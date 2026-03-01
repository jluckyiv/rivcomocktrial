module RoundTest exposing (suite)

import Expect
import Round exposing (Phase(..), Round(..))
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "Round"
        [ describe "phase"
            [ test "Preliminary1 → Preliminary" <|
                \_ ->
                    Round.phase Preliminary1
                        |> Expect.equal Preliminary
            , test "Preliminary2 → Preliminary" <|
                \_ ->
                    Round.phase Preliminary2
                        |> Expect.equal Preliminary
            , test "Preliminary3 → Preliminary" <|
                \_ ->
                    Round.phase Preliminary3
                        |> Expect.equal Preliminary
            , test "Preliminary4 → Preliminary" <|
                \_ ->
                    Round.phase Preliminary4
                        |> Expect.equal Preliminary
            , test "Quarterfinal → Elimination" <|
                \_ ->
                    Round.phase Quarterfinal
                        |> Expect.equal Elimination
            , test "Semifinal → Elimination" <|
                \_ ->
                    Round.phase Semifinal
                        |> Expect.equal Elimination
            , test "Final → Elimination" <|
                \_ ->
                    Round.phase Final
                        |> Expect.equal Elimination
            ]
        , describe "toString"
            [ test "Preliminary1 → \"Preliminary 1\"" <|
                \_ ->
                    Round.toString Preliminary1
                        |> Expect.equal "Preliminary 1"
            , test "Preliminary2 → \"Preliminary 2\"" <|
                \_ ->
                    Round.toString Preliminary2
                        |> Expect.equal "Preliminary 2"
            , test "Preliminary3 → \"Preliminary 3\"" <|
                \_ ->
                    Round.toString Preliminary3
                        |> Expect.equal "Preliminary 3"
            , test "Preliminary4 → \"Preliminary 4\"" <|
                \_ ->
                    Round.toString Preliminary4
                        |> Expect.equal "Preliminary 4"
            , test "Quarterfinal → \"Quarterfinal\"" <|
                \_ ->
                    Round.toString Quarterfinal
                        |> Expect.equal "Quarterfinal"
            , test "Semifinal → \"Semifinal\"" <|
                \_ ->
                    Round.toString Semifinal
                        |> Expect.equal "Semifinal"
            , test "Final → \"Final\"" <|
                \_ ->
                    Round.toString Final
                        |> Expect.equal "Final"
            ]
        , describe "phaseToString"
            [ test "Preliminary → \"Preliminary\"" <|
                \_ ->
                    Round.phaseToString Preliminary
                        |> Expect.equal "Preliminary"
            , test "Elimination → \"Elimination\"" <|
                \_ ->
                    Round.phaseToString Elimination
                        |> Expect.equal "Elimination"
            ]
        ]
