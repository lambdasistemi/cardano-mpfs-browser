module MPFS.UI.Material.DataTable
  ( Column
  , TableRow
  , dataTable
  , rowCount
  ) where

import Prelude

import Data.Array as Array
import Data.Maybe (Maybe(..))
import Halogen.HTML as HH
import Halogen.HTML.Properties as HP

type Column =
  { key :: String
  , label :: String
  }

type TableRow w i =
  { key :: String
  , cells :: Array (HH.HTML w i)
  }

rowCount :: forall a. Array a -> Int
rowCount = Array.length

dataTable
  :: forall w i
   . { columns :: Array Column
     , rows :: Array (TableRow w i)
     , maxHeight :: Maybe String
     }
  -> HH.HTML w i
dataTable input =
  HH.div
    [ HP.classes containerClasses
    , HP.attr (HH.AttrName "data-row-count") (show (rowCount input.rows))
    , HP.style containerStyle
    ]
    [ HH.table
        [ HP.class_ (HH.ClassName "material-data-table") ]
        [ HH.thead_
            [ HH.tr_ (map renderHeader input.columns) ]
        , HH.tbody_ (map renderRow input.rows)
        ]
    ]
  where
  containerClasses =
    [ HH.ClassName "material-data-table-container" ]

  containerStyle = case input.maxHeight of
    Nothing -> ""
    Just height -> "max-height: " <> height

renderHeader :: forall w i. Column -> HH.HTML w i
renderHeader column =
  HH.th
    [ HP.attr (HH.AttrName "scope") "col"
    , HP.attr (HH.AttrName "data-column") column.key
    ]
    [ HH.text column.label ]

renderRow :: forall w i. TableRow w i -> HH.HTML w i
renderRow row =
  HH.tr
    [ HP.attr (HH.AttrName "data-row") row.key ]
    (map renderCell row.cells)

renderCell :: forall w i. HH.HTML w i -> HH.HTML w i
renderCell cell =
  HH.td_ [ cell ]
