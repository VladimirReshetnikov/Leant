"""Actual cap-1 class-method discovery, ordinary/where acceptance and exact replay.

The source witness is kernel-checked separately and never enters a search
session. Each live session declares only Ctx.C and discovers its real out
projection. A manually supplied provider packet cannot satisfy this driver.
"""
from pathlib import Path
import argparse
import hashlib
import importlib.util
import json
import os
import re
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
PARSER = ROOT / 'test-context/run_production.py'
PARSER_SHA = '59e626db506eb1a73293962538296267c8abce4f726c62a39446d654148e1212'
def sha(path): return hashlib.sha256(Path(path).read_bytes()).hexdigest()
if sha(PARSER) != PARSER_SHA:
    raise ValueError('the frozen production result/kernel parser changed')
spec = importlib.util.spec_from_file_location('global_method_result_parser', PARSER)
parser = importlib.util.module_from_spec(spec)
spec.loader.exec_module(parser)
runtime = parser.runtime
sys.path.insert(0, str(ROOT / 'test-church'))
import behavior_partial_probe as runtime_pins

def graph_observation(block, case, term):
    observations = re.findall(r'(?m)^debug accepted-candidate: (.*)$', block)
    if len(observations) != 1:
        raise ValueError('displayed method has no unique retained-variant observation')
    observed = json.loads(observations[0])
    if (observed.get('schema') != 1 or observed.get('label') != 'it1'
            or observed.get('term') != term or observed.get('route') != 'RouteTypedCandidate'):
        raise ValueError('observation does not own the exact displayed typed candidate')
    origin = observed.get('origin', {})
    engine = origin.get('engine')
    if engine not in ['djinn', 'exference'] or (case['engine'] != 'both' and engine != case['engine']):
        raise ValueError('an opposing engine donated method authority')
    if type(origin.get('renderer_ordinal')) is not int or origin['renderer_ordinal'] < 0:
        raise ValueError('retained method lost its renderer ordinal')
    rendering = origin.get('rendering', {})
    if rendering.get('term') != term or rendering.get('matches_verified_text') is not True or 'failure' in rendering:
        raise ValueError('the actual source graph did not reproduce its accepted rendering')
    graph = origin.get('graph', {})
    if ('failure' in graph or graph.get('root_closed') is not True
            or graph.get('erasure_matches_compatibility') is not True
            or not graph.get('root') or not graph.get('root_type')
            or type(graph.get('node_count')) is not int or graph['node_count'] < 1
            or not graph.get('globals') or set(graph['globals']) != {'leantProvider0'}):
        raise ValueError('method graph lost its closed source root, exact erasure, or sole actual provider')
    introductions = graph.get('context_introductions', [])
    applications = graph.get('context_applications', [])
    if not introductions or not applications:
        raise ValueError('method lacks actual lexical dictionary introduction/application nodes')
    owned, nodes = set(), set()
    for introduction in introductions:
        if not introduction.get('node') or introduction['node'] in nodes or not introduction.get('occurrence'):
            raise ValueError('duplicate or missing dictionary introduction occurrence')
        nodes.add(introduction['node'])
        binders = introduction.get('binders', [])
        if not binders: raise ValueError('dictionary introduction lost its ordered slots')
        for slot, binder in enumerate(binders):
            if binder != {'introduction': introduction['occurrence'], 'slot': slot}:
                raise ValueError('dictionary source slot changed')
            identity = (binder['introduction'], binder['slot'])
            if identity in owned: raise ValueError('dictionary slot owner duplicated')
            owned.add(identity)
    for application in applications:
        if not application.get('node') or application['node'] in nodes or not application.get('occurrence'):
            raise ValueError('duplicate or missing dictionary application occurrence')
        nodes.add(application['node'])
        evidence = application.get('evidence', [])
        if not evidence: raise ValueError('method application lost its actual dictionary argument')
        for binder in evidence:
            if (binder.get('introduction'), binder.get('slot')) not in owned:
                raise ValueError('method acquired dictionary evidence from another scope')
    return observed

def validate_live(output, source, case):
    parser.validate_settings(output, source)
    block = parser.query_block(output, case)
    inventory = []
    for line in output.splitlines():
        if line.startswith('debug provider: '):
            matched = re.search(r'\bproviderLeanName = ("(?:[^"\\]|\\.)*")', line)
            if matched is None: raise ValueError('provider observation has no exact declaration name')
            if 'ProviderFragWithContextSource' not in line:
                raise ValueError('actual discovery returned legacy provider metadata')
            inventory.append(json.loads(matched[1]))
    if inventory != ['Ctx.C.out']:
        raise ValueError('cap-1 discovery did not select exactly Ctx.C.out: ' + repr(inventory))
    if 'provider inventory unavailable:' in output:
        raise ValueError('actual provider discovery failed')
    parsed = parser.candidate_result(block, case)
    term = parsed['candidate']
    normalized = term.replace('\u00ab', '').replace('\u00bb', '')
    if ('@_root_.Ctx.C.out' not in normalized or 'leantGiven' not in term
            or re.search(r'\bsorry\b|\bunsafe\b|Classical|Ctx\.C\.mk|MethodOracle', normalized)):
        raise ValueError('accepted term did not use the genuine method with supplied dictionary ownership')
    parsed.update(provider_inventory=inventory, accepted_variant=graph_observation(block, case, term))
    return parsed

def replay_source(case, term):
    predicate = case['predicate'].replace(case['name'], 'MethodReplay.accepted')
    names = ['Ctx.C', 'Ctx.C.mk', 'Ctx.C.out', 'MethodReplay.accepted', 'MethodReplay.passes']
    text = ('set_option autoImplicit false\nclass Ctx.C (\u03b1 : Type) where out : Nat\n'
            f'def MethodReplay.accepted : {case["type"]} :=\n{term}\n'
            f'theorem MethodReplay.passes : {predicate} := by decide\n'
            + '\n'.join('#print axioms ' + name for name in names) + '\n')
    return text, names

def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--output', type=Path, required=True)
    ap.add_argument('--leant', type=Path)
    ap.add_argument('--test-exe', type=Path,
                    help='freshly built unit executable, used only to emit the exact production prelude')
    ap.add_argument('--lean-runtime', type=Path, default=parser.default_lean_runtime())
    ap.add_argument('--backend', type=Path)
    ap.add_argument('--engine', action='append', choices=['djinn', 'exference', 'both'])
    ap.add_argument('--mode', action='append', choices=['ordinary', 'where'])
    ap.add_argument('--prepare-only', action='store_true')
    args = ap.parse_args()
    if not args.prepare_only and (args.leant is None or args.test_exe is None):
        ap.error('--leant and --test-exe are required for live execution')
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    cases = json.loads((HERE / 'live-cases.json').read_text(encoding='utf-8'))['cases']
    cases = [dict(case, expected='candidate') for case in cases
             if (not args.engine or case['engine'] in args.engine) and (not args.mode or case['mode'] in args.mode)]
    manifest = json.loads((HERE / 'manifest.json').read_text(encoding='utf-8'))
    inputs = [HERE / 'MethodOracle.lean', HERE / 'ProjectionOracle.lean', HERE / 'live-cases.json', HERE / 'manifest.json', Path(__file__).resolve()]
    report = dict(status='prepared', scope=__doc__, cases=cases, results=[], source_hashes={})
    for case in cases:
        source = HERE / case['command_path']
        if sha(source) != case['command_sha256']: raise ValueError('prepared method query changed')
        inputs.append(source)
    if args.prepare_only:
        runtime.write_json(output / 'results.json', report)
        return 0
    for record in manifest['files']:
        if sha(HERE / record['path']) != record['sha256']:
            raise ValueError('method oracle fixture changed: ' + record['path'])
    args.lean, args.toolchain = str(args.lean_runtime), ''
    executable, backend, lake, runtime_hashes = runtime_pins.runtime_identity(args, runtime, report)
    executable = Path(executable)
    test_executable = args.test_exe.resolve(strict=True)
    kernel = parser.pin_kernel(args.lean_runtime)
    paths = sorted({*parser.source_inventory(), *HERE.rglob('*.py'), *inputs, executable, test_executable, Path(kernel['path']),
                    *(Path(p) for p in runtime_hashes), *(Path(p) for p in report["source_hashes"]), Path(runtime_pins.__file__).resolve(),
                    ROOT / 'test-church/behavior_extended_probe.py', ROOT / 'test-church/behavior_probe.py'})
    environment = dict(os.environ, LEANT_BACKEND=str(backend))
    for key in ('LEANT_BACKEND_TRACE', 'LEANT_BACKEND_TRACE_REQUESTS', 'LEANT_BACKEND_TRACE_REQUEST_LIMIT'):
        environment.pop(key, None)
    before = {str(path): sha(path) for path in paths}
    report.update(status='running', source_and_input_hashes_before=before, executable=str(executable), kernel=kernel)
    runtime.write_json(output / 'results.json', report)
    processes = runtime.Processes(output, 150)
    replays = []
    try:
        emitted = processes.run('emit-production-prelude', [str(test_executable), '--emit-synthesis-prelude'], cwd=ROOT)
        if emitted.returncode != 0 or emitted.stderr:
            raise ValueError('fresh unit executable did not emit the exact production prelude')
        raw = Path(processes.rows[-1]['stdout_path']).read_bytes()
        if not raw.startswith(b'namespace LeantSynth\n') or b'def contextSessionClassProjections ' not in raw:
            raise ValueError('the emitted production prelude lacks the reviewed class metadata helper')
        projection_path = output / 'ProjectionMetadata.lean'
        projection_path.write_bytes(b'import Lean\n' + raw + b'\n' + (HERE / 'ProjectionOracle.lean').read_bytes())
        projection_input = dict(path=str(projection_path), sha256=sha(projection_path),
                                declarations=['ProjectionControl.C', 'ProjectionControl.C.out',
                                              'ProjectionControl.NotClass', 'ProjectionControl.Parent',
                                              'ProjectionControl.Child', 'ProjectionControl.Child.out'])
        projection_result = parser.kernel_check(processes, 'projection-metadata-controls', projection_input, kernel)
        replays.append(dict(projection_input, **projection_result))
        report['projection_metadata_preflight'] = replays[-1]
        projection_output = Path(processes.rows[-1]['stdout_path']).read_text(encoding='utf-8')
        if projection_result['status'] != 'passed' or projection_output.count('PROJECTION_METADATA_CONTROLS_PASSED_4') != 1:
            raise ValueError('actual registered class projection metadata controls failed')
        oracle = dict(path=str(HERE / 'MethodOracle.lean'), sha256=sha(HERE / 'MethodOracle.lean'),
                      declarations=['Ctx.C', 'Ctx.C.mk', 'Ctx.C.out', 'MethodOracle.reference',
                                    'MethodOracle.reference_passes', 'MethodOracle.wrong_dictionary',
                                    'MethodOracle.wrong_dictionary_rejected'])
        report['oracle_preflight'] = parser.kernel_check(processes, 'method-oracle', oracle, kernel)
        if report['oracle_preflight']['status'] != 'passed': raise ValueError('method oracle preflight failed')
        for case in cases:
            source = (HERE / case['command_path']).read_text(encoding='utf-8')
            live = processes.run(case['name'] + '-live', [str(executable), '--plain', '--lake', str(lake)], source=source, cwd=ROOT, env=environment)
            if live.returncode != 0: raise ValueError('actual method query process failed')
            captured = Path(processes.rows[-1]['input_path']).read_text(encoding='utf-8')
            if captured != source: raise ValueError('captured method query differs from prepared commands')
            result = validate_live(live.stdout, source, case)
            code, names = replay_source(case, result['candidate'])
            path = output / (case['name'] + '-replay.lean')
            path.write_text(code, encoding='utf-8', newline='\n')
            replay = dict(path=str(path), sha256=sha(path), declarations=names)
            checked = parser.kernel_check(processes, case['name'] + '-replay', replay, kernel)
            replays.append(dict(replay, **checked))
            result['kernel_replay'] = replays[-1]
            report['results'].append(result)
            if checked['status'] != 'passed': raise ValueError('exact emitted method replay failed')
            runtime.write_json(output / 'results.json', report)
        report['status'] = 'passed'
    except BaseException as failure:
        report.update(status='failed', failure=repr(failure))
    finally:
        after = {str(path): sha(path) if path.is_file() else None for path in paths}
        stable_replays = all(sha(item['path']) == item['sha256'] for item in replays)
        report.update(source_and_input_hashes_after=after, source_and_input_hashes_unchanged=before == after,
                      exact_replay_sources_unchanged=stable_replays, processes=processes.rows)
        if before != after or not stable_replays: report.update(status='failed', integrity_failure='frozen source, input, executable or exact replay changed')
        runtime.write_json(output / 'results.json', report)
    return 0 if report['status'] == 'passed' else 1

if __name__ == '__main__':
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, 'reconfigure'): stream.reconfigure(encoding='utf-8')
    raise SystemExit(main())
