# Exference public ground-kind synthesis

Exference now executes explicit Haskell ground-kind requests through checked source expansion, search and independent candidate checking. Its original 11-case public kinded-source corpus passes: **22 exact GHC compile/execution replays, 11 actual-False controls and one malformed-kind rejection**. This replaces the blanket `DJEX_EXF_SOURCE_KINDS` execution refusal for this path.

The corpus covers higher-kinded identity and callbacks, vacuous root/local/result binders, shadowed binders with different kinds, adjacent differently kinded callbacks, a polymorphic alias argument, a constrained callback and an impredicative pair. Both ordinary one-shot commands and named-function `where` queries pass. The named adjacent-kind query requires `(7,9)` from distinguishable inputs, so duplicating either input cannot satisfy it.

## Implementation

The adapter checks source annotations against the actual session inventory and expands aliases with lexical kind evidence attached. It then acquires fresh source identities outside the complete environment namespace. Search retains those kinds through leading-forall opening, root and nested rigid introduction, provider allocation and unifier substitutions.

Each ordinary global-provider use acquires a fresh declaration namespace. Its result, parameters and class constraints are prepared together, preserving shared parameters within a use while separating independent uses. The expression checker independently acquires declaration schemes and validates instantiation kinds; it starts from source authority rather than trusting the successful search branch's inferred kind state.

Candidate evidence now retains the checker's binder-kind table with either a plain term graph or its existing type-application certificate graph. The certificate association survives the new representation. Compatibility projection remains lazy, and rendering can consume the retained kinds in the graph's identity domain.

The expanded regression gate exposed an evaluation-order failure in the existing candidate contract: deep forcing could demand graph availability before compatibility. The implementation now uses explicit sequencing for that boundary, preserving the existing compatibility-first failure test rather than weakening its expectation.

The unannotated request path retains its existing behavior. Search budgets and public defaults are unchanged.

## Evidence and reproduction

The focused final build passes **123 private engine tests and 515 ordinary Exference tests**. New regressions cover actual higher-kinded local search, rejection of source authority belonging to another query, independent repeated-provider namespaces, and retention of kinds and certificate association. The earlier prerequisite's capture-avoidance, shadowing, vacuous-kind incompatibility and independent-checker rejection tests remain included.

The final broader strict gate passes **1,659 tests in seven suites**:

| Suite | Passing tests |
| --- | ---: |
| Private Exference engine | 123 |
| Ordinary Exference | 515 |
| Djinn | 148 |
| Djex adapter integration | 187 |
| Djex API | 38 |
| Shared synthesis | 540 |
| Type-application certificates and candidate carriers | 108 |

The final authority is `exference-kinded-regression-v2/results.json`; source and runtime integrity checks pass. The first broader receipt remains failed overall despite its six passing suites.

Both public matrices were then rerun on the final executable, at the harness's default settings. Exference and Djinn each pass all 11 cases: **44 exact GHC replays, 22 actual-False controls and two malformed-kind rejections** in total. Their final receipts are `exference-kinded-public-v3/results.json` and `djinn-kinded-regression-public-v1/results.json`; captured source and executable identities remain unchanged.

The first public experiment tested the vacuous higher-kinded callback alone and passed both forms, exact replay and rejection controls. The subsequent full Exference matrix passed all 11 cases. Failed strict-build attempts are retained separately: the added certificate test initially needed a concrete failure type, then a local name collided under `-Werror`. The first broader run passed six suites but failed the compatibility-first test in the certificate suite. These failed gates remain separate from final acceptance.

Run the affected integration gate from the Djex root:

```text
python test-church/check_exference_kinded_search.py --out dist-newstyle/exference-kinded-regression
```

It builds the executable and seven affected suites with `--ghc-options=-Werror -j1`, records each complete test inventory, runs suites with one test thread, and checks captured source and runtime identities. The original prerequisite controller is for its recorded 120-test revision; use this controller for the expanded implementation.

Run the public matrix against the executable returned by `cabal list-bin djex:exe:djex`:

```text
python test-church/public_kinded_source.py --exe PATH_TO_DJEX --backend exference --output dist-newstyle/exference-kinded-public
```

The public harness provides only a transparent alias and a methodless class/instance. It does not supply implementations. GHC checks the unchanged displayed output at the original full signature, and each positive case has a False assertion which must actually be evaluated and rejected.

The mirrored [receipt index](../../test-church/receipts/exference-kinded-source-2026-09-14.json) and [archive](../../test-church/receipts/exference-kinded-source-2026-09-14.zip) retain all final gates and earlier attempts, captured source, controllers, commands, transcripts and runtime hashes. The archive has 2,915 members and is 14,536,780 bytes; every member was reopened and verified after packaging. Compiled binaries and object files are excluded. Its SHA-256 is:

```text
f101450133b871ca6e91f5e06b93e1f444e7f6ce7d27090de475c6bd832fd54c
```

## Remaining obligations

This is acceptance of the stated Haskell source corpus, not arbitrary rank-N synthesis completeness. Caller-supplied kinds for vacuous global-provider parameters need an explicit composition gate with source-kinded queries; validation in the existing assignment API alone does not establish their retention through the new kind scope. Deconstructor paths and consistency between separately transformed search types and kind obligations also warrant discriminating integration tests before broader claims.

Leant retains its separately accepted Djex pin `9a2d59d958a60ff3b6899697a60b6985a5cf73a3`. This report does not establish native integration of the new dependency or change Lean's universe rules. The original integer `at`, simultaneous two-universe query and remaining practical source obligations stay in the [execution plan](2026-09-14-synthesis-next-priorities.md). The Church behavior ledger is unchanged.
