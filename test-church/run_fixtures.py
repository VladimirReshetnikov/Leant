#!/usr/bin/env python3
"""Run the compact Church transcripts and kernel-check every displayed term."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys

from run_corpus import parse_results, reported_axioms, validate_settings

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_FIXTURES = ["synth-church", "synth-church-rankn", "synth-church-providers",
                    "synth-church-layered-providers"]


def normalized_output(output):
    volatile = ("no Lake project", "starting Lean backend", "backend responding",
                "replaying session")
    return "\n".join(line.rstrip() for line in output.splitlines()
                     if not line.startswith(volatile)).rstrip() + "\n"


def main():
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, "reconfigure"):
            stream.reconfigure(encoding="utf-8")
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--leant", required=True, type=Path)
    parser.add_argument("--fixture", action="append", choices=DEFAULT_FIXTURES)
    parser.add_argument("--output", type=Path, default=ROOT / "test-church/generated-fixtures")
    parser.add_argument("--update-goldens", action="store_true")
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    executable_hash = hashlib.sha256(args.leant.read_bytes()).hexdigest()
    reports = []
    for name in args.fixture or DEFAULT_FIXTURES:
        if hashlib.sha256(args.leant.read_bytes()).hexdigest() != executable_hash:
            parser.error("Leant executable changed between fixtures; rerun against one build")
        path = ROOT / "test" / (name + ".txt")
        source = path.read_text(encoding="utf-8-sig")
        source_raw_hash = hashlib.sha256(path.read_bytes()).hexdigest()
        golden = path.with_suffix(".golden")
        golden_before_hash = hashlib.sha256(golden.read_bytes()).hexdigest() if golden.exists() else None
        query_lines = [(line_number, line) for line_number, line
                       in enumerate(source.splitlines(), start=1) if line.startswith(":synth ")]
        cases = [{"id": f"case{index}", "name": f"case{index}", "fixture_line": line_number,
                  "lean_type": line[len(":synth "):]}
                 for index, (line_number, line) in enumerate(query_lines)]
        if not cases:
            parser.error(f"fixture {name} contains no synthesis queries")
        environment = [line for line in source.splitlines() if not line.startswith(":")]
        env = dict(os.environ, LEANT_SYNTH_TIMEOUT="30")
        output_path = args.output / (name + ".output.txt")
        with output_path.open("w", encoding="utf-8") as transcript:
            run = subprocess.run([str(args.leant.resolve()), "--plain"], input=source,
                                 stdout=transcript, stderr=subprocess.STDOUT,
                                 text=True, encoding="utf-8", cwd=ROOT, env=env)
        output = output_path.read_text(encoding="utf-8")
        validate_settings(output, source)
        results = parse_results(output, cases)
        lines = ["set_option linter.unusedVariables false", *environment, "noncomputable section"]
        exact_vectors = True
        for index, result in enumerate(results):
            candidate = result["candidate"]
            if candidate is None:
                continue
            if name == "synth-church-providers":
                width = 8 if "ChurchProviders8" in result["lean_type"] else 12
                exact_vectors &= all(f"(«t{slot}» :=" in candidate for slot in range(width))
            lines += [f"def ChurchFixture.case{index} : {result['lean_type']} :=",
                      "\n".join("  " + line for line in candidate.splitlines()),
                      f"#print axioms ChurchFixture.case{index}"]
        replay_path = args.output / (name + ".lean")
        replay_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
        kernel = subprocess.run(["lean", "+leanprover/lean4:v4.32.0", str(replay_path.resolve())],
                                capture_output=True, text=True, encoding="utf-8", cwd=ROOT)
        kernel_output = kernel.stdout + kernel.stderr
        (args.output / (name + ".kernel.txt")).write_text(kernel_output, encoding="utf-8")
        count = sum(result["status"] == "candidate" for result in results)
        axiom_free_count = 0
        expected_axioms = True
        for index, result in enumerate(results):
            if result["candidate"] is None:
                continue
            dependencies = reported_axioms(kernel.stdout, f"ChurchFixture.case{index}")
            axiom_free_count += dependencies == set()
            if name == "synth-church-providers":
                width = 8 if "ChurchProviders8" in result["lean_type"] else 12
                expected = {f"ChurchProviders{width}.Token", f"ChurchProviders{width}.chosen"}
            elif name == "synth-church-layered-providers":
                width = 2 if "ChurchLayered.G2" in result["lean_type"] else 3
                expected = {"ChurchLayered.Seed", "ChurchLayered.seed",
                            f"ChurchLayered.G{width}", f"ChurchLayered.maker{width}"}
            else:
                expected = set()
            expected_axioms &= dependencies == expected
        executable_stable = hashlib.sha256(args.leant.read_bytes()).hexdigest() == executable_hash
        passed = (run.returncode == 0 and count == len(cases) and kernel.returncode == 0
                  and "sorryAx" not in kernel_output and exact_vectors and expected_axioms
                  and executable_stable)
        validation_passed = passed
        golden_status = "not_checked_validation_failed"
        golden_comparison_passed = None
        normalized = normalized_output(output)
        if passed and args.update_goldens:
            golden.write_text(normalized, encoding="utf-8")
            golden_status = "updated_after_validation"
        elif passed:
            def telemetry(text):
                return re.sub(r"queue limit pruned \d+", "queue limit pruned <machine-dependent>", text)
            passed = golden.exists() and telemetry(golden.read_text(encoding="utf-8")) == telemetry(normalized)
            golden_comparison_passed = passed
            golden_status = "matched" if passed else ("mismatch" if golden.exists() else "missing")
        reports.append({"fixture": name,
                        "fixture_source_sha256": hashlib.sha256(source.encode("utf-8")).hexdigest(),
                        "fixture_source_raw_sha256": source_raw_hash,
                        "live_exit_code": run.returncode,
                        "validation_passed_before_golden": validation_passed,
                        "golden_status": golden_status,
                        "golden_comparison_passed": golden_comparison_passed,
                        "golden_before_sha256": golden_before_hash,
                        "golden_after_sha256": hashlib.sha256(golden.read_bytes()).hexdigest() if golden.exists() else None,
                        "raw_output_path": str(output_path.resolve()),
                        "raw_output_sha256": hashlib.sha256(output_path.read_bytes()).hexdigest(),
                        "normalized_output_sha256": hashlib.sha256(normalized.encode("utf-8")).hexdigest(),
                        "kernel_source_path": str(replay_path.resolve()),
                        "kernel_source_sha256": hashlib.sha256(replay_path.read_bytes()).hexdigest(),
                        "kernel_output_path": str((args.output / (name + ".kernel.txt")).resolve()),
                        "kernel_output_sha256": hashlib.sha256((args.output / (name + ".kernel.txt")).read_bytes()).hexdigest(),
                        "candidate_count": count, "case_count": len(cases),
                        "kernel_exit_code": kernel.returncode, "exact_provider_vectors": exact_vectors,
                        "axiom_free_count": axiom_free_count, "expected_axioms": expected_axioms,
                        "passed": passed, "results": results})
        print(f"{name}: {count}/{len(cases)} candidates; kernel {kernel.returncode}; "
              f"{'PASS' if passed else 'FAIL'}", flush=True)
        if kernel.returncode:
            print(kernel_output)
    executable_unchanged = hashlib.sha256(args.leant.read_bytes()).hexdigest() == executable_hash
    report = {"leant_executable_sha256": executable_hash,
              "leant_executable_unchanged": executable_unchanged,
              "fixtures": reports}
    (args.output / "results.json").write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n",
                                               encoding="utf-8")
    return 0 if executable_unchanged and all(row["passed"] for row in reports) else 1


if __name__ == "__main__":
    raise SystemExit(main())
