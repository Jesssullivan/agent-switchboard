{-# LANGUAGE OverloadedStrings #-}

-- | The ruled constants, read from spec/dhall/generated/broker-constants.json.
-- That JSON is rendered from spec/dhall/Broker.dhall and freshness-checked by
-- spec/check-dhall.sh, so Dhall stays the single source of truth (R-C229).
module Swb.Constants
  ( Constants (..)
  , loadConstants
  , ttlSeconds
  , claimLeaseSeconds
  ) where

import Data.Aeson (FromJSON (..), Object, eitherDecodeFileStrict, withObject, (.:))
import Data.Aeson.Types (Parser)

data Constants = Constants
  { cLiveMaxAge :: Integer
  , cIdleMaxAge :: Integer
  , cTtlDefaultHours :: Integer
  , cTtlMinHours :: Integer
  , cTtlMaxHours :: Integer
  , cRetentionAcked :: Integer
  , cRetentionUnacked :: Integer
  , cInboxMaxLimit :: Integer
  , cClaimDefaultHours :: Integer
  , cClaimMaxHours :: Integer
  }
  deriving (Show)

instance FromJSON Constants where
  parseJSON = withObject "broker-constants" $ \o -> do
    s <- (o .: "session" :: Parser Object)
    m <- (o .: "message" :: Parser Object)
    c <- (o .: "claim" :: Parser Object)
    Constants
      <$> s .: "live_max_age_seconds"
      <*> s .: "idle_max_age_seconds"
      <*> m .: "ttl_default_hours"
      <*> m .: "ttl_min_hours"
      <*> m .: "ttl_max_hours"
      <*> m .: "retention_acked_seconds"
      <*> m .: "retention_unacked_seconds"
      <*> m .: "inbox_max_limit"
      <*> c .: "lease_default_hours"
      <*> c .: "lease_max_hours"

loadConstants :: FilePath -> IO Constants
loadConstants path = either (ioError . userError . (("broker constants: " ++ path ++ ": ") ++)) pure =<< eitherDecodeFileStrict path

-- | SWB-R09: TTL defaults to 72 h and is clamped to 1 h .. 14 d.
ttlSeconds :: Constants -> Maybe Integer -> Integer
ttlSeconds c requested =
  3600 * max (cTtlMinHours c) (min (cTtlMaxHours c) (maybe (cTtlDefaultHours c) id requested))

-- | SWB-R16: claim leases default to 4 h, at most 24 h. SWB-R16 sets no
-- floor, so the generators never request less than 1 h.
claimLeaseSeconds :: Constants -> Maybe Integer -> Integer
claimLeaseSeconds c requested =
  3600 * min (cClaimMaxHours c) (maybe (cClaimDefaultHours c) id requested)
