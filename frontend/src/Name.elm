module Name exposing (Name, displayName, fullName)


type alias Name =
    { first : String
    , last : String
    , preferred : Maybe String
    }


displayName : Name -> String
displayName name =
    Maybe.withDefault name.first name.preferred


fullName : Name -> String
fullName name =
    displayName name ++ " " ++ name.last
