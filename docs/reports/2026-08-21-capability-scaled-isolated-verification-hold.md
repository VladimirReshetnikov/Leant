# Capability-scaled isolated verification screen

Date: 2026-08-21

Status: implementation and semantic gates complete; the N3/N4 production
connection is **HOLD**. Commit `a9d2655` removed that connection after the
fixed-N4 retention screen. Production continues to acquire exactly two
isolated verification workers. The bounded two-to-four-worker resource
foundation remains package-private.

## Decision

Do not scale one verification batch from two to three or four isolated Lean
workers merely because the process has that many RTS capabilities. On both
primary five-result workloads, the four-worker candidate was slower than the
fixed-two baseline running under the same `+RTS -N4 -RTS` setting:

| Workload | Baseline B4 median | Candidate C4 median | B4/C4 speed factor |
| --- | ---: | ---: | ---: |
| state-thread | 2.969884 s | 3.486266 s | **0.851881067021277x** |
| continuation | 3.028066 s | 3.488761 s | **0.867948821945671x** |

Their B4/C4 geometric mean is **0.859877414844080x**. In the reciprocal
direction, C4/B4 is **1.173872784256894x** and **1.152141664019212x**;
the geometric mean is **1.162956466511367x**, or about **16.3% more median
wall cost**. The harness reported nine separate HOLD conditions. The Main
connection was therefore reverted rather than retained.

This decision does not redefine a genuine positive double-digit result as
speculative. A measured improvement greater than 10%, including the earlier
roughly 16.5% connected-verifier gain, is meaningful, worthwhile evidence and
is worth retaining. This experiment has the opposite sign. The historical
1.25x release-promotion gate is a distinct, stronger evidence tier; neither it
nor this negative result erases a real positive improvement above 10%.

Future N3/N4 work remains on HOLD unless a benchmarked amortization design,
such as safe warm worker reuse or deeper verification batches, passes the same
meaningful greater-than-10% retention gate with the existing semantic and
resource controls.

## Retained package-private foundation

Commit `1097e30cba7140df3fd22705276530b1f39b2d70` generalized the isolated
resource owner without changing Main. `mkIsolatedBackendPoolSize` validates an
integer in the deliberately narrow range two through four before any backend
or artifact can be touched. Its constructor is hidden. `withIsolatedBackendPool`
then restores that many independent workers from one immutable command
environment artifact.

Every historical entry point remains exact-two: artifact-restored pair,
history-replaying pair, and prepared-pair acquisition. The generalized setup
starts every requested worker under nested structured `async` ownership before
observing readiness, observes results in worker-ordinal order, cancels and
joins an irrelevant higher-ordinal suffix after the first known setup failure,
and only then reads the masked registry for ordinal cleanup. The same opaque
leases, per-worker request locks, first-poison rule, checked-out-sibling
completion, fail-stop release, atomic close transition, and bounded whole-tree
cleanup apply at every valid size.

Deterministic tests cover invalid sizes, all-four setup admission, successful
three- and four-worker leasing, ordinal-one precedence when all four setups
fail, source-order coverage of later-failure suffix cancellation before
cleanup, all-worker callback and close cleanup, poisoning a three-worker pool,
and the unchanged exact-two pair/prepared APIs. This is useful package-private
infrastructure even though the measured Main policy was rejected.

## Reverted production experiment

Commit `4f11872b9563be16bc9664982f37d4d5ad770583` connected the pool to Main
for measurement. The existing artifact runtime performed its sole capability
query only after the static session gate and recorded that result in the
synthesis-command context. An admitted batch selected
`min 4 capabilities successQuota` as its observation limit, counted only that
bounded reachable group prefix, validated the exact resulting worker count,
and gave the same width to the ordered success-quota scheduler. Thus N1 stayed
literal serial, N2 retained two workers, N3/N4 could scale, a short two-group
batch still acquired only two workers, and no unbounded `length groups` forced
the lazy tail.

The expanded real-Lean gate proved byte-identical N1/N2/N3/N4 output on a
five-result history-free fixture and exact primary-plus-worker topology. It
also proved that a two-result batch at N4 still used only two workers, that the
pristine hidden-type case remained candidate-free, and that scoped session
history remained serial. Artifact routing, exact shared-cache opens, unchanged
compiled-module identity, and command-temporary cleanup were checked at every
applicable capability count.

Commit `dc81e19d51db2aa89ba80172e17895230020066f` added the preregistered
six-cell benchmark protocol. Once the screen returned HOLD, commit
`a9d26553fe48244edcb6914bd70a52b3811dff79` reverted the Main, unit-oracle,
fixture, and real-gate connection. It deliberately retained both the
package-private pool foundation and the benchmark protocol. The Djex gitlink
was `9fa145ed743321cd861440940398413a6ad844b3` throughout.

## Benchmark protocol and provenance

The screen compared the exact foundation commit as a fixed-two baseline with
the exact connected experiment:

| Cell | Executable | RTS capabilities | Required Lean processes |
| --- | --- | ---: | ---: |
| B1 | fixed-two baseline | 1 | 1 |
| C1 | scaled candidate | 1 | 1 |
| B2 | fixed-two baseline | 2 | 3 |
| C2 | scaled candidate | 2 | 3 |
| B4 | fixed-two baseline | 4 | 3 |
| C4 | scaled candidate | 4 | 5 |

The two primary workloads were `state-thread.txt` and `continuation.txt`.
Each used one warmup and five measured samples in each cell. The Williams
orders documented by the harness cover every directed treatment adjacency,
and workload order alternated by sample. All **60 measured rows** completed
and were retained; no row was rerun or replaced. The host and current affinity
set both exposed **6 CPUs**. `/proc` process-tree resource sampling ran every
20 ms.

Exact provenance and integrity digests:

- fixed-two baseline Leant commit:
  `1097e30cba7140df3fd22705276530b1f39b2d70`;
- scaled candidate Leant commit:
  `4f11872b9563be16bc9664982f37d4d5ad770583`;
- baseline and candidate Djex commit:
  `9fa145ed743321cd861440940398413a6ad844b3`;
- baseline O2 executable SHA-256:
  `4516185be754952ad63d697db27b04c231098a5b15c5543d9e347c4ef8808d62`;
- candidate O2 executable SHA-256:
  `b978d9a0a935b531003e3d935e50ef076b377a51d299b63a71db0888e99169c8`;
- Lean 4.32 backend SHA-256:
  `a5f259e6f5c9bef23dbfe1ca6edf05b6df0a77003e5b00111885bda2484394cb`;
- committed 60-row TSV SHA-256:
  `5f530bafce3bab6053bafddd846c88f2ca865bd80dd5a8e4b628d597ea8638cc`;
- complete measurement log SHA-256:
  `e739588a64dcc31a54e162b9b8cf690f27603019d39dc3c7157e43b9f4b6752f`;
- baseline O2 build-log SHA-256:
  `149de51df4c6b036195032671028bd0ce23f81d2b26d04abb3e351eb9218f593`;
- candidate O2 build-log SHA-256:
  `f035807f468bfe986a16c2adaa4c15b84de4195d56606bfc38a33c4b612fd4ce`;
- build-metadata record SHA-256:
  `24abc64c17b3a76064a8557e1ad71edc68a067946170567351085669966c108e`;
- compiled tooling module SHA-256:
  `0d013b5f4138a0a4dcc2a9051ebaa99a78ba085486147eaf05eb2a85892e8030`;
- measurement-root pointer SHA-256:
  `9ecea3bb71ac7fc539e6c7af3d77e855834a3e307a9ae6f52423159ccb56141d`.

The final measurement audit also hashed deterministic sorted manifest streams;
these are computed integrity digests, not persisted manifest files. The
all-artifact manifest-stream SHA-256 was
`eb5abd1e08267e4ef820af0bb116fdeab2af2044b5069140d2953946c657ccd5`.
The sixteen-preflight-trace manifest-stream SHA-256 was
`b3c5388752f0701f68ccc7729a5fbd076537867bd50c35b7579d4b850b0b25e0`.

The raw table is committed as
[`2026-08-21-scaled-pool-screen.tsv`](../../bench-verification/results/2026-08-21-scaled-pool-screen.tsv).
It is byte-identical to the harness output and has one header plus 60 rows.

## Preflight evidence

The short two-result batch ran first against one shared private compiled-
tooling cache. Its B1/B4/C1/C4 topology was exactly **1/3/1/3** backends. B1
cold-published the one module and opened it zero times; B4, C1, and C4 each
opened that exact module once without changing its path or SHA-256. The four
normalized short transcripts were identical, with semantic SHA-256
`41f3e1fac5cbaa7757b1dd37fcebe8b795a7c83da07a2918c56b8d8b4ca924f4`.
The N4 candidate's three-process topology proves that reachable group demand,
not capability count alone, bounded its worker acquisition.

Each long workload then ran untimed in all six cells. Exact topology was
**1/1/3/3/3/5** for B1/C1/B2/C2/B4/C4. Every multi-worker trace used the
command artifact, every N1 trace did not, and every trace opened the same
compiled module exactly once. No `leant-parallel-verification*` artifact
remained below a command's private temporary directory. Normalized debug and
semantic transcripts were byte-identical across all six cells, retained
exactly `it1` through `it5`, and reported exactly five attempted and five
verified candidates. The semantic hashes were:

- state-thread:
  `ce055ee44eb7e6d8f8b969a32e9cd2dd85855e9646190a712a45ad2e55bddb6c`;
- continuation:
  `dbdc8ef04e90278fd773e07bc8477f3b5f59e1fbf2370910c0baaf7303dec9e7`.

Every measured TSV row rechecked its workload's exact transcript hash: 30
state-thread rows and 30 continuation rows.

## Exact wall results

Wall times are seconds. With five samples, p95 is the nearest-rank maximum.
Values below preserve the TSV's six-decimal measurements exactly.

| Workload | Cell | Median | p95 |
| --- | --- | ---: | ---: |
| state-thread | B1 | 4.908110 | 5.155659 |
| state-thread | C1 | 4.901434 | 4.934570 |
| state-thread | B2 | 2.961936 | 2.968817 |
| state-thread | C2 | 3.006073 | 3.164601 |
| state-thread | B4 | 2.969884 | 3.079269 |
| state-thread | C4 | 3.486266 | 3.519217 |
| continuation | B1 | 4.821226 | 5.097792 |
| continuation | C1 | 4.831548 | 4.873960 |
| continuation | B2 | 2.977296 | 3.251434 |
| continuation | C2 | 2.957042 | 3.081664 |
| continuation | B4 | 3.028066 | 3.151103 |
| continuation | C4 | 3.488761 | 3.676733 |

The following ratios are direct quotients of those exact table values. They
are carried beyond the harness's three-decimal display rather than computed
from its rounded summary:

| Workload | B4/C4 median | C2/C4 median | B2/B4 median | C1/B1 median/p95 | C2/B2 median/p95 | C4/B4 p95 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| state-thread | 0.851881067021277 | 0.862261514181649 | 0.997323801198969 | 0.998639802286420 / 0.957117218186851 | 1.014901402326050 / 1.065946806421550 | 1.142874169161580 |
| continuation | 0.867948821945671 | 0.847590878251620 | 0.983233522651092 | 1.002140949210840 / 0.956092363125055 | 0.993197182947211 / 0.947786115295590 | 1.166808257299110 |

The fixed-two B2/B4 controls remained near one, confirming that simply giving
the baseline four RTS capabilities did not explain the candidate's loss. N1
and N2 implementation controls also remained within their preregistered wall
bounds. Candidate N4, in contrast, did not improve on candidate N2:
C2/C4 was 0.862261514181649x and 0.847590878251620x.

Median resource ratios, again computed directly from the retained rows, were:

| Workload | Cell ratio | Allocation | Process-tree CPU | Aggregate RSS |
| --- | --- | ---: | ---: | ---: |
| state-thread | C1/B1 | 1.000154425908020 | 1.002155172413790 | 0.999645885432948 |
| state-thread | C2/B2 | 0.999803897506972 | 1.009900990099010 | 0.997945469331849 |
| state-thread | C4/B4 | 1.092237544911330 | 1.316831683168320 | 1.310349660542800 |
| continuation | C1/B1 | 1.000052194673530 | 1.000000000000000 | 1.000218265570560 |
| continuation | C2/B2 | 0.999976460638057 | 1.000000000000000 | 1.003037058466500 |
| continuation | C4/B4 | 1.063136070660860 | 1.277419354838710 | 1.321600048281750 |

N4 allocation stayed within its 1.10 bound, but CPU and aggregate RSS crossed
their 1.25 limits on both workloads. Aggregate RSS is the sampled sum across
the process tree and can double-count shared pages; it is still the exact
preregistered comparison used for both binaries.

## Nine HOLD conditions

The harness returned these nine independent failures, with exact retained
values shown here:

1. State-thread B4/C4 speed factor 0.851881067021277x was below 1.10x.
2. State-thread C4 p95 3.519217 s exceeded B4 p95 3.079269 s.
3. State-thread C4/B4 CPU ratio 1.316831683168320x exceeded 1.25x.
4. State-thread C4/B4 aggregate-RSS ratio 1.310349660542800x exceeded 1.25x.
5. Continuation B4/C4 speed factor 0.867948821945671x was below 1.10x.
6. Continuation C4 p95 3.676733 s exceeded B4 p95 3.151103 s.
7. Continuation C4/B4 CPU ratio 1.277419354838710x exceeded 1.25x.
8. Continuation C4/B4 aggregate-RSS ratio 1.321600048281750x exceeded 1.25x.
9. The two-workload B4/C4 geometric mean 0.859877414844080x was below 1.10x.

No N1 or N2 wall control and no allocation control produced another HOLD.
The negative decision therefore attributes specifically to widening this
one-shot verification batch, not to transcript drift or a general candidate-
binary regression.

## Remaining boundary

Spawning and restoring two extra Lean processes for a five-group, one-shot
batch costs more than the additional overlap saves on this six-CPU host. A
future design must amortize that setup and memory pressure without weakening
artifact identity, ordered success semantics, failure precedence, or complete
process-tree ownership. Plausible measurements include safe command-scoped
warm reuse and batches deep enough to keep three or four workers usefully busy.
Neither is authorized by this result. Until one produces a reproducible
greater-than-10% positive gain under the same gates, Main remains fixed-two and
explicit N3/N4 verification scaling remains HOLD.
