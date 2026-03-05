module Pages.Register.TeacherCoach exposing (Model, Msg, page)

import Coach
import Effect exposing (Effect)
import Email
import Error exposing (Error(..))
import Fixtures
import Html exposing (..)
import Html.Attributes as Attr
import Html.Events as Events
import Layouts
import Page exposing (Page)
import Route exposing (Route)
import Route.Path
import School
import Shared
import Team
import View exposing (View)


page : Shared.Model -> Route () -> Page Model Msg
page shared route =
    Page.new
        { init = init
        , update = update
        , view = view
        , subscriptions = subscriptions
        }
        |> Page.withLayout (\_ -> Layouts.Public {})



-- MODEL


type alias Model =
    { firstName : String
    , lastName : String
    , email : String
    , schoolIndex : Maybe Int
    , teamName : String
    , errors : List String
    }


init : () -> ( Model, Effect Msg )
init _ =
    ( { firstName = ""
      , lastName = ""
      , email = ""
      , schoolIndex = Nothing
      , teamName = ""
      , errors = []
      }
    , Effect.none
    )



-- UPDATE


type Msg
    = UpdateFirstName String
    | UpdateLastName String
    | UpdateEmail String
    | SelectSchool String
    | UpdateTeamName String
    | Submit


update : Msg -> Model -> ( Model, Effect Msg )
update msg model =
    case msg of
        UpdateFirstName val ->
            ( { model | firstName = val, errors = [] }
            , Effect.none
            )

        UpdateLastName val ->
            ( { model | lastName = val, errors = [] }
            , Effect.none
            )

        UpdateEmail val ->
            ( { model | email = val, errors = [] }
            , Effect.none
            )

        SelectSchool val ->
            let
                idx =
                    String.toInt val

                newTeamName =
                    case idx of
                        Just i ->
                            Fixtures.schools
                                |> List.drop i
                                |> List.head
                                |> Maybe.map
                                    (School.schoolName
                                        >> School.nameToString
                                    )
                                |> Maybe.withDefault
                                    model.teamName

                        Nothing ->
                            model.teamName
            in
            ( { model
                | schoolIndex = idx
                , teamName = newTeamName
                , errors = []
              }
            , Effect.none
            )

        UpdateTeamName val ->
            ( { model | teamName = val, errors = [] }
            , Effect.none
            )

        Submit ->
            case validateForm model of
                Err errors ->
                    ( { model | errors = errors }
                    , Effect.none
                    )

                Ok _ ->
                    ( model
                    , Effect.pushRoutePath
                        Route.Path.Register_Pending
                    )



-- VALIDATION


validateForm :
    Model
    -> Result (List String) ()
validateForm model =
    let
        toStrings =
            List.map (\(Error msg) -> msg)

        nameValidation =
            Coach.nameFromStrings model.firstName
                model.lastName
                |> Result.mapError toStrings

        emailValidation =
            Email.fromString model.email
                |> Result.mapError toStrings

        schoolValidation =
            case model.schoolIndex of
                Nothing ->
                    Err [ "Please select a school" ]

                Just _ ->
                    Ok ()

        teamNameValidation =
            Team.nameFromString model.teamName
                |> Result.mapError toStrings

        collectErrors results =
            List.concatMap
                (\r ->
                    case r of
                        Err errs ->
                            errs

                        Ok _ ->
                            []
                )
                results

        allErrors =
            collectErrors
                [ nameValidation
                    |> Result.map (\_ -> ())
                , emailValidation
                    |> Result.map (\_ -> ())
                , schoolValidation
                , teamNameValidation
                    |> Result.map (\_ -> ())
                ]
    in
    if List.isEmpty allErrors then
        Ok ()

    else
        Err allErrors



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none



-- VIEW


view : Model -> View Msg
view model =
    { title = "Teacher Coach Registration"
    , body =
        [ div [ Attr.class "columns is-centered" ]
            [ div [ Attr.class "column is-half" ]
                [ h1 [ Attr.class "title" ]
                    [ text "Teacher Coach Registration" ]
                , viewErrors model.errors
                , viewForm model
                ]
            ]
        ]
    }


viewErrors : List String -> Html msg
viewErrors errors =
    if List.isEmpty errors then
        text ""

    else
        div
            [ Attr.class
                "notification is-danger is-light"
            ]
            [ ul []
                (List.map (\e -> li [] [ text e ]) errors)
            ]


viewForm : Model -> Html Msg
viewForm model =
    Html.form [ Events.onSubmit Submit ]
        [ div [ Attr.class "field" ]
            [ label [ Attr.class "label" ]
                [ text "First Name" ]
            , div [ Attr.class "control" ]
                [ input
                    [ Attr.class "input"
                    , Attr.type_ "text"
                    , Attr.placeholder "First name"
                    , Attr.value model.firstName
                    , Events.onInput UpdateFirstName
                    ]
                    []
                ]
            ]
        , div [ Attr.class "field" ]
            [ label [ Attr.class "label" ]
                [ text "Last Name" ]
            , div [ Attr.class "control" ]
                [ input
                    [ Attr.class "input"
                    , Attr.type_ "text"
                    , Attr.placeholder "Last name"
                    , Attr.value model.lastName
                    , Events.onInput UpdateLastName
                    ]
                    []
                ]
            ]
        , div [ Attr.class "field" ]
            [ label [ Attr.class "label" ]
                [ text "Email" ]
            , div [ Attr.class "control" ]
                [ input
                    [ Attr.class "input"
                    , Attr.type_ "email"
                    , Attr.placeholder "you@school.edu"
                    , Attr.value model.email
                    , Events.onInput UpdateEmail
                    ]
                    []
                ]
            ]
        , div [ Attr.class "field" ]
            [ label [ Attr.class "label" ]
                [ text "School" ]
            , div [ Attr.class "control" ]
                [ div [ Attr.class "select is-fullwidth" ]
                    [ select
                        [ Events.onInput SelectSchool ]
                        (option
                            [ Attr.value ""
                            , Attr.selected
                                (model.schoolIndex
                                    == Nothing
                                )
                            ]
                            [ text "-- Select a school --" ]
                            :: List.indexedMap
                                viewSchoolOption
                                Fixtures.schools
                        )
                    ]
                ]
            ]
        , div [ Attr.class "field" ]
            [ label [ Attr.class "label" ]
                [ text "Team Name" ]
            , div [ Attr.class "control" ]
                [ input
                    [ Attr.class "input"
                    , Attr.type_ "text"
                    , Attr.placeholder "Team name"
                    , Attr.value model.teamName
                    , Events.onInput UpdateTeamName
                    ]
                    []
                ]
            , p [ Attr.class "help" ]
                [ text
                    "Defaults to school name. Change "
                    , text
                        "if registering a second team."
                ]
            ]
        , div [ Attr.class "field" ]
            [ div [ Attr.class "control" ]
                [ button
                    [ Attr.class "button is-primary"
                    , Attr.type_ "submit"
                    ]
                    [ text "Submit Registration" ]
                ]
            ]
        ]


viewSchoolOption : Int -> School.School -> Html msg
viewSchoolOption index sch =
    option
        [ Attr.value (String.fromInt index) ]
        [ text (School.schoolName sch |> School.nameToString) ]
