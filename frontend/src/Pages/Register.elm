module Pages.Register exposing (page)

import Html exposing (..)
import Html.Attributes as Attr
import Route.Path
import UI
import View exposing (View)


page : View msg
page =
    { title = "Register"
    , body =
        [ UI.pageHeading "Register"
        , UI.cardGrid
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
    UI.card
        [ UI.cardBody
            [ UI.cardTitle config.title
            , p [] [ text config.description ]
            , UI.cardActions
                [ case config.path of
                    Just path ->
                        UI.smallPrimaryLink "Register" (Route.Path.href path)

                    Nothing ->
                        span [ Attr.class "text-sm text-base-content/50" ]
                            [ text "Coming soon" ]
                ]
            ]
        ]
