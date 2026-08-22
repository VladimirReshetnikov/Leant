# Verification critical-path overlap

Date: 2026-08-21

Implementation commit: `8afedc3`

Serial-verifier baseline: `57e4445`

Predecessors:

- [ordered isolated parallel verification](2026-08-21-ordered-isolated-parallel-verification.md);
- [prepared isolated-pair ownership and prewarm experiment](2026-08-21-prepared-isolated-pair-prewarm-hold.md).

## Result

Leant keeps the conservative ordered isolated-verification route and removes
two serial waits from its end-to-end critical path:

1. the validated startup probe now retains the pristine process-local Lean
   environment instead of materializing that same environment again at the
   first eligible verification batch;
2. after the immutable verification artifact exists, the primary backend's
   read-only search for the next unused generated-result name runs alongside
   isolated pair setup and group verification.

The implementation is GO. The fixed release benchmark is also GO: 21
unreplaced O2 samples per cell measured B2/C2 median wall speedups of
**1.338x** and **1.327x** on the two primary verifier-isolation workloads and
**1.309x** on the contextual `List.map` workload. Their geometric mean is
**1.324x**. Candidate N1 ratios were 0.993x, 1.002x, and 0.997x, and candidate
N2 p95 improved on all three workloads.

This is substantive evidence for keeping the optimization and for an explicit
N2 acceleration claim on the measured history-free five-result workloads. It
does not select N2 by default, widen session eligibility, promise a universal
speedup, or turn imported effectful initializers/elaborators into a parity-safe
class.

## Startup environment reuse

Leant already starts the primary Lean backend before the prompt and sends one
probe to surface startup failures. That probe formerly used
`#eval (0 : Nat)` and discarded its returned environment identifier. The
first eligible verification batch later sent `#check True` solely to obtain a
pickleable current environment.

The startup probe now sends `#check True` and caches its environment only when
the response is clean:

- `hasErrors response` is false;
- `respFatal response` is absent;
- `respEnv response` is present.

`currentEnvironmentId` keeps exact precedence:

1. the current logical `rsEnv`, when a session command has advanced it;
2. the validated `rsBaseEnv` for the pristine imported session;
3. a fresh `#check True` materialization when neither identifier exists.

The cache is process-local. `ensureBackend` reconstructs session state before
the lookup, and successful restart/import/reset/snapshot reconstruction
replaces the base identifier for the new process. The value therefore cannot
cross a backend boundary. A response with errors, a fatal diagnostic, or no
environment is never cached.

Changing the startup readiness command from evaluator use to a type-check is
intentional. The strict suite, committed real-Lean route gate, and release
preflights all exercised the new command successfully against the pinned Lean
4.32 backend.

## Binding-name prefetch

Presenting a successful synthesis result may create `itN` definitions. Before
the first definition, `firstUnusedItCounter` asks the primary backend whether
candidate names collide. That request is read-only: it does not advance
`rsEnv`, `rsHistory`, the generated-result counter, proof state, or the
immutable artifact used by isolated workers.

`SynthVerificationContext` now owns both the existing command-scoped artifact
runtime and one opaque `VerificationBindingPrefetch`. For an eligible parallel
batch, Main captures the current `rsItCounter`, starts the read-only name probe
with `withAsync`, and runs the existing batch-scoped isolated pair in the
caller. Both scoped actions finish before the helper returns.

Publication is deliberately narrower than completion:

- a clean `Right` parallel result plus `Just candidate` records
  `(baseCounter, candidate)`;
- a normal parallel `Left` joins the probe but publishes nothing new;
- an exception or cancellation cancels and joins the probe through
  `withAsync` cleanup and propagates with the established precedence;
- result binding consumes the entry atomically at most once and only when the
  live counter still equals `baseCounter`;
- mismatch discards the stale entry, and absence falls back to the historical
  `firstUnusedItCounter` call.

No primary-backend request overlaps another primary-backend request. The
concurrent operation uses only the two independently owned isolated backends.
The pair still closes before a result or fallback becomes visible, and the
prefetch does not use the prepared-pair API or create a command-wide worker
pool.

## Unchanged route boundary

The predecessor's admission and fallback contract remains intact:

- quota at least two and at least two reachable candidate groups;
- at least two RTS capabilities;
- no snapshot base, accepted interactive history, active proof, or resumable
  `sorry` token;
- one lazily prepared absolute artifact per command;
- one fresh exactly-two-worker pair per eligible batch;
- candidate groups parallel, variants within each group serial;
- strict candidate-free summaries observed and reconstructed in input order;
- exact serial replay only after cleanup-free operational unavailability;
- interruption, cleanup failure, and impossible lifecycle states fail-stop;
- literal serial verification for N1 and every ineligible batch.

Imported environment restoration still reruns imported initializers, and
candidate parsing/elaboration may invoke imported code with process-local or
external effects. Parallel parity assumes those operations are deterministic
and free of externally significant or process-local effects. Users outside
that boundary must select `+RTS -N1 -RTS`.

## Deterministic and real-Lean gates

Four new behavioral tests cover the opaque prefetch:

- both actions start, parallel completion alone cannot return, and a
  successful joined probe is published and consumed once;
- normal parallel failure publishes no candidate;
- a changed logical counter discards the stale candidate;
- `ThreadKilled` cancels and joins a blocked probe and publishes nothing.

Main source characterization additionally pins clean startup-response
validation, `rsEnv` before `rsBaseEnv` before materialization, context
threading through every finalizer, and prefetch-before-pair-before-classifier
order. The complete strict Leant suite passes **578 of 578** tests. The
serialized full workspace suite, strict all-target tests-and-benchmarks build,
O2 executable build, Cabal check, source distribution, and diff checks pass.

The committed real-Lean gate passes on the exact O2 candidate:

- the history-free fixture uses one primary backend at N1 and primary plus
  exactly two isolated workers at N2, with byte-identical two-candidate output;
- the scoped-notation history control stays at one backend for both N1 and N2
  and retains byte-identical five-candidate output.

## Benchmark method

The benchmark used the documented four cells:

| Cell | Executable | RTS capabilities | Preflight backend executions |
| --- | --- | ---: | ---: |
| B1 | clean `57e4445` baseline | 1 | 1 |
| B2 | clean `57e4445` baseline | 2 | 1 |
| C1 | `8afedc3` candidate | 1 | 1 |
| C2 | `8afedc3` candidate | 2 | 3 |

Every workload/cell first ran with synthesis debug metrics and
`strace -f -e execve`. All 12 preflights proved the required 1/1/1/3 topology,
five attempts, five verified candidates, byte-identical normalized output,
and no leaked verification artifact. Timed runs removed debug and `strace`,
used fresh private temporary directories, rechecked the transcript hash and
candidate count, and retained every sample.

The release profile used two warmup cycles followed by 21 measured samples
per cell in the fixed Latin-square order, alternating workload order. It ran
with `--enforce` and returned `promotion: GO`.

Exact executable SHA-256 values:

- baseline: `9e0de4f44fcdffc9a9bf5cd35b3b062462580b6a8b8fcb5baaff854b8ee1ab2a`;
- candidate: `160ecc6fd6ccffffceea9c3b899e057717e945583d7ea0ebec14926f6e24a29b`;
- Lean 4.32 backend: `a5f259e6f5c9bef23dbfe1ca6edf05b6df0a77003e5b00111885bda2484394cb`.

The machine exposed six logical CPUs on Linux 5.15. `/proc` process trees were
sampled every 20 ms. Aggregate RSS sums resident pages across processes and
can double-count shared pages; short peaks can fall between samples. CPU and
RSS are therefore conservative comparison signals rather than accounting
measurements.

## Release results

Wall, CPU, and aggregate RSS are medians. Wall p95 is nearest-rank. The exact
252-row table is committed as
[`bench-verification/results/2026-08-21-critical-path-overlap-release.tsv`](../../bench-verification/results/2026-08-21-critical-path-overlap-release.tsv),
SHA-256
`80d3b1e5f87b2138c0ea9a3d6449533f6b63b4a6686a535e529d58bdf8c19fa9`.

| Workload | Cell | wall median | wall p95 | CPU | aggregate RSS | GHC allocation |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| state-thread | B1 | 7.821 s | 8.551 s | 7.500 s | 4824.6 MiB | 19.5 MiB |
| state-thread | B2 | 7.729 s | 8.035 s | 7.490 s | 4824.5 MiB | 19.5 MiB |
| state-thread | C1 | 7.765 s | 8.298 s | 7.500 s | 4821.9 MiB | 19.5 MiB |
| state-thread | C2 | 5.778 s | 6.186 s | 5.880 s | 3498.1 MiB | 20.4 MiB |
| continuation | B1 | 7.729 s | 8.240 s | 7.470 s | 4824.0 MiB | 25.3 MiB |
| continuation | B2 | 7.710 s | 8.344 s | 7.470 s | 4824.7 MiB | 25.3 MiB |
| continuation | C1 | 7.742 s | 8.259 s | 7.470 s | 4823.3 MiB | 25.4 MiB |
| continuation | C2 | 5.812 s | 6.599 s | 5.870 s | 3499.5 MiB | 26.3 MiB |
| library-map | B1 | 7.856 s | 8.303 s | 7.610 s | 4826.0 MiB | 31.8 MiB |
| library-map | B2 | 7.868 s | 8.173 s | 7.620 s | 4830.5 MiB | 31.8 MiB |
| library-map | C1 | 7.831 s | 8.343 s | 7.600 s | 4823.7 MiB | 31.8 MiB |
| library-map | C2 | 6.010 s | 6.333 s | 6.100 s | 3488.6 MiB | 32.8 MiB |

Derived ratios:

| Workload | B2/C2 wall | C1/C2 wall | C1/B1 wall | C2/B2 CPU | C2/B2 RSS | C2/B2 allocation |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| state-thread | 1.338x | 1.344x | 0.993x | 0.785x | 0.725x | 1.047x |
| continuation | 1.327x | 1.332x | 1.002x | 0.786x | 0.725x | 1.039x |
| library-map | 1.309x | 1.303x | 0.997x | 0.801x | 0.722x | 1.030x |

Transcript SHA-256 remained exact in preflight and every timed sample:

- state-thread: `ce055ee44eb7e6d8f8b969a32e9cd2dd85855e9646190a712a45ad2e55bddb6c`;
- continuation: `dbdc8ef04e90278fd773e07bc8477f3b5f59e1fbf2370910c0baaf7303dec9e7`;
- library-map: `5cc74a4cb216329ee5c4b3c8db6a4ef4403ac1b7193d5ec9d3f8ed93e0010d6d`.

## Decision and remaining HOLDs

The implementation clears every predeclared promotion condition: both primary
B2/C2 medians exceed 1.25x, candidate N2 p95 improves, N1 stays within 5%,
allocation stays within 10%, process-tree CPU and RSS signals stay within 25%,
and the three-workload geometric mean is positive at **1.324x**. This is a
release-grade GO for the measured explicit-N2 route.

The following remain HOLD:

- selecting N2 by default without broader workload and residency evidence;
- widening eligibility to snapshots, accepted history, proof state, or a
  resumable `sorry` token;
- promising parity for imported initializers, macros, or elaborators with
  externally significant or process-local effects;
- retaining an isolated pair across verification batches or commands;
- activating the prepared-pair API in Main;
- changing search deadlines, quotas, ordered commit, or failure precedence;
- claiming this result for every synthesis workload or backend version.

## Reproduction

Build both binaries with the same compiler and explicit O2 profile, repeating
the profile for `list-bin`, then run:

```console
./bench-verification/benchmark.py \
  --baseline /absolute/path/to/baseline/leant \
  --candidate /absolute/path/to/candidate/leant \
  --backend /absolute/path/to/repl \
  --warmups 2 \
  --samples 21 \
  --results /absolute/path/to/results.tsv \
  --artifacts /absolute/path/to/raw-artifacts \
  --enforce
```

The run must preserve all preflight and timed transcript hashes, candidate
counts, artifact-cleanup checks, and unreplaced samples before its performance
summary is admissible.
