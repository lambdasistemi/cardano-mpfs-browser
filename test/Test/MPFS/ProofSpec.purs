-- | Tests for proof verification through the WASM verify reactor.
module Test.MPFS.ProofSpec (spec) where

import Prelude

import Data.Argonaut.Core (Json, fromObject, fromString, stringify)
import Data.Argonaut.Decode (decodeJson)
import Data.Argonaut.Decode.Error (JsonDecodeError)
import Data.Argonaut.Parser (jsonParser)
import Data.Bifunctor (lmap)
import Data.Either (Either(..))
import Data.Maybe (Maybe(..))
import Effect.Aff (Aff, throwError)
import Effect.Exception (error)
import Foreign.Object as Object
import MPFS.Client (RawFactResponse, decodeFactRawBody)
import MPFS.App.Verification as Verification
import MPFS.SecondOracle.Types (MerkleRootEntry)
import Node.Encoding (Encoding(..))
import Node.FS.Aff as FS
import Test.Spec (Spec, describe, it)
import Test.Spec.Assertions (fail, shouldEqual)
import MPFS.Reactor (parseVerifyOutput, runVerifyReactor, verifyEnvelope)

spec :: Spec Unit
spec = describe "WASM Verify Reactor Verification" do

  it "runs the verify reactor and preserves unknown-op verdicts" do
    result <- runVerifyReactor unknownOpEnvelope
    result.exitOk `shouldEqual` true
    result.stdout `shouldEqual` "unknown_op: frobnicate"

  it "parses verify_ok as success" do
    let
      parsed =
        parseVerifyOutput
          { stdout: "verify_ok"
          , stderr: ""
          , exitOk: true
          }
    parsed `shouldEqual` Right unit

  it "parses reactor verification errors as failures" do
    let
      parsed =
        parseVerifyOutput
          { stdout: "verify_error: root mismatch"
          , stderr: ""
          , exitOk: true
          }
    parsed `shouldEqual` Left "root mismatch"

  it "routes verification envelopes through the reactor" do
    verdict <- verifyEnvelope unknownOpEnvelope
    verdict `shouldEqual` Left "unknown_op: frobnicate"

  it "rejects corrupted boot facts proof through the reactor" do
    verdict <- verifyEnvelope corruptedBootProofEnvelope
    verdict
      `shouldEqual`
        Left "CsmtReplayFailed \"boot.wallet_utxos[0].inclusion_proof\" \"malformed proof CBOR\""

  it "builds a fact-inclusion envelope with the raw fixture and verifies it" do
    fact <- readRawFactInclusionFixture
    let
      anchoredRoot =
        Verification.anchorFactSnapshotRoot [ matchingMerkleRoot ] fact

    anchoredRoot `shouldEqual` Right fixtureUtxoRoot

    case anchoredRoot of
      Left err ->
        fail err
      Right trustedRoot -> do
        let
          envelope =
            Verification.buildFactInclusionEnvelope trustedRoot fact.raw lookupKey

        assertFactInclusionEnvelope envelope trustedRoot fact.raw

        verdict <- verifyEnvelope envelope
        verdict `shouldEqual` Right unit

  it "rejects the real fact-inclusion fixture after tampering fact.mpf_proof" do
    facts <- readFactInclusionFixture
    tamperedFacts <- case tamperFactProof facts of
      Left err -> throwError $ error err
      Right value -> pure value

    verdict <-
      verifyEnvelope
        (Verification.buildFactInclusionEnvelope fixtureUtxoRoot tamperedFacts lookupKey)
    case verdict of
      Left _ -> pure unit
      Right _ -> fail "expected tampered fact inclusion proof to fail verification"

  it "rejects a fact response whose snapshot root is not independently anchored" do
    fact <- readRawFactInclusionFixture
    Verification.anchorFactSnapshotRoot [ mismatchedMerkleRoot ] fact
      `shouldEqual`
        Left "Fact snapshot UTxO root is not anchored by the second oracle"

unknownOpEnvelope :: String
unknownOpEnvelope =
  "{\"op\":\"frobnicate\",\"trusted_root\":\"0000000000000000000000000000000000000000000000000000000000000000\",\"facts\":{}}"

corruptedBootProofEnvelope :: String
corruptedBootProofEnvelope =
  "{\"facts\":{\"protocol_parameters\":{\"cbor\":\"820102\",\"verified\":false},\"snapshot\":{\"chainpoint\":{\"block_id\":\"1111111111111111111111111111111111111111111111111111111111111111\",\"slot\":42},\"utxo_root\":\"4db60d43fa4eca2a2007fd49051b36021b47dfef5af71a2d1fbdbfcfb38c74b6\"},\"wallet_utxos\":[{\"inclusion_proof\":\"00\",\"ref\":{\"tx_id\":\"c2c2c2c2c2c2c2c2c2c2c2c2c2c2c2c2c2c2c2c2c2c2c2c2c2c2c2c2c2c2c2c2\",\"tx_ix\":2},\"txout_cbor\":\"a2004461646472011a001e8480\"}]},\"op\":\"boot\",\"trusted_root\":\"4db60d43fa4eca2a2007fd49051b36021b47dfef5af71a2d1fbdbfcfb38c74b6\"}"

realFactInclusionFixturePath :: String
realFactInclusionFixturePath = "test/fixtures/real-umpfs-fact-inclusion.json"

fixtureUtxoRoot :: String
fixtureUtxoRoot =
  "2890b676dbb8714954c07b368bd229cc338dced143e8efd3ca4378b5b59f07bb"

mismatchedUtxoRoot :: String
mismatchedUtxoRoot =
  "0000000000000000000000000000000000000000000000000000000000000000"

lookupKey :: String
lookupKey = "70616f6c696e6f"

readFactInclusionFixture :: Aff Json
readFactInclusionFixture = do
  body <- FS.readTextFile UTF8 realFactInclusionFixturePath
  case jsonParser body of
    Left err -> throwError $ error err
    Right json -> pure json

readRawFactInclusionFixture :: Aff RawFactResponse
readRawFactInclusionFixture = do
  body <- FS.readTextFile UTF8 realFactInclusionFixturePath
  case decodeFactRawBody body of
    Left err -> throwError $ error (show err)
    Right fact -> pure fact

matchingMerkleRoot :: MerkleRootEntry
matchingMerkleRoot =
  { slotNo: 127139766
  , blockHash: "9bd0b0e2fc2089ed829346aab614cdb12e16ce8e2ab3bdc50507f6a4598de71e"
  , merkleRoot: fixtureUtxoRoot
  }

mismatchedMerkleRoot :: MerkleRootEntry
mismatchedMerkleRoot =
  matchingMerkleRoot { merkleRoot = mismatchedUtxoRoot }

assertFactInclusionEnvelope :: String -> String -> Json -> Aff Unit
assertFactInclusionEnvelope envelope trustedRoot facts = case jsonParser envelope of
  Left err ->
    fail err
  Right json -> case jsonObjectFields json of
    Left err ->
      fail err
    Right fields -> do
      jsonStringField "op" "op" fields `shouldEqual` Right "verify_fact_inclusion"
      jsonStringField "trusted_root" "trusted_root" fields
        `shouldEqual`
          Right trustedRoot
      jsonStringField "key" "key" fields `shouldEqual` Right lookupKey
      case lookupJson "facts" fields of
        Left err ->
          fail err
        Right envelopeFacts ->
          stringify envelopeFacts `shouldEqual` stringify facts

tamperFactProof :: Json -> Either String Json
tamperFactProof facts = do
  fields <- jsonObjectFields facts
  factJson <- lookupJson "fact" fields
  factFields <- jsonObjectFields factJson
  proof <- jsonStringField "fact.mpf_proof" "mpf_proof" factFields
  let
    corruptedProof =
      if proof == "00" then "01"
      else "00"
    tamperedFact =
      fromObject
        (Object.insert "mpf_proof" (fromString corruptedProof) factFields)
  pure
    ( fromObject
        (Object.insert "fact" tamperedFact fields)
    )

jsonObjectFields :: Json -> Either String (Object.Object Json)
jsonObjectFields json =
  lmap show (decodeJson json :: Either JsonDecodeError (Object.Object Json))

lookupJson :: String -> Object.Object Json -> Either String Json
lookupJson field object =
  case Object.lookup field object of
    Nothing -> Left ("missing field " <> field)
    Just value -> Right value

jsonStringField :: String -> String -> Object.Object Json -> Either String String
jsonStringField path field object = do
  value <- case Object.lookup field object of
    Nothing -> Left ("missing field " <> path)
    Just json -> Right json
  lmap show (decodeJson value :: Either JsonDecodeError String)
