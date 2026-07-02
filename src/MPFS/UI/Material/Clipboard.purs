module MPFS.UI.Material.Clipboard (writeText) where

import Prelude

import Control.Promise (Promise, toAffE)
import Effect (Effect)
import Effect.Aff (Aff)

foreign import writeTextImpl :: String -> Effect (Promise Unit)

writeText :: String -> Aff Unit
writeText = toAffE <<< writeTextImpl
