module MatchHistoryTest exposing (..)

import Expect
import MatchHistory exposing (MatchHistory, MatchRecord, SideCount)
import PowerMatchFixtures as F
import Team exposing (Team)
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "MatchHistory"
        [ emptyTests
        , hasPlayedTests
        , sideHistoryTests
        ]


emptyTests : Test
emptyTests =
    describe "empty"
        [ test "empty history has no matches" <|
            \_ ->
                MatchHistory.hasPlayed MatchHistory.empty F.team01 F.team02
                    |> Expect.equal False
        , test "empty history has zero side counts" <|
            \_ ->
                MatchHistory.sideHistory MatchHistory.empty F.team01
                    |> Expect.equal { prosecution = 0, defense = 0 }
        ]


hasPlayedTests : Test
hasPlayedTests =
    describe "hasPlayed"
        [ test "detects previous matchup (P vs D)" <|
            \_ ->
                let
                    history =
                        MatchHistory.fromRecords
                            [ { prosecution = F.team06
                              , defense = F.team15
                              }
                            ]
                in
                MatchHistory.hasPlayed history F.team06 F.team15
                    |> Expect.equal True
        , test "detects previous matchup (reversed order)" <|
            \_ ->
                let
                    history =
                        MatchHistory.fromRecords
                            [ { prosecution = F.team06
                              , defense = F.team15
                              }
                            ]
                in
                MatchHistory.hasPlayed history F.team15 F.team06
                    |> Expect.equal True
        , test "returns False for teams that haven't played" <|
            \_ ->
                let
                    history =
                        MatchHistory.fromRecords
                            [ { prosecution = F.team06
                              , defense = F.team15
                              }
                            ]
                in
                MatchHistory.hasPlayed history F.team01 F.team06
                    |> Expect.equal False
        , test "works with multiple records" <|
            \_ ->
                let
                    history =
                        MatchHistory.fromRecords
                            [ { prosecution = F.team01
                              , defense = F.team02
                              }
                            , { prosecution = F.team03
                              , defense = F.team04
                              }
                            ]
                in
                Expect.all
                    [ \_ ->
                        MatchHistory.hasPlayed history F.team01 F.team02
                            |> Expect.equal True
                    , \_ ->
                        MatchHistory.hasPlayed history F.team03 F.team04
                            |> Expect.equal True
                    , \_ ->
                        MatchHistory.hasPlayed history F.team01 F.team03
                            |> Expect.equal False
                    ]
                    ()
        ]


sideHistoryTests : Test
sideHistoryTests =
    describe "sideHistory"
        [ test "counts prosecution and defense appearances" <|
            \_ ->
                let
                    -- Team 09: once as D, once as P
                    history =
                        MatchHistory.fromRecords
                            [ { prosecution = F.team19
                              , defense = F.team09
                              }
                            , { prosecution = F.team09
                              , defense = F.team23
                              }
                            ]
                in
                MatchHistory.sideHistory history F.team09
                    |> Expect.equal { prosecution = 1, defense = 1 }
        , test "team with no appearances has zero counts" <|
            \_ ->
                let
                    history =
                        MatchHistory.fromRecords
                            [ { prosecution = F.team01
                              , defense = F.team02
                              }
                            ]
                in
                MatchHistory.sideHistory history F.team03
                    |> Expect.equal { prosecution = 0, defense = 0 }
        , test "team as prosecution only" <|
            \_ ->
                let
                    history =
                        MatchHistory.fromRecords
                            [ { prosecution = F.team06
                              , defense = F.team15
                              }
                            ]
                in
                MatchHistory.sideHistory history F.team06
                    |> Expect.equal { prosecution = 1, defense = 0 }
        , test "team as defense only" <|
            \_ ->
                let
                    history =
                        MatchHistory.fromRecords
                            [ { prosecution = F.team06
                              , defense = F.team15
                              }
                            ]
                in
                MatchHistory.sideHistory history F.team15
                    |> Expect.equal { prosecution = 0, defense = 1 }
        ]
