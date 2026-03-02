module UserRole exposing
    ( UserRole(..)
    , all
    , fromString
    , toString
    )

import Error exposing (Error(..))


type UserRole
    = SuperUser
    | Admin
    | TeacherCoach
    | AttorneyCoach
    | Scorer
    | Public


all : List UserRole
all =
    [ SuperUser
    , Admin
    , TeacherCoach
    , AttorneyCoach
    , Scorer
    , Public
    ]


toString : UserRole -> String
toString role =
    case role of
        SuperUser ->
            "SuperUser"

        Admin ->
            "Admin"

        TeacherCoach ->
            "TeacherCoach"

        AttorneyCoach ->
            "AttorneyCoach"

        Scorer ->
            "Scorer"

        Public ->
            "Public"


fromString : String -> Result (List Error) UserRole
fromString str =
    case str of
        "SuperUser" ->
            Ok SuperUser

        "Admin" ->
            Ok Admin

        "TeacherCoach" ->
            Ok TeacherCoach

        "AttorneyCoach" ->
            Ok AttorneyCoach

        "Scorer" ->
            Ok Scorer

        "Public" ->
            Ok Public

        _ ->
            Err [ Error ("Unknown user role: " ++ str) ]
