#!/usr/bin/env python3
"""Check isolated lexical-Given rendering and replay exact emitted Lean terms.

This exercises the direct renderer with sealed graph fixtures. It makes no
claim that live synthesis prepares the metadata or routes through this module.
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
from run_corpus import reported_axioms

CANDIDATES = [
    "contextChooseFirst", "contextChooseSecond", "contextChooseOuter",
    "contextRankN", "contextNested", "contextProvider", "contextAlias",
]
OBSERVATIONS = [
    "contextFirstPayload", "contextSecondPayload", "contextOuterPayload",
    "contextRankNPayload", "contextNestedPayload", "contextProviderPayload",
    "contextAliasPayload", "contextFirstWrong", "contextSecondWrong",
]


def source_inventory():
    paths = {Path(__file__).resolve(), ROOT / "leant.cabal", ROOT / "cabal.project",
             ROOT / "test-church/run_corpus.py",
             ROOT / "lib/Djex/test-church/behavior_runtime.py", ROOT / "lib/Djex/djex.cabal"}
    for directory in ["src", "test-unit", "lib/Djex/src", "lib/Djex/synthesis/src",
                      "lib/Djex/synthesis/internal", "lib/Djex/djinn/src-core",
                      "lib/Djex/djinn/src-internal", "lib/Djex/exference/src-core"]:
        paths.update((ROOT / directory).rglob("*.hs"))
    return sorted(paths)


def hashes(paths):
    return {str(path.relative_to(ROOT)): runtime.sha256(path) for path in paths}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--test-exe", type=Path, default=ROOT /
        "dist-newstyle/build/x86_64-windows/ghc-9.12.4/leant-0.1.0/t/leant-synth-tests/build/leant-synth-tests/leant-synth-tests.exe")
    parser.add_argument("--lean", default="lean")
    parser.add_argument("--toolchain", default="leanprover/lean4:v4.32.0")
    args = parser.parse_args()
    output = runtime.prepare_output_directory(args.output).resolve()
    executable = args.test_exe.resolve()
    sources = source_inventory()
    before = hashes(sources)
    digest = runtime.sha256(executable)
    report = dict(status="running", scope="isolated checked-graph renderer; no live synthesis routing",
                  source_hashes_before=before, executable=str(executable), executable_sha256=digest,
                  expected_unit_count=21, expected_candidate_count=7,
                  expected_payload_observations=7, expected_wrong_result_controls=2)
    # Retain exact input bytes, including uncommitted source, for review.
    for path in sources:
        saved = output / "source" / path.relative_to(ROOT)
        saved.parent.mkdir(parents=True, exist_ok=True)
        saved.write_bytes(path.read_bytes())
    runtime.write_json(output / "results.json", report)
    processes = runtime.Processes(output, 120)
    environment = {key: value for key, value in os.environ.items()
                   if not key.upper().startswith("TASTY_")}
    try:
        unit = processes.run("renderer-unit", [executable, "-j1", "-p",
            "/direct Lean lexical context rendering/"], cwd=ROOT, env=environment)
        summaries = re.findall(r"^All (\d+) tests passed \(([0-9.]+)s\)\s*$",
                               unit.stdout + "\n" + unit.stderr, re.MULTILINE)
        if unit.returncode or len(summaries) != 1 or summaries[0][0] != "21":
            raise ValueError("the complete 21-test renderer group did not pass")
        report.update(unit_count=21, unit_seconds=float(summaries[0][1]))
        emitted = processes.run("emit-lean", [executable, "--emit-context-replay"],
                                cwd=ROOT, env=environment)
        if emitted.returncode or not emitted.stdout.startswith("set_option autoImplicit false"):
            raise ValueError("the test executable did not emit the complete replay source")
        source = emitted.stdout + "\n" + "\n".join("#print axioms " + name for name in CANDIDATES) + "\n"
        if re.search(r"\b(?:sorry|axiom|unsafe)\b", source):
            raise ValueError("replay source contains a proof escape")
        path = output / "ContextReplay.lean"
        path.write_text(source, encoding="utf-8", newline="\n")
        report.update(replay_source=str(path), replay_source_sha256=runtime.sha256(path))
        replay = processes.run("kernel-replay", [args.lean, "+" + args.toolchain, path], cwd=ROOT)
        inventories = {name: reported_axioms(replay.stdout + replay.stderr, name)
                       for name in CANDIDATES + OBSERVATIONS}
        report["axiom_inventories"] = {name: None if value is None else sorted(value)
                                       for name, value in inventories.items()}
        if replay.returncode or any(value != set() for value in inventories.values()):
            raise ValueError("independent Lean replay failed or lacked an empty axiom inventory")
        report.update(status="passed", candidate_count=7, payload_observations=7,
                      wrong_result_controls=2, axiom_inventory_count=len(inventories))
    except BaseException as failure:
        report.update(status="failed", failure=type(failure).__name__ + ": " + str(failure))
    finally:
        report["source_hashes_after"] = hashes(source_inventory())
        report["sources_unchanged"] = report["source_hashes_after"] == before
        report["executable_unchanged"] = runtime.sha256(executable) == digest
        if not report["sources_unchanged"] or not report["executable_unchanged"]:
            report.update(status="failed", provenance_failure="source or executable changed during replay")
        report["processes"] = processes.rows
        runtime.write_json(output / "results.json", report)
    print("Lexical context replay: " + report["status"], flush=True)
    if report.get("failure"):
        print(report["failure"], flush=True)
    return 0 if report["status"] == "passed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
