module App where

import Prelude

import Data.Array as Array
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
import MPFS.App.Config as AppConfig
import MPFS.App.Facts as Facts
import MPFS.App.State (AppState, WalletStatus(..), defaultState, selectTab)
import MPFS.App.Tab (AppTab)
import MPFS.App.Tokens as Tokens
import MPFS.App.Verification as Verification
import MPFS.App.View as View
import MPFS.App.Wallet as Wallet
import MPFS.App.Write as Write
import MPFS.App.Write (WriteStatus(..))
import MPFS.Cage (CageResult)
import MPFS.Cage.Wasm as CageWasm
import MPFS.Client as Client
import MPFS.Client.Types as ClientTypes
import MPFS.SecondOracle as SecondOracle
import MPFS.SecondOracle.Client as SecondOracleClient
import MPFS.SecondOracle.CsmtVerify as CsmtVerify
import MPFS.SecondOracle.Types (OutputRef)
import MPFS.Types
  ( CageConfig
  , Key(..)
  , RequestId
  , TokenId(..)
  , UnsignedTxCbor(..)
  , Value(..)
  , WalletAddr(..)
  , cageErrorMessage
  )
import MPFS.UI.Remote (Remote(..))
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
  | RegisterToken
  | UpdateInsertKey String
  | UpdateInsertValue String
  | SubmitInsertFact
  | UpdateUpdateKey String
  | UpdateUpdateOldValue String
  | UpdateUpdateNewValue String
  | SubmitUpdateFact
  | UpdateDeleteKey String
  | UpdateDeleteValue String
  | SubmitDeleteFact
  | ToggleRequestSelection RequestId
  | RetractRequest RequestId
  | RejectExpired
  | UpdateToken
  | EndCage
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
          , registerToken: RegisterToken
          , updateInsertKey: UpdateInsertKey
          , updateInsertValue: UpdateInsertValue
          , submitInsertFact: SubmitInsertFact
          , updateUpdateKey: UpdateUpdateKey
          , updateUpdateOldValue: UpdateUpdateOldValue
          , updateUpdateNewValue: UpdateUpdateNewValue
          , submitUpdateFact: SubmitUpdateFact
          , updateDeleteKey: UpdateDeleteKey
          , updateDeleteValue: UpdateDeleteValue
          , submitDeleteFact: SubmitDeleteFact
          , toggleRequestSelection: ToggleRequestSelection
          , retractRequest: RetractRequest
          , rejectExpired: RejectExpired
          , updateToken: UpdateToken
          , endCage: EndCage
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
    H.modify_ \state ->
      Facts.resetSecondOracle
        ((Tokens.selectToken token state) { selectedRequestIds = [] })

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
            runSecondOracleCheck tokenState.root
          Left error, _, _, _ ->
            H.modify_ (Facts.failFactsLoad (show error))
          _, Left error, _, _ ->
            H.modify_ (Facts.failFactsLoad (show error))
          _, _, Left error, _ ->
            H.modify_ (Facts.failFactsLoad (show error))
          _, _, _, Left error ->
            H.modify_ (Facts.failFactsLoad (show error))

  RegisterToken ->
    runWriteOperation Write.WriteRegisterToken \client address cfg _state ->
      Right $ (CageWasm.wasmCageHelpers client).registerToken address cfg

  UpdateInsertKey key ->
    H.modify_ (Write.setInsertKey key)

  UpdateInsertValue value ->
    H.modify_ (Write.setInsertValue value)

  SubmitInsertFact ->
    runWriteOperation Write.WriteInsertFact \client address cfg state ->
      withSelectedToken state \token ->
        Right
          ( (CageWasm.wasmCageHelpers client).insertFact
              address
              cfg
              token
              (Key state.writeForms.insertKey)
              (Value state.writeForms.insertValue)
          )

  UpdateUpdateKey key ->
    H.modify_ (Write.setUpdateKey key)

  UpdateUpdateOldValue value ->
    H.modify_ (Write.setUpdateOldValue value)

  UpdateUpdateNewValue value ->
    H.modify_ (Write.setUpdateNewValue value)

  SubmitUpdateFact ->
    runWriteOperation Write.WriteUpdateFact \client address cfg state ->
      withSelectedToken state \token ->
        Right
          ( (CageWasm.wasmCageHelpers client).updateFact
              address
              cfg
              token
              (Key state.writeForms.updateKey)
              (Value state.writeForms.updateOldValue)
              (Value state.writeForms.updateNewValue)
          )

  UpdateDeleteKey key ->
    H.modify_ (Write.setDeleteKey key)

  UpdateDeleteValue value ->
    H.modify_ (Write.setDeleteValue value)

  SubmitDeleteFact ->
    runWriteOperation Write.WriteDeleteFact \client address cfg state ->
      withSelectedToken state \token ->
        Right
          ( (CageWasm.wasmCageHelpers client).deleteFact
              address
              cfg
              token
              (Key state.writeForms.deleteKey)
              (Value state.writeForms.deleteValue)
          )

  ToggleRequestSelection requestId ->
    H.modify_ (Write.toggleRequestSelection requestId)

  RetractRequest requestId ->
    runWriteOperation Write.WriteRetractRequest \client address cfg state ->
      withSelectedToken state \token ->
        Right
          ( (CageWasm.wasmCageHelpers client).retractRequest
              address
              cfg
              token
              requestId
          )

  RejectExpired ->
    runWriteOperation Write.WriteRejectExpired \client address cfg state ->
      withSelectedToken state \token ->
        if Array.null state.selectedRequestIds then
          Left "Select at least one expired request."
        else
          Right
            ( (CageWasm.wasmCageHelpers client).rejectExpired
                address
                cfg
                token
                state.selectedRequestIds
            )

  UpdateToken ->
    runWriteOperation Write.WriteUpdateToken \client address cfg state ->
      withSelectedToken state \token ->
        if Array.null state.selectedRequestIds then
          Left "Select at least one processable request."
        else
          Right
            ( (CageWasm.wasmCageHelpers client).updateToken
                address
                cfg
                token
                state.selectedRequestIds
            )

  EndCage ->
    runWriteOperation Write.WriteEndCage \client address cfg state ->
      withSelectedToken state \token ->
        Right
          ( (CageWasm.wasmCageHelpers client).endCage
              address
              cfg
              token
          )

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
        let
          client = Client.mkClient state.baseUrl
          clientToken = fromAppTokenId token
          lookupKey = state.factLookup.key
        H.modify_ (Facts.startFactLookup state.factLookup.key)
        result <-
          liftAff (client.getTokenFactRaw clientToken lookupKey)
        case result of
          Left error ->
            H.modify_ (Facts.failFactLookup (show error))
          Right fact -> do
            H.modify_ (Facts.finishFactLookup fact.value)
            H.modify_ Verification.startVerification
            rootResult <- liftAff do
              rootsResult <- SecondOracleClient.defaultClient.getMerkleRoots
              pure case rootsResult of
                Left error ->
                  Left (show error)
                Right roots ->
                  Verification.anchorFactSnapshotRoot roots fact
            case rootResult of
              Left message ->
                H.modify_
                  ( Verification.finishVerification
                      (Left message)
                  )
              Right trustedRoot -> do
                verificationResult <-
                  liftAff
                    ( Verification.verifyFactInclusion
                        trustedRoot
                        fact.raw
                        lookupKey
                    )
                H.modify_ (Verification.finishVerification verificationResult)

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

selectedTokenOutputRef :: AppState -> Maybe OutputRef
selectedTokenOutputRef state =
  case state.tokenState of
    Success tokenState ->
      map tokenOutputRefToSecondOracle tokenState.current_output_ref
    _ ->
      Nothing

tokenOutputRefToSecondOracle :: ClientTypes.TokenOutputRef -> OutputRef
tokenOutputRefToSecondOracle ref =
  { txId: ref.tx_id
  , txIx: ref.tx_ix
  }

runSecondOracleCheck
  :: forall slots output m
   . MonadAff m
  => String
  -> H.HalogenM AppState Action slots output m Unit
runSecondOracleCheck factsRoot = do
  state <- H.get
  case selectedTokenOutputRef state of
    Nothing ->
      H.modify_ (Facts.failSecondOracleCheck "Output reference unavailable")
    Just outputRef -> do
      H.modify_ Facts.startSecondOracleCheck
      verdict <- liftAff
        (SecondOracle.checkOutputRef secondOracleDeps outputRef factsRoot)
      H.modify_ (Facts.finishSecondOracleCheck verdict)

secondOracleDeps :: SecondOracle.SecondOracleDeps
secondOracleDeps =
  { getMerkleRoots: client.getMerkleRoots
  , getProof: client.getProof
  , verifyInclusion: CsmtVerify.verifyInclusion
  }
  where
  client = SecondOracleClient.defaultClient

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

type BuildWrite =
  Client.Client
  -> WalletAddr
  -> CageConfig
  -> AppState
  -> Either String CageResult

runWriteOperation
  :: forall slots output m
   . MonadAff m
  => Write.WriteOperation
  -> BuildWrite
  -> H.HalogenM AppState Action slots output m Unit
runWriteOperation operation buildWrite = do
  state <- H.get
  case Write.validatePrerequisites operation state of
    Left message ->
      H.modify_ (Write.failWrite message)
    Right _ ->
      case state.walletSession.api, state.walletSession.selectedAddress of
        Just api, Just address ->
          case
            buildWrite
              (Client.mkClient state.baseUrl)
              (WalletAddr address)
              AppConfig.defaultCageConfig
              state
            of
            Left message ->
              H.modify_ (Write.failWrite message)
            Right build ->
              runWritePipeline operation api (Client.mkClient state.baseUrl) build
        _, _ ->
          H.modify_ (Write.failWrite "Connect a wallet first.")

runWritePipeline
  :: forall slots output m
   . MonadAff m
  => Write.WriteOperation
  -> Cip30.WalletApi
  -> Client.Client
  -> CageResult
  -> H.HalogenM AppState Action slots output m Unit
runWritePipeline operation api client build = do
  initial <- H.get
  H.modify_ _ { writeStatus = WriteBuilding }
  built <- liftAff build
  case built of
    Left err ->
      H.modify_ (Write.failWrite (cageErrorMessage err))
    Right unsigned@(UnsignedTxCbor unsignedHex) -> do
      H.modify_ _ { writeStatus = WriteBuilt unsigned }
      H.modify_ _ { writeStatus = WriteSigning unsigned }
      signed <- liftAff $ attempt (Cip30.signTx api unsignedHex true)
      case signed of
        Left _ ->
          H.modify_ (Write.failWrite "Wallet signing failed or was declined.")
        Right witnessSet -> do
          H.modify_ _ { writeStatus = WriteAssembling unsigned witnessSet }
          assembled <- liftAff (CageWasm.assembleTx unsignedHex witnessSet)
          case assembled of
            Left err ->
              H.modify_ (Write.failWrite (cageErrorMessage err))
            Right signedTx -> do
              H.modify_ _ { writeStatus = WriteSubmitting unsigned witnessSet signedTx }
              submitted <- liftAff (client.submitSignedTx signedTx)
              case submitted of
                Left error ->
                  H.modify_ (Write.failWrite (show error))
                Right txId -> do
                  let
                    keepToken =
                      case operation of
                        Write.WriteEndCage -> Nothing
                        _ -> initial.selectedToken
                  H.modify_ \current ->
                    current
                      { writeStatus =
                          Write.submittedWrite unsigned witnessSet signedTx txId
                      , selectedToken = keepToken
                      , selectedRequestIds = []
                      }
                  refreshAfterSubmit keepToken

refreshAfterSubmit
  :: forall slots output m
   . MonadAff m
  => Maybe TokenId
  -> H.HalogenM AppState Action slots output m Unit
refreshAfterSubmit mToken = do
  handleAction LoadTokens
  case mToken of
    Nothing ->
      pure unit
    Just _ ->
      handleAction LoadFacts

withSelectedToken
  :: AppState
  -> (TokenId -> Either String CageResult)
  -> Either String CageResult
withSelectedToken state f = case state.selectedToken of
  Nothing -> Left "Select a token first."
  Just token -> f token
