# Query-local closed-monotype instantiation in Leant

**Date:** 2026-08-09

## Outcome

Leant now carries Djex <code>d0d7db95</code>'s additive Djinn family for
specializing a context-free quantified hypothesis at a closed, forall-free
type already present in the checked query. This closes a local gap that the
existing loaded-scheme family could not address: the quantified value is a
lambda-bound hypothesis, not a retained environment declaration.

The focused shape uses only abstract Lean constants:

~~~lean
axiom QueryClosed.Mono : Type
axiom QueryClosed.Token : Type
axiom QueryClosed.Indexed : Type → Type

(∀ a : Type,
    (a → QueryClosed.Token) → a → QueryClosed.Indexed a) →
  (QueryClosed.Mono → QueryClosed.Token) →
  QueryClosed.Mono →
  QueryClosed.Indexed QueryClosed.Mono
~~~

Keeping <code>a</code> in the indexed result matters. An unindexed result can
admit unrelated self-instantiations and would not prove that search discovered
<code>QueryClosed.Mono</code> as the selected closed type.

## Three separate instantiation families

Djinn deliberately does not widen its historical family in place:

1. The historical query-local family uses goal variables, skolems from opened
   positive quantifiers, sealed premise scopes, and guarded quantified
   subtrees. Its plan and candidate prefixes remain unchanged.
2. The new query-closed family revisits only context-free schemes embedded in
   the requested goal. It fairly mixes the historical candidates with closed,
   forall-free subtrees collected from that checked query, then retains only
   tuples containing at least one such closed candidate.
3. The loaded family continues to operate on exact polymorphic declarations
   retained from the sealed environment. It may use closed monotypes from the
   query and loaded value signatures, but it does not donate those declarations
   to the local family.

The new structural and nominal plans are final additive supersets. They carry
historical local axioms, loaded-scheme axioms, and checked caller-supplied
provider evidence, so a proof may compose those capabilities without changing
any established priority prefix. Djex has a direct regression composing the
new local choice with an existing loaded specialization.

## Live Lean behavior

The provider-free
[<code>synth-query-closed-rankn</code>](../../test/synth-query-closed-rankn.txt)
transcript disables live-library premises and runs every engine mode. Djinn
returns two independently Lean-checked terms:

~~~lean
fun f => f _
fun f g x => f _ (fun _ => g x) x
~~~

Both instantiate <code>f</code> at <code>QueryClosed.Mono</code>. The first
leaves the remaining arguments eta-reduced; the second constructs an equally
valid constant callback from <code>g x</code>. Standalone Exference, under a
128-step bound, returns the compact <code>fun f =&gt; f _</code>. Combined
mode retains both Djinn terms while labeling Exference's incomplete tail
separately. Every displayed candidate survives final elaboration by Lean 4.31.

A pure Leant boundary regression projects the same abstract nominal
application and requires a visible <code>f _</code> candidate from standalone
Djinn, standalone Exference, and combined mode.

## Bounds and evidence

No eligibility or search allowance increases. The query-closed family retains:

- at most five leading context-free binders;
- at most 16 retained axioms per scheme;
- at most 64 axioms in the family; and
- at most 512 attempted instantiation tuples.

Closed candidates may have any kind, but the complete substituted scheme body
must still translate and kind-check. Open, contextual, or forall-bearing
monotypes are not admitted by this route. Guarded quantified candidates remain
the historical rule rather than being relabeled as closed monotypes.

Every plan in this additive family is positive-only. Its existence poisons
exhaustive negative evidence: if bounded search finds no candidate, the result
is <code>NoEvidence</code>—reported by Leant as no term found within bounds—not
a refutation. Candidate soundness remains independently checked by Djex and
then by Lean.

## Validation

The complete Leant synthesis-boundary suite passes all 182 tests. The new pure
case covers Djinn, Exference, and combined mode. The dedicated golden replays
successfully against Lean 4.31 in all three modes, and the package build plus
whitespace checks pass.
