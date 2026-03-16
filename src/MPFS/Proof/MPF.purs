-- | Merkle Patricia Forestry proof verification.
-- Port of the Aiken on-chain verification from
-- aiken-lang/merkle-patricia-forestry.
module MPFS.Proof.MPF
  ( ProofStep(..)
  , Neighbor
  , Proof
  , has
  , including
  ) where

import Prelude

import Data.Array (uncons)
import Data.ArrayBuffer.Types (Uint8Array)
import Data.Maybe (Maybe(..))
import MPFS.Crypto.Hash (blake2b256)
import MPFS.Proof.MPF.Bytes
  ( combine
  , nibble
  , nibbles
  , sliceBytes
  , suffix
  )
import MPFS.Proof.MPF.Merkle
  ( merkle16
  , sparseMerkle16
  )

-- | A single step in an MPF proof.
data ProofStep
  = Branch { skip :: Int, neighbors :: Uint8Array }
  | Fork { skip :: Int, neighbor :: Neighbor }
  | Leaf
      { skip :: Int
      , key :: Uint8Array
      , value :: Uint8Array
      }

-- | Neighbor node in a fork proof step.
type Neighbor =
  { nibble :: Int
  , prefix :: Uint8Array
  , root :: Uint8Array
  }

-- | A proof is a list of steps.
type Proof = Array ProofStep

-- | Check whether a key-value pair exists in
-- a trie with the given root.
has
  :: Uint8Array
  -> Uint8Array
  -> Uint8Array
  -> Proof
  -> Boolean
has root key value proof =
  bytesEq (including key value proof) root

-- | Compute the root hash from a proof and
-- a key-value pair. If the proof is valid,
-- this equals the trie root.
including
  :: Uint8Array
  -> Uint8Array
  -> Proof
  -> Uint8Array
including key value proof =
  doIncluding
    (blake2b256 key)
    (blake2b256 value)
    0
    proof

doIncluding
  :: Uint8Array
  -> Uint8Array
  -> Int
  -> Proof
  -> Uint8Array
doIncluding path value cursor proof =
  case uncons proof of
    Nothing ->
      combine (suffix path cursor) value
    Just { head: Branch r, tail: rest } ->
      let
        nextCursor = cursor + 1 + r.skip
        root = doIncluding path value
          nextCursor
          rest
      in
        doBranch path cursor nextCursor
          root
          r.neighbors
    Just { head: Fork r, tail: rest } ->
      let
        nextCursor = cursor + 1 + r.skip
        root = doIncluding path value
          nextCursor
          rest
      in
        doFork path cursor nextCursor
          root
          r.neighbor
    Just { head: Leaf r, tail: rest } ->
      let
        nextCursor = cursor + 1 + r.skip
        root = doIncluding path value
          nextCursor
          rest
        neighbor =
          { prefix: suffix r.key nextCursor
          , nibble:
              nibble r.key (nextCursor - 1)
          , root: r.value
          }
      in
        doFork path cursor nextCursor
          root
          neighbor

doBranch
  :: Uint8Array
  -> Int
  -> Int
  -> Uint8Array
  -> Uint8Array
  -> Uint8Array
doBranch path cursor nextCursor root neighbors =
  let
    branch = nibble path (nextCursor - 1)
    prefix = nibbles path cursor (nextCursor - 1)
  in
    combine prefix
      ( merkle16 branch root
          (sliceBytes 0 32 neighbors)
          (sliceBytes 32 32 neighbors)
          (sliceBytes 64 32 neighbors)
          (sliceBytes 96 32 neighbors)
      )

doFork
  :: Uint8Array
  -> Int
  -> Int
  -> Uint8Array
  -> Neighbor
  -> Uint8Array
doFork path cursor nextCursor root neighbor =
  let
    branch = nibble path (nextCursor - 1)
    prefix = nibbles path cursor (nextCursor - 1)
  in
    combine prefix
      ( sparseMerkle16 branch root
          neighbor.nibble
          (combine neighbor.prefix neighbor.root)
      )

-- | Byte-level equality check.
foreign import bytesEq
  :: Uint8Array -> Uint8Array -> Boolean
