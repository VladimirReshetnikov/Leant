# Strict relational positive-affine quotient Length ranking

Date: 2026-08-15

## Outcome

Leant can now select Djex's exact root-quotient-consequence applicable-domain
validator for scalar and canonical-`Prod` finite-spine Length ranking. This is
an additive fifth strategy. It delegates every quotient-free clause to the
strict relational positive-affine predecessor and adds only four exact Natural
implications for one positive-literal floor quotient at the root of exactly one
side of a directed top-level relation.

The public pure policy builder is:

```haskell
enableLengthRankingStrictRelationalPositiveAffineQuotientApplicableDomainValidation
  :: LengthInputBoxLimits
  -> LengthRankingPolicy
  -> LengthRankingPolicy
```

It replaces only the mutually exclusive applicable-domain selection. It
preserves execution, evaluation, origin probing, the independent explicit
post-`unsat` input box, both non-vacuous ordering preferences, counterexample
simplification, eager or deferred session opening, and either usable-work
strategy. Construction reads no clock, performs no IO, opens no executable or
worker, consumes no solver observation, and creates no assessment or evidence.

The scalar assessment and renderer are:

```haskell
StrictRelationalPositiveAffineQuotientApplicableDomainEstablished
renderLengthStrictRelationalPositiveAffineQuotientApplicableDomainValidationNote
```

Their nominal product siblings are:

```haskell
LengthSpinePairStrictRelationalPositiveAffineQuotientApplicableDomainEstablished
renderLengthSpinePairStrictRelationalPositiveAffineQuotientApplicableDomainValidationNote
```

The closed startup version constants are:

```haskell
lengthRankingConfigurationFileStrictRelationalPositiveAffineQuotientVersion == 19
lengthRankingConfigurationFileSpinePairStrictRelationalPositiveAffineQuotientVersion == 20
```

Both versions require the literal
`"strict-relational-positive-affine-quotient-v1"` and otherwise retain the
complete v17/v18 descriptor-bound, scoped-v2, deferred-opening profile.

## Compatibility matrix

Startup versions are closed selections, not cumulative feature levels:

| Versions | Applicable-domain strategy | Usable-work strategy | Executable launch |
|---|---|---|---|
| v1--v6 | none | none; eager historical path | pathname snapshot/direct spawn |
| v7/v8 | `positive-affine-v1` | none; deferred historical path | pathname snapshot/direct spawn |
| v9/v10 | `positive-affine-v1` | runtime-unscoped `shared-usable-work-deadline-v1` | pathname snapshot/direct spawn |
| v11/v12 | `relational-positive-affine-v1` | none; deferred historical path | pathname snapshot/direct spawn |
| v13/v14 | `relational-positive-affine-v1` | scoped/checkpointed `scoped-checkpointed-shared-usable-work-deadline-v2` | pathname snapshot/direct spawn |
| v15/v16 | `strict-relational-positive-affine-v1` | scoped/checkpointed v2 | pathname snapshot/direct spawn |
| v17/v18 | `strict-relational-positive-affine-v1` | scoped/checkpointed v2 | sealed descriptor-bound main image |
| v19/v20 | `strict-relational-positive-affine-quotient-v1` | scoped/checkpointed v2 | sealed descriptor-bound main image |

Every v1--v18 schema, decoder route, validation and diagnostic order, policy
selection, runner route, assessment family, presentation, and identity remains
literal. The scalar-only compatibility decoder still rejects v4--v20. The
generalized decoder reaches v19/v20 only after the complete v1--v18 cascade
returns its closed unsupported-version sentinel. Version 21 is unsupported.

## Programmatic composition

A caller can replace the applicable-domain dimension of an already composed
policy without changing its scoped budget or descriptor launch:

```haskell
let quotientPolicy =
      enableLengthRankingStrictRelationalPositiveAffineQuotientApplicableDomainValidation
        applicableDomainLimits descriptorStrictScopedPolicy

scalarResult <- assessVerifiedLengthCandidatesWithPolicy
  quotientPolicy scalarQuotientContract verificationBatch

pairResult <- assessVerifiedLengthSpinePairCandidatesWithPolicy
  quotientPolicy pairQuotientContract verificationBatch
```

All five applicable-domain builders are last-wins only within that dimension.
The two budget builders are independently last-wins within the usable-work
dimension. Scalar and product contracts, queries, counterexamples, receipts,
assessments, and renderers remain nominally separate.

## Four exact Natural laws

Write `q_d(E)` for Natural floor quotient `E quot d`, where `d > 0`. For
positive-affine operands `A` and `B`, the validator adds exactly these proof
rules:

```text
q_d(A) <= B        => A <= d*B + (d - 1)
A <= q_d(B)        => d*A <= B
not (q_d(A) <= B)  => d*(B + 1) <= A
not (A <= q_d(B))  => B + 1 <= d*A
```

These implications are exact over Natural values. They are not approximations
to integer division and introduce no SMT-LIB `div`. A top-level equality emits
both directed non-strict rules, left-to-right and then right-to-left. Reversing
the equality therefore preserves its consequences while retaining canonical
source order.

For example:

```text
q_3(x) <= 2
```

gives `x <= 3*2 + 2`, hence `x <= 8`. The propagated pair

```text
x <= q_3(y)
y <= 8
```

gives `3*x <= y <= 8`, hence source-ordered maxima `[2, 8]`.
Likewise, `not (q_3(y) <= x)` together with `y <= 8` gives `x <= 1`, and
`not (y <= q_3(x))` together with `y <= 2` gives `x <= 5`.

Equality requires both directions. From `q_3(x) = y` and `x <= 1`, the
right-to-left rule derives `3*y <= x`, hence `y <= 0`; the opposite rule is
retained for subsequent propagation. The same maxima arise from
`y = q_3(x)`.

## Exact extraction and exclusion boundary

Djex scans either the normalized precondition itself or the immediate clauses
of its flat top-level `LengthAll`. A supported quotient must be at the operand
root of exactly one side of a top-level `LengthAtMost`, `LengthEqual`, or
immediate `LengthNot (LengthAtMost ...)`. Its dividend and the opposite operand
must be positive-affine expressions over compact input variables, Natural
literals, sums, and positive-literal scales.

The following shapes grant no quotient-consequence rule:

- a quotient nested below another quotient;
- a quotient embedded in a sum, scale, monus, minimum, maximum, modulo, or
  conditional rather than at the relation operand root;
- quotients at both relation roots;
- a dividend or opposite operand outside the positive-affine grammar;
- negated equality, nested negation, a nested conjunction, or another
  unsupported whole formula;
- a result variable or an out-of-range compact input.

An unsupported clause contributes no partial bound. It remains part of the
actual normalized precondition replay if other clauses establish a complete
finite box. Quotient-free clauses delegate to the strict predecessor exactly:
ordinary inequalities and equality, immediate strict Natural complement,
`LengthTruth False`, contradiction handling, and all legacy misses are
unchanged.

The inherited closure remains synchronous and rule-once. Seed rules fire
against an empty bounds map. Every later pass examines pending rules against
one immutable snapshot, merges new maxima with `min` only after that pass, and
permanently removes each fired rule. It is not a numeric least-fixed-point
solver. Recognized contradiction wins over missing coverage and selects the
all-zero carrier for replay; otherwise the first compact input without a
derived maximum is ordinary inapplicability.

## Precedence and ranking route

The validator preserves the predecessor's exact demand order:

1. reject input width before demanding evaluation limits or the precondition;
2. scan normalized top-level clauses and run the bounded rule-once closure;
3. report the first compact missing input before any finite-box replay;
4. validate derived maxima and Cartesian assignment count;
5. replay assignments in canonical order and stop at the first evaluation
   failure or counterexample;
6. release establishment only after every applicable assignment succeeds.

The selected pre-live route is also unchanged:

```text
four-entry newest-first MRU replay
  -> strict relational positive-affine quotient applicable domain
  -> canonical all-zero origin replay
  -> live Z3 observation and query-owned replay
  -> optional post-unsat explicit input box
```

An MRU hit preempts extraction. Inapplicability is a pure miss. The first
independently replayed violation is the ordinary scalar or product
counterexample and crosses the same optional query-owned componentwise-
lexicographic simplifier. Only the final reduced input vector enters the
domain-local MRU bank. Non-vacuous establishment enters the preferred stable
partition only when the separate applicable-domain preference is enabled;
vacuous establishment remains neutral. No candidate is pruned.

## Complete scalar v19 document

This document retains v17's full shape, descriptor launch, scoped-v2 budget,
deferred opening, and scalar-v5 contract. Only the version and applicable-
domain strategy selections advance:

```json
{
  "format": "leant-live-length-ranking-configuration",
  "version": 19,
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
    "executableLaunch": "descriptor-bound-executable-v1"
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
    "strategy": "strict-relational-positive-affine-quotient-v1",
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

Replace the illustrative digest with the digest of the intended executable
main image. Activation requires its presence by default; Djex compares it only
at the first live open.

## Complete pair v20 document

The nominal product sibling retains v18's full pair-v5 contract and advances
the same two selections:

```json
{
  "format": "leant-live-length-ranking-configuration",
  "version": 20,
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
    "executableLaunch": "descriptor-bound-executable-v1"
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
    "strategy": "strict-relational-positive-affine-quotient-v1",
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

The contract's postcondition quotient is unrelated to coverage selection; the
new strategy affects only precondition-derived finite-domain authority. The
contract remains the same passive assertion and QF_LIA witness grammar used by
v18.

## Decoder order and failure boundary

V19/v20 reuse the exact v17/v18 root fields. The execution object retains every
legacy member and requires `"executableLaunch":
"descriptor-bound-executable-v1"` last in its closed field set. After bounded
JSON and format/version routing, semantic validation performs:

```text
exact root admission
executionAdmission
legacy execution members
descriptor launch type and literal
Djex descriptor execution sealing
evaluation
inputBoxValidation
counterexampleProbe
boundedPositiveOrdering
quotient applicable-domain fields, literal, caps, and Djex limits
applicableDomainOrdering
counterexampleSimplification
liveSessionOpening
scoped-v2 usableWorkBudget
scalar-v5 or pair-v5 contract
```

Unknown fields precede missing fields at each exact-object gate. Missing legacy
members precede the later launch member; the launch discriminator precedes
evaluation and all behavioral policy. Contract errors cannot preempt an
earlier operational, domain, simplification, lifecycle, or budget error. JSON
member order is immaterial.

The existing disabled/activation boundary is unchanged. Decoding, loading,
and activation create no deadline, descriptor, worker, solver observation, or
evidence. Default activation requires a digest expectation, but presence is
not a match. A live descriptor-bound failure, pin mismatch, deadline, scope
failure, query failure, or cleanup failure retains the established sanitized
atomic-fallback behavior; there is no path-launch fallback.

## Scoped lifecycle and executable authority

V19/v20 inherit v17/v18's deferred lifecycle. At most 64 occurrences are
admitted before the clock, then one owner-thread-affine scoped-v2 lease covers
complete preparation, the pure MRU/domain/origin prefix, first-worker opening,
every live query, and Leant-owned result forcing. Cooperative checks occur at
the established phase boundaries. The quotient traversal is one bounded,
synchronous per-candidate checkpoint quantum; it is not asynchronously
interruptible pure work.

An all-pure batch can settle without opening an executable descriptor or Z3
worker. On the first live miss, Djex opens the source without following the
final component, hashes each bounded chunk while copying those bytes into an
anonymous image, seals writes and size changes, and executes only that sealed
descriptor. The authority covers the staged main-image bytes only. It does not
attest an ELF interpreter, dynamic loader, shared library, set-id or file-
capability metadata, Z3 semantics, or solver output.

## Behavioral authority and identity

Selecting the strategy, startup version, descriptor launch, digest
expectation, deadline, or ranking preference is not behavioral evidence.
Establishment is released only after Djex independently replays the complete
derived finite box against the exact checked query. It remains relative to the
normalized contract, interpreted candidate, bounded evaluator, finite-spine
model, and exact assumed provider-law basis. It establishes no source-language
termination, strictness, effect, bottom-freedom, universal correctness, solver
soundness, Lean theorem, or pruning authority.

The proof-only quotient rewrites emit no SMT-LIB command and consume no
`sat`, `unsat`, or `unknown`. They do not alter normalized contract bytes,
checked problem identity, sealed query fingerprint or wire bytes, protocol,
process, ready-worker, scalar-run, or pair-run identity. V19/v20 reuse the
descriptor-bound execution and scoped-v2 lifecycle identities of v17/v18.

Djex adds exactly two nominal receipt schema tags:

```text
finite-list-spine-length/strict-relational-positive-affine-quotient-precondition-domain-establishment/v1
finite-binary-product-spine-lengths/strict-relational-positive-affine-quotient-precondition-domain-establishment/v1
```

Leant adds nominal scalar/product assessment and presentation branches but no
canonical evidence bytes of its own. Private receipt constructors and provider
names remain hidden. Scalar and product receipts cannot be coerced into one
another, and stale or cross-domain replay fails at the existing association
boundary.

Djex's extraction, closure, receipt, precedence, authority, and identity
contract is recorded in the
[strict relational positive-affine quotient applicable-domain report](../../lib/Djex/docs/reports/2026-08-15-strict-relational-positive-affine-quotient-length-applicable-domain.md).

## Verification snapshot

At this dated checkpoint, `test-unit/Spec.hs` contains 23,334 lines and 443
exact `testCase` tokens. The strict test target compiled with warnings promoted
to errors:

```text
cabal build test:leant-synth-tests --ghc-options=-Werror
```

The focused characterization ran with:

```text
cabal test test:leant-synth-tests --test-options='--pattern quotient-consequence'
```

All seven focused cases passed in 2.10 seconds. These counts and timings are a
snapshot, not an API guarantee.

## Future work

This checkpoint does not select a definitive next behavioral extension.
Additional exact algebraic consequences, bounded extrema, Boolean structure,
finite unions, or other coverage rules may be evaluated independently against
their authority, complexity, and test costs. In particular, this report makes
no commitment that Boolean/DNF domain extraction is next.
