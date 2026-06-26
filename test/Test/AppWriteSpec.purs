module Test.AppWriteSpec (spec) where

import Prelude

import Data.Either (Either(..))
import Data.Maybe (Maybe(..))
import MPFS.Client (decodeRequestsBody)
import MPFS.App.State (WalletStatus(..), defaultState)
import MPFS.App.Write
  ( RefreshTarget(..)
  , WriteOperation(..)
  , WriteStatus(..)
  , failWrite
  , initialWriteForms
  , refreshPlanAfterSubmit
  , requestIdOf
  , submittedWrite
  , validatePrerequisites
  )
import MPFS.Client.Types (PendingRequest)
import MPFS.Types (RequestId(..), TokenId(..), UnsignedTxCbor(..))
import Test.Spec (Spec, describe, it)
import Test.Spec.Assertions (fail, shouldEqual)

spec :: Spec Unit
spec = describe "MPFS App Write" do
  it "tracks write operation status through successful submit details" do
    let
      submitted =
        submittedWrite
          (UnsignedTxCbor "unsigned-cbor")
          "witness-cbor"
          "signed-cbor"
          "tx-id"

    submitted
      `shouldEqual`
        WriteSubmitted
          (UnsignedTxCbor "unsigned-cbor")
          "witness-cbor"
          "signed-cbor"
          "tx-id"

  it "fails selected-token writes before any build action when prerequisites are missing" do
    validatePrerequisites WriteInsertFact defaultState
      `shouldEqual`
        Left "Connect a wallet first."

    validatePrerequisites WriteInsertFact
      ( defaultState
          { walletSession =
              defaultState.walletSession
                { status = WalletConnected
                , selectedAddress = Just "addr_test1"
                }
          }
      )
      `shouldEqual`
        Left "Select a token first."

  it "does not require a selected token to register a new token" do
    validatePrerequisites WriteRegisterToken
      ( defaultState
          { walletSession =
              defaultState.walletSession
                { status = WalletConnected
                , selectedAddress = Just "addr_test1"
                }
          }
      )
      `shouldEqual`
        Right unit

  it "records failed writes in app state without changing form input" do
    let
      state = defaultState { writeForms = initialWriteForms { insertKey = "name" } }
      failed = failWrite "build failed" state

    failed.writeStatus `shouldEqual` WriteFailed "build failed"
    failed.writeForms.insertKey `shouldEqual` "name"

  it "plans read refreshes after a submitted selected-token write" do
    refreshPlanAfterSubmit (Just (TokenId "token-1"))
      `shouldEqual`
        [ RefreshTokens
        , RefreshTokenFacts (TokenId "token-1")
        , RefreshTokenState (TokenId "token-1")
        , RefreshPendingRequests (TokenId "token-1")
        ]

  it "derives request ids from pending request rows" do
    requestIdOf pendingRequest
      `shouldEqual`
        Just (RequestId "aaaaaaaa#2")

  it "decodes request ids from witnessed pending request UTxO refs" do
    case decodeRequestsBody requestResponseBody of
      Left err ->
        fail (show err)
      Right requests ->
        map requestIdOf requests
          `shouldEqual`
            [ Just (RequestId "bbbbbbbb#3") ]

pendingRequest :: PendingRequest
pendingRequest =
  { token: "token-1"
  , owner: "owner"
  , key: "6b6579"
  , operation: "insert"
  , value: Just "76616c7565"
  , fee: 0.0
  , submitted_at: 100.0
  , request_id: "aaaaaaaa#2"
  }

requestResponseBody :: String
requestResponseBody =
  """
  {"requests":[{"token":"token-1","owner":"owner","key":"6b6579","operation":"insert","value":"76616c7565","fee":0,"submitted_at":100,"utxo":{"tx_in":{"tx_id":"bbbbbbbb","tx_ix":3},"tx_out":"00"}}]}
  """
