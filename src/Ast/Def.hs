-----------------------------------------------------------------------------
-- |
-- Module      :  Def
-- Copyright   :  Copyright (c) 2007 Igor Böhm - Bytelabs.org. All rights reserved.
-- License     :  BSD-style (see the file LICENSE) 
-- Author      :  Igor Böhm  <igor@bytelabs.org>
--
--
-- Each non terminal must be defined and consists of one or more productions:
--		* nt = prod1
--				| prod2
--				| ...
--				| prodN
--
-- This module provides the necessary abstractions to work with definitions.
--
-----------------------------------------------------------------------------

module Ast.Def (
		-- * Introduction
		-- $intro
		Definition,
        -- *  Construction
        -- $construction
		new,
        -- *  Operations on attributes
        -- $attribute operations
		getCode, getProds, getClosures,
		getNodeTypes, getNodeReturnType, getDefForProd,
		setProds,
		isNodeDefined,
		mergeDefs,
	) where

import List (find)
import Maybe (isJust, catMaybes)

import Debug (Debug(..))

import qualified Ast.Ident as Id (Ident)
import Ast.Attr (Attr, attrEqualInOut)
import qualified Ast.Bind as B (empty)
import Ast.Node (Node, getTy, getChildren)
import qualified Ast.Nt as Nt (Nt, new, getIdent, getAttr, getBinding, hasBinding)
import Ast.TermTy (TermTyClass(..))
import Ast.Code (Code)
import qualified Ast.Prod as P (Prod, getNode, isDefined, getProdsByIdent, getArity)

import Env.Env (ElemClass(..), ElemType(EDef))

------------------------------------------------------------------------------------

type Closure = [P.Prod]

data Definition 
	= Def {	nt		:: Nt.Nt,
			code 	:: Code,	-- associated semantic action
			prods	:: [P.Prod]	-- a definition consists of productions
		}

instance Eq Definition where
	(==) d1 d2 =  nt d1 == nt d2

instance Ord Definition where
	compare d1 d2 = compare (nt d1) (nt d2)

instance ElemClass Definition where
	elemShow d = elemShow (nt d)
	elemType _ = EDef
	elemL d = elemL (Nt.getIdent(nt d))
	elemC d = elemC (Nt.getIdent(nt d))

instance Show Definition where
	show d 
		= "\nDef: " ++ debug (nt d) ++
		" @closure->" ++ show (map (\n -> elemShow (P.getNode n)) (calcClosures (prods d))) ++ "\n\n " ++
			(concatMap (\p -> show p ++ "\n\n ") (prods d))

instance TermTyClass Definition where
	getId d = Nt.getIdent(nt d)
	
	isTerm _ = False
	isNonTerm _ = True
		
	getTerm _ = error "\nERROR: getTerm() called with non Term parameter!\n"
	getNonTerm d = nt d

	getAttr d = Nt.getAttr (nt d)
	
	hasBinding d = Nt.hasBinding (nt d)
	getBinding d = Nt.getBinding (nt d)

-- | Smart Constructor
new :: Id.Ident -> [Attr] -> Code -> [P.Prod] -> Definition
new i attrs c ps
	= Def {	nt = (Nt.new i B.empty attrs),
			code = c,
			prods = ps
		}

--
-- Getters
--
getCode :: Definition -> Code
getCode d = code d

-- | Array of Def nodes we have to hook up with
getClosures :: Definition -> Closure
getClosures d = calcClosures (prods d)

getProds :: Definition -> [P.Prod]
getProds d = prods d

--
-- Setters
--
setProds :: Definition -> [P.Prod] -> Definition
setProds d ps = d { prods = ps }

--
-- Other functions
--

-- | getDefForProd. Get definition for an NonTerm Prod.
getDefForProd :: [Definition] -> P.Prod -> Maybe Definition
getDefForProd defs p | isNonTerm p
	= find 
		(\d ->  (getId d) == (getId p))
		(defs)
getDefForProd _ _ = Nothing

-- | dEqualsNode. Compare a definition with a node.
dEqualsNode :: Definition -> Node -> Bool
dEqualsNode (Def { nt = nt1}) n 
	= case getTy n of
		Just ty -> if isNonTerm ty 
					then (((getId ty) == (Nt.getIdent nt1)) && (attrEqualInOut (Nt.getAttr nt1) (getAttr ty)))
					else False
		Nothing -> False

-- | isNodeDefined. Check if a production is defined
isNodeDefined :: [Definition] -> Node -> Bool
isNodeDefined [] _ = False
isNodeDefined defs n
	= isJust 
		(find 
			(\d -> (dEqualsNode d n) || (P.isDefined (prods d) n)) 
			(defs))

-- | Check all productions which are NonTerm productions
calcClosures :: [P.Prod] -> [P.Prod]
calcClosures [] = []
calcClosures prods 
	= (filter
		(\p -> case (getTy (P.getNode p)) of
				(Just ty) -> isNonTerm ty
				Nothing -> False) 
		(prods))

-- | mergeDefs. Merge definitions together
mergeDefs :: [Definition] -> Definition -> Either (Node, Node) [Definition]
mergeDefs [] def = Right [def]
mergeDefs defs def
	= let prods = concatMap (\d -> getProds d) (defs) in
	let clashes = find 
					(\p -> P.isDefined prods (P.getNode p))
					(getProds def)
		in
	case clashes of
		Nothing -> Right (def:defs)
		Just p -> Left (P.getNode (head (P.getProdsByIdent prods (P.getNode p))), P.getNode p)


-- | getNodeTypes. Return the parameter and result type of a node.
--		Example:  'reg = ADD (reg, reg)' -> Result Type: reg; Parameter Types: [reg, reg]
--				  'reg' -> Result Type: reg; Parameter Types: []
getNodeTypes :: [Definition] -> Node -> Maybe (Nt.Nt, [Nt.Nt])
getNodeTypes [] _ = Nothing
getNodeTypes defs n | isNonTerm n
	= case getNodeReturnType defs n of
		Just ty -> Just (ty, [])
		otherwise -> Nothing
getNodeTypes defs@(d:ds) n
	= case (find (\p -> n == P.getNode p) (getProds d)) of
		Just p -> 
				if (P.getArity p > 0) 
					then case dGetNodesReturnTypes defs (getChildren (P.getNode p)) of
							Just types -> Just (getNonTerm d, types)
							otherwise -> Nothing
					else Just (getNonTerm d, [])
		otherwise -> 
				getNodeTypes ds n

-- | getNodeReturnType.
getNodeReturnType :: [Definition] -> Node -> Maybe Nt.Nt
getNodeReturnType [] _ = Nothing
getNodeReturnType defs n | isNonTerm n
	= case (find (\def -> dEqualsNode def n) (defs)) of
		Just d -> Just (getNonTerm d)
		otherwise -> Nothing
getNodeReturnType (d:ds) n
	= if (P.isDefined (getProds d) n)
		then Just (getNonTerm d)
		else getNodeReturnType ds n

-- | dGetNodesReturnTypes.
dGetNodesReturnTypes :: [Definition] -> [Node] -> Maybe [Nt.Nt]
dGetNodesReturnTypes [] _ = Nothing
dGetNodesReturnTypes _ [] = Nothing
dGetNodesReturnTypes defs nodes
	= let retTypes = map (\n -> getNodeReturnType defs n)(nodes) in
	let justTypes = catMaybes retTypes in
	if (length retTypes == length justTypes)
		then Just justTypes
		else Nothing

