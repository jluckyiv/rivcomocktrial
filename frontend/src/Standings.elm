module Standings exposing
    ( RankingStrategy
    , TeamRecord
    , Tiebreaker(..)
    , cumulativePercentage
    , rank
    )


type alias TeamRecord =
    { wins : Int
    , losses : Int
    , pointsFor : Int
    , pointsAgainst : Int
    }


cumulativePercentage : TeamRecord -> Float
cumulativePercentage rec =
    let
        total =
            rec.pointsFor + rec.pointsAgainst
    in
    if total == 0 then
        0.0

    else
        toFloat rec.pointsFor / toFloat total


type Tiebreaker
    = ByWins
    | ByCumulativePercentage
    | ByPointDifferential
    | ByHeadToHead


type alias RankingStrategy =
    List Tiebreaker


rank : RankingStrategy -> List ( team, TeamRecord ) -> List ( team, TeamRecord )
rank strategy entries =
    List.sortWith (compareByStrategy strategy) entries


compareByStrategy : RankingStrategy -> ( team, TeamRecord ) -> ( team, TeamRecord ) -> Order
compareByStrategy strategy ( _, a ) ( _, b ) =
    compareByTiebreakers strategy a b


compareByTiebreakers : List Tiebreaker -> TeamRecord -> TeamRecord -> Order
compareByTiebreakers tiebreakers a b =
    case tiebreakers of
        [] ->
            EQ

        breaker :: rest ->
            case compareByTiebreaker breaker a b of
                EQ ->
                    compareByTiebreakers rest a b

                order ->
                    order


compareByTiebreaker : Tiebreaker -> TeamRecord -> TeamRecord -> Order
compareByTiebreaker breaker a b =
    case breaker of
        ByWins ->
            compare b.wins a.wins

        ByCumulativePercentage ->
            compare
                (cumulativePercentage b)
                (cumulativePercentage a)

        ByPointDifferential ->
            compare
                (b.pointsFor - b.pointsAgainst)
                (a.pointsFor - a.pointsAgainst)

        ByHeadToHead ->
            EQ
