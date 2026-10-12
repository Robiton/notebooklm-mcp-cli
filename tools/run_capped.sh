#!/usr/bin/env bash
# Project:  ai-project-scaffold
# File:     tools/run_capped.sh
# Modified: 2026-08-25
# Version:  0.1.0.20260825.0325
# Purpose:  Run a command under a wall-clock cap. macOS ships no timeout(1), so every
#           project on a macOS runner writes this, and the first attempt is usually
#           subtly broken in a way that only shows up when the cap is finally needed.
# Changelog:
#   2026-08-25 v0.1.0 — Initial, from localcoder#240 filed by an adopter after their own
#                        ad-hoc version failed in production. Two real bugs in that one, both
#                        worth recording because both are invisible until the cap actually
#                        fires:
#                          - `kill -TERM -"$pid"` is the process-GROUP form, and a `( ... ) &`
#                            subshell is not a group leader, so the kill was a no-op and the
#                            wait blocked forever. A harness meant to stop at 240s ran 20m52s.
#                          - a marker-write race between the killer and the waiter.
#                        A THIRD was found writing THIS file's ancestor in localcoder's audit
#                        suite: `exec` replaces the perl process and takes $SIG{ALRM} with it,
#                        so the handler never runs, the child dies on the raw signal, and the
#                        exit code is 142 rather than the 124 the caller is checking for.
#                        fork() and wait, never exec.
#           THE COMMON THREAD: all three passed every prior use, because the thing being
#           capped always finished on its own first. A guard that has never been asked to
#           fire has not been shown to work, which is why --selftest tests BOTH directions.
set -u

usage() {
  cat <<'USAGE'
usage: run_capped.sh <seconds> <command> [args...]
       run_capped.sh --selftest

Runs <command> with a wall-clock cap. Exit codes follow GNU timeout(1):

  124   the cap fired; the command was killed
  127   the command could not be started
  *     whatever the command itself exited with

On the cap, the child gets SIGTERM, then SIGKILL after a short grace period. A
command that ignores TERM is still stopped -- TERM alone is a cap that a
misbehaving child can decline, which is the same "guard that cannot actually
fire" this tool exists to remove.
USAGE
}

# PERL, NOT PURE SHELL, AND NOT exec. Pure shell cannot wait-with-timeout without the
# background-killer pattern that produced the group-kill bug above. perl is present on macOS
# and on every Linux runner this project has met; the alternative, python3, is also a hard
# dependency of this scaffold, but perl starts faster and this wrapper is on the hot path of
# a selftest that may invoke it hundreds of times.
run_capped() {
  _rc_secs="$1"; shift
  perl -e '
    my $t = shift;
    my $pid = fork();
    if (!defined $pid) { exit 127 }
    if (!$pid) { exec @ARGV; exit 127 }        # child: never returns on success
    my $fired = 0;
    $SIG{ALRM} = sub {
        $fired = 1;
        kill "TERM", $pid;
        # GRACE, THEN KILL. A child that ignores TERM would otherwise hold this open
        # forever and the cap would be decorative. Polled rather than slept-then-killed so
        # a well-behaved child that exits on TERM is not delayed by the full grace period.
        for (1 .. 20) {
            select(undef, undef, undef, 0.1);
            my $gone = waitpid($pid, 1);       # WNOHANG
            if ($gone == $pid || $gone == -1) { exit 124 }
        }
        kill "KILL", $pid;
        waitpid($pid, 0);
        exit 124;
    };
    alarm $t;
    waitpid($pid, 0);
    alarm 0;
    exit($? >> 8);
  ' "$_rc_secs" "$@"
}

selftest() {
  pass=0; fail=0
  ok()  { printf '  ok    %s\n' "$1"; pass=$((pass + 1)); }
  bad() { printf '  FAIL  %s\n' "$1"; fail=$((fail + 1)); }
  echo "run_capped: selftest"

  # 1. THE CAP ACTUALLY FIRES. The direction every broken version got wrong.
  run_capped 1 sleep 30 >/dev/null 2>&1; rc=$?
  [ "$rc" = "124" ] && ok "a slow command is capped, exit 124" \
                    || bad "a slow command was NOT capped (exit $rc, wanted 124)"

  # 2. AND A FAST COMMAND IS NOT DELAYED OR MANGLED. A cap wired to always fire would
  #    pass case 1 and break every real use, which is the more expensive failure.
  _t0=$(date +%s)
  run_capped 30 true >/dev/null 2>&1; rc=$?
  _elapsed=$(( $(date +%s) - _t0 ))
  [ "$rc" = "0" ] && ok "a fast command exits 0" \
                  || bad "a fast command did not exit 0 (got $rc)"
  [ "$_elapsed" -lt 5 ] && ok "and returns immediately, not at the cap ($_elapsed s)" \
                        || bad "a fast command waited for the cap ($_elapsed s)"

  # 3. THE CHILD'S OWN EXIT CODE SURVIVES. Reporting 0 for a command that failed is how a
  #    red gate reads as green -- the failure mode this whole project is organised against.
  run_capped 30 sh -c 'exit 7' >/dev/null 2>&1; rc=$?
  [ "$rc" = "7" ] && ok "the command's own exit code passes through" \
                  || bad "exit code was not preserved (got $rc, wanted 7)"

  # 4. A COMMAND THAT IGNORES TERM IS STILL STOPPED. TERM alone is a cap the child can
  #    decline; without the KILL escalation this hangs until the harness gives up.
  _t0=$(date +%s)
  run_capped 1 sh -c 'trap "" TERM; sleep 30' >/dev/null 2>&1; rc=$?
  _elapsed=$(( $(date +%s) - _t0 ))
  [ "$rc" = "124" ] && ok "a TERM-ignoring command is still capped, exit 124" \
                    || bad "a TERM-ignoring command was not capped (exit $rc)"
  [ "$_elapsed" -lt 10 ] && ok "and is killed promptly, not left to run out ($_elapsed s)" \
                         || bad "the KILL escalation did not fire in time ($_elapsed s)"

  # 5. A COMMAND THAT DOES NOT EXIST IS 127, not a hang and not a silent 0.
  run_capped 5 /no/such/binary-run-capped >/dev/null 2>&1; rc=$?
  [ "$rc" = "127" ] && ok "a missing command is 127" \
                    || bad "a missing command did not report 127 (got $rc)"

  echo
  if [ "$fail" -gt 0 ]; then
    echo "run_capped: $fail selftest case(s) FAILED"; exit 1
  fi
  echo "run_capped: $pass selftest case(s) passed"; exit 0
}

case "${1:-}" in
  --selftest) selftest ;;
  -h|--help|"") usage; exit 0 ;;
esac

case "$1" in
  ''|*[!0-9.]*) echo "run_capped.sh: first argument must be seconds, got '$1'" >&2
                usage >&2; exit 2 ;;
esac
[ "$#" -ge 2 ] || { echo "run_capped.sh: no command given" >&2; usage >&2; exit 2; }

command -v perl >/dev/null 2>&1 \
  || { echo "run_capped.sh: perl not found — this wrapper needs it to implement the cap" >&2
       exit 3; }

run_capped "$@"
