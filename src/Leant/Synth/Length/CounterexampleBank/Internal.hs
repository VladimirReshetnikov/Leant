{-# LANGUAGE RankNTypes #-}
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
  , LengthCounterexampleBankContext
  , withLengthCounterexampleBankContext
  , withDefaultLengthCounterexampleBankContext
  , readLengthCounterexampleBankContextState
  , LengthCounterexampleBankReplayFailure (..)
  , LengthCounterexampleBankReplayRefusal (..)
  , LengthCounterexampleBankReplayHit
  , lengthCounterexampleBankReplayHitCounterexample
  , LengthCounterexampleBankReplayOutcome (..)
  , replayLengthCounterexampleBank
  , LengthCounterexampleBankContextReplayHit
  , lengthCounterexampleBankContextReplayHitCounterexample
  , LengthCounterexampleBankContextReplayOutcome (..)
  , replayLengthCounterexampleBankInContext
  , LengthCounterexampleBankPromotionFailure (..)
  , promoteLengthCounterexampleBankReplayHit
  , promoteLengthCounterexampleBankReplayHitInContext
  , LengthCounterexampleBankReceiptOrigin (..)
  , LengthCounterexampleBankRecordFailure (..)
  , LengthCounterexampleBankRecordOutcome (..)
  , recordLengthCounterexampleBankReceipt
  , recordLengthCounterexampleBankReceiptInContext
  , LengthSpinePairCounterexampleBankState
  , emptyLengthSpinePairCounterexampleBankState
  , defaultLengthSpinePairCounterexampleBankState
  , lengthSpinePairCounterexampleBankStateActiveBank
  , LengthSpinePairCounterexampleBankContext
  , withLengthSpinePairCounterexampleBankContext
  , withDefaultLengthSpinePairCounterexampleBankContext
  , readLengthSpinePairCounterexampleBankContextState
  , LengthSpinePairCounterexampleBankReplayFailure (..)
  , LengthSpinePairCounterexampleBankReplayRefusal (..)
  , LengthSpinePairCounterexampleBankReplayHit
  , lengthSpinePairCounterexampleBankReplayHitCounterexample
  , LengthSpinePairCounterexampleBankReplayOutcome (..)
  , replayLengthSpinePairCounterexampleBank
  , LengthSpinePairCounterexampleBankContextReplayHit
  , lengthSpinePairCounterexampleBankContextReplayHitCounterexample
  , LengthSpinePairCounterexampleBankContextReplayOutcome (..)
  , replayLengthSpinePairCounterexampleBankInContext
  , LengthSpinePairCounterexampleBankPromotionFailure (..)
  , promoteLengthSpinePairCounterexampleBankReplayHit
  , promoteLengthSpinePairCounterexampleBankReplayHitInContext
  , LengthSpinePairCounterexampleBankReceiptOrigin (..)
  , LengthSpinePairCounterexampleBankRecordFailure (..)
  , LengthSpinePairCounterexampleBankRecordOutcome (..)
  , recordLengthSpinePairCounterexampleBankReceipt
  , recordLengthSpinePairCounterexampleBankReceiptInContext
  ) where

import Control.Concurrent.MVar (MVar, modifyMVar, newMVar, readMVar)
import Control.DeepSeq (rnf)
import Control.Exception (evaluate)

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

-- | An uninitialized scalar state owning the supplied validated limits and no
-- active bank.  The limits are not inspected; the first replay or recording
-- transition supplies the scope of the bank it creates.
emptyLengthCounterexampleBankState
  :: LengthCounterexampleBankLimits
  -> LengthCounterexampleBankState identity
emptyLengthCounterexampleBankState limits =
  LengthCounterexampleBankState limits Nothing

-- | 'emptyLengthCounterexampleBankState' at Djex's
-- 'defaultLengthCounterexampleBankLimits'.
defaultLengthCounterexampleBankState
  :: LengthCounterexampleBankState identity
defaultLengthCounterexampleBankState = emptyLengthCounterexampleBankState
  defaultLengthCounterexampleBankLimits

-- | The state's sole active bank, or 'Nothing' until a replay or recording
-- transition has ensured one for a query's scope.
lengthCounterexampleBankStateActiveBank
  :: LengthCounterexampleBankState identity
  -> Maybe (LengthCounterexampleBank identity)
lengthCounterexampleBankStateActiveBank
    (LengthCounterexampleBankState _ active) = active

-- | One command-owned mutable scalar bank.  The fresh nominal command tag
-- prevents a replay hit from one owner from being promoted through another
-- owner even when both banks share Djex's semantic identity parameter.
-- Mutation remains private to the transition functions below.
newtype LengthCounterexampleBankContext command identity =
  LengthCounterexampleBankContext
    (MVar (LengthCounterexampleBankState identity))

type role LengthCounterexampleBankContext nominal nominal

-- | Introduce a fresh empty scalar owner with caller-validated limits.
withLengthCounterexampleBankContext
  :: LengthCounterexampleBankLimits
  -> (forall command.
      LengthCounterexampleBankContext command identity -> IO result)
  -> IO result
withLengthCounterexampleBankContext limits action = do
  state <- newMVar $ emptyLengthCounterexampleBankState limits
  action $ LengthCounterexampleBankContext state

-- | 'withLengthCounterexampleBankContext' at Djex's
-- 'defaultLengthCounterexampleBankLimits'.
withDefaultLengthCounterexampleBankContext
  :: (forall command.
      LengthCounterexampleBankContext command identity -> IO result)
  -> IO result
withDefaultLengthCounterexampleBankContext =
  withLengthCounterexampleBankContext defaultLengthCounterexampleBankLimits

-- | Take an immutable diagnostic snapshot.  There is deliberately no setter
-- and no context constructor which accepts an earlier snapshot.
readLengthCounterexampleBankContextState
  :: LengthCounterexampleBankContext command identity
  -> IO (LengthCounterexampleBankState identity)
readLengthCounterexampleBankContextState
    (LengthCounterexampleBankContext state) = readMVar state

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

-- | The fresh current-query receipt established by replaying the hit's
-- retained scalar sample.
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

-- | A replay hit tied to both the semantic bank identity and the fresh
-- command owner which produced it.  Its constructor stays private so only a
-- context replay can mint promotion authority.
newtype LengthCounterexampleBankContextReplayHit command identity =
  LengthCounterexampleBankContextReplayHitValue
    (LengthCounterexampleBankReplayHit identity)

type role LengthCounterexampleBankContextReplayHit nominal nominal

-- | The fresh current-query receipt carried by a command-nominal scalar
-- replay hit; see 'lengthCounterexampleBankReplayHitCounterexample'.
lengthCounterexampleBankContextReplayHitCounterexample
  :: LengthCounterexampleBankContextReplayHit command identity
  -> ValidatedLengthCounterexample
lengthCounterexampleBankContextReplayHitCounterexample
    (LengthCounterexampleBankContextReplayHitValue hit) =
  lengthCounterexampleBankReplayHitCounterexample hit

-- | Context replay keeps the established refusal and bounded-unavailability
-- vocabulary while making a successful hit command-nominal.
data LengthCounterexampleBankContextReplayOutcome command identity
  = LengthCounterexampleBankContextReplayMiss
      [LengthCounterexampleBankReplayRefusal]
  | LengthCounterexampleBankContextReplayAttemptUnavailable
      [LengthCounterexampleBankReplayRefusal]
      !LengthCounterexampleBankError
  | LengthCounterexampleBankContextReplayHit
      [LengthCounterexampleBankReplayRefusal]
      !(LengthCounterexampleBankContextReplayHit command identity)

type role LengthCounterexampleBankContextReplayOutcome nominal nominal

-- | Replay through one mutable owner.  Exactly one pure adapter transition is
-- serialized, and its complete successor state and expected classification are
-- forced before commit.  The exception-restoring transition cell retains the
-- old state when synchronous or asynchronous forcing fails, then propagates
-- that exception; completed expected classifications install their
-- authoritative successor.
replayLengthCounterexampleBankInContext
  :: LengthEvaluationLimits
  -> LengthSMTLibQuery identity local
  -> LengthCounterexampleBankContext command identity
  -> IO
      (Either LengthCounterexampleBankReplayFailure
        (LengthCounterexampleBankContextReplayOutcome command identity))
replayLengthCounterexampleBankInContext evaluationLimits query
    (LengthCounterexampleBankContext state) =
  transitionLengthCounterexampleBankContext state $ \initial ->
    let (successor, replayed) =
          replayLengthCounterexampleBank evaluationLimits query initial
    in (successor, fmap tagOutcome replayed)
 where
  tagOutcome replayed = case replayed of
    LengthCounterexampleBankReplayMiss refusals ->
      LengthCounterexampleBankContextReplayMiss refusals
    LengthCounterexampleBankReplayAttemptUnavailable refusals failure ->
      LengthCounterexampleBankContextReplayAttemptUnavailable
        refusals failure
    LengthCounterexampleBankReplayHit refusals hit ->
      LengthCounterexampleBankContextReplayHit refusals
        $ LengthCounterexampleBankContextReplayHitValue hit

transitionLengthCounterexampleBankContext
  :: MVar (LengthCounterexampleBankState identity)
  -> (LengthCounterexampleBankState identity
      -> (LengthCounterexampleBankState identity, Either failure outcome))
  -> IO (Either failure outcome)
transitionLengthCounterexampleBankContext state transition =
  modifyMVar state $ \initial ->
    case transition initial of
      (successor, outcome) -> do
        _ <- evaluate $ forceLengthCounterexampleBankSuccessor successor
        _ <- evaluate $ forceEitherClassification outcome
        pure (successor, outcome)

-- Construction deliberately keeps validated limits lazy.  Before any
-- transition installs a successor, however, both those limits and the complete
-- bounded active bank are forced: no deferred limit, replay input, origin,
-- sample, or statistic may cross the serialized context boundary.  An
-- unexpected exception therefore leaves the old context state untouched.
forceLengthCounterexampleBankSuccessor
  :: LengthCounterexampleBankState identity
  -> ()
forceLengthCounterexampleBankSuccessor
    (LengthCounterexampleBankState limits active) =
  rnf limits `seq` rnf active

forceEitherClassification :: Either failure outcome -> ()
forceEitherClassification classified = case classified of
  Left failure -> failure `seq` ()
  Right outcome -> outcome `seq` ()

-- Scalar promotion ---------------------------------------------------------

-- | Why one explicit scalar replay hit was not promoted.  The scope and
-- membership cases are structural invariant failures: the hit's scope no
-- longer matches the active bank, or its exact sample is no longer retained
-- there.  Insertion rejection carries Djex's bank error.  Every failure
-- leaves the state unchanged.
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

-- | 'promoteLengthCounterexampleBankReplayHit' as one serialized transition
-- of the owner which minted the hit.  The shared command tag ties the hit to
-- that owner; a failure leaves the owner's state unchanged.
promoteLengthCounterexampleBankReplayHitInContext
  :: LengthCounterexampleBankContextReplayHit command identity
  -> LengthCounterexampleBankContext command identity
  -> IO (Either LengthCounterexampleBankPromotionFailure ())
promoteLengthCounterexampleBankReplayHitInContext
    (LengthCounterexampleBankContextReplayHitValue hit)
    (LengthCounterexampleBankContext state) =
  transitionLengthCounterexampleBankContext state
    $ promoteLengthCounterexampleBankReplayHit hit

-- Scalar recording ---------------------------------------------------------

-- | Coarse provenance for one freshly established scalar receipt.  These
-- labels carry no evidence authority; Djex freshly replays before insertion.
data LengthCounterexampleBankReceiptOrigin
  = LengthCounterexampleBankReceiptFromLiveModel
  | LengthCounterexampleBankReceiptFromSolverIndependentReplay
  | LengthCounterexampleBankReceiptFromSimplificationReplay
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Why one fresh scalar receipt was not recorded.  Scope invariant is a
-- structural failure after the active bank has been ensured; the remaining
-- cases are Djex's input-replay refusals and a receipt whose fresh replay
-- against the current query reproduced no counterexample.  Ordinary bounded
-- unavailability is reported through 'LengthCounterexampleBankRecordOutcome'
-- instead.
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

-- | Record one freshly established scalar receipt in the active same-scope
-- bank.
--
-- The state is first ensured for the query's scope.  Djex freshly replays
-- the receipt's inputs against the current query before inserting only those
-- inputs under the mapped origin; the bank returned by that recording bridge
-- replaces the active bank for every classification.
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

-- | 'recordLengthCounterexampleBankReceipt' as one serialized transition of
-- a mutable scalar owner.  The forced successor state is committed for both
-- classifications.
recordLengthCounterexampleBankReceiptInContext
  :: LengthEvaluationLimits
  -> LengthSMTLibQuery identity local
  -> LengthCounterexampleBankReceiptOrigin
  -> ValidatedLengthCounterexample
  -> LengthCounterexampleBankContext command identity
  -> IO
      (Either LengthCounterexampleBankRecordFailure
        LengthCounterexampleBankRecordOutcome)
recordLengthCounterexampleBankReceiptInContext evaluationLimits query origin
    counterexample (LengthCounterexampleBankContext state) =
  transitionLengthCounterexampleBankContext state
    $ recordLengthCounterexampleBankReceipt
        evaluationLimits query origin counterexample

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

-- | Validated binary-product limits and zero or one active same-scope bank;
-- the pair-domain sibling of 'LengthCounterexampleBankState'.  Both fields
-- likewise remain lazy, so constructing an empty state inspects no limits and
-- needs no query.
data LengthSpinePairCounterexampleBankState identity =
  LengthSpinePairCounterexampleBankState
    LengthSpinePairCounterexampleBankLimits
    (Maybe (LengthSpinePairCounterexampleBank identity))

type role LengthSpinePairCounterexampleBankState nominal

-- | An uninitialized binary-product state owning the supplied validated
-- limits and no active bank.  The limits are not inspected; the first replay
-- or recording transition supplies the scope of the bank it creates.
emptyLengthSpinePairCounterexampleBankState
  :: LengthSpinePairCounterexampleBankLimits
  -> LengthSpinePairCounterexampleBankState identity
emptyLengthSpinePairCounterexampleBankState limits =
  LengthSpinePairCounterexampleBankState limits Nothing

-- | 'emptyLengthSpinePairCounterexampleBankState' at Djex's
-- 'defaultLengthSpinePairCounterexampleBankLimits'.
defaultLengthSpinePairCounterexampleBankState
  :: LengthSpinePairCounterexampleBankState identity
defaultLengthSpinePairCounterexampleBankState =
  emptyLengthSpinePairCounterexampleBankState
    defaultLengthSpinePairCounterexampleBankLimits

-- | The state's sole active bank, or 'Nothing' until a replay or recording
-- transition has ensured one for a query's scope.
lengthSpinePairCounterexampleBankStateActiveBank
  :: LengthSpinePairCounterexampleBankState identity
  -> Maybe (LengthSpinePairCounterexampleBank identity)
lengthSpinePairCounterexampleBankStateActiveBank
    (LengthSpinePairCounterexampleBankState _ active) = active

-- | One command-owned mutable binary-product bank; the pair-domain sibling
-- of 'LengthCounterexampleBankContext'.  The fresh nominal command tag
-- likewise prevents a replay hit from one owner from being promoted through
-- another owner, and mutation stays private to the transition functions
-- below.
newtype LengthSpinePairCounterexampleBankContext command identity =
  LengthSpinePairCounterexampleBankContext
    (MVar (LengthSpinePairCounterexampleBankState identity))

type role LengthSpinePairCounterexampleBankContext nominal nominal

-- | Introduce a fresh empty binary-product owner with caller-validated
-- limits.
withLengthSpinePairCounterexampleBankContext
  :: LengthSpinePairCounterexampleBankLimits
  -> (forall command.
      LengthSpinePairCounterexampleBankContext command identity -> IO result)
  -> IO result
withLengthSpinePairCounterexampleBankContext limits action = do
  state <- newMVar $ emptyLengthSpinePairCounterexampleBankState limits
  action $ LengthSpinePairCounterexampleBankContext state

-- | 'withLengthSpinePairCounterexampleBankContext' at Djex's
-- 'defaultLengthSpinePairCounterexampleBankLimits'.
withDefaultLengthSpinePairCounterexampleBankContext
  :: (forall command.
      LengthSpinePairCounterexampleBankContext command identity -> IO result)
  -> IO result
withDefaultLengthSpinePairCounterexampleBankContext =
  withLengthSpinePairCounterexampleBankContext
    defaultLengthSpinePairCounterexampleBankLimits

-- | Take an immutable diagnostic snapshot of a binary-product owner.  As for
-- the scalar owner, there is no setter and no context constructor which
-- accepts an earlier snapshot.
readLengthSpinePairCounterexampleBankContextState
  :: LengthSpinePairCounterexampleBankContext command identity
  -> IO (LengthSpinePairCounterexampleBankState identity)
readLengthSpinePairCounterexampleBankContextState
    (LengthSpinePairCounterexampleBankContext state) = readMVar state

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

-- | A post-ensure structural invariant failure while traversing exact
-- retained binary-product samples.
data LengthSpinePairCounterexampleBankReplayFailure
  = LengthSpinePairCounterexampleBankReplayScopeInvariant
  | LengthSpinePairCounterexampleBankReplayMembershipInvariant
  deriving (Eq, Ord, Show)

-- | One ordinary per-sample binary-product refusal.  It is retained in
-- newest-first attempt order while traversal continues with the charged
-- successor bank.
data LengthSpinePairCounterexampleBankReplayRefusal
  = LengthSpinePairCounterexampleBankReplayEvaluationRefused
      !LengthSpinePairEvaluationError
  | LengthSpinePairCounterexampleBankReplayAssociationRefused
  deriving (Eq, Ord, Show)

-- | One exact retained binary-product sample and the fresh current-query
-- receipt produced by replaying it.  The private scope/sample association is
-- required for a later explicit no-evaluation promotion.
data LengthSpinePairCounterexampleBankReplayHit identity =
  LengthSpinePairCounterexampleBankReplayHitValue
    (LengthSpinePairCounterexampleBankScope identity)
    LengthSpinePairCounterexampleBankSample
    ValidatedLengthSpinePairCounterexample

type role LengthSpinePairCounterexampleBankReplayHit nominal

-- | The fresh current-query receipt established by replaying the hit's
-- retained binary-product sample.
lengthSpinePairCounterexampleBankReplayHitCounterexample
  :: LengthSpinePairCounterexampleBankReplayHit identity
  -> ValidatedLengthSpinePairCounterexample
lengthSpinePairCounterexampleBankReplayHitCounterexample
    (LengthSpinePairCounterexampleBankReplayHitValue _ _ counterexample) =
  counterexample

-- | Whole-bank binary-product replay result.  Exhaustion is an ordinary miss
-- and an attempt cap is ordinary bounded unavailability; neither supplies
-- evidence.
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

-- | Replay the active binary-product bank's exact retained samples newest
-- first.
--
-- Every bridge-returned bank replaces the active bank before its result is
-- classified.  An ordinary non-counterexample continues with the next exact
-- sample; a hit is returned without implicit promotion.
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

-- | A binary-product replay hit tied to both the semantic bank identity and
-- the fresh command owner which produced it.  Its constructor stays private
-- so only a context replay can mint promotion authority.
newtype LengthSpinePairCounterexampleBankContextReplayHit command identity =
  LengthSpinePairCounterexampleBankContextReplayHitValue
    (LengthSpinePairCounterexampleBankReplayHit identity)

type role LengthSpinePairCounterexampleBankContextReplayHit nominal nominal

-- | The fresh current-query receipt carried by a command-nominal
-- binary-product replay hit; see
-- 'lengthSpinePairCounterexampleBankReplayHitCounterexample'.
lengthSpinePairCounterexampleBankContextReplayHitCounterexample
  :: LengthSpinePairCounterexampleBankContextReplayHit command identity
  -> ValidatedLengthSpinePairCounterexample
lengthSpinePairCounterexampleBankContextReplayHitCounterexample
    (LengthSpinePairCounterexampleBankContextReplayHitValue hit) =
  lengthSpinePairCounterexampleBankReplayHitCounterexample hit

-- | Binary-product context replay keeps the established refusal and
-- bounded-unavailability vocabulary while making a successful hit
-- command-nominal.
data LengthSpinePairCounterexampleBankContextReplayOutcome command identity
  = LengthSpinePairCounterexampleBankContextReplayMiss
      [LengthSpinePairCounterexampleBankReplayRefusal]
  | LengthSpinePairCounterexampleBankContextReplayAttemptUnavailable
      [LengthSpinePairCounterexampleBankReplayRefusal]
      !LengthSpinePairCounterexampleBankError
  | LengthSpinePairCounterexampleBankContextReplayHit
      [LengthSpinePairCounterexampleBankReplayRefusal]
      !(LengthSpinePairCounterexampleBankContextReplayHit command identity)

type role LengthSpinePairCounterexampleBankContextReplayOutcome
  nominal nominal

-- | Replay through one mutable binary-product owner.  Exactly one pure
-- adapter transition is serialized, and its complete successor state and
-- expected classification are forced before commit.  The exception-restoring
-- transition cell retains the old state when synchronous or asynchronous
-- forcing fails, then propagates that exception; completed expected
-- classifications install their authoritative successor.
replayLengthSpinePairCounterexampleBankInContext
  :: LengthEvaluationLimits
  -> LengthSpinePairSMTLibQuery identity local
  -> LengthSpinePairCounterexampleBankContext command identity
  -> IO
      (Either LengthSpinePairCounterexampleBankReplayFailure
        (LengthSpinePairCounterexampleBankContextReplayOutcome
          command identity))
replayLengthSpinePairCounterexampleBankInContext evaluationLimits query
    (LengthSpinePairCounterexampleBankContext state) =
  transitionLengthSpinePairCounterexampleBankContext state $ \initial ->
    let (successor, replayed) =
          replayLengthSpinePairCounterexampleBank
            evaluationLimits query initial
    in (successor, fmap tagOutcome replayed)
 where
  tagOutcome replayed = case replayed of
    LengthSpinePairCounterexampleBankReplayMiss refusals ->
      LengthSpinePairCounterexampleBankContextReplayMiss refusals
    LengthSpinePairCounterexampleBankReplayAttemptUnavailable
        refusals failure ->
      LengthSpinePairCounterexampleBankContextReplayAttemptUnavailable
        refusals failure
    LengthSpinePairCounterexampleBankReplayHit refusals hit ->
      LengthSpinePairCounterexampleBankContextReplayHit refusals
        $ LengthSpinePairCounterexampleBankContextReplayHitValue hit

transitionLengthSpinePairCounterexampleBankContext
  :: MVar (LengthSpinePairCounterexampleBankState identity)
  -> (LengthSpinePairCounterexampleBankState identity
      -> ( LengthSpinePairCounterexampleBankState identity
         , Either failure outcome
         ))
  -> IO (Either failure outcome)
transitionLengthSpinePairCounterexampleBankContext state transition =
  modifyMVar state $ \initial ->
    case transition initial of
      (successor, outcome) -> do
        _ <- evaluate $ forceLengthSpinePairCounterexampleBankSuccessor successor
        _ <- evaluate $ forceEitherClassification outcome
        pure (successor, outcome)

forceLengthSpinePairCounterexampleBankSuccessor
  :: LengthSpinePairCounterexampleBankState identity
  -> ()
forceLengthSpinePairCounterexampleBankSuccessor
    (LengthSpinePairCounterexampleBankState limits active) =
  rnf limits `seq` rnf active

-- Binary-product promotion -------------------------------------------------

-- | Why one explicit binary-product replay hit was not promoted.  The scope
-- and membership cases are structural invariant failures: the hit's scope no
-- longer matches the active bank, or its exact sample is no longer retained
-- there.  Insertion rejection carries Djex's bank error.  Every failure
-- leaves the state unchanged.
data LengthSpinePairCounterexampleBankPromotionFailure
  = LengthSpinePairCounterexampleBankPromotionScopeInvariant
  | LengthSpinePairCounterexampleBankPromotionMembershipInvariant
  | LengthSpinePairCounterexampleBankPromotionInsertionRejected
      !LengthSpinePairCounterexampleBankError
  deriving (Eq, Ord, Show)

-- | Promote one explicit binary-product replay hit without replaying or
-- recording it a second time.
--
-- The exact retained sample must still belong to the active same-scope bank.
-- Direct insertion performs Djex's input-only deduplication and MRU
-- promotion; this replay-established use receives the solver-independent
-- replay origin.
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

-- | 'promoteLengthSpinePairCounterexampleBankReplayHit' as one serialized
-- transition of the owner which minted the hit.  The shared command tag ties
-- the hit to that owner; a failure leaves the owner's state unchanged.
promoteLengthSpinePairCounterexampleBankReplayHitInContext
  :: LengthSpinePairCounterexampleBankContextReplayHit command identity
  -> LengthSpinePairCounterexampleBankContext command identity
  -> IO (Either LengthSpinePairCounterexampleBankPromotionFailure ())
promoteLengthSpinePairCounterexampleBankReplayHitInContext
    (LengthSpinePairCounterexampleBankContextReplayHitValue hit)
    (LengthSpinePairCounterexampleBankContext state) =
  transitionLengthSpinePairCounterexampleBankContext state
    $ promoteLengthSpinePairCounterexampleBankReplayHit hit

-- Binary-product recording -------------------------------------------------

-- | Coarse provenance for one freshly established binary-product receipt.
-- These labels carry no evidence authority; Djex freshly replays before
-- insertion.
data LengthSpinePairCounterexampleBankReceiptOrigin
  = LengthSpinePairCounterexampleBankReceiptFromLiveModel
  | LengthSpinePairCounterexampleBankReceiptFromSolverIndependentReplay
  | LengthSpinePairCounterexampleBankReceiptFromSimplificationReplay
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Why one fresh binary-product receipt was not recorded.  Scope invariant
-- is a structural failure after the active bank has been ensured; the
-- remaining cases are Djex's input-replay refusals and a receipt whose fresh
-- replay against the current query reproduced no counterexample.  Ordinary
-- bounded unavailability is reported through
-- 'LengthSpinePairCounterexampleBankRecordOutcome' instead.
data LengthSpinePairCounterexampleBankRecordFailure
  = LengthSpinePairCounterexampleBankRecordScopeInvariant
  | LengthSpinePairCounterexampleBankRecordEvaluationRejected
      !LengthSpinePairEvaluationError
  | LengthSpinePairCounterexampleBankRecordAssociationRejected
  | LengthSpinePairCounterexampleBankRecordCounterexampleNotReproduced
  deriving (Eq, Ord, Show)

-- | Ordinary bounded binary-product recording outcomes.  Unavailable results
-- retain no claim that the supplied receipt was fresh for the current query.
data LengthSpinePairCounterexampleBankRecordOutcome
  = LengthSpinePairCounterexampleBankRecorded
      !ValidatedLengthSpinePairCounterexample
  | LengthSpinePairCounterexampleBankRecordAttemptUnavailable
      !LengthSpinePairCounterexampleBankError
  | LengthSpinePairCounterexampleBankRecordInsertionUnavailable
      !LengthSpinePairCounterexampleBankError
  deriving (Eq, Show)

-- | Record one freshly established binary-product receipt in the active
-- same-scope bank.
--
-- The state is first ensured for the query's scope.  Djex freshly replays
-- the receipt's inputs against the current query before inserting only those
-- inputs under the mapped origin; the bank returned by that recording bridge
-- replaces the active bank for every classification.
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

-- | 'recordLengthSpinePairCounterexampleBankReceipt' as one serialized
-- transition of a mutable binary-product owner.  The forced successor state
-- is committed for both classifications.
recordLengthSpinePairCounterexampleBankReceiptInContext
  :: LengthEvaluationLimits
  -> LengthSpinePairSMTLibQuery identity local
  -> LengthSpinePairCounterexampleBankReceiptOrigin
  -> ValidatedLengthSpinePairCounterexample
  -> LengthSpinePairCounterexampleBankContext command identity
  -> IO
      (Either LengthSpinePairCounterexampleBankRecordFailure
        LengthSpinePairCounterexampleBankRecordOutcome)
recordLengthSpinePairCounterexampleBankReceiptInContext
    evaluationLimits query origin counterexample
    (LengthSpinePairCounterexampleBankContext state) =
  transitionLengthSpinePairCounterexampleBankContext state
    $ recordLengthSpinePairCounterexampleBankReceipt
        evaluationLimits query origin counterexample

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
