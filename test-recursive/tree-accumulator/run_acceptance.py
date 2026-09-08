"""Serial acceptance of one supplied tree-accumulator operation.

No process runs when this module is imported. Build the selected project and executables before running this fixture. All helpers are compiled/executed only by an explicit main invocation.
"""
from __future__ import annotations
import argparse
import json
import os
from pathlib import Path
import re
import shutil
import shlex
import sys

HERE = Path(__file__).resolve().parent
LEANT = HERE.parents[1]
DJEX = LEANT / "lib/Djex"
BUILD_PROJECT = LEANT
sys.path[:0] = [str(LEANT / "test-recursive"), str(LEANT / "test-church"),
               str(LEANT / "lib/Djex/test-church")]
import run_recursors as existing
runtime = existing.runtime


def require(condition, message):
    if not condition:
        raise ValueError(message)


def require_completed_live_query(transcript):
    # The shared observation parser establishes actual False observations,
    # even in a cancelled search. This fixture additionally requires the
    # command to finish within its deadline, for positive and negative cells.
    if re.search(r"(?m)^the engine did not finish within [0-9]+s\b", transcript):
        raise TimeoutError("synthesis command exceeded its prepared deadline")


def hashes(paths):
    return {str(path.resolve()): runtime.sha256(path)
            for path in sorted(set(map(Path, paths)), key=str)}


def unchanged(values):
    return all(Path(path).is_file() and runtime.sha256(path) == digest
               for path, digest in values.items())


def executable(spelling):
    path = Path(shutil.which(str(spelling)) or spelling).resolve()
    require(path.is_file(), "missing executable: " + str(spelling))
    return path


def sources():
    # A complete local source census, excluding generated objects/results.
    paths = [Path(existing.__file__), Path(runtime.__file__), Path(__file__),
             LEANT / "leant.cabal", DJEX / "djex.cabal",
             LEANT / "test-church/behavior_probe.py", LEANT / "test-church/run_corpus.py",
             LEANT / "lib/Djex/test-church/behavior_spec.py"]
    for project in (DJEX, LEANT / "lib/Djex"):
        for relative in ("src", "synthesis", "exference/src-core", "djinn/src-core", "djinn/src-internal"):
            paths.extend(path for path in (project / relative).rglob("*")
                         if path.is_file() and path.suffix in {".hs", ".lhs", ".hsc"}
                         and "dist-newstyle" not in path.relative_to(project).parts)
    paths.extend((LEANT / "src").rglob("*.hs"))
    paths.extend(path for path in HERE.rglob("*") if path.is_file()
                 and "__pycache__" not in path.parts)
    for project in (LEANT, DJEX):
        paths.extend(path for path in (project / "cabal.project", project / "cabal.project.local") if path.is_file())
    return paths


def library_inputs(directories):
    paths = [path for directory in directories for path in directory.glob("*HSdjex*")
             if path.is_file() and path.suffix in {".a", ".dll", ".so", ".dylib"}]
    require(paths, "no built Djex library in the configured Cabal package database")
    return paths


def main():
    global DJEX, BUILD_PROJECT
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True, help="fresh directory outside the proposal")
    parser.add_argument("--language", action="append", choices=("haskell", "lean"))
    parser.add_argument("--haskell-engine", action="append", choices=("djinn", "exference"))
    parser.add_argument("--lean-engine", action="append", choices=("djinn", "exference", "both"))
    parser.add_argument("--controls-only", action="store_true")
    parser.add_argument("--leant", type=Path)
    parser.add_argument("--ghc", default="ghc")
    parser.add_argument("--runghc", default="runghc")
    parser.add_argument("--cabal", default="cabal")
    parser.add_argument("--kernel", type=Path,
                        help="exact Lean4.32.0 toolchain binary, not an elan dispatch shim")
    parser.add_argument("--djex-root", type=Path, default=DJEX,
                        help="Djex source checkout; defaults to Leant's vendored dependency")
    parser.add_argument("--haskell-project", type=Path,
                        help="Cabal project owning the prebuilt Djex library; defaults to Leant for its vendored dependency")
    args = parser.parse_args()
    DJEX = args.djex_root.resolve()
    BUILD_PROJECT = (args.haskell_project or
                     (LEANT if DJEX == (LEANT / "lib/Djex").resolve() else DJEX)).resolve()
    languages = args.language or ["haskell", "lean"]
    h_engines = args.haskell_engine or ["djinn", "exference"]
    l_engines = args.lean_engine or ["djinn", "exference", "both"]
    for values in (languages, h_engines, l_engines):
        require(len(values) == len(set(values)), "duplicate selection")
    require(HERE != args.output.resolve() and HERE not in args.output.resolve().parents,
            "output must be outside the frozen proposal directory")
    if "lean" in languages:
        require(args.kernel is not None, "--kernel must identify the exact Lean4.32.0 binary")
        if not args.controls_only:
            require(args.leant is not None, "--leant is required for live Lean cells")
    output = runtime.prepare_output_directory(args.output.resolve())
    spec = json.loads((HERE / "case.json").read_text(encoding="utf-8"))
    manifest = json.loads((HERE / "manifest.json").read_text(encoding="utf-8"))
    require(all(runtime.sha256(HERE / item["path"]) == item["sha256"] for item in manifest["files"]),
            "frozen proposal manifest differs from its source files")
    require(spec["observation_count"] == len(spec["observations"]) == 16, "oracle inventory changed")
    require(len({item["name"] for item in spec["observations"]}) == 16, "duplicate observations")
    expected = (["haskell-" + engine for engine in h_engines] if "haskell" in languages else []) + (
        ["lean-" + cell["name"] for cell in spec["cells"] if cell["engine"] in l_engines]
        if "lean" in languages else [])
    if args.controls_only:
        expected = []
    report = dict(status="running", operation=spec["operation"], scope="finite supplied-fold composition",
                  languages=languages, haskell_engines=h_engines, lean_engines=l_engines,
                  controls_only=args.controls_only, expected_cells=expected, limits=spec["limits"],
                  source_hashes=hashes(sources()), executables={}, generated_inputs={},
                  preflight=[], results=[], processes=[])
    # One process owner and one chronological process inventory. Limits change
    # only by phase: existing GHC replay60 / existing live+Lean180 guards.
    processes = runtime.Processes(output, 180)
    receipt = output / "results.json"
    env = dict(os.environ, djex_datadir=str(DJEX), PYTHONIOENCODING="utf-8")
    # These cells do not own any previously configured trace output path.
    for key in ("LEANT_BACKEND_TRACE", "LEANT_BACKEND_TRACE_REQUESTS"):
        env.pop(key, None)

    def save():
        report["processes"] = processes.rows
        runtime.write_json(receipt, report)

    def pin_input(path):
        report["generated_inputs"][str(path.resolve())] = runtime.sha256(path)

    def run(label, command, *, cwd, guard=180, source=None, child_env=None, check=True):
        processes.timeout = guard
        result = processes.run(label, command, cwd=cwd, source=source, env=child_env or env)
        if check:
            require(result.returncode == 0, label + " exited " + str(result.returncode))
        return result

    def stage(collection, name, action):
        row = dict(name=name, status="running")
        collection.append(row)
        save()
        try:
            action(row)
            row["status"] = "passed"
        except Exception as failure:
            row.update(status="failed", failure_type=type(failure).__name__, failure=str(failure))
        finally:
            save()
        return row["status"] == "passed"

    def lean_kernel(label, path, declarations):
        pin_input(path)
        result = run(label, [kernel, path.resolve()], cwd=LEANT)
        transcript = result.stdout + result.stderr
        inventories = {name: existing.reported_axioms(transcript, name) for name in declarations}
        require(all(value == set() for value in inventories.values()), "missing/duplicate/nonempty kernel inventory")
        return dict(source_path=str(path.resolve()), source_sha256=runtime.sha256(path),
                    axiom_inventories={name: sorted(value) for name, value in inventories.items()}), transcript

    try:
        if "haskell" in languages:
            ghc, runghc, cabal = map(executable, (args.ghc, args.runghc, args.cabal))
            report["executables"].update(hashes([ghc, runghc, cabal]))
        if "lean" in languages:
            kernel = executable(args.kernel)
            report["executables"].update(hashes([kernel]))
            if not args.controls_only:
                leant = executable(args.leant)
                report["executables"].update(hashes([leant]))

        def haskell_controls(row):
            result = run("haskell-oracle-controls", [runghc, "-i" + str(HERE), HERE / "CheckControls.hs"],
                         cwd=HERE, guard=60)
            observed = re.findall(r'\("([a-z_]+)",(True|False)\)', result.stdout)
            required = [(control["name"], "True") for control in spec["controls"]]
            require(observed == required, "GHC did not confirm the exact positive/wrong-control inventory")
            row.update(controls=[name for name, _ in observed], count=len(observed),
                       full_type=spec["haskell_type"], source_paths=[str(HERE / name) for name in
                       ("CheckControls.hs", "TreeAccumulatorControls.hs", "TreeAccumulatorProviders.hs")])

        def lean_controls(row):
            version = run("lean-version", [kernel, "--version"], cwd=LEANT)
            require(re.search(r"Lean \(version 4\.32\.0(?:[, )])", version.stdout + version.stderr),
                    "kernel is not the prepared Lean4.32.0 toolchain")
            names = ["TreeAccumulatorFixture.foldTree"] + [
                "TreeAccumulatorControls." + control["name"] + suffix
                for control in spec["controls"] for suffix in ("", "_checked")]
            checked, _ = lean_kernel("lean-oracle-controls", HERE / "TreeAccumulatorControls.lean", names)
            row.update(kernel=checked, controls=[item["name"] for item in spec["controls"]], count=len(spec["controls"]))

        h_ready = "haskell" in languages and stage(report["preflight"], "haskell-oracle-controls", haskell_controls)
        l_ready = "lean" in languages and stage(report["preflight"], "lean-oracle-controls", lean_controls)
        probe = output / "TreeAccumulatorProbe.exe"
        if "haskell" in languages and not args.controls_only:
            def build_probe(row):
                require(h_ready, "oracle preflight failed; Haskell search disabled")
                located = run("haskell-library-location", [cabal, "exec", "--", sys.executable,
                    "-B", HERE / "locate_library.py"], cwd=BUILD_PROJECT)
                directories = [Path(token.strip('"')) for token in shlex.split(located.stdout, posix=False)]
                report["library_inputs"] = hashes(library_inputs(directories))
                objects = output / "probe-objects"
                objects.mkdir()
                run("haskell-probe-compile", [cabal, "exec", "--", ghc, "--make", "-O0", "-Wall", "-Werror",
                    "-i", "-outputdir", objects, HERE / "TreeAccumulatorProbe.hs", "-o", probe,
                    "-package", "djex"], cwd=BUILD_PROJECT)
                report["executables"].update(hashes([probe]))
                row["executable"] = str(probe)
            h_ready = stage(report["preflight"], "haskell-probe-build", build_probe) and h_ready

        def haskell_cell(engine, row):
            require(h_ready, "oracle/probe preflight failed; no Haskell candidate search attempted")
            work = output / ("haskell-" + engine)
            work.mkdir()
            row["stage"] = "bounded_public_facade_search"
            searched = run("haskell-" + engine + "-search", [probe, engine, work], cwd=DJEX, check=False)
            path = work / "candidates.json"
            pin_input(path)
            data = json.loads(path.read_text(encoding="utf-8"))
            row["producer"] = data
            require(searched.returncode == 0 and data.get("status") == "checked", "probe reported a source-graph/erasure/renderer failure")
            require(data["engine"] == engine and data["full_signature"] == spec["haskell_type"], "probe goal/engine mismatch")
            require(data["settings"] == dict(raw_limit=1024, djinn_choice_budget=100000,
                    exference_steps=100000, exference_queue=1024, allow_unused=True, djinn_strategy="interleave"),
                    "probe changed original engine limits")
            candidates = data["candidates"]
            require(data.get("observed_count") == len(candidates) and data.get("behavior_evaluated") is False,
                    "probe did not retain exact raw observations separately from behavior")
            require(isinstance(data.get("actual_inventory"), list) and len(data["actual_inventory"]) == 2,
                    "probe did not retain the exact prepared source inventory")
            require(0 < len(candidates) <= 1024, "no candidates or raw window exceeded")
            require([item["ordinal"] for item in candidates] == list(range(len(candidates))), "missing/duplicate/reordered raw candidate identity")
            require(all(isinstance(item["term"], str) and item["term"] and isinstance(item["uses_fold"], bool)
                        and item.get("graph") and item.get("compatibility") and item.get("failure") is None
                        for item in candidates), "missing exact candidate evidence")
            # The independent GHC process compiles every exact candidate at the
            # entire original type. No candidate is inferred from the witness.
            lines = ["{-# LANGUAGE RankNTypes, ImpredicativeTypes, ScopedTypeVariables, TypeApplications #-}",
                     "module Main where", "import TreeAccumulatorProviders (Tree(..), foldTree)",
                     "import TreeAccumulatorControls (observations)"]
            for item in candidates:
                name = "candidate_" + str(item["ordinal"])
                lines += [name + " :: " + spec["haskell_type"], name + " = " + item["term"], ""]
            pairs = [f'({item["ordinal"]}, {str(item["uses_fold"])} && all snd (observations candidate_{item["ordinal"]}))' for item in candidates]
            false_pairs = []
            for item in candidates:
                call = f'candidate_{item["ordinal"]} (\\(_state :: Bool) value -> value) False (Leaf True)'
                false_pairs.append(f'({item["ordinal"]}, ({call} == True) && ({call} /= True))')
            lines += ["positiveResults :: [(Int, Bool)]", "positiveResults = [" + ",".join(pairs) + "]",
                      "falseResults :: [(Int, Bool)]", "falseResults = [" + ",".join(false_pairs) + "]",
                      "main :: IO ()", "main = putStrLn $ \"{\\\"accepted\\\":\" ++ show [i | (i, True) <- positiveResults]",
                      "  ++ \",\\\"false_passed_indices\\\":\" ++ show [i | (i, True) <- falseResults]",
                      "  ++ \",\\\"false_observation_count\\\":\" ++ show (length falseResults) ++ \"}\"", ""]
            replay = work / "ExactCandidates.hs"
            replay.write_text("\n".join(lines), encoding="utf-8", newline="\n")
            pin_input(replay)
            row["stage"] = "independent_full_type_ghc_and_actual_false"
            checked = run("haskell-" + engine + "-exact-ghc", [runghc, "-i" + str(HERE), replay], cwd=HERE, guard=60)
            verdict = json.loads(checked.stdout)
            row["ghc_verdict"] = verdict
            require(verdict["false_observation_count"] == len(candidates) and verdict["false_passed_indices"] == [],
                    "contradictory False control did not actually reject every bounded candidate")
            row["actual_false_observations"] = verdict["false_observation_count"]
            accepted = verdict["accepted"]
            require(isinstance(accepted, list) and len(accepted) == len(set(accepted))
                    and all(type(index) is int and 0 <= index < len(candidates) and candidates[index]["uses_fold"] for index in accepted),
                    "invalid independent accepted candidate indices")
            row["accepted"] = [candidates[index] for index in accepted]
            require(accepted, "bounded source-checked candidate pool completed with no matching full-type implementation")
            row["stage"] = "completed"

        def lean_cell(cell, row):
            require(l_ready, "oracle/termination preflight failed; no Lean synthesis attempted")
            source_path = HERE / cell["path"]
            source = source_path.read_text(encoding="utf-8")
            require(runtime.sha256(source_path) == cell["sha256"], "prepared Lean command changed")
            query = [line for line in source.splitlines() if line.startswith(":synth ")]
            require(len(query) == 1, "expected one command in fresh process")
            case = dict(cell, expected="no_candidate" if cell["expected"] == "actual_false" else "candidate",
                        command=query[0], predicate="False" if cell["expected"] == "actual_false" else spec["lean_predicate"].format(f=cell["name"]))
            require(query[0] == ":synth " + cell["name"] + " : " + cell["type"] + " where " + case["predicate"],
                    "live command differs from the exact replay type/predicate")
            row["stage"] = "live_named_behavior"
            result = run("lean-" + cell["name"] + "-live", [leant, "--plain"], cwd=LEANT, source=source,
                         child_env=dict(env, LEANT_SYNTH_TIMEOUT="90"))
            transcript = result.stdout + result.stderr
            row["provider_debug_lines"] = re.findall(r"(?m)^debug provider: (.+)$", transcript)
            existing.validate_settings(transcript, source)
            provider_rows = []
            for raw in row["provider_debug_lines"]:
                names = re.findall(r'providerLeanName = ("(?:[^"\\]|\\.)*")', raw)
                require(len(names) == 1, "malformed source provider row")
                provider_rows.append(dict(name=json.loads(names[0]), declaration=raw))
            names = [item["name"] for item in provider_rows]
            allowed = {"TreeAccumulatorFixture.foldTree", "TreeAccumulatorFixture.Tree.leaf", "TreeAccumulatorFixture.Tree.branch"}
            require(len(names) == len(set(names)) and set(names) <= allowed, "provider inventory acquired an unrelated value")
            require("provider inventory unavailable:" not in transcript, "provider inventory unavailable")
            row["provider_inventory"] = provider_rows
            require_completed_live_query(transcript)
            parsed = existing.parse_output(transcript, [case])[0]
            row["synthesis"] = parsed
            if case["expected"] == "no_candidate":
                row["stage"] = "completed_actual_false"
                return
            term = parsed["candidate"]
            require("TreeAccumulatorFixture.foldTree" in names, "required full generic fold was not discovered")
            require(not re.search(r"\b(?:TreeAccumulatorControls|TreeAccumulatorReplay)\.|\b(?:sorry|admit|unsafe|axiom|native_decide)\b", term),
                    "oracle or unchecked implementation leaked into accepted text")
            raw_observations = re.findall(r"(?m)^debug accepted-candidate: (.+)$", transcript)
            require(len(raw_observations) == 1, "missing/duplicate exact accepted source observation")
            observation = json.loads(raw_observations[0])
            origin = observation.get("origin") or {}
            graph = origin.get("graph") or {}
            rendering = origin.get("rendering") or {}
            require(observation.get("schema") == 1 and observation.get("label") == "it1" and observation.get("term") == term
                    and observation.get("route") == "RouteTypedCandidate"
                    and origin.get("engine") in ({"djinn", "exference"} if cell["engine"] == "both" else {cell["engine"]})
                    and rendering.get("term") == term and rendering.get("matches_verified_text") is True
                    and graph.get("erasure_matches_compatibility") is True and graph.get("root_type")
                    and graph.get("node_count", 0) > 0 and graph.get("context_introductions") == []
                    and graph.get("context_applications") == [], "accepted candidate lost its own checked graph/renderer/full root evidence")
            row["accepted_observation"] = observation
            source = (HERE / "LeanCandidateReplay.lean.in").read_text(encoding="utf-8")
            require(source.count("__EXACT_SYNTHESIZED_TERM__") == 1, "replay insertion marker changed")
            source = "import Lean\n" + source.replace("__EXACT_SYNTHESIZED_TERM__", term)
            source += '''\nrun_cmd do
  let info ← Lean.getConstInfo `TreeAccumulatorReplay.candidate
  let some value := info.value? | throwError "candidate has no inspectable implementation"
  let record := Lean.Json.mkObj [
    ("declaration", Lean.toJson "TreeAccumulatorReplay.candidate"),
    ("type_constants", Lean.toJson (info.type.getUsedConstants.map Lean.Name.toString)),
    ("value_constants", Lean.toJson (value.getUsedConstants.map Lean.Name.toString))]
  Lean.logInfo ("TREE_ACCUMULATOR_CONSTANTS " ++ record.compress)
'''
            replay = output / ("lean-" + cell["name"] + ".lean")
            replay.write_text(source, encoding="utf-8", newline="\n")
            row["stage"] = "independent_full_type_kernel"
            checked, stdout = lean_kernel("lean-" + cell["name"] + "-kernel", replay,
                ["TreeAccumulatorFixture.foldTree", "TreeAccumulatorReplay.candidate", "TreeAccumulatorReplay.candidate_passes"])
            row["kernel_replay"] = checked
            records = re.findall(r"TREE_ACCUMULATOR_CONSTANTS ([^\r\n]+)", stdout)
            require(len(records) == 1, "missing/duplicate direct implementation inventory")
            constants = json.loads(records[0])
            require(constants.get("declaration") == "TreeAccumulatorReplay.candidate", "wrong constant inventory owner")
            for key in ("type_constants", "value_constants"):
                values = constants.get(key)
                require(isinstance(values, list) and all(isinstance(x, str) for x in values)
                        and len(values) == len(set(values)), "malformed direct constant inventory")
            tree_name = "TreeAccumulatorFixture.Tree"
            allowed_constants = allowed | {tree_name, tree_name + ".casesOn", tree_name + ".rec"}
            require(set(constants["type_constants"]) == {tree_name}
                    and set(constants["value_constants"]) <= allowed_constants
                    and "TreeAccumulatorFixture.foldTree" in constants["value_constants"],
                    "candidate acquired a non-source provider or did not actually use foldTree")
            row.update(implementation_constants=constants, stage="completed")

        if not args.controls_only:
            if "haskell" in languages:
                for engine in h_engines:
                    stage(report["results"], "haskell-" + engine, lambda row, e=engine: haskell_cell(e, row))
            if "lean" in languages:
                for cell in spec["cells"]:
                    if cell["engine"] in l_engines:
                        stage(report["results"], "lean-" + cell["name"], lambda row, c=cell: lean_cell(c, row))
        require([row["name"] for row in report["results"]] == expected, "completed cell inventory differs from prepared selection")
        report["status"] = "passed" if all(row["status"] == "passed" for row in report["preflight"] + report["results"]) else "failed"
    except Exception as failure:
        report.update(status="failed", failure_type=type(failure).__name__, failure=str(failure))
    finally:
        report["source_integrity"] = unchanged(report["source_hashes"])
        report["executable_integrity"] = unchanged(report["executables"])
        report["input_integrity"] = unchanged(report["generated_inputs"])
        report["library_integrity"] = unchanged(report.get("library_inputs", {}))
        process_files = {row[field + "_path"]: row[field + "_sha256"]
                         for row in processes.rows for field in ("input", "stdout", "stderr")
                         if field + "_path" in row and field + "_sha256" in row}
        report["process_capture_integrity"] = unchanged(process_files)
        if not all(report[key] for key in ("source_integrity", "executable_integrity", "input_integrity", "library_integrity", "process_capture_integrity")):
            report.update(status="failed", integrity_failure="source/executable/library/input/capture changed")
        if report["status"] == "running":
            report.update(status="interrupted", failure="prepared acceptance inventory did not complete")
        report["accepted_cells"] = [row["name"] for row in report["results"] if row["status"] == "passed"]
        report["accepted_positive_cells"] = [row["name"] for row in report["results"]
            if row["status"] == "passed" and (row.get("accepted") or row.get("synthesis", {}).get("status") == "candidate")]
        report["lean_actual_false_cells"] = [row["name"] for row in report["results"]
            if row["status"] == "passed" and row.get("synthesis", {}).get("status") == "no_candidate"]
        report["haskell_actual_false_observations"] = {row["name"]: row["actual_false_observations"]
            for row in report["results"] if "actual_false_observations" in row}
        save()
    print("Tree accumulator: " + report["status"], flush=True)
    return 0 if report["status"] == "passed" else 1


if __name__ == "__main__":
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, "reconfigure"):
            stream.reconfigure(encoding="utf-8")
    raise SystemExit(main())
