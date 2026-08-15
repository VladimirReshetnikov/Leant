# Root-monus Length ranking

Date: 2026-08-15

## Outcome

Leant can now select Djex's cumulative root-monus applicable-domain validator
for scalar and canonical-`Prod` finite-spine Length ranking. This is an
additive seventh strategy. Every clause without an immediate root monus is
delegated literally to the root-extrema predecessor. The successor adds only
the five normalized relation cases below for one immediate binary Natural
monus at exactly one relation operand root.

The public pure policy builder is:

```haskell
enableLengthRankingStrictRelationalPositiveAffineQuotientRootExtremaMonusApplicableDomainValidation
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
StrictRelationalPositiveAffineQuotientRootExtremaMonusApplicableDomainEstablished
renderLengthStrictRelationalPositiveAffineQuotientRootExtremaMonusApplicableDomainValidationNote
```

Their nominal product siblings are:

```haskell
LengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusApplicableDomainEstablished
renderLengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusApplicableDomainValidationNote
```

The closed startup version constants are:

```haskell
lengthRankingConfigurationFileStrictRelationalPositiveAffineQuotientRootExtremaMonusVersion == 25
lengthRankingConfigurationFileSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusVersion == 26
```

Both require the exact literal
`"strict-relational-positive-affine-quotient-root-extrema-monus-v1"`. They
otherwise retain the complete v23/v24 effective-ID executable-access,
scoped-v2, deferred-opening, preference, simplification, and
scalar-v5/pair-v5 contract profiles.

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
| v25/v26 | `strict-relational-positive-affine-quotient-root-extrema-monus-v1` | scoped/checkpointed v2 | effective-ID access plus sealed main image |

Every v1--v24 schema and decoder route remains literal. The generalized
decoder reaches v25/v26 only after that complete older cascade returns its
closed `UnsupportedVersion` sentinel. Version 27 is the next unsupported
sentinel. The scalar-only compatibility decoder still rejects v4--v26.

## Five admitted Natural cases

Let

```text
M = A monus B = max(A-B,0)
C = c + sum(k_i*x_i)
```

where `A`, `B`, and `C` each have an exact positive-affine summary over
Natural inputs. The scanner admits only these five normalized relation shapes:

| Formula | Admission | Proof-only affine consequences |
|---|---|---|
| `M <= C` | always | `A <= B+C` |
| `C <= M` | `c>0`; identically-zero `C` emits nothing | `B+C <= A` when `c>0` |
| `not (M <= C)` | always | `B+C+1 <= A` |
| `not (C <= M)` | always | `1 <= C`, then `A+1 <= B+C` |
| `M = C` or `C = M` | always | `A <= B+C`; append `B+C <= A` when `c>0` |

The first four admitted rows are exact equivalences under the stated
condition. Equality deliberately keeps a necessary supported half when `C`
may be zero; that half is not claimed to be sufficient.

### The reverse non-strict zero boundary

The unconditional law is disjunctive:

```text
C <= A monus B  <=>  C = 0 or B+C <= A
```

The affine constant `c` is the minimum value of `C` over Natural inputs:

1. If `c>0`, `C` is uniformly positive and the scanner emits the exact rule
   `B+C<=A`.
2. If `c=0` and the coefficient map is empty, `C` is identically zero. The
   source relation is tautological and emits no rule.
3. If `c=0` with coefficients, `C` may be zero. The exact domain is a union,
   so the whole clause is ignored.

Positivity is clause-local. The closure stores upper bounds, not reusable
lower-bound proofs, and the scanner never borrows `1<=C` from another clause.
It also does not substitute the weaker necessary rule `C<=A`: that would turn
this checkpoint's exact oriented rewrites into an unbounded relaxation policy.

### Strict polarities and equality

Natural complement gives the exact forward strict law:

```text
not (A monus B <= C)  <=>  B+C+1 <= A
```

The reverse strict orientation has two exact conjuncts:

```text
not (C <= A monus B)
  <=>  1 <= C and A+1 <= B+C
```

The scanner emits `1<=C` first and `A+1<=B+C` second. Both appear only after
all three operands have summarized successfully.

The complete equality law crosses the same zero boundary:

```text
A monus B = C
  <=>  (C=0 and A<=B)
    or (1<=C and A=B+C)
```

Equality in either root orientation always emits the necessary consequence
`A<=B+C`. If `c>0`, it appends `B+C<=A` and the pair is exact. If `C` is
identically zero, the first rule is the exact monus-zero condition `A<=B`.
If `C` may be zero, only the necessary first rule is retained. Canonical
equality sorting cannot change this order, and negated equality remains
unsupported.

## All-or-nothing extraction and replay

Every `A`, `B`, and `C` must fit the predecessor grammar of compact inputs,
Natural literals, sums, and positive-literal scales. Exactly one relation
operand may be an immediate retained binary root monus. These shapes grant no
root-monus rule:

- root monus on both relation operands;
- monus nested below a sum, scale, quotient, modulo, extremum, conditional, or
  another expression;
- a monus operand or opposite relation operand containing monus, quotient,
  modulo, minimum, maximum, a conditional, a result reference, or another
  unsupported node;
- mixed root-monus/root-quotient or root-monus/root-extrema clauses;
- negated equality or relations below nested Boolean structure.

The scanner summarizes all three operands before retaining any candidate rule.
An unsupported shape grants no partial rule, but the original checked clause
remains authoritative during concrete replay when other clauses establish a
complete rectangle. A clause with no retained root monus delegates to the
root-extrema predecessor literally.

Admission sees the checked normalized tree. Literal/literal monus folds to the
saturated difference; `A monus 0` becomes `A`; and `A monus A` becomes zero.
Other monus expressions retain their ordered children. Equality operands and
flat top-level conjunction clauses retain normalized canonical order. The
inherited closure is synchronous and rule-once: each pass reads one immutable
bounds snapshot, then merges candidate maxima with `min`. A monus clause emits
at most two rules, so the existing `2*F` consequence ceiling and bounded
quadratic scan for formula-clause limit `F` need no new work cap.

Recognized contradiction takes precedence over missing coverage; otherwise the
first compact missing input wins. Derived maxima, Cartesian count, indexed
evaluation failure, first counterexample, receipt construction, and final query
association retain their established order. Contradiction selects the all-zero
carrier rather than an empty product. Every admitted assignment replays the
original normalized precondition and postcondition; proof summaries never
replace the checked formula.

## Representative bounds and counts

The scalar precondition `(x monus 3) <= 5` derives `x<=8`. Its rectangle has
maximum `[8]` and checked/applicable counts 9/9. The uniformly positive reverse
`1 <= (5 monus x)` derives `x+1<=5`, giving `[4]` and 5/5. The strict forward
`not ((5 monus x) <= 2)` derives `x+3<=5`, giving `[2]` and 3/3.

Equality retains original-formula selectivity. `(5 monus x)=1` derives
`5<=x+1` and `x+1<=5`, so the maximum is `[4]`; all five assignments are
checked and only one is applicable. `(x monus 3)=0` derives the exact
monus-zero condition `x<=3`, giving `[3]` and 4/4. The nominal product runner
can establish the same rectangles only as product evidence; its receipt and
assessment cannot be presented as scalar evidence.

By contrast, `x <= (5 monus y)` has a may-zero affine opposite and emits no
monus rule. If no predecessor clause bounds both inputs, the validator remains
ordinarily inapplicable rather than widening the disjunction. For
`not (0 <= (x monus y))`, the first reverse-strict rule is the contradiction
`1<=0`; contradiction selects the all-zero carrier `[0,0]`, and replay records
1/0 rather than manufacturing an empty domain.

## Replay lifecycle, failure, and preference

The selected pre-live route remains:

```text
four-entry newest-first MRU replay
  -> root-monus applicable-domain validation
  -> canonical all-zero origin replay
  -> live Z3 observation and query-owned replay
  -> optional post-unsat explicit input box
```

An MRU hit preempts extraction. Inapplicability is a pure miss. A first replayed
postcondition violation becomes the ordinary scalar or product counterexample
and its final vector is inserted or promoted in the matching four-entry MRU
bank. Only complete finite-box replay releases a root-monus establishment
receipt. Raw `sat`, `unsat`, or `unknown` never becomes evidence.

Loading and activation remain pure. An all-pure batch opens no source
descriptor, performs no execute-access check, allocates no staged image, and
starts no worker. The first actual live miss opens at most one fresh lexical
session for the remaining suffix. Preparation, pure ranking, live work, deep
forcing, and final observation remain beneath the owner-thread-affine scoped-v2
absolute deadline and cooperative phase checkpoints.

Access, staging, opening, live assessment, replay, forcing, or finalization
failure uses the existing closed failure class, discards partial live
assessments, and atomically restores literal original order. There is no
fallback to v23/v24's validator or to an older launch strategy. Candidate-local
preparation refusals remain their bounded refusal class; synchronous and
asynchronous exceptions retain their established propagation behavior.

The separately selected non-vacuous applicable-domain preference promotes only
a completed receipt whose applicable-assignment count is positive. A vacuous
receipt remains neutral. Composed with the explicit-box preference, the stable
partitions remain applicable-domain positive, explicit-box positive, neutral or
vacuous, then counterexample. Original relative order is preserved within each
partition and no candidate is pruned.

## Complete scalar v25 document

This is the complete v23 scalar document with only its version and
applicable-domain literal advanced:

```json
{
  "format": "leant-live-length-ranking-configuration",
  "version": 25,
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
    "strategy": "strict-relational-positive-affine-quotient-root-extrema-monus-v1",
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

## Complete nominal pair v26 document

This is the complete v24 pair document with only the same two selections
advanced:

```json
{
  "format": "leant-live-length-ranking-configuration",
  "version": 26,
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
    "strategy": "strict-relational-positive-affine-quotient-root-extrema-monus-v1",
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

The exact root and nested validation order, field identities, caps, effective-
ID execution constructor, scoped owner, and contract decoders are inherited
from v23/v24. JSON object member order is immaterial; semantic diagnostic order
is fixed by the decoder. The examples above intentionally differ from the
corresponding v23/v24 documents only in `version` and
`applicableDomainValidation.strategy`.

## Presentation, identity, and authority boundaries

The two renderers report derived inclusive maxima, checked and applicable
assignment counts, the exact model/provider-relative basis, and explicit
vacuity under the distinct positive-affine quotient/root-extrema/monus rule
label. Each note is capped at 384 characters. The renderers do not project
private provider-name lists, and Main prints a note only after the matching
scalar or pair assessment survives the occurrence seal. Disabled, rejected,
unassessed, heuristic-only, and atomic-fallback paths print no semantic note.

The new scalar and pair receipt schema tags are additive nominal identities.
Their constructors remain private, both receipts have `NFData`, and they are
not coercible to each other or to any predecessor receipt. Problem
serialization, SMT-LIB query bytes, wire protocol, query fingerprint,
query-association replay, counterexample identity, executable identity, worker
and run identity, and scoped-owner identity do not change. The inherited
effective-ID launch classifier and Main startup notice also remain unchanged.
The exact new receipt tags are:

```text
finite-list-spine-length/strict-relational-positive-affine-quotient-root-extrema-monus-precondition-domain-establishment/v1
finite-binary-product-spine-lengths/strict-relational-positive-affine-quotient-root-extrema-monus-precondition-domain-establishment/v1
```

Establishment means only that every assignment in one admitted finite
rectangle was replayed under the exact checked finite-spine model and that the
receipt records how many assignments met the precondition. It grants no
authority over behavior outside that rectangle, source-language termination or
realization, assumed provider implementations, solver correctness, or a global
proof. It carries no solver or global authority and never authorizes pruning or
suppression of candidates.

Djex's underlying extraction, receipt, replay, countermodels, precedence, and
identity boundary is documented in its
[root-monus applicable-domain report](../../lib/Djex/docs/reports/2026-08-15-root-monus-length-applicable-domain.md).

## Remaining finite-union boundary

May-zero `C<=A monus B` exposes an exact union:

```text
C=0 or B+C<=A
```

The current receipt represents one finite rectangle and cannot claim that
union. A future bounded Boolean/DNF design needs a separate nominal receipt and
explicit caps for branch generation, rules and closure per branch, retained
boxes, total union replay, and overlap or deduplication work. Every live branch
must be fully bounded. It must not widen branch boxes into one componentwise-
maximum rectangle, because that introduces cross-branch assignments and can
multiply work. No such union authority is implied by v25/v26.

## Validation

The complete v25 and v26 examples were parsed as JSON and accepted by Leant's
actual generalized configuration decoder. After the test suite's final metrics
were frozen, documentation links, anchors, Markdown fence balance, stale
version ranges, trailing whitespace, normalized v23-to-v25 and v24-to-v26
inheritance, and the regenerated walkthrough PDF and extracted text were
checked from the repository tree.
