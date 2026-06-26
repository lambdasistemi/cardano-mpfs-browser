module App where

import Prelude

import Data.Either (Either(..))
import Data.Maybe (Maybe(..))
import Data.DateTime.Instant as Instant
import Data.Time.Duration (Milliseconds(..))
import Data.Traversable (traverse_)
import Effect.Aff (Aff, attempt)
import Effect.Aff.Class (class MonadAff, liftAff)
import Effect.Class (liftEffect)
import Effect.Now as Now
import Halogen as H
import Halogen.Subscription as HS
import MPFS.App.Facts as Facts
import MPFS.App.State (AppState, WalletStatus(..), defaultState, selectTab)
import MPFS.App.Tab (AppTab)
import MPFS.App.Tokens as Tokens
import MPFS.App.Verification as Verification
import MPFS.App.View as View
import MPFS.App.Wallet as Wallet
import MPFS.Client as Client
import MPFS.Client.Types as ClientTypes
import MPFS.Types (TokenId(..))
import MPFS.Wallet.Cip30 as Cip30

data Action
  = Initialize
  | SelectTab AppTab
  | LoadWallets
  | ConnectWallet Cip30.WalletInfo
  | RefreshWallet
  | DisconnectWallet
  | LoadTokens
  | SelectToken TokenId
  | LoadFacts
  | UpdateFactLookupKey String
  | LookupFact
  | UpdateFactProofEnvelope String
  | VerifyFactEnvelope

component :: forall q i o m. MonadAff m => H.Component q i o m
component =
  H.mkComponent
    { initialState: const defaultState
    , render:
        View.render
          { selectTab: SelectTab
          , loadWallets: LoadWallets
          , connectWallet: ConnectWallet
          , refreshWallet: RefreshWallet
          , disconnectWallet: DisconnectWallet
          , loadTokens: LoadTokens
          , selectToken: SelectToken
          , loadFacts: LoadFacts
          , updateFactLookupKey: UpdateFactLookupKey
          , lookupFact: LookupFact
          , updateFactProofEnvelope: UpdateFactProofEnvelope
          , verifyFactEnvelope: VerifyFactEnvelope
          }
    , eval:
        H.mkEval H.defaultEval
          { initialize = Just Initialize
          , handleAction = handleAction
          }
    }

handleAction
  :: forall slots output m
   . MonadAff m
  => Action
  -> H.HalogenM AppState Action slots output m Unit
handleAction = case _ of
  Initialize ->
    loadWallets

  SelectTab tab ->
    H.modify_ (selectTab tab)

  LoadWallets ->
    loadWallets

  ConnectWallet info -> do
    state <- H.get
    traverse_ H.unsubscribe state.walletSession.subscriptionId
    H.modify_ (Wallet.startWalletConnection info)
    result <- liftAff $ attempt do
      api <- Cip30.enable info.key
      details <- readWalletDetails api
      pure { api, details }
    case result of
      Left _ ->
        H.modify_
          ( Wallet.failWalletConnection
              "Wallet connection failed or was declined."
          )
      Right { api, details } -> do
        H.modify_ (Wallet.finishWalletConnection info details)
        connected <- H.get
        case connected.walletSession.status of
          WalletConnected -> do
            subscriptionId <- subscribeWalletChanges api
            H.modify_
              (Wallet.setWalletRuntime (Just api) (Just subscriptionId))
          _ ->
            pure unit

  RefreshWallet -> do
    state <- H.get
    case state.walletSession.api of
      Nothing ->
        H.modify_ (Wallet.failWalletConnection "Connect a wallet first.")
      Just api -> do
        result <- liftAff $ attempt (readWalletDetails api)
        case result of
          Left _ ->
            H.modify_
              \current ->
                current
                  { walletSession =
                      current.walletSession
                        { feedback = Just "Wallet account refresh failed." }
                  }
          Right details -> do
            H.modify_ (Wallet.finishWalletRefresh details)
            refreshed <- H.get
            case refreshed.walletSession.status of
              WalletConnected ->
                H.modify_
                  ( Wallet.setWalletRuntime
                      (Just api)
                      refreshed.walletSession.subscriptionId
                  )
              _ ->
                traverse_ H.unsubscribe state.walletSession.subscriptionId

  DisconnectWallet -> do
    state <- H.get
    traverse_ H.unsubscribe state.walletSession.subscriptionId
    H.modify_ Wallet.disconnectWallet

  LoadTokens -> do
    state <- H.modify Tokens.startTokenLoad
    result <- liftAff (Client.mkClient state.baseUrl).getTokens
    case result of
      Left error ->
        H.modify_ (Tokens.failTokenLoad (show error))
      Right tokenIds ->
        H.modify_ (Tokens.finishTokenLoad (fromClientTokenIds tokenIds))

  SelectToken token ->
    H.modify_ (Tokens.selectToken token)

  LoadFacts -> do
    state <- H.get
    case state.selectedToken of
      Nothing ->
        H.modify_ (Facts.failFactsLoad "Select a token first.")
      Just token -> do
        loadingState <- H.modify Facts.startFactsLoad
        let
          client = Client.mkClient loadingState.baseUrl
          clientToken = fromAppTokenId token
        tokenStateResult <- liftAff (client.getToken clientToken)
        requestsResult <- liftAff (client.getTokenRequests clientToken)
        factsResult <- liftAff (client.getTokenFacts clientToken)
        trustedRootResult <- liftAff client.getTrustedRoot
        case tokenStateResult, requestsResult, factsResult, trustedRootResult of
          Right tokenState, Right requests, Right facts, Right trustedRoot -> do
            requestNowMillis <- currentTimeMillis
            H.modify_
              ( Facts.finishFactsLoadWithRootAt
                  requestNowMillis
                  tokenState
                  requests
                  facts
                  trustedRoot
              )
          Left error, _, _, _ ->
            H.modify_ (Facts.failFactsLoad (show error))
          _, Left error, _, _ ->
            H.modify_ (Facts.failFactsLoad (show error))
          _, _, Left error, _ ->
            H.modify_ (Facts.failFactsLoad (show error))
          _, _, _, Left error ->
            H.modify_ (Facts.failFactsLoad (show error))

  UpdateFactLookupKey key ->
    H.modify_ (Facts.setFactLookupKey key)

  LookupFact -> do
    state <- H.get
    case state.selectedToken of
      Nothing ->
        H.modify_ (Facts.failFactLookup "Select a token first.")
      Just _ | state.factLookup.key == "" ->
        H.modify_ (Facts.failFactLookup "Enter a fact key.")
      Just token -> do
        H.modify_ (Facts.startFactLookup state.factLookup.key)
        result <-
          liftAff
            ( (Client.mkClient state.baseUrl).getTokenFact
                (fromAppTokenId token)
                state.factLookup.key
            )
        case result of
          Left error ->
            H.modify_ (Facts.failFactLookup (show error))
          Right value ->
            H.modify_ (Facts.finishFactLookup value)

  UpdateFactProofEnvelope envelope ->
    H.modify_ (Facts.setFactProofEnvelope envelope)

  VerifyFactEnvelope -> do
    state <- H.get
    if state.factLookup.proofEnvelope == "" then
      H.modify_
        ( Verification.finishVerification
            (Left "Enter a proof envelope.")
        )
    else do
      H.modify_ Verification.startVerification
      result <- liftAff
        (Verification.verifyFactEnvelope state.factLookup.proofEnvelope)
      H.modify_ (Verification.finishVerification result)

fromClientTokenIds :: Array ClientTypes.TokenId -> Array TokenId
fromClientTokenIds = map TokenId

fromAppTokenId :: TokenId -> ClientTypes.TokenId
fromAppTokenId (TokenId tokenId) = tokenId

currentTimeMillis :: forall m. MonadAff m => m Number
currentTimeMillis = do
  instant <- liftEffect Now.now
  let
    Milliseconds millis = Instant.unInstant instant
  pure millis

loadWallets
  :: forall slots output m
   . MonadAff m
  => H.HalogenM AppState Action slots output m Unit
loadWallets = do
  H.modify_ Wallet.startWalletDiscovery
  wallets <- liftEffect Cip30.availableWallets
  H.modify_ (Wallet.finishWalletDiscovery wallets)

readWalletDetails :: Cip30.WalletApi -> Aff Wallet.ConnectedWalletDetails
readWalletDetails api = do
  networkId <- Cip30.getNetworkId api
  usedAddresses <- Cip30.getUsedAddresses api
  changeAddress <- Cip30.getChangeAddress api
  balance <- Cip30.getBalance api
  pure
    { networkId
    , usedAddresses
    , changeAddress
    , lovelace: Cip30.lovelaceOfBalance balance
    }

subscribeWalletChanges
  :: forall slots output m
   . MonadAff m
  => Cip30.WalletApi
  -> H.HalogenM AppState Action slots output m H.SubscriptionId
subscribeWalletChanges api =
  H.subscribe $ HS.makeEmitter \push -> do
    Cip30.subscribeAccountChanges api (push RefreshWallet)
