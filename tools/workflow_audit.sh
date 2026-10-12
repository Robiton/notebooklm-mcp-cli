#!/usr/bin/env bash
# Project:  ai-project-scaffold
# File:     tools/workflow_audit.sh
# Modified: 2026-10-10
# Version:  0.3.0.20261010.1324
# Purpose:  zizmor and actionlint over .github/workflows, each at a pinned version.
# Changelog:
#   2026-10-10 v0.3.0.20261010.1324 — actionlint 1.7.7 is the second half (report item 29): validity, where zizmor is security. Its shellcheck/pyflakes integration is OFF so the verdict does not depend on the box. 1 is a finding; 2 and 3 audited nothing and map to exit 3. One tool missing no longer hides the other's verdict: each half reports, a finding from either is 1, otherwise a missing half is 3. Selftest red on three mutants (pass-through exit, flags dropped, absent-is-clean).
#   2026-10-08 v0.2.3.20261008.1245 — fork_runner_check: a runner expression reading SCAFFOLD_RUNNER(S) in a pull_request workflow must route a foreign-head PR to a hosted runner. Needs no zizmor. Red against the 0.111.16 workflow on all three sites.
#   2026-09-23 v0.2.2.20260923.0941 — mktemp takes a ${TMPDIR} template. macOS mktemp ignores TMPDIR without one, so a guarded fixture root could not contain it.
#   2026-09-23 v0.2.1.20260923.0843 — every mktemp fails closed. A failed one left the temp variable empty, so the fixture ran in the caller's directory; header_check's committed into Robiton/control.
#   2026-09-22 v0.1.0 — New. zizmor found a REAL template injection in this repository's
#                        workflow on 2026-09-21 -- `github.base_ref`, which is a branch name
#                        and therefore attacker-controllable, interpolated straight into a
#                        `run:` block. That workflow ships to every adopter, so the same live
#                        line was in localcoder, control and collectionapp. It was found by
#                        somebody running the tool BY HAND, once. Nothing ran it on any
#                        schedule, and the follow-up sweep a day later missed collectionapp,
#                        which was still carrying it. That is the gate's whole argument, and
#                        it is measured rather than hypothetical.
#
#                        --persona=auditor IS NOT OPTIONAL AND IS THE MOST IMPORTANT LINE
#                        IN THIS FILE. zizmor's DEFAULT persona (`regular`) suppressed 7 of
#                        the 11 findings on this repository. A gate invoking `zizmor` plainly
#                        would have examined four findings while printing something that
#                        reads exactly like a full audit -- a non-verdict wearing a verdict's
#                        clothes, which is the failure this project keeps finding in itself.
#                        Measured on the M3 by the runner session, 2026-09-22.
#
#                        THE FLOOR IS `high`, AND IT WAS CHOSEN BY MEASUREMENT, NOT TASTE.
#                        Against a reconstructed fixture of the actual bug:
#                            `${{ github.base_ref }}` in a run: block
#                                -> error[template-injection], severity HIGH
#                            `${{ needs.<job>.result }}` in a run: block (3 live here)
#                                -> help[template-injection],  severity LOW
#                        `needs.*.result` is a closed enum the workflow engine writes, not
#                        user input. So `high` separates the injection that can actually hurt
#                        from the three that cannot, and the gate is green on this tree
#                        TODAY while still red against the exact bug that motivated it.
#
#                        THE EXIT MAPPING IS INVERTED AND THAT IS THE TRAP. zizmor and this
#                        toolchain disagree about what `1` means:
#                            zizmor  0 = clean      -> our 0  (pass)
#                            zizmor 14 = findings   -> our 1  (found something)
#                            zizmor  1 = COULD NOT RUN, e.g. a path that does not exist
#                                                   -> our 3  (verified nothing)
#                        A wrapper that passed the code through would report FINDINGS when
#                        zizmor had audited nothing, and `zizmor ... || exit 1` would make a
#                        typo'd path indistinguishable from a real injection. Worse, on that
#                        failure zizmor writes `fatal: no audit was performed` to STDERR and
#                        leaves STDOUT COMPLETELY EMPTY -- so a gate that reads stdout for
#                        its verdict sees a clean, quiet nothing. Exit codes measured on
#                        zizmor 1.30.1; stderr is captured deliberately for that reason.
#
#                        ONE WORD, TWO MECHANISMS. zizmor prints "(N ignored)" both when the
#                        PERSONA suppresses a finding and when --min-severity filters one.
#                        They are not the same thing and this file never uses "ignored" to
#                        mean either; it says suppressed or below-floor.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 3

ZIZMOR_PIN="1.30.1"
PERSONA="auditor"
MIN_SEVERITY="high"
WF_DIR=".github/workflows"

ACTIONLINT_PIN="1.7.7"

zizmor_version() { "$1" --version 2>/dev/null | awk '{print $2}' | head -1; }
# actionlint prints the bare version on its first line, then how it was installed.
actionlint_version() { "$1" --version 2>/dev/null | head -1 | tr -d '[:space:]'; }

gap() {
  echo "workflow_audit: DID NOT RUN — $1"
  echo "  This is exit 3: NOT a pass. No workflow was audited."
  [ -n "${2:-}" ] && printf '%s\n' "$2" | sed 's/^/  /'
  exit 3
}

# A STRUCTURAL CHECK THAT NEEDS NO zizmor, added the day the gate's own CI step shipped
# with this bug. GitHub runs a `run:` block as `bash -e`, so
#     tool --check; rc=$?
# kills the shell the moment `tool` returns non-zero -- `rc=$?` never executes and every
# line of exit-3 handling below it is DEAD CODE. Measured 2026-09-22: the shell-lint step
# went red on the Linux runner ("Process completed with exit code 3") while the macOS
# runner passed the same commit, because macOS had the binary and so never took the
# failing path. A three-outcome gate whose third outcome is unreachable is a two-outcome
# gate, and only a heterogeneous fleet showed it.
#
# `|| rc=$?` is the correct form: the left side of `||` is exempt from `-e`.
#
# This runs even where zizmor is absent, so the tool does real work on a box that cannot
# audit -- and it is the guard for a defect this repository has now actually shipped once.
dead_handler_check() {
  local hits
  hits="$(grep -nE '^[[:space:]]*[^#]*\b(tools/|\./)[A-Za-z0-9_./-]+[^|]*;[[:space:]]*rc=\$\?' \
            "$WF_DIR"/*.yml "$WF_DIR"/*.yaml 2>/dev/null || true)"
  [ -z "$hits" ] && return 0
  echo "workflow_audit: a three-outcome handler is UNREACHABLE under \`bash -e\`"
  printf '%s\n' "$hits" | sed 's/^/  /'
  echo ""
  echo "  GitHub runs a run: block as \`bash -e\`. \`tool; rc=\$?\` exits the shell at the"
  echo "  first non-zero, so rc=\$? and everything after it never runs. Use:  tool || rc=\$?"
  return 1
}

# A SELF-HOSTED RUNNER MUST NOT TAKE A FORK'S PULL REQUEST (audit 2026-10-08). Every
# runner expression that reads SCAFFOLD_RUNNER(S) in a workflow triggered by pull_request
# must carry the foreign-head guard, so a fork's PR is routed to a hosted runner. Needs no
# zizmor. It is defence in depth: the PR controls its own workflow file, so the repository's
# fork-PR setting is the real control. This catches the guard being lost by an honest edit.
fork_runner_check() {
  local f hits="" line
  for f in "$WF_DIR"/*.yml "$WF_DIR"/*.yaml; do
    [ -f "$f" ] || continue
    grep -qE '^[[:space:]]*pull_request(_target)?[[:space:]]*:' "$f" || continue
    line="$(grep -nE 'vars\.SCAFFOLD_RUNNERS?' "$f" | grep -vE '^[0-9]+:[[:space:]]*#' \
              | grep -vF 'github.event.pull_request.head.repo.full_name != github.repository' || true)"
    [ -n "$line" ] && hits="$hits$(printf '%s\n' "$line" | sed "s|^|$f:|")
"
  done
  [ -z "$hits" ] && return 0
  echo "workflow_audit: a runner expression can send a FORK's pull request to a self-hosted runner"
  printf '%s' "$hits" | sed 's/^/  /'
  echo ""
  echo "  Route a foreign head to a hosted runner first:"
  echo "    (github.event_name == 'pull_request' && github.event.pull_request.head.repo.full_name != github.repository) && '[\"ubuntu-latest\"]' || ..."
  return 1
}

# ONE TOOL'S ABSENCE MUST NOT COST THE OTHER'S VERDICT. Each half below prints its own
# result and returns 0 (clean), 1 (findings) or 3 (did not run); run_check combines them.
# A finding from either is 1. Otherwise a half that did not run makes the whole exit 3 --
# NOT a pass -- but the half that did run has already said what it found.
tool_gap() {
  echo "workflow_audit: $1 DID NOT RUN — $2"
  echo "  This half is exit 3: NOT a pass."
  [ -n "${3:-}" ] && printf '%s\n' "$3" | sed 's/^/  /'
  return 3
}

zizmor_check() { # $1 = workflow file count
  local n="$1"
  command -v zizmor >/dev/null 2>&1 || { tool_gap zizmor "no zizmor on PATH" \
    "Do not assume a runner has it: measured 2026-09-22, shellcheck was present on the
  macOS self-hosted runner and absent on the Linux one, and nobody had checked."; return 3; }

  local v; v="$(zizmor_version zizmor)"
  [ "$v" = "$ZIZMOR_PIN" ] || { tool_gap zizmor \
    "zizmor ${v:-unreadable} is not the pinned $ZIZMOR_PIN — a different zizmor is a different gate"; return 3; }

  # STDERR IS CAPTURED ON PURPOSE. zizmor's could-not-run reason lives there and stdout is
  # empty in that case, so discarding stderr would turn a failure into a silent clean read.
  local out rc err
  err="$(mktemp "${TMPDIR:-/tmp}/wfaudit.XXXXXX")" || { echo "workflow_audit: mktemp failed; stopping" >&2; exit 1; }
  out="$(zizmor "$WF_DIR" --persona="$PERSONA" --min-severity "$MIN_SEVERITY" --format plain 2>"$err")" && rc=0 || rc=$?

  case "$rc" in
    0)
      rm -f "$err"
      echo "workflow_audit: $n workflow file(s) clean at zizmor $ZIZMOR_PIN"
      echo "  persona=$PERSONA (nothing suppressed), floor=$MIN_SEVERITY"
      echo "  FINDINGS BELOW \`$MIN_SEVERITY\` ARE NOT EXAMINED HERE and are not a pass."
      echo "  Full picture:  zizmor $WF_DIR --persona=auditor --min-severity informational"
      return 0
      ;;
    14)
      rm -f "$err"
      echo "workflow_audit: zizmor $ZIZMOR_PIN found finding(s) at severity >= $MIN_SEVERITY"
      printf '%s\n' "$out" | sed 's/^/  /'
      echo ""
      echo "  A high finding here is the class that already shipped a live template"
      echo "  injection to four repositories. Fix it; do not raise the floor."
      return 1
      ;;
    1)
      # NOT A FINDING. zizmor could not audit. stdout is empty; the reason is on stderr.
      local why; why="$(sed 's/^/  /' "$err" 2>/dev/null | head -5)"; rm -f "$err"
      tool_gap zizmor "zizmor exited 1 — it audited nothing (this is NOT 'found findings')" "$why"
      ;;
    *)
      local why; why="$(sed 's/^/  /' "$err" 2>/dev/null | head -5)"; rm -f "$err"
      tool_gap zizmor "zizmor exited $rc, which this gate does not know how to read" "$why"
      ;;
  esac
}

# actionlint IS THE OTHER HALF (report item 29). zizmor reads a workflow for SECURITY; it
# does not check that the workflow is VALID -- an unknown key, a `needs:` naming a job that
# does not exist, an expression that will not type-check, a malformed `on:`. Those fail at
# run time on GitHub, often only on the event that exercises them.
#
# -shellcheck= AND -pyflakes= ARE EMPTY ON PURPOSE. actionlint runs either one over `run:`
# blocks WHEN IT FINDS THEM ON PATH, so the same commit would get a different verdict on a
# box that happens to carry shellcheck -- a gate measuring the machine, not the workflow.
# Shell in workflows is shell_lint's job, where its presence is checked and reported.
#
# EXIT CODES (actionlint docs): 0 clean, 1 problems found, 2 bad command line, 3 fatal.
# Only 1 is a finding. 2 and 3 audited nothing and map to our 3, never to 1 or 0.
actionlint_check() { # $1 = workflow file count
  local n="$1"
  command -v actionlint >/dev/null 2>&1 || { tool_gap actionlint "no actionlint on PATH" \
    "Install actionlint $ACTIONLINT_PIN on the runners; this box is not one by standing rule."; return 3; }
  local v; v="$(actionlint_version actionlint)"
  [ "$v" = "$ACTIONLINT_PIN" ] || { tool_gap actionlint \
    "actionlint ${v:-unreadable} is not the pinned $ACTIONLINT_PIN — a different actionlint is a different gate"; return 3; }

  local out rc err files
  files="$(find "$WF_DIR" -maxdepth 1 \( -name '*.yml' -o -name '*.yaml' \) -print 2>/dev/null | sort)"
  err="$(mktemp "${TMPDIR:-/tmp}/wfaudit.XXXXXX")" || { echo "workflow_audit: mktemp failed; stopping" >&2; exit 1; }
  # shellcheck disable=SC2086  # one path per line, none with spaces: find over WF_DIR
  out="$(actionlint -no-color -shellcheck= -pyflakes= $files 2>"$err")" && rc=0 || rc=$?
  case "$rc" in
    0)
      rm -f "$err"
      echo "workflow_audit: $n workflow file(s) valid at actionlint $ACTIONLINT_PIN"
      echo "  (shellcheck and pyflakes integration OFF: shell_lint owns run: blocks)"
      return 0
      ;;
    1)
      rm -f "$err"
      echo "workflow_audit: actionlint $ACTIONLINT_PIN found problem(s)"
      printf '%s\n' "$out" | sed 's/^/  /'
      return 1
      ;;
    *)
      local why; why="$(sed 's/^/  /' "$err" 2>/dev/null | head -5)"; rm -f "$err"
      tool_gap actionlint "actionlint exited $rc — it audited nothing (this is NOT 'found problems')" "$why"
      ;;
  esac
}

run_check() {
  # BEFORE the tool resolution on purpose: this half needs no binary, so a box without
  # zizmor still gets a real verdict on it instead of an unqualified "verified nothing".
  dead_handler_check || return 1
  fork_runner_check || return 1

  [ -d "$WF_DIR" ] || gap "no $WF_DIR in this repository"
  # PARENTHESISED ON PURPOSE. `-name a -o -name b` without them binds -maxdepth to only the
  # first branch, and the implicit -print lands in a different place on BSD and GNU find.
  local n; n="$(find "$WF_DIR" -maxdepth 1 \( -name '*.yml' -o -name '*.yaml' \) -print 2>/dev/null | wc -l | tr -d ' ')"
  [ "$n" -gt 0 ] || gap "$WF_DIR exists but contains no workflow files"

  # `|| zr=$?`: the left side of || is exempt from errexit, and the same form is what this
  # file tells every workflow to use.
  local zr=0 ar=0
  zizmor_check "$n" || zr=$?
  actionlint_check "$n" || ar=$?
  if [ "$zr" = 1 ] || [ "$ar" = 1 ]; then return 1; fi
  if [ "$zr" = 3 ] || [ "$ar" = 3 ]; then
    echo "workflow_audit: exit 3 — NOT a pass. zizmor: $( [ "$zr" = 0 ] && echo clean || echo 'did not run'), actionlint: $( [ "$ar" = 0 ] && echo valid || echo 'did not run')."
    exit 3
  fi
  return 0
}

# ---- selftest ---------------------------------------------------------------------------
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); }
bad() { FAIL=$((FAIL+1)); echo "  [FAIL] $1"; }
case_is() { if [ "$2" = "$3" ]; then ok; else bad "$1: expected [$3] got [$2]"; fi; }

selftest() {
  echo "workflow_audit.sh --selftest"
  # T IS DELIBERATELY NOT `local` — the EXIT trap fires after this function returns, and
  # under `set -u` a locally-scoped T makes the cleanup print an error on every run.
  T="$(mktemp -d "${TMPDIR:-/tmp}/workflow_audit.XXXXXX")" || { echo "workflow_audit: mktemp failed; stopping" >&2; exit 1; }; trap 'rm -rf "$T"' EXIT

  # A stub zizmor lets every exit code be exercised on a box that has no zizmor at all --
  # which is this one. The mapping is the thing under test, not zizmor.
  mkstub() { # $1 = exit code, $2 = stdout, $3 = stderr
    mkdir -p "$T/bin"
    { printf '#!/bin/sh\n'
      printf 'case "$1" in --version) echo "zizmor %s"; exit 0 ;; esac\n' "$ZIZMOR_PIN"
      printf 'printf "%%s\\n" "%s"\n' "$2"
      printf 'printf "%%s\\n" "%s" >&2\n' "$3"
      printf 'exit %s\n' "$1"
    } > "$T/bin/zizmor"
    chmod +x "$T/bin/zizmor"
    # A clean actionlint at the pin unless a case wrote its own: the zizmor cases test
    # zizmor, and must not change verdict on a runner that carries a real actionlint.
    [ -f "$T/bin/actionlint" ] || mkalstub "$T/bin" 0 "" ""
  }
  mkalstub() { # $1 = dir, $2 = exit code, $3 = stdout, $4 = stderr
    mkdir -p "$1"
    { printf '#!/bin/sh\n'
      printf 'case "$1" in --version) echo "%s"; echo "installed by stub"; exit 0 ;; esac\n' "$ACTIONLINT_PIN"
      printf 'echo "$@" > "%s/al_argv"\n' "$T"
      printf 'printf "%%s\\n" "%s"\n' "$3"
      printf 'printf "%%s\\n" "%s" >&2\n' "$4"
      printf 'exit %s\n' "$2"
    } > "$1/actionlint"
    chmod +x "$1/actionlint"
  }
  # THE SCRIPT IS COPIED INTO EACH FIXTURE, NOT POINTED AT ONE. run_check resolves ROOT
  # from its own BASH_SOURCE and cds there, so invoking the real tools/workflow_audit.sh
  # from a temp directory audits THE REAL REPOSITORY and cheerfully reports on it -- every
  # case below would have passed while measuring the wrong tree. Copying it in makes
  # `dirname/..` resolve to the fixture, which is the honest way to get the isolation.
  # The alternative, an env var that relocates ROOT, is a test-only backdoor in production
  # code, and the thing a backdoor is most likely to do is be left switched on.
  mkrepo() { mkdir -p "$1/tools" && cp "$ROOT/tools/workflow_audit.sh" "$1/tools/"; }
  runin()  { ( cd "$1" && PATH="$2:$PATH" bash "$1/tools/workflow_audit.sh" --check >/dev/null 2>&1 ); echo $?; }
  runstub() { runin "$T/repo" "$T/bin"; }
  # ABSENCE NEEDS A CLOSED PATH: a runner that carries the real tool would otherwise find it.
  runonly() { ( cd "$1" && PATH="$2:/usr/bin:/bin" bash "$1/tools/workflow_audit.sh" --check 2>&1 ); }

  mkrepo "$T/repo"; mkdir -p "$T/repo/.github/workflows"
  printf 'on: push\njobs:\n  a:\n    runs-on: x\n' > "$T/repo/.github/workflows/w.yml"

  # 0. the fixture must be the thing under test. If ROOT still resolved to the scaffold,
  #    this would find the scaffold's own workflow count and the isolation would be fake.
  mkstub 0 "clean" ""
  if [ "$( cd "$T/repo" && PATH="$T/bin:$PATH" bash "$T/repo/tools/workflow_audit.sh" --check 2>/dev/null | head -1 )" \
     = "workflow_audit: 1 workflow file(s) clean at zizmor $ZIZMOR_PIN" ]; then ok
  else bad "the harness audited something other than the 1-file fixture"; fi

  # 1. clean -> 0
  mkstub 0 "No findings to report. Good job! (9 ignored)" ""
  case_is "zizmor 0 (clean) maps to 0" "$(runstub)" "0"

  # 2. findings -> 1
  mkstub 14 "error[template-injection]: code injection" ""
  case_is "zizmor 14 (findings) maps to 1" "$(runstub)" "1"

  # 3. THE INVERSION. zizmor 1 is could-not-run and MUST NOT read as a finding, and must
  #    certainly not read as a pass. This is the case a pass-through wrapper gets wrong.
  mkstub 1 "" "fatal: no audit was performed"
  case_is "zizmor 1 (could not run) maps to 3, not 1" "$(runstub)" "3"

  # 3b. and it must SAY so. An exit 3 whose text reads like a finding teaches the reader
  #     the wrong thing even when the code is right.
  if ( cd "$T/repo" && PATH="$T/bin:$PATH" bash "$T/repo/tools/workflow_audit.sh" --check 2>&1 ) \
       | grep -Fq "no audit was performed"; then ok
  else bad "the exit-3 message did not carry zizmor's stderr reason"; fi

  # 4. an exit code we have never seen must be exit 3, never 0. Unknown is not clean.
  mkstub 99 "" "something new"
  case_is "an unknown exit maps to 3" "$(runstub)" "3"

  # 5. a version that is not the pin is refused rather than quietly answered with
  mkdir -p "$T/bin2"
  printf '#!/bin/sh\ncase "$1" in --version) echo "zizmor 0.0.1"; exit 0 ;; esac\nexit 0\n' > "$T/bin2/zizmor"
  chmod +x "$T/bin2/zizmor"; mkalstub "$T/bin2" 0 "" ""
  case_is "a non-pin zizmor is refused (exit 3)" "$(runin "$T/repo" "$T/bin2")" "3"

  # 6. no workflows directory at all is exit 3, not a pass
  mkrepo "$T/bare"
  mkstub 0 "No findings to report." ""
  case_is "a repo with no workflows is exit 3" "$(runin "$T/bare" "$T/bin")" "3"

  # 6b. THE DEAD-HANDLER GUARD MUST GO RED AGAINST THE BUG THIS REPO ACTUALLY SHIPPED.
  #     Reconstructed verbatim from the step that failed CI on 2026-09-22. It needs no
  #     zizmor, so it is the one arm that gets a real verdict on a box without the binary.
  mkrepo "$T/dead"; mkdir -p "$T/dead/.github/workflows"
  { printf 'jobs:\n  a:\n    steps:\n      - run: |\n'
    printf '          tools/shell_lint.sh --check; rc=$?\n'
    printf '          if [ "$rc" = "3" ]; then echo warn; fi\n'
  } > "$T/dead/.github/workflows/w.yml"
  case_is "the -e dead-handler bug is caught (exit 1, not 3)" "$(runin "$T/dead" "$T/bin")" "1"

  # 6c. and the CORRECT form must not be flagged, or the guard is just noise.
  mkrepo "$T/live"; mkdir -p "$T/live/.github/workflows"
  { printf 'jobs:\n  a:\n    steps:\n      - run: |\n'
    printf '          rc=0\n'
    printf '          tools/shell_lint.sh --check || rc=$?\n'
  } > "$T/live/.github/workflows/w.yml"
  case_is "the correct || form is NOT flagged" "$(runin "$T/live" "$T/bin")" "0"

  # 6d. A FORK'S PR MUST NOT REACH A SELF-HOSTED RUNNER (audit 2026-10-08). The unguarded
  #     expression is the one this repository shipped until that day.
  mkrepo "$T/fork"; mkdir -p "$T/fork/.github/workflows"
  { printf 'on:\n  pull_request:\njobs:\n  a:\n'
    printf '    runs-on: ${{ fromJSON(vars.SCAFFOLD_RUNNERS || %s) }}\n' "'[\"ubuntu-latest\"]'"
  } > "$T/fork/.github/workflows/w.yml"
  case_is "an unguarded self-hosted runner on pull_request is caught" "$(runin "$T/fork" "$T/bin")" "1"
  mkrepo "$T/forkok"; mkdir -p "$T/forkok/.github/workflows"
  { printf 'on:\n  pull_request:\njobs:\n  a:\n'
    printf "    runs-on: \${{ fromJSON((github.event_name == 'pull_request' && github.event.pull_request.head.repo.full_name != github.repository) && '[\"ubuntu-latest\"]' || vars.SCAFFOLD_RUNNERS || '[\"ubuntu-latest\"]') }}\n"
  } > "$T/forkok/.github/workflows/w.yml"
  case_is "the guarded expression is NOT flagged" "$(runin "$T/forkok" "$T/bin")" "0"
  mkrepo "$T/pushonly"; mkdir -p "$T/pushonly/.github/workflows"
  printf 'on:\n  push:\njobs:\n  a:\n    runs-on: ${{ vars.SCAFFOLD_RUNNER }}\n' > "$T/pushonly/.github/workflows/w.yml"
  case_is "a push-only workflow is not a PR surface" "$(runin "$T/pushonly" "$T/bin")" "0"

  # 7. the invocation must actually carry the persona. A gate that drops it examines a
  #    third of what it reports, which is the defect this file exists to avoid.
  mkdir -p "$T/bin3"
  { printf '#!/bin/sh\n'
    printf 'case "$1" in --version) echo "zizmor %s"; exit 0 ;; esac\n' "$ZIZMOR_PIN"
    printf 'echo "$@" > "%s/argv"\nexit 0\n' "$T"
  } > "$T/bin3/zizmor"; chmod +x "$T/bin3/zizmor"; mkalstub "$T/bin3" 0 "" ""
  runin "$T/repo" "$T/bin3" >/dev/null
  if grep -Fq -- "--persona=auditor" "$T/argv" 2>/dev/null; then ok; else bad "the invocation did not carry --persona=auditor"; fi
  if grep -Fq -- "--min-severity high" "$T/argv" 2>/dev/null; then ok; else bad "the invocation did not carry --min-severity high"; fi

  # 8. THE actionlint HALF (report item 29). Its exit codes are not zizmor's: 1 is a
  #    finding, 2 (bad flags) and 3 (fatal) audited nothing and must read as exit 3.
  mkstub 0 "clean" ""
  mkalstub "$T/bin" 1 "w.yml:4:14: label \"x\" is unknown [runner-label]" ""
  case_is "actionlint 1 (problems) maps to 1" "$(runstub)" "1"
  mkalstub "$T/bin" 3 "" "fatal: could not read"
  case_is "actionlint 3 (fatal) maps to 3, not 1" "$(runstub)" "3"
  mkalstub "$T/bin" 2 "" "flag provided but not defined"
  case_is "actionlint 2 (bad flags) maps to 3" "$(runstub)" "3"
  mkalstub "$T/bin" 0 "" ""
  case_is "both clean is 0" "$(runstub)" "0"

  # 9. ONE ABSENT TOOL MUST NOT HIDE THE OTHER'S VERDICT.
  mkdir -p "$T/zonly"; cp "$T/bin/zizmor" "$T/zonly/"
  _o="$(runonly "$T/repo" "$T/zonly")"; _rc=$?
  case_is "zizmor clean + no actionlint is exit 3" "$_rc" "3"
  if printf '%s' "$_o" | grep -Fq "clean at zizmor" && printf '%s' "$_o" | grep -Fq "no actionlint on PATH"; then ok
  else bad "the exit-3 run did not report BOTH zizmor's clean verdict and the missing actionlint"; fi
  mkdir -p "$T/aonly"; mkalstub "$T/aonly" 1 "w.yml:1:1: bad [syntax-check]" ""
  _o="$(runonly "$T/repo" "$T/aonly")"; _rc=$?
  case_is "an actionlint finding with no zizmor is 1, not 3" "$_rc" "1"

  # 10. a non-pin actionlint is refused, like a non-pin zizmor.
  mkdir -p "$T/bin4"; cp "$T/bin/zizmor" "$T/bin4/"
  printf '#!/bin/sh\ncase "$1" in --version) echo "1.0.0"; exit 0 ;; esac\nexit 0\n' > "$T/bin4/actionlint"
  chmod +x "$T/bin4/actionlint"
  case_is "a non-pin actionlint is refused (exit 3)" "$(runin "$T/repo" "$T/bin4")" "3"

  # 11. THE INTEGRATIONS ARE OFF, or the verdict depends on what else is on the box.
  rm -f "$T/al_argv"; runstub >/dev/null
  if grep -Fq -- "-shellcheck= " "$T/al_argv" 2>/dev/null && grep -Fq -- "-pyflakes= " "$T/al_argv" 2>/dev/null; then ok
  else bad "actionlint ran without -shellcheck= and -pyflakes= ($(cat "$T/al_argv" 2>/dev/null))"; fi

  echo "  $PASS passed, $FAIL failed"
  [ "$FAIL" = "0" ]
}

case "${1:---check}" in
  --check)    run_check ;;
  --pin)      echo "zizmor $ZIZMOR_PIN (persona: $PERSONA, floor: $MIN_SEVERITY); actionlint $ACTIONLINT_PIN" ;;
  --selftest) selftest ;;
  *) echo "usage: workflow_audit.sh [--check | --pin | --selftest]" >&2; exit 2 ;;
esac
