module Test.MPFS.MaterialTextSpec (spec) where

import Prelude

import MPFS.UI.Material.Text (truncateMiddle)
import Test.Spec (Spec, describe, it)
import Test.Spec.Assertions (shouldEqual)

spec :: Spec Unit
spec = describe "Material text helpers" do
  it "truncates long strings through the middle" do
    truncateMiddle 4 "0123456789abcdef" `shouldEqual` "0123…cdef"

  it "leaves short strings unchanged" do
    truncateMiddle 4 "short" `shouldEqual` "short"

  it "keeps boundary-length strings unchanged" do
    truncateMiddle 4 "012345678" `shouldEqual` "012345678"
