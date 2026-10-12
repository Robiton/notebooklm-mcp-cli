#!/usr/bin/env bash
# Project:  ai-project-scaffold
# File:     tools/session_currency.sh
# Modified: 2026-09-23
# Version:  0.3.2.20260923.0941
# Purpose:  A release with no session entry behind it is an undocumented release. This says so.
# Changelog:
#   2026-09-23 v0.3.2.20260923.0941 — fixtures run inside the root tools/fixture_guard.sh validates. There a git and a mktemp on PATH refuse anything that would land outside it. Every mktemp takes a ${TMPDIR} template, because macOS mktemp ignores TMPDIR without one.
#   2026-09-23 v0.3.1.20260923.0843 — every mktemp fails closed. A failed one left the temp variable empty, so the fixture ran in the caller's directory; header_check's committed into Robiton/control.
#   2026-09-14 v0.3.0.20260914.0624 — #307 ask whether the check can run BEFORE reading the pointer; scaffold:no-releases retires it cleanly.
#   2026-09-01 v0.2.0.20260901.0419 — A CHECK THAT CAN NEVER RUN HERE SAID THE LEAST (#258).
#                        This anchors the session log to the newest tag behind HEAD, and
#                        returned 3 with "no tag behind HEAD yet" for two opposite
#                        situations: a repo that tags and has not yet (temporary -- the next
#                        release fixes it), and a repo that never tags at all (permanent --
#                        nothing anyone installs will make this fire, ever). preflight renders
#                        a 3 under DID NOT RUN, so the permanent case read as a missing
#                        toolchain.
#                        Reported by an adopter whose repo has zero tags and ships from main,
#                        after a long session made six architectural decisions and updated
#                        none of MEMORY/SESSION/BACKLOG -- the exact drift this gate exists to
#                        catch, on a repository where it could not fire.
#                        TWO CASES, NOT ONE: the second asserts a repo that DOES tag is NOT
#                        told the gap is permanent, because a fix that made every rc=3 say
#                        "never" would pass the first case and be wrong.
#   2026-08-30 v0.1.1.20260830.0005 — A ROTTED POINTER IS NO LONGER ADVISORY (#245). run_check()
#                        separated "declared and absent" from "no log at all" on purpose, then
#                        returned the SAME code 1 that "the record is behind" uses -- and the
#                        dispatch treats 1 as advisory. So `--check` printed FAILED and exited
#                        0, and preflight printed [PASS] over a broken declaration. Declared
#                        and absent now returns 4, which is never advisory. Behind still
#                        returns 1 and stays advisory, so upgrading cannot break a push.
#   2026-08-19 v0.1.0 — Initial. Written the morning after shipping EIGHT releases in one day
#                        with zero session entries, through 44 green preflight gates, in a
#                        repository whose AGENTS.md says to checkpoint "at milestones (each
#                        merged PR or completed task)". Nothing checked. Every `SESSION.md`
#                        reference in preflight.sh was TEMPLATE detection — "is this still the
#                        unmodified stub" — and none of them asked whether it was CURRENT.
#                        The rule had been a preference for as long as it had existed.
#
# WHAT THIS CHECKS, AND WHAT IT DELIBERATELY DOES NOT
#
#   A tag is a milestone nobody can argue about. Prose is not mechanically checkable and this
#   does not try: it will not read your entry, judge whether it is any good, or verify it
#   describes the release. It answers exactly one question --
#
#       Is the newest release OLDER than the newest thing written down about this project?
#
#   -- and that question is enough to have caught the failure that produced this file.
#
#   DATES, NOT CONTENT, ON PURPOSE. An earlier draft required the session log to NAME the
#   newest tag. It fails on a legitimately written entry: "shipped 0.85.0 through 0.92.0"
#   documents eight releases and literally contains two of the eight version strings. A gate
#   that punishes the good summary and passes eight stub headings is worse than a date.
#
# THE TAG AT HEAD IS EXCLUDED, and this is the same rule the changelog needed
#   `release.sh` writes the tag AFTER the commit, so the session entry inside that commit can
#   never name the tag that commit creates. A check demanding otherwise is red at the instant
#   you release, which is a completely normal moment -- and a gate that is red at a normal
#   moment is one people learn to scroll past. That is not a hypothetical here: scrolling
#   past `session hooks are wired but the last start is not a recorded HOOK_RAN`, every run,
#   all day, is half of why this file exists.
#
# WHERE THE LOG LIVES IS DECLARED, because the split moved it out of every gate's view
#   `localcoder`'s session log is in `localcoder-dev`. Every gate ran scoped to the repo it
#   stood in, so the one file that should have been updated was outside the field of view of
#   all 44 of them. A repo whose log lives elsewhere declares it, at column 0 in
#   ai/BACKLOG.md:
#
#       <!-- scaffold:session-log ../localcoder-dev/ai/SESSION.md -->
#
#   IN ai/BACKLOG.md AND NOT IN AGENTS.md, WHICH IS NOT A STYLE CHOICE. `scaffold_upgrade.sh`
#   THREE-WAY MERGES AGENTS.md into every adopter, so a column-0 declaration there would
#   propagate -- pointing every adopter at a `-dev` repository they do not have, which this
#   tool correctly calls a FAILURE. One declaration in the wrong file would have turned this
#   check red for everybody who upgraded. ai/BACKLOG.md is in the never-touched set
#   (SESSION/BACKLOG/MEMORY/TEAM/version/CODEOWNERS), which is why `scaffold:status-repos`
#   already lives there; this follows that precedent rather than inventing a second one.
#
#   Undeclared means `ai/SESSION.md` here, which is right for a repo that was never split.
#   A declared path that does not exist is a FAILURE, not a skip -- otherwise renaming the
#   file retires the check and it just gets quieter, which is the `product-dir` lesson.
set -u

SELF="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
STRICT=0
QUIET=0
DEFAULT_LOG="ai/SESSION.md"

usage() {
  cat <<'USAGE'
session_currency.sh — is the newest release older than the newest session entry?

  --check       report and exit 0 (default; advisory, like every other record check)
  --strict      exit 1 when the log is behind the newest release
  --quiet       verdict line only
  --selftest    run the built-in cases
  -h, --help    this

Exit codes — the distinction matters and used to be lost (#245):
  0   current, or advisory-and-tolerated
  1   the record is BEHIND the newest release — advisory, waved through without --strict
  3   nothing to check (no log declared and none present, or nothing released yet)
  4   the DECLARED log does not exist — a broken configuration, NEVER advisory

Exit: 0 current (or advisory), 1 behind (--strict only), 3 could not run.
Declare a log outside this repo at column 0 in ai/BACKLOG.md (NOT AGENTS.md —
that file is merged into every adopter, so a declaration there propagates):
  <!-- scaffold:session-log ../other-repo/ai/SESSION.md -->
USAGE
}

say() { [ "$QUIET" -eq 1 ] || printf '%s\n' "$*"; }

# The declared log path, or the default. Column 0 only: an indented example in a fenced block
# is documentation, and reading it as a declaration is how a code sample starts configuring
# the tool that printed it.
# THE DECLARATION THAT RETIRES THIS CHECK (#307).
# A repository that never tags has no anchor, and before this there was no way to say so --
# the gate reported could-not-run forever, and permanently inert reads exactly like passing
# to anyone skimming a preflight. `control` is the honest case: a knowledge and routing repo
# that ships no artifact and correctly has zero tags.
#
# DECLARED, NOT INFERRED, matching scaffold:must-run and scaffold:no-artifact. Inferring it
# from "no tags yet" would retire the check on every repository the day before its first
# release, which is the opposite of what it is for.
#
# Column 0 only, and `grep -c` not `grep -q` -- see #306/#310 for why a pipeline is not used
# here at all.
no_releases_declared() {
  local root="${1:-.}"
  [ -f "$root/ai/STANDARDS.md" ] || return 1
  [ "$(grep -cE '^<!--[[:space:]]*scaffold:no-releases[[:space:]]*-->[[:space:]]*$' \
        "$root/ai/STANDARDS.md" 2>/dev/null || true)" != "0" ]
}

resolve_log() {
  local root="$1" declared=""
  if [ -f "$root/ai/BACKLOG.md" ]; then
    declared="$(grep -m1 '^<!-- scaffold:session-log ' "$root/ai/BACKLOG.md" 2>/dev/null \
                | sed -e 's/^<!-- scaffold:session-log //' -e 's/ *-->.*$//' -e 's/[[:space:]]*$//')"
  fi
  if [ -n "$declared" ]; then
    printf '%s\n' "$declared"
  else
    printf '%s\n' "$DEFAULT_LOG"
  fi
}

# The newest `## YYYY-MM-DD` heading. Sorted, not first-wins: "most recent at the top" is a
# convention the file states and cannot enforce, and a check that trusts ordering reports the
# wrong date the first time somebody appends instead of prepends.
newest_entry_date() {
  grep -oE '^## [0-9]{4}-[0-9]{2}-[0-9]{2}' "$1" 2>/dev/null \
    | sed 's/^## //' | sort -r | head -1
}

# The newest tag NOT at HEAD, as a date. See the header for why HEAD is excluded.
newest_release_date() {
  local root="$1" head_sha t
  head_sha="$(git -C "$root" rev-parse HEAD 2>/dev/null || echo none)"
  git -C "$root" tag --sort=-creatordate 2>/dev/null | while IFS= read -r t; do
    [ -n "$t" ] || continue
    [ "$(git -C "$root" rev-list -n1 "$t" 2>/dev/null)" = "$head_sha" ] && continue
    git -C "$root" log -1 --format=%ad --date=short "$t" 2>/dev/null
    break
  done
}

# How many tags are stranded past the log, for the message. A count is what turns "you are
# behind" into "you shipped eight of these and wrote about none of them", and the second one
# is the sentence that gets acted on.
releases_after() {
  local root="$1" since="$2" head_sha n=0 t d
  head_sha="$(git -C "$root" rev-parse HEAD 2>/dev/null || echo none)"
  while IFS= read -r t; do
    [ -n "$t" ] || continue
    [ "$(git -C "$root" rev-list -n1 "$t" 2>/dev/null)" = "$head_sha" ] && continue
    d="$(git -C "$root" log -1 --format=%ad --date=short "$t" 2>/dev/null)"
    [ -n "$d" ] || continue
    if [ "$d" \> "$since" ]; then n=$((n + 1)); fi
  done <<EOF
$(git -C "$root" tag --sort=-creatordate 2>/dev/null)
EOF
  printf '%s\n' "$n"
}

run_check() {
  local root="${1:-.}" logrel log entry rel n
  if ! git -C "$root" rev-parse --git-dir >/dev/null 2>&1; then
    say "session_currency: no git here — nothing to be behind of"
    return 3
  fi

  # ---- ASK WHETHER THE CHECK CAN RUN BEFORE ASKING ANYTHING ABOUT THE POINTER (#307).
  # This used to resolve and stat the declared log FIRST, so a repository that provably
  # cannot run this gate still hard-FAILED on a path the gate would never have read. Same
  # repo, no tags either way, only the declared path differing:
  #
  #     pointer at a path that does NOT exist  ->  rc=4  "the declared session log does not exist"
  #     pointer at a path that DOES exist      ->  rc=3  "it has no tags at all"
  #
  # The verdict flipped on whether an IRRELEVANT file happened to be present, and the honest
  # exit 3 was reachable only by accident. No anchor means the check cannot run, whatever the
  # pointer says. `git tag` unfiltered on purpose: tags on other branches make this the
  # TEMPORARY case, handled further down against $rel, not the permanent one.
  #
  # Invisible on the M5 for the usual adjacency reason -- every repo sits beside its -dev
  # sibling in one directory, so the declared path always resolved and the exit 4 branch was
  # never reached. Surfaced within a minute of the first preflight on a fresh M3 clone.
  if [ -z "$(git -C "$root" tag 2>/dev/null | head -1)" ]; then
    if no_releases_declared "$root"; then
      say "session_currency: RETIRED HERE — ai/STANDARDS.md declares scaffold:no-releases."
      say "    This repository does not cut releases, so there is no newest release to anchor"
      say "    the session record to. That is a DECLARED state, not a missing tool: the check"
      say "    is closed out here rather than reporting could-not-run forever."
      return 0
    fi
    say "session_currency: CANNOT RUN IN THIS REPOSITORY — it has no tags at all."
    say "    This check anchors the session log to the newest release. A repository that"
    say "    never tags has nothing to anchor to, so this will not fire here EVER — it is"
    say "    not waiting on a tool, a network or a machine."
    say "    If this repo ships from main and does not cut releases, declare that at column 0"
    say "    in ai/STANDARDS.md and the check retires cleanly instead of staying inert:"
    say "        <!-- scaffold:no-releases -->"
    return 3
  fi

  logrel="$(resolve_log "$root")"
  case "$logrel" in
    /*) log="$logrel" ;;
    *)  log="$root/$logrel" ;;
  esac

  if [ ! -f "$log" ]; then
    # DECLARED AND ABSENT IS A FAILURE. An undeclared default that is missing is a repo that
    # never adopted the convention; a DECLARED path that is missing is a pointer that rotted,
    # and treating those the same is how renaming a file silently retires its check.
    if [ "$logrel" = "$DEFAULT_LOG" ]; then
      say "session_currency: no $DEFAULT_LOG and none declared — nothing to check"
      return 3
    fi
    say "session_currency: FAILED — the declared session log does not exist"
    say "    declared: $logrel"
    say "    Fix the scaffold:session-log line in ai/BACKLOG.md, or create the file."
    # RETURN 4, NOT 1, AND THE DISTINCTION IS THE WHOLE POINT OF THE COMMENT ABOVE (#245).
    # This function separated "rotted pointer" from "no log at all" deliberately, and then
    # handed both the SAME code 1 that "the log is behind the newest release" uses. The
    # dispatch treats 1 as advisory -- correct for a stale record, wrong for a broken
    # declaration -- so `--check` printed FAILED and exited 0, and preflight printed
    # [PASS] over it. A gate that cannot fail is not a gate.
    return 4
  fi

  entry="$(newest_entry_date "$log")"
  rel="$(newest_release_date "$root")"

  if [ -z "$rel" ]; then
    # TWO DIFFERENT ANSWERS WORE ONE MESSAGE (#258). "No tag behind HEAD" is TEMPORARY on a
    # repo that tags -- cut a release and this check starts working. It is PERMANENT on a
    # repo that does not: an app deployed from main by docker compose has zero tags, will
    # never have one, and this check can therefore never fire there no matter how far the
    # session record drifts. Both printed the same line, and preflight rendered both under
    # "DID NOT RUN on this machine" -- which is the wrong frame twice over, since nothing
    # anyone installs will change it.
    #
    # Reported by an adopter (product-tracker, zero tags) after a long session made six
    # architectural decisions and updated none of MEMORY/SESSION/BACKLOG. The gate that
    # exists to catch exactly that could not fire, and said so in the register of a missing
    # toolchain.
    #
    # `git tag` WITH NO FILTER, deliberately: newest_release_date() asks for tags BEHIND
    # HEAD, and a repo whose only tags are on other branches is the temporary case, not the
    # permanent one.
    # The zero-tag case is settled ABOVE, before the pointer is touched (#307). Reaching
    # here means the repo HAS tags and none is behind HEAD -- the temporary case, which the
    # next release fixes. Re-testing for zero tags here would be dead code that reads like
    # a live branch.
    say "session_currency: no tag behind HEAD yet — nothing released to document"
    say "    (this repository DOES tag, so this check starts working at your next release)"
    return 3
  fi
  if [ -z "$entry" ]; then
    say "session_currency: BEHIND — $logrel has no dated entry at all, and $rel has shipped"
    say "    Entries are headed '## YYYY-MM-DD'."
    return 1
  fi

  if [ "$entry" \< "$rel" ]; then
    n="$(releases_after "$root" "$entry")"
    say "session_currency: BEHIND — newest release $rel, newest entry $entry"
    if [ "$n" -gt 1 ]; then
      say "    $n releases have shipped since anything was written down."
    fi
    say "    The record is $logrel. The conversation is disposable; that file is not."
    return 1
  fi

  say "session_currency: current — newest entry $entry is not behind release $rel"
  return 0
}

# ------------------------------------------------------------------ selftest
# DRIVES REAL GIT AND REAL FILES. A fixture that stubs the tag list proves the string
# comparison and nothing else, and the string comparison was never the part at risk.
SELFTEST_TMP=""
# A GLOBAL, NOT A `local`. The EXIT trap fires after the function's scope is gone, so a
# `local tmp` leaves the trap dereferencing an unset name -- and under `set -u` that turns a
# clean run into "line 291: tmp: unbound variable" printed AFTER "all cases pass". Caught by
# running it, not by reading it: every case had already reported ok.
cleanup_selftest() { [ -n "$SELFTEST_TMP" ] && rm -rf "$SELFTEST_TMP"; }

selftest() {
  local rc fails=0 out tmp
  # FIXTURES RUN INSIDE A GUARDED ROOT (tools/fixture_guard.sh). Later mktemps land inside it,
  # and a git on PATH refuses any write outside it. The guard exists because a failed mktemp
  # once let a selftest run git init and commit in the real repo.
  . "$(dirname "${BASH_SOURCE[0]}")/fixture_guard.sh" || { echo "session_currency: tools/fixture_guard.sh is missing; refusing to build fixtures" >&2; exit 1; }
  fixture_root FG_ROOT; trap fg_cleanup EXIT
  SELFTEST_TMP="$(mktemp -d "${TMPDIR:-/tmp}/session_currency.XXXXXX")" || { echo "session_currency: mktemp failed; stopping" >&2; exit 1; }; tmp="$SELFTEST_TMP"
  trap cleanup_selftest EXIT

  mk_repo() {
    local d="$1"
    mkdir -p "$d/ai"
    git -C "$d" init -q 2>/dev/null || return 1
    git -C "$d" config user.email t@t; git -C "$d" config user.name t
    printf 'x\n' > "$d/f"; git -C "$d" add -A; git -C "$d" commit -qm one
  }
  ck() {
    local name="$1" want="$2" got="$3" detail="${4:-}"
    if [ "$want" = "$got" ]; then printf '  ok   %s\n' "$name"
    else printf '  FAIL %s (want rc=%s got rc=%s) %s\n' "$name" "$want" "$got" "$detail"; fails=1; fi
  }

  # 1. no tags at all -> could-not-run, never a pass
  local a="$tmp/a"; mk_repo "$a"
  printf '# S\n\n## 2026-01-01 — x\n' > "$a/ai/SESSION.md"
  out="$(run_check "$a" 2>&1)"; rc=$?
  ck "no tags is could-not-run" 3 $rc
  # 1b. AND IT SAYS THE GAP IS PERMANENT, NOT ENVIRONMENTAL (#258). Both this case and case 2
  #     return 3 and used to print the same sentence, while meaning opposite things: this one
  #     can never fire here, case 2 fires at the next release. preflight renders a 3 under
  #     "DID NOT RUN", so a permanent repository gap read as a missing toolchain.
  case "$out" in
    *"CANNOT RUN IN THIS REPOSITORY"*) printf '  ok   %s\n' "no tags at all says the check can NEVER run here" ;;
    *) printf '  FAIL %s: %s\n' "no tags at all is reported as permanent" "$out"; fails=1 ;;
  esac

  # 1c. THE ORDERING, ASSERTED THE ONLY WAY THAT CATCHES IT (#307): same repo, no tags, and
  #     ONLY the declared path differs. Before the fix these returned 4 and 3 respectively --
  #     a repo that provably cannot run the gate hard-FAILED on a path the gate never reads,
  #     and the honest 3 was reachable only when an irrelevant file happened to exist.
  #     Both must now be 3, because neither has an anchor. Asserting just one of the two
  #     passes with the bug still in.
  printf '<!-- scaffold:session-log ../nowhere/ai/SESSION.md -->\n' > "$a/ai/BACKLOG.md"
  out="$(QUIET=1 run_check "$a" 2>&1)"; rc=$?
  ck "no tags + a pointer that does NOT resolve is could-not-run, not FAILED" 3 $rc
  mkdir -p "$tmp/a-side/ai"; printf '# S\n\n## 2026-01-01 — x\n' > "$tmp/a-side/ai/SESSION.md"
  printf '<!-- scaffold:session-log ../a-side/ai/SESSION.md -->\n' > "$a/ai/BACKLOG.md"
  out="$(QUIET=1 run_check "$a" 2>&1)"; rc=$?
  ck "no tags + a pointer that DOES resolve is the same verdict" 3 $rc
  rm -f "$a/ai/BACKLOG.md"

  # 1d. AND THE DECLARATION RETIRES IT CLEANLY rather than leaving it inert forever (#307).
  #     `control` is the real case: a knowledge repo that ships nothing and correctly has
  #     zero tags, where could-not-run reads the same as passing to anyone skimming.
  printf '<!-- scaffold:no-releases -->\n' > "$a/ai/STANDARDS.md"
  # NOT under QUIET -- this case asserts the WORDING as well as the code, and QUIET=1
  # suppresses say(), so the message assertion below would compare against an empty string
  # and pass for the wrong reason. Caught by writing the test and watching it fail on a
  # blank `out` while the return code was already correct.
  out="$(run_check "$a" 2>&1)"; rc=$?
  ck "a declared no-releases repo RETIRES the check" 0 $rc
  case "$out" in
    *"RETIRED HERE"*) printf '  ok   %s\n' "and it says retired, not could-not-run" ;;
    *) printf '  FAIL %s: %s\n' "a retired check must not read as could-not-run" "$out"; fails=1 ;;
  esac
  # 1e. INDENTED IS DOCUMENTATION, NOT CONFIGURATION — the same rule every other marker
  #     here obeys. A fix that matched anywhere on the line would retire the check from a
  #     paragraph explaining how to retire the check.
  printf 'Example:\n\n    <!-- scaffold:no-releases -->\n' > "$a/ai/STANDARDS.md"
  out="$(QUIET=1 run_check "$a" 2>&1)"; rc=$?
  ck "an indented no-releases example is not a declaration" 3 $rc
  rm -f "$a/ai/STANDARDS.md"

  # 2. tag at HEAD is EXCLUDED — the release moment must not be red
  git -C "$a" tag 1.0.0 -m 1.0.0 2>/dev/null || git -C "$a" tag 1.0.0
  out="$(run_check "$a" 2>&1)"; rc=$?
  ck "the tag at HEAD is excluded" 3 $rc
  # 2b. ...AND THIS ONE MUST NOT CLAIM TO BE PERMANENT. Same exit code, opposite meaning; a
  #     fix that made every rc=3 say "never" would pass 1b and be wrong here.
  case "$out" in
    *"CANNOT RUN IN THIS REPOSITORY"*) printf '  FAIL %s: %s\n' "a repo that DOES tag was called permanently inert" "$out"; fails=1 ;;
    *"starts working at your next release"*) printf '  ok   %s\n' "a repo that tags is told the gap is temporary" ;;
    *) printf '  FAIL %s: %s\n' "the temporary case names neither outcome" "$out"; fails=1 ;;
  esac

  # 3. a tag BEHIND head, with a stale log -> behind
  printf 'y\n' >> "$a/f"; git -C "$a" add -A; git -C "$a" commit -qm two
  out="$(run_check "$a" 2>&1)"; rc=$?
  ck "released after the newest entry is BEHIND" 1 $rc
  case "$out" in *"newest entry 2026-01-01"*) : ;;
    *) printf '  FAIL the message does not name the entry date: %s\n' "$out"; fails=1 ;;
  esac

  # 4. write an entry dated today -> current
  printf '# S\n\n## %s — x\n' "$(date +%Y-%m-%d)" > "$a/ai/SESSION.md"
  out="$(QUIET=1 run_check "$a" 2>&1)"; rc=$?
  ck "an entry on/after the release is current" 0 $rc

  # 5. NEWEST entry wins even when the file is not in date order. The "most recent at the
  #    top" convention is stated by the file and enforced by nobody.
  printf '# S\n\n## 2026-01-01 — old\n\n## %s — new\n' "$(date +%Y-%m-%d)" > "$a/ai/SESSION.md"
  out="$(QUIET=1 run_check "$a" 2>&1)"; rc=$?
  ck "out-of-order entries still resolve to the newest" 0 $rc

  # 6. a declared log in ANOTHER directory is followed — the split case this exists for
  local b="$tmp/b"; mk_repo "$b"
  mkdir -p "$tmp/b-dev/ai"
  printf '# S\n\n## 2026-01-01 — stale\n' > "$tmp/b-dev/ai/SESSION.md"
  printf '<!-- scaffold:session-log ../b-dev/ai/SESSION.md -->\n' > "$b/ai/BACKLOG.md"
  git -C "$b" add -A; git -C "$b" commit -qm decl
  git -C "$b" tag 2.0.0; printf 'z\n' >> "$b/f"; git -C "$b" add -A; git -C "$b" commit -qm three
  out="$(QUIET=1 run_check "$b" 2>&1)"; rc=$?
  ck "a sibling-repo log is read" 1 $rc
  printf '# S\n\n## %s — fresh\n' "$(date +%Y-%m-%d)" > "$tmp/b-dev/ai/SESSION.md"
  out="$(QUIET=1 run_check "$b" 2>&1)"; rc=$?
  ck "and it goes green when THAT file is updated" 0 $rc

  # 7. a DECLARED path that does not exist fails; it does not skip — AND IT IS NOT
  # ADVISORY. This asserted rc=1 until 2026-08-30, which was the bug (#245): 1 is also
  # what "the record is behind" returns, and the dispatch exits 0 on 1 without --strict.
  # So the assertion was green while `--check` printed FAILED and exited 0 over a broken
  # declaration. 4 is the code that cannot be waved through.
  printf '<!-- scaffold:session-log ../nope/ai/SESSION.md -->\n' > "$b/ai/BACKLOG.md"
  out="$(QUIET=1 run_check "$b" 2>&1)"; rc=$?
  ck "a declared-but-missing log FAILS with the non-advisory code" 4 $rc

  # 7b. THE DISTINCTION, ASSERTED END TO END rather than inferred from the return value:
  # a rotted pointer must survive `--check`, and a merely-behind record must not.
  ( cd "$b" && bash "$SELF" --check >/dev/null 2>&1 ); rc=$?
  ck "...and --check does NOT wave a rotted pointer through" 4 $rc

  # 8. an INDENTED declaration is documentation, not configuration
  local c="$tmp/c"; mk_repo "$c"
  printf 'Example:\n\n    <!-- scaffold:session-log ../wrong/ai/SESSION.md -->\n' > "$c/ai/BACKLOG.md"
  printf '# S\n\n## %s — x\n' "$(date +%Y-%m-%d)" > "$c/ai/SESSION.md"
  git -C "$c" add -A; git -C "$c" commit -qm doc; git -C "$c" tag 3.0.0
  printf 'q\n' >> "$c/f"; git -C "$c" add -A; git -C "$c" commit -qm four
  out="$(QUIET=1 run_check "$c" 2>&1)"; rc=$?
  ck "an indented example is not a declaration" 0 $rc

  # 9. --strict is what turns the advisory into a gate
  printf '# S\n\n## 2026-01-01 — stale\n' > "$c/ai/SESSION.md"
  out="$(QUIET=1 STRICT=0 run_check "$c" 2>&1)"; rc=$?
  ck "the check itself always reports the truth" 1 $rc

  # 10. the count is reported when more than one release is stranded
  git -C "$c" tag 3.1.0; printf 'r\n' >> "$c/f"; git -C "$c" add -A; git -C "$c" commit -qm five
  git -C "$c" tag 3.2.0; printf 's\n' >> "$c/f"; git -C "$c" add -A; git -C "$c" commit -qm six
  out="$(run_check "$c" 2>&1)"; rc=$?
  case "$out" in *"releases have shipped since"*) printf '  ok   multiple stranded releases are counted\n' ;;
    *) printf '  FAIL no count for multiple stranded releases: %s\n' "$out"; fails=1 ;;
  esac

  if [ "$fails" -eq 0 ]; then echo "session_currency --selftest: all cases pass"; return 0; fi
  echo "session_currency --selftest: FAILURES above"; return 1
}

MODE=check
while [ $# -gt 0 ]; do
  case "$1" in
    --check)    MODE=check ;;
    --strict)   STRICT=1 ;;
    --quiet)    QUIET=1 ;;
    --selftest) MODE=selftest ;;
    -h|--help)  usage; exit 0 ;;
    *) echo "session_currency: unknown argument $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

case "$MODE" in
  selftest) selftest; exit $? ;;
  check)
    run_check "."; rc=$?
    # ADVISORY BY DEFAULT, AND THE DEFAULT IS ARGUABLE. Exit 1 only under --strict, so
    # adding this to a pipeline cannot break somebody's push on the day they upgrade.
    # Whether the release gate should be strict is a judgement about how much a missing
    # record is worth blocking for -- see tools/README.md.
    # 1 = the record is BEHIND — advisory, so upgrading cannot break somebody's push.
    # 4 = the declaration is BROKEN — never advisory. See run_check() and #245.
    if [ "$rc" -eq 1 ] && [ "$STRICT" -eq 0 ]; then exit 0; fi
    exit $rc
    ;;
esac
