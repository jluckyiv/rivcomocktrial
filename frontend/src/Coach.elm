module Coach exposing
    ( AttorneyCoach
    , TeacherCoach
    , TeacherCoachApplicant
    , verify
    )

import Email exposing (Email)
import Student exposing (Name)


type alias TeacherCoachApplicant =
    { name : Name
    , email : Email
    }


type alias TeacherCoach =
    { name : Name
    , email : Email
    }


type alias AttorneyCoach =
    { name : Name
    , email : Maybe Email
    }


verify : TeacherCoachApplicant -> TeacherCoach
verify applicant =
    { name = applicant.name
    , email = applicant.email
    }
