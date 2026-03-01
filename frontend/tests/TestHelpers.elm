module TestHelpers exposing
    ( alice
    , applicant
    , coachName
    , courtroomName
    , districtName
    , email
    , schoolName
    , studentName
    , teamA
    , teamB
    , teamName
    , teamNumber
    )

import Coach exposing (TeacherCoach, TeacherCoachApplicant)
import Courtroom
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


districtName : String -> District.Name
districtName raw =
    case District.nameFromString raw of
        Ok n ->
            n

        Err _ ->
            Debug.todo ("Invalid district name: " ++ raw)


schoolName : String -> School.Name
schoolName raw =
    case School.nameFromString raw of
        Ok n ->
            n

        Err _ ->
            Debug.todo ("Invalid school name: " ++ raw)


courtroomName : String -> Courtroom.Name
courtroomName raw =
    case Courtroom.nameFromString raw of
        Ok n ->
            n

        Err _ ->
            Debug.todo ("Invalid courtroom name: " ++ raw)


teamA : Team
teamA =
    Team.create
        (teamNumber 1)
        (teamName "Team A")
        (School.create
            (schoolName "School A")
            (District.create (districtName "District A"))
        )
        (coach "Alice" "Smith")


teamB : Team
teamB =
    Team.create
        (teamNumber 2)
        (teamName "Team B")
        (School.create
            (schoolName "School B")
            (District.create (districtName "District B"))
        )
        (coach "Bob" "Jones")


applicant : String -> String -> TeacherCoachApplicant
applicant first last =
    Coach.apply (coachName first last) (email "test@example.com")


coach : String -> String -> TeacherCoach
coach first last =
    Coach.verify (applicant first last)
