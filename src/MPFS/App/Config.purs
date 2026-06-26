module MPFS.App.Config
  ( defaultCageConfig
  , preprodCageConfig
  ) where

import MPFS.Types (CageConfig)

defaultCageConfig :: CageConfig
defaultCageConfig = preprodCageConfig

preprodCageConfig :: CageConfig
preprodCageConfig =
  { cageScriptBytes: "__MPFS_CAGE_SCRIPT_BYTES__"
  , requestScriptBytes: "__MPFS_REQUEST_SCRIPT_BYTES__"
  , cfgScriptHash: "__MPFS_CAGE_SCRIPT_HASH__"
  , defaultProcessTime: 1800000
  , defaultRetractTime: 1800000
  , defaultTip: 2000000
  , network: "preprod"
  }
