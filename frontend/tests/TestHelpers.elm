module TestHelpers exposing
    ( alice
    , applicant
    , bob
    , charlie
    , coachName
    , courtroomName
    , diana
    , districtName
    , email
    , eve
    , frank
    , grace
    , henry
    , iris
    , schoolName
    , studentName
    , teamA
    , teamB
    , teamName
    , teamNumber
    , validRoster
    , witness1
    , witness2
    , witness3
    , witness4
    )

import Coach exposing (TeacherCoach, TeacherCoachApplicant)
import Courtroom
import District
import Email exposing (Email)
import Roster exposing (AttorneyDuty(..), RoleAssignment(..), Roster)
import School
import Side exposing (Side(..))
import Student
import Team exposing (Team)
import Witness exposing (Witness)


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


bob : Student.Student
bob =
    Student.create (studentName "Bob" "Jones") Student.HeHim


charlie : Student.Student
charlie =
    Student.create (studentName "Charlie" "Brown") Student.HeHim


diana : Student.Student
diana =
    Student.create (studentName "Diana" "Prince") Student.SheHer


eve : Student.Student
eve =
    Student.create (studentName "Eve" "Torres") Student.SheHer


frank : Student.Student
frank =
    Student.create (studentName "Frank" "Castle") Student.HeHim


grace : Student.Student
grace =
    Student.create (studentName "Grace" "Hopper") Student.SheHer


henry : Student.Student
henry =
    Student.create (studentName "Henry" "Ford") Student.HeHim


iris : Student.Student
iris =
    Student.create (studentName "Iris" "West") Student.SheHer


witness1 : Witness
witness1 =
    case Witness.create "Jordan Riley" "Lead Investigator" of
        Ok w ->
            w

        Err _ ->
            Debug.todo "witness1 must be valid"


witness2 : Witness
witness2 =
    case Witness.create "Casey Morgan" "Expert Analyst" of
        Ok w ->
            w

        Err _ ->
            Debug.todo "witness2 must be valid"


witness3 : Witness
witness3 =
    case Witness.create "Taylor Reed" "Eyewitness" of
        Ok w ->
            w

        Err _ ->
            Debug.todo "witness3 must be valid"


witness4 : Witness
witness4 =
    case Witness.create "Sam Parker" "Character Witness" of
        Ok w ->
            w

        Err _ ->
            Debug.todo "witness4 must be valid"


validRoster : Roster
validRoster =
    case
        Roster.create Prosecution
            [ ClerkRole alice
            , BailiffRole bob
            , PretrialAttorney charlie
            , WitnessRole diana witness1
            , WitnessRole eve witness2
            , WitnessRole frank witness3
            , WitnessRole grace witness4
            , TrialAttorney henry Opening
            , TrialAttorney iris (DirectOf witness1)
            ]
    of
        Ok r ->
            r

        Err _ ->
            Debug.todo "validRoster must be valid"


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
