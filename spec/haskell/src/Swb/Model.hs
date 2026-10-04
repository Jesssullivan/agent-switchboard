-- | A pure, executable model of the broker's coordination state (R-C229).
--
-- It follows crates/swb-store for sessions, threads and messages, and the
-- SWB-R16 text in ADR-0001 for claims, which are not implemented in Rust yet.
-- Time is an abstract clock in seconds that only 'Tick' advances.
--
-- The core invariants (per-thread seq, lease transitions, claim listing)
-- live in Swb.Invariants as LiquidHaskell refinement types (R-C261), and
-- the model runs those definitions.
--
-- The model is one implementation of 'Op' -> 'Res'; the live adapter
-- (Swb.Live) is another. The properties in Swb.Properties judge a trace of
-- operations and results and never look inside either implementation.
module Swb.Model
  ( Agent (..)
  , Thread (..)
  , Subject (..)
  , LeaseState (..)
  , Op (..)
  , Res (..)
  , ClaimOutcome (..)
  , ClaimView (..)
  , Trace
  , classify
  , runModel
  ) where

import Data.List (sortOn)
import qualified Data.Map.Strict as M
import Swb.Constants
import Swb.Invariants

type Time = Integer

data Op
  = Register Agent Int -- ^ agent, proc_start
  | End Agent Int -- ^ agent, proc_start
  | Peers Agent -- ^ peers(me): refreshes me, then lists every session
  | Send Agent Agent Thread (Maybe Integer) -- ^ from, to, thread, ttl_hours
  | Inbox Agent Integer -- ^ me, limit
  | Ack Agent Int -- ^ me, abstract message index (-1: an id never sent)
  | Claim Agent Subject Bool (Maybe Integer) -- ^ holder, subject, exclusive, lease hours
  | ListClaims
  | Tick Integer -- ^ advance the clock (model only)
  deriving (Eq, Show)

data ClaimOutcome
  = Recorded
  | HeldBy Agent
  | Unruled String -- ^ an SWB-R16 "Not yet ruled" case; never asserted
  deriving (Eq, Show)

data Res
  = RRegistered
  | REnded Bool -- ^ True when the session moved to ended
  | RPeers [(Agent, LeaseState)]
  | RSent Int Thread Integer -- ^ abstract message index, thread, seq
  | RInbox [(Int, Integer)] -- ^ (message index, delivery_count)
  | RAcked
  | RClaimed ClaimOutcome
  | RClaims [ClaimView]
  | RTicked
  | RUnsupported
  | RErr String
  deriving (Eq, Show)

type Trace = [(Op, Res)]

data Session = Session {sProc :: Int, sSeen :: Time, sEnded :: Bool}

data Msg = Msg
  { mId :: Int
  , mThread :: Thread
  , mSeq :: Integer
  , mTo :: Agent
  , mCreated :: Time
  , mExpires :: Time
  , mAcked :: Maybe Time
  , mDeliveries :: Integer
  }

data St = St
  { now :: Time
  , sessions :: M.Map Agent Session
  , msgs :: [Msg] -- creation order
  , threadLogs :: M.Map Thread [Integer] -- seq log per thread, newest first; survives prune, like thread_counters
  , nextId :: Int
  , claims :: [ClaimRec]
  }

classify :: Constants -> Time -> Time -> Bool -> LeaseState
classify c = classifyAge (cLiveMaxAge c) (cIdleMaxAge c)

runModel :: Constants -> [Op] -> Trace
runModel c = go (St 0 M.empty [] M.empty 0 [])
  where
    go _ [] = []
    go s (o : os) = let (r, s') = step c o s in (o, r) : go s' os

-- | Every broker operation by a registered agent refreshes its lease and
-- clears ended (the `UPDATE sessions SET last_seen=..., ended=0` in each
-- swb-store mutation). Claims are assumed to do the same.
refresh :: Agent -> St -> St
refresh a s = s {sessions = M.adjust (\x -> x {sSeen = now s, sEnded = False}) a (sessions s)}

-- | swb-store prune(): acked rows after 7 d, every other row 30 d after creation.
prune :: Constants -> St -> St
prune c s = s {msgs = filter keep (msgs s)}
  where
    keep m = case mAcked m of
      Just at -> at > now s - cRetentionAcked c
      Nothing -> mCreated m > now s - cRetentionUnacked c

pending :: St -> Agent -> Msg -> Bool
pending s a m = mTo m == a && mAcked m == Nothing && mExpires m > now s

step :: Constants -> Op -> St -> (Res, St)
step c op s = case op of
  Register a p -> (RRegistered, s {sessions = M.insert a (Session p (now s) False) (sessions s)})
  End a p -> case M.lookup a (sessions s) of
    Just x | sProc x == p -> (REnded True, s {sessions = M.insert a x {sEnded = True} (sessions s)})
    _ -> (REnded False, s)
  Peers a
    | M.member a (sessions s) ->
        let s' = refresh a s
         in (RPeers [(b, classify c (now s') (sSeen x) (sEnded x)) | (b, x) <- M.toList (sessions s')], s')
    | otherwise -> (RErr "unregistered me", s)
  Send from to th ttl ->
    let s1 = prune c s
        lg = appendSeq (M.findWithDefault [] th (threadLogs s1))
        sq = newest lg
        m = Msg (nextId s1) th sq to (now s1) (now s1 + ttlSeconds c ttl) Nothing 0
        s2 = s1 {msgs = msgs s1 ++ [m], threadLogs = M.insert th lg (threadLogs s1), nextId = nextId s1 + 1}
     in (RSent (mId m) th sq, refresh from s2)
  Inbox a limit ->
    let s1 = prune c s
        picked = take (fromInteger (min limit (cInboxMaxLimit c))) (sortOn (\m -> (mCreated m, mSeq m, mId m)) (filter (pending s1 a) (msgs s1)))
        ids = map mId picked
        bump m = if mId m `elem` ids then m {mDeliveries = mDeliveries m + 1} else m
        s2 = s1 {msgs = map bump (msgs s1)}
        counts = [(mId m, mDeliveries m) | m <- msgs s2, mId m `elem` ids]
        ordered = [(i, d) | i <- ids, Just d <- [lookup i counts]]
     in (RInbox ordered, refresh a s2)
  Ack a i -> case [m | m <- msgs s, mId m == i, mTo m == a] of
    [m]
      | pending s a m -> (RAcked, refresh a s {msgs = map (\x -> if mId x == i then x {mAcked = Just (now s)} else x) (msgs s)})
      | mAcked m /= Nothing -> (RAcked, refresh a s)
    _ -> (RErr "message unavailable", s)
  Claim h subj ex lease ->
    let active = [r | r <- claims s, crSubject r == subj, crUntil r > now s]
        others = [crHolder r | r <- active, crExclusive r, crHolder r /= h]
        record = s {claims = claims s ++ [ClaimRec h subj ex (now s + claimLeaseSeconds c lease)]}
        outcome
          | not ex = (Recorded, record)
          | any (\r -> crExclusive r && crHolder r == h) active = (Unruled "exclusive_reclaim_by_the_current_exclusive_holder", s)
          | (x : _) <- others = (HeldBy x, s)
          | not (null active) = (Unruled "exclusive_request_while_nonexclusive_claims_exist", s)
          | otherwise = (Recorded, record)
     in (RClaimed (fst outcome), refresh h (snd outcome))
  ListClaims ->
    let holder h = (\x -> classify c (now s) (sSeen x) (sEnded x)) <$> M.lookup h (sessions s)
     in (RClaims [viewClaim (holder (crHolder r)) r | r <- activeClaims (now s) (claims s)], s)
  Tick d -> (RTicked, s {now = now s + d})
