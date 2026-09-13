# Synthesis delivery re-triage after selector acceptance

The immediate release task is to reconcile the trailing-type renderer repair with its existing compatibility and variant-budget contracts. Then close missing Church behavior cells in small batches. Preserve scoped dictionary selections as the next substantive evidence repair; keep the contextual-constructor search misses separately attributable. The coverage ledger is delivered infrastructure, no longer a proposed feature.

This assessment preserves the original priorities 1–4 and their completion requirements. It changes execution order based on current evidence, without accepting the pending source changes.

## Current evidence and release boundary

- The [Church behavior ledger](../../test-church/behavior-ledger.md) enumerates exactly 160 cells. Its selected receipts record **68 historical acceptances, four attempted cells without indexed acceptance, and 88 cells without indexed evidence**. These are not a current-revision pass rate, and missing indexed evidence does not mean never attempted.
- The six supplied-default selectors `head`, `last`, `fromJust`, `fromLeft`, `fromRight`, and `atKey` have recorded acceptance across both Haskell engines and Lean Djinn, Exference, and Both. The new Lean Djinn `last` result depends on an unpublished renderer change; working-source behavior acceptance does not establish release readiness. See the [selector report](2026-09-13-native-supplied-default-selectors.md) and [last/atKey report](2026-09-13-trailing-type-witness-frontier.md).
- The isolated renderer checkout uses committed Leant `d2e5473e1cbabfc36094cd84c651a9793e4fbc68` and clean Djex `c1ad560e106f59df07d1a32c3b51158ef749fc99`, with only the renderer delta and two new tests. Its strict build passes, but **705/707 unit tests pass**. The controller stops there: its six-case live behavior gate and both 350-signature replay gates did not run.
- The two failures concern a newly added `Unit` variant in the provider-result rendering list and an existing three-lane, 36-variant expectation. They establish a compatibility decision to resolve, not a demonstrated kernel-soundness failure. Do not mechanically relax the assertions or call the renderer accepted from the separate 6/6 working-source run.
- The [constructor diagnostic](2026-09-13-contextual-constructor-frontier.md) remains **17/21 positives and 6/6 actual False controls**. Its four failures comprise a Djinn method/tail bounded miss, ambiguous scoped reconstruction in Djinn and Both, and a separate Exference bounded miss.
- The previous production integration remains revision-specific: [705 native unit tests and both 350-signature replays](2026-09-12-contextual-list-native-integration.md). It does not validate the dirty constructor or renderer sources.

The isolated failure evidence is local at `C:/Leant-validation/trailing-type-witness/dist-newstyle/trailing-type-witness-isolated-v1/results.json` and `unit/unit.stdout.txt`. The unfiltered suite completed in 284.04 seconds. The controller records unchanged inputs. This re-triage does not add a new acceptance receipt or modify ledger counts.

## Delivery order and concrete exit criteria

| Order | Improvement | Why now | Acceptance boundary |
| --- | --- | --- | --- |
| 1 | Finish the bounded trailing-type renderer repair. | A real generated `last` candidate already passes when its unresolved trailing type is instantiated with `Unit`; the current proposal also changes other renderings. | Decide and document which unresolved sites may receive the fallback. Preserve explicit type selections, provider ownership, useful earlier variants, and bounded enumeration. Resolve both failing regressions with a justified contract; then pass the isolated full suite, six `last`/`atKey` positives, three False controls, and both signature replay corpora. Publish this small change independently of constructor work. |
| 2 | Close the missing Church behavior cells. | This directly measures the requested practical capability. The ledger now identifies the gaps without another infrastructure project. | First check for existing usable receipts; otherwise run the matching Lean Djinn/Both extended cases and nonempty reductions in bounded batches. Require original full types, defaults, provider sets and limits, live synthesis, actual False controls, and exact independent replay. Diagnose a failed batch and continue independent batches. |
| 3 | Preserve selected type arguments and dictionary occurrences through reconstruction. | The nested-context failure identifies evidence that is checked and then lost. This is more specific than another ranking experiment. | Carry scoped selections through erasure and reconstruction. Cover alpha-renaming, nested binders, equal-predicate dictionaries with different payloads, wrong-scope evidence, and missing-evidence refusal. Replay the complete target. Retain ambiguity rejection when the proof does not determine a choice. |
| 4 | Finish contextual-constructor acceptance and supplied-fold/tree composition. | Ordinary data remains an original requirement; the expanded probes expose both evidence and search issues. | Trace the exact native request, including strategy and candidate accounting. Repair Djinn method/tail composition at its original 32-candidate bound and investigate Exference nested contexts independently. Require the complete 21-positive/six-control matrix and affected full suites before broad acceptance. Publish canonical Djex first, then validate the exact Leant dependency. |
| 5 | Finish public query and provider coverage. | Existing internal capability should become reliably reachable through the agreed syntax, before large new language expansions. | Complete applicable named-function `where` one-shot entrances and kinded Haskell binders. Treat derived methods, conditional/superclass dictionaries, and broader Lean universes as separate increments, each with positive and refusal cases. Haskell kinds and Lean universes require distinct evidence. |

These are dependency priorities, not instructions to run competing heavy validations. One build/runtime owner freezes each run. A stalled independent batch does not block all other deliveries.

## What remains in the 160-cell target

There are **92 cells without indexed acceptance**, divided as follows:

| Batch | Cells | Proposed handling |
| --- | ---: | --- |
| All 13 extended operations in Lean Djinn and Both | 26 | Recover any qualifying historical evidence first. Run the missing modes against their original fixtures after renderer stabilization; do not infer Both acceptance from either constituent engine. |
| Haskell Djinn `maybeEither` | 1 | Retain its recorded failed attempt; attribute the search/evidence boundary before choosing a repair. |
| Supplied-default `foldl1`, `foldr1`, and `reduce`, all five modes | 15 | Next new operation family. Exercise empty/default behavior and nonempty accumulator behavior. |
| Nine extrema operations, all five modes | 45 | Group comparator-based, projection-based, and paired results by actual dependencies. Exercise singleton, ties, order, and supplied defaults; record each operation/mode separately. |
| Supplied-default native-`Int` `at`, all five modes | 5 | Keep distinct from accepted `atKey`. Preserve the declared integer primitive, negative/out-of-range behavior, and full type. Both Haskell modes already have attempts without indexed acceptance. |

The nine extrema operations are `maximumBy`, `maximumOn`, `minimumBy`, `minimumOn`, `minMaxBy`, `minmaxElement`, `maximum`, `minimum`, and `minMax`. Existing attempts and receipts determine implementation work; absence from this index alone does not establish a missing capability.

## Other ideas reconsidered

| Idea | Decision | Promotion trigger |
| --- | --- | --- |
| More coverage-ledger machinery | Maintain, do not expand by default. | A concrete missing provenance or outcome distinction. The 160-key index and 15 ledger tests are already delivered. |
| Failure-directed rendering and source-selected type arguments | Promote narrowly. | The two renderer regressions show the cost of broad fallback generation. Use actual binder/kind/universe evidence where available; consider diagnostic-directed retries only with preserved candidate identity and limits. Do not build a general retry framework to fix one case. |
| Exact request capture and candidate accounting | Promote as focused diagnostics. | Reproduce the native method/tail failure with identical providers, assignments, strategy, and limits; identify derivation loss, truncation, duplicate work, or reconstruction refusal. Simplified passing fixtures are insufficient. |
| Search-order or derived-value redesign | Defer until a causal trace. | Earlier priority and checked-derived-value experiments failed the real 32-candidate fixture. Both experiments were reverted; retained logs are diagnostic evidence. Show which missing branch a new rule recovers at unchanged bounds. |
| Clear unsuccessful-query explanations | Add alongside the touched failure path. | Distinguish unsupported source, bounded exhaustion, reconstruction failure, and verification failure. Never report a bounded miss as impossibility. |
| Duplicate suppression and observation caching | Conditional optimization. | Measure repeated work and establish keys containing scope, selected type arguments, dictionaries, environment, and observations. Printed equality is insufficient. |
| Broader provider discovery and ranking | Defer broad expansion. | Evidence that usable providers are excluded or delayed after admission and reconstruction work correctly. Larger inventories can make bounded search worse. |
| More verifier workers, transport tuning, general memoization | Defer. | A measured bottleneck and an end-to-end improvement without weakening replay or process isolation. |
| General recursion/induction, dependent or indexed synthesis, a Lean-native engine | Future scope. | A required practical example that existing representations and supplied folds cannot express, with termination and equality obligations identified. |
| Editor integration and platform tooling | Later product work. | Stable command behavior and materially broader accepted practical coverage. |

## Completion and publication

The practical target remains **(13 extended + 19 supplied-default operations) × (2 Haskell engines + 3 Lean modes) = 160 behavior cells**, with controls and independent replay additional. Lean counterparts of partial functions retain the agreed supplied default or inhabitance assumption. Named-function-plus-`where` remains the behavioral query interface.

The 160 cells are a regression target, not a mathematical completeness theorem for arbitrary rank-N or impredicative inhabitation. Source-evidence, ordinary-data, contextual-provider, and public-query obligations remain part of the original goal even after the matrix passes.

Keep root READMEs current and push stable milestones to `origin/main` in both repositories. This assessment publishes documentation only; the renderer and contextual-constructor changes remain unaccepted implementation work, and Leant's production dependency is unchanged.
