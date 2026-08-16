# Length counterexample ranking

*An optional, opt-in last stage of `:synth` that consults Z3 about the
behavior of already-verified candidates and stably reorders them. This
document is the complete reference; the [README](../README.md) gives the
one-paragraph overview and the [manual](Leant.pdf) the user-level tour.*

## What it is, in one screen

After `:synth` has produced candidates and Lean has verified each one, Leant
can additionally ask whether a candidate *behaves* the way you meant. The
first — and so far only — behavioral dialect is **finite list-spine
lengths**: a passive JSON contract states a law over the lengths of a
candidate's list-spine inputs and result (for example, "the result has the
same length as the input"). Each eligible candidate is translated into a
canonical `QF_LIA` query, a scoped Z3 worker is consulted, and any
counterexample Z3 reports is independently re-executed by Leant's vendored
Djex engine against the exact checked problem before it is believed.

Three rules make this safe to use:

- **Nothing is pruned.** A candidate that fails the contract is stably moved
  after the ones that do not; it is still shown, still bound.
- **Raw solver status has no authority.** `sat`, `unsat`, and `unknown` are
  heuristics. Only an independently replayed counterexample (or, under an
  explicit opt-in, an independently completed bounded validation) can move
  a candidate.
- **It is off unless you turn it on.** Without `--length-ranking-config`,
  none of this code runs and no worker is ever launched.

Everything below this line describes the exact behavior of the current tree:
the startup-configuration schema, the current contract-file schema, the
binary-product extension, the replay bank, the origin probe, bounded
validation, and presentation notes. (The module-by-module ownership map lives in
[synth-internals.md](synth-internals.md).) Leant is experimental and makes no
public stability or backward-compatibility promise. Names, numeric selectors,
JSON shapes, tags, diagnostics, and output may be revised before a stable
release. The detail below is a current regression specification, not a promise
to preserve earlier decisions. It is dense by design; read the overview above
first.

---

## Contents

- [Startup configuration file](#startup-configuration-file)
  - [One current schema and fixed policy](#one-current-schema-and-fixed-policy)
  - [Activation, pinning, and worker lifecycle](#activation-pinning-and-worker-lifecycle)
  - [Candidate eligibility](#candidate-eligibility)
- [One-shot contract-only files](#one-shot-contract-only-files)
  - [Command syntax, admission, and lifetime](#command-syntax-admission-and-lifetime)
  - [Scalar contract example](#scalar-contract-example)
  - [Binary-product contract example](#binary-product-contract-example)
  - [Current nested grammar and authority](#current-nested-grammar-and-authority)
- [Binary-product Length queries](#binary-product-length-queries)
  - [Canonical `Prod` eligibility and the serializer boundary](#canonical-prod-eligibility-and-the-serializer-boundary)
  - [Library-level pair query handoff](#library-level-pair-query-handoff)
  - [Live pair ranking and non-vacuous bounded-positive preference](#live-pair-ranking-and-non-vacuous-bounded-positive-preference)
  - [Direct applicable-domain validation](#direct-applicable-domain-validation)
  - [Positive-affine applicable domain and deferred opening](#positive-affine-applicable-domain-and-deferred-opening)
  - [Relational positive-affine extraction](#relational-positive-affine-extraction)
  - [Strict relational positive-affine extraction](#strict-relational-positive-affine-extraction)
  - [Root-quotient consequence extraction](#root-quotient-consequence-extraction)
  - [Root-extrema consequence extraction](#root-extrema-consequence-extraction)
  - [Root-monus consequence extraction](#root-monus-consequence-extraction)
  - [Boolean finite-union applicable domains](#boolean-finite-union-applicable-domains)
  - [Atomic branching inside the finite union](#atomic-branching-inside-the-finite-union)
  - [Recursive piecewise-affine branching](#recursive-piecewise-affine-branching)
  - [Shared usable-work budget (v1)](#shared-usable-work-budget-v1)
  - [Scoped usable-work lease (v2)](#scoped-usable-work-lease-v2)
  - [Counterexample simplification](#counterexample-simplification)
  - [Per-candidate execution order and stable ordering](#per-candidate-execution-order-and-stable-ordering)
  - [Domain-neutral limits and product-specific authority](#domain-neutral-limits-and-product-specific-authority)
- [Current startup configuration examples](#current-startup-configuration-examples)
  - [Scalar startup configuration](#scalar-startup-configuration)
  - [Binary-product startup configuration](#binary-product-startup-configuration)
  - [Schema and validation order](#schema-and-validation-order)
- [Pair contracts, decoders, and reports](#pair-contracts-decoders-and-reports)
  - [Using a binary-product contract document with `:synth`](#using-a-binary-product-contract-document-with-synth)
  - [Pair contract grammar and validation order](#pair-contract-grammar-and-validation-order)
  - [Decoder separation and reports](#decoder-separation-and-reports)
- [Presentation notes on the Main path](#presentation-notes-on-the-main-path)

## Startup configuration file

### One current schema and fixed policy

Finite-list-spine Length counterexample ranking is disabled by default. To opt
in, pass `--length-ranking-config` with an explicitly chosen absolute path to
one current, versionless configuration file. The root contains no `version`
member. Its required `rankingDomain` member is exactly `"scalar"` or
`"binary-product"`; that choice selects the nominal result domain and the
corresponding contract grammar.

The file configures numeric limits, the executable and its budgets, and the
passive contract. It does not expose one-member strategy switches. Every
accepted startup file selects the current policy bundle:

- descriptor-bound execve-check executable access;
- the four-entry MRU replay bank followed by the all-zero origin probe;
- independent post-`unsat` input-box validation;
- recursive piecewise-affine Boolean finite-union applicable-domain
  validation;
- non-vacuous preference for both applicable-domain and input-box receipts;
- componentwise-lexicographic counterexample simplification;
- deferred session opening; and
- one owner-thread-affine, cooperatively checkpointed scoped usable-work
  deadline.

The three bounded traversal authorities remain independent: input-box,
applicable-domain, and simplification limits cannot substitute for one another.
The recursive applicable-domain strategy first uses its complete atomic
predecessor and recursively expands only otherwise ignored relational leaves
whose supported signed-affine summaries contain minimum, maximum, or monus.
Quotient, modulo, conditional, result-reference, zero-scale, and other
unsupported descendants reject the complete recursive fallback atom.

This reset deliberately removed the historical startup selectors and their
parallel schemas. A historical file is not migrated or dispatched through an
older decoder. An untouched old root fails first because it has no required
`rankingDomain`; if a valid `rankingDomain` is added while `version` or another
removed member remains, exact-root validation rejects that member as
unexpected. Leant is experimental, so Git history and the dated reports record
the old shapes without obliging the executable to continue accepting them. The
separate contract-only format is likewise one current versionless schema and
is described below.

### Activation, pinning, and worker lifecycle

Leant admits and reads that file
once at startup, requires the configuration to contain an executable SHA-256
expectation by default, and retains the decoded contract selection as a fixed
process-wide assertion. Presence at activation is not a digest match; Djex
compares the expectation only when an eligible batch later opens a worker. The
current launcher opens the source once, requires two point-in-time effective-ID
VFS execute-access observations and two descriptor-bound source
`AT_EXECVE_CHECK` observations, copies the bytes into a sealed `MFD_EXEC` main
image, and checks that staged descriptor once before child allocation. None of
those observations is a reservation or complete future execution decision.
`--length-ranking-allow-unpinned` is a separate explicit relaxation;
`--length-ranking-config-timeout` sets only the bounded file-load interruption
budget (default 5,000 ms, maximum 60,000 ms). No option discovers a file or
solver. POSIX configuration-file descriptor acquisition is implemented;
Windows currently fails
closed. The current route completes admission and preparation, then runs each
candidate's pure MRU, recursive applicable-domain, and origin prefix before IO.
An all-pure batch opens no process; the first live miss opens one lexical
session for that query and the remaining suffix. The batch captures one
dynamically scoped usable-work owner after the 64-candidate admission gate and
before full preparation. Preparation, deferred pure work, opening, every live
query, result materialization, and cooperative phase checkpoints consume that
one absolute deadline. Any structured failure preserves callback order through
the established atomic fallback.
The opaque activated mode retains the exact require-pin or permit-unpinned
decision that released it, and Main derives its startup notice from that mode
rather than reinterpreting the raw command-line flag.

### Candidate eligibility

Only callback-verified candidates with direct or exact-duplicate-recovered
typed Exference authority are eligible. Candidates with neither authority
remain in place with a payload-free preparation refusal and do not open a
worker by themselves. The default `djinn` synthesis engine supplies no typed
graph; select `:set synth-engine exference` or `both` to produce candidates
which may reach this ranking path.

## One-shot contract-only files

### Command syntax, admission, and lifetime

After startup activation, one command may replace only the fixed startup
contract selection with an explicitly named contract-only document:

```text
:synth --length-contract ABSOLUTE-PATH -- TYPE
```

The standalone `--` is mandatory and keeps the remaining text opaque Lean goal
syntax. The path may contain spaces, but a standalone `--` inside it is
reserved as the delimiter. Leant first requires an activated startup policy;
when ranking is disabled it rejects the option before path admission or file
IO. Otherwise it admits and reads that absolute POSIX path once, before goal
translation, using a fixed 5,000-ms interruption budget and the same 256-KiB
JSON ceiling as the startup file. The separate contract-only root has exactly
`format`, `rankingDomain`, and `contract`; it has no `version` member. `format`
is `leant-finite-list-spine-length-contract`, and `rankingDomain` is exactly
`"scalar"` or `"binary-product"`. That field alone selects the nominal scalar
or pair decoder. The nested contract never contains a second domain marker such
as `resultShape`.

The file is parsed once through the bounded JSON parser and one current decoder.
There is no version dispatcher, migration pass, compatibility fallback, or
retry through another domain. A historical root without `rankingDomain` fails
at that required field. If a valid domain is added while `version` remains,
exact-root validation rejects the extra member. The current schema always
requires explicit target roles and an explicit case policy, and always admits
the current modulo and positive-literal quotient grammar.

A contract-only file cannot
replace the executable, pin choice, solver limits, artifact policy, or replay
limits. The decoded contract selection is carried only through
that command's ordinary, universe-retry, provider, and classical synthesis
lanes; it is not stored in `ReplState`, `ParsedGoal`, snapshots, history, or a
cache, and later commands return to the startup-fixed contract unless they name
their own file. Malformed option syntax is rejected rather than silently
treated as a goal.

### Scalar contract example

A current scalar contract document is:

```json
{
  "format": "leant-finite-list-spine-length-contract",
  "rankingDomain": "scalar",
  "contract": {
    "spine": {"family": "List", "zero": "List.nil", "step": "List.cons"},
    "targetArgumentRoles": ["observed-spine"],
    "candidateCasePolicy": "cases-rejected",
    "precondition": ["truth", true],
    "postcondition": [
      "equal",
      ["result"],
      ["sum", [
        ["modulo", 2, ["input", 0]],
        ["quotient", 2, ["input", 0]]
      ]]
    ],
    "providerLaws": []
  }
}
```

The scalar grammar admits `["result"]`; it rejects pair result references.

### Binary-product contract example

The same root selects the nominal pair grammar through `rankingDomain`; there
is no nested `resultShape`:

```json
{
  "format": "leant-finite-list-spine-length-contract",
  "rankingDomain": "binary-product",
  "contract": {
    "spine": {"family": "List", "zero": "List.nil", "step": "List.cons"},
    "targetArgumentRoles": ["observed-spine"],
    "candidateCasePolicy": "cases-rejected",
    "precondition": ["truth", true],
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

Only pair result references `["result", "first"]` and
`["result", "second"]` are admitted in that domain. The domain remains
nominal: a scalar result reference fails in the pair decoder and a pair result
reference fails in the scalar decoder.

### Current nested grammar and authority

Both selected contract objects have exactly six members, validated in this
order after their exact shape is admitted: `spine`, `targetArgumentRoles`,
`candidateCasePolicy`, `precondition`, `postcondition`, and `providerLaws`.
All field names, enum values, and syntax tags are case-sensitive.

The target-role array is always explicit, is bounded to eight entries, and must
match the complete physical target argument spine after leading quantifiers.
Leant never infers it from the target, a provider name, a provider scheme, or a
candidate. Only `"observed-spine"` positions must have the configured
list-spine type. They receive compact contract indices in observed-position
order. Provider-law roles are different: they align with every physical
provider argument, and `["argument", n]` in a transfer keeps that physical
index rather than being renumbered through the target-role projection.

`"unobserved-target"` means only that the checked Length interpreter carries a
non-inspectable token at that position and may pass it through a non-demanding
path, including forwarding it to an explicitly `"unobserved"` provider
argument. Calling, spine-observing, or tuple-destructuring the token rejects
candidate preparation. The role makes no claim about whether the source type
is inhabited, whether a source implementation evaluates the argument, or
about purity, totality, parametricity, strictness, or effects.

`candidateCasePolicy` is also always explicit. `"cases-rejected"` preserves the
singleton, ordinal-zero renderer rule. `"exact-spine-zero-step-v1"` enables the
one nonempty case shape currently modeled by Length. The policy is not inferred
from a graph. Exference must independently retain a
checked complete case over the exact recursive two-constructor spine, with one
zero-field constructor and one two-field constructor whose single recursive
field is the scrutinized spine. Djex freshly re-seals that graph against the
contract-resolved `List` schema. The zero branch receives length zero; the step
branch receives an opaque payload and a tail length `input monus 1`; the whole
case retains the union of provider laws reached by either branch. Every other
case shape fails closed.

This remains a bounded model-relative interpretation. It does not prove Lean
purity, totality, termination, strictness, source-level equivalence, or a
provider law, and it grants no pruning authority. The selection is command-local
and leaves no role or case-policy state behind.

The current expression grammar includes input/result or provider-argument
variables, natural literals, sums, scaling, monus, minimum, maximum,
conditionals, `["modulo", positiveLiteral, expression]`, and
`["quotient", positiveLiteral, expression]`. Both arithmetic tags are accepted
in preconditions, postconditions, and provider transfers. The divisor is
checked before its operand, must be nonzero, and is bounded by the same 256-bit
numeral limit as every contract literal.

Leant retains the passive syntax. Djex lowers each surviving operation to a
private Euclidean witness shape `e = k*q + r`, `q >= 0`, `r >= 0`, and
`r <= k-1`, then projects the remainder for modulo or the quotient for
quotient. It emits no SMT-LIB `mod` or `div`; private witnesses never enter
`get-value` or presentation, and replay independently recomputes Natural
arithmetic from the original inputs.

After bounded JSON and root-object admission, validation checks format
presence/type/value, then `rankingDomain` presence/type/value, then the exact
three-member root. Exact-root validation reports an unexpected member before a
remaining missing member. The `contract` must then be an object, after which
the selected decoder admits the exact six-member nested shape and checks spine,
roles, case policy, precondition, postcondition, and provider laws in that
order. JSON object-member order does not alter this precedence.

The command-local selection contains no execution, ranking, replay,
simplification, ordering, or budget policy. Its file is read once before goal
translation and the same request is carried through ordinary, retry, provider,
and classical lanes. It never enters `ReplState`, history, snapshots, or a
cache; a later command returns to the startup-fixed contract unless it names
another file.

## Binary-product Length queries

### Canonical `Prod` eligibility and the serializer boundary

Leant also has a library-level, fail-closed handoff for a result whose root,
after the serializer's existing `whnfR` normalization, is saturated canonical
Lean `Prod` and whose two source-ordered fields are applications of the same
configured finite spine. Reducible aliases to `Prod` are admitted only after
that normalization; normalized `And` and `PProd` remain ineligible. Canonical
`Prod` retains a private provenance marker through translation, while search
and rendering continue to treat it as an ordinary boxed pair.
That marker matters only at the behavioral boundary: proposition-valued
`And`, sort-polymorphic `PProd`, a scalar result, a nested product, and a
product with either non-spine field are rejected even though some share the
same structural pair representation.

The serializer acquisition boundary also requires exactly one matching
`(goal ...)` info envelope. An extra goal-shaped message fails closed instead
of letting caller-controlled elaboration output shadow the serializer's real
normalized result.

### Library-level pair query handoff

For example, an integration can describe the callback-verified candidate
`fun xs => (xs, xs)` for the Lean goal `List Nat → List Nat × List Nat`
with a contract equating each result-field length to the one observed input
length:

```haskell
pairContract :: LeanLengthSpinePairContract
pairContract = LeanLengthSpinePairContract
  { leanLengthSpinePairContractSpine =
      LeanLengthSpineIdentity "List" "List.nil" "List.cons"
  , leanLengthSpinePairContractTargetArgumentRoles =
      [LengthObservedSpine]
  , leanLengthSpinePairContractCandidateCasePolicy =
      LeanLengthCasesRejected
  , leanLengthSpinePairContractSource = LengthSpinePairContractSource
      { lengthSpinePairContractPrecondition = LengthTruth True
      , lengthSpinePairContractPostcondition = LengthAll
          [ LengthEqual
              (LengthVariable
                (LengthSpinePairResult LengthSpinePairFirst))
              (LengthVariable (LengthSpinePairInput 0))
          , LengthEqual
              (LengthVariable
                (LengthSpinePairResult LengthSpinePairSecond))
              (LengthVariable (LengthSpinePairInput 0))
          ]
      }
  , leanLengthSpinePairContractProviderLaws = []
  }

queryResult = prepareCheckedLengthSpinePairQuery pairContract verified
```

Here `verified` is the existing callback-verified candidate carrying its exact
Exference origin; the example does not manufacture that authority. The
handoff reuses the scalar path's exact origin checks, configured-spine and
provider resolution, candidate-case/target-role policy, and sealed session
authority. It does not invent a semantic-family binding for Lean's built-in
`Prod`. Djex then seals a nominally distinct binary-product contract, problem,
and canonical QF_LIA query. Product model, saved-input, origin, and finite-box
replay remain pure query-owned operations, and only independently evaluated
and associated values can become model-relative counterexample evidence. Raw
`sat`, `unsat`, or `unknown` status has no authority.

### Live pair ranking and non-vacuous bounded-positive preference

That first checkpoint was deliberately offline. The library now also exposes
the product-specific live runner, ranking, post-verification, and presentation
path. The bounded-positive ordering choice is an orthogonal, explicit policy
derivation. For example, integrations for either domain can enable the same
finite box and origin probe, then opt into preferring only non-vacuous positive
receipts:

```haskell
let preferredPolicy =
      enableLengthRankingNonVacuousInputBoxPreference
        $ enableLengthRankingOriginProbe
        $ enableLengthRankingInputBoxValidation
            inputBoxLimits [3] basePolicy

scalarAssessment <- assessVerifiedLengthCandidatesWithPolicy
  preferredPolicy scalarContract verificationBatch

assessment <- assessVerifiedLengthSpinePairCandidatesWithPolicy
  preferredPolicy pairContract verificationBatch

let present candidate = do
      putStrLn $ lengthCandidatePresentationText candidate
      mapM_ putStrLn $ lengthCandidatePresentationNote candidate

mapM_ present
  $ presentLengthSpinePairPostVerificationResult assessment
```

Here `basePolicy` is a `LengthRankingPolicy` returned by
`mkLengthRankingPolicy`, `inputBoxLimits` is a checked Djex
`LengthInputBoxLimits`, `[3]` is the source-ordered inclusive maximum for this
example's one modeled input, and `verificationBatch` is Leant's occurrence-
sealed callback batch. A caller which already owns a plain list of verified
receipts can instead call
`rankVerifiedLengthSpinePairCandidatesWithPolicy`; the post-verification form
keeps each reordered receipt attached to its exact occurrence through the
permutation seal. The three policy builders are persistent and order
independent. Without
`enableLengthRankingNonVacuousInputBoxPreference`, completed positive receipts
retain their historical neutral ordering.

### Direct applicable-domain validation

The directly bounded applicable-domain pass is a separate programmatic opt-in.
For a concrete one-input scalar contract and its nominal pair sibling, the
relevant checked preconditions and reusable policy are:

```haskell
scalarDirectBound = LengthAtMost
  (LengthVariable (LengthInput 0)) (LengthLiteral 3)

pairDirectBound = LengthAtMost
  (LengthVariable (LengthSpinePairInput 0)) (LengthLiteral 3)

let applicablePolicy =
      enableLengthRankingNonVacuousApplicableDomainPreference
        $ enableLengthRankingApplicableDomainValidation
            inputBoxLimits
        $ enableLengthRankingOriginProbe basePolicy

scalarAssessment <- assessVerifiedLengthCandidatesWithPolicy
  applicablePolicy
  scalarContract { leanLengthContractSource =
    scalarSource { lengthContractPrecondition = scalarDirectBound } }
  verificationBatch

pairAssessment <- assessVerifiedLengthSpinePairCandidatesWithPolicy
  applicablePolicy
  pairContract { leanLengthSpinePairContractSource =
    pairSource { lengthSpinePairContractPrecondition = pairDirectBound } }
  verificationBatch
```

`enableLengthRankingApplicableDomainValidation` supplies only the checked
width/cardinality limits. Djex derives the tight inclusive maxima from direct
normalized `input <= literal` clauses; Leant supplies no maxima and consumes
no solver status. `enableLengthRankingNonVacuousApplicableDomainPreference`
is independent: without it, even an established applicable-domain receipt is
neutral. These builders work for both domain-specific assessors, while the
scalar `ApplicableDomainEstablished` and pair
`LengthSpinePairApplicableDomainEstablished` assessments and receipts remain
nominally separate. The snippets assume `scalarSource` and `pairSource` are the
otherwise complete passive contract sources used to build the surrounding
contracts, and that `basePolicy`, `inputBoxLimits`, and `verificationBatch`
have the same checked meanings as in the preceding example.

### Positive-affine applicable domain and deferred opening

The additive positive-affine rule and deferred opening are also explicit
programmatic choices. This composition uses three independently checked limit
values: `postUnsatLimits` plus the caller-supplied `[5]` box,
`applicableDomainLimits`, and `simplificationLimits`:

```haskell
let advancedPolicy =
      enableLengthRankingDeferredLiveSessionOpening
        $ enableLengthRankingCounterexampleSimplification
            simplificationLimits
        $ enableLengthRankingNonVacuousApplicableDomainPreference
        $ enableLengthRankingPositiveAffineApplicableDomainValidation
            applicableDomainLimits
        $ enableLengthRankingNonVacuousInputBoxPreference
        $ enableLengthRankingOriginProbe
        $ enableLengthRankingInputBoxValidation
            postUnsatLimits [5] basePolicy

scalarAssessment <- assessVerifiedLengthCandidatesWithPolicy
  advancedPolicy scalarPositiveAffineContract verificationBatch

pairAssessment <- assessVerifiedLengthSpinePairCandidatesWithPolicy
  advancedPolicy pairPositiveAffineContract verificationBatch
```

For example, `scalarPositiveAffineContract` may use the normalized
precondition `input 0 + 1 <= 4`; the positive-affine rule derives maximum `3`
without changing the actual precondition replayed at each assignment. The
literal-ceiling positive-affine and historical direct applicable-domain
builders select different rules. All other builders above are persistent and
orthogonal. Deferred opening is operational policy, not evidence, and adds no
presentation note.

### Relational positive-affine extraction

Relational positive-affine extraction is a third explicit selection. This
programmatic example replaces `advancedPolicy`'s literal-ceiling extractor but
retains its independent limits, ordering preferences, simplification, origin
probe, post-`unsat` box, and deferred opening:

```haskell
let relationalPolicy =
      enableLengthRankingRelationalPositiveAffineApplicableDomainValidation
        applicableDomainLimits advancedPolicy

scalarAssessment <- assessVerifiedLengthCandidatesWithPolicy
  relationalPolicy scalarRelationalContract verificationBatch

pairAssessment <- assessVerifiedLengthSpinePairCandidatesWithPolicy
  relationalPolicy pairRelationalContract verificationBatch
```

For example, `scalarRelationalContract` may combine `input 0 == input 1`
with `input 1 <= 5`, deriving inclusive maxima `[5, 5]` through the relation.
`pairRelationalContract` may use `2 * input 0 <= input 0 + 1`; exact
coefficient cancellation derives maximum `[1]`. The direct,
literal-ceiling-positive-affine, and relational-positive-affine builders are
mutually exclusive and last-wins; none changes the actual precondition replayed
over the derived box. Complete scalar traversal produces
`RelationalPositiveAffineApplicableDomainEstablished`, while the nominal pair
path produces
`LengthSpinePairRelationalPositiveAffineApplicableDomainEstablished`.
Presentation uses
`renderLengthRelationalPositiveAffineApplicableDomainValidationNote` or
`renderLengthSpinePairRelationalPositiveAffineApplicableDomainValidationNote`.
Those notes describe bounded, model/provider-relative evidence; selecting the
policy itself produces no evidence or pruning authority.

### Strict relational positive-affine extraction

Strict relational positive-affine extraction is the additive fourth selection.
It retains every ordinary relation supported above and adds only the exact
natural complement of an immediate normalized top-level at-most clause:

```text
not (L <= R)  <=>  R + 1 <= L
```

The following composition replaces only `relationalPolicy`'s applicable-domain
rule, then independently selects the scoped usable-work owner:

```haskell
usableWorkBudget <- either (fail . show) pure $
  mkLengthSMTLibLiveUsableWorkBudget
    LengthSMTLibLiveUsableWorkBudgetSource
      { lengthSMTLibLiveUsableWorkBudgetSourceMilliseconds = 30000 }

let strictPolicy =
      enableLengthRankingStrictRelationalPositiveAffineApplicableDomainValidation
        applicableDomainLimits relationalPolicy
    strictScopedPolicy =
      enableLengthRankingScopedUsableWorkBudget
        usableWorkBudget strictPolicy

scalarAssessment <- assessVerifiedLengthCandidatesWithPolicy
  strictScopedPolicy scalarStrictContract verificationBatch

pairAssessment <- assessVerifiedLengthSpinePairCandidatesWithPolicy
  strictScopedPolicy pairStrictContract verificationBatch
```

For example, top-level clauses `not (5 <= input 0)` and
`not (input 0 <= input 1)` derive inclusive maxima `[4, 3]`. A product clause
`not (input 0 + 3 <= 2 * input 0)` first becomes
`2 * input 0 + 1 <= input 0 + 3`; exact coefficient cancellation derives
maximum `[2]`. The successor is proof-only and precedes cancellation. It never
rewrites the checked contract or SMT query. Negated equality, nested negation,
and a negated comparison containing monus, minimum, maximum, quotient, modulo,
or a conditional grant no bound. Unsupported clauses remain part of actual
precondition replay when another clause supplies complete coverage.

All seven applicable-domain builders are mutually exclusive and last-wins; the
budget builder is orthogonal and last-wins only within the v1/v2 budget
dimension. The strict pass retains the same MRU-before-domain order,
query-owned counterexample simplification, non-vacuous stable preference,
deferred lifecycle, atomic fallback, and model/provider-relative authority as
the relational pass. Here *strict* means natural strict comparison, not source
evaluation strictness. See the
[strict relational positive-affine Length ranking report](reports/2026-08-15-strict-relational-positive-affine-length-ranking.md).

### Root-quotient consequence extraction

The additive root-quotient successor replaces only that policy dimension:

```haskell
let quotientPolicy =
      enableLengthRankingStrictRelationalPositiveAffineQuotientApplicableDomainValidation
        applicableDomainLimits strictScopedPolicy

scalarAssessment <- assessVerifiedLengthCandidatesWithPolicy
  quotientPolicy scalarQuotientContract verificationBatch

pairAssessment <- assessVerifiedLengthSpinePairCandidatesWithPolicy
  quotientPolicy pairQuotientContract verificationBatch
```

For positive `d`, positive-affine `A` and `B`, and Natural values, the only
new proof rules are:

```text
q_d(A) <= B        => A <= d*B + (d - 1)
A <= q_d(B)        => d*A <= B
not (q_d(A) <= B)  => d*(B + 1) <= A
not (A <= q_d(B))  => B + 1 <= d*A
```

Top-level equality contributes both directed non-strict rules in source
orientation. Exactly one relation side may have a quotient at its operand
root. A quotient nested below another quotient or embedded in a sum, scale,
minimum, maximum, monus, modulo, or conditional; quotients at both relation
roots; and unsupported whole formulas grant no coverage rule. Quotient-free
clauses delegate to the strict predecessor byte-for-byte. Extracted rules use
the established source-ordered, synchronous rule-once closure, and only a
complete query-owned replay can release either
`StrictRelationalPositiveAffineQuotientApplicableDomainEstablished` or
`LengthSpinePairStrictRelationalPositiveAffineQuotientApplicableDomainEstablished`.
Their public notes are rendered by
`renderLengthStrictRelationalPositiveAffineQuotientApplicableDomainValidationNote`
and
`renderLengthSpinePairStrictRelationalPositiveAffineQuotientApplicableDomainValidationNote`.
See the
[strict relational positive-affine quotient Length ranking report](reports/2026-08-15-strict-relational-positive-affine-quotient-length-ranking.md).

### Root-extrema consequence extraction

The additive root-extrema successor again replaces only the applicable-domain
policy dimension:

```haskell
let extremaPolicy =
      enableLengthRankingStrictRelationalPositiveAffineQuotientRootExtremaApplicableDomainValidation
        applicableDomainLimits quotientScopedPolicy

scalarAssessment <- assessVerifiedLengthCandidatesWithPolicy
  extremaPolicy scalarRootExtremaContract verificationBatch

pairAssessment <- assessVerifiedLengthSpinePairCandidatesWithPolicy
  extremaPolicy pairRootExtremaContract verificationBatch
```

For positive-affine `A`, `B`, and `C`, the only new proof rules are:

```text
max(A,B) <= C        => A <= C       and B <= C
C <= min(A,B)        => C <= A       and C <= B
not (min(A,B) <= C)  => C + 1 <= A   and C + 1 <= B
not (C <= max(A,B))  => A + 1 <= C   and B + 1 <= C
```

Equality is necessary-only in both source orientations: `max(A,B) = C` and
`C = max(A,B)` emit only the first pair, while `min(A,B) = C` and
`C = min(A,B)` emit only the second pair. No equality form emits a sufficient
or converse direction. Exactly one side may contain one immediate binary
extremum at its operand root, and the other side must be root-extrema-free.
Each accepted clause emits both rules atomically. Nested or effectively n-ary
extrema, extrema at both relation roots, mixed `min`/`max` roots, the wrong or
disjunctive orientations, negated equality, embedded extrema, unsupported
operands, and unsupported whole formulas grant no partial coverage rule.

Root-extrema-free clauses delegate to the quotient predecessor literally.
Accepted clauses, extrema operands, and emitted rules retain normalized
canonical order. The established synchronous rule-once closure reads
immutable pass snapshots, merges candidate maxima with `min` after the pass,
reports contradiction before missing coverage, and otherwise reports the first
compact missing input. The original normalized formula is still replayed even
when another clause establishes complete coverage, so extraction never replaces
behavioral authority. Only a complete query-owned replay can release
`StrictRelationalPositiveAffineQuotientRootExtremaApplicableDomainEstablished`
or
`LengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaApplicableDomainEstablished`.
Their public notes are rendered by
`renderLengthStrictRelationalPositiveAffineQuotientRootExtremaApplicableDomainValidationNote`
and
`renderLengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaApplicableDomainValidationNote`.
Operational failure preserves the existing atomic fallback and original
ordering; the new receipt tags do not revise problem, query, fingerprint, or
association identity. See the
[root-extrema Length ranking report](reports/2026-08-15-root-extrema-length-ranking.md)
and Djex's
[root-extrema applicable-domain report](../lib/Djex/docs/reports/2026-08-15-root-extrema-length-applicable-domain.md).

### Root-monus consequence extraction

The cumulative root-monus successor likewise replaces only the
applicable-domain policy dimension:

```haskell
let monusPolicy =
      enableLengthRankingStrictRelationalPositiveAffineQuotientRootExtremaMonusApplicableDomainValidation
        applicableDomainLimits extremaScopedPolicy

scalarAssessment <- assessVerifiedLengthCandidatesWithPolicy
  monusPolicy scalarRootMonusContract verificationBatch

pairAssessment <- assessVerifiedLengthSpinePairCandidatesWithPolicy
  monusPolicy pairRootMonusContract verificationBatch
```

Let `M = A monus B = max(A-B,0)`, and let the opposite positive-affine
operand have the exact summary `C = c + sum(k_i*x_i)`. After atomically
summarizing all three operands, the scanner admits only these five normalized
relation shapes:

```text
M <= C        <=> A <= B + C
C <= M        <=> B + C <= A                    when c > 0
not (M <= C)  <=> B + C + 1 <= A
not (C <= M)  <=> 1 <= C and A + 1 <= B + C
M = C or C=M  =>  A <= B + C; also B + C <= A  when c > 0
```

The reverse non-strict law is unconditionally
`C <= M <=> C = 0 or B+C <= A`. The exact affine constant therefore defines
the admission boundary. If `c > 0`, `C` is uniformly positive and the single
affine rule is exact. If `c = 0` and the coefficient map is empty, `C` is
identically zero and the relation is tautological, so it emits no rule. If
`c = 0` with coefficients, `C` may be zero and the whole clause is ignored;
the current single-rectangle receipt cannot represent that union. Positivity
is clause-local and never borrowed from another clause. The implementation
does not replace the exact disjunction with the weaker necessary rule
`C <= A`.

Equality in either root orientation always emits the necessary supported half
`A <= B+C`; it appends `B+C <= A` second only when `c > 0`. An identically-zero
opposite therefore gives the exact `A <= B`, while a may-zero affine opposite
keeps only the first, necessary consequence. That consequence is not claimed
to characterize the equality. The reverse strict case emits `1 <= C` first
and `A+1 <= B+C` second. All rules for a clause are retained only after `A`,
`B`, and `C` have each summarized in the compact-input/literal/sum/positive-
scale grammar.

Exactly one relation operand may be an immediate retained binary root monus.
Literal/literal monus, `A monus 0`, and `A monus A` may normalize away and
then delegate to the root-extrema predecessor. Both-root, nested, embedded,
mixed monus/quotient/extrema, unsupported-child, negated-equality, and nested
Boolean shapes grant no partial rule. Canonical normalized clause order and
the inherited synchronous immutable-snapshot, eligible-rule-once closure are
unchanged. Contradiction wins before the first compact missing input; value
and Cartesian limits, indexed evaluation failure, first counterexample, and
query association retain their existing order. Exhaustive replay still uses
the original normalized formula, never the proof summaries.

Only complete query-owned replay can release
`StrictRelationalPositiveAffineQuotientRootExtremaMonusApplicableDomainEstablished`
or
`LengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusApplicableDomainEstablished`.
Their public notes use
`renderLengthStrictRelationalPositiveAffineQuotientRootExtremaMonusApplicableDomainValidationNote`
and
`renderLengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusApplicableDomainValidationNote`.
Operational failure still restores literal original order atomically, and the
additive receipt identities revise no problem, query, association, executable,
or scoped-owner identity. See the
[root-monus Length ranking report](reports/2026-08-15-root-monus-length-ranking.md)
and Djex's
[root-monus applicable-domain report](../lib/Djex/docs/reports/2026-08-15-root-monus-length-applicable-domain.md).

### Boolean finite-union applicable domains

The eighth applicable-domain strategy makes the Boolean union explicit while
retaining the complete root-monus leaf scanner:

```haskell
let finiteUnionPolicy =
      enableLengthRankingStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionApplicableDomainValidation
        applicableDomainLimits booleanFiniteUnionLimits monusScopedPolicy

scalarAssessment <- assessVerifiedLengthCandidatesWithPolicy
  finiteUnionPolicy scalarBooleanContract verificationBatch

pairAssessment <- assessVerifiedLengthSpinePairCandidatesWithPolicy
  finiteUnionPolicy pairBooleanContract verificationBatch
```

The builder takes the existing `LengthInputBoxLimits` and a separately checked
`LengthBooleanFiniteUnionLimits`. Like every applicable-domain builder it is
mutually exclusive and last-wins; it preserves launch, evaluation, origin
probing, the independent post-`unsat` box, both preferences, simplification,
deferred opening, and the selected usable-work owner.

Djex expands the already normalized formula with exact proof polarity. Positive
conjunction takes the Cartesian conjunction of child DNFs; negative
conjunction takes their union; `not` flips polarity; positive equality is one
leaf; and negative equality is exactly the two branches `not (A <= B)` or
`not (B <= A)`. Positive `true` and negative `false` produce one empty branch,
while positive `false` and negative `true` produce the empty union. It never
opens an expression-level `LengthIf` or invents a general arithmetic
disjunction.

The raw generated-branch cap is checked before cleanup. Each complete branch
is then sorted and deduplicated, exact literal/complement branches are removed,
duplicate branches are removed, and strict literal-set supersets are absorbed.
Every surviving branch delegates its signed leaves to the unchanged root-monus
scanner, uses its own rule and immutable-snapshot closure-inspection caps, and
must bound every compact source input. Contradictory branches disappear;
missing coverage in any live branch makes the whole validator ordinarily
inapplicable.

Completely bounded branches become a canonical antichain of source-ordered
zero-origin maximum boxes. Duplicate or componentwise-contained boxes are
removed, but incomparable boxes remain distinct. In particular, `[1,3]` and
`[3,1]` are not widened to `[3,3]`: they cause 16 raw visits but only 12 unique
assignments after overlap deduplication. The receipt records the ordered boxes,
box count, raw visit count, unique-assignment count, applicable-assignment
count, and model/provider-relative basis. One global `Set`-ordered replay then
visits each unique assignment once in lexicographic order, with the last input
varying fastest. The original checked precondition and postcondition—not the
DNF or affine summaries—remain authoritative.

An empty union has no boxes and zero visits, unique assignments, or applicable
assignments, and demands no evaluation limit. Nullary truth is instead the
singleton box `[[]]` with one visit and one unique assignment. The fixed
failure order is input width; raw branches; every canonical branch's rule and
closure caps; missing coverage; retained boxes; maximum values; raw visits;
unique assignments; global replay/evaluation; then query association.
Width/branch/rule/closure/box/value/visit/unique cap misses are ordinary
per-candidate admission misses in Leant. An assignment-evaluation rejection,
internal enumeration invariant, or query association mismatch is an indexed
atomic batch failure which restores literal original order.

Only complete query-owned replay releases
`StrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionApplicableDomainEstablished`
or the nominal
`LengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionApplicableDomainEstablished`.
Their public notes use
`renderLengthStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionApplicableDomainValidationNote`
and
`renderLengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionApplicableDomainValidationNote`.
Each note is capped at 384 characters, prints boxes/visits/unique/applicable
counts before at most two boxes with at most two maxima each, and states
vacuity when the applicable count is zero. Receipt tags are additive evidence
and presentation distinctions only; contract, problem, query, wire,
fingerprint, association, executable, worker, run, and scoped-owner identities
remain unchanged. See the
[Boolean finite-union Length ranking report](reports/2026-08-15-boolean-finite-union-length-ranking.md)
and Djex's
[Boolean finite-union applicable-domain report](../lib/Djex/docs/reports/2026-08-15-boolean-finite-union-length-applicable-domain.md).

### Atomic branching inside the finite union

The ninth mutually exclusive strategy retains that complete Boolean union and
opens exact alternatives for one immediate binary root extremum or may-zero
root monus inside a signed atomic leaf:

```haskell
let atomicBranchingPolicy =
      enableLengthRankingStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingApplicableDomainValidation
        applicableDomainLimits booleanFiniteUnionLimits finiteUnionScopedPolicy

scalarAssessment <- assessVerifiedLengthCandidatesWithPolicy
  atomicBranchingPolicy scalarAtomicBranchingContract verificationBatch

pairAssessment <- assessVerifiedLengthSpinePairCandidatesWithPolicy
  atomicBranchingPolicy pairAtomicBranchingContract verificationBatch
```

For normalized positive-affine children `A` and `B` and opposite operand `C`,
the extremum alternatives are exactly:

```text
C <= max(A,B)      -> [C<=A] | [C<=B]
min(A,B) <= C      -> [A<=C] | [B<=C]
not(max(A,B)<=C)   -> [C+1<=A] | [C+1<=B]
not(C<=min(A,B))   -> [A+1<=C] | [B+1<=C]
max(A,B)=C         -> [A<=C,B<=C,C<=A] | [A<=C,B<=C,C<=B]
min(A,B)=C         -> [C<=A,C<=B,A<=C] | [C<=A,C<=B,B<=C]
```

The root may occur on either equality side. Alternatives always follow the
normalized first child then the second, and each displayed rule sequence is
literal: equal or extensionally duplicate rules are not removed. The four
already exact predecessor extremum orientations stay singleton alternatives.

For `M = A monus B = max(A-B,0)` and a nonconstant positive-affine `C` which
may be zero, the new zero-first alternatives are:

```text
C <= M        -> [C<=0] | [B+C<=A]
M = C, C = M  -> [A<=B+C,C<=0] | [A<=B+C,B+C<=A]
```

The common equality rule `A<=B+C` remains first, including in the zero branch;
it is not simplified to `A<=B`. Constant-positive and identically-zero
opposites, and every already exact monus orientation, retain the root-monus
predecessor's singleton behavior.

Djex first builds formula-polarity DNF, then lazily counts the complete
formula-DNF by per-atom-alternative Cartesian product under the existing
generated-branch cap. This happens before complement removal, deduplication,
or absorption: two binary atoms in one conjunction count four raw witnesses,
and the characterized negated-equality case counts three. After admission it
canonicalizes sets of the *original checked literals*, traverses those sets in
`Set` order, and re-expands each literal into explicit ignored,
contradictory, or ordered-rule alternatives. It manufactures no replacement
formula, canonicalizes no proof-rule set, and assigns rule/closure failure
indices in that expanded canonical stream.

The existing limits and failures are unchanged. An extremum equality needs
three rules per alternative and a may-zero monus equality needs two; configured
caps of two and one therefore observe three and two. The default rule ceiling
remains 64 and a 65th rule reports bounded observation 65. Input, generated-
branch, rule, closure, retained-box, value, visit, and unique-assignment limits
remain ordinary admission misses. Evaluation, invariant, association,
forcing, live, and finalization failures retain indexed or batch-wide atomic
fallback through the existing Boolean finite-union failure constructors.

Closure, zero-origin box antichain construction, global lexicographic replay,
preference, simplification, MRU, and scoped/deferred execution are the literal
finite-union predecessor. Thus `min(x,y)<=1`, `x<=3`, `y<=3` yields
`[[1,3],[3,1]]`, 16 visits, and 12 unique/applicable assignments rather than
the hull `[3,3]`. Likewise `x <= (3 monus y)`, `y<=4` yields
`[[0,4],[3,3]]`, 21 visits, 17 unique assignments, and 11 applicable
assignments; equality retains the same cover with five applicable assignments.
The original checked precondition, never an alternative proof summary, decides
applicability during replay.

Only complete query-owned replay releases
`StrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingApplicableDomainEstablished`
or its nominal product sibling
`LengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingApplicableDomainEstablished`.
Their bounded 384-character renderers are
`renderLengthStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingApplicableDomainValidationNote`
and
`renderLengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingApplicableDomainValidationNote`.
The fresh scalar and pair receipt tags distinguish evidence and presentation
only. They alter no contract, problem, query, wire, fingerprint, association,
execution policy, worker, run, or scoped-owner identity, and grant neither Z3
proof nor pruning authority. See the
[atomic-branching Length ranking report](reports/2026-08-15-atomic-branching-length-ranking.md)
and Djex's
[atomic-branching applicable-domain report](../lib/Djex/docs/reports/2026-08-15-atomic-branching-length-applicable-domain.md).

### Recursive piecewise-affine branching

The tenth mutually exclusive builder extends that exact finite union through
recursively nested extrema and natural monus:

```haskell
recursivePolicy =
  enableLengthRankingStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingRecursivePiecewiseAffineApplicableDomainValidation
    applicableDomainInputBoxLimits booleanFiniteUnionLimits basePolicy
```

Every signed relational leaf first enters the complete atomic-branching
scanner above. Recursive interpretation is attempted only when that scanner
returns exactly one ignored alternative and an extremum or monus remains
somewhere in a relation operand. A predecessor-supported leaf is never
reinterpreted. Immediate-root extrema and may-zero monus therefore retain
their existing alternatives, rule order, and cap observations.

The recursive expression grammar admits compact checked inputs, natural
literals, normalized sums, retained positive-literal scales, binary minimum,
binary maximum, and binary monus. Sum cases form a left-to-right Cartesian
product; a scale multiplies each selected signed value while preserving its
guards. Any required quotient, modulo, conditional, result reference,
out-of-range variable, retained zero scale, or unsupported child rejects the
complete recursive fallback atom. Unsupported structure is neither erased nor
approximated.

For selected signed-affine child values `L` and `R`, descendant guards come
first and the current node appends these exact disjoint cases:

```text
min(L,R) -> [L<=R; value L] | [R+1<=L; value R]
max(L,R) -> [R<=L; value L] | [L+1<=R; value R]
L monus R -> [L<=R; value 0] | [R+1<=L; value L-R]
```

The first branch owns equality. Case order is depth first, left child before
right child, then first selector before second. After both operands expand,
the relation contributes `[L<=R]`, `[R+1<=L]`, or
`[L<=R,R<=L]` for at-most, immediate negated at-most, or equality. Signed
coefficients created by positive monus are transferred exactly across the
inequality into the existing natural positive-sided rule representation. No
new formula is built and ordered selector/relation rules are not deduplicated.

This admits nested, embedded, both-root, mixed, and normalized effectively
n-ary extrema/monus expressions inside that grammar. It does not add recursive
quotient, modulo, expression-conditional, result-reference, or general
nonlinear reasoning.

The outer signed-formula DNF remains unchanged. Its raw generated-branch cap
counts the complete product by every recursive leaf alternative before
formula cleanup, selector contradiction, rule collection, closure, or box
cleanup. After admission, sets of original checked literals are canonicalized
and re-expanded in `Set` order. Rule and closure indices refer to that expanded
canonical stream. The existing immutable-snapshot rule-once closure and exact
zero-origin box antichain then apply. Incomparable boxes remain separate, and
one globally deduplicated lexicographic assignment set is replayed against the
original checked formula.

For scalar inputs `x` and `y`, the characterized precondition

```text
max(x,y) <= 3 monus min(x,y)
x <= 3
y <= 3
```

retains boxes `[[2,3],[3,2]]`, two boxes, 24 raw visits, 15 unique
assignments, and 10 applicable assignments. The atomic predecessor ignores
the recursive atom and retains the hull-like control `[[3,3]]`, one box, 16
visits, 16 unique assignments, and the same 10 applicable assignments. The
recursive strategy does not manufacture `[3,3]`.

For the product fixture, let

```text
u = min(x,y) + (x monus y)
v = min(x,y) + (y monus x)
max(u,v) <= 2
x <= 3
y <= 3
```

The recursive path retains `[[2,2]]` with one box and 9/9/9 visits, unique
assignments, and applicable assignments. The atomic predecessor retains
`[[3,3]]` with one box, 16 visits, 16 unique assignments, and nine applicable
assignments. Four cases for each inner expression and two outer maximum
choices produce 32 raw alternatives, so a generated-branch cap of 31 rejects
after observing 32 and a cap of 32 admits.

The strategy reuses `LengthBooleanFiniteUnionLimits`, all scalar/product direct
and query Boolean-union error types, and Leant's two Boolean-union ranking
failure constructors. Width, branch, rule, closure, missing-bound, box, value,
visit, and unique-assignment admission remain ordinary per-candidate misses;
assignment/invariant and association failures retain their indexed atomic
fallback routes. Non-vacuous preference, vacuous neutrality,
counterexample simplification and MRU insertion, scoped deep forcing,
deferred all-pure zero-worker behavior, and original-order recovery remain
unchanged.

Complete scalar replay releases
`StrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingRecursivePiecewiseAffineApplicableDomainEstablished`;
complete product replay releases its `LengthSpinePair` sibling. Their renderers
are
`renderLengthStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingRecursivePiecewiseAffineApplicableDomainValidationNote`
and
`renderLengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingRecursivePiecewiseAffineApplicableDomainValidationNote`.
The bounded notes report basis, boxes, visits, unique/applicable counts,
vacuity, and a maxima prefix without claiming a hull, proof, or solver
authority.

The current startup policy selects these nominal scalar/product receipt
families together with execve-check launch, the scoped-v2 owner, deferred
opening, both preferences, and simplification. The Leant boundary is recorded in the
[recursive piecewise-affine Length ranking report](reports/2026-08-15-recursive-piecewise-affine-length-ranking.md),
and Djex's exact grammar, selector laws, signed transfer, raw accounting, and
authority are in the
[recursive piecewise-affine applicable-domain report](../lib/Djex/docs/reports/2026-08-15-recursive-piecewise-affine-length-applicable-domain.md).

### Shared usable-work budget (v1)

The runtime-unscoped v1 shared usable-work policy is a further orthogonal
programmatic opt-in. Its builder accepts only an already validated opaque Djex
budget and works for both the scalar and nominal product assessors:

```haskell
usableWorkBudget <- either (fail . show) pure $
  mkLengthSMTLibLiveUsableWorkBudget
    LengthSMTLibLiveUsableWorkBudgetSource
      { lengthSMTLibLiveUsableWorkBudgetSourceMilliseconds = 30000 }

let budgetedAdvancedPolicy =
      enableLengthRankingUsableWorkBudget
        usableWorkBudget advancedPolicy

scalarAssessment <- assessVerifiedLengthCandidatesWithPolicy
  budgetedAdvancedPolicy scalarPositiveAffineContract verificationBatch

pairAssessment <- assessVerifiedLengthSpinePairCandidatesWithPolicy
  budgetedAdvancedPolicy pairPositiveAffineContract verificationBatch
```

`enableLengthRankingUsableWorkBudget` deliberately retains Djex's established
v1 owner. Its rank-N phantom separates independently captured tokens at the type
level, but does not enforce a dynamic non-escape boundary; v1 is retained for
source, runtime, and identity compatibility. Leant does not expose that token,
yet callers choosing this builder should understand which underlying policy it
selects.

Leant first productively admits at most 64 candidates, then enters that v1
deadline owner before forcing complete preparation and the deferred pure prefix.
An all-pure batch opens no worker but still reaches the owner's normal-return
expiry check. A live miss opens the one session beneath the same token; opening,
serial-gate waiting, scalar or pair transactions, independent replay, and run-
identity work use the minimum of that shared absolute deadline and the
established fresh local deadline, with the shared deadline winning a tie.

This is a usable-work boundary rather than an asynchronous watchdog. It does
not interrupt arbitrary callback IO or nonterminating pure computation, and
exceptions retain the live owner's cleanup-and-rethrow behavior. Djex checks
the shared deadline when controlled work or a callback returns normally. Final
readiness and cleanup operate with fresh private windows, but Leant deliberately
uses the general outer deadline owner so its final normal-return check occurs
after a nested session has completely finalized. It can therefore report that
the shared deadline elapsed during those fresh-window stages. The file grammar
caps the requested duration at 65,000 ms; the programmatic builder itself
accepts the caller's already validated Djex value.

Budget expiry is the existing sanitized session deadline failure with safe
original index `Nothing` and the established original-order atomic fallback.
It creates no assessment, evidence, presentation note, proof, or pruning
authority. The budgeted Djex ready-worker and nominal scalar/product query-run
identities bind the shared selection and effective deadline cause. The current
startup file always selects the scoped-v2 owner instead; v1 remains available
only to explicit programmatic policy construction. See the
[shared usable-work Length ranking report](reports/2026-08-15-shared-usable-work-length-ranking.md).

### Scoped usable-work lease (v2)

New code can instead select Djex's owner-thread-affine, dynamically scoped v2
lease. The duration value is shared with v1, but the policy builder and runtime
strategy are distinct:

```haskell
let scopedRelationalPolicy =
      enableLengthRankingScopedUsableWorkBudget
        usableWorkBudget relationalPolicy

scalarAssessment <- assessVerifiedLengthCandidatesWithPolicy
  scopedRelationalPolicy scalarRelationalContract verificationBatch

pairAssessment <- assessVerifiedLengthSpinePairCandidatesWithPolicy
  scopedRelationalPolicy pairRelationalContract verificationBatch
```

`enableLengthRankingScopedUsableWorkBudget` is pure: it reads no clock, opens no
worker, and grants no evidence. Applying either budget builder again is last-
wins across v1 and v2 while every non-budget policy component is retained. At
each scalar or pair run, Leant admits the at-most-64 input outside the clock,
captures a fresh v2 owner before preparation, and keeps complete preparation,
the deferred MRU/applicable-domain/origin prefix, worker opening, and the live
suffix beneath that one absolute deadline. It checkpoints initially, after
forced preparation, after each complete bounded candidate chain, immediately
before a pure miss can demand its first live session, after live candidates,
and before and after forcing the ranking-owned result. A pure candidate chain's
independently bounded replay, domain, origin, and simplification operations stay
one indivisible checkpoint quantum.

The v2 token is accepted only on its creating thread while the owner callback is
open. Wrong-thread or escaped use is the byte-free sanitized session failure
`LengthSMTLibLiveSessionUsableWorkScopeUnavailable`, checked before clock,
configuration, workspace, or process demand; the owner closes admission on
normal and exceptional exit. Leant's structured owner/checkpoint failure is an
original-order atomic fallback: occurrences whose preparation already failed
retain `LengthCandidatePreparationRefused`, while every eligible prepared
candidate becomes `Unassessed`. Its safe original index is `Nothing`, and it
preserves any nested cleanup-incomplete bit. A non-shared-deadline query failure
may retain that candidate's safe original index only when the shared lease is
still live at the following checkpoint. Shared-v2 expiry is instead observed by
that checkpoint or the outer owner and produces the owner failure with index
`Nothing`. Exceptions still propagate after owned cleanup instead of becoming a
ranking result.

V2 remains cooperative, not a watchdog: it cannot interrupt arbitrary callback
IO, a nonterminating pure chain, or any work which never reaches a controlled
boundary. Nested final readiness and cleanup retain their fresh private windows,
but Leant deliberately uses the general two-step owner. Its final normal-return
observation occurs only after the nested session and ranking-owned result have
finished, so it can truthfully notice expiry during those finalizer stages. The
shorter Djex convenience entrance has a different exclusion boundary; Leant's
ranking path does not use it.

Scoped ready-worker, scalar-run, and pair-run identities are distinct additive
v2 envelopes. They bind the duration, captured deadline, shared-on-tie minimum
selection, lifecycle/admission and coverage policy, but omit the owner thread,
mutable lease state, and checkpoint outcomes. Canonical queries, protocol bytes,
observations, and replay authority are unchanged. A checkpoint or deadline
asserts only process/session timing association: it supplies no solver proof,
behavioral receipt, assessment, presentation note, or pruning authority. See the
[scoped usable-work Length ranking report](reports/2026-08-15-scoped-usable-work-length-ranking.md).

### Counterexample simplification

Counterexample simplification is another orthogonal, programmatic opt-in.  It
uses the same checked Djex input-box limits for scalar and canonical-`Prod`
ranking:

```haskell
let simplifiedPolicy =
      enableLengthRankingCounterexampleSimplification
        inputBoxLimits applicablePolicy

scalarAssessment <- assessVerifiedLengthCandidatesWithPolicy
  simplifiedPolicy scalarContract verificationBatch

pairAssessment <- assessVerifiedLengthSpinePairCandidatesWithPolicy
  simplifiedPolicy pairContract verificationBatch
```

Every independently replayed counterexample—whether found by the MRU bank,
applicable-domain traversal, origin probe, live observation, or post-`unsat`
box—passes through one query-owned finalization seam.  Djex first revalidates
the anchor, then searches the complete componentwise-dominated input box from
zero in lexicographic order with the last input varying fastest.  A strict
reduction becomes the ordinary final counterexample, and only its reduced
inputs enter the four-entry MRU bank.  The ranked candidate retains separate
opaque simplification metadata through
`rankedLengthCandidateCounterexampleSimplification` or the spine-pair sibling,
so presentation can report the original inputs, final inputs, and exact number
of lower-box assignments inspected without changing the counterexample
assessment type.

Width or Cartesian-product refusal, or an anchor which is already the first
violation, retains the original receipt and makes no simplification claim.  A
bounded evaluation rejection during an optional earlier trial does the same;
structural, anchor, internal, and association failures remain indexed atomic
failures. This policy is disabled by the established direct runner and enabled
by the current startup configuration. It is bounded componentwise-lexicographic
simplification, not global minimality, pruning authority, or a new conclusion
from Z3.

### Per-candidate execution order and stable ordering

For each eligible product query, the exact execution order is the product
batch's newest-first four-entry MRU input replay bank, the optional query-owned
applicable-domain validation, the optional query-owned origin probe, a live
pair query, query-first observation replay, and—only when that live observation
has no counterexample and reports `unsat`—the optional exact input-box
traversal. An applicable-domain counterexample or establishment skips the
origin and live transaction for that candidate. An inapplicable result simply
continues to the origin/live stages. Under the historical/default policy, a
freshly replayed
and associated pair counterexample is the only assessment which moves: it
enters the stable demoted partition and can supply an MRU input vector.
When simplification is enabled, the finalized receipt and its final input
vector take those same roles; acquisition order and live transaction order do
not change.
Complete box traversal is `LengthSpinePairBoundedPositive` and remains neutral
unless the new preference is explicitly enabled. With that preference, a
receipt whose applicable-assignment count is positive enters a stable preferred
partition; a zero-applicable, vacuous receipt remains neutral. Under eager
opening, the eligible batch's lexical worker is opened and capability-probed
before this per-candidate sequence, so either applicable-domain evidence arm
avoids only a live transaction and ordinal. Under the current startup policy's
deferred opening, the pure prefix runs before IO, so an all-pure batch opens no process at all.
The first miss opens exactly one lexical session, executes that triggering
candidate once without rerunning its MRU/domain/origin prefix, and processes the
remaining suffix through the same session. A pure indexed failure before that
point resets the whole admitted batch and opens nothing. A later indexed
failure discards earlier pure or live assessments and simplification metadata;
session opener/finalizer failures keep the established safe index `Nothing`.
Status-only
`sat`, `unsat`, and `unknown` remain neutral heuristics. Any structured session
or live-query failure, live-observation association or replay failure,
an admitted query-owned applicable-domain evaluation/association failure,
origin failure, or input-box failure atomically restores the
admitted batch in original order as unassessed. Candidate-local pure preparation
refusals stay local, and no result grants pruning authority.

The current startup route therefore fixes the source order as MRU → recursive
piecewise-affine applicable domain → origin → live replay → post-`unsat`
explicit box. Every counterexample
from any of those five sources crosses the same simplification seam before
assessment. A strict receipt's final vector, never its original anchor, enters
the domain-local MRU bank. Stable ordering is non-vacuous applicable-domain
receipts, then non-vacuous explicit-box receipts, then neutral assessments
(including vacuous receipts), then counterexamples. Occurrence handles carry
each receipt and optional simplification metadata through that ordering.

### Domain-neutral limits and product-specific authority

The opaque execution/evaluation policy and Djex live-session limits are
domain-neutral and reused by the scalar and product runners. Each Leant call
productively admits no more than the shared 64-query maximum. Programmatic
eager calls open one fresh lexical worker for an eligible batch. The current
startup route is deferred: it opens at most one fresh session, only at the
first live miss, and then consumes that session's
single total query budget. Behavioral authority is not shared: product
contracts, queries, live observations, replay receipts, failures, assessments,
MRU state, and presentation remain product-specific and cannot be cast from
their scalar siblings. The existing/default scalar path, public scalar types,
query bytes, neutral ranking behavior, and presentation are unchanged.

## Current startup configuration examples

The startup format has one current shape. The examples below differ in their
`rankingDomain`, input limits, and contract, not in an operational strategy
selector. A pinned digest is shown because activation requires one unless the
caller separately supplies `--length-ranking-allow-unpinned`.

### Scalar startup configuration

This scalar example checks two compact Length inputs and asserts that the
result length equals the first input length:

```json
{
  "format": "leant-live-length-ranking-configuration",
  "rankingDomain": "scalar",
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
    }
  },
  "evaluation": {
    "assignmentValueBits": 4096,
    "intermediateValueBits": 4096
  },
  "inputBoxValidation": {
    "inclusiveInputMaximums": [5, 5],
    "maximumAssignments": 36
  },
  "applicableDomainValidation": {
    "maximumInputs": 2,
    "maximumGeneratedBranches": 4,
    "maximumRulesPerBranch": 4,
    "maximumClosureInspectionsPerBranch": 4,
    "maximumRetainedBoxes": 2,
    "maximumAssignmentVisits": 20,
    "maximumAssignments": 20
  },
  "counterexampleSimplification": {
    "maximumInputs": 2,
    "maximumAssignments": 36
  },
  "usableWorkBudget": {
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

### Binary-product startup configuration

The binary-product root selects a nominally distinct contract and assessment
path. The root-level domain is the only discriminator; expressions refer to
the two result components explicitly:

```json
{
  "format": "leant-live-length-ranking-configuration",
  "rankingDomain": "binary-product",
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
    }
  },
  "evaluation": {
    "assignmentValueBits": 4096,
    "intermediateValueBits": 4096
  },
  "inputBoxValidation": {
    "inclusiveInputMaximums": [4],
    "maximumAssignments": 5
  },
  "applicableDomainValidation": {
    "maximumInputs": 1,
    "maximumGeneratedBranches": 2,
    "maximumRulesPerBranch": 2,
    "maximumClosureInspectionsPerBranch": 2,
    "maximumRetainedBoxes": 1,
    "maximumAssignmentVisits": 4,
    "maximumAssignments": 3
  },
  "counterexampleSimplification": {
    "maximumInputs": 1,
    "maximumAssignments": 9
  },
  "usableWorkBudget": {
    "milliseconds": 30000
  },
  "contract": {
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

The domain tag never infers a contract from the Lean goal. `resultShape` is not
part of either nested schema and is rejected as unexpected. A pair result
reference fails in the selected scalar decoder, while a scalar result reference
fails in the selected pair decoder.

### Schema and validation order

The startup root has exactly ten required members:

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

Unknown members are rejected; object member order in the input is immaterial.
After bounded UTF-8 JSON parsing and root-object admission, semantic validation
checks `format`, then `rankingDomain`, then the exact ten-member root.
Operational validation proceeds through execution admission, execution,
evaluation, the post-`unsat` input box, applicable-domain limits,
counterexample simplification, and the scoped usable-work budget. The selected
scalar or binary-product contract is validated last. Policy construction is
pure and launches no worker.

The operational objects expose numeric parameters and genuine choices only:

- `execution` fixes the current descriptor-bound execve-check launcher; there
  is no `executableLaunch` field.
- `applicableDomainValidation` fixes recursive piecewise-affine atomic
  branching; there is no `strategy` field. Its limits are, in order,
  maximum inputs, generated branches, rules per branch, closure inspections per
  branch, retained boxes, assignment visits, and unique assignments. Their
  file caps remain 8, 256, 64, 4096, 256, 262144, and 65536.
- `counterexampleSimplification` fixes componentwise-lexicographic
  simplification and contains only `maximumInputs` and
  `maximumAssignments`.
- `usableWorkBudget` fixes the scoped, checkpointed v2 owner and contains only
  `milliseconds`, capped at 65,000.

The origin probe, both non-vacuous preferences, and deferred opening are also
fixed by the current decoder rather than represented by
`counterexampleProbe`, `boundedPositiveOrdering`,
`applicableDomainOrdering`, or `liveSessionOpening` members.

Historical startup documents with a `version` member or any removed strategy
member are outside this schema. They are rejected rather than migrated, and
there is no startup unsupported-version sentinel. The contract-only format now
uses the same versionless domain-selection rule.

## Pair contracts, decoders, and reports

### Using a binary-product contract document with `:synth`

Then select a typed Exference-producing engine and synthesize normally. A
versionless binary-product document can replace the startup-fixed contract for
one command without changing the CLI grammar:

```text
:set synth-engine exference
:synth List Nat → Prod (List Nat) (List Nat)
:synth --length-contract /absolute/path/pair-contract.json -- List Nat → Prod (List Nat) (List Nat)
```

### Pair contract grammar and validation order

Both file formats select their nominal contract domain with `rankingDomain`:
`"scalar"` selects the full scalar grammar and `"binary-product"` selects the
pair grammar. Neither decoder infers that choice from a Lean goal.

Pair contract objects have exactly `spine`, `targetArgumentRoles`,
`candidateCasePolicy`, `precondition`, `postcondition`, and `providerLaws`.
After the bounded root/schema gates, the contract-only decoder validates those
fields in that order. The startup decoder validates all operational objects
first and the domain-selected contract last. JSON object member order is
immaterial.

The pair grammar retains the scalar grammar's modulo, positive-literal
quotient, formulas, and provider laws, but admits only `["input", n]`,
`["result", "first"]`, and `["result", "second"]` as variables. Its target-role
vector is required, and its case policy is exactly `"cases-rejected"` or
`"exact-spine-zero-step-v1"`.

### Decoder separation and reports

The startup and contract-only roots remain separate formats. The startup
decoder accepts one exact, versionless
`leant-live-length-ranking-configuration` root and chooses the nominal runner
from `rankingDomain`. The contract-only decoder accepts one exact, versionless
`leant-finite-list-spine-length-contract` root and returns the same nominal
selection type. A `version` member is outside either exact root and is reported
as unexpected once the earlier `rankingDomain` gate succeeds. Each input is
parsed once; neither decoder delegates to a historical parser or retries under
another domain.

A binary-product startup file selects which nominal runner Main calls. It does
not infer a contract from the Lean type, bypass the exact canonical-`Prod`
handoff, turn solver status into evidence, or grant pruning authority. The
current startup reset is recorded in the
[versionless startup configuration report](reports/2026-08-15-versionless-length-ranking-configuration.md).
The matching command-local reset is recorded in the
[versionless Length contract report](reports/2026-08-15-versionless-length-contract.md).
The exact handoff and live pair boundaries are recorded in the historical
[canonical `Prod` Length handoff report](reports/2026-08-14-canonical-prod-length-handoff.md)
and
[live binary-product Length ranking report](reports/2026-08-14-live-binary-product-length-ranking.md).
Their startup-version discussions describe the checkpoints at which those
reports landed and are not current file documentation.

The current recursive validator and its inherited lifecycle are recorded in the
[recursive piecewise-affine Length ranking report](reports/2026-08-15-recursive-piecewise-affine-length-ranking.md).
That report also predates the schema reset; its v33/v34 routing discussion is
historical, while its semantic examples and authority boundary remain useful.
Djex's current recursive grammar, selector guards, signed-affine transfer,
raw-case accounting, exact union replay, and receipt authority are recorded in
the
[recursive piecewise-affine applicable-domain report](../lib/Djex/docs/reports/2026-08-15-recursive-piecewise-affine-length-applicable-domain.md).
The inherited source/staged executable-check lifecycle and its narrow authority
are in the
[execve-check descriptor-bound Z3 launch report](../lib/Djex/docs/reports/2026-08-15-execve-check-descriptor-bound-z3-launch.md).

All dated Leant reports are historical engineering records, not normative
startup grammar. The [report index](reports/README.md) states the precedence
explicitly.

## Presentation notes on the Main path

After a successful occurrence seal, Main dispatches presentation through the
selected scalar or pair domain and prints a subordinate note only for a
candidate carrying independently validated evidence. A scalar counterexample
note summarizes its observed input and result spine lengths; a pair note keeps
the first and second result lengths source ordered. Both call the receipt
replayed and model-relative and report only the number of assumed provider laws
used by that candidate. Independently completed finite-box notes instead give
the bounded maxima and checked/applicable assignment counts. Direct
applicable-domain assessments use
`renderLengthApplicableDomainValidationNote` or its spine-pair sibling.
Positive-affine assessments use
`renderLengthPositiveAffineApplicableDomainValidationNote` or its pair sibling;
their notes report derived maxima, checked/applicable counts, the exact
model/provider-relative basis, and explicit vacuity. Relational assessments use
`renderLengthRelationalPositiveAffineApplicableDomainValidationNote` or
`renderLengthSpinePairRelationalPositiveAffineApplicableDomainValidationNote`
with the same bounded projections and a distinct rule label. Strict-relational
assessments use
`renderLengthStrictRelationalPositiveAffineApplicableDomainValidationNote` or
`renderLengthSpinePairStrictRelationalPositiveAffineApplicableDomainValidationNote`.
Root-quotient-consequence assessments use
`renderLengthStrictRelationalPositiveAffineQuotientApplicableDomainValidationNote`
or
`renderLengthSpinePairStrictRelationalPositiveAffineQuotientApplicableDomainValidationNote`.
Root-extrema-consequence assessments use
`renderLengthStrictRelationalPositiveAffineQuotientRootExtremaApplicableDomainValidationNote`
or
`renderLengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaApplicableDomainValidationNote`.
Root-monus-consequence assessments use
`renderLengthStrictRelationalPositiveAffineQuotientRootExtremaMonusApplicableDomainValidationNote`
or
`renderLengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusApplicableDomainValidationNote`.
Boolean finite-union assessments use
`renderLengthStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionApplicableDomainValidationNote`
or
`renderLengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionApplicableDomainValidationNote`.
Atomic-branching finite-union assessments use
`renderLengthStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingApplicableDomainValidationNote`
or
`renderLengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingApplicableDomainValidationNote`.
Recursive piecewise-affine assessments use
`renderLengthStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingRecursivePiecewiseAffineApplicableDomainValidationNote`
or its `LengthSpinePair` sibling.
The current startup path can produce only the recursive piecewise-affine
applicable-domain receipt family selected by its scalar or binary-product
domain. Lower-level programmatic policy builders can still construct the
earlier direct, positive-affine, relational, strict, quotient, extrema, monus,
Boolean-union, or atomic-branching policies, so their renderers remain part of
the library surface. The semantic note
never projects the receipt's private provider-name list. Disabled assessment,
rejected input, heuristic status,
and atomic operational fallback add no semantic note. The note can explain a
stable demotion; it never proves, prunes, or claims concrete Lean behavior.
