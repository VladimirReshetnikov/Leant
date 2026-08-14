# Live contextual-provider ground-discharge bridge

Date: 2026-08-13

Updated: 2026-08-14 for scoped higher-kinded provider-source contexts.

## Outcome

Leant now carries a supported instance-implicit binder in a live provider
scheme as the same bounded semantic `FExactContext` used inside an exact
provider argument. The wire always retains that representation. Exference
retains the exact nominal Lean class head, its ordered bounded-kinded
source-bound or ground-nominal arguments, and the remaining provider scheme for
plain/binder-only providers and for an exact-evidence provider with at least
one selected fact group. A source-bound higher-kinded argument may use its
lexically enclosing `FAll` variable bare or partially applied only to
proper-type arguments. A no-group
exact-evidence provider instead uses successfully translatable bounded vectors
through the erased fallback. On the retained lane, Handoff presents the
nonempty context to Djex as an `AssumedConstraintConditionalProviderSummary`
instead of silently weakening it to an obligation-free law.

Djinn keeps its historical context-erased provider compatibility projection.
That projection can still search for positive terms which Lean later verifies,
but it cannot produce the opaque Exference carrier consumed by Length and does
not gain conditional provider or ground-fact authority.

This is a fail-closed representation. A dependent instance telescope, an
unresolved or non-class head, an over-bound class application, or an
unsupported class argument produces depth truncation for the provider. The
complete provider is then unavailable to synthesis and cannot acquire a
context-free approximation. Ordinary goal-side instance binders retain their
separate render-only behavior.

The second half of the bridge supplies Djex Length with the narrow static facts
needed to discharge a conditional associated occurrence. Only an exact live
`(instantiations ...)` vector can originate those facts. For each complete
vector which Lean produced by fixing one top-level active instance head and
closing that head's subgoals plus every provider constraint in one isolated
metavariable context, Leant substitutes the exact closed vector into the
provider's leading constraints. The whole resulting constraint group must be
closed, forall-free, ground, and accepted by a trial seal of the complete exact
Exference inventory. Every novel member of an accepted group is entered as a
synthetic instance declaration with no binders and no prerequisites. Those
empty fields mean that Lean already closed the complete prerequisite chain;
they do not claim that Leant transported a dictionary term or proof object.

## Exact provenance and scope

The wire keeps current and historical evidence generations distinct. Exact
live `(instantiations ...)` metadata retains top-level active-instance-closure
provenance. The legacy `(candidates ...)` form remains readable as a bounded
search compatibility hint, but its provider context is erased in both engine
projections and it cannot originate a synthetic ground fact.
Merely reshaping one historical scalar into a one-element vector would not
reconstruct the missing closure evidence, so the parser preserves that
distinction through translation.

An exact assignment remains attached to its source provider for candidate
specialization and rendering. The ground fact derived from that assignment has
a different scope: it is a declaration in the exact Exference inventory from
which the Length session is sealed. It may therefore discharge a matching
ground obligation activated by another provider in that same inventory. This
is intentional. Live provider discovery resolved the instance from the
top-level Lean environment, not from a provider-local dictionary or a query
given, and it closed all prerequisites before emitting the exact vector.
Treating the resulting ground assertion as inventory-global matches the scope
of the Lean evidence while keeping the source assignment itself provider-local.

Duplicate derived facts are collapsed before the inventory is sealed. A
discovery translation only identifies structurally eligible groups and commits
no assignment-local state. Each source-ordered trial then replays the complete
translation with exactly the previously accepted keys plus the candidate and
checks the same complete Exference inventory edge used by production; the
final inventory is another clean replay of exactly the accepted keys. A
rejected group therefore leaves no partial fact, declaration, name allocation,
family plan, or renderer map. If none survives for an exact-evidence provider,
the final replay restores all successfully translatable vectors from its
bounded, filtered list under the historical context-erased assignment lane. An
open, quantified, malformed, unsupported, or non-ground specialization
contributes no fact and cannot perturb an accepted sibling.

Accepted facts follow all provider value declarations in stable
provider/vector/constraint order. An explicit empty exact evidence block emits
none. In Exference, vectors with accepted contextual facts do not also enter
Djex's historical context-free provider-assignment adapter: they authorize the
replayed ground-fact groups and retain render metadata, while Exference uses
the exact contextual declaration under the resulting inventory. An
exact-evidence provider with no accepted group recovers its successfully
translatable bounded vectors through the context-erased assignment lane.
Once any group is accepted for a provider, only its selected vectors are
replayed; rejected and non-ground siblings cannot re-enter that erased lane.
Djinn's erased projection retains its historical assignment behavior.

## Authority flow

The complete path is deliberately one-way:

1. live discovery retains the provider's bounded exact context and one or more
   exact active-instance-closure vectors;
2. translation enters the corresponding closed zero-prerequisite ground facts
   in the exact Exference inventory;
3. Exference may produce a typed candidate whose opaque certificate row retains
   the contextual provider application and its activated ground obligations;
4. Length Handoff reuses that exact inventory, classifies the provider law as
   conditional, and passes the whole typed candidate to Djex;
5. Djex freshly re-seals the carrier, audits every protected provider prefix,
   and independently discharges each activated obligation with its bounded
   session-owned resolver; and only then
6. the checked Length problem can be lowered to a canonical query and sent to
   Z3.

There are no query givens in this resolver path. The synthetic fact is a static
inventory declaration, not a query-local premise. Z3 sees only an already
sealed arithmetic problem and can never supply a typeclass dictionary,
constraint proof, provider authorization, or missing discharge receipt.

The public `typedCandidateTermGraph` projection remains observational only. A
stamped bare graph has discarded the opaque certificate association and cannot
recover conditional authority. Production Handoff must retain the whole exact
typed candidate so Djex can authorize only the final receipt-bearing
visible-application node after the graph-wide protected-prefix audit. A direct,
partial, shared-prefix, or otherwise unassociated occurrence of the same
provider or constraint remains unauthorized.

## Identity compatibility

The bridge consumes Djex's additive conditional identities without changing
the legacy bytes. Their triggers remain distinct:

| Identity | Legacy value | Conditional value | Trigger for conditional value |
| --- | --- | --- | --- |
| provider inventory | exact v2 | conditional-retention v3 | any conditional summary retained |
| semantic inventory | exact v1 | conditional-retention v2 | any conditional summary retained |
| session encoding policy | exact 5/6/7 | 8/9/10 | any conditional summary retained |
| concrete encoding | exact 1/2/3 | 4/5/6 | any conditional summary retained |
| candidate | exact v1 plain or v2 obligation-free associated | v3 ground-discharged associated | this carrier actually authorizes a discharged conditional association |
| carrier-aware graph | v2 | v2, unchanged | unchanged |

The three policy and concrete versions respectively identify ordinary or
all-observed, mixed-role, and exact-case interpretation. Provider and semantic
retention, session policy, and concrete encoding switch even when the retained
conditional summary is unused. Candidate v3 alone requires this carrier to own
an authorized, statically discharged conditional association; otherwise it
remains v1 or v2. The exact session inventory also binds accepted derived
declarations. Complete problem and query identities bind these components
transitively; no raw dictionary, resolver proof, or certificate coordinate
becomes a public key.

Leant introduces no additional numeric wire or identity version beyond the
exact-context and evidence-provenance distinction described above. The already
pinned Djex versions bind the changed exact inventory transitively; every
legacy-only identity remains byte-for-byte exact.

## Regression evidence

The end-to-end regression selects the explicitly certified candidate from the
Exference lane while an ordinary direct conditional occurrence remains
ineligible. After static discharge it confirms candidate v3 and concrete v4,
then a fake-Z3 query at ordinal 0 issues no `get-value` and replays a zero-input,
result-0 counterexample whose `FiniteSpineModelUnderAssumedProviderLaws` basis
names the exact provider.

## Trust boundary

Static discharge proves only that the activated ground class constraint is
derivable in the exact bounded inventory. The provider transfer remains an
assumed law which is explicitly uniform over independently admitted dictionary
evidence. Neither the Lean closure used to derive a fact nor Djex's discharge
proves candidate completeness, provider implementation identity, purity,
totality, strictness, or the behavioral law itself.

Solver observations remain heuristic until exact problem-bound model replay
creates the existing finite-spine counterexample receipt. Even successful
arithmetic replay is not dictionary evidence. The bridge adds a checked static
precondition to the existing behavioral pipeline; it does not move class
resolution into Z3 or make public graph data authoritative.
