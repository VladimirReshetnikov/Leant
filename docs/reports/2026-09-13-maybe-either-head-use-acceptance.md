# Path-sensitive head use closes Djinn maybeEither

Djinn now synthesizes Church-encoded `maybeEither` in both Haskell and Lean at the original query limits. Both Haskell engines pass **all 13 extended Church operations in one fresh run each**: 26 independently compiled and executed implementations. Native Djinn, Exference and Both all pass the original `maybeEither` query and independent exact Lean replay. Both mode now obtains its accepted term from Djinn.

## Problem and implementation

The original [Church signature](https://github.com/VladimirReshetnikov/Djex/blob/main/docs/examples/Church.hs#L615) converts `Either (Maybe a) (Maybe b)` into `Maybe (Either a b)`, using the Church encodings throughout. The search must handle both outer alternatives, inspect the selected Maybe, and construct a polymorphic Either value inside the successful result. Returning `Nothing` for every input has the right type but fails the observations.

The canonical baseline on Djex `202e0f59` retained 49 candidates before exhausting the unchanged 500,000-choice allowance; the first candidates returned `Nothing` for every observation. Its trace records 130 active plans and 432 assessed raw proofs. Of these, 284 survived admission, while 148 carrier-plan proofs were omitted for failing the existing required-bridge-use check. All 194 proofs from constructed families survived checking. The common-result plan already contained the outer Either eliminator and both Maybe eliminators. The trace therefore supports a search-construction repair; it does not establish a need to weaken scope or source-graph checks.

Djinn now gives existing common-result bridge plans an additional normal-term search branch. Along each application path, that branch uses an exact function head at most once. Sibling arguments keep independent availability, so a term such as `pair (f x) (f x)` remains available in this branch. Terms requiring nested reuse, such as `f (f x)`, remain available through the complete original search continuation.

The branch activates only for explicitly requested interleaved term alternatives in the checked atomic/arrow fragment. It preserves the original first proof, fresh binder identities, and the shared choice and raw-candidate allowances. It does not recognize an operation name, introduce a reference implementation, add a provider, change type instantiations, or refund duplicate/rejected proofs. Other proof fragments and unrequested modes retain their previous search.

The two added regressions check the original expanded `maybeEither` type with empty/present left and right observations, and the search contracts: sibling reuse, nested reuse through the original continuation, first-proof preservation, finite completion controls, fresh scope, zero fuel, and exact pause/resume accounting.

## Behavioral acceptance

The focused public Haskell query accepts after **10 falsifications and one success**, with no evaluation errors or timeouts. Its displayed implementation independently compiles and executes with GHC. Positive and wrong-result oracle controls and the actual `where False` query pass. The subsequent full run passes all 26 extended operation/engine cells and both live False controls.

Native Djinn accepts after **nine falsifications**, and Both after **11**, with no inconclusive observations in either positive query. Exference also passes independently. All three exact displayed terms replay at their complete original signatures. Candidate implementations have empty axiom inventories; the fixture's oracle theorem has precisely its declared `propext` allowance. Each mode has its own actual False control. Combined-mode provenance is recorded separately from individual-engine acceptance.

The native window and verification limit remain 65,536, the Djinn choice allowance 500,000, the Exference step limit 100,000, and the query deadline 90 seconds. Complete process wall time also includes backend startup, loading observation definitions and environment preparation; it is not a measurement of synthesis time alone. The canonical unit reproducer retains its original 65,536-candidate/500,000-choice settings.

Lean Djinn native-integer `length` remains a separate open cell. The `maybeEither` results do not discharge it. The fresh retry reaches its original 90-second query deadline after 23 falsifications and zero inconclusive observations, with no accepted implementation. Its actual False control passes.

## Release checks

| Gate | Result |
| --- | --- |
| Canonical strict build and Djinn unit suite | 137/137 pass. |
| Canonical private suite | 120/120 pass. |
| Canonical synthesis suite | 514/514 pass. |
| Canonical integration suite | 156/156 pass. |
| Canonical source-graph suite | 59/59 pass. |
| Canonical cli suite | 138/138 pass. |
| Canonical signature and scope corpora | Both engines pass 350 signatures with actual GHC checking and the complete adversarial scope suites. |
| Extended Haskell behavior | 13/13 operations per engine, exact independent GHC execution, oracle controls and actual False queries. |
| Native strict build | REPL, native unit executable, Djinn unit executable and helper build pass. |
| Native constructor matrix | 21/21 positives and six actual False controls pass. |
| Native unit suite | 711/711 pass. |
| Native signature corpora | 350/350 per engine with independent kernel replay and empty implementation axiom inventories. |

All heavy stages run serially against frozen inputs. Canonical and native sources, runtime identities and controllers remain unchanged over their recorded runs. Canonical validation starts at `202e0f5951ab2156ed8e418b6480e9e60937c720` plus the three-file overlay; native validation starts at `cce462e0474536c091295eef18e8deb3615a00a3` with that same Djex base and overlay. No native implementation file changes in this milestone. Publication checks the code against these isolated snapshots rather than claiming that the root checkouts were built in place.

## Retained reduction experiment and remaining work

Before this repair, a separate experiment extended contextual required-assumption construction to existing carrier plans. It did not close the reduction gate: the published baseline produced 3,467 candidates and the experiment 2,466, with neither `foldl1` nor `foldr1` found at 500,000 choices. That rule was removed. The archive retains both failures, the `maybeEither` baseline and traces, and the successful construction experiment. A passing `maybeEither` case does not establish reduction coverage.

The historical [behavior ledger](../../test-church/behavior-ledger.md) now records **94 accepted cells, 13 attempted cells without indexed acceptance, and 53 cells without indexed evidence**. These are historical receipts rather than a current-revision pass rate. This milestone adds 2 explicitly replayed cells; constructor/signature results add no behavior cells by association. The remaining 66 cells and the separate source-language, contextual-evidence, supplied-fold tree and public-interface obligations stay on the [delivery plan](2026-09-13-synthesis-delivery-retriage.md).

The [receipt](https://github.com/VladimirReshetnikov/Leant/blob/main/test-church/receipts/acyclic-head-maybe-either-2026-09-13.json) and [archive](https://github.com/VladimirReshetnikov/Leant/blob/main/test-church/receipts/acyclic-head-maybe-either-2026-09-13.zip) preserve source snapshots, patches, commands, controls, generated replay modules and failed attempts. All 3,915 archive members were rehashed. The archive is 20,540,624 bytes, SHA-256 `9b2e6b79b32938a584283a8bdcf66b050a231b338c1b0692bfa5a20e56d7d225`.
