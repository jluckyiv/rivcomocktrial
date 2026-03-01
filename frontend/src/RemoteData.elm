module RemoteData exposing
    ( RemoteData(..)
    , isLoading
    , map
    , toMaybe
    , withDefault
    )


type RemoteData a
    = NotAsked
    | Loading
    | Failed String
    | Succeeded a


isLoading : RemoteData a -> Bool
isLoading rd =
    case rd of
        Loading ->
            True

        _ ->
            False


toMaybe : RemoteData a -> Maybe a
toMaybe rd =
    case rd of
        Succeeded a ->
            Just a

        _ ->
            Nothing


map : (a -> b) -> RemoteData a -> RemoteData b
map f rd =
    case rd of
        NotAsked ->
            NotAsked

        Loading ->
            Loading

        Failed err ->
            Failed err

        Succeeded a ->
            Succeeded (f a)


withDefault : a -> RemoteData a -> a
withDefault default rd =
    case rd of
        Succeeded a ->
            a

        _ ->
            default
