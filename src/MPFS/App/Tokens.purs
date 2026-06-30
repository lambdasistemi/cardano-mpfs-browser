module MPFS.App.Tokens
  ( failTokenLoad
  , finishTokenLoad
  , finishTokenLoadWithCompleteness
  , selectToken
  , startTokenLoad
  ) where

import Data.Array as Array
import Data.Maybe (Maybe(..))
import MPFS.App.Verification (VerificationStatus(..))
import MPFS.App.State (AppState)
import MPFS.Types (TokenId)
import MPFS.UI.Remote (Remote(..))

startTokenLoad :: AppState -> AppState
startTokenLoad state =
  state
    { tokens = Loading
    , tokenCompleteness = VerificationLoading
    }

finishTokenLoad :: Array TokenId -> AppState -> AppState
finishTokenLoad =
  finishTokenLoadWithCompleteness VerificationVerified

finishTokenLoadWithCompleteness
  :: VerificationStatus
  -> Array TokenId
  -> AppState
  -> AppState
finishTokenLoadWithCompleteness tokenCompleteness tokens state =
  state
    { tokens = Success tokens
    , tokenCompleteness = tokenCompleteness
    , selectedToken = nextSelection
    }
  where
  nextSelection = case state.selectedToken of
    Just token | Array.elem token tokens -> Just token
    _ -> Array.head tokens

failTokenLoad :: String -> AppState -> AppState
failTokenLoad message state =
  state
    { tokens = Failure message
    , tokenCompleteness = VerificationFailed message
    }

selectToken :: TokenId -> AppState -> AppState
selectToken token state = state { selectedToken = Just token }
