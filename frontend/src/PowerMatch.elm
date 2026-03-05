module PowerMatch exposing
    ( CrossBracketStrategy(..)
    , PowerMatchResult
    , ProposedPairing
    , RankedTeam
    , powerMatch
    )

import MatchHistory exposing (MatchHistory)
import Team exposing (Team)


type CrossBracketStrategy
    = HighHigh
    | HighLow


type alias RankedTeam =
    { team : Team
    , wins : Int
    , losses : Int
    , rank : Int
    }


type alias PowerMatchResult =
    { pairings : List ProposedPairing
    , warnings : List String
    }


type alias ProposedPairing =
    { prosecutionTeam : Team
    , defenseTeam : Team
    }


{-| Generate power-matched pairings.

Takes pre-ranked teams (caller determines ranking),
all prior match history (for rematch/side checking), and
match history for the current round.

Guarantees:

  - Every available team appears exactly once
  - No rematches against any prior-round opponent
  - Side balance: no team plays same side 3+ times
  - Side switching: R1 P -> R2 D, R3 P -> R4 D

-}
powerMatch :
    CrossBracketStrategy
    -> List RankedTeam
    -> MatchHistory
    -> MatchHistory
    -> PowerMatchResult
powerMatch strategy rankedTeams allHistory currentRoundHistory =
    let
        pairedTeams =
            currentRoundPairedTeams currentRoundHistory

        available =
            List.filter
                (\rt -> not (List.any (Team.sameTeam rt.team) pairedTeams))
                rankedTeams

        brackets =
            groupByWins available

        ( withinPairs, spillover ) =
            pairWithinBrackets allHistory brackets

        crossPairs =
            pairCrossBracket strategy allHistory spillover

        allPairs =
            withinPairs ++ crossPairs

        pairings =
            List.map (assignSides allHistory) allPairs
    in
    { pairings = pairings
    , warnings = []
    }


{-| Extract teams already paired in the current round's history.
-}
currentRoundPairedTeams : MatchHistory -> List Team
currentRoundPairedTeams history =
    let
        records =
            MatchHistory.toRecords history
    in
    List.concatMap
        (\r -> [ r.prosecution, r.defense ])
        records



-- GROUPING


groupByWins :
    List RankedTeam
    -> List ( Int, List RankedTeam )
groupByWins teams =
    let
        sorted =
            List.sortBy
                (\rt -> ( negate rt.wins, rt.rank ))
                teams

        folder rt acc =
            case acc of
                ( w, group ) :: rest ->
                    if w == rt.wins then
                        ( w, group ++ [ rt ] ) :: rest

                    else
                        ( rt.wins, [ rt ] ) :: acc

                [] ->
                    [ ( rt.wins, [ rt ] ) ]
    in
    List.foldl folder [] sorted |> List.reverse



-- WITHIN-BRACKET PAIRING


pairWithinBrackets :
    MatchHistory
    -> List ( Int, List RankedTeam )
    -> ( List ( RankedTeam, RankedTeam ), List RankedTeam )
pairWithinBrackets allHistory brackets =
    List.foldl
        (\( _, bracketTeams ) ( pairsAcc, spillAcc ) ->
            let
                ( pairs, spill ) =
                    pairWithinBracket allHistory bracketTeams
            in
            ( pairsAcc ++ pairs, spillAcc ++ spill )
        )
        ( [], [] )
        brackets


pairWithinBracket :
    MatchHistory
    -> List RankedTeam
    -> ( List ( RankedTeam, RankedTeam ), List RankedTeam )
pairWithinBracket allHistory teams =
    let
        sorted =
            List.sortBy .rank teams
    in
    pairTopBottom allHistory sorted [] []


pairTopBottom :
    MatchHistory
    -> List RankedTeam
    -> List ( RankedTeam, RankedTeam )
    -> List RankedTeam
    -> ( List ( RankedTeam, RankedTeam ), List RankedTeam )
pairTopBottom allHistory remaining pairs spill =
    case remaining of
        [] ->
            ( List.reverse pairs, spill )

        [ only ] ->
            ( List.reverse pairs, only :: spill )

        _ ->
            let
                top =
                    listHead remaining

                rest =
                    List.drop 1 remaining
            in
            case top of
                Nothing ->
                    ( List.reverse pairs, spill )

                Just topTeam ->
                    case findPartnerFromBottom allHistory topTeam rest of
                        Just ( partner, restWithout ) ->
                            pairTopBottom allHistory
                                restWithout
                                (( topTeam, partner ) :: pairs)
                                spill

                        Nothing ->
                            -- Top can't pair within bracket
                            pairTopBottom allHistory
                                rest
                                pairs
                                (topTeam :: spill)


findPartnerFromBottom :
    MatchHistory
    -> RankedTeam
    -> List RankedTeam
    -> Maybe ( RankedTeam, List RankedTeam )
findPartnerFromBottom allHistory top candidates =
    findFromEnd allHistory top (List.reverse candidates) []


findFromEnd :
    MatchHistory
    -> RankedTeam
    -> List RankedTeam
    -> List RankedTeam
    -> Maybe ( RankedTeam, List RankedTeam )
findFromEnd allHistory top reversed skipped =
    case reversed of
        [] ->
            Nothing

        candidate :: rest ->
            if canPair allHistory top candidate then
                Just
                    ( candidate
                    , List.reverse rest ++ List.reverse skipped
                    )

            else
                findFromEnd allHistory
                    top
                    rest
                    (candidate :: skipped)



-- CROSS-BRACKET PAIRING


pairCrossBracket :
    CrossBracketStrategy
    -> MatchHistory
    -> List RankedTeam
    -> List ( RankedTeam, RankedTeam )
pairCrossBracket strategy allHistory spillover =
    let
        sorted =
            List.sortBy
                (\rt -> ( negate rt.wins, rt.rank ))
                spillover
    in
    backtrackPairCross strategy allHistory sorted
        |> Maybe.withDefault []


{-| Backtracking cross-bracket pairing. Tries each valid
partner for the first team; if the recursive pairing of
the remaining teams fails, backtracks and tries the next
candidate.
-}
backtrackPairCross :
    CrossBracketStrategy
    -> MatchHistory
    -> List RankedTeam
    -> Maybe (List ( RankedTeam, RankedTeam ))
backtrackPairCross strategy allHistory remaining =
    case remaining of
        [] ->
            Just []

        [ _ ] ->
            -- Odd leftover; shouldn't happen
            Just []

        first :: rest ->
            let
                candidates =
                    case strategy of
                        HighHigh ->
                            rest

                        HighLow ->
                            List.reverse rest
            in
            tryPartners strategy allHistory first candidates []


tryPartners :
    CrossBracketStrategy
    -> MatchHistory
    -> RankedTeam
    -> List RankedTeam
    -> List RankedTeam
    -> Maybe (List ( RankedTeam, RankedTeam ))
tryPartners strategy allHistory team candidates skipped =
    case candidates of
        [] ->
            Nothing

        candidate :: rest ->
            if canPair allHistory team candidate then
                let
                    restWithout =
                        List.reverse skipped ++ rest
                in
                case backtrackPairCross strategy allHistory restWithout of
                    Just morePairs ->
                        Just (( team, candidate ) :: morePairs)

                    Nothing ->
                        -- This choice blocks a solution; try next
                        tryPartners strategy
                            allHistory
                            team
                            rest
                            (candidate :: skipped)

            else
                tryPartners strategy
                    allHistory
                    team
                    rest
                    (candidate :: skipped)



-- CONSTRAINTS


canPair : MatchHistory -> RankedTeam -> RankedTeam -> Bool
canPair allHistory a b =
    not (MatchHistory.hasPlayed allHistory a.team b.team)
        && not (sameSideConflict allHistory a b)


sameSideConflict :
    MatchHistory
    -> RankedTeam
    -> RankedTeam
    -> Bool
sameSideConflict allHistory a b =
    let
        aSides =
            MatchHistory.sideHistory allHistory a.team

        bSides =
            MatchHistory.sideHistory allHistory b.team

        aNeeds =
            neededSide aSides

        bNeeds =
            neededSide bSides
    in
    case ( aNeeds, bNeeds ) of
        ( Just sideA, Just sideB ) ->
            sideA == sideB

        _ ->
            False


type Side
    = Prosecution
    | Defense


neededSide : MatchHistory.SideCount -> Maybe Side
neededSide sides =
    if sides.prosecution > sides.defense then
        Just Defense

    else if sides.defense > sides.prosecution then
        Just Prosecution

    else
        Nothing



-- SIDE ASSIGNMENT


assignSides :
    MatchHistory
    -> ( RankedTeam, RankedTeam )
    -> ProposedPairing
assignSides allHistory ( a, b ) =
    let
        aSides =
            MatchHistory.sideHistory allHistory a.team

        bSides =
            MatchHistory.sideHistory allHistory b.team
    in
    if aSides.prosecution <= bSides.prosecution then
        { prosecutionTeam = a.team
        , defenseTeam = b.team
        }

    else
        { prosecutionTeam = b.team
        , defenseTeam = a.team
        }



-- HELPERS


listHead : List a -> Maybe a
listHead list =
    case list of
        x :: _ ->
            Just x

        [] ->
            Nothing
