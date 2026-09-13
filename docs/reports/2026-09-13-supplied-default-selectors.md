# Supplied-default Church selectors: eight Haskell cells accepted

Live synthesis of `head`, `fromJust`, `fromLeft` and `fromRight` passes in both
Haskell Djinn and Exference at the established limits. Every target retains
its original quantified signature with the agreed explicit default argument.
All eight exact displayed implementations pass independent GHC compilation
and execution of their original 24 observations per cell. No reference
implementation or ordinary provider is loaded into search.

| Operation | Djinn candidates checked | Exference candidates checked | Exact replay |
| --- | ---: | ---: | --- |
| `head` | 3 | 2 | Both pass |
| `fromJust` | 2 | 2 | Both pass |
| `fromLeft` | 2 | 2 | Both pass |
| `fromRight` | 2 | 2 | Both pass |

Both actual False queries pass, recording one falsification in Djinn and 256
in Exference, with no true results, errors or timeouts. All nine independent
oracle controls pass. All 44 owned processes terminate with exit code zero.
The batch's 328 frozen source files, runner inputs and runtime hashes remain
unchanged through execution and packaging.

Djinn uses interleave, a 65,536-candidate window and 500,000 choice budget;
Exference uses a 256-candidate window and 100,000 budget. Both retain 100,000
steps, queue 8,192, first selection, balanced ranking, a 300-second outer
process guard and two-second independent replay evaluation. The exact per-engine
settings and captured public commands are recorded in the raw receipt.

Before this run, the failed derived-value constructor experiment was removed
from the working implementation. Its diagnostic sources and logs remain local
under `dist-newstyle/contextual-derived-value-rejected-v2`. The existing
contextual-composition repair and its captured failing regression remain
uncommitted. A fresh `cabal build exe:djex --ghc-options=-Werror -j1` passes.
This selector batch validates behavior against that frozen working source; it
does not establish a complete regression pass or accept the constructor repair.

The [receipt](https://github.com/VladimirReshetnikov/Djex/blob/main/test-church/receipts/supplied-default-selectors-2026-09-13.json)
and [archive](https://github.com/VladimirReshetnikov/Djex/blob/main/test-church/receipts/supplied-default-selectors-2026-09-13.zip)
retain 477 artifacts, including the source snapshot, exact working diff from
base `ba049f15900e0578d2acf6ff96c80a1cf25ebf3b`, commands, raw captures,
displayed implementations, oracle/replay sources, strict build and manifests.
All archive members were rehashed. The archive is 2,274,627 bytes with SHA-256
`dcc8320cd93192e74525573887185a41ce71a2fb8657e7d57d092bf23d85fe0d`.
Runtime and replay executables are recorded by identity, not redistributed.

The [160-cell ledger](../../test-church/behavior-ledger.md) now indexes 48 cells
with historical acceptance, four with attempts but no indexed acceptance and
108 with no indexed evidence. Adding this batch changes eight previously
unindexed cells; it is not a claim that those operations were impossible in
earlier versions or that every historical receipt has been indexed. The
corresponding Lean cells still require their own live runs. Missing Church
behaviors, constructor acceptance, scoped dictionary reconstruction and public
query/provider extensions remain active deliveries.
