# Descriptor-bound Length/Z3 launch

Date: 2026-08-15

## Outcome

Leant now exposes Djex's additive descriptor-bound main-image launcher through
one pure programmatic policy constructor and two closed startup profiles:

- scalar version 17; and
- nominal binary-product version 18.

Both retain the complete strict-relational/scoped v15/v16 behavioral profile.
They change only the sealed executable-launch authority. Candidate admission,
preparation, MRU replay, applicable-domain validation, origin probing,
counterexample simplification, Z3 query ordering, post-`unsat` box replay,
ranking partitions, evidence, and presentation remain unchanged.

## Programmatic surface

`mkLengthRankingPolicyWithDescriptorBoundExecutableLaunch` accepts the same
`LengthRankingPolicySource` as `mkLengthRankingPolicy`. It calls Djex's
`mkLengthSMTLibDescriptorBoundExecutionConfig` before validating evaluation
limits, retaining the established execution-before-evaluation diagnostic order.
Successful construction is pure and produces the ordinary opaque
`LengthRankingPolicy`.

`lengthRankingPolicyExecutableLaunchStrategy` projects only Djex's closed
classifier. It reveals no configured path, digest bytes, descriptor, staged
image, pin result, or process observation. A policy assembled through
`lengthRankingPolicyFromValidatedComponents` retains the strategy already
sealed in its Djex execution config.

`lengthAssessmentModeExecutableLaunchStrategy` provides the same closed view at
the activated integration boundary. Disabled assessment returns `Nothing`.
Configured assessment inspects only the strict policy field and does not force
the separately retained scalar or product contract.

No ranking builder owns a second launch flag. Origin, box, applicable-domain,
simplification, preference, opening, and usable-work builders preserve the
sealed execution config exactly.

## Closed v17/v18 documents

The public version constants are:

- `lengthRankingConfigurationFileDescriptorBoundExecutableLaunchVersion = 17`;
- `lengthRankingConfigurationFileSpinePairDescriptorBoundExecutableLaunchVersion = 18`.

V17 and v18 retain the exact v15/v16 root fields:

```text
format
version
executionAdmission
execution
evaluation
inputBoxValidation
counterexampleProbe
boundedPositiveOrdering
applicableDomainValidation
applicableDomainOrdering
counterexampleSimplification
liveSessionOpening
usableWorkBudget
contract
```

The execution object retains every established member and appends exactly:

```json
"executableLaunch": "descriptor-bound-executable-v1"
```

Older execution objects remain literal. V1--v16 reject that member as
unexpected, and v17/v18 require it, reject another type or literal, and reject
every extra member. The established `executionFields` and `decodeExecution`
paths are not widened.

V17 requires the scalar-v5 contract. V18 requires the pair-v5 contract and its
`"resultShape": "binary-prod-spines-v1"` discriminator. Both require:

- `"strict-relational-positive-affine-v1"` applicable-domain extraction;
- both non-vacuous preferences;
- bounded componentwise-lexicographic counterexample simplification;
- deferred live opening; and
- `"scoped-checkpointed-shared-usable-work-deadline-v2"`.

The two complete documents in the root README carry a valid illustrative
64-hex-digit expectation. It must be replaced with the intended Z3 digest.
Startup activation checks only expectation presence unless the user explicitly
permits an unpinned policy; it performs no hash or match.

## Decoder precedence

The generalized decoder invokes the descriptor parser only when the complete
v1--v16 cascade returns the closed `UnsupportedVersion` sentinel. Every other
older diagnostic returns unchanged. Version 19 is the first unsupported future
profile.

Within v17/v18 the demand order is:

1. exact root;
2. execution admission;
3. exact descriptor execution object;
4. inherited response limits, path, expected digest, solver timeout, solver
   resource limit, host deadline, and artifact policy;
5. the required descriptor-launch literal and Djex policy construction;
6. evaluation limits;
7. explicit input box;
8. origin-probe literal;
9. bounded-positive ordering;
10. strict-relational applicable-domain object and limits;
11. applicable-domain ordering;
12. counterexample simplification;
13. deferred opening;
14. scoped usable-work object, duration cap, and Djex budget admission; and
15. the nominal scalar-v5 or pair-v5 contract.

JSON member order is immaterial. A later contract error cannot preempt an
earlier operational or behavioral-policy rejection.

## Runtime lifecycle

V17/v18 retain the v13--v16 scoped/deferred state machine literally:

1. admit at most 64 candidates outside the usable-work owner;
2. capture the owner-thread-affine scoped deadline;
3. force complete candidate/query preparation;
4. checkpoint;
5. run MRU, strict applicable-domain validation, and origin replay serially;
6. checkpoint after every completed candidate chain and before the first live
   miss;
7. open at most one scoped Z3 session for the first live miss and remaining
   suffix;
8. checkpoint after each live candidate and after forcing the complete result;
9. close the scoped token and observe the outer normal-return deadline; and
10. use the existing original-order atomic fallback on every structured
    failure.

An all-pure batch performs no executable filesystem or process IO. The first
live miss enters Djex's descriptor branch. Djex opens the source without
following its final component, copies each bounded chunk into SHA-256 and a
private anonymous image, compares the optional pin, makes that image executable,
seals content and size changes, and passes only the sealed descriptor to
`execveat(AT_EMPTY_PATH)`. Before exec it requires Linux `close_range` to close
every unrelated inherited descriptor around the retained staged-image and
status descriptors. A missing or rejected `close_range` fails the launch;
there is no scan bounded by the current soft `RLIMIT_NOFILE`, because that
limit can sit below a descriptor opened before it was lowered. Djex never
retries the configured pathname.

The same scoped deadline covers bounded staging, capability admission, and live
query work. Fresh established final-readiness and cleanup windows keep their
v13/v14 semantics, and the outer scoped owner can still supersede a provisional
indexed result if normal return observes shared expiry.

## Failure boundary

Pure decoder/configuration rejection remains
`LengthRankingConfigurationExecutionRejected` around the existing Djex config
error. Live source, staging, seal, descriptor spawn, capability, timeout, and
cleanup failures remain `LengthRankingLiveSessionFailed` with no candidate
index. They reset every eligible candidate to `Unassessed`, retain preparation
refusals in original order, and expose only the existing cleanup-incomplete
bit. Paths, digest bytes, errno text, descriptors, staged bytes, and child
output never enter Leant failures.

Pin mismatch occurs before child allocation. An unsupported platform or Linux
primitive fails closed if a live miss needs it. Neither case falls back to the
legacy pathname launcher.

## Startup presentation

The established pinned/unpinned activation notice remains literal. V17/v18 add
one classifier-derived operational line saying descriptor-bound launch was
selected and that a configured digest will be checked against the sealed staged
main-image bytes used for launch. The line does not say the digest matched,
because no executable IO occurs during configuration loading or activation.

V1--v16 emit no new line. Disabled assessment remains silent. Candidate,
counterexample, applicable-domain, and bounded-positive notes are byte-exact:
launch authority is not behavioral evidence.

## Identity and compatibility

V1--v16 keep their old execution config construction, fingerprints, process
strength tag, ready-worker and scalar/product query-run identities, failure
rendering, live ordering, and assessment behavior. The v17/v18 config schema is
new, and Djex supplies additive descriptor policy, process observation,
ready-worker, scalar-run, and product-run identities. Query, protocol,
behavioral-problem, contract, evidence, and receipt bytes do not change.

The configured path and expected SHA-256 remain part of the pure execution
policy. A live descriptor observation additionally binds the sealed staged
image and launch method. Mutable fd numbers, source path state after opening,
thread IDs, and cleanup observations do not become behavioral authority.

## Exact authority limit

Descriptor launch establishes only the staged main executable bytes. The image
deliberately does not copy source set-id bits or file capabilities. It does not
attest an ELF interpreter, dynamic loader, shared library, kernel, hardware,
Z3 algorithm, or solver result. The digest remains an external SHA-256 pin with
its ordinary assumptions. Descendant cleanup remains best effort after the
direct child exits.

Consequently, `sat`, `unsat`, and `unknown` remain heuristic. A counterexample
still requires exact query association and independent Djex replay, and a
positive ranking receipt still requires complete admitted finite-domain replay.
Launch selection grants no proof, pruning, or cross-domain authority.

Djex's native mechanism and threat model are recorded in the vendored
[descriptor-bound Z3 main-image launch report](../../lib/Djex/docs/reports/2026-08-15-descriptor-bound-z3-main-image-launch.md).
