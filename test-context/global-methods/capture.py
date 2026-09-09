"""Bounded exact request/response correlation for public synthesis regressions.

Extracted from the exercised recursor trace validators. The checks retain
request/backend identity, complete lifecycle and byte/omission accounting.
"""
from pathlib import Path
import hashlib
import json
import re
import sys
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'test-context'))
import run_production as parser
runtime = parser.runtime

def source_paths():
    return sorted({*parser.source_inventory(), *Path(__file__).parent.rglob('*.py')})

CAPTURE_LIMITS = {"row_limit": 128, "payload_byte_limit": 256 * 1024,
                  "annotation_byte_limit": 8 * 1024, "total_byte_limit": 4 * 1024 * 1024}

OMISSION_REASONS = {*CAPTURE_LIMITS, "invalid_unicode"}

CAPTURE_KEYS = {"format", "encoding", *CAPTURE_LIMITS,
                "retained_bytes", "omitted_records", "omissions", "requests"}

ROW_KEYS = {"backend_id", "request_id", "capture_started_ns", "capture_completed_ns",
            "payload_utf8_bytes", "annotation_utf8_bytes", "payload_json", "annotation_json"}

ANNOTATION_KEYS = {"role", "requested_type", "candidate", "renderer_ordinal", "route", "owner_engine"}

CANDIDATE_ROLES = {"type-verification", "positive-decide", "negative-decide", "positive-simp", "negative-simp", "combined-decision"}


def combined_decision_subject(code, annotation):
    """Bind the complete checked-pair program to its annotated type and term.

    This validates request structure, not a successful response or proof. The
    caller must match the returned binder/predicate to the original query and
    independently replay the actual results.
    """
    prefix = ("set_option autoImplicit false in\n"
              "set_option maxHeartbeats 200000 in\n"
              "example : _root_.PSigma (fun ")
    if not code.startswith(prefix):
        raise ValueError("combined decision lost its checked pair or proof bounds")
    binder = re.match(r"([^\s:]+) : \(\n", code[len(prefix):])
    if binder is None:
        raise ValueError("combined decision lost its lexical candidate binder")
    prefix += binder[0] + annotation['requested_type'] + "\n) => _root_.Option (_root_.Decidable (\n"
    suffix = ("\n))) := by\n  refine ⟨(\n" + annotation['candidate'] + "\n  ), ?_⟩\n"
              "  first\n"
              "  | exact _root_.Option.some (_root_.Decidable.isTrue (by decide))\n"
              "    trace \"LEANT_BEHAVIOR_DECISION:1\"\n"
              "  | exact _root_.Option.some (_root_.Decidable.isFalse (by decide))\n"
              "    trace \"LEANT_BEHAVIOR_DECISION:2\"\n"
              "  | exact _root_.Option.none\n"
              "    trace \"LEANT_BEHAVIOR_DECISION:0\"\n")
    if not code.startswith(prefix) or not code.endswith(suffix) or len(code) <= len(prefix) + len(suffix):
        raise ValueError("combined decision changed its full type, candidate, or proof protocol")
    return binder[1], code[len(prefix):-len(suffix)]

TERMINAL_STAGES = {"TraceSendFailed", "TraceRequestTimedOut", "TraceResponseTransportFailed",
                   "TraceResponseParsed", "TraceResponseInvalidJson", "TraceRequestInterrupted"}

def request_inventory(trace):
    """Validate only identities actually retained by BackendTrace v1.

    It has no request payload/purpose tags. Capture-thread events intentionally
    have no request id; insertion order across threads is not clock order.
    Dropped prefixes may lack spawn/request starts. A killed process can leave
    only an earlier command-boundary snapshot, which is not the terminal wait.
    """
    events, capacity, dropped = trace["events"], trace["capacity"], trace["dropped_events"]
    if (trace["format"] != "leant-backend-trace-v1" or not isinstance(events, list)
            or type(capacity) is not int or not 0 <= capacity <= 16384
            or len(events) > capacity or type(dropped) is not int or dropped < 0):
        raise ValueError("invalid bounded backend trace")
    request_stages = {
        "TraceWriteStarted", "TraceWriteCompleted", "TraceFlushCompleted", "TraceSendFailed",
        "TraceResponseReadStarted", "TraceResponseFirstLine", "TraceResponseDelimiter",
        "TraceResponseReadCompleted", "TraceRequestTimedOut", "TraceResponseTransportFailed",
        "TraceResponseParsed", "TraceResponseInvalidJson", "TraceRequestInterrupted",
    }
    backend_stages = {
        "TraceSpawnStarted", "TracePipesReady", "TraceSpawnFailed", "TraceStdoutReadStarted",
        "TraceStdoutReadFailed", "TraceStdoutQueued", "TraceStdoutLineRead True",
        "TraceStdoutLineRead False", "TraceCleanupStarted", "TraceCleanupCompleted", "TraceCleanupFailed",
    }
    requests, spawns, backend_ids = {}, {}, set()
    for event in events:
        backend, request, stage, clock = (event["backend_id"], event["request_id"],
                                           event["stage"], event["monotonic_ns"])
        if (type(backend) is not int or backend <= 0 or type(clock) is not int or clock < 0
                or not isinstance(stage, str)):
            raise ValueError("invalid retained backend/event identity")
        backend_ids.add(backend)
        started = re.fullmatch(r"TraceRequestStarted (?:Nothing|\(Just -?\d+\))", stage) is not None
        if started or stage in request_stages:
            if type(request) is not int or request <= 0:
                raise ValueError("request event lacks its actual request identity")
            row = requests.setdefault(request, {"request_id": request, "backend_id": backend,
                                               "stages": [], "monotonic_ns": []})
            if row["backend_id"] != backend:
                raise ValueError("one request identity was reassigned to another backend")
            row["stages"].append(stage)
            row["monotonic_ns"].append(clock)
        else:
            if request is not None or (stage not in backend_stages and re.fullmatch(
                    r"TraceProcessCreated (?:Nothing|\(Just \d+\))", stage) is None):
                raise ValueError("unrecognized or incorrectly attributed backend event")
            if stage == "TraceSpawnStarted":
                spawns[backend] = spawns.get(backend, 0) + 1
    if not requests:
        raise ValueError("trace retained no request identities")
    for backend in backend_ids:
        if spawns.get(backend, 0) > 1 or (dropped == 0 and spawns.get(backend, 0) != 1):
            raise ValueError("backend identity has missing or duplicate spawn ownership")
    for row in requests.values():
        starts = sum(stage.startswith("TraceRequestStarted ") for stage in row["stages"])
        interrupted_before_start = row["stages"] == ["TraceRequestInterrupted"]
        if starts > 1 or (dropped == 0 and not interrupted_before_start
                          and (starts != 1 or not row["stages"][0].startswith("TraceRequestStarted "))):
            raise ValueError("request identity has missing or duplicate start ownership")
        row["start_retained"] = starts == 1
        clocks = row["monotonic_ns"]
        if any(left > right for left, right in zip(clocks, clocks[1:])):
            raise ValueError("one request's clock order went backwards")
    return list(requests.values())

def object_without_duplicates(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError("duplicate JSON field: " + key)
        result[key] = value
    return result

def strict_json(text):
    def reject_constant(value):
        raise ValueError("non-JSON numeric constant: " + value)
    return json.loads(text, object_pairs_hook=object_without_duplicates,
                      parse_constant=reject_constant)

def canonical_json(value):
    """Validate the observed compact protocol dialect, including control escapes.

    This runner's requests and callback annotations use null/bool/int/string,
    arrays and ordered objects. Unexpected floating-point fields are refused;
    they are not silently normalized to a different canonical representation.
    """
    if value is None:
        return "null"
    if type(value) is bool:
        return "true" if value else "false"
    if type(value) is int:
        return str(value)
    if isinstance(value, str):
        escaped = {"\"": "\\\"", "\\": "\\\\", "\n": "\\n", "\r": "\\r", "\t": "\\t"}
        return '"' + "".join(escaped.get(character, "\\u" + format(ord(character), "04x")
                              if ord(character) < 32 else character) for character in value) + '"'
    if isinstance(value, list):
        return "[" + ",".join(map(canonical_json, value)) + "]"
    if isinstance(value, dict):
        return "{" + ",".join(canonical_json(key) + ":" + canonical_json(item)
                                for key, item in value.items()) + "}"
    raise ValueError("unexpected value in canonical request JSON")

def canonical_bytes(text, observed_length, limit, label):
    if not isinstance(text, str) or type(observed_length) is not int:
        raise ValueError(label + " lacks exact canonical text/byte count")
    raw = text.encode("utf-8", errors="strict")
    if len(raw) != observed_length or not 0 < len(raw) <= limit:
        raise ValueError(label + " has inconsistent or out-of-bound UTF-8 bytes")
    decoded = strict_json(text)
    if canonical_json(decoded) != text:
        raise ValueError(label + " is not the exact canonical protocol representation")
    return raw, decoded

def annotation_value(text, size, payload):
    if text is None:
        if size != 0:
            raise ValueError("unlabelled request acquired annotation bytes")
        return None, None
    raw, annotation = canonical_bytes(text, size, CAPTURE_LIMITS["annotation_byte_limit"], "annotation")
    if annotation == {'role': 'empty-user-environment'}:
        if payload != {'cmd': ''}:
            raise ValueError('empty root annotation belongs to a different environment/program')
        return raw, annotation
    if not isinstance(annotation, dict) or set(annotation) != ANNOTATION_KEYS:
        raise ValueError("unexpected callback annotation schema")
    role = annotation["role"]
    if role not in {"syntax", "preflight", *CANDIDATE_ROLES}:
        raise ValueError("unknown actual callback role")
    if not isinstance(annotation["requested_type"], str) or not annotation["requested_type"]:
        raise ValueError("callback lost its complete requested type")
    if not isinstance(payload.get("cmd"), str):
        raise ValueError("callback annotation does not belong to a Lean command")
    if role in {"syntax", "preflight"}:
        if any(annotation[key] is not None for key in ("candidate", "renderer_ordinal", "route", "owner_engine")):
            raise ValueError("syntax/preflight acquired an invented candidate owner")
    else:
        if (not isinstance(annotation["candidate"], str) or not annotation["candidate"]
                or type(annotation["renderer_ordinal"]) is not int or annotation["renderer_ordinal"] < 0
                or annotation["route"] not in {"RouteUnobserved", "RouteLegacyCandidateFallback", "RouteTypedCandidate"}
                or annotation["owner_engine"] not in {None, "djinn", "exference"}):
            raise ValueError("candidate callback lost its exact variant fields")
        if annotation["route"] != "RouteTypedCandidate" and annotation["owner_engine"] is not None:
            raise ValueError("compatibility diagnostics recovered an opposing typed owner")
        if (annotation["candidate"] not in payload["cmd"]
                or annotation["requested_type"] not in payload["cmd"]):
            raise ValueError("candidate/type label does not occur verbatim in its actual command")
        if role == "combined-decision":
            combined_decision_subject(payload["cmd"], annotation)
    return raw, annotation

def validate_capture(trace, expected_row_limit=128):
    if type(expected_row_limit) is not int or not 0 <= expected_row_limit <= 1024:
        raise ValueError("invalid expected diagnostic row limit")
    limits = dict(CAPTURE_LIMITS, row_limit=expected_row_limit)
    if set(trace) != {"format", "clock", "capacity", "dropped_events", "events", "request_capture"}:
        raise ValueError("missing request capture or unexpected old/new transport format")
    inventory = request_inventory(trace)
    if trace["dropped_events"] != 0:
        raise ValueError("request correlation requires a complete retained event prefix")
    capture = trace["request_capture"]
    if (not isinstance(capture, dict) or set(capture) != CAPTURE_KEYS
            or capture["format"] != "leant-backend-request-capture-v1"
            or capture["encoding"] != "canonical encodeJson UTF-8 without protocol framing"):
        raise ValueError("missing or unsupported request-capture schema")
    if any(type(capture[key]) is not int or capture[key] != value for key, value in limits.items()):
        raise ValueError("request-capture storage limits changed")
    if (type(capture["omitted_records"]) is not int or capture["omitted_records"] != 0
            or not isinstance(capture["omissions"], dict) or set(capture["omissions"]) != OMISSION_REASONS
            or any(type(value) is not int or value != 0 for value in capture["omissions"].values())):
        raise ValueError("whole request records were omitted; payload capture is incomplete")
    rows = capture["requests"]
    if not isinstance(rows, list) or not 0 < len(rows) <= limits["row_limit"]:
        raise ValueError("invalid captured request inventory")
    requests = {row["request_id"]: row for row in inventory}
    if sorted(requests) != list(range(1, len(requests) + 1)):
        raise ValueError("the terminal trace lost an allocated request identity")
    backend_events = {}
    for event in trace["events"]:
        backend_events.setdefault(event["backend_id"], []).append(event)
    if sorted(backend_events) != list(range(1, len(backend_events) + 1)):
        raise ValueError("the terminal trace lost an allocated backend identity")
    for events in backend_events.values():
        stages = [event["stage"] for event in events]
        if "TraceCleanupFailed" in stages or (stages.count("TraceSpawnFailed") != 1
                and stages.count("TraceCleanupCompleted") != 1):
            raise ValueError("snapshot does not contain a completed owned-backend lifecycle")
    seen, total, prepared = set(), 0, []
    for row in rows:
        if not isinstance(row, dict) or set(row) != ROW_KEYS:
            raise ValueError("unexpected captured request row schema")
        backend, identifier = row["backend_id"], row["request_id"]
        if type(backend) is not int or type(identifier) is not int or identifier in seen:
            raise ValueError("captured request ownership is invalid or duplicated")
        actual = requests.get(identifier)
        if actual is None or actual["backend_id"] != backend or not actual["start_retained"]:
            raise ValueError("captured request does not own its actual event identity")
        seen.add(identifier)
        stages, clocks = actual["stages"], actual["monotonic_ns"]
        if stages[-1] not in TERMINAL_STAGES or stages.count("TraceWriteStarted") != 1:
            raise ValueError("captured invocation has no complete send/terminal boundary")
        if any(type(row[key]) is not int or row[key] < 0
               for key in ("capture_started_ns", "capture_completed_ns", "annotation_utf8_bytes")):
            raise ValueError("invalid capture clocks or byte count")
        write_start = clocks[stages.index("TraceWriteStarted")]
        if not clocks[0] <= row["capture_started_ns"] <= row["capture_completed_ns"] <= write_start:
            raise ValueError("capture interval does not belong to its request/send interval")
        raw, payload = canonical_bytes(row["payload_json"], row["payload_utf8_bytes"],
                                        CAPTURE_LIMITS["payload_byte_limit"], "payload")
        if not isinstance(payload, dict):
            raise ValueError("captured REPL request is not a protocol object")
        annotation_raw, annotation = annotation_value(row["annotation_json"], row["annotation_utf8_bytes"], payload)
        total += len(raw) + (len(annotation_raw) if annotation_raw is not None else 0)
        item = {"backend_id": backend, "request_id": identifier, "stages": stages,
                "monotonic_ns": clocks, "start_ns": clocks[0], "terminal_ns": clocks[-1],
                "request_duration_ns": clocks[-1] - clocks[0],
                "capture_started_ns": row["capture_started_ns"],
                "capture_completed_ns": row["capture_completed_ns"],
                "capture_duration_ns": row["capture_completed_ns"] - row["capture_started_ns"],
                "annotation": annotation, "backend_local_environment": payload.get("env"),
                "payload_utf8_bytes": len(raw), "annotation_utf8_bytes": row["annotation_utf8_bytes"]}
        if "TraceRequestTimedOut" in stages:
            timed_out = clocks[stages.index("TraceRequestTimedOut")]
            later_lines = [event["monotonic_ns"] for event in backend_events[backend]
                           if event["stage"] == "TraceStdoutLineRead False" and event["monotonic_ns"] > timed_out]
            item["timeout_ns"] = timed_out
            item["first_backend_stdout_line_after_timeout_ns"] = min(later_lines) if later_lines else None
            item["late_output_note"] = "backend-owned observation only; no response is reassigned to a request"
            if any(other["backend_id"] == backend and other["monotonic_ns"][0] > timed_out
                   for other in inventory if other["start_retained"]):
                raise ValueError("a timed-out production backend was reused instead of retired")
        prepared.append((item, raw, annotation_raw, payload.get("cmd")))
    if seen != set(requests):
        raise ValueError("request events and full snapshots do not have an exact identity bijection")
    if type(capture["retained_bytes"]) is not int or total != capture["retained_bytes"] or total > CAPTURE_LIMITS["total_byte_limit"]:
        raise ValueError("aggregate payload/annotation byte accounting disagrees")
    return sorted(prepared, key=lambda item: item[0]["request_id"])

def export_requests(directory, label, prepared):
    output = directory / (label + ".requests")
    output.mkdir(exist_ok=False)
    exported, files = [], []

    def save_bytes(path, raw):
        with path.open("xb") as handle:
            handle.write(raw)
        record = {"path": str(path), "sha256": hashlib.sha256(raw).hexdigest(), "bytes": len(raw)}
        if runtime.sha256(path) != record["sha256"]:
            raise ValueError("local request extraction changed during write")
        files.append(record)
        return record

    for item, payload, annotation, code in prepared:
        prefix = f"b{item['backend_id']:04d}-r{item['request_id']:06d}"
        item["payload_file"] = save_bytes(output / (prefix + ".payload.json"), payload)
        item["annotation_file"] = (save_bytes(output / (prefix + ".annotation.json"), annotation)
                                   if annotation is not None else None)
        if code is not None:
            if not isinstance(code, str):
                raise ValueError("command payload has a non-string cmd field")
            item["command_file"] = save_bytes(output / (prefix + ".cmd.lean"), code.encode("utf-8", errors="strict"))
        exported.append(item)
    return exported, files
