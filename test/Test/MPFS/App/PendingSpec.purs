module Test.MPFS.App.PendingSpec (spec) where

import Prelude

import Data.Maybe (Maybe(..))
import MPFS.App.Facts (RequestPhase(..))
import MPFS.App.Pending
  ( RetractDecision(..)
  , opChipTone
  , phaseChipTone
  , retractDecision
  )
import MPFS.UI.Material.Chip as Chip
import Test.Spec (Spec, describe, it)
import Test.Spec.Assertions (shouldEqual)

spec :: Spec Unit
spec = describe "MPFS App Pending" do
  describe "retract gating" do
    it "enables retract only for the requester during the retractable phase" do
      retractDecision PhaseRetractable "requester" (Just "requester")
        `shouldEqual`
          RetractEnabled

    it "requires a connected wallet before retracting" do
      retractDecision PhaseRetractable "requester" Nothing
        `shouldEqual`
          RetractDisabled "Connect a wallet to retract"

    it "requires the connected wallet to match the requester" do
      retractDecision PhaseRetractable "requester" (Just "other")
        `shouldEqual`
          RetractDisabled "Only the requester may retract"

    it "keeps processable requests inert until the process window closes" do
      retractDecision PhaseProcessable "requester" (Just "requester")
        `shouldEqual`
          RetractDisabled "Retract opens after the process window"

    it "keeps expired requests inert after the retract window closes" do
      retractDecision PhaseExpired "requester" (Just "requester")
        `shouldEqual`
          RetractDisabled "Retract window has closed"

  describe "chip tones" do
    it "maps operation chips to the design tones" do
      isSuccess (opChipTone "insert") `shouldEqual` true
      isPrimary (opChipTone "update") `shouldEqual` true
      isError (opChipTone "delete") `shouldEqual` true
      isNeutral (opChipTone "unknown") `shouldEqual` true

    it "maps phase chips to the design tones" do
      isPrimary (phaseChipTone PhaseProcessable) `shouldEqual` true
      isWarning (phaseChipTone PhaseRetractable) `shouldEqual` true
      isNeutral (phaseChipTone PhaseExpired) `shouldEqual` true

isPrimary :: Chip.ChipTone -> Boolean
isPrimary = case _ of
  Chip.ChipPrimary -> true
  _ -> false

isSuccess :: Chip.ChipTone -> Boolean
isSuccess = case _ of
  Chip.ChipSuccess -> true
  _ -> false

isWarning :: Chip.ChipTone -> Boolean
isWarning = case _ of
  Chip.ChipWarning -> true
  _ -> false

isError :: Chip.ChipTone -> Boolean
isError = case _ of
  Chip.ChipError -> true
  _ -> false

isNeutral :: Chip.ChipTone -> Boolean
isNeutral = case _ of
  Chip.ChipNeutral -> true
  _ -> false
