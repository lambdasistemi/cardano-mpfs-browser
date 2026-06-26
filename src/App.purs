module App where

import Prelude

import Halogen as H
import MPFS.App.State (AppState, defaultState, selectTab)
import MPFS.App.Tab (AppTab)
import MPFS.App.View as View

data Action = SelectTab AppTab

component :: forall q i o m. H.Component q i o m
component =
  H.mkComponent
    { initialState: const defaultState
    , render: View.render SelectTab
    , eval: H.mkEval H.defaultEval { handleAction = handleAction }
    }

handleAction
  :: forall slots output m
   . Action
  -> H.HalogenM AppState Action slots output m Unit
handleAction = case _ of
  SelectTab tab ->
    H.modify_ (selectTab tab)
