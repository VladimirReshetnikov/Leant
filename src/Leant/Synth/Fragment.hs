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
-- products (phase 2); recursive occurrences retain a bounded constructor
-- description for the Exference projection, and every other subterm becomes
-- an opaque atom
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
  , ProviderFrag (..)
  , ProviderQuery (..)
  , synthPrelude
  , serializerProgram
  , providerProgram
  , candidateVerificationProgram
  , parseGoalSexp
  , parseProviderSexp
  , fragRefusal
  , fragUnsafeAtoms
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
  deriving (Eq, Show)

data GoalSort = GoalProp | GoalType
  deriving (Eq, Show)

data ParsedGoal = ParsedGoal
  { pgSort :: GoalSort
  , pgProviderQuery :: ProviderQuery
  , pgFrag :: Frag
  }
  deriving (Eq, Show)

-- | One Lean environment value lowered to the synthesis fragment.  The
-- provider name remains the exact fully-qualified Lean spelling; the engine
-- gives it a collision-free private name and the renderer maps that name back
-- before Lean re-elaborates the candidate.
data ProviderFrag = ProviderFrag
  { providerLeanName :: String
  , providerTypeFrag :: Frag
  }
  deriving (Eq, Show)

-- | Compiled once into the synthesis environment (session imports plus
-- @Lean@): the goal serializer as ordinary definitions.  @run_tac@ runs
-- interpreted and cannot host @let rec@, so the recursion lives in a
-- compiled @partial def@ that the per-goal command merely calls.
synthPrelude :: String
synthPrelude = unlines
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
  , "-- Preserve bounded constructor structure for a recursive (or nested)"
  , "-- inductive.  Djinn consumes these constructors as introduction rules;"
  , "-- Exference may additionally inspect one layer.  Emit only constructors"
  , "-- whose instantiated fields are explicit and"
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
  , "          let mut params := \"\""
  , "          for arg in args do"
  , "            let param \8592 go fuel depth blocked arg"
  , "            params := params ++ \" \" ++ param"
  , "          let blocked := key :: blocked"
  , "          let mut ctors := \"\""
  , "          let mut found := false"
  , "          let mut complete := true"
  , "          for c in iv.ctors do"
  , "            let ct \8592 inferType (mkAppN (Expr.const c us) args)"
  , "            match \8592 ctorFields fuel depth blocked ct with"
  , "            | none => complete := false"
  , "            | some fs =>"
  , "              found := true"
  , "              ctors := ctors ++ \" (ctor \" ++ esc c.toString"
  , "                ++ fs ++ \")\""
  , "          if !found then pure none"
  , "          else pure (some (\"(rec \""
  , "            ++ (if complete then \"complete\" else \"partial\")"
  , "            ++ \" \" ++ esc key ++ \" (params\" ++ params ++ \")\""
  , "            ++ ctors ++ \")\"))"
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
  , "    let roots := tgt.getUsedConstants.toList.map Name.getRoot"
  , "    let rootText := String.intercalate \" \" (roots.map fun n =>"
  , "      LeantSynth.esc n.toString)"
  , "    let head \8592 LeantSynth.resultHead? tgt"
  , "    let headText := match head with"
  , "      | some n => \"(head \" ++ LeantSynth.esc n.toString ++ \")\""
  , "      | none => \"(head)\""
  , "    logInfo (\"(goal \" ++ (if isP then \"prop\" else \"type\")"
  , "      ++ \" (query (roots \" ++ rootText ++ \") \" ++ headText"
  , "      ++ \") \" ++ s ++ \")\")"
  , "  sorry"
  ]

-- | Discover a bounded foreign-value inventory for Exference.  Scanning the
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
  , "        let frag \8592 LeantSynth.go 80 0 [] info.type"
  , "        body := body ++ \" (provider \" ++ LeantSynth.esc n.toString"
  , "          ++ \" \" ++ frag ++ \")\""
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
      case rest' of
        [TR] -> Right (ParsedGoal gs query frag)
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
    (frag, rest') <- parseFrag rest
    case rest' of
      TR : more -> do
        (tailProviders, final) <- providers more
        Right (ProviderFrag name frag : tailProviders, final)
      _ -> Left "malformed (provider ...)"
  providers _ = Left "malformed provider inventory"

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
    TSym inventory : TStr key : TL : TSym "params" : rest' -> do
      complete <- case inventory of
        "complete" -> Right True
        "partial" -> Right False
        other -> Left ("unknown recursive inventory " ++ other)
      (params, rest'') <- parseFrags rest'
      (ctors, rest''') <- parseCtors rest''
      Right (FRec complete key params ctors, rest''')
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

-- Fragment analysis ---------------------------------------------------------

-- | An honest refusal, when the goal offers the engine nothing structural
-- to work with, with the reason.
fragRefusal :: Frag -> Maybe String
fragRefusal frag
  | hasDepth frag = Just
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
  hasDepth f = case f of
    FArr a b -> hasDepth a || hasDepth b
    FProd a b -> hasDepth a || hasDepth b
    FSum a b -> hasDepth a || hasDepth b
    FAll _ _ b -> hasDepth b
    FInd _ ctors -> any (any hasDepth . snd) ctors
    FRec _ _ params ctors ->
      any hasDepth params || any (any hasDepth . snd) ctors
    FDepth -> True
    _ -> False

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
    FRec _ _ params ctors ->
      all quantFree params && all (all quantFree . snd) ctors
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
    FRec _ key params ctors ->
      key : concatMap go params ++ concatMap (concatMap go . snd) ctors
    FAtom False key -> [key]
    _ -> []
