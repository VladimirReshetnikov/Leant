# Length behavioral ranking and replay-authorized filtering

*An optional, opt-in last stage of `:synth` that consults Z3 about the
behavior of already-verified candidates. Its default operation stably ranks
the complete verified batch; an explicit command mode may instead omit only
independently replayed counterexamples. This document is the complete
reference; the [README](../README.md) gives the one-paragraph overview and the
[manual](Leant.pdf) the user-level tour.*

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

Five rules define the current authority boundary:

- **Ranking remains the default and never prunes.** Ordinary `:synth TYPE`,
  explicit `--behavior-mode rank`, and `--length-contract` without an explicit
  behavior mode all use stable ranking. A replayed counterexample moves after
  the retained candidates but is still shown and bound.
- **Filtering requires explicit command authority.** Only
  `--behavior-mode filter` selects hard filtering, and only an independently
  replayed counterexample may enter its rejected partition. Rejections remain
  separately visible but are not bound as `itN`.
- **Filtering can refill only inside the current bounded lane.** Ranking keeps
  its historical five-success verifier frontier. Filtering instead assesses
  the verified output of one already bounded 12-, 24-, or excluded-middle
  6-group lane as one batch, then shows and binds at most five survivors while
  reporting every rejection from that batch.
- **Raw solver status has no authority.** `sat`, `unsat`, and `unknown` are
  heuristics. Preparation refusal, unassessed input, heuristic status,
  independently completed finite-box evidence, and established applicable-
  domain evidence all retain a candidate in filter mode.
- **It is off unless you activate a policy.** Without
  `--length-ranking-config`, ordinary ranking is the lazy identity. A filter
  request is rejected before contract-path admission or file IO, and no worker
  is launched.

The ranking stage was the first behavioral increment. The current tree also
implements the command-authorized Level-1 hard-filter slice described by the
[Z3 behavioral synthesis proposal](Z3_Behavioral_Synthesis_Proposal/Z3_Behavioral_Synthesis_Proposal.pdf)
(August 2026): a bounded total occurrence partition whose only negative
Length decision is an exact replayed counterexample. The current lane-local
refill lets that filter consume the remainder of one already bounded synthesis
lane after early behavioral rejections, but it is not the proposal's Level-2
command-local CEGIS loop: it neither requests candidates from another lane nor
persists a bank across batches. Persistent sample banks, cross-lane candidate
enumeration, typed sketch completion, sound prefix pruning, further behavioral
domains, and Lean-checked proof artifacts remain proposed work.

The vendored Djex revision now contains candidate-independent scalar and
binary-product counterexample-bank scopes, bounded immutable input stores, and
exact query-owned operations for fresh receipt recording and retained-sample
replay. Leant wraps that bridge in one package-private, nominally separated
scalar/product state module. Each pure state retains validated limits and at
most one active scope, initializes lazily, resets on exact scope drift, threads
charged successors through ordered replay refusals, and keeps hit promotion an
explicit evaluation-free operation. This is still a dormant runtime
foundation: no Ranking, Selection, Integration, Main, command-state, or
persistence path constructs or consults the state. Unless this document
explicitly says otherwise, “replay bank” therefore means Leant's existing
fresh four-vector, one-assessment MRU below, not the package-private nominal
state.

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
- [Command-level ranking and hard filtering](#command-level-ranking-and-hard-filtering)
  - [Exact grammar, defaults, and authority](#exact-grammar-defaults-and-authority)
  - [Retention and rejection taxonomy](#retention-and-rejection-taxonomy)
  - [Bounded lane-local survivor refill](#bounded-lane-local-survivor-refill)
  - [Stable partition, failure, and Main behavior](#stable-partition-failure-and-main-behavior)
- [One-shot contract-only files](#one-shot-contract-only-files)
  - [Command syntax, admission, and lifetime](#command-syntax-admission-and-lifetime)
  - [Scalar contract example](#scalar-contract-example)
  - [Binary-product contract example](#binary-product-contract-example)
  - [Current nested grammar and authority](#current-nested-grammar-and-authority)
- [Binary-product Length queries](#binary-product-length-queries)
  - [Canonical `Prod` eligibility and the serializer boundary](#canonical-prod-eligibility-and-the-serializer-boundary)
  - [Library-level pair query handoff](#library-level-pair-query-handoff)
  - [Live pair ranking and non-vacuous bounded-positive preference](#live-pair-ranking-and-non-vacuous-bounded-positive-preference)
  - [Current guarded recursive applicable-domain validation](#current-guarded-recursive-applicable-domain-validation)
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
- current guarded recursive piecewise-affine applicable-domain validation;
- non-vacuous preference for both applicable-domain and input-box receipts;
- componentwise-lexicographic counterexample simplification;
- deferred session opening; and
- one owner-thread-affine, cooperatively checkpointed scoped usable-work
  deadline.

The three bounded traversal authorities remain independent: input-box,
applicable-domain, and simplification limits cannot substitute for one another.
The guarded recursive applicable-domain algorithm first uses its complete
private atomic predecessor and recursively expands only otherwise ignored
relational leaves whose supported signed-affine summaries contain minimum,
maximum, monus, or a guarded conditional. A conditional is all-or-nothing:
both polarities of its condition and both selected arms must be wholly
supported. Quotient, modulo, result-reference, zero-scale, and other
unsupported descendants reject the complete recursive fallback atom; an
unsupported descendant in either conditional arm rejects the whole atom even
when the other arm alone would establish a finite box.

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
candidate's pure MRU, guarded applicable-domain, and origin prefix before IO.
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

The inherited native descriptor launcher keeps every resource-producing
acquisition masked through publication to one terminal completion cell. Its
three descriptor strategies then share one rollback-protected transfer from
the raw child-and-stdio bundle to the opaque process owner: an asynchronous
exception before the consumer accepts ownership cleans the raw child and
stdio, while initialization becomes interruptible only after the process value
owns that cleanup. The child exec-status handle is independently closed in a
masked finalizer on EOF, child-reported exec failure, synchronous read failure,
deadline cancellation, or asynchronous interruption. These are lifecycle and
leak-prevention guarantees, not executable, solver, or behavioral evidence.

### Candidate eligibility

Only callback-verified candidates with direct or exact-duplicate-recovered
typed Exference authority are eligible. Candidates with neither authority
remain in place with a payload-free preparation refusal and do not open a
worker by themselves. The default `djinn` synthesis engine supplies no typed
graph; select `:set synth-engine exference` or `both` to produce candidates
which may reach this ranking path.

## Command-level ranking and hard filtering

### Exact grammar, defaults, and authority

The option-bearing command grammar is exactly:

```text
:synth [--behavior-mode rank|filter] [--length-contract ABSOLUTE-PATH] -- TYPE
```

The behavior mode, when present, must precede the contract option. The
standalone `--` is mandatory for every option-bearing form and leaves the
remaining text as opaque Lean goal syntax. The ordinary no-option form stays
delimiter-free:

```text
:synth TYPE
```

The current choices have these meanings:

| Command form | Operation | Contract |
| --- | --- | --- |
| `:synth TYPE` | rank | activated startup contract, or lazy identity when assessment is disabled |
| `:synth --behavior-mode rank -- TYPE` | rank | activated startup contract, or lazy identity when assessment is disabled |
| `:synth --behavior-mode filter -- TYPE` | filter | activated startup contract; rejected before IO when assessment is disabled |
| `:synth --length-contract PATH -- TYPE` | rank | command-local contract; requires an activated startup policy |
| `:synth --behavior-mode rank --length-contract PATH -- TYPE` | rank | command-local contract; requires an activated startup policy |
| `:synth --behavior-mode filter --length-contract PATH -- TYPE` | filter | command-local contract; requires an activated startup policy |

Only the exact option tokens are special. Longer lookalikes such as
`--behavior-model` and `--length-contractual` remain ordinary goal text.
After exact `--behavior-mode`, an absent value, a value other than `rank` or
`filter`, or a missing delimiter is rejected as command syntax. An empty
contract path is rejected before a misplaced mode token; otherwise an exact
`--behavior-mode` appearing in the contract span is rejected because the mode
must come first. A contract path may contain spaces, but a standalone `--`
inside it terminates the path.

The command selects behavior, not execution policy. `filter` does not activate
Z3 and a contract-only file cannot supply execution authority. Main first asks
the already activated startup mode for permission. A disabled filter request,
and any disabled request with a contract path, fails before path admission or
file IO. With permission, the selected startup or command-local contract and
the one activated policy travel only on that command's stack through ordinary,
universe-retry, provider, and classical synthesis lanes.

### Retention and rejection taxonomy

The scalar `Leant.Synth.Length.Selection` adapter and nominally separate
`Leant.Synth.Length.SpinePair.Selection` adapter consume the existing complete
ranking assessment. They map each report back to the matching callback
occurrence by its private original index, then apply this closed rule:

| Ranking report | Filter decision |
| --- | --- |
| candidate-local preparation refusal | retain with the exact refusal class |
| `Unassessed` | retain |
| `Heuristic status` | retain, including raw `sat`, `unsat`, and `unknown` |
| `BoundedPositive receipt` | retain with the independently completed finite-box receipt |
| `ApplicableDomainEstablished receipt` | retain with the independently established applicable-domain receipt |
| `Counterexample receipt` | reject with that independently replayed counterexample and its optional simplification metadata |

Preparation refusal is checked before the assessment. No solver status,
derived formula, inferred box, ordering preference, or generic partition
wrapper can reject. The negative payload is nominally scalar or pair-specific
and always carries the ordinary final replayed counterexample; simplification
is optional metadata owned by that same occurrence. The selection adapter does
not introduce another query runner, executable policy, counterexample
validator, or evidence format.

The four-entry newest-first input-vector bank remains local to one assessment
batch. A replayed violation from an earlier candidate can seed a later
candidate only after the later candidate independently evaluates and associates
that vector with its own checked problem. A new batch starts empty. No bank,
behavior mode, or selection result is retained in `ReplState`, history,
snapshots, or another command.

### Bounded lane-local survivor refill

Main's private `verifySynthLane` seam receives an exact group limit from its
current synthesis caller and takes that prefix before it inspects the
assessment request. An empty prefix therefore produces an unassessed lane
without projecting the behavior mode or forcing a retained lazy contract.
Ordinary, universe-retry, provider, and double-negation lanes use the engine's
established limit: 12 groups for a standalone Djinn or Exference lane and 24
for a combined lane. The cheaper excluded-middle classical route uses half of
`synthMaxTried`, currently 6.

Ranking retains the historical quota of five callback-accepted groups. Filter
mode instead gives verification the complete caller-owned lane limit. Because
the verification quota counts accepted groups rather than attempted groups,
the prior `take` is a separate productivity boundary: failed groups do not
allow traversal beyond the finite 12-, 24-, or 6-group lane prefix. The
complete verified filter frontier is then assessed once, so its four-entry MRU
bank can replay a counterexample learned from an early rejected occurrence
against a later occurrence in that same batch.

The lane result retains two deliberately noninterchangeable histories. Its
checked spelling frontier is every rendered variant in the complete bounded
group prefix, including variants that lazy verification never needed to call;
that remains the exact provider-deduplication and scheduling authority. Its
callback-attempt trace instead records each detailed variant immediately before
the Lean backend call. It excludes the later siblings of an accepted group and
every group beyond the successful-group quota. The exact trace is retained for
later accounting, but current provider scheduling never substitutes it for the
full spelling frontier.

Only after assessment does Main take at most five survivor presentations for
display and `itN` binding. It does not cap the rejection projection: every
rejected occurrence in the bounded assessed batch is reported. A preserve-all
selection failure likewise retains the entire enlarged verified batch
internally but shows at most five unannotated original candidates beside its
warning. Thus an early run of five behavioral rejections can be refilled by
later same-lane survivors without expanding interactive output.

After verification and its one assessment, the pure private classifier returns
one of four dispositions: no verified receipt, survivors, all behaviorally
rejected, or assessment failure with every verified candidate preserved. An
empty verified-receipt batch is the first and sole assessed-lane route to the
no-verification disposition. Verification and assessment emit no candidate
rows and mutate no synthesis-splice state; one finalizer owns observations,
the preserve-all warning, reverse binding, cache replacement or clearing,
survivor rows, every bounded rejection row, and handled-lane notes.

This scheduling remains intentionally local and behavior-preserving. Only the
no-verification disposition permits provider or classical continuation. An
accepted all-rejected batch is the distinct terminal all-behaviorally-rejected
disposition, so structural filtering still does not enter provider lanes and
an all-rejected excluded-middle batch still does not enter the double-negation
lane. No candidate from a later lane enters the assessment. The new outcome
types are private to Main; they add no public API, `Engine`, `Verification`, or
`ReplState` change, persistent runtime bank, provider continuation, or
cross-lane CEGIS scheduling.

### Stable partition, failure, and Main behavior

`Leant.Synth.BehavioralSelection` mints a fresh rank-2 occurrence epoch for
the exact `VerificationBatch`. Package-internal selection adapters may attach
one retention or rejection payload to a supplied handle but cannot construct
or reindex a handle. The bounded seal requires exactly one decision for every
admitted occurrence, rejects length, range, duplicate, and limit errors, and
reconstructs both partitions from the original verified receipts. Survivors
and rejections therefore each appear in original callback order, independent
of ranking order or decision order. Equal candidate texts remain distinct
occurrences. Filter mode is a stable subsequence selection; it does not rank
the survivors after filtering.

Post-verification failure, ranking failure or absence, an impossible
original-index mismatch, candidate/decision admission failure, or partition-
seal failure atomically preserves the complete original verified batch in
original order. Such a result exposes no accepted selection wrappers and no
rejections. Main displays a mode-neutral warning that behavioral assessment
preserved all verified candidates and then presents at most five unannotated
original candidates. The complete preserved batch remains the internal
failure result. Exceptions still propagate after owned cleanup rather than
becoming a filter result.

On accepted selection, presentation traverses the associated survivor and
rejection wrappers directly; it never zips detached candidates and evidence.
Survivors with independently completed input-box or applicable-domain receipts
retain the existing bounded positive notes. Each omitted occurrence is printed
separately as `rejected` with the exact existing bounded counterexample or
counterexample-simplification note. Only survivors are bound as `it1`, `it2`,
and so on. If every verified candidate is rejected, the command is still a
handled synthesis result: it prints the rejection rows, creates no new `itN`
bindings, clears the previous synthesis-splice cache, and does not emit the
unrelated “none survived Lean verification” diagnostic or continue into a
later provider or classical lane.

The structural and command-authority predecessor is recorded in the historical
[command-authorized Length filtering report](reports/2026-08-15-command-authorized-length-filtering.md).
The current refill checkpoint and its exact test surface are recorded in the
[lane-local Length survivor-refill report](reports/2026-08-15-lane-local-length-survivor-refill.md).
Its behavior-preserving outcome-seam successor is recorded in the
[explicit synthesis-lane outcome report](reports/2026-08-16-explicit-synthesis-lane-outcomes.md).

## One-shot contract-only files

### Command syntax, admission, and lifetime

After startup activation, one command may replace only the fixed startup
contract selection with an explicitly named contract-only document. Omitting
the behavior option keeps the default ranking operation; an explicit filter
selects replay-authorized rejection:

```text
:synth --length-contract ABSOLUTE-PATH -- TYPE
:synth --behavior-mode filter --length-contract ABSOLUTE-PATH -- TYPE
```

The standalone `--` is mandatory and keeps the remaining text opaque Lean goal
syntax. When both options are present, `--behavior-mode` must come first. The
path may contain spaces, but a standalone `--` inside it is reserved as the
delimiter. Leant first requires an activated startup policy; when assessment
is disabled it rejects either contract form before path admission or file IO.
Otherwise it admits and reads that absolute POSIX path once, before goal
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
provider law. The passive contract choice is command-local, leaves no role or
case-policy state behind, and grants no rejection authority by itself.

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

The command-local selection contains no execution, ranking, filtering, replay,
simplification, ordering, or budget policy. Its file is read once before goal
translation and the same mode-plus-contract request is carried through
ordinary, retry, provider, and classical lanes. It never enters `ReplState`,
history, snapshots, or a cache; a later command returns to the startup-fixed
contract unless it names another file, and behavior mode is parsed afresh for
every command.

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

### Current guarded recursive applicable-domain validation

Leant exposes one applicable-domain policy for current code. Programmatic
callers enable it with
`enableLengthRankingApplicableDomainValidation inputBoxLimits unionLimits`;
`inputBoxLimits` bounds compact-input width and unique assignments, while the
retained `LengthBooleanFiniteUnionLimits` value bounds generated branches,
rules, closure inspections, retained boxes, and raw assignment visits. The
latter name survives as the current resource-cap bundle; it does not select
an older strategy.

The applicable-domain preference remains an independent ranking choice:
`enableLengthRankingNonVacuousApplicableDomainPreference` moves only a
completed receipt whose applicable-assignment count is positive. It neither
enables validation nor changes the evidence acquired. A vacuous receipt stays
neutral. The scalar and nominal binary-product assessors use the same reusable
policy but cannot exchange contracts, queries, failures, receipts, or
assessments.

A complete programmatic composition can be written as:

```haskell
let currentPolicy =
      enableLengthRankingDeferredLiveSessionOpening
        $ enableLengthRankingCounterexampleSimplification
            simplificationLimits
        $ enableLengthRankingNonVacuousApplicableDomainPreference
        $ enableLengthRankingApplicableDomainValidation
            applicableInputBoxLimits applicableUnionLimits
        $ enableLengthRankingNonVacuousInputBoxPreference
        $ enableLengthRankingOriginProbe
        $ enableLengthRankingInputBoxValidation
            postUnsatLimits [5]
        $ enableLengthRankingScopedUsableWorkBudget
            usableWorkBudget basePolicy

scalarAssessment <- assessVerifiedLengthCandidatesWithPolicy
  currentPolicy scalarContract verificationBatch

pairAssessment <- assessVerifiedLengthSpinePairCandidatesWithPolicy
  currentPolicy pairContract verificationBatch
```

These persistent builders control orthogonal dimensions except that the last
usable-work builder determines its single budget strategy. The current
versionless startup decoder constructs this complete bundle directly: the
current guarded applicable domain, input-box traversal, origin probe, both
non-vacuous preferences, counterexample simplification, deferred opening, and
the scoped usable-work owner. A contract-only document replaces only the
request contract and never selects ranking, execution, replay, or opening
policy.

The former direct, positive-affine, relational, strict, quotient, extrema,
monus, Boolean-union, atomic-branching, and long recursive Leant builders were
deleted. Their assessment constructors, failure families, renderers, and
stage-specific Djex receipts are also absent from the current surface. There
are no aliases or migration adapters: Leant is experimental, promises no
stability or backward compatibility, and has no userbase requiring the old
choice matrix. Historical dated reports preserve the development sequence but
do not describe current imports.

#### Short assessment and presentation surface

Leant delegates scalar traversal to
`validateLengthSMTLibQueryApplicableDomain` and product traversal to
`validateLengthSpinePairSMTLibQueryApplicableDomain`. Their closed Djex query
errors are `LengthSMTLibApplicableDomainValidationError` and
`LengthSpinePairSMTLibApplicableDomainValidationError`; callers which already
own a checked problem can instead use `validateLengthProblemApplicableDomain`
or `validateLengthSpinePairProblemApplicableDomain`. An ordinary
inapplicable result or a bounded admission refusal is a pure miss. A replayed
counterexample enters the existing counterexample and optional simplification
path. Complete traversal produces `ApplicableDomainEstablished` for scalar
ranking or `LengthSpinePairApplicableDomainEstablished` for product ranking.

The corresponding operational failures are
`LengthRankingApplicableDomainValidationFailed` and
`LengthSpinePairRankingApplicableDomainValidationFailed`. Width, generated
branch, rule, closure, retained-box, maximum-value, visit, and unique-
assignment admission failures remain ordinary misses and continue to the
origin/live path. An admitted assignment-evaluation failure, internal
enumeration invariant, or exact evidence/query association mismatch is an
indexed atomic batch failure.

Successful scalar evidence carries the opaque Djex
`ValidatedLengthApplicableDomain`; product evidence carries
`ValidatedLengthSpinePairApplicableDomain`. The current projections are:

| Scalar | Product |
| --- | --- |
| `validatedLengthApplicableDomainInclusiveMaximumBoxes` | `validatedLengthSpinePairApplicableDomainInclusiveMaximumBoxes` |
| `validatedLengthApplicableDomainBoxCount` | `validatedLengthSpinePairApplicableDomainBoxCount` |
| `validatedLengthApplicableDomainAssignmentVisitCount` | `validatedLengthSpinePairApplicableDomainAssignmentVisitCount` |
| `validatedLengthApplicableDomainAssignmentCount` | `validatedLengthSpinePairApplicableDomainAssignmentCount` |
| `validatedLengthApplicableDomainApplicableAssignmentCount` | `validatedLengthSpinePairApplicableDomainApplicableAssignmentCount` |
| `validatedLengthApplicableDomainBasis` | `validatedLengthSpinePairApplicableDomainBasis` |

Main uses only `renderLengthApplicableDomainValidationNote` or
`renderLengthSpinePairApplicableDomainValidationNote`. Each bounded
384-character note reports the model/provider-relative basis, box count, raw
visits, unique and applicable assignments, explicit vacuity, and a bounded
prefix of the canonical maxima antichain. It does not project provider names
or claim solver proof, source behavior, a global theorem, or pruning
authority.

#### Private Djex fallback and exact domain semantics

The removed public strategy matrix survives only as Djex implementation
structure. Every normalized leaf follows one private ordered fallback:

```text
direct literal -> positive affine -> relational -> strict relational
  -> positive-literal quotient -> root extrema -> root monus
  -> Boolean finite union / atomic branching
  -> guarded recursive piecewise-affine fallback
```

The direct stage recognizes normalized `input <= literal` coverage. The
positive-affine stage summarizes compact inputs, literals, sums, and positive
scales. For `c + sum(ai*xi) <= k`, every positive coefficient derives
`xi <= (k-c) quot ai`; equality to a literal supplies the same necessary
upper bounds. A recognized constant contradiction dominates missing coverage.
Unsupported leaves contribute no bound and remain in the original formula
which is replayed later.

The relational stage summarizes the same positive-affine grammar on both
sides, cancels common constants and coefficients, and emits directed rules;
equality emits both source-ordered directions. The strict stage adds only the
exact Natural complement of an immediate normalized comparison:

```text
not (L <= R)  <=>  R + 1 <= L
```

It applies the successor before coefficient cancellation. Negated equality,
nested negation, and unsupported children do not manufacture partial rules.

For positive literal `d` and positive-affine `A` and `B`, the root-quotient
stage admits exactly one quotient at one relation-operand root and uses:

```text
quotient d A <= B        => A <= d*B + (d - 1)
A <= quotient d B        => d*A <= B
not (quotient d A <= B)  => d*(B + 1) <= A
not (A <= quotient d B)  => B + 1 <= d*A
```

Equality contributes the two non-strict directions. Nested, embedded, or
two-root quotient shapes are left to no later recursive quotient rule.

For positive-affine `A`, `B`, and `C`, the root-extrema stage adds these exact
necessary pairs:

```text
max(A,B) <= C        => A <= C       and B <= C
C <= min(A,B)        => C <= A       and C <= B
not (min(A,B) <= C)  => C + 1 <= A   and C + 1 <= B
not (C <= max(A,B))  => A + 1 <= C   and B + 1 <= C
```

Maximum equality emits the first pair; minimum equality emits the second.
There is no converse. Exactly one relation side may contain the immediate
extremum root, and both rules are retained or the leaf is ignored.

For `M = A monus B` and an opposite positive-affine summary
`C = c + sum(ki*xi)`, the root-monus stage uses:

```text
M <= C        => A <= B + C
C <= M        => B + C <= A                    when c > 0
not (M <= C)  => B + C + 1 <= A
not (C <= M)  => 1 <= C and A + 1 <= B + C
M = C or C=M  => A <= B + C; also B + C <= A  when c > 0
```

An identically zero `C <= M` is tautological; a may-zero `C <= M` is ignored
rather than replacing its exact disjunction by one branch. Equality always
retains its first necessary consequence. Positivity comes only from that
leaf's affine constant and is never borrowed from closure state.

The Boolean layer owns outer polarity: positive conjunction is a Cartesian
conjunction, negative conjunction is a union, `not` flips polarity, and
negative equality splits into the two strict alternatives. It does not add a
general arithmetic-disjunction expression form. The guarded recursive
fallback does reuse this exact Boolean expansion for an expression
conditional's condition and complement.
Before recursive descent, the atomic stage adds these exact immediate-root
alternatives in written order:

```text
C <= max(A,B)       -> [C <= A] | [C <= B]
min(A,B) <= C       -> [A <= C] | [B <= C]
not (max(A,B) <= C) -> [C + 1 <= A] | [C + 1 <= B]
not (C <= min(A,B)) -> [A + 1 <= C] | [B + 1 <= C]
max(A,B) = C        -> [A <= C, B <= C, C <= A]
                       | [A <= C, B <= C, C <= B]
min(A,B) = C        -> [C <= A, C <= B, A <= C]
                       | [C <= A, C <= B, B <= C]
C <= (A monus B)    -> [C <= 0] | [B + C <= A]
(A monus B) = C     -> [A <= B + C, C <= 0]
                       | [A <= B + C, B + C <= A]
```

The monus equality rule applies in either source orientation. Each required
operand must summarize independently as positive affine; nested, embedded,
both-root, mixed, conditional, or otherwise unsupported shapes remain one
ignored atomic alternative for the guarded recursive fallback.

An earlier exact result is retained. Recursive interpretation runs only when
the complete atomic scanner returns its singleton ignored alternative and the
relation still contains minimum, maximum, natural monus, or a conditional.
This atomic-first boundary preserves exact lower-level handling without making
it selectable Leant policy.

The recursive expression grammar admits compact inputs, natural literals,
normalized sums, retained positive scales, binary minimum, binary maximum,
binary monus, and `if F then E else E`. A conditional is admitted only when
every leaf in both the positive and negative Boolean expansion of `F` and
every descendant in both arms is supported. It does not recursively descend
through quotient, modulo, a result reference, an out-of-range input, a
retained zero scale, or another unsupported child; an earlier private stage
can still have handled the complete leaf exactly. Unsupported descendants
leave the complete fallback atom ignored rather than approximated or accepting
only the apparently reachable arm.

For selected child values `L` and `R`, the exact cases are:

```text
min(L,R)  -> [L <= R;     value L]
           | [R + 1 <= L; value R]
max(L,R)  -> [R <= L;     value L]
           | [L + 1 <= R; value R]
L monus R -> [L <= R;     value 0]
           | [R + 1 <= L; value L - R]
if F then T else E
           -> [positive F guards; value T]
            | [negative F guards; value E]
```

The first extrema/monus choice owns equality. A conditional emits its true arm
before its false arm. Within one arm, condition-DNF alternatives are outermost
and selected-expression alternatives are innermost; condition guards precede
selected-arm guards. More generally, left-child cases precede right-child
cases, descendant guards precede the current selector, and the enclosing
relation appends its at-most, immediate strict complement, or two equality
rules last. Signed coefficients created by a positive monus branch transfer
exactly across the inequality into the established natural positive-sided rule
representation. No checked formula is manufactured, and no selector,
conditional guard, or relation rule is deduplicated.

Raw generated-branch admission counts the complete formula DNF by recursive-
alternative Cartesian product before formula cleanup, conditional-guard or
selector contradiction, rule collection, closure, or box cleanup. An
impossible conditional guard therefore still keeps its selected value in the
raw Cartesian product and is collapsed only when the enclosing relation forms
branch coverage. Original literal sets are then
canonicalized: duplicate literals disappear, an exact literal/complement
branch drops, equal sets deduplicate, and strict supersets are absorbed.
Survivors are re-expanded in set and recursive-alternative order. Branch and
closure indices address that expanded stream. Surviving branches use the
immutable-snapshot, rule-once closure: constant-right rules seed maxima in
rule order; each pass reads one bounds snapshot; eligible pending rules fire
once in order; newly derived maxima merge with componentwise `min` only after
the pass; and a pass with no firing terminates. Every live branch must
establish a maximum for every compact input.

The observable bounded-work order is compact-input width, lazy raw branch
count, generated-branch cap, original-literal canonicalization and
re-expansion, per-branch rule cap, per-branch closure-inspection cap,
contradictory-branch removal, first missing input in any live branch, maximal
box-antichain construction, retained-box cap, maximum-value checks in box and
input order, raw assignment visits, unique-assignment materialization, global
original-problem replay, first indexed evaluation rejection or
counterexample, receipt construction, and finally exact query association.
Every capped counter stops after observing at most its limit plus one; later
cleanup cannot bypass earlier bounded work.

Completely bounded branches become a lexicographically ordered, componentwise-
maximal box antichain. Incomparable boxes are never replaced by a hull. Visits
count overlapping boxes repeatedly; a bounded global set deduplicates
assignments; and the original checked precondition and postcondition are
replayed once in global lexicographic order. Derived guards, rules, boxes, and
solver status never replace that replay.

The one-input characterization
`(if x <= 2 then x else 5) <= 3` retains `[[2]]` with one box, three
visits, three unique assignments, and three applicable assignments; its two
raw guard alternatives make a generated-branch cap of one report that two
were observed. Replacing the guard with `x = 0` and the arms with `1` and `x`
retains the same receipt but preserves all three negative-equality
alternatives, so a cap of two observes three.

The nested characterization
`y <= 2` and `(if x <= 1 then max(x,y) else x monus y) <= 2` retains
`[[4,2]]`: one box, 15 visits, 15 unique assignments, and 12 applicable
assignments. Its four raw alternatives pin branch admission before its
four-rule and closure boundaries; an independent replay oracle over the wider
`[0..5] x [0..3]` rectangle confirms that every one of the 12 satisfying
assignments is covered by a retained box. Replacing only the false arm with
`x modulo 2` makes the complete atom inapplicable. Scalar and nominal product
query association retain the same guarded receipt without changing query
fingerprints or bytes.

#### Lifecycle and ordering

For every eligible candidate, Leant keeps this source order:

```text
four-entry newest-first MRU replay
  -> current applicable-domain traversal
  -> all-zero origin probe
  -> live query and query-first replay
  -> post-unsat explicit input-box traversal
```

An applicable-domain counterexample or establishment skips the later stages
for that candidate. An inapplicable result or admission miss proceeds to the
origin/live stages. Every counterexample source crosses the same optional
componentwise-lexicographic simplification seam, and only the final vector
enters the domain-local MRU bank.

Under deferred opening the MRU/domain/origin prefix runs before process IO. An
all-pure batch opens no worker. The first live miss opens exactly one lexical
session, executes that candidate once without repeating its pure prefix, and
processes the suffix in the same scope. A failure discards partial assessments
and restores the admitted batch in original order.

With both current preferences enabled, stable order is non-vacuous applicable-
domain evidence, non-vacuous explicit-box evidence, neutral and vacuous
assessments, then replayed counterexamples. Original order is retained inside
each ranking partition; ranking drops no candidate or occurrence handle. The
explicit filter adapter consumes the same report but maps every occurrence
back through its original index and returns stable original-order survivor and
rejection subsequences instead of that ranking order.

The current Leant reset is recorded in the
[current applicable-domain policy report](reports/2026-08-15-current-length-applicable-domain-policy.md).
Djex owns the detailed grammar, cap precedence, receipt identity, and replay
authority described in its
[current applicable-domain surface report](../lib/Djex/docs/reports/2026-08-15-current-length-applicable-domain-surface.md).
The guarded extension and its Leant tandem characterization are recorded in
the
[guarded conditional Length ranking report](reports/2026-08-15-guarded-conditional-length-ranking.md).
The earlier
[recursive piecewise-affine Length ranking report](reports/2026-08-15-recursive-piecewise-affine-length-ranking.md)
is non-normative development history.

### Shared usable-work budget (v1)

The runtime-unscoped v1 shared usable-work policy is a further orthogonal
programmatic opt-in. Its builder accepts only an already validated opaque Djex
budget and works for both the scalar and nominal product assessors:

```haskell
usableWorkBudget <- either (fail . show) pure $
  mkLengthSMTLibLiveUsableWorkBudget
    LengthSMTLibLiveUsableWorkBudgetSource
      { lengthSMTLibLiveUsableWorkBudgetSourceMilliseconds = 30000 }

let budgetedCurrentPolicy =
      enableLengthRankingUsableWorkBudget
        usableWorkBudget currentPolicy

scalarAssessment <- assessVerifiedLengthCandidatesWithPolicy
  budgetedCurrentPolicy scalarContract verificationBatch

pairAssessment <- assessVerifiedLengthSpinePairCandidatesWithPolicy
  budgetedCurrentPolicy pairContract verificationBatch
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
let scopedCurrentPolicy =
      enableLengthRankingScopedUsableWorkBudget
        usableWorkBudget currentPolicy

scalarAssessment <- assessVerifiedLengthCandidatesWithPolicy
  scopedCurrentPolicy scalarContract verificationBatch

pairAssessment <- assessVerifiedLengthSpinePairCandidatesWithPolicy
  scopedCurrentPolicy pairContract verificationBatch
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
continues to the origin/live stages. In ranking mode, a freshly replayed and
associated pair counterexample enters the stable demoted partition and can
supply an MRU input vector. In filter mode, that same exact report is the only
assessment which enters the rejected partition.
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
refusals stay local. None of those statuses or failures grants rejection
authority; only the later explicit selection adapter may turn the final
replayed `Counterexample` assessment into a rejection.

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
- `applicableDomainValidation` fixes the current guarded recursive piecewise-affine
  algorithm; there is no `strategy` field. Its limits are, in order,
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
handoff, turn solver status into evidence, or itself grant rejection
authority. Only an explicit filter command may route an independently replayed
pair counterexample through the nominal pair-selection adapter. The
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

The current guarded recursive validator and its inherited descriptor ownership
lifecycle are recorded in the
[guarded conditional Length ranking report](reports/2026-08-15-guarded-conditional-length-ranking.md).
The earlier
[recursive piecewise-affine Length ranking report](reports/2026-08-15-recursive-piecewise-affine-length-ranking.md)
predates both this extension and the schema reset; its v33/v34 routing
discussion is historical, while its earlier semantic examples and authority
boundary remain useful.
Djex's pre-conditional recursive grammar, selector guards, signed-affine
transfer, raw-case accounting, exact union replay, and receipt authority are
recorded in the historical
[recursive piecewise-affine applicable-domain report](../lib/Djex/docs/reports/2026-08-15-recursive-piecewise-affine-length-applicable-domain.md).
The inherited source/staged executable-check lifecycle and its narrow authority
are in the
[execve-check descriptor-bound Z3 launch report](../lib/Djex/docs/reports/2026-08-15-execve-check-descriptor-bound-z3-launch.md).

All dated Leant reports are historical engineering records, not normative
startup grammar. The [report index](reports/README.md) states the precedence
explicitly.

## Presentation notes on the Main path

After a successful ranking or selection seal, Main dispatches presentation
through the selected scalar or pair domain. It projects candidate text and
evidence only from their shared opaque ranked, selected, or rejected wrapper.
A scalar counterexample note summarizes its observed input and result spine
lengths; a pair note keeps the first and second result lengths source ordered.
Both call the receipt replayed and model-relative and report only the number of
assumed provider laws used by that candidate. If simplification found a strict
reduction, the existing bounded simplification renderer instead reports the
original and final vectors and inspected lower-box count. Filter rejection
reuses these exact renderers verbatim rather than manufacturing a second
diagnostic vocabulary.

In ranking mode the counterexample note is subordinate to a still-visible,
still-bound demoted candidate. In filter mode it is subordinate to a separate
`rejected` row, and that occurrence receives no `itN` binding. Independently
completed finite-box notes instead give the bounded maxima and checked/
applicable assignment counts; applicable-domain survivor notes use
`renderLengthApplicableDomainValidationNote` or
`renderLengthSpinePairApplicableDomainValidationNote`.

Those are the only public applicable-domain renderers. They report the
canonical maxima antichain, box and assignment counts, model/provider-relative
basis, and explicit vacuity from `ApplicableDomainEstablished` or
`LengthSpinePairApplicableDomainEstablished`; they do not expose the private
fallback stage which established the receipt.

The semantic note never projects the receipt's private provider-name list.
Disabled assessment, candidate-local preparation refusal, unassessed input,
heuristic status, and atomic preserve-all fallback add no semantic note. A note
reports exact bounded model-relative evidence; it never proves or claims
unmodeled concrete Lean behavior. Rejection authority comes from the selection
adapter's replay-only taxonomy and sealed occurrence association, not from
rendered text. Historical stage-specific renderer names are not aliases and
are not part of the current library API.
