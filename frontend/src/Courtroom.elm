module Courtroom exposing
    ( Courtroom
    , Name
    , name
    , nameToString
    )


type Name
    = Name String


type alias Courtroom =
    { name : Name
    }


name : String -> Name
name =
    Name


nameToString : Name -> String
nameToString (Name n) =
    n
