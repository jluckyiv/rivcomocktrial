module Pages.Admin.Rosters exposing (Model, Msg, page)

import Api exposing (Round, RosterSubmission, Team, Tournament)
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
import UI
import View exposing (View)


page : Auth.User -> Shared.Model -> Route () -> Page Model Msg
page user shared route =
    Page.new
        { init = init user
        , update = update user
        , view = view
        , subscriptions = subscriptions
        }
        |> Page.withLayout (\_ -> Layouts.Admin {})



-- MODEL


type alias Model =
    { tournaments : List Tournament
    , teams : RemoteData (List Team)
    , rounds : RemoteData (List Round)
    , submissions : RemoteData (List RosterSubmission)
    , filterTournament : String
    , filterRound : String
    }


init : Auth.User -> () -> ( Model, Effect Msg )
init user _ =
    ( { tournaments = []
      , teams = Loading
      , rounds = Loading
      , submissions = Loading
      , filterTournament = ""
      , filterRound = ""
      }
    , Effect.batch
        [ Pb.adminList { collection = "tournaments", tag = "tournaments", filter = "", sort = "" }
        , Pb.adminList { collection = "teams", tag = "teams", filter = "", sort = "name" }
        , Pb.adminList { collection = "rounds", tag = "rounds", filter = "", sort = "number" }
        , Pb.adminList { collection = "roster_submissions", tag = "submissions", filter = "", sort = "" }
        ]
    )



-- UPDATE


type Msg
    = PbMsg Json.Decode.Value
    | FilterTournamentChanged String
    | FilterRoundChanged String


update : Auth.User -> Msg -> Model -> ( Model, Effect Msg )
update user msg model =
    case msg of
        PbMsg value ->
            case Pb.responseTag value of
                Just "tournaments" ->
                    case Pb.decodeList Api.tournamentDecoder value of
                        Ok items ->
                            ( { model | tournaments = items }, Effect.none )

                        Err _ ->
                            ( model, Effect.none )

                Just "teams" ->
                    case Pb.decodeList Api.teamDecoder value of
                        Ok items ->
                            ( { model | teams = Succeeded items }, Effect.none )

                        Err _ ->
                            ( { model | teams = Failed "Failed to load teams." }, Effect.none )

                Just "rounds" ->
                    case Pb.decodeList Api.roundDecoder value of
                        Ok items ->
                            ( { model | rounds = Succeeded items }, Effect.none )

                        Err _ ->
                            ( { model | rounds = Failed "Failed to load rounds." }, Effect.none )

                Just "submissions" ->
                    case Pb.decodeList Api.rosterSubmissionDecoder value of
                        Ok items ->
                            ( { model | submissions = Succeeded items }, Effect.none )

                        Err _ ->
                            ( { model | submissions = Failed "Failed to load submissions." }, Effect.none )

                _ ->
                    ( model, Effect.none )

        FilterTournamentChanged val ->
            ( { model | filterTournament = val }, Effect.none )

        FilterRoundChanged val ->
            ( { model | filterRound = val }, Effect.none )



-- HELPERS


submissionForTeamRoundSide : String -> String -> Api.RosterSide -> List RosterSubmission -> Maybe RosterSubmission
submissionForTeamRoundSide teamId roundId side submissions =
    submissions
        |> List.filter
            (\s ->
                s.team == teamId && s.round == roundId && s.side == side
            )
        |> List.head


statusBadge : Maybe RosterSubmission -> Html Msg
statusBadge maybeSub =
    case maybeSub of
        Just sub ->
            if sub.submittedAt /= Nothing then
                UI.badge { label = "Submitted", variant = "success" }

            else
                UI.badge { label = "Draft", variant = "warning" }

        Nothing ->
            UI.badge { label = "Missing", variant = "error" }


teamName : Team -> String
teamName team =
    if team.name /= "" then
        team.name

    else
        team.id



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    Pb.subscribe PbMsg



-- VIEW


view : Model -> View Msg
view model =
    { title = "Rosters"
    , body =
        [ UI.titleBar
            { title = "Rosters"
            , actions = []
            }
        , viewFilters model
        , viewDashboard model
        ]
    }


viewFilters : Model -> Html Msg
viewFilters model =
    div [ Attr.class "flex gap-4 mb-4" ]
        [ UI.filterSelect
            { label = "Tournament:"
            , value = model.filterTournament
            , onInput = FilterTournamentChanged
            , options =
                { value = "", label = "All Tournaments" }
                    :: List.map (\t -> { value = t.id, label = t.name }) model.tournaments
            }
        , case model.rounds of
            Succeeded rounds ->
                let
                    filteredRounds =
                        if model.filterTournament == "" then
                            rounds

                        else
                            List.filter (\r -> r.tournament == model.filterTournament) rounds
                in
                UI.filterSelect
                    { label = "Round:"
                    , value = model.filterRound
                    , onInput = FilterRoundChanged
                    , options =
                        { value = "", label = "All Rounds" }
                            :: List.map
                                (\r ->
                                    { value = r.id
                                    , label = "Round " ++ String.fromInt r.number
                                    }
                                )
                                filteredRounds
                    }

            _ ->
                text ""
        ]


viewDashboard : Model -> Html Msg
viewDashboard model =
    case ( model.teams, model.rounds, model.submissions ) of
        ( Succeeded teams, Succeeded rounds, Succeeded submissions ) ->
            let
                filteredTeams =
                    if model.filterTournament == "" then
                        teams

                    else
                        List.filter (\t -> t.tournament == model.filterTournament) teams

                filteredRounds =
                    if model.filterTournament == "" then
                        rounds

                    else
                        List.filter (\r -> r.tournament == model.filterTournament) rounds

                visibleRounds =
                    if model.filterRound == "" then
                        filteredRounds

                    else
                        List.filter (\r -> r.id == model.filterRound) filteredRounds

                activeTeams =
                    List.filter (\t -> t.status == Api.TeamActive) filteredTeams
            in
            if List.isEmpty activeTeams then
                UI.emptyState "No active teams."

            else if List.isEmpty visibleRounds then
                UI.emptyState "No rounds scheduled."

            else
                viewMatrix activeTeams visibleRounds submissions

        ( Failed err, _, _ ) ->
            UI.error err

        ( _, Failed err, _ ) ->
            UI.error err

        ( _, _, Failed err ) ->
            UI.error err

        _ ->
            UI.loading


viewMatrix : List Team -> List Round -> List RosterSubmission -> Html Msg
viewMatrix teams rounds submissions =
    div [ Attr.class "overflow-x-auto" ]
        [ table [ Attr.class "table table-sm table-zebra w-full" ]
            [ thead []
                [ tr []
                    (th [] [ text "Team" ]
                        :: List.concatMap
                            (\r ->
                                [ th [ Attr.class "text-center" ]
                                    [ text ("R" ++ String.fromInt r.number)
                                    , br [] []
                                    , span [ Attr.class "text-xs font-normal" ] [ text "P" ]
                                    ]
                                , th [ Attr.class "text-center" ]
                                    [ text ("R" ++ String.fromInt r.number)
                                    , br [] []
                                    , span [ Attr.class "text-xs font-normal" ] [ text "D" ]
                                    ]
                                ]
                            )
                            rounds
                    )
                ]
            , tbody []
                (List.map (viewTeamRow rounds submissions) teams)
            ]
        ]


viewTeamRow : List Round -> List RosterSubmission -> Team -> Html Msg
viewTeamRow rounds submissions team =
    tr []
        (td [ Attr.class "font-medium" ] [ text (teamName team) ]
            :: List.concatMap
                (\round ->
                    [ td [ Attr.class "text-center" ]
                        [ statusBadge
                            (submissionForTeamRoundSide team.id round.id Api.Prosecution submissions)
                        ]
                    , td [ Attr.class "text-center" ]
                        [ statusBadge
                            (submissionForTeamRoundSide team.id round.id Api.Defense submissions)
                        ]
                    ]
                )
                rounds
        )
