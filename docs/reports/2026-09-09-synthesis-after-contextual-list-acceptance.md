# Further improvements after contextual list acceptance

> Superseded delivery order: the [contextual-constructor re-triage](2026-09-12-synthesis-after-contextual-constructor-probes.md) records six successful working-tree list probes and six passing method cases. Acceptance and publication of that repair remain pending; the earlier refusal evidence below describes the published implementation.

> Subsequent acceptance: the [native compatibility integration](2026-09-12-contextual-list-native-integration.md) passes all ten fresh gates and promotes Djex `c1ad560e`. The release gate below is complete; the separate Lean contextual list admission and other capability deliveries remain open.

The Haskell contextual list repair is accepted and leaves the implementation queue. The next release gate is native integration of that exact Djex revision. The next capability work should address Lean contextual list source admission and missing Church behaviors in bounded batches. This replaces the delivery order in the [previous assessment](2026-09-09-synthesis-after-native-contextual-integration.md); the original priorities 1–4 and their completion requirements remain active.

## What changed

The [canonical contextual list milestone](2026-09-09-contextual-list-output.md), Djex `c1ad560e106f59df07d1a32c3b51158ef749fc99`, passes 2,385 tests in 16 complete suites. Its 80 one-shot queries replay 2,526 exact displayed alternatives; both Haskell signature corpora pass 350/350 and extended Exference retains 13/13 behaviors. The named REPL cases cover selected dictionaries, nonempty lists, preserved tails, polymorphic elements, wrappers, hidden constructors and unused outer/nested contexts. The earlier nine-test diagnostic is superseded by this acceptance. Output extraction and missing root-signature evidence in that matrix are repaired, rather than outstanding reasons to repeat the same investigation.

Leant's committed dependency remains `3adfac5c57ad5e1bec77c598c647f6c8eb38e6e6`, accepted by the [previous ten-gate integration](2026-09-09-one-shot-native-integration.md). A fresh strict native build against `c1ad560e` passes with `-Werror`, but its ten native integration gates have not run. A successful build neither promotes the dependency nor establishes Lean contextual list support.

The new [diagnostic receipt](https://github.com/VladimirReshetnikov/Leant/blob/main/test-recursive/receipts/contextual-list-admission-diagnostic.json) and [archive](https://github.com/VladimirReshetnikov/Leant/blob/main/test-recursive/receipts/contextual-list-admission-diagnostic.zip) record six completed public probes, two signatures in each Lean mode:

```lean
class Ctx.C (α : Type) where out : Nat

-- Discover the method and use the caller's selected dictionary.
∀ (α : Type), [Ctx.C α] → List Nat

-- Construct from an argument; provider discovery is disabled.
∀ (α β : Type), [Ctx.C α] → β → List β
```

The named `where` predicates require respectively singleton lists containing 7/11 from distinct dictionaries at the same type, and singleton lists containing the supplied Nat/Bool arguments. All six queries are refused at contextual-source admission before search. All six separately supplied reference implementations and predicates pass kernel checks with empty axiom inventories. These are diagnostic oracles, not synthesized candidates. No False controls were run, and this receipt is explicitly not acceptance.

The source converter in Leant's `src/Leant/Synth/Fragment.hs` rejects nominal constants carrying any universe arguments. That includes `List` instantiated at universe zero. Its version-1 contextual-source packet and the corresponding `ContextSource` representation do not carry those constant universe arguments. This identifies an earlier representation boundary than constructor search. The recursive `FParamRec` printed by the fragment translator is not evidence that recursive search caused the refusal. A list constructed from an ordinary argument with provider discovery disabled is refused too, so changing method ranking or provider caps cannot address this admission boundary.

The archive retains the corrected six-case driver, commands, output, reference source, kernel results and strict-build evidence: 51 artifacts, SHA-256 `ca9ac166154c4d38c44a96e399a93509a57c2b797dc899b9ff921af943f17984`. Source hashes still match the strict build at packaging time; this diagnostic does not claim a complete acceptance input freeze. The first attempt stopped at a syntax error in its second reference fixture; the corrected run starts afresh and completes all six cases.

## Delivery order

| Order | Delivery | Completion requirement |
| --- | --- | --- |
| Release gate | Integrate canonical Djex `c1ad560e` into Leant. | Run the ten native gates against frozen sources and runtimes: 705 unit tests, method positives/controls, local contexts, simplification, native recursors, extended Exference, nested forall, and both 350-signature corpora. Promote the gitlink only after the exact revision passes. Keep the new list admission refusal visible; these compatibility gates do not cover it. |
| 1 | Admit the smallest useful Lean contextual list fragment with exact source evidence. | Start with universe-zero instantiations needed by the two examples above. Preserve actual constant levels, lexical binder identity, constructor authority and selected dictionaries through source capture, translation, graph checking and rendering. Then establish whether constructor search has a separate gap. Require all three modes, original full-type replay, both dictionary observations, argument-only construction, actual False controls, unsupported-metadata controls and affected regressions. Do not simply remove the universe guard or infer authority from printed names. |
| 2 | Add missing Church behavior cells in small batches. | Use the complete 160-cell worklist. Start with Haskell Djinn `maybeEither` and supplied-default selectors/reductions, then extrema and native-`Int` indexing according to measured failure causes. Require actual synthesis, original types/providers/limits, observations, False controls and exact independent replay. Accepted Exference batches are regressions; rerunning them alone does not advance coverage. |
| 3 | Finish the remaining public query forms. | Add applicable named-function `where` one-shot entrances, then kinded source binders. Reuse parsing and evidence paths; cover ambiguity, lexical scope, ordinary exports, selection modes and exact displayed output. Preserve subprocess isolation and deadlines for behavioral evaluation. |
| 4 | Broaden provider and dictionary evidence after the concrete admission work. | Derived Haskell methods and mixed constructor/method inventories first; distinct dictionaries with equal predicates, conditional/superclass evidence and more general Lean universes as separate increments. Each increment must retain exact source/evidence ownership through replay. Haskell kinds and Lean universes require separate acceptance. |
| Bounded investigation | Attribute the remaining native tree failure. | One instrumented batch at a milestone boundary, correlating discovery, candidate forcing, graph construction, rendering and backend requests. Preserve the original positive/False matrix and all 16 observations. If no justified repair emerges, record the cause or remaining uncertainty and return to the queue. |

The first capability delivery is bounded. Supporting the required universe-zero constants must not silently become a general dependent-type or universe-polymorphic synthesis project. If it exposes another representation obligation, retain a reproducible refusal and move to the independent Church batch. Neither larger search limits nor a broad recursive expansion is justified by these six pre-search refusals.

## Other ideas, re-triaged

| Idea | Decision | Evidence needed to promote it |
| --- | --- | --- |
| Exact displayed-output replay and evidence-specific oracles | Keep as required acceptance infrastructure. The accepted Haskell extractor repair is done. | New output forms or a concrete replay gap; never rewrite displayed code into an oracle that happens to pass. |
| Compact acceptance index and complete behavior ledger | Promote a small receipt-derived index alongside the next behavior batch. | All 160 operation/mode keys, explicit unrun/refused/failed/accepted states, exact source and runtime identities, no duplicate keys and no aggregate pass rate combining incompatible revisions. |
| Durable corpus checkpoints | Incremental reliability work when an actual run is interrupted. | Stable case IDs, input hashes and combined replay; no stale or incomplete receipt reuse. A new general orchestration framework is deferred. |
| Candidate identities and phase timings | Approve only the diagnostic needed to attribute tree work. | Correlation sufficient to identify the phase responsible for cost or missing candidates. |
| Fair resumable scheduling | Conditional. | A useful reachable lane demonstrably starved under shared bounds, with cursor, ownership and cancellation preservation. |
| Duplicate suppression, observation caching and counterexample-guided pruning | Defer. | Measured repeated work and safe keys covering environment, polymorphic selections, dictionary evidence and predicates. Displayed-alternative counts do not establish duplication or semantic equivalence. |
| Provider relevance ranking and larger inventories | After source admission. | Recall and latency evidence on representative modules; neither can supply missing universe or dictionary evidence. |
| More verifier workers, transport tuning, RTS changes | Defer general optimization. | A measured verification, transport or residency bottleneck. The current refusal occurs before search; variable host startup times are not a causal performance finding. |
| General memoization or shared subgoal graphs | Defer architecture work. | Repeated equivalent subproblems with scope-safe keys. |
| General recursion, induction, dependent/indexed synthesis, Lean-native engine | Separate example-driven expansions. | A required practical program beyond supported data and supplied folds, with the necessary termination/equality/representation obligations identified. |
| Editor integration and additional platform tooling | Later product work. | Stable public command semantics and accepted coverage first. |

## Completion boundary

The behavior target remains **(13 extended + 19 supplied-default operations) × (2 Haskell engines + 3 Lean modes) = 160 cells**. Negative controls and independent replays are additional. Partial Lean counterparts use the agreed supplied default or inhabitance assumption. Behavioral queries retain the approved named-function-plus-`where` syntax.

Signature inhabitation, finite behavioral observations, full-type replay, regression acceptance and remote publication are separate claims. Native tree synthesis remains unaccepted in all three modes. The canonical Haskell list milestone is accepted; its native compatibility integration and new Lean contextual list behavior are separate pending deliveries. The broader implementation goal remains active.
