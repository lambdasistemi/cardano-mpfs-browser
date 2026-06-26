module MPFS.App.State
  ( AppState
  , FactLookup
  , WalletSession
  , WalletStatus(..)
  , defaultState
  , selectTab
  ) where

import Prelude

import Data.Maybe (Maybe(..))
import MPFS.App.Tab (AppTab, defaultTab)
import MPFS.App.Verification (VerificationStatus(..))
import MPFS.Client.Types (FactEntry, PendingRequest, TokenState)
import MPFS.Types (TokenId, TrustedRoot)
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

type FactLookup =
  { key :: String
  , value :: Remote String
  , proofEnvelope :: String
  , verification :: VerificationStatus
  }

type AppState =
  { activeTab :: AppTab
  , selectedToken :: Maybe TokenId
  , baseUrl :: String
  , tokens :: Remote (Array TokenId)
  , facts :: Remote (Array FactEntry)
  , tokenState :: Remote TokenState
  , pendingRequests :: Remote (Array PendingRequest)
  , trustedRoot :: Remote TrustedRoot
  , requestNowMillis :: Number
  , factLookup :: FactLookup
  , walletSession :: WalletSession
  }

defaultState :: AppState
defaultState =
  { activeTab: defaultTab
  , selectedToken: Nothing
  , baseUrl: "/api"
  , tokens: NotAsked
  , facts: NotAsked
  , tokenState: NotAsked
  , pendingRequests: NotAsked
  , trustedRoot: NotAsked
  , requestNowMillis: 0.0
  , factLookup:
      { key: ""
      , value: NotAsked
      , proofEnvelope: ""
      , verification: VerificationNotAsked
      }
  , walletSession:
      { status: WalletDisconnected
      , walletName: Nothing
      , network: Nothing
      , address: Nothing
      }
  }

selectTab :: AppTab -> AppState -> AppState
selectTab tab state = state { activeTab = tab }
