"""Live polymorphic selection and nominal universe checks with exact Lean replay.

Use --case for a focused gate. The two_box_selections case retains the known
bounded search gap; a passing subset does not establish complete acceptance.
"""
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'test-context'))
import run_products

DECLARATIONS = [
    'class SelectedPoly.Dictionary (α : Type) where tag : Nat',
    'structure SelectedPoly.Box (α : Type 1) where value : α',
    'universe u',
    'structure SelectedPoly.GenericBox (α : Type u) where value : α',
]
PREFIX = '∀ A : Type, [SelectedPoly.Dictionary A] → '
def box_spec(label, box):
    predicate = (
        '(@{f} Nat (@SelectedPoly.Dictionary.mk Nat 7) (ULift.{1} Nat) ⟨37⟩).value.down = 37 ∧ '
        '(@{f} Nat (@SelectedPoly.Dictionary.mk Nat 11) (ULift.{1} Nat) ⟨53⟩).value.down = 53'
    )
    return dict(label=label, type=PREFIX + f'∀ β : Type 1, β → {box} β',
                declarations=DECLARATIONS,
                oracle='fun (A : Type) [d : SelectedPoly.Dictionary A] (β : Type 1) payload => ⟨payload⟩',
                predicate=predicate, ordinary=predicate, require_context_introduction=True, constructor_names=[box.split('.{')[0] + '.mk'])

POLY = '(∀ β : Type, β → Nat)'
poly_predicate = (
    '(@{f} Nat (@SelectedPoly.Dictionary.mk Nat 7) (fun _ _ => 37)).value Bool true = 37 ∧ '
    '(@{f} Nat (@SelectedPoly.Dictionary.mk Nat 11) (fun _ _ => 53)).value Unit () = 53'
)
two_predicate = (
    'let pair := @{f} Nat (@SelectedPoly.Dictionary.mk Nat 7) 37 ⟨53⟩; '
    'pair.1.value = 37 ∧ pair.2.value.down = 53'
)
SPECIFICATIONS = [
    box_spec('fixed_higher_box', 'SelectedPoly.Box'),
    box_spec('selected_higher_box', 'SelectedPoly.GenericBox.{1}'),
    dict(label='two_box_selections',
         type=PREFIX + 'Nat → ULift.{1} Nat → SelectedPoly.GenericBox.{0} Nat × SelectedPoly.GenericBox.{1} (ULift.{1} Nat)',
         declarations=DECLARATIONS, oracle='fun (A : Type) [d : SelectedPoly.Dictionary A] low high => (⟨low⟩, ⟨high⟩)',
         predicate=two_predicate, ordinary='True', require_context_introduction=True, constructor_names=['SelectedPoly.GenericBox.mk']),
    dict(label='boxed_polymorphic_payload', type=PREFIX + f'{POLY} → SelectedPoly.Box {POLY}',
         declarations=DECLARATIONS, oracle='fun (A : Type) [d : SelectedPoly.Dictionary A] payload => ⟨payload⟩',
         predicate=poly_predicate, ordinary='True', require_context_introduction=True, constructor_names=['SelectedPoly.Box.mk']),
]

def higher_poly_spec(label, universe, box_level, applied_type, applied_value, *, parameter=False):
    poly = f'(∀ β : Type {universe}, β → Nat)'
    suffix = '.{u}' if parameter else ''
    predicate = (
        f'(@{{f}}{suffix} Nat (@SelectedPoly.Dictionary.mk Nat 7) (fun _ _ => 37)).value {applied_type} {applied_value} = 37 ∧ '
        f'(@{{f}}{suffix} Nat (@SelectedPoly.Dictionary.mk Nat 11) (fun _ _ => 53)).value {applied_type} {applied_value} = 53'
    )
    return dict(label=label, type=PREFIX + f'{poly} → SelectedPoly.GenericBox.{{{box_level}}} {poly}',
         declarations=DECLARATIONS, oracle='fun (A : Type) [d : SelectedPoly.Dictionary A] payload => ⟨payload⟩',
         predicate=predicate, live_predicate=predicate.replace('@{f}.{u}', '@{f}'), ordinary='True',
         require_context_introduction=True, constructor_names=['SelectedPoly.GenericBox.mk'])

SPECIFICATIONS.extend([
    higher_poly_spec('boxed_type_one_quantifier', '1', '2', '(ULift.{1} Nat)', '⟨37⟩'),
    higher_poly_spec('boxed_named_quantifier', 'u', 'u+1', 'PUnit.{u+1}', 'PUnit.unit', parameter=True),
])

strict_poly = '(∀ ⦃β : Type⦄, β → Nat)'
strict_predicate = (
    '(@{f} Nat (@SelectedPoly.Dictionary.mk Nat 7) (fun ⦃_⦄ _ => 37)).value true = 37 ∧ '
    '(@{f} Nat (@SelectedPoly.Dictionary.mk Nat 11) (fun ⦃_⦄ _ => 53)).value () = 53'
)
SPECIFICATIONS.append(dict(label='boxed_strict_quantifier',
    type=PREFIX + f'{strict_poly} → SelectedPoly.Box {strict_poly}', declarations=DECLARATIONS,
    oracle='fun (A : Type) [d : SelectedPoly.Dictionary A] payload => ⟨payload⟩',
    predicate=strict_predicate, ordinary='True', require_context_introduction=True,
    constructor_names=['SelectedPoly.Box.mk']))

PAIR_DECLARATIONS = DECLARATIONS + [
    'inductive SelectedPoly.Pair (α : Type 1) (β : Type) where | mk : α → β → SelectedPoly.Pair α β',
]
pair_predicate = (
    'match @{f} Nat (@SelectedPoly.Dictionary.mk Nat 7) Nat (fun _ _ => 37) 53 with '
    '| .mk payload value => payload Bool true = 37 ∧ value = 53'
)
SPECIFICATIONS.append(dict(label='polymorphic_first_of_two_selections',
    type=PREFIX + f'∀ Z : Type, {POLY} → Z → SelectedPoly.Pair {POLY} Z',
    declarations=PAIR_DECLARATIONS,
    oracle='fun (A : Type) [d : SelectedPoly.Dictionary A] (Z : Type) payload value => SelectedPoly.Pair.mk payload value',
    predicate=pair_predicate, ordinary='True', require_context_introduction=True,
    constructor_names=['SelectedPoly.Pair.mk']))

QUALIFIED = '(∀ β : Type, [SelectedPoly.Dictionary β] → β → Nat)'
qualified_predicate = (
    'let result := (@{f} Nat (@SelectedPoly.Dictionary.mk Nat 7) '
    '(fun (β : Type) [d : SelectedPoly.Dictionary β] _ => d.tag)).value; '
    '@result Bool (@SelectedPoly.Dictionary.mk Bool 37) true = 37 ∧ '
    '@result Unit (@SelectedPoly.Dictionary.mk Unit 53) () = 53'
)
SPECIFICATIONS.append(dict(label='boxed_qualified_polymorphic_payload',
    type=PREFIX + f'{QUALIFIED} → SelectedPoly.Box {QUALIFIED}', declarations=DECLARATIONS,
    oracle='fun (A : Type) [d : SelectedPoly.Dictionary A] payload => ⟨payload⟩',
    predicate=qualified_predicate, ordinary='True', require_context_introduction=True,
    constructor_names=['SelectedPoly.Box.mk']))

if __name__ == '__main__':
    raise SystemExit(run_products.main(
        SPECIFICATIONS,
        scope='Exact nominal universe source and constructor selections, with the original boxed polymorphic payload gate retained unchanged. Each live positive needs exact full-signature replay; no selected-polytype acceptance follows from monomorphic success.',
        label_prefix='nominal_universe', additional_sources=(Path(__file__),
            ROOT / 'src/Leant/Synth/ContextUniverse.hs', ROOT / 'test-unit/ContextUniverseSpec.hs', ROOT / 'test-unit/ContextSelectionSpec.hs')))
