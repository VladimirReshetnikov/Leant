# Single ownership of Length ranking policy

Date: 2026-08-13

## Outcome

Leant no longer retains a second generic `LengthRankingConfiguration` beside
its reusable `LengthRankingPolicy`. The policy is now the sole validated owner
of Djex execution and evaluation authority. A `LeanLengthContract` remains a
separate passive assertion supplied to each policy runner.

The version-1 JSON format and Main's compatibility behavior are unchanged. The
file boundary retains its validated policy strictly beside the decoded fixed
contract lazily in opaque `DisabledLengthRankingConfiguration`. Explicit
activation checks only the policy's closed digest-expectation-presence
classifier and releases the pair to the package-private Integration boundary.
The private configured mode keeps that exact fixed pair together for the
process lifetime and invokes `assessVerifiedLengthCandidatesWithPolicy`.

Deleted authority and adapters are:

- `LengthRankingConfigurationSource`;
- `LengthRankingConfiguration`;
- `mkLengthRankingConfiguration`;
- the validated-components configuration bridge and configuration digest
  classifier; and
- the configured ranking and post-verification runners.

`lengthRankingPolicyFromValidatedComponents` remains the total internal bridge
for the file decoder's already validated Djex values, and
`lengthRankingPolicyExecutableDigestExpectation` is the sole byte-free pin
classifier.

## Demand and failure order

The representation change preserves the former demand boundary:

- the disabled file owner is strict in `LengthRankingPolicy` and lazy in
  `LeanLengthContract`;
- the private configured integration mode is likewise strict in policy and
  lazy in contract;
- `RequirePinnedExecutable` classifies the policy before returning and never
  evaluates the contract;
- `PermitUnpinnedExecutable` performs no contract work or IO;
- file decoding remains format, version, exact root schema, execution,
  evaluation, then contract; and
- ranking still productively admits the maximum candidate count before
  traversing the contract or candidate payloads.

No process is launched by construction, decoding, acquisition, or activation.
Every eligible batch still opens a fresh lexical Djex worker. Returned ranking
failures, exception propagation, occurrence-permutation sealing, stable
counterexample demotion, and atomic fallback are unchanged.

## Compatibility and trust limits

There is no file-schema, fingerprint, SMT-LIB wire, Main option, startup
precedence, default-path, or default-output change. Main still loads one
explicit version-1 contract once and applies it to every later verified batch.
The lower policy API can reuse one policy with genuinely request-owned
contracts, but Main does not yet have a request-owned contract source and does
not infer one from a Lean goal.

The activation result is an internal compatibility pair, not a proof that the
contract is true, that an expected digest matched, or that the eventual process
is Z3. `LengthAssessmentMode` remains opaque and offers no public policy,
contract, path, or digest-byte projection.

## Validation

The focused regressions cover:

- fixed execution-before-evaluation validation and file decode precedence;
- one reusable policy ranked with two different contracts;
- parity between the activated version-1 pair and direct execution with its
  decoded contract;
- require-pinned rejection and both successful activation branches without
  evaluating a poisoned contract or launching a process;
- maximum-plus-one post-verification rejection with both a poisoned contract
  and poisoned candidate elements; and
- the existing disabled identity, integration, live ranking, occurrence seal,
  presentation, fallback, and cleanup behavior.

The full build, unit suite, repository check, and whitespace check are run for
this checkpoint. The maintained walkthrough PDF is rebuilt from its updated
source; prior dated checkpoint reports remain historical snapshots.
