-- | Stdin/stdout bridge to the Haskell WASM verify reactor.
module MPFS.Reactor
  ( ReactorResult
  , runCageReactor
  , verifyEnvelope
  , parseVerifyOutput
  ) where

import Prelude

import Control.Promise (Promise, toAffE)
import Data.Either (Either(..))
import Data.Array (head)
import Data.Maybe (Maybe(..), fromMaybe)
import Data.String.CodeUnits as CU
import Data.String.Common as String
import Data.String.Pattern (Pattern(..))
import Effect (Effect)
import Effect.Aff (Aff)

type ReactorResult =
  { stdout :: String
  , stderr :: String
  , exitOk :: Boolean
  }

foreign import runCageReactorImpl :: String -> Effect (Promise ReactorResult)

runCageReactor :: String -> Aff ReactorResult
runCageReactor = toAffE <<< runCageReactorImpl

verifyEnvelope :: String -> Aff (Either String Unit)
verifyEnvelope envelope = parseVerifyOutput <$> runCageReactor envelope

parseVerifyOutput :: ReactorResult -> Either String Unit
parseVerifyOutput result
  | not result.exitOk = Left (firstMessage result)
  | firstLine result.stdout == "verify_ok" = Right unit
  | otherwise =
      case CU.stripPrefix (Pattern "verify_error: ") (firstLine result.stdout) of
        Just err -> Left (String.trim err)
        Nothing -> Left (firstMessage result)

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
