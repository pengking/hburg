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
        NodeClass(..),
        -- * Types
        Node,
        -- * Construction
        new,
        -- * Functions
        addLinkBlockCode, setLink,
        getName, getTy, getIdent, getLink,
        getSem1, getSem2, getSem3, getSem4, getSem5, getSem6,
        equalIdents,hasLink,
        showAsFunction,
        -- ** AST traversal functions
        mapPreOrder,mapPreOrder2,mapPreOrder3,
        mapChildren,
    ) where


import qualified Ast.Ident as Id (Ident)
import Ast.TermTy (TermTy, TermTyClass(..))
import qualified Ast.Code as C (Code, empty)

import Env.Env(ElemClass(..), ElemType(EUnknown))
-----------------------------------------------------------------------------

-- | AST Node class
class NodeClass a where
    emptyNode :: a
    isNil :: a -> Bool
    addChild :: a -> a -> a
    addSibling :: a -> a -> a
    hasSibling :: a -> Bool
    hasSibling a = length (getSiblings a) > 0
    hasChildren :: a -> Bool
    hasChildren a = length (getChildren a) > 0
    getChildren :: a -> [a]
    getSiblings :: a -> [a]

-- | AST Node type
data Node 
    = Nil
    | N {
        ty      :: TermTy,  -- ^ node kind or type of node (e.g.: reg, ADD, SUB, stmt, etc.)
        code1   :: C.Code,
        code2   :: C.Code,
        child   :: Node,    -- ^ link to first child node
        code3   :: C.Code,
        sibling :: Node,    -- ^ points to sibling
        code4   :: C.Code,
        code5   :: C.Code,  -- ^ code before link but within link block
        link    :: Node,    -- ^ pointer to link node
        code6   :: C.Code   -- ^ code after link but within link block
    }
    deriving (Ord)

instance Eq Node where
    -- Two nodes are equal if they share the same TermTy and if they have
    -- the same amount of child nodes (a.k.a. same amount of parameters)
    (==) n1@(N {ty = ty1}) n2@(N {ty = ty2})
        = ((ty1 == ty2) && (length (getChildren n1) == length (getChildren n2)))
    (==) (Nil) (Nil) = True
    (==) _ _ = False

instance Show Node where
    show (Nil) = "Nil"
    show n@(N { link = (Nil) })
        = show (ty n) ++ ": " ++ 
        (displayChildren (child n) "   ")
    show n
        = show (ty n) ++ ":" ++ " link->" ++ show (ty (link n)) ++
        (displayChildren (child n) "   ")

displayChildren :: Node -> String -> String
displayChildren (Nil) gap = ")"
displayChildren n gap
    = "\n" ++ gap ++ "(" ++ show (ty n) ++
      (displayChildren (child n) (gap ++ "  ")) ++
      (displayChildren (sibling n) gap)

instance ElemClass Node where
    elemShow Nil = "Nil"
    elemShow n = elemShow (ty n)
    
    elemType Nil = EUnknown
    elemType n = elemType (ty n)
    
    elemL Nil = -1
    elemL n = elemL (ty n)
    
    elemC Nil = -1
    elemC n = elemC (ty n)

instance NodeClass Node where
    isNil (Nil) = True
    isNil _ = False

    emptyNode = Nil

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

instance TermTyClass Node where
    getId n = getId (ty n)
    
    isTerm (Nil) = False
    isTerm n = isTerm (ty n)
    
    isNonTerm (Nil) = False
    isNonTerm n = isNonTerm (ty n)
    
    getTerm n = getTerm (ty n)
    getNonTerm n = getNonTerm (ty n)
    
    getAttr (Nil) = []
    getAttr n = getAttr (ty n)
    
    hasBinding (Nil) = False
    hasBinding n = hasBinding (ty n)
    getBinding n = getBinding (ty n)


-- | Constructor for building a Node
new :: TermTy -> C.Code -> C.Code -> Node -> C.Code -> Node -> C.Code -> Node
new ty1 c1 c2 child1 c3 link1 c4
    = N {
        ty = ty1,
        code1 = c1,
        code2 = c2,
        child = child1,
        code3 = c3,
        sibling = link1,
        code4 = c4,
        code5 = C.empty,
        link = Nil,
        code6 = C.empty
    }

-- | Adds semantic action contained in link block
addLinkBlockCode :: Node -> C.Code -> C.Code -> Node
addLinkBlockCode n c5 c6 = (n { code5 = c5 }) { code6 = c6 }

hasLink :: Node -> Bool
hasLink (Nil) = False
hasLink (N { link = Nil }) = False
hasLink _ = True

-- | Compare Nodes based on identifiers
equalIdents :: Node -> Node -> Bool
equalIdents (Nil) (Nil) = True
equalIdents (N { ty = ty1 }) (N { ty = ty2 }) = getId ty1 == getId ty2
equalIdents _ _ = False


-- | Shows a node like a function 'name (child1, child2, etc.)'
showAsFunction :: Node -> String
showAsFunction (Nil) = ""
showAsFunction n | hasChildren n
    = elemShow n ++ " (" ++
    foldr
        (\child str -> 
            (\x -> if ((length x) > 0) then (str ++ ", ") else "") (str) ++
            if (isTerm child)
                then show (getId child) ++ "(...)"
                else show (getId child))
        ""
        (getChildren n) ++
    ")"
showAsFunction n = elemShow n

getName :: Node -> String
getName (Nil) = ""
getName n = show (getId (ty n))

getIdent :: Node -> Maybe Id.Ident
getIdent (Nil) = Nothing
getIdent n = Just (getId (ty n))

getTy :: Node -> Maybe TermTy
getTy (Nil) = Nothing
getTy n = Just (ty n)

getLink :: Node -> Node
getLink (Nil) = Nil
getLink n = link n

getSem1 :: Node -> C.Code
getSem1 (Nil) = C.empty
getSem1 n = code1 n

getSem2 :: Node -> C.Code
getSem2 (Nil) = C.empty
getSem2 n = code2 n

getSem3 :: Node -> C.Code
getSem3 (Nil) = C.empty
getSem3 n = code3 n

getSem4 :: Node -> C.Code
getSem4 (Nil) = C.empty
getSem4 n = code4 n

getSem5 :: Node -> C.Code
getSem5 (Nil) = C.empty
getSem5 n = code5 n

getSem6 :: Node -> C.Code
getSem6 (Nil) = C.empty
getSem6 n = code6 n

setLink :: Node -> Node -> Node
setLink (Nil) _ = Nil
setLink n lnk = n { link = lnk }

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
mapPreOrder3 :: (Int -> Node -> [a]) ->        -- ^ path accumulation function
                ([a] -> Node -> [b]) ->        -- ^ do this before recursing in pre order
                ([a] -> Node -> [b]) ->        -- ^ do this after returning from pre order recursion
                Node ->                        -- ^ current node
                [([a], [b], Node)]             -- ^ return type
mapPreOrder3 _ _ _ (Nil) = []
mapPreOrder3 _ _ _ (N { child = Nil }) = []
mapPreOrder3 path pre post n
    = let children = (zip [1 .. (length (getChildren n))]  (getChildren n)) in
    concat [ accumMap path pre post index [] node  | (index, node) <- children ]
    where
        accumMap ::    (Int -> Node -> [a]) -> 
                    ([a] -> Node -> [b]) ->
                    ([a] -> Node -> [b]) ->
                    Int -> 
                    [a] -> 
                    Node -> 
                    [([a], [b], Node)]
        accumMap path pre post pos accum n@(N { child = Nil })
            = let curpath = accum ++ (path pos n) in
            [(curpath, (pre curpath n) ++ (post curpath n), n)]
        accumMap path pre post pos accum n
            = let children = (zip [1 .. (length (getChildren n))]  (getChildren n)) in
            let curpath = accum ++ (path pos n) in
            let precode = pre curpath n in
            let postcode = post curpath n in
            let between = concat [ accumMap path pre post index curpath node  | (index, node) <- children ] in
            [(curpath, precode, n)] ++ between ++ [(curpath, postcode, n)]
