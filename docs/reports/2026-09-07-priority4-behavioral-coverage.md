# Priority 4 behavioral coverage: accepted subsets and remaining cells

The [focused introduction milestone](https://github.com/VladimirReshetnikov/Djex/blob/main/docs/reports/2026-09-08-focused-forall-search.md) accepts all **13 extended
Haskell Exference operations in one fresh run**, including `maybeEither`, with
exact original-signature replay, 28 oracle controls and a live False query.
The 256-candidate, 100,000-step and 8,192-node queue limits are unchanged.
All 2,308 regression tests and 350 signatures per Haskell engine also pass.

Other rows retain their historical receipts and harness pins. This is not a
fresh complete matrix across languages, engines and the 19 explicit defaults.
Leant still pins Djex `4a4ed0fc`; the canonical change awaits native acceptance.

| Language and engine | Accepted subset | Remaining within that subset |
| --- | ---: | --- |
| Haskell Exference, fresh complete extended run | 13/13 | None within the 13 extended operations |
| Haskell Djinn, first six, repaired length, and disjoint remaining seven | 12/13 | `maybeEither` |
| Haskell Exference, selected explicit defaults | 2/4 (`last`, `atKey`) | `foldl1`, `at` |
| Lean Exference, first six with independent repaired-length follow-up | 6/6 | None; the remaining seven and Djinn/Both are outside this subset |

Both Haskell engines accept `numeralAdd`, `fromMaybe`, `either`, `maybeToList`,
`foldl`, `length`, `numeralSuccessor`, `foldr`, `listToMaybe`, `catMaybes`,
`squashMaybe`, and `isLeft`. Exference's repeated length acceptance adds no
unique coverage. False and oracle controls are separate executions, not
synthesized operations. Earlier supplied-default `head` receipts remain
separate from the selected four-operation partial batch.

The [original Haskell coverage receipt](https://github.com/VladimirReshetnikov/Djex/blob/1b9db48f0f782a194b4076ae2cb3d910570746d7/test-church/receipts/priority4-haskell-coverage.json)
preserves the original combined receipt and its two historical audits without
changing their bytes. The [Djinn seven-operation supplement](https://github.com/VladimirReshetnikov/Djex/blob/1b9db48f0f782a194b4076ae2cb3d910570746d7/test-church/receipts/priority4-djinn-remaining-seven.json)
adds six accepted operations from seven attempted cells, 15 oracle controls,
one actual False control, and 50 owned processes, all exiting zero. Its offline
audit rehashed 192 artifacts. The original combined receipt retains SHA-256
`7e69c16a58ee380d57237ce4927f78d9f37e46da4f23021d23de107f9826019c`.
Both sets preserve actual input/capture association, full requested types,
predicates, provider inventories, exact emitted equations and GHC replay.

Djinn's missing `maybeEither` checks 364 candidates: 363 false, one error, zero
true and zero timeouts, ending at `ChoicePointLimitReached`. Its 22 same-candidate
elaboration retries are distinct observations: the three retained samples have
graphs and end false after repair. They do not identify the unsampled final
error. Exference's historical miss checks 256 candidates (251 false, five
errors); its sampled missing-forall graph evidence does not classify every
error or establish unsupported syntax. Neither failed batch is accepted merely
because its process exits zero or some other operations pass.

Length retains native GHC `Int` and exactly zero/successor. The fixture uses
ordinary implicit Prelude; Djinn's checked abstract head is `type Int :: Type`.
There is no fake empty datatype or generalized numeric target. Djinn's v2
emits a candidate after nine checks but its harness rejects that browse row;
it remains a fixture failure without accepted replay. Fresh v3 passes:
Djinn observes 9 checked / 1 true / 8 false and Exference 7 / 1 / 6, both with
zero errors/timeouts. Their False controls establish one and 256 actual
falsifications respectively. The common Djex executable is
`74e77fabd961d73b9629df1259d384d3fbfb055a4316f99ce5b6249645012706`.
Changed harness/specification pins are recorded per run; historical pins are
not asserted to match today's files. Saved inputs and artifacts, and each
run's before/after integrity gates, establish those historical boundaries.

Haskell bounds are Djinn interleave/window 65536/choice budget 500000 and
Exference window 256/budget 100000, with 100000 steps, queue 8192, first
selection, balanced ranking and a 300-second outer process guard. The REPL
query timeout is zero; independent replay evaluation is bounded to two seconds.
These are per-engine acceptance parameters, not a claim of equal cost.

The [Lean first-six receipt](../../test-church/receipts/priority4-lean-exference-first-six.json) and its [audit](../../test-church/receipts/priority4-lean-exference-first-six-audit.json)
record the failed-overall first-six batch and its separate offline audit:
68 files rehashed, 13 owned processes exiting zero, five exact displayed/full-type
kernel replays with empty inventories, and no length replay. Its actual False
control establishes 233 falsifications with zero passes or inconclusive results.
The engine's proposed-candidate count and the configured 256 limit are different
counters. The raw receipt retains SHA-256
`a2c180b0c1a2bfe6eb45f0f032a87225aa3b0c346bb7bdf1a2991ccab46df912`.
Leant executable
`27b9da6107ac0cd5081acf7c36e335296fb2b0a661e6b563d590813891c3c12c`
and actual Lean kernel
`10c6a27583eb65ff6a7e92b9718ff01d851ad594e6d70bb283fa5a10092fd810`
are pinned independently. The run uses window/verification 256, shown 1,
steps/budget 100000, balanced ranking, depth-first Djinn setting, 30-second
command deadline and 900-second outer guard. A separately completed native-length follow-up accepts one
positive and one False control, with five empty inventories. Its positive
process takes 24.53 seconds, exact kernel replay 2.19 seconds and False process
9.85 seconds. The kernel direct-implementation inventory is exactly
`Int.ofNat`, `Nat`, `Nat.succ`, and `Nat.zero`, with type constant `Int`.
Native constructor origin is validated; no ordinary providers are discovered.
This establishes a composite first-six 6/6 while preserving the original
fixture failure. The [native-length receipt](../../test-church/receipts/priority4-lean-native-length.json)
records the fresh acceptance separately from that historical failure.

The subsequent native-Int `at` calibration accepts neither engine: Djinn hits
the 300.06-second outer guard and Exference has a bounded miss in 35.27 seconds.
Both False controls and all six oracle/primitive controls pass. Its separate
[failure supplement](https://github.com/VladimirReshetnikov/Djex/blob/1b9db48f0f782a194b4076ae2cb3d910570746d7/test-church/receipts/priority4-partial-at-native-int.json) retains these boundaries and adds no
accepted coverage. Djinn has no completed behavioral summary, so its candidate
counts are unknown; Exference reports 256 false with zero errors or timeouts.

## Reproduction and delivery

Use fresh output directories and the executable whose receipt is being tested.
Leant's synchronized dependency supplies the default specification path
`lib/Djex/test-church`; reproductions do
not require an unrelated `C:/Djex` checkout. From the Leant repository
root, the recorded first-six Lean subset can be requested with:

```powershell
python test-church/behavior_extended_probe.py --leant <built-leant.exe> --engine exference --operation numeralAdd --operation fromMaybe --operation either --operation maybeToList --operation foldl --operation length --window 256 --budget 100000 --steps 100000 --timeout 30 --process-timeout 900 --djinn-strategy depth-first --output dist-newstyle/priority4-live/reproduce-exference-first-six
```

For a canonical Haskell cell, use `test-church/behavior_extended_probe.py`
with `--djex <built-djex.exe> --engine djinn --operation maybeEither`,
`--djinn-window 65536 --djinn-budget 500000 --steps 100000 --djinn-strategy interleave`,
`--process-timeout 300` and a fresh `--output` directory. A rerun remains an
attempt until its own controls, inventory, emitted expression and independent
replay pass. The historical live receipts remain pinned to their pre-vendor
runtime; a later dependency update/build does not relabel those executions.

The next delivery gate is expanded behavior and the concrete graph/elaboration
or fixture failures it exposes. Broader supplied folds and trees follow the
accepted native verification repair; one described global `Type 0` provider
and exact selected-dictionary identity follow under the existing guard.
Independent preparation can proceed in parallel, with heavy runtime serialized.
Tree-fold acceptance has no dependency on relaxing dictionary overlap guards.

All 13 extended operations and all 19 supplied-default counterparts remain
required across both Haskell engines and all three Lean modes. Finite observations,
oracle preflight and the 350-signature inhabitation corpus do not substitute for
those live cells, prove universal semantics or establish search completeness.
Original priority 1 remains complete within its supported fragment; priorities
2–4 retain their broader requirements.

The [final focused harness checks](../../test-church/receipts/priority4-harness-tests.json) pass: all 21 Haskell checks and all 26 Lean
checks, covering provider inventories, native type identity, control wiring,
accepted-source ownership, direct implementation constants and replay integrity.
These Python checks supplement the recorded live GHC/Lean executions; no
production search-engine code changes in this corpus milestone.

The [dependency integration receipt](../../test-church/receipts/priority4-vendor-integration.json)
records the strict executable/unit-target build and default-path preparation of
all 39 extended and 57 supplied-default candidate inputs, plus their False
controls. The dependency is pinned to Djex `1b9db48f0f782a194b4076ae2cb3d910570746d7`.
Its final publication-only follow-up preserves receipt bytes; production sources
are identical to the built corpus revision. Earlier live and full-unit results
retain their original executable and source pins. Routing-reference hashes
normalize LF/CRLF; recorded input and artifact hashes retain actual file bytes.
