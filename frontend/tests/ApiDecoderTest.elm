module ApiDecoderTest exposing (suite)

import Api
    exposing
        ( MotionRuling(..)
        , RoundStatus(..)
        , TrialVerdict(..)
        )
import Expect
import Json.Decode as Decode
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "Api decoders"
        [ judgeDecoderSuite
        , roundStatusDecoderSuite
        , motionRulingDecoderSuite
        , trialVerdictDecoderSuite
        , roundDecoderSuite
        , trialDecoderSuite
        , presiderBallotDecoderSuite
        ]


judgeDecoderSuite : Test
judgeDecoderSuite =
    describe "judgeDecoder"
        [ test "decodes required fields" <|
            \_ ->
                """{"id":"j1","name":"Judge Clark","created":"2026-01-01","updated":"2026-01-01"}"""
                    |> Decode.decodeString Api.judgeDecoder
                    |> Result.map .name
                    |> Expect.equal (Ok "Judge Clark")
        , test "decodes email when present" <|
            \_ ->
                """{"id":"j1","name":"Judge Clark","email":"clark@court.gov","created":"2026-01-01","updated":"2026-01-01"}"""
                    |> Decode.decodeString Api.judgeDecoder
                    |> Result.map .email
                    |> Expect.equal (Ok "clark@court.gov")
        , test "defaults email to empty string when absent" <|
            \_ ->
                """{"id":"j1","name":"Judge Clark","created":"2026-01-01","updated":"2026-01-01"}"""
                    |> Decode.decodeString Api.judgeDecoder
                    |> Result.map .email
                    |> Expect.equal (Ok "")
        , test "fails when name is missing" <|
            \_ ->
                """{"id":"j1","created":"2026-01-01","updated":"2026-01-01"}"""
                    |> Decode.decodeString Api.judgeDecoder
                    |> Expect.err
        ]


roundStatusDecoderSuite : Test
roundStatusDecoderSuite =
    describe "roundDecoder — status field"
        [ test "decodes upcoming" <|
            \_ ->
                roundJson "\"upcoming\""
                    |> Decode.decodeString Api.roundDecoder
                    |> Result.map .status
                    |> Expect.equal (Ok Upcoming)
        , test "decodes open" <|
            \_ ->
                roundJson "\"open\""
                    |> Decode.decodeString Api.roundDecoder
                    |> Result.map .status
                    |> Expect.equal (Ok Open)
        , test "decodes locked" <|
            \_ ->
                roundJson "\"locked\""
                    |> Decode.decodeString Api.roundDecoder
                    |> Result.map .status
                    |> Expect.equal (Ok Locked)
        , test "defaults to Upcoming when status absent" <|
            \_ ->
                roundJsonNoStatus
                    |> Decode.decodeString Api.roundDecoder
                    |> Result.map .status
                    |> Expect.equal (Ok Upcoming)
        , test "decodes ranking_min when present" <|
            \_ ->
                roundJsonWithRankings "3" "5"
                    |> Decode.decodeString Api.roundDecoder
                    |> Result.map .rankingMin
                    |> Expect.equal (Ok (Just 3))
        , test "decodes ranking_max when present" <|
            \_ ->
                roundJsonWithRankings "3" "5"
                    |> Decode.decodeString Api.roundDecoder
                    |> Result.map .rankingMax
                    |> Expect.equal (Ok (Just 5))
        , test "defaults ranking_min to Nothing when absent" <|
            \_ ->
                roundJson "\"upcoming\""
                    |> Decode.decodeString Api.roundDecoder
                    |> Result.map .rankingMin
                    |> Expect.equal (Ok Nothing)
        ]


motionRulingDecoderSuite : Test
motionRulingDecoderSuite =
    describe "presiderBallotRecordDecoder — motion_ruling field"
        [ test "decodes granted" <|
            \_ ->
                presiderJson "\"granted\"" "\"guilty\""
                    |> Decode.decodeString Api.presiderBallotRecordDecoder
                    |> Result.map .motionRuling
                    |> Expect.equal (Ok (Just Granted))
        , test "decodes denied" <|
            \_ ->
                presiderJson "\"denied\"" "\"guilty\""
                    |> Decode.decodeString Api.presiderBallotRecordDecoder
                    |> Result.map .motionRuling
                    |> Expect.equal (Ok (Just Denied))
        , test "defaults to Nothing when absent" <|
            \_ ->
                presiderJsonNoOptionals
                    |> Decode.decodeString Api.presiderBallotRecordDecoder
                    |> Result.map .motionRuling
                    |> Expect.equal (Ok Nothing)
        ]


trialVerdictDecoderSuite : Test
trialVerdictDecoderSuite =
    describe "presiderBallotRecordDecoder — verdict field"
        [ test "decodes guilty" <|
            \_ ->
                presiderJson "\"granted\"" "\"guilty\""
                    |> Decode.decodeString Api.presiderBallotRecordDecoder
                    |> Result.map .verdict
                    |> Expect.equal (Ok (Just Guilty))
        , test "decodes not_guilty" <|
            \_ ->
                presiderJson "\"granted\"" "\"not_guilty\""
                    |> Decode.decodeString Api.presiderBallotRecordDecoder
                    |> Result.map .verdict
                    |> Expect.equal (Ok (Just NotGuilty))
        , test "defaults to Nothing when absent" <|
            \_ ->
                presiderJsonNoOptionals
                    |> Decode.decodeString Api.presiderBallotRecordDecoder
                    |> Result.map .verdict
                    |> Expect.equal (Ok Nothing)
        ]


roundDecoderSuite : Test
roundDecoderSuite =
    describe "roundDecoder"
        [ test "decodes all required fields" <|
            \_ ->
                roundJson "\"upcoming\""
                    |> Decode.decodeString Api.roundDecoder
                    |> Result.map .number
                    |> Expect.equal (Ok 1)
        , test "decodes round type" <|
            \_ ->
                roundJson "\"upcoming\""
                    |> Decode.decodeString Api.roundDecoder
                    |> Result.map .roundType
                    |> Expect.equal (Ok Api.Preliminary)
        ]


trialDecoderSuite : Test
trialDecoderSuite =
    describe "trialDecoder"
        [ test "decodes judge when present" <|
            \_ ->
                trialJsonWithJudge "judge-id"
                    |> Decode.decodeString Api.trialDecoder
                    |> Result.map .judge
                    |> Expect.equal (Ok "judge-id")
        , test "defaults judge to empty string when absent" <|
            \_ ->
                trialJsonBase
                    |> Decode.decodeString Api.trialDecoder
                    |> Result.map .judge
                    |> Expect.equal (Ok "")
        , test "decodes scorer_1 when present" <|
            \_ ->
                trialJsonWithScorer1 "scorer-id"
                    |> Decode.decodeString Api.trialDecoder
                    |> Result.map .scorer1
                    |> Expect.equal (Ok "scorer-id")
        , test "defaults scorer1 to empty string when absent" <|
            \_ ->
                trialJsonBase
                    |> Decode.decodeString Api.trialDecoder
                    |> Result.map .scorer1
                    |> Expect.equal (Ok "")
        , test "defaults scorer5 to empty string when absent" <|
            \_ ->
                trialJsonBase
                    |> Decode.decodeString Api.trialDecoder
                    |> Result.map .scorer5
                    |> Expect.equal (Ok "")
        ]


presiderBallotDecoderSuite : Test
presiderBallotDecoderSuite =
    describe "presiderBallotRecordDecoder"
        [ test "decodes winner_side" <|
            \_ ->
                presiderJsonNoOptionals
                    |> Decode.decodeString Api.presiderBallotRecordDecoder
                    |> Result.map .winnerSide
                    |> Expect.equal (Ok Api.Prosecution)
        , test "fails when winner_side is missing" <|
            \_ ->
                """{"id":"pb1","scorer_token":"t1","trial":"trial1","submitted_at":"2026-01-01","created":"2026-01-01","updated":"2026-01-01"}"""
                    |> Decode.decodeString Api.presiderBallotRecordDecoder
                    |> Expect.err
        ]



-- FIXTURES


roundJson : String -> String
roundJson statusJson =
    """{"id":"r1","number":1,"type":"preliminary","published":false,"tournament":"t1","status":"""
        ++ statusJson
        ++ ""","created":"2026-01-01","updated":"2026-01-01"}"""


roundJsonNoStatus : String
roundJsonNoStatus =
    """{"id":"r1","number":1,"type":"preliminary","published":false,"tournament":"t1","created":"2026-01-01","updated":"2026-01-01"}"""


roundJsonWithRankings : String -> String -> String
roundJsonWithRankings minJson maxJson =
    """{"id":"r1","number":1,"type":"preliminary","published":false,"tournament":"t1","status":"upcoming","ranking_min":"""
        ++ minJson
        ++ ""","ranking_max":"""
        ++ maxJson
        ++ ""","created":"2026-01-01","updated":"2026-01-01"}"""


trialJsonBase : String
trialJsonBase =
    """{"id":"t1","round":"r1","prosecution_team":"p1","defense_team":"d1","created":"2026-01-01","updated":"2026-01-01"}"""


trialJsonWithJudge : String -> String
trialJsonWithJudge judgeId =
    """{"id":"t1","round":"r1","prosecution_team":"p1","defense_team":"d1","judge":\""""
        ++ judgeId
        ++ """\","created":"2026-01-01","updated":"2026-01-01"}"""


trialJsonWithScorer1 : String -> String
trialJsonWithScorer1 scorerId =
    """{"id":"t1","round":"r1","prosecution_team":"p1","defense_team":"d1","scorer_1":\""""
        ++ scorerId
        ++ """\","created":"2026-01-01","updated":"2026-01-01"}"""


presiderJsonNoOptionals : String
presiderJsonNoOptionals =
    """{"id":"pb1","scorer_token":"t1","trial":"trial1","winner_side":"prosecution","submitted_at":"2026-01-01","created":"2026-01-01","updated":"2026-01-01"}"""


presiderJson : String -> String -> String
presiderJson motionJson verdictJson =
    """{"id":"pb1","scorer_token":"t1","trial":"trial1","winner_side":"prosecution","motion_ruling":"""
        ++ motionJson
        ++ ""","verdict":"""
        ++ verdictJson
        ++ ""","submitted_at":"2026-01-01","created":"2026-01-01","updated":"2026-01-01"}"""
