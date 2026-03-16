-- | Blake2b-256 hashing and hex encoding via
-- @noble/hashes. These are the cryptographic
-- primitives used throughout the MPFS verification
-- chain.
module MPFS.Crypto.Hash
  ( blake2b256
  , bytesToHex
  , hexToBytes
  ) where

import Data.ArrayBuffer.Types (Uint8Array)

-- | Blake2b-256 hash (32-byte digest).
foreign import blake2b256Impl :: Uint8Array -> Uint8Array

-- | Encode bytes as hex string.
foreign import bytesToHexImpl :: Uint8Array -> String

-- | Decode hex string to bytes.
foreign import hexToBytesImpl :: String -> Uint8Array

-- | Hash a byte array with Blake2b-256.
blake2b256 :: Uint8Array -> Uint8Array
blake2b256 = blake2b256Impl

-- | Encode a byte array as a hex string.
bytesToHex :: Uint8Array -> String
bytesToHex = bytesToHexImpl

-- | Decode a hex string to a byte array.
hexToBytes :: String -> Uint8Array
hexToBytes = hexToBytesImpl
