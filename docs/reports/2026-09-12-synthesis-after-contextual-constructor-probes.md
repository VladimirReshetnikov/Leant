# Further improvements after contextual constructor probes

The next delivery is acceptance of the contextual-constructor repair already in progress, followed by missing Church behaviors. General search expansion, larger budgets and a new engine remain lower priority. This assessment supersedes the delivery order in the [previous re-triage](2026-09-09-synthesis-after-contextual-list-acceptance.md), while preserving the original priorities 1–4 and their completion requirements.

## Evidence that changes the order

The [native compatibility integration](2026-09-12-contextual-list-native-integration.md) is published and complete: ten fresh gates, 705 unit tests, and both 350-signature kernel replays. Leant pins Djex `c1ad560e`. Repeating that completed integration without a new change adds no capability coverage.

The subsequent **uncommitted working repair** passes a strict native build. Its diagnostic run completes all six contextual-list positives: construction from a supplied argument and construction using the caller's selected dictionary, each in Djinn, Exference and Both. All six exact displayed terms pass independent kernel replay at the original types and the specified observations. The existing six ordinary/behavioral method-discovery cases also pass, including their exact replays. The combined parent process exits zero.

These observations come from the local `dist-newstyle/native-contextual-lists-probe-v6/results.json` and `dist-newstyle/contextual-constructors-methods-v2/results.json` in Leant. They are development evidence, not a published acceptance receipt. The list probe has no actual False controls. Full canonical regressions and the complete native unit suite have not yet been rerun for this repair. Neither repository's published implementation includes it yet.

The earlier six public admission refusals are therefore historical evidence of the published version, no longer the only evidence for the working implementation. The repair addresses three connected obligations:

1. Retain actual universe-zero constant arguments and source-owned constructor declarations through Lean source capture, translation and rendering.
2. Let Djinn compose checked polymorphic value instantiations with lexical dictionary helpers. Separate plans for these mechanisms could not construct the desired contextual result.
3. Preserve ordinary provider-only search before constructor enrichment, and prefer relevant session methods in contextual discovery. Constructor availability had exposed a regression where an unrelated constant displaced the caller's method.

Constructor declarations supply checked positive values; they do not grant exhaustive elimination or refutation authority. General universe-polymorphic and dependent synthesis remain separate work.

## Revised delivery order

| Priority | Deliverable | Completion boundary |
| --- | --- | --- |
| 1 — finish the current repair | Accept contextual constructors and dictionary/polymorphic-value composition. | Add a canonical regression using an abstract datatype with polymorphic constructor functions, so ordinary datatype expansion cannot mask the composition gap. Cover actual False queries, unsupported source metadata, dictionary identity, wrappers/nested binders, provider-disabled construction and overlapping constructor/provider inventories. Check the staged fallback preserves deadlines and checked-candidate state. Run affected canonical and native regressions, publish Djex first, then accept and promote that exact Leant dependency. |
| 2 — advance the requested behavior coverage | Deliver missing Church operation/mode cells in bounded batches. | Start with Haskell Djinn `maybeEither` and supplied-default selectors/reductions. Use failure evidence to order extrema and native-`Int` indexing. Require live synthesis, original signatures and providers, unchanged fixture limits, observations, actual False controls and exact independent replay. Preserve accepted Exference behavior as regression coverage. |
| 3 — complete public query access | Finish applicable named-function `where` one-shot entrances, then kinded source binders. | Reuse the existing parsing and evidence paths. Verify lexical scope, ambiguity, ordinary exports, selection modes and exact displayed output. Behavioral evaluation retains subprocess isolation and the command deadline. |
| 4 — broaden evidence support | Add derived methods, mixed constructor/method inventories and further dictionary/universe forms. | Handle overlap between the new intrinsic constructor inventory and discovered values as part of priority 1: reconcile identical declarations only with matching evidence, and refuse conflicting ownership. Broader derived, conditional and superclass evidence follows in separate accepted increments. Haskell kind generalization and Lean universe generalization need distinct fixtures. |
| Bounded investigation | Attribute the remaining native tree failure. | At the next stable milestone, run one instrumented batch correlating discovery, candidate forcing, graph checking, rendering and backend requests. Preserve the original positive/False matrix and all 16 observations. A repair needs a demonstrated cause; otherwise record the unresolved boundary and resume the Church queue. |

The current repair is close enough to justify finishing its acceptance before opening another feature. That does not justify expanding it into arbitrary universes or a general recursion project. If acceptance exposes a larger independent obligation, record the failing case and move to the independent behavior batch after retaining a coherent supported boundary.

## Re-triage of other ideas

| Idea | Decision and reason | Trigger for more work |
| --- | --- | --- |
| Complete behavior ledger | Promote alongside the next Church batch. The dispersed historical receipts make it too easy to confuse repeated regressions with new coverage. | A small receipt-derived index with exactly 160 operation/mode keys, states such as unrun/refused/failed/accepted, and source/runtime identities. Keep historical acceptance distinct from validation of the current revision; do not invent an aggregate current pass rate. |
| Search mechanism composition | Promote the concrete contextual-helper/polymorphic-value interaction already exposed. | A regression that fails without the composition rule and verifies the resulting source evidence. Avoid adding another unrelated heuristic to compensate for a missing composition path. |
| Search fairness and staged fallback | Keep the limited staging required by the new constructor inventory. Defer a scheduler redesign. | A reachable useful lane demonstrably starved under the shared limits, with a regression for deadline, cancellation and ownership preservation. |
| Provider relevance and inventory size | Retain the contextual session-method priority repair. Defer broad ranking changes or larger caps. | Recall/latency measurements showing a missed relevant provider after admission and evidence reconstruction work. |
| Candidate identities and phase timings | Restrict to the diagnostic needed for tree attribution and other reproduced stalls. | Enough correlation to identify the phase responsible for missing candidates or cost. End-to-end time alone is insufficient. |
| Exact displayed-output replay | Continue as required acceptance infrastructure. The earlier Haskell extraction repair is done. | A new output form or a concrete replay gap. Never substitute an edited implementation for the displayed candidate. |
| Durable corpus checkpoints | Small reliability improvement when a real interruption warrants it. | Stable case IDs, input/runtime hashes and complete final replay. A general run orchestration framework is deferred. |
| Duplicate suppression, observation caching, counterexample-guided pruning | Defer until repeated work is measured. | Safe identity keys covering lexical scope, type selections, dictionary evidence, environment and predicates. Large alternative counts alone do not establish semantic duplication. |
| More verifier workers, transport tuning, RTS changes | Defer general optimization. | A measured verification/transport/memory bottleneck. Variable host startup times do not establish one. |
| General memoization or shared subgoal graphs | Defer architecture work. | Repeated equivalent subproblems with evidence-preserving scope keys. |
| General recursion, induction, indexed/dependent synthesis, Lean-native engine | Separate example-driven expansions. | A required practical program beyond the supported data and supplied folds, with termination, equality and representation obligations identified. |
| Editor integration and additional platform tooling | Later product work. | Stable public command semantics and accepted practical coverage first. |

## Completion and publication

The required behavior matrix remains **(13 extended + 19 supplied-default operations) × (2 Haskell engines + 3 Lean modes) = 160 cells**. Controls and replays are additional. Partial Lean counterparts retain the agreed supplied default or inhabitance assumption. Behavioral queries retain the approved named-function-plus-`where` syntax.

The new contextual-list probes add evidence for a supporting capability; they do not fill missing Church cells by association. Native tree synthesis remains unaccepted in all three modes. Signature inhabitation, finite behavioral observations, original-type replay, regression acceptance and publication remain separate claims.

Publish the current code repair only after its acceptance gate passes. Documentation may record development findings earlier if it labels them explicitly. Continue stable milestone pushes to `origin/main` in both repositories and update the root READMEs at each capability delivery. The broader implementation goal remains active.
