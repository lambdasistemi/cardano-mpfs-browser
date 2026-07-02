module MPFS.UI.Material.Button
  ( ButtonVariant(..)
  , button
  , buttonVariantClass
  ) where

import Prelude

import Halogen.HTML as HH
import Halogen.HTML.Events as HE
import Halogen.HTML.Properties as HP

data ButtonVariant = ButtonPrimary | ButtonSecondary | ButtonText

buttonVariantClass :: ButtonVariant -> String
buttonVariantClass = case _ of
  ButtonPrimary -> "material-button--primary"
  ButtonSecondary -> "material-button--secondary"
  ButtonText -> "material-button--text"

button
  :: forall w i
   . { label :: String
     , variant :: ButtonVariant
     , disabled :: Boolean
     , onClick :: i
     }
  -> HH.HTML w i
button input =
  HH.button
    [ HP.type_ HP.ButtonButton
    , HP.classes
        (map HH.ClassName [ "material-button", buttonVariantClass input.variant ])
    , HP.disabled input.disabled
    , HE.onClick \_ -> input.onClick
    ]
    [ HH.text input.label ]
