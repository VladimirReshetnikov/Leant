# Exact-duplicate typed provenance

Date: 2026-08-11

## Outcome

Combined-engine scheduling still keeps the first exact rendered spelling, but
that display decision no longer discards the only checked typed authority for
the same term. When an earlier compatibility-only occurrence and a later
Exference occurrence render byte-for-byte identical text, the earlier variant
may retain a private `ExactTypedVariantOrigin` for behavioral preparation.

This is not a sidecar transfer. The first occurrence still owns its group,
route observation, display ordinal, order, verification slot, and compatibility
projection. Group/display equality ignores the witness, while the
verification-facing value retains it. Its group-level semantic sidecar remains
absent. The witness retains the later Exference candidate, authority, exact
spelling, and that origin's renderer ordinal only on the matching variant.
Other spellings in the same Djinn group remain untyped.

## Checked use

`prepareCheckedLengthProblem` consumes the callback-accepted
`DetailedVerificationVariant`. A direct Exference occurrence and a recovered
exact-text occurrence meet at the same private origin boundary. Preparation
preserves its fixed refusal precedence and establishes all of the following:

1. the engine/fit fragments, premise layout, search goal, converted source goal,
   request contexts, and request goal still match the origin;
2. the retained Exference graph is available and re-renders exactly once under
   that origin's preparation;
3. the origin's renderer ordinal, rather than the display ordinal, is zero and
   the rendering's bytes equal the Lean-accepted spelling; and
4. the existing family, provider, session, contract, and candidate-problem
   sealing checks succeed.

The resulting problem therefore describes the accepted term text through the
exact Exference graph which independently produced that same text. It does not
claim that Djinn produced or owns the graph.

## Compatibility and bounds

Recovery is lazy and capped by the existing 60-candidate Exference collection
window. In a wider synthetic stream, a matching origin beyond that bounded
prefix fails closed while a match inside it still recovers. Default
`forceDetailedOutcome`, display, compatibility projection, and route metrics do
not force the lookup or widen historical engine work. The opt-in behavioral
handoff pays the bounded lookup when it asks for typed authority.

Stable filtering keeps a witness only with the unchanged spelling. Arbitrary
text transformations, including the classical wrapper, discard direct and
recovered authority. Nested merges preserve the lazy witness without entering
a poison or unbounded right tail merely to display the first group.

Tests cover both collision directions, exact-spelling-only recovery inside a
multi-variant group, unchanged route and ordinal observations, a real recovered
Length handoff, wrapper erasure, compatibility projection parity, and poison
tail productivity. No candidate is added, removed, or reordered by this
refactor.
