# Converted source-goal ownership

Date: 2026-08-12

## Outcome

Leant's retained Exference run authority no longer caches a converted source
goal beside the two values which determine it exactly:

- the prepared semantic origin's source goal; and
- the Exference lane's complete source-name table.

The opaque typed-candidate sidecar continues to retain both inputs, the exact
request and session, policy, converted provider assignments, and the checked
candidate. Candidate association, rendering, search order, and Main behavior
are unchanged.

## One conversion at the checked edge

`prepareCheckedLengthProblem` keeps its established refusal order:

1. engine and fitting fragments must agree;
2. constructor and caller premises must be absent;
3. source and search goals must agree;
4. every source variable must resolve through the retained name table;
5. request contexts must be empty; and
6. the request goal must equal the derived converted source goal.

The same derived goal then enters contract sealing. A missing source variable
still produces `LengthHandoffSourceGoalVariableMissing` before request contexts
or the request goal are inspected. The old
`LengthHandoffSourceGoalConversionChanged` branch was unreachable for values
constructed by `Leant.Synth.Engine`: its cached value and the handoff's value
were the same pure conversion of the same retained source goal and name table.
Deleting `exferenceAuthorityConvertedSourceGoal` removes that second
authority-shaped representation. Removing the now-unreachable refusal
constructor closes the obsolete error vocabulary; neither deletion removes a
check against independently supplied state.

## Compatibility and demand

`ExferenceRunAuthorityInspection` retains its existing field and derived
`Eq`/`Show` surface. `inspectedAuthorityConvertedSourceGoal` is now a lazy
compatibility projection from the retained preparation and name table. Asking
for it performs the same pure conversion which previously sat behind the lazy
stored field; callers which do not inspect it do no conversion work.

`TypedCandidateSemanticSidecar` equality no longer compares the redundant
projection. It still compares the checked candidate, exact session inventory,
complete prepared origin, name table, policy, request, and converted provider
assignments. Since the removed value was a deterministic function of two
earlier compared fields, equality results for constructible sidecars are
unchanged.

This checkpoint changes no Djex gitlink, fingerprint, schema, solver behavior,
candidate order, post-verification receipt, or default/opt-in activation path.

## Validation

The focused authority regression checks that the compatibility inspection
field and its `Show` label remain present, that the field equals the source
goal converted through the retained exact table, and that a premise-extended
request remains distinct. The refusal sanitizer remains exhaustive after the
unreachable raw refusal constructor is removed.

Validation completed successfully:

- `cabal test leant-synth-tests --test-show-details=direct`: 314 of 314;
- `cabal build all`;
- `cabal check`;
- two clean walkthrough PDF passes, producing the maintained 107-page PDF;
- extracted walkthrough text inspection; and
- `git diff --check`.
