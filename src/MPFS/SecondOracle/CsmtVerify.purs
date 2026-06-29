module MPFS.SecondOracle.CsmtVerify
  ( verifyInclusion
  ) where

import Control.Promise (Promise, toAffE)
import Effect (Effect)
import Effect.Aff (Aff)

foreign import verifyInclusionImpl :: String -> String -> Effect (Promise Boolean)

verifyInclusion :: String -> String -> Aff Boolean
verifyInclusion rootHex proofHex =
  toAffE (verifyInclusionImpl rootHex proofHex)
