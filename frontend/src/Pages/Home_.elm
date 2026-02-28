module Pages.Home_ exposing (page)

import Html
import Html.Attributes as Attr
import Route.Path
import View exposing (View)


page : View msg
page =
    { title = "Riverside County Mock Trial"
    , body =
        [ Html.section [ Attr.class "hero is-primary is-medium" ]
            [ Html.div [ Attr.class "hero-body" ]
                [ Html.p [ Attr.class "title" ] [ Html.text "Riverside County Mock Trial" ]
                , Html.p [ Attr.class "subtitle" ] [ Html.text "Competition management and information portal." ]
                , Html.a [ Attr.class "button is-light", Route.Path.href Route.Path.Admin_Login ]
                    [ Html.text "Admin Login" ]
                ]
            ]
        ]
    }
