# Length origin-probe orchestration

Date: 2026-08-14

> **Later 2026-08-14 follow-up.** The reusable opaque ranking policy can select
> the same orchestration shape for canonical-`Prod` ranking. The product runner
> calls the pair query-owned origin entrance after its own MRU bank misses; a
> pair receipt cannot be converted to scalar evidence. Product startup version
> 4 remains deferred. See the
> [live binary-product Length ranking report](2026-08-14-live-binary-product-length-ranking.md).

## Outcome

Leant now has an explicit opt-in checkpoint between its bounded batch-local
counterexample bank and each candidate's live Length/Z3 query. Under startup
ranking configuration version 3, the exact per-candidate order is:

1. try the newest-first four-entry MRU bank;
2. if every bank entry misses, ask the sealed query to probe its canonical
   all-zero input; and
3. only if that probe also misses, issue the live Z3 query.

The origin step calls Djex's
`probeLengthSMTLibCounterexampleAtOrigin`. Leant supplies only the configured
`LengthEvaluationLimits` and the exact opaque query. Djex derives one zero for
each compact modeled input from the checked problem privately retained by that
query, then uses the ordinary query-owned evaluator and behavioral-association
gate. Leant does not reconstruct arity, generated symbols, a contract
projection, or an input vector.

This is a single deterministic replay, not another finite-box traversal. It
can skip one candidate's live query transaction, but it does not prevent an
eligible batch from launching its one lexical worker. Complete query
preparation, worker opening, and Djex's startup capability probe all occur
before serial candidate processing reaches the MRU or origin stages. A
session-open or capability failure can therefore fail the batch before any
origin attempt. Only actual live query transactions receive live query
ordinals and run identities.

## Exact configuration opt-in

The startup format remains exactly
`leant-live-length-ranking-configuration`. Its three root versions are
deliberately separate:

- version 1 is the literal compatibility path. It has neither an input box nor
  an origin probe;
- version 2 retains the literal version-1 behavior before live execution and
  adds only its required post-`unsat` `inputBoxValidation`; and
- version 3 retains that exact required box and additionally requires
  `"counterexampleProbe": "origin-before-live"`.

The version-3 root fields are exactly `format`, `version`,
`executionAdmission`, `execution`, `evaluation`, `inputBoxValidation`,
`counterexampleProbe`, and `contract`. The new field has no alternate mode or
Boolean spelling:

```json
{
  "format": "leant-live-length-ranking-configuration",
  "version": 3,
  "inputBoxValidation": {
    "inclusiveInputMaximums": [2, 3],
    "maximumAssignments": 12
  },
  "counterexampleProbe": "origin-before-live"
}
```

The abbreviated object above shows only the version-specific fields; a real
document must also contain every required execution, evaluation, and contract
field from the closed schema. Version 1 and version 2 reject
`counterexampleProbe` as unexpected. Version 3 rejects its absence, wrong
value type, or any value other than the closed literal.

After bounded JSON parsing and the established root-object, format, and
integral-version gates, the v3 decoder preserves this failure order: exact
version-3 root shape, execution admission, execution, evaluation, input-box
validation, the closed counterexample-probe selection, then the embedded
contract. All three startup
versions still use embedded contract grammar v1. Configuration v3 therefore
does not admit modulo, quotient, target roles, or candidate-case policy; those
remain contract-only format choices.

The lower-level reusable policy keeps the two orchestration choices
independent. `mkLengthRankingPolicy` and the validated-components bridge leave
both disabled. `enableLengthRankingOriginProbe` adds only origin permission,
while `enableLengthRankingInputBoxValidation` adds only the finite box. The
version-3 file decoder explicitly composes both checked choices. Versions 1
and 2 continue to select their prior combinations unchanged.

## Per-candidate state transition

Every eligible candidate still owns one pre-sealed exact query and is visited
serially in original callback order.

The MRU stage retains its established semantics. It attempts at most four
source-ordered `[Natural]` vectors. An exact replay hit produces a fresh
query-associated counterexample and stops before the origin stage. Arity,
evaluation, association, and honest non-counterexample results remain bank
misses, so an older entry can still be tried.

After all four miss, v3 runs the origin probe exactly once:

- `Right (Just receipt)` is the ordinary
  `ValidatedLengthCounterexample`. The candidate becomes `Counterexample`, is
  placed in the stable demoted partition, and the receipt's exact zero vector
  is inserted or promoted in the same four-entry MRU bank. No live query is
  issued for that candidate.
- `Right Nothing` is only an origin miss. It creates no positive receipt,
  heuristic status, or pruning permission, does not change the bank, and
  proceeds to live Z3.
- an evaluation rejection becomes indexed
  `LengthRankingOriginProbeEvaluationFailed`; an association rejection maps to
  the established indexed evidence-replay mismatch. Either is one atomic
  operational batch failure: all partial assessments and reordering are
  discarded and the complete admitted batch returns in original order as
  `Unassessed`.

Origin failures differ deliberately from MRU replay failures. Bank entries
come from earlier candidates and can legitimately be inapplicable to a later
query, so their rejections are misses. The origin assignment is derived by the
current exact query itself; failure at that boundary is treated as a defect in
the current configured assessment and fails the batch closed.

If origin misses, live observation handling is unchanged. The query-first
fingerprint and behavioral-evidence replay gate runs before status handling. A
validated live counterexample follows the same ordinary demotion and MRU path.
Status-only `sat` and `unknown` remain neutral. A live `unsat` under v3 then,
and only then, triggers the independently configured exact input-box traversal.
A box-discovered violation is another ordinary counterexample and MRU seed;
complete traversal is neutral `BoundedPositive`; traversal or association
failure activates the existing indexed atomic fallback. An origin hit cannot
schedule the box because it creates no live `unsat` observation.

## Authority boundary

The origin vector is only a deterministic input choice. The configured replay
limits still bound concrete and intermediate values, the checked candidate
result is recomputed, precondition demand still precedes candidate and
postcondition demand, and any provider-backed violation retains its ordinary
explicit assumed-law basis. The probe consumes no solver observation and
assigns no authority to `sat`, `unsat`, or `unknown`.

Leant never fabricates or retains an origin vector before Djex releases a
validated receipt. After a hit, the MRU bank retains only the receipt's bounded
source-ordered natural inputs. It still stores no receipt, query, fingerprint,
provider basis, solver result, verdict, process fact, or durable cache entry.
A later candidate must freshly replay that vector against its own query-owned
problem.

The returned counterexample remains evidence only in Djex's versioned total
finite-list-spine model and remains conditional on any assumed provider laws
used by that candidate. It is not a Lean value-level execution, universal
behavioral proof, kernel theorem, provider-implementation validation, Z3
soundness certificate, or permission to prune candidates.

## Identity and compatibility

The only new schema selection is startup ranking configuration-file version 3.
Version 1 and version 2 retain their exact root fields, decode order,
orchestration, and embedded contract grammar.

The probe introduces no contract, provider-inventory, semantic-inventory,
session-policy, candidate, concrete-encoding, complete-problem, SMT-query,
response, protocol, execution, process, worker, query-run, live-observation,
counterexample-receipt, presentation, or MRU identity/schema change. It emits
no SMT-LIB and creates no separate verifier tag or evidence type. Canonical
query bytes and fingerprints for a prepared candidate are unchanged.

Orchestration can still change which identity *values exist*. An origin hit
skips that candidate's live query, so it creates no live query ordinal or run
identity and later actual live ordinals remain compact. The already-open and
capability-checked batch worker retains its ordinary identity. These are
consequences of taking the new configured branch under unchanged construction
rules, not identity schema changes.

## Validation scope

The focused checkpoint covers the three-version decoder boundary, exact v3
field and literal admission, preserved v1/v2 behavior and failure precedence,
MRU-before-origin ordering, origin hit/miss behavior, ordinary demotion and MRU
promotion, provider-relative receipts, skipped live ordinals, post-live-only
finite-box scheduling, and indexed atomic fallback for origin evaluation and
association failures.
