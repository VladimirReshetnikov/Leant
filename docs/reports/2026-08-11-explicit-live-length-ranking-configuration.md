# Explicit live Length ranking configuration

Date: 2026-08-11

## Outcome

`Leant.Synth.Length.Configuration` owns the pure configuration boundary in
front of the existing live Length ranking foundation. The reusable
`LengthRankingPolicySource` requires three caller-supplied values:

- explicit `LengthSMTLibExecutionLimits`;
- a complete `LengthSMTLibExecutionConfigSource`, including an absolute Z3
  path, optional exact 32-byte SHA-256 expectation, solver timeout and resource
  limit, host deadline, artifact policy, and bounded response policy;
- an explicit `LengthEvaluationLimitSource`.

`mkLengthRankingPolicy` validates those values into an opaque
`LengthRankingPolicy`. A `LeanLengthContract` is supplied independently to each
`rankVerifiedLengthCandidatesWithPolicy` call. The version-1 configuration-file
grammar remains source-compatible through `LengthRankingConfigurationSource`,
which bundles those same three policy fields with one explicit contract and
seals an opaque `LengthRankingConfiguration` compatibility value.

The module supplies no default source and performs no executable discovery,
path normalization, environment lookup, or configuration inference. A caller
may deliberately choose a Djex default before constructing the source, but
Leant does not choose one on its behalf.

## Validation and authority

`mkLengthRankingPolicy` validates and seals the complete execution policy
first. Only after that succeeds does it validate the replay limits. Raw source
fields remain lazy so an execution rejection cannot force a later replay-limit
source. `mkLengthRankingConfiguration` delegates to the same function and does
not force its later contract when either policy phase rejects, preserving the
established compatibility validation precedence.

Configuration does not validate the behavioral contract in isolation. The
contract remains a caller assertion until the ranking preparation pass checks
it separately with each exact callback-verified candidate, retained structural
origin, provider assumptions, and checked problem. A successful configuration
therefore grants no solver, contract, or candidate authority.

Both the sealed policy and compatibility configuration are opaque and have no
path, digest, execution-policy, replay-policy, or contract projection. Neither
has an `Eq`, `Show`, or `Generic` instance or can contain a process, live
session, or reusable worker. The optional digest is compared by Djex with its
pre-spawn executable-file
observation before launch. It is not executed-image attestation: portable direct
spawn cannot execute the descriptor that was hashed, and the loader and shared
libraries are outside that observation.

## Configured runner and budgets

`rankVerifiedLengthCandidatesWithPolicy` pairs one sealed policy with one
explicit request contract and passes their execution, replay, and contract
values to `rankVerifiedLengthCandidates`. One policy may be reused with
distinct contracts, but each eligible call still opens a fresh lexical live
session. `rankVerifiedLengthCandidatesConfigured` only unwraps the compatible
policy-plus-contract bundle and delegates to that same runner.

For candidate presentation, `assessVerifiedLengthCandidatesConfigured`
unwraps the same opaque bundle while retaining the caller's batch-scoped
occurrence handles. It uses the same package-private rank-2 adapter as the
separate policy/request-contract entry point, validates the exact complete
occurrence permutation, and erases those associations only after the seal
succeeds. The lower-level associated runners and projector now live only in
`Ranking.Internal` and `PostVerification.Internal`; the ordinary ranking and
configuration facades cannot return an unsealed associated value. Callers
therefore do not need a policy or contract projection to connect an explicitly
activated version-1 configuration to the safe presentation boundary.

Both paths preserve productive input admission, complete pre-sealing, serial
query order, stable counterexample demotion, atomic all-`Unassessed` fallback,
and exception behavior. Neither caches a worker between calls.

The private lifecycle bounds and explicit per-query host deadline remain
separate. The wrapper adds no batch-wide or command-wide deadline and does not
derive one from Leant's synthesis or backend timeouts. Main and the REPL still
do not construct or invoke this configuration, so live Length ranking remains
disabled unless a future integration supplies the complete explicit policy.
