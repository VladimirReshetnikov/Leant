# Exact nominal universes and selected polymorphic types

Contextual Lean synthesis now retains a nominal declaration's universe signature
and the universe vector selected at each occurrence. It can reconstruct selected
polymorphic types from exact source evidence, including a polymorphic constructor
argument followed by another type selection. This advances practical rank-N
synthesis through Djinn, Exference and Both without changing their search limits.

For example, with `Dictionary A` a class in `Type` and `Box` accepting a payload
in `Type 1`, the contextual command can synthesize the complete signature:

```lean
∀ A : Type, [Dictionary A] →
  (∀ β : Type, β → Nat) → Box (∀ β : Type, β → Nat)
```

The named `where` checks additionally require the result to preserve supplied
polymorphic payloads. Tests use distinct payload results, not only successful
type checking. Higher and named universes, strict implicit binders and qualified
polymorphic payloads have their own cases.

## Implementation

The generated Lean serializer reads the uninstantiated declaration telescope and
retains its universe parameters, argument sorts and result sort separately from
the selected levels. The Haskell preparation layer normalizes and checks that
signature before assigning a private nominal identity. Constructor discovery and
provider matching retain the actual level vector. Different selections of one
declaration must agree on its declaration-local template.

The graph projector recovers a selected forall's binder metadata from matching
positions in the expected result or an independently anchored argument. It
collects consecutive visible and implicit type applications, then validates and
instantiates them in source order. It checks scope, binder visibility, universe
formation and agreement with the graph's erased type. Retrying an evidence
deficit rolls back provisional metadata but preserves consumed work. Integrity
errors and established universe mismatches do not trigger that fallback.

The contextual test harness now accepts an explicit constructor inventory while
retaining its default empty-global requirement for other cases. Accepted results
must retain their own closed typed graph and exact rendered alternative. The
displayed term is replayed independently against the complete original Lean
signature. Reference implementations are checked separately and never supplied
to the synthesis inventory.

## Acceptance evidence

| Gate | Result |
| --- | --- |
| Strict executable and unit build | Pass with `-Werror` and one build worker. |
| Emitted production Lean serializer | Compiles with the pinned Lean kernel. |
| Focused source, universe and rendering checks | 95 pass. |
| Complete native suite | All 763 pass. |
| Six nominal/polymorphic families | 54 distinct accepted cells across ordinary, named-`where` and actual-False entrances in Djinn, Exference and Both; 36 exact empty-axiom replays and 18 actual-False controls. |
| Chained selections and qualified payloads | 18 passing cells, comprising 12 exact empty-axiom replays and six actual-False controls. |
| Existing contextual universes | All 63 pass: 42 exact replays and 21 actual-False controls. |
| Existing contextual constructors | All 27 pass: 21 exact replays and six actual-False controls. |
| Existing strict implicit binders | All 15 pass: nine exact replays and six actual-False controls. |

The first current-source 54-cell run passed 53 cases. Its Both ordinary
strict-binder query hit the separate 120-second process guard while preparing
the synthesis environment. A focused three-case retry passed at the same limits;
the ordinary query completed in 19.87 seconds. The coverage verifier checks that
the two runs have identical source and executable hashes, signatures and
observations, and that their accepted union covers exactly the original 54
cells. The failed receipt remains failed and is retained in the archive.

The first standalone native-suite attempt omitted the declared `djex-fake-z3`
build tool from PATH, producing 55 setup failures. The corrected launcher
resolves the existing helper through Cabal, pins its path and hash, checks PATH
resolution and passes all 763 tests on unchanged source and binaries. Earlier
nominal-admission, selected-type reconstruction and chained-selection failures
remain separate historical attempts, not part of the current pass counts.

## Reproduction

From the Leant root, build the executable and native test component with:

```powershell
cabal build leant:exe:leant leant:test:leant-synth-tests --ghc-options=-Werror -j1
cabal test leant:leant-synth-tests --test-options="--num-threads 1" -j1
$leantExe = (cabal list-bin leant:exe:leant).Trim()
```

The public controller supports explicit case selection. Use fresh output
directories; existing evidence is never overwritten.

```powershell
python -X utf8 -B test-context/run_polymorphic_selection.py --leant $leantExe --output dist-newstyle/selected-polytypes/reproduce-core --case fixed_higher_box --case selected_higher_box --case boxed_polymorphic_payload --case boxed_type_one_quantifier --case boxed_named_quantifier --case boxed_strict_quantifier
python -X utf8 -B test-context/run_polymorphic_selection.py --leant $leantExe --output dist-newstyle/selected-polytypes/reproduce-chained --case polymorphic_first_of_two_selections --case boxed_qualified_polymorphic_payload
python -X utf8 -B test-context/run_context_universes.py --leant $leantExe --output dist-newstyle/selected-polytypes/reproduce-universes
python -X utf8 -B test-context/run_constructors.py --leant $leantExe --output dist-newstyle/selected-polytypes/reproduce-constructors
python -X utf8 -B test-context/run_strict_implicit.py --leant $leantExe --output dist-newstyle/selected-polytypes/reproduce-strict
```

The unfiltered polymorphic-selection controller also includes the unresolved
`two_box_selections` diagnostic. It is not an all-green acceptance command.
The archive retains the exact producing controllers, commands, source snapshots,
inputs, outputs, replay artifacts and runtime hashes. Executables are not bundled.

## Scope and remaining obligations

This is a scoped source and reconstruction increment. It does not close the
original query constructing `GenericBox.{0} Nat` and
`GenericBox.{1} (ULift.{1} Nat)` together. That query remains a search miss at its
recorded bounds; the passing chained constructor case is a different obligation.
Selection through dictionary applications needs a discriminating follow-up.
Higher-universe classes and general contextual `Sort`/`Prop` formation remain
separate capabilities. Lean's predicative universe hierarchy remains authoritative.

Exference's explicit Haskell kinded-source entrance remains guarded, and integer
indexing retains its behavioral work. The Church ledger is unchanged: 94
historical acceptances, 23 attempted cells without indexed acceptance and 43
without indexed evidence. These universe fixtures do not close Church behavior
cells or establish arbitrary synthesis completeness. Partial Lean counterparts
continue to require a supplied default or inhabitance assumption.

The [latest priorities](2026-09-14-synthesis-next-priorities.md) track the remaining
work. Leant retains the tested Djex revision
`66b3212be9e5849cc8398ef9de67837e2e0e276f`; this increment does not change core
Djex search code.

The [complete evidence archive](../../test-church/receipts/selected-polymorphic-types-acceptance-2026-09-14.zip) and [manifest](../../test-church/receipts/selected-polymorphic-types-acceptance-2026-09-14.json) retain all producing attempts and their source identities.

Archive SHA-256: `ef8d1f03d8be493298f8a8481f0de2590324c4717b3109e1d982b490c93e48dd`; 17,314,096 bytes; 4,088 members. The archive was reopened and every member hash checked before publication.
