module Shared exposing
    ( Flags, decoder
    , Model, Msg
    , init, update, subscriptions
    )

import Effect exposing (Effect)
import Json.Decode
import Route exposing (Route)
import Route.Path
import Shared.Model
import Shared.Msg



-- FLAGS


type alias Flags =
    {}


decoder : Json.Decode.Decoder Flags
decoder =
    Json.Decode.succeed {}



-- INIT


type alias Model =
    Shared.Model.Model


init : Result Json.Decode.Error Flags -> Route () -> ( Model, Effect Msg )
init flagsResult route =
    ( { adminToken = Nothing }
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
            , Effect.pushRoutePath Route.Path.Admin_Tournaments
            )

        Shared.Msg.AdminLoggedOut ->
            ( { model | adminToken = Nothing }
            , Effect.pushRoutePath Route.Path.Home_
            )



-- SUBSCRIPTIONS


subscriptions : Route () -> Model -> Sub Msg
subscriptions route model =
    Sub.none
