# Djinn public ground-kind synthesis and remaining behavioral gap

Djinn's public source path now retains explicit star/arrow binder kinds from
parsing through candidate checking and Haskell rendering. This includes local
and nested polymorphism, vacuous binders, shadowing, transparent aliases,
constrained callbacks and an impredicative pair. The scope is Haskell ground
kinds; it does not establish kind polymorphism, Exference execution or Lean
universe support.

The public matrix also retains a harder adjacent-input behavioral query which
still misses. Successful synthesis of an inhabitant and successful selection of
the requested behavior are recorded separately. The 160-cell Church behavior
ledger is unchanged by these additional source tests.

## What changed

Public parsed requests carry checked source-kind obligations separately from
their kind-erased query projection. Request identity includes those obligations.
Execution checks them against the actual session inventory and expands synonyms
using that session's declarations. Contradictory kinds and stale binder paths
are rejected before search.

The private Djinn source checker assigns fresh lexical identities to binders and
transports their kind facts through opening, capture-avoiding substitution,
unification and selected instantiations. It seals the graph and exact kind table
together in the opaque typed candidate. A public read-only accessor exposes the
table; its association constructor remains package-private. Candidate equality
includes retained kind metadata, while candidates without it retain the previous
equality and display behavior.

The Haskell renderer uses those exact identities when declaring nested forall
binders and generated polymorphic helpers. This repairs a concrete failure:
discarding a vacuous `f :: * -> *` annotation caused GHC to infer `f :: *` in the
generated implementation. Ordinary variable occurrences remain undecorated.

Kind-directed completion also respects type-synonym arity. A parameterized
synonym such as `type Identity x = x` is no longer proposed as the unsaturated
type argument `@Identity`. Behavioral GHC preflight enables
`LiberalTypeSynonyms`, allowing the original polymorphic alias signature to be
checked without weakening or expanding the user's displayed signature.

Exference requests retain and validate the same source obligations, but its
execution guard remains until its own checker and provider-evidence path retain
them. The private constructor does not give another engine's graph checker
authority over Exference's selected evidence.

## Public acceptance matrix

The reusable controller is
[Djex public-kind controller](https://github.com/VladimirReshetnikov/Djex/blob/main/test-church/public_kinded_source.py).
It runs one-shot synthesis and named-function `where` queries, compiles the exact
displayed implementation at the full original signature, executes the
observation, and issues an actual `where Prelude.False` query. Its environment
supplies only a transparent alias and a methodless class/instance; reference
implementations are never synthesis providers. Invalid source kinds have a
separate rejection check.

The cases cover:

- Higher-kinded identity and a nested callback accepting that identity.
- Vacuous root, local, callback and result binders.
- A callback that shadows a higher-kinded outer binder with a proper-type binder.
- Adjacent polymorphic inputs whose vacuous binders have different kinds.
- A transparent alias around a polymorphic argument.
- A class-constrained polymorphic callback.
- An impredicative pair of identities under a vacuous higher-kinded binder.

The adjacent-input one-shot observation deliberately permits any type-correct
projection by supplying the same value twice. Its behavioral query instead
requires both values:

```haskell
probe :: forall a.
  (forall (f :: * -> *). a) ->
  (forall (f :: *). a) -> (a, a)
-- Required observation:
probe @Int (7 :: forall (f :: * -> *). Int)
           (9 :: forall (f :: *). Int) == (7, 9)
```

The prototype and root each check four candidates and reject all four, with zero compiler
errors or timeouts. Inspection of its emitted alternatives shows that all use
the first input. Switching only to the existing interleaved strategy produces
the same four falsifications. This is a construction or candidate-retention
lead, not evidence that the signature has no matching implementation. A trace
must locate where second-input alternatives disappear before changing search.

The reduced raw-prover diagnostic now reproduces a concrete product-alternative
loss without polymorphism. With `bridge : A -> B`, `left : A`, and `right : A`,
the atomic `B` query finds both applications. The `(B,B)` query finishes after
six charged choices with 4,994 of 5,000 choices unused, returning only
`(bridge left, bridge left)`. The independent proof checker accepts
`(bridge left, bridge right)`. This run uses interleaving and term alternatives.
It therefore identifies a missing alternative in that product search path,
rather than budget starvation or an invalid witness. The witness is checked
separately and never supplied as a synthesis provider.

This is a small general construction problem worth promoting. The raw result
does not by itself prove that a proposed repair will close the original
kinded-source query. Require the original `(7,9)` observation, full-signature
replay and False control after a causal change, at unchanged search bounds.

## Validation and provenance

The final root strict seven-target build and all seven suites pass:
540 foundation, 108 typed-candidate/certificate, 128 private source-graph,
187 integration, 38 API, 137 Djinn unit and 138 CLI tests (**1,276 total**).
The root source excludes the unrelated, unaccepted `queryFunctionCarriers`
experiment retained in the validation checkout. Apart from line endings, that
experiment is the only Haskell/Python source difference between the two tested
snapshots. The root streaming regression passes without that extension; no
performance claim is inferred from the separate run timings.

The initial root controller stopped the serial CLI suite at its 1,800-second
outer wall guard, after the other six suites passed. Its failure receipt is
retained. The separate CLI-only rerun completed successfully: **all 138 tests
passed in 2,377.98 seconds**, process exit zero, with unchanged source and runtime
hashes. It used visible per-test progress and a 7,200-second outer guard;
query limits and single-threaded execution were unchanged. This closes the CLI
regression gate. The original archive remains immutable; the completed rerun has
a separate [portable receipt](../../test-church/receipts/djinn-kinded-source-cli-2026-09-13.zip)
and [SHA-256 manifest](../../test-church/receipts/djinn-kinded-source-cli-2026-09-13.json).

The final root public matrix has **11/11 one-shot exact GHC replays**,
**10/11 named-`where` exact GHC replays**, **11/11 actual-False controls**, and
a passing invalid-kind rejection. Its overall status remains `failed`, because
the adjacent-input behavioral query still has no accepted candidate. Each of
the 21 compiled implementations executes its recorded observation successfully.
This is acceptance of ten full two-entrance cases plus one type-inhabitation
case, not an all-green behavioral matrix. Source and executable hashes remain
unchanged throughout both root runs.

The [portable archive](../../test-church/receipts/djinn-kinded-source-2026-09-13.zip)
and [SHA-256 manifest](../../test-church/receipts/djinn-kinded-source-2026-09-13.json)
retain exact source snapshots, controllers, commands, emitted fixtures, raw
outputs and terminal receipts. Executables and object files are excluded;
runtime hashes remain recorded. Prototype and root runs have distinct labels,
including every unsuccessful attempt described below.

The prototype's strict seven-target build passes. Its foundation (540), typed
candidate/certificate (108), private source-graph (128), integration (187) and
API (38) suites pass. One of 137 Djinn unit tests fails: the expected
function-accumulator composition is absent from the first 256 streaming
observations. The CLI controller omitted the main executable and fake tools
from `PATH`, so that attempt is not a valid CLI regression result. Both failed
attempts remain part of the evidence; the root run corrects the helper paths
and excludes the experimental carrier change.

Earlier public attempts preserve the discoveries rather than overwriting them:
four original vacuous/adjacent outputs failed GHC before the kind-table renderer
repair; the repaired six-case one-shot run passes. A larger matrix then exposed
the unsaturated synonym and preflight-extension defects, plus a fixture import
error. An import-only audit separates that fixture error from the production
failures. After the production repairs, the local, alias and constrained cases
pass both entrances and their False controls; the adjacent behavioral miss
remains explicit.

Leant's dependency pin and native acceptance remain separate from Haskell root
validation. No native feature claim follows from copying this report or its
receipts into Leant.

## Revised next actions

1. Retain the completed 1,276-test regression checkpoint and the adjacent
   behavioral miss as separate outcomes. Keep unaccepted experiments isolated.
2. Validate one bounded product-construction repair, then require the original
   adjacent-input query, exact replay and False control at unchanged search bounds.
3. Probe public Lean identity and nested callbacks above universe zero, and
   trace Exference's lexical kinds through its own checking and provider evidence.
   Neither independent source milestone depends on further extrema experiments.
4. Probe integer `at` and trace the distinct Lean Djinn `length` miss before
   committing to another broad extrema implementation experiment.
5. Give extrema one bounded witness-guided diagnosis. Reopen reductions only
   when a materially different causal construction trace justifies it.

See the [full delivery re-triage](2026-09-13-synthesis-delivery-retriage.md) for
contextual evidence, supplied-fold trees, acceptance criteria and deferred ideas.
