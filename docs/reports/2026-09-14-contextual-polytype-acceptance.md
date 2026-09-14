# Supplied polymorphic types for qualified local consumers

Djinn's contextual specialization path now admits scoped quantified types already present in the query, including nominal wrappers containing a forall. It previously considered root variables, dictionary arguments and closed monotypes, omitting the required polymorphic choice even when the query supplied it explicitly. This is a bounded source-selection repair; it introduces no arbitrary type guessing or larger search limits.

The repair reuses the ordinary instantiation path's quantified-subtree helper. A subtree mentioning a binder owned by a nested scope is excluded. Existing vocabulary entries keep their order, and each complete contextual instantiation still passes the independent kind and dictionary checks. Candidate and assignment caps remain in force; adding a valid source choice does not establish unrestricted impredicative completeness.

## Acceptance

The [manifest](../../test-church/receipts/contextual-polytype-acceptance-2026-09-14.json) links the [archive](../../test-church/receipts/contextual-polytype-acceptance-2026-09-14.zip), containing source snapshots, controllers, exact generated Haskell, compiler/execution logs and retained failed attempts. Binaries are excluded. Archive members are reopened and checked against their recorded hashes.

- Strict Djinn unit and CLI builds pass with `-Werror`.
- All **147 Djinn unit tests pass** on the final test snapshot. The new production-query test checks **eight variants**: direct and nominally wrapped foralls, depth-first and interleaved search, with alternatives enabled and disabled. It uses no constructors or global values and checks the selected type and dictionary application in the typed graph. Each variant retains the original 4,096-choice budget and separate 20-second guard.
- Both Haskell engines pass two public signatures through one-shot and named-`where` synthesis: **eight exact GHC compile-and-execute replays**, **four actual-False controls**, and **two invalid-kind rejection controls**. Djinn uses an explicit 4,096-choice budget in both public entrances; Exference uses its existing defaults. Public fixtures include the data constructors, while the isolated regression deliberately excludes them.
- Before the source repair, the corrected direct regression compiled and failed with no candidates in 0.04 seconds. Its earlier name-shadowing compilation failure is retained separately and is not a semantic baseline.

The public family has this shape, where `P` is either `forall b. b -> Token` or `Box (forall b. b -> Token)`:

```haskell
forall a r. Marker a =>
  (forall s. Marker a => s -> Witness s r) ->
  P -> Witness P r
```

The observations check both the consumer's result and the supplied payload. The isolated opaque-result test additionally requires selecting the exact supplied type; public data elimination may admit different valid implementations.

## Reproduce

After building Djex, use a new output directory for each invocation:

```powershell
cabal build djex:exe:djex djex:test:djinn-tests --ghc-options=-Werror -j1
$djexExe = (cabal list-bin djex:exe:djex).Trim()
python -X utf8 -B test-church/public_contextual_polytype.py --exe $djexExe --backend djinn --choice-budget 4096 --output dist-newstyle/contextual-polytype/djinn
python -X utf8 -B test-church/public_contextual_polytype.py --exe $djexExe --backend exference --output dist-newstyle/contextual-polytype/exference
```

The shared public runner's new optional `--choice-budget` argument only configures Djinn validation invocations; omitted arguments preserve the previous runner behavior. It does not change product defaults.

## Remaining boundaries

The default **unbounded** Haskell one-shot search timed out at its separate 90-second process guard. At 4,096 choices, candidate cutoffs of both 1 and 200 return a term promptly; the captured comparison therefore does not implicate the candidate cutoff alone. Finite-budget acceptance does not resolve the unbounded search limitation, and increasing its time limit is not the next diagnostic.

This report does not claim native Lean acceptance of the new Djex revision. Leant's separate source-evidence repair has local Exference/Both acceptance, but integrating this core revision requires the original native dictionary example across individual engines and Both, exact kernel replay, negative controls and appropriate regressions. Exference's explicit Haskell source-kind execution guard, integer indexing and the original two-universe query remain open under the [current plan](2026-09-14-synthesis-next-priorities.md). No Church behavior-ledger cells are closed by this milestone.
