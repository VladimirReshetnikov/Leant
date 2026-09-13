# Reduction carrier boundary and unsuccessful construction experiments

The original `foldl1` query now has a verified trace of two concrete instantiation routes. Djinn's root carrier family recovers `a -> a` but omits the compiler-checked witness carrier `(a -> a) -> a -> a`. At Exference's root fold application, the explicit carrier list is empty and the observed overapplication siblings select only a result of the form `d -> a`.

An implemented continuation-carrier experiment does not yet produce an accepted reduction. It passes strict builds and all 97 private Exference engine tests, but fails the focused Djinn and native Exference behavior gates. The rules remain unreleased. Carrier availability is part of the problem; the evidence does not establish it as the only cause or show that a scheduling change will fix the remaining construction.

## Corrected original-query trace

The trace uses accepted Leant `3b24ebbd4022255b8e22888408d7e890984f3887` and Djex `ebadbefd175ac98d4f79393d4ed4a4089a1725bf`, with temporary logging in the two engines and no constructor patch. The original query inputs are extracted from the previously published reduction-baseline archive. The settings remain 65,536 candidates/verifications, 500,000 choices, 100,000 steps, Interleave and a 90-second command deadline.

The first runner accidentally doubles CR in Windows line endings. Its nonempty command lines match, but the input equality check fails, so it is retained as an unsuccessful capture. The corrected runner normalizes line endings before submission; both captured inputs then match the original commands under CRLF-to-LF normalization. Sources, runtimes and controller remain unchanged in both runs.

| Corrected trace | Observation |
| --- | --- |
| Djinn `foldl1` | No match; 1,745 falsified observations, zero inconclusive. One root carrier-family event. |
| Exference `foldl1` | No match; 3,705 falsified observations, zero inconclusive. Six root provider/instantiation events. |

Djinn's five recovered types comprise `CList a -> a`, `a -> a`, `a -> a -> a`, and two larger suffixes of the opened target. The required function-only witness carrier is absent from that family. Exference records the ordinary `r := a` use, grounded extra-argument domains `a`, `Bool` and `Unit`, and the flexible-domain sibling. Each of the latter chooses `r := d -> a`; none directly names the witness carrier, whose result needs two further applications. This trace concerns the inspected root routes, not every possible derivation or a proof of non-inhabitation.

## Implemented experiment and diagnostic controls

The experiment forms `f -> f` from monomorphic function types already observed in the query or lexical scope. Djinn appends these proposals within its existing 512-proposal bound. Exference uses a finite prefix of scoped function types, instantiates a proper result variable, then splits the selected body again so that all resulting value arguments enter ordinary search. It does not match an operation name, add a reference implementation or raise query bounds.

The canonical experiments start at Djex `1481e918d42330087dc1ecdb79fd93921572c967` plus the retained patches. The new Djinn behavioral regression varies two defaults, subtraction, a decimal-order operation and both projections, with empty, singleton and longer inputs. It seeks both left and right reductions from the original polymorphic type. Its interpreter is a test oracle, never part of search.

| Gate | Result |
| --- | --- |
| Djinn regression before the new rule | Strict build passes; neither reduction found; 3,467 candidates before the original 500,000-choice limit. |
| Djinn regression with the new rule | Strict build passes; neither reduction found; 4,128 candidates before that same choice limit. |
| Complete private Exference engine suite with the rule | 97/97 pass. |
| Djinn control with the fold already specialized to the witness carrier | Strict build passes; the separate Tasty diagnostic timeout fires at 120 seconds. This is a different monomorphic-fold target and not a completed exhaustive search. |
| Native Exference `foldl1` with only its new rule | Strict build and oracle pass; no match, 3,400 falsifications and zero inconclusive observations. |
| Native Exference actual False control | Passes with 299 falsifications and zero inconclusive observations. |

No full canonical/native release regression suite or new Church behavior acceptance follows from these experiments. In particular, the 97-test result is not the complete 515-test Exference suite. Logging affects throughput, so the falsification counts across runs are not a performance comparison.

## Next implementation boundary

The carrier-only experiment has reached its focused stopping point. Preserve it, and investigate the smaller Djinn method/tail failure using its [canonical reproducer](2026-09-13-constructor-closure-after-selections.md). Capture which proof plans consume the 32 raw candidate slots and whether the method/constructor composition is delayed, rejected or absent. Do not raise the bounds, discard source evidence, or infer a shared cause with reductions without that trace.

Reduction construction remains required, along with its 15 behavior cells and the separately validated 45 extrema cells. The next reduction investigation must inspect actual term construction or plan admission; another change to the carrier vocabulary alone is not supported by the results here. The historical Church ledger remains 92 acceptances, 15 attempted cells without indexed acceptance and 53 without indexed evidence.

The [receipt](https://github.com/VladimirReshetnikov/Leant/blob/main/test-church/receipts/reduction-carrier-boundary-2026-09-13.json) and [archive](https://github.com/VladimirReshetnikov/Leant/blob/main/test-church/receipts/reduction-carrier-boundary-2026-09-13.zip) retain the unsuccessful and corrected traces, baseline and experimental patches, exact source snapshots, controllers, build/test captures and native oracle/control evidence. All 2,353 members were rehashed. The archive is 14,968,465 bytes, SHA-256 `17a661165f5a52f268db49271fc3d901e12b2e140deec99796c62caf2ea85642`. Every recorded tested source snapshot was also checked against its run's input hashes.
