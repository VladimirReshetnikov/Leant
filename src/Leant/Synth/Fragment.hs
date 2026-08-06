-- | The fragment translator for @:synth@ (SYNTHESIS_PROPOSAL.md, phase 1).
--
-- Translation /into/ the fragment happens on the Lean side: a @run_tac@
-- metaprogram ('serializerProgram') elaborates the goal with
-- @autoImplicit@ and walks the resulting 'Expr', emitting an
-- S-expression over the LJT core connectives.  Everything structural
-- (@->@, @And@\/@Prod@\/@PProd@, @Or@\/@Sum@\/@PSum@, @Iff@, @Not@,
-- @False@\/@Empty@\/@PEmpty@, @True@\/@Unit@\/@PUnit@, non-dependent and
-- sort-quantified foralls) is decomposed.  First-order constructor binders
-- and proper-type applications headed by either such a binder or an unknown
-- Lean constant retain their application spine; term-indexed applications
-- remain opaque.  A non-recursive, non-indexed
-- inductive applied to all of its parameters whose constructor fields
-- are explicit and non-dependent expands into a generalized sum of
-- products (phase 2).  Such inductive occurrences retain their exact family
-- head and ordered parameters when every parameter is a proper type; term-
-- parameterized occurrences keep the established occurrence-local form.
-- Recursive occurrences retain a bounded constructor description for native
-- exact-family introduction in both engines, Exference elimination, or a
-- conservative constructor-premise fallback; every other subterm becomes
-- an opaque atom carried by its pretty-printed spelling, so alpha-equal
-- dependent subformulas compare equal and can be transported (never
-- analyzed).  Each atom or application carries a safety bit: a node built
-- purely from universally quantified variables keeps negative verdicts sound,
-- while an atom mentioning any constant (e.g. @Nat@, @P 3@) downgrades
-- \"provably uninhabited\" to \"no term found within bounds\".
--
-- This module is deliberately Djex-free: it parses the S-expression into
-- 'Frag' and answers refusal/safety questions.  'Leant.Synth.Engine'
-- owns the narrow boundary to the synthesis engine.
module Leant.Synth.Fragment
  ( AppHead (..)
  , Frag (..)
  , Slot (..)
  , GoalSort (..)
  , ParsedGoal (..)
  , ProviderFrag (..)
  , ProviderQuery (..)
  , synthPrelude
  , serializerProgram
  , providerProgram
  , candidateVerificationProgram
  , parseGoalSexp
  , parseProviderSexp
  , fragHasDepth
  , fragProviderMayOpen
  , fragRefusal
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

import Leant.Synth.ProviderCache
  ( ProviderQuery (..)
  , canonicalProviderQuery
  )

-- | The head of a retained type-level application.  Bound type functions
-- remain variables, while Lean constants retain nominal identity without
-- exposing any implementation or constructor structure.
data AppHead
  = AppVariable String
  | AppNominal String
  deriving (Eq, Show)

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
    -- for an ordinary implicit one (the elaborator introduces it)
  | FInst String Frag
    -- ^ A non-dependent instance-implicit term binder.  Djex deliberately
    -- ignores dictionary evidence, while the Lean renderer must still bind a
    -- wildcard at an introduction site.  The display key keeps Djinn
    -- exhaustion conservative because the hidden dictionary can carry data.
  | FVar String         -- ^ opaque type variable (auto-implicit or opened binder)
  | FAtom Bool String   -- ^ opaque atom: safe-for-refutation flag, display key
  | FApp Bool String AppHead [Frag]
    -- ^ A proper-type application whose arguments are themselves types.  The
    -- flag and display key describe the complete Lean expression; the head
    -- records whether it is a bound type function or a rigid Lean constant.
    -- Term-indexed/dependent applications remain 'FAtom'.
  | FParamInd String String [Frag] [(String, [Frag])]
    -- ^ A shareable non-recursive inductive-family occurrence: exact Lean
    -- family head, occurrence display key, ordered proper-type parameters,
    -- and the occurrence-specialized complete constructor inventory.  This
    -- is emitted only when every applied parameter itself inhabits a sort.
  | FInd String [(String, [Frag])]
    -- ^ expanded inductive occurrence (phase 2): display key, then one
    -- entry per constructor (full Lean name, field fragments).  Emitted
    -- only when the serializer saw the complete constructor list with
    -- non-dependent explicit fields, so the node itself never poisons a
    -- refutation; its fields answer for themselves
  | FParamRec Bool String String [Frag] [(String, [Frag])]
    -- ^ A shareable recursive-family occurrence: completeness, exact Lean
    -- family head, occurrence display key, ordered proper-type parameters,
    -- and occurrence-specialized constructors.  Recursive self fields still
    -- use the display key as an opaque knot at this representation boundary.
  | FRec Bool String [Frag] [(String, [Frag])]
    -- ^ recursive (or nested) inductive occurrence.  Djinn treats it as an
    -- opaque atom with the listed constructors as sound introduction
    -- premises.  The flag records whether every Lean constructor was
    -- serialized, followed by the display key and the applied inductive
    -- parameters.  Exference lowers only complete occurrences whose explicit
    -- parameter vector is structurally safe to a nominal recursive datatype;
    -- partial or unsupported occurrences remain introduction-only.  The key
    -- always poisons Djinn refutations.
  | FDepth              -- ^ translator depth bound reached
  deriving (Eq, Show)

-- | One position of the goal's leading binder spine, used to line the
-- rendered candidate's lambda binders up with the Lean goal.
data Slot
  = SlotArrow Frag      -- ^ an arrow; carries the domain fragment
  | SlotAll Bool        -- ^ a quantifier; 'True' when the binder is explicit
  | SlotInst            -- ^ an erased instance binder that Lean must still bind
  deriving (Eq, Show)

data GoalSort = GoalProp | GoalType
  deriving (Eq, Show)

data ParsedGoal = ParsedGoal
  { pgSort :: GoalSort
  , pgProviderQuery :: ProviderQuery
  , pgFrag :: Frag
  , pgPrems :: [(String, Frag)]
    -- ^ library premises the serializer offered (phase-3 vanguard):
    -- curated functions over the goal's recursive inductives,
    -- instantiated at the goal's own element types.  Unfiltered here -
    -- the driver decides which are usable
  }
  deriving (Eq, Show)

-- | One Lean environment value lowered to the synthesis fragment.  The
-- provider name remains the exact fully-qualified Lean spelling; the engine
-- gives it a collision-free private name and the renderer maps that name back
-- before Lean re-elaborates the candidate.
data ProviderFrag
  = ProviderFrag
      { providerLeanName :: String
      , providerTypeFrag :: Frag
      }
  | ProviderFragWithBinders
      { providerLeanName :: String
      , providerTypeFrag :: Frag
      , providerTypeBinderNames :: [String]
        -- ^ Original Lean names for the leading type binders retained as
        -- FAll. Empty spellings mark binders that cannot be addressed by
        -- Lean named-argument syntax. The plain constructor is retained for
        -- caller-owned inventories that have no elaborator metadata.
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
  , "-- Peel every term/type binder and expose the nominal head of a result."
  , "-- Provider discovery uses this only for ranking; failure to find a head"
  , "-- leaves the provider in the lower-priority bounded pool."
  , "partial def resultHead? (e : Expr) : MetaM (Option Name) := do"
  , "  let e \8592 whnfR e.consumeMData"
  , "  match e with"
  , "  | Expr.forallE n dom body bi =>"
  , "    withLocalDecl n bi dom fun fv =>"
  , "      resultHead? (body.instantiate1 fv)"
  , "  | _ => pure e.getAppFn.constName?"
  , ""
  , "-- Type constructors and type families are not term inhabitants."
  , "partial def resultIsSort (e : Expr) : MetaM Bool := do"
  , "  let e \8592 whnfR e.consumeMData"
  , "  match e with"
  , "  | Expr.forallE n dom body bi =>"
  , "    withLocalDecl n bi dom fun fv =>"
  , "      resultIsSort (body.instantiate1 fv)"
  , "  | _ => pure e.isSort"
  , ""
  , "-- A quantified fragment variable may itself be a first-order type"
  , "-- constructor.  Admit only kind arrows whose domains and final result"
  , "-- are universes; Nat \8594 Type and dependent term-indexed families stay"
  , "-- opaque because their argument is a term, not a proper type."
  , "partial def isTypeKind (e : Expr) : MetaM Bool := do"
  , "  let e \8592 whnfR e.consumeMData"
  , "  match e with"
  , "  | Expr.sort _ => pure true"
  , "  | Expr.forallE n dom body bi =>"
  , "    let dom \8592 whnfR dom.consumeMData"
  , "    if !dom.isSort then pure false"
  , "    else withLocalDecl n bi dom fun fv =>"
  , "      isTypeKind (body.instantiate1 fv)"
  , "  | _ => pure false"
  , ""
  , "-- Retain the source binder names corresponding to the leading FAlls"
  , "-- emitted by go. Instance binders erased below are deliberately skipped"
  , "-- so Render can use named Lean arguments without exposing dictionaries."
  , "partial def leadingTypeBinderNames (fuel : Nat) (e : Expr)"
  , "    : MetaM (Array String) := do"
  , "  match fuel with"
  , "  | 0 => pure #[]"
  , "  | Nat.succ fuel => do"
  , "    let e \8592 instantiateMVars e"
  , "    let e \8592 whnfR e.consumeMData"
  , "    match e with"
  , "    | Expr.forallE n t b bi =>"
  , "      let t \8592 whnfR t.consumeMData"
  , "      if b.hasLooseBVars then"
  , "        if \8592 isTypeKind t then"
  , "          withLocalDecl n bi t fun fv => do"
  , "            let rest \8592 leadingTypeBinderNames fuel"
  , "              (b.instantiate1 fv)"
  , "            let spelling := if n.isAnonymous then \"\" else n.toString"
  , "            pure (#[spelling] ++ rest)"
  , "        else pure #[]"
  , "      else if bi.isInstImplicit then"
  , "        leadingTypeBinderNames fuel b"
  , "      else if bi.isExplicit then"
  , "        pure #[]"
  , "      else do"
  , "        if \8592 isTypeKind t then do"
  , "          let rest \8592 leadingTypeBinderNames fuel b"
  , "          let spelling := if n.isAnonymous then \"\" else n.toString"
  , "          pure (#[spelling] ++ rest)"
  , "        else pure #[]"
  , "    | _ => pure #[]"
  , ""
  , "-- Share an inductive family across occurrences only when every applied"
  , "-- parameter is a proper type.  Term parameters and dependent family"
  , "-- arguments keep the established occurrence-local representation."
  , "def allProperTypeParams (args : Array Expr) : MetaM Bool := do"
  , "  for arg in args do"
  , "    let argType \8592 whnfR (\8592 inferType arg)"
  , "    if !argType.isSort then return false"
  , "  pure true"
  , ""
  , "mutual"
  , ""
  , "partial def go (providerMode : Bool) (fuel depth : Nat)"
  , "    (blocked : List String) (e : Expr)"
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
  , "        if \8592 isTypeKind t then"
  , "          withLocalDeclD (Name.mkSimple (\"s\" ++ toString depth)) t"
  , "              fun fv => do"
  , "            let inner \8592 go providerMode fuel (depth + 1) blocked"
  , "              (b.instantiate1 fv)"
  , "            let tag := if bi.isExplicit then \"(all \" else \"(alli \""
  , "            pure (tag ++ esc (\"s\" ++ toString depth) ++ \" \""
  , "              ++ inner ++ \")\")"
  , "        else atomOf e"
  , "      else if bi.isInstImplicit then"
  , "        -- Typeclass evidence is reconstructed by Lean when a value is"
  , "        -- applied, so Djex never consumes it as a term premise. Providers"
  , "        -- erase the binder completely. Goal mode retains a render-only"
  , "        -- marker because Lean lambdas must still bind instance arguments."
  , "        if providerMode then"
  , "          go providerMode fuel depth blocked b"
  , "        else do"
  , "          let instanceType \8592 Meta.ppExpr t"
  , "          let r \8592 go providerMode fuel depth blocked b"
  , "          pure (\"(inst \" ++ esc (toString instanceType) ++ \" \""
  , "            ++ r ++ \")\")"
  , "      else if bi.isExplicit then do"
  , "        let d \8592 go providerMode fuel depth blocked t"
  , "        let r \8592 go providerMode fuel depth blocked b"
  , "        pure (\"(-> \" ++ d ++ \" \" ++ r ++ \")\")"
  , "      else do"
  , "        let properType \8592 isTypeKind t"
  , "        if providerMode && !properType then atomOf e"
  , "        else do"
  , "          -- An unused ordinary implicit type parameter still needs a"
  , "          -- scheme binder so Djex can choose a visible instantiation."
  , "          -- Goal mode retains the historical elaborator-binder model;"
  , "          -- provider mode admits only binders over proper types."
  , "          let r \8592 go providerMode fuel depth blocked b"
  , "          pure (\"(alli \" ++ esc (\"i\" ++ toString depth) ++ \" \""
  , "            ++ r ++ \")\")"
  , "    | _ =>"
  , "      match e.getAppFn with"
  , "      | Expr.const n _ => do"
  , "        let args := e.getAppArgs"
  , "        let bin (tag : String) : MetaM String := do"
  , "          let a \8592 go providerMode fuel depth blocked args[0]!"
  , "          let b \8592 go providerMode fuel depth blocked args[1]!"
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
  , "          let a \8592 go providerMode fuel depth blocked args[0]!"
  , "          let b \8592 go providerMode fuel depth blocked args[1]!"
  , "          pure (\"(prod (-> \" ++ a ++ \" \" ++ b ++ \") (-> \""
  , "            ++ b ++ \" \" ++ a ++ \"))\")"
  , "        else if args.size == 1 && n == ``Not then do"
  , "          let a \8592 go providerMode fuel depth blocked args[0]!"
  , "          pure (\"(-> \" ++ a ++ \" (bot))\")"
  , "        else do"
  , "          match \8592 indOf providerMode fuel depth blocked e with"
  , "          | some s => pure s"
  , "          | none =>"
  , "            match \8592 recOf providerMode fuel depth blocked e with"
  , "            | some s => pure s"
  , "            | none =>"
  , "              match \8592 appOf providerMode fuel depth blocked e with"
  , "              | some s => pure s"
  , "              | none => atomOf e"
  , "      | _ =>"
  , "        match \8592 appOf providerMode fuel depth blocked e with"
  , "        | some s => pure s"
  , "        | none => atomOf e"
  , ""
  , "-- Preserve applications whose head is a bound type function or a rigid"
  , "-- Lean constant, whose result is a type, and whose arguments are all"
  , "-- proper types.  Term indices,"
  , "-- proof arguments, and other dependent applications remain one opaque"
  , "-- atom.  A blocked recursive occurrence also remains an atom so recOf's"
  , "-- constructor-premise knot keeps sharing the exact occurrence key."
  , "partial def appOf (providerMode : Bool) (fuel depth : Nat)"
  , "    (blocked : List String) (e : Expr)"
  , "    : MetaM (Option String) := do"
  , "  let args := e.getAppArgs"
  , "  let resultType \8592 whnfR (\8592 inferType e)"
  , "  if !resultType.isSort || args.isEmpty then pure none"
  , "  else do"
  , "    let pp \8592 Meta.ppExpr e"
  , "    let key := toString pp"
  , "    if blocked.contains key then pure none"
  , "    else do"
  , "      for arg in args do"
  , "        let argType \8592 whnfR (\8592 inferType arg)"
  , "        if !argType.isSort then return none"
  , "      let head? \8592 match e.getAppFn with"
  , "        | Expr.fvar _ => do"
  , "          let headPP \8592 Meta.ppExpr e.getAppFn"
  , "          pure (some (\"(app-variable \" ++ esc (toString headPP) ++ \")\"))"
  , "        | Expr.const n _ =>"
  , "          pure (some (\"(app-nominal \" ++ esc n.toString ++ \")\"))"
  , "        | _ => pure none"
  , "      match head? with"
  , "      | none => pure none"
  , "      | some head => do"
  , "        let safe := e.getUsedConstants.isEmpty && !e.isSort"
  , "        let mut rendered := \"\""
  , "        for arg in args do"
  , "          let argument \8592 go providerMode fuel depth blocked arg"
  , "          rendered := rendered ++ \" \" ++ argument"
  , "        pure (some (\"(app \""
  , "          ++ (if safe then \"safe\" else \"unsafe\") ++ \" \""
  , "          ++ esc key ++ \" \" ++ head ++ rendered ++ \")\"))"
  , ""
  , "-- Phase 2: a non-recursive, non-indexed, non-mutual, non-nested"
  , "-- inductive applied to all of its parameters expands into a"
  , "-- generalized sum of products, provided every constructor field is"
  , "-- explicit and non-dependent.  Proper-type parameter vectors retain"
  , "-- their exact family head for query-wide sharing; term/dependent"
  , "-- parameter vectors keep the occurrence-local ind representation."
  , "partial def indOf (providerMode : Bool) (fuel depth : Nat)"
  , "    (blocked : List String) (e : Expr)"
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
  , "          match \8592 ctorFields providerMode fuel depth blocked ct with"
  , "          | none => return none"
  , "          | some fs =>"
  , "            ctors := ctors ++ \" (ctor \" ++ esc c.toString ++ fs ++ \")\""
  , "        let pp \8592 Meta.ppExpr e"
  , "        let key := toString pp"
  , "        if \8592 allProperTypeParams args then do"
  , "          let mut params := \"\""
  , "          for arg in args do"
  , "            let param \8592 go providerMode fuel depth blocked arg"
  , "            params := params ++ \" \" ++ param"
  , "          pure (some (\"(param-ind \" ++ esc n.toString ++ \" \""
  , "            ++ esc key ++ \" (params\" ++ params ++ \")\""
  , "            ++ ctors ++ \")\"))"
  , "        else"
  , "          pure (some (\"(ind \" ++ esc key ++ ctors ++ \")\"))"
  , "    | _ => pure none"
  , "  | _ => pure none"
  , ""
  , "-- Preserve bounded constructor structure for a recursive (or nested)"
  , "-- inductive.  Djinn consumes these constructors as introduction rules;"
  , "-- Exference may additionally inspect one layer.  Emit only constructors"
  , "-- whose instantiated fields are explicit and"
  , "-- non-dependent, with this occurrence's own key blocked so field"
  , "-- occurrences of the type serialize as the matching atom."
  , "partial def recOf (providerMode : Bool) (fuel depth : Nat)"
  , "    (blocked : List String) (e : Expr)"
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
  , "          let properParams \8592 allProperTypeParams args"
  , "          let mut params := \"\""
  , "          for arg in args do"
  , "            let param \8592 go providerMode fuel depth blocked arg"
  , "            params := params ++ \" \" ++ param"
  , "          let blocked := key :: blocked"
  , "          let mut ctors := \"\""
  , "          let mut found := false"
  , "          let mut complete := true"
  , "          for c in iv.ctors do"
  , "            let ct \8592 inferType (mkAppN (Expr.const c us) args)"
  , "            match \8592 ctorFields providerMode fuel depth blocked ct with"
  , "            | none => complete := false"
  , "            | some fs =>"
  , "              found := true"
  , "              ctors := ctors ++ \" (ctor \" ++ esc c.toString"
  , "                ++ fs ++ \")\""
  , "          if !found then pure none"
  , "          else if properParams then"
  , "            pure (some (\"(param-rec \""
  , "              ++ (if complete then \"complete\" else \"partial\")"
  , "              ++ \" \" ++ esc n.toString ++ \" \" ++ esc key"
  , "              ++ \" (params\" ++ params ++ \")\" ++ ctors ++ \")\"))"
  , "          else pure (some (\"(rec \""
  , "            ++ (if complete then \"complete\" else \"partial\")"
  , "            ++ \" \" ++ esc key ++ \" (params\" ++ params ++ \")\""
  , "            ++ ctors ++ \")\"))"
  , "    | _ => pure none"
  , "  | _ => pure none"
  , ""
  , "partial def ctorFields (providerMode : Bool) (fuel depth : Nat)"
  , "    (blocked : List String) (t : Expr)"
  , "    : MetaM (Option String) := do"
  , "  let t \8592 whnfR t"
  , "  match t with"
  , "  | Expr.forallE _ dom body bi =>"
  , "    if body.hasLooseBVars || !bi.isExplicit then pure none"
  , "    else do"
  , "      let d \8592 go providerMode fuel depth blocked dom"
  , "      match \8592 ctorFields providerMode fuel depth blocked body with"
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
  , "              let s \8592 go false 100 0 [] ty"
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
  , "    let s \8592 LeantSynth.go false 100 0 [] tgt"
  , "    let prems \8592 LeantSynth.premSpine 100 0 #[] tgt"
  , "    let roots := tgt.getUsedConstants.toList.map Name.getRoot"
  , "    let rootText := String.intercalate \" \" (roots.map fun n =>"
  , "      LeantSynth.esc n.toString)"
  , "    let head \8592 LeantSynth.resultHead? tgt"
  , "    let headText := match head with"
  , "      | some n => \"(head \" ++ LeantSynth.esc n.toString ++ \")\""
  , "      | none => \"(head)\""
  , "    logInfo (\"(goal \" ++ (if isP then \"prop\" else \"type\")"
  , "      ++ \" (query (roots \" ++ rootText ++ \") \" ++ headText"
  , "      ++ \") \" ++ s ++ prems ++ \")\")"
  , "  sorry"
  ]

-- | Discover a bounded foreign-value inventory for Djinn and Exference.
-- Scanning the
-- full Lean environment is cheap compared with serializing all of it, but a
-- large imported environment can contain over one hundred thousand
-- declarations.  The Lean side therefore retains only declarations whose
-- root namespace occurs in the target (plus exact session declarations),
-- ranks exact result-head matches first, demotes conventional implementation
-- workers without excluding them, serializes at most 80 providers, and leaves
-- final admissibility to the Haskell fragment parser and Lean's own candidate
-- verification.  Exact session declarations bypass the worker-name heuristic.
-- The already-elaborated serializer query is the complete goal-dependent
-- input; provider discovery does not elaborate the raw goal a second time.
providerProgram :: [String] -> ProviderQuery -> String
providerProgram sessionNames query = unlines
  [ "open Lean Meta Elab Command in"
  , "set_option linter.unusedVariables false in"
  , "run_cmd do"
  , "  Lean.Elab.Command.liftTermElabM do"
  , "    let env \8592 getEnv"
  , "    let roots : List String := ["
      ++ intercalate ", " (map leanString (providerQueryRoots query)) ++ "]"
  , "    let targetHead : Option String := "
      ++ maybe "none" (("some " ++) . leanString)
        (providerQueryResultHead query)
  , "    let sessions : List String := ["
      ++ intercalate ", " (map leanString sessionNames) ++ "]"
  , "    let aux : List String :="
  , "      [\"rec\", \"recOn\", \"casesOn\", \"brecOn\", \"binductionOn\","
  , "       \"below\", \"ibelow\", \"noConfusion\", \"noConfusionType\","
  , "       \"ctorElim\", \"ctorElimType\", \"ctorIdx\", \"sizeOf_spec\","
  , "       \"injEq\", \"inj\", \"eq_def\", \"decEq\"]"
  , "    let keep (n : Name) : Bool :="
  , "      !n.isInternalDetail &&"
  , "      !n.components.any fun c => match c with"
  , "        | .str _ s => s.startsWith \"it!\" || aux.contains s"
  , "        | _ => false"
  , "    let implementationWorker (n : Name) : Bool :="
  , "      match n with"
  , "      | .str _ s =>"
  , "        s == \"go\" || s == \"loop\""
  , "          || s.endsWith \"TR\" || s.endsWith \"Impl\""
  , "          || s.endsWith \"Aux\""
  , "      | _ => false"
  , "    let names := env.constants.fold (init := #[]) fun a n _ =>"
  , "      if keep n && (roots.contains n.getRoot.toString"
  , "          || sessions.contains n.toString) then a.push n else a"
  , "    let shorter (a b : Name) : Bool :="
  , "      let sa := a.toString"
  , "      let sb := b.toString"
  , "      if sa.length == sb.length then sa < sb else sa.length < sb.length"
  , "    let sorted := names.qsort shorter"
  , "    let sessionCandidates := sorted.toList.filter fun n =>"
  , "      sessions.contains n.toString"
  , "    let otherCandidates := sorted.toList.filter fun n =>"
  , "      !sessions.contains n.toString"
  , "    let mut sessionPreferred : Array Name := #[]"
  , "    let mut preferred : Array Name := #[]"
  , "    let mut sessionFallback : Array Name := #[]"
  , "    let mut fallback : Array Name := #[]"
  , "    let mut workerPreferred : Array Name := #[]"
  , "    let mut workerFallback : Array Name := #[]"
  , "    -- Exact session declarations bypass the root-pool scan cap."
  , "    for n in sessionCandidates ++ otherCandidates.take 2048 do"
  , "      match env.find? n with"
  , "      | none => pure ()"
  , "      | some info =>"
  , "        let typeLevel \8592 LeantSynth.resultIsSort info.type"
  , "        if typeLevel then pure () else"
  , "          let head \8592 LeantSynth.resultHead? info.type"
  , "          let exactHead := head.map (fun n => n.toString) == targetHead"
  , "          let session := sessions.contains n.toString"
  , "          if session then"
  , "            if exactHead then"
  , "              sessionPreferred := sessionPreferred.push n"
  , "            else"
  , "              sessionFallback := sessionFallback.push n"
  , "          else if implementationWorker n then"
  , "            if exactHead then"
  , "              workerPreferred := workerPreferred.push n"
  , "            else"
  , "              workerFallback := workerFallback.push n"
  , "          else if exactHead then"
  , "            preferred := preferred.push n"
  , "          else"
  , "            fallback := fallback.push n"
  , "    let chosen := (sessionPreferred.toList ++ preferred.toList"
  , "      ++ sessionFallback.toList ++ fallback.toList"
  , "      ++ workerPreferred.toList ++ workerFallback.toList).take 80"
  , "    let mut body := \"\""
  , "    for n in chosen do"
  , "      match env.find? n with"
  , "      | none => pure ()"
  , "      | some info =>"
  , "        let frag \8592 LeantSynth.go true 80 0 [] info.type"
  , "        let binders \8592 LeantSynth.leadingTypeBinderNames 80 info.type"
  , "        let binderText := String.join"
  , "          (binders.toList.map fun binder =>"
  , "            \" \" ++ LeantSynth.esc binder)"
  , "        body := body ++ \" (provider \" ++ LeantSynth.esc n.toString"
  , "          ++ \" (binders\" ++ binderText ++ \") \" ++ frag ++ \")\""
  , "    logInfo (\"(providers\" ++ body ++ \")\")"
  ]
 where
  leanString s = '"' : concatMap escape s ++ "\""
  escape '"' = "\\\""
  escape '\\' = "\\\\"
  escape c = [c]

-- | Lean command used to verify one rendered synthesis candidate.
-- @noncomputable@ disables executable-code generation without weakening
-- elaboration, universe checking, safety checking, or the kernel type check.
-- It therefore admits opaque and axiom-backed inhabitants without requiring a
-- second backend round trip for every ordinary type-invalid candidate.
candidateVerificationProgram :: String -> String -> String
candidateVerificationProgram goal term =
  "set_option autoImplicit true in noncomputable example : ("
    ++ goal ++ ") := (" ++ term ++ ")"

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

-- | Parse the serializer's @(goal SORT QUERY FRAG)@ message.
parseGoalSexp :: String -> Either String ParsedGoal
parseGoalSexp text = do
  toks <- tokenize text
  case toks of
    TL : TSym "goal" : TSym sort : rest -> do
      gs <- case sort of
        "prop" -> Right GoalProp
        "type" -> Right GoalType
        other -> Left ("unknown goal sort " ++ other)
      (query, afterQuery) <- parseProviderQuery rest
      (frag, rest') <- parseFrag afterQuery
      (prems, rest'') <- parsePrems rest'
      case rest'' of
        [TR] -> Right (ParsedGoal gs query frag prems)
        _ -> Left "trailing tokens in goal translation"
    _ -> Left "malformed goal translation"

parseProviderQuery :: [Tok] -> Either String (ProviderQuery, [Tok])
parseProviderQuery
    (TL : TSym "query" : TL : TSym "roots" : rest) = do
  (roots, afterRoots) <- stringList rest
  case afterRoots of
    TL : TSym "head" : TR : TR : remaining ->
      Right (canonicalProviderQuery roots Nothing, remaining)
    TL : TSym "head" : TStr resultHead : TR : TR : remaining ->
      Right (canonicalProviderQuery roots (Just resultHead), remaining)
    _ -> Left "malformed provider query result head"
 where
  stringList (TR : remaining) = Right ([], remaining)
  stringList (TStr value : remaining) = do
    (values, final) <- stringList remaining
    Right (value : values, final)
  stringList _ = Left "malformed provider query roots"
parseProviderQuery _ = Left "malformed provider query"

-- | Parse the provider inventory emitted by 'providerProgram'.
parseProviderSexp :: String -> Either String [ProviderFrag]
parseProviderSexp text = do
  toks <- tokenize text
  case toks of
    TL : TSym "providers" : rest -> do
      (parsedProviders, rest') <- providers rest
      case rest' of
        [] -> Right parsedProviders
        _ -> Left "trailing tokens in provider translation"
    _ -> Left "malformed provider translation"
 where
  providers (TR : rest) = Right ([], rest)
  providers (TL : TSym "provider" : TStr name : rest) = do
    (binderMetadata, fragTokens) <- providerBinders rest
    (frag, rest') <- parseFrag fragTokens
    case rest' of
      TR : more -> do
        (tailProviders, final) <- providers more
        let provider = case binderMetadata of
              Nothing -> ProviderFrag name frag
              Just names -> ProviderFragWithBinders name frag names
        Right (provider : tailProviders, final)
      _ -> Left "malformed (provider ...)"
  providers _ = Left "malformed provider inventory"

  -- Accept the historical metadata-free form for caller-owned inventories
  -- and old snapshots. New live discovery always emits an aligned binder
  -- list, including an explicit empty list for monomorphic providers.
  providerBinders (TL : TSym "binders" : rest) = do
    (names, remaining) <- binderNames rest
    Right (Just names, remaining)
  providerBinders rest = Right (Nothing, rest)

  binderNames (TR : rest) = Right ([], rest)
  binderNames (TStr name : rest) = do
    (names, remaining) <- binderNames rest
    Right (name : names, remaining)
  binderNames _ = Left "malformed provider binder metadata"

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
      safe <- parseSafety "atom" safety
      Right (FAtom safe key, rest')
    _ -> Left "malformed (atom ...)"
  "app" -> case rest of
    TSym safety : TStr key : headTokens -> do
      safe <- parseSafety "application" safety
      (head', afterHead) <- parseAppHead headTokens
      (arguments, rest') <- parseFrags afterHead
      if null arguments
        then Left "type application has no arguments"
        else Right (FApp safe key head' arguments, rest')
    _ -> Left "malformed (app ...)"
  "all" -> allTag True rest
  "alli" -> allTag False rest
  "inst" -> case rest of
    TStr key : toks -> do
      (body, toks') <- parseFrag toks
      close (FInst key body) toks'
    _ -> Left "malformed (inst ...)"
  "param-ind" -> case rest of
    TStr headName : TStr key : TL : TSym "params" : rest' -> do
      (params, rest'') <- parseFrags rest'
      (ctors, rest''') <- parseCtors rest''
      Right (FParamInd headName key params ctors, rest''')
    _ -> Left "malformed (param-ind ...)"
  "ind" -> case rest of
    TStr key : rest' -> do
      (ctors, rest'') <- parseCtors rest'
      Right (FInd key ctors, rest'')
    _ -> Left "malformed (ind ...)"
  "param-rec" -> case rest of
    TSym inventory : TStr headName : TStr key
        : TL : TSym "params" : rest' -> do
      complete <- parseInventory inventory
      (params, rest'') <- parseFrags rest'
      (ctors, rest''') <- parseCtors rest''
      Right (FParamRec complete headName key params ctors, rest''')
    _ -> Left "malformed (param-rec ...)"
  "rec" -> case rest of
    TSym inventory : TStr key : TL : TSym "params" : rest' -> do
      complete <- parseInventory inventory
      (params, rest'') <- parseFrags rest'
      (ctors, rest''') <- parseCtors rest''
      Right (FRec complete key params ctors, rest''')
    _ -> Left "malformed (rec ...)"
  other -> Left ("unknown fragment tag " ++ other)
 where
  parseSafety context safety = case safety of
    "safe" -> Right True
    "unsafe" -> Right False
    other -> Left ("unknown " ++ context ++ " safety " ++ other)
  parseInventory inventory = case inventory of
    "complete" -> Right True
    "partial" -> Right False
    other -> Left ("unknown recursive inventory " ++ other)
  parseAppHead
      (TL : TSym "app-variable" : TStr name : TR : toks) =
    Right (AppVariable name, toks)
  parseAppHead
      (TL : TSym "app-nominal" : TStr name : TR : toks) =
    Right (AppNominal name, toks)
  parseAppHead _ = Left "malformed type-application head"
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
  parseFrags (TR : toks) = Right ([], toks)
  parseFrags toks = do
    (frag, toks') <- parseFrag toks
    (frags, toks'') <- parseFrags toks'
    Right (frag : frags, toks'')
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

-- | Whether translation exhausted its structural fuel anywhere in a
-- fragment.  A live provider cannot repair missing type structure, so this
-- predicate is shared by refusal and provider-admission logic.
fragHasDepth :: Frag -> Bool
fragHasDepth frag = case frag of
  FArr a b -> fragHasDepth a || fragHasDepth b
  FProd a b -> fragHasDepth a || fragHasDepth b
  FSum a b -> fragHasDepth a || fragHasDepth b
  FAll _ _ b -> fragHasDepth b
  FInst _ b -> fragHasDepth b
  FApp _ _ _ arguments -> any fragHasDepth arguments
  FParamInd _ _ params ctors ->
    any fragHasDepth params || any (any fragHasDepth . snd) ctors
  FInd _ ctors -> any (any fragHasDepth . snd) ctors
  FParamRec _ _ _ params ctors ->
    any fragHasDepth params || any (any fragHasDepth . snd) ctors
  FRec _ _ params ctors ->
    any fragHasDepth params || any (any fragHasDepth . snd) ctors
  FDepth -> True
  _ -> False

-- | Whether a foreign value may open an otherwise atomic goal.  Quantifier
-- prefixes are transparent, but a depth-truncated fragment is never
-- provider-openable: its hidden structure may affect both fitting and kinds.
fragProviderMayOpen :: Frag -> Bool
fragProviderMayOpen frag
  | fragHasDepth frag = False
  | otherwise = case peel frag of
      FAtom{} -> True
      FApp{} -> True
      _ -> False
 where
  peel (FAll _ _ body) = peel body
  peel (FInst _ body) = peel body
  peel body = body

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
  | FApp False key _ _ <- peel frag = Just
      ("the goal is a single opaque type application `" ++ key
       ++ "` \8212 :synth can transport and instantiate retained type "
       ++ "applications, but cannot construct an unknown Lean family")
 | otherwise = Nothing
 where
  peel (FAll _ _ b) = peel b
  peel (FInst _ b) = peel b
  peel f = f

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
    FInst _ b -> go b
    FApp _ _ _ arguments -> concatMap go arguments
    FParamInd _ _ parameters ctors ->
      concatMap go parameters ++ concatMap (concatMap go . snd) ctors
    FInd _ ctors -> concatMap (concatMap go . snd) ctors
    FParamRec _ _ key parameters ctors ->
      key : concatMap go parameters ++ concatMap (concatMap go . snd) ctors
    FRec _ key parameters ctors ->
      key : concatMap go parameters ++ concatMap (concatMap go . snd) ctors
    _ -> []

-- | The goal's leading binder spine (arrows and quantifiers, stopping
-- at the first other connective).  Djinn models quantifiers as implicit
-- polymorphism and its candidates bind only arrows; the renderer weaves
-- anonymous binders for explicit quantifier slots and erased instance slots
-- into the candidate's lambda, while skipping ordinary implicit type binders.
fragSpine :: Frag -> [Slot]
fragSpine (FArr dom body) = SlotArrow dom : fragSpine body
fragSpine (FAll explicit _ body) = SlotAll explicit : fragSpine body
fragSpine (FInst _ body) = SlotInst : fragSpine body
fragSpine _ = []

-- | How many explicit type arguments a value of this type needs before
-- its term arguments (its leading explicit sort-quantifiers).  Used to
-- render applications of quantified hypotheses as @f _ x@: Djinn's
-- instantiation evidence is the bare hypothesis, but Lean's explicit
-- binders demand a placeholder for the elaborator to infer.
leadingTypeArgs :: Frag -> Int
leadingTypeArgs (FAll True _ body) = 1 + leadingTypeArgs body
leadingTypeArgs (FAll False _ body) = leadingTypeArgs body
leadingTypeArgs (FInst _ body) = leadingTypeArgs body
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
    -- A retained type application is one propositional atom here.  A forall
    -- in one of its type arguments is not an exposed logical quantifier.
    FApp{} -> True
    -- A non-recursive family is exposed through its specialized fields; its
    -- parameter vector records nominal identity rather than new connectives.
    FParamInd _ _ _ ctors -> all (all quantFree . snd) ctors
    FInd _ ctors -> all (all quantFree . snd) ctors
    FParamRec _ _ _ params ctors ->
      all quantFree params && all (all quantFree . snd) ctors
    FRec _ _ params ctors ->
      all quantFree params && all (all quantFree . snd) ctors
    FAll{} -> False
    FInst{} -> False
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
    FApp{} -> [f]
    FParamInd _ _ _ ctors -> concatMap (concatMap go . snd) ctors
    FInd _ ctors -> concatMap (concatMap go . snd) ctors
    -- Recursive occurrences stay nominal in the classical projection, just
    -- like the established FRec representation.
    FParamRec{} -> []
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
  FInst key b -> FInst key (stripRecCtors b)
  FApp safe key head' arguments ->
    FApp safe key head' (map stripRecCtors arguments)
  FParamInd headName key parameters ctors ->
    FParamInd headName key (map stripRecCtors parameters)
      [(name, map stripRecCtors fields) | (name, fields) <- ctors]
  FInd key ctors ->
    FInd key [(name, map stripRecCtors fields) | (name, fields) <- ctors]
  FParamRec _ _ key _ _ -> FAtom False key
  FRec _ key _ _ -> FAtom False key
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
    FInst key b -> key : go b
    FApp safe key _ arguments ->
      (if safe then [] else [key]) ++ concatMap go arguments
    FParamInd _ _ params ctors ->
      concatMap go params ++ concatMap (concatMap go . snd) ctors
    FInd _ ctors -> concatMap (concatMap go . snd) ctors
    FParamRec _ _ key params ctors ->
      key : concatMap go params ++ concatMap (concatMap go . snd) ctors
    FRec _ key params ctors ->
      key : concatMap go params ++ concatMap (concatMap go . snd) ctors
    FAtom False key -> [key]
    _ -> []
