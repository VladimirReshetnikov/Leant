# Public kinded source frontier and reduction stop condition

The next concrete source-support target is **kinded Haskell forall binders through public commands**. Both Djinn and Exference reject the two tested signatures before synthesis, through both one-shot and named-`where` entrances. Independent GHC checks compile the original signatures and execute their reference observations successfully. These are valid source types with an identified conversion refusal, not bounded search failures.

## Public-source probe

The two complete source signatures are:

```haskell
forall (f :: * -> *) a. f a -> f a
forall b. ((forall (f :: * -> *) a. f a -> f a) -> b) -> b
```

The first tests an outer higher-kinded binder. The second requires constructing a polymorphic callback with its own higher-kinded binder. The intended observations use both lists and `Maybe`; separate GHC oracle implementations satisfy them. Oracle implementations never enter a synthesis session.

All **eight public queries** fail at conversion: two signatures, two engines and two entrances. Djinn reports `DJEX_TYPE_PARSE: kinded type variable`; Exference's one-shot route reports `DJEX_EXF_PARSE` with the same underlying message. The public REPL reports the conversion error even though its process exits normally. No output is counted as a synthesized or compiler-replayed implementation.

The probe uses the previously accepted executable from the `c2d5530f` implementation milestone. It checks the retained executable identity and source parity; two regenerated behavior-ledger metadata files differ from the frozen baseline and are recorded separately. The synthesis environment directory is empty, and the named queries retain explicit 32-candidate and 20,000-choice/step settings. The initial preflight stopped on those metadata differences before running any query; the explicit classification allowed the diagnostic run to proceed. Source oracle compilation then succeeds and execution prints `[True,True]`.

## Repair boundary

`tyVarTransform` in `exference/src-frontend/Language/Haskell/Exference/TypeFromHaskellSrc.hs` explicitly refuses `KindedVar`. The shared public parser routes through that conversion. `src/Language/Haskell/Djex/HaskellSrc/Scope.hs` also refuses kinded binders when building standalone expression scope.

The repair must transport and validate binder kinds through the parsed query, checked synthesis and output scope. Accepting the syntax while discarding its annotation would leave vacuous binders and conflicting annotations unchecked. Tests must include root and nested binders, vacuous higher-kinded binders, shadowed names, malformed or contradictory kinds, and exact compiler replay through public entrances. Existing programmatic kind-assignment tests do not discharge source-command coverage.

An isolated implementation checkout has been prepared. This report identifies the blocker; it does not claim the repair is implemented or that a source example can be accepted by erasing its kind.

## Completed reduction experiment

The descending-arity head-ordering prototype passes its strict build and cursor contracts, including sibling reuse, first-proof preservation and resumed-choice accounting. Its fixed-carrier behavioral gate still fails: **53,146 proofs at 500,000 choices**, with neither `foldl1` nor `foldr1` found. Of those proofs, 37,980 use all three outer inputs. The previously tested lexical order produced 53,150 proofs and also missed both reductions.

The controller honors the stop condition and does not run the original polymorphic query after that failure. The variant remains isolated and unreleased. Return to reduction construction with a different, trace-supported hypothesis; another unchanged run or a larger limit is not the next action.

The [delivery plan](2026-09-13-synthesis-delivery-retriage.md) now makes the independent source/public lane next. The accepted [strict-implicit Lean binder release](2026-09-13-strict-implicit-source-acceptance.md) remains separate. No Church behavior cells are added by these diagnostics.

The [diagnostic receipt](https://github.com/VladimirReshetnikov/Djex/blob/main/test-church/receipts/source-kind-frontier-2026-09-13.json) and [archive](https://github.com/VladimirReshetnikov/Djex/blob/main/test-church/receipts/source-kind-frontier-2026-09-13.zip) retain commands, output, controllers, oracle source, reduction source snapshots and hashes. Generated binaries are omitted; their identities remain in the receipts.

Archive: 2,038,391 bytes, 357 rehashed members, SHA-256 `4e98cf20badf579fb0316ffe1469fc989a72a4136b2cd9b14ca0228da47cae19`.
