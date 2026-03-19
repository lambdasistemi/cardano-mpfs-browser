-- | Plutus Data AST and MPFS semantic interpretation.
-- The CBOR decoding happens in JS FFI; this module
-- provides the types and the cage-specific interpretation
-- of constructor indices into domain operations.
module MPFS.Tx.PlutusData
  ( PlutusData(..)
  , MapEntry
  , CageDatum(..)
  , TokenState
  , Request
  , Operation(..)
  , SpendRedeemer(..)
  , interpretDatum
  , interpretSpendRedeemer
  ) where

import Prelude

import Data.Array (index)
import Data.Maybe (Maybe(..))

-- | Plutus Data AST (decoded from CBOR by JS FFI).
data PlutusData
  = Constr Int (Array PlutusData)
  | PInt Int
  | PBytes String
  | PList (Array PlutusData)
  | PMap (Array MapEntry)

-- | Key-value pair in a Plutus Data map.
type MapEntry = { k :: PlutusData, v :: PlutusData }

-- | On-chain token state fields.
type TokenState =
  { owner :: String
  , root :: String
  , maxFee :: Int
  , processTime :: Int
  , retractTime :: Int
  }

-- | Trie operation requested.
data Operation
  = Insert String
  | Delete String
  | Update String String

-- | On-chain request fields.
type Request =
  { tokenId :: String
  , owner :: String
  , key :: String
  , operation :: Operation
  , fee :: Int
  , submittedAt :: Int
  }

-- | Interpreted cage datum.
data CageDatum
  = RequestDatum Request
  | StateDatum TokenState

-- | Interpreted spending redeemer.
data SpendRedeemer
  = End
  | Contribute { txId :: String, txIx :: Int }
  | Modify
  | Retract { txId :: String, txIx :: Int }
  | Reject

-- | Extract a hex bytes value from PlutusData.
asBytes :: PlutusData -> Maybe String
asBytes (PBytes s) = Just s
asBytes _ = Nothing

-- | Extract an integer from PlutusData.
asInt :: PlutusData -> Maybe Int
asInt (PInt n) = Just n
asInt _ = Nothing

-- | Extract fields from a constructor.
asConstr :: Int -> PlutusData -> Maybe (Array PlutusData)
asConstr expected (Constr ix fields)
  | ix == expected = Just fields
asConstr _ _ = Nothing

-- | Interpret an operation from PlutusData.
interpretOp :: PlutusData -> Maybe Operation
interpretOp (Constr 0 fields) = do
  v <- index fields 0 >>= asBytes
  pure $ Insert v
interpretOp (Constr 1 fields) = do
  v <- index fields 0 >>= asBytes
  pure $ Delete v
interpretOp (Constr 2 fields) = do
  old <- index fields 0 >>= asBytes
  new <- index fields 1 >>= asBytes
  pure $ Update old new
interpretOp _ = Nothing

-- | Interpret a token state from PlutusData.
interpretState :: PlutusData -> Maybe TokenState
interpretState d = do
  fields <- asConstr 0 d
  owner <- index fields 0 >>= asBytes
  root <- index fields 1 >>= asBytes
  maxFee <- index fields 2 >>= asInt
  processTime <- index fields 3 >>= asInt
  retractTime <- index fields 4 >>= asInt
  pure { owner, root, maxFee, processTime, retractTime }

-- | Interpret a request from PlutusData.
interpretRequest :: PlutusData -> Maybe Request
interpretRequest d = do
  fields <- asConstr 0 d
  tokenIdD <- index fields 0
  tokenIdFields <- asConstr 0 tokenIdD
  tokenId <- index tokenIdFields 0 >>= asBytes
  owner <- index fields 1 >>= asBytes
  key <- index fields 2 >>= asBytes
  opD <- index fields 3
  operation <- interpretOp opD
  fee <- index fields 4 >>= asInt
  submittedAt <- index fields 5 >>= asInt
  pure { tokenId, owner, key, operation, fee, submittedAt }

-- | Interpret an inline datum as a cage datum.
-- Constr 0 = RequestDatum, Constr 1 = StateDatum.
interpretDatum :: PlutusData -> Maybe CageDatum
interpretDatum (Constr 0 fields) = do
  inner <- index fields 0
  req <- interpretRequest inner
  pure $ RequestDatum req
interpretDatum (Constr 1 fields) = do
  inner <- index fields 0
  st <- interpretState inner
  pure $ StateDatum st
interpretDatum _ = Nothing

-- | Interpret a TxOutRef from PlutusData.
interpretTxOutRef
  :: PlutusData -> Maybe { txId :: String, txIx :: Int }
interpretTxOutRef d = do
  fields <- asConstr 0 d
  txId <- index fields 0 >>= asBytes
  txIx <- index fields 1 >>= asInt
  pure { txId, txIx }

-- | Interpret a spending redeemer.
-- Constr 0 = End, Constr 1 = Contribute,
-- Constr 2 = Modify, Constr 3 = Retract,
-- Constr 4 = Reject.
interpretSpendRedeemer :: PlutusData -> Maybe SpendRedeemer
interpretSpendRedeemer (Constr 0 _) = Just End
interpretSpendRedeemer (Constr 1 fields) = do
  ref <- index fields 0 >>= interpretTxOutRef
  pure $ Contribute ref
interpretSpendRedeemer (Constr 2 _) = Just Modify
interpretSpendRedeemer (Constr 3 fields) = do
  ref <- index fields 0 >>= interpretTxOutRef
  pure $ Retract ref
interpretSpendRedeemer (Constr 4 _) = Just Reject
interpretSpendRedeemer _ = Nothing
