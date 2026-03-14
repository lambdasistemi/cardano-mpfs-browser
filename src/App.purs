module App where

import Prelude

import Halogen as H
import Halogen.HTML as HH

type State = {}

component :: forall q i o m. H.Component q i o m
component =
    H.mkComponent
        { initialState: const {}
        , render
        , eval: H.mkEval H.defaultEval
        }

render :: forall m. State -> H.ComponentHTML Void () m
render _ =
    HH.div_
        [ HH.h1_ [ HH.text "MPFS Explorer" ]
        , HH.p_
            [ HH.text
                "Fact explorer and transaction verifier"
            ]
        ]
