module MPFS.App.RuntimeConfig
  ( apiBaseUrl
  , readApiBaseUrl
  , resolveBaseUrl
  ) where

import Prelude

import Data.Maybe (Maybe(..))
import Effect (Effect)

resolveBaseUrl :: Maybe String -> String
resolveBaseUrl = case _ of
  Nothing -> "/api"
  Just baseUrl -> baseUrl

readApiBaseUrl :: Effect (Maybe String)
readApiBaseUrl = readApiBaseUrlImpl Just Nothing

apiBaseUrl :: Effect String
apiBaseUrl = resolveBaseUrl <$> readApiBaseUrl

foreign import readApiBaseUrlImpl
  :: (String -> Maybe String) -> Maybe String -> Effect (Maybe String)
