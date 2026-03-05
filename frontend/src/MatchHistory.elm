module MatchHistory exposing
    ( MatchHistory
    , MatchRecord
    , SideCount
    , empty
    , fromRecords
    , hasPlayed
    , sideHistory
    , toRecords
    )

import Team exposing (Team)


type alias MatchRecord =
    { prosecution : Team
    , defense : Team
    }


type MatchHistory
    = MatchHistory (List MatchRecord)


type alias SideCount =
    { prosecution : Int
    , defense : Int
    }


empty : MatchHistory
empty =
    MatchHistory []


fromRecords : List MatchRecord -> MatchHistory
fromRecords records =
    MatchHistory records


toRecords : MatchHistory -> List MatchRecord
toRecords (MatchHistory records) =
    records


hasPlayed : MatchHistory -> Team -> Team -> Bool
hasPlayed (MatchHistory records) teamA teamB =
    List.any
        (\r ->
            (Team.sameTeam r.prosecution teamA
                && Team.sameTeam r.defense teamB
            )
                || (Team.sameTeam r.prosecution teamB
                        && Team.sameTeam r.defense teamA
                   )
        )
        records


sideHistory : MatchHistory -> Team -> SideCount
sideHistory (MatchHistory records) team =
    List.foldl
        (\r acc ->
            if Team.sameTeam r.prosecution team then
                { acc | prosecution = acc.prosecution + 1 }

            else if Team.sameTeam r.defense team then
                { acc | defense = acc.defense + 1 }

            else
                acc
        )
        { prosecution = 0, defense = 0 }
        records
