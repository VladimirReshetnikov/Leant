# Supplied-fold tree accumulation

This is a manual behavioral acceptance fixture for priority 2. The initial
recorded runs do **not** accept a synthesized accumulator in either Haskell
engine. Lean's corrected oracle proofs pass, but no positive Lean cell passes;
the Exference and Both False controls pass separately. See the
[current search report](../../docs/reports/2026-09-08-post-integration-priorities.md)
before treating any cell as accepted. This fixture is not part of the passing
unit-test count.

The target threads a caller-supplied state through tree leaves from left to
right, using only a generic fold and the tree constructors:

```haskell
forall a s. (s -> a -> s) -> s -> Tree a -> s
```

```lean
{α σ : Type} → (σ → α → σ) → σ → TreeAccumulatorFixture.Tree α → σ
```

Sixteen observations cover order, tree association, several initial states,
nonlinear state updates, heterogeneous element/state types, and list and Bool
accumulators. Eight oracle controls accept the supplied reference and reject
wrong order, ignored subtrees, duplication and reset-state implementations.
Those controls are outside synthesis inventories. The Lean oracle proofs
explicitly unfold `observations` before `decide`; every recorded declaration
must have an empty axiom inventory.

`prepare.py` regenerates the specification, provider/control sources, exact
command files, replay templates and file manifest. `run_acceptance.py` checks
that manifest before running anything. Put outputs outside this directory.
Use a fresh output directory for every run. Do not change sources or rebuild
the selected executables while a run is active.

From the Leant root, with the project and selected executables already built:

```powershell
python -B test-recursive/tree-accumulator/prepare.py
python -B test-recursive/tree-accumulator/run_acceptance.py --language haskell --output dist-newstyle/tree-haskell
python -B test-recursive/tree-accumulator/run_acceptance.py --language lean --leant <built-leant.exe> --kernel <actual-lean-4.32.0-binary> --output dist-newstyle/tree-lean
```

The default Haskell route uses the prebuilt vendored Djex library in Leant's
Cabal project. `--djex-root <checkout>` selects a separate canonical checkout;
`--haskell-project <project>` can select its build project explicitly. Library
paths are read from that project's Cabal package database and hashed. They do
not depend on a particular user's directory or a hard-coded GHC build path.
For Lean, use the actual kernel binary, rather than an Elan dispatch proxy.
Set `LEANT_BACKEND` to the intended backend when multiple builds are available;
the enclosing milestone runner additionally records the resolved runtime.

`--controls-only` validates the independent controls without searching.
`--haskell-engine djinn|exference` and `--lean-engine djinn|exference|both`
select individual engines. Each Lean engine selection includes a positive
query and a live False control. The Haskell probe retains its original raw
candidate window, then independently compiles and executes every retained
candidate at the full original signature, including contradictory checks.

The specification freezes the original limits: 1,024 raw Haskell candidates,
100,000 choices/steps, and an Exference queue of 1,024; Lean uses window/verify
1,024, 100,000 choices/steps, provider cap 80 and a 90-second command deadline.
Outer process guards are separate. A timeout, exhausted pool or unsupported
candidate remains a failed cell, never an impossibility claim. The supplied
witness demonstrates that a state-transformer fold carrier works; a passing
synthesized implementation need not use that exact construction.
