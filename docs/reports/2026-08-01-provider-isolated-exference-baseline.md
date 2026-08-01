# Provider-isolated baseline and staged Djinn fallback

**Date:** 2026-08-01

**Scope:** Leant's REPL orchestration around Djex provider search

## Outcome

Every engine mode protects ordinary structural synthesis from pressure created
by the live Lean provider inventory. When the serialized goal is accepted as an
in-fragment structural query, Leant runs the selected engine once with no
providers and asks Lean to elaborate the rendered candidates against the exact
goal. After a nonterminal baseline miss it discovers the bounded live inventory
and runs provider-enriched search. A complete Djinn refutation remains terminal
and keeps the REPL's explicit constructive-to-classical fallback policy.

This restores live transport for goals such as:

```lean
((∀ a : Type 1, Option a) → Option (∀ b : Type, b → b))
```

The direct `fun x => x _` is present in the structural projection, but an
eighty-provider inventory could previously fill or prune Exference's bounded
frontier before that term was ranked. Provider isolation makes the structural
answer independent of that unrelated inventory, while Lean verification keeps
the ordinary trust boundary intact.

The successor in the same implementation now admits those providers to Djinn.
Within fixed bounds, Djex specializes retained context-free loaded schemes at
closed monotypes or guarded rank-N polytypes. Leant first gives the
highest-ranked provider an isolated Djinn lane, preventing a lossy or irrelevant
later declaration from crowding the fixed candidate prefix. After a verified
miss it tries discovery-order prefixes of four and sixteen providers before the
full bounded inventory, allowing small multi-provider compositions to surface
before unrelated declarations displace them from the candidate window.

The live regression makes that boundary concrete. `Demo.consume` is ranked
first, an unrelated constrained `Demo.global` second, and the required
`Demo.produce` third. Prefixes three through six retain the verified
`fun x => Demo.consume (Demo.produce x)` candidate; adding `Demo.C.mk` at rank
seven displaces it with a large candidate that Lean rejects, and the full
nine-provider lane still misses. The scheduled width-four lane therefore
recovers a real composition that the former singleton-then-full policy lost.

## Dispatch policy

The baseline policy applies when both conditions hold:

1. any synthesis engine is selected; and
2. fragment translation reports no structural refusal.

The resulting dispatch matrix is:

| Engine and goal class | First search | Provider fallback | Result behavior |
| --- | --- | --- | --- |
| `EngineExference`, structural/in-fragment | Provider-free Exference | Full ranked inventory after no baseline term verifies | Stop at the first verified lane |
| `EngineDjinn`, structural/in-fragment | Provider-free Djinn | After a nonterminal miss: provider prefixes 1, 4, 16, then full bounded inventory | Preserve a complete refutation; otherwise stop at the first verified lane |
| `EngineBoth`, structural/in-fragment | Provider-free combined search | Combined singleton, Djinn-only intermediate prefixes 4 and 16, then combined full inventory | Djinn candidates remain before new Exference candidates; avoid repeating Exference at intermediate widths |
| Any engine, atomic/provider-open refused | Provider-enriched stages | No separate baseline | Preserve access to live values |

A hard refusal that providers cannot open remains an honest out-of-fragment
result. The direct path refers to atomic/refused goals for which provider
discovery is already admissible; provider isolation does not broaden the
fragment or make providers repair depth truncation.

`EngineBoth` now follows the same verified baseline/fallback policy. Inside the
combined singleton and terminal fallback invocations, both Djinn and Exference
receive the active provider slice; their public merge order remains Djinn
candidates first and new Exference candidates afterward. Intermediate widths
four and sixteen are Djinn-only.

A terminal Djinn refutation is scoped to the complete provider-free structural
calculus. It is not presented as an exhaustive theorem about all declarations
or axioms in Lean's live environment, whose inventory is intentionally bounded
and best-effort. For `Prop`, the REPL's existing classical fallback remains the
explicit policy for adding classical principles after constructive refutation.

## Verification before fallback

The provider-free baseline is not considered successful merely because the
engine emits a candidate. Leant renders the bounded candidate-group prefix,
restores exact constructors and globals, and asks the Lean backend to elaborate
each variant as:

```lean
example : (Goal) := candidate
```

Only a survivor ends a candidate-producing lane. An engine result whose
variants all fail Lean verification is a baseline miss and may proceed to
provider discovery; a complete Djinn refutation ends the lane as a proof-backed
verdict instead. Thus isolation changes search scheduling, not the trusted
boundary: no term is shown or bound without kernel-checked elaboration against
the original goal.

If a provider-enriched lane rediscovers an exact rendered spelling already
rejected during baseline or an earlier provider stage, Leant removes that
spelling before asking Lean again. Empty groups are discarded; if every wider
variant was already checked, the fallback becomes an ordinary bounded no-term
outcome. This avoids repeating failed backend work and failed temporary
elaboration environments while leaving genuinely new provider candidates
available.

## One command deadline

The baseline and provider stages do not each receive a fresh timeout. Leant
computes one command deadline from `LEANT_SYNTH_TIMEOUT` before the first
search. Each later engine lane receives only the time remaining after earlier
search, Lean verification, and provider discovery.
`LEANT_SYNTH_TIMEOUT=0` retains the explicit wait-forever behavior.

A baseline timeout is reported as no answer, not a verdict, and an engine error
is preserved directly; a provider inventory cannot repair either condition.
This prevents the multi-lane policy from silently multiplying the configured
wall-clock allowance or replacing a useful baseline diagnostic.

### Nested strict/relaxed engine lanes

A later recursive-projection follow-up adds a separate pair inside each
Exference invocation. The first request keeps Exference's normal requirement
that every introduced binder be used. Only when that request produces no
renderable candidate group does the same session and environment run again
with unused inputs admitted. Each request may spend the configured
`synth-steps` budget, but neither renews the outer command deadline described
above.

This inner pair does not change provider discovery or fallback ordering. A
strict candidate preserves the established prefix and ends that invocation;
the relaxed lane exists to express finite omissions such as returning a
constructor payload while leaving its recursive tail unopened. If both the
provider-free and provider-enriched passes are ultimately reached, each pass
may apply this strict-first pair, still under one `LEANT_SYNTH_TIMEOUT`
allowance. Unused pattern binders render as real `_` wildcards and the resulting
term remains subject to the same Lean verification as every other candidate.

## Deliberate tradeoff

After any baseline term verifies, Leant does not discover providers and does
not enumerate provider-based alternatives. This is intentional. The policy
optimizes for reliably finding an already available structural term under a
bounded frontier, avoids the latency of provider discovery, and keeps the
first result stable as the environment grows. A user who needs provider
alternatives after structural success does not currently get an exhaustive
combined list from any mode. Combined search still merges the two engines
inside a reached lane, but is not a substitute for enumerating every provider
alternative.

## Validation

The focused engine tests continue to cover provider-free proper-type family
transport and now exercise exact, polymorphic, and combined-mode providers in
Djinn. The Lean 4.31 rank-N golden adds three Exference controls:

- real `Option` transport under standalone Exference verifies that the
  structural baseline succeeds before a root-local inventory can crowd it out;
- atomic `Demo.Secret` resolves through `Demo.secretValue`, proving that an
  atomic goal still goes directly to providers; and
- `Unit → Demo.Secret` has a valid structural shape but no verified baseline
  inhabitant, then resolves through the same live provider, proving that a
  structural miss reaches fallback.

A dedicated Djinn provider golden adds seven end-to-end controls:

- atomic `Demo.Seed` resolves directly through `Demo.seedValue`, covering the
  provider-open refusal path;
- `Demo.Seed → Demo.Seed` returns structural identity without discovering a
  same-typed live definition, pinning provider-free first-result ordering;
- an ordinary universe-polymorphic `Demo.sealedBox` definition specializes at
  `Nat`, at opaque `Demo.Seed`, and at `∀ x : Type, x → x`; and
- `Demo.consume` alone cannot solve `Demo.Input Demo.Index → Demo.Output
  Demo.Index`, but the widened inventory composes it with `Demo.produce`; and
- combined mode reuses the same verified `Demo.sealedBox` provider.

Failed-variant removal is part of the fallback orchestration described above;
it is independent of whether a particular golden miss emitted a spelling to
reject.

## Relationship to parametric family sharing

The scheduling policy is independent of the fragment representation described
in the
[query-wide family report](2026-08-01-query-wide-parametric-inductive-families.md).
That projection makes real `Option` transport available to either engine; the
provider-isolated baseline ensures the live environment cannot hide it before
Lean gets the chance to verify it. Atomic, structural-miss, and polymorphic
Djinn controls ensure the protection does not turn provider search off when it
is actually needed.
