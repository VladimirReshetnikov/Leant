# Leant — a Djex-based synthesis REPL for Lean 4

Leant brings [Djex](lib/Djex)-powered program and proof synthesis to
Lean 4, wrapped in an interactive read-eval-print loop. The centerpiece
is `:synth`: give it a type and it constructs terms of that type —
ranked, bound into the session, and every candidate re-elaborated by
Lean before you see it — or proves that no such term exists. Around the
synthesizer, Leant is a full REPL in the GHCi-inspired mold Djex itself
follows: type expressions and they are evaluated, type declarations and
they enter the session, and a family of `:commands` gives you type
queries, documentation, search, and interactive tactic proving.

```text
λ> 2 + 2
4
λ> def double (n : Nat) : Nat := n + n
λ> double 21
42
λ> :synth ((A → B → C) → (A → B) → A → C)
  it1  fun f g x => f x (g x)
λ> :synth (∀ a b : Type, a → b)
provably uninhabited — no closed term of this polymorphic type exists
```

Lean 4 is normally driven from an editor, where the language server
shows goals and diagnostics as you edit a file. Leant complements that
workflow with a conversational one, aimed at exploration — trying a
lemma, poking at a definition, asking *is this type even inhabited?* —
where the unit of work is a line, not a file.

**Leant is experimental and under active development.** Commands change
shape between commits and output formats are not stable.

There is a manual: **[docs/Leant.pdf](https://raw.githubusercontent.com/VladimirReshetnikov/Leant/main/docs/Leant.pdf)**
— an overview and tutorial, with a detailed tour of `:synth`
([LaTeX source](docs/Leant.tex)).

## Contents

- [Highlights](#highlights)
- [Getting started](#getting-started)
- [Usage](#usage) — command-line options, Length counterexample
  ranking, and the command table
- [Interactive proving — `:prove`](#interactive-proving--prove)
- [`:synth` — automatic term synthesis](#synth--automatic-term-synthesis)
  - [Higher-order plumbing](#higher-order-plumbing)
  - [Programs you already know](#programs-you-already-know)
  - [Rank-N and impredicative goals](#rank-n-and-impredicative-goals)
  - [Impossibility, proved](#impossibility-proved)
  - [Classical candidates](#classical-candidates)
  - [Inductive types](#inductive-types)
  - [Recursion from the library](#recursion-from-the-library)
  - [Dependent formulas as cargo](#dependent-formulas-as-cargo)
  - [Synthesis inside a proof](#synthesis-inside-a-proof)
  - [Engines, budgets, and the fine print](#engines-budgets-and-the-fine-print)
- [How it works](#how-it-works)
- [Development](#development)
- [License](#license)

## Highlights

- **Verified term synthesis.** `:synth TYPE` constructs programs and
  proofs — ranked, bound as `it1`, `it2`, …, and every candidate
  re-elaborated by the Lean backend before it is shown. When no
  constructive inhabitant exists it can *prove* that, and for refuted
  propositional goals it offers classical candidates instead.
- **Interactive proving.** `:prove` turns the prompt into a
  tactic-by-tactic loop with unlimited `:undo`, and `:qed` saves the
  finished proof as a real theorem in the session.
- **A real REPL.** Definitions persist via the backend's environment
  threading; `it` holds the last result; TAB completes `:commands` and
  dotted identifiers; multi-line input opens automatically on
  syntactically incomplete lines and a blank line submits (`:{` … `:}`
  delimits an explicit block, as in GHCi).
- **Crash-proof sessions.** If the backend dies, times out, or is
  interrupted, it restarts and the session (imports + history) replays
  automatically; prove-mode scripts are printed before the mode exits,
  so work is never lost.
- **Sessions as artifacts.** `:transcript` records everything;
  `:pickle`/`:unpickle` snapshot and restore environments as `.olean`.
  Leant-created snapshots also carry a fingerprinted synthesis companion,
  while ordinary upstream snapshots remain compatible;
  `:load`/`:reload` round-trip `.lean` files.

## Getting started

Requires [GHC](https://www.haskell.org/ghcup/) 9.12.4 and cabal, plus
`lake`/`lean` on PATH (via [elan](https://github.com/leanprover/elan)).

```bash
git clone --recurse-submodules https://github.com/VladimirReshetnikov/Leant
cd Leant
cabal build exe:leant
```

The REPL core uses GHC boot libraries only, but `:synth` links the
vendored [Djex](lib/Djex) synthesis library (a read-only git submodule —
if you cloned without `--recurse-submodules`, run
`git submodule update --init lib/Djex`), which pulls `haskell-src-exts`
and a few other packages from Hackage. The bundled `cabal.project`
builds both packages together. On Windows, `leant.cmd` builds on first
use and runs the binary.

Leant drives the community
[leanprover-community/repl](https://github.com/leanprover-community/repl)
backend. It finds an existing `repl` binary automatically (including one
built by [LeanInteract](https://github.com/augustepoiroux/LeanInteract),
whose cache it searches), or you can point it at any build matching your
project's toolchain with `--repl-exe PATH` or the `LEANT_BACKEND`
environment variable.

## Usage

```text
leant [FILE] [--project DIR] [--plain] [-i MOD]
      [--timeout N] [--time] [--transcript [FILE]] [--timestamps]
      [--repl-exe PATH] [--lake PATH]
      [--length-ranking-config ABSOLUTE-PATH]
      [--length-ranking-config-timeout MS]
      [--length-ranking-allow-unpinned]
```

Run inside a Lake project (auto-detected, or `--project DIR`) to make
the project's modules and dependencies importable, or `--plain` for a
bare stdlib session with subsecond startup. Expressions evaluate via
`#eval` with `#check` fallback; declarations (`def`, `theorem`,
`inductive`, `open`, …) run verbatim and, on success, advance the
session environment; `#`-commands pass straight through.

Finite-list-spine Length counterexample ranking is disabled by default. To opt
in, pass `--length-ranking-config` with an explicitly chosen absolute path to
a version-1 through version-20 configuration file. Versions 1--3 select scalar
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
Version numbers are closed schema selections rather than cumulative feature
levels; versions 1--18 remain literal.
Leant admits and reads that file
once at startup, requires the configuration to contain an executable SHA-256
expectation by default, and retains the decoded contract selection as a fixed
process-wide assertion. Presence at activation is not a digest match; Djex
compares the expectation only when an eligible batch later opens a worker.
V1--v16 use the bounded pre-spawn pathname observation; v17--v20 compare it
with the sealed staged main image selected for descriptor execution.
`--length-ranking-allow-unpinned` is a separate explicit relaxation;
`--length-ranking-config-timeout` sets only the bounded file-load interruption
budget (default 5,000 ms, maximum 60,000 ms). No option discovers a file or
solver. POSIX configuration-file descriptor acquisition is implemented;
Windows currently fails
closed. Versions 1--6 and the established direct runners open one fresh lexical
solver worker for every eligible batch. Versions 7--20 instead complete all
admission and preparation, then run each candidate's pure MRU, selected
positive-affine domain, and origin prefix before IO: an all-pure batch opens no
process, while
the first live miss opens one lexical session for that query and the remaining
suffix. V9/v10 additionally capture one shared usable-work deadline after the
64-candidate admission gate and before full preparation, so deferred pure work,
opening, and every live query consume one window instead of receiving a fresh
batch allowance per query. V13--v20 capture the corresponding dynamically
scoped v2 owner at the same boundary and add cooperative checkpoints after
preparation, each complete candidate chain, and result materialization. Any
structured failure preserves callback order through the established atomic
fallback.
The opaque activated mode retains the exact require-pin or permit-unpinned
decision that released it, and Main derives its startup notice from that mode
rather than reinterpreting the raw command-line flag.
Only callback-verified candidates with direct or exact-duplicate-recovered
typed Exference authority are eligible. Candidates with neither authority
remain in place with a payload-free preparation refusal and do not open a
worker by themselves. The default `djinn` synthesis engine supplies no typed
graph; select `:set synth-engine exference` or `both` to produce candidates
which may reach this ranking path.

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

### Binary-product Length queries

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

All five applicable-domain builders are mutually exclusive and last-wins; the
budget builder is orthogonal and last-wins only within the v1/v2 budget
dimension. The strict pass retains the same MRU-before-domain order,
query-owned counterexample simplification, non-vacuous stable preference,
deferred lifecycle, atomic fallback, and model/provider-relative authority as
the relational pass. Here *strict* means natural strict comparison, not source
evaluation strictness. See the
[strict relational positive-affine Length ranking report](docs/reports/2026-08-15-strict-relational-positive-affine-length-ranking.md).

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
[strict relational positive-affine quotient Length ranking report](docs/reports/2026-08-15-strict-relational-positive-affine-quotient-length-ranking.md).

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
[shared usable-work Length ranking report](docs/reports/2026-08-15-shared-usable-work-length-ranking.md).

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
[scoped usable-work Length ranking report](docs/reports/2026-08-15-scoped-usable-work-length-ranking.md).

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
startup version 1 through 6, while startup versions 7 through 20 require it.
It is bounded componentwise-lexicographic
simplification, not global minimality, pruning authority, or a new conclusion
from Z3.

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
v19/v20 are handled only by their later quotient-consequence decoder.

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
version 21 remains unsupported. Loading and activation remain pure, and an
all-pure deferred batch opens neither an executable descriptor nor a worker.

Then select a typed Exference-producing engine and synthesize normally. A
contract-only v6 document can replace the startup-fixed contract for one
command without changing the CLI grammar:

```text
:set synth-engine exference
:synth List Nat → Prod (List Nat) (List Nat)
:synth --length-contract /absolute/path/pair-contract-v6.json -- List Nat → Prod (List Nat) (List Nat)
```

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

The old scalar decoders remain exact compatibility entrances: the startup
decoder for versions 1--3 rejects v4--v20, and the contract-only decoder for
versions 1--5 rejects v6. The generalized decoders delegate those old versions
to their unchanged scalar paths and add startup v4--v20 or contract-only v6. A
product file selects which nominal runner Main calls; it does not infer a
contract from the Lean type, bypass the exact canonical-`Prod` handoff, turn
solver status into evidence, or grant pruning authority. See the
[canonical `Prod` Length handoff report](docs/reports/2026-08-14-canonical-prod-length-handoff.md)
for the exact handoff boundary and the
[live binary-product Length ranking report](docs/reports/2026-08-14-live-binary-product-length-ranking.md)
for the live orchestration, authority, and compatibility details. The closed
v4/v6 file boundary is recorded in the
[binary-product Length configuration report](docs/reports/2026-08-14-binary-product-length-configuration.md).
The explicit v5/v6 preference and its unchanged evidence and identity
boundaries are recorded in the
[non-vacuous bounded-positive ordering report](docs/reports/2026-08-14-non-vacuous-bounded-positive-ordering.md).
The exact v7/v8 schema, positive-affine receipts, deferred state machine, and
compatibility boundary are recorded in the
[positive-affine deferred Length ranking report](docs/reports/2026-08-14-positive-affine-deferred-length-ranking.md).
The additive v9/v10 shared usable-work owner and unchanged behavioral authority
are recorded in the
[shared usable-work Length ranking report](docs/reports/2026-08-15-shared-usable-work-length-ranking.md).
The v11/v12 relational rule, exact v7/v8-shaped schema, nominal evidence, and
deliberate absence of the shared budget are recorded in the
[relational positive-affine Length ranking report](docs/reports/2026-08-15-relational-positive-affine-length-ranking.md).
The v13/v14 scoped owner, cooperative checkpoints, closed schema, failure
boundary, and additive identities are recorded in the
[scoped usable-work Length ranking report](docs/reports/2026-08-15-scoped-usable-work-length-ranking.md).
The v15/v16 strict-natural rule, inherited scoped lifecycle, nominal evidence,
closed schema, and unchanged older routes are recorded in the
[strict relational positive-affine Length ranking report](docs/reports/2026-08-15-strict-relational-positive-affine-length-ranking.md).
The v17/v18 sealed main-image selection, closed execution discriminator,
startup notice, compatibility boundary, and unchanged evidence are recorded in
the
[descriptor-bound Length/Z3 launch report](docs/reports/2026-08-15-descriptor-bound-length-z3-launch.md).
The v19/v20 root-quotient laws, inherited descriptor/scoped profile, nominal
assessments and notes, and unchanged older routes are recorded in the
[strict relational positive-affine quotient Length ranking report](docs/reports/2026-08-15-strict-relational-positive-affine-quotient-length-ranking.md).
Djex's underlying strict extraction boundary is in its
[strict relational positive-affine applicable-domain report](lib/Djex/docs/reports/2026-08-15-strict-relational-positive-affine-length-applicable-domain.md).
The quotient-consequence extraction, receipt, authority, and identity boundary
is in Djex's
[strict relational positive-affine quotient applicable-domain report](lib/Djex/docs/reports/2026-08-15-strict-relational-positive-affine-quotient-length-applicable-domain.md).

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
Main's v7--v10 path can produce only the literal-ceiling positive-affine receipt
family; v11--v14 can produce only the relational family; v15--v18 can produce
only the strict-relational family; v19/v20 can produce only the root-quotient
successor family; v1--v6 cannot produce any applicable-domain family. The semantic note
never projects the receipt's private provider-name list. Disabled assessment,
rejected input, heuristic status,
and atomic operational fallback add no semantic note. The note can explain a
stable demotion; it never proves, prunes, or claims concrete Lean behavior.

| Command | Meaning |
|---|---|
| `:help`, `:h`, `:?` | show help |
| `:quit`, `:q` | exit |
| `:type EXPR`, `:t` | show the type of an expression (`#check`) |
| `:info NAME`, `:i` | show a definition (`#print`, rendered as a valid declaration) |
| `:load FILE`, `:l` | reset the session and load a `.lean` file |
| `:reload`, `:r` | reload the last loaded file |
| `:import MOD` | add an import (rebuilds and replays history; rejected over an opaque snapshot) |
| `:imports` | list active imports, or the imports restored by the next `:reset` |
| `:browse [NS]` | list declarations in a namespace (`:browse!` includes generated auxiliaries) |
| `:doc NAME` | show the documentation string of a declaration |
| `:search TEXT` | case-insensitive name search over the environment |
| `:search? TYPE` | proof search: what proves TYPE? (via `exact?`) |
| `:synth TYPE` | verified term synthesis (see below) |
| `:synth --length-contract ABSOLUTE-PATH -- TYPE` | use one passive scalar-or-pair Length contract selection for this synthesis command |
| `:prove [PROP]` | interactive prove mode; bare form resumes the last `sorry` |
| `:set OPT VAL` | `set_option` persisting in the session |
| `:undo` | revert the last state-changing command |
| `:reset` | clear definitions or an active snapshot base, keeping configured imports |
| `:history` | list state-changing commands after the current import/snapshot base |
| `:env` | show the backend environment id |
| `:time` | toggle per-command timing |
| `:transcript [FILE\|on\|off]` | record a full transcript of the session |
| `:timestamps [on\|off]` | timestamp each command in the transcript |
| `:pickle FILE` / `:unpickle FILE` | save the environment plus synthesis companion / restore it as a new undo base |
| `:! CMD` | run a shell command |

Built-ins and keywords that are not constants in the environment
(`imax`, `Sort`, `fun`, `→`, `∀`, `⟨⟩`, …) get explanatory help from
`:t`/`:info` instead of an unhelpful "Unknown identifier".

## Interactive proving — `:prove`

`:prove PROP` opens a tactic loop against the backend's proof-state
protocol (bare `:prove` resumes the most recent `sorry`). Every line is
a tactic; goals reprint after each one, followed by a Lean-verified
suggestion for the next tactic. The candidate probes are shaped by the
goal and its hypotheses: an `intro` suggestion names the binders it
would introduce, a disjunction goal is probed with `left`/`right`, a
hypothesis whose type a single step can take apart is probed with
`cases h` or `obtain ⟨x, h1⟩ := h`, and a data-typed variable the goal
mentions is probed with `induction`. The search prefers a candidate that
closes the goal outright and annotates the suggestion accordingly
(`closes the goal`, `splits into 2 goals`); when no single tactic
closes it, a second phase chains quick finishers onto the best
progressing candidates (`constructor <;> omega`, `obtain ⟨h, h2⟩ := h1
<;> exact Exists.intro x h`), so even the opening suggestion is often a
complete checked proof. The chains also try `simp_all`, unfolding the
definitions the goal mentions and calling in `omega` on whatever
arithmetic remains, which is how an induction suggestion can arrive as
a finished proof: `induction l <;> simp_all [myLen]`, or `induction n
<;> simp_all [double] <;> omega`. Suggestions are advisory: they never advance
the proof or enter the script, and `:suggest` reprints the cached
suggestion.
`:undo` takes back steps without limit; `:script` shows the accumulated proof;
`:auto` tries common finishers; `:qed [NAME]` turns the script into a real
theorem in the session. `?`-tactics (`exact?`, `simp?`, `rw?`) record the
tactic they *found* rather than the question-mark form. Proof-state identifiers
belong to one backend process: if that process stops, Leant leaves prove mode
and prints the accumulated script instead of submitting a stale identifier
after the session restarts.

```text
λ> :prove ∀ p q : Prop, p ∧ q → q ∧ p
entering prove mode — type tactics; :help for commands
⊢ ∀ (p q : Prop), p ∧ q → q ∧ p
suggestion: intro p q h <;> exact And.comm.mp h  (closes the goal)
⊢> intro p q h
p q : Prop
h : p ∧ q
⊢ q ∧ p
suggestion: exact And.comm.mp h  (closes the goal)
⊢> exact And.comm.mp h
All goals accomplished 🎉
finish with :qed [NAME], inspect with :script
⊢> :qed and_swap
saved: theorem and_swap : ∀ p q : Prop, p ∧ q → q ∧ p
```

At its best the suggestion machinery hands you a finished induction:
here it combines `induction` (the goal mentions a data-typed
variable), `simp_all` unfolding the function the goal is about, and
`omega` for the leftover arithmetic — a complete verified proof of a
theorem about a function defined two lines earlier:

```text
λ> def double : Nat → Nat
…>   | 0 => 0
…>   | n + 1 => double n + 2
…>
λ> :prove ∀ n : Nat, double n = 2 * n
entering prove mode — type tactics; :help for commands
⊢ ∀ (n : Nat), double n = 2 * n
suggestion: intro n
⊢> intro n
n : Nat
⊢ double n = 2 * n
suggestion: induction n <;> simp_all [double] <;> omega  (closes the goal)
⊢> induction n <;> simp_all [double] <;> omega
All goals accomplished 🎉
finish with :qed [NAME], inspect with :script
⊢> :qed double_two_mul
saved: theorem double_two_mul : ∀ n : Nat, double n = 2 * n
```

## `:synth` — automatic term synthesis

`:synth TYPE` answers the question *"write me a term of this type"* —
read through propositions-as-types, *"prove this"* — and sometimes the
stronger question *"show me that no such term exists."* It covers the
structural fragment `→ / × / ∧ / ⊕ / ∨ / ↔ / ¬ / ⊥ / ⊤ / ∀` over opaque
variables, plus structurally representable inductive data, with bounded
support for rank-N and impredicative quantification. Proper-type applications
of one inductive family are shared by exact Lean head across the whole query,
so differently instantiated `Option`, `Except`, `List`, and user-family
occurrences retain one nominal identity. Compatible non-recursive families
keep their constructors and cases; compatible recursive families additionally
retain bounded one-layer elimination in Exference. If its usual all-inputs-used
search has no candidate, Leant retries that same Exference query with omissions
allowed; this can project an impredicative payload while rendering the unopened
recursive tail as `_`. Both engines can also reuse a small, goal-relevant slice
of the live Lean environment, and `List` and `Nat` goals can compose rated
library functions such as `List.map` and `List.foldr` into candidates. Design
and phasing:
[docs/SYNTHESIS_PROPOSAL.md](docs/SYNTHESIS_PROPOSAL.md). The implementation
invariants are recorded in the dated reports for
[finite families](docs/reports/2026-08-01-query-wide-parametric-inductive-families.md)
and
[recursive families](docs/reports/2026-08-01-query-wide-recursive-family-identity.md),
with the scoped quantified-provider boundary documented in the
[local-provider report](docs/reports/2026-08-01-scoped-quantified-local-providers.md)
and the active-instance extension in the
[provider-local instance-head report](docs/reports/2026-08-05-provider-local-instance-head-evidence.md).
Its complete multi-binder correlation follow-up is recorded in the
[correlated instance-head assignment report](docs/reports/2026-08-05-correlated-instance-head-assignments.md).
Djinn's expanding occurrence-plan family and Leant's checked integrations are
recorded in the
[quartic rank-N frontier report](docs/reports/2026-08-06-quartic-rank-n-frontiers.md)
and its
[quintic successor](docs/reports/2026-08-06-quintic-rank-n-frontiers.md).
The historical five-binder Djex boundary and Leant's matching live bridge are
recorded in the
[five-binder integration report](docs/reports/2026-08-09-five-binder-instantiation.md).
Its one-through-six successor is recorded in the
[six-binder integration report](docs/reports/2026-08-10-six-binder-instantiation.md).
Djinn's additive specialization of query-local schemes at closed monotypes is
recorded separately in the
[query-local closed-monotype report](docs/reports/2026-08-09-query-local-closed-monotype-instantiation.md).
Exact render-only retention of implicit forall visibility and mixed sort
domains is recorded in the
[implicit provider visible-result report](docs/reports/2026-08-09-exact-implicit-provider-visible-results.md).

The engine is the vendored [Djex](lib/Djex) library, linked in-process.
Djex began as a merger of two classic Haskell synthesizers — **Djinn**
(complete, terminating proof search for intuitionistic propositional
logic, Dyckhoff's LJT calculus) and **Exference** (ranked heuristic
search under explicit budgets) — but has grown well beyond either
original: a shared, validated synthesis foundation with checked
boundaries; a unified type-class constraint contract spanning both
engines; fixes for long-standing soundness bugs (an exhausted search
over an *approximated* goal no longer counts as a refutation); and,
most importantly here, a principled treatment of **rank-N and
impredicative types** — goal-side quantifiers open through
polarity-aware plan families, quantified hypotheses and context-free loaded
schemes are instantiated at a bounded set of query and environment types, and
impredicative instantiation is admitted under a guard that never invents a
polytype the checked input did not supply.

Leant's synthesis preparation now builds one semantic-origin record whose
source and search goals, declarations, provider bindings, constructor and type
renderer maps, premise layout, and completeness facts provide the respective
inputs projected by search and the renderer closures, then remain unchanged in
the exact Exference run authority. Each provider binding is the sole prepared
owner of its private declaration inputs, renderer metadata, and ordered
instantiation assignments. Preparation derives provider declarations and one
lazy strict-map projection shared by both renderer closures; exact-origin
rerendering and inspection derive that same map projection at their use edges.
For exact live `(instantiations ...)` metadata on an Exference contextual
provider only, preparation may also instantiate the provider's retained leading
class constraints with its complete
closed assignment vector and add the resulting zero-binder,
zero-prerequisite ground facts to the exact synthesis inventory. Historical
`(candidates ...)` metadata remains a search compatibility hint and cannot
originate those facts. An assignment stays provider-local for specialization
and rendering, while a derived class fact is inventory-global: it may serve a
matching obligation on another provider because Lean established the complete
top-level active-instance closure without query givens.
Djinn, Exference, and inspection likewise derive or project the historical
aggregate assignment list in binding order. The prepared semantic origin does
not cache an aggregate assignment list or a provider renderer map beside the
bindings. One private conversion maps that exact ordered projection through the
Exference lane's complete source-name table for the search call; the run
authority retains the bindings and table instead of caching the converted
assignment list, and its package-private inspection view derives the historical
field lazily. The authority likewise does not cache a converted source goal
beside the prepared source goal and name table. Its inspection view derives
that historical field lazily, while the Length handoff performs the same
checked conversion before it checks request contexts and the request goal.
There is no post-search field-for-field preparation copy. The
detailed Exference route retains an opaque checked candidate and that exact
run authority beside the originating rendered group. The candidate remains the
sole owner of its graph and any opaque checked certificate association.
Rendering may inspect the public bare-graph projection, but a stamped
projection has discarded that association and is rejected by Djex's public
shared-graph fingerprint. The Length handoff instead passes the whole candidate
to Djex so the domain can freshly reseal and authorize either an exact
obligation-free provider or one exact conditional occurrence whose ground
obligations and protected certificate prefix pass Djex's static checks. The
rendering sidecar carries no parallel
fallible graph-key cache. Filtering preserves a group sidecar only
with its original candidate. During combined-engine exact-text deduplication,
an earlier compatibility-only spelling may retain a private variant-scoped
witness to the first later Exference candidate which rendered the identical bytes; display
ownership, route, ordinal, ordering, and sibling variants remain unchanged, so
no sidecar is transferred onto a Djinn group. At the verification boundary the
display route, ordinal, and text are flattened into the callback candidate and
that spelling carries its exact typed origin in one field; the accepted receipt
does not retain the scheduling-only variant record or a parallel origin copy.
Wrappers such as
`Classical.byContradiction` discard both direct and recovered authority because
they denote a new term.
This is deliberately a solver-neutral identity seam, not behavioral evidence.
`Leant.Synth.Length.Handoff` binds callback-accepted text back to its exact
typed origin, original Exference renderer ordinal and exact re-rendered variant,
family provenance, an opaque Djex session which owns the exact inventory and
provider assumptions, its checked interpretation policy, the separately
reassociated contract, and the
candidate-specific Djex problem. That checked preparation consumes the
renderer, family, and session authority and returns only the sealed problem;
Engine owns the exact-origin rerender mechanics and private premise-layout ABI.
Handoff preserves the historical singleton/ordinal-zero rule for startup,
contract-only versions 1--3, and version 5's explicit `cases-rejected` policy.
The exact policy in version 4 or 5 instead owns selection of the retained
original ordinal and equality with the callback-accepted text; other valid
renderer alternatives neither replace that retained variant nor make its exact
association ambiguous.
Only after renderer correspondence and exact family/provider resolution,
Handoff converts the contract's `(candidate case policy, target roles)` pair
once into Djex's closed `LengthInterpretationPolicySource`. Legacy
case-rejecting contracts retain the implicit all-observed source; v3 and v5
case-rejecting contracts retain their explicit role vector; and v4/v5 exact
contracts retain that same vector beside exact zero/step authority. Exact
authority without roles is still refused at this point, so family and provider
failures retain their historical precedence. Handoff then uses only Djex's
session-owned `sealLengthSessionWithInterpretationPolicy`,
`sealLengthContractInSession`, and
`sealLengthTypedCandidateProblemInSession` path. The contract and candidate
cannot be sealed under separately selected role or case modes, and Leant no
longer calls the compatibility problem wrappers. Renderer selection continues
to use the raw decoded case policy. Sessions containing only legacy provider
summaries retain Djex's exact Length policy versions 5/6/7. Presence of a
constraint-conditional summary instead selects policies 8/9/10 and concrete
encodings 4/5/6; a successfully ground-discharged carrier uses candidate v3.
Conditional provider inventory v3 and semantic inventory v2 retain the
source context, while legacy provider/semantic inventory v2/v1, plain candidate
v1, obligation-free associated candidate v2, and concrete encodings 1/2/3 keep
their exact identities. Contract grammar and signatures,
legacy-versus-explicit-all-observed equivalence within each policy family, and
Leant's renderer selection remain unchanged.
The authority migration and compatibility matrix are detailed in the
[unified checked Length handoff policy report](docs/reports/2026-08-13-unified-length-handoff-policy.md).
The opaque carrier handoff and its trust limits are recorded in the
[Length certificate-carrier handoff report](docs/reports/2026-08-13-length-certificate-carrier-handoff.md).
The live exact-context wire, active-instance provenance, and inventory-wide
ground-fact bridge are recorded in the
[contextual-provider ground-discharge report](docs/reports/2026-08-13-live-contextual-provider-ground-discharge.md).
`Leant.Synth.Length.Adapter` then seals it into a bounded canonical QF_LIA
query without exposing an arbitrary problem-taking entrance. Neither step
launches a solver or grants authority
to raw `sat`, `unsat`, or `unknown`: only decoded input values which pass Djex's
independent exact-problem replay can yield a finite-spine, model-relative
counterexample receipt, still conditional on every named provider law used by
that candidate. Inside problem sealing, the exact checked provider summaries
reached by symbolic interpretation flow directly into the canonical used-law
identity; the names-only receipt is derived separately and never becomes an
authority lookup key. The problem's generic behavioral envelope is the single
retained owner of its concrete encoding fingerprint; the Length-specific
projection derives from that envelope rather than storing a second copy. The
candidate's versioned key already embeds the exact freshly checked graph
fingerprint, so the interpreted receipt does not retain a second detachable
graph key. That receipt is not by itself a concrete Lean counterexample or
kernel proof.
The query's typed SMT plan is transient through rendering and structural
fingerprinting. Once sealed, the opaque query retains only its checked problem,
bounded canonical check bytes, and complete fingerprint. Exact ordered input
symbols and optional canonical `get-value` bytes are rederived from the
problem's sealed arity after both were already bounded and structurally
fingerprinted during sealing; the unchanged structural fingerprint still binds
the full typed plan.
The collision boundary is detailed in the
[exact-duplicate typed-provenance report](docs/reports/2026-08-11-exact-duplicate-typed-provenance.md).

`Leant.Synth.Length.Ranking` supplies the checked ranking foundation. Its
caller must provide an explicit Djex live-execution policy,
explicit replay limits, an explicit `LeanLengthContract`, and the complete list
of callback-verified candidates. It productively admits at most Djex's public
64-query session bound, attempts every candidate handoff, and seals every
eligible canonical query before any possible process launch. Eager policy then
opens one lexical session; deferred policy first processes the pure source
prefix and opens at most one session on the first live miss. Both process
candidates serially in original order. After an exact counterexample,
the ranking pass retains its bounded source-ordered input naturals in a fixed
four-entry batch-local bank. The bank is newest first, deduplicates exact
vectors, promotes a replay hit or live counterexample, and evicts the least
recently used vector when a fifth distinct live counterexample is inserted.
For each later eligible query, Leant makes at most four pure replay attempts in
that order through Djex's
`replayLengthSMTLibCounterexampleInputs`. The sealed query owns its checked
problem and behavioral association and rederives its modeled arity and symbols
from that problem; Leant supplies only `[Natural]` and the configured
evaluation limits. Every hit is therefore freshly evaluated and associated
with that later query, creates a
fresh receipt, promotes the exact vector, and avoids one Z3 call. Arity or
evaluation rejection, a non-counterexample, or association mismatch is only a
bank miss; replay continues with the next vector and then follows the
established live path if all four miss. Pure misses, heuristic live statuses,
and preparation refusals do not mutate the bank. The bank never contains a
cached solver result, verdict, query, receipt, provider-law basis, proof,
solver status, or durable cache entry.

The programmatic
`enableLengthRankingApplicableDomainValidation inputBoxLimits` policy inserts
Djex's directly bounded pass after those MRU misses. Djex scans only the exact
checked normalized top-level precondition for direct `input <= literal`
clauses, selects the tightest duplicate for each compact input, and requires
every nonnullary input to be covered. Missing coverage is an ordinary
inapplicable result and continues to the next stage. A nullary query derives
maxima `[]` and validates its single assignment `[]`. Width, maximum-
value, and assignment-count admission refusals are likewise ordinary misses.
Exact admitted coverage drives a solver-independent tight-box traversal. A
violation becomes the
ordinary `Counterexample` and enters the MRU bank; complete traversal becomes
`ApplicableDomainEstablished`, carries an opaque model/provider-relative
receipt, and skips origin and live execution. Its vacuous form remains neutral.
Only the separate
`enableLengthRankingNonVacuousApplicableDomainPreference` moves an established
receipt with a positive applicable-assignment count into a stable preferred
partition. Startup versions 1--6 cannot enable either policy, so their file
behavior is exact. Startup v7--v20 enable that same preference with their
nominal literal-ceiling, relational, strict-relational, or strict-relational
root-quotient positive-affine validator; direct-v1 validation remains
programmatic-only.
Contract-only files select constraints rather than ranking policy.

`enableLengthRankingPositiveAffineApplicableDomainValidation` is a separate,
mutually exclusive extractor. It scans the precondition itself or immediate
flat top-level conjunction clauses and recognizes only compact inputs, natural
literals, sums, and positive-literal scales in `A <= k`, `A == k`, or `k == A`.
For `c + sum(ai*xi) <= k`, each positive coefficient derives
`xi <= (k-c) quot ai`; equality grants the same necessary upper bound, and
duplicate bounds take the minimum. Unsupported clauses grant no bound but stay
in the actual replayed precondition. A literal false, unequal constant-only
equality in either orientation, or recognized affine constant `c > k` is a
syntactic contradiction which overrides missing coverage. A contradictory
nonnullary query validates the one all-zero assignment, yielding maxima all
zero, total count 1, and applicable count 0. A true constant equality is
non-binding. A nullary query skips coverage extraction, validates `[]`, and
records applicable count 1 or 0. Startup v7--v10 select this rule explicitly;
the direct v1 builder, functions, receipts, and identities remain literal.

`enableLengthRankingRelationalPositiveAffineApplicableDomainValidation` is the
third mutually exclusive extractor. It accepts the same positive-affine
expression grammar on both sides of a top-level inequality or equality,
cancels common constants and coefficients, and propagates maxima through
directed relations. Equality contributes both directions. Bounds advance in
immutable synchronous snapshots, and every eligible rule fires at most once;
the sound result is deliberately not a numeric least fixed point. Unsupported
clauses grant no coverage rule, unresolved inputs remain ordinary
inapplicability, and the actual normalized precondition is still replayed over
the complete derived box. Startup v11--v14 select only this relational rule and
its nominal scalar/product receipt family. They retain every v7/v8 operational
selection; v11/v12 deliberately omit a usable-work budget, while v13/v14 add
the dynamically scoped/checkpointed v2 owner.

`enableLengthRankingStrictRelationalPositiveAffineApplicableDomainValidation`
is the fourth mutually exclusive extractor. It retains those ordinary
relations and additionally treats only an immediate normalized top-level
`not (L <= R)` as the exact natural rule `R + 1 <= L`, applying the successor
before ordinary coefficient cancellation. It is not general negation handling:
negated equality, nested logical structure, and unsupported positive-affine
subtrees contribute no rule or partial bound. Startup v15--v18 select its
nominal scalar/product receipt family and otherwise retain v13/v14's complete
scoped/checkpointed policy.

`enableLengthRankingStrictRelationalPositiveAffineQuotientApplicableDomainValidation`
is the fifth mutually exclusive extractor. It delegates every quotient-free
clause to that strict predecessor and recognizes only one positive-literal
Natural quotient at the root of exactly one relation operand. The four exact
directed laws are the two non-strict and two immediate-negated implications
shown above; equality emits the two non-strict directions in source order.
The inherited synchronous rule-once closure handles propagation. Nested,
embedded, and two-root quotient shapes and unsupported whole clauses grant no
partial rule, and actual precondition replay remains authoritative. Startup
v19/v20 select its nominal scalar/product receipt families while retaining the
complete v17/v18 descriptor-bound, scoped/checkpointed, and deferred profile.

Configuration version 3 inserts one query-owned origin probe after all four
bank entries—and after an enabled applicable-domain pass is inapplicable—before
that candidate's live Z3 query. Leant supplies no
arity or values: Djex derives one zero per compact modeled input from the
sealed checked problem and runs the ordinary bounded replay and exact
association gate. A hit is the ordinary `Counterexample`; it is stably demoted
and its exact zero vector is inserted or promoted in the same MRU bank. A miss
is no evidence, leaves the bank unchanged, and proceeds to live Z3. An
evaluation rejection or association mismatch is an indexed operational
failure and activates the same batch-wide original-order, all-`Unassessed`
fallback. The probe consumes no solver status and does not itself schedule the
finite box. Under eager policy the worker has already opened and an origin hit
avoids only a live transaction and ordinal. Under deferred policy the origin
probe runs before IO, so an all-pure batch can avoid process launch and its
capability probe entirely.

With the version-1 historical path, `unsat`, `unknown`, and status-only `sat`
remain neutral. The explicit input-box paths instead use a live `unsat` only to
trigger Djex's independent exhaustive replay of
caller-selected per-input inclusive maxima. A discovered violation becomes the
ordinary `Counterexample`, is
stably demoted, and updates the MRU bank. Complete traversal becomes
`BoundedPositive`, contributes no seed, and records only bounded/model-relative
positive evidence. It stays in the neutral stable partition under the existing
builder and startup versions 2--4. The explicit
`enableLengthRankingNonVacuousInputBoxPreference` builder—or startup scalar
v5/v7/v9/v11 or pair v6/v8/v10/v12—moves only a receipt with a positive
applicable-assignment count into a stable preferred partition. A
zero-applicable receipt remains neutral.
A validation
or association rejection is an indexed operational failure and activates the
same original-order, all-`Unassessed` atomic fallback. `sat` and `unknown`
remain heuristic. Live
observations still cross Djex's query-first gate, which checks the exact
canonical query fingerprint before inspecting optional evidence and replays
that evidence against the behavioral problem retained by the query.
The checked problem is transient until query sealing; there is no separate
runtime handoff wrapper, second callback receipt, or retained family binding.
Prepared live state retains only the caller-owned receipt association and
sealed query. The direct compatibility path uses the verified receipt itself
as that association; the presentation-safe path uses the batch-scoped
occurrence handle without a parallel detached receipt. After the permutation
seal, the accepted result retains the sealed batch as its sole receipt owner
beside an eager receipt-free ranking summary; the public ranked receipts are
materialized from those associated values only when requested. The
package-private presentation layer traverses each whole materialized ranked
receipt and projects one opaque text-plus-note value. Main uses that single
ordered list for bindings, splices, and `itN` output; it never zips candidate
text with a detached evidence list.
Nothing is pruned. A candidate-local handoff or query-construction refusal
still projects through the compatible `Unassessed` assessment, but now also
retains one bounded payload-free `LengthPreparationRefusalClass` with a fixed
machine code. The exhaustive classifiers inspect only the outer refusal
constructor: renderer text, source names, types, graph identities, and nested
Djex errors are neither evaluated nor retained in the refusal diagnostic, and
the class makes no behavioral-evidence claim. The exact verified receipt and
its semantic sidecar remain attached to the candidate. Any returned structured
live session, query, association, replay, applicable-domain, origin-probe, or
finite-box failure atomically restores every original candidate in original
order: eligible prepared candidates become `Unassessed`, while candidate-local
pure preparation refusals retain their bounded refusal class. The result carries
only one sanitized batch failure class, cleanup bit, and optional safe original
index; a successfully prepared candidate gains no invented refusal reason.
Exceptions propagate instead of producing a ranking. Legacy v1--v8 and
relational startup v11/v12 retain separate lifecycle and per-query budgets. An
explicitly v1-budgeted programmatic policy or startup v9/v10 instead places
admitted preparation and deferred ranking beneath one runtime-unscoped shared
owner. Startup v13--v20 and the scoped programmatic builder use the additive
owner-thread-affine v2 lease and cooperative phase checkpoints. Neither owner
claims asynchronous interruption of arbitrary callback code. Main invokes
this foundation only after the explicit startup opt-in described above; it
never infers an executable path, contract, or policy. The foundation is
detailed in the
[live Length ranking foundation report](docs/reports/2026-08-11-live-length-ranking-foundation.md).
The batch-local replay optimization and its unchanged trust and identity
boundaries are recorded in the
[Length counterexample seed replay report](docs/reports/2026-08-13-length-counterexample-seed-replay.md).
Its fixed four-entry MRU policy and Djex's query-owned raw-input replay boundary
are detailed in the
[Length input replay bank report](docs/reports/2026-08-14-length-input-replay-bank.md).
The version-3 all-zero checkpoint, exact MRU/origin/live order, and failure and
identity boundaries are detailed in the
[Length origin-probe orchestration report](docs/reports/2026-08-14-length-origin-probe-orchestration.md).
The opt-in finite-box policy, its unsat-as-trigger-only boundary, positive
receipt, and additive configuration grammar are detailed in the
[unsat-triggered bounded Length validation report](docs/reports/2026-08-14-unsat-triggered-length-input-box-validation.md).
The separately enabled stable preference for non-vacuous positive receipts is
detailed in the
[non-vacuous bounded-positive ordering report](docs/reports/2026-08-14-non-vacuous-bounded-positive-ordering.md).
The directly bounded pre-live pass, separate non-vacuous preference, and
unchanged configuration boundary are recorded in the
[directly bounded applicable-domain report](docs/reports/2026-08-14-directly-bounded-length-applicable-domain.md).

`Leant.Synth.Length.SpinePair.Ranking` and
`Leant.Synth.Length.SpinePair.PostVerification` supply the nominal
canonical-`Prod` sibling of this orchestration. The pair path reuses the same
bounded execution policy and lexical Djex session capability, but prepares
only pair queries and releases only pair-domain assessments and receipts. Its
own four-entry batch-local MRU bank, optional applicable-domain validation,
optional origin probe, live pair call, query-first replay, and optional
post-`unsat` pair input box preserve the same
stable-demotion and atomic-fallback rules without transferring scalar
authority. Pair-safe terminal projection lives in
`presentLengthSpinePairPostVerificationResult`; the complete checkpoint is
recorded in the
[live binary-product Length ranking report](docs/reports/2026-08-14-live-binary-product-length-ranking.md).

`Leant.Synth.Length.Configuration` seals that call boundary without choosing
any policy for the user. `LengthRankingPolicySource` carries the execution
admission, complete execution source (absolute Z3 path, optional SHA-256
expectation, solver/host budgets, artifact policy, and response limits), and
replay-limit source. After validation, `LengthRankingPolicy` retains the
opaque sealed Djex execution configuration and evaluation limits plus a
private selected direct-v1, positive-affine-v1,
relational-positive-affine-v1, strict-relational-positive-affine-v1, or
strict-relational-positive-affine-quotient-v1
applicable-domain pass,
optional origin probe, independent optional finite-input-box orchestration,
optional counterexample simplification, orthogonal non-vacuous ordering
preferences for applicable-domain and explicit-box receipts, and an eager or
deferred session-opening choice, plus an optional already validated shared
usable-work budget. `mkLengthRankingPolicy` leaves the optional choices disabled
and selects eager opening with no shared budget. The additive
`mkLengthRankingPolicyWithDescriptorBoundExecutableLaunch` validates the same
source in the same execution-before-evaluation order while selecting Djex's
sealed main-image launcher:

```haskell
descriptorPolicy <-
  mkLengthRankingPolicyWithDescriptorBoundExecutableLaunch policySource

case lengthRankingPolicyExecutableLaunchStrategy descriptorPolicy of
  LengthSMTLibDescriptorBoundExecutableLaunch ->
    assessVerifiedLengthCandidatesWithPolicy
      descriptorPolicy scalarContract verificationBatch
  LengthSMTLibPathSnapshotThenDirectSpawn ->
    error "impossible for this constructor"
```

This construction is pure. It does not open, hash, copy, seal, or launch the
configured executable. It preserves every later policy builder, and
`lengthRankingPolicyFromValidatedComponents` retains whichever sealed Djex
strategy its caller already owns. The corresponding configured-mode projection
is `lengthAssessmentModeExecutableLaunchStrategy`; disabled assessment returns
`Nothing` without inspecting any contract.
The
finite box is
enabled by its explicit builder or the version-2 decoder; versions 3 and 4
enable the box and origin probe while retaining neutral positive ordering.
Versions 5 and 6 also enable only the explicit box-receipt preference. Versions
7 and 8 require the positive-affine pass, both non-vacuous preferences,
simplification, and deferred opening; they cannot select direct v1. Versions 9
and 10 retain those respective scalar/product bundles and additionally enable
the required validated runtime-unscoped v1 budget. Versions 11 and 12 instead
retain the v7/v8 root bundle, select relational positive-affine validation, and
leave the usable-work budget disabled. Versions 13 and 14 retain that relational
bundle and enable the scoped/checkpointed v2 strategy. Versions 15 and 16
retain that complete scoped bundle and replace only the applicable-domain
strategy with the strict-relational selector. Versions 17 and 18 retain the
strict/scoped scalar and product bundles and change only the sealed executable
launch authority. Versions 19 and 20 retain those descriptor/scoped bundles
and replace only the applicable-domain strategy with the root-quotient
successor. Programmatic callers opt
in with `enableLengthRankingUsableWorkBudget` or
`enableLengthRankingScopedUsableWorkBudget`; both builders are pure and create
no evidence, and the last budget builder applied determines the strategy.
A scalar `LeanLengthContract` or nominal
`LeanLengthSpinePairContract` is supplied separately to its domain-specific
runner, so a request assertion no longer has to share the lifetime of reusable
process policy. Execution validation
precedes replay-limit validation. The sealed policy is opaque, has no path or
digest-byte projection, and retains no worker; its two closed classifiers
reveal only digest-expectation presence and the selected executable-launch
strategy. The explicit
contract remains a passive assertion. An eager eligible call opens a fresh
lexical session; a deferred all-pure call opens none, and a deferred live miss
opens exactly one for the remaining dynamic scope.

The version-1 file format remains compatible without a second generic
policy-plus-contract aggregate. Its disabled value retains one strict validated
policy beside the decoded contract, which stays lazy. Activation checks only
the policy's digest-expectation presence and releases that fixed compatibility
pair to `Integration`; the private configured mode keeps the pair together and
calls the occurrence-sealed policy-plus-contract assessor directly. Its
candidates retain their batch-scoped occurrence handles through ranking, and
the adapter seals the complete permutation before projecting the report. The
contract is checked candidate-by-candidate only during the later full
preparation pass. The no-option command deliberately reuses that decoded
contract for the process. Lower-level policy APIs and the one-shot Main path
can instead associate the same activated policy with a request-owned contract.
Legacy v1--v8 and startup v11/v12 lifecycle and per-query budgets remain
separate. A policy derived with `enableLengthRankingUsableWorkBudget`, including
startup v9/v10, instead owns one additive runtime-unscoped v1 usable-work
window. A policy derived with `enableLengthRankingScopedUsableWorkBudget`,
including startup v13--v20, owns the owner-thread-affine v2 lease, cooperative
checkpoints, and outer post-finalizer observation described above. There are no
execution defaults, executable discovery, path normalization, or environment
reads. The digest is only an optional expectation for Djex's
live executable observation. V1--v16 retain the explicitly weaker pathname
snapshot; v17--v20 compare the expectation with the sealed staged main image.
Neither choice attests loaders, libraries, or solver semantics. See the
[explicit live Length ranking configuration report](docs/reports/2026-08-11-explicit-live-length-ranking-configuration.md).
The later
[single-owner policy checkpoint](docs/reports/2026-08-13-length-ranking-policy-single-ownership.md)
records removal of the redundant generic configuration aggregate while
preserving the version-1 compatibility path.

`Leant.Synth.Length.Configuration.File` keeps the exact version-1 JSON grammar
for that policy and adds exact scalar opt-in versions 2 and 3. Its established
`decodeLengthRankingConfigurationFile` remains an exact scalar-only entrance
and rejects versions 4--20. The generalized
`decodeLengthAssessmentConfigurationFile` additionally accepts versions 4--20
and returns an opaque `DisabledLengthAssessmentConfiguration` carrying the same
checked process policy beside a lazy scalar-or-pair selection. The pure decoder consumes a caller-owned
strict byte string through a separate bounded JSON parser, rejects malformed
UTF-8, duplicate keys, unknown or missing fields, non-integral policy numbers,
and any parser, contract, or operational value above its hard ceiling. Every
object field is required. Contract expressions and formulas use closed tagged
arrays. Their core limits are pinned to the corresponding Djex default Length
limits, with additional Leant depth and name bounds; the file cannot widen
candidate type, contract, provider, literal, or fingerprint authority. A
successful decode returns an opaque *disabled*
configuration. The caller must then explicitly require a pinned executable or
explicitly permit an unpinned one before releasing its strict policy and lazy
fixed contract to the package-private integration boundary. Activation derives
that absent/present decision from the sealed Djex execution policy itself; the
decoder retains no second JSON-derived pin Boolean which could drift from the
policy, and activation does not inspect the contract. Neither choice launches
Z3. Neither grants proof, solver-status, or contract authority. There is no
automatic path, environment or executable discovery, or autoload behavior.
The explicit CLI loader uses the same 256-KiB bound before activation. The
optional digest remains only an expectation until live opening. V1--v16 compare
it with the pre-spawn pathname snapshot; v17--v20 compare it with the sealed
staged main image, still without loader, library, or solver attestation. The
complete schema and budgets are recorded in the
[bounded live Length ranking configuration-file report](docs/reports/2026-08-11-bounded-live-length-ranking-configuration-file.md).

The file decoder retains the sealed Djex execution configuration and evaluation
limits produced by their first validation pass. It assembles the reusable
opaque Leant policy directly from those authorities and retains the lazy fixed
contract beside it, instead of either resealing sources or introducing a
second generic configuration aggregate. Version 1 keeps that exact disabled
path and execution/evaluation/contract order. Additive version 2 validates an
exact `inputBoxValidation` object between evaluation and contract: its
`inclusiveInputMaximums` array is source ordered, capped at eight entries, and
itself supplies the input-width authority; `maximumAssignments` is capped at
65,536. The object is explicit, has no inferred or default box, and enables the
policy through `enableLengthRankingInputBoxValidation`.

Version 3 keeps the literal version-2 path unchanged and requires the same
`inputBoxValidation` object plus the closed root selection
`"counterexampleProbe": "origin-before-live"`. Its fixed decode order is
execution admission, execution, evaluation, input box, counterexample probe,
then the unchanged embedded version-1 contract. The field supplies only
permission for the query-owned all-zero replay after four MRU misses; it
contains no arity, vector, solver status, receipt, or verdict. Versions 1 and 2
reject the field, retain their exact ranking behavior, and never run the probe.

Version 4 preserves that complete operational grammar and order but replaces
the embedded scalar compatibility contract with the required closed pair
contract described above. The version is the domain selection; no independent
domain tag can disagree with it. Generalized decoding delegates versions 1--3
to their established decoder and wraps the resulting scalar contract without
changing old failure precedence. `activateLengthAssessmentConfiguration`
performs the same separate digest-policy decision for either domain and still
does not inspect the lazy contract or launch Z3.

Versions 5 and 6 are the scalar and pair positive-ordering successors. They
repeat versions 3 and 4's operational root and add the required exact field
`"boundedPositiveOrdering": "prefer-non-vacuous"`. Their fixed decode order is
exact root, execution admission, execution, evaluation, input box, origin
probe, bounded-positive ordering, then contract. Version 5 embeds the complete
scalar v5 contract grammar; version 6 embeds the same pair v5 grammar as
startup v4. The literal derives the opaque policy with
`enableLengthRankingNonVacuousInputBoxPreference`; it is permission for one
post-assessment stable ordering rule, not evidence, validation, or solver
authority. Existing versions reject the new field and retain their exact
ordering.

Versions 7 and 8 are the advanced scalar and pair successors. Their exact root
and fixed semantic validation order are `format`, `version`,
`executionAdmission`, `execution`, `evaluation`, `inputBoxValidation`,
`counterexampleProbe`, `boundedPositiveOrdering`,
`applicableDomainValidation`, `applicableDomainOrdering`,
`counterexampleSimplification`, `liveSessionOpening`, and `contract`. The
applicable-domain object requires exactly `"strategy": "positive-affine-v1"`,
`maximumInputs`, and `maximumAssignments`; the simplification object requires
the same two independent limits beside exactly
`"strategy": "componentwise-lexicographic-v1"`. Each width cap is 8 and each
assignment cap is 65,536. The other new literals are exactly
`"applicableDomainOrdering": "prefer-non-vacuous"` and
`"liveSessionOpening": "defer-until-live-query"`. V7 embeds scalar contract
grammar v5; v8 embeds the nominal pair grammar v5 and requires
`"resultShape": "binary-prod-spines-v1"`. The decoder constructs independent
opaque limits for all three bounded activities and demands the contract last.
The generalized decoder tries the unchanged v1--v6 dispatch first; those roots
reject every new field and still select eager opening.

Versions 9 and 10 are the shared-usable-work scalar and product successors.
They add the exact root field `usableWorkBudget` after `liveSessionOpening` and
before `contract`. That object contains exactly
`"strategy": "shared-usable-work-deadline-v1"` and a positive integer
`milliseconds` no greater than 65,000. The file decoder validates the complete
v7/v8 operational prefix first, then the strategy, integer/cap and Djex budget,
then the contract. It constructs the final opaque policy with
`enableLengthRankingUsableWorkBudget`. The generalized dispatcher attempts
this additive parser only after the unchanged v1--v8 chain reports its closed
unsupported-version sentinel, so every old success, diagnostic, schema and
identity stays literal.

Versions 11 and 12 are the relational positive-affine scalar and product
siblings of v7/v8. They reuse that exact root, field identities, caps, and
validation order, but require
`"strategy": "relational-positive-affine-v1"` in the applicable-domain object
and construct the policy with
`enableLengthRankingRelationalPositiveAffineApplicableDomainValidation`. They
do not admit `usableWorkBudget`; contract validation remains last, and the
generalized dispatcher reaches them only after the literal v1--v10 chain has
returned its closed unsupported-version sentinel. The distinct scalar and
product assessments and renderers expose only independently replayed bounded,
model/provider-relative evidence and grant no proof or pruning authority.

Versions 13 and 14 are the scoped-usable-work scalar and product successors.
They reuse v9/v10's exact root field set and budget diagnostic identities,
select v11/v12's relational positive-affine builder for the applicable-domain
field, and require the distinct budget strategy
`"scoped-checkpointed-shared-usable-work-deadline-v2"`. Validation performs
exact-root admission and the complete relational operational prefix first,
then the budget object's exact fields, strategy, positive integer and 65,000-ms
cap, then Djex validation, and finally the scalar-v5 or pair-v5 contract. The
generalized dispatcher reaches this parser only after v1--v12 have returned
their closed unsupported-version sentinel. The resulting policy uses
`enableLengthRankingScopedUsableWorkBudget`; file decoding and activation still
read no clock, launch no worker, and create no behavioral evidence.

Versions 15 and 16 are the strict-relational scalar and product successors.
They retain v13/v14's exact root fields, scoped-v2 budget object, budget
diagnostics, contract grammars, and validation order, but require
`"strategy": "strict-relational-positive-affine-v1"` in the applicable-domain
object and construct that dimension with
`enableLengthRankingStrictRelationalPositiveAffineApplicableDomainValidation`.
The generalized dispatcher reaches them only after the literal v1--v14 chain
has returned its closed unsupported-version sentinel. The policy remains
solver-independent: only complete replay of the derived finite box creates the
new nominal strict-relational receipt, and the scoped owner retains v13/v14's
cooperative lifecycle and failure boundary byte-for-byte.

Versions 17 and 18 retain that complete strict/scoped profile and append only
the required `"executableLaunch": "descriptor-bound-executable-v1"` member to
their exact execution object. The inherited execution fields are decoded in
their established order, then the launch literal is checked and Djex's
descriptor-bound execution constructor seals the policy. Evaluation, behavioral
policies, scoped budget, and nominal scalar-v5/pair-v5 contract follow in the
same order as v15/v16. The generalized dispatcher reaches these versions only
after the complete v1--v16 cascade returns UnsupportedVersion; v19/v20 are
handled only by the later quotient-consequence decoder. Decoding and activation
remain pure, and an all-pure deferred batch still opens no executable
descriptor or worker.

Versions 19 and 20 retain that exact descriptor/scoped root, execution object,
deferred lifecycle, preference and simplification policies, budget, and
contract grammars. They replace only the applicable-domain literal with
`"strict-relational-positive-affine-quotient-v1"` and construct that dimension
with
`enableLengthRankingStrictRelationalPositiveAffineQuotientApplicableDomainValidation`.
The generalized dispatcher reaches them only after the complete v1--v18
cascade returns UnsupportedVersion; version 21 is the next unsupported
sentinel. The new nominal assessment and renderer branches require complete
query-owned finite-box replay and add no solver, proof, or pruning authority.

`Leant.Synth.Length.Configuration.File.Acquire` is the compatibility facade
over the shared bounded `Leant.Synth.Length.File.Acquire` filesystem boundary.
Callers must explicitly
admit an absolute path of at most 4,096 characters and a positive timeout of
at most 60 seconds. On POSIX the final component is opened once with
no-follow, nonblocking, no-controlling-terminal, and close-on-exec flags; its
descriptor must report a regular file before any read. Strict reads stop at
the decoder's 262,144-byte maximum plus one, and only the still-disabled
configuration can escape. Errors retain closed phases, capped counts, and a
cleanup bit rather than paths, errno text, or file content. The timeout is an
interruption budget rather than a hard kernel deadline, final-component
no-follow does not exclude ancestor symlinks or in-place mutation, and Windows
fails closed until an equivalent native handle implementation exists. Main
uses `loadLengthAssessmentConfigurationFile` for its explicit startup CLI path;
the old `loadLengthRankingConfigurationFile` remains the scalar-only
compatibility entrance. There is
still no discovery or default path, and loading/activation alone never launches
a solver. See the
[bounded acquisition report](docs/reports/2026-08-11-bounded-live-length-ranking-configuration-acquisition.md).

`Leant.Synth.Length.Contract.File` adds the separate contract-only versioned
root with format `leant-finite-list-spine-length-contract` for a command-owned
passive contract. It contains exact `format`, `version`, and `contract` fields.
Version 1 delegates to the unchanged compatibility grammar. Version 2 uses the
same bounded parser owner and adds only positive-literal Natural modulo to
contract and provider-transfer expressions. Version 3 retains version 2's
expression grammar and additionally requires the exact ordered target-role
vector; versions 1 and 2 reject that field. Version 4 retains the v3 grammar
and requires the sole admitted candidate-case policy,
`exact-spine-zero-step-v1`; versions 1--3 reject that field. Version 5 retains
roles, modulo, and required explicit case choice; it accepts exactly
`cases-rejected` or `exact-spine-zero-step-v1` and alone adds positive-literal
Natural quotient. The established `decodeLengthContractFile` still accepts
exactly those scalar versions 1--5 and rejects version 6. The generalized
`decodeLengthContractSelectionFile` additionally admits v6's nominal pair
contract, while delegating every older version to that unchanged scalar
decoder. Execution and evaluation fields remain unknown and rejected. Startup
versions 1--3 retain scalar contract grammar version 1; startup v4 selects the
pair grammar, v5 selects full scalar grammar v5, and v6 selects the pair
grammar together with the explicit ordering preference.
Its `Contract.File.Acquire` facade uses the same path, descriptor, and timeout
owner as startup acquisition, but maps failures into contract-only closed
vocabulary. `Leant.Synth.Length.Command` recognizes only the exact
`--length-contract` spelling and requires a standalone `--`, so malformed
request syntax cannot disappear into Lean goal text.

`Leant.Synth.Length.Integration` authorizes an explicit request from the
already activated policy before Main admits or opens its contract path. The
result is an opaque command-local choice containing either the historical
disabled identity or one strict policy beside one lazy scalar-or-pair
selection. `LeanLengthContractSelection` is passive and nominal: dispatch
chooses exactly one scalar or pair occurrence-sealed assessor, and the two
ranking/evidence result types remain separate. Compatibility and one-shot
contracts enter the same lifetime owner; the request does not remember a
second policy/contract origin tag. Main loads a named contract once before
translating the goal and threads that value through every retry and synthesis
lane. It never writes the request to interactive state or a snapshot. See the
[one-shot contract report](docs/reports/2026-08-13-one-shot-length-contract.md).
The version-2 extension and its QF_LIA witness boundary are recorded in the
[contract-only v2 modulo report](docs/reports/2026-08-13-contract-only-v2-modulo.md).
The explicit role vocabulary, compact numbering, checked opaque-token boundary,
focused map path, and conditional Djex identities are recorded in the
[contract-only v3 target-role report](docs/reports/2026-08-13-contract-only-v3-target-roles.md).
The explicit exact-case policy, accepted-renderer association, production
Exference bridge, and fake-protocol model replay are recorded in the
[contract-only v4 exact-case report](docs/reports/2026-08-13-contract-only-v4-exact-spine-cases.md).
The positive-literal quotient grammar, policy-orthogonal case choice, shared
QF_LIA witness lowering, and production replay checks are recorded in the
[contract-only v5 quotient report](docs/reports/2026-08-13-contract-only-v5-quotient.md).

The passive finite-spine source vocabulary now lives in
`Leant.Synth.Length.Contract`. Modules that need only those assertions no
longer depend on the full synthesis engine. `Leant.Synth.Engine` owns neutral
synthesis and retained candidate provenance;
`Leant.Synth.Length.Handoff` derives the opaque verified origin and owns the
candidate-specific correspondence checks and Djex problem sealing. Ranking
reaches that preparation through `Leant.Synth.Length.Adapter` and imports the
handoff refusal taxonomy only for closed classification. This gives contract
assertions, candidate authority, checked domain preparation, and live
execution policy distinct source owners.

`Leant.Synth.PostVerification` makes the boundary after callback acceptance
explicit. Without the startup opt-in, Main sends the opaque, nominal
`VerificationBatch` through the exact non-strict disabled identity path, which
performs no IO, cannot start a worker, and claims no validated ordering
authority. With the opt-in, the Length assessor instead gives
`sealPostVerificationBatch` opaque occurrence handles minted from that batch
inside a rank-2 `PostVerificationInput` epoch. Handle constructors and original
indices are private, and nominal roles prevent coercion; handles from another
batch inhabit a different abstract epoch and cannot be mixed without an
explicit unsafe operation. The seal productively bounds the original handles
and proposals, then rejects every omission, duplicate, out-of-range occurrence,
or over-limit tail without comparing or forcing candidate payloads. Only
success can construct the opaque `PostVerificationBatch`, which therefore
carries a complete occurrence permutation rather than a pruned, duplicated,
manufactured, substituted, or reassociated candidate batch.

`Leant.Synth.Length.PostVerification` is the first domain adapter for that
boundary. The Length ranker now retains each receipt's safe original index;
package-private `Ranking.Internal` and `PostVerification.Internal` modules
thread each batch-scoped occurrence handle as the only receipt-bearing field
in transient ranking state through preparation, live assessment, stable
partitioning, atomic fallback, and the final seal. The
ordinary `Ranking` facade exports neither the associated plan nor its
projector, while the public configuration surface exports no associated
runner and its post-verification assessment entry points return only sealed
results. The deliberately retained association-free compatibility runners do
not claim presentation authority. The adapter runs one explicitly supplied
`LengthRankingPolicy` and contract, seals the returned handle order against the
exact input epoch, then retains that opaque batch as the accepted result's sole
verified-receipt owner. A bounded eager summary keeps only original indices,
assessment state, and the optional sanitized failure; the ordinary
receipt-bearing `LengthRanking` is materialized as a compatibility view from
that batch and summary only when projected. Policy callers may supply a
request-owned contract. Either startup bundle fixes its decoded compatibility
contract, while an exact
`:synth --length-contract ... --` request can reuse that activated policy with
one separately decoded command-local contract.
Input or proposal failure preserves the original opaque verification batch,
exposes no sealed output, and withholds the unsealed associated plan.
Operational ranking failure already
produces an original-order all-`Unassessed` ranking and passes through the same
seal. Main selects this path only for an explicitly loaded and activated
policy; without one, even an explicit command contract is rejected before file
IO and the historical no-option identity path is exact. Replayed
counterexamples may rank and receive a bounded model-relative note, and an
explicitly enabled complete finite-box traversal may receive a separate bounded
positive note with checked/applicable counts and visible vacuity. Neither can
prune or prove source behavior; raw `sat`, `unsat`, and `unknown` grant no proof
authority. See the
[post-verification assessment seam report](docs/reports/2026-08-11-post-verification-assessment-seam.md)
and the
[explicit integration report](docs/reports/2026-08-12-explicit-length-ranking-integration.md).

Three rules run through the design:

- **The engine is never trusted.** Every candidate is re-elaborated by
  the Lean backend against the exact goal (`example : (T) := term`)
  before you see it. An engine bug costs a dropped candidate, never a
  wrong answer.
- **Refusals come with reasons.** A goal outside the fragment is turned
  away with a note saying what fell outside, not quietly mangled into
  something answerable.
- **Negative verdicts are labeled by strength.** "Provably uninhabited"
  appears only when the translation was complete and lossless; anything
  weaker is reported as "no term found within bounds," which claims
  nothing.

Transcripts below are lightly abridged: `⋯` marks elided trailing
candidates (and, where applicable, a truncation note).

### Higher-order plumbing

The sweet spot is the "plumbing" terms one writes constantly. Free
capital identifiers are auto-bound, so quick queries stay quick, and
the first candidate is reliably the term you would have written —
here `flip`, composition, `uncurry`, and product associativity:

```text
λ> :synth ((a → b → c) → b → a → c)
  it1  fun f x y => f y x
λ> :synth ((b → c) → (a → b) → a → c)
  it1  fun f g x => f (g x)
λ> :synth ((A → B → C) → A × B → C)
  it1  fun f ⟨x, y⟩ => f x y
λ> :synth (((A × B) × C) → A × (B × C))
  it1  fun ⟨⟨x, y⟩, z⟩ => ⟨x, ⟨y, z⟩⟩
```

Candidates are ranked smallest-first and *bound into the session* as
`it1`, `it2`, …, with bare `it` the best one — they are ordinary
definitions, so you can evaluate them immediately:

```text
λ> :synth (a → a → a)
  it1  fun _ x => x
  it2  fun x _ => x
λ> #eval it2 "left" "right"
"left"
```

Read through propositions-as-types, the same plumbing proves logical
identities, and the proof terms *are* the plumbing: `Iff` symmetry is
a swap, `¬(p ∧ q) ↔ (p → ¬q)` is currying, and De Morgan's law packs
one direction each into an anonymous constructor:

```text
λ> :synth (∀ p q : Prop, (p ↔ q) → (q ↔ p))
  it1  fun _ _ ⟨f, g⟩ => ⟨g, f⟩
λ> :synth (∀ p q : Prop, ¬(p ∧ q) ↔ (p → ¬q))
  it1  fun _ _ => ⟨fun k x y => k ⟨x, y⟩, fun k1 ⟨z, w⟩ => k1 z w⟩
λ> :synth (∀ p q : Prop, ¬(p ∨ q) ↔ ¬p ∧ ¬q)
  it1  fun _ _ => ⟨fun k => ⟨fun x => k (.inl x), fun y => k (.inr y)⟩, fun ⟨k1, k2⟩ z => match z with | .inl w => k1 w | .inr x1 => k2 x1⟩
```

It reaches the textbook curiosities too — `(p ↔ ¬p) → False` comes
out by the classic self-application trick:

```text
λ> :synth (∀ p : Prop, (p ↔ ¬p) → False)
  it1  fun _ ⟨k, f⟩ => k (f (fun x => k x x)) (f (fun y => k y y))
```

Binders are named by role — functions `f g h`, values `x y z`,
negations and continuations `k` — which keeps large candidates
readable.

### Programs you already know

Some types have one sensible inhabitant, and asking for it by type is
quicker than remembering which library corner it lives in. The binds
of the reader and state monads:

```text
λ> :synth ((S → A) → (A → S → B) → S → B)
  it1  fun f g x => g (f x) x
λ> :synth ((S → A × S) → (A → S → B × S) → S → B × S)
  it1  fun f g x => match f x with | ⟨y, z⟩ => g y z
  it2  fun f g x => match f x with | ⟨y, _⟩ => g y x
  ⋯
```

For the state monad, `it1` threads the state correctly, while `it2`
is type-correct and runs `g` on the *initial* state — the classic
state-threading bug, which the type admits just as happily. Types alone
cannot tell these apart, which is why all candidates are shown and each
is one keystroke from a test run. With inductive expansion (below) the
same game extends to data — `Option.bind`, with the lazy `.none`
candidate ranked first and the real one second:

```text
λ> :synth (∀ a b : Type, Option a → (a → Option b) → Option b)
  it1  fun _ _ _ _ => .none
  it2  fun _ _ x f => match x with | .none => (.none) | .some y => f y
```

### Rank-N and impredicative goals

A polymorphic hypothesis is not just cargo: Djex instantiates it at
types the goal itself supplies — including, under a guard, at
*polymorphic* ones. Here the first candidate applies the identity
hypothesis to the whole goal `Q → Q`, an impredicative instantiation:

```text
λ> :synth ((∀ p : Prop, p → p) → Q → Q)
  it1  fun f => f _
  it2  fun _ x => x
```

A vacuous local provider can retain that closed quantified choice explicitly.
This matters when its result is an opaque Lean type: Leant keeps the result as
an ambient query parameter, while Djex supplies only the type argument already
present in the goal. Both engines now reach the application, and backend
verification selects the `Type _` universe hint needed by Lean's positional
`@` syntax:

```text
λ> axiom Demo.Token : Type
λ> :synth ((∀ x : Type, x → x) → ({a : Type 1} → Demo.Token) → Demo.Token)
  it1  fun _ x => @x (∀ (a0_0 : Type _), a0_0 → a0_0)
λ> :set synth-engine exference
synth engine: exference
λ> :synth ((∀ x : Type, x → x) → ({a : Type 1} → Demo.Token) → Demo.Token)
  it1  fun f x => f _ (@x (∀ (a0_0 : Type _), a0_0 → a0_0))
```

The search and rendering boundaries are recorded in the
[scoped quantified-provider report](docs/reports/2026-08-01-scoped-quantified-local-providers.md).

The bridge now preserves proper-type application spines too.  A bound
first-order constructor `F` stays a higher-kinded Djex variable, while an
opaque Lean family keeps one rigid nominal head across its occurrences.
That exposes the quantified argument to both engines without exposing the
family's implementation:

```text
λ> axiom Wrap : Type 1 → Type
λ> :synth ((∀ a : Type 1, Wrap a) → Wrap (∀ b : Type, b → b))
  it1  fun x => x _
λ> :set synth-engine exference
synth engine: exference
λ> :synth (∀ (F : Type 1 → Type), (∀ a : Type 1, F a) → F (∀ b : Type, b → b))
  it1  fun _ x => x _
```

The same transport now works without throwing away datatype structure.
`Option`, `Except`, and qualifying user inductives have complete constructor
schemas, while their exact Lean heads are shared across all proper-type
instantiations in one query. The provider-free engine tests exercise built-in
one- and two-parameter families through both engines. Standalone Exference now
tries an in-fragment goal without live providers first and asks Lean to verify
that baseline before it discovers an environment inventory. Djinn and `both`
now use the same provider-free ordering rule. The live golden
therefore exercises real `Option` through Exference as well as Djinn; separate
atomic and structural-miss controls confirm that a needed provider still wins
when the baseline is inapplicable, ends without a verified term, or soundly
refutes only the provider-free calculus:

```text
λ> inductive Demo.Phantom2 (a b : Type 1) : Type 1 where
…> | mk : Demo.Phantom2 a b
…>
λ> :set synth-engine exference
synth engine: exference
λ> :synth ((∀ a : Type 1, Option a) → Option (∀ b : Type, b → b))
  it1  fun x => x _
λ> :synth ((∀ a b : Type 1, Demo.Phantom2 a b) → Demo.Phantom2 (∀ x : Type, x → x) (∀ y : Type, y → y))
  it1  fun x => x _ _
λ> :set synth-engine djinn
synth engine: djinn
λ> :synth ((∀ a : Type 1, Option a) → Option (∀ b : Type, b → b))
  it1  fun x => x _
λ> :synth ((∀ a b : Type 1, Demo.Phantom2 a b) → Demo.Phantom2 (∀ x : Type, x → x) (∀ y : Type, y → y))
  it1  fun x => x _ _
```

Live polymorphic definitions now participate in Djinn's bounded
instantiation too. This ordinary Lean definition is discovered only after the
provider-free lane ends without a verified term (a bounded miss in this
example), then specialized independently at a closed built-in type, an opaque
session type, and a rank-N type:

```text
λ> def Demo.sealedBox {a : Type u} (value : a) : Demo.SealedBox a :=
…>   .mk value rfl
…>
λ> :set synth-engine djinn
synth engine: djinn
λ> :synth (Nat → Demo.SealedBox Nat)
  it1  Demo.sealedBox
λ> :synth (Demo.Seed → Demo.SealedBox Demo.Seed)
  it1  Demo.sealedBox
λ> :synth ((∀ x : Type, x → x) → Demo.SealedBox (∀ x : Type, x → x))
  it1  Demo.sealedBox
```

Vacuous type choices are retained when Lean needs to see them. Here the class
argument lies between the chosen type and the result, so Leant names the type
binder and leaves dictionary reconstruction to Lean:

```text
λ> axiom Demo.Token : Type
λ> class Demo.C (a : Type) : Prop where witness : True
λ> instance : Demo.C Nat := ⟨True.intro⟩
λ> axiom Demo.global {a : Type} [Demo.C a] : Demo.Token
λ> :synth (Nat → Demo.Token)
  it1  fun _ => Demo.global («a» := Nat)
```

Closed, context-free quantified choices follow the same path instead of
collapsing to an inferred `_`. Djex keeps their binders alpha-safe, and Leant
uses stable local names plus `_` binder domains so the provider's expected
universe remains authoritative:

```text
λ> class Demo.PolyC (a : Type 1) : Prop where witness : True
λ> instance : Demo.PolyC (∀ x : Type, x → x) := ⟨True.intro⟩
λ> axiom Demo.polyGlobal {a : Type 1} [Demo.PolyC a] : Demo.Token
λ> :synth ((∀ x : Type, x → x) → Demo.Token)
  it1  fun _ => Demo.polyGlobal («a» := (∀ (a0_0 : _), a0_0 → a0_0))
```

The choice need not occur in the query when Lean's active instance heads prove
it for that exact provider. Here the goal is only `Gap.Token`; discovery learns
the quantified argument by resolving `Gap.C ?a` against the active instance,
then both checked Djex runners retain the same explicit application:

```text
λ> axiom Gap.Token : Type
λ> class Gap.C (a : Type 1) : Prop where witness : True
λ> instance : Gap.C (∀ x : Type, x → x) := ⟨True.intro⟩
λ> axiom Gap.polyGlobal {a : Type 1} [Gap.C a] : Gap.Token
λ> :set synth-engine djinn
synth engine: djinn
λ> :synth Gap.Token
  it1  Gap.polyGlobal («a» := (∀ (a0_0 : _), a0_0 → a0_0))
λ> :set synth-engine exference
synth engine: exference
λ> :synth Gap.Token
  it1  Gap.polyGlobal («a» := (∀ (a0_0 : _), a0_0 → a0_0))
λ> :set synth-engine both
synth engine: both
λ> :synth Gap.Token
  it1  Gap.polyGlobal («a» := (∀ (a0_0 : _), a0_0 → a0_0))
```

The instance may determine a higher-kinded binder which never occurs in the
provider body. Leant retains the argument's bounded `Type -> ... -> Type` kind
instead of collapsing it to proper type, so both checked engines preserve this
constraint-only specialization:

```text
λ> namespace Higher
λ> axiom Wrap : Type → Type
λ> class VacuousChoice (F : Type → Type) : Prop where witness : True
λ> instance : VacuousChoice Wrap := ⟨True.intro⟩
λ> axiom VacuousToken : Type
λ> axiom vacuous {F : Type → Type} [VacuousChoice F] : VacuousToken
λ> end Higher
λ> :set synth-engine djinn
synth engine: djinn
λ> :synth Higher.VacuousToken
  it1  Higher.vacuous («F» := Higher.Wrap)
λ> :set synth-engine exference
synth engine: exference
λ> :synth Higher.VacuousToken
  it1  Higher.vacuous («F» := Higher.Wrap)
```

One exact provider may retain several distinct successful instance-head
vectors. In the same transcript, heads for `AlternativeChoice Wrap` and
`AlternativeChoice (Pair Nat)` produce exactly
`Higher.alternative («F» := Higher.Wrap)` and
`Higher.alternative («F» := (@Higher.Pair Nat))`. Standalone Djinn ranks
`Wrap` first, standalone Exference ranks `Pair Nat` first, and combined mode
uses Djinn's order after stable exact-spelling deduplication. The order is
engine policy; the semantic requirement is that every mode retain both exact
alternatives once. The transcript also carries one heterogeneous two-binder
vector with kind arities one and two, respectively, and requires
`Higher.multiVacuous («F» := Higher.Wrap) («G» := (@Higher.Triple Nat))` in
all three modes.

Extraction is deliberately finite and local. It opens at most six leading
type binders on one provider, retains the source instance constraints,
and inspects at most 32 active heads in Lean's resolver order. Each attempt is
state-isolated. The selected head remains fixed while its instance subgoals and
every other provider constraint are solved under the same metavariable context;
if any obligation or opened binder remains unresolved, that head contributes
nothing. A success contributes one complete vector in leading-binder order,
not a flat pool whose Cartesian product would lose the head's correlation.
For every argument, discovery also reduces its type to the admitted bounded
kind language and records the number of `Type`-arrow domains. Zero means
proper type; positive counts preserve bare and partially applied constructors.

At most 16 alpha-distinct vectors survive per provider, and Leant passes at
most 32 provider/vector associations in total. Every vector has exact provider
arity and at most six arguments. That aggregate prefix is taken before an
argument can affect family planning, rigidity, or type translation, so
evidence beyond the boundary is not entered. Live metadata uses
`(instantiations (args (kinded N ...) ...))`. A proper-kind live argument also
retains bounded structural rendering metadata as
`(kinded 0 (exact (domains prop type ...) FRAG))`. `FRAG` records source forall
visibility while the domain tags distinguish `Prop`, `Type`, and general
`Sort`, including mixed-domain rank-N types that cannot be reconstructed from
Djex's deliberately kind-erased syntax. The canonical translated type remains
authoritative for alpha-deduplication, kind/context checking, vector lookup,
and engine search. No executable Lean source crosses this boundary: the parser
accepts only the fixed domain vocabulary, requires one tag for every visible
forall in the fragment, and caps a vector at 128 tags. The metadata is used
only after the complete specified vector matches, and the backend still
elaborates and kernel-checks every resulting candidate.

The live wire uses the bounded semantic exact-context form for every supported
non-dependent provider instance binder. Exference retains that exact nominal
class head, its ordered bounded-kinded source-bound or ground-nominal arguments,
and body for plain and binder-only providers, and for an exact-evidence provider
when at least one fact group survives selection. A source-bound higher-kinded
argument may be the enclosing `FAll` variable either bare or partially applied
only to proper-type arguments. With no selected group, the exact-evidence
provider instead takes its successfully translatable bounded vectors through
the historical context-erased fallback. A dependent telescope or an
unsupported, open, or over-bound class application truncates and drops the
provider rather than erasing its premise into a stronger declaration. Djinn
always keeps its historical context-erased provider compatibility projection;
it neither owns the opaque Length carrier nor gains ground-fact authority.

Each provider occurrence whose complete visible vector matches retained exact
evidence receives a private render-time identity. One bounded metadata
alternative is then used consistently for both provider-result fitting and
final type-argument spelling;
two uses of the same canonical vector may choose different implicit\/explicit
source binders without pairing one choice's rendered type with another
choice's inserted placeholders. The established 32-selection prefix and
Cartesian cap still bound each rendering lane; if repeated occurrences expose
more individual alternatives than fit, source-earlier occurrences retain
priority and later occurrences keep their base selection. This occurrence-local
coupling is recorded in the
[provider metadata fitting report](docs/reports/2026-08-09-occurrence-local-provider-metadata-fitting.md).

For a context-free provider source, Leant reconstructs each Djex
`GroundKind` by folding that bounded arrow count into `FunctionKind` over
`ProperTypeKind`, pairs it with the translated type, and calls
`runDjinnQueryWithKindedInstantiationAssignments` or
`runExferenceQueryWithKindedInstantiationAssignments`. Exact contextual
Exference vectors whose fact groups survive the complete trial instead take
the ground-fact path below and never enter that adapter. If no group survives,
all successfully translatable vectors from the bounded, filtered list are
replayed through the historical context-erased adapter. Live discovery, wire
parsing, and engine filtering all admit at most 64 `Type`-arrow domains, whose
simple right-associated kind has `2 * 64 + 1 = 129` constructors. After an
assignment passes Djex's provider, scheme, context, and exact-arity checks, the
pinned adapters productively preflight all of that assignment's supplied kinds
before recursive kind inference, same-provider comparison, kind conversion, or
paired type elaboration. Oversized and cyclic caller-built kinds therefore fail
finitely. The historical `(candidates ...)` form and structural
`(kinded N ...)` payload remain readable, alongside metadata-free and
binder-only inventories. The parser retains legacy `(candidates ...)` as a
distinct compatibility provenance: its elements can remain unary search hints,
but its provider context is erased in both engine projections and it cannot
authorize an inventory class fact. Current exact
`(instantiations ...)` metadata may, after complete live active-instance
closure, instantiate the source scheme's leading constraints into deduplicated
zero-binder, zero-prerequisite ground facts. Those declarations are global to
the exact Exference/Length inventory and can discharge a matching obligation
activated by another provider because the Lean evidence came from the
top-level environment without query givens. Accepted facts follow all provider
values in stable provider/vector/constraint order. In Exference, vectors with
accepted contextual facts do not also enter Djex's historical context-free
assignment adapter. Once any group is accepted for one exact-evidence provider,
only that provider's selected vectors are replayed; rejected or non-ground
siblings do not re-enter the erased adapter. Exact-evidence providers with no
accepted group recover that erased fallback; an explicit empty exact evidence
block emits no fact and has no assignment to replay. Djinn's erased projection
keeps historical assignment behavior.

Provider-scheme and exact-assignment serialization may retain a bounded
contextual binder as `FExactContext`: the node records the exact nominal Lean
class head, each ordered argument's bounded ground-kind arity, and its body, so
Djex checks the context structurally and rendering restores the same Lean class
application. Proper arguments retain their full fragment. A higher-kinded
source argument may retain its enclosing `FAll` variable either bare or
partially applied only to proper-type arguments. A ground assignment argument
must instead retain a canonical bare or partially applied nominal head with
only proper-type supplied arguments; live discovery uses
`(kinded N (nominal "Head" ...))`. Historical fragment payloads remain readable
for compatible nonstructural heads, but their atom or application text does not
confer structural identity. Family planning uses supplied-plus-residual total
arity, and never mistakes the head for a proper rigid atom. A complete vector
still fails closed if any argument contains depth truncation (`FDepth`), a
legacy raw instance marker (`FInst`), or a malformed, open,
dictionary-dependent, term-indexed, or otherwise unsupported context. A
provider-root context is subject to the same fail-closed semantic checks.
Canonical nominal `Prod` and `Sum` are the structural exception: at total arity
two they map directly to Djex's boxed-pair and `Either` identities, so bare and
partially
applied forms can be consumed in provider bodies or retained in contextual
rank-N arguments. Legacy structural payloads do not gain that authority. The
implementation and live evidence are recorded in the
[higher-kinded contextual assignment report](docs/reports/2026-08-10-higher-kinded-contextual-assignments.md).
Before planning, conflicting class-kind or nominal-family arity claims discard
only the assignment vectors that touch that identity; unrelated sibling vectors
remain usable.
Provider-prefix lanes slice the metadata with its declaration, and Djex
resolves every vector by the exact private provider name, so a later or
alpha-identically typed provider cannot donate a specialization to an earlier
one. This provider-local assignment rule is distinct from the inventory-global
scope of a derived ground class fact.

Canonical `Prod` and `Sum` assignments are supported at total arity two,
including bare `Prod`/`Sum` and partial `Prod A`/`Sum A`. Unsaturated `And`,
`PProd`, `Or`, `PSum`, `Iff`, and `Not` remain excluded because the ground-kind
wire does not retain their Prop/sort distinctions. Saturated uses retain their
ordinary structural translation, and legacy structural payloads remain
fail-closed.

The dedicated
[`synth-quantified-provider`](test/synth-quantified-provider.txt) transcript
checks both the query-supplied and provider-only paths under standalone Djinn,
standalone Exference, and combined search. The dedicated
[`synth-provider-contextual-assignment`](test/synth-provider-contextual-assignment.txt)
transcript isolates the structured-context extension: its only active head
selects `∀ {a : Type}, [Inhabited a] → a → a`, and all three modes must render
and verify that exact contextual named argument. This remains bounded,
evidence-directed rank-N/impredicative support, not general impredicative
inference. Only closed, structured nominal class contexts from exact assignment
discovery or a supported provider source cross the bridge; open or unsupported
contexts and legacy `FInst` payloads fail closed rather than being guessed into
Lean syntax. Ordinary goal serialization remains unchanged, while the
Exference provider projection preserves supported contexts rather than erasing
them. See the
[contextual provider-assignment report](docs/reports/2026-08-09-contextual-provider-assignments.md).
The
[`synth-provider-implicit-visible-result`](test/synth-provider-implicit-visible-result.txt)
transcript covers the complementary exact-metadata path. It requires standalone
Djinn, standalone Exference, and combined mode to select a provider at the
mixed type `∀ {P : Prop} (A : Type), P → A → Result`, preserving the
implicit `Prop` binder and explicit `Type` binder. Exference and combined mode
also project that assigned type from a provider result and apply it under a
quantified goal; Lean verification checks the rendered specialization rather
than a string-only fixture. Its second namespace supplies two instance-selected
types with one canonical Djex fragment but swapped `Prop`/`Type` domains, puts
the wrong rendering first, and requires all three modes to fall through to the
kernel-valid alternative. The
[`synth-provider-metadata-fitting`](test/synth-provider-metadata-fitting.txt)
transcript additionally makes rendering and result fitting inseparable. Its
first instance contributes the canonical type with an implicit forall, while a
second instance contributes the same Djex type with an explicit forall. The
goal forces the explicit selection, and the provider consumes a value at that
selected type; Exference and combined mode must therefore render both the
explicit provider argument and `fun _ x => x`. Lean verifies that result at a
64-step search bound. The
[`synth-provider-higher-kind-assignment`](test/synth-provider-higher-kind-assignment.txt)
transcript separately requires the mixed kinded/rank-N vector and the exact
vacuous and heterogeneous multi-vacuous applications under Djinn, Exference,
and combined search. It also requires the two distinct `Wrap` and `Pair Nat`
applications of one provider exactly once, while allowing the engines to rank
them differently. Unit regressions pin the kinded wire format, kind/order
retention, whole-vector deduplication, finite bounds, and the same successes in
all three engine modes. The current exact-vector contract is recorded in the
[correlated instance-head assignment report](docs/reports/2026-08-05-correlated-instance-head-assignments.md);
the earlier scalar API remains documented in the
[provider-local instance-head report](docs/reports/2026-08-05-provider-local-instance-head-evidence.md).
The focused
[`synth-provider-structural-assignment`](test/synth-provider-structural-assignment.txt)
transcript discovers `Prod` and partial `Sum` assignments from real Lean
instances. It makes a provider consume their saturated forms and separately
retains both heads inside a closed contextual rank-N argument under Djinn,
Exference, and combined mode; every displayed result is checked by Lean 4.31.

Djinn first searches with only the highest-ranked provider, which prevents a
lossily projected or irrelevant declaration from crowding the fixed candidate
prefix. If that isolated candidate does not verify, Leant tries the first four
and first sixteen providers before the full bounded inventory. These sparse
prefixes preserve discovery order while reaching small compositions before
unrelated declarations can displace them from Djinn's candidate window. In
`both` mode, only the singleton and full lanes rerun Exference; intermediate
prefixes are Djinn-only. The exact live transcript deliberately places an
unrelated class-constrained provider before a two-provider composition and
verifies that the width-four lane recovers
`Demo.consume (Demo.produce x)`. It also covers an atomic provider,
provider-free first-result ordering, and combined-mode reuse.
It is checked in
[`synth-djinn-providers`](test/synth-djinn-providers.txt).

The separate
[`synth-both-frontier`](test/synth-both-frontier.txt) transcript pins the
combined quota end to end. Seven distractor types make the first 12 rendered
groups fail Lean's class-instance check; the 24-group lane reaches and verifies
`Demo.global («a» := Demo.Good)` beyond that former cap.

Only application arguments whose own type is a universe take the retained
proper-type path. A non-inductive term-indexed family such as `P 3` remains a
single opaque atom. An inductive with term or dependent parameters keeps the
older occurrence-local representation when its constructor shape is safe;
it is never silently conflated with the proper-type family projection. An
opaque nominal application also remains unsafe for negative evidence: its
hidden Lean constant can help find and verify a term, but can never justify a
refutation.

And a Church-encoded pair converts into a real conjunction — the
quantified hypothesis is instantiated once at `p` and once at `q`, fed
the matching projection each time:

```text
λ> :synth (∀ p q : Prop, (∀ r : Prop, (p → q → r) → r) → p ∧ q)
  it1  fun _ _ f => ⟨f _ (fun x _ => x), f _ (fun _ y => y)⟩
  ⋯
```

Djinn now keeps three instantiation families distinct. The historical local
family specializes context-free hypotheses at query variables, opened
skolems, premise scopes, and guarded quantified shapes. A new final
query-closed tail additionally admits closed, forall-free subtrees already
present in the checked goal, but only for schemes embedded in that goal.
Loaded environment schemes remain a third family: they retain exact source
identity and may also use closed subtrees from loaded signatures.

That distinction makes the following provider-free Lean goal reachable without
pretending that <code>Mono</code> is a type variable:

~~~text
λ> axiom QueryClosed.Mono : Type
λ> axiom QueryClosed.Token : Type
λ> axiom QueryClosed.Indexed : Type → Type
λ> :synth ((∀ a : Type, (a → QueryClosed.Token) → a →
…>     QueryClosed.Indexed a) → (QueryClosed.Mono → QueryClosed.Token) →
…>     QueryClosed.Mono → QueryClosed.Indexed QueryClosed.Mono)
  it1  fun f => f _
  it2  fun f g x => f _ (fun _ => g x) x
~~~

Both Djinn terms instantiate <code>f</code> at the exact closed query type
<code>QueryClosed.Mono</code>; the second merely chooses a different valid
callback. Standalone Exference returns the compact
<code>fun f =&gt; f _</code>, and combined mode retains both Djinn
spellings. The
[<code>synth-query-closed-rankn</code>](test/synth-query-closed-rankn.txt)
transcript turns live-library premises off and checks all three modes through
final Lean 4.31 elaboration with Exference bounded to 128 steps. The pure
boundary test does the same below the REPL layer.

The new Djinn family is appended after every established structural, provider,
and loaded-scheme family, so historical candidate prefixes do not move. Its
plan carries the established local, loaded, and caller-supplied provider
premises, allowing those capabilities to compose in one proof. It retains the
same six-binder eligibility, 16 axioms per scheme, 64 axioms per family, and
512 tuple attempts. It is positive-only: exhausting this incomplete tail is
<code>NoEvidence</code>, never a proof of uninhabitability.

Context-free hypothesis chains now reach six leading binders. Leant inserts
all six inferred type arguments, and Lean 4.31 verifies a non-lexical
source-order application of an abstract six-argument constructor:

```text
λ> axiom SixBinder.Six : Type → Type → Type → Type → Type → Type → Type
λ> :synth (∀ A B C D E F : Type, (∀ a b c d e f : Type, SixBinder.Six a b c d e f) → SixBinder.Six F E D C B A)
  it1  fun _ _ _ _ _ _ x => x _ _ _ _ _ _
```

Explicit `∀` binders — leading, nested, trailing, or interleaved — are
woven into the candidate's lambda automatically, and uses of quantified
hypotheses get placeholder type arguments wherever Lean needs them
(`f _ x`), so bounded rank-N candidates verify. Chains with seven or more
leading binders remain outside Djinn's fixed instantiation bound. Full
impredicative inhabitation is undecidable, so Djinn uses a deterministic
bounded plan family rather than a power set. Its singleton, pairwise, triple,
quadruple, and quintuple open/opaque frontiers cover every choice across eleven
independent quantified sites. Quintuple selections are edge-balanced and
capped at 512 plans per orientation; this retains all 252 ten-site and 462
eleven-site choices while bounding larger queries. A twelve-site goal needing
exactly six open and six opaque sites is the next deliberate occurrence-plan
gap. Beyond either that occurrence bound or the separate six-binder
instantiation guard, the answer is "no term found within bounds" and nothing
stronger.

The dedicated
[`synth-six-binder-rankn`](test/synth-six-binder-rankn.txt) transcript
disables live-library premises and pins that exact candidate through final
Lean elaboration under standalone Djinn, standalone Exference, and combined
mode. The same golden first discovers a six-binder active-instance assignment
and retains all six named quantified applications in every mode. Unit coverage
separately retains the six-argument function-elimination shape and exact
provider evidence across the same three engines. The earlier
[`synth-five-binder-rankn`](test/synth-five-binder-rankn.txt) transcript remains
as the historical predecessor.

The live
[`synth-quartic-rankn`](test/synth-quartic-rankn.txt) transcript makes the new
engine boundary observable, but its Lean surface binder count is not its Djex
quantifier count. After the four outer `FAll` binders for `Q`, `R`, `Z`, and
`M`, each vacuous `forall A B C D E : Type, Q`-shaped component crosses the
serializer as five ordinary arrows from the shared opaque `Type` atom to its
codomain, not as another `FAll`; those four schemes therefore do not exercise
the hypothesis-instantiation guard. Among the eight result
leaves, only the four identity leaves stay quantified. Djex `f3dd2495`
introduced the two cooperating Exference paths; its quartic follow-up,
`c0c1a461`, adds tuple-goal provenance that permits the eager
whole-tree shortcut once per independently scheduled structural route. Nested
fields emitted by the shallow alternative stay on that lane, preventing
recursive rediscovery of equivalent structural trees while preserving scoped
or environment product reuse at arbitrary depth. Standalone Djinn, standalone
Exference, and combined mode all return the direct nested-product term.
Exference does so at the unchanged 4096-step/1024-queue bounds, and its
independently checked candidate is admitted at search step 30. The live run
nevertheless continues along its bounded ranked tail and reports
`queue limit pruned 36475` when the step limit is reached; that note records an
incomplete tail, not a failure to find or check the displayed candidate.

The live
[`synth-quintic-rankn`](test/synth-quintic-rankn.txt) transcript is the exact
non-vacuous successor. Its `QuinticRankN.Wide` abbreviation is
`forall A B C D E F G : Type, A × B × C × D × E × F × G`, so all seven
binders survive as adjacent `FAll` nodes. Leant `378f866` projects each
uninterrupted `FAll` spine to one Djex `ForallType` binder list, without
crossing an `FInst`; the original
fragment still owns every explicitness slot used for Lean rendering. Thus one
`Wide` is one positive-forall occurrence site rather than seven nested sites.
With Djex `d728719f`, the first live goal requires a non-prefix five-opaque /
five-open selection across ten sites, and the second requires the separate
five-open / six-opaque dual across eleven. Leant `80f123a` records the direct
Djinn terms accepted by Lean 4.31 for both goals. Neither run is truncated.
The sentinel is now seven-binder so the same occurrence-planning witnesses
remain outside Djinn's independent six-binder instantiation cap.

Instance-implicit goal binders keep a separate render-only position. The
engines remain dictionary-independent, while Leant inserts the wildcard that
prevents the next synthesized lambda binder from being mistaken for the class
instance. Uses of a constrained rank-N hypothesis leave its nested instance
argument implicit, so Lean reconstructs the evidence during verification:

```text
λ> :synth (∀ (A R : Type) [Demo.C A], (∀ (a : Type) [Demo.C a], a → R) → A → R)
  it1  fun _ _ _ f => f _
```

Because erased dictionary evidence can carry proof power, its presence also
makes an otherwise empty Djinn search inconclusive rather than a refutation.
The live regression runs this goal under Djinn, Exference, and `both` in
[`synth-instance-implicit`](test/synth-instance-implicit.txt).

### Impossibility, proved

When Djinn's complete search exhausts a fully translated goal, failure
is a theorem — an answer no failing tactic gives you:

```text
λ> :synth (∀ a b : Type, Option a → b)
provably uninhabited — no closed term of this polymorphic type exists
```

The wording is careful: the verdict is about *closed terms of the
polymorphic type* (instantiate `b := Option a` and `id` inhabits it),
and in `Prop` it is about *constructive* provability. When the
translation had to hide structure behind an opaque atom, the verdict
backs off to "no term found within bounds". The proof is complete for the
provider-free structural calculus, but it is only a fallback with respect to
the live Lean environment. Leant still runs its bounded constructive provider
lanes, and the first candidate that Lean verifies wins. If provider discovery
is empty or unavailable, times out, or yields no verified candidate, Leant
restores the original proof-backed refutation. Provider discovery is
intentionally bounded and best-effort, so that verdict is not an exhaustive
claim about every axiom or declaration in the environment.

The focused
[`synth-provider-refutation-fallback`](test/synth-provider-refutation-fallback.txt)
transcript makes that ordering observable. Exact live rank-N providers override
the provider-free refutation under Djinn, Exference, and `both`; an exact
constructive proof of a Peirce-shaped goal wins while classical fallback is
enabled; and a no-provider control preserves the original sound verdict. Pure
engine tests separately pin a direct provider override, an empty-family
rank-N assignment, and retention of refutation for an unusable provider.

### Classical candidates

After those constructive provider lanes fail, refuted `Prop` goals get a
classical attempt
(disable with `:set synth-classical off`): first with an
excluded-middle case split per atomic subformula, then via the Glivenko
double-negation translation wrapped in `Classical.byContradiction`.
Peirce's law has no constructive inhabitant — `:synth` proves that,
then answers the classical question with a term whose spelling shows
exactly what was used:

```text
λ> :synth (∀ p q : Prop, ((p → q) → p) → p)
  it1  fun _ _ f => match Classical.em _ with | .inl x => x | .inr k => f (fun y => absurd y k)
  ⋯
λ> :set synth-classical off
synth classical: off
λ> :synth (∀ p : Prop, p ∨ ¬ p)
provably uninhabited — no closed term of this polymorphic type exists
(constructively — a classical proof may still exist; this is not a disproof of the proposition)
```

The hard direction of De Morgan needs excluded middle twice, once per
disjunct, and the candidate reads as exactly that case analysis:

```text
λ> :set synth-classical on
synth classical: on
λ> :synth (∀ p q : Prop, ¬(¬p ∧ ¬q) → p ∨ q)
  it1  fun _ _ k => match Classical.em _ with | .inl x => .inl x | .inr k1 => (match Classical.em _ with | .inl y => .inr y | .inr k2 => absurd ⟨k1, k2⟩ k)
```

### Inductive types

A non-recursive, non-indexed inductive or structure — built-in
(`Bool`, `Option`, `Ordering`, `Except`, `Decidable`, …) or
session-declared — expands into a generalized sum of products:
constructors become introduction rules, case analysis the elimination
rule, and candidates render with the real constructor names. When all applied
parameters are proper types, Leant also retains the exact family head and
ordered parameter vector. A query-wide pre-scan validates one shared
parameterized declaration, so rank-N transport no longer requires choosing
between nominal identity and useful constructor structure.
`Except.map`, synthesized rather than remembered:

```text
λ> :synth (∀ e a b : Type, Except e a → (a → b) → Except e b)
  it1  fun _ _ _ x f => match x with | .error y => .error y | .ok z => .ok (f z)
```

It extends to `Type`-valued classes-as-data like `Decidable`, where the
instance combinators write themselves — decidability of implication,
by case analysis on both instance arguments:

```text
λ> :synth (∀ p q : Prop, Decidable p → Decidable q → Decidable (p → q))
  it1  fun _ _ x y => match x with | .isFalse k => .isTrue (fun z => absurd z k) | .isTrue w => (match y with | .isFalse k1 => .isFalse (fun f => k1 (f w)) | .isTrue x1 => .isTrue (fun _ => x1))
note: search truncated: candidate limit reached (60)
```

Session-declared types participate the moment you declare them, and
refutations over expanded inductives stay sound — the engine saw the
complete constructor list:

```text
λ> structure Pair (A B : Type) where
…>   fst : A
…>   snd : B
…>
λ> :synth (∀ a b : Type, a → b → Pair a b)
  it1  fun _ _ x y => ⟨x, y⟩
λ> :synth (∀ a b : Type, Pair a b → Empty)
provably uninhabited — no closed term of this polymorphic type exists
```

Fixed constructor fields are not mistaken for family parameters. Here
`Demo.Secret` becomes one private rigid proper type inside the engine, while
the varying `a` remains the parameter of `Demo.Guard`; both engines can still
transport the whole family at an impredicative argument:

```text
λ> axiom Demo.Secret : Type
λ> inductive Demo.Guard (a : Type 1) : Type 1 where
…> | mk : Demo.Secret → a → Demo.Guard a
…>
λ> :synth ((∀ a : Type 1, Demo.Guard a) → Demo.Guard (∀ b : Type, b → b))
  it1  fun x => x _
```

Sharing is conservative and independent of traversal order. Every occurrence
of an exact head in the goal, caller premises, and usable live providers
must agree on arity and on one generic constructor schema. Repeated or
otherwise ambiguous parameter vectors may borrow a template from a later,
unambiguous occurrence only when specialization reproduces every inventory.
If no unique compatible template exists—or the same head also arrived through
an opaque nominal fallback—the whole head becomes one shared abstract family.
Transport can still succeed, but constructors and cases are withheld, and
Djinn cannot turn search exhaustion into a refutation. Unsafe atoms in caller
premises likewise forfeit negative evidence. Exference never makes negative
claims, and every positive candidate from either engine is still checked by
Lean. A contradictory arity for one exact Lean head is rejected outright
rather than abstracted or conflated.

Recursive proper-type applications now receive the same query-wide exact-head
identity discipline, with a recursive-specific schema check. This lets both
engines transport a quantified family value directly to a supplied
impredicative parameter—for example, the verified answers to a base-less
`RecBox` query include `fun x => x _`; standalone Exference now also verifies
the constructor-shaped `fun x => ⟨fun _ y => y, x _⟩`. Recursive self fields
are normalized to the generic applied family before schemas are compared, so
`List a` and `List b` can validate one recursive knot even though Lean
serialized different display keys.

The available structure remains intentionally asymmetric. When every reachable
occurrence has a complete, compatible schema and a pairwise-distinct parameter
vector yields a closed template that fits every observed occurrence, both
engines receive one shared native recursive declaration. A plain-variable
vector is direct generic evidence; a structured vector is only a speculative
positive approximation because the serialized fields lack declaration-level
parameter provenance. Every resulting term is re-elaborated by Lean, and the
approximation supplies no negative evidence. Djinn may introduce one
constructor layer from each of at most two independent recursive SCCs on a
positive logical path, but it cannot eliminate recursive inputs; Exference may
inspect one constructor layer, whose recursive fields become ordinary
branch-local values and are not immediately split again. It first preserves
the established all-inputs-used candidate prefix and tries the omission lane
only after a miss. Partial inventories, unresolved repeated parameters,
structured templates that fail the closure/fitting checks, incompatible
schemas, and nominal collisions all choose one shared abstract exact family;
their occurrence constructors remain introduction premises, but no `match` is
exposed, and Djinn search exhaustion is not promoted to a refutation. Indexed
(`Eq`) and dependent-field (`Exists`)
types remain opaque. The main impredicative gain is direct family transport,
not recursion or induction.

### Recursion from the library

`:synth` will never invent a `Nat.rec`-based program, but it does not
have to: for the everyday recursive types, the library already wrote
the recursion. A goal that mentions `List` or `Nat` brings a rated
inventory of library functions with it (`List.map`, `List.foldr`,
`List.append`, `List.flatten`, `List.length`, `List.replicate`,
`Nat.add`, …), instantiated at the goal's own types and handed to the
engine as extra premises — the phase-3 promise of *recursion via
library reuse*, in miniature. The enumeration prefers proofs that use
the goal's own arguments, generally putting the direct library answer
first while retaining distinct choices between same-typed arguments:

```text
λ> :synth ((a → b) → List a → List b)
  it1  fun f x => List.map f x
  it2  fun f x => List.reverse (List.map f x)
  ⋯
λ> :synth (List (List a) → List a)
  it1  fun x => List.flatten x
  it2  fun x => List.reverse (List.flatten x)
  ⋯
λ> :synth (List a → Nat)
  it1  fun x => List.length x
  it2  fun x => Nat.add (List.length x) (List.length x)
  ⋯
λ> :synth (Nat → a → List a)
  it1  fun x y => List.replicate x y
  ⋯
λ> :synth (List a → List b → List (a × b))
  it1  fun x y => List.zip x y
  ⋯
λ> :synth ((a → b → c) → List a → List b → List c)
  it1  fun f x y => List.zipWith f x y
  ⋯
λ> :synth (List a → List a → List a)
  it1  fun x _ => x
  it2  fun _ x => x
  it3  fun x _ => List.reverse x
  it4  fun x y => List.append x y
  it5  fun x y => List.append y x
```

The inventory is a ratings list in Djex's `*.ratings` format — lower
is better, 100 or more disables — and a project file `leant.ratings`
(lines of `Name Rating`, `#` comments) merges over the defaults at
startup, so re-ranking, disabling, or growing the inventory is
editing a list, not writing code.

The library search runs beside the plain constructor search, and its
candidates come first — they are found in a mode where the recursive
occurrences are sealed atoms, so every candidate must route through
the goal's own arguments and the offered functions rather than
through constructor junk (`List.nil` inhabits every `List` goal; a
search that may use it drowns in closed terms that ignore the
input). Both searches' candidates are verified and shown together,
and `:set synth-library off` restores the constructors-only
behavior. Negative verdicts are unaffected: goals that mention a
recursive inductive already report "no term found within bounds"
rather than a refutation, and the library run never contributes a
negative verdict at all.

### Dependent formulas as cargo

Dependent subformulas (`∀ n : Nat, P n`) are carried as opaque atoms,
compared up to α-equivalence: transportable, never analyzed.

```text
λ> opaque P : Nat → Prop
λ> opaque Q : Prop
λ> :synth ((∀ n : Nat, P n) ∧ Q → Q ∧ (∀ n : Nat, P n))
  it1  fun ⟨x, y⟩ => ⟨y, x⟩
```

The engine never looked inside `∀ n, P n`; it swapped a sealed box. A
goal that would require opening the box — an induction, a rewrite, a
case split on an index — is refused with a reason; that work belongs to
`:prove`.

### Synthesis inside a proof

Bare `:synth` in prove mode targets the current goal *with its
hypotheses as premises*, and `itN` splices the candidate applied to
those hypotheses, so `exact it1` closes the goal:

```text
λ> :prove ∀ p q : Prop, (p → q) → p → q ∧ p
entering prove mode — type tactics; :help for commands
⊢ ∀ (p q : Prop), (p → q) → p → q ∧ p
suggestion: exact fun p q a a_1 => ⟨a a_1, a_1⟩  (closes the goal)
⊢> intro p q h hp
p q : Prop
h : p → q
hp : p
⊢ q ∧ p
suggestion: exact ⟨h hp, hp⟩  (closes the goal)
⊢> :synth
(synthesizing with hypotheses p q h hp as premises)
  it1  fun _ _ f x => ⟨f x, x⟩
⊢> exact it1
All goals accomplished 🎉
finish with :qed [NAME], inspect with :script
⊢> :qed mp_and
saved: theorem mp_and : ∀ p q : Prop, (p → q) → p → q ∧ p
```

Unlike `exact?`, which finds an *existing* lemma, this composes a new
term from the goal's own material — a constructive complement to the
finisher tactics, needing no premise database and no imports. Bare
`:synth` outside prove mode targets the last `sorry`.

The classical fallback follows you into prove mode: double-negation
elimination has no constructive proof, so `:synth` offers the
excluded-middle case split, and `:qed` turns it into a theorem —
proved, verified, and named without writing a single tactic beyond
`exact`:

```text
λ> :prove ∀ p : Prop, ¬¬p → p
entering prove mode — type tactics; :help for commands
⊢ ∀ (p : Prop), ¬¬p → p
suggestion: exact fun p a => Classical.byContradiction a  (closes the goal)
⊢> :synth
  it1  fun _ k => match Classical.em _ with | .inl x => x | .inr k1 => absurd k1 k
⊢> exact it1
All goals accomplished 🎉
finish with :qed [NAME], inspect with :script
⊢> :qed not_not_elim
saved: theorem not_not_elim : ∀ p : Prop, ¬¬p → p
```

### Engines, budgets, and the fine print

- Library premises are on by default (`:set synth-library on|off`);
  the rated inventory (defaults merged with `leant.ratings`) only ever
  *offers* premises — the driver filters them against the goal's own
  types and the backend verifies every candidate, so a useless entry
  costs search time, never soundness. The ratings file is read at
  startup; edits take effect next session.
- A second engine is available: `:set synth-engine exference` switches
  to Djex's ranked heuristic search (explicit budgets, no negative
  verdicts; `:set synth-steps N` bounds it, default 4096), and `both`
  runs the two together. Standalone lanes send at most 12 fresh candidate
  groups to Lean; a combined lane gets 24 and preserves both standalone
  frontiers. Writing `D` and `E` for fresh Djinn and Exference groups, its
  order is `D1–D4, E1–E12, D5–D12`, followed by alternating tails.
  Within each Exference invocation, Leant stable-deduplicates rendered groups
  before applying the internal 60-candidate collection window. The first
  spelling remains authoritative, while repeated backend derivations cannot
  consume slots ahead of later distinct terms; the outer 12/24-group
  verification frontiers then apply as above. Combined exact-text deduplication
  likewise keeps the first display occurrence. If that occurrence has no typed
  authority, the exact spelling may lazily retain the first bounded later
  Exference origin solely for checked behavioral preparation; route metrics,
  ordinals, sibling variants, and displayed order do not change.
  Refutations still come only from Djinn. The default `djinn` remains the
  complete, terminating LJT search.
- Every engine mode gives a structurally accepted goal a provider-free
  baseline lane. Its rendered candidates are checked by Lean first, and live
  providers are discovered whenever no baseline term verifies. A complete
  Djinn refutation is retained provisionally while the constructive provider
  lanes run: the first Lean-verified provider candidate wins, while empty,
  unavailable, timed-out, or unsuccessful provider search restores the
  proof-backed refutation. Only then does the explicit classical fallback run.
  Provider-eligible atomic/refused goals go directly to provider search.
  Djinn first isolates the highest-ranked provider, then widens through the
  first 4 and 16 providers before the full bounded inventory after verified
  misses; Exference keeps its internally rated full-inventory lane. Combined
  mode runs both engines for the singleton and full lanes but uses Djinn alone
  for the intermediate prefixes. All lanes consume one command-wide
  `LEANT_SYNTH_TIMEOUT` deadline. Before a later lane is forced or capped,
  spellings that already failed Lean are removed from each source stream and
  newly empty groups are dropped. Rediscovered failures therefore consume no
  fresh quota. This policy
  deliberately favors a structural solution over breadth: provider
  alternatives are not enumerated after a baseline term succeeds. See the
  dated
  [provider-isolation report](docs/reports/2026-08-01-provider-isolated-exference-baseline.md).
- When an engine needs live values, Leant takes a bounded inventory from the
  live Lean environment. It considers constants under namespaces named
  by the target, plus exact declarations from the current session;
  rejects generated names; prioritizes exact-result session and public
  declarations before unrelated session values; and serializes at most
  80 term providers. Declarations whose fully peeled result is a sort
  (type constructors and type families) are excluded before search.
  Conventional implementation workers ending in `TR`,
  `Impl`, or `Aux` (or a `.go`/`.loop` component) remain eligible but
  move behind public fallbacks; exact user-session declarations always
  bypass that spelling heuristic. Exference assigns increasing positive
  penalties in this order, while Djinn receives the sparse-prefix schedule
  above. Thus a
  target such as `(α → β) → List α → List β` can reuse
  `List.map` instead of rebuilding recursion from scratch.
- The goal serializer also supplies a canonical provider query: the
  target's sorted, deduplicated root namespaces and its final result
  head. Leant keys a generation-aware, 12-entry LRU by that semantic
  query rather than by raw goal text. Successful empty inventories are
  cached too; discovery failures are not. Any operation that can change
  imported or session declarations advances the generation and clears
  the cache, while generated `it1`, `it2`, … bindings are excluded from
  provider discovery and deliberately preserve it.
- Providers receive collision-free private names inside Djex. Rendering
  maps those names back to the exact fully-qualified Lean globals before the
  backend verifies the candidate. Live discovery also retains the source names
  of leading type binders. When Djex makes a vacuous specialization
  visible, Leant renders a named argument such as
  `Demo.global («a» := Nat)`; intervening instance binders stay implicit and
  Lean reconstructs their dictionaries. Historical caller-owned inventories
  without binder metadata retain the positional `@` fallback. Inventory
  extraction is deliberately best-effort: if it cannot be produced, each
  engine still runs with the structural declarations it already has.
- For an exact polymorphic provider whose source constraints can determine its
  visible type arguments, discovery may attach active-instance-head evidence.
  It opens at most six type binders and inspects at most 32 heads in
  resolver order under isolated metavariable state. A selected head is retained
  only after its own subgoals and every remaining provider constraint close;
  one success yields one ordered vector of kind/type pairs, and incomplete
  heads yield nothing. Each argument retains a bounded `Type`-arrow kind. For a
  context-free provider source, Leant reconstructs the corresponding Djex
  `GroundKind` and sends the vector through the checked kinded Djinn or
  Exference assignment entry point; contextual Exference vectors with accepted
  fact groups instead authorize only the replay-isolated ground-fact path
  below, while a no-group exact-evidence provider takes its successfully
  translatable bounded vectors through the erased fallback. Leant
  rejects residual kind arities above 64 before that bridge, and pinned Djex
  independently rejects a supplied `GroundKind` above 129 constructor nodes
  before recursive operations on that assignment. At most
  16 distinct vectors survive per provider. `FDepth` and legacy raw `FInst`
  fragments reject their complete vector after parsing. The live wire retains
  provider-scheme and exact-assignment `FExactContext` nodes only for bounded,
  closed nominal class applications. Exference preserves them on the
  plain/binder-only and accepted-fact lanes; a no-group exact-evidence provider
  and Djinn use context-erased compatibility projections. Class arguments may
  have a bounded first-order kind; a positive-arity source argument may be its
  enclosing provider variable either bare or partially applied only to
  proper-type arguments, while ground assignments require a canonical nominal
  head and proper-type supplied arguments. Malformed, free,
  dictionary-dependent, term-indexed, unsupported
  structural forms, and other unsupported forms remain fail-closed. The
  command-wide vector list is capped at 32 before planning or translation, and
  provider-prefix fallback carries each vector only with its source
  declaration. The checked runners
  verify exact provider identity, arity, supplied positional kinds, closure,
  and context before consuming a vector once without Cartesian reconstruction.
  Proper-kind live arguments additionally retain a bounded structural fragment
  plus semantic forall-domain tags. This metadata is render-only, selected only
  by a complete canonical vector, and preserves implicit/explicit binders plus
  mixed `Prop`/`Type`/`Sort` domains without transporting executable Lean text;
  the mandatory Lean verifier remains the acceptance boundary.
  This includes constraint-only or otherwise vacuous higher-kinded binders.
  Canonical `Prod` and `Sum` are accepted at total arity two and translated to
  their structural Djex identities; the other unsaturated structural heads and
  every legacy structural payload remain conservatively excluded.
  A dependent or unsupported provider context truncates the entire provider;
  it is never erased into a stronger context-free scheme. Only current exact
  `(instantiations ...)` vectors on an Exference contextual provider can turn
  their source scheme's specialized constraints into deduplicated
  zero-prerequisite ground declarations after the complete constraint group
  passes a clean replayed trial inventory seal. Discovery commits no
  vector-local translation state; every trial replays the previously accepted
  source-order keys plus the candidate, and the final inventory replays only
  accepted keys. An all-rejected provider restores all successfully
  translatable vectors from its bounded, filtered context-erased fallback.
  Legacy `(candidates ...)`
  metadata cannot. The resulting class facts are global to the exact
  Exference/Length inventory and may serve another provider because
  top-level Lean instance search closed them without query givens. Djex still
  independently discharges each activated conditional-certificate obligation
  before Length problem or query sealing, and Z3 supplies no dictionary
  authority.
- Non-dependent instance-implicit binders in a goal are serialized as
  render-only slots. They are erased before either engine searches, reserve a
  wildcard in an introduced Lean lambda, stay implicit at hypothesis and
  provider applications, and poison complete negative evidence. This keeps
  dictionary reconstruction with Lean without shifting later synthesized
  term arguments.
- Proper-type applications headed by a bound constructor variable or an
  opaque/non-inductive Lean constant retain their ordered arguments. Private
  abstract declarations keep constant heads rigid, and rendering restores
  their exact Lean names. Qualifying non-recursive inductives add a query-wide
  exact-head plan: compatible `Option`, `Except`, and user-family occurrences
  share one parameterized data declaration while preserving constructor
  introduction and case elimination. Recursive `FParamRec` occurrences now
  use a parallel exact-head plan with recursive-knot normalization. Both
  engines receive a shared native recursive declaration only for a complete,
  compatible schema: Djinn gains bounded positive introduction and Exference
  its one-layer eliminator. A pairwise-distinct structured parameter vector may
  seed a positive candidate plan when its closed template specializes back to
  every observed occurrence; this remains speculative until Lean verification
  because occurrence inventories do not retain parameter provenance. Every
  recursive fallback uses one abstract exact family plus occurrence constructor
  premises. Repeated, partial, incompatible, or nominally colliding schemas
  disable negative evidence; term/dependent parameters retain the
  occurrence-local path.
  Planning reaches nested inventories through a fixed point, but only when a
  selected structural declaration or an active constructor premise consumes
  them. Fixed opaque fields are seeded as private rigid proper types, while
  recursive self keys are subtracted so the knot resolves through the shared
  datatype rather than an unrelated atom. Thus unused metadata cannot poison
  a plan, and a zero-parameter type such as `Std.Format` cannot acquire an
  accidental free variable through its `String` field.
- Where a term's shape is ambiguous in Lean (a quantified hypothesis
  may be transported whole or instantiated), the renderer offers the
  alternatives and verification picks the one that elaborates.
- Auto-bound goal variables default to `Sort`; when Type-level `×`/`⊕`
  over arrows leaves Lean's universe unifier stuck, `:synth` retries
  with the unresolved variables bound at `Type` (noted in the output).
  Names that resolve in the session — including through an opened
  namespace — are never shadowed.
- The pure searches answer in microseconds; the cost center is backend
  verification, a few hundred milliseconds per candidate. A wall-clock
  guard (default 20 s, `LEANT_SYNTH_TIMEOUT=N`, `0` waits indefinitely)
  covers quantified goals whose bounded instantiation widens the
  space. The same deadline covers the baseline and every provider fallback
  rather than restarting for each lane; hitting it is reported as "no answer",
  never as a verdict.
- `LEANT_SYNTH_DEBUG=1` prints the translated fragment, discovered providers,
  rendered variants, and stable `code=count` verification metrics — the
  fastest way to see why a candidate was dropped and how much Lean work the
  lane performed.

## How it works

Leant implements the backend protocol directly
([src/Leant/Backend.hs](src/Leant/Backend.hs)): JSON over stdin/stdout
with blank-line framing, spawned as `lake env repl.exe` inside the Lake
project. The JSON codec is hand-rolled
([src/Leant/Json.hs](src/Leant/Json.hs)), so the REPL core builds with
GHC boot libraries only — no Hackage downloads. On backend death,
timeout, or Ctrl+C, the process is killed and the session (imports +
history) replays automatically on the next command. The Haskeline
front-end provides the interrupt-safe step loop, logical multi-line
input, and completion.

An unpickled environment becomes an explicit history and undo barrier.
Leant keeps a private process-lifetime copy, so backend restart does not
depend on the user leaving the source file in place; commands entered after
the barrier replay normally and remain undoable. `:reset` or `:load` leaves
snapshot mode and rebuilds configured imports, while `:import` asks for one
of those explicit transitions because Lean cannot add imports to an existing
opaque environment.

`:pickle` publishes the ordinary `.olean` first-class artifact together with
a versioned `.leant.json` sidecar and, when synthesis tooling can be prepared,
a `.leant-synth.olean` sibling. Content fingerprints and the serializer ABI
prevent stale siblings from being trusted. Missing, stale, or foreign metadata
does not block `:unpickle`; such a snapshot is restored as an upstream snapshot
and Leant builds synthesis tooling over it when its imports expose Lean's
metaprogramming API.

A `:synth` query passes through checked stages: a Lean metaprogram
(compiled once into a cached side environment) elaborates the goal and
serializes it into the engine's fragment; the fragment translator
accepts it or refuses with a reason. For every engine mode and an accepted
structural fragment, the engine first searches without providers and the
backend re-elaborates its rendered candidates against the original goal. After
no provider-free term verifies, a second metaprogram builds the bounded
live-provider inventory and runs the fallback search. A complete Djinn
refutation is kept as a sound fallback during those constructive lanes: a
verified provider candidate overrides it, while provider discovery/search
failure or exhaustion restores it before the explicit classical policy is
considered.
Atomic/provider-open refusals use that provider path directly. Djinn-backed
fallback tries discovery-order prefixes of 1, 4, and 16 providers before the
full inventory, omitting milestones at or beyond the actual inventory size.
Combined mode runs both engines at the singleton and terminal full widths and
Djinn alone at intermediate widths. Within a combined lane, stable exact-text
deduplication keeps the first scheduled spelling and preserves variant order
inside each group: `D1–D4, E1–E12, D5–D12` form the 24-group frontier, then the
tails alternate. Empty or duplicate-only groups spend no slot. An exact later
Exference duplicate may supply a private variant-local behavioral origin, but
never changes the first occurrence's display ownership or gives authority to a
different spelling. Constructor and exact provider names are restored and
binders named by role before every verification; only survivors are shown and
bound.

The synthesis side environment tracks exactly which session history it
has replayed. An unchanged history reuses it directly; an append replays
only the new suffix; undo or another non-prefix change rebuilds from the
cached import-and-serializer base. For a restored Leant snapshot that base is
the saved synthesis companion, so snapshot-only declarations remain visible
to goal translation and live-provider discovery. Generated result bindings still join
that replay history so later goals can mention them, but because they
cannot be providers they do not invalidate a reusable provider
inventory.

## Development

The focused Haskell suite covers fragment/provider parsing, engine
isolation, exact global rendering, and synthesis behavior:

```bash
cabal test leant-synth-tests --test-show-details=direct
```

Golden transcript tests live in [test/](test/): `bash test/run-tests.sh`
passes each `*.txt` through `leant --plain` and diffs the filtered
output against the checked-in `*.golden`; `-u` regenerates the goldens
after an intentional behavior change. These end-to-end goldens require
the Lake project to provide the backend executable (`repl` or
`repl.exe`); the focused suite remains runnable when that backend is not
installed. Ideas under consideration are tracked in
[docs/PROPOSALS.md](docs/PROPOSALS.md) and
[docs/SYNTHESIS_PROPOSAL.md](docs/SYNTHESIS_PROPOSAL.md).

## License

Available under [MIT-0](LICENSE).
