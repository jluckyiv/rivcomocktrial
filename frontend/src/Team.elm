module Team exposing (Number(..), Team)

import Coach exposing (AttorneyCoach, TeacherCoach)
import School exposing (School)
import Student exposing (Student)


type Number
    = Number Int


type alias Team =
    { number : Number
    , name : String
    , school : School
    , students : List Student
    , teacherCoach : TeacherCoach
    , attorneyCoach : Maybe AttorneyCoach
    }
