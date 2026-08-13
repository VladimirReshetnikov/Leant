# Contract-only v5 positive-literal quotient

Date: 2026-08-13

## Outcome

Leant's command-local Length contract now accepts version 5 under the unchanged
format `leant-finite-list-spine-length-contract`. Version 5 retains version 3's
required ordered target-role vector and version 4's required explicit
candidate-case field, retains positive-literal Natural modulo, and adds exactly
one expression form:

```json
["quotient", positiveLiteral, expression]
```

The result is Natural floor quotient. The form is accepted in preconditions,
postconditions, and provider transfers. It is not accepted by startup
configuration or contract-only versions 1 through 4.

Version 5 deliberately separates arithmetic vocabulary from case authority.
Its required `candidateCasePolicy` accepts exactly:

- `"cases-rejected"`, preserving the singleton/ordinal-zero renderer rule; or
- `"exact-spine-zero-step-v1"`, selecting the callback-accepted retained typed
  renderer ordinal and enabling Djex's checked recursive zero/step case model.

Version 4 remains unchanged and accepts only the exact policy. Version 3 and
older remain implicitly case-rejecting and reject the policy field.

## Example

```json
{
  "format": "leant-finite-list-spine-length-contract",
  "version": 5,
  "contract": {
    "spine": {"family": "List", "zero": "List.nil", "step": "List.cons"},
    "targetArgumentRoles": ["unobserved-target", "observed-spine"],
    "candidateCasePolicy": "cases-rejected",
    "precondition": ["truth", true],
    "postcondition": [
      "equal",
      ["result"],
      ["quotient", 2, ["input", 0]]
    ],
    "providerLaws": [
      {
        "name": "Demo.mapList",
        "argumentRoles": ["unobserved", "spine"],
        "transfer": ["argument", 1]
      }
    ]
  }
}
```

The document still contains no executable, pin, solver, artifact, response,
evaluation, or replay policy. It is decoded once and remains owned by one
explicit synthesis command.

## Bounded decoding and precedence

The divisor is decoded before the child expression. It must be a positive
Natural no wider than the established 256-bit literal ceiling. Zero has its
own closed configuration error,
`LengthRankingConfigurationQuotientDivisorZero`; negative or non-integer
values use the established expected-Natural error; an oversized divisor uses
the established literal-bit limit. All three win before a malformed or cyclic
child is inspected.

Object admission remains productive and ordered. Version 5 requires
`targetArgumentRoles` before `candidateCasePolicy`, and both precede formula
parsing. Consequently a missing or invalid role wins over an invalid policy
and poisoned formula, while an invalid policy wins over that formula. Provider
transfer failures keep their exact indexed syntax phase.

The version dispatcher exports `lengthContractFileQuotientVersion = 5` and
uses the dedicated `decodeLeanLengthContractValueV5` entrance. The v1 startup
decoder and contract-only v1--v4 entrances are not widened. Their accepted
objects, diagnostics, ASTs, and downstream identities therefore retain their
earlier behavior.

## QF_LIA lowering and replay

Leant preserves Djex's public `LengthQuotient divisor expression` node rather
than interpreting or rewriting it. After checked handoff and normalization,
Djex lowers every surviving `e quot k` occurrence to deterministic private
quotient and remainder witnesses satisfying:

```text
e = k*q + r
q >= 0
r >= 0
r <= k - 1
```

The expression projects `q`; modulo projects `r`. Mixed modulo/quotient
occurrences share one deterministic Euclidean-witness order. Queries remain in
QF_LIA and emit no SMT-LIB `div` or `mod`. Witnesses are absent from
`get-value` requests and user presentation. Independent concrete replay
recomputes Natural floor quotient from the original bounded inputs and checked
candidate result.

Leant's exhaustive query-refusal classifier now maps Djex's distinct
`LengthSMTLibQuotientDivisorZero` to the existing payload-free
`query-construction-rejected` class. The established modulo classification and
all public preparation codes are unchanged.

## Production coverage

The focused integration tests exercise both version-5 policy choices against
real Exference output:

- a higher-order map candidate with target roles
  `[unobserved-target, observed-spine]` uses `cases-rejected`; its quotient
  postcondition seals to QF_LIA, emits private quotient/remainder witnesses,
  and independently replays input 3/result 3;
- a synthesized recursive `List Nat -> List Nat` rebuild case is rejected by
  a version-5 `cases-rejected` contract's singleton rule, while the same
  quotient condition under `exact-spine-zero-step-v1` retains its accepted
  renderer ordinal, seals, and replays input 3/result 3; and
- fake-Z3 assessment loads version-5 documents once, mutates their source files
  after acquisition, reuses the decoded requests, and interleaves startup,
  version-3, version-4, and both version-5 policy requests. Neither quotient
  grammar nor case authority sticks to another command.

Decoder regressions cover both admitted policies, field-order invariance,
mixed modulo/quotient ASTs, provider transfers, maximum and maximum-plus-one
divisors, zero/negative/mistyped/short forms, productive failure precedence,
startup and v1--v4 rejection, and unsupported version 6. Existing version-4
tests continue to pin its exact-only policy.

## Compatibility boundary

This is an additive contract-only version. It does not change the startup file
version, the command root, acquisition rules, Handoff routing, ranking strength,
presentation vocabulary, solver execution policy, or replay authority. Old
documents containing no quotient never acquire a quotient semantic tag,
lowering tag, witness name, command, or fingerprint field. Quotient-bearing
version-5 documents use Djex's explicit new semantic and lowering identities.

As with every Length assessment, a replayed result is bounded,
finite-list-spine, model-relative evidence conditional on any caller-supplied
provider laws. It is not a Lean execution, general behavioral equivalence,
solver certificate, kernel proof, or pruning authority.
