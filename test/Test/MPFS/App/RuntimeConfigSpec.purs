module Test.MPFS.App.RuntimeConfigSpec (spec) where

import Prelude

import Data.Maybe (Maybe(..))
import MPFS.App.RuntimeConfig (resolveBaseUrl)
import Test.Spec (Spec, describe, it)
import Test.Spec.Assertions (shouldEqual)

spec :: Spec Unit
spec = describe "MPFS App RuntimeConfig" do
  it "defaults the MPFS API base to /api" do
    resolveBaseUrl Nothing `shouldEqual` "/api"

  it "uses an injected MPFS API base when present" do
    resolveBaseUrl (Just "https://x") `shouldEqual` "https://x"
