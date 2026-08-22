#!/usr/bin/env python3
"""End-to-end benchmark for Leant's compiled synthesis-tooling cache.

The benchmark compares the exact pre-cache baseline and a candidate binary at
both one and two RTS capabilities.  Linux /proc sampling reports aggregate
process-tree CPU and resident memory; strace proves that both binaries retain
the same ordered isolated-verification topology.
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
LATIN_ROWS = (
    ("B1", "B2", "C2", "C1"),
    ("B2", "C1", "B1", "C2"),
    ("C1", "C2", "B2", "B1"),
    ("C2", "B1", "C1", "B2"),
)
COLD_ROWS = (
    ("D1", "D2"),
    ("D2", "D1"),
)
PRIMARY_WORKLOADS = ("state-thread", "continuation")
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


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="benchmark baseline and candidate verification at N1/N2",
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
        help="return failure when the documented promotion thresholds fail",
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


def assert_five_candidates(transcript: bytes, label: str) -> None:
    names = CANDIDATE_RE.findall(transcript.decode("utf-8"))
    expected = [f"it{ordinal}" for ordinal in range(1, 6)]
    if names != expected:
        raise BenchmarkFailure(
            f"{label}: expected candidates {expected}, observed {names}"
        )


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


def main() -> int:
    args = parse_arguments()
    if platform.system() != "Linux" or not Path("/proc").is_dir():
        raise BenchmarkFailure(
            "this release benchmark requires Linux /proc process sampling"
        )
    if shutil.which("strace") is None:
        raise BenchmarkFailure("strace is required for route preflight")
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
