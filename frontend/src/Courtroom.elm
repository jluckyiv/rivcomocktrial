module Courtroom exposing
    ( Courtroom
    , Name
    , courtroomName
    , create
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
                (Error "Courtroom name cannot be blank")
            ]
        )
        trimmed
        |> Result.map (\_ -> Name trimmed)


nameToString : Name -> String
nameToString (Name s) =
    s


type Courtroom
    = Courtroom { name : Name }


create : Name -> Courtroom
create n =
    Courtroom { name = n }


courtroomName : Courtroom -> Name
courtroomName (Courtroom r) =
    r.name
