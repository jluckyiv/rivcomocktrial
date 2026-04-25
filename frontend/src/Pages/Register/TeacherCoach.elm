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
import UI
import View exposing (View)


page : Shared.Model -> Route () -> Page Model Msg
page _ _ =
    Page.new
        { init = init
        , update = update
        , view = view
        , subscriptions = subscriptions
        }
        |> Page.withLayout (\_ -> Layouts.Public {})



-- MODEL


type RegistrationStep
    = NotStarted
    | Submitting
    | Done


type RegistrationAvailability
    = CheckingAvailability
    | RegistrationOpen Api.Tournament
    | RegistrationClosed
    | LoadFailed String


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
    , availability : RegistrationAvailability
    , step : RegistrationStep
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
      , availability = CheckingAvailability
      , step = NotStarted
      }
    , Effect.batch
        [ Pb.publicList
            { collection = "schools"
            , tag = "schools"
            , filter = ""
            , sort = "name"
            }
        , Pb.publicList
            { collection = "tournaments"
            , tag = "active-tournament"
            , filter = "status='registration'"
            , sort = "-created"
            }
        ]
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
            ( { model | firstName = val, errors = [] }, Effect.none )

        UpdateLastName val ->
            ( { model | lastName = val, errors = [] }, Effect.none )

        UpdateEmail val ->
            ( { model | email = val, errors = [] }, Effect.none )

        UpdatePassword val ->
            ( { model | password = val, errors = [] }, Effect.none )

        UpdatePasswordConfirm val ->
            ( { model | passwordConfirm = val, errors = [] }, Effect.none )

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
                                |> List.filter (\s -> s.id == id)
                                |> List.head
                                |> Maybe.map .name
                                |> Maybe.withDefault model.teamName

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
            ( { model | teamName = val, errors = [] }, Effect.none )

        Submit ->
            case validateForm model of
                Err errors ->
                    ( { model | errors = errors }, Effect.none )

                Ok data ->
                    ( { model | step = Submitting, errors = [] }
                    , Pb.publicCreate
                        { collection = "users"
                        , tag = "register-user"
                        , body = Api.encodeCoachRegistration data
                        }
                    )

        PbMsg value ->
            case Pb.responseTag value of
                Just "schools" ->
                    case Pb.decodeList Api.schoolDecoder value of
                        Ok schools ->
                            ( { model | schools = schools }, Effect.none )

                        Err _ ->
                            ( { model
                                | errors =
                                    [ "Failed to load schools. "
                                        ++ "Please refresh the page."
                                    ]
                              }
                            , Effect.none
                            )

                Just "active-tournament" ->
                    case Pb.decodeList Api.tournamentDecoder value of
                        Ok (tournament :: _) ->
                            ( { model
                                | availability = RegistrationOpen tournament
                              }
                            , Effect.none
                            )

                        Ok [] ->
                            ( { model | availability = RegistrationClosed }
                            , Effect.none
                            )

                        Err _ ->
                            ( { model
                                | availability =
                                    LoadFailed
                                        "Could not check registration status."
                              }
                            , Effect.none
                            )

                Just "register-user" ->
                    case Pb.decodeRecord Api.coachUserDecoder value of
                        Ok _ ->
                            ( { model | step = Done }
                            , Effect.pushRoutePath Route.Path.Register_Pending
                            )

                        Err _ ->
                            let
                                emailTaken =
                                    Json.Decode.decodeValue
                                        (Json.Decode.at
                                            [ "errorData"
                                            , "email"
                                            , "code"
                                            ]
                                            Json.Decode.string
                                        )
                                        value
                                        == Ok "validation_not_unique"

                                errorMsg =
                                    if emailTaken then
                                        "We already have a registration "
                                            ++ "for that email address. "
                                            ++ "It is pending review."

                                    else
                                        "Registration failed. Please "
                                            ++ "try again or contact "
                                            ++ "the organizer."
                            in
                            ( { model
                                | step = NotStarted
                                , errors = [ errorMsg ]
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
            Coach.nameFromStrings model.firstName model.lastName
                |> Result.mapError toStrings

        emailValidation =
            Email.fromString model.email
                |> Result.mapError toStrings

        passwordValidation =
            if String.length model.password < 8 then
                Err [ "Password must be at least 8 characters." ]

            else if model.password /= model.passwordConfirm then
                Err [ "Passwords do not match." ]

            else
                Ok ()

        schoolValidation =
            case model.selectedSchoolId of
                Nothing ->
                    Err [ "Please select a school." ]

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
                [ nameValidation |> Result.map (\_ -> ())
                , emailValidation |> Result.map (\_ -> ())
                , passwordValidation
                , schoolValidation
                , teamNameValidation |> Result.map (\_ -> ())
                ]
    in
    if List.isEmpty allErrors then
        case model.selectedSchoolId of
            Just schoolId ->
                Ok
                    { email = model.email
                    , password = model.password
                    , passwordConfirm = model.passwordConfirm
                    , name = model.firstName ++ " " ++ model.lastName
                    , school = schoolId
                    , teamName = model.teamName
                    }

            Nothing ->
                Err [ "Please select a school." ]

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
        [ UI.narrowPage
            [ UI.pageHeading "Teacher Coach Registration"
            , viewAvailability model
            ]
        ]
    }


viewAvailability : Model -> Html Msg
viewAvailability model =
    case model.availability of
        CheckingAvailability ->
            UI.loading

        RegistrationClosed ->
            UI.alert { variant = "info" }
                [ p [] [ text "Registration is not currently open." ]
                , p [] [ text "Contact the organizer if you believe this is an error." ]
                ]

        LoadFailed err ->
            UI.error err

        RegistrationOpen tournament ->
            div []
                [ UI.alert { variant = "success" }
                    [ text
                        ("Registration is open for "
                            ++ tournament.name
                            ++ "."
                        )
                    ]
                , UI.errorList model.errors
                , if List.isEmpty model.schools then
                    UI.loading

                  else
                    viewForm model
                ]


viewForm : Model -> Html Msg
viewForm model =
    let
        submitting =
            model.step == Submitting
    in
    Html.form [ Events.onSubmit Submit, Attr.class "flex flex-col gap-4" ]
        [ UI.formColumns
            [ UI.formField "First Name"
                [ input
                    [ Attr.class "input input-bordered w-full"
                    , Attr.type_ "text"
                    , Attr.placeholder "First name"
                    , Attr.value model.firstName
                    , Events.onInput UpdateFirstName
                    , Attr.disabled submitting
                    ]
                    []
                ]
            , UI.formField "Last Name"
                [ input
                    [ Attr.class "input input-bordered w-full"
                    , Attr.type_ "text"
                    , Attr.placeholder "Last name"
                    , Attr.value model.lastName
                    , Events.onInput UpdateLastName
                    , Attr.disabled submitting
                    ]
                    []
                ]
            ]
        , UI.formField "Email"
            [ input
                [ Attr.class "input input-bordered w-full"
                , Attr.type_ "email"
                , Attr.placeholder "you@school.edu"
                , Attr.value model.email
                , Events.onInput UpdateEmail
                , Attr.disabled submitting
                ]
                []
            ]
        , UI.formColumns
            [ UI.formField "Password"
                [ input
                    [ Attr.class "input input-bordered w-full"
                    , Attr.type_ "password"
                    , Attr.placeholder "At least 8 characters"
                    , Attr.value model.password
                    , Events.onInput UpdatePassword
                    , Attr.disabled submitting
                    ]
                    []
                ]
            , UI.formField "Confirm Password"
                [ input
                    [ Attr.class "input input-bordered w-full"
                    , Attr.type_ "password"
                    , Attr.placeholder "Confirm password"
                    , Attr.value model.passwordConfirm
                    , Events.onInput UpdatePasswordConfirm
                    , Attr.disabled submitting
                    ]
                    []
                ]
            ]
        , UI.formField "School"
            [ select
                [ Attr.class "select select-bordered w-full"
                , Events.onInput SelectSchool
                , Attr.disabled submitting
                ]
                (option
                    [ Attr.value ""
                    , Attr.selected (model.selectedSchoolId == Nothing)
                    ]
                    [ text "-- Select a school --" ]
                    :: List.map
                        (\sch ->
                            option [ Attr.value sch.id ] [ text sch.name ]
                        )
                        model.schools
                )
            ]
        , UI.formField "Team Name"
            [ input
                [ Attr.class "input input-bordered w-full"
                , Attr.type_ "text"
                , Attr.placeholder "Team name"
                , Attr.value model.teamName
                , Events.onInput UpdateTeamName
                , Attr.disabled submitting
                ]
                []
            , UI.note "Defaults to school name. Change if registering a second team."
            ]
        , UI.primaryButton { label = "Submit Registration", loading = submitting }
        , UI.centeredNote
            [ text "Already have an account? "
            , UI.inlineLink "Login here" (Route.Path.href Route.Path.Team_Login)
            ]
        ]


