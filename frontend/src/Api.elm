module Api exposing
    ( adminLogin
    , listTournaments, createTournament, updateTournament, deleteTournament
    , listSchools, createSchool, updateSchool, deleteSchool
    , listTeams, createTeam, updateTeam, deleteTeam
    , listStudents, createStudent, updateStudent, deleteStudent
    , listCourtrooms, createCourtroom, updateCourtroom, deleteCourtroom
    , listRounds, createRound, updateRound, deleteRound
    , listTrials, listTrialsByRound, createTrial, updateTrial, deleteTrial
    , Tournament, School, Team, Student, Courtroom, Round, Trial
    , ListResponse
    )

import Http
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


type alias ListResponse a =
    { items : List a
    , page : Int
    , perPage : Int
    , totalItems : Int
    , totalPages : Int
    }



-- DECODERS


tournamentDecoder : Decoder Tournament
tournamentDecoder =
    Decode.map8 Tournament
        (Decode.field "id" Decode.string)
        (Decode.field "name" Decode.string)
        (Decode.field "year" Decode.int)
        (Decode.field "num_preliminary_rounds" Decode.int)
        (Decode.field "num_elimination_rounds" Decode.int)
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
        (fieldWithDefault "type" Decode.string "preliminary")
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


listResponseDecoder : Decoder a -> Decoder (ListResponse a)
listResponseDecoder itemDecoder =
    Decode.map5 ListResponse
        (Decode.field "items" (Decode.list itemDecoder))
        (Decode.field "page" Decode.int)
        (Decode.field "perPage" Decode.int)
        (Decode.field "totalItems" Decode.int)
        (Decode.field "totalPages" Decode.int)


fieldWithDefault : String -> Decoder a -> a -> Decoder a
fieldWithDefault name dec default =
    Decode.oneOf
        [ Decode.field name dec
        , Decode.succeed default
        ]



-- ENCODERS


encodeTournament : { name : String, year : Int, numPreliminaryRounds : Int, numEliminationRounds : Int, status : String } -> Encode.Value
encodeTournament t =
    Encode.object
        [ ( "name", Encode.string t.name )
        , ( "year", Encode.int t.year )
        , ( "num_preliminary_rounds", Encode.int t.numPreliminaryRounds )
        , ( "num_elimination_rounds", Encode.int t.numEliminationRounds )
        , ( "status", Encode.string t.status )
        ]


encodeSchool : { name : String, district : String } -> Encode.Value
encodeSchool s =
    Encode.object
        [ ( "name", Encode.string s.name )
        , ( "district", Encode.string s.district )
        ]


encodeTeam : { tournament : String, school : String, teamNumber : Int, name : String } -> Encode.Value
encodeTeam t =
    Encode.object
        [ ( "tournament", Encode.string t.tournament )
        , ( "school", Encode.string t.school )
        , ( "team_number", Encode.int t.teamNumber )
        , ( "name", Encode.string t.name )
        ]


encodeStudent : { name : String, school : String } -> Encode.Value
encodeStudent s =
    Encode.object
        [ ( "name", Encode.string s.name )
        , ( "school", Encode.string s.school )
        ]


encodeCourtroom : { name : String, location : String } -> Encode.Value
encodeCourtroom c =
    Encode.object
        [ ( "name", Encode.string c.name )
        , ( "location", Encode.string c.location )
        ]



encodeRound : { number : Int, date : String, roundType : String, published : Bool, tournament : String } -> Encode.Value
encodeRound r =
    Encode.object
        [ ( "number", Encode.int r.number )
        , ( "date", Encode.string r.date )
        , ( "type", Encode.string r.roundType )
        , ( "published", Encode.bool r.published )
        , ( "tournament", Encode.string r.tournament )
        ]


encodeTrial : { round : String, prosecutionTeam : String, defenseTeam : String, courtroom : String } -> Encode.Value
encodeTrial t =
    Encode.object
        [ ( "round", Encode.string t.round )
        , ( "prosecution_team", Encode.string t.prosecutionTeam )
        , ( "defense_team", Encode.string t.defenseTeam )
        , ( "courtroom", Encode.string t.courtroom )
        ]



-- AUTH


adminLogin : { email : String, password : String } -> (Result Http.Error String -> msg) -> Cmd msg
adminLogin credentials toMsg =
    Http.post
        { url = "/api/collections/_superusers/auth-with-password"
        , body =
            Http.jsonBody
                (Encode.object
                    [ ( "identity", Encode.string credentials.email )
                    , ( "password", Encode.string credentials.password )
                    ]
                )
        , expect = Http.expectJson toMsg (Decode.field "token" Decode.string)
        }



-- CRUD HELPERS


authHeader : String -> Http.Header
authHeader token =
    Http.header "Authorization" token


listRecords : String -> String -> Decoder a -> (Result Http.Error (ListResponse a) -> msg) -> Cmd msg
listRecords token collection itemDecoder toMsg =
    Http.request
        { method = "GET"
        , headers = [ authHeader token ]
        , url = "/api/collections/" ++ collection ++ "/records?perPage=200"
        , body = Http.emptyBody
        , expect = Http.expectJson toMsg (listResponseDecoder itemDecoder)
        , timeout = Nothing
        , tracker = Nothing
        }


listRecordsFiltered : String -> String -> String -> Decoder a -> (Result Http.Error (ListResponse a) -> msg) -> Cmd msg
listRecordsFiltered token collection filter itemDecoder toMsg =
    Http.request
        { method = "GET"
        , headers = [ authHeader token ]
        , url = "/api/collections/" ++ collection ++ "/records?perPage=200&filter=" ++ filter
        , body = Http.emptyBody
        , expect = Http.expectJson toMsg (listResponseDecoder itemDecoder)
        , timeout = Nothing
        , tracker = Nothing
        }


createRecord : String -> String -> Encode.Value -> Decoder a -> (Result Http.Error a -> msg) -> Cmd msg
createRecord token collection body itemDecoder toMsg =
    Http.request
        { method = "POST"
        , headers = [ authHeader token ]
        , url = "/api/collections/" ++ collection ++ "/records"
        , body = Http.jsonBody body
        , expect = Http.expectJson toMsg itemDecoder
        , timeout = Nothing
        , tracker = Nothing
        }


updateRecord : String -> String -> String -> Encode.Value -> Decoder a -> (Result Http.Error a -> msg) -> Cmd msg
updateRecord token collection id body itemDecoder toMsg =
    Http.request
        { method = "PATCH"
        , headers = [ authHeader token ]
        , url = "/api/collections/" ++ collection ++ "/records/" ++ id
        , body = Http.jsonBody body
        , expect = Http.expectJson toMsg itemDecoder
        , timeout = Nothing
        , tracker = Nothing
        }


deleteRecord : String -> String -> String -> (Result Http.Error () -> msg) -> Cmd msg
deleteRecord token collection id toMsg =
    Http.request
        { method = "DELETE"
        , headers = [ authHeader token ]
        , url = "/api/collections/" ++ collection ++ "/records/" ++ id
        , body = Http.emptyBody
        , expect = Http.expectWhatever toMsg
        , timeout = Nothing
        , tracker = Nothing
        }



-- TOURNAMENTS


listTournaments : String -> (Result Http.Error (ListResponse Tournament) -> msg) -> Cmd msg
listTournaments token =
    listRecords token "tournaments" tournamentDecoder


createTournament : String -> { name : String, year : Int, numPreliminaryRounds : Int, numEliminationRounds : Int, status : String } -> (Result Http.Error Tournament -> msg) -> Cmd msg
createTournament token data =
    createRecord token "tournaments" (encodeTournament data) tournamentDecoder


updateTournament : String -> String -> { name : String, year : Int, numPreliminaryRounds : Int, numEliminationRounds : Int, status : String } -> (Result Http.Error Tournament -> msg) -> Cmd msg
updateTournament token id data =
    updateRecord token "tournaments" id (encodeTournament data) tournamentDecoder


deleteTournament : String -> String -> (Result Http.Error () -> msg) -> Cmd msg
deleteTournament token id =
    deleteRecord token "tournaments" id



-- SCHOOLS


listSchools : String -> (Result Http.Error (ListResponse School) -> msg) -> Cmd msg
listSchools token =
    listRecords token "schools" schoolDecoder


createSchool : String -> { name : String, district : String } -> (Result Http.Error School -> msg) -> Cmd msg
createSchool token data =
    createRecord token "schools" (encodeSchool data) schoolDecoder


updateSchool : String -> String -> { name : String, district : String } -> (Result Http.Error School -> msg) -> Cmd msg
updateSchool token id data =
    updateRecord token "schools" id (encodeSchool data) schoolDecoder


deleteSchool : String -> String -> (Result Http.Error () -> msg) -> Cmd msg
deleteSchool token id =
    deleteRecord token "schools" id



-- TEAMS


listTeams : String -> (Result Http.Error (ListResponse Team) -> msg) -> Cmd msg
listTeams token =
    listRecords token "teams" teamDecoder


createTeam : String -> { tournament : String, school : String, teamNumber : Int, name : String } -> (Result Http.Error Team -> msg) -> Cmd msg
createTeam token data =
    createRecord token "teams" (encodeTeam data) teamDecoder


updateTeam : String -> String -> { tournament : String, school : String, teamNumber : Int, name : String } -> (Result Http.Error Team -> msg) -> Cmd msg
updateTeam token id data =
    updateRecord token "teams" id (encodeTeam data) teamDecoder


deleteTeam : String -> String -> (Result Http.Error () -> msg) -> Cmd msg
deleteTeam token id =
    deleteRecord token "teams" id



-- STUDENTS


listStudents : String -> (Result Http.Error (ListResponse Student) -> msg) -> Cmd msg
listStudents token =
    listRecords token "students" studentDecoder


createStudent : String -> { name : String, school : String } -> (Result Http.Error Student -> msg) -> Cmd msg
createStudent token data =
    createRecord token "students" (encodeStudent data) studentDecoder


updateStudent : String -> String -> { name : String, school : String } -> (Result Http.Error Student -> msg) -> Cmd msg
updateStudent token id data =
    updateRecord token "students" id (encodeStudent data) studentDecoder


deleteStudent : String -> String -> (Result Http.Error () -> msg) -> Cmd msg
deleteStudent token id =
    deleteRecord token "students" id



-- COURTROOMS


listCourtrooms : String -> (Result Http.Error (ListResponse Courtroom) -> msg) -> Cmd msg
listCourtrooms token =
    listRecords token "courtrooms" courtroomDecoder


createCourtroom : String -> { name : String, location : String } -> (Result Http.Error Courtroom -> msg) -> Cmd msg
createCourtroom token data =
    createRecord token "courtrooms" (encodeCourtroom data) courtroomDecoder


updateCourtroom : String -> String -> { name : String, location : String } -> (Result Http.Error Courtroom -> msg) -> Cmd msg
updateCourtroom token id data =
    updateRecord token "courtrooms" id (encodeCourtroom data) courtroomDecoder


deleteCourtroom : String -> String -> (Result Http.Error () -> msg) -> Cmd msg
deleteCourtroom token id =
    deleteRecord token "courtrooms" id



-- ROUNDS


listRounds : String -> (Result Http.Error (ListResponse Round) -> msg) -> Cmd msg
listRounds token =
    listRecords token "rounds" roundDecoder


createRound : String -> { number : Int, date : String, roundType : String, published : Bool, tournament : String } -> (Result Http.Error Round -> msg) -> Cmd msg
createRound token data =
    createRecord token "rounds" (encodeRound data) roundDecoder


updateRound : String -> String -> { number : Int, date : String, roundType : String, published : Bool, tournament : String } -> (Result Http.Error Round -> msg) -> Cmd msg
updateRound token id data =
    updateRecord token "rounds" id (encodeRound data) roundDecoder


deleteRound : String -> String -> (Result Http.Error () -> msg) -> Cmd msg
deleteRound token id =
    deleteRecord token "rounds" id



-- TRIALS


listTrials : String -> (Result Http.Error (ListResponse Trial) -> msg) -> Cmd msg
listTrials token =
    listRecords token "trials" trialDecoder


listTrialsByRound : String -> String -> (Result Http.Error (ListResponse Trial) -> msg) -> Cmd msg
listTrialsByRound token roundId =
    listRecordsFiltered token "trials" ("round='" ++ roundId ++ "'") trialDecoder


createTrial : String -> { round : String, prosecutionTeam : String, defenseTeam : String, courtroom : String } -> (Result Http.Error Trial -> msg) -> Cmd msg
createTrial token data =
    createRecord token "trials" (encodeTrial data) trialDecoder


updateTrial : String -> String -> { round : String, prosecutionTeam : String, defenseTeam : String, courtroom : String } -> (Result Http.Error Trial -> msg) -> Cmd msg
updateTrial token id data =
    updateRecord token "trials" id (encodeTrial data) trialDecoder


deleteTrial : String -> String -> (Result Http.Error () -> msg) -> Cmd msg
deleteTrial token id =
    deleteRecord token "trials" id
