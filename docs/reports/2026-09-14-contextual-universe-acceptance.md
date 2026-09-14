# Contextual Type universes and intrinsic unit construction: acceptance

Leant preserves exact `Type` binder universes through contextual synthesis, including named universes, selected callbacks, shadowing and normalized `max`. Djinn, Exference and Both pass all 63 public cells for the seven specifications, with 42 exact Lean kernel replays and 21 actual-False controls. The corresponding Djex change constructs intrinsic unit values, including when an ordinary polymorphic application leaves the argument type flexible.

## Behavior and implementation

An accepted contextual signature is:

```lean
∀ (α : Type), [ContextProduction.Dictionary α] →
  ∀ (γ : Type 1), (∀ (β : Type), β → α) → γ → α
```

The callback must select an admissible `Type` argument despite the surrounding `Type 1` binder. Exference now constructs `Unit` and `Unit.unit` for this application. The synthesis environment supplies the dictionary declaration, without a reference implementation or a global provider supplying this witness. The separately checked reference uses another valid implementation.

Exact contextual forall domains and their lexical universe parameters survive parsing, preparation, graph opening and rendering. Bounded normalization handles represented zero, successor, parameter and maximum levels. Selected monotypes are checked against their original binder's universe; boxed unit, pairs and triples retain their type metadata through direct rendering.

Structurally valid but inadmissible selections are recorded as candidate rejections. Search charges each rejected or duplicate raw slot and continues within the original bound. Unknown owners, malformed graphs and conflicting metadata remain fatal integrity errors. A rejected candidate cannot justify an impossibility claim.

The Exference defect was below the source-level choice pool: known empty tuples were excluded from tuple introduction, and a flexible argument had no intrinsic unit constructor. The repair admits empty boxed tuples in both dispatchers and appends a unit-construction alternative after existing provider/function choices for flexible type-variable goals. Its unifier updates the persistent scope and pending evidence before completing the hole. Choosing a concrete type through this intrinsic constructor carries the existing weak-match cost. When the exact reserved nullary unit constructor is already in the environment, both dispatchers retain the existing constructor lane and its supplied rating instead of adding an intrinsic duplicate. Rigid variables remain rigid, and the proper-kind guard on visible type choices remains intact. Search limits are unchanged.

## Acceptance evidence

| Gate | Result |
| --- | --- |
| Strict native and Haskell builds | Pass with `-Werror` and one build worker. |
| Complete native suite | All 746 tests pass. |
| Focused contextual source/renderer tests | All 78 pass, included in the native suite. |
| Private Exference engine suite | All 100 pass, including intrinsic unit in an empty environment and refusal to inhabit an arbitrary rigid type. |
| Ordinary Exference suite | All 515 pass after updating the unit representation assertion; both the returned term and the loaded constructor are independently type-checked. |
| Contextual universe public matrix | 7 specifications × ordinary/named-`where`/False × Djinn/Exference/Both: 63 cells, 42 exact kernel replays and 21 False controls. |
| Direct renderer replay | 10 definitions, 10 payload assertions and 2 wrong-result controls; 22 empty recorded axiom inventories. |
| Existing contextual constructors and strict binders | 27 + 15 public cells; exact original-signature replay and False controls. |
| Haskell intrinsic unit | Three specifications through ordinary/named-`where`/False Exference entrances, including a local rank-N consumer and a pair of units; six exact GHC replays and three False controls. |
| Haskell extended Exference behaviors | All 13 operations pass at the unchanged default bounds. |

Public success requires the displayed candidate's own typed origin and exact renderer alternative. Both-mode output retains its producing engine. The public contextual API collects incrementally; ordinary and behavioral search policies do not establish a separate batch API. Each accepted replay checks the full original signature, and the independent reference never enters the synthesis provider inventory.

## Failed attempts and evidence preservation

Earlier attempts exposed reserved Lean identifier syntax, fixture binder identity mistakes, candidate-local universe rejection being treated as fatal, and the two Exference unequal-universe misses. Appending unit to the type-choice pool failed its focused regression; that experiment was removed before the successful constructor repair. Build logs and changing runtime hashes establish that its failure was not due to stale executables.

The first complete native suite run passed 691 of 746 tests. All 55 failures referred to the declared `djex-fake-z3` helper being absent from the controller's `PATH`. The corrected controller verifies the already-built helper's path and hash and reruns all 746 tests successfully on the same production source and binaries. The earlier successful public and private-engine receipts retain their original identities.

The first ordinary Haskell suite passed 514 of 515 tests: the old test demanded a named unit constructor even when the valid intrinsic empty tuple was returned. The revised assertion accepts precisely those two forms and checks both the returned expression and the loaded constructor against the parsed unit type. Two intervening test-only compilation failures are retained. Native production sources and runtime identities were unchanged by this fixture correction.

The subsequent Haskell behavioral gate exposed a production regression: `maybeEither` checked 256 candidates, all false, while the other 12 extended operations passed. The new flexible-unit branch had zero construction cost. Neither the exact-match nor weak-match cost alone restored the public behavior. The bounded private comparison still found the witness at indices 218 and 219. Public-boundary instrumentation exposed the implicit built-in unit constructor, and avoiding the duplicate intrinsic path restored the original public behavior without enlarging the window. Because this changes production search ordering, the final source snapshot receives fresh focused, Haskell, native public and full-native checks; the earlier passes retain their original snapshot identity.

The [complete archive](../../test-church/receipts/contextual-universe-acceptance-2026-09-14.zip) retains the distinct terminal attempts, source snapshots, controllers, public inputs, exact replay artifacts and helper-failure classification. The [manifest](../../test-church/receipts/contextual-universe-acceptance-2026-09-14.json) records archive and member hashes. Executables are identified by hashes and excluded from the archive. Source transport is checked against the producing checkout, allowing only newline normalization for already-integrated files.

## Remaining scope and next priorities

This closes the contextual binder-universe increment (2a.1). It does not establish higher-universe class/nominal parameters or nonzero constant selections, selected polymorphic types, arbitrary contextual `Sort u`/`Prop` binders, or dependent term binders. Those restrictions remain explicit. The next source capability targets a query that forces a selected polymorphic type. Promote the smallest nominal-universe prerequisite if that query needs it; broader class/provider support remains staged around declaration signatures, selected level vectors and identities that distinguish two instantiations of one declaration.

Exference's explicit Haskell kinded-source execution remains guarded. The focused Lean Djinn `length` diagnosis precedes integer indexing; extrema stays a bounded witness-trace investigation, and the unsuccessful reduction variants remain paused. The [latest priorities](2026-09-14-synthesis-next-priorities.md) track these independent obligations. The Church ledger remains 94 historical acceptances, 23 attempted cells without indexed acceptance and 43 unindexed cells; this release does not change those counts or imply arbitrary synthesis completeness.

## Published source and archive identity

The native integration pins Djex `66b3212be9e5849cc8398ef9de67837e2e0e276f`. The final transport record verifies all nine native files byte-for-byte and 406 compiled source files after newline normalization. All four final release controllers are terminal passes, and their recorded source and executable hashes were checked again before packaging.

Archive SHA-256: `8f88bdac10292cd3bff2116a49860575dbbcbbda41e07a37581d5969cc98428d`; 87,248,770 bytes; 15,900 members. The archive includes the final transport record and verifier, with the exact gate receipt hashes.
