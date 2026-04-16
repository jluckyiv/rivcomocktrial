module Pages.Team.Manage exposing (Model, Msg, page)

import Api
import Auth
import Effect exposing (Effect)
import Html exposing (..)
import Html.Attributes as Attr
import Html.Events as Events
import Json.Decode
import Json.Encode
import Layouts
import Page exposing (Page)
import Pb
import Route exposing (Route)
import Shared
import Shared.Model exposing (CoachAuth(..))
import UI
import View exposing (View)


page : Auth.User -> Shared.Model -> Route () -> Page Model Msg
page user shared route =
    Page.new
        { init = init shared
        , update = update
        , view = view
        , subscriptions = subscriptions
        }
        |> Page.withLayout (\_ -> Layouts.Team {})



-- MODEL


type PageState
    = LoadingTeam
    | TeamNotFound
    | LoadFailed String
    | TeamReady TeamData


type alias Model =
    { state : PageState }


type alias TeamData =
    { team : Api.Team
    , tournament : RemoteData Api.Tournament
    , entries : RemoteData (List Api.EligibilityEntry)
    , changeRequests : RemoteData (List Api.ChangeRequest)
    , coCoaches : RemoteData (List Api.CoCoach)
    , attorneyCoaches : RemoteData (List Api.AttorneyCoach)
    , studentForm : StudentFormState
    , changeRequestForm : ChangeRequestFormState
    , coCoachForm : CoCoachFormState
    , attorneyForm : AttorneyFormState
    }


type RemoteData a
    = Loading
    | Succeeded a
    | Failed String


type StudentFormState
    = StudentFormHidden
    | StudentFormOpen { name : String } (List String)
    | StudentFormSaving { name : String }


type ChangeRequestFormState
    = ChangeRequestFormHidden
    | ChangeRequestFormOpen
        { studentName : String
        , changeType : String
        , notes : String
        }
        (List String)
    | ChangeRequestFormSaving
        { studentName : String
        , changeType : String
        , notes : String
        }


type CoCoachFormState
    = CoCoachFormHidden
    | CoCoachFormOpen { name : String, email : String } (List String)
    | CoCoachFormSaving { name : String, email : String }


type AttorneyFormState
    = AttorneyFormHidden
    | AttorneyFormOpen { name : String, contact : String } (List String)
    | AttorneyFormSaving { name : String, contact : String }


emptyTeamData : Api.Team -> TeamData
emptyTeamData team =
    { team = team
    , tournament = Loading
    , entries = Loading
    , changeRequests = Loading
    , coCoaches = Loading
    , attorneyCoaches = Loading
    , studentForm = StudentFormHidden
    , changeRequestForm = ChangeRequestFormHidden
    , coCoachForm = CoCoachFormHidden
    , attorneyForm = AttorneyFormHidden
    }


init : Shared.Model.Model -> () -> ( Model, Effect Msg )
init shared _ =
    let
        coachId =
            case shared.coachAuth of
                LoggedIn creds ->
                    creds.user.id

                NotLoggedIn ->
                    ""
    in
    ( { state = LoadingTeam }
    , Pb.publicList
        { collection = "teams"
        , tag = "my-team"
        , filter = "coach = '" ++ coachId ++ "'"
        , sort = ""
        }
    )



-- UPDATE


type Msg
    = ShowStudentForm
    | UpdateStudentName String
    | SaveStudent
    | CancelStudentForm
    | RemoveEntry String
    | ShowChangeRequestForm String String
    | ShowAddChangeRequestForm
    | UpdateChangeRequestStudentName String
    | UpdateChangeRequestType String
    | UpdateChangeRequestNotes String
    | SaveChangeRequest
    | CancelChangeRequestForm
    | ShowCoCoachForm
    | UpdateCoCoachName String
    | UpdateCoCoachEmail String
    | SaveCoCoach
    | CancelCoCoachForm
    | RemoveCoCoach String
    | ShowAttorneyForm
    | UpdateAttorneyName String
    | UpdateAttorneyContact String
    | SaveAttorney
    | CancelAttorneyForm
    | RemoveAttorney String
    | PbMsg Json.Decode.Value


update : Msg -> Model -> ( Model, Effect Msg )
update msg model =
    case model.state of
        TeamReady data ->
            let
                ( newData, effect ) =
                    updateTeamData msg data
            in
            ( { model | state = TeamReady newData }, effect )

        _ ->
            case msg of
                PbMsg value ->
                    handleInitialPbMsg value model

                _ ->
                    ( model, Effect.none )


handleInitialPbMsg : Json.Decode.Value -> Model -> ( Model, Effect Msg )
handleInitialPbMsg value model =
    case Pb.responseTag value of
        Just "my-team" ->
            case Pb.decodeList Api.teamDecoder value of
                Ok (team :: _) ->
                    let
                        data =
                            emptyTeamData team

                        teamId =
                            team.id

                        tournamentId =
                            team.tournament
                    in
                    ( { model | state = TeamReady data }
                    , Effect.batch
                        [ Pb.publicList
                            { collection = "tournaments"
                            , tag = "tournament"
                            , filter = "id = '" ++ tournamentId ++ "'"
                            , sort = ""
                            }
                        , Pb.publicList
                            { collection = "eligibility_list_entries"
                            , tag = "entries"
                            , filter =
                                "team = '"
                                    ++ teamId
                                    ++ "' && status = 'active'"
                            , sort = "name"
                            }
                        , Pb.publicList
                            { collection = "eligibility_change_requests"
                            , tag = "change-requests"
                            , filter = "team = '" ++ teamId ++ "'"
                            , sort = "-created"
                            }
                        , Pb.publicList
                            { collection = "co_coaches"
                            , tag = "co-coaches"
                            , filter = "team = '" ++ teamId ++ "'"
                            , sort = "name"
                            }
                        , Pb.publicList
                            { collection = "attorney_coaches"
                            , tag = "attorney-coaches"
                            , filter = "team = '" ++ teamId ++ "'"
                            , sort = "name"
                            }
                        ]
                    )

                Ok [] ->
                    ( { model | state = TeamNotFound }, Effect.none )

                Err _ ->
                    ( { model | state = LoadFailed "Failed to load team." }
                    , Effect.none
                    )

        _ ->
            ( model, Effect.none )


updateTeamData : Msg -> TeamData -> ( TeamData, Effect Msg )
updateTeamData msg data =
    case msg of
        PbMsg value ->
            handleTeamPbMsg value data

        ShowStudentForm ->
            ( { data
                | studentForm =
                    StudentFormOpen { name = "" } []
              }
            , Effect.none
            )

        UpdateStudentName val ->
            case data.studentForm of
                StudentFormOpen _ _ ->
                    ( { data
                        | studentForm =
                            StudentFormOpen { name = val } []
                      }
                    , Effect.none
                    )

                _ ->
                    ( data, Effect.none )

        SaveStudent ->
            case data.studentForm of
                StudentFormOpen { name } _ ->
                    let
                        trimmed =
                            String.trim name
                    in
                    if String.isEmpty trimmed then
                        ( { data
                            | studentForm =
                                StudentFormOpen
                                    { name = name }
                                    [ "Name is required." ]
                          }
                        , Effect.none
                        )

                    else
                        ( { data
                            | studentForm =
                                StudentFormSaving { name = trimmed }
                          }
                        , Pb.publicCreate
                            { collection = "eligibility_list_entries"
                            , tag = "save-entry"
                            , body =
                                Api.encodeEligibilityEntry
                                    { team = data.team.id
                                    , tournament = data.team.tournament
                                    , name = trimmed
                                    }
                            }
                        )

                _ ->
                    ( data, Effect.none )

        CancelStudentForm ->
            ( { data | studentForm = StudentFormHidden }, Effect.none )

        RemoveEntry entryId ->
            ( data
            , Pb.publicDelete
                { collection = "eligibility_list_entries"
                , id = entryId
                , tag = "delete-entry"
                }
            )

        ShowChangeRequestForm studentName changeType ->
            ( { data
                | changeRequestForm =
                    ChangeRequestFormOpen
                        { studentName = studentName
                        , changeType = changeType
                        , notes = ""
                        }
                        []
              }
            , Effect.none
            )

        ShowAddChangeRequestForm ->
            ( { data
                | changeRequestForm =
                    ChangeRequestFormOpen
                        { studentName = ""
                        , changeType = "add"
                        , notes = ""
                        }
                        []
              }
            , Effect.none
            )

        UpdateChangeRequestStudentName val ->
            case data.changeRequestForm of
                ChangeRequestFormOpen fields _ ->
                    ( { data
                        | changeRequestForm =
                            ChangeRequestFormOpen
                                { fields | studentName = val }
                                []
                      }
                    , Effect.none
                    )

                _ ->
                    ( data, Effect.none )

        UpdateChangeRequestType val ->
            case data.changeRequestForm of
                ChangeRequestFormOpen fields _ ->
                    ( { data
                        | changeRequestForm =
                            ChangeRequestFormOpen
                                { fields | changeType = val }
                                []
                      }
                    , Effect.none
                    )

                _ ->
                    ( data, Effect.none )

        UpdateChangeRequestNotes val ->
            case data.changeRequestForm of
                ChangeRequestFormOpen fields _ ->
                    ( { data
                        | changeRequestForm =
                            ChangeRequestFormOpen
                                { fields | notes = val }
                                []
                      }
                    , Effect.none
                    )

                _ ->
                    ( data, Effect.none )

        SaveChangeRequest ->
            case data.changeRequestForm of
                ChangeRequestFormOpen fields _ ->
                    let
                        trimmedName =
                            String.trim fields.studentName

                        errors =
                            (if String.isEmpty trimmedName then
                                [ "Student name is required." ]

                             else
                                []
                            )
                                ++ (if String.isEmpty fields.changeType then
                                        [ "Change type is required." ]

                                    else
                                        []
                                   )
                    in
                    if not (List.isEmpty errors) then
                        ( { data
                            | changeRequestForm =
                                ChangeRequestFormOpen fields errors
                          }
                        , Effect.none
                        )

                    else
                        ( { data
                            | changeRequestForm =
                                ChangeRequestFormSaving
                                    { fields | studentName = trimmedName }
                          }
                        , Pb.publicCreate
                            { collection = "eligibility_change_requests"
                            , tag = "save-change-request"
                            , body =
                                Api.encodeChangeRequest
                                    { team = data.team.id
                                    , studentName = trimmedName
                                    , changeType = fields.changeType
                                    , notes = fields.notes
                                    }
                            }
                        )

                _ ->
                    ( data, Effect.none )

        CancelChangeRequestForm ->
            ( { data | changeRequestForm = ChangeRequestFormHidden }
            , Effect.none
            )

        ShowCoCoachForm ->
            ( { data
                | coCoachForm =
                    CoCoachFormOpen { name = "", email = "" } []
              }
            , Effect.none
            )

        UpdateCoCoachName val ->
            case data.coCoachForm of
                CoCoachFormOpen fields _ ->
                    ( { data
                        | coCoachForm =
                            CoCoachFormOpen { fields | name = val } []
                      }
                    , Effect.none
                    )

                _ ->
                    ( data, Effect.none )

        UpdateCoCoachEmail val ->
            case data.coCoachForm of
                CoCoachFormOpen fields _ ->
                    ( { data
                        | coCoachForm =
                            CoCoachFormOpen
                                { fields | email = val }
                                []
                      }
                    , Effect.none
                    )

                _ ->
                    ( data, Effect.none )

        SaveCoCoach ->
            case data.coCoachForm of
                CoCoachFormOpen fields _ ->
                    let
                        trimmed =
                            String.trim fields.name
                    in
                    if String.isEmpty trimmed then
                        ( { data
                            | coCoachForm =
                                CoCoachFormOpen
                                    fields
                                    [ "Name is required." ]
                          }
                        , Effect.none
                        )

                    else
                        ( { data
                            | coCoachForm =
                                CoCoachFormSaving
                                    { fields | name = trimmed }
                          }
                        , Pb.publicCreate
                            { collection = "co_coaches"
                            , tag = "save-co-coach"
                            , body =
                                Api.encodeCoCoach
                                    { team = data.team.id
                                    , name = trimmed
                                    , email = fields.email
                                    }
                            }
                        )

                _ ->
                    ( data, Effect.none )

        CancelCoCoachForm ->
            ( { data | coCoachForm = CoCoachFormHidden }, Effect.none )

        RemoveCoCoach coCoachId ->
            ( data
            , Pb.publicDelete
                { collection = "co_coaches"
                , id = coCoachId
                , tag = "delete-co-coach"
                }
            )

        ShowAttorneyForm ->
            ( { data
                | attorneyForm =
                    AttorneyFormOpen
                        { name = "", contact = "" }
                        []
              }
            , Effect.none
            )

        UpdateAttorneyName val ->
            case data.attorneyForm of
                AttorneyFormOpen fields _ ->
                    ( { data
                        | attorneyForm =
                            AttorneyFormOpen
                                { fields | name = val }
                                []
                      }
                    , Effect.none
                    )

                _ ->
                    ( data, Effect.none )

        UpdateAttorneyContact val ->
            case data.attorneyForm of
                AttorneyFormOpen fields _ ->
                    ( { data
                        | attorneyForm =
                            AttorneyFormOpen
                                { fields | contact = val }
                                []
                      }
                    , Effect.none
                    )

                _ ->
                    ( data, Effect.none )

        SaveAttorney ->
            case data.attorneyForm of
                AttorneyFormOpen fields _ ->
                    let
                        trimmed =
                            String.trim fields.name
                    in
                    if String.isEmpty trimmed then
                        ( { data
                            | attorneyForm =
                                AttorneyFormOpen
                                    fields
                                    [ "Name is required." ]
                          }
                        , Effect.none
                        )

                    else
                        ( { data
                            | attorneyForm =
                                AttorneyFormSaving
                                    { fields | name = trimmed }
                          }
                        , Pb.publicCreate
                            { collection = "attorney_coaches"
                            , tag = "save-attorney"
                            , body =
                                Api.encodeAttorneyCoach
                                    { team = data.team.id
                                    , name = trimmed
                                    , contact = fields.contact
                                    }
                            }
                        )

                _ ->
                    ( data, Effect.none )

        CancelAttorneyForm ->
            ( { data | attorneyForm = AttorneyFormHidden }, Effect.none )

        RemoveAttorney attorneyId ->
            ( data
            , Pb.publicDelete
                { collection = "attorney_coaches"
                , id = attorneyId
                , tag = "delete-attorney"
                }
            )


handleTeamPbMsg : Json.Decode.Value -> TeamData -> ( TeamData, Effect Msg )
handleTeamPbMsg value data =
    case Pb.responseTag value of
        Just "tournament" ->
            case Pb.decodeList Api.tournamentDecoder value of
                Ok (t :: _) ->
                    ( { data | tournament = Succeeded t }
                    , Effect.none
                    )

                Ok [] ->
                    ( { data | tournament = Failed "Tournament not found." }
                    , Effect.none
                    )

                Err _ ->
                    ( { data
                        | tournament = Failed "Failed to load tournament."
                      }
                    , Effect.none
                    )

        Just "entries" ->
            case Pb.decodeList Api.eligibilityEntryDecoder value of
                Ok entries ->
                    ( { data | entries = Succeeded entries }, Effect.none )

                Err _ ->
                    ( { data
                        | entries = Failed "Failed to load eligibility list."
                      }
                    , Effect.none
                    )

        Just "change-requests" ->
            case Pb.decodeList Api.changeRequestDecoder value of
                Ok requests ->
                    ( { data | changeRequests = Succeeded requests }
                    , Effect.none
                    )

                Err _ ->
                    ( { data
                        | changeRequests =
                            Failed "Failed to load change requests."
                      }
                    , Effect.none
                    )

        Just "co-coaches" ->
            case Pb.decodeList Api.coCoachDecoder value of
                Ok coaches ->
                    ( { data | coCoaches = Succeeded coaches }, Effect.none )

                Err _ ->
                    ( { data
                        | coCoaches = Failed "Failed to load co-coaches."
                      }
                    , Effect.none
                    )

        Just "attorney-coaches" ->
            case Pb.decodeList Api.attorneyCoachDecoder value of
                Ok coaches ->
                    ( { data | attorneyCoaches = Succeeded coaches }
                    , Effect.none
                    )

                Err _ ->
                    ( { data
                        | attorneyCoaches =
                            Failed "Failed to load attorney coaches."
                      }
                    , Effect.none
                    )

        Just "save-entry" ->
            case Pb.decodeRecord Api.eligibilityEntryDecoder value of
                Ok entry ->
                    ( { data
                        | entries =
                            mapSucceeded
                                (\es -> es ++ [ entry ])
                                data.entries
                        , studentForm = StudentFormHidden
                      }
                    , Effect.none
                    )

                Err _ ->
                    ( { data
                        | studentForm =
                            case data.studentForm of
                                StudentFormSaving fields ->
                                    StudentFormOpen fields
                                        [ "Failed to save student." ]

                                other ->
                                    other
                      }
                    , Effect.none
                    )

        Just "delete-entry" ->
            case Pb.decodeDelete value of
                Ok deletedId ->
                    ( { data
                        | entries =
                            mapSucceeded
                                (List.filter (\e -> e.id /= deletedId))
                                data.entries
                      }
                    , Effect.none
                    )

                Err _ ->
                    ( data, Effect.none )

        Just "save-change-request" ->
            case Pb.decodeRecord Api.changeRequestDecoder value of
                Ok req ->
                    ( { data
                        | changeRequests =
                            mapSucceeded
                                (\rs -> [ req ] ++ rs)
                                data.changeRequests
                        , changeRequestForm = ChangeRequestFormHidden
                      }
                    , Effect.none
                    )

                Err _ ->
                    ( { data
                        | changeRequestForm =
                            case data.changeRequestForm of
                                ChangeRequestFormSaving fields ->
                                    ChangeRequestFormOpen fields
                                        [ "Failed to submit request." ]

                                other ->
                                    other
                      }
                    , Effect.none
                    )

        Just "save-co-coach" ->
            case Pb.decodeRecord Api.coCoachDecoder value of
                Ok c ->
                    ( { data
                        | coCoaches =
                            mapSucceeded (\cs -> cs ++ [ c ]) data.coCoaches
                        , coCoachForm = CoCoachFormHidden
                      }
                    , Effect.none
                    )

                Err _ ->
                    ( { data
                        | coCoachForm =
                            case data.coCoachForm of
                                CoCoachFormSaving fields ->
                                    CoCoachFormOpen fields
                                        [ "Failed to save co-coach." ]

                                other ->
                                    other
                      }
                    , Effect.none
                    )

        Just "delete-co-coach" ->
            case Pb.decodeDelete value of
                Ok deletedId ->
                    ( { data
                        | coCoaches =
                            mapSucceeded
                                (List.filter (\c -> c.id /= deletedId))
                                data.coCoaches
                      }
                    , Effect.none
                    )

                Err _ ->
                    ( data, Effect.none )

        Just "save-attorney" ->
            case Pb.decodeRecord Api.attorneyCoachDecoder value of
                Ok c ->
                    ( { data
                        | attorneyCoaches =
                            mapSucceeded
                                (\cs -> cs ++ [ c ])
                                data.attorneyCoaches
                        , attorneyForm = AttorneyFormHidden
                      }
                    , Effect.none
                    )

                Err _ ->
                    ( { data
                        | attorneyForm =
                            case data.attorneyForm of
                                AttorneyFormSaving fields ->
                                    AttorneyFormOpen fields
                                        [ "Failed to save attorney coach." ]

                                other ->
                                    other
                      }
                    , Effect.none
                    )

        Just "delete-attorney" ->
            case Pb.decodeDelete value of
                Ok deletedId ->
                    ( { data
                        | attorneyCoaches =
                            mapSucceeded
                                (List.filter (\c -> c.id /= deletedId))
                                data.attorneyCoaches
                      }
                    , Effect.none
                    )

                Err _ ->
                    ( data, Effect.none )

        _ ->
            ( data, Effect.none )


mapSucceeded : (a -> a) -> RemoteData a -> RemoteData a
mapSucceeded f rd =
    case rd of
        Succeeded a ->
            Succeeded (f a)

        other ->
            other



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    Pb.subscribe PbMsg



-- VIEW


view : Model -> View Msg
view model =
    { title = "Manage Team"
    , body =
        case model.state of
            LoadingTeam ->
                [ UI.loading ]

            TeamNotFound ->
                [ UI.emptyState "No team found for your account." ]

            LoadFailed err ->
                [ UI.error err ]

            TeamReady data ->
                viewTeam data
    }


viewTeam : TeamData -> List (Html Msg)
viewTeam data =
    let
        locked =
            case data.tournament of
                Succeeded t ->
                    isLocked t

                _ ->
                    False
    in
    [ UI.titleBar
        { title = "Manage Team — " ++ data.team.name
        , actions = []
        }
    , viewEligibilitySection locked data
    , viewCoachesSection data
    ]


isLocked : Api.Tournament -> Bool
isLocked t =
    case t.eligibilityLockedAt of
        Nothing ->
            False

        Just "" ->
            False

        Just _ ->
            True


viewEligibilitySection : Bool -> TeamData -> Html Msg
viewEligibilitySection locked data =
    div []
        (if locked then
            [ viewLockedEligibilityList data
            , viewChangeRequests data
            ]

         else
            [ viewUnlockedEligibilityList data ]
        )


viewUnlockedEligibilityList : TeamData -> Html Msg
viewUnlockedEligibilityList data =
    case data.entries of
        Loading ->
            UI.loading

        Failed err ->
            UI.error err

        Succeeded entries ->
            UI.card
                [ UI.cardBody
                    [ UI.cardTitle
                        ("Eligibility List ("
                            ++ String.fromInt (List.length entries)
                            ++ " students)"
                        )
                    , viewStudentForm data.studentForm
                    , if List.isEmpty entries then
                        UI.emptyState "No students added yet."

                      else
                        div [ Attr.class "overflow-x-auto mt-4" ]
                            [ table [ Attr.class "table table-zebra w-full" ]
                                [ thead []
                                    [ tr []
                                        [ th [] [ text "Name" ]
                                        , th [] []
                                        ]
                                    ]
                                , tbody []
                                    (List.map viewEditableEntryRow entries)
                                ]
                            ]
                    , if data.studentForm == StudentFormHidden then
                        div [ Attr.class "mt-4" ]
                            [ button
                                [ Attr.class "btn btn-sm btn-outline"
                                , Events.onClick ShowStudentForm
                                ]
                                [ text "+ Add Student" ]
                            ]

                      else
                        UI.empty
                    ]
                ]


viewStudentForm : StudentFormState -> Html Msg
viewStudentForm formState =
    case formState of
        StudentFormHidden ->
            UI.empty

        StudentFormOpen { name } errors ->
            Html.form
                [ Events.onSubmit SaveStudent
                , Attr.class "mt-4"
                ]
                [ UI.errorList errors
                , div [ Attr.class "flex gap-2 items-end" ]
                    [ label [ Attr.class "form-control flex-1" ]
                        [ div [ Attr.class "label" ]
                            [ span [ Attr.class "label-text" ]
                                [ text "Student Name" ]
                            ]
                        , input
                            [ Attr.class "input input-bordered w-full"
                            , Attr.type_ "text"
                            , Attr.value name
                            , Attr.placeholder "Full name"
                            , Events.onInput UpdateStudentName
                            , Attr.autofocus True
                            ]
                            []
                        ]
                    , button
                        [ Attr.class "btn btn-primary"
                        , Attr.type_ "submit"
                        ]
                        [ text "Add" ]
                    , button
                        [ Attr.class "btn btn-ghost"
                        , Attr.type_ "button"
                        , Events.onClick CancelStudentForm
                        ]
                        [ text "Cancel" ]
                    ]
                ]

        StudentFormSaving _ ->
            div [ Attr.class "mt-4 flex items-center gap-2" ]
                [ span [ Attr.class "loading loading-spinner loading-sm" ] []
                , text "Saving..."
                ]


viewEditableEntryRow : Api.EligibilityEntry -> Html Msg
viewEditableEntryRow entry =
    tr []
        [ td [] [ text entry.name ]
        , td []
            [ button
                [ Attr.class "btn btn-sm btn-ghost"
                , Events.onClick (RemoveEntry entry.id)
                ]
                [ text "Remove" ]
            ]
        ]


viewLockedEligibilityList : TeamData -> Html Msg
viewLockedEligibilityList data =
    case data.entries of
        Loading ->
            UI.loading

        Failed err ->
            UI.error err

        Succeeded entries ->
            UI.card
                [ UI.cardBody
                    [ UI.cardTitle
                        ("Eligibility List — Locked ("
                            ++ String.fromInt (List.length entries)
                            ++ " students)"
                        )
                    , div [ Attr.class "alert alert-info mb-4" ]
                        [ text
                            ("The eligibility list is locked. "
                                ++ "To request a change, use the buttons below."
                            )
                        ]
                    , viewChangeRequestForm data.changeRequestForm
                    , if List.isEmpty entries then
                        UI.emptyState "No students on the eligibility list."

                      else
                        div [ Attr.class "overflow-x-auto mt-4" ]
                            [ table [ Attr.class "table table-zebra w-full" ]
                                [ thead []
                                    [ tr []
                                        [ th [] [ text "Name" ]
                                        , th [] []
                                        ]
                                    ]
                                , tbody []
                                    (List.map viewLockedEntryRow entries)
                                ]
                            ]
                    , if data.changeRequestForm == ChangeRequestFormHidden then
                        div [ Attr.class "mt-4 flex gap-2" ]
                            [ button
                                [ Attr.class "btn btn-sm btn-outline"
                                , Events.onClick ShowAddChangeRequestForm
                                ]
                                [ text "+ Request: Add Student" ]
                            ]

                      else
                        UI.empty
                    ]
                ]


viewLockedEntryRow : Api.EligibilityEntry -> Html Msg
viewLockedEntryRow entry =
    tr []
        [ td [] [ text entry.name ]
        , td []
            [ button
                [ Attr.class "btn btn-sm btn-ghost"
                , Events.onClick
                    (ShowChangeRequestForm entry.name "remove")
                ]
                [ text "Request Remove" ]
            ]
        ]


viewChangeRequestForm : ChangeRequestFormState -> Html Msg
viewChangeRequestForm formState =
    case formState of
        ChangeRequestFormHidden ->
            UI.empty

        ChangeRequestFormOpen fields errors ->
            Html.form
                [ Events.onSubmit SaveChangeRequest
                , Attr.class "mt-4"
                ]
                [ UI.cardTitle "Request Change"
                , UI.errorList errors
                , div [ Attr.class "grid grid-cols-1 md:grid-cols-2 gap-4" ]
                    [ label [ Attr.class "form-control w-full" ]
                        [ div [ Attr.class "label" ]
                            [ span [ Attr.class "label-text" ]
                                [ text "Student Name" ]
                            ]
                        , input
                            [ Attr.class "input input-bordered w-full"
                            , Attr.type_ "text"
                            , Attr.value fields.studentName
                            , Events.onInput UpdateChangeRequestStudentName
                            ]
                            []
                        ]
                    , label [ Attr.class "form-control w-full" ]
                        [ div [ Attr.class "label" ]
                            [ span [ Attr.class "label-text" ]
                                [ text "Request Type" ]
                            ]
                        , select
                            [ Attr.class "select select-bordered w-full"
                            , Events.onInput UpdateChangeRequestType
                            ]
                            [ option
                                [ Attr.value "add"
                                , Attr.selected (fields.changeType == "add")
                                ]
                                [ text "Add student" ]
                            , option
                                [ Attr.value "remove"
                                , Attr.selected (fields.changeType == "remove")
                                ]
                                [ text "Remove student" ]
                            ]
                        ]
                    ]
                , label [ Attr.class "form-control w-full mt-4" ]
                    [ div [ Attr.class "label" ]
                        [ span [ Attr.class "label-text" ]
                            [ text "Notes (optional)" ]
                        ]
                    , textarea
                        [ Attr.class "textarea textarea-bordered w-full"
                        , Attr.value fields.notes
                        , Attr.placeholder "Reason for the request"
                        , Events.onInput UpdateChangeRequestNotes
                        ]
                        []
                    ]
                , div [ Attr.class "mt-4 flex gap-2" ]
                    [ button
                        [ Attr.class "btn btn-primary"
                        , Attr.type_ "submit"
                        ]
                        [ text "Submit Request" ]
                    , button
                        [ Attr.class "btn btn-ghost"
                        , Attr.type_ "button"
                        , Events.onClick CancelChangeRequestForm
                        ]
                        [ text "Cancel" ]
                    ]
                ]

        ChangeRequestFormSaving _ ->
            div [ Attr.class "mt-4 flex items-center gap-2" ]
                [ span [ Attr.class "loading loading-spinner loading-sm" ] []
                , text "Submitting..."
                ]


viewChangeRequests : TeamData -> Html Msg
viewChangeRequests data =
    case data.changeRequests of
        Loading ->
            UI.empty

        Failed err ->
            UI.error err

        Succeeded [] ->
            UI.empty

        Succeeded requests ->
            UI.card
                [ UI.cardBody
                    [ UI.cardTitle "Change Requests"
                    , div [ Attr.class "overflow-x-auto" ]
                        [ table [ Attr.class "table table-zebra w-full" ]
                            [ thead []
                                [ tr []
                                    [ th [] [ text "Student" ]
                                    , th [] [ text "Type" ]
                                    , th [] [ text "Notes" ]
                                    , th [] [ text "Status" ]
                                    ]
                                ]
                            , tbody []
                                (List.map viewChangeRequestRow requests)
                            ]
                        ]
                    ]
                ]


viewChangeRequestRow : Api.ChangeRequest -> Html Msg
viewChangeRequestRow req =
    tr []
        [ td [] [ text req.studentName ]
        , td []
            [ text
                (if req.changeType == "add" then
                    "Add"

                 else
                    "Remove"
                )
            ]
        , td [] [ text req.notes ]
        , td [] [ viewChangeRequestBadge req.status ]
        ]


viewChangeRequestBadge : String -> Html msg
viewChangeRequestBadge status =
    case status of
        "pending" ->
            UI.badge { label = "Pending", variant = "warning" }

        "approved" ->
            UI.badge { label = "Approved", variant = "success" }

        "rejected" ->
            UI.badge { label = "Rejected", variant = "error" }

        _ ->
            UI.badge { label = status, variant = "ghost" }


viewCoachesSection : TeamData -> Html Msg
viewCoachesSection data =
    div [ Attr.class "grid grid-cols-1 md:grid-cols-2 gap-4 mt-4" ]
        [ viewCoCoachesCard data
        , viewAttorneyCoachesCard data
        ]


viewCoCoachesCard : TeamData -> Html Msg
viewCoCoachesCard data =
    UI.card
        [ UI.cardBody
            [ UI.cardTitle "Co-Teacher Coaches"
            , viewCoCoachForm data.coCoachForm
            , case data.coCoaches of
                Loading ->
                    UI.loading

                Failed err ->
                    UI.error err

                Succeeded [] ->
                    UI.emptyState "No co-coaches added."

                Succeeded coaches ->
                    div [ Attr.class "overflow-x-auto mt-2" ]
                        [ table [ Attr.class "table table-zebra w-full" ]
                            [ thead []
                                [ tr []
                                    [ th [] [ text "Name" ]
                                    , th [] [ text "Email" ]
                                    , th [] []
                                    ]
                                ]
                            , tbody []
                                (List.map viewCoCoachRow coaches)
                            ]
                        ]
            , if data.coCoachForm == CoCoachFormHidden then
                div [ Attr.class "mt-4" ]
                    [ button
                        [ Attr.class "btn btn-sm btn-outline"
                        , Events.onClick ShowCoCoachForm
                        ]
                        [ text "+ Add Co-Coach" ]
                    ]

              else
                UI.empty
            ]
        ]


viewCoCoachForm : CoCoachFormState -> Html Msg
viewCoCoachForm formState =
    case formState of
        CoCoachFormHidden ->
            UI.empty

        CoCoachFormOpen fields errors ->
            Html.form
                [ Events.onSubmit SaveCoCoach, Attr.class "mt-4" ]
                [ UI.errorList errors
                , div [ Attr.class "grid grid-cols-1 gap-2" ]
                    [ label [ Attr.class "form-control w-full" ]
                        [ div [ Attr.class "label" ]
                            [ span [ Attr.class "label-text" ] [ text "Name" ] ]
                        , input
                            [ Attr.class "input input-bordered w-full"
                            , Attr.type_ "text"
                            , Attr.value fields.name
                            , Events.onInput UpdateCoCoachName
                            ]
                            []
                        ]
                    , label [ Attr.class "form-control w-full" ]
                        [ div [ Attr.class "label" ]
                            [ span [ Attr.class "label-text" ]
                                [ text "Email (optional)" ]
                            ]
                        , input
                            [ Attr.class "input input-bordered w-full"
                            , Attr.type_ "email"
                            , Attr.value fields.email
                            , Events.onInput UpdateCoCoachEmail
                            ]
                            []
                        ]
                    ]
                , div [ Attr.class "mt-2 flex gap-2" ]
                    [ button
                        [ Attr.class "btn btn-sm btn-primary"
                        , Attr.type_ "submit"
                        ]
                        [ text "Add" ]
                    , button
                        [ Attr.class "btn btn-sm btn-ghost"
                        , Attr.type_ "button"
                        , Events.onClick CancelCoCoachForm
                        ]
                        [ text "Cancel" ]
                    ]
                ]

        CoCoachFormSaving _ ->
            div [ Attr.class "mt-4 flex items-center gap-2" ]
                [ span [ Attr.class "loading loading-spinner loading-sm" ] []
                , text "Saving..."
                ]


viewCoCoachRow : Api.CoCoach -> Html Msg
viewCoCoachRow c =
    tr []
        [ td [] [ text c.name ]
        , td [] [ text c.email ]
        , td []
            [ button
                [ Attr.class "btn btn-sm btn-ghost"
                , Events.onClick (RemoveCoCoach c.id)
                ]
                [ text "Remove" ]
            ]
        ]


viewAttorneyCoachesCard : TeamData -> Html Msg
viewAttorneyCoachesCard data =
    UI.card
        [ UI.cardBody
            [ UI.cardTitle "Attorney Coaches"
            , viewAttorneyForm data.attorneyForm
            , case data.attorneyCoaches of
                Loading ->
                    UI.loading

                Failed err ->
                    UI.error err

                Succeeded [] ->
                    UI.emptyState "No attorney coaches added."

                Succeeded coaches ->
                    div [ Attr.class "overflow-x-auto mt-2" ]
                        [ table [ Attr.class "table table-zebra w-full" ]
                            [ thead []
                                [ tr []
                                    [ th [] [ text "Name" ]
                                    , th [] [ text "Contact" ]
                                    , th [] []
                                    ]
                                ]
                            , tbody []
                                (List.map viewAttorneyRow coaches)
                            ]
                        ]
            , if data.attorneyForm == AttorneyFormHidden then
                div [ Attr.class "mt-4" ]
                    [ button
                        [ Attr.class "btn btn-sm btn-outline"
                        , Events.onClick ShowAttorneyForm
                        ]
                        [ text "+ Add Attorney Coach" ]
                    ]

              else
                UI.empty
            ]
        ]


viewAttorneyForm : AttorneyFormState -> Html Msg
viewAttorneyForm formState =
    case formState of
        AttorneyFormHidden ->
            UI.empty

        AttorneyFormOpen fields errors ->
            Html.form
                [ Events.onSubmit SaveAttorney, Attr.class "mt-4" ]
                [ UI.errorList errors
                , div [ Attr.class "grid grid-cols-1 gap-2" ]
                    [ label [ Attr.class "form-control w-full" ]
                        [ div [ Attr.class "label" ]
                            [ span [ Attr.class "label-text" ] [ text "Name" ] ]
                        , input
                            [ Attr.class "input input-bordered w-full"
                            , Attr.type_ "text"
                            , Attr.value fields.name
                            , Events.onInput UpdateAttorneyName
                            ]
                            []
                        ]
                    , label [ Attr.class "form-control w-full" ]
                        [ div [ Attr.class "label" ]
                            [ span [ Attr.class "label-text" ]
                                [ text "Contact (optional)" ]
                            ]
                        , input
                            [ Attr.class "input input-bordered w-full"
                            , Attr.type_ "text"
                            , Attr.value fields.contact
                            , Attr.placeholder "Phone or email"
                            , Events.onInput UpdateAttorneyContact
                            ]
                            []
                        ]
                    ]
                , div [ Attr.class "mt-2 flex gap-2" ]
                    [ button
                        [ Attr.class "btn btn-sm btn-primary"
                        , Attr.type_ "submit"
                        ]
                        [ text "Add" ]
                    , button
                        [ Attr.class "btn btn-sm btn-ghost"
                        , Attr.type_ "button"
                        , Events.onClick CancelAttorneyForm
                        ]
                        [ text "Cancel" ]
                    ]
                ]

        AttorneyFormSaving _ ->
            div [ Attr.class "mt-4 flex items-center gap-2" ]
                [ span [ Attr.class "loading loading-spinner loading-sm" ] []
                , text "Saving..."
                ]


viewAttorneyRow : Api.AttorneyCoach -> Html Msg
viewAttorneyRow c =
    tr []
        [ td [] [ text c.name ]
        , td [] [ text c.contact ]
        , td []
            [ button
                [ Attr.class "btn btn-sm btn-ghost"
                , Events.onClick (RemoveAttorney c.id)
                ]
                [ text "Remove" ]
            ]
        ]
