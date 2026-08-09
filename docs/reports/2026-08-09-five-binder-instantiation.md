# Five-binder Djex integration in Leant

> **Follow-up.** The
> [query-local closed-monotype extension](2026-08-09-query-local-closed-monotype-instantiation.md)
> adds a positive-only final Djinn family without changing this report's
> five-binder eligibility, tuple allowances, or six-binder boundary.

**Date:** 2026-08-09

## Outcome

Leant now carries Djex's complete one-through-five instantiation boundary from
Lean source to verified terms. The vendored Djex revision admits five leading
binders in Djinn hypothesis and loaded-scheme instantiation, Djinn exact
provider evidence, and Exference query-derived and exact provider
specialization. Six binders remain the conservative incomplete boundary.

The pure Leant boundary now handles the formerly unsupported function shape:

```lean
∀ A B C D E R : Type,
  (∀ a b c d e : Type, a → b → c → d → e → R) →
  A → B → C → D → E → R
```

Standalone Djinn exposes all five inferred applications in its rendered
candidate. The focused live regression uses an abstract constructor to pin a
non-lexical source-order tuple without producing a large family of equivalent
function applications:

```lean
axiom FiveBinder.Five : Type → Type → Type → Type → Type → Type

-- synthesis goal
∀ A B C D E : Type,
  (∀ a b c d e : Type, FiveBinder.Five a b c d e) →
  FiveBinder.Five E D C B A
```

Lean 4.31 accepts the unique displayed term:

```lean
fun _ _ _ _ _ x => x _ _ _ _ _
```

## Closing the live provider-producer gap

Leant already imported Djex's public
`maximumProviderInstantiationArguments` when filtering parsed exact evidence.
Its generated Lean discovery program nevertheless called
`providerEvidenceSpine fuel 4 source`, so the producer could never discover a
five-element instance-head vector that the checked consumer now accepted.

The fragment program now emits the public Djex limit into that call. The
generated worker and Haskell-side filter therefore share one authority:

```text
providerEvidenceSpine fuel 5 source
```

The fragment representation remains independent of Djex syntax; this is only
a finite numeric bridge contract. The program regression constructs its
expected spelling from the same public constant, preventing another literal
from silently drifting.

Live discovery still inspects at most 32 active heads, retains at most 16
alpha-distinct complete vectors per provider, and passes at most 32
provider/vector associations in total. Every vector must have exact provider
arity, closed context-free arguments, and bounded positional ground kinds.
Djex still productively checks the outer assignment, its argument spine, every
kind, and the fully substituted provider body.

## Engine and rendering coverage

Pure Leant boundary tests now retain five distinct quantified arguments in
source order under standalone Djinn, standalone Exference, and combined mode.
Each rendered application names all five original Lean binders. A separate
Djinn test confirms that adjacent `FAll` nodes coalesce into one five-binder
Djex `ForallType` and that rendering inserts five inferred type placeholders.

The focused
[`synth-five-binder-rankn`](../../test/synth-five-binder-rankn.txt) transcript
turns live-library premises off, selects Djinn, submits the exact goal above,
and records the Lean-checked candidate without a truncation note. Before that
goal, the same session declares a five-binder class/provider pair, discovers
its active instance, and checks a rendered application containing all five
named quantified arguments. Exact provider correlation in Exference and
combined mode is pinned deterministically by the pure boundary test.

## Preserving quintic occurrence evidence

The existing quintic transcript previously defined `QuinticRankN.Wide` with
five non-vacuous adjacent binders because that lay beyond the old four-binder
instantiation rule. The widened engine could now instantiate an opened `Wide`
and stop those goals from proving that the quintuple occurrence plans were
necessary.

`Wide` now uses six adjacent binders and a six-component product. Leant still
coalesces that uninterrupted spine into one Djex `ForallType`, so each `Wide`
remains exactly one positive occurrence site. The ten-site non-prefix
five-opaque/five-open witness and the eleven-site dual retain the same direct
Lean terms, while six-binder instantiation cannot rescue them.

## Verification

The complete synthesis-boundary suite passes all 181 tests. That sweep includes
the generated-worker contract, five ordered exact arguments in all three engine
modes, five-binder function elimination, and both six-binder quintic sentinels.
The dedicated five-binder golden replays successfully against Lean 4.31 with
both its live instance-derived provider application and non-lexical hypothesis
instantiation, and neither query reports truncation. The widened
`synth-quintic-rankn` golden also replays unchanged apart from the six-binder
`Wide` declaration.

## Bounds and soundness

No search or provider-inventory cap increased besides the leading-binder
eligibility value. Djinn retains its 16-axiom-per-scheme, 64-axiom-per-family,
and 512-attempt bounds. Exference retains 32 query-derived combinations, and
exact assignments remain complete vectors consumed once. Leant's live head,
vector, aggregate, kind, and translation limits are unchanged.

This is guarded impredicative support, not general second-order inference.
Context-bearing hypothesis chains remain opaque, candidates remain limited to
types supplied by the sequent or checked external evidence, and six or more
leading binders remain unsupported. Every displayed candidate still passes
Djex's independent checker and final Lean elaboration. A bounded miss remains
"no term found within bounds" and never becomes a refutation.
