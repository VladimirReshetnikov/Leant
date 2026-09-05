# Focused candidate-quality acceptance

See the [policy guide](../docs/candidate-quality.md) for the score, legacy
behavior, and raw candidate observation contract. Final live acceptance of
this new comparison is still being completed. The earlier 700-term Church
receipt remains pinned to its recorded executable.

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
subset is recorded. The provider names do not assign prices: both named values
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
substituted for the current run's before term. Final live acceptance of these
new paired checks remains pending the final executable receipts.

For `diverse`, a separate Lean `decide` proof checks that the displayed projection alternatives
produce both 11 and 29 on the two distinct inputs. This distinguishes actual
functions, without relying on variable names, pretty-printing, or the ranking
implementation's structural-family key. Scores and type inhabitation are not
specifications of general Church-operation behavior; existing Length
contracts and their counterexample checks address that separate concern.

The exact candidate text, settings, executable and input-transcript hashes, process
statuses, independent kernel output, and axiom inventories are retained in the
output directory. `--prepare-only` is explicitly generation-only evidence;
`--self-test` runs four Python tests and does not run synthesis or Lean:

- Complete multiline term capture and query order.
- Rejection of missing, extra, misnumbered, or unchecked output.
- Binder-independent recognition of the direct final-argument lambda, with
  rejection of unsupported syntax and ambiguous binders.
- Paired `nil` checks requiring actual before and after witnesses, with zero
  comparisons when no legacy baseline was run.
