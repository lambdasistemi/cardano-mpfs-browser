-- | HTTP client for the MPFS off-chain API.
-- Close over a base URL to get a record of
-- endpoint functions.
module MPFS.Client
  ( ClientError(..)
  , Client
  , FactSnapshot
  , RawFactResponse
  , decodeFactBody
  , decodeFactRawBody
  , decodeFactsBody
  , decodeRequestsBody
  , decodeTokenBody
  , decodeTokenRootBody
  , decodeTokensBody
  , mkClient
  ) where

import Prelude

import Data.Argonaut.Core (Json, stringify)
import Data.Argonaut.Decode.Class
  ( class DecodeJson
  , decodeJson
  )
import Data.Argonaut.Decode.Combinators ((.:), (.:?))
import Data.Argonaut.Decode.Error (JsonDecodeError)
import Data.Argonaut.Encode.Class
  ( class EncodeJson
  , encodeJson
  )
import Data.Argonaut.Parser (jsonParser)
import Data.Bifunctor (lmap)
import Data.Either (Either(..))
import Data.Maybe (Maybe(..))
import Data.Traversable (traverse)
import Effect.Aff (Aff)
import Fetch (Method(..), fetch)
import Foreign.Object as Object
import MPFS.Client.Types
  ( BootBody
  , DeleteBody
  , EndBody
  , FactEntry
  , FactsResponse
  , Hex
  , InsertBody
  , PendingRequest
  , RejectBody
  , RetractBody
  , RequestUpdateBody
  , StatusResponse
  , SubmitBody
  , TokenId
  , TokensResponse
  , TokenUtxoEntry
  , TokenOutputRef
  , TokenState
  , UpdateBody
  , UpdateRootBody
  )
import MPFS.Tx.Cbor (TxDatum(..), decodeTxOutput)
import MPFS.Tx.Cbor.Bytes (hexToBytes)
import MPFS.Tx.PlutusData
  ( CageDatum(..)
  , Operation(..)
  , interpretDatum
  )
import MPFS.Types (TrustedRoot(..))

-- | Client error: HTTP or JSON decoding failure.
data ClientError
  = HttpError Int String
  | DecodeError String

instance Show ClientError where
  show (HttpError code msg) =
    "HTTP " <> show code <> ": " <> msg
  show (DecodeError msg) =
    "Decode error: " <> msg

-- | Record of all MPFS API operations.
type Client =
  { getStatus :: Aff (Either ClientError StatusResponse)
  , getTokens :: Aff (Either ClientError (Array TokenId))
  , getToken ::
      TokenId
      -> Aff (Either ClientError TokenState)
  , getTokenRoot :: TokenId -> Aff (Either ClientError Hex)
  , getTokenFact ::
      TokenId
      -> Hex
      -> Aff (Either ClientError Hex)
  , getTokenFactRaw ::
      TokenId
      -> Hex
      -> Aff (Either ClientError RawFactResponse)
  , getTokenFacts ::
      TokenId
      -> Aff (Either ClientError (Array FactEntry))
  , getTokenProof ::
      TokenId
      -> Hex
      -> Aff (Either ClientError Hex)
  , getTokenRequests ::
      TokenId
      -> Aff
           (Either ClientError (Array PendingRequest))
  , boot :: BootBody -> Aff (Either ClientError Hex)
  , insert :: InsertBody -> Aff (Either ClientError Hex)
  , delete :: DeleteBody -> Aff (Either ClientError Hex)
  , update :: UpdateBody -> Aff (Either ClientError Hex)
  , retract :: RetractBody -> Aff (Either ClientError Hex)
  , end :: EndBody -> Aff (Either ClientError Hex)
  , submit :: SubmitBody -> Aff (Either ClientError Hex)
  , getTrustedRoot :: Aff (Either ClientError TrustedRoot)
  , getEvalContext :: Aff (Either ClientError Json)
  , postBootFacts :: BootBody -> Aff (Either ClientError Json)
  , postInsertFacts :: InsertBody -> Aff (Either ClientError Json)
  , postUpdateFacts :: RequestUpdateBody -> Aff (Either ClientError Json)
  , postDeleteFacts :: DeleteBody -> Aff (Either ClientError Json)
  , postRetractFacts ::
      { utxo :: String, address :: Hex } -> Aff (Either ClientError Json)
  , postRejectFacts :: RejectBody -> Aff (Either ClientError Json)
  , postEndFacts :: EndBody -> Aff (Either ClientError Json)
  , postUpdateRootFacts :: UpdateRootBody -> Aff (Either ClientError Json)
  , submitSignedTx :: Hex -> Aff (Either ClientError Hex)
  , getUtxo ::
      Hex -> Int -> Aff (Either ClientError Hex)
  , getUtxoProof ::
      Hex -> Int -> Aff (Either ClientError Hex)
  , getUtxoRoot :: Aff (Either ClientError Hex)
  }

-- | Create a client closed over a base URL.
mkClient :: String -> Client
mkClient baseUrl =
  { getStatus:
      get (baseUrl <> "/status")
  , getTokens:
      getWith decodeTokensBody (baseUrl <> "/tokens")
  , getToken: \tokenId ->
      getWith decodeTokenBody
        (baseUrl <> "/tokens/" <> tokenId)
  , getTokenRoot: \tokenId ->
      getWith decodeTokenRootBody
        ( baseUrl <> "/tokens/" <> tokenId
            <> "/root"
        )
  , getTokenFact: \tokenId key ->
      getWith decodeFactBody
        ( baseUrl <> "/tokens/" <> tokenId
            <> "/facts/"
            <> key
        )
  , getTokenFactRaw: \tokenId key ->
      getWith decodeFactRawBody
        ( baseUrl <> "/tokens/" <> tokenId
            <> "/facts/"
            <> key
        )
  , getTokenFacts: \tokenId ->
      getWith decodeFactsBody
        ( baseUrl <> "/tokens/" <> tokenId
            <> "/facts"
        )
  , getTokenProof: \tokenId key ->
      get
        ( baseUrl <> "/tokens/" <> tokenId
            <> "/proofs/"
            <> key
        )
  , getTokenRequests: \tokenId ->
      getWith decodeRequestsBody
        ( baseUrl <> "/tokens/" <> tokenId
            <> "/requests"
        )
  , boot:
      post (baseUrl <> "/tx/boot")
  , insert:
      post (baseUrl <> "/tx/request/insert")
  , delete:
      post (baseUrl <> "/tx/request/delete")
  , update:
      post (baseUrl <> "/tx/update")
  , retract:
      post (baseUrl <> "/tx/retract")
  , end:
      post (baseUrl <> "/tx/end")
  , submit:
      post (baseUrl <> "/tx/submit")
  , getTrustedRoot:
      getWith decodeTrustedRootBody (baseUrl <> "/status")
  , getEvalContext:
      getJson (baseUrl <> "/eval-context")
  , postBootFacts:
      postJson (baseUrl <> "/facts/boot")
  , postInsertFacts:
      postJson (baseUrl <> "/facts/request/insert")
  , postUpdateFacts:
      postJson (baseUrl <> "/facts/request/update")
  , postDeleteFacts:
      postJson (baseUrl <> "/facts/request/delete")
  , postRetractFacts:
      postJson (baseUrl <> "/facts/retract")
  , postRejectFacts:
      postJson (baseUrl <> "/facts/reject")
  , postEndFacts:
      postJson (baseUrl <> "/facts/end")
  , postUpdateRootFacts:
      postJson (baseUrl <> "/facts/update")
  , submitSignedTx: \signedTxCbor ->
      postWith decodeTxIdBody
        (baseUrl <> "/submit")
        { signedTxCbor }
  , getUtxo: \txId txIx ->
      get
        ( baseUrl <> "/utxo/" <> txId
            <> "/"
            <> show txIx
        )
  , getUtxoProof: \txId txIx ->
      get
        ( baseUrl <> "/utxo/" <> txId
            <> "/"
            <> show txIx
            <> "/proof"
        )
  , getUtxoRoot:
      get (baseUrl <> "/utxo/root")
  }

-- Internal

decodeBody
  :: forall a
   . DecodeJson a
  => String
  -> Either ClientError a
decodeBody body = do
  json <- lmap DecodeError (jsonParser body)
  lmap (show >>> DecodeError) (decodeJson json)

decodeTokensBody :: String -> Either ClientError (Array TokenId)
decodeTokensBody body = do
  response :: TokensResponse <- decodeBody body
  traverse tokenIdFromEntry response.tokens.entries

decodeTokenBody :: String -> Either ClientError TokenState
decodeTokenBody body = do
  json <- lmap DecodeError (jsonParser body)
  case decodeTokenEnvelope json of
    Right tokenState ->
      pure tokenState
    Left _ ->
      lmap (show >>> DecodeError) do
        flatState :: FlatTokenState <- decodeJson json
        pure (tokenStateFromFlat flatState Nothing)

decodeTokenRootBody :: String -> Either ClientError Hex
decodeTokenRootBody = decodeBody

type TokenEnvelope =
  { state ::
      { utxo ::
          { tx_in :: TokenOutputRef
          , tx_out :: Hex
          }
      }
  }

type FlatTokenState =
  { owner :: Hex
  , root :: Hex
  , max_fee :: Number
  , process_time :: Number
  , retract_time :: Number
  }

type RequestSetEnvelope =
  { request_set ::
      { entries :: Array RequestSetEntry
      }
  }

type RequestSetEntry =
  { ref ::
      { tx_id :: Hex
      , tx_ix :: Int
      }
  , txout_cbor :: Hex
  }

decodeTokenEnvelope :: Json -> Either ClientError TokenState
decodeTokenEnvelope json = do
  envelope :: TokenEnvelope <-
    lmap (show >>> DecodeError) (decodeJson json)
  tokenStateFromTxOut
    (Just envelope.state.utxo.tx_in)
    envelope.state.utxo.tx_out

tokenStateFromTxOut :: Maybe TokenOutputRef -> Hex -> Either ClientError TokenState
tokenStateFromTxOut outputRef txOutCbor =
  case (decodeTxOutput (hexToBytes txOutCbor)).datum of
    InlineDatum pd ->
      case interpretDatum pd of
        Just (StateDatum state) ->
          pure $
            tokenStateFromFlat
              { owner: state.owner
              , root: state.root
              , max_fee: state.maxFee
              , process_time: state.processTime
              , retract_time: state.retractTime
              }
              outputRef
        _ ->
          Left $ DecodeError "Expected token state inline datum"
    _ ->
      Left $ DecodeError "Expected token state TxOut inline datum"

tokenStateFromFlat :: FlatTokenState -> Maybe TokenOutputRef -> TokenState
tokenStateFromFlat state outputRef =
  { owner: state.owner
  , root: state.root
  , max_fee: state.max_fee
  , process_time: state.process_time
  , retract_time: state.retract_time
  , current_output_ref: outputRef
  }

tokenIdFromEntry :: TokenUtxoEntry -> Either ClientError TokenId
tokenIdFromEntry entry =
  case tokenIdsFromEntry entry of
    [ tokenId ] ->
      pure tokenId
    [] ->
      Left $ DecodeError
        "Cannot derive token id from tokens.entries[].txout_cbor: no assets"
    _ ->
      Left $ DecodeError
        "Cannot derive token id from tokens.entries[].txout_cbor: multiple assets"

tokenIdsFromEntry :: TokenUtxoEntry -> Array TokenId
tokenIdsFromEntry entry =
  let
    txOut = decodeTxOutput (hexToBytes entry.txout_cbor)
  in
    Object.values txOut.value.assets >>= Object.keys

decodeFactsBody :: String -> Either ClientError (Array FactEntry)
decodeFactsBody body = do
  response :: FactsResponse <- decodeBody body
  pure response.facts

decodeRequestsBody :: String -> Either ClientError (Array PendingRequest)
decodeRequestsBody body = do
  json <- lmap DecodeError (jsonParser body)
  case decodeRequestEntries json of
    Right requests ->
      pure requests
    Left _ ->
      lmap (show >>> DecodeError) (decodeRequests json)

decodeFactBody :: String -> Either ClientError Hex
decodeFactBody body = do
  response <- decodeFactRawBody body
  pure response.value

type FactSnapshot =
  { chainpoint :: { slot :: Int }
  , utxo_root :: Hex
  }

type RawFactResponse =
  { value :: Hex
  , raw :: Json
  , snapshot :: FactSnapshot
  }

type FactResponseWithSnapshot =
  { value :: Hex
  , snapshot :: FactSnapshot
  }

decodeFactRawBody :: String -> Either ClientError RawFactResponse
decodeFactRawBody body = do
  json <- lmap DecodeError (jsonParser body)
  response :: FactResponseWithSnapshot <-
    lmap (show >>> DecodeError) (decodeJson json)
  pure
    { value: response.value
    , raw: json
    , snapshot: response.snapshot
    }

decodeTrustedRootBody :: String -> Either ClientError TrustedRoot
decodeTrustedRootBody body = do
  json <- lmap DecodeError (jsonParser body)
  lmap (show >>> DecodeError) (decodeTrustedRoot json)

decodeTrustedRoot :: Json -> Either JsonDecodeError TrustedRoot
decodeTrustedRoot json = do
  top <- decodeJson json
  mRoot <- top .:? "utxo_root"
  case mRoot of
    Just root -> pure (TrustedRoot root)
    Nothing -> do
      snapshot <- top .: "snapshot"
      root <- snapshot .: "utxo_root"
      pure (TrustedRoot root)

decodeTxIdBody :: String -> Either ClientError Hex
decodeTxIdBody body = do
  json <- lmap DecodeError (jsonParser body)
  lmap (show >>> DecodeError) (decodeTxId json)

decodeTxId :: Json -> Either JsonDecodeError Hex
decodeTxId json = do
  top <- decodeJson json
  top .: "txId"

decodeRequestEntries :: Json -> Either ClientError (Array PendingRequest)
decodeRequestEntries json = do
  envelope :: RequestSetEnvelope <-
    lmap (show >>> DecodeError) (decodeJson json)
  traverse pendingRequestFromEntry envelope.request_set.entries

pendingRequestFromEntry :: RequestSetEntry -> Either ClientError PendingRequest
pendingRequestFromEntry entry = do
  request <- requestFromTxOut entry.txout_cbor
  let
    op =
      pendingOperation request.operation
  pure
    { token: request.tokenId
    , owner: request.owner
    , key: request.key
    , operation: op.operation
    , value: op.value
    , fee: request.fee
    , submitted_at: request.submittedAt
    , request_id: entry.ref.tx_id <> "#" <> show entry.ref.tx_ix
    }

requestFromTxOut
  :: Hex
  -> Either
       ClientError
       { tokenId :: String
       , owner :: String
       , key :: String
       , operation :: Operation
       , fee :: Number
       , submittedAt :: Number
       }
requestFromTxOut txOutCbor =
  case (decodeTxOutput (hexToBytes txOutCbor)).datum of
    InlineDatum pd ->
      case interpretDatum pd of
        Just (RequestDatum request) ->
          pure request
        _ ->
          Left $ DecodeError "Expected request inline datum"
    _ ->
      Left $ DecodeError "Expected request TxOut inline datum"

pendingOperation
  :: Operation
  -> { operation :: String, value :: Maybe Hex }
pendingOperation = case _ of
  Insert value ->
    { operation: "insert", value: Just value }
  Delete value ->
    { operation: "delete", value: Just value }
  Update _ value ->
    { operation: "update", value: Just value }

decodeRequests :: Json -> Either JsonDecodeError (Array PendingRequest)
decodeRequests json = do
  top <- decodeJson json
  mRequests <- top .:? "requests"
  case mRequests of
    Just requests ->
      traverse decodePendingRequest requests
    Nothing -> do
      requests <- decodeJson json
      traverse decodePendingRequest requests

decodePendingRequest :: Json -> Either JsonDecodeError PendingRequest
decodePendingRequest json = do
  request <- decodeJson json
  token <- request .: "token"
  owner <- request .: "owner"
  key <- request .: "key"
  operation <- request .: "operation"
  value <- request .:? "value"
  fee <- request .: "fee"
  submitted_at <- request .: "submitted_at"
  request_id <- decodeRequestId request
  pure
    { token
    , owner
    , key
    , operation
    , value
    , fee
    , submitted_at
    , request_id
    }

decodeRequestId :: Object.Object Json -> Either JsonDecodeError String
decodeRequestId request = do
  mSnake <- request .:? "request_id"
  case mSnake of
    Just requestId ->
      pure requestId
    Nothing -> do
      mCamel <- request .:? "requestId"
      case mCamel of
        Just requestId ->
          pure requestId
        Nothing -> do
          utxo <- request .: "utxo"
          txIn <- utxo .: "tx_in"
          txId <- txIn .: "tx_id"
          txIx <- txIn .: "tx_ix"
          pure (txId <> "#" <> show (txIx :: Int))

get
  :: forall a
   . DecodeJson a
  => String
  -> Aff (Either ClientError a)
get url = do
  getWith decodeBody url

getWith
  :: forall a
   . (String -> Either ClientError a)
  -> String
  -> Aff (Either ClientError a)
getWith decoder url = do
  response <- fetch url {}
  body <- response.text
  pure
    if response.ok then decoder body
    else Left $ HttpError response.status body

getJson :: String -> Aff (Either ClientError Json)
getJson = getWith decodeJsonBody

decodeJsonBody :: String -> Either ClientError Json
decodeJsonBody = jsonParser >>> lmap DecodeError

post
  :: forall req a
   . EncodeJson req
  => DecodeJson a
  => String
  -> req
  -> Aff (Either ClientError a)
post url reqBody = do
  postWith decodeBody url reqBody

postWith
  :: forall req a
   . EncodeJson req
  => (String -> Either ClientError a)
  -> String
  -> req
  -> Aff (Either ClientError a)
postWith decoder url reqBody = do
  response <- fetch url
    { method: POST
    , body: stringify (encodeJson reqBody)
    , headers:
        { "Content-Type": "application/json" }
    }
  body <- response.text
  pure
    if response.ok then decoder body
    else Left $ HttpError response.status body

postJson
  :: forall req
   . EncodeJson req
  => String
  -> req
  -> Aff (Either ClientError Json)
postJson = postWith decodeJsonBody
