module MPFS.App.Write
  ( RefreshTarget(..)
  , WriteForms
  , WriteOperation(..)
  , WriteStatus(..)
  , failWrite
  , initialWriteForms
  , operationNeedsSelectedToken
  , refreshPlanAfterSubmit
  , requestIdOf
  , setDeleteValue
  , setDeleteKey
  , setInsertKey
  , setInsertValue
  , setUpdateKey
  , setUpdateNewValue
  , setUpdateOldValue
  , submittedWrite
  , toggleRequestSelection
  , validatePrerequisites
  ) where

import Prelude

import Data.Array as Array
import Data.Either (Either(..))
import Data.Maybe (Maybe(..))
import MPFS.Client.Types (PendingRequest)
import MPFS.Types (RequestId(..), TokenId, UnsignedTxCbor)

data WriteStatus
  = WriteIdle
  | WriteBuilding
  | WriteBuilt UnsignedTxCbor
  | WriteSigning UnsignedTxCbor
  | WriteAssembling UnsignedTxCbor String
  | WriteSubmitting UnsignedTxCbor String String
  | WriteSubmitted UnsignedTxCbor String String String
  | WriteFailed String

derive instance Eq WriteStatus

instance Show WriteStatus where
  show = case _ of
    WriteIdle -> "WriteIdle"
    WriteBuilding -> "WriteBuilding"
    WriteBuilt unsigned -> "WriteBuilt " <> show unsigned
    WriteSigning unsigned -> "WriteSigning " <> show unsigned
    WriteAssembling unsigned witness ->
      "WriteAssembling " <> show unsigned <> " " <> witness
    WriteSubmitting unsigned witness signed ->
      "WriteSubmitting " <> show unsigned <> " " <> witness <> " " <> signed
    WriteSubmitted unsigned witness signed txId ->
      "WriteSubmitted "
        <> show unsigned
        <> " "
        <> witness
        <> " "
        <> signed
        <> " "
        <> txId
    WriteFailed message -> "WriteFailed " <> message

type WriteForms =
  { insertKey :: String
  , insertValue :: String
  , updateKey :: String
  , updateOldValue :: String
  , updateNewValue :: String
  , deleteKey :: String
  , deleteValue :: String
  }

data WriteOperation
  = WriteRegisterToken
  | WriteInsertFact
  | WriteUpdateFact
  | WriteDeleteFact
  | WriteRetractRequest
  | WriteRejectExpired
  | WriteUpdateToken
  | WriteEndCage

derive instance Eq WriteOperation

instance Show WriteOperation where
  show = case _ of
    WriteRegisterToken -> "WriteRegisterToken"
    WriteInsertFact -> "WriteInsertFact"
    WriteUpdateFact -> "WriteUpdateFact"
    WriteDeleteFact -> "WriteDeleteFact"
    WriteRetractRequest -> "WriteRetractRequest"
    WriteRejectExpired -> "WriteRejectExpired"
    WriteUpdateToken -> "WriteUpdateToken"
    WriteEndCage -> "WriteEndCage"

data RefreshTarget
  = RefreshTokens
  | RefreshTokenFacts TokenId
  | RefreshTokenState TokenId
  | RefreshPendingRequests TokenId

derive instance Eq RefreshTarget

instance Show RefreshTarget where
  show = case _ of
    RefreshTokens -> "RefreshTokens"
    RefreshTokenFacts token -> "RefreshTokenFacts " <> show token
    RefreshTokenState token -> "RefreshTokenState " <> show token
    RefreshPendingRequests token -> "RefreshPendingRequests " <> show token

initialWriteForms :: WriteForms
initialWriteForms =
  { insertKey: ""
  , insertValue: ""
  , updateKey: ""
  , updateOldValue: ""
  , updateNewValue: ""
  , deleteKey: ""
  , deleteValue: ""
  }

submittedWrite :: UnsignedTxCbor -> String -> String -> String -> WriteStatus
submittedWrite = WriteSubmitted

failWrite :: forall r. String -> { writeStatus :: WriteStatus | r } -> { writeStatus :: WriteStatus | r }
failWrite message state = state { writeStatus = WriteFailed message }

validatePrerequisites
  :: forall r wr
   . WriteOperation
  -> { selectedToken :: Maybe TokenId
     , walletSession :: { selectedAddress :: Maybe String | wr }
     | r
     }
  -> Either String Unit
validatePrerequisites operation state
  | state.walletSession.selectedAddress == Nothing =
      Left "Connect a wallet first."
  | operationNeedsSelectedToken operation && state.selectedToken == Nothing =
      Left "Select a token first."
  | otherwise =
      Right unit

operationNeedsSelectedToken :: WriteOperation -> Boolean
operationNeedsSelectedToken = case _ of
  WriteRegisterToken -> false
  _ -> true

refreshPlanAfterSubmit :: Maybe TokenId -> Array RefreshTarget
refreshPlanAfterSubmit = case _ of
  Nothing -> [ RefreshTokens ]
  Just token ->
    [ RefreshTokens
    , RefreshTokenFacts token
    , RefreshTokenState token
    , RefreshPendingRequests token
    ]

requestIdOf :: PendingRequest -> Maybe RequestId
requestIdOf request =
  if request.request_id == "" then Nothing
  else Just (RequestId request.request_id)

toggleRequestSelection
  :: forall r
   . RequestId
  -> { selectedRequestIds :: Array RequestId | r }
  -> { selectedRequestIds :: Array RequestId | r }
toggleRequestSelection requestId state =
  state
    { selectedRequestIds =
        if Array.elem requestId state.selectedRequestIds then
          Array.filter (_ /= requestId) state.selectedRequestIds
        else
          state.selectedRequestIds <> [ requestId ]
    }

setInsertKey
  :: forall r. String -> { writeForms :: WriteForms | r } -> { writeForms :: WriteForms | r }
setInsertKey value = updateForms \forms -> forms { insertKey = value }

setInsertValue
  :: forall r. String -> { writeForms :: WriteForms | r } -> { writeForms :: WriteForms | r }
setInsertValue value = updateForms \forms -> forms { insertValue = value }

setUpdateKey
  :: forall r. String -> { writeForms :: WriteForms | r } -> { writeForms :: WriteForms | r }
setUpdateKey value = updateForms \forms -> forms { updateKey = value }

setUpdateOldValue
  :: forall r. String -> { writeForms :: WriteForms | r } -> { writeForms :: WriteForms | r }
setUpdateOldValue value = updateForms \forms -> forms { updateOldValue = value }

setUpdateNewValue
  :: forall r. String -> { writeForms :: WriteForms | r } -> { writeForms :: WriteForms | r }
setUpdateNewValue value = updateForms \forms -> forms { updateNewValue = value }

setDeleteKey
  :: forall r. String -> { writeForms :: WriteForms | r } -> { writeForms :: WriteForms | r }
setDeleteKey value = updateForms \forms -> forms { deleteKey = value }

setDeleteValue
  :: forall r. String -> { writeForms :: WriteForms | r } -> { writeForms :: WriteForms | r }
setDeleteValue value = updateForms \forms -> forms { deleteValue = value }

updateForms
  :: forall r
   . (WriteForms -> WriteForms)
  -> { writeForms :: WriteForms | r }
  -> { writeForms :: WriteForms | r }
updateForms f state = state { writeForms = f state.writeForms }
