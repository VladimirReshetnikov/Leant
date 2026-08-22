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
  local run_key=${4:-"$fixture_name N$capabilities"}
  local cache_home=${5:-"$CACHE_HOME"}
  local fixture="$FIXTURE_DIR/$fixture_name.txt"
  local run_dir="$WORK_DIR/$run_key"
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
    "XDG_CACHE_HOME=$cache_home"
    "LEANT_SYNTH_TIMEOUT=${LEANT_SYNTH_TIMEOUT:-600}"
    "LC_ALL=C"
    "LANG=C"
    "TZ=UTC"
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
  shift 2
  local n1="$WORK_DIR/$fixture_name N1/transcript.normalized"
  local capabilities
  local parallel
  local actual_candidates

  [ "$#" -gt 0 ] || usage_failure \
    "compare_capabilities requires at least one capability to compare"
  for capabilities in "$@"; do
    parallel="$WORK_DIR/$fixture_name N$capabilities/transcript.normalized"
    if ! cmp -s -- "$n1" "$parallel"; then
      diff -u -- "$n1" "$parallel" >&2 || true
      fail "$fixture_name has different normalized -N1 and -N$capabilities transcripts"
    fi
  done

  actual_candidates=$(LC_ALL=C sed -n \
    '/^[[:space:]]*it[0-9][0-9]*[[:space:]][[:space:]]/p' "$n1" |
    wc -l | tr -d '[:space:]')
  [ "$actual_candidates" -eq "$expected_candidates" ] || {
    sed -n '1,240p' "$n1" >&2
    fail "$fixture_name returned $actual_candidates candidates; expected $expected_candidates"
  }
  printf 'ok   %-31s N1 oracle parity through N%s (%s candidates)\n' \
    "$fixture_name" "${!#}" "$actual_candidates"
}

compiled_tooling_module() {
  local cache_home=${1:-"$CACHE_HOME"}
  find "$cache_home/leant/synthesis-tooling-v1/LeantSynthCache" \
    -type f -name 'K*.olean' -print 2>/dev/null | LC_ALL=C sort
}

require_one_compiled_tooling_module() {
  local label=$1
  local cache_home=${2:-"$CACHE_HOME"}
  local modules
  local count
  modules=$(compiled_tooling_module "$cache_home")
  count=$(printf '%s\n' "$modules" | sed '/^$/d' | wc -l | tr -d '[:space:]')
  [ "$count" -eq 1 ] || {
    printf '%s\n' "$modules" >&2
    fail "$label observed $count compiled tooling modules; expected 1"
  }
  printf '%s\n' "$modules"
}

require_trace_occurrences() {
  local label=$1
  local trace_file=$2
  local needle=$3
  local expected=$4
  local actual
  actual=$(LC_ALL=C grep -F -c -- "$needle" "$trace_file" || true)
  [ "$actual" -eq "$expected" ] || {
    sed -n '1,260p' "$trace_file" >&2
    fail "$label trace contains $actual occurrences of $needle; expected $expected"
  }
}

require_trace_present() {
  local label=$1
  local trace_file=$2
  local needle=$3
  if ! LC_ALL=C grep -F -q -- "$needle" "$trace_file"; then
    sed -n '1,260p' "$trace_file" >&2
    fail "$label trace does not contain $needle"
  fi
}

require_trace_absent() {
  local label=$1
  local trace_file=$2
  local needle=$3
  if LC_ALL=C grep -F -q -- "$needle" "$trace_file"; then
    sed -n '1,260p' "$trace_file" >&2
    fail "$label trace unexpectedly contains $needle"
  fi
}

require_artifact_route() {
  local label=$1
  local run_key=$2
  local expectation=$3
  local trace_file="$WORK_DIR/$run_key/backend-exec.trace"

  [ "$TRACE_ROUTES" -eq 1 ] || return 0
  case "$expectation" in
    present)
      require_trace_present "$label" "$trace_file" \
        'leant-parallel-verification'
      ;;
    absent)
      require_trace_absent "$label" "$trace_file" \
        'leant-parallel-verification'
      ;;
    *) usage_failure "invalid artifact-route expectation: $expectation" ;;
  esac
}

require_cache_module_opens() {
  local label=$1
  local run_key=$2
  local module=$3
  local expected=$4

  [ "$TRACE_ROUTES" -eq 1 ] || return 0
  require_trace_occurrences "$label" \
    "$WORK_DIR/$run_key/backend-exec.trace" "\"$module\"" "$expected"
}

require_cache_unchanged() {
  local label=$1
  local module=$2
  local checksum=$3
  local observed
  observed=$(require_one_compiled_tooling_module "$label")
  [ "$observed" = "$module" ] || {
    printf 'expected cache module: %s\nobserved cache module: %s\n' \
      "$module" "$observed" >&2
    fail "$label changed the compiled tooling cache path"
  }
  [ "$(cksum -- "$module")" = "$checksum" ] ||
    fail "$label rewrote the compiled tooling module"
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
require_artifact_route 'serial history-free run' \
  'history-free-multi-group N1' absent
require_cache_module_opens 'serial history-free run' \
  'history-free-multi-group N1' "$CACHE_MODULE" 0
run_one history-free-multi-group 2 3
require_cache_unchanged 'warm history-free N2 run' \
  "$CACHE_MODULE" "$CACHE_CHECKSUM"
require_artifact_route 'warm history-free N2 run' \
  'history-free-multi-group N2' present
require_cache_module_opens 'warm history-free N2 run' \
  'history-free-multi-group N2' "$CACHE_MODULE" 1
compare_capabilities history-free-multi-group 2 2

COLD_N2_CACHE_HOME="$WORK_DIR/cold N2 compiled tooling cache with spaces"
mkdir -p -- "$COLD_N2_CACHE_HOME"
run_one history-free-multi-group 2 3 \
  'history-free-multi-group cold N2' "$COLD_N2_CACHE_HOME"
COLD_N2_MODULE=$(require_one_compiled_tooling_module \
  'cold history-free N2 run' "$COLD_N2_CACHE_HOME")
if ! cmp -s -- \
    "$WORK_DIR/history-free-multi-group N1/transcript.normalized" \
    "$WORK_DIR/history-free-multi-group cold N2/transcript.normalized"; then
  diff -u -- \
    "$WORK_DIR/history-free-multi-group N1/transcript.normalized" \
    "$WORK_DIR/history-free-multi-group cold N2/transcript.normalized" >&2 || true
  fail 'cold history-free N2 transcript differs from the N1 oracle'
fi
if [ "$TRACE_ROUTES" -eq 1 ]; then
  COLD_N2_TRACE="$WORK_DIR/history-free-multi-group cold N2/backend-exec.trace"
  require_trace_present 'cold history-free N2 run' "$COLD_N2_TRACE" \
    'leant-parallel-verification'
  require_trace_occurrences 'cold history-free N2 run' "$COLD_N2_TRACE" \
    "\"$COLD_N2_MODULE\"" 0
fi
printf 'ok   %-31s parity (cold N2)\n' history-free-multi-group

run_one history-free-five-result 1 1
require_cache_unchanged 'warm five-result N1 run' \
  "$CACHE_MODULE" "$CACHE_CHECKSUM"
require_artifact_route 'warm five-result N1 run' \
  'history-free-five-result N1' absent
require_cache_module_opens 'warm five-result N1 run' \
  'history-free-five-result N1' "$CACHE_MODULE" 1
for CAPABILITIES in 2 3 4; do
  case "$CAPABILITIES" in
    2) EXPECTED_PROCESSES=3 ;;
    3) EXPECTED_PROCESSES=4 ;;
    4) EXPECTED_PROCESSES=5 ;;
  esac
  run_one history-free-five-result "$CAPABILITIES" "$EXPECTED_PROCESSES"
  require_cache_unchanged "warm five-result N$CAPABILITIES run" \
    "$CACHE_MODULE" "$CACHE_CHECKSUM"
  require_artifact_route "warm five-result N$CAPABILITIES run" \
    "history-free-five-result N$CAPABILITIES" present
  require_cache_module_opens "warm five-result N$CAPABILITIES run" \
    "history-free-five-result N$CAPABILITIES" "$CACHE_MODULE" 1
done
compare_capabilities history-free-five-result 5 2 3 4

run_one history-free-multi-group 4 3
require_cache_unchanged 'warm short history-free N4 run' \
  "$CACHE_MODULE" "$CACHE_CHECKSUM"
require_artifact_route 'warm short history-free N4 run' \
  'history-free-multi-group N4' present
require_cache_module_opens 'warm short history-free N4 run' \
  'history-free-multi-group N4' "$CACHE_MODULE" 1
compare_capabilities history-free-multi-group 2 2 4

run_one pristine-hidden-type 1 1
require_cache_unchanged 'warm pristine hidden-type N1 run' \
  "$CACHE_MODULE" "$CACHE_CHECKSUM"
require_artifact_route 'warm pristine hidden-type N1 run' \
  'pristine-hidden-type N1' absent
require_cache_module_opens 'warm pristine hidden-type N1 run' \
  'pristine-hidden-type N1' "$CACHE_MODULE" 1
run_one pristine-hidden-type 2 3
require_cache_unchanged 'warm pristine hidden-type N2 run' \
  "$CACHE_MODULE" "$CACHE_CHECKSUM"
require_artifact_route 'warm pristine hidden-type N2 run' \
  'pristine-hidden-type N2' present
require_cache_module_opens 'warm pristine hidden-type N2 run' \
  'pristine-hidden-type N2' "$CACHE_MODULE" 1
run_one pristine-hidden-type 4 3
require_cache_unchanged 'warm pristine hidden-type N4 run' \
  "$CACHE_MODULE" "$CACHE_CHECKSUM"
require_artifact_route 'warm pristine hidden-type N4 run' \
  'pristine-hidden-type N4' present
require_cache_module_opens 'warm pristine hidden-type N4 run' \
  'pristine-hidden-type N4' "$CACHE_MODULE" 1
compare_capabilities pristine-hidden-type 0 2 4

run_one scoped-notation-history 1 1
require_cache_unchanged 'warm scoped-history N1 run' \
  "$CACHE_MODULE" "$CACHE_CHECKSUM"
require_artifact_route 'warm scoped-history N1 run' \
  'scoped-notation-history N1' absent
require_cache_module_opens 'warm scoped-history N1 run' \
  'scoped-notation-history N1' "$CACHE_MODULE" 1
run_one scoped-notation-history 2 1
require_cache_unchanged 'warm scoped-history N2 run' \
  "$CACHE_MODULE" "$CACHE_CHECKSUM"
require_artifact_route 'warm scoped-history N2 run' \
  'scoped-notation-history N2' absent
require_cache_module_opens 'warm scoped-history N2 run' \
  'scoped-notation-history N2' "$CACHE_MODULE" 1
run_one scoped-notation-history 4 1
require_cache_unchanged 'warm scoped-history N4 run' \
  "$CACHE_MODULE" "$CACHE_CHECKSUM"
require_artifact_route 'warm scoped-history N4 run' \
  'scoped-notation-history N4' absent
require_cache_module_opens 'warm scoped-history N4 run' \
  'scoped-notation-history N4' "$CACHE_MODULE" 1
compare_capabilities scoped-notation-history 5 2 4

printf 'PASS parallel-verification real-Lean parity and route gate\n'
