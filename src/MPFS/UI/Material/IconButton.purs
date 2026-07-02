module MPFS.UI.Material.IconButton (iconButton) where

import Halogen.HTML as HH
import Halogen.HTML.Events as HE
import Halogen.HTML.Properties as HP

iconButton
  :: forall w i
   . { ariaLabel :: String
     , icon :: HH.HTML w i
     , disabled :: Boolean
     , onClick :: i
     }
  -> HH.HTML w i
iconButton input =
  HH.button
    [ HP.type_ HP.ButtonButton
    , HP.class_ (HH.ClassName "material-icon-button")
    , HP.disabled input.disabled
    , HP.title input.ariaLabel
    , HP.attr (HH.AttrName "aria-label") input.ariaLabel
    , HE.onClick \_ -> input.onClick
    ]
    [ input.icon ]
