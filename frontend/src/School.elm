module School exposing (Name(..), School)

import District exposing (District)


type Name
    = Name String


type alias School =
    { name : Name
    , district : District
    }
