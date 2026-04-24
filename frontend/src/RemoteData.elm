module RemoteData exposing
    ( RemoteData(..)
    , map
    )


type RemoteData a
    = Loading
    | Failed String
    | Succeeded a


map : (a -> b) -> RemoteData a -> RemoteData b
map f rd =
    case rd of
        Loading ->
            Loading

        Failed err ->
            Failed err

        Succeeded a ->
            Succeeded (f a)
