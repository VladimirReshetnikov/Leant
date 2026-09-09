# Ordinary contextual Haskell output retains its selected type choices

Ordinary Djex REPL queries now retain each selected candidate's own typed graph
through presentation. For explicit-forall contextual signatures, the renderer
uses that graph's type selections and scoped dictionary evidence. Expressions
and definitions no longer depend on a behavioral predicate worker to repair an
erased method application. Missing or unsupported evidence produces a rendering
diagnostic; another candidate's evidence is never substituted.

The [receipt](https://github.com/VladimirReshetnikov/Djex/blob/main/test-church/receipts/ordinary-contextual-output.json)
and [archive](https://github.com/VladimirReshetnikov/Djex/blob/main/test-church/receipts/ordinary-contextual-output.zip)
preserve source hashes, complete inventories, commands, compiler/test captures,
the implementation patch, and earlier failed attempts.

## Accepted public coverage

All **9 cases / 36 public queries pass**: Djinn, Exference and Both; first, best
and all selection; expression and definition output; and both signatures:

```haskell
forall a. C a => Token
forall a. C a => (forall b. b -> b) -> Token
```

The loaded method's type variable occurs only in its class constraint. Independent
GHC execution checks every displayed candidate verbatim under its original full
signature and distinguishes the Int payload 37 from the Bool payload 91. The
higher-rank argument is also supplied at replay. Both mode must emit a candidate
from each labeled engine section. These are ordinary queries without a `where`
predicate. The focused matrix passes in **50.86 seconds**.

Selection continues to rank the candidate's compatibility projection with the
existing selector rules, retaining the original typed handle for rendering.
Legacy Exference all-selection still streams, and best still retains tied
candidates. Prepared parallel paths receive the parsed signature. Production
search limits, provider inventories, ranking and tie retention are unchanged.

## Complete affected regressions

Strict builds pass. All **330 tests in four complete affected suites pass**
across the following recorded runs:

| Suite | Tests | Seconds |
| --- | --- | --- |
| djex-tests | 152 | 231.08 |
| djex-api-tests | 38 | 0.08 |
| djex-parallel-tests | 27 | 0.01 |
| djex-cli-tests | 113 | 198.87 |

The first aggregate run passed three complete suites and 112/113 CLI tests. Its
only failure was a source assertion still expecting preparation callbacks without
the parsed signature argument. After correcting those two expected lines, the
complete CLI suite passed. Production source remained identical; the archive
retains the original fixture and failure. The other project suites were not
rerun for this frontend-only milestone.

## Fixture bounds and retained failures

The initial new fixture used 20,000 Exference steps. Its preserved baseline best
compiler input contains 7,475 copies of the same compatibility expression; equal
printed expressions do not establish interchangeable typed evidence. The baseline
run recorded four GHC failures, then a compiler replay stalled until the owned
outer guard terminated it. The rebuilt run passed seven cases but timed out in
Exference best and Both best at 180 seconds per case.

The accepted presentation fixture uses **256 search steps**, retaining all 36
queries, every displayed alternative, the 20,000 Djinn choice budget and the same
signatures/payloads. Its GHC replay uses a process job for owned child cleanup.
The paired baseline still fails all nine cases, although some legacy all-output
failures come from line extraction and are not claims about complete legacy
renderings. This is bounded presentation acceptance, not a performance repair or
acceptance of the earlier 20,000-step best queries.

## Remaining work

Implicit-root binder order/scope, one-shot contextual commands, typed list
rendering, derived Haskell methods, mixed Lean inventories, selected equal-predicate
dictionaries and richer evidence remain separate deliveries. Leant's committed
dependency is unchanged; the native recursor timeouts and remaining integration
gates stay open. The [current roadmap](2026-09-07-synthesis-retriage.md) preserves
all priorities 1–4 and all 13 extended plus 19 explicit-default Church operations
across Haskell Djinn/Exference and Lean Djinn/Exference/Both.
