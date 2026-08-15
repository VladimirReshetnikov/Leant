# Scoped usable-work budget for Length ranking

Date: 2026-08-15

## Outcome

Leant can now run one scalar or canonical-`Prod` Length ranking batch beneath
Djex's owner-thread-affine, dynamically scoped usable-work deadline. The new
strategy keeps one absolute monotonic deadline across complete candidate
preparation, the deferred pure ranking prefix, worker opening, every scalar or
product transaction, and ranking-owned result materialization. Leant adds
cooperative checks between bounded phases so an all-pure batch also observes
the shared deadline without opening Z3.

The public pure policy builder is:

```haskell
enableLengthRankingScopedUsableWorkBudget
  :: LengthSMTLibLiveUsableWorkBudget
  -> LengthRankingPolicy
  -> LengthRankingPolicy
```

It accepts the same already validated opaque duration as the established v1
builder, but retains a distinct private strategy. Applying either budget
builder again is last-wins across v1 and v2. Execution, evaluation, domain,
ordering, replay, simplification, and session-opening selections are otherwise
preserved. Building a policy reads no clock, performs no IO, and creates no
assessment or evidence.

This report describes Leant production commit `c865ee8` against Djex's scoped
deadline implementation and characterization through `f19c5fc1`.

## Compatibility matrix

Startup versions select closed schemas and runtime routes rather than
cumulative feature levels:

| Versions | Applicable-domain strategy | Usable-work strategy |
|---|---|---|
| v1--v6 | none | none; eager historical session path |
| v7/v8 | `positive-affine-v1` | none; deferred historical session path |
| v9/v10 | `positive-affine-v1` | runtime-unscoped `shared-usable-work-deadline-v1` |
| v11/v12 | `relational-positive-affine-v1` | none; deferred historical session path |
| v13/v14 | `relational-positive-affine-v1` | owner-thread scoped/checkpointed `scoped-checkpointed-shared-usable-work-deadline-v2` |

Every v1--v12 decoder, validation precedence, policy selection, runner route,
and identity remains literal. In particular, v9/v10 do not silently acquire
v2 scope enforcement, and v11/v12 do not infer a budget merely because later
relational versions have one.

## Programmatic composition

The duration is validated once through Djex's shared pure constructor:

```haskell
usableWorkBudget <- either (fail . show) pure $
  mkLengthSMTLibLiveUsableWorkBudget
    LengthSMTLibLiveUsableWorkBudgetSource
      { lengthSMTLibLiveUsableWorkBudgetSourceMilliseconds = 30000 }

let scopedRelationalPolicy =
      enableLengthRankingScopedUsableWorkBudget usableWorkBudget
        $ enableLengthRankingRelationalPositiveAffineApplicableDomainValidation
            applicableDomainLimits
        $ relationalBasePolicy

scalarResult <- assessVerifiedLengthCandidatesWithPolicy
  scopedRelationalPolicy scalarRelationalContract verificationBatch

pairResult <- assessVerifiedLengthSpinePairCandidatesWithPolicy
  scopedRelationalPolicy pairRelationalContract verificationBatch
```

The same policy value can be supplied to the plain verified-list runners or to
the occurrence-sealed post-verification assessors. Scalar and product
contracts, checked queries, observations, receipts, and presentations remain
nominally separate.

The established builder remains available:

```haskell
enableLengthRankingUsableWorkBudget
```

It intentionally selects runtime-unscoped v1. The rank-N v1 phantom separates
independently captured tokens at the type level but does not enforce dynamic
non-escape or thread affinity. Leant never exposes its internal token, but the
policy distinction remains explicit so compatibility code is not silently
assigned a stronger and differently identified runtime contract.

## Startup versions 13 and 14

The additive exported version constants are:

```haskell
lengthRankingConfigurationFileScopedUsableWorkBudgetVersion == 13
lengthRankingConfigurationFileSpinePairScopedUsableWorkBudgetVersion == 14
```

Version 13 embeds the scalar-v5 contract grammar. Version 14 embeds the nominal
pair-v5 contract grammar and therefore requires
`"resultShape": "binary-prod-spines-v1"`. Both use the exact v9/v10 root field
set:

```text
format
version
executionAdmission
execution
evaluation
inputBoxValidation
counterexampleProbe
boundedPositiveOrdering
applicableDomainValidation
applicableDomainOrdering
counterexampleSimplification
liveSessionOpening
usableWorkBudget
contract
```

The applicable-domain object retains the v11/v12 closed shape and selects:

```json
{
  "strategy": "relational-positive-affine-v1",
  "maximumInputs": 8,
  "maximumAssignments": 65536
}
```

The usable-work object has exactly two fields and selects v2:

```json
{
  "strategy": "scoped-checkpointed-shared-usable-work-deadline-v2",
  "milliseconds": 30000
}
```

The duration must be an integer, positive, no greater than 65,000 ms, and
representable by Djex's host-microsecond and monotonic-nanosecond arithmetic.
The budget object reuses
`LengthRankingConfigurationUsableWorkBudgetObject`, its established strategy
and milliseconds field identities, the existing value/type/cap errors, and
`LengthRankingConfigurationUsableWorkBudgetRejected`. The different exact
strategy literal selects behavior; it is not an evidence-bearing schema tag.

The generalized decoder reaches the v13/v14 parser only after every v1--v12
entrance has returned the closed unsupported-version sentinel. For a selected
v13 or v14 document, bounded JSON parsing and `format`/`version` routing occur
first. Semantic validation then proceeds in this exact order:

1. admit the exact root field set;
2. validate `executionAdmission`;
3. validate `execution`;
4. validate `evaluation`;
5. validate `inputBoxValidation`;
6. validate `counterexampleProbe`;
7. validate `boundedPositiveOrdering`;
8. admit the exact `applicableDomainValidation` object, then validate its
   relational strategy, width, cardinality, and Djex limits;
9. validate `applicableDomainOrdering`;
10. validate `counterexampleSimplification`;
11. validate `liveSessionOpening`;
12. admit the exact `usableWorkBudget` object, then validate its scoped-v2
    strategy, milliseconds integer and file cap, and Djex representability;
13. validate the scalar-v5 contract for v13 or pair-v5 contract for v14.

JSON object member order is immaterial. Exact-root admission precedes every
operational field, and the contract remains last, so a malformed later
contract cannot preempt an earlier operational, applicable-domain, or budget
diagnostic. The root README contains complete scalar-v13 and pair-v14
documents. Their null digest examples require the separate explicit
`--length-ranking-allow-unpinned` activation decision. Decode and activation
capture no deadline and launch no process.

## Owner and checkpoint lifecycle

Each scalar or product run productively admits at most 64 caller occurrences
before reading a clock. Admission overflow remains the existing input error and
does not create a deadline. Once admitted, Leant creates a fresh scoped owner
for that run and performs the following sequence:

1. check the newly captured deadline;
2. force complete candidate preparation under the lease;
3. retain a prepared original-order fallback snapshot and checkpoint;
4. for deferred policy, run each candidate through MRU replay, relational
   applicable-domain traversal, origin replay, and optional simplification
   before requesting live IO;
5. checkpoint after each complete pure candidate chain and immediately before
   a pure miss may demand the first worker;
6. open at most one lexical worker under the same scoped token, then checkpoint
   after every completed live candidate before the following candidate can run;
7. retain the nested cleanup-incomplete observation, checkpoint before result
   projection, force only Leant's ranking-owned result structure, and checkpoint
   again; and
8. return through the owner, which closes the lease and performs its final
   normal-return deadline observation.

MRU replay, applicable-domain traversal, origin replay, and simplification are
independently bounded but remain one indivisible per-candidate checkpoint
quantum. Checkpointing never forces a caller-owned occurrence handle beyond its
established weak-head boundary. A pure batch can finish without a worker, but
it cannot bypass the preparation, candidate, result, and outer-owner checks.

Once a worker is admitted, workspace allocation and inspection, executable
snapshot and launch, capability probing, shared serial-gate waiting, scalar or
product transport, bounded response processing, independent replay, and run-
identity work retain Djex's shared-deadline coverage. Each controlled operation
uses the earlier of the captured shared absolute deadline and its established
fresh local deadline; the shared deadline wins an exact tie. The existing
shared 64-transaction ordinal ceiling is independent of elapsed time.

## Dynamic scope and failure boundary

Djex's v2 owner records the creating thread and an open/closed lease state.
Checkpoint and session-opening use is accepted only on that thread while the
callback is open. Wrong-thread or escaped use becomes the byte-free sanitized
class:

```haskell
LengthSMTLibLiveSessionUsableWorkScopeUnavailable
```

Scope admission precedes the monotonic clock read. Session admission also
precedes execution-configuration evaluation, workspace creation, and process
demand. Scope unavailability therefore wins when a retained token is both
stale and expired. The owner closes the lease on every normal or exceptional
callback exit; callback exceptions are rethrown rather than replaced by a
deadline or scope result.

An owner or checkpoint failure becomes a sanitized
`LengthRankingLiveSessionFailed` batch failure with safe original index
`Nothing`. Fallback is atomic and original-order, but its candidate states are
deliberately precise:

- if failure precedes the preparation snapshot, every admitted occurrence is
  returned as ordinary `Unassessed` because preparation never completed;
- after preparation, occurrences whose pure handoff or query construction was
  refused retain `LengthCandidatePreparationRefused`, while every eligible
  prepared candidate becomes `Unassessed`; and
- any incomplete-cleanup bit already observed from the nested session is ORed
  into the owner failure.

A non-deadline candidate-local replay or live-query failure can retain its safe
original index. A local per-query deadline can do so only when the shared lease
is still live at the following checkpoint. When the shared v2 deadline itself
expires inside a query, the subsequent checkpoint or final outer-owner
observation supersedes the provisional indexed query failure with the atomic
owner failure and index `Nothing`. No fallback invents a preparation-refusal
reason for a candidate whose preparation succeeded.

## Cooperative boundary and finalizers

V2 is a usable-work lease, not an asynchronous watchdog. A checkpoint observes
the same absolute deadline without refreshing it, consuming a query ordinal,
writing SMT-LIB, recording an observation, or installing a timer. It cannot
interrupt arbitrary callback IO, a nonterminating pure candidate phase, or
work which never reaches a checkpoint or controlled live operation.

Nested session final readiness and durable process/workspace cleanup retain
their established fresh private windows. Leant intentionally uses Djex's
general two-step scoped owner, not the shorter one-session convenience owner.
The nested session returns only after final readiness and cleanup. Leant then
performs its post-ranking checkpoints and result forcing, and the outer owner
finally closes and observes the shared deadline. Finalizer time is excluded
from the nested shared-deadline window but can therefore make Leant's later
outer observation truthfully report expiry.

Djex's convenience
`withLengthSMTLibLiveSessionWithScopedUsableWorkBudget` deliberately omits that
second post-finalizer deadline observation; Leant's ranking path does not use
it. Exceptions remain authoritative in both forms, and durable owned cleanup
retains its separate bounded behavior and incomplete bit.

## Identity boundary

Every legacy and runtime-unscoped v1 identity remains byte-exact. Scoped v2
uses the additive Djex ready-worker role and envelope:

```text
finite-list-spine-length/z3-capability-probed-ready-worker/scoped-shared-usable-work-deadline/v2
djex-length-z3-scoped-shared-usable-work-deadline/v2
```

Scalar v2 query runs use:

```text
djex-length-z3-capability-probed-pre-spawn-pathname-snapshot-worker-query-run/scoped-shared-usable-work-deadline/v2
finite-list-spine-length/z3-live-query-run/scoped-shared-usable-work-deadline/v2
```

Product v2 query runs use their nominal sibling:

```text
djex-length-spine-pair-z3-capability-probed-pre-spawn-pathname-snapshot-worker-query-run/scoped-shared-usable-work-deadline/v2
finite-binary-product-spine-lengths/z3-live-query-run/scoped-shared-usable-work-deadline/v2
```

These identities bind the validated duration, captured shared deadline,
minimum/shared-on-tie selection, effective cause, owner-thread/open-only
admission contract, close-on-exit lifecycle, operation coverage, checkpoint
policy, and finalizer boundary. The actual thread identifier, mutable lease
cell, and number or outcomes of checkpoints are omitted because they are
runtime admission details, not stable semantic association. Canonical query and
protocol bytes, observations, replay gates, and public scalar/product evidence
types remain unchanged.

## Behavioral authority limit

Scope admission and checkpoint success establish only process/session timing
association. Neither is a behavioral receipt. V13/v14's
`relational-positive-affine-v1` selection can produce evidence only when Djex
independently replays the complete derived finite box for the exact checked
scalar or product query. The budget strategy does not change that rule.

No deadline, checkpoint, configuration version, worker identity, or solver
status attests the executed image, validates Z3 soundness, proves `unsat`,
establishes source-language behavior, transfers authority between scalar and
product domains, or grants pruning authority. Every live status remains
`HeuristicRankingOnly`. Expiry or scope unavailability creates no assessment,
receipt, presentation note, proof, or cache authority; ranking remains an
all-candidate ordering operation.

Djex's underlying lifecycle, precedence, finalizer, identity, and authority
contract is specified in the
[dynamically scoped live usable-work deadline report](../../lib/Djex/docs/reports/2026-08-15-dynamically-scoped-live-usable-work-deadline.md).
