module School exposing
    ( Name
    , School
    , create
    , district
    , nameFromString
    , nameToString
    , schoolName
    )

import District exposing (District)
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
                (Error "School name cannot be blank")
            ]
        )
        trimmed
        |> Result.map (\_ -> Name trimmed)


nameToString : Name -> String
nameToString (Name s) =
    s


type School
    = School { name : Name, district : District }


create : Name -> District -> School
create n d =
    School { name = n, district = d }


schoolName : School -> Name
schoolName (School r) =
    r.name


district : School -> District
district (School r) =
    r.district
