# Lane-local bounded Length survivor refill

Date: 2026-08-15

## Outcome

Leant's explicit replay-authorized Length filter can now refill its visible
survivors from the remainder of the current synthesis lane. Ranking retains
its historical five-success Lean-verification frontier. Filtering instead
verifies the callback-accepted output of one already bounded lane, assesses
that verified frontier once, and only then presents and binds at most five
survivors. Every rejection from the bounded assessed batch remains visible.

The production change landed in
`8ef6c2d17002f31774b9d05dce98b26f5b77cc1b`; the explicit source comment
freezing its scheduling boundary followed in
`88b326c204ad165f114da93ec06d654a80dd3bdc`. Its characterization landed
separately in `a83cf62aa1ddd5c8fe7190c5efc8134749514f38`.

This is a deliberately narrow successor to the historical
[command-authorized filtering checkpoint](2026-08-15-command-authorized-length-filtering.md).
It changes no command grammar, JSON shape, Length query, evidence type,
selection taxonomy, engine search, verification implementation, interactive
state, or cross-lane scheduling contract. Leant remains experimental and makes
no stability or backward-compatibility promise; this report records the
current boundary rather than freezing it for future revisions.

## The starvation gap

Before this checkpoint, each synthesis caller already bounded its generated
group stream to 12 groups for a standalone engine or 24 for the combined
engine. The cheaper excluded-middle classical route used 6. Main's private
`synthVerify`, however, always stopped after five successful Lean callbacks
before Length assessment ran.

That ordering was sufficient for ranking, which keeps every accepted
occurrence. It could starve an explicit hard filter: if the first five verified
occurrences all carried independently replayed counterexamples, selection
returned an all-rejected batch even when the same engine lane had already
generated later groups that would survive the contract. The handled
all-rejected result then correctly stopped later provider or classical lanes,
so those already bounded same-lane groups were the only safe refill source.

## Request projection and the finite consumer boundary

`Leant.Synth.Length.Integration` now exports
`lengthAssessmentRequestBehaviorMode`. Disabled assessment projects
`LengthBehaviorRank`; an enabled request projects its strict mode tag without
forcing the retained lazy scalar-or-pair contract. Main uses that projection
only after it has taken the caller-owned group prefix.

The empty-prefix case therefore returns `False` before behavior projection or
contract forcing. This order is not cosmetic. `verifyCandidateGroups` counts
accepted groups against its quota, so a failed group does not consume that
quota. Merely increasing the quota could otherwise traverse an unbounded,
poisoned, or cyclic tail. The private verification/display seam first performs
`take groupLimit groups`; only that finite list may reach the mode-dependent
quota.

The caller matrix is:

| Current lane | Group prefix | Rank success quota | Filter success quota |
| --- | ---: | ---: | ---: |
| ordinary, universe-retry, or provider; standalone engine | 12 | 5 | 12 |
| ordinary, universe-retry, or provider; combined engine | 24 | 5 | 24 |
| excluded-middle classical route | 6 | 5 | 6 |
| full double-negation classical route; standalone engine | 12 | 5 | 12 |
| full double-negation classical route; combined engine | 24 | 5 | 24 |

These are maxima, not a promise that a lane produces that many groups. The
filter receives every successful callback within the finite supplied prefix;
ordinary Lean failures remain failures and never become behavioral
occurrences.

## One assessment batch and one MRU

The complete verified filter frontier enters
`assessLengthVerificationRequest` once. The existing scalar or nominal pair
selection adapter therefore runs one assessment batch with one fresh four-entry
newest-first input-vector MRU. A counterexample learned from an early
occurrence may reject a later occurrence in that batch only after Djex
independently evaluates and associates the vector with the later occurrence's
exact checked problem.

The bank still stores only input vectors. It does not store a solver status,
candidate verdict, query, receipt, provider-law basis, or proof. It begins
empty for the next assessment batch. The enlarged same-lane batch changes only
which already bounded verified occurrences can participate in that one
invocation; it does not make the bank command-local or persistent.

## Presentation and preserve-all behavior

Main applies `take synthMaxShown` to
`presentLengthAssessment assessment`, after ranking or selection. At the
current constants this presents and binds at most five survivors. The
rejection projection is deliberately not truncated: every rejected occurrence
from the bounded assessed batch is printed in original callback order with its
exact existing counterexample or simplification note.

A selection failure still preserves the literal complete original
`VerificationBatch` and exposes no partial rejection. Because filtering may
now have verified more than five occurrences, the failure result can contain
the enlarged 12- or 24-occurrence batch internally. The user-facing warning
path presents at most five unannotated originals. Preservation authority and
interactive output size are therefore separate.

An accepted all-rejected batch retains its established meaning. Main prints
all rejection rows, creates no `itN` binding, clears `rsSynthIts` and
`rsSynthItsProve`, and returns handled `True`. It does not emit the unrelated
“none survived Lean verification” diagnostic, enter a provider lane, move from
excluded-middle to double negation, or reinterpret behavioral rejection as a
Lean failure.

## Deliberate non-goals

This checkpoint is lane-local refill toward the proposal's candidate-
enumeration direction; it is not the proposal's full Level-2 CEGIS loop. It
adds none of the following:

- a counterexample bank spanning assessment batches or synthesis lanes;
- continuation from an all-rejected structural lane into provider search;
- provider-inventory or target/session fingerprinting for a command-local
  bank;
- exact attempted-variant accounting across progressive lanes;
- deferred command-wide presentation or binding;
- a richer scheduler outcome distinguishing Lean failure, surviving
  candidates, behavioral all-rejection, and engine exhaustion;
- engine-side pruning or a request for replacement candidates; or
- persistent state, snapshots, or replay-bank entries in `ReplState`.

Returning `False` for an all-rejected filter would not implement those
features. It would conflate a verified inhabitant rejected by a behavioral
contract with failure to elaborate any inhabitant, could expose an unrelated
uninhabited fallback, and would restart assessment with a fresh batch-local
MRU. A later command-local CEGIS increment needs an explicit outcome type and
bank identity before it crosses that boundary.

## Validation boundary

The test characterization is frozen in
`a83cf62aa1ddd5c8fe7190c5efc8134749514f38`. At that checkpoint:

- `test-unit/Spec.hs` has 19,226 lines and 414 literal `testCase` tokens;
- its SHA-256 digest is
  `c3570ab40ef40a259f85e4a6286c38486b6c96a8b0f5acd0f81c6df8829c61a2`;
- `explicit Length assessment integration` passes 15/15;
- `verification observability` passes 8/8;
- `combined-engine verification frontier` passes 12/12;
- the complete unit suite passes 413/413; and
- the strict warning-as-error test build passes.

The focused Length refill fixture contains exactly twelve verified
occurrences: five early identity candidates are rejected, then seven
preparation-refused candidates survive in original order. One live
counterexample is simplified and the existing MRU replays it for the remaining
early occurrences without additional live queries. The tests also pin:

- disabled, rank, filter, one-shot, and bottom-contract behavior projection;
- the exact five-success rank stop without forcing a poison tail;
- finite filter traversal over poison and cyclic tails;
- the combined 24-group frontier below Length selection's 64-query admission
  limit;
- the post-selection five-survivor presentation cap;
- the untruncated rejection projection and preserve-all presentation cap; and
- ordinary, provider, excluded-middle, double-negation, and handled all-
  rejected Main scheduling controls.

The production, boundary-comment, and test commits remain separate so the
evidence does not claim to predate the source it characterizes. The final
documentation source was then frozen and pushed at
`6802674ecd0814ee9f17c2b9a0b64ed3e0085918`. The walkthrough resolves Leant
source and tree links against that exact checkpoint while retaining the Djex
checkpoint `a9150c77623767f187d64af5d3cd75ec1194f67b`.

Both rendered artifacts were rebuilt from clean temporary directories with
three fail-fast TeX passes apiece. Their final measurements are:

- `docs/Leant.pdf`: 29 pages, 182,610 bytes, SHA-256
  `35ef5d60b6bd3aa330d51873a5727d7aef676b29ec19716de3fd046190db26b3`;
- `docs/Djex_Leant_Codebase_Walkthrough/Djex_Leant_Codebase_Walkthrough.pdf`:
  115 pages, 765,015 bytes, SHA-256
  `322704206b9ec229abcf75dc173da67ec41ba1e65c281cb7b6134a0e4fd708e4`.

Both final logs have stable references with no undefined citation or
reference, rerun request, missing glyph, or fatal TeX diagnostic. The remaining
non-fatal layout diagnostics are one underfull manual paragraph and four
underfull plus one fixed-long-path overfull walkthrough diagnostics. Extracted
text pins the new lane-local limits, survivor/rejection behavior, frozen test
metrics, full Leant snapshot, and short tree label. Extracted PDF links resolve
Leant source paths through `6802674ecd0814ee9f17c2b9a0b64ed3e0085918`
and Djex paths through `a9150c77623767f187d64af5d3cd75ec1194f67b`, with no
old Leant documentation pin. The manual's physical PDF pages 26--27 and the
walkthrough's title, candidate funnel, unit-test, and limits pages were also
raster-inspected; the new material is readable and does not overlap.

This final evidence paragraph, the walkthrough pin refresh, and the two
generated PDFs form a narrow artifact delta after the frozen documentation
source. They change no production or test source.

## Documentation boundary

Current behavior is specified by the
[Length behavioral reference](../length-ranking.md), the
[`synth` internals map](../synth-internals.md), and current source. The earlier
command-authorized report remains an accurate historical record of its landing
checkpoint, where Main assessed only the first five callback acceptances. This
report supersedes that scheduling description for the current tree without
rewriting the older report.

The [Z3 behavioral synthesis proposal](../Z3_Behavioral_Synthesis_Proposal/Z3_Behavioral_Synthesis_Proposal.pdf)
remains forward-looking for a bank scoped across candidate batches, explicit
command-local enumeration, typed sketches, sound prefix pruning, further
domains, and Lean-checked proof artifacts.
