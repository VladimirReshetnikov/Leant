#!/usr/bin/env python3
"""Synthesize ordinary recursive-data observations and replay exact Lean output.

Only datatype declarations are supplied to synthesis. Each accepted candidate
and its finite predicate are checked again in an isolated Lean source file.
"""
from __future__ import annotations

import argparse
import os
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path[:0] = [str(ROOT / "test-church"), str(ROOT / "lib/Djex/test-church")]

import behavior_runtime as runtime
from behavior_probe import latency_observer, parse_output
from run_corpus import reported_axioms, validate_settings


PRELUDE = [
    "inductive RecursiveCases.Tree (α : Type) where | leaf : α → Tree α | branch : Tree α → Tree α → Tree α",
    "inductive RecursiveCases.Payload (α : Type) where | pairLeaf : α × α → Payload α | next : Payload α → Payload α",
    "abbrev RecursiveCases.Sequence (α : Type) := List α",
]

CASES = [
    ("null", "{α : Type} → List α → Bool",
     "{f} ([] : List Nat) = true ∧ {f} [11] = false ∧ {f} [true, false] = false"),
    ("headOr", "{α : Type} → α → List α → α",
     "{f} 91 ([] : List Nat) = 91 ∧ {f} 91 [11, 29] = 11 ∧ {f} false [true] = true"),
    ("tailOr", "{α : Type} → List α → List α → List α",
     "{f} [91] ([] : List Nat) = [91] ∧ {f} [91] [11] = [] ∧ {f} [91] [11, 29, 37] = [29, 37] ∧ {f} [false] [true, true] = [true]"),
    ("tree", "{α : Type} → α → RecursiveCases.Tree α → α",
     "{f} 91 (.leaf 11) = 11 ∧ {f} 91 (.branch (.leaf 11) (.leaf 29)) = 91 ∧ {f} false (.leaf true) = true"),
    ("alias", "{α : Type} → α → RecursiveCases.Sequence α → α",
     "{f} 91 ([] : List Nat) = 91 ∧ {f} 91 [11, 29] = 11 ∧ {f} false [true] = true"),
    ("unconsOr", "{α : Type} → α → List α → α × List α",
     "{f} 91 ([] : List Nat) = (91, []) ∧ {f} 91 [11, 29] = (11, [29]) ∧ {f} false [true, false] = (true, [false])"),
    ("tupleField", "{α : Type} → α → RecursiveCases.Payload α → α",
     "{f} 91 (.pairLeaf (11, 29)) = 11 ∧ {f} 91 (.next (.pairLeaf (11, 29))) = 91 ∧ {f} false (.pairLeaf (true, false)) = true"),
    ("independent", "{α β : Type} → α → β → List α → List β → α × β",
     "{f} 91 false ([] : List Nat) [] = (91, false) ∧ {f} 91 false [11, 29] [true] = (11, true) ∧ {f} 91 false [] [true] = (91, true)"),
]


def prepare(engines, selected, args):
    commands = [":set synth-library off", ":set synth-classical off", ":set synth-providers off",
                ":set synth-ranking balanced", ":set synth-shown 1",
                ":set synth-djinn-strategy interleave",
                f":set synth-window {args.window}", f":set synth-verify {args.window}",
                f":set synth-steps {args.steps}", f":set synth-budget {args.budget}",
                f":set synth-timeout {args.timeout}", *PRELUDE]
    cases = []
    for engine in engines:
        commands.append(":set synth-engine " + engine)
        for operation, target, predicate in CASES:
            if operation not in selected:
                continue
            name = f"recursive_{engine}_{operation}"
            assertion = predicate.format(f=name)
            command = f":synth {name} : {target} where {assertion}"
            commands.append(command)
            cases.append(dict(engine=engine, operation=operation, name=name,
                              type=target, predicate=predicate, command=command, expected="candidate"))
        name = f"recursive_{engine}_reject_all"
        command = f":synth {name} : Nat → Nat where False"
        commands.append(command)
        cases.append(dict(engine=engine, operation="reject_all", name=name,
                          type="Nat → Nat", predicate="False", command=command, expected="no_candidate"))
    return "\n".join([*commands, ":quit", ""]), cases


def kernel_source(case):
    name = "RecursiveReplay.accepted"
    proof = name + "_passes"
    return "\n".join([
        "set_option autoImplicit false", *PRELUDE,
        f"def {name} : {case['type']} :=", case["candidate"],
        f"theorem {proof} : {case['predicate'].format(f=name)} := by decide",
        f"#print axioms {name}", f"#print axioms {proof}", "",
    ]), [name, proof]


def parse_case_results(transcript, cases):
    """Validate the whole inventory, then retain every independent case result."""
    blocks = re.split(r"(?m)^λ> :synth ", transcript)[1:]
    if len(blocks) != len(cases):
        raise ValueError("live synthesis command count differs from the prepared inventory")
    results = []
    for case, block in zip(cases, blocks):
        block = block.split("\nλ> ", 1)[0]
        if block.splitlines()[0] != case["command"].removeprefix(":synth "):
            raise ValueError("named where command differs from its prepared case")
        try:
            results.extend(parse_output("λ> :synth " + block, [case]))
        except ValueError as failure:
            results.append(dict(case, status="failed", failure=str(failure), output=block))
    return results


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--leant", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--engine", action="append", choices=("djinn", "exference", "both"))
    parser.add_argument("--operation", action="append", choices=[case[0] for case in CASES])
    parser.add_argument("--window", type=int, default=1024)
    parser.add_argument("--steps", type=int, default=100000)
    parser.add_argument("--budget", type=int, default=100000)
    parser.add_argument("--timeout", type=int, default=90)
    parser.add_argument("--process-timeout", type=float, default=1200)
    parser.add_argument("--lean", default="lean")
    parser.add_argument("--toolchain", default="leanprover/lean4:v4.32.0")
    parser.add_argument("--prepare-only", action="store_true")
    args = parser.parse_args()
    runtime.validate_limits(args)
    if args.timeout <= 0 or (not args.prepare_only and args.leant is None):
        parser.error("positive timeout and --leant are required for execution")
    engines = args.engine or ["djinn", "exference", "both"]
    selected = args.operation or [case[0] for case in CASES]
    if len(engines) != len(set(engines)) or len(selected) != len(set(selected)):
        parser.error("engine and operation selections must be unique")
    source, cases = prepare(engines, selected, args)
    output = runtime.prepare_output_directory(args.output)
    source_path = output / "commands.txt"
    source_path.write_text(source, encoding="utf-8")
    report = dict(status="prepared", runner_sha256=runtime.sha256(__file__),
                  commands_sha256=runtime.sha256(source_path), cases=cases,
                  settings=dict(window=args.window, steps=args.steps, budget=args.budget,
                                timeout=args.timeout, process_timeout=args.process_timeout,
                                strategy="interleave"), named_synthesis_providers=[],
                  scope="finite ordinary-data observations; explicit defaults; no recursion synthesis")
    report["source_hashes"] = {str(path.relative_to(ROOT)): runtime.sha256(path) for path in [
        ROOT / "src/Main.hs", ROOT / "src/Leant/Synth/Engine.hs",
        ROOT / "src/Leant/Synth/Behavioral.hs", ROOT / "lib/Djex/djinn/src-core/Djinn/Core.hs",
        Path(__file__), ROOT / "test-church/behavior_probe.py", ROOT / "test-church/run_corpus.py",
        ROOT / "lib/Djex/test-church/behavior_runtime.py",
        ROOT / "lib/Djex/djinn/src-core/Djinn/Internal/TypeFormula.hs",
        ROOT / "lib/Djex/djinn/src-core/Djinn/Internal/LJT.hs",
        ROOT / "lib/Djex/exference/src-core/Language/Haskell/Exference/Core/Internal/Exference.hs",
        ROOT / "lib/Djex/exference/src-core/Language/Haskell/Exference/Core/Internal/ExpressionCheck.hs",
    ]}
    runtime.write_json(output / "results.json", report)
    if args.prepare_only:
        print(f"Prepared {len(cases)} commands; no processes run.")
        return 0
    digest = runtime.sha256(args.leant)
    report.update(status="running", executable=str(args.leant.resolve()), executable_sha256=digest)
    processes = runtime.Processes(output, args.process_timeout)
    try:
        live = processes.run("live", [args.leant.resolve(), "--plain"], source=source, cwd=ROOT,
                             env=dict(os.environ, LEANT_SYNTH_TIMEOUT=str(args.timeout)),
                             observe=latency_observer(runtime, cases))
        if live.returncode:
            raise ValueError("live Leant exited unsuccessfully")
        transcript = live.stdout + live.stderr
        validate_settings(transcript, source)
        results = parse_case_results(transcript, cases)
        report["results"] = results
        report["kernel_replays"] = []
        for index, result in enumerate(row for row in results if row["status"] == "candidate"):
            replay, names = kernel_source(result)
            path = output / f"Candidate{index}.lean"
            path.write_text(replay, encoding="utf-8")
            checked = processes.run(f"kernel-{index}",
                                    [args.lean, "+" + args.toolchain, path.resolve()], cwd=ROOT)
            inventories = {name: reported_axioms(checked.stdout + checked.stderr, name) for name in names}
            passed = checked.returncode == 0 and all(value == set() for value in inventories.values())
            report["kernel_replays"].append(dict(source_sha256=runtime.sha256(path),
                case=result["name"], status="passed" if passed else "failed",
                axiom_inventories={name: None if value is None else sorted(value)
                                  for name, value in inventories.items()}))
            runtime.write_json(output / "results.json", report)
        failures = [row["name"] for row in results if row["status"] == "failed"]
        replay_failures = [row["case"] for row in report["kernel_replays"] if row["status"] != "passed"]
        report.update(status="failed" if failures or replay_failures else "passed",
                      candidate_count=sum(row["status"] == "candidate" for row in results),
                      false_control_count=sum(row["status"] == "no_candidate" for row in results),
                      failed_cases=failures, failed_kernel_replays=replay_failures)
    except Exception as failure:
        report.update(status="failed", failure=str(failure))
    finally:
        report["executable_unchanged"] = runtime.sha256(args.leant) == digest
        report["sources_unchanged"] = all(runtime.sha256(ROOT / path) == value
                                           for path, value in report["source_hashes"].items())
        if not report["executable_unchanged"]:
            report.update(status="failed", failure="executable changed during acceptance")
        if not report["sources_unchanged"]:
            report.update(status="failed", failure="source changed during acceptance")
        report["processes"] = processes.rows
        runtime.write_json(output / "results.json", report)
    print(f"Ordinary recursive behavior: {report['status']}; {report.get('candidate_count', 0)} accepted")
    return 0 if report["status"] == "passed" else 1


if __name__ == "__main__":
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, "reconfigure"):
            stream.reconfigure(encoding="utf-8")
    raise SystemExit(main())
