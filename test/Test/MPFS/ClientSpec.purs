-- | E2E tests for the MPFS HTTP client.
-- Requires MPFS_BASE_URL to be set.
module Test.MPFS.ClientSpec (spec) where

import Prelude

import App as App
import Data.Array as Array
import Data.Either (Either(..))
import Data.Maybe (Maybe(..))
import Effect.Aff (Aff, throwError)
import Effect.Exception (error)
import MPFS.App.State (defaultState)
import Node.Encoding (Encoding(..))
import Node.FS.Aff as FS
import Test.Spec (Spec, describe, it)
import Test.Spec.Assertions (shouldEqual, fail)
import MPFS.Client
  ( decodeFactBody
  , decodeFactsBody
  , decodeTokensBody
  , decodeRequestsBody
  , decodeTokenBody
  , decodeTokenRootBody
  , mkClient
  )
import MPFS.SecondOracle.Types (OutputRef)
import MPFS.UI.Remote (Remote(..))

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

realTokenStateFixturePath :: String
realTokenStateFixturePath = "test/fixtures/real-umpfs-token-state.json"

realFactsFixturePath :: String
realFactsFixturePath = "test/fixtures/real-umpfs-facts.json"

realTokenRootFixturePath :: String
realTokenRootFixturePath = "test/fixtures/real-umpfs-token-root.json"

realRequestsFixturePath :: String
realRequestsFixturePath = "test/fixtures/real-umpfs-requests.json"

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

  it "decodes real GET /tokens/:id state envelope from inline datum" do
    body <- FS.readTextFile UTF8 realTokenStateFixturePath
    case decodeTokenBody body of
      Left err -> fail $ show err
      Right tokenState ->
        tokenState `shouldEqual`
          { owner: "8da87507ba0a8a3c67eaeb8ec768dee132ad8ecac6f526ac526f0c9f"
          , root: "0000000000000000000000000000000000000000000000000000000000000000"
          , max_fee: 1000000.0
          , process_time: 5000.0
          , retract_time: 5000.0
          , current_output_ref:
              Just
                { tx_id: "729cbe4218a27bd2dd74517cbe7612537eede47bfc9bc8d4d0d45824479ec5ba"
                , tx_ix: 0
                }
          }

  it "preserves real GET /tokens/:id state.utxo.tx_in for selected-token oracle checks" do
    body <- FS.readTextFile UTF8 realTokenStateFixturePath
    case decodeTokenBody body of
      Left err -> fail $ show err
      Right tokenState -> do
        let
          state = defaultState { tokenState = Success tokenState }

        App.selectedTokenOutputRef state `shouldEqual` Just realTokenOutputRef

  it "decodes GET /tokens/:id/facts response entries" do
    case decodeFactsBody factsResponseBody of
      Left err -> fail $ show err
      Right facts ->
        facts `shouldEqual` [ { key: "6b6579", value: "76616c7565" } ]

  it "decodes real GET /tokens/:id/facts envelope" do
    body <- FS.readTextFile UTF8 realFactsFixturePath
    case decodeFactsBody body of
      Left err -> fail $ show err
      Right facts ->
        facts `shouldEqual` []

  it "decodes real GET /tokens/:id/root quoted root" do
    body <- FS.readTextFile UTF8 realTokenRootFixturePath
    case decodeTokenRootBody body of
      Left err -> fail $ show err
      Right root ->
        root `shouldEqual`
          "0000000000000000000000000000000000000000000000000000000000000000"

  it "decodes real GET /tokens/:id/requests entries from inline datums" do
    body <- FS.readTextFile UTF8 realRequestsFixturePath
    case decodeRequestsBody body of
      Left err -> fail $ show err
      Right requests -> do
        Array.length requests `shouldEqual` 6
        case Array.head requests of
          Nothing -> fail "Expected at least one pending request"
          Just first -> do
            first.token `shouldEqual`
              "976821dbd0922f93cda689da92a6faf1894c8151bc86d6c8f725ec089aaacbc6"
            first.owner `shouldEqual`
              "8da87507ba0a8a3c67eaeb8ec768dee132ad8ecac6f526ac526f0c9f"
            first.key `shouldEqual`
              "7b2274797065223a22636f6e666967227d"
            first.operation `shouldEqual` "insert"
            first.value `shouldEqual`
              Just
                "7b226167656e74223a226238313133343233373730623564643064666530633538323630383732623464383735363930616335366561626634643330313366663137222c2270726f746f636f6c56657273696f6e223a302c227465737452756e223a7b226d61784475726174696f6e223a31322c226d696e4475726174696f6e223a317d7d"
            first.fee `shouldEqual` 1000000.0
            first.submitted_at `shouldEqual` 1781203626691.0
            first.request_id `shouldEqual`
              "14850e4aa5a87674d917161a00c0c250a6ebd99dc79987a21c5a024c2cfac42a#0"

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

realTokenOutputRef :: OutputRef
realTokenOutputRef =
  { txId: "729cbe4218a27bd2dd74517cbe7612537eede47bfc9bc8d4d0d45824479ec5ba"
  , txIx: 0
  }
