module TestHelpers exposing
    ( applicant
    , coachName
    , teamA
    , teamB
    )

import Coach exposing (TeacherCoach, TeacherCoachApplicant)
import District
import School
import Student
import Team exposing (Team)


coachName : String -> String -> Coach.Name
coachName first last =
    case Coach.nameFromStrings first last of
        Ok n ->
            n

        Err _ ->
            Debug.todo ("Invalid coach name: " ++ first ++ " " ++ last)


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
    Coach.apply (coachName first last) "test@example.com"


coach : String -> String -> TeacherCoach
coach first last =
    Coach.verify (applicant first last)
