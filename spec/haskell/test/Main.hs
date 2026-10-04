-- | Runs the five trace properties against the pure model, and against a
-- live broker when SWB_SPEC_BROKER_URL names one on loopback (R-C229).
module Main (main) where

import Control.Monad (unless)
import Data.Maybe (fromMaybe)
import Network.HTTP.Client (defaultManagerSettings, newManager)
import Swb.Constants
import Swb.Live
import Swb.Model
import Swb.Properties
import System.Environment (lookupEnv)
import System.Exit (exitFailure)
import Test.QuickCheck
import Test.QuickCheck.Monadic (assert, monadicIO, monitor, pick, run)

judge :: (Trace -> [String]) -> Trace -> Property
judge check tr = let bad = check tr in counterexample (unlines (bad ++ map show tr)) (null bad)

main :: IO ()
main = do
  path <- fromMaybe "../dhall/generated/broker-constants.json" <$> lookupEnv "SWB_SPEC_CONSTANTS"
  c <- loadConstants path
  model <-
    mapM
      ( \(name, check) -> do
          putStrLn ("model: " ++ name)
          quickCheckWithResult stdArgs {maxSuccess = 1000} $
            forAllShrink (genOps ModelMode) shrinkOps (judge check . runModel c . normalizeAcks)
      )
      (properties c)
  url <- lookupEnv "SWB_SPEC_BROKER_URL"
  live <- case url of
    Nothing -> [] <$ putStrLn "live: SWB_SPEC_BROKER_URL unset; skipped"
    Just raw -> case loopbackOnly raw of
      Left err -> ioError (userError err)
      Right base -> do
        mgr <- newManager defaultManagerSettings
        mapM
          ( \(name, check) -> do
              putStrLn ("live: " ++ name)
              quickCheckWithResult stdArgs {maxSuccess = 25} $ monadicIO $ do
                ops <- pick (resize 30 (genOps LiveMode))
                tr <- run (runLive mgr base ops)
                let bad = check tr
                monitor (counterexample (unlines (bad ++ map show tr)))
                assert (null bad)
          )
          (properties c)
  unless (all isSuccess (model ++ live)) exitFailure
