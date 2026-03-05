module Pages.Register exposing (page)

import Html exposing (..)
import Html.Attributes as Attr
import Layouts
import Route.Path
import View exposing (View)


page : View msg
page =
    { title = "Register"
    , body =
        [ div [ Attr.class "columns is-multiline is-centered" ]
            [ roleCard
                { title = "Teacher Coach"
                , description =
                    "Register as the teacher coach "
                        ++ "for your school's mock trial team."
                , path = Just Route.Path.Register_TeacherCoach
                }
            , roleCard
                { title = "Attorney Coach"
                , description =
                    "Registration for attorney coaches "
                        ++ "is coming soon."
                , path = Nothing
                }
            , roleCard
                { title = "Scorer / Judge"
                , description =
                    "Registration for scorers and judges "
                        ++ "is coming soon."
                , path = Nothing
                }
            ]
        ]
    }


roleCard :
    { title : String
    , description : String
    , path : Maybe Route.Path.Path
    }
    -> Html msg
roleCard config =
    div [ Attr.class "column is-4" ]
        [ div [ Attr.class "card" ]
            [ div [ Attr.class "card-content" ]
                [ p [ Attr.class "title is-4" ]
                    [ text config.title ]
                , p [ Attr.class "content" ]
                    [ text config.description ]
                ]
            , div [ Attr.class "card-footer" ]
                [ case config.path of
                    Just path ->
                        a
                            [ Attr.class "card-footer-item"
                            , Route.Path.href path
                            ]
                            [ text "Register" ]

                    Nothing ->
                        span
                            [ Attr.class
                                "card-footer-item has-text-grey"
                            ]
                            [ text "Coming soon" ]
                ]
            ]
        ]
