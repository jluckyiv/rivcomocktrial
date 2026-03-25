module Auth exposing (User, onPageLoad, viewCustomPage)

import Auth.Action
import Dict
import Route exposing (Route)
import Route.Path
import Shared
import Shared.Model exposing (CoachAuth(..))
import View exposing (View)


type alias User =
    { token : String
    , role : Role
    }


type Role
    = Admin
    | Coach Shared.Model.CoachUser


onPageLoad :
    Shared.Model
    -> Route ()
    -> Auth.Action.Action User
onPageLoad shared route =
    if isTeamRoute route.path then
        case shared.coachAuth of
            LoggedIn credentials ->
                Auth.Action.loadPageWithUser
                    { token = credentials.token
                    , role = Coach credentials.user
                    }

            _ ->
                Auth.Action.pushRoute
                    { path = Route.Path.Team_Login
                    , query = Dict.empty
                    , hash = Nothing
                    }

    else
        case shared.adminToken of
            Just token ->
                Auth.Action.loadPageWithUser
                    { token = token
                    , role = Admin
                    }

            Nothing ->
                Auth.Action.pushRoute
                    { path = Route.Path.Admin_Login
                    , query = Dict.empty
                    , hash = Nothing
                    }


isTeamRoute : Route.Path.Path -> Bool
isTeamRoute path =
    case path of
        Route.Path.Team_EligibleStudents ->
            True

        _ ->
            False


viewCustomPage :
    Shared.Model
    -> Route ()
    -> View Never
viewCustomPage shared route =
    View.fromString "Loading..."
