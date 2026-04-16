module Shared exposing
    ( Flags, decoder
    , Model, Msg
    , init, update, subscriptions
    )

import Effect exposing (Effect)
import Json.Decode
import Route exposing (Route)
import Route.Path
import Shared.Model exposing (CoachAuth(..))
import Shared.Msg



-- FLAGS


type alias Flags =
    { adminToken : Maybe String
    , coachToken : Maybe String
    , coachUser : Maybe Shared.Model.CoachUser
    }


decoder : Json.Decode.Decoder Flags
decoder =
    Json.Decode.map3 Flags
        (Json.Decode.field "adminToken"
            (Json.Decode.nullable Json.Decode.string)
        )
        (Json.Decode.field "coachToken"
            (Json.Decode.nullable Json.Decode.string)
        )
        (Json.Decode.field "coachUser"
            (Json.Decode.nullable coachUserDecoder)
        )


coachUserDecoder :
    Json.Decode.Decoder Shared.Model.CoachUser
coachUserDecoder =
    Json.Decode.map3 Shared.Model.CoachUser
        (Json.Decode.field "id" Json.Decode.string)
        (Json.Decode.field "email" Json.Decode.string)
        (Json.Decode.field "name" Json.Decode.string)



-- INIT


type alias Model =
    Shared.Model.Model


init :
    Result Json.Decode.Error Flags
    -> Route ()
    -> ( Model, Effect Msg )
init flagsResult route =
    let
        flags =
            case flagsResult of
                Ok f ->
                    f

                Err _ ->
                    { adminToken = Nothing
                    , coachToken = Nothing
                    , coachUser = Nothing
                    }

        coachAuth =
            case ( flags.coachToken, flags.coachUser ) of
                ( Just token, Just user ) ->
                    LoggedIn { token = token, user = user }

                _ ->
                    NotLoggedIn
    in
    ( { adminToken = flags.adminToken
      , coachAuth = coachAuth
      }
    , Effect.none
    )



-- UPDATE


type alias Msg =
    Shared.Msg.Msg


update : Route () -> Msg -> Model -> ( Model, Effect Msg )
update route msg model =
    case msg of
        Shared.Msg.AdminLoggedIn token ->
            ( { model | adminToken = Just token }
            , Effect.batch
                [ Effect.saveAdminToken (Just token)
                , Effect.pushRoutePath
                    Route.Path.Admin_Tournaments
                ]
            )

        Shared.Msg.AdminLoggedOut ->
            ( { model | adminToken = Nothing }
            , Effect.batch
                [ Effect.saveAdminToken Nothing
                , Effect.pushRoutePath Route.Path.Home_
                ]
            )

        Shared.Msg.CoachLoggedIn credentials ->
            ( { model | coachAuth = LoggedIn credentials }
            , Effect.batch
                [ Effect.saveCoachToken
                    (Just credentials.token)
                , Effect.saveCoachUser
                    (Just credentials.user)
                , Effect.pushRoutePath
                    Route.Path.Team_Manage
                ]
            )

        Shared.Msg.CoachLoggedOut ->
            ( { model | coachAuth = NotLoggedIn }
            , Effect.batch
                [ Effect.saveCoachToken Nothing
                , Effect.saveCoachUser Nothing
                , Effect.pushRoutePath Route.Path.Home_
                ]
            )



-- SUBSCRIPTIONS


subscriptions : Route () -> Model -> Sub Msg
subscriptions route model =
    Sub.none
