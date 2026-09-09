# Canonical contextual synthesis passes native integration

Leant promotes Djex from `bfc3692e` to
`3adfac5c57ad5e1bec77c598c647f6c8eb38e6e6` after a strict build and ten fresh
native integration gates. This brings the accepted canonical contextual
certificate and Haskell frontend changes into the dependency used by Leant.
The request-deadline repair remains unchanged.

## Integrated changes

The [canonical one-shot milestone](2026-09-09-one-shot-contextual-output.md)
retains lexical dictionary evidence alongside specialization certificates,
preserves source binder scope in contextual output, and can give internal
flexible type variables a local Haskell scope. Certificate ownership, selections,
lexical slots and complete application chains remain checked. Activated
obligations do not become lexical assumptions or acquire instance-discharge
identity through this integration.

Canonical Haskell acceptance covers its documented four-signature one-shot
matrix, exact displayed-output replay and corpus regressions. This report adds
native Leant integration evidence. It does not claim that Leant exposes the
Haskell one-shot command syntax or that the native matrix covers every remaining
contextual form.

## Fresh validation

The executable, complete test executable and fake-Z3 helper build with `-Werror`
and one build job. No completed gate from the old dependency or executable is
reused. Every gate runs serially against frozen sources, fixtures, plan and
runtime identities.

| Gate | Accepted coverage |
| --- | --- |
| Unit | 705/705 tests; complete unfiltered inventory and matching passing summary |
| Global methods | Six ordinary/behavioral cells and exact displayed-output replay |
| Method controls | Nine False/cache sessions with actual request correlation |
| Local context | 39 cells: 18 positive replays, three False controls and 18 explicit unsupported-metadata refusals |
| Simplification | 15 queries: six candidates, three False controls and six inconclusive controls |
| Native List recursors | 12 cells across Djinn/Exference/Both; nine positive replays and three completed False controls |
| Extended Lean Exference | 13 operations and one completed False control |
| Nested foralls | Nine cells; six positive outputs and three False controls |
| Native Djinn signatures | 350/350 candidates with axiom-free full-signature kernel replay |
| Native Exference signatures | 350/350 candidates with axiom-free full-signature kernel replay |

The final aggregate requires all ten terminal gates and unchanged recorded
inputs. Corpus acceptance checks exact displayed terms at the translated
signatures and requires empty axiom inventories. Partial Church cases retain
the agreed explicit supplied default. Search bounds, method source guards,
provider definitions and independent replay checks remain enforced.

The [acceptance receipt](https://github.com/VladimirReshetnikov/Leant/blob/main/test-recursive/receipts/one-shot-native-integration.json)
and [source/run archive](https://github.com/VladimirReshetnikov/Leant/blob/main/test-recursive/receipts/one-shot-native-integration.zip)
retain strict-build output, exact commands, child transcripts, complete test
inventories, source snapshots, executable identities and independent replays.
Every archive member is rehashed during packaging.

## Remaining work

This closes dependency integration following the accepted
[request-deadline repair](2026-09-09-request-deadline-integration.md). Remaining
public forms include typed list output, applicable named-function `where`
one-shot queries and kinded source binders. Broader provider and dictionary
evidence remains in scope.

The full Church behavior objective remains **160 cells**: 32 operations across
two Haskell engines and three Lean modes, with negative controls and replays
additional. Native tree synthesis is still unaccepted in all three modes. The
accepted native List and signature checks do not establish tree construction,
the missing operation behaviors or complete rank-N/impredicative support.

Archive SHA-256: `3ad290c3456f5c0ac84c85a012f47f55b5d06ababc2181ff3c948b7268baa3b2`.
