module PowerMatch exposing
    ( CrossBracketStrategy(..)
    , PowerMatchResult
    , ProposedPairing
    , RankedTeam
    , SideCount
    , hasPlayed
    , powerMatch
    , sideHistory
    )

import Api exposing (Team, Trial)


type CrossBracketStrategy
    = HighHigh
    | HighLow


type alias RankedTeam =
    { team : Team
    , wins : Int
    , losses : Int
    , rank : Int
    }


type alias SideCount =
    { prosecution : Int
    , defense : Int
    }


type alias PowerMatchResult =
    { pairings : List ProposedPairing
    , warnings : List String
    }


type alias ProposedPairing =
    { prosecutionTeam : String
    , defenseTeam : String
    }


hasPlayed : List Trial -> String -> String -> Bool
hasPlayed trials teamA teamB =
    List.any
        (\t ->
            (t.prosecutionTeam == teamA && t.defenseTeam == teamB)
                || (t.prosecutionTeam == teamB && t.defenseTeam == teamA)
        )
        trials


sideHistory : List Trial -> String -> SideCount
sideHistory trials teamId =
    List.foldl
        (\t acc ->
            if t.prosecutionTeam == teamId then
                { acc | prosecution = acc.prosecution + 1 }

            else if t.defenseTeam == teamId then
                { acc | defense = acc.defense + 1 }

            else
                acc
        )
        { prosecution = 0, defense = 0 }
        trials


{-| Generate power-matched pairings.

Takes pre-ranked teams (caller determines ranking),
all prior trials (for rematch/side checking), and trials
already created in the current round.

Guarantees:

  - Every available team appears exactly once
  - No rematches against any prior-round opponent
  - Side balance: no team plays same side 3+ times
  - Side switching: R1 P -> R2 D, R3 P -> R4 D

-}
powerMatch :
    CrossBracketStrategy
    -> List RankedTeam
    -> List Trial
    -> List Trial
    -> PowerMatchResult
powerMatch strategy rankedTeams allTrials currentRoundTrials =
    let
        pairedTeamIds =
            List.concatMap
                (\t -> [ t.prosecutionTeam, t.defenseTeam ])
                currentRoundTrials

        available =
            List.filter
                (\rt -> not (List.member rt.team.id pairedTeamIds))
                rankedTeams

        brackets =
            groupByWins available

        ( withinPairs, spillover ) =
            pairWithinBrackets allTrials brackets

        crossPairs =
            pairCrossBracket strategy allTrials spillover

        allPairs =
            withinPairs ++ crossPairs

        pairings =
            List.map (assignSides allTrials) allPairs
    in
    { pairings = pairings
    , warnings = []
    }



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
    List Trial
    -> List ( Int, List RankedTeam )
    -> ( List ( RankedTeam, RankedTeam ), List RankedTeam )
pairWithinBrackets allTrials brackets =
    List.foldl
        (\( _, bracketTeams ) ( pairsAcc, spillAcc ) ->
            let
                ( pairs, spill ) =
                    pairWithinBracket allTrials bracketTeams
            in
            ( pairsAcc ++ pairs, spillAcc ++ spill )
        )
        ( [], [] )
        brackets


pairWithinBracket :
    List Trial
    -> List RankedTeam
    -> ( List ( RankedTeam, RankedTeam ), List RankedTeam )
pairWithinBracket allTrials teams =
    let
        sorted =
            List.sortBy .rank teams
    in
    pairTopBottom allTrials sorted [] []


pairTopBottom :
    List Trial
    -> List RankedTeam
    -> List ( RankedTeam, RankedTeam )
    -> List RankedTeam
    -> ( List ( RankedTeam, RankedTeam ), List RankedTeam )
pairTopBottom allTrials remaining pairs spill =
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
                    case findPartnerFromBottom allTrials topTeam rest of
                        Just ( partner, restWithout ) ->
                            pairTopBottom allTrials
                                restWithout
                                (( topTeam, partner ) :: pairs)
                                spill

                        Nothing ->
                            -- Top can't pair within bracket
                            pairTopBottom allTrials
                                rest
                                pairs
                                (topTeam :: spill)


findPartnerFromBottom :
    List Trial
    -> RankedTeam
    -> List RankedTeam
    -> Maybe ( RankedTeam, List RankedTeam )
findPartnerFromBottom allTrials top candidates =
    findFromEnd allTrials top (List.reverse candidates) []


findFromEnd :
    List Trial
    -> RankedTeam
    -> List RankedTeam
    -> List RankedTeam
    -> Maybe ( RankedTeam, List RankedTeam )
findFromEnd allTrials top reversed skipped =
    case reversed of
        [] ->
            Nothing

        candidate :: rest ->
            if canPair allTrials top candidate then
                Just
                    ( candidate
                    , List.reverse rest ++ List.reverse skipped
                    )

            else
                findFromEnd allTrials
                    top
                    rest
                    (candidate :: skipped)



-- CROSS-BRACKET PAIRING


pairCrossBracket :
    CrossBracketStrategy
    -> List Trial
    -> List RankedTeam
    -> List ( RankedTeam, RankedTeam )
pairCrossBracket strategy allTrials spillover =
    let
        sorted =
            List.sortBy
                (\rt -> ( negate rt.wins, rt.rank ))
                spillover
    in
    backtrackPairCross strategy allTrials sorted
        |> Maybe.withDefault []


{-| Backtracking cross-bracket pairing. Tries each valid
partner for the first team; if the recursive pairing of
the remaining teams fails, backtracks and tries the next
candidate.
-}
backtrackPairCross :
    CrossBracketStrategy
    -> List Trial
    -> List RankedTeam
    -> Maybe (List ( RankedTeam, RankedTeam ))
backtrackPairCross strategy allTrials remaining =
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
            tryPartners strategy allTrials first candidates []


tryPartners :
    CrossBracketStrategy
    -> List Trial
    -> RankedTeam
    -> List RankedTeam
    -> List RankedTeam
    -> Maybe (List ( RankedTeam, RankedTeam ))
tryPartners strategy allTrials team candidates skipped =
    case candidates of
        [] ->
            Nothing

        candidate :: rest ->
            if canPair allTrials team candidate then
                let
                    restWithout =
                        List.reverse skipped ++ rest
                in
                case backtrackPairCross strategy allTrials restWithout of
                    Just morePairs ->
                        Just (( team, candidate ) :: morePairs)

                    Nothing ->
                        -- This choice blocks a solution; try next
                        tryPartners strategy
                            allTrials
                            team
                            rest
                            (candidate :: skipped)

            else
                tryPartners strategy
                    allTrials
                    team
                    rest
                    (candidate :: skipped)



-- CONSTRAINTS


canPair : List Trial -> RankedTeam -> RankedTeam -> Bool
canPair allTrials a b =
    not (hasPlayed allTrials a.team.id b.team.id)
        && not (sameSideConflict allTrials a b)


sameSideConflict :
    List Trial
    -> RankedTeam
    -> RankedTeam
    -> Bool
sameSideConflict allTrials a b =
    let
        aSides =
            sideHistory allTrials a.team.id

        bSides =
            sideHistory allTrials b.team.id

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


neededSide : SideCount -> Maybe Side
neededSide sides =
    if sides.prosecution > sides.defense then
        Just Defense

    else if sides.defense > sides.prosecution then
        Just Prosecution

    else
        Nothing



-- SIDE ASSIGNMENT


assignSides :
    List Trial
    -> ( RankedTeam, RankedTeam )
    -> ProposedPairing
assignSides allTrials ( a, b ) =
    let
        aSides =
            sideHistory allTrials a.team.id

        bSides =
            sideHistory allTrials b.team.id
    in
    if aSides.prosecution <= bSides.prosecution then
        { prosecutionTeam = a.team.id
        , defenseTeam = b.team.id
        }

    else
        { prosecutionTeam = b.team.id
        , defenseTeam = a.team.id
        }



-- HELPERS


listHead : List a -> Maybe a
listHead list =
    case list of
        x :: _ ->
            Just x

        [] ->
            Nothing
