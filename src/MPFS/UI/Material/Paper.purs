module MPFS.UI.Material.Paper (paper) where

import Halogen.HTML as HH
import Halogen.HTML.Properties as HP

paper :: forall w i. Array (HH.HTML w i) -> HH.HTML w i
paper children =
  HH.section
    [ HP.class_ (HH.ClassName "material-paper") ]
    children
