# Bounded behavioral simplification acceptance

`run_simplification.py` exercises the named-query path with each selected engine.
It uses a polymorphic identity type and supplies no implementation providers.
The five queries require quantified simplification, actual falsification by
simplifying the negation, opaque and partially simplified inconclusive outcomes,
and successful subsequent ordinary decision checking.

Before live synthesis, sixteen isolated Lean files check the two proof methods
at both polarities for the first four predicates. The quantified positive and
negative cases must reject both `decide` attempts, then succeed only at the
expected `simp` polarity. Opaque and partially simplified propositions must
remain unproved. Rejected controls require proof-failure diagnostics, so syntax
or import errors cannot pass them.

Every displayed result is then replayed independently at its exact complete
type and exact lexical assertion. Candidate axiom inventories must be empty.
The ordinary decision proof must also remain axiom-free. Simplification proofs
may use Lean's `propext` and `Quot.sound`, which arise from propositional
simplification and function congruence; their actual inventories are retained.
`Classical.choice`, `sorryAx`, and user axioms are not allowed in these controls.
This is an explicit proof-inventory distinction from the finite `decide` corpus.

Run against an already built executable, in a new or empty output directory:

```powershell
python test-behavioral/run_simplification.py --prepare-only --output dist-newstyle/simp-prepared
python test-behavioral/run_simplification.py --leant dist-newstyle/build/x86_64-windows/ghc-9.12.4/leant-0.1.0/x/leant/build/leant/leant.exe --output dist-newstyle/simp-acceptance
```

The default matrix uses Djinn, Exference, and Both. Repeat `--engine` to select
a subset; subset selection remains in the receipt. Initial limits are a
32-candidate window/verification allowance, 4,096 Exference steps, 20,000 Djinn
choices, and a 30-second shared command deadline. Each proof request retains the
product's five-second maximum, 200,000 heartbeats, and the simplifier's 10,000-step
limit. The runner's separate process guard defaults to 600 seconds.

The receipt records the prepared commands, source and executable hashes,
method-control results, live outcomes, exact displayed terms, independent
replay results, and actual axiom inventories. `--prepare-only` writes fixtures
without running any synthesis or Lean process. This fixture does not establish
broader Church coverage or arbitrary theorem proving.

The [retained live receipt](receipts/simplification.json) passes all sixteen
method controls, all fifteen queries across the three engines, and independent
replay of all six displayed results. See the
[acceptance report](../docs/reports/2026-09-07-bounded-behavioral-simplification.md)
for the exact dependency and separate build/full-suite status.

## Combined decision certificates

The [combined verification report](../docs/reports/2026-09-08-combined-behavioral-verification.md)
and [receipt](receipts/combined-verification.json) record the checked candidate/proof
pair, original-budget fallback, exact-input recursor comparison and regressions.
Generate the controls through the production Haskell builder, then run each
isolated command with the exact Lean kernel executable:

```powershell
python -B test-behavioral/run_combined_controls.py --output dist-newstyle/combined-controls --lean C:/Users/vresh/.elan/toolchains/leanprover--lean4---v4.32.0/bin/lean.exe
```

Use a fresh output directory and substitute the actual toolchain path. This
requires the existing Cabal build environment. The ten controls validate core
command compatibility, positive/negative/undecided certificates, diagnostic and
sorry handling, duplicate tags, trailing comments and lexical scope. They do not
alone establish synthesis or full integration acceptance. Live public queries,
complete unit tests and exact emitted-term replays remain separate evidence.
