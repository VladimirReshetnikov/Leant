# Boolean finite-union root-extrema/may-zero-monus atomic branching for Length ranking

Date: 2026-08-15

## Outcome

Leant can now select Djex's bounded Boolean finite-union validator with exact
atomic alternatives for one immediate binary root extremum or may-zero root
monus. The scalar startup schema is version 31 and the nominal canonical-
`Prod` sibling is version 32. Both retain the complete v29/v30 execution,
ranking, limit, lifecycle, and contract profile and change only the selected
applicable-domain validator and the nominal positive receipt family.

The public pure policy builder is:

```haskell
enableLengthRankingStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingApplicableDomainValidation
  :: LengthInputBoxLimits
  -> LengthBooleanFiniteUnionLimits
  -> LengthRankingPolicy
  -> LengthRankingPolicy
```

Like every applicable-domain builder, it is mutually exclusive and last-wins.
It preserves execution and evaluation, origin probing, the independent post-
`unsat` input box, both non-vacuous preferences, counterexample
simplification, deferred session opening, and the selected usable-work owner.
Construction is pure and creates no evidence.

The scalar assessment and renderer are:

```haskell
StrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingApplicableDomainEstablished
renderLengthStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingApplicableDomainValidationNote
```

Their nominal product siblings are:

```haskell
LengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingApplicableDomainEstablished
renderLengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingApplicableDomainValidationNote
```

The new routing reuses the existing closed failures:

```haskell
LengthRankingBooleanFiniteUnionApplicableDomainValidationFailed
LengthSpinePairRankingBooleanFiniteUnionApplicableDomainValidationFailed
```

It adds neither a limit type nor a failure constructor.

The startup constants are:

```haskell
lengthRankingConfigurationFileStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingVersion == 31
lengthRankingConfigurationFileSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingVersion == 32
```

Both require the exact strategy literal
`"strict-relational-positive-affine-quotient-root-extrema-monus-boolean-finite-union-atomic-branching-v1"`.
Version 33 is the next unsupported sentinel.

## Exact atomic alternatives

For normalized positive-affine children `A` and `B` and opposite affine
operand `C`, the exact root-extremum alternatives are:

```text
C <= max(A,B)          -> [C<=A] | [C<=B]
min(A,B) <= C          -> [A<=C] | [B<=C]
not(max(A,B)<=C)       -> [C+1<=A] | [C+1<=B]
not(C<=min(A,B))       -> [A+1<=C] | [B+1<=C]
max(A,B)=C             -> [A<=C,B<=C,C<=A] | [A<=C,B<=C,C<=B]
min(A,B)=C             -> [C<=A,C<=B,A<=C] | [C<=A,C<=B,B<=C]
```

Equality admits the immediate root on either side. Alternatives follow the
normalized first child and then the second child; rules inside each
alternative retain the displayed order. There is no proof-rule deduplication.
The four orientations already exact in the root-extrema predecessor remain
singleton alternatives.

Let `M = A monus B = max(A-B,0)`. When nonconstant affine `C` may be zero, the
new alternatives are zero first and bound second:

```text
C <= M        -> [C<=0] | [B+C<=A]
M = C         -> [A<=B+C,C<=0] | [A<=B+C,B+C<=A]
C = M         -> [A<=B+C,C<=0] | [A<=B+C,B+C<=A]
```

The common equality consequence remains first. In particular, the zero branch
is not rewritten to `A<=B`. Constant-positive and identically-zero opposites
retain the root-monus predecessor's singleton behavior, as do all previously
exact extremum and monus orientations.

All three required operands are summarized before any alternative is kept.
Exactly one relation operand may contain the admitted immediate binary root.
Both-root, nested, embedded, mixed extremum/monus/quotient, effectively n-ary,
conditional, unsupported-child, unsupported opposite-affine, and hidden
expression-level Boolean shapes are ignored atomically. Normalization remains
authoritative.

## Raw product, canonical expansion, and no-hull replay

Djex first creates the predecessor's signed formula DNF. It then lazily counts
the complete Cartesian product of formula branches and per-atom alternatives
under the existing generated-branch cap:

```text
raw count = sum over formula branches
              (product of each literal's alternative count)
```

The cap is enforced before complement removal, duplicate removal, absorption,
or proof-rule collection. Two binary atoms in one conjunction therefore count
four complete witnesses. The characterized negated-equality boundary counts
three. A cap one below the complete stream reports the existing bounded
`limit+1` observation.

After admission, canonicalization operates on sets of original checked
literals. Surviving sets are traversed in `Set` order and each literal is
re-expanded into explicit ignored, contradictory, or ordered-rule
alternatives. No replacement `LengthFormula` or proof-rule `Set` is created.
Rule and closure failure indices refer to this expanded canonical stream.

Branch collection, synchronous immutable-snapshot rule-once closure,
contradiction and missing-bound precedence, zero-origin box antichain,
last-input-fastest enumeration, global lexicographic unique replay, and exact
original-formula evaluation are unchanged. Incomparable boxes remain separate.
For example:

```text
min(x,y) <= 1 and x <= 3 and y <= 3
boxes       = [[1,3],[3,1]]
visits      = 16
assignments = 12
applicable  = 12
```

The hull `[3,3]` is never manufactured. For the may-zero monus relation:

```text
x <= (3 monus y) and y <= 4
boxes       = [[0,4],[3,3]]
visits      = 21
assignments = 17
applicable  = 11
```

Replacing the relation with equality retains the cover and has five applicable
assignments. These counts distinguish coverage from original-formula replay;
an alternative never replaces the checked precondition.

## Reused limits, precedence, and ranking behavior

The existing `LengthBooleanFiniteUnionLimits` remains the only Boolean-union
limit type. The file ceilings remain:

| Projection | Ceiling |
|---|---:|
| maximum inputs | 8 |
| generated branches | 256 |
| rules per branch | 64 |
| closure inspections per branch | 4096 |
| retained boxes | 256 |
| assignment visits | 262144 |
| unique assignments | 65536 |

An extremum equality contributes three rules to each alternative; a may-zero
monus equality contributes two. Configured caps of two and one report observed
three and two. At the default boundary, the 65th rule reports observed 65.

Input width, generated branch, rule, closure, retained-box, maximum-value,
visit, and unique-assignment failures are ordinary per-candidate admission
misses. Assignment evaluation and enumeration invariant failures map through
the reused Boolean finite-union ranking failures at the exact candidate index.
Association mismatch retains the evidence-replay class. Any such indexed
failure, live failure, deep-forcing failure, or finalization failure restores
literal original order atomically.

A complete counterexample uses the common simplification seam and only its
final vector enters the four-entry newest-first MRU bank. A non-vacuous positive
receipt enters the existing applicable-domain preferred partition; a vacuous
receipt remains neutral. Heuristic and unassessed candidates preserve their
relative order. The two renderers remain capped at 384 characters and report
the model/provider-relative basis, boxes, visits, unique and applicable counts,
explicit vacuity, and at most two boxes with two maxima each. They never print
provider names or collapse the union to a hull.

## Closed v31 and v32 documents

The complete scalar v31 document is the v29 document with only version and
strategy changed:

```json
{
  "format": "leant-live-length-ranking-configuration",
  "version": 31,
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
    "strategy": "strict-relational-positive-affine-quotient-root-extrema-monus-boolean-finite-union-atomic-branching-v1",
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

The complete nominal pair v32 document is the v30 document with only those
same values changed:

```json
{
  "format": "leant-live-length-ranking-configuration",
  "version": 32,
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
    "strategy": "strict-relational-positive-affine-quotient-root-extrema-monus-boolean-finite-union-atomic-branching-v1",
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
strategy, maximum inputs, generated branches, rules per branch, closure
inspections per branch, retained boxes, visits, and unique assignments. Unknown
members precede missing members, and missing members follow that order. The
numeric caps remain 8, 256, 64, 4096, 256, 262144, and 65536. A negative
integer remains `LengthRankingConfigurationFieldValueRejected`, cap plus one
remains `LengthRankingConfigurationPolicyLimitExceeded`, and
`LengthRankingConfigurationBooleanFiniteUnionLimitsRejected` remains only the
defensive checked-builder mapping after file admission. The
full policy demand order remains root, execution admission, execve-check
execution, evaluation, post-`unsat` input box, origin probe, bounded-positive
preference, applicable-domain object, applicable-domain preference,
simplification, deferred opening, scoped-v2 budget, then contract.

The generalized decoder reaches v31/v32 only after the complete v1--v30
cascade returns `UnsupportedVersion`. Every older schema and strategy literal
remains closed and unchanged; version 33 remains unsupported.

## Compatibility matrix

Startup versions are closed strategy selections rather than cumulative feature
levels:

| Versions | Applicable-domain strategy | Launch/lifecycle |
|---|---|---|
| v1--v6 | none | eager pathname/direct spawn |
| v7--v10 | literal-ceiling positive-affine | deferred; v9/v10 shared-v1 budget |
| v11--v14 | relational positive-affine | deferred; v13/v14 scoped-v2 |
| v15--v18 | strict relational positive-affine | scoped-v2; v17/v18 sealed descriptor |
| v19--v22 | root quotient | scoped-v2 sealed descriptor; v21/v22 effective-ID access |
| v23/v24 | root extrema | effective-ID/scoped-v2 |
| v25/v26 | root monus | effective-ID/scoped-v2 |
| v27/v28 | root monus | execve-check/scoped-v2 |
| v29/v30 | Boolean finite union over cumulative root-monus leaves | execve-check/scoped-v2 |
| v31/v32 | atomic-branching finite union | execve-check/scoped-v2 |

The scalar-only compatibility entrance still rejects v4--v32. Every older
decoder rejects v31/v32 or the new strategy wherever its closed schema does
not admit it.

## Lifecycle and identity boundary

Configuration loading, activation, and builder composition perform no IO. The
inherited scoped-v2 batch always captures and checks its deadline clock. If all
candidates finish through MRU or finite-union replay, no executable descriptor
is opened, no source or staged access check runs, no image is staged, and no
worker is launched. The first actual live miss follows v29/v30's exact two
source `faccessat2`/`AT_EXECVE_CHECK` pairs, staged-image exec check, sealed
descriptor launch, deadline, cancellation, and cleanup behavior.

V31/v32 add nominal scalar and product receipt schema identities and the
corresponding evidence and presentation distinctions only. Checked contract,
problem, query, SMT-LIB bytes, fingerprint, association, execution policy,
process, ready worker, fresh/shared/scoped run, and scoped-owner identities are
literal predecessors. The new receipt does not attest Z3, a proof, arbitrary
Boolean logic, a componentwise hull, non-zero-origin regions, source-language
termination, or Lean behavior beyond checked bounded replay.

## Source map and characterization

The pure scalar characterization uses `min(x,y)<=1`, `x<=3`, and `y<=3`.
V31 establishes `[[1,3],[3,1]]`, two boxes, 16 visits, 12 unique assignments,
and 12 applicable assignments; the v29 control retains `[[3,3]]`, one box, 16
visits, 16 unique assignments, and 12 applicable assignments. The nominal pair
characterization uses `(3 monus (2*y))=x`, `x<=3`, and `y<=3`. V32 establishes
`[[0,3],[3,1]]`, two boxes, 12 visits, 10 unique assignments, and four
applicable assignments; the v30 control retains `[[3,3]]`, one box, 16 visits,
16 unique assignments, and four applicable assignments.

- `Leant.Synth.Length.Configuration` owns the pure last-wins builder.
- `Leant.Synth.Length.Configuration.File` owns v31/v32, the exact eight-field
  object, the v1--v30 cascade, and the v33 sentinel.
- Scalar and pair `Ranking.Internal` modules own routing, reused ordinary
  admission misses, indexed failure, preference, MRU, scoped forcing, and the
  fresh nominal assessments.
- `Leant.Synth.Length.Presentation` owns the two bounded renderers.
- The unit suite characterizes exact schemas and caps, compatibility and
  last-wins selection, pure scalar/pair receipts and no-hull counts,
  simplification/MRU, preference and presentation, scoped live/failure routes,
  forcing, and ordinary admission misses.

Djex's exact laws, raw-product accounting, original-literal expansion, limits,
precedence, receipt tags, and authority are recorded in the vendored
[atomic-branching applicable-domain report](../../lib/Djex/docs/reports/2026-08-15-atomic-branching-length-applicable-domain.md).
