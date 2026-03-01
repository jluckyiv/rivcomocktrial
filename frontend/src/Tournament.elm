module Tournament exposing
    ( Config
    , Status(..)
    , Tournament
    , statusToString
    )


type Status
    = Draft
    | Registration
    | Active
    | Completed


type alias Config =
    { numPreliminaryRounds : Int
    , numEliminationRounds : Int
    }


type alias Tournament =
    { name : String
    , year : Int
    , config : Config
    , status : Status
    }


statusToString : Status -> String
statusToString status =
    case status of
        Draft ->
            "Draft"

        Registration ->
            "Registration"

        Active ->
            "Active"

        Completed ->
            "Completed"
