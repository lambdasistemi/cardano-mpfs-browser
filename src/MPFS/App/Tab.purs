module MPFS.App.Tab
  ( AppTab(..)
  , allTabs
  , defaultTab
  , tabLabel
  , tabSlug
  , tabFromSlug
  ) where

import Prelude

import Data.Array as Array
import Data.Maybe (Maybe)

data AppTab
  = FactsTab
  | PendingTab
  | VerificationTab

derive instance Eq AppTab
derive instance Ord AppTab

instance Show AppTab where
  show = case _ of
    FactsTab -> "FactsTab"
    PendingTab -> "PendingTab"
    VerificationTab -> "VerificationTab"

allTabs :: Array AppTab
allTabs = [ FactsTab, PendingTab, VerificationTab ]

defaultTab :: AppTab
defaultTab = FactsTab

tabLabel :: AppTab -> String
tabLabel = case _ of
  FactsTab -> "Facts"
  PendingTab -> "Pending"
  VerificationTab -> "Verification"

tabSlug :: AppTab -> String
tabSlug = case _ of
  FactsTab -> "facts"
  PendingTab -> "pending"
  VerificationTab -> "verification"

tabFromSlug :: String -> Maybe AppTab
tabFromSlug slug =
  Array.find (\tab -> tabSlug tab == slug) allTabs
