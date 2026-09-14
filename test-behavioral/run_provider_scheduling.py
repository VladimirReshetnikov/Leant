"""Public provider scheduling, structural continuation, and bound regressions.

Successful displayed candidates replay at their full signatures in an independent
Lean process. Literal-False controls must report actual rejection. These small
regressions are separate from the original 168-observation Church Int-at gate.
"""
from pathlib import Path
import argparse
import os
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path[:0] = [str(ROOT / "test-church"), str(ROOT / "lib/Djex/test-church")]
import behavior_runtime as runtime
from behavior_probe import parse_output
from run_corpus import reported_axioms

PROVIDER = "namespace Scheduling\ndef value : Nat := 37\nend Scheduling\n"
POLY = "∀ A : Type, A → A → A"
SETTINGS = """:set synth-library off
:set synth-classical off
:set synth-providers on
:set synth-debug on
:set synth-provider-cap 1
:set synth-ranking balanced
:set synth-shown 1
:set synth-window 60
:set synth-verify 12
:set synth-steps 4096
:set synth-budget 500000
:set synth-timeout 20
"""


def specifications():
    yield "provider", "Nat → Nat", "{f} 0 = 37 ∧ {f} 1 = 37 ∧ {f} 9 = 37", PROVIDER
    yield "left", POLY, "{f} Nat 37 53 = 37 ∧ {f} Bool false true = false", ""
    yield "right", POLY, "{f} Nat 37 53 = 53 ∧ {f} Bool false true = true", ""
    yield "reject_empty", POLY, "False", ""
    yield "reject_provider", "Nat → Nat", "False", PROVIDER


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--leant", type=Path, required=True)
    parser.add_argument("--backend", type=Path, required=True)
    parser.add_argument("--lake", type=Path, required=True)
    parser.add_argument("--lean", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--engine", choices=["djinn", "exference", "both"], action="append")
    args = parser.parse_args()
    output = runtime.prepare_output_directory(args.output.resolve())
    engines = args.engine or ["djinn", "exference", "both"]
    paths = sorted({Path(__file__).resolve(), ROOT / "test-church/behavior_probe.py",
                    ROOT / "test-church/run_corpus.py", Path(runtime.__file__).resolve(),
                    ROOT / "leant.cabal", ROOT / "cabal.project", *ROOT.glob("src/**/*.hs")})
    sources = {str(p): runtime.sha256(p) for p in paths}
    binaries = {str(p.resolve()): runtime.sha256(p)
                for p in (args.leant, args.backend, args.lake, args.lean)}
    for path in paths:
        saved = output / "source" / path.relative_to(ROOT)
        saved.parent.mkdir(parents=True, exist_ok=True)
        saved.write_bytes(path.read_bytes())
    report = dict(status="running", scope=__doc__, engines=engines,
                  source_hashes=sources, executable_hashes=binaries, cells=[])
    processes = runtime.Processes(output, 180)

    def save():
        report["processes"] = processes.rows
        runtime.write_json(output / "results.json", report)

    try:
        save()
        for engine in engines:
            resumed = False
            for label, signature, predicate, declarations in specifications():
                name = "scheduling_" + engine + "_" + label
                command = f":synth {name} : ({signature}) where " + predicate.replace("{f}", name)
                case = dict(name=name, command=command, type=signature,
                            expected="no_candidate" if label.startswith("reject_") else "candidate")
                row = dict(name=name, engine=engine, label=label, status="running")
                report["cells"].append(row)
                save()
                verification_limit = 12 if label == "provider" else 3
                source = (SETTINGS + f":set synth-verify {verification_limit}\n:set synth-engine {engine}\n"
                          + declarations + command + "\n:quit\n")
                live = processes.run(name, [args.leant.resolve(), "--plain", "--lake", args.lake.resolve()],
                    source=source, cwd=ROOT, env=dict(os.environ, LEANT_BACKEND=str(args.backend.resolve())))
                transcript = live.stdout + live.stderr
                if live.returncode or re.search(r"^error:", transcript, re.M):
                    raise ValueError(name + ": command failed")
                parsed = parse_output(transcript, [case])[0]
                providers = re.findall(r'^debug provider: .*?providerLeanName = "([^"]+)"', transcript, re.M)
                expected_providers = ["Scheduling.value"] if declarations else []
                if providers != expected_providers:
                    raise ValueError(name + ": wrong provider inventory: " + repr(providers))
                ordinals = [int(n) for n in re.findall(r"^debug (\d+):", transcript, re.M)]
                # Both keeps its established doubled verification allowance.
                limit = verification_limit * (2 if engine == "both" else 1)
                if not ordinals or max(ordinals) > limit:
                    raise ValueError(name + ": resumed past the original verification allowance")
                if label == "reject_provider" and max(ordinals) != limit:
                    raise ValueError(name + ": stopped before exercising the complete resumed allowance")
                if "debug behavioral request failure:" in transcript:
                    raise ValueError(name + ": bounded fixture lost a verification request")
                row.update(provider_names=providers, ordinals=ordinals,
                           observations=parsed["observations"])
                if label in ("left", "right") and parsed["observations"]["falsified"] > 0:
                    resumed = resumed or max(ordinals) >= 2
                if case["expected"] == "candidate":
                    candidate = "SchedulingReplay.candidate"
                    theorem = "SchedulingReplay.passes"
                    lean_source = ("set_option autoImplicit false\n" + declarations
                        + f"def {candidate} : ({signature}) :=\n{parsed['candidate']}\n"
                        + f"theorem {theorem} : " + predicate.replace("{f}", candidate)
                        + f" := by decide\n#print axioms {candidate}\n#print axioms {theorem}\n")
                    path = output / (name + ".lean")
                    path.write_text(lean_source, encoding="utf-8")
                    replay = processes.run(name + "-replay", [args.lean.resolve(), path], cwd=ROOT)
                    text = replay.stdout + replay.stderr
                    inventories = {n: reported_axioms(text, n) for n in (candidate, theorem)}
                    if replay.returncode or any(v != set() for v in inventories.values()):
                        raise ValueError(name + ": exact kernel replay or empty-axiom check failed")
                    row.update(candidate=parsed["candidate"], replay_source_sha256=runtime.sha256(path),
                               axiom_inventories={n: sorted(v) for n, v in inventories.items()})
                row["status"] = "passed"
                save()
            if not resumed:
                raise ValueError(engine + ": the empty-provider tests did not exercise structural continuation")
        report["status"] = "passed"
    except BaseException as error:
        report.update(status="failed", failure=repr(error))
        for row in report["cells"]:
            if row["status"] == "running":
                row.update(status="failed", failure=repr(error))
    finally:
        report["sources_unchanged"] = all(runtime.sha256(Path(p)) == h for p, h in sources.items())
        report["executables_unchanged"] = all(runtime.sha256(Path(p)) == h for p, h in binaries.items())
        if not report["sources_unchanged"] or not report["executables_unchanged"]:
            report["status"] = "failed"
        save()
    print(report["status"], report.get("failure", ""), flush=True)
    return 0 if report["status"] == "passed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
