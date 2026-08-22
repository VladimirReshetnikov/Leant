# Compiled synthesis-tooling cache benchmark

This benchmark measures the end-to-end effect of Leant's persistent compiled
synthesis-tooling cache. It compares the exact pre-cache baseline and the
candidate worktree at both one and two RTS capabilities. Both binaries already
contain the same ordered, process-isolated parallel Lean verifier. Every run is
a fresh Leant process; Lean startup, synthesis, verification, and presentation
are all included.

This is a release gate, not a microbenchmark. The script refuses to time a
route until an untimed `strace` preflight proves the expected backend topology
and byte-identical semantic output in all four cells.

## Requirements

- Linux with `/proc`
- Python 3.10 or newer
- `strace`
- an executable Lean REPL backend compatible with this Leant checkout
- optimized baseline and candidate Leant executables

Build both Leant executables with the same compiler and explicit Cabal
optimization profile. Repeat the profile on `list-bin`, because optimized and
default-profile executables occupy different Cabal paths:

```console
cabal build exe:leant --enable-optimization=2 -j1 --ghc-options=-Werror
cabal list-bin exe:leant --enable-optimization=2
```

For the compiled-tooling checkpoint, the baseline is the clean tree at commit
`575d67b667bd1fe03112c3027e7dc18a786282b8`. Build it in a detached worktree
with its recorded Djex submodule, then build the candidate from the dirty or
committed candidate tree with the same command.

## Cells and workloads

Four warm-cache cells isolate capability effects from implementation effects.
Two cold-cache controls bound the first-use cost:

| Cell | Executable | RTS capabilities | Expected Lean processes |
| --- | --- | ---: | ---: |
| B1 | pre-cache baseline | 1 | 1 |
| B2 | pre-cache baseline | 2 | 3: primary plus two isolated workers |
| C1 | candidate | 1 | 1 |
| C2 | candidate | 2 | 3: primary plus two isolated workers |
| D1 | serial baseline, fresh cache directory | 1 | 1 |
| D2 | candidate, fresh cache directory | 1 | 1 |

The two primary fixtures are history-free, default-Djinn, five-result goals.
Their baseline and candidate verification routes are identical, so B2/C2
isolates the compiled-tooling cache at fixed N2 verification semantics:

- `state-thread.txt`: a state-threading product result;
- `continuation.txt`: a nested continuation result.

`library-map.txt` is a contextual end-to-end control. Its N2 run also uses the
already-published parallel base/library search route, so it is included in the
geometric mean but not used as an isolated verification promotion workload.

## Protocol

An untimed preflight runs every workload in B1, B2, C1, and C2 with synthesis
debug metrics and `strace -f -e execve,openat`. All preflight and timed B/C
cells share one private compiled-tooling cache. With the default pre-cache
baseline, C1 cold-populates that cache; with
`--baseline-cold-cache-modules 1`, B1 does so instead. C2 must open the
resulting module. The preflight requires:

- exactly `it1` through `it5`;
- one `lean-variant-attempted=5` metric and one
  `lean-candidate-verified=5` metric;
- exactly 1/3/1/3 backend executions in B1/B2/C1/C2;
- exactly one compiled-tooling module after the first cache-enabled cell, with
  B2 opening it according to `--baseline-cold-cache-modules` and C2 opening it
  exactly once;
- the baseline B2 artifact route and the candidate C2 initializer selected by
  `--candidate-n2-initializer` (the default is the production `artifact`
  route; `pristine-replay` is available for controlled experiments);
- byte-identical normalized debug and semantic transcripts;
- no `leant-parallel-verification*` artifact beneath the private temporary
  directory.

Timed runs disable debug and `strace`, use a fresh private `TMPDIR`, force
`LEANT_SYNTH_TIMEOUT=600`, clear `GHCRTS`, and stabilize the locale and time
zone. B1/B2/C1/C2 use the shared preflight-populated cache. Every D1/D2 run
receives its own new cache directory: D1 must leave the configured baseline
module count (empty by default), while D2 must publish exactly one
compiled-tooling module. This distinguishes repeat-process warm-cache benefit
from first-use behavior instead of silently averaging the two.

When the selected baseline already contains the compiled-tooling cache, pass
`--baseline-cold-cache-modules 1`; the default `0` preserves the original
pre-cache release protocol. This setting selects both the baseline B2
cache-open oracle and the D1 cache-module oracle; it does not change any timed
route.

Two warmup cycles followed by 21 measured samples per cell is the release
profile: 378 rows across three workloads and six cells. Warm-cell order follows
a fixed four-row Latin square, cold-cell order alternates, and workload order
alternates between samples. Each timed run rechecks the preflight transcript
hash and candidate count.

Example:

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

Use `--warmups 0 --samples 1` only to smoke-test the harness and
`--warmups 1 --samples 5` for screening. Neither is release evidence.

## Metrics and promotion rule

The report includes median and nearest-rank p95 wall time, sampled total
process-tree CPU, sampled peak aggregate RSS, and the root Haskell process's
GHC allocation total. `/proc` is sampled every 20 ms by default. Aggregate RSS
sums resident pages across processes and therefore double-counts shared pages;
short-lived CPU or RSS peaks between samples can be missed. These limitations
make the resource figures conservative comparison signals, not accounting
measurements.

The default enforced gate requires:

- B2/C2 median wall speedup of at least 1.25x on each primary fixture;
- C2 p95 no worse than B2 on each primary fixture;
- C1/B1 median wall ratio no greater than 1.05 on each primary fixture;
- D2/D1 cold median wall ratio no greater than 1.05 on each primary fixture;
- D2/D1 cold p95 wall ratio no greater than 1.10 on each primary fixture;
- C2/B2 median GHC allocation ratio no greater than 1.10;
- C2/B2 median process-tree CPU and aggregate-RSS ratios no greater than 1.25;
- a positive B2/C2 geometric-mean speedup across all three workloads.

Any route, transcript, candidate-count, metric, timeout, or artifact-cleanup
mismatch is an unconditional failure. Without `--enforce`, a completed run
still prints `promotion: HOLD` but returns success so screening data can be
collected. A screening run may retain and describe an exact observed
acceleration when it is clearly labelled as screening evidence. Do not use a
screening run or a result that prints `HOLD` as release-promotion evidence.

## Preserved release evidence

The compiled-tooling release table for implementation commit `c95afa9` is
preserved as
[`results/2026-08-21-compiled-tooling-cache-release.tsv`](results/2026-08-21-compiled-tooling-cache-release.tsv).
It contains all 378 timed rows: 21 unreplaced samples for each of three
workloads and six cells. Its SHA-256 is
`e2c4ca4484b4f0897cf74b7312dc09ca174f9140045d496f73defb6c13af7d34`.
The run used two warmup cycles, the documented fixed Latin-square and
alternating cold-cell orders, and `--enforce`; it returned `promotion: GO`.

B2/C2 warm median speedups were 1.921x and 1.965x on the two primary
workloads and 1.934x on the `List.map` control, for a 1.940x geometric mean.
Primary D2/D1 cold medians were 1.005x and 1.024x; cold p95 ratios were 1.028x
and 1.009x. The dated
[compiled-tooling cache report](../docs/reports/2026-08-21-compiled-synthesis-tooling-cache.md)
records executable hashes, preflight topology and transcript hashes, exact
wall/resource tables, cache-artifact evidence, and the implementation
boundary.

The preceding five-sample screen's exact acceleration remains useful screening
evidence even though one noisy cold p95 control printed `HOLD`; no row was
replaced. The 21-sample profile is the independent release-promotion evidence.

### Previous verifier-route release evidence

The pre-cache verification-route table for implementation commit `8afedc3`
remains preserved as
[`results/2026-08-21-critical-path-overlap-release.tsv`](results/2026-08-21-critical-path-overlap-release.tsv).
It contains 252 timed rows and has SHA-256
`80d3b1e5f87b2138c0ea9a3d6449533f6b63b4a6686a535e529d58bdf8c19fa9`.
Its separate
[critical-path overlap report](../docs/reports/2026-08-21-verification-critical-path-overlap.md)
documents that checkpoint's four-cell protocol and 1.324x geometric-mean
result.
