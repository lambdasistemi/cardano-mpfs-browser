module MPFS.App.Pending
  ( PendingRowViewModel
  , RetractDecision(..)
  , opChipTone
  , opLabel
  , pendingRowViewModel
  , phaseChipTone
  , phaseDeadlineLabel
  , proofChipTone
  , proofLabel
  , retractDecision
  ) where

import Prelude

import Data.Int as Int
import Data.Maybe (Maybe(..), fromMaybe)
import Data.String.Common as String
import MPFS.App.Facts (RequestPhase(..), phaseLabel, requestPhase)
import MPFS.App.Verification (VerificationStatus(..))
import MPFS.Client.Types (PendingRequest, TokenState)
import MPFS.UI.Material.Chip (ChipTone(..))
import MPFS.UI.Material.Text (decodeHexUtf8)

data RetractDecision
  = RetractEnabled
  | RetractDisabled String

derive instance Eq RetractDecision

instance Show RetractDecision where
  show = case _ of
    RetractEnabled -> "RetractEnabled"
    RetractDisabled reason -> "(RetractDisabled " <> show reason <> ")"

type PendingRowViewModel =
  { requestId :: String
  , operation :: String
  , opLabel :: String
  , opTone :: ChipTone
  , key :: String
  , value :: Maybe String
  , keyDecoded :: String
  , valueDecoded :: Maybe String
  , keyValueSummary :: String
  , requester :: String
  , requesterIsWallet :: Boolean
  , ageLabel :: String
  , feeLabel :: String
  , phase :: RequestPhase
  , phaseLabel :: String
  , phaseTone :: ChipTone
  , deadlineLabel :: String
  , proofLabel :: String
  , proofTone :: ChipTone
  , retractDecision :: RetractDecision
  }

pendingRowViewModel
  :: Number
  -> TokenState
  -> VerificationStatus
  -> Boolean
  -> Maybe String
  -> PendingRequest
  -> PendingRowViewModel
pendingRowViewModel nowMillis tokenState proofStatus requesterIsWallet connectedWallet request =
  { requestId: request.request_id
  , operation: normalizedOperation
  , opLabel: opLabel request.operation
  , opTone: opChipTone request.operation
  , key: request.key
  , value: request.value
  , keyDecoded
  , valueDecoded
  , keyValueSummary
  , requester: request.owner
  , requesterIsWallet
  , ageLabel: durationLabel age <> " ago"
  , feeLabel: show request.fee <> " lovelace"
  , phase
  , phaseLabel: titleCasePhase phase
  , phaseTone: phaseChipTone phase
  , deadlineLabel: phaseDeadlineLabel age tokenState phase
  , proofLabel: proofLabel proofStatus
  , proofTone: proofChipTone proofStatus
  , retractDecision: retractDecision phase request.owner connectedWallet
  }
  where
  phase = requestPhase nowMillis tokenState request

  age = max 0.0 (nowMillis - request.submitted_at)

  normalizedOperation = String.toLower request.operation

  keyDecoded = fromMaybe request.key (decodeHexUtf8 request.key)

  valueDecoded = decodeHexUtf8 =<< request.value

  keyValueSummary = case valueDecoded, request.value of
    Just value, _ -> keyDecoded <> " -> " <> value
    Nothing, Just raw -> keyDecoded <> " -> " <> raw
    Nothing, Nothing -> keyDecoded

opLabel :: String -> String
opLabel operation = case String.toLower operation of
  "insert" -> "INSERT"
  "update" -> "UPDATE"
  "delete" -> "DELETE"
  other -> String.toUpper other

opChipTone :: String -> ChipTone
opChipTone operation = case String.toLower operation of
  "insert" -> ChipSuccess
  "update" -> ChipPrimary
  "delete" -> ChipError
  _ -> ChipNeutral

phaseChipTone :: RequestPhase -> ChipTone
phaseChipTone = case _ of
  PhaseProcessable -> ChipPrimary
  PhaseRetractable -> ChipWarning
  PhaseExpired -> ChipNeutral

proofChipTone :: VerificationStatus -> ChipTone
proofChipTone = case _ of
  VerificationVerified -> ChipSuccess
  VerificationLoading -> ChipWarning
  VerificationFailed _ -> ChipError
  VerificationNotAsked -> ChipNeutral

proofLabel :: VerificationStatus -> String
proofLabel = case _ of
  VerificationVerified -> "Verified"
  VerificationLoading -> "Pending"
  VerificationFailed _ -> "Rejected"
  VerificationNotAsked -> "Not checked"

retractDecision :: RequestPhase -> String -> Maybe String -> RetractDecision
retractDecision phase requester connectedWallet = case connectedWallet of
  Nothing ->
    RetractDisabled "Connect a wallet to retract"
  Just wallet
    | wallet /= requester ->
        RetractDisabled "Only the requester may retract"
    | otherwise ->
        case phase of
          PhaseRetractable -> RetractEnabled
          PhaseProcessable -> RetractDisabled "Retract opens after the process window"
          PhaseExpired -> RetractDisabled "Retract window has closed"

phaseDeadlineLabel :: Number -> TokenState -> RequestPhase -> String
phaseDeadlineLabel age tokenState = case _ of
  PhaseProcessable ->
    "Retract opens in " <> durationLabel (tokenState.process_time - age)
  PhaseRetractable ->
    "Retract closes in " <> durationLabel (tokenState.process_time + tokenState.retract_time - age)
  PhaseExpired ->
    "Retract window closed"

titleCasePhase :: RequestPhase -> String
titleCasePhase phase = case phaseLabel phase of
  "processable" -> "Processable"
  "retractable" -> "Retractable"
  "expired" -> "Expired"
  label -> label

durationLabel :: Number -> String
durationLabel millis =
  if millis <= 0.0 then
    "now"
  else if minutes < 1 then
    "less than 1m"
  else if minutes < 60 then
    show minutes <> "m"
  else if hours < 24 then
    show hours <> "h" <> minuteRemainder
  else
    show days <> "d"
  where
  minutes = Int.floor (millis / 60000.0)

  hours = minutes `div` 60

  days = hours `div` 24

  remainingMinutes = minutes `mod` 60

  minuteRemainder =
    if remainingMinutes == 0 then
      ""
    else
      " " <> show remainingMinutes <> "m"
