# Explicit live Length ranking configuration

Date: 2026-08-11

## Outcome

`Leant.Synth.Length.Configuration` now owns the pure configuration boundary in
front of the existing live Length ranking foundation. Its raw source requires
four caller-supplied values:

- explicit `LengthSMTLibExecutionLimits`;
- a complete `LengthSMTLibExecutionConfigSource`, including an absolute Z3
  path, optional exact 32-byte SHA-256 expectation, solver timeout and resource
  limit, host deadline, artifact policy, and bounded response policy;
- an explicit `LengthEvaluationLimitSource`; and
- an explicit `LeanLengthContract`.

The module supplies no default source and performs no executable discovery,
path normalization, environment lookup, or configuration inference. A caller
may deliberately choose a Djex default before constructing the source, but
Leant does not choose one on its behalf.

## Validation and authority

`mkLengthRankingConfiguration` validates and seals the complete execution
policy first. Only after that succeeds does it validate the replay limits. Raw
source fields remain lazy so an execution rejection cannot force a later
replay-limit source or contract and change that precedence.

Configuration does not validate the behavioral contract in isolation. The
contract remains a caller assertion until the ranking preparation pass checks
it separately with each exact callback-verified candidate, retained structural
origin, provider assumptions, and checked problem. A successful configuration
therefore grants no solver, contract, or candidate authority.

The sealed configuration is opaque and has no path, digest, execution-policy,
replay-policy, or contract projection. It has no `Eq`, `Show`, or `Generic`
instance and cannot contain a process, live session, or reusable worker. The
optional digest is compared by Djex with its pre-spawn executable-file
observation before launch. It is not executed-image attestation: portable direct
spawn cannot execute the descriptor that was hashed, and the loader and shared
libraries are outside that observation.

## Configured runner and budgets

`rankVerifiedLengthCandidatesConfigured` is only an opaque-policy form of the
existing call. It passes the sealed execution policy, replay limits, and
contract to `rankVerifiedLengthCandidates`, preserving the same productive
input admission, complete pre-sealing, single lexical live session, serial
query order, stable counterexample demotion, atomic all-`Unassessed` fallback,
and exception behavior. It does not cache a worker between calls.

The private lifecycle bounds and explicit per-query host deadline remain
separate. The wrapper adds no batch-wide or command-wide deadline and does not
derive one from Leant's synthesis or backend timeouts. Main and the REPL still
do not construct or invoke this configuration, so live Length ranking remains
disabled unless a future integration supplies the complete explicit policy.
