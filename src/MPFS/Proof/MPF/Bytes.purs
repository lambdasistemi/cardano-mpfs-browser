-- | Byte array helpers for MPF proof verification.
-- Mirrors the Aiken helpers module.
module MPFS.Proof.MPF.Bytes
  ( combine
  , suffix
  , nibble
  , nibbles
  , sliceBytes
  , concatBytes
  , pushByte
  , dropBytes
  , emptyBytes
  , lengthBytes
  , getByte
  ) where

import Data.ArrayBuffer.Types (Uint8Array)

-- | combine(a, b) = blake2b_256(a ++ b)
foreign import combine
  :: Uint8Array -> Uint8Array -> Uint8Array

-- | Extract hex nibble at position i from path.
-- Even index: high nibble, odd index: low nibble.
foreign import nibble :: Uint8Array -> Int -> Int

-- | Extract nibbles from path between start
-- (inclusive) and end (exclusive) as bytes.
foreign import nibbles
  :: Uint8Array -> Int -> Int -> Uint8Array

-- | Encode the suffix of a path from cursor
-- position, with hashHead prefix byte.
foreign import suffix
  :: Uint8Array -> Int -> Uint8Array

-- | Slice length bytes starting at offset.
foreign import sliceBytes
  :: Int -> Int -> Uint8Array -> Uint8Array

-- | Concatenate two byte arrays.
foreign import concatBytes
  :: Uint8Array -> Uint8Array -> Uint8Array

-- | Prepend a byte to an array.
foreign import pushByte
  :: Int -> Uint8Array -> Uint8Array

-- | Drop n bytes from the start.
foreign import dropBytes
  :: Int -> Uint8Array -> Uint8Array

-- | Empty byte array.
foreign import emptyBytes :: Uint8Array

-- | Length of a byte array.
foreign import lengthBytes :: Uint8Array -> Int

-- | Get byte at index.
foreign import getByte :: Uint8Array -> Int -> Int
