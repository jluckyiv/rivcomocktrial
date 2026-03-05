module ElimBracket exposing
    ( Matchup
    , bracket
    , higherSeed
    , lowerSeed
    )

import Array
import Error exposing (Error(..))
import Team exposing (Team)


type Matchup
    = Matchup { higherSeed : Team, lowerSeed : Team }


bracket : List Team -> Result (List Error) (List Matchup)
bracket teams =
    if List.length teams /= 8 then
        Err
            [ Error
                ("Elimination bracket requires exactly 8 teams, got "
                    ++ String.fromInt (List.length teams)
                )
            ]

    else
        let
            arr =
                Array.fromList teams

            matchup i j =
                Maybe.map2
                    (\h l -> Matchup { higherSeed = h, lowerSeed = l })
                    (Array.get i arr)
                    (Array.get j arr)
        in
        case
            [ matchup 0 7
            , matchup 1 6
            , matchup 2 5
            , matchup 3 4
            ]
                |> sequence
        of
            Just matchups ->
                Ok matchups

            Nothing ->
                Err [ Error "Internal error building bracket" ]


higherSeed : Matchup -> Team
higherSeed (Matchup r) =
    r.higherSeed


lowerSeed : Matchup -> Team
lowerSeed (Matchup r) =
    r.lowerSeed


sequence : List (Maybe a) -> Maybe (List a)
sequence list =
    List.foldr
        (\mx acc ->
            Maybe.map2 (::) mx acc
        )
        (Just [])
        list
