#!/usr/bin/env python3
"""End-to-end benchmarks for Leant's isolated synthesis verification.

The default protocol compares the exact pre-cache baseline and a candidate
binary at both one and two RTS capabilities.  The opt-in ``scaled-pool``
protocol screens the bounded two-to-four-worker verification pool at fixed
N1, N2, and N4.  Linux /proc sampling reports aggregate process-tree CPU and
resident memory; strace proves the selected ordered isolated-verification
topology before either protocol records timings.
"""

from __future__ import annotations

import argparse
import hashlib
import math
import os
from pathlib import Path
import platform
import re
import shutil
import signal
import statistics
import subprocess
import sys
import tempfile
import time
from dataclasses import dataclass
from typing import BinaryIO, Iterable, Sequence


SCRIPT_DIR = Path(__file__).resolve().parent
WORKLOADS = (
    ("state-thread", SCRIPT_DIR / "state-thread.txt"),
    ("continuation", SCRIPT_DIR / "continuation.txt"),
    ("library-map", SCRIPT_DIR / "library-map.txt"),
)
SCALED_POOL_WORKLOADS = WORKLOADS[:2]
SHORT_BATCH_FIXTURE = (
    SCRIPT_DIR.parent
    / "test"
    / "parallel-verification"
    / "history-free-multi-group.txt"
)
LATIN_ROWS = (
    ("B1", "B2", "C2", "C1"),
    ("B2", "C1", "B1", "C2"),
    ("C1", "C2", "B2", "B1"),
    ("C2", "B1", "C1", "B2"),
)
SCALED_POOL_CELL_ORDER = ("B1", "C1", "B2", "C2", "B4", "C4")
# The first row is the standard even-order Williams construction
# A, B, F, C, E, D.  Cyclic relabeling produces all six rows and makes every
# ordered pair of distinct treatments adjacent exactly once.
SCALED_POOL_WILLIAMS_ROWS = tuple(
    tuple(
        SCALED_POOL_CELL_ORDER[(ordinal + shift) % 6]
        for ordinal in (0, 1, 5, 2, 4, 3)
    )
    for shift in range(6)
)
COLD_ROWS = (
    ("D1", "D2"),
    ("D2", "D1"),
)
PRIMARY_WORKLOADS = ("state-thread", "continuation")
SCALED_POOL_WARMUPS = 1
SCALED_POOL_SAMPLES = 5
SCALED_POOL_MINIMUM_SPEEDUP = 1.10
SCALED_POOL_MAXIMUM_MEDIAN_REGRESSION = 1.05
SCALED_POOL_MAXIMUM_P95_REGRESSION = 1.10
SCALED_POOL_MAXIMUM_ALLOCATION_RATIO = 1.10
SCALED_POOL_MAXIMUM_CPU_RATIO = 1.25
SCALED_POOL_MAXIMUM_RSS_RATIO = 1.25
STARTUP_PREFIXES = (
    "no Lake project",
    "starting Lean backend",
    "backend responding",
    "replaying session",
)
ALLOCATED_RE = re.compile(
    rb"^\s*([0-9][0-9,]*) bytes allocated in the heap\s*$",
    re.MULTILINE,
)
CANDIDATE_RE = re.compile(r"^\s*(it[0-9]+)\s{2}", re.MULTILINE)
QUEUE_COUNT_RE = re.compile(r"queue limit pruned [0-9]+")
GIT_COMMIT_RE = re.compile(r"^[0-9a-f]{40}$")


class BenchmarkFailure(RuntimeError):
    """A semantic, routing, or execution invariant failed."""


@dataclass(frozen=True)
class Cell:
    name: str
    executable: Path
    capabilities: int
    expected_backends: int
    expected_cache_modules: int


@dataclass(frozen=True)
class ProcSample:
    ppid: int
    start_time: int
    cpu_ticks: int
    rss_kib: int


@dataclass(frozen=True)
class RunResult:
    workload: str
    sample: int
    cell: str
    wall_seconds: float
    cpu_seconds: float
    peak_rss_kib: int
    allocated_bytes: int
    transcript_hash: str


@dataclass(frozen=True)
class PreflightResult:
    debug_transcript: bytes
    semantic_transcript: bytes
    trace_text: str


def positive_int(raw: str) -> int:
    value = int(raw)
    if value <= 0:
        raise argparse.ArgumentTypeError("expected a positive integer")
    return value


def nonnegative_int(raw: str) -> int:
    value = int(raw)
    if value < 0:
        raise argparse.ArgumentTypeError("expected a nonnegative integer")
    return value


def executable_path(raw: str) -> Path:
    path = Path(raw).expanduser().resolve()
    if not path.is_file() or not os.access(path, os.X_OK):
        raise argparse.ArgumentTypeError(f"not an executable file: {raw}")
    return path


def exact_git_commit(raw: str) -> str:
    if GIT_COMMIT_RE.fullmatch(raw) is None:
        raise argparse.ArgumentTypeError(
            "expected an exact 40-character lowercase hexadecimal commit"
        )
    return raw


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "benchmark baseline and candidate isolated verification; the "
            "default compiled-cache protocol uses N1/N2"
        ),
    )
    parser.add_argument(
        "--protocol",
        choices=("compiled-cache", "scaled-pool"),
        default="compiled-cache",
        help=(
            "benchmark protocol (default: compiled-cache); scaled-pool is "
            "the fixed N1/N2/N4 five-sample retention screen"
        ),
    )
    for role, repository in (
        ("baseline", "leant"),
        ("candidate", "leant"),
        ("baseline", "djex"),
        ("candidate", "djex"),
    ):
        option = f"--{role}-{repository}-commit"
        parser.add_argument(
            option,
            type=exact_git_commit,
            metavar="COMMIT",
            help=(
                f"exact {role} {repository.capitalize()} commit; "
                "required by --protocol scaled-pool"
            ),
        )
    parser.add_argument(
        "--baseline",
        type=executable_path,
        default=os.environ.get("LEANT_VERIFICATION_BASELINE_EXE"),
        required="LEANT_VERIFICATION_BASELINE_EXE" not in os.environ,
    )
    parser.add_argument(
        "--candidate",
        type=executable_path,
        default=os.environ.get("LEANT_VERIFICATION_CANDIDATE_EXE"),
        required="LEANT_VERIFICATION_CANDIDATE_EXE" not in os.environ,
    )
    parser.add_argument(
        "--backend",
        type=executable_path,
        default=os.environ.get("LEANT_BACKEND"),
        required="LEANT_BACKEND" not in os.environ,
    )
    parser.add_argument(
        "--samples",
        type=positive_int,
        default=int(os.environ.get("LEANT_VERIFICATION_BENCH_SAMPLES", "5")),
    )
    parser.add_argument(
        "--warmups",
        type=nonnegative_int,
        default=int(os.environ.get("LEANT_VERIFICATION_BENCH_WARMUPS", "1")),
    )
    parser.add_argument(
        "--timeout",
        type=positive_int,
        default=int(os.environ.get("LEANT_VERIFICATION_BENCH_TIMEOUT", "900")),
        help="seconds allowed for one Leant process",
    )
    parser.add_argument(
        "--sample-interval-ms",
        type=positive_int,
        default=int(
            os.environ.get("LEANT_VERIFICATION_BENCH_INTERVAL_MS", "20")
        ),
        help="Linux /proc process-tree sampling interval",
    )
    parser.add_argument(
        "--results",
        type=Path,
        help="copy the raw TSV result table to this path",
    )
    parser.add_argument(
        "--artifacts",
        type=Path,
        help="copy successful preflight traces and raw run output to this new directory",
    )
    parser.add_argument(
        "--enforce",
        action="store_true",
        help=(
            "return failure when the selected protocol's documented "
            "thresholds fail"
        ),
    )
    parser.add_argument(
        "--minimum-speedup",
        type=float,
        default=1.25,
    )
    parser.add_argument(
        "--maximum-n1-regression",
        type=float,
        default=1.05,
    )
    parser.add_argument(
        "--maximum-allocation-ratio",
        type=float,
        default=1.10,
    )
    parser.add_argument(
        "--maximum-cpu-ratio",
        type=float,
        default=1.25,
    )
    parser.add_argument(
        "--maximum-rss-ratio",
        type=float,
        default=1.25,
    )
    parser.add_argument(
        "--maximum-cold-regression",
        type=float,
        default=1.05,
    )
    parser.add_argument(
        "--maximum-cold-p95-ratio",
        type=float,
        default=1.10,
    )
    parser.add_argument(
        "--baseline-cold-cache-modules",
        type=int,
        choices=(0, 1),
        default=0,
        help=(
            "compiled modules expected after a cold baseline N1 run; "
            "use 1 when the baseline already contains the tooling cache"
        ),
    )
    parser.add_argument(
        "--candidate-n2-initializer",
        choices=("artifact", "pristine-replay"),
        default="artifact",
        help=(
            "route which candidate N2 preflight must prove for isolated "
            "verification workers"
        ),
    )
    return parser.parse_args()


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        while chunk := handle.read(1024 * 1024):
            digest.update(chunk)
    return digest.hexdigest()


def host_and_effective_cpu_counts() -> tuple[int | None, int | None]:
    host_count = os.cpu_count()
    affinity = getattr(os, "sched_getaffinity", None)
    if affinity is not None:
        try:
            return host_count, len(affinity(0))
        except (OSError, NotImplementedError):
            pass
    return host_count, host_count


def normalize_transcript(raw: bytes, *, remove_debug: bool) -> bytes:
    text = raw.decode("utf-8", errors="strict").replace("\r", "")
    normalized: list[str] = []
    for raw_line in text.splitlines():
        line = raw_line.rstrip()
        if any(line.startswith(prefix) for prefix in STARTUP_PREFIXES):
            continue
        if remove_debug and line.startswith("debug "):
            continue
        normalized.append(QUEUE_COUNT_RE.sub(
            "queue limit pruned <machine-dependent>", line
        ))
    return ("\n".join(normalized) + "\n").encode("utf-8")


def assert_candidates(
    transcript: bytes,
    expected_count: int,
    label: str,
) -> None:
    names = CANDIDATE_RE.findall(transcript.decode("utf-8"))
    expected = [f"it{ordinal}" for ordinal in range(1, expected_count + 1)]
    if names != expected:
        raise BenchmarkFailure(
            f"{label}: expected candidates {expected}, observed {names}"
        )


def assert_five_candidates(transcript: bytes, label: str) -> None:
    assert_candidates(transcript, 5, label)


def base_environment(
    backend: Path,
    temporary: Path,
    tooling_cache: Path,
    *,
    debug: bool,
) -> dict[str, str]:
    environment = os.environ.copy()
    environment.pop("GHCRTS", None)
    environment.pop("LEANT_SYNTH_DEBUG", None)
    environment["LEANT_BACKEND"] = str(backend)
    environment["LEANT_SYNTH_TIMEOUT"] = "600"
    environment["TMPDIR"] = str(temporary)
    environment["XDG_CACHE_HOME"] = str(tooling_cache)
    environment["LC_ALL"] = "C"
    environment["LANG"] = "C"
    environment["TZ"] = "UTC"
    if debug:
        environment["LEANT_SYNTH_DEBUG"] = "1"
    return environment


def signal_matching_processes(
    samples: dict[int, ProcSample], selected_signal: signal.Signals
) -> None:
    current = read_process_table()
    for pid, sample in samples.items():
        observed = current.get(pid)
        if observed is None or observed.start_time != sample.start_time:
            continue
        try:
            os.kill(pid, selected_signal)
        except ProcessLookupError:
            pass


def terminate_process_tree(process: subprocess.Popen[bytes]) -> None:
    """Boundedly stop the benchmark root and every observed descendant.

    Leant gives each Lean backend its own process group.  Killing only the
    benchmark root can therefore orphan backend wrappers or servers if the
    root does not get a chance to run its structured cleanup.  Retain process
    start times so a recycled PID is never signalled.
    """

    observed = descendant_samples(process.pid)
    if process.poll() is None:
        try:
            process.send_signal(signal.SIGTERM)
        except ProcessLookupError:
            pass
    deadline = time.monotonic() + 10.0
    while process.poll() is None and time.monotonic() < deadline:
        observed.update(descendant_samples(process.pid))
        time.sleep(0.05)
    signal_matching_processes(observed, signal.SIGTERM)
    time.sleep(0.25)
    signal_matching_processes(observed, signal.SIGKILL)
    if process.poll() is None:
        try:
            process.kill()
        except ProcessLookupError:
            pass
    try:
        process.wait(timeout=30)
    except subprocess.TimeoutExpired as failure:
        raise BenchmarkFailure("benchmark process tree did not terminate") from failure


def communicate_before(
    command: Sequence[str],
    fixture: Path,
    environment: dict[str, str],
    timeout_seconds: int,
) -> tuple[int, bytes]:
    process = subprocess.Popen(
        command,
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        env=environment,
    )
    try:
        output, _ = process.communicate(
            fixture.read_bytes(), timeout=timeout_seconds
        )
    except subprocess.TimeoutExpired as failure:
        terminate_process_tree(process)
        raise BenchmarkFailure(
            f"command timed out after {timeout_seconds}s: {command!r}"
        ) from failure
    return process.returncode, output


def assert_no_artifact_leak(temporary: Path, label: str) -> None:
    leaks = list(temporary.rglob("leant-parallel-verification*"))
    if leaks:
        raise BenchmarkFailure(f"{label}: leaked artifacts: {leaks}")


def tooling_cache_modules(tooling_cache: Path) -> list[Path]:
    return sorted(
        (
            tooling_cache
            / "leant"
            / "synthesis-tooling-v1"
            / "LeantSynthCache"
        ).glob("K*.olean")
    )


def assert_tooling_cache_modules(
    tooling_cache: Path,
    expected: int,
    label: str,
) -> list[Path]:
    modules = tooling_cache_modules(tooling_cache)
    if len(modules) != expected:
        raise BenchmarkFailure(
            f"{label}: observed {len(modules)} compiled tooling modules, "
            f"expected {expected}"
        )
    return modules


def preflight_workload(
    name: str,
    fixture: Path,
    cells: dict[str, Cell],
    backend: Path,
    root: Path,
    tooling_cache: Path,
    timeout_seconds: int,
    baseline_cache_modules: int,
    candidate_n2_initializer: str,
) -> str:
    expected_debug: bytes | None = None
    expected_semantic: bytes | None = None
    for cell_name in ("B1", "B2", "C1", "C2"):
        cell = cells[cell_name]
        run_root = root / f"preflight {name} {cell_name}"
        temporary = run_root / "temporary artifacts with spaces"
        temporary.mkdir(parents=True)
        trace = run_root / "backend-exec.trace"
        command = (
            "strace",
            "-f",
            "-qq",
            "-e",
            "trace=execve,openat",
            "-s",
            "4096",
            "-o",
            str(trace),
            "--",
            str(cell.executable),
            "--plain",
            "+RTS",
            f"-N{cell.capabilities}",
            "-RTS",
        )
        return_code, output = communicate_before(
            command,
            fixture,
            base_environment(
                backend, temporary, tooling_cache, debug=True
            ),
            timeout_seconds,
        )
        if return_code != 0:
            raise BenchmarkFailure(
                f"preflight {name}/{cell_name} exited {return_code}:\n"
                + output.decode("utf-8", errors="replace")
            )
        assert_no_artifact_leak(temporary, f"preflight {name}/{cell_name}")
        debug_transcript = normalize_transcript(output, remove_debug=False)
        semantic_transcript = normalize_transcript(output, remove_debug=True)
        assert_five_candidates(
            semantic_transcript, f"preflight {name}/{cell_name}"
        )
        debug_text = debug_transcript.decode("utf-8")
        for metric in (
            "debug metric: lean-variant-attempted=5",
            "debug metric: lean-candidate-verified=5",
        ):
            if debug_text.count(metric) != 1:
                raise BenchmarkFailure(
                    f"preflight {name}/{cell_name}: expected one {metric!r}"
                )
        trace_text = trace.read_text(encoding="utf-8", errors="strict")
        backend_count = trace_text.count(f'execve("{backend}"')
        if backend_count != cell.expected_backends:
            raise BenchmarkFailure(
                f"preflight {name}/{cell_name}: launched {backend_count} "
                f"backends, expected {cell.expected_backends}"
            )
        if expected_debug is None:
            expected_debug = debug_transcript
            expected_semantic = semantic_transcript
        elif debug_transcript != expected_debug:
            raise BenchmarkFailure(
                f"preflight {name}/{cell_name}: debug transcript hash "
                f"{sha256_bytes(debug_transcript)} differs from "
                f"{sha256_bytes(expected_debug)}"
            )
        print(
            f"ok   preflight {name:13s} {cell_name} "
            f"({backend_count} backend{'s' if backend_count != 1 else ''})"
        )
    cache_modules = assert_tooling_cache_modules(
        tooling_cache,
        1,
        f"preflight {name}",
    )
    traces = {
        cell_name: (
            root / f"preflight {name} {cell_name}" / "backend-exec.trace"
        ).read_text(encoding="utf-8", errors="strict")
        for cell_name in ("B2", "C2")
    }
    exact_module = f'"{cache_modules[0]}"'
    expected_module_opens = {
        "B2": baseline_cache_modules,
        "C2": 1,
    }
    for cell_name in ("B2", "C2"):
        module_opens = traces[cell_name].count(exact_module)
        expected_opens = expected_module_opens[cell_name]
        if module_opens != expected_opens:
            raise BenchmarkFailure(
                f"preflight {name}/{cell_name}: opened the exact compiled "
                f"tooling module {module_opens} times, expected "
                f"{expected_opens}"
            )
    artifact_marker = "leant-parallel-verification"
    if artifact_marker not in traces["B2"]:
        raise BenchmarkFailure(
            f"preflight {name}/B2 did not exercise the baseline artifact route"
        )
    candidate_has_artifact = artifact_marker in traces["C2"]
    expected_candidate_artifact = candidate_n2_initializer == "artifact"
    if candidate_has_artifact != expected_candidate_artifact:
        expected = "present" if expected_candidate_artifact else "absent"
        actual = "present" if candidate_has_artifact else "absent"
        raise BenchmarkFailure(
            f"preflight {name}/C2 verification artifact was {actual}; "
            f"expected {expected} for {candidate_n2_initializer}"
        )
    assert expected_semantic is not None
    transcript_hash = sha256_bytes(expected_semantic)
    print(f"ok   preflight {name:13s} semantic sha256 {transcript_hash}")
    return transcript_hash


def validate_scaled_pool_design() -> None:
    """Fail closed if the checked-in six-treatment design is malformed."""

    expected_cells = set(SCALED_POOL_CELL_ORDER)
    if len(SCALED_POOL_WILLIAMS_ROWS) != len(expected_cells):
        raise BenchmarkFailure("scaled-pool design must contain six rows")
    carryover: dict[tuple[str, str], int] = {}
    for row in SCALED_POOL_WILLIAMS_ROWS:
        if len(row) != len(expected_cells) or set(row) != expected_cells:
            raise BenchmarkFailure(
                f"scaled-pool Williams row is not a permutation: {row!r}"
            )
        for pair in zip(row, row[1:]):
            carryover[pair] = carryover.get(pair, 0) + 1
    expected_pairs = {
        (left, right)
        for left in expected_cells
        for right in expected_cells
        if left != right
    }
    if set(carryover) != expected_pairs or any(
        count != 1 for count in carryover.values()
    ):
        raise BenchmarkFailure(
            "scaled-pool Williams design does not balance ordered carryover"
        )
    for workload_index, _ in enumerate(SCALED_POOL_WORKLOADS):
        scheduled = [SCALED_POOL_WILLIAMS_ROWS[workload_index]] + [
            SCALED_POOL_WILLIAMS_ROWS[
                (sample_number + workload_index)
                % len(SCALED_POOL_WILLIAMS_ROWS)
            ]
            for sample_number in range(1, SCALED_POOL_SAMPLES + 1)
        ]
        if set(scheduled) != set(SCALED_POOL_WILLIAMS_ROWS):
            raise BenchmarkFailure(
                "scaled-pool warmup and sample schedule must use every "
                "Williams row once per workload"
            )


def scaled_pool_preflight_cell(
    workload: str,
    fixture: Path,
    expected_candidates: int,
    cell: Cell,
    backend: Path,
    root: Path,
    tooling_cache: Path,
    timeout_seconds: int,
    *,
    expected_backends: int | None = None,
) -> PreflightResult:
    run_root = root / f"scaled preflight {workload} {cell.name}"
    temporary = run_root / "temporary artifacts with spaces"
    temporary.mkdir(parents=True)
    trace = run_root / "backend-exec.trace"
    command = (
        "strace",
        "-f",
        "-qq",
        "-e",
        "trace=execve,openat",
        "-s",
        "4096",
        "-o",
        str(trace),
        "--",
        str(cell.executable),
        "--plain",
        "+RTS",
        f"-N{cell.capabilities}",
        "-RTS",
    )
    return_code, output = communicate_before(
        command,
        fixture,
        base_environment(backend, temporary, tooling_cache, debug=True),
        timeout_seconds,
    )
    if return_code != 0:
        raise BenchmarkFailure(
            f"scaled preflight {workload}/{cell.name} exited "
            f"{return_code}:\n"
            + output.decode("utf-8", errors="replace")
        )
    label = f"scaled preflight {workload}/{cell.name}"
    assert_no_artifact_leak(temporary, label)
    debug_transcript = normalize_transcript(output, remove_debug=False)
    semantic_transcript = normalize_transcript(output, remove_debug=True)
    assert_candidates(semantic_transcript, expected_candidates, label)
    debug_text = debug_transcript.decode("utf-8")
    for metric in (
        f"debug metric: lean-variant-attempted={expected_candidates}",
        f"debug metric: lean-candidate-verified={expected_candidates}",
    ):
        if debug_text.count(metric) != 1:
            raise BenchmarkFailure(f"{label}: expected one {metric!r}")
    trace_text = trace.read_text(encoding="utf-8", errors="strict")
    backend_count = trace_text.count(f'execve("{backend}"')
    backend_oracle = (
        cell.expected_backends
        if expected_backends is None
        else expected_backends
    )
    if backend_count != backend_oracle:
        raise BenchmarkFailure(
            f"{label}: launched {backend_count} backends, expected "
            f"{backend_oracle}"
        )
    artifact_marker = "leant-parallel-verification"
    artifact_route = artifact_marker in trace_text
    expected_artifact_route = backend_oracle > 1
    if artifact_route != expected_artifact_route:
        actual = "present" if artifact_route else "absent"
        expected = "present" if expected_artifact_route else "absent"
        raise BenchmarkFailure(
            f"{label}: verification artifact route was {actual}, "
            f"expected {expected}"
        )
    print(
        f"ok   scaled preflight {workload:13s} {cell.name} "
        f"({backend_count} backend{'s' if backend_count != 1 else ''})"
    )
    return PreflightResult(
        debug_transcript=debug_transcript,
        semantic_transcript=semantic_transcript,
        trace_text=trace_text,
    )


def assert_exact_module_open_count(
    result: PreflightResult,
    module: Path,
    expected: int,
    label: str,
) -> None:
    actual = result.trace_text.count(f'"{module}"')
    if actual != expected:
        raise BenchmarkFailure(
            f"{label}: opened the exact compiled tooling module {actual} "
            f"times, expected {expected}"
        )


def assert_same_preflight_transcripts(
    reference: PreflightResult,
    observed: PreflightResult,
    label: str,
) -> None:
    if observed.debug_transcript != reference.debug_transcript:
        raise BenchmarkFailure(
            f"{label}: debug transcript hash "
            f"{sha256_bytes(observed.debug_transcript)} differs from "
            f"{sha256_bytes(reference.debug_transcript)}"
        )
    if observed.semantic_transcript != reference.semantic_transcript:
        raise BenchmarkFailure(
            f"{label}: semantic transcript hash "
            f"{sha256_bytes(observed.semantic_transcript)} differs from "
            f"{sha256_bytes(reference.semantic_transcript)}"
        )


def scaled_pool_preflight(
    cells: dict[str, Cell],
    backend: Path,
    root: Path,
    tooling_cache: Path,
    timeout_seconds: int,
) -> dict[str, str]:
    """Prove cache, semantic, debug, topology, and cleanup invariants."""

    assert_tooling_cache_modules(
        tooling_cache, 0, "scaled-pool initial cache"
    )
    short_reference = scaled_pool_preflight_cell(
        "SB1",
        SHORT_BATCH_FIXTURE,
        2,
        cells["B1"],
        backend,
        root,
        tooling_cache,
        timeout_seconds,
    )
    modules = assert_tooling_cache_modules(
        tooling_cache, 1, "scaled-pool SB1 cache prime"
    )
    module = modules[0]
    module_checksum = sha256_file(module)
    assert_exact_module_open_count(
        short_reference,
        module,
        0,
        "scaled preflight SB1/B1",
    )
    for short_name, cell_name, backend_override in (
        ("SB4", "B4", None),
        ("SC1", "C1", None),
        ("SC4", "C4", 3),
    ):
        observed = scaled_pool_preflight_cell(
            short_name,
            SHORT_BATCH_FIXTURE,
            2,
            cells[cell_name],
            backend,
            root,
            tooling_cache,
            timeout_seconds,
            expected_backends=backend_override,
        )
        label = f"scaled preflight {short_name}/{cell_name}"
        assert_same_preflight_transcripts(short_reference, observed, label)
        current_modules = assert_tooling_cache_modules(
            tooling_cache, 1, label
        )
        if (
            current_modules[0] != module
            or sha256_file(module) != module_checksum
        ):
            raise BenchmarkFailure(
                f"{label}: replaced the shared cache module"
            )
        assert_exact_module_open_count(observed, module, 1, label)
    print(
        "ok   scaled preflight short-batch semantic sha256 "
        f"{sha256_bytes(short_reference.semantic_transcript)}"
    )
    print(
        "ok   scaled preflight shared module "
        f"{module} sha256 {module_checksum}; "
        "SB1/SB4/SC1/SC4 opens 0/1/1/1"
    )

    expected_hashes: dict[str, str] = {}
    for workload, fixture in SCALED_POOL_WORKLOADS:
        reference: PreflightResult | None = None
        for cell_name in SCALED_POOL_CELL_ORDER:
            result = scaled_pool_preflight_cell(
                workload,
                fixture,
                5,
                cells[cell_name],
                backend,
                root,
                tooling_cache,
                timeout_seconds,
            )
            if reference is None:
                reference = result
            else:
                assert_same_preflight_transcripts(
                    reference,
                    result,
                    f"scaled preflight {workload}/{cell_name}",
                )
            current_modules = assert_tooling_cache_modules(
                tooling_cache, 1, f"scaled preflight {workload}/{cell_name}"
            )
            if (
                current_modules[0] != module
                or sha256_file(module) != module_checksum
            ):
                raise BenchmarkFailure(
                    f"scaled preflight {workload}/{cell_name} replaced "
                    "the shared cache module"
                )
            assert_exact_module_open_count(
                result,
                module,
                1,
                f"scaled preflight {workload}/{cell_name}",
            )
        if reference is None:
            raise BenchmarkFailure(
                f"scaled preflight {workload}: no cells were executed"
            )
        transcript_hash = sha256_bytes(reference.semantic_transcript)
        expected_hashes[workload] = transcript_hash
        print(
            f"ok   scaled preflight {workload:13s} semantic sha256 "
            f"{transcript_hash}"
        )
    return expected_hashes


def read_process_table() -> dict[int, ProcSample]:
    table: dict[int, ProcSample] = {}
    page_kib = os.sysconf("SC_PAGE_SIZE") // 1024
    for entry in Path("/proc").iterdir():
        if not entry.name.isdigit():
            continue
        try:
            stat = (entry / "stat").read_text(encoding="ascii")
        except (FileNotFoundError, PermissionError, ProcessLookupError):
            continue
        close = stat.rfind(")")
        if close < 0:
            continue
        fields = stat[close + 2 :].split()
        try:
            table[int(entry.name)] = ProcSample(
                ppid=int(fields[1]),
                start_time=int(fields[19]),
                cpu_ticks=int(fields[11]) + int(fields[12]),
                rss_kib=max(0, int(fields[21])) * page_kib,
            )
        except (IndexError, ValueError):
            continue
    return table


def descendant_samples(root_pid: int) -> dict[int, ProcSample]:
    table = read_process_table()
    descendants = {root_pid}
    changed = True
    while changed:
        changed = False
        for pid, sample in table.items():
            if pid not in descendants and sample.ppid in descendants:
                descendants.add(pid)
                changed = True
    return {pid: table[pid] for pid in descendants if pid in table}


def parse_allocated_bytes(stderr: bytes, label: str) -> int:
    matches = ALLOCATED_RE.findall(stderr)
    if len(matches) != 1:
        raise BenchmarkFailure(
            f"{label}: expected one GHC allocation total, observed {len(matches)}"
        )
    return int(matches[0].replace(b",", b""))


def measure_cell(
    workload: str,
    fixture: Path,
    sample_number: int,
    cell: Cell,
    backend: Path,
    root: Path,
    expected_hash: str,
    timeout_seconds: int,
    interval_seconds: float,
    tooling_cache: Path,
) -> RunResult:
    run_root = root / f"sample {sample_number} {workload} {cell.name}"
    temporary = run_root / "temporary artifacts with spaces"
    temporary.mkdir(parents=True)
    stdout_path = run_root / "transcript.raw"
    stderr_path = run_root / "rts.stderr"
    command = (
        str(cell.executable),
        "--plain",
        "+RTS",
        f"-N{cell.capabilities}",
        "-s",
        "-RTS",
    )
    peak_rss_kib = 0
    observed_cpu: dict[tuple[int, int], int] = {}
    sample_count = 0
    with fixture.open("rb") as stdin_handle, stdout_path.open(
        "wb"
    ) as stdout_handle, stderr_path.open("wb") as stderr_handle:
        started = time.monotonic()
        process = subprocess.Popen(
            command,
            stdin=stdin_handle,
            stdout=stdout_handle,
            stderr=stderr_handle,
            env=base_environment(
                backend, temporary, tooling_cache, debug=False
            ),
        )
        try:
            while True:
                samples = descendant_samples(process.pid)
                if samples:
                    sample_count += 1
                    peak_rss_kib = max(
                        peak_rss_kib,
                        sum(sample.rss_kib for sample in samples.values()),
                    )
                    for pid, proc_sample in samples.items():
                        key = (pid, proc_sample.start_time)
                        observed_cpu[key] = max(
                            observed_cpu.get(key, 0), proc_sample.cpu_ticks
                        )
                return_code = process.poll()
                if return_code is not None:
                    break
                if time.monotonic() - started > timeout_seconds:
                    terminate_process_tree(process)
                    raise BenchmarkFailure(
                        f"{workload}/{cell.name} timed out after "
                        f"{timeout_seconds}s"
                    )
                time.sleep(interval_seconds)
        finally:
            if process.poll() is None:
                terminate_process_tree(process)
        wall_seconds = time.monotonic() - started
    if process.returncode != 0:
        raise BenchmarkFailure(
            f"{workload}/{cell.name} exited {process.returncode}:\n"
            + stderr_path.read_text(encoding="utf-8", errors="replace")
        )
    if sample_count == 0:
        raise BenchmarkFailure(f"{workload}/{cell.name}: no /proc sample")
    assert_no_artifact_leak(temporary, f"{workload}/{cell.name}")
    assert_tooling_cache_modules(
        tooling_cache,
        cell.expected_cache_modules,
        f"{workload}/{cell.name}",
    )
    normalized = normalize_transcript(
        stdout_path.read_bytes(), remove_debug=True
    )
    assert_five_candidates(normalized, f"{workload}/{cell.name}")
    transcript_hash = sha256_bytes(normalized)
    if transcript_hash != expected_hash:
        raise BenchmarkFailure(
            f"{workload}/{cell.name}: transcript {transcript_hash}, "
            f"expected {expected_hash}"
        )
    allocated_bytes = parse_allocated_bytes(
        stderr_path.read_bytes(), f"{workload}/{cell.name}"
    )
    clock_ticks = os.sysconf("SC_CLK_TCK")
    cpu_seconds = sum(observed_cpu.values()) / clock_ticks
    return RunResult(
        workload=workload,
        sample=sample_number,
        cell=cell.name,
        wall_seconds=wall_seconds,
        cpu_seconds=cpu_seconds,
        peak_rss_kib=peak_rss_kib,
        allocated_bytes=allocated_bytes,
        transcript_hash=transcript_hash,
    )


def percentile95(values: Sequence[float]) -> float:
    ordered = sorted(values)
    return ordered[max(0, math.ceil(0.95 * len(ordered)) - 1)]


def median_metric(results: Iterable[RunResult], name: str) -> float:
    return float(statistics.median(getattr(result, name) for result in results))


def summary_metrics(results: Sequence[RunResult]) -> dict[str, float]:
    wall = [result.wall_seconds for result in results]
    return {
        "wall_median": float(statistics.median(wall)),
        "wall_p95": percentile95(wall),
        "cpu_median": median_metric(results, "cpu_seconds"),
        "rss_median": median_metric(results, "peak_rss_kib"),
        "alloc_median": median_metric(results, "allocated_bytes"),
    }


def ratio(numerator: float, denominator: float) -> float:
    if denominator == 0:
        raise BenchmarkFailure("cannot divide by zero in benchmark summary")
    return numerator / denominator


def write_results(path: Path, results: Sequence[RunResult]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="\n") as handle:
        handle.write(
            "workload\tsample\tcell\twall_seconds\tcpu_seconds\t"
            "peak_rss_kib\tallocated_bytes\ttranscript_sha256\n"
        )
        for result in results:
            handle.write(
                f"{result.workload}\t{result.sample}\t{result.cell}\t"
                f"{result.wall_seconds:.6f}\t{result.cpu_seconds:.6f}\t"
                f"{result.peak_rss_kib}\t{result.allocated_bytes}\t"
                f"{result.transcript_hash}\n"
            )


def print_provenance(args: argparse.Namespace) -> None:
    print("Leant compiled synthesis-tooling cache benchmark")
    print(f"baseline:  {args.baseline}")
    print(f"  sha256:  {sha256_file(args.baseline)}")
    print(f"candidate: {args.candidate}")
    print(f"  sha256:  {sha256_file(args.candidate)}")
    print(f"backend:   {args.backend}")
    print(f"  sha256:  {sha256_file(args.backend)}")
    print(f"platform:  {platform.platform()}")
    print(f"logical CPUs: {os.cpu_count()}")
    print(f"samples: {args.samples}; warmups: {args.warmups}")
    print(f"process-tree sampling: {args.sample_interval_ms} ms")
    print(
        "baseline cold cache modules: "
        f"{args.baseline_cold_cache_modules}"
    )
    print(f"candidate N2 initializer: {args.candidate_n2_initializer}")


def print_scaled_pool_provenance(
    args: argparse.Namespace,
    host_cpu_count: int | None,
    effective_cpu_count: int | None,
) -> None:
    print("Leant bounded isolated-verification pool screen")
    print("protocol: scaled-pool (fixed N1/N2/N4)")
    print(f"baseline Leant commit:  {args.baseline_leant_commit}")
    print(f"candidate Leant commit: {args.candidate_leant_commit}")
    print(f"baseline Djex commit:   {args.baseline_djex_commit}")
    print(f"candidate Djex commit:  {args.candidate_djex_commit}")
    print(f"baseline:  {args.baseline}")
    print(f"  sha256:  {sha256_file(args.baseline)}")
    print(f"candidate: {args.candidate}")
    print(f"  sha256:  {sha256_file(args.candidate)}")
    print(f"backend:   {args.backend}")
    print(f"  sha256:  {sha256_file(args.backend)}")
    print(f"platform:  {platform.platform()}")
    print(f"host logical CPUs: {host_cpu_count}")
    print(f"effective CPUs: {effective_cpu_count}")
    print(
        f"samples: {SCALED_POOL_SAMPLES}; warmups: "
        f"{SCALED_POOL_WARMUPS}; measured rows are never replaced"
    )
    print(f"process-tree sampling: {args.sample_interval_ms} ms")
    print(
        "retention threshold: each B4/C4 and their geometric mean "
        f">= {SCALED_POOL_MINIMUM_SPEEDUP:.2f}x"
    )


def scaled_pool_cells(args: argparse.Namespace) -> dict[str, Cell]:
    return {
        "B1": Cell("B1", args.baseline, 1, 1, 1),
        "C1": Cell("C1", args.candidate, 1, 1, 1),
        "B2": Cell("B2", args.baseline, 2, 3, 1),
        "C2": Cell("C2", args.candidate, 2, 3, 1),
        "B4": Cell("B4", args.baseline, 4, 3, 1),
        "C4": Cell("C4", args.candidate, 4, 5, 1),
    }


def print_scaled_pool_summary(results: Sequence[RunResult]) -> list[str]:
    summaries: dict[tuple[str, str], dict[str, float]] = {}
    print("scaled-pool summary:")
    for workload, _ in SCALED_POOL_WORKLOADS:
        for cell_name in SCALED_POOL_CELL_ORDER:
            selected = [
                result
                for result in results
                if result.workload == workload and result.cell == cell_name
            ]
            if len(selected) != SCALED_POOL_SAMPLES:
                raise BenchmarkFailure(
                    f"{workload}/{cell_name}: retained {len(selected)} rows, "
                    f"expected {SCALED_POOL_SAMPLES}"
                )
            metrics = summary_metrics(selected)
            summaries[(workload, cell_name)] = metrics
            print(
                f"  {workload:13s} {cell_name}: "
                f"wall median/p95 {metrics['wall_median']:.3f}/"
                f"{metrics['wall_p95']:.3f}s; "
                f"CPU {metrics['cpu_median']:.3f}s; "
                f"RSS {metrics['rss_median'] / 1024:.1f}MiB; "
                f"alloc {metrics['alloc_median'] / 1048576:.1f}MiB"
            )

    speedups: list[float] = []
    retention_holds: list[str] = []
    for workload, _ in SCALED_POOL_WORKLOADS:
        b1 = summaries[(workload, "B1")]
        c1 = summaries[(workload, "C1")]
        b2 = summaries[(workload, "B2")]
        c2 = summaries[(workload, "C2")]
        b4 = summaries[(workload, "B4")]
        c4 = summaries[(workload, "C4")]
        incremental = ratio(b4["wall_median"], c4["wall_median"])
        candidate_scaling = ratio(c2["wall_median"], c4["wall_median"])
        baseline_n4_control = ratio(b2["wall_median"], b4["wall_median"])
        n1_median_ratio = ratio(c1["wall_median"], b1["wall_median"])
        n1_p95_ratio = ratio(c1["wall_p95"], b1["wall_p95"])
        n2_median_ratio = ratio(c2["wall_median"], b2["wall_median"])
        n2_p95_ratio = ratio(c2["wall_p95"], b2["wall_p95"])
        n4_p95_ratio = ratio(c4["wall_p95"], b4["wall_p95"])
        speedups.append(incremental)
        print(
            f"  {workload:13s}: B4/C4={incremental:.3f}x; "
            f"C2/C4={candidate_scaling:.3f}x; "
            f"B2/B4={baseline_n4_control:.3f}x"
        )
        print(
            f"  {workload:13s}: C1/B1 median/p95="
            f"{n1_median_ratio:.3f}/{n1_p95_ratio:.3f}x; "
            f"C2/B2 median/p95={n2_median_ratio:.3f}/"
            f"{n2_p95_ratio:.3f}x; C4/B4 p95={n4_p95_ratio:.3f}x"
        )
        if incremental < SCALED_POOL_MINIMUM_SPEEDUP:
            retention_holds.append(
                f"{workload} B4/C4 speedup {incremental:.3f}x < "
                f"{SCALED_POOL_MINIMUM_SPEEDUP:.3f}x"
            )
        if c4["wall_p95"] > b4["wall_p95"]:
            retention_holds.append(
                f"{workload} candidate N4 p95 {c4['wall_p95']:.3f}s > "
                f"baseline N4 {b4['wall_p95']:.3f}s"
            )
        for capabilities, median_ratio, p95_ratio in (
            (1, n1_median_ratio, n1_p95_ratio),
            (2, n2_median_ratio, n2_p95_ratio),
        ):
            if median_ratio > SCALED_POOL_MAXIMUM_MEDIAN_REGRESSION:
                retention_holds.append(
                    f"{workload} N{capabilities} median ratio "
                    f"{median_ratio:.3f}x > "
                    f"{SCALED_POOL_MAXIMUM_MEDIAN_REGRESSION:.3f}x"
                )
            if p95_ratio > SCALED_POOL_MAXIMUM_P95_REGRESSION:
                retention_holds.append(
                    f"{workload} N{capabilities} p95 ratio "
                    f"{p95_ratio:.3f}x > "
                    f"{SCALED_POOL_MAXIMUM_P95_REGRESSION:.3f}x"
                )
        resource_checks = (
            (
                "allocation",
                "alloc_median",
                SCALED_POOL_MAXIMUM_ALLOCATION_RATIO,
            ),
            ("CPU", "cpu_median", SCALED_POOL_MAXIMUM_CPU_RATIO),
            ("aggregate RSS", "rss_median", SCALED_POOL_MAXIMUM_RSS_RATIO),
        )
        for capabilities, baseline, candidate in (
            (1, b1, c1),
            (2, b2, c2),
            (4, b4, c4),
        ):
            resource_ratios = [
                (label, ratio(candidate[metric], baseline[metric]), maximum)
                for label, metric, maximum in resource_checks
            ]
            print(
                f"  {workload:13s}: C{capabilities}/B{capabilities} "
                + "; ".join(
                    f"{label}={observed:.3f}x"
                    for label, observed, _ in resource_ratios
                )
            )
            for label, observed, maximum in resource_ratios:
                if observed > maximum:
                    retention_holds.append(
                        f"{workload} N{capabilities} {label} ratio "
                        f"{observed:.3f}x > {maximum:.3f}x"
                    )
    geometric_mean = math.exp(
        sum(math.log(value) for value in speedups) / len(speedups)
    )
    print(f"  geometric mean B4/C4: {geometric_mean:.3f}x")
    if geometric_mean < SCALED_POOL_MINIMUM_SPEEDUP:
        retention_holds.append(
            f"geometric mean B4/C4 speedup {geometric_mean:.3f}x < "
            f"{SCALED_POOL_MINIMUM_SPEEDUP:.3f}x"
        )
    return retention_holds


def run_scaled_pool_protocol(args: argparse.Namespace) -> int:
    validate_scaled_pool_design()
    commit_arguments = (
        ("--baseline-leant-commit", args.baseline_leant_commit),
        ("--candidate-leant-commit", args.candidate_leant_commit),
        ("--baseline-djex-commit", args.baseline_djex_commit),
        ("--candidate-djex-commit", args.candidate_djex_commit),
    )
    missing_commits = [
        option for option, commit in commit_arguments if commit is None
    ]
    if missing_commits:
        raise BenchmarkFailure(
            "scaled-pool requires exact provenance arguments: "
            + ", ".join(missing_commits)
        )
    if args.warmups != SCALED_POOL_WARMUPS:
        raise BenchmarkFailure(
            "scaled-pool is preregistered with exactly one warmup; "
            f"observed --warmups {args.warmups}"
        )
    if args.samples != SCALED_POOL_SAMPLES:
        raise BenchmarkFailure(
            "scaled-pool is preregistered with exactly five measured "
            f"samples; observed --samples {args.samples}"
        )
    if not SHORT_BATCH_FIXTURE.is_file():
        raise BenchmarkFailure(
            f"missing scaled-pool short-batch fixture: {SHORT_BATCH_FIXTURE}"
        )
    for name, fixture in SCALED_POOL_WORKLOADS:
        if not fixture.is_file():
            raise BenchmarkFailure(f"missing {name} fixture: {fixture}")

    host_cpu_count, effective_cpu_count = host_and_effective_cpu_counts()
    cells = scaled_pool_cells(args)
    print_scaled_pool_provenance(
        args, host_cpu_count, effective_cpu_count
    )
    if effective_cpu_count is None or effective_cpu_count < 4:
        observed = "unknown" if effective_cpu_count is None else str(
            effective_cpu_count
        )
        raise BenchmarkFailure(
            "scaled-pool requires at least four effective CPUs; observed "
            + observed
        )
    interval_seconds = args.sample_interval_ms / 1000.0
    all_results: list[RunResult] = []
    with tempfile.TemporaryDirectory(
        prefix="leant scaled pool benchmark."
    ) as raw_root:
        root = Path(raw_root)
        tooling_cache = root / "compiled tooling cache with spaces"
        tooling_cache.mkdir()
        expected_hashes = scaled_pool_preflight(
            cells,
            args.backend,
            root,
            tooling_cache,
            args.timeout,
        )
        workload_map = dict(SCALED_POOL_WORKLOADS)
        for workload_index, (name, fixture) in enumerate(
            SCALED_POOL_WORKLOADS
        ):
            row = SCALED_POOL_WILLIAMS_ROWS[workload_index]
            for cell_name in row:
                result = measure_cell(
                    name,
                    fixture,
                    -1,
                    cells[cell_name],
                    args.backend,
                    root,
                    expected_hashes[name],
                    args.timeout,
                    interval_seconds,
                    tooling_cache,
                )
                print(
                    f"warmup 1 {name:13s} {cell_name} "
                    f"{result.wall_seconds:.3f}s"
                )
        for sample_number in range(1, SCALED_POOL_SAMPLES + 1):
            workload_names = [name for name, _ in SCALED_POOL_WORKLOADS]
            if sample_number % 2 == 0:
                workload_names.reverse()
            for name in workload_names:
                workload_index = PRIMARY_WORKLOADS.index(name)
                row = SCALED_POOL_WILLIAMS_ROWS[
                    (sample_number + workload_index)
                    % len(SCALED_POOL_WILLIAMS_ROWS)
                ]
                for cell_name in row:
                    result = measure_cell(
                        name,
                        workload_map[name],
                        sample_number,
                        cells[cell_name],
                        args.backend,
                        root,
                        expected_hashes[name],
                        args.timeout,
                        interval_seconds,
                        tooling_cache,
                    )
                    all_results.append(result)
                    print(
                        f"sample {sample_number:2d} {name:13s} {cell_name} "
                        f"wall={result.wall_seconds:.3f}s "
                        f"cpu={result.cpu_seconds:.3f}s "
                        f"rss={result.peak_rss_kib / 1024:.1f}MiB "
                        f"alloc={result.allocated_bytes / 1048576:.1f}MiB"
                    )
        raw_results = root / "results.tsv"
        write_results(raw_results, all_results)
        if args.results is not None:
            destination = args.results.expanduser().resolve()
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(raw_results, destination)
            print(f"raw results: {destination}")
        if args.artifacts is not None:
            destination = args.artifacts.expanduser().resolve()
            if destination.exists():
                raise BenchmarkFailure(
                    f"artifact destination already exists: {destination}"
                )
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copytree(root, destination)
            print(f"raw artifacts: {destination}")

    retention_holds = print_scaled_pool_summary(all_results)
    if retention_holds:
        print("scaled-pool retention: HOLD")
        for hold in retention_holds:
            print(f"  - {hold}")
        return 1 if args.enforce else 0
    print("scaled-pool retention: GO")
    return 0


def main() -> int:
    args = parse_arguments()
    if platform.system() != "Linux" or not Path("/proc").is_dir():
        raise BenchmarkFailure(
            "this release benchmark requires Linux /proc process sampling"
        )
    if shutil.which("strace") is None:
        raise BenchmarkFailure("strace is required for route preflight")
    if args.protocol == "scaled-pool":
        return run_scaled_pool_protocol(args)
    for name, fixture in WORKLOADS:
        if not fixture.is_file():
            raise BenchmarkFailure(f"missing {name} fixture: {fixture}")
    cells = {
        "B1": Cell("B1", args.baseline, 1, 1, 1),
        "B2": Cell("B2", args.baseline, 2, 3, 1),
        "C1": Cell("C1", args.candidate, 1, 1, 1),
        "C2": Cell("C2", args.candidate, 2, 3, 1),
        "D1": Cell(
            "D1", args.baseline, 1, 1, args.baseline_cold_cache_modules
        ),
        "D2": Cell("D2", args.candidate, 1, 1, 1),
    }
    print_provenance(args)
    interval_seconds = args.sample_interval_ms / 1000.0
    all_results: list[RunResult] = []
    with tempfile.TemporaryDirectory(
        prefix="leant verification benchmark."
    ) as raw_root:
        root = Path(raw_root)
        tooling_cache = root / "compiled tooling cache with spaces"
        tooling_cache.mkdir()
        expected_hashes = {
            name: preflight_workload(
                name,
                fixture,
                cells,
                args.backend,
                root,
                tooling_cache,
                args.timeout,
                args.baseline_cold_cache_modules,
                args.candidate_n2_initializer,
            )
            for name, fixture in WORKLOADS
        }
        workload_map = dict(WORKLOADS)
        for warmup in range(1, args.warmups + 1):
            for workload_index, (name, fixture) in enumerate(WORKLOADS):
                row = LATIN_ROWS[(warmup - 1 + workload_index) % len(LATIN_ROWS)]
                for cell_name in row:
                    result = measure_cell(
                        name,
                        fixture,
                        -warmup,
                        cells[cell_name],
                        args.backend,
                        root,
                        expected_hashes[name],
                        args.timeout,
                        interval_seconds,
                        tooling_cache,
                    )
                    print(
                        f"warmup {warmup} {name:13s} {cell_name} "
                        f"{result.wall_seconds:.3f}s"
                    )
        for sample_number in range(1, args.samples + 1):
            workload_names = [name for name, _ in WORKLOADS]
            if sample_number % 2 == 0:
                workload_names.reverse()
            for workload_index, name in enumerate(workload_names):
                row = LATIN_ROWS[
                    (sample_number - 1 + workload_index) % len(LATIN_ROWS)
                ]
                for cell_name in row:
                    result = measure_cell(
                        name,
                        workload_map[name],
                        sample_number,
                        cells[cell_name],
                        args.backend,
                        root,
                        expected_hashes[name],
                        args.timeout,
                        interval_seconds,
                        tooling_cache,
                    )
                    all_results.append(result)
                    print(
                        f"sample {sample_number:2d} {name:13s} {cell_name} "
                        f"wall={result.wall_seconds:.3f}s "
                        f"cpu={result.cpu_seconds:.3f}s "
                        f"rss={result.peak_rss_kib / 1024:.1f}MiB "
                        f"alloc={result.allocated_bytes / 1048576:.1f}MiB"
                    )
                cold_row = COLD_ROWS[
                    (sample_number - 1 + workload_index) % len(COLD_ROWS)
                ]
                for cell_name in cold_row:
                    cold_cache = (
                        root
                        / "cold compiled tooling caches"
                        / f"sample {sample_number} {name} {cell_name}"
                    )
                    cold_cache.mkdir(parents=True)
                    result = measure_cell(
                        name,
                        workload_map[name],
                        sample_number,
                        cells[cell_name],
                        args.backend,
                        root,
                        expected_hashes[name],
                        args.timeout,
                        interval_seconds,
                        cold_cache,
                    )
                    all_results.append(result)
                    print(
                        f"sample {sample_number:2d} {name:13s} {cell_name} "
                        f"wall={result.wall_seconds:.3f}s "
                        f"cpu={result.cpu_seconds:.3f}s "
                        f"rss={result.peak_rss_kib / 1024:.1f}MiB "
                        f"alloc={result.allocated_bytes / 1048576:.1f}MiB"
                    )
        raw_results = root / "results.tsv"
        write_results(raw_results, all_results)
        if args.results is not None:
            destination = args.results.expanduser().resolve()
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(raw_results, destination)
            print(f"raw results: {destination}")
        if args.artifacts is not None:
            destination = args.artifacts.expanduser().resolve()
            if destination.exists():
                raise BenchmarkFailure(
                    f"artifact destination already exists: {destination}"
                )
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copytree(root, destination)
            print(f"raw artifacts: {destination}")

    summaries: dict[tuple[str, str], dict[str, float]] = {}
    print("summary:")
    for workload, _ in WORKLOADS:
        for cell_name in ("B1", "B2", "C1", "C2", "D1", "D2"):
            selected = [
                result
                for result in all_results
                if result.workload == workload and result.cell == cell_name
            ]
            metrics = summary_metrics(selected)
            summaries[(workload, cell_name)] = metrics
            print(
                f"  {workload:13s} {cell_name}: "
                f"wall median/p95 {metrics['wall_median']:.3f}/"
                f"{metrics['wall_p95']:.3f}s; "
                f"CPU {metrics['cpu_median']:.3f}s; "
                f"RSS {metrics['rss_median'] / 1024:.1f}MiB; "
                f"alloc {metrics['alloc_median'] / 1048576:.1f}MiB"
            )

    speedups: list[float] = []
    promotion_holds: list[str] = []
    for workload, _ in WORKLOADS:
        b1 = summaries[(workload, "B1")]
        b2 = summaries[(workload, "B2")]
        c1 = summaries[(workload, "C1")]
        c2 = summaries[(workload, "C2")]
        d1 = summaries[(workload, "D1")]
        d2 = summaries[(workload, "D2")]
        incremental = ratio(b2["wall_median"], c2["wall_median"])
        candidate_scaling = ratio(c1["wall_median"], c2["wall_median"])
        n1_ratio = ratio(c1["wall_median"], b1["wall_median"])
        cold_ratio = ratio(d2["wall_median"], d1["wall_median"])
        cold_p95_ratio = ratio(d2["wall_p95"], d1["wall_p95"])
        speedups.append(incremental)
        print(
            f"  {workload:13s}: B2/C2={incremental:.3f}x; "
            f"C1/C2={candidate_scaling:.3f}x; C1/B1={n1_ratio:.3f}x; "
            f"D2/D1={cold_ratio:.3f}x; "
            f"cold-p95={cold_p95_ratio:.3f}x"
        )
        if workload in PRIMARY_WORKLOADS:
            if incremental < args.minimum_speedup:
                promotion_holds.append(
                    f"{workload} incremental speedup {incremental:.3f}x "
                    f"< {args.minimum_speedup:.3f}x"
                )
            if c2["wall_p95"] > b2["wall_p95"]:
                promotion_holds.append(
                    f"{workload} candidate N2 p95 {c2['wall_p95']:.3f}s "
                    f"> baseline N2 {b2['wall_p95']:.3f}s"
                )
            if n1_ratio > args.maximum_n1_regression:
                promotion_holds.append(
                    f"{workload} N1 ratio {n1_ratio:.3f}x "
                    f"> {args.maximum_n1_regression:.3f}x"
                )
            if cold_ratio > args.maximum_cold_regression:
                promotion_holds.append(
                    f"{workload} cold N1 ratio {cold_ratio:.3f}x "
                    f"> {args.maximum_cold_regression:.3f}x"
                )
            if cold_p95_ratio > args.maximum_cold_p95_ratio:
                promotion_holds.append(
                    f"{workload} cold N1 p95 ratio "
                    f"{cold_p95_ratio:.3f}x > "
                    f"{args.maximum_cold_p95_ratio:.3f}x"
                )
            resource_checks = (
                ("allocation", "alloc_median", args.maximum_allocation_ratio),
                ("CPU", "cpu_median", args.maximum_cpu_ratio),
                ("aggregate RSS", "rss_median", args.maximum_rss_ratio),
            )
            for label, metric, maximum in resource_checks:
                observed = ratio(c2[metric], b2[metric])
                if observed > maximum:
                    promotion_holds.append(
                        f"{workload} {label} ratio {observed:.3f}x > "
                        f"{maximum:.3f}x"
                    )
    geometric_mean = math.exp(sum(math.log(value) for value in speedups) / len(speedups))
    print(f"  geometric mean B2/C2: {geometric_mean:.3f}x")
    if geometric_mean <= 1.0:
        promotion_holds.append(
            f"geometric mean speedup {geometric_mean:.3f}x is not positive"
        )

    if promotion_holds:
        print("promotion: HOLD")
        for hold in promotion_holds:
            print(f"  - {hold}")
        return 1 if args.enforce else 0
    print("promotion: GO")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except BenchmarkFailure as failure:
        print(f"FAIL verification benchmark: {failure}", file=sys.stderr)
        raise SystemExit(2) from failure
