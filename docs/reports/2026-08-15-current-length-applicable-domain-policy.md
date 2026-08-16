# Current-only Length applicable-domain policy

Date: 2026-08-15

## Outcome

Leant now exposes one applicable-domain ranking policy: the complete recursive
piecewise-affine algorithm. The former public sequence of direct,
positive-affine, relational, strict-relational, root-quotient, root-extrema,
root-monus, Boolean finite-union, atomic-branching, and long recursive policy
families has been deleted.

There are no deprecated aliases, compatibility wrappers, selection shims, or
migration adapters. Leant and Djex are experimental, promise no stability or
backward compatibility, and have no userbase whose source must continue to
compile. The old API ladder represented development checkpoints rather than a
useful current choice. Dated predecessor reports remain available as
non-normative engineering history.

This is a public-surface and policy-description reset. It does not change the
versionless startup or contract-only JSON schemas, the checked Length model,
canonical queries, solver protocol, launch lifecycle, resource caps, replay
authority, or ordering semantics.

## One Leant policy surface

The sole applicable-domain builder is:

```haskell
enableLengthRankingApplicableDomainValidation
  :: LengthInputBoxLimits
  -> LengthBooleanFiniteUnionLimits
  -> LengthRankingPolicy
  -> LengthRankingPolicy
```

`LengthInputBoxLimits` bounds compact-input width and globally unique
assignments. The retained `LengthBooleanFiniteUnionLimits` name identifies the
current branch/rule/closure/box/visit resource-cap record; it is not a switch
for an older Boolean-only algorithm. Applying the builder replaces the one
disabled-or-current applicable-domain policy dimension while preserving all
other policy dimensions.

The preference remains independent:

```haskell
enableLengthRankingNonVacuousApplicableDomainPreference
  :: LengthRankingPolicy -> LengthRankingPolicy
```

It prefers only a completed receipt with a positive applicable-assignment
count. It neither enables validation nor changes the evidence acquired, and a
vacuous receipt remains neutral.

The current assessments are:

```haskell
ApplicableDomainEstablished
  :: ValidatedLengthApplicableDomain
  -> LengthRankingAssessment

LengthSpinePairApplicableDomainEstablished
  :: ValidatedLengthSpinePairApplicableDomain
  -> LengthSpinePairRankingAssessment
```

The operational failures are:

```haskell
LengthRankingApplicableDomainValidationFailed
  :: LengthApplicableDomainValidationError
  -> LengthRankingFailureClass

LengthSpinePairRankingApplicableDomainValidationFailed
  :: LengthSpinePairApplicableDomainValidationError
  -> LengthSpinePairRankingFailureClass
```

Presentation uses only:

```haskell
renderLengthApplicableDomainValidationNote
renderLengthSpinePairApplicableDomainValidationNote
```

These bounded notes report the model/provider-relative basis, canonical
maxima-antichain prefix, box count, raw visits, unique assignments, applicable
assignments, and explicit vacuity. They do not reveal which private fallback
stage established the receipt and do not claim a solver proof, source-level
behavior, global theorem, hull, or pruning authority.

## Short Djex evidence surface

Leant calls the nominal query validators:

```haskell
validateLengthSMTLibQueryApplicableDomain
validateLengthSpinePairSMTLibQueryApplicableDomain
```

Djex also exposes the corresponding checked-problem validators:

```haskell
validateLengthProblemApplicableDomain
validateLengthSpinePairProblemApplicableDomain
```

Their public error families are:

```haskell
LengthApplicableDomainValidationError
LengthSpinePairApplicableDomainValidationError
LengthSMTLibApplicableDomainValidationError
LengthSpinePairSMTLibApplicableDomainValidationError
```

Successful validation returns `ValidatedLengthApplicableDomain` or
`ValidatedLengthSpinePairApplicableDomain`. Each has six nominal projections:

| Scalar | Binary product |
| --- | --- |
| `validatedLengthApplicableDomainInclusiveMaximumBoxes` | `validatedLengthSpinePairApplicableDomainInclusiveMaximumBoxes` |
| `validatedLengthApplicableDomainBoxCount` | `validatedLengthSpinePairApplicableDomainBoxCount` |
| `validatedLengthApplicableDomainAssignmentVisitCount` | `validatedLengthSpinePairApplicableDomainAssignmentVisitCount` |
| `validatedLengthApplicableDomainAssignmentCount` | `validatedLengthSpinePairApplicableDomainAssignmentCount` |
| `validatedLengthApplicableDomainApplicableAssignmentCount` | `validatedLengthSpinePairApplicableDomainApplicableAssignmentCount` |
| `validatedLengthApplicableDomainBasis` | `validatedLengthSpinePairApplicableDomainBasis` |

The scalar and binary-product contracts, problems, queries, failures,
receipts, and assessments remain nominally distinct. Djex's schema-tag bytes
for this evidence are private implementation identity, not exported policy or
format-selection API.

## Private fallback algorithm

The removed public strategy ladder remains only as one ordered internal Djex
implementation:

```text
direct literal -> positive affine -> relational -> strict relational
  -> positive-literal quotient -> root extrema -> root monus
  -> Boolean finite union / atomic branching
  -> recursive piecewise-affine fallback
```

Every normalized signed relation leaf first uses the complete atomic scanner.
The recursive interpreter runs only when that scanner returns its singleton
ignored alternative and minimum, maximum, or natural monus still occurs in a
relation operand. An earlier exact result is retained unchanged rather
than being reinterpreted by a later stage.

The recursive grammar admits compact checked inputs, natural literals,
normalized sums, retained positive scales, binary minimum, binary maximum, and
binary monus. It does not descend through quotient, modulo, a conditional, a
result reference, an out-of-range input, a retained zero scale, or another
unsupported child. An earlier private stage can still handle an entire leaf
whose exact root shape belongs to that stage.

For selected child values `L` and `R`, the exact cases are:

```text
min(L,R)  -> [L <= R;     value L]
           | [R + 1 <= L; value R]
max(L,R)  -> [R <= L;     value L]
           | [L + 1 <= R; value R]
L monus R -> [L <= R;     value 0]
           | [R + 1 <= L; value L - R]
```

The first case owns equality. Left-child cases precede right-child cases,
descendant guards precede the current selector, and the final relation rule is
appended last. Signed coefficients created by a positive monus branch transfer
exactly to the natural positive-sided rule representation. The immutable-
snapshot closure seeds constant-right maxima in rule order. Each pass reads
one snapshot, fires eligible pending rules once in order, and merges newly
derived maxima with `min` only after the pass. A pass with no firing
terminates.

Raw generated-branch admission counts the complete formula-DNF and
recursive-alternative Cartesian product before literal cleanup, guard
contradiction, rule collection, closure, or box cleanup. Canonicalization
removes duplicate literals, drops exact literal/complement branches,
deduplicates equal sets, and absorbs strict supersets. Surviving original
literal sets are re-expanded in set and recursive-alternative order. Every
surviving branch must bound every compact input.

The exact bounded-work precedence is compact-input width, lazy raw branch
count, generated-branch admission, original-literal canonicalization and
re-expansion, per-branch rule admission, per-branch closure-inspection
admission, contradictory-branch removal, first missing compact input, maximal
box-antichain construction, retained-box admission, maximum-value checks in
box/input order, raw assignment visits, unique-assignment materialization,
global original-problem replay, first indexed rejection or counterexample,
receipt construction, and exact query association. Every capped count stops
after observing no more than its limit plus one.

Retained branches form a lexicographically ordered, componentwise-maximal box
antichain. Incomparable boxes are never widened to a hull. Raw visits count box
overlap, a bounded global set deduplicates assignments, and the original
checked precondition and postcondition are replayed once per assignment in
global lexicographic order. Derived guards, rules, boxes, and solver status do
not replace that query-owned replay.

The scalar discriminator retains `[[2,3],[3,2]]`: two boxes, 24 visits, 15
unique assignments, and ten applicable assignments. The binary-product
discriminator retains `[[2,2]]` with 1/9/9/9 box, visit, unique, and applicable
counts. Its 32 raw alternatives distinguish generated-branch caps 31 and 32
before contradictory alternatives disappear.

## Leant orchestration and ordering

Each eligible candidate retains this source order:

```text
four-entry newest-first MRU replay
  -> current applicable-domain traversal
  -> all-zero origin probe
  -> live query and query-first replay
  -> post-unsat explicit input-box traversal
```

An applicable-domain counterexample or establishment completes that candidate
without later stages. An ordinary inapplicable result or bounded admission
refusal continues through origin and live execution. Width, generated-branch,
rule, closure, retained-box, maximum-value, visit, and unique-assignment
admission failures are ordinary misses. Assignment evaluation, internal
enumeration invariants, and exact evidence/query association mismatches are
indexed atomic failures.

Every counterexample source crosses the same optional componentwise-
lexicographic simplification seam, and only the final vector enters the
domain-local MRU. Under deferred opening the MRU/domain/origin prefix remains
before process IO. An all-pure batch opens no worker; the first live miss opens
one lexical session, does not repeat its pure prefix, and processes the suffix
in that scope. A structured failure discards partial assessments and restores
the admitted batch in original order.

With both current preferences enabled, stable order is:

1. non-vacuous applicable-domain evidence;
2. non-vacuous explicit-box evidence;
3. neutral and vacuous assessments; and
4. replayed counterexamples.

Original occurrence order is preserved within each partition. No candidate or
occurrence handle is omitted.

## File schemas are unchanged

The startup document remains one exact versionless ten-member root:

```text
format
rankingDomain
executionAdmission
execution
evaluation
inputBoxValidation
applicableDomainValidation
counterexampleSimplification
usableWorkBudget
contract
```

`rankingDomain` remains exactly `scalar` or `binary-product`. The startup
decoder still constructs descriptor-bound execve-check launch, MRU replay,
origin probing, post-`unsat` input-box validation, both preferences,
counterexample simplification, deferred opening, and the scoped-v2 usable-work
owner beside the current applicable-domain validator.

`applicableDomainValidation` remains an exact seven-member numeric object:

```text
maximumInputs
maximumGeneratedBranches
maximumRulesPerBranch
maximumClosureInspectionsPerBranch
maximumRetainedBoxes
maximumAssignmentVisits
maximumAssignments
```

The caps and their validation order are unchanged. There is no `strategy`
member and no historical algorithm tag in this object.

The command-local contract document remains the exact versionless root
`{format, rankingDomain, contract}`. Both nested contracts still require
exactly `spine`, `targetArgumentRoles`, `candidateCasePolicy`, `precondition`,
`postcondition`, and `providerLaws`; neither admits `resultShape`. Modulo and
positive-literal quotient retain their current grammar and positive-divisor
checks. Contract-only documents select no execution, ranking, replay,
simplification, opening, or budget policy.

## Compatibility and documentation boundary

The deleted public names are not reserved. Reusing the short current names is
intentional: they now denote the only supported current algorithm. Historical
source that imported a predecessor family must be rewritten against current
semantics; the repository provides no automatic translation and accepts no
historical policy tag.

For the current tree, authority order is:

1. source and tests;
2. [`docs/length-ranking.md`](../length-ranking.md) and
   [`docs/synth-internals.md`](../synth-internals.md);
3. this report; and
4. predecessor dated reports as historical rationale only.

Djex's detailed current evidence surface and private fallback are recorded in
its
[current applicable-domain surface report](../../lib/Djex/docs/reports/2026-08-15-current-length-applicable-domain-surface.md).

The code-and-test snapshot preceding the final documentation merge is
`b602dde94a75a7e759a4a1bba7da652fd333b3dc`, with vendored Djex
`da1dd7a316975aa8a9c59022d7dbee879f67a168`. Its
`test-unit/Spec.hs` has 17,603 lines and 391 literal `testCase` tokens; 390
suite cases execute. The focused current applicable-domain group passes 7/7,
the complete Leant suite passes 390/390, and the repository-wide run passes
all 17 suites and 2,193 tests. The final documentation snapshot and rendered
PDF hashes are recorded only after the documentation merge freezes.
