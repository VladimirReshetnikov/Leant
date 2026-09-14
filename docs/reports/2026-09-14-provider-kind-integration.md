# Exference provider kinds and polymorphic constructor fields

Explicitly kinded Exference queries now preserve caller-supplied provider kinds and can reuse polymorphic fields introduced by pattern matching. Two concrete failures identified by the integration gates are repaired. Native adoption remains a separate gate.

## Supplied provider kinds

The assignment API already validated complete caller-supplied kind vectors, including higher kinds for vacuous parameters. It then discarded those vectors before entering search. When an explicitly kinded query activated the independent kind checker, reacquiring a provider's source scheme inferred a vacuous binder as `Type`. Consequently a correct visible application at a higher-kinded constructor disappeared, even though the unannotated assignment query accepted it.

The retained vector now travels with the exact declaration name and source scheme in the private kind scope. The checker validates scheme identity and independently acquires fresh lexical owners for each occurrence. Branch substitutions retain the closed declaration authority rather than rewriting it. Other declarations with the same shape cannot borrow that authority. Wrong arity, contradictory body uses, changed authority and mismatched schemes are rejected.

The discriminating query uses a provider `forall (f :: Type -> Type). Token` and a supplied selection `Wrapper`. Its goal itself contains an explicitly kinded outer binder. Acceptance requires the actual `provider @Wrapper` occurrence; merely returning another `Token` is insufficient. A second query requires that visible selection in both components of a pair. Each occurrence retains its type-application certificate, and the generated expressions compile and execute in GHC at their full source signatures.

## Polymorphic constructor fields

A second integration query requires:

```haskell
data KindedFieldBox (f :: Type -> Type) =
  KindedFieldBoxValue (forall a. f a)

unpackKindedField :: forall (f :: Type -> Type) a b.
  KindedFieldBox f -> (f a, f b)
```

The unannotated counterpart already synthesized an independently replayable implementation. The explicitly kinded query produced no candidate: deconstruction introduced its field's nested forall binders without acquiring their lexical kind ownership, so later opening of those binders failed.

Pattern matching now acquires fresh nested field binders after specialization to the scrutinee. Existing free query identities are preserved. Including the scrutinee in the same checked type batch retains the datatype's parameter-kind constraints. Both single-constructor patterns and multiple case alternatives use this boundary. The unannotated path retains its original allocation.

The regression covers unannotated, explicitly kinded and alpha-renamed source signatures for both pattern forms. GHC independently checks and executes the generated terms. The multiple-constructor fixture explicitly enables the existing multi-constructor-pattern option and checks both arms with distinct payloads 37 and 53. These examples require independent reuse of the field at two type arguments; a reference implementation is not supplied to synthesis.

## Validation

The final strict executable and seven-suite build passes with `--ghc-options=-Werror -j1`. All **1,664 tests pass**: 125 private Exference, 515 ordinary Exference, 148 Djinn, 190 adapter integration, 38 API, 540 shared synthesis and 108 certificate tests. Final source and runtime integrity checks pass.

The original 11-case public Exference corpus also passes on that executable: **22 exact GHC compile/execution replays, 11 actual-False controls and one malformed-kind rejection**, covering both ordinary one-shot and named-function `where` commands. The unchanged public controller retains its original queries and defaults. This increment does not claim a fresh public Djinn matrix; its 148 unit tests are included in the affected gate.


The new integration tests perform eight exact GHC compile/execution replays: two provider-selection queries and six polymorphic-field queries. Private checks cover independent declaration reuse, retained authority after substitution, non-donation to a different name, wrong scheme and arity, changed kind vectors and contradictory kind uses. Existing assignment-kind refusal and independent-checker rejection tests remain required.

The original provider-composition failure and deconstructor failure are retained separately from final acceptance. The latter baseline passes its unannotated control, then fails at the explicitly kinded query. Development builds also exposed a wrong request-factory argument, a test-local name collision and a redundant import; those compile errors were corrected before the final gate.

## Remaining scope

Search limits and defaults are unchanged. This closes the demonstrated provider-kind composition and polymorphic-field ownership losses; it does not establish every possible datatype/kind combination. Explicitly annotated nested declaration binders require corresponding source evidence wherever the frontend admits them.

Leant still pins `9a2d59d958a60ff3b6899697a60b6985a5cf73a3`. The next priority-2 gate is native adoption of this implementation together with the accepted Haskell kind milestone and Djinn proof-prefix repair, followed by affected native checks. Original integer indexing and the simultaneous nominal universe query remain open. No Church behavioral ledger cells close in this milestone.

## Reproduce and inspect evidence

From the Djex root:

```powershell
python -X utf8 -B test-church/check_exference_kinded_search.py --out dist-newstyle/provider-kind-recheck
$djexExe = (cabal list-bin djex:exe:djex).Trim()
python -X utf8 -B test-church/public_kinded_source.py --exe $djexExe --backend exference --output dist-newstyle/provider-kind-public-recheck
```

The mirrored [receipt index](../../test-church/receipts/exference-provider-kind-integration-2026-09-14.json) and [portable archive](../../test-church/receipts/exference-provider-kind-integration-2026-09-14.zip) retain the two failing baselines, final regression and public runs, captured source, commands, transcripts and public GHC fixtures. Compiled binaries are identified by hashes rather than bundled. Every archive member was reopened and verified.

Continue with the [current priorities](2026-09-14-synthesis-next-priorities.md).

Archive: 953 members, 4,739,018 bytes; SHA-256 `5e595824531172956b9cfae883053bcf65ba1a9cf00001952d52c6872e59913b`.
