# Higher-kinded contextual exact assignments

Date: 2026-08-10

Extended: 2026-08-14, when live provider-source contexts gained lexically
scoped higher-kinded variable heads, including partial applications.

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

`FExactContext` distinguishes proper arguments from two positive-arity
forms. A provider-source context may retain its enclosing `FAll` variable,
bare or partially applied only to proper-type arguments. A ground assignment
instead carries its residual arity, exact Lean constant name, and supplied
proper fragments; the live wire encodes that form as
`(kinded N (nominal "Head" ...))`. Historical `(kinded N FRAG)` payloads
remain readable for nonstructural nominal heads, but cannot confer canonical
authority on legacy `Prod` or `Sum` atoms.

The Lean producer classifies each argument with the same bounded
`typeKindArity?` used for top-level provider assignments:

- arity zero retains the complete exact proper-type fragment;
- positive arity requires either a lexically bound provider-source variable or
  a Lean constant head, with every supplied argument a proper type;
- canonical `Prod` and `Sum` are accepted only when supplied arguments plus
  residual arity total two;
- `And`, `PProd`, `Or`, `PSum`, `Iff`, and `Not` remain excluded, as do legacy
  structural payloads;
- a source variable is serialized as `FVar` when bare or as
  `FApp (AppVariable ...)` when partially applied;
- a ground bare head is serialized with its canonical constant name, while a
  partial ground head retains `AppNominal`, that name, and its supplied
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
engines. Canonical `Prod` and `Sum` at total arity two translate to Djex's
boxed-pair and `Either` identities, including partial applications. A direct
provider assignment uses those same identities during substitution, so a
provider body saturated at the assignment head matches ordinary `FProd` or
`FSum` structure. Lean still elaborates and kernel-checks every rendered
candidate.

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
truncation, dependent dictionary results, term-indexed arguments, free or
unscoped variable heads, malformed or over-bound arities, unsupported
structural heads, inconsistent class kind vectors, or any nested unsupported
marker. Canonical `Prod` and `Sum` at total arity two are the structural
exception; legacy structural payloads remain rejected. Supported provider
schemes now retain scoped exact contexts on the plain/binder-only and
accepted-fact Exference lanes; Djinn and the zero-accepted-group exact-evidence
fallback retain their documented context-erased compatibility behavior.

Before family planning or translation, Leant pre-scans each bounded assignment
for exact class-kind and nominal-family arity claims. An internally inconsistent
vector is discarded immediately. If otherwise valid vectors disagree with one
another or with the query baseline, every vector touching the disputed identity
is discarded while unrelated sibling vectors remain available. Empty nominal
heads are malformed. Thus untrusted legacy snapshots cannot turn one bad
assignment into a query-wide engine failure.

## Regression evidence

The Haskell suite covers the canonical nominal wire, bare and partially applied
nominal heads, complementary bare `Prod`/partial `Sum` and bare `Sum`/partial
`Prod` assignments, contextual structural rank-N evidence, total-arity
planning, rigid-atom exclusion, malformed/open/over-bound controls, legacy and
wrong-arity structural rejection, cross-vector class-kind and family-arity
conflicts, source-local rejection, and identical selection through Djinn,
Exference, and combined mode. The generated Lean metaprogram compiles with Lean
4.31. The live
[`synth-provider-contextual-assignment`](../../test/synth-provider-contextual-assignment.txt)
transcript verifies `[Mark List]` in all three modes and retains the existing
dictionary-dependent negative control. The live
[`synth-provider-structural-assignment`](../../test/synth-provider-structural-assignment.txt)
transcript then verifies direct `Prod`/partial-`Sum` saturation together with
contextual `[Binary Prod]` and `[Unary (Sum Fixed)]` evidence in all three
engine modes. The later
[`synth-provider-bound-context-head`](../../test/synth-provider-bound-context-head.txt)
transcript exercises the live partial source head `Choice (F Nat)` through
Djinn, Exference, and combined mode.
