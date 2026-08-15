# Recursive piecewise-affine branching for Length ranking

Date: 2026-08-15

## Outcome

Leant can now select Djex's bounded Boolean finite-union validator with exact
recursive case splitting through piecewise-affine `min`, `max`, and natural
monus expressions. In the current tree, startup configuration version 33
selects the scalar finite-list-spine path and version 34 selects its nominal
canonical-`Prod` sibling. Both retain the complete v31/v32 execution, ranking,
limits, lifecycle, and contract profile and change only the selected
applicable-domain validator and nominal positive receipt family.

Here, “version 33” and “version 34” mean values of the required integer
`version` member in Leant's startup JSON. They are exact decoder branch
selectors in this revision. They are not application releases, SemVer
components, wire-protocol generations, or cumulative feature levels.

Leant is experimental and has made no public stability or backward-
compatibility promise. The version numbers, strategy literal, field layout,
diagnostics, API names, and receipt tags described here may be revised or
replaced before a stable release. Comparisons with v31/v32 characterize the
current regression boundary; they do not commit future Leant versions to
retaining those branches.

The public pure policy builder is:

```haskell
enableLengthRankingStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingRecursivePiecewiseAffineApplicableDomainValidation
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
StrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingRecursivePiecewiseAffineApplicableDomainEstablished
renderLengthStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingRecursivePiecewiseAffineApplicableDomainValidationNote
```

Their nominal product siblings are:

```haskell
LengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingRecursivePiecewiseAffineApplicableDomainEstablished
renderLengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingRecursivePiecewiseAffineApplicableDomainValidationNote
```

The routing reuses the existing closed failures:

```haskell
LengthRankingBooleanFiniteUnionApplicableDomainValidationFailed
LengthSpinePairRankingBooleanFiniteUnionApplicableDomainValidationFailed
```

It adds neither a limit type nor a failure constructor.

The current startup constants are:

```haskell
lengthRankingConfigurationFileStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingRecursivePiecewiseAffineVersion == 33
lengthRankingConfigurationFileSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingRecursivePiecewiseAffineVersion == 34
```

Both require the exact current-tree strategy literal:

```text
strict-relational-positive-affine-quotient-root-extrema-monus-boolean-finite-union-atomic-branching-recursive-piecewise-affine-v1
```

Version 35 is the current next unsupported sentinel. That observation is a
test of this decoder tree, not a reservation of version 35 or a promise that
the numbering scheme will persist.

## Atomic-first recursive boundary

Each signed relational leaf first goes through the complete atomic-branching
scanner selected by v31/v32. Recursive interpretation is attempted only when
that scanner returns exactly one ignored alternative and at least one `min`,
`max`, or monus remains somewhere in a relation operand. A predecessor-
supported leaf is never reinterpreted, so every immediate-root rule stream,
alternative order, and cap observation stays the current parity control.

The recursive grammar admits:

- compact checked inputs and natural literals;
- normalized sums, recursively combined left to right;
- retained positive-literal scales;
- binary minimum and maximum;
- binary natural monus.

It rejects a complete recursive atom when a required descendant contains a
quotient, modulo, expression conditional, result reference, out-of-range
variable, retained zero scale, or any other unsupported expression. The
unsupported child is not erased or approximated. Earlier scanners can still
handle their own exact root-quotient and other predecessor shapes because the
atomic-first gate does not reinterpret them.

For selected signed-affine child values `L` and `R`, descendant guards come
first and the current node then appends these disjoint choices:

```text
min(L,R)
  -> [L <= R; value L]
   | [R + 1 <= L; value R]

max(L,R)
  -> [R <= L; value L]
   | [L + 1 <= R; value R]

L monus R
  -> [L <= R; value 0]
   | [R + 1 <= L; value L - R]
```

The first branch owns equality. Cases are ordered depth first, left child
before right child, then first selector before second. After both relation
operands expand, the relation rule is appended last:

```text
L <= R        -> [L <= R]
not (L <= R)  -> [R + 1 <= L]
L = R         -> [L <= R, R <= L]
```

Generated signed inequalities are transferred exactly to the existing
positive-sided affine-rule representation by moving every negative term to
the opposite side. No checked formula is manufactured and no syntax or public
literal budget is consumed. Selector and relation rules remain ordered and
are not deduplicated, even when two are extensionally equal.

This adds exact handling for nested, embedded, both-root, mixed, and
normalized effectively n-ary extrema/monus expressions within that grammar.
It does not add recursive quotient, modulo, conditional, result-reference, or
general nonlinear reasoning.

## Raw branching, closure, and exact union replay

The established signed formula DNF remains the outer stream. For each raw
formula conjunction, every literal contributes its atomic-first alternative
stream and recursively admitted leaves contribute the Cartesian product of
all child and selector cases:

```text
raw count = sum over raw formula branches
              (product of each literal's complete alternative count)
```

The generated-branch cap observes that stream before complement removal,
deduplication, absorption, selector contradiction, rule collection, closure,
or box cleanup. A recursive case that later proves contradictory still
consumes raw admission work.

After raw admission, canonicalization still operates on sets of original
checked formula literals. Surviving sets are traversed in `Set` order and
re-expanded into recursive coverage alternatives. Rule and closure failure
indices address this expanded canonical stream. Leant and Djex manufacture no
replacement `LengthFormula`, proof-rule set, rule deduplication, or component-
wise hull.

Every live expanded branch must bound every compact input. Its ordered rules
use the existing immutable-snapshot, merge-after-pass, rule-once closure.
Contradictory branches drop; an unbounded live branch makes the complete
attempt ordinarily inapplicable. Bounded branches produce zero-origin boxes,
which are deduplicated and reduced only by componentwise containment.
Incomparable maxima remain separate.

Raw visits sum all retained box cardinalities, including overlap. One global
`Set [Natural]` deduplicates assignments, and its ascending order supplies the
exact replay order. The original checked precondition and postcondition—not
the selector guards or proof rules—remain final authority.

## Characterized scalar and product fixtures

The scalar v33 fixture uses compact inputs `x` and `y` with:

```text
max(x,y) <= 3 monus min(x,y)
x <= 3
y <= 3
```

Recursive validation retains:

```text
boxes        = [[2,3],[3,2]]
box count    = 2
visits       = 24
assignments  = 15
applicable   = 10
basis        = conditional on 1 assumed provider law used by this candidate
```

The v31 atomic control ignores the recursive atom and retains `[[3,3]]`, one
box, 16 visits, 16 unique assignments, and the same 10 applicable assignments.
The equal applicable count does not make that hull exact: it filters six
non-applicable hull assignments and performs one more replay than v33's
15-assignment union. Djex's lower-level direct discriminator is provider-
independent; Leant's characterized scalar candidate intentionally carries one
provider law, which pins propagation of the candidate-specific basis into the
receipt and rendered note.

For the product v34 fixture, define:

```text
u = min(x,y) + (x monus y)
v = min(x,y) + (y monus x)

max(u,v) <= 2
x <= 3
y <= 3
```

Recursive validation retains `[[2,2]]`, one box, nine visits, nine unique
assignments, nine applicable assignments, and a provider-independent basis.
The v32 control retains `[[3,3]]`, one box, 16 visits, 16 unique assignments,
and nine applicable assignments.

The nested product expression has 32 raw alternatives: four cases for `u`,
four for `v`, and two choices for the outer maximum. A generated-branch limit
of 31 rejects it after observing 32; a limit of 32 admits it. Contradictory
cases count on both paths because raw admission precedes closure.

## Reused schema, limits, and diagnostics

V33/v34 are current-tree clones of v31/v32 except for `version` and the
applicable-domain `strategy`. The root still has these required members and
current validation order:

```text
format
version
executionAdmission
execution
evaluation
inputBoxValidation
counterexampleProbe
boundedPositiveOrdering
applicableDomainValidation
applicableDomainOrdering
counterexampleSimplification
liveSessionOpening
usableWorkBudget
contract
```

The applicable-domain object still has exactly eight members:

```text
strategy
maximumInputs
maximumGeneratedBranches
maximumRulesPerBranch
maximumClosureInspectionsPerBranch
maximumRetainedBoxes
maximumAssignmentVisits
maximumAssignments
```

Its numeric ceilings remain 8, 256, 64, 4096, 256, 262144, and 65536.
Unknown members precede missing-member diagnostics; missing members follow the
listed order. A negative integer is
`LengthRankingConfigurationFieldValueRejected`, cap plus one is
`LengthRankingConfigurationPolicyLimitExceeded`, and
`LengthRankingConfigurationBooleanFiniteUnionLimitsRejected` remains only the
defensive checked-builder mapping after file admission.

At this checkpoint the generalized decoder reaches v33/v34 after the current
v1--v32 cascade reports `UnsupportedVersion`; the scalar-only entrance rejects
them. Version 33 chooses a scalar-v5 contract and version 34 chooses the
nominal pair-v5 contract. Both require
`"descriptor-bound-execve-check-executable-access-v1"`, the scoped-v2 usable-
work owner, deferred live opening, both non-vacuous preferences, and the
common counterexample simplifier.

These facts describe current code paths and regression tests only. They do not
promise that older decoders, numeric selectors, or exact diagnostics will be
preserved while Leant remains experimental.

## Ranking, presentation, and lifecycle

Input width, generated branch, rule, closure, retained-box, maximum-value,
visit, and unique-assignment failures are ordinary per-candidate admission
misses. Assignment evaluation and enumeration-invariant failures route through
the reused Boolean finite-union ranking failures at the exact candidate index.
Association mismatch retains the evidence-replay failure class. Any indexed,
live, forcing, or finalization failure restores literal original order
atomically.

A complete counterexample uses the common componentwise-lexicographic
simplifier; only its final vector enters the four-entry newest-first MRU bank.
A non-vacuous recursive receipt enters the applicable-domain preferred
partition, while a vacuous receipt remains neutral. Heuristic and unassessed
candidates keep their relative order.

The scalar and product renderers are capped at 384 characters. They identify
recursive piecewise-affine coverage and report model/provider-relative basis,
box count, raw visits, unique assignments, applicable assignments, explicit
vacuity, and a bounded maxima prefix. They do not expose provider names, call
the union a hull, or claim solver or global-proof authority.

Configuration decoding, activation, and policy construction are pure. Every
v33/v34 batch still captures and checks the inherited scoped-v2 deadline. If
MRU and applicable-domain replay finish the whole batch, Leant opens no
descriptor, performs no source or staged access check, stages no image, and
launches no worker. The first live miss inherits v31/v32's source
`faccessat2`/`AT_EXECVE_CHECK` observations, sealed `MFD_EXEC` image, staged
check, descriptor launch, deadline, cancellation, and cleanup behavior.

## Identity and authority boundary

V33/v34 currently add nominal scalar and product receipt schemas plus their
assessment and presentation branches. They do not revise the checked
contract, behavioral problem, query, SMT-LIB bytes, fingerprint, association,
execution policy, process, ready worker, fresh/shared/scoped run, or scoped-
owner identity.

The receipt establishes only that its exact canonical finite union covers the
checked precondition within admitted bounds and that every unique assignment
in the union was replayed under the checked finite-spine model and retained
provider-law basis. It does not establish Z3 correctness, source-language
termination, a global theorem, behavior outside the checked model, or
authority to prune candidates.

## Source map and characterization

- `Leant.Synth.Length.Configuration` owns the pure tenth last-wins
  applicable-domain builder.
- `Leant.Synth.Length.Configuration.File` owns the current v33/v34 selectors,
  exact inherited objects, v1--v32 dispatch, and v35 sentinel.
- Scalar and pair `Ranking.Internal` modules own routing, ordinary admission
  misses, indexed failures, non-vacuous preference, MRU behavior, scoped deep
  forcing, and the fresh nominal assessments.
- `Leant.Synth.Length.Presentation` owns the two bounded recursive renderers.
- The unit suite characterizes schema/caps/order, current decoder isolation,
  ten-builder last-wins selection, scalar/product fixtures beside v31/v32
  controls, raw 31/32 admission, simplification/MRU, preference,
  presentation, occurrence sealing, scoped/live/failure paths, deadlines, and
  ordinary cap misses.

Djex's exact recursive grammar, selector order, signed-affine transfer, raw
accounting, closure, no-hull replay, receipt tags, precedence, and authority
are recorded in the vendored
[recursive piecewise-affine applicable-domain report](../../lib/Djex/docs/reports/2026-08-15-recursive-piecewise-affine-length-applicable-domain.md).
