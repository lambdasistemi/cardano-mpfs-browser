module MPFS.UI.Material.Text (truncateMiddle) where

import Prelude

import Data.String.CodeUnits as String

truncateMiddle :: Int -> String -> String
truncateMiddle n value =
  if String.length value <= fullWidth then
    value
  else
    String.take flank value <> "…" <> String.drop tailStart value
  where
  flank = max 0 n

  fullWidth = flank * 2 + 1

  tailStart = String.length value - flank
