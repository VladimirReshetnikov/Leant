-- | The fragment translator for @:synth@ (SYNTHESIS_PROPOSAL.md, phase 1).
--
-- Translation /into/ the fragment happens on the Lean side: a @run_tac@
-- metaprogram ('serializerProgram') elaborates the goal with
-- @autoImplicit@ and walks the resulting 'Expr', emitting an
-- S-expression over the LJT core connectives.  Everything structural
-- (@->@, @And@\/@Prod@\/@PProd@, @Or@\/@Sum@\/@PSum@, @Iff@, @Not@,
-- @False@\/@Empty@\/@PEmpty@, @True@\/@Unit@\/@PUnit@, non-dependent and
-- sort-quantified foralls) is decomposed; a non-recursive, non-indexed
-- inductive applied to all of its parameters whose constructor fields
-- are explicit and non-dependent expands into a generalized sum of
-- products (phase 2); every other subterm becomes an opaque atom
-- carried by its pretty-printed spelling, so alpha-equal dependent
-- subformulas compare equal and can be transported (never analyzed).  Each atom carries a safety bit: an atom built purely from
-- universally quantified variables keeps negative verdicts sound, while
-- an atom mentioning any constant (e.g. @Nat@, @P 3@) downgrades
-- \"provably uninhabited\" to \"no term found within bounds\".
--
-- This module is deliberately Djex-free: it parses the S-expression into
-- 'Frag' and answers refusal/safety questions.  'Leant.Synth.Engine'
-- owns the narrow boundary to the synthesis engine.
module Leant.Synth.Fragment
  ( Frag (..)
  , Slot (..)
  , GoalSort (..)
  , ParsedGoal (..)
  , synthPrelude
  , serializerProgram
  , parseGoalSexp
  , fragRefusal
  , fragHasDepth
  , fragRecKeys
  , fragUnsafeAtoms
  , stripRecCtors
  , fragSpine
  , glivenkoSplit
  , leadingTypeArgs
  , propAtoms
  ) where

import Data.Char (isSpace)
import Data.List (intercalate, nub)

-- | The LJT core fragment.  @Iff@ and @Not@ are already lowered by the
-- serializer (to a pair of arrows and an arrow to 'FBot').
data Frag
  = FArr Frag Frag
  | FProd Frag Frag
  | FSum Frag Frag
  | FTop
  | FBot
  | FAll Bool String Frag
    -- ^ forall over a sort (Type\/Prop\/Sort u); the flag is 'True' for
    -- an explicit binder (needs a lambda in the Lean term) and 'False'
    -- for an implicit\/instance one (the elaborator introduces it)
  | FVar String         -- ^ opaque type variable (auto-implicit or opened binder)
  | FAtom Bool String   -- ^ opaque atom: safe-for-refutation flag, display key
  | FInd String [(String, [Frag])]
    -- ^ expanded inductive occurrence (phase 2): display key, then one
    -- entry per constructor (full Lean name, field fragments).  Emitted
    -- only when the serializer saw the complete constructor list with
    -- non-dependent explicit fields, so the node itself never poisons a
    -- refutation; its fields answer for themselves
  | FRec String [(String, [Frag])]
    -- ^ recursive (or nested) inductive occurrence: an opaque atom for
    -- elimination, but its listed constructors are sound introduction
    -- rules the engine receives as premises.  The constructor list may
    -- be partial (only in-fragment constructors are carried), and the
    -- key always poisons refutations - structure stays hidden
  | FDepth              -- ^ translator depth bound reached
  deriving (Eq, Show)

-- | One position of the goal's leading binder spine, used to line the
-- rendered candidate's lambda binders up with the Lean goal.
data Slot
  = SlotArrow Frag      -- ^ an arrow; carries the domain fragment
  | SlotAll Bool        -- ^ a quantifier; 'True' when the binder is explicit
  deriving (Eq, Show)

data GoalSort = GoalProp | GoalType
  deriving (Eq, Show)

data ParsedGoal = ParsedGoal
  { pgSort :: GoalSort
  , pgFrag :: Frag
  , pgPrems :: [(String, Frag)]
    -- ^ library premises the serializer offered (phase-3 vanguard):
    -- curated functions over the goal's recursive inductives,
    -- instantiated at the goal's own element types.  Unfiltered here -
    -- the driver decides which are usable
  }
  deriving (Eq, Show)

-- | Compiled once into the synthesis environment (session imports plus
-- @Lean@): the goal serializer as ordinary definitions.  @run_tac@ runs
-- interpreted and cannot host @let rec@, so the recursion lives in a
-- compiled @partial def@ that the per-goal command merely calls.  The
-- argument is the library inventory (SYNTHESIS_PROPOSAL.md item G/H):
-- constant names in rating order, best first, spliced in as the
-- premise-offer list.  Names are validated by the caller; anything
-- missing from the environment is skipped at premise time.
synthPrelude :: [String] -> String
synthPrelude inventory = unlines
  [ "namespace LeantSynth"
  , "open Lean Meta"
  , ""
  , "def esc (s : String) : String :="
  , "  \"\\\"\" ++ s.foldl (fun a c =>"
  , "    if c == '\\\"' || c == '\\\\' then a ++ \"\\\\\" ++ toString c"
  , "    else a.push c) \"\" ++ \"\\\"\""
  , ""
  , "def atomOf (e : Expr) : MetaM String := do"
  , "  let safe := e.getUsedConstants.isEmpty && !e.isSort"
  , "  let pp \8592 Meta.ppExpr e"
  , "  pure (\"(atom \" ++ (if safe then \"safe\" else \"unsafe\") ++ \" \""
  , "    ++ esc (toString pp) ++ \")\")"
  , ""
  , "mutual"
  , ""
  , "partial def go (fuel depth : Nat) (blocked : List String) (e : Expr)"
  , "    : MetaM String := do"
  , "  match fuel with"
  , "  | 0 => pure \"(depth)\""
  , "  | Nat.succ fuel => do"
  , "    let e \8592 instantiateMVars e"
  , "    let e \8592 whnfR e.consumeMData"
  , "    if e.isSort then atomOf e"
  , "    else match e with"
  , "    | Expr.fvar _ => do"
  , "      let t \8592 whnfR (\8592 inferType e)"
  , "      if t.isSort then"
  , "        pure (\"(var \" ++ esc (toString (\8592 Meta.ppExpr e)) ++ \")\")"
  , "      else atomOf e"
  , "    | Expr.forallE _ t b bi =>"
  , "      if b.hasLooseBVars then do"
  , "        let ts \8592 whnfR t"
  , "        if ts.isSort then"
  , "          withLocalDeclD (Name.mkSimple (\"s\" ++ toString depth)) t"
  , "              fun fv => do"
  , "            let inner \8592 go fuel (depth + 1) blocked (b.instantiate1 fv)"
  , "            let tag := if bi.isExplicit then \"(all \" else \"(alli \""
  , "            pure (tag ++ esc (\"s\" ++ toString depth) ++ \" \""
  , "              ++ inner ++ \")\")"
  , "        else atomOf e"
  , "      else if bi.isExplicit then do"
  , "        let d \8592 go fuel depth blocked t"
  , "        let r \8592 go fuel depth blocked b"
  , "        pure (\"(-> \" ++ d ++ \" \" ++ r ++ \")\")"
  , "      else do"
  , "        -- an unused implicit binder is introduced by the elaborator,"
  , "        -- so the term neither binds nor applies it"
  , "        let r \8592 go fuel depth blocked b"
  , "        pure (\"(alli \" ++ esc (\"i\" ++ toString depth) ++ \" \""
  , "          ++ r ++ \")\")"
  , "    | _ =>"
  , "      match e.getAppFn with"
  , "      | Expr.const n _ => do"
  , "        let args := e.getAppArgs"
  , "        let bin (tag : String) : MetaM String := do"
  , "          let a \8592 go fuel depth blocked args[0]!"
  , "          let b \8592 go fuel depth blocked args[1]!"
  , "          pure (\"(\" ++ tag ++ \" \" ++ a ++ \" \" ++ b ++ \")\")"
  , "        if args.size == 0 &&"
  , "            (n == ``False || n == ``Empty || n == ``PEmpty) then"
  , "          pure \"(bot)\""
  , "        else if args.size == 0 &&"
  , "            (n == ``True || n == ``Unit || n == ``PUnit) then"
  , "          pure \"(top)\""
  , "        else if args.size == 2 &&"
  , "            (n == ``And || n == ``Prod || n == ``PProd) then"
  , "          bin \"prod\""
  , "        else if args.size == 2 &&"
  , "            (n == ``Or || n == ``Sum || n == ``PSum) then"
  , "          bin \"sum\""
  , "        else if args.size == 2 && n == ``Iff then do"
  , "          let a \8592 go fuel depth blocked args[0]!"
  , "          let b \8592 go fuel depth blocked args[1]!"
  , "          pure (\"(prod (-> \" ++ a ++ \" \" ++ b ++ \") (-> \""
  , "            ++ b ++ \" \" ++ a ++ \"))\")"
  , "        else if args.size == 1 && n == ``Not then do"
  , "          let a \8592 go fuel depth blocked args[0]!"
  , "          pure (\"(-> \" ++ a ++ \" (bot))\")"
  , "        else do"
  , "          match \8592 indOf fuel depth blocked e with"
  , "          | some s => pure s"
  , "          | none =>"
  , "            match \8592 recOf fuel depth blocked e with"
  , "            | some s => pure s"
  , "            | none => atomOf e"
  , "      | _ => atomOf e"
  , ""
  , "-- Phase 2: a non-recursive, non-indexed, non-mutual, non-nested"
  , "-- inductive applied to all of its parameters expands into a"
  , "-- generalized sum of products, provided every constructor field is"
  , "-- explicit and non-dependent; anything else falls back to an atom."
  , "partial def indOf (fuel depth : Nat) (blocked : List String) (e : Expr)"
  , "    : MetaM (Option String) := do"
  , "  match e.getAppFn with"
  , "  | Expr.const n us =>"
  , "    match (\8592 getEnv).find? n with"
  , "    | some (ConstantInfo.inductInfo iv) =>"
  , "      if iv.numIndices != 0 || iv.isRec || iv.isNested"
  , "          || iv.isUnsafe || iv.all.length != 1"
  , "          || e.getAppNumArgs != iv.numParams then"
  , "        pure none"
  , "      else do"
  , "        let args := e.getAppArgs"
  , "        let mut ctors := \"\""
  , "        for c in iv.ctors do"
  , "          let ct \8592 inferType (mkAppN (Expr.const c us) args)"
  , "          match \8592 ctorFields fuel depth blocked ct with"
  , "          | none => return none"
  , "          | some fs =>"
  , "            ctors := ctors ++ \" (ctor \" ++ esc c.toString ++ fs ++ \")\""
  , "        let pp \8592 Meta.ppExpr e"
  , "        pure (some (\"(ind \" ++ esc (toString pp) ++ ctors ++ \")\"))"
  , "    | _ => pure none"
  , "  | _ => pure none"
  , ""
  , "-- A recursive (or nested) inductive stays an opaque atom for"
  , "-- elimination, but its constructors are still sound introduction"
  , "-- rules: emit the ones whose instantiated fields are explicit and"
  , "-- non-dependent, with this occurrence's own key blocked so field"
  , "-- occurrences of the type serialize as the matching atom."
  , "partial def recOf (fuel depth : Nat) (blocked : List String) (e : Expr)"
  , "    : MetaM (Option String) := do"
  , "  match e.getAppFn with"
  , "  | Expr.const n us =>"
  , "    match (\8592 getEnv).find? n with"
  , "    | some (ConstantInfo.inductInfo iv) =>"
  , "      if iv.numIndices != 0 || !(iv.isRec || iv.isNested)"
  , "          || iv.isUnsafe || iv.all.length != 1"
  , "          || e.getAppNumArgs != iv.numParams then"
  , "        pure none"
  , "      else do"
  , "        let pp \8592 Meta.ppExpr e"
  , "        let key := toString pp"
  , "        if blocked.contains key then pure none"
  , "        else do"
  , "          let args := e.getAppArgs"
  , "          let blocked := key :: blocked"
  , "          let mut ctors := \"\""
  , "          let mut found := false"
  , "          for c in iv.ctors do"
  , "            let ct \8592 inferType (mkAppN (Expr.const c us) args)"
  , "            match \8592 ctorFields fuel depth blocked ct with"
  , "            | none => pure ()"
  , "            | some fs =>"
  , "              found := true"
  , "              ctors := ctors ++ \" (ctor \" ++ esc c.toString"
  , "                ++ fs ++ \")\""
  , "          if !found then pure none"
  , "          else pure (some (\"(rec \" ++ esc key ++ ctors ++ \")\"))"
  , "    | _ => pure none"
  , "  | _ => pure none"
  , ""
  , "partial def ctorFields (fuel depth : Nat) (blocked : List String)"
  , "    (t : Expr)"
  , "    : MetaM (Option String) := do"
  , "  let t \8592 whnfR t"
  , "  match t with"
  , "  | Expr.forallE _ dom body bi =>"
  , "    if body.hasLooseBVars || !bi.isExplicit then pure none"
  , "    else do"
  , "      let d \8592 go fuel depth blocked dom"
  , "      match \8592 ctorFields fuel depth blocked body with"
  , "      | none => pure none"
  , "      | some rest => pure (some (\" \" ++ d ++ rest))"
  , "  | _ => pure (some \"\")"
  , ""
  , "end"
  , ""
  , "-- Phase-3 vanguard: library premises.  A goal that mentions a"
  , "-- recursive inductive brings rated library functions with it,"
  , "-- instantiated at the goal's own element types (\"recursion via"
  , "-- library reuse\", SYNTHESIS_PROPOSAL.md \167 4).  Offers only - the"
  , "-- driver filters them and the backend verifies every candidate, so"
  , "-- a useless premise costs search time, never soundness."
  , ""
  , "def libInventory : List Name :="
  , case inventory of
      [] -> "  []"
      _ -> "  [ " ++ intercalate "\n  , "
        [ "`" ++ name | name <- inventory ] ++ " ]"
  , ""
  , "-- How many leading type parameters an inventory entry takes: its"
  , "-- leading sort-typed binders, the ones the offers instantiate."
  , "def invArity : Expr \8594 Nat"
  , "  | Expr.forallE _ t b _ =>"
  , "    if t.isSort then 1 + invArity b else 0"
  , "  | _ => 0"
  , ""
  , "-- All assignments of `arity` type parameters drawn from `tys`."
  , "def assignments : Nat \8594 List Expr \8594 List (List Expr)"
  , "  | 0, _ => [[]]"
  , "  | Nat.succ k, tys =>"
  , "    (assignments k tys).foldr"
  , "      (fun rest acc =>"
  , "        tys.foldr (fun t acc2 => (t :: rest) :: acc2) acc)"
  , "      []"
  , ""
  , "-- Recursive-inductive occurrences reachable without crossing a"
  , "-- binder (an occurrence under a nested quantifier could mention its"
  , "-- bound variable, which no top-level premise may reference)."
  , "partial def collectSafe (fuel : Nat) (e : Expr)"
  , "    : MetaM (Array Expr) := do"
  , "  match fuel with"
  , "  | 0 => pure #[]"
  , "  | Nat.succ fuel => do"
  , "    let e \8592 whnfR e.consumeMData"
  , "    match e with"
  , "    | Expr.forallE _ t b _ =>"
  , "      if b.hasLooseBVars then pure #[]"
  , "      else pure ((\8592 collectSafe fuel t) ++ (\8592 collectSafe fuel b))"
  , "    | _ =>"
  , "      match e.getAppFn with"
  , "      | Expr.const n _ => do"
  , "        let mut acc := #[]"
  , "        if let some (ConstantInfo.inductInfo iv) :="
  , "            (\8592 getEnv).find? n then"
  , "          if iv.numIndices == 0 && (iv.isRec || iv.isNested)"
  , "              && !iv.isUnsafe && iv.all.length == 1"
  , "              && e.getAppNumArgs == iv.numParams then"
  , "            acc := acc.push e"
  , "        for a in e.getAppArgs do"
  , "          acc := acc ++ (\8592 collectSafe fuel a)"
  , "        pure acc"
  , "      | _ => pure #[]"
  , ""
  , "-- Substitute the leading type parameters of a constant's type."
  , "def instHead : Nat \8594 Expr \8594 List Expr \8594 Option Expr"
  , "  | 0, t, _ => some t"
  , "  | Nat.succ k, Expr.forallE _ _ b _, a :: as =>"
  , "    instHead k (b.instantiate1 a) as"
  , "  | _, _, _ => none"
  , ""
  , "-- Instantiate the table's functions at the goal's own types and"
  , "-- serialize each instantiated type through `go`, so premise atoms"
  , "-- share the goal's display keys.  The instantiation is syntactic"
  , "-- (fresh level metavariables, direct substitution, no unification):"
  , "-- an auto-implicit goal variable lives at a rigid `Sort u` that a"
  , "-- typechecked instantiation could never meet, yet the candidate"
  , "-- that uses the premise re-elaborates against the pretty-printed"
  , "-- goal, where auto-implicits are flexible again.  Verification is"
  , "-- the arbiter; an unusable offer just fails there."
  , "def mkPremises (occs : Array Expr) : MetaM String := do"
  , "  let mut okeys : List String := []"
  , "  let mut uniq : List Expr := []"
  , "  for o in occs do"
  , "    let k := toString (\8592 Meta.ppExpr o)"
  , "    if !okeys.contains k then"
  , "      okeys := okeys ++ [k]"
  , "      uniq := uniq ++ [o]"
  , "  -- instantiation candidates: the goal's own type variables (the"
  , "  -- sort-typed locals - auto-implicits arrive as free fvars, spine"
  , "  -- binders as the s-locals premSpine introduced), then the"
  , "  -- occurrences' element types"
  , "  let mut tkeys : List String := []"
  , "  let mut tys : List Expr := []"
  , "  for fvarId in (\8592 getLCtx).getFVarIds do"
  , "    let d \8592 fvarId.getDecl"
  , "    if !d.isImplementationDetail then"
  , "      let t \8592 whnfR d.type"
  , "      if t.isSort then"
  , "        let k := toString (\8592 Meta.ppExpr (Expr.fvar fvarId))"
  , "        if !tkeys.contains k && tkeys.length < 5 then"
  , "          tkeys := tkeys ++ [k]"
  , "          tys := tys ++ [Expr.fvar fvarId]"
  , "  for o in uniq do"
  , "    for a in o.getAppArgs do"
  , "      let k := toString (\8592 Meta.ppExpr a)"
  , "      if !tkeys.contains k && tkeys.length < 5 then"
  , "        tkeys := tkeys ++ [k]"
  , "        tys := tys ++ [a]"
  , "  let env \8592 getEnv"
  , "  let heads := uniq.map (fun o => o.getAppFn.constName!)"
  , "  let mut out := \"\""
  , "  for fn in libInventory do"
  , "    if let some info := env.find? fn then"
  , "      let arity := invArity info.type"
  , "      -- an entry fires when its type mentions one of the goal's"
  , "      -- recursive inductives; the driver's filter then insists the"
  , "      -- instantiated type mentions no inductive the goal lacks"
  , "      if arity \8804 3"
  , "          && info.type.getUsedConstants.any"
  , "               (fun n => heads.contains n) then"
  , "        for asg in assignments arity tys do"
  , "          try"
  , "            let us \8592 Meta.mkFreshLevelMVars info.numLevelParams"
  , "            let ty0 := info.instantiateTypeLevelParams us"
  , "            if let some ty := instHead arity ty0 asg then"
  , "              let s \8592 go 100 0 [] ty"
  , "              out := out ++ \" (prem \" ++ esc fn.toString"
  , "                ++ \" \" ++ s ++ \")\""
  , "          catch _ => pure ()"
  , "  pure out"
  , ""
  , "-- Walk the goal's leading spine exactly as `go` does (same binder"
  , "-- names, same depth counter, so premise types and the goal agree on"
  , "-- variable spellings and occurrence keys), collecting binder-free"
  , "-- occurrences from the domains, then emit the premise offers."
  , "partial def premSpine (fuel depth : Nat) (acc : Array Expr)"
  , "    (e : Expr) : MetaM String := do"
  , "  match fuel with"
  , "  | 0 => mkPremises acc"
  , "  | Nat.succ fuel => do"
  , "    let e \8592 instantiateMVars e"
  , "    let e \8592 whnfR e.consumeMData"
  , "    match e with"
  , "    | Expr.forallE _ t b _ =>"
  , "      if b.hasLooseBVars then do"
  , "        let ts \8592 whnfR t"
  , "        if ts.isSort then"
  , "          withLocalDeclD (Name.mkSimple (\"s\" ++ toString depth)) t"
  , "              fun fv =>"
  , "            premSpine fuel (depth + 1) acc (b.instantiate1 fv)"
  , "        else mkPremises acc"
  , "      else do"
  , "        let acc := acc ++ (\8592 collectSafe fuel t)"
  , "        premSpine fuel depth acc b"
  , "    | _ => do"
  , "      let acc := acc ++ (\8592 collectSafe fuel e)"
  , "      mkPremises acc"
  , ""
  , "end LeantSynth"
  ]

-- | The per-goal Lean command run in the synthesis environment.  The
-- goal text is spliced verbatim between parentheses; elaboration errors
-- surface as ordinary error messages and become the honest refusal.  The
-- trailing @sorry@ closes the example; its sorry entry is ignored by the
-- caller.
serializerProgram :: String -> String
serializerProgram goal = unlines
  [ "open Lean Meta Elab Tactic in"
  , "set_option autoImplicit true in"
  , "set_option linter.unusedVariables false in"
  , "example : (" ++ goal ++ ") := by"
  , "  run_tac withMainContext do"
  , "    let tgt \8592 getMainTarget"
  , "    let isP \8592 Meta.isProp tgt"
  , "    let s \8592 LeantSynth.go 100 0 [] tgt"
  , "    let prems \8592 LeantSynth.premSpine 100 0 #[] tgt"
  , "    logInfo (\"(goal \" ++ (if isP then \"prop\" else \"type\")"
  , "      ++ \" \" ++ s ++ prems ++ \")\")"
  , "  sorry"
  ]

-- S-expression parsing ------------------------------------------------------

data Tok = TL | TR | TSym String | TStr String
  deriving (Eq, Show)

tokenize :: String -> Either String [Tok]
tokenize [] = Right []
tokenize (c : rest)
  | isSpace c = tokenize rest
  | c == '(' = (TL :) <$> tokenize rest
  | c == ')' = (TR :) <$> tokenize rest
  | c == '"' = do
      (lit, rest') <- str rest
      (TStr lit :) <$> tokenize rest'
  | otherwise =
      let (word, rest') = break (\x -> isSpace x || x `elem` "()\"") (c : rest)
      in (TSym word :) <$> tokenize rest'
 where
  str ('\\' : x : xs) = do
    (a, b) <- str xs
    pure (x : a, b)
  str ('"' : xs) = pure ("", xs)
  str (x : xs) = do
    (a, b) <- str xs
    pure (x : a, b)
  str [] = Left "unterminated string in goal translation"

-- | Parse the serializer's @(goal SORT FRAG)@ message.
parseGoalSexp :: String -> Either String ParsedGoal
parseGoalSexp text = do
  toks <- tokenize text
  case toks of
    TL : TSym "goal" : TSym sort : rest -> do
      gs <- case sort of
        "prop" -> Right GoalProp
        "type" -> Right GoalType
        other -> Left ("unknown goal sort " ++ other)
      (frag, rest') <- parseFrag rest
      (prems, rest'') <- parsePrems rest'
      case rest'' of
        [TR] -> Right (ParsedGoal gs frag prems)
        _ -> Left "trailing tokens in goal translation"
    _ -> Left "malformed goal translation"

parseFrag :: [Tok] -> Either String (Frag, [Tok])
parseFrag (TL : TSym tag : rest) = case tag of
  "->" -> binary FArr rest
  "prod" -> binary FProd rest
  "sum" -> binary FSum rest
  "top" -> nullary FTop rest
  "bot" -> nullary FBot rest
  "depth" -> nullary FDepth rest
  "var" -> case rest of
    TStr name : TR : rest' -> Right (FVar name, rest')
    _ -> Left "malformed (var ...)"
  "atom" -> case rest of
    TSym safety : TStr key : TR : rest' -> do
      safe <- case safety of
        "safe" -> Right True
        "unsafe" -> Right False
        other -> Left ("unknown atom safety " ++ other)
      Right (FAtom safe key, rest')
    _ -> Left "malformed (atom ...)"
  "all" -> allTag True rest
  "alli" -> allTag False rest
  "ind" -> case rest of
    TStr key : rest' -> do
      (ctors, rest'') <- parseCtors rest'
      Right (FInd key ctors, rest'')
    _ -> Left "malformed (ind ...)"
  "rec" -> case rest of
    TStr key : rest' -> do
      (ctors, rest'') <- parseCtors rest'
      Right (FRec key ctors, rest'')
    _ -> Left "malformed (rec ...)"
  other -> Left ("unknown fragment tag " ++ other)
 where
  parseCtors (TR : toks) = Right ([], toks)
  parseCtors (TL : TSym "ctor" : TStr name : toks) = do
    (fields, toks') <- parseFields toks
    (rest', toks'') <- parseCtors toks'
    Right ((name, fields) : rest', toks'')
  parseCtors _ = Left "malformed (ctor ...)"
  parseFields (TR : toks) = Right ([], toks)
  parseFields toks = do
    (field, toks') <- parseFrag toks
    (fields, toks'') <- parseFields toks'
    Right (field : fields, toks'')
  binary ctor toks = do
    (a, toks') <- parseFrag toks
    (b, toks'') <- parseFrag toks'
    close (ctor a b) toks''
  nullary value toks = close value toks
  allTag explicit toks = case toks of
    TStr name : toks' -> do
      (body, toks'') <- parseFrag toks'
      close (FAll explicit name body) toks''
    _ -> Left "malformed (all ...)"
  close value (TR : toks) = Right (value, toks)
  close _ _ = Left "expected ) in goal translation"
parseFrag _ = Left "expected ( in goal translation"

-- | Parse the serializer's trailing @(prem "name" FRAG)@ entries (library
-- premises); absent entries parse as the empty list, so the format stays
-- backward compatible.
parsePrems :: [Tok] -> Either String ([(String, Frag)], [Tok])
parsePrems (TL : TSym "prem" : TStr name : toks) = do
  (frag, toks') <- parseFrag toks
  case toks' of
    TR : toks'' -> do
      (rest, toks''') <- parsePrems toks''
      Right ((name, frag) : rest, toks''')
    _ -> Left "expected ) in premise"
parsePrems toks = Right ([], toks)

-- Fragment analysis ---------------------------------------------------------

-- | An honest refusal, when the goal offers the engine nothing structural
-- to work with, with the reason.
fragRefusal :: Frag -> Maybe String
fragRefusal frag
  | fragHasDepth frag = Just
      "the goal exceeds the translator's depth bound"
  | FAtom _ key <- peel frag = Just
      ("the goal is a single opaque atom `" ++ key
       ++ "` \8212 :synth handles \8594/\215/\8853/\8704/\8869/\8868 over \
          \opaque variables; dependent or non-propositional structure is \
          \transported, never analyzed")
  | otherwise = Nothing
 where
  peel (FAll _ _ b) = peel b
  peel f = f

-- | Whether the translator's depth bound fired anywhere in the fragment.
fragHasDepth :: Frag -> Bool
fragHasDepth f = case f of
  FArr a b -> fragHasDepth a || fragHasDepth b
  FProd a b -> fragHasDepth a || fragHasDepth b
  FSum a b -> fragHasDepth a || fragHasDepth b
  FAll _ _ b -> fragHasDepth b
  FInd _ ctors -> any (any fragHasDepth . snd) ctors
  FRec _ ctors -> any (any fragHasDepth . snd) ctors
  FDepth -> True
  _ -> False

-- | Display keys of the recursive-inductive occurrences.  Used to keep
-- library premises honest: a premise whose type mentions a recursive
-- inductive the goal itself never mentions would drag a fresh opaque
-- atom (and its constructor premises) into every search.
fragRecKeys :: Frag -> [String]
fragRecKeys = nub . go
 where
  go f = case f of
    FArr a b -> go a ++ go b
    FProd a b -> go a ++ go b
    FSum a b -> go a ++ go b
    FAll _ _ b -> go b
    FInd _ ctors -> concatMap (concatMap go . snd) ctors
    FRec key ctors -> key : concatMap (concatMap go . snd) ctors
    _ -> []

-- | The goal's leading binder spine (arrows and quantifiers, stopping
-- at the first other connective).  Djinn models quantifiers as implicit
-- polymorphism and its candidates bind only arrows; the renderer weaves
-- anonymous binders for explicit quantifier slots into the candidate's
-- lambda, and skips implicit ones (Lean introduces those itself).
fragSpine :: Frag -> [Slot]
fragSpine (FArr dom body) = SlotArrow dom : fragSpine body
fragSpine (FAll explicit _ body) = SlotAll explicit : fragSpine body
fragSpine _ = []

-- | How many explicit type arguments a value of this type needs before
-- its term arguments (its leading explicit sort-quantifiers).  Used to
-- render applications of quantified hypotheses as @f _ x@: Djinn's
-- instantiation evidence is the bare hypothesis, but Lean's explicit
-- binders demand a placeholder for the elaborator to infer.
leadingTypeArgs :: Frag -> Int
leadingTypeArgs (FAll True _ body) = 1 + leadingTypeArgs body
leadingTypeArgs (FAll False _ body) = leadingTypeArgs body
leadingTypeArgs _ = 0

-- | Split a goal into its leading quantifier prefix and a
-- quantifier-free body, when it has that shape.  This is the fragment
-- where the Glivenko classical fallback is complete: for propositional
-- @body@ (the prefix variables are opaque atoms to the engine either
-- way), @body@ is classically provable exactly when @\172\172body@ is
-- intuitionistically provable.  Each prefix entry carries the binder's
-- explicitness.
glivenkoSplit :: Frag -> Maybe ([(Bool, String)], Frag)
glivenkoSplit = go []
 where
  go acc (FAll explicit binder body) = go ((explicit, binder) : acc) body
  go acc body
    | quantFree body = Just (reverse acc, body)
    | otherwise = Nothing
  quantFree f = case f of
    FArr a b -> quantFree a && quantFree b
    FProd a b -> quantFree a && quantFree b
    FSum a b -> quantFree a && quantFree b
    FInd _ ctors -> all (all quantFree . snd) ctors
    FRec _ ctors -> all (all quantFree . snd) ctors
    FAll{} -> False
    _ -> True

-- | The distinct atomic subformulas (opaque variables and atoms) of a
-- quantifier-free fragment - the candidates for excluded-middle
-- premises in the classical fallback's case-split presentation.
propAtoms :: Frag -> [Frag]
propAtoms = nub . go
 where
  go f = case f of
    FArr a b -> go a ++ go b
    FProd a b -> go a ++ go b
    FSum a b -> go a ++ go b
    FInd _ ctors -> concatMap (concatMap go . snd) ctors
    FVar _ -> [f]
    FAtom _ _ -> [f]
    _ -> []

-- | Forget the constructor lists of recursive-inductive occurrences,
-- leaving plain opaque atoms.  The library-premise search runs on this
-- form: nil\/cons introduction rules let the engine inhabit every List
-- goal through closed junk terms in endlessly many ways, flooding the
-- candidate window before any proof that uses the goal's own arguments
-- is enumerated.  Without them, a candidate can only reach a
-- recursive-inductive atom through a hypothesis or a library premise -
-- exactly the candidates the library run is for.
stripRecCtors :: Frag -> Frag
stripRecCtors f = case f of
  FArr a b -> FArr (stripRecCtors a) (stripRecCtors b)
  FProd a b -> FProd (stripRecCtors a) (stripRecCtors b)
  FSum a b -> FSum (stripRecCtors a) (stripRecCtors b)
  FAll e n b -> FAll e n (stripRecCtors b)
  FInd key ctors ->
    FInd key [(name, map stripRecCtors fields) | (name, fields) <- ctors]
  FRec key _ -> FAtom False key
  _ -> f

-- | Display keys of atoms that poison a negative verdict (they mention
-- concrete constants whose structure the engine cannot see).
fragUnsafeAtoms :: Frag -> [String]
fragUnsafeAtoms = nub . go
 where
  go f = case f of
    FArr a b -> go a ++ go b
    FProd a b -> go a ++ go b
    FSum a b -> go a ++ go b
    FAll _ _ b -> go b
    FInd _ ctors -> concatMap (concatMap go . snd) ctors
    FRec key ctors -> key : concatMap (concatMap go . snd) ctors
    FAtom False key -> [key]
    _ -> []
