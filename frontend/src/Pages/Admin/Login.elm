module Pages.Admin.Login exposing (Model, Msg, page)

import Dict
import Effect exposing (Effect)
import Html exposing (..)
import Html.Attributes as Attr
import Html.Events as Events
import Json.Decode
import Page exposing (Page)
import Pb
import Route exposing (Route)
import Route.Path
import Shared
import Shared.Msg
import View exposing (View)


page : Shared.Model -> Route () -> Page Model Msg
page shared route =
    Page.new
        { init = init route
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
    , redirectPath : Maybe Route.Path.Path
    }


init :
    Route ()
    -> ()
    -> ( Model, Effect Msg )
init route _ =
    ( { email = ""
      , password = ""
      , error = Nothing
      , loading = False
      , redirectPath =
            Dict.get "redirect" route.query
                |> Maybe.andThen Route.Path.fromString
      }
    , Effect.none
    )



-- UPDATE


type Msg
    = EmailChanged String
    | PasswordChanged String
    | SubmitLogin
    | PbMsg Json.Decode.Value


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
            , Pb.adminLogin
                { email = model.email
                , password = model.password
                , tag = "admin-login"
                }
            )

        PbMsg value ->
            case Pb.responseTag value of
                Just "admin-login" ->
                    case Pb.decodeToken value of
                        Ok token ->
                            ( { model | loading = False }
                            , Effect.sendSharedMsg
                                (Shared.Msg.AdminLoggedIn
                                    { token = token
                                    , redirect =
                                        model.redirectPath
                                    }
                                )
                            )

                        Err _ ->
                            ( { model
                                | loading = False
                                , error =
                                    Just
                                        "Invalid email or password."
                              }
                            , Effect.none
                            )

                _ ->
                    ( model, Effect.none )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    Pb.subscribe PbMsg



-- VIEW


view : Model -> View Msg
view model =
    { title = "Admin Login"
    , body =
        [ section [ Attr.class "hero is-fullheight" ]
            [ div [ Attr.class "hero-body" ]
                [ div [ Attr.class "container" ]
                    [ div
                        [ Attr.class "columns is-centered"
                        ]
                        [ div [ Attr.class "column is-4" ]
                            [ h1
                                [ Attr.class
                                    "title has-text-centered"
                                ]
                                [ text "Admin Login" ]
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
                div
                    [ Attr.class "notification is-danger"
                    ]
                    [ text err ]

            Nothing ->
                text ""
        , div [ Attr.class "field" ]
            [ label [ Attr.class "label" ]
                [ text "Email" ]
            , div [ Attr.class "control" ]
                [ input
                    [ Attr.class "input"
                    , Attr.type_ "email"
                    , Attr.placeholder
                        "admin@example.com"
                    , Attr.value model.email
                    , Events.onInput EmailChanged
                    ]
                    []
                ]
            ]
        , div [ Attr.class "field" ]
            [ label [ Attr.class "label" ]
                [ text "Password" ]
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
