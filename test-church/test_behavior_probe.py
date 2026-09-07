"""Pure transcript guards; no Lean or synthesis processes are started."""
import unittest
from pathlib import Path
import sys
import tempfile
from types import SimpleNamespace
from unittest import mock

from behavior_probe import (commands, isolated_kernel_sources, kernel_source,
                            latency_observer, main, parse_output, validate_settings)


def case(name="test", expected="candidate"):
    return {"name": name, "command": f":synth {name} : Nat → Nat where True", "expected": expected}


def output(item, body):
    return "λ> " + item["command"] + "\n" + body + "\nλ> :quit\n"


class BehavioralTranscriptTests(unittest.TestCase):
    def test_latency_queries_retain_exact_echoes_and_false_boundaries(self):
        factory = mock.Mock(return_value="observer")
        first = case("first")
        second = case("second")
        negative = case("negative", "no_candidate")
        self.assertEqual(latency_observer(SimpleNamespace(OutputMilestones=factory),
                                         [first, second, negative]), "observer")
        queries = factory.call_args.args[0]
        self.assertEqual([query["id"] for query in queries], ["first", "second", "negative"])
        import re
        for query, item in zip(queries, [first, second, negative]):
            self.assertRegex("λ> " + item["command"], re.compile(query["start_pattern"]))
        self.assertIsNone(queries[-1]["success_pattern"])
        self.assertIsNotNone(queries[0]["success_pattern"])

    def test_strategy_setting_is_explicit_and_its_acknowledgment_is_checked(self):
        spec = SimpleNamespace(lean_prelude=lambda: [], lean_predicate=lambda operation, name: "True",
                               OBSERVATIONS={"not": 2})
        for strategy in ("depth-first", "interleave"):
            args = SimpleNamespace(window=4096, budget=100000, steps=100000, timeout=30,
                                   djinn_strategy=strategy)
            source, cases = commands(spec, ["djinn", "both"], ["not"], args, {"not": "Nat → Nat"})
            setting = ":set synth-djinn-strategy " + strategy
            self.assertEqual(source.splitlines().count(setting), 1)
            self.assertIn(":set synth-shown 1", source.splitlines())
            self.assertIn(":set synth-window 4096", source.splitlines())
            self.assertIn(":set synth-verify 4096", source.splitlines())
            self.assertEqual(len(cases), 4)  # Two positives and both false controls.
            for control in (item for item in cases if item["expected"] == "no_candidate"):
                self.assertEqual(control["type"], "Nat → Nat")
                self.assertTrue(control["command"].endswith(" : Nat → Nat where False"))
            acknowledged = "λ> " + setting + "\nsynth djinn-strategy: " + strategy + "\nλ> :quit\n"
            validate_settings(acknowledged, setting + "\n")
            with self.assertRaises(ValueError):
                validate_settings(acknowledged.replace("\nsynth djinn-strategy:", "\nsynth djinn strategy:"), setting + "\n")

    def test_lean_runner_applies_shared_output_guard_before_preparation(self):
        # The shared helper's actual filesystem behavior is tested in Djex;
        # this checks Leant calls it before reading provenance or writing files.
        with tempfile.TemporaryDirectory(prefix="behavior-existing-receipt-") as directory:
            marker = Path(directory) / "results.json"
            marker.write_bytes(b"previous receipt")
            guard = mock.Mock(side_effect=ValueError("choose a fresh path"))
            runtime = SimpleNamespace(validate_limits=mock.Mock(), prepare_output_directory=guard,
                                      source_provenance=mock.Mock(side_effect=AssertionError("guard ran too late")))
            spec = SimpleNamespace(OPERATIONS=("not", "swap", "map", "append", "reverse", "filter"))
            with mock.patch.object(sys, "argv", ["behavior_probe.py", "--prepare-only", "--output", directory]), \
                    mock.patch.object(sys, "path", list(sys.path)), \
                    mock.patch("behavior_probe.importlib.import_module", side_effect=[spec, runtime]):
                with self.assertRaisesRegex(ValueError, "fresh path"):
                    main()
            guard.assert_called_once_with(Path(directory))
            runtime.source_provenance.assert_not_called()
            self.assertEqual(list(Path(directory).iterdir()), [marker])
            self.assertEqual(marker.read_bytes(), b"previous receipt")

    def test_exact_multiline_candidate_and_summary(self):
        item = case()
        result = parse_output(output(item, "  it1  fun x =>\n    x\nnote: supplied behavioral assertion: 1 passed, 2 falsified, 0 inconclusive (checks concern only the supplied assertion)"), [item])
        self.assertEqual(result[0]["candidate"], "fun x =>\n    x")

    def test_absent_duplicate_or_unaccounted_candidate_fails(self):
        item = case()
        bodies = ["", "  it1  fun x => x", "  it1  fun x => x\n  it2  fun x => x\nnote: supplied behavioral assertion: 2 passed, 0 falsified, 0 inconclusive",
                  "  it1  fun x => x\nnote: supplied behavioral assertion: 0 passed, 1 falsified, 0 inconclusive",
                  "  it1  sorry\nnote: supplied behavioral assertion: 1 passed, 0 falsified, 0 inconclusive"]
        for body in bodies:
            with self.subTest(body=body), self.assertRaises(ValueError):
                parse_output(output(item, body), [item])

    def test_missing_duplicate_or_changed_matrix_cells_fail(self):
        first, second = case("first"), case("second")
        body = "  it1  fun x => x\nnote: supplied behavioral assertion: 1 passed, 0 falsified, 0 inconclusive"
        for text, cases in [("", []), ("", [first]), (output(first, body), [first, second]),
                            (output(first, body) + output(first, body), [first, second]),
                            (output(first, body) + output(first, body), [first, first])]:
            with self.subTest(text=text), self.assertRaises(ValueError):
                parse_output(text, cases)

    def test_false_control_requires_falsification_not_missing_output(self):
        item = case(expected="no_candidate")
        good = "note: supplied behavioral assertion: 0 passed, 3 falsified, 0 inconclusive"
        self.assertEqual(parse_output(output(item, good), [item])[0]["status"], "no_candidate")
        for body in ("", "note: supplied behavioral assertion: 0 passed, 0 falsified, 0 inconclusive",
                     "note: supplied behavioral assertion: 0 passed, 0 falsified, 1 inconclusive",
                     "  it1  fun x => x\n" + good):
            with self.subTest(body=body), self.assertRaises(ValueError):
                parse_output(output(item, body), [item])

    def test_oracle_or_replay_names_are_not_synthesis_providers(self):
        item = case()
        for term in ("BehaviorChurch.enc", "BehaviorControl.witness_reverse", "BehaviorCandidates.other"):
            body = "  it1  " + term + "\nnote: supplied behavioral assertion: 1 passed, 0 falsified, 0 inconclusive"
            with self.subTest(term=term), self.assertRaises(ValueError):
                parse_output(output(item, body), [item])

    def test_kernel_candidates_are_isolated_from_each_other_and_controls(self):
        spec = SimpleNamespace(lean_prelude=lambda: ["-- only observation adapters"],
                               lean_predicate=lambda operation, name: name + " = " + name,
                               lean_control_source=lambda: (["def BehaviorControl.witness_reverse := 0"],
                                                            ["BehaviorControl.witness_reverse"]))
        first = {"name": "first", "type": "Nat", "operation": "reverse", "status": "candidate",
                 "candidate": "BehaviorControl.witness_reverse"}
        second = {"name": "second", "type": "Nat", "operation": "reverse", "status": "candidate",
                  "candidate": "BehaviorCandidates.first"}
        files = isolated_kernel_sources(spec, [first, second])
        self.assertEqual(len(files), 3)
        first_source, second_source, controls = [row[1] for row in files]
        self.assertIn("  " + first["candidate"], first_source)
        self.assertIn("  " + second["candidate"], second_source)
        for source in (first_source, second_source):
            self.assertNotIn("def BehaviorControl.witness_reverse", source)
            self.assertNotIn("import Behavior", source)
        self.assertNotIn("def BehaviorCandidates.second", first_source)
        self.assertNotIn("def BehaviorCandidates.first", second_source)
        self.assertIn("def BehaviorControl.witness_reverse", controls)
        self.assertNotIn("def BehaviorCandidates.", controls)
        with self.assertRaises(ValueError):
            kernel_source(spec, [first, second])


if __name__ == "__main__":
    unittest.main()
