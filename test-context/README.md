# Direct lexical-Given renderer acceptance

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
