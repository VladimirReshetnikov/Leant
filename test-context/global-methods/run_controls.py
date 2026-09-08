"""Owned literal-False and public legacy/context provider-cache controls.

This supplemental acceptance does not change the global-provider proposal.
Contextual positives retain the original window 32 and payload 7/11 oracle.
Only legacy cache probes use window 4 and a doubling predicate, requiring an
actual owned Nat.add result after structural rejection under the unchanged
45s deadline. A missing provider phase is a failed gate, never a cache hit.
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
BASE = HERE
METHOD_SHA = 'c0ff4bbf5c40588e6f52615bd55fabcb07d24c36a8e07f3f8539692f5d4d5a64'
CAPTURE = HERE / 'capture.py'
CAPTURE_SHA = '6841638bfe459c70b1a5cfa9683276cb3517766ca956407b313184f923ef0990'
BACKEND_SHA = '650e7c02c1dcd3ebe32df35c10813ba24872005efeb8caa4c23e095b338ea1c9'

def sha(path): return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def load(name, path, expected):
    if sha(path) != expected:
        raise ValueError('frozen control dependency changed: ' + str(path))
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module

method = load('supplemental_global_method', BASE / 'run_methods.py', METHOD_SHA)
capture = load('global_method_capture', CAPTURE, CAPTURE_SHA)
parser, runtime = method.parser, capture.runtime


def legacy_graph_observation(block, case, term):
    rows = re.findall(r'(?m)^debug accepted-candidate: (.*)$', block)
    if len(rows) != 1: raise ValueError('legacy result has no unique owned observation')
    observed = json.loads(rows[0])
    if (observed.get('schema') != 1 or observed.get('label') != 'it1'
            or observed.get('term') != term or observed.get('route') != 'RouteTypedCandidate'
            or type(observed.get('variant_ordinal')) is not int or observed['variant_ordinal'] < 0):
        raise ValueError('legacy provider did not retain its own exact typed result')
    origin = observed.get('origin', {})
    if (origin.get('engine') not in ('djinn', 'exference')
            or (case['engine'] != 'both' and origin['engine'] != case['engine'])
            or type(origin.get('renderer_ordinal')) is not int or origin['renderer_ordinal'] < 0):
        raise ValueError('legacy cache result lost exact engine/renderer ownership')
    rendering, graph = origin.get('rendering', {}), origin.get('graph', {})
    if (rendering.get('term') != term or rendering.get('matches_verified_text') is not True
            or 'failure' in rendering or 'failure' in graph or graph.get('root_closed') is not True
            or not graph.get('root') or not graph.get('root_type')
            or type(graph.get('node_count')) is not int or graph['node_count'] < 1
            or graph.get('erasure_matches_compatibility') is not True
            or set(graph.get('globals', [])) != {'leantProvider0'}
            or graph.get('context_introductions') != [] or graph.get('context_applications') != []):
        raise ValueError('legacy cache result lost its sole provider or acquired contextual graph evidence')
    normalized = term.replace('«', '').replace('»', '')
    if not re.search(r'\bNat\.add\b', normalized) or 'leantGiven' in term:
        raise ValueError('legacy result did not actually use its native add provider')
    return observed


def blocks(output, session, source):
    parser.validate_settings(output, source)
    # No successful prefix can hide a later timeout, transport failure, or
    # missing provider phase. The live process itself must also finish.
    if re.search(r'(?mi)^(?:.*(?:timed out|timeout exceeded)|the engine did not finish within |provider inventory unavailable:|out of fragment:)', output):
        raise ValueError('a timeout/refusal cannot establish cache-route coverage')
    chunks = re.split(r'(?m)^λ> :synth ', output)[1:]
    if len(chunks) != len(session['queries']):
        raise ValueError('missing or additional synthesis command')
    result = []
    for case, chunk in zip(session['queries'], chunks):
        block = chunk.split('\nλ> ', 1)[0]
        if block.splitlines()[0] != case['command'].removeprefix(':synth '):
            raise ValueError('query order differs from the exact prepared session')
        exact = re.findall(r'(?m)^debug fragment: (.*)$', block)
        if len(exact) != 1 or ('FExactContext' in exact[0]) != case['contextual']:
            raise ValueError('query entered the wrong contextual/legacy fragment route')
        inventory = []
        for line in block.splitlines():
            if not line.startswith('debug provider: '): continue
            name = re.search(r'\bproviderLeanName = ("(?:[^"\\]|\\.)*")', line)
            if name is None: raise ValueError('provider row has no exact source identity')
            contextual = 'ProviderFragWithContextSource' in line
            if contextual != case['contextual']:
                raise ValueError('contextual packet and legacy provider modes crossed')
            inventory.append(dict(name=json.loads(name[1]), row=line, contextual=contextual))
        expected_inventory_count = 1 if case['provider_discovery'] else 0
        if len(inventory) != expected_inventory_count:
            raise ValueError('missing fresh provider phase, or a legacy cache hit rediscovered providers')
        if case['contextual'] and [row['name'] for row in inventory] != ['Ctx.C.out']:
            raise ValueError('contextual cap-1 discovery lost exactly Ctx.C.out')
        if not case['contextual'] and case['provider_discovery'] and [row['name'] for row in inventory] != ['Nat.add']:
            raise ValueError('legacy cap-1 discovery did not select the required actual Nat.add provider')
        parsed = parser.candidate_result(block, case)
        parsed.update(kind=case['kind'], provider_inventory=inventory)
        if case['expected'] == 'candidate':
            term = parsed['candidate']
            normalized = term.replace('«', '').replace('»', '')
            if re.search(r'\bsorry\b|\bunsafe\b|Classical|MethodOracle|NativeCacheOracle|it!', normalized):
                raise ValueError('displayed candidate acquired hidden/oracle/earlier-result authority')
            if case['contextual']:
                if '@_root_.Ctx.C.out' not in normalized or 'leantGiven' not in term or 'Ctx.C.mk' in normalized:
                    raise ValueError('displayed method lost its genuine projection or supplied dictionary')
                parsed['accepted_variant'] = method.graph_observation(block, case, term)
            else:
                parsed['accepted_variant'] = legacy_graph_observation(block, case, term)
        result.append(parsed)
    return result


def provider_request(code):
    if not isinstance(code, str) or 'let chosen := (sessionPreferred.toList' not in code:
        return None
    roots = re.findall(r'(?m)^    let roots : List String := (\[[^\n]*\])$', code)
    heads = re.findall(r'(?m)^    let targetHead : Option String := (.+)$', code)
    sessions = re.findall(r'(?m)^    let sessions : List String := (\[[^\n]*\])$', code)
    modes = re.findall(r'(?m)^    let sessionMethods : Array Name := (.+)$', code)
    caps = re.findall(r'(?m)^      \+\+ workerPreferred.toList \+\+ workerFallback.toList\)\.take (\d+)$', code)
    if any(len(field) != 1 for field in (roots, heads, sessions, modes, caps)) or caps != ['1']:
        raise ValueError('actual provider command lost its exact query/cap/mode fields')
    key = dict(roots=json.loads(roots[0]), result_head=heads[0], session_names=json.loads(sessions[0]))
    if key != dict(roots=['Ctx', 'Nat'], result_head='some "Nat"', session_names=['Ctx.C']):
        raise ValueError('provider program did not use the intended same-session semantic key: ' + repr(key))
    if modes == ['LeantSynth.contextSessionClassProjections env sessions']:
        if ('LeantSynth.contextProviderSourcePacket n info.levelParams info.type' not in code
                or 'LeantSynth.providerInstantiationAssignments 80 info.type' in code):
            raise ValueError('contextual discovery acquired legacy assignment evidence')
        mode = 'contextual'
    elif modes == ['#[]']:
        if ('LeantSynth.providerInstantiationAssignments 80 info.type' not in code
                or 'LeantSynth.contextProviderSourcePacket n info.levelParams info.type' in code):
            raise ValueError('legacy discovery acquired contextual packet authority')
        mode = 'legacy'
    else:
        raise ValueError('unknown actual provider source mode')
    return dict(mode=mode, key=key, cap=1)


def trace_semantics(prepared, session, observed):
    rows = [dict(item, payload=capture.strict_json(raw.decode('utf-8')), code=code)
            for item, raw, _, code in prepared]
    if len({row['backend_id'] for row in rows}) != 1:
        raise ValueError('backend replacement cannot establish same-session cache ownership')
    if any(row['stages'][-1] != 'TraceResponseParsed' for row in rows):
        raise ValueError('nonterminal/failed request cannot establish provider-cache reuse')
    serializers = [row for row in rows if isinstance(row['code'], str)
                   and 'let contextSource ← LeantSynth.contextSourcePacket tgt' in row['code']
                   and '\nexample : (' in row['code'] and '\n  sorry\n' in row['code']]
    if len(serializers) != len(session['queries']):
        raise ValueError('actual serializer requests do not delimit the public query phases')
    boundaries = [row['request_id'] for row in serializers] + [rows[-1]['request_id'] + 1]
    phases = []
    rejected = []
    for index, (case, result, serializer) in enumerate(zip(session['queries'], observed, serializers)):
        # runBehavioralSynth appends exactly one protective newline to the
        # source goal before serialization and candidate callbacks. Ordinary
        # queries retain their literal goal. Check that exact production form.
        queried_type = case['type'] + ('\n' if case['mode'] == 'where' else '')
        if '\nexample : (' + queried_type + ') := by\n' not in serializer['code']:
            raise ValueError('serializer payload differs from the exact queried type')
        group = [row for row in rows if boundaries[index] <= row['request_id'] < boundaries[index + 1]]
        discoveries = []
        for row in group:
            discovered = provider_request(row['code'])
            if discovered is not None:
                discoveries.append(dict(discovered, backend_id=row['backend_id'], request_id=row['request_id'],
                    environment=row['payload'].get('env'), payload_sha256=hashlib.sha256(capture.canonical_json(row['payload']).encode('utf-8')).hexdigest()))
        if len(discoveries) != (1 if case['provider_discovery'] else 0):
            raise ValueError('actual request trace does not establish required provider miss/hit/bypass')
        if any(item['mode'] != ('contextual' if case['contextual'] else 'legacy') for item in discoveries):
            raise ValueError('actual provider request used the wrong metadata mode')
        calls = [row for row in group if row['annotation'] and row['annotation']['role'] in capture.CANDIDATE_ROLES]
        if not calls: raise ValueError('query did not reach actual candidate verification')
        for row in calls:
            annotation = row['annotation']
            if annotation['requested_type'] != queried_type:
                raise ValueError('a callback crossed its exact source query boundary')
            if (annotation['route'] != 'RouteTypedCandidate' or annotation['owner_engine'] not in ('djinn', 'exference')
                    or (case['engine'] != 'both' and annotation['owner_engine'] != case['engine'])):
                raise ValueError('actual callback lost its own typed route/engine origin')
        if case['expected'] == 'no_candidate':
            if not any(row['annotation']['role'] == 'negative-decide' for row in calls):
                raise ValueError('literal False did not reach an actual negative proof request')
            # A positive decision request occurs only after real Lean type
            # verification succeeds. Replay every distinct such exact term.
            evaluated = {}
            for row in calls:
                annotation = row['annotation']
                if annotation['role'] == 'positive-decide':
                    term = annotation['candidate']
                    if re.search(r'\bsorry\b|\bunsafe\b|Classical|MethodOracle|MethodReplay|it!', term):
                        raise ValueError('a rejected candidate borrowed hidden/oracle/earlier-result authority')
                    evaluated.setdefault(term, dict(term=term, requested_type=case['type'],
                        owner_engine=annotation['owner_engine'], renderer_ordinal=annotation['renderer_ordinal'],
                        request_id=row['request_id'], backend_id=row['backend_id']))
            if not evaluated: raise ValueError('no independently type-verified literal-False candidate was evaluated')
            rejected.append(dict(name=case['name'], candidates=list(evaluated.values())))
        else:
            retained = result['accepted_variant']
            if type(retained.get('variant_ordinal')) is not int or retained['variant_ordinal'] < 0:
                raise ValueError('displayed candidate lost its exact verification ordinal')
            # The callback ordinal is the retained verification variant's
            # ordinal, not the graph renderer's separate internal ordinal.
            # Both engines can generate the same text: require the actual
            # display owner, rather than borrowing the other lane's request.
            after_discovery = discoveries[-1]['request_id'] if discoveries else boundaries[index]
            accepted_checks = [row for row in calls
                if row['annotation']['role'] == 'type-verification'
                and row['annotation']['candidate'] == result['candidate']
                and row['annotation']['owner_engine'] == retained['origin']['engine']
                and row['annotation']['renderer_ordinal'] == retained['variant_ordinal']
                and row['request_id'] > after_discovery]
            if not accepted_checks:
                raise ValueError('displayed candidate lacks its own post-discovery verification request')
            result['accepted_verification_requests'] = [dict(backend_id=row['backend_id'],
                request_id=row['request_id'], annotation=row['annotation']) for row in accepted_checks]
        phases.append(dict(name=case['name'], contextual=case['contextual'], discoveries=discoveries,
            provider_phase=('fresh exact-source discovery' if case['contextual'] else
                'legacy cache miss' if discoveries else 'legacy cache hit with an accepted owned Nat.add result'),
            serializer_request_id=serializer['request_id'], callback_requests=len(calls)))
    if session['kind'] == 'cache':
        if [phase['contextual'] for phase in phases] != [False, True, False]:
            raise ValueError('alternation order changed')
        keys = [d['key'] for p in phases for d in p['discoveries']]
        if len(keys) != 2 or any(key != keys[0] for key in keys):
            raise ValueError('actual legacy and contextual discovery keys are not equal')
        # No source declaration/settings change may invalidate the provider
        # world between these requests. Generated it! results are explicitly
        # excluded by the pinned production history policy.
        first = boundaries[0]
        for row in rows:
            code = row['code']
            if row['request_id'] < first or not isinstance(code, str): continue
            if re.match(r'^(?:class |structure |def |axiom |import |namespace |section\b|end\b)', code):
                raise ValueError('a provider-world change interrupted same-session cache coverage')
    return dict(phases=phases, rejected_candidates=rejected,
                cache_hit_evidence='accepted own-graph Nat.add result at exact legacy type after contextual visit, equal actual provider query key, and no fresh discovery request; no cache-hit debug label is invented')


def rejected_replay(case):
    lines = ['set_option autoImplicit false', 'class Ctx.C (α : Type) where out : Nat']
    names = ['Ctx.C', 'Ctx.C.mk', 'Ctx.C.out']
    for index, candidate in enumerate(case['candidates']):
        name = 'RejectedReplay.candidate' + str(index)
        names.append(name)
        lines += [f'def {name} : {candidate["requested_type"]} :=', candidate['term']]
    # This literal check remains separate from candidate type checking.
    # No target implementation or fixture enters any synthesis environment.
    lines += ['theorem RejectedReplay.literalFalse : ¬ False := by decide']
    names.append('RejectedReplay.literalFalse')
    return '\n'.join(lines + ['#print axioms ' + name for name in names]) + '\n', names


def prior_positives(paths, sessions, executable):
    accepted = set()
    for path in paths:
        report = json.loads(path.read_text(encoding='utf-8'))
        if (report.get('status') != 'passed' or report.get('source_and_input_hashes_unchanged') is not True
                or report.get('exact_replay_sources_unchanged') is not True
                or report.get('projection_metadata_preflight', {}).get('status') != 'passed'
                or report.get('oracle_preflight', {}).get('status') != 'passed'
                or report.get('executable') != str(executable)):
            raise ValueError('required original method acceptance/preflight is absent or failed')
        if report.get('source_and_input_hashes_before', {}).get(str(executable)) != sha(executable):
            raise ValueError('prior method acceptance used a different executable')
        for result in report.get('results', []):
            if result.get('status') == 'candidate' and result.get('kernel_replay', {}).get('status') == 'passed':
                accepted.add(result['name'])
    required = {'method_' + s['engine'] + '_' + (s['mode'] if s['kind'] == 'cache' else 'where') for s in sessions}
    if not required <= accepted:
        raise ValueError('run the original same-engine/mode positive gates first: ' + repr(sorted(required - accepted)))


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--output', type=Path, required=True)
    ap.add_argument('--leant', type=Path)
    ap.add_argument('--positive-receipt', type=Path, action='append', default=[])
    ap.add_argument('--lean-runtime', type=Path, default=parser.default_lean_runtime())
    ap.add_argument('--backend', type=Path)
    ap.add_argument('--engine', action='append', choices=['djinn', 'exference', 'both'])
    ap.add_argument('--mode', action='append', choices=['ordinary', 'where'])
    ap.add_argument('--kind', action='append', choices=['false', 'cache'])
    ap.add_argument('--prepare-only', action='store_true')
    ap.add_argument('--legacy-window', type=int, choices=[4, 32], default=4,
                    help='4 preserves the original probe; 32 is the separately recorded expanded diagnostic')
    ap.add_argument('--capture-rows', type=int, choices=[128, 512], default=128,
                    help='explicit local trace capacity; synthesis limits are unchanged')
    args = ap.parse_args()
    fixtures = HERE / ('cache-window' + str(args.legacy_window))
    args.positive_receipt = [path.resolve(strict=True) for path in args.positive_receipt]
    if not args.prepare_only and (args.leant is None or not args.positive_receipt):
        ap.error('--leant and completed --positive-receipt are required')
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    sessions = [s for s in json.loads((fixtures / 'sessions.json').read_text(encoding='utf-8'))['sessions']
                if (not args.engine or s['engine'] in args.engine)
                and (not args.kind or s['kind'] in args.kind)
                and (s['kind'] == 'false' or not args.mode or s['mode'] in args.mode)]
    if not sessions: raise ValueError('empty supplemental selection')
    report = dict(status='prepared', validation='unexecuted', sessions=[], selected=sessions, source_hashes={}, capture_row_limit=args.capture_rows)
    inputs = [Path(__file__).resolve(), fixtures / 'sessions.json', fixtures / 'manifest.json', BASE / 'manifest.json',
              BASE / 'run_methods.py', method.PARSER, CAPTURE,
              fixtures / 'NativeCacheOracle.lean', *args.positive_receipt]
    for session in sessions:
        path = fixtures / session['command_file']
        if sha(path) != session['command_sha256']: raise ValueError('prepared supplemental input changed')
        inputs.append(path)
    runtime.write_json(output / 'results.json', report)
    if args.prepare_only: return 0
    if sha(ROOT / 'src/Leant/Backend.hs') != BACKEND_SHA:
        raise ValueError('request-capture backend differs from the frozen authority')
    args.lean, args.toolchain = str(args.lean_runtime), ''
    selected_executable, backend, lake, runtime_hashes = method.runtime_pins.runtime_identity(args, runtime, report)
    executable = Path(selected_executable)
    prior_positives(args.positive_receipt, sessions, executable)
    kernel = parser.pin_kernel(args.lean_runtime)
    inventory = sorted({*capture.source_paths(), *parser.source_inventory(), *inputs, executable, Path(kernel['path']), *(Path(path) for path in runtime_hashes), *(Path(path) for path in report["source_hashes"])})
    before = {str(path): sha(path) for path in inventory}
    report.update(status='running', validation='actual public commands, complete local request capture, exact kernel replay',
                  executable=str(executable), kernel=kernel, hashes_before=before)
    replay_files, exports = [], []
    processes = runtime.Processes(output, 300)
    try:
        if any(session['kind'] == 'cache' for session in sessions):
            oracle = dict(path=str(fixtures / 'NativeCacheOracle.lean'), sha256=sha(fixtures / 'NativeCacheOracle.lean'),
                declarations=['Ctx.C', 'Ctx.C.mk', 'Ctx.C.out', 'NativeCacheOracle.reference',
                              'NativeCacheOracle.reference_passes', 'NativeCacheOracle.projection',
                              'NativeCacheOracle.projection_rejected'])
            report['legacy_oracle_preflight'] = parser.kernel_check(processes, 'native-cache-oracle', oracle, kernel)
            if report['legacy_oracle_preflight']['status'] != 'passed':
                raise ValueError('isolated legacy doubling/control oracle failed')
        for session in sessions:
            row = dict(name=session['name'], status='running', replays=[])
            report['sessions'].append(row)
            runtime.write_json(output / 'results.json', report)
            source = (fixtures / session['command_file']).read_text(encoding='utf-8')
            trace_path = output / (session['name'] + '.backend-trace.json')
            environment = dict(os.environ, LEANT_BACKEND=str(backend), LEANT_BACKEND_TRACE=str(trace_path), LEANT_BACKEND_TRACE_REQUESTS='1', LEANT_BACKEND_TRACE_REQUEST_LIMIT=str(args.capture_rows))
            processes.timeout = session['process_timeout_seconds']
            live = processes.run(session['name'] + '-live', [str(executable), '--plain', '--lake', str(lake)], source=source, cwd=ROOT, env=environment)
            owned = processes.rows[-1]
            row['owned_process'] = owned
            if live.returncode != 0 or owned.get('status') != 'completed' or owned.get('timed_out'):
                raise ValueError('owned live command process did not complete')
            if Path(owned['input_path']).read_text(encoding='utf-8') != source:
                raise ValueError('captured stdin differs from exact prepared commands')
            if not trace_path.is_file() or trace_path.stat().st_size > 16 * 1024 * 1024:
                raise ValueError('missing or oversized terminal request trace')
            trace_sha = sha(trace_path)
            trace = capture.strict_json(trace_path.read_text(encoding='utf-8'))
            prepared = capture.validate_capture(trace, expected_row_limit=args.capture_rows)
            requests, extracted = capture.export_requests(output, session['name'], prepared)
            exports.extend(extracted)
            row.update(trace_path=str(trace_path), trace_sha256=trace_sha, capture_valid=True,
                       requests=requests, exports=extracted, omitted_records=0, dropped_events=0)
            observed = blocks(live.stdout, session, source)
            semantics = trace_semantics(prepared, session, observed)
            row.update(observations=observed, semantics=semantics)
            replays = []
            for case, result in zip(session['queries'], observed):
                if result['status'] == 'candidate':
                    code, names = method.replay_source(case, result['candidate'])
                    replays.append((case['name'], code, names))
            for rejected in semantics['rejected_candidates']:
                code, names = rejected_replay(rejected)
                replays.append((rejected['name'], code, names))
            for name, code, names in replays:
                path = output / (name + '-replay.lean')
                path.write_text(code, encoding='utf-8', newline='\n')
                prepared_replay = dict(path=str(path), sha256=sha(path), declarations=names)
                result = parser.kernel_check(processes, name + '-replay', prepared_replay, kernel)
                replay_files.append(prepared_replay)
                row['replays'].append(dict(prepared_replay, **result))
                if result['status'] != 'passed': raise ValueError('exact full-type/payload replay failed: ' + name)
            if sha(trace_path) != trace_sha: raise ValueError('completed trace changed during extraction')
            row['status'] = 'passed'
            runtime.write_json(output / 'results.json', report)
        report['status'] = 'passed'
    except BaseException as failure:
        report.update(status='failed', failure=repr(failure))
        if report['sessions']: report['sessions'][-1].update(status='failed', failure=repr(failure))
    finally:
        after = {str(path): sha(path) if path.is_file() else None for path in inventory}
        stable = all(sha(item['path']) == item['sha256'] for item in replay_files + exports)
        report.update(hashes_after=after, hashes_unchanged=before == after,
                      exact_replay_and_export_bytes_unchanged=stable, processes=processes.rows)
        if before != after or not stable: report.update(status='failed', integrity_failure='frozen source/input/executable/kernel/export changed')
        runtime.write_json(output / 'results.json', report)
    return 0 if report['status'] == 'passed' else 1


if __name__ == '__main__':
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, 'reconfigure'): stream.reconfigure(encoding='utf-8')
    raise SystemExit(main())
