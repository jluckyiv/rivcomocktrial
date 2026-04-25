module BallotAssembly exposing
    ( assemblePresiderBallot
    , assembleScoredPresentation
    , assembleSubmittedBallot
    , assembleVerifiedBallot
    , rosterSideToSide
    )

{-| Converts flat PocketBase API records into domain ballot types.

The domain types (SubmittedBallot, VerifiedBallot, etc.) are opaque
and validated. This module bridges the gap between the flat storage
representation in PocketBase and the rich domain model.

Limitations:
- Student names are stored as flat strings in ballot_scores. We parse
  them into first/last by splitting on the last space. Pronouns default
  to TheyThem (irrelevant for scoring calculations).
- If a name cannot be parsed, the score is returned as an Error.

-}

import Api
    exposing
        ( BallotCorrection
        , BallotScore
        , PresiderBallotRecord
        , PresentationType(..)
        , RosterSide
        )
import Error exposing (Error(..))
import PresiderBallot exposing (PresiderBallot)
import Side exposing (Side)
import Student exposing (Pronouns(..), Student)
import SubmittedBallot
    exposing
        ( Points
        , ScoredPresentation(..)
        , SubmittedBallot
        )
import VerifiedBallot exposing (VerifiedBallot)


{-| Converts an Api.RosterSide to a domain Side.
-}
rosterSideToSide : RosterSide -> Side
rosterSideToSide rs =
    case rs of
        Api.Prosecution ->
            Side.Prosecution

        Api.Defense ->
            Side.Defense


{-| Parses a flat name string ("First Last") into a domain Student.

Splits on the last space so compound first names ("Mary Jane Smith"
→ first="Mary Jane", last="Smith") work naturally. If the name has
no space, the whole string becomes the last name and first is set to
"—" (a non-blank placeholder).

Pronouns default to TheyThem; they are not stored on ballots and are
irrelevant for scoring calculations.

-}
assembleStudent : String -> Result (List Error) Student
assembleStudent fullName =
    let
        trimmed =
            String.trim fullName

        ( rawFirst, rawLast ) =
            case String.indices " " trimmed of
                [] ->
                    ( "—", trimmed )

                indices ->
                    let
                        lastIndex =
                            List.foldl max 0 indices
                    in
                    ( String.left lastIndex trimmed
                    , String.dropLeft (lastIndex + 1) trimmed
                    )
    in
    Student.nameFromStrings rawFirst rawLast Nothing
        |> Result.map (\name -> Student.create name TheyThem)


{-| Converts a validated Int (1–10) into a domain Points value.
-}
assemblePoints : Int -> Result (List Error) Points
assemblePoints =
    SubmittedBallot.fromInt


{-| Converts a flat BallotScore API record into a domain ScoredPresentation.
-}
assembleScoredPresentation : BallotScore -> Result (List Error) ScoredPresentation
assembleScoredPresentation score =
    let
        side =
            rosterSideToSide score.side

        studentResult =
            assembleStudent score.studentName

        pointsResult =
            assemblePoints score.points
    in
    case ( studentResult, pointsResult ) of
        ( Err e1, Err e2 ) ->
            Err (e1 ++ e2)

        ( Err e, Ok _ ) ->
            Err e

        ( Ok _, Err e ) ->
            Err e

        ( Ok student, Ok pts ) ->
            case score.presentation of
                PretrialPresentation ->
                    Ok (Pretrial side student pts)

                OpeningPresentation ->
                    Ok (Opening side student pts)

                DirectExaminationPresentation ->
                    Ok (DirectExamination side student pts)

                CrossExaminationPresentation ->
                    Ok (CrossExamination side student pts)

                ClosingPresentation ->
                    Ok (Closing side student pts)

                WitnessExaminationPresentation ->
                    Ok (WitnessExamination side student pts)

                ClerkPerformancePresentation ->
                    -- ClerkPerformance does not carry an explicit side in the
                    -- domain type (it hard-codes Prosecution). Ignore score.side.
                    Ok (ClerkPerformance student pts)

                BailiffPerformancePresentation ->
                    -- BailiffPerformance hard-codes Defense in the domain type.
                    Ok (BailiffPerformance student pts)


{-| Assembles a SubmittedBallot from a list of BallotScore records.

Returns the first error encountered, or a validated SubmittedBallot
if all scores are valid.

-}
assembleSubmittedBallot : List BallotScore -> Result (List Error) SubmittedBallot
assembleSubmittedBallot scores =
    let
        sorted =
            List.sortBy .sortOrder scores

        results =
            List.map assembleScoredPresentation sorted

        ( errs, presentations ) =
            List.foldl
                (\result ( accErrs, accOk ) ->
                    case result of
                        Err e ->
                            ( accErrs ++ e, accOk )

                        Ok p ->
                            ( accErrs, accOk ++ [ p ] )
                )
                ( [], [] )
                results
    in
    if List.isEmpty errs then
        SubmittedBallot.create presentations

    else
        Err errs


{-| Assembles a VerifiedBallot from an original SubmittedBallot and a
list of BallotCorrection records.

Corrections replace individual score points while preserving original
student names and presentation types. Corrections that reference
scores not in the original ballot are silently ignored.

If there are no corrections, uses VerifiedBallot.verify (accept as-is).
If there are corrections, reconstructs the corrected presentation list
and uses VerifiedBallot.verifyWithCorrections.

-}
assembleVerifiedBallot :
    SubmittedBallot
    -> List BallotScore
    -> List BallotCorrection
    -> VerifiedBallot
assembleVerifiedBallot original scores corrections =
    if List.isEmpty corrections then
        VerifiedBallot.verify original

    else
        let
            -- Build a lookup from original_score ID → corrected_points.
            correctionMap =
                List.foldl
                    (\c acc ->
                        ( c.originalScore, c.correctedPoints ) :: acc
                    )
                    []
                    corrections

            correctedScores =
                List.map
                    (\score ->
                        case List.filter (\( id, _ ) -> id == score.id) correctionMap of
                            ( _, correctedPts ) :: _ ->
                                { score | points = correctedPts }

                            [] ->
                                score
                    )
                    scores

            correctedPresentations =
                List.sortBy .sortOrder correctedScores
                    |> List.filterMap
                        (\score ->
                            assembleScoredPresentation score
                                |> Result.toMaybe
                        )
        in
        VerifiedBallot.verifyWithCorrections original correctedPresentations


{-| Converts an Api.PresiderBallotRecord into a domain PresiderBallot.
-}
assemblePresiderBallot : Api.PresiderBallotRecord -> PresiderBallot
assemblePresiderBallot record =
    PresiderBallot.for (rosterSideToSide record.winnerSide)
