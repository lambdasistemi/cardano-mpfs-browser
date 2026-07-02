module MPFS.UI.Material.TextField
  ( Input
  , textField
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

textField :: forall w i. Input i -> HH.HTML w i
textField input =
  HH.label
    [ HP.class_ (HH.ClassName "mui-field") ]
    [ HH.span
        [ HP.class_ (HH.ClassName "mui-field__label") ]
        [ HH.text input.label ]
    , HH.input inputProps
    ]
  where
  inputProps =
    [ HP.type_ HP.InputText
    , HP.value input.value
    , HP.disabled input.disabled
    , HE.onValueInput input.onInput
    ]
      <> placeholderProps

  placeholderProps = case input.placeholder of
    Nothing -> []
    Just placeholder ->
      [ HP.placeholder placeholder ]
