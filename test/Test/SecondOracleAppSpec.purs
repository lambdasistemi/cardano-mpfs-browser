module Test.SecondOracleAppSpec (spec) where

import Prelude

import App as App
import Data.Maybe (Maybe(..))
import MPFS.App.State (defaultState)
import MPFS.App.View (secondOracleStatusLabel)
import MPFS.SecondOracle.Types
  ( SecondOracleUnavailable(..)
  , SecondOracleVerdict(..)
  )
import MPFS.Types (TokenId(..))
import MPFS.UI.Remote (Remote(..))
import Test.Spec (Spec, describe, it)
import Test.Spec.Assertions (shouldEqual)

spec :: Spec Unit
spec = describe "MPFS App Second Oracle UI" do
  it "does not fabricate an output reference from selected-token state" do
    let
      state = defaultState { selectedToken = Just (TokenId "token") }

    App.selectedTokenOutputRef state `shouldEqual` Nothing

  it "renders status labels for second oracle outcomes" do
    map secondOracleStatusLabel
      [ NotAsked
      , Loading
      , Failure "Output reference unavailable"
      , Success verifiedVerdict
      , Success mismatchVerdict
      , Success verifierFalseVerdict
      , Success missingRootVerdict
      , Success malformedDatumVerdict
      , Success oracleUnavailableVerdict
      ]
      `shouldEqual`
        [ "Not checked"
        , "Checking second oracle"
        , "Output reference unavailable"
        , "Verified"
        , "Mismatch"
        , "Verifier rejected inclusion proof"
        , "Merkle root missing"
        , "Malformed datum: not MPFS datum"
        , "Oracle unavailable: offline"
        ]

verifiedVerdict :: SecondOracleVerdict
verifiedVerdict =
  SecondOracleVerified
    { chainPoint
    , merkleRoot: "merkle-root"
    , factsRoot: "root"
    }

mismatchVerdict :: SecondOracleVerdict
mismatchVerdict =
  SecondOracleMismatch
    { chainPoint
    , merkleRoot: "merkle-root"
    , expectedFactsRoot: "expected-root"
    , attestedFactsRoot: "attested-root"
    }

verifierFalseVerdict :: SecondOracleVerdict
verifierFalseVerdict =
  SecondOracleVerifierFalse
    { chainPoint
    , merkleRoot: "merkle-root"
    }

missingRootVerdict :: SecondOracleVerdict
missingRootVerdict =
  SecondOracleMissingRoot chainPoint

malformedDatumVerdict :: SecondOracleVerdict
malformedDatumVerdict =
  SecondOracleMalformedDatum "not MPFS datum"

oracleUnavailableVerdict :: SecondOracleVerdict
oracleUnavailableVerdict =
  SecondOracleUnavailable (ProofUnavailable "offline")

chainPoint :: { slotNo :: Int, blockHash :: String }
chainPoint =
  { slotNo: 42
  , blockHash: "block-hash"
  }
