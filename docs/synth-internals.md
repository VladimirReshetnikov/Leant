# `:synth` internals

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
  - [Current applicable-domain validation](#current-applicable-domain-validation)
  - [The origin probe](#the-origin-probe)
  - [Live input-box validation and query-first replay](#live-input-box-validation-and-query-first-replay)
  - [Refusals, atomic fallback, and lifecycle owners](#refusals-atomic-fallback-and-lifecycle-owners)
- [SpinePair ranking and post-verification](#spinepair-ranking-and-post-verification)
- [Configuration and its file grammar](#configuration-and-its-file-grammar)
  - [Policy builders and usable-work budgets](#policy-builders-and-usable-work-budgets)
  - [`Configuration.File`: the current versionless JSON grammar](#configurationfile-the-current-versionless-json-grammar)
  - [Fixed startup policy and domain selection](#fixed-startup-policy-and-domain-selection)
  - [File acquisition](#file-acquisition)
  - [Contract-only files and the length-contract command](#contract-only-files-and-the-length-contract-command)
  - [Integration and one-shot contracts](#integration-and-one-shot-contracts)
- [Contract vocabulary and module ownership](#contract-vocabulary-and-module-ownership)
- [Post-verification sealing](#post-verification-sealing)
  - [The Length domain adapter](#the-length-domain-adapter)
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
schemes are instantiated at a bounded set of query and environment types, and
impredicative instantiation is admitted under a guard that never invents a
polytype the checked input did not supply.

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

## Length handoff and problem sealing

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

The policy runs after the four-entry newest-first MRU replay and before the
origin probe. An ordinary inapplicable result or any width, generated-branch,
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
  -> recursive piecewise-affine fallback
```

Each leaf first uses the complete atomic scanner. Recursive expansion runs only
for its singleton ignored alternative when the relation still contains
minimum, maximum, or natural monus, so an earlier exact result remains
authoritative. The recursive grammar admits compact inputs, natural literals,
normalized sums, positive scales, minimum, maximum, and monus. A quotient,
modulo, conditional, result reference, out-of-range input, retained zero
scale, or another unsupported child rejects that fallback atom; an earlier
private stage may still have handled the complete leaf.

For child values `L` and `R`, the exact alternatives are:

```text
min(L,R)  -> [L <= R;     value L] | [R + 1 <= L; value R]
max(L,R)  -> [R <= L;     value L] | [L + 1 <= R; value R]
L monus R -> [L <= R;     value 0] | [R + 1 <= L; value L - R]
```

The first case owns equality. Left-child alternatives precede right-child
alternatives, descendant guards precede the current selector, and the final
relation rule comes last. Signed coefficients produced by positive monus
branches transfer exactly into the natural positive-sided rule
representation. The closure uses one immutable snapshot per pass and fires
each source-ordered rule at most once.

Generated-branch admission counts the raw formula-DNF and recursive-alternative
Cartesian product before cleanup. Canonical original literal sets are
re-expanded in set order before rule and closure accounting. Every surviving
branch must bound every compact input. Bounded branches form a
lexicographically ordered, componentwise-maximal box antichain; incomparable
boxes are never replaced by a hull. Visits count overlaps, a global bounded set
deduplicates assignments, and Djex replays the original checked precondition
and postcondition once per assignment in global lexicographic order. Derived
guards, rules, boxes, and solver status never replace this query-owned replay.

The scalar discriminator retains `[[2,3],[3,2]]` with two boxes, 24 visits,
15 unique assignments, and ten applicable assignments. The product
discriminator retains `[[2,2]]` with 1/9/9/9 box, visit, unique, and
applicable counts; its 32 raw alternatives distinguish branch caps 31 and 32
before contradictory cases disappear.

Under deferred opening the MRU/domain/origin prefix remains before process IO.
A pure establishment or counterexample opens no worker. The first live miss
opens one lexical session without repeating the prefix; the remaining
candidates stay in that scope. The current policy and deletion rationale are
recorded in the
[current applicable-domain policy report](reports/2026-08-15-current-length-applicable-domain-policy.md).
The detailed grammar, cap precedence, receipt identity, and replay authority
are owned by Djex's
[current applicable-domain surface report](../lib/Djex/docs/reports/2026-08-15-current-length-applicable-domain-surface.md).
The older strategy reports are non-normative development history.

### The origin probe

The current startup policy inserts one query-owned origin probe after all four
bank entries—and after the applicable-domain pass is inapplicable—before that
candidate's live Z3 query. Programmatic policies can enable the same probe
explicitly. Leant supplies no
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

### Live input-box validation and query-first replay

Without input-box validation, `unsat`, `unknown`, and status-only `sat` remain
neutral. The current startup policy and explicit input-box builder use a live
`unsat` only to trigger Djex's independent exhaustive replay of
caller-selected per-input inclusive maxima. A discovered violation becomes the
ordinary `Counterexample`, is
stably demoted, and updates the MRU bank. Complete traversal becomes
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
Exceptions propagate instead of producing a ranking. Programmatic callers may
retain separate per-query budgets or explicitly select the runtime-unscoped v1
shared owner. The current startup route and the scoped programmatic builder use
the owner-thread-affine v2 lease and cooperative phase checkpoints. Neither owner
claims asynchronous interruption of arbitrary callback code. Main invokes
this foundation only after the explicit startup opt-in described above; it
never infers an executable path, contract, or policy. The foundation is
detailed in the
[live Length ranking foundation report](reports/2026-08-11-live-length-ranking-foundation.md).
The batch-local replay optimization and its unchanged trust and identity
boundaries are recorded in the
[Length counterexample seed replay report](reports/2026-08-13-length-counterexample-seed-replay.md).
Its fixed four-entry MRU policy and Djex's query-owned raw-input replay boundary
are detailed in the
[Length input replay bank report](reports/2026-08-14-length-input-replay-bank.md).
The historical checkpoint which introduced the all-zero probe, exact
MRU/origin/live order, and failure and identity boundaries is detailed in the
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

## SpinePair ranking and post-verification

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
[live binary-product Length ranking report](reports/2026-08-14-live-binary-product-length-ranking.md).

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

The retained policy builders are persistent and orthogonal for programmatic
callers. Applicable-domain construction has only the short current builder;
its lower analysis stages are private inside Djex. The startup decoder always
enables the input box, origin probe, both non-vacuous
preferences, recursive piecewise-affine applicable-domain validation,
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
`executableLaunch` member. The current recursive piecewise-affine algorithm is
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
- the four-entry MRU bank and all-zero origin probe;
- independent post-`unsat` input-box traversal;
- current recursive piecewise-affine applicable-domain traversal;
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
MRU state, or presentation across the scalar/product boundary.

Construction remains pure. An all-pure batch captures and checks the scoped
clock but performs no executable or access-check IO. The first live miss opens
one lexical session for the remaining suffix. Any access, staging, live,
replay, association, forcing, or finalization failure preserves the established
original-order atomic fallback.

The current schema reset and deleted compatibility surface are recorded in the
[versionless startup configuration report](reports/2026-08-15-versionless-length-ranking-configuration.md).
The recursive semantic and evidence boundary is recorded in the historical
[recursive piecewise-affine Length ranking report](reports/2026-08-15-recursive-piecewise-affine-length-ranking.md)
and Djex's
[recursive piecewise-affine applicable-domain report](../lib/Djex/docs/reports/2026-08-15-recursive-piecewise-affine-length-applicable-domain.md).
The former report's startup-number discussion describes its landing checkpoint,
not the current grammar.

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
uses `loadLengthAssessmentConfigurationFile` for its explicit startup CLI path;
there is no scalar-only startup loader. There is still no discovery or default
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
vocabulary. `Leant.Synth.Length.Command` recognizes only the exact
`--length-contract` spelling and requires a standalone `--`, so malformed
request syntax cannot disappear into Lean goal text.

### Integration and one-shot contracts

`Leant.Synth.Length.Integration` authorizes an explicit request from the
already activated policy before Main admits or opens its contract path. The
result is an opaque command-local choice containing either the disabled
identity or one strict policy beside one lazy scalar-or-pair selection.
`LeanLengthContractSelection` is passive and nominal: dispatch chooses exactly
one scalar or pair occurrence-sealed assessor, and the two ranking/evidence
result types remain separate. Startup and one-shot contracts enter the same
lifetime owner; the request does not remember a second policy/contract origin
tag. Main calls `loadLengthContractFile` and then
`explicitLengthAssessmentRequest` once before translating the goal and threads
that value through every retry and synthesis lane. It never writes the request
to interactive state or a snapshot. The selection-suffixed entrances have been
removed; the unsuffixed decoder, loader, and request names now carry the
nominal scalar-or-pair selection instead of their former scalar-only types.

The current reset is recorded in the
[versionless Length contract report](reports/2026-08-15-versionless-length-contract.md).
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

### The Length domain adapter

`Leant.Synth.Length.PostVerification` is the first domain adapter for that
boundary. The Length ranker now retains each receipt's safe original index;
package-private `Ranking.Internal` and `PostVerification.Internal` modules
thread each batch-scoped occurrence handle as the only receipt-bearing field
in transient ranking state through preparation, live assessment, stable
partitioning, atomic fallback, and the final seal. That control flow is
written once, in `Leant.Synth.Length.Ranking.Generic`, over a closed
`LengthRankingDomain` class; the scalar and binary-product `Ranking.Internal`
modules are its two instances and keep their nominal assessment, failure,
policy, and receipt types by wrapping the shared structure in domain
newtypes. The
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
[post-verification assessment seam report](reports/2026-08-11-post-verification-assessment-seam.md)
and the
[explicit integration report](reports/2026-08-12-explicit-length-ranking-integration.md).

## Provider instantiation evidence

*Moved from the README's rank-N tour. The transcripts these paragraphs refer
to remain in the [README](../README.md#rank-n-and-impredicative-goals).*

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
`both` mode, only the singleton and full lanes rerun Exference; intermediate
prefixes are Djinn-only. The exact live transcript deliberately places an
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
independently checked candidate is admitted at search step 30. The live run
nevertheless continues along its bounded ranked tail and reports
`queue limit pruned 36475` when the step limit is reached; that note records an
incomplete tail, not a failure to find or check the displayed candidate.

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
The sentinel is now seven-binder so the same occurrence-planning witnesses
remain outside Djinn's independent six-binder instantiation cap.
