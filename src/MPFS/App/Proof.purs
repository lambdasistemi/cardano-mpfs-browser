module MPFS.App.Proof
  ( ProofCheckKind(..)
  , ProofCheckRow
  , proofCheckRow
  , proofCheckVerifierOp
  , proofStatusBadge
  , proofStatusReason
  , proofStatusTone
  ) where

import Prelude

import Data.Maybe (Maybe(..))
import MPFS.App.Verification (VerificationStatus(..))

data ProofCheckKind
  = CheckSecondOracle
  | CheckFactsSet
  | CheckPerFactInclusion

derive instance Eq ProofCheckKind

type ProofCheckRow =
  { name :: String
  , detail :: String
  , badgeLabel :: String
  , tone :: String
  , verifierOp :: String
  , reason :: Maybe String
  }

proofCheckRow
  :: { kind :: ProofCheckKind
     , status :: VerificationStatus
     , checkedCount :: Int
     , totalCount :: Int
     }
  -> ProofCheckRow
proofCheckRow input =
  { name: proofCheckName input.kind
  , detail: proofCheckDetail input.kind input.checkedCount input.totalCount
  , badgeLabel: proofStatusBadge input.status
  , tone: proofStatusTone input.status
  , verifierOp: proofCheckVerifierOp input.kind
  , reason: proofStatusReason input.status
  }

proofCheckName :: ProofCheckKind -> String
proofCheckName = case _ of
  CheckSecondOracle -> "Second-oracle agreement"
  CheckFactsSet -> "Facts-set completeness"
  CheckPerFactInclusion -> "Per-fact inclusion proofs"

proofCheckDetail :: ProofCheckKind -> Int -> Int -> String
proofCheckDetail kind checkedCount totalCount = case kind of
  CheckSecondOracle ->
    "State root reproduced by an independent oracle and matched byte-for-byte."
  CheckFactsSet ->
    "All " <> show totalCount <> " committed facts are present in the snapshot."
  CheckPerFactInclusion ->
    show checkedCount
      <> "/"
      <> show totalCount
      <> " Merkle-Patricia inclusion proofs re-computed locally."

proofCheckVerifierOp :: ProofCheckKind -> String
proofCheckVerifierOp = case _ of
  CheckSecondOracle -> "verify_snapshot"
  CheckFactsSet -> "verify_facts"
  CheckPerFactInclusion -> "verify_fact_inclusion"

proofStatusBadge :: VerificationStatus -> String
proofStatusBadge = case _ of
  VerificationVerified -> "PASS"
  VerificationFailed _ -> "FAIL"
  VerificationLoading -> "PENDING"
  VerificationNotAsked -> "PENDING"

proofStatusTone :: VerificationStatus -> String
proofStatusTone = case _ of
  VerificationVerified -> "pass"
  VerificationFailed _ -> "reject"
  VerificationLoading -> "pending"
  VerificationNotAsked -> "pending"

proofStatusReason :: VerificationStatus -> Maybe String
proofStatusReason = case _ of
  VerificationFailed message -> Just message
  _ -> Nothing
