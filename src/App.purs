module App where

import Prelude

import Data.Either (Either(..))
import Data.Maybe (Maybe(..))
import Data.DateTime.Instant as Instant
import Data.Time.Duration (Milliseconds(..))
import Effect.Aff.Class (class MonadAff, liftAff)
import Effect.Class (liftEffect)
import Effect.Now as Now
import Halogen as H
import MPFS.App.Facts as Facts
import MPFS.App.State (AppState, defaultState, selectTab)
import MPFS.App.Tab (AppTab)
import MPFS.App.Tokens as Tokens
import MPFS.App.Verification as Verification
import MPFS.App.View as View
import MPFS.Client as Client
import MPFS.Client.Types as ClientTypes
import MPFS.Types (TokenId(..))

data Action
  = SelectTab AppTab
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
          , loadTokens: LoadTokens
          , selectToken: SelectToken
          , loadFacts: LoadFacts
          , updateFactLookupKey: UpdateFactLookupKey
          , lookupFact: LookupFact
          , updateFactProofEnvelope: UpdateFactProofEnvelope
          , verifyFactEnvelope: VerifyFactEnvelope
          }
    , eval: H.mkEval H.defaultEval { handleAction = handleAction }
    }

handleAction
  :: forall slots output m
   . MonadAff m
  => Action
  -> H.HalogenM AppState Action slots output m Unit
handleAction = case _ of
  SelectTab tab ->
    H.modify_ (selectTab tab)

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
