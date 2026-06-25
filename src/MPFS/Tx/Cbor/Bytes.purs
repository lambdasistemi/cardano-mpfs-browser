-- | Byte-level access to Uint8Array.
module MPFS.Tx.Cbor.Bytes
  ( unsafeIndex
  , slice
  , byteLength
  , bytesToHex
  , hexToBytes
  ) where

import Data.ArrayBuffer.Types (Uint8Array)

-- | Read a single byte at the given index.
foreign import unsafeIndex
  :: Uint8Array -> Int -> Int

-- | Slice [start, end) from the array.
foreign import slice
  :: Uint8Array -> Int -> Int -> Uint8Array

-- | Length of the array in bytes.
foreign import byteLength :: Uint8Array -> Int

-- | Encode bytes as hex string.
foreign import bytesToHex :: Uint8Array -> String

-- | Decode hex string to bytes.
foreign import hexToBytes :: String -> Uint8Array
