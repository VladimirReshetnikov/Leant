# Explicit finite-list-spine Length ranking integration

Date: 2026-08-12

## Outcome

Leant now composes its existing checked Length/Z3 boundaries at one explicit
startup seam. `Leant.Synth.Length.Integration` owns two opaque modes:

- disabled mode is the historical non-strict identity projection of the exact
  callback-owned `VerificationBatch`;
- configured mode contains one already admitted, decoded, and activated
  version-1 `LengthRankingConfiguration` together with the exact closed
  activation policy which released it.

Main selects configured mode only with
`--length-ranking-config ABSOLUTE-PATH`. No project, home, environment,
executable-relative, or default path is searched. POSIX acquisition is bounded
and final-component no-follow; Windows continues to fail closed. The separate
file-load timeout defaults to 5,000 milliseconds and is admitted in the exact
range 1 through 60,000. It is not Leant's backend command timeout or a solver
query deadline.

## Startup authority and lifetime

Setup has one fixed order:

1. productively admit the exact path and timeout without IO;
2. acquire strict bounded bytes and decode the file;
3. activate its already sealed execution policy.

A digest expectation is required by default. An unpinned execution policy is
released only when `--length-ranking-allow-unpinned` is also present. This
choice merely permits later execution; it does not claim that an expected
digest matches, that the file ultimately executed is attested, or that the
program is Z3. Setup never launches a process.

After activation, Main obtains the startup notice's require-pin versus
permit-unpinned fact from the opaque mode rather than consulting the original
CLI Boolean again. The mode exposes no path, timeout, digest bytes, contract
projection, executable observation, or worker authority through that edge.

The version-1 document intentionally bundles a contract. Main reads it once
and treats the decoded contract as a fixed process-wide assertion for later
synthesis requests. It does not reread or watch the source file, infer a new
contract from a goal, or retarget the contract. The lower-level
policy-plus-contract API remains available for genuinely request-owned
contracts. The CLI compatibility bundle is explicitly the fixed-contract path.

## Per-batch behavior

After Lean callback verification, Main gives the exact opaque
`VerificationBatch DetailedVerificationVariant` to
`assessLengthVerificationBatch`. Configured mode delegates only to
`assessVerifiedLengthCandidatesConfigured`, never to the association-free
compatibility ranker. Package-private occurrence handles therefore survive
preparation, live assessment, stable partitioning, and atomic fallback; a
complete permutation is sealed before Main sees a reordered receipt list.

Only candidates with direct or exact-duplicate-recovered typed Exference
authority and a successful correspondence check against the startup contract
are eligible. Candidates with neither authority and contract-mismatched
candidates remain `Unassessed` with bounded payload-free preparation refusal
classes. They do not acquire graph authority and do not by themselves open a
solver. The default `djinn` engine has no typed graph, so an operator expecting
eligible candidates must select `:set synth-engine exference` or `both`.

Every batch containing an eligible query opens a fresh lexical Djex live
session. No worker, process handle, workspace, transcript, query ordinal, or
rank-2 session authority enters `ReplState`. A reusable process policy and
fixed contract are retained; live process authority is not.

The only ordering change remains stable demotion of candidates carrying an
independently replayed finite-list-spine counterexample. No candidate is
pruned. `sat`, `unsat`, `unknown`, and status-only observations grant no proof
or pruning authority.

After the seal, the presentation layer traverses each whole materialized
`RankedLengthCandidate`. Candidate text and any note therefore come from the
same receipt rather than from detached lists joined by spelling or position.
Only a replayed counterexample gets a bounded subordinate note. It is labeled
model-relative, reports spine lengths, and reduces any provider-backed basis
to the count of assumed laws; the note never projects or displays the
receipt's private provider-name list.

## Failures and presentation

Admission, acquisition, decode, or activation rejection stops startup with a
sanitized closed error. Paths, bytes, OS text, digest material, and Lean names
do not enter that error.

During assessment:

- input or permutation rejection preserves the exact original verification
  batch and exposes neither a suspect ranking nor a sealed proposal;
- a returned structured live failure yields the established original-order,
  all-`Unassessed` ranking, seals that identity order, and emits one sanitized
  warning;
- synchronous and asynchronous exceptions retain the ranking layer's existing
  propagation and Djex cleanup behavior rather than becoming presentation
  output.

Rejected input, heuristic status, and the all-`Unassessed` operational
fallback produce no semantic note. A successful counterexample note explains
stable demotion only; it is not pruning, proof, Z3 attestation, provider-law
validation, or a claim about concrete Lean execution.

The disabled path emits no new startup line or batch warning and performs no
configuration or solver IO, so the existing transcript corpus remains the
default contract.

## Validation

The 315-test Leant unit suite now covers:

- exact disabled-mode laziness and identity;
- CLI dependency rules, pin default, explicit unpinned choice, 5,000-ms setup
  default, exact 60,000-ms ceiling, and rejection of overflow-sized numerals;
- admission and load rejection before a poisoned activation policy;
- require-pinned rejection of an acquired unpinned file;
- no solver launch during successful setup;
- full file-to-activation-to-live-to-permutation-seal demotion;
- reusing one mode after corrupting the source file, proving read-once fixed
  configuration;
- a distinct worker event file for a second assessment, proving lexical worker
  ownership rather than a cached process;
- productive maximum-plus-one adapter rejection without a suspect ranking;
- structured live failure with exact original-order sealed fallback.
- exact text/evidence association after reordering, including equal
  occurrences;
- provider-name redaction, provider-independent/conditional wording, no-note
  neutral and fallback branches, and bounded 4,096-bit value presentation.

The no-option golden transcript corpus remains the separate compatibility
check. In the implementation environment it was attempted but could not enter
any transcript because no Lean REPL backend executable was available; every
case stopped at the existing backend-discovery error and no golden was changed.
The disabled identity/no-output property is therefore validated here by the
unit seam, not claimed as a successful golden run.

This remains one narrow `finite-list-spine-length/v1` ranking adapter. It is
not general behavioral constraints, a Lean operational semantics, a proof
certificate path, or permission to infer contracts or trust provider laws.
