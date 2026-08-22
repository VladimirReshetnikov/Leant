# Prepared isolated-pair ownership and prewarm experiment

Date: 2026-08-21

Foundation commit: `a35863e`

Connected verification route: `ea75133`

Serial-verifier benchmark baseline: `57e4445`

> **Successor:** commit `8afedc3` kept this prepared API disconnected and
> removed different critical-path waits: it reused the validated startup
> environment and overlapped binding-name discovery with isolated
> verification. The enforced 21-sample release profile returned GO at
> 1.338x/1.327x on the two primary workloads. See the
> [critical-path overlap report](2026-08-21-verification-critical-path-overlap.md).

## Result

Leant now has a package-private, one-shot owner for preparing an isolated
two-worker Lean backend pair while an enclosing caller performs independent
work. The ownership checkpoint is GO: it closes the setup-publication gap,
linearizes competing claims, cancels and joins an unused preparation, closes a
consumed pair before returning, and prevents a detached claim from escaping
the preparation scope.

The proposed production use was not promoted. Its measured double-digit route
gain was meaningful, but an experimental Main route
prepared the artifact synchronously and overlapped pair spawn/restore with one
historically serial initial search. Its route-certified five-sample O2 screen
measured B2/C2 median wall ratios of **1.165x** and **1.166x** on the two
primary workloads, below the fixed **1.25x** promotion threshold. The
geometric mean across all three workloads was **1.167x**. That screen was not
the release profile, and—more importantly for this experiment—the result was
effectively unchanged from the already connected route. It did not establish
an incremental benefit for this prewarm seam.

The experimental Main and real-Lean unused-prewarm fixture were therefore
removed before `a35863e` was committed. Production still prepares the command
artifact lazily at the first eligible verification batch and scopes one fresh
pair around that batch. The new prepared-pair API has no Main caller.

## Foundation boundary

### Concurrent acquisition

`Leant.Backend.Isolated` starts both worker spawn-and-restore actions before it
observes either result. Each child publishes its newly spawned backend into a
masked ordinal registry before restoration becomes interruptible. The parent
still observes logical worker one before worker two, so concurrent operating
system scheduling cannot change failure precedence. Registered backends are
cleaned in ordinal order.

The ordinary `withIsolatedBackendPair` route uses this concurrent acquisition
too. Its pair, leases, poison state, request serialization, and close semantics
are otherwise unchanged.

### One-shot preparation

The opaque `PreparedIsolatedBackendPair` is created only inside:

```haskell
withIsolatedBackendPairPreparation
  :: BackendConfig
  -> FilePath
  -> Maybe Int
  -> (PreparedIsolatedBackendPair -> IO a)
  -> IO (a, PreparedPairFinalization)
```

The manager owns both acquisition children before it admits the caller
callback. It publishes one terminal acquisition outcome into an `MVar`; the
prepared value never exposes an `Async`, `Backend`, handle, environment ID, or
worker process.

Exactly one caller may claim the preparation through:

```haskell
runPreparedIsolatedBackendPair
  :: PreparedIsolatedBackendPair
  -> (IsolatedBackendPair -> IO a)
  -> IO (Either IsolatedBackendFailure a)
```

An atomic claim transition records the claimant and its completion cell.
Concurrent, repeated, or post-scope claims return
`IsolatedBackendPreparationClaimed`; the runtime's exhaustive classifier marks
that lifecycle state fatal rather than serial-fallbackable.

### Publication and transfer

Publishing a successful pair is not yet an ownership transfer. After reading
the terminal outcome, the claimant joins the acquisition manager through an
uncancellable handoff before it enters the ordinary acquired-pair bracket.
The manager has only its masked publication tail left at that point; all
spawn, restore, and cleanup work precedes publication. Cancellation before
publication discards the acquisition and preserves the original exception.

This ordering closes a concrete race found during independent audit. Before
the repair, cancellation could arrive after the claimant read a successful
pair but while it waited interruptibly for the manager wrapper. Neither the
manager nor the claimant would then close the already-published workers.

### Scope finalization

Normal callback return produces one of three explicit outcomes:

- `PreparedPairConsumed` when a claim completed inside the scope;
- `PreparedPairDiscarded` when an unused acquisition and pair closed cleanly;
- `PreparedPairDiscardedWithFailure failure` when unused setup or teardown
  failed.

An unused scope sends a private discard exception to the manager, joins it,
reads the terminal outcome, and closes any successfully prepared pair before
returning. A scope with a detached active claimant first seals the prepared
state, sends a private scope-closing exception to that claimant, and waits for
its completion cell. Callback and cancellation exceptions remain primary over
cleanup exceptions.

Both post-publication ownership paths are characterized with a deterministic
test hook. One test holds the manager after publication while a claimant is
cancelled at the async `STM` join; another holds the same tail while an unused
scope finalizes. Neither path may return before the manager is released and
joined.

## Experimental Main route

The discarded experiment deliberately chose the narrowest existing serial
search seam. It admitted prewarming only when all of the following held:

- the command selected the structural-first path;
- synthesis limits were exactly the defaults;
- no library premise was selected;
- the cursor could not request a filter successor;
- neither the structural `EngineBoth` pair nor the base/library pair was
  eligible;
- the session passed the established no-snapshot, no-history, no-proof, and
  no-resumable-sorry artifact gate;
- at least two RTS capabilities were available.

The primary backend still created the environment artifact synchronously.
Only after that completed did the prepared-pair scope start. The callback then
captured the unchanged search deadline and ran the initial baseline, allowing
worker spawn and restoration to overlap pure search. The first eligible
verification batch could claim the pair once. The scope closed before provider
or classical continuation; an unused pair was cancelled and joined.

This design avoided nested Haskell search and Lean-worker pools, avoided a
cancelable speculative request on the primary backend, and preserved the
existing deadline. It nevertheless reran imported initialization and consumed
worker resources speculatively on N2 searches which might never reach a
verification batch. That cost required measured benefit rather than an
assumption.

## Deterministic and real-backend evidence

The prepared subgroup contains 17 cases covering:

- overlap after both setup children are owned;
- sequential and simultaneous one-shot claims;
- late and escaped claim rejection;
- discard before startup, during restore, and after readiness;
- claimed and unclaimed post-publication manager joins;
- deterministic worker-one setup-failure precedence;
- cancellation during startup, restore, claim, and pair callback;
- a detached claimed run at scope exit;
- callback-exception precedence on both unused and consumed paths.

The broader `-p prepared` pattern passed 26 of 26 tests in five independent
repetitions after strict compilation. An audit found one test-only race in the
fast setup-failure fixture: worker one could fail before worker two established
its heartbeat. The repaired fixture holds both fake restores behind a shared
gate, waits for both `.setup` markers, then releases identical fatal replies.
It now pins two owned processes, worker-one precedence, and sibling cleanup
with a real happens-before relation.

The final narrowed checkpoint passed:

- 17 of 17 prepared-pair cases;
- 26 of 26 tests in the broad prepared pattern;
- 574 of 574 complete strict unit tests;
- the strict all-target tests-and-benchmarks build;
- the strict O2 executable build;
- Cabal check and diff check;
- source-distribution construction with byte-identical copies of all three
  changed files;
- the existing real-Lean gate: one versus three backend processes with
  history-free transcript parity, and one versus one for the scoped-history
  serial control.

The independent prepared-pair audit returned GO after five fresh repetitions.

## Benchmark method

The same fixed four-cell harness and workloads as the connected-route report
were used:

| Cell | Binary | RTS capabilities | Required backend executions |
| --- | --- | ---: | ---: |
| B1 | clean `57e4445` baseline | 1 | 1 |
| B2 | clean `57e4445` baseline | 2 | 1 |
| C1 | experimental prewarm candidate | 1 | 1 |
| C2 | experimental prewarm candidate | 2 | 3 |

The two primary fixtures were the history-free, default-Djinn
`state-thread` and `continuation` goals. `library-map` remained the contextual
control. Every preflight required five attempted and verified candidates,
byte-identical normalized output, exact 1/1/1/3 backend topology, and no
artifact leak. Every timed sample rechecked the transcript hash and candidate
count without `strace` or debug output.

One warmup and five measured samples per cell were run in the fixed Latin
square order. This is a screen, not the release profile of two warmups and 21
samples. Because the screen failed the primary threshold, no 21-sample run was
performed.

Exact executables and evidence:

- baseline O2 binary:
  `9e0de4f44fcdffc9a9bf5cd35b3b062462580b6a8b8fcb5baaff854b8ee1ab2a`;
- experimental candidate O2 binary:
  `ba54009e3475dd22d3c0783f23414fdb615a6f48001d7551a213bafbbedad5cb`;
- Lean 4.32 backend:
  `a5f259e6f5c9bef23dbfe1ca6edf05b6df0a77003e5b00111885bda2484394cb`;
- 61-line result TSV:
  `79ed323bd889cf6a010845af8e407cc343aeec87a72cf6417ebe6dfdcf1c0687`;
- sorted preflight/timed artifact manifest:
  `b7b37653a69fb7609ae897c1c061d81fd07dd639aeff44d866e47c0802b67014`.

The machine exposed six logical CPUs on Linux 5.15. `/proc` was sampled every
20 ms. Aggregate RSS sums resident pages across the process tree and therefore
double-counts shared pages; CPU and RSS remain comparison signals rather than
accounting measurements.

## Screening results

Wall, CPU, and aggregate RSS values are medians. Wall p95 is the nearest-rank
maximum of five samples.

| Workload | Cell | wall median | wall p95 | CPU | aggregate RSS | GHC allocation |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| state-thread | B1 | 7.775 s | 7.854 s | 7.510 s | 4858.9 MiB | 19.5 MiB |
| state-thread | B2 | 7.780 s | 8.035 s | 7.530 s | 4859.0 MiB | 19.5 MiB |
| state-thread | C1 | 7.871 s | 8.298 s | 7.650 s | 4855.9 MiB | 19.5 MiB |
| state-thread | C2 | 6.681 s | 7.423 s | 6.330 s | 3598.5 MiB | 20.4 MiB |
| continuation | B1 | 7.716 s | 7.848 s | 7.470 s | 4857.1 MiB | 25.3 MiB |
| continuation | B2 | 7.791 s | 8.098 s | 7.530 s | 4856.5 MiB | 25.3 MiB |
| continuation | C1 | 7.721 s | 7.817 s | 7.440 s | 4855.9 MiB | 25.4 MiB |
| continuation | C2 | 6.681 s | 6.886 s | 6.240 s | 3586.9 MiB | 26.3 MiB |
| library-map | B1 | 7.716 s | 8.058 s | 7.490 s | 4858.7 MiB | 31.8 MiB |
| library-map | B2 | 7.876 s | 8.091 s | 7.610 s | 4861.8 MiB | 31.8 MiB |
| library-map | C1 | 7.931 s | 8.125 s | 7.700 s | 4857.6 MiB | 31.8 MiB |
| library-map | C2 | 6.730 s | 6.917 s | 6.340 s | 3580.0 MiB | 32.8 MiB |

Derived ratios:

| Workload | B2/C2 wall | C1/C2 wall | C1/B1 wall | C2/B2 CPU | C2/B2 RSS | C2/B2 allocation |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| state-thread | 1.165x | 1.178x | 1.012x | 0.841x | 0.741x | 1.048x |
| continuation | 1.166x | 1.156x | 1.001x | 0.829x | 0.739x | 1.040x |
| library-map | 1.170x | 1.179x | 1.028x | 0.833x | 0.736x | 1.031x |

The B2/C2 geometric mean was **1.167x**. Candidate N2 p95 was below baseline
N2 p95 on every workload. N1, allocation, total process-tree CPU, and
aggregate-RSS ratios stayed within their gates.

Transcript SHA-256 remained exact in every preflight and timed sample:

- state-thread:
  `ce055ee44eb7e6d8f8b969a32e9cd2dd85855e9646190a712a45ad2e55bddb6c`;
- continuation:
  `dbdc8ef04e90278fd773e07bc8477f3b5f59e1fbf2370910c0baaf7303dec9e7`;
- library-map:
  `5cc74a4cb216329ee5c4b3c8db6a4ef4403ac1b7193d5ec9d3f8ed93e0010d6d`.

## Decision

The two primary incremental wall ratios failed the fixed 1.25x gate. They are
also effectively unchanged from the earlier connected-route screen, which
measured 1.166x and 1.169x. The hypothesis that overlapping pair preparation
with this particular pure search seam would hide enough startup latency is not
supported by the screen.

The contextual `library-map` ratio moved from 1.144x in the earlier screen to
1.170x here, but that workload also contains the independent parallel library
search route and a five-sample comparison is not attribution evidence. It
cannot rescue two failed primary gates.

Lowering the threshold after observing the result would convert a promotion
rule into a description. Running the larger profile after a failed screen
would consume time without changing that decision. Main prewarming is therefore
HOLD and its speculative effects are absent from the committed product. The
measured 1.165x and 1.166x accelerations remain meaningful screening evidence;
the screen does not establish an incremental prewarm benefit or a
release-promotion claim.

The ownership mechanism remains useful infrastructure. A later route may use
it only after identifying a substantially longer independent phase, proving
that speculative import restoration is acceptable on unused paths, and
passing a fresh fixed-threshold benchmark. A command-wide warm pool still
requires a separate non-lossy terminal-outcome design which keeps all stateful
finalization outside the pair scope.

## Reproduction

The screen used the maintained benchmark harness:

```console
./bench-verification/benchmark.py \
  --baseline /absolute/path/to/baseline/leant \
  --candidate /absolute/path/to/experimental-prewarm/leant \
  --backend /absolute/path/to/repl \
  --warmups 1 \
  --samples 5 \
  --results /absolute/path/to/results.tsv \
  --artifacts /absolute/path/to/raw-artifacts
```

The harness prints `promotion: HOLD` without `--enforce`, while route,
transcript, candidate-count, timeout, and artifact-cleanup mismatches remain
fatal. A future promotion attempt must use two warmups, 21 samples, and
`--enforce`; this failed screen did not qualify for that run.
