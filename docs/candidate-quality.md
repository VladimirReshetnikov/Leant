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
fair merge. Structural profiles use Djinn alone for proper provider-inventory
prefixes of one, four, and sixteen declarations, then run both engines on the
full inventory. A singleton inventory therefore still runs both engines.
This avoids spending Exference's rated search on an incomplete singleton
before reaching a composition which needs another provider. `legacy` keeps
its previous combined singleton and full stages, with Djinn-only intermediate
prefixes. Standalone engine schedules and discovery order remain unchanged.
`providerStagesWithRanking` selects this schedule without changing the shared
command deadline, raw search allowances, verification quotas, or final merge.

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

Exact provider assignments have a separate target-reconstruction boundary.
Some retained class-instance vectors contain quantified types which cannot
be represented as first-order resolver facts. Their fallback search scheme
therefore erases the leading class context while retaining the complete Lean
vector. A bare provider may then be valid and cheaper in the neutral search
language even though Lean cannot infer its class-dependent type arguments.

For that explicitly marked fallback alone, rendering can restore a whole
retained vector at an otherwise unannotated provider occurrence. Every
leading quantified variable must be absent from the residual value type,
including ordinary argument domains and later contexts. The vector must be
complete, closed, and aligned with the source-derived binder arity; existing
visible choices and nonvacuous variables are not overwritten. Occurrence
aliases keep the canonical type arguments and their Lean domain/visibility
metadata together. Alternatives select complete correlated vectors inside
the existing bounded metadata cohorts, without mixing vector positions,
adding a raw candidate slot, or refunding search work.

The added type choices belong to target rendering, not to the original
checked graph. Such groups are marked `RouteUnobserved` and carry no typed
semantic sidecar or exact typed origin, even when their original candidate
had a graph. They are not mislabeled as the graph-absence compatibility route.
Lean still checks every resulting spelling before display, and Length cannot
obtain a certificate by transferring the bare graph to a reconstructed vector.

The motivating E0 failure was a `Gap.Token` query under Exference: the same
contextual `Gap.polyGlobal` application appeared as both `it1` and `it3`,
consuming two success slots. Verification now suppresses a spelling only after
Lean has accepted that exact, case-sensitive text in the current batch. A rejected spelling may be
retried; a later group containing only already accepted spellings consumes
neither another success nor a verification attempt or failure. The first
accepted variant retains its original ordinal, route, and evidence. This
verification-time filter neither borrows a later candidate's typed receipt
nor changes the earlier combined-engine origin-association rules.

The caller still supplies the same bounded group prefix. Skipped duplicates
do not refill it, refund raw search work, or enlarge any search or display
limit; fresh alternatives can be tried only within that existing prefix.
Length assessment still receives the exact verified batch. Its behavioral
ordering and authorized filtering are applied after this structural selection,
with the same failure-preservation rules. A preference for a smaller inhabitant
does not establish that it implements an intended operation such as reversal.

## Validation status

### Accepted-spelling repair: completed acceptance

The accepted-only verification filter described above is newer than the E0
receipts below. Production revision `043a6a3d` passed **all 578 tests serially
in 533.23 seconds**, and its executable build passed. The executable SHA-256 is
`42c0c9c0a46a35302a04691a93fc68099c5e80bd91305e9a927ba9de9cec5cae`.
`test-church/quality-results/dedup-build-acceptance.json` binds the source
hashes, test/build exits, and executable hash; its logs are
`build-leant-dedup-02.log` and `build-executable-dedup-02.log` in the same
directory.

Fresh live compatibility validation completed **30 fixtures and 265 synthesis
commands** in 1,124.61 seconds at a 30-second synthesis timeout. Twenty-nine
original goldens matched; one differed only by removal of the duplicate
`Gap.polyGlobal` result. Independent review checked 132 input artifacts and
found no lost successes, changed first results, new spellings, remaining
exact duplicates, or control/proof changes. No 600-second retry was needed.
Both retained terms in the changed query passed independent kernel replay
with exactly `Gap.Token` and `Gap.polyGlobal` as axioms. After the sole
golden-line update, an offline production-normalizer comparison matched all
30 files; the original live runner exit **1** remains preserved.

The fresh policy matrix also passed: **84 queries and 136 exact terms**, with
112 empty axiom inventories and 24 confined to declared premises. It combines
two disjoint live/kernel runs, 56 queries/87 terms for the individual engines
and 28 queries/49 terms for combined mode. Both used window 12, shown 4,
10,000 Exference steps, explicit Djinn budget 10,000, and a 30-second timeout.
All three paired Exference `nil` improvements and three projection-diversity
proofs passed; every type and ordered term list is unchanged from E0.
The [final acceptance table](../test-church/README.md#accepted-spelling-repair-completed-acceptance)
links the live, independent-review, kernel, offline-comparison, and matrix
receipts. The full 700-term Church replay remains historical E0 evidence,
not a new-executable replay.

### Historical E0 baseline

Before the accepted-spelling repair, the provider repairs compiled successfully
and passed all **90 broader fixture queries**. Acceptance checkout `5629936`
includes the corrected test assertion
and reviewed goldens, with unchanged production code from `a970d1f`, vendored
Djex `ae986bf5` (synthesis code
`2954b6d2`) and unchanged executable SHA-256
`e0b9c87cae0bc34d59c8d5a34a58fdd5005676913969a80d5503d7281081d025`.
All 90 displayed terms passed independent kernel replay: **78 have empty axiom
inventories and 12 contain exactly their declared premises**. The eight- and
twelve-argument providers retain every named argument in their complete
correlated vectors, and all six layered-provider queries now produce verified
results under the original limits.

The same executable also passed the fresh **84-query policy matrix**, with
all **136 exact displayed terms** independently kernel-replayed: **112 closed
terms have empty axiom inventories and 24 provider terms use only their
declared premises**. All queries produced candidates, all three paired
Exference `nil` checks passed, and all three projection-diversity proofs
passed. `test-church/quality-results/matrix-final/results.json` records zero
live/kernel exit codes and an unchanged executable. Its settings and canonical
input hash match the earlier matrix. The three fewer terms are second
provider alternatives under structural combined mode; every first result and
all other query term lists retain their previous order.

The live fixture receipt is `test-church/quality-results/fixtures-repair/results.json`.
Its original runner exit was 1 solely because three golden files differed;
all four live exits, kernel exits, and pre-golden validation checks succeeded.
After review and application of those three baseline changes, all four goldens
match the preserved captures. `test-church/quality-results/compact-comparison/results.json`
records that final **offline comparison**, not a second synthesis or kernel run.

The focused repair suite passed all nine tests
(`provider-repair-focused-01.log`). The fresh full suite passed **all 569 tests**
serially at unchanged limits in **389.71 seconds**, with process exit zero
(`build-leant-06.log`). This supersedes the earlier stale source-text routing
assertion in `build-leant-05.log`. `build-executable-05.log` records the successful executable
build. These log paths are under `test-church/quality-results/`.

Both full Church runs also passed on that same executable: **350/350 cases
per engine, all 700 exact displayed terms independently kernel-replayed,
and all axiom inventories empty**. The final receipts are
`test-church/quality-results/church-djinn-final/results.json` and
`test-church/quality-results/church-exference-final/results.json`.
Both use the default `balanced` profile, a one-candidate window, and a
30-second configured synthesis timeout. Exference uses 4,096 steps; Djinn
retains `synth-budget off`, subject to the shared deadline and intrinsic
finite planning caps. The 315 total, 16 integer-provider, and 19
explicit-default cases per engine retain the
[corpus guide's](../test-church/README.md) scope and predicative-universe
qualifications.

The E0 ordinary run subsequently completed **26/26 fixtures**. Six matched
their original goldens and 20 required reviewed updates; the original runner
exit remains **1**. Independent replay checked **99 exact changed terms**,
plus **six proof terms and two exact tactic applications** in a separate
proof-context check. Combining these preserved captures with the four compact
fixtures produced a **30/30 offline comparison covering 265 synthesis
commands**, using the production normalizer. This was not another live run.
The [corpus acceptance table](../test-church/README.md#current-quality-policy-acceptance)
links the distinct live, replay, baseline-application, and comparison receipts.

This historical baseline also records a quality counterexample. In
`synth-manual` query 20, of type
`∀ p q : Prop, Decidable p → Decidable q → Decidable (p ∧ q)`, the first
result grew from **two to three `match` expressions**. Both terms type-check;
the new negative branch performs an additional elimination of the second
decision. Structural ranking therefore does not promise a better first
result for every query. The transcript does not show whether the older term
entered the same selected pool, so it proves neither a final-score inversion
nor budget exhaustion. The observed regression remains documented rather
than being presented as an improvement.

### Recorded acceptance before the provider repairs

The following matrix and full-corpus receipts remain valid for their pinned
`dab110…` executable. They do not claim acceptance of the repaired executable.

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
[corpus guide](../test-church/README.md).

The initial broader run on that same executable failed and remains recorded
at `test-church/quality-results/fixtures/results.json`: the ordinary Church
and rank-N fixtures produced all 9 and 69 required kernel-checked terms,
respectively, but the latter had a golden mismatch. Wide exact providers
produced only 2/6 results, with the Exference and combined candidates rejected
by Lean; layered providers produced 4/6 results, with both combined queries
reaching the configured deadline. That original failure remains recorded;
the later 90-query repair run above resolves the missing results through fresh
live synthesis and kernel replay, not by inferring success from this corpus
or policy matrix.

The earlier 700-term Church result in the
[corpus guide](../test-church/README.md) belongs to Leant `4757569` with Djex
`e2eb71e` and executable SHA-256
`addfac35b9d82955fc871c177b582a8c043475c0171c22cb17977e0e9f5b9869`.
Those runs preceded the quality policies; their counts are historical evidence
for that unchanged executable, not results from a new balanced-policy run.

See the [focused quality regression guide](../test-church/quality.md),
[Church acceptance guide](../test-church/README.md), and
[synthesis internals](synth-internals.md) for validation and architecture.
