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
  = ConnectTab
  | TokensTab
  | FactsTab
  | EndTab

derive instance Eq AppTab
derive instance Ord AppTab

instance Show AppTab where
  show = case _ of
    ConnectTab -> "ConnectTab"
    TokensTab -> "TokensTab"
    FactsTab -> "FactsTab"
    EndTab -> "EndTab"

allTabs :: Array AppTab
allTabs = [ ConnectTab, TokensTab, FactsTab, EndTab ]

defaultTab :: AppTab
defaultTab = ConnectTab

tabLabel :: AppTab -> String
tabLabel = case _ of
  ConnectTab -> "Connect"
  TokensTab -> "Tokens"
  FactsTab -> "Facts"
  EndTab -> "End"

tabSlug :: AppTab -> String
tabSlug = case _ of
  ConnectTab -> "connect"
  TokensTab -> "tokens"
  FactsTab -> "facts"
  EndTab -> "end"

tabFromSlug :: String -> Maybe AppTab
tabFromSlug slug =
  Array.find (\tab -> tabSlug tab == slug) allTabs
