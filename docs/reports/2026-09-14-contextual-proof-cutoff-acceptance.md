# Contextual proof-prefix checking: default Haskell acceptance

Djinn's contextual batch path now checks only the raw proof prefix requested by its candidate limit. This resolves the observed default unbounded one-shot timeout for the direct and wrapped qualified-polymorphic consumer examples. Search defaults, candidate limits, proof enumeration, ranking and source authority are unchanged.

## Cause and repair

The original path opened the query's term arguments, searched the resulting formula, checked every returned proof in that opened environment, and only then let the downstream owner apply the raw candidate cutoff. The proof list is lazy, so checking all of it forced work far beyond the requested prefix.

Temporary instrumentation on the original public query made this concrete. With a candidate cutoff of **one**, the 4,096-choice run checked **657 opened proofs** before returning. The unbounded run checked **11,049 proofs** before its separate 12-second diagnostic guard stopped it, without completing the opened-proof check. The instrumentation was removed and its exact source, output and runtime identity were retained.

The repair applies `take candidateLimit` to that preliminary check. Each retained proof is still checked against the exact opened environment, restored to the original lambda spine, and independently checked again at the original goal before conversion. The downstream raw cutoff, duplicate/rejection accounting and existing overflow lookahead remain unchanged. The repair does not change exhaustion into a non-inhabitation claim or remove the requested prefix's checks.

A new isolated regression forces every one of fourteen tuple fields to use a qualified local consumer with a choice of four supplied arguments. It therefore exercises the affected contextual path and has a large Cartesian proof tail without requiring additional normal-term search. Before repair it compiles and fails its 10-second guard. After repair it returns the one-candidate prefix promptly, checks the exact graph and candidate-limit completion, and verifies that bounded and unbounded settings retain the same candidate.

Earlier regression attempts are retained and labeled: one compilation failure, one incorrect collection-policy expectation, and a passing dictionary-independent fixture that did not exercise the affected path. None substitutes for the final failing qualified-consumer baseline.

## Acceptance

The [manifest](../../test-church/receipts/contextual-proof-cutoff-acceptance-2026-09-14.json) and [archive](../../test-church/receipts/contextual-proof-cutoff-acceptance-2026-09-14.zip) retain controllers, source snapshots, diagnostic traces, failed attempts, exact generated Haskell, GHC compile/execution output and runtime identities. Every archive member was reopened and checked against its hash; executable binaries are excluded.

- Strict CLI, Djinn-unit and adapter-integration builds pass with `-Werror`.
- All **148 Djinn tests** and **187 adapter integration tests** pass.
- At default settings, the original direct and wrapped one-shot requests complete in **0.77 and 0.98 seconds**, respectively. These are observed whole-process times, not a cross-machine performance guarantee.
- Default and explicit 4,096-choice public runs each pass two signatures through ordinary and named-function `where` entrances: **eight exact GHC compile/execution replays in total**, **four actual-False controls** and **two wrong-kind controls**. The observations distinguish consumer results and supplied payloads. No reference implementation enters the synthesis environment.
- Current captured source and runtime hashes remain unchanged across the acceptance gates. Exference is not modified by this repair; its earlier public acceptance remains a separate snapshot.

The public signatures and fixtures are the original [qualified-consumer examples](2026-09-14-contextual-polytype-acceptance.md). Both default and finite runs use the existing portable controller:

```powershell
cabal build djex:exe:djex djex:test:djinn-tests djex:test:djex-tests --ghc-options=-Werror -j1
$djexExe = (cabal list-bin djex:exe:djex).Trim()
python -X utf8 -B test-church/public_contextual_polytype.py --exe $djexExe --backend djinn --output dist-newstyle/proof-prefix/default
python -X utf8 -B test-church/public_contextual_polytype.py --exe $djexExe --backend djinn --choice-budget 4096 --output dist-newstyle/proof-prefix/finite
```

Use fresh output directories. The archive also preserves the exact regression-suite launchers and the instrumentation used to establish the cause.

## Scope and next work

Leant retains the separately accepted Djex `9a2d59d9` dependency for the [native dictionary-selection release](2026-09-14-dictionary-selection-acceptance.md). This follow-up establishes the Haskell prefix repair; it does not claim a new native dependency integration or rerun that native archive's 766 tests.

The observed default-query timeout is closed on the tested signatures. Other no-result searches still require their own diagnosis, and finite instantiation vocabularies remain bounded approximations. Exference explicit Haskell kinds, integer indexing and the original simultaneous two-universe query remain open under the [current plan](2026-09-14-synthesis-next-priorities.md). No Church behavior-ledger cells close here.
