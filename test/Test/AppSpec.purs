module Test.AppSpec (spec) where

import Prelude

import Data.Array as Array
import Data.Maybe (Maybe(..))
import MPFS.App.State (defaultState, selectTab)
import MPFS.App.Tab (AppTab(..), allTabs, defaultTab, tabLabel, tabSlug, tabFromSlug)
import MPFS.App.Tokens as Tokens
import MPFS.Types (TokenId(..))
import Test.Spec (Spec, describe, it)
import Test.Spec.Assertions (shouldEqual)

spec :: Spec Unit
spec = describe "MPFS App Shell" do
  it "defines the three workspace tabs in design order" do
    allTabs `shouldEqual` [ FactsTab, PendingTab, VerificationTab ]
    Array.length allTabs `shouldEqual` 3

  it "exposes deterministic tab labels and slugs" do
    map tabLabel allTabs
      `shouldEqual` [ "Facts", "Pending", "Verification" ]
    map tabSlug allTabs
      `shouldEqual` [ "facts", "pending", "verification" ]

  it "uses Facts as the default workspace tab" do
    defaultTab `shouldEqual` FactsTab
    defaultState.activeTab `shouldEqual` FactsTab

  it "looks up and selects tabs without changing unrelated state" do
    tabFromSlug "facts" `shouldEqual` Just FactsTab
    tabFromSlug "verification" `shouldEqual` Just VerificationTab
    tabFromSlug "missing" `shouldEqual` Nothing
    (selectTab PendingTab defaultState).activeTab `shouldEqual` PendingTab
    (selectTab PendingTab defaultState).selectedToken `shouldEqual` defaultState.selectedToken

  it "resets token selection to the Facts workspace tab" do
    let
      state = selectTab VerificationTab defaultState

      selected = Tokens.selectToken (TokenId "token-01") state

    selected.selectedToken `shouldEqual` Just (TokenId "token-01")
    selected.activeTab `shouldEqual` FactsTab
