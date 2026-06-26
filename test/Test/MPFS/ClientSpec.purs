-- | E2E tests for the MPFS HTTP client.
-- Requires MPFS_BASE_URL to be set.
module Test.MPFS.ClientSpec (spec) where

import Prelude

import Data.Either (Either(..))
import Data.Maybe (Maybe(..))
import Effect.Aff (Aff, throwError)
import Effect.Class (liftEffect)
import Effect.Exception (error)
import Node.Process (lookupEnv)
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

baseUrl :: Aff String
baseUrl = do
  mUrl <- liftEffect $ lookupEnv "MPFS_BASE_URL"
  case mUrl of
    Nothing ->
      throwError $ error "MPFS_BASE_URL not set"
    Just url -> pure url

spec :: Spec Unit
spec = describe "MPFS Client E2E" do

  it "decodes bumped GET /tokens response envelope" do
    case decodeTokensBody bumpedTokensResponseBody of
      Left err -> fail $ show err
      Right tokens ->
        tokens `shouldEqual` []

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

  it "GET /status returns tip slot" do
    url <- baseUrl
    let client = mkClient url
    result <- client.getStatus
    case result of
      Left err -> fail $ show err
      Right status ->
        status.tip_slot `shouldEqual`
          status.tip_slot

  it "GET /tokens returns empty array" do
    url <- baseUrl
    let client = mkClient url
    result <- client.getTokens
    case result of
      Left err -> fail $ show err
      Right tokens ->
        tokens `shouldEqual` []

  it "GET /utxo/root returns a hash" do
    url <- baseUrl
    let client = mkClient url
    result <- client.getUtxoRoot
    case result of
      Left err -> fail $ show err
      Right _root -> pure unit
