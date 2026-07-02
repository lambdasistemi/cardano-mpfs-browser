module Test.MPFS.MaterialTextSpec (spec) where

import Prelude

import Data.Maybe (Maybe(..))
import MPFS.UI.Material.Text (decodeHexUtf8, truncateMiddle)
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

  it "decodes printable hex-encoded UTF-8 text" do
    decodeHexUtf8 "7b2274797065223a22636f6e666967227d" `shouldEqual` Just "{\"type\":\"config\"}"
    decodeHexUtf8 "7b226b6579223a2276616c7565227d" `shouldEqual` Just "{\"key\":\"value\"}"

  it "rejects hashes, malformed hex, and non-printable decoded bytes" do
    decodeHexUtf8 "976821" `shouldEqual` Nothing
    decodeHexUtf8 "abc" `shouldEqual` Nothing
    decodeHexUtf8 "zz" `shouldEqual` Nothing
    decodeHexUtf8 "00" `shouldEqual` Nothing
