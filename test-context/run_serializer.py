#!/usr/bin/env python3
"""Compile the exact production synthesis prelude emitted by the unit binary."""
from __future__ import annotations

import argparse
import os
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'lib/Djex/test-church'))
import behavior_runtime as runtime


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--test-exe', type=Path, default=ROOT /
        'dist-newstyle/build/x86_64-windows/ghc-9.12.4/leant-0.1.0/t/leant-synth-tests/build/leant-synth-tests/leant-synth-tests.exe')
    parser.add_argument('--lean-runtime', type=Path, default=Path(
        os.environ.get('ELAN_HOME', str(Path.home() / '.elan'))) /
        'toolchains/leanprover--lean4---v4.32.0/bin/lean.exe')
    parser.add_argument('--process-timeout', type=float, default=120)
    args = parser.parse_args()
    output = runtime.prepare_output_directory(args.output).resolve()
    processes = runtime.Processes(output, args.process_timeout)
    paths = [Path(__file__).resolve(), Path(runtime.__file__).resolve(),
             ROOT / 'test-unit/Spec.hs', ROOT / 'src/Leant/Synth/Fragment.hs',
             ROOT / 'src/Leant/Synth/ContextSource.hs', ROOT / 'src/Leant/Synth/ContextRender.hs',
             ROOT / 'leant.cabal', args.test_exe.resolve(), args.lean_runtime.resolve()]
    before = {str(path): runtime.sha256(path) for path in paths}
    report = dict(status='running', scope='exact emitted synthesis serializer compilation; no synthesis acceptance',
                  hashes_before=before, processes=[])
    receipt = output / 'results.json'
    runtime.write_json(receipt, report)
    try:
        emitted = processes.run('emit-synthesis-prelude',
                                [args.test_exe.resolve(), '--emit-synthesis-prelude'], cwd=ROOT)
        if emitted.returncode != 0 or emitted.stderr:
            raise ValueError('the built test executable failed to emit the production prelude')
        raw = Path(processes.rows[-1]['stdout_path']).read_bytes()
        if not raw.startswith(b'namespace LeantSynth\n') or b'def contextSourcePacket ' not in raw:
            raise ValueError('emitter did not return the expected complete production prelude')
        source = output / 'SynthesisPrelude.lean'
        source.write_bytes(b'import Lean\n' + raw)
        report.update(emitted_sha256=processes.rows[-1]['stdout_sha256'],
                      source_path=str(source), source_sha256=runtime.sha256(source),
                      transformation='prepend exactly import Lean and one LF to emitted bytes')
        runtime.write_json(receipt, report)
        compiled = processes.run('compile-synthesis-prelude',
                                 [args.lean_runtime.resolve(), source], cwd=ROOT)
        report['kernel_exit_code'] = compiled.returncode
        report['source_unchanged'] = runtime.sha256(source) == report['source_sha256']
        if compiled.returncode != 0 or 'declaration uses `sorry`' in compiled.stdout + compiled.stderr:
            raise ValueError('the exact production serializer did not compile without errors or sorry warnings')
        if not report['source_unchanged']:
            raise ValueError('the emitted kernel source changed during compilation')
        report['status'] = 'passed'
    except Exception as failure:
        report.update(status='failed', failure=str(failure))
    finally:
        report['hashes_after'] = {str(path): runtime.sha256(path) for path in paths}
        report['inputs_unchanged'] = before == report['hashes_after']
        if not report['inputs_unchanged']:
            report.update(status='failed', integrity_failure='source or executable changed')
        report['processes'] = processes.rows
        runtime.write_json(receipt, report)
    print('Exact synthesis serializer: ' + report['status'], flush=True)
    return 0 if report['status'] == 'passed' else 1


if __name__ == '__main__':
    raise SystemExit(main())
