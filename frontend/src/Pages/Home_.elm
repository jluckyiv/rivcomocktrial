module Pages.Home_ exposing (page)

import Html
import Html.Attributes as Attr
import View exposing (View)


page : View msg
page =
    { title = "Riverside County Mock Trial"
    , body =
        [ Html.div [ Attr.style "text-align" "center", Attr.style "padding" "4rem 2rem" ]
            [ Html.h1 [] [ Html.text "Riverside County Mock Trial" ]
            , Html.p [] [ Html.text "Competition management and information portal." ]
            ]
        ]
    }
