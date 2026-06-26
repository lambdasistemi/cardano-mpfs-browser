-- | The cage transaction-builder boundary.
module MPFS.Cage
  ( CageHelpers
  , CageResult
  ) where

import Data.Either (Either)
import Effect.Aff (Aff)
import MPFS.Types
  ( CageConfig
  , CageError
  , Key
  , RequestId
  , TokenId
  , UnsignedTxCbor
  , Value
  , WalletAddr
  )

type CageResult = Aff (Either CageError UnsignedTxCbor)

type CageHelpers =
  { registerToken :: WalletAddr -> CageConfig -> CageResult
  , insertFact :: WalletAddr -> CageConfig -> TokenId -> Key -> Value -> CageResult
  , updateFact ::
      WalletAddr -> CageConfig -> TokenId -> Key -> Value -> Value -> CageResult
  , deleteFact :: WalletAddr -> CageConfig -> TokenId -> Key -> Value -> CageResult
  , retractRequest :: WalletAddr -> CageConfig -> TokenId -> RequestId -> CageResult
  , rejectExpired :: WalletAddr -> CageConfig -> TokenId -> Array RequestId -> CageResult
  , endCage :: WalletAddr -> CageConfig -> TokenId -> CageResult
  , updateToken :: WalletAddr -> CageConfig -> TokenId -> Array RequestId -> CageResult
  }
