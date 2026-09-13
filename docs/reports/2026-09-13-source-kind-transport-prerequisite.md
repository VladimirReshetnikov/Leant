# Checked source-kind conversion and synonym transport

This Djex library prerequisite preserves ground-kind forall information through source conversion and synonym expansion. It does **not** enable kinded queries in the public commands yet. The original eight public conversion refusals remain open until both engines and the output renderer consume the checked information.

## Implementation

- `SourceTypeKinds` keeps the type, nominal assumptions, explicit annotations and inferred lexical binder kinds together. Binder ownership uses a structural path and a slot, so shadowed spellings have independent kinds. An opaque constructor prevents replacing the type while retaining unrelated kind evidence.
- `inferVariableKindsForObligations` checks annotations and uses jointly in one inference scope. Vacuous unannotated binders retain the existing proper-type default.
- `convertKindedSourceType` accepts explicit star/arrow/parenthesized ground kinds on forall binders. It validates them before synonym expansion, including uses that a phantom synonym may discard. The older type-only conversion still refuses annotated binders.
- `expandSourceTypeKinds` carries checked binder kinds through the existing capture-avoiding synonym expansion. Cloned arguments keep their kinds; discarded arguments leave no stale positions; tuple canonicalization and class arguments get correct resulting positions. An inferred kind survives removal of its only constraining use.
- Temporary kind metadata does not change variable equality. Shared substitution and freshness checks therefore still detect source/definition collisions. Final binder normalization preserves unclaimed source identities, including the IDs used by source-name hints, and renames cloned or colliding binders.

The expansion result's annotations are effective obligations on the expanded type, including transported inferred kinds. They are not a transcript of written annotations; retain the original checked source separately for presentation.

The existing `ParsedSourceType` now retains inferred kinds for ordinary supported syntax. Its getter names and types remain available, with a new `parsedSourceKinds` getter. **Record updates through the former getter fields are no longer supported**: those could detach the type from its checked metadata. Construct a new parsed value through the parser instead.

The new conversion API currently supports ground star/arrow binder kinds. Unresolved kind variables are refused; named kind syntax and whole-type kind annotations are not added here. Synonym definitions accepted by the expansion adapter use the existing unannotated definition representation. These limitations remain part of the source-support work.

## Validation and evidence boundaries

| Snapshot | Validation |
| --- | --- |
| Initial lexical-kind foundation | Strict build; 12 focused tests included in all 526 foundation tests. |
| Ordinary parser retention | Strict build; four focused tests included in all 160 integration tests. |
| Public compatibility after ordinary parser retention | Strict build; all 38 API and 138 CLI tests, with frozen source/runtime/controller checks. This predates the new conversion and expansion modules. |
| Final conversion/expansion prerequisite | Strict library and test builds with warnings treated as errors; 13 focused expansion and 11 focused conversion tests, included in all **539 foundation and 171 integration tests**. Frozen source/runtime/controller checks pass. |

The final tests include copied and discarded polymorphic arguments, vacuous and inferred higher kinds, shadowing, capture avoidance, class-argument expansion, contradictory annotations, invalid synonym definitions, saturation failures, allocator collisions/exhaustion, preserved source IDs and bounded rejection of an oversized caller-built tuple. The integration suite also retains its existing independent GHC replay cases. The new conversion cases establish checked conversion and expansion, not synthesis of implementations for the kinded queries.

The [portable archive](https://github.com/VladimirReshetnikov/Djex/blob/main/test-church/receipts/source-kind-transport-2026-09-13.zip) and [manifest](https://github.com/VladimirReshetnikov/Djex/blob/main/test-church/receipts/source-kind-transport-2026-09-13.json) contain the staged receipts, source snapshots, controller scripts and output, including failed build attempts and the earlier successful expansion version. Final validation ran in `C:/Djex-validation/public-kinded-source`. The root transport checks all implementation text against that snapshot, records unchanged files with only CRLF/LF differences, and copies changed files byte-for-byte.

## Next required delivery

Connect the checked source result to scope-aware public parsing, both checked request paths, exact engine kind authority and original-signature rendering. Retain kinds at local and nested polymorphic sites, not just leading global providers. Preserve source binder identity through projection into Djinn and Exference. Do not use spelling-only matching or an alpha key that erases vacuous binders as authority.

Then pass the [original public probes](2026-09-13-public-kinded-source-frontier.md), plus vacuous, shadowed and conflicting source cases, by synthesizing and independently replaying the actual displayed implementations. Leant stays pinned to its last validated native Djex dependency until a native integration milestone is tested. This prerequisite adds no Church behavior cells and makes no new Lean acceptance claim.

The [delivery plan](2026-09-13-synthesis-delivery-retriage.md) retains the full practical rank-N/impredicative objective and the remaining behavior, universe, evidence and supplied-fold obligations.
