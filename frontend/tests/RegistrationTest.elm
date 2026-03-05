module RegistrationTest exposing (suite)

import Coach
import District
import Email
import Expect
import Registration exposing (Status(..))
import School
import Team
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "Registration"
        [ describe "create"
            [ test "returns Pending status" <|
                \_ ->
                    sampleRegistration
                        |> Registration.status
                        |> Expect.equal Pending
            ]
        , describe "approve"
            [ test "Pending becomes Approved" <|
                \_ ->
                    sampleRegistration
                        |> Registration.approve
                        |> Registration.status
                        |> Expect.equal Approved
            , test "Approved stays Approved (idempotent)" <|
                \_ ->
                    sampleRegistration
                        |> Registration.approve
                        |> Registration.approve
                        |> Registration.status
                        |> Expect.equal Approved
            ]
        , describe "reject"
            [ test "Pending becomes Rejected" <|
                \_ ->
                    sampleRegistration
                        |> Registration.reject
                        |> Registration.status
                        |> Expect.equal Rejected
            , test "Rejected stays Rejected (idempotent)" <|
                \_ ->
                    sampleRegistration
                        |> Registration.reject
                        |> Registration.reject
                        |> Registration.status
                        |> Expect.equal Rejected
            ]
        , describe "accessors"
            [ test "applicant round-trips" <|
                \_ ->
                    sampleRegistration
                        |> Registration.applicant
                        |> Coach.teacherCoachApplicantName
                        |> Coach.nameToString
                        |> Expect.equal "Jane Doe"
            , test "school round-trips" <|
                \_ ->
                    sampleRegistration
                        |> Registration.school
                        |> School.schoolName
                        |> School.nameToString
                        |> Expect.equal "Palm Desert High School"
            , test "teamName round-trips" <|
                \_ ->
                    sampleRegistration
                        |> Registration.teamName
                        |> Team.nameToString
                        |> Expect.equal "Palm Desert"
            , test "id round-trips" <|
                \_ ->
                    sampleRegistration
                        |> Registration.id
                        |> Registration.idToString
                        |> Expect.equal "reg-001"
            ]
        , describe "statusToString"
            [ test "Pending" <|
                \_ ->
                    Registration.statusToString Pending
                        |> Expect.equal "Pending"
            , test "Approved" <|
                \_ ->
                    Registration.statusToString Approved
                        |> Expect.equal "Approved"
            , test "Rejected" <|
                \_ ->
                    Registration.statusToString Rejected
                        |> Expect.equal "Rejected"
            ]
        , describe "idFromString / idToString"
            [ test "round-trips" <|
                \_ ->
                    Registration.idFromString "abc-123"
                        |> Registration.idToString
                        |> Expect.equal "abc-123"
            ]
        ]


sampleRegistration : Registration.Registration
sampleRegistration =
    let
        applicantName =
            case Coach.nameFromStrings "Jane" "Doe" of
                Ok n ->
                    n

                Err _ ->
                    Debug.todo "Invalid name"

        applicantEmail =
            case Email.fromString "jane@example.com" of
                Ok e ->
                    e

                Err _ ->
                    Debug.todo "Invalid email"

        sampleApplicant =
            Coach.apply applicantName applicantEmail

        districtName =
            case District.nameFromString "Desert Sands USD" of
                Ok n ->
                    n

                Err _ ->
                    Debug.todo "Invalid district name"

        sampleSchool =
            School.create
                (case School.nameFromString "Palm Desert High School" of
                    Ok n ->
                        n

                    Err _ ->
                        Debug.todo "Invalid school name"
                )
                (District.create districtName)

        sampleTeamName =
            case Team.nameFromString "Palm Desert" of
                Ok n ->
                    n

                Err _ ->
                    Debug.todo "Invalid team name"
    in
    Registration.create
        (Registration.idFromString "reg-001")
        sampleApplicant
        sampleSchool
        sampleTeamName
