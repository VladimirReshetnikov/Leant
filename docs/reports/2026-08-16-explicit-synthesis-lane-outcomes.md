# Explicit synthesis-lane outcomes

Date: 2026-08-16

## Outcome

Leant now represents one bounded synthesis lane with explicit Main-private
outcome types. The production checkpoint is
`f9b60cb949635f61424a19a05bcdbe93bd6f835e`; its frozen characterization is
`57388950fac328f317898599fe8f87d89e5b5ef0`.

The refactor is deliberately behavior-preserving. It distinguishes failure to
verify a Lean inhabitant, surviving candidates, accepted behavioral
all-rejection, and preserve-all assessment failure without yet changing which
case may enter another provider or classical lane. Only no verification
continues. Every other disposition remains terminal.

This is a private prerequisite for later command-local counterexample-guided
scheduling, not that scheduling. It changes no command grammar, public Leant
module, engine search, verification API, Length assessment or selection type,
interactive-state field, snapshot shape, output contract, or vendored Djex
source. Leant remains experimental and promises neither stability nor backward
compatibility; these types may be revised or deleted as the next integration
is designed.

## The two lane histories

One lane retains two sequences with intentionally different meanings:

1. `synthLaneCheckedFrontierSpellings` is the complete rendered spelling
   frontier obtained by `concatMap detailedCandidateGroupVariants` over the
   already bounded group prefix. It includes variants which lazy verification
   never needed to call. This remains the existing provider-deduplication and
   progressive-lane scheduling authority.
2. `synthLaneCallbackAttemptVariants` is the exact ordered
   `[DetailedVerificationVariant]` trace. Main appends a variant immediately
   before its `runCurrentCmd` verification request. A failed spelling before an
   accepted spelling is present, while later siblings of the accepted group
   and every group beyond the successful-group quota are absent.

The scheduler never substitutes the narrower callback trace for the complete
spelling frontier. This preserves existing provider-stage deduplication while
making exact attempted-variant accounting available for a later increment.
Neither sequence is a candidate verdict, replay receipt, or counterexample-bank
entry.

The caller-owned bound remains outside both histories. Main takes the finite
prefix before projecting behavior mode, so a poisoned, cyclic, or merely lazy
tail cannot escape because `verifyCandidateGroups` counts successful groups
rather than attempted groups. The unchanged limits are:

| Lane | Bounded groups | Rank success quota | Filter success quota |
| --- | ---: | ---: | ---: |
| ordinary, universe-retry, or provider; standalone engine | 12 | 5 | 12 |
| ordinary, universe-retry, or provider; combined engine | 24 | 5 | 24 |
| excluded-middle classical | 6 | 5 | 6 |
| double-negation classical; standalone engine | 12 | 5 | 12 |
| double-negation classical; combined engine | 24 | 5 | 24 |

An empty bounded prefix returns an unassessed outcome without inspecting the
behavior mode or retained lazy contract.

## Private outcome and disposition spine

`SynthLaneOutcome` retains the two histories, accumulated observations, engine
notes, and an optional `AssessedSynthLane`. The assessed value keeps the exact
`VerificationBatch DetailedVerificationVariant` beside its one
`LengthAssessmentResult`. All fields remain lazy. The three private types
derive neither `Eq` nor `Show`, and none is exported from a library module.

The pure `synthLaneDisposition` classifier has four constructors:

| Disposition | Exact meaning | Current scheduling authority |
| --- | --- | --- |
| `SynthLaneNoVerified` | Empty unassessed lane, or an assessed batch whose `verifiedCandidateReceipts` is empty | May continue |
| `SynthLaneSurvivors` | At least one effective presentation, with the complete rejection projection retained | Terminal |
| `SynthLaneAllBehaviorallyRejected` | A successful assessment has rejection rows and no survivor presentation | Terminal |
| `SynthLaneAssessmentPreserved` | Assessment failure preserved the complete verified batch | Terminal |

Receipt-batch emptiness is tested before behavioral failure or presentation
classification. It is the first and sole assessed-lane route to
`SynthLaneNoVerified`; an empty presentation cannot masquerade as failure to
verify Lean. The total presentation adapters make a callback-verified batch
with neither presentations nor rejections unreachable, but its defensive
classification is terminal `SynthLaneSurvivors [] []` rather than continuation.

Survivor and preserve-all presentations are capped at five during pure
classification. Rejections are never passed through that cap. The distinction
between a terminal all-rejected batch and an empty receipt batch is therefore
available before any presentation or state effect.

## Verification, classification, and finalization

Private `verifySynthLane` owns only the bounded Lean callbacks, rendering-route
and verification observations, and the one optional Length assessment. It does
not emit result metrics, warnings, survivor rows, rejection rows, or engine
notes; bind a candidate; or mutate `rsSynthIts` or `rsSynthItsProve`.

`synthLaneDisposition` is pure. `finalizeSynthLaneOutcome` is then the single
owner of the result effects:

- debug observation metrics;
- the sanitized mode-neutral preserve-all warning;
- reverse candidate binding so the best result remains the newest `it`;
- proof-splice construction and synthesis-cache replacement;
- synthesis-cache clearing for accepted all-rejection;
- at most five survivor or preserved rows;
- the complete bounded rejection projection; and
- engine notes for every handled disposition.

For `SynthLaneNoVerified`, the finalizer may emit debug observations but does
not mutate synthesis state or print engine notes. Intermediate lane notes are
therefore withheld. When the last lane still has no verified receipt, the final
report prints “none survived Lean verification” before those stored notes.
Pre-verification `LEANT_SYNTH_DEBUG` spelling output deliberately remains at the
scheduling edge, where it describes the supplied engine frontier rather than a
result disposition.

An already checked outcome is reused by final reporting. It is neither
reverified nor finalized twice. Structural-refutation fallback still discards
weaker provider-lane notes, excluded-middle and double-negation keep their
empty note lists, reverse binding and row order are unchanged, and unresolved-
universe annotations remain on their established paths.

## Scheduling freeze

Baseline, provider, and classical orchestration now pattern-match on the
explicit disposition instead of an `IO Bool` handled flag:

- a baseline `SynthLaneNoVerified` may discover providers;
- a provider `SynthLaneNoVerified` unions the complete bounded spelling
  frontier into the checked set before the next provider stage;
- an excluded-middle `SynthLaneNoVerified` may enter the double-negation
  route; and
- survivor, all-behaviorally-rejected, and assessment-preserved dispositions
  stop immediately at each of those sites.

Thus an accepted all-rejected filter still prints every rejection, clears the
old synthesis-splice cache, creates no binding, emits no unrelated Lean-
verification failure, and does not continue. Preserve-all failure still warns,
presents at most five originals, and remains terminal. No externally visible
scheduling or presentation behavior changes at this checkpoint.

## Dormant Djex bank prerequisite

The preceding Leant dependency commit
`42860160c757332f9b999c9028a8af9397976960` pins `lib/Djex` to
`d3a57beff39fb7895a15b4d1111736dd7c99c852`. That Djex snapshot exposes
candidate-independent scalar and binary-product bank scopes plus bounded
immutable input-vector stores. The scope binds the checked session inventory
and provider-law basis, solver-neutral interpretation policy, exact contract,
and alpha-canonical target while excluding candidate and execution identity.
A match authorizes only an attempted fresh replay; a stored sample has no
verdict or receipt.

Leant contains no import or runtime use of that module. No command constructs a
bank, no observation inserts a vector, and no bridge fresh-replays a stored
sample into an associated receipt. The active four-vector MRU remains private
to one assessment batch and starts empty for the next batch. The dependency
foundation and the Main-private outcome spine are complementary prerequisites,
not an integrated command-local CEGIS loop.

Djex's exact boundary is recorded in its
[nominal counterexample-bank report](../../lib/Djex/docs/reports/2026-08-16-nominal-length-counterexample-bank-foundation.md).

## Deliberate non-goals

This checkpoint adds none of the following:

- continuation after `SynthLaneAllBehaviorallyRejected`;
- a bank owner spanning candidates, assessment batches, lanes, or commands;
- bank insertion, replay-attempt charging, or fresh-receipt association;
- candidate verdict, solver-status, query, receipt, or proof storage;
- persistent or snapshot state;
- a public scheduler API or a new `Engine`, `Verification`, `Integration`, or
  `ReplState` contract;
- engine-side pruning, replacement-candidate requests, or typed sketches; or
- a change to rank/filter quotas, command output, bindings, notes, or fallback
  order.

The next integration must still decide who owns one command-local bank, when a
replay attempt is charged, which newly established counterexamples are stored,
and how fresh replay failure affects a later candidate. Merely treating
all-rejection as no verification would remain unsound and is explicitly
prevented by the new disposition.

## Characterization

The test checkpoint `57388950fac328f317898599fe8f87d89e5b5ef0`
characterizes the private seam without exporting it. At that checkpoint:

- `src/Main.hs` has 4,730 lines and SHA-256
  `04c9a439be8e9a83fbcf04e79764fb2ba7c3744f248afcce38d0a54db4ee13f6`;
- `test-unit/Spec.hs` has 19,532 lines and 418 literal `testCase` tokens;
- the test source SHA-256 is
  `665ab065778d328b77575ec8b65477708768c3f675c40aeaeb8c5bed930bc976`;
- the test delta is 397 insertions and 91 deletions;
- `verification observability` passes 9/9;
- `explicit Length assessment integration` passes 18/18;
- the complete Leant unit suite passes 417/417;
- strict warning-as-error builds of `leant-synth-tests` and all project targets
  pass; and
- `git diff --check` is clean.

The direct verifier characterization constructs a complete bounded spelling
frontier which contains later accepted-group siblings and a group beyond the
success quota, while the callback records only two failures and two accepted
variants actually attempted. Main source-boundary tests separately pin:

- every lazy outcome, assessed-lane, and four-way-disposition field;
- bound-before-mode projection and the exact 5/12/24/6 quotas;
- callback recording before the backend request;
- the absence of presentation and state effects from verification and pure
  disposition code;
- receipt emptiness before assessment/presentation classification;
- finalizer ownership and effect ordering;
- complete provider-frontier rather than callback-trace deduplication;
- terminal handling for survivor, all-rejected, and preserved outcomes;
- final no-verification diagnostic-before-note order; and
- unchanged structural-refutation and classical fallback boundaries.

The golden transcript runner was also attempted, but the validation environment
had no Lean REPL backend executable. It stopped before running the corpus and
changed no file. That check is recorded as unavailable, not passed; the
behavior-preserving source and unit characterization changed no golden fixture.

## Documentation and artifact boundary

The current normative descriptions are the
[Length behavioral reference](../length-ranking.md), the
[`synth` internals map](../synth-internals.md), the manual source, the
maintainer-walkthrough source, and current code. The historical
[lane-local refill report](2026-08-15-lane-local-length-survivor-refill.md)
correctly records that its earlier checkpoint had no richer scheduler outcome;
it is not rewritten retroactively. This report supersedes only that statement
for the current tree while retaining the same external behavior.

The [Z3 behavioral synthesis proposal](../Z3_Behavioral_Synthesis_Proposal/Z3_Behavioral_Synthesis_Proposal.pdf)
remains forward-looking for command-local bank ownership, cross-lane
enumeration, typed sketch completion, prefix pruning, broader domains, and
Lean-checked proof artifacts.

The documentation source was frozen and pushed at
`30bbb0ae73ae7ceea2d24e1b7ca0cd80be2f2507`. The artifact-only successor then
changed the walkthrough's snapshot fields and links to that exact Leant commit
and to vendored Djex
`d3a57beff39fb7895a15b4d1111736dd7c99c852`, advanced its prepared date to
August 16, 2026, completed this evidence section, and regenerated only the two
maintained PDFs. The final manual TeX has 1,798 lines and SHA-256
`a30606aba9d6f02e5c85f427186c7002380b3447ee6fb485291879c5f6664c0a`;
the final pinned walkthrough TeX has 3,244 lines and SHA-256
`e5b0480f6baef609139a39e63fbb46fadc68388b2af722995336c934c9964b95`.

Both artifacts were rebuilt from clean temporary directories with three
fail-fast passes apiece: LuaLaTeX for the manual and pdfLaTeX for the
walkthrough. Their final measurements are:

- `docs/Leant.pdf`: 30 pages, 184,779 bytes, SHA-256
  `32c18181409ab0b9f21818b2e8bc64fa5979c69b960c66e406a41400d4f0411b`;
- `docs/Djex_Leant_Codebase_Walkthrough/Djex_Leant_Codebase_Walkthrough.pdf`:
  117 pages, 769,443 bytes, SHA-256
  `ace85303dcee12eedb5a4b72def33edbc137e64496c04d3b8fb6e2296d54aa31`.

The final logs contain no undefined citation or reference, rerun request,
missing glyph, package warning, fatal diagnostic, or TeX error. The remaining
non-fatal layout diagnostics are three underfull manual paragraphs and four
underfull walkthrough lines in the fixed descriptor-launch quotation, plus one
pre-existing overfull walkthrough paragraph containing long fixed code
identifiers. Every PDF font is embedded and subsetted with Unicode mappings.

Extracted text pins the dormant Djex bank distinction, private four-way lane
outcomes, distinct spelling/callback histories, 19,532/418/417 test metrics,
417/417 result, exact source snapshots, and August 16 date. URL extraction
finds eleven manual annotations, whose ten relative report targets all exist,
and 236 walkthrough annotations. All 179 Djex source links use the exact
`d3a57be` blob root, all 50 Leant source links use the exact `30bbb0a` blob
root, and the two repository-tree links use those same full commits. No
`a9150c` or `6802674` walkthrough pin remains in source, extracted text, or
annotations.

The manual's physical PDF page 27 and the walkthrough's physical pages 1, 11,
20, 25, 89, 93, and 116 were raster-inspected. The updated manual narrative,
title snapshot table, behavioral addendum, counterexample-bank module row,
current opt-in summary, candidate funnel and disposition explanation, test
metrics, and pinned-tree appendix are readable without clipping or overlap.
The final artifact delta remains limited to this report, the walkthrough TeX
pin refresh, and the two regenerated PDFs; it changes no production, test,
manual TeX, normative Markdown reference, historical report, or vendored
dependency.
