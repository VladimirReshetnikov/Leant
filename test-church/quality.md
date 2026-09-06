# Focused candidate-quality acceptance

See the [policy guide](../docs/candidate-quality.md) for the score, legacy
behavior, and raw candidate observation contract. The historical E0 executable
(`e0b9…`) passed the **84-query/136-term policy matrix**, all 90 broader fixture
terms, and all **700 Church terms**. Its 26 ordinary fixtures also completed;
reviewed captures now match all 30 goldens in a separate offline comparison.
The subsequent accepted-spelling repair passed **578 unit tests**, a fresh
**30-fixture/265-command** live compatibility run with one reviewed
duplicate-removal drift, and a fresh **84-query/136-term** kernel-replayed
matrix. Historical Church receipts remain separate from these new checks.

The standalone runner compares all four ranking policies under identical
settings and independently kernel-replays every displayed alternative:

```powershell
python test-church/quality_probe.py --self-test
python test-church/quality_probe.py --prepare-only
python test-church/quality_probe.py --leant PATH_TO_BUILT_LEANT_EXE
```

The default matrix contains 56 queries: Djinn and Exference, four policies,
and seven cases covering projections, Church `nil`, tuple construction,
repeated input use, closed and ambient impredicative construction, and declared
providers. `--engine`, `--policy`, and `--case` may be repeated to narrow a
diagnostic run. `--engine both` additionally tests the combined frontend.
The runner does not build Leant or modify existing transcripts or goldens.
The accepted 84-query run explicitly included all three engine modes:

```powershell
python test-church/quality_probe.py --leant PATH_TO_BUILT_LEANT_EXE --engine djinn --engine exference --engine both --output test-church/quality-results/matrix-final
```

Defaults are `synth-window 12`, four displayed outputs, 10,000 Exference steps,
**10,000 explicit Djinn choice points**, and a 30-second configured synthesis
timeout. Structural Exference policies charge raw candidates against the
window; legacy retains its distinct-rendered-group window. Equal settings
therefore preserve the documented compatibility behavior, rather than claiming
identical raw observation counts for every profile. The search timeout is not an
end-to-end limit on startup, serialization, or standalone kernel replay.
These fixed probe settings are independent of Djex's interactive `first`
policy, which retains early stopping instead of collecting a quality pool.
All settings are checked against interleaved REPL acknowledgments, and the
executable hash must remain unchanged throughout the run.

The kernel module contains each complete displayed term at its original
requested type. `#print axioms` must report no dependencies for the six closed
examples. The provider example permits only its three declared premises:
`Quality.Token`, `Quality.cheap`, and `Quality.expensive`; its exact actual
subset is recorded. Only replay definitions for this opaque-provider example
use `noncomputable def`, because the supplied premises have no executable
implementation. The six closed examples retain ordinary computable `def`
wrappers. This distinction neither supplies new premises nor bypasses kernel
typing or the exact axiom-inventory checks.

The provider names do not assign prices: both named values
have the same default structural call cost, while applying `Quality.cheap` to
a `Unit` value makes a larger term than the direct `Quality.expensive` value. Existing
source relevance still affects discovery and search separately. This live
example records the selected terms without requiring one provider name to win;
the focused size-only integration test checks the compact term at the same
cutoff. The companion Haskell API probe separately asserts explicit exact-name
cost overrides, which the Lean REPL does not expose.

For exact class-instance assignments whose context must be erased during
neutral search, the renderer can restore omitted leading type choices only
from complete retained vectors. The quantified variables must be vacuous in
the residual value type, including ordinary argument domains and later
contexts; each argument must remain closed and aligned with the source binder
arity. Existing explicit choices and nonvacuous dependencies are excluded.
Whole-vector alternatives and their exact Lean metadata use the existing
bounded rendering cohorts, with no new raw candidate slots. Reconstructed
groups use `RouteUnobserved` and have no typed semantic sidecar: a graph of the
bare source cannot certify the added instantiation. The mandatory independent
Lean replay and exact-vector/premise checks remain in force.

Structural combined mode searches proper provider prefixes with Djinn only
and runs both engines on the full inventory; a singleton inventory still runs
both. Legacy keeps its combined singleton/full stages and Djinn-only
intermediate prefixes. This changes the structural stage order, not the
shared deadline, per-engine budgets, verification quota, or final fair merge.
The repair regressions specifically retain the wide-provider window of one
and 512 Exference steps, rather than widening the search to recover a later
exact witness.

Nonlegacy Church `nil` must avoid an explicit `match`. When the run includes
Exference `nil` under both `legacy` and a structural profile, an additional
paired check requires a freshly observed difference: the first legacy term
contains an explicit `match`, and the first structural term is a simple
four-binder lambda spine returning its final argument. The recognizer accepts
grouped or successive lambda binders and renamed identifiers, including
escaped names. Applications, patterns, annotations, repeated final-binder
names, and additional syntax fail this narrowly defined check. Independent
Lean replay still checks both complete terms; the shape check is a quality
witness, not a substitute for typing or a general equivalence test.

`results.json` records `paired_nil_comparison_count` and
`paired_nil_comparisons`, including the exact `before_term`, `after_term`,
profile names, and both shape predicates for each verdict. The full default
matrix includes three such Exference comparisons. A single-profile diagnostic
run records zero paired comparisons; it cannot claim an observed before/after
improvement. Historical legacy output motivates this fixture but is never
substituted for the current run's before term. All three paired comparisons
passed in the accepted matrix below.

For `diverse`, a separate Lean `decide` proof checks that the displayed projection alternatives
produce both 11 and 29 on the two distinct inputs. This distinguishes actual
functions, without relying on variable names, pretty-printing, or the ranking
implementation's structural-family key. Scores and type inhabitation are not
specifications of general Church-operation behavior; existing Length
contracts and their counterexample checks address that separate concern.

The exact candidate text, settings, executable and input-transcript hashes, process
statuses, independent kernel output, and axiom inventories are retained in the
output directory. `source_sha256` hashes the generated input text encoded as
UTF-8 with LF line endings, before platform file writing; it is not a hash of
the Windows CRLF bytes in `queries.txt`. To reproduce it from that file, read
as UTF-8 with universal newline normalization, then hash its UTF-8 encoding.
The executable hash covers its exact file bytes.

`--prepare-only` is explicitly generation-only evidence;
`--self-test` runs four Python tests and does not run synthesis or Lean:

- Complete multiline term capture and query order.
- Rejection of missing, extra, misnumbered, or unchecked output.
- Binder-independent recognition of the direct final-argument lambda, with
  rejection of unsupported syntax and ambiguous binders.
- Paired `nil` checks requiring actual before and after witnesses, with zero
  comparisons when no legacy baseline was run.

## Accepted-spelling repair: completed acceptance

Verification now suppresses only exact, case-sensitive spellings already
accepted in the same batch. Failed spellings remain retryable. Skipping a
previously accepted spelling creates no attempt, failure, or extra success,
and the first accepted candidate retains its ordinal, route, and evidence.
This filter does not borrow a later typed receipt or refill the caller's
bounded group prefix. Raw candidate charges and resource settings stay fixed.

Production revision `043a6a3d` passed **all 578 tests serially in 533.23
seconds**, and its executable build passed. The new executable SHA-256 is
`42c0c9c0a46a35302a04691a93fc68099c5e80bd91305e9a927ba9de9cec5cae`.
`quality-results/dedup-build-acceptance.json` records zero test/build exits,
source hashes, and the logs `build-leant-dedup-02.log` and
`build-executable-dedup-02.log`.

The fresh full live run completed **30 fixtures and 265 synthesis commands**
in **1,124.61 seconds**, with all executable, source, and runner identities
stable. It used a 30-second synthesis timeout. Twenty-nine original goldens
matched; the sole drift removed Exference's duplicate contextual
`Gap.polyGlobal` application from `it3`. Independent review of 132 input
artifacts found no lost successes, changed first results, new spellings,
remaining exact duplicates, or control/proof changes. No 600-second retry
was required. The two retained terms passed fresh exact kernel replay with
only `Gap.Token` and `Gap.polyGlobal` in their axiom inventories.

Receipts are `quality-results/dedup-compatibility/results.json`,
`quality-results/dedup-independent-review.json`, and
`quality-results/dedup-gap-replay/results.json`. After the single reviewed
golden-line removal, `quality-results/dedup-final-comparison/results.json`
matched all 30 files and 265 commands using the production normalizer. This
offline comparison reran neither synthesis nor the kernel and preserves the
original live runner exit **1**.

The fresh matrix passed in **two disjoint live and kernel runs**:

| Engines | Queries | Exact terms | Receipt under `quality-results/` |
| --- | ---: | ---: | --- |
| Djinn and Exference | 56 | 87 | `matrix-dedup/results.json` |
| Combined | 28 | 49 | `matrix-dedup-both/results.json` |
| Aggregate | **84** | **136** | `matrix-dedup-complete.json` |

Both runs used the same executable and settings: window 12, shown 4,
10,000 Exference steps, explicit Djinn budget 10,000, and synthesis timeout
30 seconds. All live and kernel exits were zero. Of the 136 terms, **112 have
empty axiom inventories and 24 use only declared provider premises**. All
three paired Exference `nil` improvements and three projection-diversity
proofs passed. Every query type and ordered term list is unchanged from E0;
the aggregate only checks the two completed runs and does not execute a new
one. The [acceptance table](README.md#accepted-spelling-repair-completed-acceptance)
keeps these fresh receipts separate from the historical 700-term Church run.

## Historical E0 provider-repair acceptance

Leant acceptance checkout `5629936` includes the corrected test assertion and
reviewed goldens. Its production code is unchanged from `a970d1f`, with
vendored Djex `ae986bf5` (synthesis code `2954b6d2`).
`quality-results/build-executable-05.log` records the successful build of that
unchanged executable, whose SHA-256 is
`e0b9c87cae0bc34d59c8d5a34a58fdd5005676913969a80d5503d7281081d025`.
All nine focused repair tests passed. The fresh full suite passed **all 569
tests** serially at unchanged limits in **389.71 seconds**, with process exit
zero. Receipts are
`quality-results/provider-repair-focused-01.log` and
`quality-results/build-leant-06.log`. The latter supersedes the earlier
`build-leant-05.log` failure of a stale source-text routing assertion.

`quality-results/fixtures-repair/results.json` records **90/90 required
candidates**, all independently kernel-replayed: **78 empty axiom inventories
and 12 exact declared-premise inventories**. All four live processes and
kernel replays exited zero, and every pre-golden validation passed. The wide
providers retain all eight or twelve named arguments under the original
one-candidate window and 512-step budget. All six layered-provider queries
also succeeded without larger limits.

The same executable passed the fresh full matrix in
`quality-results/matrix-final/results.json`: **84/84 nonempty queries and
136 exact displayed terms**, all independently kernel-replayed. **112 terms
have empty axiom inventories and 24 use only the declared provider premises**.
All three paired `nil` improvements and three projection-diversity proofs
passed. Live synthesis and kernel replay exited zero, and the executable hash
remained unchanged. Settings and canonical input hash match the earlier matrix.
Only the second provider alternative under each structural combined profile
disappeared: every first result and all 81 other query term lists are unchanged.
The E0 136-term result remains separate from the earlier 139-term receipt.

The original fixture runner exited 1 because three reviewed golden files
differed. After those baseline changes were applied,
`quality-results/compact-comparison/results.json` confirms that all four
goldens match the preserved live captures using the fixture runner's
normalization. This is an offline comparison, not a second live or kernel run;
the original receipt and its three mismatches remain intact.

The same executable also passed **350/350 Church cases per engine**, with
all **700 exact displayed terms** independently kernel-replayed and all axiom
inventories empty. Receipts are
`quality-results/church-djinn-final/results.json` and
`quality-results/church-exference-final/results.json`.
The runs retain the default `balanced` profile, window one, a configured
30-second synthesis timeout, 4,096 Exference steps, and Djinn's
`synth-budget off` under the shared deadline and intrinsic finite planning
caps. Each engine covers 315 total, 16 integer-provider, and 19 explicit-default
cases, with the scope and universe qualifications in the
[corpus guide](README.md#current-quality-policy-acceptance).

### Completed E0 ordinary compatibility review

`quality-results/ordinary-final/results.json` records **26/26 live fixtures**
completed in 98 minutes 45 seconds: six original matches and 20 golden drifts,
with the original runner exit **1** preserved. Their source inputs and E0
executable remained unchanged. Review checked controls and diagnostics as
well as candidate text. `quality-results/ordinary-review/results.json` and
`quality-results/ordinary-review-audit.json` retain independent kernel replay
and provenance checks for **99 exact changed terms**. The separate
`quality-results/synth-prove-review/review.json` records **six proof terms and
two exact tactic applications**, including their original proof contexts and
the fixture's expected error.

After the 20 reviewed goldens were applied,
`quality-results/ordinary-golden-application/application.json` preserved their
before/after hashes. `quality-results/composite-comparison/results.json`
then matched **30/30 files and 265 synthesis commands** from the ordinary and
compact capture groups using the production normalizer. This comparison ran
neither synthesis nor the kernel and did not change the original exit code.

Acceptance does not mean monotonic first-result quality: `synth-manual` query
20 grew from two to three `match` expressions. The
[policy guide](../docs/candidate-quality.md#historical-e0-baseline) records
the precise observation and why it establishes neither a score inversion nor
budget exhaustion. E0 also retains the duplicate presentation which motivated
the subsequently validated accepted-spelling repair.

## Recorded policy matrix before the provider repairs

The following completed receipts belong to the earlier executable and remain
separate from acceptance of the repaired executable.

Leant implementation `fb84b96` with vendored Djex `2954b6d2` passed all
**565 unit tests**, run serially at unchanged limits in 392.05 seconds
(`quality-results/build-leant-04.log`). The live runs below used one unchanged
executable with SHA-256
`dab110ad2a7903ac4ef4883898d48532c00cc8c3b1b8d8748aac7744eedffb61`.

| Receipt directory | Queries | Exact displayed terms | Empty axiom inventories | Declared-premise inventories | Paired nil checks | Projection diversity proofs |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `quality-results/focused-repair` | 6 | 14 | 14 | 0 | 2 | 1 |
| `quality-results/matrix-accepted` | 84 | 139 | 112 | 27 | 3 | 3 |

Both live processes and both independent kernel replays exited successfully.
All queries produced candidates, and every inventory stayed within its allowed
premises. The focused run is a diagnostic subset of the matrix, not additional
distinct coverage. Each directory contains `results.json`, `queries.txt`, the
complete live output, `QualityCandidates.lean`, and `kernel-output.txt`.
The matrix input's canonical SHA-256 is
`96b6681ec583aa213df0d6a80d780eac17f36ba4e13827f98b1e8526a1851547`.

The freshly observed first Exference `nil` term was:

```lean
fun _ _ f x => match Sum.inr x with | .inl a => f a x | .inr b => b
```

Each of `balanced`, `compact`, and `diverse` instead displayed:

```lean
fun _ _ _ x => x
```

All were independently kernel-checked at
`∀ A R : Type, (A → R → R) → R → R` with empty axiom inventories. The safe
single-use alias exposure and decreasing-case-count reduction described in
the [policy guide](../docs/candidate-quality.md#normalization-and-verification)
allow this unnecessary elimination to disappear while retaining the original
allowances, sharing rules, and visible-type-application barrier.

The earlier `quality-results/matrix-all` attempt had the same 84 nonempty
queries and all 139 identical displayed terms, but its standalone compiler
rejected the 27 ordinary `def` wrappers around opaque provider premises as
noncomputable. The accepted rerun changed only those wrappers to
`noncomputable def`. Its complete per-query results, settings, and input hash
match the earlier attempt; removing those 27 prefixes makes the two kernel
sources identical. The closed definitions and all typing, budget, term-capture,
and axiom-inventory checks stayed unchanged.

These results establish the stated quality and diversity witnesses under the
configured search allowances. They do not establish a general behavioral
specification for every Church operation, global term minimality, or a search
speedup.

The separate fresh Church runs passed **350/350 cases for Djinn and 350/350
for Exference**, with all **700 exact displayed terms** independently
kernel-replayed and all axiom inventories empty on the same executable.
Their receipts are `quality-results/church-djinn/results.json` and
`quality-results/church-exference/results.json`. These runs use the default
`balanced` profile, a one-candidate window, and a configured 30-second synthesis
timeout; Exference uses 4,096 steps, and Djinn leaves `synth-budget off`, subject
to the shared deadline and intrinsic finite planning caps. Each engine's
315 total, 16 integer-provider, and 19 explicit-default cases retain the
scope and predicative-universe qualifications in the
[corpus guide](README.md).

The first broader-fixture attempt is retained in
`quality-results/fixtures/results.json`. All nine ordinary Church and 69
rank-N queries passed independent kernel replay; the rank-N transcript has
reviewed candidate-order and cutoff-diagnostic changes. The wide-provider
fixture produced only two of six required results because Exference and
combined mode selected a bare provider whose exact type arguments Lean could
not infer. The layered-provider fixture produced four of six results, with
the two combined-mode queries reaching the configured 30-second deadline.
Those missing results were real failures; the successful corpus and quality
matrix did not substitute for broader fixture acceptance. The later 90-query
repair run above separately verifies their resolution.
The report keeps live process exit codes separate from candidate/kernel
validation and golden comparison, so its zero live exits and kernel checks
for the emitted subset cannot hide missing required results. The original
broader runner exited unsuccessfully; the successful repair run does not
change that recorded outcome.
