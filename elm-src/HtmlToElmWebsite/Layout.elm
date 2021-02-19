module HtmlToElmWebsite.Layout exposing (..)

-- import Window
import Html
import Html.Attributes exposing (style)

topBarHeight = 50
panelHeaderHeight = 30

topBar otherStyles =
    List.concat [
        otherStyles,
        [ style "height" ((String.fromInt topBarHeight) ++ "px")
        , style "line-height" ((String.fromInt topBarHeight) ++ "px")
        , style "padding-left" ((String.fromInt 12) ++ "px")
        , style "font-size" ((String.fromInt 20) ++ "px")
        , style "color" "#293c4b"
        ]
    ]

topBarRight =
    [ ("float", "right")
    ]

mainPanel windowSize =
    let
        width = windowSize.width // 2
        height = windowSize.height - topBarHeight
    in
        [ style "width" ((String.fromInt width) ++ "px")
        , style "height" ((String.fromInt height) ++ "px")
        , style "position" "absolute"
        , style "display" "fixed"
        ]

panelHeader otherAttributes =
    [style "height" ((String.fromInt panelHeaderHeight) ++ "px")] ++ otherAttributes

panelContent windowSize otherAttributes =
    let
        height = windowSize.height - (topBarHeight + (panelHeaderHeight * 2) )
    in
        [style "height" ((String.fromInt height) ++ "px")] ++ otherAttributes


-- leftPanel : Window.Size -> List (Html msg)
leftPanel windowSize otherAttributes =
    mainPanel windowSize ++ [style "left" "0px"] ++ otherAttributes
-- rightPanel : Window.Size -> List (Html msg)
rightPanel windowSize otherAttributes =
    mainPanel windowSize ++ [style "right" "0px"] ++ otherAttributes
