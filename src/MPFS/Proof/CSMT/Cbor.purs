-- | CBOR decoding for CSMT inclusion proofs.
module MPFS.Proof.CSMT.Cbor
  ( decodeProof
  , RawProof
  , RawStep
  , RawIndirect
  , Direction
  , Key
  ) where

import Data.ArrayBuffer.Types (Uint8Array)

-- | Direction in the binary tree: 0 = Left, 1 = Right.
type Direction = Int

-- | Key as a list of directions.
type Key = Array Direction

-- | Indirect node: jump path + hash value.
type RawIndirect =
  { jump :: Key
  , value :: Uint8Array
  }

-- | A single proof step.
type RawStep =
  { stepConsumed :: Int
  , stepSibling :: RawIndirect
  }

-- | Decoded inclusion proof.
type RawProof =
  { proofKey :: Key
  , proofValue :: Uint8Array
  , proofRootHash :: Uint8Array
  , proofSteps :: Array RawStep
  , proofRootJump :: Key
  }

-- | Decode CBOR bytes into a CSMT inclusion proof.
foreign import decodeProofImpl
  :: Uint8Array -> RawProof

decodeProof :: Uint8Array -> RawProof
decodeProof = decodeProofImpl
