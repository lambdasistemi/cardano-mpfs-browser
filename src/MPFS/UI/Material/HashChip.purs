module MPFS.UI.Material.HashChip
  ( Input
  , component
  ) where

import Prelude

import Data.Maybe (Maybe(..))
import Data.Time.Duration (Milliseconds(..))
import Effect.Aff (delay)
import Effect.Aff.Class (class MonadAff)
import Halogen as H
import Halogen.HTML as HH
import Halogen.HTML.Events as HE
import Halogen.HTML.Properties as HP
import MPFS.UI.Material.Clipboard as Clipboard
import MPFS.UI.Material.Text (truncateMiddle)

type Input =
  { value :: String
  , flank :: Int
  }

data CopyState = Idle | Copied

type State =
  { value :: String
  , flank :: Int
  , copyState :: CopyState
  }

data Action
  = Receive Input
  | Copy

component :: forall query output m. MonadAff m => H.Component query Input output m
component =
  H.mkComponent
    { initialState
    , render
    , eval:
        H.mkEval H.defaultEval
          { receive = Just <<< Receive
          , handleAction = handleAction
          }
    }

initialState :: Input -> State
initialState input =
  { value: input.value
  , flank: input.flank
  , copyState: Idle
  }

render :: forall slots m. State -> H.ComponentHTML Action slots m
render state =
  HH.span
    [ HP.class_ (HH.ClassName "hash-chip")
    , HP.title state.value
    ]
    [ HH.span
        [ HP.class_ (HH.ClassName "hash-chip__value") ]
        [ HH.text (truncateMiddle state.flank state.value) ]
    , HH.button
        [ HP.type_ HP.ButtonButton
        , HP.classes (map HH.ClassName (buttonClasses state.copyState))
        , HP.title "Copy full value"
        , HP.attr (HH.AttrName "aria-label") "Copy full value"
        , HE.onClick \_ -> Copy
        ]
        [ HH.span
            [ HP.class_ (HH.ClassName "copy-button__icon")
            , HP.attr (HH.AttrName "aria-hidden") "true"
            ]
            [ HH.text "⧉" ]
        , HH.span
            [ HP.class_ (HH.ClassName "copy-button__label") ]
            [ HH.text (buttonLabel state.copyState) ]
        ]
    ]

handleAction
  :: forall slots output m
   . MonadAff m
  => Action
  -> H.HalogenM State Action slots output m Unit
handleAction = case _ of
  Receive input ->
    H.modify_ \state ->
      state
        { value = input.value
        , flank = input.flank
        , copyState = Idle
        }

  Copy -> do
    state <- H.get
    H.liftAff (Clipboard.writeText state.value)
    H.modify_ _ { copyState = Copied }
    _ <- H.fork do
      H.liftAff (delay (Milliseconds 1500.0))
      H.modify_ _ { copyState = Idle }
    pure unit

buttonClasses :: CopyState -> Array String
buttonClasses = case _ of
  Idle -> [ "copy-button", "hash-chip__copy" ]
  Copied -> [ "copy-button", "hash-chip__copy", "is-copied" ]

buttonLabel :: CopyState -> String
buttonLabel = case _ of
  Idle -> "Copy"
  Copied -> "Copied"
