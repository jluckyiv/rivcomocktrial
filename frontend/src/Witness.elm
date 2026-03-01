module Witness exposing (Witness, fromString, toString)


type Witness
    = Witness String


fromString : String -> Witness
fromString =
    Witness


toString : Witness -> String
toString (Witness name) =
    name
