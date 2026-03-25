module Pages.Register exposing (page)

import Html exposing (..)
import Html.Attributes as Attr
import Route.Path
import View exposing (View)


page : View msg
page =
    { title = "Register"
    , body =
        [ h1 [ Attr.class "text-2xl font-bold mb-6" ] [ text "Register" ]
        , div [ Attr.class "grid grid-cols-1 md:grid-cols-3 gap-4" ]
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
    div [ Attr.class "card bg-base-100 shadow-sm" ]
        [ div [ Attr.class "card-body" ]
            [ h2 [ Attr.class "card-title" ] [ text config.title ]
            , p [] [ text config.description ]
            , div [ Attr.class "card-actions justify-end mt-2" ]
                [ case config.path of
                    Just path ->
                        a
                            [ Attr.class "btn btn-primary btn-sm"
                            , Route.Path.href path
                            ]
                            [ text "Register" ]

                    Nothing ->
                        span [ Attr.class "text-sm text-base-content/50" ]
                            [ text "Coming soon" ]
                ]
            ]
        ]
