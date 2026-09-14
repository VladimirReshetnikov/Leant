# Intrinsic unit construction with the existing constructor path preserved

Djex's Exference engine can construct unit in an empty inventory, including when applying a local rank-N function leaves a flexible argument type. It preserves the existing constructor path when the environment already supplies the reserved nullary unit constructor. The final Haskell release passes all 13 extended Church operations, 515 ordinary Exference tests, 100 private engine tests, and three public intrinsic-unit specifications with exact GHC replay and False controls.

## Implementation and regression diagnosis

The empty-inventory engine now handles both a concrete unit goal and the signature:

```haskell
forall r. (forall a. a -> r) -> r
```

A matching implementation applies the supplied function to `()`. Known empty tuples previously missed tuple introduction, and a flexible argument had no intrinsic nullary constructor. The repair adds those construction paths without expanding the visible type-choice pool or weakening rigid-variable and proper-kind checks. Flexible selection updates the persistent substitution and pending evidence before completing the unit hole; it carries the existing weak-match heuristic cost.

The first prototype passed the contextual Lean source gates but regressed Haskell `maybeEither`: its public behavioral query checked 256 candidates, all false. A fresh build of the published baseline passed the same query at the same bounds. Changing only the new branch's cost did not recover the public result.

A bounded private-engine comparison located the baseline witness at candidate 218, step 1,736. The weak-match prototype still found it at candidate 219 in an empty inventory. Instrumenting the public query exposed the missing distinction: the public Exference environment includes built-in constructors, including `()`, although the fixture supplies no ordinary implementation declarations. The new intrinsic route duplicated an existing constructor path. The diagnostic also records the frontend's alpha-renumbering of the source binders; it does not infer that private and public requests are identical from their printed signatures alone.

The final repair reuses the existing search lane when the inventory contains the reserved unit constructor with exactly its nullary, unconstrained unit type. It keeps that binding's supplied rating and avoids the extra intrinsic branch in both dispatchers. An ordinary named provider returning unit does not suppress syntax introduction. When the constructor is absent, intrinsic unit remains available. The focused witness regression checks both an empty inventory and one containing the built-in unit constructor.

The public `maybeEither` query again records one success and 255 falsifications, with no evaluation errors or timeouts. The displayed implementation independently compiles and executes with GHC. The window remains 256, the step limit 100,000 and the queue bound 8,192. No rejected candidate receives a refunded slot.

## Acceptance evidence

| Gate | Result |
| --- | --- |
| Strict executable/test builds | Pass with `-Werror` and one build worker. |
| Ordinary Exference suite | All 515 tests pass. |
| Private Exference suite | All 100 tests pass, including the empty-inventory unit/rigid-type controls and bounded `maybeEither` witness regression. |
| Public intrinsic-unit specifications | Unit, a local rank-N consumer, and a pair-of-units argument; ordinary/named-`where`/False entrances, six exact GHC replays and three False controls. |
| Extended Haskell Exference behaviors | All 13 operations pass with independent GHC execution, oracle controls and the actual False query. |
| Focused native contextual source/renderer tests | All 78 pass on the final source. These are not full native release acceptance. |
| Source/runtime integrity | Producing source snapshots and runtime hashes remain unchanged over the recorded gates. Publication transports the checked code rather than claiming an in-place build of the root checkout. |

The [acceptance archive](../../test-church/receipts/intrinsic-unit-acceptance-2026-09-14.zip) contains complete producing source snapshots, controllers, public inputs and exact replay artifacts, the private-engine gate, and both bounded diagnostic comparisons. Its [manifest](../../test-church/receipts/intrinsic-unit-acceptance-2026-09-14.json) records archive and member hashes. Executables are identified by hashes and excluded. The diagnostic trace instrumentation is retained in its own source snapshot and is absent from the final implementation.

The earlier [prefix regression archive](../../test-church/receipts/contextual-universe-prefix-retriage-2026-09-14.zip) and [weak-match experiment archive](../../test-church/receipts/contextual-universe-weak-match-retriage-2026-09-14.zip) preserve the unsuccessful attempts. Their selected diagnostic scope differs from this acceptance bundle. The earlier unit test's representation-only assertion was replaced with independent checks of the returned term and loaded constructor; its failed attempts remain recorded.

## Remaining integration

Leant's full contextual public matrix, complete native suite and affected constructor/binder regressions are separate gates on this final source. Its dependency pin remains at the last accepted native revision until those gates finish. The previous prototype's 63 public cells and 746 native tests are evidence for that earlier source snapshot.

Class/nominal/provider universe selections, contextual polymorphic selected types, Exference explicit Haskell kinded-source execution and the remaining Church behaviors are still open. See the [delivery plan](2026-09-13-synthesis-delivery-retriage.md). This milestone restores an existing historical behavior and adds a general construction rule; it does not change the Church ledger counts or establish arbitrary synthesis completeness.
