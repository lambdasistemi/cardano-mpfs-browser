module MPFS.App.Verification
  ( VerificationStatus(..)
  , anchorFactSnapshotRoot
  , anchorTokenSnapshotRoot
  , buildFactInclusionEnvelope
  , buildTokensVerificationEnvelope
  , finishVerification
  , startVerification
  , verifyFactEnvelope
  , verifyFactInclusion
  , verifyTokenList
  ) where

import Prelude

import Data.Array as Array
import Data.Argonaut.Core (Json, fromNumber, fromObject, fromString, stringify)
import Data.Either (Either(..))
import Data.Int (toNumber)
import Data.Maybe (Maybe(..))
import Data.Tuple (Tuple(..))
import Effect.Aff (Aff)
import Foreign.Object as Object
import MPFS.Client (RawFactResponse, RawTokensResponse)
import MPFS.Reactor as Reactor
import MPFS.SecondOracle.Types (MerkleRootEntry)
import MPFS.Types (CageConfig)

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

anchorTokenSnapshotRoot
  :: Array MerkleRootEntry
  -> RawTokensResponse
  -> Either String String
anchorTokenSnapshotRoot roots tokens =
  case Array.find matchesSlot roots of
    Nothing ->
      Left
        ( "Token list snapshot slot "
            <> show slot
            <> " is not anchored by the second oracle"
        )
    Just root
      | root.merkleRoot == tokens.snapshot.utxo_root ->
          Right root.merkleRoot
      | otherwise ->
          Left "Token list snapshot UTxO root is not anchored by the second oracle"
  where
  slot = tokens.snapshot.chainpoint.slot

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

buildTokensVerificationEnvelope :: String -> Json -> CageConfig -> String
buildTokensVerificationEnvelope trustedRoot facts cfg =
  stringify
    ( fromObject
        ( Object.fromFoldable
            [ Tuple "op" (fromString "verify_tokens")
            , Tuple "trusted_root" (fromString trustedRoot)
            , Tuple "facts" facts
            , Tuple "cage_config" (cageConfigJson cfg)
            ]
        )
    )

verifyTokenList :: String -> Json -> CageConfig -> Aff (Either String Unit)
verifyTokenList trustedRoot facts cfg =
  verifyFactEnvelope (buildTokensVerificationEnvelope trustedRoot facts cfg)

cageConfigJson :: CageConfig -> Json
cageConfigJson cfg =
  fromObject
    ( Object.fromFoldable
        [ Tuple "cage_script_bytes" (fromString cfg.cageScriptBytes)
        , Tuple "request_script_bytes" (fromString cfg.requestScriptBytes)
        , Tuple "default_process_time" (intJson cfg.defaultProcessTime)
        , Tuple "default_retract_time" (intJson cfg.defaultRetractTime)
        , Tuple "default_tip" (intJson cfg.defaultTip)
        , Tuple "network" (fromString (reactorNetworkName cfg.network))
        ]
    )

intJson :: Int -> Json
intJson = fromNumber <<< toNumber

reactorNetworkName :: String -> String
reactorNetworkName = case _ of
  "preprod" -> "testnet"
  network -> network
