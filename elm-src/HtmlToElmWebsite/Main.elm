port module  HtmlToElmWebsite.Main exposing (..)

import Task

import Dict
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Browser
-- import Debug exposing (..)
import HtmlToElmWebsite.Layout as Layout
import HtmlToElmWebsite.HtmlComponents exposing (githubStarButton)
import HtmlToElmWebsite.HtmlExamples exposing (htmlExamples)
import HtmlToElm.HtmlToElm exposing (htmlToElm)
import Browser.Events
import Browser.Dom exposing (Error(..))
import String

-- type alias StringAddress = Signal.Address String


-- currHtmlMailbox : Signal.Mailbox String
-- currHtmlMailbox =
--   Signal.mailbox ""


topBar : Html Msg
topBar =
    div (Layout.topBar [ class "top-bar" ])
        [ div
            []
            [ p
                [ style "float" "left"]
                [ text "HTML to Elm" ]
            , div
                [ style "float" "right", style "font-size" "14px"]
                [ a
                    [ href "https://github.com/mbylstra/html-to-elm"
                    , style "margin-right" "10px"
                    ]
                    [ img
                        [ src "https://cdn0.iconfinder.com/data/icons/octicons/1024/mark-github-16.png"
                        , style "vertical-align" "text-top"
                        ]
                        []
                    , text " https://github.com/mbylstra/html-to-elm"
                    ]
                , githubStarButton
                    { user="mbylstra"
                    , repo="html-to-elm"
                    , type_="star"
                    , size="small"
                    , style=[ style "vertical-align" "middle", style "margin-top" "-5px" ]
                    }
                ]
            ]
        ]


snippetButton : String -> Html Msg
snippetButton snippetName =
    span
        [class "example-button"
        , onClick (LoadSnippet snippetName)
        ]
        [ text snippetName ]


snippetButtons : List (Html Msg)
snippetButtons =
    List.map (\key -> snippetButton key) (Dict.keys htmlExamples)


leftPanel : Model -> Html Msg
leftPanel model =
    div
        (Layout.leftPanel model.windowSize [ class "left-panel" ])
        [ div
            (Layout.panelHeader [ class "left-panel-heading"])
            [ text "Type or paste HTML here" ]
        , div
            []
            [ textarea
                [
                  -- type_ "string"
                  id "html"
                , placeholder "input"
                , name "points"
                -- , on "input" targetValue (\v -> Signal.message currHtmlMailbox.address v)  -- this should be an action!
                ]
                [ ]
            ]
        , div
            (Layout.panelHeader [ class "left-panel-heading" ])
            ([ text "snippets: " ]  ++  snippetButtons)
        ]


copyButton : Bool -> Html Msg
copyButton visible =
    let
        style_ = if visible then [] else [ style "display" "none" ]
    in
        div
          ([ id "copy-button", class "copy-button" ] ++ style_)
          [ text "copy"]


rightPanel : Model -> Html Msg
rightPanel model =

    let
        hint =
            case model.elmCode of
                Just elmCode ->
                    div [] []
                Nothing ->
                    div [ class "hint" ]
                        [ text """
                            Hint: only one top level element is allowed
                          """
                        ]

    in
        div
            (Layout.rightPanel model.windowSize [ class "right-panel" ])
            [ div
                (Layout.panelHeader [ class "right-panel-heading" ])
                [ text "Elm code appears here (see "
                , a [href "https://github.com/elm-lang/html", target "_blank"] [ text "elm-lang/html"]
                , text ")"
                ]
            , div
                (Layout.panelContent model.windowSize [ class "elm-code" ])
                [ hint
                , pre [id "elm-code", class "elm"] []
                ]
            , div
                (Layout.panelHeader [ class "right-panel-heading" ])
                [ text "indent spaces: "
                , span
                    [ class "example-button"
                    , onClick (SetIndentSpaces 2)
                    ]
                    [text "2"]
                , span
                    [class "example-button"
                    , onClick (SetIndentSpaces 4)
                    ]
                    [text "4"]
                ]
              --, copyButton (if elmCode == "" then True else True)
            , copyButton True
            ]

type Msg =
    LoadSnippet String
    | SetIndentSpaces Int
    | HtmlUpdated String
    | WindowSizeChanged WindowSize
    | ElmDomReady
    | NoOp

type alias WindowSize = {
        width: Int,
        height: Int
    }

-- actionsMailbox : Signal.Mailbox (Maybe Msg)
-- actionsMailbox = Signal.mailbox Nothing


-- actionsAddress : Signal.Address Msg
-- actionsAddress =
--   Signal.forwardTo actionsMailbox.address Just


update : Msg -> Model   ->   (Model, Cmd Msg)
update msg model =
    case Debug.log "msg" msg of
        HtmlUpdated html ->
            let
              elmCode = (htmlToElm model.indentSpaces) html
            in
              ({ model |
                html = html
              , elmCode = elmCode
              }, outgoingElmCode elmCode)
        LoadSnippet snippetName ->
            let
              snippet =
                  case (Dict.get snippetName htmlExamples) of
                      Just snippet_ -> snippet_
                      Nothing -> ""

            in
              ({ model | currentSnippet = snippet }
              , currentSnippet snippet)
        SetIndentSpaces indentSpaces ->
            let
              newModel = { model | indentSpaces = indentSpaces }
            in
              (newModel,
                Task.perform identity (Task.succeed (HtmlUpdated model.html)))
        WindowSizeChanged size ->
            ({ model | windowSize = size }, Cmd.none)
        ElmDomReady ->
          (model,
            elmDomReady "")
        NoOp ->
          (model, Cmd.none)


        -- Nothing ->
        --     Debug.todo "This should never happen."


type alias Model =
    { html : String
    , elmCode: Maybe String
    , indentSpaces : Int
    , currentSnippet : String
    , windowSize : WindowSize
    }


initialModel : Model
initialModel =
    { html = ""
    , elmCode = Just ""
    , indentSpaces = 4
    , currentSnippet = ""
    , windowSize = { width = 1000, height = 20 }
    }


-- actionsModelSignal : Signal Model
-- actionsModelSignal =
--     Signal.foldp updateFunc initialModel actionsMailbox.signal


-- modelSignal : Signal Model
-- modelSignal =
--     let
--         reducer actionsModel htmlCode =
--             let
--                 elmCode = htmlToElm actionsModel.indentSpaces htmlCode
--             in
--                 { actionsModel |
--                   elmCode = elmCode
--                 }
--     in
--         Signal.map2 reducer actionsModelSignal incomingHtmlCodeSignal


-- main : Signal Html
-- main =
--   Signal.map2 (view actionsAddress) modelSignal Window.dimensions


view : Model -> Html Msg
view model =
  div [ ]
    [ topBar
    , div []
        [ leftPanel model
        , rightPanel model
        ]
    ]


-- port incomingHtmlCodeSignal : Signal (String)

-- port outgoingElmCode : Signal (Maybe String)
-- port outgoingElmCode = Signal.map .elmCode modelSignal

-- port windowHeight : Signal Int
-- port windowHeight = Window.height


toInt f = String.fromFloat f |> String.toInt |> Maybe.withDefault 0

main : Program () Model Msg
main =
  Browser.element
    { init = \_ ->
        (initialModel, Cmd.batch [
            Task.perform (\v -> WindowSizeChanged { width = toInt v.viewport.width, height = toInt v.viewport.height }) Browser.Dom.getViewport
            , Task.perform identity (Task.succeed ElmDomReady)])
    , update = update
    , view = view
    , subscriptions = subscriptions
    }

subscriptions : Model -> Sub Msg
subscriptions model =
  Sub.batch [
  -- suggestions Suggest
    incomingHtmlCode HtmlUpdated,
    Browser.Events.onResize (\w h -> WindowSizeChanged { width = w, height = h })
  ]

-- subscriptions model =
--   Window.resizes (\size -> WindowSizeChanged size)




port incomingHtmlCode : (String -> msg) -> Sub msg
-- port suggestions : (List String -> msg) -> Sub msg

port outgoingElmCode : Maybe String -> Cmd msg

port currentSnippet : String -> Cmd msg

port elmDomReady : String -> Cmd msg
