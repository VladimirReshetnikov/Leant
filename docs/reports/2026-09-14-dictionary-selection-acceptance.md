# Dictionary-qualified polymorphic selection: native acceptance

Leant now preserves source evidence when a polymorphic type selection is followed by a dictionary application. Together with Djex's [scoped quantified-choice repair](2026-09-14-contextual-polytype-acceptance.md), this lets a qualified local consumer accept a supplied polymorphic payload, including one inside a nominal wrapper, through Djinn, Exference and Both.

This milestone integrates Djex `9a2d59d958a60ff3b6899697a60b6985a5cf73a3`. Exference explicit Haskell kinds, integer indexing and the original simultaneous two-universe construction query remain separate obligations. The subsequent [Haskell proof-prefix repair](2026-09-14-contextual-proof-cutoff-acceptance.md) resolves the observed default timeout; it is a separate backend milestone, not part of this native dependency snapshot.

## Failure and repair

The discriminating example has this shape, where `P` is either `∀ β : Type, β → Nat` or `Box (∀ β : Type, β → Nat)`:

```lean
∀ A R : Type, [Dictionary A] →
  (∀ α : Type 1, [Dictionary A] → α → Witness α R) →
  P → Witness P R
```

The local consumer must receive the selected type, outer dictionary and supplied payload. The result type `R` is abstract. Observations distinguish dictionary tags 7/11 and payload results 37/53, so accepting a term merely because it has a compatible printed type is insufficient. Reference witnesses validate the specification independently and are not synthesis providers.

Before repair, Leant could lose expected-result or actual-argument metadata while crossing the intervening dictionary application. The selected forall then lacked the source evidence needed for reconstruction. `ContextSource.hs` now uses explicit structural path steps for arrow domains, arrow results and context bodies. Dictionary application forwards its hints through the context-body step, which only traverses a nonempty discharged dictionary telescope. Scope, visibility, universe checks, typed-graph ownership and failure-path work accounting remain in force. Three focused tests exercise expected-result recovery, actual-argument recovery and rejection of an incorrectly sized universe.

The native Djinn example also exposed a separate backend omission: the contextual specialization vocabulary excluded the required supplied forall. The pinned Djex repair adds closed quantified subtrees after the existing monotype prefix. Its independent kind/Given checks and candidate/assignment caps remain unchanged. The backend report records the real failing baseline, eight isolated variants and Haskell acceptance.

## Current acceptance

The [manifest](../../test-church/receipts/dictionary-selection-acceptance-2026-09-14.json) links the [complete native evidence archive](../../test-church/receipts/dictionary-selection-acceptance-2026-09-14.zip). It contains source snapshots, controllers, runtime identities, raw logs, exact generated Lean and independent replay records. Executable binaries are excluded. Every archive member was reopened and checked against its recorded hash.

| Gate | Result |
| --- | --- |
| Strict Haskell build and emitted Lean serializer | Pass, with `-Werror` for the native build. |
| Focused contextual/source tests | **98 pass.** |
| Complete native unit suite on the integrated Djex pin | **766 pass**, with one test worker and the pinned fake-Z3 build helper correctly placed on PATH. |
| Original dictionary example plus nominally wrapped payload, all three engines | **18 pass:** 12 exact empty-axiom Lean replays and six actual-False controls. |
| Lexical contextual regression matrix, all three engines | **27 pass:** 18 exact empty-axiom replays, three actual-False controls and six explicit higher-class-universe refusals. |
| Eight existing nominal/polymorphic families through the changed Djinn backend | **24 pass:** 16 exact empty-axiom replays and eight actual-False controls. |

The public total is **69 cells: 46 exact replays, 17 actual-False controls and six refusal controls**. The original dictionary and wrapped transfer cases retain their existing 20-second synthesis timeout, 4,096 search steps, 60 raw candidates, 1,024 queue bound and 120-second process guard. Each other family retains its recorded controller settings. Neither supplying a reference solution nor enlarging limits establishes these passes.

The 24-cell regression gate excludes the original `two_box_selections` query, which remains open. These affected gates do not establish that the earlier 72-public/105-regression milestone was rerun on this revision; that earlier acceptance retains its own source snapshot. No Church behavior-ledger cells close here.

## Harness maintenance and retained failures

The first combined controller is retained as **failed overall**. Its dictionary child passed all 18 cells, but its old 39-cell lexical matrix still expected higher-binder and some global-provider examples to be refused. Those expectations predated newer capabilities. The corrected lexical matrix has 27 cells and retains the six higher-class-universe refusals with the current diagnostic. Positive higher-binder and global-method capabilities belong to their existing specialized suites; global-provider acceptance is still engine/inventory dependent, and Djinn success does not establish Exference success.

The accepted dictionary child predates that harness maintenance. An explicit bridge verifies that every active imported helper definition, production implementation and runtime it used is unchanged; only unused standalone matrix/main definitions and refusal constants changed. The archive includes both harness snapshots, the bridge and the failed attempt. The corrected 27-cell gate, 24-cell Djinn gate and complete native suite use the final strict source snapshot.

Earlier [dictionary triage](../../test-church/receipts/dictionary-selection-triage-2026-09-14.json) and [backend acceptance](../../test-church/receipts/contextual-polytype-acceptance-2026-09-14.json) retain the pre-repair failures and prerequisites. The later [integration triage index](../../test-church/receipts/dictionary-integration-retriage-2026-09-14.json) recorded the full native suite as pending; this acceptance supersedes that status without rewriting the historical index.

## Reproduce

Build the native executable and tests against the committed submodule, then run the portable public gates into fresh output directories:

```powershell
cabal build leant:exe:leant leant:test:leant-synth-tests --ghc-options=-Werror -j1
$leantExe = (cabal list-bin leant:exe:leant).Trim()
python -X utf8 -B test-context/run_dictionary_selection.py --leant $leantExe --output dist-newstyle/dictionary-release/dictionary
python -X utf8 -B test-context/run_production.py --leant $leantExe --output dist-newstyle/dictionary-release/context
```

The archive retains the exact focused 24-cell selection, strict/serializer controller and full native launcher. That launcher resolves and hashes `djex:exe:djex-fake-z3`, verifies its PATH resolution, inventories all 766 tests and runs the existing test executable with `--num-threads 1`. Its source/runtime checks prevent a receipt from silently covering a different implementation. External Lean REPL metadata is included under explicit archive paths; runtime hashes identify the toolchain without bundling its binaries.

Continue with the [current priorities](2026-09-14-synthesis-next-priorities.md). Higher-universe classes, selected global providers, finite vocabulary caps and broader Church behaviors require their own evidence. This scoped release does not establish arbitrary rank-N/impredicative synthesis completeness.
