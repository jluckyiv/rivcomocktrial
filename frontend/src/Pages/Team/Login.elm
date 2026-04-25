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
import UI
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
        [ div [ Attr.class "flex justify-center mt-12" ]
            [ div [ Attr.class "w-full max-w-sm" ]
                [ UI.card
                    [ UI.cardBody
                        [ UI.cardTitle "Coach Login"
                        , viewState model.state
                        , viewForm model
                        , p [ Attr.class "text-center text-sm mt-4" ]
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
        ]
    }


viewState : State -> Html msg
viewState state =
    case state of
        Failed errorMsg ->
            UI.error errorMsg

        _ ->
            UI.empty


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
        [ UI.textField
            { label = "Email"
            , value = model.email
            , onInput = UpdateEmail
            , required = True
            }
        , UI.passwordField
            { label = "Password"
            , value = model.password
            , onInput = UpdatePassword
            }
        , div [ Attr.class "mt-4" ]
            [ UI.primaryButton
                { label = "Login", loading = submitting }
            ]
        ]
