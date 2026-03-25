module Pages.Home_ exposing (page)

import Html
import Html.Attributes as Attr
import Route.Path
import View exposing (View)


page : View msg
page =
    { title = "Riverside County Mock Trial"
    , body =
        [ Html.div [ Attr.class "hero min-h-64 bg-primary text-primary-content rounded-box mb-8" ]
            [ Html.div [ Attr.class "hero-content text-center" ]
                [ Html.div []
                    [ Html.h1 [ Attr.class "text-4xl font-bold mb-4" ]
                        [ Html.text "Riverside County Mock Trial" ]
                    , Html.p [ Attr.class "text-lg mb-6 opacity-90" ]
                        [ Html.text "Competition management and information portal." ]
                    , Html.div [ Attr.class "flex gap-3 justify-center flex-wrap" ]
                        [ Html.a
                            [ Attr.class "btn btn-secondary"
                            , Route.Path.href Route.Path.Register
                            ]
                            [ Html.text "Register" ]
                        , Html.a
                            [ Attr.class "btn btn-info"
                            , Route.Path.href Route.Path.Team_Login
                            ]
                            [ Html.text "Coach Login" ]
                        , Html.a
                            [ Attr.class "btn btn-ghost btn-outline"
                            , Route.Path.href Route.Path.Admin_Login
                            ]
                            [ Html.text "Admin Login" ]
                        ]
                    ]
                ]
            ]
        ]
    }
