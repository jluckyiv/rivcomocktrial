module School exposing (School)

import District exposing (District)


type alias School =
    { name : String
    , district : District
    }
