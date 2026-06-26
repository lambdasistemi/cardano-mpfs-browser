module Test.Main where

import Prelude

import Data.Maybe (Maybe(..))
import Effect (Effect)
import Node.Process (lookupEnv)
import Test.Spec (Spec)
import Test.Spec.Reporter (consoleReporter)
import Test.Spec.Runner.Node (runSpecAndExitProcess)
import Test.AppWalletSpec as AppWalletSpec
import Test.AppSpec as AppSpec
import Test.FactsSpec as FactsSpec
import Test.MPFS.CageSpec as CageSpec
import Test.MPFS.ClientSpec as ClientSpec
import Test.MPFS.ProofSpec as ProofSpec
import Test.MPFS.TxCborSpec as TxCborSpec
import Test.MPFS.WalletSpec as WalletSpec
import Test.TokensSpec as TokensSpec

main :: Effect Unit
main = do
  mUrl <- lookupEnv "MPFS_BASE_URL"
  let
    specs :: Spec Unit
    specs = do
      AppSpec.spec
      AppWalletSpec.spec
      CageSpec.spec
      FactsSpec.spec
      ProofSpec.spec
      TokensSpec.spec
      TxCborSpec.spec
      WalletSpec.spec
      case mUrl of
        Nothing -> pure unit
        Just _ -> ClientSpec.spec
  runSpecAndExitProcess [ consoleReporter ] specs
