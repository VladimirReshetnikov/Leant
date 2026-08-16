# Filter-only nominal Length counterexample-bank context runner

Date: 2026-08-16

## Outcome

Leant now runs its additive context-aware scalar and binary-product filtering
path through the nominal counterexample-bank state introduced at the preceding
foundation checkpoint. The production integration landed as
`6fb4c7235a55b29b11351d499865f90276a1564b`; the exception-safe context-cell
successor is `fbd68c20a02195327bf67b47d303c7bea62526e3`. The independently
audited characterization is
`539d89feb2a30d421c8a2b6f47f4ed508d6ae6ef`.

This is deliberately a filter-only runtime integration. Existing ranking
entrances and the direct scalar/product Selection compatibility entrances keep
their literal raw `[[Natural]]`, newest-first four-vector MRU. The new
context-aware Configuration and Selection entrances thread one nominal bank
through the scalar or pair internal runner. No rank API, raw-MRU contract,
query identity, solver protocol, evidence authority, selection rule, Main
scheduling decision, presentation code/format, or binding policy changed.

Leant is experimental and promises neither stability nor backward
compatibility. These package-internal names and contracts are a current-tree
specification, not a commitment to preserve an earlier design.

## Dependency and foundation boundary

The vendored Djex revision remains
`f957549e36a63cd6003f5edef4ab8a867221813f`. It owns nominal scalar and product
bank scopes, bounded immutable input stores, and query-owned bridges which
freshly replay a receipt before recording its inputs or replay one retained
sample against a later query. A scope match grants only an attempted fresh
evaluation; no retained vector or old receipt is a reusable verdict.

Leant's historical foundation commit
`f4269f9c4762bdf6e3b6cbcfe1fe87ce6d9d19de` added pure nominal state, ordered
whole-bank replay, explicit hit promotion, and fresh receipt recording without
a runtime caller. Its dated
[foundation report](2026-08-16-nominal-length-counterexample-bank-state.md)
remains a point-in-time record and is not rewritten. This checkpoint adds the
mutable command-tagged context and filter runner on top of that state.

## Nominal context ownership

`Leant.Synth.Length.CounterexampleBank.Internal` now defines abstract scalar
and product contexts. Each context's `command` type parameter has a nominal
role beside its nominal semantic identity parameter, and its introducer binds
`command` inside a rank-2 callback. Context replay returns a
command-tagged opaque hit, so even two owners with the same Djex semantic
identity cannot exchange promotion authority.

The scalar and product introducers allocate one fresh empty state under
caller-validated or default bank limits and lend the context only through a
rank-2 callback. A read-only state projection provides immutable diagnostic
snapshots. There is no setter, snapshot-consuming constructor, serialization
entrance, or way to restore an earlier state.

The first replay or record transition initializes the bank from the exact
query-owned scope. A later same-scope query retains it. Exact scope drift
replaces it with one empty bank under the original limits, without traversing
or carrying samples or statistics from the discarded scope.

## Serialized exception-restoring transitions

Each private context cell is an `MVar` containing the complete nominal state.
Replay, promotion, and recording use `modifyMVar`, so concurrent transitions
are serialized and an exception in the callback restores the old value. The
callback fully evaluates the successor's validated limits and complete active
bank, then forces the outer `Either` and its selected failure or outcome
constructor to weak head normal form before returning the value to be
installed.

This force boundary prevents a lazy input, origin, sample, statistic, or limit
exception from publishing a poisoned successor. A synchronous or asynchronous
exception during preparation leaves the old state installed and propagates to
the caller. A completed expected classification installs Djex's authoritative
successor even when the result is an ordinary refusal, miss, attempt-cap, or
insertion-cap outcome.

The `MVar` masks only its take/restore/install mechanics. The callback runs
under `modifyMVar`'s restored exception state; Leant does not mask a complete
ranking pass, solver session, candidate loop, or simplification traversal.

## Raw compatibility cursor and nominal filter cursor

The scalar and product `Ranking.Internal` modules now carry one private cursor
with two branches:

1. the established raw four-vector batch-local bank; or
2. one explicitly supplied nominal context.

Every existing ranking entrance constructs branch 1. The direct
`selectVerifiedLengthCandidatesWithPolicy` and product sibling also retain
their established raw assessment. Additive context-aware Configuration and
Selection entrances select branch 2. Integration uses only those new entrances
for filter contexts.

Both cursor branches run through the same scalar/product candidate machinery:

- eager opening, where the worker opens before bank replay;
- deferred opening, where bank, applicable-domain, and origin work precedes
  the first live open;
- no shared usable-work budget;
- the retained runtime-unscoped v1 usable-work owner; and
- the current owner-thread-affine scoped-v2 usable-work owner.

The scoped runner commits a completed cache transition before its following
cooperative checkpoint. Deadline expiry at that checkpoint can preserve the
candidate batch, but cannot make the already completed bank update disappear.

## Per-candidate source and receipt flow

The source order is unchanged:

```text
selected newest-first bank replay
  -> applicable-domain traversal
  -> all-zero origin probe
  -> live query and query-first replay
  -> post-unsat explicit input-box traversal
```

Expected per-sample evaluation or association refusals are kept in attempt
order while traversal continues. An ordinary non-counterexample also
continues. Exhaustion and attempt-cap unavailability are ordinary misses and
grant no candidate authority. Only a structural replay invariant failure maps
to the established indexed evidence-replay mismatch.

A nominal replay hit keeps its command-tagged sample association until the
candidate's optional simplification finishes:

- an unsimplified hit promotes the exact sample without a second evaluation;
- a simplified hit records the final receipt under simplification replay
  instead of promoting the original sample;
- a fresh live-model counterexample records under live-model replay;
- a fresh applicable-domain, origin, or input-box counterexample records under
  solver-independent replay; and
- any strict reduction records under simplification replay regardless of its
  acquisition source.

The assessment always retains its pre-record final receipt and optional
simplification metadata. The fresh receipt returned by recording confirms only
the cache transition and does not replace candidate evidence. Expected record
attempt or insertion unavailability retains the authoritative successor and
the existing assessment. Fail-closed evaluation, association, reproduction,
stale-scope, stale-membership, or promotion-insertion mismatch becomes the
existing indexed evidence-replay failure.

A fatal simplification failure performs no promotion or recording for that
candidate. If acquisition already completed a nominal replay transition, that
charge and successor remain. This is the same direction as every later
failure: cache effects which completed before candidate-report fallback are
not rolled back.

## Selection and fallback boundary

The context-aware scalar and product Selection adapters use the same total
behavioral-partition seal and the same closed decision taxonomy as their raw
compatibility siblings. Preparation refusal, `Unassessed`, every raw solver
status, `BoundedPositive`, and `ApplicableDomainEstablished` retain the exact
occurrence. Only an independently replayed `Counterexample` rejects it.

Any post-verification, ranking, index, admission, or partition failure still
returns the complete original `VerificationBatch` with no partial rejection.
That preserve-all contract concerns candidate ownership and presentation. It
does not rewind replay charges, promotions, or recordings which already
completed in the reusable context. Unexpected exceptions remain exceptions;
they are not classified as a selection result.

## Integration lifetime and current Main ceiling

`Leant.Synth.Length.Integration` adds abstract
`LengthAssessmentContext command` and three operations:

- `withLengthAssessmentRequestContext` introduces its nominal lifetime;
- `lengthAssessmentContextBehaviorMode` projects only the strict mode tag; and
- `assessLengthVerificationContext` assesses one batch through the retained
  owner.

Disabled and rank contexts contain no bank. Scalar and product filter contexts
contain exactly one matching nominal bank. A caller which remains inside the
rank-2 callback may invoke `assessLengthVerificationContext` repeatedly and
reuse that bank across batches.

The compatibility `assessLengthVerificationRequest` entrance introduces a
fresh context for every call and assesses exactly one batch. Main is unchanged
and still calls that wrapper separately from each bounded lane assessment.
Consequently, the current executable shares a filter bank among candidates in
one assessed lane but not across lanes. The request may travel on the command
stack, but the context does not.

There is no Main-owned full-command context, cross-lane candidate continuation,
new provider or classical scheduling decision, `ReplState` field, history or
snapshot field, serialization, persistence, restoration, or migration policy.
An all-rejected lane remains terminal, and only the established no-verified
disposition can continue.

## Deliberate exclusions

This checkpoint adds no:

- change to the public Ranking facade or direct raw-MRU Selection behavior;
- change to ranking order, filtering taxonomy, presentation row/note formats,
  or `itN` binding policy;
- Main, `Engine`, `Verification`, Presentation, ReplState, Cabal, CLI grammar,
  configuration schema, or contract schema change;
- new solver operation or protocol stage, worker-sharing policy, query
  identity, protocol byte, status authority, or evidence type;
- cross-lane enumeration, command-wide retry, all-rejected continuation,
  prefix pruning, or typed sketch completion;
- global mutable bank, persistent cache, disk format, snapshot sidecar, or
  migration surface; or
- promise of API, schema, diagnostic, or output compatibility.

In particular, the reusable rank-2 Integration seam is capacity for a later
scheduler owner. It is not evidence that Main currently supplies that owner or
that the proposal's Level-2 command-local CEGIS loop is complete.

## Frozen characterization

The existing package-private bank group grew from 12 to 14 cases by adding
scalar and product exception-atomic transition tests. Each test catches both a
synchronous poisoned transition and an asynchronous interruption, then proves
that an immutable snapshot still exposes the complete pre-transition bank.

The new group `command-local Length counterexample-bank runners` contains seven
cases:

1. scalar reuse through every eager, deferred, unbudgeted, v1, and scoped-v2
   route;
2. the nominal product mirror through the same route matrix;
3. scalar/product attempt and insertion cap behavior;
4. scalar/product selection sealing, preserve-all behavior, and resumed reuse;
5. preservation after live-session failure without cache rollback;
6. reusable Integration filter contexts beside fresh compatibility wrappers
   and bank-free rank calls; and
7. nominal, failure-atomic, package-private, and fatal-before-commit source
   boundaries.

Together the focused bank adapter and runner groups pass 21/21. The tests pin
source provenance, newest-first reuse, eager/deferred open order, all three
budget strategies, authoritative cap successors, final receipt and
simplification timing, scalar/product separation, selection association,
context lifetime, exception restoration, and the Main/source ceiling.

## Frozen source and test metrics

Relative to the pre-integration characterization `dc23057`, the complete
production checkpoint changes exactly seven Haskell files by 1,843 insertions
and 580 deletions:

| File | Lines | SHA-256 |
| --- | ---: | --- |
| `src/Leant/Synth/Length/Configuration.hs` | 1,191 | `548630163f576f8b36c794e1db7241d7aa1e573b6db3cb3d04fdcb7807580c23` |
| `src/Leant/Synth/Length/CounterexampleBank/Internal.hs` | 994 | `2d2f098674a2e70317739a434abe448a6c068d8a6f4df1f1cd9b8d66e53b40d8` |
| `src/Leant/Synth/Length/Integration.hs` | 541 | `c37516d0f6c0fa12fcfa84466d65445e690c3c029a4c3287c0a00ceaba9dd2d9` |
| `src/Leant/Synth/Length/Ranking/Internal.hs` | 2,660 | `eec8c9a3d64f765ea2e5aa75ff7a9f249fb7658d4dc8157f312370abf7dc4040` |
| `src/Leant/Synth/Length/Selection/Internal.hs` | 368 | `9235993d24a47b6d58dbb5fa224ac53a56e3b65388d2c129cdb463de574aada4` |
| `src/Leant/Synth/Length/SpinePair/Ranking/Internal.hs` | 2,503 | `7764c3a23f61425d6c70ae7cc947e5b4042334448f3bed4cc631fb9d14bda734` |
| `src/Leant/Synth/Length/SpinePair/Selection/Internal.hs` | 371 | `ad72fbf63f40882bbd7607475e764762e3d07f3c0fb4160f9edeafda2fdc9443` |

The exception-safe successor itself changes only
`CounterexampleBank/Internal.hs` by 48 insertions and 23 deletions. The frozen
test checkpoint changes only `test-unit/Spec.hs` by 1,274 insertions and no
deletions:

| File | Lines | literal `testCase` tokens | registered/executed cases | SHA-256 |
| --- | ---: | ---: | ---: | --- |
| `test-unit/Spec.hs` | 22,240 | 439 | 438 | `d011f4aa07e6ba16697e8fa5cb93d86cbca15557a90b15e8525627ec07d29f77` |

The literal token count is one greater than the registered suite count, as at
the preceding checkpoints.

## Validation evidence

The frozen production-and-characterization tree passed:

- 21/21 focused strict bank adapter and runner cases;
- 438/438 complete strict Leant unit cases;
- strict all-target compilation with `-Wall -Wcompat -Werror`;
- clean `cabal check`; and
- clean `git diff --check` before documentation changes.

Independent source and test audits checked the scalar/product mirror, every
opening/budget route, exception restoration, provenance, cap behavior,
selection continuity, Integration lifetime, package-private surface, and the
absence of Main, persistence, and vendored-Djex changes.

## Documentation and artifact boundary

Current behavior is specified by the
[Length behavioral reference](../length-ranking.md), the
[`synth` internals map](../synth-internals.md), the maintained manual and
walkthrough sources, and current code. Earlier dated reports remain historical
landing records. In particular, the nominal-state foundation report correctly
says its `f4269f9` checkpoint had no runtime caller; this report supersedes only
that current-tree statement.

The [Z3 behavioral synthesis proposal](../Z3_Behavioral_Synthesis_Proposal/Z3_Behavioral_Synthesis_Proposal.pdf)
remains forward-looking for a scheduler-owned full-command bank, cross-lane
enumeration, typed sketches, sound prefix pruning, further domains, and
Lean-checked proof artifacts.

The maintained PDFs are generated artifacts and are intentionally unchanged in
the source-document checkpoint. An artifact-only successor will pin the
walkthrough to the exact frozen source-document commit, complete this section
with final hashes and rendered checks, and regenerate only the manual and
walkthrough PDFs from clean temporary directories.
