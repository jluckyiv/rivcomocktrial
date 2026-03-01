module District exposing (District, Name(..))


type Name
    = Name String


type alias District =
    { name : Name }
