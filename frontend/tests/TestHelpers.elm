module TestHelpers exposing
    ( alice
    , applicant
    , bob
    , charlie
    , coach
    , coachName
    , courtroomA
    , courtroomB
    , courtroomName
    , diana
    , districtName
    , email
    , eve
    , frank
    , grace
    , henry
    , iris
    , judgeName
    , schoolName
    , studentName
    , teamA
    , teamB
    , teamC
    , teamName
    , teamNumber
    , testActiveTrial
    , testJudge
    , testPresider
    , testScorer
    , testSubmittedBallot
    , testTrial
    , trialFor
    , validRoster
    , volunteerName
    , witness1
    , witness2
    , witness3
    , witness4
    )

import ActiveTrial exposing (ActiveTrial)
import Assignment exposing (Assignment(..))
import Coach exposing (TeacherCoach, TeacherCoachApplicant)
import Courtroom exposing (Courtroom)
import District
import Email exposing (Email)
import Judge
import Pairing
import PresiderBallot
import Roster exposing (AttorneyDuty(..), RoleAssignment(..), Roster)
import School
import Side exposing (Side(..))
import Student
import SubmittedBallot exposing (SubmittedBallot)
import Team exposing (Team)
import Trial exposing (Trial)
import TrialRole exposing (TrialRole(..))
import Volunteer
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


judgeName : String -> String -> Judge.Name
judgeName first last =
    case Judge.nameFromStrings first last of
        Ok n ->
            n

        Err _ ->
            Debug.todo ("Invalid judge name: " ++ first ++ " " ++ last)


testJudge : Judge.Judge
testJudge =
    Judge.create (judgeName "Test" "Judge") (email "judge@example.com")


coach : String -> String -> TeacherCoach
coach first last =
    Coach.verify (applicant first last)


volunteerName : String -> String -> Volunteer.Name
volunteerName first last =
    case Volunteer.nameFromStrings first last of
        Ok n ->
            n

        Err _ ->
            Debug.todo ("Invalid volunteer name: " ++ first ++ " " ++ last)


testScorer : Volunteer.Volunteer
testScorer =
    Volunteer.create
        (volunteerName "Test" "Scorer")
        (email "scorer@example.com")
        ScorerRole


testPresider : Volunteer.Volunteer
testPresider =
    Volunteer.create
        (volunteerName "Test" "Presider")
        (email "presider@example.com")
        PresiderRole


teamC : Team
teamC =
    Team.create
        (teamNumber 3)
        (teamName "Team C")
        (School.create
            (schoolName "School C")
            (District.create (districtName "District C"))
        )
        (coach "Charlie" "Davis")


courtroomA : Courtroom
courtroomA =
    Courtroom.create (courtroomName "Dept A")


courtroomB : Courtroom
courtroomB =
    Courtroom.create (courtroomName "Dept B")


testTrial : Trial
testTrial =
    let
        pairing =
            case Pairing.create teamA teamB of
                Ok p ->
                    p

                Err _ ->
                    Debug.todo "testTrial pairing must be valid"
    in
    case
        pairing
            |> Pairing.assignCourtroom courtroomA
            |> Pairing.assignJudge testJudge
            |> Trial.fromPairing
    of
        Just t ->
            t

        Nothing ->
            Debug.todo "testTrial must be valid"


trialFor : Team -> Team -> Trial
trialFor prosecution defense =
    let
        pairing =
            case Pairing.create prosecution defense of
                Ok p ->
                    p

                Err _ ->
                    Debug.todo "trialFor pairing must be valid"
    in
    case
        pairing
            |> Pairing.assignCourtroom courtroomA
            |> Pairing.assignJudge testJudge
            |> Trial.fromPairing
    of
        Just t ->
            t

        Nothing ->
            Debug.todo "trialFor must be valid"


testActiveTrial : ActiveTrial
testActiveTrial =
    ActiveTrial.fromTrial testTrial


testSubmittedBallot : SubmittedBallot
testSubmittedBallot =
    let
        points =
            case SubmittedBallot.fromInt 8 of
                Ok p ->
                    p

                Err _ ->
                    Debug.todo "testSubmittedBallot points must be valid"
    in
    case
        SubmittedBallot.create
            [ SubmittedBallot.Opening Prosecution alice points ]
    of
        Ok b ->
            b

        Err _ ->
            Debug.todo "testSubmittedBallot must be valid"
