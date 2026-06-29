module Test.MPFS.SecondOracleCsmtVerifySpec
  ( main
  , spec
  ) where

import Prelude

import Data.Argonaut.Decode.Class (decodeJson)
import Data.Argonaut.Parser (jsonParser)
import Data.Bifunctor (lmap)
import Data.Either (Either(..))
import Data.String.CodeUnits as String
import Effect (Effect)
import Effect.Aff (Aff, throwError)
import Effect.Exception (error)
import MPFS.SecondOracle.CsmtVerify (verifyInclusion)
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
  { merkleRoot :: String
  , proof :: String
  }

spec :: Spec Unit
spec = describe "CSMT UTxO verifier" do
  it "verifies a captured real inclusion proof" do
    fixture <- readFixture
    verdict <- verifyInclusion fixture.merkleRoot fixture.proof
    verdict `shouldEqual` true

  it "rejects a tampered captured inclusion proof" do
    fixture <- readFixture
    verdict <- verifyInclusion fixture.merkleRoot (tamperProof fixture.proof)
    verdict `shouldEqual` false

  it "verifies a real MPFS-token inclusion proof through the wasm" do
    fixture <- readRealMpfsTokenFixture
    verdict <- verifyInclusion fixture.merkleRoot fixture.proof
    verdict `shouldEqual` true

  it "rejects a tampered real MPFS-token proof" do
    fixture <- readRealMpfsTokenFixture
    verdict <- verifyInclusion fixture.merkleRoot (tamperProof fixture.proof)
    verdict `shouldEqual` false

readFixture :: Aff Fixture
readFixture =
  readFixtureFile "test/fixtures/csmt-utxo-verify.json"

readRealMpfsTokenFixture :: Aff Fixture
readRealMpfsTokenFixture =
  readFixtureFile "test/fixtures/csmt-utxo-verdict-real-mpfs-token.json"

readFixtureFile :: String -> Aff Fixture
readFixtureFile path = do
  body <- FS.readTextFile UTF8 path
  case decodeFixture body of
    Left err -> throwError (error err)
    Right fixture -> pure fixture

decodeFixture :: String -> Either String Fixture
decodeFixture body = do
  json <- lmap show (jsonParser body)
  lmap show (decodeJson json)

tamperProof :: String -> String
tamperProof proofHex =
  let
    finalOffset = String.length proofHex - 1
    replacement =
      if String.drop finalOffset proofHex == "0" then "1"
      else "0"
  in
    String.take finalOffset proofHex <> replacement
