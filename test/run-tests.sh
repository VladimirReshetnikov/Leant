#!/usr/bin/env bash
# Golden transcript tests for Leant's interactive commands.
#
#   ./run-tests.sh            run all *.txt, diff against *.golden
#   ./run-tests.sh -u         regenerate the golden files instead
#   ./run-tests.sh basic      run only synth-basic.txt
#
# Each transcript is piped into `leant --plain` on stdin; volatile lines
# (backend discovery, startup timing) are filtered before comparison, so
# the goldens are stable across machines and cache states.  Requires the
# Lean backend that leant already knows how to find (see ../README.md).

set -u
cd "$(dirname "$0")"

# Resolve the built binary through cabal (toolchain-agnostic), falling
# back to a dist-newstyle scan when cabal is unavailable.
EXE=$(cd .. && cabal list-bin exe:leant 2>/dev/null | tr -d '\r')
if [ -z "${EXE:-}" ] || [ ! -x "$EXE" ]; then
  EXE=$(find ../dist-newstyle -name leant.exe -o -name leant -type f 2>/dev/null \
        | head -1)
fi
if [ -z "${EXE:-}" ] || [ ! -x "$EXE" ]; then
  echo "leant binary not found - run: cabal build exe:leant" >&2
  exit 2
fi

update=0
pattern=""
for arg in "$@"; do
  case "$arg" in
    -u) update=1 ;;
    *) pattern="$arg" ;;
  esac
done

# A transcript records what the engines answer, not how fast this machine
# answers it.  The interactive 20-second wall clock would turn a slow box, a
# cold cache, or a loaded CI runner into a "did not finish" line and a failed
# golden, so the suite searches under a deliberately generous budget instead.
# Export a different LEANT_SYNTH_TIMEOUT to override it (0 waits forever).
export LEANT_SYNTH_TIMEOUT="${LEANT_SYNTH_TIMEOUT:-600}"

filter() {
  # Drop the volatile startup lines, and any CR a Windows checkout may
  # still introduce.  Normalize prompt-only continuation lines too: the REPL
  # writes one trailing separator after the prompt, which is presentation
  # whitespace rather than a semantic part of the transcript.
  tr -d '\r' \
    | sed 's/[[:space:]]*$//' \
    | grep -v -e '^no Lake project' -e '^starting Lean backend' \
              -e '^backend responding' -e '^replaying session'
}

failures=0
ran=0
for input in *.txt; do
  case "$input" in
    *"$pattern"*) ;;
    *) continue ;;
  esac
  ran=$((ran + 1))
  golden="${input%.txt}.golden"
  actual=$("$EXE" --plain < "$input" 2>&1 | filter)
  if [ "$update" = 1 ]; then
    printf '%s\n' "$actual" > "$golden"
    echo "updated $golden"
  elif [ ! -f "$golden" ]; then
    echo "MISSING $golden (run with -u to create)"
    failures=$((failures + 1))
  elif ! diff_out=$(printf '%s\n' "$actual" | diff -u "$golden" -); then
    echo "FAIL $input"
    printf '%s\n' "$diff_out"
    failures=$((failures + 1))
  else
    echo "ok   $input"
  fi
done

if [ "$ran" = 0 ]; then
  echo "no transcript matched '$pattern'" >&2
  exit 2
fi
[ "$failures" = 0 ]
