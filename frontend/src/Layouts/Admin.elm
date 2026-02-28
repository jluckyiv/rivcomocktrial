module Layouts.Admin exposing (Model, Msg, Props, layout)

import Auth
import Effect exposing (Effect)
import Html exposing (..)
import Html.Attributes as Attr
import Html.Events as Events
import Layout exposing (Layout)
import Route exposing (Route)
import Route.Path
import Shared
import Shared.Msg
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
    { burgerOpen : Bool
    }


init : () -> ( Model, Effect Msg )
init _ =
    ( { burgerOpen = False }
    , Effect.none
    )



-- UPDATE


type Msg
    = ToggleBurger
    | Logout


update : Msg -> Model -> ( Model, Effect Msg )
update msg model =
    case msg of
        ToggleBurger ->
            ( { model | burgerOpen = not model.burgerOpen }
            , Effect.none
            )

        Logout ->
            ( model
            , Effect.sendSharedMsg Shared.Msg.AdminLoggedOut
            )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none



-- VIEW


view : Route () -> { toContentMsg : Msg -> contentMsg, content : View contentMsg, model : Model } -> View contentMsg
view route { toContentMsg, content, model } =
    { title = content.title ++ " | Admin"
    , body =
        [ Html.map toContentMsg (viewNavbar model route)
        , div [ Attr.class "section" ]
            [ div [ Attr.class "container" ]
                content.body
            ]
        ]
    }


viewNavbar : Model -> Route () -> Html Msg
viewNavbar model route =
    nav [ Attr.class "navbar is-dark", Attr.attribute "role" "navigation" ]
        [ div [ Attr.class "navbar-brand" ]
            [ a [ Attr.class "navbar-item", Route.Path.href Route.Path.Home_ ]
                [ strong [] [ text "RCMT Admin" ] ]
            , a
                [ Attr.class
                    (if model.burgerOpen then
                        "navbar-burger is-active"

                     else
                        "navbar-burger"
                    )
                , Events.onClick ToggleBurger
                , Attr.attribute "role" "button"
                , Attr.attribute "aria-label" "menu"
                ]
                [ span [] [], span [] [], span [] [], span [] [] ]
            ]
        , div
            [ Attr.class
                (if model.burgerOpen then
                    "navbar-menu is-active"

                 else
                    "navbar-menu"
                )
            ]
            [ div [ Attr.class "navbar-start" ]
                [ navLink route Route.Path.Admin_Tournaments "Tournaments"
                , navLink route Route.Path.Admin_Schools "Schools"
                , navLink route Route.Path.Admin_Teams "Teams"
                , navLink route Route.Path.Admin_Students "Students"
                , navLink route Route.Path.Admin_Courtrooms "Courtrooms"
                , navLink route Route.Path.Admin_Rounds "Rounds"
                ]
            , div [ Attr.class "navbar-end" ]
                [ div [ Attr.class "navbar-item" ]
                    [ button [ Attr.class "button is-light is-small", Events.onClick Logout ]
                        [ text "Logout" ]
                    ]
                ]
            ]
        ]


navLink : Route () -> Route.Path.Path -> String -> Html Msg
navLink route path label =
    a
        [ Attr.class
            (if route.path == path then
                "navbar-item is-active"

             else
                "navbar-item"
            )
        , Route.Path.href path
        ]
        [ text label ]
