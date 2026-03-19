-- | Tests for CBOR transaction decoding against
-- test vectors from mpfs-tx-vectors.
module Test.MPFS.TxCborSpec (spec) where

import Prelude

import Data.Array (length)
import Foreign.Object as Object
import Test.Spec (Spec, describe, it)
import Test.Spec.Assertions (shouldEqual)
import MPFS.Crypto.Hash (hexToBytes)
import MPFS.Tx.Cbor (decodeTx)

spec :: Spec Unit
spec = describe "CBOR Transaction Decoder" do

  it "decodes boot tx: 1 input, 1 output, mint +1" do
    let
      tx = decodeTx $ hexToBytes bootHex
    length tx.inputs `shouldEqual` 1
    length tx.outputs `shouldEqual` 1
    tx.fee `shouldEqual` 0
    -- Mint: one policy with +1 token
    Object.size tx.mint `shouldEqual` 1

  it "decodes burn tx: 1 input, no outputs, mint -1" do
    let
      tx = decodeTx $ hexToBytes burnHex
    length tx.inputs `shouldEqual` 1
    length tx.outputs `shouldEqual` 0
    Object.size tx.mint `shouldEqual` 1

  it "decodes request-insert tx: 1 input, 1 output with datum" do
    let
      tx = decodeTx $ hexToBytes requestInsertHex
    length tx.inputs `shouldEqual` 1
    length tx.outputs `shouldEqual` 1
    tx.fee `shouldEqual` 0

  it "decodes update tx: 2 inputs, 1 output, redeemer" do
    let
      tx = decodeTx $ hexToBytes updateHex
    length tx.inputs `shouldEqual` 2
    length tx.outputs `shouldEqual` 1
    length tx.redeemers `shouldEqual` 1

  it "decodes update-multi tx: 3 inputs" do
    let
      tx = decodeTx $ hexToBytes updateMultiHex
    length tx.inputs `shouldEqual` 3
    length tx.outputs `shouldEqual` 1
    length tx.redeemers `shouldEqual` 1

  it "decodes retract tx: 2 inputs, redeemer" do
    let
      tx = decodeTx $ hexToBytes retractHex
    length tx.inputs `shouldEqual` 2
    length tx.outputs `shouldEqual` 0
    length tx.redeemers `shouldEqual` 1

  it "decodes plain tx: 1 input, no mint" do
    let
      tx = decodeTx $ hexToBytes plainHex
    length tx.inputs `shouldEqual` 1
    length tx.outputs `shouldEqual` 0
    Object.size tx.mint `shouldEqual` 0

  it "decodes boot-request tx: 1 input, 2 outputs, mint" do
    let
      tx = decodeTx $ hexToBytes bootRequestHex
    length tx.inputs `shouldEqual` 1
    length tx.outputs `shouldEqual` 2
    Object.size tx.mint `shouldEqual` 1

-- Test vectors from mpfs-tx-vectors
bootHex :: String
bootHex = "84a400d90102818258201111111111111111111111111111111111111111111111111111111111111111000181a300581d70aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa01821a001e8480a1581caaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa15820aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa01028201d8185857d87a9fd8799f581ccccccccccccccccccccccccccccccccccccccccccccccccccccccccc5820bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb1a001e84801a000493e01a000927c0ffff020009a1581caaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa15820aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa01a0f5f6"

burnHex :: String
burnHex = "84a400d90102818258201111111111111111111111111111111111111111111111111111111111111111000180020009a1581caaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa15820aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa20a0f5f6"

requestInsertHex :: String
requestInsertHex = "84a300d90102818258201111111111111111111111111111111111111111111111111111111111111111000181a300581d70aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa011a001e8480028201d8185865d8799fd8799fd8799f5820aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaff581ccccccccccccccccccccccccccccccccccccccccccccccccccccccccc43010203d8799f420405ff1a000f42401b0000018bcfe56800ffff0200a0f5f6"

updateHex :: String
updateHex = "84a300d90102828258201111111111111111111111111111111111111111111111111111111111111111008258202222222222222222222222222222222222222222222222222222222222222222000181a300581d70aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa01821a001e8480a1581caaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa15820aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa01028201d8185857d87a9fd8799f581ccccccccccccccccccccccccccccccccccccccccccccccccccccccccc5820dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd1a001e84801a000493e01a000927c0ffff0200a105a182000082d87b9f80ff820000f5f6"

updateMultiHex :: String
updateMultiHex = "84a300d90102838258201111111111111111111111111111111111111111111111111111111111111111008258202222222222222222222222222222222222222222222222222222222222222222008258203333333333333333333333333333333333333333333333333333333333333333000181a300581d70aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa01821a001e8480a1581caaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa15820aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa01028201d8185857d87a9fd8799f581ccccccccccccccccccccccccccccccccccccccccccccccccccccccccc5820dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd1a001e84801a000493e01a000927c0ffff0200a105a182000082d87b9f80ff820000f5f6"

retractHex :: String
retractHex = "84a300d901028282582011111111111111111111111111111111111111111111111111111111111111110082582022222222222222222222222222222222222222222222222222222222222222220001800200a105a182000082d87c9fd8799f4000ffff820000f5f6"

plainHex :: String
plainHex = "84a300d901028182582011111111111111111111111111111111111111111111111111111111111111110001800200a0f5f6"

bootRequestHex :: String
bootRequestHex = "84a400d90102818258201111111111111111111111111111111111111111111111111111111111111111000182a300581d70aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa01821a001e8480a1581caaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa15820aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa01028201d8185857d87a9fd8799f581ccccccccccccccccccccccccccccccccccccccccccccccccccccccccc5820bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb1a001e84801a000493e01a000927c0ffffa300581d70aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa011a001e8480028201d8185865d8799fd8799fd8799f5820aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaff581ccccccccccccccccccccccccccccccccccccccccccccccccccccccccc43010203d8799f420405ff1a000f42401b0000018bcfe56800ffff020009a1581caaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa15820aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa01a0f5f6"
