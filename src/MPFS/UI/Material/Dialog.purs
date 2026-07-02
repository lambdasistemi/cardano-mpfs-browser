module MPFS.UI.Material.Dialog (dialog) where

import Halogen.HTML as HH
import Halogen.HTML.Properties as HP

dialog
  :: forall w i
   . { open :: Boolean
     , title :: String
     , body :: Array (HH.HTML w i)
     , actions :: Array (HH.HTML w i)
     }
  -> HH.HTML w i
dialog input =
  if input.open then
    HH.div
      [ HP.class_ (HH.ClassName "material-dialog-backdrop") ]
      [ HH.div
          [ HP.class_ (HH.ClassName "material-dialog")
          , HP.attr (HH.AttrName "role") "dialog"
          , HP.attr (HH.AttrName "aria-modal") "true"
          , HP.attr (HH.AttrName "aria-label") input.title
          ]
          [ HH.header
              [ HP.class_ (HH.ClassName "material-dialog__header") ]
              [ HH.h2_ [ HH.text input.title ] ]
          , HH.div
              [ HP.class_ (HH.ClassName "material-dialog__body") ]
              input.body
          , HH.footer
              [ HP.class_ (HH.ClassName "material-dialog__actions") ]
              input.actions
          ]
      ]
  else
    HH.text ""
