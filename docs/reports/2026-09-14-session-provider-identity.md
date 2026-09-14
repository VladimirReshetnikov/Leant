# Qualified session provider identity and integer-indexing diagnosis

Leant now uses fully qualified declaration names reported by Lean during successful synthesis replay when selecting session providers. A declaration inside `namespace Outer` therefore competes as `Outer.value`, including when its namespace does not occur in the requested type. The provider cap, ranking, search limits, exact-context serialization, and candidate verification rules are unchanged.

This repairs one prerequisite for the original supplied-default Church `at` query. **Integer indexing is still open.** The original three-engine baseline admitted no numeric provider and found no matching implementation. A diagnostic with an explicitly smaller verification prefix now admits exactly `BehaviorPartialNumeric.intCase`, but still finds no matching candidate. It is not acceptance at the original limits.

## Cause and implementation

Previously, discovery obtained session names from a textual scan of the command history. The scan did not track namespaces: a declaration of `BehaviorPartialNumeric.intCase` inside a namespace was recorded as `intCase`. The fully qualified environment constant consequently lost session priority. In the diagnostic, `Int.cast` occupied the single allowed provider slot instead.

Synthesis replay now requests the backend's structured `declarations` metadata and retains each `fullName` alongside the environment and replayed history. Appending history extends both; undo or replacement reconstructs both from the base. Failed replay entries contribute neither an environment transition nor declaration names. Transport failure prevents publishing a partial replay cache. Provider discovery uses the names belonging to its exact cached environment. It does not infer identity from diagnostic messages, short names, or matching suffixes. The existing textual helper remains in browsing/completion; changing those commands is outside this synthesis repair.

The metadata is taken from Lean REPL's supported declaration-response option, checked here with REPL v1.3.18 and Lean 4.32.0. A backend that omits this optional metadata contributes no session priority, while ordinary root-based discovery remains available. Declaration metadata identifies candidates for discovery; the existing environment lookup, provider filtering, translation and Lean verification still govern their use.

## Evidence and limits

| Check | Result |
| --- | --- |
| Strict executable and test build | Passed with `--ghc-options=-Werror -j1`. |
| Complete native suite | All **768 tests passed** in 362.33 seconds; complete inventory and final source/runtime integrity verified. |
| Six public inventory sessions | Passed: nested namespace, fully qualified spelling, attributes/comments, duplicate short names, append/undo, and a rejected declaration. |
| Literal-False queries in those sessions | Nine conclusively rejected; no accepted candidates or inconclusive observations. The repeated query after a rejected entry also exercises unchanged provider-cache reuse. |
| Original native integer `at`, Djinn/Exference/Both | Failed: zero of three positive cells accepted; all three actual-False controls passed. The primitive and reference/primitive-only witness controls passed. |
| Original baseline with verification prefix 1, before repair | One provider admitted, incorrectly `Int.cast`; zero matching candidates. |
| The same diagnostic after repair | Exactly `BehaviorPartialNumeric.intCase` admitted; zero passed, four falsified, zero inconclusive. |

The indexing query keeps source `Int`, an explicit supplied default, and all 168 observations, including negative, zero, in-range and out-of-range indices over multiple payload types. Its only approved provider is the generic integer case primitive. The independently checked primitive-only witness is never added as a provider.

The original public settings remain `synth-window 65536`, `synth-verify 65536`, 100,000 search steps, 500,000 choices, a 90-second synthesis deadline, and provider cap 1, with library and classical synthesis disabled. The two diagnostics change only `synth-verify` to 1 relative to their saved original input; the second also uses the repaired executable. Their positive query failures do not become Church acceptance.

The baseline exposes a separate scheduling defect: the structural first lane can spend the entire shared deadline checking rejected candidates before provider discovery is reached. The declaration repair does not change that schedule. The next indexing step must give discovery and provider search an opportunity while preserving the original structural continuation, total allowances, and shared deadline. Simply shrinking the user's verification allowance or restarting structural search would not establish the required behavior.

## Reproduce

Build against Leant's committed Djex dependency, then pass the actual executable, backend, and Lake paths:

```powershell
cabal build leant:exe:leant leant:test:leant-synth-tests --ghc-options=-Werror -j1
$leantExe = (cabal list-bin leant:exe:leant).Trim()
python -X utf8 -B test-context/run_session_provider_names.py --leant $leantExe --backend $backendExe --lake $lakeExe --output dist-newstyle/session-provider-recheck
```

The new controller saves exact public inputs, transcripts, source snapshots, runtime hashes, inventories and false-control outcomes. Its small verification prefix is intentional: this gate checks discovery identity and cache lifetime, not indexing synthesis.

The [receipt index](../../test-church/receipts/session-provider-identity-2026-09-14.json) describes the [portable archive](../../test-church/receipts/session-provider-identity-2026-09-14.zip), including the unsuccessful original baseline, both diagnostics, the six public sessions and full native regression controller. Runtime binaries are identified by hashes rather than bundled. Source and runtime integrity are checked separately for the original and repaired runs.

Leant retains Djex `9a2d59d958a60ff3b6899697a60b6985a5cf73a3`; this repair does not adopt the later Haskell milestones. The remaining provider-kind composition, deconstructor transport, native dependency adoption, original integer indexing and simultaneous two-universe query retain their acceptance requirements in the [current priorities](2026-09-14-synthesis-next-priorities.md). No new Church behavioral acceptance is claimed.
