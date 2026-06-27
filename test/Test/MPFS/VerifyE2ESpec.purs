-- | E2E tests for live proof verification through the WASM verify reactor.
-- Requires MPFS_BASE_URL to be set.
module Test.MPFS.VerifyE2ESpec (spec) where

import Prelude

import Data.Argonaut.Core (Json, fromArray, fromObject, fromString, stringify)
import Data.Argonaut.Decode (decodeJson)
import Data.Argonaut.Decode.Error (JsonDecodeError)
import Data.Array as Array
import Data.Bifunctor (lmap)
import Data.Either (Either(..))
import Data.Maybe (Maybe(..))
import Data.Tuple (Tuple(..))
import Effect.Aff (Aff, throwError)
import Effect.Class (liftEffect)
import Effect.Exception (error)
import Foreign.Object as Object
import MPFS.Client (mkClient)
import MPFS.Reactor (verifyEnvelope)
import MPFS.Types (TrustedRoot(..))
import Node.Process (lookupEnv)
import Test.Spec (Spec, describe, it)
import Test.Spec.Assertions (fail, shouldEqual)

spec :: Spec Unit
spec = describe "MPFS Verify E2E" do
  it "verifies live boot facts and rejects tampered live boot facts" do
    url <- baseUrl
    let client = mkClient url
    facts <- expectRight "POST /facts/boot" $
      client.postBootFacts { address: devnetGenesisAddress }
    trustedRoot <- expectRight "GET /status trusted root" client.getTrustedRoot

    honest <- verifyEnvelope (buildBootEnvelope trustedRoot facts)
    honest `shouldEqual` Right unit

    tamperedFacts <- case tamperBootFacts facts of
      Left err -> throwError $ error err
      Right value -> pure value
    tampered <- verifyEnvelope (buildBootEnvelope trustedRoot tamperedFacts)
    case tampered of
      Left _ -> pure unit
      Right _ -> fail "expected tampered live boot facts to fail verification"

baseUrl :: Aff String
baseUrl = do
  mUrl <- liftEffect $ lookupEnv "MPFS_BASE_URL"
  case mUrl of
    Nothing ->
      throwError $ error "MPFS_BASE_URL not set"
    Just url -> pure url

expectRight :: forall e a. Show e => String -> Aff (Either e a) -> Aff a
expectRight label action = do
  result <- action
  case result of
    Left err -> throwError $ error (label <> ": " <> show err)
    Right value -> pure value

buildBootEnvelope :: TrustedRoot -> Json -> String
buildBootEnvelope (TrustedRoot trustedRoot) facts =
  stringify
    ( jsonObject
        [ Tuple "op" (fromString "boot")
        , Tuple "trusted_root" (fromString trustedRoot)
        , Tuple "facts" facts
        ]
    )

jsonObject :: Array (Tuple String Json) -> Json
jsonObject = fromObject <<< Object.fromFoldable

tamperBootFacts :: Json -> Either String Json
tamperBootFacts facts = do
  fields <- jsonObjectFields facts
  utxosJson <- lookupJson "wallet_utxos" fields
  utxos <- lmap show (decodeJson utxosJson :: Either JsonDecodeError (Array Json))
  case Array.uncons utxos of
    Nothing -> Left "wallet_utxos is empty"
    Just { head, tail } -> do
      firstFields <- jsonObjectFields head
      proof <- jsonStringField "wallet_utxos[0].inclusion_proof"
        "inclusion_proof"
        firstFields
      let
        corruptedProof =
          if proof == "00" then "01"
          else "00"
        tamperedFirst =
          fromObject
            ( Object.insert
                "inclusion_proof"
                (fromString corruptedProof)
                firstFields
            )
      pure
        ( fromObject
            ( Object.insert
                "wallet_utxos"
                (fromArray (Array.cons tamperedFirst tail))
                fields
            )
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

-- The local mpfs-devnet-server funds Cardano.Node.Client.E2E.Setup.genesisAddr.
devnetGenesisAddress :: String
devnetGenesisAddress =
  "60f92331d882d35e05978c558352a66c61f476838e1e2fd1c4ae7fc0d6"
