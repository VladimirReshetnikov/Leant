# Further synthesis improvements: revised priorities

This decision supersedes the execution order in the [previous delivery plan](2026-09-13-synthesis-delivery-retriage.md). That document retains the investigation history and acceptance links. The practical rank-N/impredicative goal remains active; neither this plan nor type-signature coverage establishes arbitrary synthesis completeness.

## What changed

The [intrinsic-unit repair](2026-09-14-intrinsic-unit-construction-acceptance.md) is published in Djex at `66b3212be9e5849cc8398ef9de67837e2e0e276f`. It preserves the original `maybeEither` candidate window while adding construction in an empty inventory. Further unit-cost experiments leave the queue.

The [contextual binder-universe release](2026-09-14-contextual-universe-acceptance.md) is now integrated. Its final source passes **63 public cells** (42 exact kernel replays and 21 actual-False controls), **746 native tests**, **100 private Exference tests**, and the additional **27 contextual-constructor and 15 strict-binder public regression cells**. All four release controllers are terminal passes, source/runtime hashes remain unchanged, and the complete archive includes the final source-transport checks. Leant pins the tested Djex revision above. This closes release item 0. The subsequent [bounded comparison and boxed-value baseline](2026-09-14-selected-polytype-frontier.md) advance the next source action to exact nominal universe signatures needed by polymorphic payloads.

The nominal prerequisite now has working-tree evidence, while contextual polymorphic selection has reached a more precise failure boundary. Broader class/provider work moves behind explicit Haskell kinds and integer indexing unless a concrete dependency requires a small part of it sooner.

## Latest working-tree evidence

These results concern **uncommitted Leant implementation changes**, not an accepted release or a new Djex capability. The published contextual binder release remains the baseline. The [triage evidence summary](../../test-church/receipts/nominal-universe-triage-2026-09-14.json) records the producing receipt hashes and individual outcomes; it is not a complete reproducibility archive.

- Exact nominal declaration signatures and selected universe vectors pass a strict native build, 87 focused tests, and compilation of the emitted Lean serializer.
- Fixed and explicitly selected higher-universe boxes pass **12 public cells across Djinn and Exference**: eight exact Lean replays with empty axiom inventories and four actual-False controls. Both mode and the full native regression suite have not been rerun for this implementation.
- The original boxed polymorphic payload now passes source admission, but Djinn candidates reach `ContextUnsupportedSelectedPolytype` during projection. The original signature and behavioral observations remain unchanged. The 60-candidate limit is reached with no accepted result; its False run is not a successful rejection control.
- A query using `GenericBox.{0}` and `GenericBox.{1}` together remains unresolved: Djinn times out at 20 seconds; Exference reaches its step limit with zero candidates and reports 18,974 queue-pruned states. Distinct selected identities appear in the source fragment, but that alone does not establish construction support. The ordinary query requires exact type checking; its `where` query additionally requires preservation of both supplied payloads. Neither engine's False run establishes predicate rejection.

## Execution order

| Order | Deliverable | Why now and how to finish |
| --- | --- | --- |
| 1 | Contextual selection of a polymorphic type. | The original boxed-value query now reaches a specific projection refusal. Recover the selected type's source binder and universe evidence from the expected result and/or an anchored argument, preserving scope, visibility, capture avoidance and erasure agreement. Require ordinary and named-`where` results with exact replay, plus actual-False controls, in Djinn, Exference and Both. Do not remove the guard or guess Type 0 metadata. |
| 2 | Finish the nominal-universe increment and its release gates. | Preserve the passing single-box cases. Trace the first missing construction step in the original two-selection query at unchanged limits; distinguish provider discovery, application, product construction and search pruning before proposing a repair. Require both selected payloads in one behaviorally checked result, malformed-metadata rejection, Both coverage and affected native regressions. Source identity tests alone cannot close this item. |
| 3 | Exference explicit Haskell kinds. | This remains a separate public execution guard despite shared kind transport and Djinn progress. Follow an original kinded query through opening, freshening, substitution and provider checking to the first lost kind. Require Exference's own ordinary and named-`where` results with GHC replay. Keep this bounded source task ahead of a general provider redesign. |
| 4 | Integer `at`. | Baseline one native engine before assuming unindexed native cells share historical Haskell misses. Separate arithmetic availability from index-state construction. Then require both Haskell engines and all three native modes, with negative, zero, in-range and out-of-range observations and supplied defaults. This has a smaller behavioral acceptance target than an extrema family. |
| 5 | Higher-universe classes and selected global providers. | Preserve declaration-local universe ownership, actual sorts and selected dictionary identity. Start with one discriminating class/provider example, then two selections and distinct dictionaries in one query. Promote only the minimal dependency if it blocks items 1–2; defer a general discovery redesign. Prop/Sort formation and unsupported level operations need their own evidence. |
| 6; causal diagnostics only | Lean Djinn `length`, reductions and extrema. | The direct/wrapped `length` comparison missed the expected normalized fold witness at both original 500,000-choice limits and did not isolate constructor-field loss. Existing extrema/carrier misses likewise do not justify another heuristic. Resume only with a different bounded trace identifying an absent, pruned or unaffordable witness step; make at most one general repair per supported hypothesis. |

This is a serial execution order for one heavy build/runtime owner. Items 1–2 form the immediate source milestone; publication must distinguish a deliberately scoped nominal increment from complete polymorphic-selection support if they are released separately. Completed intrinsic-unit and contextual-binder releases leave the improvement queue. Do not repeat unchanged full matrices or enlarge search limits to manufacture acceptance.

## Preserve the source evidence at each boundary

Use the smallest representation that preserves the required evidence, with separate public gates:

1. **Selected polymorphic arguments:** lexical opening and capture avoidance; compute the selected type's universe rather than treating it as Type 0. Require a test that needs this selection, not just a higher-rank signature that admits an unrelated implementation. Lean's predicative type hierarchy remains authoritative.
2. **Selected nominal and class declarations:** keep declaration universe parameters, argument sorts and result sort separately from the selected level vector. A private identity must distinguish the structured declaration name and its normalized selection. Test two distinct selections in one query, equivalent `max` expressions, and inconsistent metadata.
3. **Selected global providers:** instantiate declaration universe parameters from actual source evidence before installing a closed search binding. Test a method/provider at two universe vectors, with observations that distinguish its chosen dictionary. Matching printed parameter names is insufficient evidence of ownership.

Sort accounting is a shared correctness requirement, not a separate algebra project. Higher-universe dictionaries and Prop-valued classes must contribute correctly to Pi formation. Extend represented level operations only as required by a concrete example; do not silently discard a dictionary's universe or replace an unsupported result with Type 0.

Each source gate uses the original signature, ordinary and named-`where` entrances, individual engines and Both, independent exact replay, and actual-False or malformed-source controls as appropriate. A Both result does not establish success in either individual engine. The contextual API's policy Boolean does not establish a separate batch API.

## Other ideas: promote only with evidence

| Idea | Revised disposition |
| --- | --- |
| Conditional, derived and superclass evidence; distinct dictionaries with equal predicates | A required practical obligation. Promote the smallest failing example immediately when it blocks polymorphic selection or a universe milestone. Keep evidence identity explicit; defer a general instance-search redesign. |
| Supplied-fold trees | Retain as a transfer test of general construction. Promote if it reveals a shared blocker; supplying a fold or a reference implementation is not synthesis acceptance. |
| Search diagnostics | Include the actual failure boundary in each fix: unsupported source, search limit, rejected selection, reconstruction failure, behavioral mismatch or verifier timeout. Build only the trace needed for the next causal experiment. |
| Prefix stability and duplicate work | Preserve the accepted unit/product regression checks whenever search changes. The unit regression demonstrates that adding a valid alternative can displace an existing result at a fixed limit. Measure useful-result position and charged work, not just total term count. |
| Caching, counterexample-guided refinement and extra verifier workers | Defer until measurements identify repeated checking or verification as the bottleneck. Current construction misses do not justify these optimizations. Cache identity would need source scope, selected types, dictionaries and observations. |
| Reduction carriers, head ordering and use-all-inputs filters | Keep the tested failed variants retired. Reopen `foldl1`, `foldr1` or `reduce` only with a different trace-supported hypothesis and a bounded experiment. |
| Generic scheduling, rendering-retry frameworks, recursive/dependent synthesis redesign or a Lean-native search engine | Defer architecture changes until a required public example establishes the missing representation or construction rule. Preserve focused fixes with explicit scope. |
| Editor integration and broader platform work | Later product work, after the outstanding source and behavior obligations. |
| More reports or repeated full matrices | Maintenance only. Preserve provenance and update the ledger when new evidence arrives; documentation volume and repeated unchanged runs are not capability improvements. |

## Coverage and stopping rules

The [behavior ledger](../../test-church/behavior-ledger.md) still records **94 historical acceptances, 23 attempted cells without indexed acceptance, and 43 without indexed evidence**. Those are evidence categories, not a current pass rate. The 66 cells without indexed acceptance comprise 15 reductions, one Lean Djinn `length`, five integer-`at`, and 45 extrema cells. The source obligations above are additional; this re-triage closes no behavior cells.

For each implementation: establish the discriminating public example, fix the first demonstrated loss, run the affected family and appropriate release checks, then publish a stable milestone to both repositories and keep the native pin coherent. Preserve unsuccessful bounded experiments without treating a miss as an impossibility proof. Partial Lean cases continue to require a supplied default or inhabitance assumption.
