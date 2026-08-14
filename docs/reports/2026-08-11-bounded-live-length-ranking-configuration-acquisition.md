# Bounded live Length ranking configuration acquisition

Date: 2026-08-11

## Outcome

`Leant.Synth.Length.Configuration.File.Acquire` adds the filesystem boundary
around the pure versioned Length-ranking configuration decoder. It admits the
literal version-1 compatibility grammar and the additive version-2 bounded-box
grammar plus version 3's bounded-box-and-origin grammar under the same byte,
path, descriptor, and timeout policy. The module
does not discover a file, activate a decoded policy, or start Z3. A successful
load returns only the existing opaque `DisabledLengthRankingConfiguration`;
Main's later integration composes this explicit boundary with activation.

The caller must first supply both an exact path and an acquisition timeout to
`mkLengthRankingConfigurationFileRequest`.  The resulting request is opaque.
There is no default path, current-project convention, environment variable,
home-directory lookup, executable-relative lookup, or watcher.

## Pure request admission

Admission has one fixed order and performs no IO:

1. scan the path only through character 4,097 and reject a maximum-plus-one
   observation beyond the 4,096-character ceiling;
2. reject an empty path;
3. reject an embedded NUL;
4. require the exact host spelling to be absolute, without normalizing or
   canonicalizing it;
5. require a positive timeout in milliseconds; and
6. reject a timeout above 60,000 milliseconds with a capped 60,001
   observation.

The raw source fields remain lazy so an over-limit or cyclic path is rejected
without forcing a later timeout field.  The opaque admitted request has no
`Eq`, `Ord`, `Show`, or `Generic` instance and no path or timeout projection.

## POSIX descriptor policy

On POSIX the admitted path is opened exactly once, read-only, with these flags
set atomically on the open operation:

- `O_NOFOLLOW` for the final path component;
- `O_NONBLOCK`, so a final-component FIFO does not wait for a writer;
- `O_NOCTTY`, so opening a terminal-like special file cannot acquire a
  controlling terminal; and
- `O_CLOEXEC`, so a concurrently launched child cannot inherit the descriptor.

The loader then obtains status from that descriptor with `fstat`.  It rejects
anything other than a regular file before issuing a read.  A regular file
whose reported size is already above the byte ceiling is rejected without
reading; this is only an early conservative check.  A file can grow or report
an unhelpful size, so the streaming byte counter remains authoritative.

There is no pre-open existence test, pathname `stat`, canonicalization,
`Handle` conversion, reopen, lazy IO, or pathname-based read.  A rename or
replacement after open therefore cannot redirect the descriptor.  The policy
does not claim more than it implements: `O_NOFOLLOW` covers only the final
component, hard links remain possible, ancestor symlinks may be traversed, and
opening an unusual device can have implementation-specific effects before
`fstat` rejects it.  A same-UID writer can also mutate the already-open regular
file in place while it is being read.

## Exact byte admission and decoding

The loader derives its 262,144-byte maximum from the pure decoder's versioned
JSON limit rather than duplicating it.  It reads strict `ByteString` chunks,
retaining at most the maximum and probing through exactly byte 262,145:

- EOF at or below 262,144 bytes finishes acquisition;
- byte 262,145 yields a capped `262144/262145` size failure; and
- no following byte is requested or retained.

The installed `unix` package reports normal `fdRead` EOF as an `IOException`.
The loop treats only `isEOFError` as successful EOF; every other read error is
a sanitized read failure.  Chunks are accumulated in reverse and concatenated
once, avoiding lazy IO and quadratic append behavior.

The complete retained bytes are decoded inside the timeout-owned descriptor
scope.  Decoder failures preserve the existing sanitized
`LengthRankingConfigurationFileError` and its established JSON/schema
precedence.  The descriptor is not exposed, and successful decoding still
does not grant activation authority.

## Timeout, exceptions, and cleanup

One same-process timeout covers open, descriptor inspection, bounded reads,
strict decoding, and normal descriptor release.  Ownership is installed under
masking before the interruptible body runs.  A timeout or unrelated caller
asynchronous exception triggers a descriptor-close attempt; unrelated async
exceptions are then rethrown unchanged rather than converted into a loader
error.

The returned sanitized error records a primary closed failure class and one
`cleanupIncomplete` bit.  A synchronous primary read, type, size, or decode
failure remains primary if close also fails.  A close failure after an
otherwise successful load becomes the primary cleanup failure.  Timeout
remains primary and reports whether the close attempt was observed to fail or
be interrupted.

This is an interruption budget, not a hard kernel deadline.  An
uninterruptible network filesystem, FUSE implementation, device open, or
descriptor close can outlive the requested interval.  Cleanup latency can
therefore outlive the operation that initiated it.  A strict wall-clock bound
against arbitrary filesystems would require a separately killable helper
process and is outside this checkpoint.

## Sanitized failures and platform boundary

Admission errors retain only closed reasons and capped counts.  Load errors
retain only one of these closed classes plus the cleanup bit:

- unsupported platform;
- open failure;
- descriptor-inspection failure;
- non-regular descriptor;
- read failure;
- capped byte-limit failure;
- the already sanitized pure-decoder failure;
- deadline exceeded; or
- descriptor cleanup failure.

No path, symlink target, errno message, OS exception text, file byte, unknown
JSON key or tag, digest, Lean name, or source snippet crosses the error
boundary.

Windows fails closed before filesystem access.  There is no fallback through
portable `readFile`, `doesFileExist`, or a symlink-following `Handle`.  A
future Windows implementation must use a native handle opened with equivalent
no-reparse/type/ownership semantics before this format can be loaded there.

## Authority and integration status

Acquisition proves only that a bounded byte sequence was read from one
descriptor which reported a regular-file type and decoded into an internally
valid disabled policy.  It does not prove who wrote the file, that its content
was stable during the read, that its Z3 path exists, that a digest pins the
image ultimately executed, that the declared behavioral contract is true, or
that any later solver answer is sound.

Activation remains a separate explicit pinned-only or permit-unpinned choice.
Each eventual ranking invocation must still open a fresh Djex rank-N session,
perform capability checks, associate each query exactly, and replay any model
against the checked candidate problem. Version 1 keeps `unsat` neutral. Version
2 may use it only to schedule independent exact-query input-box traversal;
version 3 first performs its query-owned origin probe after the MRU bank and
uses its retained version-2 box only after an actual live `unsat`. `unknown`, status-only
`sat`, and an origin miss remain neutral, and no status grants proof authority.
The worker has already opened and passed capability checks before the
per-candidate origin step, so a hit does not avoid process launch and cannot
bypass an earlier session-open or capability failure. Lean verification
remains the final acceptance boundary. The bounded extension is detailed in the
[unsat-triggered validation report](2026-08-14-unsat-triggered-length-input-box-validation.md).
The origin extension is detailed in the
[origin-probe orchestration report](2026-08-14-length-origin-probe-orchestration.md).

Main now loads exactly one caller-named absolute file at startup when the
explicit option is present. It neither discovers nor watches the file, and it
does not retain file bytes or reopen it for later requests. Requiring a digest
expectation is the default activation choice; permitting an unpinned executable
requires a separate flag. Setup failure stops startup with a sanitized error,
while later structured ranking failure preserves callback order.
