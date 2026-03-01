module Side exposing (Side(..), toString)


type Side
    = Prosecution
    | Defense


toString : Side -> String
toString side =
    case side of
        Prosecution ->
            "Prosecution"

        Defense ->
            "Defense"
