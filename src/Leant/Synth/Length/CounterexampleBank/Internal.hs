{-# LANGUAGE RoleAnnotations #-}

-- | Package-private ownership and query-owned replay for Djex's bounded
-- Length counterexample banks.
--
-- A state owns validated limits and at most one active bank.  It starts
-- uninitialized, acquires the exact candidate-independent scope of the first
-- query which uses it, and discards that sole bank when a later query has a
-- different scope.  No query, receipt, verdict, solver observation, or
-- process capability is retained by the state.
--
-- Replay traverses the active bank's exact opaque samples newest first.  Each
-- attempt is made through Djex's query-owned bridge and its returned bank is
-- authoritative even on failure.  A hit remains explicit: promotion is a
-- separate input-only insertion which performs no second evaluation.  Fresh
-- established or simplified receipts likewise cross Djex's recording bridge
-- exactly once before their inputs may be retained.
module Leant.Synth.Length.CounterexampleBank.Internal
  ( LengthCounterexampleBankState
  , emptyLengthCounterexampleBankState
  , defaultLengthCounterexampleBankState
  , lengthCounterexampleBankStateActiveBank
  , LengthCounterexampleBankReplayFailure (..)
  , LengthCounterexampleBankReplayRefusal (..)
  , LengthCounterexampleBankReplayHit
  , lengthCounterexampleBankReplayHitCounterexample
  , LengthCounterexampleBankReplayOutcome (..)
  , replayLengthCounterexampleBank
  , LengthCounterexampleBankPromotionFailure (..)
  , promoteLengthCounterexampleBankReplayHit
  , LengthCounterexampleBankReceiptOrigin (..)
  , LengthCounterexampleBankRecordFailure (..)
  , LengthCounterexampleBankRecordOutcome (..)
  , recordLengthCounterexampleBankReceipt
  , LengthSpinePairCounterexampleBankState
  , emptyLengthSpinePairCounterexampleBankState
  , defaultLengthSpinePairCounterexampleBankState
  , lengthSpinePairCounterexampleBankStateActiveBank
  , LengthSpinePairCounterexampleBankReplayFailure (..)
  , LengthSpinePairCounterexampleBankReplayRefusal (..)
  , LengthSpinePairCounterexampleBankReplayHit
  , lengthSpinePairCounterexampleBankReplayHitCounterexample
  , LengthSpinePairCounterexampleBankReplayOutcome (..)
  , replayLengthSpinePairCounterexampleBank
  , LengthSpinePairCounterexampleBankPromotionFailure (..)
  , promoteLengthSpinePairCounterexampleBankReplayHit
  , LengthSpinePairCounterexampleBankReceiptOrigin (..)
  , LengthSpinePairCounterexampleBankRecordFailure (..)
  , LengthSpinePairCounterexampleBankRecordOutcome (..)
  , recordLengthSpinePairCounterexampleBankReceipt
  ) where

import Language.Haskell.Djex
  ( LengthCounterexampleBank
  , LengthCounterexampleBankError
  , LengthCounterexampleBankLimits
  , LengthCounterexampleBankOrigin
  , LengthCounterexampleBankSample
  , LengthCounterexampleBankScope
  , LengthEvaluationError
  , LengthEvaluationLimits
  , LengthSMTLibCounterexampleBankRecordError (..)
  , LengthSMTLibCounterexampleBankSampleReplayError (..)
  , LengthSMTLibInputReplayError (..)
  , LengthSMTLibQuery
  , LengthSpinePairCounterexampleBank
  , LengthSpinePairCounterexampleBankError
  , LengthSpinePairCounterexampleBankLimits
  , LengthSpinePairCounterexampleBankOrigin
  , LengthSpinePairCounterexampleBankSample
  , LengthSpinePairCounterexampleBankScope
  , LengthSpinePairEvaluationError
  , LengthSpinePairSMTLibCounterexampleBankRecordError (..)
  , LengthSpinePairSMTLibCounterexampleBankSampleReplayError (..)
  , LengthSpinePairSMTLibInputReplayError (..)
  , LengthSpinePairSMTLibQuery
  , ValidatedLengthCounterexample
  , ValidatedLengthSpinePairCounterexample
  , defaultLengthCounterexampleBankLimits
  , defaultLengthSpinePairCounterexampleBankLimits
  , emptyLengthCounterexampleBank
  , emptyLengthSpinePairCounterexampleBank
  , insertLengthCounterexampleBankSample
  , insertLengthSpinePairCounterexampleBankSample
  , lengthCounterexampleBankLiveModelReplayOrigin
  , lengthCounterexampleBankMatchesScope
  , lengthCounterexampleBankSampleInputs
  , lengthCounterexampleBankSamples
  , lengthCounterexampleBankSimplificationReplayOrigin
  , lengthCounterexampleBankSolverIndependentReplayOrigin
  , lengthSMTLibQueryCounterexampleBankScope
  , lengthSpinePairCounterexampleBankLiveModelReplayOrigin
  , lengthSpinePairCounterexampleBankMatchesScope
  , lengthSpinePairCounterexampleBankSampleInputs
  , lengthSpinePairCounterexampleBankSamples
  , lengthSpinePairCounterexampleBankSimplificationReplayOrigin
  , lengthSpinePairCounterexampleBankSolverIndependentReplayOrigin
  , lengthSpinePairSMTLibQueryCounterexampleBankScope
  , recordLengthSMTLibQueryCounterexampleInBank
  , recordLengthSpinePairSMTLibQueryCounterexampleInBank
  , replayLengthSMTLibCounterexampleBankSample
  , replayLengthSpinePairSMTLibCounterexampleBankSample
  )

-- Scalar ownership ---------------------------------------------------------

-- | Validated scalar limits and zero or one active same-scope bank.
--
-- Both fields deliberately remain lazy.  Constructing an empty state does
-- not inspect the limits and requires no query from which to obtain a scope.
data LengthCounterexampleBankState identity =
  LengthCounterexampleBankState
    LengthCounterexampleBankLimits
    (Maybe (LengthCounterexampleBank identity))

type role LengthCounterexampleBankState nominal

emptyLengthCounterexampleBankState
  :: LengthCounterexampleBankLimits
  -> LengthCounterexampleBankState identity
emptyLengthCounterexampleBankState limits =
  LengthCounterexampleBankState limits Nothing

defaultLengthCounterexampleBankState
  :: LengthCounterexampleBankState identity
defaultLengthCounterexampleBankState = emptyLengthCounterexampleBankState
  defaultLengthCounterexampleBankLimits

lengthCounterexampleBankStateActiveBank
  :: LengthCounterexampleBankState identity
  -> Maybe (LengthCounterexampleBank identity)
lengthCounterexampleBankStateActiveBank
    (LengthCounterexampleBankState _ active) = active

ensureLengthCounterexampleBankState
  :: LengthSMTLibQuery identity local
  -> LengthCounterexampleBankState identity
  -> LengthCounterexampleBankState identity
ensureLengthCounterexampleBankState query
    state@(LengthCounterexampleBankState limits active) =
  case active of
    Just bank
      | lengthCounterexampleBankMatchesScope scope bank -> state
    _ -> LengthCounterexampleBankState limits
      $ Just $ emptyLengthCounterexampleBank limits scope
 where
  scope = lengthSMTLibQueryCounterexampleBankScope query

replaceLengthCounterexampleBank
  :: LengthCounterexampleBank identity
  -> LengthCounterexampleBankState identity
  -> LengthCounterexampleBankState identity
replaceLengthCounterexampleBank bank
    (LengthCounterexampleBankState limits _) =
  LengthCounterexampleBankState limits $ Just bank

-- Scalar replay ------------------------------------------------------------

-- | A post-ensure structural invariant failure while traversing exact
-- retained scalar samples.
data LengthCounterexampleBankReplayFailure
  = LengthCounterexampleBankReplayScopeInvariant
  | LengthCounterexampleBankReplayMembershipInvariant
  deriving (Eq, Ord, Show)

-- | One ordinary per-sample refusal.  It is retained in newest-first attempt
-- order while traversal continues with the charged successor bank.
data LengthCounterexampleBankReplayRefusal
  = LengthCounterexampleBankReplayEvaluationRefused !LengthEvaluationError
  | LengthCounterexampleBankReplayAssociationRefused
  deriving (Eq, Ord, Show)

-- | One exact retained sample and the fresh current-query receipt produced by
-- replaying it.  The private scope/sample association is required for a later
-- explicit no-evaluation promotion.
data LengthCounterexampleBankReplayHit identity =
  LengthCounterexampleBankReplayHitValue
    (LengthCounterexampleBankScope identity)
    LengthCounterexampleBankSample
    ValidatedLengthCounterexample

type role LengthCounterexampleBankReplayHit nominal

lengthCounterexampleBankReplayHitCounterexample
  :: LengthCounterexampleBankReplayHit identity
  -> ValidatedLengthCounterexample
lengthCounterexampleBankReplayHitCounterexample
    (LengthCounterexampleBankReplayHitValue _ _ counterexample) =
  counterexample

-- | Whole-bank replay result.  Exhaustion is an ordinary miss and an attempt
-- cap is ordinary bounded unavailability; neither supplies evidence.
data LengthCounterexampleBankReplayOutcome identity
  = LengthCounterexampleBankReplayMiss
      [LengthCounterexampleBankReplayRefusal]
  | LengthCounterexampleBankReplayAttemptUnavailable
      [LengthCounterexampleBankReplayRefusal]
      !LengthCounterexampleBankError
  | LengthCounterexampleBankReplayHit
      [LengthCounterexampleBankReplayRefusal]
      !(LengthCounterexampleBankReplayHit identity)

type role LengthCounterexampleBankReplayOutcome nominal

-- | Replay the active bank's exact retained samples newest first.
--
-- Every bridge-returned bank replaces the active bank before its result is
-- classified.  An ordinary non-counterexample continues with the next exact
-- sample; a hit is returned without implicit promotion.
replayLengthCounterexampleBank
  :: LengthEvaluationLimits
  -> LengthSMTLibQuery identity local
  -> LengthCounterexampleBankState identity
  -> ( LengthCounterexampleBankState identity
     , Either LengthCounterexampleBankReplayFailure
         (LengthCounterexampleBankReplayOutcome identity)
     )
replayLengthCounterexampleBank evaluationLimits query initial =
  case lengthCounterexampleBankStateActiveBank ensured of
    Nothing ->
      (ensured, Left LengthCounterexampleBankReplayScopeInvariant)
    Just bank -> go [] ensured bank $ lengthCounterexampleBankSamples bank
 where
  ensured = ensureLengthCounterexampleBankState query initial

  go reversedRefusals state _ [] =
    ( state
    , Right $ LengthCounterexampleBankReplayMiss $ reverse reversedRefusals
    )
  go reversedRefusals state bank (sample : remaining) =
    let (successor, replayed) =
          replayLengthSMTLibCounterexampleBankSample
            evaluationLimits query sample bank
        successorState = replaceLengthCounterexampleBank successor state
    in case replayed of
      Left LengthSMTLibCounterexampleBankSampleReplayScopeMismatch ->
        ( successorState
        , Left LengthCounterexampleBankReplayScopeInvariant
        )
      Left LengthSMTLibCounterexampleBankSampleReplaySampleNotRetained ->
        ( successorState
        , Left LengthCounterexampleBankReplayMembershipInvariant
        )
      Left
          (LengthSMTLibCounterexampleBankSampleReplayAttemptRejected failure) ->
        ( successorState
        , Right $ LengthCounterexampleBankReplayAttemptUnavailable
            (reverse reversedRefusals) failure
        )
      Left (LengthSMTLibCounterexampleBankSampleReplayInputRejected failure) ->
        case failure of
          LengthSMTLibInputReplayEvaluationRejected evaluationFailure ->
            go
              (LengthCounterexampleBankReplayEvaluationRefused
                evaluationFailure : reversedRefusals)
              successorState successor remaining
          LengthSMTLibInputReplayAssociationRejected _ ->
            go
              (LengthCounterexampleBankReplayAssociationRefused
                : reversedRefusals)
              successorState successor remaining
      Right Nothing -> go reversedRefusals successorState successor remaining
      Right (Just counterexample) ->
        ( successorState
        , Right $ LengthCounterexampleBankReplayHit
            (reverse reversedRefusals)
            $ LengthCounterexampleBankReplayHitValue
                (lengthSMTLibQueryCounterexampleBankScope query)
                sample counterexample
        )

-- Scalar promotion ---------------------------------------------------------

data LengthCounterexampleBankPromotionFailure
  = LengthCounterexampleBankPromotionScopeInvariant
  | LengthCounterexampleBankPromotionMembershipInvariant
  | LengthCounterexampleBankPromotionInsertionRejected
      !LengthCounterexampleBankError
  deriving (Eq, Ord, Show)

-- | Promote one explicit scalar replay hit without replaying or recording it
-- a second time.
--
-- The exact retained sample must still belong to the active same-scope bank.
-- Direct insertion performs Djex's input-only deduplication and MRU promotion;
-- this replay-established use receives the solver-independent replay origin.
promoteLengthCounterexampleBankReplayHit
  :: LengthCounterexampleBankReplayHit identity
  -> LengthCounterexampleBankState identity
  -> ( LengthCounterexampleBankState identity
     , Either LengthCounterexampleBankPromotionFailure ()
     )
promoteLengthCounterexampleBankReplayHit
    (LengthCounterexampleBankReplayHitValue scope sample _counterexample)
    state =
  case lengthCounterexampleBankStateActiveBank state of
    Nothing ->
      (state, Left LengthCounterexampleBankPromotionScopeInvariant)
    Just bank
      | not $ lengthCounterexampleBankMatchesScope scope bank ->
          (state, Left LengthCounterexampleBankPromotionScopeInvariant)
      | sample `notElem` lengthCounterexampleBankSamples bank ->
          (state, Left LengthCounterexampleBankPromotionMembershipInvariant)
      | otherwise -> case insertLengthCounterexampleBankSample
          lengthCounterexampleBankSolverIndependentReplayOrigin
          (lengthCounterexampleBankSampleInputs sample) bank of
        Left failure ->
          ( state
          , Left $ LengthCounterexampleBankPromotionInsertionRejected failure
          )
        Right promoted ->
          (replaceLengthCounterexampleBank promoted state, Right ())

-- Scalar recording ---------------------------------------------------------

-- | Coarse provenance for one freshly established scalar receipt.  These
-- labels carry no evidence authority; Djex freshly replays before insertion.
data LengthCounterexampleBankReceiptOrigin
  = LengthCounterexampleBankReceiptFromLiveModel
  | LengthCounterexampleBankReceiptFromSolverIndependentReplay
  | LengthCounterexampleBankReceiptFromSimplificationReplay
  deriving (Bounded, Enum, Eq, Ord, Show)

data LengthCounterexampleBankRecordFailure
  = LengthCounterexampleBankRecordScopeInvariant
  | LengthCounterexampleBankRecordEvaluationRejected !LengthEvaluationError
  | LengthCounterexampleBankRecordAssociationRejected
  | LengthCounterexampleBankRecordCounterexampleNotReproduced
  deriving (Eq, Ord, Show)

-- | Ordinary bounded recording outcomes.  Unavailable results retain no
-- claim that the supplied receipt was fresh for the current query.
data LengthCounterexampleBankRecordOutcome
  = LengthCounterexampleBankRecorded !ValidatedLengthCounterexample
  | LengthCounterexampleBankRecordAttemptUnavailable
      !LengthCounterexampleBankError
  | LengthCounterexampleBankRecordInsertionUnavailable
      !LengthCounterexampleBankError
  deriving (Eq, Show)

recordLengthCounterexampleBankReceipt
  :: LengthEvaluationLimits
  -> LengthSMTLibQuery identity local
  -> LengthCounterexampleBankReceiptOrigin
  -> ValidatedLengthCounterexample
  -> LengthCounterexampleBankState identity
  -> ( LengthCounterexampleBankState identity
     , Either LengthCounterexampleBankRecordFailure
         LengthCounterexampleBankRecordOutcome
     )
recordLengthCounterexampleBankReceipt evaluationLimits query origin
    counterexample initial =
  case lengthCounterexampleBankStateActiveBank ensured of
    Nothing ->
      (ensured, Left LengthCounterexampleBankRecordScopeInvariant)
    Just bank ->
      let (successor, recorded) =
            recordLengthSMTLibQueryCounterexampleInBank
              evaluationLimits query (scalarReceiptOrigin origin)
              counterexample bank
          successorState = replaceLengthCounterexampleBank successor ensured
      in (successorState, mapRecordResult recorded)
 where
  ensured = ensureLengthCounterexampleBankState query initial

  mapRecordResult recorded = case recorded of
    Left LengthSMTLibCounterexampleBankRecordScopeMismatch ->
      Left LengthCounterexampleBankRecordScopeInvariant
    Left (LengthSMTLibCounterexampleBankRecordAttemptRejected failure) ->
      Right $ LengthCounterexampleBankRecordAttemptUnavailable failure
    Left
        (LengthSMTLibCounterexampleBankRecordInputReplayRejected failure) ->
      case failure of
        LengthSMTLibInputReplayEvaluationRejected evaluationFailure ->
          Left $ LengthCounterexampleBankRecordEvaluationRejected
            evaluationFailure
        LengthSMTLibInputReplayAssociationRejected _ ->
          Left LengthCounterexampleBankRecordAssociationRejected
    Left LengthSMTLibCounterexampleBankRecordCounterexampleNotReproduced ->
      Left LengthCounterexampleBankRecordCounterexampleNotReproduced
    Left (LengthSMTLibCounterexampleBankRecordInsertionRejected failure) ->
      Right $ LengthCounterexampleBankRecordInsertionUnavailable failure
    Right fresh -> Right $ LengthCounterexampleBankRecorded fresh

scalarReceiptOrigin
  :: LengthCounterexampleBankReceiptOrigin
  -> LengthCounterexampleBankOrigin
scalarReceiptOrigin origin = case origin of
  LengthCounterexampleBankReceiptFromLiveModel ->
    lengthCounterexampleBankLiveModelReplayOrigin
  LengthCounterexampleBankReceiptFromSolverIndependentReplay ->
    lengthCounterexampleBankSolverIndependentReplayOrigin
  LengthCounterexampleBankReceiptFromSimplificationReplay ->
    lengthCounterexampleBankSimplificationReplayOrigin

-- Binary-product ownership -------------------------------------------------

data LengthSpinePairCounterexampleBankState identity =
  LengthSpinePairCounterexampleBankState
    LengthSpinePairCounterexampleBankLimits
    (Maybe (LengthSpinePairCounterexampleBank identity))

type role LengthSpinePairCounterexampleBankState nominal

emptyLengthSpinePairCounterexampleBankState
  :: LengthSpinePairCounterexampleBankLimits
  -> LengthSpinePairCounterexampleBankState identity
emptyLengthSpinePairCounterexampleBankState limits =
  LengthSpinePairCounterexampleBankState limits Nothing

defaultLengthSpinePairCounterexampleBankState
  :: LengthSpinePairCounterexampleBankState identity
defaultLengthSpinePairCounterexampleBankState =
  emptyLengthSpinePairCounterexampleBankState
    defaultLengthSpinePairCounterexampleBankLimits

lengthSpinePairCounterexampleBankStateActiveBank
  :: LengthSpinePairCounterexampleBankState identity
  -> Maybe (LengthSpinePairCounterexampleBank identity)
lengthSpinePairCounterexampleBankStateActiveBank
    (LengthSpinePairCounterexampleBankState _ active) = active

ensureLengthSpinePairCounterexampleBankState
  :: LengthSpinePairSMTLibQuery identity local
  -> LengthSpinePairCounterexampleBankState identity
  -> LengthSpinePairCounterexampleBankState identity
ensureLengthSpinePairCounterexampleBankState query
    state@(LengthSpinePairCounterexampleBankState limits active) =
  case active of
    Just bank
      | lengthSpinePairCounterexampleBankMatchesScope scope bank -> state
    _ -> LengthSpinePairCounterexampleBankState limits
      $ Just $ emptyLengthSpinePairCounterexampleBank limits scope
 where
  scope = lengthSpinePairSMTLibQueryCounterexampleBankScope query

replaceLengthSpinePairCounterexampleBank
  :: LengthSpinePairCounterexampleBank identity
  -> LengthSpinePairCounterexampleBankState identity
  -> LengthSpinePairCounterexampleBankState identity
replaceLengthSpinePairCounterexampleBank bank
    (LengthSpinePairCounterexampleBankState limits _) =
  LengthSpinePairCounterexampleBankState limits $ Just bank

-- Binary-product replay ----------------------------------------------------

data LengthSpinePairCounterexampleBankReplayFailure
  = LengthSpinePairCounterexampleBankReplayScopeInvariant
  | LengthSpinePairCounterexampleBankReplayMembershipInvariant
  deriving (Eq, Ord, Show)

data LengthSpinePairCounterexampleBankReplayRefusal
  = LengthSpinePairCounterexampleBankReplayEvaluationRefused
      !LengthSpinePairEvaluationError
  | LengthSpinePairCounterexampleBankReplayAssociationRefused
  deriving (Eq, Ord, Show)

data LengthSpinePairCounterexampleBankReplayHit identity =
  LengthSpinePairCounterexampleBankReplayHitValue
    (LengthSpinePairCounterexampleBankScope identity)
    LengthSpinePairCounterexampleBankSample
    ValidatedLengthSpinePairCounterexample

type role LengthSpinePairCounterexampleBankReplayHit nominal

lengthSpinePairCounterexampleBankReplayHitCounterexample
  :: LengthSpinePairCounterexampleBankReplayHit identity
  -> ValidatedLengthSpinePairCounterexample
lengthSpinePairCounterexampleBankReplayHitCounterexample
    (LengthSpinePairCounterexampleBankReplayHitValue _ _ counterexample) =
  counterexample

data LengthSpinePairCounterexampleBankReplayOutcome identity
  = LengthSpinePairCounterexampleBankReplayMiss
      [LengthSpinePairCounterexampleBankReplayRefusal]
  | LengthSpinePairCounterexampleBankReplayAttemptUnavailable
      [LengthSpinePairCounterexampleBankReplayRefusal]
      !LengthSpinePairCounterexampleBankError
  | LengthSpinePairCounterexampleBankReplayHit
      [LengthSpinePairCounterexampleBankReplayRefusal]
      !(LengthSpinePairCounterexampleBankReplayHit identity)

type role LengthSpinePairCounterexampleBankReplayOutcome nominal

replayLengthSpinePairCounterexampleBank
  :: LengthEvaluationLimits
  -> LengthSpinePairSMTLibQuery identity local
  -> LengthSpinePairCounterexampleBankState identity
  -> ( LengthSpinePairCounterexampleBankState identity
     , Either LengthSpinePairCounterexampleBankReplayFailure
         (LengthSpinePairCounterexampleBankReplayOutcome identity)
     )
replayLengthSpinePairCounterexampleBank evaluationLimits query initial =
  case lengthSpinePairCounterexampleBankStateActiveBank ensured of
    Nothing ->
      (ensured, Left LengthSpinePairCounterexampleBankReplayScopeInvariant)
    Just bank -> go [] ensured bank
      $ lengthSpinePairCounterexampleBankSamples bank
 where
  ensured = ensureLengthSpinePairCounterexampleBankState query initial

  go reversedRefusals state _ [] =
    ( state
    , Right $ LengthSpinePairCounterexampleBankReplayMiss
        $ reverse reversedRefusals
    )
  go reversedRefusals state bank (sample : remaining) =
    let (successor, replayed) =
          replayLengthSpinePairSMTLibCounterexampleBankSample
            evaluationLimits query sample bank
        successorState = replaceLengthSpinePairCounterexampleBank
          successor state
    in case replayed of
      Left
          LengthSpinePairSMTLibCounterexampleBankSampleReplayScopeMismatch ->
        ( successorState
        , Left LengthSpinePairCounterexampleBankReplayScopeInvariant
        )
      Left
          LengthSpinePairSMTLibCounterexampleBankSampleReplaySampleNotRetained ->
        ( successorState
        , Left LengthSpinePairCounterexampleBankReplayMembershipInvariant
        )
      Left
          (LengthSpinePairSMTLibCounterexampleBankSampleReplayAttemptRejected
            failure) ->
        ( successorState
        , Right
            $ LengthSpinePairCounterexampleBankReplayAttemptUnavailable
                (reverse reversedRefusals) failure
        )
      Left
          (LengthSpinePairSMTLibCounterexampleBankSampleReplayInputRejected
            failure) -> case failure of
        LengthSpinePairSMTLibInputReplayEvaluationRejected
            evaluationFailure ->
          go
            (LengthSpinePairCounterexampleBankReplayEvaluationRefused
              evaluationFailure : reversedRefusals)
            successorState successor remaining
        LengthSpinePairSMTLibInputReplayAssociationRejected _ ->
          go
            (LengthSpinePairCounterexampleBankReplayAssociationRefused
              : reversedRefusals)
            successorState successor remaining
      Right Nothing -> go reversedRefusals successorState successor remaining
      Right (Just counterexample) ->
        ( successorState
        , Right $ LengthSpinePairCounterexampleBankReplayHit
            (reverse reversedRefusals)
            $ LengthSpinePairCounterexampleBankReplayHitValue
                (lengthSpinePairSMTLibQueryCounterexampleBankScope query)
                sample counterexample
        )

-- Binary-product promotion -------------------------------------------------

data LengthSpinePairCounterexampleBankPromotionFailure
  = LengthSpinePairCounterexampleBankPromotionScopeInvariant
  | LengthSpinePairCounterexampleBankPromotionMembershipInvariant
  | LengthSpinePairCounterexampleBankPromotionInsertionRejected
      !LengthSpinePairCounterexampleBankError
  deriving (Eq, Ord, Show)

promoteLengthSpinePairCounterexampleBankReplayHit
  :: LengthSpinePairCounterexampleBankReplayHit identity
  -> LengthSpinePairCounterexampleBankState identity
  -> ( LengthSpinePairCounterexampleBankState identity
     , Either LengthSpinePairCounterexampleBankPromotionFailure ()
     )
promoteLengthSpinePairCounterexampleBankReplayHit
    (LengthSpinePairCounterexampleBankReplayHitValue
      scope sample _counterexample) state =
  case lengthSpinePairCounterexampleBankStateActiveBank state of
    Nothing ->
      ( state
      , Left LengthSpinePairCounterexampleBankPromotionScopeInvariant
      )
    Just bank
      | not $ lengthSpinePairCounterexampleBankMatchesScope scope bank ->
          ( state
          , Left LengthSpinePairCounterexampleBankPromotionScopeInvariant
          )
      | sample `notElem` lengthSpinePairCounterexampleBankSamples bank ->
          ( state
          , Left LengthSpinePairCounterexampleBankPromotionMembershipInvariant
          )
      | otherwise -> case insertLengthSpinePairCounterexampleBankSample
          lengthSpinePairCounterexampleBankSolverIndependentReplayOrigin
          (lengthSpinePairCounterexampleBankSampleInputs sample) bank of
        Left failure ->
          ( state
          , Left
              $ LengthSpinePairCounterexampleBankPromotionInsertionRejected
                  failure
          )
        Right promoted ->
          (replaceLengthSpinePairCounterexampleBank promoted state, Right ())

-- Binary-product recording -------------------------------------------------

data LengthSpinePairCounterexampleBankReceiptOrigin
  = LengthSpinePairCounterexampleBankReceiptFromLiveModel
  | LengthSpinePairCounterexampleBankReceiptFromSolverIndependentReplay
  | LengthSpinePairCounterexampleBankReceiptFromSimplificationReplay
  deriving (Bounded, Enum, Eq, Ord, Show)

data LengthSpinePairCounterexampleBankRecordFailure
  = LengthSpinePairCounterexampleBankRecordScopeInvariant
  | LengthSpinePairCounterexampleBankRecordEvaluationRejected
      !LengthSpinePairEvaluationError
  | LengthSpinePairCounterexampleBankRecordAssociationRejected
  | LengthSpinePairCounterexampleBankRecordCounterexampleNotReproduced
  deriving (Eq, Ord, Show)

data LengthSpinePairCounterexampleBankRecordOutcome
  = LengthSpinePairCounterexampleBankRecorded
      !ValidatedLengthSpinePairCounterexample
  | LengthSpinePairCounterexampleBankRecordAttemptUnavailable
      !LengthSpinePairCounterexampleBankError
  | LengthSpinePairCounterexampleBankRecordInsertionUnavailable
      !LengthSpinePairCounterexampleBankError
  deriving (Eq, Show)

recordLengthSpinePairCounterexampleBankReceipt
  :: LengthEvaluationLimits
  -> LengthSpinePairSMTLibQuery identity local
  -> LengthSpinePairCounterexampleBankReceiptOrigin
  -> ValidatedLengthSpinePairCounterexample
  -> LengthSpinePairCounterexampleBankState identity
  -> ( LengthSpinePairCounterexampleBankState identity
     , Either LengthSpinePairCounterexampleBankRecordFailure
         LengthSpinePairCounterexampleBankRecordOutcome
     )
recordLengthSpinePairCounterexampleBankReceipt evaluationLimits query origin
    counterexample initial =
  case lengthSpinePairCounterexampleBankStateActiveBank ensured of
    Nothing ->
      ( ensured
      , Left LengthSpinePairCounterexampleBankRecordScopeInvariant
      )
    Just bank ->
      let (successor, recorded) =
            recordLengthSpinePairSMTLibQueryCounterexampleInBank
              evaluationLimits query (spinePairReceiptOrigin origin)
              counterexample bank
          successorState = replaceLengthSpinePairCounterexampleBank
            successor ensured
      in (successorState, mapRecordResult recorded)
 where
  ensured = ensureLengthSpinePairCounterexampleBankState query initial

  mapRecordResult recorded = case recorded of
    Left LengthSpinePairSMTLibCounterexampleBankRecordScopeMismatch ->
      Left LengthSpinePairCounterexampleBankRecordScopeInvariant
    Left
        (LengthSpinePairSMTLibCounterexampleBankRecordAttemptRejected
          failure) ->
      Right
        $ LengthSpinePairCounterexampleBankRecordAttemptUnavailable failure
    Left
        (LengthSpinePairSMTLibCounterexampleBankRecordInputReplayRejected
          failure) -> case failure of
      LengthSpinePairSMTLibInputReplayEvaluationRejected evaluationFailure ->
        Left $ LengthSpinePairCounterexampleBankRecordEvaluationRejected
          evaluationFailure
      LengthSpinePairSMTLibInputReplayAssociationRejected _ ->
        Left LengthSpinePairCounterexampleBankRecordAssociationRejected
    Left
        LengthSpinePairSMTLibCounterexampleBankRecordCounterexampleNotReproduced ->
      Left
        LengthSpinePairCounterexampleBankRecordCounterexampleNotReproduced
    Left
        (LengthSpinePairSMTLibCounterexampleBankRecordInsertionRejected
          failure) ->
      Right
        $ LengthSpinePairCounterexampleBankRecordInsertionUnavailable failure
    Right fresh -> Right $ LengthSpinePairCounterexampleBankRecorded fresh

spinePairReceiptOrigin
  :: LengthSpinePairCounterexampleBankReceiptOrigin
  -> LengthSpinePairCounterexampleBankOrigin
spinePairReceiptOrigin origin = case origin of
  LengthSpinePairCounterexampleBankReceiptFromLiveModel ->
    lengthSpinePairCounterexampleBankLiveModelReplayOrigin
  LengthSpinePairCounterexampleBankReceiptFromSolverIndependentReplay ->
    lengthSpinePairCounterexampleBankSolverIndependentReplayOrigin
  LengthSpinePairCounterexampleBankReceiptFromSimplificationReplay ->
    lengthSpinePairCounterexampleBankSimplificationReplayOrigin
