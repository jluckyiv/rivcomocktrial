module Awards exposing
    ( AwardCategory(..)
    , AwardCriteria
    , AwardTiebreaker(..)
    , StudentScore
    , nominationCategory
    , scoreByRankPoints
    )

import Rank exposing (NominationCategory(..))
import Side exposing (Side)
import Student exposing (Student)
import Witness exposing (Witness)


type AwardCategory
    = BestAttorney Side
    | BestWitness Witness
    | BestClerk
    | BestBailiff


nominationCategory : AwardCategory -> NominationCategory
nominationCategory category =
    case category of
        BestAttorney _ ->
            Advocate

        BestWitness _ ->
            NonAdvocate

        BestClerk ->
            NonAdvocate

        BestBailiff ->
            NonAdvocate


type AwardTiebreaker
    = ByRankPoints
    | ByRawScore
    | ByMedianDelta


type alias AwardCriteria =
    List AwardTiebreaker


type alias StudentScore =
    { student : Student, totalRankPoints : Int }


scoreByRankPoints :
    List ( Student, List Rank.Rank )
    -> List StudentScore
scoreByRankPoints entries =
    let
        count =
            List.length entries
    in
    entries
        |> List.map (scoreOneStudent count)
        |> List.sortBy (\s -> negate s.totalRankPoints)


scoreOneStudent : Int -> ( Student, List Rank.Rank ) -> StudentScore
scoreOneStudent count ( s, ranks ) =
    { student = s
    , totalRankPoints =
        ranks
            |> List.filterMap (Rank.rankPoints count >> Result.toMaybe)
            |> List.sum
    }
