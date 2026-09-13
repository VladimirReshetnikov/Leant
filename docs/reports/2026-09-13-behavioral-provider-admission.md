# Behavioral provider admission: a retained unsuccessful experiment

An isolated provider-first scheduling change admits the exact numeric inventory for Lean Djinn `length`, but does not produce an implementation satisfying the original behavioral query. The change is not accepted for release. It has been removed from the validation checkout after its exact source, diff, controller, and outputs were archived.

The experiment used Leant `dccad48b57f7af9c859e654115776dd93bc9db87` with clean Djex `c1ad560e106f59df07d1a32c3b51158ef749fc99`, plus a 14-line `Main.hs` diff. It kept the original full target, 44 finite observations, provider cap two, Interleave traversal, search/verification window 65536, choice budget 500000, Exference step limit 100000, and 90-second command deadline. Only the provider-admission order changed.

| Check | Result |
| --- | --- |
| Strict executable/unit-target build with `-Werror`, one job | Exit zero; the unit suite was not run in this diagnostic. |
| Exact provider admission | `BehaviorExtendedNumeric.zero` and `BehaviorExtendedNumeric.successor`, in the required order; no extra values. |
| Original `length` query | No accepted implementation; 88 falsifications, zero inconclusive observations; command deadline reached. |
| Original provider-free False control | 623 falsifications; zero accepted or inconclusive observations. |
| Same-environment provider-enabled False control | 512 falsifications; zero accepted or inconclusive observations; both exact numeric providers observed. |
| Source, runtime, and controller integrity | Unchanged throughout the completed run. |

The captured diagnostic contains 51 candidate groups and 102 rendered variants. All 102 begin with `fun _ _ =>`, discarding the type and Church-list arguments. The metric totals distinguish 88 verified variants from 14 backend-request verification failures. These observations identify the explored prefix; they do not establish that a fold-based derivation is absent from the search space or that all failed verification requests are search failures.

Admission starvation was real, but admission alone is insufficient. Do not promote this scheduling policy or repeatedly raise limits. Before another search repair, trace the demanded list instantiation and the competing numeric constructor plans at the original bounds. The next substantive work remains scoped type/dictionary evidence and supplied-default reduction accumulators.

The [receipt](https://github.com/VladimirReshetnikov/Leant/blob/main/test-church/receipts/behavioral-provider-admission-diagnostic-2026-09-13.json) identifies the [complete archive](https://github.com/VladimirReshetnikov/Leant/blob/main/test-church/receipts/behavioral-provider-admission-diagnostic-2026-09-13.zip): 461 artifacts, 2,948,633 bytes, SHA-256 `acc36b74849cd2677abd60fba1e0693dfacf46a0a35eeb5f2db55024b30dd776`. Every archive member was rehashed after packaging. This diagnostic adds no behavior acceptance; the historical ledger remains 92 accepted, six attempted without acceptance, and 62 without indexed evidence.
