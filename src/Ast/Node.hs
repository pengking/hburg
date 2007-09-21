-----------------------------------------------------------------------------
-- |
-- Module      :  Node
-- Copyright   :  Copyright (c) 2007 Igor Boehm - Bytelabs.org. All rights reserved.
-- License     :  BSD-style (see the file LICENSE) 
-- Author      :  Igor Boehm  <igor@bytelabs.org>
--
--
-- The input tree pattern matching grammar specification is converted into an
-- AST where this module, an AST node, is the primary substrate.
-----------------------------------------------------------------------------

module Ast.Node (
        -- * Classes
        TreeClass(..),
        -- * Types
        Node, Position(..),
        -- * Construction
        new,
        -- * Functions
        addLinkBlockCode, setLink,
        getName, getTerm, getIdent, getLink, getSemAct,
        equalIdents, hasLink,
        showAsFun,
        -- ** AST traversal functions
        mapPreOrder,mapPreOrder2,mapPreOrder3,
        mapChildren,
    ) where

import qualified Data.Map as M

import qualified Ast.Ident as Id (Ident)
import Ast.Term (Term, TermClass(..))
import qualified Ast.Code as C (Code, empty)

import qualified Csa.Elem as E (ElemClass(..), ElemType(EUnknown))
-----------------------------------------------------------------------------

-- | Abstract Syntax Tree class
class TreeClass a where
    empty :: a
    isNil :: a -> Bool
    addChild :: a -> a -> a
    addSibling :: a -> a -> a
    hasSibling :: a -> Bool
    hasSibling a = length (getSiblings a) > 0
    hasChildren :: a -> Bool
    hasChildren a = length (getChildren a) > 0
    getChildren :: a -> [a]
    getSiblings :: a -> [a]

-- | Abstract Syntax Tree Node data type
data Node
    = Nil
    | N {   term    :: Term     -- ^ node kind or type of node (e.g.: reg, ADD, SUB, stmt, etc.)
        ,   child   :: Node     -- ^ link to first child node
        ,   sibling :: Node     -- ^ points to sibling
        ,   link    :: Node     -- ^ points to link node
        ,   code    :: M.Map Position C.Code }  -- ^ Map enconding semantic actions and their position relativ to this node
    deriving (Ord)

-- | Position denotes the position of a semantic action relativ to a node
data Position
    = Pos1 -- ^ code before the Term
    | Pos2 -- ^ code after the Term and before any sub pattern
    | Pos3 -- ^ code after subpattern of this Term
    | Pos4 -- ^ code at the very end of this Term
    -- semantic actions in link block '[' ']'
    | Pos5 -- ^ code within link block and before link
    | Pos6 -- ^ code within link block and after link
    deriving (Eq,Ord,Show)

instance Eq Node where
    -- Two nodes are equal if they share the same Term and if they have
    -- the same amount of child nodes (a.k.a. same amount of parameters)
    (==) n1@(N {term = t1}) n2@(N {term = t2})
        = ((t1 == t2) && (length (getChildren n1) == length (getChildren n2)))
    (==) (Nil) (Nil) = True
    (==) _ _ = False

instance Show Node where
    show (Nil) = "Nil"
    show n
        = show (term n) ++ ":" ++
        (if (hasLink n)
            then " link->" ++ show (term (link n))
            else " ") ++
        (showChildren (child n) "   ")
        where
            showChildren :: Node -> String -> String
            showChildren (Nil) gap = ")"
            showChildren n gap
                = "\n" ++ gap ++ "(" ++ show (term n) ++
                  (showChildren (child n) (gap ++ "  ")) ++
                  (showChildren (sibling n) gap)

-- | Shows a node like a function 'name(child1, child2, etc.)'
showAsFun :: Node -> String
showAsFun (Nil) = ""
showAsFun n | hasChildren n
    = E.elemShow n ++ " (" ++
    foldr
      (\child str ->
               (if (str /= "") 
                    then (str ++ ", ") 
                    else "") ++
                (getName child) ++
                (if (isTerminal child)
                    then "(...)"
                    else ""))
      ""
      (getChildren n) ++ ")"
showAsFun n = E.elemShow n


instance E.ElemClass Node where
    elemShow Nil = "Nil"
    elemShow n = E.elemShow (term n)
    
    elemType Nil = E.EUnknown
    elemType n = E.elemType (term n)
    
    elemL Nil = -1
    elemL n = E.elemL (term n)
    
    elemC Nil = -1
    elemC n = E.elemC (term n)

instance TreeClass Node where
    isNil (Nil) = True
    isNil _ = False

    empty = Nil

    getSiblings (Nil) = []
    getSiblings (N { sibling = Nil }) = []
    getSiblings n = (sibling n) : getSiblings (sibling n)

    getChildren (Nil) = []
    getChildren (N { child = Nil }) = []
    getChildren n = (child n) : getSiblings (child n)

    addChild (Nil) child = Nil
    addChild n@(N { child = Nil }) child1 = n { child = child1 }
    addChild n child1 = n { child = addSibling (child n) child1 }

    addSibling (Nil) sib = Nil
    addSibling n@(N { sibling = Nil }) sib = n { sibling = sib }
    addSibling n sib1 = n { sibling = addSibling (sibling n) sib1 }

instance TermClass Node where
    getId n = getId (term n)

    isTerminal (Nil) = False
    isTerminal n = isTerminal (term n)

    isNonTerminal (Nil) = False
    isNonTerminal n = isNonTerminal (term n)

    getTerminal n = getTerminal (term n)
    getNonTerminal n = getNonTerminal (term n)

    getAttr (Nil) = []
    getAttr n = getAttr (term n)

    hasBinding (Nil) = False
    hasBinding n = hasBinding (term n)
    getBinding n = getBinding (term n)


-- | Constructor for building a Node
new :: Term -> C.Code -> C.Code -> Node -> C.Code -> Node -> C.Code -> Node
new t c1 c2 child' c3 link' c4
    = N {   term = t
        ,   child = child'
        ,   sibling = link'
        ,   link = Nil
        -- semantic actions
        ,   code = M.fromList [ (Pos1, c1)
                              , (Pos2, c2)
                              , (Pos3, c3)
                              , (Pos4, c4)
                              , (Pos5, C.empty)
                              , (Pos6, C.empty)] }

-- | Compare Nodes based on identifiers
equalIdents :: Node -> Node -> Bool
equalIdents (Nil) (Nil) = True
equalIdents (N { term = t1 }) (N { term = t2 }) = getId t1 == getId t2
equalIdents _ _ = False

getName :: Node -> String
getName (Nil) = ""
getName n = show (getId (term n))

getIdent :: Node -> Maybe Id.Ident
getIdent (Nil) = Nothing
getIdent n = Just (getId (term n))

getTerm :: Node -> Maybe Term
getTerm (Nil) = Nothing
getTerm n = Just (term n)

hasLink :: Node -> Bool
hasLink (Nil) = False
hasLink (N { link = Nil }) = False
hasLink _ = True

getLink :: Node -> Node
getLink (Nil) = Nil
getLink n = link n

setLink :: Node -> Node -> Node
setLink (Nil) _ = Nil
setLink n link' = n { link = link' }

-- | Adds semantic action contained in link block
addLinkBlockCode :: Node -> C.Code -> C.Code -> Node
addLinkBlockCode n c1 c2 
    = let code' = (M.insert Pos5 c1 (M.insert Pos6 c2 (code n))) in
    n { code = code' }

-- | Get Semantic Action based on Position where it has been specified
getSemAct :: Position -> Node -> C.Code
getSemAct _ (Nil) = C.empty
getSemAct pos n = (code n) M.! pos

--
-- Higher order AST traversal functions
--

-- | mapPreOrder.
mapPreOrder :: (Node -> a) -> Node -> [a]
mapPreOrder _ (Nil) = []
mapPreOrder f n
    =  ((f n) : (concat [ mapPreOrder f x | x <- getChildren n ]))

-- | mapChildren.
mapChildren :: (Int -> Node -> a) -> Node -> [a]
mapChildren _ (Nil) = []
mapChildren _ (N { child = Nil }) = []
mapChildren f n 
    = let children = getChildren n in
    map 
        (\(index, child) -> f index child)
        (zip [1 .. (length children)]  children)

-- | Note: The root is node is NOT processed! Processing starts from roots children.
mapPreOrder2 :: (Int -> Node -> [a]) -> (Node -> b) -> Node -> [([a], b)]
mapPreOrder2 _ _ (Nil) = []
mapPreOrder2 _ _ (N { child = Nil }) = []
mapPreOrder2 f g n
    = let children = (zip [1 .. (length (getChildren n))]  (getChildren n)) in
    concat [ accumMap f g index [] node  | (index, node) <- children ]
    where
        accumMap :: (Int -> Node -> [a]) -> (Node -> b) -> Int -> [a] -> Node -> [([a], b)]
        accumMap f g pos accum n@(N { child = Nil }) 
            = [(accum ++ (f pos n), g n)]
        accumMap f g pos accum n
            = let children = (zip [1 .. (length (getChildren n))]  (getChildren n)) in
            let current = accum ++ (f pos n) in
            (current, g n) : concat [ accumMap f g index current node  | (index, node) <- children ]


-- | Note: The root node is NOT processed! Processing starts from roots children.
mapPreOrder3 :: (Int -> Node -> [a])  ->      -- ^ path accumulation function
                ([a] -> Node -> [b]) ->    -- ^ do this before recursing in pre order
                ([a] -> Node -> [b]) ->    -- ^ do this after returning from pre order recursion
                Node ->                    -- ^ current node
                [([a], [b], Node)]       -- ^ return type
mapPreOrder3 _ _ _ (Nil) = []
mapPreOrder3 _ _ _ (N { child = Nil }) = []
mapPreOrder3 path pre post n
    = let children = (zip [1 .. (length (getChildren n))]  (getChildren n)) in
    concat [ accumMap path pre post index [] node  | (index, node) <- children ]
    where
        accumMap :: (Int -> Node -> [a]) ->
                    ([a] -> Node -> [b]) ->
                    ([a] -> Node -> [b]) ->
                    Int -> 
                    [a] -> 
                    Node -> 
                    [([a], [b], Node)]
        -- Case where Node has no children
        accumMap path pre post pos accum n@(N { child = Nil })
            = let curpath = accum ++ (path pos n) in
            [(curpath, (pre curpath n) ++ (post curpath n), n)]
        -- Case where Node has children
        accumMap path pre post pos accum n
            = let children = (zip [1 .. (length (getChildren n))]  (getChildren n)) in
            let curpath = accum ++ (path pos n) in
            let precode = pre curpath n in
            let postcode = post curpath n in
            let between = concat [ accumMap path pre post index curpath node  | (index, node) <- children ] in
            [(curpath, precode, n)] ++ between ++ [(curpath, postcode, n)]