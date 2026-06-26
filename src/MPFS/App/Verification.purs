module MPFS.App.Verification
  ( VerificationStatus(..)
  , finishVerification
  , startVerification
  , verifyFactEnvelope
  ) where

import Prelude

import Data.Either (Either(..))
import Effect.Aff (Aff)
import MPFS.Reactor as Reactor

data VerificationStatus
  = VerificationNotAsked
  | VerificationLoading
  | VerificationVerified
  | VerificationFailed String

derive instance Eq VerificationStatus

instance Show VerificationStatus where
  show = case _ of
    VerificationNotAsked -> "VerificationNotAsked"
    VerificationLoading -> "VerificationLoading"
    VerificationVerified -> "VerificationVerified"
    VerificationFailed message -> "(VerificationFailed " <> show message <> ")"

startVerification
  :: forall stateRest lookupRest
   . { factLookup :: { verification :: VerificationStatus | lookupRest }
     | stateRest
     }
  -> { factLookup :: { verification :: VerificationStatus | lookupRest }
     | stateRest
     }
startVerification state =
  state
    { factLookup =
        state.factLookup
          { verification = VerificationLoading }
    }

finishVerification
  :: forall stateRest lookupRest
   . Either String Unit
  -> { factLookup :: { verification :: VerificationStatus | lookupRest }
     | stateRest
     }
  -> { factLookup :: { verification :: VerificationStatus | lookupRest }
     | stateRest
     }
finishVerification result state =
  state
    { factLookup =
        state.factLookup
          { verification = status }
    }
  where
  status = case result of
    Right _ -> VerificationVerified
    Left message -> VerificationFailed message

verifyFactEnvelope :: String -> Aff (Either String Unit)
verifyFactEnvelope =
  Reactor.verifyEnvelope
