# Remaining extended Church matrix: twelve acceptances and two Djinn misses

The seven remaining extended operations complete all fourteen Lean Djinn/Both queries. **Twelve positives and both actual False controls pass.** Djinn `length` and `maybeEither` remain unaccepted. The batch is a completed diagnostic with individually accepted cells, not a passing fourteen-cell release.

| Operation | Djinn | Both | Finite observations per cell |
| --- | --- | --- | ---: |
| `foldr` | Passed | Passed | 400 |
| `foldl` | Passed | Passed | 400 |
| `length` | Command deadline before provider discovery | Passed | 44 |
| `listToMaybe` | Passed | Passed | 44 |
| `catMaybes` | Passed | Passed | 40 |
| `squashMaybe` | Passed | Passed | 8 |
| `maybeEither` | Choice-point limit; no accepted output | Passed | 7 |

All twelve exact displayed implementations pass independent full-type/original-oracle kernel replay, covering 1,835 finite observations on accepted cells. Every synthesized implementation has an empty axiom inventory. Only the exact `maybeEither` oracle proof retains `propext`, inherited from the documented Sum equality observer; candidates and unrelated declarations cannot use it. There are 26 empty replay declaration inventories and one such oracle-proof inventory.

The two actual False queries pass with 623 Djinn and 915 Both falsifications, zero accepted observations, and zero inconclusive observations. The separate oracle module passes 13 positive controls, 14 fully typed wrong controls and one specialized adapter control. All 29 query/kernel child processes exit zero without timing out, but the parent acceptance process correctly exits one because two positive requirements fail.

## Failure attribution

Djinn `length` reaches its original 90-second command deadline after 37 falsified observations. Provider discovery is enabled and the exact zero/successor declarations are present, but no `debug provider:` entries appear. The native provider-free baseline consumes the deadline; the current scheduling code reports that timeout before loading the live providers. This identifies a scheduling boundary, not a proof that the goal is uninhabited. A proposed repair must let the complete bounded provider inventory participate without resetting the deadline or inflating the search allowances. It must also account for the existing singleton provider stage, which can itself omit a needed second primitive.

Both `length` succeeds through Exference's native constructor route, with this exact replayed term:

```lean
fun _ f => .ofNat (f _ (fun _ => .succ) (.zero))
```

Its provider inventory is empty. The captured typed graph, allowed value constants and kernel replay establish the native `Nat`/`Int` constructor route; this is not evidence that provider discovery ran or that the Djinn scheduling miss is solved.

Djinn `maybeEither` reaches the original choice-point limit with 364 proposed candidates and 288 falsified observations. No candidate passes both Lean verification and the assertion. One source-graph typing failure and additional verification failures are recorded; they are separate from the resource-limit outcome. The retained capture does not establish that repairing the final graph failure alone would solve the behavior.

Both `maybeEither` succeeds through Exference, with an exact full-type replay:

```lean
fun _ _ f _ x g =>
  f _ (fun h => h _ x (fun y => g (fun _ f1 _ => f1 y)))
      (fun f2 => f2 _ x (fun z => g (fun _ _ f3 => f3 z)))
```

This confirms a valid implementation for the unchanged Lean type and observations. It does not substitute for Djinn acceptance or repair the separately recorded Haskell Djinn miss.

## Reproducible evidence

The [receipt](https://github.com/VladimirReshetnikov/Leant/blob/main/test-church/receipts/matching-extended-native-seven-2026-09-13.json) and [archive](https://github.com/VladimirReshetnikov/Leant/blob/main/test-church/receipts/matching-extended-native-seven-2026-09-13.zip) preserve 549 artifacts. The archive is 3,157,341 bytes, SHA-256 `001133f85dd1902b5ed4c81fac3646203a95dce67836b3fead5448462856d87d`. Every member is rehashed. The raw runner receipt remains unchanged; `diagnoses.json` separately records the two classifications and their exact capture hashes.

The controller verifies the published renderer/test blobs at Leant `0345344eef3a16e5fe29c33a4e328a6696fab03f`, with clean Djex `c1ad560e106f59df07d1a32c3b51158ef749fc99`. The isolated base is Leant `d2e5473e1cbabfc36094cd84c651a9793e4fbc68` plus the accepted renderer diff. It freezes 436 relevant sources and pins the executable, kernel and backend. Sources, runtimes and controller remain unchanged through the completed run and packaging. The batch takes 540.19 seconds; no new source change, rebuild or benchmark comparison is claimed.

Original settings remain window/verification 65,536, one displayed result, balanced ranking, Djinn interleave/choice budget 500,000, Exference steps 100,000, command deadline 90 seconds and separate process guard 900 seconds. Reference implementations never enter live search. Provider discovery is off except for the existing length fixture's capped zero/successor inventory.

The [160-cell ledger](../../test-church/behavior-ledger.md) now records **92 historical acceptances, six attempted cells without indexed acceptance, and 62 cells without indexed evidence**. This is not a current-revision pass rate or universal extensional equivalence. The remaining extended behavior gaps are Djinn `length` in Lean and Djinn `maybeEither` in both Haskell and Lean. Supplied-default reductions, extrema, native-Int indexing, scoped dictionaries, constructor acceptance and the other original implementation obligations remain open.
