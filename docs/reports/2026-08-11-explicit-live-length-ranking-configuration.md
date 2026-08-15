# Explicit live Length ranking configuration

> **2026-08-14 follow-up.** `LengthRankingPolicy` now privately retains an
> optional finite-box orchestration policy. `mkLengthRankingPolicy` and the
> version-1 file path remain disabled; callers can opt in with
> `enableLengthRankingInputBoxValidation`, and configuration version 2 supplies
> the same explicit policy through its required `inputBoxValidation` object.
> See the
> [unsat-triggered bounded validation report](2026-08-14-unsat-triggered-length-input-box-validation.md).
>
> **Later 2026-08-14 follow-up.** `LengthRankingPolicy` also retains an
> independent optional origin-probe policy. `mkLengthRankingPolicy` leaves it
> disabled, `enableLengthRankingOriginProbe` enables it explicitly, and startup
> configuration version 3 composes it with version 2's exact finite box. The
> runtime order is four-entry MRU, query-owned origin, then live Z3. See the
> [origin-probe orchestration report](2026-08-14-length-origin-probe-orchestration.md).

Date: 2026-08-11

> **Later 2026-08-14 follow-up.** `LengthRankingPolicy` now also retains an
> explicitly selected direct-v1 or positive-affine-v1 applicable-domain rule,
> optional simplification, and eager or deferred opening. Startup v7/v8 select
> positive-affine validation, simplification, and deferred opening; v1--v6 keep
> the eager behavior recorded below. See the
> [positive-affine deferred Length ranking report](2026-08-14-positive-affine-deferred-length-ranking.md).

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
grammar remains unchanged; additive version 2 enables the finite box without
changing that version-1 path, and additive version 3 retains the box while
enabling the pre-live query-owned origin probe. Its compatibility path uses
`LengthRankingConfigurationSource`, which nests that same
`LengthRankingPolicySource` beside one explicit contract and seals an opaque
`LengthRankingConfiguration` compatibility value. There is one source
vocabulary and one validation path for reusable and bundled policy.

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

`lengthRankingConfigurationFromValidatedComponents` is the total one-way bridge
for owners which already possess Djex's opaque `LengthSMTLibExecutionConfig`
and `LengthEvaluationLimits`. It stores those same sealed authorities in the
Leant policy without reconstructing sources or repeating validation, while the
contract remains lazy. The bounded file decoder uses this bridge after its
execution and evaluation phases have each succeeded.

Configuration does not validate the behavioral contract in isolation. The
contract remains a caller assertion until the ranking preparation pass checks
it separately with each exact callback-verified candidate, retained structural
origin, provider assumptions, and checked problem. A successful configuration
therefore grants no solver, contract, or candidate authority.

Both the sealed policy and compatibility configuration are opaque and have no
path, digest-byte, execution-policy, replay-policy, or contract projection.
The compatibility configuration exposes only a closed absent/present
classification of the digest expectation already retained by its sealed Djex
execution policy. That classification cannot recover the expected bytes or
path and makes no claim about a later match. Neither opaque value has an `Eq`,
`Show`, or `Generic` instance or can contain a process, live session, or
reusable worker. The optional digest is compared by Djex with its pre-spawn
executable-file observation before launch. It is not executed-image
attestation: portable direct spawn cannot execute the descriptor that was
hashed, and the loader and shared libraries are outside that observation.

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
activated version-1, version-2, or version-3 configuration to the safe
presentation boundary.

Both paths preserve productive input admission, complete pre-sealing, serial
query order, stable counterexample demotion, atomic all-`Unassessed` fallback,
and exception behavior. With the origin policy enabled, every candidate tries
the four-entry MRU bank, then Djex's query-owned all-zero replay, then its live
query. The lexical worker has already opened and passed its capability probe,
so an origin hit avoids only that query transaction and ordinal. The hit
follows the existing counterexample demotion/MRU path; a
miss has no authority; an evaluation or association rejection is indexed and
atomically fails the batch. An enabled box policy still uses only an actual
live `unsat` to trigger Djex's independent bounded traversal; a resulting
counterexample follows the same demotion/MRU path, while positive completion
is neutral and does not seed. Neither policy caches a worker between calls.

The private lifecycle bounds and explicit per-query host deadline remain
separate. The wrapper adds no batch-wide or command-wide deadline and does not
derive one from Leant's synthesis or backend timeouts. Main now constructs this
configuration only through an explicit bounded startup file. That CLI
compatibility path fixes the decoded contract for the process; the separate
policy API above still accepts a request-owned contract per invocation.
