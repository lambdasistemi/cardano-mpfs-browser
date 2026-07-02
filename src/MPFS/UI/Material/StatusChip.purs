module MPFS.UI.Material.StatusChip
  ( StatusTone(..)
  , statusChip
  , statusToneClass
  ) where

import Prelude

import Halogen.HTML as HH
import Halogen.HTML.Properties as HP

data StatusTone = StatusOk | StatusWarn | StatusError | StatusNeutral

statusToneClass :: StatusTone -> String
statusToneClass = case _ of
  StatusOk -> "status-chip--ok"
  StatusWarn -> "status-chip--warn"
  StatusError -> "status-chip--error"
  StatusNeutral -> "status-chip--neutral"

statusChip
  :: forall w i
   . { label :: String
     , tone :: StatusTone
     }
  -> HH.HTML w i
statusChip input =
  HH.span
    [ HP.classes (map HH.ClassName [ "status-chip", statusToneClass input.tone ]) ]
    [ HH.text input.label ]
