-----------------------------------------------------------------------------
-- |
-- Module      :  Enum
-- Copyright   :  Copyright (c) 2007 Igor Boehm - Bytelabs.org. All rights reserved.
-- License     :  BSD-style (see the file LICENSE)
-- Author      :  Igor Boehm  <igor@bytelabs.org>
--
-- Java enumeration.
-----------------------------------------------------------------------------

module Gen.Emit.Java.Enum (
  -- * Types
  Enum,
  -- * Functions
  new,
) where

{- unqualified imports  -}
import Prelude hiding (Enum)

import Text.PrettyPrint

import Gen.Document (Document(..))

import Gen.Emit.Java.Modifier(Modifier)

{- qualified imports  -}

-----------------------------------------------------------------------------

data Enum =
  MkEnum
    Modifier  -- public|private|protected modifier
    String    -- enumeration identifier
    [String]  -- enumeration elements
  deriving (Eq)

instance Show Enum where
  show e = render . toDoc $ e

instance Document Enum where
  toDoc (MkEnum modifier ident enums) =
    toDoc modifier <+> text "enum"    -- Modifier
    <+> text ident                    -- Identifier
    <+> 
      lbrace
        $+$
        (if (null enums)              -- Enumeration
          then empty
          else
            foldr1
              (\e1 e2 -> nest 2 e1 <> comma $+$ nest 2 e2)
              (map (text) enums))
        $+$
      rbrace

-- | Constructor for building a Modifier
new :: Modifier -> String -> [String] -> Enum
new m ident elems = MkEnum m ident elems

-----------------------------------------------------------------------------