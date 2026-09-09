#!/usr/bin/env python3
"""Accept recursive programs composed from supplied, checked generic folds.

Each query has a fresh Leant process, with no earlier synthesized definitions.
Private ordinary datatypes keep native List operations out of live discovery.
A separate providers-off family takes a rank-N native List fold argument.
"""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path[:0] = [str(ROOT / "test-church"), str(ROOT / "lib/Djex/test-church")]

import behavior_runtime as runtime
from behavior_probe import parse_output
from run_corpus import reported_axioms, validate_settings


def require_completed_live_query(transcript):
    """Observations from a cancelled prefix do not satisfy query completion."""
    if re.search(r"(?m)^the engine did not finish within [0-9]+s\b", transcript):
        raise TimeoutError("synthesis command exceeded its prepared deadline")


DATATYPES = [
    "namespace FoldFixture",
    "set_option genSizeOf false in inductive Seq (α : Type) where | nil : Seq α | cons : α → Seq α → Seq α deriving DecidableEq",
    "set_option genSizeOf false in inductive Tree (α : Type) where | leaf : α → Tree α | branch : Tree α → Tree α → Tree α deriving DecidableEq",
    "set_option genSizeOf false in inductive Count where | zero : Count | succ : Count → Count deriving DecidableEq",
    "end FoldFixture",
]
FOLD_DEFINITIONS = {
    "FoldFixture.foldSeq":
        "def FoldFixture.foldSeq {α ρ : Type} (step : α → ρ → ρ) (zero : ρ) : FoldFixture.Seq α → ρ | .nil => zero | .cons x xs => step x (FoldFixture.foldSeq step zero xs)",
    "FoldFixture.foldTree":
        "def FoldFixture.foldTree {α ρ : Type} (leaf : α → ρ) (branch : ρ → ρ → ρ) : FoldFixture.Tree α → ρ | .leaf x => leaf x | .branch l r => branch (FoldFixture.foldTree leaf branch l) (FoldFixture.foldTree leaf branch r)",
}
PRELUDE = [*DATATYPES, *FOLD_DEFINITIONS.values()]
CONSTRUCTOR_PROVIDERS = {
    "FoldFixture.Seq.nil", "FoldFixture.Seq.cons",
    "FoldFixture.Tree.leaf", "FoldFixture.Tree.branch",
    "FoldFixture.Count.zero", "FoldFixture.Count.succ",
}
# Generated equality instances are allowed structural machinery. Every other
# discovered name fails closed and remains in the captured transcript.
EQUALITY_PROVIDERS = {
    "FoldFixture.instDecidableEqSeq", "FoldFixture.instDecidableEqTree",
    "FoldFixture.instDecidableEqCount",
}
ALLOWED_PROVIDERS = set(FOLD_DEFINITIONS) | CONSTRUCTOR_PROVIDERS | EQUALITY_PROVIDERS
FORBIDDEN_IMPLEMENTATION = re.compile(
    r"\b(?:sorry|admit|unsafe|axiom)\b"
    r"|\b(?:FoldReplay|BehaviorChurch|BehaviorCandidates|BehaviorControl)\."
    r"|\bList\.(?:map|append|length|reverse|flatten|flatMap)\b"
    r"|\bFoldFixture\.(?:map|append|length|treeMap|treeFlatten)\b"
)


def seq(values, element_type):
    result = "(FoldFixture.Seq.nil : FoldFixture.Seq " + element_type + ")"
    for value in reversed(values):
        result = f"(FoldFixture.Seq.cons {value} {result})"
    return result


def count(value):
    result = "FoldFixture.Count.zero"
    for _ in range(value):
        result = f"(FoldFixture.Count.succ {result})"
    return result


def leaf(value):
    return f"(FoldFixture.Tree.leaf {value})"


def branch(left, right):
    return f"(FoldFixture.Tree.branch {left} {right})"


def predicate(observations):
    return " ∧ ".join("(" + observation + ")" for observation in observations)


def supplied_cases():
    numbers = ["11", "29", "37", "41", "53"]
    bools = ["true", "false", "true", "false", "true"]
    natural_tree = branch(leaf("11"), branch(branch(leaf("29"), leaf("37")), leaf("41")))
    boolean_tree = branch(branch(leaf("true"), leaf("false")), leaf("true"))
    mapped_tree = branch(leaf("true"), branch(branch(leaf("false"), leaf("false")), leaf("false")))
    mapped_bool_tree = branch(branch(leaf("7"), leaf("11")), leaf("7"))
    return [
        dict(operation="map", type="{α β : Type} → (α → β) → FoldFixture.Seq α → FoldFixture.Seq β",
             required_providers=["FoldFixture.foldSeq"],
             predicate=predicate([
                 f"{{f}} (fun n : Nat => n == 11) {seq([], 'Nat')} = {seq([], 'Bool')}",
                 f"{{f}} (fun n : Nat => n == 11) {seq(['11'], 'Nat')} = {seq(['true'], 'Bool')}",
                 f"{{f}} (fun n : Nat => n == 11) {seq(numbers, 'Nat')} = {seq(['true', 'false', 'false', 'false', 'false'], 'Bool')}",
                 f"{{f}} (fun b : Bool => if b then (7 : Nat) else 11) {seq(bools, 'Bool')} = {seq(['7', '11', '7', '11', '7'], 'Nat')}",
             ])),
        dict(operation="append", type="{α : Type} → FoldFixture.Seq α → FoldFixture.Seq α → FoldFixture.Seq α",
             required_providers=["FoldFixture.foldSeq"],
             predicate=predicate([
                 f"{{f}} {seq([], 'Nat')} {seq([], 'Nat')} = {seq([], 'Nat')}",
                 f"{{f}} {seq([], 'Nat')} {seq(numbers, 'Nat')} = {seq(numbers, 'Nat')}",
                 f"{{f}} {seq(numbers, 'Nat')} {seq([], 'Nat')} = {seq(numbers, 'Nat')}",
                 f"{{f}} {seq(numbers[:2], 'Nat')} {seq(numbers[2:], 'Nat')} = {seq(numbers, 'Nat')}",
                 f"{{f}} {seq(bools[:2], 'Bool')} {seq(bools[2:], 'Bool')} = {seq(bools, 'Bool')}",
             ])),
        dict(operation="length", type="{α : Type} → FoldFixture.Seq α → FoldFixture.Count",
             required_providers=["FoldFixture.foldSeq"],
             predicate=predicate([
                 f"{{f}} {seq(numbers[:size], 'Nat')} = {count(size)}"
                 for size in (0, 1, 2, 5)
             ] + [f"{{f}} {seq(bools, 'Bool')} = {count(5)}"])),
        dict(operation="treeMap", type="{α β : Type} → (α → β) → FoldFixture.Tree α → FoldFixture.Tree β",
             required_providers=["FoldFixture.foldTree"],
             predicate=predicate([
                 f"{{f}} (fun n : Nat => n == 11) {leaf('11')} = {leaf('true')}",
                 f"{{f}} (fun n : Nat => n == 11) {natural_tree} = {mapped_tree}",
                 f"{{f}} (fun b : Bool => if b then (7 : Nat) else 11) {boolean_tree} = {mapped_bool_tree}",
             ])),
        dict(operation="treeFlatten", type="{α : Type} → FoldFixture.Tree α → FoldFixture.Seq α",
             required_providers=["FoldFixture.foldTree", "FoldFixture.foldSeq"],
             predicate=predicate([
                 f"{{f}} {leaf('(11 : Nat)')} = {seq(['11'], 'Nat')}",
                 f"{{f}} {natural_tree} = {seq(['11', '29', '37', '41'], 'Nat')}",
                 f"{{f}} {boolean_tree} = {seq(['true', 'false', 'true'], 'Bool')}",
             ])),
    ]


def native_cases():
    fold = "(∀ ρ : Type, (α → ρ → ρ) → ρ → List α → ρ)"
    nat_fold = "(fun ρ => @List.foldr Nat ρ)"
    bool_fold = "(fun ρ => @List.foldr Bool ρ)"
    return [
        dict(operation="map", type="{α β : Type} → " + fold + " → (α → β) → List α → List β",
             required_providers=[],
             predicate=predicate([
                 f"{{f}} {nat_fold} (fun n : Nat => n == 11) [] = ([] : List Bool)",
                 f"{{f}} {nat_fold} (fun n : Nat => n == 11) [11] = [true]",
                 f"{{f}} {nat_fold} (fun n : Nat => n == 11) [11, 29, 37, 41, 53] = [true, false, false, false, false]",
                 f"{{f}} {bool_fold} (fun b : Bool => if b then (7 : Nat) else 11) [true, false, true] = [7, 11, 7]",
             ])),
        dict(operation="append", type="{α : Type} → " + fold + " → List α → List α → List α",
             required_providers=[],
             predicate=predicate([
                 f"{{f}} {nat_fold} [] [] = ([] : List Nat)",
                 f"{{f}} {nat_fold} [] [11, 29] = [11, 29]",
                 f"{{f}} {nat_fold} [11, 29] [] = [11, 29]",
                 f"{{f}} {nat_fold} [11, 29] [37, 41, 53] = [11, 29, 37, 41, 53]",
                 f"{{f}} {bool_fold} [true, false] [true] = [true, false, true]",
             ])),
        dict(operation="length", type="{α τ : Type} → " + fold + " → τ → (τ → τ) → List α → τ",
             required_providers=[],
             predicate=predicate([
                 f"{{f}} {nat_fold} 0 Nat.succ [] = 0",
                 f"{{f}} {nat_fold} 0 Nat.succ [11] = 1",
                 f"{{f}} {nat_fold} 0 Nat.succ [11, 29] = 2",
                 f"{{f}} {nat_fold} 0 Nat.succ [11, 29, 37, 41, 53] = 5",
                 f"{{f}} {bool_fold} 0 Nat.succ [true, false, true] = 3",
                 f"{{f}} {nat_fold} true Bool.not [11, 29] = true",
                 f"{{f}} {nat_fold} true Bool.not [11, 29, 37] = false",
             ])),
    ]


FAMILIES = {"supplied": supplied_cases(), "native": native_cases()}
OPERATIONS = sorted({case["operation"] for cases in FAMILIES.values() for case in cases})


def command_source(case, args):
    enabled = case["family"] == "supplied"
    settings = [
        ":set synth-library off", ":set synth-classical off",
        ":set synth-providers " + ("on" if enabled else "off"),
        ":set synth-debug on", ":set synth-ranking balanced",
        ":set synth-shown 1", ":set synth-djinn-strategy interleave",
        f":set synth-provider-cap {args.provider_cap}",
        f":set synth-window {args.window}", f":set synth-verify {args.window}",
        f":set synth-steps {args.steps}", f":set synth-budget {args.budget}",
        f":set synth-timeout {args.timeout}", ":set synth-engine " + case["engine"],
    ]
    return "\n".join([*settings, *(PRELUDE if enabled else []), case["command"], ":quit", ""])


def prepare(engines, families, operations):
    cases = []
    for engine in engines:
        for family in families:
            for specification in FAMILIES[family]:
                if specification["operation"] not in operations:
                    continue
                name = f"recursor_{engine}_{family}_{specification['operation']}"
                case = dict(specification, engine=engine, family=family, name=name, expected="candidate")
                case["command"] = f":synth {name} : {case['type']} where {case['predicate'].format(f=name)}"
                cases.append(case)
            name = f"recursor_{engine}_{family}_reject_all"
            target = ("FoldFixture.Seq FoldFixture.Count → FoldFixture.Seq FoldFixture.Count"
                      if family == "supplied" else "Nat → Nat")
            cases.append(dict(engine=engine, family=family, operation="reject_all", name=name,
                              type=target, predicate="False", expected="no_candidate", required_providers=[],
                              command=f":synth {name} : {target} where False"))
    return cases


def provider_inventory(transcript, case):
    """Retain each exact debug row; a fresh process prevents cache ambiguity."""
    rows = []
    for line in transcript.splitlines():
        if not line.startswith("debug provider: "):
            continue
        match = re.search(r'\bproviderLeanName = ("(?:[^"\\]|\\.)*")', line)
        if match is None:
            raise ValueError("provider debug row has no exact source name: " + line)
        rows.append(dict(name=json.loads(match.group(1)), declaration=line.removeprefix("debug provider: ")))
    names = [row["name"] for row in rows]
    if len(names) != len(set(names)):
        raise ValueError("a fresh single-query process emitted duplicate provider identities")
    if case["family"] == "native":
        if rows:
            raise ValueError("providers-off native query discovered a named provider")
    else:
        unexpected = sorted(set(names) - ALLOWED_PROVIDERS)
        if unexpected:
            raise ValueError("unreviewed provider names in the supplied-fold inventory: " + ", ".join(unexpected))
        missing = sorted(set(case["required_providers"]) - set(names))
        if missing:
            raise ValueError("required generic fold was not discovered: " + ", ".join(missing))
    return rows


def validate_candidate(result, case):
    if result["status"] != "candidate":
        return
    term = result["candidate"]
    if FORBIDDEN_IMPLEMENTATION.search(term) or case["name"] in term:
        raise ValueError("target, reference, or unchecked implementation appeared in the candidate")
    for provider in case["required_providers"]:
        if not re.search(r"(?<![\w.])" + re.escape(provider) + r"(?![\w.])", term):
            raise ValueError("accepted output does not use its supplied generic fold: " + provider)
    if case["family"] == "native" and re.search(r"\b(?:FoldFixture\.|List\.fold)", term):
        raise ValueError("native output acquired a named fold instead of using its supplied argument")


def kernel_source(case, result, inventory):
    name = "FoldReplay.accepted"
    proof = name + "_passes"
    supplied = case["family"] == "supplied"
    providers = sorted(set(FOLD_DEFINITIONS) | {row["name"] for row in inventory}) if supplied else ["List.foldr"]
    lines = ["set_option autoImplicit false", *(PRELUDE if supplied else []),
             f"def {name} : {case['type']} :=", result["candidate"],
             f"theorem {proof} : {case['predicate'].format(f=name)} := by decide"]
    names = [*providers, name, proof]
    lines.extend(f"#print axioms {declaration}" for declaration in names)
    return "\n".join([*lines, ""]), names


def kernel_check(processes, label, path, names, args):
    source_hash = runtime.sha256(path)
    checked = processes.run(label, [args.lean, "+" + args.toolchain, path.resolve()], cwd=ROOT)
    inventories = {name: reported_axioms(checked.stdout + checked.stderr, name) for name in names}
    unchanged = file_unchanged(path, source_hash)
    passed = checked.returncode == 0 and unchanged and all(value == set() for value in inventories.values())
    return dict(source_path=str(path.resolve()), source_sha256=source_hash, source_unchanged=unchanged,
                status="passed" if passed else "failed",
                axiom_inventories={name: None if value is None else sorted(value)
                                  for name, value in inventories.items()})


def file_unchanged(path, digest):
    try:
        return runtime.sha256(path) == digest
    except OSError:
        return False


def source_paths():
    return [
        Path(__file__).resolve(), ROOT / "test-church/behavior_probe.py",
        ROOT / "test-church/run_corpus.py", ROOT / "lib/Djex/test-church/behavior_runtime.py",
        ROOT / "src/Main.hs", ROOT / "src/Leant/Synth/Engine.hs",
        ROOT / "src/Leant/Synth/Fragment.hs", ROOT / "src/Leant/Synth/Render.hs",
        ROOT / "src/Leant/Synth/Behavioral.hs",
        ROOT / "lib/Djex/djinn/src-core/Djinn/Core.hs",
        ROOT / "lib/Djex/djinn/src-core/Djinn/Internal/Environment.hs",
        ROOT / "lib/Djex/djinn/src-core/Djinn/Internal/TypeFormula.hs",
        ROOT / "lib/Djex/djinn/src-internal/Djinn/Internal/Instantiation.hs",
        ROOT / "lib/Djex/djinn/src-core/Djinn/Internal/LJT.hs",
        ROOT / "lib/Djex/exference/src-core/Language/Haskell/Exference/Core/Internal/Exference.hs",
        ROOT / "lib/Djex/exference/src-core/Language/Haskell/Exference/Core/Internal/ExpressionCheck.hs",
    ]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--leant", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--engine", action="append", choices=("djinn", "exference", "both"))
    parser.add_argument("--family", action="append", choices=tuple(FAMILIES))
    parser.add_argument("--operation", action="append", choices=OPERATIONS)
    parser.add_argument("--window", type=int, default=1024)
    parser.add_argument("--steps", type=int, default=100000)
    parser.add_argument("--budget", type=int, default=100000)
    parser.add_argument("--provider-cap", type=int, default=80)
    parser.add_argument("--timeout", type=int, default=90)
    parser.add_argument("--process-timeout", type=float, default=180)
    parser.add_argument("--lean", default="lean")
    parser.add_argument("--toolchain", default="leanprover/lean4:v4.32.0")
    parser.add_argument("--prepare-only", action="store_true")
    args = parser.parse_args()
    runtime.validate_limits(args)
    if args.timeout <= 0 or args.provider_cap <= 0 or (not args.prepare_only and args.leant is None):
        parser.error("positive timeout/provider cap and --leant are required for execution")
    engines = args.engine or ["djinn", "exference", "both"]
    families = args.family or list(FAMILIES)
    available = {case["operation"] for family in families for case in FAMILIES[family]}
    operations = args.operation or sorted(available)
    for label, values in (("engine", engines), ("family", families), ("operation", operations)):
        if len(values) != len(set(values)):
            parser.error(label + " selections must be unique")
    if set(operations) - available:
        parser.error("an operation is not available in the selected families")
    for family in families:
        if not any(case["operation"] in operations for case in FAMILIES[family]):
            parser.error("each selected family must contain an actual operation")

    cases = prepare(engines, families, operations)
    output = runtime.prepare_output_directory(args.output)
    for case in cases:
        path = output / (case["name"] + ".commands.txt")
        path.write_text(command_source(case, args), encoding="utf-8")
        case.update(commands_path=str(path.resolve()), commands_sha256=runtime.sha256(path))
    definition_checks = {}
    for family in families:
        names = list(FOLD_DEFINITIONS) if family == "supplied" else ["List.foldr"]
        path = output / (family + "-fold-definitions.lean")
        lines = ["set_option autoImplicit false", *(PRELUDE if family == "supplied" else []),
                 *(f"#print axioms {name}" for name in names), ""]
        path.write_text("\n".join(lines), encoding="utf-8")
        definition_checks[family] = dict(status="prepared", declarations=names,
                                        source_path=str(path.resolve()), source_sha256=runtime.sha256(path))
    report = dict(
        status="prepared", runner_sha256=runtime.sha256(__file__), cases=cases,
        selected=dict(engines=engines, families=families, operations=operations),
        settings=dict(window=args.window, steps=args.steps, budget=args.budget,
                      provider_cap=args.provider_cap, timeout=args.timeout,
                      process_timeout=args.process_timeout, strategy="interleave", shown=1,
                      debug=True, library=False, classical=False),
        datatype_declarations=DATATYPES,
        declared_generic_providers=FOLD_DEFINITIONS,
        allowed_discovered_providers=sorted(ALLOWED_PROVIDERS),
        provider_definition_checks=definition_checks,
        scope="finite recursive behavior via supplied terminating folds; exact source/kernel replay; no recursive-call synthesis or universal-law claim",
        source_hashes={str(path.relative_to(ROOT)): runtime.sha256(path) for path in source_paths()},
        results=[],
    )
    receipt = output / "results.json"
    runtime.write_json(receipt, report)
    if args.prepare_only:
        print(f"Prepared {len(cases)} isolated queries; no processes run.")
        return 0

    digest = runtime.sha256(args.leant)
    report.update(status="running", executable=str(args.leant.resolve()), executable_sha256=digest)
    processes = runtime.Processes(output, args.process_timeout)
    try:
        # Establish the providers' own kernel/termination boundary even when
        # search finds no candidate. A failure only disables its own family.
        for family, check in definition_checks.items():
            try:
                path = Path(check["source_path"])
                if runtime.sha256(path) != check["source_sha256"]:
                    raise ValueError("prepared fold definition source changed")
                checked = kernel_check(processes, family + "-fold-definitions",
                                       path, check["declarations"], args)
                check.update(status=checked["status"], kernel_replay=checked)
            except Exception as failure:
                check.update(status="failed", failure=str(failure))
            runtime.write_json(receipt, report)
        for case in cases:
            row = dict(name=case["name"], engine=case["engine"], family=case["family"],
                       operation=case["operation"], status="running")
            report["results"].append(row)
            runtime.write_json(receipt, report)
            try:
                if definition_checks[case["family"]]["status"] != "passed":
                    raise ValueError("the supplied fold definitions failed independent kernel checking")
                source = Path(case["commands_path"]).read_text(encoding="utf-8")
                if runtime.sha256(case["commands_path"]) != case["commands_sha256"]:
                    raise ValueError("prepared query source changed before execution")
                live = processes.run(case["name"] + "-live", [args.leant.resolve(), "--plain"],
                                     source=source, cwd=ROOT,
                                     env=dict(os.environ, LEANT_SYNTH_TIMEOUT=str(args.timeout)))
                transcript = live.stdout + live.stderr
                row["provider_debug_lines"] = [
                    line for line in transcript.splitlines() if line.startswith("debug provider: ")
                ]
                if live.returncode:
                    raise ValueError("live Leant exited unsuccessfully")
                validate_settings(transcript, source)
                inventory = provider_inventory(transcript, case)
                row["provider_inventory"] = inventory
                require_completed_live_query(transcript)
                result = parse_output(transcript, [case])[0]
                row["synthesis"] = result
                validate_candidate(result, case)
                if result["status"] == "candidate":
                    replay, names = kernel_source(case, result, inventory)
                    path = output / (case["name"] + ".lean")
                    path.write_text(replay, encoding="utf-8")
                    row["kernel_replay"] = kernel_check(processes, case["name"] + "-kernel",
                                                         path, names, args)
                    if row["kernel_replay"]["status"] != "passed":
                        raise ValueError("independent candidate/provider kernel replay failed")
                row["status"] = "passed"
            except Exception as failure:
                row.update(status="failed", failure=str(failure))
            runtime.write_json(receipt, report)
        report.update(
            status="passed" if all(row["status"] == "passed" for row in report["results"]) else "failed",
            accepted_candidate_count=sum(row["status"] == "passed" and row["operation"] != "reject_all"
                                         for row in report["results"]),
            false_control_count=sum(row["status"] == "passed" and row["operation"] == "reject_all"
                                    for row in report["results"]),
        )
    finally:
        report["executable_unchanged"] = file_unchanged(args.leant, digest)
        report["sources_unchanged"] = all(file_unchanged(ROOT / path, value)
                                           for path, value in report["source_hashes"].items())
        report["commands_unchanged"] = all(file_unchanged(case["commands_path"], case["commands_sha256"])
                                            for case in cases)
        report["provider_definitions_unchanged"] = all(
            file_unchanged(check["source_path"], check["source_sha256"])
            for check in definition_checks.values())
        if not all(report[field] for field in ("executable_unchanged", "sources_unchanged", "commands_unchanged",
                                               "provider_definitions_unchanged")):
            report.update(status="failed", failure="source, query commands, or executable changed during acceptance")
        if report["status"] == "running":
            report.update(status="interrupted", failure="acceptance did not finish its prepared case inventory")
        report["processes"] = processes.rows
        runtime.write_json(receipt, report)
    print(f"Supplied recursor behavior: {report['status']}; {report.get('accepted_candidate_count', 0)} independently accepted")
    return 0 if report["status"] == "passed" else 1


if __name__ == "__main__":
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, "reconfigure"):
            stream.reconfigure(encoding="utf-8")
    raise SystemExit(main())
