# Isolated synthesis-verification benchmarks

The default `compiled-cache` protocol measures the end-to-end effect of
Leant's persistent compiled synthesis-tooling cache. It compares the exact
pre-cache baseline and the candidate worktree at both one and two RTS
capabilities. Both binaries already contain the same ordered,
process-isolated parallel Lean verifier. Every run is a fresh Leant process;
Lean startup, synthesis, verification, and presentation are all included.

This is a release gate, not a microbenchmark. The script refuses to time a
route until an untimed `strace` preflight proves the expected backend topology
and byte-identical semantic output in all four cells.

The opt-in `--protocol scaled-pool` is a separate, preregistered retention
screen for the bounded two-to-four-worker verifier. It fixes the benchmark at
one warmup and five measured samples in six N1/N2/N4 cells. It neither changes
the default compiled-cache protocol nor constitutes release-promotion
evidence.

## Requirements

- Linux with `/proc`
- Python 3.10 or newer
- `strace`
- an executable Lean REPL backend compatible with this Leant checkout
- optimized baseline and candidate Leant executables

The scaled-pool protocol additionally requires at least four effective CPUs.
On platforms with `sched_getaffinity`, the script uses the current process's
affinity-set size; otherwise it falls back to the host logical-CPU count. It
prints both host and effective counts and aborts before preflight when the
effective count is below four.

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

## Scaled-pool retention protocol

Use `--protocol scaled-pool` to compare the fixed-two-worker baseline at exact
commit `1097e30cba7140df3fd22705276530b1f39b2d70` with a candidate that
connects the bounded pool to Main. The protocol times only the two primary,
history-free, five-result workloads: `state-thread.txt` and
`continuation.txt`.

Scaled mode requires all four exact provenance options:
`--baseline-leant-commit`, `--candidate-leant-commit`,
`--baseline-djex-commit`, and `--candidate-djex-commit`. Each value must be a
40-character lowercase hexadecimal commit. The script prints them with the
three executable hashes before preflight. These options are globally optional,
so omitting them preserves the default compiled-cache CLI.

The six warm-cache cells are:

| Cell | Executable | RTS capabilities | Expected Lean processes |
| --- | --- | ---: | ---: |
| B1 | fixed-two baseline | 1 | 1 |
| C1 | scaled-pool candidate | 1 | 1 |
| B2 | fixed-two baseline | 2 | 3: primary plus two workers |
| C2 | scaled-pool candidate | 2 | 3: primary plus two workers |
| B4 | fixed-two baseline | 4 | 3: primary plus two workers |
| C4 | scaled-pool candidate | 4 | 5: primary plus four workers |

The protocol explicitly passes `+RTS -N4 -RTS` to B4 and C4. That fixed
experimental cell does not add a default `-N4`, change the executable's
ordinary capability count, or by itself promote N4 as a default route.

### Scaled-pool preflight

Before the long-workload preflight, the repository's
`history-free-multi-group.txt` short batch runs in this exact order against one
shared private tooling cache:

| Short cell | Executable/capabilities | Backends | Artifact | Exact module opens |
| --- | --- | ---: | --- | ---: |
| SB1 | baseline N1 | 1 | absent | 0; cold-publishes the module |
| SB4 | baseline N4 | 3 | present | 1 |
| SC1 | candidate N1 | 1 | absent | 1 |
| SC4 | candidate N4 | 3 | present | 1 |

The N4 short cells prove that a reachable two-group batch acquires only two
workers. All four cells must produce byte-identical normalized debug and
semantic transcripts with exactly `it1`/`it2`, one
`lean-variant-attempted=2`, and one `lean-candidate-verified=2` metric. SB1
creates exactly one compiled module. SB4, SC1, and SC4 must retain that exact
module path and SHA-256 while opening it once each.

Each long workload then runs untimed in all six cells against that same warm
module. The preflight requires:

- exactly `it1` through `it5`, one `lean-variant-attempted=5`, and one
  `lean-candidate-verified=5` in every cell;
- byte-identical normalized debug and semantic transcripts across all six
  cells;
- exact 1/1/3/3/3/5 backend counts in B1/C1/B2/C2/B4/C4;
- one open of the exact shared compiled module per long preflight cell, with
  an unchanged path and SHA-256;
- an artifact route in every N2/N4 multi-worker trace and no artifact route in
  either N1 trace;
- no `leant-parallel-verification*` artifact beneath any command's private
  temporary directory after it exits.

Any mismatch aborts before timing.

### Scaled-pool timing order

The screen is fixed at one warmup and five measured samples per cell and
workload: 60 retained timing rows. `--warmups` and `--samples` must therefore
remain 1 and 5. A failed or noisy row is never rerun or replaced. Workload
order alternates by measured sample. Within a workload the six treatments use
this fixed Williams square, where every directed adjacency occurs exactly
once across its six rows:

| Row | Treatment order |
| ---: | --- |
| 1 | B1, C1, C4, B2, B4, C2 |
| 2 | C1, B2, B1, C2, C4, B4 |
| 3 | B2, C2, C1, B4, B1, C4 |
| 4 | C2, B4, B2, C4, C1, B1 |
| 5 | B4, C4, C2, B1, B2, C1 |
| 6 | C4, B1, B4, C1, C2, B2 |

Each workload uses every Williams row exactly once across its warmup and five
measured samples. State-thread warms up with row 1 and measures rows 2 through
6. Continuation warms up with row 2 and measures rows 3 through 6 followed by
row 1.

Example:

```console
./bench-verification/benchmark.py \
  --protocol scaled-pool \
  --baseline /absolute/path/to/1097e30/leant \
  --candidate /absolute/path/to/candidate/leant \
  --backend /absolute/path/to/repl \
  --baseline-leant-commit 1097e30cba7140df3fd22705276530b1f39b2d70 \
  --candidate-leant-commit 4f11872b9563be16bc9664982f37d4d5ad770583 \
  --baseline-djex-commit 9fa145ed743321cd861440940398413a6ad844b3 \
  --candidate-djex-commit 9fa145ed743321cd861440940398413a6ad844b3 \
  --warmups 1 \
  --samples 5 \
  --results /absolute/path/to/scaled-pool-screen.tsv \
  --artifacts /absolute/path/to/scaled-pool-artifacts \
  --enforce
```

The fixed retention gate requires, on each workload:

- B4/C4 median wall speedup of at least 1.10x;
- C4 p95 wall time no worse than B4;
- C1/B1 and C2/B2 median wall ratios no greater than 1.05, and p95 ratios no
  greater than 1.10;
- C1/B1, C2/B2, and C4/B4 median GHC allocation ratios no greater than 1.10;
- C1/B1, C2/B2, and C4/B4 median process-tree CPU and aggregate-RSS ratios no
  greater than 1.25;
- a B4/C4 geometric-mean speedup of at least 1.10x across both workloads.

The report also prints C2/C4 candidate scaling, the B2/B4 fixed-two control,
all N1/N2 median and p95 ratios, the C4/B4 p95 ratio, and allocation, CPU, and
RSS ratios for C1/B1, C2/B2, and C4/B4. Without `--enforce`, a threshold miss
prints `scaled-pool retention: HOLD` but returns success so the unreplaced
screen can be preserved.

A measured improvement >10%, including ~16.5%, is meaningful retention
evidence. Such a result is worth keeping and must not be described as
speculative merely because it came from this screen. The historical 1.25x
compiled-cache release-promotion tier is a distinct, stronger evidence level;
it does not erase a reproducible double-digit result or turn fixed N4 into a
default runtime setting.

The compiled-cache-only controls (`--minimum-speedup`,
`--maximum-n1-regression`, the allocation/CPU/RSS and cold-cache threshold
options, `--baseline-cold-cache-modules`, and `--candidate-n2-initializer`) do
not alter the fixed scaled-pool screen.

### Completed scaled-pool screen

The 2026-08-21 fixed screen compared exact baseline `1097e30` with connected
candidate `4f11872` on a host and affinity set of six CPUs. All 60 measured
rows completed without replacement. State-thread and continuation B4/C4
median speed factors were **0.851881067021277x** and
**0.867948821945671x**; their geometric mean was
**0.859877414844080x**. In the reciprocal direction the candidate therefore
cost about **16.3% more median wall time**. Candidate N4 p95 was worse on both
workloads, and both N4 CPU and aggregate-RSS ratios exceeded 1.25. The harness
reported nine HOLD conditions.

The exact
[`60-row result table`](results/2026-08-21-scaled-pool-screen.tsv) has SHA-256
`5f530bafce3bab6053bafddd846c88f2ca865bd80dd5a8e4b628d597ea8638cc`.
The
[capability-scaled verification report](../docs/reports/2026-08-21-capability-scaled-isolated-verification-hold.md)
records exact medians, p95 values, unrounded ratios, provenance, preflight
hashes, and all nine failures. Commit `a9d2655` reverted the production
connection. The validated two-to-four-worker owner remains package-private;
Main remains fixed-two.

This negative result has the opposite sign from a genuine double-digit
improvement. A measured positive gain greater than 10%, including the earlier
roughly 16.5%, remains meaningful and worth retaining, not speculative.
Future N3/N4 work stays on HOLD until a measured amortization design such as
warm reuse or deeper batches passes this same greater-than-10% gate.

## Default compiled-cache cells and workloads

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

### Rejected direct-pristine initializer screen

A later controlled experiment compared the cache-enabled parent `896840a`
with a candidate that replaced the verification artifact only for the exact
pristine session. It used `--baseline-cold-cache-modules 1` and
`--candidate-n2-initializer pristine-replay`, one warmup, and five measured
samples per cell. The three B2/C2 median ratios were 0.974x, 1.019x, and
1.003x, for a neutral 0.999x geometric mean. Exact transcripts, 1/3/1/3
preflight topology, route selection, cache behavior, and cleanup all passed.

The candidate route was removed: it established semantic parity but no
incremental acceleration over the artifact route. The harness defaults remain
`--baseline-cold-cache-modules 0` and
`--candidate-n2-initializer artifact`, preserving the published pre-cache
release protocol. The
[direct-pristine initializer report](../docs/reports/2026-08-21-direct-pristine-verification-worker-initialization-hold.md)
records exact executable hashes, wall results, and the separate semantic
rejection of using the richer compiled-tooling module itself.

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
