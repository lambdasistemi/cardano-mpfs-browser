-- | HTTP client and decoders for the csmt-utxo service.
module MPFS.SecondOracle.Client
  ( ClientError(..)
  , Client
  , defaultBaseUrl
  , defaultClient
  , decodeMerkleRootsBody
  , decodeProofBody
  , mkClient
  ) where

import Prelude

import Data.Argonaut.Decode.Class
  ( class DecodeJson
  , decodeJson
  )
import Data.Argonaut.Parser (jsonParser)
import Data.Bifunctor (lmap)
import Data.Either (Either(..))
import Effect.Aff (Aff)
import Fetch (fetch)
import MPFS.SecondOracle.Types
  ( MerkleRootEntry
  , OutputRef
  , ProofResponse
  )

data ClientError
  = HttpError Int String
  | DecodeError String

instance Show ClientError where
  show (HttpError code msg) =
    "HTTP " <> show code <> ": " <> msg
  show (DecodeError msg) =
    "Decode error: " <> msg

type Client =
  { getMerkleRoots :: Aff (Either ClientError (Array MerkleRootEntry))
  , getProof :: OutputRef -> Aff (Either ClientError ProofResponse)
  }

defaultBaseUrl :: String
defaultBaseUrl = "https://utxo-csmt.plutimus.com"

defaultClient :: Client
defaultClient =
  mkClient defaultBaseUrl

mkClient :: String -> Client
mkClient baseUrl =
  { getMerkleRoots:
      getWith decodeMerkleRootsBody (baseUrl <> "/merkle-roots")
  , getProof: \ref ->
      getWith decodeProofBody
        ( baseUrl <> "/proof/"
            <> ref.txId
            <> "/"
            <> show ref.txIx
        )
  }

decodeMerkleRootsBody :: String -> Either ClientError (Array MerkleRootEntry)
decodeMerkleRootsBody =
  decodeBody

decodeProofBody :: String -> Either ClientError ProofResponse
decodeProofBody =
  decodeBody

decodeBody
  :: forall a
   . DecodeJson a
  => String
  -> Either ClientError a
decodeBody body = do
  json <- lmap DecodeError (jsonParser body)
  lmap (show >>> DecodeError) (decodeJson json)

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
