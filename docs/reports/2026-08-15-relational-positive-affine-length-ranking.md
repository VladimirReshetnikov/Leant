# Relational positive-affine Length ranking

Date: 2026-08-15

## Outcome

Leant can now select Djex's relational positive-affine applicable-domain rule
for scalar and canonical-`Prod` finite-spine Length ranking. This is an
additive third rule beside the historical direct-literal and literal-ceiling
positive-affine extractors. It can propagate finite maxima through relations
between compact inputs and can cancel common positive-affine coefficients.

The public policy builder is:

```haskell
enableLengthRankingRelationalPositiveAffineApplicableDomainValidation
  :: LengthInputBoxLimits
  -> LengthRankingPolicy
  -> LengthRankingPolicy
```

It is pure and retains only already validated Djex width and assignment limits.
It performs no IO, opens no worker, consumes no solver observation, and creates
no assessment or evidence. The direct, literal-ceiling positive-affine, and
relational positive-affine builders are mutually exclusive; the last applied
applicable-domain builder determines the retained rule. Every orthogonal
policy component is preserved, including the post-`unsat` box, origin probe,
ordering preferences, counterexample simplification, deferred/eager opening,
and an independently selected usable-work budget.

## Programmatic composition

A caller can replace the applicable-domain rule of an otherwise complete
policy without rebuilding its other selections:

```haskell
let relationalPolicy =
      enableLengthRankingRelationalPositiveAffineApplicableDomainValidation
        applicableDomainLimits advancedPolicy

scalarResult <- assessVerifiedLengthCandidatesWithPolicy
  relationalPolicy scalarRelationalContract verificationBatch

pairResult <- assessVerifiedLengthSpinePairCandidatesWithPolicy
  relationalPolicy pairRelationalContract verificationBatch
```

For a scalar contract whose normalized precondition is:

```text
input0 == input1
input1 <= 5
```

the constant ceiling seeds `input1 <= 5`, and the equality direction then
derives `input0 <= 5`. The resulting box has inclusive maxima `[5, 5]`, 36
total assignments, and six precondition-applicable diagonal assignments.

For a product contract with:

```text
2*input0 <= input0 + 1
```

exact cancellation derives `input0 <= 1`. The same compact input-domain rule
is used, but product queries, counterexamples, establishment receipts,
assessments, and presentation remain nominally separate from their scalar
siblings.

## Relational rule boundary

Djex scans only the normalized precondition itself or immediate clauses of its
flat top-level conjunction. Both sides of a recognized top-level `at-most` or
`equal` relation must be exact positive-affine expressions over compact inputs,
natural literals, sums, and positive-literal scales. Common constants and
same-input coefficients are cancelled exactly. Equality contributes both
directed rules in canonical order. Unsupported clauses contribute no bound and
no partial authority, but remain part of the real precondition replayed at
every admitted assignment.

Propagation is synchronous and rule-once, not numeric least-fixed-point
iteration. Constant-right rules seed the first immutable bounds snapshot. In
each later pass, every rule whose right-side inputs were bounded in the same
starting snapshot fires once; its bounds are merged with `min` only after the
whole pass, and that rule is permanently removed. Rules which cannot yet fire
retry in canonical stored order. Work is therefore bounded by the finite rule
set, while multi-hop relations can still propagate across successive passes.

The snapshot boundary is deliberate. Given `x <= y`, `y <= 10`, `y <= z`, and
`z <= 2`, the rule yields the sound but nonleast maxima `[10, 2, 2]`. The
`x <= y` rule is not fired a second time after `y` tightens.

`LengthTruth False`, or a fired rule whose residual left constant exceeds the
maximum of its bounded right side, makes the conjunction contradictory.
Contradiction takes precedence over otherwise missing bounds and selects an
all-zero coverage carrier. The ordinary verifier still replays that singleton;
successful traversal is explicitly vacuous. Without contradiction, the first
unbounded compact input is ordinary applicable-domain inapplicability and
ranking proceeds to the next source. A nullary query retains the ordinary
single empty assignment.

Width, derived values, Cartesian cardinality, and assignment evaluation retain
the established Djex admission and failure order. Complete traversal is the
only path to establishment evidence; the first postcondition violation is the
ordinary independently replayed scalar or product counterexample.

## Ranking and presentation

The relational pass occupies the existing pre-live applicable-domain position:

```text
four-entry MRU replay
  -> relational positive-affine applicable domain
  -> origin replay
  -> live observation replay
  -> optional post-unsat explicit box
```

Inapplicability is a pure miss. A relational counterexample crosses the same
query-owned simplification seam, becomes the ordinary stable demotion, and can
enter the domain-local MRU bank. Complete non-vacuous establishment skips the
remaining sources and enters the existing preferred partition only when
`enableLengthRankingNonVacuousApplicableDomainPreference` is also selected.
Vacuous establishment remains neutral. Any admitted association, evaluation,
or invariant failure retains the established indexed, original-order,
all-`Unassessed` atomic fallback.

Scalar success is represented by:

```haskell
RelationalPositiveAffineApplicableDomainEstablished
```

The nominal product constructor is:

```haskell
LengthSpinePairRelationalPositiveAffineApplicableDomainEstablished
```

The corresponding terminal-note renderers are:

```haskell
renderLengthRelationalPositiveAffineApplicableDomainValidationNote
renderLengthSpinePairRelationalPositiveAffineApplicableDomainValidationNote
```

Each bounded note reports the derived maxima, checked and applicable assignment
counts, exact finite-spine/provider-law basis, and explicit vacuity. It calls
the result model/provider-relative and denies global proof and solver
authority. Private provider names are not projected.

## Startup versions 11 and 12

The frozen constants are:

```haskell
lengthRankingConfigurationFileRelationalPositiveAffineVersion == 11
lengthRankingConfigurationFileSpinePairRelationalPositiveAffineVersion == 12
```

Version 11 embeds the scalar-v5 contract grammar; version 12 embeds the
nominal pair-v5 grammar. Both intentionally reuse the exact v7/v8 operational
root:

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
contract
```

The applicable-domain object has exactly these fields:

```json
{
  "strategy": "relational-positive-affine-v1",
  "maximumInputs": 8,
  "maximumAssignments": 65536
}
```

The strategy is exact. `maximumInputs` and `maximumAssignments` retain the
inclusive caps of 8 and 65,536 and are delegated to the existing Djex limits
validator after their JSON type and file caps pass.

Semantic validation is exact root admission, `executionAdmission`,
`execution`, `evaluation`, `inputBoxValidation`, `counterexampleProbe`,
`boundedPositiveOrdering`, the applicable-domain object's exact fields then
strategy/width/cardinality/Djex validation, `applicableDomainOrdering`,
`counterexampleSimplification`, `liveSessionOpening`, and finally the scalar
or product contract. Format and version have already been decoded to select
that root. A malformed later contract cannot preempt an earlier operational or
applicable-domain error.

No new diagnostic identity is introduced. The decoder reuses
`LengthRankingConfigurationApplicableDomainValidationObject` and the existing
field identities
`LengthRankingConfigurationApplicableDomainValidationField`,
`LengthRankingConfigurationApplicableDomainStrategyField`,
`LengthRankingConfigurationApplicableDomainMaximumInputsField`, and
`LengthRankingConfigurationApplicableDomainMaximumAssignmentsField`, together
with their established type, value, policy-limit, and Djex-limit errors.

Versions 11 and 12 deliberately do not contain `usableWorkBudget`. It is an
unknown extra root field rather than an optional or ignored selection. These
versions therefore retain deferred opening but use the historical separate
opener/finalizer and fresh per-query host deadlines. Version numbering is a
closed schema choice, not cumulative feature inheritance from v9/v10. A
programmatic caller can compose the relational builder with an already
validated usable-work budget independently.

The generalized decoder attempts v11/v12 only after the complete literal
v1--v10 chain returns its closed unsupported-version sentinel. Every older
accepted document, unknown-field rejection, validation precedence, policy
selection, domain selection, assessment family, and identity remains literal.

The root README contains complete scalar-v11 and product-v12 documents. Their
null executable digest expectations require the separate explicit
`--length-ranking-allow-unpinned` activation choice. Loading and activation
perform no ranking, capture no clock, and launch no solver.

## Authority and identity

Applicable-domain policy and limit selection are not behavioral evidence.
Relational establishment becomes evidence only after the complete derived box
has been independently replayed against the checked problem retained by the
exact query. The query-owned Djex wrapper emits no SMT-LIB command and consumes
no `sat`, `unsat`, or `unknown` status for this pass.

The receipt is finite and relative to the normalized contract, interpreted
candidate, bounded evaluator, finite-spine model, and exact assumed
provider-law basis. It does not establish source-language inhabitance,
realization, termination, strictness, provider implementation behavior,
dictionary evidence, universal correctness, or pruning authority. A solver
status remains heuristic and the ranking never prunes.

Only Djex's new scalar and nominal product relational receipt tags add
canonical bytes. Existing contracts, policies, sessions, candidates, problems,
queries, responses, execution/process/worker/run identities, live observations,
counterexamples, direct applicable-domain receipts, and literal-ceiling
positive-affine receipts remain unchanged. Leant adds nominal assessment and
presentation branches without changing those older identities or transferring
evidence between scalar and product domains.

The underlying extraction, propagation, evidence, and identity boundary is
specified in Djex's
[relational positive-affine applicable-domain report](../../lib/Djex/docs/reports/2026-08-15-relational-positive-affine-length-applicable-domain.md).
