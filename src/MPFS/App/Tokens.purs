module MPFS.App.Tokens
  ( failTokenLoad
  , finishTokenLoad
  , selectToken
  , startTokenLoad
  ) where

import Data.Array as Array
import Data.Maybe (Maybe(..))
import MPFS.App.State (AppState)
import MPFS.Types (TokenId)
import MPFS.UI.Remote (Remote(..))

startTokenLoad :: AppState -> AppState
startTokenLoad state = state { tokens = Loading }

finishTokenLoad :: Array TokenId -> AppState -> AppState
finishTokenLoad tokens state =
  state
    { tokens = Success tokens
    , selectedToken = nextSelection
    }
  where
  nextSelection = case state.selectedToken of
    Just token | Array.elem token tokens -> Just token
    _ -> Array.head tokens

failTokenLoad :: String -> AppState -> AppState
failTokenLoad message state = state { tokens = Failure message }

selectToken :: TokenId -> AppState -> AppState
selectToken token state = state { selectedToken = Just token }
