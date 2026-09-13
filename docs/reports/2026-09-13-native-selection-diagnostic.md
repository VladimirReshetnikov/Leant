# Native scoped-selection diagnostic and revised priorities

The accepted Djex source-selection repair passes the new native selection cases in Djinn and Both, but Exference produces no candidates. This diagnostic blocks native dependency promotion and makes Exference's lexical selection path the next focused repair. Both's successful implementations all originate in Djinn.

The [revised delivery order](2026-09-13-synthesis-delivery-retriage.md) follows this with a bounded closure pass for the pending constructor integration, then reusable reduction carriers. The [canonical Djex acceptance](2026-09-13-scoped-source-selections.md) remains valid within its documented Haskell test scope; it did not establish these new native cases.

## Exact scope and results

The isolated checkout uses Leant `d9dfcfad0158092e094e45931d1db0e503e6aded` with clean Djex `a4c1bad92d1c63bb533113a7497a577c418559db`. Its only source addition is the new selection fixture. It excludes the root checkout's pending constructor changes. Production Leant still pins Djex `c1ad560e106f59df07d1a32c3b51158ef749fc99`.

| Completed gate | Result |
| --- | --- |
| Strict native build, GHC 9.12.4, `-Werror`, one job | Pass |
| Complete native unit suite | 707/707; 249.95 seconds in the suite |
| Djinn global/local selection positives | 4/4, exact Lean kernel replay passes |
| Djinn actual False controls | 2/2 |
| Exference global/local selection positives | 0/4; no candidate produced |
| Exference actual False controls | 0/2; zero predicate checks cannot establish rejection |
| Both global/local selection positives | 4/4, exact Lean kernel replay passes; producing engine is Djinn |
| Both actual False controls | 2/2 |
| Djinn full signature corpus | 350/350 candidates, axiom-free exact kernel replay passes |

The initial diagnostic was captured while the Exference signature gate was running. That gate subsequently completed: **350/350 candidates and axiom-free exact kernel replay pass in Exference too**. The final controller confirms unchanged sources, runtimes and controller. Its overall status remains failed solely because the selection matrix failed. The [terminal supplement](https://github.com/VladimirReshetnikov/Leant/blob/main/test-context/receipts/native-scoped-selection-terminal-2026-09-13.json) and [archive](https://github.com/VladimirReshetnikov/Leant/blob/main/test-context/receipts/native-scoped-selection-terminal-2026-09-13.zip) retain this final result and the Exference signature artifacts; the initial checkpoint archive is unchanged.

The matrix uses 32 candidates/verifications, 20,000 search steps/choices, a 45-second query deadline, and a 180-second outer process guard. The global inventory contains only `Ctx.C.out`, with provider cap one; provider discovery is disabled for the local callback cases. Reference implementations are confined to separate replay/oracle files.

The global target is `∀ (α β : Type), [Ctx.C α] → [Ctx.C β] → Nat`. The local target adds a rank-N callback of type `∀ (p : Type), [Ctx.C p] → Nat`. Each is exercised with observations requiring selection of the outer or inner dictionary. Payloads and callback offsets vary independently, including a caller that supplies two dictionaries at the same concrete type. Positives validate source-graph authority, selected evidence ownership, exact displayed text, full target type, and behavior through independent replay. These Lean caller observations do not authorize removal of Haskell's hidden equal-predicate dictionary guard.

## Specific next hypothesis

Both captured Exference query forms pass fragment admission. The global capture also confirms admission of the exact `Ctx.C.out` provider. Their result summaries report zero candidates and zero passed, falsified, or inconclusive behavioral checks. This places the observed failure before behavioral rejection; further tracing must distinguish search construction from independent expression/graph refusal.

In canonical Djex, `byUnified` in `exference/src-core/Language/Haskell/Exference/Core/Internal/Exference.hs` invokes `uniqueGivenInstantiation` for fresh constraint-only provider variables. The implementation in `ConstraintSolver.hs` deliberately returns no selection when more than one coherent assignment exists. `ExpressionCheck.hs` also uses that helper to infer otherwise unspecified selections.

This is a concrete hypothesis, not a demonstrated root cause. The next bounded experiment should trace one global and one local provider application with two legal lexical Givens. If the unique-only search policy discards those alternatives, enumerate legal selections within existing accounting and retain explicit type/dictionary evidence in the emitted expression. Keep the independent checker strict when no such evidence is supplied. Validate the point where substitutions reach newly inserted applications; changing the branching policy alone may still lose the chosen selection during reconstruction.

First obtain the four Exference positives and two actual False controls at unchanged bounds, with independent replay. Then run the complete native matrix, unit suite, and both signature corpora at the final dependency. The existing Djinn and Both results must remain passing. The older constructor matrix is a subsequent, separate gate.

## Retained evidence and limitations

The [diagnostic receipt](https://github.com/VladimirReshetnikov/Leant/blob/main/test-context/receipts/native-scoped-selection-diagnostic-2026-09-13.json) and [archive](https://github.com/VladimirReshetnikov/Leant/blob/main/test-context/receipts/native-scoped-selection-diagnostic-2026-09-13.zip) retain completed build/unit/selection/Djinn-signature outputs, raw query inputs, generated exact replay sources, source/runtime identities, the new fixture, and reproduction controllers. The archive contains 622 members, all independently rehashed after packaging; it is 3,188,441 bytes with SHA-256 `ccb7546cdc9bc58dad728ba52d8f7c2adb3ed19ef7825bf05e35ac1bd3a449cd`.

The archive also preserves provisional function-carrier witnesses for reductions, clearly marked as neither compiler-checked nor synthesized. Their finite-model note is design evidence, and its generator is not included. It does not establish behavioral acceptance or carrier reachability in either engine.

No production source change or dependency promotion is included in this documentation milestone. No Church behavior cell is added: the historical ledger remains 92 accepted, 15 attempted without indexed acceptance, and 53 without indexed evidence. These are not current-revision pass rates. The original 160-cell behavior target and the remaining source/interface/contextual obligations are unchanged.
