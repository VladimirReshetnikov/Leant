# Inline Length where-clause runtime activation

Date: 2026-08-20

## Outcome

Leant now consumes the previously passive inline Length command surface in
production. One `:synth` command can select a fixed exact-case list model,
declare the physical source-arrow inputs whose spines are observable, and give
one bounded ASCII postcondition without a JSON contract file:

```text
:synth --behavior-mode filter --length-model list-scalar-exact-cases|list-binary-product-exact-cases --length-inputs arg0[,argN...] --where CLAUSE -- TYPE
```

The bar displays two alternative literal model tokens; it is not part of one
accepted command. The clause is unquoted and ends at the standalone `--`.
Quote characters are clause input and the bounded parser rejects them. The
form requires literal `--behavior-mode filter`, cannot be combined with
`--length-contract`, and reuses the already activated startup execution
policy. It supplies no process-launch, pin, solver, replay, or rejection
authority by itself.

The production activation landed as
`e078ca9168b71f8d8dab5cbe87d115384be855d5` (`Activate inline Length
constraints in synth`). Its runtime characterization landed as
`0425ad9be5bcb8f8e3612b711e2fff94ad1c13be` (`Characterize inline Length
runtime activation`). The initial reconciliation baseline inspected for this
report is Leant `260d36d1dc2578ce7e470171c8591137569e455f`, with the Djex submodule at
`39c95a9b20e15f4e96c2b1447853943c98220c98`. The reconciled Stage 1 source
documentation landed at
`9f0da7f7f7d6601521c19288edef1c6a02b80c4f`. A subsequent source-only layout
repair at `0ef02f855dbfed30752f2e5a1be745d8a43504d1` gives the two long Overview
setting names explicit two-line command cells; that repair is the final Leant
source snapshot used by the artifacts below.

## Fixed syntax and semantic profile

`Leant.Synth.Length.Command` recognizes the inline form before delegating
non-inline input to the established command parser. Structural validation owns
option order, repetition, required literal filter mode, and the mutual
exclusion of file and inline contract sources. The model token is exactly
`list-scalar-exact-cases` or `list-binary-product-exact-cases`.

`--length-inputs` is one nonempty comma-separated token containing strictly
increasing numeric `argN` indices from `arg0` through `arg7`. Leading zeroes
are accepted as numeric aliases, so alias duplicates and descending aliases
are rejected after decoding. Gaps are valid, and a listed input need not occur
in the clause. Every clause `len(argN)` reference must be listed and lie within
the translated physical arity. These are physical source-arrow positions.
After Lean translation, Main counts only `SlotArrow` entries in the fragment
spine; universal, instance, and contextual slots do not enter that number.
Listed arrows become observed roles compacted in source order and omitted
arrows become unobserved roles.

The Djex parser admits one ASCII relation over natural literals,
`len(argN)`, scalar `len(result)`, product `len(result.first)` and
`len(result.second)`, linear arithmetic, direct-positive-literal division and
remainder, `min`/`max`, parentheses, and the six ordinary comparison operators.
It retains no source bytes. Admission is bounded at 16,384 UTF-8 bytes and 64
parser-nesting levels across parentheses, `len`, `min`, and `max`, in addition
to the existing Length syntax, formula, collection, literal, and input limits.
Parse and elaboration errors are closed and sanitized; diagnostics never echo
the clause.

Resolution expands exactly one of two profiles:

- fixed `List`, `List.nil`, and `List.cons` identities;
- scalar result or canonical binary `Prod` result, selected only by the model
  token;
- the complete explicit observed/unobserved target-role vector;
- the exact zero/step candidate-case policy;
- a true precondition and the parsed relation as postcondition; and
- an empty provider-law set.

No model, spine identity, result domain, role, case policy, provider law, or
execution permission is inferred from the clause or the translated Lean
target. Consequently a provider-dependent candidate that cannot be prepared
under the empty provider-law set is retained with its ordinary preparation
refusal. It is not a behavioral rejection.

## Authority and lifetime order

Main owns the complete order for the new entrance:

1. parse and structurally validate the inline command;
2. resolve the explicit goal or current prove/`sorry` goal source;
3. authorize literal filter mode against the activated startup policy;
4. parse the bounded clause;
5. emit the established inaccessible-hypothesis and premise-scope report;
6. translate the Lean target, including the existing universe retry;
7. count only physical `SlotArrow` entries and resolve the clause/profile;
8. construct exactly one authorized scalar or product assessment context; and
9. pass that context through every ordinary, provider, excluded-middle, and
   double-negation lane.

The filter authorization precedes clause parsing, so disabled assessment
refuses the request before parsing or IO. Translation and target association
precede context creation, so either failure creates no counterexample bank.
Once created, the one nominal context retains the existing progressive-batch
and cross-lane lifetime, and no request, clause, parsed source, role vector,
bank, result, or context enters `ReplState`, history, snapshots, or later
commands.

The established startup and contract-file entrances intentionally keep their
older order: `synthRun` opens their one assessment context before translation
and retains it through universe narrowing and all lanes. Activating the inline
entrance did not silently change that lifetime.

## Characterization

The active focused group retains the twenty pure structural/parser/profile
checks and adds the runtime-architecture boundary as its twenty-first case. It
pins inline-first dispatch, goal selection before authorization, literal
`LengthBehaviorFilter` permission, post-authorization bounded parsing,
translation/retry before resolution, `SlotArrow`-only arity, one post-resolution
context, reuse of `explicitLengthAssessmentRequest`, and absence of the inline
surface from lower Integration, Configuration, and Handoff layers.

Provider-free runtime fixtures cover both result domains:

- the scalar fixture distinguishes identity length from positive-spine
  increment under
  `len(result)=len(arg0)+min(len(arg0),1)`; and
- the product fixture distinguishes `(input,input)` from `(input,0)` under
  `len(result.first)+len(result.second)=2*len(arg0)`.

The tests activate a real request-scoped filter policy, compare startup,
inline, and later startup requests, and establish that neither contract choice
nor bank state sticks across commands.

## Verification evidence

At the reconciled baseline, the following strict gates passed:

- active inline Length group: 21/21;
- Integration group: 24/24;
- full Leant unit suite: 475/475;
- strict `cabal build all -j1 --ghc-options=-Werror`; and
- all 26 pinned-backend golden transcripts, byte-exact after the runner's
  comparison-only queue-telemetry normalization.

The inline change required no checked-in golden fixture update. The later
telemetry normalization does not regenerate or alter checked-in expected
transcript bytes: only the numeric queue total is normalized symmetrically,
while any label, reason, semantic-line, or removal drift still fails. Cabal
package checks and whitespace/diff checks also passed at the reconciliation
boundary.

## Artifact evidence

Stage 1 updated source documentation only. The separate artifact checkpoint
changes exactly the walkthrough source, this report, and the five maintained
PDFs. The walkthrough source is 3,543 lines with SHA-256
`4abbea948e49b47268921f456b9668538e1d0f3b1feb0ba6f0aa790581a8c743`.
Its three Djex pins are exactly
`39c95a9b20e15f4e96c2b1447853943c98220c98`, and its three Leant pins are
exactly the layout-repair snapshot
`0ef02f855dbfed30752f2e5a1be745d8a43504d1`; the full and abbreviated labels,
tree links, blob links, and the Leant submodule revision agree.

The installed artifacts are:

| PDF | Pages | Bytes | SHA-256 |
| --- | ---: | ---: | --- |
| `docs/Leant_Overview/Leant_Overview.pdf` | 33 | 199,559 | `13ebbcd56d88e150e11c5df36e54ce2dae4468134efad75f7b4389ed4d499efe` |
| `docs/Djex_Leant_Codebase_Walkthrough/Djex_Leant_Codebase_Walkthrough.pdf` | 126 | 828,927 | `d6c023622c70ea05ce7b7428eac41368bac6901cda539beb17e49be26d102d19` |
| `docs/Z3_Behavioral_Synthesis_Proposal/Z3_Behavioral_Synthesis_Proposal.pdf` | 122 | 628,586 | `93666130a345157707f145f520f61bab061bd80e171a87ca7578810345daafea` |
| `docs/Z3_for_Leant_and_Djex/Z3_for_Leant_and_Djex.pdf` | 182 | 902,430 | `ee779d40e60b71ad08d7bf98fc0e5bfb6b83b58f10a556e97239ee0022c08b12` |
| `docs/Lean_from_First_Principles/Lean_from_First_Principles.pdf` | 145 | 625,509 | `32b2be250b75b81ad6c08fff4c80ff68ec4a402e4fc3488e51533ac90590207b` |

Each document was built for three fail-fast passes in a separate initially
empty directory. LuaHBTeX 1.14.0 built the Overview and Lean guide; pdfTeX
1.40.22 built the walkthrough, proposal, and Z3 guide. Proposal and Z3-guide
fonts came from a temporary task-local `newtx` TEXMF tree, without changing
the repository or system TeX installation. Passes two and three have
byte-identical standard output for every document. The final logs contain no
fatal error, undefined reference or citation, rerun request, missing glyph, or
literal LaTeX warning. Box diagnostics are: Overview 0 overfull/10 underfull;
walkthrough its three established overfulls (47.37619 pt, 56.46841 pt, and
36.05583 pt)/4 underfull; proposal 0/18; Z3 guide 0/16; and Lean guide its 17
baseline overfulls/11 underfull. The Lean guide also retains exactly its three
baseline package warnings. The Overview page-6 command-cell collision found
during full-size review is absent after the source repair.

All five files are unencrypted letter-size PDF 1.5 documents. Every page has
nonempty UTF-8 extracted text and no replacement character. The ordered text
hashes and byte counts are, respectively, Overview
`c3fa09083b291ff950eabd391f13e7c3f0fceeacc6c717494b07d09c7c4db829`
/89,311; walkthrough
`ddc02c67637818512b4ce43851c2bdd07692ed267caba75c01914a5e04cb5230`
/335,260; proposal
`f7786eadb9ee5e9a35ace567fce1e96552fa20f610833dfcadd1f7d7d36215cb`
/248,139; Z3 guide
`696f6de6e7125d4365ca4b0d7c1a425ef03f0293e78afa1bd6ee1bc0d956d6dc`
/412,080; and Lean guide
`5d29f1387353b2507a504baa3df8c267bce3c395de7f3cdade0504b175e6b59e`
/300,756. Their 8, 18, 18, 18, and 12 fonts are all embedded, subsetted, and
Unicode-mapped. They contain no raster images, attachments, forms,
JavaScript, signatures, launch actions, rich media, XFA, encryption, or
duplicate named destinations; destination counts are 55, 699, 1,257, 1,825,
and 467.

The final walkthrough has 241 URL annotations: 184 point to the pinned Djex
revision, 52 to the pinned Leant revision, and five to external Linux/kernel
references. Its 64 unique Djex blob targets and 18 unique Leant blob targets,
plus both tree roots, exist at the pinned commits. All five external targets
returned HTTP 200 during this audit.

The 144-DPI RGB raster comparison against the checked-in parent artifacts
changed Overview pages 1--33; walkthrough pages 1 and 3--126; 80 proposal
pages; 170 Z3-guide pages; and Lean-guide pages 2--145. The ordered current
raster-set hashes are
`0b5bd46b2ead1c8f1586587aa77cfe017a42c8f717b0bf8b921af691c92c3cce`,
`b32ab9a544a50c3141db062eca2cefc85a4a98e3c39ceee52fdfbdde1df0d395`,
`ac3ca871f4086a228407391a906d2e54088a32da3af39d3122b6fbec578924c4`,
`1fa589d9573a1734acb0552534822bb883d469008848886ae9706411b3cff20f`,
and `a5fe63790dcb6a11a00d82fd4c21047bd2a962f054b510ae7c32beb94e007360`.
Every changed or new page was inspected in labeled contact sheets, with title,
inline-syntax, current-tree, pin appendix, repaired command table, landscape,
and concluding pages also checked at full size. No clipping, collision,
malformed wrap, overlap, or orphan artifact remains.
