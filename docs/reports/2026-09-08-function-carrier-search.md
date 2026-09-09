# Exference composes supplied folds with function carriers

Canonical Haskell Exference now synthesizes the supplied tree accumulator at
its original limits, while retaining the complete 13-operation extended Church
behavioral corpus. The [receipt](https://github.com/VladimirReshetnikov/Djex/blob/main/test-church/receipts/function-carrier-search.json)
and [evidence archive](https://github.com/VladimirReshetnikov/Djex/blob/main/test-church/receipts/function-carrier-search.zip)
preserve the final source, exact candidates, independent replays, complete-suite
results and unsuccessful experiments. This is a bounded Haskell delivery within
priority 2. Native Lean integration and the wider priorities 2–4 remain open.

## Search change

The [earlier trace](2026-09-08-tree-carrier-retriage.md) showed that Exference
already constructs the useful `s -> s` carrier branch, but its old estimate
prunes that branch before exploring it. Introducing a function binds parameters;
it does not require constructing values of their parameter types.

The new estimate charges the introduction action and residual result type when
the arrow goal, its lexical term bindings and its local constraint parameters
contain no `forall`. If any of those are polymorphic, the existing estimate
remains in place: even a monomorphic result can require impredicative use of a
polymorphic local parameter. Existing `ContinueForallIntroduction` handling is
also retained. The exported type-complexity function and numerical settings
are unchanged.

This rule does not recognize tree names, operation names or reference terms.
It preserves search alternatives, provider inventories, unification, checking,
candidate windows and step/queue limits. Its scope follows the types of the
actual goal and visible assumptions.

Two broader experiments were rejected. Discounting all arrow goals accepts the
tree but times out in the existing Church branch-composition regression at
180 seconds. Restricting the discount to the goal's type alone also accepts the
tree, but Church composition finishes with 256 false candidates and no match.
Including the lexical context retains both constructions. These failures and
their exact source snapshots remain in the archive.

## Accepted tree behavior

The requested signature is unchanged:

```haskell
forall a s. (s -> a -> s) -> s -> Tree a -> s
```

Search sees only the datatype, its constructors and the generic `foldTree`
signature. In the final 1,024-candidate pool, indices **160 and 556** satisfy all
16 observations. Both have the following composition, with names simplified
here for readability:

```haskell
\step seed tree ->
  foldTree (\value state -> step state value)
           (\left right state -> right (left state))
           tree seed
```

The exact typed expressions and graphs are archived. All 1,024 candidates are
independently compiled under the original full signature and executed; all
1,024 contradictory controls reject. All eight oracle controls pass. Search
retains 100,000 steps and a queue cap of 1,024; independent replay retains its
60-second guard. Source, library, executable, input and process-capture
integrity checks pass. This establishes the recorded finite observations, not
universal semantic equivalence or completeness of inhabitation search.

## Regression and fixture changes

| Check | Final evidence |
| --- | --- |
| Strict builds | The complete selected canonical targets and affected fixture rebuilds pass with `-Werror`. |
| Canonical regressions | **2,309 tests in 15 complete suites pass across the recorded runs.** Fourteen suites pass together; the entire 436-test Length suite passes after its test-only lifecycle timing repair. The sole source difference before that rerun is `synthesis/test-length/Spec.hs`; engine source and helper executable hashes match. The earlier full run remains marked failed. |
| Signatures | All **350 signatures in each Haskell engine** synthesize and pass the corpus's independent compiler check. |
| Extended Haskell Exference behavior | All **13 operations**, all **28 oracle controls**, and the actual False query pass in a fresh run. The window remains 256, step limit 100,000 and queue cap 8,192. Exact implementations compile and execute at their original full signatures. |
| Supplied recursors | All nine tests pass, including the new typed tree accumulator, map/append/generalized length in both engines, and the uninhabited empty-input cases. |
| Native Lean | Not run for this change. Older native results remain tied to their recorded dependency revisions. |

The permanent recursor fixture now shares each polymorphic observation predicate
across its candidate pool. Repeating all observations in each candidate's test
expression previously triggered a GHC 9.12.4 bytecode breakpoint-index panic.
Factoring the predicate preserves the full signatures, observations, contradictory
controls and deadline. The tree regression uses exact typed rendering. Existing
Exference list tests retain their original independently compiled compatibility
expressions; their separately exposed typed-renderer limitation remains frontend
work and is not claimed fixed here.

The CLI elaboration regression now checks every actual repair, including its
distinct original observation slot, own graph, compilation failure, successful
retry, exact displayed expression/definition, independent replay and rejection
by the opposite predicate. It still enforces the eight-candidate observation
window. Search ordering may change the number of repairs without changing that
contract.

Two Length lifecycle fixtures had assumed that a worker would reach the target
stage within a 400 or 500 ms shared startup/work budget. Both short-budget cases
remain. Separate controls with a 3,000 ms shared budget require entry into the
blocked query or callback; their per-query allowance remains longer than the
shared deadline. Query admission/hang events, poisoning, callback completion and
workspace removal remain checked. This separates early-expiry safety from
required stage coverage without changing production deadline behavior or any
synthesis limit. The complete 436-test suite passes after this repair.

## Integration and remaining scope

Leant still commits Djex `4a4ed0fc`, with working dependency `63a23f58` under
integration. This milestone does not advance that pin. Next, integrate the
accepted canonical source and require the complete native unit and affected
kernel-replay matrices, including the recurring layered-provider deadline.
The new Haskell result does not change any previously recorded Lean tree cell.

The [delivery priorities](2026-09-08-tree-carrier-retriage.md) retain Haskell
Djinn and Lean Djinn/Exference/Both tree acceptance, exact Haskell frontend output,
contextual evidence transport, and the full **13 extended plus all 19
explicit-default operations** across all required engines. Supplied defaults
or inhabitance assumptions remain the Lean contract for partial source
operations. The wider implementation goal remains active.
