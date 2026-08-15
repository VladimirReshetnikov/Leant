# Bounded Length counterexample simplification

Date: 2026-08-14

## Outcome

Leant can now explicitly ask Djex to simplify every independently replayed
scalar or canonical-`Prod` Length counterexample before ranking, MRU promotion,
and presentation. The public policy builder is:

```haskell
enableLengthRankingCounterexampleSimplification
  :: LengthInputBoxLimits
  -> LengthRankingPolicy
  -> LengthRankingPolicy
```

The builder is persistent and composes with input-box validation,
applicable-domain validation, the origin probe, and both positive-ordering
preferences. `mkLengthRankingPolicy`, the validated-component bridge, every
established direct runner, and startup configuration versions 1 through 6
leave simplification disabled.

## One finalization seam

Both scalar and pair rankers invoke one domain-specific finalization helper for
counterexamples obtained from all five sources:

1. a fresh replay hit from the four-entry MRU bank;
2. applicable-domain traversal;
3. the query-owned origin probe;
4. mandatory replay of a live model observation; and
5. post-`unsat` finite input-box traversal.

The acquisition order is unchanged: MRU, optional applicable domain, optional
origin, live query and observation replay, then optional post-`unsat` box. The
simplifier performs no solver transaction and does not reserve or change a
live ordinal.

On a strict simplification, its fresh ordinary counterexample receipt becomes
the candidate's `Counterexample` or `LengthSpinePairCounterexample`
assessment. The final input vector—not the anchor—is inserted or promoted in
the domain-local four-entry MRU bank. A later candidate still replays that
vector under its own exact query; neither the simplification receipt nor its
behavioral authority is cached.

## Bounded search and fallback

Djex owns the exact search. Given anchor inputs `a`, it admits the complete box
`[0..a0] × ... × [0..an]` under the policy's checked
`LengthInputBoxLimits`, independently revalidates the anchor, and visits the
box lexicographically with the last input varying fastest. A simplification
receipt exists only when the first violation differs strictly from the anchor.

Ordinary bounded unavailability—input width or Cartesian product beyond the
configured limits—or an anchor already at the first violation retains the
original receipt without metadata. Leant also treats only an admitted earlier
trial's `LengthInputBoxAssignmentEvaluationRejected` as best-effort search
incompletion: the already replayed anchor remains valid, so ranking keeps it
without claiming simplification.

Arity/value rejection, invalid anchor replay, internal enumeration failure,
and query/problem association failure are not search misses. They become an
indexed, sanitized atomic ranking failure and restore the admitted batch in
original order as unassessed. Association rejection reuses Leant's established
redacted evidence-replay mismatch class.

## Receipt association and presentation

The public ranked-candidate projections are:

- `rankedLengthCandidateCounterexampleSimplification`;
- `rankedLengthSpinePairCandidateCounterexampleSimplification`.

They expose only optional opaque Djex metadata attached to the exact ranked
candidate occurrence. The post-verification permutation seal carries that
metadata with the candidate and final receipt, including when equal candidate
values occur more than once.

`renderLengthCounterexampleSimplificationNote` and its spine-pair sibling state
that the reduction was bounded, query-owned, componentwise, and
lexicographic. They report the original inputs, final inputs, exact number of
search assignments inspected through the hit, recomputed final result, and a
provider-count-only basis under the established 384-character terminal cap.
The ordinary counterexample note is used when no strict metadata exists.

This language deliberately does not claim a globally minimal witness, a Lean
counterexample, pruning permission, provider implementation correctness,
universal behavior, or Z3 soundness.

## Authority and identity compatibility

Leant never edits a receipt or treats smaller numbers as evidence. It consumes
only Djex's fresh exact-query-associated ordinary receipt and keeps the
separate simplification receipt solely as bounded provenance for presentation.
Scalar and product metadata, errors, problems, queries, and evidence remain
nominally distinct.

The checkpoint changes no contract, provider, session, candidate, concrete
encoding, complete-problem, SMT query, protocol, process, worker, live-run, or
observation identity. Query bytes and source order are unchanged. Under the
explicit policy, final counterexample inputs and therefore later MRU hits and
actual live ordinals may change; this is the requested orchestration behavior,
not an identity-schema change.

## Characterization

Focused scalar and product regressions pin:

- strict live-model reductions and exact inspected counts;
- final-vector MRU reuse and compact live transactions;
- ordinary fallback for unavailable, unchanged, and trial-evaluation cases;
- indexed atomic handling for structural and association failures;
- builder composition, base-policy immutability, and disabled compatibility;
- exact occurrence association and bounded scalar/product presentation; and
- unchanged query bytes, fingerprints, protocol, and live ordering.

The underlying Djex API, receipt semantics, and evaluator characterization are
recorded in the
[Djex bounded simplification report](https://github.com/VladimirReshetnikov/Djex/blob/main/docs/reports/2026-08-14-bounded-length-counterexample-simplification.md).
