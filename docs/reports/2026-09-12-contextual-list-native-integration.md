# Native integration of canonical contextual list construction

Leant now pins Djex `c1ad560e106f59df07d1a32c3b51158ef749fc99` after a strict build and ten fresh passing native gates. This integrates the [accepted canonical Haskell contextual list milestone](2026-09-09-contextual-list-output.md). It closes the compatibility gate in the [current delivery order](2026-09-09-synthesis-after-contextual-list-acceptance.md).

The separately diagnosed Lean contextual list admission refusal remains open. The six diagnostic queries were refused before search because their contextual source packet could not retain the universe arguments carried by `List`. Neither the native compatibility matrix below nor Haskell list acceptance establishes that those Lean queries now work.

## Fresh acceptance

The build uses `-Werror -j1` for Leant, its complete boundary test executable and the fake-Z3 helper. All ten gates ran serially against the exact dependency and fixed executables; no earlier gate receipt was retained. The final parent check confirms all 524 frozen input hashes are unchanged. Packaging independently rechecks them.

| Gate | Coverage | Wall seconds |
| --- | --- | ---: |
| unit | 705 unfiltered unit tests | 258.17 |
| methods | 6 method cases and exact replays | 120.66 |
| method-controls | 9 negative/source-ownership/cache control sessions | 137.32 |
| local-context | 39 positive, False and unsupported-source cells | 313.02 |
| simplification | 15 behavioral simplification queries | 27.16 |
| native-recursor | 9 positive map/append/length replays and 3 False controls | 297.69 |
| extended-exference | 13 extended operations and 1 False control | 198.06 |
| nested-forall | 6 exact positive replays and 3 False controls | 91.98 |
| signatures-djinn | 350 signatures, complete kernel replay and empty axiom inventories | 49.59 |
| signatures-exference | 350 signatures, complete kernel replay and empty axiom inventories | 666.10 |

The gate durations include their subprocesses and are observations of this host, not a performance comparison. Search windows, budgets, provider settings and internal timeouts retain the existing fixtures' requirements. The parent completed with exit zero and no pending gates.

## Reproducible evidence

The [receipt](https://github.com/VladimirReshetnikov/Leant/blob/main/test-recursive/receipts/contextual-list-native-integration.json) and [archive](https://github.com/VladimirReshetnikov/Leant/blob/main/test-recursive/receipts/contextual-list-native-integration.zip) retain the exact parent snapshot, child receipts, commands, raw process captures, source inputs, replay modules and strict-build evidence. The archive has 3747 artifacts, 11507937 bytes, SHA-256 `28e9c1c6ca40023174bfdfbf165b27415e7a41573d1d66623883f406ab9b0d27`. Every manifest member was rehashed and the ZIP integrity check passed.

The kernel replays validate the exact emitted terms at their original signatures. Positive behavior, actual False controls and unsupported-source refusals remain distinct receipt entries. The unit gate includes all 705 configured tests. Both 350-signature corpora complete their combined kernel checks and axiom inventories; a signature count alone would not satisfy these gates.

## Remaining work

The next capability delivery is exact Lean contextual list source evidence, followed by missing Church behavior batches, remaining named-`where` one-shot entrances and kinded binders, then broader provider/dictionary/universe evidence. The first admission increment must preserve actual levels and constructor authority rather than discard the refusal guard. Native tree work remains one bounded diagnostic batch at a milestone boundary.

The full behavior target remains `(13 extended + 19 supplied-default operations) × 5 modes = 160 cells`, with negative controls and replay additional. Native tree synthesis remains unaccepted in all three modes. This dependency promotion does not claim complete rank-N/impredicative search or close those remaining deliveries.
