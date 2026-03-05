module Pages.Admin.Registrations exposing (Model, Msg, page)

import Auth
import Coach
import Effect exposing (Effect)
import Email
import Fixtures
import Html exposing (..)
import Html.Attributes as Attr
import Html.Events as Events
import Layouts
import Page exposing (Page)
import Registration exposing (Registration, Status(..))
import Route exposing (Route)
import School
import Shared
import Team
import View exposing (View)


page : Auth.User -> Shared.Model -> Route () -> Page Model Msg
page user shared route =
    Page.new
        { init = init
        , update = update
        , view = view
        , subscriptions = subscriptions
        }
        |> Page.withLayout (\_ -> Layouts.Admin {})



-- MODEL


type alias Model =
    { registrations : List Registration
    }


init : () -> ( Model, Effect Msg )
init _ =
    ( { registrations = Fixtures.registrations }
    , Effect.none
    )



-- UPDATE


type Msg
    = ApproveRegistration Registration.RegistrationId
    | RejectRegistration Registration.RegistrationId


update : Msg -> Model -> ( Model, Effect Msg )
update msg model =
    case msg of
        ApproveRegistration regId ->
            ( { model
                | registrations =
                    List.map
                        (\reg ->
                            if
                                Registration.idToString
                                    (Registration.id reg)
                                    == Registration.idToString
                                        regId
                            then
                                Registration.approve reg

                            else
                                reg
                        )
                        model.registrations
              }
            , Effect.none
            )

        RejectRegistration regId ->
            ( { model
                | registrations =
                    List.map
                        (\reg ->
                            if
                                Registration.idToString
                                    (Registration.id reg)
                                    == Registration.idToString
                                        regId
                            then
                                Registration.reject reg

                            else
                                reg
                        )
                        model.registrations
              }
            , Effect.none
            )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none



-- VIEW


view : Model -> View Msg
view model =
    { title = "Registrations"
    , body =
        [ h1 [ Attr.class "title" ]
            [ text "Registrations" ]
        , viewRegistrationsTable model.registrations
        ]
    }


viewRegistrationsTable : List Registration -> Html Msg
viewRegistrationsTable regs =
    table [ Attr.class "table is-fullwidth is-striped" ]
        [ thead []
            [ tr []
                [ th [] [ text "Name" ]
                , th [] [ text "Email" ]
                , th [] [ text "School" ]
                , th [] [ text "Team Name" ]
                , th [] [ text "Status" ]
                , th [] [ text "Actions" ]
                ]
            ]
        , tbody []
            (List.map viewRegistrationRow regs)
        ]


viewRegistrationRow : Registration -> Html Msg
viewRegistrationRow reg =
    let
        app =
            Registration.applicant reg

        name =
            Coach.teacherCoachApplicantName app
                |> Coach.nameToString

        emailStr =
            Coach.teacherCoachApplicantEmail app
                |> Email.toString

        schoolStr =
            Registration.school reg
                |> School.schoolName
                |> School.nameToString

        teamNameStr =
            Registration.teamName reg
                |> Team.nameToString

        regStatus =
            Registration.status reg

        regId =
            Registration.id reg
    in
    tr []
        [ td [] [ text name ]
        , td [] [ text emailStr ]
        , td [] [ text schoolStr ]
        , td [] [ text teamNameStr ]
        , td [] [ viewStatusTag regStatus ]
        , td [] [ viewActions regId regStatus ]
        ]


viewStatusTag : Status -> Html msg
viewStatusTag s =
    let
        ( tagClass, label ) =
            case s of
                Pending ->
                    ( "tag is-warning", "Pending" )

                Approved ->
                    ( "tag is-success", "Approved" )

                Rejected ->
                    ( "tag is-danger", "Rejected" )
    in
    span [ Attr.class tagClass ] [ text label ]


viewActions :
    Registration.RegistrationId
    -> Status
    -> Html Msg
viewActions regId s =
    case s of
        Pending ->
            div [ Attr.class "buttons are-small" ]
                [ button
                    [ Attr.class "button is-success"
                    , Events.onClick
                        (ApproveRegistration regId)
                    ]
                    [ text "Approve" ]
                , button
                    [ Attr.class "button is-danger"
                    , Events.onClick
                        (RejectRegistration regId)
                    ]
                    [ text "Reject" ]
                ]

        _ ->
            text ""
