# Direct pristine verification-worker initialization screen

Date: 2026-08-21

Status: semantic audit complete; direct initialization is **HOLD** and the
production command-scoped environment artifact remains authoritative. Gate
hardening landed at `a9f74c2`; no production route changed in that commit.

## Decision

Do not initialize candidate-verification workers by importing Leant's compiled
synthesis-tooling module. That module is intentionally built on `import Lean`
and `Lean.Environment`, so it is a serializer cache, not a representation of
the user's current verification environment. Loading it in an N2 worker can
make names available which the pristine serial session cannot resolve.

A semantically sound control initialized each worker through the existing
empty-history replay protocol, whose empty case materializes the same
`#check True` base as a fresh primary session. That candidate passed every
transcript, topology, route, cache, and cleanup check, but its fixed-N2
five-sample medians were neutral: **0.974x**, **1.019x**, and **1.003x** B2/C2,
for a **0.999x** geometric mean. The experimental Main route was removed.

Production therefore continues to pickle the exact eligible command
environment once and restore each fresh isolated pair from that artifact.

This incremental HOLD does not discount the connected verifier's earlier
roughly **16.5% measured acceleration**. A double-digit measured result is
worth retaining as screening evidence. The fixed 1.25x threshold is a
separate release-promotion gate, not a definition of whether an observed
speedup is meaningful.

## Semantic rejection of the compiled-module route

Serial candidate verification runs in the user's current primary Lean
environment. For a fresh no-import session, startup establishes only the
validated environment returned by `#check True`. The compiled tooling module,
by contrast, contains Leant's generated synthesis support and was compiled
after importing Lean implementation modules.

A real Lean 4.32 probe made the mismatch concrete. The exact candidate-check
shape involving `Lean.Elab.Command.CommandElabM` and
`Lean.Elab.Command.elabCommand` fails with unknown-identifier diagnostics
after `#check True`, but succeeds after `import Lean`. An N2 worker initialized
from the tooling module could therefore accept a spelling which N1 rejects,
consume the ordered success quota early, and present a result that the primary
session cannot bind.

The committed
[`pristine-hidden-type.txt`](../../test/parallel-verification/pristine-hidden-type.txt)
fixture turns that finding into a route gate. Its goal is visible to Leant's
synthesis translator but not to the pristine Lean session. N1 and N2 must both
return zero verified candidates; N2 must nevertheless execute the primary plus
exactly two isolated workers. A richer worker initializer would make the
projection candidates verify and fail the transcript comparison.

## Sound direct-pristine control

The corrected experiment used the established package-private replay owner:

```haskell
withIsolatedBackendPairReplaying config [] [] timeout callback
```

With no imports or history, each worker executes the same `#check True`
materialization as the primary startup base. No process-local environment ID
crosses a process, and the ordinary pair still owns concurrent setup,
worker-one failure precedence, request serialization, cancellation, and
complete process-tree cleanup.

This was deliberately only a control for the already-conservative production
eligibility gate. It did not widen eligibility to snapshots, accepted
history, active proof state, or resumable `sorry` state. It also did not
change group ordering, serial variant traversal, success quota, fallback
classification, or the literal N1 verifier.

## Benchmark method

The six-cell compiled-tooling harness compared the exact cache-enabled parent
and the corrected experimental candidate:

| Cell | Executable | RTS capabilities | Worker initializer |
| --- | --- | ---: | --- |
| B1 | clean `896840a` | 1 | serial primary |
| B2 | clean `896840a` | 2 | exact environment artifact |
| C1 | experimental candidate | 1 | serial primary |
| C2 | experimental candidate | 2 | direct pristine replay |
| D1 | clean `896840a`, private cold cache | 1 | serial primary |
| D2 | experimental candidate, private cold cache | 1 | serial primary |

The run used one warmup cycle and five measured samples for each of three
workloads. It completed all 12 untimed preflights, 18 warmup invocations, and
90 measured invocations without replacement. Preflight proved byte-identical
debug and semantic transcripts, five attempted and verified candidates,
1/3/1/3 backend executions in B1/B2/C1/C2, exact cache-module opens, the B2
artifact route, the artifact-free C2 control, and no leaked temporary artifact.
Every measured row rechecked the transcript hash and candidate count.

Exact provenance:

- source parent: `896840a29ba3afc6ae4d43cadca9034328ba7a67`;
- parent O2 executable SHA-256:
  `7220670e4a37aad33729952006c44c0c0f93222d17a230010f1e03d4692e9d79`;
- experimental O2 executable SHA-256:
  `e114c8679abc6a7991fdc7c2b5d69b675809791508c4b9c36715784faa151540`;
- Lean 4.32 backend SHA-256:
  `a5f259e6f5c9bef23dbfe1ca6edf05b6df0a77003e5b00111885bda2484394cb`;
- 90-row result TSV SHA-256:
  `18b0b7f007b0a98019b40a288e12d90386c72151ef00401e6191fa519045b206`.

The candidate was an intentionally uncommitted experiment based on the stated
parent and was removed after the screen. Its executable hash and the report's
method identify the measured bytes; the maintained harness retains
`--candidate-n2-initializer pristine-replay` for controlled comparisons, while
its production default remains `artifact`.

## Screening results

Wall times are seconds. p95 is nearest-rank over five samples.

| Workload | B2 median/p95 | C2 median/p95 | B2/C2 |
| --- | ---: | ---: | ---: |
| state-thread | 3.114/3.189 | 3.196/3.226 | **0.974x** |
| continuation | 3.093/3.269 | 3.037/3.118 | **1.019x** |
| `List.map` | 3.251/3.314 | 3.240/3.484 | **1.003x** |

The B2/C2 geometric mean was **0.999x**. Candidate N1 versus baseline N1 was
0.975x, 0.996x, and 1.013x. The private cold N1 controls were 0.978x, 1.017x,
and 0.902x. Those controls and every semantic gate were acceptable, but the
fixed-N2 change itself produced no incremental wall-time improvement.

This is negative attribution evidence, not a claim that parallel verification
has no value. The baseline already contains the connected verifier, its later
critical-path overlap release profile measured a 1.324x geometric mean, and
the tooling cache subsequently measured 1.940x at fixed N2. This experiment
asked only whether replacing the exact artifact with an exact pristine replay
made that established route faster. It did not.

## Gate hardening retained

Although the production experiment was removed, its audit produced durable
tests in `a9f74c2`:

- all six immediate invalid-setup fixtures now hold both worker processes
  behind a shared barrier before releasing identical failures, so worker-one
  precedence and sibling cleanup are deterministic rather than scheduler-
  dependent;
- the real-Lean gate adds the pristine hidden-type counterexample;
- warm and cold N2 controls prove the retained artifact route, exact
  three-backend topology, cache publication/open behavior, transcript parity,
  and artifact cleanup; and
- the benchmark harness can state whether the baseline already contains the
  compiled cache and can audit an experimental candidate initializer without
  changing the production default.

On the final artifact-route checkpoint, the focused isolated/runtime group
passed 50/50 three times, the complete strict Leant suite passed 585/585, all
Djex and Leant suites passed serially with `-Werror`, the strict all-target
tests-and-benchmarks build passed, and Cabal check plus source-distribution
inclusion were clean. The expanded real-Lean gate passed with exact warm/cold
artifact routing, one-versus-three history-free and hidden-type topology, and
one-versus-one scoped-history serial control.

## Remaining boundary

The command artifact stays authoritative until another representation can
prove that it recreates the user's exact candidate-verification environment.
A future alternative must first pass the hidden-type fixture and the complete
session-parity corpus, then demonstrate incremental benefit against the
current artifact route. Reusing the synthesis-tooling module as a verification
environment remains rejected even if it appears faster.
