-- | CBOR decoder for Cardano Conway-era transactions.
-- All decoding logic is PureScript; only byte-level
-- Uint8Array access uses JS FFI (3 functions).
module MPFS.Tx.Cbor
  ( decodeTx
  , decodeTxOutput
  , decodePlutusData
  , RawTx
  , TxInput
  , TxOutput
  , TxValue
  , TxDatum(..)
  , TxRedeemer
  , ExUnits
  ) where

import Prelude

import Control.Monad.ST (ST)
import Control.Monad.ST as ST
import Control.Monad.ST.Ref (STRef)
import Control.Monad.ST.Ref as Ref
import Data.Array (snoc)
import Data.Array.ST as STA
import Data.ArrayBuffer.Types (Uint8Array)
import Data.Int (toNumber)
import Foreign.Object (Object)
import Foreign.Object as Object
import MPFS.Tx.Cbor.Bytes as B
import MPFS.Tx.Cbor.Bytes (bytesToHex, hexToBytes)
import MPFS.Tx.PlutusData (PlutusData(..))

-- -------------------------------------------------------
-- Reader state
-- -------------------------------------------------------

type ReaderST h =
  { bytes :: Uint8Array
  , offset :: STRef h Int
  }

readByte :: forall h. ReaderST h -> ST h Int
readByte r = do
  o <- Ref.read r.offset
  void $ Ref.write (o + 1) r.offset
  pure $ B.unsafeIndex r.bytes o

peekByte :: forall h. ReaderST h -> ST h Int
peekByte r = do
  o <- Ref.read r.offset
  pure $ B.unsafeIndex r.bytes o

readArgument :: forall h. ReaderST h -> Int -> ST h Int
readArgument _ info | info < 24 = pure info
readArgument r 24 = readByte r
readArgument r 25 = do
  hi <- readByte r
  lo <- readByte r
  pure $ hi * 256 + lo
readArgument r 26 = do
  b0 <- readByte r
  b1 <- readByte r
  b2 <- readByte r
  b3 <- readByte r
  pure $ b0 * 16777216 + b1 * 65536 + b2 * 256 + b3
readArgument r 27 = do
  hi <- readArgument r 26
  lo <- readArgument r 26
  pure $ mul32 hi + lo
readArgument _ 31 = pure (-1)
readArgument _ _ = pure 0

readArgumentNumber :: forall h. ReaderST h -> Int -> ST h Number
readArgumentNumber _ info | info < 24 = pure $ toNumber info
readArgumentNumber r 24 = toNumber <$> readByte r
readArgumentNumber r 25 = do
  hi <- readByte r
  lo <- readByte r
  pure $ toNumber hi * 256.0 + toNumber lo
readArgumentNumber r 26 = do
  b0 <- readByte r
  b1 <- readByte r
  b2 <- readByte r
  b3 <- readByte r
  pure
    $ toNumber b0 * 16777216.0
        + toNumber b1 * 65536.0
        + toNumber b2 * 256.0
        + toNumber b3
readArgumentNumber r 27 = do
  hi <- readArgumentNumber r 26
  lo <- readArgumentNumber r 26
  pure $ hi * 4294967296.0 + lo
readArgumentNumber _ 31 = pure (-1.0)
readArgumentNumber _ _ = pure 0.0

readHeader
  :: forall h. ReaderST h -> ST h { major :: Int, arg :: Int }
readHeader r = do
  b <- readByte r
  let major = b `shr` 5
  let info = b `and` 31
  arg <- readArgument r info
  pure { major, arg }

readHeaderNumber
  :: forall h. ReaderST h -> ST h { major :: Int, arg :: Number }
readHeaderNumber r = do
  b <- readByte r
  let major = b `shr` 5
  let info = b `and` 31
  arg <- readArgumentNumber r info
  pure { major, arg }

shr :: Int -> Int -> Int
shr = intShr

and :: Int -> Int -> Int
and = intAnd

foreign import intShr :: Int -> Int -> Int
foreign import intAnd :: Int -> Int -> Int
foreign import mul32 :: Int -> Int

readUint :: forall h. ReaderST h -> ST h Int
readUint r = do
  { arg } <- readHeader r
  pure arg

readInt :: forall h. ReaderST h -> ST h Int
readInt r = do
  { major, arg } <- readHeader r
  if major == 1 then pure (-1 - arg) else pure arg

readPlutusInt :: forall h. ReaderST h -> ST h Number
readPlutusInt r = do
  { major, arg } <- readHeaderNumber r
  if major == 1 then pure (-1.0 - arg) else pure arg

readBytes :: forall h. ReaderST h -> ST h Uint8Array
readBytes r = do
  { arg } <- readHeader r
  if arg == -1 then
    hexToBytes <$> readIndefiniteBytesHex r ""
  else do
    o <- Ref.read r.offset
    void $ Ref.write (o + arg) r.offset
    pure $ B.slice r.bytes o (o + arg)

readIndefiniteBytesHex
  :: forall h. ReaderST h -> String -> ST h String
readIndefiniteBytesHex r acc = do
  b <- peekByte r
  if b == 0xff then do
    void $ readByte r
    pure acc
  else do
    chunk <- readBytesHex r
    readIndefiniteBytesHex r (acc <> chunk)

readBytesHex :: forall h. ReaderST h -> ST h String
readBytesHex r = bytesToHex <$> readBytes r

readMapLen :: forall h. ReaderST h -> ST h Int
readMapLen r = do
  { arg } <- readHeader r
  pure arg

readArrayLen :: forall h. ReaderST h -> ST h Int
readArrayLen r = do
  { arg } <- readHeader r
  pure arg

readTag :: forall h. ReaderST h -> ST h Int
readTag r = do
  { arg } <- readHeader r
  pure arg

skip :: forall h. ReaderST h -> ST h Unit
skip r = do
  b <- readByte r
  let major = b `shr` 5
  let info = b `and` 31
  arg <- readArgument r info
  case major of
    0 -> pure unit
    1 -> pure unit
    2 -> do
      if arg == -1 then skipUntilBreak r
      else do
        o <- Ref.read r.offset
        void $ Ref.write (o + arg) r.offset
    3 -> do
      if arg == -1 then skipUntilBreak r
      else do
        o <- Ref.read r.offset
        void $ Ref.write (o + arg) r.offset
    4 ->
      if arg == -1 then skipUntilBreak r
      else skipN r arg
    5 ->
      if arg == -1 then skipUntilBreakPairs r
      else skipN r (arg * 2)
    6 -> skip r
    7 -> pure unit
    _ -> pure unit

skipN :: forall h. ReaderST h -> Int -> ST h Unit
skipN _ 0 = pure unit
skipN r n = do
  skip r
  skipN r (n - 1)

skipUntilBreak :: forall h. ReaderST h -> ST h Unit
skipUntilBreak r = do
  b <- peekByte r
  if b == 0xff then void (readByte r)
  else do
    skip r
    skipUntilBreak r

skipUntilBreakPairs :: forall h. ReaderST h -> ST h Unit
skipUntilBreakPairs r = do
  b <- peekByte r
  if b == 0xff then void (readByte r)
  else do
    skip r
    skip r
    skipUntilBreakPairs r

-- -------------------------------------------------------
-- Plutus Data decoder
-- -------------------------------------------------------

readPlutusData :: forall h. ReaderST h -> ST h PlutusData
readPlutusData r = do
  b <- peekByte r
  let major = b `shr` 5
  case major of
    6 -> do
      tag <- readTag r
      let
        constrIdx =
          if tag >= 121 && tag <= 127 then tag - 121
          else tag - 1280 + 7
      fields <- readPlutusFields r
      pure $ Constr constrIdx fields
    0 -> do
      n <- readPlutusInt r
      pure $ PInt n
    1 -> do
      n <- readPlutusInt r
      pure $ PInt n
    2 -> do
      hex <- readBytesHex r
      pure $ PBytes hex
    4 -> do
      len <- readArrayLen r
      items <- readPlutusN r len
      pure $ PList items
    5 -> do
      len <- readMapLen r
      entries <- readPlutusMapN r len
      pure $ PMap entries
    _ -> do
      skip r
      pure $ PInt 0.0

readPlutusFields
  :: forall h. ReaderST h -> ST h (Array PlutusData)
readPlutusFields r = do
  b <- peekByte r
  if b == 0x9f then do
    void $ readByte r
    readPlutusUntilBreak r []
  else do
    len <- readArrayLen r
    readPlutusN r len

readPlutusUntilBreak
  :: forall h
   . ReaderST h
  -> Array PlutusData
  -> ST h (Array PlutusData)
readPlutusUntilBreak r acc = do
  b <- peekByte r
  if b == 0xff then do
    void $ readByte r
    pure acc
  else do
    item <- readPlutusData r
    readPlutusUntilBreak r (snoc acc item)

readPlutusN
  :: forall h. ReaderST h -> Int -> ST h (Array PlutusData)
readPlutusN r n = do
  arr <- STA.new
  go arr n
  STA.unsafeFreeze arr
  where
  go _ 0 = pure unit
  go arr remaining = do
    item <- readPlutusData r
    void $ STA.push item arr
    go arr (remaining - 1)

readPlutusMapN
  :: forall h
   . ReaderST h
  -> Int
  -> ST h (Array { k :: PlutusData, v :: PlutusData })
readPlutusMapN r n = do
  arr <- STA.new
  go arr n
  STA.unsafeFreeze arr
  where
  go _ 0 = pure unit
  go arr remaining = do
    k <- readPlutusData r
    v <- readPlutusData r
    void $ STA.push { k, v } arr
    go arr (remaining - 1)

-- -------------------------------------------------------
-- Transaction types
-- -------------------------------------------------------

type TxInput =
  { txId :: String
  , txIx :: Int
  }

type ExUnits =
  { mem :: Int
  , steps :: Int
  }

type TxRedeemer =
  { purpose :: String
  , index :: Int
  , dataCbor :: String
  , "data" :: PlutusData
  , exUnits :: ExUnits
  }

data TxDatum
  = DatumHash String
  | InlineDatum PlutusData
  | NoDatum

type TxValue =
  { lovelace :: Int
  , assets :: Object (Object Int)
  }

type TxOutput =
  { address :: String
  , value :: TxValue
  , datum :: TxDatum
  }

type RawTx =
  { inputs :: Array TxInput
  , collateralInputs :: Array TxInput
  , outputs :: Array TxOutput
  , fee :: Int
  , mint :: Object (Object Int)
  , redeemers :: Array TxRedeemer
  , isValid :: Boolean
  }

-- -------------------------------------------------------
-- Transaction decoder
-- -------------------------------------------------------

readTxIn :: forall h. ReaderST h -> ST h TxInput
readTxIn r = do
  _ <- readArrayLen r
  txId <- readBytesHex r
  txIx <- readUint r
  pure { txId, txIx }

readInputs :: forall h. ReaderST h -> ST h (Array TxInput)
readInputs r = do
  b <- peekByte r
  let major = b `shr` 5
  when (major == 6) (void $ readTag r)
  len <- readArrayLen r
  arr <- STA.new
  go arr len
  STA.unsafeFreeze arr
  where
  go _ 0 = pure unit
  go arr n = do
    inp <- readTxIn r
    void $ STA.push inp arr
    go arr (n - 1)

readValue :: forall h. ReaderST h -> ST h TxValue
readValue r = do
  b <- peekByte r
  let major = b `shr` 5
  if major == 0 then do
    lovelace <- readUint r
    pure { lovelace, assets: Object.empty }
  else do
    _ <- readArrayLen r
    lovelace <- readUint r
    assets <- readMultiAsset r
    pure { lovelace, assets }

readMultiAsset
  :: forall h. ReaderST h -> ST h (Object (Object Int))
readMultiAsset r = do
  numPolicies <- readMapLen r
  go Object.empty numPolicies
  where
  go acc 0 = pure acc
  go acc n = do
    policyId <- readBytesHex r
    numAssets <- readMapLen r
    policyAssets <- goAssets Object.empty numAssets
    go (Object.insert policyId policyAssets acc) (n - 1)

  goAssets acc 0 = pure acc
  goAssets acc n = do
    name <- readBytesHex r
    amount <- readInt r
    goAssets (Object.insert name amount acc) (n - 1)

readDatum :: forall h. ReaderST h -> ST h TxDatum
readDatum r = do
  b <- peekByte r
  let major = b `shr` 5
  if major == 4 then do
    _ <- readArrayLen r
    tag <- readUint r
    if tag == 0 then do
      hash <- readBytesHex r
      pure $ DatumHash hash
    else if tag == 1 then do
      _ <- readTag r
      datumBytes <- readBytes r
      let pd = decodePlutusData datumBytes
      pure $ InlineDatum pd
    else do
      skip r
      pure NoDatum
  else do
    skip r
    pure NoDatum

readOutput :: forall h. ReaderST h -> ST h TxOutput
readOutput r = do
  b <- peekByte r
  let major = b `shr` 5
  if major == 5 then do
    len <- readMapLen r
    readOutputMap r len "" { lovelace: 0, assets: Object.empty } NoDatum
  else do
    len <- readArrayLen r
    address <- readBytesHex r
    value <- readValue r
    datum <- if len >= 3 then readDatum r else pure NoDatum
    pure { address, value, datum }

readOutputMap
  :: forall h
   . ReaderST h
  -> Int
  -> String
  -> TxValue
  -> TxDatum
  -> ST h TxOutput
readOutputMap _ 0 address value datum =
  pure { address, value, datum }
readOutputMap r n address value datum = do
  key <- readUint r
  case key of
    0 -> do
      addr <- readBytesHex r
      readOutputMap r (n - 1) addr value datum
    1 -> do
      val <- readValue r
      readOutputMap r (n - 1) address val datum
    2 -> do
      d <- readDatum r
      readOutputMap r (n - 1) address value d
    _ -> do
      skip r
      readOutputMap r (n - 1) address value datum

readRedeemers
  :: forall h. ReaderST h -> ST h (Array TxRedeemer)
readRedeemers r = do
  numRedeemers <- readMapLen r
  arr <- STA.new
  go arr numRedeemers
  STA.unsafeFreeze arr
  where
  go _ 0 = pure unit
  go arr n = do
    _ <- readArrayLen r
    tag <- readUint r
    idx <- readUint r
    _ <- readArrayLen r
    dataStart <- Ref.read r.offset
    pd <- readPlutusData r
    dataEnd <- Ref.read r.offset
    let
      dataCbor = bytesToHex
        $ B.slice r.bytes dataStart dataEnd
    _ <- readArrayLen r
    mem <- readUint r
    steps <- readUint r
    let
      purpose = case tag of
        0 -> "spend"
        1 -> "mint"
        2 -> "cert"
        3 -> "reward"
        _ -> "unknown"
    void $ STA.push
      { purpose
      , index: idx
      , dataCbor
      , "data": pd
      , exUnits: { mem, steps }
      }
      arr
    go arr (n - 1)

readTxBody
  :: forall h
   . ReaderST h
  -> ST h
       { inputs :: Array TxInput
       , collateralInputs :: Array TxInput
       , outputs :: Array TxOutput
       , fee :: Int
       , mint :: Object (Object Int)
       }
readTxBody r = do
  bodyLen <- readMapLen r
  go bodyLen [] [] [] 0 Object.empty
  where
  go 0 inputs collInputs outputs fee mint =
    pure { inputs, collateralInputs: collInputs, outputs, fee, mint }
  go n inputs collInputs outputs fee mint = do
    key <- readUint r
    case key of
      0 -> do
        ins <- readInputs r
        go (n - 1) ins collInputs outputs fee mint
      1 -> do
        outLen <- readArrayLen r
        outs <- readOutputsN r outLen
        go (n - 1) inputs collInputs outs fee mint
      2 -> do
        f <- readUint r
        go (n - 1) inputs collInputs outputs f mint
      9 -> do
        m <- readMultiAsset r
        go (n - 1) inputs collInputs outputs fee m
      13 -> do
        ci <- readInputs r
        go (n - 1) inputs ci outputs fee mint
      _ -> do
        skip r
        go (n - 1) inputs collInputs outputs fee mint

readOutputsN
  :: forall h. ReaderST h -> Int -> ST h (Array TxOutput)
readOutputsN r n = do
  arr <- STA.new
  go arr n
  STA.unsafeFreeze arr
  where
  go _ 0 = pure unit
  go arr remaining = do
    out <- readOutput r
    void $ STA.push out arr
    go arr (remaining - 1)

readWitnesses
  :: forall h. ReaderST h -> ST h (Array TxRedeemer)
readWitnesses r = do
  witLen <- readMapLen r
  go witLen []
  where
  go 0 redeemers = pure redeemers
  go n redeemers = do
    key <- readUint r
    if key == 5 then do
      reds <- readRedeemers r
      go (n - 1) reds
    else do
      skip r
      go (n - 1) redeemers

decodePlutusData :: Uint8Array -> PlutusData
decodePlutusData bytes = ST.run do
  offset <- Ref.new 0
  let r = { bytes, offset }
  readPlutusData r

decodeTx :: Uint8Array -> RawTx
decodeTx bytes = ST.run do
  offset <- Ref.new 0
  let r = { bytes, offset }
  _ <- readArrayLen r
  body <- readTxBody r
  redeemers <- readWitnesses r
  isValidByte <- peekByte r
  skip r
  skip r
  let isValid = isValidByte /= 0xf4
  pure
    { inputs: body.inputs
    , collateralInputs: body.collateralInputs
    , outputs: body.outputs
    , fee: body.fee
    , mint: body.mint
    , redeemers
    , isValid
    }

decodeTxOutput :: Uint8Array -> TxOutput
decodeTxOutput bytes = ST.run do
  offset <- Ref.new 0
  let r = { bytes, offset }
  readOutput r
