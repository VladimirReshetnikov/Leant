"""Checks for the acceptance harness's exact-output and coverage boundary."""
import contextlib
import io
import sys
import unittest
from unittest.mock import patch

from run_corpus import kernel_source, main, parse_results, reported_axioms, validate_settings


class TranscriptSettingTests(unittest.TestCase):
    def test_require_accepted_engine_switches_in_order(self):
        source = ":set synth-engine djinn\n:set synth-engine exference\n"
        output = ("λ> :set synth-engine djinn\nsynth engine: djinn\n"
                  "λ> :set synth-engine exference\nsynth engine: exference\n")
        validate_settings(output, source)
        with self.assertRaisesRegex(ValueError, "did not acknowledge"):
            validate_settings(output.replace("synth engine: exference", "synth engine: djinn"), source)
        with self.assertRaisesRegex(ValueError, "do not match"):
            validate_settings(output.split("λ> :set synth-engine exference")[0], source)

    def test_reject_command_error_outside_synthesis_chunk(self):
        for diagnostic in ["error: failed declaration", "REPL error: unavailable",
                           "unknown command :bad", "usage: :set synth-engine djinn|exference|both"]:
            with self.subTest(diagnostic=diagnostic), self.assertRaisesRegex(ValueError, "error"):
                validate_settings("λ> def bad := missing\n" + diagnostic + "\n", "")

    def test_bind_repeated_queries_to_their_engine_switches(self):
        source = (":set synth-engine djinn\n:synth Unit\n"
                  ":set synth-engine exference\n:synth Unit\n")
        djinn = "λ> :set synth-engine djinn\nsynth engine: djinn\n"
        exference = "λ> :set synth-engine exference\nsynth engine: exference\n"
        query = "λ> :synth Unit\n  it1  ⟨⟩\n"
        validate_settings(djinn + query + exference + query, source)
        # Both separate command subsequences are unchanged, but both queries
        # now run under Exference, so this cannot establish Djinn coverage.
        with self.assertRaisesRegex(ValueError, "transcript order"):
            validate_settings(djinn + exference + query + query, source)

    def test_acknowledge_unbounded_timeout(self):
        validate_settings("λ> :set synth-timeout 0\nsynth timeout: 0 (wait indefinitely)\n",
                          ":set synth-timeout 0\n")

    def test_acknowledge_actual_provider_cap_label(self):
        for value in (1, 2, 80):
            with self.subTest(value=value):
                validate_settings(
                    f"λ> :set synth-provider-cap {value}\nsynth provider cap: {value}\n",
                    f":set synth-provider-cap {value}\n")

    def test_reject_altered_provider_cap_value_or_label(self):
        source = ":set synth-provider-cap 80\n"
        for acknowledgment in ("synth provider cap: 81", "synth provider-cap: 80",
                               "synth-provider-cap: 80"):
            with self.subTest(acknowledgment=acknowledgment), self.assertRaisesRegex(
                    ValueError, "did not acknowledge"):
                validate_settings("λ> :set synth-provider-cap 80\n" + acknowledgment + "\n", source)

    def test_preserve_historical_djinn_strategy_label(self):
        source = ":set synth-djinn-strategy interleave\n"
        output = "λ> :set synth-djinn-strategy interleave\nsynth djinn-strategy: interleave\n"
        validate_settings(output, source)
        with self.assertRaisesRegex(ValueError, "did not acknowledge"):
            validate_settings(output.replace("synth djinn-strategy:", "synth djinn strategy:"), source)

    def test_bind_repeated_queries_to_their_provider_caps(self):
        source = (":set synth-provider-cap 1\n:synth Unit\n"
                  ":set synth-provider-cap 80\n:synth Unit\n")
        one = "λ> :set synth-provider-cap 1\nsynth provider cap: 1\n"
        eighty = "λ> :set synth-provider-cap 80\nsynth provider cap: 80\n"
        query = "λ> :synth Unit\n  it1  ⟨⟩\n"
        validate_settings(one + query + eighty + query, source)
        # The setting and query subsequences still match independently, but
        # moving the first query changes its actual discovery allowance.
        with self.assertRaisesRegex(ValueError, "transcript order"):
            validate_settings(one + eighty + query + query, source)

    def test_live_and_saved_transcript_modes_are_mutually_exclusive(self):
        with patch.object(sys, "argv", ["run_corpus.py", "--leant", "unused.exe",
                                       "--replay-output", "unused.txt"]):
            with contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit) as failure:
                main()
        self.assertEqual(failure.exception.code, 2)


class AxiomInventoryTests(unittest.TestCase):
    def test_read_wrapped_dependency_list_for_exact_declaration(self):
        output = ("'Example.term' depends on axioms: [Example.G,\n"
                  " Example.Seed,\n Example.maker,\n Example.seed]\n")
        self.assertEqual(reported_axioms(output, "Example.term"),
                         {"Example.G", "Example.Seed", "Example.maker", "Example.seed"})
        self.assertIsNone(reported_axioms(output, "Example.other"))

    def test_require_one_inventory_and_preserve_empty_inventory(self):
        output = "'Example.term' does not depend on any axioms\n"
        self.assertEqual(reported_axioms(output, "Example.term"), set())
        self.assertIsNone(reported_axioms(output + output, "Example.term"))


class DisplayedCandidateTests(unittest.TestCase):
    def test_preserve_multiline_term_until_diagnostics(self):
        cases = [{"id": "identity", "name": "identity", "lean_type": "Unit → Unit"}]
        output = (
            "λ> :synth Unit → Unit\n"
            "  it1  fun value =>\n"
            "    let result := value\n"
            "    result\n"
            "note: search truncated: candidate limit reached (1)\n"
            "λ> :quit\n"
        )
        self.assertEqual(parse_results(output, cases)[0]["candidate"],
                         "fun value =>\n    let result := value\n    result")

    def test_unreached_query_is_a_failure(self):
        cases = [{"id": "first", "name": "first"}, {"id": "second", "name": "second"}]
        output = "λ> :synth Unit\n  it1  ⟨⟩\n"
        results = parse_results(output, cases)
        self.assertEqual([row["status"] for row in results], ["candidate", "missing"])
        self.assertIsNone(results[1]["candidate"])

    def test_keep_relative_indentation_in_kernel_replay(self):
        result = {"id": "identity", "name": "identity", "line": 1,
                  "classification": "total", "lean_type": "Unit → Unit",
                  "candidate": "fun value =>\n  let result := value\n  result"}
        source = kernel_source([result])
        self.assertIn("  fun value =>\n    let result := value\n    result", source)

    def test_refuse_transcript_from_another_selected_query(self):
        cases = [{"id": "identity", "name": "identity", "lean_type": "Unit → Unit"}]
        with self.assertRaisesRegex(ValueError, "does not match"):
            parse_results("λ> :synth Unit\n  it1  ⟨⟩\n", cases)

    def test_refuse_extra_queries_instead_of_silently_ignoring_them(self):
        output = "λ> :synth Unit\n  it1  ⟨⟩\nλ> :synth Unit\n  it1  ⟨⟩\n"
        with self.assertRaisesRegex(ValueError, "more synthesis queries"):
            parse_results(output, [{"id": "one", "name": "one", "lean_type": "Unit"}])

    def test_reject_empty_selection(self):
        with self.assertRaisesRegex(ValueError, "empty selection"):
            parse_results("", [])

    def test_reject_extra_or_duplicate_displayed_candidates(self):
        case = {"id": "one", "name": "one", "lean_type": "Unit"}
        for extra_label in ["it1", "it2", "it0"]:
            with self.subTest(label=extra_label), self.assertRaisesRegex(ValueError, "candidate labels"):
                parse_results("λ> :synth Unit\n  it1  ⟨⟩\n  " + extra_label + "  ⟨⟩\n", [case])


if __name__ == "__main__":
    unittest.main()
