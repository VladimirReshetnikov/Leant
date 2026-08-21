# Ordered isolated parallel Lean verification

Date: 2026-08-21

Implementation commit: `ea75133`

Serial-verifier baseline: `57e4445`

> **Successor:** commit `a35863e` added a safe one-shot prepared-pair owner,
> but an experimental Main prewarm measured only 1.165x and 1.166x B2/C2 on
> the primary five-sample screen, below the fixed 1.25x gate. The Main
> experiment was removed. See the
> [prepared-pair and prewarm HOLD report](2026-08-21-prepared-isolated-pair-prewarm-hold.md).

## Result

Leant now has an end-to-end, package-private-to-Main route for verifying
different synthesis candidate groups on two isolated Lean backend processes.
The route is enabled only when the user starts the threaded executable with at
least two RTS capabilities and the command satisfies a conservative semantic
gate. N1 enters the literal established serial verifier.

The implementation and parity gates are GO. The performance decision is more
limited: a route-certified five-sample O2 screen recorded 1.166x and 1.169x
B2/C2 median wall ratios on the two primary workloads and a 1.159x geometric
mean across all three workloads. Those observations favor the candidate in
this screen, but the screening profile and its HOLD are not acceleration
evidence: both ratios are below the provisional 1.25x promotion threshold.
The checkpoint is therefore useful opt-in N2 functionality, not evidence for
selecting N2 by default or claiming a universal verification speedup.

## Production boundary

The route composes four previously separate boundaries:

1. `Leant.Synth.Verification` reduces one candidate group to a strict,
   candidate-free `GroupVerificationSummary` and reconstructs the historical
   `VerificationBatch` from ordered summaries.
2. `Leant.Synth.Verification.Parallel` admits lazy waves no wider than the
   remaining success quota, forces summaries in workers, and observes results
   and exceptions in input order.
3. `Leant.Backend.Isolated` owns two independent Lean processes, their
   process-local restored environments, serialized lease requests, poison,
   and whole-tree cleanup.
4. `Leant.Synth.Verification.Runtime` owns the optional command artifact,
   sticky serial fallback, and the exhaustive operational-versus-fatal failure
   classifier without importing Main's session type.

All four remain Cabal `Other-Modules`; no public Haskell API or user-facing
jobs setting was added.

### Eligibility and N1

One batch is eligible only when its accepted-result quota is at least two and
its lazy group spine exposes at least two groups. Before capability or
filesystem/backend work, the artifact runtime checks that the current session
has:

- no `rsSnapshotBase`;
- no active `rsProve` token;
- no resumable `rsLastSorry` token;
- no accepted interactive `rsHistory`.

The history restriction is necessary rather than cosmetic. The upstream Lean
REPL snapshot format does not preserve arbitrary session-created scoped
extension entries. Before this gate, a scoped-notation session silently
produced two N2 candidates where N1 produced five: isolated workers returned
valid JSON rejections, so infrastructure fallback could not detect the
semantic loss. The gate makes that session take the serial route at N2.

If the session is unsafe, capabilities are below two, or the batch is too
small, `runVerificationBatchWith` calls `synthVerifySerial` without evaluating
the artifact action. N1 therefore performs no snapshot, temporary-path, pair,
or worker operation and remains the exact compatibility control.

### Artifact ownership

The first eligible batch asks the primary backend for its current environment,
resolves the temporary directory to an absolute path, and reserves a
collision-resistant absent sibling of `leant-parallel-verification.olean`.
The runtime records ownership while masked before the interruptible pickle
request can create the file. One immutable artifact is reused by later
eligible batches in that synthesis command.

Normal preparation failure becomes sticky serial. Successful early removal
clears ownership immediately so command-final cleanup cannot delete a foreign
file which later reused the same name. Failed removal retains ownership for a
final retry. Callback exceptions remain primary over artifact-cleanup
exceptions; cleanup failure is surfaced after normal callback completion.

Primary-backend acquisition and protocol use were hardened at the same time.
Spawn publication is masked, and an exception after a request enters the
protocol retires and invalidates that backend before the exception is
rethrown. A half-read response can therefore never be consumed as the next
request's reply.

### Pair and group ownership

Each eligible verification batch acquires and closes one fresh pair. Pair
setup starts both spawn-and-restore actions concurrently. A masked atomic
registry records each backend before its setup becomes interruptible; the
parent observes logical worker one first and cleans registered processes in
ordinal order. Logical failure precedence is consequently independent of
which fake or real OS process claims a marker first.

One parallel scheduler task leases one backend for a complete candidate group.
That group tries textual variants serially and stops at its first accepted
variant. The worker deeply forces only the candidate-free summary before
publication. Ordered reconstruction then reattaches the original receipts and
attempt prefix without forcing an accepted variant suffix or any group beyond
the serial success cutoff.

Rejected groups do not consume the accepted-result quota. Accepted candidates,
variant attempts, per-reason failure counts, observations, success cutoff, and
exception precedence therefore match the serial verifier. No backend pipe is
shared concurrently.

### Failure and cancellation

The typed scheduler exception is caught inside the pair callback. That lets
the callback return normally and gives pair closure a chance to attach stable
poison and worker-labelled cleanup failures before Main decides whether to
fallback.

The following cleanup-free operational failures disable parallelism for the
rest of the command and replay the exact batch serially, after the pair has
closed:

- spawn failure;
- restore fatal/error/missing-environment response;
- restore or command timeout;
- backend EOF;
- malformed backend response.

Interrupted requests, cleanup failure, and closed/retired lease or pair states
are not fallbackable. They are cancellation or lifecycle evidence and remain
fail-stop. Arbitrary programmer and asynchronous exceptions propagate after
scoped worker cleanup. The existing backend lifecycle owns POSIX process groups
and Windows Jobs, so cancellation and partial setup close whole trees rather
than only direct wrappers.

## Parity boundary

Imported modules are restored by reimporting them with extensions enabled.
That preserves imported environment metadata, but it also reruns imported
module initializers in each worker. Imported macros and elaborators can perform
process-local or external I/O while candidate text is elaborated. Exact parity
therefore assumes that import restoration and candidate elaboration are
deterministic and free of externally significant or process-local effects.
Users whose environment violates that assumption must select
`+RTS -N1 -RTS`.

This limitation is distinct from the gated session-extension bug: imported
extensions are rebuilt, whereas accepted session history is excluded because
the current snapshot format can lose entries created after import.

## Deterministic and real-backend gates

The focused isolated-pair group passes 28 of 28 cases. It includes
simultaneous restore admission, deterministic worker-one failure precedence,
simultaneous-setup cancellation, partial ownership cleanup, distinct process
and environment identity, request serialization, escaped-lease rejection,
in-flight release, stable poison, sibling completion, callback precedence,
and atomic close ordering.

The scheduler, summary, and runtime tests pin:

- literal caller-thread N1 behavior;
- guard order and poisoned-tail laziness;
- strict worker publication;
- ordered results and exceptions;
- success-only quota accounting;
- artifact ownership before preparation;
- sticky fallback and cleanup precedence;
- exhaustive classification of every isolated failure constructor;
- no conversion of interruption into serial fallback.

The complete strict Leant suite passes 557 of 557 tests. The serialized full
workspace suite, strict all-target tests-and-benchmarks build, Cabal check,
source distribution, diff checks, shellcheck, and Python syntax check pass.

`test/run-parallel-verification-gate.sh` supplies the real Lean route proof:

- a history-free two-result fixture launches one backend at N1 and exactly
  three at N2, with byte-identical normalized transcripts;
- the scoped-notation history fixture launches one backend at both N1 and N2
  and retains the same five-candidate transcript.

The gate requires `strace` and an explicit `LEANT_BACKEND` for route evidence
on Linux. An explicit skip exists for portability, but a skipped trace is not
release route evidence.

## Benchmark method

`bench-verification/benchmark.py` compares four fresh-process cells:

| Cell | Binary | RTS capabilities | Required backend executions |
| --- | --- | ---: | ---: |
| B1 | clean `57e4445` baseline | 1 | 1 |
| B2 | clean `57e4445` baseline | 2 | 1 |
| C1 | `ea75133` candidate | 1 | 1 |
| C2 | `ea75133` candidate | 2 | 3 |

The two primary fixtures are history-free, default-Djinn, five-result goals:
a state-threading product and a nested continuation. Baseline N1 and N2 use
the same search route, so B2/C2 isolates the candidate implementation at a
fixed capability count. `List.map` is a contextual third workload whose N2
path also includes the already-published parallel base/library search.

Before timing, every cell and workload runs under debug plus
`strace -f -e execve`. Preflight requires:

- exactly `it1` through `it5`;
- exactly five attempted variants and five verified candidates;
- byte-identical normalized debug and semantic transcripts;
- the 1/1/1/3 backend topology;
- no verification artifact beneath the private temporary directory.

Timed runs remove debug and `strace`, use fresh private temporary directories,
force a 600-second synthesis timeout, clear `GHCRTS`, and stabilize locale and
time zone. One warmup and five measured samples per cell were run in a fixed
Latin-square cell order with alternating workload order. This is a screening
profile, not the documented release profile of two warmups and 21 samples.

The exact binaries were:

- baseline: `9e0de4f44fcdffc9a9bf5cd35b3b062462580b6a8b8fcb5baaff854b8ee1ab2a`;
- candidate: `85e7c79082d1a52f5fb60aa064d05736e33462ed754a59981d5bdaaab2ce828e`;
- Lean 4.32 backend: `a5f259e6f5c9bef23dbfe1ca6edf05b6df0a77003e5b00111885bda2484394cb`.

The machine exposed six logical CPUs on Linux 5.15. `/proc` was sampled every
20 ms. CPU is the summed process-tree counter, RSS is the sampled sum of
resident pages across the tree and double-counts shared pages, and allocation
is the root Haskell process's GHC total. These are comparison signals, not
precise resource accounting.

## Screening results

Wall, CPU, and aggregate RSS values below are medians. Wall p95 uses the
nearest-rank sample.

| Workload | Cell | wall median | wall p95 | CPU | aggregate RSS | GHC allocation |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| state-thread | B1 | 7.604 s | 7.906 s | 7.370 s | 4856.1 MiB | 19.5 MiB |
| state-thread | B2 | 7.631 s | 8.074 s | 7.440 s | 4858.1 MiB | 19.5 MiB |
| state-thread | C1 | 7.602 s | 8.102 s | 7.330 s | 4856.7 MiB | 19.5 MiB |
| state-thread | C2 | 6.547 s | 6.865 s | 6.190 s | 3583.1 MiB | 20.4 MiB |
| continuation | B1 | 7.509 s | 7.758 s | 7.310 s | 4857.3 MiB | 25.3 MiB |
| continuation | B2 | 7.579 s | 7.780 s | 7.330 s | 4856.7 MiB | 25.3 MiB |
| continuation | C1 | 7.587 s | 7.760 s | 7.360 s | 4857.0 MiB | 25.4 MiB |
| continuation | C2 | 6.486 s | 6.704 s | 6.120 s | 3576.1 MiB | 26.3 MiB |
| library-map | B1 | 7.698 s | 8.040 s | 7.470 s | 4858.9 MiB | 31.8 MiB |
| library-map | B2 | 7.617 s | 7.868 s | 7.390 s | 4864.8 MiB | 31.8 MiB |
| library-map | C1 | 7.622 s | 7.843 s | 7.390 s | 4858.8 MiB | 31.8 MiB |
| library-map | C2 | 6.658 s | 6.847 s | 6.260 s | 3573.9 MiB | 32.8 MiB |

Derived ratios:

| Workload | B2/C2 wall | C1/C2 wall | C1/B1 wall | C2/B2 CPU | C2/B2 RSS | C2/B2 allocation |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| state-thread | 1.166x | 1.161x | 1.000x | 0.832x | 0.738x | 1.048x |
| continuation | 1.169x | 1.170x | 1.010x | 0.835x | 0.736x | 1.040x |
| library-map | 1.144x | 1.145x | 0.990x | 0.847x | 0.735x | 1.031x |

Transcript SHA-256 remained exact in preflight and every timed sample:

- state-thread: `ce055ee44eb7e6d8f8b969a32e9cd2dd85855e9646190a712a45ad2e55bddb6c`;
- continuation: `dbdc8ef04e90278fd773e07bc8477f3b5f59e1fbf2370910c0baaf7303dec9e7`;
- library-map: `5cc74a4cb216329ee5c4b3c8db6a4ef4403ac1b7193d5ec9d3f8ed93e0010d6d`.

## Decision and next checkpoint

The semantic, route, N1, p95, CPU, RSS, and allocation gates pass. The two
primary median wall gates do not: 1.166x and 1.169x are below 1.25x. Lowering
the threshold after observing the data would turn a promotion rule into a
description, so the report retains the HOLD.

The route remains valuable as explicit opt-in functionality. All three screen
median ratios favor the candidate, and the resource signals stayed within
their gates, but the result must remain non-promotional and narrowly
described.

The most plausible next optimization is to overlap the already-parallel
two-worker preparation with the pure initial search. The current critical path
does not start pair acquisition until search and artifact preparation finish.
Hiding roughly 0.44 seconds would be enough to cross the present primary gate.
That follow-up is not semantics-free: eagerly preparing workers for an N2
search miss reruns imported initialization even when no verification batch is
eventually used. It needs an opaque one-shot prepared-pair owner, typed unused
cleanup, unchanged search-deadline placement, explicit speculative-N2 effect
documentation, miss/cancellation tests, and a fresh 2x2 screen. It belongs in a
separate commit rather than being folded into this audited checkpoint.

## Reproduction

Build baseline and candidate with the same compiler and explicit O2 profile,
repeating the optimization flag for `list-bin`:

```console
cabal build exe:leant --enable-optimization=2 -j1 --ghc-options=-Werror
cabal list-bin exe:leant --enable-optimization=2
```

Then run the release profile:

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

`--enforce` exits unsuccessfully when the performance promotion gate remains
HOLD. Route, transcript, candidate, timeout, and artifact failures are always
fatal, even without `--enforce`.
