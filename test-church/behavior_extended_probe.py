#!/usr/bin/env python3
"""Probe the opt-in extended Church specification in isolated Lean sessions.

Every selected engine/operation and every false-oracle control gets a fresh
Leant process. Observation declarations are never synthesis providers. Length
retains the two specified numeric definitions, inline observation and two-entry
discovery cap. Acceptance records either the exact discovered inventory or the
exact native Int/Nat constructor baseline, and requires independent direct
implementation-constant checking in addition to full-type/oracle/axiom replay.

Displayed candidates are replayed unchanged under their complete source type,
then checked against the specification's original oracle. All oracle controls,
actual axiom inventories, captures, failures and source hashes are retained.
--prepare-only writes inputs and metadata without starting any child process.
"""
from __future__ import annotations

import argparse
import ast
import hashlib
import importlib
import json
import os
from pathlib import Path
import re
import shutil
import sys

from behavior_probe import parse_output
from run_corpus import reported_axioms, validate_settings

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
ENGINES = ("djinn", "exference", "both")
NUMERIC_NAMES = ("BehaviorExtendedNumeric.zero", "BehaviorExtendedNumeric.successor")
# Lean 4.32's derived Sum.instBEq depends on propext. Only proofs which
# reference this exact oracle inherit it; candidate implementations still
# require an empty inventory. Keep this explicit rather than allowing every
# standard axiom for every declaration.
MAYBE_EITHER_CONTROL_PROOFS = frozenset({
    "BehaviorExtendedControl.witness_maybeEither_passes",
    "BehaviorExtendedControl.wrong_maybeEither_nothing_rejected",
})
PRODUCT_SOURCES = (
    "src/Main.hs", "src/Leant/Backend.hs", "src/Leant/Synth/Behavioral.hs", "src/Leant/Synth/Engine.hs",
    "src/Leant/Synth/Fragment.hs", "src/Leant/Synth/Render.hs",
    "src/Leant/Synth/CandidateObservation.hs",
)


def write_source(runtime, path, source):
    path.write_text(source, encoding="utf-8")
    return {"path": str(path.resolve()), "sha256": runtime.sha256(path),
            "canonical_lf_sha256": hashlib.sha256(source.encode("utf-8")).hexdigest()}


def length_inputs(spec):
    """Read the Boolean fixture from the exact prelude; do not add examples."""
    matches = [re.fullmatch(r"def BehaviorExtended\.boolInputs : List \(List Bool\) := (.+)", line)
               for line in spec.lean_prelude()]
    literals = [match.group(1) for match in matches if match]
    if len(literals) != 1:
        raise ValueError("cannot recover the exact Boolean length observation inventory")
    bools = ast.literal_eval(re.sub(r"\b(false|true)\b",
                                   lambda match: match.group(1).title(), literals[0]))
    ints = spec.INPUTS
    if (not isinstance(ints, list) or not isinstance(bools, list)
            or any(not isinstance(xs, list) or any(type(x) is not int for x in xs) for xs in ints)
            or any(not isinstance(xs, list) or any(type(x) is not bool for x in xs) for xs in bools)
            or len(ints) + len(bools) != spec.OBSERVATIONS["length"]):
        raise ValueError("length observation values or count differ from the specification")
    return [("Int", xs) for xs in ints] + [("Bool", xs) for xs in bools]


def length_predicate(spec, candidate):
    assertions = []
    for element_type, values in length_inputs(spec):
        body = "zero"
        for value in reversed(values):
            literal = ("true" if value else "false") if type(value) is bool else f"({value})"
            body = f"step {literal} ({body})"
        encoded = "(fun _ step zero => " + body + ")"
        assertions.append(f"{candidate} {element_type} {encoded} = ({len(values)} : Int)")
    return " ∧ ".join("(" + assertion + ")" for assertion in assertions)


def numeric_declarations(spec):
    inventory = spec.search_provider_inventory("length")["lean"]
    if [row["name"] for row in inventory] != list(NUMERIC_NAMES):
        raise ValueError("numeric provider specification changed; review the discovery gate")
    if [(row["type"], row["definition"]) for row in inventory] != [
            ("Int", "0"), ("Int → Int", "fun n => n + 1")]:
        raise ValueError("length providers are no longer the approved generic arithmetic primitives")
    # Establish only a namespace, not an additional declaration/provider. Keep
    # the specification's definitions and their exact fully qualified names.
    return ["namespace BehaviorExtendedNumeric", "end BehaviorExtendedNumeric",
            *spec.LEAN_NUMERIC_PROVIDERS]


def cell_commands(spec, engine, operation, args):
    false_control = operation == "reject_all"
    numeric = operation == "length"
    name = f"extended_{engine}_{operation}"
    target = "Nat → Nat" if false_control else spec.LEAN_TYPES[operation]
    predicate = ("False" if false_control else length_predicate(spec, name) if numeric
                 else spec.lean_predicate(operation, name))
    declarations = ([] if false_control else numeric_declarations(spec) if numeric
                    else list(spec.lean_prelude()))
    if not false_control and not numeric and spec.search_provider_inventory(operation)["lean"]:
        raise ValueError("unexpected provider requirement for " + operation)
    lines = [":set synth-library off", ":set synth-classical off",
             ":set synth-providers " + ("on" if numeric else "off"),
             ":set synth-debug on", ":set synth-ranking balanced", ":set synth-shown 1",
             f":set synth-djinn-strategy {args.djinn_strategy}",
             f":set synth-window {args.window}", f":set synth-verify {args.window}",
             f":set synth-steps {args.steps}", f":set synth-budget {args.budget}",
             f":set synth-timeout {args.timeout}", ":set synth-engine " + engine]
    if numeric:
        lines.append(":set synth-provider-cap 2")
    command = f":synth {name} : {target} where {predicate}"
    source = "\n".join([*lines, *declarations, command, ":quit", ""])
    case = {"engine": engine, "operation": operation, "name": name, "type": target,
            "command": command, "expected": "no_candidate" if false_control else "candidate",
            "finite_observation_count": 0 if false_control else spec.OBSERVATIONS[operation],
            "required_provider_names": list(NUMERIC_NAMES) if numeric else [],
            "provider_policy": "native constructor baseline or exact observed capped numeric inventory" if numeric else "discovery off",
            "session_isolation": "one synthesis query in one fresh process", "status": "prepared"}
    return source, case


def actual_provider_inventory(output, case):
    lines = re.findall(r"(?m)^debug provider: (.+)$", output)
    names = []
    malformed = []
    for line in lines:
        matches = re.findall(r'providerLeanName = "([^"\\]+)"', line)
        if len(matches) != 1:
            malformed.append(line)
        else:
            names.append(matches[0])
    required = case["required_provider_names"]
    # With two exact session/result-head matches the product's documented
    # shortest-name ordering emits zero before successor. Check count, order
    # and identity, not merely membership or the candidate's eventual globals.
    return {"ordered_names": names, "count": len(names), "entries": lines,
            "malformed_entries": malformed,
            "required_ordered_names": required,
            "exact_inventory_verified": names == required and not malformed
                and "provider inventory unavailable:" not in output}


# This fixture has one exact translated native family inventory. It is checked
# before using the constructor route; no provider is inferred from output text.
NATIVE_LENGTH_FRAGMENT = 'FAll True "s0" (FArr (FAll True "s1" (FArr (FArr (FVar "s0") (FArr (FVar "s1") (FVar "s1"))) (FArr (FVar "s1") (FVar "s1")))) (FParamInd "Int" "Int" [] [("Int.ofNat",[FParamRec True "Nat" "Nat" [] [("Nat.zero",[]),("Nat.succ",[FAtom False "Nat"])]]),("Int.negSucc",[FParamRec True "Nat" "Nat" [] [("Nat.zero",[]),("Nat.succ",[FAtom False "Nat"])]])]))'
NATIVE_LENGTH_GRAPH_GLOBALS = frozenset({
    "LeantFamilyC0_0", "LeantFamilyC0_1", "LeantRecC1_0", "LeantRecC1_1",
})
NATIVE_LENGTH_CONSTANTS = frozenset({"Int", "Nat", "Int.ofNat", "Nat.zero", "Nat.succ"})
IMPLEMENTATION_MARKER = "BEHAVIOR_IMPLEMENTATION_CONSTANTS "


def length_source_route(output, case, result, inventory):
    """Classify actual observed source scope; kernel replay is still required."""
    if case["operation"] != "length":
        if not inventory["exact_inventory_verified"]:
            raise ValueError("actual provider inventory differs from its exact ordered requirement")
        return None
    if inventory["exact_inventory_verified"]:
        return {"route": "exact_numeric_provider_inventory",
                "allowed_value_constants": sorted(NATIVE_LENGTH_CONSTANTS | set(NUMERIC_NAMES)),
                "required_type_constants": ["Int"]}
    if (inventory["entries"] or inventory["malformed_entries"]
            or "provider inventory unavailable:" in output
            or re.search(r"(?m)^debug premise:", output)):
        raise ValueError("numeric provider discovery was observed but did not match the exact inventory")
    fragments = re.findall(r"(?m)^debug fragment: (.+)$", output)
    if fragments != [NATIVE_LENGTH_FRAGMENT]:
        raise ValueError("native length scope lacks its exact Int/Nat constructor inventory")
    raw = re.findall(r"(?m)^debug accepted-candidate: (.+)$", output)
    if len(raw) != 1 or result["status"] != "candidate":
        raise ValueError("native length requires one retained accepted source observation")
    observation = json.loads(raw[0])
    origin = observation.get("origin") or {}
    rendering = origin.get("rendering") or {}
    graph = origin.get("graph") or {}
    globals_ = graph.get("globals")
    expected_engines = {case["engine"]} if case["engine"] != "both" else {"djinn", "exference"}
    if (observation.get("schema") != 1 or observation.get("label") != "it1"
            or observation.get("term") != result["candidate"]
            or observation.get("route") != "RouteTypedCandidate"
            or origin.get("engine") not in expected_engines
            or rendering.get("term") != result["candidate"]
            or rendering.get("matches_verified_text") is not True
            or graph.get("erasure_matches_compatibility") is not True
            or not isinstance(globals_, list) or not globals_
            or any(not isinstance(name, str) for name in globals_)
            or not set(globals_) <= NATIVE_LENGTH_GRAPH_GLOBALS
            or graph.get("context_introductions") != []
            or graph.get("context_applications") != []):
        raise ValueError("native length output lost its exact constructor-owned source origin")
    return {"route": "native_constructor_baseline",
            "provider_discovery_observed": False,
            "fragment_sha256": hashlib.sha256(fragments[0].encode("utf-8")).hexdigest(),
            "accepted_observation_sha256": hashlib.sha256(raw[0].encode("utf-8")).hexdigest(),
            "graph_globals": globals_,
            "allowed_value_constants": sorted(NATIVE_LENGTH_CONSTANTS),
            "required_type_constants": ["Int"]}


def implementation_inventory_source():
    # Replay-only metaprogram. Its declarations never enter the live synthesis
    # input or the implementation's expression. Inspect direct dependencies,
    # including binder types, without unfolding a possible oracle helper away.
    return '''run_cmd do
  let info ← Lean.getConstInfo `BehaviorExtendedReplay.candidate
  let some value := info.value? | throwError "candidate has no inspectable implementation"
  let record := Lean.Json.mkObj [
    ("declaration", Lean.toJson "BehaviorExtendedReplay.candidate"),
    ("type_constants", Lean.toJson (info.type.getUsedConstants.map Lean.Name.toString)),
    ("value_constants", Lean.toJson (value.getUsedConstants.map Lean.Name.toString))]
  Lean.logInfo ("BEHAVIOR_IMPLEMENTATION_CONSTANTS " ++ record.compress)'''


def check_implementation_inventory(output, policy):
    records = re.findall(re.escape(IMPLEMENTATION_MARKER) + r"([^\r\n]+)", output)
    if len(records) != 1:
        raise ValueError("missing or duplicate exact implementation-constant inventory")
    record = json.loads(records[0])
    if (set(record) != {"declaration", "type_constants", "value_constants"}
            or record["declaration"] != "BehaviorExtendedReplay.candidate"):
        raise ValueError("implementation-constant inventory belongs to another declaration")
    for key in ("type_constants", "value_constants"):
        values = record[key]
        if (not isinstance(values, list) or any(not isinstance(name, str) for name in values)
                or len(values) != len(set(values))):
            raise ValueError("malformed implementation-constant inventory")
    if (set(record["type_constants"]) != set(policy["required_type_constants"])
            or not set(record["value_constants"]) <= set(policy["allowed_value_constants"])):
        raise ValueError("candidate implementation uses a constant outside its observed source route")
    return {**record, "type_constants": sorted(record["type_constants"]),
            "value_constants": sorted(record["value_constants"]), "route": policy["route"]}


def check_displayed_source(result):
    term = result["candidate"]
    if re.search(r"\b(?:sorry|admit|unsafe|axiom|native_decide)\b", term):
        raise ValueError("unchecked construct appeared in the displayed candidate")
    if re.search(r"\bBehaviorExtended(?:Control|Replay)?\.", term):
        raise ValueError("an observation or control declaration appeared as a provider")
    if re.search(r"\bextended_(?:djinn|exference|both)_\w+\b", term):
        raise ValueError("a target or prior accepted definition appeared in the candidate")
    names = re.findall(r"\bBehaviorExtendedNumeric\.([A-Za-z_][A-Za-z_0-9']*)", term)
    allowed = {name.rsplit(".", 1)[1] for name in result["required_provider_names"]}
    if any(name not in allowed for name in names):
        raise ValueError("a numeric fixture outside this cell's inventory appeared in the candidate")


def candidate_replay(spec, result):
    name = "BehaviorExtendedReplay.candidate"
    proof = name + "_passes_original_oracle"
    lines = ["import Lean", *spec.lean_prelude()] if result["operation"] == "length" else list(spec.lean_prelude())
    names = []
    if result["operation"] == "length":
        lines += numeric_declarations(spec)
        names += list(NUMERIC_NAMES)
    lines += ["namespace BehaviorExtendedReplay", "end BehaviorExtendedReplay",
              "set_option autoImplicit false", f"def {name} : {result['type']} :=",
              "\n".join("  " + line for line in result["candidate"].splitlines()),
              f"theorem {proof} : {spec.lean_predicate(result['operation'], name)} := by decide"]
    names += [name, proof]
    if result["operation"] == "length":
        inline = name + "_passes_inline_oracle"
        lines += [f"theorem {inline} : {length_predicate(spec, name)} := by decide"]
        names.append(inline)
        lines.append(implementation_inventory_source())
    lines += [f"#print axioms {declaration}" for declaration in names]
    return "\n".join(lines) + "\n", names


def expected_oracle_control_axioms(names):
    return {name: (["propext"] if name in MAYBE_EITHER_CONTROL_PROOFS else [])
            for name in names}


def expected_candidate_replay_axioms(operation, names):
    proof = "BehaviorExtendedReplay.candidate_passes_original_oracle"
    return {name: (["propext"] if operation == "maybeEither" and name == proof else [])
            for name in names}


def exact_axiom_inventories(names, declared, inventories, expected):
    return (len(names) == len(set(names)) and sorted(declared) == sorted(names)
            and set(inventories) == set(names) and set(expected) == set(names)
            and all(inventories[name] == set(expected[name]) for name in names))


def unchanged(runtime, hashes):
    try:
        return bool(hashes) and all(Path(path).is_file() and runtime.sha256(path) == digest
                                    for path, digest in hashes.items())
    except OSError:
        return False

def resolve_executable(value, label):
    found = shutil.which(str(value))
    path = Path(found if found is not None else value).resolve()
    if not path.is_file():
        raise ValueError(label + " executable was not found: " + str(value))
    return path

def toolchain_binary(toolchain, executable):
    elan = Path(os.environ.get("ELAN_HOME", str(Path.home() / ".elan")))
    directory = toolchain.replace("/", "--").replace(":", "---")
    suffix = ".exe" if os.name == "nt" else ""
    path = elan / "toolchains" / directory / "bin" / (executable + suffix)
    if not path.is_file():
        raise ValueError("cannot pin the actual " + executable + " binary for toolchain " + toolchain
                         + "; select an installed toolchain or supply --lean-runtime for a direct kernel executable")
    return path.resolve()

def resolve_backend(explicit):
    selected = explicit or os.environ.get("LEANT_BACKEND")
    if selected:
        return resolve_executable(selected, "Lean REPL backend")
    # Same source-derived discovery order as Backend.discoverReplExe. Pin the
    # chosen file in LEANT_BACKEND so it cannot change between query sessions.
    appdata = os.environ.get("LOCALAPPDATA")
    candidates = [] if not appdata else list(
        (Path(appdata) / "Python").glob(
            "*/Lib/site-packages/lean_interact/cache/*/repl/*/.lake/build/bin/repl.exe"))
    candidates = sorted((str(path) for path in candidates if path.is_file()), reverse=True)
    if not candidates:
        raise ValueError("cannot pin the Lean REPL backend; use --backend or LEANT_BACKEND")
    return Path(candidates[0]).resolve()

def runtime_identity(args, runtime, report):
    leant = resolve_executable(args.leant, "Leant")
    launcher = resolve_executable(args.lean, "kernel Lean")
    kernel = (resolve_executable(args.lean_runtime, "actual kernel Lean") if args.lean_runtime else
              toolchain_binary(args.toolchain, "lean") if args.toolchain else launcher)
    backend = resolve_backend(args.backend)
    project = next((parent for parent in backend.parents
                    if (parent / "lakefile.lean").is_file() or (parent / "lakefile.toml").is_file()), None)
    if project is None or not (project / "lean-toolchain").is_file():
        raise ValueError("the pinned backend has no identifiable Lake project/toolchain")
    live_toolchain_path = project / "lean-toolchain"
    live_toolchain = live_toolchain_path.read_text(encoding="utf-8").strip()
    live_lean = toolchain_binary(live_toolchain, "lean")
    live_lake = toolchain_binary(live_toolchain, "lake")
    paths = {leant, launcher, kernel, backend, live_lean, live_lake,
             Path(sys.executable).resolve()}
    hashes = {str(path): runtime.sha256(path) for path in sorted(paths, key=str)}
    for path in (live_toolchain_path, project / "lakefile.lean", project / "lakefile.toml",
                 project / "lake-manifest.json"):
        if path.is_file():
            report["source_hashes"][str(path.resolve())] = runtime.sha256(path)
    report["runtime_identity"] = {
        "leant": str(leant), "kernel_launcher": str(launcher), "kernel_runtime": str(kernel),
        "requested_kernel_toolchain": args.toolchain, "backend": str(backend),
        "backend_project": str(project), "backend_toolchain": live_toolchain,
        "backend_lean_runtime": str(live_lean), "backend_lake_runtime": str(live_lake),
        "python": sys.executable,
        "discovery_policy": "filesystem-only resolution; direct kernel binary; explicit backend and direct Lake binary for every live query",
    }
    # The shared kernel helper accepts a direct executable when toolchain is
    # empty. Invoke the exact hashed binary, rather than trusting an elan
    # launcher override to select the requested runtime at execution time.
    args.lean = str(kernel)
    args.toolchain = ""
    return leant, backend, live_lake, hashes


def resolve_kernel(args):
    explicit = getattr(args, "lean_runtime", None)
    if explicit:
        return resolve_executable(explicit, "actual kernel Lean")
    if args.toolchain:
        return toolchain_binary(args.toolchain, "lean")
    return resolve_executable(args.lean, "actual kernel Lean")


def live_invocation(leant, backend, lake, timeout):
    # These explicit selections override ambient discovery for every fresh cell.
    return ([leant, "--plain", "--lake", lake],
            dict(os.environ, LEANT_BACKEND=str(backend), LEANT_SYNTH_TIMEOUT=str(timeout)))


def check_kernel(runtime, processes, args, label, source_row, names, expected_axioms=None, implementation_policy=None):
    expected = ({name: [] for name in names} if expected_axioms is None else expected_axioms)
    row = {"source": source_row, "expected_declarations": names, "status": "running",
           "expected_axiom_inventories": expected,
           "actual_axiom_inventories": {name: None for name in names}}
    kernel_hashes = {}
    try:
        kernel = resolve_kernel(args)
        kernel_hashes = {str(kernel): runtime.sha256(kernel)}
        row["kernel_runtime"] = {"path": str(kernel), "sha256": kernel_hashes[str(kernel)]}
        if not unchanged(runtime, {source_row["path"]: source_row["sha256"]}):
            raise ValueError("exact kernel input is missing or changed before replay")
        # Never ask an elan launcher to resolve the toolchain at execution time.
        checked = processes.run(label, [kernel, source_row["path"]], cwd=ROOT)
        output = checked.stdout + checked.stderr
        inventories = {name: reported_axioms(output, name) for name in names}
        declared = re.findall(r"(?m)^'([^']+)' (?:does not depend on any axioms|depends on axioms:)", output)
        row.update(exit_code=checked.returncode,
                   actual_axiom_inventories={name: None if axioms is None else sorted(axioms)
                                             for name, axioms in inventories.items()},
                   actual_inventory_declarations=declared)
        if (checked.returncode != 0
                or not exact_axiom_inventories(names, declared, inventories, expected)
                or re.search(r"\bdeclaration uses ['‘]sorry['’]", output)):
            raise ValueError("kernel replay or exact per-declaration axiom inventory failed")
        if implementation_policy is not None:
            row["implementation_constants"] = check_implementation_inventory(output, implementation_policy)
        row["status"] = "passed"
    except Exception as failure:
        row.update(status="failed", failure=str(failure))
    finally:
        row["kernel_runtime_unchanged"] = unchanged(runtime, kernel_hashes)
        row["source_unchanged"] = unchanged(runtime, {source_row["path"]: source_row["sha256"]})
        if not row["kernel_runtime_unchanged"] or not row["source_unchanged"]:
            row.update(status="failed", failure=row.get("failure", "kernel runtime or exact input changed during replay"))
    return row


def load_spec(directory):
    directory = directory.resolve()
    sys.path.insert(0, str(directory))
    spec = importlib.import_module("behavior_extended_spec")
    runtime = importlib.import_module("behavior_runtime")
    for name in ("behavior_extended_spec", "behavior_runtime", "behavior_spec"):
        if Path(sys.modules[name].__file__).resolve() != directory / (name + ".py"):
            raise ValueError("specification dependency came from another directory: " + name)
    return spec, runtime


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--leant", type=Path)
    parser.add_argument("--spec-dir", type=Path, default=ROOT / "lib/Djex/test-church")
    parser.add_argument("--output", type=Path, required=True,
                        help="new or empty receipt directory; existing results are never replaced")
    parser.add_argument("--engine", action="append", choices=ENGINES)
    parser.add_argument("--operation", action="append", help="operation in behavior_extended_spec.OPERATIONS")
    parser.add_argument("--window", type=int, default=65536)
    parser.add_argument("--budget", type=int, default=500000)
    parser.add_argument("--steps", type=int, default=100000)
    parser.add_argument("--timeout", type=int, default=90)
    parser.add_argument("--process-timeout", type=float, default=900)
    parser.add_argument("--djinn-strategy", choices=("depth-first", "interleave"), default="interleave")
    parser.add_argument("--lean", default="lean")
    parser.add_argument("--toolchain", default="leanprover/lean4:v4.32.0")
    parser.add_argument("--lean-runtime", type=Path,
                        help="explicit actual kernel binary to invoke and hash instead of toolchain resolution")
    parser.add_argument("--backend", type=Path,
                        help="pin the live Lean REPL; otherwise use existing environment/cache discovery")
    parser.add_argument("--prepare-only", action="store_true")
    args = parser.parse_args()
    spec, runtime = load_spec(args.spec_dir)
    runtime.validate_limits(args)
    if args.timeout <= 0 or (not args.prepare_only and args.leant is None):
        parser.error("positive command timeout and --leant are required for execution")
    engines = args.engine or list(ENGINES)
    operations = args.operation or list(spec.OPERATIONS)
    if (len(set(engines)) != len(engines) or len(set(operations)) != len(operations)
            or any(operation not in spec.OPERATIONS for operation in operations)):
        parser.error("engine/operation selection must be unique and drawn from the specification")
    output = runtime.prepare_output_directory(args.output)
    provenance = spec.source_provenance(args.spec_dir / "manifest.json")
    report = {"status": "prepared", "validation_mode": "prepared_only",
              "engines": engines, "operations": operations, "provenance": provenance,
              "full_corpus_selected": engines == list(ENGINES) and operations == list(spec.OPERATIONS),
              "expected_candidate_count": len(engines) * len(operations),
              "expected_false_control_count": len(engines),
              "settings": {"window": args.window, "verify": args.window, "shown": 1,
                           "ranking": "balanced", "djinn_strategy": args.djinn_strategy,
                           "djinn_choice_budget": args.budget, "exference_steps": args.steps,
                           "command_timeout_seconds": args.timeout,
                           "separate_process_guard_seconds": args.process_timeout},
              "axiom_policy": "candidate implementations and numeric primitives require empty inventories; only the exact named maybeEither oracle/control proofs may use propext",
              "universe_policy": "original full LEAN_TYPES; specification prelude universe binders preserved",
              "scope": "finite behavioral observations; partial cases excluded; no extensional completeness claim",
              "cells": [], "preparation_failures": []}
    tracked = [Path(__file__), HERE / "behavior_probe.py", HERE / "run_corpus.py",
               *[ROOT / path for path in PRODUCT_SOURCES],
               *[args.spec_dir / name for name in
                 ("behavior_extended_spec.py", "behavior_runtime.py", "behavior_spec.py", "manifest.json")],
               Path(provenance["church_source_path"])]
    report["source_hashes"] = {str(path.resolve()): runtime.sha256(path) for path in tracked}
    inputs = {}
    for engine in engines:
        for operation in [*operations, "reject_all"]:
            try:
                source, cell = cell_commands(spec, engine, operation, args)
                inputs[cell["name"]] = source
                cell["input"] = write_source(runtime, output / (cell["name"] + ".txt"), source)
                report["source_hashes"][cell["input"]["path"]] = cell["input"]["sha256"]
            except Exception as failure:
                cell = {"engine": engine, "operation": operation,
                        "name": f"extended_{engine}_{operation}", "status": "preparation_failed",
                        "failure": str(failure)}
                report["preparation_failures"].append(cell["name"])
            report["cells"].append(cell)
    control_lines, control_names = spec.lean_control_source()
    controls_source = "\n".join([*spec.lean_prelude(), *control_lines, ""])
    controls = write_source(runtime, output / "ExtendedOracleControls.lean", controls_source)
    report["source_hashes"][controls["path"]] = controls["sha256"]
    report["oracle_controls"] = {"source": controls, "expected_declarations": control_names,
                                 "expected_axiom_inventories": expected_oracle_control_axioms(control_names),
                                 "status": "prepared", "positive_controls": len(spec.LEAN_WITNESSES),
                                 "fully_typed_wrong_controls": sum(map(len, spec.LEAN_WRONG.values())),
                                 "specialized_adapter_controls": 1}
    if args.leant is not None:
        report["executable"] = {"path": str(args.leant.resolve()), "sha256": runtime.sha256(args.leant)}
    runtime.write_json(output / "results.json", report)
    if args.prepare_only:
        if report["preparation_failures"]:
            report["status"] = "preparation_failed"
            runtime.write_json(output / "results.json", report)
        print(f"{report['status']}: {len(report['cells'])} isolated inputs; no processes run.")
        return 0 if report["status"] == "prepared" else 1
    report.update(status="running", validation_mode="isolated_live_queries_then_exact_kernel_replays")
    processes = runtime.Processes(output, args.process_timeout)
    executable_hashes = {}
    try:
        leant, backend, live_lake, executable_hashes = runtime_identity(args, runtime, report)
        report["executable_hashes"] = executable_hashes
        runtime.write_json(output / "results.json", report)
        report["oracle_controls"].update(check_kernel(runtime, processes, args, "oracle-controls",
                                                      controls, control_names,
                                                      expected_oracle_control_axioms(control_names)))
        runtime.write_json(output / "results.json", report)
        for cell in report["cells"]:
            if cell["status"] == "preparation_failed":
                continue
            cell["status"] = "running"
            runtime.write_json(output / "results.json", report)
            try:
                source = inputs[cell["name"]]
                if not unchanged(runtime, executable_hashes):
                    raise ValueError("a pinned runtime changed before this live cell")
                command, environment = live_invocation(leant, backend, live_lake, args.timeout)
                live = processes.run(cell["name"], command, source=source, cwd=ROOT, env=environment)
                cell["runtime_hashes_unchanged"] = unchanged(runtime, executable_hashes)
                if not cell["runtime_hashes_unchanged"]:
                    raise ValueError("a pinned runtime changed during this live cell")
                transcript = live.stdout + live.stderr
                cell["exit_code"] = live.returncode
                if live.returncode:
                    raise ValueError("fresh Leant process exited unsuccessfully")
                validate_settings(transcript, source)
                cell["actual_provider_inventory"] = actual_provider_inventory(transcript, cell)
                result = parse_output(transcript, [cell])[0]
                cell["live_outcome"] = result
                implementation_policy = length_source_route(transcript, cell, result,
                    cell["actual_provider_inventory"])
                if implementation_policy is not None:
                    cell["numeric_source_route"] = implementation_policy
                if result["status"] == "candidate":
                    check_displayed_source(result)
                    replay, names = candidate_replay(spec, result)
                    path = output / (cell["name"] + ".lean")
                    replay_source = write_source(runtime, path, replay)
                    report["source_hashes"][replay_source["path"]] = replay_source["sha256"]
                    cell["replay"] = check_kernel(runtime, processes, args,
                        cell["name"] + "-kernel", replay_source, names,
                        expected_candidate_replay_axioms(result["operation"], names),
                        implementation_policy=implementation_policy)
                    if cell["replay"]["status"] != "passed":
                        raise ValueError("exact displayed candidate/full-type/original-oracle replay failed")
                cell["status"] = "passed"
            except Exception as failure:
                cell.update(status="failed", failure=str(failure))
            finally:
                report["processes"] = processes.rows
                runtime.write_json(output / "results.json", report)
        report["status"] = "passed" if (report["oracle_controls"]["status"] == "passed"
            and all(cell["status"] == "passed" for cell in report["cells"])) else "failed"
    except Exception as failure:
        report.update(status="failed", failure=str(failure))
    finally:
        report["executable_unchanged"] = unchanged(runtime, {
            report["executable"]["path"]: report["executable"]["sha256"]})
        report["executables_unchanged"] = unchanged(runtime, executable_hashes)
        report["sources_unchanged"] = unchanged(runtime, report["source_hashes"])
        if not report["executables_unchanged"] or not report["sources_unchanged"]:
            report.update(status="failed", failure=report.get("failure", "source or pinned runtime changed during this receipt"))
        report["candidate_count"] = sum(cell["status"] == "passed" and cell["operation"] != "reject_all"
                                         for cell in report["cells"])
        report["false_control_count"] = sum(cell["status"] == "passed" and cell["operation"] == "reject_all"
                                             for cell in report["cells"])
        report["processes"] = processes.rows
        runtime.write_json(output / "results.json", report)
    print(f"Extended Lean behavioral corpus: {report['status']}; "
          f"{report['candidate_count']}/{report['expected_candidate_count']} candidates; "
          f"{report['false_control_count']}/{report['expected_false_control_count']} false controls")
    return 0 if report["status"] == "passed" else 1


if __name__ == "__main__":
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, "reconfigure"):
            stream.reconfigure(encoding="utf-8")
    raise SystemExit(main())
