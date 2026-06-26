-- | Stdin/stdout bridge to the MPFS cage reactor.
module MPFS.Cage.Reactor
  ( ReactorResult
  , buildDecodeEnvelope
  , decodeTxOut
  , parseCageTxOutput
  , parseDecodedOutput
  , parseSignedTxOutput
  , runCageReactor
  ) where

import Prelude

import Control.Promise (Promise, toAffE)
import Data.Argonaut.Core (Json, fromObject, fromString, stringify)
import Data.Argonaut.Parser (jsonParser)
import Data.Array (head)
import Data.Either (Either(..))
import Data.Maybe (Maybe(..), fromMaybe)
import Data.String.CodeUnits as CU
import Data.String.Common as String
import Data.String.Pattern (Pattern(..))
import Data.Tuple (Tuple(..))
import Effect (Effect)
import Effect.Aff (Aff)
import Foreign.Object as Object
import MPFS.Types (CageError(..))

type ReactorResult =
  { stdout :: String
  , stderr :: String
  , exitOk :: Boolean
  }

foreign import runCageReactorImpl :: String -> Effect (Promise ReactorResult)

runCageReactor :: String -> Aff ReactorResult
runCageReactor = toAffE <<< runCageReactorImpl

decodeTxOut :: String -> Aff (Either CageError Json)
decodeTxOut txOutHex = do
  result <- runCageReactor (buildDecodeEnvelope txOutHex)
  pure (parseDecodedOutput result)

buildDecodeEnvelope :: String -> String
buildDecodeEnvelope txOutHex =
  stringify
    ( fromObject
        ( Object.fromFoldable
            [ Tuple "op" (fromString "decode")
            , Tuple "tx_out" (fromString txOutHex)
            ]
        )
    )

parseDecodedOutput :: ReactorResult -> Either CageError Json
parseDecodedOutput result
  | not result.exitOk = Left (CageError (firstMessage result))
  | otherwise =
      case CU.stripPrefix (Pattern "decoded: ") (firstLine result.stdout) of
        Just payload ->
          case jsonParser (String.trim payload) of
            Right json -> Right json
            Left err -> Left (CageError ("decode parse: " <> err))
        Nothing -> Left (CageError (firstMessage result))

parseCageTxOutput :: ReactorResult -> Either CageError String
parseCageTxOutput = parsePrefixedOutput "cage_tx: "

parseSignedTxOutput :: ReactorResult -> Either CageError String
parseSignedTxOutput = parsePrefixedOutput "signed_tx: "

parsePrefixedOutput :: String -> ReactorResult -> Either CageError String
parsePrefixedOutput prefix result
  | not result.exitOk = Left (CageError (firstMessage result))
  | otherwise =
      case CU.stripPrefix (Pattern prefix) (firstLine result.stdout) of
        Just hex | String.trim hex /= "" -> Right (String.trim hex)
        _ -> Left (CageError (firstMessage result))

firstMessage :: ReactorResult -> String
firstMessage result =
  let
    err = String.trim result.stderr
    out = String.trim result.stdout
  in
    if err /= "" then err
    else if out /= "" then firstLine out
    else "reactor returned no output"

firstLine :: String -> String
firstLine text =
  String.trim
    (fromMaybe text (head (String.split (Pattern "\n") text)))
