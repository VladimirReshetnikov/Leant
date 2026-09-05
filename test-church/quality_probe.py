#!/usr/bin/env python3
"""Compare bounded ranking policies and kernel-replay every exact displayed term.

This is a focused quality regression, not a semantic specification of Church
operations. The projection check has its own explicit, executable specification.
Search settings are identical across policies. --steps controls Exference only;
the configured synthesis timeout excludes startup and standalone kernel replay.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import unittest

from run_corpus import reported_axioms, validate_settings

ROOT = Path(__file__).resolve().parents[1]
POLICIES = ("legacy", "balanced", "compact", "diverse")
ENVIRONMENT = [
    "axiom Quality.Token : Type",
    "axiom Quality.cheap : Unit → Quality.Token",
    "axiom Quality.expensive : Quality.Token",
]
CASES = [
    ("projection", "(∀ A : Type, A → A → A)"),
    ("nil", "(∀ A R : Type, (A → R → R) → R → R)"),
    ("tuple", "(∀ A B : Type, A → B → A × B)"),
    ("repeat", "(∀ A : Type, A → A × A)"),
    ("impredicative", "(∀ F : Type 1 → Type 1, (∀ A : Type 1, A → F A) → F (∀ B : Type, B → B))"),
    ("ambient", "(∀ (X : Type) (F : Type 1 → Type 1), (∀ A : Type 1, A → F A) → F (∀ B : Type, X → B → B))"),
    ("provider", "Quality.Token"),
]


def parse_many(output, cases, shown):
    """Preserve complete numbered term blocks; reject missing/extra queries."""
    chunks = re.split(r"(?m)^λ> :synth ", output)[1:]
    if len(chunks) != len(cases):
        raise ValueError("synthesis query count differs from requested transcript")
    results = []
    for case, tail in zip(cases, chunks):
        chunk = tail.split("\nλ> ", 1)[0]
        if chunk.splitlines()[0].strip() != case["type"]:
            raise ValueError("synthesis query type/order mismatch")
        matches = list(re.finditer(r"(?m)^[ \t]+it([0-9]+)[ \t]+(.+)$", chunk))
        labels = [int(match.group(1)) for match in matches]
        if labels != list(range(1, len(labels) + 1)) or len(labels) > shown:
            raise ValueError(f"unexpected candidate labels: {labels}")
        terms = []
        for index, match in enumerate(matches):
            end = matches[index + 1].start() if index + 1 < len(matches) else len(chunk)
            body = re.split(r"(?m)^(?:note:|debug )", chunk[match.start(2):end], maxsplit=1)[0].strip()
            if not body or re.search(r"\b(?:sorry|admit|unsafe|axiom)\b", body):
                raise ValueError("unchecked or empty displayed candidate")
            terms.append(body)
        results.append({**case, "terms": terms, "output": chunk})
    return results


def make_commands(args):
    lines = [*ENVIRONMENT, ":set synth-library off", ":set synth-classical off",
             ":set synth-providers off", f":set synth-window {args.window}",
             f":set synth-verify {args.window}", f":set synth-shown {args.shown}",
             f":set synth-timeout {args.timeout}", f":set synth-steps {args.steps}",
             f":set synth-budget {args.budget}"]
    cases = []
    for engine in args.engine or ["djinn", "exference"]:
        lines.append(f":set synth-engine {engine}")
        for policy in args.policy or POLICIES:
            lines.append(f":set synth-ranking {policy}")
            for name, target in CASES:
                if args.case and name not in args.case:
                    continue
                lines.append(":set synth-providers " + ("on" if name == "provider" else "off"))
                lines.append(":synth " + target)
                cases.append({"engine": engine, "policy": policy, "name": name, "type": target})
    return "\n".join(lines + [":quit", ""]), cases


def kernel_source(results):
    lines = ["set_option linter.unusedVariables false", *ENVIRONMENT]
    declarations = []
    for index, result in enumerate(results):
        names = []
        for number, term in enumerate(result["terms"], 1):
            name = f"Quality.case{index}_{number}"
            names.append(name)
            declarations.append((name, result))
            lines.extend([f"def {name} : {result['type']} :=",
                          "\n".join("  " + line for line in term.splitlines()),
                          f"#print axioms {name}"])
        if result["name"] == "projection" and result["policy"] == "diverse":
            # Actual functional distinction, independent of binder spellings,
            # pretty-printing, type-erasure hashes or a syntactic diversity key.
            choices = ["(" + " ∨ ".join(f"{name} Nat 11 29 = {value}" for name in names) + ")"
                       for value in (11, 29)]
            lines.append("example : " + " ∧ ".join(choices) + " := by decide")
    return "\n".join(lines) + "\n", declarations


def is_direct_last_argument_selector(term, arity):
    """Recognize only a simple lambda spine returning its final bound name.

    This fixture metric does not infer Lean equivalence or replace replay. It
    accepts grouped or successive simple binders and ignores their spelling;
    applications, matches, patterns, annotations and extra syntax fail closed.
    """
    remaining = term.strip()
    binders = []
    while match := re.match(r"fun\s+(.+?)\s*=>\s*", remaining, re.DOTALL):
        tokens = re.findall(r"«[^»]+»|\S+", match.group(1))
        if not tokens or any(not re.fullmatch(r"(?:[^\W\d]\w*'*|«[^»]+»)", token)
                             for token in tokens):
            return False
        binders.extend(tokens)
        remaining = remaining[match.end():].strip()
    return (len(binders) == arity and binders[-1] != "_"
            and remaining == binders[-1]
            and binders[-1] not in binders[:-1])


def paired_nil_comparisons(results):
    """Require an actual before/after witness when both profiles were run.

    The historical Exference Church nil receipt contains a case on Sum.inr.
    New paired runs must establish the difference afresh under their identical
    settings; that old receipt is motivation, not substituted live evidence.
    Single-policy diagnostic runs report no paired comparison.
    """
    nil_results = {result["policy"]: result for result in results
                   if result["engine"] == "exference" and result["name"] == "nil"}
    legacy = nil_results.get("legacy")
    if legacy is None:
        return []
    before = legacy["terms"][0] if legacy["terms"] else ""
    comparisons = []
    for policy in POLICIES[1:]:
        current = nil_results.get(policy)
        if current is None:
            continue
        after = current["terms"][0] if current["terms"] else ""
        before_has_match = bool(re.search(r"\bmatch\b", before))
        after_is_direct = is_direct_last_argument_selector(after, 4)
        comparisons.append({"engine": "exference", "case": "nil",
                            "before_policy": "legacy", "after_policy": policy,
                            "before_term": before, "after_term": after,
                            "legacy_has_explicit_match": before_has_match,
                            "quality_is_direct_last_argument_selector": after_is_direct,
                            "passed": before_has_match and after_is_direct})
    return comparisons


class ParserTests(unittest.TestCase):
    def test_multiline_and_order(self):
        cases = [{"type": "A"}, {"type": "B"}]
        output = "λ> :synth A\n  it1 fun x =>\n    x\n  it2 other\nnote: stop\nλ> :synth B\n  it1 b\nλ> :quit\n"
        self.assertEqual(parse_many(output, cases, 2)[0]["terms"], ["fun x =>\n    x", "other"])

    def test_missing_extra_labels_and_unchecked(self):
        for output in ["λ> :synth A\n  it2 x\n", "λ> :synth A\n  it1 sorry\n",
                       "λ> :synth B\n  it1 x\n", "λ> :synth A\nλ> :synth A\n"]:
            with self.subTest(output=output), self.assertRaises(ValueError):
                parse_many(output, [{"type": "A"}], 1)

    def test_direct_selector_recognition_is_binder_independent(self):
        for term in ["fun _ _ _ result => result", "fun A R => fun f seed => seed",
                     "fun _ _ f «final value» => «final value»"]:
            self.assertTrue(is_direct_last_argument_selector(term, 4), term)
        for term in ["fun _ _ f seed => f seed", "fun _ _ f seed => match seed with | x => x",
                     "fun _ _ ⟨f⟩ seed => seed", "fun _ _ _ => _",
                     "fun seed _ _ seed => seed", "fun _ _ f seed => (fun x => x) seed"]:
            self.assertFalse(is_direct_last_argument_selector(term, 4), term)

    def test_paired_nil_requires_observed_before_and_after(self):
        def result(policy, term):
            return {"engine": "exference", "policy": policy, "name": "nil", "terms": [term]}
        legacy = result("legacy", "fun _ _ f x => match Sum.inr x with | .inl a => f a x | .inr b => b")
        direct = result("balanced", "fun _ _ _ final => final")
        self.assertTrue(paired_nil_comparisons([legacy, direct])[0]["passed"])
        self.assertFalse(paired_nil_comparisons([result("legacy", direct["terms"][0]), direct])[0]["passed"])
        self.assertFalse(paired_nil_comparisons([legacy, result("balanced", "fun _ _ f x => f x")])[0]["passed"])
        self.assertEqual(paired_nil_comparisons([direct]), [])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--leant", type=Path)
    parser.add_argument("--output", type=Path, default=ROOT / "test-church/quality-results")
    parser.add_argument("--engine", action="append", choices=["djinn", "exference", "both"])
    parser.add_argument("--policy", action="append", choices=POLICIES)
    parser.add_argument("--case", action="append", choices=[name for name, _ in CASES])
    parser.add_argument("--window", type=int, default=12)
    parser.add_argument("--shown", type=int, default=4)
    parser.add_argument("--steps", type=int, default=10000, help="Exference step budget only")
    parser.add_argument("--budget", type=int, default=10000, help="Djinn choice-point budget")
    parser.add_argument("--timeout", type=int, default=30, help="configured synthesis search timeout")
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("--prepare-only", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        return 0 if unittest.TextTestRunner(verbosity=2).run(
            unittest.defaultTestLoader.loadTestsFromTestCase(ParserTests)).wasSuccessful() else 1
    if args.window <= 0 or args.shown <= 0 or args.shown > args.window:
        parser.error("require 0 < shown <= window")
    if not args.prepare_only and args.leant is None:
        parser.error("--leant is required unless --prepare-only or --self-test")
    args.output.mkdir(parents=True, exist_ok=True)
    source, cases = make_commands(args)
    (args.output / "queries.txt").write_text(source, encoding="utf-8")
    if args.prepare_only:
        print(f"Prepared {len(cases)} paired queries; no synthesis or kernel replay run.")
        return 0
    digest = hashlib.sha256(args.leant.read_bytes()).hexdigest()
    with (args.output / "live-output.txt").open("w", encoding="utf-8") as capture:
        run = subprocess.run([str(args.leant.resolve()), "--plain"], input=source,
                             stdout=capture, stderr=subprocess.STDOUT, text=True, encoding="utf-8",
                             cwd=ROOT, env=dict(os.environ, LEANT_SYNTH_TIMEOUT=str(args.timeout)))
    output = (args.output / "live-output.txt").read_text(encoding="utf-8")
    validate_settings(output, source)
    results = parse_many(output, cases, args.shown)
    replay, declarations = kernel_source(results)
    path = args.output / "QualityCandidates.lean"
    path.write_text(replay, encoding="utf-8")
    kernel = subprocess.run(["lean", "+leanprover/lean4:v4.32.0", str(path.resolve())],
                            capture_output=True, text=True, encoding="utf-8", cwd=ROOT)
    (args.output / "kernel-output.txt").write_text(kernel.stdout + kernel.stderr, encoding="utf-8")
    inventories = {}
    for name, result in declarations:
        actual = reported_axioms(kernel.stdout, name)
        allowed = {"Quality.Token", "Quality.cheap", "Quality.expensive"} if result["name"] == "provider" else set()
        inventories[name] = {"actual": None if actual is None else sorted(actual),
                             "within_declared_premises": actual is not None and actual <= allowed}
    simple_nil = all(not re.search(r"\bmatch\b", result["terms"][0])
                     for result in results if result["name"] == "nil" and result["policy"] != "legacy"
                     and result["terms"])
    nil_comparisons = paired_nil_comparisons(results)
    stable = hashlib.sha256(args.leant.read_bytes()).hexdigest() == digest
    passed = (run.returncode == 0 and kernel.returncode == 0 and stable and simple_nil
              and all(comparison["passed"] for comparison in nil_comparisons)
              and all(result["terms"] for result in results)
              and all(item["within_declared_premises"] for item in inventories.values()))
    report = {"executable_sha256": digest, "executable_unchanged": stable,
              "source_sha256": hashlib.sha256(source.encode()).hexdigest(),
              "settings": {key: getattr(args, key) for key in ["window", "shown", "steps", "budget", "timeout"]},
              "live_exit_code": run.returncode, "kernel_exit_code": kernel.returncode,
              "query_count": len(cases), "term_count": len(declarations),
              "nil_has_no_explicit_match": simple_nil,
              "paired_nil_comparison_count": len(nil_comparisons),
              "paired_nil_comparisons": nil_comparisons, "inventories": inventories,
              "results": results, "passed": passed}
    (args.output / "results.json").write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"{'PASS' if passed else 'FAIL'}: {len(cases)} queries, {len(declarations)} exact displayed terms; kernel {kernel.returncode}")
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
