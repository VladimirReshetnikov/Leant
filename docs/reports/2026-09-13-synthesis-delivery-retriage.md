# Synthesis delivery after nested Church composition

The next substantial implementation target is **reduction construction**. The new `maybeEither` result provides a concrete search mechanism to investigate, while the attempted extension of contextual required-assumption construction has now failed its reduction gate. Remove that failed extension from the active proposals. Keep source-language and public-interface obligations explicit; Church behavior alone cannot establish practical rank-N and impredicative support.

## Current evidence and release status

A local candidate now closes the original Haskell Djinn and Lean Djinn `maybeEither` behavioral queries at their existing limits. Both Haskell engines pass all 13 extended operations in fresh runs, with independent GHC execution. Native Djinn, Exference and Both pass the original `maybeEither` query with exact Lean replay and actual False controls. The candidate also passes all 137 Djinn unit tests. Its broader release checks are still running, so these two cells are provisional and are not yet added to the published ledger. The implementation remains in isolated validation checkouts; this roadmap update does not publish it.

The published [contextual constructor release](2026-09-13-contextual-constructor-use-acceptance.md) already closes the original method/tail and nested-context failures. Its original Djinn query passes at 32 raw candidates, and its native matrix passes 21 positives and six actual False controls. The earlier [lexical type/dictionary selection](2026-09-13-exference-native-acceptance.md) and [trailing-type rendering](2026-09-13-trailing-type-witness-acceptance.md) repairs retain their separate acceptance records. These investigations leave the active queue.

The [behavior ledger](../../test-church/behavior-ledger.md) currently records **92 historical acceptances, 15 attempted cells without indexed acceptance, and 53 without indexed evidence**, out of 160. This is a receipt inventory, not a current-revision pass rate. Missing indexed evidence does not establish a missing capability. Lean Djinn `length` remains an independent open cell.

## Revised execution order

| Priority | Improvement | Reason and bounded next action | Exit criterion |
| --- | --- | --- | --- |
| Release gate | Finish validation and publication of the `maybeEither` candidate. | Keep its three source files frozen through the already running canonical and native checks. On success, publish the exact tested code and receipts, update the ledger, and pin Leant to the new Djex commit. | Required release gates pass, tested-code parity holds, and both remote main refs are verified. A focused pass alone does not close publication. |
| 1 | Reduction construction: `foldl1`, `foldr1`, `reduce` (15 cells). | Check admission of the continuation carrier `R = (a -> a) -> a -> a`, then applicability of the new path-sensitive head-use branch to its singleton function-carrier plan. Trace carrier, step, fold application and final arguments separately. | First, one original polymorphic query at unchanged bounds with independent behavior replay. Then all three operations across two Haskell engines and three Lean modes, including nonassociative operators and empty/default observations. |
| 2 | Lean Djinn `length`: one independent miss. | Run the original numeric-provider query on the frozen `maybeEither` candidate. If it still misses, identify whether the useful fold step is unavailable, delayed or rejected before choosing a change. | Exact original-type synthesis, independent Lean replay and an actual False control. Admission of both providers and Both-mode success do not discharge Djinn acceptance. |
| 3 | Native-integer `at` (five cells). | Preserve the original integer primitive and full signature. First isolate arithmetic-provider availability from construction of the indexing state. The accepted `atKey` variant does not discharge integer indexing. | All five modes pass negative, zero, in-range and out-of-range observations with the agreed supplied default. |
| 4 | Extrema (45 cells), divided by dependencies. | Start with one scalar comparator operation and one projection operation. Reuse accepted reductions when useful; investigate paired results and ordinary-order evidence separately. Run an original case before assuming an unindexed cell requires an engine change. | Each of nine operations passes all five modes, including singleton, ties, order and empty/default observations. Broaden only after a focused case passes. |
| Prerequisite throughout | Source-language forms, contextual evidence and public commands. | Promote any concrete source/interface blocker before the operation it prevents. Maintain the separate completion checklist below. | Full source types and lexical selections survive the real public entrance and independent compiler/kernel replay. |

This order is evidence-driven rather than a strict dependency chain. A ready scalar-extrema repair may precede integer indexing. If the focused reduction experiment cannot identify an actionable transition, retain its trace and move to an independent case; do not repeat it with only larger limits.

## What the latest experiments change

The `maybeEither` baseline retained 49 candidates before exhausting 500,000 choices. Its common-result plan already contained the outer Either eliminator and both Maybe eliminators. The successful candidate adds a normal-term branch that avoids repeating the same exact head along one application path. Sibling arguments can still reuse a head independently. The original first proof, complete original search continuation, fresh scope and shared accounting remain intact. This is evidence for a specific construction change, not blanket support for another scheduler redesign.

The attempted required-assumption extension found neither `foldl1` nor `foldr1`: the published baseline retained 3,467 candidates and the extension 2,466 at the same 500,000-choice limit. Fewer candidates did not mean better synthesis. The extension was removed and the failed runs retained locally for the forthcoming acceptance archive. The [earlier carrier-only experiment](2026-09-13-reduction-carrier-boundary.md) likewise failed its behavioral gates and remains unreleased.

The next reduction hypothesis has two independently checkable parts. The inspected baseline inventory lacks the desired continuation carrier, and the new head-use policy currently selects common-result groups rather than singleton function-carrier plans. The test-only `foldl1` and `foldr1` witness shapes fit the new grammar, including sibling reuse, and pass 80 finite observations. That analysis establishes neither live synthesis nor new compiler-replay acceptance. First show an admitted plan and a constructed step; then require the original complete query to pass. Reference implementations must stay outside synthesis providers.

The [numeric-provider experiment](2026-09-13-behavioral-provider-admission.md) admitted both providers but still missed `length`. Retrying the original query after the new construction change is a bounded compatibility check. If it fails, another provider-order change needs a trace of the derivation it would recover.

## Obligations beyond the 160-cell ledger

| Area | Required evidence and next action |
| --- | --- |
| Public behavioral queries | Exercise the approved named-function-plus-`where` form through applicable REPL and one-shot entrances, loading paths and result-selection modes. Replay the actual displayed implementation at its full signature. Direct engine API tests do not establish frontend coverage. |
| Haskell binders and kinds | Add named source cases for kinded binders, higher-kinded variables, nested and alternating polymorphic arguments/results, and constrained local callbacks. Distinguish parsing failures, unavailable constructions and reconstruction failures. |
| Lean universes and binders | Record outcomes for universe polymorphism, strict-implicit binders and dependent binders. The contextual constructor packet's documented Type-0 fragment and explicit universe-zero selections do not establish these broader forms. Preserve Lean's universe rules for Church encodings. |
| Contextual evidence | Cover derived, conditional and superclass evidence, deeper callback scopes and distinct dictionaries with equal predicates. Design transport of the selected dictionary before relaxing guards against erased or ambiguous evidence. |
| Ordinary recursive data with supplied folds | Close the original supplied-fold tree transfer query by live synthesis and replay. A debug witness is insufficient. Diagnose its carrier and step construction before proposing general recursion or a replacement engine. |

Use a small set of discriminating public examples with explicit outcomes. These are required parts of the practical goal, not optional work deferred until the ledger is full. A concrete blocker moves ahead of the behavior batch it prevents. Review all five areas before any completion claim.

## Other improvement ideas

| Idea | Decision | Evidence that would change the decision |
| --- | --- | --- |
| Carrier admission plus path-sensitive step construction | Promote to the next bounded reduction experiment. | An actual admitted plan, constructed step and original-query improvement; witness grammar compatibility alone is insufficient. |
| Required-assumption extension to carrier plans | Retire the tested variant. | A materially different, trace-supported construction requirement. Do not reinstate the failed variant unchanged. |
| More continuation carriers by themselves | Defer. | A missing representable derivation together with a viable construction path; the carrier-only failure already rules out treating enumeration alone as the fix. |
| Search caching and duplicate-work reduction | Measure before implementation. | Repeated expensive work in another required query, with cache keys preserving scope, chosen instantiations and dictionary identity. Keep raw limits and charging semantics unchanged. |
| Search performance regression check | Keep a focused check with the new policy. | Some unit cases took longer, but the existing runs are not controlled timing comparisons. A repeatable slowdown attributable to the policy justifies narrowing its applicability or allocation before broader adoption. Avoid a new benchmark project. |
| Counterexample-guided refinement and observation caching | Later optimization. | A measured repeated-verification bottleneck after useful terms can be constructed. Environment and observation identity belong in cache keys; final exact replay remains required. |
| Failure explanations | Add small diagnostics with each diagnosed miss. | Report the actual boundary: source/provider refusal, bounded search exhaustion, reconstruction refusal, behavioral rejection or verification timeout. Never turn a bounded miss into an impossibility claim. |
| General scheduling or derived-value redesign | Defer broad changes; retain focused, causal repairs. | A trace identifying a useful branch that the current construction and scheduling cannot reach within the recorded bounds, while preserving original alternatives and accounting. |
| Diagnostic-directed rendering retries | Keep focused repairs; defer a general framework. | A real reconstruction failure with candidate, binder, kind, universe and selected-evidence identity preserved within existing variant bounds. |
| More verifier workers or transport tuning | Defer until measured. | End-to-end evidence of a verification/transport bottleneck; preserve isolated, bounded replay. Current `maybeEither` evidence points to construction. |
| More coverage infrastructure or repeated full matrices | Maintenance only. | Missing provenance, relevant source changes or a specific unresolved regression. Use existing gates; do not substitute report generation for implementation. |
| General recursion/induction, indexed synthesis or a Lean-native search engine | Defer architectural commitment. | A required practical example outside the existing representation and supplied-fold approach, with termination and equality obligations identified. Required source-binder support remains in scope independently. |
| Editor integration and platform tooling | Later product work. | Stable public behavior and broader accepted practical examples. |

## Acceptance and publication

For a source change, first pass the discriminating original query, then the coherent operation/engine batch, then appropriate release checks on frozen inputs. Preserve unsuccessful attempts and record the producing engine separately in Both mode. Use one heavy build/runtime owner and repeat an already passed full suite only after a relevant change or unresolved concern.

The ledger still has 68 cells without indexed acceptance. The two provisionally passing `maybeEither` cells would reduce that to 66 after release and indexing. The remaining implementation groups are **15 reductions + 1 Lean Djinn length + 5 integer-at + 45 extrema**. Lean versions of partial operations retain the supplied default or inhabitance assumption. The full target remains `(13 extended + 19 supplied-default operations) × (2 Haskell engines + 3 Lean modes)`, with controls, exact replay and the source/interface obligations additional.

Keep root READMEs current, publish stable milestones to both `origin/main` refs, and pin Leant to the corresponding tested Djex revision. The practical rank-N/impredicative goal remains active. Neither this plan nor the 350-signature type corpus proves arbitrary synthesis completeness.
