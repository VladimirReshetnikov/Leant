# Opaque detailed synthesis cursor foundation

Date: 2026-08-16

## Outcome

Leant's Engine module now exposes a lazy opaque continuation for observing one
detailed synthesis outcome in more than one bounded slice. The production
checkpoint is `5d559a5a4d16993d7131c35ca6323827c826e6e4`; its independently
reviewed characterization is
`5382f743ae2bf8c273fd8c8aa43ba7590bc3729e`.

This is an Engine-only observation foundation. It does not change `src/Main.hs`
or any command's runtime schedule. Main still forces one caller-bounded lane,
verifies and assesses that finite prefix once, and stops on the first survivor
or preserve-all result. The cursor neither reruns an engine nor asks it to
synthesize a replacement. It retains one existing lazy detailed outcome and
exposes successive prefixes of that value under the established 60-group
product-wide hard cap.

Leant is experimental and promises neither stability nor backward
compatibility. The names and representation choices recorded here describe the
current tree rather than committing a future release to preserve this module
surface.

## Predecessor and dependency boundary

The immediate Leant predecessor is the command-local counterexample-bank
scheduler recorded in the historical
[scheduler report](2026-08-16-command-local-length-counterexample-bank-scheduler.md).
That checkpoint introduced one assessment context around Main's existing
baseline, provider, excluded-middle, and double-negation lane plan. It could
continue after no verification or complete behavioral rejection, but every
engine invocation was still observed through one fixed lane window.

The vendored Djex revision remains
`f957549e36a63cd6003f5edef4ab8a867221813f`. It supplies the existing search
streams, opaque typed-candidate machinery, and candidate-independent Length
counterexample-bank bridge. Leant Engine retains its own typed rendering and
semantic sidecars around those results. This cursor changes no Djex source,
submodule pin, query, evidence, progress, solver, or search contract.

The [Z3 behavioral synthesis proposal](../Z3_Behavioral_Synthesis_Proposal/Z3_Behavioral_Synthesis_Proposal.pdf)
calls for progressive engine batches during command-local candidate CEGIS.
This checkpoint lands only the neutral same-run observation prerequisite. It
does not connect that prerequisite to verification, behavioral assessment, or
Main's scheduler.

## Opaque representation boundary

`Leant.Synth.Engine` adds this exported surface:

```haskell
data DetailedCandidateBatch
detailedCandidateBatchGroups :: DetailedCandidateBatch
  -> [DetailedCandidateGroup]
detailedCandidateBatchNotes :: DetailedCandidateBatch -> [String]

data DetailedSynthCursor

data DetailedSynthCursorError
  = DetailedSynthCursorBatchSizeNotPositive Int
  | DetailedSynthCursorBatchSizeLimitExceeded Int Int

data DetailedSynthCursorStep
  = DetailedSynthCursorCandidateBatch
      DetailedCandidateBatch DetailedSynthCursor
  | DetailedSynthCursorNaturallyExhausted [String]
  | DetailedSynthCursorHardCapReached [String]
  | DetailedSynthCursorEngineFailed String
  | DetailedSynthCursorRefuted Bool
  | DetailedSynthCursorNoTerm [String]

startDetailedSynthCursor
  :: Either String DetailedSynthOutcome -> DetailedSynthCursor
advanceDetailedSynthCursor
  :: Int -> DetailedSynthCursor
  -> Either DetailedSynthCursorError DetailedSynthCursorStep
forceDetailedSynthCursorStep :: DetailedSynthCursorStep -> Int
```

The error and step constructors are visible so a caller can classify admission
and observation results. The `DetailedCandidateBatch` and
`DetailedSynthCursor` constructors are not exported. Both hidden
representations are positional and lazy. They have no record syntax, strict
field, derived instance, or separately declared `Eq` or `Show` instance.

Only Engine can associate a returned group slice with the run-level notes and
only Engine can create a cursor with its consumed-count invariant. A returned
candidate batch is nonempty. This is ordinary Haskell abstraction, not a
linear or affine capability: a caller can retain and reuse an earlier pure
cursor value. The guarantee is that every such cursor refers to the same
retained detailed outcome, so observation never reruns synthesis.

## Admission before observation

`startDetailedSynthCursor` stores the initial consumed count and outcome
without evaluating the outcome's `Either`, verdict, notes, or candidate stream.

`advanceDetailedSynthCursor` validates its requested per-step group count
before it demands the cursor:

| Request | Result |
| --- | --- |
| `requested <= 0` | `DetailedSynthCursorBatchSizeNotPositive requested` |
| `requested > candidateWindow` | `DetailedSynthCursorBatchSizeLimitExceeded candidateWindow requested` |
| `1 <= requested <= candidateWindow` | lazy outer `Right` containing the step computation |

`candidateWindow` remains 60. The over-limit error records the maximum first
and observed request second. Zero, negative, 61, and `maxBound :: Int`
requests therefore terminate without inspecting even a bottom cursor.

For a valid request, observing only the outer `Right` also leaves the cursor
untouched. Forcing the contained `DetailedSynthCursorStep` is the point which
demands the cursor and the outer detailed outcome constructor. This separates
pure request admission from the search and rendering work which belongs under
a caller-owned deadline.

## Ordered batches and the cumulative cap

Before the hard cap, a candidate advance selects:

```text
min requested (60 - groups already returned)
```

groups from the remaining stream. It returns a candidate step only when that
slice is nonempty. The groups retain original engine order. The successor
retains the unselected stream tail and the actual number of groups returned,
not the nominal request size. A short finite stream can therefore produce, for
example, batches of 2, 2, and 1 from repeated requests of 2.

Every candidate batch carries the original run-level notes unchanged. The same
notes are also retained by natural-exhaustion and hard-cap terminal steps.
This is association, not presentation policy: the cursor does not print,
deduplicate, suppress, or decide when a later scheduler should emit those
notes.

The completion vocabulary deliberately separates two facts:

| Step | Observation |
| --- | --- |
| `DetailedSynthCursorNaturallyExhausted` | An advance while below 60 observed an empty candidate stream |
| `DetailedSynthCursorHardCapReached` | 60 groups had already been returned; the remaining stream was not probed |

A 59-group finite stream followed by another advance is naturally exhausted.
An exactly 60-group finite stream followed by another advance is capped,
because proving natural exhaustion would require looking beyond the product
bound. The same cap result is productive when group 61 is bottom or the tail is
cyclic. Thus hard-cap completion carries no negative evidence and makes no
claim about whether another engine group exists.

Requests near the cap are clamped to the remaining allowance. Requests of 7,
19, and 40 over a cyclic stream return batches of 7, 19, and 34, respectively,
then report the cap. No caller-selected total above 60 and no separate
120-group combined-engine ceiling is part of this contract.

An initial engine error, `DetailedSynthRefuted` outcome, or
`DetailedSynthNoTerm` outcome keeps its existing payload and receives its own
terminal step. An initially empty candidate stream is natural exhaustion. The
cursor does not collapse any of these cases into an empty batch or reinterpret
their evidence strength.

## Deadline forcing boundary

The engine is pure and lazy, so returning a step does not establish that the
selected search and rendering work happened inside a timeout.
`forceDetailedSynthCursorStep` supplies the bounded value which a caller can
evaluate under its own wall-clock guard.

For a candidate step it demands:

- the complete selected group-list spine and each group constructor;
- each selected group's rendering route to weak head normal form;
- each selected variant-list spine and each variant constructor far enough to
  project its text;
- each selected rendered spelling's `String` list spine through `length`; and
- the run-note list spine and each note's `String` list spine through `length`.

`String` is a list of `Char`. Traversing its spine through `length` does not
force the `Char` heads and performs no text encoding, so this boundary makes no
claim about character or byte normal form.

It deliberately does not force:

- a group semantic sidecar;
- a variant's recovered exact typed origin;
- any selected spelling or note `Char` value;
- the successor cursor; or
- any unselected candidate-stream tail.

A selected bottom route, whole-spelling or whole-note thunk, bottom selected
`String` list-spine tail, or later selected group therefore fails while forcing the
step. A bottom `Char` head, successor, group 61, or lazy recovered-origin search
does not. Terminal steps demand the same error/note `String` list spines or
refutation `Bool` as the historical `forceDetailedOutcome` boundary.

The existing `forceDetailedOutcome` implementation is refactored only to share
private group and note forcing helpers with the cursor. Its observable force
boundary remains unchanged, including the lazy recovered-origin behavior used
by combined-engine exact-text provenance recovery. Neither force helper starts
a timer, catches an exception, or owns IO.

## Main and runtime remain unchanged

`src/Main.hs` at this checkpoint is byte-identical to the command-local
scheduler production checkpoint. Its SHA-256 remains
`2541d582aac5e0a6714ad3f0ff833ad57681698a1a6bde13b7d5946acc7b6937`.
The cursor characterization also asserts that Main contains none of the new
batch, cursor, error, step, start, advance, or force names.

Main continues to call `forceDetailedOutcome` through `runEngineBounded` and
`runEngineBefore`. Its current behavior therefore remains:

| Lane | Engine group prefix | Rank accepted-group quota | Filter accepted-group quota |
| --- | ---: | ---: | ---: |
| standalone Djinn or Exference | 12 | 5 | 12 |
| combined engine | 24 | 5 | 24 |
| excluded-middle classical | 6 | 5 | 6 |
| double-negation classical | 12 or 24 by engine | 5 | 12 or 24 by engine |

Each current lane is still verified and assessed as one batch. The command's
Length assessment context and bank may cross existing lanes, but there is no
new within-run engine slice. No-verification and all-rejection still continue
only through the existing provider/classical plan. One survivor or
preserve-all result still terminates immediately rather than filling five
presentations.

The cursor therefore owns none of Main's:

- provider checked-frontier deduplication;
- verification callback trace;
- `VerificationBatch` or Length assessment;
- counterexample-bank context or replay schedule;
- lane outcome, disposition, or accumulation;
- warning, note, rejection, candidate, binding, or cache effect; or
- structural, classical, timeout, or error diagnostic gate.

## Deliberate exclusions

This checkpoint adds no:

- change to command grammar, startup or contract-only JSON, behavior mode, or
  user-visible output;
- change to Main, Verification, Integration, Length ranking/selection, Cabal,
  or the vendored Djex tree;
- engine rerun, replacement-candidate request, counterexample-directed search,
  or typed-prefix pruning;
- progressive verification or assessment wiring;
- five-survivor quota filling within or across lanes;
- replay-only assessment delta for a later raw input batch;
- persistent cursor, counterexample bank, `ReplState`, history, snapshot,
  serialization, restoration, or migration field;
- natural-exhaustion claim after the 60-group boundary;
- promise to expose a combined outcome beyond its first 60 groups; or
- promise of API, representation, diagnostic, output, or compatibility
  stability.

## Frozen characterization

The characterization commit changes only `test-unit/Spec.hs`. Its focused
`bounded detailed synthesis cursor` group passes 10/10 and pins:

1. ordered 2/2/1 batches, unchanged notes, and later natural exhaustion;
2. engine failure, both refutation flags, no-term, and initially empty-stream
   taxonomy;
3. nonpositive and over-60 admission errors before a poisoned cursor;
4. lazy start and lazy valid outer `Right`, followed by failure only when the
   poisoned step is demanded;
5. 59-group natural exhaustion versus the exact 60-group hard-cap tie;
6. a poisoned group 61, cap-time validation precedence, and terminal force
   parity;
7. productive 7/19/34 clamping over a cyclic varied stream;
8. candidate and terminal parity with `forceDetailedOutcome`, including lazy
   recovered-origin lookup;
9. forcing of every selected route, bottom whole-spelling and whole-note
   thunks, and a later selected group, beside laziness of the explicit
   successor and unselected tail; and
10. exact opaque exports, positional lazy representation, absence of `Eq` and
    `Show` instances, and absence of every new symbol from Main.

The architecture check searches both declaration syntax and separately
declared qualified or unqualified instance heads. It therefore rejects a later
attempt to freeze comparison or display semantics outside the data
declarations as well as an accidental derived instance.

## Frozen source and test metrics

Production `5d559a5` changes exactly one file by 139 insertions and 3
deletions:

| File | Lines | SHA-256 |
| --- | ---: | --- |
| `src/Leant/Synth/Engine.hs` | 4,509 | `3d42c3f1cbcd01604f57d4969d95850ffdb2d2a82b377b589183eb70e11c64f6` |

Characterization `5382f74` changes exactly one file by 562 insertions and 2
deletions:

| File | Lines | literal `testCase` tokens | registered/executed cases | SHA-256 |
| --- | ---: | ---: | ---: | --- |
| `test-unit/Spec.hs` | 23,248 | 452 | 451 | `f6024bfdbb3c504695acb785d2dc709610fbd6bad64e3389fce28f1b7d931e44` |

The literal token count is one greater than the registered suite count, as at
the preceding checkpoints.

The unchanged Main source remains 4,869 lines with the SHA-256 stated above.
Neither production nor characterization changes `leant.cabal`, `lib/Djex`, a
golden input/output, or another production or test module.

## Validation evidence

The frozen production-and-characterization tree passed:

- 10/10 focused bounded detailed synthesis cursor cases;
- 7/7 strict command-local counterexample-bank runner cases;
- 21/21 strict explicit Length assessment integration cases;
- 451/451 complete strict Leant unit cases;
- strict warning-as-error builds of the unit-test component and all targets
  with `-Wall -Wcompat -Werror`;
- clean `cabal check`; and
- clean `git diff --check` before documentation changes.

Independent source and test audits checked representation opacity, admission
precedence, start and outer-result laziness, actual-count succession, ordered
notes, terminal taxonomy, exact-cap non-probing, cyclic productivity, force
parity, selected-versus-unselected demand, the unchanged Main call path, and
the absence of persistence or scheduler coupling.

All 26 ordinary golden transcripts also passed byte-exact against the pinned
Lean 4.31 backend, with exit status zero, no diff, and no update mode. The
backend at `/tmp/leant-repl-backend/.lake/build/bin/repl` had SHA-256
`0db3cff86ad773e2d8f21a69e84488ba32a6ea5ff40f0ec2ca8c0081013df059`.
The 26 `.txt` inputs, 26 `.golden` outputs, and `test/run-tests.sh` remained
unchanged. Their ordered 53-file aggregate was
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

Current behavior and the dormant cursor boundary are described by the
[Length behavioral reference](../length-ranking.md), the
[`synth` internals map](../synth-internals.md), the maintained manual and
walkthrough sources, this report, and current code. Earlier dated reports remain
historical landing records rather than normative contracts.

The maintained PDFs are generated artifacts and are intentionally unchanged in
the source-document checkpoint. The walkthrough also retains its previous
Leant source-link and title-page pin in this first stage. An artifact-only
successor will pin those three walkthrough locations to the exact frozen
source-document commit, complete this section with final source/render/link
evidence, and regenerate only the manual and walkthrough PDFs from separate
empty temporary directories with three fail-fast TeX passes each.
