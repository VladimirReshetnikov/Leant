"""Check supplied polymorphic selection through a dictionary-qualified consumer.

The rigid result parameter prevents independent constructor introduction. The
observations distinguish the supplied dictionary and polymorphic payload. Each
positive result needs exact Lean replay; the False control needs actual rejection.
"""
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'test-context'))
import run_products

POLY = '(∀ β : Type, β → Nat)'
PREFIX = '∀ A R : Type, [SelectionProbe.Dictionary A] → '
observations = []
for tag, payload, argument_type, argument_value in [(7, 37, 'Bool', 'true'), (11, 53, 'Unit', '()')]:
    call = ('@{f} Nat Nat (@SelectionProbe.Dictionary.mk Nat ' + str(tag) + ') '
            '(fun α [d : SelectionProbe.Dictionary Nat] payload => '
            '(@SelectionProbe.Witness.mk α Nat d.tag payload)) '
            '(fun _ _ => ' + str(payload) + ')')
    observations.append(f'(match {call} with | .mk value payload => value = {tag} ∧ payload {argument_type} {argument_value} = {payload})')

SPECIFICATIONS = [dict(
    label='forced_polymorphic_result_after_dictionary',
    declarations=[
        'class SelectionProbe.Dictionary (α : Type) where tag : Nat',
        'inductive SelectionProbe.Witness (α : Type 1) (R : Type) where | mk : R → α → SelectionProbe.Witness α R',
    ],
    type=PREFIX + '(∀ α : Type 1, [SelectionProbe.Dictionary A] → α → SelectionProbe.Witness α R) → '
         f'{POLY} → SelectionProbe.Witness {POLY} R',
    oracle='fun (A R : Type) [d : SelectionProbe.Dictionary A] consumer payload => '
           f'@consumer {POLY} d payload',
    predicate=' ∧ '.join(observations), ordinary='True', require_context_introduction=True,
)]

BOXED_POLY = f'(SelectionProbe.Box {POLY})'
boxed_observations = []
for tag, payload, argument_type, argument_value in [(7, 37, 'Bool', 'true'), (11, 53, 'Unit', '()')]:
    call = ('@{f} Nat Nat (@SelectionProbe.Dictionary.mk Nat ' + str(tag) + ') '
            '(fun α [d : SelectionProbe.Dictionary Nat] payload => '
            '(@SelectionProbe.Witness.mk α Nat d.tag payload)) '
            f'(@SelectionProbe.Box.mk {POLY} (fun _ _ => {payload}))')
    boxed_observations.append(
        f'(match {call} with | .mk value (.mk payload) => value = {tag} ∧ payload {argument_type} {argument_value} = {payload})')
SPECIFICATIONS.append(dict(
    label='boxed_polymorphic_result_after_dictionary',
    declarations=SPECIFICATIONS[0]['declarations'] + [
        'inductive SelectionProbe.Box (α : Type 1) where | mk : α → SelectionProbe.Box α',
    ],
    type=PREFIX + '(∀ α : Type 1, [SelectionProbe.Dictionary A] → α → SelectionProbe.Witness α R) → '
         f'{BOXED_POLY} → SelectionProbe.Witness {BOXED_POLY} R',
    oracle='fun (A R : Type) [d : SelectionProbe.Dictionary A] consumer payload => '
           f'@consumer {BOXED_POLY} d payload',
    predicate=' ∧ '.join(boxed_observations), ordinary='True', require_context_introduction=True,
))

if __name__ == '__main__':
    raise SystemExit(run_products.main(SPECIFICATIONS,
        scope=__doc__, label_prefix='selection_dictionary',
        additional_sources=(Path(__file__), ROOT / 'src/Leant/Synth/ContextUniverse.hs',
            ROOT / 'test-unit/ContextSelectionSpec.hs', ROOT / 'test-unit/ContextUniverseSpec.hs',
            ROOT / 'test-unit/ContextDictionarySelectionSpec.hs')))
