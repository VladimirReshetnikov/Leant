# Combined behavioral certificates reduce native verification requests

Leant now checks a candidate and attempts both decision polarities in one
kernel-checked command. The two previously failing native Exference recursor
queries pass at their original bounds. This is an accepted verification
increment within priority 2; full native integration and the broader priorities
1–4 remain incomplete.

The [receipt](https://github.com/VladimirReshetnikov/Leant/blob/main/test-behavioral/receipts/combined-verification.json)
and [archive](https://github.com/VladimirReshetnikov/Leant/blob/main/test-behavioral/receipts/combined-verification.zip)
preserve 2,592 hashed artifacts: production sources and patch, generated Lean
controls, exact request traces, live queries, independent replays, complete unit
inventories, and earlier failures. The archive SHA-256 is
`9ed5ae3982884f18023be3a47c084be263cd4a11c3381c8dd6eddc02b952c73c`.

## Result at the original bounds

| Native Exference query | Previous terminal result | New checked result |
| --- | --- | --- |
| Supplied native List fold: append | 90-second timeout; 513 falsifications in the original integration run | Pass: one accepted candidate after 548 falsifications, zero inconclusive observations; 45.96 seconds for the live process |
| Same target, literal False | 90-second timeout; 299 falsifications | Pass: completed query, 299 actual falsifications, zero passes/inconclusive observations; 75.50 seconds for the live process |

Both command files are byte-for-byte identical to the original inputs. The
90-second command deadline, window/verification 1,024, 100,000 steps and choices,
provider inventory and cap 80 are unchanged. Process times include startup and
are not kernel CPU measurements or isolated per-candidate speedup estimates.

The displayed append implementation is:

```lean
fun f x y => f _ (.cons) y x
```

Independent Lean replay checks it at the complete requested type, with the fold
supplied as an argument, and proves every original Nat/Bool observation.
`List.foldr`, the implementation and its observation proof have empty reported
axiom inventories. No reference implementation enters synthesis discovery.
These two focused results do not replace a fresh complete native recursor matrix
or establish native tree acceptance.

## Implementation and proof boundary

An ordinary core `example` constructs a dependent pair. Its first field is the
exact candidate at the complete requested type. Its second field is an
`Option (Decidable p)` for the exact lexical assertion: a checked proof of the
assertion, a checked proof of its negation, or neither. The candidate remains an
explicit value even when the predicate ignores it. A fixed trace tag follows
only the successfully closed tactic branch. The command uses no extra imports,
private declaration names, native evaluator or new user-visible declarations.

A tag alone has no proof authority. Main first rejects transport/fatal failures,
checks Lean diagnostics and sorries, and requires a returned command environment.
The decoder accepts exactly one valid tag; missing, malformed, duplicate and
conflicting tags do not classify the candidate. Lean error recovery can emit an
apparent success tag alongside a type error or sorry warning; the controls
explicitly exercise that situation.

When a nonfatal combined attempt fails, the original isolated type check and
proof pipeline remain available. When its checked certificate returns neither
polarity, the original positive/negative `decide` and bounded `simp` attempts
still run with their original individual proof allowances. This preserves the
fallback coverage despite the combined attempt's shared 200,000-heartbeat bound.
Every request still obeys the original absolute query deadline. Transport/fatal
failures do not retry a potentially retired backend.

A one-use handoff between the adjacent verification callbacks retains the exact
candidate text; it is not a cross-candidate cache or substitute for graph
ownership. Candidate order, engine/renderer ownership, variant accounting and
the success quota retain their existing contracts. Ordinary synthesis without
a behavioral assertion keeps its existing verification path.

## Validation and retained failures

- Strict executable/test build passes with `--ghc-options=-Werror`.
- Ten production-generated, Init-only Lean controls pass: positive, negative,
  undecided, ill-typed, sorry, duplicate-tag, trailing-comment, lexical-name,
  namespace and declaration-collision cases.
- Three public smoke queries pass: finite identity, actual False rejection and
  quantified identity through the original simplification fallback. Complete
  request capture confirms the combined role and fallback sequence.
- The fresh complete unit suite passes **702/702 in 359.92 seconds**, matching
  its full unique inventory. The previous complete run passed 701/702 and failed
  while reading a missing fake-solver event file. That case and the complete
  suite pass on unchanged source/executable bytes; no cause is proven and no
  limits or expectations were changed to obtain the passing run.
- All six original global-method cells pass with exact full-type/payload replay.
- All nine method-control/cache sessions pass after the trace validator learns
  the new protocol. It checks the complete candidate field, requested type,
  original binder/predicate and both proof branches, preserving exact replay.
  Twelve adversarial trace tests also pass. The earlier validator's rejection
  of the unknown callback role remains recorded.

The positive-method run preceded changes to the three trace-control Python
files. Those files are not imported or executed by the positive-method driver;
its production sources, executable, queries and replays are unchanged. The
receipts retain that fixture-version distinction rather than claiming one
uninterrupted run of every gate.

Earlier control generation failed on a hidden Cabal package and overly specific
diagnostic spelling; their raw files remain. Lean did report sorry in the
original Option-only control: a quote mismatch caused that fixture failure.
The explicit candidate field is a design clarification, not a claimed repair
of an observed missing-sorry diagnostic. The initial four-variant Nat identity
smoke fixture selected zero/successor candidates; the corrected polymorphic
fixture passes without increasing its limit.

## Remaining integration

**Later checkpoint:** the [next-delivery re-triage](2026-09-08-synthesis-next-deliveries.md)
records the fresh 12/12 native recursor matrix, 13/13 extended Exference behavior,
nested-result checks and 350/350 native Djinn signatures. The Exference signature
gate was still running; aggregate integration and dependency promotion remain
pending. The paragraph below records this component's earlier publication boundary.

Leant still commits Djex `4a4ed0fc`; this verification increment is tested with
working Djex `bfc3692e`. Local contexts, the full simplification/recursor matrices,
extended behavior, nested foralls and both native signature corpora continue as
separate integration gates. No unexecuted or running gate contributes accepted
coverage here. Advance the dependency only after the complete required gates
pass at the final dependency.

The [current roadmap](2026-09-07-synthesis-retriage.md) retains implicit-root and
one-shot Haskell output, typed lists, native tree construction, contextual
evidence, and all 13 extended plus 19 supplied-default operations across Haskell
Djinn/Exference and Lean Djinn/Exference/Both. This increment closes none of those
broader requirements by itself.
