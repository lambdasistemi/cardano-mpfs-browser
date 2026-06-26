module Test.AppWalletSpec (spec) where

import Prelude

import Data.Maybe (Maybe(..))
import MPFS.App.State (WalletStatus(..), defaultState)
import MPFS.App.Wallet
  ( ConnectedWalletDetails
  , disconnectWallet
  , failWalletDiscovery
  , finishWalletConnection
  , finishWalletDiscovery
  , startWalletConnection
  , startWalletDiscovery
  )
import MPFS.Types (TokenId(..))
import MPFS.UI.Remote (Remote(..))
import MPFS.Wallet.Cip30 (WalletInfo)
import Test.Spec (Spec, describe, it)
import Test.Spec.Assertions (shouldEqual)

spec :: Spec Unit
spec = describe "MPFS App Wallet" do
  it "tracks wallet discovery loading, success, empty, and failure state" do
    let
      loading = startWalletDiscovery defaultState
      loaded = finishWalletDiscovery [ lace ] loading
      empty = finishWalletDiscovery [] loading
      failed = failWalletDiscovery "wallet discovery failed" loading

    loading.walletSession.wallets `shouldEqual` Loading
    loaded.walletSession.wallets `shouldEqual` Success [ lace ]
    loaded.walletSession.feedback `shouldEqual` Nothing
    empty.walletSession.wallets `shouldEqual` Success []
    empty.walletSession.feedback `shouldEqual` Just "No CIP-30 wallet found."
    failed.walletSession.wallets `shouldEqual` Failure "wallet discovery failed"
    failed.walletSession.feedback `shouldEqual` Just "wallet discovery failed"

  it "records the selected wallet while connection is in progress" do
    let
      state = startWalletConnection lace defaultState

    state.walletSession.status `shouldEqual` WalletConnecting
    state.walletSession.walletKey `shouldEqual` Just "lace"
    state.walletSession.walletName `shouldEqual` Just "Lace"
    state.walletSession.selectedAddress `shouldEqual` Nothing
    state.walletSession.feedback `shouldEqual` Nothing

  it "stores successful wallet details with used-address priority" do
    let
      state = finishWalletConnection lace connectedDetails defaultState

    state.walletSession.status `shouldEqual` WalletConnected
    state.walletSession.walletKey `shouldEqual` Just "lace"
    state.walletSession.walletName `shouldEqual` Just "Lace"
    state.walletSession.networkId `shouldEqual` Just 0
    state.walletSession.network `shouldEqual` Just "preprod/testnet"
    state.walletSession.selectedAddress `shouldEqual` Just "addr_used"
    state.walletSession.changeAddress `shouldEqual` Just "addr_change"
    state.walletSession.usedAddresses `shouldEqual` [ "addr_used", "addr_second" ]
    state.walletSession.lovelace `shouldEqual` Just "1234567"
    state.walletSession.feedback `shouldEqual` Just "Connected to Lace."

  it "falls back to change address when there are no used addresses" do
    let
      state =
        finishWalletConnection lace
          (connectedDetails { usedAddresses = [] })
          defaultState

    state.walletSession.selectedAddress `shouldEqual` Just "addr_change"
    state.walletSession.usedAddresses `shouldEqual` []

  it "accepts preprod/testnet and rejects unsupported network ids" do
    let
      preprod = finishWalletConnection lace connectedDetails defaultState
      mainnet =
        finishWalletConnection lace
          (connectedDetails { networkId = 1 })
          defaultState
      unknown =
        finishWalletConnection lace
          (connectedDetails { networkId = 42 })
          defaultState

    preprod.walletSession.status `shouldEqual` WalletConnected
    preprod.walletSession.network `shouldEqual` Just "preprod/testnet"
    mainnet.walletSession.status `shouldEqual` WalletDisconnected
    mainnet.walletSession.feedback
      `shouldEqual`
        Just "Switch the wallet to preprod before connecting."
    unknown.walletSession.status `shouldEqual` WalletDisconnected
    unknown.walletSession.feedback
      `shouldEqual`
        Just "Switch the wallet to preprod before connecting."

  it "disconnects the wallet without changing unrelated app state" do
    let
      selected = TokenId "token"
      connected =
        finishWalletConnection lace connectedDetails
          (defaultState { selectedToken = Just selected })
      disconnected = disconnectWallet connected

    disconnected.selectedToken `shouldEqual` Just selected
    disconnected.walletSession.status `shouldEqual` WalletDisconnected
    disconnected.walletSession.walletKey `shouldEqual` Nothing
    disconnected.walletSession.walletName `shouldEqual` Nothing
    disconnected.walletSession.selectedAddress `shouldEqual` Nothing
    disconnected.walletSession.feedback `shouldEqual` Just "Wallet disconnected."

lace :: WalletInfo
lace = { key: "lace", name: "Lace", icon: "" }

connectedDetails :: ConnectedWalletDetails
connectedDetails =
  { networkId: 0
  , usedAddresses: [ "addr_used", "addr_second" ]
  , changeAddress: "addr_change"
  , lovelace: Just "1234567"
  }
