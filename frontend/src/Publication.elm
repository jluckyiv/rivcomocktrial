module Publication exposing
    ( Audience(..)
    , Publication
    , PublicationLevel(..)
    , audience
    , audienceAtLeast
    , isVisibleTo
    , level
    , levelAtLeast
    , publish
    , round
    )

import Error exposing (Error(..))
import Round exposing (Round)
import RoundProgress exposing (RoundProgress(..))


type PublicationLevel
    = ResultOnly
    | ScoreSheet
    | FullBallots


type Audience
    = OwnTeamCoach
    | AllCoaches
    | Public


type Publication
    = Publication
        { round : Round
        , level : PublicationLevel
        , audience : Audience
        }


publish :
    Round
    -> PublicationLevel
    -> Audience
    -> RoundProgress
    -> Result (List Error) Publication
publish r lvl aud progress =
    case progress of
        FullyVerified ->
            Ok
                (Publication
                    { round = r
                    , level = lvl
                    , audience = aud
                    }
                )

        _ ->
            Err
                [ Error
                    ("Cannot publish until round is fully verified, current status: "
                        ++ RoundProgress.progressToString progress
                    )
                ]


round : Publication -> Round
round (Publication r) =
    r.round


level : Publication -> PublicationLevel
level (Publication r) =
    r.level


audience : Publication -> Audience
audience (Publication r) =
    r.audience


levelAtLeast : PublicationLevel -> PublicationLevel -> Bool
levelAtLeast actual minimum =
    levelToInt actual >= levelToInt minimum


audienceAtLeast : Audience -> Audience -> Bool
audienceAtLeast actual minimum =
    audienceToInt actual >= audienceToInt minimum


isVisibleTo :
    PublicationLevel
    -> Audience
    -> Publication
    -> Bool
isVisibleTo queryLevel queryAudience pub =
    levelAtLeast (level pub) queryLevel
        && audienceAtLeast (audience pub) queryAudience


levelToInt : PublicationLevel -> Int
levelToInt lvl =
    case lvl of
        ResultOnly ->
            0

        ScoreSheet ->
            1

        FullBallots ->
            2


audienceToInt : Audience -> Int
audienceToInt aud =
    case aud of
        OwnTeamCoach ->
            0

        AllCoaches ->
            1

        Public ->
            2
