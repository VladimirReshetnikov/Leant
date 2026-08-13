# Post-verification assessment seam

Date: 2026-08-11

## Outcome

Leant now has one explicit, domain-neutral boundary between callback
verification and candidate presentation. `Leant.Synth.PostVerification`
accepts the opaque nominal `VerificationBatch candidate` produced by the
callback verifier and exposes two paths:

- `skipPostVerificationAssessment` is the disabled/default path. It returns
  the batch's exact receipt list without payload traversal, IO, configuration
  access, worker launch, or any claim that permutation validation occurred.
- `sealPostVerificationBatch` admits assessor proposals only when they form a
  bounded complete permutation of opaque occurrence handles minted from that
  exact callback batch under one fresh rank-2 epoch.

`Main.verifyAndDisplay` selects the first path by default, so no-option CLI and
REPL behavior remains the exact receipt list in callback order. An explicit
startup configuration instead selects the sealed Length adapter for the same
`VerificationBatch` produced by `synthVerify`. No path performs solver or
contract discovery or contract inference.

## Exact permutation boundary

`PostVerificationBatch candidate` is opaque and nominal in its candidate
parameter. Its constructor is available only to the sealing function; the raw
identity path cannot construct it. The sealing function receives a maximum,
one opaque `PostVerificationInput epoch candidate`, and reordered
`PostVerificationCandidate epoch candidate` handles. The input and handle
constructors, handle indices, and epoch are private. `withPostVerificationInput`
introduces a fresh abstract epoch for each callback batch; nominal roles and
the rank-2 callback prevent a handle from another batch from inhabiting the
same epoch without an explicit unsafe operation. The seal validates in a fixed
order:

1. productively admit the input's original handle list through maximum plus one;
2. productively admit the proposal list through maximum plus one;
3. require exact length equality;
4. reject each out-of-range index before checking that index for duplication;
5. reconstruct the ordered receipt list from the original handles only after
   all checks succeed.

Length equality, unique private indices, and range membership require a
complete occurrence permutation. The candidate universe is minted only from
the opaque `VerificationBatch`; there is no public constructor from a receipt
or candidate value. An assessor may reorder supplied handles but cannot omit
one, repeat one, manufacture one, or substitute a same-valued receipt from
another batch. Equal candidate payloads remain distinct occurrences, and
sealing never requires `Eq candidate` or forces a candidate payload. The
generic seal validates occurrence order only; a domain adapter must retain its
assessment with each handle, as the Length adapter below does. Cyclic proposals
terminate at the maximum-plus-one observation. Candidate admission precedes
proposal admission, so an oversized input cannot force a later proposal
source.

The raw identity path and the seal do not grant evidence. `Verified` records
callback acceptance at Leant's verification boundary;
`PostVerificationBatch` records only a checked ordering relationship among
those receipts. Neither type claims a Lean kernel proof or a behavioral
result.

## Length adapter

`Leant.Synth.Length.PostVerification` adapts the existing live Length ranker to
the generic seal without exposing Djex's worker or protocol authority.
`RankedLengthCandidate` now retains the safe original input index beside its
opaque verified receipt and assessment. Stable counterexample demotion carries
those indices through the reordered result, while atomic failure reconstruction
restores indices `0..n-1` with the original all-`Unassessed` order.

Before that public report exists, a package-private
`AssociatedLengthRanking association` threads each caller-owned association
through transient handoff preparation, query execution, Djex's query-owned
evidence replay, stable counterexample partitioning, and atomic fallback. The
post-verification adapter instantiates `association` with the current epoch's
opaque occurrence handle, which is the only receipt-bearing field in transient
ranking state throughout those phases. Preparation may inspect the receipt
through that handle, but retains no parallel detached copy. The internal
sealing core seals the reordered handles first and retains the resulting
opaque `PostVerificationBatch` as the accepted result's sole verified-receipt
owner. Only original indices, assessment state, and the optional sanitized
failure survive in its separately eager bounded summary. The established
receipt-bearing `LengthRanking` is materialized on projection by one fixed
exact-length traversal of that batch and summary, so an assessment is never
detached and later reassociated by candidate equality, numeric lookup, or a
caller-supplied projection. The ordinary
`Leant.Synth.Length.Ranking` facade exports neither associated types nor the
projector, and `Configuration` exports only the two sealed assessment entry
points rather than its lower-level associated runners.

`assessVerifiedLengthCandidatesWithPolicy` requires an already sealed
`LengthRankingPolicy`, one request-owned `LeanLengthContract`, and the exact
opaque verification input. The parallel
`assessVerifiedLengthCandidatesConfigured` accepts the version-1 opaque
policy-plus-contract compatibility bundle. Its configuration wrapper retains
the same batch-scoped occurrence handles rather than falling back to the older
association-free configured ranking projection. Both entry points share one
private rank-2 adapter and the same sealing tail. Their opaque result is an
accepted/rejected sum. Only when permutation and receipt association sealing
succeeds does it retain a `PostVerificationBatch` and expose the corresponding
materialized `LengthRanking` compatibility view.

The caller-facing presentation layer consumes that whole materialized ranked
receipt when deriving candidate text and its optional counterexample note.
Equal spellings and reordered occurrences therefore cannot borrow evidence by
equality, index lookup, or list zipping; disabled, rejected, heuristic, and
fallback branches produce no semantic note.

The result cases are:

- productive ranking-input rejection preserves the original opaque callback
  batch, reports a sanitized adapter input failure, and has neither a ranking
  report nor a sealed batch;
- a completed associated ranking keeps its original-index order coupled to its
  batch-scoped handle, then seals against the exact input epoch under Djex's
  public 64-query maximum; the accepted result retains the sealed batch and a
  receipt-free summary rather than a second receipt-bearing report;
- an impossible malformed proposal preserves the original opaque callback
  batch, reports a sanitized proposal failure, and exposes neither the suspect
  ranking nor a sealed batch;
- a structured operational ranking failure remains a completed original-order
  all-`Unassessed` ranking and therefore seals as the identity permutation.
  Its payload-free candidate-local preparation refusal classes survive the
  fallback and the adapter projection, while candidates which reached live
  execution retain no invented refusal reason.

Synchronous and asynchronous exceptions retain the ranking layer's existing
propagation and Djex cleanup behavior; the adapter does not translate them into
partial output.

## Behavioral authority

The ordering policy is unchanged. A satisfiable model may demote a candidate
only after Djex decodes bounded input values and its query-owned replay gate,
invoked by Leant, accepts the exact sealed query and candidate-specific checked
Length problem. Even that receipt is a finite-spine, model-relative
counterexample conditional on the named provider laws. It is not a concrete
Lean counterexample, solver certificate, or kernel proof.

Status-only `sat`, `unsat`, and `unknown` remain heuristic observations and do
not change order. No result prunes a candidate. Any returned live session,
query, fingerprint-association, or evidence-replay failure restores the entire
original order atomically.

Main now calls the Length adapter only after
`--length-ranking-config ABSOLUTE-PATH`. Startup owns bounded acquisition,
pinned-by-default activation, and the version-1 file's fixed process-wide
contract. The no-option route remains the non-strict identity path. Each
eligible batch still owns a fresh worker. Setup failure stops startup with a
sanitized diagnostic; a later adapter or live failure preserves callback order.

## Validation

The unit suite covers:

- exact and non-strict identity behavior for the disabled path;
- successful complete permutation sealing;
- length mismatch, duplicate-occurrence, candidate-limit, and cyclic
  proposal-limit rejection without payload equality;
- distinct handle identity for equal candidate payload occurrences; foreign
  batch mixing is excluded statically by the abstract epoch;
- productive Length input rejection with the exact opaque callback batch
  retained and no sealed output;
- parity between the separate policy/request-contract path and the configured
  path for stable counterexample demotion and atomic operational fallback;
- a decoded, explicitly activated version-1 file reaches the same sealed
  ranking report as its established association-free compatibility runner;
- configured maximum-plus-one rejection without forcing either the retained
  contract or any candidate payload;
- equal-valued repeated occurrences retain distinct indices across configured
  counterexample demotion and the final seal;
- stable replayed-counterexample demotion with original indices `[1,3,0,2]`;
- operational failure with identity indices `[0,1,2]`, a complete unchanged
  candidate batch, the sanitized ranking failure report retained, and only the
  pre-existing pure preparation refusal class preserved; and
- exhaustive fixed refusal codes plus non-strict classification of every
  handoff refusal constructor, including deliberately unevaluated payloads.

All 306 Leant synthesis-boundary unit tests pass with the configured bridge in
place.
