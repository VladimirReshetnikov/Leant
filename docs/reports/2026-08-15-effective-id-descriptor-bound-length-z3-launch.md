# Effective-ID descriptor-bound Length/Z3 launch

Date: 2026-08-15

## Outcome

Leant now exposes Djex's effective-ID executable-access descriptor launcher
through one pure programmatic constructor and two exact startup profiles:

- scalar version 21; and
- nominal binary-product version 22.

V21/v22 retain the complete v19/v20 root-quotient-consequence, descriptor,
scoped-v2, deferred-opening, preference, simplification, and contract profile.
They replace only the executable-launch literal and Djex execution-policy
constructor. There is no new assessment, behavioral receipt, renderer, query,
protocol, ranking rule, or pruning authority.

## Public surface

`mkLengthRankingPolicyWithDescriptorBoundEffectiveIDExecutableAccessLaunch`
accepts the same `LengthRankingPolicySource` as the two established policy
makers. It validates Djex execution before evaluation limits and performs no
IO. Source opening, both effective-ID access checks, copying, hashing, pin
comparison, sealing, and child allocation occur only if a later lexical live
session is demanded.

`lengthRankingPolicyExecutableLaunchStrategy` projects Djex's closed
classifier from an opaque policy. The result for this maker is
`LengthSMTLibDescriptorBoundEffectiveIDExecutableAccessLaunch`.
`lengthAssessmentModeExecutableLaunchStrategy` provides the same closed view
at the integration boundary: disabled assessment returns `Nothing`, and a
configured mode returns the policy classifier without forcing the separately
retained scalar or pair contract. Every policy builder and
`lengthRankingPolicyFromValidatedComponents` preserves the strategy already
sealed in the Djex execution config.

A minimal programmatic selection is:

```haskell
effectiveAccessPolicy <- either (fail . show) pure $
  mkLengthRankingPolicyWithDescriptorBoundEffectiveIDExecutableAccessLaunch
    policySource

case lengthRankingPolicyExecutableLaunchStrategy effectiveAccessPolicy of
  LengthSMTLibDescriptorBoundEffectiveIDExecutableAccessLaunch ->
    assessVerifiedLengthCandidatesWithPolicy
      effectiveAccessPolicy scalarContract verificationBatch
  _ -> error "impossible for this constructor"
```

The established orthogonal builders can then select the quotient applicable-
domain pass, both non-vacuous preferences, simplification, deferred opening,
and scoped-v2 usable-work budget. Their last-wins dimensions are unchanged.
The scalar and pair assessments and their presentation renderers remain
`StrictRelationalPositiveAffineQuotientApplicableDomainEstablished`,
`LengthSpinePairStrictRelationalPositiveAffineQuotientApplicableDomainEstablished`,
`renderLengthStrictRelationalPositiveAffineQuotientApplicableDomainValidationNote`,
and
`renderLengthSpinePairStrictRelationalPositiveAffineQuotientApplicableDomainValidationNote`.
Launch strategy itself creates no candidate note.

## Exact v21/v22 schema

The public version constants are:

- `lengthRankingConfigurationFileDescriptorBoundEffectiveIDExecutableAccessVersion = 21`;
- `lengthRankingConfigurationFileSpinePairDescriptorBoundEffectiveIDExecutableAccessVersion = 22`.

Both versions retain the exact v19/v20 root field set and all existing caps.
Their execution object retains the v17--v20 field set and requires this last
closed member:

```json
"executableLaunch": "descriptor-bound-effective-id-executable-access-v1"
```

The complete scalar v21 document is:

```json
{
  "format": "leant-live-length-ranking-configuration",
  "version": 21,
  "executionAdmission": {
    "executablePathCharacters": 4096,
    "policyFingerprintBytes": 262144
  },
  "execution": {
    "executablePath": "/absolute/path/to/z3",
    "expectedExecutableSha256": "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
    "solverTimeoutMilliseconds": 1000,
    "solverResourceLimit": 100000,
    "hostDeadlineMilliseconds": 1500,
    "artifactPolicy": "input-values-after-satisfiable",
    "responseLimits": {
      "bytes": 65536,
      "nestingDepth": 64,
      "nodes": 4096,
      "tokenBytes": 4096,
      "integerBits": 4096
    },
    "executableLaunch": "descriptor-bound-effective-id-executable-access-v1"
  },
  "evaluation": {
    "assignmentValueBits": 4096,
    "intermediateValueBits": 4096
  },
  "inputBoxValidation": {
    "inclusiveInputMaximums": [5, 5],
    "maximumAssignments": 36
  },
  "counterexampleProbe": "origin-before-live",
  "boundedPositiveOrdering": "prefer-non-vacuous",
  "applicableDomainValidation": {
    "strategy": "strict-relational-positive-affine-quotient-v1",
    "maximumInputs": 2,
    "maximumAssignments": 20
  },
  "applicableDomainOrdering": "prefer-non-vacuous",
  "counterexampleSimplification": {
    "strategy": "componentwise-lexicographic-v1",
    "maximumInputs": 2,
    "maximumAssignments": 36
  },
  "liveSessionOpening": "defer-until-live-query",
  "usableWorkBudget": {
    "strategy": "scoped-checkpointed-shared-usable-work-deadline-v2",
    "milliseconds": 30000
  },
  "contract": {
    "spine": {"family": "List", "zero": "List.nil", "step": "List.cons"},
    "targetArgumentRoles": ["observed-spine", "observed-spine"],
    "candidateCasePolicy": "cases-rejected",
    "precondition": [
      "all",
      [
        ["not", ["at-most", ["literal", 5], ["input", 0]]],
        ["not", ["at-most", ["input", 0], ["input", 1]]]
      ]
    ],
    "postcondition": ["equal", ["result"], ["input", 0]],
    "providerLaws": []
  }
}
```

The complete nominal pair v22 document is:

```json
{
  "format": "leant-live-length-ranking-configuration",
  "version": 22,
  "executionAdmission": {
    "executablePathCharacters": 4096,
    "policyFingerprintBytes": 262144
  },
  "execution": {
    "executablePath": "/absolute/path/to/z3",
    "expectedExecutableSha256": "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
    "solverTimeoutMilliseconds": 1000,
    "solverResourceLimit": 100000,
    "hostDeadlineMilliseconds": 1500,
    "artifactPolicy": "input-values-after-satisfiable",
    "responseLimits": {
      "bytes": 65536,
      "nestingDepth": 64,
      "nodes": 4096,
      "tokenBytes": 4096,
      "integerBits": 4096
    },
    "executableLaunch": "descriptor-bound-effective-id-executable-access-v1"
  },
  "evaluation": {
    "assignmentValueBits": 4096,
    "intermediateValueBits": 4096
  },
  "inputBoxValidation": {
    "inclusiveInputMaximums": [4],
    "maximumAssignments": 5
  },
  "counterexampleProbe": "origin-before-live",
  "boundedPositiveOrdering": "prefer-non-vacuous",
  "applicableDomainValidation": {
    "strategy": "strict-relational-positive-affine-quotient-v1",
    "maximumInputs": 1,
    "maximumAssignments": 3
  },
  "applicableDomainOrdering": "prefer-non-vacuous",
  "counterexampleSimplification": {
    "strategy": "componentwise-lexicographic-v1",
    "maximumInputs": 1,
    "maximumAssignments": 9
  },
  "liveSessionOpening": "defer-until-live-query",
  "usableWorkBudget": {
    "strategy": "scoped-checkpointed-shared-usable-work-deadline-v2",
    "milliseconds": 30000
  },
  "contract": {
    "resultShape": "binary-prod-spines-v1",
    "spine": {"family": "List", "zero": "List.nil", "step": "List.cons"},
    "targetArgumentRoles": ["observed-spine"],
    "candidateCasePolicy": "cases-rejected",
    "precondition": [
      "not",
      [
        "at-most",
        ["sum", [["input", 0], ["literal", 3]]],
        ["scale", 2, ["input", 0]]
      ]
    ],
    "postcondition": [
      "all",
      [
        ["equal", ["result", "first"], ["input", 0]],
        ["equal", ["result", "second"],
          ["quotient", 2, ["input", 0]]]
      ]
    ],
    "providerLaws": []
  }
}
```

The illustrative digest must be replaced with the intended Z3 digest. Default
activation requires expectation presence, not a match; matching occurs only
at the first demanded live open. JSON object member order is immaterial, but
the decoder's validation and diagnostic precedence are fixed.

## Decoder order and compatibility

The v21/v22 parser is reached only after the complete v1--v20 cascade returns
the closed `UnsupportedVersion` sentinel. Version 23 is the next unsupported
sentinel. V1--v20 remain literal: their exact schemas, launch literals,
diagnostics, builders, identities, and behavior are unchanged, and their
execution objects reject the new literal or an unexpected new member.

Within v21/v22 the demand order is:

1. exact root fields;
2. `executionAdmission`;
3. exact execution object;
4. response limits, executable path, expected digest, solver timeout and
   60,000-ms cap, resource limit and 10,000,000 cap, host deadline and
   65,000-ms cap, then artifact policy;
5. launch field type, exact effective-ID literal, and Djex policy sealing;
6. evaluation limits;
7. input-box object and limits;
8. origin-probe literal;
9. bounded-positive preference;
10. quotient applicable-domain object, literal, width/cardinality caps, and
    Djex limits;
11. applicable-domain preference;
12. counterexample simplification;
13. deferred opening;
14. scoped-v2 usable-work object, duration cap, and Djex budget admission; and
15. the scalar-v5 or nominal pair-v5 contract.

No new Leant configuration error class is introduced. Type, missing,
unexpected, value, cap, and `LengthRankingConfigurationExecutionRejected`
diagnostics remain the existing closed vocabulary and precedence.

## Deferred and scoped runtime

Loading and activation remain pure. V21/v22 preserve v19/v20's deferred state
machine: candidate preparation, MRU replay, quotient applicable-domain replay,
origin replay, and simplification run before a worker is demanded. An all-pure
batch opens no source descriptor, invokes no access checker, stages no image,
and starts no worker. The first live miss opens at most one lexical worker for
the remaining suffix.

The owner-thread-affine scoped-v2 deadline still encloses bounded staging,
both access observations, readiness, and live queries, with cooperative Leant
checkpoints between bounded phases. Fresh established cleanup/final-readiness
windows retain their prior semantics. Any structured setup, access, staging,
session, query, replay, association, or deadline failure activates the same
batch-wide original-order atomic fallback: eligible candidates become
`Unassessed`, preparation refusals remain in source order, and no partial
ranking or evidence escapes.

Djex opens the source once with no-follow and nonblocking discipline. After
regular-file and execute-mode shape admission it performs
`faccessat2(fd, "", X_OK, AT_EMPTY_PATH | AT_EACCESS)`, copies each bounded
chunk once into SHA-256 and a private memfd, checks metadata and the optional
pin, sets the memfd to fixed `0500`, seals and verifies it, then performs the
same access check again on the same source descriptor immediately before child
allocation. Only the sealed descriptor reaches `execveat(AT_EMPTY_PATH)`.
There is no pathname or older-strategy fallback.

## Failure and presentation boundary

Djex maps effective-access denial to
`LengthSMTLibLiveSessionExecutableRejected`. A missing syscall, `ENOSYS`,
fixed-flag `EINVAL`, or another closed checker failure maps to
`LengthSMTLibLiveSessionLaunchFailed`; Leant exposes either through the
existing `LengthRankingLiveSessionFailed` path. Cleanup incompleteness remains
separate. Paths, credentials, ACL entries, modes, mount details, descriptors,
errno values, digests, staged bytes, and child output are never rendered.

The established pinned/unpinned activation line remains unchanged. V21/v22
add one classifier-derived startup line:

```text
Effective-ID executable-access descriptor launch selected; the opened source must pass Linux faccessat2 X_OK under effective filesystem credentials before copying and again immediately before child allocation; any configured digest is checked against the sealed staged main-image bytes.
```

It describes the selected policy, not completed IO or a successful match.
Disabled assessment is silent. Candidate, quotient-domain, counterexample, and
bounded-positive notes remain byte-for-byte behavioral presentations and make
no executable-access claim.

## Authority and identity

The two source checks are point-in-time VFS execute-access observations under
the caller's then-current effective filesystem credentials. They cover
ordinary DAC, applicable POSIX ACLs, source-mount `noexec`, and inode
permission hooks. They are not a reservation: credentials, mode, ACL, mount,
inode, or policy can change between or after them. The actual executable is a
different sealed memfd with launcher-owned mode `0500`.

This profile does not copy or attest source ownership, group, ACLs, set-id
bits, file capabilities, extended attributes, security labels, IMA state, or
mount identity. It is not a full source `exec`/`bprm`/LSM/IMA/binfmt check and
does not bind an ELF or script interpreter, loader, shared library, external
configuration, solver semantics, or status. The primary Linux semantics are
documented by [`access(2)`](https://man7.org/linux/man-pages/man2/access.2.html),
[`execveat(2)`](https://man7.org/linux/man-pages/man2/execveat.2.html), and the
kernel's [`do_faccessat`](https://github.com/torvalds/linux/blob/v6.17/fs/open.c#L391-L547)
and [`inode_permission`](https://github.com/torvalds/linux/blob/v6.17/fs/namei.c#L317-L341)
paths.

Linux 6.14's separate `AT_EXECVE_CHECK` interface is intentionally not used
under this v1 profile. Its kernel documentation is in
[`check_exec`](https://docs.kernel.org/userspace-api/check_exec.html). A future
adoption would require a new Leant launch literal/version pair and a new Djex
strategy/identity; it must not vary silently by host kernel.

V21/v22 select Djex's domain-separated effective-ID execution-policy, process,
ready-worker, and scoped scalar/pair run identities. The v1--v20 identities
remain literal. The v19/v20 quotient query and receipt identities are retained:
operational source access is neither behavioral evidence nor part of the
quotient extraction authority. Mutable descriptors, credentials, errno values,
thread IDs, and post-observation pathname state do not become evidence.

Djex's exact lower-level lifecycle, identity tags, failure mapping, kernel
references, and exclusions are recorded in the
[effective-ID descriptor-bound Z3 launch report](../../lib/Djex/docs/reports/2026-08-15-effective-id-descriptor-bound-z3-launch.md).

## Characterization

The focused Leant matrix pins:

- exact v21/v22 roots, field identities, literal, caps, demand order, and
  v23 unsupported sentinel;
- v1--v20 schema closure and unchanged launch classifiers;
- public maker and policy/integration projections, including disabled-mode
  `Nothing` without forcing a contract;
- pure decoding, activation, and an all-pure deferred batch with zero source,
  checker, or worker IO;
- healthy scalar and pair live parity, compact ordinals, and retained quotient
  assessments/presentation;
- first- and second-check denial, check unavailable, checker failure, pin
  mismatch, invalid image, unsupported platform, deadline, cancellation, and
  session failure with original-order atomic reset;
- no fallback to the v17/v18 descriptor strategy or the pathname strategy; and
- the startup policy line without a premature access or digest-match claim.
