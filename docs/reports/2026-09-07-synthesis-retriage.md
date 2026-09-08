# Synthesis re-triage: bounded contexts, reliable checking, and behavior

This 2026-09-07 update preserves the active goal to implement priorities 1–4
from the [original roadmap](../../lib/Djex/docs/reports/2026-09-06-synthesis-next-priorities.md).
The [completion register](https://github.com/VladimirReshetnikov/Djex/blob/fcea4779508f10b608f0ad59293d7c7cca121b29/docs/reports/2026-09-07-synthesis-priorities-1-4.md)
retains the full scope. The current canonical
[Djex re-triage](https://github.com/VladimirReshetnikov/Djex/blob/main/docs/reports/2026-09-07-synthesis-retriage.md)
also covers working changes newer than this repository's pinned dependency.

## Current decision and next delivery gates

**Bounded local Lean contexts are accepted: all 39 public cells and the complete
680-test suite pass.** The validated dependency is Djex
`38435709bf4e70c4b53c541c462b0bbd35837bf2`. This completes the bounded integration
milestone within original priority 3; that priority remains open for richer
contextual evidence. Original priority 1's supported-fragment Haskell elaboration
is complete. Priorities 2–4 retain their original requirements.

| Order | Delivery | Required acceptance |
| --- | --- | --- |
| 1 | Broaden supplied-fold acceptance after the native verification repair | Exact empty-user-root reuse now passes native Djinn append/length, lifecycle isolation/reset/recovery and the complete 686-test suite. Continue the remaining engine and supplied tree-fold/accumulator cases with exact provider inventories, full-signature behavior and termination-checked replay. Keep existing bounds and failure classifications. |
| 2 | Execute broader Church behavior independently | Run additional totals and all 19 explicit-default counterparts in both Haskell engines and all three Lean modes. Require controlled providers, actual False controls and independent exact full-signature replay. Record success, timeout and inconclusive outcomes per cell. These cells need not wait for native fold repair. |
| 3 | Admit one described global contextual provider | Extend the existing `Type 0` route with one fully described global provider while retaining the current non-overlap guard. Preserve complete source metadata, exact owned graph/renderer evidence and payload-sensitive replay; do not broaden instances or universes as part of this increment. |
| 4 | Preserve selected dictionary identity before relaxing overlap guards | Carry the selected introduction occurrence and ordered slot through lowering and reconstruction. Require a forced equal-predicate outer/inner fixture whose faithful scoped capture preserves distinct payload behavior in Haskell and Lean replay. Graph IDs or successful compilation alone are insufficient. Methods, superclass evidence and further provider schemes remain separate extensions. |

These are delivery steps, not replacement priority numbers: step 1 advances
priority 2, step 2 advances priority 4, and steps 3–4 advance priority 3.
Independent cells may proceed while heavy runtime work remains serialized.
Tree folds and accumulator programs depend on reliable native verification,
not on completing dictionary selection.

## Current evidence and its limits

The [contextual acceptance receipt](../../test-context/receipts/ordinary-context-streaming.json) records a **fresh complete 39/39
public matrix**: 18 exact displayed outputs with full-type replay, 72 finite
payload observations and 144 empty replay inventories, three actual False
controls, and 18 explicit universe/global-metadata refusals. Ordinary and named-`where` commands pass in Djinn, Exference and Both.
Each accepted variant retains its own source graph, renderer alternative and
engine. The directly invoked kernel, source, executable, commands and replay
inputs remained unchanged during the run. The 14 pure production-runner controls
also pass.

The strict build and 54 focused tests pass. The corrected unfiltered unit suite
passes **680/680 in 293.73 seconds**, with an owned process time of 293.86 seconds,
matching its complete unique inventory and preserving source/executable identity.
Ordinary contextual collection now verifies bounded groups before demanding a
complete pool; all four formerly timed-out cells pass in the fresh matrix.
The linked receipt preserves the earlier 35/39 composite, universe-fixture
correction, 678-test checkpoint and subsequent three stale source-assertion
failures. Those historical failures do not replace the fresh complete results.

The accepted route is a local `Type 0` subset. It refuses unrecorded universe
arguments, selected polytypes without complete metadata, and global/caller
premises without source packets. The current provider map is empty and rejects
typed globals. Equal active dictionaries remain unsupported. Rank-N constrained
forwarding is covered; richer nested forall/Given combinations outside the
accepted bounded forms remain open. This acceptance does not establish methods, superclass
search, global contextual providers, arbitrary universes or complete recursion.

The [native request comparison](../../test-recursive/receipts/native-request-traces.json) records a passing length query
(17.744 seconds) with exact kernel replay and a passing False control (14
falsifications, zero behavioral inconclusive checks). That False control passed
its behavioral gate despite two transport/type-verification timeouts; these
are different outcome counts. Append's positive run
failed with ten falsifications and two inconclusive checks; its separate False
control also failed with eleven falsifications and two inconclusive checks.
All four traces retain their owning process and report zero dropped events.
Writes, queue operations and parsing take milliseconds, but the longer response
waits do not identify a transport defect. Candidate 4's negative-decision check
is associated with the first timeout only by sequential inference: trace v1
records no request roles or payload tags. Its replay records the actual launcher
command, not a resolved kernel-executable hash. This historical event-only trace
predates the request-correlated diagnosis below.

The newer [request-correlated diagnosis](2026-09-07-empty-environment-diagnosis.md)
passes its strict build, all 14 focused controls and the complete 686-test suite
(357.63 seconds). Its failed append baseline has complete payload capture. The
same exact candidate command times out after 5.008023501 seconds without `env`
and completes in 0.0223364 seconds with a materialized empty root; decoded
payloads differ only by `env: 2`. Source confirms repeated header/import
initialization. The matched append control passes in 24.85 seconds with exact
kernel replay, and its actual False control passes in 10.19 seconds. The latter
trace retains 128 requests and explicitly omits 187, so its diagnostic capture
remains incomplete. The [receipt](../../test-recursive/receipts/request-correlation.json)
preserves all boundaries. This diagnostic checkpoint is now followed by
[accepted production root reuse](2026-09-07-empty-environment-reuse.md): the
original append and length workloads pass, as do four lifecycle sessions with
11 queries, four exact replays and ten empty axiom inventories. The strict build
and complete 686-test suite pass in 335.32 seconds. Positive native traces are
complete with no timeout; each actual False control passes with 87 falsifications
while explicitly omitting 184 payload records at the unchanged row cap. The
[production receipt](../../test-recursive/receipts/empty-user-environment.json)
keeps those diagnostic omissions separate from behavioral acceptance.

Both partial Church oracle preflights pass: 20 Lean files with 491 exact
inventories (487 empty and four named observer/proof allowances), and 63 Haskell
controls. All 19 explicit defaults and 736 observations remain represented.
Supplied-default `head` passes live synthesis, exact GHC execution and False
controls in both Haskell engines. Most expanded live cells remain open;
oracle preflight and the earlier 350-signature inhabitation corpus do not
establish behavioral synthesis. The exact named axiom allowances remain in the corpus receipts.

Original priority 1 is complete within its supported fragment. The
[completion register](https://github.com/VladimirReshetnikov/Djex/blob/fcea4779508f10b608f0ad59293d7c7cca121b29/docs/reports/2026-09-07-synthesis-priorities-1-4.md) and [timeout-sample receipt](https://github.com/VladimirReshetnikov/Djex/blob/fcea4779508f10b608f0ad59293d7c7cca121b29/test-integration/receipts/elaboration-timeout-samples.json) record the
strict build and complete 101-test CLI suite: first/best/all repairs, exact GHC
replay and retention of the original failed candidate across a same-deadline
retry timeout. These remain regression gates, not a claim that every compiler
error is repairable.

## Other improvements, re-ranked

| Idea | Promotion criterion |
| --- | --- |
| Exact accepted-candidate provenance and reproducible replay | Retain the accepted 39-cell/680-test boundaries, non-forcing diagnostics and direct kernel pinning. Retain bounded request capture and its whole-record omission accounting. Keep the accepted empty-environment repair and lifecycle controls as regressions; defer a general tracing framework. |
| Routing-test maintenance | When touching a routing boundary, replace brittle source-text counts with executable routing or boundary controls where practical. Preserve coverage; this is incremental maintenance, not a separate cleanup milestone. |
| Tree folds and accumulator programs | Extend after native verification is reliable, independently of dictionary work. Select a missing program with exact supplied-provider inventory, full-signature behavior and termination checking. |
| Native Windows Length acquisition | Promote for a concrete Windows workflow. Require bounded acquisition, actual solver execution and independent replay; existing refusal behavior and Length tests do not implement the missing acquisition route. |
| Measured performance | Profile rejected contextual slots, native request waits, duplicate checking and retained memory separately. Preserve source ownership and original budget charges; do not increase defaults to hide failures. |
| Provider retrieval | Require a useful provider excluded by inventory selection and measured recall/latency. A larger inventory alone is not useful synthesis. |
| Broader architecture | Defer engine rewrites, general caching, shared subgoal graphs, equality saturation and arbitrary frontier expansion until a concrete missing program or measured bottleneck justifies them. |

## Accepted baselines and earlier execution recommendation

The decision table above supersedes the older fold-first order in this section.
Historical receipts retain their original source revisions and acceptance scope.

The earlier integration checkpoint pins published Djex
`922c55580eadec156ba9ef447b300f43e0953ed7`, after published Leant
`990b7f335bac92bc8b21b475b9c2f1d5340f10e4` established bounded behavioral
simplification. The Haskell ordinary-data matrix now passes all sixteen cells,
and both engines pass supplied-fold `map`, order-sensitive `append`, generalized
`length`, and the empty-input rejection control. Those Haskell fixes are accepted
baselines. Leant now also passes the complete ordinary-data matrix: **24 positive
cells**, three actual false controls, 24 independent replays of the exact
displayed source at its full type, and **48 empty axiom inventories**. The
[three-engine receipt](../../test-recursive/receipts/all-engines.json) records
180.78 seconds for the live phase, unchanged source/executable hashes, a 1,024
window, 100,000 choices/steps, and a 90-second command deadline. The earlier
case failures below are historical receipts.

The strict executable/test build and eighteen focused streaming tests pass.
The first complete run passed 645/647 tests in 297.72 seconds; its two stale
fixture expectations are corrected and both focused checks pass in 0.41 seconds.
Strict build v6 and the refreshed isolated renderer replay also pass. The
[full configured integration run](../../test-recursive/receipts/unit.json) now
passes **all 647 tests in 343.79 seconds**. The actual unfiltered inventory and
passing summary agree; source, test-executable, and fake-Z3 helper hashes remain
unchanged. This closes the aggregate integration gate while retaining separate
live case and isolated context-renderer receipts.

Shared lexical-Given graphs, independent source checkers, and Haskell rendering
are also accepted in this dependency. The live Given matrix covers five
Exference roles, three Djinn roles, and three leakage controls. Djinn's forced
constrained local/global applications and sibling-scope search control remain
outside that accepted matrix. No instance or superclass derivation is implied.
Canonical Djex now publishes the
[conditional-Given increment](https://github.com/VladimirReshetnikov/Djex/blob/90c882615ae2a3a296ad963f3f8cb786d4aa614f/docs/reports/2026-09-07-djinn-conditional-givens.md)
in `90c882615ae2a3a296ad963f3f8cb786d4aa614f`. It passes strict builds,
all 92 private tests including 26 conditional-kind/proof and eleven direct-
erasure controls, the sixteen-test Given target in 23.56 seconds, and ten
permanent production budget tests. Forced Djinn local/global use and sibling-
scope rejection are accepted. The
[aggregate receipt](https://github.com/VladimirReshetnikov/Djex/blob/90c882615ae2a3a296ad963f3f8cb786d4aa614f/test-integration/receipts/conditional-givens-checkpoint.json)
records 2,168 passing tests across twelve complementary complete suites,
including all 432 Length tests. Only three test files changed between the
initial run and complete corrected reruns; production source stayed identical.
This is not one unfiltered twelve-suite invocation. At that checkpoint, Leant
pins `922c5558` and does not yet include this increment. These Haskell results do
not establish production Lean context handling.

The new direct Lean context renderer passes a strict GHC build, all 21 focused
tests, and independent Lean 4.32.0 replay of seven exact rendered implementations.
Seven payload observations distinguish equal-predicate dictionary slots and
outer dictionaries under shadowing; two wrong-result controls also pass.
All sixteen candidate/proof axiom inventories are empty. The
[renderer receipt](../../test-context/receipts/renderer-replay.json) records
these results; the [replay runner](../../test-context/run_replay.py) retains
source snapshots and hashes. This is isolated renderer acceptance; at that
checkpoint, ordinary `:synth` did not prepare its exact metadata or use this
route. The first replay exposed implicit
dictionary introduction around compound applications; the corrected renderer
makes the compound application explicit before replay.

Lean request reliability precedes expansion of the fold matrix.
The fresh [native-fold run](../../test-recursive/receipts/native-folds-incomplete.json)
accepts map, but append exhausts its raw window and generalized length reaches
the command deadline. Both correct terms already occur in the debug stream
and pass [independent witness replay](../../test-recursive/receipts/native-fold-witnesses.json)
at the original signatures and predicates; all eleven inventories, including
wrong-result controls, are empty. Their live failures are backend-request
failures during type verification. Diagnose request timing and recovery before
raising search defaults. The false control has eleven falsifications and one
inconclusive check, so it does not pass the strict acceptance gate.

A subsequent [focused diagnostic run](../../test-recursive/receipts/native-length-diagnostic.json)
preserves the request's original error instead of only its aggregate class.
Length's correct group-2 term times out during type verification after five
seconds, with 71 seconds still available to the command. The backend had
responded at startup and had not restarted before this candidate. Later
failures include exhausted command time and decision timeouts, which must
remain separate causes. Debug output now records the stage, exact candidate,
remaining command time, and original request error; ordinary output and all
limits are unchanged. The strict executable build passes. This diagnostic
run is incomplete acceptance, with unchanged source/executable hashes.

The [isolated direct-request diagnostic](../../test-recursive/receipts/native-request-timing.json)
then submits the exact length verification and both decision programs in fresh
Leant processes with an explicit 60-second request guard. All expected responses
arrive: type checking takes 0.736 seconds, positive decision 0.790 seconds, and
the expected rejection of the negative decision 0.782 seconds, excluding startup.
Sources and executable remain unchanged. This does not reproduce the preceding
synthesis workload or constitute five-second live acceptance. It makes the
difference between isolated requests and requests during synthesis the next
diagnostic target; an inherently expensive standalone term is not established.

The subsequent [five-second control](../../test-recursive/receipts/native-preparation-diagnostic.json)
narrows that inference: a fresh session with no synthesis preparation or search
also times out on the identical type-verification program after 5.028 seconds.
Its startup probe separately takes 91 seconds. All thirteen shared source/input
hashes and the exact program hash match the earlier fast direct-request run.
The prepared comparison cell never reaches its required intentional preflight
type error, so it does not establish an effect of serializer preparation.
Synthesis workload is therefore not necessary for this failure. Investigate
startup and request-time variability, including the process/IO boundary, before
attributing the problem to search or changing production limits; complete
ambient-environment equality was not recorded by these diagnostics.

Canonical Djex's published correction also suppresses source-level negative
evidence when retained qualifications or separately supplied contexts can
expose class methods omitted by search. Positive checking and unconstrained
refutations remain available. Root/nested method regressions and the affected
suites pass. This correction does not implement method synthesis, and Leant's
`922c5558` dependency does not yet contain it. Carry this correctness fix into
the next dependency integration.

The delivery order after these gates is:

| Order | Next deliverable | Acceptance boundary |
| --- | --- | --- |
| 1 | Complete supplied-fold composition in Lean | Resolve the observed verification-request failures; independently check generic provider termination, full candidate types, behavior, and axioms; then expand list/tree folds and accumulator programs. Haskell map/append/generalized length are already accepted. |
| 2 | Complete lexical-Given production synthesis | Integrate the validated canonical Djinn Given increment and negative-evidence correction with Lean source metadata/preparation/routing. Extend forced nested uses and actual duplicate-slot association, then methods, partial constrained instantiation, conditional instances, superclasses, and contextual certificate association. The isolated renderer and Haskell acceptance do not establish this production route. |
| 3 | Broaden Church behavior alongside these deliveries | Execute the prepared extended total and all-nineteen supplied-default fixtures, with controlled provider inventories, oracle preflight, fresh processes, false controls, and exact full-signature replay. Preparation alone is not accepted behavior. |

Production Lean context handling needs versioned source metadata preserving
binder visibility, lexical identity, and exact `Prop`/`Type u`/`Sort u` domains.
An initial `Type 0` subset must reject unsupported domains explicitly. Prepare
separate class and nominal authority together with the actual query/providers;
propagate projections from that root through the checked graph, using its
actual openings and substitutions. Selected polytypes must retain their own
source metadata. Preserve rank-N callback structure, but initially reject
impredicative selections until their resulting Lean universes can be checked
from exact metadata: `Type 0` binder domains do not imply that the whole
polymorphic type inhabits `Type 0`. Apply the precise Given identity explicitly.
Missing metadata or graph authority must reject this route rather than erase contexts or let
instance search choose a replacement dictionary.

Measure performance within these gates. The Exference supplied-fold rejection
fixture takes about 147 seconds at 100,000 steps; record this exhaustion cost
alongside first-success latency. Separate startup, search, source checking,
rendering, kernel work, and peak memory before changing defaults. The earlier
interpreted/default-deferral context failures and native/immediate-pruning
successes changed two variables and do not establish a controlled speedup.

Source inspection found two concrete integration policies to correct. Named
queries previously withheld unused-binder candidates after finding any typed
strict candidate, even if every such candidate later failed the assertion.
They now choose the permissive Exference policy inside the existing bounded
lanes. Both's streaming schedule also previously used the requested success
count and verification quota as raw-group turn lengths: `shown 1` and
`verify 1024` gave Exference the first 1,024 groups. The corrected streaming
schedule alternates observed slots from Djinn and Exference, including misses
and duplicates, while retaining source caps and each candidate's own authority.
It does not add wall-clock preemption inside one engine step.

The 24-case replay now accepts those policy corrections within the recorded
bounds, and the full 647-test integration suite now passes. The previous
619/620 full run plus unchanged focused retry remains incomplete aggregate
evidence. The 350-signature-per-engine corpus establishes type inhabitation
at its recorded boundary; expanded
behavioral coverage remains a separate requirement. At that historical
checkpoint none of priorities 1–4 was complete; current priority-1 acceptance
is recorded above, while priorities 2–4 remain open.

## Historical integration receipts

The [647-test run before fixture refresh](../../test-recursive/receipts/unit-before-fixture-refresh.json)
passed 645 tests in 297.72 seconds. The old layered-provider case passed in
75.76 seconds. The two failures required a legacy fallback for a wildcard whose
typed graph is now accepted and a fixed first spelling of a Nat-case result.
The refreshed tests require the typed authority and retain the intended Nat
case under the original 1,024-step bound and default-12 frontier; the wildcard
fixture retains its 128-step bound. Both focused tests pass in 0.41 seconds.
The subsequent full 647-test pass is recorded separately; budgets are unchanged.

At the same Djex `922c5558` dependency, the
[earlier policy baseline](../../test-recursive/receipts/policy-baseline-incomplete.json)
(`all-engines-v2`) took 986.39 seconds and recorded twenty of twenty-four live
positives plus three false controls. Exference missed `tailOr` within 100,000
steps and timed out on alias and tuple fields; Both timed out on tuple fields.
Its parser aborted before independent kernel replay. The separate
[live classification](../../test-recursive/receipts/policy-baseline-live-classification.json)
retains that successful subset without claiming unperformed replays. The
180.78-second accepted run above follows both policy corrections; these whole-run
times are not an isolated benchmark of either correction.

Leant `aab110e99e3c3d96549a05d3975b26bea93dc6ef` pins Djex
`6890bb5a8a56902c2baf137581e23c25a376fad0`. Integration of the Haskell
elaboration checkpoint is accepted at the receipt boundaries below. Canonical
Djex's subsequent live first/best regression now passes in expression and
definition modes, with exact displayed-source GHC replay. All 100 Djex CLI tests
passed in 142.44 seconds, retaining the all-selection and false controls.
This closes that selection fixture; it does not enlarge this pinned Lean
integration receipt or prove ranking among multiple successful repairs.

The earlier working integration pinned Djex
`3ce26cfd966ea4da2300028880c71ddaae50596d`. Djinn passed all eight ordinary
recursive-data behavioral queries and independent Lean replay, with sixteen
empty axiom inventories and one actually falsified control. The
[`test-recursive` runner](../../test-recursive/README.md) covers `null`,
`headOr`, `tailOr`, shallow tree inspection, aliases, a unary tuple field,
an `unconsOr` pair, and two independently typed inputs. Library and named
provider discovery are disabled; partial cases use explicit defaults.

The [successful Djinn receipt](../../test-recursive/receipts/djinn-cases.json)
is retained from `dist-newstyle/recursive-acceptance/djinn-v1/results.json`. It records a
1,024-candidate/verification window, 100,000 choices/steps, interleaving,
a 90-second command deadline, exact displayed terms, and unchanged source
and executable hashes. These are finite observations, not universal laws.

The [mixed-engine receipt](../../test-recursive/receipts/other-engines-incomplete.json)
at the same source revision failed; its original location is
`dist-newstyle/recursive-acceptance/other-engines-v1/results.json`.
Exference did not find `tailOr` within 100,000 steps and timed out on the
tuple-payload case. Both also timed out on that payload despite the successful
Djinn-only result. The failed run performed no independent kernel replays.
That experiment motivated optional recursive input splitting and finite payload
inspection. It also exposed an unused-binder
graph projection mismatch and the narrower graph boundary that accepts only
zero/step recursive cases returning the scrutinee's type. Djex `922c5558`
subsequently closed these Haskell gaps with declaration-backed complete-case
evidence, including finite tuple fields, exact association, exhaustiveness,
and lexical scope. The accepted three-engine run above closes their live Lean
case-stage acceptance; it does not retroactively alter this failed receipt.

The strict Leant build passed at the corrected dependency revision. The new
configured boundary run enumerated 620 tests and passed 619, correcting the
earlier missing fake-Z3 setup and retaining `3ce26cfd`'s positive-construction
bound fix. One existing staged polymorphic-search test exceeded its 30-second
limit; an unchanged focused retry passed. The separate
[full-run](../../test-behavioral/receipts/unit-incomplete.json) and
[retry](../../test-behavioral/receipts/unit-focused-retry.json) receipts do not
constitute an unfiltered 620-test pass. They remain distinct from the current
successful 647-test aggregate and the accepted cross-engine case matrix.

The initial positive GHC repair fixture exercises a graph-rendered impredicative
let. A subsequent public Exference query now demonstrates live repair under
`all` selection, exact display and independent GHC replay, and rejection of the
same repaired expression by a false predicate; see the implementation checklist.
The inspected live `reverse` failure had no source graph and therefore could
not authorize an annotation retry. Keep those two failure classes separate.

## Earlier delivery evidence and schedule

The earlier accepted elaboration integration advanced the dependency to
`6890bb5a8a56902c2baf137581e23c25a376fad0`, including the Haskell elaboration
renderer, behavioral retry, and Exference implicit local graph evidence.
The GHC 9.12.4 `-Werror` build passed for `exe:leant` and
`test:leant-synth-tests`. All 615 Leant boundary tests passed in 256.23 seconds.
The executable and source hashes remained unchanged during that test run.
The [unit receipt](../../test-church/receipts/unit-elaboration-integration.json)
records source and executable hashes. The strict build log is
`dist-newstyle/priority-elaboration-integration-build.log`.
The [live behavioral receipt](../../test-church/receipts/behavior-elaboration-integration.json)
passed all 18 cases: the existing six operations under Djinn, Exference, and
Both, with an additional `where False` rejection control per engine mode.
Independent Lean 4.32.0 replay accepted the exact displayed implementations,
their predicates, and the oracle controls; all 69 recorded axiom inventories
were empty. The executable remained unchanged throughout the run. Settings
were a 65,536 candidate/verification window, 500,000 Djinn choice points,
100,000 Exference steps, interleaving, and a 90-second command deadline.
This validates the existing six-operation corpus at this dependency revision;
it does not complete priority 4's broader corpus.
This is integration evidence for the dependency checkpoint; remaining priority
1 acceptance and priorities 2–4 below still apply.

The historical schedule below motivated the published Haskell improvements.
Its imperative wording records that earlier plan; the current execution table
above supersedes it, and the case failures it describes are resolved.

1. **Close Exference case parity and full Leant integration.** Retain the eight
   accepted Djinn cases; fix Exference's supplied-list default and unary tuple
   field, with complete graphs and actual Haskell execution. Require all eight
   cases in each engine mode, independent Lean replay, false controls, and the
   full boundary suite with its fake-Z3 helper configured. Preserve the existing
   positive-only constructor bounds. Check Both explicitly: a slow engine has
   already delayed an otherwise accepted Djinn result beyond the deadline.
2. **Deliver priority 2's supplied folds/recursors.** Use generic recursion
   structure to target operations such as `map`, `append`, and `length`, with
   checked source evidence and termination guarantees. Add behavioral corpus
   cases alongside this work.
3. **Implement priority 3's contextual evidence.** Start with forwarding and
   dictionary-independent bodies under lexical givens, then methods,
   conditional providers, and superclasses. Retain identities and scoped
   obligations throughout Djinn's provider projection and graph checking.
4. **Close priority 4's full behavioral corpus.** Finish naturals,
   options/eithers, folds, conversions, and all 19 supplied-default cases.
   Begin this coverage during earlier deliveries; preserve explicit defaults
   or inhabitance assumptions and independent false controls.

At that historical checkpoint none of the four priorities was complete.
The current priority-1 completion is recorded above. Moving the smaller
simplification delivery earlier changed scheduling, not the required
contextual capability.
The accepted first/best CLI fixture and bounded simplification remain regression
gates for later shared integration changes. Simplification now passes its 16
method controls, 15 live queries, and six independent candidate replays, with
false and inconclusive outcomes preserved. See the
[acceptance report](2026-09-07-bounded-behavioral-simplification.md) for exact
proof axioms and the separate boundary-suite timing failure. These and the
100-test CLI results are new runs; the older Church and recursive-case counts
remain inspected prior receipts. The dependency's linked execution report reflects its
pinned checkpoint; this companion records the newer canonical-worktree triage.

## Why these boundaries matter in Leant

[`ExactFamilyPlan`](../../src/Leant/Synth/Engine.hs) now documents Djinn's
bounded positive recursive construction and checked one-layer input cases.
The same module's `djinnRecursiveProjection` uses `EraseProviderContexts`.
Context erasure remains a boundary to address explicitly; successful ordinary
input cases do not establish contextual Djinn synthesis.

[`Leant.Synth.Behavioral`](../../src/Leant/Synth/Behavioral.hs) now has a working
implementation of bounded `simp` after both `decide` attempts. Its
[acceptance runner](../../test-behavioral/README.md) passed the complete live
proof-fallback matrix and independent kernel replay. A failed tactic must never be converted
into a false verdict or a proof. Successful simplification proofs can use
`propext` and `Quot.sound`; their actual inventories must be recorded separately
from the candidate's inventory and the existing axiom-free finite corpus.

Native Windows Length support remains a separate platform milestone:
[`Acquire.hs`](../../src/Leant/Synth/Length/File/Acquire.hs) deliberately returns
`LengthFilePlatformUnsupported`. Its acceptance needs acquisition, configured
solver execution, and independent replay together.

| Further improvement | Current disposition and promotion criterion |
| --- | --- |
| Both progress and cancellation | Retain raw-slot alternation and the now-passing tuple/default cases as regressions. Broader preemption needs a measured case where one engine step still blocks a reachable result or violates cancellation latency. |
| Search/checker performance | Instrument within current deliveries. Measure startup, first acceptance, search, checking, replay, exhaustion, and memory; retain the 147-second Exference rejection fixture. Change defaults only after a controlled comparison. |
| Failure diagnostics and capability receipts | Include now. Distinguish graph absence, compiler rejection, false assertions, inconclusive checking, and exhausted search; retain exact sources, settings, engine ownership, and per-cell replay outcomes on failure. |
| Semantic provider retrieval | Investigate when a realistic query misses a useful provider; measure recall as well as latency. |
| Shared subgoal graphs, caches, and cooperative internal search | Defer broad changes until a profile identifies repeated work or blocking as material, preserving source identity and budget charging. |
| Native tactic integration and isolated-worker production routing | Separate product/integration milestones. Require a concrete workflow; worker routing also needs environment snapshots, backend parity, transcript equality, cancellation, and memory evidence. |
| Dependent/indexed refinement, residual holes, and induction | Defer until ordinary-data and contextual milestones settle, then begin with a concrete missing program and its equality or termination obligations. |

The older future-directions reports remain design references; their claims
about missing typed graphs must be reconciled with the current implementation
before using them as a backlog.
