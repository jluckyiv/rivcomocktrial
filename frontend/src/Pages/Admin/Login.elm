module Pages.Admin.Login exposing (Model, Msg, page)

import Api
import Effect exposing (Effect)
import Html exposing (..)
import Html.Attributes as Attr
import Html.Events as Events
import Http
import Page exposing (Page)
import Route exposing (Route)
import Shared
import Shared.Msg
import View exposing (View)


page : Shared.Model -> Route () -> Page Model Msg
page shared route =
    Page.new
        { init = init
        , update = update
        , view = view
        , subscriptions = subscriptions
        }



-- MODEL


type alias Model =
    { email : String
    , password : String
    , error : Maybe String
    , loading : Bool
    }


init : () -> ( Model, Effect Msg )
init _ =
    ( { email = ""
      , password = ""
      , error = Nothing
      , loading = False
      }
    , Effect.none
    )



-- UPDATE


type Msg
    = EmailChanged String
    | PasswordChanged String
    | SubmitLogin
    | GotLoginResponse (Result Http.Error String)


update : Msg -> Model -> ( Model, Effect Msg )
update msg model =
    case msg of
        EmailChanged email ->
            ( { model | email = email }
            , Effect.none
            )

        PasswordChanged password ->
            ( { model | password = password }
            , Effect.none
            )

        SubmitLogin ->
            ( { model | loading = True, error = Nothing }
            , Effect.sendCmd
                (Api.adminLogin
                    { email = model.email
                    , password = model.password
                    }
                    GotLoginResponse
                )
            )

        GotLoginResponse (Ok token) ->
            ( { model | loading = False }
            , Effect.sendSharedMsg (Shared.Msg.AdminLoggedIn token)
            )

        GotLoginResponse (Err _) ->
            ( { model | loading = False, error = Just "Invalid email or password." }
            , Effect.none
            )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none



-- VIEW


view : Model -> View Msg
view model =
    { title = "Admin Login"
    , body =
        [ section [ Attr.class "hero is-fullheight" ]
            [ div [ Attr.class "hero-body" ]
                [ div [ Attr.class "container" ]
                    [ div [ Attr.class "columns is-centered" ]
                        [ div [ Attr.class "column is-4" ]
                            [ h1 [ Attr.class "title has-text-centered" ] [ text "Admin Login" ]
                            , viewLoginForm model
                            ]
                        ]
                    ]
                ]
            ]
        ]
    }


viewLoginForm : Model -> Html Msg
viewLoginForm model =
    Html.form [ Events.onSubmit SubmitLogin ]
        [ case model.error of
            Just err ->
                div [ Attr.class "notification is-danger" ] [ text err ]

            Nothing ->
                text ""
        , div [ Attr.class "field" ]
            [ label [ Attr.class "label" ] [ text "Email" ]
            , div [ Attr.class "control" ]
                [ input
                    [ Attr.class "input"
                    , Attr.type_ "email"
                    , Attr.placeholder "admin@example.com"
                    , Attr.value model.email
                    , Events.onInput EmailChanged
                    ]
                    []
                ]
            ]
        , div [ Attr.class "field" ]
            [ label [ Attr.class "label" ] [ text "Password" ]
            , div [ Attr.class "control" ]
                [ input
                    [ Attr.class "input"
                    , Attr.type_ "password"
                    , Attr.value model.password
                    , Events.onInput PasswordChanged
                    ]
                    []
                ]
            ]
        , div [ Attr.class "field" ]
            [ div [ Attr.class "control" ]
                [ button
                    [ Attr.class
                        (if model.loading then
                            "button is-primary is-fullwidth is-loading"

                         else
                            "button is-primary is-fullwidth"
                        )
                    , Attr.type_ "submit"
                    , Attr.disabled model.loading
                    ]
                    [ text "Login" ]
                ]
            ]
        ]
