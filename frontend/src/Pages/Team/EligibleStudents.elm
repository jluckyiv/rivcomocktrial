module Pages.Team.EligibleStudents exposing (Model, Msg, page)

import Auth
import Effect exposing (Effect)
import EligibleStudents exposing (Status(..))
import Error exposing (Error(..))
import Fixtures
import Html exposing (..)
import Html.Attributes as Attr
import Html.Events as Events
import Layouts
import Page exposing (Page)
import Route exposing (Route)
import Shared
import Student
import Team
import UI
import View exposing (View)


page : Auth.User -> Shared.Model -> Route () -> Page Model Msg
page user shared route =
    Page.new
        { init = init
        , update = update
        , view = view
        , subscriptions = subscriptions
        }
        |> Page.withLayout (\_ -> Layouts.Team {})



-- MODEL


type alias Model =
    { eligibleStudents : EligibleStudents.EligibleStudents
    , firstName : String
    , lastName : String
    , preferredName : String
    , pronouns : String
    , formErrors : List String
    , submitResult : Maybe (Result (List String) ())
    }


init : () -> ( Model, Effect Msg )
init _ =
    ( { eligibleStudents =
            EligibleStudents.create EligibleStudents.defaultConfig palmDesertTeam
      , firstName = ""
      , lastName = ""
      , preferredName = ""
      , pronouns = ""
      , formErrors = []
      , submitResult = Nothing
      }
    , Effect.none
    )


palmDesertTeam : Team.Team
palmDesertTeam =
    case List.head Fixtures.teams of
        Just t ->
            t

        Nothing ->
            EligibleStudents.team Fixtures.palmDesertEligibleStudents



-- UPDATE


type Msg
    = SetFirstName String
    | SetLastName String
    | SetPreferredName String
    | SetPronouns String
    | AddStudent
    | RemoveStudent Int
    | SubmitList


update : Msg -> Model -> ( Model, Effect Msg )
update msg model =
    case msg of
        SetFirstName val ->
            ( { model | firstName = val }, Effect.none )

        SetLastName val ->
            ( { model | lastName = val }, Effect.none )

        SetPreferredName val ->
            ( { model | preferredName = val }, Effect.none )

        SetPronouns val ->
            ( { model | pronouns = val }, Effect.none )

        AddStudent ->
            let
                pref =
                    if String.isEmpty (String.trim model.preferredName) then
                        Nothing

                    else
                        Just model.preferredName

                nameResult =
                    Student.nameFromStrings
                        model.firstName
                        model.lastName
                        pref

                pron =
                    pronounsFromString model.pronouns
            in
            case nameResult of
                Ok name ->
                    let
                        newStudent =
                            Student.create name pron

                        addResult =
                            EligibleStudents.addStudent
                                newStudent
                                model.eligibleStudents
                    in
                    case addResult of
                        Ok es ->
                            ( { model
                                | eligibleStudents = es
                                , firstName = ""
                                , lastName = ""
                                , preferredName = ""
                                , pronouns = ""
                                , formErrors = []
                              }
                            , Effect.none
                            )

                        Err errors ->
                            ( { model
                                | formErrors =
                                    List.map errorToString errors
                              }
                            , Effect.none
                            )

                Err errors ->
                    ( { model
                        | formErrors =
                            List.map errorToString errors
                      }
                    , Effect.none
                    )

        RemoveStudent idx ->
            let
                studentList =
                    EligibleStudents.students model.eligibleStudents

                maybeStudent =
                    List.head (List.drop idx studentList)
            in
            case maybeStudent of
                Just s ->
                    ( { model
                        | eligibleStudents =
                            EligibleStudents.removeStudent
                                s
                                model.eligibleStudents
                      }
                    , Effect.none
                    )

                Nothing ->
                    ( model, Effect.none )

        SubmitList ->
            case EligibleStudents.submit model.eligibleStudents of
                Ok es ->
                    ( { model
                        | eligibleStudents = es
                        , submitResult = Just (Ok ())
                        , formErrors = []
                      }
                    , Effect.none
                    )

                Err errors ->
                    ( { model
                        | submitResult =
                            Just
                                (Err
                                    (List.map errorToString errors)
                                )
                      }
                    , Effect.none
                    )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none



-- VIEW


view : Model -> View Msg
view model =
    let
        teamNameStr =
            model.eligibleStudents
                |> EligibleStudents.team
                |> Team.teamName
                |> Team.nameToString

        currentStatus =
            EligibleStudents.status model.eligibleStudents

        studentList =
            EligibleStudents.students model.eligibleStudents

        isDraft =
            currentStatus == Draft

        cfg =
            EligibleStudents.config model.eligibleStudents
    in
    { title = "Eligible Students"
    , body =
        [ UI.titleBar
            { title = "Eligible Students — " ++ teamNameStr
            , actions = []
            }
        , p [ Attr.class "text-base-content/60 mb-4" ]
            [ text ("Status: " ++ EligibleStudents.statusToString currentStatus) ]
        , if isDraft then
            viewAddStudentForm model

          else
            UI.empty
        , viewStudentList isDraft cfg studentList
        , viewSubmitSection model isDraft cfg studentList
        ]
    }


viewAddStudentForm : Model -> Html Msg
viewAddStudentForm model =
    UI.card
        [ UI.cardBody
            [ UI.cardTitle "Add Student"
            , UI.errorList model.formErrors
            , div [ Attr.class "grid grid-cols-1 md:grid-cols-2 gap-4" ]
                [ label [ Attr.class "form-control w-full" ]
                    [ div [ Attr.class "label" ]
                        [ span [ Attr.class "label-text" ] [ text "First Name" ] ]
                    , input
                        [ Attr.class "input input-bordered w-full"
                        , Attr.type_ "text"
                        , Attr.value model.firstName
                        , Events.onInput SetFirstName
                        ]
                        []
                    ]
                , label [ Attr.class "form-control w-full" ]
                    [ div [ Attr.class "label" ]
                        [ span [ Attr.class "label-text" ] [ text "Last Name" ] ]
                    , input
                        [ Attr.class "input input-bordered w-full"
                        , Attr.type_ "text"
                        , Attr.value model.lastName
                        , Events.onInput SetLastName
                        ]
                        []
                    ]
                , label [ Attr.class "form-control w-full" ]
                    [ div [ Attr.class "label" ]
                        [ span [ Attr.class "label-text" ] [ text "Preferred Name" ] ]
                    , input
                        [ Attr.class "input input-bordered w-full"
                        , Attr.type_ "text"
                        , Attr.value model.preferredName
                        , Attr.placeholder "Optional"
                        , Events.onInput SetPreferredName
                        ]
                        []
                    ]
                , label [ Attr.class "form-control w-full" ]
                    [ div [ Attr.class "label" ]
                        [ span [ Attr.class "label-text" ] [ text "Pronouns" ] ]
                    , select
                        [ Attr.class "select select-bordered w-full"
                        , Events.onInput SetPronouns
                        ]
                        [ option [ Attr.value "", Attr.selected (model.pronouns == "") ] [ text "-- select --" ]
                        , option [ Attr.value "he/him", Attr.selected (model.pronouns == "he/him") ] [ text "He/Him" ]
                        , option [ Attr.value "she/her", Attr.selected (model.pronouns == "she/her") ] [ text "She/Her" ]
                        , option [ Attr.value "they/them", Attr.selected (model.pronouns == "they/them") ] [ text "They/Them" ]
                        , option [ Attr.value "other", Attr.selected (model.pronouns == "other") ] [ text "Other" ]
                        ]
                    ]
                ]
            , div [ Attr.class "mt-4" ]
                [ button
                    [ Attr.class "btn btn-info"
                    , Events.onClick AddStudent
                    ]
                    [ text "Add Student" ]
                ]
            ]
        ]


viewStudentList : Bool -> EligibleStudents.Config -> List Student.Student -> Html Msg
viewStudentList isDraft cfg studentList =
    let
        count =
            List.length studentList
    in
    UI.card
        [ UI.cardBody
            [ UI.cardTitle
                ("Students ("
                    ++ String.fromInt count
                    ++ " of "
                    ++ String.fromInt cfg.minStudents
                    ++ " minimum)"
                )
            , if List.isEmpty studentList then
                UI.emptyState "No students added yet."

              else
                div [ Attr.class "overflow-x-auto" ]
                    [ table [ Attr.class "table table-zebra w-full" ]
                        [ thead []
                            [ tr []
                                [ th [] [ text "#" ]
                                , th [] [ text "Name" ]
                                , th [] [ text "Pronouns" ]
                                , if isDraft then
                                    th [] []

                                  else
                                    text ""
                                ]
                            ]
                        , tbody []
                            (List.indexedMap
                                (viewStudentRow isDraft)
                                studentList
                            )
                        ]
                    ]
            ]
        ]


viewStudentRow : Bool -> Int -> Student.Student -> Html Msg
viewStudentRow isDraft idx s =
    let
        name =
            Student.studentName s

        displayStr =
            Student.fullName name

        pronStr =
            Student.pronounsToString (Student.pronouns s)
    in
    tr []
        [ td [] [ text (String.fromInt (idx + 1)) ]
        , td [] [ text displayStr ]
        , td [] [ text ("(" ++ pronStr ++ ")") ]
        , if isDraft then
            td []
                [ button
                    [ Attr.class "btn btn-sm btn-ghost btn-circle"
                    , Events.onClick (RemoveStudent idx)
                    , Attr.attribute "aria-label" "Remove"
                    ]
                    [ text "✕" ]
                ]

          else
            text ""
        ]


viewSubmitSection : Model -> Bool -> EligibleStudents.Config -> List Student.Student -> Html Msg
viewSubmitSection model isDraft cfg studentList =
    let
        count =
            List.length studentList

        minReq =
            cfg.minStudents
    in
    UI.card
        [ UI.cardBody
            ([ if isDraft then
                button
                    [ Attr.class "btn btn-primary"
                    , Attr.disabled (count < minReq)
                    , Events.onClick SubmitList
                    ]
                    [ text "Submit Student List" ]

               else
                p [ Attr.class "text-success font-semibold" ]
                    [ text "Student list has been submitted." ]
             ]
                ++ (case model.submitResult of
                        Just (Err errors) ->
                            [ div [ Attr.class "mt-3" ]
                                [ UI.errorList errors ]
                            ]

                        _ ->
                            []
                   )
                ++ (if isDraft && count < minReq then
                        [ p [ Attr.class "text-sm text-error mt-2" ]
                            [ text
                                ("Need at least "
                                    ++ String.fromInt minReq
                                    ++ " students ("
                                    ++ String.fromInt (minReq - count)
                                    ++ " more)"
                                )
                            ]
                        ]

                    else
                        []
                   )
            )
        ]



-- HELPERS


pronounsFromString : String -> Student.Pronouns
pronounsFromString str =
    case str of
        "he/him" ->
            Student.HeHim

        "she/her" ->
            Student.SheHer

        "they/them" ->
            Student.TheyThem

        _ ->
            Student.Other str


errorToString : Error -> String
errorToString (Error s) =
    s
