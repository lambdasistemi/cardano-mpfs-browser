-- | E2E tests for the MPFS HTTP client.
-- Requires MPFS_BASE_URL to be set.
module Test.MPFS.ClientSpec (spec) where

import Prelude

import Data.Either (Either(..))
import Data.Maybe (Maybe(..))
import Effect.Aff (Aff, throwError)
import Effect.Exception (error)
import Node.Encoding (Encoding(..))
import Node.FS.Aff as FS
import Test.Spec (Spec, describe, it)
import Test.Spec.Assertions (shouldEqual, fail)
import MPFS.Client
  ( decodeFactBody
  , decodeFactsBody
  , decodeTokensBody
  , mkClient
  )

bumpedTokensResponseBody :: String
bumpedTokensResponseBody =
  """
  {"snapshot":{"chainpoint":{"slot":42,"block_id":"1111111111111111111111111111111111111111111111111111111111111111"},"utxo_root":"2222222222222222222222222222222222222222222222222222222222222222"},"tokens":{"entries":[],"completeness_proof":"00"}}
  """

factsResponseBody :: String
factsResponseBody =
  """
  {"snapshot":{"chainpoint":{"slot":42,"block_id":"1111111111111111111111111111111111111111111111111111111111111111"},"utxo_root":"2222222222222222222222222222222222222222222222222222222222222222"},"state":{},"facts":[{"key":"6b6579","value":"76616c7565"}]}
  """

factResponseBody :: String
factResponseBody =
  """
  {"snapshot":{"chainpoint":{"slot":42,"block_id":"1111111111111111111111111111111111111111111111111111111111111111"},"utxo_root":"2222222222222222222222222222222222222222222222222222222222222222"},"value":"76616c7565","fact":{}}
  """

realTokensFixturePath :: String
realTokensFixturePath = "test/fixtures/real-umpfs-tokens.json"

baseUrl :: Maybe String -> Aff String
baseUrl mUrl =
  case mUrl of
    Nothing ->
      throwError $ error "MPFS_BASE_URL not set"
    Just url -> pure url

spec :: Maybe String -> Spec Unit
spec mBaseUrl = describe "MPFS Client" do

  it "decodes bumped GET /tokens response envelope" do
    case decodeTokensBody bumpedTokensResponseBody of
      Left err -> fail $ show err
      Right tokens ->
        tokens `shouldEqual` []

  it "decodes real GET /tokens entries to token ids" do
    body <- FS.readTextFile UTF8 realTokensFixturePath
    case decodeTokensBody body of
      Left err -> fail $ show err
      Right tokens ->
        tokens `shouldEqual`
          [ "976821dbd0922f93cda689da92a6faf1894c8151bc86d6c8f725ec089aaacbc6"
          , "98207724b0ea59b96c0eba16cb09e91da10f8bdc54ad36da4a2e40104a59a32b"
          ]

  it "decodes GET /tokens/:id/facts response entries" do
    case decodeFactsBody factsResponseBody of
      Left err -> fail $ show err
      Right facts ->
        facts `shouldEqual` [ { key: "6b6579", value: "76616c7565" } ]

  it "decodes GET /tokens/:id/facts/:key response value" do
    case decodeFactBody factResponseBody of
      Left err -> fail $ show err
      Right value ->
        value `shouldEqual` "76616c7565"

  case mBaseUrl of
    Nothing -> pure unit
    Just _ -> describe "MPFS Client E2E" do

      it "GET /status returns tip slot" do
        url <- baseUrl mBaseUrl
        let client = mkClient url
        result <- client.getStatus
        case result of
          Left err -> fail $ show err
          Right status ->
            status.tip_slot `shouldEqual`
              status.tip_slot

      it "GET /tokens returns empty array" do
        url <- baseUrl mBaseUrl
        let client = mkClient url
        result <- client.getTokens
        case result of
          Left err -> fail $ show err
          Right tokens ->
            tokens `shouldEqual` []

      it "GET /utxo/root returns a hash" do
        url <- baseUrl mBaseUrl
        let client = mkClient url
        result <- client.getUtxoRoot
        case result of
          Left err -> fail $ show err
          Right _root -> pure unit
