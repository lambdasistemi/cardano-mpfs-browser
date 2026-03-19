-- | CBOR decoder for Cardano Conway-era transactions.
-- Extracts inputs, outputs, fee, mint, redeemers.
module MPFS.Tx.Cbor
  ( decodeTx
  , RawTx
  , TxInput
  , TxOutput
  , TxValue
  , TxDatum
  , TxRedeemer
  , ExUnits
  ) where

import Data.ArrayBuffer.Types (Uint8Array)
import Foreign.Object (Object)

-- | A decoded transaction input (TxIn).
type TxInput =
  { txId :: String
  , txIx :: Int
  }

-- | Execution units for a redeemer.
type ExUnits =
  { mem :: Int
  , steps :: Int
  }

-- | A decoded redeemer.
type TxRedeemer =
  { purpose :: String
  , index :: Int
  , dataCbor :: String
  , exUnits :: ExUnits
  }

-- | Datum attached to an output.
type TxDatum =
  { type :: String
  , hash :: String
  , cbor :: String
  }

-- | Transaction value: lovelace + multi-asset.
type TxValue =
  { lovelace :: Int
  , assets :: Object (Object Int)
  }

-- | A decoded transaction output.
type TxOutput =
  { address :: String
  , value :: TxValue
  , datum :: TxDatum
  }

-- | Top-level decoded transaction.
type RawTx =
  { inputs :: Array TxInput
  , collateralInputs :: Array TxInput
  , outputs :: Array TxOutput
  , fee :: Int
  , mint :: Object (Object Int)
  , redeemers :: Array TxRedeemer
  , isValid :: Boolean
  }

-- | FFI: decode CBOR bytes into a transaction.
foreign import decodeTxImpl :: Uint8Array -> RawTx

-- | Decode CBOR-encoded transaction bytes.
decodeTx :: Uint8Array -> RawTx
decodeTx = decodeTxImpl
