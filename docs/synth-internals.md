# `:synth` internals

*How Leant's synthesis pipeline is put together: the semantic-origin record,
provider bindings, the Length handoff, and the invariants each dated report
pins. The [README](../README.md) keeps the user-facing tour of `:synth`; this
document holds the design detail that used to sit inline there.*

The material below is a specification of internal boundaries. Each paragraph
names the module that owns a boundary and links the report that recorded it,
so a reader who wants the *why* of a rule can follow the link, and a reader
who wants the *what* can stop at the paragraph.

---

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
[unified checked Length handoff policy report](reports/2026-08-13-unified-length-handoff-policy.md).
The opaque carrier handoff and its trust limits are recorded in the
[Length certificate-carrier handoff report](reports/2026-08-13-length-certificate-carrier-handoff.md).
The live exact-context wire, active-instance provenance, and inventory-wide
ground-fact bridge are recorded in the
[contextual-provider ground-discharge report](reports/2026-08-13-live-contextual-provider-ground-discharge.md).
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
[live Length ranking foundation report](reports/2026-08-11-live-length-ranking-foundation.md).
The batch-local replay optimization and its unchanged trust and identity
boundaries are recorded in the
[Length counterexample seed replay report](reports/2026-08-13-length-counterexample-seed-replay.md).
Its fixed four-entry MRU policy and Djex's query-owned raw-input replay boundary
are detailed in the
[Length input replay bank report](reports/2026-08-14-length-input-replay-bank.md).
The version-3 all-zero checkpoint, exact MRU/origin/live order, and failure and
identity boundaries are detailed in the
[Length origin-probe orchestration report](reports/2026-08-14-length-origin-probe-orchestration.md).
The opt-in finite-box policy, its unsat-as-trigger-only boundary, positive
receipt, and additive configuration grammar are detailed in the
[unsat-triggered bounded Length validation report](reports/2026-08-14-unsat-triggered-length-input-box-validation.md).
The separately enabled stable preference for non-vacuous positive receipts is
detailed in the
[non-vacuous bounded-positive ordering report](reports/2026-08-14-non-vacuous-bounded-positive-ordering.md).
The directly bounded pre-live pass, separate non-vacuous preference, and
unchanged configuration boundary are recorded in the
[directly bounded applicable-domain report](reports/2026-08-14-directly-bounded-length-applicable-domain.md).

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
[explicit live Length ranking configuration report](reports/2026-08-11-explicit-live-length-ranking-configuration.md).
The later
[single-owner policy checkpoint](reports/2026-08-13-length-ranking-policy-single-ownership.md)
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
[bounded live Length ranking configuration-file report](reports/2026-08-11-bounded-live-length-ranking-configuration-file.md).

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
[bounded acquisition report](reports/2026-08-11-bounded-live-length-ranking-configuration-acquisition.md).

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
[one-shot contract report](reports/2026-08-13-one-shot-length-contract.md).
The version-2 extension and its QF_LIA witness boundary are recorded in the
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
