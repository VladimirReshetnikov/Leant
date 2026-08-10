# Six-binder Djex integration in Leant

Date: 2026-08-10

## Outcome

Leant now carries Djex's complete one-through-six leading-binder boundary from
Lean source to checked synthesis. The shared limit applies consistently to:

- Djinn hypothesis, query-local closed-monotype, and loaded-scheme
  instantiation;
- Exference query-derived provider specialization;
- exact provider assignments in Djinn and Exference; and
- Leant's active-instance producer, wire parser, engine filter, and renderer.

Seven or more leading binders remain a deliberate incomplete boundary. A miss
there is `NoEvidence`—displayed as no term found within bounds—and never a
proof of uninhabitability.

The focused hypothesis shape uses an abstract six-argument constructor so an
unrelated structural proof cannot hide the instantiation:

```lean
axiom SixBinder.Six :
  Type → Type → Type → Type → Type → Type → Type

∀ A B C D E F : Type,
  (∀ a b c d e f : Type, SixBinder.Six a b c d e f) →
  SixBinder.Six F E D C B A
```

Djinn, Exference, and combined mode all expose the six inferred type
applications, and Lean 4.31 accepts the rendered term:

```lean
fun _ _ _ _ _ _ x => x _ _ _ _ _ _
```

## One shared finite boundary

Djex's public `maximumProviderInstantiationArguments` is the single authority
for the leading-binder limit. Djinn's instantiation families and checked exact
assignment adapter, plus Exference's query-derived and exact-assignment paths,
all consult that value. The widening changes it from five to six; the existing
16-axiom-per-scheme, 64-axiom-per-family, 512-tuple-attempt, 32 provider-vector,
and Exference query-combination bounds do not increase.

The wide-binder scheduler was already arity-generic. Its source-order windows,
diagonal choices, edge-balanced selections, and bounded Cartesian tail now
admit arity six under the same fixed attempt allowance. This is bounded guarded
instantiation, not general second-order inference: every candidate type still
comes from the checked sequent, query, loaded signatures, or exact external
evidence.

Djex regressions turn the former six-binder sentinels into positive witnesses
for hypothesis and loaded-scheme instantiation and for exact provider
assignments in both engines. New seven-binder controls retain the finite,
inconclusive boundary and ensure an over-wide exact vector is rejected before
its elements can participate in search.

## Lean provider discovery and rendering

Leant's generated discovery program emits the public Djex limit into
`providerEvidenceSpine`; it does not carry a second numeric maximum. It may now
open six leading type binders on one exact provider while retaining the erased
instance constraints which determine them. All established safeguards remain:

- at most 32 active heads are inspected per provider;
- at most 16 alpha-distinct complete vectors survive per provider;
- at most 32 provider/vector associations reach one checked query;
- every vector has exact source arity and positional ground kinds; and
- open, partial, malformed, depth-limited, or unsupported evidence fails
  closed.

The dedicated provider witness declares six independently distinguishable
quantified choices and an active instance for their complete ordered vector:

```lean
class SixBinder.Choice
    (one two three four five six : Type 1) : Prop where
  witness : True

axiom SixBinder.chosen
    {one two three four five six : Type 1}
    [SixBinder.Choice one two three four five six] : SixBinder.Token
```

The live instance assigns increasingly wide quantified function types to the
six positions. Standalone Djinn, standalone Exference, and combined mode must
all retain one application of `SixBinder.chosen` with all six original Lean
binder names and their exact quantified arguments. Complete-vector matching
prevents order loss or cross-head Cartesian reconstruction, and final Lean
elaboration remains the acceptance boundary.

## Preserving the quintic occurrence witness

The `synth-quintic-rankn` transcript proves a separate property: Djinn's
quintuple open/opaque occurrence plans reach every selection through eleven
independent quantified sites. Its `Wide` scheme previously used six adjacent
non-vacuous binders specifically because six lay beyond the instantiation
limit. Once six-binder instantiation became available, that sentinel could be
opened and specialized without requiring the intended quintic occurrence
choice.

`QuinticRankN.Wide` therefore now has seven adjacent binders and a
seven-component product. Leant still coalesces the uninterrupted `FAll` spine
to one Djex `ForallType`, so each `Wide` remains one occurrence site rather than
seven nested sites. Seven binders lie beyond the new instantiation boundary;
the existing ten-site five-opaque/five-open witness and eleven-site dual remain
tests of the quintic plan family. Their direct Lean terms and search bounds do
not change.

## Regression evidence

Pure Leant regressions require both the six-binder hypothesis application and
the six-element exact provider vector under standalone Djinn, standalone
Exference, and combined mode. The generated-program assertion continues to
derive the producer fuel from Djex's public constant.

The live
[`synth-six-binder-rankn`](../../test/synth-six-binder-rankn.txt) transcript
checks the active-instance provider and non-lexical hypothesis shapes in all
three modes through Lean 4.31 elaboration. The widened
[`synth-quintic-rankn`](../../test/synth-quintic-rankn.txt) transcript keeps its
two direct quintic candidates with the seven-binder sentinel. The earlier
five-binder transcript remains intact as historical lower-bound coverage.

No search or inventory cap changes besides the shared leading-binder
eligibility value. Context-bearing hypothesis chains remain opaque, candidate
types remain evidence-supplied, and every positive result is checked first by
Djex and then by Lean.
