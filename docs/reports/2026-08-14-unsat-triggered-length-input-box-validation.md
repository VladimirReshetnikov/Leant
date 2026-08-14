# Unsat-triggered bounded Length input-box validation

Date: 2026-08-14

## Outcome

Leant now has an explicit opt-in path which can turn a live Length query's
`unsat` status into a request for independent finite-domain checking. The status
is only a scheduling trigger. Djex's solver-independent evaluator exhausts one
exact, caller-selected Cartesian box against the checked problem retained by
the sealed query; no solver status becomes behavioral evidence.

The public lower-level entrance is
`rankVerifiedLengthCandidatesWithInputBoxValidation`. Reusable policy callers
can derive an enabled policy with
`enableLengthRankingInputBoxValidation :: LengthInputBoxLimits -> [Natural] ->
LengthRankingPolicy -> LengthRankingPolicy`. Both retain the established live
execution and evaluation policies and add only checked traversal limits plus
source-ordered inclusive maxima. The historical entrances and every policy
created by `mkLengthRankingPolicy` remain input-box-disabled.

## Exact configuration opt-in

The startup configuration decoder now accepts two exact root versions under the
unchanged format `leant-live-length-ranking-configuration`:

- version 1 is the literal compatibility grammar and retains the disabled
  ranking behavior; and
- version 2 requires one additional `inputBoxValidation` object and enables the
  bounded path.

`lengthRankingConfigurationFileVersion` deliberately remains `1`.
`lengthRankingConfigurationFileInputBoxVersion` names the additive value `2`.
Version 1 rejects the new root field as unexpected, while version 2 rejects its
absence. The version-2 root fields are exactly `format`, `version`,
`executionAdmission`, `execution`, `evaluation`, `inputBoxValidation`, and
`contract`. The `inputBoxValidation` field's value is exactly:

```json
{
  "inclusiveInputMaximums": [2, 3],
  "maximumAssignments": 12
}
```

`inclusiveInputMaximums` is source ordered and supplies one inclusive Natural
maximum per compact modeled input. Its finite width, from zero through eight,
is also the sealed maximum-input admission limit; there is no second width
field which could disagree with it. `maximumAssignments` is a Natural capped at
65,536. These are caller choices, not Leant-selected defaults.

The decoder preserves fixed precedence: exact root shape, execution admission,
execution policy, evaluation limits, input-box object, then contract. Within the
box object it checks the array width before decoding elements left-to-right,
then decodes the assignment cap and seals `LengthInputBoxLimits`. Candidate
arity, each maximum under the configured assignment-value bit limit, and the
Cartesian product under the assignment cap remain exact-problem runtime checks;
they are not guessed from the passive JSON contract.

## Runtime order and outcomes

Eligible candidates still traverse serially in original order. Before a live
call, each candidate tries the established newest-first four-entry MRU bank.
A seed hit is already an independently replayed counterexample, avoids the live
call, and therefore never reaches input-box validation.

After a live call, the established query-first association and evidence replay
gate runs before status handling. A validated live counterexample remains an
ordinary `Counterexample`. If no counterexample was retained, status handling
is:

| Live status | Input-box policy | Assessment |
| --- | --- | --- |
| `sat` | either | the existing neutral `Heuristic` result |
| `unknown` | either | the existing neutral `Heuristic` result |
| `unsat` | disabled | the existing neutral `Heuristic` result |
| `unsat` | enabled | run exact query-owned finite-box validation |

The enabled validation has three semantic outcomes:

- The first violated assignment returns the ordinary exact-problem
  `ValidatedLengthCounterexample` and becomes `Counterexample`. It is stably
  demoted and its exact input vector is inserted or promoted in the MRU bank.
- Complete traversal returns `BoundedPositive !ValidatedLengthInputBox`. This
  assessment stays in the neutral stable partition and contributes no MRU seed.
- A traversal rejection becomes
  `LengthRankingInputBoxValidationFailed !LengthInputBoxValidationError` at the
  candidate's safe original index. An association rejection maps to the
  established evidence-replay mismatch class. Either is an operational batch
  failure: every partial assessment and reordering is discarded and the whole
  admitted batch returns in original order as `Unassessed`. Exceptions continue
  to propagate.

The positive assessment does not promote a candidate ahead of another neutral
assessment. It records bounded information for presentation while preserving
the successful stable ordering rule: only counterexamples move behind the
other candidates, and no candidate is pruned.

## Positive receipt and presentation

`BoundedPositive` carries Djex's opaque `ValidatedLengthInputBox`. The receipt
was created only after deterministic traversal of every assignment in the
exact box and exact replay against the query-owned behavioral problem. It
retains the versioned verifier semantics, inclusive maxima, total checked
assignment count, precondition-applicable assignment count, and explicit
finite-spine/provider-law basis.

`renderLengthInputBoxValidationNote` produces the associated terminal note from
the same ranked receipt as the candidate text. It names the claim as
independently checked and bounded/model-relative, shows the inclusive maxima and
both counts, reduces provider names to a count, and explicitly calls out a zero
applicable count as vacuous within the box. The existing 384-character terminal
ceiling and bounded Natural rendering apply. The note never mentions `unsat`,
because the solver status is not part of the receipt's authority.

The result establishes only the checked finite box in Djex's versioned total
finite-spine model, conditional on any named assumed provider laws used by the
candidate. It is not a universal proof, a Lean value-level execution result, a
kernel theorem, source-language totality, provider-implementation validation,
dictionary evidence, pruning permission, or a certificate that Z3 or its
encoding is sound.

## MRU and identity compatibility

The MRU bank continues to store only source-ordered `[Natural]` vectors. An
input-box-discovered counterexample enters it because a later query can freshly
replay those values under its own checked problem. A positive receipt, solver
status, query, provider basis, or verdict never enters the bank.

Version 1 retains its exact root fields, accepted grammar, decode order,
disabled policy, and ranking behavior. Version 2 is an additive Leant configuration
grammar; it does not change the contract grammar or any Djex contract,
provider-inventory, semantic-inventory, session-policy, candidate,
concrete-problem, SMT-query, protocol, response, execution, process, worker,
query-run, or live-observation identity or schema. It does not change the
canonical SMT-LIB bytes for a query.

Finite-box traversal is pure and creates no solver query, transcript, ordinal,
or run identity. The preceding live `unsat` call retains the identity it already
earned under the unchanged live construction rules. A seed hit can still avoid
that call entirely, so later actual live ordinals remain compact exactly as in
the existing MRU policy.
