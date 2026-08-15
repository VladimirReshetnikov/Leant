# Live Length ranking foundation

> **2026-08-14 follow-up.** Later eligible candidates now try at most four
> distinct prior input vectors from a fixed newest-first MRU bank. Each attempt
> calls Djex's query-owned `replayLengthSMTLibCounterexampleInputs` boundary, so
> the sealed query freshly evaluates and associates the inputs without Leant
> reconstructing SMT symbols or bindings. A hit avoids one live query; after
> all misses, the candidate follows the serial live path described below. The
> original one-entry checkpoint is recorded in the
> [Length counterexample seed replay report](2026-08-13-length-counterexample-seed-replay.md),
> and the current bounded policy is detailed in the
> [Length input replay bank report](2026-08-14-length-input-replay-bank.md).
>
> **Later 2026-08-14 follow-up.** An additive opt-in can use `unsat` only as a
> trigger for independent exact-query finite-box validation. A discovered
> counterexample follows the existing stable demotion and MRU rules; complete
> traversal produces neutral `BoundedPositive` evidence, and traversal failure
> activates the established atomic fallback. See the
> [unsat-triggered bounded validation report](2026-08-14-unsat-triggered-length-input-box-validation.md).
>
> **Later 2026-08-14 follow-up.** Additive startup configuration version 3
> inserts Djex's query-owned canonical origin replay after all four MRU misses
> and before the candidate's live query. A hit follows the ordinary
> counterexample/MRU/demotion path, a miss is no evidence, and evaluation or
> association failure activates indexed atomic fallback. The lexical worker is
> already open and capability-probed before candidate processing, so a hit
> skips a query transaction and ordinal, not process launch. See the
> [origin-probe orchestration report](2026-08-14-length-origin-probe-orchestration.md).
>
> **Later 2026-08-14 follow-up.** A nominal canonical-`Prod` sibling now
> consumes Djex's live pair facade under the same domain-neutral execution
> policy and common session limits. It has product-specific query-first replay,
> evidence, assessments, fallback diagnostics, presentation, and batch-local
> MRU state; scalar definitions and behavior remain unchanged. The library
> checkpoint is detailed in the
> [live binary-product Length ranking report](2026-08-14-live-binary-product-length-ranking.md).

Date: 2026-08-11

## Outcome

`Leant.Synth.Length.Ranking` is now the narrow Leant consumer of Djex's public
live Length/Z3 facade. It accepts four explicit inputs:

- a validated `LengthSMTLibExecutionConfig`;
- bounded `LengthEvaluationLimits`;
- a caller-supplied `LeanLengthContract`; and
- the complete `[Verified DetailedVerificationVariant]` batch.

The module does not discover an executable, infer a contract, choose a digest
pin, or read configuration from ambient process state. Main can now call it
through an explicit startup-owned integration facade; that facade supplies a
bounded file, pinned-by-default activation, and a fixed decoded contract rather
than weakening this module's explicit inputs. The activated policy can also be
paired with one separately decoded contract-only version 1, 2, 3, 4, or 5
document for an explicit
`:synth --length-contract ABSOLUTE-PATH -- TYPE` command. This changes contract
lifetime, not the ranking module's authority or input shape.

The one-shot document has the exact format string
`leant-finite-list-spine-length-contract` and only a `contract` payload beside
those two root fields. Version 1 reuses the unchanged compatibility grammar;
version 2 adds positive-literal Natural modulo to contract and provider-transfer
expressions through that same bounded parser owner. Version 3 retains that grammar
and requires an exact ordered target-role vector: every physical target argument is
either `observed-spine` or `unobserved-target`, with a maximum of eight. Older
contract documents and the startup configuration reject the field. Version 4
retains the version-3 grammar and additionally requires the sole exact
zero/step candidate-case policy; older versions reject that field. Version 5
requires the role vector and an explicit choice of either `cases-rejected` or
`exact-spine-zero-step-v1`, and adds positive-literal Natural floor quotient.
None of these versions contains execution, activation, artifact, response, or
replay policy. A shared package-private acquisition leaf owns the same
absolute-path, POSIX descriptor, byte, timeout, and cleanup rules for both file
facades.

## Admission and preparation

Input admission productively inspects at most Djex's public live-session maximum
plus one candidate. The current maximum is 64. Maximum-plus-one returns a
structured limit error before the contract or any candidate handoff is touched,
so an unbounded candidate tail cannot trigger unbounded preparation.

For an admitted batch, Leant completes the entire pure preparation pass before
opening a worker. For each candidate it attempts to bind the callback-verified
variant to an exact typed origin. An unmatched Djinn or compatibility spelling
has no such origin and remains `Unassessed`. For an eligible spelling the origin
is usually the displayed Exference group itself. If combined-engine exact-text
deduplication displayed an earlier compatibility-only occurrence, a private
variant-scoped witness may instead refer to the first bounded later Exference
occurrence with identical bytes. The displayed route, display ordinal,
ordering, group sidecar, and sibling variants do not change.
`prepareCheckedLengthProblem` preserves the singleton/ordinal-zero association
for startup, contract-only versions 1--3, and version 5's explicit
`cases-rejected` policy. The explicit exact-case policy in version 4 or 5
instead uses the origin's own renderer ordinal and requires the retained
graph to re-render that exact alternative to the callback-accepted text before
binding its family provenance, inventory, provider assumptions, and explicit
contract. A graph may have multiple valid Lean renderings under that policy; a
sibling spelling or a missing/changed ordinal does not gain the accepted
occurrence's authority.
Eligible checked problems are then sealed into canonical QF_LIA queries. A
version-2 modulo expression is retained passively until this Djex boundary.
Djex normalizes it and lowers every surviving occurrence to private,
deterministically allocated quotient/remainder equations using only QF_LIA;
it emits no SMT-LIB `mod` term and requests no witness values. Version-1
startup and one-shot documents remain unchanged, and existing no-modulo query
identities remain byte-identical. Version 5 quotient uses the same private
Euclidean witness equations and deterministic mixed witness order, projects
the quotient rather than the remainder, emits no SMT-LIB `div`, and is
independently recomputed during replay.

For every grammar version, the checked Handoff converts the decoded case
policy and optional target-role vector exactly once into Djex's closed
`LengthInterpretationPolicySource`, and it does so only after the established
exact-origin, renderer, family, and provider checks. Startup and contract-only
versions 1--2 select the legacy case-rejecting source; version 3 and version 5
`cases-rejected` select the explicit-role case-rejecting source; version 4 and
version 5 `exact-spine-zero-step-v1` select the explicit-role exact source.
The otherwise invalid exact-without-roles pair is still refused after family
and provider resolution. Handoff then calls only the unified, session-owned
session, contract, and problem sealers. It does not use Djex's legacy,
role-aware, or exact compatibility problem wrappers, so later stages cannot
reselect role or case authority independently. Renderer association remains
based on the raw decoded case policy and therefore keeps its existing demand
and refusal order. Djex aligns every explicit vector against the normalized
physical target arrow spine; Leant does not infer roles from the type.
Observed roles are numbered compactly as `LengthInput 0..`, while provider transfer
variables keep physical provider-argument ordinals. An unobserved role supplies only
an opaque, non-inspectable Length-interpreter token which a candidate may ignore or
forward into an unobserved provider position. It is not a claim about source
inhabitance, evaluation, purity, totality, parametricity, strictness, or effects.
Any attempt by the interpreter to inspect such a token fails closed as candidate
semantics rejection.

A focused checked-map regression uses target roles `[unobserved-target,
observed-spine]`, provider roles `[unobserved,spine]`, and provider transfer argument
1. It proves that the canonical query and replay expose exactly one compact observed
input, while the provider-backed counterexample remains explicitly conditional on
the assumed law. Reusing the same one-shot request after its source file is mutated
does not reopen it, and the next compatibility request receives no sticky v3 roles.

For version 4, Handoff retains the version-3 role association in the unified
checked session beside exact-case authority. Exference must have independently
checked the complete recursive zero/step case graph, and Djex freshly re-seals
it through the session-owned problem entrance against the resolved spine
schema. A production `List Nat -> List Nat` rebuild case yields a checked
conditional result using zero and `monus 1` tail semantics, one compact QF_LIA
input, and a replayed input-3/result-3 counterexample. Versions 1--3 continue
to reject the same case. The policy remains command-local and supplies neither
proof nor pruning authority.

Version 5 composes that same production handoff with quotient without granting
case authority implicitly. A role-aware higher-order map under
`cases-rejected` seals a quotient postcondition to QF_LIA and replays one
compact input-3/result-3 counterexample. A production recursive rebuild case
remains ineligible under version 5 `cases-rejected`, but the same quotient
contract under `exact-spine-zero-step-v1` retains the accepted renderer ordinal
and replays the counterexample. Reusing decoded requests after source mutation
and interleaving startup, v3, v4, and both v5 policies demonstrates that neither
grammar nor case choice enters interactive state.

A pure refusal at either boundary leaves that one candidate `Unassessed` through
the legacy assessment projection and records a separate
`LengthPreparationRefusalClass`. The ten-value taxonomy is bounded and
payload-free, and each value has a fixed `lengthPreparationRefusalClassCode`.
Its exhaustive handoff and query classifiers inspect only the already-known
outer constructor; they do not evaluate or retain renderer text, source names,
types, graph identities, or nested Djex errors in the refusal diagnostic. The
exact verified receipt and semantic sidecar remain attached to the candidate
for association. These classes identify only the phase that refused
preparation. They are not behavioral evidence and do not affect ranking. A
refusal does not prevent other eligible candidates from running. If no
candidate is eligible, no live session is opened.

## One scoped serial pass

All eligible candidates are processed in original input order inside one
lexical `withLengthSMTLibLiveSession` rank-N scope. That scope opens the worker
and completes Djex's capability probe before serial candidate processing.
Queries whose batch-local bank replay attempts all miss run live in that same
order on versions 1 and 2. Version 3 first performs one query-owned origin
probe and runs live only after that probe also misses. The ranking layer neither
exposes nor retains Djex's process, workspace, barriers, ordinals, transcripts,
or private run identities.

For each successful live query, Leant calls Djex's
`replayLengthSMTLibLiveQueryObservation`. The gate checks that the observation
carries the exact fingerprint of the already sealed query before inspecting
its private whole status-indexed solver observation. Only the satisfiable
branch can contain optional evidence; the gate then replays any such evidence
against the exact behavioral problem retained by the query. Only a successful
replay releases the safe `ValidatedLengthCounterexample` receipt into the
assessment stored by the opaque ranked-candidate association. The whole
observation has no public projection, so this query-first gate remains the only
semantic extraction edge from a live observation and Djex's public Live API is
unchanged. A bank hit has no observation: Leant passes only the saved
source-ordered naturals and configured evaluation limits to
`replayLengthSMTLibCounterexampleInputs`; the sealed query independently
evaluates them and associates any resulting evidence with its own retained
behavioral problem.

A version-3 origin attempt likewise has no observation. Leant passes only the
evaluation limits and exact query to
`probeLengthSMTLibCounterexampleAtOrigin`; Djex derives the compact all-zero
assignment and performs ordinary replay. A hit becomes the same counterexample
assessment and MRU seed as a bank or live hit. `Nothing` has no positive
authority and proceeds live. Origin evaluation failure becomes its dedicated
indexed ranking class, while association failure maps to the established
indexed evidence mismatch; either atomically restores the batch.

This pre-live branch emits no SMT-LIB and creates no new receipt, verifier,
query, protocol, execution, worker, run, observation, MRU, or presentation
identity schema. Startup ranking configuration-file version 3 is the sole new
schema selection; actual later live ordinals can compact when an origin hit
skips a transaction under the unchanged live construction rules.

The checked problem is transient until it is sealed into a canonical query.
Each eligible prepared record retains only its caller-owned receipt association
and that query. The direct compatibility runner uses the verified callback
receipt itself as the association; the presentation-safe runner uses the
batch-scoped occurrence handle as the only receipt-bearing field in its
transient ranking state. The query already owns the same behavioral problem, so
retaining the earlier renderer, session, or family preparation state solely
for a second replay would duplicate authority and heap residency without
strengthening query/evidence replay.

Djex likewise drops the private typed SMT plan after bounded rendering and
structural fingerprint construction. The sealed query keeps only the checked
problem, canonical check bytes, and full query fingerprint needed by live
execution and replay. Exact decoder-symbol order and optional canonical
`get-value` bytes are rederived from the problem's sealed arity after both were
already bounded and structurally fingerprinted during sealing. The
fingerprint's typed-plan field remains unchanged, so this heap reduction does
not make rendered bytes the semantic source of truth or alter query identity.

Below the public Length execution policy, Djex now admits reusable launch facts
once into a package-private pure Z3 profile. That profile owns the bounded path,
optional digest expectation, timeout, resource limit, host deadline, the
controls which determine configured arguments, startup and reset bytes, empty
environment, fresh-working-directory policy, and the established flat
eleven-field identity slice. It owns no behavioral protocol schema, standalone
fingerprint, or fingerprint budget. The Length wrapper still owns both Length
schema tags, artifact and response policy, the sole fingerprint admission pass,
and the complete reversible policy key.
The package-private `Internal.SMTLib.Z3.Process` runtime opens from that admitted
launch profile and now owns the child, bounded executable observation, FIFO
typed pipe events, cancellation/deadline control, and staged cleanup without
importing Length semantics. One opaque process associates the schema-free
observation slice with its exact limits; the generic owner chooses no domain
identity root, schema tag, or fingerprint budget. The former Length
`...Session.Process` module is now a compatibility and identity facade. It maps
the closed generic phase/failure/cleanup vocabulary exhaustively and retains
only that exact generic process. Its identity selector derives the existing
raw-process v2 root from the process-associated schema-free observation and
process-owned limits, including the unchanged limits-v1 wrapper; the facade
caches no parallel `FingerprintField`.

Successful generic acquisition returns under the facade's existing mask. The
handoff first forces the strict one-field facade and then a transiently derived
outer root to weak head normal form before returning, preserving the former
cached-root demand point without evaluating the lazy ordered observation and
limit field list or opening an asynchronous-exception window.

That v2 identity still binds the path observation, pin result, arguments,
environment, working directory, deadline, limits, and launch flags it
enforces, with no nested copy of the complete Length key. The scoped Session's
v4 ready-worker identity still binds one occurrence of that complete key beside
the raw process field. The earlier v2/v4 migration changed and shortened
ready-worker and transitive query-run identities, allowing a tight custom
identity-byte budget to newly admit the same policy. This later runtime/facade
extraction and the later cached-root deletion leave canonical raw-process,
ready-worker, and query-run bytes and schema tags unchanged. This is structured
authority removal, not byte scrubbing: the reversible identities still contain
the exact derived raw-process field. Leant's configuration API, activation
boundary, and public behavior remain unchanged.

After capability admission, the opaque ready worker no longer retains the
complete five-part pre-readiness Session configuration. One strict private
query policy keeps only maximum queries, the query-run identity budget,
protocol limits, and one strict post-launch policy containing the host deadline,
artifact policy, response limits, and original complete execution-policy
reversible key. This narrower value does not retain the structured Z3 launch
profile or separately projectable executable path, digest expectation, solver
timeout or resource limit, argument vector, environment, or working-directory
policy. Because the reversible key still contains the exact original policy
bytes, this is structured-authority narrowing rather than byte scrubbing.
Exact process limits are projected from the same retained runtime;
workspace-allocation, capability, and ready-identity admission have completed,
while the opener deadline and Session workspace-cleanup authority remain with
the enclosing rank-2 scope; process shutdown limits remain process-owned. The
protocol sealer consumes that associated post-launch policy. Its sealed plan
then supplies its exact query and artifact policy during replay, while response
decoding uses the limits retained by that same plan, rather than pairing either
operation with an independent worker-wide replay copy.
Run-identity admission likewise derives its budget from the worker and its
transport limits from that worker's process. This heap/association narrowing
changes no ready-worker or query-run identity field or byte, schema tag, wire
byte, failure order, public Djex API, or Leant behavior.

The private protocol plan follows the same single-owner rule. After validation
and fingerprint sealing from the post-launch policy it retains the exact
artifact-policy and bounded-response-limit projections, nominal query,
cumulative cursor policy, positional barriers, and reversible plan key needed
by later protocol consumers. The unchanged plan key still embeds the original
complete execution-policy key. Launch-profile, digest, solver-control,
deadline, environment, and working-directory facts are not retained as
separate structured plan authority. The complete fingerprint still binds the
exact initial and optional value writes; concatenated write fragments are
transient fingerprint inputs and are derived again on demand from the retained
query and positional sentinels through the selectors used at the causal write
edges. Presence-only inspection of the optional write does not render request
bytes.

Below Length's compatibility decoder, Djex's package-private Standard response
layer owns canonical `sat`/`unsat`/`unknown` bytes, bounded check-status
classification, and the closed `unsupported`/solver-error shapes. Length maps
that vocabulary exhaustively into its unchanged errors and continues to own
its limit wrapper/defaults, response schema, and query-specific valuation
shape. The readiness capability imports only canonical `sat`/`unsat` bytes and
still exact-compares complete frames with payload-free phase failures. The
shared layer grants no query, process, schema, or evidence authority; changing
its accepted bytes or classification requires every consuming domain to revise
the corresponding response/plan schema identity.

Query protocol and readiness capability now share Djex's opaque cumulative
stream policy and zero-start cursor. A completed frame keeps its exact policy,
absolute charged end, and untouched tail together for same-write continuation;
only fully consumed and validated boundary whitespace can produce the opaque
policy-and-offset token used to start a next-write receiver. Thus neither
machine can restart a detached tail under a different cumulative budget or
absolute offset. The configured frame-total failure still wins an exact tie,
while only a strictly tighter remaining transaction budget becomes the
established cumulative maximum-plus-one failure. The schema-free
`Internal.SMTLib.Lexical` leaf owns the exact SMT-LIB whitespace predicate and
canonical horizontal-tab, line-feed, carriage-return, space order. Bounded
response parsing, framing, the cumulative cursor, process boundary draining,
causal attribution, and the unchanged protocol/capability fingerprints all
consume that one vocabulary. Any vocabulary change must revise the affected
response, framing, and plan schema identities; no domain phase, plan, or solver
authority moves into the lexical leaf or shared cursor.

The schema-free `Internal.SMTLib.Causal.BoundaryWhitespace` leaf now admits
finite strict queued-drain bytes into an opaque lexical-content receipt.
Process mints each nonempty receipt inside the same all-or-nothing STM
inspection which can restore a non-whitespace snapshot before poison, so the
generic transport operation cannot report raw unchecked drain bytes as a
success. The receipt proves content only: FIFO origin, boundedness,
nonblocking behavior, cancellation/deadline and process association, and
restoration remain concrete transport laws. For the initial adopted
predecessor boundary, Driver opens the receipt only after its first exact write
succeeds; later completed-epoch drains preserve their existing append timing.
No transcript, wire, fingerprint, schema, public API, or Leant behavior changes.

The sibling schema-free `Internal.SMTLib.Causal.StdoutChunk` receipt now
admits every nonempty strict Process read before enqueue. Empty reads retain
their FIFO EOF terminal; at the stdout maximum a nonempty permitted prefix is
queued before the maximum-plus-one terminal, while an empty prefix cannot be
represented as a successful chunk. The generic driver can therefore receive
neither a zero-progress success nor an empty success masquerading as the
delimiter required before another write. This receipt proves nonemptiness
only: FIFO origin, configured bounds, cancellation/deadline and process
association remain Length transport laws. Boundary-drain rollback retains the
original typed stdout receipts and their segmentation. Driver projects the
receipt only at its existing receiver-feed and post-epoch boundary-collection
edges. Transcript bytes, failure order, fingerprints, schemas, public
behavior, and Leant remain unchanged.

The package-private terminal protocol value now owns one strict
status-indexed `SolverObservation` instead of a status beside an optional
binding payload. Only the satisfiable branch can carry decoded bindings:
`Nothing` remains status-only `sat`, `Just []` remains the vacuous zero-input
value result, and a nonempty `Just` remains a framed valuation. The `unsat` and
`unknown` branches carry unit, so invalid status/payload pairs are
unrepresentable. Generic `SolverObservation` payloads remain lazy; the opaque
Length owner separately forces only the satisfiable `Maybe` spine, preserving
the former demand without forcing the binding list.

Session consumes that whole protocol observation and produces one private
five-way replay result for status-only satisfiable, validated vacuous
satisfiable, validated framed satisfiable, unsatisfiable, or unknown. That
single owner supplies both unchanged version-1 identity fields and the
completed run observation, preventing decoded status/value classification from
being paired independently with evidence. Successful lease commit retains the
run's ordinal, one strict status-indexed observation, reversible key,
transcript digest, and accounting boundaries, but no parsed symbol/integer
binding list. Only its satisfiable branch can contain optional problem-bound
evidence. The Live facade copies that whole observation once and keeps it
private behind the query-first replay gate. The evidence receipt retains
normalized source-ordered inputs, while the private reversible key retains
exact bounded transcript bytes carrying the raw model. Query-run identity
bytes, field order, schema, wire behavior, and public API remain unchanged;
this is structured-authority narrowing, not byte scrubbing.

Both readiness and ordinary-query driver invocations take their final
transcript cap from the exact sealed plan whose initial action they drive: the
capability plan and protocol plan, respectively. Pre-reservation query-run
identity sizing uses that same protocol-plan projection. A prepared query
transaction retains the exact plan, marker roles, admitted replay limits, and
deadline, but no
accounting anchors and no execution authority. Atomic reservation burns the
ordinal and markers, reads the last-committed stdout and stderr anchors, and
mints the private nominal epoch-bound receipt accepted by execution and commit.
Replay projects the exact query and artifact policy from that receipt's plan.
The live Session carries the protocol plan through driving and binds its
complete key directly into the unchanged version-1 query-run field layout.
Exact bounded status-frame and input-value-frame bytes remain singly stored in
the causal transcript rather than being copied into that decoded branch.

Preparation returns only the sealed problem. Callback receipt and resolved
family values are consumed before that result rather than being copied into a
transient wrapper; the ranking association is the only receipt-bearing slot
retained for occurrence-preserving presentation. The fixed post-verification
seal then becomes the accepted result's sole verified-receipt owner beside an
eager receipt-free index/assessment/failure summary. The fixed compatibility
projection materializes the association-free public ranked receipt from those
two associated values without caching a second receipt list in the accepted
result. The fused adapter preserves the
handoff-before-query refusal boundary with nested closed results rather than
another runtime authority type.

The receipt remains finite-spine and model-relative, including any named
provider-law assumptions. It is not a Lean source-level counterexample, an
executable-realization claim, a solver-soundness certificate, or a kernel proof.
After post-verification sealing, the presentation boundary traverses each
whole materialized ranked receipt and produces one opaque text-plus-note
value. Main never zips candidate text to a detached evidence list; a
counterexample receives a bounded, provider-name-free model summary and an
explicitly enabled positive box receipt receives its distinct bounded summary.

## Ranking and failure policy

The successful ordering rule is intentionally small:

1. `Unassessed`, heuristic, and bounded-positive candidates retain their
   original relative order;
2. candidates with independently replayed counterexamples follow,
   also in their original relative order; and
3. no candidate is removed.

`unknown` and status-only `sat` are neutral. `unsat` is also neutral on the
historical disabled path; under the explicit finite-box policy it schedules
independent traversal but supplies no evidence to that traversal. A completed
box remains neutral, while only a discovered violation enters the
counterexample partition. No status provides proof or pruning authority. The
assessment type deliberately has no `Ord`
instance, so constructor order cannot become an accidental solver-status
ranking.

Any returned structured live session, query, query-fingerprint association,
evidence-replay, origin-probe, or input-box-validation failure discards every
partial assessment and partial reordering. The returned ranking contains every original callback receipt in
original order, all marked `Unassessed`, plus one sanitized failure. Pure
candidate-local preparation classes already established before the worker was
opened survive this atomic fallback; candidates which reached query execution
carry no fabricated refusal class. The batch failure retains only Djex's
public session/query class when applicable, an incomplete-cleanup Boolean, and
a safe zero-based original input index when the failure belongs to one query.
Exceptions propagate and return no ranking. No child bytes, symbols, values,
paths, process details, candidate text, or private identities appear in the
batch-failure payload.

## Budgets and integration boundary

The live lifecycle and query budgets stay distinct. Djex's private policy owns
workspace allocation, capability probing, final readiness, and cleanup bounds;
the strict post-launch policy retained from the explicit execution
configuration supplies the host deadline for each serial query. Sixty-four
admitted candidates do not imply one 64-query wall-clock deadline, and
cumulative process-output limits can still stop a session earlier. Durable
cleanup is bounded by its own staged policy, and its latency can outlive the
operation or deadline that initiated it.

The ranking runner deliberately propagates synchronous and asynchronous
exceptions. Exceptions raised while the live callback owns a session flow
through Djex's durable cleanup; pre-open exceptions own no worker, and
post-scope exceptions occur after cleanup. The module itself contains no Main,
command-line, configuration-file, or REPL wiring. The later explicit
`Leant.Synth.Length.Integration` layer composes those boundaries without making
this ranker guess an executable, pin policy, or contract. Its command-local
request is either the exact disabled identity or one activated policy beside
one lazy contract. Main authorizes an explicit contract before admitting or
opening its path, loads it once before goal translation, and threads that
request through ordinary, universe-retry, provider, and classical lanes. It is
never stored in `ReplState`, `ParsedGoal`, history, snapshots, or a cache; the
no-option path still uses the fixed startup contract, and disabled mode refuses
the option before IO or verification.
