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
        [ h1 [ Attr.class "title" ]
            [ text ("Eligible Students — " ++ teamNameStr) ]
        , p [ Attr.class "subtitle" ]
            [ text ("Status: " ++ EligibleStudents.statusToString currentStatus) ]
        , if isDraft then
            viewAddStudentForm model

          else
            text ""
        , viewStudentList isDraft cfg studentList
        , viewSubmitSection model isDraft cfg studentList
        ]
    }


viewAddStudentForm : Model -> Html Msg
viewAddStudentForm model =
    div [ Attr.class "box" ]
        [ h2 [ Attr.class "title is-5" ] [ text "Add Student" ]
        , viewFormErrors model.formErrors
        , div [ Attr.class "field" ]
            [ label [ Attr.class "label" ] [ text "First Name" ]
            , div [ Attr.class "control" ]
                [ input
                    [ Attr.class "input"
                    , Attr.type_ "text"
                    , Attr.value model.firstName
                    , Events.onInput SetFirstName
                    ]
                    []
                ]
            ]
        , div [ Attr.class "field" ]
            [ label [ Attr.class "label" ] [ text "Last Name" ]
            , div [ Attr.class "control" ]
                [ input
                    [ Attr.class "input"
                    , Attr.type_ "text"
                    , Attr.value model.lastName
                    , Events.onInput SetLastName
                    ]
                    []
                ]
            ]
        , div [ Attr.class "field" ]
            [ label [ Attr.class "label" ] [ text "Preferred Name" ]
            , div [ Attr.class "control" ]
                [ input
                    [ Attr.class "input"
                    , Attr.type_ "text"
                    , Attr.value model.preferredName
                    , Attr.placeholder "Optional"
                    , Events.onInput SetPreferredName
                    ]
                    []
                ]
            ]
        , div [ Attr.class "field" ]
            [ label [ Attr.class "label" ] [ text "Pronouns" ]
            , div [ Attr.class "control" ]
                [ div [ Attr.class "select" ]
                    [ select
                        [ Events.onInput SetPronouns
                        , Attr.value model.pronouns
                        ]
                        [ option [ Attr.value "" ] [ text "-- select --" ]
                        , option [ Attr.value "he/him" ] [ text "He/Him" ]
                        , option [ Attr.value "she/her" ] [ text "She/Her" ]
                        , option [ Attr.value "they/them" ]
                            [ text "They/Them" ]
                        , option [ Attr.value "other" ] [ text "Other" ]
                        ]
                    ]
                ]
            ]
        , div [ Attr.class "field" ]
            [ div [ Attr.class "control" ]
                [ button
                    [ Attr.class "button is-info"
                    , Events.onClick AddStudent
                    ]
                    [ text "Add Student" ]
                ]
            ]
        ]


viewFormErrors : List String -> Html msg
viewFormErrors errors =
    if List.isEmpty errors then
        text ""

    else
        div [ Attr.class "notification is-danger is-light" ]
            (List.map (\e -> p [] [ text e ]) errors)


viewStudentList : Bool -> EligibleStudents.Config -> List Student.Student -> Html Msg
viewStudentList isDraft cfg studentList =
    let
        count =
            List.length studentList
    in
    div [ Attr.class "box" ]
        [ h2 [ Attr.class "title is-5" ]
            [ text
                ("Students ("
                    ++ String.fromInt count
                    ++ " of "
                    ++ String.fromInt cfg.minStudents
                    ++ " minimum)"
                )
            ]
        , if List.isEmpty studentList then
            p [ Attr.class "has-text-grey" ]
                [ text "No students added yet." ]

          else
            table [ Attr.class "table is-fullwidth is-striped" ]
                [ thead []
                    [ tr []
                        [ th [] [ text "#" ]
                        , th [] [ text "Name" ]
                        , th [] [ text "Pronouns" ]
                        , if isDraft then
                            th [] [ text "" ]

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
                    [ Attr.class "delete"
                    , Events.onClick (RemoveStudent idx)
                    ]
                    []
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
    div [ Attr.class "box" ]
        ([ if isDraft then
            button
                [ Attr.class "button is-primary"
                , Attr.disabled (count < minReq)
                , Events.onClick SubmitList
                ]
                [ text "Submit Student List" ]

           else
            p [ Attr.class "has-text-success" ]
                [ text "Student list has been submitted." ]
         ]
            ++ (case model.submitResult of
                    Just (Err errors) ->
                        [ div
                            [ Attr.class
                                "notification is-danger is-light mt-3"
                            ]
                            (List.map (\e -> p [] [ text e ]) errors)
                        ]

                    _ ->
                        []
               )
            ++ (if isDraft && count < minReq then
                    [ p [ Attr.class "help is-danger mt-2" ]
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
