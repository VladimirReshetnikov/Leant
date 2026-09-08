# Further synthesis improvements after native Exference acceptance

The next release gate is reliable integration of the refined scheduler. After
that, alternate a missing Church construction with a bounded frontend or tree
delivery. Keep the original priorities 1–4 and the full behavioral matrix open.
This re-triage uses completed local runs; it does not claim a new runtime run or
a clean aggregate Leant integration. The [evidence receipt](../../test-church/receipts/post-integration-retriage.json)
indexes exact commands, captures, replay sources, failed attempts and hashes.

## What changes the priorities

| Evidence | Consequence |
| --- | --- |
| Exference synthesizes all 13 extended operations in Haskell at Djex `63a23f58`, and in Lean at Djex `3529c465`; both runs replay the exact full signatures and pass actual False controls. | Remove Exference `maybeEither` from the open construction list. Native Exference is beyond the historical first-six subset. These are separate revision-pinned runs. |
| Djex `63a23f58` passes 2,308 tests in 15 complete suites, all 350 signatures per Haskell engine, and the 13-operation Exference behavior run. | The canonical scheduler refinement has complete Haskell regression evidence. Signature inhabitation remains distinct from matching behavior. |
| Native integration at `3529c465` exposes a structural-provider regression despite passing the 13-operation batch, six method cases, nine method/cache controls and 39 local-context cells. | A behavioral submatrix cannot authorize a dependency update by itself. |
| Restricting eager scheduling to determined polymorphic local work at `63a23f58` restores the unchanged structural-provider test. The later full native suite passes 699/701; its two other failures pass unchanged in isolation. | Keep a clean complete 701-test run and affected native matrices as the release gate. Do not claim that isolated retries repair aggregate reliability. |
| The unchanged metadata preflight times out in that integration attempt, then passes with both worker settings: pool 1 in 36.57 seconds and default in 8.14 seconds. | No change to Lean's default worker setting is justified by this serial, order-sensitive pair. Separate timing investigation from search-rule changes. |

The refinement preserves ordinary monomorphic worklist ordering while retaining
focused introduction where the new goals or visible local bindings contain
quantifiers. Goals, local constraints and bindings must have no free flexible
type variables before they receive the eager ordering. It retains the earlier
forall-phase estimate. No reference program, operation-name dispatch, larger
candidate window, budget refund or deleted search alternative is involved.

Leant's committed dependency remains `4a4ed0fc`. Its working dependency was
`63a23f58` during the later tests. Publishing the canonical refinement and this
report does not promote that working pin to accepted Leant integration.

## Ordered delivery plan

| Order | Improvement | Acceptance and stopping rule |
| --- | --- | --- |
| 0 | Finish the current native integration gate | One clean complete 701-test run, affected context/method/recursor and nested-forall checks, whole-signature coverage, and fresh extended Exference acceptance at the exact final dependency. Correct the recursor runner's toolchain invocation. Record source/runtime identity and deadlines; retain failed attempts. If a timeout repeats, diagnose that stage rather than tune unrelated search weights. Advance the committed pin only after the gate passes. |
| 1 | Close Djinn's remaining extended construction | Reproduce `maybeEither` with the original public query and limits. Locate the missing or delayed derivation, implement the smallest general repair, then run all 13 extended cases and False controls. Verify Lean Djinn/Both separately; a Haskell result or Exference replay does not establish parity. |
| 2 | Finish bounded Haskell frontend usability | Preserve implicit root binder order and lexical scope, and make ordinary contextual expression/definition output independently usable. Cover explicit and implicit signatures through ordinary and named-function `where` queries. Replay exactly the displayed implementation at the requested signature. This is the next independent delivery after the first accepted engine repair. |
| 3 | Execute the prepared polymorphic tree accumulator fixture | Use supplied folds in both Haskell engines and Lean Djinn/Exference/Both. Require order-sensitive observations, exact provider inventories, full-type replay, termination evidence and False controls. Fixture preparation is not acceptance; introduce recursive-call search only if the fixture establishes a need. |
| 4 | Close all explicit-default behavioral cells | Start from the observed Exference `foldl1` and native-Int `at` misses, distinguishing search exhaustion from process timeout. Interleave bounded repairs with deliveries 2–3. Keep all 19 operations across all five language/engine combinations in the register; supplied witnesses and oracle preflights add no synthesis coverage. |
| 5 | Extend contextual source admission | Add Haskell derived method schemes and Lean mixed constructor/method inventories. The `ContextProduction.Dictionary.mk` refusal requires representation/admission work; raising provider caps cannot resolve it. Preserve precise unsupported outcomes. |
| 6 | Preserve selected dictionary occurrences, then extend evidence | Demonstrate distinct selected payloads for equal predicates through nested scopes, search, rendering and replay before relaxing overlap guards. Add superclass/conditional evidence and richer universe metadata in separate bounded fixtures. Existing coherent-Given inference does not settle those cases. |

Orders 1 and 4 preserve the full priority-4 obligation: **13 extended plus 19
explicit-default operations**, across Haskell Djinn/Exference and Lean
Djinn/Exference/Both. The current register combines revision-pinned subsets;
it is not one accepted 160-cell matrix. The user-approved explicit default or
inhabitance assumption remains the Lean contract for partial source operations.
Supported-fragment elaboration from original priority 1 stays accepted; broader
frontend/contextual work is still required by priority 3.

Do not make all of priority 4 a prerequisite for frontend and tree work. After
each accepted construction repair, run the next independent prepared fixture.
A failed bounded experiment should produce a specific diagnosis and a retained
query, rather than another round of unmeasured heuristic changes.

## Re-triage of the other ideas

| Idea | Disposition | Evidence that would promote it |
| --- | --- | --- |
| Validation reliability and stage timing | Immediate, narrow release work | Repeated failure of a specific query/session under unchanged settings. Separate cold startup, candidate search, checking, replay and process ownership; preserve the original deadlines. |
| Further heuristic tuning | Conditional on one remaining miss | An observed unavailable or delayed construction and a controlled improvement at existing limits, with both polymorphic and monomorphic regressions. The structural-provider regression makes broad eager scheduling a poor default. |
| Counterexample-guided search | Next performance experiment after construction coverage | Repeated costly rejection of reachable candidates. Cache exact candidate/environment/predicate observations; finite agreement must not be treated as universal equivalence. |
| Better duplicate keys or a shared subgoal DAG | Defer broad refactoring | A profile showing repeated work dominates a real workload, with source identity, scope and budget accounting preserved. |
| Provider retrieval | Conditional on realistic inventory scale | A useful provider omitted from a supported inventory, with recall and latency measured together. Source admission refusals are a different problem. |
| Cross-engine preemption and cancellation | Preserve existing fixes; extend only for a measured failure | A single engine step blocks a reachable result or violates a concrete cancellation target. Retain engine ownership and fair budget accounting. |
| Native Windows Length acquisition | Separate platform delivery | A required Windows workflow exercised through acquisition, configured solver execution and independent replay. Existing ranking tests do not establish this path. |
| More diagnostics and receipts | Maintain the current narrow infrastructure | A missing distinction prevents diagnosis. Keep unsupported, compiler rejection, false, inconclusive, exhausted and cancelled separate; do not build another general tracing framework now. |
| Native Lean tactic integration or an engine implemented in Lean | Separate product/architecture work | A concrete editor/proof-mode vertical slice with kernel replay, environment handling, search coverage and budget parity. A rewrite should not displace the current missing programs. |
| Isolated-worker production routing | Separate integration experiment | Environment snapshots, backend/transcript parity, cancellation and measured memory/latency improvements. Isolation alone is not a demonstrated speedup. |
| Dependent/indexed synthesis, residual holes, induction or invariant discovery | Defer broad expansion | A concrete missing indexed program and explicit equality, transport or termination obligations after ordinary-data/contextual deliveries settle. |

For each milestone, publish the accepted capability, its limits and the exact
dependency revision. Keep root READMEs current. Do not describe signature
inhabitation, finite behavioral observations or a successful isolated retry as
stronger evidence than it supplies.
