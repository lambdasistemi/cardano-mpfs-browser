-- | Verdict logic for cross-checking MPFS token state against csmt-utxo.
module MPFS.SecondOracle
  ( SecondOracleDeps
  , VerdictFixtureInput
  , checkOutputRef
  , extractAttestedFactsRoot
  , verdictFromFixture
  ) where

import Prelude

import Data.Array (find, index)
import Data.Either (Either(..))
import Data.Maybe (Maybe(..))
import Effect.Aff (Aff)
import MPFS.SecondOracle.Client as OracleClient
import MPFS.SecondOracle.Types
  ( AttestedTxOut
  , ChainPoint
  , Hex
  , MerkleRoot
  , MerkleRootEntry
  , OutputRef
  , ProofCbor
  , ProofResponse
  , SecondOracleUnavailable(..)
  , SecondOracleVerdict(..)
  )
import MPFS.Tx.Cbor (TxDatum(..), decodeTxOutput)
import MPFS.Tx.Cbor.Bytes (hexToBytes)
import MPFS.Tx.PlutusData (PlutusData(..))

type SecondOracleDeps =
  { getMerkleRoots ::
      Aff (Either OracleClient.ClientError (Array MerkleRootEntry))
  , getProof ::
      OutputRef -> Aff (Either OracleClient.ClientError ProofResponse)
  , verifyInclusion :: MerkleRoot -> ProofCbor -> Aff Boolean
  }

type VerdictFixtureInput =
  { expectedFactsRoot :: Hex
  , merkleRoots :: Array MerkleRootEntry
  , proofResponse :: ProofResponse
  , inclusionVerified :: Boolean
  }

checkOutputRef
  :: SecondOracleDeps
  -> OutputRef
  -> Hex
  -> Aff SecondOracleVerdict
checkOutputRef deps outputRef expectedFactsRoot = do
  eProof <- deps.getProof outputRef
  case eProof of
    Left err ->
      pure $ SecondOracleUnavailable (ProofUnavailable (show err))
    Right proofResponse -> do
      eMerkleRoots <- deps.getMerkleRoots
      case eMerkleRoots of
        Left err ->
          pure $ SecondOracleUnavailable (MerkleRootsUnavailable (show err))
        Right merkleRoots ->
          case findMatchingRoot proofResponse merkleRoots of
            Nothing ->
              pure $ SecondOracleMissingRoot (proofChainPoint proofResponse)
            Just merkleRootEntry -> do
              inclusionVerified <- deps.verifyInclusion
                merkleRootEntry.merkleRoot
                proofResponse.proof
              pure $ verdictWithRoot
                expectedFactsRoot
                merkleRootEntry
                proofResponse
                inclusionVerified

verdictFromFixture :: VerdictFixtureInput -> SecondOracleVerdict
verdictFromFixture input =
  case findMatchingRoot input.proofResponse input.merkleRoots of
    Nothing ->
      SecondOracleMissingRoot (proofChainPoint input.proofResponse)
    Just merkleRootEntry ->
      verdictWithRoot
        input.expectedFactsRoot
        merkleRootEntry
        input.proofResponse
        input.inclusionVerified

extractAttestedFactsRoot :: AttestedTxOut -> Maybe Hex
extractAttestedFactsRoot txOutHex =
  case (decodeTxOutput (hexToBytes txOutHex)).datum of
    InlineDatum datum ->
      extractFactsRoot datum
    _ ->
      Nothing

verdictWithRoot
  :: Hex
  -> MerkleRootEntry
  -> ProofResponse
  -> Boolean
  -> SecondOracleVerdict
verdictWithRoot expectedFactsRoot merkleRootEntry proofResponse inclusionVerified =
  let
    chainPoint = proofChainPoint proofResponse
    merkleRoot = merkleRootEntry.merkleRoot
  in
    case extractAttestedFactsRoot proofResponse.txOut of
      Nothing ->
        SecondOracleMalformedDatum
          "attested txOut does not contain an MPFS state datum"
      Just attestedFactsRoot ->
        if inclusionVerified && attestedFactsRoot == expectedFactsRoot then
          SecondOracleVerified
            { chainPoint
            , merkleRoot
            , factsRoot: expectedFactsRoot
            }
        else
          SecondOracleMismatch
            { chainPoint
            , merkleRoot
            , expectedFactsRoot
            , attestedFactsRoot
            }

findMatchingRoot
  :: ProofResponse -> Array MerkleRootEntry -> Maybe MerkleRootEntry
findMatchingRoot proofResponse =
  find \entry ->
    entry.slotNo == proofResponse.slotNo
      && entry.blockHash == proofResponse.blockHash

proofChainPoint :: ProofResponse -> ChainPoint
proofChainPoint proofResponse =
  { slotNo: proofResponse.slotNo
  , blockHash: proofResponse.blockHash
  }

extractFactsRoot :: PlutusData -> Maybe Hex
extractFactsRoot (Constr 1 fields) =
  index fields 0 >>= extractStateRoot
extractFactsRoot datum =
  extractStateRoot datum

extractStateRoot :: PlutusData -> Maybe Hex
extractStateRoot (Constr 0 fields) =
  index fields 1 >>= asBytes
extractStateRoot _ =
  Nothing

asBytes :: PlutusData -> Maybe Hex
asBytes (PBytes bytes) =
  Just bytes
asBytes _ =
  Nothing
