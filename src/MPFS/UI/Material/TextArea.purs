module MPFS.UI.Material.TextArea
  ( Input
  , textArea
  ) where

import Prelude

import Data.Maybe (Maybe(..))
import Halogen.HTML as HH
import Halogen.HTML.Events as HE
import Halogen.HTML.Properties as HP

type Input i =
  { label :: String
  , value :: String
  , placeholder :: Maybe String
  , onInput :: String -> i
  , disabled :: Boolean
  }

textArea :: forall w i. Input i -> HH.HTML w i
textArea input =
  HH.label
    [ HP.classes (map HH.ClassName [ "mui-field", "mui-field--textarea" ]) ]
    [ HH.span
        [ HP.class_ (HH.ClassName "mui-field__label") ]
        [ HH.text input.label ]
    , HH.textarea inputProps
    ]
  where
  inputProps =
    [ HP.value input.value
    , HP.rows 4
    , HP.disabled input.disabled
    , HE.onValueInput input.onInput
    ]
      <> placeholderProps

  placeholderProps = case input.placeholder of
    Nothing -> []
    Just placeholder ->
      [ HP.placeholder placeholder ]
