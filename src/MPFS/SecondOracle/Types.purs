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
  ) where

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
