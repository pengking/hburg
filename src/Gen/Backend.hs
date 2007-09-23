-----------------------------------------------------------------------------
-- |
-- Module      :  Backend
-- Copyright   :  Copyright (c) 2007 Igor Boehm - Bytelabs.org. All rights reserved.
-- License     :  BSD-style (see the file LICENSE) 
-- Author      :  Igor Boehm  <igor@bytelabs.org>
--
--
-- This module creates all the necessary 'code' given an AST of definitions
-- from the tree pattern matching language. The emit() function is the main
-- interface to the outside, abstracting away from the business of code generation.
-----------------------------------------------------------------------------

module Gen.Backend (
        -- * Functions
        emit,
    ) where

import Control.Monad.State
import qualified Data.Map as M
import qualified Data.Set as S

import Util (stringFoldr)

import qualified Ast.Ir as Ir (Ir(..), baseRuleMap, linkSet)

import Gen.Emit.Enums (genEnums)
import Gen.Emit.Tile (genTiling)
import Gen.Emit.Eval (genEval)
import Gen.Emit.NodeIface (genNodeInterface)

import Gen.Emit.Class (JavaClass(..))
import Gen.Emit.Java.Class (Java, java)
import qualified Gen.Emit.Java.Method as M (Method, new, setComment, getParams, getName, getRetTy)
import Gen.Emit.Java.Modifier (Modifier(..))
import qualified Gen.Emit.Java.Parameter as Param (getIdent)
import qualified Gen.Emit.Java.Comment as Comment (new)
import qualified Gen.Emit.Java.Constructor as Constructor (new)
import qualified Gen.Emit.Java.Variable as Variable (new)
-----------------------------------------------------------------------------

type ClassName = String
type PackageName = String
type ImportName = String
type NodeKind = String

-- | Generates all the code which is necessary in order to make our code generator work.
emit :: ClassName -> PackageName -> NodeKind -> Ir.Ir -> [Java]
emit cname pkg nkind ir
    = let (ir', enumClasses) = genEnums pkg ir in
    let tileClass = genTiling pkg nkind ir' in
    let evalClass = genEval ir' in
    let nodeInterface
            = genNodeInterface
                    (pkg)
                    (fst                            -- max. amount of children node can have
                        (M.findMax $ Ir.baseRuleMap ir))
                    (not (S.null $ Ir.linkSet ir))
                    nkind                           -- return type of node
        in
    let mapEntryClass
            = evalState
                (do
                    clazz <- get
                    put (setConstructors
                            clazz
                            [ Constructor.new Public "MapEntry" [] ""
                            , Constructor.new Public "MapEntry"
                                ["int c", "RuleEnum r"] "\tthis.cost = c;\n\tthis.rule = r;"])
                    clazz <- get
                    put (setVariables
                            clazz
                            [ Variable.new Public False "int" "cost" ""
                            , Variable.new Public False "RuleEnum" "rule" ""])
                    get)
                (java pkg "MapEntry")
        in
    let codeGenClass
            = evalState
                (do -- Set imports
                    clazz <- get
                    put (setImports
                                clazz
                                [genImport pkg "NT.*" True,
                                 genImport pkg "RuleEnum.*" True,
                                 genImport pkg "NT" False,
                                 genImport pkg "RuleEnum" False,
                                 genImport pkg "MapEntry" False,
                                 genImport "java.util" "EnumSet" False,
                                 "// @USER INCLUDES START",
                                 (show $ Ir.include ir'),
                                 "// @USER INCLUDES END"])
                    -- Set code defined in 'declarations' section
                    clazz <- get
                    put (setUserCode clazz (show $ Ir.declaration ir'))
                    -- Add 'tiling' and 'eval' classes as nested classes
                    clazz <- get
                    put (setNestedClasses clazz [tileClass, evalClass])
                    -- Generate Interface method to the outside world
                    clazz <- get
                    put (setMethods clazz [genEmitFun evalClass])
                    get) 
                (java pkg cname)
        in
    -- Return generated classes
    [   codeGenClass        -- the final code generator class
    ,   mapEntryClass       -- MapEntry class
    ,   nodeInterface]      -- Node interface
    ++  enumClasses         -- Classes holding enumerations
    where
        -- | Generate import statements
        genImport :: PackageName -> ClassName -> Bool -> ImportName
        genImport pkg cname static
            = "import" ++
            (if (static) then " static " else " ") ++
            (if (pkg /= "") then pkg ++ "." else "") ++
            cname ++ ";"

        -- | Create method in our code generator which is public and callable from the outside.
        genEmitFun :: Java -> M.Method
        genEmitFun evalClass
            = let m1 = case (getMethods evalClass) of-- retrieve the entry method for evaluation
                        [] -> error ("\nERROR: Class " ++ getClassName evalClass ++ " has no methods!\n")
                        list -> head list
                in
            -- given the entry method for evaluation, its parameters and return
            -- type, generate the emit method which serves as an entry point
            -- to our code generator
            let m2 = M.new Public True (M.getRetTy m1) "emit" (M.getParams m1) (genBody m1) in
            M.setComment m2 (Comment.new ["emit():", "  Generate Code for AST starting with root node."])
            where
                -- | Method body of emit method.
                genBody :: M.Method -> String
                genBody m
                    = "\t" ++ cname ++ ".Tiling.tile(n);\n" ++
                    (if (M.getRetTy m == "void")
                        then "\t"
                        else "\treturn ") ++
                    cname ++ ".Eval." ++ (M.getName m) ++ 
                    "(" ++
                    (stringFoldr
                        (\x y -> x ++ ", " ++ y)
                        (map (\p -> Param.getIdent p) (M.getParams m))) ++
                    ");"