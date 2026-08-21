# Private ordered verification scheduler foundation

Date: 2026-08-20

Implementation checkpoint: `31c7d43` (`Add an ordered verification worker scheduler`)

Current repository checkpoint: `470d15b` (`Advance Djex to the audited parallel-search checkpoints`)

Successor: the scheduler was connected to conservatively gated, isolated N2
verification at `ea75133`; see the
[ordered isolated parallel verification report](2026-08-21-ordered-isolated-parallel-verification.md).
The boundary below describes this foundation at its original landing
checkpoint.

## Outcome

Leant now has a private coordination primitive for a future pool of isolated
Lean candidate-verification workers. `runOrderedSuccessQuota` accepts an
ordered input list, a task returning `Either rejection success`, a worker
limit, and a success quota. It preserves the serial success cutoff and
observable input order while allowing the inputs that are known to precede
that cutoff to run in bounded waves.

This is deliberately not a production verification route. The module
`Leant.Synth.Verification.Parallel` is listed only under Cabal
`Other-Modules`, and only the unit tests import it. The implementation
checkpoint did not change Main, Backend, or `Leant.Synth.Verification`.
Candidate groups and their rendering variants therefore still verify
serially over Leant's one backend process. There is no new command, runtime
default, benchmark result, or speed-up claim.

The later `470d15b` repository checkpoint changes only the Djex submodule
gitlink. It does not change the scheduler, its tests, Cabal ownership, or the
production verification boundary described here.

## Ordered success-quota contract

The result classification has one simple meaning:

- `Left rejection` records a rejected input and does not consume the quota;
- `Right success` records one success and reduces the remaining quota by one.

A positive parallel run proceeds in waves. At the start of each wave it admits
exactly the available prefix up to
`min workerLimit remainingSuccessQuota`. Since one input can contribute at
most one success, even an all-success wave cannot reach the quota before its
last admitted input. Consequently the scheduler never launches an input to
the right of the corresponding serial success-quota cutoff. Rejections reduce
the quota by zero, so a later wave is admitted only when the serial traversal
would also have to continue.

Admission is intentionally lazy. The private splitter examines no input after
the final admitted cons cell, and quota exhaustion does not inspect the
remaining tail. A nonpositive success quota returns `[]` without inspecting
the worker limit, task, or inputs. With a positive quota, a nonpositive worker
limit reports the exact validation error before touching the task or inputs.
A worker limit of one bypasses `async` entirely and performs the same strict
quota traversal on the caller thread.

## Strict publication, ordering, and cleanup

Every task result is forced to normal form in the executing worker before the
worker can publish it. This applies to both the rejection and success payloads
and to the one-worker caller-thread route. A latent payload exception is
therefore attributed to the task boundary rather than escaping later while a
coordinator or presentation path consumes the returned list.

Within a parallel wave, nested `withAsync` scopes start all admitted workers
before observation and `wait` them in input order. A later worker may finish
or throw first, but its value or exception cannot overtake an earlier input.
If an earlier wait throws, scope unwinding cancels and joins the later active
workers before propagating that exception. The same scopes join every active
worker when the caller is cancelled.

This contract intentionally speaks about the success-quota cutoff. Workers
within an already admitted wave may execute before an earlier worker's
exception is observed; ordered waiting determines which exception is exposed,
and scoped cleanup determines their lifetime.

## Audit repairs incorporated before landing

The implementation-and-review loop tightened the boundary before the code
checkpoint was committed:

- the total zero-quota guard precedes worker-limit validation and leaves the
  task and input spine untouched;
- positive-quota worker validation likewise does not demand poisoned task or
  input arguments;
- the wave splitter preserves the unadmitted tail instead of accidentally
  forcing it while finding the bounded prefix;
- both `Either` payloads are deeply forced before publication, including on
  the literal one-worker path;
- one worker stays on the caller thread rather than constructing an async
  scope; and
- nested scopes plus ordered waits pin exception precedence and cancel-and-join
  behavior under worker failure and caller cancellation.

These are semantic and resource-lifetime properties, not timing assumptions.

## Characterization and independent audit

All **17 of 17** focused ordered-scheduler tests passed. The same focused set
then passed **50 consecutive repetitions**, covering simultaneous admission,
right-first completion, quota and rejection accounting, exact N1 parity,
per-group variant short-circuiting, exception order, worker bounds, strict
publication, cancellation cleanup, guard precedence, and poisoned-tail
laziness.

The complete warning-as-error unit suite passed all **506 of 506** tests.
Strict all-target builds, Cabal package validation, and source-distribution
construction also passed. An independent read-only audit reviewed the final
implementation, Cabal visibility, characterization, and build evidence and
returned **GO** with no required repair. These gates apply to implementation
checkpoint `31c7d43`; the later dependency-only gitlink commit does not alter
them.

## Next stage

The scheduler alone cannot make Lean verification concurrent because a
backend owns one request/response pipe and one process-local environment. The
next implementation stage is an isolated Lean worker pool: clone the command's
current environment into separate backend processes, assign one candidate
group to one worker, keep variants within that group serial, and commit group
results through this ordered quota boundary. Pool startup, failure fallback,
timeout and cancellation ownership, environment equivalence, cold and warm
costs, memory, and end-to-end transcripts all require their own tests and
measurements before production routing or any performance claim.

## Documentation validation

The synthesis internals, synthesis proposal, reports index, and this report
pass Pandoc parsing with warnings treated as errors. Their local Markdown
links and explicit/generated heading anchors resolve, and the final diff
passes whitespace checks. The root README remains unchanged because its
user-facing statement that Lean verification is serial is still exact. No PDF
or LaTeX artifact is part of this checkpoint.
