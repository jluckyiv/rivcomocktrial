module Pages.Admin.EligibilityRequests exposing (Model, Msg, page)

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
page user shared route =
    Page.new
        { init = init user
        , update = update user
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
    { requests : RemoteData (List Api.ChangeRequest)
    , teams : RemoteData (List Api.Team)
    , error : Maybe String
    }


init : Auth.User -> () -> ( Model, Effect Msg )
init _ _ =
    ( { requests = Loading
      , teams = Loading
      , error = Nothing
      }
    , Effect.batch
        [ Pb.adminList
            { collection = "eligibility_change_requests"
            , tag = "change-requests"
            , filter = ""
            , sort = "-created"
            }
        , Pb.adminList
            { collection = "teams"
            , tag = "teams"
            , filter = ""
            , sort = "name"
            }
        ]
    )



-- UPDATE


type Msg
    = ApproveRequest String
    | RejectRequest String
    | PbMsg Json.Decode.Value


update : Auth.User -> Msg -> Model -> ( Model, Effect Msg )
update _ msg model =
    case msg of
        ApproveRequest id ->
            ( model
            , Pb.adminUpdate
                { collection = "eligibility_change_requests"
                , id = id
                , tag = "update-request"
                , body =
                    Json.Encode.object
                        [ ( "status", Api.encodeRequestStatus Api.Approved ) ]
                }
            )

        RejectRequest id ->
            ( model
            , Pb.adminUpdate
                { collection = "eligibility_change_requests"
                , id = id
                , tag = "update-request"
                , body =
                    Json.Encode.object
                        [ ( "status", Api.encodeRequestStatus Api.Rejected ) ]
                }
            )

        PbMsg value ->
            case Pb.responseTag value of
                Just "change-requests" ->
                    case Pb.decodeList Api.changeRequestDecoder value of
                        Ok requests ->
                            ( { model | requests = Succeeded requests }
                            , Effect.none
                            )

                        Err _ ->
                            ( { model
                                | requests =
                                    Failed "Failed to load change requests."
                              }
                            , Effect.none
                            )

                Just "teams" ->
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

                Just "update-request" ->
                    case Pb.decodeRecord Api.changeRequestDecoder value of
                        Ok updated ->
                            ( { model
                                | requests =
                                    case model.requests of
                                        Succeeded reqs ->
                                            Succeeded
                                                (List.map
                                                    (\r ->
                                                        if r.id == updated.id then
                                                            updated

                                                        else
                                                            r
                                                    )
                                                    reqs
                                                )

                                        other ->
                                            other
                              }
                            , Effect.none
                            )

                        Err _ ->
                            ( { model
                                | error =
                                    Just "Failed to update request."
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
    { title = "Eligibility Change Requests"
    , body =
        [ UI.titleBar
            { title = "Eligibility Change Requests"
            , actions = []
            }
        , case model.error of
            Just err ->
                UI.error err

            Nothing ->
                UI.empty
        , viewContent model
        ]
    }


viewContent : Model -> Html Msg
viewContent model =
    case ( model.requests, model.teams ) of
        ( Loading, _ ) ->
            UI.loading

        ( _, Loading ) ->
            UI.loading

        ( Failed err, _ ) ->
            UI.error err

        ( _, Failed err ) ->
            UI.error err

        ( Succeeded [], _ ) ->
            UI.emptyState "No change requests yet."

        ( Succeeded requests, Succeeded teams ) ->
            UI.dataTable
                { columns =
                    [ "Team"
                    , "Student"
                    , "Type"
                    , "Notes"
                    , "Status"
                    , "Actions"
                    ]
                , rows = requests
                , rowView = viewRequestRow teams
                }


viewRequestRow : List Api.Team -> Api.ChangeRequest -> Html Msg
viewRequestRow teams req =
    let
        teamName =
            teams
                |> List.filter (\t -> t.id == req.team)
                |> List.head
                |> Maybe.map .name
                |> Maybe.withDefault req.team
    in
    tr []
        [ td [] [ text teamName ]
        , td [] [ text req.studentName ]
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
        , td [] [ viewStatusBadge req.status ]
        , td [] [ viewActions req.id req.status ]
        ]


viewStatusBadge : Api.RequestStatus -> Html msg
viewStatusBadge status =
    case status of
        Api.Pending ->
            UI.badge { label = "Pending", variant = "warning" }

        Api.Approved ->
            UI.badge { label = "Approved", variant = "success" }

        Api.Rejected ->
            UI.badge { label = "Rejected", variant = "error" }


viewActions : String -> Api.RequestStatus -> Html Msg
viewActions requestId status =
    case status of
        Api.Pending ->
            div [ Attr.class "flex gap-2" ]
                [ button
                    [ Attr.class "btn btn-sm btn-success"
                    , Events.onClick (ApproveRequest requestId)
                    ]
                    [ text "Approve" ]
                , button
                    [ Attr.class "btn btn-sm btn-error"
                    , Events.onClick (RejectRequest requestId)
                    ]
                    [ text "Reject" ]
                ]

        _ ->
            UI.empty
