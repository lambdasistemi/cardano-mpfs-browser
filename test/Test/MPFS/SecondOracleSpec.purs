module Test.MPFS.SecondOracleSpec
  ( main
  , spec
  ) where

import Prelude

import Data.Argonaut.Decode.Class (decodeJson)
import Data.Argonaut.Parser (jsonParser)
import Data.Bifunctor (lmap)
import Data.Either (Either(..))
import Effect (Effect)
import Effect.Aff (Aff, throwError)
import Effect.Exception (error)
import MPFS.SecondOracle
  ( SecondOracleDeps
  , checkOutputRef
  , verdictFromFixture
  )
import MPFS.SecondOracle.Client as OracleClient
import MPFS.SecondOracle.Types
  ( MerkleRootEntry
  , OutputRef
  , ProofResponse
  , SecondOracleUnavailable(..)
  , SecondOracleVerdict(..)
  )
import Node.Encoding (Encoding(..))
import Node.FS.Aff as FS
import Test.Spec (Spec, describe, it)
import Test.Spec.Assertions (shouldEqual)
import Test.Spec.Reporter (consoleReporter)
import Test.Spec.Runner.Node (runSpecAndExitProcess)

main :: Effect Unit
main =
  runSpecAndExitProcess [ consoleReporter ] spec

type Fixture =
  { tokenId :: String
  , txId :: String
  , txIx :: Int
  , slotNo :: Int
  , blockHash :: String
  , merkleRoot :: String
  , proof :: String
  , txOut :: String
  , expectedFactsRoot :: String
  }

spec :: Spec Unit
spec = describe "second-oracle verdict" do
  it "verifies a real MPFS token fixture" do
    fixture <- readFixture
    verdictFromFixture
      { expectedFactsRoot: fixture.expectedFactsRoot
      , merkleRoots: [ rootEntry fixture ]
      , proofResponse: proofResponse fixture
      , inclusionVerified: true
      }
      `shouldEqual`
        SecondOracleVerified
          { chainPoint: chainPoint fixture
          , merkleRoot: fixture.merkleRoot
          , factsRoot: fixture.expectedFactsRoot
          }

  it "reports a facts-root mismatch after inclusion verifies" do
    fixture <- readFixture
    verdictFromFixture
      { expectedFactsRoot: wrongFactsRoot
      , merkleRoots: [ rootEntry fixture ]
      , proofResponse: proofResponse fixture
      , inclusionVerified: true
      }
      `shouldEqual`
        SecondOracleMismatch
          { chainPoint: chainPoint fixture
          , merkleRoot: fixture.merkleRoot
          , expectedFactsRoot: wrongFactsRoot
          , attestedFactsRoot: fixture.expectedFactsRoot
          }

  it "reports verifier false before trusting the datum" do
    fixture <- readFixture
    verdictFromFixture
      { expectedFactsRoot: fixture.expectedFactsRoot
      , merkleRoots: [ rootEntry fixture ]
      , proofResponse: proofResponse fixture
      , inclusionVerified: false
      }
      `shouldEqual`
        SecondOracleVerifierFalse
          { chainPoint: chainPoint fixture
          , merkleRoot: fixture.merkleRoot
          }

  it "reports a missing chainpoint root" do
    fixture <- readFixture
    verdictFromFixture
      { expectedFactsRoot: fixture.expectedFactsRoot
      , merkleRoots: []
      , proofResponse: proofResponse fixture
      , inclusionVerified: true
      }
      `shouldEqual` SecondOracleMissingRoot (chainPoint fixture)

  it "reports a malformed attested datum" do
    fixture <- readFixture
    let
      malformedProofResponse =
        (proofResponse fixture) { txOut = "a0" }
    verdictFromFixture
      { expectedFactsRoot: fixture.expectedFactsRoot
      , merkleRoots: [ rootEntry fixture ]
      , proofResponse: malformedProofResponse
      , inclusionVerified: true
      }
      `shouldEqual`
        SecondOracleMalformedDatum "attested txOut does not contain an MPFS state datum"

  it "uses injected client and verifier dependencies" do
    fixture <- readFixture
    verdict <- checkOutputRef
      (verifiedDeps fixture)
      (outputRef fixture)
      fixture.expectedFactsRoot
    verdict
      `shouldEqual`
        SecondOracleVerified
          { chainPoint: chainPoint fixture
          , merkleRoot: fixture.merkleRoot
          , factsRoot: fixture.expectedFactsRoot
          }

  it "selects the merkle root by the proof chainpoint" do
    fixture <- readFixture
    verdict <- checkOutputRef
      (multiRootDeps fixture)
      (outputRef fixture)
      fixture.expectedFactsRoot
    verdict
      `shouldEqual`
        SecondOracleVerified
          { chainPoint: chainPoint fixture
          , merkleRoot: fixture.merkleRoot
          , factsRoot: fixture.expectedFactsRoot
          }

  it "reports missing root when non-empty roots do not match the proof chainpoint" do
    fixture <- readFixture
    verdict <- checkOutputRef
      (noMatchingRootDeps fixture)
      (outputRef fixture)
      fixture.expectedFactsRoot
    verdict `shouldEqual` SecondOracleMissingRoot (chainPoint fixture)

  it "reports proof-client unavailability" do
    fixture <- readFixture
    verdict <- checkOutputRef
      (proofUnavailableDeps fixture)
      (outputRef fixture)
      fixture.expectedFactsRoot
    verdict
      `shouldEqual`
        SecondOracleUnavailable
          (ProofUnavailable "Decode error: proof fixture unavailable")

  it "reports merkle-root client unavailability" do
    fixture <- readFixture
    verdict <- checkOutputRef
      (rootsUnavailableDeps fixture)
      (outputRef fixture)
      fixture.expectedFactsRoot
    verdict
      `shouldEqual`
        SecondOracleUnavailable
          (MerkleRootsUnavailable "Decode error: roots fixture unavailable")

readFixture :: Aff Fixture
readFixture = do
  body <- FS.readTextFile UTF8
    "test/fixtures/csmt-utxo-verdict-real-mpfs-token.json"
  case decodeFixture body of
    Left err -> throwError (error err)
    Right fixture -> pure fixture

decodeFixture :: String -> Either String Fixture
decodeFixture body = do
  json <- lmap show (jsonParser body)
  lmap show (decodeJson json)

rootEntry :: Fixture -> MerkleRootEntry
rootEntry fixture =
  { slotNo: fixture.slotNo
  , blockHash: fixture.blockHash
  , merkleRoot: fixture.merkleRoot
  }

proofResponse :: Fixture -> ProofResponse
proofResponse fixture =
  { slotNo: fixture.slotNo
  , blockHash: fixture.blockHash
  , proof: fixture.proof
  , txOut: fixture.txOut
  }

chainPoint :: Fixture -> { slotNo :: Int, blockHash :: String }
chainPoint fixture =
  { slotNo: fixture.slotNo
  , blockHash: fixture.blockHash
  }

outputRef :: Fixture -> OutputRef
outputRef fixture =
  { txId: fixture.txId
  , txIx: fixture.txIx
  }

verifiedDeps :: Fixture -> SecondOracleDeps
verifiedDeps fixture =
  { getMerkleRoots: pure (Right [ rootEntry fixture ])
  , getProof: \_ -> pure (Right (proofResponse fixture))
  , verifyInclusion: \root proof ->
      pure (root == fixture.merkleRoot && proof == fixture.proof)
  }

multiRootDeps :: Fixture -> SecondOracleDeps
multiRootDeps fixture =
  (verifiedDeps fixture)
    { getMerkleRoots =
        pure
          ( Right
              [ decoyBeforeRootEntry fixture
              , rootEntry fixture
              , decoyAfterRootEntry fixture
              ]
          )
    }

noMatchingRootDeps :: Fixture -> SecondOracleDeps
noMatchingRootDeps fixture =
  (verifiedDeps fixture)
    { getMerkleRoots =
        pure
          ( Right
              [ decoyBeforeRootEntry fixture
              , decoyAfterRootEntry fixture
              ]
          )
    }

proofUnavailableDeps :: Fixture -> SecondOracleDeps
proofUnavailableDeps fixture =
  { getMerkleRoots: pure (Right [ rootEntry fixture ])
  , getProof: \_ ->
      pure (Left (OracleClient.DecodeError "proof fixture unavailable"))
  , verifyInclusion: \_ _ -> pure true
  }

rootsUnavailableDeps :: Fixture -> SecondOracleDeps
rootsUnavailableDeps fixture =
  { getMerkleRoots:
      pure (Left (OracleClient.DecodeError "roots fixture unavailable"))
  , getProof: \_ -> pure (Right (proofResponse fixture))
  , verifyInclusion: \_ _ -> pure true
  }

wrongFactsRoot :: String
wrongFactsRoot =
  "0000000000000000000000000000000000000000000000000000000000000000"

decoyBeforeRootEntry :: Fixture -> MerkleRootEntry
decoyBeforeRootEntry fixture =
  { slotNo: fixture.slotNo - 2
  , blockHash: "1111111111111111111111111111111111111111111111111111111111111111"
  , merkleRoot: "1111111111111111111111111111111111111111111111111111111111111111"
  }

decoyAfterRootEntry :: Fixture -> MerkleRootEntry
decoyAfterRootEntry fixture =
  { slotNo: fixture.slotNo + 2
  , blockHash: "2222222222222222222222222222222222222222222222222222222222222222"
  , merkleRoot: "2222222222222222222222222222222222222222222222222222222222222222"
  }
