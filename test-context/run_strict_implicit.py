"""Strict-implicit source binders through live contextual synthesis and exact replay.

Reuse the constructor/method observations and original 32/20000/45 bounds.
Only type-binder visibility changes. Reference definitions remain in separate
kernel oracle modules, and the actual source packet must come from Lean.
"""
from pathlib import Path
import re
import sys

import run_constructors as constructors


original_specifications = constructors.specifications
original_validate = constructors.validate
original_inventory = constructors.parser.source_inventory


def specifications():
    rows = []
    for operation, source, predicate, reference, providers in original_specifications():
        if operation not in {"method", "argument", "nested_context"}:
            continue
        # These are the actual Type-0 source telescopes of the existing cases;
        # term parameters, observations and source-selected dictionaries stay.
        strict = lambda text: re.sub(r"\((α(?: β)?|β) : Type\)", r"⦃\1 : Type⦄", text)
        rows.append((operation, strict(source), predicate, strict(reference), providers))
    return rows


def validate(output, source, case):
    result = original_validate(output, source, case)
    if result["status"] == "candidate":
        expected = sum(len(group.split()) for group in re.findall(r"⦃([^:]+) : Type⦄", case["type"]))
        actual = len(re.findall(r"fun ⦃[^⦄]+⦄ =>", result["candidate"]))
        if expected == 0 or actual != expected:
            raise ValueError(f"displayed strict-implicit introductions changed: expected {expected}, got {actual}")
        result["strict_implicit_introductions"] = actual
    return result


def main():
    constructors.__doc__ = __doc__
    constructors.specifications = specifications
    constructors.validate = validate
    constructors.parser.source_inventory = lambda: [*original_inventory(), Path(__file__).resolve()]
    return constructors.main()


if __name__ == "__main__":
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, "reconfigure"):
            stream.reconfigure(encoding="utf-8")
    raise SystemExit(main())
