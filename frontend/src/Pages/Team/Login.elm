module Pages.Team.Login exposing (Model, Msg, page)

import Api
import Dict
import Effect exposing (Effect)
import Html exposing (..)
import Html.Attributes as Attr
import Html.Events as Events
import Json.Decode
import Layouts
import Page exposing (Page)
import Pb
import Route exposing (Route)
import Route.Path
import Shared
import Shared.Model exposing (CoachAuth(..))
import Shared.Msg
import View exposing (View)


page : Shared.Model -> Route () -> Page Model Msg
page shared route =
    Page.new
        { init = init shared route
        , update = update
        , view = view
        , subscriptions = subscriptions
        }
        |> Page.withLayout (\_ -> Layouts.Public {})



-- MODEL


type State
    = Ready
    | Submitting
    | Failed String


type alias Model =
    { email : String
    , password : String
    , state : State
    , redirectPath : Maybe Route.Path.Path
    }


init :
    Shared.Model
    -> Route ()
    -> ()
    -> ( Model, Effect Msg )
init shared route _ =
    let
        redirectPath =
            Dict.get "redirect" route.query
                |> Maybe.andThen Route.Path.fromString
    in
    case shared.coachAuth of
        LoggedIn _ ->
            ( { email = ""
              , password = ""
              , state = Ready
              , redirectPath = redirectPath
              }
            , Effect.pushRoutePath
                (redirectPath
                    |> Maybe.withDefault
                        Route.Path.Team_Manage
                )
            )

        NotLoggedIn ->
            ( { email = ""
              , password = ""
              , state = Ready
              , redirectPath = redirectPath
              }
            , Effect.none
            )



-- UPDATE


type Msg
    = UpdateEmail String
    | UpdatePassword String
    | Submit
    | PbMsg Json.Decode.Value


update : Msg -> Model -> ( Model, Effect Msg )
update msg model =
    case msg of
        UpdateEmail val ->
            ( { model | email = val }, Effect.none )

        UpdatePassword val ->
            ( { model | password = val }, Effect.none )

        Submit ->
            if
                String.isEmpty model.email
                    || String.isEmpty model.password
            then
                ( { model
                    | state =
                        Failed
                            "Please enter email and password."
                  }
                , Effect.none
                )

            else
                ( { model | state = Submitting }
                , Pb.coachLogin
                    { email = model.email
                    , password = model.password
                    , tag = "coach-login"
                    }
                )

        PbMsg value ->
            case Pb.responseTag value of
                Just "coach-login" ->
                    case Pb.decodeCoachAuth Api.coachUserDecoder value of
                        Ok response ->
                            ( model
                            , Effect.sendSharedMsg
                                (Shared.Msg.CoachLoggedIn
                                    { token = response.token
                                    , user =
                                        { id = response.record.id
                                        , email = response.record.email
                                        , name = response.record.name
                                        }
                                    , redirect =
                                        model.redirectPath
                                    }
                                )
                            )

                        Err err ->
                            ( { model
                                | state = Failed err
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
    { title = "Coach Login"
    , body =
        [ div [ Attr.class "columns is-centered" ]
            [ div [ Attr.class "column is-half" ]
                [ div [ Attr.class "box" ]
                    [ h1 [ Attr.class "title" ]
                        [ text "Coach Login" ]
                    , viewState model.state
                    , viewForm model
                    , p
                        [ Attr.class
                            "has-text-centered mt-4"
                        ]
                        [ text "Don't have an account? "
                        , a
                            [ Route.Path.href
                                Route.Path.Register_TeacherCoach
                            ]
                            [ text "Register here" ]
                        ]
                    ]
                ]
            ]
        ]
    }


viewState : State -> Html msg
viewState state =
    case state of
        Failed errorMsg ->
            div
                [ Attr.class
                    "notification is-danger is-light"
                ]
                [ text errorMsg ]

        _ ->
            text ""


viewForm : Model -> Html Msg
viewForm model =
    let
        submitting =
            case model.state of
                Submitting ->
                    True

                _ ->
                    False
    in
    Html.form [ Events.onSubmit Submit ]
        [ div [ Attr.class "field" ]
            [ label [ Attr.class "label" ]
                [ text "Email" ]
            , div [ Attr.class "control" ]
                [ input
                    [ Attr.class "input"
                    , Attr.type_ "email"
                    , Attr.placeholder "you@school.edu"
                    , Attr.value model.email
                    , Events.onInput UpdateEmail
                    , Attr.disabled submitting
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
                    , Events.onInput UpdatePassword
                    , Attr.disabled submitting
                    ]
                    []
                ]
            ]
        , div [ Attr.class "field" ]
            [ div [ Attr.class "control" ]
                [ button
                    [ Attr.class
                        (if submitting then
                            "button is-info is-fullwidth is-loading"

                         else
                            "button is-info is-fullwidth"
                        )
                    , Attr.type_ "submit"
                    , Attr.disabled submitting
                    ]
                    [ text "Login" ]
                ]
            ]
        ]
