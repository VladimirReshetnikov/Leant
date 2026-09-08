"""Pure acceptance-harness controls; no Lean or synthesis processes are run."""
from copy import deepcopy
import json
from pathlib import Path
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

import run_production as production


def case(operation="local_given", mode="ordinary", engine="djinn"):
    return production.selected_cases([engine], [operation], [mode])[0]


def observation(term="exact candidate", engine="djinn"):
    binder = dict(introduction="OccurrenceId 3", slot=0)
    return dict(schema=1, label="it1", term=term, route="RouteTypedCandidate", variant_ordinal=0,
                origin=dict(engine=engine, renderer_ordinal=0,
                            rendering=dict(term=term, matches_verified_text=True),
                            graph=dict(root="TermNodeId 0", root_type="original complete source type",
                                       root_closed=True, node_count=8, erasure_matches_compatibility=True,
                                       globals=[], context_introductions=[dict(node="TermNodeId 2",
                                           occurrence="OccurrenceId 3", binders=[binder])],
                                       context_applications=[dict(node="TermNodeId 5",
                                           occurrence="OccurrenceId 6", evidence=[deepcopy(binder)])])))


def observed_block(value):
    return "debug accepted-candidate: " + json.dumps(value) + "\n"


class CoverageTests(unittest.TestCase):
    def test_complete_inventory_separates_modes_and_false(self):
        cases = production.selected_cases(["djinn", "exference", "both"],
                                          list(production.specifications()), ["ordinary", "where"])
        self.assertEqual(len(cases), 39)
        self.assertEqual(len({entry["name"] for entry in cases}), 39)
        self.assertEqual(sum(entry["expected"] == "candidate" for entry in cases), 18)
        self.assertEqual(sum(entry["expected"] == "unsupported" for entry in cases), 18)
        false_cases = [entry for entry in cases if entry["operation"] == "reject_all"]
        self.assertEqual(len(false_cases), 3)
        self.assertTrue(all(entry["mode"] == "where" for entry in false_cases))

    def test_ordinary_query_excludes_predicate_but_replay_keeps_payloads(self):
        ordinary, behavioral = [case(mode=mode) for mode in ("ordinary", "where")]
        self.assertEqual(ordinary["command"], ":synth " + ordinary["type"])
        self.assertNotIn(" where ", ordinary["command"])
        self.assertIn(" where ", behavioral["command"])
        self.assertEqual(ordinary["predicate"], behavioral["predicate"])
        for entry in (ordinary, behavioral):
            source, names = production.replay_source(entry, "exact_candidate")
            self.assertIn("def ContextReplay.accepted : " + entry["type"] + " :=\nexact_candidate", source)
            self.assertIn("= 7", source)
            self.assertIn("= 11", source)
            self.assertIn("= 107", source)
            self.assertIn("= 111", source)
            self.assertEqual(len(names), 8)

    def test_ordinary_output_does_not_require_behavioral_summary(self):
        parsed = production.candidate_result("  it1  exact candidate\ndebug accepted-candidate: {}\n", case())
        self.assertEqual(parsed["candidate"], "exact candidate")
        self.assertNotIn("observations", parsed)
        with self.assertRaises(ValueError):
            production.candidate_result("  it1  exact candidate\nsupplied behavioral assertion: 1 passed, 0 falsified, 0 inconclusive", case())

    def test_false_requires_actual_rejection_without_an_accepted_receipt(self):
        entry = case("reject_all", "where")
        block = "supplied behavioral assertion: 0 passed, 1 falsified, 0 inconclusive\n"
        self.assertEqual(production.candidate_result(block, entry)["status"], "no_candidate")
        for bad in (block.replace("1 falsified", "0 falsified"), block + "debug accepted-candidate: {}\n"):
            with self.assertRaises(ValueError):
                production.candidate_result(bad, entry)

    def test_refusals_observe_the_selected_mode(self):
        for mode in ("ordinary", "where"):
            entry = case("higher_universe", mode)
            block = "λ> " + entry["command"] + "\nsynthesis engine error: " + entry["required_refusal"] + "\n"
            if mode == "where":
                block += "supplied behavioral assertion: 0 passed, 0 falsified, 0 inconclusive\n"
            with patch.object(production, "validate_settings"):
                self.assertEqual(production.validate_live(block, "prepared settings", entry)["status"], "unsupported")
                with self.assertRaises(ValueError):
                    production.validate_live(block + "debug accepted-candidate: {}\n", "prepared settings", entry)


class AssociationTests(unittest.TestCase):
    def test_exact_origin_and_both_keep_the_actual_owner(self):
        for selected, owner in (("djinn", "djinn"), ("exference", "exference"),
                                ("both", "djinn"), ("both", "exference")):
            parsed = production.accepted_observation(observed_block(observation(engine=owner)),
                                                     case(engine=selected), "exact candidate")
            self.assertEqual(parsed["observation"]["origin"]["engine"], owner)
            self.assertEqual(len(parsed["observation_sha256"]), 64)

    def test_aggregate_counts_cannot_replace_the_exact_origin(self):
        with self.assertRaises(ValueError):
            production.accepted_observation("debug metric: typed-candidate-rendered=100\n", case(), "exact candidate")
        value = observation()
        value["origin"] = None
        with self.assertRaises(ValueError):
            production.accepted_observation(observed_block(value), case(), "exact candidate")

    def test_wrong_text_route_owner_rendering_and_erasure_are_rejected(self):
        changes = [
            lambda value: value.update(term="another candidate"),
            lambda value: value.update(label="it2"),
            lambda value: value.update(route="RouteLegacyCandidateFallback"),
            lambda value: value["origin"].update(engine="both"),
            lambda value: value["origin"].update(engine="exference"),
            lambda value: value["origin"]["rendering"].update(term="another candidate"),
            lambda value: value["origin"]["rendering"].update(matches_verified_text=False),
            lambda value: value["origin"]["graph"].update(erasure_matches_compatibility=False),
            lambda value: value["origin"]["graph"].update(root_closed=False),
            lambda value: value["origin"]["graph"].update(globals=["borrowedProvider"]),
        ]
        for index, change in enumerate(changes):
            with self.subTest(control=index):
                value = observation()
                change(value)
                with self.assertRaises(ValueError):
                    production.accepted_observation(observed_block(value), case(), "exact candidate")

    def test_dictionary_use_requires_its_actual_introduction_and_slot(self):
        for identity in (dict(introduction="OccurrenceId 99", slot=0),
                         dict(introduction="OccurrenceId 3", slot=1)):
            value = observation()
            value["origin"]["graph"]["context_applications"][0]["evidence"] = [identity]
            with self.assertRaises(ValueError):
                production.accepted_observation(observed_block(value), case(), "exact candidate")
        for key in ("context_applications", "context_introductions"):
            value = observation()
            value["origin"]["graph"][key] = []
            with self.assertRaises(ValueError):
                production.accepted_observation(observed_block(value), case(), "exact candidate")

    def test_duplicate_observations_cannot_be_associated_by_text(self):
        block = observed_block(observation())
        with self.assertRaises(ValueError):
            production.accepted_observation(block + block, case(), "exact candidate")


class KernelPinTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        directory = Path(self.directory.name)
        self.executable = directory / "actual-lean.exe"
        self.executable.write_bytes(b"kernel before")
        self.kernel = production.pin_kernel(self.executable)
        self.prepared = production.saved_source(directory, "Input.lean", "def checked := 1\n", ["checked"])
        self.calls = []

    def processes(self, mutate=False, inventory=True):
        def run(label, command, **kwargs):
            self.calls.append((label, command, kwargs))
            if mutate:
                self.executable.write_bytes(b"kernel after")
            return SimpleNamespace(returncode=0, stderr="",
                                   stdout="'checked' does not depend on any axioms\n" if inventory else "")
        return SimpleNamespace(run=run)

    def test_invokes_only_pinned_absolute_kernel_directly(self):
        result = production.kernel_check(self.processes(), "check", self.prepared, self.kernel)
        self.assertEqual(result["status"], "passed")
        self.assertEqual(self.calls[0][1], [str(self.executable.resolve()), self.prepared["path"]])
        self.assertTrue(result["kernel_unchanged"])

    def test_changed_kernel_before_call_cannot_run(self):
        self.executable.write_bytes(b"changed")
        with self.assertRaises(ValueError):
            production.kernel_check(self.processes(), "check", self.prepared, self.kernel)
        self.assertEqual(self.calls, [])

    def test_changed_kernel_during_call_cannot_pass(self):
        result = production.kernel_check(self.processes(mutate=True), "check", self.prepared, self.kernel)
        self.assertEqual(result["status"], "failed")
        self.assertFalse(result["kernel_unchanged"])

    def test_exit_zero_without_exact_inventory_cannot_pass(self):
        result = production.kernel_check(self.processes(inventory=False), "check", self.prepared, self.kernel)
        self.assertEqual(result["status"], "failed")
        self.assertIsNone(result["axiom_inventories"]["checked"])


if __name__ == "__main__":
    unittest.main()
