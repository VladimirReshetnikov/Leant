# Parallel structural/library baseline

Date: 2026-08-20

Production checkpoint: `86d79ef` (`Overlap structural and library baseline searches`)

Benchmark checkpoint: `793a7a4` (`benchmark(synth): measure outer library overlap`)

## Outcome

Leant now has a second bounded multicore schedule for the initial
provider-free structural baseline. When the goal selects rated library
premises, Main can overlap the ordinary structural search with the tuned
library-premise search for Djinn, Exference, or `EngineBoth`. The prior
no-library `EngineBoth` Djinn/Exference pair remains available and unchanged.

The library pair shows a useful but deliberately narrow result. On the fixed
eight-premise `List.map` search-only workload, the designated five-sample
`-N2` run measured 1.523x for Exference and 1.572x for `EngineBoth`; an
independent run reproduced 1.538x and 1.566x. This supports a cautious claim of
roughly 1.5x for substantive work at this search seam. It is not evidence for
end-to-end REPL latency, Lean verification, every goal, enabling `-N2` by
default, or a general parallel-search speedup. The tiny Djinn case is dominated
by process and scheduling overhead and supports no performance claim.

## Exact schedule selection

Main computes one `initialBaselineSchedule` entirely from pure command state
before the only `getNumCapabilities` call:

| Selected premises | Engine | Selected work pair |
| --- | --- | --- |
| none | `EngineBoth` | provider-free Djinn / provider-free Exference |
| nonempty | Djinn, Exference, or `EngineBoth` | provider-free structural base / tuned library search |
| any other case | any | established serial callback |

Either parallel schedule also requires all of the following:

- a structurally accepted goal and the initial provider-free baseline;
- `SynthLimits == defaultSynthLimits`: 5 shown, 12 verified per standalone
  engine, a 60-group observation window, no Djinn choice-point budget, and an
  Exference queue bound of 1024;
- disabled or rank behavioral assessment, hence one outer batch and no filter
  successor; and
- at least two RTS capabilities.

The premise list is the goal-specific rated selection. Merely having
`:set synth-library on` does not select the library pair when no premise
applies. `:set synth-steps N` changes `rsSynthSteps`, not a `SynthLimits`
field, so a retuned Exference step budget remains eligible.

The pure selection produces either one concrete parallel closure or the
serial route; capabilities cannot change which pair was chosen. At one
capability, including explicit `+RTS -N1 -RTS`, Main does not construct a pair
and calls the literal established
`runSynthesis True Set.empty engine []` callback. This retains the historical
base-then-library evaluation path. The executable is threaded, but it has no
default `-N2` and no public synthesis-jobs setting.

## Nonnested ownership and bounded demand

The selected-library route is exactly one outer pair. Its left action performs
the ordinary provider-free structural search with the selected engine. Its
right action performs the existing tuned search with the selected premises,
constructor-stripped search goal, 60-group collection window, and 100,000
choice-point ceiling. `EngineBoth` remains serial inside each action: the
outer scheduler never nests a Djinn/Exference pair and admits at most two
active search actions.

The two strict boundaries are asymmetric by design:

- **Base, zero groups.** `forceDetailedOutcome 0` forces the `Either` and
  detailed-outcome constructors, any refutation verdict, and the run-note list
  and string spines. It does not enter the candidate-group spine.
- **Library, one verification window.** The right action requests and forces
  the available prefix of up to 12 candidate groups for Djinn or Exference, or
  24 for `EngineBoth`. It does not demand the unselected tail.

`runParallelEitherPairOrdered` starts both actions in nested `withAsync`
scopes, observes the base/left action first, and joins both before returning.
Normal left failure, a worker exception, command timeout, caller cancellation,
and scope exit all cancel and join unfinished work. A deadline win creates an
empty `SynthLaneRunTimedOut` receipt without probing either cancelled outcome,
its notes, checked spelling frontier, or group count.

After the join, Main calls the unchanged `mergeLibraryDetailedOutcomes` with
the base on the left. Thus base errors retain left-first ownership, library
candidates still lead base candidates, duplicate base variants are removed,
run notes retain their established ownership, and only the complete base
search can contribute a negative verdict. The ordinary cursor drives any
later base fill and deduplication serially under the remaining portion of the
same absolute command deadline.

Provider-enriched lanes and widening, filter successors, excluded-middle and
double-negation routes, Lean verification, post-verification behavioral
assessment, and lanes with retuned shown/verify/window/budget/queue limits
remain serial. This checkpoint does not change public syntax, pure Engine API
semantics, displayed order, or verification policy.

## Characterization and end-to-end equivalence

The strict unit suite passed all **489 of 489** tests. The added deterministic
coverage pins pure-before-IO schedule selection, admission for all three
library engines, literal `-N1` fallback, nonnesting, base-left observation,
asymmetric zero/full-window force boundaries, poisoned unselected tails,
deadline ownership, empty timeout receipts, unchanged merge ordering, and the
serial exclusions above.

The complete `test/synth-library.txt` end-to-end transcript matched under
`-N1`, `-N2`, and the checked-in golden after normalizing the runner's volatile
fields. Its shared SHA-256 digest was:

```text
812a45c86d6b7f1fc7db4dad208e7531dc381ea9a8748e737d124359b4d8307b
```

A targeted end-to-end transcript covering Djinn, Exference, and `EngineBoth`
with live library premises was also identical under `-N1` and `-N2`. Its
shared SHA-256 digest was:

```text
a909e8627c876854289fbbd134567e72c3897dc73d4c9611c6edcc58a301388a
```

All **26 of 26** pinned Lean golden transcripts passed exactly at `-N2`
without regeneration. Warning-as-error all-target builds passed with tests and
benchmarks enabled, including the explicit O2 profile; Cabal package checks,
the live-fixture comparison, and whitespace checks also passed. These checks
exercise the real Lean backend, whereas the microbenchmark below intentionally
isolates Haskell search.

## Fixed live-library fixture

The benchmark copies the first checked workload in `test/synth-library.txt`.
Its goal is the ordinary `List.map` shape
`(a -> b) -> List a -> List b`. Main's selected-premise order is represented
exactly by eight instantiated entries:

1. `List.map` at `a -> b`;
2. `List.map` at `a -> a`;
3. `List.map` at `b -> a`;
4. `List.map` at `b -> b`;
5. `List.append` for `List a`;
6. `List.append` for `List b`;
7. `List.reverse` for `List a`; and
8. `List.reverse` for `List b`.

The ordinary action receives the recursive constructor schemas. The tuned
library action receives the same constructor-stripped goal and premises as
Main. Both use the default limits and 4,096 Exference steps, with no provider
discovery, Lean backend, candidate verification, behavioral solver, or nested
engine parallelism.

Serial mode forces base zero first and then the library window. Parallel mode
forces those same boundaries through the scoped outer pair. Every timing is a
fresh worker-process wall measurement and therefore includes process startup,
search, and semantic-transcript construction. The coordinator alternates
serial-first and parallel-first order, proves byte-for-byte equality at
preflight, and checks every sample against that frozen transcript.

The bounded transcripts and actual candidate-group counts were:

| Engine | Library demand cap | Actual groups | FNV-1a-64/UTF-8 |
| --- | ---: | ---: | --- |
| Djinn | 12 | 6 | `694065acdd6d8644` |
| Exference | 12 | 12 | `fda21dcc3f474651` |
| `EngineBoth` | 24 | 24 | `687842765cae6d2e` |

The earlier no-argument quartic benchmark remains unchanged; its transcript
digest is still `b16747a04c6485e2`.

## Reproducible O2 command

Optimization belongs to the explicit benchmark profile rather than a
component-local `ghc-options` entry. The same `--enable-optimization=2` flag
must be supplied to both `build` and `list-bin`, so Cabal resolves the O2
executable rather than a default-profile build:

```bash
cabal build bench:leant-parallel-bench \
  --enable-optimization=2 --ghc-options=-Werror

parallel_bench=$(cabal list-bin bench:leant-parallel-bench \
  --enable-optimization=2)

LEANT_PARALLEL_BENCH_SAMPLES=5 \
LEANT_PARALLEL_BENCH_CAPABILITIES=2 \
  "$parallel_bench" library

LEANT_PARALLEL_BENCH_SAMPLES=5 \
LEANT_PARALLEL_BENCH_CAPABILITIES=1 \
  "$parallel_bench" library
```

## Designated measurements

The frozen five-sample `-N2` measurements were:

| Engine | Serial median / p95 | Parallel median / p95 | Serial / parallel |
| --- | ---: | ---: | ---: |
| Djinn | 0.014050 / 0.014178 s | 0.015890 / 0.016394 s | 0.884x |
| Exference | 7.615288 / 8.081833 s | 4.998904 / 5.017771 s | 1.523x |
| `EngineBoth` | 8.021115 / 8.200870 s | 5.101162 / 5.641434 s | 1.572x |

The one-capability scheduling controls were:

| Engine | Serial median / p95 | Parallel median / p95 | Serial / parallel |
| --- | ---: | ---: | ---: |
| Djinn | 0.014165 / 0.014177 s | 0.014851 / 0.015644 s | 0.954x |
| Exference | 9.018895 / 9.190316 s | 9.080658 / 10.642327 s | 0.993x |
| `EngineBoth` | 8.949703 / 9.134966 s | 9.104184 / 9.523618 s | 0.983x |

Production takes the literal serial callback at `-N1`; the benchmark invokes
the pair on one capability solely as a scheduling-overhead control. Its near
parity shows that the N2 Exference and combined gains come from overlapping
the two substantive searches rather than different semantic demand. Djinn's
14–16 ms process-level measurement is too small for a useful speedup claim.

An independent O2 reproduction measured N2 ratios of 1.538x for Exference and
1.566x for `EngineBoth`; its N1 controls were 1.009x and 1.013x. The close N2
agreement supports the cautious roughly-1.5x search-only result, while the
small variation reinforces why no broader latency promise is made.

## Documentation validation

The root README, synthesis internals, synthesis proposal, reports index, and
this report pass Pandoc parsing with warnings treated as errors. Local Markdown
links and explicit/generated heading anchors resolve, and the final diff
passes whitespace checks. No PDF or LaTeX artifact is part of this checkpoint.
