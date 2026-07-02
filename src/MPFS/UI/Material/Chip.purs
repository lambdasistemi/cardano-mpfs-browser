module MPFS.UI.Material.Chip
  ( ChipTone(..)
  , chip
  , chipToneClass
  ) where

import Prelude

import Data.Maybe (Maybe(..))
import Halogen.HTML as HH
import Halogen.HTML.Properties as HP

data ChipTone = ChipNeutral | ChipPrimary | ChipSuccess | ChipWarning | ChipError

chipToneClass :: ChipTone -> String
chipToneClass = case _ of
  ChipNeutral -> "material-chip--neutral"
  ChipPrimary -> "material-chip--primary"
  ChipSuccess -> "material-chip--success"
  ChipWarning -> "material-chip--warning"
  ChipError -> "material-chip--error"

chip
  :: forall w i
   . { label :: String
     , tone :: ChipTone
     , leading :: Maybe (HH.HTML w i)
     }
  -> HH.HTML w i
chip input =
  HH.span
    [ HP.classes (map HH.ClassName [ "material-chip", chipToneClass input.tone ]) ]
    (leadingContent <> [ HH.span_ [ HH.text input.label ] ])
  where
  leadingContent = case input.leading of
    Nothing -> []
    Just leading ->
      [ HH.span
          [ HP.class_ (HH.ClassName "material-chip__leading") ]
          [ leading ]
      ]
