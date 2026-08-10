# Correlated instance-head assignments

> **Follow-up.** The
> [five-binder integration](2026-08-09-five-binder-instantiation.md) raises the
> shared vector and live-discovery boundary from four to five. The examples and
> numeric limit below describe this report's historical tree.
> The
> [six-binder successor](2026-08-10-six-binder-instantiation.md) raises the
> current boundary from five to six while preserving the complete-vector
> contract.

**Date:** 2026-08-05

**Scope:** complete, ordered Lean-to-Djex provider instantiations

## Outcome

Leant now preserves the complete type-argument assignment established by one
successful active instance head. If a provider has leading binders
`[a, b, c, d]`, one resolver choice contributes one ordered, ground-kinded
vector `[(Ka, Ta), (Kb, Tb), (Kc, Tc), (Kd, Td)]`. It never contributes four
unrelated scalar candidates and never asks Djex to reconstruct the relationship
with a Cartesian product. Each `K` is the bounded first-order kind which Lean
proved for that exact argument: a chain of `Type`-domain arrows ending in
`Type`.

This closes the correlation gap left by the earlier
[provider-local instance-head evidence](2026-08-05-provider-local-instance-head-evidence.md)
channel. The scalar protocol was sufficient for unary providers, but a
multi-parameter instance can establish a relationship which disappears when
its arguments are flattened. The correct tuple can then fall behind a
backend's product cap or be combined with arguments from another active head.

A representative live provider is:

```lean
class Gap.C4 (a b c d : Type 1) : Prop where
  witness : True

instance : Gap.C4
    (forall x : Type, x -> x)
    (forall x : Type, x -> x -> x)
    (forall x : Type, x -> x -> x -> x)
    (forall x : Type, x -> x -> x -> x -> x) :=
  <| True.intro |>

axiom Gap.correlated {a b c d : Type 1} [Gap.C4 a b c d] : Gap.Token
```

The desired vector is the 28th zero-based-lexicographic tuple (index 27) in
the old four-way product of those four scalar types. It lies beyond Djinn's
historical first-sixteen specializations. Retaining the instance head's vector
directly makes the exact application reachable in standalone Djinn,
standalone Exference, and combined mode without widening the old product
bounds.

## Multiple and heterogeneous live vectors

Several successful heads for one exact provider remain several alternatives;
whole-vector deduplication removes only repeated alpha-equivalent vectors. The
higher-kind live regression uses:

```lean
axiom Wrap : Type -> Type
axiom Pair : Type -> Type -> Type
axiom Triple : Type -> Type -> Type -> Type

instance : AlternativeChoice Wrap := <| True.intro |>
instance : AlternativeChoice (Pair Nat) := <| True.intro |>
axiom alternative {F : Type -> Type}
    [AlternativeChoice F] : AlternativeToken

instance : MultiVacuousChoice Wrap (Triple Nat) := <| True.intro |>
axiom multiVacuous {F : Type -> Type} {G : Type -> Type -> Type}
    [MultiVacuousChoice F G] : MultiVacuousToken
```

The two `alternative` heads contribute the distinct complete unary vectors
`[(kind-1, Wrap)]` and `[(kind-1, Pair Nat)]`. Standalone Djinn renders
`Higher.alternative («F» := Higher.Wrap)` before
`Higher.alternative («F» := (@Higher.Pair Nat))`; standalone Exference ranks
the same exact alternatives in the opposite order. Combined mode is Djinn-first
and stable-deduplicates the Exference spellings. Thus result order belongs to
each engine's ranking policy, while the regression requires both exact
applications once in every mode.

The `multiVacuous` head contributes one heterogeneous vector
`[(kind-1, Wrap), (kind-2, Triple Nat)]`. It renders exactly as
`Higher.multiVacuous («F» := Higher.Wrap) («G» := (@Higher.Triple Nat))` in
all three modes. This simultaneously checks a bare unary constructor, a
partially applied ternary constructor with residual binary kind, and positional
kind agreement across a complete correlated vector.

## Complete Lean-side resolution

Discovery still opens at most four leading type binders and retains the
provider's erased instance constraints. For each constraint it visits active
heads in Lean resolver order, with at most 32 heads inspected per provider.
Every selected head is evaluated inside its own
`Lean.withoutModifyingState` scope.

A head is accepted only after its complete provider obligation closes:

1. `tryResolve` applies that exact selected head to a fresh goal.
2. Every instance-implicit subgoal returned by the selected head is synthesized
   under the returned metavariable context.
3. Every other erased constraint in the provider telescope is synthesized in
   source order under that same context.
4. All opened type arguments are instantiated, closed, free of universe and
   expression metavariables, and context-free. The type of each argument must
   reduce to a bounded `Type -> ... -> Type` kind; Leant records its arrow
   count instead of erasing it to proper type.
5. The kinded arguments serialize in the provider's leading-binder order as
   one vector.

Keeping the seed fixed matters. Re-running ordinary instance synthesis for the
seed constraint could select a different head and would no longer enumerate
the resolver alternatives Leant claims to preserve. Closing the selected
head's subgoals and the remaining constraints matters just as much. For
example, `{a b} [C a] [D b] -> Token` needs both constraints to determine the
complete vector, while `{a b} [C a b] [Missing a b] -> Token` must contribute
nothing even if the `C` head alone fixes both metavariables.

An attempt which fails any closure step contributes no partial pool. It also
cannot consume one of the sixteen retained-vector positions with an unusable
assignment. Metavariable effects are restored before the next active head is
tried.

## Provider protocol

The live provider inventory carries complete vectors explicitly:

```text
(provider "Gap.correlated"
  (binders "a" "b" "c" "d")
  (instantiations
    (args (kinded 0 TYPE-A) (kinded 0 TYPE-B)
          (kinded 0 TYPE-C) (kinded 0 TYPE-D))
    (args (kinded 0 OTHER-A) (kinded 0 OTHER-B)
          (kinded 0 OTHER-C) (kinded 0 OTHER-D)))
  PROVIDER-TYPE)
```

The integer after `kinded` is the remaining `Type`-arrow arity: zero denotes
proper type, one denotes `Type -> Type`, and so on. A higher-kinded nominal
argument also carries its canonical Lean head and any already supplied
proper-type arguments, so `Higher.Wrap` and `Higher.Pair Nat` do not depend on
a pretty-printed atom spelling; for example, a bare wrapper is encoded as
`(kinded 1 (nominal "Higher.Wrap"))`. Historical exact vectors without
`kinded` are still read as all-proper-kind assignments.

`(instantiations)` is a valid explicit empty block. An `(args)` vector is
invalid because it cannot correspond to a polymorphic provider
specialization. Historical metadata-free and binder-only provider entries
remain valid.

The parser also continues to read the earlier `(candidates T1 T2 ...)` form.
Each old scalar becomes one unary vector (`[[T1], [T2], ...]`). This is wire
compatibility only: Leant deliberately does not recreate multi-binder products
from a legacy scalar pool, because doing so would reintroduce the correlation
bug.

## Bounds and translation

The finite limits now apply to complete assignments:

- at most four ordered arguments in one vector;
- at most 64 `Type`-arrow domains in live discovery, the serialized wire, and
  engine filtering, producing at most 129 constructor nodes;
- at most 129 constructor nodes in each supplied Djex `GroundKind`, checked
  independently at the adapter trust boundary;
- at most 32 active heads inspected for one provider;
- at most 16 alpha-distinct complete vectors retained for one provider; and
- at most 32 provider/vector associations passed to one Djex execution.

Leant takes the command-wide 32-vector prefix before any vector argument enters
family planning, rigid-atom collection, or type translation. Every vector must
be nonempty, match the provider's exact leading-`FAll` arity, fit the four
argument limit, and contain no `FDepth` or `FInst` node. A vector failing any
condition is discarded as a whole. Its siblings and its provider declaration
remain available.

Each surviving vector is translated in one shared state, preserving argument
order, binder alpha-scope, rigid family identity, each argument's kind-arrow
count, and the exact private provider name. Leant reconstructs a Djex
`GroundKind` by folding that count into `FunctionKind ProperTypeKind ...` and
pairs it with the translated argument. Provider-prefix fallback slices the
assignment metadata with its owning declaration, so a later or
alpha-identically typed provider cannot donate a vector to an earlier lane.

## Checked Djex boundary

Leant constructs the shared contract:

```haskell
KindedProviderInstantiationAssignment
  { kindedProviderInstantiationAssignmentProvider = privateProviderName
  , kindedProviderInstantiationAssignmentArguments =
      [(k1, t1), (k2, t2), (k3, t3), (k4, t4)]
  }
```

and calls:

```haskell
runDjinnQueryWithKindedInstantiationAssignments
runExferenceQueryWithKindedInstantiationAssignments
```

Both adapters bound the outer list before entering assignments and bound each
argument spine before entering its members. They resolve the exact retained
polymorphic provider, require exact arity and a context-free scheme, and then
productively preflight every supplied `GroundKind` in that assignment under the
pinned 129-node ceiling. The preflight counts at most 129 constructors and
returns the one-over-bound sentinel if work remains, without entering the
pending subtree or paired type. It therefore rejects oversized and cyclic
caller-built kinds before recursive kind inference, same-provider equality, or
kind conversion. The adapters then validate supplied binder kinds against every
occurrence in the retained body, require one binder-kind vector per exact
provider, elaborate each argument at its supplied positional kind, require
closed context-free visible arguments, prove the complete specialization is
kind-correct, and alpha-deduplicate whole vectors per provider. Constructing
the record is an assertion; these checked runners remain the Djex trust
boundary.

Djinn consumes one vector once as a direct specialized proof premise. Its
independent proof checker validates the specialized formula before rendering
the term; the renderer then replaces the private proof identity with the real
provider and ordered named type arguments. Exference likewise tries each
vector once at exact global lookup. The exact route supports non-vacuous
leading binders and also constraint-only or otherwise vacuous higher-kinded
binders: Lean supplies the kind fact which the erased provider body cannot
infer. It neither performs a Cartesian product nor depends on the legacy
runner's vacuous-to-`Type` default.

The historical `ProviderInstantiationCandidate` runners and unkinded exact
assignment runners remain supported as compatibility APIs. The latter still
infer binder kinds from the provider body and default a vacuous binder to
`Type`; Leant deliberately uses the kinded contract above. Empty kinded calls
remain exactly inert, preserving historical diagnostics, ordering, and budget
observations.

## Scope and validation

This feature transports evidence which Lean's active instance resolver has
already established. It does not serialize dictionaries, infer arbitrary
polytypes, inspect local term scopes, mix components from separately accepted
assignment vectors, remove engine search bounds, or turn a bounded miss into a
refutation. Closing one selected seed may use other heads for that seed's
instance subgoals and the provider's remaining constraints; all of them must
agree in one metavariable context. At this slice's original boundary, open,
contextual, depth-truncated, wrong-kind, wrong-arity, incomplete, or unsatisfied
assignments failed closed. Unsaturated structural built-ins `And`, `Prod`,
`PProd`, `Or`, `Sum`, `PSum`, `Iff`, and `Not` were also unsupported until
canonical unsaturated identity was modeled. Saturated occurrences retained
their existing structural translations.

Pure regressions cover exact parsing, legacy unary parsing, finite outer,
inner, and 129-node kind bounds, four ordered quantified arguments in all
engines, early aggregate capping, cross-provider non-donation, kind/order
preservation, repeated-vector deduplication, and distinct same-provider
alternatives under Djinn, Exference, and combined mode. Live extraction covers
two independently determining constraints, a selected head with its own instance
prerequisite, and a correlated pair reached only after sixteen unsatisfied
distractor heads. Each case succeeds under standalone Djinn and standalone
Exference; the distractors and an unsatisfied remaining constraint contribute
no partial vector.

The 2026-08-06 higher-kind transcript
[`synth-provider-higher-kind-assignment`](../../test/synth-provider-higher-kind-assignment.txt)
adds constraint-only providers with vacuous higher-kinded binders. Besides
`Higher.vacuous («F» := Higher.Wrap)`, its golden output contains the
heterogeneous arity-1/arity-2 `Higher.multiVacuous` application and both exact
`Wrap` and `Pair Nat` alternatives of `Higher.alternative` under standalone
Djinn, standalone Exference, and combined search. Djinn and Exference rank the
two alternatives differently, while combined mode retains Djinn's order; all
three still contain exactly the same required applications. The transcript
also retains the earlier mixed higher-kinded/rank-N vector, so these vacuous
paths do not weaken positional kind or argument-order preservation.

## Successor: contextual and structural nominal assignments

The
[contextual-assignment successor](2026-08-09-contextual-provider-assignments.md)
first extended exact evidence into assignment-local class contexts. The
subsequent
[higher-kinded contextual extension](2026-08-10-higher-kinded-contextual-assignments.md)
now distinguishes canonical nominal arguments from legacy fragments. Canonical
`Prod` and `Sum` are accepted at total arity two, both as direct provider
assignments and inside contextual rank-N arguments. They reuse Djex's boxed-pair
and `Either` identities, so their saturation in a provider body agrees with the
ordinary structural representation.

This is a deliberately narrow successor to the historical boundary above.
Legacy structural payloads remain fail-closed, as do unsaturated `And`,
`PProd`, `Or`, `PSum`, `Iff`, and `Not`, whose `Prop` and sort distinctions are
not carried by the ground-kind wire. The live
[`synth-provider-structural-assignment`](../../test/synth-provider-structural-assignment.txt)
fixture verifies bare and partially applied `Prod`/`Sum` evidence under Djinn,
Exference, and combined search.

On 2026-08-06, `cabal build all -j1` and
`cabal test leant-synth-tests -j1 --test-show-details=direct` passed, including
all 175 Leant unit cases against the updated vendored Djex. The dedicated
higher-kind transcript passed its exact single-vector, heterogeneous-vector,
and multiple-alternative applications under Djinn, Exference, and combined
search. All 13 `synth-*` golden transcripts passed under the normal per-query
timeouts; `synth-djinn-providers` was rerun in isolation at the same default
timeout after one load-sensitive aggregate miss. This alignment change
regenerated no golden output.
