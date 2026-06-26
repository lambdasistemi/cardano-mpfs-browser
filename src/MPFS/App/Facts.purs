module MPFS.App.Facts
  ( RequestPhase(..)
  , failFactLookup
  , failFactsLoad
  , finishFactLookup
  , finishFactsLoad
  , finishFactsLoadAt
  , finishFactsLoadWithRootAt
  , phaseLabel
  , requestPhase
  , setFactLookupKey
  , setFactProofEnvelope
  , startFactLookup
  , startFactsLoad
  ) where

import Prelude

import MPFS.App.State (AppState)
import MPFS.App.Verification (VerificationStatus(..))
import MPFS.Client.Types (FactEntry, PendingRequest, TokenState)
import MPFS.Types (TrustedRoot)
import MPFS.UI.Remote (Remote(..))

data RequestPhase
  = PhaseProcessable
  | PhaseRetractable
  | PhaseExpired

derive instance Eq RequestPhase

instance Show RequestPhase where
  show = case _ of
    PhaseProcessable -> "PhaseProcessable"
    PhaseRetractable -> "PhaseRetractable"
    PhaseExpired -> "PhaseExpired"

startFactsLoad :: AppState -> AppState
startFactsLoad state =
  state
    { facts = Loading
    , tokenState = Loading
    , pendingRequests = Loading
    , trustedRoot = Loading
    }

finishFactsLoad
  :: TokenState
  -> Array PendingRequest
  -> Array FactEntry
  -> AppState
  -> AppState
finishFactsLoad =
  finishFactsLoadAt 0.0

finishFactsLoadAt
  :: Number
  -> TokenState
  -> Array PendingRequest
  -> Array FactEntry
  -> AppState
  -> AppState
finishFactsLoadAt nowMillis tokenState requests facts state =
  state
    { tokenState = Success tokenState
    , pendingRequests = Success requests
    , facts = Success facts
    , requestNowMillis = nowMillis
    }

finishFactsLoadWithRootAt
  :: Number
  -> TokenState
  -> Array PendingRequest
  -> Array FactEntry
  -> TrustedRoot
  -> AppState
  -> AppState
finishFactsLoadWithRootAt nowMillis tokenState requests facts trustedRoot state =
  (finishFactsLoadAt nowMillis tokenState requests facts state)
    { trustedRoot = Success trustedRoot }

failFactsLoad :: String -> AppState -> AppState
failFactsLoad message state =
  state
    { facts = Failure message
    , tokenState = Failure message
    , pendingRequests = Failure message
    , trustedRoot = Failure message
    }

requestPhase :: Number -> TokenState -> PendingRequest -> RequestPhase
requestPhase nowMillis tokenState request =
  let
    age = nowMillis - request.submitted_at
  in
    if age <= tokenState.process_time then
      PhaseProcessable
    else if age <= tokenState.process_time + tokenState.retract_time then
      PhaseRetractable
    else
      PhaseExpired

phaseLabel :: RequestPhase -> String
phaseLabel = case _ of
  PhaseProcessable -> "processable"
  PhaseRetractable -> "retractable"
  PhaseExpired -> "expired"

setFactLookupKey :: String -> AppState -> AppState
setFactLookupKey key state =
  state
    { factLookup =
        state.factLookup
          { key = key
          , value = NotAsked
          , verification = VerificationNotAsked
          }
    }

startFactLookup :: String -> AppState -> AppState
startFactLookup key state =
  state
    { factLookup =
        state.factLookup
          { key = key
          , value = Loading
          , verification = VerificationNotAsked
          }
    }

finishFactLookup :: String -> AppState -> AppState
finishFactLookup value state =
  state
    { factLookup =
        state.factLookup
          { value = Success value
          , verification = VerificationNotAsked
          }
    }

failFactLookup :: String -> AppState -> AppState
failFactLookup message state =
  state
    { factLookup =
        state.factLookup
          { value = Failure message
          , verification = VerificationNotAsked
          }
    }

setFactProofEnvelope :: String -> AppState -> AppState
setFactProofEnvelope envelope state =
  state
    { factLookup =
        state.factLookup
          { proofEnvelope = envelope
          , verification = VerificationNotAsked
          }
    }
