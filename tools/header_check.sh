#!/usr/bin/env bash
# Project:  ai-project-scaffold
# File:     tools/header_check.sh
# Modified: 2026-09-23
# Version:  0.7.6.20260923.0941
# Purpose:  Enforce the file-header and build-stamp rules the scaffold states but never checked.
# Changelog:
#   2026-09-23 v0.7.6.20260923.0941 — fixtures run inside the root tools/fixture_guard.sh validates. There a git and a mktemp on PATH refuse anything that would land outside it. Every mktemp takes a ${TMPDIR} template, because macOS mktemp ignores TMPDIR without one.
#   2026-09-23 v0.7.5.20260923.0843 — every mktemp fails closed. A failed one left the temp variable empty, so the fixture ran in the caller's directory; header_check's committed into Robiton/control.
#   2026-09-23 v0.7.4.20260923.0733 — EXCLUDE is applied once in source_candidates, not as a
#                                     printf|grep per path. godsfall: 28s -> 3.9s, output identical.
#   2026-09-22 v0.7.3.20260922.1549 — The future-stamp message says it compares LOCAL time
#                                     and names the zone (Clocktower #11): a UTC-stamped
#                                     header on a machine behind UTC read as 'typed, not
#                                     read' with no hint why.
#   2026-09-14 v0.7.2.20260914.0621 — #310 the four printf|grep -q pipelines the #306 sweep missed.
#   2026-09-13 v0.7.1.20260913.0807 — FIVE SELFTEST ASSERTIONS DID WHAT THIS FILE WARNS ABOUT
#                        TWICE (#306). Under `set -o pipefail` (line 147) `grep -q` exits at
#                        the first match, the writer on the left takes SIGPIPE, and the
#                        pipeline reports 141 -- so the assertion fails BECAUSE the string was
#                        found. Whether the writer finishes first is a scheduling race, which
#                        is the entire intermittency.
#                        THE NOTES AT --list-legacy AND AT THE RE-STAMP COUNTER ALREADY SAY
#                        THIS, each recording it as a defect that made every file come back
#                        FAIL on a first real run. Five assertions did it anyway; the worst
#                        piped "$SELF" ITSELF into grep -q, so a match killed the process
#                        whose output was being judged.
#                        COST: it blocked every release and every commit in any repo running
#                        the gate, whenever the race went the wrong way -- including a
#                        docs-only commit to `control`. Three correctly-captured samples read
#                        FAIL, FAIL, PASS, which produced a confident and wrong time-window
#                        theory on #306.
#                        RULED OUT FIRST, each by test and each wrong: my own changes
#                        (byte-identical to the tag), working-tree state (a pristine clone
#                        failed), TMPDIR debris (1,928 dirs cleared), the environment (env -i
#                        identical), concurrency (8/8 failed together AND it failed alone),
#                        and a midnight rollover (04:17 fails, nothing crosses a date).
#                        AND ONE FIX OF MINE WAS WRONG ON THE WAY: converting a LINE-oriented
#                        grep to a `case` glob matches across the whole multi-line string, so
#                        past.sh on one line and AHEAD on another satisfied it -- 20 runs out
#                        of 20 still failed. `grep -c` is the right form: it consumes all its
#                        input, so it cannot take SIGPIPE, and it stays line-oriented.
#                        VERIFIED OVER 30 CONSECUTIVE RUNS, because a race needs volume
#                        before a pass means anything. The other nine grep -q uses here are
#                        safe: single-line or few-byte writers that finish first.
#   2026-09-04 v0.7.0.20260904.0853 — A SQUASHED HISTORY CANNOT DATE ITS OWN FILES (#305). This reads the
#                        COMMITTER date, so in a repo whose whole history is one commit every
#                        file shares it and the baseline amnesty is STRUCTURALLY unreachable —
#                        which is exactly adoption_check's fixture. An adopter who declared a
#                        baseline, went green in their own repo, then saw adoption_check report
#                        the same files had NO action available that could fix it. New state 3,
#                        reported NOT MEASURED, distinct from 2 (shallow clone, where the
#                        history exists and refusing the amnesty is right). Scoped to
#                        baseline-declared + single-commit, so a fresh project with no baseline
#                        is still held to the rule.
#   2026-09-03 v0.6.0.20260903.0510 — A STAMP IN THE FUTURE FAILS AT COMMIT TIME, not at
#                        release (#287). `stamp_not_ahead` compares a stamp to the COMMIT
#                        that carries it, with a two-hour grace, and says nothing about the
#                        wall clock -- and it returns early on a file with no commit yet,
#                        which is every file at the moment it is written.
#                        MEASURED 2026-09-02: three stamps in one session written from
#                        memory rather than read from the clock. One was 17 minutes in the
#                        FUTURE and passed, because 17 minutes is inside the other check's
#                        grace. Two were behind, and behind-the-commit is the direction that
#                        check exists to allow. All three reached a commit.
#                        Nothing can legitimately be built at a time that has not happened.
#                        Five minutes of grace for clock skew and no more -- a wider window
#                        is exactly how a hand-typed stamp gets through. `Modified:` is
#                        checked as a date, because a file modified tomorrow is the same lie
#                        in a coarser unit.
#                        RUNS IN THE BARE FORM, deliberately. `--since` only sees files that
#                        CHANGED; the bare form is what setup.sh --check and a developer run,
#                        and a typed stamp is wrong when it is written, not when it is diffed.
#                        The selftest gives the past case its OWN fixture rather than reusing
#                        past.sh, which is stamped 20 minutes ahead on purpose. The two checks
#                        disagree about that file and both are right, and that disagreement is
#                        the reason this one exists.
#   2026-08-23 v0.5.0 — A HAND-TYPED STAMP AHEAD OF ITS OWN COMMIT IS NOW CAUGHT (#238). The
#                        format rule accepted any well-formed date, so a file re-stamped into
#                        next week satisfied every gate. It happened here: three headers
#                        written .1330/.1345/.1420 against a clock reading 0518/0537/0544, and
#                        preflight passed 38 gates over them three times. Caught only because
#                        `date` was run while cutting the release.
#                        COMPARED AGAINST THE COMMIT THAT CARRIES THE FILE, not against the
#                        clock. "Not in the future" sounds right and breaks every distributed
#                        team -- stamps are minted with local `date`, so a developer east of
#                        the CI runner is legitimately up to fourteen hours "ahead" of it. The
#                        commit's author date carries its own UTC offset and `--date=format:`
#                        renders it in that zone, so both sides come from one clock.
#                        Two hours of grace: a stamp is written before its commit, never after,
#                        and the gap is however long the gates take. Wide enough for any real
#                        cycle, far too narrow for the eight-hour case it exists to catch.
#                        Three selftest cases, both directions, mutation-verified.
#   2026-08-10 v0.4.0 — Document exit 3 in --help, per the convention now in
#                        ai/STANDARDS.md (#188).
#   2026-08-09 v0.3.1 — Say what was NOT checked, and what 'source file' means (#182).
#                        A bare run does not check build stamps and CI runs
#                        --since origin/main, so local green and CI red disagreed for a
#                        reason nothing on screen mentioned. --help now also states that
#                        --since reads the COMMITTED diff, and that .gd/.js/.ts/.go/.rs
#                        are out of scope — an adopter proved both to themselves the hard
#                        way, editing a .gd file and then a file already stamped on the
#                        branch, and concluded twice that they had broken something.
#   2026-08-09 v0.3.0 — SEE FILES THAT DO NOT EXIST YET (#166). Every file list here came
#                        from `git ls-files`, which is TRACKED ONLY — so a source file
#                        created and not yet `git add`ed was invisible to BOTH scans. It
#                        reported clean, and the same file failed CI on the commit that
#                        added it. That is one of the two red builds #166 was filed about:
#                        "a new .py with no header at all".
#                        The suite could not have caught it: its missing-header case ran
#                        `git add -A` first, so the untracked path was never once exercised.
#                        `source_candidates()` is tracked ∪ untracked (--exclude-standard, so
#                        .gitignore still decides what is not source), and --since unions the
#                        new files in as well. A new file is NEW, not "history unreadable" —
#                        it is never baseline-exempt, and it is asked for a complete header
#                        rather than for a stamp that CHANGED, which on a first version is
#                        an instruction with no action behind it.
#   2026-08-05 v0.2.1 — --adopt matches the SLOT'S SHAPE, not upstream's sentence. The
#                        shipped negative declaration asserted a fact about whatever repo
#                        the file landed in, so it had to be reworded — and a matcher keyed
#                        to that sentence would have broken silently.
#   2026-08-05 v0.2.0 — Declared baseline: the rule applies forward, not retroactively (#76)
#   2026-08-04 v0.1.0 — Initial creation
#
# WHY THIS EXISTS
#   ai/CODING.md -> File headers calls a header MANDATORY on every source file, and
#   ai/STANDARDS.md requires a build stamp on every PR. Nothing checked either one, and
#   the scaffold's own tools had drifted accordingly. Measured 2026-08-04, on the repo
#   that publishes the rule:
#
#     setup.sh                    header said 0.3.1.20260709.1050 — 4 versions and
#                                 ~4 weeks behind its own last change
#     tools/localcoder            substantially rewritten; header still said 2026-07-31
#     tools/session_archive.py    no Version line at all
#     sync-check.sh               no header at all
#     tools/audit_localcoder.sh   stale
#     tools/localcoder_bench.py   stale
#
#   This is the same failure as the archive ceiling that reached 1,001 lines: the rule
#   was stated, everyone agreed with it, and nothing was watching. A rule that depends
#   on remembering it at the end of a long session is a rule that quietly stops holding.
#
#   The stamp is not bookkeeping for its own sake. `Modified:` is how a reader decides
#   whether a comment describing a measurement still describes the code.
#
# WHAT COUNTS AS A SOURCE FILE HERE
#   Shell and Python — tracked `*.sh`, `*.py`, and extensionless tracked files whose
#   first line is a shebang. Markdown, JSON, SVG and workflow YAML are excluded: they
#   carry their provenance differently (front matter, a `name:` key) and stamping them
#   would be ceremony rather than information. EXCLUDE is the escape hatch; add to it in
#   a reviewed commit, so an exemption is a decision rather than an oversight.
#
# THE RULE APPLIES FORWARD, NOT RETROACTIVELY
#   Reported from a real 0.5.0 -> 0.6.3 upgrade (#76): making this check blocking failed an
#   existing adoption's ENTIRE codebase at once — 33 files written long before the standard
#   was — and the PR could not merge. The cost scales with how old and large a project is,
#   so it lands hardest on exactly the projects with the most to gain from upgrading, and
#   the likely outcome is not that people write 33 headers. It is that they stop upgrading.
#
#   Both escape hatches at the time lived in files `scaffold_upgrade.sh` REPLACES — EXCLUDE
#   below, and --warn-only wired into the workflow — so any local accommodation was erased
#   by the next upgrade. And downgrading a blocking check locally is precisely the loosening
#   `ai/STANDARDS.md` -> *Rule precedence* forbids, so an adopter who followed the standards
#   had no sanctioned way out and one who worked around it broke a different rule to do it.
#
#   So the exemption is DECLARED, in a file upgrades merge rather than overwrite:
#
#       <!-- scaffold:header-baseline YYYY-MM-DD -->      in ai/STANDARDS.md
#
#   A tracked source file whose last commit predates that date is `legacy`: reported,
#   counted, and NOT failed. Touch it and it is in scope on the spot — the baseline exempts
#   history, never future work. No marker means no exemption, so a project that adopts the
#   standard on day one is unaffected and nothing is inferred from absence.
#
#   `--adopt` writes the marker and prints exactly what it exempts, so the amnesty is a
#   visible decision with a number attached rather than a checker quietly going soft.
#
# Usage:
#   tools/header_check.sh                 # every tracked source file has a valid header
#   tools/header_check.sh --since <ref>   # every file changed since <ref> was re-stamped
#   tools/header_check.sh --since origin/main --warn-only    # report, always exit 0
#   tools/header_check.sh --adopt         # declare today as this project's header baseline
#   tools/header_check.sh --list-legacy   # name the files the baseline is exempting
#   tools/header_check.sh --no-baseline   # ignore any declared baseline; check everything
set -uo pipefail

cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

SINCE=""
WARN_ONLY=0
BASELINE=""          # resolved below unless --no-baseline / --baseline override
NO_BASELINE=0
ADOPT=0
LIST_LEGACY=0
STANDARDS="ai/STANDARDS.md"

# ANCHORED TO COLUMN 0, AND THAT IS LOAD-BEARING. Three markers in this scaffold are read
# from the same file that documents them, and an unanchored pattern matches its own
# documentation: `scaffold:localcoder-forked` did exactly that, and the drift check it
# gated could not fail. A declaration sits at column 0; a documented example is indented.
BASELINE_SED='s/^<!--[[:space:]]*scaffold:header-baseline[[:space:]]+([0-9]{4}-[0-9]{2}-[0-9]{2})[[:space:]]*-->[[:space:]]*$/\1/p'

read_baseline() {
  [ -f "$STANDARDS" ] || return 0
  sed -nE "$BASELINE_SED" "$STANDARDS" 2>/dev/null | head -1
}

while [ $# -gt 0 ]; do
  case "$1" in
    --since) SINCE="${2:-}"; [ -n "$SINCE" ] || { echo "header_check: --since needs a ref" >&2; exit 2; }; shift 2 ;;
    --warn-only) WARN_ONLY=1; shift ;;
    --baseline)
      BASELINE="${2:-}"
      case "$BASELINE" in
        [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]) ;;
        *) echo "header_check: --baseline needs a YYYY-MM-DD date" >&2; exit 2 ;;
      esac
      shift 2 ;;
    --no-baseline) NO_BASELINE=1; shift ;;
    --list-legacy) LIST_LEGACY=1; shift ;;
    --adopt) ADOPT=1; shift ;;
    --selftest)
      # A CHECKER WITH NO NEGATIVE TEST IS THE DEFECT IT EXISTS TO CATCH. This whole
      # round of fixes came from suites that passed while the behaviour was broken, and
      # this tool's own first run reported every file FAIL because `grep -q` under
      # `set -o pipefail` made git die of SIGPIPE. Prove both directions on a throwaway
      # repo: it must FAIL an unstamped change and PASS a stamped one.
      # FAIL CLOSED ON MKTEMP. Unguarded, a failed mktemp left TD empty, `cd ""` was a no-op,
      # and the fixture below ran git init/add/commit in the REAL repo. On 2026-09-23, under a
      # Claude Code sandbox, that committed tools/thing.sh into Robiton/control and a push
      # published it. Every mktemp in tools/ now stops the same way.
      # FIXTURES RUN INSIDE A GUARDED ROOT (tools/fixture_guard.sh). Later mktemps land inside it,
      # and a git on PATH refuses any write outside it. The guard exists because a failed mktemp
      # once let a selftest run git init and commit in the real repo.
      . "$(dirname "${BASH_SOURCE[0]}")/fixture_guard.sh" || { echo "header_check: tools/fixture_guard.sh is missing; refusing to build fixtures" >&2; exit 1; }
      fixture_root FG_ROOT; trap fg_cleanup EXIT
      TD="$(mktemp -d "${TMPDIR:-/tmp}/header_check.XXXXXX")" || { echo "header_check: mktemp failed; stopping" >&2; exit 1; }; trap 'rm -rf "$TD"; fg_cleanup' EXIT
      ORIG="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
      # COPY THE TOOL INTO THE FIXTURE REPO AND RUN IT FROM THERE. This script resolves
      # its root from its own location, so invoking the installed copy would have
      # audited THIS repo while the fixture sat untouched — the test would have passed
      # by measuring the wrong thing, which is the failure mode this round is about.
      SELF="$TD/tools/header_check.sh"
      (
        cd "$TD"
        git init -q . && git config user.email a@b.c && git config user.name t
        mkdir tools
        cp "$ORIG" "$SELF"
        cat > tools/thing.sh <<'SEED'
#!/usr/bin/env bash
# Project:  t
# File:     tools/thing.sh
# Modified: 2026-01-01
# Version:  1.0.0.20260101.0000
# Purpose:  seed
echo hi
SEED
        git add -A && git commit -qm base
        base="$(git rev-parse HEAD)"

        echo "echo more" >> tools/thing.sh          # changed, NOT re-stamped
        if "$SELF" --since "$base" >/dev/null 2>&1; then
          echo "  FAIL  an unstamped change was reported clean"; exit 1
        fi
        echo "  ok    unstamped change is caught"

        sed -i.bak 's/# Modified: 2026-01-01/# Modified: 2026-08-04/' tools/thing.sh
        sed -i.bak 's/1\.0\.0\.20260101\.0000/1.0.1.20260804.1800/' tools/thing.sh
        rm -f tools/thing.sh.bak
        if "$SELF" --since "$base" >/dev/null 2>&1; then
          echo "  ok    re-stamped change passes"
        else
          echo "  FAIL  a correctly re-stamped change was reported dirty"; exit 1
        fi

        # A NEW FILE, NOT YET `git add`ed. THIS ORDER IS THE WHOLE POINT (#166): the case
        # below used to run `git add -A` FIRST, so every file list this tool builds — all of
        # which came from `git ls-files` — could stay tracked-only and still pass. A source
        # file created and not staged was invisible to both scans, reported clean, and failed
        # CI on the commit that added it. That was one of the two red builds #166 reports.
        printf '#!/usr/bin/env bash\necho no header\n' > tools/bare.sh
        if "$SELF" >/dev/null 2>&1; then
          echo "  FAIL  an UNTRACKED file with no header was reported clean"; exit 1
        fi
        echo "  ok    a new file is checked before it is staged"
        # The count BEFORE the new file exists. Asserting an absolute number here failed
        # against a fixture that already carries one re-stamped file — a test tied to the
        # fixture's history rather than to the behaviour, which is how a suite starts
        # needing maintenance for reasons unrelated to the code.
        stamped_before="$(rm -f tools/bare.sh; "$SELF" --since "$base" 2>&1 \
                          | sed -nE 's/.*  ([0-9]+) changed source file\(s\) correctly re-stamped/\1/p')"

        # ...and a new file that DOES arrive with a header must pass, AND BE COUNTED.
        # The first version of this pair also asserted that `--since` fails on the
        # unheadered file above — which it does, but for the wrong reason: the completeness
        # scan runs in the same invocation and has already set the failure, so that case
        # could not tell the --since union from its absence. It is the COUNT that only the
        # union can move, so the count is what is asserted.
        cat > tools/fresh.sh <<'FRESH'
#!/usr/bin/env bash
# Project:  t
# File:     tools/fresh.sh
# Modified: 2026-08-09
# Version:  0.1.0.20260809.1200
# Purpose:  a new file that arrived correctly headered
echo fresh
FRESH
        rm -f tools/bare.sh
        fresh_out="$("$SELF" --since "$base" 2>&1)"; fresh_rc=$?
        if [ "$fresh_rc" -ne 0 ]; then
          echo "  FAIL  a new file with a complete header was failed for not re-stamping"
          printf '%s\n' "$fresh_out" | sed 's/^/        /'; exit 1
        fi
        echo "  ok    a correctly headered new file passes --since"
        stamped_after="$(printf '%s' "$fresh_out" \
                         | sed -nE 's/.*  ([0-9]+) changed source file\(s\) correctly re-stamped/\1/p')"
        if [ "${stamped_after:-0}" -eq $(( ${stamped_before:-0} + 1 )) ]; then
          echo "  ok    --since counts new files, not only files git already knows"
        else
          echo "  FAIL  a new file was not counted by --since (${stamped_before:-?} -> ${stamped_after:-?})"
          printf '%s\n' "$fresh_out" | sed 's/^/        /'; exit 1
        fi
        rm -f tools/fresh.sh

        printf '#!/usr/bin/env bash\necho no header\n' > tools/bare.sh
        git add -A
        if "$SELF" >/dev/null 2>&1; then
          echo "  FAIL  a file with no header was reported clean"; exit 1
        fi
        echo "  ok    missing header is caught"

        # ---- the baseline: the rule applies FORWARD, not retroactively (#76) ----
        git rm -q --cached tools/bare.sh >/dev/null 2>&1; rm -f tools/bare.sh
        git add -A && git commit -qm restamped
        mkdir -p ai && printf '# Standards\n' > ai/STANDARDS.md
        printf 'print("written long before the standard was")\n' > legacy.py
        OLD='2020-01-01T00:00:00+0000'
        GIT_AUTHOR_DATE="$OLD" GIT_COMMITTER_DATE="$OLD" git add -A
        GIT_AUTHOR_DATE="$OLD" GIT_COMMITTER_DATE="$OLD" git commit -qm legacy

        if "$SELF" >/dev/null 2>&1; then
          echo "  FAIL  a headerless file passed with NO baseline declared"; exit 1
        fi
        echo "  ok    no baseline means no exemption"

        MARK='<!-- scaffold:header-baseline 2021-01-01 -->'
        printf '%s\n' "$MARK" >> ai/STANDARDS.md
        if "$SELF" >/dev/null 2>&1; then
          echo "  ok    a file predating the baseline is exempt"
        else
          echo "  FAIL  a pre-baseline file was still failed"; exit 1
        fi

        # PROVE THE EXEMPTION IS WHAT PASSED IT. Without this the case above also passes if
        # the checker silently stopped examining legacy.py for some unrelated reason — a
        # test that cannot distinguish "exempted" from "not looked at" proves neither.
        if "$SELF" --no-baseline >/dev/null 2>&1; then
          echo "  FAIL  --no-baseline still honoured the baseline"; exit 1
        fi
        echo "  ok    --no-baseline holds every file to the rule"

        # A MARKER MUST BE DECLARED AT COLUMN 0, NOT MERELY MENTIONED. ai/STANDARDS.md
        # documents this marker, and an unanchored pattern matches its own documentation —
        # which is exactly how scaffold:localcoder-forked disabled the check it gated.
        printf '# Standards\n    %s\n' "$MARK" > ai/STANDARDS.md
        if "$SELF" >/dev/null 2>&1; then
          echo "  FAIL  an INDENTED marker (documentation) granted the exemption"; exit 1
        fi
        echo "  ok    an indented marker is documentation, not a declaration"
        printf '# Standards\n%s\n' "$MARK" > ai/STANDARDS.md

        printf 'print("new file, after the baseline")\n' > fresh.py
        git add -A && git commit -qm fresh
        if "$SELF" >/dev/null 2>&1; then
          echo "  FAIL  a file created AFTER the baseline was exempted"; exit 1
        fi
        echo "  ok    the baseline exempts history, not new files"
        git rm -qf fresh.py && git commit -qm drop-fresh

        printf 'print("touched")\n' >> legacy.py
        if "$SELF" >/dev/null 2>&1; then
          echo "  FAIL  an EDITED legacy file kept its exemption"; exit 1
        fi
        echo "  ok    editing a legacy file ends its exemption"
        git checkout -- legacy.py

        # ---- --adopt ----
        printf '# Standards\n' > ai/STANDARDS.md      # drop the hand-written marker
        if "$SELF" --adopt >/dev/null 2>&1; then :; else
          echo "  FAIL  --adopt exited non-zero"; exit 1
        fi
        if [ "$(grep -cE '^<!--[[:space:]]*scaffold:header-baseline' ai/STANDARDS.md)" != "1" ]; then
          echo "  FAIL  --adopt did not write exactly one anchored marker"; exit 1
        fi
        if "$SELF" >/dev/null 2>&1; then
          echo "  ok    --adopt declares a baseline that makes the tree pass"
        else
          echo "  FAIL  the tree still failed after --adopt"; exit 1
        fi

        "$SELF" --adopt >/dev/null 2>&1
        if [ "$(grep -cE '^<!--[[:space:]]*scaffold:header-baseline' ai/STANDARDS.md)" != "1" ]; then
          echo "  FAIL  a second --adopt wrote a second marker"; exit 1
        fi
        echo "  ok    --adopt is idempotent"

        # CAPTURE, do not pipe into `grep -q`. Under `set -o pipefail` grep -q exits at the
        # first match, "$SELF" takes SIGPIPE, and the pipeline reports 141 — so the assertion
        # fails precisely BECAUSE the string was found. That is the same defect this tool's
        # own first run had, reproduced here in the test written to check the fix for it.
        out="$("$SELF" --list-legacy 2>&1 || true)"
        case "$out" in
          *legacy.py*) echo "  ok    --list-legacy names the exempted file" ;;
          *) echo "  FAIL  --list-legacy did not name the exempted file"; exit 1 ;;
        esac

        # --adopt MUST FILL THE SLOT THE STANDARD SHIPS, NOT APPEND TO EOF. Verified on a
        # real 0.5.0 -> 0.6.3 upgrade: an EOF marker conflicted, because upstream grows this
        # file by appending and the two edits landed adjacent.
        printf '# Standards\n<!-- scaffold:header-baseline — not declared; the form to use is shown below -->\ntrailing section\n' > ai/STANDARDS.md
        "$SELF" --adopt >/dev/null 2>&1
        if [ "$(wc -l < ai/STANDARDS.md)" -ne 3 ]; then
          echo "  FAIL  --adopt appended instead of filling the shipped slot"; exit 1
        fi
        if ! sed -n 2p ai/STANDARDS.md | grep -qE '^<!-- scaffold:header-baseline [0-9]{4}-[0-9]{2}-[0-9]{2} -->$'; then
          echo "  FAIL  --adopt did not write the marker into the shipped slot"; exit 1
        fi
        echo "  ok    --adopt fills the slot the standard ships, in place"

        # THE SLOT IS A SHAPE, NOT A SENTENCE. The first version matched upstream's exact
        # prose, which then had to change — the shipped wording asserted a fact about
        # whatever repo the file landed in, and was false in every repo that merged it.
        printf '# Standards\n<!-- scaffold:header-baseline anything at all here -->\ntrailing\n' > ai/STANDARDS.md
        "$SELF" --adopt >/dev/null 2>&1
        if ! sed -n 2p ai/STANDARDS.md | grep -qE '^<!-- scaffold:header-baseline [0-9]{4}-[0-9]{2}-[0-9]{2} -->$'; then
          echo "  FAIL  --adopt did not recognise a slot worded differently"; exit 1
        fi
        echo "  ok    --adopt matches the slot's shape, not upstream's wording"

        # AND IT MUST NOT OVERWRITE A REAL DECLARATION that sits above the slot.
        printf '# Standards\n<!-- scaffold:header-baseline 2021-01-01 -->\n<!-- scaffold:header-baseline — not declared -->\n' > ai/STANDARDS.md
        "$SELF" --adopt >/dev/null 2>&1
        if ! sed -n 2p ai/STANDARDS.md | grep -q '2021-01-01'; then
          echo "  FAIL  --adopt overwrote an existing declaration"; exit 1
        fi
        echo "  ok    --adopt never overwrites an existing declaration"

        # AN AMNESTY FOR A PROBLEM YOU DO NOT HAVE IS A PERMANENT EXEMPTION. A compliant
        # tree must be told to skip the marker, not handed one for later.
        git rm -qf legacy.py && git commit -qm drop-legacy
        printf '# Standards\n' > ai/STANDARDS.md
        "$SELF" --adopt >/dev/null 2>&1
        if grep -qE '^<!--[[:space:]]*scaffold:header-baseline' ai/STANDARDS.md; then
          echo "  FAIL  --adopt baselined an already-compliant tree"; exit 1
        fi
        echo "  ok    --adopt refuses when there is nothing to exempt"

        # ---- A HAND-TYPED STAMP AHEAD OF ITS OWN COMMIT (#238) ----------------------
        # Three of these shipped on 2026-08-20 -- .1330, .1345, .1420 against a clock
        # reading 0518, 0537, 0544 -- and preflight passed 38 gates over them, three
        # times. BOTH DIRECTIONS, because a check that fails everything would pass the
        # first case here and be worse than no check.
        printf '# Standards\n' > ai/STANDARDS.md
        printf '#!/usr/bin/env bash\n# Project:  t\n# File:     past.sh\n# Modified: 2026-01-01\n# Version:  0.1.0.20260101.0000\n# Purpose:  stamped before its commit\necho a\n' > past.sh
        printf '#!/usr/bin/env bash\n# Project:  t\n# File:     ahead.sh\n# Modified: 2026-01-01\n# Version:  0.1.0.20260101.0000\n# Purpose:  stamped after its commit\necho a\n' > ahead.sh
        git add -A >/dev/null && git commit -qm stamps && git tag stamps
        # Re-stamp both: one a few minutes on, one eight hours on -- the measured case.
        _near="$(python3 -c 'import datetime;print((datetime.datetime.now()+datetime.timedelta(minutes=20)).strftime("%Y%m%d.%H%M"))')"
        _far="$(python3 -c 'import datetime;print((datetime.datetime.now()+datetime.timedelta(hours=8)).strftime("%Y%m%d.%H%M"))')"
        printf 'echo b\n' >> past.sh && printf 'echo b\n' >> ahead.sh
        sed -i.bak "s/0\.1\.0\.20260101\.0000/0.2.0.$_near/" past.sh
        sed -i.bak "s/0\.1\.0\.20260101\.0000/0.2.0.$_far/"  ahead.sh
        rm -f past.sh.bak ahead.sh.bak
        git add -A >/dev/null && git commit -qm restamp
        _out="$("$SELF" --since stamps 2>&1 || true)"
        # CASE, not `printf | grep -q` — THE THIRD INSTANCE OF THIS TRAP IN THIS FILE, and
        # the first two are documented above at --list-legacy and in the re-stamp counter.
        # Under `set -o pipefail` grep -q exits at the FIRST match, printf takes SIGPIPE, and
        # the pipeline reports 141 — so the assertion fails precisely BECAUSE the string was
        # found. Whether printf has finished writing before grep exits is a scheduling race,
        # which is why this failed intermittently for a day and looked like a clock bug:
        # three correctly-captured samples said FAIL, FAIL, PASS, and the PASS was luck.
        # Ruled out along the way, each by test: the working tree (a pristine clone failed),
        # TMPDIR debris, the environment (`env -i` identical), and concurrency (8/8 failed
        # together and it failed alone too). None of them was it. `case` never pipes.
        case "$_out" in
          *ahead.sh*) : ;;
          *) echo "  FAIL  a stamp eight hours ahead of its commit was accepted"; exit 1 ;;
        esac
        echo "  ok    a stamp ahead of its own commit is caught"
        # COUNT, not `case` and not `grep -q`. This assertion is LINE-ORIENTED: it asks
        # whether past.sh and AHEAD appear on the SAME line. A `case` glob matches across the
        # whole multi-line string, so `*past.sh*AHEAD*` is satisfied by past.sh on one line
        # and ahead.sh's AHEAD on another -- which is exactly what my first fix did, turning
        # this into a false positive that failed 20 runs out of 20. `grep -c` reads all of
        # its input, so it cannot take SIGPIPE the way `grep -q` does; that is the form this
        # file already prescribes for the re-stamp counter, and the reason is the same.
        _grace="$(printf '%s\n' "$_out" | grep -c 'past\.sh.*AHEAD' || true)"
        if [ "${_grace:-0}" != "0" ]; then
          echo "  FAIL  a stamp inside the grace window was reported"; exit 1
        fi
        echo "  ok    and one inside the grace window is not"
        if "$SELF" --since stamps >/dev/null 2>&1; then
          echo "  FAIL  the finding did not reach the exit code"; exit 1
        fi
        echo "  ok    and the finding reaches the exit code"

        # A STAMP IN THE FUTURE IS A DIFFERENT QUESTION, and the bare form must catch it.
        # `--since` only sees files that CHANGED; the bare form is what setup.sh --check and
        # a developer run. MEASURED 2026-09-02: three stamps written from memory reached a
        # commit in one session, and the one 17 minutes AHEAD passed stamp_not_ahead because
        # 17 minutes is inside its two-hour grace. Different check, different window.
        _fut="$(date -v+1H "+%Y%m%d.%H%M" 2>/dev/null || date -d "+1 hour" "+%Y%m%d.%H%M")"
        _tom="$(date -v+1d "+%Y-%m-%d" 2>/dev/null || date -d "+1 day" "+%Y-%m-%d")"
        printf '#!/usr/bin/env bash\n# Project:  t\n# File:     later.sh\n# Modified: %s\n# Version:  0.1.0.%s\n# Purpose:  stamped in the future\necho a\n' \
          "$(date +%Y-%m-%d)" "$_fut" > later.sh
        printf '#!/usr/bin/env bash\n# Project:  t\n# File:     tomorrow.sh\n# Modified: %s\n# Version:  0.1.0.%s\n# Purpose:  modified tomorrow\necho a\n' \
          "$_tom" "$(date +%Y%m%d.%H%M)" > tomorrow.sh
        _fout="$("$SELF" 2>&1 || true)"
        # COUNT, never `grep -q`, for every one of these. See the note on the --since
        # assertions above: `grep -q` exits at the first match, the writer on the left takes
        # SIGPIPE, and under `set -o pipefail` the pipeline reports 141 — so the assertion
        # fails BECAUSE the string was found. `grep -c` consumes all of its input.
        _l="$(printf '%s\n' "$_fout" | grep -c 'later\.sh.*FUTURE' || true)"
        if [ "${_l:-0}" = "0" ]; then
          echo "  FAIL  a Version stamp an hour in the future was accepted"; exit 1
        fi
        echo "  ok    a Version stamp in the future is caught by the BARE form"
        _t="$(printf '%s\n' "$_fout" | grep -c 'tomorrow\.sh.*FUTURE' || true)"
        if [ "${_t:-0}" = "0" ]; then
          echo "  FAIL  a Modified: date of tomorrow was accepted"; exit 1
        fi
        echo "  ok    and so is a Modified: date of tomorrow"
        # AND THE PAST IS STILL FINE. A check that flagged both directions would fail every
        # file in the repo, which is how a gate gets switched off. Its own fixture, NOT
        # past.sh -- that one is stamped 20 minutes AHEAD on purpose, to sit inside
        # stamp_not_ahead's two-hour grace. The two checks disagree about it and both are
        # right: 20 minutes ahead of the commit is tolerable, 20 minutes ahead of the CLOCK
        # is a typed stamp. That disagreement is the whole reason this check exists.
        _old="$(date -v-2H "+%Y%m%d.%H%M" 2>/dev/null || date -d "-2 hours" "+%Y%m%d.%H%M")"
        printf '#!/usr/bin/env bash\n# Project:  t\n# File:     earlier.sh\n# Modified: %s\n# Version:  0.1.0.%s\n# Purpose:  stamped in the past\necho a\n' \
          "$(date +%Y-%m-%d)" "$_old" > earlier.sh
        # THE WORST OF THE THREE: this piped the TOOL ITSELF into `grep -q`, so a match
        # killed the very process whose output was being judged. Capture, then count.
        _eout="$("$SELF" 2>&1 || true)"
        _e="$(printf '%s\n' "$_eout" | grep -c 'earlier\.sh.*FUTURE' || true)"
        if [ "${_e:-0}" != "0" ]; then
          echo "  FAIL  a stamp two hours in the PAST was reported as future"; exit 1
        fi
        echo "  ok    and a stamp in the past is not"
        rm -f later.sh tomorrow.sh earlier.sh
      ) || { echo "header_check: selftest FAILED"; exit 1; }
      echo "header_check: selftest passed"
      exit 0 ;;
    -h|--help)
      cat <<'USAGE'
header_check.sh — verify the file-header and build-stamp rules in ai/CODING.md.

  (no args)              every tracked shell/python file carries a complete header
  --since <ref>          additionally: every such file changed since <ref> had its
                         Modified:/Version: line changed too (build-stamp every PR)
  --warn-only            report findings but always exit 0
  --adopt                declare today as this project's header baseline, in
                         ai/STANDARDS.md, and report what that exempts
  --baseline <date>      use this baseline instead of the declared one (YYYY-MM-DD)
  --no-baseline          ignore any declared baseline — hold every file to the rule
  --list-legacy          name the exempted files instead of only counting them
  --selftest             prove on a throwaway repo that this tool fails what it should
  -h, --help             this message

THE BASELINE. A file whose last commit predates the declared baseline is `legacy`:
reported, counted, never failed. Edit it and it is in scope immediately — the baseline
exempts history, not future work. Declare one when adopting the standard into an
existing codebase; a project that starts with it needs no marker at all.

WHAT "SOURCE FILE" MEANS HERE, because it is narrower than it sounds and the output does
not say so. Tracked shell and python files, plus EXTENSIONLESS tracked files with a
shebang (that is how `tools/localcoder` is covered). **`.gd`, `.js`, `.ts`, `.go`, `.rs`
and `.md` are NOT in scope** — editing one and expecting a finding proves nothing, and an
adopter lost time to exactly that.

`--since` READS THE COMMITTED DIFF (plus the working tree and untracked files). Run it
before `git commit` and it reports clean on changes it has not been shown. Order matters:

    git commit ...  &&  tools/preflight.sh  &&  git push

A second edit to a file already re-stamped on this branch also proves nothing — a stamp
cannot go stale twice. To see this tool fail on purpose, commit a change to a file that
this branch has NOT already touched.

CI RUNS `--since origin/main`, NOT THE BARE FORM. The bare run is a strictly weaker check,
so local green and CI red can disagree for a reason you cannot see. `tools/preflight.sh`
runs both and is the command to reach for.

Exit codes: 0 clean, 1 findings, 2 usage error, 3 SKIPPED (verified nothing —
git unavailable). See ai/STANDARDS.md -> 'Exit 3 means I verified nothing'.
USAGE
      exit 0 ;;
    *) echo "header_check: unknown argument '$1' (try --help)" >&2; exit 2 ;;
  esac
done

# Files exempt from the header rule, with the reason. An exemption is a decision.
EXCLUDE='^(tools/__pycache__/|.*\.md$|.*\.json$|.*\.svg$|.*\.png$|.*\.docx$)'

is_source() {
  case "$1" in
    *.sh|*.py) return 0 ;;
    *.*)       return 1 ;;   # any other extension is not in scope
    *)         head -c 2 "$1" 2>/dev/null | grep -q '^#!' ;;   # extensionless + shebang
  esac
}

fail=0
legacy=0
squashed=0
note() { printf '  [%s] %-32s %s\n' "$1" "$2" "$3"; }

# ------------------------------------------------------------------------ the baseline
[ -n "$BASELINE" ] || BASELINE="$(read_baseline)"
[ "$NO_BASELINE" = "1" ] && BASELINE=""

# Uncommitted edits count as TOUCHED, so a local run agrees with CI. Without this a file
# you have modified but not yet committed still reports its old commit date and would be
# exempted locally, then fail the moment it reached a pull request — the checker
# disagreeing with itself depending on where it ran.
DIRTY="|$(git diff --name-only HEAD 2>/dev/null | tr '\n' '|')"

# A BRAND-NEW FILE IS THE ONE THIS TOOL COULD NOT SEE (#166). Every file list here came from
# `git ls-files`, which is TRACKED ONLY, so a source file created and not yet `git add`ed was
# invisible to both forms of the check — it reported clean, and the same file failed CI the
# moment it was committed. That is one of the two red builds #166 was filed about: "a new .py
# with no header at all". The tool's own selftest could not catch it either, because its
# missing-header case runs `git add -A` first.
#
# --exclude-standard so .gitignore still decides what is not source; a build directory must
# not start producing header findings.
UNTRACKED="|$(git ls-files --others --exclude-standard 2>/dev/null | tr '\n' '|')"

# Tracked files PLUS new ones, minus EXCLUDE. One definition, used by both scans below.
# EXCLUDE IS APPLIED HERE, ONCE, not per file in the loops: a `printf | grep` per path cost
# two processes each, and godsfall's 3,991 files (3,731 of them game assets) made this tool
# 26s against 3s for the scaffold -- inside a fixture preflight that runs twice per CI job
# under an 8-minute ceiling. Same pattern, same lines filtered; one grep instead of 3,991.
source_candidates() {
  { git ls-files 2>/dev/null
    git ls-files --others --exclude-standard 2>/dev/null
  } | sort -u | { grep -vE "$EXCLUDE" || true; }
}

is_untracked() {
  case "$UNTRACKED" in *"|$1|"*) return 0 ;; esac
  return 1
}

# 0 = in scope, 1 = predates the baseline (exempt), 2 = cannot tell (history unreadable),
# 3 = cannot DISCRIMINATE (the whole history is one commit, so every file shares its date)
touched_since_baseline() {
  case "$DIRTY" in *"|$1|"*) return 0 ;; esac
  # A file with no history is NEW, not unreadable. Without this the untracked files added
  # above fall through to the git-log probe, come back empty, and are reported as "history
  # unreadable — shallow clone?", which is both wrong and unactionable. New code is exactly
  # what a baseline is NOT meant to exempt.
  is_untracked "$1" && return 0
  # A SQUASHED HISTORY CANNOT DATE ITS OWN FILES (#305).
  #
  # This reads the COMMITTER date, so in a repository whose entire history is one commit
  # every file carries that commit's date and the comparison below can only ever say "on or
  # after the baseline". The amnesty is not merely hard to reach there — it is structurally
  # unreachable, for every file, always.
  #
  # That is exactly the shape of tools/adoption_check.sh's fixture: it copies the tracked
  # tree, `git init`, one commit. So an adopter who declared a baseline, watched
  # header_check go green in their own repo, and then watched adoption_check report the same
  # files as failures had NO ACTION AVAILABLE that could fix it. Found by an adoption session
  # that ran --adopt on my advice and reported back that my advice was wrong.
  #
  # SCOPED TIGHTLY. This only fires when a baseline is DECLARED and the history is a single
  # commit. A fresh project created by setup.sh has one commit and no baseline, so every file
  # there is still held to the rule — which is right, they were all written today. A real
  # adopter has history, so nothing changes for them either.
  if [ "$(git rev-list --count HEAD 2>/dev/null || echo 0)" = "1" ]; then
    return 3
  fi
  _d="$(git log -1 --format=%cI -- "$1" 2>/dev/null | cut -c1-10)"
  [ -n "$_d" ] || return 2
  [ "$_d" \< "$BASELINE" ] && return 1
  return 0
}

# Route every header-completeness finding through here, so the baseline is applied in one
# place rather than at each of the three points that can fail a file.
report() {
  if [ -n "$BASELINE" ]; then
    touched_since_baseline "$1"; _t=$?
    if [ "$_t" = "1" ]; then
      legacy=$((legacy + 1))
      [ "$LIST_LEGACY" = "1" ] && note "legacy" "$1" "$2 (last touched before $BASELINE)"
      return
    fi
    # A COMPARISON THAT COULD NOT RUN IS NOT AN EXEMPTION. Same rule as --since below:
    # if history is unavailable (a shallow clone), we cannot prove the file is old, so
    # the amnesty is refused rather than granted on a guess.
    # 3 IS NOT 2, AND THE DIFFERENCE IS THE WHOLE POINT. A shallow clone HAS history we
    # cannot see, so refusing the amnesty is right — fetch it and the answer appears. A
    # single-commit repository has no history to fetch: every file genuinely shares one
    # date and no baseline can ever discriminate. Failing there asks the adopter for
    # something no action of theirs can produce.
    if [ "$_t" = "3" ]; then
      squashed=$((squashed + 1))
      return
    fi
    if [ "$_t" = "2" ]; then
      note FAIL "$1" "$2 — and its history is unreadable, so the $BASELINE baseline cannot be applied (shallow clone? use fetch-depth: 0)"
      fail=1
      return
    fi
  fi
  note FAIL "$1" "$2"
  fail=1
}

# A STAMP TYPED BY HAND IS NOT CHECKED AGAINST ANYTHING (#238). The format rule below accepts
# any well-formed date, so a file re-stamped into next week satisfies every gate. It happened:
# three headers written `.1330`, `.1345`, `.1420` while the clock read `0518`, `0537`, `0544`
# — eight hours ahead — and preflight passed 38 gates three times over them. It was caught only
# because `date` was run while cutting the release.
#
# ai/STANDARDS.md states the cost: a stamp rounded forward makes the next honest release sort
# EARLIER than its predecessor, and every benchmark row and envelope carries a version, so the
# corpus sorts wrong from then on.
#
# COMPARED AGAINST THE COMMIT THAT CARRIES THE FILE, NOT AGAINST THE CLOCK. "Not in the future"
# sounds right and breaks every distributed team: stamps are minted with local `date`, so a
# developer east of the CI runner is legitimately up to fourteen hours "ahead" of it. The
# commit's author date is recorded WITH its own UTC offset, and `--date=format:` renders it in
# that same zone — so both sides of this comparison come from one clock, whoever owns it.
#
# Two hours of grace: a stamp is written before the commit that carries it, never after, and
# the gap is however long the gates take. Wide enough for any real stamp-then-commit cycle,
# far too narrow for the eight-hour case this exists to catch.
# A STAMP MAY NOT SIT IN THE FUTURE, AND THAT IS A DIFFERENT QUESTION FROM stamp_not_ahead.
#
# `stamp_not_ahead` compares the stamp to the COMMIT that carries it, with a two-hour grace.
# It says nothing about the wall clock, and it returns early on a file with no commit yet --
# which is every file at the moment you are writing it.
#
# MEASURED 2026-09-02, three stamps in one session written from memory rather than read from
# the clock: one 17 minutes in the future, two behind it. Every one reached a commit. The
# future one passed `stamp_not_ahead` because 17 minutes is inside its grace, and the two
# behind passed because behind-the-commit is the direction that check exists to allow.
#
# A stamp ahead of NOW is unambiguous: nothing can legitimately be built at a time that has
# not happened. Five minutes of grace for clock skew between a checkout and a runner, and no
# more -- a wider window is how a hand-typed stamp gets through, which is the whole defect.
#
# THE DATE-ONLY FIELD IS CHECKED TOO. `Modified:` is a date, so it is compared as a date;
# a file modified tomorrow is the same lie in a coarser unit.
stamp_not_future() {
  _snf_f="$1"
  _snf_now="$(date +%Y%m%d%H%M)"
  _snf_ver="$(grep -m1 -E '^#[[:space:]]*Version:' "$_snf_f" 2>/dev/null \
              | sed 's/.*Version:[[:space:]]*//' | tr -d '[:space:]')"
  case "$_snf_ver" in
    *.*.*.*.*)
      _snf_stamp="$(printf '%s' "$_snf_ver" | awk -F. '{print $(NF-1) $NF}')"
      case "$_snf_stamp" in
        *[!0-9]*|"") : ;;
        *)
          if [ "$_snf_stamp" -gt "$_snf_now" ]; then
            _snf_ahead="$(python3 - "$_snf_stamp" "$_snf_now" <<'PYEOF' 2>/dev/null || echo 0
import sys, datetime
f = "%Y%m%d%H%M"
try:
    a = datetime.datetime.strptime(sys.argv[1], f)
    b = datetime.datetime.strptime(sys.argv[2], f)
except ValueError:
    print(0); raise SystemExit
print(int((a - b).total_seconds() // 60))
PYEOF
)"
            if [ "${_snf_ahead:-0}" -gt 5 ]; then
              report "$_snf_f" "Version stamp $_snf_ver is ${_snf_ahead} minute(s) in the FUTURE — it was typed, not read. This machine's LOCAL clock says $(date +%Y%m%d.%H%M) ($(date +%Z)); stamps are local time, so a UTC-stamped or other-timezone header reads as ahead"
            fi
          fi ;;
      esac ;;
  esac
  _snf_mod="$(grep -m1 -E '^#[[:space:]]*Modified:' "$_snf_f" 2>/dev/null \
              | sed 's/.*Modified:[[:space:]]*//' | tr -d '[:space:]')"
  case "$_snf_mod" in
    [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9])
      if [ "$(printf '%s' "$_snf_mod" | tr -d -)" -gt "$(date +%Y%m%d)" ]; then
        report "$_snf_f" "Modified: $_snf_mod is in the FUTURE — today is $(date +%Y-%m-%d) in this machine's LOCAL time ($(date +%Z))"
      fi ;;
  esac
}

stamp_not_ahead() {
  _sna_f="$1"
  _sna_ver="$(grep -m1 -E '^#[[:space:]]*Version:' "$_sna_f" 2>/dev/null \
              | sed 's/.*Version:[[:space:]]*//' | tr -d '[:space:]')"
  case "$_sna_ver" in
    *.*.*.*.*) : ;;
    *) return 0 ;;     # malformed: the format rule already reported it
  esac
  _sna_stamp="$(printf '%s' "$_sna_ver" | awk -F. '{print $(NF-1) $NF}')"
  _sna_commit="$(git log -1 --format='%ad' --date=format:'%Y%m%d%H%M' -- "$_sna_f" 2>/dev/null)"
  # No commit yet (a new file not yet committed) means nothing to compare against, and
  # guessing would be worse than saying nothing.
  [ -n "$_sna_commit" ] || return 0
  case "$_sna_stamp$_sna_commit" in
    *[!0-9]*) return 0 ;;
  esac
  # Minutes since epoch is overkill; comparing YYYYMMDDHHMM as an integer is monotonic and
  # the two-hour grace is applied by converting only when the stamp actually looks ahead.
  if [ "$_sna_stamp" -le "$_sna_commit" ]; then
    return 0
  fi
  _sna_ahead="$(python3 - "$_sna_stamp" "$_sna_commit" <<'PYEOF' 2>/dev/null || echo 0
import sys, datetime
f = "%Y%m%d%H%M"
try:
    a = datetime.datetime.strptime(sys.argv[1], f)
    b = datetime.datetime.strptime(sys.argv[2], f)
except ValueError:
    print(0); raise SystemExit
print(int((a - b).total_seconds() // 60))
PYEOF
)"
  if [ "${_sna_ahead:-0}" -gt 120 ]; then
    report "$_sna_f" "Version stamp $_sna_ver is ${_sna_ahead} minute(s) AHEAD of the commit that carries it — a hand-typed stamp, and it sorts the release corpus wrong (#238)"
  fi
}

# ----------------------------------------------------------------------------- --adopt
if [ "$ADOPT" = "1" ]; then
  if [ ! -f "$STANDARDS" ]; then
    echo "header_check: --adopt needs $STANDARDS, which does not exist here." >&2
    exit 2
  fi
  existing="$(read_baseline)"
  if [ -n "$existing" ]; then
    echo "header_check: $STANDARDS already declares a header baseline of $existing."
    echo "              Nothing to do. Edit that line directly to change it, or delete it"
    echo "              once every file carries a header."
    exit 0
  fi
  TODAY="$(date +%Y-%m-%d)"
  # Count what the amnesty would cover BEFORE writing it, so the number in the marker is
  # measured rather than asserted — and so a project with nothing to exempt is told to
  # skip the marker entirely instead of acquiring a permanent exemption it never needed.
  pending=0
  while IFS= read -r f; do
    [ -f "$f" ] || continue
    is_source "$f" || continue
    for field in Project File Modified Version Purpose; do
      grep -qE "^#[[:space:]]*${field}:" "$f" || { pending=$((pending + 1)); break; }
    done
  done < <(source_candidates)
  if [ "$pending" = "0" ]; then
    echo "header_check: every tracked source file already carries a header — no baseline needed."
    echo "              A marker here would be a standing exemption for a problem you do not have."
    exit 0
  fi
  tmp="$STANDARDS.adopt.$$"
  # PREFER THE SLOT THE STANDARD SHIPS FOR THIS. ai/STANDARDS.md carries a negative
  # declaration — "<!-- scaffold:header-baseline is not set here — ... -->" — in the
  # File-header baseline section, exactly as scaffold:no-artifact does. Replacing that line
  # puts the marker in a stable, upstream-owned region.
  #
  # MEASURED, on a real 0.5.0 -> 0.6.3 upgrade of a fixture: a marker appended to EOF
  # CONFLICTED, because upstream had appended a new section to the end of the same file and
  # the two edits were adjacent. EOF is the worst available position in a file whose upstream
  # grows by appending, which is how every standards file in this scaffold grows.
  # THE SLOT IS "AT COLUMN 0, NAMES THE MARKER, IS NOT A VALID DECLARATION" — never a
  # particular sentence. Matching upstream's exact prose would break the moment that
  # sentence was edited, and it was: the shipped wording used to assert a fact about
  # whatever repo the file landed in ("this repo ships the scaffold itself"), which is
  # false in every repo that merged it. Wording is documentation; the shape is the contract.
  if grep -qE '^<!--[[:space:]]*scaffold:header-baseline([^0-9]|$)' "$STANDARDS"; then
    awk -v today="$TODAY" '
      /^<!--[[:space:]]*scaffold:header-baseline[[:space:]]+[0-9]{4}-[0-9]{2}-[0-9]{2}[[:space:]]*-->[[:space:]]*$/ { print; next }
      /^<!--[[:space:]]*scaffold:header-baseline/ && !filled {
        print "<!-- scaffold:header-baseline " today " -->"; filled = 1; next
      }
      { print }
    ' "$STANDARDS" > "$tmp" && mv "$tmp" "$STANDARDS"
    where="in the File-header baseline section"
  else
    # Older adoption, predating that section. Insert ABOVE the overlay appendix when there is
    # one: scaffold_upgrade.sh detaches everything from `# Overlay:` down before merging, so a
    # marker below it would travel with the wrong half of the file.
    ov="$(grep -n '^# Overlay:' "$STANDARDS" | head -1 | cut -d: -f1)"
    {
      if [ -n "$ov" ]; then head -n "$((ov - 1))" "$STANDARDS"; else cat "$STANDARDS"; fi
      cat <<MARKER

### File-header baseline

This project adopted the file-header rule on $TODAY, with $pending file(s) already in
tree that predate it. The rule applies from that date forward: those files are exempt
until they are edited, and every file touched on or after it must carry a header.

<!-- scaffold:header-baseline $TODAY -->

\`tools/header_check.sh --list-legacy\` names what is still exempt. Delete the line above
once that list is empty — it is an amnesty for existing history, not a permanent opt-out.
MARKER
      if [ -n "$ov" ]; then tail -n "+$ov" "$STANDARDS"; fi
    } > "$tmp" && mv "$tmp" "$STANDARDS"
    where="as a new section (this project predates the one upstream ships)"
  fi
  echo "header_check: declared a header baseline of $TODAY in $STANDARDS, $where."
  echo "              $pending existing file(s) are now exempt until they are next edited."
  echo "              Commit that change; ai/STANDARDS.md is merged, not overwritten, by upgrades."
  exit 0
fi

# ---------------------------------------------------------------- header completeness
echo "header_check: file headers (ai/CODING.md -> File headers)"
checked=0
while IFS= read -r f; do
  [ -f "$f" ] || continue
  is_source "$f" || continue
  checked=$((checked + 1))
  missing=""
  for field in Project File Modified Version Purpose; do
    grep -qE "^#[[:space:]]*${field}:" "$f" || missing="$missing $field"
  done
  if [ -n "$missing" ]; then
    report "$f" "header missing:$missing"
    continue
  fi
  # The File: field must name the file it is in. A copied header that still points at
  # its source is worse than none — it reads as deliberate and is wrong.
  declared="$(grep -m1 -E '^#[[:space:]]*File:' "$f" | sed 's/.*File:[[:space:]]*//' | tr -d '[:space:]')"
  if [ "$declared" != "$f" ] && [ "$declared" != "$(basename "$f")" ]; then
    report "$f" "header says File: $declared"
    continue
  fi
  # Version must be MAJOR.MINOR.PATCH.YYYYMMDD.HHMM — the format AGENTS.md states.

  ver="$(grep -m1 -E '^#[[:space:]]*Version:' "$f" | sed 's/.*Version:[[:space:]]*//' | tr -d '[:space:]')"
  # `grep -c`, not `grep -q` (#310). grep -q exits at the first match, printf takes
  # SIGPIPE, and under `set -o pipefail` the pipeline reports 141 -- so the test fails
  # BECAUSE the pattern matched. Survived the #306 sweep only because $ver is one short
  # string that fits the pipe buffer, which is an accident of payload size, not a guard.
  # grep -c consumes all of its input and cannot race its writer.
  if [ "$(printf '%s\n' "$ver" | grep -cE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]{8}\.[0-9]{4}$' || true)" = 0 ]; then
    report "$f" "Version '$ver' is not MAJOR.MINOR.PATCH.YYYYMMDD.HHMM"
  fi
  # A FUTURE STAMP IS CAUGHT IN THE BARE FORM TOO, and that is the point of it. The
  # `--since` path only sees files that CHANGED, and the bare form is what runs in
  # `setup.sh --check` and in a developer's hands. A stamp typed from memory is wrong the
  # moment it is written, not the moment it is diffed.
  stamp_not_future "$f"
done < <(source_candidates)
if [ "$fail" = "0" ] && [ "$legacy" = "0" ]; then
  echo "  all $checked source file(s) carry a complete header"
  # SAY WHAT WAS NOT CHECKED (#182). CI runs `--since origin/main`; the bare form does
  # not check build stamps at all, so a developer can be green locally and red in CI
  # for a reason nothing on screen mentions. Only when the stricter form was not asked
  # for — repeating it under --since would be noise.
  if [ -z "${SINCE:-}" ]; then
    echo "  (build stamps NOT checked — that needs --since <ref>, and CI uses"
    echo "   --since origin/main. tools/preflight.sh runs both.)"
  fi
elif [ "$fail" = "0" ]; then
  # NOT "all clean". A pass that says everything is fine while N files are exempt is how
  # an amnesty becomes permanent — the number has to stay visible on every green run.
  echo "  $((checked - legacy)) of $checked source file(s) carry a complete header"
fi
if [ "$legacy" -gt 0 ]; then
  echo "  $legacy file(s) predate the declared baseline of $BASELINE and are exempt until edited."
  [ "$LIST_LEGACY" = "1" ] || echo "  Name them with: tools/header_check.sh --list-legacy"
fi
# SAY IT OUT LOUD. This is not an exemption anyone earned and it must not read as one — an
# amnesty granted because the question was unanswerable is the kind that quietly becomes
# permanent. It fires in a synthetic single-commit tree (adoption_check's fixture) and
# nowhere a real project lives.
if [ "$squashed" -gt 0 ]; then
  echo "  $squashed file(s) NOT MEASURED against the $BASELINE baseline — this repository's"
  echo "  entire history is one commit, so every file shares its date and no baseline can"
  echo "  discriminate. Not a pass and not a failure; the check could not run here."
fi

# ---------------------------------------------------------------- build stamp per PR
if [ -n "$SINCE" ]; then
  echo
  echo "header_check: build stamps since $SINCE (ai/STANDARDS.md -> Versioning)"
  if ! git rev-parse --verify --quiet "$SINCE" >/dev/null; then
    echo "  [SKIP] '$SINCE' is not a ref in this clone — cannot compare. NOT a pass."
    # A comparison that could not run is not a clean result. Same rule the localcoder
    # audit learned: a skip that returns 0 is how CI goes green having checked nothing.
    [ "$WARN_ONLY" = "1" ] || exit 1
  else
    stamped=0
    # COMMITTED CHANGES **AND** THE WORKING TREE. Comparing only `$SINCE...HEAD` made
    # this useless locally — the first local run reported "0 changed files" while a dozen
    # were sitting modified but uncommitted, which is precisely when you want to be told.
    # In CI the working tree is clean, so the union is exactly the PR's own changes.
    # ...AND FILES THAT DO NOT EXIST YET. `git diff` in either form only ever names files
    # git already knows about, so a source file created on this branch and not yet `git
    # add`ed was in NEITHER set — reported clean here, then failed in CI on the commit that
    # added it (#166). The union is now committed ∪ modified ∪ new.
    changed="$( { git diff --name-only "$SINCE"...HEAD; git diff --name-only HEAD
                  git ls-files --others --exclude-standard; } \
                2>/dev/null | sort -u )"
    while IFS= read -r f; do
      [ -n "$f" ] || continue
      [ -f "$f" ] || continue     # deleted files have nothing to stamp
      # `grep -c`, not `grep -q` (#310). grep -q exits at the first match, printf takes
      # SIGPIPE, and under `set -o pipefail` the pipeline reports 141 -- so the test fails
      # BECAUSE the pattern matched. Survived the #306 sweep only because $f is one short
      # string that fits the pipe buffer, which is an accident of payload size, not a guard.
      # grep -c consumes all of its input and cannot race its writer.
      [ "$(printf '%s\n' "$f" | grep -cE "$EXCLUDE" || true)" = 0 ] || continue
      is_source "$f" || continue
      # Did this file's diff touch its own stamp? Look for a CHANGED Modified:/Version:
      # line, not merely for their presence — an unchanged header on a changed file is
      # exactly the drift being caught.
      # COUNT, do not `grep -q`. Under `set -o pipefail`, `grep -q` exits at the first
      # match, git takes SIGPIPE, and the PIPELINE reports 141 — so a correctly stamped
      # file was reported as unstamped. The match succeeded and the test failed anyway:
      # every file this tool checked came back FAIL on its first real run.
      hits="$( { git diff "$SINCE"...HEAD -- "$f"; git diff HEAD -- "$f"; } 2>/dev/null \
               | grep -cE '^[+]#[[:space:]]*(Modified|Version):' )"
      if is_untracked "$f"; then
        # A NEW FILE HAS NOTHING TO RE-STAMP, so asking whether its stamp CHANGED is the
        # wrong question and produces the wrong instruction ("its Modified:/Version: did
        # not change" — there is no previous version). The right question is whether it
        # arrived with a header at all, which is the completeness rule; the scan above
        # already applies it to the same file. Count it, say nothing twice.
        if grep -qE '^#[[:space:]]*Version:' "$f"; then
          stamped=$((stamped + 1))
          stamp_not_ahead "$f"
          stamp_not_future "$f"
        fi
      elif [ "${hits:-0}" -gt 0 ]; then
        stamped=$((stamped + 1))
        stamp_not_ahead "$f"
        stamp_not_future "$f"
      elif ! grep -qE '^#[[:space:]]*Version:' "$f"; then
        # A legacy file with NO header at all, now edited. "its Modified:/Version: did not
        # change" is technically true and useless — there is nothing to change. Say what
        # actually has to happen, because this is the exact moment a baselined file leaves
        # the amnesty and the person editing it needs to know why.
        note FAIL "$f" "changed since $SINCE and has no header — editing a file ends its baseline exemption; add one"
        fail=1
      else
        note FAIL "$f" "changed since $SINCE but its Modified:/Version: did not"
        fail=1
      fi
    done <<EOF
$changed
EOF
    echo "  $stamped changed source file(s) correctly re-stamped"
  fi
fi

echo
if [ "$fail" = "0" ]; then
  echo "header_check: clean"
  exit 0
fi
echo "header_check: findings above. A stale header is not cosmetic — 'Modified:' is how"
echo "              a reader decides whether the measurement in a comment still describes"
echo "              the code. See ai/CODING.md -> File headers."
# NAME THE REMEDY. Adopting the standard into an existing codebase fails the whole tree at
# once, and until 2026-08-05 this message offered nothing but the rule — so the only ways
# out were editing a product file the next upgrade overwrites, or loosening a rule
# ai/STANDARDS.md forbids loosening. Both were wrong, and neither was written down here.
if [ -z "$BASELINE" ] && [ "$fail" = "1" ] && [ -f "$STANDARDS" ]; then
  echo
  echo "              Adopting this standard into an existing codebase? The rule is meant to"
  echo "              apply forward, not retroactively:"
  echo "                  tools/header_check.sh --adopt"
  echo "              declares today as your baseline in $STANDARDS — which upgrades merge"
  echo "              rather than overwrite — exempting files that predate it until they are"
  echo "              next edited. See ai/CODING.md -> File headers."
fi
[ "$WARN_ONLY" = "1" ] && exit 0
exit 1
