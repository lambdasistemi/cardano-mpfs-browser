module Test.TokensSpec (spec) where

import Prelude

import Data.Maybe (Maybe(..))
import MPFS.App.State (defaultState)
import MPFS.App.Tokens
  ( failTokenLoad
  , finishTokenLoad
  , selectToken
  , startTokenLoad
  )
import MPFS.Types (TokenId(..))
import MPFS.UI.Remote (Remote(..))
import Test.Spec (Spec, describe, it)
import Test.Spec.Assertions (shouldEqual)

spec :: Spec Unit
spec = describe "MPFS App Tokens" do
  it "marks tokens as loading without changing the selected token" do
    let
      selected = TokenId "existing"
      state = defaultState { selectedToken = Just selected }
      next = startTokenLoad state

    next.tokens `shouldEqual` Loading
    next.selectedToken `shouldEqual` Just selected

  it "stores loaded tokens and selects the first token when none is selected" do
    let
      alpha = TokenId "alpha"
      beta = TokenId "beta"
      next = finishTokenLoad [ alpha, beta ] defaultState

    next.tokens `shouldEqual` Success [ alpha, beta ]
    next.selectedToken `shouldEqual` Just alpha

  it "preserves an existing selected token when it is still present" do
    let
      alpha = TokenId "alpha"
      beta = TokenId "beta"
      state = defaultState { selectedToken = Just beta }
      next = finishTokenLoad [ alpha, beta ] state

    next.tokens `shouldEqual` Success [ alpha, beta ]
    next.selectedToken `shouldEqual` Just beta

  it "selects a token without changing the loaded token list" do
    let
      alpha = TokenId "alpha"
      beta = TokenId "beta"
      state = defaultState { tokens = Success [ alpha, beta ] }
      next = selectToken beta state

    next.tokens `shouldEqual` Success [ alpha, beta ]
    next.selectedToken `shouldEqual` Just beta

  it "stores a load failure without clearing the selected token" do
    let
      selected = TokenId "existing"
      state = defaultState { selectedToken = Just selected }
      next = failTokenLoad "network unavailable" state

    next.tokens `shouldEqual` Failure "network unavailable"
    next.selectedToken `shouldEqual` Just selected
