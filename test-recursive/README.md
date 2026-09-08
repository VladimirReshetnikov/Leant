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

## Current accepted case matrix

The integration of Djex `922c55580eadec156ba9ef447b300f43e0953ed7` passes
all eight operations in Djinn, Exference, and Both: **24 positive cells**, three
actual false controls, and 24 independent Lean 4.32.0 replays of the exact
displayed source at its original full signature. All **48 implementation/proof
axiom inventories are empty**. The live phase took 180.78 seconds; all source
and executable hashes remained unchanged. The successful
[all-engines receipt](receipts/all-engines.json) was retained from
`dist-newstyle/recursive-acceptance/all-engines-v3/results.json`.

Named behavioral queries admit unused-input candidates inside the existing
bounded Exference lanes. Both alternates observed raw engine slots, including
misses and duplicates, independently of the requested success count. The
accepted run retains the documented 1,024 window, 100,000 choices/steps, and
90-second command deadline. It closes the earlier case failures below; it does
not establish preemption within one engine step or synthesis of recursive calls.
The separate full configured Leant suite passes all 647 tests in 343.79 seconds.

## Full integration suite

After the strict build, run the complete configured suite with its built fake-Z3
helper from the repository root:

```powershell
python -B test-recursive/run_unit.py --expected-count 647 --output dist-newstyle/recursive-unit/full-1
```

`--test-exe` and `--fake-z3` override the documented Windows build defaults.
The runner clears inherited Tasty filters, verifies the actual 647-name
inventory, runs it serially, and requires the passing summary to match that
inventory. It records source, test-executable, and helper hashes; a changed
artifact invalidates acceptance. The [full-run receipt](receipts/unit.json)
records **647/647 tests passing in 343.79 seconds** with exit code 0, matching
unfiltered inventory and summary counts, and unchanged sources, test executable,
and fake-Z3 helper. This aggregate remains separate from the live case receipt.

## Historical receipts

The [first 647-test run](receipts/unit-before-fixture-refresh.json) passed
645/647 in 297.72 seconds; the old layered-provider case passed in 75.76 seconds.
Two expectations were stale: a typed wildcard graph was expected to use legacy
fallback, and a Nat case was required to be the first candidate. The corrected
checks retain typed graph authority and the semantic Nat case under its original
1,024-step bound and default-12 frontier; the wildcard fixture keeps its
128-step bound. Both focused tests pass in 0.41 seconds without increased
budgets. Strict build v6 and the subsequent full 647-test rerun pass.

At the working integration of Djex
`3ce26cfd966ea4da2300028880c71ddaae50596d`, the
[Djinn-only receipt](receipts/djinn-cases.json) passed eight cases, eight
independent Lean replays with sixteen empty axiom inventories, and one actual
false control. The [Exference/Both run](receipts/other-engines-incomplete.json)
failed: Exference missed `tailOr` within its step bound, and both modes timed
out on the unary tuple-payload case. That failed run performed no independent
kernel replays. Its failure does not invalidate the separate Djinn receipt.

An earlier three-engine run after integrating Djex `922c5558` also failed:
[`all-engines-v2`](receipts/policy-baseline-incomplete.json) took 986.39 seconds
and yielded twenty of twenty-four live positives plus three false controls.
Exference missed `tailOr` and timed out on
alias and tuple fields; Both also timed out on tuple fields. The parser stopped
before independent replay. Its [preserved live subset](receipts/policy-baseline-live-classification.json)
must not be counted as kernel-replayed evidence. The successful `all-engines-v3`
receipt above follows the request-policy and scheduling corrections.

These earlier receipts retain their historical source and executable hashes;
they do not validate later code or establish universal behavioral laws.

## Supplied folds and rank-N recursor arguments

The included [run_recursors.py](run_recursors.py) fixture specifies acceptance of
ordinary recursive programs composed from generic folds. It does not load
implementations of map, append, length, tree map, or tree flattening.
It is a prepared acceptance fixture with diagnostic evidence, not an accepted
fold-synthesis matrix. In the [initial settings receipt](receipts/recursor-settings-incomplete.json),
native Djinn `map` produced a live candidate and the false control rejected
candidates, but a wrong provider-cap acknowledgement label in the validator
stopped processing before independent kernel replay. The shared validator fix
passes eighteen Python tests; that failed receipt is preserved unchanged.

The [fresh native Djinn receipt](receipts/native-folds-incomplete.json) accepts
`map` through live synthesis and exact independent replay. Append exhausts its
1,024 raw slots, generalized length reaches the 90-second command deadline,
and the false control has eleven falsifications plus one inconclusive check.
All source, executable, command, and provider-definition hashes remain unchanged.
The matrix therefore remains incomplete.

The needed append and length terms already occur in the captured debug stream,
but receive backend-request failures during type verification. A separate
[witness replay](receipts/native-fold-witnesses.json) checks those exact terms,
their original full signatures and predicates, and two earlier wrong-result
controls. All eleven inventories are empty. The editable
[Lean source](NativeFoldWitnesses.lean) reproduces this diagnostic boundary;
it does not count either term as a live accepted synthesis result. Resolve
request handling before changing search caps or enlarging this matrix.

The [focused length diagnostic](receipts/native-length-diagnostic.json) uses
the same bounds and now records the original failure reason: the correct
group-2 term times out at type verification's five-second request limit with
71 seconds left in the command. The backend was already responding and had
not restarted before that request. The debug trace distinguishes this from
later exhausted-deadline failures. This is an incomplete acceptance run, with
source and executable hashes unchanged.

The [direct-request timing diagnostic](receipts/native-request-timing.json)
submits the same length verification and positive/negative decision programs
in three fresh Leant sessions with an explicit 60-second request limit. Their
command durations are 0.736, 0.790, and 0.782 seconds, excluding startup; the
negative program receives the expected Lean rejection. Exact program text and
source/executable hashes are retained. This isolates direct request cost; it
does not reproduce the preceding synthesis workload or pass the live five-second
acceptance gate.

A later [five-second direct control](receipts/native-preparation-diagnostic.json)
also times out with no synthesis preparation or search. Startup separately
takes 91 seconds; the identical type request then reaches its five-second
limit. Shared source/input and program hashes match the earlier fast run.
The attempted prepared control fails before its required preflight type error,
so it cannot establish a preparation effect. Request/startup variability remains
unresolved, and these measurements do not justify attributing the failure to
Djinn search.

The [direct stdout](receipts/native-direct-5s.stdout.txt) and
[attempted prepared stdout](receipts/native-prepared-5s.stdout.txt) retain
the startup durations and exact timeout responses; their bytes match the
process hashes in the diagnostic receipt.

The later [owned request-trace comparison](receipts/native-request-traces.json)
records a passing native Djinn length query (17.744 seconds) and exact kernel
replay. Its False control passes with fourteen falsifications and no behavioral
inconclusives, although two separate transport/type-verification timeouts still
occur. Append remains unaccepted: its positive query records ten falsifications
and two inconclusives, while its False control also fails the acceptance gate.
These are focused diagnostic results under the original search and timeout
bounds, not a completed native or cross-engine fold matrix.

All four traces retain complete bounded event inventories with zero drops.
Append's first timed-out request receives its first subsequent producer stdout
line about 466 milliseconds after the five-second timeout. Trace v1 records
backend/request ownership and transport stages but no request payload or purpose;
mapping that request to the candidate's negative-decision check is explicitly
an inference from sequential execution. This historical trace is superseded
for request correlation by the
[new empty-environment diagnosis](../docs/reports/2026-09-07-empty-environment-diagnosis.md). This
evidence does not establish a transport defect or justify increasing deadlines.

For local timing diagnostics, set `LEANT_BACKEND_TRACE` to a fresh JSON file
path before starting Leant. The opt-in trace retains at most 16,384 events,
reports dropped events, and is written at command and backend lifecycle
boundaries. It includes monotonic timestamps and process/request identities,
but no source or response payloads by default. Concurrent event insertion order
can differ from timestamp order; stdout-capture events have no inferred request
identity.

Additionally set `LEANT_BACKEND_TRACE_REQUESTS=1` to capture exact canonical
UTF-8 request JSON and callback annotations under their actual backend/request
ids. Both settings are required. Capture is limited to 128 records, 256 KiB per
payload, 8 KiB per annotation and 4 MiB total, with explicit whole-record omission
counts. Disabled capture does not demand extra snapshots. Canonical JSON is not
a claim about physical pipe byte encoding. The [diagnostic receipt](receipts/request-correlation.json)
records the strict build, 14 focused controls and all 686 unit tests passing,
the complete failed append baseline, and the matched empty-session control.
The control's actual False rejection passes while its trace exceeds the row
cap; these are distinct outcomes. Production root reuse is still pending.

The supplied family declares fresh FoldFixture.Seq, Tree, and Count datatypes,
their equality instances, and two structurally recursive fold definitions.
Automatic SizeOf generation is disabled on these datatype declarations so
counting cannot acquire an unrelated recursive size provider.
It asks for heterogeneous map, append, length, heterogeneous tree map, and
left-to-right tree flattening. The observations include empty inputs,
singletons, five-element sequences, asymmetric trees, and both Nat and Bool
elements. Accepted source must actually mention the required generic fold;
tree flattening requires both folds.

The native family leaves provider discovery off and takes a rank-N List fold
as an explicit function argument. Its map and append queries use native List;
its length query also takes an initial accumulator and successor function.
Length observations instantiate the accumulator at both Nat and Bool. Actual
List.foldr values enter only the observation expressions, and are checked
again by the isolated replay.

Native List queries with provider discovery enabled can discover List.map or
List.length from the target namespace. The private datatype family avoids that
source of reference implementations. Each query runs in a fresh Leant process,
so earlier synthesized values cannot become later providers and inventory
debug output cannot disappear behind a prior-query cache hit. Provider debug
rows are retained exactly and checked against explicit names for the folds,
constructors, and generated equality instances. An unexpected declaration is
a failed inventory check, not an automatically trusted extension.

Each selected engine/family pair includes its own actual false control. Every
successful candidate gets a separate Lean file containing the exact displayed
term, its original complete signature, its finite predicate, and the supplied
fold definitions where relevant. Acceptance requires successful kernel replay
and empty axiom inventories for the implementation, theorem, and supplied or
discovered providers. Lean must accept the fold definitions' structural
termination; synthesized terms compose these definitions without introducing
new recursive declarations.

The provider definitions also have independent kernel checks before synthesis.
Their termination and axiom evidence therefore survive even when search finds
no matching program. A failed definition check disables only its own family.

Prepare the complete 30-query matrix without starting Leant or Lean:

    python test-recursive/run_recursors.py --prepare-only --output dist-newstyle/recursor-acceptance/prepared-1

Run one focused supplied-fold operation after building the executable:

    python test-recursive/run_recursors.py --leant dist-newstyle/build/x86_64-windows/ghc-9.12.4/leant-0.1.0/x/leant/build/leant/leant.exe --engine djinn --family supplied --operation map --output dist-newstyle/recursor-acceptance/djinn-map-1

Run the complete matrix:

    python test-recursive/run_recursors.py --leant dist-newstyle/build/x86_64-windows/ghc-9.12.4/leant-0.1.0/x/leant/build/leant/leant.exe --output dist-newstyle/recursor-acceptance/all-1

Engine, family, and operation selections may be repeated to form explicit
subsets. Defaults are 1,024 candidates/verifications, 100,000 choices/steps,
80 discovered providers, interleaving, a 90-second query deadline, and a
separate 180-second guard for each fresh live or kernel process. Cases run
serially. A failed case is retained and does not prevent other independent
cases from producing their own evidence. The aggregate succeeds only if every
prepared case succeeds and all recorded sources, commands, and the executable
remain unchanged.

This runner is an acceptance specification until an executed receipt establishes
its result. It does not by itself prove recursive synthesis support, universal
behavioral laws, dependent induction, or direct synthesis of decreasing calls.
