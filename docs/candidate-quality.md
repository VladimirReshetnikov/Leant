# Candidate quality before verification

Leant ranks candidates before its verification and display cutoffs. Choose a
profile with:

```text
:set synth-ranking balanced
:set synth-ranking compact
:set synth-ranking diverse
:set synth-ranking legacy
:set synth-ranking
```

`balanced` is the default. All profiles keep the existing search allowances:
`synth-window` 60, `synth-verify` 12 per engine, `synth-shown` 5, Exference
`synth-steps` 4096 and `synth-queue` 1024, and Djinn `synth-budget off` unless
changed explicitly. A different ranking profile does not disable the existing
parallel search schedule or increase those budgets.

## What the profiles prefer

`compact` emphasizes small terms. `balanced` additionally penalizes
elimination structure and gives some preference to different structural
families. `diverse` gives that variety a stronger preference. `legacy` retains
the historical search order, Djinn's frontend size sort, and Exference's
historical selection path.

The shared structural score combines term size, elimination structure, and
exact provider cost. Grouped and successive lambdas have the same size cost;
printed names do not affect size. Let-bound work is counted once, so useful
sharing is preserved. The built-in weights are:

| Profile | Size | Eliminations | Provider cost | Repeated family |
| --- | ---: | ---: | ---: | ---: |
| `compact` | 1 | 1 | 1 | 0 |
| `balanced` | 1 | 3 | 2 | 4 |
| `diverse` | 1 | 3 | 2 | 12 |

Both engines use the shared default structural provider prices: each named
value occurrence costs one, and constructors have no provider surcharge.
Provider discovery and lane order retain their existing relevance priorities.
Exference also retains its established positional source ratings of 0, 20, 40,
and so on, keyed by exact private identities. Those search ratings are separate
from structural prices and are not charged again by the quality score.
Different supplied arguments, providers, constructors, and explicit type
choices remain distinct alternatives.

Diversity groups related operation/dependency shapes, such as `f x` and
`f (f x)`, and adds a cost when selecting another member of an already used
family. It changes order only. This approximate structural relation cannot
justify treating two terms as equal or attaching one term's evidence to
another. Equal scores retain encounter order.

## Where the policy applies

Djinn uses the selected policy when ordering finite search choices before its
raw proof cutoff. Its checked collection is then ranked before Leant applies
verification and output limits. Leant no longer applies a separate size sort
that overrides a structural policy.

Exference uses structural cost in frontier ordering while retaining its step,
queue, depth, and source-rating controls. For structural policies, Leant then
observes at most `synth-window` backend candidates, ranks that finite
collection, and only then renders and deduplicates. Rejected rendering and duplicate output do not earn
replacement observation slots. Search steps spent on rejected or duplicate
derivations remain spent.

`legacy` instead keeps Exference's historical distinct-rendered-group window:
it can inspect duplicate derivations and render failures while collecting up
to `synth-window` distinct groups. That is a compatibility rule, not a refund
of backend steps. Structural policies charge the raw observation before those
operations, so deduplication can only shrink the selected pool. The later
verification cursor and combined-engine exact-text merge retain their own
quotas and provenance rules.

This is Leant's verification-window contract. Djex's interactive Exference
`first` mode separately retains early stopping and does not fill a frontend
quality pool; its structural `all` mode uses that pool. The bounded Haskell
API comparison and these Lean window settings remain unchanged by that
interactive policy.

An observation cap is conservatively reported as truncation without inspecting
an unbudgeted tail. It cannot become a proof of uninhabitation. The policy
improves candidates admitted by the configured search; it cannot recover an
arbitrary better term outside that search or promise global minimality.
Collecting and ranking a finite pool may delay the first output; if the shared
search deadline expires during collection, an already found prefix need not
be displayed. Changing profiles leaves the existing ordinary, provider, and
classical deadline ownership unchanged.

Ordinary, provider, library, and classical lanes use the same selected
profile. With `synth-engine both`, each engine is ranked before the existing
fair merge. Provider discovery, lane priorities, and verification quotas keep
their separate roles.

## Normalization and verification

Obvious matches on already constructed values can be reduced before ranking.
For instance,

```lean
match Sum.inr value with
| .inl a => use a
| .inr b => b
```

can reduce to `value` when the constructor and binding information authorize
the transformation. The implementation retains constructor identity and arity,
checks scopes, and preserves payload sharing through lets. Unsupported or
uncertain cases retain their original form. It does not use an unrestricted
eta law that would erase required higher-rank reconstruction boundaries.
This additional reduction belongs to structural profiles; legacy preserves
the earlier normalization sequence. Leant supplies exact non-strict
constructor arities from its actual total family translation and active
inventory. Generic neutral declarations alone do not grant that authority.

Before reduction, Exference's capture-safe simplifier exposes single-use let
aliases and removes unused lets without contracting eta expansions. It then
applies the shared one-pass constructor reducer and simplifies the resulting
field lets. Newly exposed matches are reduced only while the number of case
nodes strictly decreases, so the original case count bounds the iteration.
Repeated payload uses remain shared, and a visible type application on a
constructor head still blocks its reduction. This iteration belongs to the
Exference adapter; the shared reducer itself remains a single pass.

Djex checks a normalized Exference candidate before constructing its typed
graph; a failed reduction can fall back to the checked original. Leant scores
the authoritative graph when available, preserving the candidate's exact
provider assignments, rendering route, and request authority. Every displayed
term is still re-elaborated by Lean. A smaller score is never an acceptance
certificate.

Length assessment still receives the exact verified batch. Its behavioral
ordering and authorized filtering are applied after this structural selection,
with the same failure-preservation rules. A preference for a smaller inhabitant
does not establish that it implements an intended operation such as reversal.

## Validation status

The Haskell implementation passed all **565 Leant unit tests**, run serially
at unchanged limits in 392.05 seconds after the constructor-alias repair.
These checks cover the policy integration, exact candidate
authority, provider specialization, and existing Length contracts. The build
receipt is `test-church/quality-results/build-leant-04.log`; elapsed test time
is validation metadata, not evidence of a synthesis performance improvement.

The policy matrix passed **84 queries across Djinn, Exference, and the combined
frontend**, with all four profiles at the same configured allowances. All
**139 displayed terms** passed independent Lean kernel replay: **112 closed
terms had empty axiom inventories**, and **27 provider terms used only the
fixture's declared premises**. All queries produced a result. The three paired
Exference `nil` checks and three separate `diverse` projection proofs passed.
The earlier focused repair run passed six queries and 14 terms; it exercises a
subset of this matrix and is not an additional set of distinct coverage cases.

For the Church `nil` type
`∀ A R : Type, (A → R → R) → R → R`, the freshly observed first Exference
result changed from this legacy term:

```lean
fun _ _ f x => match Sum.inr x with | .inl a => f a x | .inr b => b
```

to this term under each structural profile:

```lean
fun _ _ _ x => x
```

Both complete terms were independently checked at the requested type. This is
a concrete improvement before the display cutoff under unchanged settings,
not a claim of globally minimal terms or faster search.

These results use Leant implementation `fb84b96`, vendored Djex `2954b6d2`, and
executable SHA-256
`dab110ad2a7903ac4ef4883898d48532c00cc8c3b1b8d8748aac7744eedffb61`.
The executable remained unchanged during both runs. Receipts are
`test-church/quality-results/matrix-accepted/results.json` and
`test-church/quality-results/focused-repair/results.json`. The matrix uses a
12-candidate window, four displayed outputs, 10,000 Exference steps, 10,000
explicit Djinn choice points, and a 30-second configured synthesis timeout;
the [focused guide](../test-church/quality.md) describes the compatibility
window semantics and independent replay checks.

The opaque-provider replay definitions alone are marked `noncomputable`:
their premises supply values without executable implementations. The closed
definitions remain computable. Correcting those wrappers preserved every
displayed term and all settings from the previous matrix attempt; it did not
relax kernel typing or permitted axiom inventories.

A fresh Church corpus run with each engine also passed on this executable's
default `balanced` profile: **350/350 cases per engine, with all 700 exact
displayed terms independently kernel-replayed and all axiom inventories
empty**. Receipts are
`test-church/quality-results/church-djinn/results.json` and
`test-church/quality-results/church-exference/results.json`. Both runs used a
one-candidate window and a 30-second configured synthesis timeout; Exference
used 4,096 steps, while Djinn retained `synth-budget off` subject to the shared
deadline and intrinsic finite planning caps. Each engine covers 315 total
cases, 16 integer-provider cases, and 19 cases with a supplied ordinary default
argument. Those defaults and Lean's predicative universe discipline follow the
[corpus guide](../test-church/README.md). Fresh acceptance of the 90 broader
rank-N/provider fixture queries remains pending.

The earlier 700-term Church result in the
[corpus guide](../test-church/README.md) belongs to Leant `4757569` with Djex
`e2eb71e` and executable SHA-256
`addfac35b9d82955fc871c177b582a8c043475c0171c22cb17977e0e9f5b9869`.
Those runs preceded the quality policies; their counts are historical evidence
for that unchanged executable, not results from a new balanced-policy run.

See the [focused quality regression guide](../test-church/quality.md),
[Church acceptance guide](../test-church/README.md), and
[synthesis internals](synth-internals.md) for validation and architecture.
