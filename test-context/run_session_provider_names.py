"""Check qualified provider identity and replay-cache lifetime via public commands.

Each query has a literal False assertion. These tests accept only provider
inventories and rejection behavior; they make no successful-synthesis claim.
The small verification prefix deliberately reaches provider discovery quickly.
"""
from pathlib import Path
import argparse
import os
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "lib/Djex/test-church"))
import behavior_runtime as runtime

QUERY = ":synth pick : Nat → Nat where False\n"
SETTINGS = """:set synth-library off
:set synth-classical off
:set synth-providers on
:set synth-debug on
:set synth-provider-cap 1
:set synth-verify 1
:set synth-engine exference
:set synth-timeout 30
"""


def block(code):
    return ":{\n" + code + "\n:}\n"


def cases():
    original = block("namespace Longer\ndef value : Nat := 37\nend Longer")
    yield "nested", block("namespace Outer\nnamespace Inner\ndef value : Nat := 37\n"
                          "end Inner\nend Outer") + QUERY, ["Outer.Inner.value"], 1, False
    yield "qualified", "def Outer.Inner.value : Nat := 37\n" + QUERY, ["Outer.Inner.value"], 1, False
    yield "attributes-comments", block("namespace Outer\n/- def fake := 0 -/\n"
        "@[inline]\ndef value : Nat := 37\nend Outer") + QUERY, ["Outer.value"], 1, False
    yield "same-leaf", ":set synth-provider-cap 2\n" + block(
        "namespace One\ndef value : Nat := 37\nend One\n"
        "namespace Two\ndef value : Nat := 53\nend Two") + QUERY, ["One.value", "Two.value"], 1, False
    yield "append-undo", original + QUERY + block(
        "namespace A\ndef value : Nat := 53\nend A") + QUERY + ":undo\n" + QUERY, [
        "Longer.value", "A.value", "Longer.value"], 3, False
    yield "rejected-entry", original + QUERY + block(
        "namespace Bad\ndef value : Nat := True\nend Bad") + QUERY, ["Longer.value"], 2, True


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--leant", type=Path, required=True)
    parser.add_argument("--backend", type=Path, required=True)
    parser.add_argument("--lake", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    output = runtime.prepare_output_directory(args.output.resolve())
    sources = sorted({Path(__file__).resolve(), Path(runtime.__file__).resolve(),
                      ROOT / "leant.cabal", ROOT / "cabal.project", *ROOT.glob("src/**/*.hs")})
    before = {str(p): runtime.sha256(p) for p in sources}
    binaries = {str(p.resolve()): runtime.sha256(p) for p in (args.leant, args.backend, args.lake)}
    for path in sources:
        saved = output / "source" / path.relative_to(ROOT)
        saved.parent.mkdir(parents=True, exist_ok=True)
        saved.write_bytes(path.read_bytes())
    report = dict(status="running", scope=__doc__, source_hashes=before,
                  executable_hashes=binaries, cells=[])
    processes = runtime.Processes(output, 240)

    def save():
        report["processes"] = processes.rows
        runtime.write_json(output / "results.json", report)

    try:
        save()
        for name, commands, expected, queries, allows_error in cases():
            row = dict(name=name, status="running", expected_providers=expected,
                       expected_false_controls=queries)
            report["cells"].append(row)
            save()
            result = processes.run(name, [args.leant.resolve(), "--plain", "--lake", args.lake.resolve()],
                source=SETTINGS + commands + ":quit\n", cwd=ROOT,
                env=dict(os.environ, LEANT_BACKEND=str(args.backend.resolve())))
            transcript = result.stdout + result.stderr
            providers = re.findall(r'^debug provider: .*?providerLeanName = "([^"]+)"', transcript, re.M)
            summaries = re.findall(r'^supplied behavioral assertion: (\d+) passed, (\d+) falsified, '
                                   r'(\d+) inconclusive', transcript, re.M)
            errors = [line for line in transcript.splitlines() if line.startswith("error:")]
            row.update(actual_providers=providers, behavioral_summaries=summaries, errors=errors)
            if result.returncode or providers != expected:
                raise ValueError(name + ": wrong provider inventory or command failure")
            if len(summaries) != queries or any(int(p) != 0 or int(f) < 1 or int(i) != 0
                                               for p, f, i in summaries):
                raise ValueError(name + ": literal False was not conclusively rejected")
            if bool(errors) != allows_error:
                raise ValueError(name + ": unexpected declaration-error behavior")
            row["status"] = "passed"
            save()
        report["status"] = "passed"
    except BaseException as error:
        report.update(status="failed", failure=repr(error))
    finally:
        report["sources_unchanged"] = all(runtime.sha256(Path(p)) == h for p, h in before.items())
        report["executables_unchanged"] = all(runtime.sha256(Path(p)) == h for p, h in binaries.items())
        if not report["sources_unchanged"] or not report["executables_unchanged"]:
            report["status"] = "failed"
        save()
    print(report["status"], flush=True)
    return 0 if report["status"] == "passed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
