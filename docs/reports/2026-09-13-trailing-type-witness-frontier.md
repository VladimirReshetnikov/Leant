# Remaining selectors and a trailing-type rendering repair

Both Haskell engines accept the supplied-default `last` and `atKey` fixtures
at their original limits. The first matching Lean run accepts five of six
positives: Djinn's `last` reaches its 90-second command deadline without an
accepted output. Its generated candidate 45 identifies a concrete rendering
boundary. A bounded renderer change then passes all six positives and all
three False controls in a fresh working-source run. Isolated production
validation subsequently passed its strict build but failed two of 707 unit
tests: an exact rendering-list assertion and a three-lane variant-count
assertion. Its later behavior and signature gates did not run. The renderer
change is not yet published; see the [updated re-triage](2026-09-13-synthesis-delivery-retriage.md).

## Completed behavior evidence

| Batch | Positive results | Controls and replay | Publication boundary |
| --- | --- | --- | --- |
| Haskell `last` and `atKey`, both engines | 4/4 | Four exact GHC replays; 24 observations for each `last`, 54 for each `atKey`; two actual False queries; six independent oracle controls; 26 owned processes exit zero. | Fresh frozen working-source behavior batch. Both Exference cells repeat historical acceptance; the two Djinn cells were previously unindexed. |
| Lean before the renderer change | 5/6 | Five exact kernel replays, three passing False queries, two oracle modules; all 16 owned processes exit zero. | Djinn `last` fails the acceptance criteria despite its process exiting zero. |
| Lean with the trailing-type fallback | 6/6 | Six exact kernel replays, three passing False queries, two oracle modules; all 17 owned processes exit zero. | Working-source behavior acceptance, not isolated production or full regression acceptance. |

All synthesized Lean implementations have empty axiom inventories. Only the
two exact `atKey` observer/proof declarations retain the documented dependencies
of `String.length`: `Classical.choice`, `Quot.sound`, and `propext`. Those
dependencies are not permitted on candidates or unrelated helpers. The ledger
adapter now checks this precise boundary; its new negative test brings the
complete ledger suite to 15 passing tests.

Haskell Djinn `atKey` finds its accepted implementation after 500 observations,
including 15 candidate-check errors. Its 180 same-candidate elaboration retries
are a separate counter. The three retained graph-present samples are repaired
and finally falsified; they do not classify all 15 remaining errors. The
accepted output passes exact full-type replay. Exference checks 67 candidates
for `atKey`; the `last` counts are 45 for Djinn and 15 for Exference.

The native fixture retains window/verification 65,536, choice budget 500,000,
Exference steps 100,000, interleave for Djinn, a 90-second command deadline and
a separate 900-second process guard. Both native batches freeze 437 source
files before their strict builds and retain unchanged source/runtime checks.
Haskell retains its established per-engine settings and freezes 328 sources.
No limit increase accounts for the successful rerun.

## Why the first Lean Djinn `last` failed

The failed query records 725 falsified assertions, zero inconclusive observations
and no accepted output before its command deadline. Search did generate the
same structural construction as the accepted Haskell implementation, at
candidate 45. Independent kernel checking of its exact two rendered variants
reports different failures:

```lean
-- Universe constraint failure: transporting the complete polymorphic f.
fun _ x f => f _ (fun a b _ => b a) (fun c _ => c) x f

-- Unresolved trailing type placeholder and dependent binder inference.
fun _ x f => f _ (fun a b _ => b a) (fun c _ => c) x (f _)
```

The first uses a polymorphic Church-list type at an instantiation whose Lean
universe is too small. The second avoids that transport but supplies too little
information to infer the trailing result type. Both kernel runs fail; their
error-recovery `sorryAx` inventories are rejected evidence, not accepted proofs.

A diagnostic copy using `f _root_.Unit` passes the complete original target,
observations and empty inventories. That manually directed check is not live
synthesis acceptance. The renderer follow-up independently produces the same
form in a fresh live query:

```lean
fun _ x f => f _ (fun a b _ => b a) (fun c _ => c) x (f _root_.Unit)
```

The live result passes after 44 falsifications, with no inconclusive observations.
The proposed rule offers a closed `Unit` witness only at the already selected
trailing local-instantiation sites, after inferred spellings. Explicit source
type applications and provider assignments are preserved. The existing
per-domain variant cap still bounds the combined proposals, and every proposal
requires kernel checking. This does not make Lean's universe hierarchy impredicative.

The two focused renderer tests pass: one retains the original variants and
adds the captured working form; the other prevents defaulting an explicit source
type argument. A separate checkout at committed Leant `d2e5473`, with clean
Djex `c1ad560e`, contains only the renderer change and these tests. Its complete
native unit suite, paired behavior matrix and both 350-signature replay corpora
must pass before code publication. The unrelated contextual-constructor work
remains outside that isolated change.

## Retained receipts

- [Haskell batch](https://github.com/VladimirReshetnikov/Djex/blob/main/test-church/receipts/supplied-default-last-atkey-haskell-2026-09-13.json): 420 archived artifacts, SHA-256 `a6af06e43c00b1bbb3ce2bc7b51776fba64b951b5bebef8e820aa609532b6655`.
- [Native five-of-six batch](https://github.com/VladimirReshetnikov/Leant/blob/main/test-church/receipts/supplied-default-last-atkey-native-2026-09-13.json): 503 archived artifacts, SHA-256 `ee69c04a246435d6ee212d5164840b6615a2509c0682f1dcfc700095dd8f9f4f`.
- [Kernel diagnosis](https://github.com/VladimirReshetnikov/Leant/blob/main/test-church/receipts/trailing-type-witness-diagnostic-2026-09-13.json): 12 artifacts, including the unchanged rejected variants and the separately labeled directed diagnostic, SHA-256 `72aa685f15b94fb14a1f0bdcdd1e683bc32faf1c3937dc9a923d1cce0d1f90c9`.
- [Working renderer follow-up](https://github.com/VladimirReshetnikov/Leant/blob/main/test-church/receipts/trailing-type-witness-working-2026-09-13.json): 506 archived artifacts, SHA-256 `d5703deead9d93f25848382adfc8162207d295d152138b2a52402a7326b3c121`.

All archive members were rehashed. Source snapshots, base revisions and working
diffs retain the exact implementation boundaries. Runtime binaries are recorded
by identity rather than redistributed.

The [160-cell ledger](../../test-church/behavior-ledger.md) now records 68 cells
with historical acceptance, four attempted without indexed acceptance and 88
without indexed evidence. The failed native `last` attempt remains in its history
alongside the passing working-source follow-up. This is not a current-revision
pass rate. Nonempty reductions, extrema, native-Int indexing, Haskell Djinn
`maybeEither`, constructor acceptance and broader evidence/query forms remain
required. The six selector operations now have recorded behavior in all five
modes, but the new renderer still needs its isolated release gate.
