#!/usr/bin/env bash
# Project:  ai-project-scaffold
# File:     tools/conflict_scan.sh
# Modified: 2026-09-23
# Version:  0.3.1.20260923.0941
# Purpose:  Fail the build when an unfinished upgrade is committed — conflict markers, or the
#           `.scaffold-<version>` sidecars a divergent PRODUCT file leaves behind.
# Changelog:
#   2026-09-23 v0.3.1.20260923.0941 — fixtures run inside the root tools/fixture_guard.sh validates. There a git and a mktemp on PATH refuse anything that would land outside it. Every mktemp takes a ${TMPDIR} template, because macOS mktemp ignores TMPDIR without one.
#   2026-08-14 v0.3.0.20260814.2100 — `scaffold:not-a-conflict` reports its count, at every value including
#                        zero. A run that suppressed six regions and a run with nothing to
#                        suppress printed the identical verdict.
#                        THE FIRST VERSION OF THIS COUNTER REPORTED 0 FOREVER. It passed the
#                        log path to awk through `-v`, and macOS's one-true-awk coerces a
#                        value beginning with `/` to the NUMBER -inf — so the redirect wrote
#                        nowhere, on the platform this project develops on. ENVIRON[] instead.
#                        Caught only because a selftest asserted a NUMBER; a case asserting
#                        that the line exists would have passed throughout.
#   2026-08-12 v0.2.1 — The sidecar check now requires TRACKED **and still on disk**.
#                        `git ls-files` reads the INDEX, so a sidecar just deleted and not
#                        yet staged still listed, and the tool failed the person in the
#                        middle of doing exactly what it asked for. Hit for real while
#                        reconciling localcoder's three: reconcile, rm, re-run, still red,
#                        with no hint that staging was the missing step. A guard that fires
#                        on its own remedy is one people route around.
#   2026-08-12 v0.2.0 — THE SIDECAR HALF, which had been invisible since 0.10.0 shipped it.
#                        An upgrade that cannot overwrite an edited PRODUCT file keeps the
#                        local one and drops the incoming version at `<file>.scaffold-<TO>`,
#                        printing an instruction to reconcile them. That instruction was the
#                        entire mechanism — the identical mistake this file was written to
#                        fix for conflict markers, one file class later.
#                        FOUND IN THE SIBLING localcoder REPO: three sidecars from the 0.29.4
#                        upgrade, tracked since 2026-08-09. One was scaffold-check.yml, and
#                        the cost was real — localcoder's copy carries a deliberate local edit
#                        and the scaffold's had since grown a check that catches silently
#                        retired test suites. Neither side was wrong; the merge was simply
#                        never finished, and nothing could say so.
#                        TRACKED IS THE SIGNAL. A sidecar the upgrade just wrote is untracked
#                        and correct; failing on it would fail the run that produced it.
#   2026-08-08 v0.1.0 — New. `scaffold_upgrade.sh` performs three-way merges on MERGE-class
#                        files and, when a hunk conflicts, writes ordinary git conflict
#                        markers into the adopter's file and TELLS THEM TO RESOLVE IT. That
#                        instruction was the entire mechanism: nothing ever checked that it
#                        happened.
#                        Measured, in this project's own dev repo: the 0.14.0 upgrade left
#                        `<<<<<<< yours` / `>>>>>>> scaffold 0.14.0` in ai/STANDARDS.md, the
#                        file every agent reads FIRST at session start. It was committed, it
#                        survived the 0.14.1 upgrade layered on top of it, and it passed
#                        every CI run in between. The one place the string was checked was
#                        scaffold_upgrade.sh's OWN selftest, asserting that the clean path
#                        writes no markers — a check aimed at the case that was never the
#                        risk, which this repo has now shipped four times.
#                        This is the class ai/MEMORY.md names: a rule with no checker behind
#                        it is not a rule. The upgrade tool's printed instruction was that
#                        rule; this file is the checker.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# A HUMAN ALREADY RULED ON THIS REGION. Documentation that DEMONSTRATES a conflict — a
# tutorial, a changelog quoting what an upgrade wrote — contains real markers at column 0 on
# purpose. The same argument as `scaffold:not-a-secret` in tools/secret_scan.sh applies: a
# prohibition with no sanctioned path gets worked around, and the workarounds available here
# are all worse (excluding docs/ wholesale is a hole; indenting the example corrupts it).
#
# LINE-SCOPED BY CONSTRUCTION, and accepted on ANY of the three marker lines so the example
# can carry it wherever it is least disruptive — usually the closer. It clears exactly the
# one region it sits in, never the file.
MARK='scaffold:not-a-conflict'

# THE PREFILTER IS ONE PROCESS FOR THE WHOLE TREE, AND THAT IS A SCALE PROPERTY.
# The obvious shape — walk `git ls-files -z` and grep each file — costs two processes per
# tracked file. Measured on a synthetic 5,000-file repo, that shape takes ~20s; the CI job
# it would run in budgets 5 minutes for everything. A 50k-file monorepo would spend the
# whole budget deciding it had nothing to report. `git grep` searches the tracked working
# tree in a single process, so the walk below only ever visits the handful of files that
# already look suspicious — and in the normal case, none.
#
# THE PREFILTER IS DELIBERATELY BROADER THAN THE VERDICT, and that direction is the safety
# argument. It matches any line STARTING with a marker run; the verdict below then decides
# whether those lines form a real region. A prefilter that is a strict superset can only
# ever cost time, never a detection. Narrowing it to "look like a real conflict" would put
# the real decision in two places, and the file whose regex drifts silently reports success
# for work it did not do.
PREFILTER='^(<<<<<<<|=======|>>>>>>>|\|\|\|\|\|\|\|)'

# -I skips binary files: a .png whose bytes happen to start a line with '=======' is not a
# conflict, and printing its contents as a finding is how a checker gets switched off.
candidates() {
  git grep -I -l -z -E "$PREFILTER" -- . 2>/dev/null || true
}

# Prints the unadjudicated conflict regions in $1. Empty output = file is clean.
#
# A REGION IS AN OPENER AND ITS CLOSER, NOT A LONE '======='. Markdown's setext heading
# underlines a title with '=' at column 0, so a rule that fired on the separator alone would
# fail on ordinary prose — including this repo's own docs. Requiring the pair means the
# check cannot be provoked by anything a human writes by hand.
#
# AN UNTERMINATED OPENER STILL COUNTS. A half-resolved conflict — someone deleted the
# '>>>>>>>' line and stopped — leaves the file broken in exactly the way this exists to
# catch, and '<<<<<<<' at column 0 does not otherwise occur in text.
# THE SUPPRESSION REPORTS ITS COUNT (design review 2026-08-14). `scaffold:not-a-conflict` is a
# human declaration that turns this check off for one region, and until now a run that
# suppressed six regions and a run with nothing to suppress printed the identical verdict.
# Zero is the interesting value in both directions: `0 adjudicated` on a clean tree means the
# tree is clean, and a nonzero count on a clean tree means somebody is standing on the check.
#
# THE COUNT GOES TO A FILE. conflict_regions is called inside `$( )`, a subshell, so a global
# counter would report 0 forever while looking correct — the same trap secret_scan.sh's
# counting hit, and the reason both are written this way.
CONFLICT_SUPPRESS_LOG=""

conflict_regions() {
# A PATH CANNOT REACH awk THROUGH -v ON macOS. Measured 2026-08-14 on one-true-awk
# (version 20200816, the awk every macOS ships): `awk -v log=/tmp/l2` arrives inside the
# program as the NUMBER -inf, because a value beginning with `/` is coerced numerically
# before the program runs. Quoting does not help; the damage is done by -v itself.
#
# The failure mode is the worst available for a counter: the redirect silently writes
# nowhere, the count reads 0 on every run, and 0 is a legitimate value — so it looks exactly
# like a tree with nothing suppressed. This shipped in the FIRST version of this counting and
# was caught only because a selftest asserted a NUMBER rather than the presence of a line.
# ENVIRON[] is read at run time and is not touched by -v's escape and coercion pass.
  CFS_LOG="$CONFLICT_SUPPRESS_LOG" awk -v mark="$MARK" '
    /^<<<<<<</            { open = NR; otext = $0; adj = (index($0, mark) > 0); next }
    open && /^=======/    { if (index($0, mark) > 0) adj = 1; next }
    open && /^\|\|\|\|\|\|\|/ { if (index($0, mark) > 0) adj = 1; next }
    open && /^>>>>>>>/    {
                            if (index($0, mark) > 0) adj = 1
                            if (adj) suppressed++
                            if (!adj) printf "  lines %d-%d: %s\n", open, NR, otext
                            open = 0; adj = 0; next
                          }
    END                   {
                            if (open && adj) suppressed++
                            if (open && !adj) printf "  line %d: %s (never closed)\n", open, otext
                            if (ENVIRON["CFS_LOG"] != "" && suppressed > 0)
                              printf "%d\n", suppressed >> ENVIRON["CFS_LOG"]
                          }
  ' "$1" 2>/dev/null
}

# THE OTHER HALF OF AN UNFINISHED UPGRADE, and it has been invisible the whole time.
#
# When scaffold_upgrade.sh cannot reconcile a file it does one of two things. On a MERGE-class
# file it writes conflict markers — caught above, which is why this tool exists. On a PRODUCT
# file the adopter has edited it does something quieter: it KEEPS the local file and drops the
# incoming one alongside as `<file>.scaffold-<TO>`, printing an instruction to reconcile them.
# That instruction is the entire mechanism, exactly as the marker instruction was, and nothing
# checked that it happened either. Same defect, one file type later.
#
# TRACKED IS THE SIGNAL, NOT PRESENT. A sidecar that an upgrade just wrote is untracked and
# completely correct — it is the reconciliation waiting to be done. Once it is COMMITTED the
# reconciliation stopped, and a committed sidecar is invisible: it is not in any diff anyone
# reads again, it breaks no build, and it looks like an ordinary file in `ls`.
#
# MEASURED, in the sibling `localcoder` repo, on 2026-08-12: three sidecars from the 0.29.4
# upgrade tracked since 2026-08-09 — .github/CONTRIBUTING.md, docs/benchmarks/README.md and
# .github/workflows/scaffold-check.yml. The workflow one mattered. localcoder's copy carries a
# deliberate local edit (its selftest loop scans src/localcoder/, which IS the product) and the
# scaffold's copy had since grown an executable-bit check that catches silently-retired test
# suites. Neither side was wrong; the merge was simply never finished, so localcoder ran three
# days without a check it had already paid for, with the answer sitting in the repo the whole
# time under a filename nobody greps.
#
# `.scaffold-version` IS NOT ONE OF THESE. It is the base stamp the three-way merge needs, and
# it must stay tracked. The suffix below requires a full MAJOR.MINOR.PATCH.YYYYMMDD.HHMM, which
# it does not have — excluded by shape rather than by a name in a list that would drift.
SIDECAR_RE='\.scaffold-[0-9]+\.[0-9]+\.[0-9]+\.[0-9]{8}\.[0-9]{4}$'

# TRACKED **AND STILL ON DISK**. `git ls-files` reads the INDEX, so a sidecar you have just
# deleted and not yet staged still lists — and the tool then fails the person in the middle of
# doing exactly what it asked for. Hit while reconciling localcoder's three on 2026-08-12:
# reconcile, `rm`, re-run, still red, with no hint that staging was the missing step. A guard
# that fires on the remedy is one people route around.
#
# Deleted-in-worktree-but-still-in-HEAD therefore PASSES. That is the right answer: this scans
# what you would push, and the next commit carries the deletion.
tracked_sidecars() {
  git ls-files -z 2>/dev/null | tr '\0' '\n' | grep -E "$SIDECAR_RE" | while IFS= read -r f; do
    [ -e "$f" ] && printf '%s\n' "$f"
  done
  return 0
}

# ALWAYS PRINTED, INCLUDING ZERO, AND BEFORE THE VERDICT ON BOTH PATHS. The case this is for
# is a GREEN run: "No conflict markers" is the same sentence whether none existed or every one
# of them carried an adjudication marker.
conflict_suppression_report() {
  local n=0
  if [ -n "$CONFLICT_SUPPRESS_LOG" ] && [ -f "$CONFLICT_SUPPRESS_LOG" ]; then
    n="$(awk '{t+=$1} END {printf "%d", t}' "$CONFLICT_SUPPRESS_LOG" 2>/dev/null)"
    rm -f "$CONFLICT_SUPPRESS_LOG"
  fi
  n="${n:-0}"
  echo "Suppressed $n conflict region(s) declared scaffold:not-a-conflict."
  if [ "$n" -gt 0 ]; then
    echo "  Each is a standing decision that a <<<<<<< region is intentional text."
    echo "  List them:  grep -rn 'scaffold:not-a-conflict' \$(git ls-files)"
  fi
}

scan() {
  local failed="" f regions sidecars
  CONFLICT_SUPPRESS_LOG="$(mktemp "${TMPDIR:-/tmp}/conflict_scan.XXXXXX")" || CONFLICT_SUPPRESS_LOG=""
  if ! git rev-parse --git-dir >/dev/null 2>&1; then
    echo "Not a git repository — nothing to scan."
    return 0
  fi
  # NUL-DELIMITED END TO END. tools/secret_scan.sh shipped a newline-joined list walked with
  # `for f in $hits`, and a tracked file named `app/my config.py` split into two paths that
  # do not exist, so it was reported clean. Same defect, same cost, so the same shape here.
  while IFS= read -r -d "" f; do
    [ -f "$f" ] || continue
    regions="$(conflict_regions "$f")"
    if [ -n "$regions" ]; then
      failed="yes"
      echo "$f:"
      printf '%s\n' "$regions"
    fi
  done < <(candidates)

  conflict_suppression_report
  if [ -n "$failed" ]; then
    echo "::error::Unresolved merge-conflict markers are committed."
    echo ""
    echo "These arrive from a three-way merge — usually './setup.sh --upgrade' on a"
    echo "MERGE-class file such as ai/STANDARDS.md. Open each file, keep what belongs"
    echo "from BOTH sides, and delete the <<<<<<< ======= >>>>>>> lines."
    echo ""
    echo "If a region is a deliberate EXAMPLE of a conflict, mark any one of its three"
    echo "marker lines and re-run:"
    echo "    >>>>>>> theirs   $MARK"
    return 1
  fi

  # BOTH SCANS REPORT BEFORE EITHER DECIDES. Returning at the first failure above would hide
  # the sidecars behind the markers, which is the same "one failure at a time" shape preflight
  # exists to prevent. The markers block is kept intact for that reason and this runs after it.
  sidecars="$(tracked_sidecars)"
  if [ -n "$sidecars" ]; then
    echo "::error::Unreconciled upgrade sidecars are committed."
    printf '%s\n' "$sidecars" | sed 's/^/  /'
    echo ""
    echo "An upgrade could not overwrite these files because you had edited them, so it"
    echo "kept yours and left the incoming version alongside for you to reconcile. Being"
    echo "TRACKED means that never happened — and a committed sidecar is invisible: it is"
    echo "in no diff, breaks no build, and reads as an ordinary file."
    echo ""
    echo "For each one: diff it against the file it shadows, fold in what the scaffold"
    echo "added, keep your own edits, then 'git rm' the sidecar."
    echo "    diff <sidecar> <the file without the .scaffold-... suffix>"
    return 1
  fi

  echo "No conflict markers or unreconciled upgrade sidecars in the tracked tree."
  return 0
}

selftest() {
  # PROVE IT FAILS WHAT IT SHOULD. Case 1 is the real defect: the exact bytes 0.14.0 wrote
  # into ai/STANDARDS.md and that then survived a second upgrade and every CI run.
  local T fails=0 out got
  # FIXTURES RUN INSIDE A GUARDED ROOT (tools/fixture_guard.sh). Later mktemps land inside it,
  # and a git on PATH refuses any write outside it. The guard exists because a failed mktemp
  # once let a selftest run git init and commit in the real repo.
  . "$(dirname "${BASH_SOURCE[0]}")/fixture_guard.sh" || { echo "conflict_scan: tools/fixture_guard.sh is missing; refusing to build fixtures" >&2; exit 1; }
  fixture_root FG_ROOT; trap fg_cleanup EXIT
  T="$(mktemp -d "${TMPDIR:-/tmp}/conflict_scan.XXXXXX")" || return 1
  local SELF_ABS="$ROOT/tools/conflict_scan.sh"

  case_run() {  # case_run <label> <expected-exit> <setup-fn>
    local label="$1" want="$2" setup="$3" R="$T/case"
    rm -rf "$R"; mkdir -p "$R/ai"
    ( cd "$R" && git init -q . && git config user.email a@b.c && git config user.name t )
    printf '# Standards\n' > "$R/ai/STANDARDS.md"
    ( cd "$R" && $setup )
    ( cd "$R" && git add -A >/dev/null 2>&1 )
    out="$( cd "$R" && bash "$SELF_ABS" 2>&1 )"; got=$?
    if [ "$got" = "$want" ]; then printf '  ok   %-56s\n' "$label"
    else
      printf '  FAIL %-56s want exit %s, got %s\n' "$label" "$want" "$got"
      printf '%s\n' "$out" | sed 's/^/         /' | head -6
      fails=$((fails + 1))
    fi
  }

  # THE REAL ONE, BYTE FOR BYTE.
  c_the_defect() {
    printf '# Standards\n<<<<<<< yours\n<!-- scaffold:ceilings MEMORY.md=250/350 -->\n=======\n<!-- scaffold:ceilings MEMORY.md=250 -->\n>>>>>>> scaffold 0.14.0.20260808.1910\n' > ai/STANDARDS.md
  }
  c_clean()        { printf '# Standards\nnothing to see\n' > ai/STANDARDS.md; }
  # SETEXT: the false positive that would make this check unusable on prose.
  c_setext()       { printf 'A Heading\n=========\n\nBody text.\n' > ai/STANDARDS.md; }
  c_setext_dash()  { printf 'A Heading\n---------\n\nBody.\n' > ai/STANDARDS.md; }
  # MID-LINE mentions: tools/scaffold_upgrade.sh greps for the string and prints advice
  # about it. Anchoring at column 0 is what keeps the checker off its own toolchain.
  c_midline()      { mkdir -p tools; printf "#!/bin/sh\ngrep -rl '<<<<<<<' \"\$DIR\"\necho \"search for '<<<<<<<' in each file\"\n" > tools/x.sh; }
  c_adj_open()     { printf '<<<<<<< ours   scaffold:not-a-conflict\na\n=======\nb\n>>>>>>> theirs\n' > ai/STANDARDS.md; }
  c_adj_close()    { printf '<<<<<<< ours\na\n=======\nb\n>>>>>>> theirs   scaffold:not-a-conflict\n' > ai/STANDARDS.md; }
  c_adj_sep()      { printf '<<<<<<< ours\na\n=======   scaffold:not-a-conflict\nb\n>>>>>>> theirs\n' > ai/STANDARDS.md; }
  # An adjudicated example must not launder a REAL conflict later in the same file.
  c_adj_then_real(){ printf '<<<<<<< ours\na\n=======\nb\n>>>>>>> theirs   scaffold:not-a-conflict\n\n<<<<<<< yours\nc\n=======\nd\n>>>>>>> scaffold 1.0.0\n' > ai/STANDARDS.md; }
  c_unclosed()     { printf '# Standards\n<<<<<<< yours\nsome text and then the file just ends\n' > ai/STANDARDS.md; }
  c_diff3()        { printf '<<<<<<< ours\na\n||||||| base\nz\n=======\nb\n>>>>>>> theirs\n' > ai/STANDARDS.md; }
  # THE CLASS THAT COST tools/secret_scan.sh A SILENT FALSE NEGATIVE (v0.2.0).
  c_spaced_path()  { mkdir -p app; printf '<<<<<<< ours\na\n=======\nb\n>>>>>>> theirs\n' > "app/my config.py"; }
  # Untracked files are out of scope by construction, same as the secret scan: this checks
  # what is COMMITTED. A dirty worktree mid-resolution must not fail the author's own run.
  c_untracked()    { printf '# Standards\nclean\n' > ai/STANDARDS.md
                     printf '<<<<<<< ours\na\n=======\nb\n>>>>>>> theirs\n' > scratch.txt
                     printf 'scratch.txt\n' > .gitignore; }
  # -I: a binary blob whose bytes start a line with a marker run is not a conflict.
  c_binary()       { mkdir -p bin; printf '<<<<<<< \x00\x01\x02binary\n=======\n\x00>>>>>>> x\n' > bin/blob.dat; }

  # ---- the sidecar half. The real one, from localcoder, byte for byte.
  c_sidecar()      { mkdir -p .github/workflows
                     printf 'name: x\n' > .github/workflows/scaffold-check.yml
                     printf 'name: x\n' > .github/workflows/scaffold-check.yml.scaffold-0.29.4.20260809.1810; }
  # UNTRACKED IS THE CORRECT STATE, not a lesser failure. The upgrade writes the sidecar and
  # tells you to reconcile it; failing the run that just produced it would make the tool
  # unusable and it would be turned off. Only COMMITTING it means the reconciliation stopped.
  c_sidecar_untr() { mkdir -p .github/workflows
                     printf 'name: x\n' > .github/workflows/scaffold-check.yml
                     printf 'name: x\n' > .github/workflows/scaffold-check.yml.scaffold-0.29.4.20260809.1810
                     printf '*.scaffold-0.29.4.20260809.1810\n' > .gitignore; }
  # `.scaffold-version` IS THE BASE STAMP FOR THE THREE-WAY MERGE and must stay tracked.
  # Flagging it would delete the input that makes upgrades mergeable at all — a check whose
  # remediation breaks the tool is worse than no check.
  c_version_stamp(){ printf '0.36.5.20260812.0140\n' > .scaffold-version; }
  # A file that merely CONTAINS the string is not a sidecar; the suffix must be the whole
  # version shape at the end of the name. Same argument as anchoring the markers at column 0.
  c_near_miss()    { printf 'x\n' > notes-about-.scaffold-0.29.4-upgrades.md
                     printf 'x\n' > config.scaffold-dev; }
  # RECONCILED BUT NOT YET STAGED. `git ls-files` reads the index, so the file still lists
  # after `rm`. Failing here fails the person mid-remedy — hit for real while reconciling
  # localcoder's three, and a guard that fires on its own fix is one people route around.
  c_sidecar_rmd()  { mkdir -p .github/workflows
                     printf 'name: x\n' > .github/workflows/scaffold-check.yml
                     printf 'name: x\n' > .github/workflows/scaffold-check.yml.scaffold-0.29.4.20260809.1810
                     git add -A >/dev/null 2>&1
                     rm -f .github/workflows/scaffold-check.yml.scaffold-0.29.4.20260809.1810; }

  echo "conflict_scan selftest — committed merge-conflict markers, offline"
  case_run "the real 0.14.0 STANDARDS.md conflict fails"      1 c_the_defect
  case_run "a clean tree passes"                              0 c_clean
  case_run "a setext '=====' heading is not a conflict"       0 c_setext
  case_run "a setext '-----' heading is not a conflict"       0 c_setext_dash
  case_run "mid-line mentions of the markers are not hits"    0 c_midline
  case_run "marker on the opener adjudicates the region"      0 c_adj_open
  case_run "marker on the closer adjudicates the region"      0 c_adj_close
  case_run "marker on the separator adjudicates the region"   0 c_adj_sep
  case_run "an adjudicated example launders no later region"  1 c_adj_then_real

  # ---- THE SUPPRESSION COUNT (design review 2026-08-14) --------------------------------
  #
  # EVERY CASE HERE ASSERTS A NUMBER. "Reports its count" is satisfied by printing 0 forever,
  # and that is not hypothetical: the first version of this counter passed its path to awk
  # through `-v`, which macOS's awk coerced to -inf, so the redirect wrote nowhere and every
  # run reported 0. It was caught by the equivalent case in stale_path_scan.sh asserting a 1.
  sup_case() {  # sup_case <label> <expected-line> <setup-fn>
    local label="$1" want="$2" setup="$3" R="$T/sup" out
    rm -rf "$R"; mkdir -p "$R/ai"
    ( cd "$R" && git init -q . && git config user.email a@b.c && git config user.name t )
    printf '# Standards\n' > "$R/ai/STANDARDS.md"
    ( cd "$R" && $setup )
    ( cd "$R" && git add -A >/dev/null 2>&1 )
    out="$( cd "$R" && bash "$SELF_ABS" 2>&1 )"
    if printf '%s\n' "$out" | grep -qF "$want"; then printf '  ok   %-56s\n' "$label"
    else
      printf '  FAIL %-56s wanted: %s\n' "$label" "$want"
      printf '%s\n' "$out" | sed 's/^/         /' | head -6
      fails=$((fails + 1))
    fi
  }
  sup_case "a clean tree prints the suppression count at zero" \
           "Suppressed 0 conflict region(s)" c_clean
  sup_case "one adjudicated region is counted as one" \
           "Suppressed 1 conflict region(s)" c_adj_close
  sup_case "and the count prints on a FAILING run too" \
           "Suppressed 1 conflict region(s)" c_adj_then_real
  case_run "an opener that is never closed still fails"       1 c_unclosed
  case_run "a diff3 region with a base marker fails"          1 c_diff3
  case_run "a conflict in a path WITH SPACES still fails"     1 c_spaced_path
  case_run "an untracked conflicted file is out of scope"     0 c_untracked
  case_run "a binary file is skipped, not reported"           0 c_binary
  case_run "a TRACKED upgrade sidecar fails"                  1 c_sidecar
  case_run "an UNTRACKED sidecar is the correct mid-upgrade state" 0 c_sidecar_untr
  case_run ".scaffold-version is the base stamp, not a sidecar"    0 c_version_stamp
  case_run "a name merely containing the string is not a sidecar"  0 c_near_miss
  case_run "a sidecar deleted but not yet staged passes"           0 c_sidecar_rmd

  # SCALE, ASSERTED RATHER THAN ASSUMED. The prefilter exists so this cost stays flat as a
  # tree grows; without an assertion that is a comment, not a property. 600 files is enough
  # to catch a reintroduced per-file walk (~2.4s at the measured 4ms/file) while keeping
  # this suite fast enough to run on every push.
  local R="$T/scale" i start elapsed
  rm -rf "$R"; mkdir -p "$R/ai/pkg"
  ( cd "$R" && git init -q . && git config user.email a@b.c && git config user.name t )
  printf '# Standards\n' > "$R/ai/STANDARDS.md"
  i=0; while [ "$i" -lt 600 ]; do printf 'x = %d\n' "$i" > "$R/ai/pkg/m$i.py"; i=$((i + 1)); done
  ( cd "$R" && git add -A >/dev/null 2>&1 )
  start=$(date +%s)
  ( cd "$R" && bash "$SELF_ABS" >/dev/null 2>&1 )
  elapsed=$(( $(date +%s) - start ))
  if [ "$elapsed" -le 1 ]; then printf '  ok   %-56s\n' "600 files scan in <=1s (prefilter intact)"
  else
    printf '  FAIL %-56s took %ss\n' "600 files scan in <=1s (prefilter intact)" "$elapsed"
    fails=$((fails + 1))
  fi

  rm -rf "$T"
  echo ""
  if [ "$fails" -eq 0 ]; then echo "  all checks passed"; return 0; fi
  echo "  $fails check(s) FAILED"; return 1
}

case "${1:-}" in
  --selftest) selftest ;;
  "")         scan ;;
  *)          echo "usage: conflict_scan.sh [--selftest]" >&2; exit 2 ;;
esac
