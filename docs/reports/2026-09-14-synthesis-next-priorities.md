# Further synthesis improvements: revised priorities

**Finish original integer indexing, then the original simultaneous two-universe query.**
The [native kind-adoption gate](2026-09-14-native-kind-adoption.md) now passes:
strict build, all 768 native tests and 84 affected public cells. Leant adopts the
accepted Exference kind/provider/pattern-field repairs and Djinn proof-prefix
repair together. Dictionary-qualified selection remains accepted. The four stale
scheduling guards are repaired, and the initial failed run is preserved. These
integration results do not close integer indexing or the simultaneous query.

This is the current execution plan for the original priorities 1–4. It supersedes the ordering in the [previous delivery plan](2026-09-13-synthesis-delivery-retriage.md). The practical rank-N/impredicative goal remains active. All original acceptance queries and limits remain binding.

## What the latest evidence changes

### Native adoption accepted

Leant's [native adoption](2026-09-14-native-kind-adoption.md) of Djex
`e237e8667190aff38faaa590ce5b12afbffac452` passes its strict build, all 768 native
tests, the focused 25-test integration group and all 84 affected public cells.
The gate also independently compiles the emitted serializer prelude and checks
source/runtime integrity. It replaces the previously committed dependency
`9a2d59d958a60ff3b6899697a60b6985a5cf73a3`.

The initial run passed 764 tests and failed four source-text guards tied to the
previous scheduling layout. Its [failed-run evidence](../../test-church/receipts/native-adoption-retriage-2026-09-14.json)
remains available. The test update removes redundant expression-layout matches
and points fallback checks at the shared constructive finalizer. Cursor/deadline
and classical-route checks remain; public scheduling independently checks
continuation and per-lane allowances. No production-source repair was required.

The [accepted archive](../../test-church/receipts/native-kind-adoption-2026-09-14.json)
records the actual completed public matrix: dictionary 18, lexical context 27,
accepted nominal/polymorphic Djinn cases 24, and scheduling 15. These scoped
regressions do not include the unresolved original two-universe query and add no
Church behavior-ledger acceptance.

| Finding | Consequence for the next work |
| --- | --- |
| The [fresh original-query diagnostics](2026-09-14-indexing-composition-diagnostics.md) falsify all 256 Haskell Exference candidates with no errors/timeouts. The clean inventory contains function-valued folds and 82 primitive-using definitions; the isolated step succeeds at candidate 5 and its larger-context counterpart at 219, both independently replayed in GHC. | Trace composition and ordering inside the original fold branch, including its usage history and pending goals. Availability of the carrier or primitive alone is no longer the discriminating question. The larger-context ordinal is not an internal trace of the original query. |
| The corrected shared-predicate diagnostic checks eight rejections with empty axiom inventories: 4.506 seconds inline and 1.551 seconds shared in one ordered run. | A valid isolated measurement now exists. Measure the real command path and setup cost before proposing production caching. |
| The original simultaneous two-universe query remains unaccepted in all nine ordinary/named/False cells on the adopted dependency. Exference proposes zero candidates with 18,974 queue prunes; Djinn and Both time out. | Preserve the original acceptance obligation and diagnose construction before verification; no actual-False acceptance follows from an empty candidate pool. |
| Qualified session names now survive replay, append and undo. The [identity release](2026-09-14-session-provider-identity.md) passed 768 native tests, six inventory sessions and nine False queries on its captured revision. | Preserve this regression coverage; do not reopen namespace discovery without a new failure. |
| Cooperative scheduling passes 15 public cells across Djinn, Exference and Both. Three additional Exference dictionary cells pass on the same final implementation. | Publish the scheduler as a bounded prerequisite repair. These 18 cells comprise 11 exact Lean replays and seven actual-False controls. A fresh full native suite was not run for this increment. |
| The original Exference integer query admits exactly the approved `intCase` primitive, but still yields zero accepted candidates and 23 falsified observations. | Stop treating provider admission as the remaining indexing diagnosis. Distinguish constructing the fold state from selecting/applying the primitive. A final all-engine acceptance rerun is still outstanding. |
| Matching whole-second callback admission removes the 270 last-subsecond no-time attempts seen in the earlier scheduling run. The final run has three actual request timeouts and no no-time attempts. | Keep deadline admission fixed. The three timeouts warrant candidate-specific inspection; they do not establish that every miss is a verifier bottleneck. |
| A small integer-case query passes by synthesizing structural cases. Its candidate does not call `intCase`. | This confirms elementary signed-integer behavior, not primitive use or Church indexing. Do not substitute it for the original query. |
| The earlier shared-predicate experiment failed `Decidable` synthesis and contained `sorryAx`. | Retain that failed evidence. Its corrected successor is measured above; only the checked successor supports a timing comparison. Production caching remains deferred. |

The [scheduling archive](../../test-church/receipts/provider-scheduling-2026-09-14.json) retains these runs, including unsuccessful attempts. Diagnostic failures are not acceptance receipts.

## Delivery order and exit gates

The numbers below preserve the original commitments. Supporting repairs can be promoted when a discriminating test demonstrates that they block an earlier item.

| Priority | Status and next action | Acceptance required |
| --- | --- | --- |
| **1. Dictionary-qualified polymorphic selection** | Accepted; regression maintenance. The [native release](2026-09-14-dictionary-selection-acceptance.md) closes the demonstrated reconstruction and candidate-vocabulary failures. The separate [Djinn proof-prefix repair](2026-09-14-contextual-proof-cutoff-acceptance.md) closes the observed default Haskell timeout. | Retain the original dictionary and transfer examples. Repeat affected checks when integrating the newer dependency; do not restart passing investigations. |
| **2. Exference explicit Haskell kinds** | The original public corpus and [provider-kind/deconstructor integration follow-up](2026-09-14-provider-kind-integration.md) are accepted in Haskell. The [native adoption](2026-09-14-native-kind-adoption.md) also passes, including the accepted Djinn prefix repair. Retain these gates during later engine changes. | An explicitly kinded query must retain the caller-supplied higher kind of a vacuous provider binder and its selected argument/certificate. Exercise independently reused providers, capture avoidance and later substitutions. Require independent checking plus affected native regressions on the proposed pin. |
| **3. Original integer `at`** | Provider identity, cooperative scheduling and deadline admission are repaired. The function carrier and required primitive step are demonstrably synthesizable in focused comparisons. Next trace their composition and ordering in the original fold branch, preserving lexical identities, usage history and pending goals. | Source `Int`, supplied default, original binder order and all 168 observations, covering negative, zero, in-range and out-of-range indices. Both Haskell engines and all three native modes must synthesize matching implementations with independent exact replay and real False controls at the original limits. |
| **4. Two nominal universe selections in one result** | Still open. Diagnose the original simultaneous `GenericBox.{0} Nat` / `GenericBox.{1} (ULift.{1} Nat)` query, with distinguishable payloads 37 and 53. Locate the first lost selection, rejected application, missing product construction or pruning step. | Djinn, Exference and Both; original window 60, verify 12, steps 4,096, queue 1,024, budget off, Djinn depth-first, timeout 20, library/providers/classical off. Require the exact original result, independent replay and actual-False controls. Single, chained and generic-payload comparisons do not close this query. |
| **5. Lean Djinn `length`** | Next bounded investigation after commitments 2–4. Compare the accepted Exference witness with Djinn's construction rules and pruning. | Find the first absent, rejected or unaffordable step before changing search. Require the original public behavior, exact Lean replay and False control. Earlier unsuccessful direct/wrapped experiments remain failed hypotheses. |
| **6. Higher-universe classes and selected global providers** | Required practical extension, after the concrete misses above unless a minimal example proves it is their prerequisite. Begin with one class/provider case and then two distinguishable universe selections. | Preserve declaration-local universe ownership, argument/result sorts and dictionary identity. Treat Prop/Sort formation and additional level operations as separately checked extensions. |
| **7. Reductions and extrema** | Retain, but trace one representative before implementation. The family size does not justify one patch per operation. | A general construction repair must earn one discriminating behavior acceptance before expansion. Do not repeat carrier-only, descending-head or use-all-inputs experiments without a new causal hypothesis. |

### Next bounded experiments

1. **Trace original indexing composition.** The fresh Haskell run rejects all 256 observed candidates, while carrier and step diagnostics pass separately. Trace the original fold branch and identify the first delayed or rejected necessary application before changing search penalties or pruning.
2. **Preserve the now-passing transport regressions.** The adapter previously discarded validated provider kinds, and pattern matching omitted kind ownership for nested field binders. The follow-up passes single/repeated provider selections with retained certificates, single/multiple constructor patterns, alpha-renamed field queries and eight new exact GHC replays. Its full 1,664-test gate and unchanged 11-case public Exference matrix pass. Broaden transport work only when another discriminating case demonstrates a gap.
3. **Preserve the original indexing gate.** Keep source `Int`, the supplied default, binder order, all 168 observations and original limits. The step queries and all-True inventory are diagnostics, not substitutes. Compare the original branch with the isolated and larger-context steps, accounting for their different partial-term usage histories.
4. **Measure the actual verification path before caching.** The corrected predicate experiment passes kernel and empty-axiom checks, with a promising isolated timing difference. A production proposal still needs end-to-end measurements that charge setup and preserve query scope, environment identity, observations and the shared deadline.

Use one heavy build/runtime owner. Scheduling is cooperative at checked candidate-group boundaries; it is not preemptive CPU fairness. One expensive next-candidate computation can still consume the remaining deadline. Promote a further scheduler change only when a trace demonstrates a distinct remaining starvation case.

## Other ideas: promote, retain or defer

| Idea | Revised disposition and trigger |
| --- | --- |
| **Tests of scheduling behavior and ownership** | The four demonstrated stale source-layout guards are repaired and the native/public gates pass. Retain continuation, cursor/deadline accounting and classical/fallback coverage. Broader test-framework work remains deferred until another concrete maintenance failure warrants it. |
| **Type/kind/evidence transport consistency** | The demonstrated provider and pattern-field losses now have an accepted focused repair. Preserve its alpha-renaming, repeated-use, substitution and independent-checker regressions during native adoption. Promote another transport change only from a discriminating failure. |
| **Small differential and metamorphic regressions** | Promote on changed paths: rename binders, reuse a provider in sibling branches, or add an irrelevant declaration to a comfortably bounded fixture. Compare acceptance and exact replay, not identical ordering. Defer broad fuzzing. |
| **Actionable failure diagnostics** | Promote within active investigations. Distinguish unsupported source, bounded search exhaustion, missing selection/evidence, reconstruction failure, behavioral mismatch, verifier timeout and no remaining callback allowance. Inspect the three actual indexing timeouts. Defer a general tracing framework or dashboard. |
| **Finite-prefix and budget accounting** | Required regression coverage for search changes. Retain cursor position, original per-lane counts and the command deadline across yields; exercise empty provider discovery and complete allowance exhaustion. Do not infer completeness from more candidate output. |
| **Predicate reuse / caching** | The corrected isolated measurement passes; defer production implementation until the actual command path is measured. No end-to-end synthesis speedup is established. Any later cache must preserve exact query scope, selected types, dictionary identity, backend generation, checked predicate/decidability evidence and observations. |
| **Candidate deduplication, counterexample-guided refinement, extra verifier workers** | Defer. Overlapping worlds can produce repeated candidates, but safe cross-world rejection reuse and a demonstrated end-to-end benefit are prerequisites. Never reuse an inconclusive timeout as a rejection. |
| **Memoization or a shared subgoal graph** | Defer implementation. First attribute cost to repeated equivalent subproblems in an original failing query. Any equivalence key must preserve lexical scope, kinds, universe selections, provider/dictionary identity and remaining search obligations. Allocation or wall time alone does not establish duplicate work. |
| **Provider retrieval/ranking at scale** | Defer scaling. Current indexing evidence shows that the approved provider is admitted. Promote retrieval work only when a realistic inventory omits a supported useful declaration or measured selection cost dominates; measure recall together with latency. |
| **Combined-engine cancellation, more workers or runtime tuning** | Retain existing cancellation and budget controls. Promote another change only from an observed blocked cancellation or attributable CPU/GC/backend bottleneck. A Both success never substitutes for individual-engine acceptance. |
| **Conditional, derived and superclass evidence; distinct dictionaries with equal predicates** | Retain as practical source obligations. Promote a minimal case when it blocks a committed source milestone. Local dictionary acceptance does not establish global or derived-instance search. |
| **Coverage-led baseline selection** | Use one representative of the next family, then expand after success or a shared causal diagnosis. Cells without indexed evidence are unknown outcomes, not confirmed defects. Update the ledger only from qualifying receipts. |
| **Harness capability expectations** | Maintain with the implementation boundary. Retired refusals must point to positive coverage; preserve engine-specific refusals. The obsolete dictionary harness is retained as historical evidence, not a current source defect. |
| **Supplied-fold trees** | Retain as a transfer test for a general construction repair. A supplied fold or independently replayed reference witness is not live synthesis acceptance. |
| **Search heuristics / reduction templates** | Keep failed variants retired. Prefer a trace-supported construction repair to operation-specific templates. |
| **Recursive/dependent redesign or a Lean-native search engine** | Defer until a required public example demonstrates a missing representation or rule that cannot be handled locally. Current misses alone do not justify replacing the architecture. |
| **Editor/platform work** | Later product work. Promote an observed usability blocker of a required query, not a speculative integration project. |
| **Documentation and repeated full matrices** | Maintenance. Root READMEs now summarize capabilities and link to this plan and detailed reports. Preserve historical evidence; do not expand the opening release log again. Run affected checks once per stable implementation, broadening when failures or new concerns justify it. |

## Evidence boundaries and stopping rules

The dictionary release retains 98 focused tests, 766 native tests and 69 public cells: 46 exact replays, 17 actual-False controls and six higher-class-universe refusals. The later identity release has its own 768-test gate. The scheduling release has its own strict executable build and 18 public cells. These are separate captured revisions; their suite counts must not be added or presented as a fresh combined release test.

The Haskell kind milestone retains 1,659 tests across seven affected suites and the complete public matrices for both engines: 44 exact GHC replays, 22 actual-False controls and two malformed-kind rejections. Native adoption is a separate gate. Earlier [nominal/polymorphic](2026-09-14-selected-polymorphic-types-acceptance.md), [contextual-universe](2026-09-14-contextual-universe-acceptance.md), [strict-implicit](2026-09-13-strict-implicit-source-acceptance.md), [product](2026-09-13-native-sort-products-acceptance.md) and [Church-composition](2026-09-13-maybe-either-head-use-acceptance.md) releases remain accepted within their documented scopes.

The [Church behavior ledger](../../test-church/behavior-ledger.md) remains **94 historical acceptances, 23 attempted cells without indexed acceptance and 43 cells without indexed evidence**, out of 160. The 66 cells without indexed acceptance comprise 15 reductions, one Lean Djinn `length`, five integer-`at` and 45 extrema cells. New indexing diagnostics do not change this pinned historical ledger or establish a current pass rate. Source-language obligations are additional.

Every new source gate must force the selection being tested. Use ordinary and named-function `where` queries as applicable, each individual engine and Both where supported, independent full-signature replay, and actual-False or malformed-source controls. A Both success does not establish either individual engine's success. Lean's universe formation rules remain authoritative; partial Church functions require supplied defaults or inhabitance assumptions.

For each implementation, establish the discriminating query, repair the first demonstrated loss, run affected checks, then push a stable milestone to both repositories with current README status. A bounded miss is inconclusive, not proof of non-inhabitation. Stop an unsuccessful hypothesis when its discriminating experiment fails; require new evidence before repeating it with a larger budget.

The later [provider-kind integration gate](2026-09-14-provider-kind-integration.md) has its own final 1,664-test snapshot, eight new exact integration replays and unchanged 11-case public Exference corpus. Its Haskell transport repairs are accepted. The initial native attempt failed four source-text guards and remains archived. After their focused repair, native adoption passes all 768 tests and the 84-cell public matrix. These scoped integration results do not revise historical Church acceptance counts.
