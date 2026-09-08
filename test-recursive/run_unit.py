#!/usr/bin/env python3
"""Capture the complete Leant boundary inventory and run that unfiltered suite.

Both the inventory query and the suite run use the shared owned-process-tree
runner. Acceptance requires
the actual inventory, the expected post-build count, and the passing summary to
agree, with unchanged sources, test executable, and fake-Z3 helper.
"""
from __future__ import annotations

import argparse
import os
from pathlib import Path
import re
import shutil
import sys

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "lib/Djex/test-church"))
import behavior_runtime as runtime


def positive_integer(value):
    parsed = int(value)
    if parsed <= 0:
        raise argparse.ArgumentTypeError("must be positive")
    return parsed


def source_inventory():
    # Include the whole relevant Haskell source directories so that a new
    # shared helper cannot silently fall outside the provenance boundary.
    directories = [
        "src", "test-unit", "lib/Djex/src", "lib/Djex/djinn/src-core",
        "lib/Djex/djinn/src-internal", "lib/Djex/exference/src-core",
        "lib/Djex/synthesis/src", "lib/Djex/synthesis/internal",
        "lib/Djex/test-support/fake-z3",
    ]
    paths = {
        Path(__file__).resolve(), ROOT / "leant.cabal", ROOT / "cabal.project",
        ROOT / "lib/Djex/djex.cabal",
        ROOT / "lib/Djex/test-church/behavior_runtime.py",
        ROOT / "lib/Djex/test-church/behavior_spec.py",
    }
    for relative in directories:
        directory = ROOT / relative
        if not directory.is_dir():
            raise FileNotFoundError("required source directory is missing: " + str(directory))
        paths.update(directory.rglob("*.hs"))
    return sorted(paths, key=lambda path: str(path).casefold())


def snapshot(paths):
    return {str(path.resolve()): runtime.sha256(path) for path in paths}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--expected-count", type=positive_integer, default=647,
                        help="expected post-build full-suite count (default: 647)")
    parser.add_argument("--timeout", type=positive_integer, default=1200,
                        help="owned full-suite process-tree guard, in seconds")
    parser.add_argument("--inventory-timeout", type=positive_integer, default=30)
    parser.add_argument("--test-exe", type=Path, default=ROOT /
        "dist-newstyle/build/x86_64-windows/ghc-9.12.4/leant-0.1.0/t/leant-synth-tests/build/leant-synth-tests/leant-synth-tests.exe")
    parser.add_argument("--fake-z3", type=Path, default=ROOT /
        "dist-newstyle/build/x86_64-windows/ghc-9.12.4/djex-2026.7.17/x/djex-fake-z3/build/djex-fake-z3/djex-fake-z3.exe")
    args = parser.parse_args()
    output = runtime.prepare_output_directory(args.output).resolve()
    executable = args.test_exe.resolve()
    helper = args.fake_z3.resolve()
    report = {
        "status": "running", "scope": "complete unfiltered Leant synthesis boundary suite",
        "expected_count": args.expected_count, "test_executable": str(executable),
        "fake_z3_executable": str(helper), "test_threads": 1,
    }
    runtime.write_json(output / "results.json", report)
    processes = runtime.Processes(output, args.inventory_timeout)
    sources = []
    artifacts = [executable, helper]
    try:
        for artifact in artifacts:
            if not artifact.is_file():
                raise FileNotFoundError("required built executable is missing: " + str(artifact))
        sources = source_inventory()
        report["source_hashes_before"] = snapshot(sources)
        report["executable_hashes_before"] = snapshot(artifacts)
        # Tasty's environment options must not restrict either invocation.
        # Store key names only, never arbitrary inherited environment values.
        removed = sorted(key for key in os.environ if key.upper().startswith("TASTY_"))
        environment = {key: value for key, value in os.environ.items() if key not in removed}
        environment["PATH"] = str(helper.parent) + os.pathsep + os.environ.get("PATH", "")
        resolved_helper = shutil.which(helper.name, path=environment["PATH"])
        if resolved_helper is None or Path(resolved_helper).resolve() != helper:
            raise RuntimeError("fake-Z3 lookup does not resolve to the supplied built helper")
        report["removed_tasty_environment_keys"] = removed
        report["fake_z3_path_directory"] = str(helper.parent)
        report["resolved_fake_z3"] = str(Path(resolved_helper).resolve())
        runtime.write_json(output / "results.json", report)

        listed = processes.run("list-tests", [executable, "--list-tests"],
                               cwd=ROOT, env=environment)
        if listed.returncode != 0:
            raise RuntimeError("the actual test executable failed to enumerate its full inventory")
        names = [line for line in listed.stdout.splitlines() if line.strip()]
        if not names or any(not name.startswith("Leant synthesis boundary.") for name in names):
            raise RuntimeError("test enumeration contains missing or unexpected non-test output")
        names_path = output / "test-names.txt"
        names_path.write_text("\n".join(names) + "\n", encoding="utf-8", newline="\n")
        duplicates = sorted(name for name in set(names) if names.count(name) > 1)
        inventory = {
            "count": len(names), "names": names, "duplicate_names": duplicates,
            "names_path": str(names_path), "names_sha256": runtime.sha256(names_path),
            "enumeration_stdout_path": processes.rows[-1]["stdout_path"],
            "enumeration_stdout_sha256": processes.rows[-1]["stdout_sha256"],
        }
        inventory_path = output / "inventory.json"
        runtime.write_json(inventory_path, inventory)
        report.update(inventory_count=len(names), test_names_path=str(names_path),
                      test_names_sha256=inventory["names_sha256"],
                      inventory_path=str(inventory_path), inventory_sha256=runtime.sha256(inventory_path))
        if len(names) != args.expected_count:
            raise RuntimeError(f"full inventory has {len(names)} tests; expected {args.expected_count} after integration build")
        # Prevent a changed/replaced build or source from being accepted even
        # when it occurs between the inventory process and the suite process.
        if snapshot(sources) != report["source_hashes_before"]:
            raise RuntimeError("source files changed during inventory enumeration")
        if snapshot(artifacts) != report["executable_hashes_before"]:
            raise RuntimeError("built test/helper executable changed during inventory enumeration")

        processes.timeout = args.timeout
        checked = processes.run("unit", [executable, "-j1"], cwd=ROOT, env=environment)
        summaries = re.findall(r"^All (\d+) tests passed \(([0-9.]+)s\)\s*$",
                               checked.stdout + "\n" + checked.stderr, flags=re.MULTILINE)
        report["suite_exit_code"] = checked.returncode
        if checked.returncode != 0 or len(summaries) != 1:
            raise RuntimeError("the unfiltered suite did not report exactly one successful complete summary")
        count, seconds = summaries[0]
        report["suite_summary_count"] = int(count)
        report["suite_seconds"] = float(seconds)
        if int(count) != len(names):
            raise RuntimeError("passing summary count differs from the enumerated full test inventory")
        report["status"] = "passed"
    except BaseException as failure:
        report["status"] = "failed"
        report["failure"] = type(failure).__name__ + ": " + str(failure)
    finally:
        try:
            # Re-enumeration of source paths also detects new or removed files.
            after_sources = source_inventory()
            report["source_hashes_after"] = snapshot(after_sources)
            report["sources_unchanged"] = (
                report["source_hashes_after"] == report.get("source_hashes_before"))
            report["executable_hashes_after"] = snapshot(artifacts)
            report["executables_unchanged"] = (
                report["executable_hashes_after"] == report.get("executable_hashes_before"))
            if not report["sources_unchanged"] or not report["executables_unchanged"]:
                report["status"] = "failed"
        except BaseException as failure:
            report["status"] = "failed"
            report["final_provenance_failure"] = type(failure).__name__ + ": " + str(failure)
        report["processes"] = processes.rows
        runtime.write_json(output / "results.json", report)
    print(report["status"], flush=True)
    if report.get("failure"):
        print(report["failure"], flush=True)
    return 0 if report["status"] == "passed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
