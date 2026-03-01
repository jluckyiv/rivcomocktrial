module Name exposing (Name)


type alias Name =
    { first : String
    , last : String
    , preferred : Maybe String
    }
