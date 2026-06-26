module MPFS.UI.Remote
  ( Remote(..)
  , remoteStatus
  ) where

import Prelude

data Remote a
  = NotAsked
  | Loading
  | Failure String
  | Success a

derive instance Eq a => Eq (Remote a)

instance Show a => Show (Remote a) where
  show = case _ of
    NotAsked -> "NotAsked"
    Loading -> "Loading"
    Failure msg -> "(Failure " <> show msg <> ")"
    Success value -> "(Success " <> show value <> ")"

remoteStatus :: forall a. Remote a -> String
remoteStatus = case _ of
  NotAsked -> "Not loaded"
  Loading -> "Loading"
  Failure _ -> "Error"
  Success _ -> "Ready"
