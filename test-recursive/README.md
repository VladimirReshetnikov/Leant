# Ordinary recursive-data behavioral acceptance

`run_behavior.py` submits named `:synth ... where ...` queries through the live
Leant executable. It provides datatype declarations, with library and named
provider discovery disabled. Every accepted, exactly displayed implementation
is then checked in a separate Lean file together with its finite predicate.
Both declarations must have empty axiom inventories. A `where False` control
must actually reject candidates for each selected engine.

The eight scenarios cover list `null`, `headOr`, `tailOr`, shallow tree
inspection, list aliases, unary tuple fields, an `unconsOr` product result,
and two independently typed list inputs whose observations form a pair.
Partial operations use explicit default arguments. These fixtures do not
claim universal laws or synthesis of recursive calls.

Run from the repository root after building the executable:

```powershell
python test-recursive/run_behavior.py --leant dist-newstyle/build/x86_64-windows/ghc-9.12.4/leant-0.1.0/x/leant/build/leant/leant.exe --output dist-newstyle/recursive-acceptance/run-1
```

The default matrix includes Djinn, Exference, and Both. `--engine` and
`--operation` select explicit subsets, which are recorded in the receipt.
`--prepare-only` writes the exact query inventory without running synthesis
or Lean. Output directories must be new or empty; earlier receipts are never
overwritten. Defaults are a 1,024-candidate/verification window, 100,000 Djinn
choices and Exference steps, interleaving, a 90-second command deadline, and
a separate 1,200-second process guard. Lean replay uses 4.32.0 by default.

Receipts retain settings, source and executable hashes, exact commands,
captured processes, candidate spellings, observations, and kernel inventories.
Source or executable changes during acceptance invalidate the run. A prepared
inventory, a dependency update, and a passing Haskell fixture are not Lean
acceptance; consult the actual `results.json` status and selected case matrix.

## Retained checkpoint

At the working integration of Djex
`3ce26cfd966ea4da2300028880c71ddaae50596d`, the
[Djinn-only receipt](receipts/djinn-cases.json) passed eight cases, eight
independent Lean replays with sixteen empty axiom inventories, and one actual
false control. The [Exference/Both run](receipts/other-engines-incomplete.json)
failed: Exference missed `tailOr` within its step bound, and both modes timed
out on the unary tuple-payload case. That failed run performed no independent
kernel replays. Its failure does not invalidate the separate Djinn receipt.

The complete three-engine matrix and the full post-correction Leant unit run
remain required. The receipts record their historical source and executable
hashes; they do not validate later code or establish universal behavioral laws.
