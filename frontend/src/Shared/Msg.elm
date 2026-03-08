module Shared.Msg exposing (Msg(..))

import Shared.Model exposing (CoachUser)


type Msg
    = AdminLoggedIn String
    | AdminLoggedOut
    | CoachLoggedIn { token : String, user : CoachUser }
    | CoachLoggedOut
