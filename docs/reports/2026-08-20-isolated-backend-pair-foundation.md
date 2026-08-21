# Private isolated Lean backend pair foundation

Date: 2026-08-20

Landing checkpoint:
`8163d13f49d9aa46724f20cc5b25789cce7aeec3` (`8163d13`)

Successor: Main connected this pair to conservatively gated N2 candidate-group
verification at `ea75133`; see the
[ordered isolated parallel verification report](2026-08-21-ordered-isolated-parallel-verification.md).
The boundary below describes the pair at its original foundation checkpoint.

## Outcome and boundary

Leant now has a package-private scoped owner for exactly two independent Lean
backend processes restored from one environment artifact. It supplies the
resource boundary needed to connect the earlier ordered success-quota
scheduler without ever issuing concurrent requests through one backend pipe or
mixing process-local environment identifiers.

This is a foundation, not a production route. `Leant.Backend.Isolated` is
listed under Cabal `Other-Modules`; Main and `Leant.Synth.Verification` do not
import it. Candidate groups and all variants still verify serially through the
one established REPL backend. The checkpoint adds no command, jobs setting,
default capability count, real-backend benchmark, or speed-up claim.

## Scoped API and visibility

The internal API has three operations:

```haskell
withIsolatedBackendPair
  :: BackendConfig -> FilePath -> Maybe Int
  -> (IsolatedBackendPair -> IO a)
  -> IO (Either IsolatedBackendFailure a)

withIsolatedBackendLease
  :: IsolatedBackendPair
  -> (IsolatedBackendLease -> IO a)
  -> IO (Either IsolatedBackendFailure a)

runIsolatedBackendCommand
  :: IsolatedBackendLease -> String
  -> IO (Either IsolatedBackendFailure JValue)
```

The pair and lease constructors are hidden, so a caller cannot manufacture a
checkout or extract and share the underlying `Backend`. Failure constructors
remain visible to internal callers. They distinguish ordinal-tagged spawn and
setup failures, transport failures, closed and retired leases, poisoned and
closed pairs, and cleanup failure with an optional primary infrastructure
failure plus worker-labelled cleanup details. Callback and unexpected
exceptions deliberately remain exceptions: each scope finishes its cleanup
and then rethrows the original exception instead of converting it to a routine
infrastructure value.

The executable and unit suite now declare `stm >= 2.5 && < 2.6` directly for
this state machine. The fake-backend suite raises its `process` floor to
1.6.12 for `getCurrentPid`; the executable retains the lifecycle checkpoint's
`process >= 1.6.3` floor.

## Exactly two independently restored workers

Acquisition has a fixed sequential shape:

1. Spawn worker one and send it `unpickleEnvFrom` for the supplied artifact.
2. Validate its response and retain its process-local environment identifier.
3. Spawn worker two, send it the same restoration request, and retain that
   process's environment identifier.
4. Publish the pair only after both workers are fully initialized.

There is no partially useful one-worker pair. Setup requires a valid integer
`env`, rejects a fatal response or any error-severity diagnostic, and reports
timeout, server closure, or malformed JSON as an ordinal-tagged transport
failure. Failure or cancellation during either spawn or restoration cleans
every backend already acquired. Cleanup failure is attached to a routine setup
failure; when an exception is already primary, cleanup is still completed but
does not replace that exception.

The common artifact does not make the processes share protocol state. Each
worker retains its own restored `env`. Every later command payload contains
exactly `cmd` plus that retained identifier. An `env` returned by a command is
ignored, so a complete lease stays on its original restored branch. This is
the intended candidate-group boundary: variants belonging to one group can be
tried sequentially against one stable environment, while another group may
use the independently restored sibling.

Valid command JSON is not confused with a transport failure. Fatal, Lean
error-diagnostic, and `sorry` responses are returned unchanged for the
existing verification classifier and leave the worker healthy.

## Lease and request discipline

An STM queue admits at most two simultaneous lease callbacks. Every checkout
receives a fresh active token, and every worker has an `MVar` request lock.
Consequently even two child threads sharing one legitimate lease serialize
their protocol transactions rather than interleave writes or reads on its
pipe.

Normal release first invalidates the active token, then synchronizes on the
request lock. One request which passed admission may complete before the
worker is reused; a queued detached request reaches admission only afterward
and observes `IsolatedBackendLeaseClosed`. The worker returns to the queue only
when it is idle, not retired, and the pair is still healthy. An escaped lease
therefore cannot operate on a worker which a later callback has checked out.

An idle callback exception invalidates and safely returns a healthy worker
before rethrowing. If its callback left a protocol request in flight, abort
retires the worker instead. Cancellation or another exception during the
normal release handoff is always fail-stop, even in the narrow tail where the
request has just cleared its in-flight flag: the worker is retired and cleaned
under an independent owner, and the handoff never requeues it.

## Stable poison and checked-out sibling semantics

The following request outcomes retire and kill their worker and poison the
complete pair:

- request timeout;
- server closure or EOF;
- malformed protocol response; and
- an exception or cancellation after a request entered the protocol.

There is no replacement spawn. The first pair poison is stable, the idle queue
is cleared, and every later lease acquisition returns that cause. A normal
pair callback cannot hide a request failure merely by ignoring its returned
`Left`: scope exit reports the recorded pair poison.

A lease already checked out on the sibling follows a narrower whole-group
rule. Pair poison does not asynchronously kill it or prevent its next serial
variant from entering the sibling's still-healthy protocol. It may finish the
complete callback and release. If that sibling later suffers its own transport
failure, it too is retired, but the pair continues to publish the first cause.
This keeps work already admitted as one ordered candidate-group task intact
while forbidding any new group admission after trust in the pool is lost.

## Atomic close and cancellation-safe cleanup

Pair close reads the prior status and writes the closed state in one STM
transaction, clearing admission at the same time. It then cleans both workers
from the pair's permanent ownership list rather than merely draining the idle
queue. Checked-out or escaped-child workers therefore cannot outlive their
pair scope.

The atomic transition defines the close race exactly. A poison committed
before close is captured and returned after cleanup. If close commits first,
the pair returns its healthy callback result even when an already admitted,
mis-scoped child observes teardown and reports a later request failure; that
late failure cannot rewrite the already closed pair.

All worker teardown uses the bounded whole-process-tree lifecycle introduced
at `39901f3`. A masked caller starts an independent unmasked cleanup owner and
waits for that bounded owner, so caller cancellation cannot skip worker two or
interrupt a fail-stop retirement halfway through. Both workers are attempted
in ordinal order, and normal infrastructure results surface deterministic
worker-labelled cleanup failures. Callback, request, setup-cancellation, and
release exceptions retain precedence after cleanup.

## Audit repairs before landing

Implementation and independent review closed five ownership races before the
checkpoint landed:

- pair and lease acquisition handoffs remain masked until their cleanup scope
  owns the acquired resource;
- a checkout-local active token rejects a lease used after its callback;
- the per-worker request lock and in-flight state prevent an admitted child
  request from overlapping release and reuse;
- failure or cancellation while normal release waits for that lock takes a
  dedicated retire-and-poison path and can never fall through to healthy
  requeue; and
- pair close captures its prior terminal status atomically with the transition
  to closed, eliminating a race that could otherwise miss an established
  poison.

The resulting distinction between idle callback abort and failed normal
release is intentional: the former may prove the protocol idle and return a
worker, while the latter cannot prove a completed ownership handoff and is
therefore fail-stop.

## Characterization and validation

The self-hosted fake backend gives each process a distinct operating-system
identity and deterministic environment identifier, records restoration and
command entry, and provides gates for controlled interleavings. All **24 of
24** focused cases passed. They cover:

- atomic close source shape and close-versus-late-failure ordering;
- two-process/two-environment restoration and sequential commands retaining
  the correct environment;
- valid fatal, error, and `sorry` command responses without poison;
- escaped-lease rejection, same-lease request serialization, gated release,
  and cancellation during normal release;
- six first-worker setup rejection classes, second-worker setup and spawn
  cleanup, and setup cancellation;
- timeout, EOF, and malformed-response retirement with no third worker;
- stable first poison while an already leased sibling completes; and
- callback exception precedence and cancellation of an in-flight request with
  both process trees reaped.

At landing checkpoint
`8163d13f49d9aa46724f20cc5b25789cce7aeec3`, the complete
warning-as-error unit suite passed **532 of 532** tests. The serialized
`cabal test all -j1 --ghc-options=-Werror` gate passed every suite, and a
warning-as-error all-target build with tests and benchmarks enabled passed.
`cabal check`, source-distribution construction and contents, and final diff
checks also passed. An independent read-only concurrency audit returned
**GO** after the release and close race repairs.

These are ownership and deterministic fake-protocol results. They do not prove
that two restored workers match Main's live command environment, do not
exercise a real Lean project through this route, and do not measure cold
startup, warm throughput, memory, end-to-end latency, or scaling.

## Next production stage

Main must next own an artifact that exactly represents the current command's
Lean environment, restore both isolated workers from it, and connect one
candidate group per lease to `runOrderedSuccessQuota`. Variants within a group
must remain serial on that lease, while result publication, rejection
accounting, exception observation, and the success cutoff remain in original
input order. A one-worker configuration must take the literal established
serial path.

Before the new route can be enabled, real-backend tests must prove environment
and diagnostic parity, exact candidate/transcript order, deadline and
cancellation behavior, poison fallback, and absence of process leaks.
Benchmarks must separate artifact creation, cold pair startup, warm candidate
verification, resident memory, and complete `:synth` latency on `-N1` and
multicore runs. Only those measurements can support a speed-up claim or a
default policy.

## Documentation validation

The root README, synthesis internals, synthesis proposal, reports index, and
this report pass Pandoc parsing with warnings treated as errors. Their local
Markdown links and generated heading anchors resolve, and the final diff
passes whitespace and final-newline checks. No LaTeX or PDF artifact is part
of this checkpoint.
