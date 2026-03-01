module TestHelpers exposing
    ( alice
    , applicant
    , coachName
    , email
    , studentName
    , teamA
    , teamB
    , teamName
    , teamNumber
    )

import Coach exposing (TeacherCoach, TeacherCoachApplicant)
import District
import Email exposing (Email)
import School
import Student
import Team exposing (Team)


studentName : String -> String -> Student.Name
studentName first last =
    case Student.nameFromStrings first last Nothing of
        Ok n ->
            n

        Err _ ->
            Debug.todo ("Invalid student name: " ++ first ++ " " ++ last)


alice : Student.Student
alice =
    Student.create (studentName "Alice" "Smith") Student.SheHer


coachName : String -> String -> Coach.Name
coachName first last =
    case Coach.nameFromStrings first last of
        Ok n ->
            n

        Err _ ->
            Debug.todo ("Invalid coach name: " ++ first ++ " " ++ last)


email : String -> Email
email raw =
    case Email.fromString raw of
        Ok e ->
            e

        Err _ ->
            Debug.todo ("Invalid email: " ++ raw)


teamName : String -> Team.Name
teamName raw =
    case Team.nameFromString raw of
        Ok n ->
            n

        Err _ ->
            Debug.todo ("Invalid team name: " ++ raw)


teamNumber : Int -> Team.Number
teamNumber n =
    case Team.numberFromInt n of
        Ok num ->
            num

        Err _ ->
            Debug.todo ("Invalid team number: " ++ String.fromInt n)


teamA : Team
teamA =
    Team.create
        (teamNumber 1)
        (teamName "Team A")
        { name = School.Name "School A"
        , district = { name = District.Name "District A" }
        }
        (coach "Alice" "Smith")


teamB : Team
teamB =
    Team.create
        (teamNumber 2)
        (teamName "Team B")
        { name = School.Name "School B"
        , district = { name = District.Name "District B" }
        }
        (coach "Bob" "Jones")


applicant : String -> String -> TeacherCoachApplicant
applicant first last =
    Coach.apply (coachName first last) (email "test@example.com")


coach : String -> String -> TeacherCoach
coach first last =
    Coach.verify (applicant first last)
