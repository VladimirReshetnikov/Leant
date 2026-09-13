# Six extended Church operations accepted in Lean Djinn and Both

Fresh live synthesis accepts `fromMaybe`, `maybeToList`, `isLeft`, `either`, `numeralSuccessor`, and `numeralAdd` in both Lean Djinn and Both. All twelve exact displayed implementations pass independent full-type and original-oracle kernel replay. These cells previously lacked indexed acceptance; adding this receipt brings the historical ledger from 68 to 80 accepted cells.

## Results

| Operation | Djinn | Both | Finite observations per mode |
| --- | --- | --- | ---: |
| `fromMaybe` | Passed | Passed | 18 |
| `maybeToList` | Passed | Passed | 7 |
| `isLeft` | Passed | Passed | 10 |
| `either` | Passed | Passed | 15 |
| `numeralSuccessor` | Passed | Passed | 15 |
| `numeralAdd` | Passed | Passed | 75 |

This is 140 finite observations per mode, 280 across the batch. All 24 candidate/proof axiom inventories are empty. Each query runs in a separate session; reference implementations and prior synthesized definitions do not enter search. Library search, provider discovery and classical fallback are disabled for these six operations, and the observed provider inventories are empty.

Both actual False queries pass: Djinn records 623 falsifications and Both records 915, with zero accepted or inconclusive observations. A separate oracle module passes 13 positive controls, 14 fully typed wrong implementations, and one specialized adapter control. These are controls, not additional accepted synthesis cells. The oracle module's own axiom inventory is checked independently; it is not conflated with the empty candidate inventories.

## Source and validation boundary

The batch uses the [published trailing-type renderer](2026-09-13-trailing-type-witness-acceptance.md) at Leant `b6b4e2022dae8a20a09a4fa12d7c4fb002eb24c1` and clean Djex `c1ad560e106f59df07d1a32c3b51158ef749fc99`. The isolated checkout is based on Leant `d2e5473e1cbabfc36094cd84c651a9793e4fbc68` plus the accepted renderer diff. Before execution, the controller compares the isolated renderer and test sources with the published Git blobs, freezes 436 relevant source files, and pins the executable, Lean kernel and backend. All source, runtime and controller checks remain unchanged through execution and packaging.

There is no additional implementation change or rebuild in this batch. The earlier isolated renderer receipt owns its strict build, 707 unit tests and paired 350-signature replay claims; this receipt adds fresh behavioral evidence only. The root checkout's contextual-constructor changes remain excluded.

The original fixture settings remain: window/verification 65,536, one displayed result, balanced ranking, Djinn interleave with choice budget 500,000, Exference steps 100,000, a 90-second command deadline, and a separate 900-second process guard. All 27 owned processes exit zero without timing out. The complete batch takes 418.05 seconds; this is a single-run timing, not a benchmark claim.

## Reproducible receipt and next batch

The [receipt](https://github.com/VladimirReshetnikov/Leant/blob/main/test-church/receipts/matching-extended-native-six-2026-09-13.json) and [archive](https://github.com/VladimirReshetnikov/Leant/blob/main/test-church/receipts/matching-extended-native-six-2026-09-13.zip) retain 540 artifacts, including frozen sources, exact commands and captures, the oracle and replay modules, controller, and a rehashed manifest. The archive is 3,124,584 bytes, SHA-256 `4693b1165926511d7ffbb3c338af153bc9f0aa99c3efca7ae2ea6a57ab9c0e3b`. Build products are pinned by identity rather than redistributed.

The [160-cell ledger](../../test-church/behavior-ledger.md) now records **80 historical acceptances, four attempted cells without indexed acceptance and 76 cells without indexed evidence**. This is neither current-revision acceptance of the complete matrix nor universal extensional equivalence. Both-mode acceptance is recorded from actual Both queries, not inferred from an individual engine's result.

The next fourteen cells are the remaining seven extended operations in Lean Djinn and Both: `foldr`, `foldl`, `length`, `listToMaybe`, `catMaybes`, `squashMaybe`, and `maybeEither`. Haskell Djinn `maybeEither`, supplied-default reductions, extrema and native-Int indexing remain separate coverage obligations. Scoped dictionary preservation, contextual-constructor acceptance and the broader original implementation priorities also remain open.
