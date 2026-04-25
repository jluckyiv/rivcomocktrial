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
import UI
import View exposing (View)


page : Shared.Model -> Route () -> Page Model Msg
page _ route =
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
        [ div [ Attr.class "min-h-screen flex items-center justify-center" ]
            [ div [ Attr.class "w-full max-w-sm" ]
                [ UI.card
                    [ UI.cardBody
                        [ UI.cardTitle "Admin Login"
                        , case model.error of
                            Just err ->
                                UI.error err

                            Nothing ->
                                UI.empty
                        , viewLoginForm model
                        ]
                    ]
                ]
            ]
        ]
    }


viewLoginForm : Model -> Html Msg
viewLoginForm model =
    Html.form [ Events.onSubmit SubmitLogin ]
        [ UI.textField
            { label = "Email"
            , value = model.email
            , onInput = EmailChanged
            , required = True
            }
        , UI.passwordField
            { label = "Password"
            , value = model.password
            , onInput = PasswordChanged
            }
        , div [ Attr.class "mt-4" ]
            [ UI.primaryButton
                { label = "Login", loading = model.loading }
            ]
        ]
