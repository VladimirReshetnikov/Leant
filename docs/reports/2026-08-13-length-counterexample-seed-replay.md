# Batch-local Length counterexample seed replay

## Outcome

Leant's conservative Length ranking pass now tries the input vector from its
most recent validated counterexample before running each later eligible Z3
query. This is a narrow, batch-local CEGIS-style feedback edge. It reduces
redundant live solver work without reusing a verdict or widening behavioral
authority.

The pass retains at most one seed: the bounded source-ordered `[Natural]`
projection of an exact `ValidatedLengthCounterexample`. For a later
`CheckedLengthQuery`, Leant requires exact symbol/input cardinality, rebuilds
`LengthSMTLibIntegerBinding`s from that query's own generated input symbols,
and calls `validateLengthSMTLibCounterexample` with the configured evaluation
limits. If validation yields evidence, Leant additionally calls
`replayBehavioralEvidence` against the behavioral problem retained by that
same query. Only the resulting fresh problem-bound receipt can mark the later
candidate as a counterexample.

An arity mismatch, validation error, non-counterexample assignment, or replay
rejection is a seed miss, not a ranking failure. The candidate then follows
the exact pre-existing live Z3 path. A counterexample from that live path
replaces the seed; a heuristic status leaves the most recent exact seed in
place. Pure preparation refusals do not inspect or modify it.

## Failure and ordering policy

Candidate processing remains stable and serial in original input order. The
successful partition is unchanged: unassessed and heuristic candidates retain
their relative order, replayed counterexamples retain theirs after that group,
and no candidate is pruned.

The optimization does not weaken atomic live failure behavior. If any live
query that is actually attempted returns a structured session, query,
association, or evidence failure, the established fallback still discards all
partial assessments and returns every admitted occurrence in original order as
`Unassessed`. Seed replay itself is pure and fail-closed to a miss.

The policy deliberately keeps only one most-recent seed. A multi-seed bank
would introduce a new attempt-order and work-bound policy; a durable cache
would additionally need complete cache and run identities. Neither is part of
this checkpoint.

## Authority and identity

The seed contains no prior query fingerprint, solver observation, status,
provider-law basis, result, receipt, process identity, or transcript. The
later checked query supplies all symbol and problem authority again. The
independently recomputed receipt remains model-relative and conditional on the
provider laws retained by that later problem. It is not a Lean counterexample,
a proof, a Z3 soundness certificate, or permission to prune.

No Djex or Leant semantic identity or wire schema changes. Checked Length
problems, candidate/session policy versions, QF_LIA query bytes and
fingerprints, execution/capability/protocol policy, JSON configuration grammar,
and presentation remain unchanged. A skipped query deliberately has no live
run identity; Leant never exposed or retained such an identity in the ranking
assessment. Live identity schemas, construction, and replay gates are
unchanged, while session query ordinals continue to count the live calls which
actually occur and can therefore compact when a seed replay skips a call.

This orchestration begins only after a checked Length problem exists. It grants
no inventory, provider implementation, typeclass dictionary, constraint
discharge, or contextual-certificate authority. Z3 remains downstream natural
arithmetic evidence only.

## Regression coverage

The focused strict unit suite pins both sides of the boundary:

- two occurrences of a real one-input provider-backed query are independently
  refuted at input `3`, while the fake worker records only query/get-value
  ordinal `0`; both occurrences retain receipts with input/result `[3]`/`3`
  and the exact provider-law basis;
- distinct zero-result and one-result provider queries have different query
  fingerprints and independently recomputed receipt results `0` and `1`, while
  their shared empty input seed leaves only live query ordinal `0`;
- independently verified zero-input and one-input candidates under one legacy
  contract treat the empty seed as an arity miss and run live query/get-value
  ordinal `1`; and
- live counterexample, replay hit, and later non-refuting seed miss reach only
  live ordinals `0` and `1`, after which the expected rejection restores the
  replay-derived and live partial assessments with the complete batch to
  `Unassessed`.

The binding helper checks exact symbol/input cardinality and treats a mismatch
as a seed miss. The compatibility ranker accepts independently verified
receipts and a legacy contract derives all-observed roles in each candidate's
own checked context, so the cross-arity regression exercises that public seam
without constructing raw queries or bypassing handoff authority.

Validation for this checkpoint uses the strict `leant-synth-tests` warning
profile, the full strict build, Cabal package checks, and whitespace/status
audits.
