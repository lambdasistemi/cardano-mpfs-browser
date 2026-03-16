-- | Tests for MPF proof verification against
-- cage test vectors.
module Test.MPFS.ProofSpec (spec) where

import Prelude

import Test.Spec (Spec, describe, it)
import Test.Spec.Assertions (shouldEqual)
import MPFS.Crypto.Hash (hexToBytes, bytesToHex)
import MPFS.Proof.MPF
  ( ProofStep(..)
  , has
  , including
  )

spec :: Spec Unit
spec = describe "MPF Proof Verification" do

  it "insert into empty trie" do
    let
      key = hexToBytes "6162"
      value = hexToBytes "6364"
      proof = []
      expected =
        "5774710a4457e50a5a2ff1fe6149398617c895dd3fbd3bd8cac51ecc571f9319"
      result = including key value proof
    bytesToHex result `shouldEqual` expected

  it "insert creating fork" do
    -- Leaf step: constructor 2, fields=[skip, key, value]
    let
      key = hexToBytes "6b32"
      value = hexToBytes "7632"
      proof =
        [ Leaf
            { skip: 0
            , key:
                hexToBytes
                  "30e612d85865aaf22de5c95a43c5cbc1907323d74edcc3f2e122c385044dac2b"
            , value:
                hexToBytes
                  "ae11692325525e82337167fcfab34d45d1904ff786e2d4bf4be2d1c4878cd34c"
            }
        ]
      expected =
        "5a72ccdd24fe693d6c10aaacd4635f5daa94dbd881f3340a985634e7aaed3c7f"
      result = including key value proof
    bytesToHex result `shouldEqual` expected

  it "insert with shared prefix" do
    let
      key = hexToBytes "6b62"
      value = hexToBytes "7662"
      proof =
        [ Leaf
            { skip: 0
            , key:
                hexToBytes
                  "9e3330d3dd6f271cf17f48426f651f7b4e9cd347561c9617110a8bf998eb4930"
            , value:
                hexToBytes
                  "ac5370259669ccdf4639f09317bbb2adaa740a300a5dc98fd51912b1173155b0"
            }
        ]
      expected =
        "8ba3fb9d4d56aa4d03e3d5481e9e23ea0c87d4e9dee6debd9cf268b462b61f74"
      result = including key value proof
    bytesToHex result `shouldEqual` expected

  it "inclusion proof for middle key" do
    let
      key = hexToBytes "79"
      value = hexToBytes "32"
      root =
        hexToBytes
          "91db563fdb311ea17481d01600e08179f6393a9c0e0c8cec41ffb9d8eaba9327"
      proof =
        [ Branch
            { skip: 0
            , neighbors:
                hexToBytes
                  "9c7a465e42fff5f33d830117491d1754e12a901d4f0a6ce156f0d1da2a69b66996137bd9a8bdc4452f60cb31222fb2742a3f0b5ef9189188d06221c8153f7dc40eb923b0cbd24df54401d998531feead35a47a99f4deed205de4af81120f97610000000000000000000000000000000000000000000000000000000000000000"
            }
        ]
    has root key value proof
      `shouldEqual` true
