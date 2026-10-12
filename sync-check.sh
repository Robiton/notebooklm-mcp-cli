#!/bin/bash
# Project:  ai-project-scaffold
# File:     sync-check.sh
# Modified: 2026-09-24
# Version:  0.21.0.20260924.1023
# Purpose:  Pre-work check that this clone's ai/ context is current with the remote.
# Changelog:
#   2026-09-24 v0.21.0 — QUIET BY DEFAULT through tools/session_hook.sh --quiet-filter, when the vendored copy has it; full output otherwise. --verbose or SCAFFOLD_VERBOSE=1 prints everything. The feature probe captures --help rather than piping to grep -q, which SIGPIPEs under pipefail and read as "unsupported" every run.
#   2026-08-20 — STAMP CORRECTED from .1345 to .0537. The first was
#                        FABRICATED: written from nothing rather than read from the clock,
#                        landing ~8 hours in the future. ai/STANDARDS.md names this exact
#                        failure -- a stamp rounded forward makes the next honest release
#                        sort EARLIER than its predecessor. The replacement is this file's
#                        real commit time from git.
#   2026-08-20 v0.20.0 — THE SECOND DEFINITION OF THE CEILING IS GONE, THIRD TIME LUCKY.
#                        v0.7.0 found this fallback hardcoding 150 against a shipped 600,
#                        named it 'a second definition of a ceiling', and fixed it by
#                        hardcoding 600 -- still a second definition, which merely agreed
#                        for a year. The shipped default moved to 800/900 today and this
#                        line said 600 again, in the script that runs at EVERY session
#                        start. It no longer carries a number at all: with the archiver
#                        vendored we never reach this branch, and without it the ceiling
#                        is genuinely unknowable here -- it lives in a scaffold:ceilings
#                        marker and parsing that is the tool's job. Reports the COUNT and
#                        says there is no ceiling to compare it against.
#   2026-08-11 v0.9.0 — WARN THE ADOPTERS THE UPGRADE FIX CANNOT REACH. scaffold_upgrade.sh
#                        before 0.16.0 expands an empty array at the line that PERFORMS the
#                        handover, so on bash 3.2 — every Mac — a bare run aborts in the
#                        OUTGOING copy before control reaches the fixed one. No release can
#                        unstick them: reaching the new code is what is broken. And
#                        --dry-run PASSES, because one argument makes the array non-empty,
#                        so the only run that writes is the only one that fails.
#                        This prints the one-time escape (`--to <tag>`), which installs the
#                        fixed copy and makes bare runs work permanently after.
#                        PLACED ABOVE EVERY EARLY EXIT, not appended: this script exits 0
#                        when there is no remote branch, and the first draft of this check
#                        sat below that line where a stuck adopter would never see it.
#                        MAJOR.MINOR compared NUMERICALLY — "0.9" sorts above "0.16" as a
#                        string, a comparison bug this project has already paid for twice.
#   2026-08-09 v0.8.0 — Logs its own run and REPORTS what has gone quiet. The two halves
#                        only work together: a run log nobody reads is a file, and a
#                        session-start check is the one thing guaranteed to read it. It
#                        prints the finding only, never the inventory — a full table every
#                        session start is the noise that gets a report ignored.
#                        This script is why the log exists: it had never fired once on the
#                        machine that develops this scaffold.
#   2026-08-09 v0.7.0 — The inline SESSION.md fallback hardcoded 150 while the shipped
#                        marker said 600 — a second definition of a ceiling, in the one
#                        path that runs when the tool that owns it is absent. It now uses
#                        the shipped default and SAYS it could not read the project's own
#                        marker, rather than reporting a number as though it had.
#   2026-08-09 v0.6.0 — Reports red CI on the remote (tools/ci_status.sh), and FIXES a
#                        nudge that had been dead since 0.14.0: the archive check
#                        branched on an exit code that command stopped returning when
#                        it became advisory, so the session-start reminder could not
#                        fire at all for five releases. A check that has gone silent
#                        looks exactly like a check with nothing to report.
#   2026-08-04 v0.5.0 — Added the file header this script had never carried. It shipped
#                        headerless from the beginning in the repo that publishes the
#                        header rule, and nothing noticed for four releases because
#                        nothing checked — see tools/header_check.sh, which now does.
#                        Version set to 0.5.0 to match the release it ships in rather
#                        than inventing a history it does not have.
#
# AI Project Scaffold — Sync Check
# Run before starting work to verify your ai/ files are current with remote.
# Usage: ./sync-check.sh [--verbose]

set -euo pipefail

# ---------------------------------------------------------------- quiet by default
#
# This runs at every session start, once per repository, and most of what it printed was
# [OK]. It now re-runs itself through tools/session_hook.sh --quiet-filter, which hides a
# one-line [OK] and progress lines, counts them, and prints everything else untouched. An
# [OK] carrying a caveat is a NOT-verified and still prints. The filter lives in
# session_hook.sh because that tool has a selftest and this script does not. A vendored
# session_hook.sh too old to have the filter means full output, never a filtered-away one.
# The help text is CAPTURED, not piped to `grep -q`: under pipefail, grep's early exit
# SIGPIPEs the writer and the probe reads as "unsupported" on every run.
if [ -z "${SCAFFOLD_VERBOSE:-}" ] && [ "${1:-}" != "--verbose" ] && [ -x tools/session_hook.sh ] \
   && case "$(tools/session_hook.sh --help 2>/dev/null)" in *--quiet-filter*) true ;; *) false ;; esac; then
  SCAFFOLD_VERBOSE=1 bash "$0" | tools/session_hook.sh --quiet-filter "$(basename "$PWD")"
  exit "${PIPESTATUS[0]}"
fi
# ---------------------------------------------------------------- the stuck-upgrader trap
#
# THE ONE FIX THAT CANNOT DELIVER ITSELF. `tools/scaffold_upgrade.sh` before 0.16.0 expands
# an empty array as "${_ORIG_ARGS[@]}" at the line that PERFORMS the handover. Under bash
# 3.2 — still the system bash on every Mac — an empty array under `set -u` is "unbound" and
# aborts. So a bare `tools/scaffold_upgrade.sh` dies in the OUTGOING copy, before control
# ever reaches the fixed one, and no future release can unstick it: reaching the new code is
# exactly what is broken.
#
# AND THE SIGNAL SHAPE IS THE WORST POSSIBLE. `--dry-run` is one argument, so the array is
# non-empty and the dry run passes CLEANLY. The bare run — the only one that writes — is the
# only one that fails.
#
# The escape is one argument. `--to <tag>` makes the array non-empty, the upgrade completes,
# and the copy it installs carries the fix, so bare works permanently afterwards. Reported
# from a real macOS adoption at 0.34.0 that hit this and had no way to be told.
if [ -f tools/scaffold_upgrade.sh ] && [ "${BASH_VERSINFO:-4}" -lt 4 ]; then
  _su_v="$(sed -n 's/^# Version:  *\([0-9][0-9.]*\).*/\1/p' tools/scaffold_upgrade.sh | head -1)"
  _su_mm="$(printf '%s' "${_su_v:-0.0.0}" | cut -d. -f1,2)"
  # Numeric compare on MAJOR.MINOR: "0.9" is above "0.16" as a string and below it as a
  # version, which is the comparison bug this project has already paid for twice.
  _su_maj="${_su_mm%%.*}"; _su_min="${_su_mm##*.}"
  if [ "${_su_maj:-0}" -eq 0 ] && [ "${_su_min:-0}" -lt 16 ]; then
    echo "[!]  YOUR UPGRADER CANNOT UPGRADE ITSELF ON THIS MAC."
    echo "     tools/scaffold_upgrade.sh is ${_su_v:-unknown}; bash here is ${BASH_VERSION:-3.x}."
    echo "     A BARE run aborts with '_ORIG_ARGS[@]: unbound variable' before it does"
    echo "     anything — and --dry-run PASSES, because one argument hides the bug."
    echo "     Pass any argument once, and the fix installs itself:"
    echo "         tools/scaffold_upgrade.sh --to 0.36.3.20260811.2350"
    echo "     Bare runs work normally after that. Nothing is damaged by the abort: it"
    echo "     happens before any file is written."
  fi
fi


# ------------------------------------------------------------------ remote CI
#
# LOCAL GREEN IS NOT CI GREEN, AND THIS PROJECT LEARNED THAT THE EXPENSIVE WAY.
# Measured 2026-08-08: the dev context repo was red for four hours while every local check
# passed, because the failing step lints by a header the local run never exercised — and it
# was the OWNER who noticed, not the toolchain. The lesson went into ai/MEMORY.md and then
# stayed a note, which is the failure this repo names most often: a rule with no checker
# behind it is not a rule.
#
# AN EXIT TRAP, NOT A LINE AT THE BOTTOM, AND THAT IS THE WHOLE POINT.
# This script exits early on four paths — it is the scaffold's own repo, there is no
# remote branch, ai/ is behind, not a git repo — and three of them are the states where
# you MOST want to know whether the remote is red. Written as a final statement it ran on
# exactly one path: the one where everything was already fine. That is the same shape as
# the archive nudge below, which branched on an exit code the tool stopped returning and
# went silent for five releases. A check placed where it cannot run is not a check.
#
# The trap does not change the exit status: bash preserves it across an EXIT handler that
# does not itself exit.
#
# Silent when it cannot ask — no gh, no auth, no GitHub remote, offline. See
# tools/ci_status.sh for why that is not a compromise: a check that errors on a plane is
# one people disable, and then none of the checks above run either.
report_remote_ci() {
  [ -x tools/ci_status.sh ] || return 0
  tools/ci_status.sh || true
}

# RECORD THAT THIS RAN, AND SAY WHAT HAS STOPPED RUNNING.
#
# The two halves belong together and only work together. A run log nobody reads is a file;
# a session-start check is the one thing guaranteed to look at it. And the finding it can
# make is the one nothing else in this toolchain can: `setup.sh --check` reports on the
# checks it RUNS, which by construction cannot include a check that no longer runs at all.
#
# This exists because four hooks — including this script's own — had never fired on the
# machine that develops this scaffold, and there was no artefact anywhere that could have
# shown it. Silence is what a passing check and an absent check both look like.
report_run_log() {
  [ -x tools/scaffold_log.sh ] || return 0
  tools/scaffold_log.sh --log "sync-check.sh" ok "" || true
  # Only the finding, not the inventory: a full table every session start is noise, and a
  # session-start report that is noise is one people stop reading.
  local quiet
  quiet="$(tools/scaffold_log.sh --report 14 2>/dev/null | grep -A 5 'have not run in')" || true
  [ -n "$quiet" ] && { echo ""; printf '%s\n' "$quiet"; }
  return 0
}
report_session_start() { report_remote_ci; report_run_log; }
trap report_session_start EXIT

# Check CLAUDE.md pointer health — a committed one-line '@AGENTS.md' import
# (Claude Code inlines AGENTS.md at load time; legacy symlinks also accepted)
if [ ! -f CLAUDE.md ] && [ ! -L CLAUDE.md ]; then
  echo "[!]  CLAUDE.md missing — Claude Code will not load the project standards."
  echo "     Fix: printf '@AGENTS.md\n' > CLAUDE.md"
  echo ""
elif [ ! -L CLAUDE.md ] && ! grep -q '^@AGENTS.md' CLAUDE.md 2>/dev/null; then
  echo "[!]  CLAUDE.md has no '@AGENTS.md' line — Claude Code may not load AGENTS.md."
  echo "     Fix: add a line containing exactly: @AGENTS.md"
  echo ""
fi

# Check skills mirror health — .agents/skills/ is canonical, .claude/skills/ is the
# mirror Claude Code actually reads. tools/skills_check.sh owns the comparison so there
# is ONE definition: it ignores intentional localcoder:begin blocks, and it names the
# direction of the fix (a mirror holding adopter-authored skills is not fixed by copying
# canonical over it — cp never removes).
if [ -x tools/skills_check.sh ]; then
  tools/skills_check.sh || true
elif [ -d .agents/skills ]; then
  if ! diff -rq .agents/skills .claude/skills >/dev/null 2>&1; then
    echo "[!]  .claude/skills/ does not match canonical .agents/skills/ — skills have drifted."
    echo "     Fix (canonical wins): cp -R .agents/skills/. .claude/skills/"
    echo ""
  fi
fi

# Is the vendored scaffold itself stale? Every other check here compares this project
# against ITS OWN origin; none compared the scaffold against upstream, which is how a
# project sat on v0.2.0 for four months without knowing. Cached 24h and silent offline,
# so the session-start path costs nothing on a normal day.
if [ -x tools/scaffold_version.sh ]; then
  tools/scaffold_version.sh || true
fi

# Determine current branch
BRANCH=$(git branch --show-current 2>/dev/null)
if [ -z "$BRANCH" ]; then
  echo "ERROR: Not in a git repository or no branch checked out."
  exit 1
fi

# Fetch latest from remote without merging
echo "[..] Fetching latest from origin..."
git fetch origin 2>/dev/null

# Check if remote branch exists
if ! git rev-parse --verify "origin/$BRANCH" >/dev/null 2>&1; then
  echo "[OK] No remote branch 'origin/$BRANCH' — nothing to compare."
  exit 0
fi

# Count commits where ai/ files changed that are on remote but not local
BEHIND=$(git rev-list HEAD..origin/"$BRANCH" -- ai/ | wc -l | tr -d ' ')

if [ "$BEHIND" -gt 0 ]; then
  echo ""
  echo "WARNING: ai/ files are $BEHIND commit(s) behind origin/$BRANCH"
  echo ""
  echo "Run this before starting work:"
  echo "  git pull origin $BRANCH"
  echo ""
  echo "Or if you are on a feature branch:"
  echo "  git fetch origin && git merge origin/$BRANCH"
  echo ""
  exit 1
else
  echo "[OK] ai/ files are current with origin/$BRANCH"
fi

# Also check for uncommitted changes to ai/ files
DIRTY=$(git status --porcelain ai/ 2>/dev/null | wc -l | tr -d ' ')
if [ "$DIRTY" -gt 0 ]; then
  echo "[!]  You have uncommitted changes in ai/:"
  git status --short ai/
fi

# Archive-threshold check — session-start files must stay small (ai/STANDARDS.md → Archiving).
# Archiving is a session-START duty: if over threshold, archive before starting new work.
# (Replaces the old SESSION-newer-than-MEMORY mtime advisory, which fired constantly
# during normal work and trained people to ignore it.)
# tools/session_archive.py is the single source of truth for the count — it excludes
# the template blocks a fresh scaffold ships with, which an inline grep counts as real
# sessions and which would otherwise consume retention slots. Falls back to the inline
# check when the tool is absent, so this script still works on its own.
# READ THE REPORT, DO NOT BRANCH ON THE EXIT CODE. This tested `if ! ... --check`, and
# 0.14.0 made that command advisory — it exits 0 whatever it finds. So from 0.14.0 to
# 0.15.3 the session-start archive nudge could not fire at all, in the script whose whole
# job is to nudge at session start. Nobody noticed because a check that has gone silent
# looks exactly like a check with nothing to report. The `[over]` marker in the output is
# the verdict now, and it is the same string the tool prints to a human.
if [ -x tools/session_archive.py ]; then
  ARCHIVE_REPORT="$(tools/session_archive.py --all --check 2>/dev/null || true)"
  if printf '%s' "$ARCHIVE_REPORT" | grep -q '\[over\]'; then
    printf '%s\n' "$ARCHIVE_REPORT" | grep -E '\[over\]|^ ' | sed 's/^/     /'
    echo "[!]  An ai/ file is over its archive line — archive BEFORE starting new work."
    echo "     Nothing is deleted; every path adds to an archive (ai/STANDARDS.md -> Archiving)."
  fi
  elif [ -f ai/SESSION.md ]; then
    S_LINES=$(wc -l < ai/SESSION.md | tr -d ' ')
    # NO SECOND DEFINITION OF THE CEILING. THIS IS THE THIRD TIME.
    #
    # v0.7.0 found this fallback hardcoding 150 while the shipped default was 600 and called
    # it "a second definition of a ceiling" -- then fixed it by hardcoding 600, which is
    # still a second definition; it merely agreed for a while. On 2026-08-20 the shipped
    # default moved to 800/900 and this line still said 600, in the one script that runs at
    # every session start. A number copied is a number that drifts.
    #
    # So it is no longer copied. If the archiver is vendored we never reach this branch; if
    # it is NOT, this script genuinely cannot know the project ceiling -- it is declared by a
    # scaffold:ceilings marker in ai/STANDARDS.md and parsing that is the tool's job, not a
    # shell fallback's. Report the COUNT, which is knowable, and say there is no ceiling to
    # compare against. Could-not-check, never a guessed verdict.
    echo "[!]  ai/SESSION.md is ${S_LINES} lines, and the archive line here is UNKNOWN."
    echo "     tools/session_archive.py is not vendored, so nothing can read this project's"
    echo "     ceiling -- it is declared by a scaffold:ceilings marker in ai/STANDARDS.md and"
    echo "     parsing that is the tool's job. This is a count, not a verdict."
    echo "     Vendor the tool (./setup.sh) for a real check, or ai/STANDARDS.md -> Archiving."
fi

