# Package-private nominal Length counterexample-bank state

Date: 2026-08-16

## Outcome

Leant now has a package-private pure state foundation over Djex's nominal
scalar and binary-product counterexample banks. The production checkpoint is
`f4269f9c4762bdf6e3b6cbcfe1fe87ce6d9d19de`; its frozen characterization is
`dc2305731158ef4327cefd2dcc072cc89b667edf`.

Each nominal state retains already validated Djex limits and zero or one active
same-scope bank. It initializes lazily, discards that sole bank on exact scope
drift, traverses retained samples newest first through Djex's fresh query-owned
replay bridge, threads authoritative charged successors, and keeps replay-hit
promotion explicit and free of a second evaluation. Fresh receipt recording
likewise crosses the Djex bridge exactly once before inputs can be retained.

This is state machinery, not a runtime integration. There is no call site in
Ranking, Selection, Integration, or Main; no `IORef`, solver session, command
owner, candidate scheduler, persistence, or cross-lane continuation uses it.
The active four-entry assessment-local MRU and all external command behavior
remain unchanged.

Leant is experimental and promises neither stability nor backward
compatibility. These private types and contracts may be revised or deleted as
the later integration takes shape.

## Vendored Djex prerequisite

The preceding dependency checkpoint
`534f234d0bbf6816860392d0ddaad44713782fb0` pins `lib/Djex` to
`f957549e36a63cd6003f5edef4ab8a867221813f`. That Djex revision combines two
separate foundations:

- candidate-independent scalar/product scope identities and bounded immutable
  input stores; and
- exact query-owned operations which fresh-replay a supplied receipt before
  recording its inputs or replay one exact opaque sample retained by a
  same-scope bank.

Neither an old receipt nor a bank sample is behavioral evidence for a later
candidate. Scope equality authorizes only a fresh attempt against the current
query. Once Djex admits an attempt, its returned bank is authoritative even if
evaluation, association, reproduction, or insertion later refuses the
operation.

Djex deliberately does not own whole-bank traversal, hit promotion, Leant
candidate scheduling, a command lifetime, or persistence. The new Leant
module supplies the pure traversal and promotion policies while still owning
none of the later scheduling, lifetime, or persistence decisions.

## Nominal state ownership

`Leant.Synth.Length.CounterexampleBank.Internal` defines distinct scalar and
binary-product state families:

- `LengthCounterexampleBankState identity`; and
- `LengthSpinePairCounterexampleBankState identity`.

Both identity parameters have nominal roles. State and replay-hit constructors
remain hidden, while the closed outcome and error vocabularies required by
package-internal consumers are exposed. The two domains cannot be coerced or
silently funneled through one untyped adapter.

Each state owns exactly:

1. one validated domain-appropriate `CounterexampleBankLimits` value; and
2. `Nothing` or one immutable Djex bank carrying its exact scope, strict
   retained samples, and statistics.

The empty constructors retain their limits lazily and install no scope. The
default constructors use Djex's validated defaults but likewise start without
an active bank. Inspecting a new state's active-bank projection therefore does
not demand the limits or invent a scope.

The first replay or recording operation obtains the scope from its exact
opaque query and initializes one empty bank. A same-scope operation retains
the existing bank. A different scope replaces it with a new empty bank under
the original limits. That reset does not traverse or demand the discarded
sample list and does not carry statistics or inputs into the new semantic
target.

## Ordered whole-bank replay

`replayLengthCounterexampleBank` and
`replayLengthSpinePairCounterexampleBank` traverse the active bank's exact
opaque samples newest first. They do not perform input-vector lookup or choose
a different order from the immutable bank.

For every sample the adapter calls the matching Djex same-scope replay bridge
and immediately installs the returned successor bank before classifying the
result. The result classes are:

- a structural scope or retained-membership invariant failure;
- an ordered evaluation or association refusal, after which traversal
  continues to the next older sample;
- an ordinary non-counterexample miss, which also continues;
- ordinary bounded attempt unavailability, retaining the refusals which
  preceded the cap; or
- a hit carrying the preceding refusals and an opaque association between the
  exact retained sample, its scope, and a fresh current-query validated
  counterexample.

Complete exhaustion is an ordinary miss. Neither a refusal, miss, attempt cap,
nor scope match supplies negative or positive candidate evidence. The exact
attempt counter advances only when Djex admits real replay work, and no later
classification rolls that charge back.

## Explicit one-evaluation promotion

A replay hit does not mutate recency implicitly. The caller must pass the
opaque hit back to `promoteLengthCounterexampleBankReplayHit` or its nominal
product sibling.

Promotion first requires the state still to own a bank under the hit's exact
scope and then requires the identical opaque sample still to be retained. A
stale scope and a stale membership are distinct structural failures. Only
after both checks does promotion use Djex's ordinary input-only insertion with
the solver-independent-replay origin.

The fresh replay already evaluated and associated the inputs exactly once.
Promotion performs no second evaluation or receipt recording; it only applies
the bank kernel's exact-vector deduplication, origin replacement, newest-first
promotion, limits, eviction, and statistics. An insertion refusal leaves the
prior state available.

## Fresh-replayed receipt recording

The scalar and product recording entrances accept:

- bounded evaluation limits;
- the exact current query;
- one closed coarse origin;
- an existing validated counterexample receipt; and
- the current nominal state.

The supplied receipt is only a source of natural inputs. After lazy scope
initialization or reset, Djex admits one bounded attempt and replays those
inputs through the current query. Only a freshly reproduced current-query
counterexample can reach insertion. A miss does not record the vector.

Leant maps three coarse, non-authoritative receipt origins into Djex's closed
origin values:

- live-model replay;
- solver-independent replay; and
- simplification replay.

The adapter retains distinct outcomes for structural scope failure, evaluation
or association rejection, failure to reproduce the counterexample, bounded
attempt unavailability, bounded insertion unavailability, and successful
recording of the fresh receipt. Attempt and insertion unavailability are
ordinary bounded outcomes. Evaluation, association, and non-reproduction are
fail-closed record failures. In every case the bridge-returned successor state
is preserved.

## Deliberate exclusions

This checkpoint adds no:

- call from scalar or product Ranking, Selection, PostVerification, or
  Presentation;
- Integration request field, Main lane field, `ReplState` field, `IORef`, or
  mutable global;
- solver execution, SMT-LIB construction, worker reuse, or solver-status
  authority;
- automatic insertion from live observations, simplification, applicable-
  domain validation, or the active assessment-local MRU;
- automatic promotion, candidate verdict, pruning, or rejection decision;
- bank sharing across assessment batches, provider lanes, classical lanes,
  commands, sessions, or snapshots;
- serialization, persistence, concurrency, or migration policy; or
- public Leant API or user-visible diagnostic/output change.

In particular, the package-private module does not yet connect to Main's
`SynthLaneAllBehaviorallyRejected` disposition. That lane remains terminal,
and only `SynthLaneNoVerified` continues exactly as before.

## Frozen characterization

The focused group `package-private Length counterexample-bank ownership`
passes 12/12. It pins:

- lazy empty/default scalar and product initialization;
- first-scope acquisition and exact scope reset;
- origin-aware recording in both nominal domains;
- newest-first miss traversal and fresh hits;
- ordered refusal-to-hit and refusal-to-attempt-cap transitions;
- exact charged successor statistics;
- explicit promotion without reevaluation;
- stale-scope and stale-membership hit rejection;
- reproduction, evaluation, attempt, and insertion outcomes;
- zero-limit productivity before poisoned origins, receipts, samples, or
  evaluation limits;
- preservation of custom limits across scope rotation; and
- constructor opacity, exhaustive closed mappings, and nominal roles.

The tests intentionally distinguish the state transition from the evidence
projection. They inspect retained order, origins, and all six Djex statistics,
while a replayed receipt is checked only through its existing validated
counterexample projections.

## Frozen source metrics

The production checkpoint added 691 lines across the package manifest and new
module. The package-private implementation itself is frozen as:

| File | Lines | SHA-256 |
| --- | ---: | --- |
| `src/Leant/Synth/Length/CounterexampleBank/Internal.hs` | 689 | `914d48144d27d11e094eac63142185f65f62e37f13b527a22c7e50f195d63d52` |

The characterization checkpoint changes `test-unit/Spec.hs` by 1,435
insertions and one deletion. At that checkpoint:

| File | Lines | literal `testCase` tokens | SHA-256 |
| --- | ---: | ---: | --- |
| `test-unit/Spec.hs` | 20,966 | 430 | `2dd5beed5f863bf2219a649530d48d4bee85571805f7ae77aeddd8152bf37b8f` |

The literal token count is one greater than the executed suite count; the
complete Leant suite runs 429 tests.

## Validation evidence

The frozen production-and-characterization tree passed:

- 12/12 focused package-private bank-state cases;
- 429/429 complete Leant cases;
- strict all-target compilation and testing with `-Wall -Wcompat -Werror`;
- clean `cabal check`; and
- clean `git diff --check` before documentation changes.

The source checkpoint also preserved the then-existing 417-test runtime suite
unchanged; the characterization commit adds the 12 new package-private cases.
No runtime test expectation changed to accommodate this foundation.

## Documentation boundary

The current internal contract is summarized in
[`synth-internals.md`](../synth-internals.md#package-private-nominal-counterexample-bank-state),
and the user-facing Length reference distinguishes this dormant state from the
active assessment-local MRU in
[`length-ranking.md`](../length-ranking.md).

Djex's lower boundaries remain separately documented in its
[nominal bank report](../../lib/Djex/docs/reports/2026-08-16-nominal-length-counterexample-bank-foundation.md)
and
[fresh query-replay report](../../lib/Djex/docs/reports/2026-08-16-length-counterexample-bank-query-replay-bridge.md).

The earlier
[explicit synthesis-lane outcome report](2026-08-16-explicit-synthesis-lane-outcomes.md)
remains a point-in-time record of the dependency and Leant tree at that
checkpoint. The Z3 behavioral-synthesis proposal likewise remains deliberately
forward-looking for command-local ownership, all-rejected continuation,
cross-lane enumeration, and later CEGIS policy. Neither historical document is
silently rewritten into a claim that this dormant package-private state is the
completed loop.

## Documentation and artifact evidence

The current documentation source was frozen and pushed at
`0611e2c9685590508bf76cda165147c29b69d1fb`. The artifact-only successor
updates the walkthrough's source, title, and repository-tree links to that
exact Leant commit while retaining the vendored Djex revision
`f957549e36a63cd6003f5edef4ab8a867221813f`. The prepared date remains August
16, 2026, matching the source checkpoint.

The final documentation sources are:

| File | Lines | SHA-256 |
| --- | ---: | --- |
| `docs/Leant.tex` | 1,805 | `66a5be26c8cb75a22bd7d1e9d858b913f6b77d3278d3cfb6e0115461b8a1d050` |
| `docs/Djex_Leant_Codebase_Walkthrough/Djex_Leant_Codebase_Walkthrough.tex` | 3,245 | `464080a85f0bceeb1aba547131fe7003e86e518253253e6043301581bab51aa1` |

Both maintained PDFs were regenerated from new empty temporary directories
with three fail-fast passes apiece: LuaLaTeX for the manual and pdfLaTeX for
the walkthrough. Their final measurements are:

- `docs/Leant.pdf`: 30 pages, 185,216 bytes, SHA-256
  `9551f25c2bd1e76ac3234723b2d05a198767254617bde2fa1ed98374df14be8c`;
  and
- `docs/Djex_Leant_Codebase_Walkthrough/Djex_Leant_Codebase_Walkthrough.pdf`:
  117 pages, 770,545 bytes, SHA-256
  `05c288fc97a548cad5993e3c6fc05906a0caca4626ee43f72bc44cde66344d9e`.

The final logs contain no undefined citation or reference, rerun request,
missing glyph, fatal diagnostic, or TeX error. The manual retains one nonfatal
LuaTeX duplicate-`page.1` destination warning and four underfull paragraphs.
The walkthrough retains four underfull lines in the fixed descriptor-launch
quotation and one pre-existing overfull binder-hygiene paragraph containing
long fixed identifiers. PDF metadata inspection, text extraction, image-table
scanning, and font inspection all succeed. Every font is embedded and
subsetted with a Unicode mapping.

Extracted manual text contains the package-private nominal state, exact scope
reset, charged newest-first replay, evaluation-free promotion, dormant runtime
boundary, and report path. Its eleven URL annotations include ten relative
report targets, all present in the tree. Extracted walkthrough text contains
the exact full title-page snapshots, package-private state narrative, Djex
fresh-replay boundary, new module-map row, current report links, and abbreviated
pinned-tree labels.

The walkthrough has 236 URL annotations. All 179 Djex source links use the
exact `f957549e36a63cd6003f5edef4ab8a867221813f` blob root, all 50 Leant source
links use the exact `0611e2c9685590508bf76cda165147c29b69d1fb` blob root, and
the two repository-tree links use those same full commits. No prior
`d3a57be`, `30bbb0a`, `a9150c`, or `6802674` pin remains in the walkthrough
source, extracted text, or URL annotations.

The manual's physical PDF page 27 and the walkthrough's physical pages 1, 11,
19, 24, 27, and 116 were raster-inspected. The updated manual paragraph and
report path, exact title snapshot table, addendum headline, detailed bank-state
boundary, module-map row, current report links, and pinned-tree appendix are
readable without clipping, overlap, or malformed line breaking.

This evidence paragraph, the walkthrough pin refresh, and the two regenerated
PDFs form a four-file artifact delta after the frozen source-doc commit. They
change no Haskell production or test source, Cabal file, vendored Djex file,
manual TeX, normative Markdown reference, or earlier point-in-time report.
