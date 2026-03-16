-- | Sparse Merkle tree operations for MPF proofs.
-- Port of aiken/merkle-patricia-forestry/merkling.
module MPFS.Proof.MPF.Merkle
  ( nullHash
  , merkle16
  , sparseMerkle16
  ) where

import Prelude

import Data.ArrayBuffer.Types (Uint8Array)
import MPFS.Proof.MPF.Bytes (combine)

-- | 32-byte null hash (all zeros).
foreign import nullHash :: Uint8Array

-- Cached null hashes for sparse merkle
foreign import nullHash2 :: Uint8Array
foreign import nullHash4 :: Uint8Array
foreign import nullHash8 :: Uint8Array

-- | Reconstruct a 16-element merkle root given
-- the branch position, its hash, and 4 neighbor
-- hashes (each covering 8, 4, 2, 1 elements).
merkle16
  :: Int
  -> Uint8Array
  -> Uint8Array
  -> Uint8Array
  -> Uint8Array
  -> Uint8Array
  -> Uint8Array
merkle16 branch root n8 n4 n2 n1 =
  if branch <= 7 then
    combine (merkle8 branch root n4 n2 n1) n8
  else
    combine n8
      (merkle8 (branch - 8) root n4 n2 n1)

merkle8
  :: Int
  -> Uint8Array
  -> Uint8Array
  -> Uint8Array
  -> Uint8Array
  -> Uint8Array
merkle8 branch root n4 n2 n1 =
  if branch <= 3 then
    combine (merkle4 branch root n2 n1) n4
  else
    combine n4
      (merkle4 (branch - 4) root n2 n1)

merkle4
  :: Int
  -> Uint8Array
  -> Uint8Array
  -> Uint8Array
  -> Uint8Array
merkle4 branch root n2 n1 =
  if branch <= 1 then
    combine (merkle2 branch root n1) n2
  else
    combine n2
      (merkle2 (branch - 2) root n1)

merkle2
  :: Int -> Uint8Array -> Uint8Array -> Uint8Array
merkle2 branch root neighbor =
  if branch <= 0 then combine root neighbor
  else combine neighbor root

-- | Sparse 16-element merkle with only 2 occupied
-- slots (me and neighbor).
sparseMerkle16
  :: Int
  -> Uint8Array
  -> Int
  -> Uint8Array
  -> Uint8Array
sparseMerkle16 me meHash neighbor neighborHash =
  if me < 8 then
    if neighbor < 8 then
      combine
        ( sparseMerkle8 me meHash
            neighbor
            neighborHash
        )
        nullHash8
    else
      combine
        ( merkle8 me meHash nullHash4
            nullHash2
            nullHash
        )
        ( merkle8 (neighbor - 8) neighborHash
            nullHash4
            nullHash2
            nullHash
        )
  else if neighbor >= 8 then
    combine nullHash8
      ( sparseMerkle8 (me - 8) meHash
          (neighbor - 8)
          neighborHash
      )
  else
    combine
      ( merkle8 neighbor neighborHash
          nullHash4
          nullHash2
          nullHash
      )
      ( merkle8 (me - 8) meHash nullHash4
          nullHash2
          nullHash
      )

sparseMerkle8
  :: Int
  -> Uint8Array
  -> Int
  -> Uint8Array
  -> Uint8Array
sparseMerkle8 me meHash neighbor neighborHash =
  if me < 4 then
    if neighbor < 4 then
      combine
        ( sparseMerkle4 me meHash
            neighbor
            neighborHash
        )
        nullHash4
    else
      combine
        ( merkle4 me meHash nullHash2
            nullHash
        )
        ( merkle4 (neighbor - 4) neighborHash
            nullHash2
            nullHash
        )
  else if neighbor >= 4 then
    combine nullHash4
      ( sparseMerkle4 (me - 4) meHash
          (neighbor - 4)
          neighborHash
      )
  else
    combine
      ( merkle4 neighbor neighborHash
          nullHash2
          nullHash
      )
      ( merkle4 (me - 4) meHash nullHash2
          nullHash
      )

sparseMerkle4
  :: Int
  -> Uint8Array
  -> Int
  -> Uint8Array
  -> Uint8Array
sparseMerkle4 me meHash neighbor neighborHash =
  if me < 2 then
    if neighbor < 2 then
      combine
        (merkle2 me meHash neighborHash)
        nullHash2
    else
      combine
        (merkle2 me meHash nullHash)
        ( merkle2 (neighbor - 2) neighborHash
            nullHash
        )
  else if neighbor >= 2 then
    combine nullHash2
      (merkle2 (me - 2) meHash neighborHash)
  else
    combine
      (merkle2 neighbor neighborHash nullHash)
      (merkle2 (me - 2) meHash nullHash)
