"""Root-owned isolated nested-result acceptance; importing starts no processes."""
from __future__ import annotations
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import sys

HERE = Path(__file__).resolve().parent
ROOT = Path(__file__).resolve().parent.parent
sys.path[:0] = [str(ROOT / 'test-context'), str(ROOT / 'test-church'),
               str(ROOT / 'lib/Djex/test-church')]
import run_production as existing
import behavior_partial_probe as runtime_pins
runtime = existing.runtime

FULL_TYPE = '{α : Type} → α → {β : Type} → β → β'
ORACLE = 'fun {α : Type} (_ : α) {β : Type} (y : β) => y'
OBSERVATIONS = (
    '@{f} Nat 17 Bool true = true',
    '@{f} Bool false Nat 23 = 23',
    '@{f} Nat 99 Nat 7 = 7',
    '@{f} Unit () (List Nat) [2, 5] = [2, 5]',
)
PREDICATE = ' ∧ '.join('(' + leaf + ')' for leaf in OBSERVATIONS)


def require(value, message):
    if not value:
        raise ValueError(message)


def condition(name):
    return PREDICATE.replace('{f}', name)


def cases():
    result = []
    for engine in ('djinn', 'exference', 'both'):
        for mode in ('ordinary', 'where', 'false'):
            name = 'nested_' + engine + '_' + mode
            predicate = 'False' if mode == 'false' else condition(name)
            command = (':synth ' + FULL_TYPE if mode == 'ordinary' else
                       ':synth ' + name + ' : ' + FULL_TYPE + ' where ' + predicate)
            result.append(dict(name=name, engine=engine, operation='nested_result',
                               mode='ordinary' if mode == 'ordinary' else 'where',
                               expected='no_candidate' if mode == 'false' else 'candidate',
                               type=FULL_TYPE, predicate=predicate, command=command))
    return result


def command_source(case):
    # Keep the original resource defaults. Shown=1 only reduces display quota.
    settings = [':set synth-library off', ':set synth-providers off',
                ':set synth-classical off', ':set synth-debug on',
                ':set synth-ranking balanced', ':set synth-shown 1',
                ':set synth-window 60', ':set synth-verify 12',
                ':set synth-steps 4096', ':set synth-queue 1024',
                ':set synth-budget off', ':set synth-djinn-strategy depth-first',
                ':set synth-timeout 20', ':set synth-engine ' + case['engine']]
    # No declaration, import, section, oracle, or richer synthesis environment.
    return '\n'.join(settings + [case['command'], ':quit', ''])


def oracle_source():
    return '\n'.join([
        'set_option autoImplicit false',
        'def NestedOracle.reference : ' + FULL_TYPE + ' := ' + ORACLE,
        'theorem NestedOracle.passes : ' + condition('NestedOracle.reference') + ' := by decide',
        'theorem NestedOracle.rejects_wrong_result : ¬ (@NestedOracle.reference Bool false Nat 23 = 24) := by decide',
        'theorem NestedOracle.rejects_false : ¬ False := by decide',
        *('#print axioms ' + name for name in ORACLE_NAMES), ''])


ORACLE_NAMES = ['NestedOracle.reference', 'NestedOracle.passes',
                'NestedOracle.rejects_wrong_result', 'NestedOracle.rejects_false']


def replay_source(term):
    names = ['NestedReplay.accepted', 'NestedReplay.passes']
    # The exact displayed term is inserted once, without rewriting its syntax.
    text = '\n'.join(['set_option autoImplicit false',
        'def NestedReplay.accepted : ' + FULL_TYPE + ' :=', term,
        'theorem NestedReplay.passes : ' + condition('NestedReplay.accepted') + ' := by decide',
        *('#print axioms ' + name for name in names), ''])
    return text, names


def validate_live(transcript, source, case):
    # Existing validator expects values without this one documented suffix.
    # Require it exactly before normalizing only the validation copy.
    acknowledgment = 'synth budget: off (unbounded)'
    require(transcript.splitlines().count(acknowledgment) == 1,
            'missing or repeated default unbounded Djinn budget acknowledgment')
    existing.validate_settings(transcript.replace(acknowledgment, 'synth budget: off'), source)
    require(not re.search(r'(?m)^debug provider: ', transcript), 'providers-off query acquired a provider')
    require('provider inventory unavailable:' not in transcript, 'provider discovery failed')
    block = existing.query_block(transcript, case)
    require('FExactContext' not in block, 'context-free query entered dictionary metadata route')
    result = existing.candidate_result(block, case)
    if result['status'] == 'no_candidate':
        return result
    if case['mode'] == 'where':
        require(result['observations']['inconclusive'] == 0, 'positive predicate had inconclusive observations')
    term = result['candidate']
    require(not re.search(r'\b(?:sorry|admit|unsafe|axiom|native_decide|NestedOracle|NestedReplay)\b', term),
            'candidate acquired untrusted or oracle syntax')
    owned = existing.accepted_observation(block, case, term)
    graph = owned['observation']['origin']['graph']
    require(graph['context_introductions'] == [] and graph['context_applications'] == [],
            'context-free candidate acquired dictionary evidence')
    introductions = graph.get('forall_introductions')
    require(isinstance(introductions, list) and len(introductions) == 2,
            'expected the two actual source forall introductions')
    for field in ('node', 'occurrence', 'child', 'source', 'variable', 'body'):
        require(all(isinstance(row.get(field), str) and row[field] for row in introductions),
                'missing forall witness field: ' + field)
    for field in ('node', 'occurrence', 'variable'):
        require(len({row[field] for row in introductions}) == 2, 'forall identity reused: ' + field)
    require(all(row.get('node_matches_source') is True and row.get('child_matches_body') is True
                for row in introductions), 'forall witness does not belong to its actual node and child')
    roots = [row for row in introductions if row['node'] == graph['root']]
    require(len(roots) == 1 and roots[0]['source'] == graph['root_type'],
            'outer introduction is not the retained closed graph root')
    require(graph.get('implicit_type_applications') == [],
            'projection unexpectedly needed an implicit application')
    result['accepted_variant'] = owned
    result['finite_observation_count'] = len(OBSERVATIONS)
    return result


def stable(mapping):
    return all(existing.unchanged(path, digest) for path, digest in mapping.items())


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--leant', type=Path)
    parser.add_argument('--lean-runtime', type=Path, default=existing.default_lean_runtime())
    parser.add_argument('--backend', type=Path)
    parser.add_argument('--prepare-only', action='store_true')
    args = parser.parse_args()
    require(args.prepare_only or args.leant is not None, '--leant is required for execution')
    require(HERE != args.output.resolve() and HERE not in args.output.resolve().parents,
            'output must be outside the harness source directory')
    output = runtime.prepare_output_directory(args.output).resolve()
    selected = cases()
    pinned_sources = set(existing.source_inventory()) | {
        Path(__file__).resolve(), Path(runtime_pins.__file__).resolve(),
        ROOT / 'test-church/behavior_extended_probe.py', ROOT / 'test-church/behavior_probe.py'}
    report = dict(status='prepared', scope='one context-free nested-result type; no MaybeEither search claim',
        type=FULL_TYPE, observations=list(OBSERVATIONS), expected_cells=9, source_hashes=existing.hashes(sorted(pinned_sources)),
        settings=dict(shown=1, window=60, verify_per_lane=12, steps=4096, queue=1024,
                      budget=None, strategy='depth-first', timeout=20, process_guard=120),
        cases=selected, results=[], executable_hashes={}, processes=[])
    for case in selected:
        case['commands'] = existing.saved_source(output, case['name'] + '.commands.txt', command_source(case))
    report['oracle'] = existing.saved_source(output, 'Oracle.lean', oracle_source(), ORACLE_NAMES)
    generated = [report['oracle']]
    receipt = output / 'results.json'
    runtime.write_json(receipt, report)
    if args.prepare_only:
        print('Prepared nine isolated commands and one kernel oracle; no process launched.')
        return 0
    args.lean, args.toolchain = str(args.lean_runtime), ''
    leant, backend, lake, report['executable_hashes'] = runtime_pins.runtime_identity(args, runtime, report)
    kernel = existing.pin_kernel(Path(report['runtime_identity']['kernel_runtime']))
    processes = runtime.Processes(output, 120)
    report['kernel'] = kernel
    report['status'] = 'running'
    env = dict(os.environ, LEANT_BACKEND=str(backend), LEANT_SYNTH_TIMEOUT='20')
    for key in ('LEANT_BACKEND_TRACE', 'LEANT_BACKEND_TRACE_REQUESTS'):
        env.pop(key, None)
    try:
        report['oracle'].update(existing.kernel_check(processes, 'oracle', report['oracle'], kernel))
        for case in selected:
            row = dict(name=case['name'], engine=case['engine'], mode=case['mode'], status='running')
            report['results'].append(row)
            try:
                require(report['oracle']['status'] == 'passed', 'independent oracle preflight failed')
                prepared = case['commands']
                require(existing.unchanged(prepared['path'], prepared['sha256']), 'exact command changed')
                require(stable(report['executable_hashes']), 'runtime identity changed before cell')
                source = Path(prepared['path']).read_text(encoding='utf-8')
                live = processes.run(case['name'] + '-live', [leant, '--plain', '--lake', lake],
                                     source=source, cwd=ROOT, env=env)
                require(live.returncode == 0, 'owned Leant process did not complete successfully')
                row['live'] = validate_live(live.stdout + live.stderr, source, case)
                if row['live']['status'] == 'candidate':
                    text, names = replay_source(row['live']['candidate'])
                    replay = existing.saved_source(output, case['name'] + '-replay.lean', text, names)
                    generated.append(replay)
                    row['replay'] = replay
                    replay.update(existing.kernel_check(processes, case['name'] + '-kernel', replay, kernel))
                    require(replay['status'] == 'passed', 'exact displayed full-type/predicate/axiom replay failed')
                row['status'] = 'passed'
            except Exception as failure:
                row.update(status='failed', failure=type(failure).__name__ + ': ' + str(failure))
            finally:
                report['processes'] = processes.rows
                runtime.write_json(receipt, report)
        report['status'] = ('passed' if len(report['results']) == 9
                            and all(row['status'] == 'passed' for row in report['results']) else 'failed')
    except Exception as failure:
        report.update(status='failed', failure=type(failure).__name__ + ': ' + str(failure))
    finally:
        report['sources_unchanged'] = stable(report['source_hashes'])
        report['executables_unchanged'] = stable(report['executable_hashes'])
        report['commands_unchanged'] = all(existing.unchanged(c['commands']['path'], c['commands']['sha256']) for c in selected)
        report['kernel_sources_unchanged'] = all(existing.unchanged(p['path'], p['sha256']) for p in generated)
        captures = {row[field + '_path']: row[field + '_sha256'] for row in processes.rows
                    for field in ('input', 'stdout', 'stderr') if field + '_sha256' in row}
        report['captures_unchanged'] = stable(captures)
        if not all(report[k] for k in ('sources_unchanged', 'executables_unchanged',
                                      'commands_unchanged', 'kernel_sources_unchanged', 'captures_unchanged')):
            report['status'] = 'failed'
        if report['status'] == 'running':
            report['status'] = 'interrupted'
        report['processes'] = processes.rows
        report['accepted_outputs'] = sum(r['status'] == 'passed' and r.get('live', {}).get('status') == 'candidate' for r in report['results'])
        report['actual_false_controls'] = sum(r['status'] == 'passed' and r.get('live', {}).get('status') == 'no_candidate' for r in report['results'])
        runtime.write_json(receipt, report)
    print('Nested forall acceptance: ' + report['status'])
    return 0 if report['status'] == 'passed' else 1


if __name__ == '__main__':
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, 'reconfigure'):
            stream.reconfigure(encoding='utf-8')
    raise SystemExit(main())
