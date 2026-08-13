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
verification-facing value retains it in its single exact-origin field. That
value flattens the scheduling-only variant to its display route, ordinal, and
text instead of retaining the intermediate record plus a parallel copy of the
same recovered origin. Its group-level semantic sidecar remains absent. The
witness retains the later Exference candidate, authority, exact spelling, and
that origin's renderer ordinal only on the matching variant. Other spellings
in the same Djinn group remain untyped.

## Checked use

`prepareCheckedLengthProblem` consumes the callback-accepted
`DetailedVerificationVariant`. A direct Exference occurrence and a recovered
exact-text occurrence meet at the same private origin boundary. Preparation
preserves its fixed refusal precedence and establishes all of the following:

1. the engine/fit fragments, premise layout, search goal, converted source goal,
   request contexts, and request goal still match the origin;
2. the retained Exference graph is available and, under the historical
   startup/version-1--3 policy, re-renders to exactly one alternative;
3. that historical origin renderer ordinal is zero and the rendering's bytes
   equal the Lean-accepted spelling; and
4. the existing family, provider, session, contract, and candidate-problem
   sealing checks succeed.

The resulting problem therefore describes the accepted term text through the
exact Exference graph which independently produced that same text. It does not
claim that Djinn produced or owns the graph.

The contract-only version-4 exact-case policy, added later, deliberately
extends only its own association rule: the retained origin ordinal selects one
in-range alternative and sibling renderer alternatives cannot replace that
exact accepted spelling. Older policies retain the singleton rule above.

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

Flattening at verification preserves that productivity boundary: route,
display ordinal, text, and the legacy authority-free `Show` rendering do not
force the lazy exact-origin lookup. Verification equality still compares the
origin after route, ordinal, and text, so callback receipts cannot treat an
association-free occurrence as the same value as its origin-bearing twin.

Tests cover both collision directions, exact-spelling-only recovery inside a
multi-variant group, unchanged route and ordinal observations, a real recovered
Length handoff, wrapper erasure, compatibility projection parity, and poison
tail productivity. No candidate is added, removed, or reordered by this
refactor.
