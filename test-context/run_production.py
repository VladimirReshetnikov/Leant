#!/usr/bin/env python3
"""Accept the public lexical-Given synthesis route and replay exact Lean output.

Only the Dictionary class and nominal Token declaration enter positive search.
Reference implementations and counterexample controls live in separate Lean
processes. Each query starts a fresh Leant process. Unsupported metadata is an
explicit negative boundary, never a substitute for a failed positive query.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path[:0] = [str(ROOT / "test-church"), str(ROOT / "lib/Djex/test-church")]

import behavior_runtime as runtime
from run_corpus import reported_axioms, validate_settings


CLASS = "ContextProduction.Dictionary"
TOKEN = "ContextProduction.Token"
DECLARATIONS = [
    f"class {CLASS} (α : Type) where tag : Nat",
    f"structure {TOKEN} where payload : Nat",
]
UNIVERSE_CLASS = "ContextProduction.UniverseDictionary"
UNIVERSE_DECLARATION = (
    f"class {UNIVERSE_CLASS}.{{u}} (α : Type) : Type where "
    "evidence : ∀ β : Type u, True"
)
DECLARATION_NAMES = [CLASS, CLASS + ".mk", CLASS + ".tag",
                     TOKEN, TOKEN + ".mk", TOKEN + ".payload"]
SCHEME = f"(∀ (β : Type), [{CLASS} β] → β → {TOKEN})"
IDENTITY = f"∀ (α : Type), [{CLASS} α] → α → α"
FORWARDING = SCHEME + " → " + SCHEME
LOCAL_GIVEN = f"∀ (α : Type), [{CLASS} α] → {SCHEME} → α → {TOKEN}"
UNSUPPORTED_SOURCE = (
    "exact lexical-Given source requires Type-0 binders, nominal/class domains, "
    "supported visibility and nondependent term arrows"
)
GLOBAL_REFUSAL = "context-source: global provider inventory requires complete source metadata"
FORBIDDEN_TERM = re.compile(
    r"\b(?:sorry|admit|unsafe|axiom|inferInstance|inferInstanceAs|Classical)\b"
    r"|\b(?:ContextOracle|ContextSyntax|ContextReplay|BehaviorChurch|BehaviorControl|BehaviorCandidates)\."
    r"|\bby\b"
)


def dictionary(ty, payload):
    return f"(@{CLASS}.mk {ty} {payload})"


def provider(offset):
    return (f"(fun (β : Type) [d : {CLASS} β] (_ : β) => "
            f"{TOKEN}.mk ((@{CLASS}.tag β d) + {offset}))")


def conjunction(observations):
    return " ∧ ".join("(" + observation + ")" for observation in observations)


def specifications():
    # Dictionary payload changes with the same type and value. Changing the
    # supplied provider independently rules out a hard-coded payload result.
    identity_observations = [
        f"@{{f}} Nat {dictionary('Nat', 7)} 37 = 37",
        f"@{{f}} Nat {dictionary('Nat', 11)} 53 = 53",
        f"@{{f}} Bool {dictionary('Bool', 11)} true = true",
        f"@{{f}} Bool {dictionary('Bool', 7)} false = false",
    ]
    forwarding_observations = []
    local_observations = []
    for ty, value, payload, offset in [
            ("Nat", "37", 7, 0), ("Nat", "37", 11, 0),
            ("Nat", "53", 7, 100), ("Bool", "true", 11, 100)]:
        dictionary_value = dictionary(ty, payload)
        callback = provider(offset)
        forwarding_observations.append(
            f"{TOKEN}.payload (@{{f}} {callback} {ty} {dictionary_value} {value}) = {payload + offset}")
        local_observations.append(
            f"{TOKEN}.payload (@{{f}} {ty} {dictionary_value} {callback} {value}) = {payload + offset}")
    return {
        "identity": dict(
            type=IDENTITY, predicate=conjunction(identity_observations),
            oracle=f"fun (α : Type) [unusedDictionary : {CLASS} α] (x : α) => x",
            wrong_predicate=f"@{{f}} Nat {dictionary('Nat', 7)} 37 = 38",
            observation_count=len(identity_observations), expected="candidate"),
        "forwarding": dict(
            type=FORWARDING, predicate=conjunction(forwarding_observations),
            oracle=f"fun (p : {SCHEME}) => @p",
            wrong_oracle=(f"fun (p : {SCHEME}) (α : Type) [d : {CLASS} α] (x : α) => "
                          f"@p α {dictionary('α', 7)} x"),
            observation_count=len(forwarding_observations), expected="candidate"),
        "local_given": dict(
            type=LOCAL_GIVEN, predicate=conjunction(local_observations),
            oracle=(f"fun (α : Type) [d : {CLASS} α] (p : {SCHEME}) (x : α) => @p α d x"),
            wrong_oracle=(f"fun (α : Type) [d : {CLASS} α] (p : {SCHEME}) (x : α) => "
                          f"@p α {dictionary('α', 7)} x"),
            observation_count=len(local_observations), expected="candidate"),
        "reject_all": dict(
            type=IDENTITY, predicate="False",
            oracle=f"fun (α : Type) [unusedDictionary : {CLASS} α] (x : α) => x",
            observation_count=1, expected="no_candidate"),
        "higher_universe": dict(
            type=f"∀ (α : Type), [{CLASS} α] → (∀ (β : Type 1), β → β)",
            predicate="True", oracle=f"fun (α : Type) [unusedDictionary : {CLASS} α] (β : Type 1) (x : β) => x",
            observation_count=0, expected="unsupported", required_refusal=UNSUPPORTED_SOURCE),
        "constant_universe": dict(
            # The universe occurs only in a Prop field, so the actual class
            # parameter and result remain Type 0. Dropping this vector would
            # silently equate distinct source declarations C.{0} and C.{1}.
            type=f"∀ (α : Type), [{UNIVERSE_CLASS}.{{1}} α] → α → α",
            predicate="True", oracle=f"fun (α : Type) [unusedDictionary : {UNIVERSE_CLASS}.{{1}} α] (x : α) => x",
            extra_declarations=[UNIVERSE_DECLARATION],
            extra_inventory=[UNIVERSE_CLASS, UNIVERSE_CLASS + ".mk", UNIVERSE_CLASS + ".evidence"],
            observation_count=0, expected="unsupported", required_refusal=UNSUPPORTED_SOURCE),
        "global_metadata": dict(
            # The abstract local lane has no Token value. Discovery is enabled
            # only for this explicit inventory-refusal control; no helper or
            # implementation declaration is added to the live environment.
            type=f"∀ (α : Type), [{CLASS} α] → {TOKEN}",
            predicate=conjunction([
                f"{TOKEN}.payload (@{{f}} Nat {dictionary('Nat', payload)}) = {payload}"
                for payload in (7, 11)]),
            oracle=f"fun (α : Type) [d : {CLASS} α] => {TOKEN}.mk (@{CLASS}.tag α d)",
            providers=True, observation_count=2, expected="unsupported", required_refusal=GLOBAL_REFUSAL),
    }


def instantiate(template, name):
    # Substitute only our function marker. Lean universe and record braces
    # remain literal source text and never enter Python's formatting grammar.
    return template.replace("{f}", name)


def declarations(case):
    return [*DECLARATIONS, *case.get("extra_declarations", [])]


def command_source(case, args):
    settings = [
        ":set synth-library off", ":set synth-classical off",
        ":set synth-providers " + ("on" if case.get("providers") else "off"),
        ":set synth-debug on", ":set synth-ranking balanced", ":set synth-shown 1",
        ":set synth-djinn-strategy interleave", f":set synth-provider-cap {args.provider_cap}",
        f":set synth-window {args.window}", f":set synth-verify {args.window}",
        f":set synth-steps {args.steps}", f":set synth-budget {args.budget}",
        f":set synth-timeout {args.timeout}", ":set synth-engine " + case["engine"],
    ]
    return "\n".join([*settings, *declarations(case), case["command"], ":quit", ""])


def selected_cases(engines, operations, modes):
    specs = specifications()
    cases = []
    for engine in engines:
        for mode in modes:
            for operation in operations:
                if operation == "reject_all" and mode != "where":
                    continue
                name = "context_" + engine + "_" + mode + "_" + operation
                case = dict(specs[operation], engine=engine, operation=operation, mode=mode, name=name)
                case["command"] = (f":synth {name} : {case['type']} where {instantiate(case['predicate'], name)}"
                                   if mode == "where" else f":synth {case['type']}")
                cases.append(case)
    return cases


def syntax_source(case):
    name = "ContextSyntax.condition"
    decision = "ContextSyntax.condition_decidable"
    expression = instantiate(case["predicate"], "f")
    names = [*DECLARATION_NAMES, *case.get("extra_inventory", []), name, decision]
    lines = ["set_option autoImplicit false", *declarations(case),
             f"def {name} (f : {case['type']}) : Prop := {expression}",
             f"def {decision} (f : {case['type']}) : Decidable ({name} f) := by unfold {name}; infer_instance"]
    if case.get("extra_declarations") == [UNIVERSE_DECLARATION]:
        # Prove the negative is the lost constant universe vector, rather
        # than accidentally choosing a class whose result already needs Type 1.
        type_zero = "ContextSyntax.class_result_type_zero"
        lines.append(f"def {type_zero} : Type := {UNIVERSE_CLASS}.{{1}} Nat")
        names.append(type_zero)
    return "\n".join([*lines, *("#print axioms " + n for n in names), ""]), names


def oracle_source(case):
    name = "ContextOracle.reference"
    proof = name + "_checked"
    condition = instantiate(case["predicate"], name)
    if case["expected"] == "no_candidate":
        condition = "¬ (" + condition + ")"
    names = [*DECLARATION_NAMES, *case.get("extra_inventory", []), name, proof]
    lines = ["set_option autoImplicit false", *declarations(case),
             f"def {name} : {case['type']} := {case['oracle']}",
             f"theorem {proof} : {condition} := by decide"]
    if "wrong_oracle" in case:
        wrong = "ContextOracle.wrong_dictionary"
        rejected = wrong + "_rejected"
        lines += [f"def {wrong} : {case['type']} := {case['wrong_oracle']}",
                  f"theorem {rejected} : ¬ ({instantiate(case['predicate'], wrong)}) := by decide"]
        names += [wrong, rejected]
    if "wrong_predicate" in case:
        rejected = name + "_wrong_result_rejected"
        lines += [f"theorem {rejected} : ¬ ({instantiate(case['wrong_predicate'], name)}) := by decide"]
        names.append(rejected)
    return "\n".join([*lines, *("#print axioms " + n for n in names), ""]), names


def replay_source(case, term):
    name = "ContextReplay.accepted"
    proof = name + "_passes"
    names = [*DECLARATION_NAMES, name, proof]
    lines = ["set_option autoImplicit false", *DECLARATIONS,
             f"def {name} : {case['type']} :=", term,
             f"theorem {proof} : {instantiate(case['predicate'], name)} := by decide"]
    return "\n".join([*lines, *("#print axioms " + n for n in names), ""]), names


def saved_source(output, filename, source, names=()):
    path = output / filename
    path.write_text(source, encoding="utf-8", newline="\n")
    return dict(path=str(path.resolve()), sha256=runtime.sha256(path), declarations=list(names), status="prepared")


def unchanged(path, digest):
    try:
        return runtime.sha256(path) == digest
    except OSError:
        return False


def default_lean_runtime():
    return (Path(os.environ.get("ELAN_HOME", str(Path.home() / ".elan"))) /
            "toolchains/leanprover--lean4---v4.32.0/bin" / ("lean.exe" if os.name == "nt" else "lean"))


def pin_kernel(path):
    executable = path.expanduser().resolve(strict=True)
    if not executable.is_file():
        raise ValueError("--lean-runtime must resolve to the actual Lean kernel executable")
    return dict(path=str(executable), sha256_before=runtime.sha256(executable),
                invocation="direct absolute kernel executable; no PATH lookup or elan proxy")


def kernel_check(processes, label, prepared, kernel):
    if not unchanged(prepared["path"], prepared["sha256"]):
        raise ValueError("prepared kernel source changed before execution")
    if not unchanged(kernel["path"], kernel["sha256_before"]):
        raise ValueError("pinned Lean kernel changed before execution")
    result = processes.run(label, [kernel["path"], prepared["path"]], cwd=ROOT)
    inventories = {name: reported_axioms(result.stdout + result.stderr, name)
                   for name in prepared["declarations"]}
    stable = unchanged(prepared["path"], prepared["sha256"])
    kernel_stable = unchanged(kernel["path"], kernel["sha256_before"])
    passed = result.returncode == 0 and stable and kernel_stable and all(value == set() for value in inventories.values())
    return dict(status="passed" if passed else "failed", source_unchanged=stable,
                kernel_path=kernel["path"], kernel_sha256=kernel["sha256_before"], kernel_unchanged=kernel_stable,
                axiom_inventories={name: None if value is None else sorted(value)
                                  for name, value in inventories.items()})


def query_block(transcript, case):
    blocks = re.split(r"(?m)^λ> :synth ", transcript)[1:]
    if len(blocks) != 1:
        raise ValueError("expected exactly one isolated synthesis command")
    block = blocks[0].split("\nλ> ", 1)[0]
    if block.splitlines()[0] != case["command"].removeprefix(":synth "):
        raise ValueError("live query differs from its exact prepared command")
    return block


def candidate_result(block, case):
    summaries = re.findall(r"(?m)^supplied behavioral assertion: (\d+) passed, (\d+) falsified, (\d+) inconclusive", block)
    result = dict(name=case["name"], type=case["type"], mode=case["mode"], output=block)
    if case["mode"] == "where":
        if len(summaries) != 1:
            raise ValueError("missing or duplicate supplied-assertion summary")
        passed, falsified, inconclusive = map(int, summaries[0])
        result["observations"] = dict(passed=passed, falsified=falsified, inconclusive=inconclusive)
    elif summaries:
        raise ValueError("ordinary synthesis unexpectedly acquired a supplied behavioral assertion")
    labels = re.findall(r"(?m)^[ \t]+it([0-9]+)[ \t]+", block)
    if case["expected"] == "no_candidate":
        if case["mode"] != "where" or labels or passed or not falsified or inconclusive:
            raise ValueError("where False did not establish actual predicate rejection")
        if "debug accepted-candidate: " in block:
            raise ValueError("where False retained an accepted candidate observation")
        return dict(result, status="no_candidate")
    if labels != ["1"] or (case["mode"] == "where" and passed < 1):
        raise ValueError("expected exactly one verified displayed output")
    match = re.search(r"(?m)^[ \t]+it1[ \t]+(.+)$", block)
    lines = []
    for line in block[match.start(1):].splitlines():
        # A fully exhausted successful query need not print a search note.
        # Its assertion summary is still output metadata, never candidate text.
        if re.match(r"^(?:note:|debug |error:|supplied behavioral assertion:|[ \t]+it[0-9]+[ \t])", line):
            break
        lines.append(line)
    term = "\n".join(lines).strip()
    if not term:
        raise ValueError("empty displayed candidate")
    return dict(result, status="candidate", candidate=term)


def accepted_observation(block, case, term):
    rows = re.findall(r"(?m)^debug accepted-candidate: (.*)$", block)
    if len(rows) != 1:
        raise ValueError("displayed candidate lacks its unique retained-variant observation")
    observation = json.loads(rows[0])
    if (not isinstance(observation, dict) or type(observation.get("schema")) is not int
            or observation["schema"] != 1 or observation.get("label") != "it1"
            or observation.get("term") != term or observation.get("route") != "RouteTypedCandidate"
            or type(observation.get("variant_ordinal")) is not int or observation["variant_ordinal"] < 0):
        raise ValueError("candidate observation does not own the exact displayed text and typed route")
    origin = observation.get("origin")
    if not isinstance(origin, dict):
        raise ValueError("displayed variant lost its exact typed origin")
    if origin.get("engine") not in ("djinn", "exference") or (
            case["engine"] != "both" and origin["engine"] != case["engine"]):
        raise ValueError("typed origin does not belong to an actual selected engine")
    if type(origin.get("renderer_ordinal")) is not int or origin["renderer_ordinal"] < 0:
        raise ValueError("typed origin lost its own renderer ordinal")
    rendering = origin.get("rendering", {})
    if (not isinstance(rendering, dict) or rendering.get("matches_verified_text") is not True
            or rendering.get("term") != term or "failure" in rendering):
        raise ValueError("the retained graph did not reproduce its exact accepted renderer alternative")
    graph = origin.get("graph", {})
    if (not isinstance(graph, dict) or "failure" in graph or not isinstance(graph.get("root"), str) or not graph["root"]
            or not isinstance(graph.get("root_type"), str) or not graph["root_type"]
            or graph.get("root_closed") is not True or graph.get("erasure_matches_compatibility") is not True
            or type(graph.get("node_count")) is not int or graph["node_count"] < 1 or graph.get("globals") != []):
        raise ValueError("accepted origin lost its own closed source graph or exact compatibility association")
    introductions = graph.get("context_introductions")
    applications = graph.get("context_applications")
    if not isinstance(introductions, list) or not isinstance(applications, list):
        raise ValueError("accepted graph lost its explicit context evidence observations")
    binders = set()
    sites = set()
    for introduction in introductions:
        if (not isinstance(introduction, dict) or not isinstance(introduction.get("node"), str)
                or not introduction["node"] or not isinstance(introduction.get("occurrence"), str)
                or not introduction["occurrence"] or introduction["node"] in sites
                or not isinstance(introduction.get("binders"), list) or not introduction["binders"]):
            raise ValueError("malformed or duplicate context introduction observation")
        sites.add(introduction["node"])
        for slot, binder in enumerate(introduction["binders"]):
            if (not isinstance(binder, dict) or type(binder.get("slot")) is not int
                    or binder != dict(introduction=introduction["occurrence"], slot=slot)):
                raise ValueError("context introduction lost ordered source dictionary slots")
            identity = (binder["introduction"], binder["slot"])
            if identity in binders:
                raise ValueError("dictionary introduction identity was duplicated")
            binders.add(identity)
    for application in applications:
        if (not isinstance(application, dict) or not isinstance(application.get("node"), str)
                or not application["node"] or not isinstance(application.get("occurrence"), str)
                or not application["occurrence"] or application["node"] in sites
                or not isinstance(application.get("evidence"), list) or not application["evidence"]):
            raise ValueError("malformed or duplicate context application observation")
        sites.add(application["node"])
        for binder in application["evidence"]:
            if (not isinstance(binder, dict) or type(binder.get("slot")) is not int
                    or not isinstance(binder.get("introduction"), str)
                    or (binder.get("introduction"), binder["slot"]) not in binders):
                raise ValueError("dictionary application lost its actual introduced source owner")
    if case["operation"] in ("identity", "local_given") and not introductions:
        raise ValueError("accepted root context has no actual dictionary introduction")
    if case["operation"] == "local_given" and not applications:
        raise ValueError("forced provider application has no actual graph dictionary evidence")
    return dict(observation=observation, observation_sha256=hashlib.sha256(rows[0].encode("utf-8")).hexdigest())


def validate_live(transcript, source, case):
    block = query_block(transcript, case)
    # The regular settings validator correctly rejects every engine error.
    # For a negative boundary, remove ONLY its one expected error line from
    # the validation copy; retain the exact original transcript as evidence.
    error_lines = re.findall(r"(?m)^synthesis engine error: (.*)$", block)
    checked_transcript = transcript
    if case["expected"] == "unsupported":
        if len(error_lines) != 1 or case["required_refusal"] not in error_lines[0]:
            raise ValueError("missing the exact expected unsupported-metadata engine refusal")
        checked_transcript = transcript.replace("synthesis engine error: " + error_lines[0],
                                                "expected metadata refusal: " + error_lines[0], 1)
    validate_settings(checked_transcript, source)
    inventories = []
    for line in transcript.splitlines():
        if line.startswith("debug provider: "):
            match = re.search(r'\bproviderLeanName = ("(?:[^"\\]|\\.)*")', line)
            if match is None:
                raise ValueError("provider debug row lacks an exact source identity")
            inventories.append(dict(name=json.loads(match.group(1)), row=line))
    if case.get("providers"):
        if not inventories:
            raise ValueError("global-metadata control did not reach a real nonempty provider inventory")
    elif inventories:
        raise ValueError("providers-off query discovered a global provider")
    if "provider inventory unavailable:" in transcript:
        raise ValueError("provider discovery failed instead of exercising the metadata boundary")
    if case["expected"] == "unsupported":
        if re.search(r"(?m)^[ \t]+it[0-9]+[ \t]+", block):
            raise ValueError("unsupported metadata produced a displayed candidate")
        summaries = re.findall(r"supplied behavioral assertion: (\d+) passed, (\d+) falsified, (\d+) inconclusive", block)
        if ((case["mode"] == "where" and (len(summaries) != 1 or any(int(value) for value in summaries[0])))
                or (case["mode"] == "ordinary" and summaries)):
            raise ValueError("unsupported metadata reached behavioral evaluation or changed its query mode")
        if "debug accepted-candidate: " in block:
            raise ValueError("unsupported metadata acquired an accepted variant observation")
        return dict(status="unsupported", refusal=error_lines[0], output=block,
                    provider_inventory=inventories)
    if not re.search(r"(?m)^debug fragment: .*FExactContext", block):
        raise ValueError("the live serializer did not route an exact context fragment")
    result = candidate_result(block, case)
    if result["status"] == "candidate":
        term = result["candidate"]
        plain_names = term.replace("«", "").replace("»", "")
        if (FORBIDDEN_TERM.search(term) or case["name"] in term
                or re.search(r"\bContextProduction\.(?:Dictionary|Token)\.", plain_names)):
            raise ValueError("candidate acquired an oracle, dictionary solver, field or constructor provider")
        result["accepted_variant"] = accepted_observation(block, case, term)
        if not re.search(r"\[@?_root_\.ContextProduction\.Dictionary\b", plain_names):
            raise ValueError("the displayed term lost its explicit source context type")
        if case["operation"] in ("identity", "local_given") and "leantGiven" not in term:
            raise ValueError("the displayed root context lost its introduced lexical dictionary")
        applications = re.findall(r"@leantHead[0-9]+ (leantGiven[0-9]+x[0-9]+)\b", term)
        result["explicit_dictionary_arguments"] = applications
        if case["operation"] == "local_given" and not applications:
            raise ValueError("forced local application did not pass an explicit lexical dictionary")
    result["provider_inventory"] = inventories
    return result


def source_inventory():
    paths = {Path(__file__).resolve(), ROOT / "test-context/test_production.py", ROOT / "leant.cabal", ROOT / "cabal.project",
             ROOT / "test-church/run_corpus.py",
             ROOT / "lib/Djex/test-church/behavior_runtime.py", ROOT / "lib/Djex/test-church/behavior_spec.py",
             ROOT / "lib/Djex/djex.cabal"}
    for directory in ["src", "test-unit", "lib/Djex/src", "lib/Djex/synthesis/src",
                      "lib/Djex/synthesis/internal", "lib/Djex/djinn/src-core",
                      "lib/Djex/djinn/src-internal", "lib/Djex/exference/src-core"]:
        paths.update((ROOT / directory).rglob("*.hs"))
    return sorted(paths)


def hashes(paths):
    return {str(path.relative_to(ROOT)): runtime.sha256(path) for path in paths}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--leant", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--engine", action="append", choices=("djinn", "exference", "both"))
    parser.add_argument("--mode", action="append", choices=("ordinary", "where"))
    parser.add_argument("--operation", action="append", choices=tuple(specifications()))
    parser.add_argument("--window", type=int, default=32)
    parser.add_argument("--steps", type=int, default=20000)
    parser.add_argument("--budget", type=int, default=20000)
    parser.add_argument("--provider-cap", type=int, default=80)
    parser.add_argument("--timeout", type=int, default=45)
    parser.add_argument("--process-timeout", type=float, default=120)
    parser.add_argument("--lean-runtime", type=Path, default=default_lean_runtime(),
                        help="actual Lean kernel binary, invoked directly and pinned before/after every kernel call")
    parser.add_argument("--prepare-only", action="store_true")
    args = parser.parse_args()
    runtime.validate_limits(args)
    if args.timeout <= 0 or args.provider_cap <= 0 or (not args.prepare_only and args.leant is None):
        parser.error("positive timeout/provider cap and --leant are required for execution")
    engines = args.engine or ["djinn", "exference", "both"]
    modes = args.mode or ["ordinary", "where"]
    specifications_by_name = specifications()
    operations = args.operation or list(specifications_by_name)
    if (len(engines) != len(set(engines)) or len(operations) != len(set(operations))
            or len(modes) != len(set(modes))):
        parser.error("duplicate engine/mode/operation selections are not coverage")
    cases = selected_cases(engines, operations, modes)
    if not cases:
        parser.error("the selection has no applicable cases; reject_all requires --mode where")
    if not args.prepare_only:
        try:
            kernel = pin_kernel(args.lean_runtime)
        except (OSError, ValueError) as failure:
            parser.error(str(failure))
    output = runtime.prepare_output_directory(args.output).resolve()
    sources = source_inventory()
    before = hashes(sources)
    for path in sources:
        snapshot = output / "source" / path.relative_to(ROOT)
        snapshot.parent.mkdir(parents=True, exist_ok=True)
        snapshot.write_bytes(path.read_bytes())
    preflights = {}
    for operation in dict.fromkeys(case["operation"] for case in cases):
        case = specifications_by_name[operation]
        syntax, names = syntax_source(case)
        oracle, oracle_names = oracle_source(case)
        preflights[operation] = dict(
            syntax=saved_source(output, operation + "-syntax.lean", syntax, names),
            oracle=saved_source(output, operation + "-oracle.lean", oracle, oracle_names))
    for case in cases:
        case["commands"] = saved_source(output, case["name"] + ".commands.txt", command_source(case, args))
    report = dict(status="prepared", selected=dict(engines=engines, modes=modes, operations=operations), cases=cases,
                  settings=dict(window=args.window, verify=args.window, steps=args.steps, budget=args.budget,
                                timeout=args.timeout, process_timeout=args.process_timeout,
                                provider_cap=args.provider_cap, strategy="interleave", shown=1,
                                ranking="balanced", debug=True, library=False, classical=False,
                                providers="off except explicit global_metadata refusal control"),
                  expected_cases=len(cases), source_hashes_before=before, preflights=preflights, results=[],
                  scope="public ordinary and named-where contextual synthesis; exact displayed variant/graph/owner association and independent full-type Lean replay with finite dictionary payload observations; no global/universe support claim")
    receipt = output / "results.json"
    runtime.write_json(receipt, report)
    if args.prepare_only:
        print(f"Prepared {len(cases)} isolated queries; no processes run.", flush=True)
        return 0
    executable = args.leant.resolve()
    digest = runtime.sha256(executable)
    report.update(status="running", executable=str(executable), executable_sha256=digest, kernel=kernel)
    processes = runtime.Processes(output, args.process_timeout)
    generated = [item for checks in preflights.values() for item in checks.values()]
    try:
        # These two stages are independent of the Leant process. Their failures
        # disable only their own operation and cannot become a search verdict.
        for operation, checks in preflights.items():
            for stage, prepared in checks.items():
                try:
                    prepared.update(kernel_check(processes, operation + "-" + stage, prepared, kernel))
                except Exception as failure:
                    prepared.update(status="failed", failure=type(failure).__name__ + ": " + str(failure))
                runtime.write_json(receipt, report)
        for case in cases:
            row = dict(name=case["name"], engine=case["engine"], mode=case["mode"], operation=case["operation"], status="running")
            report["results"].append(row)
            runtime.write_json(receipt, report)
            try:
                if any(check["status"] != "passed" for check in preflights[case["operation"]].values()):
                    row.update(status="preflight_failed", failure="syntax or oracle preflight failed; live search was not run")
                    continue
                prepared = case["commands"]
                if not unchanged(prepared["path"], prepared["sha256"]):
                    raise ValueError("prepared live query source changed")
                if not unchanged(executable, digest):
                    raise ValueError("pinned Leant executable changed before execution")
                source = Path(prepared["path"]).read_text(encoding="utf-8")
                live = processes.run(case["name"] + "-live", [executable, "--plain"], source=source,
                                     cwd=ROOT, env=dict(os.environ, LEANT_SYNTH_TIMEOUT=str(args.timeout)))
                if live.returncode:
                    raise ValueError("live Leant process exited unsuccessfully")
                result = validate_live(live.stdout + live.stderr, source, case)
                row["live"] = result
                if result["status"] == "candidate":
                    text, names = replay_source(case, result["candidate"])
                    replay = saved_source(output, case["name"] + "-replay.lean", text, names)
                    generated.append(replay)
                    row["replay"] = replay
                    replay.update(kernel_check(processes, case["name"] + "-replay", replay, kernel))
                    if replay["status"] != "passed":
                        raise ValueError("exact displayed candidate failed independent full-type/payload replay")
                row["status"] = "passed"
            except Exception as failure:
                row.update(status="failed", failure=type(failure).__name__ + ": " + str(failure))
            finally:
                runtime.write_json(receipt, report)
        complete = len(report["results"]) == len(cases)
        report.update(status="passed" if complete and all(row["status"] == "passed" for row in report["results"]) else "failed",
                      accepted_candidate_count=sum(row["status"] == "passed" and row.get("live", {}).get("status") == "candidate"
                                                   for row in report["results"]),
                      false_control_count=sum(row["status"] == "passed" and row["operation"] == "reject_all"
                                              for row in report["results"]),
                      explicit_metadata_refusal_count=sum(row["status"] == "passed" and row.get("live", {}).get("status") == "unsupported"
                                                         for row in report["results"]))
    finally:
        report["source_hashes_after"] = hashes(source_inventory())
        report["sources_unchanged"] = report["source_hashes_after"] == before
        report["executable_unchanged"] = unchanged(executable, digest)
        kernel["sha256_after"] = runtime.sha256(kernel["path"]) if Path(kernel["path"]).is_file() else None
        report["kernel_executable_unchanged"] = kernel["sha256_after"] == kernel["sha256_before"]
        report["commands_unchanged"] = all(unchanged(case["commands"]["path"], case["commands"]["sha256"]) for case in cases)
        report["kernel_sources_unchanged"] = all(unchanged(item["path"], item["sha256"]) for item in generated)
        if not all(report[key] for key in ("sources_unchanged", "executable_unchanged", "kernel_executable_unchanged", "commands_unchanged", "kernel_sources_unchanged")):
            report.update(status="failed", provenance_failure="source, executable, query, kernel executable or kernel input changed during acceptance")
        if report["status"] == "running":
            report.update(status="interrupted", failure="prepared acceptance inventory did not finish")
        report["processes"] = processes.rows
        runtime.write_json(receipt, report)
    print(f"Production lexical context acceptance: {report['status']}; {report.get('accepted_candidate_count', 0)} exact outputs replayed", flush=True)
    return 0 if report["status"] == "passed" else 1


if __name__ == "__main__":
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, "reconfigure"):
            stream.reconfigure(encoding="utf-8")
    raise SystemExit(main())
