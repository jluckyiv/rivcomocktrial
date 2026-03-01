module Team exposing (Team)

import Coach exposing (AttorneyCoach, TeacherCoach)
import School exposing (School)
import Side exposing (Side)
import Student exposing (Student)


type alias Team =
    { teamNumber : Int
    , name : String
    , school : School
    , side : Side
    , students : List Student
    , teacherCoach : TeacherCoach
    , attorneyCoach : Maybe AttorneyCoach
    }
