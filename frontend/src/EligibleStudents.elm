module EligibleStudents exposing
    ( Config
    , EligibleStudents
    , Status(..)
    , addStudent
    , config
    , create
    , defaultConfig
    , lock
    , removeStudent
    , status
    , statusToString
    , students
    , submit
    , team
    )

import Error exposing (Error(..))
import Student exposing (Student)
import Team exposing (Team)


type alias Config =
    { minStudents : Int
    , maxStudents : Int
    }


defaultConfig : Config
defaultConfig =
    { minStudents = 8
    , maxStudents = 25
    }


type EligibleStudents
    = EligibleStudents
        { team : Team
        , students : List Student
        , status : Status
        , config : Config
        }


type Status
    = Draft
    | Submitted
    | Locked


create : Config -> Team -> EligibleStudents
create cfg t =
    EligibleStudents
        { team = t
        , students = []
        , status = Draft
        , config = cfg
        }


addStudent :
    Student
    -> EligibleStudents
    -> Result (List Error) EligibleStudents
addStudent s (EligibleStudents r) =
    case r.status of
        Draft ->
            if isDuplicate s r.students then
                Err [ Error "Student is already in the list" ]

            else if List.length r.students >= r.config.maxStudents then
                Err
                    [ Error
                        ("Cannot exceed "
                            ++ String.fromInt r.config.maxStudents
                            ++ " students"
                        )
                    ]

            else
                Ok
                    (EligibleStudents
                        { r | students = r.students ++ [ s ] }
                    )

        _ ->
            Err [ Error "Can only add students in Draft status" ]


removeStudent : Student -> EligibleStudents -> EligibleStudents
removeStudent s (EligibleStudents r) =
    case r.status of
        Draft ->
            EligibleStudents
                { r
                    | students =
                        List.filter
                            (\existing -> not (sameStudent existing s))
                            r.students
                }

        _ ->
            EligibleStudents r


submit :
    EligibleStudents
    -> Result (List Error) EligibleStudents
submit (EligibleStudents r) =
    case r.status of
        Draft ->
            if List.length r.students < r.config.minStudents then
                Err
                    [ Error
                        ("Need at least "
                            ++ String.fromInt r.config.minStudents
                            ++ " students, have "
                            ++ String.fromInt (List.length r.students)
                        )
                    ]

            else
                Ok
                    (EligibleStudents { r | status = Submitted })

        _ ->
            Err [ Error "Can only submit from Draft status" ]


lock :
    EligibleStudents
    -> Result (List Error) EligibleStudents
lock (EligibleStudents r) =
    case r.status of
        Submitted ->
            Ok (EligibleStudents { r | status = Locked })

        _ ->
            Err [ Error "Can only lock from Submitted status" ]


team : EligibleStudents -> Team
team (EligibleStudents r) =
    r.team


students : EligibleStudents -> List Student
students (EligibleStudents r) =
    r.students


status : EligibleStudents -> Status
status (EligibleStudents r) =
    r.status


config : EligibleStudents -> Config
config (EligibleStudents r) =
    r.config


statusToString : Status -> String
statusToString s =
    case s of
        Draft ->
            "Draft"

        Submitted ->
            "Submitted"

        Locked ->
            "Locked"



-- INTERNAL


isDuplicate : Student -> List Student -> Bool
isDuplicate s list =
    List.any (sameStudent s) list


sameStudent : Student -> Student -> Bool
sameStudent a b =
    let
        nameA =
            Student.studentName a

        nameB =
            Student.studentName b
    in
    Student.first nameA
        == Student.first nameB
        && Student.last nameA
        == Student.last nameB
