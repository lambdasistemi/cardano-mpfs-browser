module MPFS.App.State
  ( AppState
  , WalletSession
  , WalletStatus(..)
  , defaultState
  , selectTab
  ) where

import Prelude

import Data.Maybe (Maybe(..))
import MPFS.App.Tab (AppTab, defaultTab)
import MPFS.Types (TokenId)
import MPFS.UI.Remote (Remote(..))

data WalletStatus
  = WalletDisconnected
  | WalletConnecting
  | WalletConnected

derive instance Eq WalletStatus

instance Show WalletStatus where
  show = case _ of
    WalletDisconnected -> "WalletDisconnected"
    WalletConnecting -> "WalletConnecting"
    WalletConnected -> "WalletConnected"

type WalletSession =
  { status :: WalletStatus
  , walletName :: Maybe String
  , network :: Maybe String
  , address :: Maybe String
  }

type AppState =
  { activeTab :: AppTab
  , selectedToken :: Maybe TokenId
  , baseUrl :: String
  , tokens :: Remote (Array TokenId)
  , facts :: Remote Unit
  , trustedRoot :: Remote Unit
  , walletSession :: WalletSession
  }

defaultState :: AppState
defaultState =
  { activeTab: defaultTab
  , selectedToken: Nothing
  , baseUrl: "/api"
  , tokens: NotAsked
  , facts: NotAsked
  , trustedRoot: NotAsked
  , walletSession:
      { status: WalletDisconnected
      , walletName: Nothing
      , network: Nothing
      , address: Nothing
      }
  }

selectTab :: AppTab -> AppState -> AppState
selectTab tab state = state { activeTab = tab }
