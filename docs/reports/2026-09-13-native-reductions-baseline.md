# Supplied-default reduction baseline in Lean

The published implementation did not synthesize an accepted `foldl1`, `foldr1`, or `reduce` implementation in any of Lean Djinn, Exference, or Both at the original limits. All nine queries reached their 90-second command deadline. This completed baseline is failure evidence, not a claim of impossibility or a current-revision pass rate.

The frozen checkout was Leant `8087a1dca171daabae79b8b8bc174938de3ea257`, with clean Djex `c1ad560e106f59df07d1a32c3b51158ef749fc99`. Its strict executable/unit-target build passed with `-Werror` and one job; the unit suite was not rerun for this source-unchanged baseline. The separate scoped-evidence and contextual-constructor experiments were absent.

| Operation | Djinn falsifications | Exference falsifications | Both falsifications |
| --- | ---: | ---: | ---: |
| foldl1 | 1283 | 2998 | 1555 |
| foldr1 | 1602 | 3507 | 1505 |
| reduce | 1710 | 3256 | 2134 |

Every query recorded zero accepted and zero inconclusive behavioral observations. Backend-request and other verification diagnostics remain in the raw captures; the table reports only assertion falsifications. Each query preserved its complete manifest-derived type, supplied default, empty provider inventory, Interleave traversal, search/verification window 65536, choice budget 500000, step limit 100000, and the original deadline.

The controls passed independently: three positive oracle witnesses, nine fully typed wrong implementations, and one actual False query per mode. The False queries recorded 623 Djinn, 299 Exference, and 915 Both falsifications, with zero accepted or inconclusive observations. The 15 owned query/kernel processes all exited zero without an outer process timeout. The parent acceptance runner exited one because no synthesis cell passed. Every oracle declaration matched its expected empty axiom inventory, and all frozen sources, runtimes, and the controller stayed unchanged.

The next reduction repair should inspect the actual proposed instantiation types and candidate derivations. In particular, test whether a carrier distinguishing an empty input from an accumulated nonempty result is missing, delayed, or rejected. Do not infer that missing carrier admission is the cause merely from these deadlines, and do not count the control witnesses as synthesized implementations.

The [receipt](https://github.com/VladimirReshetnikov/Leant/blob/main/test-church/receipts/native-reductions-baseline-2026-09-13.json) identifies the [complete archive](https://github.com/VladimirReshetnikov/Leant/blob/main/test-church/receipts/native-reductions-baseline-2026-09-13.zip): 504 artifacts, 3,302,282 bytes, SHA-256 `f839fd4e3d3009fd5dd4e244bf6f3a02c8f2dbc77374a2714d1b005735a547a2`. All archive members were rehashed after packaging. Indexing these nine misses changes the historical 160-cell ledger to **92 acceptances, 15 attempted cells without acceptance, and 53 cells without indexed evidence**. It adds no acceptance.
