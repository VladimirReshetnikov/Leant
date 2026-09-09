# Completed native integration of the function-carrier and verification changes

All ten required native integration gates pass with Leant production revision
`43f1bc11aed4dc08cf498682b50ce698fd2e5a53` and Djex
`bfc3692e891ed2d81846fb2bd6b54ecd51aa7442`. The final source, runtime and executable
hashes match the starting snapshot. Leant now pins that exact tested Djex
revision. This closes the integration release gate for these changes.

The [receipt](https://github.com/VladimirReshetnikov/Leant/blob/main/test-recursive/receipts/combined-native-integration.json)
and [archive](https://github.com/VladimirReshetnikov/Leant/blob/main/test-recursive/receipts/combined-native-integration.zip)
preserve all terminal gates, commands, raw captures, exact replay sources,
frozen source copies, runtime identities and the serial integration driver.
All 3,736 artifacts plus the manifest were checked; the archive SHA-256 is
`ac464ba0f8d35a1095bf5bed2c59e2e8961660502e345be703022700ad2d87c9`.

| Gate | Accepted result |
| --- | --- |
| Complete unit suite | 702/702 |
| Global methods | Six public cells, exact full-type and payload replay |
| Method controls and cache separation | Nine completed sessions |
| Local contexts | 39 cells, including 18 exact output cases and refusal/control cases |
| Simplification | 15 queries: six candidates, three false controls, six inconclusive controls; independent replays |
| Native List recursors | 12/12 across Djinn, Exference and Both: nine exact full-type replays and three completed False controls |
| Extended native Exference behavior | 13/13 operations, exact full-type replay and an actual False control |
| Nested-result foralls | Nine cells: six exact outputs and three actual False controls |
| Native Djinn Church signatures | 350/350 synthesized and independently replayed; 350 empty candidate axiom inventories |
| Native Exference Church signatures | 350/350 synthesized and independently replayed; 350 empty candidate axiom inventories |

The last Exference signature process completed successfully in 737.51 seconds.
The native recursor matrix completed in 311.01 seconds, retaining its original
90-second command deadlines, 1,024 window/verification allowance and 100,000
steps/choices. The earlier 9/12 recursor result is superseded. False controls
must complete their commands; rejection prefixes from timeouts remain failures.
All nine recursor implementations, their observation proofs and `List.foldr`
have empty reported axiom inventories. Simplification and extended behavior
retain their separate documented proof-axiom policies.

The suite and positive-method gates reuse the terminal v2 receipts on unchanged
production and executable bytes. Three trace-control fixture files changed
after the positive-method run; its driver imports or executes none of them.
The fresh v3 method-control run exercises the updated validator. The complete
driver validates those boundaries before reusing results. This is acceptance
from compatible terminal runs, not a claim that all ten gates ran afresh in one
uninterrupted invocation.

The earlier missing fake-solver event file, obsolete trace-role validator and
control-generation failures remain in the
[component report and archive](2026-09-08-combined-behavioral-verification.md).
The [nine-gate checkpoint](https://github.com/VladimirReshetnikov/Leant/blob/main/test-recursive/receipts/combined-integration-retriage.json)
retains the earlier running-parent snapshot; this terminal receipt supersedes
its pending signature and dependency status without changing that artifact.

For reproduction, the archived integration driver records each exact command
and runtime path. Its public entry points are `test-recursive/run_unit.py`,
`test-context/global-methods/run_methods.py`, `run_controls.py`,
`test-context/run_production.py`, `test-behavioral/run_simplification.py`,
`test-recursive/run_recursors.py`, `test-church/behavior_extended_probe.py`,
`test-church/nested_forall_probe.py` and `test-church/run_corpus.py` for each
engine. Use fresh output directories and the recorded gate-specific limits;
resolve runtime paths for the checking machine. Preserve source/executable
identity throughout a serial run.

Native tree synthesis is a separate open acceptance target. The 350 signature
results establish type inhabitation, not matching behavior for the entire
Church library. The [revised delivery order](2026-09-08-synthesis-next-deliveries.md)
retains all 13 extended and all 19 supplied-default operations across Haskell
Djinn/Exference and Lean Djinn/Exference/Both, the Haskell frontend gaps, and
broader contextual evidence. The priorities 1–4 goal remains open.
