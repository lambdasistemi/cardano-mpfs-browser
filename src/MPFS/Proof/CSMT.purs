-- | CSMT (Compact Sparse Merkle Tree) inclusion
-- proof verification. Port of the Haskell
-- verification from haskell-mts.
module MPFS.Proof.CSMT
  ( verify
  , decodeAndVerify
  ) where

import Prelude

import Data.Array (drop, length, reverse, splitAt, uncons)
import Data.ArrayBuffer.Types (Uint8Array)
import Data.Maybe (Maybe(..))
import MPFS.Proof.CSMT.Cbor
  ( Direction
  , RawIndirect
  , RawProof
  , RawStep
  , decodeProof
  )

-- | Verify a decoded CSMT inclusion proof.
-- Returns true if the computed root matches
-- the claimed root hash.
verify :: RawProof -> Boolean
verify proof =
  bytesEq (computeRootHash proof) proof.proofRootHash

-- | Decode CBOR proof bytes and verify.
decodeAndVerify :: Uint8Array -> Boolean
decodeAndVerify = verify <<< decodeProof

-- | Compute the root hash from an inclusion proof
-- by folding from leaf to root.
computeRootHash :: RawProof -> Uint8Array
computeRootHash proof =
  let
    keyAfterRoot =
      drop (length proof.proofRootJump)
        proof.proofKey
    rootValue =
      go proof.proofValue
        (reverse keyAfterRoot)
        proof.proofSteps
  in
    rootHash
      { jump: proof.proofRootJump
      , value: rootValue
      }

go
  :: Uint8Array
  -> Array Direction
  -> Array RawStep
  -> Uint8Array
go acc _ steps | length steps == 0 = acc
go acc revKey steps =
  case uncons steps of
    Nothing -> acc
    Just { head: step, tail: rest } ->
      let
        { before: consumedRev, after: remainingRev } =
          splitAt step.stepConsumed revKey
        consumed = reverse consumedRev
      in
        case uncons consumed of
          Nothing -> acc -- invalid
          Just { head: direction, tail: stepJump } ->
            let
              me =
                { jump: stepJump
                , value: acc
                }
              combined =
                addWithDirection direction
                  me
                  step.stepSibling
            in
              go combined remainingRev rest

-- | Hash an indirect node: blake2b(serialize(indirect))
foreign import rootHash :: RawIndirect -> Uint8Array

-- | Combine two indirect nodes based on direction.
-- L: blake2b(serialize(left) ++ serialize(right))
-- R: blake2b(serialize(right) ++ serialize(left))
foreign import addWithDirection
  :: Direction -> RawIndirect -> RawIndirect -> Uint8Array

-- | Byte-level equality.
foreign import bytesEq
  :: Uint8Array -> Uint8Array -> Boolean
