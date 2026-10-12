#!/usr/bin/env bash
# Project:  ai-project-scaffold
# File:     tools/stale_path_scan.sh
# Modified: 2026-09-23
# Version:  0.5.3.20260923.0941
# Purpose:  Fail the build when the tree TELLS SOMEONE TO RUN a tools/ path that is not there,
#           or LINKS a reader to a file that is not there.
# Changelog:
#   2026-09-23 v0.5.3.20260923.0941 — fixtures run inside the root tools/fixture_guard.sh validates. There a git and a mktemp on PATH refuse anything that would land outside it. Every mktemp takes a ${TMPDIR} template, because macOS mktemp ignores TMPDIR without one.
#   2026-09-23 v0.5.2.20260923.0843 — every mktemp fails closed. A failed one left the temp variable empty, so the fixture ran in the caller's directory; header_check's committed into Robiton/control.
#   2026-09-08 v0.5.1.20260908.1937 — an INLINE CODE SPAN is not a link, the same argument the
#                        fence rule already makes: GitHub renders `[x](docs/gone.md)` inside
#                        backticks as literal text, so there is nothing to click and nothing to
#                        404. Found by this gate flagging the SESSION ENTRY that explains this
#                        gate — prose about links has to quote one, and quoting it tripped the
#                        check. Same shape as the marker docs in ai/STANDARDS.md tripping an
#                        unanchored pattern, and the fix is the rule, not an exemption on a
#                        sentence that was right. Two cases: a span is text, and a real link
#                        beside a span is still checked, because stripping the span must not
#                        take the rest of the line with it.
#   2026-09-08 v0.5.0.20260908.1901 — SECOND PASS: `link_scan()`, because a markdown link is a
#                        promise where prose is only a mention. W-15 moved docs/benchmarks/ out
#                        with localcoder; THREE links in two READMEs kept pointing into this
#                        repo, GitHub rendered all three, and nothing in CI said a word.
#                        Two were found by hand. The THIRD, in tools/README.md, was missed by
#                        the hand check — which globbed README.md and docs/*.md — and found by
#                        this pass on its first run. That gap is the whole argument: a person
#                        sweeps almost everywhere, and almost is where the defect lives.
#                        The pass is narrow on purpose (tracked *.md, prose only, relative
#                        targets only, no network), because a link checker with false positives
#                        is a link checker somebody switches off.
#                        SHIPPED A BUG AND CAUGHT IT BY COUNTING: the first regex excluded any
#                        target containing `#`, so every ANCHORED link went unchecked while the
#                        verdict said fragments were stripped. Counting the tree two ways gave
#                        21 links against the gate's 20. A case now locks it. Anchors themselves
#                        are still NOT checked, and the verdict says so rather than implying it.
#                        Both passes run and neither short-circuits the other — fixing one class
#                        at a time is what CI already makes you do.
#   2026-08-14 v0.4.0.20260814.2100 — `scaffold:path-not-an-instruction` reports its count, and the
#                        file-level count now prints AT ZERO. It used to return early when
#                        nothing was exempted, so the run that proves nothing is being skipped
#                        said nothing at all — the same observation as a broken counter.
#                        A selftest case asserting the OLD behaviour ("no exemptions prints no
#                        suppression block") was inverted rather than deleted, with the
#                        argument kept beside it.
#                        Same macOS awk `-v` path trap as conflict_scan.sh 0.6.0: a log path
#                        beginning with `/` arrives as -inf. ENVIRON[] instead.
#   2026-08-14 v0.3.0 — `scaffold:file-is-historical` GETS THE DEC-18 TREATMENT (Claude Work
#                        §6). It suppressed in silence, which is the thing this file exists to
#                        stop: a whole-FILE exemption is the largest silent reduction the tool
#                        can make — one line at the top of a document turns off every check in
#                        it, forever — and "No instructions reference a missing tools/ path"
#                        read identically whether it skipped nothing or skipped forty files.
#                        I wrote the rule about gates that discover their own work and then
#                        shipped a suppression that does less, quietly.
#                        The count prints on BOTH the pass and the fail path, the files are
#                        named, and a marker with no date and no reason is reported as
#                        incomplete — an exemption without one cannot be told apart from a
#                        line somebody added to make a build go green.
#                        IT STILL SUPPRESSES. Blocking a build to collect a justification is a
#                        guard that gets switched off, and a switched-off guard protects
#                        nothing (ai/SECURITY.md). The nag is proportionate to the ask.
#                        Five cases, both directions: the correct dated-and-reasoned form must
#                        NOT nag, or people delete the reason to quieten it.
#   2026-08-12 v0.2.0 — `scaffold:file-is-historical`, a FILE-scope exemption for documents
#                        that are entirely history — a known-defects log, a decision record.
#                        Marking each line would be seven annotations today and more every
#                        week in a file whose purpose is to accumulate them, and a burden
#                        that grows with the document is one people satisfy by deleting the
#                        check. Found in ai-project-scaffold-dev's 04-KNOWN-DEFECTS.md, where
#                        all seven hits were correct quotations of commands that had produced
#                        real defects. Column 0 only.
#   2026-08-12 v0.1.0 — New. W-15 stopped shipping localcoder and the prose describing it
#                        stayed. That is not merely stale documentation: `chmod +x tools/*.sh
#                        tools/*.py tools/localcoder` shipped in all three of the adoption
#                        guide's copy-paste blocks, and `chmod` exits non-zero on a missing
#                        path — so an adopter's FIRST command ended in an error, at the one
#                        moment they cannot tell "expected" from "I broke it".
#                        SWEPT TWICE AND STILL NOT DONE. 0.36.7 swept `*.md`. 0.36.8 then
#                        found two more inside code — a PRINTED line in `setup.sh --check`
#                        and a workflow comment. A sweep scoped by file EXTENSION is scoped
#                        to the wrong thing, which is D2's shape exactly: a rule enforced
#                        only on changed files is not enforced on what stopped changing.
#                        This file is the checker, so there is no third sweep. Its first run
#                        found three more the two sweeps had missed, including
#                        `preflight --list` printing `tools/audit_localcoder.sh --offline`
#                        as a numbered step to run.
# =============================================================================
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# WHY NOT "ANY MENTION OF A MISSING tools/ PATH". Because most mentions are HISTORY, and
# history is the thing this project is built on. Changelogs, release notes and the comments
# that explain why something left all name the departed file ON PURPOSE — docs/TROUBLESHOOTING
# .md deliberately keeps a whole section about `tools/localcoder` so that someone arriving
# from an old CI log is told it is gone rather than finding nothing. A checker that fired on
# those would be turned off within a day, and ai/SECURITY.md's rule is that a guard which
# blocks legitimate work protects nothing afterwards.
#
# So the rule is INSTRUCTIONS, not mentions. Two forms, and both were real defects:
#
#   1. A fenced code block in Markdown. That is a thing to copy and run — `chmod +x ...
#      tools/localcoder`, `tools/guard_delegation.py --selftest`.
#   2. A quoted string in an `echo`/`printf`. That is a thing PRINTED TO A HUMAN as advice —
#      `setup.sh --check`'s summary, and `preflight --list`'s numbered steps.
#
# Prose outside both is left alone. It is allowed to talk about the past.
MARK='scaffold:path-not-an-instruction'

# AND A FILE-SCOPE FORM, for documents that are ENTIRELY history.
#
# A known-defects log, a decision record, a session archive: every command in them is quoted
# because it once ran, and most of what they name is deliberately gone. Marking each line
# would be seven annotations today and more every week, in a file whose whole purpose is to
# accumulate them — and an annotation burden that grows with the document is one people
# eventually satisfy by deleting the check.
#
# Found in ai-project-scaffold-dev on 2026-08-12: 04-KNOWN-DEFECTS.md, seven hits, every one
# a correct quotation of a command that had produced a real defect.
#
# AT COLUMN 0, like every other marker here — an indented example inside a code block is
# documentation, not a declaration. It exempts the WHOLE file, which is a real cost and the
# reason it is a separate, more deliberate marker rather than a laxer default.
FILE_MARK='scaffold:file-is-historical'

# TESTS BUILD TREES ON PURPOSE, and those paths are MEANT not to exist. `header_check.sh`
# writes tools/bare.sh into a temp dir; `adoption_check.sh` writes tools/our_delegate.sh.
# Two ways to tell those apart from a real instruction, and both are needed:
#
#   - STRUCTURAL: skip the body of a function named for a test entry point. Cheap, catches
#     most of them, and needs no annotation.
#   - DECLARED: the line marker above, for fixture builders with project-specific names.
#     A human ruling, visible at the line it applies to — the same shape as
#     `scaffold:not-a-conflict` and `scaffold:not-a-secret`, and for the same reason: a
#     prohibition with no sanctioned path gets worked around, and every workaround is worse.
#
# THE MARKER IS NOT ONLY FOR FIXTURES, and that was learned by running this. Its first real
# run flagged setup.sh's own message EXPLAINING that `tools/localcoder` is gone — history,
# printed to a human, which is precisely what the prose exemption exists for and which the
# printed-string rule cannot distinguish. So the marker says "this line names a missing path
# ON PURPOSE", whichever purpose. That is the same trap the W-15 no-execution gate fell into:
# it fired on setup.sh's echo telling a developer what to install — a gate forbidding its own
# remedy.
# BRACKET EXPRESSIONS, NOT BACKSLASHES. This pattern reaches awk through `-v`, which
# processes escape sequences BEFORE the regex compiler sees them — so `\(\)` arrived as an
# empty group `()` that matches everywhere, and `\{` as a bare brace the compiler reads as
# an interval. The skip silently never fired. `[(][)]` and `[{]` survive both passes.
FIXTURE_FN='^(selftest|prove_it_fails|run|case_run|make_[a-z_]+|build_[a-z_]+|adopter_[a-z_]+|c_[a-z_]+)[[:space:]]*[(][)][[:space:]]*[{]'

PATH_SUPPRESS_LOG=""

scan() {
  local f line lineno path hits=0 tmp isMd hist_files='' hist_bare=''
  PATH_SUPPRESS_LOG="$(mktemp "${TMPDIR:-/tmp}/stale_path_scan.XXXXXX")" || PATH_SUPPRESS_LOG=""
  if ! git rev-parse --git-dir >/dev/null 2>&1; then
    echo "stale_path_scan: not a git repository — nothing to scan."
    return 3
  fi

  # NO `awk -v RS='\0'`. macOS ships the one-true-awk, where an EMPTY RS means PARAGRAPH
  # MODE — records separated by blank lines — and `RS='\0'` is an empty string to it. The
  # first version of this file did exactly that: every record was a blob of concatenated
  # filenames, `test -f` failed on all of them, zero files were examined, and every selftest
  # case reported PASS. A checker that verifies nothing while printing "No instructions
  # reference a missing tools/ path" is the precise defect this project keeps paying for,
  # and it shipped inside the tool written to catch that class. Caught only because four
  # cases that MUST fail did not.
  #
  # So: NUL-safe iteration in bash (`read -r -d ""`), exactly as tools/conflict_scan.sh does,
  # and awk gets one file at a time with default record separators.
  #
  # PREFILTERED TO ONE PROCESS FOR THE TREE. Walking every tracked file would cost a process
  # each; `git grep -l` names the handful that mention a tools/ path at all, and in the normal
  # case that is a short list.
  tmp="$(mktemp "${TMPDIR:-/tmp}/stalepath.XXXXXX")" || { echo "stale_path_scan: mktemp failed; stopping" >&2; exit 1; }
  while IFS= read -r -d "" f; do
    [ -f "$f" ] || continue
    # A whole-file declaration, at column 0. Checked before any line work, so a historical
    # document costs one grep rather than a scan.
    #
    # IT USED TO SUPPRESS IN SILENCE, WHICH IS THE THING THIS FILE EXISTS TO STOP.
    #
    # DEC-18 says a gate that discovers its own work can silently do less of it and the
    # verdict line cannot say so. A whole-FILE exemption is the largest possible instance:
    # one line at the top of a document turns off every check for every path in it, forever,
    # and the report read identically whether it skipped nothing or skipped forty files.
    # I wrote the rule about gates that discover their own work and then shipped a
    # suppression that does less, quietly. Raised by Claude Work as §6.
    #
    # So the count is printed on success, the files are named, and a marker with no reason
    # is reported as incomplete. IT STILL SUPPRESSES: breaking an adopter's build to collect
    # a justification would be a guard that blocks legitimate work, which ai/SECURITY.md says
    # gets switched off — and a switched-off guard protects nothing. The nag is proportionate
    # to the ask.
    _hist="$(grep -m 1 -E "^(<!--|#)[[:space:]]*${FILE_MARK}" "$f" 2>/dev/null || true)"
    if [ -n "$_hist" ]; then
      hist_files="$hist_files $f"
      # A REASON AND A DATE, per DEC-18. `<!-- scaffold:file-is-historical 2026-08-12 records
      # commands retired in W-15 -->`. Without them the next reader cannot tell a considered
      # exemption from one somebody added to make a build go green.
      case "$_hist" in
        *"${FILE_MARK}"[[:space:]][0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9][[:space:]]*) ;;
        *) hist_bare="$hist_bare $f" ;;
      esac
      continue
    fi
    # COMPUTED BEFORE THE CALL, NOT INSIDE IT. A `case ... esac` inside `$( )` closes the
    # substitution on its first `)` and the shell reports a syntax error from a line number
    # inside the awk program, which is a long way from the cause.
    case "$f" in *.md) isMd=1 ;; *) isMd=0 ;; esac
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
    SPS_LOG="$PATH_SUPPRESS_LOG" awk -v mark="$MARK" -v fixfn="$FIXTURE_FN" -v isMd="$isMd" '
      { line = $0 }
      line ~ fixfn                  { infix = 1; next }
      infix && line ~ /^[}]/        { infix = 0; next }
      infix                         { next }
      index(line, mark) > 0         { suppressed++; next }   # a human already ruled on this line
      {
        if (isMd == 1) {
          if (line ~ /^[[:space:]]*```/) { fence = !fence; next }
          if (!fence) next
        } else {
          if (line !~ /(echo|printf)[[:space:]]+["'"'"']/) next
          # A REDIRECT MEANS THE LINE IS BUILDING A FILE, NOT ADVISING A HUMAN.
          # `printf '...' > tools/bare.sh` writes a fixture; `echo "run tools/x.sh"` tells
          # someone to run one. Structural, so the common fixture shape needs no annotation.
          # NARROW: the redirect TARGET must itself be a tools/ path. `> "$d/tools/x.sh"` is
          # a fixture being written; a printed line telling someone to run a tools/ path and
          # send its output somewhere is still an instruction, and a rule that skipped any
          # line containing `>` at all would lose it. (That example is DESCRIBED rather than
          # quoted on purpose: written out, this comment would trip its own check — which is
          # how the marker docs in ai/STANDARDS.md tripped an unanchored pattern already.)
          if (line ~ /[>][>]?[[:space:]]*["'"'"']?[^"'"'"']*tools\//) next
        }
        pos = 0; rest = line
        while (match(rest, /tools\/[A-Za-z0-9_.-]+/)) {
          p = substr(rest, RSTART, RLENGTH)
          before = substr(rest, 1, RSTART - 1)
          rest = substr(rest, RSTART + RLENGTH)
          # A path built from a variable names a file in a tree that is not this one:
          # `$UP/tools/x`, `"$ROOT/tools/y"`, `$T/p/tools/z`.
          if (before ~ /[$\/][A-Za-z0-9_{}\/.-]*$/) continue
          printf "%d\t%s\n", NR, p
        }
      }
      END { if (ENVIRON["SPS_LOG"] != "" && suppressed > 0)
              printf "%d\n", suppressed >> ENVIRON["SPS_LOG"] }
    ' "$f" > "$tmp"
    while IFS="	" read -r lineno path; do
      [ -n "$path" ] || continue
      [ -e "$path" ] && continue
      printf "  %s:%s  %s\n" "$f" "$lineno" "$path"
      hits=$((hits + 1))
    done < "$tmp"
  done < <(git grep -I -l -z -E 'tools/[A-Za-z0-9_.-]+' -- . 2>/dev/null || true)
  rm -f "$tmp"

  # THE SUPPRESSION COUNT PRINTS WHETHER OR NOT ANYTHING FAILED (DEC-18).
  #
  # "No instructions reference a missing tools/ path" read identically whether this scanned
  # every file or skipped forty of them, and a whole-file exemption is the largest silent
  # reduction available to this tool. Naming them costs one line and makes the verdict mean
  # something specific.
  _report_suppressions() {
    local n=0 f
    for f in $hist_files; do n=$((n + 1)); done
    # THE LINE-SCOPED EXEMPTION, COUNTED (design review 2026-08-14). `path-not-an-instruction`
    # is a human declaration that a line naming a missing tools/ path is not telling anyone to
    # run it. It was applied silently, so a run that skipped six such lines and a run with
    # none printed the identical verdict.
    local l=0
    if [ -n "$PATH_SUPPRESS_LOG" ] && [ -f "$PATH_SUPPRESS_LOG" ]; then
      l="$(awk '{t+=$1} END {printf "%d", t}' "$PATH_SUPPRESS_LOG" 2>/dev/null)"
      rm -f "$PATH_SUPPRESS_LOG"
    fi
    l="${l:-0}"
    echo ""
    echo "Suppressed: $l line(s) marked ${MARK}, $n file(s) exempted whole by ${FILE_MARK}."
    # ZERO IS PRINTED. This used to return early when no file was exempted, so the run that
    # proves nothing is being skipped said nothing at all — which is the same observation as
    # a run whose counter was broken. Both numbers now print on every run, and the detail
    # below appears only when there is detail.
    [ "$n" -eq 0 ] && return 0
    echo ""
    echo "$n file(s) exempted whole by ${FILE_MARK}, and NOT scanned:"
    for f in $hist_files; do echo "    $f"; done
    local b=0
    for f in $hist_bare; do b=$((b + 1)); done
    if [ "$b" -gt 0 ]; then
      echo ""
      echo "  $b of them carry NO DATE AND NO REASON. An exemption without one cannot be"
      echo "  told apart from a line somebody added to make a build go green:"
      for f in $hist_bare; do echo "    $f"; done
      echo "  Use:  <!-- ${FILE_MARK} $(date +%Y-%m-%d) why this file records dead commands -->"
      echo "  These are still exempted — a guard that blocked the build to collect a"
      echo "  justification is one people switch off, and then it protects nothing."
    fi
  }

  if [ "$hits" -eq 0 ]; then
    echo "No instructions reference a missing tools/ path."
    _report_suppressions
    return 0
  fi
  echo "::error::The tree tells someone to run a tools/ path that is not there."
  echo ""
  echo "Each line above is an INSTRUCTION — a fenced command block, or a string this"
  echo "project PRINTS as advice — naming a file that does not exist. Prose about the"
  echo "past is deliberately not checked; these are things a reader would run."
  echo ""
  echo "Fix the path, or if the line builds a TEST FIXTURE whose tree is meant to be"
  echo "absent, mark it and re-run:"
  echo "    printf 'x' > tools/fake.sh    # $MARK"
  _report_suppressions
  return 1
}

# ---------------------------------------------------------------------------
# SECOND PASS: a markdown LINK is a promise, not a mention.
#
# The pass above deliberately ignores markdown prose — prose is allowed to talk about the
# past, and `tools/localcoder_sync.py` in TROUBLESHOOTING.md is a correct sentence about a
# check that was retired. A LINK is different. A link is not a mention of a file; it is an
# offer to take the reader to one, and it fails silently — GitHub renders it, the reader
# clicks, and gets a 404 with no error anywhere in CI.
#
# Found 2026-09-08: W-15 moved docs/benchmarks/ out with localcoder and THREE links in two
# READMEs kept pointing into this repo. Two were found by hand; the third, in tools/README.md,
# was missed by the hand check and found by this pass on its first run. That is the argument
# for the pass: the hand check globbed README.md and docs/*.md, which is exactly the sort of
# almost-complete sweep a person does and a gate does not.
#
# SCOPE, deliberately narrow — a link check with false positives gets switched off:
#   - Tracked *.md only, prose only. A link inside a fence is an EXAMPLE of a link.
#   - Relative targets only. http(s), mailto, tel, ftp, protocol-relative and bare #anchors
#     are somebody else's to verify; this gate does not touch the network.
#   - Anything containing a shell or template metacharacter is a TEMPLATE, not a path.
#   - A #fragment is stripped before resolving. Whether the ANCHOR exists is a different
#     question this does NOT answer, and the verdict says so rather than implying it checked.
link_scan() {
  local f d lineno target resolved hits=0 files=0 links=0 tmp
  if ! git rev-parse --git-dir >/dev/null 2>&1; then
    echo "stale_path_scan: not a git repository — links NOT CHECKED."
    return 3
  fi
  LINK_SUPPRESS_LOG="$(mktemp "${TMPDIR:-/tmp}/stale_path_scan.XXXXXX")" || LINK_SUPPRESS_LOG=""
  tmp="$(mktemp "${TMPDIR:-/tmp}/stalelink.XXXXXX")" || { echo "stale_path_scan: mktemp failed; stopping" >&2; exit 1; }
  while IFS= read -r -d "" f; do
    [ -f "$f" ] || continue
    # The same whole-file exemption as the pass above. A document that is entirely history
    # is entirely history for both checks.
    grep -q -m 1 -E "^(<!--|#)[[:space:]]*${FILE_MARK}" "$f" 2>/dev/null && continue
    files=$((files + 1))
    # ENVIRON[], NOT -v, for the log path. Same one-true-awk coercion trap documented at
    # length in scan(): a value beginning with `/` arrives as the number -inf, the redirect
    # writes nowhere, and the suppression count reads 0 forever — which looks exactly like a
    # tree with nothing suppressed.
    LS_LOG="$LINK_SUPPRESS_LOG" awk -v MARKV="$MARK" '
      { line = $0 }
      line ~ /^[[:space:]]*```/ { fence = !fence; next }
      fence                     { next }
      index(line, MARKV) > 0    { suppressed++; next }
      {
        rest = line
        # AN INLINE CODE SPAN IS NOT A LINK, for the same reason a fence is not. GitHub
        # renders `[x](docs/gone.md)` inside backticks as literal text — there is nothing to
        # click and nothing to 404. Found by this gate flagging the SESSION entry that
        # explains this gate: the prose describing a link had to quote one, and quoting it
        # tripped the check. That is the recurring shape here — a pattern matching the
        # document that documents it — and the fix is the same as the fence rule, not an
        # exemption marker on a sentence that was correct.
        gsub(/`[^`]*`/, "", rest)
        while (match(rest, /\]\([^)[:space:]]+\)/)) {
          t = substr(rest, RSTART + 2, RLENGTH - 3)
          rest = substr(rest, RSTART + RLENGTH)
          if (t ~ /^(https?:|mailto:|tel:|ftp:|\/\/|#)/) continue
          if (t ~ /[$<>{}*|`]/) continue
          # STRIP THE FRAGMENT AND QUERY, do not EXCLUDE the link. The first version of this
          # regex refused to match any target containing `#` at all, so every link with an
          # anchor went UNCHECKED while the verdict said fragments were stripped — a comment
          # asserting the opposite of the code, in a gate whose whole subject is claims that
          # are not true. Caught by counting: 31 links in the tree, 21 relative, gate said 20.
          sub(/[#?].*$/, "", t)
          if (t == "") continue
          printf "%d\t%s\n", NR, t
        }
      }
      END { if (ENVIRON["LS_LOG"] != "" && suppressed > 0)
              printf "%d\n", suppressed >> ENVIRON["LS_LOG"] }
    ' "$f" > "$tmp"
    d="$(dirname "$f")"
    while IFS="	" read -r lineno target; do
      [ -n "$target" ] || continue
      links=$((links + 1))
      case "$target" in /*) resolved="$target" ;; *) resolved="$d/$target" ;; esac
      [ -e "$resolved" ] && continue
      printf "  %s:%s  -> %s\n" "$f" "$lineno" "$target"
      hits=$((hits + 1))
    done < "$tmp"
  done < <(git ls-files -z -- '*.md' 2>/dev/null || true)
  rm -f "$tmp"

  local l=0
  if [ -n "$LINK_SUPPRESS_LOG" ] && [ -f "$LINK_SUPPRESS_LOG" ]; then
    l="$(awk '{t+=$1} END {printf "%d", t}' "$LINK_SUPPRESS_LOG" 2>/dev/null)"
    rm -f "$LINK_SUPPRESS_LOG"
  fi
  l="${l:-0}"

  if [ "$hits" -eq 0 ]; then
    # THE COUNTS PRINT AT ZERO AND ON SUCCESS (DEC-18). "All links resolve" reads identically
    # whether this examined 400 links or, because a glob broke, none at all — and this file
    # has already shipped that exact defect once, in the awk RS trap in scan().
    echo "Checked $links relative markdown link(s) across $files file(s); all resolve."
    echo "  ANCHORS ARE NOT CHECKED — a #fragment is stripped before resolving, so a link to a"
    echo "  real file with a dead heading passes here. Suppressed: $l line(s) marked ${MARK}."
    return 0
  fi
  echo "::error::A markdown link points at a file that is not there."
  echo ""
  echo "Each line above is a LINK, not a mention — prose about retired paths is deliberately"
  echo "left alone. A reader clicking one of these gets a 404, and nothing else reports it."
  echo ""
  echo "Fix the target, or repoint it at the repository the file moved to. If the line is not"
  echo "really a promise, mark the line with ${MARK} and re-run."
  echo ""
  echo "Checked $links relative link(s) across $files file(s); $hits broken, $l suppressed."
  return 1
}


selftest() {
  local T fails=0 out got
  # FIXTURES RUN INSIDE A GUARDED ROOT (tools/fixture_guard.sh). Later mktemps land inside it,
  # and a git on PATH refuses any write outside it. The guard exists because a failed mktemp
  # once let a selftest run git init and commit in the real repo.
  . "$(dirname "${BASH_SOURCE[0]}")/fixture_guard.sh" || { echo "stale_path_scan: tools/fixture_guard.sh is missing; refusing to build fixtures" >&2; exit 1; }
  fixture_root FG_ROOT; trap fg_cleanup EXIT
  T="$(mktemp -d "${TMPDIR:-/tmp}/stale_path_scan.XXXXXX")" || return 1
  local SELF_ABS="$ROOT/tools/stale_path_scan.sh"

  case_run() {  # case_run <label> <expected-exit> <setup-fn>
    local label="$1" want="$2" setup="$3" R="$T/case"
    rm -rf "$R"; mkdir -p "$R/tools" "$R/docs"
    ( cd "$R" && git init -q . && git config user.email a@b.c && git config user.name t )
    printf '#!/bin/sh\nexit 0\n' > "$R/tools/real.sh"; chmod +x "$R/tools/real.sh"
    ( cd "$R" && $setup )
    ( cd "$R" && git add -A >/dev/null 2>&1 )
    out="$( cd "$R" && bash "$SELF_ABS" 2>&1 )"; got=$?
    if [ "$got" = "$want" ]; then printf '  ok   %-58s\n' "$label"
    else
      printf '  FAIL %-58s want exit %s, got %s\n' "$label" "$want" "$got"
      printf '%s\n' "$out" | sed 's/^/         /' | head -6
      fails=$((fails + 1))
    fi
  }

  # THE REAL ONE, BYTE FOR BYTE: three copies of this shipped in docs/ADOPTION_GUIDE.md and
  # `chmod` exits non-zero on the missing path, so an adopter's first command block errored.
  c_the_defect()   { printf '# Setup\n\n```bash\nchmod +x tools/*.sh tools/gone.sh\n```\n' > docs/g.md; }
  # THE SECOND REAL ONE: a string PRINTED as advice. 0.36.7 swept *.md and missed this class
  # entirely, which is why the checker exists instead of a third sweep.
  c_printed()      { printf '#!/bin/sh\necho "  run tools/gone.sh --offline for the rest"\n' > tools/say.sh; }
  c_clean()        { printf '# Doc\n\n```bash\ntools/real.sh\n```\n' > docs/g.md; }
  # PROSE IS ALLOWED TO TALK ABOUT THE PAST. docs/TROUBLESHOOTING.md deliberately keeps a
  # section about `tools/localcoder` so someone arriving from an old CI log is told it is
  # gone. A checker that fired on that would be switched off within a day.
  c_history()      { printf '# Doc\n\n`tools/gone.sh` was removed in W-15; it is not here any more.\n' > docs/g.md; }
  # A COMMENT IS NOT AN INSTRUCTION either — the same argument, in code.
  c_comment()      { printf '#!/bin/sh\n# tools/gone.sh used to run here; it left in W-15.\nexit 0\n' > tools/say.sh; }
  # A PATH BUILT FROM A VARIABLE names a file in a tree that is not this one.
  c_var_prefix()   { printf '#!/bin/sh\nprintf "x" > "$UP/tools/gone.sh"\necho "wrote $UP/tools/gone.sh"\n' > tools/say.sh; }
  # A GLOB IS NOT A PATH.
  c_glob()         { printf '# Doc\n\n```bash\nchmod +x tools/*.sh\n```\n' > docs/g.md; }
  # A REDIRECT INTO tools/ IS A FILE BEING BUILT.
  c_redirect_in()  { printf '#!/bin/sh\nmk() {\n  printf "x" > tools/gone.sh\n}\n' > tools/say.sh; }
  # ...but a redirect ELSEWHERE does not make the line stop being an instruction. The first
  # version skipped any line containing `>` at all, which would have lost this.
  c_redirect_out() { printf '#!/bin/sh\nmk() {\n  echo "run tools/gone.sh > out.txt"\n}\n' > tools/say.sh; }
  # STRUCTURAL FIXTURE SKIP: a selftest body builds trees whose paths are meant to be absent.
  c_fixture_fn()   { printf '#!/bin/sh\nselftest() {\n  printf "x" > tools/gone.sh\n  echo "made tools/gone.sh"\n}\nexit 0\n' > tools/say.sh; }
  # DECLARED FIXTURE SKIP, for builders whose names this file cannot predict.
  c_fixture_mark() { printf '#!/bin/sh\nmk() {\n  echo "tools/gone.sh"    # scaffold:path-not-an-instruction\n}\nexit 0\n' > tools/say.sh; }
  # ...and the marker must clear ONE LINE, never the file.
  c_mark_scoped()  { printf '#!/bin/sh\nmk() {\n  echo "tools/gone.sh"    # scaffold:path-not-an-instruction\n  echo "run tools/alsogone.sh now"\n}\nexit 0\n' > tools/say.sh; }
  # THE CLASS THAT COST tools/secret_scan.sh A SILENT FALSE NEGATIVE.
  c_spaced_path()  { mkdir -p "my docs"; printf '# D\n\n```bash\ntools/gone.sh\n```\n' > "my docs/a b.md"; }
  # A DOCUMENT THAT IS ENTIRELY HISTORY — a defects log, a decision record.
  c_file_hist()    { printf '<!-- scaffold:file-is-historical -->\n# Log\n\n```bash\ntools/gone.sh --run\n```\n' > docs/g.md; }
  # WITH a date and a reason — the form DEC-18 asks for, and the one that must not nag.
  c_file_hist_ok() { printf '<!-- scaffold:file-is-historical 2026-08-12 records commands retired in W-15 -->\n# Log\n\n```bash\ntools/gone.sh --run\n```\n' > docs/g.md; }
  # ...and it has to be at column 0, like every other marker here.
  c_file_hist_ind(){ printf '# Log\n\n    <!-- scaffold:file-is-historical -->\n\n```bash\ntools/gone.sh --run\n```\n' > docs/g.md; }
  # Untracked is out of scope, same as every other scanner here: this checks what is COMMITTED.
  c_untracked()    { printf '# D\n\n```bash\ntools/gone.sh\n```\n' > docs/g.md
                     printf 'docs/g.md\n' > .gitignore; }


  # ---- link_scan cases: a LINK is a promise, and prose is still not one ----
  # THE REAL ONE: W-15 moved docs/benchmarks/ out with localcoder and three links kept
  # pointing into this repo. GitHub renders them; the reader gets a 404; CI said nothing.
  c_link_broken()  { printf '# D\n\nSee [the runbook](docs/benchmarks/README.md) for method.\n' > docs/g.md; }
  # AT THE REPO ROOT, so `tools/real.sh` is root-relative here. Written in docs/ it would
  # resolve to docs/tools/real.sh and fail — which is the resolver working, and is what the
  # first draft of this case asserted was a bug.
  c_link_ok()      { printf '# D\n\nSee [the tool](tools/real.sh).\n' > g.md; }
  # THIS GATE DOES NOT TOUCH THE NETWORK. An http target is somebody else's to verify.
  c_link_http()    { printf '# D\n\nSee [upstream](https://example.invalid/gone.md).\n' > docs/g.md; }
  # A LINK INSIDE A FENCE IS AN EXAMPLE OF A LINK, the same argument as the pass above.
  c_link_fenced()  { printf '# D\n\n```markdown\n[example](docs/benchmarks/README.md)\n```\n' > docs/g.md; }
  # THE FRAGMENT IS STRIPPED, NOT USED TO SKIP THE LINK. The first version of the regex
  # refused to match any target containing `#`, so every anchored link went unchecked while
  # the verdict claimed fragments were stripped — a gate about untrue claims, making one.
  # Caught by counting links two ways and getting 20 against 21, not by any case.
  c_link_anchor()  { printf '# D\n\nSee [a section](docs/gone.md#why).\n' > docs/g.md; }
  c_link_anchor_ok(){ printf '# D\n\nSee [a section](tools/real.sh#why).\n' > g.md; }
  # A TEMPLATE IS NOT A PATH — the same rule the instruction pass applies to globs.
  c_link_template(){ printf '# D\n\nSee [it](docs/{{name}}.md) and [it](docs/$VAR.md).\n' > docs/g.md; }
  # RESOLVED RELATIVE TO THE LINKING FILE, not to the repo root. A `../` link from docs/ is
  # the common shape in this tree and the one a root-relative resolver reports as broken.
  c_link_updir()   { printf '# D\n\nSee [the tool](../tools/real.sh).\n' > docs/g.md; }
  # A BROKEN LINK A HUMAN HAS RULED ON is adjudicated, like any other marked line.
  c_link_marked()  { printf '# D\n\nSee [gone](docs/gone.md).    <!-- scaffold:path-not-an-instruction -->\n' > docs/g.md; }
  # AN INLINE CODE SPAN IS NOT A LINK. GitHub renders it as literal text. Found when this
  # gate flagged the session entry EXPLAINING this gate — prose about links has to quote one.
  c_link_code()    { printf '# D\n\nA link is `[x](docs/gone.md)` and that is text.\n' > docs/g.md; }
  # ...and a real link on the SAME LINE as a code span is still a link. Stripping the span
  # must not take the rest of the line with it.
  c_link_code_mix(){ printf '# D\n\n`[x](docs/a.md)` but see [b](docs/gone.md) too.\n' > docs/g.md; }
  # AND PROSE IS STILL NOT A LINK: the same missing file, merely NAMED, stays legal. This is
  # the boundary between the two passes and the reason both exist.
  c_link_prose()   { printf '# D\n\nThe file docs/gone.md was removed in W-15.\n' > docs/g.md; }

  echo "stale_path_scan selftest — instructions naming a tools/ path that is not there"
  case_run "the real ADOPTION_GUIDE chmod block fails"          1 c_the_defect
  case_run "a PRINTED instruction fails (the *.md sweep's blind spot)" 1 c_printed
  case_run "a fenced block naming a real tool passes"           0 c_clean
  case_run "PROSE about a removed tool is not an instruction"   0 c_history
  case_run "a COMMENT about a removed tool is not an instruction" 0 c_comment
  case_run "a path built from a variable is not this tree's"    0 c_var_prefix
  case_run "a glob is not a path"                               0 c_glob
  case_run "a redirect INTO tools/ is a fixture being written"   0 c_redirect_in
  case_run "a redirect that is not into tools/ stays an instruction" 1 c_redirect_out
  case_run "a selftest() body is a fixture, not an instruction" 0 c_fixture_fn
  case_run "a marked fixture line is adjudicated"               0 c_fixture_mark
  case_run "the marker clears its line, not the file"           1 c_mark_scoped
  case_run "a path in a filename WITH SPACES still fails"       1 c_spaced_path
  case_run "an untracked file is out of scope"                  0 c_untracked
  case_run "a file declared historical is exempt whole"        0 c_file_hist
  case_run "an INDENTED file marker exempts nothing"           1 c_file_hist_ind

  echo ""
  echo "  — links —"
  case_run "a LINK to a missing file fails"                    1 c_link_broken
  case_run "a link to a real file passes"                      0 c_link_ok
  case_run "an http target is not this gate's to verify"       0 c_link_http
  case_run "a link inside a fence is an EXAMPLE of a link"     0 c_link_fenced
  case_run "an ANCHORED link to a missing file still fails"    1 c_link_anchor
  case_run "an anchored link to a real file passes"            0 c_link_anchor_ok
  case_run "a template is not a path"                          0 c_link_template
  case_run "a link resolves against ITS OWN directory"         0 c_link_updir
  case_run "a marked broken link is adjudicated"               0 c_link_marked
  case_run "a link inside an inline code span is text"         0 c_link_code
  case_run "a real link beside a code span is still checked"   1 c_link_code_mix
  case_run "PROSE naming the same missing file stays legal"    0 c_link_prose
  # NOT A GIT REPO IS 3, NOT 0. A scan that could not run must not report clean —
  # ai/STANDARDS.md, and the reason that number exists at all.
  # ---- THE SUPPRESSION IS COUNTED, NAMED, AND ASKED TO JUSTIFY ITSELF (DEC-18, §6) -----
  #
  # A whole-file exemption is the largest silent reduction this tool can make: one line at
  # the top of a document turns off every check in it, forever. The verdict read identically
  # whether it skipped nothing or skipped forty files.
  #
  # BOTH DIRECTIONS, because a nag that fires on the correct form is one people remove.
  run_and_capture() {   # run_and_capture <setup-fn>; prints the tool's output
    local setup="$1" R="$T/sup"
    rm -rf "$R"; mkdir -p "$R/tools" "$R/docs"
    ( cd "$R" && git init -q . && git config user.email a@b.c && git config user.name t )
    printf '#!/bin/sh\nexit 0\n' > "$R/tools/real.sh"; chmod +x "$R/tools/real.sh"
    ( cd "$R" && $setup )
    ( cd "$R" && git add -A >/dev/null 2>&1 )
    ( cd "$R" && bash "$SELF_ABS" 2>&1 )
  }
  sup_case() {  # sup_case <label> <setup-fn> <must-contain> <must-not-contain>
    local label="$1" out
    out="$(run_and_capture "$2")"
    if printf '%s' "$out" | grep -q "$3" \
       && { [ -z "$4" ] || ! printf '%s' "$out" | grep -q "$4"; }; then
      printf '  ok   %-58s\n' "$label"
    else
      printf '  FAIL %-58s\n' "$label"
      printf '%s\n' "$out" | sed 's/^/         /' | head -6
      fails=$((fails + 1))
    fi
  }
  sup_case "an exempted file is COUNTED and NAMED, not silent" c_file_hist \
           "exempted whole by" ""
  sup_case "a bare exemption is asked for a date and a reason" c_file_hist \
           "NO DATE AND NO REASON" ""
  # AND IT STILL SUPPRESSES. Blocking the build to collect a justification is a guard that
  # gets switched off, and a switched-off guard protects nothing.
  sup_case "a bare exemption still exempts (exit 0 path)" c_file_hist \
           "No instructions reference a missing" ""
  # THE CORRECT FORM MUST NOT NAG, or people delete the reason to quieten it.
  sup_case "a dated, reasoned exemption is counted but NOT nagged" c_file_hist_ok \
           "exempted whole by" "NO DATE AND NO REASON"
  # A CLEAN TREE STILL PRINTS THE COUNTS, AND THIS CASE USED TO ASSERT THE OPPOSITE.
  #
  # It read "no exemptions prints no suppression block" and it was defensible at the time:
  # a line on every clean run is a line people learn to skim. Design review ruled against it
  # on 2026-08-14 and the reason is the stronger one — a filter that removes nothing must SAY
  # so, because "nothing was suppressed" and "the counter is broken" are otherwise the same
  # observation, and this programme has now shipped four checks that reported success without
  # having checked.
  #
  # Kept and inverted rather than deleted, so the argument is visible to whoever reads it next.
  sup_case "a clean tree still prints both counts, at zero" c_clean \
           "Suppressed: 0 line(s) marked" ""
  sup_case "and the file-level detail block stays absent when there is none" c_clean \
           "No instructions reference a missing" "and NOT scanned:"
  # THE LINE-SCOPED COUNT IS REAL, NOT A LITERAL ZERO. A counter wired to nothing prints 0
  # forever and passes the case above, so one fixture must move the number.
  # NOT c_mark_scoped: its marked line sits inside a fixture function, which the FIXTURE_FN
  # branch skips BEFORE the marker branch is reached — so the line is never adjudicated and
  # the count is legitimately zero. Discovering that is the case doing its job; asserting 1
  # against it would have been asserting the wrong mechanism.
  c_mark_plain()   { printf '#!/bin/sh\necho "tools/gone.sh"    # scaffold:path-not-an-instruction\nexit 0\n' > tools/plain.sh; }
  sup_case "a line-scoped exemption is counted as one" c_mark_plain \
           "Suppressed: 1 line(s) marked" ""

  local R2="$T/nogit"; mkdir -p "$R2"
  ( cd "$R2" && bash "$SELF_ABS" >/dev/null 2>&1 ); got=$?
  if [ "$got" = "3" ]; then printf '  ok   %-58s\n' "outside a git repo: exit 3, not a pass"
  else printf '  FAIL %-58s want 3, got %s\n' "outside a git repo: exit 3, not a pass" "$got"; fails=$((fails + 1)); fi

  rm -rf "$T"
  echo ""
  if [ "$fails" -eq 0 ]; then echo "  all checks passed"; return 0; fi
  echo "  $fails failed"; return 1
}

# BOTH PASSES RUN, AND THE WORSE ANSWER WINS — but neither short-circuits the other.
#
# `scan && link_scan` would report the instruction failures and never tell you about the
# broken links, so a fix-and-rerun cycle learns about one class at a time. That is the same
# reason preflight.sh reports every gate rather than stopping at the first: CI already does
# stop-at-first, and a local gate that copies it adds nothing.
#
# Exit 3 (COULD NOT CHECK) outranks 0 and is outranked by 1: a real finding is still a real
# finding even when the other pass could not run.
run_all() {
  local a b
  scan; a=$?
  echo ""
  link_scan; b=$?
  [ "$a" -eq 1 ] || [ "$b" -eq 1 ] && return 1
  [ "$a" -eq 3 ] || [ "$b" -eq 3 ] && return 3
  return 0
}

case "${1:-}" in
  --selftest) selftest ;;
  --links)    link_scan ;;
  "")         run_all ;;
  *) echo "usage: stale_path_scan.sh [--selftest|--links]" >&2; exit 2 ;;
esac
