# Church behavior evidence ledger

Generated from pinned historical receipts. This is not a current-revision acceptance run.
A = historical acceptance recorded; F = attempts without indexed acceptance; ? = no indexed evidence.
The ? marker does not assert that a case was never run. Controls and replays are additional to the 160 cells.
See `behavior-ledger.json` for individual receipt pointers, hashes, limits and runtime/source metadata.

| Group | Operation | Haskell Djinn | Haskell Exference | Lean Djinn | Lean Exference | Lean Both |
| --- | --- | --- | --- | --- | --- | --- |
| extended | foldr | A | A | ? | A | ? |
| extended | foldl | A | A | ? | A | ? |
| extended | length | A | A | ? | A | ? |
| extended | fromMaybe | A | A | ? | A | ? |
| extended | maybeToList | A | A | ? | A | ? |
| extended | listToMaybe | A | A | ? | A | ? |
| extended | catMaybes | A | A | ? | A | ? |
| extended | squashMaybe | A | A | ? | A | ? |
| extended | isLeft | A | A | ? | A | ? |
| extended | maybeEither | F | A | ? | A | ? |
| extended | either | A | A | ? | A | ? |
| extended | numeralSuccessor | A | A | ? | A | ? |
| extended | numeralAdd | A | A | ? | A | ? |
| supplied_default | head | A | A | A | A | A |
| supplied_default | last | ? | A | ? | ? | ? |
| supplied_default | at | F | F | ? | ? | ? |
| supplied_default | foldl1 | ? | F | ? | ? | ? |
| supplied_default | foldr1 | ? | ? | ? | ? | ? |
| supplied_default | fromJust | A | A | A | A | A |
| supplied_default | fromLeft | A | A | A | A | A |
| supplied_default | fromRight | A | A | A | A | A |
| supplied_default | maximumBy | ? | ? | ? | ? | ? |
| supplied_default | maximumOn | ? | ? | ? | ? | ? |
| supplied_default | minimumBy | ? | ? | ? | ? | ? |
| supplied_default | minimumOn | ? | ? | ? | ? | ? |
| supplied_default | minMaxBy | ? | ? | ? | ? | ? |
| supplied_default | minmaxElement | ? | ? | ? | ? | ? |
| supplied_default | atKey | ? | A | ? | ? | ? |
| supplied_default | reduce | ? | ? | ? | ? | ? |
| supplied_default | maximum | ? | ? | ? | ? | ? |
| supplied_default | minimum | ? | ? | ? | ? | ? |
| supplied_default | minMax | ? | ? | ? | ? | ? |
