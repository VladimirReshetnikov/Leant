"""Check both production discovery modes against real Lean auxiliary metadata."""
from pathlib import Path
import argparse
import json
import os
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "lib/Djex/test-church"))
import behavior_runtime as runtime


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--lean-runtime", type=Path, default=Path(
        os.environ.get("ELAN_HOME", str(Path.home() / ".elan"))) /
        "toolchains/leanprover--lean4---v4.32.0/bin/lean.exe")
    args = parser.parse_args()
    output = runtime.prepare_output_directory(args.output.resolve())
    kernel = args.lean_runtime.resolve()
    paths = [Path(__file__).resolve(), Path(runtime.__file__).resolve(), kernel,
             ROOT / "test-context/ProviderInventoryProbe.hs", ROOT / "leant.cabal",
             ROOT / "cabal.project"]
    paths.extend((ROOT / "src").rglob("*.hs"))
    snapshot = lambda: {str(p): runtime.sha256(p) for p in paths}
    report = dict(status="running", scope="production ordinary/contextual provider inventory, roots and explicit sessions",
                  before=snapshot(), cells=[], processes=[])
    receipt = output / "results.json"
    processes = runtime.Processes(output, 180)
    runtime.write_json(receipt, report)

    def run(label, command):
        result = processes.run(label, command, cwd=ROOT)
        if result.returncode != 0:
            raise ValueError(label + " failed: " + str(result.returncode))
        return result

    try:
        helper = output / "ProviderInventoryProbe.exe"
        objects = output / "objects"
        objects.mkdir()
        run("build", ["cabal", "exec", "--", "ghc", "--make", "-O0", "-Wall", "-Werror",
                      "-package", "djex", "-isrc", "-outputdir", objects,
                      ROOT / "test-context/ProviderInventoryProbe.hs", "-o", helper])
        helper_hash = runtime.sha256(helper)
        for mode in ("ordinary", "contextual"):
            for selection in ("roots", "sessions"):
                name = mode + "-" + selection
                row = dict(name=name, status="running")
                report["cells"].append(row)
                runtime.write_json(receipt, report)
                emitted = run(name + "-emit", [helper, "emit", mode, selection])
                source = output / (name + ".lean")
                source.write_bytes(Path(processes.rows[-1]["stdout_path"]).read_bytes())
                if not emitted.stdout.startswith("import Lean\n"):
                    raise ValueError("helper did not emit the production prelude")
                checked = run(name + "-kernel", [kernel, source])
                inventories = [line for line in checked.stdout.splitlines() if line.startswith("(providers")]
                if len(inventories) != 1:
                    raise ValueError("expected one complete production inventory")
                inventory = output / (name + ".sexp")
                inventory.write_text(inventories[0], encoding="utf-8")
                run(name + "-parse", [helper, "check", inventory])
                row.update(status="passed", source=str(source), source_sha256=runtime.sha256(source),
                           inventory=str(inventory), inventory_sha256=runtime.sha256(inventory))
                runtime.write_json(receipt, report)
        if runtime.sha256(helper) != helper_hash:
            raise ValueError("compiled production helper changed during the run")
        report.update(status="passed", helper_sha256=helper_hash)
    except Exception as failure:
        report.update(status="failed", failure_type=type(failure).__name__, failure=str(failure))
    finally:
        report.update(after=snapshot(), processes=processes.rows)
        report["unchanged"] = report["before"] == report["after"]
        if not report["unchanged"]:
            report["status"] = "failed"
        runtime.write_json(receipt, report)
    print(json.dumps({k: report[k] for k in ("status", "unchanged", "cells")}))
    return 0 if report["status"] == "passed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
