{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE TupleSections #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FunctionalDependencies #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DerivingVia #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE ImplicitParams #-}
{-# LANGUAGE BangPatterns #-}

module Pact.Core.Typed.Eval.Builtin(coreBuiltinRuntime) where

import Data.Text(Text)
import Data.Decimal(roundTo', Decimal)
import Data.Bits
import Data.List.NonEmpty(NonEmpty(..))

import qualified Data.RAList as RAList
import qualified Data.Vector as V
import qualified Data.Primitive.Array as Array
import qualified Data.Text as T
import qualified Data.Map.Strict as Map

import Pact.Core.Builtin
import Pact.Core.Literal
import Pact.Core.Typed.Eval.CEK

applyOne :: CEKRuntime b => ETerm b -> CEKEnv b -> CEKValue b -> EvalT b (CEKValue b)
applyOne body env arg = eval (RAList.cons arg env) body

applyTwo :: CEKRuntime b => ETerm b -> CEKEnv b -> CEKValue b -> CEKValue b -> EvalT b (CEKValue b)
applyTwo body env arg1 arg2 = eval (RAList.cons arg2 (RAList.cons arg1 env)) body

unsafeApplyOne :: CEKRuntime b => CEKValue b -> CEKValue b -> EvalT b (CEKValue b)
unsafeApplyOne (VClosure cn (_:ns) body env) arg = case ns of
  [] -> applyOne body env arg
  _ -> pure (VClosure cn ns body (RAList.cons arg env))
unsafeApplyOne (VNative b) arg = do
  let (BuiltinFn f) = Array.indexArray ?cekBuiltins (fromEnum b)
  f (arg :| [])
unsafeApplyOne _ _ = error "impossible"

unsafeApplyTwo :: CEKRuntime b => CEKValue b -> CEKValue b -> CEKValue b -> EvalT b (CEKValue b)
unsafeApplyTwo (VClosure cn (_:ns) body env) arg1 arg2 = case ns of
  [] -> error "impossible"
  _:ms -> case ms of
    [] -> applyTwo body env arg1 arg2
    _ ->
      let env' = (RAList.cons arg2 (RAList.cons arg1 env))
      in pure (VClosure cn ms body env')
unsafeApplyTwo (VNative b) arg1 arg2 = do
  let (BuiltinFn f) = Array.indexArray ?cekBuiltins (fromEnum b)
  f (arg1 :| [arg2])
unsafeApplyTwo _ _ _ = error "impossible"


-- Todo: runtime error
unaryIntFn :: (Integer -> Integer) -> BuiltinFn b
unaryIntFn op = BuiltinFn \case
  VLiteral (LInteger i) :| [] -> pure (VLiteral (LInteger (op i)))
  _ -> fail "impossible"
{-# INLINE unaryIntFn #-}

unaryDecFn :: (Decimal -> Decimal) -> BuiltinFn b
unaryDecFn op = BuiltinFn \case
  VLiteral (LDecimal i) :| [] -> pure (VLiteral (LDecimal (op i)))
  _ -> fail "impossible"
{-# INLINE unaryDecFn #-}

binaryIntFn :: (Integer -> Integer -> Integer) -> BuiltinFn b
binaryIntFn op = BuiltinFn \case
  VLiteral (LInteger i) :| [VLiteral (LInteger i')] -> pure (VLiteral (LInteger (op i i')))
  _ -> fail "impossible"
{-# INLINE binaryIntFn #-}

binaryDecFn :: (Decimal -> Decimal -> Decimal) -> BuiltinFn b
binaryDecFn op = BuiltinFn \case
  VLiteral (LDecimal i) :| [VLiteral (LDecimal i')] -> pure (VLiteral (LDecimal (op i i')))
  _ -> fail "impossible"
{-# INLINE binaryDecFn #-}

binaryBoolFn :: (Bool -> Bool -> Bool) -> BuiltinFn b
binaryBoolFn op = BuiltinFn \case
  VLiteral (LBool l) :| [VLiteral (LBool r)] -> pure (VLiteral (LBool (op l r)))
  _ -> fail "impossible"
{-# INLINE binaryBoolFn #-}

compareIntFn :: (Integer -> Integer -> Bool) -> BuiltinFn b
compareIntFn op = BuiltinFn \case
  VLiteral (LInteger i) :| [VLiteral (LInteger i')] -> pure (VLiteral (LBool (op i i')))
  _ -> fail "impossible"
{-# INLINE compareIntFn #-}

compareDecFn :: (Decimal -> Decimal -> Bool) -> BuiltinFn b
compareDecFn op = BuiltinFn \case
  VLiteral (LDecimal i) :| [VLiteral (LDecimal i')] -> pure (VLiteral (LBool (op i i')))
  _ -> fail "impossible"
{-# INLINE compareDecFn #-}

compareStrFn :: (Text -> Text -> Bool) -> BuiltinFn b
compareStrFn op = BuiltinFn \case
  VLiteral (LString i) :| [VLiteral (LString i')] -> pure (VLiteral (LBool (op i i')))
  _ -> fail "impossible"
{-# INLINE compareStrFn #-}

roundingFn :: (Rational -> Integer) -> BuiltinFn b
roundingFn op = BuiltinFn \case
  VLiteral (LDecimal i) :| [] -> pure (VLiteral (LInteger (truncate (roundTo' op 0 i))))
  _ -> fail "impossible"
{-# INLINE roundingFn #-}

---------------------------------
-- integer ops
------------------------------
addInt :: BuiltinFn b
addInt = binaryIntFn (+)

subInt :: BuiltinFn b
subInt = binaryIntFn (-)

mulInt :: BuiltinFn b
mulInt = binaryIntFn (*)

divInt :: BuiltinFn b
divInt = binaryIntFn quot

negateInt :: BuiltinFn b
negateInt = unaryIntFn negate

modInt :: BuiltinFn b
modInt = binaryIntFn mod

eqInt :: BuiltinFn b
eqInt = compareIntFn (==)

neqInt :: BuiltinFn b
neqInt = compareIntFn (/=)

gtInt :: BuiltinFn b
gtInt = compareIntFn (>)

ltInt :: BuiltinFn b
ltInt = compareIntFn (<)

geqInt :: BuiltinFn b
geqInt = compareIntFn (>=)

leqInt :: BuiltinFn b
leqInt = compareIntFn (<=)

bitAndInt :: BuiltinFn b
bitAndInt = binaryIntFn (.&.)

bitOrInt :: BuiltinFn b
bitOrInt = binaryIntFn (.|.)

bitFlipInt :: BuiltinFn b
bitFlipInt = unaryIntFn complement

bitXorInt :: BuiltinFn b
bitXorInt = binaryIntFn xor

bitShiftInt :: BuiltinFn b
bitShiftInt = BuiltinFn \case
  VLiteral (LInteger i) :| [VLiteral (LInteger s)] ->
    pure (VLiteral (LInteger (shift i (fromIntegral s))))
  _ -> fail "impossible"

absInt :: BuiltinFn b
absInt = unaryIntFn abs

expInt :: BuiltinFn b
expInt = BuiltinFn \case
  VLiteral (LInteger i) :| [] ->
    pure (VLiteral (LDecimal (f2Dec (exp (fromIntegral i)))))
  _ -> fail "impossible"

lnInt :: BuiltinFn b
lnInt = BuiltinFn \case
  VLiteral (LInteger i) :| [] ->
    pure (VLiteral (LDecimal (f2Dec (log (fromIntegral i)))))
  _ -> fail "impossible"

showInt :: BuiltinFn b
showInt = BuiltinFn \case
  VLiteral (LInteger i) :| [] ->
    pure (VLiteral (LString (T.pack (show i))))
  _ -> fail "impossible"

---------------------------
-- double ops
---------------------------

addDec :: BuiltinFn b
addDec = binaryDecFn (+)

subDec :: BuiltinFn b
subDec = binaryDecFn (-)

mulDec :: BuiltinFn b
mulDec = binaryDecFn (*)

divDec :: BuiltinFn b
divDec = binaryDecFn (/)

negateDec :: BuiltinFn b
negateDec = unaryDecFn negate

absDec :: BuiltinFn b
absDec = unaryDecFn abs

eqDec :: BuiltinFn b
eqDec = compareDecFn (==)

neqDec :: BuiltinFn b
neqDec = compareDecFn (/=)

gtDec :: BuiltinFn b
gtDec = compareDecFn (>)

geqDec :: BuiltinFn b
geqDec = compareDecFn (>=)

ltDec :: BuiltinFn b
ltDec = compareDecFn (<)

leqDec :: BuiltinFn b
leqDec = compareDecFn (<=)

showDec :: BuiltinFn b
showDec = BuiltinFn \case
  VLiteral (LDecimal i) :| [] ->
    pure (VLiteral (LString (T.pack (show i))))
  _ -> fail "impossible"

dec2F :: Decimal -> Double
dec2F = fromRational . toRational

f2Dec :: Double -> Decimal
f2Dec = fromRational . toRational

roundDec, floorDec, ceilingDec :: BuiltinFn b
roundDec = roundingFn round
floorDec = roundingFn floor
ceilingDec = roundingFn ceiling

expDec :: BuiltinFn b
expDec = unaryDecFn (f2Dec . exp . dec2F)

lnDec :: BuiltinFn b
lnDec = unaryDecFn (f2Dec . log . dec2F)

---------------------------
-- bool ops
---------------------------
andBool :: BuiltinFn b
andBool = binaryBoolFn (&&)

orBool :: BuiltinFn b
orBool = binaryBoolFn (||)

notBool :: BuiltinFn b
notBool = BuiltinFn \case
  VLiteral (LBool i) :| [] -> pure (VLiteral (LBool (not i)))
  _ -> fail "impossible"

eqBool :: BuiltinFn b
eqBool = binaryBoolFn (==)

neqBool :: BuiltinFn b
neqBool = binaryBoolFn (/=)

---------------------------
-- string ops
---------------------------
eqStr :: BuiltinFn b
eqStr = compareStrFn (==)

neqStr :: BuiltinFn b
neqStr = compareStrFn (/=)

gtStr :: BuiltinFn b
gtStr = compareStrFn (>)

geqStr :: BuiltinFn b
geqStr = compareStrFn (>=)

ltStr :: BuiltinFn b
ltStr = compareStrFn (<)

leqStr :: BuiltinFn b
leqStr = compareStrFn (<=)

addStr :: BuiltinFn b
addStr =  BuiltinFn \case
  VLiteral (LString i) :| [VLiteral (LString i')] -> pure (VLiteral (LString (i <> i')))
  _ -> fail "impossible"

---------------------------
-- Object ops
---------------------------

eqObj :: BuiltinFn b
eqObj = BuiltinFn \case
  l@VObject{} :| [r@VObject{}] -> pure (VLiteral (LBool (unsafeEqCEKValue l r)))
  _ -> fail "impossible"

neqObj :: BuiltinFn b
neqObj = BuiltinFn \case
  l@VObject{} :| [r@VObject{}] -> pure (VLiteral (LBool (unsafeNeqCEKValue l r)))
  _ -> fail "impossible"


------------------------------
--- conversions + unsafe ops
------------------------------
asBool :: CEKValue b -> EvalT b Bool
asBool (VLiteral (LBool b)) = pure b
asBool _ = fail "impossible"

asString :: CEKValue b -> EvalT b Text
asString (VLiteral (LString b)) = pure b
asString _ = fail "impossible"

unsafeEqLiteral :: Literal -> Literal -> Bool
unsafeEqLiteral (LString i) (LString i') = i == i'
unsafeEqLiteral (LInteger i) (LInteger i') = i == i'
unsafeEqLiteral (LDecimal i) (LDecimal i') = i == i'
unsafeEqLiteral LUnit LUnit = True
unsafeEqLiteral (LBool i) (LBool i') = i == i'
unsafeEqLiteral (LTime i) (LTime i') = i == i'
unsafeEqLiteral _ _ = error "todo: throw invariant failure exception"

-- unsafeNeqLiteral :: Literal -> Literal -> Bool
-- unsafeNeqLiteral a b = not (unsafeEqLiteral a b)

unsafeEqCEKValue :: CEKValue b -> CEKValue b -> Bool
unsafeEqCEKValue (VLiteral l) (VLiteral l') = unsafeEqLiteral l l'
unsafeEqCEKValue (VObject o) (VObject o') = and (Map.intersectionWith unsafeEqCEKValue o o')
unsafeEqCEKValue (VList l) (VList l') =  V.length l == V.length l' &&  and (V.zipWith unsafeEqCEKValue l l')
unsafeEqCEKValue _ _ = error "todo: throw invariant failure exception"

unsafeNeqCEKValue :: CEKValue b -> CEKValue b -> Bool
unsafeNeqCEKValue a b = not (unsafeEqCEKValue a b)

---------------------------
-- list ops
---------------------------
eqList :: BuiltinFn b
eqList = BuiltinFn \case
  l@VList{} :| [r@VList{}] -> pure (VLiteral (LBool (unsafeEqCEKValue l r)))
  _ -> fail "impossible"

neqList :: BuiltinFn b
neqList = BuiltinFn \case
  l@VList{} :| [r@VList{}] -> pure (VLiteral (LBool (unsafeNeqCEKValue l r)))
  _ -> fail "impossible"

addList :: BuiltinFn b
addList = BuiltinFn \case
  VList l :| [VList r] -> pure (VList (l <> r))
  _ -> fail "impossible"

pcShowList :: BuiltinFn b
pcShowList = BuiltinFn \case
  showFn :| [VList l1] -> do
    strli <- traverse ((=<<) asString  . unsafeApplyOne showFn) (V.toList l1)
    let out = "[" <> T.intercalate ", " strli <> "]"
    pure (VLiteral (LString out))
  _ -> fail "impossible"

coreMap :: BuiltinFn b
coreMap = BuiltinFn \case
  fn :| [VList li] -> do
    li' <- traverse (unsafeApplyOne fn) li
    pure (VList li')
  _ -> fail "impossible"

coreFilter :: BuiltinFn b
coreFilter = BuiltinFn \case
  fn :| [VList li] -> do
    let applyOne' arg = unsafeApplyOne fn arg >>= asBool
    li' <- V.filterM applyOne' li
    pure (VList li')
  _ -> fail "impossible"

coreFold :: BuiltinFn b
coreFold = BuiltinFn \case
  fn :| [initElem, VList li] -> do
    out <- V.foldM' (unsafeApplyTwo fn) initElem li
    pure out
  _ -> fail "impossible"

lengthList :: BuiltinFn b
lengthList = BuiltinFn \case
  VList li :| [] -> pure (VLiteral (LInteger (fromIntegral (V.length li))))
  _ -> fail "impossible"

takeList :: BuiltinFn b
takeList = BuiltinFn \case
  VLiteral (LInteger i) :| [VList li] ->
    pure (VList (V.take (fromIntegral i) li))
  _ -> fail "impossible"

dropList :: BuiltinFn b
dropList = BuiltinFn \case
  VLiteral (LInteger i) :| [VList li] ->
    pure (VList (V.drop (fromIntegral i) li))
  _ -> fail "impossible"

coreEnumerate :: BuiltinFn b
coreEnumerate = BuiltinFn \case
  VLiteral (LInteger from) :| [VLiteral (LInteger to)] -> enum' from to
  _ -> fail "impossible"
  where
  toVecList = VList . fmap (VLiteral . LInteger)
  enum' from to
    | to >= from = pure $ toVecList $ V.enumFromN from (fromIntegral (to - from + 1))
    | otherwise = pure $ toVecList $ V.enumFromStepN from (-1) (fromIntegral (from - to + 1))

coreEnumerateStepN :: BuiltinFn b
coreEnumerateStepN = BuiltinFn \case
  VLiteral (LInteger from) :| [VLiteral (LInteger to), VLiteral (LInteger step)] -> enum' from to step
  _ -> fail "impossible"
  where
  toVecList = VList . fmap (VLiteral . LInteger)
  enum' from to step
    | to > from && (step > 0) = pure $ toVecList $ V.enumFromStepN from step (fromIntegral ((to - from + 1) `quot` step))
    | from > to && (step < 0) = pure $ toVecList $ V.enumFromStepN from step (fromIntegral ((from - to + 1) `quot` step))
    | from == to && step == 0 = pure $ toVecList $ V.singleton from
    | otherwise = fail "enumerate outside interval bounds"

coreConcat :: BuiltinFn b
coreConcat = BuiltinFn \case
  VList li :| [] -> do
    li' <- traverse asString li
    pure (VLiteral (LString (T.concat (V.toList li'))))
  _ -> fail "impossible"

-----------------------------------
-- Other Core forms
---------------------------------

coreIf :: BuiltinFn b
coreIf = BuiltinFn \case
  VLiteral (LBool b) :| [VClosure _ _ ibody ienv, VClosure _ _ ebody eenv] ->
    if b then applyOne ibody ienv (VLiteral LUnit) else  applyOne ebody eenv (VLiteral LUnit)
  _ -> fail "impossible"

unimplemented :: BuiltinFn b
unimplemented = BuiltinFn \case
  _ -> fail "unimplemented"

coreBuiltinFn :: CoreBuiltin -> BuiltinFn CoreBuiltin
coreBuiltinFn = \case
  -- IntOps
  AddInt -> addInt
  SubInt -> subInt
  DivInt -> divInt
  MulInt -> mulInt
  NegateInt -> negateInt
  AbsInt -> absInt
  LogBaseInt -> unimplemented
  ModInt -> modInt
  ExpInt -> expInt
  LnInt -> lnInt
  BitAndInt -> bitAndInt
  BitOrInt -> bitOrInt
  BitXorInt ->  bitXorInt
  BitShiftInt -> bitShiftInt
  BitComplementInt -> bitFlipInt
  ShowInt -> showInt
  -- If
  IfElse -> coreIf
  -- Decimal ops
  AddDec -> addDec
  SubDec -> subDec
  DivDec -> divDec
  MulDec -> mulDec
  NegateDec -> negateDec
  AbsDec -> absDec
  RoundDec -> roundDec
  CeilingDec -> ceilingDec
  ExpDec -> expDec
  FloorDec -> floorDec
  LnDec -> lnDec
  LogBaseDec -> unimplemented
  ShowDec -> showDec
  -- Bool Comparisons
  AndBool -> andBool
  OrBool -> orBool
  NotBool -> notBool
  EqBool -> eqBool
  NeqBool -> neqBool
  -- Int Equality
  EqInt -> eqInt
  NeqInt -> neqInt
  GTInt -> gtInt
  GEQInt -> geqInt
  LTInt -> ltInt
  LEQInt -> leqInt
  -- Decimal Equality
  EqDec -> eqDec
  NeqDec -> neqDec
  GTDec -> gtDec
  GEQDec -> geqDec
  LTDec -> ltDec
  LEQDec -> leqDec
  -- String Equality
  EqStr -> eqStr
  NeqStr -> neqStr
  GTStr -> gtStr
  GEQStr -> geqStr
  LTStr -> ltStr
  LEQStr -> leqStr
  -- Object equality
  EqObj -> eqObj
  NeqObj -> neqObj
  -- List Equality
  EqList -> eqList
  NeqList -> neqList
  ShowList -> pcShowList
  -- String Ops
  AddStr -> addStr
  ConcatStr -> coreConcat
  DropStr -> unimplemented
  TakeStr -> unimplemented
  LengthStr -> unimplemented
  ShowStr -> unimplemented
  -- Unit ops
  EqUnit -> unimplemented
  NeqUnit -> unimplemented
  ShowUnit -> unimplemented
  -- ListOps
  AddList -> addList
  DistinctList -> unimplemented
  TakeList -> takeList
  DropList -> dropList
  LengthList -> lengthList
  FilterList -> coreFilter
  ZipList -> unimplemented
  MapList -> coreMap
  FoldList -> coreFold
  Enforce -> unimplemented
  EnforceOne -> unimplemented
  Enumerate -> coreEnumerate
  EnumerateStepN -> coreEnumerateStepN
  Dummy -> unimplemented

coreBuiltinRuntime :: Array.Array (BuiltinFn CoreBuiltin)
coreBuiltinRuntime = Array.arrayFromList (coreBuiltinFn <$> [minBound .. maxBound])
