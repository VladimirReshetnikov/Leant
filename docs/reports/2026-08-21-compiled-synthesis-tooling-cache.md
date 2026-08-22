# Persistent compiled synthesis-tooling cache

Date: 2026-08-21

Status: implemented and promoted at
`c95afa924442e043ffb22d7c33061c81576c7fa0`. The exact release profile
returned `promotion: GO`.

## Decision

Keep the cache in the production no-project/no-explicit-import base route.

The checkpoint removes repeated compilation of Leant's generated Lean
synthesis serializer from fresh processes. A no-project, no-explicit-import
synthesis base now loads an ABI-checked `.olean` from a
persistent XDG cache after its first successful build. A cache miss, rejection,
or ordinary filesystem failure uses the established dynamic-compilation path.

The distinction between *observed acceleration* and *release promotion*
remains deliberate. The earlier five-sample run was useful evidence even when
one cold p95 control printed `HOLD`; it was not dismissed as speculative and
no row was replaced. The preregistered 21-sample release profile then resolved
that noisy control and independently cleared every enforced gate. Likewise,
the earlier prepared-pair route's roughly 16.5% screening acceleration remains
a meaningful measured result even though that particular scheduling change
added no incremental gain and was not promoted.

## Previous bottleneck

Every fresh Leant process used to build the same generated synthesis support
inside the primary Lean REPL:

1. import `Lean`;
2. send the complete generated `synthPrelude` command;
3. retain the returned process-local environment; and
4. only then pickle or use that environment for candidate verification.

The generated source depends on the active rating-name inventory, but not on
the user's candidate goal or session history. Repeating this compilation in
the primary process before isolated-worker artifact preparation was therefore
avoidable startup work. The preceding critical-path checkpoint
had already made isolated verification worthwhile; this cache removes a
larger common cost without changing its scheduler.

## Admission and compatibility boundary

The cache opens only when startup selected no Lake project. Main uses a cache
entry only when all three conditions hold:

- `rsProjectDir == Nothing`;
- `rsImports == []`; and
- the process-start cache authority is available.

Project sessions, explicit startup imports, and external snapshots retain
their existing dynamic base paths. Such a session with accepted interactive
history may load the cached pristine base and then replay that history through
the exact existing replay owner. The compiled module contains only the
generated synthesis tooling and its ABI constant; it contains no user goal,
candidate, declaration history, proof state, resumable `sorry` state, or
process-local environment ID.

This boundary is narrower than a claim that arbitrary Lean state is safely
cacheable. It deliberately preserves the conservative isolated-verification
session gate and its `+RTS -N1 -RTS` external-effects control.

## Cache identity and validation

`Leant.Synth.ToolingCache` owns one process-start authority and opaque derived
entries. The default root is:

```text
$XDG_CACHE_HOME/leant/synthesis-tooling-v1
```

or the platform XDG cache equivalent when `XDG_CACHE_HOME` is unset. Generated
modules live below `LeantSynthCache/` and have names such as:

```text
LeantSynthCache.K3723ebd3b1ad50ca
```

An entry key includes:

- the cache format tag;
- the absolute REPL backend path;
- backend byte count and high-resolution modification time;
- the normalized absolute backend working directory; and
- the exact generated serializer source, including the current rating-name
  inventory.

Hashing the complete backend executable was rejected after it caused roughly
9–11x GHC allocation for a 227 MiB REPL binary. Path, size, and modification
time are a cheap build-cache identity, not a security boundary. Deliberately
replacing an executable while preserving all three metadata fields requires
manual cache removal.

The metadata key is not trusted on its own. The generated module embeds the
exact `synthesisToolingABI`, and every hit imports the module together with a
Lean equality proof against the expected ABI. Lean's module loader and that
proof are the final semantic validity gates. Any error, fatal diagnostic,
missing environment, or transport failure rejects the hit. A rejected file is
invalidated and the current command takes the dynamic path.

## Publication and cleanup

The cache root is added to each backend's inherited `LEAN_PATH` before spawn.
`BackendConfig.bcLeanPath` preserves the historical environment exactly when
empty; otherwise it prepends the extra roots using the platform search-path
separator and replaces inherited `LEAN_PATH` case-insensitively for Windows.

On a miss, Main imports `Lean` and `Lean.Environment`, compiles the exact
historical `synthPrelude`, appends the ABI definition, and asks the same Lean
command to write a module to an absent sibling temporary path. No extra JSON
protocol round trip is added. Publication requires all of the following:

- the command returned normally;
- the response has no error or fatal diagnostic;
- Lean emitted the exact ABI-qualified completion marker; and
- the temporary module exists.

The Haskell owner reserves the absent path while masked, preserves callback
exceptions and cancellation, and cleans incomplete output. A complete module
is renamed into place; an already-present same-key artifact is retained.
Concurrent same-key writers may race only between semantically equivalent
entries and publish atomically. Optional filesystem failures are cache misses,
not synthesis failures.

## Deterministic and real-Lean gates

Three deterministic unit cases pin:

1. identity changes for backend metadata, working directory, and exact source;
2. publish-only-on-completion, existing-artifact retention, invalidation, and
   missing-backend failure; and
3. exact `ThreadKilled` propagation plus unpublished-temp cleanup.

Main source characterizations pin the no-project/no-import admission, validation
before dynamic fallback, cache-only `Lean.Environment` import, export marker,
invalidation, startup opening, and `LEAN_PATH` propagation.

The existing real-Lean parity gate now uses a private cache path containing
spaces and traces both `execve` and `openat`:

- the cold history-free N1 run executes one backend and publishes exactly one
  `K*.olean`;
- the warm history-free N2 run executes three backends, leaves that module's
  checksum unchanged, and opens the exact module;
- N1/N2 normalized output remains byte-identical with two candidates; and
- the scoped-history control executes one backend at N1 and N2 and retains its
  five-candidate transcript.

## Release benchmark design

The benchmark compares the immediate pre-cache parent with the candidate.
Both contain the same ordered isolated-verification implementation, so fixed-N2
`B2/C2` isolates the cache rather than comparing different schedulers.

| Cell | Binary | Capabilities | Cache state | Expected backends |
| --- | --- | ---: | --- | ---: |
| B1 | pre-cache baseline | 1 | shared | 1 |
| B2 | pre-cache baseline | 2 | shared | 3 |
| C1 | cache candidate | 1 | shared and warm | 1 |
| C2 | cache candidate | 2 | shared and warm | 3 |
| D1 | pre-cache baseline | 1 | unique and empty | 1 |
| D2 | cache candidate | 1 | unique and empty | 1 |

Each untimed preflight uses debug metrics and
`strace -f -e trace=execve,openat`. It requires five accepted candidates,
five attempted variants, five verified candidates, exact normalized semantic
output, B1/B2/C1/C2 topology 1/3/1/3, one shared module after C1, an exact C2
module open, and no verification-artifact leak.

Timed B/C samples reuse the preflight-populated cache. Every D sample receives
its own cache directory: D1 must leave it empty and D2 must publish exactly one
module. Timed runs do not use `strace`; they recheck the transcript hash,
candidate count, cache-module count, timeout, and artifact cleanup.

The release profile used two warmup cycles and 21 unreplaced samples per cell
for three workloads: 378 timed rows. Warm cells use a fixed four-row Latin
square, cold order alternates, and workload order alternates.

## Provenance

- baseline source:
  `575d67b667bd1fe03112c3027e7dc18a786282b8`;
- implementation source:
  `c95afa924442e043ffb22d7c33061c81576c7fa0`;
- pinned Djex gitlink:
  `9fa145ed743321cd861440940398413a6ad844b3`;
- baseline O2 executable SHA-256:
  `c37b75f21548940f4d1f1ccbd6b4ca13f99b43f4269f962f0ef6ac74ff0b62c5`;
- candidate O2 executable SHA-256:
  `05dbad8d174c10ee6cc17ac7231ff3e3051d2e55d504d5ad12e129a6ca8ab069`;
- Lean 4.32 REPL backend SHA-256:
  `a5f259e6f5c9bef23dbfe1ca6edf05b6df0a77003e5b00111885bda2484394cb`;
- benchmark harness SHA-256:
  `400025ae8399a2ee67271382a3cd5c24a46a0106cefd18c8fc2fc450a4deab82`;
- raw 378-row TSV SHA-256:
  `e2c4ca4484b4f0897cf74b7312dc09ca174f9140045d496f73defb6c13af7d34`.

The committed table is
[`bench-verification/results/2026-08-21-compiled-tooling-cache-release.tsv`](../../bench-verification/results/2026-08-21-compiled-tooling-cache-release.tsv).

## Exact wall results

Times are seconds. p95 is nearest-rank p95 over 21 samples.

| Workload | B1 med/p95 | B2 med/p95 | C1 med/p95 | C2 med/p95 | D1 med/p95 | D2 med/p95 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| state-thread | 7.884/8.358 | 5.861/6.171 | 4.954/5.440 | 3.051/3.550 | 7.883/8.509 | 7.921/8.745 |
| continuation | 7.835/8.191 | 5.943/6.337 | 4.892/5.241 | 3.025/3.345 | 7.786/8.677 | 7.974/8.754 |
| `List.map` | 7.823/8.528 | 5.957/6.407 | 4.955/5.681 | 3.080/3.204 | 7.796/8.809 | 8.038/9.510 |

| Workload | B2/C2 warm speedup | C1/C2 candidate scaling | C1/B1 warm N1 ratio | D2/D1 cold median ratio | Cold p95 ratio |
| --- | ---: | ---: | ---: | ---: | ---: |
| state-thread | **1.921x** | 1.624x | 0.628x | 1.005x | 1.028x |
| continuation | **1.965x** | 1.617x | 0.624x | 1.024x | 1.009x |
| `List.map` | **1.934x** | 1.609x | 0.633x | 1.031x | 1.080x |

The B2/C2 geometric mean across all three workloads is **1.940x**.
Candidate N1 is also about 1.58–1.60x faster than the pre-cache baseline once
the shared cache is warm. The cold primary controls remain within +2.4% at the
median and +2.8% at p95.

## Resource ratios

The table reports candidate C2 divided by baseline B2 medians. RSS is sampled
aggregate process-tree resident memory and can double-count shared pages.

| Workload | GHC allocation | process-tree CPU | aggregate peak RSS |
| --- | ---: | ---: | ---: |
| state-thread | 0.624x | 0.530x | 0.985x |
| continuation | 0.710x | 0.518x | 0.987x |
| `List.map` | 0.767x | 0.523x | 0.978x |

All are below the preregistered ceilings of 1.10x allocation and 1.25x CPU/RSS.
Candidate N2 p95 is lower than baseline N2 p95 for every workload.

## Transcript evidence

Every preflight and timed row retained one normalized transcript hash per
workload:

- state-thread:
  `ce055ee44eb7e6d8f8b969a32e9cd2dd85855e9646190a712a45ad2e55bddb6c`;
- continuation:
  `dbdc8ef04e90278fd773e07bc8477f3b5f59e1fbf2370910c0baaf7303dec9e7`;
- `List.map`:
  `5cc74a4cb216329ee5c4b3c8db6a4ef4403ac1b7193d5ec9d3f8ed93e0010d6d`.

The 12 preflight traces contain the exact expected backend counts. The shared
cache contains one 2,452,952-byte module, and C2 opens it. The 126 cold cache
directories contain exactly 63 modules, one for each D2 sample and none for
D1. No `leant-parallel-verification*` artifact remained.

## Screening versus promotion

The preceding five-sample screen measured a 1.955x warm geometric mean. It
printed `HOLD` only because continuation's cold p95 was the five-sample maximum
and happened to be 1.204x. That observation was retained as meaningful
screening evidence; it was not release evidence and was not silently replaced.
At the preregistered 21-sample profile, the same cold p95 ratio was 1.009x and
every gate returned GO.

This is why the project records exact double-digit screening improvements such
as the earlier 16.5% route gain while still requiring a larger release profile
for promotion. “Not yet promoted” does not mean “speculative” or “worthless”;
it describes the evidence tier.

## Validation

The implementation checkpoint passed:

- three of three focused cache tests;
- the complete strict Leant suite, **585 of 585**;
- serialized `cabal test all -j1 --ghc-options=-Werror` across Leant and Djex;
- strict all-target builds with tests and benchmarks enabled;
- native POSIX and forced Windows CPP warning-as-error compilation of
  `Leant.Backend`;
- the real-Lean cache/parity/topology gate;
- `cabal check`, diff, whitespace, final-newline, and TSV-shape checks; and
- `cabal sdist pkg:leant`, with every changed source, harness, gate, and result
  file byte-identical inside the archive.

## Claim boundary

The release-grade claim is narrow and concrete:

- on the measured history-free, no-project five-result workloads, a warm
  compiled-tooling cache makes the existing explicit-N2 route about
  **1.92–1.96x** faster than the same route immediately before this cache;
- the first-use primary controls show no material median or p95 regression;
- output, candidate count, debug metrics, worker topology, and cleanup remain
  exact.

This is not a claim about project sessions, explicit-import sessions, external
snapshots, nonempty history, arbitrary cache security, every Lean filesystem,
default N2, or universal synthesis speed. Those paths remain unchanged or
outside the measured corpus.

## Reproduction

Build both binaries with the same explicit optimized profile:

```console
cabal build exe:leant --enable-optimization=2 -j1 --ghc-options=-Werror
cabal list-bin exe:leant --enable-optimization=2
```

Then run:

```console
./bench-verification/benchmark.py \
  --baseline /absolute/path/to/575d67b/leant \
  --candidate /absolute/path/to/c95afa9/leant \
  --backend /absolute/path/to/lean-4.32/repl \
  --warmups 2 \
  --samples 21 \
  --results bench-verification/results/2026-08-21-compiled-tooling-cache-release.tsv \
  --artifacts /absolute/path/to/raw-artifacts \
  --enforce
```

The real-Lean topology/cache gate is:

```console
LEANT_EXE=/absolute/path/to/leant \
LEANT_BACKEND=/absolute/path/to/repl \
./test/run-parallel-verification-gate.sh
```
