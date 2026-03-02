module UserRoleTest exposing (suite)

import Error exposing (Error(..))
import Expect
import Test exposing (Test, describe, test)
import UserRole exposing (UserRole(..))


suite : Test
suite =
    describe "UserRole"
        [ describe "toString / fromString round-trip"
            [ roundTrip SuperUser "SuperUser"
            , roundTrip Admin "Admin"
            , roundTrip TeacherCoach "TeacherCoach"
            , roundTrip AttorneyCoach "AttorneyCoach"
            , roundTrip Scorer "Scorer"
            , roundTrip Public "Public"
            ]
        , describe "fromString"
            [ test "rejects unknown string" <|
                \_ ->
                    UserRole.fromString "Unknown"
                        |> Expect.equal
                            (Err [ Error "Unknown user role: Unknown" ])
            ]
        , describe "all"
            [ test "contains every variant" <|
                \_ ->
                    UserRole.all
                        |> Expect.equal
                            [ SuperUser
                            , Admin
                            , TeacherCoach
                            , AttorneyCoach
                            , Scorer
                            , Public
                            ]
            , test "all values round-trip through toString/fromString" <|
                \_ ->
                    UserRole.all
                        |> List.map
                            (\role ->
                                role
                                    |> UserRole.toString
                                    |> UserRole.fromString
                            )
                        |> Expect.equal
                            (List.map Ok UserRole.all)
            ]
        ]


roundTrip : UserRole -> String -> Test
roundTrip role str =
    describe (str ++ " round-trip")
        [ test "toString" <|
            \_ ->
                role
                    |> UserRole.toString
                    |> Expect.equal str
        , test "fromString" <|
            \_ ->
                UserRole.fromString str
                    |> Expect.equal (Ok role)
        ]
