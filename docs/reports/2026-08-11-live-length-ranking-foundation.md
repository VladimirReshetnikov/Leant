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
pin, or read configuration from ambient process state. It is a foundation only:
Main and the REPL do not call it yet.

## Admission and preparation

Input admission productively inspects at most Djex's public live-session maximum
plus one candidate. The current maximum is 64. Maximum-plus-one returns a
structured limit error before the contract or any candidate handoff is touched,
so an unbounded candidate tail cannot trigger unbounded preparation.

For an admitted batch, Leant completes the entire pure preparation pass before
opening a worker. Every candidate is first bound back to its callback-verified
variant, retained typed graph, exact family provenance, inventory, provider
assumptions, and explicit contract through `prepareCheckedLengthHandoff`.
Eligible handoffs are then sealed into canonical QF_LIA queries. A pure refusal
at either boundary leaves that one candidate `Unassessed`; it does not prevent
other eligible candidates from running. If no candidate is eligible, no live
session is opened.

## One scoped serial pass

All eligible queries run in original input order inside one lexical
`withLengthSMTLibLiveSession` rank-N scope. The ranking layer neither exposes nor
retains Djex's process, workspace, barriers, ordinals, transcripts, or private
run identities.

For each successful query, Leant checks that the observation carries the exact
fingerprint of the already sealed query. Optional counterexample evidence is
then replayed again against `checkedLengthHandoffProblem`'s exact behavioral
problem. Only a successful second association replay releases the safe
`ValidatedLengthCounterexample` receipt into the assessment stored by the
opaque ranked-candidate association.

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
original order, all marked `Unassessed`, plus one sanitized failure. That
failure retains only Djex's public session/query class when applicable, an
incomplete-cleanup Boolean, and a safe zero-based original input index when the
failure belongs to one query. Exceptions propagate and return no ranking.
No child bytes, symbols, values, paths, process details, or private identities
cross this boundary.

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
post-scope exceptions occur after cleanup. The module contains no Main,
command-line, configuration-file, or REPL wiring. Enabling user-visible live
ranking later requires an explicit executable/pin policy and explicit contract
source; this checkpoint does not guess either.
