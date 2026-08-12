-- | The narrow checked projection from one callback-accepted Leant candidate
-- to Djex's pure, canonical Length query.
--
-- This module first uses "Leant.Synth.Length.Handoff" to tie the exact
-- accepted Exference term graph to structural family provenance and a sealed
-- Length problem, then immediately seals that problem into an opaque query.
-- It never exposes an adapter which promotes an arbitrary checked problem into
-- this Leant staging boundary. Verification spelling, renderer state, family
-- bindings, and synthesis session authority are not retained by the result.
--
-- No solver is launched here.  Callback acceptance is not a Lean kernel
-- receipt, raw solver statuses remain heuristic, and a replayed model can
-- establish only a finite-spine counterexample relative to the exact problem
-- and any provider laws named by its receipt.  It does not authorize candidate
-- pruning or a source-level claim that Lean behavior has been disproved.
module Leant.Synth.Length.Adapter
  ( CheckedLengthQuery
  , prepareCheckedLengthQuery
  , prepareCheckedLengthQueryWithLimits
  ) where

import Language.Haskell.Djex
  ( ExferenceLocal
  , LengthSMTLibLimits
  , LengthSMTLibQuery
  , LengthSMTLibQueryError
  , defaultLengthSMTLibLimits
  , sealLengthSMTLibQuery
  )

import Leant.Synth.Engine (DetailedVerificationVariant)
import Leant.Synth.Length.Contract (LeanLengthContract)
import Leant.Synth.Length.Handoff
  ( LengthHandoffRefusal
  , prepareCheckedLengthProblem
  )
import Leant.Synth.Verification (Verified)

-- | Query specialization for the exact Exference identities checked by the
-- Leant preparation boundary. The alias adds no wrapper or projection around
-- Djex's opaque nominal association.
type CheckedLengthQuery = LengthSMTLibQuery ExferenceLocal ExferenceLocal

-- | Check the verified origin, then construct a query with Djex's conservative
-- bounds. The nested result preserves the handoff/query refusal boundary
-- without retaining a separate runtime handoff wrapper.
prepareCheckedLengthQuery
  :: LeanLengthContract
  -> Verified DetailedVerificationVariant
  -> Either LengthHandoffRefusal
      (Either LengthSMTLibQueryError CheckedLengthQuery)
prepareCheckedLengthQuery =
  prepareCheckedLengthQueryWithLimits defaultLengthSMTLibLimits

-- | Check and construct with explicit operational bounds. Limits can reject a
-- query but cannot change its fixed QF_LIA semantics or translator schema.
prepareCheckedLengthQueryWithLimits
  :: LengthSMTLibLimits
  -> LeanLengthContract
  -> Verified DetailedVerificationVariant
  -> Either LengthHandoffRefusal
      (Either LengthSMTLibQueryError CheckedLengthQuery)
prepareCheckedLengthQueryWithLimits limits contract verified =
  case prepareCheckedLengthProblem contract verified of
    Left refusal -> Left refusal
    Right problem -> Right $ problem `seq`
      sealLengthSMTLibQuery limits problem
