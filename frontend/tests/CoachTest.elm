module CoachTest exposing (suite)

import Coach
import Expect
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "Coach"
        [ describe "verify"
            [ test "preserves the applicant's name" <|
                \_ ->
                    let
                        applicant =
                            { name =
                                { first = "Jane"
                                , last = "Doe"
                                , preferred = Nothing
                                }
                            , email = "jane@example.com"
                            }
                    in
                    applicant
                        |> Coach.verify
                        |> .name
                        |> Expect.equal applicant.name
            , test "preserves the applicant's email" <|
                \_ ->
                    let
                        applicant =
                            { name =
                                { first = "Jane"
                                , last = "Doe"
                                , preferred = Nothing
                                }
                            , email = "jane@example.com"
                            }
                    in
                    applicant
                        |> Coach.verify
                        |> .email
                        |> Expect.equal applicant.email
            ]
        ]
