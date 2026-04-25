module Pages.Admin.Registrations exposing (Model, Msg, page)

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
import UI
import View exposing (View)


page : Auth.User -> Shared.Model -> Route () -> Page Model Msg
page _ _ _ =
    Page.new
        { init = init
        , update = update
        , view = view
        , subscriptions = subscriptions
        }
        |> Page.withLayout (\_ -> Layouts.Admin {})



-- MODEL


type RemoteData a
    = Loading
    | Succeeded a
    | Failed String


type alias Model =
    { coaches : RemoteData (List Api.CoachUser)
    , teams : RemoteData (List Api.Team)
    , withdrawalRequests : RemoteData (List Api.WithdrawalRequest)
    , error : Maybe String
    }


init : () -> ( Model, Effect Msg )
init _ =
    ( { coaches = Loading
      , teams = Loading
      , withdrawalRequests = Loading
      , error = Nothing
      }
    , Effect.batch
        [ Pb.adminList
            { collection = "users"
            , tag = "coaches"
            , filter = "role='coach'"
            , sort = ""
            }
        , Pb.adminList
            { collection = "teams"
            , tag = "reg-teams"
            , filter = "coach != ''"
            , sort = "created"
            }
        , Pb.adminList
            { collection = "withdrawal_requests"
            , tag = "withdrawal-requests"
            , filter = "status = 'pending'"
            , sort = "-created"
            }
        ]
    )



-- UPDATE


type Msg
    = ApproveCoach String
    | RejectCoach String
    | DeleteCoach String
    | ApproveWithdrawal String
    | RejectWithdrawal String
    | ReactivateTeam String
    | PbMsg Json.Decode.Value


update :
    Msg
    -> Model
    -> ( Model, Effect Msg )
update msg model =
    case msg of
        ApproveCoach id ->
            ( model
            , Pb.adminUpdate
                { collection = "users"
                , id = id
                , tag = "user-status-update"
                , body =
                    Json.Encode.object
                        [ ( "status", Api.encodeCoachUserStatus Api.CoachApproved ) ]
                }
            )

        RejectCoach id ->
            ( model
            , Pb.adminUpdate
                { collection = "users"
                , id = id
                , tag = "user-status-update"
                , body =
                    Json.Encode.object
                        [ ( "status", Api.encodeCoachUserStatus Api.CoachRejected ) ]
                }
            )

        DeleteCoach id ->
            ( model
            , Pb.adminDelete
                { collection = "users"
                , id = id
                , tag = "delete-user"
                }
            )

        ApproveWithdrawal withdrawalId ->
            ( model
            , Pb.adminUpdate
                { collection = "withdrawal_requests"
                , id = withdrawalId
                , tag = "update-withdrawal"
                , body =
                    Json.Encode.object
                        [ ( "status", Api.encodeRequestStatus Api.Approved ) ]
                }
            )

        RejectWithdrawal withdrawalId ->
            ( model
            , Pb.adminUpdate
                { collection = "withdrawal_requests"
                , id = withdrawalId
                , tag = "update-withdrawal"
                , body =
                    Json.Encode.object
                        [ ( "status", Api.encodeRequestStatus Api.Rejected ) ]
                }
            )

        ReactivateTeam teamId ->
            ( model
            , Pb.adminUpdate
                { collection = "teams"
                , id = teamId
                , tag = "reactivate-team"
                , body =
                    Json.Encode.object
                        [ ( "status", Api.encodeTeamStatus Api.TeamActive ) ]
                }
            )

        PbMsg value ->
            case Pb.responseTag value of
                Just "coaches" ->
                    case Pb.decodeList Api.coachUserDecoder value of
                        Ok coaches ->
                            ( { model | coaches = Succeeded coaches }
                            , Effect.none
                            )

                        Err _ ->
                            ( { model
                                | coaches =
                                    Failed "Failed to load registrations."
                              }
                            , Effect.none
                            )

                Just "reg-teams" ->
                    case Pb.decodeList Api.teamDecoder value of
                        Ok teams ->
                            ( { model | teams = Succeeded teams }
                            , Effect.none
                            )

                        Err _ ->
                            ( { model
                                | teams = Failed "Failed to load teams."
                              }
                            , Effect.none
                            )

                Just "user-status-update" ->
                    case Pb.decodeRecord Api.coachUserDecoder value of
                        Ok updated ->
                            -- The registration hook has already synced the
                            -- team status server-side by the time this
                            -- response arrives. Update both coach and team
                            -- in the local model to reflect the new state.
                            let
                                newCoaches =
                                    case model.coaches of
                                        Succeeded coaches ->
                                            Succeeded
                                                (List.map
                                                    (\c ->
                                                        if c.id == updated.id then
                                                            updated

                                                        else
                                                            c
                                                    )
                                                    coaches
                                                )

                                        other ->
                                            other

                                expectedTeamStatus =
                                    case updated.status of
                                        Api.CoachApproved ->
                                            Just Api.TeamActive

                                        Api.CoachRejected ->
                                            Just Api.TeamRejected

                                        Api.CoachPending ->
                                            Nothing

                                newTeams =
                                    case expectedTeamStatus of
                                        Nothing ->
                                            model.teams

                                        Just newStatus ->
                                            case model.teams of
                                                Succeeded teams ->
                                                    Succeeded
                                                        (List.map
                                                            (\t ->
                                                                if t.coach == updated.id then
                                                                    { t | status = newStatus }

                                                                else
                                                                    t
                                                            )
                                                            teams
                                                        )

                                                other ->
                                                    other
                            in
                            ( { model
                                | coaches = newCoaches
                                , teams = newTeams
                              }
                            , Effect.none
                            )

                        Err _ ->
                            ( { model
                                | error = Just "Failed to update status."
                              }
                            , Effect.none
                            )

                Just "delete-user" ->
                    case Pb.decodeDelete value of
                        Ok deletedId ->
                            let
                                newCoaches =
                                    case model.coaches of
                                        Succeeded coaches ->
                                            Succeeded
                                                (List.filter
                                                    (\c -> c.id /= deletedId)
                                                    coaches
                                                )

                                        other ->
                                            other

                                newTeams =
                                    case model.teams of
                                        Succeeded teams ->
                                            Succeeded
                                                (List.filter
                                                    (\t -> t.coach /= deletedId)
                                                    teams
                                                )

                                        other ->
                                            other
                            in
                            ( { model
                                | coaches = newCoaches
                                , teams = newTeams
                              }
                            , Effect.none
                            )

                        Err _ ->
                            ( { model
                                | error = Just "Failed to delete registration."
                              }
                            , Effect.none
                            )

                Just "withdrawal-requests" ->
                    case Pb.decodeList Api.withdrawalRequestDecoder value of
                        Ok requests ->
                            ( { model | withdrawalRequests = Succeeded requests }
                            , Effect.none
                            )

                        Err _ ->
                            ( { model
                                | withdrawalRequests =
                                    Failed "Failed to load withdrawal requests."
                              }
                            , Effect.none
                            )

                Just "update-withdrawal" ->
                    case Pb.decodeRecord Api.withdrawalRequestDecoder value of
                        Ok updated ->
                            let
                                -- Remove from pending list (approved or rejected).
                                newWithdrawals =
                                    case model.withdrawalRequests of
                                        Succeeded reqs ->
                                            Succeeded
                                                (List.filter
                                                    (\r -> r.id /= updated.id)
                                                    reqs
                                                )

                                        other ->
                                            other

                                -- If approved, optimistically mark team as
                                -- withdrawn (hook does this server-side too).
                                newTeams =
                                    if updated.status == Api.Approved then
                                        case model.teams of
                                            Succeeded teams ->
                                                Succeeded
                                                    (List.map
                                                        (\t ->
                                                            if t.id == updated.team then
                                                                { t | status = Api.TeamWithdrawn }

                                                            else
                                                                t
                                                        )
                                                        teams
                                                    )

                                            other ->
                                                other

                                    else
                                        model.teams
                            in
                            ( { model
                                | withdrawalRequests = newWithdrawals
                                , teams = newTeams
                              }
                            , Effect.none
                            )

                        Err _ ->
                            ( { model
                                | error = Just "Failed to update withdrawal request."
                              }
                            , Effect.none
                            )

                Just "reactivate-team" ->
                    case Pb.decodeRecord Api.teamDecoder value of
                        Ok updated ->
                            let
                                newTeams =
                                    case model.teams of
                                        Succeeded teams ->
                                            Succeeded
                                                (List.map
                                                    (\t ->
                                                        if t.id == updated.id then
                                                            updated

                                                        else
                                                            t
                                                    )
                                                    teams
                                                )

                                        other ->
                                            other
                            in
                            ( { model | teams = newTeams }, Effect.none )

                        Err _ ->
                            ( { model
                                | error = Just "Failed to reactivate team."
                              }
                            , Effect.none
                            )

                _ ->
                    ( model, Effect.none )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    Pb.subscribe PbMsg



-- VIEW


view : Model -> View Msg
view model =
    { title = "Registrations"
    , body =
        [ UI.titleBar { title = "Registrations", actions = [] }
        , case model.error of
            Just err ->
                UI.error err

            Nothing ->
                UI.empty
        , viewPendingWithdrawals model
        , viewContent model
        ]
    }


viewPendingWithdrawals : Model -> Html Msg
viewPendingWithdrawals model =
    case model.withdrawalRequests of
        Succeeded ((_ :: _) as requests) ->
            UI.card
                [ UI.cardBody
                    [ UI.cardTitle "Pending Withdrawals"
                    , div [ Attr.class "overflow-x-auto" ]
                        [ UI.dataTable
                            { columns = [ "Team ID", "Reason", "Actions" ]
                            , rows = requests
                            , rowView = viewWithdrawalRow model.teams
                            }
                        ]
                    ]
                ]

        _ ->
            UI.empty


viewWithdrawalRow : RemoteData (List Api.Team) -> Api.WithdrawalRequest -> Html Msg
viewWithdrawalRow teamsData req =
    let
        teamName =
            case teamsData of
                Succeeded teams ->
                    teams
                        |> List.filter (\t -> t.id == req.team)
                        |> List.head
                        |> Maybe.map .name
                        |> Maybe.withDefault req.team

                _ ->
                    req.team
    in
    tr []
        [ td [] [ text teamName ]
        , td [] [ text req.reason ]
        , td []
            [ div [ Attr.class "flex gap-2" ]
                [ button
                    [ Attr.class "btn btn-sm btn-error"
                    , Events.onClick (ApproveWithdrawal req.id)
                    ]
                    [ text "Confirm" ]
                , button
                    [ Attr.class "btn btn-sm btn-ghost"
                    , Events.onClick (RejectWithdrawal req.id)
                    ]
                    [ text "Dismiss" ]
                ]
            ]
        ]


viewContent : Model -> Html Msg
viewContent model =
    case ( model.coaches, model.teams ) of
        ( Loading, _ ) ->
            UI.loading

        ( _, Loading ) ->
            UI.loading

        ( Failed err, _ ) ->
            UI.error err

        ( _, Failed err ) ->
            UI.error err

        ( Succeeded [], _ ) ->
            UI.emptyState "No registrations yet."

        ( Succeeded coaches, Succeeded teams ) ->
            UI.dataTable
                { columns =
                    [ "Coach"
                    , "Email"
                    , "Team"
                    , "User Status"
                    , "Team Status"
                    , "Actions"
                    ]
                , rows = coaches
                , rowView = viewCoachRow coaches teams
                }


viewCoachRow : List Api.CoachUser -> List Api.Team -> Api.CoachUser -> Html Msg
viewCoachRow coaches teams coach =
    let
        maybeTeam =
            teams
                |> List.filter (\t -> t.coach == coach.id)
                |> List.head

        teamName =
            maybeTeam
                |> Maybe.map .name
                |> Maybe.withDefault coach.teamName

        teamStatus =
            maybeTeam
                |> Maybe.map .status

        -- For pending coaches, check if their school already has an active
        -- team from a different coach. If so, this is a second-team
        -- registration and RCOE needs to verify the coaches are different.
        maybeExistingTeam =
            case coach.status of
                Api.CoachPending ->
                    teams
                        |> List.filter
                            (\t ->
                                t.school == coach.school
                                    && t.coach /= coach.id
                                    && t.status == Api.TeamActive
                            )
                        |> List.head

                _ ->
                    Nothing

        teamCell =
            case maybeExistingTeam of
                Nothing ->
                    td [] [ text teamName ]

                Just existingTeam ->
                    let
                        existingCoachName =
                            coaches
                                |> List.filter (\c -> c.id == existingTeam.coach)
                                |> List.head
                                |> Maybe.map .name
                                |> Maybe.withDefault "unknown"
                    in
                    td []
                        [ text teamName
                        , UI.badge { label = "2nd Team", variant = "warning" }
                        , UI.note
                            ("Same school as: "
                                ++ existingTeam.name
                                ++ " (coach: "
                                ++ existingCoachName
                                ++ ")"
                            )
                        ]
    in
    tr []
        [ td [] [ text coach.name ]
        , td [] [ text coach.email ]
        , teamCell
        , td [] [ viewUserStatusBadge coach.status ]
        , td [] [ viewTeamStatusBadge teamStatus ]
        , td [] [ viewActions coach.id coach.status maybeTeam ]
        ]


viewUserStatusBadge : Api.CoachUserStatus -> Html msg
viewUserStatusBadge s =
    case s of
        Api.CoachPending ->
            UI.badge { label = "Pending", variant = "warning" }

        Api.CoachApproved ->
            UI.badge { label = "Approved", variant = "success" }

        Api.CoachRejected ->
            UI.badge { label = "Rejected", variant = "error" }


viewTeamStatusBadge : Maybe Api.TeamStatus -> Html msg
viewTeamStatusBadge maybeStatus =
    case maybeStatus of
        Nothing ->
            UI.empty

        Just Api.TeamPending ->
            UI.badge { label = "Pending", variant = "warning" }

        Just Api.TeamActive ->
            UI.badge { label = "Active", variant = "success" }

        Just Api.TeamWithdrawn ->
            UI.badge { label = "Withdrawn", variant = "ghost" }

        Just Api.TeamRejected ->
            UI.badge { label = "Rejected", variant = "error" }


viewActions : String -> Api.CoachUserStatus -> Maybe Api.Team -> Html Msg
viewActions coachId status maybeTeam =
    let
        deleteButton =
            button
                [ Attr.class "btn btn-sm btn-ghost"
                , Events.onClick (DeleteCoach coachId)
                ]
                [ text "Delete" ]

        reactivateButton teamId =
            button
                [ Attr.class "btn btn-sm btn-outline"
                , Events.onClick (ReactivateTeam teamId)
                ]
                [ text "Reactivate" ]
    in
    case status of
        Api.CoachPending ->
            div [ Attr.class "flex gap-2" ]
                [ button
                    [ Attr.class "btn btn-sm btn-success"
                    , Events.onClick (ApproveCoach coachId)
                    ]
                    [ text "Approve" ]
                , button
                    [ Attr.class "btn btn-sm btn-error"
                    , Events.onClick (RejectCoach coachId)
                    ]
                    [ text "Reject" ]
                , deleteButton
                ]

        _ ->
            div [ Attr.class "flex gap-2" ]
                (List.filterMap identity
                    [ case maybeTeam of
                        Just t ->
                            if t.status == Api.TeamWithdrawn then
                                Just (reactivateButton t.id)

                            else
                                Nothing

                        Nothing ->
                            Nothing
                    , Just deleteButton
                    ]
                )
