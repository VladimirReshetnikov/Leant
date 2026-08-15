# Non-vacuous bounded-positive Length ordering

Date: 2026-08-14

> **Later 2026-08-14 follow-up.** V7/v8 enable both independent preferences.
> Stable non-vacuous positive-affine-domain receipts precede non-vacuous
> explicit-box receipts, then neutral and vacuous assessments, then
> counterexamples. See the
> [positive-affine deferred Length ranking report](2026-08-14-positive-affine-deferred-length-ranking.md).

> **Later 2026-08-14 follow-up.** Directly bounded applicable-domain
> establishment has its own nominal receipt and separate non-vacuous preference.
> This report's builder continues to classify only explicit post-`unsat`
> input-box receipts. Startup v5/v6 enable only this established preference;
> no startup version enables the new one. See the
> [directly bounded applicable-domain report](2026-08-14-directly-bounded-length-applicable-domain.md).

## Outcome

Leant now has a separately enabled soft ordering preference for scalar and
canonical-`Prod` Length candidates which already carry independently checked
finite-input-box evidence. The preference is disabled by default. It is enabled
programmatically with
`enableLengthRankingNonVacuousInputBoxPreference`, by scalar startup
configuration version 5, or by pair startup configuration version 6.

The preference consumes no raw solver result. It runs only after the existing
assessment pipeline has finished successfully and recognizes a bounded-positive
receipt only when its exact applicable-assignment count is greater than zero.
A completed box with zero applicable assignments remains explicitly vacuous and
neutral.

This checkpoint changes no pruning decision and establishes no proof. It is one
explicit user-selected ordering heuristic over callback-verified candidates.

## Exact stable ordering

The enabled rule is a stable trichotomy:

1. `BoundedPositive receipt` or
   `LengthSpinePairBoundedPositive receipt` with
   `applicableAssignmentCount > 0`;
2. every neutral assessment, including heuristic statuses, unassessed
   candidates, preparation refusals, and bounded-positive receipts whose
   applicable count is zero; then
3. independently replayed scalar or pair counterexamples.

Original order is preserved within all three groups. Original candidate indices
also remain unchanged. No candidate is omitted, duplicated, or manufactured.
In particular, the order does not compare:

- inclusive box maxima;
- total or applicable assignment magnitudes beyond the zero/nonzero test;
- provider-independent and assumed-provider-law-relative bases;
- receipt equality or derived `Ord` values; or
- `sat`, `unsat`, and `unknown` statuses.

Without the preference, the historical two-way rule is literal: all
non-counterexamples retain their original relative order and independently
replayed counterexamples move stably to the end. Thus the established public
builders and startup versions 1 through 4 preserve their old ordering.

## Evidence and vacuity boundary

Djex already supplies every authority needed by the classifier. Its opaque
`ValidatedLengthInputBox` and `ValidatedLengthSpinePairInputBox` receipts retain
strict applicable-assignment counts, exposed through
`validatedLengthInputBoxApplicableAssignmentCount` and
`validatedLengthSpinePairInputBoxApplicableAssignmentCount`.

Those receipts can be constructed only after deterministic traversal completes
for the exact sealed problem without finding a violation. The query-owned
wrappers then replay the produced behavioral evidence against the same complete
problem identity before releasing the receipt. The new Leant policy reads only
the existing count projection; it does not add a second verifier, receipt, or
association mechanism.

A positive count means only that at least one assignment inside the configured
finite box met the contract precondition and satisfied the postcondition. It
does not make the finite result universal. A zero count means every checked
assignment missed the precondition, so promoting that receipt would mistake
vacuity for supporting behavior. The zero/nonzero boundary is therefore the
only ordering distinction.

Provider-backed receipts remain conditional on the exact assumed provider laws
recorded by their basis. “Independently checked” describes concrete replay
rather than provider independence. The existing presentation note continues to
show whether the result is provider-independent or conditional without
projecting private provider names.

## Raw Z3 status remains scheduling-only

With the later programmatic checkpoint, the complete per-candidate sequence is:

1. try up to four newest-first batch-local counterexample input vectors;
2. under the newer programmatic policy, optionally try directly bounded
   applicable-domain validation;
3. after an inapplicable result, optionally probe the exact query-owned origin;
4. run the live Z3 query;
5. pass the observation through query-first association and evidence replay;
6. only when no counterexample was released and the status is `unsat`, run the
   separately enabled query-owned finite-box traversal.

`unsat` can therefore decide whether an independent traversal is scheduled, but
it cannot place a candidate in the preferred group. Only the resulting opaque
receipt and its positive applicable count do that. Status-only `sat`, `unsat`,
and `unknown` stay neutral. A traversal-discovered counterexample follows the
ordinary counterexample/MRU path instead of becoming positive evidence.

Positive receipts still never enter the MRU bank. The bank retains only compact
input vectors from exact counterexamples, and a later query must independently
replay any such vector under its own checked problem.

## Policy API

`LengthRankingPolicy` remains opaque. Its private state now retains the ordering
preference independently of execution, evaluation, input-box, and origin-probe
policy. Both established constructors leave it disabled:

- `mkLengthRankingPolicy`; and
- `lengthRankingPolicyFromValidatedComponents`.

The three public derivations are persistent and order independent. For example:

```haskell
let preferredPolicy =
      enableLengthRankingNonVacuousInputBoxPreference
        $ enableLengthRankingOriginProbe
        $ enableLengthRankingInputBoxValidation limits [3] basePolicy

scalar <- assessVerifiedLengthCandidatesWithPolicy
  preferredPolicy scalarContract verificationBatch

pair <- assessVerifiedLengthSpinePairCandidatesWithPolicy
  preferredPolicy pairContract verificationBatch
```

The same opaque process/evaluation policy can drive either domain, but contracts,
queries, assessments, counterexamples, positive receipts, failures, and
presentation remain nominally domain-specific. Enabling the preference without
an input box is inert because no bounded-positive assessment can arise.

## Startup configuration versions 5 and 6

The format remains `leant-live-length-ranking-configuration`. Two versions keep
the domain selection unambiguous:

- `lengthRankingConfigurationFilePositiveOrderingVersion = 5` selects scalar
  ranking and embeds the complete scalar contract v5 grammar;
- `lengthRankingConfigurationFileSpinePairPositiveOrderingVersion = 6` selects
  canonical-`Prod` ranking and embeds the existing pair v5 grammar.

Both repeat the complete operational root of scalar v3 or pair v4 and add one
required field:

```json
"boundedPositiveOrdering": "prefer-non-vacuous"
```

The value is the sole accepted literal. It grants only the ordering preference;
it is not a behavioral observation, contract assertion, validation result, or
solver authority. The fixed new-version validation precedence is:

1. exact root schema;
2. execution admission;
3. execution;
4. evaluation;
5. input-box validation;
6. counterexample probe;
7. bounded-positive ordering; then
8. the scalar or pair contract.

The established scalar-only `decodeLengthRankingConfigurationFile` still
accepts exactly versions 1 through 3 and rejects versions 4 through 6. The
generalized `decodeLengthAssessmentConfigurationFile` delegates every v1--v4
success and diagnostic to the established paths, then admits v5 and v6. Older
versions reject the new root field and retain neutral bounded-positive ordering.

Contract-only format versions 1 through 6 do not change. Ordering is reusable
process policy, not part of a passive behavioral contract. A one-shot scalar or
pair contract therefore inherits the already activated startup policy without
adding another ordering field or contract version.

## Atomic failure and occurrence ownership

The preference is applied only to a fully successful associated assessment.
Any session-open, live-query, query-association, evidence-replay, origin,
finite-box, or post-verification-seal failure retains the established atomic
fallback: every admitted candidate is returned in original order as unassessed,
with only the sanitized failure class, cleanup bit, and optional safe original
index. Synchronous and asynchronous exceptions continue to propagate.

Candidate-local pure preparation refusals remain local and neutral. The enabled
preference neither starts a worker nor changes which candidates are eligible.
It also does not change query counts or the MRU/origin/live/box demand order.

During successful ranking, each assessment stays attached to its exact
caller-owned occurrence handle. Stable partitioning happens before the existing
post-verification permutation seal, and Main renders text and evidence from the
same sealed occurrence. Equal candidate texts or duplicate verified receipts
therefore cannot exchange positive notes when a preferred occurrence moves.

## Identity and version impact

No Djex API or identity version changes are required. The applicable-count
projections and both opaque receipt schemas already exist, so their scalar and
pair verifier tags remain v1. The preference changes none of:

- behavioral domain, inventory, encoding, candidate, or problem fingerprints;
- canonical SMT-LIB query bytes or query fingerprints;
- live protocol, capability, worker, process, or run identity;
- solver observations or independently replayed receipts; or
- counterexample seed-bank contents.

Leant's output order, and consequently interactive `itN` assignment, is
observable. That is why the file behavior uses additive startup versions and
the library behavior requires an explicit builder. A future durable cache of
ranked output would need to retain this Leant policy choice, but the current
lexical ranking path has no such cache.

The resulting preferred receipt is still only positive within its configured
finite box and versioned total finite-spine model, conditional on any assumed
provider laws. It is not a Lean kernel theorem, validation of source execution,
termination, purity, totality, strictness, provider implementations, or Z3
soundness, and it grants no pruning authority.
