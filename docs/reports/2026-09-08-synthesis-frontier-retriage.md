# Re-triage after tree transfer and implicit-signature regression

> Subsequent milestone: [implicit-signature scope](2026-09-08-implicit-root-scope.md)
> now passes 361/361 tests and 350 signatures per Haskell engine. GHC retains
> the vacuous outer synonym binder; the strengthened test preserves the
> genuinely erased-binder guard. The failed checkpoint below is historical.
> Next: native tree tracing, then remaining public frontend and Church behavior.

This September 8, 2026 update changes execution order within the active
priorities 1–4. **Finish the implicit-signature correctness gate, trace the
native tree candidate through verification, then extend public frontend and
Church behavior coverage.** The full goal remains open. The previously
planned transfer checks have now run; repeating them unchanged is no longer
the next delivery.

## What the new evidence changes

The [completed native integration](2026-09-08-combined-native-integration.md)
remains accepted at Leant production `43f1bc11` and Djex `bfc3692e`, pinned by
Leant `701cf4cb`. It includes 702 unit tests, the complete 12-cell native List
recursor matrix, 13 extended Lean Exference operations and 350 independently
replayed signatures per native engine. Its other context and verification
gates retain the fixture boundaries documented in that report.

The subsequent [tree/foldl1 receipt](https://github.com/VladimirReshetnikov/Leant/blob/main/test-recursive/receipts/tree-transfer-after-integration.json)
and [archive](https://github.com/VladimirReshetnikov/Leant/blob/main/test-recursive/receipts/tree-transfer-after-integration.zip)
record the following results at the original limits:

| Check | Result | Consequence |
| --- | --- | --- |
| Native Djinn tree | Positive query reaches its candidate limit without acceptance; actual False control completes | Remains a bounded miss; trace one derivation before changing construction rules |
| Native Exference tree | Positive and False queries time out | Neither cell is accepted |
| Native Both tree | Positive and False queries time out | Neither cell is accepted |
| Exference debug expression 115 | Independent Lean replay passes the full type and all 16 observations; provider, candidate and observation-proof axiom inventories are empty | A correct expression is present in debug output; its typed-candidate association and live verification/selection remain unestablished |
| Haskell Exference `foldl1` | No accepted positive survivor; actual False control and all four oracle controls pass | Retains the bounded miss; the oracle is not a synthesized implementation |

The native matrix uses window 1,024, 100,000 search steps/choices, cap 80 and a
90-second command deadline. The Haskell recheck uses window 256, 100,000 steps
and queue 8,192. A first tree attempt stopped before synthesis because the
fixture manifest was stale. Regeneration changed preparation hashes and the
manifest only; types, observations, providers, commands and limits were
unchanged. The archive preserves that failure as well as the subsequent run.
Native inputs and runtimes remained unchanged during execution. The Haskell
runner records its declared 20-file input scope and exact executable identity,
not a complete production-source census.

The in-progress Haskell implicit-signature implementation has a passing strict
build and **360/361 tests across six complete affected suites**. The
[failed-regression receipt](https://github.com/VladimirReshetnikov/Djex/blob/main/test-integration/receipts/implicit-root-retriage.json)
and [source/run archive](https://github.com/VladimirReshetnikov/Djex/blob/main/test-integration/receipts/implicit-root-retriage.zip)
preserve the uncommitted implementation and exact run:

| Suite | Result |
| --- | --- |
| `djex-tests` | 151/152 |
| `djex-api-tests` | 38/38 |
| `djex-parallel-tests` | 27/27 |
| `exference-frontend-api-tests` | 4/4 |
| `exference-cli-tests` | 25/25 |
| `djex-cli-tests` | 115/115 |

The new CLI cases cover 40 positive public queries with exact GHC replay, 20
actual False controls and four invalid-explicit-forall guards, across both
Haskell engines. Definitions retain the original signature and introduce
visible type patterns on the left-hand side. Expression output is checked as
an independently applied annotated polymorphic expression; pasting it as an
ordinary right-hand side under an ambiguous implicit signature is a separate
scope obligation.

The failing test is `do not reuse erased hints for synonym-introduced binders`
at `test-integration/Spec.hs:4657`. Root quantification makes the name `erased`
survive in the candidate hint map after expanding a phantom synonym, where the
test expects no names. This does **not yet establish** that an introduced
binder borrowed the name: the name might belong to a retained vacuous outer
binder. Compare the supported GHC's quantification and visible applications,
then inspect binder identities through expansion. Preserve the source-ownership
invariant; do not weaken the test merely to obtain a green suite. This increment
is **not accepted, committed as production, or promoted into Leant**.

## Revised delivery order

| Order | Delivery | Acceptance and stopping rule |
| --- | --- | --- |
| 1 | Resolve implicit-root quantification and synonym identity, P3 | Establish compiler behavior, repair the semantic or hint-mapping discrepancy, retain an identity-sensitive regression and rerun the complete affected suites. Exact original-signature output and selected dictionary payloads must survive. |
| 2 | Diagnose the reached native tree expression, P2 | Correlate expression 115 with its own typed graph, verification request, result and selection outcome under the original deadline. If that exposes a repair, require the original three-mode positive/False matrix and exact replays. One bounded diagnostic batch must precede any broader search change. |
| 3 | Finish public contextual presentation, P3 | One-shot contextual commands, then typed list output, as separate increments. Cover ordinary and named-`where` entrances, both engines, applicable first/best/all selection and exact displayed-output replay. Preserve binder order, nested scope and dictionary choice. |
| 4 | Complete Church behavior, P4 | Continue concrete missing cells: Djinn `maybeEither`, supplied-default selectors, nonempty reductions including `foldl1`, extrema and native-`Int` indexing. Keep all 13 extended and 19 supplied-default operations across all five modes. Record actual synthesis, full-type replay and completed controls separately. |
| 5 | Broaden contextual evidence, P3 | Derived Haskell methods and mixed Lean constructor/method inventories first; selected equal-predicate dictionaries, conditional/superclass evidence and richer universes follow in separately checked increments. |

The tree diagnostic must not turn into an open-ended prerequisite for frontend
or Church work. If it remains inconclusive, retain the evidence and continue
the next independent delivery. Likewise, diagnose the preserved `foldl1` miss
before another unchanged rerun. Heavy validation remains serialized with
frozen source, fixtures and executables.

The behavioral target remains **160 operation/mode cells**: 32 operations
across Haskell Djinn/Exference and Lean Djinn/Exference/Both, with controls and
replays additional. This is the total worklist size, not a missing-cell or
passing-cell count. Partial signatures stay explicitly separated; total Lean
counterparts use the agreed supplied default or inhabitance assumption.

## Further ideas, re-ranked

| Idea | New disposition | Evidence required to advance |
| --- | --- | --- |
| Candidate identity through search, verification and selection | **Promote now, narrowly for the native tree failure** | An owned association with the exact graph, source environment and request; bounded traces must disclose omissions and preserve deadline/budget accounting |
| Exact displayed-output replay across frontend forms | **Part of correctness acceptance** | Compile definitions under the unchanged requested signature and expressions in their advertised use context; exercise nested/constraint-only binders and distinct payloads |
| Machine-readable acceptance index and generated status summaries | **Useful follow-up to the next accepted milestone** | Derive current/historical/miss/timeout/unrun labels from existing receipts, including revision and fixture identity; detect stale documentation without treating different revisions as one aggregate pass |
| Exact duplicate suppression | **Conditional performance work, no longer automatically next** | Show equivalent repeated typed candidates or verification requests on the failing path; equality must include source ownership and dictionary choice, not printed text alone |
| Additional verification-request reduction or worker tuning | **Defer general changes** | The native List matrix already passes; reopen for measured costs in a remaining query, separating compiler work, transport and scheduling |
| Counterexample-guided search, observation caching, semantic pruning | **Defer** | Repeated exact candidate/environment/predicate evaluations with measurable cost; finite agreement alone cannot establish semantic equivalence |
| Provider retrieval and relevance ranking | **After provider admission** | A realistic inventory must demonstrably hide a useful supported provider; evaluate recall as well as latency |
| General memoization or shared subgoal graphs | **Defer** | A profile must identify equivalent repeated work; duplicate text and timeout totals are insufficient |
| General recursion, dependent/indexed synthesis, induction | **Separate expansion** | A required program must exceed supplied folds and expose concrete equality or termination obligations |
| Lean-native engine rewrite, editor/tactic integration, Windows Length acquisition | **Separate architecture/product/platform milestones** | A requested workflow and independent acceptance criteria; these do not close current frontend or Church behavior gaps |

Priority 1 stays accepted within its documented elaboration fragment. Accepted
ordinary structures, explicit-forall contextual output, provider filtering,
canonical Haskell Exference tree synthesis and native List integration remain
regressions. The new misses and failed frontend regression do not erase those
recorded successes or establish broader completeness.

## Preserved diagnostic artifacts

- Tree/foldl1 archive: 623 artifacts plus manifest, 5,021,987 bytes, SHA-256
  `d36b8c23b03e29454520c51c26ddcc6f01109cb0b059c988cc758438524c6a80`.
- Implicit-root archive: 333 artifacts plus manifest, 1,971,855 bytes, SHA-256
  `bffd0579b3caeb96d4f59b35d7747a0a5398a7b1137e70cec370014813052263`.

Every archive member was rehashed. These are diagnostic checkpoints, not new
synthesis acceptance receipts. They retain failed outcomes and the distinction
between a debug expression, an independently checked expression and an accepted
live typed candidate.
