module Student exposing (Student)

import Name exposing (Name)
import Pronouns exposing (Pronouns)


type alias Student =
    { name : Name
    , pronouns : Pronouns
    }
