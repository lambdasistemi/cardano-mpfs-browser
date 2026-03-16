module Test.Main where

import Prelude

import Effect (Effect)
import Test.Spec.Reporter (consoleReporter)
import Test.Spec.Runner.Node (runSpecAndExitProcess)
import Test.MPFS.ProofSpec as ProofSpec

main :: Effect Unit
main = runSpecAndExitProcess [ consoleReporter ]
  ProofSpec.spec
