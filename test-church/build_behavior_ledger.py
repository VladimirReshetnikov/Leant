"""Regenerate Leant's shared behavior ledger using a specified Djex checkout."""
import argparse
from pathlib import Path
import subprocess
import sys


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--djex-root", type=Path, required=True,
                        help="Djex checkout containing test-church/behavior_ledger.py")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    directory = Path(__file__).resolve().parent
    root = args.djex_root.resolve()
    script = root / "test-church/behavior_ledger.py"
    if not script.is_file():
        parser.error("the specified Djex checkout does not contain the ledger generator")
    command = [sys.executable, "-B", str(script), "--djex-root", str(root),
               "--leant-root", str(directory.parent), "--output", str(directory)]
    if args.check:
        command.append("--check")
    return subprocess.call(command)


if __name__ == "__main__":
    raise SystemExit(main())
