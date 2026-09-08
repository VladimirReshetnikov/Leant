# Further synthesis improvements: reproduced failures and bounded deliveries

The next work should target three concrete gaps: costly layered-provider search,
Lean's admission of generated auxiliary eliminators, and accumulator composition
through a supplied tree fold. Keep Haskell frontend usability as an independent
delivery. Broad scheduler tuning and new recursion architectures move down the
list. This changes the delivery order, not the original priorities 1–4 or their
acceptance requirements.

The [new evidence receipt](../../test-church/receipts/search-failures-retriage.json) retains the complete failed integration run,
timing probes, rejected experiment, tree queries, candidate graphs, compiler
checks and runtime hashes. The [earlier acceptance receipt](../../test-church/receipts/post-integration-retriage.json) preserves
the accepted Church subsets. This update accepts no new positive synthesis cell
and does not advance Leant's committed Djex dependency.

## Evidence that changes the order

| Observation | What it establishes | Consequence |
| --- | --- | --- |
| The latest full native unit run at working Djex `63a23f58` passes **700/701** in 688.55 suite seconds. The structural-provider case passes in 19.21 seconds; the sole failure is the named-binary stage of successive polymorphic providers, exceeding its existing 30-second deadline. | This repeats the layered-provider failure from the previous 699/701 run. Earlier isolated success does not establish aggregate reliability. | Stop repeating the full suite without a relevant change. Diagnose and repair this specific stage, then require the complete integration gate. |
| A diagnostic linked to the existing unit engine objects finds the named-binary result with Djinn in about 7 ms; Exference takes 12.85 seconds and allocates **12.55 GB cumulatively**, with about 19 MB maximum residency and 1.05 seconds of GC in that process. Both takes 10.31 seconds in a separate invocation. | Substantial work occurs in the pure Haskell engine path. Cumulative allocation is not resident memory; these serial observations do not establish a speedup or prove the full-suite timeout's cause. | Profile candidate construction and forcing in this fixture before changing Lean worker counts, heap settings or global search weights. |
| The pending-polymorphic-work scheduling experiment `b567d781` passes a focused structural test but fails the unchanged layered-provider test. Its Exference allocation is slightly higher despite a faster isolated wall time. | There is no demonstrated workload reduction or acceptance improvement. | The experiment was reverted by `50340b07`; its net source difference from published `3b075d6d` is empty. Do not reintroduce it based on isolated elapsed time. |
| The supplied tree accumulator produces **95 Djinn and 1,024 Exference source-checked candidates**, all independently compiled and executed at the original full signature; none satisfies the 16 observations. | This is now an executed bounded synthesis miss in both Haskell engines. It is not a proof of uninhabitation. | Promote a focused fold-carrier construction investigation. Preserve the original providers, budgets and counterexamples. |
| The corrected Lean tree oracle passes all eight controls with 17 empty axiom inventories. All three positive engine cells fail their provider-inventory gate because generated constructor `.elim` declarations appear. | Oracle validity and live synthesis acceptance are separate. No positive Lean accumulator is accepted. Exference and Both False controls pass separately; Djinn's False outcome fails the inventory gate. | Repair automatic provider admission before comparing Lean search performance or expanding its inventory. |

Earlier acceptance remains: canonical Djex `63a23f58` passes 2,308 tests in 15
complete suites, all 350 signatures per Haskell engine, and a fresh 13/13 extended
Haskell Exference behavior run. Native Lean Exference passes 13/13 extended
operations at the distinct `3529c465` dependency. These are revision-pinned
subsets, not a new complete cross-engine matrix. Leant still commits `4a4ed0fc`;
its working `63a23f58` dependency remains under integration.

## Next deliveries

| Order | Work | Concrete acceptance |
| --- | --- | --- |
| Release gate | **Fix the recurring layered-provider deadline.** Measure where Exference and combined search allocate and force work in the existing named-binary fixture. Inspect staged collection as well as the engine derivation; retain the requested candidate ordering and budgets. | The unchanged focused test passes reliably, followed by one clean complete 701-test run and the affected native context, method, recursor, nested-forall, whole-signature and extended behavioral matrices at the exact final dependency. Use the correct Elan-proxy/toolchain pairing for the existing recursor runner. Only then advance the committed pin. |
| 1 | **Exclude generated auxiliary recursors semantically in Lean provider discovery.** The shared ordinary/contextual generator currently filters name components but misses constructor `.elim` declarations. Lean 4.32 marks those declarations as auxiliary recursors; test using `Lean.isAuxRecursor env n`. | Real-kernel discovery excludes the generated helpers while retaining the supplied fold, both constructors and an ordinary user function named `elim`. Re-run the unchanged positive/False tree commands with the original allowlist and check both discovery modes. This is a proposed repair, not an implemented one. |
| 2 | **Make useful function-carrier fold compositions reachable.** Trace the tree accumulator's instantiation and scheduling through a carrier such as `s → s`. Exference already has a general overapplication rule, so first distinguish an absent choice from a delayed branch. | Synthesize a matching implementation at `forall a s. (s -> a -> s) -> s -> Tree a -> s`, with the corresponding full Lean type, using only the supplied fold and constructors. Require all 16 observations, exact graph/source replay, termination and False controls in Haskell Djinn/Exference and Lean Djinn/Exference/Both. No reference implementation enters the provider set. |
| 3 | **Finish bounded Haskell frontend usability.** Preserve written implicit-root binder order and scope, and make ordinary contextual expression/definition output independently usable. | Explicit and implicit root signatures work through ordinary queries and named-function `where` queries. The exact displayed implementation compiles at the original requested signature, including nested quantifiers and contextual parameters. This is an independent delivery; do not make all Church behavior a prerequisite. |
| 4 | **Complete the remaining Church constructions and explicit defaults.** Djinn `maybeEither` and the observed Exference `foldl1`/native-Int `at` misses remain concrete starting points. Interleave those repairs with orders 2–3. | Preserve the full **13 extended plus all 19 explicit-default operations**, across Haskell Djinn/Exference and Lean Djinn/Exference/Both. Each accepted cell needs actual synthesis and independent checking at the existing limits. Retain timeouts, exhausted pools and unexecuted cells distinctly. |
| 5 | **Extend contextual source admission, then evidence transport.** Add derived Haskell method schemes and mixed Lean constructor/method inventories. Follow with distinct selected dictionaries for equal predicates, superclass/conditional evidence and richer universes in separate increments. | Exact source identity and selected payload survive nested scopes, search, rendering and replay. A source-admission refusal cannot be fixed by raising provider caps. Keep overlap guards until selected-dictionary transport is demonstrated. |

Orders 1–4 can make bounded progress while the release gate remains open, but
their individual results must not be reported as complete native integration.
After one measured construction experiment, either accept the general repair
with its regressions or retain its failed trace and move to the next independent
delivery. A faster isolated time alone does not justify another scheduler
change or repeated full integration runs.

The user-approved supplied default or inhabitance assumption remains the Lean
contract for source operations such as `head` and `fromJust`. Original priority 1
is accepted within its supported elaboration fragment; broader frontend work
belongs to priority 3. Priorities 2–4 remain open. Finite behavioral agreement
does not establish semantic completeness of higher-rank inhabitation search.

## Tree diagnosis and reproduction

The [portable tree fixture](../../test-recursive/tree-accumulator/README.md) records the original provider inventory,
16 order-sensitive observations, eight independent oracle controls, six Lean
command files, full-type replay templates and a manifest. Its runner uses the
selected prebuilt Cabal library, resolves output paths before changing working
directories, and keeps compiler replay separate from synthesis. The new receipt
also preserves the earlier oracle failure and the two initial portability
failures; none contributes accepted coverage.

In the first Haskell Exference pool, all 1,245 visible fold applications use an
atomic carrier. Djinn reaches some function-carrier shapes but still has no
matching result. That observation directs the next trace; it does not prove that
every solution must use the reference's carrier or that Exference lacks the rule.
The observed shapes normalize skolem names and therefore do not preserve their
individual identity. Use the retained exact graphs for a scope-sensitive repair.

Lean's original `by decide` oracle failed to unfold the named observation
predicate. Explicitly unfolding it before `decide` repairs those proofs without
changing any public synthesis command or observation. The subsequent live run
still fails all positive cells at the original inventory boundary. Adding `.elim`
to a string blacklist could discard legitimate user providers; widening the
fixture's allowlist would change the experiment. Prefer the environment's
auxiliary-recursion metadata. A separate real-kernel diagnosis passes: both
generated helpers have the auxiliary tag, while the fold, constructors and an
ordinary user `elim` do not. This validates the proposed discrimination; the
production discovery filter is still unchanged.

## Other ideas, re-triaged

| Idea | Disposition | Evidence needed before implementation |
| --- | --- | --- |
| Broad heuristic tuning | **Demote.** Replace with a trace of one failed construction. | The intended derivation is delayed, and a general change improves the original query without hurting polymorphic or monomorphic regressions. |
| Memoization, duplicate keys or a shared subgoal DAG | **Profile next; defer the refactor.** High allocation makes investigation worthwhile, but does not identify duplicate work. | Cost attribution and repeated equivalent subproblems with scope, source identity and budget accounting preserved. |
| Counterexample-guided search and cached observations | **Conditional performance work after reachable constructions.** It cannot alone add a missing derivation. | Repeated costly rejection dominates a concrete workload. Cache by candidate, environment and predicate; finite observations are not universal equivalence. |
| Combined-engine early results and cancellation | **Narrow investigation within the release gate.** A fast Djinn result and costly combined collection justify inspecting forcing and staging. | A trace shows avoidable waiting or blocked cancellation, followed by a change that preserves selection order, engine ownership and accounting. |
| Provider retrieval and relevance ranking | **Defer scaling; fix inventory correctness now.** | Supported useful providers are omitted at realistic scale, with recall and latency measured together. Generated-helper admission and unsupported source fragments are separate defects. |
| Lean worker count, RTS heap tuning or isolated-worker routing | **Do not adopt as a search fix.** The metadata worker comparison was order-sensitive; the new expensive probe is pure Haskell. | A controlled workload shows startup, GC, memory or isolation is the limiting factor, including transcript/environment parity and cleanup. |
| More diagnostics and receipts | **Keep small and task-specific.** Fix terminal status reporting in failed diagnostic runners when reusing them. | A missing distinction blocks a concrete diagnosis. Do not build another tracing framework. The experiment's stale top-level `running` status is overridden by its retained terminal failing process record. |
| Native Windows Length acquisition | **Separate platform delivery.** | Exercise acquisition, configured solver execution and independent replay on a required Windows workflow. Ranking tests alone do not cover it. |
| Native Lean tactic integration or an engine rewritten in Lean | **Separate product/architecture work.** | A concrete editor or proof-mode slice requires it and demonstrates kernel replay, environment handling and budget parity. Current Lean synthesis gaps do not by themselves require a rewrite. |
| General recursion, induction, indexed/dependent synthesis, residual holes and invariant discovery | **Defer broad expansion.** Supplied folds already suffice to express the tree witness. | A concrete program requires additional recursive calls, equality transport or termination machinery after the ordinary-data and contextual deliveries. |

Publish stable milestones to both repositories with the root READMEs current.
Report implemented capabilities, test outcomes and remaining limits separately.
This re-triage preserves failed evidence and changes priorities; it does not
declare the wider implementation goal complete.
