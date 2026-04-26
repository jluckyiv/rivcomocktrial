module Pages.Admin.Trials exposing (AssignmentField(..), Model, Msg, applyFieldValue, fieldValue, page)

import Api exposing (Courtroom, Judge, Round, RoundStatus(..), Team, Trial)
import Auth
import Dict exposing (Dict)
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
page _ _ route =
    Page.new
        { init = init route
        , update = update
        , view = view
        , subscriptions = subscriptions
        }
        |> Page.withLayout (\_ -> Layouts.Admin {})



-- TYPES


type AssignmentField
    = JudgeField
    | ScorerField Int


type AssignmentState
    = AssignmentIdle
    | AssignmentEditing { trialId : String, field : AssignmentField, value : String }
    | AssignmentSaving String


type RoundAction
    = OpeningRound
    | LockingRound
    | UnlockingRound



-- MODEL


type alias Model =
    { roundId : String
    , round : RemoteData String Round
    , trials : RemoteData String (List Trial)
    , teams : RemoteData String (List Team)
    , courtrooms : RemoteData String (List Courtroom)
    , judges : RemoteData String (List Judge)
    , submissionCounts : Dict String Int
    , assignment : AssignmentState
    , roundAction : Maybe RoundAction
    }


init : Route () -> () -> ( Model, Effect Msg )
init route _ =
    let
        roundId =
            Dict.get "round" route.query |> Maybe.withDefault ""
    in
    ( { roundId = roundId
      , round = Loading
      , trials = Loading
      , teams = Loading
      , courtrooms = Loading
      , judges = Loading
      , submissionCounts = Dict.empty
      , assignment = AssignmentIdle
      , roundAction = Nothing
      }
    , if roundId == "" then
        Effect.none

      else
        Effect.batch
            [ Pb.adminList
                { collection = "rounds"
                , tag = "round"
                , filter = "id='" ++ roundId ++ "'"
                , sort = ""
                }
            , Pb.adminList
                { collection = "trials"
                , tag = "trials"
                , filter = "round='" ++ roundId ++ "'"
                , sort = "courtroom.name"
                }
            , Pb.adminList
                { collection = "teams"
                , tag = "teams"
                , filter = ""
                , sort = "team_number"
                }
            , Pb.adminList
                { collection = "courtrooms"
                , tag = "courtrooms"
                , filter = ""
                , sort = "name"
                }
            , Pb.adminList
                { collection = "judges"
                , tag = "judges"
                , filter = ""
                , sort = "name"
                }
            , Pb.adminList
                { collection = "ballot_submissions"
                , tag = "ballot-submissions"
                , filter = "trial.round='" ++ roundId ++ "'"
                , sort = ""
                }
            ]
    )



-- UPDATE


type Msg
    = PbMsg Json.Decode.Value
    | ClickEditField String AssignmentField
    | SelectFieldValue String
    | SaveAssignment
    | CancelAssignment
    | ClickOpenRound
    | ClickLockRound
    | ClickUnlockRound


update : Msg -> Model -> ( Model, Effect Msg )
update msg model =
    case msg of
        PbMsg value ->
            case Pb.responseTag value of
                Just "round" ->
                    case Pb.decodeList Api.roundDecoder value of
                        Ok (round :: _) ->
                            ( { model | round = Success round }, Effect.none )

                        Ok [] ->
                            ( { model | round = Failure "Round not found" }, Effect.none )

                        Err err ->
                            ( { model | round = Failure err }, Effect.none )

                Just "trials" ->
                    case Pb.decodeList Api.trialDecoder value of
                        Ok trials ->
                            ( { model | trials = Success trials }, Effect.none )

                        Err err ->
                            ( { model | trials = Failure err }, Effect.none )

                Just "teams" ->
                    case Pb.decodeList Api.teamDecoder value of
                        Ok teams ->
                            ( { model | teams = Success teams }, Effect.none )

                        Err err ->
                            ( { model | teams = Failure err }, Effect.none )

                Just "courtrooms" ->
                    case Pb.decodeList Api.courtroomDecoder value of
                        Ok courtrooms ->
                            ( { model | courtrooms = Success courtrooms }, Effect.none )

                        Err err ->
                            ( { model | courtrooms = Failure err }, Effect.none )

                Just "judges" ->
                    case Pb.decodeList Api.judgeDecoder value of
                        Ok judges ->
                            ( { model | judges = Success judges }, Effect.none )

                        Err err ->
                            ( { model | judges = Failure err }, Effect.none )

                Just "ballot-submissions" ->
                    case Pb.decodeList Api.ballotSubmissionDecoder value of
                        Ok submissions ->
                            let
                                counts =
                                    List.foldl
                                        (\sub acc ->
                                            Dict.update sub.trial
                                                (Just << (+) 1 << Maybe.withDefault 0)
                                                acc
                                        )
                                        Dict.empty
                                        submissions
                            in
                            ( { model | submissionCounts = counts }, Effect.none )

                        Err _ ->
                            ( model, Effect.none )

                Just "save-assignment" ->
                    case model.assignment of
                        AssignmentSaving trialId ->
                            case Pb.decodeRecord Api.trialDecoder value of
                                Ok updated ->
                                    ( { model
                                        | trials =
                                            RemoteData.map
                                                (List.map
                                                    (\t ->
                                                        if t.id == trialId then
                                                            updated

                                                        else
                                                            t
                                                    )
                                                )
                                                model.trials
                                        , assignment = AssignmentIdle
                                      }
                                    , Effect.none
                                    )

                                Err _ ->
                                    ( { model | assignment = AssignmentIdle }, Effect.none )

                        _ ->
                            ( model, Effect.none )

                Just "update-round-status" ->
                    case Pb.decodeRecord Api.roundDecoder value of
                        Ok round ->
                            ( { model | round = Success round, roundAction = Nothing }
                            , Effect.none
                            )

                        Err _ ->
                            ( { model | roundAction = Nothing }, Effect.none )

                _ ->
                    ( model, Effect.none )

        ClickEditField trialId field ->
            let
                currentValue =
                    case model.trials of
                        Success trials ->
                            trials
                                |> List.filter (\t -> t.id == trialId)
                                |> List.head
                                |> Maybe.map (fieldValue field)
                                |> Maybe.withDefault ""

                        _ ->
                            ""
            in
            ( { model
                | assignment =
                    AssignmentEditing
                        { trialId = trialId
                        , field = field
                        , value = currentValue
                        }
              }
            , Effect.none
            )

        SelectFieldValue value ->
            case model.assignment of
                AssignmentEditing state ->
                    ( { model | assignment = AssignmentEditing { state | value = value } }
                    , Effect.none
                    )

                _ ->
                    ( model, Effect.none )

        SaveAssignment ->
            case model.assignment of
                AssignmentEditing { trialId, field, value } ->
                    let
                        maybeTrial =
                            case model.trials of
                                Success trials ->
                                    trials
                                        |> List.filter (\t -> t.id == trialId)
                                        |> List.head

                                _ ->
                                    Nothing
                    in
                    case maybeTrial of
                        Just trial ->
                            let
                                updated =
                                    applyFieldValue field value trial
                            in
                            ( { model | assignment = AssignmentSaving trialId }
                            , Pb.adminUpdate
                                { collection = "trials"
                                , id = trialId
                                , tag = "save-assignment"
                                , body =
                                    Api.encodeTrialAssignment
                                        { judge = updated.judge
                                        , scorer1 = updated.scorer1
                                        , scorer2 = updated.scorer2
                                        , scorer3 = updated.scorer3
                                        , scorer4 = updated.scorer4
                                        , scorer5 = updated.scorer5
                                        }
                                }
                            )

                        Nothing ->
                            ( { model | assignment = AssignmentIdle }, Effect.none )

                _ ->
                    ( model, Effect.none )

        CancelAssignment ->
            ( { model | assignment = AssignmentIdle }, Effect.none )

        ClickOpenRound ->
            case model.round of
                Success round ->
                    ( { model | roundAction = Just OpeningRound }
                    , Pb.adminUpdate
                        { collection = "rounds"
                        , id = round.id
                        , tag = "update-round-status"
                        , body = Api.encodeRoundStatus Open
                        }
                    )

                _ ->
                    ( model, Effect.none )

        ClickLockRound ->
            case model.round of
                Success round ->
                    ( { model | roundAction = Just LockingRound }
                    , Pb.adminUpdate
                        { collection = "rounds"
                        , id = round.id
                        , tag = "update-round-status"
                        , body = Api.encodeRoundStatus Locked
                        }
                    )

                _ ->
                    ( model, Effect.none )

        ClickUnlockRound ->
            case model.round of
                Success round ->
                    ( { model | roundAction = Just UnlockingRound }
                    , Pb.adminUpdate
                        { collection = "rounds"
                        , id = round.id
                        , tag = "update-round-status"
                        , body = Api.encodeRoundStatus Open
                        }
                    )

                _ ->
                    ( model, Effect.none )


fieldValue : AssignmentField -> Trial -> String
fieldValue field trial =
    case field of
        JudgeField ->
            trial.judge

        ScorerField 1 ->
            trial.scorer1

        ScorerField 2 ->
            trial.scorer2

        ScorerField 3 ->
            trial.scorer3

        ScorerField 4 ->
            trial.scorer4

        ScorerField _ ->
            trial.scorer5


applyFieldValue : AssignmentField -> String -> Trial -> Trial
applyFieldValue field value trial =
    case field of
        JudgeField ->
            { trial | judge = value }

        ScorerField 1 ->
            { trial | scorer1 = value }

        ScorerField 2 ->
            { trial | scorer2 = value }

        ScorerField 3 ->
            { trial | scorer3 = value }

        ScorerField 4 ->
            { trial | scorer4 = value }

        ScorerField _ ->
            { trial | scorer5 = value }



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    Pb.subscribe PbMsg



-- VIEW


view : Model -> View Msg
view model =
    { title = "Manage Trials"
    , body =
        [ viewTitleBar model
        , viewRoundActions model
        , viewTrialsTable model
        ]
    }


viewTitleBar : Model -> Html Msg
viewTitleBar model =
    let
        title =
            case model.round of
                Success round ->
                    "Round " ++ String.fromInt round.number ++ " — " ++ round.date

                _ ->
                    "Manage Trials"
    in
    UI.backLinkTitleBar
        { title = title
        , backLabel = "← Rounds"
        , backHref = "/admin/rounds"
        }


viewRoundActions : Model -> Html Msg
viewRoundActions model =
    case model.round of
        Success round ->
            div [ Attr.class "flex items-center gap-4 mb-6" ]
                [ viewStatusBadge round.status
                , viewActionButton model.roundAction round.status
                ]

        _ ->
            text ""


viewStatusBadge : RoundStatus -> Html Msg
viewStatusBadge status =
    case status of
        Upcoming ->
            UI.badge { label = "Upcoming", variant = "neutral" }

        Open ->
            UI.badge { label = "Open", variant = "success" }

        Locked ->
            UI.badge { label = "Locked", variant = "error" }


viewActionButton : Maybe RoundAction -> RoundStatus -> Html Msg
viewActionButton action status =
    let
        loading =
            action /= Nothing
    in
    case status of
        Upcoming ->
            button
                [ Attr.class "btn btn-success btn-sm"
                , Events.onClick ClickOpenRound
                , Attr.disabled loading
                ]
                (if loading then
                    [ span [ Attr.class "loading loading-spinner loading-sm" ] [] ]

                 else
                    [ text "Open Round" ]
                )

        Open ->
            button
                [ Attr.class "btn btn-error btn-sm"
                , Events.onClick ClickLockRound
                , Attr.disabled loading
                ]
                (if loading then
                    [ span [ Attr.class "loading loading-spinner loading-sm" ] [] ]

                 else
                    [ text "Lock Round" ]
                )

        Locked ->
            button
                [ Attr.class "btn btn-warning btn-sm"
                , Events.onClick ClickUnlockRound
                , Attr.disabled loading
                ]
                (if loading then
                    [ span [ Attr.class "loading loading-spinner loading-sm" ] [] ]

                 else
                    [ text "Unlock Round" ]
                )


viewTrialsTable : Model -> Html Msg
viewTrialsTable model =
    case model.trials of
        NotAsked ->
            UI.notAsked "Getting ready…"

        Loading ->
            div [ Attr.class "text-center py-8" ]
                [ span [ Attr.class "loading loading-spinner loading-lg" ] [] ]

        Failure err ->
            div [ Attr.class "alert alert-error" ] [ text err ]

        Success trials ->
            let
                teams =
                    case model.teams of
                        Success ts ->
                            ts

                        _ ->
                            []

                courtrooms =
                    case model.courtrooms of
                        Success cs ->
                            cs

                        _ ->
                            []

                judges =
                    case model.judges of
                        Success js ->
                            js

                        _ ->
                            []

                editable =
                    case model.round of
                        Success round ->
                            round.status == Upcoming

                        _ ->
                            False

                showSubmissions =
                    case model.round of
                        Success round ->
                            round.status == Open || round.status == Locked

                        _ ->
                            False
            in
            UI.tableWrap
                (table [ Attr.class "table table-sm table-zebra w-full" ]
                    [ thead []
                        [ tr []
                            ([ th [] [ text "Courtroom" ]
                             , th [] [ text "Prosecution" ]
                             , th [] [ text "Defense" ]
                             , th [] [ text "Judge" ]
                             , th [] [ text "S1" ]
                             , th [] [ text "S2" ]
                             , th [] [ text "S3" ]
                             , th [] [ text "S4" ]
                             , th [] [ text "S5" ]
                             ]
                                ++ (if showSubmissions then
                                        [ th [] [ text "Submitted" ] ]

                                    else
                                        []
                                   )
                            )
                        ]
                    , tbody []
                        (List.map
                            (viewTrialRow
                                model.assignment
                                judges
                                teams
                                courtrooms
                                editable
                                showSubmissions
                                model.submissionCounts
                            )
                            trials
                        )
                    ]
                )


viewTrialRow :
    AssignmentState
    -> List Judge
    -> List Team
    -> List Courtroom
    -> Bool
    -> Bool
    -> Dict String Int
    -> Trial
    -> Html Msg
viewTrialRow assignmentState judges teams courtrooms editable showSubmissions submissionCounts trial =
    let
        courtroomName =
            courtrooms
                |> List.filter (\c -> c.id == trial.courtroom)
                |> List.head
                |> Maybe.map .name
                |> Maybe.withDefault "—"

        prosecutionName =
            teams
                |> List.filter (\t -> t.id == trial.prosecutionTeam)
                |> List.head
                |> Maybe.map teamLabel
                |> Maybe.withDefault "—"

        defenseName =
            teams
                |> List.filter (\t -> t.id == trial.defenseTeam)
                |> List.head
                |> Maybe.map teamLabel
                |> Maybe.withDefault "—"

        submittedCount =
            Dict.get trial.id submissionCounts |> Maybe.withDefault 0
    in
    tr []
        ([ td [] [ text courtroomName ]
         , td [] [ text prosecutionName ]
         , td [] [ text defenseName ]
         , viewAssignmentCell assignmentState judges trial JudgeField trial.judge editable
         , viewAssignmentCell assignmentState judges trial (ScorerField 1) trial.scorer1 editable
         , viewAssignmentCell assignmentState judges trial (ScorerField 2) trial.scorer2 editable
         , viewAssignmentCell assignmentState judges trial (ScorerField 3) trial.scorer3 editable
         , viewAssignmentCell assignmentState judges trial (ScorerField 4) trial.scorer4 editable
         , viewAssignmentCell assignmentState judges trial (ScorerField 5) trial.scorer5 editable
         ]
            ++ (if showSubmissions then
                    [ td [] [ text (String.fromInt submittedCount) ] ]

                else
                    []
               )
        )


viewAssignmentCell :
    AssignmentState
    -> List Judge
    -> Trial
    -> AssignmentField
    -> String
    -> Bool
    -> Html Msg
viewAssignmentCell assignmentState judges trial field currentId editable =
    let
        lookupName id =
            if id == "" then
                "—"

            else
                judges
                    |> List.filter (\j -> j.id == id)
                    |> List.head
                    |> Maybe.map .name
                    |> Maybe.withDefault "—"
    in
    case assignmentState of
        AssignmentEditing state ->
            if state.trialId == trial.id && state.field == field then
                td [ Attr.class "p-1" ]
                    [ div [ Attr.class "flex gap-1 items-center" ]
                        [ select
                            [ Attr.class "select select-sm select-bordered"
                            , Events.onInput SelectFieldValue
                            ]
                            (option [ Attr.value "", Attr.selected (state.value == "") ]
                                [ text "—" ]
                                :: List.map
                                    (\j ->
                                        option
                                            [ Attr.value j.id
                                            , Attr.selected (j.id == state.value)
                                            ]
                                            [ text j.name ]
                                    )
                                    judges
                            )
                        , button
                            [ Attr.class "btn btn-xs btn-primary"
                            , Events.onClick SaveAssignment
                            ]
                            [ text "Save" ]
                        , button
                            [ Attr.class "btn btn-xs btn-ghost"
                            , Events.onClick CancelAssignment
                            ]
                            [ text "✕" ]
                        ]
                    ]

            else
                viewStaticCell editable trial.id field (lookupName currentId)

        AssignmentSaving savingId ->
            if savingId == trial.id then
                td [] [ span [ Attr.class "loading loading-spinner loading-xs" ] [] ]

            else
                viewStaticCell editable trial.id field (lookupName currentId)

        AssignmentIdle ->
            viewStaticCell editable trial.id field (lookupName currentId)


viewStaticCell : Bool -> String -> AssignmentField -> String -> Html Msg
viewStaticCell editable trialId field label =
    if editable then
        td
            [ Attr.class "cursor-pointer hover:bg-base-200"
            , Events.onClick (ClickEditField trialId field)
            ]
            [ text label ]

    else
        td [] [ text label ]


teamLabel : Team -> String
teamLabel team =
    String.fromInt team.teamNumber ++ " — " ++ team.name
