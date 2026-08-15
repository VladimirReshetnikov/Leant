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
configuration-file selectors, contract-file selectors, the binary-product
extension, the replay bank, the origin probe, bounded validation, and
presentation notes. (The module-by-module ownership map lives in
[synth-internals.md](synth-internals.md).) Leant is experimental and makes no
public stability or backward-compatibility promise. Names, numeric selectors,
JSON shapes, tags, diagnostics, and output may be revised before a stable
release. The detail below is a current regression specification, not a promise
to preserve earlier decisions. It is dense by design; read the overview above
first.

---

## Contents

- [Startup configuration file](#startup-configuration-file)
  - [Versions 1 to 34 at a glance](#versions-1-to-34-at-a-glance)
  - [Activation, pinning, and worker lifecycle](#activation-pinning-and-worker-lifecycle)
  - [Candidate eligibility](#candidate-eligibility)
- [One-shot contract-only files](#one-shot-contract-only-files)
  - [Command syntax, admission, and lifetime](#command-syntax-admission-and-lifetime)
  - [Contract-only versions 1 and 2: compatibility grammar and modulo](#contract-only-versions-1-and-2-compatibility-grammar-and-modulo)
  - [Contract-only version 3: explicit target-argument roles](#contract-only-version-3-explicit-target-argument-roles)
  - [Contract-only version 4: exact-spine zero-step case policy](#contract-only-version-4-exact-spine-zero-step-case-policy)
  - [Contract-only version 5: positive-literal quotient](#contract-only-version-5-positive-literal-quotient)
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
- [Startup configuration examples by version](#startup-configuration-examples-by-version)
  - [Startup version 5: scalar bounded-positive ordering](#startup-version-5-scalar-bounded-positive-ordering)
  - [Contract-only version 6: binary-product pair contract](#contract-only-version-6-binary-product-pair-contract)
  - [Startup versions 4 and 6: pair ranking](#startup-versions-4-and-6-pair-ranking)
  - [Startup versions 7 and 8: positive-affine deferred opening](#startup-versions-7-and-8-positive-affine-deferred-opening)
  - [Startup versions 9 and 10: shared usable-work budget](#startup-versions-9-and-10-shared-usable-work-budget)
  - [Root fields and validation order for versions 7 to 10](#root-fields-and-validation-order-for-versions-7-to-10)
  - [Startup versions 11 and 12: relational positive-affine](#startup-versions-11-and-12-relational-positive-affine)
  - [Startup versions 13 and 14: scoped usable-work lease](#startup-versions-13-and-14-scoped-usable-work-lease)
  - [Startup versions 15 and 16: strict relational positive-affine](#startup-versions-15-and-16-strict-relational-positive-affine)
  - [Startup versions 17 and 18: descriptor-bound executable launch](#startup-versions-17-and-18-descriptor-bound-executable-launch)
  - [Startup versions 19 and 20: root-quotient consequences](#startup-versions-19-and-20-root-quotient-consequences)
  - [Startup versions 21 and 22: effective-ID executable access](#startup-versions-21-and-22-effective-id-executable-access)
  - [Startup versions 23 and 24: root-extrema consequences](#startup-versions-23-and-24-root-extrema-consequences)
  - [Startup versions 25 and 26: root-monus consequences](#startup-versions-25-and-26-root-monus-consequences)
  - [Startup versions 27 and 28: execve-check executable access](#startup-versions-27-and-28-execve-check-executable-access)
  - [Startup versions 29 and 30: Boolean finite-union applicable domains](#startup-versions-29-and-30-boolean-finite-union-applicable-domains)
  - [Startup versions 31 and 32: atomic-branching finite unions](#startup-versions-31-and-32-atomic-branching-finite-unions)
  - [Startup versions 33 and 34: recursive piecewise-affine branching](#startup-versions-33-and-34-recursive-piecewise-affine-branching)
- [Pair contracts, decoders, and reports](#pair-contracts-decoders-and-reports)
  - [Using a contract-only version 6 document with `:synth`](#using-a-contract-only-version-6-document-with-synth)
  - [Pair contract grammar and validation order](#pair-contract-grammar-and-validation-order)
  - [Decoder routing and reports](#decoder-routing-and-reports)
- [Presentation notes on the Main path](#presentation-notes-on-the-main-path)

## Startup configuration file

### Versions 1 to 34 at a glance

Finite-list-spine Length counterexample ranking is disabled by default. To opt
in, pass `--length-ranking-config` with an explicitly chosen absolute path to
a version-1 through version-34 configuration file. The required integer
`version` member is a current-tree decoder discriminator: it selects one exact
JSON shape and scalar-or-product policy branch. It is not Leant's release
version, a SemVer component, a negotiated protocol, or a cumulative feature
level. In the current tree, versions 1--3 select scalar
finite-list-spine Length ranking. Version 1 preserves the established
counterexample-only behavior. Version 2 additionally requires an explicit
per-input finite box and enables independent bounded validation after a live
`unsat` trigger. Version 3 retains that exact box and requires
`"counterexampleProbe": "origin-before-live"`; after the four-entry MRU bank
misses, each exact query asks Djex to replay its canonical all-zero input before
Leant issues that candidate's live Z3 query. Version 4 retains version 3's
operational policy but selects the nominal canonical-`Prod` domain through a
required binary-product-spine contract. Version 5 is the scalar successor and
version 6 is the pair successor: both additionally require
`"boundedPositiveOrdering": "prefer-non-vacuous"`, which explicitly promotes
only candidates carrying a completed finite-box receipt with at least one
precondition-applicable assignment. Version 7 is the scalar advanced successor
and version 8 is its nominal binary-product sibling. Both require the distinct
`"positive-affine-v1"` applicable-domain rule and its non-vacuous preference,
bounded componentwise-lexicographic counterexample simplification, and
`"defer-until-live-query"` session opening. The three bounded authorities in a
v7/v8 file are deliberately independent: its caller-selected post-`unsat` input
box, applicable-domain limits, and simplification limits cannot substitute for
one another. Version 9 is the scalar usable-work successor and version 10 is
its nominal product sibling. They retain their v7/v8 domain policy and require
one additional `"usableWorkBudget"` object selecting
`"shared-usable-work-deadline-v1"`. Versions 1--8 remain literal: versions
1--6 keep eager opening, while v7/v8 keep deferred opening with the historical
separate opener and fresh-per-query deadlines.
Version 11 is the scalar relational positive-affine successor and version 12
is its nominal product sibling. They branch from the exact v7/v8 operational
root, replace only the applicable-domain strategy with
`"relational-positive-affine-v1"`, and deliberately have no
`"usableWorkBudget"` field. Their deferred live lifecycle therefore retains
the historical separate opener/finalizer and fresh per-query deadlines.
Version 13 is the scalar scoped-usable-work successor and version 14 is its
nominal product sibling. They retain v11/v12's relational validator, restore
the exact v9/v10 root field set, and require
`"scoped-checkpointed-shared-usable-work-deadline-v2"`. This additive owner is
valid only on its creating thread and within its callback's dynamic extent,
and Leant cooperatively checks its one absolute deadline between bounded
candidate phases. Version 15 is the scalar strict-relational successor and
version 16 is its nominal product sibling. They preserve the complete v13/v14
root, scoped owner, checkpoint, and contract choices and replace only the
applicable-domain literal with
`"strict-relational-positive-affine-v1"`. That fourth extractor recognizes the
ordinary relational grammar plus exactly one immediate top-level natural
complement, `not (L <= R)`, as `R + 1 <= L`; it is not general negation
normalization. Version 17 is the scalar descriptor-launch successor and version
18 is its nominal product sibling. They preserve the complete v15/v16
behavioral and scoped profile but require the additional closed execution
member `"executableLaunch": "descriptor-bound-executable-v1"`. At the first
live miss, Djex hashes and copies the source bytes into a sealed anonymous main
image and launches that descriptor without resolving the pathname again.
Version 19 is the scalar root-quotient-consequence successor and version 20 is
its nominal product sibling. They retain the complete v17/v18 descriptor,
scoped-v2, deferred-opening, simplification, preference, and contract profiles
and replace only the applicable-domain strategy with
`"strict-relational-positive-affine-quotient-v1"`. That closed fifth extractor
delegates quotient-free clauses to the strict predecessor and adds exact
Natural consequences for one positive-literal quotient at the root of exactly
one side of a top-level inequality, equality, or immediate negated inequality.
It is not general quotient reasoning.
Version 21 is the scalar effective-ID executable-access successor and version
22 is its nominal product sibling. They retain the complete v19/v20 quotient,
scoped-v2, deferred-opening, simplification, preference, and contract profiles
and replace only the closed execution member with
`"executableLaunch": "descriptor-bound-effective-id-executable-access-v1"`.
At a demanded live open, the opened source must pass Linux descriptor-based
`faccessat2` `X_OK` under effective filesystem credentials before copying and
again immediately before child allocation; the staged main image is fixed to
mode `0500`, sealed, and executed without pathname or older-strategy fallback.
Version 23 is the scalar root-extrema-consequence successor and version 24 is
its nominal product sibling. They retain the complete v21/v22 effective-ID
launch, scoped-v2 budget, deferred-opening, simplification, preference, and
contract profiles and replace only the applicable-domain strategy with
`"strict-relational-positive-affine-quotient-root-extrema-v1"`. That closed
sixth extractor delegates root-extrema-free clauses to the quotient predecessor
and adds four necessary Natural consequences for one immediate binary `min` or
`max` at exactly one relation operand root. It is not general extrema solving.
Version 25 is the scalar root-monus-consequence successor and version 26 is its
nominal product sibling. They retain the complete v23/v24 effective-ID launch,
scoped-v2 budget, deferred-opening, simplification, preference, and contract
profiles and replace only the applicable-domain strategy with
`"strict-relational-positive-affine-quotient-root-extrema-monus-v1"`. That
closed seventh extractor delegates root-monus-free clauses to the root-extrema
predecessor and adds exact or necessary Natural consequences for one immediate
binary monus at exactly one relation operand root. Its reverse orientation and
equality distinguish a uniformly positive, identically zero, or may-zero
opposite affine expression; it is not general monus or Boolean-union solving.
Version 27 is the scalar execve-check executable-access successor and version
28 is its nominal product sibling. They retain the complete v25/v26 root-monus,
scoped-v2, deferred-opening, simplification, preference, and contract profiles
and replace only the closed execution member with
`"executableLaunch": "descriptor-bound-execve-check-executable-access-v1"`.
At a demanded live open, Djex retains both effective-credential source VFS
checks and additionally requires descriptor-bound Linux `AT_EXECVE_CHECK`
before and after staging, creates the image with `MFD_EXEC`, fixed mode `0500`,
and the complete executable seal set, and checks that sealed staged descriptor
once before child allocation. Version numbers are closed schema selections
rather than cumulative feature levels; versions 1--26 remain literal.
Version 29 is the scalar Boolean finite-union successor and version 30 is its
nominal product sibling. They retain the complete v27/v28 execve-check launch,
scoped-v2, deferred-opening, simplification, preference, and contract profiles
and replace only the applicable-domain strategy with
`"strict-relational-positive-affine-quotient-root-extrema-monus-boolean-finite-union-v1"`.
The new closed eight-field object independently caps raw DNF branches,
per-branch rules and closure inspections, retained canonical boxes, raw box
visits, input width, and the deduplicated assignment set. It represents an
exact antichain of zero-origin boxes and never substitutes a componentwise
hull.
Version 31 is the scalar atomic-branching finite-union successor and version
32 is its nominal product sibling. They retain the complete v29/v30 JSON and
operational profile and replace only the applicable-domain strategy with
`"strict-relational-positive-affine-quotient-root-extrema-monus-boolean-finite-union-atomic-branching-v1"`.
The same eight-field object is retained; its generated-branch limit now counts
the Cartesian product of formula-DNF branches and exact alternatives for one
immediate binary root extremum or may-zero root monus before Boolean cleanup.
Surviving incomparable boxes remain an exact union; the strategy never
manufactures a hull or rewrites the checked precondition.
Version 33 is the scalar recursive piecewise-affine successor and version 34
is its nominal product sibling. They retain the complete v31/v32 JSON and
operational profile and replace only the applicable-domain strategy with
`"strict-relational-positive-affine-quotient-root-extrema-monus-boolean-finite-union-atomic-branching-recursive-piecewise-affine-v1"`.
The same eight-field object is retained. Every relational leaf first uses the
atomic predecessor; only an otherwise ignored leaf containing an extremum or
monus recursively expands through supported sums, positive scales, binary
minimum, maximum, and monus. Its exact disjoint selector cases feed the same
bounded rule closure, box antichain, and original-formula replay. Quotient,
modulo, conditional, result-reference, zero-scale, and other unsupported
descendants reject the complete recursive fallback atom. V33/v34 are simply
the numbers assigned to these two decoder branches in this revision; their
continued availability or numbering is not promised.

### Activation, pinning, and worker lifecycle

Leant admits and reads that file
once at startup, requires the configuration to contain an executable SHA-256
expectation by default, and retains the decoded contract selection as a fixed
process-wide assertion. Presence at activation is not a digest match; Djex
compares the expectation only when an eligible batch later opens a worker.
V1--v16 use the bounded pre-spawn pathname observation; v17--v34 compare it
with the sealed staged main image selected for descriptor execution. V21--v34
add the two point-in-time source VFS execute-access observations. V27--v34 also
add two point-in-time source kernel executable checks and one staged-image
check; none is a reservation or complete future execution decision.
`--length-ranking-allow-unpinned` is a separate explicit relaxation;
`--length-ranking-config-timeout` sets only the bounded file-load interruption
budget (default 5,000 ms, maximum 60,000 ms). No option discovers a file or
solver. POSIX configuration-file descriptor acquisition is implemented;
Windows currently fails
closed. Versions 1--6 and the established direct runners open one fresh lexical
solver worker for every eligible batch. Versions 7--34 instead complete all
admission and preparation, then run each candidate's pure MRU, selected
positive-affine domain, and origin prefix before IO: an all-pure batch opens no
process, while
the first live miss opens one lexical session for that query and the remaining
suffix. V9/v10 additionally capture one shared usable-work deadline after the
64-candidate admission gate and before full preparation, so deferred pure work,
opening, and every live query consume one window instead of receiving a fresh
batch allowance per query. V13--v34 capture the corresponding dynamically
scoped v2 owner at the same boundary and add cooperative checkpoints after
preparation, each complete candidate chain, and result materialization. Any
structured failure preserves callback order through the established atomic
fallback.
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
JSON ceiling as the compatibility file. The separate contract-only root has
format `leant-finite-list-spine-length-contract`. Version 1 preserves the
existing bounded compatibility grammar; version 2 adds the exact expression
form `["modulo", positiveLiteral, expression]` in preconditions,
postconditions, and provider transfers. Version 3 retains that modulo grammar
and requires an exact source-ordered `targetArgumentRoles` array containing
only `"observed-spine"` and `"unobserved-target"`. Versions 1 and 2 reject that
field, while version 3 rejects its absence. Version 4 retains version 3 and
also requires `"candidateCasePolicy": "exact-spine-zero-step-v1"`. Version 5
retains roles and modulo, requires an explicit case policy, accepts exactly
`"cases-rejected"` or `"exact-spine-zero-step-v1"`, and adds
`["quotient", positiveLiteral, expression]` to preconditions, postconditions,
and provider transfers. Thus quotient does not itself grant case authority.
Version 6 is the separately typed binary-product-spine form: its required
`"resultShape": "binary-prod-spines-v1"` selects a pair contract whose result
variables are `["result", "first"]` and `["result", "second"]`. It retains
version 5's arithmetic, explicit target roles, and explicit case-policy
vocabulary. Startup versions 1--3 retain the scalar compatibility contract
grammar from contract-only version 1 and reject roles, candidate-case policy,
modulo, quotient, and product-only fields. Startup version 4 requires the pair
grammar. The positive-ordering successors use the complete existing grammars:
startup version 5 embeds scalar contract grammar v5, while startup version 6
embeds the same pair grammar as startup v4 and contract-only v6.
No contract-only version can
replace the executable, pin choice, solver limits, artifact policy, or replay
limits. The decoded contract selection is carried only through
that command's ordinary, universe-retry, provider, and classical synthesis
lanes; it is not stored in `ReplState`, `ParsedGoal`, snapshots, history, or a
cache, and later commands return to the startup-fixed contract unless they name
their own file. Malformed option syntax is rejected rather than silently
treated as a goal.

### Contract-only versions 1 and 2: compatibility grammar and modulo

The contract-only document has exactly three root fields; for example:

```json
{
  "format": "leant-finite-list-spine-length-contract",
  "version": 1,
  "contract": {
    "spine": {"family": "List", "zero": "List.nil", "step": "List.cons"},
    "precondition": ["truth", true],
    "postcondition": ["equal", ["result"], ["literal", 0]],
    "providerLaws": []
  }
}
```

Changing only `"version"` to `2` enables positive-literal Natural modulo. The
divisor must be nonzero and no wider than 256 bits. Leant preserves the passive
AST; Djex normalization and sealing own its semantics and lower every surviving
modulo occurrence to private quotient/remainder witness equations using only
QF_LIA. No SMT-LIB `mod` term is emitted, and private witnesses never enter
`get-value` or counterexample presentation. Old one-shot version-1 documents
and version-2 documents retain their exact grammar and behavior.

### Contract-only version 3: explicit target-argument roles

Version 3 is the explicit role-aware form. A map-shaped request can use this
exact contract object:

```json
{
  "format": "leant-finite-list-spine-length-contract",
  "version": 3,
  "contract": {
    "spine": {"family": "List", "zero": "List.nil", "step": "List.cons"},
    "targetArgumentRoles": ["unobserved-target", "observed-spine"],
    "precondition": ["truth", true],
    "postcondition": ["equal", ["result"], ["literal", 0]],
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

The target-role array is bounded to eight entries and must match the complete
physical target argument spine after leading quantifiers. Leant never infers
it from the target, a provider name, a provider scheme, or a candidate. Only
`"observed-spine"` positions must have the configured list-spine type. They
receive compact contract indices in observed-position order, so the two
physical target roles above expose only `LengthInput 0`. Provider-law roles are
different: they still align with every physical provider argument, and a
transfer such as `["argument", 1]` refers to physical provider argument 1; it
is not renumbered to 0 merely because argument 0 is `"unobserved"`.

`"unobserved-target"` means only that the checked Length interpreter carries a
non-inspectable token at that position and may pass it through a non-demanding
path, including forwarding it to an explicitly `"unobserved"` provider
argument. Calling, spine-observing, or tuple-destructuring the token rejects
candidate preparation. The role makes no claim about whether the source type
is inhabited, whether a source implementation evaluates the argument, or
about purity, totality, parametricity, strictness, or effects. The resulting
counterexample remains model-relative evidence under the explicit provider
laws, not a theorem about Lean execution.

Version 3 changes no contract lifetime. Its file is still read once for that
`:synth` command, the decoded request is shared by every retry and synthesis
lane, and neither it nor its roles enter `ReplState`, history, snapshots, or a
cache. A later command returns to the startup-fixed version-1 compatibility
contract unless it explicitly names another contract-only file.

### Contract-only version 4: exact-spine zero-step case policy

Version 4 explicitly enables the one nonempty case shape currently modeled by
Length. It requires the version-3 role vector and the exact field below:

```json
{
  "format": "leant-finite-list-spine-length-contract",
  "version": 4,
  "contract": {
    "spine": {"family": "List", "zero": "List.nil", "step": "List.cons"},
    "targetArgumentRoles": ["observed-spine"],
    "candidateCasePolicy": "exact-spine-zero-step-v1",
    "precondition": ["truth", true],
    "postcondition": ["equal", ["result"], ["literal", 0]],
    "providerLaws": []
  }
}
```

The policy is not inferred from a graph. Exference must independently retain a
checked complete case over the exact recursive two-constructor spine, with one
zero-field constructor and one two-field constructor whose single recursive
field is the scrutinized spine. Djex freshly re-seals that graph against the
contract-resolved `List` schema. The zero branch receives length zero; the step
branch receives an opaque payload and a tail length `input monus 1`; the whole
case retains the union of provider laws reached by either branch. Every other
case shape fails closed, and versions 1--3 keep rejecting all nonempty cases.

This remains a bounded model-relative interpretation. It does not prove Lean
purity, totality, termination, strictness, source-level equivalence, or a
provider law, and it grants no pruning authority. Like version 3, version 4 is
command-local and leaves no role or case-policy state behind.

### Contract-only version 5: positive-literal quotient

Version 5 adds positive-literal Natural floor quotient without changing that
authority model. For example, a postcondition can contain
`["quotient", 2, ["input", 0]]`. The divisor is checked before its child, must
be nonzero, and is bounded by the same 256-bit numeral limit as modulo. Djex
lowers every surviving quotient to the same private Euclidean witness shape
`e = k*q + r`, `q >= 0`, `r >= 0`, and `r <= k-1`, then projects `q`; it emits
no SMT-LIB `div`. Replay independently recomputes Natural quotient from the
original input. Version 5 requires both `targetArgumentRoles` and
`candidateCasePolicy`. Choosing `"cases-rejected"` preserves the singleton,
ordinal-zero renderer rule, while choosing `"exact-spine-zero-step-v1"`
retains the accepted typed renderer ordinal just as version 4 does. Versions
1--4 and startup continue to reject the quotient tag.

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
      Just [LengthObservedSpine]
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

Startup v33/v34 select these nominal scalar/product receipt families while
retaining v31/v32's complete execve-check, scoped-v2, deferred, preference,
simplification, and contract profile. The Leant boundary is recorded in the
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
identities bind the shared selection and effective deadline cause; v1--v8 and
startup v11/v12 keep the unbudgeted worker/run identities. See the
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
failures. This policy is disabled by every established direct runner and
startup version 1 through 6, while startup versions 7 through 34 require it.
It is bounded componentwise-lexicographic
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
avoids only a live transaction and ordinal. Under the v7/v8 deferred policy,
the pure prefix runs before IO, so an all-pure batch opens no process at all.
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

V7/v8 therefore fix the source order as MRU → positive-affine applicable
domain → origin → live replay → post-`unsat` explicit box. Every counterexample
from any of those five sources crosses the same simplification seam before
assessment. A strict receipt's final vector, never its original anchor, enters
the domain-local MRU bank. Stable ordering is non-vacuous applicable-domain
receipts, then non-vacuous explicit-box receipts, then neutral assessments
(including vacuous receipts), then counterexamples. Occurrence handles carry
each receipt and optional simplification metadata through that ordering.

### Domain-neutral limits and product-specific authority

The opaque execution/evaluation policy and Djex live-session limits are
domain-neutral and reused by the scalar and product runners. Each Leant call
productively admits no more than the shared 64-query maximum. Eager calls open
one fresh lexical worker for an eligible batch; deferred calls open at most one
fresh session, only at the first live miss, and then consume that session's
single total query budget. Behavioral authority is not shared: product
contracts, queries, live observations, replay receipts, failures, assessments,
MRU state, and presentation remain product-specific and cannot be cast from
their scalar siblings. The existing/default scalar path, public scalar types,
query bytes, neutral ranking behavior, and presentation are unchanged.

## Startup configuration examples by version

### Startup version 5: scalar bounded-positive ordering

Startup version 5 is the concrete scalar file opt-in. This complete unpinned
example checks input lengths 0 through 3 and prefers a candidate only after the
independent traversal finds no violation and at least one assignment satisfies
the precondition:

```json
{
  "format": "leant-live-length-ranking-configuration",
  "version": 5,
  "executionAdmission": {
    "executablePathCharacters": 4096,
    "policyFingerprintBytes": 262144
  },
  "execution": {
    "executablePath": "/absolute/path/to/z3",
    "expectedExecutableSha256": null,
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
    "inclusiveInputMaximums": [3],
    "maximumAssignments": 4
  },
  "counterexampleProbe": "origin-before-live",
  "boundedPositiveOrdering": "prefer-non-vacuous",
  "contract": {
    "spine": {"family": "List", "zero": "List.nil", "step": "List.cons"},
    "targetArgumentRoles": ["observed-spine"],
    "candidateCasePolicy": "cases-rejected",
    "precondition": ["truth", true],
    "postcondition": ["equal", ["result"], ["input", 0]],
    "providerLaws": []
  }
}
```

Version 5 embeds the full scalar v5 contract grammar, including explicit target
roles and case policy plus positive-literal modulo and quotient. Versions 1--3
retain their older embedded compatibility grammar and neutral positive ordering.
Because the example is unpinned, run it with the explicit relaxation:

```text
leant --length-ranking-config /absolute/path/scalar-ranking-v5.json \
  --length-ranking-allow-unpinned
```

### Contract-only version 6: binary-product pair contract

Main now exposes that same product path through closed, separately typed file
versions. Contract-only version 6 has the same three-field root as versions
1--5, but its version selects a pair contract and requires the closed result
shape. For example, `/absolute/path/pair-contract-v6.json` can state that the
first result length equals the input length and the second equals half of it:

```json
{
  "format": "leant-finite-list-spine-length-contract",
  "version": 6,
  "contract": {
    "resultShape": "binary-prod-spines-v1",
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

### Startup versions 4 and 6: pair ranking

Startup version 4 selects pair ranking process-wide and retains version 3's
required input box and origin-before-live policy while leaving positive receipts
neutral. Startup version 6 is its explicit preferred-positive successor. A
complete unpinned example is:

```json
{
  "format": "leant-live-length-ranking-configuration",
  "version": 6,
  "executionAdmission": {
    "executablePathCharacters": 4096,
    "policyFingerprintBytes": 262144
  },
  "execution": {
    "executablePath": "/absolute/path/to/z3",
    "expectedExecutableSha256": null,
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
    "inclusiveInputMaximums": [3],
    "maximumAssignments": 4
  },
  "counterexampleProbe": "origin-before-live",
  "boundedPositiveOrdering": "prefer-non-vacuous",
  "contract": {
    "resultShape": "binary-prod-spines-v1",
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

Because that example intentionally has no executable digest expectation, start
it only with the separate explicit relaxation:

```text
leant --length-ranking-config /absolute/path/pair-ranking-v6.json \
  --length-ranking-allow-unpinned
```

### Startup versions 7 and 8: positive-affine deferred opening

Startup v7 and v8 are the advanced scalar and pair successors. They keep the
same CLI and add no discovery or inferred defaults. This complete scalar v7
example uses distinct post-`unsat`, positive-affine, and simplification bounds:

```json
{
  "format": "leant-live-length-ranking-configuration",
  "version": 7,
  "executionAdmission": {
    "executablePathCharacters": 4096,
    "policyFingerprintBytes": 262144
  },
  "execution": {
    "executablePath": "/absolute/path/to/z3",
    "expectedExecutableSha256": null,
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
    "inclusiveInputMaximums": [5],
    "maximumAssignments": 6
  },
  "counterexampleProbe": "origin-before-live",
  "boundedPositiveOrdering": "prefer-non-vacuous",
  "applicableDomainValidation": {
    "strategy": "positive-affine-v1",
    "maximumInputs": 2,
    "maximumAssignments": 16
  },
  "applicableDomainOrdering": "prefer-non-vacuous",
  "counterexampleSimplification": {
    "strategy": "componentwise-lexicographic-v1",
    "maximumInputs": 1,
    "maximumAssignments": 8
  },
  "liveSessionOpening": "defer-until-live-query",
  "contract": {
    "spine": {"family": "List", "zero": "List.nil", "step": "List.cons"},
    "targetArgumentRoles": ["observed-spine"],
    "candidateCasePolicy": "cases-rejected",
    "precondition": [
      "at-most",
      ["sum", [["input", 0], ["literal", 1]]],
      ["literal", 4]
    ],
    "postcondition": ["equal", ["result"], ["input", 0]],
    "providerLaws": []
  }
}
```

Here the positive-affine rule derives the tight maximum `3` from
`input0 + 1 <= 4`. It still evaluates the complete precondition on every
assignment in `[0..3]`; the explicit `[0..5]` post-`unsat` box and the
simplifier's own limits are independent authorities. Because the executable is
intentionally unpinned, the unchanged startup command is:

```text
leant --length-ranking-config /absolute/path/scalar-ranking-v7.json \
  --length-ranking-allow-unpinned
```

The nominal pair v8 root has the same operational fields and embeds the pair v5
contract grammar. This complete example deliberately chooses three different
bounded objects as well:

```json
{
  "format": "leant-live-length-ranking-configuration",
  "version": 8,
  "executionAdmission": {
    "executablePathCharacters": 4096,
    "policyFingerprintBytes": 262144
  },
  "execution": {
    "executablePath": "/absolute/path/to/z3",
    "expectedExecutableSha256": null,
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
  "counterexampleProbe": "origin-before-live",
  "boundedPositiveOrdering": "prefer-non-vacuous",
  "applicableDomainValidation": {
    "strategy": "positive-affine-v1",
    "maximumInputs": 3,
    "maximumAssignments": 32
  },
  "applicableDomainOrdering": "prefer-non-vacuous",
  "counterexampleSimplification": {
    "strategy": "componentwise-lexicographic-v1",
    "maximumInputs": 1,
    "maximumAssignments": 9
  },
  "liveSessionOpening": "defer-until-live-query",
  "contract": {
    "resultShape": "binary-prod-spines-v1",
    "spine": {"family": "List", "zero": "List.nil", "step": "List.cons"},
    "targetArgumentRoles": ["observed-spine"],
    "candidateCasePolicy": "cases-rejected",
    "precondition": [
      "equal",
      ["sum", [["input", 0], ["literal", 1]]],
      ["literal", 4]
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

The equality derives maximum `3` but remains the actual filter, so only input
`3` is applicable. Start it through the same unchanged option grammar:

```text
leant --length-ranking-config /absolute/path/pair-ranking-v8.json \
  --length-ranking-allow-unpinned
```

### Startup versions 9 and 10: shared usable-work budget

Startup v9 and v10 retain those complete scalar and product policy bundles and
add only the required shared usable-work object. The exported version constants
are
`lengthRankingConfigurationFileUsableWorkBudgetVersion` (9) and
`lengthRankingConfigurationFileSpinePairUsableWorkBudgetVersion` (10).
This full scalar v9 example keeps the established 1,500-ms fresh local query
deadline while placing the whole admitted ranking callback beneath one
30,000-ms shared window:

```json
{
  "format": "leant-live-length-ranking-configuration",
  "version": 9,
  "executionAdmission": {
    "executablePathCharacters": 4096,
    "policyFingerprintBytes": 262144
  },
  "execution": {
    "executablePath": "/absolute/path/to/z3",
    "expectedExecutableSha256": null,
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
    "inclusiveInputMaximums": [5],
    "maximumAssignments": 6
  },
  "counterexampleProbe": "origin-before-live",
  "boundedPositiveOrdering": "prefer-non-vacuous",
  "applicableDomainValidation": {
    "strategy": "positive-affine-v1",
    "maximumInputs": 2,
    "maximumAssignments": 16
  },
  "applicableDomainOrdering": "prefer-non-vacuous",
  "counterexampleSimplification": {
    "strategy": "componentwise-lexicographic-v1",
    "maximumInputs": 1,
    "maximumAssignments": 8
  },
  "liveSessionOpening": "defer-until-live-query",
  "usableWorkBudget": {
    "strategy": "shared-usable-work-deadline-v1",
    "milliseconds": 30000
  },
  "contract": {
    "spine": {"family": "List", "zero": "List.nil", "step": "List.cons"},
    "targetArgumentRoles": ["observed-spine"],
    "candidateCasePolicy": "cases-rejected",
    "precondition": [
      "at-most",
      ["sum", [["input", 0], ["literal", 1]]],
      ["literal", 4]
    ],
    "postcondition": ["equal", ["result"], ["input", 0]],
    "providerLaws": []
  }
}
```

The nominal product v10 sibling uses the same root policy and the complete pair
contract grammar:

```json
{
  "format": "leant-live-length-ranking-configuration",
  "version": 10,
  "executionAdmission": {
    "executablePathCharacters": 4096,
    "policyFingerprintBytes": 262144
  },
  "execution": {
    "executablePath": "/absolute/path/to/z3",
    "expectedExecutableSha256": null,
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
  "counterexampleProbe": "origin-before-live",
  "boundedPositiveOrdering": "prefer-non-vacuous",
  "applicableDomainValidation": {
    "strategy": "positive-affine-v1",
    "maximumInputs": 3,
    "maximumAssignments": 32
  },
  "applicableDomainOrdering": "prefer-non-vacuous",
  "counterexampleSimplification": {
    "strategy": "componentwise-lexicographic-v1",
    "maximumInputs": 1,
    "maximumAssignments": 9
  },
  "liveSessionOpening": "defer-until-live-query",
  "usableWorkBudget": {
    "strategy": "shared-usable-work-deadline-v1",
    "milliseconds": 30000
  },
  "contract": {
    "resultShape": "binary-prod-spines-v1",
    "spine": {"family": "List", "zero": "List.nil", "step": "List.cons"},
    "targetArgumentRoles": ["observed-spine"],
    "candidateCasePolicy": "cases-rejected",
    "precondition": [
      "equal",
      ["sum", [["input", 0], ["literal", 1]]],
      ["literal", 4]
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

Both examples are deliberately unpinned and therefore require the same
separate `--length-ranking-allow-unpinned` activation choice as v7/v8. The
usable-work object has exactly `strategy` followed semantically by
`milliseconds`; JSON member order is immaterial. Its strategy literal is exact,
the duration must be positive, and the file grammar caps it at 65,000 ms before
delegating to Djex's representability validator.

### Root fields and validation order for versions 7 to 10

The v7/v8 advanced roots have exactly these fields in semantic validation order:
`format`, `version`, `executionAdmission`, `execution`, `evaluation`,
`inputBoxValidation`, `counterexampleProbe`, `boundedPositiveOrdering`,
`applicableDomainValidation`, `applicableDomainOrdering`,
`counterexampleSimplification`, `liveSessionOpening`, and `contract`. JSON
member order is immaterial. The two strategy objects have exactly `strategy`,
`maximumInputs`, and `maximumAssignments`; their caps are 8 inputs and 65,536
assignments. The exact literals are `positive-affine-v1`,
`prefer-non-vacuous`, `componentwise-lexicographic-v1`, and
`defer-until-live-query`. The explicit input-box vector is independently capped
at eight entries and 65,536 assignments. The existing 256-KiB JSON,
4,096-character executable path, 64-KiB response, 60,000-ms solver timeout,
10,000,000 resource limit, 65,000-ms host deadline, and 4,096-bit evaluation
and response-integer ceilings remain unchanged. Missing, extra, mistyped, or
over-cap content fails closed in that demand order before the later
contract can preempt an earlier operational error.

V9/v10 retain that exact order and insert `usableWorkBudget` only after
`liveSessionOpening` and before `contract`. The generalized dispatcher reaches
their parser only after every literal v1--v8 decoder has returned the closed
unsupported-version sentinel. Once v9 or v10 is selected from its already
decoded `format` and `version`, exact-root admission precedes every operational
field. The established fields are then validated in their old order, followed
by the exact budget object, strategy, milliseconds cap and Djex budget
validation, and only then the scalar-v5 or pair-v5 contract. An earlier
operational or budget error therefore cannot be preempted by a later malformed
contract.

### Startup versions 11 and 12: relational positive-affine

Startup v11 and v12 select relational positive-affine applicable-domain
validation without selecting the v9/v10 shared usable-work owner. The exported
version constants are
`lengthRankingConfigurationFileRelationalPositiveAffineVersion` (11) and
`lengthRankingConfigurationFileSpinePairRelationalPositiveAffineVersion`
(12). This complete scalar v11 document lets the bound on input 1 flow through
an equality to input 0:

```json
{
  "format": "leant-live-length-ranking-configuration",
  "version": 11,
  "executionAdmission": {
    "executablePathCharacters": 4096,
    "policyFingerprintBytes": 262144
  },
  "execution": {
    "executablePath": "/absolute/path/to/z3",
    "expectedExecutableSha256": null,
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
  "counterexampleProbe": "origin-before-live",
  "boundedPositiveOrdering": "prefer-non-vacuous",
  "applicableDomainValidation": {
    "strategy": "relational-positive-affine-v1",
    "maximumInputs": 2,
    "maximumAssignments": 36
  },
  "applicableDomainOrdering": "prefer-non-vacuous",
  "counterexampleSimplification": {
    "strategy": "componentwise-lexicographic-v1",
    "maximumInputs": 2,
    "maximumAssignments": 36
  },
  "liveSessionOpening": "defer-until-live-query",
  "contract": {
    "spine": {"family": "List", "zero": "List.nil", "step": "List.cons"},
    "targetArgumentRoles": ["observed-spine", "observed-spine"],
    "candidateCasePolicy": "cases-rejected",
    "precondition": [
      "all",
      [
        ["equal", ["input", 0], ["input", 1]],
        ["at-most", ["input", 1], ["literal", 5]]
      ]
    ],
    "postcondition": ["equal", ["result"], ["input", 0]],
    "providerLaws": []
  }
}
```

The relational rule derives maxima `[5, 5]`, then the existing finite-box
verifier checks all 36 assignments. Exactly six diagonal assignments satisfy
the precondition. The independent post-`unsat` box happens to use the same
maxima in this example; it remains a separate authority and is not used to
derive the applicable domain.

The nominal product v12 document uses exact coefficient cancellation to reduce
`2 * input0 <= input0 + 1` to `input0 <= 1`:

```json
{
  "format": "leant-live-length-ranking-configuration",
  "version": 12,
  "executionAdmission": {
    "executablePathCharacters": 4096,
    "policyFingerprintBytes": 262144
  },
  "execution": {
    "executablePath": "/absolute/path/to/z3",
    "expectedExecutableSha256": null,
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
  "counterexampleProbe": "origin-before-live",
  "boundedPositiveOrdering": "prefer-non-vacuous",
  "applicableDomainValidation": {
    "strategy": "relational-positive-affine-v1",
    "maximumInputs": 1,
    "maximumAssignments": 8
  },
  "applicableDomainOrdering": "prefer-non-vacuous",
  "counterexampleSimplification": {
    "strategy": "componentwise-lexicographic-v1",
    "maximumInputs": 1,
    "maximumAssignments": 9
  },
  "liveSessionOpening": "defer-until-live-query",
  "contract": {
    "resultShape": "binary-prod-spines-v1",
    "spine": {"family": "List", "zero": "List.nil", "step": "List.cons"},
    "targetArgumentRoles": ["observed-spine"],
    "candidateCasePolicy": "cases-rejected",
    "precondition": [
      "at-most",
      ["scale", 2, ["input", 0]],
      ["sum", [["input", 0], ["literal", 1]]]
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

Both documents intentionally have the exact v7/v8 root fields and validation
order. Their `applicableDomainValidation` object still has exactly `strategy`,
`maximumInputs`, and `maximumAssignments`; only the strategy literal is the new
`relational-positive-affine-v1`. The existing width cap of 8 and assignment
cap of 65,536 apply. The scalar-v5 or pair-v5 contract remains last.
`usableWorkBudget` is not optional here: it is an unknown extra root field and
is rejected. Consequently startup v11/v12 retain deferred opening but use the
historical separate opener/finalizer and fresh per-query host deadlines rather
than a shared ranking owner. A programmatic caller may independently compose
the relational builder with a validated budget, but the versioned schemas do
not infer that composition.

The generalized decoder reaches the v11/v12 parser only after the literal
v1--v10 chain returns its closed unsupported-version sentinel. The relational
parser reuses the established applicable-domain object, field, limit, and
validation-error identities, validates the exact operational root in its
established order, and demands the contract last. Both examples are unpinned
and therefore require the separate explicit
`--length-ranking-allow-unpinned` activation choice.

### Startup versions 13 and 14: scoped usable-work lease

Startup v13 and v14 combine the relational scalar/product choices with Djex's
dynamically scoped v2 usable-work lease. Their exported constants are
`lengthRankingConfigurationFileScopedUsableWorkBudgetVersion` (13) and
`lengthRankingConfigurationFileSpinePairScopedUsableWorkBudgetVersion` (14).
This complete scalar v13 document retains the v11 relation and adds the budget
after `liveSessionOpening`:

```json
{
  "format": "leant-live-length-ranking-configuration",
  "version": 13,
  "executionAdmission": {
    "executablePathCharacters": 4096,
    "policyFingerprintBytes": 262144
  },
  "execution": {
    "executablePath": "/absolute/path/to/z3",
    "expectedExecutableSha256": null,
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
  "counterexampleProbe": "origin-before-live",
  "boundedPositiveOrdering": "prefer-non-vacuous",
  "applicableDomainValidation": {
    "strategy": "relational-positive-affine-v1",
    "maximumInputs": 2,
    "maximumAssignments": 36
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
        ["equal", ["input", 0], ["input", 1]],
        ["at-most", ["input", 1], ["literal", 5]]
      ]
    ],
    "postcondition": ["equal", ["result"], ["input", 0]],
    "providerLaws": []
  }
}
```

The nominal product v14 sibling uses the complete pair-v5 contract and exact
coefficient cancellation from the v12 example:

```json
{
  "format": "leant-live-length-ranking-configuration",
  "version": 14,
  "executionAdmission": {
    "executablePathCharacters": 4096,
    "policyFingerprintBytes": 262144
  },
  "execution": {
    "executablePath": "/absolute/path/to/z3",
    "expectedExecutableSha256": null,
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
  "counterexampleProbe": "origin-before-live",
  "boundedPositiveOrdering": "prefer-non-vacuous",
  "applicableDomainValidation": {
    "strategy": "relational-positive-affine-v1",
    "maximumInputs": 1,
    "maximumAssignments": 8
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
      "at-most",
      ["scale", 2, ["input", 0]],
      ["sum", [["input", 0], ["literal", 1]]]
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

V13/v14 have exactly the v9/v10 root fields, but they require the relational
applicable-domain strategy and the scoped-v2 budget strategy. After bounded JSON
and `format`/`version` routing, their fixed semantic validation order is exact
root admission; `executionAdmission`; `execution`; `evaluation`;
`inputBoxValidation`; `counterexampleProbe`; `boundedPositiveOrdering`; the
relational `applicableDomainValidation` object's exact fields, strategy, width,
cardinality, and Djex limit validation; `applicableDomainOrdering`;
`counterexampleSimplification`; `liveSessionOpening`; the `usableWorkBudget`
object's exact fields, strategy, integer type, 65,000-ms cap, and Djex
representability validation; then the scalar-v5 or pair-v5 contract. A later
contract error cannot preempt an earlier operational, domain, or budget error.
JSON object member order remains immaterial.

The generalized dispatcher attempts this final parser only after the complete
v1--v12 chain returns its closed unsupported-version sentinel. The compatibility
matrix is therefore literal: v1--v8 have no shared budget; v9/v10 select the
runtime-unscoped `shared-usable-work-deadline-v1`; v11/v12 select relational
positive-affine validation with no budget; and v13/v14 select that relational
validator with `scoped-checkpointed-shared-usable-work-deadline-v2`. V13/v14
reuse the existing budget object, field, type, value, cap, and Djex-rejection
diagnostic identities rather than introducing evidence-bearing schema. These
examples are also unpinned and require the explicit
`--length-ranking-allow-unpinned` activation choice.

### Startup versions 15 and 16: strict relational positive-affine

Startup v15 and v16 preserve that complete scoped root and runtime route while
selecting Djex's strict relational rule. Their exported constants are
`lengthRankingConfigurationFileStrictRelationalPositiveAffineVersion` (15) and
`lengthRankingConfigurationFileSpinePairStrictRelationalPositiveAffineVersion`
(16). This complete scalar v15 document uses strict-only clauses to derive
maxima `[4, 3]`:

```json
{
  "format": "leant-live-length-ranking-configuration",
  "version": 15,
  "executionAdmission": {
    "executablePathCharacters": 4096,
    "policyFingerprintBytes": 262144
  },
  "execution": {
    "executablePath": "/absolute/path/to/z3",
    "expectedExecutableSha256": null,
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
  "counterexampleProbe": "origin-before-live",
  "boundedPositiveOrdering": "prefer-non-vacuous",
  "applicableDomainValidation": {
    "strategy": "strict-relational-positive-affine-v1",
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

The first clause is `not (5 <= input0)`, which becomes
`input0 + 1 <= 5`; the second is `not (input0 <= input1)`, which becomes
`input1 + 1 <= input0`. Synchronous rule-once propagation therefore derives
`[4, 3]`, and the applicable-domain traversal admits its 20-assignment box.

The nominal product v16 sibling uses the complete pair-v5 contract. Its strict
clause exercises successor-before-coefficient-cancellation and derives maximum
`[2]`:

```json
{
  "format": "leant-live-length-ranking-configuration",
  "version": 16,
  "executionAdmission": {
    "executablePathCharacters": 4096,
    "policyFingerprintBytes": 262144
  },
  "execution": {
    "executablePath": "/absolute/path/to/z3",
    "expectedExecutableSha256": null,
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
  "counterexampleProbe": "origin-before-live",
  "boundedPositiveOrdering": "prefer-non-vacuous",
  "applicableDomainValidation": {
    "strategy": "strict-relational-positive-affine-v1",
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

Here `not (input0 + 3 <= 2 * input0)` becomes
`2 * input0 + 1 <= input0 + 3`. Exact cancellation leaves
`input0 + 1 <= 3`, so the three assignments `[0]`, `[1]`, and `[2]` form the
complete derived box.

V15/v16 have exactly the v13/v14 root fields, scoped-v2 budget object, scalar-
v5/pair-v5 contract grammars, semantic demand order, caps, and diagnostics.
Only the applicable-domain strategy literal and resulting nominal assessment
family differ. The generalized dispatcher reaches them only after every
v1--v14 entrance returns its closed unsupported-version sentinel. The strict
extractor accepts the ordinary relational rules plus immediate normalized
top-level `not (L <= R)` as `R + 1 <= L`; negated equality, nested logical
structure, and unsupported expression subtrees grant no partial bound. These
examples are unpinned and require the explicit
`--length-ranking-allow-unpinned` activation choice.

### Startup versions 17 and 18: descriptor-bound executable launch

Startup v17 and v18 retain that exact strict/scoped behavioral profile and
change only executable-launch authority. Their exported constants are
`lengthRankingConfigurationFileDescriptorBoundExecutableLaunchVersion` (17)
and
`lengthRankingConfigurationFileSpinePairDescriptorBoundExecutableLaunchVersion`
(18). The execution object has the complete inherited fields plus the
additional required member `"executableLaunch": "descriptor-bound-executable-v1"`. This is a
complete scalar v17 document:

```json
{
  "format": "leant-live-length-ranking-configuration",
  "version": 17,
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
    "strategy": "strict-relational-positive-affine-v1",
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

The nominal product v18 sibling retains the complete pair-v5 contract and
strict successor-before-cancellation example:

```json
{
  "format": "leant-live-length-ranking-configuration",
  "version": 18,
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
    "strategy": "strict-relational-positive-affine-v1",
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

Replace the illustrative 64-hex-digit expectation in either document with the
digest of the intended Z3 image. Activation checks only that the expectation is
present; matching occurs at the first live open. Djex then opens the source
without following the final component, hashes each bounded chunk while copying
the same bytes into an anonymous image, compares the pin, seals writes and size
changes, and invokes `execveat` only on that sealed descriptor. No worker or
executable IO occurs if the deferred pure prefix settles the batch. A namespace
swap or in-place source rewrite after sealing cannot alter the staged main
image, and any unavailable primitive or failure is terminal rather than a
fallback to v15/v16 path launch.

The child requires Linux `close_range` to close every unrelated inherited
descriptor before `execveat`. If the primitive is unavailable or rejects a
required segment, descriptor launch fails closed; Djex does not substitute a
scan capped by the current soft `RLIMIT_NOFILE`, which may lie below a
descriptor opened before the limit was lowered.

The guarantee is main-image-only: it does not attest an ELF interpreter,
dynamic loader, shared library, file capability, set-id metadata, Z3 semantics,
or solver result. V17/v18 add no assessment constructor, ranking tier, or
candidate presentation note. Their startup notice reports only that descriptor
launch was selected; it never says the pin matched. Their fixed validation
order is the v15/v16 order with the execution object's required launch literal
checked after every inherited execution member and before Djex descriptor
policy sealing. Contract validation remains last. The generalized dispatcher
reaches v17/v18 only after the exact v1--v16 cascade returns UnsupportedVersion;
v19/v20 are handled only by their later quotient-consequence decoder, and
v21/v22 only by the subsequent effective-ID launch successor.

### Startup versions 19 and 20: root-quotient consequences

Startup v19 and v20 retain the complete descriptor-bound/scoped profiles and
replace only the applicable-domain strategy selection. Their exported
constants are
`lengthRankingConfigurationFileStrictRelationalPositiveAffineQuotientVersion`
(19) and
`lengthRankingConfigurationFileSpinePairStrictRelationalPositiveAffineQuotientVersion`
(20). This complete scalar v19 document is the scalar v17 example with only
the version and applicable-domain strategy selections advanced:

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

The complete nominal pair v20 document advances the pair v18 selections in
the same way:

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

The unchanged example contracts make the schema delta explicit: the fifth
extractor is an additive strict superset, so both established strict-only
examples retain their prior derived boxes. A quotient-bearing precondition can
instead use, for example, `q_3(input0) <= 2` to derive `input0 <= 8`, or combine
`input0 <= q_3(input1)` with `input1 <= 8` to derive source-ordered maxima
`[2, 8]`. Equality contributes both directions and can therefore propagate a
bound through either source orientation.

V19/v20 preserve v17/v18's exact root fields, descriptor execution object,
scoped-v2 budget, deferred lifecycle, caps, diagnostics, and scalar-v5/pair-v5
contract grammars. Validation order remains exact root admission;
`executionAdmission`; inherited execution fields; the required launch
discriminator; descriptor policy sealing; `evaluation`; `inputBoxValidation`;
`counterexampleProbe`; `boundedPositiveOrdering`; the quotient applicable-
domain object's exact fields, literal, width, cardinality, and Djex limits;
`applicableDomainOrdering`; `counterexampleSimplification`;
`liveSessionOpening`; scoped budget; then contract. The dispatcher reaches
v19/v20 only after the exact v1--v18 cascade returns UnsupportedVersion;
v21/v22 are handled only by their later effective-ID executable-access
decoder. Loading and activation remain pure, and an all-pure deferred batch
opens neither an executable descriptor, an access checker, nor a worker.

### Startup versions 21 and 22: effective-ID executable access

Startup v21 and v22 retain that complete quotient/scoped profile and replace
only the executable-launch selection. Their exported constants are
`lengthRankingConfigurationFileDescriptorBoundEffectiveIDExecutableAccessVersion`
(21) and
`lengthRankingConfigurationFileSpinePairDescriptorBoundEffectiveIDExecutableAccessVersion`
(22). The complete scalar v21 document is the scalar v19 example with only
the version and launch literal advanced:

```json
{
  "format": "leant-live-length-ranking-configuration",
  "version": 21,
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

The complete nominal pair v22 document changes those same two selections in
the pair v20 example:

```json
{
  "format": "leant-live-length-ranking-configuration",
  "version": 22,
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

The required launch literal is exactly
`"descriptor-bound-effective-id-executable-access-v1"`. The inherited
execution fields are validated in their established order before that final
discriminator and Djex policy sealing; evaluation, input box, probe,
preferences, quotient-domain limits, simplification, deferred opening,
scoped-v2 budget, and contract then retain v19/v20 order and caps. The
dispatcher reaches v21/v22 only after the exact v1--v20 cascade returns
UnsupportedVersion. V1--v20 remain exact and reject the new member or literal
wherever their own closed schema does not admit it; v23/v24 are reached only by
the later root-extrema decoder.

At the first live miss, Djex checks the opened source descriptor with
`faccessat2(fd, "", X_OK, AT_EMPTY_PATH | AT_EACCESS)` before copying and
again after pin/sealed-image admission immediately before child allocation.
The staged memfd is fixed to mode `0500`, sealed, verified, and executed by
descriptor. These are point-in-time effective-filesystem-credential VFS
observations, not a reservation or full `exec`/`bprm`/LSM/IMA/binfmt check.
Source ownership, group, ACLs, set-id bits, capabilities, extended attributes,
security labels, and mount identity are not copied; loaders, interpreters,
libraries, solver semantics, and results remain unbound. No unsupported
platform, syscall, flag, access, staging, or exec failure falls back to v19/v20
descriptor launch or the pathname launcher.

### Startup versions 23 and 24: root-extrema consequences

Startup v23 and v24 preserve the complete v21/v22 effective-ID launch,
scoped-v2 budget, deferred lifecycle, preference, simplification, and scalar-v5
or pair-v5 contract roots. They replace only the applicable-domain strategy.
Their exported constants are
`lengthRankingConfigurationFileStrictRelationalPositiveAffineQuotientRootExtremaVersion`
(23) and
`lengthRankingConfigurationFileSpinePairStrictRelationalPositiveAffineQuotientRootExtremaVersion`
(24). The complete scalar v23 document is therefore the scalar v21 document
with only those two closed selections advanced:

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

The complete nominal pair v24 document is likewise the pair v22 document with
only the version and strategy literal changed:

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

The required strategy literal is exactly
`"strict-relational-positive-affine-quotient-root-extrema-v1"`. Validation
retains v21/v22's exact field order and caps, changing only the selected
applicable-domain validator and nominal receipt. The dispatcher reaches v23/v24
only after the complete v1--v22 cascade returns `UnsupportedVersion`; v25/v26
are reached only by the still later root-monus decoder. Every v1--v22 decoder
remains literal and rejects the new version or strategy wherever its own closed
schema does not admit it.

V23/v24 retain query-owned replay, the non-vacuous applicable-domain
preference, deferred live opening, one owner-thread-affine scoped-v2 absolute
deadline, cooperative phase checkpoints, and Leant-owned deep result forcing.
An all-pure batch still performs no executable or access-check IO. Failure at
access checking, staging, opening, live assessment, replay, forcing, or scope
finalization maps through the existing closed failure classes and atomically
restores original order; it creates no partial receipt and never falls back to
an older launch or domain validator. The new nominal receipt tags are evidence
and presentation distinctions only: query, wire, problem, fingerprint,
association, executable, and scoped-owner identities remain unchanged.

### Startup versions 25 and 26: root-monus consequences

Startup v25 and v26 preserve the complete v23/v24 effective-ID launch,
scoped-v2 budget, deferred lifecycle, preference, simplification, and scalar-v5
or pair-v5 contract roots. They replace only the applicable-domain strategy.
Their exported constants are
`lengthRankingConfigurationFileStrictRelationalPositiveAffineQuotientRootExtremaMonusVersion`
(25) and
`lengthRankingConfigurationFileSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusVersion`
(26). The complete scalar v25 document is therefore the scalar v23 document
with only those two closed selections advanced:

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

The complete nominal pair v26 document is likewise the pair v24 document with
only the version and strategy literal changed:

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

The required strategy literal is exactly
`"strict-relational-positive-affine-quotient-root-extrema-monus-v1"`.
Validation retains v23/v24's exact root and nested field order, caps, effective-
ID execution constructor, scoped owner, and scalar/pair contract decoder.
Only the selected applicable-domain validator and nominal receipt change. The
generalized dispatcher reaches v25/v26 only after the complete v1--v24 cascade
returns `UnsupportedVersion`; v27/v28 are reached only by the later execve-
check executable-access decoder. Every v1--v24 decoder remains literal and
rejects the new version or strategy wherever its own closed schema does not
admit it.

V25/v26 retain query-owned replay, both non-vacuous preferences,
counterexample simplification and final-vector MRU promotion, deferred opening,
one owner-thread-affine scoped-v2 absolute deadline, cooperative phase
checkpoints, and Leant-owned deep result forcing. An all-pure batch still
performs no executable or access-check IO. Failure at access checking, staging,
opening, live assessment, replay, forcing, or scope finalization maps through
the existing closed failure classes and atomically restores original order; it
creates no partial receipt and never falls back to an older launch or domain
validator. The effective-ID launch startup notice is unchanged because v25/v26
inherit the same launch strategy. New scalar and pair receipt tags are additive
evidence identities only: contract, problem, query, wire, fingerprint,
association, executable, worker, run, and scoped-owner identities remain
unchanged.

### Startup versions 27 and 28: execve-check executable access

Startup v27 and v28 preserve the complete v25/v26 root-monus applicable-
domain, scoped-v2 budget, deferred lifecycle, preference, simplification, and
scalar-v5 or pair-v5 contract roots. They replace only the executable-launch
selection. Their exported constants are
`lengthRankingConfigurationFileDescriptorBoundExecveCheckExecutableAccessVersion`
(27) and
`lengthRankingConfigurationFileSpinePairDescriptorBoundExecveCheckExecutableAccessVersion`
(28). Programmatic callers select the same launch with
`mkLengthRankingPolicyWithDescriptorBoundExecveCheckExecutableAccessLaunch`.
The complete scalar v27 document is therefore the scalar v25 document
with only its version and launch literal advanced:

```json
{
  "format": "leant-live-length-ranking-configuration",
  "version": 27,
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

The complete nominal pair v28 document is likewise the pair v26 document with
only the same two selections advanced:

```json
{
  "format": "leant-live-length-ranking-configuration",
  "version": 28,
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

The required launch literal is exactly
`"descriptor-bound-execve-check-executable-access-v1"`. V27/v28 retain
v25/v26's exact root and nested field sets, caps, and demand order. The
execution decoder checks response limits first, then executable path, digest,
the 60,000-ms solver-timeout cap, the 10,000,000 resource cap, the 65,000-ms
host-deadline cap, and artifact policy before requiring the launch field's
string type and exact literal and sealing the Djex policy. Evaluation, input
box, origin probe, bounded-positive preference, root-monus applicable-domain
limits, applicable-domain preference, simplification, deferred opening,
scoped-v2 budget, and scalar-v5 or pair-v5 contract retain their v25/v26
order. The generalized dispatcher reaches v27/v28 only after the complete
v1--v26 cascade returns `UnsupportedVersion`; v29/v30 are reached only by the
later Boolean finite-union decoder, and v31/v32 only by its atomic-branching
successor; v33/v34 are handled only by the recursive piecewise-affine
successor. Every v1--v26 entrance remains literal and rejects the new version,
member, or launch literal wherever its closed schema does not admit it.

Loading, activation, and policy construction remain pure. An all-pure deferred
batch opens no source descriptor, invokes no access checker, creates no staged
image, and launches no worker. At the first demanded live miss, the Linux
opener performs source `faccessat2(..., X_OK, AT_EMPTY_PATH | AT_EACCESS)` and
source `execveat(..., AT_EMPTY_PATH | AT_EXECVE_CHECK)` before copying. It
creates the staged image with `MFD_EXEC`, hashes and pins the copied bytes,
sets mode `0500`, and adds and verifies the write, grow, shrink, future-write,
exec, and final-seal prohibitions. After its deterministic hook it repeats
both source checks and checks the sealed staged descriptor once before child
allocation. Only then may the established descriptor-only spawn path run.
There is no pathname, older-launch, non-`MFD_EXEC`, reduced-seal, or unchecked
fallback. On a stock Linux 5.15 kernel the first source exec check fails closed
as unavailable before staging or child allocation; Linux 6.14 or later is
necessary but not sufficient for live admission.

Source or staged denial maps through Djex to the existing executable-rejected
Leant session path; checker unavailable or failed maps through the existing launch-
failed path. Leant introduces no failure class, and any access, staging, live,
replay, forcing, or finalization failure still atomically restores literal
original order. The new execution-policy, raw-process, ready-worker, and
fresh/shared/scoped scalar and pair run identities are operationally domain-
separated. Contract, root-monus problem, query, wire, receipt, replay,
association, presentation, and scoped-owner semantics remain unchanged.

The checks are point-in-time observations, not reservations or source-
authorization transfers. `AT_EXECVE_CHECK` deliberately ignores file-format
and interpreter dependencies, and this profile does not attest every later
`bprm` decision, credential transition, source metadata, loader, interpreter,
library, solver behavior, result, proof, or pruning authority. Main emits the
following fixed classifier-derived notice without claiming completed IO:

```text
Descriptor-bound execve-check executable-access launch selected; the opened source must pass Linux faccessat2 X_OK under effective filesystem credentials and AT_EXECVE_CHECK before copying and again immediately before child allocation; the sealed staged image must pass AT_EXECVE_CHECK immediately before child allocation; any configured digest is checked against the sealed staged main-image bytes.
```

### Startup versions 29 and 30: Boolean finite-union applicable domains

Startup v29 and v30 preserve the complete v27/v28 execve-check launch,
scoped-v2 budget, deferred lifecycle, preference, simplification, and
scalar-v5 or pair-v5 contract roots. They replace only the applicable-domain
selection. Their exported constants are
`lengthRankingConfigurationFileStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionVersion`
(29) and
`lengthRankingConfigurationFileSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionVersion`
(30). Programmatic callers make the same selection with
`enableLengthRankingStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionApplicableDomainValidation`.

The complete scalar v29 document is:

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

The complete nominal pair v30 document is:

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

The `applicableDomainValidation` object is closed and contains exactly eight
members in its diagnostic order: `strategy`, `maximumInputs`,
`maximumGeneratedBranches`, `maximumRulesPerBranch`,
`maximumClosureInspectionsPerBranch`, `maximumRetainedBoxes`,
`maximumAssignmentVisits`, and `maximumAssignments`. Their required strategy
literal and numeric file caps are respectively the exact literal above, 8,
256, 64, 4096, 256, 262144, and 65536. The first and last numeric fields create
the existing input-box width and unique-assignment authority; the five middle
fields create the independent Boolean finite-union authority. Unknown members
are rejected before missing members, and missing members follow that listed
order.

The inherited full policy demand order is root schema, execution admission,
execve-check execution, evaluation, post-`unsat` input box, origin probe,
bounded-positive preference, the eight-field applicable-domain object,
applicable-domain preference, simplification, deferred opening, scoped-v2
budget, then scalar-v5 or pair-v5 contract. The generalized dispatcher reaches
v29/v30 only after the complete v1--v28 cascade returns
`UnsupportedVersion`; v31/v32 are reached only by the later atomic-branching
decoder, v33/v34 only by the recursive piecewise-affine decoder, and v35 is
the current next unsupported sentinel. Every v1--v28 route
remains literal and rejects the new versions or strategies where its closed
schema does not admit them.

Configuration loading, activation, and policy construction remain pure. An
all-pure deferred batch still captures and checks its scoped deadline clock,
but performs no executable, access-check, staging, or worker IO. An actual
live miss retains v27/v28's exact execve-check launch
and scoped deadline. The new strategy can complete before that miss, so a pure
finite-union establishment or counterexample opens no worker. Non-vacuous
finite-union establishment participates in the existing applicable-domain
preference; vacuous establishment remains neutral. A replayed counterexample
still enters the common simplification path and only the final vector enters
the four-entry newest-first MRU bank.

The public scalar assessment is
`StrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionApplicableDomainEstablished`;
the pair assessment is
`LengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionApplicableDomainEstablished`.
Their renderers are the two Boolean finite-union renderers named above. Leant's
closed scalar and pair failure classes are
`LengthRankingBooleanFiniteUnionApplicableDomainValidationFailed` and
`LengthSpinePairRankingBooleanFiniteUnionApplicableDomainValidationFailed`.
Admission-limit failures are ordinary absence of this assessment. Assignment-
evaluation or internal-enumeration failure, association mismatch, live
failure, deep forcing failure, or finalization failure is atomic and restores
literal original order. No partial receipt or fallback to root-monus is
exposed.

V29/v30 add only nominal receipt schema identities and the corresponding
evidence and presentation distinctions. They do not revise contract, problem,
query, SMT-LIB bytes, fingerprint, association, execve-check execution,
ready-worker, fresh/shared/scoped query-run, or scoped-owner identities. Their
authority is exactly the canonical finite union replayed under the checked
contract; it is neither a componentwise hull, a general Boolean solver, a Z3
proof, a global theorem, nor pruning authority.

### Startup versions 31 and 32: atomic-branching finite unions

Startup v31 and v32 retain the complete v29/v30 root, eight-field applicable-
domain object,
execve-check launch, scoped-v2 budget, deferred lifecycle, preference,
simplification, and scalar-v5 or pair-v5 contract. They replace only the
applicable-domain strategy. Their constants are
`lengthRankingConfigurationFileStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingVersion`
(31) and
`lengthRankingConfigurationFileSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingVersion`
(32). Programmatic callers select the same strategy with
`enableLengthRankingStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingApplicableDomainValidation`.

The complete scalar v31 document is the v29 document with only `version` and
`strategy` changed:

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
same two values changed:

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

The applicable-domain object still has exactly eight members in this demand
order: strategy, maximum inputs, generated branches, rules per branch, closure
inspections per branch, retained boxes, assignment visits, and unique
assignments. The numeric caps remain 8, 256, 64, 4096, 256, 262144, and
65536, with the same negative and cap-plus-one diagnostics and the same
defensive checked-builder error. The full root and nested validation order is
literal v29/v30. The generalized decoder reaches v31/v32 only after the
complete v1--v30 cascade returns `UnsupportedVersion`; v33/v34 are handled by
the later recursive piecewise-affine decoder, and v35 is the current next
unsupported sentinel. Every v1--v30 decoder and closed strategy literal is a
current regression reference, not a promised compatibility surface.

The scalar assessment is
`StrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingApplicableDomainEstablished`;
the pair assessment is
`LengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingApplicableDomainEstablished`.
They use the two matching atomic-branching renderers. The strategy reuses
`LengthRankingBooleanFiniteUnionApplicableDomainValidationFailed` and
`LengthSpinePairRankingBooleanFiniteUnionApplicableDomainValidationFailed`,
including the predecessor's ordinary-admission and indexed atomic-failure
classification.

Loading, activation, builder composition, and the new finite-union validation
remain pure. Every all-pure v31/v32 batch still captures and checks the
scoped-v2 deadline clock but opens no descriptor, performs no source or staged
access check, stages no image, and launches no worker. A later live miss
inherits v29/v30's complete execve-check launch and scoped lifecycle.
Non-vacuous receipts enter the existing preferred partition, vacuous receipts
remain neutral, counterexamples use the common simplification/MRU path, and
any operational or forcing failure restores literal original order.

V31/v32 add only fresh scalar/product receipt schema identities and their
evidence/presentation branches. They change no checked contract, behavioral
problem, query, SMT-LIB bytes, fingerprint, association, executable policy,
process, ready worker, fresh/shared/scoped run, or scoped-owner identity. Their
authority is exact bounded replay of the canonical union under the original
formula—not a hull, solver proof, global theorem, or pruning grant. See the
[atomic-branching Length ranking report](reports/2026-08-15-atomic-branching-length-ranking.md)
and Djex's
[atomic-branching applicable-domain report](../lib/Djex/docs/reports/2026-08-15-atomic-branching-length-applicable-domain.md).

### Startup versions 33 and 34: recursive piecewise-affine branching

Startup v33 and v34 are current-tree scalar/product selectors. They retain the
complete v31/v32 root, eight-field applicable-domain object, execve-check
launch, scoped-v2 budget, deferred lifecycle, both preferences,
simplification, and scalar-v5 or pair-v5 contract. They replace only the
applicable-domain strategy. Their constants are
`lengthRankingConfigurationFileStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingRecursivePiecewiseAffineVersion`
(33) and
`lengthRankingConfigurationFileSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingRecursivePiecewiseAffineVersion`
(34). Programmatic callers select the same strategy with
`enableLengthRankingStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingRecursivePiecewiseAffineApplicableDomainValidation`.

The complete scalar v33 document is a v31 clone with only `version` and
`strategy` changed:

```json
{
  "format": "leant-live-length-ranking-configuration",
  "version": 33,
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
    "strategy": "strict-relational-positive-affine-quotient-root-extrema-monus-boolean-finite-union-atomic-branching-recursive-piecewise-affine-v1",
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

The complete nominal pair v34 document is a v32 clone with the same two
selection changes:

```json
{
  "format": "leant-live-length-ranking-configuration",
  "version": 34,
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
    "strategy": "strict-relational-positive-affine-quotient-root-extrema-monus-boolean-finite-union-atomic-branching-recursive-piecewise-affine-v1",
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

These examples deliberately keep the v31/v32 contract fixtures so the
normalized documents differ only in `version` and `strategy`; the recursive
characterization formulas appear in the semantic section above. The decoder
requires the existing scalar-v5 or pair-v5 contract grammar, not a particular
formula. The applicable-domain object still has
exactly eight members in the predecessor demand order and the same numeric
caps: 8, 256, 64, 4096, 256, 262144, and 65536. The complete root and nested
demand order is unchanged on this tree. The generalized dispatcher reaches
v33/v34 only after the current v1--v32 cascade returns
`UnsupportedVersion`; v35 is the current unsupported sentinel.

The scalar assessment is
`StrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingRecursivePiecewiseAffineApplicableDomainEstablished`;
the pair assessment is its nominal `LengthSpinePair` sibling. They use the two
matching recursive renderers and reuse the Boolean finite-union failures.

Loading, activation, builder composition, and recursive validation remain
pure. An all-pure v33/v34 batch captures and checks the scoped-v2 deadline but
opens no descriptor, runs no access check, stages no image, and launches no
worker. A live miss inherits v31/v32's complete execve-check launch and scoped
lifecycle. Non-vacuous receipts join the established preferred partition,
vacuous receipts remain neutral, counterexamples use simplification/MRU, and
any operational or forcing failure restores original order.

The terms “v33” and “v34” throughout this section are current implementation
shorthand only. They do not imply a compatibility commitment to retain these
numbers, fields, literals, or behavior. See the
[recursive piecewise-affine Length ranking report](reports/2026-08-15-recursive-piecewise-affine-length-ranking.md)
and Djex's
[recursive piecewise-affine applicable-domain report](../lib/Djex/docs/reports/2026-08-15-recursive-piecewise-affine-length-applicable-domain.md).

## Pair contracts, decoders, and reports

### Using a contract-only version 6 document with `:synth`

Then select a typed Exference-producing engine and synthesize normally. A
contract-only v6 document can replace the startup-fixed contract for one
command without changing the CLI grammar:

```text
:set synth-engine exference
:synth List Nat → Prod (List Nat) (List Nat)
:synth --length-contract /absolute/path/pair-contract-v6.json -- List Nat → Prod (List Nat) (List Nat)
```

### Pair contract grammar and validation order

Versions, not a redundant domain field, choose the grammar. Pair contract
objects have exactly `resultShape`, `spine`, `targetArgumentRoles`,
`candidateCasePolicy`, `precondition`, `postcondition`, and `providerLaws`.
After the bounded root/schema gates, contract-only v6 validates those fields in
that order. Startup v4 first validates execution admission, execution,
evaluation, input-box validation, and the closed origin-probe selection, then
validates the pair contract in the same order. Startup v5 and v6 validate the
new bounded-positive ordering literal after the origin-probe selection and
before their scalar or pair contract. JSON object member order is immaterial.
The pair grammar retains v5's modulo, positive-literal quotient, formulas, and
provider laws, but admits only `["input", n]`, `["result", "first"]`, and
`["result", "second"]` as contract variables. Its target-role vector is
required, and its case policy is exactly `"cases-rejected"` or
`"exact-spine-zero-step-v1"`.

### Decoder routing and reports

In the current tree, the narrower scalar decoders remain exact entrances: the
startup decoder for versions 1--3 rejects v4--v34, and the contract-only decoder for
versions 1--5 rejects v6. The generalized decoders delegate those old versions
to their current scalar paths and add startup v4--v34 or contract-only v6. This
routing is regression-characterized but is not a backward-compatibility
promise. A
product file selects which nominal runner Main calls; it does not infer a
contract from the Lean type, bypass the exact canonical-`Prod` handoff, turn
solver status into evidence, or grant pruning authority. See the
[canonical `Prod` Length handoff report](reports/2026-08-14-canonical-prod-length-handoff.md)
for the exact handoff boundary and the
[live binary-product Length ranking report](reports/2026-08-14-live-binary-product-length-ranking.md)
for the live orchestration, authority, and compatibility details. The closed
v4/v6 file boundary is recorded in the
[binary-product Length configuration report](reports/2026-08-14-binary-product-length-configuration.md).
The explicit v5/v6 preference and its unchanged evidence and identity
boundaries are recorded in the
[non-vacuous bounded-positive ordering report](reports/2026-08-14-non-vacuous-bounded-positive-ordering.md).
The exact v7/v8 schema, positive-affine receipts, deferred state machine, and
compatibility boundary are recorded in the
[positive-affine deferred Length ranking report](reports/2026-08-14-positive-affine-deferred-length-ranking.md).
The additive v9/v10 shared usable-work owner and unchanged behavioral authority
are recorded in the
[shared usable-work Length ranking report](reports/2026-08-15-shared-usable-work-length-ranking.md).
The v11/v12 relational rule, exact v7/v8-shaped schema, nominal evidence, and
deliberate absence of the shared budget are recorded in the
[relational positive-affine Length ranking report](reports/2026-08-15-relational-positive-affine-length-ranking.md).
The v13/v14 scoped owner, cooperative checkpoints, closed schema, failure
boundary, and additive identities are recorded in the
[scoped usable-work Length ranking report](reports/2026-08-15-scoped-usable-work-length-ranking.md).
The v15/v16 strict-natural rule, inherited scoped lifecycle, nominal evidence,
closed schema, and unchanged older routes are recorded in the
[strict relational positive-affine Length ranking report](reports/2026-08-15-strict-relational-positive-affine-length-ranking.md).
The v17/v18 sealed main-image selection, closed execution discriminator,
startup notice, compatibility boundary, and unchanged evidence are recorded in
the
[descriptor-bound Length/Z3 launch report](reports/2026-08-15-descriptor-bound-length-z3-launch.md).
The v19/v20 root-quotient laws, inherited descriptor/scoped profile, nominal
assessments and notes, and unchanged older routes are recorded in the
[strict relational positive-affine quotient Length ranking report](reports/2026-08-15-strict-relational-positive-affine-quotient-length-ranking.md).
The v21/v22 effective-ID source-access selection, exact closed schema,
deferred/scoped lifecycle, failure mapping, startup notice, and unchanged
behavioral authority are recorded in the
[effective-ID descriptor-bound Length/Z3 launch report](reports/2026-08-15-effective-id-descriptor-bound-length-z3-launch.md).
The v23/v24 root-extrema laws, inherited effective-ID/scoped lifecycle,
all-or-nothing extraction, nominal receipts, and unchanged identity boundary
are recorded in the
[root-extrema Length ranking report](reports/2026-08-15-root-extrema-length-ranking.md).
The v25/v26 root-monus laws, zero-boundary admission, inherited lifecycle,
nominal receipts, presentation, and unchanged older identities are recorded in
the
[root-monus Length ranking report](reports/2026-08-15-root-monus-length-ranking.md).
The v27/v28 descriptor-bound kernel executable checks, inherited root-monus/
scoped profile, closed schema, failure mapping, and unchanged behavioral
authority are recorded in the
[execve-check descriptor-bound Length/Z3 launch report](reports/2026-08-15-execve-check-descriptor-bound-length-z3-launch.md).
The v29/v30 bounded Boolean DNF, canonical box union, admission and atomic
failure routes, nominal assessments, and no-hull authority are recorded in the
[Boolean finite-union Length ranking report](reports/2026-08-15-boolean-finite-union-length-ranking.md).
The v31/v32 atomic alternative laws, complete raw-product cap, reused limits
and errors, nominal receipts, inherited lifecycle, and identity-only extension
are recorded in the
[atomic-branching Length ranking report](reports/2026-08-15-atomic-branching-length-ranking.md).
The v33/v34 recursive grammar, selector order, signed-affine transfer,
raw-product caps, current schemas, nominal receipts, and inherited lifecycle
are recorded in the
[recursive piecewise-affine Length ranking report](reports/2026-08-15-recursive-piecewise-affine-length-ranking.md).
Djex's underlying strict extraction boundary is in its
[strict relational positive-affine applicable-domain report](../lib/Djex/docs/reports/2026-08-15-strict-relational-positive-affine-length-applicable-domain.md).
The quotient-consequence extraction, receipt, authority, and identity boundary
is in Djex's
[strict relational positive-affine quotient applicable-domain report](../lib/Djex/docs/reports/2026-08-15-strict-relational-positive-affine-quotient-length-applicable-domain.md).
The root-extrema extraction, all-or-nothing clause boundary, canonical order,
receipt authority, and identity boundary are in Djex's
[root-extrema applicable-domain report](../lib/Djex/docs/reports/2026-08-15-root-extrema-length-applicable-domain.md).
The root-monus extraction, zero-boundary countermodels, proof-summary order,
replay precedence, receipt authority, and identity boundary are in Djex's
[root-monus applicable-domain report](../lib/Djex/docs/reports/2026-08-15-root-monus-length-applicable-domain.md).
Djex's signed DNF, branch and box antichains, bounded closure, exact union
replay, and receipt authority are recorded in the
[Boolean finite-union applicable-domain report](../lib/Djex/docs/reports/2026-08-15-boolean-finite-union-length-applicable-domain.md).
Djex's exact root-extrema and may-zero-monus alternatives, raw-product
admission, ordered original-literal expansion, no-hull replay, and fresh
receipt tags are recorded in the
[atomic-branching applicable-domain report](../lib/Djex/docs/reports/2026-08-15-atomic-branching-length-applicable-domain.md).
Djex's recursive grammar, selector guards, signed-affine transfer, raw-case
accounting, exact union replay, and fresh receipt tags are recorded in the
[recursive piecewise-affine applicable-domain report](../lib/Djex/docs/reports/2026-08-15-recursive-piecewise-affine-length-applicable-domain.md).
Djex's underlying two-point source-access and sealed-image execution authority
is recorded in the
[effective-ID descriptor-bound Z3 launch report](../lib/Djex/docs/reports/2026-08-15-effective-id-descriptor-bound-z3-launch.md).
Djex's lower-level source/staged exec-check lifecycle, identities, and narrow
kernel authority are recorded in the
[execve-check descriptor-bound Z3 launch report](../lib/Djex/docs/reports/2026-08-15-execve-check-descriptor-bound-z3-launch.md).

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
Main's v7--v10 path can produce only the literal-ceiling positive-affine receipt
family; v11--v14 can produce only the relational family; v15--v18 can produce
only the strict-relational family; v19--v22 can produce only the root-quotient
successor family; v23/v24 can produce only the root-extrema successor family;
v25--v28 can produce only the root-monus successor family; v29/v30 can produce
only the Boolean finite-union successor family; v31/v32 can produce only the
atomic-branching finite-union successor family; v33/v34 can produce only the
recursive piecewise-affine successor family; v1--v6 cannot produce
any applicable-domain family. The semantic note
never projects the receipt's private provider-name list. Disabled assessment,
rejected input, heuristic status,
and atomic operational fallback add no semantic note. The note can explain a
stable demotion; it never proves, prunes, or claims concrete Lean behavior.
