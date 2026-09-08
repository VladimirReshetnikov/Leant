# Global contextual method regression

These runners exercise actual class-projection discovery through public Leant
commands, followed by exact full-type Lean replay. `MethodOracle.lean` is checked
in isolation; its reference implementation never enters a synthesis session.
Each session discovers only `Ctx.C.out` under a provider cap of one.

Run serially after a strict build of `exe:leant` and `test:leant-synth-tests`.
The options below name executable paths: `LEANT` is the built executable,
`TEST_EXE` the built boundary-test executable, `LEAN` the actual pinned kernel
binary, and `BACKEND` the matching Lean REPL executable. Output directories must
be new. Use the same executables for the method and supplemental runs.

```text
python test-context/global-methods/run_methods.py --leant LEANT --test-exe TEST_EXE --lean-runtime LEAN --backend BACKEND --output METHOD_OUTPUT
python test-context/global-methods/run_controls.py --leant LEANT --lean-runtime LEAN --backend BACKEND --positive-receipt METHOD_OUTPUT/results.json --kind false --output FALSE_OUTPUT
python test-context/global-methods/run_controls.py --leant LEANT --lean-runtime LEAN --backend BACKEND --positive-receipt METHOD_OUTPUT/results.json --kind cache --legacy-window 4 --output ORIGINAL_CACHE_OUTPUT
python test-context/global-methods/run_controls.py --leant LEANT --lean-runtime LEAN --backend BACKEND --positive-receipt METHOD_OUTPUT/results.json --kind cache --legacy-window 32 --capture-rows 512 --output EXPANDED_CACHE_OUTPUT
python -m unittest discover -s test-context/global-methods -p test_capture.py -v
```

The method matrix contains ordinary and named-`where` queries in Djinn,
Exference and Both. All six retain the original `∀ (α : Type), [Ctx.C α] → Nat`
goal and distinguish dictionaries carrying 7 and 11 at Nat and Bool. Metadata
preflight separately checks real class projections and excludes ordinary
structures, namespace siblings and superclass subobjects.

Each cache session runs a legacy query, a contextual method query and the same
legacy query again. It requires the actual `Nat.add` provider before and after,
an identical provider-query key, fresh contextual source discovery, no second
legacy discovery, the displayed variant's own verification request, and exact
kernel replay of all three outputs. All request/backend identities, terminal
responses, cleanup and capture-byte counts must agree; omissions are failures.

The default four-slot legacy probe preserves the original failing search
workload. `--legacy-window 32` is an explicitly expanded diagnostic, retaining
all other steps, queue, provider and deadline limits. Passing that diagnostic
does not establish success at four slots. The contextual method queries always
use the original 32-slot limit. Literal False controls are independent of the
legacy window and require actual negative predicate checking.

The portable capture helpers preserve the exercised recursor validators'
request, lifecycle and byte-accounting checks. Eleven adversarial unit controls
cover duplicate owners, a substituted term or backend, missing responses or
cleanup, incomplete capture, and inconsistent JSON/byte accounting. The runner
pins its dependencies and runtime/source inputs before and after execution.
No files from a previous `dist-newstyle` directory are required.

The default trace capacity remains 128 request records. The Exference cache
workload exceeds that count, so `--capture-rows 512` explicitly requests a larger
bounded diagnostic. The runner sets `LEANT_BACKEND_TRACE_REQUEST_LIMIT` and
requires the recorded limit to match. Payloads remain limited to 256 KiB each,
annotations to 8 KiB each, and aggregate retained UTF-8 to 4 MiB; omissions still
fail acceptance. This changes observation capacity, not search, verification,
provider or timeout budgets. The production constructor clamps request limits
to 0–1024 and reports the selected limit in every snapshot.
