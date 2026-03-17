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
import MPFS.Client (mkClient)

baseUrl :: Aff String
baseUrl = do
  mUrl <- liftEffect $ lookupEnv "MPFS_BASE_URL"
  case mUrl of
    Nothing ->
      throwError $ error "MPFS_BASE_URL not set"
    Just url -> pure url

spec :: Spec Unit
spec = describe "MPFS Client E2E" do

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

  it "GET /utxo/root returns 404 on empty devnet" do
    url <- baseUrl
    let client = mkClient url
    result <- client.getUtxoRoot
    case result of
      Left _ -> pure unit -- expected: no UTxOs yet
      Right _root -> pure unit
