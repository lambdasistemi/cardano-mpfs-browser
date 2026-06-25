-- | Tests for proof verification through the WASM verify reactor.
module Test.MPFS.ProofSpec (spec) where

import Prelude

import Data.Either (Either(..))
import Test.Spec (Spec, describe, it)
import Test.Spec.Assertions (shouldEqual)
import MPFS.Reactor (parseVerifyOutput, runCageReactor, verifyEnvelope)

spec :: Spec Unit
spec = describe "WASM Verify Reactor Verification" do

  it "runs the reactor and preserves unknown-op verdicts" do
    result <- runCageReactor unknownOpEnvelope
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

unknownOpEnvelope :: String
unknownOpEnvelope =
  "{\"op\":\"frobnicate\",\"trusted_root\":\"0000000000000000000000000000000000000000000000000000000000000000\",\"facts\":{}}"

corruptedBootProofEnvelope :: String
corruptedBootProofEnvelope =
  "{\"facts\":{\"protocol_parameters\":{\"cbor\":\"820102\",\"verified\":false},\"snapshot\":{\"chainpoint\":{\"block_id\":\"1111111111111111111111111111111111111111111111111111111111111111\",\"slot\":42},\"utxo_root\":\"4db60d43fa4eca2a2007fd49051b36021b47dfef5af71a2d1fbdbfcfb38c74b6\"},\"wallet_utxos\":[{\"inclusion_proof\":\"00\",\"ref\":{\"tx_id\":\"c2c2c2c2c2c2c2c2c2c2c2c2c2c2c2c2c2c2c2c2c2c2c2c2c2c2c2c2c2c2c2c2\",\"tx_ix\":2},\"txout_cbor\":\"a2004461646472011a001e8480\"}]},\"op\":\"boot\",\"trusted_root\":\"4db60d43fa4eca2a2007fd49051b36021b47dfef5af71a2d1fbdbfcfb38c74b6\"}"
