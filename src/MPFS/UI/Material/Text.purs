module MPFS.UI.Material.Text (decodeHexUtf8, truncateMiddle) where

import Prelude

import Data.Array as Array
import Data.Enum (fromEnum, toEnum)
import Data.Foldable (all)
import Data.Maybe (Maybe(..))
import Data.String.CodePoints (CodePoint)
import Data.String.CodePoints as CodePoints
import Data.String.CodeUnits as String

decodeHexUtf8 :: String -> Maybe String
decodeHexUtf8 value = do
  bytes <- parseHexBytes value
  codePoints <- decodeUtf8 bytes
  if all isPrintableCodePoint codePoints then
    Just (CodePoints.fromCodePointArray codePoints)
  else
    Nothing

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

parseHexBytes :: String -> Maybe (Array Int)
parseHexBytes value
  | String.length value `mod` 2 /= 0 = Nothing
  | otherwise = go 0
      where
      length = String.length value

      go index
        | index >= length = Just []
        | otherwise = do
            high <- hexAt index
            low <- hexAt (index + 1)
            rest <- go (index + 2)
            Just (Array.cons (high * 16 + low) rest)

      hexAt index = do
        char <- String.charAt index value
        hexValue char

hexValue :: Char -> Maybe Int
hexValue char =
  let
    code = fromEnum char
  in
    if code >= fromEnum '0' && code <= fromEnum '9' then
      Just (code - fromEnum '0')
    else if code >= fromEnum 'a' && code <= fromEnum 'f' then
      Just (10 + code - fromEnum 'a')
    else if code >= fromEnum 'A' && code <= fromEnum 'F' then
      Just (10 + code - fromEnum 'A')
    else
      Nothing

decodeUtf8 :: Array Int -> Maybe (Array CodePoint)
decodeUtf8 bytes = go 0
  where
  length = Array.length bytes

  go index
    | index >= length = Just []
    | otherwise = do
        first <- Array.index bytes index
        if first <= 0x7f then
          prepend first (index + 1)
        else if first >= 0xc2 && first <= 0xdf then do
          b1 <- continuation (index + 1)
          prepend ((first - 0xc0) * 0x40 + b1) (index + 2)
        else if first >= 0xe0 && first <= 0xef then do
          b1 <- continuation (index + 1)
          b2 <- continuation (index + 2)
          let
            codePoint = (first - 0xe0) * 0x1000 + b1 * 0x40 + b2
          if codePoint >= 0x800 && not (isSurrogate codePoint) then
            prepend codePoint (index + 3)
          else
            Nothing
        else if first >= 0xf0 && first <= 0xf4 then do
          b1 <- continuation (index + 1)
          b2 <- continuation (index + 2)
          b3 <- continuation (index + 3)
          let
            codePoint = (first - 0xf0) * 0x40000 + b1 * 0x1000 + b2 * 0x40 + b3
          if codePoint >= 0x10000 && codePoint <= 0x10ffff then
            prepend codePoint (index + 4)
          else
            Nothing
        else
          Nothing

  continuation index = do
    byte <- Array.index bytes index
    if byte >= 0x80 && byte <= 0xbf then
      Just (byte - 0x80)
    else
      Nothing

  prepend value nextIndex = do
    codePoint <- toEnum value
    rest <- go nextIndex
    Just (Array.cons codePoint rest)

isSurrogate :: Int -> Boolean
isSurrogate codePoint =
  codePoint >= 0xd800 && codePoint <= 0xdfff

isPrintableCodePoint :: CodePoint -> Boolean
isPrintableCodePoint codePoint =
  code == 0x09
    || code == 0x0a
    || code == 0x0d
    || (code >= 0x20 && not (code >= 0x7f && code <= 0x9f))
  where
  code = fromEnum codePoint
