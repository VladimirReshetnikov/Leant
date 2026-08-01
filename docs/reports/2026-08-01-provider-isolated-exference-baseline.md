# Provider-isolated Exference baseline

**Date:** 2026-08-01

**Scope:** Leant's REPL orchestration around standalone Djex Exference search

## Outcome

Standalone Exference now protects ordinary structural synthesis from pressure
created by the live Lean provider inventory. When the serialized goal is
accepted as an in-fragment structural query, Leant runs Exference once with no
providers and asks Lean to elaborate the rendered candidates against the exact
goal. Only when no baseline variant verifies does it discover the bounded live
inventory and run provider-enriched Exference.

This restores live transport for goals such as:

```lean
((∀ a : Type 1, Option a) → Option (∀ b : Type, b → b))
```

The direct `fun x => x _` is present in the structural projection, but an
eighty-provider inventory could previously fill or prune Exference's bounded
frontier before that term was ranked. Provider isolation makes the structural
answer independent of that unrelated inventory, while Lean verification keeps
the ordinary trust boundary intact.

## Dispatch policy

The policy applies only when both conditions hold:

1. the selected engine is exactly `EngineExference`; and
2. fragment translation reports no structural refusal.

The resulting dispatch matrix is:

| Engine and goal class | First search | Provider fallback | Result behavior |
| --- | --- | --- | --- |
| `EngineExference`, structural/in-fragment | Provider-free Exference | Only after no baseline term verifies | Stop at the first verified lane |
| `EngineExference`, atomic or provider-open refused | Provider-enriched Exference | Not a separate lane | Preserve access to live values |
| `EngineBoth` | Existing combined engine behavior | Existing combined engine behavior | Djinn candidates first, then Exference-only candidates |
| `EngineDjinn` | Djinn | None | Unchanged |

A hard refusal that providers cannot open remains an honest out-of-fragment
result. The direct path refers to atomic/refused goals for which provider
discovery is already admissible; provider isolation does not broaden the
fragment or make providers repair depth truncation.

`EngineBoth` deliberately does not adopt the standalone two-pass policy. Its
Djinn projection is already isolated from providers inside the engine, and its
public contract is to merge Djinn candidates with later Exference-only
alternatives. Changing it would alter candidate enumeration rather than merely
protect standalone Exference.

## Verification before fallback

The provider-free baseline is not considered successful merely because the
engine emits a candidate. Leant renders the bounded candidate-group prefix,
restores exact constructors and globals, and asks the Lean backend to elaborate
each variant as:

```lean
example : (Goal) := candidate
```

Only a survivor ends the command. An engine result whose variants all fail
Lean verification is a baseline miss and may proceed to provider discovery.
Thus isolation changes search scheduling, not the trusted boundary: no term is
shown or bound without kernel-checked elaboration against the original goal.

If provider-enriched Exference rediscovers an exact rendered spelling that was
already rejected during baseline verification, Leant removes that spelling
from the fallback groups before asking Lean again. Empty groups are discarded;
if every enriched variant was already checked, the fallback becomes an
ordinary bounded no-term outcome. This avoids repeating failed backend work
and failed temporary elaboration environments while leaving genuinely new
provider candidates available.

## One command deadline

The baseline and fallback do not each receive a fresh timeout. Leant computes
one command deadline from `LEANT_SYNTH_TIMEOUT` before the first search. The
fallback engine receives only the time remaining after baseline search, Lean
verification, and provider discovery. `LEANT_SYNTH_TIMEOUT=0` retains the
explicit wait-forever behavior.

A baseline timeout is reported as no answer, not a verdict, and an engine error
is preserved directly; a provider inventory cannot repair either condition.
This prevents the two-lane policy from silently doubling the configured
wall-clock allowance or replacing a useful baseline diagnostic.

## Deliberate tradeoff

After any baseline term verifies, Leant does not discover providers and does
not enumerate provider-based alternatives. This is intentional. The policy
optimizes for reliably finding an already available structural term under a
bounded frontier, avoids the latency of provider discovery, and keeps the
first result stable as the environment grows. A user who needs provider
alternatives after structural success does not currently get an exhaustive
combined list from standalone Exference; `both` retains its separate merged
behavior, but is not a substitute for enumerating every Exference provider
alternative.

## Validation

The focused engine tests continue to cover provider-free proper-type family
transport. The Lean 4.31 rank-N golden adds three end-to-end controls:

- real `Option` transport under standalone Exference verifies that the
  structural baseline succeeds before a root-local inventory can crowd it out;
- atomic `Demo.Secret` resolves through `Demo.secretValue`, proving that an
  atomic goal still goes directly to providers; and
- `Unit → Demo.Secret` has a valid structural shape but no verified baseline
  inhabitant, then resolves through the same live provider, proving that a
  structural miss reaches fallback.

Djinn golden coverage remains unchanged, and `EngineBoth` retains its existing
isolation and candidate ordering tests. Failed-baseline variant removal is part
of the fallback orchestration described above; it is independent of whether a
particular golden miss emitted a structural spelling to reject.

## Relationship to parametric family sharing

The scheduling policy is independent of the fragment representation described
in the
[query-wide family report](2026-08-01-query-wide-parametric-inductive-families.md).
That projection makes real `Option` transport available to Exference; the
provider-isolated baseline ensures the live environment cannot hide it before
Lean gets the chance to verify it. Atomic and structural-miss controls ensure
the protection does not turn provider search off when it is actually needed.
