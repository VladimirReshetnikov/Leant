"""Check production-generated combined decision commands with the Lean kernel.

These are command/protocol controls, not synthesis acceptance. Live public
queries and original-bound recursor regressions remain separate requirements.
"""
from pathlib import Path
import argparse
import json
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "lib/Djex/test-church"))
import behavior_runtime as runtime


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--lean", type=Path, required=True,
                        help="Exact toolchain kernel executable, not an Elan shim")
    args = parser.parse_args()
    output = runtime.prepare_output_directory(args.output)
    kernel = args.lean.resolve(strict=True)
    sources = [Path(__file__), ROOT / "test-behavioral/CombinedDecisionPrograms.hs",
               ROOT / "src/Leant/Synth/Behavioral.hs", kernel]
    snapshot = lambda: {str(p): runtime.sha256(p) for p in sources}
    report = dict(status="running", before=snapshot(), controls=[])
    processes = runtime.Processes(output, 120)
    try:
        generated = processes.run("generate", ["cabal", "exec", "--", "runghc",
            "-package=djex", "-isrc", "test-behavioral/CombinedDecisionPrograms.hs",
            str(output)], cwd=ROOT)
        if generated.returncode:
            raise ValueError("Production command generation failed")
        expected = dict(positive=1, negative=2, undecided=0, comments=1,
                        lexical=1, namespace=1, collision=1)
        for name in [*expected, "illtyped", "sorry", "duplicate"]:
            source = output / (name + ".lean")
            checked = processes.run(name, [str(kernel), str(source)], cwd=ROOT)
            transcript = checked.stdout + checked.stderr
            tags = re.findall(r"^LEANT_BEHAVIOR_DECISION:([^\r\n]*)$", transcript, re.M)
            if name in expected:
                passed = (checked.returncode == 0 and tags == [str(expected[name])]
                          and "sorry" not in transcript and "error:" not in transcript)
            elif name == "illtyped":
                passed = checked.returncode != 0 and "type mismatch" in transcript.lower()
            elif name == "sorry":
                # A successful process and apparent success tag are insufficient.
                passed = ("declaration uses `sorry`" in transcript
                          or "declaration uses 'sorry'" in transcript) and "1" in tags
            else:
                # Valid proofs may emit extra output; the decoder must refuse it.
                passed = checked.returncode == 0 and len(tags) > 1 and "2" in tags
            report["controls"].append(dict(name=name, passed=passed, tags=tags,
                exit_code=checked.returncode, source_sha256=runtime.sha256(source)))
            runtime.write_json(output / "results.json", report)
            if not passed:
                raise ValueError("Combined decision control failed: " + name)
        report["status"] = "passed"
    finally:
        report["after"] = snapshot()
        report["unchanged"] = report["before"] == report["after"]
        report["processes"] = processes.rows
        if not report["unchanged"] or report["status"] == "running":
            report["status"] = "failed"
        runtime.write_json(output / "results.json", report)
        print(json.dumps({k: report[k] for k in ["status", "unchanged", "controls"]}))
    return 0 if report["status"] == "passed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
