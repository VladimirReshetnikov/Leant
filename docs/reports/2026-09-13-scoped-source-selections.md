# Checked source selections through rank-N synthesis

Djex now retains the type arguments and lexical dictionary occurrences selected by a checked contextual proof through source lowering and independent graph reconstruction. The public batch and streaming entrances both preserve the two implementations of `forall a b. (C a, C b) => Token` obtained from `provider :: forall p. C p => Token`. The analogous local rank-N callback is covered as well. Independent GHC execution with different class payloads distinguishes the choices as `(37,91)` and `(91,37)`.

This is canonical Haskell acceptance for the supported contextual fragment. Native Lean integration with the new dependency remains pending. It adds no Church behavior cells and does not establish completeness for arbitrary higher-rank or impredicative inhabitation.

## Implementation

The shared type API adds `implicitizeLeadingForallsWithOpenings`, returning every opened binder in telescope order, including vacuous and shadowed binders. The existing API delegates to it and preserves its result contract. Prepared root and nested Given openings retain these identities.

Private unary annotations keep each original provider scheme, complete selected type vector, and checked dictionary occurrence attached to its expression. Cleanup can move or duplicate the association with the expression. Final source graphs contain ordinary typed nodes, with no annotation markers or extra search premises. The independent checker verifies the complete original target, exact lexical ownership, selected constraints, and erasure. Missing selections, scope escape, and wrong dictionary/type pairings remain errors. A forall introduced by an impredicatively selected result is preserved as part of that result, not consumed as another original provider parameter.

Duplicate comparison uses the annotated expression with source type and dictionary binders identified by lexical position. Nested type binders receive alpha-normal keys. Only annotations actually used by that expression affect comparison; unused markers and temporary proof names do not. Selection occurrences remain distinct from ordinary source locals. This preserves different selections at different expression positions while collapsing equivalent implementations reached by different proof paths. It does not construct source graphs eagerly, refill raw candidate windows, alter choice budgets, or change provider scheduling.

## Validation

The final frozen run records unchanged source inputs, test executables, and controller. Strict builds use GHC 9.12.4 with `-Werror` and one build job. Its passing gates are:

| Gate | Result |
| --- | --- |
| Public dictionary selections, with batch/stream synthesis and GHC execution | 2 tests |
| Conditional-Given budget controls | 10 tests |
| Private source-graph suite | 120 tests |
| Shared synthesis suite | 514 tests |
| Djinn unit suite | 133 tests |
| Full integration suite | 154 tests |
| Public source-graph suite | 59 tests |
| Church signature corpus | 350 signatures in each Haskell engine; both generated corpora pass GHC checking |
| Adversarial scope probes | 50 per engine; generated positive witnesses pass GHC checking |
| Complete CLI suite, run separately through Cabal | 138 tests |

Scope refusals are bounded no-candidate observations, not general impossibility proofs. Signature synthesis/typechecking is distinct from behavioral acceptance. The dictionary observations test actual source-selected payloads, with replay instances excluded from search inventories. Lean partial cases retain their approved supplied-default or inhabitance contracts.

The new rewrite regression starts with checked proofs containing the same annotation table and then explicitly applies capture-avoiding substitution. Their erased tuple expressions coincide, but the independently checked graphs use opposite dictionary orders. Both comparison keys survive; exact duplicates collapse. Ordinary eta cleanup does not promise general beta reduction, so the test invokes the shared substitution operation explicitly.

## Retained failed attempts

The first frozen run passes the public, private, shared, and Djinn suites but fails two of 154 integration tests: the reusable-callback budget controls expose duplicates from comparing raw annotation tables. The lexical occurrence key repairs this without changing the controls. The second frozen run stops at a new private regression whose fixture incorrectly assumed that ordinary cleanup performed general beta reduction. A further focused attempt records that eta cleanup also makes no such promise. The corrected fixture explicitly performs capture-avoiding substitution and independently checks the resulting graphs; the complete final run passes.

The earlier local-callback GHC failure was in the fixture invocation `candidate @Int @Bool provider`, where the provider's constraint-only parameter was ambiguous. Passing `(\ @p -> provider @p)` with `TypeAbstractions` fixes the invocation. Both public regressions then pass with the generated bodies unchanged by that fixture repair. The initial eta-contraction failure and subsequent diagnostics are retained as well.

## Evidence and remaining work

The [receipt](https://github.com/VladimirReshetnikov/Djex/blob/main/test-church/receipts/scoped-source-selections-2026-09-13.json) identifies the [archive](https://github.com/VladimirReshetnikov/Djex/blob/main/test-church/receipts/scoped-source-selections-2026-09-13.zip), with 207 artifacts (920,739 bytes, SHA-256 `aa9a3d74629b2fbd243ed8a109e4e09642b3068a7daec3b10f9a4877469d20a3`): commands, input hashes, changed source snapshots, failed and passing logs, generated replay modules, and a rehashed member manifest. Each frozen source tree is reproducible from its recorded Git base plus the retained source overlay. Runtime executables are identified by hash rather than redistributed. The CLI gate is recorded separately from the frozen multi-suite run.

Equal-predicate dictionary overlap and deeper quantified callback admission remain guarded. Distinct selected types do not demonstrate arbitrary choice between two hidden Haskell dictionaries for the same predicate. Native constructor integration, the bounded method/tail and Exference nested-context misses, reduction carriers, and remaining behavioral coverage remain open. See the [delivery re-triage](2026-09-13-synthesis-delivery-retriage.md).
