# Further improvements after the contextual frontend investigation

This September 9, 2026 assessment supersedes the delivery order in the
[deadline/tree report](2026-09-09-synthesis-after-deadline-trace.md). The original
priorities 1–4 and their completion requirements remain in force. The next
milestones should close existing validation and evidence gaps, complete public
frontend coverage, then advance the full Church behavior matrix. Native tree
work gets a bounded investigation, not an exclusive claim on the delivery queue.

## What changes the triage

The deadline repair has progressed beyond the obsolete fixture pin. Its second
integration attempt records **nine completed gates**, including the retained
**705-test** unit result, fresh method controls, contextual and recursor checks,
and the Djinn signature corpus. The final Exference corpus has no terminal
acceptance receipt. Both that attempt and its restart have explicit interruption
records; the reason for termination is unknown. The parent `running` status is
stale. Do not classify these interrupted runs as successful, bounded synthesis
misses, or evidence of a new backend defect.

The latest completed focused one-shot frontend run passes **6/8 cases**: all
four Djinn selection/ranking combinations and Exference first/best. Exference
all/balanced and all/legacy fail when a candidate lacks an admissible source
graph. A later diagnostic identifies `Methods.method @Int` and the explicit
`UnsupportedContextualCertificateGraph` boundary. The local extension combining
lexical context with type-application certificates is **unbuilt and untested**;
the 6/8 result predates it and does not validate current source.

This also exposed a test-oracle issue. For a type-only query
`forall a. C a => Token`, a constant implementation using `method @Int` is legal.
The test currently expects every alternative to forward the caller's dictionary.
That is stronger than the type. Tests must independently verify the selected
dictionary: a forwarding candidate should yield `(37,91)` under the two fixture
instantiations, while a candidate explicitly selecting `Int` should yield
`(37,37)`. A named behavioral query can require forwarding. Do not remove valid
instances, discard the candidate, or accept arbitrary observations to make the
test pass. Expected choices should come from checked selection evidence or
explicit controlled cases, not a guess based on a printed substring.

The [interim evidence summary](2026-09-09-synthesis-after-contextual-frontier.json)
preserves receipt hashes, gate states and focused diagnostic text. It is a compact
triage index, **not** a complete archive or acceptance receipt. Its local paths
identify retained workspace evidence, not portable published artifacts.

## Revised order and concrete completion gates

| Order | Delivery | Why now and what completes it |
| --- | --- | --- |
| 0 | Close deadline integration; make long validation recoverable | Nine gates are already complete. Finish the entire 350-case Exference corpus and independent kernel replay under the existing settings. Retain completed gates only when their source, fixture and executable identities match. Publish the repair only with terminal aggregate evidence. |
| 1 | Close the contextual certificate boundary and correct the oracle | This is the concrete blocker for one-shot Exference all-selection. Add positive combined-context/certificate cases plus adversarial ownership, scope, slot and chain checks. Preserve the legacy context-free entrance and the distinction between lexical assumptions and instance discharge. Then strictly build and run the affected shared certificate, engine and frontend suites, exact output replay and corpus regressions. |
| 2 | Complete the remaining public contextual frontend | Finish one-shot acceptance, then typed list output and applicable named-`where` entrances. Cover both engines, first/best/all, definitions/expressions, exported provider inventories, original signatures and explicit/implicit binders. Integrate the exact accepted canonical Djex revision into Leant before promoting its dependency. |
| 3 | Advance all missing Church behavior cells | Work from the complete 160-cell ledger, prioritizing concrete bounded examples such as `maybeEither`, supplied-default selectors, nonempty reductions, extrema and native-`Int` indexing. Preserve the original per-mode bounds, False controls and exact compiler/kernel replay. A signature inhabitant does not by itself establish the operation's behavior. |
| 4 | Run one bounded native tree investigation | Instrument candidate forcing, lane transitions and provider discovery around the measured request-free interval. Identify the actual expensive phase before changing scheduling. A repair must pass the original Djinn/Exference/Both positive and False matrix, plus the full type and all 16 observations. If the batch finds no justified repair, record the miss and return to independent deliveries. |
| 5 | Expand contextual expressiveness in small increments | Address explicit remaining binder forms, derived methods and mixed constructor/method inventories, then distinct equal-predicate dictionaries, conditional/superclass evidence and richer universes. Each needs source ownership and independent language checks. These remain part of the original goal, not optional omissions. |

Orders 0 and 1 are closure of existing work. Their investigations can progress
independently, but heavy builds and runtime validation must remain serialized
with frozen inputs. Tree measurement can be a short independent task without
becoming a prerequisite for every remaining Church or frontend improvement.

## Further ideas: promote, condition, or defer

| Idea | Updated disposition |
| --- | --- |
| Durable validation checkpoints and terminal status reconciliation | **Promote now, narrowly.** Two interrupted corpus attempts demonstrate the cost. Preserve stable case IDs, exact settings, input hashes, completed outputs and independent replay. Any batched runner must account for all 350 cases exactly once, reject missing/duplicate/stale entries and finish with combined replay. An interrupted transcript alone is never a checkpoint of accepted results. |
| Small acceptance/freshness index | **Promote with the next acceptance milestone.** Track repository/dependency revision, fixture/runtime identity and accepted, historical, miss, timeout, interrupted, preflight-failed and unrun states. Keep immutable receipts; derive summaries instead of maintaining competing counts by hand. The index here is only an interim starting point. |
| Exact public-output replay and evidence-specific behavioral oracles | **Required correctness work.** A well-typed internal term can lose binder or dictionary choices during presentation. Verify the exact displayed result at the original signature and separate type validity from requested behavior. |
| Candidate identity plus phase timing | **Promote only for the tree question.** Correlate search candidate, graph, rendering and backend request; report omitted records. Existing evidence points toward search work but does not identify a precise cost center. |
| Fair resumable scheduling | **Conditional.** Implement only if measurement establishes starvation. Preserve lane cursors, candidate identities, common deadlines and total budgets; retain accepted List and Church regressions. |
| Exact duplicate suppression or observation caching | **Defer until measured repetition.** Equality must include source environment, polymorphic selections and dictionary identity. Printed-text equality and finite behavioral agreement are insufficient. |
| More verifier workers, batching or transport tuning | **Defer general optimization.** The deadline repair is concrete reliability work; the tree's long request-free interval is not evidence that more backend concurrency will help. |
| Provider relevance ranking | **After admission and scheduling correctness.** Measure recall as well as latency; do not hide needed providers to obtain faster tests. |
| General memoization, shared subgoal graphs and semantic pruning | **Defer pending profiles and sound equivalence keys.** Do not add a broad caching architecture merely because a query timed out. |
| General recursion, dependent/indexed synthesis, induction or a Lean-native rewrite | **Separate expansions.** Reconsider when a required example exposes an obligation beyond supplied folds or the current representation. They do not close the immediate frontend and behavior gaps. |
| Editor integration and additional platform tooling | **Later product work.** First make the public command surfaces and documented acceptance reliable. |

## Scope and evidence boundaries

The full behavior target remains **(13 extended + 19 supplied-default operations)
× (2 Haskell engines + 3 Lean modes) = 160 cells**, with negative controls and
exact replays additional. This is the worklist size, not a pass count. Partial
Lean cases retain the agreed supplied default or inhabitance assumption.

Previously accepted elaboration, ordinary structures, canonical Haskell
Exference tree synthesis, native List recursors and contextual fragments remain
regressions at their recorded revisions. Native tree synthesis is still
unaccepted in all three modes. Neither this report nor the local unvalidated
patch establishes complete rank-N or impredicative synthesis support.
