-- | CIP-30 wallet connector.
module MPFS.Wallet.Cip30
  ( WalletApi
  , WalletInfo
  , availableWallets
  , enable
  , getNetworkId
  , getUsedAddresses
  , getChangeAddress
  , getBalance
  , subscribeAccountChanges
  , ownerKeyHashOfAddress
  , lovelaceOfBalance
  , signTx
  , submitTx
  , networkName
  ) where

import Prelude

import Control.Promise (Promise, toAffE)
import Data.Maybe (Maybe)
import Data.Nullable (Nullable, toMaybe)
import Effect (Effect)
import Effect.Aff (Aff)

foreign import data WalletApi :: Type

type WalletInfo = { key :: String, name :: String, icon :: String }

foreign import _availableWallets :: Effect (Array WalletInfo)
foreign import _enable :: String -> Effect (Promise WalletApi)
foreign import _getNetworkId :: WalletApi -> Effect (Promise Int)
foreign import _getUsedAddresses :: WalletApi -> Effect (Promise (Array String))
foreign import _getChangeAddress :: WalletApi -> Effect (Promise String)
foreign import _getBalance :: WalletApi -> Effect (Promise String)
foreign import _subscribeAccountChanges :: WalletApi -> Effect Unit -> Effect (Effect Unit)
foreign import _ownerKeyHashOfAddress :: String -> Nullable String
foreign import _signTx :: WalletApi -> String -> Boolean -> Effect (Promise String)
foreign import _submitTx :: WalletApi -> String -> Effect (Promise String)
foreign import _coinOfBalance :: String -> Nullable String

availableWallets :: Effect (Array WalletInfo)
availableWallets = _availableWallets

enable :: String -> Aff WalletApi
enable key = toAffE (_enable key)

getNetworkId :: WalletApi -> Aff Int
getNetworkId api = toAffE (_getNetworkId api)

getUsedAddresses :: WalletApi -> Aff (Array String)
getUsedAddresses api = toAffE (_getUsedAddresses api)

getChangeAddress :: WalletApi -> Aff String
getChangeAddress api = toAffE (_getChangeAddress api)

getBalance :: WalletApi -> Aff String
getBalance api = toAffE (_getBalance api)

subscribeAccountChanges :: WalletApi -> Effect Unit -> Effect (Effect Unit)
subscribeAccountChanges = _subscribeAccountChanges

ownerKeyHashOfAddress :: String -> Maybe String
ownerKeyHashOfAddress = toMaybe <<< _ownerKeyHashOfAddress

lovelaceOfBalance :: String -> Maybe String
lovelaceOfBalance = toMaybe <<< _coinOfBalance

signTx :: WalletApi -> String -> Boolean -> Aff String
signTx api tx partial = toAffE (_signTx api tx partial)

submitTx :: WalletApi -> String -> Aff String
submitTx api tx = toAffE (_submitTx api tx)

networkName :: Int -> String
networkName 1 = "mainnet"
networkName 0 = "testnet"
networkName n = "network " <> show n
