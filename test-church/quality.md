# Focused candidate-quality acceptance

See the [policy guide](../docs/candidate-quality.md) for the score, legacy
behavior, and raw candidate observation contract. The full 84-query policy
matrix has passed live synthesis and independent replay of all 139 displayed
terms. Fresh Church corpus runs on the same executable also passed all 700
displayed terms with empty axiom inventories. Fresh acceptance of the 90
broader fixture queries remains pending; the earlier corpus and ordinary-suite
receipts remain separately pinned to their historical executable.

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
python test-church/quality_probe.py --leant PATH_TO_BUILT_LEANT_EXE --engine djinn --engine exference --engine both --output test-church/quality-results/matrix-accepted
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

## Accepted policy matrix

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
[corpus guide](README.md#current-quality-policy-acceptance). Fresh acceptance
of the 90 broader fixture queries remains pending.

The first broader-fixture attempt is retained in
`quality-results/fixtures/results.json`. All nine ordinary Church and 69
rank-N queries passed independent kernel replay; the rank-N transcript has
reviewed candidate-order and cutoff-diagnostic changes. The wide-provider
fixture produced only two of six required results because Exference and
combined mode selected a bare provider whose exact type arguments Lean could
not infer. The layered-provider fixture produced four of six results, with
the two combined-mode queries reaching the configured 30-second deadline.
Those missing results remain failures requiring repair; the successful corpus
and quality matrix do not substitute for the broader fixture acceptance.
