module Student exposing
    ( Name
    , Pronouns(..)
    , Student
    , displayName
    , fullName
    , pronounsToString
    )


type alias Name =
    { first : String
    , last : String
    , preferred : Maybe String
    }


type Pronouns
    = HeHim
    | SheHer
    | TheyThem
    | Other String


type alias Student =
    { name : Name
    , pronouns : Pronouns
    }


displayName : Name -> String
displayName name =
    Maybe.withDefault name.first name.preferred


fullName : Name -> String
fullName name =
    displayName name ++ " " ++ name.last


pronounsToString : Pronouns -> String
pronounsToString pronouns =
    case pronouns of
        HeHim ->
            "he/him"

        SheHer ->
            "she/her"

        TheyThem ->
            "they/them"

        Other custom ->
            custom
