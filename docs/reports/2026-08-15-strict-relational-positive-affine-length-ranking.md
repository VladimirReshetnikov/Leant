# Strict relational positive-affine Length ranking

Date: 2026-08-15

## Outcome

Leant can now select Djex's strict relational positive-affine applicable-domain
rule for scalar and canonical-`Prod` finite-spine Length ranking. This is an
additive fourth rule beside the historical direct-literal, literal-ceiling
positive-affine, and non-strict relational extractors. It retains every
ordinary relation accepted by the non-strict relational rule and adds exactly
the natural-number complement of one immediate top-level at-most clause:

```text
not (L <= R)  <=>  R + 1 <= L
```

The public pure policy builder is:

```haskell
enableLengthRankingStrictRelationalPositiveAffineApplicableDomainValidation
  :: LengthInputBoxLimits
  -> LengthRankingPolicy
  -> LengthRankingPolicy
```

It retains only already validated Djex width and assignment limits. It reads no
clock, performs no IO, opens no worker, consumes no solver observation, and
creates no assessment or evidence. All four applicable-domain builders are
mutually exclusive and last-wins within that policy dimension. Execution,
evaluation, origin probing, the explicit post-`unsat` box, both ordering
preferences, counterexample simplification, live-session opening, and the
independently selected usable-work strategy are preserved.

The word *strict* names the admitted natural-number comparison rule. It makes
no claim about evaluation strictness, bottoms, effects, or source-language
behavior.

## Compatibility matrix

Startup versions remain closed schema and runtime selections rather than
cumulative feature levels:

| Versions | Applicable-domain strategy | Usable-work strategy |
|---|---|---|
| v1--v6 | none | none; eager historical session path |
| v7/v8 | `positive-affine-v1` | none; deferred historical session path |
| v9/v10 | `positive-affine-v1` | runtime-unscoped `shared-usable-work-deadline-v1` |
| v11/v12 | `relational-positive-affine-v1` | none; deferred historical session path |
| v13/v14 | `relational-positive-affine-v1` | owner-thread scoped/checkpointed `scoped-checkpointed-shared-usable-work-deadline-v2` |
| v15/v16 | `strict-relational-positive-affine-v1` | owner-thread scoped/checkpointed `scoped-checkpointed-shared-usable-work-deadline-v2` |

Every v1--v14 decoder, diagnostic precedence, policy selection, runner route,
assessment family, presentation, and identity remains literal. In particular,
v11/v12 still give `LengthNot` no coverage authority, v13/v14 do not silently
gain the strict rule, and v9/v10 do not gain dynamic-scope enforcement.

## Programmatic composition

A caller can replace the applicable-domain selection of an otherwise complete
policy, then independently retain or select the scoped usable-work owner:

```haskell
let strictPolicy =
      enableLengthRankingStrictRelationalPositiveAffineApplicableDomainValidation
        applicableDomainLimits advancedPolicy
    strictScopedPolicy =
      enableLengthRankingScopedUsableWorkBudget
        usableWorkBudget strictPolicy

scalarResult <- assessVerifiedLengthCandidatesWithPolicy
  strictScopedPolicy scalarStrictContract verificationBatch

pairResult <- assessVerifiedLengthSpinePairCandidatesWithPolicy
  strictScopedPolicy pairStrictContract verificationBatch
```

`usableWorkBudget` is an already validated
`LengthSMTLibLiveUsableWorkBudget`. Applying either budget builder later is
last-wins between runtime-unscoped v1 and scoped/checkpointed v2 without
changing the strict-domain choice. Scalar and product contracts, queries,
counterexamples, establishment receipts, assessments, and presentations remain
nominally separate.

## Exact extraction boundary

Djex scans either the normalized precondition itself or the immediate clauses
of its flat top-level `LengthAll`. The strict selector delegates ordinary
top-level `LengthAtMost`, `LengthEqual`, and `LengthTruth False` clauses to the
unchanged relational scanner. Its sole extra shape is:

```text
LengthNot (LengthAtMost L R)
```

Both `L` and `R` must be positive-affine expressions over compact inputs,
natural literals, sums, and positive-literal scales. Djex increments the exact
arbitrary-precision constant in the affine summary of `R`, then applies the
ordinary relational constant and same-input coefficient cancellation. The
successor is proof-only: it does not construct a new checked expression,
consume syntax budget, rewrite the retained contract, or enter SMT-LIB bytes.

For example:

```text
not (5 <= x)       gives x + 1 <= 5, hence x <= 4
not (x <= y)       gives y + 1 <= x
```

Together they derive source-ordered maxima `[4, 3]`. On the product side:

```text
not (x + 3 <= 2*x)
```

first becomes `2*x + 1 <= x + 3`; exact common-coefficient cancellation then
gives `x + 1 <= 3`, hence `x <= 2`. Successor insertion occurs before
cancellation, so the strict unit cannot disappear when an input occurs on both
sides.

This is not general negation normalization. It deliberately excludes negated
equality; negation around truth, conjunction, or another formula; a strict
comparison below a non-top-level formula; and a negated comparison containing
monus, minimum, maximum, quotient, modulo, a conditional, a result variable,
or any other subtree outside the positive-affine grammar. An unsupported
strict clause contributes no partial bound and is an ordinary coverage miss,
but remains part of the actual precondition evaluated over any box established
from other clauses.

The inherited closure is synchronous and rule-once, not a numeric least-fixed-
point solver. Seed rules fire against the empty bounds map. Each later pass
examines every eligible pending rule against one immutable snapshot, merges
new maxima with `min` only after the pass, and permanently removes every rule
which fired. Unsupported clauses are ignored for coverage. Syntactic or
propagated contradiction wins over missing bounds and selects the established
all-zero carrier; a successful replay is then explicitly vacuous. Otherwise,
the first compact input without a derived maximum is ordinary inapplicability.

## Ranking, preference, and simplification

The strict pass occupies the established pre-live position for both domains:

```text
four-entry newest-first MRU replay
  -> strict relational positive-affine applicable domain
  -> canonical all-zero origin replay
  -> live Z3 observation and query-owned replay
  -> optional post-unsat explicit input box
```

Only enabled sources run. An MRU hit therefore preempts extraction for that
candidate. Strict-domain inapplicability is a pure miss and continues to the
origin/live path. The first independently replayed violation is the ordinary
scalar or product counterexample; if simplification is enabled, it crosses the
same query-owned componentwise-lexicographic simplification seam as a
counterexample from any other source. A strict reduction becomes the final
counterexample and only those reduced inputs enter the four-entry domain-local
MRU bank. Bounded unavailability or absence of an improvement retains the
original receipt.

Complete traversal creates the new strict-relational assessment family.
Non-vacuous establishment enters the stable preferred partition only when the
independent applicable-domain preference is enabled; a vacuous receipt remains
neutral. With both preferences enabled, the exact stable order is non-vacuous
applicable-domain evidence, non-vacuous post-`unsat` box evidence, neutral and
vacuous assessments, then counterexamples. Counterexamples remain the stable
demotion, heuristic observations remain heuristic, and no candidate is pruned.

The scalar assessment and renderer are:

```haskell
StrictRelationalPositiveAffineApplicableDomainEstablished
renderLengthStrictRelationalPositiveAffineApplicableDomainValidationNote
```

Their nominal product siblings are:

```haskell
LengthSpinePairStrictRelationalPositiveAffineApplicableDomainEstablished
renderLengthSpinePairStrictRelationalPositiveAffineApplicableDomainValidationNote
```

Each bounded presentation reports source-ordered derived maxima, exact checked
and applicable assignment counts, the finite-spine/provider-law basis, and
explicit vacuity. It labels the conclusion model/provider-relative and denies
global proof and solver authority. Private provider names are not projected.

## Startup versions 15 and 16

The additive exported constants are:

```haskell
lengthRankingConfigurationFileStrictRelationalPositiveAffineVersion == 15
lengthRankingConfigurationFileSpinePairStrictRelationalPositiveAffineVersion == 16
```

Version 15 embeds the complete scalar-v5 contract grammar. Version 16 embeds
the nominal pair-v5 grammar and requires
`"resultShape": "binary-prod-spines-v1"`. Both retain the exact v13/v14 root
field set:

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

The applicable-domain object still has exactly `strategy`, `maximumInputs`,
and `maximumAssignments`, but its strategy must be:

```json
{
  "strategy": "strict-relational-positive-affine-v1",
  "maximumInputs": 8,
  "maximumAssignments": 65536
}
```

The usable-work object is unchanged from v13/v14 and must select:

```json
{
  "strategy": "scoped-checkpointed-shared-usable-work-deadline-v2",
  "milliseconds": 30000
}
```

After bounded JSON and `format`/`version` routing, validation performs exact-
root admission; `executionAdmission`; `execution`; `evaluation`;
`inputBoxValidation`; `counterexampleProbe`; `boundedPositiveOrdering`; the
strict applicable-domain object's exact fields, strategy, width, cardinality,
and Djex limits; `applicableDomainOrdering`; `counterexampleSimplification`;
`liveSessionOpening`; the scoped budget object's exact fields, strategy,
integer type, 65,000-ms cap, and Djex validation; then the scalar-v5 or pair-v5
contract. Contract validation cannot preempt an earlier operational, domain,
or budget diagnostic. JSON member order is immaterial.

The generalized decoder reaches v15/v16 only after the complete v1--v14 chain
returns its closed unsupported-version sentinel. Loading and activation capture
no deadline, open no worker, and create no evidence. The complete scalar-v15
and pair-v16 documents are in the root README; their null digest examples
require the separate explicit `--length-ranking-allow-unpinned` activation
choice.

## Scoped lifecycle and failure boundary

V15/v16 retain the v13/v14 runtime route exactly. Each scalar or product run
admits at most 64 caller occurrences outside the clock, then creates one fresh
owner-thread-affine v2 lease before complete preparation. The same absolute
monotonic deadline covers preparation, the deferred MRU/domain/origin prefix,
worker opening, every live transaction, and Leant-owned result forcing.

Leant checks the lease initially, after forced preparation, after each complete
bounded candidate chain, immediately before a pure miss can demand the first
worker, after each live candidate, and before and after forcing the ranking-
owned result. A strict-domain traversal is bounded, synchronous, and one
indivisible per-candidate checkpoint quantum; the lease is not an asynchronous
watchdog and cannot interrupt arbitrary callback IO or nonterminating pure
work. An all-pure batch can avoid Z3, but it cannot avoid the owner checks.

The token is accepted only on its creating thread while its callback is open.
Wrong-thread or escaped use is Djex's byte-free sanitized
`LengthSMTLibLiveSessionUsableWorkScopeUnavailable`, admitted before clock,
configuration, workspace, or process demand. Every normal or exceptional
callback exit closes the lease; exceptions are rethrown after owned cleanup.

An owner/checkpoint failure becomes `LengthRankingLiveSessionFailed` with safe
original index `Nothing` and the original-order atomic fallback. Before the
prepared snapshot every occurrence is `Unassessed`; afterward, actual pure
preparation refusals retain `LengthCandidatePreparationRefused` while every
eligible candidate returns to `Unassessed`. Any nested cleanup-incomplete bit
is retained. A candidate-local association, evaluation, or live failure may
retain its safe index, but shared expiry observed at the following checkpoint
or outer owner supersedes a provisional indexed deadline result with the
batch-wide owner failure.

Nested session final readiness and durable process/workspace cleanup retain
fresh private windows. Leant uses Djex's general two-step scoped owner, so its
post-ranking checkpoints and final normal-return owner observation occur after
the nested session has finalized and can report expiry during those finalizer
stages. No checkpoint refreshes the deadline or consumes a query ordinal.

## Behavioral authority and identity

Selecting the strict rule, a startup version, a deadline, or a ranking
preference is not behavioral evidence. Establishment is released only after
Djex independently replays the complete derived finite box against the exact
checked query. It remains relative to the normalized contract, interpreted
candidate, bounded evaluator, finite-spine model, and exact assumed provider-
law basis. It establishes neither the truth of a caller-asserted provider law
nor source-language inhabitance, realization, termination, evaluation
strictness, absence of bottoms or effects, universal correctness, solver
soundness, or pruning authority.

The strict applicable-domain pass emits no SMT-LIB command and consumes no
`sat`, `unsat`, or `unknown` observation. Live status remains
`HeuristicRankingOnly`. Budget expiry, scope rejection, inapplicability, and
policy selection create no receipt or presentation note.

Djex adds exactly two nominal strict-relational receipt schema tags:

```text
finite-list-spine-length/strict-relational-positive-affine-precondition-domain-establishment/v1
finite-binary-product-spine-lengths/strict-relational-positive-affine-precondition-domain-establishment/v1
```

Leant adds nominal scalar/product assessment and presentation branches, but no
canonical evidence bytes of its own. V15/v16 reuse v13/v14's scoped ready-
worker and scalar/product query-run roles and envelopes byte-for-byte. The
proof-only successor never enters contract, problem, query, protocol,
observation, process, ready-worker, or run identity material. Every v1--v14
configuration route and every older direct, positive-affine, relational,
counterexample, input-box, process, session, query, and receipt identity
remains unchanged.

Djex's exact extraction, closure, receipt, authority, and identity boundary is
specified in the
[strict relational positive-affine applicable-domain report](../../lib/Djex/docs/reports/2026-08-15-strict-relational-positive-affine-length-applicable-domain.md).
