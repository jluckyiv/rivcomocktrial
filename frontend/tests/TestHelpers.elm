module TestHelpers exposing (applicant, teamA, teamB)

import Coach exposing (TeacherCoach, TeacherCoachApplicant)
import District
import School
import Student
import Team exposing (Team)


teamA : Team
teamA =
    { number = Team.Number 1
    , name = "Team A"
    , school =
        { name = School.Name "School A"
        , district = { name = District.Name "District A" }
        }
    , students = []
    , teacherCoach = coach "Alice" "Smith"
    , attorneyCoach = Nothing
    }


teamB : Team
teamB =
    { number = Team.Number 2
    , name = "Team B"
    , school =
        { name = School.Name "School B"
        , district = { name = District.Name "District B" }
        }
    , students = []
    , teacherCoach = coach "Bob" "Jones"
    , attorneyCoach = Nothing
    }


applicant : String -> String -> TeacherCoachApplicant
applicant first last =
    { name =
        { first = first
        , last = last
        , preferred = Nothing
        }
    , email = "test@example.com"
    }


coach : String -> String -> TeacherCoach
coach first last =
    { name =
        { first = first
        , last = last
        , preferred = Nothing
        }
    , email = "test@example.com"
    }
