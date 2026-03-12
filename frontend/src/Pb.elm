module Pb exposing
    ( adminList, adminCreate, adminUpdate, adminDelete
    , publicList, publicCreate
    , adminLogin, coachLogin
    , subscribe
    , responseTag
    , decodeList, decodeRecord, decodeDelete
    , decodeToken, decodeCoachAuth
    )

{-| Port-based PocketBase client.

All PB operations go through the JS SDK via ports.
See ADR-010 in docs/decisions.md for rationale.

-}

import Effect exposing (Effect)
import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode



-- ADMIN CRUD


adminList :
    { collection : String
    , tag : String
    , filter : String
    , sort : String
    }
    -> Effect msg
adminList config =
    pbSend "list"
        ([ ( "collection"
           , Encode.string config.collection
           )
         , ( "tag", Encode.string config.tag )
         , ( "admin", Encode.bool True )
         ]
            ++ optionalString "filter" config.filter
            ++ optionalString "sort" config.sort
        )


adminCreate :
    { collection : String
    , tag : String
    , body : Encode.Value
    }
    -> Effect msg
adminCreate config =
    pbSend "create"
        [ ( "collection"
          , Encode.string config.collection
          )
        , ( "tag", Encode.string config.tag )
        , ( "admin", Encode.bool True )
        , ( "body", config.body )
        ]


adminUpdate :
    { collection : String
    , id : String
    , tag : String
    , body : Encode.Value
    }
    -> Effect msg
adminUpdate config =
    pbSend "update"
        [ ( "collection"
          , Encode.string config.collection
          )
        , ( "tag", Encode.string config.tag )
        , ( "admin", Encode.bool True )
        , ( "id", Encode.string config.id )
        , ( "body", config.body )
        ]


adminDelete :
    { collection : String
    , id : String
    , tag : String
    }
    -> Effect msg
adminDelete config =
    pbSend "delete"
        [ ( "collection"
          , Encode.string config.collection
          )
        , ( "tag", Encode.string config.tag )
        , ( "admin", Encode.bool True )
        , ( "id", Encode.string config.id )
        ]



-- PUBLIC CRUD


publicList :
    { collection : String
    , tag : String
    , filter : String
    , sort : String
    }
    -> Effect msg
publicList config =
    pbSend "list"
        ([ ( "collection"
           , Encode.string config.collection
           )
         , ( "tag", Encode.string config.tag )
         , ( "admin", Encode.bool False )
         ]
            ++ optionalString "filter" config.filter
            ++ optionalString "sort" config.sort
        )


publicCreate :
    { collection : String
    , tag : String
    , body : Encode.Value
    }
    -> Effect msg
publicCreate config =
    pbSend "create"
        [ ( "collection"
          , Encode.string config.collection
          )
        , ( "tag", Encode.string config.tag )
        , ( "admin", Encode.bool False )
        , ( "body", config.body )
        ]



-- AUTH


adminLogin :
    { email : String
    , password : String
    , tag : String
    }
    -> Effect msg
adminLogin config =
    pbSend "adminLogin"
        [ ( "email", Encode.string config.email )
        , ( "password", Encode.string config.password )
        , ( "tag", Encode.string config.tag )
        ]


coachLogin :
    { email : String
    , password : String
    , tag : String
    }
    -> Effect msg
coachLogin config =
    pbSend "coachLogin"
        [ ( "email", Encode.string config.email )
        , ( "password", Encode.string config.password )
        , ( "tag", Encode.string config.tag )
        ]



-- SUBSCRIPTION


subscribe : (Decode.Value -> msg) -> Sub msg
subscribe =
    Effect.incoming



-- RESPONSE DECODERS


responseTag : Decode.Value -> Maybe String
responseTag value =
    Decode.decodeValue
        (Decode.field "tag" Decode.string)
        value
        |> Result.toMaybe


decodeList :
    Decoder a
    -> Decode.Value
    -> Result String (List a)
decodeList decoder value =
    case decodeError value of
        Just err ->
            Err err

        Nothing ->
            Decode.decodeValue
                (Decode.at [ "data", "items" ]
                    (Decode.list decoder)
                )
                value
                |> Result.mapError Decode.errorToString


decodeRecord :
    Decoder a
    -> Decode.Value
    -> Result String a
decodeRecord decoder value =
    case decodeError value of
        Just err ->
            Err err

        Nothing ->
            Decode.decodeValue
                (Decode.field "data" decoder)
                value
                |> Result.mapError Decode.errorToString


decodeDelete : Decode.Value -> Result String String
decodeDelete value =
    case decodeError value of
        Just err ->
            Err err

        Nothing ->
            Decode.decodeValue
                (Decode.at [ "data", "id" ] Decode.string)
                value
                |> Result.mapError Decode.errorToString


decodeToken : Decode.Value -> Result String String
decodeToken value =
    case decodeError value of
        Just err ->
            Err err

        Nothing ->
            Decode.decodeValue
                (Decode.at [ "data", "token" ]
                    Decode.string
                )
                value
                |> Result.mapError Decode.errorToString


decodeCoachAuth :
    Decoder a
    -> Decode.Value
    -> Result String { token : String, record : a }
decodeCoachAuth decoder value =
    case decodeError value of
        Just err ->
            Err err

        Nothing ->
            Decode.decodeValue
                (Decode.field "data"
                    (Decode.map2
                        (\t r ->
                            { token = t, record = r }
                        )
                        (Decode.field "token"
                            Decode.string
                        )
                        (Decode.field "record" decoder)
                    )
                )
                value
                |> Result.mapError Decode.errorToString



-- INTERNAL


pbSend :
    String
    -> List ( String, Encode.Value )
    -> Effect msg
pbSend action fields =
    Effect.portSend
        { tag = "PbSend"
        , data =
            Encode.object
                (( "action", Encode.string action )
                    :: fields
                )
        }


optionalString :
    String
    -> String
    -> List ( String, Encode.Value )
optionalString key val =
    if String.isEmpty val then
        []

    else
        [ ( key, Encode.string val ) ]


decodeError : Decode.Value -> Maybe String
decodeError value =
    Decode.decodeValue
        (Decode.field "error" Decode.string)
        value
        |> Result.toMaybe
