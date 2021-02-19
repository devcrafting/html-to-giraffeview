module Parser.ParserHelpers exposing (..)

--------------------------------------------------------------------------------
-- EXTERNAL DEPENDENCIES
--------------------------------------------------------------------------------

-- import Legacy.ElmTest exposing (..)
import List

--------------------------------------------------------------------------------
-- INTERNAL DEPENDENCIES
--------------------------------------------------------------------------------

import Parser.Tokenizer exposing (..)
import Parser.Parser exposing (
    ParseFunction,
    ParseResult(..),
    AstNode(..),
    AstNodeValue(..),
    createParseTokenIgnoreFunction,
    createParseTokenKeepFunction,
    optional
    )


--------------------------------------------------------------------------------
-- MAIN
--------------------------------------------------------------------------------

parseLeftAngleBracketIgnore = createParseTokenIgnoreFunction LeftAngleBracket
parseRightAngleBracketIgnore = createParseTokenIgnoreFunction RightAngleBracket
parseForwardSlashIgnore = createParseTokenIgnoreFunction ForwardSlash
parseEqualsSignIgnore = createParseTokenIgnoreFunction EqualsSign
parseWhitespaceIgnore = createParseTokenIgnoreFunction Whitespace
parseDoubleQuotationMarkIgnore = createParseTokenIgnoreFunction DoubleQuotationMark
parseSingleQuotationMarkIgnore = createParseTokenIgnoreFunction SingleQuotationMark
parseExclamationMarkIgnore = createParseTokenIgnoreFunction ExclamationMark
parseDashIgnore = createParseTokenIgnoreFunction Dash

parseLeftAngleBracketKeep = createParseTokenKeepFunction LeftAngleBracket
parseRightAngleBracketKeep = createParseTokenKeepFunction RightAngleBracket
parseForwardSlashKeep = createParseTokenKeepFunction ForwardSlash
parseEqualsSignKeep = createParseTokenKeepFunction EqualsSign
parseWhitespaceKeep = createParseTokenKeepFunction Whitespace
parseDoubleQuotationMarkKeep = createParseTokenKeepFunction DoubleQuotationMark
parseSingleQuotationMarkKeep = createParseTokenKeepFunction SingleQuotationMark
parseExclamationMarkKeep = createParseTokenKeepFunction ExclamationMark
parseDashKeep = createParseTokenKeepFunction Dash
parseWordKeep = createParseTokenKeepFunction Word

parseIgnoreOptionalWhitespace = optional <| parseWhitespaceIgnore

unpackStringFromNode : AstNode -> String
unpackStringFromNode astNode =
    case astNode of
        UnlabelledAstNode astValue ->
            case astValue of
                AstLeaf s -> s
                AstChildren _ ->
                    List.foldr (++) "" <| unpackStringsFromNode astNode
        _ ->
            Debug.todo("")


unpackListFromNode : AstNode -> List AstNode
unpackListFromNode astNode =
    case astNode of
        UnlabelledAstNode value ->
            case value of
                AstChildren xs -> xs
                AstLeaf x -> [UnlabelledAstNode value]

        LabelledAstNode {label, value} ->
            case value of
                AstChildren xs -> xs
                AstLeaf x -> [UnlabelledAstNode value]

unpackStringsFromNode : AstNode -> List String
unpackStringsFromNode astNode =
    let
        nodes = unpackListFromNode astNode
        strings = List.map unpackStringFromNode nodes
    in
        strings

concatLeafs : AstNode -> String
concatLeafs astNode =
    let
        strings = unpackStringsFromNode astNode
    in
        List.foldr (++) "" strings

unsafeHead xs =
    case xs of
        x::_ ->
            x
        _ ->
            Debug.todo("unsafe Head returned crash!")

unsafeTail xs =
    case xs of
        _::ys ->
            ys
        _ ->
            Debug.todo("")

listToPair : List a -> (a, a)
listToPair xs =
    (unsafeHead xs, unsafeHead <| unsafeTail xs)

listTo3Tuple : List a -> (a, a, a)
listTo3Tuple children =
    (
        unsafeHead children,
        unsafeHead <| unsafeTail children,
        unsafeHead <| unsafeTail <| unsafeTail children
    )

getLabel : AstNode -> String
getLabel astNode =
    case astNode of
        LabelledAstNode {label, value} ->
            label
        _ ->
            Debug.todo("")


{-| Assumes all nodes are Unlabelled. Will throw runtime Debug.todo if not. -}
flattenAstNode : AstNode -> AstNode
flattenAstNode astNode =

    let
        flatten_ astNode_ =
            case astNode_ of
                UnlabelledAstNode astValue ->
                    case astValue of
                        AstLeaf _ ->
                            [astNode]
                        AstChildren leafNodes_ ->
                            List.foldl flatten__ [] leafNodes_
                _ ->
                    Debug.todo("flatten does not support Labelled nodes yet!")

        flatten__ : AstNode -> List AstNode -> List AstNode
        flatten__ astNode_ acc =
            acc ++ (flatten_ astNode_)

    in
        case astNode of
            UnlabelledAstNode astValue ->
                case astValue of
                    AstLeaf leaf ->
                        astNode
                    AstChildren leafNodes_ ->
                        UnlabelledAstNode <| AstChildren (flatten_ astNode)
            _ ->
                Debug.todo("flatten does not support Labelled nodes yet!")


flatten    :    ParseFunction -> ParseFunction
flatten parseFunction =
    let
        f tokens =
            case parseFunction tokens of
                (ParseMatchesReturnsResult result, remainderTokens) ->
                    ( ParseMatchesReturnsResult (flattenAstNode result)
                    , remainderTokens
                    )
                result -> result
    in
        f

--------------------------------------------------------------------------------
-- TESTS
--------------------------------------------------------------------------------


leafNodes : List AstNode
leafNodes =
    [ UnlabelledAstNode <| AstLeaf "hello"
    , UnlabelledAstNode <| AstLeaf " "
    , UnlabelledAstNode <| AstLeaf "world"
    ]

unlabelledLeafs : AstNode
unlabelledLeafs =
    UnlabelledAstNode <| AstChildren leafNodes


-- tests = suite "ParserHelpers.elm"
--     [ test "unpackStringFromNode"
--         ( assertEqual
--             "hello"
--             (unpackStringFromNode (UnlabelledAstNode (AstLeaf "hello")))
--         )
--     , test "unpackStringFromNode (nested)"
--         ( assertEqual
--             "hello world"
--             (concatLeafs unlabelledLeafs)
--         )
--     , test "listToPair"
--         ( assertEqual
--             (1, 2)
--             (listToPair [1, 2])
--         )
--     , test "listTo3Tuple"
--         ( assertEqual
--             (1, 2, 3)
--             (listTo3Tuple [1, 2, 3])
--         )
--     , test "getLabel"
--         ( assertEqual
--             "SOMETHING"
--             (getLabel
--                 (LabelledAstNode
--                     { label = "SOMETHING"
--                     , value = AstLeaf "hello"
--                     }
--                 )
--             )
--         )
--     , test "flattenAstNode (identity for leaf)"
--         ( assertEqual
--             ( UnlabelledAstNode <| AstLeaf "hello" )
--             ( flattenAstNode ( UnlabelledAstNode <| AstLeaf "hello" ) )
--         )
--     , test "flattenAstNode (identity for AstChildren)"
--         ( assertEqual
--             ( UnlabelledAstNode <| AstChildren
--                 [ UnlabelledAstNode <| AstLeaf "hello" ]
--             )
--             ( flattenAstNode
--                 ( UnlabelledAstNode <| AstChildren
--                     [ UnlabelledAstNode <| AstLeaf "hello" ]
--                 )
--             )
--         )
--     , test "flattenAstNode (identity for multiple AstChildren)"
--         ( assertEqual
--             ( UnlabelledAstNode <| AstChildren
--                 [  UnlabelledAstNode <| AstLeaf "one"
--                 ,  UnlabelledAstNode <| AstLeaf "two"
--                 ]
--             )
--             ( flattenAstNode
--                 ( UnlabelledAstNode <| AstChildren
--                     [  UnlabelledAstNode <| AstLeaf "one"
--                     ,  UnlabelledAstNode <| AstLeaf "two"
--                     ]
--                 )
--             )
--         )
--     , test "flattenAstNode (nested)"
--         ( assertEqual
--             ( UnlabelledAstNode <| AstChildren
--                 [  UnlabelledAstNode <| AstLeaf "one"
--                 ,  UnlabelledAstNode <| AstLeaf "two"
--                 ,  UnlabelledAstNode <| AstLeaf "three"
--                 ]
--             )
--             ( flattenAstNode
--                 ( UnlabelledAstNode <| AstChildren
--                     [  UnlabelledAstNode <| AstChildren
--                         [  UnlabelledAstNode <| AstLeaf "one" ]
--                     ,  UnlabelledAstNode <| AstChildren
--                         [  UnlabelledAstNode <| AstLeaf "two"
--                         ,  UnlabelledAstNode <| AstChildren
--                             [ UnlabelledAstNode <| AstLeaf "three" ]
--                         ]
--                     ]
--                 )
--             )
--         )
--     ]


-- main =
--     runSuiteHtml tests
