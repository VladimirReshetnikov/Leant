#!/usr/bin/env python3
"""Isolated Lean acceptance for the 19 supplied-default Church signatures.

The canonical Djex behavior_partial_spec.py is selected by --spec-dir; its
source/manifest validation and exact expanded types remain authoritative.
No original partial signature is promoted to totality: each tested type has
the documented explicit default as its first value argument, after all source
type binders. Source Int stays Lean Int, never Nat or a Church numeral.

All engine/operation queries and false controls use fresh Leant processes.
Discovery is off except at, whose session contains only the generic Int
primitive and uses a one-entry cap plus exact observed inventory checking.
Its predicate inlines the SAME 168 concrete observations so no observation
declaration can enter discovery. Original and inline oracles are both replayed.

Oracle controls are isolated by operation, including every full-type wrong
control, with a separate primitive preflight. A failed operation cannot erase
another operation's independently accepted result. Candidate replay defines the
unchanged displayed term BEFORE observation definitions, under the complete
default-adjusted type, and inventories every generated declaration's axioms.
Acceptance also requires the engine's actual false control and final integrity.

--prepare-only writes inputs, controls, inventories, and a prepared receipt.
It never resolves or executes a compiler/backend. This runner performs no
build. Process-tree ownership/captures and kernel parsing reuse existing tools.
"""
from __future__ import annotations

import argparse
import hashlib
import importlib
import os
from pathlib import Path
import re
import shutil
import sys

from behavior_probe import latency_observer, parse_output
from behavior_extended_probe import check_kernel, write_source
from run_corpus import validate_settings

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
ENGINES = ("djinn", "exference", "both")
PRIMITIVE_NAME = "BehaviorPartialNumeric.intCase"
ROUTING_SPEC_SHA256 = "85066eab8089205346e591e3673f936844005e3846705c74d92d3a7e635b5716"
# Lean 4.32 String.length carries these dependencies through String.toList,
# String.Internal.toArray, and ByteArray.isSome_utf8Decode?_iff. Only the exact
# atKey observer and proofs of its unchanged predicate inherit them. The
# synthesized candidate, witnesses, wrong implementations, and other proofs
# must still have empty inventories.
AT_KEY_OBSERVER_AXIOMS = ("Classical.choice", "Quot.sound", "propext")
AT_KEY_CONTROL_NAMES = frozenset({
    "BehaviorPartial.check_atKey",
    "BehaviorPartialControl.witness_atKey_passes",
    "BehaviorPartialControl.wrong_atKey_always_default_rejected",
    "BehaviorPartialControl.wrong_atKey_last_matching_value_rejected",
})
AT_KEY_REPLAY_NAMES = frozenset({
    "BehaviorPartial.check_atKey",
    "BehaviorPartialReplay.candidate_passes_original_oracle",
})
PRODUCT_SOURCES = (
    "src/Main.hs", "src/Leant/Backend.hs", "src/Leant/Options.hs", "src/Leant/Synth/Behavioral.hs",
    "src/Leant/Synth/Engine.hs", "src/Leant/Synth/Fragment.hs", "src/Leant/Synth/Render.hs",
)


def load_spec(directory):
    directory = directory.resolve()
    sys.path.insert(0, str(directory))
    spec = importlib.import_module("behavior_partial_spec")
    runtime = importlib.import_module("behavior_runtime")
    for name in ("behavior_partial_spec", "behavior_extended_spec", "behavior_runtime", "behavior_spec"):
        module = sys.modules.get(name)
        if module is None or Path(module.__file__).resolve() != directory / (name + ".py"):
            raise ValueError("specification dependency came from another directory: " + name)
    spec.validate_specification()
    if len(spec.OPERATIONS) != 19 or len(spec.PARTIAL_CASES) != 19:
        raise ValueError("the selected specification no longer covers exactly the 19 source partial cases")
    return spec, runtime


def numeric_declarations(spec):
    inventory = spec.search_provider_inventory("at")["lean"]
    if inventory != [{
        "name": PRIMITIVE_NAME,
        "type": "∀ R : Type, Int → R → R → (Int → R) → R",
        "definition": "fun _ n negative zero positive => if n < 0 then negative else if n = 0 then zero else positive (n - 1)",
    }]:
        raise ValueError("review the changed generic Int provider before enabling discovery")
    return list(spec.search_provider_source("at", "lean"))


def _lean_literal(value):
    if type(value) is bool:
        return "true" if value else "false"
    if type(value) is int:
        return "(" + str(value) + ")"
    if isinstance(value, tuple):
        return "(" + ", ".join(_lean_literal(x) for x in value) + ")"
    if isinstance(value, list):
        return "[" + ", ".join(_lean_literal(x) for x in value) + "]"
    raise ValueError("unsupported native payload in the exact inline indexing fixture")


def at_predicate(spec, candidate):
    """Inline exactly the spec's native indexing observations, without helpers."""
    fixtures = spec.FIXTURES["at"]
    if len(fixtures) != spec.OBSERVATIONS["at"]:
        raise ValueError("indexing observation count differs from the specification")
    assertions = []
    for row in fixtures:
        if row["decode"] != "identity" or len(row["lean_type_arguments"]) != 1:
            raise ValueError("indexing observation changed its result or binder structure")
        native = row["native_inputs"]
        if type(native["index"]) is not int or not isinstance(native["list"], list):
            raise ValueError("indexing observation no longer uses a source Int and finite list")
        # Refuse drift between native data and the argument/expected spellings
        # which the original oracle uses. Result types are preserved verbatim.
        element_type = row["lean_type_arguments"][0]
        typed_default = "(" + _lean_literal(native["default"]) + " : " + element_type + ")"
        typed_index = "(" + _lean_literal(native["index"]) + " : Int)"
        original_default, original_index, original_list = row["lean_arguments"]
        typed_list = "(" + _lean_literal(native["list"]) + " : (List " + element_type + "))"
        encoded_list = "(BehaviorPartial.enc " + typed_list + ")"
        typed_expected = "(" + _lean_literal(row["expected_native"]) + " : " + element_type + ")"
        compact = lambda text: re.sub(r"\s+", "", text)
        pairs = ((typed_default, original_default), (typed_index, original_index),
                 (encoded_list, original_list), (typed_expected, row["lean_expected"]))
        if any(compact(inline) != compact(original) for inline, original in pairs):
            raise ValueError("inline indexing inputs differ from the original oracle: " + row["id"])
        expected = (native["list"][native["index"]]
                    if 0 <= native["index"] < len(native["list"]) else native["default"])
        if expected != row["expected_native"]:
            raise ValueError("indexing native expectation changed: " + row["id"])
        body = "zero"
        for value in reversed(native["list"]):
            body = "step " + _lean_literal(value) + " (" + body + ")"
        encoded = "(fun _ step zero => " + body + ")"
        assertions.append(
            "((" + candidate + ") (" + element_type + ") (" + original_default + ") ("
            + original_index + ") " + encoded + " = " + row["lean_expected"] + ")"
        )
    # Resolve each small equality separately. One Decidable instance for the
    # complete Prop conjunction exceeds Lean's total instance-size bound even
    # when the conjunction tree is balanced. The final Bool equality requires
    # only a small instance and preserves every original equality observation.
    decisions = ["(decide " + assertion + ")" for assertion in assertions]
    return "(" + spec.lean_conjunction(decisions, connective="&&") + ") = true"


def cell_commands(spec, engine, operation, args):
    false_control = operation == "reject_all"
    numeric = operation == "at"
    name = f"partial_{engine}_{operation}"
    target = "Nat → Nat" if false_control else spec.LEAN_TYPES[operation]
    predicate = ("False" if false_control else at_predicate(spec, name) if numeric
                 else spec.lean_predicate(operation, name))
    declarations = ([] if false_control else numeric_declarations(spec) if numeric
                    else list(spec.lean_prelude([operation])))
    if not false_control and not numeric and spec.search_provider_inventory(operation)["lean"]:
        raise ValueError("unexpected provider requirement for " + operation)
    lines = [
        ":set synth-library off", ":set synth-classical off",
        ":set synth-providers " + ("on" if numeric else "off"),
        ":set synth-debug on", ":set synth-ranking balanced", ":set synth-shown 1",
        f":set synth-djinn-strategy {args.djinn_strategy}",
        f":set synth-window {args.window}", f":set synth-verify {args.window}",
        f":set synth-steps {args.steps}", f":set synth-budget {args.budget}",
        f":set synth-timeout {args.timeout}", ":set synth-engine " + engine,
    ]
    if numeric:
        lines.append(":set synth-provider-cap 1")
    command = f":synth {name} : {target} where {predicate}"
    case_id = None if false_control else spec.SOURCE_CASE_IDS[operation]
    provenance = None if false_control else spec.PARTIAL_CASES[case_id]
    case = {
        "engine": engine, "operation": operation, "name": name, "type": target,
        "command": command, "expected": "no_candidate" if false_control else "candidate",
        "source_case_id": case_id,
        "original_source_signature": None if false_control else provenance["source_signature"],
        "original_expanded_type": None if false_control else spec.ORIGINAL_LEAN_TYPES[operation],
        "defaulted_expanded_type": None if false_control else spec.DEFAULTED_TYPES[operation],
        "manifest_default_type": None if false_control else provenance["manifest_default_type"],
        "source_default_type": None if false_control else provenance["source_default_type"],
        "default_argument_position": None if false_control else provenance["default_argument_position"],
        "original_binder_order": None if false_control else provenance["original_binder_order"],
        "finite_observation_count": 0 if false_control else spec.OBSERVATIONS[operation],
        "fixture_ids": [] if false_control else [row["id"] for row in spec.FIXTURES[operation]],
        "required_provider_names": [PRIMITIVE_NAME] if numeric else [],
        "required_provider_definitions": [] if false_control else spec.REQUIRED_PROVIDERS[operation]["lean"],
        "provider_policy": "one exact observed generic Int provider; observation-free session" if numeric else "discovery off",
        "oracle_policy": "same fixtures inlined; original and inline oracle both kernel-replayed" if numeric else "original specification oracle",
        "session_isolation": "one synthesis query in one fresh process",
        "status": "prepared", "accepted": False,
    }
    return "\n".join([*lines, *declarations, command, ":quit", ""]), case


def actual_provider_inventory(output, case):
    entries = re.findall(r"(?m)^debug provider: (.+)$", output)
    names, malformed = [], []
    for entry in entries:
        matches = re.findall(r'providerLeanName = "([^"\\]+)"', entry)
        if len(matches) == 1:
            names.append(matches[0])
        else:
            malformed.append(entry)
    required = case["required_provider_names"]
    return {
        "ordered_names": names, "entries": entries, "count": len(names),
        "required_ordered_names": required, "malformed_entries": malformed,
        "required_source_definitions": case["required_provider_definitions"],
        "exact_inventory_verified": names == required and not malformed
            and "provider inventory unavailable:" not in output,
        "type_authority": "exact source declaration, separate primitive kernel preflight, and full-signature candidate replay; raw provider fragments are retained above",
    }


def check_displayed_source(result):
    term = result["candidate"]
    if re.search(r"\b(?:sorry|admit|unsafe|axiom|native_decide)\b", term):
        raise ValueError("unchecked construct appeared in the displayed candidate")
    if re.search(r"\bBehaviorPartial(?:Oracle|Control|Replay)?\.", term):
        raise ValueError("an observation/oracle/control/replay declaration appeared in the candidate")
    if re.search(r"\bpartial_(?:djinn|exference|both)_[A-Za-z_0-9]+\b", term):
        raise ValueError("a target or prior accepted definition appeared in the candidate")
    used = re.findall(r"\bBehaviorPartialNumeric\.([A-Za-z_][A-Za-z_0-9']*)", term)
    allowed = {name.rsplit(".", 1)[1] for name in result["required_provider_names"]}
    if any(name not in allowed for name in used):
        raise ValueError("a generic Int declaration outside the exact provider inventory appeared")


def inventory_source(lines):
    """Inventory every generated def/abbrev/theorem, without duplicate prints."""
    retained, declarations, namespaces = [], [], []
    for line in "\n".join(lines).splitlines():
        if re.match(r"^\s*#print axioms ", line):
            continue
        opened = re.fullmatch(r"\s*namespace ([A-Za-z_][A-Za-z_0-9.]*)\s*", line)
        closed = re.fullmatch(r"\s*end(?: ([A-Za-z_][A-Za-z_0-9.]*))?\s*", line)
        if opened:
            namespaces.append(opened.group(1))
        elif closed:
            if not namespaces or (closed.group(1) is not None and closed.group(1) != namespaces[-1]):
                raise ValueError("unbalanced generated Lean namespace")
            namespaces.pop()
        declared = re.match(r"^\s*(?:def|abbrev|theorem)\s+([A-Za-z_][A-Za-z_0-9.']*)\b", line)
        if declared:
            name = ".".join([*namespaces, declared.group(1)])
            if name in declarations:
                raise ValueError("duplicate generated Lean declaration: " + name)
            declarations.append(name)
        if re.match(r"^\s*(?:axiom|unsafe|opaque)\b", line):
            raise ValueError("unchecked declaration in kernel replay source")
        retained.append(line)
    if namespaces:
        raise ValueError("unterminated generated Lean namespace")
    retained += ["#print axioms " + name for name in declarations]
    return "\n".join(retained) + "\n", declarations


def oracle_control_source(spec, operation):
    control_lines, _ = spec.lean_control_source([operation])
    lines = ["set_option autoImplicit false", *spec.lean_prelude([operation]), *control_lines]
    if operation == "at":
        positive = [spec.WITNESS_NAMES[operation]["lean"], spec.PROVIDER_WITNESS_NAMES[operation]["lean"]]
        for index, name in enumerate(positive):
            lines.append(
                f"theorem BehaviorPartialControl.inline_positive_{index} : {at_predicate(spec, name)} := by decide"
            )
        for label, name in spec.WRONG_CONTROL_NAMES[operation].items():
            lines.append(
                f"theorem BehaviorPartialControl.inline_wrong_{label} : ¬ ({at_predicate(spec, name['lean'])}) := by decide"
            )
    return inventory_source(lines)


def primitive_control_source(spec):
    lines, _ = spec.provider_control_source("lean")
    return inventory_source(["set_option autoImplicit false", *lines])


def candidate_replay(spec, result):
    name = "BehaviorPartialReplay.candidate"
    proof = name + "_passes_original_oracle"
    # Define the candidate before any observation/oracle helper exists. Only
    # the query's exact approved primitive can precede it in this fresh file.
    lines = ["set_option autoImplicit false"]
    if result["operation"] == "at":
        lines += numeric_declarations(spec)
    lines += [
        "namespace BehaviorPartialReplay", "end BehaviorPartialReplay",
        f"def {name} : {spec.LEAN_TYPES[result['operation']]} :=",
        "\n".join("  " + line for line in result["candidate"].splitlines()),
        *spec.lean_prelude([result["operation"]]),
        f"theorem {proof} : {spec.lean_predicate(result['operation'], name)} := by decide",
    ]
    if result["operation"] == "at":
        lines.append(
            f"theorem {name}_passes_inline_oracle : {at_predicate(spec, name)} := by decide"
        )
    return inventory_source(lines)


def expected_oracle_control_axioms(operation, names):
    allowed = AT_KEY_CONTROL_NAMES if operation == "atKey" else frozenset()
    return {name: list(AT_KEY_OBSERVER_AXIOMS) if name in allowed else [] for name in names}


def expected_candidate_replay_axioms(operation, names):
    allowed = AT_KEY_REPLAY_NAMES if operation == "atKey" else frozenset()
    return {name: list(AT_KEY_OBSERVER_AXIOMS) if name in allowed else [] for name in names}


def tracked_source(runtime, report, path, source):
    row = write_source(runtime, path, source)
    report["source_hashes"][row["path"]] = row["sha256"]
    return row


def persist(runtime, output, report, processes=None):
    if processes is not None:
        report["processes"] = processes.rows
    runtime.write_json(output / "results.json", report)


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


def kernel_row(runtime, processes, args, label, row):
    try:
        checked = check_kernel(runtime, processes, args, label, row["source"], row["expected_declarations"],
                               expected_axioms=row["expected_axiom_inventories"])
        row.update(checked)
        if runtime.sha256(row["source"]["path"]) != row["source"]["sha256"]:
            row.update(status="failed", failure="kernel input changed during replay")
    except Exception as failure:
        row.update(status="failed", failure=str(failure))


def finish(runtime, report, executable_hashes, *, interrupted=False):
    integrity = unchanged(runtime, report["source_hashes"]) and unchanged(runtime, executable_hashes)
    report["sources_unchanged"] = unchanged(runtime, report["source_hashes"])
    report["executables_unchanged"] = unchanged(runtime, executable_hashes)
    false_controls = {cell["engine"]: cell for cell in report["cells"] if cell["operation"] == "reject_all"}
    for cell in report["cells"]:
        controls = [row for row in report["oracle_controls"] if row["operation"] == cell["operation"]]
        cell["oracle_controls_passed"] = (
            bool(controls) and all(row["status"] == "passed" for row in controls)
            if cell["operation"] != "reject_all" else True)
        cell["engine_false_control_passed"] = false_controls[cell["engine"]]["status"] == "passed"
        cell["accepted"] = (cell["status"] == "passed" and cell["oracle_controls_passed"]
                            and cell["engine_false_control_passed"] and integrity)
    candidates = [cell for cell in report["cells"] if cell["operation"] != "reject_all"]
    report["accepted_subset"] = [
        {"engine": cell["engine"], "operation": cell["operation"], "source_case_id": cell["source_case_id"]}
        for cell in candidates if cell["accepted"]]
    report["candidate_count"] = len(report["accepted_subset"])
    report["false_control_count"] = sum(row["status"] == "passed" for row in false_controls.values())
    report["passed_oracle_preflights"] = sum(row["status"] == "passed" for row in report["oracle_controls"])
    passed = (integrity and not report["preparation_failures"]
              and all(cell["accepted"] for cell in report["cells"])
              and all(row["status"] == "passed" for row in report["oracle_controls"]))
    report["status"] = "interrupted" if interrupted else "passed" if passed else "failed"
    report["accepted"] = passed and not interrupted
    if not integrity:
        report["integrity_failure"] = "tracked source or executable changed or was unavailable"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--leant", type=Path)
    parser.add_argument("--spec-dir", type=Path, default=ROOT / "lib/Djex/test-church")
    parser.add_argument("--output", type=Path, required=True, help="fresh or empty receipt directory")
    parser.add_argument("--engine", action="append", choices=ENGINES)
    parser.add_argument("--operation", action="append", help="operation in behavior_partial_spec.OPERATIONS")
    parser.add_argument("--window", type=int, default=65536)
    parser.add_argument("--budget", type=int, default=500000)
    parser.add_argument("--steps", type=int, default=100000)
    parser.add_argument("--timeout", type=int, default=90)
    parser.add_argument("--process-timeout", type=float, default=900)
    parser.add_argument("--djinn-strategy", choices=("depth-first", "interleave"), default="interleave")
    parser.add_argument("--lean", default="lean")
    parser.add_argument("--toolchain", default="leanprover/lean4:v4.32.0")
    parser.add_argument("--lean-runtime", type=Path, help="explicit actual kernel binary to invoke and hash instead of resolving the selected toolchain")
    parser.add_argument("--backend", type=Path, help="pin the live Lean REPL; otherwise use existing environment/cache discovery")
    parser.add_argument("--observe-latency", action="store_true")
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
    output = runtime.prepare_output_directory(args.output).resolve()
    provenance = spec.source_provenance()
    tracked = [
        Path(__file__), HERE / "behavior_extended_probe.py", HERE / "behavior_probe.py", HERE / "run_corpus.py",
        *[ROOT / path for path in PRODUCT_SOURCES],
        *[args.spec_dir / name for name in (
            "behavior_partial_spec.py", "behavior_extended_spec.py", "behavior_runtime.py", "behavior_spec.py", "manifest.json")],
        args.spec_dir.resolve().parent / provenance["source"],
    ]
    report = {
        "status": "prepared", "validation_mode": "prepared_only", "accepted": False,
        "engines": engines, "operations": operations, "provenance": provenance,
        "routing_spec_sha256": ROUTING_SPEC_SHA256,
        "routing_hash_format": "UTF-8 with universal newlines normalized to LF",
        "selected_spec_sha256": runtime.sha256(args.spec_dir / "behavior_partial_spec.py"),
        "routing_hash_matches_current_spec": hashlib.sha256(
            (args.spec_dir / "behavior_partial_spec.py").read_text(encoding="utf-8").encode("utf-8")
        ).hexdigest() == ROUTING_SPEC_SHA256,
        "full_corpus_selected": set(engines) == set(ENGINES) and set(operations) == set(spec.OPERATIONS),
        "expected_candidate_count": len(engines) * len(operations),
        "expected_false_control_count": len(engines),
        "settings": {
            "window": args.window, "verify": args.window, "shown": 1, "ranking": "balanced",
            "djinn_strategy": args.djinn_strategy, "djinn_choice_budget": args.budget,
            "exference_steps": args.steps, "command_timeout_seconds": args.timeout,
            "separate_process_guard_seconds": args.process_timeout,
        },
        "axiom_policy": "exact per-declaration inventories: empty for all implementations; only the named atKey String.length observer and its oracle proofs carry Classical.choice, Quot.sound, propext",
        "universe_policy": "complete original LEAN_TYPES with the explicit default; no inferred universe or binder weakening",
        "scope": "finite Haskell-source-derived default-adjusted Lean counterparts; no acceptance claim for the original partial signatures",
        "provider_policy": "library/classical off; discovery off except one exact generic Int provider for at; no target or oracle provider",
        "source_hashes": {str(path.resolve()): runtime.sha256(path) for path in tracked},
        "cells": [], "oracle_controls": [], "preparation_failures": [], "processes": [],
    }
    inputs = {}
    for engine in engines:
        for operation in [*operations, "reject_all"]:
            name = f"partial_{engine}_{operation}"
            try:
                source, cell = cell_commands(spec, engine, operation, args)
                inputs[name] = source
                cell["input"] = tracked_source(runtime, report, output / (name + ".txt"), source)
            except Exception as failure:
                cell = {"engine": engine, "operation": operation, "name": name,
                        "source_case_id": None if operation == "reject_all" else spec.SOURCE_CASE_IDS[operation],
                        "status": "preparation_failed", "accepted": False, "failure": str(failure)}
                report["preparation_failures"].append(name)
            report["cells"].append(cell)
    for operation in operations:
        row = {"id": "oracle-" + operation, "operation": operation, "kind": "operation_oracle_preflight",
               "status": "prepared", "positive_controls": 1 + int(operation in spec.LEAN_PROVIDER_WITNESSES),
               "fully_typed_wrong_controls": len(spec.LEAN_WRONG[operation]),
               "separating_fixtures": spec.CONTROL_COUNTEREXAMPLES[operation]}
        try:
            source, names = oracle_control_source(spec, operation)
            row.update(source=tracked_source(runtime, report, output / ("PartialOracle_" + operation + ".lean"), source),
                       expected_declarations=names,
                       expected_axiom_inventories=expected_oracle_control_axioms(operation, names))
        except Exception as failure:
            row.update(status="preparation_failed", failure=str(failure))
            report["preparation_failures"].append(row["id"])
        report["oracle_controls"].append(row)
    if "at" in operations:
        row = {"id": "primitive-at", "operation": "at", "kind": "generic_primitive_preflight", "status": "prepared"}
        try:
            source, names = primitive_control_source(spec)
            row.update(source=tracked_source(runtime, report, output / "PartialPrimitiveControls.lean", source),
                       expected_declarations=names,
                       expected_axiom_inventories={name: [] for name in names})
        except Exception as failure:
            row.update(status="preparation_failed", failure=str(failure))
            report["preparation_failures"].append(row["id"])
        report["oracle_controls"].append(row)
    report["expected_oracle_preflights"] = len(report["oracle_controls"])
    persist(runtime, output, report)
    if args.prepare_only:
        if report["preparation_failures"]:
            report["status"] = "preparation_failed"
            persist(runtime, output, report)
        print(f"{report['status']}: {len(report['cells'])} fresh query inputs and "
              f"{len(report['oracle_controls'])} isolated preflights; no processes run.")
        return 0 if report["status"] == "prepared" else 1

    processes = runtime.Processes(output, args.process_timeout)
    executable_hashes = {}
    interrupted = False
    try:
        leant, backend, live_lake, executable_hashes = runtime_identity(args, runtime, report)
        report.update(status="running", validation_mode="isolated_live_queries_and_exact_kernel_replays",
                      executable_hashes=executable_hashes)
        persist(runtime, output, report, processes)
        for row in report["oracle_controls"]:
            if row["status"] == "preparation_failed":
                continue
            row["status"] = "running"
            persist(runtime, output, report, processes)
            kernel_row(runtime, processes, args, row["id"], row)
            persist(runtime, output, report, processes)
        for cell in report["cells"]:
            if cell["status"] == "preparation_failed":
                continue
            cell["status"] = "running"
            persist(runtime, output, report, processes)
            observer = latency_observer(runtime, [cell]) if args.observe_latency else None
            try:
                if not unchanged(runtime, executable_hashes):
                    raise ValueError("a pinned executable changed before this query")
                source = inputs[cell["name"]]
                live = processes.run(cell["name"], [leant, "--plain", "--lake", live_lake], source=source, cwd=ROOT,
                    env=dict(os.environ, LEANT_BACKEND=str(backend), LEANT_SYNTH_TIMEOUT=str(args.timeout)),
                    observe=observer)
                transcript = live.stdout + live.stderr
                cell["exit_code"] = live.returncode
                cell["actual_behavioral_summaries"] = [
                    {"passed": int(passed), "falsified": int(falsified), "inconclusive": int(inconclusive)}
                    for passed, falsified, inconclusive in re.findall(
                        r"supplied behavioral assertion: (\d+) passed, (\d+) falsified, (\d+) inconclusive", transcript)]
                if live.returncode:
                    raise ValueError("fresh Leant process exited unsuccessfully")
                validate_settings(transcript, source)
                cell["actual_provider_inventory"] = actual_provider_inventory(transcript, cell)
                if not cell["actual_provider_inventory"]["exact_inventory_verified"]:
                    raise ValueError("actual providers differ from this cell's exact inventory")
                result = parse_output(transcript, [cell])[0]
                cell["live_outcome"] = result
                if observer is not None:
                    observer.validate_counts({cell["name"]: int(result["status"] == "candidate")})
                if result["status"] == "candidate":
                    check_displayed_source(result)
                    cell["displayed_candidate_sha256"] = hashlib.sha256(result["candidate"].encode("utf-8")).hexdigest()
                    replay, names = candidate_replay(spec, result)
                    row = {
                        "source": tracked_source(runtime, report, output / (cell["name"] + ".lean"), replay),
                        "expected_declarations": names, "status": "prepared",
                        "expected_axiom_inventories": expected_candidate_replay_axioms(cell["operation"], names),
                        "full_defaulted_signature": spec.LEAN_TYPES[cell["operation"]],
                        "candidate_declared_before_observation_helpers": True,
                    }
                    cell["replay"] = row
                    persist(runtime, output, report, processes)
                    kernel_row(runtime, processes, args, cell["name"] + "-kernel", row)
                    if row["status"] != "passed":
                        raise ValueError("exact displayed candidate/full-defaulted-type/original-oracle kernel replay failed")
                cell["status"] = "passed"
            except Exception as failure:
                cell.update(status="failed", failure=str(failure))
            finally:
                if observer is not None:
                    cell["latency_observations"] = observer.receipt()
                persist(runtime, output, report, processes)
    except KeyboardInterrupt:
        interrupted = True
        report["failure"] = "interrupted; owned process cleanup and independent earlier results retained"
    except Exception as failure:
        report["failure"] = str(failure)
    finally:
        for row in [*report["cells"], *report["oracle_controls"]]:
            if row["status"] in ("prepared", "running"):
                row.update(status="not_run", reason=report.get("failure", "run ended before this result"))
        finish(runtime, report, executable_hashes, interrupted=interrupted)
        persist(runtime, output, report, processes)
    print(f"Supplied-default Lean corpus: {report['status']}; "
          f"{report['candidate_count']}/{report['expected_candidate_count']} accepted candidates; "
          f"{report['false_control_count']}/{report['expected_false_control_count']} false controls.")
    return 130 if interrupted else 0 if report["status"] == "passed" else 1


if __name__ == "__main__":
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, "reconfigure"):
            stream.reconfigure(encoding="utf-8")
    raise SystemExit(main())
