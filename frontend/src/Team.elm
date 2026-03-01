module Team exposing
    ( Name
    , Number
    , Team
    , addStudents
    , attorneyCoach
    , create
    , nameFromString
    , nameToString
    , numberFromInt
    , numberToInt
    , school
    , setAttorneyCoach
    , students
    , teacherCoach
    , teamName
    , teamNumber
    )

import Coach exposing (AttorneyCoach, TeacherCoach)
import Error exposing (Error(..))
import School exposing (School)
import Student exposing (Student)
import Validate


type Name
    = Name String


nameFromString : String -> Result (List Error) Name
nameFromString raw =
    let
        trimmed =
            String.trim raw
    in
    Validate.validate
        (Validate.all
            [ Validate.ifBlank identity
                (Error "Team name cannot be blank")
            ]
        )
        trimmed
        |> Result.map (\_ -> Name trimmed)


nameToString : Name -> String
nameToString (Name s) =
    s


type Number
    = Number Int


numberFromInt : Int -> Result (List Error) Number
numberFromInt n =
    Validate.validate
        (Validate.fromErrors
            (\v ->
                if v >= 1 then
                    []

                else
                    [ Error ("Team number must be positive, got " ++ String.fromInt v) ]
            )
        )
        n
        |> Result.map (Validate.fromValid >> Number)


numberToInt : Number -> Int
numberToInt (Number n) =
    n


type Team
    = Team
        { number : Number
        , name : Name
        , school : School
        , students : List Student
        , teacherCoach : TeacherCoach
        , attorneyCoach : Maybe AttorneyCoach
        }


create : Number -> Name -> School -> TeacherCoach -> Team
create num n s tc =
    Team
        { number = num
        , name = n
        , school = s
        , students = []
        , teacherCoach = tc
        , attorneyCoach = Nothing
        }


teamNumber : Team -> Number
teamNumber (Team r) =
    r.number


teamName : Team -> Name
teamName (Team r) =
    r.name


school : Team -> School
school (Team r) =
    r.school


students : Team -> List Student
students (Team r) =
    r.students


teacherCoach : Team -> TeacherCoach
teacherCoach (Team r) =
    r.teacherCoach


attorneyCoach : Team -> Maybe AttorneyCoach
attorneyCoach (Team r) =
    r.attorneyCoach


addStudents : List Student -> Team -> Team
addStudents newStudents (Team r) =
    Team { r | students = r.students ++ newStudents }


setAttorneyCoach : AttorneyCoach -> Team -> Team
setAttorneyCoach ac (Team r) =
    Team { r | attorneyCoach = Just ac }
