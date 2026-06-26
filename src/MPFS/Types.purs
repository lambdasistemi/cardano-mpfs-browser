-- | Shared MPFS domain types used by the browser logic boundary.
module MPFS.Types
  ( WalletAddr(..)
  , TokenId(..)
  , Key(..)
  , Value(..)
  , RequestId(..)
  , UnsignedTxCbor(..)
  , TrustedRoot(..)
  , CageConfig
  , CageError(..)
  , cageErrorMessage
  ) where

import Prelude

-- | A wallet payment address as surfaced by CIP-30.
newtype WalletAddr = WalletAddr String

derive instance Eq WalletAddr
derive newtype instance Show WalletAddr

-- | An MPFS token identifier.
newtype TokenId = TokenId String

derive instance Eq TokenId
derive newtype instance Show TokenId

-- | A fact key.
newtype Key = Key String

derive instance Eq Key
derive newtype instance Show Key

-- | A fact value.
newtype Value = Value String

derive instance Eq Value
derive newtype instance Show Value

-- | A pending request identifier (`txid#ix`).
newtype RequestId = RequestId String

derive instance Eq RequestId
derive newtype instance Show RequestId

-- | A hex-encoded unsigned transaction CBOR value.
newtype UnsignedTxCbor = UnsignedTxCbor String

derive instance Eq UnsignedTxCbor
derive newtype instance Show UnsignedTxCbor

-- | A hex-encoded trusted MPFS root.
newtype TrustedRoot = TrustedRoot String

derive instance Eq TrustedRoot
derive newtype instance Show TrustedRoot

-- | Client-side cage transaction configuration.
type CageConfig =
  { cageScriptBytes :: String
  , requestScriptBytes :: String
  , cfgScriptHash :: String
  , defaultProcessTime :: Int
  , defaultRetractTime :: Int
  , defaultTip :: Int
  , network :: String
  }

-- | An error returned by the cage reactor boundary.
newtype CageError = CageError String

derive instance Eq CageError
derive newtype instance Show CageError

cageErrorMessage :: CageError -> String
cageErrorMessage (CageError msg) = msg
