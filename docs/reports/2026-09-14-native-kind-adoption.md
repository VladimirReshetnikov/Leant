# Native adoption of Exference kind integration and Djinn prefix checking

Leant adopts Djex `e237e8667190aff38faaa590ce5b12afbffac452`, replacing `9a2d59d958a60ff3b6899697a60b6985a5cf73a3`. This combines the accepted Haskell ground-kind implementation, the provider-kind and polymorphic-field integration repairs, and the Djinn contextual proof-prefix repair in one native dependency update.

The [Haskell integration report](2026-09-14-provider-kind-integration.md) records the two demonstrated failures, their fixes and exact GHC acceptance. The [prefix report](2026-09-14-contextual-proof-cutoff-acceptance.md) records the lazy proof-list checking defect. This native gate checks the actual proposed dependency with Leant's source, serializer and public commands. No Leant production-source changes accompany the gitlink update.

## Native validation

The strict native build and all **768 native tests pass**. The focused Length
integration group also passes all 25 tests. The public gate passes **84 cells**:
18 dictionary, 27 lexical-context, 24 nominal/polymorphic Djinn, and 15 scheduling
cells. The emitted serializer prelude compiles independently in Lean. Each child
retains its exact replay or rejection/refusal evidence and original limits.
Source and runtime integrity checks pass for the full gate and its public parent.

The first native attempt passed its strict build but failed four source-text
scheduling guards. The [failed-run archive](../../test-church/receipts/native-adoption-retriage-2026-09-14.json)
is preserved. Those guards expected pre-scheduling expression layouts or searched
the old local fallback section. The test update removes redundant full-expression
matches and points the retained ownership and diagnostic checks at the shared
constructive finalizer. Cursor/deadline and classical-route checks remain; the
public scheduling gate independently exercises continuation and lane limits.
No production search code was changed to satisfy these assertions.

The [accepted native archive](../../test-church/receipts/native-kind-adoption-2026-09-14.json)
contains the strict build, inventory, focused/full suite output, source snapshots,
public commands, displayed terms, independent replays and checked archive hashes.

The dictionary gate retains both the original forced polymorphic result after dictionary application and its boxed transfer. Its ordinary and named-`where` commands exercise Djinn, Exference and Both. The lexical gate retains its actual-False and higher-class-universe refusal controls. The nominal/polymorphic gate covers the eight previously accepted families through Djinn, including higher/named universes, strict quantifiers, chained selections and qualified polymorphic payloads. It excludes the original simultaneous two-universe query, which remains an acceptance obligation.

The scheduling gate rechecks provider use, resumed structural continuation after empty discovery and original per-lane verification allowances across all three modes. The serialized support prelude is emitted from the actual test executable and independently compiled by Lean. These gates retain original fixture settings, source signatures and observations; no reference implementation is supplied to synthesis.

Full native tests run with one worker and the resolved, hashed `djex-fake-z3` helper on PATH. Source and runtime snapshots identify the exact dependency and executables. The public children also capture their backend/kernel identities, exact inputs, displayed candidates, full-signature Lean replays and axiom inventories. Native acceptance is kept separate from the Haskell source corpus and historical release counts.

## Remaining work

This completes native adoption of the stated Haskell milestone. It does not establish all future datatype/kind combinations or arbitrary synthesis completeness. Original integer `at` still requires its source `Int`, supplied default, 168 observations and original limits, with both Haskell engines and all three native modes independently accepted. The original simultaneous nominal-universe selection query remains open. No new Church behavior-ledger cells are closed by a dependency regression run.

Continue with the [current priorities](2026-09-14-synthesis-next-priorities.md).
