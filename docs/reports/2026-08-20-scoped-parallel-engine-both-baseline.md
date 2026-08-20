# Scoped parallel `EngineBoth` structural baseline

Date: 2026-08-20

Production checkpoint: `8f4e7ea` (`Overlap independent EngineBoth baseline searches`)

Benchmark checkpoint: `ee41e0d` (`benchmark(synth): measure scoped EngineBoth overlap`)

## Outcome

Leant now has one deliberately narrow multicore synthesis seam. Main can
overlap the independent Djinn and Exference searches for an eligible
provider-free structural `EngineBoth` baseline, then hand their results to the
existing deterministic combined merge and cursor driver. The pure Engine API
and its ordinary `EngineBoth` implementation remain serial.

This checkpoint establishes bounded demand, scoped cancellation, exact serial
fallback, and transcript equivalence. It does **not** establish a performance
win. On the fixed quartic rank-N workload, the two-capability parallel median
was about 10.1% slower than the serial median.

## Exact admission policy

Main considers the parallel path only for the initial provider-free structural
baseline and only when every row below is satisfied.

| Condition | Required value |
| --- | --- |
| Engine | `EngineBoth` (`:set synth-engine both`) |
| Shown bound | default `synthLimitShown = 5` |
| Verification bound | default `synthLimitTried = 12` per engine |
| Observation window | default `synthLimitWindow = 60` |
| Djinn choice-point budget | default `synthLimitBudget = Nothing` (`synth-budget off`) |
| Exference queue bound | default `synthLimitQueue = 1024` |
| Library extension | no library premise selected for this goal |
| Behavioral policy | disabled or rank, hence a one-batch lane with no filter successor |
| RTS | `getNumCapabilities >= 2` |

The library condition is about the goal-specific selected premise list. The
session may still have `synth-library on` when no rated premise applies.
Likewise, provider discovery may remain enabled: the first lane itself is
provider-free, while any later provider lane remains serial.

`:set synth-steps N` changes `rsSynthSteps`, not `SynthLimits`, so a retuned
Exference step budget remains eligible. Retuning shown, verify, window, budget,
or queue makes the whole combined lane serial. The executable has a threaded
runtime, but Leant supplies no default `-N2` and exposes no public
`:set synth-jobs` setting. An explicit `+RTS -N2 -RTS` can admit this path;
`+RTS -N1 -RTS` bypasses pair construction and invokes the exact historical
serial `EngineBoth` call.

## Scoped worker and demand ownership

Main builds the same standalone provider-free Djinn and Exference outcomes it
already knows how to build. It supplies them as two strict-prefix actions to a
private ordered pair runner:

1. nested `withAsync` scopes start both actions before either result is
   observed;
2. the parent waits for Djinn first and Exference second, preserving Djinn's
   established left-first result and error precedence;
3. a normal left failure, worker exception, timeout, or caller cancellation
   leaves the scopes only after unfinished workers have been cancelled and
   joined; and
4. each worker forces only `synthLimitTried`, 12 detailed candidate groups at
   the defaults, rather than the complete lazy search trace.

The pair runs beneath the absolute deadline captured at command entry. Main
does not restart that clock for worker preparation. If the deadline wins, the
pair is cancelled and Main creates an empty `SynthLaneRunTimedOut` receipt:
zero candidate groups, no checked-frontier spellings, no notes, and no demand
on the unavailable branch outcomes.

After both workers join, Main applies the existing
`mergeDetailedOutcomesSkipping Set.empty`. This retains the default combined
schedule (`D1–D4, E1–E12, D5–D12`, followed by alternating tails), exact-text
deduplication, note ownership, and negative-verdict semantics. Cross-lane
duplicates can require the merged 24-group batch to look beyond a worker's
already forced 12-group prefix. That additional tail is intentionally demanded
serially after the join by the unchanged cursor driver, under the remaining
part of the same absolute command deadline.

## Deliberately serial work

This checkpoint does not parallelize any of the following:

- the pure `runTunedSynthesis` / `EngineBoth` API;
- Lean backend verification or behavioral post-verification assessment;
- provider-enriched lanes or Djinn's staged provider widening;
- selected library-premise synthesis and its merge with the structural lane;
- behavioral filter lanes, including their conditional successor batch;
- excluded-middle or double-negation classical routes; or
- combined lanes whose shown, verify, window, budget, or queue limit was
  retuned.

These exclusions avoid overlapping dependent stages, multiplexing Leant's
single Lean backend pipe, changing the filter scheduler, or silently assigning
new demand to a formerly lazy search. They are future measurement and design
questions, not accidental omissions from this checkpoint.

## Characterization and end-to-end equivalence

The strict test suite passed all **487 of 487** tests. Its new coverage pins:

- simultaneous admission of both workers without timing assertions;
- left-first values and errors even when Exference completes first;
- exception propagation and normal-left-failure precedence;
- caller cancellation only completing after both workers clean up;
- a 12-group force boundary per engine and deferred merged-tail ownership;
- the exact static and RTS capability gates;
- the empty timeout receipt; and
- the unchanged serial provider, library, filter, classical, retuned-limit,
  pure-Engine, and `-N1` routes.

All **26 of 26** pinned Lean golden transcripts passed byte-exact under `-N2`
without regeneration. The quartic end-to-end transcript was also replayed
through production Leant under both `-N1` and `-N2`; after the golden runner's
normal volatile-line and queue-count normalization, both outputs had the same
SHA-256 digest:

```text
40c3ed3e2777c5f3af635a2938897dd0ab7252543b5473ad39b0ac3a3a8b4441
```

The checkpoint also passed warning-as-error builds of all targets and the test
component, plus `cabal check`:

```bash
cabal build all -j1 --ghc-options=-Werror
cabal test test:leant-synth-tests -j1 \
  --test-show-details=direct --ghc-options=-Werror
cabal check
```

## Fixed benchmark

The benchmark embeds the balanced eight-site quartic rank-N fragment used by
the quartic synthesis characterization. It runs only in-process search: no
provider discovery, Lean backend, candidate verification, or behavioral
solver. Serial mode evaluates the ordinary pure `EngineBoth` outcome;
parallel mode evaluates the two 12-group standalone prefixes through the new
ordered pair helper and then applies the default merge. Both modes force the
combined semantic transcript, whose 24-group cap contains **15 actual groups**
for this workload.

Each timing sample launches a fresh worker process and includes process
startup, search, and transcript production. The coordinator alternates which
mode runs first and checks the complete semantic transcript byte-for-byte at
preflight and after every sample. Its FNV-1a-64/UTF-8 transcript digest was:

```text
b16747a04c6485e2
```

Optimization is selected explicitly by the benchmark profile command rather
than embedded as a component-local GHC flag:

```bash
cabal build bench:leant-parallel-bench \
  --enable-optimization=2 --ghc-options=-Werror

# Repeat the profile flag when resolving the executable so Cabal selects
# the same O2 build tree rather than a default-profile binary.
parallel_bench=$(cabal list-bin bench:leant-parallel-bench \
  --enable-optimization=2)
LEANT_PARALLEL_BENCH_SAMPLES=5 \
LEANT_PARALLEL_BENCH_CAPABILITIES=2 \
  "$parallel_bench"

LEANT_PARALLEL_BENCH_SAMPLES=5 \
LEANT_PARALLEL_BENCH_CAPABILITIES=1 \
  "$parallel_bench"
```

The frozen five-sample `-N2` result was:

| Mode | Median wall time | p95 wall time |
| --- | ---: | ---: |
| Serial | 1.983714 s | 2.014523 s |
| Parallel | 2.183937 s | 2.266059 s |

The reported median ratio is `serial / parallel = 0.908x`; equivalently, the
parallel median is about **10.1% slower**. The one-capability control reported
`0.955x`. That control deliberately invokes the benchmark's parallel helper on
one capability to expose scheduling overhead; production Leant does not take
that route at `-N1`, because its capability gate selects the exact serial
implementation instead.

The quartic workload therefore gives no basis for a speedup claim or a default
`-N2`. The useful result is architectural: there is now a deterministic,
cancellation-safe seam on which later work can measure larger independent
frontiers, finer-grained engine work, or isolated verification workers without
first changing public REPL syntax or serial semantics.

## Documentation validation

The root README, synthesis internals, synthesis proposal, reports index, and
this report pass Pandoc parsing with warnings treated as errors. Their local
Markdown links and explicit/generated heading anchors resolve, and the final
diff passes whitespace checks. No PDF or LaTeX artifact is part of this
checkpoint.
