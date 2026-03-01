module District exposing
    ( District
    , Name
    , create
    , districtName
    , nameFromString
    , nameToString
    )

import Error exposing (Error(..))
import Validate


type Name
    = Name String


nameFromString : String -> Result (List Error) Name
nameFromString raw =
    let
        trimmed =
            String.trim raw
    in
    Validate.validate
        (Validate.all
            [ Validate.ifBlank identity
                (Error "District name cannot be blank")
            ]
        )
        trimmed
        |> Result.map (\_ -> Name trimmed)


nameToString : Name -> String
nameToString (Name s) =
    s


type District
    = District { name : Name }


create : Name -> District
create n =
    District { name = n }


districtName : District -> Name
districtName (District r) =
    r.name
