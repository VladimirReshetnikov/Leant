# `:synth` internals

The [candidate-quality guide](candidate-quality.md) describes the configurable
policy now applied before candidate-window, verification, and display cutoffs.
`synthLimitRanking` travels with each lane. Djinn orders finite proof choices
before its raw cutoff; Exference ranks a bounded checked pool before rendering
and deduplication. Selection moves whole candidate/evidence associations and
uses typed-graph erasure for scoring when that authority is available. Raw
proof/step work is never refunded for normalized duplicates. The later cursor,
verification, and Length boundaries below consume that selected order.
The default profile is `balanced`. Descriptions of legacy candidate prefixes
or the distinct-rendered-group window apply to `legacy`; the structural
profiles can choose another checked order under the same resource settings.
The historical E0 baseline uses Leant acceptance checkout `5629936`, with unchanged
production code from `a970d1f`, vendored Djex `ae986bf5` (synthesis code
`2954b6d2`), and the unchanged `e0b9…` executable. All **569 unit tests**
passed serially at unchanged limits. Both engines passed **350/350 Church
cases**, with all **700 exact displayed terms** independently kernel-replayed
and all axiom inventories empty. The **84-query/136-term policy matrix**
passed with 112 empty inventories and 24 confined to declared provider
premises, including three paired nil checks and three projection-diversity
proofs. All **90 broader fixture terms** passed live and kernel validation,
with 78 empty inventories and 12 exact declared-premise inventories.

The [current acceptance table](../test-church/README.md#current-quality-policy-acceptance)
and [quality probes](../test-church/quality.md) retain executable hashes,
receipt paths, universe/default qualifications, and the distinction between
live validation and reviewed offline golden comparison. E0's remaining 26
ordinary fixtures completed with six original matches and 20 reviewed golden
drifts; the original runner exit remains 1. Independent replay checked 99
exact changed terms and, separately, six proof terms and two exact tactic
applications. The preserved ordinary and compact captures then matched all
30 goldens offline, covering 265 synthesis commands. Manual query 20's first
result nevertheless grew from two to three matches; neither a final-score
inversion nor budget exhaustion has been established.

The accepted-spelling verification repair described below is newer than E0.
Production revision `043a6a3d` passed **all 578 tests serially in 533.23
seconds** and built executable `42c0c9c0…` successfully. Its fresh full
30-fixture/265-command live run completed at a 30-second synthesis timeout:
29 original golden matches and one expected duplicate-line removal, with
no lost successes, changed first results, new spellings, remaining exact
duplicates, or control/proof changes. Two retained `Gap.Token` terms passed
fresh exact kernel replay. All 30 reviewed goldens then matched offline;
the original live runner exit 1 is preserved.

The fresh 84-query matrix passed in two disjoint runs with all 136 terms
kernel-replayed, 112 empty inventories and 24 within declared premises.
All three paired nil checks and three projection-diversity proofs passed,
with every type and ordered term list unchanged from E0. The
[final acceptance table](../test-church/README.md#accepted-spelling-repair-completed-acceptance)
pins the executable hash, settings, and distinct receipts. The 700-term
Church replay remains historical E0 evidence. Earlier receipts
remain separately identified under
[historical acceptance](../test-church/README.md#historical-acceptance-before-the-quality-profiles).

*How Leant's synthesis pipeline is put together: the semantic-origin record,
provider bindings, the Length handoff, and the invariants each dated report
pins. The [README](../README.md) keeps the user-facing tour of `:synth`; this
document holds the design detail that used to sit inline there.*

The material below is a current-tree specification of internal boundaries.
Leant is experimental and makes no public stability or backward-compatibility
promise: startup or contract-only JSON shapes, tags, names,
diagnostics, and output may be revised before a stable release. Historical
comparisons below are regression descriptions, not commitments to preserve
earlier design decisions. Each paragraph
names the module that owns a boundary and links the report that recorded it,
so a reader who wants the *why* of a rule can follow the link, and a reader
who wants the *what* can stop at the paragraph.

---

## Contents

- [Design and report index](#design-and-report-index)
- [The Djex engine](#the-djex-engine)
- [The semantic-origin record and provider bindings](#the-semantic-origin-record-and-provider-bindings)
  - [Candidate authority, sidecars, and exact-text deduplication](#candidate-authority-sidecars-and-exact-text-deduplication)
- [Length handoff and problem sealing](#length-handoff-and-problem-sealing)
  - [Interpretation policy and session-owned sealing](#interpretation-policy-and-session-owned-sealing)
  - [Adapter and canonical query sealing](#adapter-and-canonical-query-sealing)
- [Ranking foundation](#ranking-foundation)
  - [Package-private nominal counterexample-bank state and context](#package-private-nominal-counterexample-bank-state-and-context)
  - [Current applicable-domain validation](#current-applicable-domain-validation)
  - [The origin probe](#the-origin-probe)
  - [Live input-box validation and query-first replay](#live-input-box-validation-and-query-first-replay)
  - [Refusals, atomic fallback, and lifecycle owners](#refusals-atomic-fallback-and-lifecycle-owners)
- [SpinePair ranking, post-verification, and selection](#spinepair-ranking-post-verification-and-selection)
- [Configuration and its file grammar](#configuration-and-its-file-grammar)
  - [Policy builders and usable-work budgets](#policy-builders-and-usable-work-budgets)
  - [`Configuration.File`: the current versionless JSON grammar](#configurationfile-the-current-versionless-json-grammar)
  - [Fixed startup policy and domain selection](#fixed-startup-policy-and-domain-selection)
  - [File acquisition](#file-acquisition)
  - [Contract-only files and the length-contract command](#contract-only-files-and-the-length-contract-command)
  - [Inline where-clause command and activation](#inline-where-clause-command-and-activation)
  - [Integration and one-shot contracts](#integration-and-one-shot-contracts)
- [Opaque detailed synthesis cursor foundation](#opaque-detailed-synthesis-cursor-foundation)
- [Scoped parallel initial structural schedules](#scoped-parallel-initial-structural-schedules)
- [Private ordered verification scheduler foundation](#private-ordered-verification-scheduler-foundation)
- [Backend process-tree lifecycle prerequisite](#backend-process-tree-lifecycle-prerequisite)
- [Private isolated backend pair foundation](#private-isolated-backend-pair-foundation)
- [Main's progressive same-run cursor scheduler](#mains-progressive-same-run-cursor-scheduler)
- [Contract vocabulary and module ownership](#contract-vocabulary-and-module-ownership)
- [Post-verification sealing](#post-verification-sealing)
  - [The behavioral-selection partition seal](#the-behavioral-selection-partition-seal)
  - [The Length ranking and selection adapters](#the-length-ranking-and-selection-adapters)
- [Provider instantiation evidence](#provider-instantiation-evidence)
  - [Exact provider assignment vectors](#exact-provider-assignment-vectors)
- [Proper-type applications and family plans](#proper-type-applications-and-family-plans)
- [Rank-N plan families and bounds](#rank-n-plan-families-and-bounds)

## Design and report index

The implementation invariants are recorded in the dated reports for
[finite families](reports/2026-08-01-query-wide-parametric-inductive-families.md)
and
[recursive families](reports/2026-08-01-query-wide-recursive-family-identity.md),
with the scoped quantified-provider boundary documented in the
[local-provider report](reports/2026-08-01-scoped-quantified-local-providers.md)
and the active-instance extension in the
[provider-local instance-head report](reports/2026-08-05-provider-local-instance-head-evidence.md).
Its complete multi-binder correlation follow-up is recorded in the
[correlated instance-head assignment report](reports/2026-08-05-correlated-instance-head-assignments.md).
Djinn's expanding occurrence-plan family and Leant's checked integrations are
recorded in the
[quartic rank-N frontier report](reports/2026-08-06-quartic-rank-n-frontiers.md)
and its
[quintic successor](reports/2026-08-06-quintic-rank-n-frontiers.md).
The historical five-binder Djex boundary and Leant's matching live bridge are
recorded in the
[five-binder integration report](reports/2026-08-09-five-binder-instantiation.md).
Its one-through-six successor is recorded in the
[six-binder integration report](reports/2026-08-10-six-binder-instantiation.md).
Djinn's additive specialization of query-local schemes at closed monotypes is
recorded separately in the
[query-local closed-monotype report](reports/2026-08-09-query-local-closed-monotype-instantiation.md).
Exact render-only retention of implicit forall visibility and mixed sort
domains is recorded in the
[implicit provider visible-result report](reports/2026-08-09-exact-implicit-provider-visible-results.md).

## The Djex engine

If dependent types, propositions-as-types, or how Lean elaborates and
checks a term are unfamiliar, read
[Lean from First Principles](Lean_from_First_Principles/Lean_from_First_Principles.pdf)
first: it builds that background from zero and then follows the pipeline
below chapter by chapter, from the fragment translation through search,
rendering, verification, and negative evidence.

The engine is the vendored [Djex](../lib/Djex) library, linked in-process.
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
schemes use correlated source/target assignments together with bounded query
and environment alternatives. Impredicative instantiation retains quantified
structure and lexical scope through checking, including compound polytypes
assembled from those demands.

## The semantic-origin record and provider bindings

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

### Candidate authority, sidecars, and exact-text deduplication

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

`synthVerify` uses `verifyDistinctCandidateGroupsBy` to keep at most one
accepted representative of each exact, case-sensitive text in its batch.
Only an actual `VariantAccepted` inserts a key. Failed spellings can be
retried, including in another group; duplicate-only nonempty groups add no
attempt, failure, or success. An originally empty group retains its existing
failed-group semantics. A fresh alternative within a later group may still
be tried. Quota checks precede observation of later groups or variants.

This verification filter returns the first accepted callback candidate
unchanged, including its ordinal, route, and existing origin. It does not
borrow an origin or Length receipt from a skipped later duplicate; the
earlier combined-engine origin association above is a separate boundary.
`verifySynthLane` still takes the same bounded group prefix before flattening
variants. Skips do not request a refill or refund raw search work, and the
generic `verifyCandidateGroups` API retains its earlier behavior.

## Length handoff and problem sealing

The Length sections that follow assume the reader knows what a satisfiable
formula, a model, and an `unsat` answer are and how a candidate becomes a
`QF_LIA` query; [Z3 from First Principles](Z3_for_Leant_and_Djex/Z3_for_Leant_and_Djex.pdf)
teaches that background from zero and then walks these same modules in a
maintainer's source map, so it is the place to start when this material is
new.

`Leant.Synth.Length.Handoff` binds callback-accepted text back to its exact
typed origin, original Exference renderer ordinal and exact re-rendered variant,
family provenance, an opaque Djex session which owns the exact inventory and
provider assumptions, its checked interpretation policy, the separately
reassociated contract, and the
candidate-specific Djex problem. That checked preparation consumes the
renderer, family, and session authority and returns only the sealed problem;
Engine owns the exact-origin rerender mechanics and private premise-layout ABI.
Handoff preserves the singleton/ordinal-zero rule whenever the explicitly
selected current contract policy rejects cases. The exact zero/step policy
instead owns selection of the retained original ordinal and equality with the
callback-accepted text; other valid renderer alternatives neither replace that
retained variant nor make its exact association ambiguous.

### Interpretation policy and session-owned sealing

Only after renderer correspondence and exact family/provider resolution,
Handoff converts the contract's explicit `(candidate case policy, target
roles)` pair once into Djex's closed `LengthInterpretationPolicySource`.
Case-rejecting and exact zero/step contracts both carry their exact
source-ordered role vector; the current grammar cannot construct the former
implicit-role combination or exact authority without roles. Handoff then uses
only Djex's
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
their exact identities. Djex's legacy-versus-explicit-all-observed equivalence
within each policy family and Leant's renderer selection remain unchanged;
Leant's current files no longer construct the legacy entrance.
The authority migration and compatibility matrix are detailed in the
[unified checked Length handoff policy report](reports/2026-08-13-unified-length-handoff-policy.md).
The opaque carrier handoff and its trust limits are recorded in the
[Length certificate-carrier handoff report](reports/2026-08-13-length-certificate-carrier-handoff.md).
The live exact-context wire, active-instance provenance, and inventory-wide
ground-fact bridge are recorded in the
[contextual-provider ground-discharge report](reports/2026-08-13-live-contextual-provider-ground-discharge.md).

### Adapter and canonical query sealing

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
[exact-duplicate typed-provenance report](reports/2026-08-11-exact-duplicate-typed-provenance.md).

## Ranking foundation

`Leant.Synth.Length.Ranking` supplies the checked ranking foundation. Its
caller must provide an explicit Djex live-execution policy,
explicit replay limits, an explicit `LeanLengthContract`, and the complete list
of callback-verified candidates. It productively admits at most Djex's public
64-query session bound, attempts every candidate handoff, and seals every
eligible canonical query before any possible process launch. Eager policy then
opens one lexical session; deferred policy first processes the pure source
prefix and opens at most one session on the first live miss. Both process
candidates serially in original order. Every established rank and direct
Selection compatibility runner retains the historical raw-bank path. After an exact counterexample,
that path retains its bounded source-ordered input naturals in a fixed
four-entry batch-local bank. The raw bank is newest first, deduplicates exact
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

### Package-private nominal counterexample-bank state and context

The vendored Djex snapshot exposes nominal candidate-independent scalar and
binary-product scopes, bounded immutable input stores, and pure query-owned
bridges which fresh-replay a receipt before recording its inputs or replay one
exact retained sample against a later same-scope query. A same-scope match
authorizes only that fresh attempt; neither an old receipt nor a stored vector
is a reusable verdict.

`Leant.Synth.Length.CounterexampleBank.Internal` is the package-private state
owner over those Djex primitives. The scalar and product state types are
nominal and distinct. Each retains validated limits and zero or one active
bank. Its empty and default constructors leave that bank absent without
forcing the limits. The first replay or record operation initializes from the
exact query-owned scope. A same-scope query retains the bank; scope drift
replaces it with one empty bank under the original limits and does not inspect
the discarded samples.

Whole-bank replay traverses exact opaque samples newest first. Every admitted
attempt accepts Djex's returned charged successor as authoritative. Evaluation
or association refusal is retained in attempt order and traversal continues;
an ordinary non-counterexample also continues. Exhaustion is an ordinary miss,
and attempt-cap exhaustion is ordinary bounded unavailability. A hit returns
an opaque sample/scope association plus the fresh current-query receipt but
does not promote implicitly. Promotion is a separate membership- and
scope-checked input-only insertion under the solver-independent replay origin,
so it performs no second evaluation.

Recording accepts a previously validated receipt only as an input-vector
source. Djex first fresh-replays it once through the current query, and Leant
records only a reproduced counterexample under one closed coarse origin: live
model, solver-independent replay, or simplification replay. Evaluation,
association, non-reproduction, attempt-limit, and insertion-limit outcomes
remain explicit, and every bridge-returned successor is threaded even when a
later step refuses the operation.

The module now also owns abstract scalar and product context cells. Each
context's `command` type parameter has a nominal role, as does its semantic
identity parameter, and the introducer quantifies `command` inside a rank-2
callback. A context replay mints a command-tagged opaque hit, so a same-
identity hit cannot later be promoted through another context. The only state
projection returns an immutable snapshot; there is no setter or constructor
which restores a snapshot.

Each context cell is an `MVar`, not a whole-assessment lock. Replay, promotion,
and recording each run one serialized exception-restoring transition. Before
commit the adapter fully evaluates the successor limits and complete active
bank, then forces the outer `Either` and its selected failure or outcome
constructor to weak head normal form. A synchronous or asynchronous exception
during that preparation restores the old state and propagates. Every completed
expected result instead installs Djex's authoritative successor, including
ordinary refusal, miss, attempt-cap, and insertion-cap results. Ranking,
simplification, worker IO, and the rest of the candidate loop remain outside
the cell's masking and serialization boundary.

The shared ranking core (`Ranking.Generic`, instantiated by the scalar and
pair `Ranking.Internal` modules) threads an additive cursor which is either
the historical raw `[[Natural]]` MRU or one supplied nominal context of the
instantiating domain. Existing ranking and compatibility selection entrances
always choose the raw cursor. Only the context-aware Configuration and
Selection entrances used by Integration's filter context choose the nominal
cursor. The cursor is threaded through eager/deferred opening and unbudgeted,
v1, and scoped-v2 usable-work loops without changing the established rank/raw
entrances.

On the context path, an unsimplified bank hit promotes its exact opaque sample
without reevaluation. A simplified hit records the final receipt under the
simplification origin instead. Fresh live-model and solver-independent sources
use their corresponding origin unless simplification produced the final
receipt. Recording is only a cache side effect: the assessment keeps the final
pre-record receipt and simplification metadata. A fatal simplification failure
does not promote or record, while its already completed replay transition
remains charged. A later indexed ranking failure or preserve-all selection
failure likewise does not roll back earlier completed bank transitions.

The pure-state foundation checkpoint remains recorded in Leant's historical
[nominal bank-state report](reports/2026-08-16-nominal-length-counterexample-bank-state.md).
Its filter-only runtime successor is recorded in the
[counterexample-bank context runner report](reports/2026-08-16-filter-only-length-counterexample-bank-context-runner.md).
Djex's storage and fresh-replay boundaries are recorded separately in its
[nominal bank report](../lib/Djex/docs/reports/2026-08-16-nominal-length-counterexample-bank-foundation.md)
and
[query-replay bridge report](../lib/Djex/docs/reports/2026-08-16-length-counterexample-bank-query-replay-bridge.md).

### Current applicable-domain validation

Leant has one applicable-domain policy in the current tree. The programmatic
builder is
`enableLengthRankingApplicableDomainValidation inputBoxLimits unionLimits`;
the current startup decoder installs the same policy directly. The
`LengthInputBoxLimits` value bounds compact-input width and unique
assignments. The retained `LengthBooleanFiniteUnionLimits` value bounds raw
generated branches, rules per branch, closure inspections per branch, retained
boxes, and raw assignment visits. Its name identifies the resource-cap record,
not a selectable predecessor strategy.

The policy runs after the selected newest-first replay source—the raw
four-entry MRU on rank/direct compatibility paths or the nominal context on
Integration's filter path—and before the origin probe. An ordinary
inapplicable result or any width, generated-branch,
rule, closure, retained-box, maximum-value, visit, or unique-assignment
admission refusal is a pure miss and continues through origin and live
execution. A replayed violation becomes the ordinary `Counterexample`.
Complete traversal becomes `ApplicableDomainEstablished` for the scalar
domain or `LengthSpinePairApplicableDomainEstablished` for the nominal
binary-product domain and skips the later stages. Assignment evaluation,
internal enumeration invariants, and exact evidence/query association remain
indexed atomic failures.

The independent
`enableLengthRankingNonVacuousApplicableDomainPreference` moves only a
completed receipt whose applicable-assignment count is positive. It does not
enable validation or alter its evidence. With both current preferences enabled,
the stable partitions are non-vacuous applicable-domain evidence, non-vacuous
explicit-box evidence, neutral and vacuous assessments, then counterexamples.

Scalar validation delegates to
`validateLengthSMTLibQueryApplicableDomain`; product validation delegates to
`validateLengthSpinePairSMTLibQueryApplicableDomain`. Their closed query error
families are `LengthSMTLibApplicableDomainValidationError` and
`LengthSpinePairSMTLibApplicableDomainValidationError`; the checked-problem
entrances are `validateLengthProblemApplicableDomain` and
`validateLengthSpinePairProblemApplicableDomain`. Successful assessments
carry `ValidatedLengthApplicableDomain` or
`ValidatedLengthSpinePairApplicableDomain`. Their six public projections are
the domain-specific `InclusiveMaximumBoxes`, `BoxCount`,
`AssignmentVisitCount`, `AssignmentCount`,
`ApplicableAssignmentCount`, and `Basis` projections. Presentation uses
only `renderLengthApplicableDomainValidationNote` or
`renderLengthSpinePairApplicableDomainValidationNote`. The operational
failures are `LengthRankingApplicableDomainValidationFailed` and
`LengthSpinePairRankingApplicableDomainValidationFailed`, carrying the short
Djex error families `LengthApplicableDomainValidationError` and
`LengthSpinePairApplicableDomainValidationError`.

The earlier direct, positive-affine, relational, strict, quotient, extrema,
monus, Boolean-union, atomic-branching, and long recursive builders,
assessments, failures, renderers, Djex receipt families, and public schema tags
were deleted. There are no aliases or migration adapters. Leant is
experimental, promises no stability or backward compatibility, and has no
userbase requiring that historical choice ladder. Dated reports retain the
engineering sequence but do not describe current imports.

#### Private fallback semantics

Djex retains the former analyses only as one private ordered fallback inside
the current validator:

```text
direct literal -> positive affine -> relational -> strict relational
  -> positive-literal quotient -> root extrema -> root monus
  -> Boolean finite union / atomic branching
  -> guarded recursive piecewise-affine fallback
```

Each leaf first uses the complete atomic scanner. Recursive expansion runs only
for its singleton ignored alternative when the relation still contains
minimum, maximum, natural monus, or a conditional, so an earlier exact result
remains authoritative. The recursive grammar admits compact inputs, natural
literals, normalized sums, positive scales, minimum, maximum, monus, and
`LengthIf condition trueArm falseArm`. A conditional is all-or-nothing: every
leaf in both condition polarities and every descendant in both selected arms
must be supported. A quotient, modulo, result reference, out-of-range input,
retained zero scale, or another unsupported child rejects the complete
fallback atom; an earlier private stage may still have handled the complete
leaf.

For child values `L` and `R`, the exact alternatives are:

```text
min(L,R)  -> [L <= R;     value L] | [R + 1 <= L; value R]
max(L,R)  -> [R <= L;     value L] | [L + 1 <= R; value R]
L monus R -> [L <= R;     value 0] | [R + 1 <= L; value L - R]
if F then T else E
          -> [positive F guards; value T]
           | [negative F guards; value E]
```

The first extrema/monus case owns equality. Conditional true-arm alternatives
precede false-arm alternatives; inside an arm, condition-DNF alternatives are
outermost, the selected expression is innermost, and condition guards precede
selected-arm guards. Left-child alternatives otherwise precede right-child
alternatives, descendant guards precede the current selector, and the final
relation rule comes last. Signed coefficients produced by positive monus
branches transfer exactly into the natural positive-sided rule
representation. The closure uses one immutable snapshot per pass and fires
each source-ordered rule at most once.

Generated-branch admission counts the raw formula-DNF and recursive-alternative
Cartesian product before cleanup, including impossible conditional guards that
collapse only when the enclosing relation forms branch coverage. Canonical
original literal sets are
re-expanded in set order before rule and closure accounting. Every surviving
branch must bound every compact input. Bounded branches form a
lexicographically ordered, componentwise-maximal box antichain; incomparable
boxes are never replaced by a hull. Visits count overlaps, a global bounded set
deduplicates assignments, and Djex replays the original checked precondition
and postcondition once per assignment in global lexicographic order. Derived
guards, rules, boxes, and solver status never replace this query-owned replay.

The one-input discriminator `(if x <= 2 then x else 5) <= 3` retains
`[[2]]` with 1/3/3/3 box, visit, unique, and applicable counts; its two raw
alternatives distinguish branch caps one and two. A negative equality guard
retains all three complement alternatives. The nested discriminator
`y <= 2` and `(if x <= 1 then max(x,y) else x monus y) <= 2` retains
`[[4,2]]` with 1/15/15/12 counts. Its four raw alternatives precede rule and
closure admission, and an independent wider-rectangle replay oracle checks
that no satisfying assignment is omitted. Replacing either arm with an
unsupported modulo or quotient descendant rejects the whole fallback atom.

Under deferred opening the selected-bank/domain/origin prefix remains before process IO.
A pure establishment or counterexample opens no worker. The first live miss
opens one lexical session without repeating the prefix; the remaining
candidates stay in that scope. The current policy and deletion rationale are
recorded in the
[current applicable-domain policy report](reports/2026-08-15-current-length-applicable-domain-policy.md).
The detailed grammar, cap precedence, receipt identity, and replay authority
are owned by Djex's
[current applicable-domain surface report](../lib/Djex/docs/reports/2026-08-15-current-length-applicable-domain-surface.md).
The guarded extension and inherited native process ownership are recorded in
the
[guarded conditional Length ranking report](reports/2026-08-15-guarded-conditional-length-ranking.md).
The older strategy reports are non-normative development history.

### The origin probe

The current startup policy inserts one query-owned origin probe after the
selected replay source is exhausted—at most four raw entries on the established
rank path—and after the applicable-domain pass is inapplicable, before that
candidate's live Z3 query. Programmatic policies can enable the same probe
explicitly. Leant supplies no
arity or values: Djex derives one zero per compact modeled input from the
sealed checked problem and runs the ordinary bounded replay and exact
association gate. A hit is the ordinary `Counterexample`; it is stably demoted
and its exact zero vector updates the selected raw MRU or nominal context. A
miss is no evidence, leaves the bank unchanged, and proceeds to live Z3. An
evaluation rejection or association mismatch is an indexed operational
failure and activates the same batch-wide original-order, all-`Unassessed`
fallback. The probe consumes no solver status and does not itself schedule the
finite box. Under eager policy the worker has already opened and an origin hit
avoids only a live transaction and ordinal. Under deferred policy the origin
probe runs before IO, so an all-pure batch can avoid process launch and its
capability probe entirely.

### Live input-box validation and query-first replay

Without input-box validation, `unsat`, `unknown`, and status-only `sat` remain
neutral. The current startup policy and explicit input-box builder use a live
`unsat` only to trigger Djex's independent exhaustive replay of
caller-selected per-input inclusive maxima. A discovered violation becomes the
ordinary `Counterexample`, is
stably demoted, and updates the selected raw MRU or nominal context. Complete traversal becomes
`BoundedPositive`, contributes no seed, and records only bounded/model-relative
positive evidence. It stays in the neutral stable partition unless the
non-vacuous preference is selected. The current startup route selects that
preference; programmatic callers can use
`enableLengthRankingNonVacuousInputBoxPreference`. Only a receipt with a
positive applicable-assignment count moves into the stable preferred partition. A
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

### Refusals, atomic fallback, and lifecycle owners

The ranking foundation never prunes. A candidate-local handoff or query-
construction refusal
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
That atomic fallback discards partial candidate assessments, not completed
nominal-bank transitions: accepted replay charges and authoritative promotion
or record successors remain in the context. An exception inside a context
transition is the complementary case; the `MVar` restores the old state before
the exception propagates. Other exceptions propagate instead of producing a
ranking. Programmatic callers may
retain separate per-query budgets or explicitly select the runtime-unscoped v1
shared owner. The current startup route and the scoped programmatic builder use
the owner-thread-affine v2 lease and cooperative phase checkpoints. Neither owner
claims asynchronous interruption of arbitrary callback code. Main invokes
this foundation only after the explicit startup opt-in described above; it
never infers an executable path, contract, or policy. The foundation is
detailed in the
[live Length ranking foundation report](reports/2026-08-11-live-length-ranking-foundation.md).
The raw batch-local replay optimization and its unchanged trust and identity
boundaries are recorded in the
[Length counterexample seed replay report](reports/2026-08-13-length-counterexample-seed-replay.md).
Its fixed raw four-entry MRU policy and Djex's query-owned raw-input replay boundary
are detailed in the
[Length input replay bank report](reports/2026-08-14-length-input-replay-bank.md).
The historical checkpoint which introduced the all-zero probe, exact
raw-MRU/origin/live order, and failure and identity boundaries is detailed in the
[Length origin-probe orchestration report](reports/2026-08-14-length-origin-probe-orchestration.md).
The opt-in finite-box policy, its unsat-as-trigger-only boundary, positive
receipt, and additive configuration grammar are detailed in the
[unsat-triggered bounded Length validation report](reports/2026-08-14-unsat-triggered-length-input-box-validation.md).
The separately enabled stable preference for non-vacuous positive receipts is
detailed in the
[non-vacuous bounded-positive ordering report](reports/2026-08-14-non-vacuous-bounded-positive-ordering.md).
The historical directly bounded pre-live checkpoint and its separate
non-vacuous preference are recorded in the
[directly bounded applicable-domain report](reports/2026-08-14-directly-bounded-length-applicable-domain.md).
Its public validator family has been superseded by the one current algorithm
documented in the
[current applicable-domain policy report](reports/2026-08-15-current-length-applicable-domain-policy.md).

## SpinePair ranking, post-verification, and selection

`Leant.Synth.Length.SpinePair.Ranking` and
`Leant.Synth.Length.SpinePair.PostVerification` supply the nominal
canonical-`Prod` sibling of this orchestration. The pair path reuses the same
bounded execution policy and lexical Djex session capability, but prepares
only pair queries and releases only pair-domain assessments and receipts. Its
established ranking and direct Selection compatibility entrances retain their own raw four-entry
batch-local MRU, while the additive context-aware filter entrance receives the
nominal product bank. Optional applicable-domain validation, origin probe,
live pair call, query-first replay, and post-`unsat` pair input box preserve the same
stable-demotion and atomic-fallback rules without transferring scalar
authority. Pair-safe terminal projection lives in
`presentLengthSpinePairPostVerificationResult`; the complete checkpoint is
recorded in the
[live binary-product Length ranking report](reports/2026-08-14-live-binary-product-length-ranking.md).
The later nominal `Leant.Synth.Length.SpinePair.Selection` adapter consumes
only this pair report, rejects only an independently replayed pair
counterexample, and otherwise follows the preserve-all and stable original-
order selection rules described below.

## Configuration and its file grammar

`Leant.Synth.Length.Configuration` seals that call boundary without choosing
any policy for the user. `LengthRankingPolicySource` carries the execution
admission, complete execution source (absolute Z3 path, optional SHA-256
expectation, solver/host budgets, artifact policy, and response limits), and
replay-limit source. After validation, `LengthRankingPolicy` retains the
opaque sealed Djex execution configuration and evaluation limits plus a
private disabled-or-current applicable-domain pass,
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
  LengthSMTLibDescriptorBoundEffectiveIDExecutableAccessLaunch ->
    error "impossible for this constructor"
  LengthSMTLibDescriptorBoundExecveCheckExecutableAccessLaunch ->
    error "impossible for this constructor"
```

The established `rankPostVerification...WithPolicy` and
`assessVerified...WithPolicy` scalar/product entrances remain literal raw-MRU
compatibility paths. Additive
`assessVerifiedLengthCandidatesWithPolicyAndCounterexampleBankContext` and
`assessVerifiedLengthSpinePairCandidatesWithPolicyAndCounterexampleBankContext`
entrances accept the matching nominal context. Their private ranking siblings
dispatch that same context through every eager/deferred and
unbudgeted/v1/scoped policy branch; the policy value itself owns no bank.

This construction is pure. It does not open, hash, copy, seal, or launch the
configured executable. It preserves every later policy builder, and
`lengthRankingPolicyFromValidatedComponents` retains whichever sealed Djex
strategy its caller already owns. The corresponding configured-mode projection
is `lengthAssessmentModeExecutableLaunchStrategy`; disabled assessment returns
`Nothing` without inspecting any contract.
The effective-ID executable-access sibling is selected independently:

```haskell
effectiveAccessPolicy <-
  mkLengthRankingPolicyWithDescriptorBoundEffectiveIDExecutableAccessLaunch
    policySource

case lengthRankingPolicyExecutableLaunchStrategy effectiveAccessPolicy of
  LengthSMTLibDescriptorBoundEffectiveIDExecutableAccessLaunch ->
    assessVerifiedLengthCandidatesWithPolicy
      effectiveAccessPolicy scalarContract verificationBatch
  LengthSMTLibPathSnapshotThenDirectSpawn ->
    error "impossible for this constructor"
  LengthSMTLibDescriptorBoundExecutableLaunch ->
    error "impossible for this constructor"
  LengthSMTLibDescriptorBoundExecveCheckExecutableAccessLaunch ->
    error "impossible for this constructor"
```

This maker is equally pure and retains the same execution-before-evaluation
failure order. Its later live opener requires two point-in-time Linux
`faccessat2(fd, "", X_OK, AT_EMPTY_PATH | AT_EACCESS)` admissions on the same
opened source descriptor. The first precedes copying; the second follows pin
and sealed-image admission and immediately precedes child allocation. The
staged memfd has fixed mode `0500`, and unsupported checks fail closed without
falling back to either established strategy. The policy and configured-mode
projections expose only the third closed classifier, never credentials,
access results, descriptors, or source metadata.

The execve-check executable-access sibling is the fourth pure selection:

```haskell
execveCheckPolicy <-
  mkLengthRankingPolicyWithDescriptorBoundExecveCheckExecutableAccessLaunch
    policySource

case lengthRankingPolicyExecutableLaunchStrategy execveCheckPolicy of
  LengthSMTLibDescriptorBoundExecveCheckExecutableAccessLaunch ->
    assessVerifiedLengthCandidatesWithPolicy
      execveCheckPolicy scalarContract verificationBatch
  LengthSMTLibPathSnapshotThenDirectSpawn ->
    error "impossible for this constructor"
  LengthSMTLibDescriptorBoundExecutableLaunch ->
    error "impossible for this constructor"
  LengthSMTLibDescriptorBoundEffectiveIDExecutableAccessLaunch ->
    error "impossible for this constructor"
```

Construction preserves the same execution-before-evaluation failure order and
does no IO. At a demanded Linux live open, Djex pairs each of the two source
`faccessat2` observations with descriptor-bound `AT_EXECVE_CHECK`, creates the
staged image with `MFD_EXEC`, fixes mode `0500`, adds and verifies write, grow,
shrink, future-write, exec, and final seals, then checks the sealed staged image
once before child allocation. The compiled-backend classifier is not a runtime
kernel probe: a stock 5.15 kernel fails closed at the first source exec check,
while 6.14 or later remains conditional on active kernel policy. There is no
path, older-maker, non-`MFD_EXEC`, reduced-seal, or unchecked fallback. The
policy and configured-mode projections reveal only the fourth closed
classifier, not descriptors, credentials, check results, requested staging
flags, or runtime admission.

All three native descriptor launch variants share the same lower ownership
transition. A resource-producing deadline worker stays masked until it
publishes one terminal `Either` through one completion cell as its final
effect. Cancellation, deadline loss, or an exception in the controller kills
that worker, joins by reading the same completion, and rolls back any returned
resource; there is no separately visible outcome followed by a lagging done
signal. Source descriptors, staged images, portable `createProcess` results,
and native spawn results use this masked-publication entrance.

After native spawn, a shared masked handoff retains rollback ownership of the
raw child, stdin, stdout, and stderr bundle across one restored asynchronous-
exception checkpoint. The consumer is entered masked; it allocates the opaque
process owner before restoring interruptible initialization, after which that
process value owns cleanup. The exec-status `Handle` has its own masked
`finally`, so EOF, a child-reported exec failure, synchronous read failure,
deadline cancellation, and asynchronous interruption all close it before
child-and-stdio cleanup proceeds. This changes neither public process types nor
behavioral evidence; it closes leak windows in the inherited runtime. See
Djex's
[descriptor spawn resource-ownership report](../lib/Djex/docs/reports/2026-08-15-descriptor-spawn-resource-ownership.md).

The retained policy builders are persistent and orthogonal for programmatic
callers. Applicable-domain construction has only the short current builder;
its lower analysis stages are private inside Djex. The startup decoder always
enables the input box, origin probe, both non-vacuous
preferences, guarded recursive piecewise-affine applicable-domain validation,
counterexample simplification, deferred opening, and the scoped/checkpointed
usable-work owner on top of the execve-check descriptor launcher. Only numeric
limits and the genuine scalar-or-binary-product domain choice remain in the
startup document.

Programmatic callers can still opt into the runtime-unscoped or scoped budget
with `enableLengthRankingUsableWorkBudget` or
`enableLengthRankingScopedUsableWorkBudget`; both builders are pure and create
no evidence, and the last budget builder applied determines that one policy
dimension.
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

### Policy builders and usable-work budgets

The configuration boundary keeps reusable process policy separate from the
passive scalar-or-pair contract selection. A decoded startup value owns one
strictly validated policy beside one lazy nominal contract selection.
Activation checks only whether that sealed policy contains the required digest
expectation or whether the caller explicitly permits an unpinned executable.
It does not inspect the contract, open a descriptor, run an access check, stage
an image, or launch Z3.

Lower-level policy construction still permits independent choices for library
callers. In particular, the runtime-unscoped v1 usable-work owner and the
owner-thread-affine v2 scoped lease remain distinct programmatic strategies.
The v2 lease admits use only on its creating thread and during its callback,
and Leant places cooperative checkpoints around preparation, complete
candidate chains, live work, and result materialization. Neither strategy is an
asynchronous watchdog or behavioral authority. The current startup decoder
always constructs the scoped-v2 route; it has no budget-strategy selector.

The startup-fixed contract is reused by ordinary commands. A one-shot
contract-only document can instead associate the same activated policy with a
request-owned scalar or pair contract. In either case the exact
candidate-specific contract check remains deferred to full preparation. The
opaque policy has no path or digest-byte projection and retains no worker.
There are no execution defaults, executable discovery, path normalization, or
environment reads.

### `Configuration.File`: the current versionless JSON grammar

`Leant.Synth.Length.Configuration.File` owns one bounded startup grammar. Its
root has exactly these ten required members:

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

`format` is exactly `leant-live-length-ranking-configuration`.
`rankingDomain` is exactly `scalar` or `binary-product`. The root has no
`version` member. Every object rejects duplicate, unknown, and missing fields;
every scalar uses its closed type and range. The decoder consumes a
caller-owned strict byte string through the bounded JSON parser, rejects
malformed UTF-8 and non-integral policy numbers, and cannot widen Djex's
candidate, contract, provider, literal, fingerprint, or evaluation authority.

The document exposes only numeric parameters and genuine choices. The current
execve-check descriptor launcher is fixed, so `execution` has no
`executableLaunch` member. The current guarded recursive piecewise-affine algorithm is
fixed, so `applicableDomainValidation` has no `strategy` member.
Counterexample simplification and the scoped-v2 budget likewise omit their
one-choice `strategy` fields. The origin probe, both non-vacuous preferences,
and deferred opening are decoder-owned policy and therefore do not appear as
`counterexampleProbe`, `boundedPositiveOrdering`,
`applicableDomainOrdering`, or `liveSessionOpening`.

After bounded JSON and root-object admission, semantic validation checks
`format`, `rankingDomain`, and the exact root shape. It then validates
execution admission, execution, evaluation, input-box limits,
applicable-domain limits, simplification limits, and the scoped usable-work
budget. The domain-selected contract is last. JSON member order does not alter
that precedence.

The applicable-domain object contains exactly seven numeric limits: maximum
inputs, generated branches, rules per branch, closure inspections per branch,
retained boxes, assignment visits, and deduplicated assignments. Their file
caps remain 8, 256, 64, 4096, 256, 262144, and 65536. The simplification object
contains only maximum inputs and maximum assignments. The budget object
contains only milliseconds, capped at 65,000. Input-box, applicable-domain, and
simplification limits are independent authorities.

A successful decode returns an opaque disabled configuration. The caller must
still explicitly require a pinned executable or permit an unpinned one before
activation releases the strict policy and lazy domain selection to Integration.
Neither step launches Z3 or grants proof, solver-status, contract, or replay
authority. Historical startup roots with `version` or removed strategy
members are rejected rather than migrated. Because `rankingDomain` is demanded
before exact-root validation, an untouched historical root first reports that
required member as missing; after a valid domain is supplied, a retained
historical member is unexpected. There is no startup unsupported-version
sentinel or compatibility dispatcher.

### Fixed startup policy and domain selection

Every accepted startup file constructs the same operational bundle:

- descriptor-bound execve-check executable access, including the two
  point-in-time effective-ID source VFS checks, two source
  `AT_EXECVE_CHECK` observations, sealed `MFD_EXEC` image, and one staged
  descriptor check;
- newest-first replay and the all-zero origin probe, using the raw four-entry
  MRU on rank/direct compatibility paths or the supplied nominal context on
  Integration's filter path;
- independent post-`unsat` input-box traversal;
- current guarded recursive piecewise-affine applicable-domain traversal;
- non-vacuous preference for both positive-evidence families;
- componentwise-lexicographic counterexample simplification;
- deferred worker opening; and
- one scoped-v2 usable-work deadline with cooperative checkpoints.

`rankingDomain = scalar` selects the nominal scalar assessor and the full
scalar contract grammar. `rankingDomain = binary-product` selects the
nominal canonical-`Prod` assessor and its separately typed pair contract.
`rankingDomain` is the sole domain discriminator; neither nested contract
admits `resultShape`. Domain selection never comes from the
Lean goal and cannot cast contracts, queries, receipts, failures, assessments,
raw-MRU/context state, or presentation across the scalar/product boundary.

Construction remains pure. An all-pure batch captures and checks the scoped
clock but performs no executable or access-check IO. The first live miss opens
one lexical session for the remaining suffix. Any access, staging, live,
replay, association, forcing, or finalization failure preserves the established
original-order assessment fallback. That fallback does not rewind completed
nominal-context cache transitions.

The current schema reset and deleted compatibility surface are recorded in the
[versionless startup configuration report](reports/2026-08-15-versionless-length-ranking-configuration.md).
The current semantic and evidence boundary is recorded in the
[guarded conditional Length ranking report](reports/2026-08-15-guarded-conditional-length-ranking.md)
and Djex's
[guarded conditional applicable-domain report](../lib/Djex/docs/reports/2026-08-15-guarded-conditional-length-applicable-domain.md).
The earlier recursive reports and their startup-number discussion describe
their landing checkpoint, not the current grammar.

### File acquisition

`Leant.Synth.Length.Configuration.File.Acquire` maps the shared bounded
`Leant.Synth.Length.File.Acquire` filesystem boundary into startup
configuration failures. Callers must explicitly admit an absolute path of at
most 4,096 characters and a positive timeout of
at most 60 seconds. On POSIX the final component is opened once with
no-follow, nonblocking, no-controlling-terminal, and close-on-exec flags; its
descriptor must report a regular file before any read. Strict reads stop at
the decoder's 262,144-byte maximum plus one, and only the still-disabled
configuration can escape. Errors retain closed phases, capped counts, and a
cleanup bit rather than paths, errno text, or file content. The timeout is an
interruption budget rather than a hard kernel deadline, final-component
no-follow does not exclude ancestor symlinks or in-place mutation, and Windows
fails closed until an equivalent native handle implementation exists. Main
reaches `loadLengthAssessmentConfigurationFile` through Integration's
`loadLengthAssessmentMode` for its explicit startup CLI path; there is no
scalar-only startup loader. There is still no discovery or default
path, and loading/activation alone never launches a solver. See the historical
[bounded acquisition report](reports/2026-08-11-bounded-live-length-ranking-configuration-acquisition.md).

### Contract-only files and the length-contract command

`Leant.Synth.Length.Contract.File` adds the separate versionless root with
format `leant-finite-list-spine-length-contract` for a command-owned passive
contract. Its exact fields are `format`, `rankingDomain`, and `contract`.
`rankingDomain` is exactly `scalar` or `binary-product` and is the sole domain
discriminator; neither nested grammar admits `resultShape`. Execution and
evaluation fields remain unknown and rejected.

`decodeLengthContractFile` parses bounded JSON exactly once and returns one
`LeanLengthContractSelection`. Its semantic order is root object, format
presence/type/value, domain presence/type/value, exact root, contract-object
type, and then the selected nested decoder. Exact-root validation reports an
unexpected member before a remaining missing member. There is no version
dispatcher, unsupported-version sentinel, compatibility fallback, migration,
or retry through another domain.

Both nested decoders first require the exact six fields `spine`,
`targetArgumentRoles`, `candidateCasePolicy`, `precondition`, `postcondition`,
and `providerLaws`, then validate them in that order. Roles and case policy are
always explicit. The current expression grammar always admits positive-literal
Natural modulo and quotient in contract formulas and provider transfers; both
divisors are checked before their operands and must be nonzero. All names,
enum values, and syntax tags are case-sensitive.

The `Contract.File.Acquire` facade uses the same path, descriptor, and timeout
owner as startup acquisition, but maps failures into contract-only closed
vocabulary. `Leant.Synth.Length.Command` owns the exact option-bearing grammar

```text
:synth [--behavior-mode rank|filter] [--length-contract PATH] -- TYPE
```

while keeping ordinary `:synth TYPE` delimiter-free. Only the exact option
tokens are recognized; longer lookalike prefixes remain goal text. The mode
must precede the contract, every recognized option form requires the standalone
delimiter, the behavior value is exactly `rank` or `filter`, and an empty path
is rejected before a misplaced exact mode token in the contract span.
Omitting the behavior mode defaults to `rank`.

### Inline where-clause command and activation

`Leant.Synth.Length.Command` gives the fully explicit inline grammar a
separate, fixed-order structural parser:

```text
:synth --behavior-mode filter --length-model list-scalar-exact-cases|list-binary-product-exact-cases --length-inputs arg0[,argN...] --where CLAUSE -- TYPE
```

The bar shows two alternative literal model tokens, not syntax accepted in one
command. The mode must be exactly `filter`; `--length-contract` is mutually
exclusive; every inline option occurs once in the displayed order; and the
standalone `--` separates the unquoted clause from opaque Lean goal text.
Quotes are ordinary rejected clause characters, not a quoting mechanism. The
input token is a nonempty, strictly increasing comma-separated sequence from
`arg0` through `arg7`; gaps and declared-but-unused inputs are valid. Leading
zeroes are numeric aliases, and every clause `argN` reference must name a
declared input within the translated physical arity.

The structural parser retains the raw clause only inside an opaque plan with no
`Show` instance. Main resolves the explicit or prove/`sorry` goal, obtains
`ExplicitLengthAssessmentPermission` for literal `LengthBehaviorFilter`, and
only then calls `Leant.Synth.Length.Where.parseLeanLengthWhereSource`. That
function crosses the single UTF-8 boundary into Djex's source-free bounded
ASCII parser. Its relation grammar and its 16,384-byte and 64-nesting limits
are owned by Djex; closed failures retain offsets and limit observations but no
clause bytes.

After parsing, Main emits the established inaccessible-hypothesis and
premise-scope report. After the ordinary Lean translation/universe-retry state
machine succeeds, Main counts only `SlotArrow` entries in the translated fragment spine.
`forall`, instance, and contextual slots are excluded. The Where resolver
checks that physical arity, marks the explicitly listed source arrows observed,
marks every omitted arrow unobserved, and compacts observed Length inputs in
source order. It then expands only the selected built-in profile: fixed
`List`/`List.nil`/`List.cons` identity, exact zero/step case policy, true
precondition, scalar or canonical-`Prod` result domain, and no provider laws.
Neither clause nor target infers a model, role, spine identity, case policy,
provider law, or execution permission.

Resolution returns the ordinary passive `LeanLengthContractSelection`. Main
pairs it with the previously granted permission, opens exactly one matching
nominal filter context, and passes that context through the complete scheduler.
Every structural, authorization, clause, translation, arity, or elaboration
refusal occurs before the context exists. A provider-dependent candidate not
covered by the empty provider-law set is retained with its preparation refusal;
it is never rejected merely for needing a provider. Established startup and
contract-file requests deliberately retain their older lifetime: `synthRun`
opens their context before translation and keeps it through retry and all
lanes. Neither path writes request or context state into `ReplState`.

#### Concise Lean-native defaults

The common case has a second, higher-precedence command parser:

```text
:synth --where List.length result = List.length arg0 -- List Nat -> List Nat
```

`parseLengthSynthNativeInlineCommand` owns only an exact leading `--where`,
slices the raw clause at the first standalone `--`, and otherwise delegates
unchanged to the explicit and established parsers. Presence of this concise
form is literal filter intent. Main resolves the goal, authorizes
`LengthBehaviorFilter`, and only then calls `parseLeanNativeLengthWhereSource`,
which uses Djex's nominally separate `parseLeanLengthWhereSource` grammar.

After translation, `resolveLeanNativeLengthWhereSource` derives a complete
conservative profile from semantic fragments rather than display text. Only
`SlotArrow` domains count as physical inputs. Every domain that is an exact
unary nominal `List` application becomes `LengthObservedSpine`; every other
arrow is unobserved. An exact unary `List` result chooses the scalar model,
and only a canonical `FLeanProd` whose two components are exact unary `List`s
chooses the pair model. All other result shapes fail closed. The fixed spine,
exact zero/step policy, true precondition, empty provider-law set, policy
authorization, context lifetime, Handoff checks, replay authority, scheduler,
and deadline behavior are identical to the explicit inline path.

The long form therefore remains useful whenever callers need an explicit role
vector or model. The short form supplies reasonable defaults without making
the clause responsible for policy, type, provider, or solver authority. Djex's
standalone REPL independently offers the Haskell-shaped sibling
`:exference --where length result == length arg0 -- [a] -> [a]`.

### Integration and one-shot contracts

`Leant.Synth.Length.Integration` carries the parsed strict
`LengthBehaviorMode` beside the already activated policy and lazy passive
contract selection. `LengthBehaviorRank` dispatches to the scalar or pair
permutation-sealed ranking adapter; `LengthBehaviorFilter` dispatches to the
matching scalar or pair selection adapter. Startup and one-shot contracts
enter the same lifetime owner; the request does not remember a second policy/
contract origin tag. `lengthAssessmentRequestBehaviorMode` projects only the
strict mode tag: disabled assessment projects `LengthBehaviorRank`, and an
enabled projection does not force its retained lazy contract.

`withLengthAssessmentRequestContext` introduces a fresh nominal
`LengthAssessmentContext command` through a rank-2 callback. Disabled and
enabled rank contexts deliberately contain no counterexample bank. A scalar or
product filter context owns exactly one matching nominal bank, and repeated
`assessLengthVerificationContext` calls through that same callback-scoped
value reuse it across batches. `lengthAssessmentContextBehaviorMode` inspects
only the strict context tag and preserves contract laziness.

`assessLengthVerificationRequest` is the compatibility entrance: it calls the
rank-2 introducer once and assesses exactly one batch. A filter call therefore
gets a fresh bank, while a rank call still uses the established raw-MRU runner.
`assessLengthVerificationBatch` delegates through the same compatibility edge.
Main no longer uses that compatibility entrance. `synthRun` calls
`withLengthAssessmentRequestContext` once before initial goal translation and
threads the resulting context through universe narrowing and every ordinary,
provider, excluded-middle, and double-negation assessment. A filter bank is
therefore reusable across all assessed batches in that command; a rank context
remains bank-free.

The disabled rank request is the established non-strict identity. A disabled
filter request returns `LengthAssessmentFilteringRequiresActivatedPolicy`.
For a command-local contract, Integration authorizes mode-plus-policy before
Main admits or opens the path: disabled rank returns the established explicit-
contract activation refusal and disabled filter returns the filtering refusal.
Only after permission does Main call `loadLengthContractFile` and
`explicitLengthAssessmentRequest`. It passes that request into `synthRun`,
which introduces the context before goal translation and keeps it around every
retry and synthesis lane. It never writes behavior mode, the request, an
assessment context, a replay bank, or a selection result to interactive state
or a snapshot.

`LengthAssessmentResult` keeps scalar ranking, pair ranking, scalar selection,
and pair selection nominally disjoint. Ranking projections return `Nothing`
for selection results and selection projections return `Nothing` for ranking.
`lengthAssessmentCandidates` is the common effective-candidate projection: a
successful filter returns only sealed survivors, while every selection failure
returns the complete original batch. `lengthAssessmentFailure` maps both
selection failure families into the mode-neutral Main warning path.

## Opaque detailed synthesis cursor foundation

`Leant.Synth.Engine` now has an additive observation boundary over one lazy
`Either String DetailedSynthOutcome`. `DetailedSynthCursor` and
`DetailedCandidateBatch` are positional, lazy types whose constructors remain
hidden. They have no record selectors, strict fields, `Eq`, or `Show`
instances. Callers can inspect a returned batch only through
`detailedCandidateBatchGroups` and `detailedCandidateBatchNotes`; the Engine
module is therefore the sole constructor of the nonempty ordered group slice
and its association with the original run-level notes. This is ordinary pure
Haskell opacity, not a linear capability: a caller may retain an older cursor,
but advancing any cursor observes the already retained outcome and never
reruns an engine.

`startDetailedSynthCursor` wraps its outcome without demanding the verdict or
candidate stream. `advanceDetailedSynthCursorWith` first validates the
requested per-step size independently of its cursor. Zero and negative
requests return `DetailedSynthCursorBatchSizeNotPositive`; requests above the
window it is given — `synthLimitWindow`, default 60, from `:set synth-window`
— return `DetailedSynthCursorBatchSizeLimitExceeded` with that maximum
followed by the observed request. `advanceDetailedSynthCursor` is the same
walk under `candidateWindow`. Both errors precede even a bottom cursor. For an admitted
request, the outer `Right` is likewise available without demanding the cursor;
forcing its `DetailedSynthCursorStep` performs the first outcome observation.

A candidate step selects at most the requested number of groups and at most
the unspent part of the product-wide 60-group hard cap. It returns
`DetailedSynthCursorCandidateBatch` with one nonempty batch and a lazy
successor. Batches preserve engine order and carry the original notes
unchanged. A request can return fewer groups because the stream ended or
because the remaining hard-cap allowance was smaller; the following step
states which boundary was reached.

This cursor consumes the already selected engine outcome. Its group count
does not replace the earlier raw observation bound: structural Exference
selection has already charged each backend candidate, including rendering
failures and duplicates, before constructing this stream. Legacy Exference
instead builds the stream with its earlier distinct-rendered-group window.
Advancing the cursor does not refund either form of underlying search work.

`DetailedSynthCursorNaturallyExhausted` is returned only when advancing before
the cap observes an empty stream. Once 60 groups have been returned,
`DetailedSynthCursorHardCapReached` wins without probing the next group. An
exactly 60-element finite stream is therefore intentionally a hard-cap result,
not an exhaustion witness, and group 61 may be bottom or an infinite cyclic
tail without affecting productivity. `DetailedSynthCursorEngineFailed`,
`DetailedSynthCursorRefuted`, and `DetailedSynthCursorNoTerm` preserve the
existing error, refutation-soundness flag, and no-term notes rather than
coercing them into candidate completion.

`forceDetailedSynthCursorStep` supplies the value a deadline-owning caller can
evaluate for exactly one step. On a candidate batch it traverses the selected
group-list spine and group constructors, forces each rendering route to weak
head normal form, traverses each variant-list spine and variant constructor far
enough to project text, and traverses each selected rendered spelling's
`String` list spine through `length`. It likewise traverses the run-note list
spine and each note's `String` spine through `length`. It does not force `Char`
values or perform text encoding, and it does not demand semantic sidecars, lazy
recovered-origin lookup, the successor, or the unselected tail. Terminal steps
use the same error/note `String`-list-spine or
soundness-`Bool` boundary as the established `forceDetailedOutcome`; that older
helper is factored through the same private group/note forcing functions and
retains its compatibility force boundary. Main now uses the cursor-step helper.
Neither helper installs a timeout.

`src/Main.hs` consumes this surface without reconstructing either opaque
representation. It imports the cursor and step types, visible terminal
constructors, start/advance operations, batch accessors, and force helper, but
not the hidden `DetailedCandidateBatch` or `DetailedSynthCursor` constructors.
The cursor still owns no assessment context, counterexample bank, provider
deduplication, note-presentation policy, survivor quota, `ReplState` field, or
counterexample-directed engine request; those private orchestration choices
remain in Main.

## Scoped parallel initial structural schedules

The concurrency checkpoints live in Main rather than in the pure Engine API.
`runTunedSynthesis`, including its `EngineBoth` branch, remains serial and
retains its established left-to-right failure behavior. For the initial
provider-free structural baseline, Main can select exactly one of two
disjoint private schedules:

| Selected premises | Engine | Scoped pair |
| --- | --- | --- |
| none | `EngineBoth` | standalone Djinn / standalone Exference |
| nonempty | Djinn, Exference, or `EngineBoth` | structural base / tuned library search |

Both schedules additionally require the resource fields of `SynthLimits` to
match `defaultSynthLimits` (5
shown, 12 verified per standalone engine, a 60-group window, no Djinn
choice-point budget, and Exference queue 1024), a disabled or rank assessment
whose lane cannot request a filter successor, and at least two RTS
capabilities. The library schedule also requires a structurally accepted goal;
the selected premises are the goal-specific rated list, not merely the global
`:set synth-library on` switch. `rsSynthSteps` is not a `SynthLimits` field,
so `:set synth-steps N` remains eligible. The ranking profile is excluded from
that resource-default comparison: each scheduled branch retains the actual
`synthLimitRanking` captured for the command.

`initialBaselineSchedule` decides among those two closures and the serial route
entirely from pure command state. Only an admitted closure reaches the one
`getNumCapabilities` call. At one capability, including explicit
`+RTS -N1 -RTS`, Main does not construct either pair: it invokes the literal
established `runSynthesis True Set.empty engine []` callback, which performs
the same base-then-library schedule as before. The executable is threaded but
has neither a default `-N2` nor a public `:set synth-jobs` setting.

The no-library schedule retains the first checkpoint's exact boundary. Its
scoped workers request and strictly force the available prefix of up to 12
groups from Djinn and 12 from Exference, observe the left/Djinn result first,
join both workers, and then apply the established deterministic `EngineBoth`
merge. Any duplicate-driven tail demand is left to the cursor under the
remaining part of the same absolute command deadline.

The selected-library schedule is one *outer* pair for every engine mode. Its
left action is the ordinary provider-free structural search and its right
action is the existing tuned library-premise search. There is no nested engine
parallelism: when the selected engine is `EngineBoth`, its Djinn and Exference
halves remain serial inside each outer action, so at most these two search
actions are active. The asymmetric strict boundary is intentional:

- the left/base request is zero groups, which still forces the outcome
  constructor, refutation verdict when present, and run-note string spines,
  without entering the candidate-group spine; and
- the right/library request is one complete verification window, capped at 12
  groups for Djinn or Exference and 24 groups for `EngineBoth`.

After both actions join, Main calls the unchanged
`mergeLibraryDetailedOutcomes` with base on the left. Base failures therefore
retain left-first ownership, library candidates still precede base candidates,
and only the base may supply a negative verdict. The ordinary cursor then owns
later base filling and variant-list deduplication under the same absolute
deadline; worker preparation does not start a new clock.

Both paths use the private `runParallelEitherPairOrdered` helper. Nested
`withAsync` scopes start the actions before either result is observed, wait
left first, and cancel and join unfinished work on ordinary left failure,
worker exception, command timeout, or caller cancellation. A deadline win
produces a genuinely empty `SynthLaneRunTimedOut` receipt without probing the
cancelled outcomes, notes, spelling frontier, or group counts.

Provider-enriched lanes and widening, behavioral filter successors, classical
routes, Lean verification, post-verification behavioral assessment, and any
lane with retuned shown/verify/window/budget/queue limits remain serial. The
first quartic engine-pair fixture was about 10.1% slower at `-N2`. In contrast,
the fixed eight-premise `List.map` search-only fixture measured 1.523x for
Exference and 1.572x for `EngineBoth`, with near-parity `-N1` controls and an
independent reproduction near 1.5x. This supports a cautious search-only gain
for the substantive library seam, not an end-to-end, verification,
default-`N2`, or universal speedup claim. See the dated
[structural-pair report](reports/2026-08-20-scoped-parallel-engine-both-baseline.md)
and [library-pair report](reports/2026-08-20-parallel-library-baseline.md).

## Private ordered verification scheduler foundation

`Leant.Synth.Verification.Parallel` now provides one package-private
`runOrderedSuccessQuota` primitive for future production use with isolated
Lean-verification workers. Cabal lists the module only under `Other-Modules`,
and only the unit test suite imports it. `Main`, `Leant.Backend`, and
`Leant.Synth.Verification` have
no dependency on the primitive, so every production candidate group and its
rendering variants still use the established serial verification route over
one backend process.

The primitive classifies each task result as `Left rejection` or
`Right success`. Rejections remain in the ordered result but do not consume
the requested success quota. A positive parallel run admits lazy waves of
width `min workerLimit remainingSuccessQuota`; because one input can contribute
at most one success, no wave can include an input beyond the corresponding
serial success cutoff. The splitter does not inspect the input tail beyond the
last admitted cons cell. A nonpositive quota returns without inspecting the
worker limit, task, or input. For a positive quota, a nonpositive worker limit
fails before inspecting the task or input, while `workerLimit == 1` executes a
literal strict traversal on the caller thread with no asynchronous worker.

Every `Either` result is forced to normal form inside its worker before
publication. A parallel wave starts its admitted workers in nested
`withAsync` scopes and waits in input order. Later completion or failure cannot
overtake an earlier result or exception; an observed failure, caller
cancellation, or scope exit cancels and joins all unfinished siblings before
returning. The pre-landing audit specifically sealed guard precedence,
poisoned-tail laziness, strict result publication, caller-thread N1 behavior,
ordered exception precedence, and cancel-and-join cleanup.

This checkpoint is a scheduler proof boundary, not a runtime integration or a
performance result. The separate private isolated-pair foundation now supplies
two backend processes restored from one artifact; a single backend pipe is
never shared concurrently. Neither foundation is connected to Main, so
production wiring and benchmarking remain future work. The scheduler's exact
contract, audit evidence, and boundary are recorded in the
[ordered verification scheduler report](reports/2026-08-20-ordered-verification-scheduler-foundation.md).

## Backend process-tree lifecycle prerequisite

`Leant.Backend` now gives every `lake env repl` launch an owned process-tree
boundary. The `CreateProcess` request sets both `create_group = True` and
`use_process_jobs = True`. On POSIX it captures the direct wrapper PID
immediately after creation and refuses to publish a `Backend` without it.
That PID supplies a stable process-group address for inherited descendants
even if the Lake wrapper exits before teardown begins. Windows ownership is
the Job held by `ProcessHandle`; it does not require a separate wrapper PID.
Backend-bearing components require
`process >= 1.6.3`, the release in which `getPid` became available.

On POSIX, the child leads a dedicated process group whose ID is the captured
PID; Leant never signals its caller's or a global process group. Teardown sends
`SIGTERM` to that owned group and probes it for a bounded grace period. If the
group remains, teardown sends `SIGKILL`, boundedly reaps the direct wrapper,
and boundedly requires the group probe to report disappearance. Only `ESRCH`
means that the group is gone. Permission, invalid-argument, observation, and
other I/O failures propagate, as do explicit noncompletion failures when the
wrapper cannot be reaped or the group remains after `SIGKILL`.

On Windows, `use_process_jobs` makes the `process` package place the launch in
a Job. `terminateProcess` therefore terminates that Job rather than only the
direct wrapper, and a bounded `waitForProcess` observes Job completion. If the
first wait expires, Leant retries termination and one bounded wait; a second
expiry is an explicit cleanup failure. This branch passed warning-as-error
source compilation with the Windows CPP path forced at the original lifecycle
checkpoint. The subsequent native Windows validation found and corrected a
startup mismatch: `process` represents Job ownership with `OpenExtHandle`, for
which its public `getPid` returns `Nothing`. Requiring that separate identifier
rejected every otherwise valid Job-owned backend. The platform-specific guard
now retains the mandatory POSIX group identifier and uses Windows Job ownership
directly. The native Windows lifecycle and isolated-worker tests exercise
descendant termination, cancellation, malformed responses, and setup timeouts.

`killBackend` owns a masked shared cleanup attempt rather than tying cleanup
to one waiting caller. Cancellation of a waiter does not cancel teardown;
concurrent callers share the active result, successful cleanup remains
memoized, and a failed attempt resets the gate only after all of its cleanup
actions finish. The old completion cell still delivers that attempt's failure
to its current waiters; a later caller may begin a retry just before that
publication, but cannot overlap the completed resource cleanup. Complete
startup, partial startup, and ordinary backend teardown all run their local
cleanup actions even when the tree terminator fails. They attempt to close
every available pipe. Ordinary teardown also gives the stderr pump a bounded drain window before
killing it and boundedly waiting again. Actions run left to right and the
first failure, normally the tree failure, is preserved after the remaining
cleanup attempts.

Backend stdout has a dedicated capture thread and a bounded one-line queue.
Requests wait interruptibly on that queue, preserving their deadline even when
a native Windows pipe read blocks before the end of a line. Directly timing
`hGetLine` did not interrupt that blocking native read and could leave setup
timeouts waiting indefinitely. EOF and read errors remain terminal results in
the queue. Teardown terminates the owned tree first, then stops and joins stdout
capture immediately; unread response lines do not incur the stderr diagnostic
drain grace period. Dedicated regressions cover an incomplete response line
and a valid response followed by an unread output tail.

The deterministic lifecycle fixture runs the unit-test executable as a fake
Lake wrapper. That wrapper launches an independently active heartbeat child
through a path containing spaces, records that it has exited, and then exits
before `killBackend`. On POSIX the child inherits an ignored `SIGTERM`, forcing
the escalation path; it also self-expires after a finite interval as a leak
guard. The test observes both wrapper exit and heartbeat activity, cancels an
initial cleanup waiter, joins concurrent repeated callers, and requires the
heartbeat to stabilize after cleanup returns. Wrapper-only termination would
leave the observed child active and fail this characterization. The existing
oversized-stderr regression remains in the same three-test lifecycle group.

This checkpoint cleared the lifecycle prerequisite used by the later private
isolated-pair foundation. Production candidate verification still runs
serially over one backend. Main integration, acquisition of a command-current
environment artifact, connection to the private ordered scheduler, and
performance measurement all remain future work. The lifecycle implementation,
audit repairs, and **508 of 508** strict-suite result are recorded in the
[backend lifecycle report](reports/2026-08-20-backend-process-tree-lifecycle.md).

## Private isolated backend pair foundation

`Leant.Backend.Isolated` is a package-private resource boundary for future
parallel Lean verification. Cabal lists it under `Other-Modules`; Main and the
production Verification route do not import it. Its pair and lease
constructors are hidden, while its typed setup, transport, lease, pair, and
cleanup failures are inspectable. Its callable shape inside the package is:

```haskell
withIsolatedBackendPair
  :: BackendConfig -> FilePath -> Maybe Int
  -> (IsolatedBackendPair -> IO a)
  -> IO (Either IsolatedBackendFailure a)

withIsolatedBackendLease
  :: IsolatedBackendPair
  -> (IsolatedBackendLease -> IO a)
  -> IO (Either IsolatedBackendFailure a)

runIsolatedBackendCommand
  :: IsolatedBackendLease -> String
  -> IO (Either IsolatedBackendFailure JValue)
```

Pair acquisition sequentially spawns exactly two independent `Backend`
processes and sends each `unpickleEnvFrom` with the same optional request
timeout. Each
successful response must contain its own integer environment identifier and
must contain neither a fatal response nor an error-severity diagnostic.
Failures retain the worker ordinal and distinguish spawn, transport, fatal,
diagnostic, and missing-environment setup cases. A failure or cancellation at
any partial-acquisition point tears down every process already owned before it
returns or rethrows.

The environment artifact is common, but the restored identifiers and process
state are worker-local. A leased command sends exactly the requested `cmd` and
that worker's retained `env`; a response's optional `env` is ignored. Thus all
variants assigned to one lease stay on the same restored branch for the whole
callback rather than silently advancing or crossing into a sibling process.
Fatal, error-diagnostic, and `sorry` JSON received as valid command responses
remain ordinary values for the caller to classify and do not damage the pool.

STM admits at most two simultaneous lease callbacks. Each worker has a
request lock, so commands sharing even one active lease enter its protocol
strictly one at a time. A checkout-local active token prevents a lease from
escaping its callback: release invalidates the token before synchronizing with
the request lock, waits for an already admitted command, and requeues only an
idle worker while both worker and pair remain healthy. A queued detached
command therefore observes a closed lease instead of racing with reuse.

A request timeout, server closure, malformed response, or interrupted
protocol request retires and kills that worker, poisons the complete pair, and
admits no replacement or new lease. The pair's first poison is stable. A
sibling already checked out when that poison occurs may nevertheless finish
its complete candidate-group callback, including further serial variants; it
is not asynchronously killed merely because the other worker failed. Its own
later transport failure retires it without replacing the original pair cause.
This whole-group sibling rule is the resource counterpart to keeping variants
within one ordered-verification task.

Normal release is fail-stop if its synchronized handoff is interrupted or
throws: the worker is retired, the pair receives an interruption poison, and
bounded cleanup completes under an independent owner before the original
release exception is rethrown. An idle lease-callback exception may return its
healthy worker, while an exception with an admitted request retires it. Pair
and request callback exceptions remain primary after cleanup; infrastructure
failures returned as values can attach deterministic worker-labelled cleanup
details.

Pair closure atomically captures the prior healthy or first-poison status in
the same STM transaction that changes the pair to closed and removes all idle
admission. It then tears down both originally registered workers, including a
worker still checked out by a mis-scoped child, rather than relying on the idle
queue. This atomic transition has two deliberate outcomes: poison established
before close cannot be missed, while close wins over a later failure from a
request already admitted in an escaped child. Cleanup uses the bounded,
cancellation-safe whole-process-tree lifecycle described above.

The self-hosted fake-backend characterization passed all **24 of 24** focused
cases, including distinct process/environment identity, setup ordering and
partial cleanup, command serialization, escaped leases, gated release,
release and request cancellation, valid diagnostic responses, stable poison,
sibling completion, callback precedence, and atomic close ordering. The
complete warning-as-error unit suite passed **532 of 532** tests; the
serialized all-suite gate, strict all-target tests-and-benchmarks build, Cabal
check, source-distribution construction, and diff checks also passed. An
independent concurrency audit returned GO. These results characterize the
private foundation and its fake protocol peer, not production routing, real
project environment parity, throughput, latency, or memory use.

The next stage belongs in Main: create and own one artifact representing the
command's current Lean environment, restore both isolated workers from that
artifact, route one candidate group per lease through the ordered success-quota
scheduler, and keep variants serial inside the lease. A one-worker setting
must retain the literal established serial route. Real-backend parity,
deadlines, cold and warm pool cost, resident memory, failure fallback, and
end-to-end transcript equality must be measured before enabling the route or
claiming a speed-up. The landing boundary and evidence are recorded in the
[isolated backend pair report](reports/2026-08-20-isolated-backend-pair-foundation.md).

## Main's progressive same-run cursor scheduler

Main adds three private, lazy representation boundaries with no `Eq` or `Show`
instance. `SynthLaneCursorPolicy` owns the batch width, the filter-successor
permission, ordinary-note retention, and the session's two cursor bounds —
the hard cap on observed candidate groups (`:set synth-window`) and the
accepted groups one batch may keep (`:set synth-shown`). `SynthLaneRunEnd` distinguishes
stopped-by-disposition, policy completion, natural exhaustion, hard cap,
timeout, cursor-admission failure, engine failure, refutation, and no term.
`SynthLaneRun` retains the updated command accumulation, chronological
same-run spelling frontier, cumulative candidate-group count, run notes, and
that terminal reason. None is exported or stored in `ReplState`.

`ordinarySynthLaneCursorPolicy` uses `synthVerificationWindowWith`:
`synthLimitTried`, default 12, for either standalone engine and twice that for
`EngineBoth`. Rank and disabled contexts disallow a successor. Filter contexts
allow one. The excluded-middle policy always uses half of `synthLimitTried`,
default 6, and disallows a successor. Both batch sizes pass through
`admissibleCursorBatch`, which keeps them positive and no wider than
`synthLimitWindow`, so a session that lowers `:set synth-window` below the
frontier narrows the batch instead of failing admission. Double negation uses
the ordinary policy; its tuned Djinn candidate cutoff remains
`synthLimitTried` for rank and disabled modes and becomes `synthLimitWindow`,
default 60, for filter mode. Thus filter-mode standalone and combined runs observe at most two batches of
the frontier each, 12+12 and 24+24 at the default bounds, while EM remains
half a frontier. `admissibleCursorBatch` is what keeps a batch within the
window, at any setting; the arithmetic between the two defaults is not an
invariant.

`runDetailedSynthCursorBefore` calls `advanceDetailedSynthCursorWith` before
the
timeout branch. Valid admission is non-demanding by Engine's contract. With no
deadline it forces the selected step directly; otherwise it computes the
remaining duration from the supplied absolute deadline and evaluates
`forceDetailedSynthCursorStep` beneath `timeout`. It neither captures a new
deadline nor forces the successor or unselected tail.

`runSynthLaneCursor` calls `startDetailedSynthCursor` once for the retained
outcome and owns the only advance site. Every candidate step maps its optional
classical transform over the selected groups, advances the cumulative count,
emits ordinary debug spellings with ordinals continuing from that count, and
calls `verifySynthLane` once. Only `SynthLaneNoVerified` and
`SynthLaneAllBehaviorallyRejected` reach `continueOrStop`; survivor and
preserve-all finish as `SynthLaneRunStoppedByDisposition`.

The continuation guard is literal: the policy must allow a successor and the
current ordinal must be less than two. A continuing second batch therefore
finishes as `SynthLaneRunBatchPolicyReached` without a third advance, even just
to decide whether the tail is empty. Natural exhaustion and the hard cap are
recorded only when the corresponding Engine step was actually observed. The
driver maps every other terminal cursor step and a timeout/admission failure to
the matching `SynthLaneRunEnd` without flattening the result.

Each `verifySynthLane` call takes its supplied batch bound before projecting
behavior mode. Private `synthVerify` receives `synthLimitShown`, default 5,
in rank mode and the complete current batch width in filter mode. The exact
`VerificationBatch` is assessed once and retained with its one
`LengthAssessmentResult` in `AssessedSynthLane`. The driver contains no engine
invocation and no verification or assessment path around its one
`verifySynthLane` call per candidate batch. It therefore cannot rerun
synthesis, reverify a previous batch, or reassess it. Both batches receive the same
`LengthAssessmentContext command`; a filter bank successor is therefore
available to the second batch.

`SynthLaneOutcome` still retains two noninterchangeable histories. Its complete
`concatMap detailedCandidateGroupVariants` spelling frontier includes every
variant in the current batch even when lazy callback verification did not reach
it. Its `[DetailedVerificationVariant]` trace records only actual callbacks.
`SynthLaneRun` reverses its at-most-two buffered outcomes into chronological
order, folds them into the command's reverse accumulation, and concatenates
their complete frontiers in that same order. Later provider deduplication uses
only the run frontier; callback attempts never become scheduling authority.

The pure `synthLaneDispositionWith`, applied to that shown-group cap,
remains four-way:

- `SynthLaneNoVerified` for an unassessed empty batch or an assessed batch with
  no verified receipt;
- `SynthLaneSurvivors` for an accepted presentation, carrying at most
  `synth-shown` (default five) survivors and its complete rejection
  projection;
- `SynthLaneAllBehaviorallyRejected` when an accepted assessment has only
  rejection rows; and
- `SynthLaneAssessmentPreserved` when assessment failure preserves the
  original verified batch.

The defensive callback-verified/no-presentation branch remains terminal
`SynthLaneSurvivors [] []`. Continuing after NV or AR does not fill a survivor
quota: the first S or P batch stops, even with one survivor, and there is never
a third same-run batch.

Engine notes arrive unchanged on every cursor batch, but Main assigns them only
after the run ends. `attachNotesToRightmostHandled` walks the reverse same-run
outcomes, skips no-verification, and attaches the notes once to the newest
all-rejected, survivor, or preserve-all outcome. If all outcomes are
no-verification, the notes remain only in `SynthLaneRun` for the final candidate
or no-term diagnostic. Both classical policies disable handled-note retention.

`classicalSynthLaneDeadline` is behavior-mode sensitive. Filter mode returns
the original command deadline without reading the environment or clock, so
ordinary work, both batches, excluded middle, and double negation share one
absolute budget. Rank and disabled modes read the session's `synth-timeout`
(`:set synth-timeout N`, seeded from `LEANT_SYNTH_TIMEOUT`) and capture a fresh
full duration independently at each reached EM and NN entry. A skipped
route captures nothing, a terminal EM prevents the NN capture, and a nonpositive
configured duration returns the established unbounded `Nothing`.

`SynthLaneAccumulation` remains a positional lazy reverse history. Its pure fold
uses the chronological prefix through the first terminal outcome.
`finalizeSynthLaneAccumulation` remains the sole effect owner: chronological
metrics, effective warnings, one final cache/binding phase, candidate and
rejection rows, and handled notes. Aggregate all-rejection clears once;
survivor or preserve-all replaces once. No batch is finalized early.

Only a completed continuing run reaches another provider stage, contributing
its concatenated spelling frontier. Provider timeout/error remains masked by a
retained sound provider-free refutation, while completed outcomes survive in
the accumulation. The sound-refutation path passes the original command
deadline into `synthClassical`; EM no-verification or all-rejection reaches NN,
while survivor or preserve-all stops. `synthClassical` never finalizes. Its
caller retains the established provably-uninhabited, unresolved-universe, and
constructive/classical-hint gates.

Without a sound fallback, timeout, cursor-admission failure, or engine failure
first finalizes completed outcomes and then emits the corresponding abnormal
diagnostic. Ordinary aggregate all-rejection still suppresses unrelated no-
verification/no-term text. This scheduler adds no quota fill, engine rerun,
reassessment, counterexample-directed request, prefix pruning, public Engine or
Verification API, persistence, or `ReplState` field.

The current reset is recorded in the
[versionless Length contract report](reports/2026-08-15-versionless-length-contract.md).
The behavior request and selection dispatch are recorded in the
[command-authorized Length filtering report](reports/2026-08-15-command-authorized-length-filtering.md).
Its bounded lane-local refill successor is recorded in the
[lane-local Length survivor-refill report](reports/2026-08-15-lane-local-length-survivor-refill.md).
The private behavior-preserving outcome seam is recorded in the
[explicit synthesis-lane outcome report](reports/2026-08-16-explicit-synthesis-lane-outcomes.md).
The later filter-only context runner is recorded in the
[counterexample-bank context runner report](reports/2026-08-16-filter-only-length-counterexample-bank-context-runner.md).
The command-local scheduler successor is recorded in the
[command-local counterexample-bank scheduler report](reports/2026-08-16-command-local-length-counterexample-bank-scheduler.md).
The later Engine-only observation seam is recorded in the
[opaque detailed synthesis cursor report](reports/2026-08-16-opaque-detailed-synthesis-cursor-foundation.md).
Its progressive Main runtime successor is recorded in the
[same-run Length filter batching report](reports/2026-08-16-progressive-same-run-length-filter-batching.md).
The active inline parser/profile boundary and its later context lifetime are
recorded in the
[inline Length where-clause runtime report](reports/2026-08-20-inline-length-where-runtime.md).
The older [one-shot contract report](reports/2026-08-13-one-shot-length-contract.md)
and the reports below remain useful landing history, but their version routing
and public API names are not current contracts. The historical modulo QF_LIA
witness boundary is recorded in the
[contract-only v2 modulo report](reports/2026-08-13-contract-only-v2-modulo.md).
The explicit role vocabulary, compact numbering, checked opaque-token boundary,
focused map path, and conditional Djex identities are recorded in the
[contract-only v3 target-role report](reports/2026-08-13-contract-only-v3-target-roles.md).
The explicit exact-case policy, accepted-renderer association, production
Exference bridge, and fake-protocol model replay are recorded in the
[contract-only v4 exact-case report](reports/2026-08-13-contract-only-v4-exact-spine-cases.md).
The positive-literal quotient grammar, policy-orthogonal case choice, shared
QF_LIA witness lowering, and production replay checks are recorded in the
[contract-only v5 quotient report](reports/2026-08-13-contract-only-v5-quotient.md).

## Contract vocabulary and module ownership

The passive finite-spine source vocabulary now lives in
`Leant.Synth.Length.Contract`. Modules that need only those assertions no
longer depend on the full synthesis engine. `Leant.Synth.Engine` owns neutral
synthesis and retained candidate provenance;
`Leant.Synth.Length.Command` owns both the established file grammar and the
separate inline structural parser. `Leant.Synth.Length.Where` owns the two
fixed list profiles, bounded-input admission, and physical-role resolution
over Djex's bounded parser/elaborator. Main alone orders authorization,
translation, resolution, and context creation for the active inline path.
`Leant.Synth.Length.Handoff` derives the opaque verified origin and owns the
candidate-specific correspondence checks and Djex problem sealing. Ranking
reaches that preparation through `Leant.Synth.Length.Adapter` and imports the
handoff refusal taxonomy only for closed classification. This gives contract
assertions, candidate authority, checked domain preparation, and live
execution policy distinct source owners.

## Post-verification sealing

`Leant.Synth.PostVerification` makes the boundary after callback acceptance
explicit. Without the startup opt-in, Main sends the opaque, nominal
`VerificationBatch` through the exact non-strict disabled identity path, which
performs no IO, cannot start a worker, and claims no validated ordering
authority. With the opt-in, the Length assessor instead gives
`sealPostVerificationBatch` opaque occurrence handles for ranking, minted from
that batch
inside a rank-2 `PostVerificationInput` epoch. Handle constructors and original
indices are private, and nominal roles prevent coercion; handles from another
batch inhabit a different abstract epoch and cannot be mixed without an
explicit unsafe operation. The seal productively bounds the original handles
and proposals, then rejects every omission, duplicate, out-of-range occurrence,
or over-limit tail without comparing or forcing candidate payloads. Only
success can construct the opaque `PostVerificationBatch`, which therefore
carries a complete occurrence permutation rather than a pruned, duplicated,
manufactured, substituted, or reassociated candidate batch.
An explicit filter operation uses the distinct total-partition seal below; it
does not weaken or overload this permutation contract.

### The behavioral-selection partition seal

`Leant.Synth.BehavioralSelection` is the separate structural boundary used by
the hard-selection path. `withBehavioralSelectionInput` mints private
occurrence handles from one exact `VerificationBatch` inside a fresh rank-2
epoch. The public facade keeps the input, handle, decision, selected receipt,
rejected receipt, and batch constructors opaque and exports no decision
builder. A package-internal domain adapter may import
`Leant.Synth.BehavioralSelection.Internal` to classify a supplied handle with
one retention or rejection payload, but it cannot manufacture a handle or
change its private original index.

`sealBehavioralSelectionBatch` first bounds the candidate occurrences, then
bounds the decision spine, requires one decision per occurrence, and checks
each private index for range before duplication. It reconstructs the exact
original `Verified` receipt rather than trusting a receipt in the decision,
then emits both the selected and rejected partitions in original callback
order, independent of decision order. Equal candidate payloads remain
different occurrences, and the seal neither compares nor forces candidate,
retention, or rejection payloads. Cyclic decisions stop at the caller's
maximum plus one. An out-of-range handle is checked defensively, although the
safe public and package-internal builders cannot construct one for the same
epoch.

This generic seal validates only a bounded total occurrence partition and its
association with the original callback receipts. In particular,
`BehaviorallyRejected` is not behavioral evidence: the generic layer does not
fingerprint, replay, or validate its rejection payload, apply an
unknown/inapplicable policy, inspect solver status, or establish a Lean proof.
The seal therefore cannot by itself authorize filtering. The current Length
selection adapters supply the narrower replay-only decision taxonomy, and
Integration plus Main require explicit per-command filter authority before
using their result. The generic boundary itself remains domain-neutral. Its
structural landing checkpoint is described by the
[behavioral-selection partition report](reports/2026-08-15-behavioral-selection-partition-seal.md),
while the connected Length path is recorded in the
[command-authorized filtering report](reports/2026-08-15-command-authorized-length-filtering.md).

### The Length ranking and selection adapters

`Leant.Synth.Length.PostVerification` is the scalar ranking adapter for the
permutation boundary. The Length ranker retains each receipt's safe original
index;
package-private `Ranking.Internal` and `PostVerification.Internal` modules
thread each batch-scoped occurrence handle as the only receipt-bearing field
in transient ranking state through preparation, live assessment, stable
partitioning, atomic fallback, and the final seal. That control flow is
written once, in `Leant.Synth.Length.Ranking.Generic`, over a closed
`LengthRankingDomain` class whose associated types name each domain's Djex
vocabulary (queries, receipts, validators, the live observation, and the
counterexample-bank limits, bank, scope, sample, and error). The scalar and
binary-product `Ranking.Internal` modules are its two instances: each keeps
its nominal assessment, failure, policy, and receipt types by wrapping the
shared structure in domain newtypes, supplies its own handoff and query
refusal classifiers, and hands the shared runners its bank surface and bridge
from `CounterexampleBank.Internal`. The replay cursor (batch-local raw MRU or
command-local nominal context) and every runner in the eager/deferred and
unbudgeted/v1/scoped matrix therefore exist once. The
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
request-owned contract. The startup bundle fixes its decoded domain-selected
contract, while an exact
`:synth --length-contract ... --` request can reuse that activated policy with
one separately decoded command-local contract. The inline filter request can
instead supply one resolved fixed-profile selection through the same authorized
request constructor; its empty provider-law set means unsupported
provider-dependent candidates retain a preparation refusal. The nominal pair stack mirrors
these rules in `Leant.Synth.Length.SpinePair.PostVerification`.
Input or proposal failure preserves the original opaque verification batch,
exposes no sealed output, and withholds the unsealed associated plan.
Operational ranking failure already
produces an original-order all-`Unassessed` ranking and passes through the same
seal. Main selects this path only for an explicitly loaded and activated
policy, except that an ordinary or explicit rank command with no contract keeps
the disabled identity when no policy is active. Without activation, any
explicit command contract is rejected before file IO. Replayed
counterexamples may rank and receive a bounded model-relative note, and an
explicitly enabled complete finite-box traversal may receive a separate bounded
positive note with checked/applicable counts and visible vacuity. Ranking never
prunes or proves source behavior; raw `sat`, `unsat`, and `unknown` grant no
proof authority.

`Leant.Synth.Length.Selection` and
`Leant.Synth.Length.SpinePair.Selection` are nominal hard-selection adapters
over those existing assessors. Their established `...WithPolicy` entrances
keep the raw-MRU compatibility assessment. Additive package-private
`...WithPolicyAndCounterexampleBankContext` entrances select the matching
context-aware assessor and are the only Selection calls used by Integration's
filter contexts. Each opens a fresh behavioral-selection epoch,
uses the ranking report's safe original index to select the matching private
occurrence handle, and makes one total decision. Candidate-local preparation
refusal, `Unassessed`, every heuristic solver status, `BoundedPositive`, and
`ApplicableDomainEstablished` are explicit retention classes. Only an
independently replayed `Counterexample` becomes a rejection, carrying that
domain's exact final replay receipt and optional simplification metadata. A raw
`sat`, `unsat`, or `unknown` never rejects.

The adapter then invokes the generic total-partition seal. Success exposes
opaque, intrinsically associated `BehaviorallySelected` and
`BehaviorallyRejected` wrappers in original callback order. Decision order and
the ranking permutation have no selection-order authority. Every
post-verification, ranking, ranking-absence, original-index, candidate/decision
limit, or seal failure instead returns one preserve-all result containing the
literal original `VerificationBatch`; no partial rejection escapes. Scalar and
pair retentions, rejections, failures, and results cannot be cast across the
domain boundary. Preserve-all rolls back the candidate partition only; any
context transitions completed while constructing the failed report remain.

`Leant.Synth.Length.Presentation` traverses selected and rejected wrappers
directly, without zipping candidate text to detached evidence. Retained finite-
box and applicable-domain evidence keeps the existing positive note. Rejection
uses the existing bounded counterexample or simplification renderer verbatim.
Main binds only the survivor presentations as `itN` and prints omitted
occurrences separately as `rejected`. An accepted all-rejected partition is a
handled batch result but remains pending in the command accumulation. It may
consume the one permitted same-run successor; only a completed continuing run
may enter the next provider or classical route, with no new binding or
immediate cache mutation. Final aggregate all-rejection prints every
accumulated row and clears the old synthesis-splice cache once. A later terminal
survivor or preserve-all batch prints its candidate rows before the retained
earlier rejections. Partial and zero-rejection selections remain terminal. Assessment
failure prints one mode-neutral preserve-all warning, retains the complete
verification batch, and shows at most five unannotated original candidates.

The established ranking and direct Selection compatibility paths still obtain
their assessments through one fresh raw four-entry batch-local MRU. The
Integration filter path instead uses the supplied nominal context bank. Both
stores retain inputs rather than verdicts; a later occurrence must independently
replay and associate a sample against its own checked problem before it can be
rejected. Main supplies one filter context across every assessment in a
command; Integration's fresh-per-call compatibility wrapper remains available
to other callers. No behavior mode, context, replay bank, contract request, or
selection result enters `ReplState`.

The ranking foundation is detailed in the
[post-verification assessment seam report](reports/2026-08-11-post-verification-assessment-seam.md)
and the
[explicit integration report](reports/2026-08-12-explicit-length-ranking-integration.md).
The hard-selection adapter and command integration are specified by the
[command-authorized Length filtering report](reports/2026-08-15-command-authorized-length-filtering.md),
with the historical lane-local scheduling checkpoint in the
[survivor-refill report](reports/2026-08-15-lane-local-length-survivor-refill.md).
The context-aware successor is recorded in the
[filter-only bank runner report](reports/2026-08-16-filter-only-length-counterexample-bank-context-runner.md).
Its Main scheduler successor is recorded in the
[command-local counterexample-bank scheduler report](reports/2026-08-16-command-local-length-counterexample-bank-scheduler.md).

## Provider instantiation evidence

*Moved from the README's rank-N tour. The transcripts these paragraphs refer
to remain in the [README](../README.md#rank-n-and-impredicative-goals).*

One exact provider may retain several distinct successful instance-head
vectors. In the same transcript, heads for `AlternativeChoice Wrap` and
`AlternativeChoice (Pair Nat)` produce exactly
`Higher.alternative («F» := Higher.Wrap)` and
`Higher.alternative («F» := (@Higher.Pair Nat))`. In the recorded rank-N
acceptance transcript, standalone Djinn ranked `Wrap` first, standalone
Exference ranked `Pair Nat` first, and combined mode used Djinn's order after
stable exact-spelling deduplication. A different structural profile may change
that order; the semantic requirement is that every mode retain both exact
alternatives once. The transcript also carries one heterogeneous two-binder
vector with kind arities one and two, respectively, and requires
`Higher.multiVacuous («F» := Higher.Wrap) («G» := (@Higher.Triple Nat))` in
all three modes.

Extraction is deliberately finite and local. It opens the leading type
binders retained on the source provider, retains its instance constraints,
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
arity, including source spines wider than six binders. The consumer examines
at most the expected arity plus one list cell before traversing arguments, so
overwide and cyclic vectors fail without an unbounded length check. The
aggregate prefix is taken before an
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
[provider metadata fitting report](reports/2026-08-09-occurrence-local-provider-metadata-fitting.md).

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
[higher-kinded contextual assignment report](reports/2026-08-10-higher-kinded-contextual-assignments.md).
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
[`synth-quantified-provider`](../test/synth-quantified-provider.txt) transcript
checks both the query-supplied and provider-only paths under standalone Djinn,
standalone Exference, and combined search. The dedicated
[`synth-provider-contextual-assignment`](../test/synth-provider-contextual-assignment.txt)
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
[contextual provider-assignment report](reports/2026-08-09-contextual-provider-assignments.md).
The
[`synth-provider-implicit-visible-result`](../test/synth-provider-implicit-visible-result.txt)
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
[`synth-provider-metadata-fitting`](../test/synth-provider-metadata-fitting.txt)
transcript additionally makes rendering and result fitting inseparable. Its
first instance contributes the canonical type with an implicit forall, while a
second instance contributes the same Djex type with an explicit forall. The
goal forces the explicit selection, and the provider consumes a value at that
selected type; Exference and combined mode must therefore render both the
explicit provider argument and `fun _ x => x`. Lean verifies that result at a
64-step search bound. The
[`synth-provider-higher-kind-assignment`](../test/synth-provider-higher-kind-assignment.txt)
transcript separately requires the mixed kinded/rank-N vector and the exact
vacuous and heterogeneous multi-vacuous applications under Djinn, Exference,
and combined search. It also requires the two distinct `Wrap` and `Pair Nat`
applications of one provider exactly once, while allowing the engines to rank
them differently. Unit regressions pin the kinded wire format, kind/order
retention, whole-vector deduplication, finite bounds, and the same successes in
all three engine modes. The current exact-vector contract is recorded in the
[correlated instance-head assignment report](reports/2026-08-05-correlated-instance-head-assignments.md);
the earlier scalar API remains documented in the
[provider-local instance-head report](reports/2026-08-05-provider-local-instance-head-evidence.md).
The focused
[`synth-provider-structural-assignment`](../test/synth-provider-structural-assignment.txt)
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
structural `both` mode, every proper prefix is Djinn-only and the full lane
runs both engines; a singleton inventory is already the full lane. Legacy
preserves its combined singleton/full lanes and Djinn-only intermediate
prefixes. `providerStagesWithRanking` owns this choice while the original
`providerStages` retains the legacy schedule. Discovery order, the shared
deadline, engine budgets, verification quotas, and final merge do not change.
The exact live transcript deliberately places an
unrelated class-constrained provider before a two-provider composition and
verifies that the width-four lane recovers
`Demo.consume (Demo.produce x)`. It also covers an atomic provider,
provider-free first-result ordering, and combined-mode reuse.
It is checked in
[`synth-djinn-providers`](../test/synth-djinn-providers.txt).

The separate
[`synth-both-frontier`](../test/synth-both-frontier.txt) transcript pins the
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

### Exact provider assignment vectors

*Moved from the README's engine notes.*

For an exact polymorphic provider whose source constraints can determine its
visible type arguments, discovery may attach active-instance-head evidence.
It derives the required type-binder count from the source and inspects at most 32 heads in
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
16 distinct vectors survive per provider. The seed attempts and all recursive
instance-closure branches share 128 resolution attempts per provider. This
counter uses an `IO.Ref`, so restoring a failed branch's metavariable state
does not replenish its work budget. Optional assignment discovery also gets
at most 2000 Lean heartbeats, clamped to the command's remaining allowance.
A local heartbeat timeout or ordinary assignment exception yields no exact
vector while preserving the provider and inventory already collected.
Interruptions, other runtime exceptions, and exhaustion of the original
command budget still propagate; the original context is checked after both
failure and success. These are search work limits, independent of source
binder arity and the complete-vector acceptance rules. The live regression
`runghc -isrc test-church/check-provider-discovery.hs` covers `Or.by_cases`,
later usable providers, state rollback, and explicit fault injection at that
assignment boundary.

`FDepth` and legacy raw `FInst`
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

## Proper-type applications and family plans

*Moved from the README's engine notes.*

Proper-type applications headed by a bound constructor variable or an
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

## Rank-N plan families and bounds

The dedicated
[`synth-six-binder-rankn`](../test/synth-six-binder-rankn.txt) transcript
disables live-library premises and pins that exact candidate through final
Lean elaboration under standalone Djinn, standalone Exference, and combined
mode. The same golden first discovers a six-binder active-instance assignment
and retains all six named quantified applications in every mode. Unit coverage
separately retains the six-argument function-elimination shape and exact
provider evidence across the same three engines. The earlier
[`synth-five-binder-rankn`](../test/synth-five-binder-rankn.txt) transcript remains
as the historical predecessor.

The live
[`synth-quartic-rankn`](../test/synth-quartic-rankn.txt) transcript makes the new
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
independently checked candidate is admitted early in that search. The live
run nevertheless continues along its bounded ranked tail and reports
`queue limit pruned 39308` when the step limit is reached (see
[test/synth-quartic-rankn.golden](../test/synth-quartic-rankn.golden)); that
note records an incomplete tail, not a failure to find or check the displayed
candidate.

The live
[`synth-quintic-rankn`](../test/synth-quintic-rankn.txt) transcript is the exact
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
The historical sentinel used seven binders to stay outside the then-current
six-binder instantiation cap. That cap has since been replaced by
source-directed correlated instantiation, so the transcript remains a useful
regression but no longer identifies a current capability boundary.

### Source-directed rank-N and Church acceptance

Djex now derives correlated assignments from quantified source and target
structure before resorting to bounded tuple enumeration. Source binder count
determines assignment arity; multiple independently selected polytypes and
compound types containing nested quantifiers can appear in one candidate.
Finite fallback and occurrence-planning limits still apply to the overall
search. Exhausting an incomplete rank-N route cannot justify negative evidence.

If Exference's established strict and relaxed searches both return no groups,
Leant also tries a checked route with multi-constructor patterns disabled.
This prevents decomposition of an irrelevant recursive input such as Lean's
expanded `Int`/`Nat` schema from consuming the entire budget before an ordinary
polymorphic result is introduced. The route uses its own exact Exference
options; when a typed sidecar is available, those options remain part of the
recovered run authority. It never displaces a successful candidate from either
earlier route. Candidates without an optional typed graph still pass through
the existing compatibility renderer and mandatory Lean verification.

If all of those searches miss, a final family of routes keeps only the
historical prelude declarations required by the goal, exact instantiation
arguments, and retained Lean declarations. The dependency closure includes
type synonyms, constructor fields, class constraints and superclasses, and
structural tuple identities. Every discovered provider and foreign declaration
is retained. Unrelated stock constructor families such as `Maybe` or `Either`
can otherwise consume the search budget while a polymorphic argument is being
constructed through successive forall layers. The fallback keeps the original
variable identities and provider ratings, and stores its actual checked
session in the candidate authority. Length assessment consequently reads the
same reduced inventory that admitted the candidate. A successful earlier
candidate is unchanged, and an unsuccessful fallback adds no negative proof.

The Lean renderer keeps the original fragment's explicitness information even
when Djex coalesces a forall spine. In particular, an implicit forall between
term arguments begins a new lambda boundary. Flattening that boundary would
move a subsequent synthesized term binder into an implicit type-binder slot.
Visible type arguments can also retain a quantified shape with ambient `_`
holes; bound variables retain canonical lexical identities. Those holes are
emission syntax after the complete correlated assignment has been checked,
and never serve as evidence for that assignment.

Expected result types also propagate backward into application argument
domains. For example, `F (forall b, b -> b)` determines the value domain in
`forall a, a -> F a`, letting the renderer reconstruct the argument's explicit
Lean type lambda. A plain `let` alias retains a forall reached after ordinary
arguments, so the same fitting applies through a local factory alias;
destructuring still exposes the structural result needed by its patterns.
A specified closed structural type argument also specializes the consumed
source binder directly. This is needed when a partially applied factory is
stored in a let before its final expected result is available: both the
constructed argument's type lambda and the alias's remaining forall spine
must survive. Neutral syntax with ambient holes or nominal constructors does
not supply an invented rigid fragment; exact retained Lean evidence and the
caller's expected type remain authoritative for those cases.
When a single-use plain let hides that expected result and its applied alias
has no exact domain, an additional rendering pass substitutes the binding
capture-safely and fits the complete application against the original goal.
The shared simplifier does not contract eta redexes or duplicate bindings.
All original variants remain first; the inlined form has its own bounded
metadata cohort, so a full original cohort cannot suppress it. The three
32-variant domain lanes bound each form at 96 variants, and the two forms
together at 192. Candidate quotas still count semantic groups, with serial
verification of their variants under the existing request deadline. A visible
type argument in the middle of an application retains the rest of its source
forall spine, including placeholders after later ordinary arguments.
If such a selected binder is implicit, the renderer exposes the checked
application at its original known head (`@factory seed ...`). Lean does not
accept `@(factory seed) ...`; the complete source binder stream therefore
supplies every intervening type and instance placeholder from the original
head. Leading named global type assignments retain their existing spelling.
Explicit underscores in instance slots are reconstructed by Lean's instance
search, as checked by the constructive `MixedSpineSyntax.lean` witnesses.
A non-exact visible type annotation spells its known forall binders explicitly.
When its ambient holes are resolved from a target containing implicit foralls,
argument fitting preserves those resolved type identities but follows the
annotation's actual binder visibility. The alignment follows known syntax
nodes only; a wildcard leaf neither opens nor changes its unknown fragment.
Final-result matching ignores the explicit/implicit forall flag, which Lean's
definitional equality also ignores; all rigid identities, scope checks, and
capture prevention remain intact. Argument/evidence matching retains its
existing visibility policy. A closed explicit annotation can therefore match
an implicitly quantified target while its own value retains explicit lambda
binders. If a global application with leading exact type arguments later
exposes an implicit binder, the positional rendering retains that leading
vector's exact visibility and universe-domain metadata, consuming it only
at actual visible argument nodes. Malformed retained vectors still fail closed.
For an inferred polymorphic argument before a later forall layer, Lean may
elaborate the value before learning its final expected type. The renderer
therefore writes that value's known implicit type binders as `fun {_} ...`.
This applies only when the argument domain still contains an unresolved opened
source variable before final-result fitting; an already exact domain keeps its
existing spelling. It reconstructs those binders, including boundaries inside
the value's lambda spine, from the already fitted fragment. Anonymous private markers are added
after source-name uniquification and never occur in a term body. This adds no
type identities or candidate variants; final arguments and ordinary applications
retain their existing compact spelling.
When bottom-up argument analysis leaves an opened forall variable unresolved,
that result is not treated as an exact rigid input type. The renderer instead
fits the nested application against its caller's expected domain. This reaches
polymorphic let aliases inside a Church continuation whose result is determined
only by the enclosing consumer. Genuine ambient variables remain rigid, and a
conflict with a known rigid argument still prevents that fitting route.
Directly constructed sum scrutinees additionally receive qualified `Sum.inl`
or `Sum.inr` variants, with `Or` variants for propositions. Leading-dot syntax
alone has no expected family at a match scrutinee. These alternatives remain
subject to the same mandatory Lean verification as every other candidate.

Live exact-provider evidence uses source-derived arity as well. The nominal
class-context payload has its own finite 128-argument guard, independent of
the number of quantified binders. The new
[`synth-church-providers`](../test/synth-church-providers.txt) fixture checks
eight- and twelve-binder source vectors against actual active instances. Its
opaque provider declarations are explicit premises of that fixture; kernel
acceptance is relative to those premises.
The separate
[`synth-church-layered-providers`](../test/synth-church-layered-providers.txt)
fixture exercises named global factories through successive term/forall
layers, with alpha-reused identity and Boolean arguments. Its accepted axiom
inventory is exactly the declared seed type, seed value, result constructor,
and corresponding factory; the harness rejects any additional premise.

The [Church harness](../test-church/README.md) translates all 350 resolved source
signatures from the versioned Djex manifest and records source, manifest, and
executable hashes. It replays the complete displayed candidate text in a fresh
Lean file, checks every selected case was reached, and requires an empty axiom
inventory for every generated corpus declaration. The compact
[`synth-church-rankn`](../test/synth-church-rankn.txt) fixture additionally covers
explicit and implicit rank-seven continuation encodings, distinct polymorphic
arguments, composition, and nested construction with an ambient dependency.
Nineteen source signatures require a supplied element default; those cases
are separate from the 315 pure total cases and 16 integer-provider cases.
Each quantified type receives its own inferred Lean universe. Successful
elaboration establishes a valid universe instantiation, not inhabitation
under all independent universe assignments and not impredicativity of Lean's
`Type` hierarchy. No Church implementation is supplied as a synthesis provider.
