# Live canonical-`Prod` Length ranking

Date: 2026-08-14

> **Later 2026-08-14 follow-up.** Startup v8 now composes this nominal pair
> runner with positive-affine applicable-domain validation, counterexample
> simplification, both non-vacuous preferences, and deferred session opening.
> Pair evidence and MRU state remain disjoint from scalar v7. See the
> [positive-affine deferred Length ranking report](2026-08-14-positive-affine-deferred-length-ranking.md).

> **Later 2026-08-14 follow-up.** The reusable policy can now insert Djex's
> nominal pair applicable-domain validation after the pair MRU bank and before
> origin/live execution. Pair counterexample and establishment receipts remain
> distinct from scalar evidence; establishment is neutral unless its separate
> non-vacuous preference is enabled. Startup versions 1--6 cannot select the
> pass. See the
> [directly bounded applicable-domain report](2026-08-14-directly-bounded-length-applicable-domain.md).
>
> **Later 2026-08-14 follow-up.** Pair bounded-positive receipts remain neutral
> under startup v4 and the established API. Startup v6 or the explicit policy
> builder now stably prefers only a pair receipt with a positive applicable
> count; vacuous positives remain neutral and pair counterexamples remain
> demoted. See the
> [non-vacuous bounded-positive ordering report](2026-08-14-non-vacuous-bounded-positive-ordering.md).
>
> **Later 2026-08-14 follow-up.** Main now exposes this nominal pair runner
> through startup configuration version 4 and contract-only version 6. The new
> generalized decoders dispatch a passive scalar-or-pair selection while the
> established scalar decoders remain exact and reject the new versions. See the
> [binary-product Length configuration report](2026-08-14-binary-product-length-configuration.md).
>
> **Later 2026-08-14 follow-up.** A programmatic policy can finalize every
> product counterexample source through Djex's nominal query-owned bounded
> simplifier. A strict reduction supplies the ordinary final pair receipt and
> its inputs to the unchanged pair-local MRU bank; metadata remains attached
> to the same occurrence for presentation. See the
> [bounded counterexample simplification report](2026-08-14-bounded-length-counterexample-simplification.md).

## Outcome

Leant now consumes Djex's live
`finite-binary-product-spine-lengths/v1` facade through a conservative,
product-specific ranking path. A callback-verified candidate must first pass
the established exact canonical-`Prod` handoff: after Lean normalization the
result root is saturated built-in `Prod`, both source-ordered fields are exact
applications of the configured finite spine, and the candidate remains bound
to its exact typed Exference origin and accepted renderer occurrence.

The public library surface is split by responsibility:

- `Leant.Synth.Length.SpinePair.Ranking` exposes pair assessments, opaque
  ranked candidates and failures, and direct live runners;
- `Leant.Synth.Length.Configuration` dispatches the existing opaque
  `LengthRankingPolicy` to either its scalar or pair-specific runner;
- `Leant.Synth.Length.SpinePair.PostVerification` keeps reordered pair
  assessments attached to their callback occurrences through the existing
  generative permutation seal; and
- `Leant.Synth.Length.Presentation` projects pair receipts to bounded terminal
  notes without separating evidence from the candidate which produced it.

This was initially an additive library checkpoint: Main did not yet select the
pair domain, startup ranking configuration versions 1--3 and contract-only
versions 1--5 remained scalar-only, and startup version 4 plus contract-only
version 6 were reserved for the later file-boundary checkpoint linked above.

## Concrete policy entrance

The execution/evaluation policy contains no scalar behavioral contract, so the
same checked policy can be supplied with an explicit product contract. An
occurrence-safe caller can enable both optional replay stages and assess a
verified callback batch as follows:

```haskell
let pairPolicy =
      enableLengthRankingOriginProbe
        $ enableLengthRankingInputBoxValidation
            inputBoxLimits [3] basePolicy

assessment <- assessVerifiedLengthSpinePairCandidatesWithPolicy
  pairPolicy pairContract verificationBatch

let present candidate = do
      putStrLn $ lengthCandidatePresentationText candidate
      mapM_ putStrLn $ lengthCandidatePresentationNote candidate

mapM_ present
  $ presentLengthSpinePairPostVerificationResult assessment
```

`basePolicy` must already have been returned by `mkLengthRankingPolicy`, and
`inputBoxLimits` must be a checked Djex `LengthInputBoxLimits`. In this unary
example, `[3]` requests the source-ordered input interval zero through three.
The passive `pairContract` cannot make an arbitrary verified candidate
eligible; every candidate must still pass exact handoff and pair-query sealing.

Callers which own a plain list of
`Verified DetailedVerificationVariant` values can instead use
`rankVerifiedLengthSpinePairCandidatesWithPolicy`. The direct lower-level
entrances `rankVerifiedLengthSpinePairCandidates` and
`rankVerifiedLengthSpinePairCandidatesWithInputBoxValidation` accept already
checked Djex execution/evaluation components. The post-verification entrance
is preferred when a caller needs to preserve exact callback-occurrence
ownership across reordering.

## Admission, preparation, and worker ownership

The pair runner productively admits at most Djex's public 64-query live-session
maximum. A maximum-plus-one input is rejected before the contract or candidate
payloads are traversed. For an admitted batch, every candidate is prepared in
source order through `prepareCheckedLengthSpinePairQuery` before any child
process is launched. Empty and all-ineligible batches open no worker; local
handoff or query-construction refusals remain bounded, payload-free
`LengthPreparationRefusalClass` values on those candidates.

If at least one candidate is eligible, the run opens one fresh lexical
`LengthSMTLibLiveSession`. Scalar and pair runs reuse the same opaque execution
policy, capability-probed worker implementation, lifecycle rules, and total
session query limit. This is one shared limit, not an additional allowance per
behavioral domain. Leant's scalar and pair policy runners each open their own
fresh session, however: they do not retain a worker in the policy or combine
their batch-local replay state.

The common process capability conveys only exact QF_LIA/input-value transport
readiness. It does not convert a scalar query into a pair query or transfer
behavioral evidence between domains. Every live transaction in this path uses
Djex's product query, product run identity, product response interpretation,
and product observation replay boundary.

## Exact per-candidate order

Eligible pair candidates are visited serially in original callback order. The
configured state machine is:

1. try at most four source-ordered natural input vectors from the product
   batch's newest-first MRU bank;
2. if all miss and the policy enables it, ask the exact pair query to probe its
   canonical all-zero origin;
3. if that misses, issue one live product query in the shared lexical session;
4. replay the resulting observation against the exact query before inspecting
   its solver status; and
5. only when replay found no counterexample, the live status is `unsat`, and
   the policy enables it, run the pair query's independent finite input-box
   validation.

Each MRU attempt calls the product-specific query-owned input replay entrance.
An arity rejection, evaluation rejection, association rejection, or honest
non-counterexample is only a bank miss because a vector learned from an earlier
candidate need not apply to this one. A hit creates a fresh pair receipt under
the later query and avoids that candidate's live transaction. The bank stores
only at most four `[Natural]` vectors; it stores no scalar or product receipt,
query, fingerprint, provider basis, solver status, verdict, transcript, or
process fact. It is neither durable nor shared with a scalar batch.

The optional origin probe differs from a bank attempt because its vector is
derived by the current pair query. A miss contributes no evidence and proceeds
to live Z3. An evaluation or association rejection is therefore an indexed
operational failure rather than a cache miss. A bank or origin hit skips a live
transaction and ordinal, but the lexical worker has already opened and passed
its capability probe before serial candidate processing begins.

Live observation handling is query-first. Leant calls
`replayLengthSpinePairSMTLibLiveQueryObservation` with the exact prepared query;
Djex first binds the observation to that query fingerprint and independently
binds any optional behavioral evidence to the retained pair problem. Only
after a successful replay which returned no counterexample does Leant inspect
`sat`, `unsat`, or `unknown`. Thus a raw solver status never acquires evidence
authority, and `unsat` is at most a scheduling trigger for the separately
checked finite box.

## Assessments and stable ordering

`LengthSpinePairRankingAssessment` has four closed outcomes:

- `LengthSpinePairCounterexample` carries an independently replayed and
  associated `ValidatedLengthSpinePairCounterexample`;
- `LengthSpinePairBoundedPositive` carries the result of complete independent
  traversal of the configured finite input box;
- `LengthSpinePairHeuristic` records a status which supplied no replayed
  counterexample; and
- `LengthSpinePairUnassessed` records that no behavioral assessment was
  released.

Only `LengthSpinePairCounterexample` affects ordering. Its exact input vector
is inserted or promoted in the product MRU bank, and successful output uses a
stable partition which moves all counterexample-bearing candidates behind all
other candidates while preserving order inside both partitions. A live model,
an origin probe, a prior-input replay, or a post-`unsat` box traversal can
supply that receipt only through the same pair-specific independent evaluator
and association gate.

Complete finite-box traversal is bounded positive information, not a universal
proof or a promotion signal. It stays in the neutral partition and supplies no
MRU seed. Status-only `sat`, `unsat`, and `unknown` are likewise neutral.
Candidates are never pruned, and no assessment claims Lean execution,
termination, source-language equivalence, provider-law validity, a kernel
theorem, or Z3 soundness.

## Atomic fallback and occurrence ownership

A structured session-open, live-query, query-association, evidence-replay,
origin-evaluation, or input-box failure aborts behavioral assessment for the
whole admitted batch. The result restores every candidate in original order as
unassessed and retains only a sanitized failure class, cleanup-incomplete bit,
and optional safe original index. Candidate-local pure preparation refusal
classes remain attached; successfully prepared candidates gain no invented
refusal. Earlier MRU, origin, live, or box successes cannot escape this atomic
fallback. Synchronous exceptions continue to propagate rather than being
misrepresented as a ranking.

The post-verification adapter retains batch-scoped occurrence handles through
preparation, live assessment, stable demotion, and fallback. It accepts a
ranking only after sealing the final permutation against the original callback
batch, then materializes the public receipt-bearing view. Presentation consumes
those whole ranked values. It never zips candidate strings to a detached list
of pair evidence.

`renderLengthSpinePairCounterexampleNote` reports the source-ordered first and
second result lengths beside the observed input lengths and a provider-law
count. `renderLengthSpinePairInputBoxValidationNote` reports inclusive maxima,
checked and applicable assignment counts, and explicit finite-box vacuity. Both
remain within the established 384-character terminal ceiling and call their
claims bounded/model-relative. Heuristic, unassessed, disabled, rejected, and
atomic-fallback output receives no semantic note.

## Product authority and scalar compatibility

The product path reuses scalar infrastructure only where it is genuinely
domain-neutral: execution admission, executable configuration, evaluation
limits, optional origin/box policy choices, the common live-session capability,
the candidate-count/query budget, and bounded sanitized diagnostic vocabulary.
The exact `LeanLengthSpinePairContract` remains a separate request assertion.

Behavioral authority remains nominally pair-specific throughout. The checked
product problem, QF_LIA query, run and observation identities, decoded result,
counterexample and positive receipts, ranking assessment, failure, MRU state,
post-verification result, and pair presentation renderer cannot be cast from
their scalar siblings. Both result fields remain in source order, and only the
exact canonical-`Prod` provenance gate can authorize this handoff.

The scalar ranking modules, public constructors, query bytes, replay bank,
origin and input-box orchestration, stable ordering, failure behavior, and
presentation remain unchanged. Reusing one opaque policy for a scalar request
and a later pair request does not share a worker, a contract, a query budget
between those separate calls, or any evidence. Within any one Djex session,
however, scalar and product transactions consume the same configured total
query counter; the domain distinction never doubles that capability budget.

## Configuration work deferred at this checkpoint

This checkpoint intentionally does not:

- add a product form to Main's startup `--length-ranking-config` decoder;
- add a product form to the command-local `--length-contract` decoder;
- activate product ranking automatically from a Lean result type;
- infer a product contract from `Prod` syntax; or
- retain a product policy or contract in interactive state.

The later configuration checkpoint resolves the first two items with startup
version 4 and contract-only version 6. It deliberately leaves the remaining
three items unchanged: selection is explicit, no product contract is inferred
from Lean syntax, and no contract is retained in interactive state. Existing
scalar file versions and scalar-only compatibility decoders still reject the
new product versions and fields.
