module MPFS.App.Verification
  ( VerificationStatus(..)
  , anchorFactSnapshotRoot
  , buildFactInclusionEnvelope
  , finishVerification
  , startVerification
  , verifyFactEnvelope
  , verifyFactInclusion
  ) where

import Prelude

import Data.Array as Array
import Data.Argonaut.Core (Json, fromObject, fromString, stringify)
import Data.Either (Either(..))
import Data.Maybe (Maybe(..))
import Data.Tuple (Tuple(..))
import Effect.Aff (Aff)
import Foreign.Object as Object
import MPFS.Client (RawFactResponse)
import MPFS.Reactor as Reactor
import MPFS.SecondOracle.Types (MerkleRootEntry)

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

anchorFactSnapshotRoot
  :: Array MerkleRootEntry
  -> RawFactResponse
  -> Either String String
anchorFactSnapshotRoot roots fact =
  case Array.find matchesSlot roots of
    Nothing ->
      Left
        ( "Fact snapshot slot "
            <> show slot
            <> " is not anchored by the second oracle"
        )
    Just root
      | root.merkleRoot == fact.snapshot.utxo_root ->
          Right root.merkleRoot
      | otherwise ->
          Left "Fact snapshot UTxO root is not anchored by the second oracle"
  where
  slot = fact.snapshot.chainpoint.slot

  matchesSlot root =
    root.slotNo == slot

buildFactInclusionEnvelope :: String -> Json -> String -> String
buildFactInclusionEnvelope trustedRoot facts key =
  stringify
    ( fromObject
        ( Object.fromFoldable
            [ Tuple "op" (fromString "verify_fact_inclusion")
            , Tuple "trusted_root" (fromString trustedRoot)
            , Tuple "facts" facts
            , Tuple "key" (fromString key)
            ]
        )
    )

verifyFactInclusion :: String -> Json -> String -> Aff (Either String Unit)
verifyFactInclusion trustedRoot facts key =
  verifyFactEnvelope (buildFactInclusionEnvelope trustedRoot facts key)
