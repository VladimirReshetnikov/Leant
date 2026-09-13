# Accepted native Exference lexical selections

Leant now pins Djex `ebadbefd175ac98d4f79393d4ed4a4089a1725bf`, after the complete isolated native acceptance run passed. This delivers the [Exference selection repair](2026-09-13-exference-scoped-selections.md) for global methods and local rank-N callbacks. The separate constructor patch remains unaccepted.

## Validation and source identity

The run used Leant `d9dfcfad0158092e094e45931d1db0e503e6aded`, Djex `a4c1bad92d1c63bb533113a7497a577c418559db`, and the seven-file Exference overlay now committed in `ebadbefd`. Before promotion, all 111 recorded Leant source inputs matched committed Leant `48585ca515d80617431102f2585cfa193e445a8e`, and all 331 recorded Djex inputs matched `ebadbefd`, after CRLF-to-LF normalization. The additional selection fixture matched the publication file. The archive retains exact tested bytes and their hashes; the receipt separately records normalized publication parity.

| Gate | Result |
| --- | --- |
| Strict native build | Passed with GHC 9.12.4, `-Werror`, one job |
| Global/local lexical selection matrix | 12/12 positives, every exact displayed term independently replayed in Lean |
| Actual False controls | 6/6; each requires observed candidate rejection, not just an empty result |
| Complete native unit suite | 707/707 |
| Djinn Church signature corpus | 350/350, exact kernel replay with empty axiom inventories |
| Exference Church signature corpus | 350/350, exact kernel replay with empty axiom inventories |
| Final source, runtime and controller integrity | Unchanged throughout acceptance |

The fixture varies selected outer/inner dictionaries, type order, payload order, same-type dictionary payloads, and callback behavior. Each single engine passes its own four positives. In Both mode, the global/local outer choices originate in Djinn and the global/local inner choices originate in Exference. Combined success is therefore reported alongside independent engine coverage.

The selection queries retain 32 candidate/verifier allowances, 20,000 steps/choices, a 45-second query deadline and a separate 180-second process guard. Global discovery admits only the designated class method; local callback cases disable discovery. Reference implementations appear only in separate oracle/replay files. The fixture checks graph ownership and exact displayed implementations.

## Portable evidence and remaining work

The [receipt](https://github.com/VladimirReshetnikov/Leant/blob/main/test-context/receipts/exference-scoped-native-acceptance-2026-09-13.json), [archive](https://github.com/VladimirReshetnikov/Leant/blob/main/test-context/receipts/exference-scoped-native-acceptance-2026-09-13.zip), and [fixture](https://github.com/VladimirReshetnikov/Leant/blob/main/test-context/run_scoped_selections.py) retain the complete build and acceptance evidence, exact source snapshot, controllers, observations, outputs, and kernel replay files. All 650 archive members were independently rehashed before publication. The archive is 3,305,734 bytes, SHA-256 `a76fc7f5a18da4b218f1a149f65671a6da66e1439b84841f1e95ad17c1fd46fb`.

The [earlier native diagnostic](2026-09-13-native-selection-diagnostic.md) remains the unsuccessful baseline. No complete CLI rerun is claimed by this native receipt. The run excludes the pending constructor edits and adds no Church behavior cells by association. The ledger remains 92 historical acceptances, 15 attempted cells without indexed acceptance and 53 without indexed evidence; it is not a current-revision pass rate.

The [revised delivery order](2026-09-13-synthesis-delivery-retriage.md) starts with one bounded constructor closure pass, then reduction construction and separately validated extrema. Broader kind/universe, contextual-provider and public-interface obligations remain part of the practical goal.
