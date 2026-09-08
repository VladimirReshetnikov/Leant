# Further synthesis improvements: integration closure before expansion

**Later September 8 follow-up:** the [global-method integration](2026-09-08-global-contextual-providers.md)
now passes its complete bounded acceptance gates, including all 701 unit tests.
The [current roadmap](2026-09-07-synthesis-retriage.md) moves frontend gaps and
Church construction ahead of the integration work recorded below. This report
retains the earlier documentation checkpoint and its historical failures.

This September 8, 2026 re-triage preserves the original priorities 1–4 and
changes their execution order. The [current roadmap](2026-09-07-synthesis-retriage.md)
retains the full scope. This is a documentation checkpoint: the global-method
implementation and updated Djex gitlink remain uncommitted pending integration
acceptance. The published Leant dependency remains `a44f7057`; the working
prototype uses canonical Djex `4a4ed0fc`.

## Evidence that changes the priorities

The [extracted local results](../../test-context/receipts/global-method-integration-retriage.json)
record existing runs, their artifact hashes, selected exact candidates and
kernel replays, and a fresh read-only inspection of the cache trace. They are
not a new run or a substitute for publishing the implementation and its complete
reproducible fixtures. The production source hashes still match the successful
native method run; subsequent test maintenance changed a source-text assertion.

| Gate | Current evidence | Remaining obligation |
| --- | --- | --- |
| Constraint-only inference in Djex | Published `4a4ed0fc`: both engines, four public Haskell API cases, strict build and 2,304 tests in 15 complete suites | Loaded-provider admission/source schemes and implicit-root behavioral scoping remain frontend gaps. |
| Leant method preparation | Working prototype: strict build; all 13 focused tests pass, including six positives and seven metadata/ownership controls | Retain the complete source packet, exact provider name and lexical dictionary evidence during final integration. |
| Real Lean method discovery and synthesis | Six ordinary/where × Djinn/Exference/Both queries pass with actual cap-one discovery of `Ctx.C.out`; six exact full-type kernel replays and 24 payload observations pass | This closes the forced fixture's inference failure; it does not cover arbitrary methods, universes or overlapping dictionaries. |
| Actual False controls | Three engine-mode controls pass, with independent replay of the rejected candidate and literal False | Retain as regressions. |
| Complete Leant unit suite | 698/699 passed; the sole failure was an obsolete source-text assertion forbidding all contextual providers. The corrected test passes after a strict test rebuild | Run the complete 699-test suite again. A focused pass does not establish that result. |
| Legacy/contextual discovery and cache separation | Four-slot cache fixture misses its required legacy candidate. A 32-slot diagnostic finds actual `Nat.add` doubling before and after the contextual query, then fails the trace validator | Repair ordinary-query verification correlation; complete all six sessions and exact replays. Preserve the original four-slot failure and identify any changed budget explicitly. |
| Existing local-context behavior | Prior published 39-cell matrix remains accepted at its recorded revision | Rerun it against the prototype; review the six old global-metadata refusals individually if complete provider packets intentionally change their outcome. |

The forced method retains its original goal
`∀ (α : Type), [Ctx.C α] → Nat`. Its type parameter occurs only in a class
constraint on the provider. Adding an ordinary argument of type `α` would avoid
the problem. The successful observations instead distinguish Nat and Bool
dictionaries carrying 7 and 11.

## Delivery order

1. **Finish the existing Leant global-method integration (priority 3).**
   Resolve the trace contract mismatch, finish cache/discovery and local-context
   regressions, and rerun the complete suite. Then publish the code, dependency,
   reproducible fixtures and acceptance report together. Do not reopen engine
   inference work already demonstrated by the six real method queries.
2. **Close the Haskell frontend gaps (priority 3).**
   Preserve complete constrained source schemes when loading providers; make
   explicitly enabled Djinn provider admission usable, and support implicit-root
   behavioral aliases without changing binder scope or order. Use the actual
   public ordinary and named-`where` commands in both engines, with full original
   signatures, payload-sensitive execution and False controls. Public API success
   and compiler preflight are already useful evidence but do not close these gaps.
3. **Find and fix the missing Church construction paths (priority 4).**
   Trace actual rule admission, substitutions and queue decisions for
   `maybeEither` and `foldl1`. First determine whether the needed branch cannot
   be constructed or is merely delayed. A supplied witness and graph-shape counts
   do not settle that question. Accept a generic rule or scheduling change only
   when the original live query succeeds at its existing bounds and the accepted
   corpus remains intact. Keep reference implementations out of provider inventories.
4. **Validate supplied tree folds and accumulator composition (priority 2).**
   The prepared polymorphic tree fixture is an independent, bounded delivery.
   Execute it with its exact constructor/recursor inventory, order-sensitive
   observations, full-signature replay and Lean termination checks in both Haskell
   engines and all three Lean modes. It is prepared, not yet executed. It need
   not wait for a general recursion architecture or for all Church fixes.
5. **Extend dictionary evidence in separate increments (priority 3).**
   First preserve the selected outer/inner dictionary occurrence for equal
   predicates, demonstrating distinct payload behavior under nested scope.
   Then add conditional providers and superclass projections. A uniquely inferred
   type argument does not identify which dictionary was selected. Retain current
   overlap and universe guards until each extension has its own evidence.

Priority 1 remains accepted within its documented elaboration fragment.
Priority 4 still requires all **13 extended operations and 19 explicit-default
counterparts**, across Haskell Djinn/Exference and Lean Djinn/Exference/Both.
Recorded Haskell 12/13 coverage and selected defaulted/Lean subsets do not close
that matrix. Keep partial cases explicit with the agreed supplied default or
inhabitance assumptions in Lean. Execute outstanding cells with relevant
implementation increments; do not replace the obligation with another small
successful subset. Heavy runtime checks remain serialized.

## Other ideas, re-ranked

| Idea | Decision | Evidence needed to promote it |
| --- | --- | --- |
| Consistent ordinary/behavioral verification traces | Promote now, narrowly | The cache validator currently requires behavioral annotations for an ordinary query. Correlate the exact checked term, requested type, engine, renderer and response without borrowing another candidate's authority. Preserve bounded capture and omission reporting. |
| Reusable validation helpers | Promote within integration work | Share UTF-8 handling, runtime/source pinning and exact ordinary/where query formatting across the exercised runners. Preserve fixture-specific inventories and budgets. Validate the helper on both successful and rejected traces; avoid a general framework rewrite. |
| Executable routing tests | Incremental maintenance | Replace the touched brittle source-text assertion with behavior at the actual preparation/routing boundary where practical. Keep negative ownership, extra-premise and changed-goal controls. |
| Search-rule diagnostics | Promote for the two Church failures | Record why a concrete missing branch is rejected or postponed, including its substitutions and budget charges. Term-shape histograms alone are insufficient. |
| Ranking and larger search windows | Demote speculative changes | Two ranking experiments still produced 256 false `maybeEither` candidates. A 32-slot cache diagnostic is not a four-slot success. Require a measured cause and a successful original workload before changing policy. |
| Counterexample-guided search | Conditional follow-up | Show material repeated behavioral rejection after required constructions become reachable. Reuse only observations of the exact candidate under the same environment and predicate; finite agreement must not justify general equivalence or unsound pruning. |
| Provider retrieval | Conditional scaling work | Demonstrate a useful provider excluded from a realistic inventory and measure recall as well as latency. The cap-one method fixture already finds its provider. |
| Performance and cancellation | Profile a concrete remaining cost | Separate cold startup, rejected candidates, checker time, memory and cancellation latency. Preserve the accepted environment-reuse and cross-engine scheduling regressions. |
| Native Windows Length acquisition | Separate platform milestone | Promote for an actual Length workflow, with bounded file acquisition, real solver execution and independent replay. It does not resolve the current Church or method gates. |
| Native Lean engine migration, dependent/indexed synthesis, shared subgoal graphs, persistent caches, equality saturation | Defer broad work | Require a concrete workflow or measured bottleneck that the smaller scoped changes cannot address. Existing checked graphs and replay do not justify a rewrite by themselves. |

## Cache finding and evidence boundary

In the 32-slot diagnostic, backend 1 request 53 contains the ordinary contextual
candidate's exact type-checking command and reaches `TraceResponseParsed`.
Its `annotation_json` is absent. Production `synthVerify` calls `runCurrentCmd`
with `candidateVerificationProgram`; behavioral verification separately adds
`type-verification` annotations. The supplemental runner selects only annotated
candidate roles and consequently reports `query did not reach actual candidate
verification` for this ordinary phase.

This is a concrete trace-contract mismatch. It is not evidence that Lean never
received the candidate, and it does not establish cache correctness. Prefer a
small shared annotation boundary if production tracing is changed, or a validator
that establishes equivalent exact-request ownership from existing evidence.
Do not simply remove the verification requirement. Complete replay and all
remaining sessions after the fix. The original four-slot search miss remains a
separate result; any revised diagnostic budget must remain visible.
