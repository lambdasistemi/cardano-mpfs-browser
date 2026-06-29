module Test.MPFS.LiveTokensSmoke
  ( main
  , spec
  ) where

import Prelude

import Data.Array as Array
import Data.Either (Either(..))
import Data.Maybe (Maybe(..))
import Effect (Effect)
import Effect.Class (liftEffect)
import MPFS.Client (mkClient)
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
  it "derives at least one token id from live GET /tokens" do
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
      Right tokens ->
        if Array.null tokens then
          fail $ "Expected at least one token id from " <> baseUrl <> "/tokens"
        else
          pure unit
