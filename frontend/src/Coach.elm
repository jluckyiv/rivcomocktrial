module Coach exposing (AttorneyCoach, TeacherCoach)

import Email exposing (Email)
import Name exposing (Name)


type alias TeacherCoach =
    { name : Name
    , email : Email
    }


type alias AttorneyCoach =
    { name : Name
    , email : Maybe Email
    }
