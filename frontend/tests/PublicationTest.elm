module PublicationTest exposing (suite)

import Expect
import Publication
    exposing
        ( Audience(..)
        , PublicationLevel(..)
        )
import Round exposing (Round(..))
import RoundProgress exposing (RoundProgress(..))
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "Publication"
        [ publishTests
        , levelAtLeastTests
        , audienceAtLeastTests
        , isVisibleToTests
        ]


publishTests : Test
publishTests =
    describe "publish"
        [ test "rejects CheckInOpen" <|
            \_ ->
                Publication.publish
                    Preliminary1
                    ResultOnly
                    OwnTeamCoach
                    CheckInOpen
                    |> Expect.err
        , test "rejects AllTrialsStarted" <|
            \_ ->
                Publication.publish
                    Preliminary1
                    ResultOnly
                    OwnTeamCoach
                    AllTrialsStarted
                    |> Expect.err
        , test "rejects AllTrialsComplete" <|
            \_ ->
                Publication.publish
                    Preliminary1
                    ResultOnly
                    OwnTeamCoach
                    AllTrialsComplete
                    |> Expect.err
        , test "succeeds for FullyVerified" <|
            \_ ->
                Publication.publish
                    Preliminary1
                    ScoreSheet
                    AllCoaches
                    FullyVerified
                    |> Expect.ok
        , test "preserves round" <|
            \_ ->
                Publication.publish
                    Preliminary2
                    ResultOnly
                    OwnTeamCoach
                    FullyVerified
                    |> Result.map Publication.round
                    |> Expect.equal (Ok Preliminary2)
        , test "preserves level" <|
            \_ ->
                Publication.publish
                    Preliminary1
                    FullBallots
                    OwnTeamCoach
                    FullyVerified
                    |> Result.map Publication.level
                    |> Expect.equal (Ok FullBallots)
        , test "preserves audience" <|
            \_ ->
                Publication.publish
                    Preliminary1
                    ResultOnly
                    Public
                    FullyVerified
                    |> Result.map Publication.audience
                    |> Expect.equal (Ok Public)
        ]


levelAtLeastTests : Test
levelAtLeastTests =
    describe "levelAtLeast"
        [ test "ResultOnly >= ResultOnly" <|
            \_ ->
                Publication.levelAtLeast ResultOnly ResultOnly
                    |> Expect.equal True
        , test "ScoreSheet >= ResultOnly" <|
            \_ ->
                Publication.levelAtLeast ScoreSheet ResultOnly
                    |> Expect.equal True
        , test "ResultOnly >= ScoreSheet is false" <|
            \_ ->
                Publication.levelAtLeast ResultOnly ScoreSheet
                    |> Expect.equal False
        , test "FullBallots >= ResultOnly" <|
            \_ ->
                Publication.levelAtLeast FullBallots ResultOnly
                    |> Expect.equal True
        , test "FullBallots >= ScoreSheet" <|
            \_ ->
                Publication.levelAtLeast FullBallots ScoreSheet
                    |> Expect.equal True
        , test "FullBallots >= FullBallots" <|
            \_ ->
                Publication.levelAtLeast FullBallots FullBallots
                    |> Expect.equal True
        ]


audienceAtLeastTests : Test
audienceAtLeastTests =
    describe "audienceAtLeast"
        [ test "OwnTeamCoach >= OwnTeamCoach" <|
            \_ ->
                Publication.audienceAtLeast
                    OwnTeamCoach
                    OwnTeamCoach
                    |> Expect.equal True
        , test "AllCoaches >= OwnTeamCoach" <|
            \_ ->
                Publication.audienceAtLeast
                    AllCoaches
                    OwnTeamCoach
                    |> Expect.equal True
        , test "OwnTeamCoach >= AllCoaches is false" <|
            \_ ->
                Publication.audienceAtLeast
                    OwnTeamCoach
                    AllCoaches
                    |> Expect.equal False
        , test "Public >= AllCoaches" <|
            \_ ->
                Publication.audienceAtLeast
                    Public
                    AllCoaches
                    |> Expect.equal True
        , test "Public >= Public" <|
            \_ ->
                Publication.audienceAtLeast
                    Public
                    Public
                    |> Expect.equal True
        ]


isVisibleToTests : Test
isVisibleToTests =
    let
        pub level aud =
            case
                Publication.publish
                    Preliminary1
                    level
                    aud
                    FullyVerified
            of
                Ok p ->
                    p

                Err _ ->
                    Debug.todo "test pub must be valid"
    in
    describe "isVisibleTo"
        [ test "ScoreSheet/AllCoaches: ResultOnly/OwnTeamCoach visible" <|
            \_ ->
                Publication.isVisibleTo
                    ResultOnly
                    OwnTeamCoach
                    (pub ScoreSheet AllCoaches)
                    |> Expect.equal True
        , test "ScoreSheet/AllCoaches: FullBallots/AllCoaches not visible" <|
            \_ ->
                Publication.isVisibleTo
                    FullBallots
                    AllCoaches
                    (pub ScoreSheet AllCoaches)
                    |> Expect.equal False
        , test "ScoreSheet/AllCoaches: ScoreSheet/Public not visible" <|
            \_ ->
                Publication.isVisibleTo
                    ScoreSheet
                    Public
                    (pub ScoreSheet AllCoaches)
                    |> Expect.equal False
        , test "FullBallots/Public: everything visible" <|
            \_ ->
                Publication.isVisibleTo
                    FullBallots
                    Public
                    (pub FullBallots Public)
                    |> Expect.equal True
        ]
