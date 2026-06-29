module Test.MPFS.LiveTokensSmoke
  ( main
  , spec
  ) where

import Prelude

import App as App
import Data.Array as Array
import Data.Either (Either(..))
import Data.Maybe (Maybe(..))
import Effect (Effect)
import Effect.Class (liftEffect)
import MPFS.App.State (defaultState)
import MPFS.Client (mkClient)
import MPFS.SecondOracle as SecondOracle
import MPFS.SecondOracle.Client as SecondOracleClient
import MPFS.SecondOracle.CsmtVerify as CsmtVerify
import MPFS.SecondOracle.Types (SecondOracleVerdict(..))
import MPFS.UI.Remote (Remote(..))
import Node.Process (lookupEnv)
import Test.Spec (Spec, describe, it)
import Test.Spec.Assertions (fail)
import Test.Spec.Reporter (consoleReporter)
import Test.Spec.Runner.Node (runSpecAndExitProcess)

defaultBaseUrl :: String
defaultBaseUrl = "https://umpfs.plutimus.com"

main :: Effect Unit
main =
  runSpecAndExitProcess [ consoleReporter ] spec

spec :: Spec Unit
spec = describe "Live UMPFS token smoke" do
  it "exercises live token read flow" do
    mBaseUrl <- liftEffect $ lookupEnv "MPFS_BASE_URL"
    let
      baseUrl =
        case mBaseUrl of
          Nothing -> defaultBaseUrl
          Just url -> url
      client = mkClient baseUrl
    result <- client.getTokens
    case result of
      Left err ->
        fail $ "GET " <> baseUrl <> "/tokens failed: " <> show err
      Right tokens -> case Array.head tokens of
        Nothing ->
          fail $ "Expected at least one token id from " <> baseUrl <> "/tokens"
        Just token -> do
          stateResult <- client.getToken token
          case stateResult of
            Left err ->
              fail $ "GET " <> baseUrl <> "/tokens/" <> token <> " failed: " <> show err
            Right _state -> pure unit

          factsResult <- client.getTokenFacts token
          case factsResult of
            Left err ->
              fail $ "GET " <> baseUrl <> "/tokens/" <> token <> "/facts failed: " <> show err
            Right _facts -> pure unit

          rootResult <- client.getTokenRoot token
          case rootResult of
            Left err ->
              fail $ "GET " <> baseUrl <> "/tokens/" <> token <> "/root failed: " <> show err
            Right root ->
              if root == "" then
                fail $ "Expected non-empty root from " <> baseUrl <> "/tokens/" <> token <> "/root"
              else
                pure unit

          requestsResult <- client.getTokenRequests token
          case requestsResult of
            Left err ->
              fail $ "GET " <> baseUrl <> "/tokens/" <> token <> "/requests failed: " <> show err
            Right _requests -> pure unit

          case stateResult of
            Left _ ->
              pure unit
            Right tokenState -> do
              let
                appState = defaultState { tokenState = Success tokenState }

              case App.selectedTokenOutputRef appState of
                Nothing ->
                  fail "Expected decoded live token state to include an output reference for the second oracle"
                Just outputRef -> do
                  verdict <- SecondOracle.checkOutputRef
                    secondOracleDeps
                    outputRef
                    tokenState.root
                  case verdict of
                    SecondOracleVerified _ ->
                      pure unit
                    SecondOracleMismatch _ ->
                      pure unit
                    other ->
                      fail $ "Expected concrete second-oracle verdict, got " <> show other

secondOracleDeps :: SecondOracle.SecondOracleDeps
secondOracleDeps =
  { getMerkleRoots: client.getMerkleRoots
  , getProof: client.getProof
  , verifyInclusion: CsmtVerify.verifyInclusion
  }
  where
  client = SecondOracleClient.defaultClient
