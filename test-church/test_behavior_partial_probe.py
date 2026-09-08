"""Pure guards for the exact partial-corpus observer/proof axiom policy."""
import unittest
from types import SimpleNamespace

import behavior_partial_probe as probe
from behavior_extended_probe import exact_axiom_inventories


class PartialAxiomPolicyTests(unittest.TestCase):
    def test_control_allowance_is_exact_and_never_covers_implementations(self):
        protected = [
            "BehaviorPartialControl.witness_atKey",
            "BehaviorPartialControl.wrong_atKey_always_default",
            "BehaviorPartialControl.wrong_atKey_last_matching_value",
            "BehaviorPartialReplay.candidate",
            "BehaviorPartialControl.witness_at_passes",
            "Other.BehaviorPartial.check_atKey",
        ]
        names = sorted(probe.AT_KEY_CONTROL_NAMES) + protected
        expected = probe.expected_oracle_control_axioms("atKey", names)
        self.assertEqual({name for name, axioms in expected.items() if axioms},
                         set(probe.AT_KEY_CONTROL_NAMES))
        self.assertTrue(all(expected[name] == [] for name in protected))
        self.assertTrue(all(axioms == [] for axioms in
                            probe.expected_oracle_control_axioms("at", names).values()))

    def test_candidate_replay_has_its_own_two_exact_allowances(self):
        names = [
            "BehaviorPartialReplay.candidate",
            "BehaviorPartial.check_atKey",
            "BehaviorPartialReplay.candidate_passes_original_oracle",
            "BehaviorPartialReplay.candidate_passes_inline_oracle",
            "BehaviorPartialControl.witness_atKey_passes",
            "BehaviorPartialReplay.other_candidate_passes_original_oracle",
        ]
        expected = probe.expected_candidate_replay_axioms("atKey", names)
        self.assertEqual({name for name, axioms in expected.items() if axioms},
                         set(probe.AT_KEY_REPLAY_NAMES))
        self.assertEqual(expected[names[0]], [])
        self.assertTrue(all(axioms == [] for axioms in
                            probe.expected_candidate_replay_axioms("head", names).values()))

    def test_only_the_complete_exact_observer_inventory_passes(self):
        names = ["BehaviorPartialReplay.candidate",
                 "BehaviorPartialReplay.candidate_passes_original_oracle"]
        expected = probe.expected_candidate_replay_axioms("atKey", names)
        actual = {name: set(axioms) for name, axioms in expected.items()}
        self.assertTrue(exact_axiom_inventories(names, names, actual, expected))
        for removed in probe.AT_KEY_OBSERVER_AXIOMS:
            changed = {name: set(axioms) for name, axioms in actual.items()}
            changed[names[1]].remove(removed)
            self.assertFalse(exact_axiom_inventories(names, names, changed, expected))
        for added in ("sorryAx", "foreignAxiom"):
            changed = {name: set(axioms) for name, axioms in actual.items()}
            changed[names[1]].add(added)
            self.assertFalse(exact_axiom_inventories(names, names, changed, expected))

    def test_observer_dependencies_cannot_leak_into_candidate(self):
        names = ["BehaviorPartialReplay.candidate",
                 "BehaviorPartialReplay.candidate_passes_original_oracle"]
        expected = probe.expected_candidate_replay_axioms("atKey", names)
        for dependency in probe.AT_KEY_OBSERVER_AXIOMS:
            actual = {name: set(axioms) for name, axioms in expected.items()}
            actual[names[0]].add(dependency)
            self.assertFalse(exact_axiom_inventories(names, names, actual, expected))

    def test_missing_duplicate_and_foreign_declarations_fail(self):
        names = sorted(probe.AT_KEY_CONTROL_NAMES)
        expected = probe.expected_oracle_control_axioms("atKey", names)
        actual = {name: set(axioms) for name, axioms in expected.items()}
        for declared in (names[:-1], names + [names[0]], names + ["foreign.declaration"]):
            self.assertFalse(exact_axiom_inventories(names, declared, actual, expected))
        incomplete = {name: axioms for name, axioms in actual.items() if name != names[0]}
        self.assertFalse(exact_axiom_inventories(names, names, incomplete, expected))
        foreign = dict(actual, foreign=set())
        self.assertFalse(exact_axiom_inventories(names, names, foreign, expected))
        missing_expected = {name: axioms for name, axioms in expected.items() if name != names[0]}
        self.assertFalse(exact_axiom_inventories(names, names, actual, missing_expected))


class PartialInlinePredicateTests(unittest.TestCase):
    def test_all_168_equalities_are_decided_in_order_before_one_bool_equality(self):
        # Distinct payloads make a missing, repeated, or reordered observation
        # observable. Empty lists keep this test about the assertion boundary,
        # rather than duplicating the independently maintained Church oracle.
        fixtures = []
        expected = []
        for value in range(168):
            literal = f"(({value}) : Int)"
            fixtures.append({
                "id": "observation_" + str(value), "decode": "identity",
                "lean_type_arguments": ["Int"],
                "native_inputs": {"default": value, "index": -1, "list": []},
                "lean_arguments": [literal, "((-1) : Int)", "(BehaviorPartial.enc ([] : (List Int)))"],
                "expected_native": value, "lean_expected": literal,
            })
            expected.append(f"(decide ((candidate) (Int) ({literal}) (((-1) : Int)) "
                            f"(fun _ step zero => zero) = {literal}))")
        calls = []

        def conjunction(expressions, *, connective):
            calls.append((list(expressions), connective))
            return "balanced_boolean_result"

        spec = SimpleNamespace(FIXTURES={"at": fixtures}, OBSERVATIONS={"at": 168},
                               lean_conjunction=conjunction)
        actual = probe.at_predicate(spec, "candidate")
        self.assertEqual(calls, [(expected, "&&")])
        self.assertEqual(actual, "(balanced_boolean_result) = true")
        self.assertEqual(len(set(expected)), 168)


if __name__ == "__main__":
    unittest.main()
