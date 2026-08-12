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
than weakening this module's explicit inputs.

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
optional evidence, then replays that evidence against the exact behavioral
problem retained by the query. Only a successful replay releases the safe
`ValidatedLengthCounterexample` receipt into the assessment stored by the
opaque ranked-candidate association.

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
The live process still binds that complete Length key together with its
pre-spawn file observation and launch facts; Leant's configuration API and
activation boundary remain unchanged.

The private protocol plan follows the same single-owner rule. Its unchanged
complete fingerprint still binds the exact initial and optional value writes,
but the plan retains only the sealed query and positional sentinels needed to
render them. Concatenated write fragments are transient fingerprint inputs and
are derived again on demand through the selectors used at the causal write
edges; presence-only inspection of the optional write does not render request
bytes.

Query protocol and readiness capability now share Djex's opaque cumulative
stream policy and zero-start cursor. A completed frame keeps its exact policy,
absolute charged end, and untouched tail together for same-write continuation;
only fully consumed and validated boundary whitespace can produce the opaque
policy-and-offset token used to start a next-write receiver. Thus neither
machine can restart a detached tail under a different cumulative budget or
absolute offset. The configured frame-total failure still wins an exact tie,
while only a strictly tighter remaining transaction budget becomes the
established cumulative maximum-plus-one failure. The base stream layer owns the
canonical ordered SMT-LIB whitespace bytes used by framing, cursor, process
boundary draining, causal attribution, and the unchanged protocol/capability
fingerprints. This factors runtime accounting without moving domain phase
schemas, plan identities, or solver authority into the shared cursor.

The package-private terminal protocol value likewise retains only the closed
solver status and optional decoded integer bindings. Both readiness and
ordinary-query driver invocations take their final transcript cap from the
exact sealed plan whose initial action they drive: the capability plan and
protocol plan, respectively. Pre-reservation query-run identity sizing uses
that same protocol-plan projection. The live Session carries the protocol plan
through driving and binds its complete key directly into the unchanged
query-run identity. Exact bounded status-frame and
input-value-frame bytes remain singly stored in the causal transcript rather
than being copied into that decoded branch.

Preparation returns only the sealed problem. Callback receipt and resolved
family values are consumed before that result rather than being copied into a
transient wrapper; the ranking association is the only receipt-bearing slot
retained for occurrence-preserving presentation. The fixed post-verification
erasure materializes the association-free public ranked receipt only after the
permutation seal. The fused adapter preserves the
handoff-before-query refusal boundary with nested closed results rather than
another runtime authority type.

The receipt remains finite-spine and model-relative, including any named
provider-law assumptions. It is not a Lean source-level counterexample, an
executable-realization claim, a solver-soundness certificate, or a kernel proof.

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
the explicit execution configuration supplies the host deadline for each
serial query. Sixty-four admitted candidates do not imply one 64-query
wall-clock deadline, and cumulative process-output limits can still stop a
session earlier. Durable cleanup is bounded by its own staged policy, and its
latency can outlive the operation or deadline that initiated it.

The ranking runner deliberately propagates synchronous and asynchronous
exceptions. Exceptions raised while the live callback owns a session flow
through Djex's durable cleanup; pre-open exceptions own no worker, and
post-scope exceptions occur after cleanup. The module itself contains no Main,
command-line, configuration-file, or REPL wiring. The later explicit
`Leant.Synth.Length.Integration` layer composes those boundaries without making
this ranker guess an executable, pin policy, or contract.
