{-# LANGUAGE RankNTypes #-}

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
  , CheckedLengthSpinePairQuery
  , prepareCheckedLengthSpinePairQuery
  , prepareCheckedLengthSpinePairQueryWithLimits
  , SourceCheckedLengthQuery (..)
  , SourceCheckedLengthSpinePairQuery (..)
  , prepareSourceCheckedLengthQuery
  , prepareSourceCheckedLengthSpinePairQuery
  , withSourceCheckedLengthQuery
  , withSourceCheckedLengthSpinePairQuery
  ) where

import Language.Haskell.Djex
  ( ExferenceLocal
  , LengthSMTLibLimits
  , LengthSMTLibQuery
  , LengthSMTLibQueryError
  , LengthSpinePairSMTLibQuery
  , LengthSpinePairSMTLibQueryError
  , defaultLengthSMTLibLimits
  , sealLengthSMTLibQuery
  , sealLengthSpinePairSMTLibQuery
  )

import Leant.Synth.Engine (DetailedVerificationVariant)
import Leant.Synth.Length.Contract
  ( LeanLengthContract
  , LeanLengthSpinePairContract
  )
import Leant.Synth.Length.Handoff
  ( LengthHandoffRefusal
  , LengthSpinePairHandoffRefusal
  , prepareCheckedLengthProblem
  , prepareCheckedLengthSpinePairProblem
  , SourceCheckedLengthProblem (..)
  , SourceCheckedLengthSpinePairProblem (..)
  , prepareSourceCheckedLengthProblem
  , prepareSourceCheckedLengthSpinePairProblem
  )
import Leant.Synth.Verification (Verified)

-- | Query specialization for the exact Exference identities checked by the
-- Leant preparation boundary. The alias adds no wrapper or projection around
-- Djex's opaque nominal association.
type CheckedLengthQuery = LengthSMTLibQuery ExferenceLocal ExferenceLocal

-- | Product-domain query specialization for the same exact Exference
-- identities. It remains nominally distinct from 'CheckedLengthQuery'.
type CheckedLengthSpinePairQuery =
  LengthSpinePairSMTLibQuery ExferenceLocal ExferenceLocal

-- | A nominal engine sum around the original sealed query. The eliminators
-- let engine-neutral consumers use the shared semantic operations without
-- changing any source identity, candidate graph, or query fingerprint.
data SourceCheckedLengthQuery
  = ExferenceCheckedLengthQuery CheckedLengthQuery
  | DjinnCheckedLengthQuery (LengthSMTLibQuery String String)

data SourceCheckedLengthSpinePairQuery
  = ExferenceCheckedLengthSpinePairQuery CheckedLengthSpinePairQuery
  | DjinnCheckedLengthSpinePairQuery (LengthSpinePairSMTLibQuery String String)

withSourceCheckedLengthQuery
  :: SourceCheckedLengthQuery
  -> (forall identity. LengthSMTLibQuery identity identity -> result)
  -> result
withSourceCheckedLengthQuery query action = case query of
  ExferenceCheckedLengthQuery exact -> action exact
  DjinnCheckedLengthQuery exact -> action exact

withSourceCheckedLengthSpinePairQuery
  :: SourceCheckedLengthSpinePairQuery
  -> (forall identity. LengthSpinePairSMTLibQuery identity identity -> result)
  -> result
withSourceCheckedLengthSpinePairQuery query action = case query of
  ExferenceCheckedLengthSpinePairQuery exact -> action exact
  DjinnCheckedLengthSpinePairQuery exact -> action exact

prepareSourceCheckedLengthQuery
  :: LeanLengthContract
  -> Verified DetailedVerificationVariant
  -> Either LengthHandoffRefusal
      (Either LengthSMTLibQueryError SourceCheckedLengthQuery)
prepareSourceCheckedLengthQuery contract verified = do
  problem <- prepareSourceCheckedLengthProblem contract verified
  pure $ case problem of
    ExferenceCheckedLengthProblem exact -> ExferenceCheckedLengthQuery
      <$> sealLengthSMTLibQuery defaultLengthSMTLibLimits exact
    DjinnCheckedLengthProblem exact -> DjinnCheckedLengthQuery
      <$> sealLengthSMTLibQuery defaultLengthSMTLibLimits exact

prepareSourceCheckedLengthSpinePairQuery
  :: LeanLengthSpinePairContract
  -> Verified DetailedVerificationVariant
  -> Either LengthSpinePairHandoffRefusal
      (Either LengthSpinePairSMTLibQueryError SourceCheckedLengthSpinePairQuery)
prepareSourceCheckedLengthSpinePairQuery contract verified = do
  problem <- prepareSourceCheckedLengthSpinePairProblem contract verified
  pure $ case problem of
    ExferenceCheckedLengthSpinePairProblem exact -> ExferenceCheckedLengthSpinePairQuery
      <$> sealLengthSpinePairSMTLibQuery defaultLengthSMTLibLimits exact
    DjinnCheckedLengthSpinePairProblem exact -> DjinnCheckedLengthSpinePairQuery
      <$> sealLengthSpinePairSMTLibQuery defaultLengthSMTLibLimits exact

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

-- | Check post-@whnfR@ canonical Lean @Prod@ provenance and both configured
-- spine fields, then construct Djex's pure product query with conservative
-- bounds.
prepareCheckedLengthSpinePairQuery
  :: LeanLengthSpinePairContract
  -> Verified DetailedVerificationVariant
  -> Either LengthSpinePairHandoffRefusal
      (Either LengthSpinePairSMTLibQueryError
        CheckedLengthSpinePairQuery)
prepareCheckedLengthSpinePairQuery =
  prepareCheckedLengthSpinePairQueryWithLimits defaultLengthSMTLibLimits

-- | Product counterpart of 'prepareCheckedLengthQueryWithLimits'. No solver
-- is launched and no live scalar worker/session protocol is reused.
prepareCheckedLengthSpinePairQueryWithLimits
  :: LengthSMTLibLimits
  -> LeanLengthSpinePairContract
  -> Verified DetailedVerificationVariant
  -> Either LengthSpinePairHandoffRefusal
      (Either LengthSpinePairSMTLibQueryError
        CheckedLengthSpinePairQuery)
prepareCheckedLengthSpinePairQueryWithLimits limits contract verified =
  case prepareCheckedLengthSpinePairProblem contract verified of
    Left refusal -> Left refusal
    Right problem -> Right $ problem `seq`
      sealLengthSpinePairSMTLibQuery limits problem
