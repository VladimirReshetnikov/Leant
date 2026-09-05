#!/usr/bin/env python3
"""Generate and check Lean synthesis counterparts of the Church signatures.

The Djex manifest contains GHC-resolved types, never source implementations.
Each nested type quantifier gets an independently inferred Lean universe. Lean
has a predicative Type hierarchy, so the translation does not claim that its
Type is impredicative. Acceptance means a universe-correct counterpart of the
Haskell signature, checked again by the Lean kernel.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys


HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
PARTIAL = "requires_partiality"
INT_PROVIDER = "needs_int_provider"


def reported_axioms(output, declaration):
    """Read one exact #print axioms inventory, including wrapped lists."""
    pattern = (r"^'" + re.escape(declaration)
               + r"' (does not depend on any axioms|depends on axioms:\s*\[([^\]]*)\])")
    matches = list(re.finditer(pattern, output, re.MULTILINE))
    if len(matches) != 1:
        return None
    dependencies = matches[0].group(2)
    return set() if dependencies is None else {
        name.strip() for name in dependencies.split(",") if name.strip()}


def validate_settings(output, source):
    """Bind each query to its requested settings and require acknowledgments."""
    error = re.search(
        r"(?m)^(?:error:|REPL error:|synthesis engine error:|Lean error:|"
        r"unknown command |usage:|sorry(?:$|[ (])).*", output)
    if error:
        raise ValueError(f"Leant reported a command or backend error: {error.group()}")
    blocks = re.split(r"(?m)^λ> ", output)[1:]
    # Settings and queries must remain interleaved: checking their separate
    # subsequences would accept moving an engine switch across a query, and
    # repeated goals could then appear to cover engines that never ran them.
    command_prefixes = (":set ", ":synth ")
    expected_commands = [line for line in source.splitlines()
                         if line.startswith(command_prefixes)]
    observed_commands = [block.splitlines()[0] for block in blocks
                         if block.startswith(command_prefixes)]
    if observed_commands != expected_commands:
        raise ValueError("Leant setting and synthesis commands do not match the requested transcript order")
    expected = [line for line in source.splitlines() if line.startswith(":set ")]
    observed = [block for block in blocks if block.startswith(":set ")]
    if [block.splitlines()[0] for block in observed] != expected:
        raise ValueError("Leant setting commands do not match the requested transcript")
    for command, block in zip(expected, observed):
        _, setting, value = command.split(maxsplit=2)
        label = setting.replace("-", " ", 1)
        displayed_value = value
        if setting == "synth-timeout":
            displayed_value = "0 (wait indefinitely)" if value == "0" else value + "s"
        acknowledgment = f"{label}: {displayed_value}"
        if block.splitlines()[1:2] != [acknowledgment]:
            raise ValueError(f"Leant did not acknowledge setting: {command}")


def lean_type(node):
    tag = node["tag"]
    if tag == "name":
        name = node["name"]
        if not re.fullmatch(r"[A-Za-z_][A-Za-z_0-9']*", name):
            raise ValueError(f"unsupported type name: {name!r}")
        return name
    if tag == "arrow":
        return f"({lean_type(node['domain'])} → {lean_type(node['codomain'])})"
    if tag == "app":
        return f"({lean_type(node['function'])} {lean_type(node['argument'])})"
    if tag == "forall":
        binders = " ".join(f"({name} : Type _)" for name in node["binders"])
        return f"(∀ {binders}, {lean_type(node['body'])})"
    raise ValueError(f"unsupported type node: {tag!r}")


def with_element_default(node, default_type):
    """Make partial element extraction total under explicit input defaults."""
    binders = []
    body = node
    while body["tag"] == "forall":
        binders.extend(body["binders"])
        body = body["body"]
    if not binders:
        raise ValueError("partial case lacks a quantified element type")
    body = {"tag": "arrow", "domain": default_type, "codomain": body}
    return {"tag": "forall", "binders": binders, "body": body}, [default_type["name"]]


def translated_cases(manifest):
    cases = []
    for source in manifest["cases"]:
        node = source["expanded_type"]
        defaults = []
        if source["classification"] == PARTIAL:
            node, defaults = with_element_default(node, source["default_type"])
        cases.append({
            "id": source["id"], "name": source["name"],
            "line": source["line"], "classification": source["classification"],
            "scope": source.get("scope", "top_level"),
            "default_type_parameters": defaults, "lean_type": lean_type(node),
        })
    return cases


def commands(cases, engine, timeout, steps, window):
    lines = [
        ":set synth-library off", ":set synth-classical off",
        ":set synth-providers off", ":set synth-shown 1",
        f":set synth-window {window}", f":set synth-verify {window}",
        f":set synth-engine {engine}", f":set synth-timeout {timeout}",
        f":set synth-steps {steps}",
        "def ChurchCorpus.integerZero : Int := 0",
    ]
    providers_enabled = False
    for case in cases:
        needs_provider = case["classification"] == INT_PROVIDER
        if needs_provider != providers_enabled:
            lines.append(":set synth-providers " + ("on" if needs_provider else "off"))
            providers_enabled = needs_provider
        lines.append(f":synth {case['lean_type']}")
    return "\n".join(lines + [":quit", ""])


def parse_results(output, cases):
    if not cases:
        raise ValueError("cannot validate an empty selection of synthesis queries")
    chunks = re.split(r"(?m)^λ> :synth ", output)[1:]
    if len(chunks) > len(cases):
        raise ValueError("Leant output contains more synthesis queries than the selected corpus")
    results = []
    for case, chunk in zip(cases, chunks):
        chunk = chunk.split("\nλ> ", 1)[0]
        echoed_type = chunk.splitlines()[0].strip()
        if "lean_type" in case and echoed_type != case["lean_type"]:
            raise ValueError(f"Leant query does not match manifest case {case['id']}")
        labels = re.findall(r"(?m)^[ \t]+it([0-9]+)[ \t]+", chunk)
        if labels and labels != ["1"]:
            raise ValueError(f"unexpected candidate labels for shown=1 in {case['id']}: {labels}")
        # Render currently joins its ordinary syntax into one line, but a
        # retained Lean type spelling can contain whitespace. Preserve the
        # entire displayed term block so future pretty-printing changes cannot
        # silently truncate the exact text we send to the kernel.
        term = re.search(r"(?m)^[ \t]+it1[ \t]+(.+)$", chunk)
        candidate = None
        if term:
            tail = chunk[term.start(1):]
            term_lines = []
            for line in tail.splitlines():
                if re.match(r"^(?:note:|debug |[ \t]+it[0-9]+[ \t])", line):
                    break
                term_lines.append(line)
            candidate = "\n".join(term_lines).strip() or None
        if candidate and re.search(r"\b(?:sorry|admit|unsafe|axiom)\b", candidate):
            raise ValueError(f"forbidden unchecked candidate in {case['id']}")
        results.append({
            **case, "status": "candidate" if candidate else "failed",
            "candidate": candidate, "output": chunk,
        })
    for case in cases[len(results):]:
        results.append({**case, "status": "missing", "candidate": None,
                        "output": "Leant did not reach this case."})
    return results


def kernel_source(results):
    lines = [
        "-- Generated exclusively from synthesized candidates and the manifest.",
        "set_option linter.unusedVariables false",
        "def ChurchCorpus.integerZero : Int := 0", "",
    ]
    for result in results:
        if result["candidate"] is None:
            continue
        lines.extend([
            f"-- Church.hs:{result['line']} {result['name']} ({result['classification']})",
            f"def ChurchCorpus.{result['id']} : {result['lean_type']} :=",
            "\n".join("  " + line for line in result["candidate"].splitlines()),
            f"#print axioms ChurchCorpus.{result['id']}", "",
        ])
    return "\n".join(lines)


def main():
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, "reconfigure"):
            stream.reconfigure(encoding="utf-8")
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path,
                        default=ROOT / "lib/Djex/test-church/manifest.json")
    parser.add_argument("--output", type=Path, default=HERE / "generated")
    parser.add_argument("--engine", choices=["djinn", "exference", "both"], default="djinn")
    parser.add_argument("--timeout", type=int, default=30)
    parser.add_argument("--steps", type=int, default=4096)
    parser.add_argument("--window", type=int, default=12,
                        help="candidate search/verification window; default 12")
    parser.add_argument("--name", action="append", help="select a source name; repeatable")
    parser.add_argument("--classification", choices=["total", INT_PROVIDER, PARTIAL])
    execution = parser.add_mutually_exclusive_group()
    execution.add_argument("--leant", type=Path, help="run this built Leant executable")
    parser.add_argument("--lean", default="lean", help="Lean executable for kernel replay")
    parser.add_argument("--toolchain", default="leanprover/lean4:v4.32.0")
    execution.add_argument("--replay-output", type=Path,
                        help="parse and kernel-check a previously saved Leant output")
    args = parser.parse_args()
    manifest_bytes = args.manifest.read_bytes()
    manifest = json.loads(manifest_bytes)
    source_path = args.manifest.parent.parent / manifest["source"]
    if not source_path.is_file():
        parser.error(f"manifest source is missing: {source_path}")
    # Git may check out the same Haskell source with LF or CRLF. Hash its
    # canonical UTF-8 text, just as the shared extractor does.
    source_hash = hashlib.sha256(
        source_path.read_text(encoding="utf-8-sig").encode("utf-8")).hexdigest()
    if source_hash != manifest["source_sha256"]:
        parser.error("Church manifest is stale; rerun Djex test-church/extract_corpus.py")
    expected_count = manifest["counts"].get("all_signatures", len(manifest["cases"]))
    if len(manifest["cases"]) != expected_count:
        parser.error("Church manifest case count does not match its recorded inventory")
    cases = translated_cases(manifest)
    if args.name:
        names = set(args.name)
        cases = [case for case in cases if case["name"] in names]
        unknown = names - {case["name"] for case in cases}
        if unknown:
            parser.error(f"unknown names: {', '.join(sorted(unknown))}")
    if args.classification:
        cases = [case for case in cases if case["classification"] == args.classification]
    if not cases:
        parser.error("no synthesis signatures remain in the selected corpus")
    args.output.mkdir(parents=True, exist_ok=True)
    source = commands(cases, args.engine, args.timeout, args.steps, args.window)
    (args.output / "synth-church.txt").write_text(source, encoding="utf-8")
    metadata = {
        "source_sha256": manifest["source_sha256"], "engine": args.engine,
        "source_hash_normalization": "UTF-8 without BOM; universal newlines normalized to LF",
        "input_manifest_sha256": hashlib.sha256(manifest_bytes).hexdigest(),
        "case_count": len(cases), "cases": cases,
        "translation": "Expanded Church aliases; independently inferred Lean Type universes.",
        "partial_policy": "An explicit input default for the returned element type, only in partial cases.",
        "validation_mode": ("saved_transcript_replay" if args.replay_output else
                            "live_synthesis" if args.leant else "generation_only"),
    }
    (args.output / "manifest.json").write_text(
        json.dumps(metadata, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    shape_source = ["-- Type formation only; no inhabitants or synthesis claims."]
    shape_source += [f"#check (fun (witness : {case['lean_type']}) => witness)" for case in cases]
    (args.output / "Types.lean").write_text("\n".join(shape_source) + "\n", encoding="utf-8")
    print(f"Generated {len(cases)} Lean goals in {args.output}", flush=True)
    if args.replay_output:
        output = args.replay_output.read_text(encoding="utf-8")
    elif args.leant:
        metadata["leant_executable_sha256"] = hashlib.sha256(
            args.leant.read_bytes()).hexdigest()
        # Keep the exact transcript on disk while the run is active, so a
        # long acceptance run has inspectable progress without holding all
        # output in a parent-process pipe until synthesis finishes.
        output_path = args.output / "leant-output.txt"
        with output_path.open("w", encoding="utf-8") as transcript:
            run = subprocess.run([str(args.leant.resolve()), "--plain"], input=source,
                                 stdout=transcript, stderr=subprocess.STDOUT,
                                 text=True, encoding="utf-8", cwd=ROOT)
        output = output_path.read_text(encoding="utf-8")
        if run.returncode:
            print(f"Leant exit code: {run.returncode}", file=sys.stderr)
        metadata["leant_exit_code"] = run.returncode
        metadata["leant_executable_unchanged"] = (
            hashlib.sha256(args.leant.read_bytes()).hexdigest()
            == metadata["leant_executable_sha256"])
        if not metadata["leant_executable_unchanged"]:
            print("Leant executable changed during synthesis; rerun against one build",
                  file=sys.stderr)
    else:
        return 0
    validate_settings(output, source)
    results = parse_results(output, cases)
    kernel_path = args.output / "Candidates.lean"
    kernel_path.write_text(kernel_source(results), encoding="utf-8")
    command = [args.lean]
    if args.toolchain:
        command.append("+" + args.toolchain)
    command.append(str(kernel_path.resolve()))
    replay = subprocess.run(command, capture_output=True, text=True,
                            encoding="utf-8", cwd=ROOT)
    (args.output / "kernel-output.txt").write_text(replay.stdout + replay.stderr, encoding="utf-8")
    count = sum(result["status"] == "candidate" for result in results)
    axiom_free_count = sum(
        reported_axioms(replay.stdout, "ChurchCorpus." + result["id"]) == set()
        for result in results if result["candidate"] is not None)
    replay_ok = (replay.returncode == 0 and "sorryAx" not in replay.stdout + replay.stderr
                 and axiom_free_count == count)
    report = {**metadata, "candidate_count": count, "kernel_replay_passed": replay_ok,
              "kernel_exit_code": replay.returncode, "axiom_free_count": axiom_free_count,
              "results": results,
              "leant_output_sha256": hashlib.sha256(output.encode()).hexdigest()}
    (args.output / "results.json").write_text(
        json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Candidates: {count}/{len(cases)}; kernel replay: {'PASS' if replay_ok else 'FAIL'}")
    failures = [result["name"] for result in results if result["status"] != "candidate"]
    if failures:
        print("Missing: " + ", ".join(failures))
    if not replay_ok:
        print(replay.stdout + replay.stderr)
    return 0 if (count == len(cases) and replay_ok and not metadata.get("leant_exit_code", 0)
                 and metadata.get("leant_executable_unchanged", True)) else 1


if __name__ == "__main__":
    raise SystemExit(main())
