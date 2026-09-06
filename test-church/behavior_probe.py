#!/usr/bin/env python3
"""Exercise six named Lean where predicates, then kernel-replay exact outputs.

The shared specification comes from canonical/vendored Djex. No synthesis or
compiler runs occur in --prepare-only mode. All three frontend engine modes are
selected by default; subset runs are explicitly recorded as subsets.
"""
from __future__ import annotations

import argparse
import hashlib
import importlib
import os
from pathlib import Path
import re
import sys

from run_corpus import reported_axioms, validate_settings

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent


def parse_output(output, cases):
    if not cases or len({case["name"] for case in cases}) != len(cases):
        raise ValueError("expected a nonempty, unique prepared query inventory")
    blocks = re.split(r"(?m)^λ> :synth ", output)[1:]
    if len(blocks) != len(cases):
        raise ValueError("live synthesis command count differs from the prepared inventory")
    results = []
    for case, block in zip(cases, blocks):
        block = block.split("\nλ> ", 1)[0]
        if block.splitlines()[0] != case["command"].removeprefix(":synth "):
            raise ValueError("named where command differs from its prepared case")
        summaries = re.findall(r"supplied behavioral assertion: (\d+) passed, (\d+) falsified, (\d+) inconclusive", block)
        if len(summaries) != 1:
            raise ValueError("missing or duplicate supplied-assertion summary")
        passed, falsified, inconclusive = map(int, summaries[0])
        observations = {"passed": passed, "falsified": falsified, "inconclusive": inconclusive}
        labels = re.findall(r"(?m)^[ \t]+it([0-9]+)[ \t]+", block)
        if case["expected"] == "no_candidate":
            if labels or passed or not falsified or inconclusive:
                raise ValueError("where False did not establish actual predicate rejection")
            results.append({**case, "status": "no_candidate", "observations": observations, "output": block})
            continue
        if labels != ["1"] or passed < 1:
            raise ValueError(f"expected one behaviorally accepted output for {case['name']}: {labels}")
        match = re.search(r"(?m)^[ \t]+it1[ \t]+(.+)$", block)
        term_lines = []
        for line in block[match.start(1):].splitlines():
            if re.match(r"^(?:note:|debug |error:|[ \t]+it[0-9]+[ \t])", line):
                break
            term_lines.append(line)
        term = "\n".join(term_lines).strip()
        if not term or re.search(r"\b(?:sorry|admit|unsafe|axiom)\b", term):
            raise ValueError("unchecked or empty displayed candidate")
        if re.search(r"\bBehavior(?:Church|Control|Candidates)\.", term):
            raise ValueError("oracle or replay declarations appeared as synthesis providers")
        results.append({**case, "status": "candidate", "candidate": term, "observations": observations, "output": block})
    return results


def commands(spec, engines, operations, args, targets):
    lines = [":set synth-library off", ":set synth-classical off", ":set synth-providers off",
             ":set synth-ranking balanced", ":set synth-shown 1",
             f":set synth-djinn-strategy {args.djinn_strategy}",
             f":set synth-window {args.window}", f":set synth-verify {args.window}",
             f":set synth-steps {args.steps}", f":set synth-budget {args.budget}",
             f":set synth-timeout {args.timeout}", *spec.lean_prelude()]
    cases = []
    for engine in engines:
        lines.append(":set synth-engine " + engine)
        for operation in operations:
            name = f"behavior_{engine}_{operation}"
            target = targets[operation]
            command = f":synth {name} : {target} where {spec.lean_predicate(operation, name)}"
            lines.append(command)
            cases.append({"engine": engine, "operation": operation, "name": name,
                          "type": target, "command": command, "expected": "candidate",
                          "finite_observation_count": spec.OBSERVATIONS[operation]})
        name = "behavior_" + engine + "_reject_all"
        command = f":synth {name} : ∀ A : Type, A → A where False"
        lines.append(command)
        cases.append({"engine": engine, "operation": "reject_all", "name": name,
                      "type": "∀ A : Type, A → A", "command": command,
                      "expected": "no_candidate"})
    return "\n".join([*lines, ":quit", ""]), cases


def kernel_source(spec, results):
    """One exact candidate OR controls, with no other replay declarations."""
    candidates = [result for result in results if result["status"] == "candidate"]
    if len(candidates) > 1:
        raise ValueError("candidate kernel files must be isolated per query")
    lines = spec.lean_prelude()
    names = []
    for result in candidates:
        name = "BehaviorCandidates." + result["name"]
        proof = name + "_passes"
        lines.extend([f"def {name} : {result['type']} :=",
                      "\n".join("  " + line for line in result["candidate"].splitlines()),
                      f"theorem {proof} : {spec.lean_predicate(result['operation'], name)} := by decide",
                      f"#print axioms {name}", f"#print axioms {proof}"])
        names += [name, proof]
    controls, control_names = spec.lean_control_source() if not candidates else ([], [])
    lines += controls
    return "\n".join(lines) + "\n", names + control_names


def isolated_kernel_sources(spec, results):
    sources = []
    for index, result in enumerate(row for row in results if row["status"] == "candidate"):
        source, names = kernel_source(spec, [result])
        sources.append((f"BehaviorCandidate{index}.lean", source, names))
    controls, names = kernel_source(spec, [])
    sources.append(("OracleControls.lean", controls, names))
    return sources


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--leant", type=Path)
    parser.add_argument("--spec-dir", type=Path, default=ROOT / "lib/Djex/test-church",
                        help="canonical/vendored Djex directory containing behavior_spec.py and manifest.json")
    parser.add_argument("--output", type=Path, default=HERE / "quality-results/behavior",
                        help="new or empty directory; prior receipts are never overwritten")
    parser.add_argument("--engine", action="append", choices=("djinn", "exference", "both"))
    parser.add_argument("--operation", action="append", choices=("not", "swap", "map", "append", "reverse", "filter"))
    parser.add_argument("--window", type=int, default=256,
                        help="sets synth-window and synth-verify, including Djinn raw cutoff; shown stays 1 (default: 256; calibration is explicit)")
    parser.add_argument("--djinn-strategy", choices=("depth-first", "interleave"), default="depth-first",
                        help="explicit Djinn branch strategy, including Both; preserves ordinary depth-first default")
    parser.add_argument("--steps", type=int, default=100000, help="Exference only")
    parser.add_argument("--budget", type=int, default=100000, help="explicit Djinn choice-point budget")
    parser.add_argument("--timeout", type=int, default=30, help="shared synthesis command timeout, not end-to-end")
    parser.add_argument("--process-timeout", type=float, default=900, help="separate live/kernel process wall guard")
    parser.add_argument("--lean", default="lean")
    parser.add_argument("--toolchain", default="leanprover/lean4:v4.32.0")
    parser.add_argument("--prepare-only", action="store_true")
    args = parser.parse_args()
    sys.path.insert(0, str(args.spec_dir.resolve()))
    spec = importlib.import_module("behavior_spec")
    runtime = importlib.import_module("behavior_runtime")
    runtime.validate_limits(args)
    if args.timeout <= 0:
        parser.error("timeout must be a positive synthesis bound")
    if not args.prepare_only and args.leant is None:
        parser.error("--leant is required unless --prepare-only")
    engines = args.engine or ["djinn", "exference", "both"]
    operations = args.operation or list(spec.OPERATIONS)
    if len(set(engines)) != len(engines) or len(set(operations)) != len(operations):
        parser.error("duplicate engine/operation selections are not coverage")
    args.output = runtime.prepare_output_directory(args.output)
    provenance = runtime.source_provenance(args.spec_dir / "manifest.json")
    targets = {row["name"]: row["lean_target"] for row in provenance["operations"]}
    source, cases = commands(spec, engines, operations, args, targets)
    commands_path = args.output / "queries.txt"
    commands_path.write_text(source, encoding="utf-8")
    controls, control_names = kernel_source(spec, [])
    control_path = args.output / "OracleControls.lean"
    control_path.write_text(controls, encoding="utf-8")
    report = {"status": "prepared", "validation_mode": "prepared_only",
              "provenance": provenance,
              "runner_sha256": runtime.sha256(__file__), "spec_sha256": runtime.sha256(args.spec_dir / "behavior_spec.py"),
              "input_sha256": runtime.sha256(commands_path),
              "input_canonical_lf_sha256": hashlib.sha256(source.encode("utf-8")).hexdigest(),
              "engines": engines, "operations": operations,
              "expected_candidate_count": len(engines) * len(operations),
              "expected_false_oracle_count": len(engines),
              "settings": {"ranking": "balanced", "shown": 1, "window": args.window,
                           "djinn_strategy": args.djinn_strategy,
                           "verify": args.window, "exference_steps": args.steps,
                           "djinn_choice_budget": args.budget, "synthesis_timeout_seconds": args.timeout,
                           "separate_process_guard_seconds": args.process_timeout},
              "named_synthesis_providers": [],
              "universe_policy": "element and eliminator-result Type0; predicative Church encodings live in Type1",
              "oracle_control_source": str(control_path.resolve()),
              "oracle_control_sha256": runtime.sha256(control_path),
              "oracle_control_inventory_count": len(control_names), "cases": cases}
    runtime.write_json(args.output / "results.json", report)
    if args.prepare_only:
        print(f"Prepared {report['expected_candidate_count']} Lean behavioral queries plus {len(engines)} false-oracle controls; no processes run.")
        return 0
    digest = runtime.sha256(args.leant)
    report.update(status="running", validation_mode="live_synthesis_then_exact_kernel_behavior_replay",
                  executable_path=str(args.leant.resolve()), executable_sha256=digest)
    processes = runtime.Processes(args.output, args.process_timeout)
    try:
        live = processes.run("live", [args.leant.resolve(), "--plain"], source=source, cwd=ROOT,
                             env=dict(os.environ, LEANT_SYNTH_TIMEOUT=str(args.timeout)))
        output = live.stdout + live.stderr
        if live.returncode:
            raise ValueError("live Leant exited unsuccessfully")
        validate_settings(output, source)
        results = parse_output(output, cases)
        report["results"] = results
        expected_cells = {(engine, operation) for engine in engines for operation in operations}
        candidates = [row for row in results if row["status"] == "candidate"]
        rejected = [row for row in results if row["status"] == "no_candidate"]
        if (len(candidates) != len(expected_cells)
                or {(row["engine"], row["operation"]) for row in candidates} != expected_cells
                or [row["engine"] for row in rejected] != engines):
            raise ValueError("candidate or false-oracle matrix differs from its exact selected inventory")
        report["kernel_replays"] = []
        inventory_count = 0
        for index, (filename, replay, names) in enumerate(isolated_kernel_sources(spec, results)):
            path = args.output / filename
            path.write_text(replay, encoding="utf-8")
            command = [args.lean]
            if args.toolchain:
                command.append("+" + args.toolchain)
            command.append(path.resolve())
            checked = processes.run("kernel-" + str(index), command, cwd=ROOT)
            kernel_output = checked.stdout + checked.stderr
            inventories = {name: reported_axioms(kernel_output, name) for name in names}
            declared = re.findall(r"(?m)^'([^']+)' (?:does not depend on any axioms|depends on axioms:)", kernel_output)
            passed = (checked.returncode == 0 and sorted(declared) == sorted(names)
                      and all(value == set() for value in inventories.values()))
            report["kernel_replays"].append({"path": str(path.resolve()), "source_sha256": runtime.sha256(path),
                                              "exit_code": checked.returncode, "declarations": names,
                                              "empty_axiom_inventory_count": len(names) if passed else None,
                                              "status": "passed" if passed else "failed"})
            runtime.write_json(args.output / "results.json", report)
            if not passed:
                raise ValueError("isolated candidate/predicate/control kernel replay or empty-axiom inventory failed: " + filename)
            inventory_count += len(names)
        report.update(status="passed", candidate_count=sum(row["status"] == "candidate" for row in results),
                      false_oracle_count=sum(row["status"] == "no_candidate" for row in results),
                      kernel_exit_code=0,
                      kernel_inventory_count=inventory_count, empty_axiom_inventory_count=inventory_count,
                      exact_type_wrong_controls=10, oracle_positive_controls=6, specialized_swap_control=1)
    except Exception as failure:
        report.update(status="failed", failure=str(failure))
    finally:
        report["executable_unchanged"] = runtime.sha256(args.leant) == digest
        if not report["executable_unchanged"]:
            report.update(status="failed", failure="executable changed during acceptance")
        report["processes"] = processes.rows
        runtime.write_json(args.output / "results.json", report)
    print(f"Lean behavioral corpus: {report['status']}; {report.get('candidate_count', 0)}/{report['expected_candidate_count']} candidates")
    return 0 if report["status"] == "passed" else 1


if __name__ == "__main__":
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, "reconfigure"):
            stream.reconfigure(encoding="utf-8")
    raise SystemExit(main())
