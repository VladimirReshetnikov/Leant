# Structured contextual provider schemes and exact assignments

Date: 2026-08-09

Updated: 2026-08-14 for scoped higher-kinded provider contexts, live
provider-scheme retention, and Length ground constraint discharge.

## Outcome

Leant's wire preserves a closed nominal class context in both places where live
provider evidence may need semantic identity:

- inside the exact type argument established by one active Lean instance head;
  and
- in the source scheme of the live provider whose instance-implicit binder
  introduced that context.

The original assignment case closes the gap for provider assignments such as

```lean
abbrev Choice := {a : Type} → [Inhabited a] → a → a

class Pick (a : Type 1) : Prop where
  witness : True

instance : Pick Choice := ⟨True.intro⟩
axiom chosen {a : Type 1} [Pick a] : Token
```

The active head can contribute `Choice` as the exact named argument to
`chosen` in standalone Djinn, standalone Exference, and combined mode. Djex
sees and checks the contextual argument rather than a context-erased
approximation, and Lean still elaborates and kernel-checks every rendered
candidate.

The later provider-scheme extension covers an ordinary constrained source such
as `forall a. C a => List a`. An exact-evidence Exference provider retains that
context only when at least one fact group survives selection; with no selected
group, its successfully translatable bounded vectors use the historical erased
fallback. On the retained lane, Handoff sees the exact nonempty leading context
and classifies its behavioral summary as conditional. The explicit Exference
candidate whose final visible type application owns the association retains the
activated ground obligation in its opaque certificate. An ordinary direct
occurrence remains unassociated and Length-ineligible, so it cannot reach query
construction or Z3.

## Shared structured context wire

The generated serializer uses one bounded semantic `FExactContext` form in
admitted provider-scheme and exact-assignment positions. After reducing an
instance binder there, it accepts only a genuine nominal Lean class application
whose ordered arguments have bounded first-order ground kinds. The node carries
the exact class name, each kind/fragment argument, and the contextual body.
Arity-zero arguments keep their complete fragment. Since the 2026-08-14
extension, a positive-arity provider-scheme argument may retain its enclosing
source `FAll` variable either bare or partially applied only to proper-type
arguments, while a ground assignment keeps a canonical bare or partially
applied nominal head with only proper-type supplied arguments. No pretty-printed
binder syntax becomes executable metadata. A class binder nested
inside one of those supplied fragments stays an unsupported `FInst`; Leant
drops that complete vector locally rather than granting recursive context
authority.

Leant translates each exact class head to a collision-free private Djex class
on the retained lane, keeps its constraints in the corresponding `ForallType`,
and maps the private name back to the same fully qualified Lean class during
rendering.
Constraint arguments and the body participate in closure, schema equivalence,
specialization, and forall-metadata traversal, so retained source metadata stays
paired with the scheme Djex checked. Existing renderer fitting still does not
infer a higher-kinded replacement by matching two positive-arity
variable-headed contextual fragments; an already retained source application
renders structurally and Lean remains the verifier. Provider-source contexts
additionally survive through the exact Exference run authority and Length
Handoff. Djinn retains its historical context-erased provider projection;
positive Djinn terms still require Lean verification, but that projection has
no conditional Length authority.

Ordinary goal serialization still uses `FInst` only as a render-time wildcard.
It does not gain contextual search or dictionary authority. Exference retains
a supported provider context on the plain/binder-only and accepted-fact lanes,
because erasing it there would unsafely strengthen a constrained global at the
behavioral boundary. An unsupported provider context instead truncates the
provider and makes it unavailable. Exact-evidence providers with no accepted
fact group use their successfully translatable bounded assignments under the
historical erasure. Djinn's compatibility projection deliberately keeps that
erasure and never originates Length authority.

## Exact active-instance provenance

For every exact live provider independently, discovery may emit an
`(instantiations ...)` block only after it has fixed one top-level active Lean
instance head and closed that head's subgoals plus all remaining provider
constraints in the same isolated metavariable context. A success is one
complete, ordered, closed vector. This metadata remains attached to its source
provider for specialization and rendering.

The Length bridge may also instantiate the source provider's leading class
constraints with that exact vector. The complete specialized constraint group
must be closed, forall-free, ground, and accepted by a trial seal of the exact
Exference inventory. Each novel member of an accepted group is a synthetic
Djex instance declaration with no binders or prerequisites. The empty prerequisite
list records that Lean already closed the complete top-level chain; Leant
transports no dictionary or proof term. Group admission is transactional, so a
discovery pass commits no vector-local translation state, every source-ordered
trial replays only its previously accepted keys plus the candidate, and the
final replay retains exactly the accepted keys. A rejected group therefore
leaves no partial fact, declaration, plan, or renderer state; an all-rejected
provider recovers all successfully translatable vectors from its bounded,
filtered historical context-erased assignment lane.

Only current `(instantiations ...)` metadata has that provenance. Historical
`(candidates ...)` payloads remain readable as bounded search hints, have their
provider context erased in both engine projections, and cannot originate
synthetic ground facts. The parser therefore keeps the two wire generations
distinct rather than normalizing a legacy scalar into an authority-bearing
exact vector.

The derived fact is inventory-global even though its source assignment is
provider-local. It may satisfy a matching ground obligation activated by a
different provider in the same exact Exference/Length inventory. This does not
donate a provider specialization: the live Lean discovery ran against the
top-level environment without query givens, and the fact states only the class
assertion whose entire prerequisite closure was already resolved there.

Accepted facts are appended after all provider values in stable
provider/vector/constraint order and deduplicated against the complete bounded
inventory. An explicit empty exact block emits none. In Exference, vectors
with accepted contextual facts do not also enter the historical context-free
assignment adapter; they retain render metadata and authorize only their
replayed ground-fact groups. An exact-evidence provider with no accepted group
recovers all successfully translatable vectors from its bounded, filtered
erased assignment fallback. Djinn's erased projection keeps
historical assignment behavior.

## Fail-closed boundary

The extension remains deliberately narrower than general constrained
impredicativity. A provider or complete exact vector is rejected when its
relevant context contains:

- legacy raw `FInst` or depth truncation (`FDepth`);
- malformed or over-bound contextual wire data;
- metavariables, free variables, loose binders, or an unresolved class head;
- a contextual result type that depends on the dictionary term;
- term-indexed class arguments; or
- any unsupported class-argument kind or fragment shape.

Dependent provider instance telescopes and unsupported provider-source
contexts become depth truncation instead of a context-free approximation. An
open, quantified, unsupported, or non-ground specialization contributes no
synthetic instance fact. Existing provider identity, arity, positional-kind,
vector, and search bounds remain in force.

Djex Length independently accepts only closed, alias-free, forall-free,
first-order ground obligations under the exact session inventory and bounded
default resolver limits. There are no query givens. Z3 runs only after static
discharge has produced a checked Length problem, so solver status or model
replay can never serve as dictionary evidence.

Higher-kinded context arguments, total-arity family planning, and the matching
Djinn shared-class-kind boundary are detailed in the
[follow-up report](2026-08-10-higher-kinded-contextual-assignments.md). The
certificate, identity, and behavioral boundary is detailed in the
[live ground-discharge report](2026-08-13-live-contextual-provider-ground-discharge.md).

## Regression evidence

Pure regressions cover structured provider-root and assignment-local parsing,
legacy provenance separation, legacy `FInst` rejection, context-preserving
translation and rendering, exact provider selection, and fail-closed dependent
contexts. The live
[`synth-provider-contextual-assignment`](../../test/synth-provider-contextual-assignment.txt)
transcript keeps the assignment-local `Choice` as the only active selection and
requires every engine mode to produce a Lean-verified specialization. Its
`HigherContext.Choice` and dictionary-dependent controls retain the established
higher-kinded success and dependent failure boundaries.

The production Length regression covers the complementary provider-root path:
an exact live assignment derives the ground fact required by a contextual
associated provider. It selects the explicitly certified candidate from the
Exference lane; an ordinary direct conditional occurrence in the same result
remains ineligible. After independent static discharge, the candidate seals as
v3 and the problem uses concrete encoding v4. The fake-Z3 run observes query
ordinal 0, issues no `get-value`, and replays a zero-input, result-0
counterexample whose `FiniteSpineModelUnderAssumedProviderLaws` basis names the
exact provider. Controls using legacy candidate metadata or missing exact
closure cannot originate the fact.
