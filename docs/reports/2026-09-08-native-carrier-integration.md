# Native carrier integration: accepted contexts and remaining recursor timeouts

Native integration at working Djex `bfc3692e` is **incomplete**. The serial run
completed with unchanged source/runtime inputs and stopped at its required
recursor gate. Leant's committed dependency remains `4a4ed0fc`. The
[receipt](https://github.com/VladimirReshetnikov/Leant/blob/main/test-recursive/receipts/function-carrier-native-integration.json) and [archive](https://github.com/VladimirReshetnikov/Leant/blob/main/test-recursive/receipts/function-carrier-native-integration.zip) preserve the original terminal results,
exact inputs, process captures, kernel replays, deadline audit and fixture repair.
All 6,289 archive member hashes were verified.

| Completed gate | Evidence |
| --- | --- |
| Native unit suite | **701/701 pass**, including the layered-provider case at its unchanged deadline. |
| Global methods | **6/6 real-kernel cells pass**. |
| Method controls and cache separation | **9/9 sessions pass**. |
| Local contexts | **39/39 cells pass**, including 18 exact outputs replayed by Lean. |
| Native List fold-argument recursors | **9/12 cells pass after the deadline audit**: eight positive operations and Djinn's False control. Three commands time out. |

The recursor outcomes are explicit:

| Mode | Map | Append | Generalized length | False control |
| --- | --- | --- | --- | --- |
| Djinn | Pass | Pass | Pass | Pass: 87 falsifications |
| Exference | Pass | **90-second timeout: 513 falsifications** | Pass | **90-second timeout: 299 falsifications** |
| Both | Pass | Pass | Pass | **90-second timeout: 379 falsifications** |

Each successful positive has its own exact full-type kernel replay and empty
reported axiom inventories. The target takes the generic native List fold as
an argument with provider discovery disabled. These are List recursor cases;
they do not establish native tree-accumulator acceptance. The three failed
commands report zero passing and zero inconclusive predicate observations, but
their rejection counts do not establish completion. Append remains a timeout,
not an exhausted-pool result or a proof that no matching implementation exists.

## Completion check repaired

The original recursor runner classified both Exference and Both False controls
as passed because it saw actual rejection observations. Their transcripts also
contain `the engine did not finish within 90s`. The shared observation parser
reports observations from cancelled prefixes; each fixture must separately
enforce its command-completion contract.

`run_recursors.py` now requires completion before parsing an accepted result.
The tree runner uses the same helper, retaining its existing public helper
name and behavior. All four deadline tests pass, including a timeout after an
accepted prefix and a timeout after actual False observations. The helper was
also executed against all twelve immutable recursor captures. This invalidates
the two False pass labels above without editing the original results. No live
rerun under the corrected fixture is claimed. Production deadlines, candidate
windows, provider inventories, search steps and verification limits are unchanged.

The native recursor run retained window/verification 1,024, 100,000 steps and
choice budget, provider cap 80, a 90-second command deadline and 180-second
process guard. Reproduce with the exact prebuilt executable and Elan shim:

```powershell
python -B test-recursive/run_recursors.py --leant <leant.exe> --lean <elan-lean.exe> --toolchain leanprover/lean4:v4.32.0 --family native --operation map --operation append --operation length --output <fresh-directory>
```

## Remaining integration and implementation

The extended Exference behavioral corpus, nested-forall matrix and both
350-signature native corpora were **not run**: the integration runner stopped
at the failed required gate. The accepted four gates remain revision-pinned
evidence; they do not authorize promoting the dependency as fully integrated.

Diagnose native Exference append and the two False-control timeouts at these
original bounds, preserving the successful Djinn/Both append outputs and their
ownership. A completed False control needs actual rejection and command
completion. Finish the remaining gates before promoting the dependency.
Exact ordinary Haskell output is an independent implementation delivery.

The [current roadmap](2026-09-07-synthesis-retriage.md) retains all original
priorities 1–4, including native tree acceptance and the full 13 extended plus
19 supplied-default operations across all five language/engine combinations.
The accepted canonical Haskell function-carrier result remains valid at its
recorded revision; this native timeout does not relabel that earlier evidence.
