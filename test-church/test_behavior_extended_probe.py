"""Reject axiom leakage while recording the standard Sum equality dependency."""
import hashlib
import os
from pathlib import Path
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch
import behavior_extended_probe as probe


class ExactAxiomInventories(unittest.TestCase):
    names = ["BehaviorExtendedReplay.candidate",
             "BehaviorExtendedReplay.candidate_passes_original_oracle"]

    def check(self, actual, *, operation="maybeEither", declared=None):
        return probe.exact_axiom_inventories(
            self.names, self.names if declared is None else declared,
            dict(zip(self.names, actual)),
            probe.expected_candidate_replay_axioms(operation, self.names))

    def test_exact_oracle_dependency(self):
        self.assertTrue(self.check([set(), {"propext"}]))

    def test_candidate_still_must_be_axiom_free(self):
        self.assertFalse(self.check([{"propext"}, {"propext"}]))

    def test_other_oracles_do_not_inherit_permission(self):
        self.assertFalse(self.check([set(), {"propext"}], operation="foldr"))

    def test_unexpected_or_missing_proof_axioms_fail(self):
        for actual in (None, set(), {"propext", "sorryAx"}, {"Classical.choice"}):
            self.assertFalse(self.check([set(), actual]))

    def test_missing_duplicate_and_foreign_declarations_fail(self):
        for declared in (self.names[:1], self.names + self.names[:1], self.names + ["foreign"]):
            self.assertFalse(self.check([set(), {"propext"}], declared=declared))

    def test_only_the_two_named_control_proofs_use_propext(self):
        names = ["BehaviorExtendedControl.witness_maybeEither",
                 *sorted(probe.MAYBE_EITHER_CONTROL_PROOFS),
                 "BehaviorExtendedControl.witness_foldr_passes"]
        expected = probe.expected_oracle_control_axioms(names)
        self.assertEqual(expected[names[0]], [])
        self.assertEqual(expected[names[-1]], [])
        self.assertEqual([name for name, axioms in expected.items() if axioms], names[1:-1])


class RuntimeProvenance(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.directory = Path(temporary.name).resolve()
        self.runtime = SimpleNamespace(sha256=lambda path:
            hashlib.sha256(Path(path).read_bytes()).hexdigest())
        self.kernel = self.file("actual-lean", b"actual kernel")
        self.launcher = self.file("launcher-lean", b"different launcher")
        self.source = self.file("Candidate.lean", b"def candidate : Nat := 0\n")
        self.source_row = {"path": str(self.source), "sha256": self.runtime.sha256(self.source)}
        self.args = SimpleNamespace(lean=str(self.launcher), toolchain="owner/lean:v1",
                                    lean_runtime=self.kernel)

    def file(self, relative, content):
        path = self.directory / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(content)
        return path

    def replay(self, mutation=None):
        calls = []

        def run(label, command, *, cwd):
            calls.append((label, command, cwd))
            if mutation:
                mutation()
            return SimpleNamespace(returncode=0, stderr="",
                stdout="'candidate' does not depend on any axioms\n")

        result = probe.check_kernel(self.runtime, SimpleNamespace(run=run), self.args,
                                    "exact", self.source_row, ["candidate"])
        return result, calls

    def test_explicit_kernel_is_invoked_directly_and_both_identities_are_checked(self):
        result, calls = self.replay()
        self.assertEqual(result["status"], "passed")
        self.assertEqual(calls, [("exact", [self.kernel, str(self.source)], probe.ROOT)])
        self.assertEqual(result["kernel_runtime"],
                         {"path": str(self.kernel), "sha256": self.runtime.sha256(self.kernel)})
        self.assertTrue(result["kernel_runtime_unchanged"])
        self.assertTrue(result["source_unchanged"])

    def test_existing_partial_launcher_direct_kernel_arguments_remain_compatible(self):
        self.args = SimpleNamespace(lean=str(self.kernel), toolchain="")
        result, calls = self.replay()
        self.assertEqual(result["status"], "passed")
        self.assertEqual(calls, [("exact", [self.kernel, str(self.source)], probe.ROOT)])

    def test_kernel_change_or_disappearance_fails_even_with_valid_axiom_output(self):
        for delete in (False, True):
            with self.subTest(delete=delete):
                self.kernel.write_bytes(b"original")
                mutation = self.kernel.unlink if delete else lambda: self.kernel.write_bytes(b"replacement")
                result, _ = self.replay(mutation)
                self.assertEqual(result["status"], "failed")
                self.assertFalse(result["kernel_runtime_unchanged"])

    def test_changed_input_cannot_borrow_success_from_another_program(self):
        result, _ = self.replay(lambda: self.source.write_bytes(b"different program"))
        self.assertEqual(result["status"], "failed")
        self.assertFalse(result["source_unchanged"])
        # An already changed input must be refused before any process is run.
        result, calls = self.replay()
        self.assertEqual(result["status"], "failed")
        self.assertEqual(calls, [])

    def test_installed_toolchain_resolution_never_invokes_the_launcher(self):
        suffix = ".exe" if os.name == "nt" else ""
        actual = self.file("elan/toolchains/owner--lean---v1/bin/lean" + suffix, b"installed kernel")
        self.args.lean_runtime = None
        with patch.dict(os.environ, {"ELAN_HOME": str(self.directory / "elan")}):
            self.assertEqual(probe.resolve_kernel(self.args), actual)
            actual.unlink()
            with self.assertRaisesRegex(ValueError, "cannot pin the actual lean binary"):
                probe.resolve_kernel(self.args)

    def test_live_backend_and_lake_are_explicit_and_all_runtime_files_are_pinned(self):
        suffix = ".exe" if os.name == "nt" else ""
        leant = self.file("leant" + suffix, b"leant")
        backend = self.file("backend/.lake/build/bin/repl" + suffix, b"repl")
        lakefile = self.file("backend/lakefile.toml", b'name = "repl"\n')
        toolchain = self.file("backend/lean-toolchain", b"owner/live:v2\n")
        lean = self.file("elan/toolchains/owner--live---v2/bin/lean" + suffix, b"live lean")
        lake = self.file("elan/toolchains/owner--live---v2/bin/lake" + suffix, b"live lake")
        self.args.leant = leant
        self.args.backend = backend
        report = {"source_hashes": {}}
        with patch.dict(os.environ, {"ELAN_HOME": str(self.directory / "elan"),
                                     "LEANT_BACKEND": "wrong ambient backend",
                                     "LEANT_SYNTH_TIMEOUT": "999"}):
            selected_leant, selected_backend, selected_lake, hashes = probe.runtime_identity(
                self.args, self.runtime, report)
            command, environment = probe.live_invocation(
                selected_leant, selected_backend, selected_lake, 90)
        self.assertEqual(command, [leant, "--plain", "--lake", lake])
        self.assertEqual(environment["LEANT_BACKEND"], str(backend))
        self.assertEqual(environment["LEANT_SYNTH_TIMEOUT"], "90")
        self.assertTrue({str(path) for path in (leant, backend, lean, lake, self.kernel, self.launcher)} <= set(hashes))
        self.assertEqual(report["source_hashes"][str(toolchain)], self.runtime.sha256(toolchain))
        self.assertEqual(report["source_hashes"][str(lakefile)], self.runtime.sha256(lakefile))
        self.assertEqual(report["runtime_identity"]["requested_kernel_toolchain"], "owner/lean:v1")
        self.assertEqual(self.args.lean, str(self.kernel))
        self.assertEqual(self.args.toolchain, "")
        self.assertTrue(probe.unchanged(self.runtime, hashes))
        backend.write_bytes(b"changed repl")
        self.assertFalse(probe.unchanged(self.runtime, hashes))



class NativeLengthSourceAuthority(unittest.TestCase):
    term = "fun _ f => .ofNat (f _ (fun _ => .succ) (.zero))"

    def fixture(self):
        case = {"operation": "length", "engine": "exference",
                "required_provider_names": list(probe.NUMERIC_NAMES)}
        result = {**case, "status": "candidate", "candidate": self.term}
        observation = {"schema": 1, "label": "it1", "term": self.term,
            "route": "RouteTypedCandidate", "origin": {"engine": "exference",
                "rendering": {"term": self.term, "matches_verified_text": True},
                "graph": {"globals": ["LeantRecC1_0", "LeantRecC1_1", "LeantFamilyC0_0"],
                    "erasure_matches_compatibility": True,
                    "context_introductions": [], "context_applications": []}}}
        return case, result, observation

    def transcript(self, observation, fragment=None):
        return ("debug fragment: " + (fragment or probe.NATIVE_LENGTH_FRAGMENT)
                + "\ndebug accepted-candidate: " + probe.json.dumps(observation) + "\n")

    def route(self, output, case, result):
        return probe.length_source_route(output, case, result,
            probe.actual_provider_inventory(output, case))

    def test_native_baseline_without_discovery_has_its_own_source_route(self):
        case, result, observation = self.fixture()
        policy = self.route(self.transcript(observation), case, result)
        self.assertEqual(policy["route"], "native_constructor_baseline")
        self.assertFalse(policy["provider_discovery_observed"])
        self.assertEqual(set(policy["allowed_value_constants"]), probe.NATIVE_LENGTH_CONSTANTS)

    def test_exact_provider_inventory_stays_distinct_and_ordered(self):
        case, result, observation = self.fixture()
        entries = [f'debug provider: Provider {{providerLeanName = "{name}"}}\n'
                   for name in probe.NUMERIC_NAMES]
        native = self.transcript(observation)
        policy = self.route(native + "".join(entries), case, result)
        self.assertEqual(policy["route"], "exact_numeric_provider_inventory")
        for rows in (entries[:1], entries[::-1], entries + entries[:1],
                     ['debug provider: malformed\n']):
            with self.assertRaisesRegex(ValueError, "discovery was observed"):
                self.route(native + "".join(rows), case, result)

    def test_native_route_requires_the_exact_fragment_and_actual_owner(self):
        case, result, observation = self.fixture()
        with self.assertRaisesRegex(ValueError, "constructor inventory"):
            self.route(self.transcript(observation, 'FAtom False "Int"'), case, result)
        for change in (lambda o: o["origin"].update(engine="djinn"),
                       lambda o: o["origin"]["graph"].update(globals=["oracle-helper"]),
                       lambda o: o["origin"]["graph"].update(erasure_matches_compatibility=False),
                       lambda o: o["origin"]["rendering"].update(term="another term")):
            _, _, altered = self.fixture()
            change(altered)
            with self.assertRaisesRegex(ValueError, "source origin"):
                self.route(self.transcript(altered), case, result)

    def test_absent_duplicate_or_foreign_accepted_observations_fail(self):
        case, result, observation = self.fixture()
        text = self.transcript(observation)
        for output in (text.split("debug accepted-candidate:")[0],
                       text + "debug accepted-candidate: " + probe.json.dumps(observation) + "\n"):
            with self.assertRaisesRegex(ValueError, "one retained accepted"):
                self.route(output, case, result)
        observation["term"] = "another term"
        with self.assertRaisesRegex(ValueError, "source origin"):
            self.route(self.transcript(observation), case, result)

    def policy(self, provider=False):
        return {"route": "exact_numeric_provider_inventory" if provider else "native_constructor_baseline",
                "required_type_constants": ["Int"],
                "allowed_value_constants": sorted(probe.NATIVE_LENGTH_CONSTANTS
                    | (set(probe.NUMERIC_NAMES) if provider else set()))}

    def inventory(self, values=None, types=None):
        return probe.IMPLEMENTATION_MARKER + probe.json.dumps({
            "declaration": "BehaviorExtendedReplay.candidate",
            "type_constants": ["Int"] if types is None else types,
            "value_constants": ["Int", "Nat", "Int.ofNat", "Nat.succ", "Nat.zero"]
                if values is None else values}) + "\n"

    def test_kernel_constants_discriminate_native_and_provider_routes(self):
        checked = probe.check_implementation_inventory(self.inventory(), self.policy())
        self.assertEqual(checked["route"], "native_constructor_baseline")
        provider = self.inventory(["Int", *probe.NUMERIC_NAMES])
        probe.check_implementation_inventory(provider, self.policy(provider=True))
        with self.assertRaisesRegex(ValueError, "outside its observed source route"):
            probe.check_implementation_inventory(provider, self.policy())

    def test_oracle_alias_native_extra_and_wrong_type_cannot_hide_in_implementation(self):
        for foreign in ("BehaviorExtended.length", "BehaviorExtendedControl.witness_length",
                        "BehaviorExtendedNumeric.extra", "Int.negSucc", "Nat.rec"):
            with self.assertRaisesRegex(ValueError, "outside its observed source route"):
                probe.check_implementation_inventory(self.inventory([foreign]), self.policy(provider=True))
        with self.assertRaisesRegex(ValueError, "outside its observed source route"):
            probe.check_implementation_inventory(self.inventory(types=["Nat"]), self.policy())

    def test_kernel_inventory_missing_duplicate_and_malformed_rows_fail(self):
        record = self.inventory()
        for output in ("", record + record, self.inventory(["Nat", "Nat"]),
                       record.replace("BehaviorExtendedReplay.candidate", "foreign")):
            with self.assertRaises(ValueError):
                probe.check_implementation_inventory(output, self.policy())

    def test_axiom_success_alone_cannot_promote_a_native_candidate_replay(self):
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            kernel = directory / "kernel"
            kernel.write_bytes(b"pinned kernel fixture")
            source = directory / "Candidate.lean"
            source.write_text("def candidate : Nat := 0\n", encoding="utf-8")
            runtime = SimpleNamespace(sha256=lambda path:
                hashlib.sha256(Path(path).read_bytes()).hexdigest())
            args = SimpleNamespace(lean=str(kernel), lean_runtime=kernel, toolchain="")
            row = {"path": str(source), "sha256": runtime.sha256(source)}
            name = "BehaviorExtendedReplay.candidate"
            axioms = f"'{name}' does not depend on any axioms\n"
            for marker, expected in (("", "failed"), (self.inventory(), "passed"),
                    (self.inventory(["BehaviorExtended.length"]), "failed")):
                processes = SimpleNamespace(run=lambda *args, **kwargs:
                    SimpleNamespace(returncode=0, stdout=axioms + marker, stderr=""))
                result = probe.check_kernel(runtime, processes, args, "candidate", row,
                    [name], implementation_policy=self.policy())
                self.assertEqual(result["status"], expected)
                self.assertTrue(result["kernel_runtime_unchanged"])
                self.assertTrue(result["source_unchanged"])

if __name__ == "__main__":
    unittest.main()
