module MPFS.App.View (render) where

import Prelude

import Data.Array as Array
import Data.Maybe (Maybe(..))
import Halogen as H
import Halogen.HTML as HH
import Halogen.HTML.Events as HE
import Halogen.HTML.Properties as HP
import MPFS.App.State (AppState, WalletStatus(..))
import MPFS.App.Tab (AppTab(..), allTabs, tabLabel, tabSlug)
import MPFS.Types (TokenId(..))
import MPFS.UI.Remote (Remote(..), remoteStatus)

type AppActions action =
  { loadTokens :: action
  , selectTab :: AppTab -> action
  , selectToken :: TokenId -> action
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
        , statusPill "Wallet" (walletStatusLabel state.walletSession.status)
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
  ConnectTab -> connectPanel state
  TokensTab -> tokensPanel actions state
  FactsTab -> factsPanel state
  EndTab -> endPanel state

connectPanel :: forall action m. AppState -> H.ComponentHTML action () m
connectPanel state =
  panelLayout "Connect" "Wallet session"
    [ fieldLine "Session" (walletStatusLabel state.walletSession.status)
    , fieldLine "Network" (maybeText state.walletSession.network)
    , fieldLine "Address" (maybeText state.walletSession.address)
    , HH.div
        [ HP.class_ (HH.ClassName "control-row") ]
        [ inertButton "Connect wallet"
        , inertButton "Refresh"
        ]
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
    , HH.div
        [ HP.class_ (HH.ClassName "control-row") ]
        [ HH.button
            [ HP.type_ HP.ButtonButton
            , HP.class_ (HH.ClassName "primary-button")
            , HP.disabled (state.tokens == Loading)
            , HE.onClick \_ -> actions.loadTokens
            ]
            [ HH.text (tokenLoadLabel state.tokens) ]
        , inertButton "Register token"
        ]
    ]

factsPanel :: forall action m. AppState -> H.ComponentHTML action () m
factsPanel state =
  panelLayout "Facts" "Selected token facts"
    [ fieldLine "Token" (selectedTokenLabel state.selectedToken)
    , fieldLine "Facts" (remoteStatus state.facts)
    , fieldLine "Trusted root" (remoteStatus state.trustedRoot)
    , HH.div
        [ HP.class_ (HH.ClassName "control-row") ]
        [ inertButton "Load facts"
        , inertButton "Verify proof"
        ]
    ]

endPanel :: forall action m. AppState -> H.ComponentHTML action () m
endPanel state =
  panelLayout "End" "Cage lifecycle"
    [ fieldLine "Token" (selectedTokenLabel state.selectedToken)
    , fieldLine "Wallet" (walletStatusLabel state.walletSession.status)
    , HH.div
        [ HP.class_ (HH.ClassName "control-row") ]
        [ inertButton "End cage"
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

inertButton :: forall action m. String -> H.ComponentHTML action () m
inertButton label =
  HH.button
    [ HP.type_ HP.ButtonButton
    , HP.disabled true
    , HP.class_ (HH.ClassName "inert-button")
    ]
    [ HH.text label ]

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

walletStatusLabel :: WalletStatus -> String
walletStatusLabel = case _ of
  WalletDisconnected -> "Not connected"
  WalletConnecting -> "Connecting"
  WalletConnected -> "Connected"

selectedTokenLabel :: Maybe TokenId -> String
selectedTokenLabel = case _ of
  Nothing -> "None"
  Just (TokenId tokenId) -> tokenId

maybeText :: Maybe String -> String
maybeText = case _ of
  Nothing -> "Unavailable"
  Just value -> value
