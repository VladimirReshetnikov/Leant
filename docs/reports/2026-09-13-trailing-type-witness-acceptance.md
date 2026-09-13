# Isolated acceptance of trailing-type witness rendering

Leant now offers a bounded closed `Unit` witness when a local use has unresolved trailing type arguments. This repairs the captured Djinn implementation of supplied-default Church `last` while preserving the established variants ahead of the fallbacks within each universe lane. The isolated release checks pass with clean Djex `c1ad560e`; separate contextual-constructor changes are excluded.

## The concrete repair

The generated implementation previously reached one of two rejected Lean forms: transporting the full polymorphic Church list exceeded the expected universe, while applying it to `_` left the result type undetermined. The renderer can now propose:

```lean
fun _ x f => f _ (fun a b _ => b a) (fun c _ => c) x (f _root_.Unit)
```

Live Djinn synthesis finds this implementation at the original limits, after 44 falsified observations. The exact displayed term passes the complete supplied-default type and all 24 observations, with an empty axiom inventory. This is a target-language rendering proposal, not new source-proof authority or a change to Lean's universe hierarchy.

The fallback applies only to the existing ambiguous trailing local-instantiation sites. Explicit source type applications, provider assignments and mid-spine holes remain intact. Every proposal still requires Lean verification. All established fitting and style variants precede closed-witness fallbacks within each universe lane. The pre-existing cap remains 32 variants per lane, 96 per normal form; an unresolved applied let can retain the existing independently bounded inlined form.

## Compatibility and negative evidence

The first isolated attempt built successfully but passed only 705/707 unit tests. One exact rendering-list assertion did not include the new provider-result proposal; another assumed the older 12-variant lane limit. Inspection also exposed an ordering defect: fallbacks could precede established forced-fit variants. The revised enumeration fixes that ordering, and the tests now check preservation of the established variants, fallback ordering, and the actual per-lane cap.

The provider-result fixture deliberately includes an extra proposal that does not typecheck at its original `Nat` target. Independent kernel checks accept the original polymorphic provider term and reject that exact `Unit` variant. The rejected kernel process exits one as expected; it is not counted as a successful implementation. Explicitly selected type arguments have a separate no-defaulting regression.

The failed first run is retained under `previous-attempt/` in the acceptance archive. It is not relabeled as a pass or combined with focused results.

## Complete isolated validation

| Gate | Result |
| --- | --- |
| Strict build | Passed with `-Werror`, one build owner. |
| Complete unfiltered native unit suite | 707/707 passed. |
| Exact provider-result kernel checks | Original term accepted without axioms; invalid closed-witness variant rejected. |
| Supplied-default `last` and `atKey`, Djinn/Exference/Both | 6/6 live synthesis cells and exact candidate replays passed. |
| Actual False queries | 3/3 passed; Djinn 581, Exference 299, Both 915 falsifications, with no accepted or inconclusive observations. |
| Independent operation-oracle modules | 2/2 passed. |
| Church signature corpus, Djinn | 350/350 synthesized and independently replayed without axioms. |
| Church signature corpus, Exference | 350/350 synthesized and independently replayed without axioms. |

All synthesized behavior implementations have empty axiom inventories. Only the two exact `atKey` observer/proof declarations retain their documented `String.length` dependencies: `Classical.choice`, `Quot.sound`, and `propext`. The receipt checks prohibit those dependencies on candidates and unrelated declarations.

The isolated checkout starts at Leant `d2e5473e1cbabfc36094cd84c651a9793e4fbc68`, with clean Djex `c1ad560e106f59df07d1a32c3b51158ef749fc99`. It contains only the renderer change, two new tests, and the two updated rendering-contract tests. The release stages exactly those source changes; the root checkout's pending constructor changes are outside this acceptance.

The controller freezes 437 source files, retains the exact diff and runtime identities, and verifies unchanged inputs. Unit tests took 332.25 seconds; the Djinn and Exference signature gates took 158.40 and 876.36 seconds respectively. These are single-run timings, not comparative benchmarks or performance guarantees. Behavior fixtures retain their original types, providers, search limits and deadlines.

## Reproducible evidence and remaining work

The [acceptance receipt](https://github.com/VladimirReshetnikov/Leant/blob/main/test-church/receipts/trailing-type-witness-isolated-2026-09-13.json) and [archive](https://github.com/VladimirReshetnikov/Leant/blob/main/test-church/receipts/trailing-type-witness-isolated-2026-09-13.zip) preserve 548 artifacts, including frozen source, controllers, the source diff, transcripts, replay modules, and a rehashed manifest. The archive is 3,431,560 bytes, SHA-256 `d0e00042fe387c52777c1b7a0439a84b8f8ac3d11a0b74f5a509a9782f6f2e10`. Build products are identified rather than redistributed.

The [earlier diagnosis](2026-09-13-trailing-type-witness-frontier.md) separates the rejected renderings, a manually directed kernel experiment, and the first live working-tree repair. This receipt establishes the isolated implementation release.

The [160-cell ledger](../../test-church/behavior-ledger.md) gains another pinned historical receipt for these six cells; its counts remain 68 accepted, four attempted without indexed acceptance, and 88 without indexed evidence. This is not current-revision acceptance of all 160 cells. Finite observations do not establish universal extensional equivalence.

The next capability batch covers `fromMaybe`, `maybeToList`, `isLeft`, `either`, `numeralSuccessor`, and `numeralAdd` in Lean Djinn and Both. Nonempty reductions, extrema, native-Int indexing, Haskell Djinn `maybeEither`, scoped dictionary selections, constructor acceptance, and broader query/provider evidence remain required. Leant's production dependency is unchanged.
