# Constructor closure after selected-evidence integration

The bounded closure pass repairs three of the four original native failures: nested-context construction now passes independently in Djinn, Exference and Both. Djinn's method-with-tail case still misses the required composition at its original 32-candidate bound. The focused canonical composition regression also fails. The constructor patch therefore remains unaccepted; its exact residual moves to the bounded-search queue while reduction construction becomes the next delivery.

## Frozen source and results

The fresh isolated checkout starts at Leant `3b24ebbd4022255b8e22888408d7e890984f3887`, with Djex `ebadbefd175ac98d4f79393d4ed4a4089a1725bf`. It adds exactly the eight pending Leant source/test files and the two pending Djinn Core/test files recorded in the receipt. These are separate from the already accepted lexical-selection implementation.

The strict GHC 9.12.4 build passes with `-Werror` and one job. It builds Leant, the native unit target, the fake solver fixture and the Djinn unit target. Building test executables does not establish that their full suites pass.

| Focused case | Result |
| --- | --- |
| Djinn: prepend the selected method result to the supplied tail | Miss: 32-candidate limit; four falsified observations, zero inconclusive |
| Djinn: construct a singleton using the outer dictionary under a second dictionary scope | Accepted; exact displayed implementation passes independent Lean replay |
| Exference: same nested-context behavior | Accepted; exact displayed implementation passes independent Lean replay |
| Both: same nested-context behavior | Accepted, produced by Exference; exact displayed implementation passes independent Lean replay |
| Canonical Djinn abstract-datatype composition regression | Failed at its 32-candidate bound |

The three successful kernel replays retain their full types, finite behavior observations and empty axiom inventories. The live fixture also checks source-graph closure, exact rendering and lexical dictionary ownership. All four separate positive oracle preflights pass. The original query settings remain 32 candidates/verifications, 20,000 steps/choices, a 45-second command allowance, provider cap one and a separate 180-second process guard.

The canonical failure produces the same relevant alternatives as the native method/tail miss: identity, constructor applications using competing numeric providers, and the empty constructor. It does not expose the required method/constructor/tail composition within the observed prefix. The logs are evidence of a bounded miss, not impossibility. Preserving selected evidence fixed nested reconstruction and Exference's selection alternatives; it did not by itself fix this composition search.

## Release boundary and next action

This was the four-failure gate of the planned bounded closure pass. Because it fails, the complete 21-positive/six-control matrix and full unit suites were not rerun. No new actual False controls are claimed. Do not combine the historical 17/21 result with these three new successes into a current 20/21 pass rate: the snapshots differ. No Church behavior cells are added.

The root pending constructor files remain intact. The diagnostic copy has its complete source retained before being returned to accepted production source for a separate reduction trace. The method/tail residual, including its failing canonical regression, remains required work under the [delivery priorities](2026-09-13-synthesis-delivery-retriage.md). It can be resumed from the exact retained patches without another broad provider redesign.

The [receipt](https://github.com/VladimirReshetnikov/Leant/blob/main/test-context/receipts/constructor-closure-after-selections-2026-09-13.json) and [archive](https://github.com/VladimirReshetnikov/Leant/blob/main/test-context/receipts/constructor-closure-after-selections-2026-09-13.zip) retain 504 verified members: strict-build captures, source snapshots, both patches, controllers, four live queries and oracle files, three exact replays, and the failed canonical regression. The archive is 3,053,444 bytes, SHA-256 `ca7ebb3ffd1c0e655a8ce0cc301e9753eb4e66343d5d317a396e99104f0e2ffc`. All recorded source, runtime and controller integrity checks pass.
