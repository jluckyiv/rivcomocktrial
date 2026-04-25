module Pages.Team.Manage exposing (Model, Msg, page)

import Api
import Auth
import Effect exposing (Effect)
import Html exposing (..)
import Html.Attributes as Attr
import Html.Events as Events
import Json.Decode
import Layouts
import Page exposing (Page)
import Pb
import RemoteData exposing (RemoteData(..))
import Route exposing (Route)
import Shared
import Shared.Model exposing (CoachAuth(..))
import UI
import View exposing (View)


page : Auth.User -> Shared.Model -> Route () -> Page Model Msg
page _ shared _ =
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
    , withdrawalRequest : RemoteData (Maybe Api.WithdrawalRequest)
    , studentForm : StudentFormState
    , changeRequestForm : ChangeRequestFormState
    , coCoachForm : CoCoachFormState
    , attorneyForm : AttorneyFormState
    , withdrawalForm : WithdrawalFormState
    }


type StudentFormState
    = StudentFormHidden
    | StudentFormOpen { name : String } (List String)
    | StudentFormSaving { name : String }


type ChangeRequestFormState
    = ChangeRequestFormHidden
    | ChangeRequestFormOpen
        { studentName : String
        , changeType : Api.ChangeType
        , notes : String
        }
        (List String)
    | ChangeRequestFormSaving
        { studentName : String
        , changeType : Api.ChangeType
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


type WithdrawalFormState
    = WithdrawalFormHidden
    | WithdrawalFormOpen { reason : String }
    | WithdrawalFormSaving { reason : String }


emptyTeamData : Api.Team -> TeamData
emptyTeamData team =
    { team = team
    , tournament = Loading
    , entries = Loading
    , changeRequests = Loading
    , coCoaches = Loading
    , attorneyCoaches = Loading
    , withdrawalRequest = Loading
    , studentForm = StudentFormHidden
    , changeRequestForm = ChangeRequestFormHidden
    , coCoachForm = CoCoachFormHidden
    , attorneyForm = AttorneyFormHidden
    , withdrawalForm = WithdrawalFormHidden
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
    | ShowChangeRequestForm String Api.ChangeType
    | ShowAddChangeRequestForm
    | UpdateChangeRequestStudentName String
    | UpdateChangeRequestType Api.ChangeType
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
    | ShowWithdrawalForm
    | UpdateWithdrawalReason String
    | ConfirmWithdrawal
    | CancelWithdrawalForm
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
                        , Pb.publicList
                            { collection = "withdrawal_requests"
                            , tag = "withdrawal-requests"
                            , filter =
                                "team = '"
                                    ++ teamId
                                    ++ "' && status = 'pending'"
                            , sort = "-created"
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
                        , changeType = Api.AddStudent
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
                            if String.isEmpty trimmedName then
                                [ "Student name is required." ]

                            else
                                []
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

        ShowWithdrawalForm ->
            ( { data | withdrawalForm = WithdrawalFormOpen { reason = "" } }
            , Effect.none
            )

        UpdateWithdrawalReason val ->
            case data.withdrawalForm of
                WithdrawalFormOpen _ ->
                    ( { data | withdrawalForm = WithdrawalFormOpen { reason = val } }
                    , Effect.none
                    )

                _ ->
                    ( data, Effect.none )

        ConfirmWithdrawal ->
            case data.withdrawalForm of
                WithdrawalFormOpen fields ->
                    ( { data | withdrawalForm = WithdrawalFormSaving fields }
                    , Pb.publicCreate
                        { collection = "withdrawal_requests"
                        , tag = "save-withdrawal"
                        , body =
                            Api.encodeWithdrawalRequest
                                { team = data.team.id
                                , reason = fields.reason
                                }
                        }
                    )

                _ ->
                    ( data, Effect.none )

        CancelWithdrawalForm ->
            ( { data | withdrawalForm = WithdrawalFormHidden }, Effect.none )


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

        Just "withdrawal-requests" ->
            case Pb.decodeList Api.withdrawalRequestDecoder value of
                Ok (req :: _) ->
                    ( { data | withdrawalRequest = Succeeded (Just req) }
                    , Effect.none
                    )

                Ok [] ->
                    ( { data | withdrawalRequest = Succeeded Nothing }
                    , Effect.none
                    )

                Err _ ->
                    ( { data
                        | withdrawalRequest =
                            Failed "Failed to load withdrawal request."
                      }
                    , Effect.none
                    )

        Just "save-withdrawal" ->
            case Pb.decodeRecord Api.withdrawalRequestDecoder value of
                Ok req ->
                    ( { data
                        | withdrawalRequest = Succeeded (Just req)
                        , withdrawalForm = WithdrawalFormHidden
                      }
                    , Effect.none
                    )

                Err _ ->
                    ( { data
                        | withdrawalForm =
                            case data.withdrawalForm of
                                WithdrawalFormSaving fields ->
                                    WithdrawalFormOpen fields

                                other ->
                                    other
                      }
                    , Effect.none
                    )

        _ ->
            ( data, Effect.none )


mapSucceeded : (a -> a) -> RemoteData a -> RemoteData a
mapSucceeded =
    RemoteData.map



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

        readOnly =
            data.team.status == Api.TeamWithdrawn
    in
    [ UI.titleBar
        { title = "Manage Team — " ++ data.team.name
        , actions = []
        }
    , viewWithdrawalSection data
    , viewEligibilitySection locked readOnly data
    , viewCoachesSection readOnly data
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


changeTypeFromString : String -> Api.ChangeType
changeTypeFromString s =
    case s of
        "add" ->
            Api.AddStudent

        _ ->
            Api.RemoveStudent


viewEligibilitySection : Bool -> Bool -> TeamData -> Html Msg
viewEligibilitySection locked readOnly data =
    div []
        (if locked then
            [ viewLockedEligibilityList readOnly data
            , viewChangeRequests data
            ]

         else
            [ viewUnlockedEligibilityList readOnly data ]
        )


viewUnlockedEligibilityList : Bool -> TeamData -> Html Msg
viewUnlockedEligibilityList readOnly data =
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
                    , if readOnly then
                        UI.empty

                      else
                        viewStudentForm data.studentForm
                    , if List.isEmpty entries then
                        UI.emptyState "No students added yet."

                      else
                        UI.dataTable
                            { columns = [ "Name", "" ]
                            , rows = entries
                            , rowView = viewEditableEntryRow readOnly
                            }
                    , if not readOnly && data.studentForm == StudentFormHidden then
                        UI.actionRow
                            [ UI.smallOutlineButton
                                { label = "+ Add Student"
                                , variant = ""
                                , msg = ShowStudentForm
                                }
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
                , UI.formField "Student Name"
                    [ input
                        [ Attr.class "input input-bordered w-full"
                        , Attr.type_ "text"
                        , Attr.value name
                        , Attr.placeholder "Full name"
                        , Events.onInput UpdateStudentName
                        , Attr.autofocus True
                        ]
                        []
                    ]
                , UI.actionRow
                    [ UI.primaryButton { label = "Add", loading = False }
                    , UI.cancelButton CancelStudentForm
                    ]
                ]

        StudentFormSaving _ ->
            UI.inlineLoading "Saving..."


viewEditableEntryRow : Bool -> Api.EligibilityEntry -> Html Msg
viewEditableEntryRow readOnly entry =
    tr []
        [ td [] [ text entry.name ]
        , td []
            [ if readOnly then
                UI.empty

              else
                UI.smallButton { label = "Remove", variant = "ghost", msg = RemoveEntry entry.id }
            ]
        ]


viewLockedEligibilityList : Bool -> TeamData -> Html Msg
viewLockedEligibilityList readOnly data =
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
                    , UI.alert { variant = "info" }
                        [ text
                            ("The eligibility list is locked. "
                                ++ "To request a change, use the buttons below."
                            )
                        ]
                    , if readOnly then
                        UI.empty

                      else
                        viewChangeRequestForm data.changeRequestForm
                    , if List.isEmpty entries then
                        UI.emptyState "No students on the eligibility list."

                      else
                        UI.dataTable
                            { columns = [ "Name", "" ]
                            , rows = entries
                            , rowView = viewLockedEntryRow readOnly
                            }
                    , if not readOnly && data.changeRequestForm == ChangeRequestFormHidden then
                        UI.actionRow
                            [ UI.smallOutlineButton
                                { label = "+ Request: Add Student"
                                , variant = ""
                                , msg = ShowAddChangeRequestForm
                                }
                            ]

                      else
                        UI.empty
                    ]
                ]


viewLockedEntryRow : Bool -> Api.EligibilityEntry -> Html Msg
viewLockedEntryRow readOnly entry =
    tr []
        [ td [] [ text entry.name ]
        , td []
            [ if readOnly then
                UI.empty

              else
                UI.smallButton
                    { label = "Request Remove"
                    , variant = "ghost"
                    , msg = ShowChangeRequestForm entry.name Api.RemoveStudent
                    }
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
                , UI.formColumns
                    [ UI.textField
                        { label = "Student Name"
                        , value = fields.studentName
                        , onInput = UpdateChangeRequestStudentName
                        , required = False
                        }
                    , UI.formField "Request Type"
                        [ select
                            [ Attr.class "select select-bordered w-full"
                            , Events.onInput
                                (changeTypeFromString
                                    >> UpdateChangeRequestType
                                )
                            ]
                            [ option
                                [ Attr.value "add"
                                , Attr.selected
                                    (fields.changeType == Api.AddStudent)
                                ]
                                [ text "Add student" ]
                            , option
                                [ Attr.value "remove"
                                , Attr.selected
                                    (fields.changeType == Api.RemoveStudent)
                                ]
                                [ text "Remove student" ]
                            ]
                        ]
                    ]
                , UI.textareaField
                    { label = "Notes (optional)"
                    , value = fields.notes
                    , onInput = UpdateChangeRequestNotes
                    , rows = 3
                    , placeholder = "Reason for the request"
                    }
                , UI.actionRow
                    [ UI.primaryButton { label = "Submit Request", loading = False }
                    , UI.cancelButton CancelChangeRequestForm
                    ]
                ]

        ChangeRequestFormSaving _ ->
            UI.inlineLoading "Submitting..."


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
                    , UI.dataTable
                        { columns = [ "Student", "Type", "Notes", "Status" ]
                        , rows = requests
                        , rowView = viewChangeRequestRow
                        }
                    ]
                ]


viewChangeRequestRow : Api.ChangeRequest -> Html Msg
viewChangeRequestRow req =
    tr []
        [ td [] [ text req.studentName ]
        , td []
            [ text
                (case req.changeType of
                    Api.AddStudent ->
                        "Add"

                    Api.RemoveStudent ->
                        "Remove"
                )
            ]
        , td [] [ text req.notes ]
        , td [] [ viewChangeRequestBadge req.status ]
        ]


viewChangeRequestBadge : Api.RequestStatus -> Html msg
viewChangeRequestBadge status =
    case status of
        Api.Pending ->
            UI.badge { label = "Pending", variant = "warning" }

        Api.Approved ->
            UI.badge { label = "Approved", variant = "success" }

        Api.Rejected ->
            UI.badge { label = "Rejected", variant = "error" }


viewCoachesSection : Bool -> TeamData -> Html Msg
viewCoachesSection readOnly data =
    UI.formColumns
        [ viewCoCoachesCard readOnly data
        , viewAttorneyCoachesCard readOnly data
        ]


viewCoCoachesCard : Bool -> TeamData -> Html Msg
viewCoCoachesCard readOnly data =
    UI.card
        [ UI.cardBody
            [ UI.cardTitle "Co-Teacher Coaches"
            , if readOnly then
                UI.empty

              else
                viewCoCoachForm data.coCoachForm
            , case data.coCoaches of
                Loading ->
                    UI.loading

                Failed err ->
                    UI.error err

                Succeeded [] ->
                    UI.emptyState "No co-coaches added."

                Succeeded coaches ->
                    UI.dataTable
                        { columns = [ "Name", "Email", "" ]
                        , rows = coaches
                        , rowView = viewCoCoachRow readOnly
                        }
            , if not readOnly && data.coCoachForm == CoCoachFormHidden then
                UI.actionRow
                    [ UI.smallOutlineButton
                        { label = "+ Add Co-Coach"
                        , variant = ""
                        , msg = ShowCoCoachForm
                        }
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
                , UI.textField
                    { label = "Name"
                    , value = fields.name
                    , onInput = UpdateCoCoachName
                    , required = True
                    }
                , UI.textField
                    { label = "Email (optional)"
                    , value = fields.email
                    , onInput = UpdateCoCoachEmail
                    , required = False
                    }
                , UI.actionRow
                    [ UI.smallPrimarySubmit "Add"
                    , UI.smallCancelButton CancelCoCoachForm
                    ]
                ]

        CoCoachFormSaving _ ->
            UI.inlineLoading "Saving..."


viewCoCoachRow : Bool -> Api.CoCoach -> Html Msg
viewCoCoachRow readOnly c =
    tr []
        [ td [] [ text c.name ]
        , td [] [ text c.email ]
        , td []
            [ if readOnly then
                UI.empty

              else
                UI.smallButton { label = "Remove", variant = "ghost", msg = RemoveCoCoach c.id }
            ]
        ]


viewAttorneyCoachesCard : Bool -> TeamData -> Html Msg
viewAttorneyCoachesCard readOnly data =
    UI.card
        [ UI.cardBody
            [ UI.cardTitle "Attorney Coaches"
            , if readOnly then
                UI.empty

              else
                viewAttorneyForm data.attorneyForm
            , case data.attorneyCoaches of
                Loading ->
                    UI.loading

                Failed err ->
                    UI.error err

                Succeeded [] ->
                    UI.emptyState "No attorney coaches added."

                Succeeded coaches ->
                    UI.dataTable
                        { columns = [ "Name", "Contact", "" ]
                        , rows = coaches
                        , rowView = viewAttorneyRow readOnly
                        }
            , if not readOnly && data.attorneyForm == AttorneyFormHidden then
                UI.actionRow
                    [ UI.smallOutlineButton
                        { label = "+ Add Attorney Coach"
                        , variant = ""
                        , msg = ShowAttorneyForm
                        }
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
                , UI.textField
                    { label = "Name"
                    , value = fields.name
                    , onInput = UpdateAttorneyName
                    , required = True
                    }
                , UI.formField "Contact (optional)"
                    [ input
                        [ Attr.class "input input-bordered w-full"
                        , Attr.type_ "text"
                        , Attr.value fields.contact
                        , Attr.placeholder "Phone or email"
                        , Events.onInput UpdateAttorneyContact
                        ]
                        []
                    ]
                , UI.actionRow
                    [ UI.smallPrimarySubmit "Add"
                    , UI.smallCancelButton CancelAttorneyForm
                    ]
                ]

        AttorneyFormSaving _ ->
            UI.inlineLoading "Saving..."


viewAttorneyRow : Bool -> Api.AttorneyCoach -> Html Msg
viewAttorneyRow readOnly c =
    tr []
        [ td [] [ text c.name ]
        , td [] [ text c.contact ]
        , td []
            [ if readOnly then
                UI.empty

              else
                UI.smallButton { label = "Remove", variant = "ghost", msg = RemoveAttorney c.id }
            ]
        ]


viewWithdrawalSection : TeamData -> Html Msg
viewWithdrawalSection data =
    if data.team.status == Api.TeamWithdrawn then
        UI.alert { variant = "error" }
            [ text "This team has withdrawn from the competition." ]

    else
        case data.withdrawalRequest of
            Loading ->
                UI.empty

            Failed _ ->
                UI.empty

            Succeeded (Just _) ->
                UI.alert { variant = "warning" }
                    [ text "A withdrawal request is pending admin review." ]

            Succeeded Nothing ->
                case data.withdrawalForm of
                    WithdrawalFormHidden ->
                        UI.actionRow
                            [ UI.smallOutlineButton
                                { label = "Request Withdrawal"
                                , variant = "error"
                                , msg = ShowWithdrawalForm
                                }
                            ]

                    WithdrawalFormOpen fields ->
                        viewWithdrawalForm fields

                    WithdrawalFormSaving _ ->
                        UI.inlineLoading "Submitting..."


viewWithdrawalForm : { reason : String } -> Html Msg
viewWithdrawalForm fields =
    Html.form
        [ Events.onSubmit ConfirmWithdrawal
        , Attr.class "mt-4"
        ]
        [ UI.card
            [ UI.cardBody
                [ UI.cardTitle "Request Withdrawal"
                , UI.alert { variant = "warning" }
                    [ text
                        ("Submitting this request will notify RCOE. "
                            ++ "Your team will remain active until an admin confirms."
                        )
                    ]
                , UI.textareaField
                    { label = "Reason (optional)"
                    , value = fields.reason
                    , onInput = UpdateWithdrawalReason
                    , rows = 4
                    , placeholder = "Briefly explain why you need to withdraw"
                    }
                , UI.actionRow
                    [ UI.errorSubmitButton "Confirm Withdrawal"
                    , UI.cancelButton CancelWithdrawalForm
                    ]
                ]
            ]
        ]
