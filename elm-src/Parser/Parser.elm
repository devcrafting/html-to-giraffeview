module Parser.Parser exposing
    ( ParseFunction
    , createParseTokenIgnoreFunction
    , createParseTokenKeepFunction
    , createParseSequenceFunction
    , createOptionallyParseMultipleFunction
    , createParseAtLeastOneFunction
    , createParseAnyFunction
    , ParseResult(..)
    , AstNode(..)
    , AstNodeValue(..)
    , labelled
    , optional
    , ignore
    -- , main
    -- , tests
    )


--------------------------------------------------------------------------------
-- EXTERNAL DEPENDENCIES
--------------------------------------------------------------------------------

-- import Legacy.ElmTest exposing (..)


--------------------------------------------------------------------------------
-- INTERNAL DEPENDENCIES
--------------------------------------------------------------------------------

import Parser.Tokenizer exposing (..)


--------------------------------------------------------------------------------
-- TYPES
--------------------------------------------------------------------------------

type AstNode =
    LabelledAstNode AstNodeRecord | UnlabelledAstNode AstNodeValue

type alias AstNodeRecord =
    { label:String
    , value:AstNodeValue
    }

type AstNodeValue =
    AstLeaf String | AstChildren AstNodes

type alias AstNodes = List AstNode

type alias RemainderTokens = Tokens

type ConsumeTokenResult =
    TokenMatches (String, RemainderTokens) | TokenDoesNotMatch RemainderTokens

type alias ParseValue = String

type ParseResult
    = ParseMatchesReturnsResult AstNode
    | ParseMatchesReturnsNothing
    | ParseDoesNotMatch

type alias ParseResults = List ParseResult

type alias ParseFunction  = Tokens    ->    (ParseResult, RemainderTokens)
type alias ParseFunctions = List ParseFunction


--------------------------------------------------------------------------------
-- MAIN
--------------------------------------------------------------------------------

consumeToken :   TokenType -> Tokens   ->   ConsumeTokenResult
consumeToken expectedTokenType tokens =
    case tokens of
        (tokenType, tokenValue)::tailTokens ->
            if
                tokenType == expectedTokenType
            then
                TokenMatches (tokenValue, tailTokens)
            else
                TokenDoesNotMatch tokens
        [] ->
            TokenDoesNotMatch tokens


createParseTokenIgnoreFunction : TokenType -> ParseFunction
createParseTokenIgnoreFunction tokenType =
    let
        parseTokenIgnore : ParseFunction
        parseTokenIgnore tokens =
            case (consumeToken tokenType tokens) of
                TokenMatches (_, tailTokens) ->
                    (ParseMatchesReturnsNothing, tailTokens)
                TokenDoesNotMatch tailTokens ->
                    (ParseDoesNotMatch, tokens)
    in
        parseTokenIgnore


createParseTokenKeepFunction : TokenType -> ParseFunction
createParseTokenKeepFunction tokenType =
    let
        parseTokenKeep : ParseFunction
        parseTokenKeep tokens =
            case (consumeToken tokenType tokens) of
                TokenMatches (tokenValue, tailTokens) ->
                    ( ParseMatchesReturnsResult <| UnlabelledAstNode <| AstLeaf tokenValue
                    , tailTokens
                    )
                TokenDoesNotMatch tailTokens ->
                    (ParseDoesNotMatch, tokens)
    in
        parseTokenKeep


-- give an UnlabelledNode a value, or override the label of a LabelledNode
labelled :   String -> ParseFunction   ->   ParseFunction
labelled label parseFunction =
    let
        parseFunction_ : ParseFunction
        parseFunction_ tokens =
            let
                result = parseFunction tokens
            in
                case result of
                    (ParseMatchesReturnsResult (UnlabelledAstNode nodeValue), remainderTokens) ->
                        ( ParseMatchesReturnsResult (LabelledAstNode { label=label, value=nodeValue } )
                        , remainderTokens
                        )

                    _ -> result  -- no need to change anything if empty result returned
    in
        parseFunction_

ignore    :    ParseFunction -> ParseFunction
ignore parseFunction =
    let
        f tokens =
            case parseFunction tokens of
                (ParseMatchesReturnsResult _, remainderTokens) ->
                    (ParseMatchesReturnsNothing, remainderTokens)
                result -> result
    in
        f

optional    :    ParseFunction -> ParseFunction
optional parseFunction =
    let
        f tokens =
            case parseFunction tokens of
                (ParseDoesNotMatch , remainderTokens) ->
                    (ParseMatchesReturnsNothing, remainderTokens)
                result -> result
    in
        f

createParseAnyFunction : ParseFunctions -> ParseFunction
createParseAnyFunction parseFunctions =
    let
        parseAny_ tokens = parseAny parseFunctions tokens

        parseAny    :   ParseFunctions -> Tokens   ->   (ParseResult, RemainderTokens)
        parseAny parseFunctions_ tokens =
            case parseFunctions_ of
                [] -> (ParseDoesNotMatch, tokens)
                parseFunction::remainderParseFunctions ->
                    case (parseFunction tokens) of
                        (ParseDoesNotMatch, _) ->
                            parseAny remainderParseFunctions tokens
                        (ParseMatchesReturnsNothing, remainderTokens) ->
                            (ParseMatchesReturnsNothing, remainderTokens)
                        (ParseMatchesReturnsResult result, remainderTokens) ->
                            (ParseMatchesReturnsResult result, remainderTokens)
    in
        parseAny_


createOptionallyParseMultipleFunction : ParseFunction -> ParseFunction
createOptionallyParseMultipleFunction repeatedParseFunction =
    let
        parseMultiple_ : ParseFunction
        parseMultiple_ tokens =
            case tokens of
                [] ->
                    (ParseMatchesReturnsResult <| UnlabelledAstNode <| AstChildren [], tokens)
                _ ->
                    let
                        (astNodes, remainderTokens) = parseMultiple__ [] tokens
                    in
                        ( ParseMatchesReturnsResult <| UnlabelledAstNode <| AstChildren astNodes
                        , remainderTokens
                        )

        parseMultiple__ : AstNodes -> RemainderTokens   ->   (AstNodes, RemainderTokens)
        parseMultiple__ accAstNodes remainderTokens =
            case repeatedParseFunction remainderTokens of
                (ParseMatchesReturnsResult extraAstNode, remainderRemainderTokens) ->
                    parseMultiple__ (accAstNodes ++ [extraAstNode]) remainderRemainderTokens
                (ParseMatchesReturnsNothing, remainderRemainderTokens) ->
                    parseMultiple__ accAstNodes remainderRemainderTokens
                (ParseDoesNotMatch, remainderRemainderTokens) ->
                    (accAstNodes, remainderRemainderTokens)

    in
        parseMultiple_


createParseSequenceFunction : ParseFunctions -> ParseFunction
createParseSequenceFunction parseFunctions  =
    let
        parseSequence : ParseFunction
        parseSequence tokens =
            let
                parseSequence_ : ParseFunctions -> AstNodes -> RemainderTokens -> (ParseResult, RemainderTokens)
                parseSequence_ remainderParseFunctions accAstNodes remainderTokens =
                    case remainderParseFunctions of
                        [] ->
                            (ParseMatchesReturnsResult <| UnlabelledAstNode <| AstChildren accAstNodes, remainderTokens)
                        parseFunction::tailParseFunctions ->
                            case parseFunction remainderTokens of
                                (ParseMatchesReturnsNothing, remainderRemainderTokens) ->
                                    parseSequence_
                                        tailParseFunctions
                                        accAstNodes
                                        remainderRemainderTokens
                                (ParseMatchesReturnsResult extraChildNode, remainderRemainderTokens) ->
                                    parseSequence_
                                        tailParseFunctions
                                        (accAstNodes ++ [extraChildNode])
                                        remainderRemainderTokens
                                (ParseDoesNotMatch, _) ->
                                    (ParseDoesNotMatch, tokens)

            in
                case tokens of
                    [] -> (ParseDoesNotMatch, [])
                    _ -> parseSequence_ parseFunctions [] tokens

    in
        parseSequence


createParseAtLeastOneFunction : ParseFunction -> ParseFunction
createParseAtLeastOneFunction parseFunction =
    let
        parseAtLeastOne tokens =
            let
                (messyResult, remainderTokens) = parseAtLeastOne_ tokens
            in
                (cleanUpMessyResult messyResult, remainderTokens)

        sequenceFunction = createParseSequenceFunction
            [ parseFunction
            , createOptionallyParseMultipleFunction parseFunction
            ]

        parseAtLeastOne_ tokens = sequenceFunction tokens

        cleanUpMessyResult messyResult =
            case messyResult of
                ParseMatchesReturnsResult messyNode ->
                    let
                        getChildren node =
                            case node of
                                UnlabelledAstNode astNodeValue ->
                                    case astNodeValue of
                                        AstChildren children ->
                                            children
                                        _ ->
                                            Debug.todo ("")

                                _ ->
                                    Debug.todo ""
                        split_ children =
                            case children of
                                a::b::_ ->
                                    (a,b)
                                _ ->
                                    Debug.todo ("")
                        (headNode, tailMess) = split_ (getChildren messyNode)
                        tailNodes = getChildren tailMess
                        allNodes = [headNode] ++ tailNodes
                    in
                        ParseMatchesReturnsResult (UnlabelledAstNode (AstChildren allNodes))
                _ -> messyResult
    in
        parseAtLeastOne


--------------------------------------------------------------------------------
-- TESTS
--------------------------------------------------------------------------------

-- testTokens = [(LeftAngleBracket, "<")]

-- parseLeftAngleBracketKeep = createParseTokenKeepFunction LeftAngleBracket
-- parseLeftAngleBracket = createParseTokenIgnoreFunction LeftAngleBracket
-- parseRightAngleBracket = createParseTokenIgnoreFunction RightAngleBracket
-- parseRightAngleBracketKeep = createParseTokenIgnoreFunction RightAngleBracket
-- parseWordKeep = createParseTokenKeepFunction Word

-- tests = suite "Parser.elm"
--     [
--         test "consumeToken with match" (
--             assertEqual
--                 (consumeToken LeftAngleBracket testTokens)
--                 (TokenMatches ("<", []))
--         )
--         ,
--         test "consumeToken with match" (
--             assertEqual
--                 (consumeToken LeftAngleBracket testTokens)
--                 (TokenMatches ("<", []))
--         )
--         ,
--         test "consumeToken no match" (
--             assertEqual
--                 (consumeToken RightAngleBracket testTokens)
--                 (TokenDoesNotMatch testTokens)
--         )
--         ,
--         test "createParseTokenIgnoreFunction" (
--             assertEqual
--                 (ParseMatchesReturnsNothing, [])
--                 (
--                     createParseTokenIgnoreFunction LeftAngleBracket
--                     <| tokenize "<"
--                 )
--         )
--         ,
--         test "createParseTokenKeepFunction" (
--             assertEqual
--                 (
--                     (ParseMatchesReturnsResult <| UnlabelledAstNode <| AstLeaf "<")
--                     ,
--                     []
--                 )
--                 (
--                     createParseTokenKeepFunction LeftAngleBracket
--                     <| tokenize "<"
--                 )
--         )
--         ,
--         test "createParseTokenKeepFunction" (
--             assertEqual
--                 (
--                     (ParseMatchesReturnsResult <| LabelledAstNode { label = "LEFT_ANGLE_BRACKET", value = AstLeaf "<" })
--                     ,
--                     []
--                 )
--                 (
--                     let
--                         parseBracket = labelled "LEFT_ANGLE_BRACKET" <| createParseTokenKeepFunction LeftAngleBracket
--                     in
--                         parseBracket <| tokenize "<"
--                 )
--         )
--         ,
--         test "parseLeftAngleBracket" (
--             assertEqual
--                 (ParseMatchesReturnsNothing, [])
--                 (parseLeftAngleBracket testTokens)
--         )
--         ,
--         test "parseWordKeep" (
--             assertEqual
--                 (ParseMatchesReturnsResult (UnlabelledAstNode (AstLeaf "h1")) , [])
--                 (parseWordKeep  <| tokenize("h1"))
--         )

--         ,
--         (suite "optionallyParseMultiple"
--             (
--                 let
--                     optionallyParseMultipleLeftBrackets =
--                         createOptionallyParseMultipleFunction parseLeftAngleBracketKeep
--                 in
--                     [
--                         test "optionallyParseMultiple" (
--                             assertEqual
--                                 (ParseMatchesReturnsResult (UnlabelledAstNode (AstChildren ([
--                                         UnlabelledAstNode (AstLeaf "<"),
--                                         UnlabelledAstNode (AstLeaf "<")
--                                     ]))),[])
--                                 (optionallyParseMultipleLeftBrackets [(LeftAngleBracket, "<"),(LeftAngleBracket, "<")])
--                         )
--                         ,
--                         test "optionallyParseMultiple" (
--                             assertEqual

--                                 (
--                                     ParseMatchesReturnsResult (UnlabelledAstNode (AstChildren ([UnlabelledAstNode (AstLeaf "<")])))
--                                     ,
--                                     [(Word,"hello")]
--                                 )
--                                 (optionallyParseMultipleLeftBrackets [(LeftAngleBracket, "<"),(Word, "hello")])
--                         )
--                         ,
--                         test "optionallyParseMultiple" (
--                             assertEqual
--                                 (ParseMatchesReturnsResult (UnlabelledAstNode (AstChildren [])), [(Word,"hello")])
--                                 (optionallyParseMultipleLeftBrackets <| tokenize("hello"))
--                         )
--                     ]
--             )

--         )
--         ,
--         (suite "parseAny"
--             (
--                 let
--                     parseLeftOrRightBracket =
--                         (
--                             createParseAnyFunction
--                             [
--                                 parseLeftAngleBracket,
--                                 parseRightAngleBracket
--                             ]
--                         )
--                 in
--                     [
--                         test "parseAny left" (
--                             assertEqual
--                                 (ParseMatchesReturnsNothing, [])
--                                 (parseLeftOrRightBracket (tokenize "<"))
--                         )
--                         ,
--                         test "parseAny right" (
--                             assertEqual
--                                 (ParseMatchesReturnsNothing, [])
--                                 (parseLeftOrRightBracket (tokenize ">"))
--                         )
--                         ,
--                         test "parseAny none" (
--                             assertEqual
--                                 (ParseDoesNotMatch, [(Word, "!")])
--                                 (parseLeftOrRightBracket (tokenize "!"))
--                         )
--                     ]
--             )
--         )
--         ,
--         (suite "parseSequence"
--             (
--                 let
--                     parseSimpleTag =
--                         (
--                             createParseSequenceFunction
--                             [
--                                 parseLeftAngleBracket,
--                                 parseWordKeep,
--                                 parseRightAngleBracket
--                             ]
--                         )
--                 in
--                     [
--                         test "parseSequence" (
--                             assertEqual
--                                 (
--                                     (ParseMatchesReturnsResult
--                                         <| UnlabelledAstNode
--                                         <| AstChildren [UnlabelledAstNode (AstLeaf "h1")]
--                                     ),
--                                     []
--                                 )
--                                 (parseSimpleTag (tokenize "<h1>"))
--                         )
--                         ,
--                         test "parseSequence" (
--                             assertEqual
--                                 (ParseDoesNotMatch,[(LeftAngleBracket,"<"), (RightAngleBracket,">")])
--                                 (parseSimpleTag (tokenize "<>"))
--                         )
--                         ,
--                         test "parseSequence" (
--                             let
--                                 optionalMiddle =
--                                     (
--                                         createParseSequenceFunction
--                                         [
--                                             parseLeftAngleBracket,
--                                             optional parseWordKeep,
--                                             parseRightAngleBracket
--                                         ]
--                                     )
--                             in
--                                 assertEqual
--                                     (
--                                         (ParseMatchesReturnsResult
--                                             <| UnlabelledAstNode
--                                             <| AstChildren []
--                                         ),
--                                         []
--                                     )
--                                     (optionalMiddle (tokenize "<>"))
--                         )
--                     ]
--             )
--         )
--         ,
--         (suite "parseAtLeastOne"
--             (
--                 let
--                     parseLeftOrRightBracket = createParseAnyFunction
--                         [parseLeftAngleBracketKeep, parseRightAngleBracketKeep]
--                     parseAtLeastOneLeftOrRightBracket = createParseAtLeastOneFunction parseLeftOrRightBracket
--                 in
--                     [
--                         test "parseAtLeastOne" (
--                             assertEqual
--                                 (
--                                     ParseMatchesReturnsResult (UnlabelledAstNode (AstChildren ([
--                                             UnlabelledAstNode (AstLeaf "<"),
--                                             UnlabelledAstNode (AstLeaf "<"),
--                                             UnlabelledAstNode (AstLeaf "<")
--                                         ])))
--                                     ,
--                                     [(RightAngleBracket,">")]
--                                 )
--                                 ((createParseAtLeastOneFunction parseLeftAngleBracketKeep) [
--                                     (LeftAngleBracket, "<"),
--                                     (LeftAngleBracket, "<"),
--                                     (LeftAngleBracket, "<"),
--                                     (RightAngleBracket, ">")
--                                 ])
--                         )
--                         ,
--                         test "parseAtLeastOne" (
--                             assertEqual
--                                 (
--                                     ParseMatchesReturnsResult (UnlabelledAstNode (AstChildren ([
--                                         UnlabelledAstNode (AstLeaf "<"),
--                                         UnlabelledAstNode (AstLeaf ">")
--                                         ])))
--                                     ,
--                                     [(Word,"!")]
--                                 )
--                                 (parseAtLeastOneLeftOrRightBracket [
--                                     (LeftAngleBracket, "<"),
--                                     (LeftAngleBracket, ">"),
--                                     (Word, "!")
--                                 ])
--                         )
--                         ,
--                         test "parseAtLeastOne" (
--                             assertEqual
--                                 (ParseDoesNotMatch,[(Word,"!"),(LeftAngleBracket,"<")])
--                                 (parseAtLeastOneLeftOrRightBracket [
--                                     (Word, "!"),
--                                     (LeftAngleBracket, "<")
--                                 ])
--                         )
--                     ]
--             )
--         )
--     ]

-- main = runSuiteHtml tests
