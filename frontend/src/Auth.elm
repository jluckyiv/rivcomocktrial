module Auth exposing (User, onPageLoad, viewCustomPage)

import Auth.Action
import Dict
import Route exposing (Route)
import Route.Path
import Shared
import View exposing (View)


type alias User =
    { token : String
    }


onPageLoad : Shared.Model -> Route () -> Auth.Action.Action User
onPageLoad shared route =
    case shared.adminToken of
        Just token ->
            Auth.Action.loadPageWithUser { token = token }

        Nothing ->
            Auth.Action.pushRoute
                { path = Route.Path.Admin_Login
                , query = Dict.empty
                , hash = Nothing
                }


viewCustomPage : Shared.Model -> Route () -> View Never
viewCustomPage shared route =
    View.fromString "Loading..."
