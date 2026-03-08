module Api exposing
    ( Tournament, School, Team, Student
    , Courtroom, Round, Trial, CoachUser
    , tournamentDecoder, schoolDecoder, teamDecoder
    , studentDecoder, courtroomDecoder, roundDecoder
    , trialDecoder, coachUserDecoder
    , encodeTournament, encodeSchool, encodeTeam
    , encodeStudent, encodeCourtroom, encodeRound
    , encodeTrial, encodeCoachRegistration
    )

{-| PocketBase record types, decoders, and encoders.

All API operations go through the Pb module (port-based
PB JS SDK client). This module only defines data shapes.

-}

import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode



-- TYPES


type alias Tournament =
    { id : String
    , name : String
    , year : Int
    , numPreliminaryRounds : Int
    , numEliminationRounds : Int
    , status : String
    , created : String
    , updated : String
    }


type alias School =
    { id : String
    , name : String
    , district : String
    , created : String
    , updated : String
    }


type alias Team =
    { id : String
    , tournament : String
    , school : String
    , teamNumber : Int
    , name : String
    , created : String
    , updated : String
    }


type alias Student =
    { id : String
    , name : String
    , school : String
    , created : String
    , updated : String
    }


type alias Courtroom =
    { id : String
    , name : String
    , location : String
    , created : String
    , updated : String
    }


type alias Round =
    { id : String
    , number : Int
    , date : String
    , roundType : String
    , published : Bool
    , tournament : String
    , created : String
    , updated : String
    }


type alias Trial =
    { id : String
    , round : String
    , prosecutionTeam : String
    , defenseTeam : String
    , courtroom : String
    , created : String
    , updated : String
    }


type alias CoachUser =
    { id : String
    , email : String
    , name : String
    , school : String
    , teamName : String
    , status : String
    , role : String
    , created : String
    , updated : String
    }



-- DECODERS


tournamentDecoder : Decoder Tournament
tournamentDecoder =
    Decode.map8 Tournament
        (Decode.field "id" Decode.string)
        (Decode.field "name" Decode.string)
        (Decode.field "year" Decode.int)
        (Decode.field "num_preliminary_rounds"
            Decode.int
        )
        (Decode.field "num_elimination_rounds"
            Decode.int
        )
        (Decode.field "status" Decode.string)
        (Decode.field "created" Decode.string)
        (Decode.field "updated" Decode.string)


schoolDecoder : Decoder School
schoolDecoder =
    Decode.map5 School
        (Decode.field "id" Decode.string)
        (Decode.field "name" Decode.string)
        (fieldWithDefault "district" Decode.string "")
        (Decode.field "created" Decode.string)
        (Decode.field "updated" Decode.string)


teamDecoder : Decoder Team
teamDecoder =
    Decode.map7 Team
        (Decode.field "id" Decode.string)
        (Decode.field "tournament" Decode.string)
        (Decode.field "school" Decode.string)
        (fieldWithDefault "team_number" Decode.int 0)
        (fieldWithDefault "name" Decode.string "")
        (Decode.field "created" Decode.string)
        (Decode.field "updated" Decode.string)


studentDecoder : Decoder Student
studentDecoder =
    Decode.map5 Student
        (Decode.field "id" Decode.string)
        (Decode.field "name" Decode.string)
        (Decode.field "school" Decode.string)
        (Decode.field "created" Decode.string)
        (Decode.field "updated" Decode.string)


courtroomDecoder : Decoder Courtroom
courtroomDecoder =
    Decode.map5 Courtroom
        (Decode.field "id" Decode.string)
        (Decode.field "name" Decode.string)
        (fieldWithDefault "location" Decode.string "")
        (Decode.field "created" Decode.string)
        (Decode.field "updated" Decode.string)


roundDecoder : Decoder Round
roundDecoder =
    Decode.map8 Round
        (Decode.field "id" Decode.string)
        (fieldWithDefault "number" Decode.int 0)
        (fieldWithDefault "date" Decode.string "")
        (fieldWithDefault "type" Decode.string
            "preliminary"
        )
        (fieldWithDefault "published" Decode.bool False)
        (Decode.field "tournament" Decode.string)
        (Decode.field "created" Decode.string)
        (Decode.field "updated" Decode.string)


trialDecoder : Decoder Trial
trialDecoder =
    Decode.map7 Trial
        (Decode.field "id" Decode.string)
        (Decode.field "round" Decode.string)
        (Decode.field "prosecution_team" Decode.string)
        (Decode.field "defense_team" Decode.string)
        (fieldWithDefault "courtroom" Decode.string "")
        (Decode.field "created" Decode.string)
        (Decode.field "updated" Decode.string)


coachUserDecoder : Decoder CoachUser
coachUserDecoder =
    Decode.succeed CoachUser
        |> andMap (Decode.field "id" Decode.string)
        |> andMap
            (Decode.field "email" Decode.string)
        |> andMap
            (fieldWithDefault "name"
                Decode.string
                ""
            )
        |> andMap
            (fieldWithDefault "school"
                Decode.string
                ""
            )
        |> andMap
            (fieldWithDefault "team_name"
                Decode.string
                ""
            )
        |> andMap
            (fieldWithDefault "status"
                Decode.string
                "pending"
            )
        |> andMap
            (fieldWithDefault "role"
                Decode.string
                ""
            )
        |> andMap
            (Decode.field "created" Decode.string)
        |> andMap
            (Decode.field "updated" Decode.string)



-- ENCODERS


encodeTournament :
    { name : String
    , year : Int
    , numPreliminaryRounds : Int
    , numEliminationRounds : Int
    , status : String
    }
    -> Encode.Value
encodeTournament t =
    Encode.object
        [ ( "name", Encode.string t.name )
        , ( "year", Encode.int t.year )
        , ( "num_preliminary_rounds"
          , Encode.int t.numPreliminaryRounds
          )
        , ( "num_elimination_rounds"
          , Encode.int t.numEliminationRounds
          )
        , ( "status", Encode.string t.status )
        ]


encodeSchool :
    { name : String, district : String }
    -> Encode.Value
encodeSchool s =
    Encode.object
        [ ( "name", Encode.string s.name )
        , ( "district", Encode.string s.district )
        ]


encodeTeam :
    { tournament : String
    , school : String
    , teamNumber : Int
    , name : String
    }
    -> Encode.Value
encodeTeam t =
    Encode.object
        [ ( "tournament", Encode.string t.tournament )
        , ( "school", Encode.string t.school )
        , ( "team_number", Encode.int t.teamNumber )
        , ( "name", Encode.string t.name )
        ]


encodeStudent :
    { name : String, school : String }
    -> Encode.Value
encodeStudent s =
    Encode.object
        [ ( "name", Encode.string s.name )
        , ( "school", Encode.string s.school )
        ]


encodeCourtroom :
    { name : String, location : String }
    -> Encode.Value
encodeCourtroom c =
    Encode.object
        [ ( "name", Encode.string c.name )
        , ( "location", Encode.string c.location )
        ]


encodeRound :
    { number : Int
    , date : String
    , roundType : String
    , published : Bool
    , tournament : String
    }
    -> Encode.Value
encodeRound r =
    Encode.object
        [ ( "number", Encode.int r.number )
        , ( "date", Encode.string r.date )
        , ( "type", Encode.string r.roundType )
        , ( "published", Encode.bool r.published )
        , ( "tournament", Encode.string r.tournament )
        ]


encodeTrial :
    { round : String
    , prosecutionTeam : String
    , defenseTeam : String
    , courtroom : String
    }
    -> Encode.Value
encodeTrial t =
    Encode.object
        [ ( "round", Encode.string t.round )
        , ( "prosecution_team"
          , Encode.string t.prosecutionTeam
          )
        , ( "defense_team"
          , Encode.string t.defenseTeam
          )
        , ( "courtroom", Encode.string t.courtroom )
        ]


encodeCoachRegistration :
    { email : String
    , password : String
    , passwordConfirm : String
    , name : String
    , school : String
    , teamName : String
    }
    -> Encode.Value
encodeCoachRegistration r =
    Encode.object
        [ ( "email", Encode.string r.email )
        , ( "password", Encode.string r.password )
        , ( "passwordConfirm"
          , Encode.string r.passwordConfirm
          )
        , ( "name", Encode.string r.name )
        , ( "school", Encode.string r.school )
        , ( "team_name", Encode.string r.teamName )
        , ( "status", Encode.string "pending" )
        , ( "role", Encode.string "coach" )
        ]



-- HELPERS


fieldWithDefault :
    String
    -> Decoder a
    -> a
    -> Decoder a
fieldWithDefault name dec default =
    Decode.oneOf
        [ Decode.field name dec
        , Decode.succeed default
        ]


andMap : Decoder a -> Decoder (a -> b) -> Decoder b
andMap =
    Decode.map2 (|>)
