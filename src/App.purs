module App where

import Prelude

import Data.Either (Either(..))
import Effect.Aff.Class (class MonadAff, liftAff)
import Halogen as H
import MPFS.App.Tokens as Tokens
import MPFS.App.State (AppState, defaultState, selectTab)
import MPFS.App.Tab (AppTab)
import MPFS.Client as Client
import MPFS.Client.Types as ClientTypes
import MPFS.Types (TokenId(..))
import MPFS.App.View as View

data Action
  = SelectTab AppTab
  | LoadTokens
  | SelectToken TokenId

component :: forall q i o m. MonadAff m => H.Component q i o m
component =
  H.mkComponent
    { initialState: const defaultState
    , render:
        View.render
          { selectTab: SelectTab
          , loadTokens: LoadTokens
          , selectToken: SelectToken
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

fromClientTokenIds :: Array ClientTypes.TokenId -> Array TokenId
fromClientTokenIds = map TokenId
