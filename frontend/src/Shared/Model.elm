module Shared.Model exposing (CoachAuth(..), CoachUser, Model)


type alias CoachUser =
    { id : String
    , email : String
    , name : String
    }


type CoachAuth
    = NotLoggedIn
    | LoggedIn { token : String, user : CoachUser }


type alias Model =
    { adminToken : Maybe String
    , coachAuth : CoachAuth
    }
