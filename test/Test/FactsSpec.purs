module Test.FactsSpec (spec) where

import Prelude

import Data.Either (Either(..))
import Data.Maybe (Maybe(..))
import MPFS.App.Facts
  ( RequestPhase(..)
  , failSecondOracleCheck
  , failFactLookup
  , finishSecondOracleCheck
  , finishFactLookup
  , finishFactsSetVerification
  , finishFactsLoad
  , finishFactsLoadAt
  , finishFactsLoadWithRootAt
  , phaseLabel
  , requestPhase
  , resetSecondOracle
  , startSecondOracleCheck
  , startFactLookup
  , startFactsSetVerification
  , startFactsLoad
  )
import MPFS.App.State (defaultState)
import MPFS.App.Verification
  ( VerificationStatus(..)
  , finishVerification
  , startVerification
  )
import MPFS.App.View as View
import MPFS.Client.Types (FactEntry, PendingRequest, TokenState)
import MPFS.SecondOracle.Types (SecondOracleVerdict(..))
import MPFS.Types (TokenId(..), TrustedRoot(..))
import MPFS.UI.Remote (Remote(..))
import Test.Spec (Spec, describe, it)
import Test.Spec.Assertions (shouldEqual)

spec :: Spec Unit
spec = describe "MPFS App Facts" do
  it "defaults the second oracle status to not asked" do
    defaultState.secondOracle `shouldEqual` NotAsked

  it "marks facts, token state, and pending requests as loading" do
    let
      selected = TokenId "token"

      state =
        defaultState
          { selectedToken = Just selected
          , facts = Success facts
          , tokenState = Success tokenState
          , pendingRequests = Success [ pendingAt 0.0 ]
          }

      next = startFactsLoad state

    next.facts `shouldEqual` Loading
    next.tokenState `shouldEqual` Loading
    next.pendingRequests `shouldEqual` Loading
    next.trustedRoot `shouldEqual` Loading
    next.secondOracle `shouldEqual` Loading
    next.selectedToken `shouldEqual` Just selected

  it "resets second oracle state when token-dependent facts change" do
    let
      checked = defaultState { secondOracle = Success verifiedVerdict }
      resetState = resetSecondOracle checked

    resetState.secondOracle `shouldEqual` NotAsked

  it "stores loaded token state, pending requests, and facts" do
    let
      selected = TokenId "token"
      request = pendingAt 100.0
      requestNowMillis = 1234.0

      state = defaultState { selectedToken = Just selected }

      next = finishFactsLoadAt requestNowMillis tokenState [ request ] facts state

    next.tokenState `shouldEqual` Success tokenState
    next.pendingRequests `shouldEqual` Success [ request ]
    next.facts `shouldEqual` Success facts
    next.requestNowMillis `shouldEqual` requestNowMillis
    next.selectedToken `shouldEqual` Just selected

  it "keeps second oracle pending until the facts load action checks it" do
    let
      state = defaultState { secondOracle = Loading }

      next =
        finishFactsLoadWithRootAt
          1234.0
          tokenState
          []
          facts
          trustedRoot
          state

    next.secondOracle `shouldEqual` Loading

  it "defaults loaded request time for compatibility" do
    let
      next = finishFactsLoad tokenState [] facts defaultState

    next.requestNowMillis `shouldEqual` 0.0

  it "classifies pending request phase from token timing windows" do
    requestPhase 110.0 tokenState (pendingAt 100.0)
      `shouldEqual`
        PhaseProcessable
    requestPhase 111.0 tokenState (pendingAt 100.0)
      `shouldEqual`
        PhaseRetractable
    requestPhase 130.0 tokenState (pendingAt 100.0)
      `shouldEqual`
        PhaseRetractable
    requestPhase 131.0 tokenState (pendingAt 100.0)
      `shouldEqual`
        PhaseExpired
    phaseLabel PhaseExpired `shouldEqual` "expired"

  it "tracks fact lookup loading, success, and failure" do
    let
      loading = startFactLookup "6b6579" defaultState
      lookedUp = finishFactLookup "76616c7565" loading
      failed = failFactLookup "not found" loading

    loading.factLookup.key `shouldEqual` "6b6579"
    loading.factLookup.value `shouldEqual` Loading
    loading.factLookup.verification `shouldEqual` VerificationNotAsked
    lookedUp.factLookup.value `shouldEqual` Success "76616c7565"
    lookedUp.factLookup.verification `shouldEqual` VerificationNotAsked
    failed.factLookup.value `shouldEqual` Failure "not found"

  it "tracks verification loading and reactor verdicts" do
    let
      loading = startVerification defaultState
      verified = finishVerification (Right unit) loading
      failed = finishVerification (Left "root mismatch") loading

    loading.factLookup.verification `shouldEqual` VerificationLoading
    verified.factLookup.verification `shouldEqual` VerificationVerified
    failed.factLookup.verification
      `shouldEqual`
        VerificationFailed "root mismatch"

  it "tracks facts-set verification independently from fact lookup" do
    let
      loading = startFactsSetVerification defaultState
      verified = finishFactsSetVerification (Right unit) loading
      rejected = finishFactsSetVerification (Left "root mismatch") loading

    loading.factsSetVerification `shouldEqual` VerificationLoading
    verified.factsSetVerification `shouldEqual` VerificationVerified
    rejected.factsSetVerification
      `shouldEqual`
        VerificationFailed "root mismatch"
    rejected.factLookup.verification `shouldEqual` VerificationNotAsked

  it "renders facts-set verifier labels" do
    View.factsSetStatusLabel VerificationVerified
      `shouldEqual`
        "Facts set: Verified"
    View.factsSetStatusLabel (VerificationFailed "root mismatch")
      `shouldEqual`
        "Facts set: Rejected: root mismatch"

  it "keeps looked-up values while automatic verification resolves" do
    let
      lookedUp = finishFactLookup "3432" (startFactLookup "70616f6c696e6f" defaultState)
      verified = finishVerification (Right unit) lookedUp
      rejected = finishVerification (Left "proof mismatch") lookedUp

    verified.factLookup.value `shouldEqual` Success "3432"
    verified.factLookup.verification `shouldEqual` VerificationVerified
    rejected.factLookup.value `shouldEqual` Success "3432"
    rejected.factLookup.verification
      `shouldEqual`
        VerificationFailed "proof mismatch"

  it "renders verifier failures as rejected verdicts" do
    View.verificationStatusLabel (VerificationFailed "proof mismatch")
      `shouldEqual`
        "Rejected: proof mismatch"

  it "tracks second oracle loading, verdicts, and local unavailable messages" do
    let
      loading = startSecondOracleCheck defaultState
      checked = finishSecondOracleCheck verifiedVerdict loading
      unavailable =
        failSecondOracleCheck "Output reference unavailable" checked

    loading.secondOracle `shouldEqual` Loading
    checked.secondOracle `shouldEqual` Success verifiedVerdict
    unavailable.secondOracle
      `shouldEqual`
        Failure "Output reference unavailable"

tokenState :: TokenState
tokenState =
  { owner: "owner"
  , root: "root"
  , max_fee: 2.0
  , process_time: 10.0
  , retract_time: 20.0
  , current_output_ref: Nothing
  }

pendingAt :: Number -> PendingRequest
pendingAt submittedAt =
  { token: "token"
  , owner: "owner"
  , key: "6b6579"
  , operation: "insert"
  , value: Just "76616c7565"
  , fee: 0.0
  , submitted_at: submittedAt
  , request_id: "aaaaaaaa#2"
  }

facts :: Array FactEntry
facts =
  [ { key: "6b6579", value: "76616c7565" }
  ]

trustedRoot :: TrustedRoot
trustedRoot = TrustedRoot "trusted-root"

verifiedVerdict :: SecondOracleVerdict
verifiedVerdict =
  SecondOracleVerified
    { chainPoint: { slotNo: 42, blockHash: "block-hash" }
    , merkleRoot: "merkle-root"
    , factsRoot: "root"
    }
