-- | Wire/domain types for the csmt-utxo second oracle service.
module MPFS.SecondOracle.Types
  ( Hex
  , SlotNo
  , BlockHash
  , MerkleRoot
  , ProofCbor
  , AttestedTxOut
  , ChainPoint
  , OutputRef
  , MerkleRootEntry
  , ProofResponse
  , SecondOracleUnavailable(..)
  , SecondOracleVerdict(..)
  ) where

import Prelude

-- | Hex-encoded bytestring.
type Hex = String

type SlotNo = Int

type BlockHash = Hex

type MerkleRoot = Hex

-- | Hex-encoded CBOR proof consumed by csmt-verify-wasm.
type ProofCbor = Hex

-- | Hex-encoded attested transaction output payload.
type AttestedTxOut = Hex

type ChainPoint =
  { slotNo :: SlotNo
  , blockHash :: BlockHash
  }

type OutputRef =
  { txId :: Hex
  , txIx :: Int
  }

type MerkleRootEntry =
  { slotNo :: SlotNo
  , blockHash :: BlockHash
  , merkleRoot :: MerkleRoot
  }

type ProofResponse =
  { slotNo :: SlotNo
  , blockHash :: BlockHash
  , proof :: ProofCbor
  , txOut :: AttestedTxOut
  }

data SecondOracleUnavailable
  = MerkleRootsUnavailable String
  | ProofUnavailable String

derive instance Eq SecondOracleUnavailable

instance Show SecondOracleUnavailable where
  show (MerkleRootsUnavailable message) =
    "(MerkleRootsUnavailable " <> show message <> ")"
  show (ProofUnavailable message) =
    "(ProofUnavailable " <> show message <> ")"

data SecondOracleVerdict
  = SecondOracleVerified
      { chainPoint :: ChainPoint
      , merkleRoot :: MerkleRoot
      , factsRoot :: Hex
      }
  | SecondOracleMismatch
      { chainPoint :: ChainPoint
      , merkleRoot :: MerkleRoot
      , expectedFactsRoot :: Hex
      , attestedFactsRoot :: Hex
      }
  | SecondOracleMissingRoot ChainPoint
  | SecondOracleMalformedDatum String
  | SecondOracleUnavailable SecondOracleUnavailable

derive instance Eq SecondOracleVerdict

instance Show SecondOracleVerdict where
  show (SecondOracleVerified verdict) =
    "(SecondOracleVerified " <> show verdict <> ")"
  show (SecondOracleMismatch verdict) =
    "(SecondOracleMismatch " <> show verdict <> ")"
  show (SecondOracleMissingRoot chainPoint) =
    "(SecondOracleMissingRoot " <> show chainPoint <> ")"
  show (SecondOracleMalformedDatum message) =
    "(SecondOracleMalformedDatum " <> show message <> ")"
  show (SecondOracleUnavailable unavailable) =
    "(SecondOracleUnavailable " <> show unavailable <> ")"
