module Pages.Register.Pending exposing (page)

import Html exposing (..)
import Html.Attributes as Attr
import Route.Path
import View exposing (View)


page : View msg
page =
    { title = "Registration Pending"
    , body =
        [ div [ Attr.class "hero min-h-64 bg-info text-info-content rounded-box" ]
            [ div [ Attr.class "hero-content text-center" ]
                [ div []
                    [ h1 [ Attr.class "text-3xl font-bold mb-4" ]
                        [ text "Application Received" ]
                    , p [ Attr.class "text-lg mb-6 opacity-90" ]
                        [ text
                            ("Your registration is pending "
                                ++ "admin review. You will be "
                                ++ "notified once approved."
                            )
                        ]
                    , a
                        [ Attr.class "btn btn-ghost btn-outline"
                        , Route.Path.href Route.Path.Home_
                        ]
                        [ text "Back to Home" ]
                    ]
                ]
            ]
        ]
    }
