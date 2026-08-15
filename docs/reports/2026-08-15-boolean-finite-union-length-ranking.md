# Boolean finite-union Length ranking

Date: 2026-08-15

## Outcome

Leant can now select Djex's bounded Boolean finite-union applicable-domain
validator for scalar and canonical-`Prod` finite-spine Length ranking. This is
an additive eighth applicable-domain strategy. It retains the cumulative
strict relational positive-affine quotient, root-extrema, and root-monus leaf
scanner, then adds exact proof-polarity DNF, per-branch bounded closure, a
canonical antichain of zero-origin boxes, and one deduplicated global replay.

The public pure policy builder is:

```haskell
enableLengthRankingStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionApplicableDomainValidation
  :: LengthInputBoxLimits
  -> LengthBooleanFiniteUnionLimits
  -> LengthRankingPolicy
  -> LengthRankingPolicy
```

It replaces only the mutually exclusive applicable-domain selection. It
preserves execution and evaluation, origin probing, the independent post-
`unsat` input box, both non-vacuous preferences, counterexample simplification,
deferred session opening, and the selected usable-work strategy. Construction
is pure and creates no receipt.

The scalar assessment, failure, and renderer are:

```haskell
StrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionApplicableDomainEstablished
LengthRankingBooleanFiniteUnionApplicableDomainValidationFailed
renderLengthStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionApplicableDomainValidationNote
```

Their nominal product siblings are:

```haskell
LengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionApplicableDomainEstablished
LengthSpinePairRankingBooleanFiniteUnionApplicableDomainValidationFailed
renderLengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionApplicableDomainValidationNote
```

The closed startup constants are:

```haskell
lengthRankingConfigurationFileStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionVersion == 29
lengthRankingConfigurationFileSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionVersion == 30
```

Both require the exact strategy literal
`"strict-relational-positive-affine-quotient-root-extrema-monus-boolean-finite-union-v1"`.
They otherwise retain v27/v28 literally, including
`"descriptor-bound-execve-check-executable-access-v1"`, the scoped-v2 owner,
deferred opening, and scalar-v5 or pair-v5 contracts.

## Compatibility matrix

Startup versions are closed selections rather than cumulative feature levels:

| Versions | Applicable-domain strategy | Usable-work strategy | Executable launch |
|---|---|---|---|
| v1--v6 | none | none; eager | pathname snapshot/direct spawn |
| v7/v8 | literal-ceiling positive-affine | none; deferred | pathname snapshot/direct spawn |
| v9/v10 | literal-ceiling positive-affine | runtime-unscoped v1 | pathname snapshot/direct spawn |
| v11/v12 | relational positive-affine | none; deferred | pathname snapshot/direct spawn |
| v13/v14 | relational positive-affine | scoped/checkpointed v2 | pathname snapshot/direct spawn |
| v15/v16 | strict relational positive-affine | scoped/checkpointed v2 | pathname snapshot/direct spawn |
| v17/v18 | strict relational positive-affine | scoped/checkpointed v2 | sealed descriptor-bound image |
| v19/v20 | root quotient | scoped/checkpointed v2 | sealed descriptor-bound image |
| v21/v22 | root quotient | scoped/checkpointed v2 | effective-ID source access plus sealed image |
| v23/v24 | root extrema | scoped/checkpointed v2 | effective-ID source access plus sealed image |
| v25/v26 | root monus | scoped/checkpointed v2 | effective-ID source access plus sealed image |
| v27/v28 | root monus | scoped/checkpointed v2 | execve-check source/staged access plus sealed image |
| v29/v30 | Boolean finite union over cumulative root-monus leaves | scoped/checkpointed v2 | execve-check source/staged access plus sealed image |

The generalized decoder reaches v29/v30 only after every v1--v28 route returns
its closed `UnsupportedVersion` sentinel. Version 31 remains unsupported. The
scalar-only compatibility entrance still rejects v4--v30, and every older
schema rejects the new version or strategy where it is not admitted.

## Exact Boolean and union authority

Djex traverses the checked normalized formula with positive or negative proof
polarity:

| Signed formula | Raw DNF |
|---|---|
| `+true`, `-false` | one empty conjunction |
| `+false`, `-true` | empty union |
| `+not F`, `-not F` | flip polarity |
| `+all [F_i]` | Cartesian conjunction of positive child DNFs |
| `-all [F_i]` | union of negative child DNFs |
| positive at-most/equality | one predecessor leaf |
| negative at-most | one immediate strict predecessor leaf |
| negative equality | `not(A<=B)` or `not(B<=A)` |

It does not descend through an expression-level conditional or split a hidden
arithmetic disjunction. The raw branch cap is checked before canonicalization.
Then exact duplicate literals, literal/complement branches, duplicate branches,
and strict literal-set supersets are removed in order. Every retained branch
uses the unchanged root-monus leaf scanner, canonical rule order, and
immutable-snapshot rule-once closure under independent rule and inspection
caps. A contradictory branch disappears; missing coverage in any live branch
makes the whole validator ordinarily inapplicable.

Each bounded branch yields a source-ordered inclusive-maximum box. Duplicate
and componentwise-contained boxes are removed. Incomparable boxes remain
separate: `[1,3]` and `[3,1]` have 16 raw visits and 12 unique assignments and
are never widened to `[3,3]`. The receipt records boxes, box count, raw visit
count, unique-assignment count, applicable-assignment count, and its
model/provider-relative basis.

Assignments from every box enter one set and are replayed exactly once in
global lexicographic order, with the last input varying fastest. The checked
original precondition and postcondition remain authoritative. An empty union
records no boxes and all counts zero without demanding evaluation limits.
Nullary truth records `[[]]`, one visit, and one unique assignment. This is
finite-union authority, not a hull, general Boolean solver, Z3 proof, global
theorem, or pruning grant.

## Closed v29 and v30 documents

The complete scalar document is:

```json
{
  "format": "leant-live-length-ranking-configuration",
  "version": 29,
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
    "executableLaunch": "descriptor-bound-execve-check-executable-access-v1"
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
    "strategy": "strict-relational-positive-affine-quotient-root-extrema-monus-boolean-finite-union-v1",
    "maximumInputs": 2,
    "maximumGeneratedBranches": 4,
    "maximumRulesPerBranch": 4,
    "maximumClosureInspectionsPerBranch": 4,
    "maximumRetainedBoxes": 2,
    "maximumAssignmentVisits": 20,
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

The complete nominal product document is:

```json
{
  "format": "leant-live-length-ranking-configuration",
  "version": 30,
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
    "executableLaunch": "descriptor-bound-execve-check-executable-access-v1"
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
    "strategy": "strict-relational-positive-affine-quotient-root-extrema-monus-boolean-finite-union-v1",
    "maximumInputs": 1,
    "maximumGeneratedBranches": 2,
    "maximumRulesPerBranch": 2,
    "maximumClosureInspectionsPerBranch": 2,
    "maximumRetainedBoxes": 1,
    "maximumAssignmentVisits": 4,
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

The applicable-domain object has exactly eight members in this demand order:
strategy, maximum inputs, maximum generated branches, maximum rules per
branch, maximum closure inspections per branch, maximum retained boxes,
maximum assignment visits, and maximum unique assignments. The respective
numeric file caps are 8, 256, 64, 4096, 256, 262144, and 65536. The complete
policy order remains root, execution admission, execve-check execution,
evaluation, post-`unsat` box, origin probe, bounded-positive preference,
Boolean limits, applicable-domain preference, simplification, deferred
opening, scoped-v2 budget, then contract.

A negative JSON integer fails at `naturalField` as
`LengthRankingConfigurationFieldValueRejected`; cap plus one fails at
`capNatural` as `LengthRankingConfigurationPolicyLimitExceeded`.
`LengthRankingConfigurationBooleanFiniteUnionLimitsRejected` is only the
defensive checked-builder mapping after the file caps have admitted every
field.

## Ranking, failure, and presentation behavior

A complete finite-union counterexample follows the same simplification seam as
every other counterexample, and only its final vector is promoted in the
four-entry newest-first MRU bank. A positive receipt participates in the
applicable-domain preference only when its applicable count is nonzero; a
vacuous receipt remains neutral. Heuristic and unassessed candidates keep their
established relative order.

Input width, generated branch, per-branch rule, per-branch closure inspection,
retained box, maximum value, raw visit, and unique-assignment cap failures are
ordinary admission misses and continue to the next stage. Assignment-
evaluation rejection, internal enumeration invariant, and association failure
remain indexed atomic batch failures. Live, forcing, and finalization failures
also restore literal original order. No partial assessment or predecessor
fallback is retained.

The scalar and pair renderers are capped at 384 characters. They report the
model/provider-relative basis, boxes, raw visits, unique assignments,
applicable assignments, explicit vacuity, and at most the first two boxes with
the first two maxima in each. They do not print provider names, collapse the
union to a hull, or claim solver/global authority.

## Lifecycle and identity boundary

Configuration loading, activation, and builder composition perform no IO. The
inherited scoped-v2 batch always captures and checks its deadline clock. If
every candidate completes through pure MRU or finite-union replay, no
executable descriptor is opened, no source or staged access check runs, no
image is staged, and no worker is launched. The first actual live miss follows
v27/v28's exact two-source-pair plus one-staged exec-check lifecycle, sealed
image, deadline, cancellation, and cleanup behavior.

The v29/v30 profiles add nominal scalar and pair receipt schema identities and
the corresponding evidence and presentation distinctions only. Contract,
problem, query, SMT-LIB bytes, fingerprint, association, executable policy,
raw process, ready worker, fresh/shared/scoped run, and scoped-owner identities
remain literal. Nothing in the receipt attests Z3, a proof, arbitrary Boolean
logic, non-zero-origin regions, or Lean behavior beyond the checked bounded
replay.

## Source map and characterization

- `Leant.Synth.Length.Configuration` owns the pure last-wins builder.
- `Leant.Synth.Length.Configuration.File` owns v29/v30, the eight-field object,
  cap/order diagnostics, v1--v28 cascade, and v31 sentinel.
- Scalar and pair `Ranking.Internal` modules own routing, ordinary admission
  misses, indexed atomic failures, preference, MRU, scoped forcing, and
  nominal assessments.
- `Leant.Synth.Length.Presentation` owns the two bounded renderers.
- The unit suite characterizes closed schemas, limits, compatibility,
  last-wins policy composition, pure zero-worker routes, nominal scalar/pair
  assessments, simplification/MRU behavior, preference, presentation, scoped
  live/failure routes, and atomic fallback.

Djex's underlying DNF and union contract is recorded in the vendored
[Boolean finite-union applicable-domain report](../../lib/Djex/docs/reports/2026-08-15-boolean-finite-union-length-applicable-domain.md).
