"""Apply the tree deadline contract to immutable captured fixture results.

This is a transcript audit, not a synthesis rerun. Original receipts are never
rewritten; every inspected stdout and stderr capture must match its recorded hash.
"""
from pathlib import Path
import argparse
import json
import re

from run_acceptance import require_completed_live_query, runtime


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--receipt", type=Path, action="append", required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    output = runtime.prepare_output_directory(args.output.resolve())
    report = dict(status="passed", scope="hash-checked transcript audit; no live synthesis rerun", audits=[])
    try:
        for receipt in args.receipt:
            receipt = receipt.resolve()
            data = json.loads(receipt.read_text(encoding="utf-8"))
            source_hash = runtime.sha256(receipt)
            audit = dict(receipt=str(receipt), receipt_sha256=source_hash, cells=[])
            report["audits"].append(audit)
            processes = {row["label"]: row for row in data["processes"]}
            for row in data["results"]:
                if not row["name"].startswith("lean-"):
                    continue
                process = processes.get(row["name"] + "-live")
                if process is None:
                    raise ValueError("missing live process for " + row["name"])
                captures = []
                for channel in ("stdout", "stderr"):
                    path = Path(process[channel + "_path"])
                    if runtime.sha256(path) != process[channel + "_sha256"]:
                        raise ValueError("capture hash changed: " + str(path))
                    captures.append(path.read_text(encoding="utf-8"))
                transcript = "".join(captures)
                deadline = True
                try:
                    require_completed_live_query(transcript)
                except TimeoutError:
                    deadline = False
                finished = process["status"] == "completed" and process["exit_code"] == 0 and not process["timed_out"]
                counts = re.findall(r"supplied behavioral assertion: (\d+) passed, (\d+) falsified, (\d+) inconclusive", transcript)
                audited = dict(name=row["name"], original_status=row["status"],
                               command_deadline_passed=deadline, process_completed=finished,
                               status=row["status"] if deadline and finished else "failed",
                               counts=[list(map(int, values)) for values in counts],
                               stdout_sha256=process["stdout_sha256"], stderr_sha256=process["stderr_sha256"])
                if not deadline:
                    audited["failure"] = "synthesis command exceeded its prepared deadline"
                audit["cells"].append(audited)
            audit["accepted_cells"] = [row["name"] for row in audit["cells"] if row["status"] == "passed"]
            if runtime.sha256(receipt) != source_hash:
                raise ValueError("original receipt changed during audit")
    except Exception as failure:
        report.update(status="failed", failure_type=type(failure).__name__, failure=str(failure))
    runtime.write_json(output / "results.json", report)
    print(json.dumps(report))
    return 0 if report["status"] == "passed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
