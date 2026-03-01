module Round exposing
    ( Phase(..)
    , Round(..)
    , phase
    , phaseToString
    , toString
    )


type Round
    = Preliminary1
    | Preliminary2
    | Preliminary3
    | Preliminary4
    | Quarterfinal
    | Semifinal
    | Final


type Phase
    = Preliminary
    | Elimination


phase : Round -> Phase
phase round =
    case round of
        Preliminary1 ->
            Preliminary

        Preliminary2 ->
            Preliminary

        Preliminary3 ->
            Preliminary

        Preliminary4 ->
            Preliminary

        Quarterfinal ->
            Elimination

        Semifinal ->
            Elimination

        Final ->
            Elimination


toString : Round -> String
toString round =
    case round of
        Preliminary1 ->
            "Preliminary 1"

        Preliminary2 ->
            "Preliminary 2"

        Preliminary3 ->
            "Preliminary 3"

        Preliminary4 ->
            "Preliminary 4"

        Quarterfinal ->
            "Quarterfinal"

        Semifinal ->
            "Semifinal"

        Final ->
            "Final"


phaseToString : Phase -> String
phaseToString p =
    case p of
        Preliminary ->
            "Preliminary"

        Elimination ->
            "Elimination"
