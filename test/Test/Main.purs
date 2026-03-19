module Test.Main where

import Prelude

import Data.Maybe (Maybe(..))
import Effect (Effect)
import Effect.Class (liftEffect)
import Node.Process (lookupEnv)
import Test.Spec (Spec)
import Test.Spec.Reporter (consoleReporter)
import Test.Spec.Runner.Node (runSpecAndExitProcess)
import Test.MPFS.ClientSpec as ClientSpec
import Test.MPFS.ProofSpec as ProofSpec
import Test.MPFS.TxCborSpec as TxCborSpec

main :: Effect Unit
main = do
  mUrl <- lookupEnv "MPFS_BASE_URL"
  let
    specs :: Spec Unit
    specs = do
      ProofSpec.spec
      TxCborSpec.spec
      case mUrl of
        Nothing -> pure unit
        Just _ -> ClientSpec.spec
  runSpecAndExitProcess [ consoleReporter ] specs
