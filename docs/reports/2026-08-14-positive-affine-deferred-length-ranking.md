# Positive-affine deferred Length ranking

Date: 2026-08-14

## Outcome

Leant now exposes the additive Djex positive-affine applicable-domain rule,
query-owned bounded counterexample simplification, and deferred live-session
opening through one closed advanced startup checkpoint. Startup version 7
selects scalar finite-list-spine Length ranking; version 8 selects the nominal
canonical binary-`Prod` sibling. Both use the unchanged format literal:

```text
leant-live-length-ranking-configuration
```

No CLI option changes. A file is still selected only through:

```text
leant --length-ranking-config /absolute/path/configuration.json
```

An unpinned file still additionally requires the existing explicit
`--length-ranking-allow-unpinned` relaxation. Loading and activation perform no
solver launch.

Versions 1 through 6 remain literal eager compatibility paths. Their schemas,
decoders, policy construction, failure precedence, contract selection,
identities, and behavior do not acquire any advanced feature.

## Programmatic policy surface

The additive public builders are:

```haskell
enableLengthRankingPositiveAffineApplicableDomainValidation
  :: LengthInputBoxLimits
  -> LengthRankingPolicy
  -> LengthRankingPolicy

enableLengthRankingCounterexampleSimplification
  :: LengthInputBoxLimits
  -> LengthRankingPolicy
  -> LengthRankingPolicy

enableLengthRankingDeferredLiveSessionOpening
  :: LengthRankingPolicy
  -> LengthRankingPolicy
```

The established
`enableLengthRankingNonVacuousApplicableDomainPreference` recognizes both the
historical direct-v1 and positive-affine receipt families. The direct-v1 and
positive-affine applicable-domain builders are mutually exclusive selections;
whichever is applied last is retained. Neither preference enables validation,
and deferred opening is operational policy rather than evidence.

The same opaque policy can be supplied to the scalar and pair assessors. That
reuse shares only execution, evaluation, bounded orchestration, ordering, and
opening choices. The contracts, checked problems, queries, replay receipts,
failures, assessments, MRU banks, simplification metadata, and presentation
remain nominally domain-specific.

## Exact v7/v8 file schema

After bounded JSON parsing and format/version dispatch, v7 and v8 require
exactly these root fields and demand them in this semantic validation order.
JSON object member order itself is immaterial.

| Order | Field | Exact advanced meaning |
|---:|---|---|
| 1 | `format` | `"leant-live-length-ranking-configuration"` |
| 2 | `version` | `7` for scalar or `8` for binary product |
| 3 | `executionAdmission` | unchanged execution-admission object |
| 4 | `execution` | unchanged complete execution object |
| 5 | `evaluation` | unchanged replay-evaluation object |
| 6 | `inputBoxValidation` | independent caller-selected post-`unsat` box |
| 7 | `counterexampleProbe` | `"origin-before-live"` |
| 8 | `boundedPositiveOrdering` | `"prefer-non-vacuous"` |
| 9 | `applicableDomainValidation` | independent positive-affine limits |
| 10 | `applicableDomainOrdering` | `"prefer-non-vacuous"` |
| 11 | `counterexampleSimplification` | independent simplification limits |
| 12 | `liveSessionOpening` | `"defer-until-live-query"` |
| 13 | `contract` | scalar v5 grammar for v7; pair v5 grammar for v8 |

The positive-affine object has exactly:

```json
{
  "strategy": "positive-affine-v1",
  "maximumInputs": 8,
  "maximumAssignments": 65536
}
```

The simplification object has exactly:

```json
{
  "strategy": "componentwise-lexicographic-v1",
  "maximumInputs": 8,
  "maximumAssignments": 65536
}
```

Those displayed values are the caps, not defaults. Each object is decoded and
sealed independently as its own `LengthInputBoxLimits`; neither can borrow the
explicit input-box width or cardinality. The explicit box separately admits at
most eight source-ordered maxima and 65,536 assignments.

The unchanged bounded JSON policy is 262,144 total bytes, depth 133, 32,768
nodes, 32 members per object, 257 elements per array, 64 UTF-8 bytes per key,
16,384 UTF-8 bytes and 4,096 Unicode scalars per string, and 80 bytes per
number. Other unchanged operational caps include 4,096 executable-path
characters, 262,144 policy-fingerprint bytes, a 65,536-byte response, 64
response nesting levels, 4,096 response nodes, 4,096 token bytes, 4,096-bit
response integers, a 60,000-ms solver timeout, a 10,000,000 solver resource
limit, a 65,000-ms host deadline, and 4,096-bit assignment and intermediate
evaluation values. `expectedExecutableSha256` remains either `null` or exactly
64 lowercase hexadecimal characters. Artifact policy remains exactly
`status-only` or `input-values-after-satisfiable`.

The embedded contract limits also remain unchanged: at most 256 provider laws,
8 target roles, 16 roles per provider, 256 Unicode scalars and 1,024 UTF-8
bytes per name, semantic depth 64, 1,024 syntax nodes, 32 formula clauses, 64
elements per syntax collection, and 256 bits per natural literal. These caps do
not enlarge because v7/v8 add ranking policy rather than contract vocabulary.

V7 embeds scalar contract grammar v5. V8 embeds the same pair grammar used by
startup v6 and contract-only v6, including the required exact
`"resultShape": "binary-prod-spines-v1"`. The contract is demanded only after
every operational field, so a poisoned later contract cannot preempt an earlier
schema, literal, limit, execution, evaluation, or policy failure.

## Positive-affine coverage authority

The new rule is a distinct explicit selection. Djex's old direct-v1 functions
and receipts still recognize only an immediate normalized
`input <= natural-literal` clause. They continue to reject equality and
arithmetic-derived coverage.

For a nonnullary positive-affine query, Djex scans the precondition itself or
the immediate clauses of a flat top-level conjunction. The admitted affine
expression grammar is exactly:

```text
A ::= compact-input
    | natural-literal
    | LengthSum [A]
    | LengthScale positive-literal A
```

A comparison supplies coverage only as `A <= k`, `A == k`, or `k == A`, where
`k` is a natural literal. If `A` denotes
`c + a0*x0 + ... + an*xn` and `c <= k`, every positive coefficient derives the
necessary bound:

```text
xi <= (k - c) quot ai
```

Duplicate bounds use the minimum in compact source order. Unsupported clauses
grant no bound and are not partially mined, but they remain part of the actual
precondition evaluated during replay. Thus natural monus, minimum, maximum,
quotient, modulo, conditionals, negation, and nonliteral comparisons do not
create coverage authority.

A checked `false`, an unequal constant-only equality in either orientation, or
a recognized affine atom whose constant exceeds its ceiling is a syntactic
contradiction. Contradiction takes precedence over missing coverage elsewhere.
For a nonnullary contradiction, Djex derives all-zero maxima and validates the
one all-zero assignment, so successful establishment records one checked
assignment and zero applicable assignments. An equal constant-only equality is
true and non-binding. A nullary problem skips coverage extraction, derives
maxima `[]`, validates the singleton assignment `[]`, and records applicable
count one or zero according to the full precondition.

Extraction and replay have fixed demand order: input width before the
precondition; clauses and affine children left to right; stop immediately on a
contradiction, but otherwise complete the full scan before selecting the first
missing compact input in source order, because a later contradiction overrides
earlier missing coverage; derived values left to right; saturating Cartesian
admission; last-input-fastest lexicographic replay; then exact query/problem
association. Incomplete coverage and Leant-classified width, value, or product
admission refusal are pure misses. After admission, indexed evaluation,
internal enumeration, and association errors are operational failures.

Complete scalar traversal becomes
`PositiveAffineApplicableDomainEstablished` with an opaque
`ValidatedLengthPositiveAffineApplicableDomain`. The pair siblings are
`LengthSpinePairPositiveAffineApplicableDomainEstablished` and
`ValidatedLengthSpinePairPositiveAffineApplicableDomain`. A first violation is
the existing ordinary scalar or pair counterexample instead. The receipt
projects only derived maxima, exact total and applicable assignment counts, and
the model/provider-relative `LengthCounterexampleBasis`.

## Deferred runtime state machine

Candidate admission is productive and rejects a maximum-plus-one tail before
contract or candidate payload traversal. The full admitted batch, capped at 64,
then completes handoff and canonical query preparation before any IO.

For each eligible candidate, v7/v8 execute this source order:

1. up to four newest-first domain-local MRU raw-input replays;
2. positive-affine applicable-domain validation;
3. the exact query-owned all-zero origin replay;
4. a live query followed by mandatory exact observation replay; and
5. only after a counterexample-free live `unsat`, the independent explicit
   post-`unsat` input box.

MRU, applicable-domain, and origin are the pure prefix. A counterexample or an
establishment receipt completes that candidate without visiting later sources;
inapplicability continues. If every eligible candidate completes through pure
sources, no process is opened and no capability probe runs.

The first candidate whose pure prefix misses causes exactly one lexical Djex
session to open. Its live query runs once; Leant does not rerun that candidate's
pure prefix. The remaining candidate suffix uses the same session, applying its
own pure prefixes and issuing live calls only on misses. The session retains the
existing single 64-query total budget, serial ordinals, capability admission,
poisoning, deadline, and cleanup rules. It never becomes cached interactive
state or crosses to a later batch.

A pure indexed operational failure before opening atomically reconstructs the
entire admitted batch in original order with all assessments `Unassessed`, and
opens nothing. An opener failure does the same with safe index `Nothing`. Once
open, any later indexed live, replay, domain, origin, simplification, or box
failure discards every earlier pure or live assessment and all simplification
metadata, then performs the same atomic reset. Finalizer/session failures retain
the established index-`Nothing` classification. Candidate-local preparation
refusals remain local in successful runs and retain their bounded payload-free
classes through atomic fallback.

## Counterexample finalization, MRU, and ordering

Every independently validated counterexample source—MRU, positive-affine
domain, origin, live observation, and post-`unsat` box—enters the same
query-owned simplification seam before assessment or MRU mutation.

Djex first revalidates the supplied anchor against the exact query. After
admitting the complete componentwise-dominated box, it searches from zero in
last-input-fastest lexicographic order. A metadata receipt exists only when the
canonical first violation differs strictly from the anchor. It retains the
original inputs, exact inspected count including the returned hit but excluding
anchor replay, and a fresh ordinary counterexample whose inputs and result are
recomputed under the exact problem.

Width or Cartesian-product unavailability, no strict improvement, and a trial
assignment evaluation rejection retain the exact original counterexample and
make no simplification claim. Admitted structural, anchor, association, or
internal failures remain indexed atomic failures; association is exposed only
through the established sanitized replay-mismatch class. A strict result's
final vector, never its original anchor, is inserted or promoted in the same
four-entry domain-local MRU bank. Later candidates still replay that raw vector
under their own checked query, so no receipt or authority is cached.

V7/v8 enable both positive preferences. Stable final order is:

1. non-vacuous applicable-domain establishments;
2. non-vacuous explicit post-`unsat` box completions;
3. neutral assessments, including either zero-applicable vacuous receipt,
   heuristic solver statuses, unassessed candidates, and preparation refusals;
4. independently replayed counterexamples.

Original order is stable inside every partition. Occurrence handles retain the
exact callback occurrence, ordinary receipt, and optional simplification
metadata through the final permutation seal, including equal candidate values.

Presentation reports positive-affine derived maxima, total/applicable counts,
the provider-count-only basis, and explicit vacuity through
`renderLengthPositiveAffineApplicableDomainValidationNote` or its nominal pair
sibling. Strict simplification notes report original and final inputs, inspected
count, recomputed result, and basis. Existing 384-character redaction remains;
deferred opening itself adds no note.

## Authority and identity boundary

Positive-affine establishment is complete only for the exact derived finite box
under the checked precondition, interpreted candidate, evaluation limits, total
finite-spine model, and retained assumed provider laws. It is not a global
proof, solver proof, provider-implementation validation, Lean execution claim,
termination or totality claim, or pruning authority. Raw `sat`, `unsat`, and
`unknown` cannot manufacture it. The query wrapper launches no solver; it
contributes exact problem association before releasing evidence.

Counterexample simplification is bounded componentwise lexicographic search,
not global minimization. Deferred opening is only lifecycle orchestration.
Neither changes the meaning of an existing counterexample, positive receipt,
or live status.

Djex adds only its nominal positive-affine receipt tags. Leant adds startup v7
and v8 schema identity. Existing contract, inventory, interpretation, session,
candidate, encoding, problem, SMT query, protocol, process, ready-worker,
query-run, live-observation, replay, direct applicable-domain, input-box, and
counterexample identities and canonical bytes remain unchanged. Query commands
and fingerprints are unchanged. Scalar and pair authority remains disjoint.

## Compatibility and characterization map

The generalized startup decoder delegates versions 1 through 6 to their
established paths before considering v7/v8. Old roots reject every advanced
field; base policy constructors and established direct runners select eager
opening and disabled simplification. Contract-only documents remain versions 1
through 6 and carry no execution, ranking, domain-validation, simplification,
or opening policy.
The `:synth --length-contract ... -- TYPE` grammar is unchanged.

Focused characterization for this checkpoint covers:

- exact v7/v8 roots, versions, literals, field demand, independent limits, and
  caps, including old-version rejection of new fields;
- scalar and pair positive-affine establishment, counterexample, inapplicable,
  contradiction, nullary, admission, and operational-failure paths;
- all-pure no-process execution and first-miss single-session suffix execution
  without rerunning the triggering pure prefix;
- scalar and pair MRU, domain, origin, live, and post-`unsat` counterexample
  sources crossing simplification before assessment and final-vector MRU;
- pre-open and later indexed failure atomic reset, opener/finalizer index
  `Nothing`, and removal of earlier occurrence-attached metadata;
- non-vacuous applicable-domain preference ahead of explicit-box preference,
  stable neutral/vacuous handling, stable counterexample demotion, and no
  pruning; and
- unchanged v1--v6 eager behavior, query bytes, identities, presentation for
  old receipt families, and scalar/pair nominal separation.

Djex's extraction proof, receipt tags, and evaluator-level characterization are
recorded in the
[positive-affine applicable-domain report](../../lib/Djex/docs/reports/2026-08-14-positive-affine-length-applicable-domain.md).
The prior Leant direct-v1 and simplification boundaries remain documented in
the [directly bounded applicable-domain report](2026-08-14-directly-bounded-length-applicable-domain.md)
and [bounded counterexample simplification report](2026-08-14-bounded-length-counterexample-simplification.md).
