# Exference lexical kind ownership and independent checker prerequisite

> Historical prerequisite. The [subsequent public ground-kind milestone](2026-09-14-exference-kinded-source-acceptance.md) connects this scope to search and passes the original 11-case public corpus. The 120-test controller below reproduces this earlier revision; the newer report supplies the current integration controller and remaining provider/native obligations.

Exference now has a private lexical kind scope and an independent expression-checking entrance that consumes it. The final strict build passes **120 private engine tests and all 515 ordinary Exference tests**. This is a prerequisite for explicit Haskell kinded synthesis: the public adapter still returns DJEX_EXF_SOURCE_KINDS, and the public 11-case synthesis matrix remains open.

## Implemented behavior

Checked source binders acquire distinct identities outside the supplied reserved namespace. Kinds follow those exact identities, including shadowed binders, vacuous binders, free source variables and binders used only in class constraints. Additional provider schemes acquire their own fresh namespaces and must use the same nominal/class kind assumptions.

Leading-forall instantiation retains the actual source layers and ordered allocation pairs. The kind scope consumes that evidence and rejects reuse of another owned identity, even when the kinds happen to agree. It does not reconstruct allocation from an offset or from variable occurrences in the instantiated body.

Capture-avoiding substitution transports binder tags and pending kind obligations together. A later substitution cannot turn a previously higher-kinded selection into a proper type. Intermediate application variables retain constraints without being prematurely defaulted to Type. Simultaneous substitution semantics are preserved.

Kind compatibility includes corresponding forall binder slots even when their variables never occur in either body. Arrow syntax and its saturated constructor spelling are canonicalized before comparison. The common kind of two unified types is inferred jointly with retained obligations, so higher-kinded class arguments are not incorrectly required to have kind Type. Forall bodies and dictionary arguments retain their formation checks.

The private expression-checker entrance requires kind ownership for every source query variable, including unused callbacks. It independently checks root and nested forall selections, visible and implicit local instantiation, unifier substitutions, capture-avoiding zonking and guarded shallow subsumption. It imports the source scope, not kind assignments produced by search.

## Validation

The 120-test private suite includes the two forall-opening tests and 18 kind-scope/checker tests. Discriminating tests establish that the kind-erased checker accepts a wrong-kind visible selection of a vacuous binder and an incompatible polymorphic lambda annotation, while the new checker rejects them with kind-specific errors. Matching positive cases pass. A shallow-subsumption test distinguishes nested vacuous binder kinds in an impredicative argument/result pair.

Other checks cover shadowing, independent provider namespaces, allocation collisions, source-inventory mismatch, root rigid selections, implicit local selections, delayed kind solving, malformed binders and capture avoidance. The final ordinary 515-test suite exercises the existing public/default checker and engine behavior.

Run the final gate from a Djex checkout:

~~~text
python test-church/check_exference_kind_scope.py --out dist-newstyle/exference-kind-scope-replay
~~~

The controller builds both test components with --ghc-options=-Werror -j1, runs each suite with one test thread, and records captured source, executable hashes, process transcripts and unchanged-input checks. The final recorded strict build took 70.11 seconds; the private and ordinary test processes took 3.86 and 1.76 seconds respectively. These are observations of this run, not performance guarantees.

The [receipt index](../../test-church/receipts/exference-kind-scope-prerequisite-2026-09-14.json) and [archive](../../test-church/receipts/exference-kind-scope-prerequisite-2026-09-14.zip) are mirrored in both repositories. The archive contains 118 members, is 704,665 bytes, and has SHA-256:

~~~text
1e3acee55985d5a5b1306e7e9b74b7c45684ee395764f6cce6c86c938cffb3a3
~~~

Every member was reopened and verified after packaging. Executables are identified by hashes; their binaries are not embedded. Earlier snapshots remain separate: initial compilation failures, the 114/117-test increments, a failed collision fixture whose assumed allocation did not collide, the corrected 119-test gate, and the first 119-plus-515 release gate. The final authority is attempts/exference-kind-scope-release-v2/results.json.

## Remaining integration

This release does not establish public Exference kinded synthesis. The next implementation must connect the source scope through session alias expansion and checked query preparation, reserve complete environment namespaces in search, preserve kinds during search/provider freshening and substitutions, and retain the appropriate kind evidence with emitted candidates. Global-provider freshening and declaration-owned kinds must also reach the new checker entrance; the tests here establish the scoped local path.

Only then should the public guard be lifted and Exference's own ordinary and named-function where queries run over all 11 existing kinded-source cases, with exact GHC replay and actual rejection controls. No such public result is claimed by the internal checker tests.

Leant retains its separately accepted Djex pin 9a2d59d958a60ff3b6899697a60b6985a5cf73a3. This milestone updates its documentation and evidence archive; it does not update the gitlink or claim a native Lean acceptance run. The Church behavior ledger is unchanged.

The [current execution plan](2026-09-14-synthesis-next-priorities.md) retains Exference kinds, integer indexing and the original simultaneous nominal-universe query as the next delivery commitments.
