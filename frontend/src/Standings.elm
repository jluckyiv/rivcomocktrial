module Standings exposing
    ( RankingStrategy
    , TeamRecord
    , Tiebreaker(..)
    , cumulativePercentage
    , losses
    , pointsAgainst
    , pointsFor
    , rank
    , teamRecord
    , wins
    )


type TeamRecord
    = TeamRecord
        { wins : Int
        , losses : Int
        , pointsFor : Int
        , pointsAgainst : Int
        }


teamRecord :
    { wins : Int
    , losses : Int
    , pointsFor : Int
    , pointsAgainst : Int
    }
    -> TeamRecord
teamRecord r =
    TeamRecord r


wins : TeamRecord -> Int
wins (TeamRecord r) =
    r.wins


losses : TeamRecord -> Int
losses (TeamRecord r) =
    r.losses


pointsFor : TeamRecord -> Int
pointsFor (TeamRecord r) =
    r.pointsFor


pointsAgainst : TeamRecord -> Int
pointsAgainst (TeamRecord r) =
    r.pointsAgainst


cumulativePercentage : TeamRecord -> Float
cumulativePercentage (TeamRecord rec) =
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
            compare (wins b) (wins a)

        ByCumulativePercentage ->
            compare
                (cumulativePercentage b)
                (cumulativePercentage a)

        ByPointDifferential ->
            compare
                (pointsFor b - pointsAgainst b)
                (pointsFor a - pointsAgainst a)

        ByHeadToHead ->
            EQ
