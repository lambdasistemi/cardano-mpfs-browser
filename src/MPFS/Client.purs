-- | HTTP client for the MPFS off-chain API.
-- Close over a base URL to get a record of
-- endpoint functions.
module MPFS.Client
  ( ClientError(..)
  , Client
  , decodeFactBody
  , decodeFactsBody
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
import Data.Array (null)
import Data.Bifunctor (lmap)
import Data.Either (Either(..))
import Data.Maybe (Maybe(..))
import Effect.Aff (Aff)
import Fetch (Method(..), fetch)
import MPFS.Client.Types
  ( BootBody
  , DeleteBody
  , EndBody
  , FactResponse
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
  , TokenState
  , UpdateBody
  , UpdateRootBody
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
      get
        (baseUrl <> "/tokens/" <> tokenId)
  , getTokenRoot: \tokenId ->
      get
        ( baseUrl <> "/tokens/" <> tokenId
            <> "/root"
        )
  , getTokenFact: \tokenId key ->
      getWith decodeFactBody
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
      get
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
  if null response.tokens.entries then
    pure []
  else
    Left $ DecodeError
      "Cannot derive token ids from tokens.entries[].txout_cbor"

decodeFactsBody :: String -> Either ClientError (Array FactEntry)
decodeFactsBody body = do
  response :: FactsResponse <- decodeBody body
  pure response.facts

decodeFactBody :: String -> Either ClientError Hex
decodeFactBody body = do
  response :: FactResponse <- decodeBody body
  pure response.value

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
