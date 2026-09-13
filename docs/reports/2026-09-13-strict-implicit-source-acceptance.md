# Strict-implicit Lean binders through contextual synthesis

Leant now retains strict-implicit type binders through contextual source extraction, synthesis and rendering. The strict build and all **719 native unit tests** pass. The new live matrix passes **nine positive cases with independent Lean replay and six actual False controls** across Djinn, Exference and Both. The existing contextual constructor matrix also passes **21 exact positive replays and six False controls**.

## Problem and change

A query such as `∀ ⦃α : Type⦄, [Ctx.C α] → List Nat` previously failed contextual source admission. The caller's dictionary can supply a value through `Ctx.C.out`; the query should be able to construct a singleton containing that value. The accepted observations distinguish dictionaries carrying 7 and 11. The same visibility must survive inside a rank-N callback and nested dictionary scopes.

The Lean source serializer now records `.strictImplicit` explicitly. The contextual packet parser, source binder representation and renderer retain that distinction, including the displayed `⦃…⦄` lambda and signature binders. The change does not erase a strict binder to an ordinary implicit or explicit binder, change a dictionary selection, or widen the allowed type domains.

The contextual source packet remains restricted to its documented Type-0 fragment, explicit universe-zero constant selections and nondependent term arrows. Higher universes, general dependent binders and broader evidence transport still require separate work. This change is confined to Leant; the synthesis dependency remains the accepted Djex `c2d5530f6951a3b4b81a23372285902bc1ab35ee`.

## Validation and reproducibility

| Gate | Result |
| --- | --- |
| Original source-refusal baseline | Two live queries reach the exact contextual source refusal; their positive oracle modules compile. These are refusal evidence, not successful behavioral rejection controls. |
| Strict executable/unit build | Pass, with `--ghc-options=-Werror -j1`. |
| Focused source units | Eight pass: root and nested callback binders, both engines, streaming and batch preparation. |
| New strict-implicit live matrix | Nine positive exact replays and six actual False controls pass in the three native engine modes. |
| Complete native unit suite | 719 pass serially. |
| Existing contextual constructor matrix | 21 positive exact replays and six actual False controls pass. |

The new driver reuses the existing method, argument and nested-context cases, changing only their type-binder visibility. It retains 32 raw candidates, 20,000 search steps/choices and the 45-second query deadline. It checks actual provider inventories, source graph ownership, displayed strict introductions, exact complete types, behavior and empty implementation/proof axiom inventories. Reference implementations remain in separate oracle modules and never enter synthesis sessions. Both-mode receipts preserve the producing engine.

Validation ran in an isolated Leant checkout based on `8877db37859ee415334878483aa7565f0aab3990`, with the pinned Djex revision above and the five-file source/test overlay in the receipt. Frozen source and runtime identities were checked before and after the runs, and publication compares the tested source with the root checkout. The archive retains source snapshots, controllers, commands, output, exact replay modules and all unsuccessful baseline evidence. The first full-unit controller omitted the built `djex-fake-z3` helper from `PATH`; its failed run is retained, and the corrected controller supplies and hashes the helper. The first baseline parent controller failed to recognize the precise source-refusal diagnostic; the next controller checked the retained child receipt rather than repeating or relabeling it.

Run the new driver from the repository root after building:

```powershell
python -X utf8 -B test-context/run_strict_implicit.py --leant <built-leant.exe> --output dist-newstyle/strict-implicit/run-1
```

Use a fresh output directory. `--lean-runtime` and `--backend` select installations; `--engine` and `--operation` select diagnostic subsets. A subset is not full-matrix acceptance. The archive's `REPRODUCE.md` records the unit and contextual regression commands and source provenance.

The unchanged non-context Church signature and behavior matrices were not rerun for this binder change. This milestone adds no Church behavior cells: the historical ledger remains 94 acceptances, 13 attempts without indexed acceptance and 53 cells without indexed evidence. See the [delivery plan](2026-09-13-synthesis-delivery-retriage.md) for the remaining source/public-interface and behavioral obligations.

The [receipt](https://github.com/VladimirReshetnikov/Leant/blob/main/test-context/receipts/strict-implicit-source-2026-09-13.json) and [archive](https://github.com/VladimirReshetnikov/Leant/blob/main/test-context/receipts/strict-implicit-source-2026-09-13.zip) retain the validation evidence.

Archive: 6,382,227 bytes, 1,323 rehashed members, SHA-256 `fe42a148c063dd79328db5b612f4051f8bd5ba698d7c167d5a225569b76bc89b`.
