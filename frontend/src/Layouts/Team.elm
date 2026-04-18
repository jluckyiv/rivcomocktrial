module Layouts.Team exposing (Model, Msg, Props, layout)

import Auth
import Effect exposing (Effect)
import Html exposing (..)
import Html.Attributes as Attr
import Html.Events as Events
import Layout exposing (Layout)
import Route exposing (Route)
import Route.Path
import Shared
import Shared.Model exposing (CoachAuth(..))
import Shared.Msg
import View exposing (View)


type alias Props =
    {}


layout : Props -> Shared.Model -> Route () -> Layout () Model Msg contentMsg
layout props shared route =
    Layout.new
        { init = init
        , update = update
        , view = view shared route
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
            , Effect.sendSharedMsg Shared.Msg.CoachLoggedOut
            )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none



-- VIEW


view :
    Shared.Model
    -> Route ()
    ->
        { toContentMsg : Msg -> contentMsg
        , content : View contentMsg
        , model : Model
        }
    -> View contentMsg
view shared route { toContentMsg, content, model } =
    { title = content.title ++ " | Team"
    , body =
        [ Html.map toContentMsg
            (viewNavbar shared model route)
        , main_ [ Attr.class "p-6" ]
            [ div [ Attr.class "max-w-4xl mx-auto" ]
                content.body
            ]
        ]
    }


viewNavbar :
    Shared.Model
    -> Model
    -> Route ()
    -> Html Msg
viewNavbar shared model route =
    let
        displayName =
            case shared.coachAuth of
                LoggedIn credentials ->
                    credentials.user.name

                _ ->
                    "Coach"
    in
    nav [ Attr.class "navbar bg-info text-info-content shadow-sm" ]
        [ div [ Attr.class "navbar-start" ]
            [ div [ Attr.class "dropdown" ]
                [ button
                    [ Attr.class "btn btn-ghost btn-square lg:hidden"
                    , Events.onClick ToggleBurger
                    , Attr.attribute "aria-label" "menu"
                    ]
                    [ Html.node "svg"
                        [ Attr.class "h-5 w-5"
                        , Attr.attribute "xmlns" "http://www.w3.org/2000/svg"
                        , Attr.attribute "fill" "none"
                        , Attr.attribute "viewBox" "0 0 24 24"
                        , Attr.attribute "stroke" "currentColor"
                        ]
                        [ Html.node "path"
                            [ Attr.attribute "stroke-linecap" "round"
                            , Attr.attribute "stroke-linejoin" "round"
                            , Attr.attribute "stroke-width" "2"
                            , Attr.attribute "d" "M4 6h16M4 12h16M4 18h16"
                            ]
                            []
                        ]
                    ]
                , if model.burgerOpen then
                    ul [ Attr.class "menu menu-sm dropdown-content bg-info text-info-content mt-3 z-10 w-52 p-2 shadow-lg rounded-box" ]
                        [ navItem route Route.Path.Team_Manage "Eligible Students"
                        , navItem route Route.Path.Team_Rosters "Rosters"
                        ]

                  else
                    text ""
                ]
            , a [ Attr.class "btn btn-ghost text-base font-bold normal-case", Route.Path.href Route.Path.Home_ ]
                [ text displayName ]
            ]
        , div [ Attr.class "navbar-center hidden lg:flex" ]
            [ ul [ Attr.class "menu menu-horizontal px-1" ]
                [ navItem route Route.Path.Team_Manage "Eligible Students"
                , navItem route Route.Path.Team_Rosters "Rosters"
                ]
            ]
        , div [ Attr.class "navbar-end" ]
            [ button
                [ Attr.class "btn btn-ghost btn-sm"
                , Events.onClick Logout
                ]
                [ text "Logout" ]
            ]
        ]


navItem : Route () -> Route.Path.Path -> String -> Html Msg
navItem route path label =
    li []
        [ a
            [ Route.Path.href path
            , Attr.class
                (if route.path == path then
                    "active"

                 else
                    ""
                )
            ]
            [ text label ]
        ]
