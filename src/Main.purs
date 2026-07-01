module Main where

import Prelude

import Effect (Effect)
import Effect.Class (liftEffect)
import Halogen.Aff as HA
import Halogen.VDom.Driver (runUI)
import App as App
import MPFS.App.RuntimeConfig as RuntimeConfig

main :: Effect Unit
main = HA.runHalogenAff do
  body <- HA.awaitBody
  base <- liftEffect RuntimeConfig.apiBaseUrl
  runUI App.component { baseUrl: base } body
