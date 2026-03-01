module Email exposing (Email, fromString, toString)

import Error exposing (Error(..))
import Validate


type Email
    = Email String


fromString : String -> Result (List Error) Email
fromString raw =
    let
        trimmed =
            String.trim raw
    in
    Validate.validate
        (Validate.all
            [ Validate.ifBlank identity
                (Error "Email cannot be blank")
            , Validate.ifInvalidEmail identity
                (\_ -> Error "Invalid email format")
            ]
        )
        trimmed
        |> Result.map (\_ -> Email trimmed)


toString : Email -> String
toString (Email s) =
    s
