module Witness exposing (Witness, create, description, name)

import Error exposing (Error(..))
import Validate


type Witness
    = Witness { name : String, description : String }


create : String -> String -> Result (List Error) Witness
create rawName rawDesc =
    let
        trimmedName =
            String.trim rawName

        trimmedDesc =
            String.trim rawDesc
    in
    Validate.validate
        (Validate.all
            [ Validate.ifBlank Tuple.first
                (Error "Witness name cannot be blank")
            , Validate.ifBlank Tuple.second
                (Error "Witness description cannot be blank")
            ]
        )
        ( trimmedName, trimmedDesc )
        |> Result.map
            (\_ ->
                Witness
                    { name = trimmedName
                    , description = trimmedDesc
                    }
            )


name : Witness -> String
name (Witness r) =
    r.name


description : Witness -> String
description (Witness r) =
    r.description
