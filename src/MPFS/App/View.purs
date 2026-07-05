module MPFS.App.View
  ( render
  , factsSetStatusLabel
  , pendingRequestsStatusLabel
  , secondOracleStatusLabel
  , tokenCompletenessStatusLabel
  , verificationStatusLabel
  ) where

import Prelude

import Data.Array as Array
import Data.Maybe (Maybe(..), fromMaybe)
import Data.String.CodeUnits as CodeUnits
import Data.String.Common as String
import Data.String.Pattern (Pattern(..))
import Effect.Aff.Class (class MonadAff)
import Halogen as H
import Halogen.HTML as HH
import Halogen.HTML.Events as HE
import Halogen.HTML.Properties as HP
import MPFS.App.Facts as Facts
import MPFS.App.Pending as Pending
import MPFS.App.Proof as Proof
import MPFS.App.State (AppState, ProofDrawer(..), WalletStatus(..))
import MPFS.App.Tab (AppTab(..), allTabs, tabLabel, tabSlug)
import MPFS.App.Verification (VerificationStatus(..))
import MPFS.App.Write (WriteStatus(..))
import MPFS.Client.Types (FactEntry, PendingRequest, TokenState)
import MPFS.SecondOracle.Types
  ( SecondOracleUnavailable(..)
  , SecondOracleVerdict(..)
  )
import MPFS.Types (RequestId(..), TokenId(..), TrustedRoot(..))
import MPFS.UI.Material.Chip as Chip
import MPFS.UI.Material.CopyButton as CopyButton
import MPFS.UI.Material.DataTable as DataTable
import MPFS.UI.Material.HashChip as HashChip
import MPFS.UI.Material.Paper as Paper
import MPFS.UI.Material.StatusChip as StatusChip
import MPFS.UI.Remote (Remote(..))
import MPFS.Wallet.Cip30 (WalletInfo)
import Type.Proxy (Proxy(..))

type Slots =
  ( copyButton :: forall query. H.Slot query Void String
  , hashChip :: forall query. H.Slot query Void String
  )

_copyButton :: Proxy "copyButton"
_copyButton = Proxy

_hashChip :: Proxy "hashChip"
_hashChip = Proxy

type AppActions action =
  { loadWallets :: action
  , connectWallet :: WalletInfo -> action
  , refreshWallet :: action
  , disconnectWallet :: action
  , loadTokens :: action
  , updateTokenSearch :: String -> action
  , toggleMineOnly :: action
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
  , openSetProofDrawer :: action
  , openFactProofDrawer :: FactEntry -> action
  , openRequestProofDrawer :: PendingRequest -> action
  , closeProofDrawer :: action
  , lookupFact :: action
  , selectTab :: AppTab -> action
  , selectToken :: TokenId -> action
  , updateFactLookupKey :: String -> action
  , updateFactProofEnvelope :: String -> action
  , verifyFactEnvelope :: action
  }

render
  :: forall action m
   . MonadAff m
  => AppActions action
  -> AppState
  -> H.ComponentHTML action Slots m
render actions state =
  HH.div
    [ HP.class_ (HH.ClassName "mpfs-shell") ]
    [ appBar actions state
    , HH.div
        [ HP.class_ (HH.ClassName "app-layout") ]
        [ tokenSidebar actions state
        , workspace actions state
        ]
    , proofDrawer actions state
    ]

appBar
  :: forall action m
   . MonadAff m
  => AppActions action
  -> AppState
  -> H.ComponentHTML action Slots m
appBar actions state =
  HH.header
    [ HP.class_ (HH.ClassName "app-bar") ]
    [ HH.div
        [ HP.class_ (HH.ClassName "brand-lockup") ]
        [ HH.div [ HP.class_ (HH.ClassName "brand-mark") ] [ HH.span_ [ HH.text "M" ] ]
        , HH.div [ HP.class_ (HH.ClassName "brand-name") ] [ HH.text "MPFS Browser" ]
        ]
    , HH.div
        [ HP.class_ (HH.ClassName "app-bar__meta") ]
        [ networkPill state
        , endpointChip state.baseUrl
        , walletControl actions state
        ]
    ]

networkPill :: forall action m. AppState -> H.ComponentHTML action Slots m
networkPill state =
  HH.span
    [ HP.class_ (HH.ClassName "network-pill") ]
    [ HH.span [ HP.class_ (HH.ClassName "status-dot status-dot--success") ] []
    , HH.text (fromMaybe "Preprod" state.walletSession.network)
    ]

endpointChip :: forall action m. String -> H.ComponentHTML action Slots m
endpointChip baseUrl =
  HH.span
    [ HP.class_ (HH.ClassName "endpoint-chip")
    , HP.title baseUrl
    ]
    [ HH.text baseUrl ]

walletControl
  :: forall action m
   . MonadAff m
  => AppActions action
  -> AppState
  -> H.ComponentHTML action Slots m
walletControl actions state = case state.walletSession.status of
  WalletConnected ->
    HH.div
      [ HP.class_ (HH.ClassName "wallet-chip")
      , HP.title "Connected wallet"
      ]
      [ HH.span [ HP.class_ (HH.ClassName "wallet-avatar") ] [ HH.text (walletInitial state) ]
      , HH.span [ HP.class_ (HH.ClassName "wallet-chip__name") ] [ HH.text (fromMaybe "Wallet" state.walletSession.walletName) ]
      , maybeHashInline "wallet-address" state.walletSession.selectedAddress
      ]
  WalletConnecting ->
    HH.button
      [ HP.type_ HP.ButtonButton
      , HP.class_ (HH.ClassName "wallet-connect")
      , HP.disabled true
      ]
      [ HH.text "Connecting" ]
  WalletDisconnected ->
    disconnectedWalletControl actions state

disconnectedWalletControl
  :: forall action m
   . AppActions action
  -> AppState
  -> H.ComponentHTML action Slots m
disconnectedWalletControl actions state = case state.walletSession.wallets of
  Success wallets ->
    case Array.head wallets of
      Just wallet ->
        HH.button
          [ HP.type_ HP.ButtonButton
          , HP.class_ (HH.ClassName "wallet-connect")
          , HE.onClick \_ -> actions.connectWallet wallet
          ]
          [ HH.text "Connect wallet" ]
      Nothing ->
        HH.button
          [ HP.type_ HP.ButtonButton
          , HP.class_ (HH.ClassName "wallet-connect")
          , HE.onClick \_ -> actions.loadWallets
          ]
          [ HH.text "Find wallet" ]
  Loading ->
    HH.button
      [ HP.type_ HP.ButtonButton
      , HP.class_ (HH.ClassName "wallet-connect")
      , HP.disabled true
      ]
      [ HH.text "Finding wallets" ]
  _ ->
    HH.button
      [ HP.type_ HP.ButtonButton
      , HP.class_ (HH.ClassName "wallet-connect")
      , HE.onClick \_ -> actions.loadWallets
      ]
      [ HH.text "Connect wallet" ]

tokenSidebar
  :: forall action m
   . MonadAff m
  => AppActions action
  -> AppState
  -> H.ComponentHTML action Slots m
tokenSidebar actions state =
  HH.aside
    [ HP.class_ (HH.ClassName "token-sidebar") ]
    [ HH.div
        [ HP.class_ (HH.ClassName "token-sidebar__controls") ]
        [ HH.div
            [ HP.class_ (HH.ClassName "sidebar-heading") ]
            [ HH.h2_ [ HH.text "Tokens" ]
            , HH.span_ [ HH.text (tokenCountLabel state.tokens) ]
            ]
        , HH.label
            [ HP.class_ (HH.ClassName "token-search") ]
            [ HH.span_ [ HH.text "Search" ]
            , HH.input
                [ HP.type_ HP.InputText
                , HP.value state.tokenSearch
                , HP.placeholder "Search token id or owner"
                , HE.onValueInput actions.updateTokenSearch
                ]
            ]
        , HH.button
            [ HP.type_ HP.ButtonButton
            , HP.classes (classNames [ "mine-toggle" ] state.tokenMineOnly [ "is-on" ])
            , HP.attr (HH.AttrName "aria-pressed") (boolAttr state.tokenMineOnly)
            , HE.onClick \_ -> actions.toggleMineOnly
            ]
            [ HH.span [ HP.class_ (HH.ClassName "mine-toggle__track") ] [ HH.span_ [] ]
            , HH.span_ [ HH.text "Owned by me" ]
            , HH.span [ HP.class_ (HH.ClassName "mine-toggle__count") ] [ HH.text (mineCountLabel state) ]
            ]
        ]
    , tokenList actions state
    , HH.div
        [ HP.class_ (HH.ClassName "token-sidebar__footer") ]
        ( [ HH.button
              [ HP.type_ HP.ButtonButton
              , HP.class_ (HH.ClassName "secondary-button")
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
              [ HH.text "Register" ]
          ]
            <> disabledReasonWhen
              (not (canWriteWithoutToken state))
              "Connect a wallet to register a token."
        )
    ]

tokenList
  :: forall action m
   . MonadAff m
  => AppActions action
  -> AppState
  -> H.ComponentHTML action Slots m
tokenList actions state =
  HH.div
    [ HP.class_ (HH.ClassName "token-list-scroll") ]
    case state.tokens of
      NotAsked ->
        [ emptyMessage "Tokens have not been loaded." ]
      Loading ->
        [ loadingMessage "Loading tokens..." ]
      Failure message ->
        [ errorMessage ("Error loading tokens: " <> message) ]
      Success tokens ->
        let
          visible = visibleTokens state tokens
        in
          if Array.null visible then
            [ emptyMessage ("No tokens match \"" <> state.tokenSearch <> "\".") ]
          else
            Array.mapWithIndex (tokenRow actions state) visible

tokenRow
  :: forall action m
   . MonadAff m
  => AppActions action
  -> AppState
  -> Int
  -> TokenId
  -> H.ComponentHTML action Slots m
tokenRow actions state index token@(TokenId tokenId) =
  HH.div
    [ HP.classes (classNames [ "token-row" ] active [ "is-active" ])
    , HP.attr (HH.AttrName "role") "button"
    , HP.attr (HH.AttrName "tabindex") "0"
    , HP.attr (HH.AttrName "aria-pressed") (boolAttr active)
    , HE.onClick \_ -> actions.selectToken token
    ]
    [ HH.div
        [ HP.class_ (HH.ClassName "token-row__top") ]
        [ HH.span [ HP.class_ (HH.ClassName "kind-dot") ] []
        , hashChip ("token-row-" <> show index <> "-" <> tokenId) tokenId
        , mineBadgeIf (tokenIsMine state token)
        ]
    , HH.div
        [ HP.class_ (HH.ClassName "token-row__meta") ]
        [ HH.span_ [ HH.text (factsCountFor state token) ]
        , HH.span [ HP.class_ (HH.ClassName "pending-count") ] [ HH.text (pendingCountFor state token) ]
        ]
    ]
  where
  active = state.selectedToken == Just token

workspace
  :: forall action m
   . MonadAff m
  => AppActions action
  -> AppState
  -> H.ComponentHTML action Slots m
workspace actions state =
  HH.main
    [ HP.class_ (HH.ClassName "workspace") ]
    case state.selectedToken of
      Nothing ->
        [ emptyWorkspace actions state ]
      Just token ->
        [ tokenHeader actions state token
        , summaryStrip state
        , workspaceTabs actions state
        , activePanel actions state
        ]

emptyWorkspace
  :: forall action m
   . AppActions action
  -> AppState
  -> H.ComponentHTML action Slots m
emptyWorkspace actions state =
  HH.section
    [ HP.class_ (HH.ClassName "placeholder-panel placeholder-panel--empty") ]
    [ HH.div [ HP.class_ (HH.ClassName "empty-glyph") ] [ HH.text "[]" ]
    , HH.h1_ [ HH.text "Select a token" ]
    , HH.p_ [ HH.text "Load the registry, then choose a token from the sidebar to inspect its state." ]
    , HH.button
        [ HP.type_ HP.ButtonButton
        , HP.class_ (HH.ClassName "primary-button")
        , HP.disabled (state.tokens == Loading)
        , HE.onClick \_ -> actions.loadTokens
        ]
        [ HH.text (tokenLoadLabel state.tokens) ]
    ]

tokenHeader
  :: forall action m
   . MonadAff m
  => AppActions action
  -> AppState
  -> TokenId
  -> H.ComponentHTML action Slots m
tokenHeader actions state (TokenId tokenId) =
  HH.section
    [ HP.class_ (HH.ClassName "token-header") ]
    [ HH.div
        [ HP.class_ (HH.ClassName "token-heading") ]
        [ HH.div
            [ HP.class_ (HH.ClassName "token-title-line") ]
            [ HH.h1_ [ HH.text "Token" ]
            , mineBadgeIf (tokenIsMine state (TokenId tokenId))
            , hashChip "workspace-token-id" tokenId
            ]
        , HH.div
            [ HP.class_ (HH.ClassName "owner-line") ]
            [ HH.span_ [ HH.text "Owner" ]
            , maybeHashInline "workspace-owner" (selectedTokenOwner state)
            ]
        ]
    , HH.div
        [ HP.class_ (HH.ClassName "token-header__actions") ]
        [ verdictPill actions state
        , HH.button
            [ HP.type_ HP.ButtonButton
            , HP.class_ (HH.ClassName "secondary-button")
            , HP.disabled (state.selectedToken == Nothing || remoteIsLoading state.facts)
            , HE.onClick \_ -> actions.loadFacts
            ]
            [ HH.text (factsLoadLabel state.facts) ]
        ]
    ]

summaryStrip :: forall action m. MonadAff m => AppState -> H.ComponentHTML action Slots m
summaryStrip state =
  HH.section
    [ HP.class_ (HH.ClassName "summary-strip") ]
    [ summaryHashCell "State root" "summary-root" (tokenStateField _.root state.tokenState)
    , summaryTextCell "Max fee" (tokenStateText _.max_fee " lovelace" state.tokenState)
    , summaryTextCell "Process window" (tokenStateText _.process_time " slots" state.tokenState)
    , summaryTextCell "Retract window" (tokenStateText _.retract_time " slots" state.tokenState)
    ]

workspaceTabs
  :: forall action m
   . AppActions action
  -> AppState
  -> H.ComponentHTML action Slots m
workspaceTabs actions state =
  HH.nav
    [ HP.class_ (HH.ClassName "workspace-tabs")
    , HP.attr (HH.AttrName "aria-label") "Token workspace tabs"
    ]
    (map (tabButton actions state) allTabs)

tabButton
  :: forall action m
   . AppActions action
  -> AppState
  -> AppTab
  -> H.ComponentHTML action Slots m
tabButton actions state tab =
  HH.button
    [ HP.type_ HP.ButtonButton
    , HP.classes (classNames [ "workspace-tab" ] active [ "is-active" ])
    , HP.attr (HH.AttrName "aria-selected") (boolAttr active)
    , HP.attr (HH.AttrName "data-tab") (tabSlug tab)
    , HE.onClick \_ -> actions.selectTab tab
    ]
    [ HH.text (tabLabel tab)
    , HH.span [ HP.class_ (HH.ClassName "tab-count") ] [ HH.text (tabCount state tab) ]
    ]
  where
  active = state.activeTab == tab

activePanel
  :: forall action m
   . MonadAff m
  => AppActions action
  -> AppState
  -> H.ComponentHTML action Slots m
activePanel actions state = case state.activeTab of
  FactsTab -> factsPanel actions state
  PendingTab -> pendingPanel actions state
  VerificationTab -> verificationPanel actions state

factsPanel
  :: forall action m
   . MonadAff m
  => AppActions action
  -> AppState
  -> H.ComponentHTML action Slots m
factsPanel actions state =
  Paper.paper
    [ HH.div
        [ HP.class_ (HH.ClassName "facts-panel__header") ]
        [ HH.div_
            [ HH.div [ HP.class_ (HH.ClassName "facts-panel__eyebrow") ] [ HH.text "Committed facts · decoded UTF-8 JSON" ]
            , HH.div [ HP.class_ (HH.ClassName "facts-panel__proof-summary") ] [ HH.text (factsSetStatusLabel state.factsSetVerification) ]
            ]
        , HH.div [ HP.class_ (HH.ClassName "facts-panel__count") ] [ HH.text factsCount ]
        ]
    , factsPanelBody actions state
    ]
  where
  factsCount = case state.facts of
    Success facts -> show (Array.length facts) <> " " <> if Array.length facts == 1 then "entry" else "entries"
    Loading -> "Loading"
    Failure _ -> "Unavailable"
    NotAsked -> "Not loaded"

factsPanelBody
  :: forall action m
   . MonadAff m
  => AppActions action
  -> AppState
  -> H.ComponentHTML action Slots m
factsPanelBody actions state = case state.facts of
  NotAsked ->
    dimmedFactsState
      "No facts loaded"
      "Load details to inspect committed key/value facts for the selected token."
  Loading ->
    dimmedFactsState "Loading facts" "Fetching the committed forest and verification status."
  Failure message ->
    HH.div
      [ HP.class_ (HH.ClassName "facts-empty facts-empty--error") ]
      [ HH.div [ HP.class_ (HH.ClassName "empty-glyph") ] [ HH.text "!" ]
      , HH.h2_ [ HH.text "Facts unavailable" ]
      , HH.p_ [ HH.text message ]
      ]
  Success facts ->
    if Array.null facts then
      dimmedFactsState
        "No facts"
        "This token's forest is empty. Committed key/value facts will appear here."
    else
      factsTable actions state facts

factsTable
  :: forall action m
   . MonadAff m
  => AppActions action
  -> AppState
  -> Array FactEntry
  -> H.ComponentHTML action Slots m
factsTable actions state facts =
  HH.div
    [ HP.class_ (HH.ClassName "facts-table-shell") ]
    [ DataTable.dataTable
        { columns:
            [ { key: "key", label: "Key" }
            , { key: "value", label: "Value" }
            , { key: "proof", label: "Proof" }
            , { key: "actions", label: "Actions" }
            ]
        , rows: Array.mapWithIndex (factTableRow actions state isMine) facts
        , maxHeight: Nothing
        }
    ]
  where
  isMine = case state.selectedToken of
    Nothing -> false
    Just token -> tokenIsMine state token

factTableRow
  :: forall action m
   . MonadAff m
  => AppActions action
  -> AppState
  -> Boolean
  -> Int
  -> FactEntry
  -> DataTable.TableRow (H.ComponentSlot Slots m action) action
factTableRow actions state isMine index fact =
  { key: show index <> "-" <> fact.key
  , cells:
      [ factKeyCell index vm
      , factValueCell index vm
      , factProofCell actions fact vm
      , factActionsCell actions fact vm
      ]
  }
  where
  vm = Facts.factRowViewModel state.factsSetVerification isMine fact

factKeyCell
  :: forall action m
   . MonadAff m
  => Int
  -> Facts.FactRowViewModel
  -> H.ComponentHTML action Slots m
factKeyCell index vm =
  HH.div
    [ HP.class_ (HH.ClassName "fact-key-cell") ]
    [ HH.div [ HP.class_ (HH.ClassName "fact-key-label") ] [ HH.text vm.keyLabel ]
    , case vm.keyJson of
        Just json -> jsonWell "fact-json-well fact-json-well--key" json
        Nothing -> hashChip ("fact-key-" <> show index) vm.key
    ]

factValueCell
  :: forall action m
   . MonadAff m
  => Int
  -> Facts.FactRowViewModel
  -> H.ComponentHTML action Slots m
factValueCell index vm =
  case vm.valueJson of
    Just json -> jsonWell "fact-json-well fact-json-well--value" json
    Nothing -> hashChip ("fact-value-" <> show index) vm.value

factProofCell
  :: forall action m
   . AppActions action
  -> FactEntry
  -> Facts.FactRowViewModel
  -> H.ComponentHTML action Slots m
factProofCell actions fact vm =
  proofChipButton
    { label: vm.proofLabel
    , tone: proofTone vm.proofTone
    , title: "Open fact proof"
    , onClick: actions.openFactProofDrawer fact
    }

factActionsCell
  :: forall action m
   . AppActions action
  -> FactEntry
  -> Facts.FactRowViewModel
  -> H.ComponentHTML action Slots m
factActionsCell actions fact vm =
  HH.div
    [ HP.class_ (HH.ClassName "fact-actions") ]
    ( [ HH.button
          [ HP.type_ HP.ButtonButton
          , HP.classes (map HH.ClassName [ "material-button", "material-button--secondary", "fact-action-button" ])
          , HP.title "Open fact proof"
          , HE.onClick \_ -> actions.openFactProofDrawer fact
          ]
          [ HH.text "Proof" ]
      , HH.button
          [ HP.type_ HP.ButtonButton
          , HP.classes (map HH.ClassName [ "material-button", "material-button--secondary", "fact-action-button" ])
          , HP.disabled (not vm.canEdit)
          , HP.title (fromMaybe "Edit dialog placeholder (#70)" vm.editDisabledReason)
          ]
          [ HH.text "Edit" ]
      ]
        <> disabledReasonWhen (not vm.canEdit) (fromMaybe "" vm.editDisabledReason)
    )

jsonWell :: forall action m. String -> String -> H.ComponentHTML action Slots m
jsonWell classes value =
  HH.code
    [ HP.classes (map HH.ClassName (String.split (Pattern " ") classes)) ]
    [ HH.text value ]

proofTone :: String -> StatusChip.StatusTone
proofTone = case _ of
  "ok" -> StatusChip.StatusOk
  "warn" -> StatusChip.StatusWarn
  "error" -> StatusChip.StatusError
  _ -> StatusChip.StatusNeutral

dimmedFactsState :: forall action m. String -> String -> H.ComponentHTML action Slots m
dimmedFactsState title message =
  HH.div
    [ HP.class_ (HH.ClassName "facts-empty") ]
    [ HH.div [ HP.class_ (HH.ClassName "empty-glyph") ] [ HH.text "{}" ]
    , HH.h2_ [ HH.text title ]
    , HH.p_ [ HH.text message ]
    ]

pendingPanel
  :: forall action m
   . MonadAff m
  => AppActions action
  -> AppState
  -> H.ComponentHTML action Slots m
pendingPanel actions state =
  Paper.paper
    [ HH.div
        [ HP.class_ (HH.ClassName "pending-notice") ]
        [ HH.span [ HP.class_ (HH.ClassName "pending-notice__icon") ] [ HH.text "i" ]
        , HH.span_
            [ HH.text "Requests are not yet applied to the forest. A request is processable, then retractable, then expired per the token windows. Only the original requester may retract, and only during the retract window." ]
        ]
    , HH.div
        [ HP.class_ (HH.ClassName "facts-panel__header") ]
        [ HH.div_
            [ HH.div [ HP.class_ (HH.ClassName "facts-panel__eyebrow") ] [ HH.text "Pending fact operations" ]
            , HH.div [ HP.class_ (HH.ClassName "facts-panel__proof-summary") ] [ HH.text (pendingRequestsStatusLabel state.pendingRequestsVerification) ]
            ]
        , HH.div [ HP.class_ (HH.ClassName "facts-panel__count") ] [ HH.text pendingCount ]
        ]
    , pendingPanelBody actions state
    ]
  where
  pendingCount = case state.pendingRequests of
    Success requests -> show (Array.length requests) <> " " <> if Array.length requests == 1 then "request" else "requests"
    Loading -> "Loading"
    Failure _ -> "Unavailable"
    NotAsked -> "Not loaded"

pendingPanelBody
  :: forall action m
   . MonadAff m
  => AppActions action
  -> AppState
  -> H.ComponentHTML action Slots m
pendingPanelBody actions state = case state.tokenState, state.pendingRequests of
  _, Failure message ->
    pendingDimmedState "Pending requests unavailable" message
  Failure message, _ ->
    pendingDimmedState "Token timing unavailable" message
  Loading, _ ->
    pendingDimmedState "Loading pending requests" "Fetching token timing and pending request data."
  _, Loading ->
    pendingDimmedState "Loading pending requests" "Fetching token timing and pending request data."
  Success tokenState, Success requests ->
    if Array.null requests then
      pendingDimmedState
        "No pending requests"
        "Every proposed change has been applied or expired. New requests appear here until processed."
    else
      pendingRequestsView actions state tokenState requests
  _, _ ->
    pendingDimmedState
      "No pending requests loaded"
      "Load details to inspect pending changes for the selected token."

pendingRequestsView
  :: forall action m
   . MonadAff m
  => AppActions action
  -> AppState
  -> TokenState
  -> Array PendingRequest
  -> H.ComponentHTML action Slots m
pendingRequestsView actions state tokenState requests =
  HH.div
    [ HP.class_ (HH.ClassName "pending-requests") ]
    [ HH.div
        [ HP.class_ (HH.ClassName "pending-table-shell") ]
        [ HH.table
            [ HP.class_ (HH.ClassName "pending-table") ]
            [ HH.thead_
                [ HH.tr_
                    [ HH.th_ [ HH.text "Op - Key -> Value" ]
                    , HH.th_ [ HH.text "Requester" ]
                    , HH.th_ [ HH.text "Age" ]
                    , HH.th_ [ HH.text "Fee" ]
                    , HH.th_ [ HH.text "Phase" ]
                    , HH.th_ [ HH.text "Proof" ]
                    , HH.th_ [ HH.text "Action" ]
                    ]
                ]
            , HH.tbody_ (Array.mapWithIndex (pendingTableRow actions state tokenState) requests)
            ]
        ]
    , HH.div
        [ HP.class_ (HH.ClassName "pending-card-list") ]
        (Array.mapWithIndex (pendingCard actions state tokenState) requests)
    ]

pendingTableRow
  :: forall action m
   . MonadAff m
  => AppActions action
  -> AppState
  -> TokenState
  -> Int
  -> PendingRequest
  -> H.ComponentHTML action Slots m
pendingTableRow actions state tokenState index request =
  HH.tr_
    [ HH.td_ [ pendingOperationCell vm ]
    , HH.td_ [ pendingRequesterCell index vm ]
    , HH.td_ [ HH.span [ HP.class_ (HH.ClassName "pending-age") ] [ HH.text vm.ageLabel ] ]
    , HH.td_ [ HH.span [ HP.class_ (HH.ClassName "pending-fee") ] [ HH.text vm.feeLabel ] ]
    , HH.td_ [ pendingPhaseCell vm ]
    , HH.td_ [ pendingProofChip actions request vm ]
    , HH.td_ [ pendingRetractAction actions vm ]
    ]
  where
  vm = pendingViewModel state tokenState request

pendingCard
  :: forall action m
   . MonadAff m
  => AppActions action
  -> AppState
  -> TokenState
  -> Int
  -> PendingRequest
  -> H.ComponentHTML action Slots m
pendingCard actions state tokenState index request =
  HH.article
    [ HP.class_ (HH.ClassName cardClass) ]
    [ HH.div
        [ HP.class_ (HH.ClassName "pending-card__topline") ]
        [ chip vm.opLabel vm.opTone
        , HH.span [ HP.class_ (HH.ClassName "pending-card__title") ] [ HH.text "Key -> Value" ]
        , HH.span [ HP.class_ (HH.ClassName "pending-card__age") ] [ HH.text vm.ageLabel ]
        ]
    , HH.code [ HP.class_ (HH.ClassName "pending-json-summary") ] [ HH.text vm.keyValueSummary ]
    , HH.div
        [ HP.class_ (HH.ClassName "pending-card__requester") ]
        [ pendingRequesterCell index vm
        , HH.span [ HP.class_ (HH.ClassName "pending-fee") ] [ HH.text ("fee " <> vm.feeLabel) ]
        ]
    , HH.div
        [ HP.class_ (HH.ClassName "pending-card__phase") ]
        [ chip vm.phaseLabel vm.phaseTone
        , HH.span_ [ HH.text vm.deadlineLabel ]
        ]
    , HH.div
        [ HP.class_ (HH.ClassName "pending-card__actions") ]
        [ pendingProofChip actions request vm
        , pendingRetractAction actions vm
        ]
    ]
  where
  vm = pendingViewModel state tokenState request

  cardClass = case vm.retractDecision of
    Pending.RetractEnabled -> "pending-card pending-card--retractable"
    Pending.RetractDisabled _ -> "pending-card"

pendingViewModel :: AppState -> TokenState -> PendingRequest -> Pending.PendingRowViewModel
pendingViewModel state tokenState request =
  Pending.pendingRowViewModel
    state.requestNowMillis
    tokenState
    state.pendingRequestsVerification
    (requesterIsWallet state request.owner)
    (connectedWalletForRequester state request.owner)
    request

pendingOperationCell
  :: forall action m
   . Pending.PendingRowViewModel
  -> H.ComponentHTML action Slots m
pendingOperationCell vm =
  HH.div
    [ HP.class_ (HH.ClassName "pending-operation-cell") ]
    [ HH.div
        [ HP.class_ (HH.ClassName "pending-operation-cell__line") ]
        [ chip vm.opLabel vm.opTone
        , HH.span [ HP.class_ (HH.ClassName "pending-key-value-label") ] [ HH.text "Decoded key -> value" ]
        ]
    , HH.code [ HP.class_ (HH.ClassName "pending-json-summary") ] [ HH.text vm.keyValueSummary ]
    ]

pendingRequesterCell
  :: forall action m
   . MonadAff m
  => Int
  -> Pending.PendingRowViewModel
  -> H.ComponentHTML action Slots m
pendingRequesterCell index vm =
  HH.div
    [ HP.class_ (HH.ClassName "pending-requester") ]
    [ hashChip ("pending-requester-" <> show index <> "-" <> vm.requestId) vm.requester
    , if vm.requesterIsWallet then
        HH.span [ HP.class_ (HH.ClassName "you-badge") ] [ HH.text "YOU" ]
      else
        HH.text ""
    ]

pendingPhaseCell
  :: forall action m
   . Pending.PendingRowViewModel
  -> H.ComponentHTML action Slots m
pendingPhaseCell vm =
  HH.div
    [ HP.class_ (HH.ClassName "pending-phase-cell") ]
    [ chip vm.phaseLabel vm.phaseTone
    , HH.div [ HP.class_ (HH.ClassName "pending-deadline") ] [ HH.text vm.deadlineLabel ]
    ]

pendingProofChip
  :: forall action m
   . AppActions action
  -> PendingRequest
  -> Pending.PendingRowViewModel
  -> H.ComponentHTML action Slots m
pendingProofChip actions request vm =
  HH.span
    [ HP.class_ (HH.ClassName "pending-proof-chip") ]
    [ chipButton
        { label: vm.proofLabel
        , tone: vm.proofTone
        , title: "Open request proof"
        , onClick: actions.openRequestProofDrawer request
        }
    ]

pendingRetractAction
  :: forall action m
   . AppActions action
  -> Pending.PendingRowViewModel
  -> H.ComponentHTML action Slots m
pendingRetractAction actions vm =
  HH.div
    [ HP.class_ (HH.ClassName "pending-retract") ]
    case vm.retractDecision of
      Pending.RetractEnabled ->
        [ HH.button
            [ HP.type_ HP.ButtonButton
            , HP.classes (map HH.ClassName [ "material-button", "pending-retract__button", "pending-retract__button--enabled" ])
            , HP.title "Retract this request"
            , HE.onClick \_ -> actions.retractRequest (RequestId vm.requestId)
            ]
            [ HH.text "Retract" ]
        ]
      Pending.RetractDisabled reason ->
        [ HH.button
            [ HP.type_ HP.ButtonButton
            , HP.classes (map HH.ClassName [ "material-button", "pending-retract__button" ])
            , HP.disabled true
            , HP.title reason
            ]
            [ HH.text "Retract" ]
        , HH.div [ HP.class_ (HH.ClassName "pending-retract__reason") ] [ HH.text reason ]
        ]

pendingDimmedState :: forall action m. String -> String -> H.ComponentHTML action Slots m
pendingDimmedState title message =
  HH.div
    [ HP.class_ (HH.ClassName "facts-empty pending-empty") ]
    [ HH.div [ HP.class_ (HH.ClassName "empty-glyph") ] [ HH.text "..." ]
    , HH.h2_ [ HH.text title ]
    , HH.p_ [ HH.text message ]
    ]

chip :: forall action m. String -> Chip.ChipTone -> H.ComponentHTML action Slots m
chip label tone =
  Chip.chip
    { label
    , tone
    , leading: Just (HH.span [ HP.class_ (HH.ClassName "pending-chip-dot") ] [])
    }

chipButton
  :: forall action m
   . { label :: String
     , tone :: Chip.ChipTone
     , title :: String
     , onClick :: action
     }
  -> H.ComponentHTML action Slots m
chipButton input =
  HH.button
    [ HP.type_ HP.ButtonButton
    , HP.classes
        ( map HH.ClassName
            [ "material-chip"
            , Chip.chipToneClass input.tone
            , "proof-chip-button"
            ]
        )
    , HP.title input.title
    , HE.onClick \_ -> input.onClick
    ]
    [ HH.span
        [ HP.class_ (HH.ClassName "material-chip__leading") ]
        [ HH.span [ HP.class_ (HH.ClassName "pending-chip-dot") ] [] ]
    , HH.span_ [ HH.text input.label ]
    ]

proofChipButton
  :: forall action m
   . { label :: String
     , tone :: StatusChip.StatusTone
     , title :: String
     , onClick :: action
     }
  -> H.ComponentHTML action Slots m
proofChipButton input =
  HH.button
    [ HP.type_ HP.ButtonButton
    , HP.classes
        ( map HH.ClassName
            [ "status-chip"
            , StatusChip.statusToneClass input.tone
            , "proof-chip-button"
            ]
        )
    , HP.title input.title
    , HE.onClick \_ -> input.onClick
    ]
    [ HH.text input.label ]

verificationPanel
  :: forall action m
   . MonadAff m
  => AppActions action
  -> AppState
  -> H.ComponentHTML action Slots m
verificationPanel actions state =
  HH.section
    [ HP.classes (map HH.ClassName [ "verification-panel", "verification-panel--" <> overall.tone ]) ]
    [ HH.div
        [ HP.class_ (HH.ClassName "verification-card") ]
        [ HH.div
            [ HP.class_ (HH.ClassName "verification-card__header") ]
            [ HH.div
                [ HP.classes (map HH.ClassName [ "verification-card__icon", "verification-card__icon--" <> overall.tone ]) ]
                [ HH.text overall.symbol ]
            , HH.div
                [ HP.class_ (HH.ClassName "verification-card__title") ]
                [ HH.h2_ [ HH.text overall.title ]
                , HH.p_ [ HH.text overall.subtitle ]
                ]
            , HH.button
                [ HP.type_ HP.ButtonButton
                , HP.classes (map HH.ClassName [ "material-button", "material-button--secondary", "verification-card__proof-button" ])
                , HE.onClick \_ -> actions.openSetProofDrawer
                ]
                [ HH.text "Open proof drawer" ]
            ]
        , HH.div
            [ HP.class_ (HH.ClassName "verification-checks") ]
            (map verificationCheckRow rows)
        ]
    , HH.div
        [ HP.class_ (HH.ClassName "verification-meta-grid") ]
        [ verificationMetaText "Snapshot slot" (snapshotSlotLabel state) "on-chain reference point"
        , verificationMetaHash "Trusted root" "verification-trusted-root" (trustedRootValue state) "what proofs are checked against"
        , verificationMetaText "Verifier ops" verifierOpsLabel "operations executed locally"
        ]
    ]
  where
  rows = verificationRows state

  overall = overallVerificationVerdict rows

  verifierOpsLabel =
    String.joinWith ", " (map _.verifierOp rows)

verificationCheckRow
  :: forall action m
   . Proof.ProofCheckRow
  -> H.ComponentHTML action Slots m
verificationCheckRow row =
  HH.div
    [ HP.class_ (HH.ClassName "verification-check-row") ]
    [ HH.div
        [ HP.classes (map HH.ClassName [ "verification-check-row__mark", "verification-check-row__mark--" <> row.tone ]) ]
        [ HH.text (if row.tone == "pass" then "OK" else "!") ]
    , HH.div
        [ HP.class_ (HH.ClassName "verification-check-row__body") ]
        ( [ HH.div [ HP.class_ (HH.ClassName "verification-check-row__name") ] [ HH.text row.name ]
          , HH.div [ HP.class_ (HH.ClassName "verification-check-row__detail") ] [ HH.text row.detail ]
          , HH.div [ HP.class_ (HH.ClassName "verification-check-row__op") ] [ HH.text ("op " <> row.verifierOp) ]
          ]
            <> case row.reason of
              Nothing -> []
              Just reason ->
                [ HH.div [ HP.class_ (HH.ClassName "verification-check-row__reason") ] [ HH.text reason ] ]
        )
    , HH.span
        [ HP.classes (map HH.ClassName [ "verification-badge", "verification-badge--" <> row.tone ]) ]
        [ HH.text row.badgeLabel ]
    ]

verificationMetaText
  :: forall action m
   . String
  -> String
  -> String
  -> H.ComponentHTML action Slots m
verificationMetaText label value helper =
  HH.div
    [ HP.class_ (HH.ClassName "verification-meta-card") ]
    [ HH.div [ HP.class_ (HH.ClassName "verification-meta-card__label") ] [ HH.text label ]
    , HH.div [ HP.class_ (HH.ClassName "verification-meta-card__value") ] [ HH.text value ]
    , HH.div [ HP.class_ (HH.ClassName "verification-meta-card__helper") ] [ HH.text helper ]
    ]

verificationMetaHash
  :: forall action m
   . MonadAff m
  => String
  -> String
  -> Maybe String
  -> String
  -> H.ComponentHTML action Slots m
verificationMetaHash label slotId value helper =
  HH.div
    [ HP.class_ (HH.ClassName "verification-meta-card") ]
    [ HH.div [ HP.class_ (HH.ClassName "verification-meta-card__label") ] [ HH.text label ]
    , maybeHashInline slotId value
    , HH.div [ HP.class_ (HH.ClassName "verification-meta-card__helper") ] [ HH.text helper ]
    ]

verificationRows :: AppState -> Array Proof.ProofCheckRow
verificationRows state =
  [ Proof.proofCheckRow
      { kind: Proof.CheckSecondOracle
      , status: secondOracleVerificationStatus state.secondOracle
      , checkedCount: 1
      , totalCount: 1
      }
  , Proof.proofCheckRow
      { kind: Proof.CheckFactsSet
      , status: state.factsSetVerification
      , checkedCount: factsCount
      , totalCount: factsCount
      }
  , Proof.proofCheckRow
      { kind: Proof.CheckPerFactInclusion
      , status: state.factsSetVerification
      , checkedCount: if state.factsSetVerification == VerificationVerified then factsCount else 0
      , totalCount: factsCount
      }
  ]
  where
  factsCount = case state.facts of
    Success facts -> Array.length facts
    _ -> 0

secondOracleVerificationStatus :: Remote SecondOracleVerdict -> VerificationStatus
secondOracleVerificationStatus = case _ of
  NotAsked -> VerificationNotAsked
  Loading -> VerificationLoading
  Failure message -> VerificationFailed message
  Success (SecondOracleVerified _) -> VerificationVerified
  Success verdict -> VerificationFailed (secondOracleVerdictLabel verdict)

overallVerificationVerdict
  :: Array Proof.ProofCheckRow
  -> { title :: String, subtitle :: String, tone :: String, symbol :: String }
overallVerificationVerdict rows =
  if Array.any (_.tone >>> (_ == "reject")) rows then
    { title: "Verification rejected"
    , subtitle: "At least one proof check failed. Inspect the reason before trusting this snapshot."
    , tone: "reject"
    , symbol: "!"
    }
  else if Array.all (_.tone >>> (_ == "pass")) rows then
    { title: "Verified independently"
    , subtitle: "Second-oracle, completeness, and inclusion checks passed in this browser."
    , tone: "pass"
    , symbol: "OK"
    }
  else
    { title: "Verification pending"
    , subtitle: "Load details to verify the snapshot and its proof envelopes."
    , tone: "pending"
    , symbol: "..."
    }

verdictPill
  :: forall action m
   . AppActions action
  -> AppState
  -> H.ComponentHTML action Slots m
verdictPill actions state =
  HH.button
    [ HP.type_ HP.ButtonButton
    , HP.classes (map HH.ClassName [ "verdict-pill", verdictClass ])
    , HP.title "Open facts-set proof"
    , HE.onClick \_ -> actions.openSetProofDrawer
    ]
    [ HH.span [ HP.class_ (HH.ClassName "status-dot") ] []
    , HH.span_ [ HH.text verdictText ]
    , HH.span [ HP.class_ (HH.ClassName "verdict-pill__hint") ] [ HH.text "View proof" ]
    ]
  where
  verdictClass = case state.factsSetVerification of
    VerificationVerified -> "is-pass"
    VerificationFailed _ -> "is-reject"
    VerificationLoading -> "is-pending"
    VerificationNotAsked -> "is-pending"

  verdictText = case state.factsSetVerification of
    VerificationVerified -> "Verified"
    VerificationFailed _ -> "Rejected"
    VerificationLoading -> "Verifying"
    VerificationNotAsked -> "Verification pending"

type ProofDrawerViewModel =
  { slotId :: String
  , title :: String
  , subtitle :: String
  , verdictLabel :: String
  , tone :: String
  , snapshot :: String
  , root :: Maybe String
  , verifierOp :: String
  , reason :: Maybe String
  , note :: Maybe String
  , raw :: String
  }

proofDrawer
  :: forall action m
   . MonadAff m
  => AppActions action
  -> AppState
  -> H.ComponentHTML action Slots m
proofDrawer actions state = case state.proofDrawer of
  ProofDrawerClosed ->
    HH.text ""
  target ->
    let
      vm = proofDrawerViewModel state target
    in
      HH.div
        [ HP.class_ (HH.ClassName "proof-drawer-layer") ]
        [ HH.div
            [ HP.class_ (HH.ClassName "proof-drawer-scrim")
            , HE.onClick \_ -> actions.closeProofDrawer
            ]
            []
        , HH.aside
            [ HP.class_ (HH.ClassName "proof-drawer")
            , HP.attr (HH.AttrName "role") "dialog"
            , HP.attr (HH.AttrName "aria-modal") "true"
            , HP.attr (HH.AttrName "aria-label") vm.title
            ]
            [ HH.header
                [ HP.class_ (HH.ClassName "proof-drawer__header") ]
                [ HH.div
                    [ HP.class_ (HH.ClassName "proof-drawer__heading") ]
                    [ HH.div [ HP.class_ (HH.ClassName "proof-drawer__eyebrow") ] [ HH.text "Proof inspector" ]
                    , HH.h2_ [ HH.text vm.title ]
                    , HH.p_ [ HH.text vm.subtitle ]
                    ]
                , HH.button
                    [ HP.type_ HP.ButtonButton
                    , HP.class_ (HH.ClassName "proof-drawer__close")
                    , HP.title "Close proof drawer"
                    , HE.onClick \_ -> actions.closeProofDrawer
                    ]
                    [ HH.text "x" ]
                ]
            , HH.div
                [ HP.class_ (HH.ClassName "proof-drawer__body") ]
                ( [ HH.div
                      [ HP.classes (map HH.ClassName [ "proof-drawer__verdict", "proof-drawer__verdict--" <> vm.tone ]) ]
                      [ HH.span [ HP.class_ (HH.ClassName "status-dot") ] []
                      , HH.text vm.verdictLabel
                      ]
                  ]
                    <> maybeBlock "proof-drawer__reason" vm.reason
                    <> maybeBlock "proof-drawer__note" vm.note
                    <>
                      [ proofDrawerMeta vm
                      , HH.div
                          [ HP.class_ (HH.ClassName "proof-drawer__raw") ]
                          [ HH.div
                              [ HP.class_ (HH.ClassName "proof-drawer__raw-header") ]
                              [ HH.div [ HP.class_ (HH.ClassName "proof-drawer__raw-title") ] [ HH.text "Raw proof" ]
                              , copyButton ("proof-drawer-copy-" <> vm.slotId) vm.raw "Copy raw proof"
                              ]
                          , HH.pre_ [ HH.text vm.raw ]
                          ]
                      ]
                )
            ]
        ]

proofDrawerMeta
  :: forall action m
   . MonadAff m
  => ProofDrawerViewModel
  -> H.ComponentHTML action Slots m
proofDrawerMeta vm =
  HH.div
    [ HP.class_ (HH.ClassName "proof-drawer__meta") ]
    [ proofDrawerMetaText "Snapshot slot" vm.snapshot
    , HH.div
        [ HP.class_ (HH.ClassName "proof-drawer__meta-row") ]
        [ HH.span_ [ HH.text "Trusted root" ]
        , case vm.root of
            Just root ->
              hashChip ("proof-drawer-root-" <> vm.slotId) root
            Nothing ->
              HH.span [ HP.class_ (HH.ClassName "muted-value") ] [ HH.text "Unavailable" ]
        ]
    , proofDrawerMetaText "Verifier op" vm.verifierOp
    ]

proofDrawerMetaText
  :: forall action m
   . String
  -> String
  -> H.ComponentHTML action Slots m
proofDrawerMetaText label value =
  HH.div
    [ HP.class_ (HH.ClassName "proof-drawer__meta-row") ]
    [ HH.span_ [ HH.text label ]
    , HH.code_ [ HH.text value ]
    ]

proofDrawerViewModel :: AppState -> ProofDrawer -> ProofDrawerViewModel
proofDrawerViewModel state target = case target of
  ProofDrawerClosed ->
    setProofDrawerViewModel state
  ProofDrawerSet ->
    setProofDrawerViewModel state
  ProofDrawerFact fact ->
    factProofDrawerViewModel state fact
  ProofDrawerRequest request ->
    requestProofDrawerViewModel state request

setProofDrawerViewModel :: AppState -> ProofDrawerViewModel
setProofDrawerViewModel state =
  { slotId: "set"
  , title: "Facts-set verification"
  , subtitle: selectedTokenLabel state
  , verdictLabel: drawerVerdictLabel status
  , tone: Proof.proofStatusTone status
  , snapshot: snapshotSlotLabel state
  , root: trustedRootValue state
  , verifierOp: "verify_facts"
  , reason: Proof.proofStatusReason status
  , note:
      if state.factsSetProofEnvelope == "" then
        Just "No raw facts-set proof envelope is loaded yet."
      else
        Nothing
  , raw: proofEnvelopeOrFallback "verify_facts" state.factsSetProofEnvelope
  }
  where
  status = overallVerificationStatus state

factProofDrawerViewModel :: AppState -> FactEntry -> ProofDrawerViewModel
factProofDrawerViewModel state fact =
  { slotId: "fact-" <> fact.key
  , title: "Fact inclusion proof"
  , subtitle: fromMaybe fact.key (Facts.factRowViewModel state.factsSetVerification false fact).keyJson
  , verdictLabel: drawerVerdictLabel state.factsSetVerification
  , tone: Proof.proofStatusTone state.factsSetVerification
  , snapshot: snapshotSlotLabel state
  , root: trustedRootValue state
  , verifierOp: "verify_fact_inclusion"
  , reason: Proof.proofStatusReason state.factsSetVerification
  , note:
      Just "Per-fact proof data is not separately retained in current state; showing the facts-set verification envelope."
  , raw: proofEnvelopeOrFallback "verify_fact_inclusion" state.factsSetProofEnvelope
  }

requestProofDrawerViewModel :: AppState -> PendingRequest -> ProofDrawerViewModel
requestProofDrawerViewModel state request =
  { slotId: "request-" <> request.request_id
  , title: "Request proof"
  , subtitle: request.operation <> " " <> request.key
  , verdictLabel: drawerVerdictLabel state.pendingRequestsVerification
  , tone: Proof.proofStatusTone state.pendingRequestsVerification
  , snapshot: snapshotSlotLabel state
  , root: trustedRootValue state
  , verifierOp: "verify_snapshot"
  , reason: Proof.proofStatusReason state.pendingRequestsVerification
  , note:
      Just "Request-specific proof data is not separately retained in current state; showing the pending-request snapshot envelope."
  , raw: proofEnvelopeOrFallback "verify_snapshot" state.pendingRequestsProofEnvelope
  }

overallVerificationStatus :: AppState -> VerificationStatus
overallVerificationStatus state =
  let
    rows = verificationRows state
  in
    case Array.find (\row -> row.tone == "reject") rows of
      Just row -> VerificationFailed (fromMaybe "Proof check failed" row.reason)
      Nothing ->
        if Array.all (\row -> row.tone == "pass") rows then
          VerificationVerified
        else
          VerificationLoading

drawerVerdictLabel :: VerificationStatus -> String
drawerVerdictLabel = case _ of
  VerificationVerified -> "Verified"
  VerificationFailed _ -> "Rejected"
  VerificationLoading -> "Pending"
  VerificationNotAsked -> "Not checked"

snapshotSlotLabel :: AppState -> String
snapshotSlotLabel state = case state.verificationSnapshotSlot of
  Just slot -> show slot
  Nothing -> "Unavailable"

trustedRootValue :: AppState -> Maybe String
trustedRootValue state = case state.trustedRoot of
  Success (TrustedRoot root) -> Just root
  _ -> Nothing

selectedTokenLabel :: AppState -> String
selectedTokenLabel state = case state.selectedToken of
  Just (TokenId tokenId) -> tokenId
  Nothing -> "No token selected"

proofEnvelopeOrFallback :: String -> String -> String
proofEnvelopeOrFallback op envelope =
  if envelope == "" then
    "{\n  \"op\": \""
      <> op
      <> "\",\n  \"status\": \"unavailable\",\n  \"note\": \"Proof envelope is not loaded in the current browser state.\"\n}"
  else
    envelope

maybeBlock
  :: forall action m
   . String
  -> Maybe String
  -> Array (H.ComponentHTML action Slots m)
maybeBlock _ Nothing = []
maybeBlock className (Just message) =
  [ HH.div [ HP.class_ (HH.ClassName className) ] [ HH.text message ] ]

summaryHashCell
  :: forall action m
   . MonadAff m
  => String
  -> String
  -> Maybe String
  -> H.ComponentHTML action Slots m
summaryHashCell label slotId value =
  HH.div
    [ HP.class_ (HH.ClassName "summary-cell") ]
    [ HH.div [ HP.class_ (HH.ClassName "summary-label") ] [ HH.text label ]
    , maybeHashInline slotId value
    ]

summaryTextCell :: forall action m. String -> String -> H.ComponentHTML action Slots m
summaryTextCell label value =
  HH.div
    [ HP.class_ (HH.ClassName "summary-cell") ]
    [ HH.div [ HP.class_ (HH.ClassName "summary-label") ] [ HH.text label ]
    , HH.div [ HP.class_ (HH.ClassName "summary-value") ] [ HH.text value ]
    ]

maybeHashInline
  :: forall action m
   . MonadAff m
  => String
  -> Maybe String
  -> H.ComponentHTML action Slots m
maybeHashInline slotId = case _ of
  Nothing ->
    HH.span [ HP.class_ (HH.ClassName "muted-value") ] [ HH.text "Unavailable" ]
  Just value ->
    hashChip slotId value

hashChip
  :: forall action m
   . MonadAff m
  => String
  -> String
  -> H.ComponentHTML action Slots m
hashChip slotId value =
  HH.slot_
    _hashChip
    slotId
    HashChip.component
    { value, flank: 6 }

copyButton
  :: forall action m
   . MonadAff m
  => String
  -> String
  -> String
  -> H.ComponentHTML action Slots m
copyButton slotId value label =
  HH.slot_
    _copyButton
    slotId
    CopyButton.component
    { value, label }

mineBadgeIf :: forall action m. Boolean -> H.ComponentHTML action Slots m
mineBadgeIf false = HH.text ""
mineBadgeIf true =
  HH.span [ HP.class_ (HH.ClassName "mine-badge") ] [ HH.text "MINE" ]

visibleTokens :: AppState -> Array TokenId -> Array TokenId
visibleTokens state =
  Array.filter \token ->
    tokenMatchesSearch state token
      && (not state.tokenMineOnly || tokenIsMine state token)

tokenMatchesSearch :: AppState -> TokenId -> Boolean
tokenMatchesSearch state token@(TokenId tokenId) =
  query == ""
    || CodeUnits.contains (Pattern query) (String.toLower tokenId)
    || ownerMatches
  where
  query = String.toLower state.tokenSearch

  ownerMatches = case ownerForToken state token of
    Nothing -> false
    Just owner -> CodeUnits.contains (Pattern query) (String.toLower owner)

ownerForToken :: AppState -> TokenId -> Maybe String
ownerForToken state token =
  if state.selectedToken == Just token then
    selectedTokenOwner state
  else
    Nothing

selectedTokenOwner :: AppState -> Maybe String
selectedTokenOwner state = case state.tokenState of
  Success tokenState -> Just tokenState.owner
  _ -> Nothing

tokenIsMine :: AppState -> TokenId -> Boolean
tokenIsMine state token = case ownerForToken state token of
  Nothing -> false
  Just owner ->
    Array.elem owner (walletRefs state)

requesterIsWallet :: AppState -> String -> Boolean
requesterIsWallet state requester =
  state.walletSession.status == WalletConnected
    && Array.elem requester (walletRefs state)

connectedWalletForRequester :: AppState -> String -> Maybe String
connectedWalletForRequester state requester =
  if state.walletSession.status /= WalletConnected then
    Nothing
  else if Array.elem requester refs then
    Just requester
  else
    Array.head refs
  where
  refs = walletRefs state

walletRefs :: AppState -> Array String
walletRefs state =
  Array.catMaybes
    [ state.walletSession.selectedAddress
    , state.walletSession.changeAddress
    , state.walletSession.walletKey
    ]
    <> state.walletSession.usedAddresses

tokenCountLabel :: forall a. Remote (Array a) -> String
tokenCountLabel = case _ of
  Success tokens -> show (Array.length tokens) <> " tokens"
  Loading -> "Loading"
  Failure _ -> "Unavailable"
  NotAsked -> "Not loaded"

mineCountLabel :: AppState -> String
mineCountLabel state = case state.tokens of
  Success tokens -> show (Array.length (Array.filter (tokenIsMine state) tokens))
  _ -> "0"

factsCountFor :: AppState -> TokenId -> String
factsCountFor state token =
  if state.selectedToken == Just token then
    case state.facts of
      Success facts -> show (Array.length facts) <> " facts"
      Loading -> "facts loading"
      _ -> "facts --"
  else
    "facts --"

pendingCountFor :: AppState -> TokenId -> String
pendingCountFor state token =
  if state.selectedToken == Just token then
    case state.pendingRequests of
      Success requests -> show (Array.length requests) <> " pending"
      Loading -> "pending loading"
      _ -> "pending --"
  else
    "pending --"

tabCount :: AppState -> AppTab -> String
tabCount state = case _ of
  FactsTab -> remoteArrayCount state.facts
  PendingTab -> remoteArrayCount state.pendingRequests
  VerificationTab -> verificationTabCount state

remoteArrayCount :: forall a. Remote (Array a) -> String
remoteArrayCount = case _ of
  Success values -> show (Array.length values)
  Loading -> "..."
  _ -> "-"

verificationTabCount :: AppState -> String
verificationTabCount state =
  case state.factsSetVerification, state.pendingRequestsVerification, state.secondOracle of
    VerificationVerified, VerificationVerified, Success _ -> "3"
    VerificationLoading, _, _ -> "..."
    _, VerificationLoading, _ -> "..."
    _, _, Loading -> "..."
    _, _, _ -> "-"

tokenStateField :: (TokenState -> String) -> Remote TokenState -> Maybe String
tokenStateField field = case _ of
  Success tokenState -> Just (field tokenState)
  _ -> Nothing

tokenStateText :: (TokenState -> Number) -> String -> Remote TokenState -> String
tokenStateText field suffix = case _ of
  Success tokenState -> show (field tokenState) <> suffix
  Loading -> "Loading"
  Failure _ -> "Unavailable"
  NotAsked -> "Not loaded"

emptyMessage :: forall action m. String -> H.ComponentHTML action Slots m
emptyMessage message =
  HH.div [ HP.class_ (HH.ClassName "sidebar-empty") ] [ HH.text message ]

loadingMessage :: forall action m. String -> H.ComponentHTML action Slots m
loadingMessage message =
  HH.div [ HP.class_ (HH.ClassName "sidebar-loading") ] [ HH.text message ]

errorMessage :: forall action m. String -> H.ComponentHTML action Slots m
errorMessage message =
  HH.div [ HP.class_ (HH.ClassName "sidebar-error") ] [ HH.text message ]

disabledReasonWhen
  :: forall action m
   . Boolean
  -> String
  -> Array (H.ComponentHTML action Slots m)
disabledReasonWhen false _ = []
disabledReasonWhen true message =
  [ HH.p
      [ HP.class_ (HH.ClassName "disabled-reason") ]
      [ HH.text message ]
  ]

tokenLoadLabel :: forall a. Remote a -> String
tokenLoadLabel = case _ of
  NotAsked -> "Load"
  Loading -> "Loading"
  Failure _ -> "Refresh"
  Success _ -> "Refresh"

factsLoadLabel :: forall a. Remote a -> String
factsLoadLabel = case _ of
  NotAsked -> "Load details"
  Loading -> "Loading"
  Failure _ -> "Refresh details"
  Success _ -> "Refresh details"

remoteIsLoading :: forall a. Remote a -> Boolean
remoteIsLoading = case _ of
  Loading -> true
  _ -> false

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

boolAttr :: Boolean -> String
boolAttr true = "true"
boolAttr false = "false"

classNames :: Array String -> Boolean -> Array String -> Array HH.ClassName
classNames base enabled extra =
  map HH.ClassName (if enabled then base <> extra else base)

walletInitial :: AppState -> String
walletInitial state =
  case state.walletSession.walletName of
    Just name ->
      CodeUnits.take 1 name
    Nothing ->
      "W"

verificationStatusLabel :: VerificationStatus -> String
verificationStatusLabel = case _ of
  VerificationNotAsked -> "Not verified"
  VerificationLoading -> "Verifying"
  VerificationVerified -> "Verified"
  VerificationFailed message -> "Rejected: " <> message

tokenCompletenessStatusLabel :: VerificationStatus -> String
tokenCompletenessStatusLabel = case _ of
  VerificationNotAsked -> "not checked"
  VerificationLoading -> "checking"
  VerificationVerified -> "complete"
  VerificationFailed _ -> "incomplete"

factsSetStatusLabel :: VerificationStatus -> String
factsSetStatusLabel status =
  "Facts set: " <> verificationStatusLabel status

pendingRequestsStatusLabel :: VerificationStatus -> String
pendingRequestsStatusLabel status =
  "Pending requests: " <> verificationStatusLabel status

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
