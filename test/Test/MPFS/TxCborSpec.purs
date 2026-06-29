-- | Tests for CBOR transaction decoding against
-- test vectors from mpfs-tx-vectors.
module Test.MPFS.TxCborSpec (spec) where

import Prelude

import Data.Argonaut.Decode.Class (decodeJson)
import Data.Argonaut.Parser (jsonParser)
import Data.Array (index, length)
import Data.Either (Either(..))
import Data.Maybe (Maybe(..))
import Effect.Aff (Aff, throwError)
import Effect.Exception (error)
import Foreign.Object as Object
import Node.Encoding (Encoding(..))
import Node.FS.Aff as FS
import Test.Spec (Spec, describe, it)
import Test.Spec.Assertions (shouldEqual, fail)
import MPFS.Tx.Cbor (TxDatum(..), decodeTx, decodeTxOutput)
import MPFS.Tx.Cbor.Bytes (hexToBytes)
import MPFS.Tx.PlutusData
  ( CageDatum(..)
  , Operation(..)
  , SpendRedeemer(..)
  , interpretDatum
  , interpretSpendRedeemer
  )

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

  describe "MPFS Semantic Interpretation" do

    it "boot tx output has StateDatum" do
      let
        tx = decodeTx $ hexToBytes bootHex
        out = index tx.outputs 0
      case out of
        Nothing -> fail "missing output"
        Just o -> case o.datum of
          InlineDatum pd -> case interpretDatum pd of
            Just (StateDatum st) -> do
              st.maxFee `shouldEqual` 2000000.0
              st.processTime `shouldEqual` 300000.0
              st.retractTime `shouldEqual` 600000.0
            _ -> fail "expected StateDatum"
          _ -> fail "expected InlineDatum"

    it "request-insert has RequestDatum with Insert op" do
      let
        tx = decodeTx $ hexToBytes requestInsertHex
        out = index tx.outputs 0
      case out of
        Nothing -> fail "missing output"
        Just o -> case o.datum of
          InlineDatum pd -> case interpretDatum pd of
            Just (RequestDatum req) ->
              case req.operation of
                Insert _ -> pure unit
                _ -> fail "expected Insert"
            _ -> fail "expected RequestDatum"
          _ -> fail "expected InlineDatum"

    it "real request output decodes indefinite bytestring value" do
      txOutCbor <- realRequestTxOutCbor
      let
        out = decodeTxOutput $ hexToBytes txOutCbor
      case out.datum of
        InlineDatum pd -> case interpretDatum pd of
          Just (RequestDatum req) -> do
            req.tokenId `shouldEqual` realTokenId
            req.owner `shouldEqual` realOwner
            req.key `shouldEqual` realRequestKey
            req.fee `shouldEqual` 1000000.0
            req.submittedAt `shouldEqual` 1781203626691.0
            case req.operation of
              Insert value ->
                value `shouldEqual` realRequestValue
              _ -> fail "expected Insert"
          _ -> fail "expected RequestDatum"
        _ -> fail "expected InlineDatum"

    it "update tx redeemer is Modify" do
      let
        tx = decodeTx $ hexToBytes updateHex
        red = index tx.redeemers 0
      case red of
        Nothing -> fail "missing redeemer"
        Just r ->
          case interpretSpendRedeemer r."data" of
            Just Modify -> pure unit
            _ -> fail "expected Modify"

    it "retract tx redeemer is Retract" do
      let
        tx = decodeTx $ hexToBytes retractHex
        red = index tx.redeemers 0
      case red of
        Nothing -> fail "missing redeemer"
        Just r ->
          case interpretSpendRedeemer r."data" of
            Just (Retract _) -> pure unit
            _ -> fail "expected Retract"

type RealRequestsFixture =
  { request_set ::
      { entries :: Array { txout_cbor :: String }
      }
  }

realRequestsFixturePath :: String
realRequestsFixturePath = "test/fixtures/real-umpfs-requests.json"

realRequestTxOutCbor :: Aff String
realRequestTxOutCbor = do
  body <- FS.readTextFile UTF8 realRequestsFixturePath
  case jsonParser body of
    Left err ->
      throwError $ error err
    Right json ->
      case decodeJson json of
        Left err ->
          throwError $ error $ show err
        Right (fixture :: RealRequestsFixture) ->
          case index fixture.request_set.entries 0 of
            Nothing ->
              throwError $ error "real requests fixture has no entries"
            Just entry ->
              pure entry.txout_cbor

realTokenId :: String
realTokenId =
  "976821dbd0922f93cda689da92a6faf1894c8151bc86d6c8f725ec089aaacbc6"

realOwner :: String
realOwner =
  "8da87507ba0a8a3c67eaeb8ec768dee132ad8ecac6f526ac526f0c9f"

realRequestKey :: String
realRequestKey = "7b2274797065223a22636f6e666967227d"

realRequestValue :: String
realRequestValue =
  "7b226167656e74223a226238313133343233373730623564643064666530633538323630383732623464383735363930616335366561626634643330313366663137222c2270726f746f636f6c56657273696f6e223a302c227465737452756e223a7b226d61784475726174696f6e223a31322c226d696e4475726174696f6e223a317d7d"

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
