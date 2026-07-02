module MPFS.UI.Material.SectionHeader (sectionHeader) where

import Prelude

import Data.Maybe (Maybe(..))
import Halogen.HTML as HH
import Halogen.HTML.Properties as HP

sectionHeader
  :: forall w i
   . { title :: String
     , subtitle :: Maybe String
     , actions :: Array (HH.HTML w i)
     }
  -> HH.HTML w i
sectionHeader input =
  HH.div
    [ HP.class_ (HH.ClassName "material-section-header") ]
    [ HH.div
        [ HP.class_ (HH.ClassName "material-section-header__copy") ]
        ( [ HH.h2_ [ HH.text input.title ] ]
            <> subtitleContent
        )
    , HH.div
        [ HP.class_ (HH.ClassName "material-section-header__actions") ]
        input.actions
    ]
  where
  subtitleContent = case input.subtitle of
    Nothing -> []
    Just subtitle ->
      [ HH.p_ [ HH.text subtitle ] ]
