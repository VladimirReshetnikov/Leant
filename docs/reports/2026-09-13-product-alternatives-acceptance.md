# General product alternatives: Haskell acceptance

Djinn can now synthesize the mixed pair from two independently quantified inputs in the original public named query, at the original search bounds. The final candidate passes the complete 11-case kinded-source matrix and 383 relevant regression tests. The exact five changed source files have been integrated into Djex. Leant's dependency and native product acceptance remain pending.

## Behavior and implementation

The discriminating source signature is:

```haskell
forall a. (forall (f :: * -> *). a) -> (forall (f :: *). a) -> (a,a)
```

The named-function `where` query supplies distinct values 7 and 9. Previously the search produced only candidates using the first input. It now displays `probe a b = (a @_, b @_)`; the exact displayed definition compiles at the original signature and satisfies the predicate. The focused run checks three candidates: one true and two false, with zero errors or timeouts. Its actual-False control rejects all 16 observed candidates without errors or timeouts.

The additional normal-term grammar now supports product introduction, forwarding and projection, including nested/unit products, function arguments and functions obtained by projection. Projection uses the independently checked tuple eliminator and fresh binders. Exact atom identities and distinct projection paths remain separate. Sums and nominal elimination retain the existing LJT route; no operation-specific templates or reference implementations are added.

Explicit product alternatives work with depth-first as well as interleaved search. Raw cursors retain the exact historical first proof and unconsumed continuation. Sequential source batches first visit historical plans, then spend the remaining shared allowance on extra product terms from productive plans. The extra phase cannot independently establish source refutation. Every additional search attempt remains charged; no search bound increases.

## Validation and unsuccessful attempts

The final isolated executable and affected suites build with `-Werror -j1`. All 383 selected tests pass:

| Suite | Passed |
| --- | ---: |
| Djinn | 146 |
| Integration | 187 |
| Public API | 38 |
| Focused CLI: rank-N, streaming, behavior, graph, selection, parsing and rendering | 12 |

The full 11-case public kinded-source matrix passes: 11 one-shot and 11 named-`where` exact GHC compile/execution replays, 11 actual-False controls and the invalid-kind negative. The earlier root's seven-suite 1,276-test result belongs to its previous source snapshot; it is not a full-suite result for this patch.

The focused baseline fails six of eight raw-proof actions; the candidate passes all eight. The first public candidate passed the original query but failed two unit tests: an exact result-count assertion and a real regression where product alternatives consumed the cutoff before a later historical plan. Deferring the extra grammar fixes that regression. The second public attempt retained two test expectation mismatches for unused binders; the final tests normalize them and assert all nine specific historical combinations, as well as mixed application products. The first focused harness's package-ambiguity failure is also retained.

The first broader regression controller accidentally selected zero CLI tests and returned success. It does not establish CLI coverage. A separate corrected run lists and requires exactly 12 distinct tests, then requires all 12 to pass. The incomplete initial selection and corrected terminal receipt are both retained; the successful integration/API/matrix gates were not repeated.

Source and runtime integrity checks pass in the final receipts. The integrated files match their captured hashes exactly; every other captured source matches the root after newline normalization. Tests were run in the isolated checkout before this verified transport, not rerun in the root directory.

## Evidence and remaining work

The [portable archive](../../test-church/receipts/product-alternatives-acceptance-2026-09-13.zip) and [per-member manifest](../../test-church/receipts/product-alternatives-acceptance-2026-09-13.json) retain the source snapshots, commands, public outputs, exact replay fixtures, final suite output, original historical-combination diagnostic and failed attempts. Archive SHA-256: `ace1aea8f4863e8c1e76d4f02106715d0d5ef84a393ec6178b00ed632af87f4d`.

This adds public Haskell product acceptance; it does not add a Church behavior-ledger cell or establish native Lean behavior. Next, validate the corresponding Djex dependency in Leant, including exact displayed-term kernel replay and False controls. Exference kinded execution and contextual Lean universes remain independent obligations in the [delivery plan](2026-09-13-synthesis-delivery-retriage.md).
