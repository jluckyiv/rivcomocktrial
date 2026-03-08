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
    { coaches : List Api.CoachUser
    , loading : Bool
    , error : Maybe String
    }


init : Auth.User -> () -> ( Model, Effect Msg )
init user _ =
    ( { coaches = []
      , loading = True
      , error = Nothing
      }
    , Pb.adminList
        { collection = "users"
        , tag = "coaches"
        , filter = "role='coach'"
        , sort = ""
        }
    )



-- UPDATE


type Msg
    = ApproveCoach String
    | RejectCoach String
    | PbMsg Json.Decode.Value


update :
    Auth.User
    -> Msg
    -> Model
    -> ( Model, Effect Msg )
update user msg model =
    case msg of
        ApproveCoach id ->
            ( model
            , Pb.adminUpdate
                { collection = "users"
                , id = id
                , tag = "status-update"
                , body =
                    Json.Encode.object
                        [ ( "status"
                          , Json.Encode.string "approved"
                          )
                        ]
                }
            )

        RejectCoach id ->
            ( model
            , Pb.adminUpdate
                { collection = "users"
                , id = id
                , tag = "status-update"
                , body =
                    Json.Encode.object
                        [ ( "status"
                          , Json.Encode.string "rejected"
                          )
                        ]
                }
            )

        PbMsg value ->
            case Pb.responseTag value of
                Just "coaches" ->
                    case Pb.decodeList Api.coachUserDecoder value of
                        Ok coaches ->
                            ( { model
                                | coaches = coaches
                                , loading = False
                              }
                            , Effect.none
                            )

                        Err _ ->
                            ( { model
                                | loading = False
                                , error =
                                    Just
                                        "Failed to load registrations."
                              }
                            , Effect.none
                            )

                Just "status-update" ->
                    case Pb.decodeRecord Api.coachUserDecoder value of
                        Ok updated ->
                            ( { model
                                | coaches =
                                    List.map
                                        (\c ->
                                            if c.id == updated.id then
                                                updated

                                            else
                                                c
                                        )
                                        model.coaches
                              }
                            , Effect.none
                            )

                        Err _ ->
                            ( { model
                                | error =
                                    Just
                                        "Failed to update status."
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
        [ h1 [ Attr.class "title" ]
            [ text "Registrations" ]
        , case model.error of
            Just err ->
                div
                    [ Attr.class
                        "notification is-danger is-light"
                    ]
                    [ text err ]

            Nothing ->
                text ""
        , if model.loading then
            p [ Attr.class "has-text-grey" ]
                [ text "Loading..." ]

          else
            viewCoachTable model.coaches
        ]
    }


viewCoachTable : List Api.CoachUser -> Html Msg
viewCoachTable coaches =
    table [ Attr.class "table is-fullwidth is-striped" ]
        [ thead []
            [ tr []
                [ th [] [ text "Name" ]
                , th [] [ text "Email" ]
                , th [] [ text "Team Name" ]
                , th [] [ text "Status" ]
                , th [] [ text "Actions" ]
                ]
            ]
        , tbody []
            (List.map viewCoachRow coaches)
        ]


viewCoachRow : Api.CoachUser -> Html Msg
viewCoachRow coach =
    tr []
        [ td [] [ text coach.name ]
        , td [] [ text coach.email ]
        , td [] [ text coach.teamName ]
        , td [] [ viewStatusTag coach.status ]
        , td [] [ viewActions coach.id coach.status ]
        ]


viewStatusTag : String -> Html msg
viewStatusTag s =
    let
        ( tagClass, label ) =
            case s of
                "pending" ->
                    ( "tag is-warning", "Pending" )

                "approved" ->
                    ( "tag is-success", "Approved" )

                "rejected" ->
                    ( "tag is-danger", "Rejected" )

                _ ->
                    ( "tag", s )
    in
    span [ Attr.class tagClass ] [ text label ]


viewActions : String -> String -> Html Msg
viewActions coachId s =
    case s of
        "pending" ->
            div [ Attr.class "buttons are-small" ]
                [ button
                    [ Attr.class "button is-success"
                    , Events.onClick
                        (ApproveCoach coachId)
                    ]
                    [ text "Approve" ]
                , button
                    [ Attr.class "button is-danger"
                    , Events.onClick
                        (RejectCoach coachId)
                    ]
                    [ text "Reject" ]
                ]

        _ ->
            text ""
