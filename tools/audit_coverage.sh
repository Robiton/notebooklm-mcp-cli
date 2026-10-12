#!/usr/bin/env bash
# Project:  ai-project-scaffold
# File:     tools/audit_coverage.sh
# Modified: 2026-09-30
# Version:  0.3.2.20260930.1041
# Purpose:  Fail when NO leg audited — a fleet with zero coverage must not report as a clean one.
# Changelog:
#   2026-09-30 v0.3.2.20260930.1041 — the final job failed over green legs, fleet-wide. GitHub published leg steps over 100s late on both platforms, and after "Re-run failed jobs" the default listing held no leg, which --settled accepted. Now: --from-outputs reads the legs' job outputs (the primary channel, with no API wait); --settled refuses a listing with no finished leg; both keep only each job's latest attempt, for ?filter=all.
#   2026-09-24 v0.3.1.20260924.0416 — a third state, n/a: a leg whose tree gives a gate nothing to examine. A coverage:<gate>=na marker records it, cancels that leg's skipped =ran, and a gate that is n/a on every leg prints [n/a] and does not fail. n/a next to a gap with nothing ran still fails.
#   2026-09-23 v0.3.0.20260923.1140 — --settled: the aggregating job read the jobs API seconds
#                        after the leg finished, while GitHub still listed that leg with NO
#                        steps. That yielded "derived 0 leg report(s)", so a covered run failed as
#                        "nothing audited". Seen in an adopter on 4 attempts in a row over a
#                        green leg; replayed minutes later, the same run passed. The workflow
#                        now polls until --settled holds.
#   2026-09-23 v0.2.2.20260923.0941 — mktemp takes a ${TMPDIR} template. macOS mktemp ignores TMPDIR without one, so a guarded fixture root could not contain it.
#   2026-09-23 v0.2.1.20260923.0843 — every mktemp fails closed. A failed one left the temp variable empty, so the fixture ran in the caller's directory; header_check's committed into Robiton/control.
#   2026-09-22 v0.2.0.20260922.1457 — THE CHANNEL CHANGED, BECAUSE THE FIRST ONE DOES NOT EXIST HERE.
#                        v0.1.0 had each leg publish its coverage with
#                        actions/upload-artifact. CI failed on BOTH legs with "Artifact
#                        storage quota has been hit" -- while this repository stored ZERO
#                        artifacts, because the quota is ACCOUNT-wide. A cross-leg channel
#                        that depends on a storage quota vanishes without warning and takes
#                        the gate with it, so this now uses no storage at all.
#                        --from-jobs reads the run's OWN job list and derives each leg's
#                        report from a marker step that is `success` when the gate produced
#                        a verdict and `skipped` when it gapped.
#                        THE GATE STEP'S CONCLUSION CANNOT CARRY THIS, and the same run
#                        proved it: the Linux leg gapped the workflow audit and its step
#                        still reported `success`, because exit 3 prints a ::warning:: and
#                        a warning is a successful step. The parsing lives here rather than
#                        in the YAML so it is tested against a recorded payload.
#   2026-09-22 v0.1.0 — New. Brian's decision, after the gap was measured on this fleet:
#                        some legs GAP -> warning (unchanged); EVERY leg GAP -> FAILURE.
#                        No provisioning required; CI goes red when nothing was audited.
#
#                        THE GAP THIS CLOSES. shell_lint.sh and workflow_audit.sh are
#                        three-outcome gates: 0 pass, 1 fail, 3 COULD NOT RUN. Exit 3 is a
#                        ::warning:: on its leg, which is right -- a toolchain missing from
#                        one runner is a provisioning problem, and failing every build over
#                        it trains people to ignore the step. But the fleet is audited today
#                        only because ONE macOS runner happens to carry shellcheck 0.11.0 and
#                        zizmor 1.30.1; the Linux runner carries neither. Retire that one box
#                        and every leg returns 3, every leg warns, and the suite goes GREEN.
#                        A fleet with zero coverage then reports identically to a fully
#                        covered one, which is the exact shape this repository exists to
#                        refuse: green must be an allowlist, and a non-verdict must never
#                        read as a pass.
#
#                        WHY THIS CANNOT LIVE IN THE PER-LEG STEP. A leg knows only its own
#                        result. "Every leg gapped" is not a fact any leg can observe, so the
#                        per-leg step is structurally incapable of deciding it -- which is why
#                        the legs now PUBLISH their coverage and the aggregating job decides.
#
#                        THIS CHECKER MUST NEVER ITSELF GAP. It shells out to nothing and
#                        pins no binary, so it has two outcomes, not three. A coverage checker
#                        that could return "could not check" would recreate the bug it exists
#                        to close, one level up.
#
#                        AN ABSENT REPORT IS NOT A PASS. Zero report files means no leg said
#                        anything -- upload failed, every leg was cancelled, the glob was
#                        wrong. That is the absence this whole file is written against, so it
#                        is a FAILURE, never a quiet success.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# The report a leg writes. One line per gate:  <gate><TAB>ran|gap
# `ran` means the gate produced a real verdict (pass or fail) on that leg.
# `gap` means exit 3 -- the tool was absent, nothing was examined.
# `na`  means the tree gives the gate nothing to examine (dependency_audit with no lockfile).
#       It is NOT a pass and NOT a gap: nothing was examined, and nothing was there to be.
emit() {
  # emit <gate> <ran|gap|na> <file>
  printf '%s\t%s\n' "$1" "$2" >> "$3"
}

check() {
  local dir="${1:-}"
  [ -n "$dir" ] || { echo "usage: audit_coverage.sh --check <report-dir>" >&2; exit 2; }

  if [ ! -d "$dir" ]; then
    echo "[FAIL] coverage: no report directory at '$dir'."
    echo "       No leg published its coverage, so nothing here audited anything."
    echo "       An absent report is not a clean one."
    return 1
  fi

  # -L: a report dir handed to us as a symlink is still a report dir. find does not
  # follow a symlinked ROOT without it, and a zero-match from an unentered directory
  # reads exactly like a real absence.
  # Concatenated ONCE into a single file, deliberately. Every earlier shape here read
  # `cat $files` unquoted, which word-splits on any path containing a space -- and the
  # directory this runs against in CI is an artifact download path we do not control.
  local all legs
  all="$(mktemp "${TMPDIR:-/tmp}/audit_coverage.XXXXXX")" || { echo "audit_coverage: mktemp failed; stopping" >&2; exit 1; }
  legs=0
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    legs=$((legs+1))
    cat "$f" >> "$all" 2>/dev/null || true
  done <<EOF_FILES
$(find -L "$dir" -type f -name '*.tsv' 2>/dev/null | sort || true)
EOF_FILES

  if [ "$legs" -eq 0 ]; then
    rm -f "$all"
    echo "[FAIL] coverage: report directory '$dir' contains no leg reports."
    echo "       Every leg was cancelled, or the upload failed, or the glob is wrong."
    echo "       Whatever the cause, NOTHING was audited and this must not report green."
    return 1
  fi

  # Collect the set of gates mentioned anywhere, then tally per gate.
  local gates
  gates="$(awk -F'\t' 'NF>=2 && $1!="" {print $1}' "$all" | sort -u || true)"

  if [ -z "$gates" ]; then
    rm -f "$all"
    echo "[FAIL] coverage: $legs leg report(s) present but not one names a gate."
    echo "       A malformed report is an absent report."
    return 1
  fi

  local rc=0 g ran gap na nas=0
  echo "coverage across $legs leg report(s):"
  for g in $gates; do
    ran="$(awk -F'\t' -v g="$g" '$1==g && $2=="ran"' "$all" | grep -c . || true)"
    gap="$(awk -F'\t' -v g="$g" '$1==g && $2=="gap"' "$all" | grep -c . || true)"
    na="$(awk -F'\t' -v g="$g" '$1==g && $2=="na"' "$all" | grep -c . || true)"

    if [ "$ran" -eq 0 ] && [ "$na" -gt 0 ] && [ "$gap" -eq 0 ]; then
      # NOTHING TO AUDIT, SAID IN ITS OWN WORDS. Every leg found the tree declares nothing
      # this gate reads. Failing it would turn every repo without a lockfile red for having
      # no dependencies. Printing [ok] would turn an empty set into assurance.
      echo "  [n/a]  $g — nothing to examine on any of $na leg(s). Not a pass: nothing was checked."
      nas=$((nas+1))
    elif [ "$ran" -eq 0 ]; then
      # EVERY leg that reported on this gate gapped. Brian's rule.
      echo "  [FAIL] $g — NOT ONE leg ran it ($gap gap / $ran ran)."
      echo "         Nothing on this fleet examined it. A result nobody produced is not a pass."
      rc=1
    elif [ "$gap" -gt 0 ]; then
      echo "  [warn] $g — ran on $ran leg(s), gapped on $gap. Partial coverage, which is allowed."
    else
      echo "  [ok]   $g — ran on all $ran leg(s)."
    fi
  done

  rm -f "$all"
  if [ "$rc" = "0" ] && [ "$nas" -gt 0 ]; then
    echo "coverage OK — every gate was examined somewhere, except $nas with nothing to examine."
  elif [ "$rc" = "0" ]; then
    echo "coverage OK — every gate was examined somewhere."
  fi
  return "$rc"
}

# ---------------------------------------------------------------- selftest
selftest() {
  local pass=0 fail=0
  # NOT `local tmp` with a `trap ... EXIT`. The trap fires after this function has
  # returned, when a local is out of scope -- under `set -u` that made the trap itself
  # fail and a selftest reporting "10 passed, 0 failed" still exit 1. A gate cannot tell
  # that apart from a real failure.
  AC_TMP="$(mktemp -d "${TMPDIR:-/tmp}/audit_coverage.XXXXXX")" || { echo "audit_coverage: mktemp failed; stopping" >&2; exit 1; }
  trap 'rm -rf "${AC_TMP:-}"' EXIT
  local tmp="$AC_TMP"

  t() { # t <name> <expected-rc> <dir>
    local name="$1" want="$2" dir="$3" got=0
    check "$dir" >/dev/null 2>&1 || got=$?
    if [ "$got" = "$want" ]; then
      echo "  [PASS] $name (rc=$got)"; pass=$((pass+1))
    else
      echo "  [FAIL] $name — wanted rc=$want, got rc=$got"; fail=$((fail+1))
    fi
  }

  # --- THE BASELINE CONTROL, AND IT COMES FIRST.
  # A seeded red proves nothing unless the UNSEEDED case is green for the right reason.
  # Measured elsewhere on 2026-09-22: a seeding round whose baseline control was itself
  # failing proved nothing at all and had to be redone. So: the healthy fleet, asserted
  # green, before any case that asserts red.
  local d="$tmp/baseline"; mkdir -p "$d"
  emit shell_lint ran "$d/mac.tsv";   emit workflow_audit ran "$d/mac.tsv"
  emit shell_lint ran "$d/linux.tsv"; emit workflow_audit ran "$d/linux.tsv"
  t "baseline control: every leg ran every gate -> pass" 0 "$d"

  # --- today's real fleet: macOS has the binaries, Linux does not.
  d="$tmp/partial"; mkdir -p "$d"
  emit shell_lint ran "$d/mac.tsv";   emit workflow_audit ran "$d/mac.tsv"
  emit shell_lint gap "$d/linux.tsv"; emit workflow_audit gap "$d/linux.tsv"
  t "some legs gap, some ran -> warning, still passes" 0 "$d"

  # --- THE CASE THIS TOOL EXISTS FOR: the one provisioned box goes away.
  d="$tmp/allgap"; mkdir -p "$d"
  emit shell_lint gap "$d/mac.tsv";   emit workflow_audit gap "$d/mac.tsv"
  emit shell_lint gap "$d/linux.tsv"; emit workflow_audit gap "$d/linux.tsv"
  t "EVERY leg gapped both gates -> FAILURE" 1 "$d"

  # --- one gate covered, the other not. Must fail on the uncovered one alone.
  d="$tmp/mixed"; mkdir -p "$d"
  emit shell_lint ran "$d/mac.tsv";   emit workflow_audit gap "$d/mac.tsv"
  emit shell_lint ran "$d/linux.tsv"; emit workflow_audit gap "$d/linux.tsv"
  t "one gate ran everywhere, the other nowhere -> FAILURE" 1 "$d"

  # --- a single-leg fleet that gapped. One leg is still EVERY leg.
  d="$tmp/single"; mkdir -p "$d"
  emit shell_lint gap "$d/only.tsv"; emit workflow_audit gap "$d/only.tsv"
  t "single leg, gapped -> FAILURE (one leg is still every leg)" 1 "$d"

  d="$tmp/singleok"; mkdir -p "$d"
  emit shell_lint ran "$d/only.tsv"; emit workflow_audit ran "$d/only.tsv"
  t "single leg, ran -> pass" 0 "$d"

  # --- the absences. Each must be a failure, never a quiet pass.
  t "no report directory at all -> FAILURE" 1 "$tmp/does-not-exist"

  d="$tmp/empty"; mkdir -p "$d"
  t "report directory present but empty -> FAILURE" 1 "$d"

  d="$tmp/garbage"; mkdir -p "$d"; printf 'not a report\n' > "$d/junk.tsv"
  t "reports present but naming no gate -> FAILURE" 1 "$d"

  # --- THE INSTRUMENT MUST BE ABLE TO FAIL. Flip the rule and the all-gap case must
  # stop being red; if it stays red either way, the assertion is measuring nothing.
  local inverted=0
  (
    cat "$tmp/allgap"/*.tsv | awk -F'\t' '$2=="ran"' | grep -q . 
  ) && inverted=1
  if [ "$inverted" = "0" ]; then
    echo "  [PASS] the all-gap fixture genuinely contains no 'ran' (the red has the stated cause)"
    pass=$((pass+1))
  else
    echo "  [FAIL] the all-gap fixture contains a 'ran' — its red would have another cause"
    fail=$((fail+1))
  fi

  # ---- the jobs-API converter, against the REAL payload shape.
  # Recorded from /actions/runs/35770143924/jobs, which is the run that proved the gate
  # step's own conclusion is useless here: the Linux leg GAPPED the workflow audit and its
  # "Audit the workflows themselves" step still reported `success`.
  local jd="$tmp/jobs"; mkdir -p "$jd"
  cat > "$jd/mixed.json" <<'JEOF'
{"jobs":[
 {"name":"scaffold-check (self-hosted, macOS)","steps":[
   {"name":"Audit the workflows themselves","conclusion":"success"},
   {"name":"coverage:shell_lint=ran","conclusion":"success"},
   {"name":"coverage:workflow_audit=ran","conclusion":"success"}]},
 {"name":"scaffold-check (self-hosted, Linux)","steps":[
   {"name":"Audit the workflows themselves","conclusion":"success"},
   {"name":"coverage:shell_lint=ran","conclusion":"skipped"},
   {"name":"coverage:workflow_audit=ran","conclusion":"skipped"}]},
 {"name":"scaffold-check-complete","steps":[
   {"name":"Every runner passed","conclusion":"success"}]}
]}
JEOF
  from_jobs "$jd/mixed.json" "$jd/out" >/dev/null 2>&1 || true
  t "from-jobs: macOS ran, Linux gapped -> partial coverage passes" 0 "$jd/out"

  local nlegs
  nlegs="$(find "$jd/out" -name '*.tsv' | grep -c . || true)"
  if [ "$nlegs" = "2" ]; then
    echo "  [PASS] from-jobs counts 2 legs, not 3 (the aggregating job is not a leg)"
    pass=$((pass+1))
  else
    echo "  [FAIL] from-jobs derived $nlegs leg(s); the aggregating job must not count as one"
    fail=$((fail+1))
  fi

  cat > "$jd/allgap.json" <<'JEOF'
{"jobs":[
 {"name":"leg-a","steps":[
   {"name":"Audit the workflows themselves","conclusion":"success"},
   {"name":"coverage:shell_lint=ran","conclusion":"skipped"},
   {"name":"coverage:workflow_audit=ran","conclusion":"skipped"}]},
 {"name":"leg-b","steps":[
   {"name":"coverage:shell_lint=ran","conclusion":"skipped"},
   {"name":"coverage:workflow_audit=ran","conclusion":"skipped"}]}
]}
JEOF
  from_jobs "$jd/allgap.json" "$jd/out2" >/dev/null 2>&1 || true
  t "from-jobs: the provisioned runner is gone, every leg skipped -> FAILURE" 1 "$jd/out2"

  # A run where no leg carries markers at all -- an old workflow, or every leg cancelled
  # before reaching them. Deriving zero legs must fail, not pass.
  cat > "$jd/nomarkers.json" <<'JEOF'
{"jobs":[{"name":"leg-a","steps":[{"name":"Lint this scaffold's own shell","conclusion":"success"}]}]}
JEOF
  from_jobs "$jd/nomarkers.json" "$jd/out3" >/dev/null 2>&1 || true
  t "from-jobs: no leg carries a coverage marker -> FAILURE" 1 "$jd/out3"

  # ---- --settled: has GitHub finished publishing the legs' steps?
  # The unsettled shapes are both recorded from a real run (product-tracker 35874737948): a
  # leg `completed/success` with an EMPTY steps list, and one whose steps still read
  # `pending`. Either one gives from-jobs nothing to read.
  st() {   # st <label> <want exit> <json>
    local got=0
    printf '%s' "$3" > "$jd/s.json"
    settled "$jd/s.json" >/dev/null 2>&1 || got=$?
    if [ "$got" = "$2" ]; then echo "  [PASS] $1"; pass=$((pass+1))
    else echo "  [FAIL] $1 (exit $got, want $2)"; fail=$((fail+1)); fi
  }
  st "settled: every finished leg lists completed steps" 0 \
     '{"jobs":[{"name":"leg","status":"completed","conclusion":"success","steps":[{"name":"x","status":"completed","conclusion":"success"}]},{"name":"agg","status":"in_progress","conclusion":null,"steps":[]}]}'
  st "settled: a finished leg with NO steps yet is not settled" 1 \
     '{"jobs":[{"name":"leg","status":"completed","conclusion":"success","steps":[]}]}'
  st "settled: a finished leg whose steps read pending is not settled" 1 \
     '{"jobs":[{"name":"leg","status":"completed","conclusion":"success","steps":[{"name":"x","status":"pending","conclusion":null}]}]}'
  st "settled: a SKIPPED leg has no steps to wait for" 0 \
     '{"jobs":[{"name":"leg","status":"completed","conclusion":"skipped","steps":[]}]}'
  # "Re-run failed jobs", recorded 2026-09-30 (product-tracker 36726227312): the default
  # jobs listing held ONLY the aggregating job, so there was no leg to wait for, --settled
  # said yes at once, and the run failed with 0 legs. No leg listed is not settled.
  st "settled: NO leg listed at all is not settled (re-run failed jobs)" 1 \
     '{"jobs":[{"name":"agg","status":"in_progress","conclusion":null,"steps":[]}]}'

  # ---- ?filter=all lists every attempt. Only each job's LATEST attempt may count, or a
  # full re-run whose leg gapped would borrow "ran" from the attempt before it.
  cat > "$jd/attempts.json" <<'JEOF'
{"jobs":[
 {"name":"leg-a","run_attempt":1,"status":"completed","conclusion":"success","steps":[
   {"name":"coverage:shell_lint=ran","status":"completed","conclusion":"success"}]},
 {"name":"leg-a","run_attempt":2,"status":"completed","conclusion":"success","steps":[
   {"name":"coverage:shell_lint=ran","status":"completed","conclusion":"skipped"}]}
]}
JEOF
  from_jobs "$jd/attempts.json" "$jd/atto" >/dev/null 2>&1 || true
  t "from-jobs: only the latest attempt of a leg counts (attempt 2 gapped) -> FAILURE" 1 "$jd/atto"
  st "settled: an older attempt's steps do not settle a newer attempt with none" 1 \
     '{"jobs":[{"name":"leg-a","run_attempt":1,"status":"completed","conclusion":"success","steps":[{"name":"x","status":"completed","conclusion":"success"}]},{"name":"leg-a","run_attempt":2,"status":"completed","conclusion":"success","steps":[]}]}'

  # ---- --from-outputs: the legs' JOB OUTPUTS, which need no jobs-API listing at all.
  fo() {   # fo <label> <want exit> <expected legs> <outputs json> [check want]
    local got=0 od="$jd/fo.$pass.$fail"
    printf '%s' "$4" > "$jd/fo.json"
    from_outputs "$jd/fo.json" "$od" "$3" >/dev/null 2>&1 || got=$?
    if [ "$got" = "$2" ]; then echo "  [PASS] $1"; pass=$((pass+1))
    else echo "  [FAIL] $1 (exit $got, want $2)"; fail=$((fail+1)); fi
    [ -z "${5:-}" ] || t "$1 -> check" "$5" "$od"
  }
  fo "from-outputs: two legs, both reported, mixed coverage" 0 2 \
     '{"cov_0":"shell_lint=ran,workflow_audit=ran,dependency_audit=na","cov_1":"shell_lint=gap,workflow_audit=gap,dependency_audit=na","cov_2":""}' 0
  fo "from-outputs: two legs, both reported, every gate gapped" 0 2 \
     '{"cov_0":"shell_lint=gap,workflow_audit=gap","cov_1":"shell_lint=gap,workflow_audit=gap"}' 1
  fo "from-outputs: a leg that never reported is INCOMPLETE, not a pass" 3 2 \
     '{"cov_0":"shell_lint=ran,workflow_audit=ran","cov_1":""}'
  fo "from-outputs: no outputs at all is INCOMPLETE" 3 1 'null'
  fo "from-outputs: an unknown state is refused, not read as coverage" 2 1 \
     '{"cov_0":"shell_lint=yes"}'

  # ---- NOT APPLICABLE: a third state, and the one that must not become a pass or a fail.
  local nd="$tmp/na"; mkdir -p "$nd/all" "$nd/mixgap" "$nd/mixran"
  printf 'shell_lint\tran\ndependency_audit\tna\n' > "$nd/all/leg-1.tsv"
  printf 'shell_lint\tran\ndependency_audit\tna\n' > "$nd/all/leg-2.tsv"
  t "n/a: every leg found nothing to audit -> not a failure" 0 "$nd/all"
  local nout; nout="$(check "$nd/all" 2>&1 || true)"
  if printf '%s' "$nout" | grep -qF "[n/a]  dependency_audit" \
     && printf '%s' "$nout" | grep -qF "Not a pass: nothing was checked" \
     && ! printf '%s' "$nout" | grep -qF "every gate was examined somewhere."; then
    echo "  [PASS] n/a prints as n/a and says it is not a pass"; pass=$((pass+1))
  else
    echo "  [FAIL] n/a did not print as its own state"; fail=$((fail+1))
  fi
  printf 'dependency_audit\tna\n' > "$nd/mixgap/leg-1.tsv"
  printf 'dependency_audit\tgap\n' > "$nd/mixgap/leg-2.tsv"
  t "n/a on one leg, gap on the other, ran on none -> FAILURE" 1 "$nd/mixgap"
  printf 'dependency_audit\tgap\n' > "$nd/mixran/leg-1.tsv"
  printf 'dependency_audit\tgap\n' > "$nd/mixran/leg-2.tsv"
  t "n/a absent, every leg gapped (lockfile, no scanner) -> FAILURE" 1 "$nd/mixran"

  cat > "$jd/na.json" <<'JEOF'
{"jobs":[
 {"name":"leg-a","steps":[
   {"name":"coverage:shell_lint=ran","conclusion":"success"},
   {"name":"coverage:dependency_audit=ran","conclusion":"skipped"},
   {"name":"coverage:dependency_audit=na","conclusion":"success"}]},
 {"name":"leg-b","steps":[
   {"name":"coverage:shell_lint=ran","conclusion":"success"},
   {"name":"coverage:dependency_audit=ran","conclusion":"skipped"},
   {"name":"coverage:dependency_audit=na","conclusion":"success"}]}
]}
JEOF
  from_jobs "$jd/na.json" "$jd/nao" >/dev/null 2>&1 || true
  t "from-jobs: =na succeeded on every leg -> not a failure" 0 "$jd/nao"
  cat > "$jd/nagap.json" <<'JEOF'
{"jobs":[
 {"name":"leg-a","steps":[
   {"name":"coverage:dependency_audit=ran","conclusion":"skipped"},
   {"name":"coverage:dependency_audit=na","conclusion":"skipped"}]}
]}
JEOF
  from_jobs "$jd/nagap.json" "$jd/nagapo" >/dev/null 2>&1 || true
  t "from-jobs: both markers skipped (lockfile, no scanner) -> FAILURE" 1 "$jd/nagapo"

  echo "audit_coverage.sh selftest: $pass passed, $fail failed"
  [ "$fail" -eq 0 ]
}

# Turn a GitHub `/actions/runs/{id}/jobs` payload into the leg reports `check` reads.
#
# IT LIVES HERE, NOT IN THE YAML, so it can be tested against a recorded payload. The
# parsing is the part most likely to be quietly wrong -- a renamed step or a changed
# conclusion string would otherwise make every gate look covered with nothing to say so.
#
# THE MARKER STEP IS THE SIGNAL. A leg runs `coverage:<gate>=ran` only when that gate
# produced a verdict, so the step is `success` when it ran and `skipped` when it gapped.
# The GATE step's own conclusion cannot be used: exit 3 prints a ::warning:: and a warning
# is still a successful step.
# Has GitHub finished publishing every finished leg's steps? Exit 0 yes, 1 not yet.
#
# A job's `completed` status arrives BEFORE its step list does. The aggregating job starts
# the moment its `needs:` are met, so its first read can find a green leg with `steps: []`,
# and from_jobs, correctly, derives nothing from that. Only legs that actually ran are
# waited for. Skipped and cancelled legs may never list steps, and the aggregating job is
# still in_progress while it reads.
settled() {
  local json="${1:-}"
  [ -f "$json" ] || { echo "[FAIL] no jobs payload at '$json'" >&2; return 2; }
  JOBS_JSON="$json" python3 - <<'PYEOF'
import json, os, sys
jobs = json.load(open(os.environ["JOBS_JSON"])).get("jobs") or []
# ?filter=all lists every attempt of a re-run. Keep each job's LATEST attempt only.
_latest = {}
for _j in jobs:
    _k = _j.get("name") or "?"
    if _k not in _latest or (_j.get("run_attempt") or 0) >= (_latest[_k].get("run_attempt") or 0):
        _latest[_k] = _j
jobs = list(_latest.values())
# NO LEG LISTED IS NOT SETTLED. On "Re-run failed jobs" the default listing held only the
# aggregating job, still in progress, so nothing was waited for and 0 legs were read.
if not any(j.get("status") == "completed" for j in jobs):
    print("no finished leg is listed yet")
    sys.exit(1)
waiting = []
for j in jobs:
    if j.get("status") != "completed" or j.get("conclusion") not in ("success", "failure"):
        continue
    steps = j.get("steps") or []
    if not steps or any(s.get("status") != "completed" for s in steps):
        waiting.append(j.get("name") or "?")
if waiting:
    print("steps not yet published for: " + ", ".join(waiting))
    sys.exit(1)
PYEOF
}

from_jobs() {
  local json="${1:-}" outdir="${2:-}"
  [ -n "$json" ] && [ -n "$outdir" ] || {
    echo "usage: audit_coverage.sh --from-jobs <jobs.json> <outdir>" >&2; exit 2; }
  [ -f "$json" ] || { echo "[FAIL] no jobs payload at '$json'" >&2; return 1; }
  mkdir -p "$outdir"
  JOBS_JSON="$json" OUTDIR="$outdir" python3 - <<'PYEOF'
import json, os, re, sys
payload = json.load(open(os.environ["JOBS_JSON"]))
jobs = payload.get("jobs") or []
# ?filter=all lists every attempt of a re-run. Keep each job's LATEST attempt only.
_latest = {}
for _j in jobs:
    _k = _j.get("name") or "?"
    if _k not in _latest or (_j.get("run_attempt") or 0) >= (_latest[_k].get("run_attempt") or 0):
        _latest[_k] = _j
jobs = list(_latest.values())
n = 0
for j in jobs:
    # Only the matrix legs carry coverage markers. The aggregating job has none, and
    # counting it as a leg would invent a leg that audited nothing.
    rows = []
    for st in (j.get("steps") or []):
        m = re.match(r"^coverage:([A-Za-z0-9_]+)=(ran|na)$", (st.get("name") or "").strip())
        if not m:
            continue
        gate = m.group(1)
        # success -> the gate produced a verdict here. Anything else (skipped, and also
        # cancelled or failed, which mean this leg never got to say) is NOT coverage.
        if m.group(2) == "na":
            # The =na marker runs only on a leg that found nothing to examine. Skipped means
            # the leg did not say so, and its =ran marker carries whatever it did instead.
            if st.get("conclusion") == "success":
                rows.append((gate, "na"))
            continue
        rows.append((gate, "ran" if st.get("conclusion") == "success" else "gap"))
    # A leg that said n/a for a gate SKIPPED that gate's =ran marker, which reads as a gap.
    # It is not one: the leg answered, and its answer was "nothing to examine".
    na_gates = {g for g, st_ in rows if st_ == "na"}
    rows = [(g, st_) for g, st_ in rows if not (g in na_gates and st_ == "gap")]
    if not rows:
        continue
    n += 1
    with open(os.path.join(os.environ["OUTDIR"], "leg-%d.tsv" % n), "w") as fh:
        for gate, state in rows:
            fh.write("%s\t%s\n" % (gate, state))
print("derived %d leg report(s) from %d job(s)" % (n, len(jobs)))
PYEOF
}

# Turn the legs' JOB OUTPUTS into leg reports. Exit 0 every expected leg reported, 3 one or
# more did not (the caller falls back to the jobs API), 2 a malformed value.
#
# THIS IS THE PRIMARY CHANNEL FROM 0.111.11. The jobs API publishes a leg's steps late -- on
# 2026-09-30 more than 100s late on both platforms, and over 30 minutes once -- and after
# "Re-run failed jobs" it does not list the legs at all. `needs.<job>.outputs` is handed
# to this job by the runner itself: no listing, no wait, no quota. Each leg writes
# cov_<strategy.job-index>; a matrix merges every leg's distinct output names.
from_outputs() {
  local json="${1:-}" outdir="${2:-}" expected="${3:-}"
  [ -n "$json" ] && [ -n "$outdir" ] && [ -n "$expected" ] || {
    echo "usage: audit_coverage.sh --from-outputs <outputs.json> <outdir> <expected legs>" >&2; exit 2; }
  [ -f "$json" ] || { echo "[FAIL] no outputs payload at '$json'" >&2; return 2; }
  mkdir -p "$outdir"
  OUT_JSON="$json" OUTDIR="$outdir" EXPECTED="$expected" python3 - <<'PYEOF'
import json, os, re, sys
outs = json.load(open(os.environ["OUT_JSON"])) or {}
expected = int(os.environ["EXPECTED"])
legs = []
for key in sorted(k for k in outs if re.match(r"^cov_[0-9]+$", k)):
    val = (outs.get(key) or "").strip()
    if not val:
        continue
    rows = []
    for tok in val.split(","):
        m = re.match(r"^([A-Za-z0-9_]+)=(ran|gap|na)$", tok.strip())
        if not m:
            print("[FAIL] %s: '%s' is not <gate>=ran|gap|na" % (key, tok), file=sys.stderr)
            sys.exit(2)
        rows.append((m.group(1), m.group(2)))
    legs.append(rows)
for i, rows in enumerate(legs, 1):
    with open(os.path.join(os.environ["OUTDIR"], "leg-%d.tsv" % i), "w") as fh:
        for gate, state in rows:
            fh.write("%s\t%s\n" % (gate, state))
print("derived %d leg report(s) from job outputs; %d leg(s) expected" % (len(legs), expected))
sys.exit(0 if len(legs) >= expected else 3)
PYEOF
}

case "${1:---help}" in
  --check)     shift; check "${1:-}" ;;
  --emit)      shift; emit "${1:-}" "${2:-}" "${3:-}" ;;
  --from-jobs) shift; from_jobs "${1:-}" "${2:-}" ;;
  --settled)   shift; settled "${1:-}" ;;
  --from-outputs) shift; from_outputs "${1:-}" "${2:-}" "${3:-}" ;;
  --selftest)  selftest ;;
  *) echo "usage: audit_coverage.sh [--check <dir> | --from-jobs <jobs.json> <outdir> | --settled <jobs.json> | --from-outputs <outputs.json> <outdir> <n> | --emit <gate> <ran|gap> <file> | --selftest]" >&2; exit 2 ;;
esac
