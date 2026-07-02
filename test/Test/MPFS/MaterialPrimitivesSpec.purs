module Test.MPFS.MaterialPrimitivesSpec (spec) where

import Prelude

import MPFS.UI.Material.DataTable as DataTable
import MPFS.UI.Material.StatusChip as StatusChip
import Test.Spec (Spec, describe, it)
import Test.Spec.Assertions (shouldEqual)

spec :: Spec Unit
spec = describe "Material primitives" do
  describe "StatusChip" do
    it "maps status tones to variant classes" do
      StatusChip.statusToneClass StatusChip.StatusOk
        `shouldEqual` "status-chip--ok"
      StatusChip.statusToneClass StatusChip.StatusWarn
        `shouldEqual` "status-chip--warn"
      StatusChip.statusToneClass StatusChip.StatusError
        `shouldEqual` "status-chip--error"
      StatusChip.statusToneClass StatusChip.StatusNeutral
        `shouldEqual` "status-chip--neutral"

  describe "DataTable" do
    it "counts one rendered row per input row" do
      DataTable.rowCount
        [ [ "token", "owner" ]
        , [ "fact", "value" ]
        , [ "request", "phase" ]
        ]
        `shouldEqual` 3
