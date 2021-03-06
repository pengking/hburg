-----------------------------------------------------------------------------
-- |
-- Module      :  Util
-- Copyright   :  Copyright (c) 2007 Igor Boehm - Bytelabs.org. All rights reserved.
-- License     :  BSD-style (see the file LICENSE)
-- Author      :  Igor Boehm  <igor@bytelabs.org>
--
-- General utility functions.
-----------------------------------------------------------------------------

module Hburg.Util (
   -- Functions
   toInt,
   toUpper,
   bye,
   die,
) where

{- unqualified imports  -}
import System.IO

{- qualified imports  -}
import qualified System.Exit as E
import qualified Data.Char as C (ord, toUpper)

------------------------------------------------------------------------------------

{- | Convert a string to a number given a base -}
stToInt :: Int -> String -> Int
stToInt base digits =
  sign * (foldl acc 0 $ concatMap digToInt digits1)
  where
    splitSign ('-' : ds) = ((-1), ds)
    splitSign ('+' : ds) = ( 1  , ds)
    splitSign ds         = ( 1  , ds)
    (sign, digits1)      = splitSign digits
    digToInt c  | c >= '0' && c <= '9'
                      = [C.ord c - C.ord '0']
                | c >= 'A' && c <= 'Z'
                      =  [C.ord c - C.ord 'A' + 10]
                | c >= 'a' && c <= 'z'
                      =  [C.ord c - C.ord 'a' + 10]
                | otherwise = []
    acc i1 i0 = i1 * base + i0

{- | Convert String to Int -}
toInt :: String -> Int
toInt str = stToInt 10 str

{- | Convert String to upper case String -}
toUpper :: String -> String
toUpper str = map (C.toUpper) (str)

{- | Successful Exit -}
bye :: String -> IO a
bye s = do
  putStrLn s
  E.exitWith (E.ExitSuccess)

{- | Exit upon failure -}
die :: String -> IO a
die s = do
  hPutStrLn stderr s
  E.exitWith (E.ExitFailure 1)

------------------------------------------------------------------------------------