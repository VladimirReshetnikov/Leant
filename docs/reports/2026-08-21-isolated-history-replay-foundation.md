# Isolated history-replay foundation

Date: 2026-08-21

Implementation commit: `2156261`

Connected history-free route: `8afedc3`

## Result

Leant now has a disconnected package-private initializer for reconstructing
ordinary imported session history on two isolated Lean backend processes.
The ownership and semantic foundation is GO. Production admission is
unchanged: Main still uses the faster artifact route only for history-free
sessions and still excludes any accepted interactive history.

A temporary Main connection repaired the known scoped-notation parity problem
but failed performance screening. It was removed before commit. This report
retains both facts: the reconstruction mechanism is correct and useful, while
unconditional replay is not an acceptable production optimization.

## Motivation

The upstream Lean REPL snapshot format reimports modules and restores ordinary
command state, but does not preserve every environment-extension entry created
inside a live session. The earlier artifact route therefore excluded nonempty
`rsHistory`. Before that gate was added, a session-created scoped notation
could silently produce fewer N2 candidates than N1.

Leant already has an authoritative recovery contract for ordinary history:

1. start from the configured ordered imports;
2. retain the import response environment;
3. check that branch with `example : True := True.intro` in a later
   environment, while deliberately ignoring the probe's returned environment;
4. replay every accepted command in chronological order, threading only the
   process-local environment returned by that worker.

Commit `2156261` makes that contract available to isolated verification
without exposing a backend handle, environment ID, worker, or cleanup owner.

## Private API and lifetime

The new entry point is:

```haskell
withIsolatedBackendPairReplaying
  :: BackendConfig
  -> [String]
  -> [String]
  -> Maybe Int
  -> (IsolatedBackendPair -> IO a)
  -> IO (Either IsolatedBackendFailure a)
```

The first list is the import order and the second is accepted chronological
history. Both worker reconstructions start concurrently. Within one worker,
imports, the usability probe, and history remain serial. An empty import and
history plan materializes a process-local base with `#check True`.

The established isolated-pair owner remains authoritative:

- each backend is published into the masked ordinal registry immediately
  after spawn;
- worker one is observed before worker two, preserving deterministic failure
  precedence;
- setup transport, fatal, error, and missing-environment results use the
  existing typed failure vocabulary;
- a known worker-one failure cancels and joins its sibling;
- callback exceptions and cancellation remain primary after cleanup;
- every owned process tree is killed and reaped before the bracket returns.

Artifact restoration and prepared-pair acquisition still use their original
path. Main has no replay-pair caller at the committed checkpoint.

## Deterministic coverage

The fake backend records every setup command and input environment. Four new
tests prove:

1. both workers see one exact multi-import request, the later-environment
   probe, and two history entries in order; each retained import environment
   and subsequent environment transition is exact;
2. an empty plan materializes two distinct process-local bases;
3. simultaneous gated replay errors retain worker-one precedence, never enter
   the callback, and clean both workers;
4. `ThreadKilled` during two blocked replay requests remains exact after both
   worker trees are joined.

Validation on the committed bytes:

- focused isolated/runtime group: **50/50**;
- complete strict Leant suite: **582/582**;
- strict all-target tests-and-benchmarks build: pass;
- `cabal check` and `git diff --check`: clean;
- sdist inclusion: exact source and test bytes.

The final file SHA-256 values at the implementation checkpoint were:

- `src/Leant/Backend/Isolated.hs`:
  `7a68b5e8e3fc0564068c78598f2786b801e76898f7c7980b39242672b75b8fe9`;
- `test-unit/Spec.hs`:
  `38cf9fbfefe8089ca580dcd18f9ff78b95198cbb5d0feeee925fde2efa94bf4e`.

## Real-Lean semantic diagnostics

The pinned Lean 4.32 backend was
`/tmp/leant-repl-v432.w3gxVr/.lake/build/bin/repl` during the local diagnostic.
The formerly divergent session was:

```lean
namespace ScopedParity
scoped notation "Tokenish" => Nat
end ScopedParity
open scoped ScopedParity
#check Tokenish
:synth (Tokenish → Tokenish → Tokenish)
```

The temporary replay-connected binary produced five identical candidates at
N1 and N2. The complete output hash was
`2ce2331beec5458abd11280e0113536c1da6f617a6d3e5cb0fb51fed95170469`;
the normalized benchmark transcript hash was
`df43ca9b9d69326ffaa23d078d7eed05b781bda136deb712270be9600b1d5628`.
Process tracing proved one backend at N1 and exactly three at N2.

A second diagnostic started with `--import Std`, accepted one declaration,
and synthesized through that declared type. Its normalized N1/N2 hash was
`2f3106b7aeb79672f11d912704f33fd180d6afe854cdb563b9676d450ef23fc1`,
again with one versus three backend processes.

These are diagnostic parity results, not committed production-route gates,
because the Main connection was removed after screening.

## Five-sample screening decision

Both screens used alternating baseline/candidate order, fresh processes, the
same O2 baseline executable (`160ecc6f...`), N2, exact normalized transcript
hashes, and no replacement samples. They were deliberately small decision
screens, not release profiles.

| workload | serial samples (s) | replay-parallel samples (s) | serial median/p95 | replay median/p95 | serial/replay |
|---|---|---|---:|---:|---:|
| scoped notation history | 5.21, 5.63, 6.09, 5.09, 5.06 | 6.23, 5.98, 6.07, 6.17, 5.88 | 5.21 / 6.09 | 6.07 / 6.23 | 0.858x |
| one declaration + state thread | 5.36, 5.05, 5.18, 4.96, 5.05 | 6.55, 5.91, 6.48, 6.05, 5.70 | 5.05 / 5.36 | 6.05 / 6.55 | 0.835x |

Replay therefore increased the median wall time by about **16.5%** on the
scoped session and **19.8%** on the one-declaration control. The cost of
spawning two processes and replaying history outweighed parallel verification
on both workloads. No threshold reinterpretation is involved: these are
measured regressions, not double-digit gains being dismissed as speculative.

## Decision and future boundary

The package-private replay initializer remains because it is the correct
ownership boundary for future history-aware work and directly characterizes
the known snapshot gap. Main replay admission is HOLD.

A future connection needs a workload-aware design with positive incremental
evidence. Plausible directions include a bounded warm reconstruction reused
across several genuinely expensive verification batches, or a protocol which
transfers elaborated/kernel-checkable candidates without replaying arbitrary
surface commands. Any future route must still preserve N1 literally, keep
snapshot/proof/sorry state fail-closed, expose no speculative attempt trace,
and measure history reconstruction separately from candidate checking.
