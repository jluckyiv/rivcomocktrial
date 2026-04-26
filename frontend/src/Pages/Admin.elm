module Pages.Admin exposing (Model, Msg, page)

import Api
import Auth
import Effect exposing (Effect)
import Html exposing (..)
import Html.Attributes as Attr
import Json.Decode
import Layouts
import Page exposing (Page)
import Pb
import RemoteData exposing (RemoteData(..))
import Route exposing (Route)
import Route.Path
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


type alias Model =
    { tournament : RemoteData String Api.Tournament
    , pendingCoaches : RemoteData String (List Api.CoachUser)
    , pendingWithdrawals : RemoteData String (List Api.WithdrawalRequest)
    , pendingEligibility : RemoteData String (List Api.ChangeRequest)
    , teams : RemoteData String (List Api.Team)
    }


init : () -> ( Model, Effect Msg )
init _ =
    ( { tournament = Loading
      , pendingCoaches = Loading
      , pendingWithdrawals = Loading
      , pendingEligibility = Loading
      , teams = Loading
      }
    , Pb.adminList
        { collection = "tournaments"
        , tag = "active-tournament"
        , filter = "status != 'draft' && status != 'completed'"
        , sort = "-created"
        }
    )



-- UPDATE


type Msg
    = PbMsg Json.Decode.Value


update : Msg -> Model -> ( Model, Effect Msg )
update msg model =
    case msg of
        PbMsg value ->
            case Pb.responseTag value of
                Just "active-tournament" ->
                    case Pb.decodeList Api.tournamentDecoder value of
                        Ok (tournament :: _) ->
                            let
                                phaseEffects =
                                    case tournament.status of
                                        Api.TournamentRegistration ->
                                            Effect.batch
                                                [ Pb.adminList
                                                    { collection = "users"
                                                    , tag = "pending-coaches"
                                                    , filter = "role='coach' && status='pending'"
                                                    , sort = ""
                                                    }
                                                , Pb.adminList
                                                    { collection = "withdrawal_requests"
                                                    , tag = "pending-withdrawals"
                                                    , filter = "status='pending'"
                                                    , sort = ""
                                                    }
                                                , Pb.adminList
                                                    { collection = "teams"
                                                    , tag = "dashboard-teams"
                                                    , filter = "coach != ''"
                                                    , sort = ""
                                                    }
                                                ]

                                        Api.TournamentActive ->
                                            Effect.batch
                                                [ Pb.adminList
                                                    { collection = "eligibility_change_requests"
                                                    , tag = "pending-eligibility"
                                                    , filter = "status='pending'"
                                                    , sort = ""
                                                    }
                                                , Pb.adminList
                                                    { collection = "teams"
                                                    , tag = "dashboard-teams"
                                                    , filter = "coach != ''"
                                                    , sort = ""
                                                    }
                                                ]

                                        _ ->
                                            Effect.none
                            in
                            ( { model | tournament = Success tournament }
                            , phaseEffects
                            )

                        Ok [] ->
                            ( { model | tournament = Failure "no-active" }
                            , Effect.none
                            )

                        Err _ ->
                            ( { model | tournament = Failure "Failed to load tournament." }
                            , Effect.none
                            )

                Just "pending-coaches" ->
                    case Pb.decodeList Api.coachUserDecoder value of
                        Ok coaches ->
                            ( { model | pendingCoaches = Success coaches }
                            , Effect.none
                            )

                        Err _ ->
                            ( { model | pendingCoaches = Failure "Failed to load pending coaches." }
                            , Effect.none
                            )

                Just "pending-withdrawals" ->
                    case Pb.decodeList Api.withdrawalRequestDecoder value of
                        Ok reqs ->
                            ( { model | pendingWithdrawals = Success reqs }
                            , Effect.none
                            )

                        Err _ ->
                            ( { model | pendingWithdrawals = Failure "Failed to load pending withdrawals." }
                            , Effect.none
                            )

                Just "pending-eligibility" ->
                    case Pb.decodeList Api.changeRequestDecoder value of
                        Ok reqs ->
                            ( { model | pendingEligibility = Success reqs }
                            , Effect.none
                            )

                        Err _ ->
                            ( { model | pendingEligibility = Failure "Failed to load eligibility requests." }
                            , Effect.none
                            )

                Just "dashboard-teams" ->
                    case Pb.decodeList Api.teamDecoder value of
                        Ok teams ->
                            ( { model | teams = Success teams }
                            , Effect.none
                            )

                        Err _ ->
                            ( { model | teams = Failure "Failed to load teams." }
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
    { title = "Dashboard"
    , body =
        [ UI.titleBar { title = "Dashboard", actions = [] }
        , viewBody model
        ]
    }


viewBody : Model -> Html Msg
viewBody model =
    case model.tournament of
        NotAsked ->
            UI.notAsked "Getting ready…"

        Loading ->
            UI.loading

        Failure "no-active" ->
            viewNoActiveTournament

        Failure err ->
            UI.error err

        Success tournament ->
            case tournament.status of
                Api.TournamentRegistration ->
                    viewRegistrationPhase tournament model

                Api.TournamentActive ->
                    viewActivePhase tournament model

                Api.TournamentCompleted ->
                    viewCompletedPhase tournament

                Api.TournamentDraft ->
                    viewDraftPhase tournament


viewNoActiveTournament : Html Msg
viewNoActiveTournament =
    UI.card
        [ UI.cardBody
            [ UI.cardTitle "No Active Tournament"
            , p [] [ text "Create or activate a tournament to get started." ]
            , a
                [ Route.Path.href Route.Path.Admin_Tournaments
                , Attr.class "btn btn-primary mt-4"
                ]
                [ text "Go to Tournaments" ]
            ]
        ]


viewDraftPhase : Api.Tournament -> Html Msg
viewDraftPhase tournament =
    UI.card
        [ UI.cardBody
            [ div [ Attr.class "flex items-center gap-3 mb-2" ]
                [ UI.cardTitle tournament.name
                , UI.badge { label = "Draft", variant = "neutral" }
                ]
            , p [] [ text "This tournament is in draft. Open registration when ready." ]
            , a
                [ Route.Path.href Route.Path.Admin_Tournaments
                , Attr.class "btn btn-primary mt-4"
                ]
                [ text "Manage Tournaments" ]
            ]
        ]


viewRegistrationPhase : Api.Tournament -> Model -> Html Msg
viewRegistrationPhase tournament model =
    let
        pendingCoachCount =
            model.pendingCoaches
                |> RemoteData.map List.length
                |> remoteCount

        pendingWithdrawalCount =
            model.pendingWithdrawals
                |> RemoteData.map List.length
                |> remoteCount

        activeTeamCount =
            model.teams
                |> RemoteData.map
                    (List.filter (\t -> t.status == Api.TeamActive) >> List.length)
                |> remoteCount
    in
    UI.card
        [ UI.cardBody
            [ div [ Attr.class "flex items-center gap-3 mb-4" ]
                [ UI.cardTitle tournament.name
                , UI.badge { label = "Registration", variant = "info" }
                ]
            , div [ Attr.class "stats shadow w-full" ]
                [ UI.statCard
                    { label = "Pending Approvals"
                    , value = pendingCoachCount
                    , variant =
                        if pendingCoachCount == "0" then
                            "success"

                        else
                            "warning"
                    }
                , UI.statCard
                    { label = "Active Teams"
                    , value = activeTeamCount
                    , variant = "neutral"
                    }
                , UI.statCard
                    { label = "Pending Withdrawals"
                    , value = pendingWithdrawalCount
                    , variant =
                        if pendingWithdrawalCount == "0" then
                            "neutral"

                        else
                            "warning"
                    }
                ]
            , div [ Attr.class "mt-4" ]
                [ a
                    [ Route.Path.href Route.Path.Admin_Registrations
                    , Attr.class "btn btn-outline btn-sm"
                    ]
                    [ text "View Registrations" ]
                ]
            ]
        ]


viewActivePhase : Api.Tournament -> Model -> Html Msg
viewActivePhase tournament model =
    let
        pendingEligibilityCount =
            model.pendingEligibility
                |> RemoteData.map List.length
                |> remoteCount

        activeTeamCount =
            model.teams
                |> RemoteData.map
                    (List.filter (\t -> t.status == Api.TeamActive) >> List.length)
                |> remoteCount
    in
    UI.card
        [ UI.cardBody
            [ div [ Attr.class "flex items-center gap-3 mb-4" ]
                [ UI.cardTitle tournament.name
                , UI.badge { label = "Active", variant = "success" }
                ]
            , div [ Attr.class "stats shadow w-full" ]
                [ UI.statCard
                    { label = "Pending Eligibility Requests"
                    , value = pendingEligibilityCount
                    , variant =
                        if pendingEligibilityCount == "0" then
                            "neutral"

                        else
                            "warning"
                    }
                , UI.statCard
                    { label = "Active Teams"
                    , value = activeTeamCount
                    , variant = "neutral"
                    }
                ]
            , div [ Attr.class "flex gap-2 mt-4" ]
                [ a
                    [ Route.Path.href Route.Path.Admin_EligibilityRequests
                    , Attr.class "btn btn-outline btn-sm"
                    ]
                    [ text "View Eligibility Requests" ]
                , a
                    [ Route.Path.href Route.Path.Admin_Rounds
                    , Attr.class "btn btn-outline btn-sm"
                    ]
                    [ text "View Rounds" ]
                ]
            ]
        ]


viewCompletedPhase : Api.Tournament -> Html Msg
viewCompletedPhase tournament =
    UI.card
        [ UI.cardBody
            [ div [ Attr.class "flex items-center gap-3" ]
                [ UI.cardTitle tournament.name
                , UI.badge { label = "Completed", variant = "ghost" }
                ]
            , p [ Attr.class "mt-2" ] [ text "This tournament has concluded." ]
            ]
        ]



-- HELPERS


remoteCount : RemoteData String Int -> String
remoteCount rd =
    case rd of
        NotAsked ->
            "_"

        Loading ->
            "…"

        Failure _ ->
            "?"

        Success n ->
            String.fromInt n
