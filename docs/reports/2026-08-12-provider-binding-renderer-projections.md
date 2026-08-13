# Provider-binding-owned renderer projections

Date: 2026-08-12

## Outcome

Leant's prepared synthesis authority now keeps each provider's exact private
identity, translated scheme, renderer metadata, and canonical assignment list
in one `ProviderBinding`. It no longer caches three deterministic projections
of those bindings:

- `SynthesisTranslation` no longer retains a separate provider declaration
  list or provider renderer map;
- `PreparedSemanticOrigin` no longer retains a provider renderer map beside
  its provider bindings.

The combined `semanticOriginDeclarations` list remains search authority. It is
assembled in the historical order from structural declarations followed by
the provider declarations derived from binding order.

## Exact projections

Two private projections now have one definition in `Leant.Synth.Engine`:

- provider declarations are `map providerBindingDeclaration`; and
- the renderer index is the same strict `Data.Map.Strict.fromList` over exact
  private spellings and `ProviderInfo` values.

The map therefore retains the prior ascending-key representation, duplicate
private-spelling last-wins behavior, and weak-head-normal-form demand on mapped
values when the map itself is built. Normal preparation binds one lazy map
thunk and shares it between the expression and term-graph renderer closures.
Exact-origin graph rerendering derives one map after graph availability has
already succeeded. Inspection derives one compatibility map when that field is
demanded.

No private spelling is reconstructed from `Name`: the checked spelling stays
in its binding because `nameSpelling` is fallible and is not an equivalent
authority edge. Provider assignments likewise remain in binding order and are
aggregated only by projection.

## Compatibility and trust

`PreparedSynthesisInspection.inspectedProviderMap` remains unchanged, as do
the renderer APIs, candidate text, search declaration order, provider
assignment order, exact-origin rerendering, and the Length handoff's provider
checks. This is an internal ownership consolidation; it adds no provider law,
does not reinterpret a private name as a Lean name, and does not widen any
public API.

The renderer map remains a finite retained-list derivation. Main's live
inventory is independently bounded, while package-private preparation tests
may supply other finite lists; this refactor does not introduce a new global
provider-count claim.

## Validation

The two-provider preparation regression now checks all of the following from
the same retained binding order:

- the canonical aggregate assignment order;
- the provider-declaration suffix's exact private identities, schemes, and
  binding order;
- exact private-spelling map keys; and
- each complete mapped `ProviderInfo`, including source Lean name, binder
  metadata, source fragment, and ordered rendering alternatives.

Validation completed successfully:

- `cabal test leant-synth-tests --test-show-details=direct`: 314 of 314;
- `cabal build all`;
- `cabal check`;
- two clean walkthrough PDF passes, producing the maintained 107-page PDF;
- extracted walkthrough text inspection; and
- `git diff --check`.
