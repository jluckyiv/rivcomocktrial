port module Effect exposing
    ( Effect
    , none, batch
    , sendCmd, sendMsg
    , sendSharedMsg
    , pushRoute, replaceRoute
    , pushRoutePath, replaceRoutePath
    , loadExternalUrl, back
    , saveAdminToken
    , saveCoachToken
    , saveCoachUser
    , portSend
    , incoming
    , map, toCmd
    )

{-|

@docs Effect

@docs none, batch
@docs sendCmd, sendMsg

@docs pushRoute, replaceRoute
@docs pushRoutePath, replaceRoutePath
@docs loadExternalUrl, back

@docs map, toCmd

-}

import Browser.Navigation
import Dict exposing (Dict)
import Json.Encode
import Route exposing (Route)
import Route.Path
import Shared.Model
import Shared.Msg
import Task
import Url exposing (Url)


type Effect msg
    = -- BASICS
      None
    | Batch (List (Effect msg))
    | SendCmd (Cmd msg)
      -- ROUTING
    | PushUrl String
    | ReplaceUrl String
    | LoadExternalUrl String
    | Back
      -- SHARED
    | SendSharedMsg Shared.Msg.Msg



-- BASICS


{-| Don't send any effect.
-}
none : Effect msg
none =
    None


{-| Send multiple effects at once.
-}
batch : List (Effect msg) -> Effect msg
batch =
    Batch


{-| Send a normal `Cmd msg` as an effect, something like `Http.get` or `Random.generate`.
-}
sendCmd : Cmd msg -> Effect msg
sendCmd =
    SendCmd


{-| Send a message as an effect. Useful when emitting events from UI components.
-}
sendMsg : msg -> Effect msg
sendMsg msg =
    Task.succeed msg
        |> Task.perform identity
        |> SendCmd


{-| Send a shared message as an effect. Useful for cross-page communication
like login/logout.
-}
sendSharedMsg : Shared.Msg.Msg -> Effect msg
sendSharedMsg =
    SendSharedMsg



-- PORTS


port outgoing :
    { tag : String, data : Json.Encode.Value }
    -> Cmd msg


port incoming :
    (Json.Encode.Value -> msg)
    -> Sub msg


{-| Send a tagged message to JS via the outgoing port.
-}
portSend :
    { tag : String, data : Json.Encode.Value }
    -> Effect msg
portSend msg =
    SendCmd (outgoing msg)


{-| Persist or clear the admin token in localStorage.
-}
saveAdminToken : Maybe String -> Effect msg
saveAdminToken token =
    SendCmd
        (outgoing
            { tag = "SaveAdminToken"
            , data =
                case token of
                    Just t ->
                        Json.Encode.string t

                    Nothing ->
                        Json.Encode.null
            }
        )


{-| Persist or clear the coach token in localStorage.
-}
saveCoachToken : Maybe String -> Effect msg
saveCoachToken token =
    SendCmd
        (outgoing
            { tag = "SaveCoachToken"
            , data =
                case token of
                    Just t ->
                        Json.Encode.string t

                    Nothing ->
                        Json.Encode.null
            }
        )


{-| Persist or clear the coach user in localStorage.
-}
saveCoachUser : Maybe Shared.Model.CoachUser -> Effect msg
saveCoachUser maybeUser =
    SendCmd
        (outgoing
            { tag = "SaveCoachUser"
            , data =
                case maybeUser of
                    Just user ->
                        Json.Encode.object
                            [ ( "id"
                              , Json.Encode.string user.id
                              )
                            , ( "email"
                              , Json.Encode.string user.email
                              )
                            , ( "name"
                              , Json.Encode.string user.name
                              )
                            ]

                    Nothing ->
                        Json.Encode.null
            }
        )



-- ROUTING


{-| Set the new route, and make the back button go back to the current route.
-}
pushRoute :
    { path : Route.Path.Path
    , query : Dict String String
    , hash : Maybe String
    }
    -> Effect msg
pushRoute route =
    PushUrl (Route.toString route)


{-| Same as `Effect.pushRoute`, but without `query` or `hash` support
-}
pushRoutePath : Route.Path.Path -> Effect msg
pushRoutePath path =
    PushUrl (Route.Path.toString path)


{-| Set the new route, but replace the previous one, so clicking the back
button **won't** go back to the previous route.
-}
replaceRoute :
    { path : Route.Path.Path
    , query : Dict String String
    , hash : Maybe String
    }
    -> Effect msg
replaceRoute route =
    ReplaceUrl (Route.toString route)


{-| Same as `Effect.replaceRoute`, but without `query` or `hash` support
-}
replaceRoutePath : Route.Path.Path -> Effect msg
replaceRoutePath path =
    ReplaceUrl (Route.Path.toString path)


{-| Redirect users to a new URL, somewhere external to your web application.
-}
loadExternalUrl : String -> Effect msg
loadExternalUrl =
    LoadExternalUrl


{-| Navigate back one page
-}
back : Effect msg
back =
    Back



-- INTERNALS


{-| Elm Land depends on this function to connect pages and layouts
together into the overall app.
-}
map : (msg1 -> msg2) -> Effect msg1 -> Effect msg2
map fn effect =
    case effect of
        None ->
            None

        Batch list ->
            Batch (List.map (map fn) list)

        SendCmd cmd ->
            SendCmd (Cmd.map fn cmd)

        PushUrl url ->
            PushUrl url

        ReplaceUrl url ->
            ReplaceUrl url

        Back ->
            Back

        LoadExternalUrl url ->
            LoadExternalUrl url

        SendSharedMsg sharedMsg ->
            SendSharedMsg sharedMsg


{-| Elm Land depends on this function to perform your effects.
-}
toCmd :
    { key : Browser.Navigation.Key
    , url : Url
    , shared : Shared.Model.Model
    , fromSharedMsg : Shared.Msg.Msg -> msg
    , batch : List msg -> msg
    , toCmd : msg -> Cmd msg
    }
    -> Effect msg
    -> Cmd msg
toCmd options effect =
    case effect of
        None ->
            Cmd.none

        Batch list ->
            Cmd.batch (List.map (toCmd options) list)

        SendCmd cmd ->
            cmd

        PushUrl url ->
            Browser.Navigation.pushUrl options.key url

        ReplaceUrl url ->
            Browser.Navigation.replaceUrl options.key url

        Back ->
            Browser.Navigation.back options.key 1

        LoadExternalUrl url ->
            Browser.Navigation.load url

        SendSharedMsg sharedMsg ->
            Task.succeed sharedMsg
                |> Task.perform options.fromSharedMsg
