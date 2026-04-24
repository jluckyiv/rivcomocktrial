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
layout _ _ _ =
    Layout.new
        { init = init
        , update = update
        , view = view
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
update _ model =
    ( model, Effect.none )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none



-- VIEW


view : { toContentMsg : Msg -> contentMsg, content : View contentMsg, model : Model } -> View contentMsg
view { content } =
    { title = content.title ++ " | Riverside County Mock Trial"
    , body =
        [ viewNavbar
        , main_ [ Attr.class "p-6" ]
            [ div [ Attr.class "max-w-4xl mx-auto" ]
                content.body
            ]
        ]
    }


viewNavbar : Html msg
viewNavbar =
    nav [ Attr.class "navbar bg-primary text-primary-content shadow-sm" ]
        [ div [ Attr.class "navbar-start" ]
            [ a [ Attr.class "btn btn-ghost text-base font-bold normal-case", Route.Path.href Route.Path.Home_ ]
                [ text "Riverside County Mock Trial" ]
            ]
        , div [ Attr.class "navbar-center hidden lg:flex" ]
            [ ul [ Attr.class "menu menu-horizontal px-1" ]
                [ li []
                    [ a [ Route.Path.href Route.Path.Register ]
                        [ text "Register" ]
                    ]
                ]
            ]
        , div [ Attr.class "navbar-end" ]
            [ a [ Attr.class "btn btn-sm btn-info mr-2", Route.Path.href Route.Path.Team_Login ]
                [ text "Coach Login" ]
            , a [ Attr.class "btn btn-sm btn-ghost", Route.Path.href Route.Path.Admin_Login ]
                [ text "Admin" ]
            ]
        ]
