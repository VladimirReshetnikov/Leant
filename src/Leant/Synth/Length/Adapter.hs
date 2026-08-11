-- | The narrow projection from a callback-accepted Leant candidate handoff to
-- Djex's pure, canonical Length query.
--
-- The source 'CheckedLengthHandoff' has already tied an exact Exference term
-- graph to structural family provenance and a sealed Length problem.  This
-- module immediately projects that problem and returns only the opaque query;
-- verification spelling, renderer state, family bindings, and synthesis
-- session authority are not retained by the result.
--
-- No solver is launched here.  Callback acceptance is not a Lean kernel
-- receipt, raw solver statuses remain heuristic, and a replayed model can
-- establish only a finite-spine counterexample relative to the exact problem
-- and any provider laws named by its receipt.  It does not authorize candidate
-- pruning or a source-level claim that Lean behavior has been disproved.
module Leant.Synth.Length.Adapter
  ( CheckedLengthQuery
  , prepareLengthQueryFromHandoff
  , prepareLengthQueryFromHandoffWithLimits
  ) where

import Language.Haskell.Djex
  ( ExferenceLocal
  , LengthSMTLibLimits
  , LengthSMTLibQuery
  , LengthSMTLibQueryError
  , defaultLengthSMTLibLimits
  , sealLengthSMTLibQuery
  )

import Leant.Synth.Engine
  ( CheckedLengthHandoff
  , checkedLengthHandoffProblem
  )

-- | Query specialization for the exact Exference identities retained by a
-- Leant handoff.  The alias adds no wrapper or projection around Djex's opaque
-- nominal association.
type CheckedLengthQuery = LengthSMTLibQuery ExferenceLocal ExferenceLocal

-- | Project with Djex's conservative query-construction bounds.
prepareLengthQueryFromHandoff
  :: CheckedLengthHandoff
  -> Either LengthSMTLibQueryError CheckedLengthQuery
prepareLengthQueryFromHandoff =
  prepareLengthQueryFromHandoffWithLimits defaultLengthSMTLibLimits

-- | Project with explicit operational construction bounds.  Limits can reject
-- a query but cannot change its fixed QF_LIA semantics or translator schema.
prepareLengthQueryFromHandoffWithLimits
  :: LengthSMTLibLimits
  -> CheckedLengthHandoff
  -> Either LengthSMTLibQueryError CheckedLengthQuery
prepareLengthQueryFromHandoffWithLimits limits handoff =
  let problem = checkedLengthHandoffProblem handoff
  in problem `seq` sealLengthSMTLibQuery limits problem
