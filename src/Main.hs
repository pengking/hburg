-----------------------------------------------------------------------------
-- |
-- Module      :  Main
-- Copyright   :  Copyright (c) 2007 Igor Boehm - Bytelabs.org. All rights reserved.
-- License     :  BSD-style (see the file LICENSE) 
-- Author      :  Igor Boehm  <igor@bytelabs.org>
--
--
-- The main entry point of our code generator. In here we do several things,
-- namely:
--        * handles CLI args
--        * feeds the lexer and reacts to possible errors
--        * feeds the parser and reacts to possible errors
--        * feeds the code generator and emits its result to a file
-----------------------------------------------------------------------------

module Main where

import IO
import System
import System.Console.GetOpt

import qualified Debug as Debug (Level(..), Entry, new, filter, format)

import Parser.Lexer (Token, scanner)
import Parser.Parser (ParseResult(..), parse)

import qualified Ast.Ir as Ir (Ir(..))

import qualified Gen.Backend as B (emit)
import qualified Gen.Emit as E (Emit(..))

------------------------------------------------------------------------------------

-- | main. Read arguments and start code generator
main :: IO ()
main = getArgs >>= \args -> codeGen args

--
-- Display information about ourselves
--

usageHeader :: String -> String
usageHeader prog
    = "Usage: "++ prog ++" [OPTION...] file\n"

--
-- Various ways how we may exit
--

byeStr :: String -> IO a
byeStr s = putStr s >> exitWith ExitSuccess

bye :: IO a
bye = exitWith ExitSuccess

showTokens :: [Token] -> IO a
showTokens t
    = byeStr (outToken t)
    where
        outToken :: [Token] -> String
        outToken [] = ""
        outToken (x:xs) = (show x) ++ outToken xs

die :: String -> IO a
die s 
    = hPutStr stderr (s ++"\n") >> exitWith (ExitFailure 1)

dieCodeGen :: String -> IO a
dieCodeGen s
    = getProgName >>= \prog -> die (prog ++": "++ s)

--
-- Command line arguments
--

data CLIFlags
    = OptHelp
    | OptOutputClass String
    | OptOutputPackage String
    | OptNodeKindType String
    | OptDebug
    deriving (Eq)

constArgs :: [a]
constArgs = []

argInfo :: [OptDescr CLIFlags]
argInfo
    = [Option [ '?' ] ["help"] (NoArg OptHelp)
            "display this help and exit"
        , Option [ 'd' ] ["debug"] (NoArg OptDebug)
            "display debugging output after parsing"
        , Option [ 'c' ] ["classname"] (ReqArg OptOutputClass "Class")
            "code generator Java class name (default: Codegen)"
        , Option [ 'p' ] ["package"] (ReqArg OptOutputPackage "Package")
            "Java package name (e.g.: comp.gen)"
        , Option [ 't' ] ["type"] (ReqArg OptNodeKindType "Type")
            "Java datatype which discriminates IR nodes (default: NodeKind)"
        ]

--
-- Extract various command line options
--
getOutputClassName :: [CLIFlags] -> IO (String)
getOutputClassName cli
    = case [ s | (OptOutputClass s) <- cli ] of
        [] -> return ("Codegen")
        files -> return (last files)

getOutputPackage :: [CLIFlags] -> IO (String)
getOutputPackage cli
    = case [ s | (OptOutputPackage s) <- cli ] of
        [] -> return ("")
        packages -> return (last packages)

getNodeKindType :: [CLIFlags] -> IO (String)
getNodeKindType cli
    = case [ s | (OptNodeKindType s) <- cli ] of
        [] -> return ("NodeKind")
        types -> return (last types)

--
-- Run code generator and parser
--

-- | Evaluate arguments and kick of scanner and parser
codeGen :: [String] -> IO ()
codeGen args
    = case getOpt Permute argInfo (constArgs ++ args) of
        (cli,_,[]) | OptHelp `elem` cli ->
            do
                prog <- getProgName
                byeStr (usageInfo (usageHeader prog) argInfo)
        (cli,[fname],[]) ->
            do
                content <- readFile fname
                outclass <- getOutputClassName cli
                outpkg <- getOutputPackage cli
                ntype <- getNodeKindType cli
                -- Run Our Parser
                case runParse content of
                    -- If the result or the parser is Right we emit code for it
                    Right result ->
                        let clazz = B.emit outclass outpkg ntype result in
                        if (OptDebug `elem` cli)
                            then 
                                do
                                    outputFiles clazz
                                    byeStr $ Debug.format $ Debug.filter Debug.All $ Ir.debug result
                            else
                                do
                                    outputFiles clazz
                                    bye
                    Left err | OptDebug `elem` cli ->
                        dieCodeGen $ Debug.format $ Debug.filter Debug.All err
                    Left err ->
                        dieCodeGen $ Debug.format $ Debug.filter Debug.Error err
        (_,_,errors) ->
            do
                prog <- getProgName
                die (concat errors ++
                     usageInfo (usageHeader prog) argInfo)

-- | Runs the Lexer and Parser
runParse :: String -> Either [Debug.Entry] Ir.Ir
runParse input =
    -- Scan using our scanner
    case (scanner input) of
        Left e -> Left [Debug.new Debug.Error e]
        -- Parse using our parser
        Right lexx -> case parse lexx of
            -- Parse was Ok, we can continue....
            ParseOk result ->
                    Right result
            -- There were errors...
            ParseErr errors result ->
                    Left (Ir.debug result ++ errors)
            -- The parse failed due to some serious error...
            ParseFail failed ->
                    Left failed

-- | Output generated class into a file
outputFiles :: E.Emit a => [a] -> IO [()]
outputFiles classes
    = mapM
        (\c -> writeFile (E.emitTo c) (E.emit c))
        (classes)