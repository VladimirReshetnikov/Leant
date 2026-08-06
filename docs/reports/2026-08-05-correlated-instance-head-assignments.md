# Correlated instance-head assignments

**Date:** 2026-08-05

**Scope:** complete, ordered Lean-to-Djex provider instantiations

## Outcome

Leant now preserves the complete type-argument assignment established by one
successful active instance head. If a provider has leading binders
`[a, b, c, d]`, one resolver choice contributes one ordered vector
`[Ta, Tb, Tc, Td]`. It never contributes four unrelated scalar candidates and
never asks Djex to reconstruct the relationship with a Cartesian product.

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

## Complete Lean-side resolution

Discovery still opens at most four leading proper-type binders and retains the
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
   expression metavariables, context-free, and universe-kinded.
5. The arguments serialize in the provider's leading-binder order as one
   vector.

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
    (args TYPE-A TYPE-B TYPE-C TYPE-D)
    (args OTHER-A OTHER-B OTHER-C OTHER-D))
  PROVIDER-TYPE)
```

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
order, binder alpha-scope, rigid family identity, and the exact private
provider name. Provider-prefix fallback slices the assignment metadata with
its owning declaration, so a later or alpha-identically typed provider cannot
donate a vector to an earlier lane.

## Checked Djex boundary

Leant constructs the shared contract:

```haskell
ProviderInstantiationAssignment
  { providerInstantiationAssignmentProvider = privateProviderName
  , providerInstantiationAssignmentArguments = [t1, t2, t3, t4]
  }
```

and calls:

```haskell
runDjinnQueryWithInstantiationAssignments
runExferenceQueryWithInstantiationAssignments
```

Both adapters bound the outer list before entering assignments and bound each
argument spine before entering its members. They resolve the exact retained
polymorphic provider, require exact arity and a context-free scheme, elaborate
arguments in the sealed synonym/kind environment, prove the complete
positional specialization is kind-correct, require closed context-free visible
arguments, and alpha-deduplicate whole vectors per provider. Constructing the
record is an assertion; these checked runners remain the Djex trust boundary.

Djinn consumes one vector once as a direct specialized proof premise. Its
independent proof checker validates the specialized formula before rendering
the term; the renderer then replaces the private proof identity with the real
provider and ordered named type arguments. Exference likewise tries each
vector once at exact global lookup. The exact route supports non-vacuous
leading binders because the assignment already determines their ordered
substitution; it neither performs a Cartesian product nor depends on the legacy
scalar route's vacuous-body guard.

The historical `ProviderInstantiationCandidate` runners remain supported as
an independent scalar-pool compatibility API. Empty exact-assignment calls
delegate exactly to the historical runners, preserving their diagnostics,
ordering, and budget observations.

## Scope and validation

This feature transports evidence which Lean's active instance resolver has
already established. It does not serialize dictionaries, infer arbitrary
polytypes, inspect local term scopes, mix components from separately accepted
assignment vectors, remove engine search bounds, or turn a bounded miss into a
refutation. Closing one selected seed may use other heads for that seed's
instance subgoals and the provider's remaining constraints; all of them must
agree in one metavariable context. Open, contextual, depth-truncated,
wrong-kind, wrong-arity, incomplete, or unsatisfied assignments fail closed.

Pure regressions cover exact parsing, legacy unary parsing, finite outer and
inner bounds, four ordered quantified arguments in all engines, early aggregate
capping, and cross-provider non-donation. Live extraction covers two
independently determining constraints, a selected head with its own instance
prerequisite, and a correlated pair reached only after sixteen unsatisfied
distractor heads. Each case succeeds under standalone Djinn and standalone
Exference; the distractors and an unsatisfied remaining constraint contribute
no partial vector.

On 2026-08-05, `cabal build exe:leant -j1` and
`cabal test all -j1 --test-show-details=direct` passed, including all 161 Leant
unit cases and the vendored Djex matrices. The dedicated Lean 4.31 constraint-
closure transcript passed all six exact applications, and the existing
quantified-provider transcript remained unchanged and passing. All eleven
`synth-*` golden transcripts passed; the only refreshed output was the stable
Exference queue-pruning count in the existing Djinn-provider transcript, while
its candidate and truncation reason remained unchanged.
