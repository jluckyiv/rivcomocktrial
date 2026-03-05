module Pages.Register.Pending exposing (page)

import Html exposing (..)
import Html.Attributes as Attr
import Route.Path
import View exposing (View)


page : View msg
page =
    { title = "Registration Pending"
    , body =
        [ section [ Attr.class "hero is-info is-medium" ]
            [ div [ Attr.class "hero-body" ]
                [ p [ Attr.class "title" ]
                    [ text "Application Received" ]
                , p [ Attr.class "subtitle" ]
                    [ text
                        ("Your registration is pending "
                            ++ "admin review. You will be "
                            ++ "notified once approved."
                        )
                    ]
                , a
                    [ Attr.class "button is-light"
                    , Route.Path.href Route.Path.Home_
                    ]
                    [ text "Back to Home" ]
                ]
            ]
        ]
    }
