-----------------------------------------------------------------------------
-- |
-- Module      :  Cost
-- Copyright   :  Copyright (c) 2007 Igor Böhm - Bytelabs.org. All rights reserved.
-- License     :  BSD-style (see the file LICENSE)
-- Author      :  Igor Böhm  <igor@bytelabs.org>
--
-- Costs for productions can either be static (i.e. an integer number), or they
-- can be dynamic and include arbitrary expressions.
-----------------------------------------------------------------------------

module Hburg.Ast.Cost (
  -- Types
  Cost,
  -- Functions
  static, dynamic,
  isZero,
) where

{- unqualified imports  -}
import Hburg.Ast.Code (Code)

{- qualified imports  -}

-----------------------------------------------------------------------------

{- | Cost Type -}
data Cost =
  Static Int
  | Dynamic Code
  deriving (Eq,Ord)

instance Show Cost where
  show (Static i) = show i
  show (Dynamic c) = show c

{- | Create static cost consisting of a constant. -}
static :: Int -> Cost
static i = (Static i)

{- | Create dynamic cost consisting of an arbitrary expression. -}
dynamic :: Code -> Cost
dynamic c = (Dynamic c)

{- | In the case when a cost is statically defined we can scrutinize
     it to see if it is zero. -}
isZero :: Cost -> Bool
isZero (Dynamic _) = False
isZero (Static num) = num == 0

-----------------------------------------------------------------------------