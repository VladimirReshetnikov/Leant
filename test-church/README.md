# Church synthesis acceptance in Lean

The [candidate-quality guide](../docs/candidate-quality.md) explains the new
default `balanced` profile and its legacy compatibility mode. The
[focused quality probes](quality.md) compare policies at equal configured
budgets: the current 84-query matrix and all 136 displayed terms passed live
synthesis and independent kernel replay. The repaired executable also passed
all 90 compact queries and their independent kernel checks, followed by
reviewed offline golden comparison. Both full Church runs also passed:
350 cases per engine and all 700 exact displayed terms independently
kernel-replayed with empty axiom inventories. The remaining 26 ordinary
compatibility fixtures are still being validated; earlier receipts remain
separately identified below.

`run_corpus.py` consumes Djex's GHC-resolved `test-church/manifest.json` and
generates a Lean goal for every signature in `docs/examples/Church.hs`,
including its locally scoped signatures. It expands aliases from the manifest;
it never reads source implementations as candidate terms or providers.
It verifies the source file's SHA-256 after normalizing line endings before
using the manifest, and records
both manifest and executable hashes in the run report.

The 19 signatures classified as partial are tested separately with the explicit
element-default input recorded in the manifest. This makes their Lean
counterparts total. A successful default-bearing query makes no inhabitation
claim about the original default-free signature.

Lean's `Type` hierarchy is predicative. Every translated quantifier therefore
has its own inferred `Type _` universe, and the synthesized term constrains those
levels during elaboration. This tests valid universe instantiations of the
Haskell signatures; it does not assert that all independent universe assignments
admit the same implementation. `UniverseProbe.lean` includes small checked
examples of this distinction, including impredicative Haskell instantiation
represented by an appropriate higher Lean universe.

After building Leant, generate and run all cases with:

```powershell
python test-church/run_corpus.py --leant <path-to-leant.exe> --window 1
```

The default manifest path is `lib/Djex/test-church/manifest.json`. Use
`--manifest <path>` when working with an unvendored Djex checkout. `--name`
selects individual source names and may be repeated; `--classification`
selects total, integer-provider, or partial/default-bearing cases. `--engine`
chooses `djinn`, `exference`, or `both`. `--window` sets the search and
verification window. `--steps` sets `synth-steps`, the Exference-only step
budget; it does not set a Djinn choice-point limit. Djinn retains the default
`synth-budget off`, subject to the shared wall-clock search deadline and
intrinsic finite planning caps. `--timeout` configures `synth-timeout` for
synthesis; it is not an end-to-end limit covering process startup, goal
serialization, or the separate standalone kernel replay.

The output directory contains the exact goal transcript, a translated manifest,
the complete Leant output, every accepted candidate as a Lean declaration, and
a JSON result report. The script then invokes Lean 4.32.0 on the candidate
declarations and checks their reported axioms for `sorryAx`. Both every-case
success and successful standalone kernel replay with an empty axiom inventory
for every candidate are required for a zero exit
code. A failed or unreached query remains a failure, even if the other
candidates compile. An empty selection, a command error, an unacknowledged
engine or setting change, and extra or duplicate displayed candidates are
also failures. `--replay-output` rechecks an existing transcript without
running synthesis again, using the same engine/settings arguments as the
saved run. It is mutually exclusive with `--leant`; the report distinguishes
saved-transcript replay from live execution against an unchanged executable.
Generated run directories are ignored by Git.

The named provider inventory is disabled for pure and default-bearing goals.
Integer-provider cases may discover the explicitly defined integer zero or
Lean's standard integer constructors. Classical fallback is disabled. Thus
accepted terms do not rely on the Church implementations, `sorry`, or invented
axioms. These are tests of matching types, as requested; they do not claim the
behavioral semantics of functions with names such as `map` or `sort`.

The ordinary golden runner also contains compact, readable suites:
`test/synth-church.txt` covers representative encodings and the explicit default
policy; `test/synth-church-rankn.txt` stresses wide quantified hypotheses and
polymorphic values supplied to abstract constructors under Djinn, Exference,
and combined mode. Its twenty-three goals per engine include two distinct
polymorphic value arguments, composition inside a constructed polymorphic
value, closed and dependent nested construction, and explicit and implicit
rank-seven continuation encodings, and successive ordinary-argument/forall
layers with different polymorphic choices at each layer, including an ambient
type hidden in the first choice. The latter crosses all four explicit/implicit
source and target binder combinations; a closed first choice also tests a
mixed implicit/explicit target across let aliases. The rank-seven examples place a polymorphic
type under six additional arrow domains; the separate eight- and twelve-binder
examples test arity rather than confusing binder width with type rank.
`test/synth-church-providers.txt` checks discovery of complete eight- and
twelve-argument active-instance assignments. That separate fixture explicitly
declares opaque primitive assumptions, matching the established provider tests;
its candidate checks are relative to those assumptions, and make no claim of
closed inhabitation. None of those assumptions enters the Church corpus runner.
`test/synth-church-layered-providers.txt` tests named global factories with
successive ordinary-argument/forall layers. Its binary and ternary goals reuse
the same bound type-variable spelling in distinct identity and Boolean types.
Each term is checked relative to exactly four supplied declarations: `Seed`,
`seed`, the corresponding opaque result constructor, and its factory.

`run_fixtures.py --leant <path-to-leant.exe>` runs all four compact fixtures,
checks every query produced a candidate, and independently kernel-checks their
complete displayed terms in the fixture's declared environment. The provider
fixture additionally requires every named argument of each eight- or
twelve-entry vector to appear in the emitted term, and verifies that the exact
axiom inventory contains only that fixture's declared `Token` and `chosen`
premises. The global-factory fixture requires its corresponding four premises,
including when Lean prints their dependency list on multiple lines. The
ordinary Church and rank-N fixtures require empty axiom inventories. The runner
records the executable hash before the first run and rejects a build change
during the fixture run. `--update-goldens` writes
goldens only after those checks pass; otherwise existing goldens must match.
The fixture receipt separates `live_exit_code`,
`validation_passed_before_golden` (live success, every candidate, independent
kernel replay, the fixture's axiom/argument checks, and an unchanged executable), and
`golden_comparison_passed`. A valid term can therefore be distinguished from
a changed baseline. `golden_status` records a match, mismatch, missing golden,
an update after validation, or a comparison skipped because validation failed;
the comparison result is null when no comparison was performed. The final
`passed` field still requires the applicable validation and golden checks,
and the aggregate run separately rejects an executable hash change.
There are 90 compact fixture queries in total: nine representative Church
queries, 69 rank-N queries, six exact-provider queries, and six global-factory
queries.

`lean +leanprover/lean4:v4.32.0 test-church/MixedSpineSyntax.lean` separately
checks constructive syntax witnesses for implicit type binders reached after
ordinary arguments, explicit instance placeholders, and differing visibility
between a selected type annotation and the final expected type, and inferred
implicit polytype values supplied before a later forall layer. All eight
witness declarations have empty axiom inventories.

Run `runghc -isrc test-church/check-provider-discovery.hs` from the repository
root for the separate live provider-discovery regression. It generates the
current production Lean serializer, asks for the real `Or.by_cases` inventory,
and checks that both earlier and later simple providers survive. The five
serial Lean checks also verify that the 128-attempt provider work counter
survives metavariable rollback, that ordinary assignment errors and local
heartbeat exhaustion leave the inventory usable, and that recursion-limit
exceptions and interrupts escape the optional-evidence boundary. The error
and heartbeat modes inject faults at exactly one checked assignment call;
they do not change the production serializer. Assignment work has a local
2000-heartbeat allowance clamped to the remaining command budget. These work
limits do not change source-derived type-binder arity or weaken complete,
correlated vector checks. Generated sources and compiler output remain under
the ignored `generated-provider-discovery` directory.

## Current quality-policy acceptance

The current acceptance checkout is Leant `5629936`, including the corrected
test assertion and reviewed goldens. It retains unchanged production code
from `a970d1f`, vendored Djex
`ae986bf5` (unchanged synthesis code `2954b6d2`), and executable SHA-256
`e0b9c87cae0bc34d59c8d5a34a58fdd5005676913969a80d5503d7281081d025`.
Each completed live run verified that the executable remained unchanged.

| Gate | Current result | Receipt |
| --- | --- | --- |
| Leant unit suite | 569 tests passed serially at unchanged limits, 389.71 seconds | `quality-results/build-leant-06.log` |
| Four profiles across Djinn, Exference, and combined mode | 84/84 queries; all 136 displayed terms independently kernel-replayed | `quality-results/matrix-final/results.json` |
| Church corpus, Djinn | 350/350 candidates; all 350 independently kernel-replayed with empty axiom inventories | `quality-results/church-djinn-final/results.json` |
| Church corpus, Exference | 350/350 candidates; all 350 independently kernel-replayed with empty axiom inventories | `quality-results/church-exference-final/results.json` |
| Four compact fixtures | 90/90 live and kernel successes; 78 empty inventories and 12 exact declared-premise inventories | `quality-results/fixtures-repair/results.json` |
| Compact golden comparison | All four reviewed goldens match preserved live captures; no synthesis or kernel rerun | `quality-results/compact-comparison/results.json` |
| Remaining 26 ordinary fixtures | Compatibility validation running; no completed acceptance yet | `quality-results/ordinary-final/` |

The policy matrix contains 112 closed terms with empty axiom inventories and
24 provider terms whose dependencies stay within the fixture's declared
premises. Its three paired Exference `nil` improvements and three independent
projection-diversity proofs passed. The [quality guide](quality.md) records
the unchanged settings, exact before/after terms, and provider-only
`noncomputable` replay wrappers. These quality witnesses do not substitute for
the full Church corpus or compact-fixture gates.

All **700 exact displayed corpus terms** passed independent Lean 4.32.0
replay with empty axiom inventories. The fresh corpus runs used the
executable's default `balanced` profile,
a one-candidate search and verification window, and a configured 30-second
synthesis timeout. Exference used 4,096 steps. Djinn's choice-point budget remained `synth-budget off`,
subject to the shared search deadline and intrinsic finite planning caps;
the transcript's `synth-steps 4096` applies only to Exference. The timeout
does not cover startup, serialization, or independent kernel replay.
Each engine's 350 cases comprise 315 pure total
cases, 16 integer-provider cases, and
19 cases supplied with the explicit ordinary default argument described
above. The latter establish the default-extended types only. Lean's
predicative universe discipline and independently inferred universe
instantiations remain unchanged.

The compact runner originally exited unsuccessfully because three goldens
differed, despite all required live and kernel validations passing. Review
confirmed complete eight- and twelve-argument provider vectors, exact allowed
premises, valid projection changes, and expected cutoff diagnostics. Only the
three reviewed baselines were updated; the separate offline comparison closes
their transcript differences without changing the original receipt.

The preceding quality executable, Leant `fb84b96` with Djex `2954b6d2` and
SHA-256 `dab110ad2a7903ac4ef4883898d48532c00cc8c3b1b8d8748aac7744eedffb61`,
passed 565 unit tests, an 84-query/139-term matrix, and all 700 Church terms
with empty axiom inventories. Those results remain in `quality-results/`
under `build-leant-04.log`, `matrix-accepted`, `church-djinn`, and
`church-exference`; they are not substituted for acceptance of the repaired
executable.

## Historical acceptance before the quality profiles

### Rank-N corpus and compact fixtures

Independent live runs completed **350/350 cases for Djinn and 350/350 for
Exference**. Lean 4.32.0 independently accepted all **700 exact displayed
terms**, and every corpus declaration has an empty axiom inventory. Each
engine covers 315 pure total cases, 16 integer-provider cases, and 19
explicit-default cases under the policy above.
These runs preceded the candidate-quality profiles. Their original outputs
and executable identity remain the acceptance evidence for that revision.

Both runs used a one-candidate window and a configured thirty-second synthesis
timeout. Exference used 4,096 search steps. Djinn retained its default
unbounded choice-point budget (`synth-budget off`), subject to the shared
wall-clock search deadline and intrinsic finite planning caps; the configured
`synth-steps 4096` does not bound Djinn choice points. The synthesis timeout
does not cover process startup, goal serialization, or the separate standalone
kernel replay. Both runs used one unchanged executable with SHA-256
`addfac35b9d82955fc871c177b582a8c043475c0171c22cb17977e0e9f5b9869`.
The implementation revisions are Leant `4757569` and vendored Djex `e2eb71e`.
The live-synthesis reports, candidate modules, and kernel output are in
`generated-djinn-acceptance` and `generated-exference-acceptance` beneath this
directory. Each `results.json` records the source/manifest/executable hashes,
unchanged-executable check, every candidate, and independent kernel outcome.

All **90 compact fixture queries** also pass on that executable, with 78
empty axiom inventories and twelve inventories containing exactly their
declared premises. Their report is
`generated-fixtures-bounded-final/results.json`. The Haskell unit suite passes
558 tests; the eight constructive syntax witnesses, five standalone
provider-discovery modes, and fourteen Python harness checks pass separately.

### Full ordinary compatibility suite on the historical executable

The full ordinary compatibility run completed on that same unchanged
executable on 5 September 2026 at 01:55:44, UTC-07:00. It covered 30 files,
263 explicit-type queries, and two proof-mode `:synth` commands, for 265
synthesis commands altogether. With a configured 600-second synthesis
timeout, the complete run took 5,515.86 seconds. Its original runner exit
code was 1: 17 fixture outputs matched immediately and 13 differed from
their baselines. That original result remains recorded.

The 13 changed fixtures were reviewed query by query: 114 actual displayed
terms across 34 changed queries passed independent Lean 4.32.0 replay.
Thirty-one have empty axiom inventories, and 83 have exactly their
fixture-declared premises. No previously successful query lost its result.
The aggregate `generated-final-drift-index/results.json` records this review;
it excludes four earlier baseline updates and their separate 44 term replays.
Only reviewed term and diagnostic changes were applied to the golden files.

All **30 final golden files match the retained full live-run outputs** using
the production Bash runner's normalization functions and command-substitution
semantics. This final check is an offline comparison of the completed live
outputs, not a second live synthesis run. Evidence is retained under
`generated-goldens-final`: `results.json` preserves the original exit code,
timing, and executable identity; `final-comparison.json` records all final
comparisons; `runner.log` and `transcripts/` retain the live output. This
ordinary compatibility closure is distinct from the independently checked
full corpus and compact fixture acceptance above.
