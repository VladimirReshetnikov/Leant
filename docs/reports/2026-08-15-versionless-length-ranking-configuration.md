# Versionless live Length ranking configuration

## Status and scope

This checkpoint replaces Leant's historical startup-configuration version
matrix with one current schema. Like every dated report, it is a non-normative
checkpoint summary; the current startup-file reference is
[`docs/length-ranking.md`](../length-ranking.md), backed by the implementation
in `Leant.Synth.Length.Configuration.File`.

Leant is experimental and has no startup-file compatibility commitment. This
change intentionally provides no migration decoder, deprecation period, or
fallback for the former versions 1 through 34. Git history and the earlier
dated reports retain those designs as engineering history. Their statements
about accepted startup versions, version constants, compatibility entrances,
strategy fields, or decoder cascades are non-normative after this checkpoint.
The separate contract-only file grammar remains versioned and is outside this
reset.

## One current root

The startup format literal remains:

```text
leant-live-length-ranking-configuration
```

The root has exactly ten required members:

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

There is no `version` member. `rankingDomain` is the only root-level domain
choice and accepts exactly:

```text
scalar
binary-product
```

`scalar` selects the nominal scalar assessor and full scalar contract grammar.
`binary-product` selects the nominal canonical-`Prod` assessor and the pair
contract grammar, including the required
`resultShape = binary-prod-spines-v1`. The choice never comes from the Lean
goal, and one domain's contract, query, receipt, failure, assessment, MRU state,
or presentation cannot be cast into the other.

## Fixed operational policy

The old matrix primarily encoded successive snapshots of policy choices. The
current decoder instead constructs one policy bundle directly:

- descriptor-bound execve-check executable access;
- the four-entry MRU input replay bank;
- the query-owned all-zero origin probe;
- independent post-`unsat` input-box validation;
- recursive piecewise-affine Boolean finite-union applicable-domain
  validation;
- non-vacuous preference for both applicable-domain and input-box receipts;
- componentwise-lexicographic counterexample simplification;
- deferred session opening; and
- one owner-thread-affine, cooperatively checkpointed scoped usable-work
  deadline.

Consequently, one-choice discriminators are not part of the document. The
reset removes:

- root `counterexampleProbe`;
- root `boundedPositiveOrdering`;
- root `applicableDomainOrdering`;
- root `liveSessionOpening`;
- nested `execution.executableLaunch`;
- nested `applicableDomainValidation.strategy`;
- nested `counterexampleSimplification.strategy`; and
- nested `usableWorkBudget.strategy`.

The remaining nested fields are genuine values and limits. `execution` has the
seven established path, digest, solver-timeout, resource-limit, host-deadline,
artifact-policy, and response-limit fields. `applicableDomainValidation` has
seven numeric limits: inputs, generated branches, rules per branch, closure
inspections per branch, retained boxes, assignment visits, and deduplicated
assignments. Their file caps remain 8, 256, 64, 4096, 256, 262144, and 65536.
`counterexampleSimplification` retains only maximum inputs and maximum
assignments. `usableWorkBudget` retains only milliseconds, capped at 65,000.
The input-box, applicable-domain, and simplification objects remain independent
bounded authorities.

## Decoder order and rejection boundary

The pure decoder retains bounded UTF-8 JSON parsing, duplicate-key rejection,
closed objects, integral-number checks, and the established hard ceilings.
After bounded JSON and root-object admission, semantic demand order is:

1. `format`;
2. `rankingDomain` presence, type, and exact literal;
3. the exact ten-member root;
4. `executionAdmission`;
5. `execution`;
6. `evaluation`;
7. `inputBoxValidation`;
8. `applicableDomainValidation`;
9. `counterexampleSimplification`;
10. `usableWorkBudget`; and
11. the domain-selected contract.

Input object-member order is immaterial. A former startup root is not routed by
its integer or reported as an unsupported version. `version` and every removed
strategy member are simply outside the exact current schema. An untouched
historical root fails first for its missing `rankingDomain`; a root augmented
with a valid domain but still carrying a historical member reaches exact-root
validation and reports that member as unexpected. The public field vocabulary
replaces the removed version-field identity with
`LengthRankingConfigurationRankingDomainField`, and the startup error
vocabulary no longer contains `UnsupportedVersion`.

A successful decode still returns an opaque disabled configuration. Activation
must separately require the sealed digest expectation or explicitly permit an
unpinned executable. Decode and activation are pure: neither opens the source
executable, checks access, stages an image, launches Z3, or creates behavioral
evidence.

## Public-surface reset

`Leant.Synth.Length.Configuration.File` now exports the format constant,
bounded JSON limits and errors, the abstract
`DisabledLengthAssessmentConfiguration`, activation policy and error types,
`decodeLengthAssessmentConfigurationFile`, the contract-only decoder helpers,
and `activateLengthAssessmentConfiguration`.

The reset removes all 34 startup version constants, the unsupported-version
branch, the version field identifier, and the scalar-only disabled/decode/
disable/activate facade. Startup acquisition retains the generalized assessment
loader and removes `loadLengthRankingConfigurationFile`. Integration names the
process-fixed request `startupLengthAssessmentRequest`; it is not a
compatibility route.

The lower-level programmatic policy builders remain available. Their direct,
positive-affine, relational, strict, quotient, extrema, monus, Boolean-union,
atomic-branching, eager/deferred, and v1/v2 budget choices are library
construction tools, not startup JSON alternatives.

## Contract-only grammar remains separate

The command-local format
`leant-finite-list-spine-length-contract` still has the exact three-member root
`format`, `version`, and `contract`. Versions 1 through 5 are scalar; version 6
is the nominal binary-product form. Those numbers select contract expression
and result grammars only. Contract-only files contain no execution, replay,
ordering, simplification, or usable-work policy and cannot override the
activated startup policy.

This distinction is deliberate: removing startup versions does not silently
renumber, reinterpret, or remove contract-only versions.

## Runtime and authority consequences

The reset changes configuration selection, not behavioral authority. An
all-pure batch still captures and checks the scoped deadline without opening an
executable descriptor. The first live miss performs the fixed execve-check
descriptor lifecycle and opens one lexical session for the remaining suffix.
Only independently replayed counterexamples or completed bounded validations
can affect stable ordering. Solver status alone remains heuristic; nothing is
pruned; failures retain the original-order atomic fallback.

The recursive piecewise-affine semantics and nominal receipt families are
unchanged by this reset. Their landing checkpoint is recorded in the
[recursive piecewise-affine Length ranking report](2026-08-15-recursive-piecewise-affine-length-ranking.md),
whose v33/v34 startup discussion is now historical. Djex's semantic boundary
remains in its
[recursive piecewise-affine applicable-domain report](../../lib/Djex/docs/reports/2026-08-15-recursive-piecewise-affine-length-applicable-domain.md).

## Documentation precedence

For the current tree, read sources in this order:

1. the implementation and tests;
2. [`docs/length-ranking.md`](../length-ranking.md) and
   [`docs/synth-internals.md`](../synth-internals.md);
3. this reset report; and
4. earlier dated reports as historical rationale only.

No earlier report establishes a compatibility obligation or overrides the
current versionless startup grammar.
