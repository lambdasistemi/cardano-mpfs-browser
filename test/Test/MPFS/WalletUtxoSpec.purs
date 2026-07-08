module Test.MPFS.WalletUtxoSpec (spec) where

import Prelude

import Data.Argonaut.Core (stringify)
import Data.Argonaut.Encode.Class (encodeJson)
import Data.String.CodeUnits as String
import MPFS.App.Wallet (walletUtxoAddresses)
import MPFS.Client.Types (BootBody)
import Test.Spec (Spec, describe, it)
import Test.Spec.Assertions (shouldEqual)

spec :: Spec Unit
spec = describe "MPFS Wallet UTxOs" do
  it "extracts base and enterprise output addresses from CIP-30 UTxO CBOR" do
    walletUtxoAddresses
      [ utxoArrayOutput 0 baseAddress
      , utxoArrayOutput 1 enterpriseAddress
      ]
      `shouldEqual`
        [ baseAddress
        , enterpriseAddress
        ]

  it "returns distinct output addresses in first-seen order" do
    walletUtxoAddresses
      [ utxoArrayOutput 0 baseAddress
      , utxoArrayOutput 1 baseAddress
      , utxoArrayOutput 2 enterpriseAddress
      ]
      `shouldEqual`
        [ baseAddress
        , enterpriseAddress
        ]

  it "extracts output address from map-style TxOut CBOR" do
    walletUtxoAddresses [ utxoMapOutput 0 mapAddress ]
      `shouldEqual`
        [ mapAddress ]

  it "encodes boot bodies with the multi-address request shape" do
    stringify
      ( encodeJson
          ( { addresses: [ baseAddress, enterpriseAddress ] } :: BootBody
          )
      )
      `shouldEqual`
        ( "{\"addresses\":[\""
            <> baseAddress
            <> "\",\""
            <> enterpriseAddress
            <> "\"]}"
        )

baseAddress :: String
baseAddress =
  "00"
    <> "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    <> "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"

enterpriseAddress :: String
enterpriseAddress =
  "60"
    <> "cccccccccccccccccccccccccccccccccccccccccccccccccccccccc"

mapAddress :: String
mapAddress =
  "00"
    <> "dddddddddddddddddddddddddddddddddddddddddddddddddddddddd"
    <> "eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"

utxoArrayOutput :: Int -> String -> String
utxoArrayOutput txIx address =
  "82" <> txInput txIx <> "82" <> cborBytes address <> "01"

utxoMapOutput :: Int -> String -> String
utxoMapOutput txIx address =
  "82" <> txInput txIx <> "a200" <> cborBytes address <> "0101"

txInput :: Int -> String
txInput txIx =
  "825820"
    <> "1111111111111111111111111111111111111111111111111111111111111111"
    <> cborSmallUint txIx

cborBytes :: String -> String
cborBytes hex =
  "58" <> cborSmallUint (hexLengthBytes hex) <> hex

cborSmallUint :: Int -> String
cborSmallUint n
  | n < 16 = "0" <> show n
  | otherwise = intToTwoDigitHex n

hexLengthBytes :: String -> Int
hexLengthBytes hex = div (String.length hex) 2

intToTwoDigitHex :: Int -> String
intToTwoDigitHex = case _ of
  16 -> "10"
  17 -> "11"
  18 -> "12"
  19 -> "13"
  20 -> "14"
  21 -> "15"
  22 -> "16"
  23 -> "17"
  24 -> "18"
  25 -> "19"
  26 -> "1a"
  27 -> "1b"
  28 -> "1c"
  29 -> "1d"
  30 -> "1e"
  31 -> "1f"
  32 -> "20"
  33 -> "21"
  34 -> "22"
  35 -> "23"
  36 -> "24"
  37 -> "25"
  38 -> "26"
  39 -> "27"
  40 -> "28"
  41 -> "29"
  42 -> "2a"
  43 -> "2b"
  44 -> "2c"
  45 -> "2d"
  46 -> "2e"
  47 -> "2f"
  48 -> "30"
  49 -> "31"
  50 -> "32"
  51 -> "33"
  52 -> "34"
  53 -> "35"
  54 -> "36"
  55 -> "37"
  56 -> "38"
  57 -> "39"
  _ -> "00"
