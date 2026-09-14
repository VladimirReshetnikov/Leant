# Public Lean universe baseline

The existing strict-implicit native release passes **24 public cells** for
context-free identity and nested callbacks at `Type 1` and at a named universe
`u`. Djinn and Exference each pass ordinary synthesis, the approved named
function plus `where` entrance, and actual-False rejection for all four types.
All **16 displayed implementations** pass independent Lean kernel replay at
their original signatures and observations. All **eight False controls** record
actual falsification without an accepted candidate or inconclusive observation.

This baseline locates existing capability; it does not introduce a native
implementation change or update Leant's Djex dependency pin. In particular,
the contextual dictionary source path still has separate universe restrictions.

## Original source signatures

```lean
∀ A : Type 1, A → A
∀ R : Type, ((∀ A : Type 1, A → A) → R) → R

universe u
∀ A : Type u, A → A
∀ R : Type, ((∀ A : Type u, A → A) → R) → R
```

The parameterized cases declare `u` in the live session and in independent
replay. They are not specialized to universe zero. Observations use two
different `Nat` payloads lifted by `ULift` to the source universe, then inspect
the returned payload. Nested callbacks apply the synthesized polymorphic
identity at that lifted type. Separate kernel preflights check all four
reference terms and their observations before live synthesis.

The live search environment has library discovery, provider discovery and
classical search disabled. Reference implementations and replay declarations
are confined to independent kernel processes. Each query uses a fresh Leant
process with the original resource defaults: shown 1, window 60, verification
quota 12, 4,096 steps, queue 1,024, depth-first Djinn, no choice budget, and
a 20-second synthesis timeout. The outer process guard is 120 seconds.

Accepted-output metadata must identify the selected engine and the exact
displayed typed candidate and renderer variant. Independent replay inserts that
text unchanged, checks the original full signature and both observations, and
requires empty axiom inventories for the implementation and its checking theorem.

## Evidence and limits

The [portable archive](../../test-church/receipts/public-universe-baseline-2026-09-13.zip)
and [SHA-256 manifest](../../test-church/receipts/public-universe-baseline-2026-09-13.json)
retain the controller, source snapshots, original validated-build receipt,
commands, process captures, generated Lean fixtures and terminal results.
The actual native executable, Lean kernel and REPL backend are pinned by hash.
Source and runtime integrity checks pass. Executables and object files are
excluded from the archive, and every archived member is checked against its hash.

These results do not establish contextual universe-polymorphic dictionaries,
universe-bearing global providers, dependent term binders or arbitrary universe
instantiation search. The source adapter currently restricts contextual binders
and nominal/class parameters to Type 0 and retains only explicit universe-zero
constant selections. Its existing higher-universe and constant-universe negative
fixtures remain open implementation requirements.

The next Lean source milestone should preserve exact binder domains and
constant universe selections through that contextual path, including callbacks
above universe zero and distinct universe instantiations of the same declaration.
Do not remove the restrictions without transporting the missing metadata and
checking the original public examples. These source obligations remain separate
from the Church behavior ledger, whose historical counts are unchanged.

See the [delivery re-triage](2026-09-13-synthesis-delivery-retriage.md) for the
remaining product-construction, Exference kind, indexing and extrema work.
