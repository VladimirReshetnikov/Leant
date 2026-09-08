"""Read Djex library directories from the active Cabal execution environment."""
import os
from pathlib import Path
import subprocess


def main():
    environment = Path(os.environ["GHC_ENVIRONMENT"])
    lines = environment.read_text(encoding="utf-8").splitlines()
    databases = [line.removeprefix("package-db ") for line in lines
                 if line.startswith("package-db ")]
    if not databases:
        raise ValueError("Cabal execution environment has no package databases")
    command = ["ghc-pkg", "--no-user-package-db"]
    command.extend("--package-db=" + str((environment.parent / path).resolve())
                   for path in databases)
    command.extend(["field", "djex", "library-dirs", "--simple-output"])
    raise SystemExit(subprocess.run(command, check=False).returncode)


if __name__ == "__main__":
    main()
