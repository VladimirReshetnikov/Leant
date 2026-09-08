"""A False observation must not turn a timed-out tree query into acceptance."""
import unittest

from run_acceptance import require_completed_live_query


class DeadlineTests(unittest.TestCase):
    def test_actual_false_observations_do_not_override_timeout(self):
        transcript = (
            "the engine did not finish within 90s — no answer, not a verdict\n"
            "supplied behavioral assertion: 0 passed, 446 falsified, 0 inconclusive\n"
        )
        with self.assertRaises(TimeoutError):
            require_completed_live_query(transcript)

    def test_timeout_after_an_accepted_prefix_still_fails(self):
        with self.assertRaises(TimeoutError):
            require_completed_live_query(
                "  it1 fun x => x\n"
                "the engine did not finish within 30s — no answer, not a verdict\n"
                "supplied behavioral assertion: 1 passed, 0 falsified, 0 inconclusive\n"
            )

    def test_completed_false_search_retains_its_observations(self):
        require_completed_live_query(
            "supplied behavioral assertion: 0 passed, 194 falsified, 0 inconclusive\n"
        )

    def test_timeout_setting_is_not_a_timeout_event(self):
        require_completed_live_query("λ> :set synth-timeout 90\nsynth-timeout = 90\n")


if __name__ == "__main__":
    unittest.main()
