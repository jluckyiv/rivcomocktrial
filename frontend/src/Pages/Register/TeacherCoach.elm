module Pages.Register.TeacherCoach exposing (Model, Msg, page)

import Api
import Coach
import Effect exposing (Effect)
import Email
import Error exposing (Error(..))
import Html exposing (..)
import Html.Attributes as Attr
import Html.Events as Events
import Json.Decode
import Layouts
import Page exposing (Page)
import Pb
import Route exposing (Route)
import Route.Path
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
    , password : String
    , passwordConfirm : String
    , selectedSchoolId : Maybe String
    , teamName : String
    , errors : List String
    , schools : List Api.School
    , loadingSchools : Bool
    , submitting : Bool
    }


init : () -> ( Model, Effect Msg )
init _ =
    ( { firstName = ""
      , lastName = ""
      , email = ""
      , password = ""
      , passwordConfirm = ""
      , selectedSchoolId = Nothing
      , teamName = ""
      , errors = []
      , schools = []
      , loadingSchools = True
      , submitting = False
      }
    , Pb.publicList
        { collection = "schools"
        , tag = "schools"
        , filter = ""
        , sort = "name"
        }
    )



-- UPDATE


type Msg
    = UpdateFirstName String
    | UpdateLastName String
    | UpdateEmail String
    | UpdatePassword String
    | UpdatePasswordConfirm String
    | SelectSchool String
    | UpdateTeamName String
    | Submit
    | PbMsg Json.Decode.Value


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

        UpdatePassword val ->
            ( { model | password = val, errors = [] }
            , Effect.none
            )

        UpdatePasswordConfirm val ->
            ( { model
                | passwordConfirm = val
                , errors = []
              }
            , Effect.none
            )

        SelectSchool val ->
            let
                schoolId =
                    if String.isEmpty val then
                        Nothing

                    else
                        Just val

                newTeamName =
                    case schoolId of
                        Just id ->
                            model.schools
                                |> List.filter
                                    (\s -> s.id == id)
                                |> List.head
                                |> Maybe.map .name
                                |> Maybe.withDefault
                                    model.teamName

                        Nothing ->
                            model.teamName
            in
            ( { model
                | selectedSchoolId = schoolId
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

                Ok data ->
                    ( { model
                        | submitting = True
                        , errors = []
                      }
                    , Pb.publicCreate
                        { collection = "users"
                        , tag = "register"
                        , body =
                            Api.encodeCoachRegistration
                                data
                        }
                    )

        PbMsg value ->
            case Pb.responseTag value of
                Just "schools" ->
                    case Pb.decodeList Api.schoolDecoder value of
                        Ok schools ->
                            ( { model
                                | schools = schools
                                , loadingSchools = False
                              }
                            , Effect.none
                            )

                        Err _ ->
                            ( { model
                                | loadingSchools = False
                                , errors =
                                    [ "Failed to load schools. "
                                        ++ "Please refresh the page."
                                    ]
                              }
                            , Effect.none
                            )

                Just "register" ->
                    case Pb.decodeRecord Api.coachUserDecoder value of
                        Ok _ ->
                            ( model
                            , Effect.pushRoutePath
                                Route.Path.Register_Pending
                            )

                        Err _ ->
                            ( { model
                                | submitting = False
                                , errors =
                                    [ "Registration failed. The email "
                                        ++ "may already be in use."
                                    ]
                              }
                            , Effect.none
                            )

                _ ->
                    ( model, Effect.none )



-- VALIDATION


validateForm :
    Model
    ->
        Result
            (List String)
            { email : String
            , password : String
            , passwordConfirm : String
            , name : String
            , school : String
            , teamName : String
            }
validateForm model =
    let
        toStrings =
            List.map (\(Error m) -> m)

        nameValidation =
            Coach.nameFromStrings model.firstName
                model.lastName
                |> Result.mapError toStrings

        emailValidation =
            Email.fromString model.email
                |> Result.mapError toStrings

        passwordValidation =
            if String.length model.password < 8 then
                Err
                    [ "Password must be at least "
                        ++ "8 characters."
                    ]

            else if model.password /= model.passwordConfirm then
                Err [ "Passwords do not match." ]

            else
                Ok ()

        schoolValidation =
            case model.selectedSchoolId of
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
                , passwordValidation
                , schoolValidation
                , teamNameValidation
                    |> Result.map (\_ -> ())
                ]
    in
    if List.isEmpty allErrors then
        case model.selectedSchoolId of
            Just schoolId ->
                Ok
                    { email = model.email
                    , password = model.password
                    , passwordConfirm =
                        model.passwordConfirm
                    , name =
                        model.firstName
                            ++ " "
                            ++ model.lastName
                    , school = schoolId
                    , teamName = model.teamName
                    }

            Nothing ->
                Err [ "Please select a school" ]

    else
        Err allErrors



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    Pb.subscribe PbMsg



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
                , if model.loadingSchools then
                    p [ Attr.class "has-text-grey" ]
                        [ text "Loading schools..." ]

                  else
                    viewForm model
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
                (List.map
                    (\e -> li [] [ text e ])
                    errors
                )
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
                    , Attr.disabled model.submitting
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
                    , Attr.disabled model.submitting
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
                    , Attr.disabled model.submitting
                    ]
                    []
                ]
            ]
        , div [ Attr.class "field" ]
            [ label [ Attr.class "label" ]
                [ text "Password" ]
            , div [ Attr.class "control" ]
                [ input
                    [ Attr.class "input"
                    , Attr.type_ "password"
                    , Attr.placeholder
                        "At least 8 characters"
                    , Attr.value model.password
                    , Events.onInput UpdatePassword
                    , Attr.disabled model.submitting
                    ]
                    []
                ]
            ]
        , div [ Attr.class "field" ]
            [ label [ Attr.class "label" ]
                [ text "Confirm Password" ]
            , div [ Attr.class "control" ]
                [ input
                    [ Attr.class "input"
                    , Attr.type_ "password"
                    , Attr.placeholder "Confirm password"
                    , Attr.value model.passwordConfirm
                    , Events.onInput UpdatePasswordConfirm
                    , Attr.disabled model.submitting
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
                        [ Events.onInput SelectSchool
                        , Attr.disabled model.submitting
                        ]
                        (option
                            [ Attr.value ""
                            , Attr.selected
                                (model.selectedSchoolId
                                    == Nothing
                                )
                            ]
                            [ text
                                "-- Select a school --"
                            ]
                            :: List.map
                                viewSchoolOption
                                model.schools
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
                    , Attr.disabled model.submitting
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
                    [ Attr.class
                        (if model.submitting then
                            "button is-primary is-fullwidth is-loading"

                         else
                            "button is-primary is-fullwidth"
                        )
                    , Attr.type_ "submit"
                    , Attr.disabled model.submitting
                    ]
                    [ text "Submit Registration" ]
                ]
            ]
        , p [ Attr.class "has-text-centered mt-4" ]
            [ text "Already have an account? "
            , a
                [ Route.Path.href Route.Path.Team_Login ]
                [ text "Login here" ]
            ]
        ]


viewSchoolOption : Api.School -> Html msg
viewSchoolOption sch =
    option
        [ Attr.value sch.id ]
        [ text sch.name ]
