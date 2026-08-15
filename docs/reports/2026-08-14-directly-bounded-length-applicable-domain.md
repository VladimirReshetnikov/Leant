# Directly bounded Length applicable-domain orchestration

Date: 2026-08-14

> **Later 2026-08-14 follow-up.** The direct-v1 builder, extraction rule,
> receipts, and identities below remain literal. Startup v7/v8 explicitly
> select the nominally distinct positive-affine rule, its non-vacuous
> preference, simplification, and deferred session opening. See the
> [positive-affine deferred Length ranking report](2026-08-14-positive-affine-deferred-length-ranking.md).

## Outcome

Leant now has an explicit programmatic policy which asks Djex to validate the
entire directly bounded precondition-applicable input domain before spending a
live query transaction. The persistent builder is:

```haskell
enableLengthRankingApplicableDomainValidation
  :: LengthInputBoxLimits
  -> LengthRankingPolicy
  -> LengthRankingPolicy
```

It supplies only checked width and Cartesian-cardinality limits. It supplies no
input maxima, solver status, query, receipt, or verdict. Djex alone inspects the
exact checked normalized contract and derives the tight source-ordered maxima.
The same opaque reusable policy works with the scalar and canonical-`Prod`
domain-specific assessors.

The new assessment arms are `ApplicableDomainEstablished` and
`LengthSpinePairApplicableDomainEstablished`. The receipts stay nominally
separate. Presentation uses
`renderLengthApplicableDomainValidationNote` and
`renderLengthSpinePairApplicableDomainValidationNote`; each note reports only
bounded maxima, checked/applicable counts, and the model/provider-relative
basis permitted by the opaque receipt.

## Direct coverage and evidence boundary

Djex recognizes only checked normalized top-level clauses of the exact form
`input <= literal`. A top-level conjunction is scanned clause by clause. The
tightest duplicate literal is retained for each compact input, and every
compact input must have a direct clause. Equality, arithmetic-derived bounds,
negation, conditionals, implications, nested formulas, and solver models do not
provide coverage. A missing bound is an ordinary inapplicable result. A
nullary problem has no input requiring a clause; it derives maxima `[]` and
validates the single assignment `[]`.

When coverage succeeds, Djex exhausts the derived tight Cartesian box through
the existing solver-independent exact evaluator. The first violation releases
the ordinary scalar or pair counterexample receipt. Complete traversal releases
the new opaque applicable-domain establishment receipt. Both arms are replayed
against the exact query-owned behavioral problem before Leant can assess them.

Establishment can be vacuous: the complete precondition may hold on zero
assignments inside the derived box. The receipt exposes that count without
weakening its opacity. Provider-backed validation remains conditional on the
exact named assumed provider laws used by the checked candidate. Neither a
counterexample nor establishment is a claim about arbitrary Lean execution,
termination, bottoms, effects, or implementation totality.

## Exact per-candidate order

For an eligible scalar candidate, Leant's order is now:

1. try up to four newest-first batch-local MRU input vectors;
2. when enabled, ask Djex for directly bounded applicable-domain validation;
3. if that result is inapplicable, optionally run the query-owned origin probe;
4. after an origin miss, issue the live scalar Z3 transaction and replay its
   exact observation; and
5. only after a counterexample-free live `unsat`, optionally traverse the
   separately configured explicit finite input box.

The canonical-`Prod` runner has the exact nominal pair sibling of every step.
Its MRU bank, queries, receipts, assessments, failures, and presentation remain
product-specific.

An applicable-domain counterexample follows the ordinary stable demotion and
MRU insertion/promotion path. An established receipt skips origin, live Z3,
and post-`unsat` box validation for that candidate. Inapplicability is a pure
miss and continues without an assessment. Bounded-admission refusals are also
ordinary misses: a problem wider than the policy limit, a derived maximum
outside the evaluation value limit, or a derived Cartesian box beyond the
assignment cap falls through to origin/live. Once that admission succeeds, an
evaluation/internal traversal failure or exact association mismatch is an
indexed operational failure and activates the established atomic
original-order, all-unassessed fallback.

Leant still opens and capability-probes the eligible batch's fresh lexical
worker before it processes any candidate. Consequently a counterexample or
establishment skips a live transaction and consumes no query ordinal, but it
does not avoid process launch, readiness probing, or an earlier session-open
failure.

## Separate non-vacuous preference

Acquiring establishment evidence and preferring it are independent choices.
The second persistent builder is:

```haskell
enableLengthRankingNonVacuousApplicableDomainPreference
  :: LengthRankingPolicy
  -> LengthRankingPolicy
```

Without this builder, both scalar and pair establishment assessments stay in
the neutral stable partition. With it, only a receipt whose exact
precondition-applicable assignment count is positive enters a stable preferred
partition. A zero-applicable receipt remains vacuous and neutral. Ordinary
counterexamples remain in the final stable demoted partition. Relative order
within every partition is preserved, as are occurrence associations and
original candidate indices.

This preference is distinct from
`enableLengthRankingNonVacuousInputBoxPreference`. Enabling either does not
enable the other's validation path or classify the other's receipt. The
builders are persistent, compositional, and order independent. When both
preferences are enabled, stable non-vacuous applicable-domain receipts come
first, then stable non-vacuous explicit-box receipts, then the neutral
partition, and finally counterexamples.

## Programmatic scalar and pair use

A one-input scalar contract and pair contract can share the same reusable
policy while keeping their evidence nominally separate:

```haskell
let applicablePolicy =
      enableLengthRankingNonVacuousApplicableDomainPreference
        $ enableLengthRankingApplicableDomainValidation
            inputBoxLimits basePolicy

scalarResult <- assessVerifiedLengthCandidatesWithPolicy
  applicablePolicy scalarContract verificationBatch

pairResult <- assessVerifiedLengthSpinePairCandidatesWithPolicy
  applicablePolicy pairContract verificationBatch
```

For either call, the passive contract must itself contain direct normalized
bounds such as `input 0 <= 3`; the policy never invents a domain maximum.
`basePolicy` must come from `mkLengthRankingPolicy`, `inputBoxLimits` must be a
checked Djex value, and the occurrence-safe assessors retain every callback
candidate association through stable reordering and the final permutation
seal.

## Configuration and compatibility

The closed startup and contract-only JSON schemas are unchanged. Startup
configuration versions 1 through 6 cannot enable applicable-domain validation
or its non-vacuous preference. Versions 2 through 6 retain only their existing
explicit post-`unsat` input boxes; versions 3 through 6 retain their existing
origin-before-live policy; startup versions 5 and 6 retain only their existing
non-vacuous explicit-box ordering preference. Contract-only documents still
contain no execution or ranking policy.

Every established public runner and existing decoded policy therefore retains
its exact behavior. The new path is reached only by deriving an opaque policy
with the new programmatic builder. No new CLI flag, environment lookup,
executable discovery, configuration field, or Main dispatch branch is added.

No raw `sat`, `unsat`, or `unknown` status grants applicable-domain authority.
The pre-live pass does not consume a status at all. An opaque establishment
receipt remains model/provider-relative information for optional soft ranking;
it grants no pruning permission or kernel proof. Djex's contract, candidate,
problem, query, protocol, process, worker, and live-observation identities are
unchanged, and Leant retains its established occurrence association and atomic
fallback boundaries.
