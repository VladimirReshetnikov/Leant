# Lexical-Given synthesis acceptance

## Public production route

`run_production.py` exercises ordinary and named-`where` contextual synthesis
through the live executable in Djinn, Exference, and Both. Its fixed 39-cell
matrix covers local identity, constrained rank-N forwarding and forced local
Given application, three actual False controls, and eighteen explicit metadata
refusals. Search receives only the declared class and nominal datatype;
reference implementations remain in independent oracle processes.

The [accepted production receipt](receipts/ordinary-context-streaming.json)
records **39/39 passing cells**, with all eighteen exactly displayed candidates
independently checked at their complete Lean types. Their replay contains 72
finite payload observations and 144 empty axiom inventories. Candidate receipts
retain the displayed variant's own graph, renderer and engine. Source,
executable, resolved kernel, command and replay-input identities stayed unchanged.
The strict executable/unit build and the complete **680-test** serial suite pass.

Run from the repository root after the strict build:

```powershell
python -B -m unittest discover -s test-context -p test_production.py
python -B test-context/run_production.py --output dist-newstyle/context-production/run-1
```

`--leant` and `--lean-runtime` override the Windows executable defaults.
The output directory must be new or empty. The default acceptance gate keeps a
32-candidate/verification window, 20,000 search steps/choices, a 45-second query
deadline and a separate 120-second process guard. Contextual ordinary queries
verify bounded groups incrementally and present the assessed stream prefix;
they do not rank an unobserved whole candidate pool.

This accepts local `Type 0` contexts with complete source metadata. Global
contextual providers, richer universe metadata and selection between equal
active dictionaries remain separate implementation gates. An explicit refusal
counts only for its designated unsupported case, never for a positive query.
The [re-triage report](../../docs/reports/2026-09-07-synthesis-retriage.md)
records the remaining scope and preserved historical failures.

`run_serializer.py` separately compiles the exact production synthesis prelude
emitted by the built unit executable. That component check establishes serializer
validity; the production matrix establishes public command acceptance.

## Direct renderer component

`run_replay.py` exercises the isolated `Leant.Synth.ContextRender` module using
sealed graph fixtures. It runs all 21 focused tests, emits actual rendered Lean
terms from the test executable, and checks those terms against seven independently
written complete signatures in a separate Lean 4.32.0 process.

The fixtures distinguish equal-predicate dictionary slots, an outer dictionary
under a matching inner binder, a rank-N constrained callback, nested type and
context introductions, a constrained global provider, and a local let. Dictionary
payloads 11, 29, and 43 make the selected evidence observable. Seven positive
observations and two wrong-result controls must pass. All sixteen implementation
and proof axiom inventories must be present and empty.

Run after the strict Haskell build:

```powershell
cabal build leant:exe:leant leant:test:leant-synth-tests --ghc-options=-Werror -j1
python -B test-context/run_replay.py --output dist-newstyle/context-acceptance/replay-1
```

The output directory must be new or empty. The runner owns each child process
tree with a 120-second guard, records raw stdout/stderr, retains the exact source
snapshot and replay file, and rejects source or executable changes during the
run. A successful receipt establishes this component's behavior; it does not
establish live synthesis reachability, production source-metadata preparation,
instance/superclass derivation, or routing through the ordinary `:synth` command.

The first integration replay caught Lean implicitly introducing a residual
dictionary around a compound application. Making the compound term explicit
with `@(let ...)` preserves its checked partial-application type. Both formerly
failing cases now pass the full independent replay. The retained successful
receipt is [renderer-replay.json](receipts/renderer-replay.json).
