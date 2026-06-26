module MPFS.App.Wallet
  ( ConnectedWalletDetails
  , disconnectWallet
  , failWalletConnection
  , failWalletDiscovery
  , finishWalletConnection
  , finishWalletDiscovery
  , finishWalletRefresh
  , setWalletRuntime
  , startWalletConnection
  , startWalletDiscovery
  , unsupportedNetworkMessage
  ) where

import Prelude

import Data.Array as Array
import Data.Maybe (Maybe(..), fromMaybe)
import Halogen.Query.HalogenM (SubscriptionId)
import MPFS.App.State (AppState, WalletStatus(..))
import MPFS.UI.Remote (Remote(..))
import MPFS.Wallet.Cip30 (WalletApi, WalletInfo)

type ConnectedWalletDetails =
  { networkId :: Int
  , usedAddresses :: Array String
  , changeAddress :: String
  , lovelace :: Maybe String
  }

startWalletDiscovery :: AppState -> AppState
startWalletDiscovery state =
  state
    { walletSession =
        state.walletSession
          { wallets = Loading
          , feedback = Nothing
          }
    }

finishWalletDiscovery :: Array WalletInfo -> AppState -> AppState
finishWalletDiscovery wallets state =
  state
    { walletSession =
        state.walletSession
          { wallets = Success wallets
          , feedback =
              if Array.null wallets then
                Just "No CIP-30 wallet found."
              else
                Nothing
          }
    }

failWalletDiscovery :: String -> AppState -> AppState
failWalletDiscovery message state =
  state
    { walletSession =
        state.walletSession
          { wallets = Failure message
          , feedback = Just message
          }
    }

startWalletConnection :: WalletInfo -> AppState -> AppState
startWalletConnection info state =
  state
    { walletSession =
        state.walletSession
          { status = WalletConnecting
          , walletKey = Just info.key
          , walletName = Just info.name
          , networkId = Nothing
          , network = Nothing
          , selectedAddress = Nothing
          , changeAddress = Nothing
          , usedAddresses = []
          , lovelace = Nothing
          , feedback = Nothing
          , api = Nothing
          , subscriptionId = Nothing
          }
    }

finishWalletConnection
  :: WalletInfo -> ConnectedWalletDetails -> AppState -> AppState
finishWalletConnection info details state =
  if details.networkId == 0 then
    state
      { walletSession =
          state.walletSession
            { status = WalletConnected
            , walletKey = Just info.key
            , walletName = Just info.name
            , networkId = Just details.networkId
            , network = Just preprodNetworkLabel
            , selectedAddress = Just (selectedAddress details)
            , changeAddress = Just details.changeAddress
            , usedAddresses = details.usedAddresses
            , lovelace = details.lovelace
            , feedback = Just ("Connected to " <> info.name <> ".")
            }
      }
  else
    failWalletConnection unsupportedNetworkMessage state

finishWalletRefresh :: ConnectedWalletDetails -> AppState -> AppState
finishWalletRefresh details state =
  case state.walletSession.walletKey, state.walletSession.walletName of
    Just key, Just name ->
      finishWalletConnection { key, name, icon: "" } details state
    _, _ ->
      failWalletConnection "Connect a wallet first." state

failWalletConnection :: String -> AppState -> AppState
failWalletConnection message state =
  state
    { walletSession =
        state.walletSession
          { status = WalletDisconnected
          , networkId = Nothing
          , network = Nothing
          , selectedAddress = Nothing
          , changeAddress = Nothing
          , usedAddresses = []
          , lovelace = Nothing
          , feedback = Just message
          , api = Nothing
          , subscriptionId = Nothing
          }
    }

setWalletRuntime
  :: Maybe WalletApi -> Maybe SubscriptionId -> AppState -> AppState
setWalletRuntime api subscriptionId state =
  state
    { walletSession =
        state.walletSession
          { api = api
          , subscriptionId = subscriptionId
          }
    }

disconnectWallet :: AppState -> AppState
disconnectWallet state =
  state
    { walletSession =
        state.walletSession
          { status = WalletDisconnected
          , walletKey = Nothing
          , walletName = Nothing
          , networkId = Nothing
          , network = Nothing
          , selectedAddress = Nothing
          , changeAddress = Nothing
          , usedAddresses = []
          , lovelace = Nothing
          , feedback = Just "Wallet disconnected."
          , api = Nothing
          , subscriptionId = Nothing
          }
    }

selectedAddress :: ConnectedWalletDetails -> String
selectedAddress details =
  fromMaybe details.changeAddress (Array.head details.usedAddresses)

preprodNetworkLabel :: String
preprodNetworkLabel = "preprod/testnet"

unsupportedNetworkMessage :: String
unsupportedNetworkMessage = "Switch the wallet to preprod before connecting."
