#!/usr/bin/env python3
"""Exercise bounded Lean simplification through named synthesis and kernel replay.

The live cases contain no implementation providers. Separate kernel controls
establish that the quantified positive/negative assertions require the new
fallback, and that simplifying an opaque proposition does not constitute proof.
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
from behavior_probe import parse_output
from run_corpus import reported_axioms, validate_settings

TYPE = "∀ A : Type, A → A"
IDENTITY = "fun A x => x"
PRELUDE = ["opaque BehavioralSimpFixture.pending : Prop := True"]
QUANTIFIED = "∀ n : Nat, {f} Nat n + 0 = n"
CASES = [
    ("quantified", QUANTIFIED, "candidate"),
    ("falsified", "(" + QUANTIFIED + ") ∧ False", "no_candidate"),
    ("opaque", "BehavioralSimpFixture.pending", "inconclusive"),
    ("partial", "BehavioralSimpFixture.pending ∧ (" + QUANTIFIED + ")", "inconclusive"),
    ("recovery", "{f} Nat 7 = 7", "candidate"),
]
SIMP = "by\n  solve\n  | simp (config := { maxSteps := 10000 })"
OPTIONS = ["set_option autoImplicit false", "set_option maxHeartbeats 200000"]
PROOF_AXIOMS = {"propext", "Quot.sound"}


def prepare(engines, args):
    commands = [":set synth-library off", ":set synth-classical off", ":set synth-providers off",
                ":set synth-ranking balanced", ":set synth-shown 1",
                ":set synth-djinn-strategy interleave",
                f":set synth-window {args.window}", f":set synth-verify {args.window}",
                f":set synth-steps {args.steps}", f":set synth-budget {args.budget}",
                f":set synth-timeout {args.timeout}", *PRELUDE]
    cases = []
    for engine in engines:
        commands.append(":set synth-engine " + engine)
        for operation, predicate, expected in CASES:
            name = f"simp_{engine}_{operation}"
            command = f":synth {name} : {TYPE} where {predicate.format(f=name)}"
            commands.append(command)
            cases.append(dict(engine=engine, operation=operation, name=name, type=TYPE,
                              predicate=predicate, command=command, expected=expected))
    return "\n".join([*commands, ":quit", ""]), cases


def parse_live(output, cases):
    blocks = re.split(r"(?m)^λ> :synth ", output)[1:]
    if len(blocks) != len(cases):
        raise ValueError("live query count differs from the prepared inventory")
    results = []
    for case, raw in zip(cases, blocks):
        if case["expected"] != "inconclusive":
            results.extend(parse_output("λ> :synth " + raw, [case]))
            continue
        block = raw.split("\nλ> ", 1)[0]
        if block.splitlines()[0] != case["command"].removeprefix(":synth "):
            raise ValueError("inconclusive query does not match its prepared command")
        summaries = re.findall(r"supplied behavioral assertion: (\d+) passed, (\d+) falsified, (\d+) inconclusive", block)
        if len(summaries) != 1:
            raise ValueError("missing inconclusive query summary")
        passed, falsified, inconclusive = map(int, summaries[0])
        if re.search(r"(?m)^[ \t]+it\d+[ \t]+", block) or passed or falsified or not inconclusive:
            raise ValueError("opaque or partly simplified assertion was not inconclusive")
        if "by bounded decide or simp" not in block:
            raise ValueError("inconclusive control did not complete the bounded proof methods")
        results.append(dict(case, status="inconclusive", output=block,
                            observations=dict(passed=passed, falsified=falsified, inconclusive=inconclusive)))
    return results


def exact_proposition(predicate, term):
    return "(\nlet f : (\n" + TYPE + "\n) := (\n" + term + "\n); (\n" + predicate.format(f="f") + "\n))"


def kernel_controls():
    """Expected success means a complete theorem, never mere simp progress."""
    controls = []
    for operation, predicate, _ in CASES:
        if operation == "recovery":
            continue
        for method in ("decide", "simp"):
            for negative in (False, True):
                name = f"BehavioralSimpControl.{operation}_{method}_{'negative' if negative else 'positive'}"
                target = ("¬ " if negative else "") + exact_proposition(predicate, IDENTITY)
                expected = method == "simp" and (
                    (operation == "quantified" and not negative) or
                    (operation == "falsified" and negative))
                proof = "by decide" if method == "decide" else SIMP
                source = "\n".join([*OPTIONS, *PRELUDE,
                    f"theorem {name} : {target} := {proof}",
                    *([f"#print axioms {name}"] if expected else []), ""])
                controls.append(dict(name=name, operation=operation, method=method,
                                     negative=negative, expected=expected, source=source))
    return controls


def kernel_candidate(result):
    name = "BehavioralSimpReplay.accepted"
    proof = name + "_passes"
    # Replay the exact lexical proposition, including the candidate RHS, so
    # simp needs no extra unfolding theorem absent from the live environment.
    target = exact_proposition(result["predicate"], result["candidate"])
    tactic = "by decide" if result["operation"] == "recovery" else SIMP
    source = "\n".join([*OPTIONS, *PRELUDE,
        f"def {name} : {TYPE} :=", result["candidate"],
        f"theorem {proof} : {target} := {tactic}",
        f"#print axioms {name}", f"#print axioms {proof}", ""])
    return source, name, proof


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--leant", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--engine", action="append", choices=("djinn", "exference", "both"))
    parser.add_argument("--window", type=int, default=32)
    parser.add_argument("--steps", type=int, default=4096)
    parser.add_argument("--budget", type=int, default=20000)
    parser.add_argument("--timeout", type=int, default=30)
    parser.add_argument("--process-timeout", type=float, default=600)
    parser.add_argument("--lean", default="lean")
    parser.add_argument("--toolchain", default="leanprover/lean4:v4.32.0")
    parser.add_argument("--prepare-only", action="store_true")
    args = parser.parse_args()
    runtime.validate_limits(args)
    if args.timeout <= 0 or (not args.prepare_only and args.leant is None):
        parser.error("positive timeout and --leant are required for execution")
    engines = args.engine or ["djinn", "exference", "both"]
    if len(engines) != len(set(engines)):
        parser.error("engine selections must be unique")
    output = runtime.prepare_output_directory(args.output)
    source, cases = prepare(engines, args)
    source_path = output / "commands.txt"
    source_path.write_text(source, encoding="utf-8")
    controls = kernel_controls()
    for index, control in enumerate(controls):
        path = output / f"Control{index}.lean"
        path.write_text(control["source"], encoding="utf-8")
        control.update(path=str(path.resolve()), source_sha256=runtime.sha256(path))
        del control["source"]
    report = dict(status="prepared", runner_sha256=runtime.sha256(__file__),
                  commands_sha256=runtime.sha256(source_path), cases=cases, controls=controls,
                  settings=dict(window=args.window, steps=args.steps, budget=args.budget,
                                timeout=args.timeout, process_timeout=args.process_timeout),
                  candidate_axiom_policy="empty", proof_axiom_allowance=sorted(PROOF_AXIOMS),
                  named_synthesis_providers=[], scope="bounded proof fallback, false and inconclusive controls")
    tracked_sources = ["src/Main.hs", "src/Leant/Synth/Behavioral.hs", "src/Leant/Synth/Engine.hs"]
    report["source_hashes"] = {path: runtime.sha256(ROOT / path) for path in tracked_sources}
    runtime.write_json(output / "results.json", report)
    if args.prepare_only:
        print(f"Prepared {len(cases)} live queries and {len(controls)} isolated proof controls; no processes run.")
        return 0
    executable_hash = runtime.sha256(args.leant)
    report.update(status="running", executable=str(args.leant.resolve()), executable_sha256=executable_hash)
    processes = runtime.Processes(output, args.process_timeout)
    try:
        for index, control in enumerate(controls):
            checked = processes.run(f"control-{index}", [args.lean, "+" + args.toolchain, control["path"]], cwd=ROOT)
            transcript = checked.stdout + checked.stderr
            inventory = reported_axioms(transcript, control["name"]) if control["expected"] else None
            if control["expected"]:
                passed = checked.returncode == 0 and inventory is not None and inventory <= PROOF_AXIOMS
            else:
                # A parser/import failure must not masquerade as proof rejection.
                if control["method"] == "decide":
                    diagnostic = "Decidable" in transcript and "error:" in transcript
                else:
                    diagnostic = "unsolved goals" in transcript or "simp made no progress" in transcript
                passed = checked.returncode != 0 and diagnostic
            control.update(status="passed" if passed else "failed",
                           axiom_inventory=None if inventory is None else sorted(inventory))
            runtime.write_json(output / "results.json", report)
            if not passed:
                raise ValueError("proof-method control failed: " + control["name"])
        live = processes.run("live", [args.leant.resolve(), "--plain"], source=source, cwd=ROOT,
                             env=dict(os.environ, LEANT_SYNTH_TIMEOUT=str(args.timeout)))
        if live.returncode:
            raise ValueError("live Leant exited unsuccessfully")
        transcript = live.stdout + live.stderr
        validate_settings(transcript, source)
        results = parse_live(transcript, cases)
        report["results"] = results
        report["kernel_replays"] = []
        for index, result in enumerate(row for row in results if row["status"] == "candidate"):
            replay, candidate, proof = kernel_candidate(result)
            path = output / f"Candidate{index}.lean"
            path.write_text(replay, encoding="utf-8")
            checked = processes.run(f"kernel-{index}", [args.lean, "+" + args.toolchain, path.resolve()], cwd=ROOT)
            inventories = {name: reported_axioms(checked.stdout + checked.stderr, name) for name in (candidate, proof)}
            proof_inventory = inventories[proof]
            allowed = set() if result["operation"] == "recovery" else PROOF_AXIOMS
            passed = (checked.returncode == 0 and inventories[candidate] == set()
                      and proof_inventory is not None and proof_inventory <= allowed)
            report["kernel_replays"].append(dict(case=result["name"], source_sha256=runtime.sha256(path),
                status="passed" if passed else "failed", axiom_inventories={
                    name: None if value is None else sorted(value) for name, value in inventories.items()}))
            runtime.write_json(output / "results.json", report)
            if not passed:
                raise ValueError("exact candidate replay failed: " + result["name"])
        report.update(status="passed", candidate_count=sum(row["status"] == "candidate" for row in results),
                      false_control_count=sum(row["status"] == "no_candidate" for row in results),
                      inconclusive_control_count=sum(row["status"] == "inconclusive" for row in results))
    except Exception as failure:
        report.update(status="failed", failure=str(failure))
    finally:
        report["executable_unchanged"] = runtime.sha256(args.leant) == executable_hash
        report["sources_unchanged"] = all(runtime.sha256(ROOT / path) == digest
                                          for path, digest in report["source_hashes"].items())
        if not report["executable_unchanged"] or not report["sources_unchanged"]:
            report.update(status="failed", failure="source or executable changed during acceptance")
        runtime.write_json(output / "results.json", report)
    print(report["status"] + ": " + str(output / "results.json"))
    return 0 if report["status"] == "passed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
