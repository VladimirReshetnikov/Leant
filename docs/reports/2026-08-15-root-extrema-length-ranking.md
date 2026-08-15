# Root-extrema Length ranking

Date: 2026-08-15

## Outcome

Leant can now select Djex's cumulative root-extrema applicable-domain
validator for scalar and canonical-`Prod` finite-spine Length ranking. This is
an additive sixth strategy. It delegates every root-extrema-free clause to the
strict relational positive-affine quotient predecessor and adds exactly four
necessary Natural consequence pairs for one immediate binary `min` or `max`
at exactly one top-level relation operand root.

The public pure policy builder is:

```haskell
enableLengthRankingStrictRelationalPositiveAffineQuotientRootExtremaApplicableDomainValidation
  :: LengthInputBoxLimits
  -> LengthRankingPolicy
  -> LengthRankingPolicy
```

It replaces only the mutually exclusive applicable-domain selection. It
preserves execution and evaluation limits, origin probing, the independent
post-`unsat` input box, both non-vacuous preferences, counterexample
simplification, live-session opening, and the selected usable-work strategy.
Construction reads no clock, performs no IO, and creates no assessment.

The scalar assessment and renderer are:

```haskell
StrictRelationalPositiveAffineQuotientRootExtremaApplicableDomainEstablished
renderLengthStrictRelationalPositiveAffineQuotientRootExtremaApplicableDomainValidationNote
```

Their nominal product siblings are:

```haskell
LengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaApplicableDomainEstablished
renderLengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaApplicableDomainValidationNote
```

The closed startup version constants are:

```haskell
lengthRankingConfigurationFileStrictRelationalPositiveAffineQuotientRootExtremaVersion == 23
lengthRankingConfigurationFileSpinePairStrictRelationalPositiveAffineQuotientRootExtremaVersion == 24
```

Both require the exact literal
`"strict-relational-positive-affine-quotient-root-extrema-v1"`. They otherwise
retain the complete v21/v22 effective-ID executable-access, scoped-v2,
deferred-opening, preference, simplification, and scalar-v5/pair-v5 contract
profiles.

## Compatibility matrix

Startup versions are closed selections, not cumulative feature levels:

| Versions | Applicable-domain strategy | Usable-work strategy | Executable launch |
|---|---|---|---|
| v1--v6 | none | none; eager historical path | pathname snapshot/direct spawn |
| v7/v8 | `positive-affine-v1` | none; deferred historical path | pathname snapshot/direct spawn |
| v9/v10 | `positive-affine-v1` | runtime-unscoped v1 | pathname snapshot/direct spawn |
| v11/v12 | `relational-positive-affine-v1` | none; deferred historical path | pathname snapshot/direct spawn |
| v13/v14 | `relational-positive-affine-v1` | scoped/checkpointed v2 | pathname snapshot/direct spawn |
| v15/v16 | `strict-relational-positive-affine-v1` | scoped/checkpointed v2 | pathname snapshot/direct spawn |
| v17/v18 | `strict-relational-positive-affine-v1` | scoped/checkpointed v2 | sealed descriptor-bound main image |
| v19/v20 | `strict-relational-positive-affine-quotient-v1` | scoped/checkpointed v2 | sealed descriptor-bound main image |
| v21/v22 | `strict-relational-positive-affine-quotient-v1` | scoped/checkpointed v2 | effective-ID access plus sealed main image |
| v23/v24 | `strict-relational-positive-affine-quotient-root-extrema-v1` | scoped/checkpointed v2 | effective-ID access plus sealed main image |

Every v1--v22 schema and decoder route remains literal. The generalized
decoder reaches v23/v24 only after that complete older cascade returns its
closed `UnsupportedVersion` sentinel. Version 25 is the next unsupported
sentinel. The scalar-only compatibility decoder still rejects v4--v24.

## Four exact Natural laws

For positive-affine `A`, `B`, and `C`, the validator adds only these pairs:

```text
max(A,B) <= C        => A <= C       and B <= C
C <= min(A,B)        => C <= A       and C <= B
not (min(A,B) <= C)  => C + 1 <= A   and C + 1 <= B
not (C <= max(A,B))  => A + 1 <= C   and B + 1 <= C
```

Each implication is necessary over Natural values. Equality is also
necessary-only in both source orientations:

```text
max(A,B) = C   or C = max(A,B)  => A <= C and B <= C
min(A,B) = C   or C = min(A,B)  => C <= A and C <= B
```

There is no converse or sufficient equality rule. In particular, the emitted
inequalities do not establish that either extremum operand attains `C`.

## Exact extraction and exclusion boundary

Djex scans the normalized precondition itself or its immediate flat top-level
conjuncts. A supported clause has exactly one immediate binary root extremum
at one relation operand root. The other operand is root-extrema-free, and all
three operands are positive-affine.

The following shapes grant no root-extrema rule:

- nested extrema, including a binary tree that represents an n-ary extremum;
- extrema at both relation operand roots, or mixed `min`/`max` roots;
- an extremum embedded below a sum, scale, quotient, monus, modulo,
  conditional, or another expression rather than at the relation root;
- the wrong inequality or negated-inequality orientation;
- a disjunctive, nested-conjunctive, negated-equality, or otherwise unsupported
  whole formula;
- an operand outside the positive-affine grammar, a result variable, or an
  out-of-range compact input.

Extraction is all-or-nothing per clause: both rules are emitted atomically or
the whole clause is ignored. An ignored clause remains in the original
normalized precondition replay if other clauses establish a complete finite
box. Root-extrema-free clauses delegate to the quotient predecessor literally,
including its quotient laws, strict complement, contradiction handling, and
legacy misses.

Accepted clauses, extrema operands, and emitted rules retain normalized
canonical order. The inherited closure is synchronous and rule-once: every
pass reads one immutable bounds snapshot, then merges new maxima with `min`.
Recognized contradiction takes precedence over missing coverage; otherwise the
first compact input without a bound is reported. This order is observable in
diagnostics but never changes the checked formula.

## Replay, authority, and preference

The selected pre-live route remains:

```text
four-entry newest-first MRU replay
  -> root-extrema applicable-domain validation
  -> canonical all-zero origin replay
  -> live Z3 observation and query-owned replay
  -> optional post-unsat explicit input box
```

An MRU hit preempts extraction. Inapplicability is a pure miss. Only a complete
query-owned replay across the derived finite box releases the new scalar or
pair receipt; extraction itself is not evidence. The original normalized
formula and provider laws remain behavioral authority for every assignment.
The solver's status is never promoted into a receipt.

When the separately enabled non-vacuous applicable-domain preference is
selected, a completed receipt with at least one applicable assignment enters
the preferred stable partition. A zero-applicable receipt remains neutral.
Counterexamples remain in their stable demoted partition, no candidate is
pruned, and original relative order is preserved inside every partition.

## Complete scalar v23 document

This is the complete v21 scalar document with only its version and
applicable-domain literal advanced:

```json
{
  "format": "leant-live-length-ranking-configuration",
  "version": 23,
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
    "executableLaunch": "descriptor-bound-effective-id-executable-access-v1"
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
    "strategy": "strict-relational-positive-affine-quotient-root-extrema-v1",
    "maximumInputs": 2,
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

## Complete nominal pair v24 document

This is the complete v22 pair document with only the same two selections
advanced:

```json
{
  "format": "leant-live-length-ranking-configuration",
  "version": 24,
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
    "executableLaunch": "descriptor-bound-effective-id-executable-access-v1"
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
    "strategy": "strict-relational-positive-affine-quotient-root-extrema-v1",
    "maximumInputs": 1,
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

## Decoder, lifecycle, and failure boundary

V23/v24 retain v21/v22's exact root and nested field admission order. Only the
selected applicable-domain validator and receipt constructor change. Loading
and activation remain pure. An all-pure batch opens no source descriptor,
performs no execute-access check, allocates no staged image, and starts no
worker. The first demanded live miss opens at most one fresh lexical session.

Preparation, pure ranking, live work, and Leant-owned deep forcing remain
beneath the same owner-thread-affine scoped-v2 absolute deadline and
cooperative checkpoints. No scoped token escapes its dynamic extent. Access,
staging, opening, live assessment, replay, forcing, and finalization failures
use the existing closed failure classes, discard partial live assessments, and
atomically restore literal original order. There is no fallback to v21/v22's
domain validator or to an older executable-launch strategy.

## Presentation and identity boundaries

The two new renderers report derived inclusive maxima, checked and applicable
assignment counts, the exact model/provider-relative basis, and explicit
vacuity under the distinct positive-affine quotient/root-extrema rule label.
They do not project private provider-name lists and do not turn the receipt
into a proof of Lean behavior or pruning authority.

The new scalar and pair receipt schema tags are additive nominal identities.
Problem serialization, SMT-LIB query bytes, wire protocol, query fingerprint,
query-association replay, counterexample identity, executable identity, and
scoped-owner identity do not change. Scalar and pair contracts, queries,
receipts, assessments, and notes remain nominally separate.

Djex's underlying extraction, receipt, replay, authority, and identity
boundary is documented in its
[root-extrema applicable-domain report](../../lib/Djex/docs/reports/2026-08-15-root-extrema-length-applicable-domain.md).

## Validation

The complete v23 and v24 examples were parsed as JSON and accepted by Leant's
actual generalized configuration decoder. Documentation links, Markdown fence
balance, trailing whitespace, stale version ranges, and the generated
walkthrough were checked from the repository tree.
