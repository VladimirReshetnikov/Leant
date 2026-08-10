# Higher-kinded contextual exact assignments

Date: 2026-08-10

## Outcome

Leant now preserves a bounded higher-kinded nominal argument inside an exact
assignment-local class context. For example, active instance evidence can
select this closed rank-N type:

```lean
class Mark (f : Type → Type) : Prop where
  witness : True

abbrev Choice := {a : Type} → [Mark List] → a → a
```

Djinn, Exference, and combined mode all synthesize and Lean verifies the named
specialization containing

```lean
∀ {a : Type}, [@Mark List] → a → a
```

The extension composes contextual impredicative assignments with the existing
ground-kinded provider wire; it does not add general dictionary search.

## Producer and wire

`FExactContext` already stores each class argument as `(kindArity, fragment)`.
The Lean producer now classifies an argument with the same bounded
`typeKindArity?` used for top-level provider assignments:

- arity zero retains the complete exact proper-type fragment;
- positive arity requires a Lean constant head, rejects unsaturated logical
  structural built-ins, and requires every supplied argument to be a proper
  type;
- a bare head is serialized with its canonical constant name;
- a partial head retains `AppNominal`, its canonical name, and its supplied
  proper arguments.

Forall-domain collection uses the same classifier. A bare higher-kinded head
contributes no visible forall domain, while a partial head's supplied proper
arguments are traversed in source order. Arity remains capped at 64 and the
context argument vector retains the public provider-assignment bound.

## Checked engine bridge

Leant reconstructs every private context class parameter as
`Type → ... → Type` from the recorded arity. The pinned Djex change accepts
those explicit ground kinds only at the shared Djinn environment boundary:
the temporary legacy `ClassDecl` preflight copy drops the unrepresentable
annotation, while the authoritative Inventory, prepared class index, and raw
snapshot retain it. Standalone shared-to-legacy conversion remains strict.

The translated contextual argument is checked against that class kind in both
engines. Lean still elaborates and kernel-checks every rendered candidate.

## Total-arity and rigidity invariants

A residual kind arity is not an ordinary supplied type argument. Query-wide
family planning therefore records a contextual nominal head as an evidence use
at `supplied count + residual arity`. This prevents a partial head such as
`Except String` from being planned at arity one and translated at arity two.

Rigid-atom scans likewise omit the higher-kinded head itself and traverse only
its supplied proper arguments. A bare `List` can no longer be declared once as
a proper atom and again as a unary family. The same decomposition is used by
recursive structural scans, provider-surface closure, and exact-family
planning.

## Fail-closed boundary

The complete assignment vector is still discarded for legacy `FInst`, depth
truncation, dependent dictionary results, term-indexed arguments, open or
variable higher-kinded heads, malformed or over-bound arities, unsaturated
structural built-ins, inconsistent class kind vectors, or any nested
unsupported marker. Ordinary goals and provider schemes keep their previous
instance behavior.

Before family planning or translation, Leant pre-scans each bounded assignment
for exact class-kind and nominal-family arity claims. An internally inconsistent
vector is discarded immediately. If otherwise valid vectors disagree with one
another or with the query baseline, every vector touching the disputed identity
is discarded while unrelated sibling vectors remain available. Empty nominal
heads are malformed. Thus untrusted legacy snapshots cannot turn one bad
assignment into a query-wide engine failure.

## Regression evidence

The Haskell suite covers the wire, bare and partially applied nominal heads,
total-arity planning, rigid-atom exclusion, malformed/open/over-bound controls,
cross-vector class-kind and family-arity conflicts, source-local rejection,
and identical selection through Djinn, Exference, and combined mode. The
generated Lean metaprogram compiles with Lean 4.31. The live
[`synth-provider-contextual-assignment`](../../test/synth-provider-contextual-assignment.txt)
transcript verifies `[Mark List]` in all three modes and retains the existing
dictionary-dependent negative control.
