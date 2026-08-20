# Progressive same-run Length filter batching

Date: 2026-08-16

## Outcome

Leant now consumes the opaque detailed-synthesis cursor in Main so an explicit
Length filter can verify and assess at most two ordered batches from one lazy
engine outcome. The Main-only production checkpoint is
`d01fbd2be3f50c57ad75e8e36a683854198c1afb`; its independently audited
characterization is `3b1be069c28928cd4f4a2967b5da5fe76431c622`.

This is a bounded same-run progression step, not an engine feedback loop. Main
starts one cursor for one retained outcome, verifies and assesses each returned
batch once through the command's existing `LengthAssessmentContext`, and may
consume exactly one successor after no verification or complete behavioral
rejection. It does not rerun synthesis, reverify or reassess an earlier batch,
or fill a five-survivor quota. A survivor or preserve-all result remains
terminal, and the second candidate batch ends without a third tail probe.

Leant is experimental and promises neither stability nor backward
compatibility. The private names, numeric limits, deadline policy, diagnostics,
and output behavior recorded here describe the current tree and may be revised
before a stable release.

## Dependency and predecessor boundary

The vendored Djex revision remains
`f957549e36a63cd6003f5edef4ab8a867221813f`. It supplies the existing typed
candidate streams and candidate-independent scalar and binary-product Length
counterexample-bank scopes. This checkpoint changes no Djex source, gitlink,
query, evidence, replay, solver, identity, or search contract.

Two Leant predecessors meet at this boundary:

1. The historical
   [command-local counterexample-bank scheduler](2026-08-16-command-local-length-counterexample-bank-scheduler.md)
   introduced one rank-2 assessment context and one lazy reverse outcome
   accumulation across Main's existing baseline, provider, excluded-middle,
   and double-negation routes. Each engine run was still observed as one fixed
   batch.
2. The historical
   [opaque detailed synthesis cursor foundation](2026-08-16-opaque-detailed-synthesis-cursor-foundation.md)
   added ordered nonempty slices, unchanged run notes, explicit terminal
   taxonomy, selected-step forcing for a caller-owned deadline, and a
   cumulative 60-group cap over one retained detailed outcome. Main deliberately
   did not use it at that checkpoint.

Those reports remain correct point-in-time records and are not rewritten. This
report supersedes only their statements about the current Main runtime ceiling.
The [Z3 behavioral synthesis proposal](../Z3_Behavioral_Synthesis_Proposal/Z3_Behavioral_Synthesis_Proposal.pdf)
remains forward-looking for an engine which accepts counterexamples, typed
sketch completion, sound semantic-prefix pruning, further behavioral domains,
and Lean-checked proof artifacts.

## Private policy and run receipts

Main adds three private lazy types:

```haskell
data SynthLaneCursorPolicy = SynthLaneCursorPolicy
  { synthLaneCursorBatchSize :: Int
  , synthLaneCursorAllowsFilterSuccessor :: Bool
  , synthLaneCursorRetainsRunNotes :: Bool
  }

data SynthLaneRunEnd
  = SynthLaneRunStoppedByDisposition
  | SynthLaneRunBatchPolicyReached
  | SynthLaneRunNaturallyExhausted
  | SynthLaneRunHardCapReached
  | SynthLaneRunTimedOut
  | SynthLaneRunCursorAdmissionFailed DetailedSynthCursorError
  | SynthLaneRunEngineFailed String
  | SynthLaneRunRefuted Bool
  | SynthLaneRunNoTerm

data SynthLaneRun = SynthLaneRun
  { synthLaneRunAccumulation :: SynthLaneAccumulation
  , synthLaneRunCheckedFrontierSpellings :: [String]
  , synthLaneRunCandidateGroupCount :: Int
  , synthLaneRunNotes :: [String]
  , synthLaneRunEnd :: SynthLaneRunEnd
  }
```

All fields are lazy. None of the types derives or separately receives `Eq` or
`Show`, and none enters `ReplState`. Main exports only `main`, so these values
cannot become a public scheduler protocol. `DetailedCandidateBatch` and
`DetailedSynthCursor` remain Engine-opaque. Main imports the cursor type without
its constructor, the visible step constructors, and the batch accessors; it
never names the hidden batch type or reconstructs either hidden representation.

`SynthLaneRunEnd` separates policy completion from observed stream completion.
After the allowed one or two candidate batches, Main returns
`SynthLaneRunBatchPolicyReached` without advancing merely to decide whether the
tail is empty. `SynthLaneRunNaturallyExhausted` and
`SynthLaneRunHardCapReached` therefore retain the exact meanings established by
Engine. Error, refutation, and no-term payloads also stay distinct.

## Exact batch policy

The current route matrix is:

| Engine route | Rank or disabled | Explicit filter |
| --- | ---: | ---: |
| ordinary, universe-retry, or provider; Djinn or Exference | one batch, at most 12 groups | at most 12 + 12 groups |
| ordinary, universe-retry, or provider; `EngineBoth` | one batch, at most 24 groups | at most 24 + 24 groups |
| excluded-middle classical | one batch, at most 6 groups | one batch, at most 6 groups |
| double-negation classical; Djinn or Exference | one batch, at most 12 groups | at most 12 + 12 groups |
| double-negation classical; `EngineBoth` | one batch, at most 24 groups | at most 24 + 24 groups |

`ordinarySynthLaneCursorPolicy` obtains its width from
`synthVerificationWindow`: 12 for either standalone engine and 24 for
`EngineBoth`. A rank or disabled context sets the successor permission to
false; an explicit filter sets it to true. Ordinary policies retain run notes.

Excluded middle keeps the historical `synthMaxTried div 2` width of six, the
existing choice-point budget, no successor in any mode, and no handled run
notes. Double negation derives the ordinary cursor policy but disables handled
run notes. Its tuned Djinn candidate cutoff remains `synthMaxTried`, currently
12, for rank and disabled modes and becomes `candidateWindow`, currently 60,
for filter mode. The cutoff applies to Djinn and the Djinn half of
`EngineBoth`; Exference retains its own search limits.

The largest Main policy observes at most 48 groups from a combined run, below
Engine's cumulative 60-group cap. This checkpoint creates no separate 120-group
combined cap and makes no promise that either batch is full: a finite stream may
end early.

## One cursor and a literal two-batch ceiling

`runSynthLaneCursor` calls `startDetailedSynthCursor` exactly once for its
supplied `Either String DetailedSynthOutcome`. One private observation loop
then requests the policy width from the current cursor.

A candidate step performs this sequence once:

1. project and optionally transform the selected groups;
2. retain the batch's original run notes;
3. advance the cumulative same-run group count;
4. emit ordinary debug spelling rows with ordinals after the prior count;
5. call `verifySynthLane` once for that batch; and
6. classify the returned `SynthLaneOutcome` once.

The disposition controls continuation:

| Batch disposition | Same-run action |
| --- | --- |
| `SynthLaneNoVerified` | request the one permitted filter successor, otherwise stop by policy |
| `SynthLaneAllBehaviorallyRejected` | request the one permitted filter successor, otherwise stop by policy |
| `SynthLaneSurvivors` | stop immediately |
| `SynthLaneAssessmentPreserved` | stop immediately |

The continuation guard is the conjunction of the filter-successor permission
and `batchOrdinal < 2`. A continuing second candidate batch therefore stops by
policy. There is no third `advanceDetailedSynthCursor`, including a terminal-
only probe. Natural exhaustion, hard cap, timeout, admission failure, engine
failure, refutation, and no term instead finish with their matching run-end
constructor.

The cursor driver contains no synthesis call. Constructive scheduling creates
the lazy outcome once and passes it to this driver. Classical scheduling does
the same independently for EM and NN. Observing the successor therefore never
reruns Djinn, Exference, their combined merger, a provider lane, or a classical
translation.

## Exactly-once verification and assessment

Every nonempty cursor batch has its selected group list passed once to
`verifySynthLane`. That seam applies the caller's finite batch width before
projecting behavior mode. Rank keeps the five-success callback quota; filter
mode permits the complete current batch. A failed candidate group cannot pull
a lazy or cyclic tail through the verifier.

`verifySynthLane` invokes `synthVerify` once, constructs one exact
`VerificationBatch DetailedVerificationVariant`, and invokes
`assessLengthVerificationContext` once. `AssessedSynthLane` retains that exact
verification batch beside its one assessment. The cursor driver contains no
separate verification or assessment path around that one `verifySynthLane`
call, and it never passes an earlier outcome back through the seam.

Both same-run batches receive the one `LengthAssessmentContext command`
introduced before translation. Filter mode can therefore reuse a same-scope
counterexample-bank successor established by the first batch. Configured rank
contexts are bank-free and retain the established raw four-vector MRU path; the
disabled context remains a lazy identity and performs no behavioral assessment.
Any preserve-all assessment failure still preserves the complete current verified
batch without rolling back already completed bank transitions.

## Chronological frontier and observation ownership

Each `SynthLaneOutcome` retains its established two histories:

1. the complete rendered spelling frontier of its bounded batch, including
   variants which lazy callback verification did not need to attempt; and
2. the exact ordered callback-attempt trace recorded immediately before each
   Lean backend request.

`runSynthLaneCursor` buffers at most two outcomes in reverse order, reverses
them once, folds them into the command's existing reverse
`SynthLaneAccumulation`, and concatenates their complete spelling frontiers in
batch order. `SynthLaneRun` exposes that concatenation to the provider
scheduler. The narrower callback trace is never deduplication or scheduling
authority.

Candidate-group counts are cumulative across the run. `debugSynthLaneGroups`
starts a successor batch at the preceding count plus one, so debug group
ordinals do not restart. Each batch retains its own rendering and verification
observations; the plural finalizer later emits every retained outcome's metrics
in chronological order.

Provider progression occurs only after the run finishes. A continuing baseline
or provider run contributes its full concatenated spelling frontier to the
checked set before the next provider stage. The scheduler does not rerun an
engine to obtain a cursor successor, substitute callback attempts, or fill a
quota from a later route.

## Exactly-once run-note ownership

Engine associates the same original run notes with every cursor batch and
note-bearing terminal step. Main must therefore avoid presenting the same note
once per batch.

At run exit, `attachNotesToRightmostHandled` walks the reverse at-most-two
outcomes. It skips `SynthLaneNoVerified` and attaches the notes to the first
all-rejected, survivor, or preserve-all outcome it encounters. This is the
chronologically rightmost handled batch. The three handled cases share one
record update site each, and the attachment function is called once.

If every candidate batch is no-verification, no outcome receives the notes.
They remain only in `SynthLaneRun` and are printed after the final candidate or
no-term diagnostic when that run reaches the reporting boundary. Earlier all-
no-verification runs remain silent when scheduling continues. Both classical
policies disable handled-note retention; `synthClassical` contains no generic
note reporter. Debug-only EM summaries remain diagnostics rather than handled
lane notes.

## Mode-sensitive deadline ownership

`synthGo'` captures the ordinary command deadline once before constructive
search. Every baseline and provider cursor step uses the remaining part of that
same absolute deadline, so a second filter batch receives no renewed duration.
Provider discovery and earlier work continue to reduce what remains when the
next step is forced.

`runDetailedSynthCursorBefore` first calls `advanceDetailedSynthCursor`.
Admission remains outside the timeout and does not demand a valid cursor. For a
bounded deadline, Main then reads the clock, calculates the remaining
microseconds, and evaluates `forceDetailedSynthCursorStep` beneath `timeout`.
For `Nothing`, it forces the step without a timeout, preserving
`LEANT_SYNTH_TIMEOUT=0`.

`classicalSynthLaneDeadline` selects policy by behavior mode before any timeout
or clock read:

- filter mode returns the original command deadline unchanged, so ordinary
  work, both same-run batches, EM, and NN share one absolute budget and no
  classical clock is recaptured;
- rank and disabled modes read the configured timeout and capture a fresh full
  duration independently when EM is reached and again when NN is reached; and
- a nonpositive configured duration returns `Nothing` for that reached route.

An ineligible or skipped EM captures no EM deadline. A terminal EM survivor or
preserve-all result never reaches NN and therefore captures no NN deadline.
When EM continues for any other run end, rank/disabled NN receives its separate
fresh budget; filter NN receives the same original command deadline, which may
already be exhausted.

## Finalization and fallback gates

The existing lazy reverse `SynthLaneAccumulation` remains the command owner of
batch outcomes. Its pure disposition fold uses the chronological prefix through
the first survivor or preserve-all result. Continuation does not accumulate a
five-survivor quota: one survivor is terminal, presentation remains capped at
five, and every accumulated rejection remains visible.

`finalizeSynthLaneAccumulation` remains the sole owner of result effects:

- chronological metrics for retained outcomes;
- effective preserve-all warnings;
- one final synthesis-splice cache/binding phase;
- terminal candidate rows;
- prior and terminal rejection rows in attempt order; and
- handled notes in their chronological ownership order.

Final aggregate all-rejection clears once. A terminal survivor or preserve-all
result replaces the cache once. No first batch is finalized before the second
batch or later scheduling decision.

A sound provider-free Djinn refutation remains the structural control-flow
fallback. Provider timeout, cursor-admission failure, or engine error remains
masked by that stronger result, while every completed provider batch stays in
the accumulation. The fallback run retains its refutation taxonomy while Main
substitutes only the later completed accumulation.

The sound-refutation route passes the command deadline into `synthClassical`.
EM no-verification or all-rejection enters NN; survivor or preserve-all stops.
The classical helper returns only the updated accumulation and never finalizes.
Its caller retains the established provably-uninhabited,
unresolved-universe-annotation, and constructive/classical-hint gates.

Without a retained sound fallback, timeout, cursor-admission failure, or engine
failure finalizes completed outcomes before the corresponding abnormal
diagnostic. Ordinary aggregate all-rejection remains handled output and
suppresses an unrelated no-verification or no-term diagnostic.

## Deliberate exclusions

This checkpoint adds no:

- third cursor probe or total above two Main-selected candidate batches per
  engine run;
- engine rerun, replacement-candidate request, counterexample-directed search,
  or replay-only assessment delta;
- reverification or reassessment of an earlier batch;
- five-survivor quota filling within a run or across provider/classical routes;
- change to the public Engine cursor, Verification, Presentation, Integration,
  Ranking, Selection, or Djex contracts;
- change to command grammar, startup or contract-only JSON, solver protocol,
  query identity, evidence authority, or rejection taxonomy;
- new `ReplState`, history, snapshot, serialization, restoration, migration,
  session bank, or persistent cursor field;
- behavioral authority for natural exhaustion, hard-cap completion, timeout,
  engine failure, refutation, or raw solver status; or
- promise of API, representation, diagnostic, output, schema, or compatibility
  stability.

## Frozen characterization

The characterization commit changes only `test-unit/Spec.hs`. The existing
`bounded detailed synthesis cursor` group remains 10/10. Its architecture case
now verifies Main's accessor-only use while continuing to pin Engine opacity,
lazy positional representation, absence of `Eq` and `Show`, admission before
demand, exact-cap non-probing, selected-payload forcing, and successor/tail
laziness.

The `explicit Length assessment integration` group is now 24/24. Its nine Main
characterizations pin:

1. one assessment context beginning before translation and reaching every
   cursor batch;
2. the batch-local verification/assessment seam and unchanged 5/12/24/6
   constants;
3. chronological accumulation and first-terminal folding;
4. exactly-once plural finalization and effect order;
5. baseline/provider and EM/NN scheduling over complete run receipts;
6. lazy private policy, run-end, and run-receipt representation without frozen
   instances or persistent state;
7. one cursor start, one advance site, filter-only successor permission,
   NV/AR continuation, S/P termination, literal two-batch ceiling, complete
   terminal taxonomy, one verify/assessment per batch, full-frontier
   concatenation, cumulative debug ordinals, and rightmost note ownership;
8. filter command-deadline reuse beside independent reached-route rank/disabled
   EM and NN deadlines, including the zero-timeout boundary; and
9. normal, structural-fallback, cursor-admission, timeout, engine-error,
   no-term, and candidate-completion diagnostic gates.

Source assertions reject the old eager `runEngineBefore`, `runEngineBounded`,
and `forceDetailedOutcome` Main path; an engine rerun; callback-trace
deduplication; `remainingQuota` or `successesNeeded` quota loops; reassessment;
and progressive state in `ReplState`.

## Frozen source and test metrics

Production `d01fbd2` changes exactly one file by 395 insertions and 231
deletions. Its canonical binary diff has SHA-256
`4c231d2dcad8ecd816bbf2868b71d09aaaeafd6996a248f8d0d1f772ff061c7c`.

| File | Lines | SHA-256 |
| --- | ---: | --- |
| `src/Main.hs` | 5,033 | `5e2176ea2766da93a4510ec565afe5b6e825db36b9b5c665d239946a76ff9cfa` |

Characterization `3b1be06` changes exactly one file by 548 insertions and 194
deletions. Its canonical binary diff has SHA-256
`5c39f220cd2d726f27b587fcdb32ae08f4e501d54112a6d0e97e89ad18846ec8`.

| File | Lines | literal `testCase` tokens | registered/executed cases | SHA-256 |
| --- | ---: | ---: | ---: | --- |
| `test-unit/Spec.hs` | 23,602 | 455 | 454 | `16638f13430a95418196cbcdd20cb65b04b6d8eaadeb3af7638581caa2446801` |

As at earlier checkpoints, the literal token count is one greater than the
registered suite count. Neither commit changes another production or test
module, `leant.cabal`, `lib/Djex`, a golden input/output, or the transcript
runner.

## Validation evidence

The frozen production-and-characterization tree passed:

- 24/24 focused explicit Length assessment integration cases;
- 10/10 focused bounded detailed synthesis cursor cases;
- 7/7 strict command-local counterexample-bank runner cases;
- 454/454 complete strict Leant unit cases;
- strict warning-as-error builds of the unit-test component and every project
  target with `-Wall -Wcompat -Werror`;
- clean `cabal check`; and
- clean `git diff --check` before documentation changes.

Independent production and test audits checked cursor opacity at Main's import
boundary, one-outcome reuse, every run-end route, exact filter/rank/classical
batch policy, deadline capture order, verification and assessment cardinality,
full-frontier scheduling, chronological accounting, note ownership, finalizer
and fallback gates, and the absence of rerun, reassessment, quota filling, or
persistence.

All 26 ordinary golden transcripts passed byte-exact against the pinned Lean
4.31 backend, with exit status zero, no diff, and no update mode. The backend at
`/tmp/leant-repl-backend/.lake/build/bin/repl` had SHA-256
`0db3cff86ad773e2d8f21a69e84488ba32a6ea5ff40f0ec2ca8c0081013df059`.
The 26 `.txt` inputs, 26 `.golden` outputs, and `test/run-tests.sh` remained
unchanged. Their ordered 53-file aggregate remained
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

The maintained PDFs are generated artifacts and are intentionally unchanged in
the source-document checkpoint. The walkthrough likewise retains its previous
Leant source-link and title-page pin in this first stage. An artifact-only
successor will pin those three walkthrough locations to the exact frozen
source-document commit, complete this section with final source/render/link
evidence, and regenerate only the manual and walkthrough PDFs from separate
empty temporary directories with three fail-fast TeX passes each.

## Artifact successor evidence

The source-document checkpoint was frozen and pushed as
`778774d26109891565b9ca7a04cc59432273256b`. The artifact-only successor
changes the walkthrough's three Leant pin locations to that exact commit. Its
three Djex pin locations remain
`f957549e36a63cd6003f5edef4ab8a867221813f`. No former `a18f3d0` pin or other
stale Leant/Djex checkpoint pin remains in the walkthrough source, extracted
text, or URL annotations.

The final maintained sources are:

| File | Lines | SHA-256 |
| --- | ---: | --- |
| `docs/Leant.tex` | 1,925 | `37338f3b8ac749303c87a06ba01105ad55689b5deebfe9612bfdef567a781fb3` |
| `docs/Djex_Leant_Codebase_Walkthrough/Djex_Leant_Codebase_Walkthrough.tex` | 3,350 | `6e0ee8d76b6bc0d4b6d50acafb32f3184bdeff2bf69a5639590b407fab4dbc10` |

The manual was rebuilt in the initially empty
`/tmp/leant-progressive-stage2-manual.MRphsR` directory with three fail-fast
LuaLaTeX passes. The walkthrough was rebuilt independently in the initially
empty `/tmp/leant-progressive-stage2-walk.CZf1Rz` directory with three
fail-fast pdfLaTeX passes. Both used `-interaction=nonstopmode`,
`-halt-on-error`, and `-file-line-error`. Pass-two and pass-three stdout are
byte-identical for each document, with SHA-256
`81135f03e34e166a4e1daceda894ef04c230ac7dd31b8a8ac62224e8af83035f`
for the manual and
`69b5efe8b78db6566d7a6b13ad375aaaa0bedf02c0348b2acc2c680b2ba9fa56`
for the walkthrough. The engines were LuaHBTeX 1.14.0 and pdfTeX
3.141592653-2.6-1.40.22 from TeX Live 2022/dev/Debian.

The final artifacts are:

- `docs/Leant.pdf`: 32 pages, 193,868 bytes, SHA-256
  `d23f17f11af310474d95bb72eb21502b921f201aa81f94e46dc8536f7833405d`;
  and
- `docs/Djex_Leant_Codebase_Walkthrough/Djex_Leant_Codebase_Walkthrough.pdf`:
  119 pages, 784,405 bytes, SHA-256
  `77604e324799219fcdd4b911c6ba238d91c28c1a6be4bb5a96c739f13e098774`.

The final logs contain no literal `LaTeX Warning` or `Package ... Warning`
line and no undefined citation or reference, rerun request, missing glyph,
fatal diagnostic, or TeX error. The manual has no overfull box. It retains one
underfull box in the command grammar paragraph at source lines 1621--1671 and
eight in the dated-report path paragraph at lines 1759--1788. The walkthrough
retains four underfull boxes in the fixed descriptor-launch quotation at lines
463--464 and the pre-existing 36.05583-point overfull binder-hygiene paragraph
at lines 2050--2051.

Both PDFs are unencrypted, untagged PDF 1.5 documents on 612-by-792-point
letter pages, with expected title, author, producer, creation, and modification
metadata and with no form, JavaScript, embedded file, signature, raster-image
payload, or suspect-object flag. A raw object-key scan likewise finds no
JavaScript, launch, rich-media, embedded-file, filespec, XFA, open-action, or
additional-action key. Their 54 and 689 named destinations, respectively, have
no duplicate name. All eight manual font rows and all 17 walkthrough font rows
are embedded and subsetted with Unicode mappings.

Plain text extraction succeeds on every physical page. The manual extract is
85,849 bytes over 1,536 lines with SHA-256
`a9937cd0c7e129b90542f7f88791465608a95a4d56fc053d4b9100cd8efe19d0`.
The walkthrough extract is 313,830 bytes over 6,327 lines with SHA-256
`3ffe959d8aa52c4dcfdb1c95899a36b319a05b03e80779ca0f695448d6882159`.
UTF-8 validation finds no replacement character. The extracts retain the
progressive 12+12 and 24+24 filter ceilings, the one six-group
excluded-middle route, the double-negation cutoff of 60, no-verification and
all-rejection continuation, survivor and preserve-all termination, the
literal no-third-probe boundary, chronological frontiers and note ownership,
mode-sensitive deadlines, the 23,602/455/454 test inventory, full title-page
snapshots, and abbreviated pinned-tree labels.

The manual has 11 URL annotations: one repository link and ten relative report
links covering eight unique targets, all present. The walkthrough has 236 URL
annotations. All 179 Djex blob links use the exact `f957549` root; all 50 Leant
blob links use the exact `778774d` root; and the two repository-tree links use
those same full commits. The remaining five external kernel documentation,
source, and manual-page targets return HTTP 200. All 63 unique Djex blob
targets and all 18 unique Leant blob targets exist in the pinned Git trees.
The source contains three full Leant pins and three full Djex pins; the
annotation set contains 51 Leant and 180 Djex full-pin occurrences.

At 144 DPI, every rendered page is a 1,224-by-1,584-pixel RGB raster. Ordered
page-set SHA-256 values are
`6143f39329f05745b448c7a3c0c20ee917f5d6829fcc86a412b7e83e256c9da1`
and `0bb7e20cb119387b0d10c266ae9257863fee4f6961a364fe4b19b6e23b961fe8`
for the old and new manual, and
`50f54cc63a8a42f0579280480c4d93923390ffd768c8bb02f2c4184c66699768`
and `8b886c3f27bd98e43d555912e39a22869b56f7bbeb53118b6848da3e2eb75438`
for the old and new walkthrough. Exact same-resolution comparison with the
source-checkpoint artifacts finds changed physical pages 2 and 22--32 in the
manual, with page 32 newly added, and pages 1, 7, 11--28, 83--87, 91--92,
95--96, 111--112, and 118 in the walkthrough. Every other paired page is
byte-identical at raster level. Every changed page was inspected; the title
snapshot, progressive-run prose, tables, diagrams, current test inventory,
appendices, pinned-source entry points, and conclusions remain readable
without clipping, overlap, an orphaned fragment, or malformed line breaking.
The raster audit did not justify a pagination guard, so the walkthrough source
contains only the three authorized pin substitutions.

This evidence append, the three walkthrough pin substitutions, and the two
regenerated PDFs are the complete four-file artifact delta. It changes no
manual TeX, normative Markdown reference, reports index, historical report,
Haskell production or test source, Cabal file, golden fixture, or vendored
Djex file.
