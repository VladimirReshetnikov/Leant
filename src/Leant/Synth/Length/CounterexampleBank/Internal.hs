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
--
-- Both Length domains own, replay, promote and record through exactly this
-- control flow; they differ only in the Djex vocabulary each spells.  The
-- shared section below holds the flow once, over types parameterized by the
-- domain's own limits, bank, scope, sample, receipt and error types -- so a
-- scalar state and a binary-product state remain distinct types which no
-- transition can confuse -- and each domain supplies one 'BankBridge' saying
-- how Djex answers for it.

module Leant.Synth.Length.CounterexampleBank.Internal
  ( BankState
  , BankContext
  , BankSurface (..)
  , BankBridge (..)
  , BankReplayStep (..)
  , BankRecordStep (..)
  , BankReplayFailure (..)
  , BankReplayRefusal (..)
  , BankReplayHit
  , BankReplayOutcome (..)
  , BankContextReplayHit
  , BankPromotionFailure (..)
  , BankReceiptOrigin (..)
  , BankRecordFailure (..)
  , BankRecordOutcome (..)
  , LengthCounterexampleBankState
  , emptyLengthCounterexampleBankState
  , defaultLengthCounterexampleBankState
  , lengthCounterexampleBankStateActiveBank
  , LengthCounterexampleBankContext
  , withLengthCounterexampleBankContext
  , withDefaultLengthCounterexampleBankContext
  , readLengthCounterexampleBankContextState
  , LengthCounterexampleBankReplayRefusal
  , LengthCounterexampleBankReplayHit
  , lengthCounterexampleBankReplayHitCounterexample
  , LengthCounterexampleBankReplayOutcome
  , replayLengthCounterexampleBank
  , LengthCounterexampleBankContextReplayHit
  , lengthCounterexampleBankContextReplayHitCounterexample
  , LengthCounterexampleBankContextReplayOutcome
  , replayLengthCounterexampleBankInContext
  , LengthCounterexampleBankPromotionFailure
  , promoteLengthCounterexampleBankReplayHit
  , promoteLengthCounterexampleBankReplayHitInContext
  , LengthCounterexampleBankRecordFailure
  , LengthCounterexampleBankRecordOutcome
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
  , LengthSpinePairCounterexampleBankReplayRefusal
  , LengthSpinePairCounterexampleBankReplayHit
  , lengthSpinePairCounterexampleBankReplayHitCounterexample
  , LengthSpinePairCounterexampleBankReplayOutcome
  , replayLengthSpinePairCounterexampleBank
  , LengthSpinePairCounterexampleBankContextReplayHit
  , lengthSpinePairCounterexampleBankContextReplayHitCounterexample
  , LengthSpinePairCounterexampleBankContextReplayOutcome
  , replayLengthSpinePairCounterexampleBankInContext
  , LengthSpinePairCounterexampleBankPromotionFailure
  , promoteLengthSpinePairCounterexampleBankReplayHit
  , promoteLengthSpinePairCounterexampleBankReplayHitInContext
  , LengthSpinePairCounterexampleBankRecordFailure
  , LengthSpinePairCounterexampleBankRecordOutcome
  , recordLengthSpinePairCounterexampleBankReceipt
  , recordLengthSpinePairCounterexampleBankReceiptInContext
  ) where

import Control.Concurrent.MVar (MVar, modifyMVar, newMVar, readMVar)
import Control.DeepSeq (NFData, rnf)
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

-- Shared ownership --------------------------------------------------------

-- | Validated limits and zero or one active same-scope bank.
--
-- Both fields deliberately remain lazy.  Constructing an empty state does not
-- inspect the limits and requires no query from which to obtain a scope.  The
-- limits and bank types are the domain's own, so a scalar state and a
-- binary-product state remain distinct types.
data BankState limits bank = BankState limits (Maybe bank)

type role BankState nominal nominal

-- | An uninitialized state owning the supplied validated limits and no active
-- bank.  The limits are not inspected; the first replay or recording
-- transition supplies the scope of the bank it creates.
emptyBankState :: limits -> BankState limits bank
emptyBankState limits = BankState limits Nothing

-- | The state's sole active bank, or 'Nothing' until a replay or recording
-- transition has ensured one for a query's scope.
bankStateActiveBank :: BankState limits bank -> Maybe bank
bankStateActiveBank (BankState _ active) = active

-- | One command-owned mutable bank.  The fresh nominal command tag prevents a
-- replay hit from one owner from being promoted through another owner even
-- when both banks share Djex's semantic identity parameter.  Mutation remains
-- private to the transition functions below.
newtype BankContext command limits bank =
  BankContext (MVar (BankState limits bank))

type role BankContext nominal nominal nominal

-- | Introduce a fresh empty owner with caller-validated limits.
withBankContext
  :: limits
  -> (forall command. BankContext command limits bank -> IO result)
  -> IO result
withBankContext limits action = do
  state <- newMVar $ emptyBankState limits
  action $ BankContext state

-- | Take an immutable diagnostic snapshot.  There is deliberately no setter
-- and no context constructor which accepts an earlier snapshot.
readBankContextState
  :: BankContext command limits bank
  -> IO (BankState limits bank)
readBankContextState (BankContext state) = readMVar state

-- | The part of one domain's Djex bank vocabulary which needs no query.
-- Promotion is exactly this much, which is why it keeps its query-free
-- signature.
data BankSurface bank scope sample bankError = BankSurface
  { surfaceMatchesScope :: scope -> bank -> Bool
  , surfaceSamples :: bank -> [sample]
  , surfaceInsertReplayedSample :: sample -> bank -> Either bankError bank
    -- ^ input-only reinsertion under the solver-independent replay origin,
    -- performing no second evaluation
  }

-- | Everything one Length domain spells for itself, with the evaluation
-- limits and the current query already captured.  The shared transitions
-- below call exactly these; each domain builds one per call.
data BankBridge limits bank scope sample counterexample bankError
    evaluationError =
  BankBridge
    { bridgeSurface :: BankSurface bank scope sample bankError
    , bridgeQueryScope :: scope
      -- ^ the candidate-independent bank scope of the current query
    , bridgeEmptyBank :: limits -> scope -> bank
    , bridgeReplaySample
        :: sample
        -> bank
        -> (bank, BankReplayStep evaluationError bankError counterexample)
      -- ^ one query-owned replay attempt; the returned bank is authoritative
      -- even on failure
    , bridgeRecordReceipt
        :: BankReceiptOrigin
        -> counterexample
        -> bank
        -> (bank, BankRecordStep evaluationError bankError counterexample)
    }

-- | How one domain's replay bridge answered, in the vocabulary the shared
-- walk classifies.  The two invariant cases are structural failures; the
-- refusals are ordinary and traversal continues past them.
data BankReplayStep evaluationError bankError counterexample
  = ReplayStepScopeMismatch
  | ReplayStepSampleNotRetained
  | ReplayStepAttemptRejected !bankError
  | ReplayStepEvaluationRefused !evaluationError
  | ReplayStepAssociationRefused
  | ReplayStepNoCounterexample
  | ReplayStepCounterexample !counterexample

-- | How one domain's recording bridge answered.
data BankRecordStep evaluationError bankError counterexample
  = RecordStepScopeMismatch
  | RecordStepAttemptRejected !bankError
  | RecordStepEvaluationRejected !evaluationError
  | RecordStepAssociationRejected
  | RecordStepCounterexampleNotReproduced
  | RecordStepInsertionRejected !bankError
  | RecordStepRecorded !counterexample

ensureBankState
  :: BankBridge limits bank scope sample counterexample bankError
      evaluationError
  -> BankState limits bank
  -> BankState limits bank
ensureBankState bridge state@(BankState limits active) = case active of
  Just bank
    | surfaceMatchesScope (bridgeSurface bridge) scope bank -> state
  _ -> BankState limits $ Just $ bridgeEmptyBank bridge limits scope
 where
  scope = bridgeQueryScope bridge

replaceBank :: bank -> BankState limits bank -> BankState limits bank
replaceBank bank (BankState limits _) = BankState limits $ Just bank

-- Shared replay ------------------------------------------------------------

-- | A post-ensure structural invariant failure while traversing exact
-- retained samples.
data BankReplayFailure
  = BankReplayScopeInvariant
  | BankReplayMembershipInvariant
  deriving (Eq, Ord, Show)

-- | One ordinary per-sample refusal.  It is retained in newest-first attempt
-- order while traversal continues with the charged successor bank.
data BankReplayRefusal evaluationError
  = BankReplayEvaluationRefused !evaluationError
  | BankReplayAssociationRefused
  deriving (Eq, Ord, Show)

-- | One exact retained sample and the fresh current-query receipt produced by
-- replaying it.  The private scope/sample association is required for a later
-- explicit no-evaluation promotion.
data BankReplayHit scope sample counterexample =
  BankReplayHitValue scope sample counterexample

type role BankReplayHit nominal nominal nominal

-- | The fresh current-query receipt established by replaying the hit's
-- retained sample.
bankReplayHitCounterexample
  :: BankReplayHit scope sample counterexample
  -> counterexample
bankReplayHitCounterexample (BankReplayHitValue _ _ counterexample) =
  counterexample

-- | Whole-bank replay result.  Exhaustion is an ordinary miss and an attempt
-- cap is ordinary bounded unavailability; neither supplies evidence.
data BankReplayOutcome evaluationError bankError hit
  = BankReplayMiss [BankReplayRefusal evaluationError]
  | BankReplayAttemptUnavailable
      [BankReplayRefusal evaluationError]
      !bankError
  | BankReplayHit [BankReplayRefusal evaluationError] !hit

type role BankReplayOutcome nominal nominal nominal

-- | Replay the active bank's exact retained samples newest first.
--
-- Every bridge-returned bank replaces the active bank before its result is
-- classified.  An ordinary non-counterexample continues with the next exact
-- sample; a hit is returned without implicit promotion.
replayBank
  :: BankBridge limits bank scope sample counterexample bankError
      evaluationError
  -> BankState limits bank
  -> ( BankState limits bank
     , Either BankReplayFailure
         (BankReplayOutcome evaluationError bankError
           (BankReplayHit scope sample counterexample))
     )
replayBank bridge initial = case bankStateActiveBank ensured of
  Nothing -> (ensured, Left BankReplayScopeInvariant)
  Just bank -> go [] ensured bank $ surfaceSamples (bridgeSurface bridge) bank
 where
  ensured = ensureBankState bridge initial

  go reversedRefusals state _ [] =
    (state, Right $ BankReplayMiss $ reverse reversedRefusals)
  go reversedRefusals state bank (sample : remaining) =
    let (successor, replayed) = bridgeReplaySample bridge sample bank
        successorState = replaceBank successor state
        continue refusal = go (refusal : reversedRefusals)
          successorState successor remaining
    in case replayed of
      ReplayStepScopeMismatch ->
        (successorState, Left BankReplayScopeInvariant)
      ReplayStepSampleNotRetained ->
        (successorState, Left BankReplayMembershipInvariant)
      ReplayStepAttemptRejected failure ->
        ( successorState
        , Right $ BankReplayAttemptUnavailable
            (reverse reversedRefusals) failure
        )
      ReplayStepEvaluationRefused failure ->
        continue $ BankReplayEvaluationRefused failure
      ReplayStepAssociationRefused -> continue BankReplayAssociationRefused
      ReplayStepNoCounterexample ->
        go reversedRefusals successorState successor remaining
      ReplayStepCounterexample counterexample ->
        ( successorState
        , Right $ BankReplayHit (reverse reversedRefusals)
            $ BankReplayHitValue
                (bridgeQueryScope bridge) sample counterexample
        )

-- | A replay hit tied to both the semantic bank identity and the fresh
-- command owner which produced it.  Its constructor stays private so only a
-- context replay can mint promotion authority.
newtype BankContextReplayHit command scope sample counterexample =
  BankContextReplayHitValue (BankReplayHit scope sample counterexample)

type role BankContextReplayHit nominal nominal nominal nominal

-- | The fresh current-query receipt carried by a command-nominal replay hit;
-- see 'bankReplayHitCounterexample'.
bankContextReplayHitCounterexample
  :: BankContextReplayHit command scope sample counterexample
  -> counterexample
bankContextReplayHitCounterexample (BankContextReplayHitValue hit) =
  bankReplayHitCounterexample hit

-- | Replay through one mutable owner.  Exactly one pure adapter transition is
-- serialized, and its complete successor state and expected classification are
-- forced before commit.  The exception-restoring transition cell retains the
-- old state when synchronous or asynchronous forcing fails, then propagates
-- that exception; completed expected classifications install their
-- authoritative successor.
replayBankInContext
  :: (NFData limits, NFData bank)
  => BankBridge limits bank scope sample counterexample bankError
      evaluationError
  -> BankContext command limits bank
  -> IO
      (Either BankReplayFailure
        (BankReplayOutcome evaluationError bankError
          (BankContextReplayHit command scope sample counterexample)))
replayBankInContext bridge (BankContext state) =
  transitionBankContext state $ \initial ->
    let (successor, replayed) = replayBank bridge initial
    in (successor, fmap tagOutcome replayed)
 where
  tagOutcome replayed = case replayed of
    BankReplayMiss refusals -> BankReplayMiss refusals
    BankReplayAttemptUnavailable refusals failure ->
      BankReplayAttemptUnavailable refusals failure
    BankReplayHit refusals hit ->
      BankReplayHit refusals $ BankContextReplayHitValue hit

transitionBankContext
  :: (NFData limits, NFData bank)
  => MVar (BankState limits bank)
  -> (BankState limits bank
      -> (BankState limits bank, Either failure outcome))
  -> IO (Either failure outcome)
transitionBankContext state transition =
  modifyMVar state $ \initial ->
    case transition initial of
      (successor, outcome) -> do
        _ <- evaluate $ forceBankSuccessor successor
        _ <- evaluate $ forceEitherClassification outcome
        pure (successor, outcome)

-- Construction deliberately keeps validated limits lazy.  Before any
-- transition installs a successor, however, both those limits and the complete
-- bounded active bank are forced: no deferred limit, replay input, origin,
-- sample, or statistic may cross the serialized context boundary.  An
-- unexpected exception therefore leaves the old context state untouched.
forceBankSuccessor
  :: (NFData limits, NFData bank)
  => BankState limits bank
  -> ()
forceBankSuccessor (BankState limits active) = rnf limits `seq` rnf active

forceEitherClassification :: Either failure outcome -> ()
forceEitherClassification classified = case classified of
  Left failure -> failure `seq` ()
  Right outcome -> outcome `seq` ()

-- Shared promotion ---------------------------------------------------------

-- | Why one explicit replay hit was not promoted.  The scope and membership
-- cases are structural invariant failures: the hit's scope no longer matches
-- the active bank, or its exact sample is no longer retained there.
-- Insertion rejection carries Djex's bank error.  Every failure leaves the
-- state unchanged.
data BankPromotionFailure bankError
  = BankPromotionScopeInvariant
  | BankPromotionMembershipInvariant
  | BankPromotionInsertionRejected !bankError
  deriving (Eq, Ord, Show)

-- | Promote one explicit replay hit without replaying or recording it a
-- second time.
--
-- The exact retained sample must still belong to the active same-scope bank.
-- Direct insertion performs Djex's input-only deduplication and MRU
-- promotion; this replay-established use receives the solver-independent
-- replay origin.
promoteBankReplayHit
  :: Eq sample
  => BankSurface bank scope sample bankError
  -> BankReplayHit scope sample counterexample
  -> BankState limits bank
  -> (BankState limits bank, Either (BankPromotionFailure bankError) ())
promoteBankReplayHit surface (BankReplayHitValue scope sample _counterexample)
    state =
  case bankStateActiveBank state of
    Nothing -> (state, Left BankPromotionScopeInvariant)
    Just bank
      | not $ surfaceMatchesScope surface scope bank ->
          (state, Left BankPromotionScopeInvariant)
      | sample `notElem` surfaceSamples surface bank ->
          (state, Left BankPromotionMembershipInvariant)
      | otherwise -> case surfaceInsertReplayedSample surface sample bank of
        Left failure ->
          (state, Left $ BankPromotionInsertionRejected failure)
        Right promoted -> (replaceBank promoted state, Right ())

-- | 'promoteBankReplayHit' as one serialized transition of the owner which
-- minted the hit.  The shared command tag ties the hit to that owner; a
-- failure leaves the owner's state unchanged.
promoteBankReplayHitInContext
  :: (Eq sample, NFData limits, NFData bank)
  => BankSurface bank scope sample bankError
  -> BankContextReplayHit command scope sample counterexample
  -> BankContext command limits bank
  -> IO (Either (BankPromotionFailure bankError) ())
promoteBankReplayHitInContext surface (BankContextReplayHitValue hit)
    (BankContext state) =
  transitionBankContext state $ promoteBankReplayHit surface hit

-- Shared recording ---------------------------------------------------------

-- | Coarse provenance for one freshly established receipt.  These labels
-- carry no evidence authority; Djex freshly replays before insertion.
data BankReceiptOrigin
  = BankReceiptFromLiveModel
  | BankReceiptFromSolverIndependentReplay
  | BankReceiptFromSimplificationReplay
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Why one fresh receipt was not recorded.  Scope invariant is a structural
-- failure after the active bank has been ensured; the remaining cases are
-- Djex's input-replay refusals and a receipt whose fresh replay against the
-- current query reproduced no counterexample.  Ordinary bounded
-- unavailability is reported through 'BankRecordOutcome' instead.
data BankRecordFailure evaluationError
  = BankRecordScopeInvariant
  | BankRecordEvaluationRejected !evaluationError
  | BankRecordAssociationRejected
  | BankRecordCounterexampleNotReproduced
  deriving (Eq, Ord, Show)

-- | Ordinary bounded recording outcomes.  Unavailable results retain no claim
-- that the supplied receipt was fresh for the current query.
data BankRecordOutcome counterexample bankError
  = BankRecorded !counterexample
  | BankRecordAttemptUnavailable !bankError
  | BankRecordInsertionUnavailable !bankError
  deriving (Eq, Show)

-- | Record one freshly established receipt in the active same-scope bank.
--
-- The state is first ensured for the query's scope.  Djex freshly replays the
-- receipt's inputs against the current query before inserting only those
-- inputs under the mapped origin; the bank returned by that recording bridge
-- replaces the active bank for every classification.
recordBankReceipt
  :: BankBridge limits bank scope sample counterexample bankError
      evaluationError
  -> BankReceiptOrigin
  -> counterexample
  -> BankState limits bank
  -> ( BankState limits bank
     , Either (BankRecordFailure evaluationError)
         (BankRecordOutcome counterexample bankError)
     )
recordBankReceipt bridge origin counterexample initial =
  case bankStateActiveBank ensured of
    Nothing -> (ensured, Left BankRecordScopeInvariant)
    Just bank ->
      let (successor, recorded) =
            bridgeRecordReceipt bridge origin counterexample bank
          successorState = replaceBank successor ensured
      in (successorState, mapRecordResult recorded)
 where
  ensured = ensureBankState bridge initial

  mapRecordResult recorded = case recorded of
    RecordStepScopeMismatch -> Left BankRecordScopeInvariant
    RecordStepAttemptRejected failure ->
      Right $ BankRecordAttemptUnavailable failure
    RecordStepEvaluationRejected failure ->
      Left $ BankRecordEvaluationRejected failure
    RecordStepAssociationRejected -> Left BankRecordAssociationRejected
    RecordStepCounterexampleNotReproduced ->
      Left BankRecordCounterexampleNotReproduced
    RecordStepInsertionRejected failure ->
      Right $ BankRecordInsertionUnavailable failure
    RecordStepRecorded fresh -> Right $ BankRecorded fresh

-- | 'recordBankReceipt' as one serialized transition of a mutable owner.  The
-- forced successor state is committed for both classifications.
recordBankReceiptInContext
  :: (NFData limits, NFData bank)
  => BankBridge limits bank scope sample counterexample bankError
      evaluationError
  -> BankReceiptOrigin
  -> counterexample
  -> BankContext command limits bank
  -> IO
      (Either (BankRecordFailure evaluationError)
        (BankRecordOutcome counterexample bankError))
recordBankReceiptInContext bridge origin counterexample
    (BankContext state) =
  transitionBankContext state $ recordBankReceipt bridge origin counterexample

-- Scalar ownership ---------------------------------------------------------

-- | Validated scalar limits and zero or one active same-scope bank.
type LengthCounterexampleBankState identity =
  BankState LengthCounterexampleBankLimits (LengthCounterexampleBank identity)

-- | An uninitialized scalar state owning the supplied validated limits and no
-- active bank.
emptyLengthCounterexampleBankState
  :: LengthCounterexampleBankLimits
  -> LengthCounterexampleBankState identity
emptyLengthCounterexampleBankState = emptyBankState

-- | 'emptyLengthCounterexampleBankState' at Djex's
-- 'defaultLengthCounterexampleBankLimits'.
defaultLengthCounterexampleBankState
  :: LengthCounterexampleBankState identity
defaultLengthCounterexampleBankState =
  emptyBankState defaultLengthCounterexampleBankLimits

-- | The scalar state's sole active bank.
lengthCounterexampleBankStateActiveBank
  :: LengthCounterexampleBankState identity
  -> Maybe (LengthCounterexampleBank identity)
lengthCounterexampleBankStateActiveBank = bankStateActiveBank

-- | One command-owned mutable scalar bank.
type LengthCounterexampleBankContext command identity =
  BankContext
    command LengthCounterexampleBankLimits (LengthCounterexampleBank identity)

-- | Introduce a fresh empty scalar owner with caller-validated limits.
withLengthCounterexampleBankContext
  :: LengthCounterexampleBankLimits
  -> (forall command.
      LengthCounterexampleBankContext command identity -> IO result)
  -> IO result
withLengthCounterexampleBankContext = withBankContext

-- | 'withLengthCounterexampleBankContext' at Djex's
-- 'defaultLengthCounterexampleBankLimits'.
withDefaultLengthCounterexampleBankContext
  :: (forall command.
      LengthCounterexampleBankContext command identity -> IO result)
  -> IO result
withDefaultLengthCounterexampleBankContext =
  withBankContext defaultLengthCounterexampleBankLimits

-- | Take an immutable diagnostic snapshot of a scalar owner.
readLengthCounterexampleBankContextState
  :: LengthCounterexampleBankContext command identity
  -> IO (LengthCounterexampleBankState identity)
readLengthCounterexampleBankContextState = readBankContextState

-- | One ordinary per-sample scalar refusal.
type LengthCounterexampleBankReplayRefusal =
  BankReplayRefusal LengthEvaluationError

-- | One exact retained scalar sample and the fresh current-query receipt
-- produced by replaying it.
type LengthCounterexampleBankReplayHit identity =
  BankReplayHit
    (LengthCounterexampleBankScope identity)
    LengthCounterexampleBankSample
    ValidatedLengthCounterexample

-- | The fresh current-query receipt established by replaying the hit's
-- retained scalar sample.
lengthCounterexampleBankReplayHitCounterexample
  :: LengthCounterexampleBankReplayHit identity
  -> ValidatedLengthCounterexample
lengthCounterexampleBankReplayHitCounterexample = bankReplayHitCounterexample

-- | Whole-bank scalar replay result.
type LengthCounterexampleBankReplayOutcome identity =
  BankReplayOutcome
    LengthEvaluationError
    LengthCounterexampleBankError
    (LengthCounterexampleBankReplayHit identity)

-- | A scalar replay hit tied to the fresh command owner which produced it.
type LengthCounterexampleBankContextReplayHit command identity =
  BankContextReplayHit
    command
    (LengthCounterexampleBankScope identity)
    LengthCounterexampleBankSample
    ValidatedLengthCounterexample

-- | The fresh current-query receipt carried by a command-nominal scalar
-- replay hit.
lengthCounterexampleBankContextReplayHitCounterexample
  :: LengthCounterexampleBankContextReplayHit command identity
  -> ValidatedLengthCounterexample
lengthCounterexampleBankContextReplayHitCounterexample =
  bankContextReplayHitCounterexample

-- | Scalar context replay keeps the established refusal and
-- bounded-unavailability vocabulary while making a successful hit
-- command-nominal.
type LengthCounterexampleBankContextReplayOutcome command identity =
  BankReplayOutcome
    LengthEvaluationError
    LengthCounterexampleBankError
    (LengthCounterexampleBankContextReplayHit command identity)

-- | Why one explicit scalar replay hit was not promoted.
type LengthCounterexampleBankPromotionFailure =
  BankPromotionFailure LengthCounterexampleBankError

-- | Why one fresh scalar receipt was not recorded.
type LengthCounterexampleBankRecordFailure =
  BankRecordFailure LengthEvaluationError

-- | Ordinary bounded scalar recording outcomes.
type LengthCounterexampleBankRecordOutcome =
  BankRecordOutcome ValidatedLengthCounterexample LengthCounterexampleBankError

-- | Djex's query-free scalar bank surface.
scalarBankSurface
  :: BankSurface
      (LengthCounterexampleBank identity)
      (LengthCounterexampleBankScope identity)
      LengthCounterexampleBankSample
      LengthCounterexampleBankError
scalarBankSurface = BankSurface
  { surfaceMatchesScope = lengthCounterexampleBankMatchesScope
  , surfaceSamples = lengthCounterexampleBankSamples
  , surfaceInsertReplayedSample = \sample ->
      insertLengthCounterexampleBankSample
        lengthCounterexampleBankSolverIndependentReplayOrigin
        (lengthCounterexampleBankSampleInputs sample)
  }

-- | Djex's scalar bank vocabulary for one query: the bridges the shared
-- transitions call, and the translation of Djex's scalar replay and recording
-- refusals into the shared classification.
scalarBankBridge
  :: LengthEvaluationLimits
  -> LengthSMTLibQuery identity local
  -> BankBridge
      LengthCounterexampleBankLimits
      (LengthCounterexampleBank identity)
      (LengthCounterexampleBankScope identity)
      LengthCounterexampleBankSample
      ValidatedLengthCounterexample
      LengthCounterexampleBankError
      LengthEvaluationError
scalarBankBridge evaluationLimits query = BankBridge
  { bridgeSurface = scalarBankSurface
  , bridgeQueryScope = lengthSMTLibQueryCounterexampleBankScope query
  , bridgeEmptyBank = emptyLengthCounterexampleBank
  , bridgeReplaySample = \sample bank ->
      classifyReplay
        $ replayLengthSMTLibCounterexampleBankSample
            evaluationLimits query sample bank
  , bridgeRecordReceipt = \origin counterexample bank ->
      classifyRecord
        $ recordLengthSMTLibQueryCounterexampleInBank
            evaluationLimits query (scalarReceiptOrigin origin)
            counterexample bank
  }
 where
  classifyReplay (successor, replayed) = (,) successor $ case replayed of
    Left LengthSMTLibCounterexampleBankSampleReplayScopeMismatch ->
      ReplayStepScopeMismatch
    Left LengthSMTLibCounterexampleBankSampleReplaySampleNotRetained ->
      ReplayStepSampleNotRetained
    Left
        (LengthSMTLibCounterexampleBankSampleReplayAttemptRejected failure) ->
      ReplayStepAttemptRejected failure
    Left (LengthSMTLibCounterexampleBankSampleReplayInputRejected failure) ->
      case failure of
        LengthSMTLibInputReplayEvaluationRejected evaluationFailure ->
          ReplayStepEvaluationRefused evaluationFailure
        LengthSMTLibInputReplayAssociationRejected _ ->
          ReplayStepAssociationRefused
    Right Nothing -> ReplayStepNoCounterexample
    Right (Just counterexample) -> ReplayStepCounterexample counterexample

  classifyRecord (successor, recorded) = (,) successor $ case recorded of
    Left LengthSMTLibCounterexampleBankRecordScopeMismatch ->
      RecordStepScopeMismatch
    Left (LengthSMTLibCounterexampleBankRecordAttemptRejected failure) ->
      RecordStepAttemptRejected failure
    Left (LengthSMTLibCounterexampleBankRecordInputReplayRejected failure) ->
      case failure of
        LengthSMTLibInputReplayEvaluationRejected evaluationFailure ->
          RecordStepEvaluationRejected evaluationFailure
        LengthSMTLibInputReplayAssociationRejected _ ->
          RecordStepAssociationRejected
    Left LengthSMTLibCounterexampleBankRecordCounterexampleNotReproduced ->
      RecordStepCounterexampleNotReproduced
    Left (LengthSMTLibCounterexampleBankRecordInsertionRejected failure) ->
      RecordStepInsertionRejected failure
    Right fresh -> RecordStepRecorded fresh

-- | Replay the active scalar bank's exact retained samples newest first.
replayLengthCounterexampleBank
  :: LengthEvaluationLimits
  -> LengthSMTLibQuery identity local
  -> LengthCounterexampleBankState identity
  -> ( LengthCounterexampleBankState identity
     , Either BankReplayFailure
         (LengthCounterexampleBankReplayOutcome identity)
     )
replayLengthCounterexampleBank evaluationLimits query =
  replayBank $ scalarBankBridge evaluationLimits query

-- | Replay through one mutable scalar owner.
replayLengthCounterexampleBankInContext
  :: LengthEvaluationLimits
  -> LengthSMTLibQuery identity local
  -> LengthCounterexampleBankContext command identity
  -> IO
      (Either BankReplayFailure
        (LengthCounterexampleBankContextReplayOutcome command identity))
replayLengthCounterexampleBankInContext evaluationLimits query =
  replayBankInContext $ scalarBankBridge evaluationLimits query

-- | Promote one explicit scalar replay hit without replaying or recording it
-- a second time.
promoteLengthCounterexampleBankReplayHit
  :: LengthCounterexampleBankReplayHit identity
  -> LengthCounterexampleBankState identity
  -> ( LengthCounterexampleBankState identity
     , Either LengthCounterexampleBankPromotionFailure ()
     )
promoteLengthCounterexampleBankReplayHit =
  promoteBankReplayHit scalarBankSurface

-- | 'promoteLengthCounterexampleBankReplayHit' as one serialized transition
-- of the owner which minted the hit.
promoteLengthCounterexampleBankReplayHitInContext
  :: LengthCounterexampleBankContextReplayHit command identity
  -> LengthCounterexampleBankContext command identity
  -> IO (Either LengthCounterexampleBankPromotionFailure ())
promoteLengthCounterexampleBankReplayHitInContext =
  promoteBankReplayHitInContext scalarBankSurface

-- | Record one freshly established scalar receipt in the active same-scope
-- bank.
recordLengthCounterexampleBankReceipt
  :: LengthEvaluationLimits
  -> LengthSMTLibQuery identity local
  -> BankReceiptOrigin
  -> ValidatedLengthCounterexample
  -> LengthCounterexampleBankState identity
  -> ( LengthCounterexampleBankState identity
     , Either LengthCounterexampleBankRecordFailure
         LengthCounterexampleBankRecordOutcome
     )
recordLengthCounterexampleBankReceipt evaluationLimits query =
  recordBankReceipt $ scalarBankBridge evaluationLimits query

-- | 'recordLengthCounterexampleBankReceipt' as one serialized transition of a
-- mutable scalar owner.
recordLengthCounterexampleBankReceiptInContext
  :: LengthEvaluationLimits
  -> LengthSMTLibQuery identity local
  -> BankReceiptOrigin
  -> ValidatedLengthCounterexample
  -> LengthCounterexampleBankContext command identity
  -> IO
      (Either LengthCounterexampleBankRecordFailure
        LengthCounterexampleBankRecordOutcome)
recordLengthCounterexampleBankReceiptInContext evaluationLimits query =
  recordBankReceiptInContext $ scalarBankBridge evaluationLimits query

scalarReceiptOrigin
  :: BankReceiptOrigin
  -> LengthCounterexampleBankOrigin
scalarReceiptOrigin origin = case origin of
  BankReceiptFromLiveModel -> lengthCounterexampleBankLiveModelReplayOrigin
  BankReceiptFromSolverIndependentReplay ->
    lengthCounterexampleBankSolverIndependentReplayOrigin
  BankReceiptFromSimplificationReplay ->
    lengthCounterexampleBankSimplificationReplayOrigin

-- Binary-product ownership -------------------------------------------------

-- | Validated binary-product limits and zero or one active same-scope bank.
type LengthSpinePairCounterexampleBankState identity =
  BankState
    LengthSpinePairCounterexampleBankLimits
    (LengthSpinePairCounterexampleBank identity)

-- | An uninitialized binary-product state owning the supplied validated
-- limits and no active bank.
emptyLengthSpinePairCounterexampleBankState
  :: LengthSpinePairCounterexampleBankLimits
  -> LengthSpinePairCounterexampleBankState identity
emptyLengthSpinePairCounterexampleBankState = emptyBankState

-- | 'emptyLengthSpinePairCounterexampleBankState' at Djex's
-- 'defaultLengthSpinePairCounterexampleBankLimits'.
defaultLengthSpinePairCounterexampleBankState
  :: LengthSpinePairCounterexampleBankState identity
defaultLengthSpinePairCounterexampleBankState =
  emptyBankState defaultLengthSpinePairCounterexampleBankLimits

-- | The binary-product state's sole active bank.
lengthSpinePairCounterexampleBankStateActiveBank
  :: LengthSpinePairCounterexampleBankState identity
  -> Maybe (LengthSpinePairCounterexampleBank identity)
lengthSpinePairCounterexampleBankStateActiveBank = bankStateActiveBank

-- | One command-owned mutable binary-product bank.
type LengthSpinePairCounterexampleBankContext command identity =
  BankContext
    command
    LengthSpinePairCounterexampleBankLimits
    (LengthSpinePairCounterexampleBank identity)

-- | Introduce a fresh empty binary-product owner with caller-validated limits.
withLengthSpinePairCounterexampleBankContext
  :: LengthSpinePairCounterexampleBankLimits
  -> (forall command.
      LengthSpinePairCounterexampleBankContext command identity -> IO result)
  -> IO result
withLengthSpinePairCounterexampleBankContext = withBankContext

-- | 'withLengthSpinePairCounterexampleBankContext' at Djex's
-- 'defaultLengthSpinePairCounterexampleBankLimits'.
withDefaultLengthSpinePairCounterexampleBankContext
  :: (forall command.
      LengthSpinePairCounterexampleBankContext command identity -> IO result)
  -> IO result
withDefaultLengthSpinePairCounterexampleBankContext =
  withBankContext defaultLengthSpinePairCounterexampleBankLimits

-- | Take an immutable diagnostic snapshot of a binary-product owner.
readLengthSpinePairCounterexampleBankContextState
  :: LengthSpinePairCounterexampleBankContext command identity
  -> IO (LengthSpinePairCounterexampleBankState identity)
readLengthSpinePairCounterexampleBankContextState = readBankContextState

-- | One ordinary per-sample binary-product refusal.
type LengthSpinePairCounterexampleBankReplayRefusal =
  BankReplayRefusal LengthSpinePairEvaluationError

-- | One exact retained binary-product sample and the fresh current-query
-- receipt produced by replaying it.
type LengthSpinePairCounterexampleBankReplayHit identity =
  BankReplayHit
    (LengthSpinePairCounterexampleBankScope identity)
    LengthSpinePairCounterexampleBankSample
    ValidatedLengthSpinePairCounterexample

-- | The fresh current-query receipt established by replaying the hit's
-- retained binary-product sample.
lengthSpinePairCounterexampleBankReplayHitCounterexample
  :: LengthSpinePairCounterexampleBankReplayHit identity
  -> ValidatedLengthSpinePairCounterexample
lengthSpinePairCounterexampleBankReplayHitCounterexample =
  bankReplayHitCounterexample

-- | Whole-bank binary-product replay result.
type LengthSpinePairCounterexampleBankReplayOutcome identity =
  BankReplayOutcome
    LengthSpinePairEvaluationError
    LengthSpinePairCounterexampleBankError
    (LengthSpinePairCounterexampleBankReplayHit identity)

-- | A binary-product replay hit tied to the fresh command owner which
-- produced it.
type LengthSpinePairCounterexampleBankContextReplayHit command identity =
  BankContextReplayHit
    command
    (LengthSpinePairCounterexampleBankScope identity)
    LengthSpinePairCounterexampleBankSample
    ValidatedLengthSpinePairCounterexample

-- | The fresh current-query receipt carried by a command-nominal
-- binary-product replay hit.
lengthSpinePairCounterexampleBankContextReplayHitCounterexample
  :: LengthSpinePairCounterexampleBankContextReplayHit command identity
  -> ValidatedLengthSpinePairCounterexample
lengthSpinePairCounterexampleBankContextReplayHitCounterexample =
  bankContextReplayHitCounterexample

-- | Binary-product context replay keeps the established refusal and
-- bounded-unavailability vocabulary while making a successful hit
-- command-nominal.
type LengthSpinePairCounterexampleBankContextReplayOutcome command identity =
  BankReplayOutcome
    LengthSpinePairEvaluationError
    LengthSpinePairCounterexampleBankError
    (LengthSpinePairCounterexampleBankContextReplayHit command identity)

-- | Why one explicit binary-product replay hit was not promoted.
type LengthSpinePairCounterexampleBankPromotionFailure =
  BankPromotionFailure LengthSpinePairCounterexampleBankError

-- | Why one fresh binary-product receipt was not recorded.
type LengthSpinePairCounterexampleBankRecordFailure =
  BankRecordFailure LengthSpinePairEvaluationError

-- | Ordinary bounded binary-product recording outcomes.
type LengthSpinePairCounterexampleBankRecordOutcome =
  BankRecordOutcome
    ValidatedLengthSpinePairCounterexample
    LengthSpinePairCounterexampleBankError

-- | Djex's query-free binary-product bank surface.
spinePairBankSurface
  :: BankSurface
      (LengthSpinePairCounterexampleBank identity)
      (LengthSpinePairCounterexampleBankScope identity)
      LengthSpinePairCounterexampleBankSample
      LengthSpinePairCounterexampleBankError
spinePairBankSurface = BankSurface
  { surfaceMatchesScope = lengthSpinePairCounterexampleBankMatchesScope
  , surfaceSamples = lengthSpinePairCounterexampleBankSamples
  , surfaceInsertReplayedSample = \sample ->
      insertLengthSpinePairCounterexampleBankSample
        lengthSpinePairCounterexampleBankSolverIndependentReplayOrigin
        (lengthSpinePairCounterexampleBankSampleInputs sample)
  }

-- | Djex's binary-product bank vocabulary for one query: the bridges the
-- shared transitions call, and the translation of Djex's binary-product
-- replay and recording refusals into the shared classification.
spinePairBankBridge
  :: LengthEvaluationLimits
  -> LengthSpinePairSMTLibQuery identity local
  -> BankBridge
      LengthSpinePairCounterexampleBankLimits
      (LengthSpinePairCounterexampleBank identity)
      (LengthSpinePairCounterexampleBankScope identity)
      LengthSpinePairCounterexampleBankSample
      ValidatedLengthSpinePairCounterexample
      LengthSpinePairCounterexampleBankError
      LengthSpinePairEvaluationError
spinePairBankBridge evaluationLimits query = BankBridge
  { bridgeSurface = spinePairBankSurface
  , bridgeQueryScope = lengthSpinePairSMTLibQueryCounterexampleBankScope query
  , bridgeEmptyBank = emptyLengthSpinePairCounterexampleBank
  , bridgeReplaySample = \sample bank ->
      classifyReplay
        $ replayLengthSpinePairSMTLibCounterexampleBankSample
            evaluationLimits query sample bank
  , bridgeRecordReceipt = \origin counterexample bank ->
      classifyRecord
        $ recordLengthSpinePairSMTLibQueryCounterexampleInBank
            evaluationLimits query (spinePairReceiptOrigin origin)
            counterexample bank
  }
 where
  classifyReplay (successor, replayed) = (,) successor $ case replayed of
    Left LengthSpinePairSMTLibCounterexampleBankSampleReplayScopeMismatch ->
      ReplayStepScopeMismatch
    Left
        LengthSpinePairSMTLibCounterexampleBankSampleReplaySampleNotRetained ->
      ReplayStepSampleNotRetained
    Left
        (LengthSpinePairSMTLibCounterexampleBankSampleReplayAttemptRejected
          failure) ->
      ReplayStepAttemptRejected failure
    Left
        (LengthSpinePairSMTLibCounterexampleBankSampleReplayInputRejected
          failure) ->
      case failure of
        LengthSpinePairSMTLibInputReplayEvaluationRejected evaluationFailure ->
          ReplayStepEvaluationRefused evaluationFailure
        LengthSpinePairSMTLibInputReplayAssociationRejected _ ->
          ReplayStepAssociationRefused
    Right Nothing -> ReplayStepNoCounterexample
    Right (Just counterexample) -> ReplayStepCounterexample counterexample

  classifyRecord (successor, recorded) = (,) successor $ case recorded of
    Left LengthSpinePairSMTLibCounterexampleBankRecordScopeMismatch ->
      RecordStepScopeMismatch
    Left
        (LengthSpinePairSMTLibCounterexampleBankRecordAttemptRejected
          failure) ->
      RecordStepAttemptRejected failure
    Left
        (LengthSpinePairSMTLibCounterexampleBankRecordInputReplayRejected
          failure) ->
      case failure of
        LengthSpinePairSMTLibInputReplayEvaluationRejected evaluationFailure ->
          RecordStepEvaluationRejected evaluationFailure
        LengthSpinePairSMTLibInputReplayAssociationRejected _ ->
          RecordStepAssociationRejected
    Left
        LengthSpinePairSMTLibCounterexampleBankRecordCounterexampleNotReproduced
        ->
      RecordStepCounterexampleNotReproduced
    Left
        (LengthSpinePairSMTLibCounterexampleBankRecordInsertionRejected
          failure) ->
      RecordStepInsertionRejected failure
    Right fresh -> RecordStepRecorded fresh

-- | Replay the active binary-product bank's exact retained samples newest
-- first.
replayLengthSpinePairCounterexampleBank
  :: LengthEvaluationLimits
  -> LengthSpinePairSMTLibQuery identity local
  -> LengthSpinePairCounterexampleBankState identity
  -> ( LengthSpinePairCounterexampleBankState identity
     , Either BankReplayFailure
         (LengthSpinePairCounterexampleBankReplayOutcome identity)
     )
replayLengthSpinePairCounterexampleBank evaluationLimits query =
  replayBank $ spinePairBankBridge evaluationLimits query

-- | Replay through one mutable binary-product owner.
replayLengthSpinePairCounterexampleBankInContext
  :: LengthEvaluationLimits
  -> LengthSpinePairSMTLibQuery identity local
  -> LengthSpinePairCounterexampleBankContext command identity
  -> IO
      (Either BankReplayFailure
        (LengthSpinePairCounterexampleBankContextReplayOutcome
          command identity))
replayLengthSpinePairCounterexampleBankInContext evaluationLimits query =
  replayBankInContext $ spinePairBankBridge evaluationLimits query

-- | Promote one explicit binary-product replay hit without replaying or
-- recording it a second time.
promoteLengthSpinePairCounterexampleBankReplayHit
  :: LengthSpinePairCounterexampleBankReplayHit identity
  -> LengthSpinePairCounterexampleBankState identity
  -> ( LengthSpinePairCounterexampleBankState identity
     , Either LengthSpinePairCounterexampleBankPromotionFailure ()
     )
promoteLengthSpinePairCounterexampleBankReplayHit =
  promoteBankReplayHit spinePairBankSurface

-- | 'promoteLengthSpinePairCounterexampleBankReplayHit' as one serialized
-- transition of the owner which minted the hit.
promoteLengthSpinePairCounterexampleBankReplayHitInContext
  :: LengthSpinePairCounterexampleBankContextReplayHit command identity
  -> LengthSpinePairCounterexampleBankContext command identity
  -> IO (Either LengthSpinePairCounterexampleBankPromotionFailure ())
promoteLengthSpinePairCounterexampleBankReplayHitInContext =
  promoteBankReplayHitInContext spinePairBankSurface

-- | Record one freshly established binary-product receipt in the active
-- same-scope bank.
recordLengthSpinePairCounterexampleBankReceipt
  :: LengthEvaluationLimits
  -> LengthSpinePairSMTLibQuery identity local
  -> BankReceiptOrigin
  -> ValidatedLengthSpinePairCounterexample
  -> LengthSpinePairCounterexampleBankState identity
  -> ( LengthSpinePairCounterexampleBankState identity
     , Either LengthSpinePairCounterexampleBankRecordFailure
         LengthSpinePairCounterexampleBankRecordOutcome
     )
recordLengthSpinePairCounterexampleBankReceipt evaluationLimits query =
  recordBankReceipt $ spinePairBankBridge evaluationLimits query

-- | 'recordLengthSpinePairCounterexampleBankReceipt' as one serialized
-- transition of a mutable binary-product owner.
recordLengthSpinePairCounterexampleBankReceiptInContext
  :: LengthEvaluationLimits
  -> LengthSpinePairSMTLibQuery identity local
  -> BankReceiptOrigin
  -> ValidatedLengthSpinePairCounterexample
  -> LengthSpinePairCounterexampleBankContext command identity
  -> IO
      (Either LengthSpinePairCounterexampleBankRecordFailure
        LengthSpinePairCounterexampleBankRecordOutcome)
recordLengthSpinePairCounterexampleBankReceiptInContext evaluationLimits
    query =
  recordBankReceiptInContext $ spinePairBankBridge evaluationLimits query

spinePairReceiptOrigin
  :: BankReceiptOrigin
  -> LengthSpinePairCounterexampleBankOrigin
spinePairReceiptOrigin origin = case origin of
  BankReceiptFromLiveModel ->
    lengthSpinePairCounterexampleBankLiveModelReplayOrigin
  BankReceiptFromSolverIndependentReplay ->
    lengthSpinePairCounterexampleBankSolverIndependentReplayOrigin
  BankReceiptFromSimplificationReplay ->
    lengthSpinePairCounterexampleBankSimplificationReplayOrigin
