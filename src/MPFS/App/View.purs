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
import MPFS.App.State (AppState, WalletStatus(..))
import MPFS.App.Tab (AppTab(..), allTabs, tabLabel, tabSlug)
import MPFS.App.Verification (VerificationStatus(..))
import MPFS.App.Write (WriteStatus(..))
import MPFS.Client.Types (FactEntry, TokenState)
import MPFS.SecondOracle.Types
  ( SecondOracleUnavailable(..)
  , SecondOracleVerdict(..)
  )
import MPFS.Types (RequestId, TokenId(..))
import MPFS.UI.Material.DataTable as DataTable
import MPFS.UI.Material.HashChip as HashChip
import MPFS.UI.Material.Paper as Paper
import MPFS.UI.Material.StatusChip as StatusChip
import MPFS.UI.Remote (Remote(..))
import MPFS.Wallet.Cip30 (WalletInfo)
import Type.Proxy (Proxy(..))

type Slots =
  ( hashChip :: forall query. H.Slot query Void String
  )

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
        , activePanel state
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
        [ verdictPill state
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
  => AppState
  -> H.ComponentHTML action Slots m
activePanel state = case state.activeTab of
  FactsTab -> factsPanel state
  PendingTab -> placeholderPanel PendingTab
  VerificationTab -> placeholderPanel VerificationTab

factsPanel
  :: forall action m
   . MonadAff m
  => AppState
  -> H.ComponentHTML action Slots m
factsPanel state =
  Paper.paper
    [ HH.div
        [ HP.class_ (HH.ClassName "facts-panel__header") ]
        [ HH.div_
            [ HH.div [ HP.class_ (HH.ClassName "facts-panel__eyebrow") ] [ HH.text "Committed facts · decoded UTF-8 JSON" ]
            , HH.div [ HP.class_ (HH.ClassName "facts-panel__proof-summary") ] [ HH.text (factsSetStatusLabel state.factsSetVerification) ]
            ]
        , HH.div [ HP.class_ (HH.ClassName "facts-panel__count") ] [ HH.text factsCount ]
        ]
    , factsPanelBody state
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
  => AppState
  -> H.ComponentHTML action Slots m
factsPanelBody state = case state.facts of
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
      factsTable state facts

factsTable
  :: forall action m
   . MonadAff m
  => AppState
  -> Array FactEntry
  -> H.ComponentHTML action Slots m
factsTable state facts =
  HH.div
    [ HP.class_ (HH.ClassName "facts-table-shell") ]
    [ DataTable.dataTable
        { columns:
            [ { key: "key", label: "Key" }
            , { key: "value", label: "Value" }
            , { key: "proof", label: "Proof" }
            , { key: "actions", label: "Actions" }
            ]
        , rows: Array.mapWithIndex (factTableRow state isMine) facts
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
  => AppState
  -> Boolean
  -> Int
  -> FactEntry
  -> DataTable.TableRow (H.ComponentSlot Slots m action) action
factTableRow state isMine index fact =
  { key: show index <> "-" <> fact.key
  , cells:
      [ factKeyCell index vm
      , factValueCell index vm
      , factProofCell vm
      , factActionsCell vm
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
   . Facts.FactRowViewModel
  -> H.ComponentHTML action Slots m
factProofCell vm =
  StatusChip.statusChip
    { label: vm.proofLabel
    , tone: proofTone vm.proofTone
    }

factActionsCell
  :: forall action m
   . Facts.FactRowViewModel
  -> H.ComponentHTML action Slots m
factActionsCell vm =
  HH.div
    [ HP.class_ (HH.ClassName "fact-actions") ]
    ( [ HH.button
          [ HP.type_ HP.ButtonButton
          , HP.classes (map HH.ClassName [ "material-button", "material-button--secondary", "fact-action-button" ])
          , HP.title "Proof drawer placeholder (#69)"
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

placeholderPanel :: forall action m. AppTab -> H.ComponentHTML action Slots m
placeholderPanel tab =
  HH.section
    [ HP.class_ (HH.ClassName "placeholder-panel")
    , HP.attr (HH.AttrName "aria-live") "polite"
    ]
    [ HH.div [ HP.class_ (HH.ClassName "empty-glyph") ] [ HH.text placeholderGlyph ]
    , HH.h2_ [ HH.text (tabLabel tab) ]
    , HH.p_ [ HH.text (tabLabel tab <> " content is coming in the next ticket.") ]
    ]
  where
  placeholderGlyph = case tab of
    FactsTab -> "{}"
    PendingTab -> "..."
    VerificationTab -> "OK"

verdictPill :: forall action m. AppState -> H.ComponentHTML action Slots m
verdictPill state =
  HH.button
    [ HP.type_ HP.ButtonButton
    , HP.classes (map HH.ClassName [ "verdict-pill", verdictClass ])
    ]
    [ HH.span [ HP.class_ (HH.ClassName "status-dot") ] []
    , HH.span_ [ HH.text verdictText ]
    , HH.span [ HP.class_ (HH.ClassName "verdict-pill__hint") ] [ HH.text "Proof later" ]
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
    Array.elem owner walletRefs
  where
  walletRefs =
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
