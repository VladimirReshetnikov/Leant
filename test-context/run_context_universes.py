#!/usr/bin/env python3
"""Replay contextual Type-universe queries using the public acceptance runner."""
from pathlib import Path

import run_products

C = 'ContextProduction.Dictionary'
DECLARATIONS = [f'class {C} (α : Type) where tag : Nat']


def specification(label, universe, *, selected=False, shadowed=False, parameters=(), callback_universe=None):
    # The original higher_universe refusal is exactly the non-selected Type 1
    # signature below. No oracle/helper definition enters the live environment.
    variable = 'α' if shadowed else 'β'
    domain = f'Type ({universe})' if ' ' in universe else f'Type {universe}'
    if selected:
        callback_domain = domain if callback_universe is None else f'Type {callback_universe}'
        tail = f'∀ (γ : {domain}), (∀ (β : {callback_domain}), β → α) → γ → α'
        body = '@p γ x' if callback_universe is None else '@p (α → α) (fun value => value)'
        oracle = f'fun (α : Type) [d : {C} α] (γ : {domain}) p x => {body}'
    else:
        tail = f'(∀ ({variable} : {domain}), {variable} → {variable})'
        oracle = f'fun (α : Type) [d : {C} α] ({variable} : {domain}) x => x'
    source = f'∀ (α : Type), [{C} α] → {tail}'
    level = universe
    lifted = f'(ULift.{{{level}}} Nat)'
    conditions = []
    for value, tag in [(37, 7), (53, 11)]:
        dictionary = f'(@{C}.mk Nat {tag})'
        application = '@{f} Nat ' + dictionary + ' ' + lifted
        if selected:
            application += f' (fun _ _ => {value + tag}) (⟨{value}⟩ : {lifted})'
            conditions.append(application + f' = {value + tag}')
        else:
            application += f' (⟨{value}⟩ : {lifted})'
            conditions.append('(' + application + f').down = {value}')
    predicate = ' ∧ '.join('(' + condition + ')' for condition in conditions)
    # Live where f is a local at fixed universe parameters; the independent
    # replay defines a global that receives its explicit parameter vector.
    replay = predicate.replace('@{f}', '@{f}.{' + ', '.join(parameters) + '}') if parameters else predicate
    return dict(label=label, type=source, oracle=oracle,
                declarations=[*(['universe ' + ' '.join(parameters)] if parameters else []), *DECLARATIONS],
                live_predicate=predicate, predicate=replay, ordinary=replay,
                require_context_introduction=True)


SPECIFICATIONS = [
    specification('higher_universe', '1'),
    specification('named_universe', 'u', parameters=('u',)),
    specification('selected_callback', '1', selected=True),
    specification('named_selected_callback', 'u', selected=True, parameters=('u',)),
    specification('shadowed_binder', '1', shadowed=True),
    specification('max_universes', 'max u v', parameters=('u', 'v')),
    specification('unequal_selection_domains', '1', selected=True, callback_universe='0'),
]


if __name__ == '__main__':
    raise SystemExit(run_products.main(
        SPECIFICATIONS,
        scope='Fresh contextual Type 1, named/max universe, shadowed binder and selected callback queries; ordinary/named/False through individual engines and Both, with exact full-signature Lean replay. This does not establish nonzero nominal/class universe selections or contextual polymorphic type arguments.',
        label_prefix='context_universe', additional_sources=(Path(__file__),)))
