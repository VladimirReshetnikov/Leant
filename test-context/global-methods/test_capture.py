"""Adversarial controls for the trace evidence used by method/cache acceptance."""
import copy
import unittest
import capture


def fixture():
    typ, term = 'Nat', 'Nat.succ 0'
    payload = capture.canonical_json({'cmd': 'example : (' + typ + ') := (' + term + ')', 'env': 2})
    annotation = capture.canonical_json(dict(role='type-verification', requested_type=typ,
        candidate=term, renderer_ordinal=0, route='RouteTypedCandidate', owner_engine='djinn'))
    row = dict(backend_id=1, request_id=1, capture_started_ns=2, capture_completed_ns=3,
        payload_utf8_bytes=len(payload.encode('utf-8')), annotation_utf8_bytes=len(annotation.encode('utf-8')),
        payload_json=payload, annotation_json=annotation)
    events = [dict(backend_id=1, request_id=request, stage=stage, monotonic_ns=clock)
        for request, stage, clock in [(None, 'TraceSpawnStarted', 0),
            (1, 'TraceRequestStarted (Just 5)', 1), (1, 'TraceWriteStarted', 4),
            (1, 'TraceWriteCompleted', 5), (1, 'TraceResponseParsed', 6),
            (None, 'TraceCleanupCompleted', 7)]]
    return dict(format='leant-backend-trace-v1', clock='monotonic', capacity=128,
        dropped_events=0, events=events, request_capture=dict(
            format='leant-backend-request-capture-v1',
            encoding='canonical encodeJson UTF-8 without protocol framing', **capture.CAPTURE_LIMITS,
            retained_bytes=row['payload_utf8_bytes'] + row['annotation_utf8_bytes'],
            omitted_records=0, omissions={key: 0 for key in capture.OMISSION_REASONS}, requests=[row]))


class CaptureTests(unittest.TestCase):
    def test_combined_certificate_subject_and_protocol(self):
        annotation = dict(requested_type='Nat', candidate='Nat.succ 0')
        # Independent protocol fixture: full candidate value, both proof
        # constructors, and the inconclusive branch must all be retained.
        code = '''set_option autoImplicit false in
set_option maxHeartbeats 200000 in
example : _root_.PSigma (fun f : (
Nat
) => _root_.Option (_root_.Decidable (
f = 1
))) := by
  refine ⟨(
Nat.succ 0
  ), ?_⟩
  first
  | exact _root_.Option.some (_root_.Decidable.isTrue (by decide))
    trace "LEANT_BEHAVIOR_DECISION:1"
  | exact _root_.Option.some (_root_.Decidable.isFalse (by decide))
    trace "LEANT_BEHAVIOR_DECISION:2"
  | exact _root_.Option.none
    trace "LEANT_BEHAVIOR_DECISION:0"
'''
        self.assertEqual(capture.combined_decision_subject(code, annotation), ('f', 'f = 1'))
        # Presence of the annotated text in a comment cannot donate authority
        # to a different actual field, unlike a mere substring check.
        mutations = [code.replace('200000', '0'),
                     code.replace('DECISION:2', 'DECISION:1'),
                     code.replace('isFalse (by decide)', 'isFalse (by sorry)'),
                     code.replace('Nat.succ 0\n  ),', 'Nat.zero -- Nat.succ 0\n  ),'),
                     code.replace('PSigma', 'Option'), code + 'example : True := by trivial\n']
        for changed in mutations:
            with self.subTest(changed=changed), self.assertRaises(ValueError):
                capture.combined_decision_subject(changed, annotation)
        with self.assertRaises(ValueError):
            capture.combined_decision_subject(code, dict(annotation, requested_type='Bool'))

    def test_owned_ordinary_type_check(self):
        result = capture.validate_capture(fixture())
        self.assertEqual(result[0][0]['annotation']['owner_engine'], 'djinn')
        self.assertEqual(result[0][0]['backend_local_environment'], 2)

    def test_selected_row_limit_must_match_the_actual_capture(self):
        value = fixture()
        with self.assertRaisesRegex(ValueError, 'storage limits changed'):
            capture.validate_capture(value, expected_row_limit=512)
        value['request_capture']['row_limit'] = 512
        self.assertEqual(len(capture.validate_capture(value, expected_row_limit=512)), 1)

    def test_duplicate_request_owner(self):
        value = fixture()
        value['request_capture']['requests'] *= 2
        with self.assertRaisesRegex(ValueError, 'duplicated'):
            capture.validate_capture(value)

    def test_annotation_cannot_name_another_term(self):
        value = fixture()
        row = value['request_capture']['requests'][0]
        annotation = capture.strict_json(row['annotation_json'])
        annotation['candidate'] = 'Nat.zero'
        row['annotation_json'] = capture.canonical_json(annotation)
        row['annotation_utf8_bytes'] = len(row['annotation_json'].encode('utf-8'))
        with self.assertRaisesRegex(ValueError, 'verbatim'):
            capture.validate_capture(value)

    def test_another_backend_cannot_donate_response(self):
        value = fixture()
        value['events'][4]['backend_id'] = 2
        with self.assertRaisesRegex(ValueError, 'another backend'):
            capture.validate_capture(value)

    def test_incomplete_capture_is_not_acceptance(self):
        value = fixture()
        value['request_capture']['omitted_records'] = 1
        with self.assertRaisesRegex(ValueError, 'omitted'):
            capture.validate_capture(value)

    def test_missing_terminal_response(self):
        value = fixture()
        del value['events'][4]
        with self.assertRaisesRegex(ValueError, 'terminal'):
            capture.validate_capture(value)

    def test_missing_cleanup(self):
        value = fixture()
        value['events'].pop()
        with self.assertRaisesRegex(ValueError, 'lifecycle'):
            capture.validate_capture(value)

    def test_changed_byte_accounting(self):
        value = fixture()
        value['request_capture']['retained_bytes'] += 1
        with self.assertRaisesRegex(ValueError, 'accounting'):
            capture.validate_capture(value)

    def test_duplicate_json_fields(self):
        with self.assertRaisesRegex(ValueError, 'duplicate JSON'):
            capture.strict_json('{"cmd":"first","cmd":"second"}')

    def test_empty_environment_annotation_owns_only_empty_command(self):
        text = capture.canonical_json({'role': 'empty-user-environment'})
        self.assertEqual(capture.annotation_value(text, len(text), {'cmd': ''})[1],
            {'role': 'empty-user-environment'})
        with self.assertRaisesRegex(ValueError, 'different environment'):
            capture.annotation_value(text, len(text), {'cmd': '', 'env': 9})


if __name__ == '__main__':
    unittest.main()
