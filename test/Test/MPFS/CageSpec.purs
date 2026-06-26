-- | Tests for cage reactor output parsing and write-envelope construction.
module Test.MPFS.CageSpec (spec) where

import Prelude

import Data.Argonaut.Core (Json, fromObject, fromString)
import Data.Argonaut.Decode (decodeJson)
import Data.Argonaut.Decode.Error (JsonDecodeError)
import Data.Argonaut.Parser (jsonParser)
import Data.Bifunctor (lmap)
import Data.Either (Either(..))
import Data.Maybe (maybe)
import Data.Tuple (Tuple(..))
import Foreign.Object as Object
import MPFS.Cage.Reactor
  ( parseCageTxOutput
  , parseDecodedOutput
  , parseSignedTxOutput
  )
import MPFS.Cage.Wasm
  ( buildAssembleEnvelope
  , buildBootEnvelope
  , buildRequestEnvelope
  )
import MPFS.Types (CageConfig, CageError, TrustedRoot(..), cageErrorMessage)
import Test.Spec (Spec, describe, it)
import Test.Spec.Assertions (fail, shouldEqual)

spec :: Spec Unit
spec = describe "MPFS Cage Boundary" do
  it "parses cage and signed transaction reactor output" do
    parseCageTxOutput okCageTx `shouldEqual` Right "deadbeef"
    parseSignedTxOutput okSignedTx `shouldEqual` Right "cafebabe"
    parseErrorMessage (parseCageTxOutput badOutput)
      `shouldEqual`
        Left "decoded: {}"

  it "parses decoded reactor JSON output" do
    case parseDecodedOutput okDecoded of
      Left err -> fail (cageErrorMessage err)
      Right json ->
        jsonStringField "token_id" json `shouldEqual` Right "token-1"

  it "builds boot and request envelopes with required cage fields" do
    let
      boot = buildBootEnvelope trustedRoot evalContext cageConfig facts
      request =
        buildRequestEnvelope
          "request_insert"
          trustedRoot
          evalContext
          cageConfig
          facts
    envelopeStringField "op" boot `shouldEqual` Right "boot"
    envelopeStringField "trusted_root" boot `shouldEqual` Right "root-1"
    envelopeStringField "op" request `shouldEqual` Right "request_insert"
    envelopeNestedStringField "cage_config" "network" request
      `shouldEqual`
        Right "preprod"

  it "builds assemble envelopes with unsigned tx and witness set" do
    let
      envelope = buildAssembleEnvelope "unsigned-cbor" "witness-cbor"
    envelopeStringField "op" envelope `shouldEqual` Right "assemble"
    envelopeStringField "unsigned_tx" envelope
      `shouldEqual`
        Right "unsigned-cbor"
    envelopeStringField "witness_set" envelope
      `shouldEqual`
        Right "witness-cbor"

okCageTx :: { stdout :: String, stderr :: String, exitOk :: Boolean }
okCageTx = { stdout: "cage_tx: deadbeef\nignored", stderr: "", exitOk: true }

okSignedTx :: { stdout :: String, stderr :: String, exitOk :: Boolean }
okSignedTx = { stdout: "signed_tx: cafebabe", stderr: "", exitOk: true }

okDecoded :: { stdout :: String, stderr :: String, exitOk :: Boolean }
okDecoded =
  { stdout: "decoded: {\"token_id\":\"token-1\"}"
  , stderr: ""
  , exitOk: true
  }

badOutput :: { stdout :: String, stderr :: String, exitOk :: Boolean }
badOutput = { stdout: "decoded: {}", stderr: "", exitOk: true }

trustedRoot :: TrustedRoot
trustedRoot = TrustedRoot "root-1"

cageConfig :: CageConfig
cageConfig =
  { cageScriptBytes: "cage-script"
  , requestScriptBytes: "request-script"
  , cfgScriptHash: "script-hash"
  , defaultProcessTime: 10
  , defaultRetractTime: 20
  , defaultTip: 30
  , network: "preprod"
  }

evalContext :: Json
evalContext = jsonObject [ Tuple "era" (fromString "conway") ]

facts :: Json
facts = jsonObject [ Tuple "wallet" (fromString "addr_test1") ]

jsonObject :: Array (Tuple String Json) -> Json
jsonObject = fromObject <<< Object.fromFoldable

parseErrorMessage :: forall a. Either CageError a -> Either String a
parseErrorMessage = lmap cageErrorMessage

envelopeStringField :: String -> String -> Either String String
envelopeStringField field body = do
  json <- lmap show (jsonParser body)
  jsonStringField field json

envelopeNestedStringField :: String -> String -> String -> Either String String
envelopeNestedStringField outer inner body = do
  json <- lmap show (jsonParser body)
  object <- jsonObjectFields json
  nested <- maybe (Left ("missing field " <> outer)) Right (Object.lookup outer object)
  jsonStringField inner nested

jsonStringField :: String -> Json -> Either String String
jsonStringField field json = do
  object <- jsonObjectFields json
  value <- maybe (Left ("missing field " <> field)) Right (Object.lookup field object)
  lmap show (decodeJson value :: Either JsonDecodeError String)

jsonObjectFields :: Json -> Either String (Object.Object Json)
jsonObjectFields json =
  lmap show (decodeJson json :: Either JsonDecodeError (Object.Object Json))
