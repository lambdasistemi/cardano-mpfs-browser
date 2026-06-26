-- | WASM-backed cage helper implementation.
module MPFS.Cage.Wasm
  ( assembleTx
  , buildAssembleEnvelope
  , buildBootEnvelope
  , buildEndEnvelope
  , buildRequestEnvelope
  , wasmCageHelpers
  ) where

import Prelude

import Data.Argonaut.Core (Json, fromNumber, fromObject, fromString, stringify)
import Data.Bifunctor (lmap)
import Data.Either (Either(..))
import Data.Int (toNumber)
import Data.Tuple (Tuple(..))
import Effect.Aff (Aff)
import Foreign.Object as Object
import MPFS.Cage (CageHelpers, CageResult)
import MPFS.Cage.Reactor
  ( parseCageTxOutput
  , parseSignedTxOutput
  , runCageReactor
  )
import MPFS.Client (Client, ClientError)
import MPFS.Types
  ( CageConfig
  , CageError(..)
  , Key(..)
  , RequestId(..)
  , TokenId(..)
  , TrustedRoot(..)
  , UnsignedTxCbor(..)
  , Value(..)
  , WalletAddr(..)
  )

foreign import encodeUtf8Hex :: String -> String

wasmCageHelpers :: Client -> CageHelpers
wasmCageHelpers client =
  { registerToken: registerToken client
  , insertFact: insertFact client
  , updateFact: updateFact client
  , deleteFact: deleteFact client
  , retractRequest: retractRequest client
  , rejectExpired: rejectExpired client
  , endCage: endCage client
  , updateToken: updateToken client
  }

registerToken :: Client -> WalletAddr -> CageConfig -> CageResult
registerToken client (WalletAddr address) cfg =
  cageTxWithFacts client cfg "boot" (client.postBootFacts { address })

insertFact :: Client -> WalletAddr -> CageConfig -> TokenId -> Key -> Value -> CageResult
insertFact client (WalletAddr address) cfg (TokenId token) (Key key) (Value value) =
  cageTxWithFacts client cfg "request_insert"
    ( client.postInsertFacts
        { token
        , key: encodeUtf8Hex key
        , value: encodeUtf8Hex value
        , address
        }
    )

updateFact
  :: Client
  -> WalletAddr
  -> CageConfig
  -> TokenId
  -> Key
  -> Value
  -> Value
  -> CageResult
updateFact
  client
  (WalletAddr address)
  cfg
  (TokenId token)
  (Key key)
  (Value oldValue)
  (Value newValue) =
  cageTxWithFacts client cfg "request_update"
    ( client.postUpdateFacts
        { token
        , key: encodeUtf8Hex key
        , old_value: encodeUtf8Hex oldValue
        , new_value: encodeUtf8Hex newValue
        , address
        }
    )

deleteFact :: Client -> WalletAddr -> CageConfig -> TokenId -> Key -> Value -> CageResult
deleteFact client (WalletAddr address) cfg (TokenId token) (Key key) (Value value) =
  cageTxWithFacts client cfg "request_delete"
    ( client.postDeleteFacts
        { token
        , key: encodeUtf8Hex key
        , value: encodeUtf8Hex value
        , address
        }
    )

retractRequest :: Client -> WalletAddr -> CageConfig -> TokenId -> RequestId -> CageResult
retractRequest client (WalletAddr address) cfg _ (RequestId utxo) =
  cageTxWithFacts client cfg "retract"
    (client.postRetractFacts { utxo, address })

rejectExpired
  :: Client -> WalletAddr -> CageConfig -> TokenId -> Array RequestId -> CageResult
rejectExpired client (WalletAddr address) cfg (TokenId token) requestIds =
  cageTxWithFacts client cfg "reject"
    ( client.postRejectFacts
        { token, address, requests: requestIdStrings requestIds }
    )

endCage :: Client -> WalletAddr -> CageConfig -> TokenId -> CageResult
endCage client (WalletAddr address) cfg (TokenId token) =
  cageTxWithFacts client cfg "end"
    (client.postEndFacts { token, address })

updateToken
  :: Client -> WalletAddr -> CageConfig -> TokenId -> Array RequestId -> CageResult
updateToken client (WalletAddr address) cfg (TokenId token) requestIds =
  cageTxWithFacts client cfg "update"
    ( client.postUpdateRootFacts
        { token, address, requests: requestIdStrings requestIds }
    )

assembleTx :: String -> String -> Aff (Either CageError String)
assembleTx unsignedTx witnessSet = do
  result <- runCageReactor (buildAssembleEnvelope unsignedTx witnessSet)
  pure (parseSignedTxOutput result)

cageTxWithFacts
  :: Client
  -> CageConfig
  -> String
  -> Aff (Either ClientError Json)
  -> CageResult
cageTxWithFacts client cfg op fetchFacts = do
  eroot <- client.getTrustedRoot
  ectx <- client.getEvalContext
  efacts <- fetchFacts
  case clientError eroot, clientError ectx, clientError efacts of
    Left err, _, _ -> pure (Left err)
    _, Left err, _ -> pure (Left err)
    _, _, Left err -> pure (Left err)
    Right root, Right evalContext, Right facts -> do
      let
        envelope =
          if op == "boot" then buildBootEnvelope root evalContext cfg facts
          else if op == "end" then buildEndEnvelope root evalContext cfg facts
          else buildRequestEnvelope op root evalContext cfg facts
      result <- runCageReactor envelope
      pure (UnsignedTxCbor <$> parseCageTxOutput result)

clientError :: forall a. Either ClientError a -> Either CageError a
clientError = lmap (CageError <<< show)

requestIdStrings :: Array RequestId -> Array String
requestIdStrings = map \(RequestId requestId) -> requestId

buildBootEnvelope :: TrustedRoot -> Json -> CageConfig -> Json -> String
buildBootEnvelope root evalContext cfg facts =
  stringify (buildEnvelope "boot" root evalContext cfg facts)

buildEndEnvelope :: TrustedRoot -> Json -> CageConfig -> Json -> String
buildEndEnvelope root evalContext cfg facts =
  stringify (buildEnvelope "end" root evalContext cfg facts)

buildRequestEnvelope :: String -> TrustedRoot -> Json -> CageConfig -> Json -> String
buildRequestEnvelope op root evalContext cfg facts =
  stringify (buildEnvelope op root evalContext cfg facts)

buildAssembleEnvelope :: String -> String -> String
buildAssembleEnvelope unsignedTx witnessSet =
  stringify
    ( obj
        [ Tuple "op" (fromString "assemble")
        , Tuple "unsigned_tx" (fromString unsignedTx)
        , Tuple "witness_set" (fromString witnessSet)
        ]
    )

buildEnvelope :: String -> TrustedRoot -> Json -> CageConfig -> Json -> Json
buildEnvelope op (TrustedRoot trustedRoot) evalContext cfg facts =
  obj
    [ Tuple "op" (fromString op)
    , Tuple "trusted_root" (fromString trustedRoot)
    , Tuple "eval_context" evalContext
    , Tuple "cage_config" (cageConfigJson cfg)
    , Tuple "wallet_policy" walletPolicyJson
    , Tuple "facts" facts
    ]

cageConfigJson :: CageConfig -> Json
cageConfigJson cfg =
  obj
    [ Tuple "cage_script_bytes" (fromString cfg.cageScriptBytes)
    , Tuple "request_script_bytes" (fromString cfg.requestScriptBytes)
    , Tuple "default_process_time" (intJson cfg.defaultProcessTime)
    , Tuple "default_retract_time" (intJson cfg.defaultRetractTime)
    , Tuple "default_tip" (intJson cfg.defaultTip)
    , Tuple "network" (fromString cfg.network)
    ]

walletPolicyJson :: Json
walletPolicyJson =
  obj
    [ Tuple "max_fee" (fromNumber 10000000.0)
    , Tuple "max_min_utxo_coin_per_byte" (fromNumber 10000.0)
    , Tuple "max_ex_unit_prices"
        ( obj
            [ Tuple "price_memory" (fromNumber 1000000000000.0)
            , Tuple "price_steps" (fromNumber 1000000000000.0)
            , Tuple "pr_mem" (fromNumber 1000000000000.0)
            , Tuple "pr_steps" (fromNumber 1000000000000.0)
            ]
        )
    ]

intJson :: Int -> Json
intJson = fromNumber <<< toNumber

obj :: Array (Tuple String Json) -> Json
obj = fromObject <<< Object.fromFoldable
