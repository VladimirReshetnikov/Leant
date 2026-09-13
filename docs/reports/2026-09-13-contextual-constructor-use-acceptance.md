# Contextual constructor composition acceptance

Djinn now synthesizes the original contextual method/tail implementation at its unchanged 32-candidate limit. The complete native constructor matrix passes all **21 positives and six actual False controls**, and all **711 native unit tests** pass. Both native 350-signature corpora pass independent Lean replay. The canonical regression and all 135 Djinn unit tests pass, followed by the broader canonical release gates below.

## Problem and implementation

The failing query asks for `∀ (α : Type), [Ctx.C α] → List Nat → List Nat`, where the caller's dictionary supplies a `Nat`. Its observations require the method's value to be prepended to the supplied tail: a dictionary carrying 7 and tail `[3, 5]` must produce `[7, 3, 5]`, while a dictionary carrying 11 and an empty tail must produce `[11]`. The exact displayed term now independently replays with these observations and no implementation or proof axioms.

Native source packets retain reachable constructor schemes and their explicit universe-zero constant selections. Duplicate owners, unrelated result families and incompatible source packets are refused. A discovered constructor can share an intrinsic constructor only when their complete packets agree. The renderer preserves the checked constructor, type and dictionary selections.

Djinn's contextual plans now combine their lexical method bridges with bounded, checked specializations of retained polymorphic values. This lets a method and an abstract datatype's constructor participate in the same proof with the original dictionary erasure receipt.

The final search change adds a normal-term branch that constructs a use of an existing contextual helper. A required assumption occurs either at a neutral head or in one of its arguments; unrestricted siblings use the established normal grammar. It is generic over exact proof-assumption identities and types, with no operation-name match or reference implementation. The original first proof and complete original search remain available. The branch runs only for explicit interleaved term alternatives, and all introduced binders remain fresh.

Every choice still spends the shared allowance. Every yielded raw proof still spends a candidate slot, including later rejected or duplicate results. The existing independent proof and source-graph checks remain in force. Required-use construction does not add a dictionary, invent a type instantiation, suppress ordinary providers or refund unsuccessful proofs.

## Trace and retained unsuccessful attempts

The canonical reproducer retains the native providers, full type, source contexts and original limits. Its failed baseline yields 32 assessed raw candidates, of which 28 are discarded by duplicate comparison, leaving four implementations. The specialized contextual plan contains both the method and constructor bridges but does not combine them before the raw cutoff; 19,140 of the 20,000 choice allowance remains at the final raw event. The goal's outer arguments were already introduced, so missing lambda introduction was not the explanation.

Giving contextual plans the existing normal-form priority still fails: 27 duplicates leave five implementations, without the required method/tail behavior. That priority-only experiment is not part of the accepted code. The required-use grammar then passes the exact regression. Its first strict build caught an ambiguous numeric default in a helper signature; the retained corrected build and tests pass.

## Validation

| Gate | Result |
| --- | --- |
| Canonical strict builds and complete Djinn unit suite | 135/135 pass, including contextual constructor behavior and required-use cursor contracts. |
| Canonical private suite | 120/120 pass. |
| Canonical synthesis suite | 514/514 pass. |
| Canonical integration suite | 156/156 pass. |
| Canonical source-graph suite | 59/59 pass. |
| Canonical cli suite | 138/138 pass. |
| Canonical Church signatures and adversarial scopes | Both Haskell engines pass the complete 350-signature corpus with GHC checking and the scope suite. |
| Actual synthesized Haskell contextual constructors | The singleton and method/tail outputs compile and execute under GHC with distinct dictionary payloads. |
| Native strict build | Passes for the REPL, full native unit executable, canonical Djinn unit executable and fake-Z3 helper. |
| Original four failing native cases | All four pass exact Lean replay; the canonical regression also passes in the native build. |
| Complete constructor matrix | 21/21 positives and 6/6 actual False controls; all positive implementation/proof axiom inventories are empty. |
| Full native unit suite | 711/711 pass. |
| Native signature replays | 350/350 for Djinn and 350/350 for Exference, independently kernel-checked with empty implementation axiom inventories. |

The six False controls reject actual proposals, with falsification counts 5, 3, 32, 32, 32 and 32 and no inconclusive checks. In the combined-mode matrix, six positives are produced by Djinn and method/tail by Exference. Both individual engines also independently pass all seven positive operations. Combined mode is not substituted for individual-engine coverage.

The first native release controller completed the matrix, then stopped before running unit tests because its expected inventory was 709. The executable's actual inventory is 711: the prior 707 plus exactly four intended constructor/source-metadata tests, with no removed tests. A retained continuation corrects only that expectation, verifies unchanged sources and executables, and runs all 711 tests plus both signature corpora. The completed matrix is reused by its exact receipt hash rather than rerun or silently relabeled.

The initial canonical CLI invocation omitted the built command and helper directories from PATH, causing 136 command-launch failures. A separate continuation records those exact executable identities, corrects only PATH, and runs the complete CLI suite plus Church and scope gates. The earlier passing canonical suites remain tied to their original frozen receipt. Actual synthesized singleton and method/tail graphs are additionally rendered to complete Haskell modules and executed with distinct class instances; their implementation bodies are generated by search, while concrete provider bodies remain confined to the external test support.

The standalone Haskell emitter retains its initial package/source-path setup failures and a signature-free rendering refusal. The passing driver uses the unit component's exact package IDs and source paths, then supplies the original complete query type to the existing signature-aware renderer. That signature is required because the type parameter occurs only in the class constraint; dropping it would lose dictionary selection. Both generated modules compile and print `(True,True)` under independent GHC execution.

The native validation uses Leant base `3b24ebbd4022255b8e22888408d7e890984f3887` and Djex base `ebadbefd175ac98d4f79393d4ed4a4089a1725bf` plus the retained eight-file native and three-file dependency overlays. Canonical validation starts at `1481e918d42330087dc1ecdb79fd93921572c967` plus its retained overlay. The archives preserve the exact sources and controllers; these are isolated validation results, not a claim that the previously dirty root checkout was built in place.

## Scope and next work

This closes the contextual constructor release gate. It does not add Church behavior cells or establish arbitrary rank-N/impredicative completeness. The historical ledger remains **92 accepted, 15 attempted without indexed acceptance and 53 without indexed evidence** out of 160 cells.

Reduction term construction is next, followed by the eight independent Church cells and the 45 extrema cells in coherent batches. Required-use construction may be worth investigating for carrier-only plans, whose existing checker already requires instantiation-bridge use; no reduction acceptance follows from the constructor results.

The native contextual source representation still checks its documented Type-0 fragment and explicit universe-zero constant selections. General Lean universe support, broader source binders, named-`where` entrances and richer contextual evidence retain their separate obligations. See the [delivery plan](2026-09-13-synthesis-delivery-retriage.md) and the [unsuccessful reduction experiment](2026-09-13-reduction-carrier-boundary.md).

The [receipt](https://github.com/VladimirReshetnikov/Leant/blob/main/test-context/receipts/contextual-constructor-use-2026-09-13.json) and [archive](https://github.com/VladimirReshetnikov/Leant/blob/main/test-context/receipts/contextual-constructor-use-2026-09-13.zip) retain all gates and unsuccessful attempts. All 2,818 archive members and the recorded source snapshots were rehashed. The archive is 16,913,822 bytes, SHA-256 `6f724bd8312b79ee6a86dc70e0a22880d3055241986172a60f62e920791c0d25`.
