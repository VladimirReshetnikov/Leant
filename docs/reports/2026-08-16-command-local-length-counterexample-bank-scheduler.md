# Command-local Length counterexample-bank scheduler

Date: 2026-08-16

## Outcome

Leant now owns one lexical Length assessment context across an admitted
`:synth` command and may continue its existing bounded lane schedule after a
successful behavioral all-rejection. The Main-only production checkpoint is
`1ce17ecd2eedb28383bd511675aa255bd5a30495`; its independently audited
characterization is `45642332fe47e0e094483142cc51b04f151ec09b`.

This is the smallest command-local scheduler integration over the preceding
filter-only context runner. It does not ask an engine for replacement
candidates, fill a five-survivor quota across lanes, prune a typed prefix, or
persist state. It reuses only Main's existing baseline, widening-provider,
excluded-middle, and double-negation lanes. Each lane retains its existing
finite bound, and the first survivor or preserve-all result remains terminal.

Leant is experimental and promises neither stability nor backward
compatibility. These private names, diagnostic gates, and scheduling contracts
describe the current tree rather than committing a future release to preserve
them.

## Dependency and predecessor boundary

The vendored Djex revision remains
`f957549e36a63cd6003f5edef4ab8a867221813f`. It supplies candidate-independent
scalar and binary-product bank scopes, bounded immutable input stores, and
query-owned fresh replay. A retained sample stores inputs rather than a verdict
or receipt; every later candidate must independently replay and associate that
sample against its own exact checked problem before it can be rejected.

The preceding Leant context-runner production and characterization are recorded
in the historical
[filter-only context-runner report](2026-08-16-filter-only-length-counterexample-bank-context-runner.md).
At that checkpoint Integration could introduce a reusable rank-2 context, but
Main still used a fresh one-batch compatibility wrapper and all-rejection was
terminal. The earlier
[explicit lane-outcome report](2026-08-16-explicit-synthesis-lane-outcomes.md),
[nominal bank-state report](2026-08-16-nominal-length-counterexample-bank-state.md),
and [lane-local refill report](2026-08-15-lane-local-length-survivor-refill.md)
likewise remain correct point-in-time records. They are not rewritten; this
report supersedes only their statements about the current Main ceiling.

## One pre-translation command context

Command parsing and explicit-contract admission remain outside `synthRun`.
After a request has been admitted and any command-local contract has been read,
`synthRun` calls `withLengthAssessmentRequestContext` exactly once. The rank-2
`LengthAssessmentContext command` is introduced before the initial
`translateGoal` call and lexically encloses:

- initial goal translation;
- every narrowing and retranslation attempt for unresolved universes;
- the provider-free baseline lane;
- every widening provider lane; and
- excluded-middle and double-negation classical lanes.

Every nonempty bounded lane is assessed through
`assessLengthVerificationContext`. A scalar or product filter context owns
exactly one matching nominal bank. Exact same-scope batches reuse it; exact
scope drift replaces its active contents with one empty bank under the retained
limits. Rank contexts contain no bank and continue to select the established
raw four-vector MRU runner. The one-batch
`assessLengthVerificationRequest` compatibility entrance remains available to
other callers but is no longer Main's lane boundary.

The context's `command` parameter and rank-2 introducer prevent escape. Neither
the request, context, bank, behavior mode, accumulation, nor selection result
enters `ReplState`, history, snapshots, serialization, or another command.

## Lane outcome accumulation

`SynthLaneOutcome` keeps the established two noninterchangeable histories:

1. `synthLaneCheckedFrontierSpellings` is the complete rendered spelling
   frontier in the caller-bounded group prefix. It includes variants which the
   lazy Lean callback never needed to attempt and remains provider-deduplication
   authority.
2. `synthLaneCallbackAttemptVariants` is the exact trace appended immediately
   before a Lean callback. It excludes later siblings of an accepted group and
   groups beyond the successful-group quota.

Main now prepends every actual lane outcome to:

```haskell
newtype SynthLaneAccumulation =
  SynthLaneAccumulation [SynthLaneOutcome]
```

The list is lazy and in reverse attempt order. The newtype is positional, has
no record selector, and derives neither `Eq` nor `Show`. Prepending does not
force an earlier outcome, and the complete accumulation remains private to
Main and lexical to one command.

The pure `synthLaneAccumulationDisposition` folds outcomes in chronological
order. No-verification adds no rows. Each continuing all-rejected outcome
appends its complete rejection projection. The first survivor or preserve-all
outcome supplies the only candidate presentation and terminates the effective
fold. A defensive accumulated-terminal guard ignores any impossible later
outcome; the scheduler itself never appends after a terminal result.

## Continuation and finite bounds

The four lane dispositions retain distinct authority:

| Disposition | Scheduler meaning |
| --- | --- |
| `SynthLaneNoVerified` | Continue; no verified receipt exists |
| `SynthLaneAllBehaviorallyRejected` | Continue; verified receipts existed, and only independently replayed counterexamples rejected every occurrence |
| `SynthLaneSurvivors` | Terminal, even with one survivor |
| `SynthLaneAssessmentPreserved` | Terminal preserve-all failure |

Both continuing dispositions union the complete bounded spelling frontier into
the provider checked set before another stage. The callback-attempt trace never
substitutes for that frontier. Raw `sat`, `unsat`, and `unknown`, preparation
refusal, unassessed input, bounded-positive evidence, and applicable-domain
evidence all retain candidates; none can manufacture an all-rejected outcome.
Preserve-all candidate atomicity still does not roll back bank replay,
promotion, or recording transitions which completed before the later failure.

Baseline and provider no-verification or all-rejection enter the next existing
provider stage. Excluded-middle no-verification or all-rejection enters double
negation. Survivor and preserve-all stop at every site. A double-negation lane
outcome is added only when that run actually returns candidates; an
excluded-middle outcome is retained even when its bounded group list is empty.

The existing productivity and presentation bounds do not change:

| Lane | Bounded groups | Rank success quota | Filter success quota |
| --- | ---: | ---: | ---: |
| standalone Djinn or Exference | 12 | 5 | 12 |
| combined engine | 24 | 5 | 24 |
| excluded-middle classical | 6 | 5 | 6 |
| double-negation classical | 12 or 24 by engine | 5 | 12 or 24 by engine |

The finite `take` still precedes behavior-mode projection, so a lazy or cyclic
tail cannot escape the caller's lane bound. Continuation does not accumulate a
five-survivor quota: the first later lane with any survivor terminates and at
most five presentations are shown from that lane.

## One deferred plural finalizer

No lane is immediately finalized. `finalizeSynthLaneAccumulation` is the sole
owner of result effects at terminal, exhausted, structural-fallback, and
abnormal-reporting boundaries. It distinguishes the raw chronological history
from the effective prefix through the first survivor or preserve-all outcome:

- every raw retained outcome may emit its debug metrics in chronological order
  for forensic accounting;
- only the effective prefix may emit preserve-all warnings;
- the aggregate disposition runs at most one final binding batch and at most
  one splice-cache action;
- terminal survivor or preserve-all candidate rows print first;
- rejection rows are every prior continuing all-rejected projection in attempt
  order followed by terminal-lane rejections; and
- handled notes are prior all-rejected notes followed by the first terminal
  note, while no-verification notes remain withheld.

Final aggregate all-rejection creates no binding, clears the old synthesis-
splice cache once, prints every accumulated rejection, and emits its
chronological handled notes. A terminal survivor or preserve-all result binds
or replaces the cache once. Prior all-rejected lanes never perform an interim
clear, and an already checked outcome is neither reverified nor reassessed.

## Structural, classical, and abnormal gates

Final reporting keeps behavioral handling separate from engine evidence.

For ordinary candidate, no-term, or non-sound-refutation exhaustion, aggregate
all-rejection is already handled output. Main suppresses the unrelated “none
survived Lean verification,” bounded-no-term, or unsafe-atom diagnostic and its
otherwise final notes. Aggregate no-verification retains the established
diagnostic path.

A sound provider-free Djinn refutation remains the structural control-flow
fallback for empty, unavailable, timed-out, errored, no-verified, or
all-rejected provider search. Provider timeout/error remains masked on that
path exactly as before. Completed provider outcomes are nevertheless retained
in the accumulation and finalized after the optional classical search.

`synthClassical` accepts and returns `SynthLaneAccumulation` without finalizing
it. When the Glivenko split exists, the excluded-middle outcome is accumulated
before branching. Its no-verification or all-rejection disposition enters
double negation; survivor or preserve-all returns immediately. With no split,
the incoming accumulation is returned unchanged. The sound-refutation caller
is the sole finalizer and output gate:

- aggregate no-verification prints the established provably-uninhabited claim,
  then any goal-qualified unresolved-universe annotation, then the existing
  constructive/classical hint;
- aggregate all-rejection suppresses that claim and hint but still prints the
  unresolved-universe annotation; and
- terminal survivor or preserve-all output likewise keeps the annotation on
  its existing path after finalization.

Without a retained sound fallback, timeout or engine error first finalizes all
completed outcomes and then prints the unchanged abnormal diagnostic. Timeout
also prints its existing hint. No generic lane notes are appended afterward.

## Deliberate exclusions

This checkpoint adds no:

- change to public Ranking, Selection, Engine, Verification, Presentation, or
  Integration facade contracts;
- change to command grammar, startup or contract schema, executable policy,
  solver protocol, query identity, evidence authority, or rejection taxonomy;
- rank-mode bank, rank order, rank-five quota, lane bound, or presentation cap;
- survivor quota filling across lanes;
- counterexample-directed candidate request, engine feedback protocol, typed
  sketch completion, or semantic prefix pruning;
- `ReplState`, history, snapshot, persistence, restoration, serialization, or
  migration field;
- global or session bank; or
- promise of API, diagnostic, output, schema, or compatibility stability.

The [Z3 behavioral synthesis proposal](../Z3_Behavioral_Synthesis_Proposal/Z3_Behavioral_Synthesis_Proposal.pdf)
therefore remains forward-looking for active counterexample-guided engine
enumeration, typed sketches, sound prefix pruning, further behavioral domains,
and Lean-checked proof artifacts.

## Frozen characterization

The characterization commit changes only `test-unit/Spec.hs`. The existing
`command-local Length counterexample-bank runners` group remains 7/7 and pins
scalar/product reuse, route parity, bank caps, selection continuity, live-
session failure, reusable Integration contexts beside fresh compatibility
wrappers and bank-free rank calls, and the nominal package boundary.

The `explicit Length assessment integration` group is now 21/21. Six focused
Main characterizations pin:

1. one assessment context around the complete command, beginning before
   translation;
2. the bounded verification-lane seam beside command accumulation;
3. chronological folding, prior rejection order, and first-terminal defense;
4. exactly-once plural finalization and effect order;
5. baseline/provider and excluded-middle/double-negation continuation after
   both nonterminal dispositions; and
6. normal, sound-refutation, unresolved-universe, timeout, and error diagnostic
   gates.

Source assertions additionally pin the positional lazy accumulation, absence
of `Eq`, `Show`, strict fields, and a record selector, exact private signatures,
one `withLengthAssessmentRequestContext` call inside `synthRun`, context-typed
downstream calls, complete-frontier deduplication, unchanged 5/12/24/6 bounds,
no singular finalizer, no survivor-quota loop, and no `ReplState` field.

## Frozen source and test metrics

Production `1ce17ec` changes exactly one file by 285 insertions and 146
deletions:

| File | Lines | SHA-256 |
| --- | ---: | --- |
| `src/Main.hs` | 4,869 | `2541d582aac5e0a6714ad3f0ff833ad57681698a1a6bde13b7d5946acc7b6937` |

Characterization `4564233` changes exactly one file by 501 insertions and 53
deletions:

| File | Lines | literal `testCase` tokens | registered/executed cases | SHA-256 |
| --- | ---: | ---: | ---: | --- |
| `test-unit/Spec.hs` | 22,688 | 442 | 441 | `e8443061e38ed9949c163280a3d4757088d7f30c17f9f682587124252b77788b` |

The literal token count is one greater than the registered suite count, as at
the preceding checkpoints.

## Validation evidence

The frozen production-and-characterization tree passed:

- 7/7 strict command-local counterexample-bank runner cases;
- 21/21 strict explicit Length assessment integration cases;
- 441/441 complete strict Leant unit cases;
- strict warning-as-error builds of the unit-test component and all targets
  with `-Wall -Wcompat -Werror`;
- clean `cabal check`; and
- clean `git diff --check` before documentation changes.

Independent source and test audits checked context ownership, laziness,
first-terminal folding, complete-frontier deduplication, exactly-once state and
output effects, provider/classical continuation, structural and abnormal
diagnostic gates, finite bounds, package boundaries, and absence of persistence
or quota filling.

All 26 golden transcripts also passed byte-exact against the pinned Lean 4.31
backend, with exit status zero, no diff, and no update mode. The backend binary
SHA-256 was
`0db3cff86ad773e2d8f21a69e84488ba32a6ea5ff40f0ec2ca8c0081013df059`.
The 26 `.txt` inputs, 26 `.golden` outputs, and `test/run-tests.sh` remained
unchanged. Their ordered aggregate was
`a82fe7e5f324bb3d3b87c70cc3b424cb51fb10166a010afea0a0981e0d81e072`,
computed from the repository root as:

```sh
find test -maxdepth 1 -type f \( -name '*.txt' -o -name '*.golden' \
  -o -name 'run-tests.sh' \) -print0 \
  | sort -z | xargs -0 sha256sum | sha256sum
```

The NUL sort fixes the relative `test/...` path order. The outer hash covers
the ordinary per-file `sha256sum` record stream, including each relative path.

## Documentation and artifact boundary

Current behavior is specified by the
[Length behavioral reference](../length-ranking.md), the
[`synth` internals map](../synth-internals.md), the maintained manual and
walkthrough sources, this report, and current code. Earlier dated reports remain
historical landing records rather than normative contracts.

The documentation source was frozen and pushed at
`a9b917f5689ed71a8bf1d3aed038af8e34602a9e`. The artifact-only successor
updates the walkthrough's Leant blob base, title-page snapshot, and
repository-tree link to that exact commit while retaining the vendored Djex
revision `f957549e36a63cd6003f5edef4ab8a867221813f`. The prepared date remains
August 16, 2026, matching the source checkpoint.

The final walkthrough source also adds one local, non-semantic
`\Needspace{7\baselineskip}` guard immediately before the Chapter 18 summary.
The first rebuilt raster had split that box after its penultimate line and left
the orphaned final line on the next page. The guard moves the intact box to the
next page without changing its prose; the follow-up raster audit found no split,
overlap, or orphan.

The final documentation sources are:

| File | Lines | SHA-256 |
| --- | ---: | --- |
| `docs/Leant.tex` | 1,860 | `1ed5eba9156fd2e072679957384ecce238cee059ba6eb7a65181c3c75aac2992` |
| `docs/Djex_Leant_Codebase_Walkthrough/Djex_Leant_Codebase_Walkthrough.tex` | 3,269 | `58e07ee11ff908424f9896c8d79a635d3d5d6f0f845f22161a2f7e049d7fdf5d` |

Both maintained PDFs were regenerated from separate new empty temporary
directories with three fail-fast passes apiece: LuaHBTeX 1.14.0 for the manual
and pdfTeX 3.141592653-2.6-1.40.22 for the walkthrough, both from the TeX Live
2022/dev/Debian toolchain. Pass-two and pass-three stdout are byte-identical for
each document. Their final measurements are:

- `docs/Leant.pdf`: 31 pages, 189,370 bytes, SHA-256
  `bc321e8662e3df011e5cdaec1f9fe29980d652c05748de7cfb35a11269f6f3a3`;
  and
- `docs/Djex_Leant_Codebase_Walkthrough/Djex_Leant_Codebase_Walkthrough.pdf`:
  118 pages, 775,578 bytes, SHA-256
  `41edba22e5dab7d02f1bbace8b5aadfa1256bd526280882a7fadd607396bcadf`.

The final logs contain no undefined citation or reference, rerun request,
missing glyph, fatal diagnostic, or TeX error. The manual retains one nonfatal
LuaTeX duplicate-`page.1` destination warning and 11 underfull box diagnostics:
one at source lines 1588--1638 and ten at lines 1702--1726. It has no overfull
box. The walkthrough retains four underfull diagnostics in the fixed
descriptor-launch quotation and one pre-existing 36.05583-point overfull
binder-hygiene paragraph containing long fixed identifiers.

Both PDFs are unencrypted, untagged PDF 1.5 documents on 612-by-792-point letter
pages, with no form, JavaScript, or suspect-object flag. Text extraction succeeds:
the manual extract is 81,577 bytes over 1,485 lines with SHA-256
`3b8e06450a55a020113919934d36eb203e0276f015968e038f48e4dfe034c5e2`,
and the walkthrough extract is 305,664 bytes over 6,229 lines with SHA-256
`58ee94cbe2486e201d13444ce95b7d39be3df8088e87c255a85e7e470f065175`.
Image-table scans find no raster-image payload in either PDF. All eight manual
font rows and all 17 walkthrough font rows are embedded and subsetted with
Unicode mappings.

Extracted manual text contains the one pre-translation command-local context,
no-verification and all-rejection continuation, complete-frontier
deduplication, one plural finalizer, structural/classical and abnormal gates,
the no-quota and nonpersistent-REPL-state boundary, and this report path. Its 11
URL annotations comprise the repository link and ten relative report targets;
all ten relative targets exist.

Extracted walkthrough text contains the exact full title-page snapshots,
command-local scheduler narrative, 22,688/442/441 test inventory, focused 7/7
and 21/21 results, complete 441/441 result, this report path, and the abbreviated
pinned-tree labels. The walkthrough has 236 URL annotations. All 179 Djex source
links use the exact
`f957549e36a63cd6003f5edef4ab8a867221813f` blob root, all 50 Leant source links
use the exact `a9b917f5689ed71a8bf1d3aed038af8e34602a9e` blob root, and the two
repository-tree links use those same full commits. The remaining five links are
external references. All 63 unique Djex and 18 unique Leant blob targets exist
at their pinned commits. No previous Leant pin or prior `0611e2c`, `30bbb0a`,
`d3a57be`, `a9150c`, or `6802674` pin remains in the walkthrough source,
extracted text, or URL annotations.

A same-resolution comparison against the source-checkpoint artifacts found
changed rasters on the manual's physical pages 2 and 22--31 and the
walkthrough's physical pages 1, 3--9, 11, 19, and 24--118. Every changed page
was raster-inspected. The command-local scheduler narrative, exact title
snapshot, behavioral addendum, test inventory, repaired Chapter 18 summary,
pinned-tree appendix, and all downstream pages are readable without clipping,
overlap, or malformed line breaking.

This evidence section, the three walkthrough pin refreshes, the one local
pagination guard, and the two regenerated PDFs form a four-file artifact delta
after the frozen source-document commit. They change no Haskell production or
test source, Cabal file, vendored Djex file, manual TeX, normative Markdown
reference, reports index, or earlier point-in-time report.
