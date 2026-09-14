# Native sort values and product integration: acceptance

Leant now synthesizes the original mixed-product query with differently kinded polymorphic inputs. The complete native release covers 90 public cells: 63 exact Lean kernel replays and 27 actual-False controls. All 726 native unit tests pass. Leant pins the tested Djex product implementation at `eea33f2464ea5424cd4e74557d0b5368829a8cd8`.

## Behavior and implementation

The original signature is:

```lean
∀ A : Type, (∀ F : Type → Type, A) → (∀ F : Type, A) → A × A
```

With inputs returning 7 and 9, the Djinn named query displays:

```lean
fun _ f g => ⟨f (fun x => x), g _root_.PUnit.{(0 + 1)}⟩
```

The exact displayed definition replays at its original signature and returns `(7,9)`. Updating the Djex dependency alone was insufficient: the native translation treated `Type` as an opaque atom and supplied no value of that atom. The repaired translation distinguishes source sorts from opaque lookalikes, retains their exact levels, and supplies the type `_root_.PUnit.{level}` as an inhabitant of `Sort level`. Its private sort declaration is abstract; this introduction witness supplies no datatype eliminator or complete-refutation authority.

Closed sorts needed only by providers receive the same witness. A second failure occurred after preparation: eta-reduced candidates could omit explicit lambda binders required by premise substitution. The renderer now restores exactly the missing arguments prescribed by the prepared premise layout, avoiding all existing local names, before substituting the Lean witnesses. It preserves existing explicit spines and search limits.

The seven focused tests cover sort/opaque identity, malformed and excessive levels, both engines' sort introduction, refusal to invent elimination/refutation, provider-only sort arguments, and eta-reduced outer/inner premise handling with capture avoidance.

## Acceptance evidence

| Gate | Result |
| --- | --- |
| Strict native executable and test builds | Pass with `-Werror` and one build worker. |
| Focused source-sort tests | All 7 pass, including the provider-only case through both engines. |
| Complete native unit suite | All 726 pass; 527.89 seconds in the retained final run. |
| Product/sort public matrix | 7 specifications × ordinary/named/False × Djinn/Exference/Both: 63 cells, 42 exact kernel replays and 21 False controls. |
| Existing contextual constructor matrix | 27 cells: 21 exact kernel replays and 6 False controls. |
| Source/runtime integrity | Frozen producing source and executable identities remain unchanged; root transport checks the eight changed files exactly and other native sources after newline normalization. |

The product/sort specifications cover adjacent kinds, mixed applications, projected functions, `Prop`, `Type 1`, a named universe, and unequal kind domains. Public success requires the displayed candidate's own typed origin and exact renderer alternative; Both-mode output identifies its actual producing engine. References are checked separately and are never synthesis providers. Replayed definitions and assertions have empty recorded axiom inventories.

## Retained failures and recoveries

- The original native baseline and dependency-only attempt miss the adjacent-kind named query.
- `sort-value-v1` passes all nine initial Djinn public cells but one of 724 unit tests fails because a new parser fixture omitted the required query envelope.
- `sort-value-v2` corrects that fixture and exposes the provider-only premise reconstruction failure.
- `sort-value-v3` includes the eta repair, passes its strict build and seven focused tests, and passes 20 of 21 expanded Djinn cells. Its sole failure is invalid fixture syntax: explicit universe arguments were applied to the local function variable in a `where` clause.
- `sort-value-v4` corrects only the live assertion syntax, retaining explicit universe selection for the separately replayed global definition. The three named-universe cells and all 726 units pass on unchanged compiled source and binaries. The other 18 public cells retain their original producing receipt.
- `sort-value-release-v1` passes 41 of 42 remaining engine cells. The first Exference ordinary process reaches its 120-second outer guard while preparing the Lean environment, without a synthesis result. Its terminal cleanup is recorded.
- `sort-value-release-v2` retries that three-cell group at unchanged limits; all pass. The other 39 cells retain their own receipts. All 27 contextual constructor regressions then pass.

These are distinct attempts, not a rewritten all-green run. The [complete archive](../../test-church/receipts/native-sort-products-acceptance-2026-09-13.zip) contains terminal records, source snapshots, controllers, public inputs, exact replay files and the provider diagnostic. The [manifest](../../test-church/receipts/native-sort-products-acceptance-2026-09-13.json) records archive and per-member hashes plus transport evidence. Executables are identified by hashes rather than included in the archive. The earlier baseline runtime is documented by the [strict-implicit release](2026-09-13-strict-implicit-source-acceptance.md).

## Remaining scope

This release supports the represented zero/successor/parameter/max sort levels; unsupported level expressions retain the conservative fallback. Open provider universe parameters still require scope evidence. Contextual binder universes, class/nominal constant-level selections, Exference's explicit Haskell kinded-source execution, and the outstanding Church behaviors remain separate obligations. The Church ledger is unchanged at 94 historical acceptances, 23 attempted cells without indexed acceptance and 43 unindexed cells. No arbitrary inhabitation-completeness claim follows from these tests.
