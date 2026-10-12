#!/usr/bin/env bash
# Project:  ai-project-scaffold
# File:     tools/scaffold_log.sh
# Modified: 2026-09-23
# Version:  0.3.2.20260923.0941
# Purpose:  Record that a check RAN, so a check that stops running is visible.
# Changelog:
#   2026-09-23 v0.3.2.20260923.0941 — mktemp takes a ${TMPDIR} template. macOS mktemp ignores TMPDIR without one, so a guarded fixture root could not contain it.
#   2026-08-31 v0.3.1.20260831.0904 — #251 '\\t' in a BRE is an escaped t, not a tab, on GNU grep and ugrep -- the assertion failed
#                        while the row it sought was present. Pattern now built with printf.
#   2026-08-19 v0.3.0 — A QUIET KEY HAS THREE CAUSES AND ONLY ONE IS AN ALARM. Every quiet
#                        key printed the same 'check stopped running'. Measured here: FIVE
#                        were about to fire on 2026-08-24 and NONE was a real silence --
#                        four tools that left in the W-15 split, plus `preflight:lint_python.sh`
#                        frozen at 30 runs while `preflight:ruff, pinned (tools/lint_python.sh)`
#                        had 244 and ran that morning: one check, two keys, because
#                        RELABELLING A GATE STARTS A NEW SERIES. Five wolf cries in the one
#                        report whose job is detecting silence teaches the reader to skip it.
#                        Now split into SILENT (still here, stopped — the finding), RELABELLED
#                        (a live key names the same tool) and RETIRED (not in the tree), with
#                        `--retire` to tombstone by APPENDING, never by rewriting.
#                        THE WALK BUG WAS THE DANGEROUS ONE: it covered tools/ops/src only, so
#                        `sync-check.sh` — top-level, the SessionStart hook, precisely what this
#                        report exists to catch — was filed as 'not an alarm'. Over-reporting
#                        costs a glance; under-reporting is this tool failing at its one job.
#                        A label with no filename in it stays in the alarming column for the
#                        same reason. retire() is a FUNCTION so --selftest exercises the
#                        shipped path: the first tombstone case re-implemented the append in
#                        the fixture and a delete-instead-of-append mutation passed it.
#   2026-08-09 v0.2.0 — `--report` shows runs per week, so it can answer "is this getting
#                        better or worse" and not only "what is true right now". A single
#                        snapshot cannot tell a check that is fading from one that has
#                        always been occasional.
#                        THE BUCKETING WAS DRAFTED BY tools/localcoder — the first real use
#                        of the routing rule this release added. It passed 7/7 against
#                        cases written after the fact (empty weeks, unparseable input,
#                        week-boundary alignment) and review changed exactly one thing: the
#                        draft returned `(None, 0)` for empty input, so a caller printing
#                        the label got "None". Dates are always computable; only counts can
#                        be zero. That one fix is what the agent half of the split is for.
#   2026-08-09 v0.1.0 — New. Every check in this toolchain prints to a console that is then
#                        thrown away, so nothing anywhere records that a check RAN. That is
#                        not a gap in reporting; it is the reason this project's dominant
#                        failure mode is invisible.
#                        Measured on 2026-08-09: FOUR hooks — sync-check at SessionStart and
#                        the journal at SessionStart, Stop and SessionEnd — had never fired
#                        once on the machine that develops this scaffold, because they
#                        resolved paths against the working directory and sessions open in
#                        the parent of three repos. Months. Nothing said so, and nothing
#                        could have: silence is what a passing check and a check that never
#                        ran both look like.
#                        The same week: sync-check's archive nudge branched on an exit code
#                        that had stopped being returned (five releases dead), and CI printed
#                        "12 tool selftest suite(s) passed" in green while a 15-case suite
#                        was skipped for a missing mode bit.
#                        A verdict is not the useful signal here. THE TIMESTAMP IS.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# PER-MACHINE AND GITIGNORED, like ai/SESSION_JOURNAL.md. It records what happened on THIS
# box; committing it would merge three developers' clocks into one file and conflict on
# every push while telling nobody anything. What crosses machines is the ai/ files.
LOG="$ROOT/ai/.scaffold-run-log"

# A LINE PER RUN, and the fields are fixed so `--report` never has to guess:
#   ISO8601<TAB>tool<TAB>verdict<TAB>detail
# Tab-separated because a detail string may contain anything, and the first three fields
# never contain a tab. Same reasoning as reading `git ls-files -s` off a tab.
#
# NOT ROTATED BY LINE COUNT — by AGE. A cap on lines throws away the oldest entries, which
# are exactly the ones that answer "when did this last run", and that question is the whole
# point of the file. 90 days of one line per check per session is a few hundred kilobytes.
KEEP_DAYS="${SCAFFOLD_LOG_KEEP_DAYS:-90}"

now_iso() { date -u +%Y-%m-%dT%H:%M:%SZ; }

log_run() {   # log_run <tool> <verdict> [detail]
  local tool="${1:-?}" verdict="${2:-?}" detail="${3:-}"
  # ONE RECORD, ONE LINE — SANITISED HERE SO EVERY CALLER IS COVERED, not at each call site.
  # Details are free text from callers and a newline in one splits a record across two lines,
  # which `--report` then reads as a malformed row and silently drops. Found immediately:
  # guard_pretooluse.py passes its refusal reason, and those reasons are multi-line prose.
  # A tab does the same to the field boundaries. Both collapse to a space.
  tool="$(printf '%s' "$tool" | tr '\n\t' '  ')"
  verdict="$(printf '%s' "$verdict" | tr '\n\t' '  ')"
  detail="$(printf '%s' "$detail" | tr '\n\t' '  ')"
  mkdir -p "$(dirname "$LOG")" 2>/dev/null || return 0
  # NEVER FAIL A CALLER. This is instrumentation: a full disk or a read-only checkout must
  # not turn a passing check into a failing one. The whole file is best-effort by design,
  # and `--report` says so rather than treating absence as proof of anything.
  #
  # THE GUARANTEE IS THE EXPLICIT `return 0` BELOW, NOT THIS `|| true`. `set -e` is not on
  # here, so a failing append does not abort the function either way — removing `|| true`
  # changes nothing observable, and an injected defect that removed it passed every case.
  # It stays because it survives someone adding `set -e` later, but the honest statement is
  # that no test covers it, and saying so beats implying coverage that does not exist.
  printf '%s\t%s\t%s\t%s\n' "$(now_iso)" "$tool" "$verdict" "$detail" >> "$LOG" 2>/dev/null || true
  prune
  return 0
}

# A FUNCTION, NOT INLINE IN THE DISPATCH, so --selftest can call the SHIPPED code path.
# The first version of the tombstone case re-implemented the append inside the fixture; a
# mutation that made --retire DELETE the matching lines instead of appending passed it,
# because the case never touched the real thing. That is the vacuous-test shape this
# repository has been bitten by before.
retire() {
  if [ $# -lt 1 ] || [ -z "${1:-}" ]; then
    echo "scaffold_log: --retire needs the check key, exactly as --report prints it" >&2
    return 2
  fi
  # APPEND, NEVER REWRITE. Editing the log to drop a check destroys the record of it ever
  # having run, which is the one thing this file exists to hold. A tombstone is just the
  # newest verdict, so a later real run un-retires the key by being newer.
  mkdir -p "$(dirname "$LOG")" 2>/dev/null || true
  printf '%s\t%s\tretired\t%s\n' "$(now_iso)" "$1" "${2:-retired by hand}" >> "$LOG" || true
  echo "scaffold_log: retired '$1' — it will stop being counted as quiet."
  echo "  A later real run supersedes this automatically; nothing is deleted."
}

prune() {
  [ -f "$LOG" ] || return 0
  local cutoff
  # BSD and GNU date disagree about relative dates, and this project has already paid for
  # assuming one of them (`mktemp -t`, and grep's binary-match channel). python3 is already
  # a hard dependency of this toolchain — session_archive.py is vendored beside this file.
  cutoff="$(python3 -c "
import datetime, sys
d = datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(days=$KEEP_DAYS)
sys.stdout.write(d.strftime('%Y-%m-%dT%H:%M:%SZ'))
" 2>/dev/null)" || return 0
  [ -n "$cutoff" ] || return 0
  local tmp="$LOG.tmp.$$"
  awk -F'\t' -v c="$cutoff" '$1 >= c' "$LOG" > "$tmp" 2>/dev/null && mv "$tmp" "$LOG" 2>/dev/null
  rm -f "$tmp" 2>/dev/null
  return 0
}

# THE POINT OF THE FILE: what has gone QUIET.
#
# A verdict tells you about one run. A timestamp tells you whether the check still exists in
# practice, which is the question nothing else in this toolchain can answer. `setup.sh
# --check` reports on the checks it runs; it cannot report on a check that no longer runs at
# all, because from inside a run there is no difference between "clean" and "absent".
report() {
  local quiet_days="${1:-14}"
  if [ ! -f "$LOG" ]; then
    echo "No run log yet at ai/.scaffold-run-log."
    echo "  It fills as checks run. Nothing is wrong; nothing has been recorded."
    return 0
  fi
  echo "Scaffold run log — what has run, and when (ai/.scaffold-run-log)"
  echo ""
  python3 - "$LOG" "$quiet_days" <<'PYEOF'
import sys, datetime, collections
path, quiet_days = sys.argv[1], int(sys.argv[2])
now = datetime.datetime.now(datetime.timezone.utc)
last, counts, verdicts = {}, collections.Counter(), {}
for line in open(path, errors="replace"):
    parts = line.rstrip("\n").split("\t")
    if len(parts) < 3:
        continue
    ts, tool, verdict = parts[0], parts[1], parts[2]
    try:
        when = datetime.datetime.strptime(ts, "%Y-%m-%dT%H:%M:%SZ").replace(
            tzinfo=datetime.timezone.utc)
    except ValueError:
        continue
    counts[tool] += 1
    if tool not in last or when > last[tool]:
        last[tool], verdicts[tool] = when, verdict
# A TOMBSTONE IS A LATEST VERDICT, NOT A DELETED LINE. `--retire` appends rather than
# rewrites, so the history of a check that legitimately left stays readable and the act of
# retiring it is itself dated and attributable. A later real run un-retires it by simply
# being newer, which is the correct behaviour if a tool comes back.
retired_keys = {t for t, v in verdicts.items() if v == "retired"}
for t in retired_keys:
    del last[t]
if not last:
    # DISTINGUISH THE TWO WAYS THIS IS EMPTY. "No rows at all" and "every row retired" are
    # different states and printing one message for both loses the distinction.
    if retired_keys:
        print(f"  (all {len(retired_keys)} tracked check(s) are retired)")
    else:
        print("  (log present but empty)")
    sys.exit(0)
width = max(len(t) for t in last)
quiet = []
for tool in sorted(last, key=lambda t: last[t], reverse=True):
    age = (now - last[tool]).total_seconds() / 86400
    when = "today" if age < 1 else f"{int(age)}d ago"
    flag = ""
    if age >= quiet_days:
        flag = "   <-- QUIET"
        quiet.append((tool, int(age)))
    print(f"  {tool:<{width}}  {counts[tool]:>4} run(s)   last {when:<9} "
          f"{verdicts[tool]}{flag}")
print()
# TREND, so the report can answer "is this getting better or worse" and not only "what is
# true right now". A single snapshot cannot tell a check that is fading from one that has
# always been occasional.
#
# DRAFTED BY tools/localcoder AND KEPT ALMOST AS WRITTEN — the first real use of the routing
# rule in ai/CODING.md. It passed 7/7 against cases written after the fact, including empty
# weeks, unparseable input and week-boundary alignment. Review changed exactly one thing:
# the model returned `(None, 0)` tuples for empty input, so a caller printing the label got
# "None". Dates are always computable; only the counts can be zero.
def bucket_by_week(stamps, weeks=4):
    parsed = []
    for stamp in stamps:
        try:
            parsed.append(datetime.datetime.fromisoformat(stamp.replace("Z", "+00:00")))
        except (ValueError, AttributeError):
            continue
    anchor = max(parsed).date() if parsed else now.date()
    monday = anchor - datetime.timedelta(days=anchor.weekday())
    out = []
    for i in range(weeks):
        start = monday - datetime.timedelta(weeks=i)
        end = start + datetime.timedelta(weeks=1)
        out.append((start.isoformat(),
                    sum(1 for p in parsed if start <= p.date() < end)))
    return out[::-1]


all_stamps = []
for line in open(path, errors="replace"):
    parts = line.rstrip("\n").split("\t")
    if len(parts) >= 3:
        all_stamps.append(parts[0])
weekly = bucket_by_week(all_stamps, weeks=4)
if any(c for _, c in weekly):
    print("  runs per week (all checks):")
    peak = max(c for _, c in weekly) or 1
    for wk, c in weekly:
        bar = "#" * max(1, round(20 * c / peak)) if c else ""
        print(f"    {wk}  {c:>5}  {bar}")
    print()

if quiet:
    # THIS IS THE FINDING, and it is the one no other check in this toolchain can make.
    #
    # TWO CLASSES, BECAUSE ONE OF THEM IS NOT AN ALARM. A key goes quiet for two very
    # different reasons and the old report called both "check stopped running":
    #   RETIRED  -- the tool left, or the gate's LABEL changed. Nothing is broken. Measured
    #               here 2026-08-19: `preflight:lint_python.sh` sat at 30 runs / 9 days
    #               while `preflight:ruff, pinned (tools/lint_python.sh)` had 244 and ran
    #               that morning. Same check, two keys, because relabelling a gate starts a
    #               new series and orphans the old one. Four more keys pointed at tools that
    #               left in the W-15 split. Five false alarms were due to land on 2026-08-24.
    #   SILENT   -- something that still exists here stopped running. THIS is the finding.
    #
    # Five wolf cries in the one report whose entire job is detecting silence would have
    # taught the reader to skip it, which is how the next real outage gets forgiven.
    # Resolution is by SUBSTRING against the tree, not by exact path, because a key is a
    # human label ("ruff, pinned (tools/lint_python.sh)") and not a filename.
    import os, re
    # THE REPO ROOT IS IN THE WALK, and leaving it out was a bug in the DANGEROUS direction.
    # `sync-check.sh` lives at the top level, not under tools/ — it is the SessionStart hook,
    # the very thing this report exists to catch going silent — and a walk of tools/ops/src
    # alone could not see it, so a genuinely quiet hook was being filed as "not an alarm".
    # Over-reporting is a nuisance; under-reporting is this tool failing at its one job.
    on_disk = set(f for f in os.listdir(".") if os.path.isfile(f))
    for d in ("tools", "ops", "src", "tests", "scripts", ".claude", ".githooks"):
        if not os.path.isdir(d):
            continue
        for _root, _dirs, files in os.walk(d):
            on_disk.update(files)

    def names_in(key):
        return [os.path.basename(n) for n in re.findall(r"[\w.-]+\.(?:sh|py)\b", key)]

    def superseded_by(key, age):
        """A live key naming the same tool means this one is a RENAMED LABEL, not a silence.

        Measured 2026-08-19: `preflight:lint_python.sh` sat at 30 runs / 9 days while
        `preflight:ruff, pinned (tools/lint_python.sh)` had 244 and ran that morning. The
        file is on disk, so resolvability alone calls the dead key SILENT and reports a
        check that runs on every single preflight as having stopped.
        """
        mine = set(names_in(key))
        if not mine:
            return None
        for other in last:
            if other == key:
                continue
            if (now - last[other]).total_seconds() / 86400 >= quiet_days:
                continue
            if mine & set(names_in(other)):
                return other
        return None

    silent, retired, relabelled = [], [], []
    for t, a in quiet:
        live = superseded_by(t, a)
        if live is not None:
            relabelled.append((t, a, live))
        elif names_in(t) and not any(n in on_disk for n in names_in(t)):
            retired.append((t, a))
        else:
            # NO FILENAME IN THE LABEL MEANS CANNOT JUDGE, so it stays in the alarming
            # column on purpose. A false alarm costs a glance; a false all-clear costs the
            # outage this whole report exists to surface.
            silent.append((t, a))
    if silent:
        print(f"  {len(silent)} check(s) still present here have not run in {quiet_days}+ days.")
        for t, a in silent:
            print(f"    - {t}  ({a}d)")
        print("  A check that stopped running looks exactly like a check with nothing to")
        print("  report. Confirm it is still wired — .claude/settings.json hooks resolve")
        print("  against the session's working directory, which is how four of them went")
        print("  silent for months on this project's own machine.")
    if relabelled:
        if silent:
            print()
        print(f"  {len(relabelled)} quiet key(s) are an OLD LABEL for a check that is still")
        print("  running under a new name. Renaming a gate starts a new series and orphans")
        print("  the old one; nothing is broken. Tombstone the old key:")
        for t, a, live in relabelled:
            print(f"    tools/scaffold_log.sh --retire '{t}'      # {a}d, now logged as: {live}")
    if retired:
        if silent or relabelled:
            print()
        print(f"  {len(retired)} quiet key(s) name a tool that is not in this tree — moved,")
        print("  renamed, or retired. NOT an alarm, and left in the log rather than deleted")
        print("  so the history stays readable. Tombstone them so they stop being counted:")
        for t, a in retired:
            print(f"    tools/scaffold_log.sh --retire '{t}'      # {a}d")
    if not silent and not retired and not relabelled:
        print(f"  Nothing has gone quiet (threshold {quiet_days} days).")
else:
    print(f"  Nothing has gone quiet (threshold {quiet_days} days).")
PYEOF
  return 0
}

selftest() {
  local fails=0 T
  T="$(mktemp -d "${TMPDIR:-/tmp}/scaffold_log.XXXXXX")" || return 1
  local real_log="$LOG"
  chk() {  # chk <label> <expected> <actual>
    if [ "$2" = "$3" ]; then printf '  ok   %-56s\n' "$1"
    else printf '  FAIL %-56s expected=%s got=%s\n' "$1" "$2" "$3"; fails=$((fails + 1)); fi
  }

  echo "scaffold_log selftest — a check that stops running must become visible"

  LOG="$T/log"
  log_run "tool_a" "ok" "detail here"
  chk "a run is recorded"            1 "$(wc -l < "$T/log" | tr -d ' ')"
  chk "the tool name is field 2"     "tool_a" "$(awk -F'\t' 'NR==1{print $2}' "$T/log")"
  chk "the verdict is field 3"       "ok"     "$(awk -F'\t' 'NR==1{print $3}' "$T/log")"
  # A DETAIL CONTAINING A TAB WOULD SHIFT EVERY FIELD AFTER IT. Details are free text from
  # callers, so the format has to survive one.
  log_run "tool_b" "fail" "$(printf 'a\tb')"
  chk "a tab in the detail does not move field 2" "tool_b" \
      "$(awk -F'\t' 'NR==2{print $2}' "$T/log")"
  chk "a tab in the detail does not move field 3" "fail" \
      "$(awk -F'\t' 'NR==2{print $3}' "$T/log")"
  # AND A NEWLINE, WHICH IS THE ONE THAT ACTUALLY HAPPENED. guard_pretooluse.py passes its
  # refusal reason and those are multi-line prose; the first version wrote a record across
  # two lines, and --report drops a row it cannot parse — a log entry that silently is not
  # one. The tab case existed and this did not, which is the whole lesson.
  log_run "tool_d" "ask" "$(printf 'line one\nline two')"
  chk "a newline in the detail stays ONE record" 3 "$(wc -l < "$T/log" | tr -d ' ')"
  chk "a newline does not move field 2" "tool_d" \
      "$(awk -F'\t' 'NR==3{print $2}' "$T/log")"
  chk "the whole detail survives on one line" "line one line two" \
      "$(awk -F'\t' 'NR==3{print $4}' "$T/log")"

  # INSTRUMENTATION MUST NEVER FAIL ITS CALLER. A read-only tree is the realistic case:
  # a check running against a checkout someone mounted ro must still report its own verdict.
  #
  # THE DIRECTORY MUST EXIST AND THE FILE MUST BE UNWRITABLE, which is not the same as
  # pointing at a path that cannot exist. The first version used /proc/nonexistent/..., so
  # `mkdir -p` failed and log_run returned at its FIRST guard — the append was never reached
  # and an injected defect that removed the `|| true` from the append passed the case. A
  # fixture has to fail on the line under test; this is the second time today that caught me.
  mkdir -p "$T/ro"
  : > "$T/ro/log"
  chmod 444 "$T/ro/log"
  LOG="$T/ro/log"
  log_run "tool_c" "ok" ""
  chk "an unwritable log still returns 0" 0 $?
  chmod 644 "$T/ro/log" 2>/dev/null || true

  # QUIET DETECTION — the entire reason the file exists.
  LOG="$T/quiet"
  old="$(python3 -c "
import datetime
print((datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(days=40)).strftime('%Y-%m-%dT%H:%M:%SZ'))")"
  printf '%s\tstale_tool\tok\t\n' "$old"       >  "$T/quiet"
  printf '%s\tfresh_tool\tok\t\n' "$(now_iso)" >> "$T/quiet"
  # ONE LINE AT A TIME. The first version globbed the WHOLE report for
  # `*fresh_tool*QUIET*`, which matched because the stale tool's QUIET appears later in the
  # output on a different line — the assertion passed and failed for reasons unrelated to
  # the tool it named. A multi-line glob cannot isolate a row; grep the row first.
  out="$(report 14)"
  chk "a 40-day-old tool is flagged QUIET" 1 \
      "$(printf '%s\n' "$out" | grep -c '^  stale_tool.*QUIET' | tr -d ' ')"
  chk "a tool that ran today is NOT flagged" 0 \
      "$(printf '%s\n' "$out" | grep -c '^  fresh_tool.*QUIET' | tr -d ' ')"
  chk "the fresh tool is still listed"       1 \
      "$(printf '%s\n' "$out" | grep -c '^  fresh_tool' | tr -d ' ')"
  # The threshold has to be load-bearing, or "QUIET" is decoration.
  out="$(report 90)"
  chk "a higher threshold clears the flag" 0 \
      "$(printf '%s\n' "$out" | grep -c 'QUIET' | tr -d ' ')"

  # THE THREE REASONS A KEY GOES QUIET, and they are not one reason (2026-08-19).
  # Before this, every quiet key printed the same "check stopped running" alarm. Measured on
  # this repository: FIVE of them were about to fire and NONE was a real silence -- four
  # tools that left in the W-15 split, and one orphaned LABEL whose check ran on every
  # single preflight. Five wolf cries in the one report whose job is detecting silence.
  #
  # The fixture runs in a scratch tree, so "is this file on disk" is answered against a real
  # directory rather than a stub -- resolution against the tree is the whole mechanism.
  LOG="$T/classes"
  _cwd="$(pwd)"
  mkdir -p "$T/tree/tools" && cd "$T/tree"
  printf '#!/bin/sh\n' > tools/still_here.sh
  printf '#!/bin/sh\n' > roothook.sh          # top-level, NOT under tools/
  old40="$(python3 -c "
import datetime
print((datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(days=40)).strftime('%Y-%m-%dT%H:%M:%SZ'))")"
  {
    printf '%s\tgone_away.sh\tok\t\n'                  "$old40"
    printf '%s\troothook.sh\tok\t\n'                   "$old40"
    printf '%s\tpreflight:tools/still_here.sh\tok\t\n' "$old40"
    printf '%s\tnew label (tools/still_here.sh)\tok\t\n' "$(now_iso)"
  } > "$T/classes"
  out="$(report 14)"
  cd "$_cwd"

  # A TOOL THAT IS NOT IN THE TREE is not an alarm.
  chk "a vanished tool is classed as retired, not silent" 1 \
      "$(printf '%s\n' "$out" | grep -c "retire 'gone_away.sh'" | tr -d ' ')"

  # A TOP-LEVEL FILE IS STILL IN THE TREE. The walk originally covered tools/ops/src only,
  # so sync-check.sh -- the SessionStart hook, the exact thing this report exists to catch --
  # was filed as "not an alarm". A false all-clear here is this tool failing at its one job.
  chk "a quiet TOP-LEVEL script is a real alarm, not 'retired'" 1 \
      "$(printf '%s\n' "$out" | grep -c '^    - roothook.sh')"

  # AN OLD LABEL FOR A LIVE CHECK is not a silence. Resolvability alone cannot see this:
  # the file is on disk, so the dead key looks present-and-silent.
  chk "an orphaned label is classed as relabelled" 1 \
      "$(printf '%s\n' "$out" | grep -c "retire 'preflight:tools/still_here.sh'" | tr -d ' ')"
  chk "and it is NOT reported as a silent check" 0 \
      "$(printf '%s\n' "$out" | grep -c '^    - preflight:tools/still_here.sh')"

  # --retire TOMBSTONES BY APPENDING. Deleting the line would destroy the record of the
  # check ever having run, which is the one thing this file exists to hold.
  _before="$(wc -l < "$T/classes" | tr -d ' ')"
  LOG="$T/classes"
  retire "gone_away.sh" "left in the split" >/dev/null
  chk "retiring APPENDS rather than rewriting" "$((_before + 1))" \
      "$(wc -l < "$T/classes" | tr -d ' ')"
  out="$(report 14)"
  chk "a retired key stops being counted"  0 \
      "$(printf '%s\n' "$out" | grep -c "retire 'gone_away.sh'" | tr -d ' ')"
  # A LITERAL TAB, BUILT BY printf -- NOT '\t' IN THE PATTERN (#251). Inside a POSIX basic
  # regular expression `\t` is an escaped `t`, not a tab. BSD/macOS grep happens to accept
  # it, GNU grep and ugrep do not -- so this assertion failed on Linux while the row it was
  # looking for was present and correct. A false alarm about the ONE property this file
  # exists to hold, which is the worst kind: it teaches you to distrust a working check.
  _tabpat="$(printf '^.*\tgone_away.sh\tok')"
  chk "and its history is still in the log" 1 \
      "$(grep -c "$_tabpat" "$T/classes" | tr -d ' ')"

  # ABSENCE IS NOT A PASS, and must not read as one.
  LOG="$T/missing"
  out="$(report 14)"
  case "$out" in *"Nothing is wrong; nothing has been recorded"*)
      chk "no log says so, rather than implying clean" 1 1 ;;
    *)  chk "no log says so, rather than implying clean" 1 0 ;; esac

  # PRUNING KEEPS THE ANSWER TO 'WHEN DID THIS LAST RUN'. Rotation by age, not by line
  # count: a line cap discards the oldest entries, which are the ones that answer it.
  LOG="$T/prune"
  ancient="$(python3 -c "
import datetime
print((datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(days=400)).strftime('%Y-%m-%dT%H:%M:%SZ'))")"
  printf '%s\tancient\tok\t\n' "$ancient"     >  "$T/prune"
  printf '%s\trecent\tok\t\n'  "$(now_iso)"   >> "$T/prune"
  prune
  # THE TREND FUNCTION, drafted by localcoder and integrated here. Its contract is worth
  # asserting independently of the report that prints it: an empty log must still produce
  # dated weeks (the one thing review had to fix — the draft returned None labels), and the
  # buckets must align to Monday or a "runs per week" row means nothing.
  LOG="$T/trend"
  : > "$T/trend"
  out="$(report 14)"
  case "$out" in *"None"*) chk "empty log produces no None week labels" 1 0 ;;
                 *)        chk "empty log produces no None week labels" 1 1 ;; esac
  printf '2026-08-05T10:00:00Z\ta\tok\t\n2026-08-09T10:00:00Z\tb\tok\t\n' > "$T/trend"
  out="$(report 14)"
  chk "the week bucket starts on a Monday" 1 \
      "$(printf '%s\n' "$out" | grep -c '^    2026-08-03 ')"
  chk "both runs land in that one week"    1 \
      "$(printf '%s\n' "$out" | grep -c '^    2026-08-03      2 ')"

  LOG="$T/prune"
  chk "an entry past the retention window is pruned" 0 \
      "$(grep -c 'ancient' "$T/prune" | tr -d ' ')"
  chk "a recent entry survives pruning"              1 \
      "$(grep -c 'recent' "$T/prune" | tr -d ' ')"

  LOG="$real_log"
  rm -rf "$T"
  echo ""
  if [ "$fails" -eq 0 ]; then echo "  all checks passed"; return 0; fi
  echo "  $fails check(s) FAILED"; return 1
}

case "${1:-}" in
  --selftest) selftest ;;
  --report)   report "${2:-14}" ;;
  --log)      shift; log_run "$@" ;;
  --retire)   shift; retire "$@" ;;
  ""|--help)  echo "usage: scaffold_log.sh --log <tool> <verdict> [detail] | --retire <tool> [why] | --report [quiet-days] | --selftest" ;;
  *)          echo "usage: scaffold_log.sh --log <tool> <verdict> [detail] | --retire <tool> [why] | --report [quiet-days] | --selftest" >&2; exit 2 ;;
esac
