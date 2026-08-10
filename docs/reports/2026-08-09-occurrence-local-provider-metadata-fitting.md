# Occurrence-local exact provider metadata fitting

Date: 2026-08-09

## Outcome

Leant now selects exact Lean-only provider metadata per visible application
occurrence and uses that same selection for both fragment fitting and final
rendering. This closes a correctness and completeness gap left by canonical
Djex assignment deduplication.

Two closed Lean types can translate to one Djex `VisibleTypeArgument` while
still differing in source forall visibility. For example,

```lean
∀ {A : Type}, A → A
∀ (A : Type), A → A
```

The first result is consumed as `f x`; the second needs `f _ x`. Previously,
Leant fitted the entire engine candidate once using the first retained source
assignment, then varied only the rendered provider type argument. A fallback
could therefore spell the second type while retaining the first type's fitted
application, which Lean correctly rejected. Two uses of the same provider and
canonical vector were also forced to share one global metadata choice.

## Coupled bounded selection

Before fitting, the renderer now gives every provider occurrence whose complete
visible vector matches retained exact evidence a private internal provider
identity. Only assignments whose canonical visible vector matches that
occurrence are retained on the private identity; bare, partial, and otherwise
unmatched uses stay on the original provider without assignment alternatives.
Fresh identities avoid every provider, constructor, and other global already
present in the candidate.

The established metadata scheduler then selects alternatives independently for
those occurrence identities. Each selected provider map travels together with
the expression produced by `fit`, and `render` receives that exact pair. The
base selection, source-ordered individual-alternative prefix, and bounded
Cartesian tail keep their previous priority. Results from metadata selections
are round-robin interleaved within each fitting cohort before the existing
per-domain lane limit, so one selection's style or instantiation-site fallbacks
cannot starve another retained source choice. The historical non-forced fitting
cohort remains wholly ahead of forced eta-expansion fallbacks.

No engine input or public name changes. The private aliases exist only after
Djex has checked a candidate and map back to the same exact Lean global. The
renderer constructs at most 32 provider metadata maps. Each of the inferred,
`Type`, and `Prop` rendering lanes retains at most 32 spellings, for at most 96
final spellings before cross-lane deduplication. Repeating a collision at more
occurrences than fit in that map budget does not expand it: zero-padded private
keys preserve source order, the earliest individual alternatives are retained,
and later occurrences use the base metadata unless a retained Cartesian choice
also changes them.

## Regression evidence

The pure renderer regression uses the same canonical identity assignment
twice. It requires one occurrence to select an implicit source forall and
render `f x`, while the other selects an explicit source forall and renders
`g _ x`. It also updates the older single-occurrence collision expectation so
each implicit spelling is paired with binder-free result use.

The live
[`synth-provider-metadata-fitting`](../../test/synth-provider-metadata-fitting.txt)
transcript defines two instance-selected types with the canonical body
`A → A`, putting the implicit-forall choice first. Its goal requires the
explicit-forall `Marker`, and the provider consumes a value at the selected
type. At a 64-step bound, standalone Exference and combined mode fall through
to this kernel-checked term:

```lean
MetadataFitting.make
  («a» := (∀ (a0_0 : Type _), a0_0 → a0_0))
  (fun _ x => x)
```

The complete 222-test synthesis-boundary suite, package build, focused live
golden replay, and whitespace checks cover this change.
