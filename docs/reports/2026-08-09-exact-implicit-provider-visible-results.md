# Exact implicit provider visible results (2026-08-09)

Leant's active-instance inventory already retained the canonical Djex type for
each exact provider assignment. That representation intentionally erases two
Lean details: forall binder visibility and the binder's precise sort domain.
Reconstructing every binder with `_`, `Type _`, or `Prop` therefore failed for
mixed types such as `∀ {P : Prop} (A : Type), P → A → Result`.

Proper-kind live assignments now carry a second, bounded structural payload.
The ordinary fragment records each forall binder's visibility, and a parallel
vector classifies every visible forall domain as `Prop`, `Type`, or general
`Sort`. The canonical fragment remains authoritative for Djex translation,
kind and context checks, alpha-deduplication, search, and provider-result
substitution. The extra domain vector is render-only. Leant uses it only when
the complete leading specified visible-argument vector matches the retained
provider-local vector; malformed vector lengths fail the candidate instead of
falling back to lossy rendering. Lean elaboration and kernel checking remain
mandatory for every rendered term.

The wire extension is backward-compatible. Historical bare fragments,
`(kinded N FRAG)`, and kinded nominal heads still parse unchanged. New live
proper-kind evidence uses
`(kinded 0 (exact (domains prop type sort ...) FRAG))`. Producer, parser,
engine filtering, and renderer require exactly one tag for every visible
forall in `FRAG` and cap a vector at 128 tags. Only this closed vocabulary and
the existing fragment grammar cross the process boundary; no executable Lean
source text is retained or elaborated as metadata. Higher-kinded evidence keeps
its canonical nominal representation.

Two active instances can still have the same canonical Djex assignment while
differing in Lean-only domain metadata. The engine searches that canonical
assignment once, retains every bounded provider-local metadata alternative,
and gives the verifier bounded rendering alternatives. This preserves
alpha-deduplication without silently committing to the first domain spelling.

The live `synth-provider-implicit-visible-result` transcript checks provider
selection in Djinn, Exference, and combined mode at a mixed `Prop`/`Type`
rank-N assignment. It also checks a non-vacuous provider result through
Exference and combined mode: synthesis projects the assigned polymorphic value,
applies it under a quantified goal, and the backend accepts the final term.
The same transcript then gives Lean two instance-selected types with one
canonical Djex fragment and swapped domain vectors. The wrong vector is first;
all three modes must retain the collision and let kernel verification fall
through to the exact `Prop`/`Type` rendering.
Unit coverage pins exact-metadata parsing, domain bounds and vocabulary,
canonical-collision retention, first-vector correlation, binder-count and
vector-length failures, legacy fallback behavior, mixed-domain rendering, and
result specialization.
