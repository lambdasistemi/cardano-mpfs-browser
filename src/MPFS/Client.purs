-- | HTTP client for the MPFS off-chain API.
-- Close over a base URL to get a record of
-- endpoint functions.
module MPFS.Client
  ( ClientError(..)
  , Client
  , mkClient
  ) where

import Prelude

import Data.Argonaut.Core (stringify)
import Data.Argonaut.Decode.Class
  ( class DecodeJson
  , decodeJson
  )
import Data.Argonaut.Encode.Class
  ( class EncodeJson
  , encodeJson
  )
import Data.Argonaut.Parser (jsonParser)
import Data.Bifunctor (lmap)
import Data.Either (Either(..))
import Effect.Aff (Aff)
import Fetch (Method(..), fetch)
import MPFS.Client.Types
  ( BootBody
  , DeleteBody
  , EndBody
  , Hex
  , InsertBody
  , PendingRequest
  , RetractBody
  , StatusResponse
  , SubmitBody
  , TokenId
  , TokenState
  , UpdateBody
  )

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
      get (baseUrl <> "/tokens")
  , getToken: \tokenId ->
      get
        (baseUrl <> "/tokens/" <> tokenId)
  , getTokenRoot: \tokenId ->
      get
        ( baseUrl <> "/tokens/" <> tokenId
            <> "/root"
        )
  , getTokenFact: \tokenId key ->
      get
        ( baseUrl <> "/tokens/" <> tokenId
            <> "/facts/"
            <> key
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

get
  :: forall a
   . DecodeJson a
  => String
  -> Aff (Either ClientError a)
get url = do
  response <- fetch url {}
  body <- response.text
  pure
    if response.ok then decodeBody body
    else Left $ HttpError response.status body

post
  :: forall req a
   . EncodeJson req
  => DecodeJson a
  => String
  -> req
  -> Aff (Either ClientError a)
post url reqBody = do
  response <- fetch url
    { method: POST
    , body: stringify (encodeJson reqBody)
    , headers:
        { "Content-Type": "application/json" }
    }
  body <- response.text
  pure
    if response.ok then decodeBody body
    else Left $ HttpError response.status body
