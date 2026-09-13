# Supplied-default selectors accepted in all five language/engine modes

The matching Lean batch accepts `head`, `fromJust`, `fromLeft` and `fromRight`
in Djinn, Exference and Both. Together with the [eight Haskell cells](2026-09-13-supplied-default-selectors.md),
these four operations now have recorded acceptance in all five required modes:
20 cells in total, each using its documented explicit default argument.

| Operation | Lean Djinn | Lean Exference | Lean Both |
| --- | --- | --- | --- |
| `head` | Passed | Passed | Passed |
| `fromJust` | Passed | Passed | Passed |
| `fromLeft` | Passed | Passed | Passed |
| `fromRight` | Passed | Passed | Passed |

All twelve exact displayed terms pass independent kernel replay at the complete
default-adjusted types, with the original type binders preserved and 24 finite
observations per cell. Each candidate is declared before the observation helpers.
The 192 declaration inventories across the candidate replay files are all empty.
Search uses no discovered providers; library and classical search are disabled.
Four separate oracle modules validate the reference and wrong implementations.

All three actual False queries pass. Their captures record 581 falsifications
for Djinn, 299 for Exference and 915 for Both, with zero passing or inconclusive
observations and no displayed candidate. These are completed bounded controls,
not proofs of search exhaustion. All 31 owned processes exit zero without the
outer process guard terminating them.

The native supplied-default fixture's original settings remain unchanged:
window/verification 65,536, shown 1, balanced ranking, interleave for Djinn,
choice budget 500,000, Exference steps 100,000, a 90-second command deadline
and a separate 900-second process guard. The Haskell and Lean receipts use their
respective established fixture settings; this is not an equal-cost comparison.

A fresh `cabal build exe:leant --ghc-options=-Werror -j1` passes before execution.
The run freezes 437 native and dependency source files before that build and
checks them again after the run and during packaging. Runner inputs, runtimes
and the controller also remain unchanged. The base Leant commit is
`154dc56eba3c3a46a8e0afcd879a689f3e66d453`; the dependency base is
`c1ad560e106f59df07d1a32c3b51158ef749fc99`. Both working diffs are archived.
The contextual-constructor repair remains uncommitted. This behavioral batch
does not establish its full regression acceptance or promote the dependency.

The [receipt](https://github.com/VladimirReshetnikov/Leant/blob/main/test-church/receipts/supplied-default-selectors-native-2026-09-13.json)
and [archive](https://github.com/VladimirReshetnikov/Leant/blob/main/test-church/receipts/supplied-default-selectors-native-2026-09-13.zip)
retain 554 artifacts: source snapshots, working diffs, the build/controller,
commands, captures, exact candidate replay files, oracle modules and manifests.
All archive members were rehashed. The archive is 3,171,302 bytes with SHA-256
`439d3d68b8720882fa6642ca146fe4629e38f29b2c00547a35529767b24a2af7`.
Runtime binaries are recorded by identity rather than redistributed.

## Ledger and remaining work

The [160-cell ledger](../../test-church/behavior-ledger.md) now indexes 60 cells
with historical acceptance, four attempted without indexed acceptance and 96
without indexed evidence. The twelve Lean cells were previously unindexed;
this does not imply that the earlier implementation could not synthesize them.
Historical evidence remains separate from current-revision validation.

The ledger adapter now recognizes the supplied-default replay namespace and
preserves an explicit `accepted: false` even if an individual replay passed.
Required control or integrity failures therefore cannot become acceptance
through indexing. Two new tests cover that boundary and prevent the extended
`maybeEither` oracle axiom exception from applying to these partial counterparts.
All 14 ledger tests and deterministic regeneration pass.

The next independent cells are the remaining selectors (`last` and `atKey`)
and nonempty reductions; Haskell Djinn `maybeEither` remains a required search
repair. Extrema, native-Int indexing, constructor acceptance, scoped dictionary
reconstruction and the remaining public query/provider forms stay in scope.
The agreed supplied defaults make these tested counterparts total; no total
implementation of the original partial signatures is claimed. Finite
observations remain distinct from universal behavioral equivalence.
