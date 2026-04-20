module Shared.Msg exposing (Msg(..))

import Route.Path
import Shared.Model exposing (CoachUser)


type Msg
    = AdminLoggedIn
        { token : String
        , redirect : Maybe Route.Path.Path
        }
    | AdminLoggedOut
    | CoachLoggedIn
        { token : String
        , user : CoachUser
        , redirect : Maybe Route.Path.Path
        }
    | CoachLoggedOut
