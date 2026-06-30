module Test.SecondOracleAppSpec (spec) where

import Prelude

import App as App
import Data.Either (Either(..))
import Data.Maybe (Maybe(..))
import MPFS.Client (decodeTokenBody)
import MPFS.App.State (defaultState)
import MPFS.App.View (secondOracleStatusLabel)
import MPFS.SecondOracle.Types
  ( OutputRef
  , SecondOracleUnavailable(..)
  , SecondOracleVerdict(..)
  )
import MPFS.Types (TokenId(..))
import MPFS.UI.Remote (Remote(..))
import Node.Encoding (Encoding(..))
import Node.FS.Aff as FS
import Test.Spec (Spec, describe, it)
import Test.Spec.Assertions (fail, shouldEqual)

spec :: Spec Unit
spec = describe "MPFS App Second Oracle UI" do
  it "does not fabricate an output reference from selected-token identity alone" do
    let
      state = defaultState { selectedToken = Just (TokenId "token") }

    App.selectedTokenOutputRef state `shouldEqual` Nothing

  it "uses the loaded token-state output reference for the selected token" do
    body <- FS.readTextFile UTF8 "test/fixtures/real-umpfs-token-state.json"
    case decodeTokenBody body of
      Left err -> fail $ show err
      Right tokenState -> do
        let
          state =
            defaultState
              { selectedToken =
                  Just
                    ( TokenId
                        "976821dbd0922f93cda689da92a6faf1894c8151bc86d6c8f725ec089aaacbc6"
                    )
              , tokenState = Success tokenState
              }

        App.selectedTokenOutputRef state `shouldEqual` Just realTokenOutputRef

  it "renders status labels for second oracle outcomes" do
    map secondOracleStatusLabel
      [ NotAsked
      , Loading
      , Failure "Output reference unavailable"
      , Success verifiedVerdict
      , Success mismatchVerdict
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

realTokenOutputRef :: OutputRef
realTokenOutputRef =
  { txId: "729cbe4218a27bd2dd74517cbe7612537eede47bfc9bc8d4d0d45824479ec5ba"
  , txIx: 0
  }
