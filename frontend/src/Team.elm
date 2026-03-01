module Team exposing (Side(..), Team)

import Coach exposing (AttorneyCoach, TeacherCoach)
import School exposing (School)
import Student exposing (Student)


type Side
    = Prosecution
    | Defense


type alias Team =
    { teamNumber : Int
    , name : String
    , school : School
    , students : List Student
    , teacherCoach : TeacherCoach
    , attorneyCoach : Maybe AttorneyCoach
    }
