# Four-entry MRU Length input replay bank

Date: 2026-08-14

> **Later 2026-08-14 follow-up.** Explicit configuration version 2 can use a
> live `unsat` only to trigger Djex's independent finite-box traversal. A
> violation discovered there is an ordinary counterexample and inserts or
> promotes its input vector in this same bank. A completed positive receipt is
> neutral and never enters the bank. The extension is detailed in the
> [unsat-triggered bounded validation report](2026-08-14-unsat-triggered-length-input-box-validation.md).

## Outcome and work bound

Leant's batch-local Length ranking feedback edge now retains a fixed-capacity
bank of four source-ordered natural input vectors. The bank is newest first.
Before an eligible candidate runs Z3, the ranker tries each retained vector in
that order, making at most four pure replay attempts for that candidate. If
none produces a counterexample, the candidate follows the unchanged live Z3
path.

The bank deduplicates by exact `[Natural]` equality. A successful replay hit
promotes its vector to the newest position. A counterexample returned after an
actual live call, including one found by independent post-`unsat` input-box
traversal, inserts or promotes its vector, and a fifth distinct vector
evicts the least recently used entry. An arity or evaluation rejection, an
honest non-counterexample, or a behavioral association rejection is only a
miss and continues with the next retained vector. If all vectors miss, their
order is unchanged. A pure preparation refusal and a heuristic live status
also leave the bank unchanged. A completed `BoundedPositive` assessment
likewise contains no counterexample vector and leaves the bank unchanged.

The private implementation makes those bounds explicit:
`counterexampleSeedBankMaximumEntries` is `4`,
`replayCounterexampleSeeds` stops after four entries even if a package-private
caller supplies a malformed oversized list, and `promoteCounterexampleSeed`
owns exact deduplication, promotion, and eviction. Promotion deeply evaluates
the resulting bounded bank before the next candidate, so repeated head hits
cannot retain an unbounded chain of earlier lazy bank values.

This is a bounded orchestration policy, not a durable cache. Its state exists
only for one admitted ranking batch, and its fixed capacity makes both retained
memory and replay work independent of the number of candidates after the
fourth distinct input vector.

## Query-owned fresh replay

Each attempt calls Djex's
`replayLengthSMTLibCounterexampleInputs` with the configured
`LengthEvaluationLimits`, the later candidate's sealed `LengthSMTLibQuery`, and
one saved `[Natural]`. Leant no longer rebuilds generated SMT symbols or
`LengthSMTLibIntegerBinding`s for this optimization.

The opaque query already owns its checked problem and exact behavioral-problem
association, and it rederives modeled-input arity and canonical generated
symbols from that retained problem. Djex productively checks the supplied
vector against the problem, performs a new bounded concrete evaluation, and
associates any new behavioral evidence with the same query-owned problem. Only
`Right (Just receipt)` is a hit. `Right Nothing` and either closed
`LengthSMTLibInputReplayError` constructor are misses. Consequently, every hit
yields a freshly evaluated, freshly associated
`ValidatedLengthCounterexample`; no receipt or verdict is transferred from the
candidate which first supplied the inputs.

The raw decoded-model validator remains the only entrance for untrusted SMT
symbol/integer bindings. Query-owned input replay is for already normalized
natural vectors and does not weaken live model validation.

## Authority boundary

Each bank entry contains only `[Natural]`. The bank stores no query,
fingerprint, checked problem, behavioral evidence, counterexample receipt,
provider-law basis, solver status, verdict, transcript, process fact, live
ordinal, or query-run identity. In particular, an input vector obtained under
one provider-qualified problem carries none of that problem's authority into a
later query. The later query must freshly establish both concrete violation
and exact problem association, including its own provider-law qualifications.

A replayed receipt remains finite-spine, model-relative evidence. It is not a
Lean counterexample, proof, pruning permission, dictionary witness, universal
behavioral claim, or Z3 soundness certificate. `unknown` and status-only `sat`
remain heuristic. Under the explicit input-box policy, `unsat` may schedule
independent traversal but cannot enter the bank as a conclusion; only a freshly
discovered and associated counterexample vector can do so.

## Live ordering and failure behavior

Only actual solver calls consume live session ordinals. A replay hit performs
no live call, so later live ordinals remain compact and count the calls which
actually occurred. A live counterexample both supplies the candidate's fresh
receipt and updates the bank; the bank never fabricates or reserves a skipped
run identity.

Candidate traversal, stable ranking, and no-pruning behavior are unchanged. If
an actual live query returns a structured session, query, association, or
evidence failure, the established atomic fallback still discards every partial
assessment and restores the complete admitted batch in original order as
`Unassessed`. Earlier replay hits do not weaken that batch-wide rollback.
Exceptions continue to propagate.

## Identity compatibility

The bank changes only Leant's bounded call orchestration. Djex's query-owned
input entrance adds no field to the sealed query and neither component changes
Length semantics, QF_LIA translation, canonical solver bytes for a given
query, solver protocol, response interpretation, the then-current version-1
JSON configuration grammar,
checked-problem or query fingerprints, presentation schema or renderer,
identity schemas or construction rules, or any semantic, solver, JSON, schema,
or identity version number. The wider replay policy can nevertheless newly
assess and stably demote a candidate that the former single-entry policy would
have sent to Z3. Actual later live identity values and ordinals can compact
when replay skips a solver call; only calls which actually occur receive those
identities, under the unchanged identity schemas and construction rules. The
later additive version-2 JSON grammar selects the bounded validation policy
without changing any of those Djex identities or the bank's representation.
