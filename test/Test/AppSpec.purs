module Test.AppSpec (spec) where

import Prelude

import Data.Array as Array
import Data.Maybe (Maybe(..))
import MPFS.App.State (defaultState, selectTab)
import MPFS.App.Tab (AppTab(..), allTabs, defaultTab, tabLabel, tabSlug, tabFromSlug)
import Test.Spec (Spec, describe, it)
import Test.Spec.Assertions (shouldEqual)

spec :: Spec Unit
spec = describe "MPFS App Shell" do
  it "defines the four routed tabs in workbench order" do
    allTabs `shouldEqual` [ ConnectTab, TokensTab, FactsTab, EndTab ]
    Array.length allTabs `shouldEqual` 4

  it "exposes deterministic tab labels and slugs" do
    map tabLabel allTabs
      `shouldEqual` [ "Connect", "Tokens", "Facts", "End" ]
    map tabSlug allTabs
      `shouldEqual` [ "connect", "tokens", "facts", "end" ]

  it "uses Connect as the default app selection" do
    defaultTab `shouldEqual` ConnectTab
    defaultState.activeTab `shouldEqual` ConnectTab

  it "looks up and selects tabs without changing unrelated state" do
    tabFromSlug "facts" `shouldEqual` Just FactsTab
    tabFromSlug "missing" `shouldEqual` Nothing
    (selectTab EndTab defaultState).activeTab `shouldEqual` EndTab
    (selectTab EndTab defaultState).selectedToken `shouldEqual` defaultState.selectedToken
