-- | Tests for pure wallet display helpers.
module Test.MPFS.WalletSpec (spec) where

import Prelude

import Data.Maybe (Maybe(..))
import MPFS.Wallet.Cip30
  ( lovelaceOfBalance
  , networkName
  , ownerKeyHashOfAddress
  )
import Test.Spec (Spec, describe, it)
import Test.Spec.Assertions (shouldEqual)

spec :: Spec Unit
spec = describe "MPFS Wallet CIP-30 Helpers" do
  it "labels known and unknown CIP-30 networks" do
    networkName 1 `shouldEqual` "mainnet"
    networkName 0 `shouldEqual` "testnet"
    networkName 42 `shouldEqual` "network 42"

  it "extracts payment key hashes from Shelley key-payment addresses" do
    ownerKeyHashOfAddress keyPaymentAddress `shouldEqual` Just paymentKeyHash
    ownerKeyHashOfAddress scriptPaymentAddress `shouldEqual` Nothing
    ownerKeyHashOfAddress "not hex" `shouldEqual` Nothing

  it "extracts lovelace from display-only balance CBOR" do
    lovelaceOfBalance "1903e8" `shouldEqual` Just "1000"
    lovelaceOfBalance "821903e8a0" `shouldEqual` Just "1000"
    lovelaceOfBalance "a0" `shouldEqual` Nothing

paymentKeyHash :: String
paymentKeyHash = "00112233445566778899aabbccddeeff00112233445566778899aabb"

keyPaymentAddress :: String
keyPaymentAddress = "00" <> paymentKeyHash <> "ff"

scriptPaymentAddress :: String
scriptPaymentAddress = "10" <> paymentKeyHash <> "ff"
