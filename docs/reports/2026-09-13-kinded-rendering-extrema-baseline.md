# Kinded-source rendering and completed extrema baseline

This checkpoint fixes the concrete Haskell source-rendering refusal for explicit ground-kind binders and completes the representative extrema baseline. It does not remove the kinded-query execution guards or add a Church synthesis acceptance. The behavior ledger now records **94 historical acceptances, 23 attempted cells without indexed acceptance and 43 cells without indexed evidence**, out of 160.

## Renderer change and validation

`standaloneSourceExpression` now obtains the binding-pattern name from a binder such as `(f :: * -> *)`, while preserving that binder's complete kind annotation in the original expected signature. The implicit-scope calculation accepts the same star/arrow/parenthesized ground-kind language as the checked source converter. Unsupported polymorphic kinds are still refused instead of silently omitting their free kind variables.

The [rendering fixtures](https://github.com/VladimirReshetnikov/Djex/blob/main/test-church/source_scope_rendering.hs) cover higher-kinded identity, a vacuous higher-kinded binder, a nested callback, implicit outer quantification, two higher-kinded parameters, successive leading foralls, a constrained outer scope and nested shadowing. The actual emitted module compiles with GHC and executes to:

```text
(Just 17,23,31,Just 41,Just [43],47,Just True,[True])
```

Four additional scope/rejection checks pass. A separate module applies the vacuous higher-kinded parameter to `Int`; GHC rejects it for the kind mismatch. This negative case matters because the binder's kind cannot be recovered from its unused body occurrence. The old renderer's explicit refusal was independently reproduced.

The Djex root checkout passes `cabal build djex:lib:djex --ghc-options=-Werror -j1`, both private rendering-driver builds, actual positive compilation/execution and the negative GHC check. The captured root source and runtime hashes remain unchanged during validation. This is a focused renderer validation, not a new full engine or native suite run. The Leant dependency pin stays at its last tested native revision.

The first two prototype runs fail because of the hand-written nested rendering fixtures: the first lacked a usable expected type at the nested visible type abstraction, and the second annotated the lambda body instead of the whole lambda. Those attempts are retained separately. The corrected fixtures explicitly annotate the complete nested lambda. They are test inputs, never supplied synthesis providers.

### Reproducing the focused rendering check

From the Djex root, build the library as above and create a fresh output directory. Compile `test-church/source_scope_rendering.hs` together with the actual `src/Language/Haskell/Djex/HaskellSrc/Scope.hs` and `exference/src-frontend/Language/Haskell/Exference/HaskellSrcUtils.hs` using `cabal exec -- ghc -i -package djex -package haskell-src-exts -Wall -Werror`, supplying distinct `-odir`, `-hidir` and `-o` paths under that output directory. These explicit home modules let the fixture exercise private rendering code without exposing it as public API.

Run the resulting driver with the fresh fixture directory as its sole argument. Compile and execute its `Positive.hs`, checking the tuple above, and require `ghc -fno-code WrongKind.hs` to fail with the kind diagnostic. The archive retains the complete executable controller, actual commands, generated modules, output and source snapshots for the root and all three prototype attempts.

## Ten-cell extrema baseline

Both `maximumBy` and `maximumOn` miss in all five modes at their original settings. Haskell Djinn reaches its 500,000-choice limit; Haskell Exference checks its 256-candidate window. Each Lean query uses its original 90-second command timeout. A bounded miss is not an impossibility result.

| Mode | `maximumBy` | `maximumOn` |
| --- | --- | --- |
| Haskell Djinn | 2,255 checked: 2,184 falsified, 71 compilation errors, no evaluation timeouts | 1,846 checked: 1,806 falsified, 40 compilation errors, no evaluation timeouts |
| Haskell Exference | 256 falsified; no compilation errors or evaluation timeouts | 256 falsified; no compilation errors or evaluation timeouts |
| Lean Djinn | 651 falsified, zero inconclusive | 842 falsified, zero inconclusive |
| Lean Exference | 727 falsified, zero inconclusive | 623 falsified, zero inconclusive |
| Lean Both | 472 falsified, zero inconclusive | 319 falsified, zero inconclusive |

All five actual False controls pass, as do the independent oracle controls/preflights. Both-mode success is not substituted for individual-engine acceptance; in this baseline neither mode produces an accepted implementation.

The baseline archive retains the wrong-runtime native attempt as aborted and excluded, and the later interrupted controller with its source/runtime integrity audit. A consolidated native receipt selects only completed rows from the interrupted run and the two completed recovery runs. Every selected row points to its original receipt member, hash and row index. The interrupted parent is not relabeled as a completed run. Both repos' generated ledgers index the four Haskell and six Lean attempts from these exact members.

## Construction diagnosis after the timeout

The earlier fixed-carrier diagnostic admits `a -> a` after a local carrier proposal change, but times out at 120 seconds. Its independently supplied witness type-checks and passes all 30 observations, while remaining outside the search environment.

A new isolated interpreter charges every expression evaluation and function application against a shared per-observation budget of 50,000 operations. The old interpreter limited recursive depth, which did not bound total evaluation work. With the new evaluator, the unchanged search reaches its full **500,000-choice limit and 47,684 checked proofs** in a completed run. It finds no match, with **67 evaluation-fuel failures recorded as inconclusive**. The witness passes all 30 observations using 4,194 evaluation operations in total.

The first completed global-fuel run records 3.21875 CPU seconds overall, including 0.625 seconds in candidate evaluation. A separate prefix-observation trace traverses the same 47,684 proofs and records the best prefix as six of the 30 ordered observations, at proof index 13,646. That prefix count is a diagnostic tied to fixture order, not a quality score or partial acceptance. The candidate folds the supplied default through comparisons; it is not the control witness. The trace retains the actual term.

These results replace a whole-test timeout with bounded evidence. They do not prove that the 67 inconclusive candidates are incorrect, or establish that increasing search limits would suffice. The next construction change still needs a trace explaining a missing or delayed derivation. Coordination between carrier and comparator instantiations remains a separate public-plan hypothesis. The carrier prototype remains unpublished.

## Portable evidence and remaining work

The same manifests and archives are present in both repos:

- [Renderer manifest](../../test-church/receipts/source-scope-rendering-2026-09-13.json) and [archive](../../test-church/receipts/source-scope-rendering-2026-09-13.zip): root validation, baseline refusal and all prototype attempts.
- [Extrema baseline manifest](../../test-church/receipts/extrema-baseline-2026-09-13.json) and [archive](../../test-church/receipts/extrema-baseline-2026-09-13.zip): all ten cells, controls, interruptions, sources and consolidated native selection.
- [Construction diagnostic manifest](../../test-church/receipts/extrema-construction-diagnostics-2026-09-13.json) and [archive](../../test-church/receipts/extrema-construction-diagnostics-2026-09-13.zip): timed-out fixed-carrier attempts and global-fuel traces. Temporary private-module exposure in the old diagnostics was restored before renderer validation.

The public kinded-source path still needs exact lexical kind ownership through session expansion and local/nested source checking. The original published parser still refuses the public kinded queries; the unpublished request prototype retains explicit execution guards. Renderer success does not bypass those requirements. Lean universe support stays an independent milestone, followed by integer indexing and trace-directed length work. See the [delivery plan](2026-09-13-synthesis-delivery-retriage.md) for the full obligations.
