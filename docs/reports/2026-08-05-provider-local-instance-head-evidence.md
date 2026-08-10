# Provider-local instance-head evidence

> **Historical scalar snapshot.** This report records the original unary
> provider/type association channel. Leant now preserves complete ordered
> multi-binder vectors; see the
> [correlated instance-head assignment report](2026-08-05-correlated-instance-head-assignments.md).
> The legacy `(candidates ...)` wire form and Djex candidate runners remain
> supported compatibility paths, but live extraction uses exact assignments.
> The later
> [five-binder integration](2026-08-09-five-binder-instantiation.md) widens
> that exact live channel, and its
> [six-binder successor](2026-08-10-six-binder-instantiation.md) widens it once
> more while leaving this scalar snapshot historical.

**Date:** 2026-08-05

**Scope:** bounded Lean-to-Djex evidence for a live provider's visible
proper-type arguments

## Outcome

Leant can now use a closed rank-N type selected by an active Lean instance
head even when that type does not occur in the synthesis query. The focused
end-to-end case is deliberately provider-only:

```lean
axiom Gap.Token : Type

class Gap.C (a : Type 1) : Prop where
  witness : True

instance : Gap.C (∀ x : Type, x → x) := ⟨True.intro⟩

axiom Gap.polyGlobal {a : Type 1} [Gap.C a] : Gap.Token
```

For the atomic goal `Gap.Token`, standalone Djinn, standalone Exference, and
combined mode all produce the following term, which Lean verifies:

```lean
Gap.polyGlobal («a» := (∀ (a0_0 : _), a0_0 → a0_0))
```

The earlier bridge could render this visible quantified argument if the query
itself supplied it. It intentionally erased provider instance binders, however,
so neither engine could learn a type choice known only to Lean's instance
registry. The new path transfers the narrow fact the frontend established—an
exact provider may be instantiated at this closed proper type—without
transferring a dictionary or pretending Djex inferred the type.

Leant pins Djex commit `a0ccba8e`, whose stable facades expose the shared
provider-local candidate contract to both engines.

## Lean-side extraction

Candidate discovery runs independently for each exact live provider. It walks
only the leading provider spine which Leant already represents as visible
`FAll` binders:

1. Open at most four leading proper-type binders with fresh metavariables.
2. Retain intervening erased instance-implicit constraints next to the type
   metavariables they can determine.
3. For each constraint, obtain active instance heads and traverse them in
   Lean's resolver order. The metaprogram reverses the internal
   `getInstances` result to restore that order.
4. Inspect at most 32 heads across that provider's retained constraints.
5. Try each head against a fresh synthetic instance goal under
   `Lean.withoutModifyingState`. Success or failure therefore cannot leak
   metavariable assignments into a later attempt.
6. Instantiate the provider's type metavariables from the successful
   resolution and retain at most 16 distinct serialized proper types for that
   provider, preserving first resolver occurrence.

An unresolved metavariable, universe metavariable, free variable, or loose
bound variable rejects the candidate. Its inferred kind must reduce to a
universe. These checks ensure that the bridge exports a closed proper-type
choice, not an unfinished elaboration problem.

The 32 inspected heads and 16 retained types are **per-provider extraction
bounds**. They are separate from the later command-wide bound of 32
provider/type associations passed into Djex.

## Contextual and depth failure is closed

The selected type itself must be context-free. Leant enforces this on both
sides of serialization:

- the Lean expression scan rejects a visible instance-implicit `forall` in a
  candidate; and
- candidates serialize in goal mode, not provider-erasure mode, so an instance
  binder remains an `FInst` node. The parsed fragment walker rejects `FInst`
  anywhere in the tree and also rejects any `FDepth` truncation.

The second check matters for reducible aliases. The live regression includes:

```lean
abbrev Gap.Contextual := {a : Type} → [Inhabited a] → a
instance : Gap.C Gap.Contextual := ⟨True.intro⟩
```

An early expression scan may see the alias constant rather than its body. The
ordinary goal-mode serializer unfolds enough structure to retain the nested
instance binder, and the exact-fragment `FInst` walk excludes the candidate.
Consequently the contextual instance cannot compete with or replace the valid
`∀ x : Type, x → x` choice. A depth-truncated type is excluded for the same
reason: hidden structure cannot be asserted to be closed and context-free.

This filtering does not claim that contextual polytypes are invalid Lean
types. It says only that erasing their evidence would silently strengthen
them, so they are not valid values for this Djex boundary.

## Provider inventory protocol

The provider S-expression admits an optional evidence block after its binder
metadata:

```text
(provider "Gap.polyGlobal"
  (binders "a")
  (candidates (all "x" (-> (var "x") (var "x"))))
  PROVIDER-TYPE)
```

The parser remains backward-compatible with all established forms:

- historical metadata-free providers;
- binder-only providers, including an explicit empty binder list;
- new providers with a nonempty candidate block; and
- an explicit empty `(candidates)` block.

Live discovery omits the candidate block when it found nothing, preserving the
historical wire shape in the common case. Parsing produces one
`ProviderFragWithEvidence` value which owns the Lean name, provider type,
binder names, and candidate fragments together.

That ownership is the first non-donation boundary. Djinn fallback searches
provider prefixes of 1, 4, and 16 declarations before the full inventory.
Because each prefix slices whole provider records, a candidate attached to a
later declaration is not visible in an earlier lane.

## Haskell translation and aggregate bound

Leant first filters and flattens candidate fragments in provider discovery and
evidence order, then retains only the first
`maximumProviderInstantiationCandidates` entries---currently 32---across the
whole engine invocation. This prefix is taken before a candidate participates
in exact-family planning, rigid-atom collection, or type translation. Evidence
beyond the boundary therefore cannot change the query representation, add a
declaration, fail translation, or even be entered.

Each retained candidate is then translated in the same state as its provider
and goal. It therefore shares the exact private rigid atoms, family
declarations, kind environment, and alpha-aware binder treatment of that
synthesis request. The resulting Djex association contains:

```haskell
ProviderInstantiationCandidate
  { providerInstantiationCandidateProvider = privateProviderName
  , providerInstantiationCandidateType = translatedType
  }
```

The early cap keeps a large but valid Lean environment from turning a provider
lane into an over-wide boundary diagnostic while preserving the same
deterministic prefix Djex would validate. A regression places bottom in the
33rd evidence position and pins that the fragment is never forced.

The private provider name is exact. It is not a scheme key: two providers with
alpha-identical types remain different sources, and evidence for one cannot
make the other eligible.

## Checked Djex runners

Leant calls the pinned stable entry points:

```haskell
runDjinnQueryWithInstantiationCandidates
runExferenceQueryWithInstantiationCandidates
```

Both runners validate the aggregate 32-association bound before entering
elements, then resolve every association against the exact sealed-session
provider. They elaborate the candidate in that session's synonym and kind
inventory, require a closed context-free proper type, and alpha-deduplicate
only within one provider while preserving source order. Their historical
runners are exact empty-list delegates, so provider queries without evidence
retain the old diagnostics, ordering, and finite-budget observations.

Djinn turns a checked association into a direct proof-producing specialization
premise for that exact provider. The proof checker validates the specialized
formula before the private premise is rewritten into a visible application of
the source provider. The evidence-enriched plan is positive-only and cannot
strengthen a negative verdict.

Exference stores associations in a private exact-global map. Only lookup of
that global reads its entries; scoped values and sibling globals keep their
existing paths. Supplied choices form a separately capped visible-application
tail after ordinary implicit instantiation, monomorphic Haskell instance-head
choices, and query-derived choices, so the historical prefix is preserved.

The two implementations differ internally, but their observable locality
contract is the same: the candidate belongs to one named provider, and its
presence cannot authorize another provider with an equal scheme.

## Trust and scope boundary

Lean owns the source-language justification: an active instance head solved the
erased provider constraint and thereby fixed a proper-type argument. Djex owns
only the narrower checked boundary: exact provider identity, kind and synonym
elaboration, closure, context-freedom, alpha deduplication, and finite input.
Lean's elaborator still reconstructs the actual instance argument when it
checks the rendered term.

This division is intentionally not a general proof interchange and not general
impredicative inference. The feature does not:

- serialize dictionaries or class methods into Djex;
- search arbitrary local scopes;
- invent a polytype not established by a checked query route or supplied Lean
  evidence;
- admit open, contextual, or depth-truncated candidates;
- donate evidence between providers or provider-prefix lanes;
- remove the four-binder, 32-head, 16-candidate, 32-association, engine search,
  or rendering bounds; or
- turn a bounded miss into proof that no term exists.

It is bounded, evidence-directed support for a useful rank-N/impredicative
case. Full impredicative inhabitation remains undecidable and outside the
contract.

## Validation

The implementation commits record:

- all 157 focused Leant unit tests passing;
- the complete test and CLI matrix of the pinned Djex submodule passing;
- a freshly linked Leant executable; and
- the Lean 4.31 `synth-quantified-provider` golden transcript passing.

Pure regressions cover provider-only success in Djinn, Exference, and combined
mode; parsing of historical, binder-only, nonempty-evidence, and explicit-empty
forms; exact-tree contextual filtering; and cross-provider non-donation. The
live transcript verifies the explicit `Gap.polyGlobal` application in all
three engine modes while the reducible contextual alias remains excluded.
