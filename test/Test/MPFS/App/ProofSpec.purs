module Test.MPFS.App.ProofSpec (spec) where

import Prelude

import Data.Maybe (Maybe(..))
import MPFS.App.Proof
  ( ProofCheckKind(..)
  , proofCheckRow
  )
import MPFS.App.Verification (VerificationStatus(..))
import Test.Spec (Spec, describe, it)
import Test.Spec.Assertions (shouldEqual)

spec :: Spec Unit
spec = describe "MPFS App Proof" do
  it "maps verification checks to design verdict rows" do
    let
      row =
        proofCheckRow
          { kind: CheckSecondOracle
          , status: VerificationFailed "root mismatch"
          , checkedCount: 2
          , totalCount: 3
          }

    row.name `shouldEqual` "Second-oracle agreement"
    row.badgeLabel `shouldEqual` "FAIL"
    row.tone `shouldEqual` "reject"
    row.verifierOp `shouldEqual` "verify_snapshot"
    row.reason `shouldEqual` Just "root mismatch"

  it "uses the facts-set verifier operation and count detail" do
    let
      row =
        proofCheckRow
          { kind: CheckFactsSet
          , status: VerificationVerified
          , checkedCount: 5
          , totalCount: 5
          }

    row.name `shouldEqual` "Facts-set completeness"
    row.badgeLabel `shouldEqual` "PASS"
    row.tone `shouldEqual` "pass"
    row.verifierOp `shouldEqual` "verify_facts"
    row.detail `shouldEqual` "All 5 committed facts are present in the snapshot."

  it "uses the per-fact inclusion verifier operation" do
    let
      row =
        proofCheckRow
          { kind: CheckPerFactInclusion
          , status: VerificationVerified
          , checkedCount: 5
          , totalCount: 5
          }

    row.name `shouldEqual` "Per-fact inclusion proofs"
    row.badgeLabel `shouldEqual` "PASS"
    row.tone `shouldEqual` "pass"
    row.verifierOp `shouldEqual` "verify_fact_inclusion"
    row.detail `shouldEqual` "5/5 Merkle-Patricia inclusion proofs re-computed locally."
