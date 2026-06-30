module MPFS.App.View
  ( render
  , secondOracleStatusLabel
  , verificationStatusLabel
  ) where

import Prelude

import Data.Array as Array
import Data.Maybe (Maybe(..))
import Halogen as H
import Halogen.HTML as HH
import Halogen.HTML.Events as HE
import Halogen.HTML.Properties as HP
import MPFS.App.Facts (phaseLabel, requestPhase)
import MPFS.App.State (AppState, WalletStatus(..))
import MPFS.App.Tab (AppTab(..), allTabs, tabLabel, tabSlug)
import MPFS.App.Verification (VerificationStatus(..))
import MPFS.App.Write as Write
import MPFS.App.Write (WriteStatus(..))
import MPFS.Client.Types (FactEntry, PendingRequest, TokenState)
import MPFS.SecondOracle.Types
  ( SecondOracleUnavailable(..)
  , SecondOracleVerdict(..)
  )
import MPFS.Types (RequestId, TokenId(..), TrustedRoot(..))
import MPFS.UI.Remote (Remote(..), remoteStatus)
import MPFS.Wallet.Cip30 (WalletInfo)

type AppActions action =
  { loadWallets :: action
  , connectWallet :: WalletInfo -> action
  , refreshWallet :: action
  , disconnectWallet :: action
  , loadTokens :: action
  , loadFacts :: action
  , registerToken :: action
  , updateInsertKey :: String -> action
  , updateInsertValue :: String -> action
  , submitInsertFact :: action
  , updateUpdateKey :: String -> action
  , updateUpdateOldValue :: String -> action
  , updateUpdateNewValue :: String -> action
  , submitUpdateFact :: action
  , updateDeleteKey :: String -> action
  , updateDeleteValue :: String -> action
  , submitDeleteFact :: action
  , toggleRequestSelection :: RequestId -> action
  , retractRequest :: RequestId -> action
  , rejectExpired :: action
  , updateToken :: action
  , endCage :: action
  , lookupFact :: action
  , selectTab :: AppTab -> action
  , selectToken :: TokenId -> action
  , updateFactLookupKey :: String -> action
  , updateFactProofEnvelope :: String -> action
  , verifyFactEnvelope :: action
  }

render
  :: forall action m
   . AppActions action
  -> AppState
  -> H.ComponentHTML action () m
render actions state =
  HH.main
    [ HP.class_ (HH.ClassName "app-shell") ]
    [ header state
    , HH.nav
        [ HP.class_ (HH.ClassName "tab-strip")
        , HP.attr (HH.AttrName "aria-label") "MPFS workbench tabs"
        ]
        (map (tabButton actions.selectTab state.activeTab) allTabs)
    , HH.section
        [ HP.class_ (HH.ClassName "panel")
        , HP.attr (HH.AttrName "aria-live") "polite"
        ]
        [ tabPanel actions state ]
    ]

header :: forall action m. AppState -> H.ComponentHTML action () m
header state =
  HH.header
    [ HP.class_ (HH.ClassName "shell-header") ]
    [ HH.div_
        [ HH.p
            [ HP.class_ (HH.ClassName "eyebrow") ]
            [ HH.text "MPFS Browser" ]
        , HH.h1_ [ HH.text "Fact workbench" ]
        ]
    , HH.div
        [ HP.class_ (HH.ClassName "status-row") ]
        [ statusPill "Client" state.baseUrl
        , statusPill "Wallet" (walletSessionLabel state)
        , statusPill "Token" (selectedTokenLabel state.selectedToken)
        ]
    ]

tabButton
  :: forall action m
   . (AppTab -> action)
  -> AppTab
  -> AppTab
  -> H.ComponentHTML action () m
tabButton toAction activeTab tab =
  HH.button
    [ HP.type_ HP.ButtonButton
    , HP.classes (map HH.ClassName classes)
    , HP.attr (HH.AttrName "aria-selected") selected
    , HP.attr (HH.AttrName "data-tab") (tabSlug tab)
    , HE.onClick \_ -> toAction tab
    ]
    [ HH.span
        [ HP.class_ (HH.ClassName "tab-marker") ]
        []
    , HH.text (tabLabel tab)
    ]
  where
  isActive = activeTab == tab

  selected =
    if isActive then "true" else "false"

  classes =
    if isActive then
      [ "tab-button", "is-active" ]
    else
      [ "tab-button" ]

tabPanel :: forall action m. AppActions action -> AppState -> H.ComponentHTML action () m
tabPanel actions state = case state.activeTab of
  ConnectTab -> connectPanel actions state
  TokensTab -> tokensPanel actions state
  FactsTab -> factsPanel actions state
  EndTab -> endPanel actions state

connectPanel
  :: forall action m
   . AppActions action
  -> AppState
  -> H.ComponentHTML action () m
connectPanel actions state =
  panelLayout "Connect" "Wallet session"
    [ fieldLine "Session" (walletSessionLabel state)
    , fieldLine "Network" (maybeText state.walletSession.network)
    , fieldLine "Address" (maybeText state.walletSession.selectedAddress)
    , fieldLine "Balance" (lovelaceText state.walletSession.lovelace)
    , walletFeedback state.walletSession.feedback
    , walletControls actions state
    ]

tokensPanel
  :: forall action m
   . AppActions action
  -> AppState
  -> H.ComponentHTML action () m
tokensPanel actions state =
  panelLayout "Tokens" "Token registry"
    [ fieldLine "Token list" (remoteStatus state.tokens)
    , fieldLine "Selected token" (selectedTokenLabel state.selectedToken)
    , tokenRemoteView actions state.selectedToken state.tokens
    , writeStatusView state.writeStatus
    , HH.div
        [ HP.class_ (HH.ClassName "control-row") ]
        [ HH.button
            [ HP.type_ HP.ButtonButton
            , HP.class_ (HH.ClassName "primary-button")
            , HP.disabled (state.tokens == Loading)
            , HE.onClick \_ -> actions.loadTokens
            ]
            [ HH.text (tokenLoadLabel state.tokens) ]
        , HH.button
            [ HP.type_ HP.ButtonButton
            , HP.class_ (HH.ClassName "primary-button")
            , HP.disabled (not (canWriteWithoutToken state))
            , HE.onClick \_ -> actions.registerToken
            ]
            [ HH.text "Register token" ]
        ]
    ]

factsPanel
  :: forall action m
   . AppActions action
  -> AppState
  -> H.ComponentHTML action () m
factsPanel actions state =
  panelLayout "Facts" "Selected token facts"
    [ fieldLine "Token" (selectedTokenLabel state.selectedToken)
    , fieldLine "Token state" (remoteStatus state.tokenState)
    , fieldLine "Pending requests" (remoteStatus state.pendingRequests)
    , fieldLine "Facts" (remoteStatus state.facts)
    , fieldLine "Trusted root" (remoteStatus state.trustedRoot)
    , fieldLine "Second oracle" (secondOracleStatusLabel state.secondOracle)
    , tokenStateRemoteView state.tokenState
    , trustedRootRemoteView state.trustedRoot
    , pendingRequestsRemoteView
        actions
        state.requestNowMillis
        state.tokenState
        state.selectedRequestIds
        state.pendingRequests
    , factsRemoteView state.facts
    , factLookupView actions state
    , factWriteForms actions state
    , writeStatusView state.writeStatus
    , HH.div
        [ HP.class_ (HH.ClassName "control-row") ]
        [ HH.button
            [ HP.type_ HP.ButtonButton
            , HP.class_ (HH.ClassName "primary-button")
            , HP.disabled
                ( state.selectedToken == Nothing
                    || remoteIsLoading state.facts
                    || remoteIsLoading state.tokenState
                    || remoteIsLoading state.pendingRequests
                )
            , HE.onClick \_ -> actions.loadFacts
            ]
            [ HH.text (factsLoadLabel state.facts) ]
        , HH.button
            [ HP.type_ HP.ButtonButton
            , HP.class_ (HH.ClassName "primary-button")
            , HP.disabled (not (canWriteSelected state))
            , HE.onClick \_ -> actions.updateToken
            ]
            [ HH.text "Process selected" ]
        , HH.button
            [ HP.type_ HP.ButtonButton
            , HP.class_ (HH.ClassName "inert-button")
            , HP.disabled (not (canWriteSelected state))
            , HE.onClick \_ -> actions.rejectExpired
            ]
            [ HH.text "Reject expired" ]
        ]
    ]

endPanel :: forall action m. AppActions action -> AppState -> H.ComponentHTML action () m
endPanel actions state =
  panelLayout "End" "Cage lifecycle"
    [ fieldLine "Token" (selectedTokenLabel state.selectedToken)
    , fieldLine "Wallet" (walletSessionLabel state)
    , fieldLine "Wallet network" (maybeText state.walletSession.network)
    , fieldLine "Wallet address" (maybeText state.walletSession.selectedAddress)
    , writeStatusView state.writeStatus
    , HH.div
        [ HP.class_ (HH.ClassName "control-row") ]
        [ HH.button
            [ HP.type_ HP.ButtonButton
            , HP.class_ (HH.ClassName "primary-button")
            , HP.disabled (not (canWriteSelected state))
            , HE.onClick \_ -> actions.endCage
            ]
            [ HH.text "End cage" ]
        ]
    ]

panelLayout
  :: forall action m
   . String
  -> String
  -> Array (H.ComponentHTML action () m)
  -> H.ComponentHTML action () m
panelLayout title subtitle children =
  HH.div
    [ HP.class_ (HH.ClassName "panel-layout") ]
    ( [ HH.div
          [ HP.class_ (HH.ClassName "panel-heading") ]
          [ HH.h2_ [ HH.text title ]
          , HH.p_ [ HH.text subtitle ]
          ]
      ]
        <> children
    )

fieldLine :: forall action m. String -> String -> H.ComponentHTML action () m
fieldLine label value =
  HH.div
    [ HP.class_ (HH.ClassName "field-line") ]
    [ HH.span_ [ HH.text label ]
    , HH.strong_ [ HH.text value ]
    ]

statusPill :: forall action m. String -> String -> H.ComponentHTML action () m
statusPill label value =
  HH.div
    [ HP.class_ (HH.ClassName "status-pill") ]
    [ HH.span_ [ HH.text label ]
    , HH.strong_ [ HH.text value ]
    ]

tokenRemoteView
  :: forall action m
   . AppActions action
  -> Maybe TokenId
  -> Remote (Array TokenId)
  -> H.ComponentHTML action () m
tokenRemoteView actions selectedToken = case _ of
  NotAsked ->
    HH.p
      [ HP.class_ (HH.ClassName "empty-state") ]
      [ HH.text "Tokens have not been loaded." ]
  Loading ->
    HH.p
      [ HP.class_ (HH.ClassName "loading-state") ]
      [ HH.text "Loading tokens..." ]
  Failure message ->
    HH.p
      [ HP.class_ (HH.ClassName "error-state") ]
      [ HH.text ("Error loading tokens: " <> message) ]
  Success tokens
    | Array.null tokens ->
        HH.p
          [ HP.class_ (HH.ClassName "empty-state") ]
          [ HH.text "No tokens registered." ]
    | otherwise ->
        HH.ul
          [ HP.class_ (HH.ClassName "token-list") ]
          (map (tokenRow actions selectedToken) tokens)

walletControls
  :: forall action m
   . AppActions action
  -> AppState
  -> H.ComponentHTML action () m
walletControls actions state = case state.walletSession.status of
  WalletConnected ->
    HH.div
      [ HP.class_ (HH.ClassName "control-row") ]
      [ HH.button
          [ HP.type_ HP.ButtonButton
          , HP.class_ (HH.ClassName "primary-button")
          , HE.onClick \_ -> actions.refreshWallet
          ]
          [ HH.text "Refresh wallet" ]
      , HH.button
          [ HP.type_ HP.ButtonButton
          , HP.class_ (HH.ClassName "inert-button")
          , HE.onClick \_ -> actions.disconnectWallet
          ]
          [ HH.text "Disconnect" ]
      ]
  _ ->
    HH.div_
      [ walletRemoteView actions state.walletSession.status
          state.walletSession.wallets
      , HH.div
          [ HP.class_ (HH.ClassName "control-row") ]
          [ HH.button
              [ HP.type_ HP.ButtonButton
              , HP.class_ (HH.ClassName "primary-button")
              , HP.disabled (state.walletSession.wallets == Loading)
              , HE.onClick \_ -> actions.loadWallets
              ]
              [ HH.text (walletDiscoveryLabel state.walletSession.wallets) ]
          ]
      ]

walletRemoteView
  :: forall action m
   . AppActions action
  -> WalletStatus
  -> Remote (Array WalletInfo)
  -> H.ComponentHTML action () m
walletRemoteView actions status = case _ of
  NotAsked ->
    HH.p
      [ HP.class_ (HH.ClassName "empty-state") ]
      [ HH.text "Wallet discovery has not run." ]
  Loading ->
    HH.p
      [ HP.class_ (HH.ClassName "loading-state") ]
      [ HH.text "Looking for CIP-30 wallets..." ]
  Failure message ->
    HH.p
      [ HP.class_ (HH.ClassName "error-state") ]
      [ HH.text ("Error discovering wallets: " <> message) ]
  Success wallets
    | Array.null wallets ->
        HH.p
          [ HP.class_ (HH.ClassName "empty-state") ]
          [ HH.text "No CIP-30 wallet found." ]
    | otherwise ->
        HH.ul
          [ HP.class_ (HH.ClassName "token-list") ]
          (map (walletRow actions status) wallets)

walletRow
  :: forall action m
   . AppActions action
  -> WalletStatus
  -> WalletInfo
  -> H.ComponentHTML action () m
walletRow actions status wallet =
  HH.li
    [ HP.attr (HH.AttrName "data-wallet") wallet.key ]
    [ HH.strong_ [ HH.text wallet.name ]
    , HH.button
        [ HP.type_ HP.ButtonButton
        , HP.class_ (HH.ClassName "primary-button")
        , HP.disabled (status == WalletConnecting)
        , HE.onClick \_ -> actions.connectWallet wallet
        ]
        [ HH.text
            if status == WalletConnecting then
              "Connecting"
            else
              "Connect"
        ]
    ]

walletFeedback
  :: forall action m
   . Maybe String
  -> H.ComponentHTML action () m
walletFeedback = case _ of
  Nothing ->
    HH.text ""
  Just message ->
    HH.p
      [ HP.class_ (HH.ClassName "empty-state") ]
      [ HH.text message ]

tokenStateRemoteView
  :: forall action m
   . Remote TokenState
  -> H.ComponentHTML action () m
tokenStateRemoteView = case _ of
  NotAsked ->
    HH.p
      [ HP.class_ (HH.ClassName "empty-state") ]
      [ HH.text "Token state has not been loaded." ]
  Loading ->
    HH.p
      [ HP.class_ (HH.ClassName "loading-state") ]
      [ HH.text "Loading token state..." ]
  Failure message ->
    HH.p
      [ HP.class_ (HH.ClassName "error-state") ]
      [ HH.text ("Error loading token state: " <> message) ]
  Success tokenState ->
    HH.div
      [ HP.class_ (HH.ClassName "field-group") ]
      [ fieldLine "Owner" (shortText tokenState.owner)
      , fieldLine "Root" (shortText tokenState.root)
      , fieldLine "Max fee" (show tokenState.max_fee)
      , fieldLine "Process window" (show tokenState.process_time)
      , fieldLine "Retract window" (show tokenState.retract_time)
      ]

trustedRootRemoteView
  :: forall action m
   . Remote TrustedRoot
  -> H.ComponentHTML action () m
trustedRootRemoteView = case _ of
  NotAsked ->
    HH.p
      [ HP.class_ (HH.ClassName "empty-state") ]
      [ HH.text "Trusted root has not been loaded." ]
  Loading ->
    HH.p
      [ HP.class_ (HH.ClassName "loading-state") ]
      [ HH.text "Loading trusted root..." ]
  Failure message ->
    HH.p
      [ HP.class_ (HH.ClassName "error-state") ]
      [ HH.text ("Error loading trusted root: " <> message) ]
  Success (TrustedRoot trustedRoot) ->
    fieldLine "Trusted root hash" (shortText trustedRoot)

pendingRequestsRemoteView
  :: forall action m
   . AppActions action
  -> Number
  -> Remote TokenState
  -> Array RequestId
  -> Remote (Array PendingRequest)
  -> H.ComponentHTML action () m
pendingRequestsRemoteView actions nowMillis tokenStateRemote selectedRequestIds = case _ of
  NotAsked ->
    HH.p
      [ HP.class_ (HH.ClassName "empty-state") ]
      [ HH.text "Pending requests have not been loaded." ]
  Loading ->
    HH.p
      [ HP.class_ (HH.ClassName "loading-state") ]
      [ HH.text "Loading pending requests..." ]
  Failure message ->
    HH.p
      [ HP.class_ (HH.ClassName "error-state") ]
      [ HH.text ("Error loading pending requests: " <> message) ]
  Success requests
    | Array.null requests ->
        HH.p
          [ HP.class_ (HH.ClassName "empty-state") ]
          [ HH.text "No pending requests." ]
    | otherwise ->
        case tokenStateRemote of
          Success tokenState ->
            HH.ul
              [ HP.class_ (HH.ClassName "token-list") ]
              (map (requestRow actions nowMillis tokenState selectedRequestIds) requests)
          _ ->
            HH.p
              [ HP.class_ (HH.ClassName "empty-state") ]
              [ HH.text "Token state is required for request phases." ]

factsRemoteView
  :: forall action m
   . Remote (Array FactEntry)
  -> H.ComponentHTML action () m
factsRemoteView = case _ of
  NotAsked ->
    HH.p
      [ HP.class_ (HH.ClassName "empty-state") ]
      [ HH.text "Facts have not been loaded." ]
  Loading ->
    HH.p
      [ HP.class_ (HH.ClassName "loading-state") ]
      [ HH.text "Loading facts..." ]
  Failure message ->
    HH.p
      [ HP.class_ (HH.ClassName "error-state") ]
      [ HH.text ("Error loading facts: " <> message) ]
  Success facts
    | Array.null facts ->
        HH.p
          [ HP.class_ (HH.ClassName "empty-state") ]
          [ HH.text "No facts found." ]
    | otherwise ->
        HH.ul
          [ HP.class_ (HH.ClassName "token-list") ]
          (map factRow facts)

factLookupView
  :: forall action m
   . AppActions action
  -> AppState
  -> H.ComponentHTML action () m
factLookupView actions state =
  HH.div
    [ HP.class_ (HH.ClassName "field-group") ]
    [ HH.div
        [ HP.class_ (HH.ClassName "control-row") ]
        [ HH.input
            [ HP.type_ HP.InputText
            , HP.value state.factLookup.key
            , HP.placeholder "Fact key"
            , HE.onValueInput actions.updateFactLookupKey
            ]
        , HH.button
            [ HP.type_ HP.ButtonButton
            , HP.class_ (HH.ClassName "primary-button")
            , HP.disabled
                ( state.selectedToken == Nothing
                    || state.factLookup.key == ""
                    || remoteIsLoading state.factLookup.value
                )
            , HE.onClick \_ -> actions.lookupFact
            ]
            [ HH.text "Look up" ]
        ]
    , factLookupRemoteView state.factLookup.value
    , HH.textarea
        [ HP.value state.factLookup.proofEnvelope
        , HP.rows 4
        , HP.placeholder "Proof envelope"
        , HE.onValueInput actions.updateFactProofEnvelope
        ]
    , HH.div
        [ HP.class_ (HH.ClassName "control-row") ]
        [ HH.button
            [ HP.type_ HP.ButtonButton
            , HP.class_ (HH.ClassName "primary-button")
            , HP.disabled
                ( state.factLookup.proofEnvelope == ""
                    || state.factLookup.verification == VerificationLoading
                )
            , HE.onClick \_ -> actions.verifyFactEnvelope
            ]
            [ HH.text "Verify proof" ]
        , fieldLine
            "Verification"
            (verificationStatusLabel state.factLookup.verification)
        ]
    ]

factWriteForms
  :: forall action m
   . AppActions action
  -> AppState
  -> H.ComponentHTML action () m
factWriteForms actions state =
  HH.div
    [ HP.class_ (HH.ClassName "field-group") ]
    [ HH.div
        [ HP.class_ (HH.ClassName "control-row") ]
        [ HH.input
            [ HP.type_ HP.InputText
            , HP.value state.writeForms.insertKey
            , HP.placeholder "Insert key"
            , HE.onValueInput actions.updateInsertKey
            ]
        , HH.input
            [ HP.type_ HP.InputText
            , HP.value state.writeForms.insertValue
            , HP.placeholder "Insert value"
            , HE.onValueInput actions.updateInsertValue
            ]
        , HH.button
            [ HP.type_ HP.ButtonButton
            , HP.class_ (HH.ClassName "primary-button")
            , HP.disabled
                ( not (canWriteSelected state)
                    || state.writeForms.insertKey == ""
                    || state.writeForms.insertValue == ""
                )
            , HE.onClick \_ -> actions.submitInsertFact
            ]
            [ HH.text "Insert fact" ]
        ]
    , HH.div
        [ HP.class_ (HH.ClassName "control-row") ]
        [ HH.input
            [ HP.type_ HP.InputText
            , HP.value state.writeForms.updateKey
            , HP.placeholder "Update key"
            , HE.onValueInput actions.updateUpdateKey
            ]
        , HH.input
            [ HP.type_ HP.InputText
            , HP.value state.writeForms.updateOldValue
            , HP.placeholder "Old value"
            , HE.onValueInput actions.updateUpdateOldValue
            ]
        , HH.input
            [ HP.type_ HP.InputText
            , HP.value state.writeForms.updateNewValue
            , HP.placeholder "New value"
            , HE.onValueInput actions.updateUpdateNewValue
            ]
        , HH.button
            [ HP.type_ HP.ButtonButton
            , HP.class_ (HH.ClassName "primary-button")
            , HP.disabled
                ( not (canWriteSelected state)
                    || state.writeForms.updateKey == ""
                    || state.writeForms.updateOldValue == ""
                    || state.writeForms.updateNewValue == ""
                )
            , HE.onClick \_ -> actions.submitUpdateFact
            ]
            [ HH.text "Update fact" ]
        ]
    , HH.div
        [ HP.class_ (HH.ClassName "control-row") ]
        [ HH.input
            [ HP.type_ HP.InputText
            , HP.value state.writeForms.deleteKey
            , HP.placeholder "Delete key"
            , HE.onValueInput actions.updateDeleteKey
            ]
        , HH.input
            [ HP.type_ HP.InputText
            , HP.value state.writeForms.deleteValue
            , HP.placeholder "Delete value"
            , HE.onValueInput actions.updateDeleteValue
            ]
        , HH.button
            [ HP.type_ HP.ButtonButton
            , HP.class_ (HH.ClassName "primary-button")
            , HP.disabled
                ( not (canWriteSelected state)
                    || state.writeForms.deleteKey == ""
                    || state.writeForms.deleteValue == ""
                )
            , HE.onClick \_ -> actions.submitDeleteFact
            ]
            [ HH.text "Delete fact" ]
        ]
    ]

factLookupRemoteView
  :: forall action m
   . Remote String
  -> H.ComponentHTML action () m
factLookupRemoteView = case _ of
  NotAsked ->
    HH.p
      [ HP.class_ (HH.ClassName "empty-state") ]
      [ HH.text "No fact lookup has run." ]
  Loading ->
    HH.p
      [ HP.class_ (HH.ClassName "loading-state") ]
      [ HH.text "Looking up fact..." ]
  Failure message ->
    HH.p
      [ HP.class_ (HH.ClassName "error-state") ]
      [ HH.text ("Error looking up fact: " <> message) ]
  Success value ->
    fieldLine "Lookup value" value

requestRow
  :: forall action m
   . AppActions action
  -> Number
  -> TokenState
  -> Array RequestId
  -> PendingRequest
  -> H.ComponentHTML action () m
requestRow actions nowMillis tokenState selectedRequestIds request =
  HH.li
    [ HP.attr (HH.AttrName "data-request-key") request.key ]
    ( [ HH.strong_ [ HH.text request.operation ]
      , HH.span_ [ HH.text (" key " <> request.key) ]
      , HH.span_ [ HH.text (" value " <> requestValueText request) ]
      , HH.span_
          [ HH.text
              ( " phase "
                  <> phaseLabel (requestPhase nowMillis tokenState request)
              )
          ]
      ]
        <> requestControls
    )
  where
  requestControls = case Write.requestIdOf request of
    Nothing ->
      [ HH.span_ [ HH.text " missing request id" ] ]
    Just requestId ->
      [ HH.button
          [ HP.type_ HP.ButtonButton
          , HP.class_ (HH.ClassName "inert-button")
          , HE.onClick \_ -> actions.toggleRequestSelection requestId
          ]
          [ HH.text
              if Array.elem requestId selectedRequestIds then
                "Selected"
              else
                "Select"
          ]
      , HH.button
          [ HP.type_ HP.ButtonButton
          , HP.class_ (HH.ClassName "inert-button")
          , HE.onClick \_ -> actions.retractRequest requestId
          ]
          [ HH.text "Retract" ]
      ]

factRow :: forall action m. FactEntry -> H.ComponentHTML action () m
factRow fact =
  HH.li
    [ HP.attr (HH.AttrName "data-fact-key") fact.key ]
    [ HH.strong_ [ HH.text fact.key ]
    , HH.span_ [ HH.text (" " <> fact.value) ]
    ]

tokenRow
  :: forall action m
   . AppActions action
  -> Maybe TokenId
  -> TokenId
  -> H.ComponentHTML action () m
tokenRow actions selectedToken token@(TokenId tokenId) =
  HH.li
    [ HP.attr (HH.AttrName "data-token") tokenId ]
    [ HH.button
        [ HP.type_ HP.ButtonButton
        , HP.classes (map HH.ClassName classes)
        , HP.attr (HH.AttrName "aria-pressed") pressed
        , HE.onClick \_ -> actions.selectToken token
        ]
        [ HH.text tokenId ]
    ]
  where
  isSelected = selectedToken == Just token

  pressed =
    if isSelected then "true" else "false"

  classes =
    if isSelected then
      [ "token-row", "is-selected" ]
    else
      [ "token-row" ]

tokenLoadLabel :: forall a. Remote a -> String
tokenLoadLabel = case _ of
  NotAsked -> "Load tokens"
  Loading -> "Loading tokens"
  Failure _ -> "Refresh tokens"
  Success _ -> "Refresh tokens"

factsLoadLabel :: forall a. Remote a -> String
factsLoadLabel = case _ of
  NotAsked -> "Load facts"
  Loading -> "Loading facts"
  Failure _ -> "Refresh facts"
  Success _ -> "Refresh facts"

walletDiscoveryLabel :: forall a. Remote a -> String
walletDiscoveryLabel = case _ of
  NotAsked -> "Find wallets"
  Loading -> "Finding wallets"
  Failure _ -> "Refresh wallets"
  Success _ -> "Refresh wallets"

remoteIsLoading :: forall a. Remote a -> Boolean
remoteIsLoading = case _ of
  Loading -> true
  _ -> false

writeStatusView :: forall action m. WriteStatus -> H.ComponentHTML action () m
writeStatusView = case _ of
  WriteIdle ->
    HH.text ""
  WriteBuilding ->
    HH.p [ HP.class_ (HH.ClassName "loading-state") ] [ HH.text "Building transaction..." ]
  WriteBuilt _ ->
    HH.p [ HP.class_ (HH.ClassName "loading-state") ] [ HH.text "Unsigned transaction built." ]
  WriteSigning _ ->
    HH.p [ HP.class_ (HH.ClassName "loading-state") ] [ HH.text "Waiting for wallet signature..." ]
  WriteAssembling _ _ ->
    HH.p [ HP.class_ (HH.ClassName "loading-state") ] [ HH.text "Assembling signed transaction..." ]
  WriteSubmitting _ _ _ ->
    HH.p [ HP.class_ (HH.ClassName "loading-state") ] [ HH.text "Submitting transaction..." ]
  WriteSubmitted _ _ _ txId ->
    HH.p [ HP.class_ (HH.ClassName "empty-state") ] [ HH.text ("Submitted transaction " <> txId) ]
  WriteFailed message ->
    HH.p [ HP.class_ (HH.ClassName "error-state") ] [ HH.text message ]

writeBusy :: WriteStatus -> Boolean
writeBusy = case _ of
  WriteBuilding -> true
  WriteBuilt _ -> true
  WriteSigning _ -> true
  WriteAssembling _ _ -> true
  WriteSubmitting _ _ _ -> true
  _ -> false

canWriteWithoutToken :: AppState -> Boolean
canWriteWithoutToken state =
  state.walletSession.status == WalletConnected
    && state.walletSession.selectedAddress /= Nothing
    && not (writeBusy state.writeStatus)

canWriteSelected :: AppState -> Boolean
canWriteSelected state =
  canWriteWithoutToken state && state.selectedToken /= Nothing

verificationStatusLabel :: VerificationStatus -> String
verificationStatusLabel = case _ of
  VerificationNotAsked -> "Not verified"
  VerificationLoading -> "Verifying"
  VerificationVerified -> "Verified"
  VerificationFailed message -> "Rejected: " <> message

secondOracleStatusLabel :: Remote SecondOracleVerdict -> String
secondOracleStatusLabel = case _ of
  NotAsked -> "Not checked"
  Loading -> "Checking second oracle"
  Failure message -> message
  Success verdict -> secondOracleVerdictLabel verdict

secondOracleVerdictLabel :: SecondOracleVerdict -> String
secondOracleVerdictLabel = case _ of
  SecondOracleVerified _ ->
    "Verified"
  SecondOracleMismatch _ ->
    "Mismatch"
  SecondOracleMissingRoot _ ->
    "Merkle root missing"
  SecondOracleMalformedDatum message ->
    "Malformed datum: " <> message
  SecondOracleUnavailable unavailable ->
    "Oracle unavailable: " <> secondOracleUnavailableMessage unavailable

secondOracleUnavailableMessage :: SecondOracleUnavailable -> String
secondOracleUnavailableMessage = case _ of
  MerkleRootsUnavailable message -> message
  ProofUnavailable message -> message

requestValueText :: PendingRequest -> String
requestValueText request = case request.value of
  Nothing -> "none"
  Just value -> value

shortText :: String -> String
shortText = identity

walletStatusLabel :: WalletStatus -> String
walletStatusLabel = case _ of
  WalletDisconnected -> "Not connected"
  WalletConnecting -> "Connecting"
  WalletConnected -> "Connected"

walletSessionLabel :: AppState -> String
walletSessionLabel state = case state.walletSession.status, state.walletSession.walletName of
  WalletConnected, Just name -> "Connected: " <> name
  WalletConnecting, Just name -> "Connecting: " <> name
  _, _ -> walletStatusLabel state.walletSession.status

lovelaceText :: Maybe String -> String
lovelaceText = case _ of
  Nothing -> "Unavailable"
  Just value -> value <> " lovelace"

selectedTokenLabel :: Maybe TokenId -> String
selectedTokenLabel = case _ of
  Nothing -> "None"
  Just (TokenId tokenId) -> tokenId

maybeText :: Maybe String -> String
maybeText = case _ of
  Nothing -> "Unavailable"
  Just value -> value
