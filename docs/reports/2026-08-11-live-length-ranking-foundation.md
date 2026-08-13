# Live Length ranking foundation

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
paired with one separately decoded contract-only version 1 document for an
explicit `:synth --length-contract ABSOLUTE-PATH -- TYPE` command. This changes
contract lifetime, not the ranking module's authority or input shape.

The one-shot document has the exact format string
`leant-finite-list-spine-length-contract`, version `1`, and only a `contract`
payload beside those two root fields. It reuses the compatibility file's single
bounded contract decoder and contains no execution, activation, artifact,
response, or replay policy. A shared package-private acquisition leaf owns the
same absolute-path, POSIX descriptor, byte, timeout, and cleanup rules for both
file facades.

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
`prepareCheckedLengthProblem` uses the origin's own renderer ordinal and
requires the retained graph to re-render to one spelling equal to the
callback-accepted text before binding its family provenance, inventory,
provider assumptions, and explicit contract.
Eligible checked problems are then sealed into canonical QF_LIA queries. A
pure refusal at either boundary leaves that one candidate `Unassessed` through
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

All eligible queries run in original input order inside one lexical
`withLengthSMTLibLiveSession` rank-N scope. The ranking layer neither exposes nor
retains Djex's process, workspace, barriers, ordinals, transcripts, or private
run identities.

For each successful query, Leant calls Djex's
`replayLengthSMTLibLiveQueryObservation`. The gate checks that the observation
carries the exact fingerprint of the already sealed query before inspecting
its private whole status-indexed solver observation. Only the satisfiable
branch can contain optional evidence; the gate then replays any such evidence
against the exact behavioral problem retained by the query. Only a successful
replay releases the safe `ValidatedLengthCounterexample` receipt into the
assessment stored by the opaque ranked-candidate association. The whole
observation has no public projection, so this query-first gate remains the only
semantic extraction edge and Djex's public Live API is unchanged.

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
value. Main never zips candidate text to a detached evidence list; only a
counterexample receives a bounded, provider-name-free model summary.

## Ranking and failure policy

The successful ordering rule is intentionally small:

1. `Unassessed` candidates and candidates with heuristic statuses retain their
   original relative order;
2. candidates with independently replayed satisfiable counterexamples follow,
   also in their original relative order; and
3. no candidate is removed.

`unsat`, `unknown`, and status-only `sat` are therefore neutral. Their public
statuses may be retained as `Heuristic SolverStatus`, but they provide neither
proof nor pruning authority. The assessment type deliberately has no `Ord`
instance, so constructor order cannot become an accidental solver-status
ranking.

Any returned structured live session, query, query-fingerprint association, or
evidence-replay failure discards every partial assessment and partial
reordering. The returned ranking contains every original callback receipt in
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
