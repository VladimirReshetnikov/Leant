"""Contextual native constructors: actual synthesis, False controls and exact replay.

Constructor declarations and method packets must come from the live Lean
serializer. Reference definitions enter only separate kernel preflight files.
The original six diagnostic cases retain their 32/20000/45 limits.
"""
from pathlib import Path
import argparse
import importlib.util
import json
import os
import re
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
spec = importlib.util.spec_from_file_location("constructor_result_parser", HERE / "run_production.py")
parser = importlib.util.module_from_spec(spec)
spec.loader.exec_module(parser)
runtime = parser.runtime
sys.path.insert(0, str(ROOT / "test-church"))
import behavior_partial_probe as pins

PRELUDE = "set_option autoImplicit false\nclass Ctx.C (α : Type) where out : Nat\n"


def specifications():
    method_type = "∀ (α : Type), [Ctx.C α] → List Nat"
    argument_type = "∀ (α β : Type), [Ctx.C α] → β → List β"
    method_checks = "(@F Nat (@Ctx.C.mk Nat 7) = [7]) ∧ (@F Nat (@Ctx.C.mk Nat 11) = [11])"
    argument_checks = "(@F Nat Nat (@Ctx.C.mk Nat 7) 37 = [37]) ∧ (@F Nat Bool (@Ctx.C.mk Nat 11) true = [true])"
    return [
        ("method", method_type, method_checks,
         "fun (α : Type) [d : Ctx.C α] => [@Ctx.C.out α d]", True),
        ("argument", argument_type, argument_checks,
         "fun (α β : Type) [d : Ctx.C α] (x : β) => [x]", False),
        ("method_tail", "∀ (α : Type), [Ctx.C α] → List Nat → List Nat",
         "(@F Nat (@Ctx.C.mk Nat 7) [3, 5] = [7, 3, 5]) ∧ (@F Nat (@Ctx.C.mk Nat 11) [] = [11])",
         "fun (α : Type) [d : Ctx.C α] (xs : List Nat) => @Ctx.C.out α d :: xs", True),
        ("argument_tail", "∀ (α β : Type), [Ctx.C α] → β → List β → List β",
         "(@F Nat Nat (@Ctx.C.mk Nat 7) 37 [3, 5] = [37, 3, 5]) ∧ (@F Nat Bool (@Ctx.C.mk Nat 11) true [false] = [true, false])",
         "fun (α β : Type) [d : Ctx.C α] (x : β) (xs : List β) => x :: xs", False),
        ("wrapper", "∀ (α β : Type), [Ctx.C α] → β → Option (List β)",
         "(@F Nat Nat (@Ctx.C.mk Nat 7) 37 = some [37]) ∧ (@F Nat Bool (@Ctx.C.mk Nat 11) true = some [true])",
         "fun (α β : Type) [d : Ctx.C α] (x : β) => some [x]", False),
        ("nested_list", "∀ (α β : Type), [Ctx.C α] → β → List (List β)",
         "(@F Nat Nat (@Ctx.C.mk Nat 7) 37 = [[37]]) ∧ (@F Nat Bool (@Ctx.C.mk Nat 11) true = [[true]])",
         "fun (α β : Type) [d : Ctx.C α] (x : β) => [[x]]", False),
        ("nested_context", "∀ (α : Type), [Ctx.C α] → ∀ (β : Type), [Ctx.C β] → List Nat",
         "(@F Nat (@Ctx.C.mk Nat 7) Bool (@Ctx.C.mk Bool 11) = [7]) ∧ (@F Nat (@Ctx.C.mk Nat 11) Bool (@Ctx.C.mk Bool 7) = [11])",
         "fun (α : Type) [d : Ctx.C α] (β : Type) [e : Ctx.C β] => [@Ctx.C.out α d]", True),
    ]


def cases(engines, operations):
    result = []
    for engine in engines:
        for operation, ty, predicate, reference, providers in specifications():
            if operations and operation not in operations:
                continue
            for negative in ([False, True] if operation in ("method", "argument") else [False]):
                name = f"construct_{engine}_{operation}" + ("_false" if negative else "")
                assertion = "False" if negative else predicate.replace("@F", "@" + name)
                command = f":synth {name} : {ty} where {assertion}"
                result.append(dict(name=name, engine=engine, operation=operation, type=ty,
                                   predicate=assertion, positive_predicate=predicate, reference=reference,
                                   providers=providers, mode="where", command=command,
                                   expected="no_candidate" if negative else "candidate"))
    return result


def command_source(case):
    return "\n".join([
        ":set synth-library off", ":set synth-classical off",
        ":set synth-providers " + ("on" if case["providers"] else "off"),
        ":set synth-provider-cap 1", ":set synth-debug on", ":set synth-ranking balanced",
        ":set synth-shown 1", ":set synth-djinn-strategy interleave", ":set synth-window 32",
        ":set synth-verify 32", ":set synth-steps 20000", ":set synth-budget 20000",
        ":set synth-timeout 45", "class Ctx.C (α : Type) where out : Nat",
        ":set synth-engine " + case["engine"], case["command"], ":quit", ""])


def graph_observation(block, case, term):
    rows = re.findall(r"(?m)^debug accepted-candidate: (.*)$", block)
    if len(rows) != 1:
        raise ValueError("no unique accepted source graph observation")
    observed = json.loads(rows[0])
    origin = observed.get("origin") or {}
    graph = origin.get("graph") or {}
    rendering = origin.get("rendering") or {}
    if (observed.get("term") != term or observed.get("route") != "RouteTypedCandidate"
            or rendering.get("term") != term or rendering.get("matches_verified_text") is not True
            or graph.get("root_closed") is not True or graph.get("erasure_matches_compatibility") is not True
            or "failure" in graph or "failure" in rendering or not graph.get("globals")):
        raise ValueError("constructor output lost its exact typed source authority")
    engine = origin.get("engine")
    if engine not in ("djinn", "exference") or (case["engine"] != "both" and engine != case["engine"]):
        raise ValueError("constructor acquired another engine's authority")
    owned = set()
    for intro in graph.get("context_introductions", []):
        for slot, binder in enumerate(intro.get("binders", [])):
            if binder != dict(introduction=intro.get("occurrence"), slot=slot):
                raise ValueError("context introduction changed its ordered source identity")
            identity = (binder["introduction"], binder["slot"])
            if identity in owned:
                raise ValueError("duplicate dictionary owner")
            owned.add(identity)
    if not owned:
        raise ValueError("constructor erased the source dictionary telescope")
    applications = graph.get("context_applications", [])
    if case["providers"] and not applications:
        raise ValueError("method construction lost its actual dictionary application")
    for application in applications:
        evidence = application.get("evidence", [])
        if not evidence or any((e.get("introduction"), e.get("slot")) not in owned for e in evidence):
            raise ValueError("constructor composition acquired unowned dictionary evidence")
    return observed


def validate(output, source, case):
    parser.validate_settings(output, source)
    block = parser.query_block(output, case)
    if "FExactContext" not in block or "provider inventory unavailable:" in output:
        raise ValueError("live constructor source admission or provider discovery failed")
    inventory = []
    for line in output.splitlines():
        if line.startswith("debug provider: "):
            match = re.search(r'\bproviderLeanName = ("(?:[^"\\]|\\.)*")', line)
            if match is None or "ProviderFragWithContextSource" not in line:
                raise ValueError("discovered provider lacks complete source metadata")
            inventory.append(json.loads(match[1]))
    if inventory != (["Ctx.C.out"] if case["providers"] else []):
        raise ValueError("unexpected discovered provider inventory: " + repr(inventory))
    result = parser.candidate_result(block, case)
    result["provider_inventory"] = inventory
    if result["status"] == "candidate":
        term = result["candidate"]
        plain = term.replace("«", "").replace("»", "")
        if (re.search(r"\bsorry\b|\bunsafe\b|Classical|Ctx\.C\.mk|ConstructorOracle", plain)
                or case["name"] in term or "@_root_.List.cons.{0}" not in plain
                or (case["providers"] and "@_root_.Ctx.C.out" not in plain)):
            raise ValueError("candidate lost actual constructor/method evidence or acquired an oracle")
        result["accepted_variant"] = graph_observation(block, case, term)
    return result


def kernel_source(case, term, namespace, predicate):
    names = [namespace + ".implementation", namespace + ".passes"]
    text = (PRELUDE + f"def {names[0]} : {case['type']} :=\n{term}\n"
            + f"theorem {names[1]} : {predicate} := by decide\n"
            + "\n".join("#print axioms " + n for n in names) + "\n")
    return text, names


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--output", type=Path, required=True)
    ap.add_argument("--leant", type=Path, required=True)
    ap.add_argument("--lean-runtime", type=Path, default=parser.default_lean_runtime())
    ap.add_argument("--backend", type=Path)
    ap.add_argument("--engine", action="append", choices=["djinn", "exference", "both"])
    ap.add_argument("--operation", action="append", choices=[row[0] for row in specifications()])
    args = ap.parse_args()
    output = runtime.prepare_output_directory(args.output.resolve())
    selected = cases(args.engine or ["djinn", "exference", "both"], args.operation)
    report = dict(status="preparing", scope=__doc__, cases=selected, results=[], source_hashes={})
    args.lean, args.toolchain = str(args.lean_runtime), ""
    executable, backend, lake, identities = pins.runtime_identity(args, runtime, report)
    kernel = parser.pin_kernel(args.lean_runtime)
    inputs = set(parser.source_inventory()) | {Path(__file__).resolve(), Path(parser.__file__),
        Path(pins.__file__), Path(executable), Path(kernel["path"]),
        *(Path(p) for p in identities), *(Path(p) for p in report["source_hashes"])}
    prepared = {}
    for case in selected:
        command = parser.saved_source(output, case["name"] + ".commands.txt", command_source(case))
        oracle_predicate = case["positive_predicate"].replace("@F", "@ConstructorOracle.implementation")
        text, names = kernel_source(case, case["reference"], "ConstructorOracle", oracle_predicate)
        oracle = parser.saved_source(output, case["name"] + "-oracle.lean", text, names)
        prepared[case["name"]] = (command, oracle)
        inputs.update([Path(command["path"]), Path(oracle["path"])])
    before = {str(path): runtime.sha256(path) for path in sorted(inputs)}
    processes = runtime.Processes(output, 180)
    environment = dict(os.environ, LEANT_BACKEND=str(backend), leant_datadir=str(ROOT), djex_datadir=str(ROOT / "lib/Djex"))
    for key in ("LEANT_BACKEND_TRACE", "LEANT_BACKEND_TRACE_REQUESTS", "LEANT_BACKEND_TRACE_REQUEST_LIMIT"):
        environment.pop(key, None)
    report.update(status="running", source_and_input_hashes_before=before, runtime_identities=identities, kernel=kernel)
    replays = []
    try:
        for case in selected:
            command, oracle = prepared[case["name"]]
            result = dict(name=case["name"], status="running")
            report["results"].append(result)
            runtime.write_json(output / "results.json", report)
            try:
                checked = parser.kernel_check(processes, case["name"] + "-oracle", oracle, kernel)
                if checked["status"] != "passed":
                    raise ValueError("constructor positive oracle failed")
                result["oracle"] = checked
                source = Path(command["path"]).read_text(encoding="utf-8")
                live = processes.run(case["name"] + "-live", [str(executable), "--plain", "--lake", str(lake)],
                                     source=source, cwd=ROOT, env=environment)
                if live.returncode != 0 or Path(processes.rows[-1]["input_path"]).read_text(encoding="utf-8") != source:
                    raise ValueError("constructor live process or captured input failed")
                result.update(validate(live.stdout, source, case))
                if result["status"] == "candidate":
                    text, names = kernel_source(case, result["candidate"], "ConstructorReplay",
                        case["predicate"].replace(case["name"], "ConstructorReplay.implementation"))
                    replay = parser.saved_source(output, case["name"] + "-replay.lean", text, names)
                    replays.append(replay)
                    result["replay"] = parser.kernel_check(processes, case["name"] + "-replay", replay, kernel)
                    if result["replay"]["status"] != "passed":
                        raise ValueError("exact displayed constructor failed full-type/behavior replay")
            except Exception as failure:
                result.update(status="failed", failure=repr(failure))
            runtime.write_json(output / "results.json", report)
            print(json.dumps(dict(name=case["name"], status=result["status"])), flush=True)
        report["status"] = "passed" if all(r["status"] in ("candidate", "no_candidate") for r in report["results"]) else "failed"
    except BaseException as failure:
        report.update(status="failed", failure=repr(failure))
    finally:
        after = {str(path): runtime.sha256(path) if path.is_file() else None for path in sorted(inputs)}
        stable = all(parser.unchanged(r["path"], r["sha256"]) for r in replays)
        report.update(source_and_input_hashes_after=after, source_and_input_hashes_unchanged=before == after,
                      exact_replay_sources_unchanged=stable, processes=processes.rows)
        if before != after or not stable:
            report.update(status="failed", integrity_failure="frozen inputs or exact replay changed")
        runtime.write_json(output / "results.json", report)
    return 0 if report["status"] == "passed" else 1


if __name__ == "__main__":
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, "reconfigure"):
            stream.reconfigure(encoding="utf-8")
    raise SystemExit(main())
