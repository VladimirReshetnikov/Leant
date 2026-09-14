#!/usr/bin/env python3
"""Exercise general product construction through live synthesis and exact replay."""
from pathlib import Path
from types import SimpleNamespace
import argparse
import json
import os
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'test-context'))
import run_production as existing

rt = existing.runtime
SPECIFICATIONS = [
    dict(label='adjacent_kinds', type='∀ A : Type, (∀ F : Type → Type, A) → (∀ F : Type, A) → A × A',
         oracle='fun A left right => (left List, right Unit)',
         predicate='@{f} Nat (fun _ => 7) (fun _ => 9) = (7,9)',
         ordinary='@{f} Nat (fun _ => 7) (fun _ => 7) = (7,7)'),
    dict(label='mixed_applications', type='∀ A B : Type, (A → B) → A → A → B × B',
         oracle='fun A B convert left right => (convert left, convert right)',
         predicate='@{f} Nat Nat (fun x => x + 1) 7 9 = (8,10)',
         ordinary='@{f} Nat Nat (fun x => x + 1) 7 7 = (8,8)'),
    dict(label='projected_functions', type='∀ A B : Type, ((A → B) × (A → B)) → A → B × B',
         oracle='fun A B functions value => (functions.1 value, functions.2 value)',
         predicate='@{f} Nat Nat ((fun x => x + 1), (fun x => x * 2)) 3 = (4,6) ∧ @{f} Nat Nat ((fun x => x + 1), (fun x => x * 2)) 5 = (6,10)',
         ordinary='@{f} Nat Nat ((fun x => x + 1), (fun x => x + 1)) 3 = (4,4)'),
    dict(label='sort_prop', type='∀ A : Type, (Prop → A) → A',
         oracle='fun A consume => consume PUnit.{0}',
         predicate='@{f} Nat (fun _ => 37) = 37', ordinary='@{f} Nat (fun _ => 37) = 37'),
    dict(label='sort_type_one', type='∀ A : Type, (Type 1 → A) → A',
         oracle='fun A consume => consume PUnit.{2}',
         predicate='@{f} Nat (fun _ => 37) = 37', ordinary='@{f} Nat (fun _ => 37) = 37'),
    dict(label='sort_parameter', type='∀ A : Type, (Sort u → A) → A', declarations=['universe u'],
         oracle='fun A consume => consume PUnit.{u}',
         live_predicate='@{f} Nat (fun _ => 37) = 37',
         predicate='@{f}.{u} Nat (fun _ => 37) = 37', ordinary='@{f}.{u} Nat (fun _ => 37) = 37'),
    dict(label='unequal_kind_domains', type='∀ A : Type, ((Type 1 → Type) → A) → A',
         oracle='fun A consume => consume (fun _ => PUnit.{1})',
         predicate='@{f} Nat (fun _ => 37) = 37', ordinary='@{f} Nat (fun _ => 37) = 37'),
]


def main(specifications=None, *, scope=None, label_prefix='product', additional_sources=()):
    specifications = SPECIFICATIONS if specifications is None else specifications
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--leant', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--case', choices=[s['label'] for s in specifications], action='append')
    parser.add_argument('--engine', choices=['djinn', 'exference', 'both'], action='append')
    parser.add_argument('--backend', type=Path)
    options = parser.parse_args()
    out = rt.prepare_output_directory(options.output)
    (out / 'controller.py').write_bytes(Path(__file__).read_bytes())
    specs = [s for s in specifications if not options.case or s['label'] in options.case]
    engines = options.engine or ['djinn', 'exference', 'both']
    report = dict(status='running', scope=scope or 'Fresh public ordinary/named/False product queries with exact displayed full-signature replay and typed graph ownership.', specifications=specs, results=[], source_hashes={}, executable_hashes={})
    files = [*additional_sources, Path(__file__), Path(existing.__file__), Path(existing.runtime_pins.__file__), Path(rt.__file__), ROOT/'test-church/run_corpus.py']
    for base in [ROOT, ROOT/'lib/Djex']:
        tracked = subprocess.check_output(['git', 'ls-files', '-z'], cwd=base).decode().split('\0')
        files += [base / p for p in tracked if p.endswith(('.hs', '.cabal', '.lean')) and (base / p).is_file()]
    report['source_hashes'] = {str(p.resolve()): rt.sha256(p) for p in files}
    kernel_path = existing.default_lean_runtime()
    pins = SimpleNamespace(leant=options.leant, lean=str(kernel_path), lean_runtime=kernel_path, backend=options.backend, toolchain='')
    leant, backend, lake, report['executable_hashes'] = existing.runtime_pins.runtime_identity(pins, rt, report)
    kernel = existing.pin_kernel(Path(report['runtime_identity']['kernel_runtime']))
    runner = rt.Processes(out, 120)
    env = dict(os.environ, LEANT_BACKEND=str(backend), LEANT_SYNTH_TIMEOUT='20', PYTHONDONTWRITEBYTECODE='1')
    for key in ['LEANT_BACKEND_TRACE', 'LEANT_BACKEND_TRACE_REQUESTS']: env.pop(key, None)

    def stable(mapping): return all(existing.unchanged(p, h) for p, h in mapping.items())
    def save():
        report['processes'] = runner.rows
        rt.write_json(out/'results.json', report)
    def replay(label, spec, term, predicate):
        name, proof = 'ProductReplay.accepted', 'ProductReplay.passes'
        source = '\n'.join(['set_option autoImplicit false', *spec.get('declarations', []), f'def {name} : {spec["type"]} :=', term,
            f'theorem {proof} : '+predicate.replace('{f}', name)+' := by decide', f'#print axioms {name}', f'#print axioms {proof}', ''])
        prepared = existing.saved_source(out, label+'.lean', source, [name, proof])
        prepared.update(existing.kernel_check(runner, label, prepared, kernel))
        return prepared
    try:
        save()
        for spec in specs:
            spec['oracle_replay'] = replay(spec['label']+'-oracle', spec, spec['oracle'], spec['predicate'])
            save()
            assert spec['oracle_replay']['status']=='passed', 'reference fixture failed'
            for engine in engines:
                for mode in ['ordinary', 'where', 'false']:
                    label = label_prefix+'_'+spec['label']+'_'+engine+'_'+mode
                    # The where-clause function is a local at the source's
                    # fixed universe; only the separately replayed global
                    # definition accepts an explicit universe argument list.
                    predicate = 'False' if mode=='false' else spec.get('live_predicate', spec['predicate']).replace('{f}', label)
                    command = ':synth '+spec['type'] if mode=='ordinary' else f':synth {label} : {spec["type"]} where {predicate}'
                    case = dict(name=label, type=spec['type'], command=command, mode='ordinary' if mode=='ordinary' else 'where', engine=engine, operation=spec['label'], expected='no_candidate' if mode=='false' else 'candidate')
                    if 'constructor_names' in spec:
                        case['constructor_names'] = spec['constructor_names']
                    source = '\n'.join([':set synth-library off', ':set synth-providers off', ':set synth-classical off', ':set synth-debug on', ':set synth-ranking balanced', ':set synth-shown 1', ':set synth-window 60', ':set synth-verify 12', ':set synth-steps 4096', ':set synth-queue 1024', ':set synth-budget off', ':set synth-djinn-strategy depth-first', ':set synth-timeout 20', ':set synth-engine '+engine, *spec.get('declarations', []), command, ':quit', ''])
                    row = dict(label=label, engine=engine, mode=mode, status='running', command=command)
                    report['results'].append(row); save()
                    try:
                        assert stable(report['executable_hashes']), 'runtime changed'
                        live = runner.run(label+'-live', [leant, '--plain', '--lake', lake], source=source, cwd=ROOT, env=env)
                        assert live.returncode==0, 'live process failed'
                        text = live.stdout+live.stderr
                        existing.validate_settings(text.replace('synth budget: off (unbounded)', 'synth budget: off'), source)
                        block = existing.query_block(text, case)
                        row['live'] = existing.candidate_result(block, case)
                        if row['live']['status']=='candidate':
                            term = row['live']['candidate']
                            assert not re.search(r'\b(sorry|admit|unsafe|axiom|native_decide|ProductReplay)\b', term), 'untrusted output'
                            row['owned'] = existing.accepted_observation(block, case, term)
                            if spec.get('require_context_introduction'):
                                assert row['owned']['observation']['origin']['graph']['context_introductions'], 'contextual query lost its dictionary introduction'
                            row['replay'] = replay(label+'-replay', spec, term, spec['ordinary'] if mode=='ordinary' else spec['predicate'])
                            assert row['replay']['status']=='passed', 'exact replay failed'
                            if mode=='where': assert row['live']['observations']['inconclusive']==0, 'inconclusive positive'
                        row['status']='passed'
                    except Exception as failure: row.update(status='failed', failure=repr(failure))
                    save(); print(label, row['status'], row.get('failure', ''), flush=True)
        report['status']='passed' if len(report['results'])==len(specs)*len(engines)*3 and all(r['status']=='passed' for r in report['results']) else 'failed'
    except BaseException as failure: report.update(status='failed', failure=repr(failure))
    finally:
        report['sources_unchanged']=stable(report['source_hashes'])
        report['runtimes_unchanged']=stable(report['executable_hashes'])
        if not report['sources_unchanged'] or not report['runtimes_unchanged']: report['status']='failed'
        save()
    print(report['status'], flush=True)
    return 0 if report['status']=='passed' else 1


if __name__=='__main__':
    raise SystemExit(main())
