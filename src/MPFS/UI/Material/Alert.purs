module MPFS.UI.Material.Alert
  ( AlertTone(..)
  , alert
  , alertToneClass
  ) where

import Prelude

import Halogen.HTML as HH
import Halogen.HTML.Properties as HP

data AlertTone = AlertInfo | AlertSuccess | AlertWarning | AlertError

alertToneClass :: AlertTone -> String
alertToneClass = case _ of
  AlertInfo -> "material-alert--info"
  AlertSuccess -> "material-alert--success"
  AlertWarning -> "material-alert--warning"
  AlertError -> "material-alert--error"

alert
  :: forall w i
   . { tone :: AlertTone
     , message :: String
     }
  -> HH.HTML w i
alert input =
  HH.div
    [ HP.classes (map HH.ClassName [ "material-alert", alertToneClass input.tone ]) ]
    [ HH.text input.message ]
