module Layouts.Public exposing (Model, Msg, Props, layout)

import Effect exposing (Effect)
import Html exposing (..)
import Html.Attributes as Attr
import Layout exposing (Layout)
import Route exposing (Route)
import Route.Path
import Shared
import View exposing (View)


type alias Props =
    {}


layout : Props -> Shared.Model -> Route () -> Layout () Model Msg contentMsg
layout props shared route =
    Layout.new
        { init = init
        , update = update
        , view = view route
        , subscriptions = subscriptions
        }



-- MODEL


type alias Model =
    {}


init : () -> ( Model, Effect Msg )
init _ =
    ( {}
    , Effect.none
    )



-- UPDATE


type Msg
    = NoOp


update : Msg -> Model -> ( Model, Effect Msg )
update msg model =
    ( model, Effect.none )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none



-- VIEW


view : Route () -> { toContentMsg : Msg -> contentMsg, content : View contentMsg, model : Model } -> View contentMsg
view route { toContentMsg, content, model } =
    { title = content.title ++ " | Riverside County Mock Trial"
    , body =
        [ viewNavbar route
        , div [ Attr.class "section" ]
            [ div [ Attr.class "container" ]
                content.body
            ]
        ]
    }


viewNavbar : Route () -> Html msg
viewNavbar route =
    nav [ Attr.class "navbar is-primary", Attr.attribute "role" "navigation" ]
        [ div [ Attr.class "navbar-brand" ]
            [ a [ Attr.class "navbar-item", Route.Path.href Route.Path.Home_ ]
                [ strong [] [ text "Riverside County Mock Trial" ] ]
            ]
        , div [ Attr.class "navbar-menu" ]
            [ div [ Attr.class "navbar-start" ]
                [ a
                    [ Attr.class "navbar-item"
                    , Route.Path.href Route.Path.Register
                    ]
                    [ text "Register" ]
                ]
            , div [ Attr.class "navbar-end" ]
                [ div [ Attr.class "navbar-item" ]
                    [ div [ Attr.class "buttons" ]
                        [ a
                            [ Attr.class
                                "button is-info is-small"
                            , Route.Path.href
                                Route.Path.Team_Login
                            ]
                            [ text "Coach Login" ]
                        , a
                            [ Attr.class
                                "button is-light is-small"
                            , Route.Path.href
                                Route.Path.Admin_Login
                            ]
                            [ text "Admin" ]
                        ]
                    ]
                ]
            ]
        ]
