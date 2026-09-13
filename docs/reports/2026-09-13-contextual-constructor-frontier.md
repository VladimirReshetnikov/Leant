# Contextual constructor acceptance frontier

The expanded live matrix completes all 27 cases against one frozen working implementation: **17 of 21 positives pass exact kernel replay and all six actual False controls pass**. Four positive cases remain unaccepted. This is a diagnostic milestone, not release acceptance of the constructor repair, and it adds no Church behavior cells by association.

## Complete results

| Case | Djinn | Exference | Both |
| --- | --- | --- | --- |
| Singleton using the selected dictionary's method | Passed | Passed | Passed |
| Singleton from an argument, discovery disabled | Passed | Passed | Passed |
| Prepend the method result to a supplied tail | Bounded miss | Passed | Passed |
| Prepend an argument to a supplied tail | Passed | Passed | Passed |
| Wrap an argument singleton in `Option` | Passed | Passed | Passed |
| Construct a nested singleton list | Passed | Passed | Passed |
| Select the outer dictionary under a second dictionary scope | Source graph failure | Bounded miss | Source graph failure |
| Method singleton with `where False` | Passed control | Passed control | Passed control |
| Argument singleton with `where False` | Passed control | Passed control | Passed control |

Each positive uses its original full type and finite observations. All 27 separately supplied reference preflights pass. Each of the 17 emitted implementations passes independent full-type/behavior kernel replay with empty axiom inventories. The controls require actual falsified assertions, no displayed candidate and no inconclusive observations; a mere process exit cannot pass them.

The driver is [run_constructors.py](https://github.com/VladimirReshetnikov/Leant/blob/main/test-context/run_constructors.py). It records each failed case and continues through the complete matrix. Its defaults retain window/verification 32, steps/choices 20,000, command deadline 45 seconds, method-discovery cap 1, library/classical search disabled, and a separate 180-second process guard. Argument-only cases disable provider discovery. References never enter live search sessions.

## What the failures establish

The Djinn tail case is:

```lean
∀ (α : Type), [Ctx.C α] → List Nat → List Nat
```

The observations require prepending 7 or 11 from the caller's dictionary while preserving the supplied list. The run reaches the original 32-result bound after four verified but falsified observations, with zero inconclusive results. Provider discovery selects the actual `Ctx.C.out`. The displayed debug candidates include identity, prepending zero/one and the empty list. Thus source admission and ordinary constructor typing work; the required composition is absent from the observed prefix. This does not establish impossibility or justify increasing the limit.

The nested-context case is:

```lean
∀ (α : Type), [Ctx.C α] → ∀ (β : Type), [Ctx.C β] → List Nat
```

Its two observations exchange the outer/inner payloads and require the outer one. Djinn and Both stop with `ambiguous lexical Given type instantiation` during source graph reconstruction. Exference verifies and falsifies seven candidates, with no inconclusive observations, before its step/queue limits stop search. Those are distinct failure boundaries.

Source inspection identifies an evidence obligation for the Djinn failure: `SourceEvidence.hs` checks each conditional helper's source scheme and dictionary obligations, but its erasure drops the helper's selected type vector. `SourceGraph.hs` then attempts to infer context-only parameters from available Givens and deliberately rejects ambiguous choices. Preserving the proof's actual selection through reconstruction is a candidate repair; this inspection alone does not prove that it fixes the live case. Removing the ambiguity guard would discard required evidence and is not an acceptable repair.

## Completed work and rejected experiment

The working implementation now reconciles an intrinsic constructor with a discovered provider only when their complete source packets agree, including universe arguments. A conflicting packet is refused. Its unit regression passes. A canonical abstract-datatype regression checks typed dictionary/constructor composition and observes singleton/tail behavior with competing zero/successor values; the reduced fixture passes, so it does not yet reproduce the native tail miss.

The first complete native unit run finishes **707/709**, with two existing source-wiring assertions still expecting the old unconditional constructor argument in `Main`. Updating those assertions for staged admission and constructor-only fallback makes both focused tests pass after a strict rebuild. A fresh unfiltered 709-test pass remains required; the separate results are not relabeled as one passing full run.

An experiment placed specialized contextual plans before unspecialized plans. The complete matrix above ran against that variant after a strict build. It did not repair either Djinn failure and has been reverted. The archive preserves the exact experimental sources and executables' identities; its results must not be presented as fresh validation of the restored working source. The restored source needs rebuilding before further live acceptance.

## Evidence and next action

The [receipt](https://github.com/VladimirReshetnikov/Leant/blob/main/test-context/receipts/contextual-constructors-expanded-diagnostic.json) and [archive](https://github.com/VladimirReshetnikov/Leant/blob/main/test-context/receipts/contextual-constructors-expanded-diagnostic.zip) retain 543 artifacts: frozen source inputs, commands, captures, oracle/replay modules, strict-build output and a checked manifest. The archive is 2,040,649 bytes, SHA-256 `3fd965de955fb444193c63c2b53c53a5990f674b5a34921dcc2b2c92d2a71be8`. Runtime binaries are recorded by identity rather than redistributed. All 71 owned child processes exit zero; four cases nevertheless fail the acceptance criteria. All recorded source/input hashes and exact replay files remain unchanged through execution and packaging.

The [delivery priorities](2026-09-12-synthesis-after-contextual-constructor-probes.md) remain active. Next, capture the exact prepared native tail request, including provider assignments, to reduce its discrepancy from the passing canonical fixture. For nested dictionaries, preserve actual type selections and lexical scope through the checked source graph; distinguish that work from Exference's bounded search miss. Then rerun the full constructor matrix, complete native unit suite and affected canonical/native regressions before publishing the implementation or promoting the dependency.

Missing Church behaviors, remaining named-`where` one-shot entrances, kinded binders and broader provider/dictionary/universe evidence remain required. The full behavior target remains 160 operation/mode cells, with controls and replays additional. Both repositories' production code changes remain uncommitted at this diagnostic checkpoint.
