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
        , main_ [ Attr.class "p-6" ]
            [ div [ Attr.class "max-w-6xl mx-auto" ]
                content.body
            ]
        ]
    }


viewNavbar : Model -> Route () -> Html Msg
viewNavbar model route =
    nav [ Attr.class "navbar bg-neutral text-neutral-content shadow-sm" ]
        [ div [ Attr.class "navbar-start" ]
            [ -- Mobile burger button
              div [ Attr.class "dropdown" ]
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
                    ul [ Attr.class "menu menu-sm dropdown-content bg-neutral text-neutral-content mt-3 z-10 w-52 p-2 shadow-lg rounded-box" ]
                        [ mobileNavItem route Route.Path.Admin_Tournaments "Tournaments"
                        , mobileNavItem route Route.Path.Admin_Schools "Schools"
                        , mobileNavItem route Route.Path.Admin_Teams "Teams"
                        , mobileNavItem route Route.Path.Admin_Students "Students"
                        , mobileNavItem route Route.Path.Admin_Courtrooms "Courtrooms"
                        , mobileNavItem route Route.Path.Admin_Rounds "Rounds"
                        , mobileNavItem route Route.Path.Admin_Registrations "Registrations"
                        ]

                  else
                    text ""
                ]
            , a [ Attr.class "btn btn-ghost text-base font-bold normal-case", Route.Path.href Route.Path.Home_ ]
                [ text "RCMT Admin" ]
            ]
        , div [ Attr.class "navbar-center hidden lg:flex" ]
            [ ul [ Attr.class "menu menu-horizontal px-1" ]
                [ navItem route Route.Path.Admin_Tournaments "Tournaments"
                , navItem route Route.Path.Admin_Schools "Schools"
                , navItem route Route.Path.Admin_Teams "Teams"
                , navItem route Route.Path.Admin_Students "Students"
                , navItem route Route.Path.Admin_Courtrooms "Courtrooms"
                , navItem route Route.Path.Admin_Rounds "Rounds"
                , navItem route Route.Path.Admin_Registrations "Registrations"
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


mobileNavItem : Route () -> Route.Path.Path -> String -> Html Msg
mobileNavItem route path label =
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
