module Awards exposing
    ( AwardCategory(..)
    , AwardCriteria
    , AwardTiebreaker(..)
    , nominationCategory
    )

import Rank exposing (NominationCategory(..))
import Side exposing (Side)
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
