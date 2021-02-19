module HtmlToElm.HtmlToElm exposing (..)


--------------------------------------------------------------------------------
-- EXTERNAL DEPENDENCIES
--------------------------------------------------------------------------------
import Dict exposing (Dict)
import String
import Maybe exposing (Maybe)
import Regex


--------------------------------------------------------------------------------
-- INTERNAL DEPENDENCIES
--------------------------------------------------------------------------------

import HtmlParser.HtmlParser exposing
    ( parseHtml
    , Node(..)
    )
import HtmlToElm.ElmHtmlWhitelists exposing (..)


--------------------------------------------------------------------------------
-- TYPES
--------------------------------------------------------------------------------

type IndentTree = IndentTreeLeaf String | IndentTrees (List IndentTree)

type alias IndentFunction = Int -> Int -> String   ->   String


--------------------------------------------------------------------------------
-- MAIN
--------------------------------------------------------------------------------

renderAttribute : (String, String) -> String
renderAttribute (key, value) =
    if
        List.member key implementedAttributeFunctions

    then
        "_" ++ key ++ " " ++ "\"" ++ value ++ "\""
    else
        if
            List.member key reservedWords
        then
            "_" ++ key ++ "_ " ++ "\"" ++ value ++ "\""
        else
            "attribute \"" ++ key ++ "\""  ++ " \"" ++ value ++ "\""
-- TODO: look this app in the attributes whitelist


indent : IndentFunction
indent spacesPerIndent indentLevel s =
    let
        spaces = spacesPerIndent * indentLevel
        listOfSpaces = List.repeat spaces " "
    in
        (String.join "" listOfSpaces) ++ s


renderAttributes : Dict String String   ->   String
renderAttributes attributes =
    let
        attributesList = Dict.toList attributes
        attributeListString = List.map renderAttribute attributesList
        innards = String.join "; " attributeListString
    in
        case innards of
            "" -> "[]"
            _ -> "[ " ++ innards ++ " ]"




renderTextNode : Node -> String
renderTextNode node =
    case node of
        Text text ->
            let
                text_ = text |> removeNewlines |> escapeDoubleQuotes

            in
                "str \"" ++ text_ ++ "\""
        _ ->
            Debug.todo("")


renderTagFunctionHead : String -> String
renderTagFunctionHead tagName =
    if
        List.member tagName implementedTagFunctions
    then
        tagName
    else
        if
            List.member tagName reservedWords
        then
            tagName ++ "_"
        else
            "node \""  ++ tagName ++ "\""

renderVerticalChild : Node -> IndentTree
renderVerticalChild node =
    case node of
        Element {tagName, attributes, children} ->
            let
                firstLine =
                    (renderTagFunctionHead tagName) ++ " " ++ (renderAttributes attributes)
                childrenLines =
                    case children of
                        [] ->
                            case tagName of
                                "br" -> []
                                "img" -> []
                                _ -> [IndentTreeLeaf "[]"]
                        _ -> formatFsharpMultilineList (List.map renderNode children)

            in
                IndentTrees
                    [ IndentTreeLeaf firstLine
                    , IndentTrees childrenLines
                    ]
        Text s ->
            IndentTreeLeaf <| renderTextNode node


verticallyRenderChildren : List Node -> IndentTree
verticallyRenderChildren nodes =
    IndentTrees (List.map renderVerticalChild nodes)


renderNode : Node -> IndentTree
renderNode node =
    renderVerticalChild node


indentTreeStrings : Int -> IndentTree   ->   IndentTree
indentTreeStrings spacesPerIndent originalTree =
    let
        indentTreeStrings_ depth currTree =
            let indentLevel = depth // 2  -- we only want to increase the indent every second second level we go down the tree
            in
            case currTree of
                IndentTreeLeaf s ->
                    IndentTreeLeaf (indent spacesPerIndent indentLevel s)
                IndentTrees trees ->
                    IndentTrees (List.map (indentTreeStrings_ (depth + 1)) trees)
    in
        indentTreeStrings_ 0 originalTree


flattenIndentTree : IndentTree -> List String
flattenIndentTree indentTree =
    let
        flattenIndentTree_ : IndentTree -> List String   ->   List String
        flattenIndentTree_ indentTree_ acc =
            (flattenIndentTree indentTree_) ++ acc
    in
        case indentTree of
            IndentTreeLeaf s -> [s]
            IndentTrees trees ->
                List.foldr flattenIndentTree_ [] trees


htmlNodeToElm : Int -> Node   ->   String
htmlNodeToElm spacesPerIndent node =
    String.join "\n"
        <| flattenIndentTree
        <| indentTreeStrings spacesPerIndent
        <| renderNode node


removeNewlines : String -> String
removeNewlines s =
    Regex.replace (Regex.fromString "\n" |> Maybe.withDefault Regex.never) (\_ -> "") s


escapeDoubleQuotes : String -> String
escapeDoubleQuotes s =
    Regex.replace (Regex.fromString "\"" |> Maybe.withDefault Regex.never) (\_ -> "\\\"") s

formatFsharpMultilineList : List IndentTree -> List IndentTree
formatFsharpMultilineList indentTrees =
    -- 1. prepend "[ " to first item
    -- 2. prepend ", " to tail items
    -- 3 append a line with "]"
    let
        transformHeadLine : IndentTree -> IndentTree
        transformHeadLine indentTree_ =
            case indentTree_ of
                IndentTreeLeaf s ->
                    IndentTreeLeaf <| "[ " ++ s
                IndentTrees (headTree::tailTrees) ->
                    IndentTrees <| [transformHeadLine headTree] ++ tailTrees
                IndentTrees [] ->
                    Debug.todo("")

        transformTailLine : IndentTree -> IndentTree
        transformTailLine indentTree_ =
            case indentTree_ of
                IndentTreeLeaf s ->
                    IndentTreeLeaf <| "  " ++ s
                IndentTrees (headTree::tailTrees) ->
                    IndentTrees <| [transformTailLine headTree] ++ tailTrees
                IndentTrees [] ->
                    Debug.todo("")
    in
        case indentTrees of
            headTree::[] ->
                -- here we need a tree size function, that traverse the tree
                -- if the headTree is a leaf, then run transformHeadline and add "]" to end
                case headTree of
                    IndentTreeLeaf s ->
                        [IndentTreeLeaf <| "[ " ++ s ++ " ]"]
                    _ ->
                        [transformHeadLine headTree]
                            ++ [IndentTreeLeaf "]"]
            headTree::tailTrees ->
                [transformHeadLine headTree]
                    ++ (List.map transformTailLine tailTrees)
                    ++ [IndentTreeLeaf "]"]
            _ ->
                indentTrees


htmlToElm : Int -> String   ->  Maybe String
htmlToElm spacesPerIndent s =
    if
        s == ""
    then
        Just ""
    else
        case parseHtml s of
            Just htmlNode ->
                Just (htmlNodeToElm spacesPerIndent <| htmlNode)
            Nothing ->
                Nothing



--------------------------------------------------------------------------------
-- TESTS
--------------------------------------------------------------------------------


-- testAttributes = Dict.fromList [("id", "1"), ("class", "success")]
-- testLeafElement = Element
--     {
--         tagName = "div",
--         attributes = testAttributes,
--         children = []
--     }

-- testLeafElement2 = Element
--     {
--         tagName = "div",
--         attributes = testAttributes,
--         children = [Text "hello"]
--     }

-- testLeafElements = List.repeat 3 testLeafElement

-- testIndentTree =
--     IndentTrees [
--         IndentTreeLeaf "a",
--         IndentTrees
--             [
--                 IndentTreeLeaf "b"
--             ]
--     ]

-- tests = suite "HtmlToElm.elm"
--     [
--         test "renderAttribute" (
--             assertEqual
--                 "class \"success\""
--                 (renderAttribute ("class", "success"))
--         )
--         ,
--         test "renderAttributes" (
--             assertEqual
--                 "[ class \"success\", id \"1\" ]"
--                 (renderAttributes <| Dict.fromList [("id", "1"), ("class", "success")])
--         )
--         ,
--         test "renderAttributes" (
--             assertEqual
--                 "[]"
--                 (renderAttributes <| Dict.fromList [])
--         )
--         ,
--         test "renderTextNode" (
--             assertEqual
--                 "text \"hello\""
--                 (renderTextNode <| Text "hello")
--         )
--         ,
--         test "indent" (
--             assertEqual
--                 "        hello"
--                 (indent 4 2 "hello")
--         )
--         ,
--         test "indentTree" (
--             assertEqual
--                 (IndentTrees [IndentTreeLeaf "a", IndentTreeLeaf "b"])
--                 (IndentTrees [IndentTreeLeaf "a", IndentTreeLeaf "b"])
--         )
--         ,
--         test "flattenIndentTree" (
--             assertEqual
--                 ["a", "b"]
--                 (flattenIndentTree testIndentTree)
--         )
--         ,
--         test "formatHaskellMultilineList" (
--             assertEqual
--                 [IndentTreeLeaf "[ X", IndentTreeLeaf ", X", IndentTreeLeaf "]"]
--                 (formatHaskellMultilineList [IndentTreeLeaf "X", IndentTreeLeaf "X"])
--         )
--         ,
--         test "just text" (
--             assertEqual
--                 (IndentTreeLeaf "x")
--                 (
--                     case parseHtml "hello" of
--                         Just node -> renderNode node
--                         Nothing -> IndentTreeLeaf "x"
--                 )
--         )
--     ]

-- main =
--     runSuiteHtml tests
