#!/usr/bin/env bash
# Real-Lean parity and route gate for the parallel candidate verifier.

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
ROOT_DIR=$(cd -- "$SCRIPT_DIR/.." && pwd -P)
FIXTURE_DIR="$SCRIPT_DIR/parallel-verification"

fail() {
  printf 'FAIL parallel-verification gate: %s\n' "$*" >&2
  exit 1
}

usage_failure() {
  printf 'parallel-verification gate: %s\n' "$*" >&2
  exit 2
}

absolute_existing_executable() {
  local requested=$1
  local directory
  local base

  case "$requested" in
    /*) ;;
    *) requested="$PWD/$requested" ;;
  esac
  directory=$(dirname -- "$requested")
  base=$(basename -- "$requested")
  directory=$(cd -- "$directory" 2>/dev/null && pwd -P) || return 1
  requested="$directory/$base"
  [ -f "$requested" ] && [ -x "$requested" ] || return 1
  printf '%s\n' "$requested"
}

resolve_leant_executable() {
  local candidate=""

  if [ -n "${LEANT_EXE:-}" ]; then
    absolute_existing_executable "$LEANT_EXE" ||
      usage_failure "LEANT_EXE is not an executable file: $LEANT_EXE"
    return
  fi

  if command -v cabal >/dev/null 2>&1; then
    candidate=$(cd -- "$ROOT_DIR" && cabal list-bin exe:leant 2>/dev/null |
      tr -d '\r' | sed -n '1p')
  fi
  if [ -n "$candidate" ] && [ -x "$candidate" ]; then
    absolute_existing_executable "$candidate"
    return
  fi

  candidate=$(find "$ROOT_DIR/dist-newstyle" -type f \
    \( -path '*/x/leant/build/leant/leant' \
       -o -path '*/x/leant/build/leant/leant.exe' \) \
    -perm -u+x -print 2>/dev/null | LC_ALL=C sort | sed -n '1p')
  if [ -n "$candidate" ] && [ -x "$candidate" ]; then
    absolute_existing_executable "$candidate"
    return
  fi

  usage_failure 'Leant executable not found; build exe:leant or set LEANT_EXE'
}

case "${LEANT_GATE_TIMEOUT_SECONDS:-900}" in
  ''|*[!0-9]*|0) usage_failure 'LEANT_GATE_TIMEOUT_SECONDS must be a positive integer' ;;
esac
case "${LEANT_SYNTH_TIMEOUT:-600}" in
  ''|*[!0-9]*) usage_failure 'LEANT_SYNTH_TIMEOUT must be a nonnegative integer' ;;
esac
case "${LEANT_ROUTE_TRACE:-auto}" in
  auto|require|skip) ;;
  *) usage_failure 'LEANT_ROUTE_TRACE must be auto, require, or skip' ;;
esac

EXE=$(resolve_leant_executable)

BACKEND=""
if [ -n "${LEANT_BACKEND:-}" ]; then
  BACKEND=$(absolute_existing_executable "$LEANT_BACKEND") ||
    usage_failure "LEANT_BACKEND is not an executable file: $LEANT_BACKEND"
fi

TIMEOUT_EXE=""
if command -v timeout >/dev/null 2>&1; then
  TIMEOUT_EXE=$(command -v timeout)
elif command -v gtimeout >/dev/null 2>&1; then
  TIMEOUT_EXE=$(command -v gtimeout)
else
  usage_failure 'GNU timeout (or gtimeout) is required'
fi

TRACE_ROUTES=0
case "${LEANT_ROUTE_TRACE:-auto}" in
  require) TRACE_ROUTES=1 ;;
  skip) TRACE_ROUTES=0 ;;
  auto)
    if [ "$(uname -s)" = Linux ]; then
      TRACE_ROUTES=1
    fi
    ;;
esac
if [ "$TRACE_ROUTES" -eq 1 ]; then
  command -v strace >/dev/null 2>&1 ||
    usage_failure 'route tracing is required but strace is unavailable (set LEANT_ROUTE_TRACE=skip to opt out explicitly)'
  [ -n "$BACKEND" ] ||
    usage_failure 'route tracing requires LEANT_BACKEND so exact backend execve calls can be identified'
fi

TEMPORARY_PARENT=${TMPDIR:-/tmp}
[ -d "$TEMPORARY_PARENT" ] ||
  usage_failure "temporary directory does not exist: $TEMPORARY_PARENT"
WORK_DIR=$(mktemp -d -- "$TEMPORARY_PARENT/leant parallel verification gate.XXXXXXXX") ||
  usage_failure 'could not create gate work directory'
CACHE_HOME="$WORK_DIR/compiled tooling cache with spaces"
mkdir -p -- "$CACHE_HOME"
cleanup() {
  chmod -R u+rwX -- "$WORK_DIR" 2>/dev/null || true
  rm -rf -- "$WORK_DIR"
}
trap cleanup EXIT HUP INT TERM

normalize_transcript() {
  tr -d '\r' < "$1" |
    sed -e 's/[[:space:]]*$//' \
        -e '/^no Lake project/d' \
        -e '/^starting Lean backend/d' \
        -e '/^backend responding/d' \
        -e '/^replaying session/d' > "$2"
}

backend_exec_count() {
  local trace_file=$1
  LC_ALL=C awk -v needle="execve(\"$BACKEND\"" \
    'index($0, needle) { count += 1 } END { print count + 0 }' "$trace_file"
}

run_one() {
  local fixture_name=$1
  local capabilities=$2
  local expected_processes=$3
  local fixture="$FIXTURE_DIR/$fixture_name.txt"
  local run_dir="$WORK_DIR/$fixture_name N$capabilities"
  local command_tmp="$run_dir/temporary artifacts with spaces"
  local raw="$run_dir/transcript.raw"
  local normalized="$run_dir/transcript.normalized"
  local trace="$run_dir/backend-exec.trace"
  local status

  [ -f "$fixture" ] || usage_failure "fixture is missing: $fixture"
  mkdir -p -- "$command_tmp"

  local -a environment=(
    env -u GHCRTS -u LEANT_SYNTH_DEBUG
    "TMPDIR=$command_tmp"
    "XDG_CACHE_HOME=$CACHE_HOME"
    "LEANT_SYNTH_TIMEOUT=${LEANT_SYNTH_TIMEOUT:-600}"
  )
  if [ -n "$BACKEND" ]; then
    environment+=("LEANT_BACKEND=$BACKEND")
  fi

  if [ "$TRACE_ROUTES" -eq 1 ]; then
    if "$TIMEOUT_EXE" --foreground --signal=TERM --kill-after=30s \
        "${LEANT_GATE_TIMEOUT_SECONDS:-900}s" \
        strace -f -qq -e trace=execve,openat -s 4096 -o "$trace" -- \
        "${environment[@]}" "$EXE" --plain \
          +RTS "-N$capabilities" -RTS < "$fixture" > "$raw" 2>&1; then
      status=0
    else
      status=$?
    fi
  else
    if "$TIMEOUT_EXE" --foreground --signal=TERM --kill-after=30s \
        "${LEANT_GATE_TIMEOUT_SECONDS:-900}s" \
        "${environment[@]}" "$EXE" --plain \
          +RTS "-N$capabilities" -RTS < "$fixture" > "$raw" 2>&1; then
      status=0
    else
      status=$?
    fi
  fi

  if [ "$status" -ne 0 ]; then
    printf '%s\n' "--- $fixture_name N$capabilities output ---" >&2
    sed -n '1,240p' "$raw" >&2
    fail "$fixture_name at -N$capabilities exited with status $status"
  fi

  normalize_transcript "$raw" "$normalized"

  if find "$command_tmp" -name 'leant-parallel-verification*' -print -quit |
      grep -q .; then
    find "$command_tmp" -name 'leant-parallel-verification*' -print >&2
    fail "$fixture_name at -N$capabilities leaked its verification artifact"
  fi

  if [ "$TRACE_ROUTES" -eq 1 ]; then
    local actual_processes
    local process_label=process
    actual_processes=$(backend_exec_count "$trace")
    [ "$actual_processes" -eq "$expected_processes" ] || {
      sed -n '1,240p' "$trace" >&2
      fail "$fixture_name at -N$capabilities launched $actual_processes backend processes; expected $expected_processes"
    }
    if [ "$actual_processes" -ne 1 ]; then
      process_label=processes
    fi
    printf 'ok   %-31s -N%s (%s backend %s)\n' \
      "$fixture_name" "$capabilities" "$actual_processes" "$process_label"
  else
    printf 'ok   %-31s -N%s (route evidence skipped)\n' \
      "$fixture_name" "$capabilities"
  fi
}

compare_capabilities() {
  local fixture_name=$1
  local expected_candidates=$2
  local n1="$WORK_DIR/$fixture_name N1/transcript.normalized"
  local n2="$WORK_DIR/$fixture_name N2/transcript.normalized"
  local actual_candidates

  if ! cmp -s -- "$n1" "$n2"; then
    diff -u -- "$n1" "$n2" >&2 || true
    fail "$fixture_name has different normalized -N1 and -N2 transcripts"
  fi

  actual_candidates=$(LC_ALL=C sed -n \
    '/^[[:space:]]*it[0-9][0-9]*[[:space:]][[:space:]]/p' "$n1" |
    wc -l | tr -d '[:space:]')
  [ "$actual_candidates" -eq "$expected_candidates" ] || {
    sed -n '1,240p' "$n1" >&2
    fail "$fixture_name returned $actual_candidates candidates; expected $expected_candidates"
  }
  printf 'ok   %-31s parity (%s candidates)\n' \
    "$fixture_name" "$actual_candidates"
}

compiled_tooling_module() {
  find "$CACHE_HOME/leant/synthesis-tooling-v1/LeantSynthCache" \
    -type f -name 'K*.olean' -print 2>/dev/null | LC_ALL=C sort
}

require_one_compiled_tooling_module() {
  local label=$1
  local modules
  local count
  modules=$(compiled_tooling_module)
  count=$(printf '%s\n' "$modules" | sed '/^$/d' | wc -l | tr -d '[:space:]')
  [ "$count" -eq 1 ] || {
    printf '%s\n' "$modules" >&2
    fail "$label observed $count compiled tooling modules; expected 1"
  }
  printf '%s\n' "$modules"
}

printf 'Leant:   %s\n' "$EXE"
if [ -n "$BACKEND" ]; then
  printf 'Backend: %s\n' "$BACKEND"
else
  printf 'Backend: application discovery\n'
fi
if [ "$TRACE_ROUTES" -eq 0 ]; then
  printf 'SKIP route evidence (LEANT_ROUTE_TRACE=%s)\n' \
    "${LEANT_ROUTE_TRACE:-auto}"
fi

run_one history-free-multi-group 1 1
CACHE_MODULE=$(require_one_compiled_tooling_module 'cold history-free run')
CACHE_CHECKSUM=$(cksum -- "$CACHE_MODULE")
run_one history-free-multi-group 2 3
[ "$(cksum -- "$CACHE_MODULE")" = "$CACHE_CHECKSUM" ] ||
  fail 'warm history-free run rewrote the compiled tooling module'
if [ "$TRACE_ROUTES" -eq 1 ]; then
  grep -F -- "$CACHE_MODULE" \
      "$WORK_DIR/history-free-multi-group N2/backend-exec.trace" >/dev/null ||
    fail 'warm history-free run did not open the compiled tooling module'
fi
compare_capabilities history-free-multi-group 2

run_one scoped-notation-history 1 1
run_one scoped-notation-history 2 1
compare_capabilities scoped-notation-history 5

printf 'PASS parallel-verification real-Lean parity and route gate\n'
