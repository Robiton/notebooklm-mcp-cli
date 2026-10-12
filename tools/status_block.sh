#!/usr/bin/env bash
# Project:  ai-project-scaffold
# File:     tools/status_block.sh
# Modified: 2026-09-23
# Version:  0.6.4.20260923.0941
# Purpose:  Generate the repository status table from git and gh, so it cannot go stale
# Changelog:
#   2026-09-23 v0.6.4.20260923.0941 — fixtures run inside the root tools/fixture_guard.sh validates. There a git and a mktemp on PATH refuse anything that would land outside it. Every mktemp takes a ${TMPDIR} template, because macOS mktemp ignores TMPDIR without one.
#   2026-09-23 v0.6.3.20260923.0843 — every mktemp fails closed. A failed one left the temp variable empty, so the fixture ran in the caller's directory; header_check's committed into Robiton/control.
#   2026-09-22 v0.6.2.20260922.0501 — a sibling's row is advisory; this repo's own row is not (#311).
#                        0.25.0's post-upgrade refresh covers the repo's OWN row and cannot cover
#                        a sibling's -- a repo does not know who declares it, and a tool that
#                        writes into other repositories to keep a gate green is worse than the
#                        gate. So the gate was ORDER-DEPENDENT: upgrade the block-declaring repo
#                        first and a later sibling upgrade reds it on a row that is not about it.
#                        #288's cut, one column out. The tolerance is withheld entirely when the
#                        block has no row of its own, or a sibling-only block would become a gate
#                        that cannot fail on any version.
#   2026-09-15 v0.6.1.20260915.0910 — #311 --write no longer freezes an in-flight CI state into the
#                        committed block, which reddened the gate at every run afterwards.
#   2026-09-03 v0.6.0.20260903.0805 — AN ISSUE COUNT IS NOT A FACT ABOUT THIS TREE (#288).
#                        Closing an issue made this gate red. Nothing in the repository
#                        changed; somebody clicked a button on GitHub.
#                        MEASURED: five refreshes in two days, every one because an issue was
#                        closed AFTER the block was written, one of them mid-release where
#                        the entire fix was "run the tool again".
#                        A gate that fires predictably after a normal action, with a fixed
#                        one-command remedy and no decision in it, is one people learn to
#                        clear on autopilot -- and then clear on the day it mattered. That
#                        argument is already in this repository twice (#282, and the archive
#                        ceiling before it).
#                        SO THE COLUMNS ARE NOT EQUAL. A version, an adoption marker or a CI
#                        conclusion is a fact about this tree and drift there still FAILS. An
#                        open-issue count is a fact about a website, carried for orientation:
#                        drift in that column ALONE is reported and exits 0. --write still
#                        refreshes everything, so the number is never wrong for long.
#                        The selftest pins the MASK in both directions, because the way this
#                        breaks is blanking the wrong field -- which would swallow a version
#                        drift and leave the gate unfalsifiable.
#   2026-08-26 v0.5.0 — A CI STATE STILL IN FLIGHT IS NO LONGER A DIFFERENCE (#241).
#                        The CI column reports the newest run on main, and that state changes
#                        AS A DIRECT RESULT OF THE PUSH THE BLOCK IS COMMITTED IN -- so
#                        --write, commit, push, preflight was reliably STALE with nothing
#                        wrong. Observed three times in one session. That is a gate red at a
#                        completely normal moment, the property session_currency.sh argues
#                        against in its own header, and it trains the wrong repair: re-run
#                        --write and commit, which pushes again, which starts another run.
#                        queued / in_progress / requested / waiting now adopt whatever the
#                        file already says for that row. success and failure still compare
#                        exactly -- settling those would make the column unfalsifiable, which
#                        is worse than the false red, and there is a selftest case asserting
#                        precisely that.
#                        The first draft passed the committed text through `awk -v`, where a
#                        multi-line value is mangled: it matched nothing and staled every row.
#                        Two-file NR==FNR instead.
#   2026-08-20 v0.4.0 — THE CI COLUMN READ ANY BRANCH, NOT main. `--limit 1` with no
#                        --branch takes the newest Scaffold Check run in the repository,
#                        so a failing feature branch is reported as the repository's CI
#                        state. Measured: localcoder-dev showed `failure` while every run
#                        on main was green, because an M3 results branch had a red run one
#                        minute newer. It flip-flopped success/failure/success across three
#                        consecutive regenerations -- worse than being wrong once, because
#                        a gate that looks flaky is one people stop reading.
#                        release.sh carried this same defect and had it fixed; this is the
#                        other tool asking the same question and nobody checked it.
#                        An in-progress run has a null conclusion, which printed as empty
#                        and read as a missing answer rather than a pending one; now named.
#   2026-08-18 v0.3.0.20260818.1918 — A BLOCK THAT CANNOT BE DERIVED HERE IS EXIT 3, NOT A
#                        FAILURE, and --write refuses rather than shortening the table.
#                        The block names sibling repositories by relative path. On a machine
#                        without them -- a fresh clone, a CI runner, an adopter who inherited
#                        the markers -- render() quietly produced a table with NO ROWS: so
#                        --check called a perfectly correct block STALE, and --write would
#                        have DESTROYED the real table and called that an update.
#                        Caught by adoption_check, which builds a new project from a clone and
#                        found its preflight RED ON ARRIVAL -- which this project's own rule
#                        says is a preflight people learn to skip, including for the gates
#                        that matter.
#   2026-08-18 v0.2.0.20260818.1827 — TWO DEFECTS IN MY OWN 0.1.x, both from the families this
#                        programme keeps naming.
#                        (1) THE GATE COULD NEVER BE GREEN. The written block reported HEAD,
#                        dirty and sync FOR THE REPO THAT HOSTS IT — three facts the act of
#                        writing and committing the block changes. `--write` made dirty 1;
#                        committing moved HEAD. So `--check` reported STALE immediately after
#                        a successful `--write`, forever, with nothing wrong. A gate that
#                        fires on every green run is one people learn to filter out — the
#                        exact lesson already recorded here about the Node 20 notice.
#                        Fix: the block carries only facts that survive its own commit
#                        (tag, version, adopts, issues, CI). The volatile working-tree view
#                        moved to `--status`, which prints and never writes.
#                        (2) THE SELFTEST WAS VACUOUS. It ran a hand-written `s.replace()`
#                        instead of the splice, so it passed whether or not the tool worked,
#                        and could not have caught (1). It now drives the real --write/--check
#                        paths and asserts the property that was broken: check is clean
#                        immediately after write, and write is idempotent.
#   2026-08-18 v0.1.0.20260818.1800 — Initial. A HAND-MAINTAINED STATUS TABLE HAS NOW GONE
#                        STALE TWICE IN THIS PROGRAMME, the second time inside a block whose
#                        own text says "Re-derived, not copied — the block below this one used
#                        to be six releases stale and that lesson is kept." It re-staled by
#                        twelve releases within a day of being hand-corrected, and an outside
#                        review flagged it in two consecutive assessments.
#                        Discipline has been tried and has failed twice, so the answer is
#                        derivation. Human commentary lives OUTSIDE the markers and is never
#                        touched; only the region between them is rewritten.
#                        --check fails on drift, so a stale block is a gate result rather than
#                        something a reader has to notice.
set -euo pipefail

BEGIN='<!-- scaffold:status-begin -->'
END='<!-- scaffold:status-end -->'
TARGET="${STATUS_BLOCK_FILE:-ai/BACKLOG.md}"
MODE="${1:---check}"

# WHICH REPOS. Declared at column 0 in the target file, so a context repo names the siblings
# it tracks rather than this tool guessing from a directory listing.
#     <!-- scaffold:status-repos ../a ../b -->
repos_declared() {
  grep -oE '^<!--[[:space:]]*scaffold:status-repos[[:space:]]+[^>]*-->' "$TARGET" 2>/dev/null \
    | sed -E 's/^<!--[[:space:]]*scaffold:status-repos[[:space:]]+//; s/[[:space:]]*-->$//'
}

# CAN THIS BLOCK BE DERIVED HERE AT ALL? Prints "<resolved> <declared>".
# WHY THIS EXISTS. The block names sibling repositories by relative path. On a machine that
# does not have them checked out -- a fresh clone, a CI runner, an adopter who inherited the
# markers -- render() quietly produces a table with no rows. That is two failures at once:
# --check reports STALE against a block that is perfectly correct, and --write DESTROYS the
# real table and replaces it with an empty one.
# Caught by adoption_check: a new project built from a clone had a preflight that was RED ON
# ARRIVAL, which this project's own rule says is a preflight people learn to skip.
# A block that cannot be derived is EXIT 3 -- could not check. Not a pass, not a failure.
resolvable() {
  local r declared=0 found=0
  for r in $(repos_declared); do
    declared=$((declared + 1))
    [ -d "$r/.git" ] && found=$((found + 1))
  done
  printf '%s %s' "$found" "$declared"
}

slug_of() {
  local s; s="$(git -C "$1" remote get-url origin 2>/dev/null || true)"
  # NO NON-GREEDY OPERATOR IN BSD sed, and this is a shipped file that must run on both.
  # The first draft used `+?` and printed `RE error: repetition-operator operand invalid`
  # four times on macOS — the same class as the `mktemp -t NAME` defect this repo records.
  s="${s%.git}"; s="${s#*github.com/}"; s="${s#*github.com:}"; printf '%s' "$s"
}

# THE DURABLE TABLE — what gets written to the file.
# Every column here must survive the commit that writes it. HEAD, dirty and sync do not:
# see the 0.2.0 changelog. They live in --status instead.
render() {
  local now; now="$(date -u '+%Y-%m-%dT%H:%MZ')"
  printf '%s\n' "$BEGIN"
  printf '_Generated by `tools/status_block.sh --write`. Do not hand-edit — run it.\n'
  printf 'Derived %s from git and gh; commentary belongs OUTSIDE these markers.\n' "$now"
  printf 'Working-tree state (dirty, ahead/behind) is deliberately absent — it cannot outlive\n'
  printf 'its own commit. Run `tools/status_block.sh --status` for that view._\n\n'
  printf '| repo | exact tag | version | adopts | open issues | CI |\n'
  printf '|---|---|---|---|---|---|\n'
  local r name tag ver scf issues ci slug
  for r in $(repos_declared); do
    [ -d "$r/.git" ] || continue
    name="$(basename "$(cd "$r" && pwd)")"
    tag="$(git -C "$r" describe --tags --exact-match HEAD 2>/dev/null || echo '—')"
    ver="$(head -1 "$r/version" 2>/dev/null || echo 'ships nothing')"
    scf="$(head -1 "$r/.scaffold-version" 2>/dev/null || echo '—')"
    slug="$(slug_of "$r")"
    issues="—"; ci="—"
    if [ -n "$slug" ] && command -v gh >/dev/null 2>&1; then
      # NEVER LET A NETWORK CALL DECIDE A GATE. A failed lookup prints `?`, which is not the
      # same claim as 0 and must not read like one.
      issues="$(gh issue list --repo "$slug" --json number -q '.|length' 2>/dev/null || echo '?')"
        # --branch main, AND IT IS THE WHOLE POINT OF THE COLUMN. Without it `--limit 1`
        # takes the newest Scaffold Check run on ANY branch, so a failing feature branch is
        # reported as the repository's CI state. Measured 2026-08-20: localcoder-dev showed
        # `failure` while every run on main was green, because a branch had a red run one
        # minute newer. The column flip-flopped success/failure/success across three
        # consecutive regenerations, which is worse than being wrong once -- a gate that
        # looks flaky is a gate people stop reading.
        # release.sh carried this exact defect and had it fixed; this is the same bug in the
        # other tool asking the same question.
        # AN IN-PROGRESS RUN HAS A NULL CONCLUSION, which would print empty and read as a
        # missing answer rather than a pending one, so it is named.
        ci="$(gh run list --repo "$slug" --workflow 'Scaffold Check' --branch main --limit 1 \
              --json conclusion,status \
              -q '.[0] | if (.conclusion // "") == "" then (.status + "-pending") else .conclusion end' \
              2>/dev/null || echo '?')"
    fi
    printf '| `%s` | %s | %s | %s | %s | %s |\n' \
      "$name" "$tag" "$ver" "$scf" "$issues" "${ci:-?}"
  done
  printf '%s\n' "$END"
}

# THE VOLATILE VIEW — printed, never written. This is the operational "is everything
# committed and pushed" check that used to be smuggled into the document.
status_now() {
  local r name head dirty ahead behind
  printf '%-26s %-10s %-6s %s\n' repo HEAD dirty sync
  for r in $(repos_declared); do
    [ -d "$r/.git" ] || continue
    name="$(basename "$(cd "$r" && pwd)")"
    head="$(git -C "$r" rev-parse --short HEAD 2>/dev/null || echo '?')"
    dirty="$(git -C "$r" status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
    git -C "$r" fetch -q origin >/dev/null 2>&1 || true
    ahead="$(git -C "$r" rev-list --count origin/main..HEAD 2>/dev/null || echo '?')"
    behind="$(git -C "$r" rev-list --count HEAD..origin/main 2>/dev/null || echo '?')"
    printf '%-26s %-10s %-6s %s/%s\n' "$name" "$head" "$dirty" "$ahead" "$behind"
  done
}

splice() {  # $1 = file; block on stdin via $BLOCK
  BLOCK="$1" BEGIN_M="$BEGIN" END_M="$END" python3 - "$2" <<'SPLICE'
import io, os, sys
path = sys.argv[1]
begin, end = os.environ["BEGIN_M"], os.environ["END_M"]
lines = io.open(path, encoding="utf-8").read().split("\n")
out, skip = [], False
for ln in lines:
    if ln.strip() == begin:
        out.extend(os.environ["BLOCK"].split("\n")); skip = True; continue
    if ln.strip() == end:
        skip = False; continue
    if not skip:
        out.append(ln)
io.open(path, "w", encoding="utf-8").write("\n".join(out))
SPLICE
}

# A CI STATE THAT IS STILL MOVING IS NOT A DIFFERENCE (#241).
#
# The CI column reports the newest Scaffold Check run on main. That state changes AS A DIRECT
# RESULT OF THE PUSH THE BLOCK IS COMMITTED IN, so the sequence is:
#
#     --write            CI: success
#     commit ; push      <- this push starts a run
#     preflight          CI: in_progress-pending  ->  STALE, exit 1
#
# Nothing is wrong at that moment. The block was regenerated minutes earlier and was correct
# when written. That is a gate red at a completely normal moment, which is the property
# session_currency.sh argues against in its own header -- and it trains the wrong repair:
# re-run --write, commit, which pushes again, which starts another run, which makes it stale
# again. Observed three times in one session before this existed.
#
# SO ONLY TERMINAL STATES ARE COMPARED. queued / in_progress / requested / waiting -- the
# states that exist only BETWEEN a push and its result -- adopt whatever the file already
# says for that row, because no committed file can track them. success and failure still
# compare exactly: those are the ones a stale block would be lying about.
#
# It takes the CURRENT rendering on stdin and the committed text as $1.
settle_pending_ci() {  # settle_pending_ci <file-holding-the-committed-text>
  # TWO FILES, NOT -v. A multi-line value passed through `awk -v` is mangled -- escape
  # sequences are processed and the newlines do not survive intact -- so the first draft of
  # this silently matched nothing and staled every row. The committed text is read as a
  # file and the candidate arrives on stdin, which is the ordinary NR==FNR idiom.
  awk '
    NR == FNR {
      if ($0 ~ /^\| `/) {
        split($0, f, "|"); key = f[2]
        gsub(/^[ \t]+|[ \t]+$/, "", key)
        old[key] = $0
      }
      next
    }
    {
      if ($0 ~ /^\| `/ && $0 ~ /(queued|in_progress|requested|waiting)/) {
        split($0, g, "|"); key = g[2]
        gsub(/^[ \t]+|[ \t]+$/, "", key)
        if (key in old) { print old[key]; next }
      }
      print
    }
  ' "$1" -
}

case "$MODE" in
  --selftest)
    # DRIVES THE REAL PATHS. The 0.1.x selftest ran a hand-written string replace and so
    # passed whether or not the tool worked; it is the reason the unsatisfiable-gate defect
    # shipped. Every assertion below runs this script as a subprocess.
    # FIXTURES RUN INSIDE A GUARDED ROOT (tools/fixture_guard.sh). Later mktemps land inside it,
    # and a git on PATH refuses any write outside it. The guard exists because a failed mktemp
    # once let a selftest run git init and commit in the real repo.
    . "$(dirname "${BASH_SOURCE[0]}")/fixture_guard.sh" || { echo "status_block: tools/fixture_guard.sh is missing; refusing to build fixtures" >&2; exit 1; }
    fixture_root FG_ROOT; trap fg_cleanup EXIT
    d="$(mktemp -d "${TMPDIR:-/tmp}/status_block.XXXXXX")" || { echo "status_block: mktemp failed; stopping" >&2; exit 1; }; f="$d/f.md"; fails=0; _rc=0
    # A DECLARED REPO, OR THE FIXTURE IS VACUOUS. With no rows rendered, only the header is
    # compared and a re-added volatile column would sail straight through — the same
    # "passes whether or not the defect is there" failure the 0.1.x selftest had. This repo
    # has no origin, so no network call fires.
    git init -q "$d/repo"; : > "$d/repo/f"; echo '1.0.0.20260818.0000' > "$d/repo/version"
    git -C "$d/repo" add -A
    git -C "$d/repo" -c user.email=t@t -c user.name=t commit -qm init
    printf 'HUMAN INTRO\n<!-- scaffold:status-repos %s -->\n\n%s\nstale garbage\n%s\n\nHUMAN TAIL\n' \
      "$d/repo" "$BEGIN" "$END" > "$f"
    STATUS_BLOCK_FILE="$f" "$0" --write >/dev/null

    grep -q '^HUMAN INTRO$' "$f" && grep -q '^HUMAN TAIL$' "$f" \
      && echo "  ok   commentary outside the markers survives a rewrite" \
      || { echo "  FAIL commentary outside the markers was destroyed"; fails=1; }

    grep -q 'stale garbage' "$f" \
      && { echo "  FAIL the old block was not replaced"; fails=1; } \
      || echo "  ok   the region between the markers is replaced"

    grep -q '| `repo` |' "$f" \
      && echo "  ok   the declared repo produced a row, so the comparison has content" \
      || { echo "  FAIL no row rendered — every assertion below would be vacuous"; fails=1; }

    grep -q "$BEGIN" "$f" && grep -q "$END" "$f" \
      && echo "  ok   both markers survive, so the block can be rewritten again" \
      || { echo "  FAIL a marker was consumed — the block is now unwritable"; fails=1; }

    # THE PROPERTY THAT WAS BROKEN. --check must be clean the instant --write returns.
    if STATUS_BLOCK_FILE="$f" "$0" --check >/dev/null 2>&1; then
      echo "  ok   --check is clean immediately after --write"
    else
      echo "  FAIL --check reports STALE right after --write — the gate can never be green"; fails=1
    fi

    # THE MUTATION GUARD. Re-add a working-tree column to render() and these two fail.
    : > "$d/repo/dirtyfile"
    if STATUS_BLOCK_FILE="$f" "$0" --check >/dev/null 2>&1; then
      echo "  ok   a dirty working tree does not stale the block"
    else
      echo "  FAIL a dirty tree staled the block — a volatile column is back in render()"; fails=1
    fi
    git -C "$d/repo" add -A
    git -C "$d/repo" -c user.email=t@t -c user.name=t commit -qm second
    if STATUS_BLOCK_FILE="$f" "$0" --check >/dev/null 2>&1; then
      echo "  ok   a new commit does not stale the block"
    else
      echo "  FAIL a commit staled the block — HEAD is back in render()"; fails=1
    fi

    cp "$f" "$d/once"; STATUS_BLOCK_FILE="$f" "$0" --write >/dev/null
    if diff -q <(grep -vE '^Derived ' "$d/once") <(grep -vE '^Derived ' "$f") >/dev/null; then
      echo "  ok   --write is idempotent"
    else
      echo "  FAIL --write is not idempotent — the block churns on every run"; fails=1
    fi

    # AND IT MUST STILL FAIL WHEN IT SHOULD. A check that never fails is worth nothing.
    printf 'HUMAN INTRO\n<!-- scaffold:status-repos %s -->\n%s\n| tampered |\n%s\n' \
      "$d/repo" "$BEGIN" "$END" > "$f"
    if STATUS_BLOCK_FILE="$f" "$0" --check >/dev/null 2>&1; then
      echo "  FAIL --check passed a tampered block"; fails=1
    else
      echo "  ok   --check fails on a tampered block"
    fi

    # A RELEASE MUST STALE IT, or the gate is measuring nothing that matters.
    STATUS_BLOCK_FILE="$f" "$0" --write >/dev/null
    echo '2.0.0.20260818.0001' > "$d/repo/version"
    if STATUS_BLOCK_FILE="$f" "$0" --check >/dev/null 2>&1; then
      echo "  FAIL a version bump did not stale the block"; fails=1
    else
      echo "  ok   a version bump stales the block"
    fi

    # A BLOCK THAT CANNOT BE DERIVED IS EXIT 3, IN BOTH MODES. This is the case that made an
    # adopter's preflight red on arrival, and the one where --write would have destroyed the
    # real table. Declares a repository that is not here.
    printf 'HUMAN INTRO\n<!-- scaffold:status-repos %s/absent -->\n%s\n| x |\n%s\n' \
      "$d" "$BEGIN" "$END" > "$f"
    set +e; STATUS_BLOCK_FILE="$f" "$0" --check >/dev/null 2>&1; _rc=$?; set -e
    if [ "$_rc" -eq 3 ]; then
      echo "  ok   --check is exit 3, not a failure, when the declared repos are absent"
    else
      echo "  FAIL --check returned $_rc for an underivable block — an adopter inherits a red gate"; fails=1
    fi
    cp "$f" "$d/before"
    set +e; STATUS_BLOCK_FILE="$f" "$0" --write >/dev/null 2>&1; _rc=$?; set -e
    if [ "$_rc" -eq 3 ] && diff -q "$d/before" "$f" >/dev/null; then
      echo "  ok   --write REFUSES rather than replacing the table with a shorter one"
    else
      echo "  FAIL --write returned $_rc and the file changed — a real table was overwritten"; fails=1
    fi

    rm -rf "$d"
    # ---- #241: A CI STATE STILL IN FLIGHT IS NOT A DIFFERENCE ------------------------
    #
    # The property, and its negative. Settling every mismatch would make the column
    # unfalsifiable -- a block claiming `success` over a real `failure` would sail through,
    # which is worse than the false red this fixes.
    # ITS OWN TEMP FILE: $d is already removed by the cases above, and reusing it made these
    # four cases fail on a missing path rather than on the property they test.
    _cf="$(mktemp "${TMPDIR:-/tmp}/status_block.XXXXXX")" || { echo "status_block: mktemp failed; stopping" >&2; exit 1; }
    printf '| `%s` | 1.0 | 1.0 | 1.0 | 0 | success |\n' repo > "$_cf"

    _settled="$(printf '| `%s` | 1.0 | 1.0 | 1.0 | 0 | in_progress-pending |\n' repo \
                | settle_pending_ci "$_cf")"
    case "$_settled" in
      *success*) echo "  ok   an in-flight CI state adopts the committed value, not a diff" ;;
      *) echo "  FAIL a pending CI state still stales the block (#241): $_settled"; fails=1 ;;
    esac

    # NO SELFTEST CASE FOR THE #311 DIRECTION, AND THAT IS DELIBERATE.
    #
    # The fix is at write time: --write now pipes render() through settle_pending_ci so a
    # pending CI state never replaces a settled committed value. Asserting that needs
    # render() to PRODUCE a pending row, and render() reads CI from gh -- the fixture repo
    # below has no remote, so it can never be pending here.
    #
    # A case was written and then removed: it exercised settle_pending_ci directly in the
    # direction that was ALREADY guarded, so it passed with the fix reverted. Proven by
    # reverting it in a copy and watching the case stay green. A test that cannot fail is
    # worse than an acknowledged gap, because the gap is visible and the green is not.
    #
    # Verified instead against the real reproduction: ai-project-scaffold-dev's committed
    # block held `in_progress-pending` for localcoder, and --check stayed red across runs
    # until --write happened to land while CI was idle. Closing that needs a test seam in
    # render(), which is a bigger change than the defect.

    _q="$(printf '| `%s` | 1.0 | 1.0 | 1.0 | 0 | queued-pending |\n' repo \
          | settle_pending_ci "$_cf")"
    case "$_q" in
      *success*) echo "  ok   queued is treated the same as in_progress" ;;
      *) echo "  FAIL queued was not settled: $_q"; fails=1 ;;
    esac

    # THE NEGATIVE, AND IT IS THE ONE THAT KEEPS THE COLUMN HONEST.
    _fail="$(printf '| `%s` | 1.0 | 1.0 | 1.0 | 0 | failure |\n' repo \
             | settle_pending_ci "$_cf")"
    case "$_fail" in
      *failure*) echo "  ok   a TERMINAL state is still compared — success/failure never settle" ;;
      *) echo "  FAIL a real failure was settled away — the column is now unfalsifiable"; fails=1 ;;
    esac

    # A row we have never seen must pass through untouched rather than vanish.
    _new="$(printf '| `%s` | 1.0 | 1.0 | 1.0 | 0 | in_progress-pending |\n' brandnew \
            | settle_pending_ci "$_cf")"
    case "$_new" in
      *brandnew*) echo "  ok   a row absent from the committed block survives" ;;
      *) echo "  FAIL a new row was dropped: $_new"; fails=1 ;;
    esac

    # ---- ISSUE-COUNT DRIFT IS ADVISORY; EVERY OTHER COLUMN IS NOT (#288) ---------------
    #
    # Asserted on the COLUMN MASK rather than end to end, because an end-to-end case needs
    # four resolvable sibling repos and a live `gh`. What can break here is the masking: if
    # it blanked the wrong field, a version drift would be tolerated and this gate would
    # stop meaning anything. So both directions are pinned.
    _mask() { awk -F'|' 'BEGIN{OFS="|"} NF>5{$(NF-2)=" x "} {print}'; }
    _row_a='| `r` | — | 1.0.0 | 2.0.0 | 19 | success |'
    _row_issue='| `r` | — | 1.0.0 | 2.0.0 | 27 | success |'
    _row_ver='| `r` | — | 1.0.1 | 2.0.0 | 19 | success |'
    _row_ci='| `r` | — | 1.0.0 | 2.0.0 | 19 | failure |'
    if [ "$(printf '%s' "$_row_a" | _mask)" = "$(printf '%s' "$_row_issue" | _mask)" ]; then
      echo "  ok   a differing issue count masks to the same row"
    else
      echo "  FAIL the issue column is not the one being masked"; fails=1
    fi
    if [ "$(printf '%s' "$_row_a" | _mask)" != "$(printf '%s' "$_row_ver" | _mask)" ]; then
      echo "  ok   a differing VERSION still differs after masking"
    else
      echo "  FAIL masking swallowed a version drift — the gate is now unfalsifiable"; fails=1
    fi
    if [ "$(printf '%s' "$_row_a" | _mask)" != "$(printf '%s' "$_row_ci" | _mask)" ]; then
      echo "  ok   and so does a differing CI conclusion"
    else
      echo "  FAIL masking swallowed a CI drift"; fails=1
    fi

    # ---- A SIBLING'S ROW IS ADVISORY; THIS REPO'S OWN ROW IS NOT (#311) ---------------
    #
    # Pinned on the mask, for the reason given above the #288 block: end to end this needs
    # four resolvable siblings and a live gh. The danger here is a mask that is too WIDE --
    # swallow this repo's own row and the gate stops meaning anything at all -- so both
    # directions are asserted, and so is the guard that withholds the tolerance entirely.
    _sm() {  # the mask, with $1 as this repo's name
      SB_OWN="$1" awk -F'|' '
        BEGIN { own = ENVIRON["SB_OWN"] }
        NF>5 {
          name = $2
          gsub(/[`[:space:]]/, "", name)
          if (name != "" && name != "repo" && name !~ /^-+$/ && name != own) {
            print "|SIBLING-ROW-MASKED|"; next
          }
        }
        { print }'
    }
    _me='| `mine` | — | 1.0.0 | 2.0.0 | 3 | success |'
    _me_drift='| `mine` | — | 1.0.1 | 2.0.0 | 3 | success |'
    _sib='| `other` | — | 1.0.0 | 2.0.0 | 3 | success |'
    _sib_drift='| `other` | — | 9.9.9 | 2.0.0 | 3 | success |'

    if [ "$(printf '%s' "$_sib" | _sm mine)" = "$(printf '%s' "$_sib_drift" | _sm mine)" ]; then
      echo "  ok   a sibling's version drift masks to the same row"
    else
      echo "  FAIL a sibling row is not being masked — #311 is not fixed"; fails=1
    fi
    if [ "$(printf '%s' "$_me" | _sm mine)" != "$(printf '%s' "$_me_drift" | _sm mine)" ]; then
      echo "  ok   THIS repo's own row still differs after masking"
    else
      echo "  FAIL the mask swallowed this repo's own row — the gate is now unfalsifiable"; fails=1
    fi
    # The header and the separator must survive, or two blocks with different columns
    # would compare equal.
    _hdr='| repo | exact tag | version | adopts | open issues | CI |'
    if [ "$(printf '%s' "$_hdr" | _sm mine)" = "$_hdr" ]; then
      echo "  ok   the header row is never masked"
    else
      echo "  FAIL the header was masked away — a column change would go unnoticed"; fails=1
    fi

    # THE GUARD: no own row means NO tolerance. A block listing only other repositories
    # would otherwise become a gate that cannot fail on any version.
    _cur_only_sibs="$(printf '%s\n' "$_sib")"
    if printf '%s\n' "$_cur_only_sibs" | grep -qF '| `mine` |'; then
      echo "  FAIL fixture error: the sibling-only block contains an own row"; fails=1
    else
      echo "  ok   a block with no row of its own is detected, so the tolerance is withheld"
    fi

    rm -f "$_cf"
    [ "$fails" -eq 0 ] && { echo "status_block: selftest passed"; exit 0; }
    echo "status_block: selftest FAILED" >&2; exit 1 ;;
  --status)
    status_now; exit 0 ;;
  --write)
    [ -f "$TARGET" ] || { echo "status_block: $TARGET not found" >&2; exit 1; }
    grep -q "$BEGIN" "$TARGET" || { echo "status_block: no $BEGIN marker in $TARGET" >&2; exit 1; }
    set -- $(resolvable)
    if [ "$2" -gt 0 ] && [ "$1" -lt "$2" ]; then
      echo "status_block: REFUSING to write — $1 of $2 declared repositories are present here." >&2
      echo "  Writing now would replace the table with a shorter one and call that an update." >&2
      exit 3
    fi
    # ---- DO NOT FREEZE A TRANSIENT INTO A COMMITTED FILE (#311).
    #
    # `--write` spliced raw render() output, so a CI run that happened to be in flight at
    # write time was recorded as though `in_progress-pending` were a CONCLUSION. It is not
    # a conclusion; it is the could-not-check state, and writing it as a result is the same
    # error this project names everywhere else -- absent is not empty, unchecked is not
    # clean.
    #
    # And it does not merely record a wrong value once. settle_pending_ci() handles
    # committed-settled vs candidate-pending, which is the direction that protects a good
    # block from CI churn. The REVERSE -- committed-pending vs candidate-settled -- has no
    # guard, so once a pending value is in the file the gate is red at every run until a
    # human happens to execute --write at a moment when CI is idle. Measured: it reds
    # ai-project-scaffold-dev's gate and the remedy is a command with no decision attached,
    # which is precisely the gate people learn to clear on autopilot.
    #
    # Settling on WRITE keeps the transient out of the file in the first place, so the
    # existing guard only ever has to handle the direction it was written for. A first
    # write with no prior settled value still records pending, which is honest and
    # self-correcting on the next write.
    _wcur="$(mktemp "${TMPDIR:-/tmp}/status_block.XXXXXX")" || { echo "status_block: mktemp failed; stopping" >&2; exit 1; }
    awk -v b="$BEGIN" -v e="$END" '$0==b{p=1} p{print} $0==e{p=0}' "$TARGET" > "$_wcur"
    splice "$(render | settle_pending_ci "$_wcur")" "$TARGET"
    rm -f "$_wcur"
    echo "status_block: $TARGET rewritten"; exit 0 ;;
  --check)
    [ -f "$TARGET" ] || exit 0
    grep -q "$BEGIN" "$TARGET" || exit 0
    set -- $(resolvable)
    if [ "$2" -gt 0 ] && [ "$1" -lt "$2" ]; then
      echo "status_block: CANNOT CHECK — $1 of $2 declared repositories are present here." >&2
      echo "  A fresh clone, a CI runner or an adopter that inherited these markers cannot" >&2
      echo "  derive this table, and a block it cannot derive is not a block that is wrong." >&2
      exit 3
    fi
    _curfile="$(mktemp "${TMPDIR:-/tmp}/status_block.XXXXXX")" || { echo "status_block: mktemp failed; stopping" >&2; exit 1; }; trap 'rm -f "$_curfile"' EXIT
    cur="$(awk -v b="$BEGIN" -v e="$END" '$0==b{p=1} p{print} $0==e{p=0}' "$TARGET" \
           | grep -vE '^_Generated|^Derived|^Working-tree|^its own commit|^$')"
    printf '%s\n' "$cur" > "$_curfile"
    new="$(render | grep -vE '^_Generated|^Derived|^Working-tree|^its own commit|^$' \
           | settle_pending_ci "$_curfile")"
    if [ "$cur" = "$new" ]; then echo "status_block: current"; exit 0; fi

    # ---- AN ISSUE COUNT IS NOT A FACT ABOUT THIS TREE (#288) ----------------------------
    #
    # Closing an issue makes this gate red. Nothing in the repository changed; somebody
    # clicked a button on GitHub. MEASURED: five refreshes in two days, every one of them
    # because an issue was closed AFTER the block was written, and one of them mid-release
    # where the fix was "run the tool again" and nothing else.
    #
    # A gate that fires predictably after a normal action, with a fixed one-command remedy
    # and no decision attached, is one people learn to clear on autopilot -- and then clear
    # on the day it was telling them something. That argument is already in this repo twice
    # (#282, and the archive ceiling before it).
    #
    # SO THE COLUMNS ARE NOT EQUAL. A version or an adoption marker or a CI conclusion is a
    # fact about this tree and drift there is a real finding. An open-issue count is a fact
    # about a website, and it is in the table for orientation. Drift in the issue column
    # ALONE is reported and exits 0; drift anywhere else still fails.
    #
    # `--write` still refreshes everything, so the number is never wrong for long -- it just
    # stops being a reason to fail a push.
    _cur_noissue="$(printf '%s\n' "$cur" | awk -F'|' 'BEGIN{OFS="|"} NF>5{$(NF-2)=" x "} {print}')"
    _new_noissue="$(printf '%s\n' "$new" | awk -F'|' 'BEGIN{OFS="|"} NF>5{$(NF-2)=" x "} {print}')"
    if [ "$_cur_noissue" = "$_new_noissue" ]; then
      echo "status_block: issue counts have drifted; every other column agrees."
      echo "  Not a failure — an issue count is a fact about GitHub, not about this tree."
      echo "  Refresh when convenient: tools/status_block.sh --write"
      diff <(printf '%s\n' "$cur") <(printf '%s\n' "$new") | grep '^[<>]' | head -6 || true
      exit 0
    fi

    # ---- A SIBLING'S VERSION IS NOT A FACT ABOUT THIS TREE EITHER (#311) ---------------
    #
    # 0.25.0 made scaffold_upgrade refresh a declared block after an upgrade. That covers
    # this repo's OWN row -- the upgrade is what changed its .scaffold-version. It cannot
    # cover a SIBLING's row: a repo does not know who declares it, and a tool that writes
    # into other repositories to keep a gate green is worse than the gate it is keeping
    # green. So the tolerance has to live here, at the read.
    #
    # WHAT WAS ACTUALLY WRONG WAS THE ORDER-DEPENDENCE. Upgrade the block-declaring repo
    # FIRST and its block captures the siblings as they were a moment before; upgrade a
    # sibling next and the declaring repo is red on a row that is not about it. One pass
    # over four repos produced exactly that. Correctness that depends on the order of
    # independent operations holds until somebody does them the other way round.
    #
    # This is #288's cut, one column further out, and it lands on the same side: a fact
    # about THIS tree is a hard gate, a fact about somewhere else is orientation.
    #
    # THE TOLERANCE IS ONLY GRANTED WHEN THERE IS AN OWN ROW TO BE HELD TO. A block that
    # does not list its own repository is all siblings, and masking every row would leave a
    # gate that cannot fail on a version at all. No own row means no tolerance -- the
    # not-a-verdict rule, applied to a tolerance instead of a pass.
    _own="$(basename "$PWD")"
    if printf '%s\n' "$cur" | grep -qF "| \`$_own\` |"; then
      # ENVIRON[], not awk -v: a repo name is data, and `-v` runs its value through awk's
      # own conversion before the program ever sees it.
      _sibmask() {
        SB_OWN="$_own" awk -F'|' '
          BEGIN { own = ENVIRON["SB_OWN"] }
          NF>5 {
            name = $2
            gsub(/[`[:space:]]/, "", name)
            if (name != "" && name != "repo" && name !~ /^-+$/ && name != own) {
              print "|SIBLING-ROW-MASKED|"; next
            }
          }
          { print }'
      }
      _cur_nosib="$(printf '%s\n' "$_cur_noissue" | _sibmask)"
      _new_nosib="$(printf '%s\n' "$_new_noissue" | _sibmask)"
      if [ "$_cur_nosib" = "$_new_nosib" ]; then
        echo "status_block: only OTHER repositories' rows have drifted; this repo's own row agrees."
        echo "  Not a failure — a sibling's version is a fact about that repository, not this one,"
        echo "  and nothing here can refresh it at the moment it changes (#311)."
        echo "  Refresh when convenient: tools/status_block.sh --write"
        diff <(printf '%s\n' "$cur") <(printf '%s\n' "$new") | grep '^[<>]' | head -6 || true
        exit 0
      fi
    fi

    echo "status_block: STALE — run tools/status_block.sh --write" >&2
    diff <(printf '%s\n' "$cur") <(printf '%s\n' "$new") | head -12 >&2 || true
    exit 1 ;;
  *) echo "usage: status_block.sh [--write|--check|--status|--selftest]" >&2; exit 2 ;;
esac
