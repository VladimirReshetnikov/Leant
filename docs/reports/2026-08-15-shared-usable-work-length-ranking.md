# Shared usable-work budget for Length ranking

Date: 2026-08-15

## Outcome

Leant can now place one admitted scalar or canonical-`Prod` Length ranking
batch beneath a validated Djex shared usable-work deadline. The additive public
policy builder is:

```haskell
enableLengthRankingUsableWorkBudget
  :: LengthSMTLibLiveUsableWorkBudget
  -> LengthRankingPolicy
  -> LengthRankingPolicy
```

The builder is pure. It accepts only Djex's already validated opaque duration,
reads no clock, performs no IO, and is last-wins when applied more than once.
The absolute monotonic deadline is captured independently for every admitted
ranking call. The policy remains reusable and retains no process, session,
clock observation, candidate, contract, solver status, or evidence.

Startup scalar version 9 and product version 10 select the same policy through
an exact required file object. They retain the complete v7/v8 behavioral
bundle—finite input box, origin probe, positive-affine applicable domain, both
non-vacuous preferences, counterexample simplification, and deferred session
opening—and add only shared usable-work ownership.

## Programmatic construction

A programmatic caller first validates the Djex source, then derives a policy:

```haskell
budget <- either (fail . show) pure $
  mkLengthSMTLibLiveUsableWorkBudget
    LengthSMTLibLiveUsableWorkBudgetSource
      { lengthSMTLibLiveUsableWorkBudgetSourceMilliseconds = 30000 }

let budgetedPolicy =
      enableLengthRankingUsableWorkBudget budget advancedPolicy

scalarResult <- assessVerifiedLengthCandidatesWithPolicy
  budgetedPolicy scalarContract verificationBatch

pairResult <- assessVerifiedLengthSpinePairCandidatesWithPolicy
  budgetedPolicy pairContract verificationBatch
```

`mkLengthSMTLibLiveUsableWorkBudget` rejects nonpositive durations and values
which cannot be represented by the host microsecond wait or monotonic
nanosecond delta. Leant does not duplicate that validation in its builder. The
65,000-ms ceiling described below belongs to the versioned file boundary; a
programmatic caller may supply any value which Djex has validated.

The same `LengthRankingPolicy` can be used by the two domain-specific
assessors because the duration contains no behavioral authority. Scalar and
product contracts, queries, observations, evidence, assessments, and
presentation remain nominally separate.

## Exact owned interval

The input list is productively admitted against Djex's fixed 64-query session
maximum before a deadline is captured. Maximum-plus-one therefore returns the
established `LengthRankingInputError` without sampling a clock or forcing
candidate preparation.

After successful admission, the one rank-N owner covers all ranking-owned work:

1. complete checked-handoff and canonical-query preparation;
2. each candidate's newest-first four-entry MRU replay bank;
3. applicable-domain validation, origin replay, and counterexample
   simplification selected by the policy;
4. eager opening, or deferred opening at the first live miss;
5. every scalar or product live transaction, independent observation replay,
   and optional post-`unsat` finite-box traversal;
6. stable evidence ordering, projection through the occurrence association,
   and the final ranking-owned result spine.

The final owned result is forced before the deadline callback returns. Lazy
ranking transforms, assessment constructors, simplification metadata, or
failure structure therefore cannot escape the normal-return check. Caller-
owned verified receipts and occurrence associations keep their established
WHNF boundary and do not acquire a new `NFData` requirement.

An empty, all-ineligible, or all-pure deferred batch opens no Z3 process, but it
still executes beneath the owner and reaches the final deadline check. This is
what makes the policy a usable-work budget rather than merely a shared solver-
transaction timeout.

## Live deadline selection and finalization

When live work is needed, Leant passes the generative token to
`withLengthSMTLibLiveSessionUnderDeadline`. Djex selects the minimum of the
shared absolute deadline and the established fresh local opener deadline. Each
scalar or product query similarly selects the minimum of the same shared
deadline and its fresh configured host deadline. The shared deadline wins an
exact tie. Waiting for the serial gate and the complete transaction/replay/run-
identity boundary use that effective deadline.

This does not install an asynchronous watchdog around arbitrary Leant code.
Blocking callback IO and nonterminating pure computation are not interrupted;
expiry is observed by the next controlled operation or when a callback returns
normally. Synchronous and asynchronous exceptions remain authoritative and
retain Djex's durable-cleanup-and-rethrow behavior.

Djex's post-session final-readiness observation and durable cleanup use fresh
private operational windows, not the shared deadline. Leant deliberately owns
the whole ranking with the general outer deadline callback, however. When a
nested live session returns, that outer callback returns only after the nested
fresh-window finalization has completed. The owner's final check can therefore
truthfully report that the shared deadline elapsed during final readiness or
cleanup. Startup v9/v10 choose this broader observation boundary so pre-session
pure work and all-pure batches cannot escape the same budget.

## Failure and atomic fallback

Budget-owner expiry maps through the existing sanitized live-session deadline
class. The resulting scalar or product ranking failure has safe original index
`Nothing`. If an inner session already recorded cleanup incompleteness, the
outer fallback preserves it by combining that bit with the owner failure.

Every admitted candidate is returned in original order with public assessment
`Unassessed`; earlier heuristic statuses, independently validated evidence,
counterexample simplification metadata, and stable reordering are discarded.
When complete preparation had already classified a candidate-local refusal,
that existing bounded payload-free refusal class remains inspectable while its
legacy assessment projection is still `Unassessed`. If the deadline owner
could not invoke preparation, no refusal is invented.

A shorter fresh per-query deadline can still fail before the shared budget.
That existing query failure retains its safe candidate index when the shared
owner is still live. Once the shared deadline itself is expired at the session
or outer callback boundary, the batch-wide session failure with index
`Nothing` is authoritative. Exceptions propagate rather than becoming an
atomic fallback value.

## Startup versions 9 and 10

The new constants are exact:

```haskell
lengthRankingConfigurationFileUsableWorkBudgetVersion == 9
lengthRankingConfigurationFileSpinePairUsableWorkBudgetVersion == 10
```

Both roots add this required object after `liveSessionOpening` and before
`contract`:

```json
{
  "usableWorkBudget": {
    "strategy": "shared-usable-work-deadline-v1",
    "milliseconds": 30000
  }
}
```

The object has exactly those two fields. JSON member order is immaterial, but
semantic validation demands the exact strategy first, then the integer
duration. The duration must be positive and is capped inclusively at 65,000 ms
before the decoder delegates to Djex's representability validator.

Closed diagnostics identify this boundary with
`LengthRankingConfigurationUsableWorkBudgetObject` and the exact field
identities `LengthRankingConfigurationUsableWorkBudgetField`,
`LengthRankingConfigurationUsableWorkBudgetStrategyField`, and
`LengthRankingConfigurationUsableWorkBudgetMillisecondsField`. A wrong
strategy is the existing field-value rejection for the strategy identity; an
over-cap integer is the existing policy-limit failure for the milliseconds
identity. Djex validation failures are wrapped only by
`LengthRankingConfigurationUsableWorkBudgetRejected`. No unknown key text or
raw clock value enters an error.

The complete v9/v10 semantic validation order is:

1. bounded JSON and root-object admission;
2. `format` and `version`;
3. exact v9/v10 root-field admission;
4. `executionAdmission`, `execution`, and `evaluation`;
5. `inputBoxValidation`, `counterexampleProbe`, and
   `boundedPositiveOrdering`;
6. `applicableDomainValidation`, `applicableDomainOrdering`, and
   `counterexampleSimplification`;
7. `liveSessionOpening`;
8. `usableWorkBudget`, including its exact object fields, strategy,
   integer/cap, and Djex
   validation; and
9. the scalar-v5 contract for v9 or nominal pair-v5 contract for v10.

An earlier operational or budget failure therefore cannot be hidden by a later
malformed contract. The generalized decoder attempts v9/v10 only after the
complete literal v1--v8 chain has returned its closed unsupported-version
sentinel. Every v1--v8 accepted document, unknown-field diagnostic, validation
precedence, policy branch, and domain selection remains exact.

The root README contains complete scalar-v9 and product-v10 documents. As with
earlier versions, an absent executable digest expectation requires the
separate explicit `--length-ranking-allow-unpinned` activation decision.
Loading and activation alone never capture a usable-work deadline or launch a
solver.

## Identity and authority boundary

Leant's version number selects a closed file schema; it is not a behavioral
certificate or a detached cache key. The opaque policy merely retains the
validated duration. At runtime Djex gives budgeted ready workers an additive
shared-deadline identity envelope and gives scalar and product query runs
distinct budgeted schemas and fingerprint roles. Those identities bind the
requested duration, captured shared deadline, minimum-selection rule,
shared-on-tie behavior, effective cause, and callback/finalizer policy.

The disabled branch dispatches literally through the historical runners.
Startup v1--v8 therefore preserve their existing ready-worker and scalar or
product run identities without an appended shared-deadline field. V9/v10 do not
change canonical query or protocol bytes, ordinal allocation, execution-policy
identity, or public observation association.

The deadline proves only association with an owned monotonic timing policy. It
does not attest the executed Z3 image, validate solver soundness, make `unsat`
a proof, establish a contract, or grant pruning authority. Live status remains
`HeuristicRankingOnly`. Optional counterexample evidence still requires exact
query association and independent scalar or product replay, and every positive
receipt remains bounded and model/provider-relative. Budget expiry itself
creates no evidence and adds no presentation note.
