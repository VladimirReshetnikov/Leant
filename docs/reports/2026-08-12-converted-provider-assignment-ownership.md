# Converted provider-assignment ownership

Date: 2026-08-12

## Outcome

Leant's Exference run authority no longer retains a converted provider-
assignment list beside the exact values which determine it:

- `PreparedSemanticOrigin` retains the ordered `ProviderBinding` list;
- each binding owns its ordered canonical source-domain assignments; and
- the Exference lane retains the complete source-name table.

The search call still receives the same Exference-domain list. The list is now
a transient shared projection rather than a second authority-shaped field in
every typed-candidate sidecar.

## One exact conversion

`convertProviderAssignments` is the single private conversion used both for
the local list passed to
`runExferenceTypedQueryWithKindedInstantiationAssignments` and for the lazy
`inspectedAuthorityProviderAssignments` compatibility view. It preserves:

1. provider-binding order;
2. every provider-local assignment order;
3. provider private identities;
4. argument-kind order; and
5. each type variable's `FlexibleVariable` identity from the exact name table.

The name table is constructed from declaration variables, the search goal, and
every retained provider-assignment argument before conversion, so the private
helper is total for production authority. It keeps the historical `Map.!`
lookup and therefore the same variable-demand behavior if an internal caller
were ever to violate that complete-table invariant; no new exception or
structured error channel is introduced. The outer converted list remains a
lazy thunk shared by the Exference lanes, while inspection does no conversion
work unless its compatibility field is demanded.

## Equality and compatibility

`TypedCandidateSemanticSidecar` equality no longer compares the redundant
converted list. It still compares, in its historical order, the checked
candidate, session inventory, complete prepared origin, exact name table,
policy, and request. Since provider assignments are a deterministic projection
of the prepared origin and table, equality for constructible sidecars is
unchanged.

`ExferenceRunAuthorityInspection` retains its existing field and derived
`Eq`/`Show` surface. Tests derive the expected Exference assignments from two
retained provider bindings and the inspection's exact name table, then compare
the complete list, provider order, provider-local order, argument kinds, and
the retained `Show` label.

This changes no Djex gitlink, schema, fingerprint, candidate order, renderer,
Length refusal, Main behavior, or default/opt-in activation path.

## Validation

- `cabal test leant-synth-tests --test-show-details=direct`: all 314 tests
  passed;
- `cabal build all`: passed;
- `cabal check`: no errors or warnings;
- the maintained walkthrough PDF was rebuilt in two clean passes and remains
  107 pages, with the new ownership wording present in extracted text; and
- `git diff --check`: clean.
