# Synthesis re-triage: bounded contexts, reliable checking, and behavior

This report, updated on 2026-09-08, preserves the active goal to implement priorities 1–4
from the [original roadmap](../../lib/Djex/docs/reports/2026-09-06-synthesis-next-priorities.md).
The [completion register](https://github.com/VladimirReshetnikov/Djex/blob/fcea4779508f10b608f0ad59293d7c7cca121b29/docs/reports/2026-09-07-synthesis-priorities-1-4.md)
retains the full scope. The current canonical
[Djex re-triage](https://github.com/VladimirReshetnikov/Djex/blob/main/docs/reports/2026-09-07-synthesis-retriage.md)
also records the canonical evidence and remaining implementation gates.

## Current decision and next delivery gates

The accepted [function-carrier repair](2026-09-08-function-carrier-search.md)
changes the order below. Canonical Haskell Exference now synthesizes the supplied
tree accumulator at its original bounds, retaining all 13 extended operations,
350 signatures per Haskell engine and 2,309 tests across the documented complete
suite runs. The semantic auxiliary-provider filter and replay factoring are
also delivered. These leave the implementation queue and remain regressions.

The [terminal native integration report](2026-09-08-native-carrier-integration.md)
records **701/701 unit tests, 6/6 method cells, 9/9 method-control sessions and
39/39 local-context cells passing** at working Djex `bfc3692e`. The recurring
layered-provider case passes at its unchanged deadline. Native List recursors
pass **9/12 cells after a deadline audit**: Exference append and the Exference/Both
False controls time out. The fixture now rejects timed-out False prefixes, as
the tree fixture already did; original results are preserved alongside the
correction. Both mode accepts append. The run stopped at this gate, so extended
behavior, nested foralls and the two native signature corpora were not run.
Leant still commits `4a4ed0fc`; integration remains incomplete.

The [verification diagnostic receipt](https://github.com/VladimirReshetnikov/Leant/blob/main/test-recursive/receipts/verification-retriage.json)
and [archive](https://github.com/VladimirReshetnikov/Leant/blob/main/test-recursive/receipts/verification-retriage.zip)
now justify one focused attempt to reduce verification requests. The events-only
append rerun still reaches the original 90-second deadline: zero passes, 385
falsifications and zero inconclusive observations. Its retained tail contains
780 completed requests totaling 61.47 seconds, including 61.18 seconds waiting
for responses. The ring dropped 8,047 events. These unlabelled retained-tail
sums are neither whole-query attribution nor kernel CPU measurements, and do
not establish a speedup. The payload-capture attempt instead hit its 180-second
outer guard and retained only a startup snapshot; it supplies no complete phase
breakdown.

The combined type/positive/negative-decision prototype passes its strict build
and focused tag-decoder test, but **fails all three live smoke queries** at the
Lean command boundary. Its metaprogramming wrapper requires imports unavailable
in the exact user environment; an independent no-import kernel probe reproduces
the missing `Command` namespace and `Lean.Elab.Command` requirement. The prototype
remains unaccepted and uncommitted as production code. A process exit of zero
and a diagnostic status of `captured` do not establish behavioral acceptance.

This is the current execution order. Original priorities 1–4 and their full
completion requirements are unchanged. Native integration gates dependency
promotion; independent frontend and Church work need not wait for its completion.

| Order | Delivery | Acceptance and decision boundary |
| --- | --- | --- |
| **1 — one bounded verification experiment, P2** | **Reduce redundant native verification requests.** Try a kernel-checked combined certificate in the exact user environment, then compare at the original append/False bounds. | Preserve the complete requested type, candidate ownership, positive/negative/inconclusive distinction, bounded simplification, error/sorry rejection, effective proof budgets and absolute command deadline. First pass live positive, negative, undecidable, ill-typed and protocol-failure controls without changing user imports or scope. Then require actual original-bound recursor improvement and affected regressions. If the corrected experiment fails these gates, retain its evidence and move to order 2; do not start another open-ended tracing or scheduler campaign. |
| **2 — independent frontend deliveries, P3** | **Finish implicit-root scope, one-shot contextual output and typed list rendering in separate increments.** | Ordinary and named-function `where` queries must preserve root binder order, nested quantifiers and selected contextual payloads in both Haskell engines. Compile the exact displayed implementation at the original signature. Compatibility erasure cannot validate a failed typed rendering. After these increments, investigate repeated best-output results under the separate identity gate below. |
| **3 — transfer the accepted construction, P2/P4** | **Run the native tree fixture and recheck Haskell Exference `foldl1` once at their original bounds.** The accepted Haskell Exference function-carrier repair is the concrete reason for these checks. | Native tree requires the supplied fold/constructor inventory, all 16 observations, full-type kernel replay, axiom/termination checks and completed False controls in Djinn, Exference and Both. `foldl1` needs actual search and all original observations, not just its checked witness. Haskell Djinn tree remains a separate known miss. Diagnose one failed derivation, then continue the next independent batch. |
| **4 — finish the entire behavioral matrix, P4** | **Work through explicit batches: remaining extended operations, selectors, nonempty reductions, extrema and native-Int indexing.** Trace Djinn `maybeEither` and native-Int `at` as concrete failed cells. | Retain all **13 extended plus all 19 supplied-default operations** across Haskell Djinn/Exference and Lean Djinn/Exference/Both. Each accepted cell requires live synthesis, exact full-type replay and its controls. Distinguish historical acceptance, current acceptance, bounded miss, timeout, replay failure and not run. No successful batch replaces the full matrix. |
| **5 — broader contextual evidence, P3** | **Extend source admission before selected-dictionary transport.** Derived Haskell method schemes and mixed Lean constructor/method inventories precede distinct dictionaries for equal predicates, superclass/conditional evidence and richer universes. | Preserve source identity, lexical scope and selected payload throughout search, rendering and replay. Keep overlap guards until distinct outer/inner dictionary behavior passes. Increasing provider caps cannot repair a missing source scheme. |

After a relevant native repair, rerun the corrected recursor gate and the affected
complete regressions, then finish extended behavior, nested foralls and both
350-signature native corpora at the final dependency before promoting the gitlink.
The successful Djinn/Both append cases and all previously accepted context/method
behavior remain regressions. No new native acceptance is recorded by this re-triage.

The [ordinary contextual REPL delivery](2026-09-08-ordinary-contextual-output.md)
now passes all 36 public queries and 330 tests across four complete affected
suites, with the documented test-only assertion correction and 256-step fixture.
It leaves the implementation queue. The earlier 20,000-step best timeouts remain
recorded; this delivery does not repair their performance. Implicit-root scope,
one-shot contextual commands and typed list rendering remain open.

Native integration remains a release gate for the dependency. Execute heavy
checks serially with frozen inputs, and rerun accepted aggregate suites when
relevant production inputs change.

The full supplied-default worklist is explicit so that successful small batches
cannot silently replace it:

- Selectors: `head`, `last`, `fromJust`, `fromLeft`, `fromRight`, `atKey`.
- Nonempty reductions: `foldl1`, `foldr1`, `reduce`.
- Extrema: `maximumBy`, `maximumOn`, `minimumBy`, `minimumOn`, `minMaxBy`,
  `minmaxElement`, `maximum`, `minimum`, `minMax`.
- Native-`Int` indexing: `at`, including negative indices.

Those are all 19 prepared operation identities. These groups are an execution
plan, not new behavioral acceptance. Use the agreed supplied default or
inhabitance assumption for partial Lean counterparts. Keep original partial
signatures classified separately from their total defaulted targets.

### Disposition of other ideas

| Idea | Re-triaged decision | Evidence that would promote it |
| --- | --- | --- |
| Fewer verification requests | **Promote to the bounded experiment above.** The current request tail establishes substantial checking latency; the first prototype fails its environment gate. | A checked certificate works in the exact user environment, preserves proof and deadline semantics, reduces work at original bounds, and passes controls and regressions. No speedup is assumed from the request count. |
| Exact duplicate suppression in contextual best output | **Promote to a bounded follow-up after frontend correctness.** The preserved 20,000-step baseline includes 7,475 copies of the same compatibility expression and best-mode timeouts; the accepted 256-step presentation fixture does not close this performance gap. | First establish duplicate identity using typed evidence, selected dictionaries and source ownership. Equal printed expressions alone are insufficient. Preserve distinct derivations where observable, documented tie behavior and engine selection. Compare exact displayed outputs and independent compiler replay at the original failing settings. |
| Broader search estimates and heuristic tuning | **Defer.** Retain the scoped accepted change and its rejected broader variants. | A traced original-bound failure identifies a lost or delayed useful branch, and a general repair retains the accepted regressions. |
| General memoization and shared subgoal graphs | **Defer the refactor.** Repeated displayed text is not evidence of equivalent internal subproblems. The old allocation figure did not identify reusable work. | Repeated scope-equivalent work explains a material current cost; keys preserve source identity, dictionary selection and budget accounting. |
| Combined-engine streaming and cancellation | **Conditional.** Both already accepts append; do not change its established selection order to mask Exference's failure. | A trace identifies avoidable waiting or cancellation work, with ordering, ownership and deadlines preserved. |
| Counterexample-guided search and observation caching | **Defer behind request reduction.** Hundreds of falsifications do not establish reusable candidate evaluations or a sound pruning rule. | Repeated exact candidate/environment/predicate checks dominate after the smaller repair. Broader pruning needs a sound condition; finite agreement is not semantic equivalence. |
| Provider retrieval and relevance ranking | **Defer scaling; finish supported admission first.** | A realistic inventory demonstrably omits a useful supported provider, with recall and latency measured together. |
| More diagnostics and validation infrastructure | **Keep narrow.** Reuse existing traces and preserve their omissions. Payload capture failed to retain the command trace; do not count it as complete attribution. | Add a bounded observation only when it decides the current experiment. Keep deadline completion distinct from rejection counts and retain failed evidence. |
| Worker counts and RTS tuning | **Defer.** Response waits do not identify kernel CPU, transport overhead, GC or memory as their cause. | Controlled current measurements identify a specific bottleneck and demonstrate improvement with environment and cleanup parity. |
| General recursion, induction, dependent/indexed synthesis and invariant discovery | **Defer broad expansion.** Supplied folds already express the current tree witness. | A concrete required program needs additional termination or equality machinery. |
| A Lean-native engine rewrite, editor/tactic integration, native Windows Length acquisition | **Separate architecture, product and platform deliveries.** | A concrete requested workflow supplies its own runtime, replay and budget acceptance criteria. |

The remaining sections preserve historical diagnoses, counts and proposals at
their recorded revisions. They do not override the current decision above.

## What changed in this re-triage

The [focused introduction change](https://github.com/VladimirReshetnikov/Djex/blob/main/docs/reports/2026-09-08-focused-forall-search.md) follows the actual unfinished
`maybeEither` branch to the queue boundary. It remains at position 1,002 of
8,192 after the original prefix; it was delayed, not capacity-pruned.
Completing determined goal groups before interleaving siblings, together with
retaining the forall estimate until arrow parameters enter scope, finds a
matching program in the original 256-candidate window. Ordering alone failed;
the combined generic change passes the full extended corpus and regressions.
This supersedes the earlier Exference search-miss diagnosis below. The
parenthesized-forall worker correction remains a separate accepted repair.
Leant still pins `4a4ed0fc`; advancing that dependency requires native validation.

The [accepted integration follow-up](2026-09-08-global-contextual-providers.md) supersedes the earlier
working-prototype and incomplete-regression status below. The following
diagnoses and counts remain historical evidence at their recorded revisions.

The [canonical engine acceptance report](https://github.com/VladimirReshetnikov/Djex/blob/4a4ed0fc23f76d7b82b06496e03adfadbf374f84/docs/reports/2026-09-08-constraint-only-provider-inference.md) supersedes the
engine failure diagnosis below with unique coherent Given inference, scoped
Haskell rendering, and complete regression results. It retains ambiguity and
dictionary-ownership guards. The linked receipt also preserves failed direct
CLI diagnostics: explicit preflight success is not loaded-provider synthesis
acceptance. The earlier Leant fixture failures below remain historical results
against the older dependency; the follow-up above records the new native passes.

The [diagnostic receipt](https://github.com/VladimirReshetnikov/Djex/blob/12ec0a2002a4e15b48aae1bfbbbd887a1fd431af/test-church/receipts/synthesis-retriage-diagnostics.json) embeds selected process captures, the failed
method fixture, tested heuristic diffs and source hashes. It is a diagnostic
extraction from completed local runs, not a new acceptance matrix. Full raw
prefix artifacts remain in the hash-addressed local runs identified there.

**The class-method boundary is now specific.** In the forced fixture, `α`
occurs only in the provider's class constraint, so the `Nat` result cannot
determine it. Djinn reaches exact lexical-Given lookup with a fresh unresolved
type variable. Exference returns no checked group; the same inference gap is
a source-supported hypothesis, but its terminal path has not yet been isolated.
Adding a term argument of type `α` would avoid the failing case and would not
meet this delivery gate.

Start with a unique coherent substitution obtained from in-scope Givens. Match
only fresh provider variables, check all constraints together, and retain the
ordinary scope/occurs checks and graph witnesses. Do not mutate a goal's rigid
type variables or recover dictionary authority from a printed class name.
Multiple possible instantiations need bounded alternatives with their own
evidence; equal predicates need the selected dictionary occurrence. Those are
distinct extensions, so an ambiguity refusal may remain in the first milestone.

**The `maybeEither` prefix is now matched to the real frontend.** An empty user
workspace still loads intrinsic list, unit and tuple constructors. A manually
empty environment produced a different order and failed the first diagnostic's
correspondence gate. The corrected loader-based capture reproduces the original
CLI samples at positions 63, 117 and 119. It observes 256 graph-backed, typed
candidates in 3,346 batches, with 31,165 queue prunings. Of those candidates,
199 have extra result-argument applications; 232 contain three forall
introductions and 24 contain four. The supplied checked reference has five.
These shapes do not prove which rule produced a candidate, that five
introductions are necessary, or that every equivalent solution is unreachable.
The public observer exposes no pending goals or actual search-rule history.

Counting forall bodies/bound variables in the complexity heuristic passed its
83 focused engine tests but still produced 256 false candidates. Combining that
change with an extra-arrow application penalty also produced 256 false
candidates. Both runs had zero behavioral errors/timeouts and passed their
separate False/oracle controls. Neither experiment was adopted; baseline source
was restored and rebuilt. A new ranking proposal now needs an observed branch
or queue diagnosis and a successful original behavioral query.

**`foldl1` has a valid reference construction, not synthesis acceptance.** Its
supplied continuation-carrier witness compiles at the original full signature
and passes all 36 original observations. That run performs no search. Inspect
the point where a flexible goal would need function structure, and establish
whether a general construction or scheduling rule is missing before changing
defaults. This witness does not prove every equivalent derivation needs that
same rule.

## Current evidence and its limits

The evidence below records accepted milestones and historical diagnostics.
The September 8 decision table above supersedes their earlier delivery order;
their recorded source revisions and acceptance limits remain unchanged.

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
premises without source packets. The published accepted provider map is empty
and rejects typed globals; the subsequent global-method acceptance above extends this older boundary.
Equal active dictionaries remain unsupported. Rank-N constrained
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

The [P4 behavioral coverage report](2026-09-07-priority4-behavioral-coverage.md)
records the union of separate accepted runs: **12/13 extended operations
in each Haskell engine and 2/4 Exference explicit-default operations**.
Both engines still lack `maybeEither`; Exference `foldl1` and `at`
remain unaccepted at the recorded bounds. Fresh native-Int length synthesis,
exact GHC replay and False controls pass in both Haskell engines; Exference's
repeat length run adds no unique coverage. Historical harness hashes and
the two earlier Djinn length fixture failures remain separate.

Lean Exference now accepts **6/6 of the selected first-six operations**
from two runs: five exact kernel replays in the original batch and native
length in an independent corrected-fixture follow-up. Both False controls
pass. The initial length inventory failure and missing replay remain in the
historical receipt; this is a composite, not a fresh six-cell rerun.
These are recorded subsets, not a complete new matrix. All 13 extended
operations and all 19 explicit-default counterparts remain required across
both Haskell engines and all three Lean modes.

Both partial oracle preflights pass: 20 Lean files with 491 exact inventories
(487 empty and four named observer/proof allowances), and 63 Haskell controls.
All 736 observations remain represented. Earlier supplied-default `head`
acceptance has its own two-engine receipts. Preflight and the 350-signature
inhabitation corpus do not substitute for the remaining behavioral cells.

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
| Verification trace and runner consistency | Completed for the global-method increment. Retain exact ordinary/where ownership, portable runners, explicit capture caps and negative controls. Defer broader tracing until another concrete acceptance gap requires it. |
| Routing-test maintenance | When touching a routing boundary, replace brittle source-text counts with executable routing or boundary controls where practical. Preserve coverage; this is incremental maintenance, not a separate cleanup milestone. |
| Constraint-only provider instantiation | Engine/API, bounded native integration and loaded Haskell explicit-forall behavioral use are accepted. Retain the 701-test native and 2,306-test canonical receipts at their distinct revisions. Implicit-root scoping and ordinary presentation are delivery 2; derived method schemes and mixed Lean inventories are delivery 4. |
| Tree folds and accumulator programs | Independent next recursion delivery; the polymorphic tree-accumulator fixture is prepared but unexecuted. Require exact supplied-provider inventory, order-sensitive full-signature behavior and termination checking. Native verification repair is already accepted. |
| Flexible-goal construction and branch diagnostics | Promoted to the first delivery: trace actual rule admission, substitutions and queue decisions for a missing derivation. Preserve budgets and distinguish an unavailable construction from an admitted but delayed branch. Public graph histograms alone do not locate the cause. |
| Further heuristic tuning | Demoted: three tested Exference changes leave `maybeEither` at 256 false candidates. The newest trace locates a priority drop while opening an injection, but a body-cost estimate still fails. Inspect the exact branch's queue fate and require a successful original query before adoption. |
| Counterexample-guided search | Conditional follow-up when repeated expensive rejection remains material after construction gaps close. Reuse only exact-candidate observations under the same environment/predicate; finite agreement cannot justify general equivalence or unsound pruning. |
| Native Windows Length acquisition | Promote for a concrete Windows workflow. Require bounded acquisition, actual solver execution and independent replay; existing refusal behavior and Length tests do not implement the missing acquisition route. |
| Measured performance | Profile rejected contextual slots, native request waits, duplicate checking and retained memory separately. Preserve source ownership and original budget charges; do not increase defaults to hide failures. |
| Provider retrieval | Require a useful provider excluded by inventory selection and measured recall/latency. The forced method fixture already supplies the provider, so retrieval cannot resolve that failure. A larger inventory alone is not useful synthesis. |
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
| Search/checker performance | First validate the canonical focused-introduction change in Lean. Further tuning needs a measured remaining miss or cost, distinguishing startup, first acceptance, checking, replay, exhaustion and memory. Retain the 147-second rejection fixture and unchanged defaults until a controlled comparison supports a change. |
| Failure diagnostics and capability receipts | Include now. Distinguish graph absence, compiler rejection, false assertions, inconclusive checking, and exhausted search; retain exact sources, settings, engine ownership, and per-cell replay outcomes on failure. |
| Semantic provider retrieval | Investigate when a realistic query misses a useful provider; measure recall as well as latency. |
| Shared subgoal graphs, caches, and cooperative internal search | Defer broad changes until a profile identifies repeated work or blocking as material, preserving source identity and budget charging. |
| Native tactic integration and isolated-worker production routing | Separate product/integration milestones. Require a concrete workflow; worker routing also needs environment snapshots, backend parity, transcript equality, cancellation, and memory evidence. |
| Dependent/indexed refinement, residual holes, and induction | Defer until ordinary-data and contextual milestones settle, then begin with a concrete missing program and its equality or termination obligations. |

The older future-directions reports remain design references; their claims
about missing typed graphs must be reconciled with the current implementation
before using them as a backlog.
