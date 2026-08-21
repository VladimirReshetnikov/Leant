# Backend process-tree lifecycle prerequisite

Date: 2026-08-20

Landing checkpoint:
`39901f314c9cca7bb177b6194c8ef047293c2a35` (`39901f3`)

## Outcome and boundary

Leant now owns and boundedly tears down the complete process tree behind each
`lake env repl` backend. The checkpoint closes a lifecycle prerequisite for a
future pool of isolated Lean-verification workers: direct-wrapper exit or a
cancelled cleanup waiter cannot silently abandon descendants, and a failure
terminating the tree cannot skip the remaining local resource cleanup.

This does **not** make verification parallel. Main and the established
Verification route still send candidate groups and their variants serially to
one backend. The package-private ordered success-quota scheduler remains
unconnected. Isolated pool construction, environment cloning, Main wiring,
worker-level cancellation policy, benchmarking, and any performance claim are
future work.

## Owned launch boundary

The backend's `CreateProcess` request sets `create_group = True` and
`use_process_jobs = True`. Immediately after creation, it captures the direct
wrapper PID with `getPid`; startup refuses to publish a `Backend` without an
owned identifier. Keeping that spawn-time value lets cleanup continue to
address descendants after the wrapper has exited. Backend-bearing Cabal
components require `process >= 1.6.3`, where `getPid` is available.

Startup exceptions use the same tree terminator as ordinary teardown. Whether
all three pipes were created or only a partial set exists, a close is
subsequently attempted for every present handle even if tree termination fails.

### POSIX: dedicated group, escalation, and completion

`create_group` makes the direct child the leader of a new process group. Leant
uses only the captured leader PID as that group's identifier; it never sends a
signal to the caller's process group or to a global group. The
`use_process_jobs` field has no effect on this POSIX path.

Teardown has the following bounded sequence:

1. Send `SIGTERM` to the owned group. If it is already gone, boundedly reap the
   direct wrapper and finish.
2. Otherwise, probe that group with the null signal during a bounded grace
   period. If it disappears, boundedly reap the wrapper and finish.
3. If it remains, send `SIGKILL` to the owned group.
4. Boundedly reap the direct wrapper, with one direct-termination fallback and
   a second bounded reap if needed.
5. When `SIGKILL` found the group present, boundedly probe until the complete
   owned group disappears; report explicit noncompletion if it remains.

Only `ESRCH` classifies a group as gone. `EPERM`, `EINVAL`, other signal or
probe failures, and direct-process observation failures propagate. A failed
group `SIGTERM` is therefore never converted into wrapper-only success, and a
successful `SIGKILL` is not treated as completion until the group is observed
gone. The direct wrapper remains unreaped until the group signaling decision
is complete, so its numeric PID cannot be reused while Leant still uses it as
the group address.

### Windows: Job termination and bounded completion

With `use_process_jobs`, the `process` package owns the launch through a
Windows Job. `terminateProcess` invokes Job termination, covering descendants
rather than merely the direct wrapper, and the matching `waitForProcess`
observes Job completion. Teardown bounds that wait. If it expires, Leant
retries termination and waits once more; a second expiry raises the explicit
`backend process Job did not complete after termination` failure. Termination
via `terminateProcess` ignores only the benign does-not-exist/already-exited
classification; every other termination error and every wait error propagates.

The Windows CPP branch passed forced warning-as-error source compilation. This
checkpoint did not runtime-test the behavior on a Windows host, so it records
source and API coverage rather than a Windows runtime claim.

## Shared, retryable, unconditional cleanup

`killBackend` masks state transitions and starts one independent cleanup
worker. Concurrent callers share the active completion cell. Cancelling a
waiting caller cannot cancel that worker; later callers can still join it.
Success remains available for repeated idempotent calls. Current waiters
receive the same failure, while the gate returns to its initial state so a
later call starts a fresh attempt instead of memoizing failure forever.

All three lifecycle exits use an ordered cleanup combinator that attempts the
remaining actions after an earlier exception and then rethrows the first
failure:

- complete-pipe startup failure terminates the tree and closes stdin, stdout,
  and stderr;
- partial-pipe startup failure terminates the tree and closes every handle
  that exists; and
- ordinary backend cleanup terminates the tree, closes stdin, boundedly drains
  the stderr capture or kills its pump and gives completion another bounded
  wait, and closes stdout and stderr.

Tree termination is first, so its exception remains primary, but it cannot
skip local resource cleanup. The ordering also preserves the existing bounded
stderr capture and request behavior.

## Deterministic descendant evidence

The self-executable lifecycle fixture acts as both fake Lake wrapper and
grandchild. The wrapper starts a separately active child using a heartbeat
path that contains spaces, writes a wrapper-exited marker, and exits
immediately. The test observes that marker and a nonempty heartbeat before it
calls `killBackend`, proving that the direct wrapper is already gone while an
inherited descendant is still working.

On POSIX, a shell installs an ignored `SIGTERM` disposition and then `exec`s
the grandchild, so the disposition survives and deterministically forces the
`SIGKILL` escalation path. The grandchild self-expires after a finite period
as a final leak guard. The test cancels its first cleanup waiter, launches four
concurrent repeated calls, bounds their completion, and then polls until the
heartbeat remains stable. The old wrapper-only teardown would leave that
observed child writing and fail the stabilization check. The pre-existing
oversized-stderr test remains intact.

The focused lifecycle group passed **3 of 3** tests. Source characterization
in that group also pins `create_group`, `use_process_jobs`, spawn-time PID
capture, POSIX `SIGTERM`/`SIGKILL` and post-kill disappearance, error
classification, Windows bounded Job noncompletion, unconditional local
cleanup, primary-failure preservation, and retry after failed cleanup.

## Validation at the landing checkpoint

The following gates passed at
`39901f314c9cca7bb177b6194c8ef047293c2a35`:

- the complete warning-as-error unit suite: **508 of 508**;
- the focused lifecycle group: **3 of 3**;
- strict all-target builds with tests and benchmarks enabled;
- warning-as-error source compilation of the native POSIX branch and the
  forced Windows CPP branch;
- Cabal package validation; and
- final diff and whitespace checks.

Windows coverage in this list is compilation and source characterization,
not runtime execution. No benchmark was added or run for this checkpoint, and
the lifecycle result supports no speed-up claim.

## Documentation validation

The root README, synthesis internals, synthesis proposal, reports index, and
this report pass Pandoc parsing with warnings treated as errors. Their local
links and generated heading anchors resolve, and tracked and untracked files
pass trailing-whitespace and final-newline checks. No LaTeX or PDF artifact is
part of this checkpoint.
