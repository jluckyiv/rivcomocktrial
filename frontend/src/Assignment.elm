module Assignment exposing
    ( Assignment(..)
    , isAssigned
    , toMaybe
    )


type Assignment a
    = NotAssigned
    | Assigned a


isAssigned : Assignment a -> Bool
isAssigned assignment =
    case assignment of
        NotAssigned ->
            False

        Assigned _ ->
            True


toMaybe : Assignment a -> Maybe a
toMaybe assignment =
    case assignment of
        NotAssigned ->
            Nothing

        Assigned a ->
            Just a
