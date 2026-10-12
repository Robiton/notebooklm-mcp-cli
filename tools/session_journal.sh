#!/usr/bin/env bash
# Project:  ai-project-scaffold
# File:     tools/session_journal.sh
# Modified: 2026-09-23
# Version:  0.4.4.20260923.0941
# Purpose:  Capture session FACTS continuously so a lost session loses narrative, not work.
# Changelog:
#   2026-09-23 v0.4.4.20260923.0941 — fixtures run inside the root tools/fixture_guard.sh validates. There a git and a mktemp on PATH refuse anything that would land outside it. Every mktemp takes a ${TMPDIR} template, because macOS mktemp ignores TMPDIR without one.
#   2026-09-22 v0.4.3.20260922.0445 — the `end` arm named the template too (#320). #314 fixed
#                        this sentence in `start` and left its twin in `end`, where it told the
#                        reader to write a dated entry into the one file preflight hard-fails on.
#                        Hidden by two things that are each correct: SessionEnd fires about 6% of
#                        the time (187 sessions started across the four repos, 12 ended), and
#                        this arm's stdout goes to /dev/null by the 0.7.0 per-event policy.
#   2026-09-22 v0.4.2.20260922.0428 — the warning can now go quiet, so it detects something (#319).
#                        The count was `grep -c '^- '` over a file only ever appended to, with
#                        no truncation, rotation or watermark anywhere in the tool — so once the
#                        journal was non-empty the message fired in EVERY session, forever, with
#                        a number that only grew. 161 entries across 58 sessions and 24 days here,
#                        135 in localcoder, every one of them a false alarm. The condition it
#                        exists to announce — a session that ended without anyone writing the
#                        log — was therefore undetectable. The watermark needed no new signal:
#                        the declared log's own newest dated heading is exactly "when somebody
#                        last wrote this down", and #314 already resolves that path one line
#                        away. Distilled is an ALLOWLIST — an undated line, an unreadable date,
#                        or no watermark at all is un-distilled, and the no-watermark case
#                        reports the whole journal AND says which situation it is (#316).
#   2026-09-21 v0.4.1.20260921.1202 — name the log this repo actually distils into (#314).
#                        The fold instruction hardcoded ai/SESSION.md. Here the distilled
#                        log is the -dev sibling, declared in ai/BACKLOG.md exactly as
#                        tools/session_currency.sh reads it, and ai/SESSION.md is a SHIPPED
#                        template that ADOPTION_GUIDE step 3 copies verbatim into every new
#                        adoption (`cp -r "$SCAFFOLD_DIR/ai" .`). So this tool spent every
#                        session telling whoever read it to do the one thing a gate BLOCKS:
#                        tools/preflight.sh:2103 hard-fails, upstream only, if SESSION.md,
#                        MEMORY.md or BACKLOG.md grows a dated entry. The instruction and
#                        the gate disagreed, and the instruction pointed away from the real
#                        destination the marker had named all along.
#                        I first filed #314 claiming NOTHING would have caught a leak here,
#                        citing shipped-ai-kind's `template) : ;;` no-op. That was wrong --
#                        the guard is the separate gate directly beneath it, and I found it
#                        in the preflight run for this very fix. Nothing was ever close to
#                        shipping; the defect is a wrong signpost, not a leak.
#   2026-09-01 v0.4.0.20260901.1656 — a `commit` mode, for every tool that is not Claude
#                        Code (#279). Every record-keeping entry point here is a Claude Code
#                        lifecycle hook, so a Cursor, Codex or plain-terminal session read
#                        the standards and wrote nothing while the README claimed the record
#                        travels regardless of tool. A commit is the one event every tool
#                        produces, and .githooks/post-commit now calls this.
#                        NOT `checkpoint`. checkpoint compares HEAD against a state file only
#                        a session hook ever writes, so on a machine where no Claude session
#                        has run there is no state file, no diff, a clean tree immediately
#                        after the commit, and nothing recorded. Measured: two commits, an
#                        empty journal. This mode records the commit it was called for --
#                        a fact it does not have to infer -- and seeds the state file.
#   2026-08-12 v0.3.1 — Same `grep -c ... || echo 0` defect as setup.sh and the workflow: on
#                        an empty journal this printed a count that was literally two lines
#                        long, mid-sentence. Swept, not fixed one site at a time.
#   2026-08-09 v0.3.0 — THE JOURNAL WAS LOGGING ITSELF ON EVERY TURN, and it now has a
#                        selftest at all. `git status --porcelain` COLLAPSES untracked
#                        files into a directory entry, so with the journal untracked it
#                        reported `?? ai/` and never named ai/SESSION_JOURNAL.md — the
#                        filter on that path matched nothing, and the tool counted its
#                        own directory as a project change. `-uall` lists the files.
#                        The code claimed to be "correct by construction" against exactly
#                        this; the construction filtered a path git had already hidden.
#                        Latent wherever the journal is gitignored — which is every repo
#                        that ran setup.sh — and LIVE for precisely the adopter that
#                        guard was written to protect.
#                        Nine cases. This tool is wired to three hook events, runs on
#                        every session in four repos, and had no test of any kind: every
#                        failure path is swallowed, so it could do anything or nothing
#                        and look identical. It did nothing at all until 0.17.0, and the
#                        first test written after it started running found this.
#   2026-07-31 v0.1.0 — Initial creation
#
# THE PROBLEM THIS SOLVES
#   ai/SESSION.md is written by the agent at the END of a session. If the session
#   dies first — context exhausted, window closed, crash, laptop asleep — the entire
#   record is lost. That is not hypothetical: the project this came from ran sessions
#   long enough that SESSION.md was written once, hours in, from memory.
#
# THE SPLIT THAT MAKES THIS WORK
#   Hooks capture FACTS automatically (what changed, what was committed, when).
#   The agent writes NARRATIVE (why, what was decided, what to do next).
#   If the session dies, the facts survive and the narrative is reconstructable.
#   Trying to make a hook write narrative would produce noise nobody reads.
#
# Usage (wired via .claude/settings.json hooks — see tools/README.md):
#   session_journal.sh start        # SessionStart
#   session_journal.sh checkpoint   # Stop — i.e. after every assistant turn
#   session_journal.sh end          # SessionEnd
#
# Portable bash rather than zsh: the scaffold ships to Linux and WSL as well as
# macOS, and its other scripts (setup.sh, sync-check.sh) are already bash.
set -u

# Resolve this script's directory without zsh's ${0:A:h}, following one symlink
# level so an installed copy still finds its repo.
self="${BASH_SOURCE[0]}"
[ -L "$self" ] && self="$(readlink "$self")"
here="$(cd "$(dirname "$self")" && pwd)"

# SESSION_JOURNAL_ROOT, not LOCALCODER_ROOT: the journal is not part of the
# local-coder workflow, and sharing that variable meant setting it for a
# localcoder reason silently relocated an unrelated tool's output.
ROOT="${SESSION_JOURNAL_ROOT:-$(cd "$here/.." && pwd)}"
JOURNAL="$ROOT/ai/SESSION_JOURNAL.md"
STATE="$ROOT/.session-journal-state"

# WHERE THE DISTILLED LOG LIVES IS NOT ALWAYS ai/SESSION.md (#314). ai/BACKLOG.md may declare
# it, and tools/session_currency.sh already reads that marker with this exact parse -- this is
# the same predicate, not a second one, and it is deliberately copied verbatim rather than
# re-derived. Undeclared means ai/SESSION.md, which is right for a repo that was never split.
#
# RESOLVE ONLY; DO NOT VALIDATE. session_currency.sh owns the verdict on a declared path that
# does not exist. A second copy of THAT predicate here would be the tenth copy of a predicate
# this repo has already been bitten by, and this tool is wired to SessionStart, where it must
# never fail a session.
session_log_path() {
  local declared
  declared="$(grep -m1 '^<!-- scaffold:session-log ' "$ROOT/ai/BACKLOG.md" 2>/dev/null \
              | sed -e 's/^<!-- scaffold:session-log //' -e 's/ *-->.*$//' -e 's/[[:space:]]*$//')"
  printf '%s' "${declared:-ai/SESSION.md}"
}

# THE DISTILLATION WATERMARK IS ALREADY IN THE LOG -- no new signal needs inventing (#319).
# A session entry is dated, so the NEWEST dated heading in the declared log is exactly
# "when somebody last wrote this down". The old code had no watermark at all: it counted
# `^- ` over a file that is only ever appended to, so once the journal was non-empty the
# warning fired in every session forever, with a number that only grew -- 161 entries
# across 58 sessions and 24 days in this repository the day it was found. The condition
# the tool exists to announce was therefore undetectable.
#
# The heading shapes accepted here are #318's SESSION_ENTRY_RE, deliberately: a month-only
# heading like `## 2026-03 (multiple sessions)` IS a real session entry, and a repo whose
# log carries only those must not be permanently stuck on the fallback. ISO dates compare
# correctly as strings, and a month-only watermark reads every day of that month as
# un-distilled, which is the safe direction.
#
# DAY GRANULARITY IS THE LIMIT, AND IT IS ALL THE LOG FORMAT OFFERS. Work done later on a
# day the log already has an entry for reads as distilled. That is a real miss, and still
# strictly better than an alarm that is on in every session and so detects nothing.
log_watermark() {  # newest dated heading in <file>, or "" when there is none
  [ -r "$1" ] || return 0
  grep -oE '^## [0-9]{4}-[0-9]{2}(-[0-9]{2})?' "$1" 2>/dev/null \
    | sed 's/^## //' | sort | tail -1
}

mode="${1:-checkpoint}"

# ------------------------------------------------------------------ selftest
#
# THIS TOOL RAN ON EVERY SESSION IN FOUR REPOS WITH NO TEST OF ANY KIND. It is wired to three
# hook events, it appends to a file nobody reads until something has gone wrong, and every
# failure path is swallowed by `2>/dev/null || true` — so it could do anything, or nothing,
# and look identical either way. It did in fact do nothing at all until 0.17.0 fixed the
# hooks, and the first thing a test found once it started running was that it logged ITSELF
# on every turn.
if [ "$mode" = "--selftest" ]; then
  fails=0
  # FIXTURES RUN INSIDE A GUARDED ROOT (tools/fixture_guard.sh). Later mktemps land inside it,
  # and a git on PATH refuses any write outside it. The guard exists because a failed mktemp
  # once let a selftest run git init and commit in the real repo.
  . "$(dirname "${BASH_SOURCE[0]}")/fixture_guard.sh" || { echo "session_journal: tools/fixture_guard.sh is missing; refusing to build fixtures" >&2; exit 1; }
  fixture_root FG_ROOT; trap fg_cleanup EXIT
  T="$(mktemp -d "${TMPDIR:-/tmp}/session_journal.XXXXXX")" || exit 1
  SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"

  chk() {  # chk <label> <expected> <actual>
    if [ "$2" = "$3" ]; then printf '  ok   %-58s\n' "$1"
    else printf '  FAIL %-58s expected=%s got=%s\n' "$1" "$2" "$3"; fails=$((fails + 1)); fi
  }
  fixture() {  # fixture [gitignore-the-journal]
    rm -rf "$T/r"; mkdir -p "$T/r/ai"
    ( cd "$T/r" && git init -q . && git config user.email a@b.c && git config user.name t
      printf 'x\n' > f.txt
      [ "${1:-}" = "ignored" ] && printf 'ai/SESSION_JOURNAL.md\n.session-journal-state\n' > .gitignore
      git add -A >/dev/null 2>&1 && git commit -qm one >/dev/null 2>&1 )
  }
  jlines() { wc -l < "$T/r/ai/SESSION_JOURNAL.md" 2>/dev/null | tr -d ' '; }
  run() { ( cd "$T/r" && SESSION_JOURNAL_ROOT="$T/r" bash "$SELF" "$@" ); }

  echo "session_journal selftest — it runs every session; it had no test at all"

  fixture
  run start >/dev/null 2>&1
  chk "start writes a session header" 1 \
      "$(grep -c '^## Session started' "$T/r/ai/SESSION_JOURNAL.md" 2>/dev/null | tr -d ' ')"

  # THE DEFECT THIS SUITE WAS WRITTEN FOR. Untracked files are collapsed by git into a
  # DIRECTORY entry, so filtering the journal's own path matched nothing and the journal
  # counted itself as a project change — logging a line on every turn, forever.
  before="$(jlines)"; run checkpoint >/dev/null 2>&1
  chk "a no-change checkpoint writes NOTHING" "$before" "$(jlines)"

  # And with the journal gitignored, which is every repo that ran setup.sh.
  fixture ignored
  run start >/dev/null 2>&1
  before="$(jlines)"; run checkpoint >/dev/null 2>&1
  chk "no-change checkpoint, journal gitignored" "$before" "$(jlines)"

  # A REAL change must still be recorded, or the fix above has broken the feature.
  printf 'changed\n' >> "$T/r/f.txt"
  run checkpoint >/dev/null 2>&1
  chk "a real edit IS recorded" 1 \
      "$(grep -c 'uncommitted file' "$T/r/ai/SESSION_JOURNAL.md" 2>/dev/null | tr -d ' ')"
  chk "and the file is named, so a dead session says what was in flight" 1 \
      "$(grep -c 'f\.txt' "$T/r/ai/SESSION_JOURNAL.md" 2>/dev/null | tr -d ' ')"

  # A NEW COMMIT is the other thing worth a line.
  ( cd "$T/r" && git add -A >/dev/null 2>&1 && git commit -qm two >/dev/null 2>&1 )
  run checkpoint >/dev/null 2>&1
  chk "a new commit is recorded" 1 \
      "$(grep -c 'committed:' "$T/r/ai/SESSION_JOURNAL.md" 2>/dev/null | tr -d ' ')"

  run end >/dev/null 2>&1
  chk "end writes a footer" 1 \
      "$(grep -c '^## Session ended' "$T/r/ai/SESSION_JOURNAL.md" 2>/dev/null | tr -d ' ')"

  # UN-DISTILLED ENTRIES ARE THE POINT OF THE TOOL: a session that ended without anyone
  # writing SESSION.md must be announced at the next start.
  out="$(run start 2>&1)"
  case "$out" in *"un-distilled"*) chk "start announces un-distilled entries" 1 1 ;;
                 *)                 chk "start announces un-distilled entries" 1 0 ;; esac

  # AND IT MUST NAME THE RIGHT FILE (#314). This fixture has no ai/BACKLOG.md, so it is the
  # undeclared case: ai/SESSION.md is the correct answer for a repo that was never split.
  # Re-using $out above -- same run, second property.
  case "$out" in *"Fold them into ai/SESSION.md"*) chk "undeclared: folds into ai/SESSION.md" 1 1 ;;
                 *)                                chk "undeclared: folds into ai/SESSION.md" 1 0 ;; esac

  # A DECLARED session-log MUST WIN. In this very repo it is ../ai-project-scaffold-dev, and
  # the file this tool used to name unconditionally is a SHIPPED TEMPLATE that
  # ADOPTION_GUIDE step 3 copies verbatim into every new adoption.
  #
  # THE DISCRIMINATOR HAS TO BE ABSENT FROM THE WRONG ANSWER. "../side-dev/ai/SESSION.md"
  # CONTAINS "ai/SESSION.md", so an assertion phrased as "the default is not named" passes
  # against BOTH answers and tests nothing. Match the prefix, which only the declared
  # answer can produce.
  printf '<!-- scaffold:session-log ../side-dev/ai/SESSION.md -->\n' > "$T/r/ai/BACKLOG.md"
  out="$(run start 2>&1)"
  case "$out" in *"Fold them into ../side-dev/ai/SESSION.md"*) chk "a declared session-log is named instead" 1 1 ;;
                 *)                                            chk "a declared session-log is named instead" 1 0 ;; esac

  # ---- #319: THE WARNING MUST BE ABLE TO GO QUIET -------------------------------------
  # It could not. The count was `grep -c '^- '` over an append-only file, so the message
  # fired in every session forever and the one condition it announces -- a session that
  # ended without anyone writing the log -- was undetectable. The discriminating case is
  # the FIRST one: a non-empty journal whose work IS already in the log. The old code
  # warns there, which is the whole bug, so that case goes red the moment this is reverted.
  jset() {  # jset <journal-body> <log-body>
    printf '<!-- scaffold:session-log ai/LOG.md -->\n' > "$T/r/ai/BACKLOG.md"
    printf '%b' "$1" > "$T/r/ai/SESSION_JOURNAL.md"
    printf '%b' "$2" > "$T/r/ai/LOG.md"
  }

  fixture
  jset '- 2026-09-20 a thing\n' '## 2026-09-21 — a session\n'
  out="$(run start 2>&1)"
  case "$out" in *un-distilled*) chk "a CURRENT log silences the warning" 1 0 ;;
                 *)               chk "a CURRENT log silences the warning" 1 1 ;; esac

  # A STALE log must still warn, and must count only what the log does NOT have. Asserting
  # merely that it warns would pass against the old code too -- the old code always warns.
  jset '- 2026-09-01 old\n- 2026-09-02 old\n- 2026-09-20 new\n' '## 2026-09-02 — a session\n'
  out="$(run start 2>&1)"
  case "$out" in *"1 un-distilled"*) chk "a STALE log warns, counting only what is newer" 1 1 ;;
                 *)                   chk "a STALE log warns, counting only what is newer" 1 0 ;; esac

  # DISTILLED IS AN ALLOWLIST: a line whose date does not parse is un-distilled, never
  # dropped. Filtering to dated lines and counting those would silently lose it.
  jset '- 2026-09-01 old\n- no date on this one\n' '## 2026-09-02 — a session\n'
  out="$(run start 2>&1)"
  case "$out" in *"1 un-distilled"*) chk "an UNDATED entry counts as un-distilled" 1 1 ;;
                 *)                   chk "an UNDATED entry counts as un-distilled" 1 0 ;; esac

  # NO WATERMARK IS NOT A PASS (#316). A log with no dated heading cannot measure anything,
  # so it reports the whole journal AND says which situation this is.
  jset '- 2026-09-01 old\n- 2026-09-02 old\n' '# Session Log\n\nnothing dated here\n'
  out="$(run start 2>&1)"
  case "$out" in *"2 un-distilled"*) chk "no watermark reports the WHOLE journal, not zero" 1 1 ;;
                 *)                   chk "no watermark reports the WHOLE journal, not zero" 1 0 ;; esac
  case "$out" in *"no dated entry"*) chk "and it says why it could not measure" 1 1 ;;
                 *)                  chk "and it says why it could not measure" 1 0 ;; esac

  # A MONTH-ONLY heading is a real session entry (#318), so it must work as a watermark
  # rather than dropping the repo onto the fallback forever.
  jset '- 2026-03-04 same month\n' '## 2026-03 (multiple sessions) — a session\n'
  out="$(run start 2>&1)"
  case "$out" in *un-distilled*) chk "a month-only heading is a usable watermark" 1 1 ;;
                 *)               chk "a month-only heading is a usable watermark" 1 0 ;; esac

  # #320: `end` NAMES THE RIGHT LOG TOO. Neither existing coverage nor real use would ever
  # surface this -- the event fires ~6% of the time and its stdout is redirected away by
  # design -- so the only thing that can catch it is a case that runs the arm directly.
  # The discriminator is the `ai/LOG.md` prefix: "ai/SESSION.md" is a SUBSTRING of nothing
  # here, but phrasing the assertion as "the default is absent" would pass against a tool
  # that named neither, so match what only the correct answer can produce.
  jset '- 2026-09-20 a thing\n' '## 2026-09-21 — a session\n'
  out="$(run end 2>&1)"
  case "$out" in *"distil into ai/LOG.md"*) chk "end names the DECLARED log, not the template" 1 1 ;;
                 *)                          chk "end names the DECLARED log, not the template" 1 0 ;; esac

  # NEVER BREAK A SESSION. Outside a git repo, or with an unwritable tree, it must exit 0 —
  # it is wired to SessionStart, and a non-zero exit there is a developer's first impression.
  rm -rf "$T/nogit"; mkdir -p "$T/nogit/ai"
  ( cd "$T/nogit" && SESSION_JOURNAL_ROOT="$T/nogit" bash "$SELF" checkpoint >/dev/null 2>&1 )
  chk "outside a git repo it still exits 0" 0 $?

  rm -rf "$T"
  echo ""
  if [ "$fails" -eq 0 ]; then echo "  all checks passed"; exit 0; fi
  echo "  $fails check(s) FAILED"; exit 1
fi

stamp="$(date "+%Y-%m-%d %H:%M:%S")"

cd "$ROOT" 2>/dev/null || exit 0

# Never let a journal problem break the developer's session.
{
  case "$mode" in
    start)
      branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo '?')"
      head_sha="$(git rev-parse --short HEAD 2>/dev/null || echo '?')"
      # An un-distilled journal from last time means a session ended without the
      # agent writing SESSION.md — say so loudly, because that is the exact
      # failure this tool exists to make visible.
      if [ -s "$JOURNAL" ]; then
        log_rel="$(session_log_path)"
        case "$log_rel" in /*) log_abs="$log_rel" ;; *) log_abs="$ROOT/$log_rel" ;; esac
        mark="$(log_watermark "$log_abs")"

        # DISTILLED IS AN ALLOWLIST. An entry is distilled only if its date PARSES and is
        # at or before the watermark. Everything else -- an undated line, a date we cannot
        # read, no watermark at all -- counts as un-distilled and is never silently
        # dropped. A tool that cannot compute the property must not report the clean
        # answer, which is #316's rule and the reason #319 existed at all.
        #
        # ENVIRON[], not awk -v: `-v` runs the value through awk's own conversion, and this
        # repository has already lost an afternoon to a `-v` assignment arriving as a
        # number. The comparison is forced to strings for the same reason.
        if [ -n "$mark" ]; then
          entries="$(SJ_MARK="$mark" awk '
            BEGIN { m = ENVIRON["SJ_MARK"] "" }
            /^- / {
              if ($0 ~ /^- [0-9]{4}-[0-9]{2}-[0-9]{2}/) {
                d = substr($0, 3, 10)
                if (d "" > m) n++
              } else n++
            }
            END { print n + 0 }' "$JOURNAL" 2>/dev/null)"
          why=""
        elif [ ! -r "$log_abs" ]; then
          entries="$(grep -c '^- ' "$JOURNAL" 2>/dev/null || true)"
          why=" — the whole journal, because $log_rel cannot be read"
        else
          entries="$(grep -c '^- ' "$JOURNAL" 2>/dev/null || true)"
          why=" — the whole journal, because $log_rel carries no dated entry"
        fi
        # `grep -c` prints "0" AND exits 1 on no matches; `|| echo 0` appended a second
        # line, so this printed a two-line count mid-sentence. Swept 2026-08-11.
        case "$entries" in ''|*[!0-9]*) entries=0 ;; esac

        if [ "$entries" -gt 0 ]; then
          printf '[journal] %s un-distilled entry(ies) in ai/SESSION_JOURNAL.md%s\n' "$entries" "$why"
          printf '[journal] Fold them into %s before starting new work.\n' "$log_rel"
        fi
      fi
      printf '\n## Session started %s (branch %s @ %s)\n' "$stamp" "$branch" "$head_sha" >> "$JOURNAL"
      git rev-parse HEAD 2>/dev/null > "$STATE"
      ;;

    checkpoint)
      # Only record when something actually changed. A turn that answered a
      # question does not deserve a line, and a journal full of no-ops is a
      # journal nobody reads.
      last="$(cat "$STATE" 2>/dev/null || echo '')"
      now="$(git rev-parse HEAD 2>/dev/null || echo '')"
      # Never count the journal's OWN artefacts as project changes. They should be
      # gitignored (setup.sh adds the entries), but if that line is ever missing the
      # journal makes the tree permanently dirty and then logs itself every single
      # turn, forever. Correct by construction rather than by config.
      # `-uall` IS LOAD-BEARING, AND ITS ABSENCE MADE THIS COMMENT FALSE.
      #
      # By default git COLLAPSES untracked files into a directory entry: with the journal
      # untracked, `git status --porcelain` says `?? ai/` and never names
      # `ai/SESSION_JOURNAL.md` at all — so a filter on the file path matched nothing, the
      # journal counted its own directory as a project change, and it logged itself on every
      # turn, forever. Exactly the failure the paragraph above claims to be correct by
      # construction against; the construction was filtering a path git had already hidden.
      #
      # Latent wherever the journal IS gitignored, which is every repo that ran `setup.sh` —
      # and live for precisely the adopter that guard was written to protect.
      dirty="$(git status --porcelain -uall 2>/dev/null \
               | grep -v 'ai/SESSION_JOURNAL\.md' \
               | grep -v '\.session-journal-state')"
      changed="$(printf '%s' "$dirty" | grep -c . | tr -d ' ')"
      newcommits=""
      if [ -n "$last" ] && [ -n "$now" ] && [ "$last" != "$now" ]; then
        newcommits="$(git log --oneline "$last..$now" 2>/dev/null | sed 's/^/    - /')"
        printf '%s\n' "$now" > "$STATE"
      fi
      if [ -z "$newcommits" ] && [ "$changed" = "0" ]; then
        exit 0
      fi
      {
        printf -- '- %s — %s uncommitted file(s)\n' "$stamp" "$changed"
        if [ -n "$newcommits" ]; then
          printf '  committed:\n'
          printf '%s\n' "$newcommits"
        fi
        # Name the files so a dead session still says WHAT was being worked on.
        printf '%s\n' "$dirty" | grep . | head -8 | sed 's/^/    /'
      } >> "$JOURNAL"
      ;;

    commit)
      # ---- THE ONE EVENT EVERY TOOL PRODUCES (#279) ----------------------------------
      #
      # Called from .githooks/post-commit, which git runs for Cursor, Codex, a plain
      # terminal and anything else. Every other entry point here is a Claude Code
      # lifecycle hook, so without this the journal is empty for most of the world.
      #
      # NOT `checkpoint`. checkpoint compares HEAD against the state file and exits 0 when
      # they match -- and on a machine where no session hook has ever run there IS no state
      # file, so `last` is empty, `newcommits` is empty, the tree is clean immediately after
      # a commit, and it records nothing. Tried it: two commits, an empty journal. This mode
      # records the commit it was called for, which is a fact it does not have to infer, and
      # seeds the state file so a later checkpoint has a floor to compare against.
      now="$(git rev-parse HEAD 2>/dev/null || echo '')"
      [ -n "$now" ] || exit 0
      subject="$(git log -1 --format='%h %s' 2>/dev/null || echo '')"
      {
        printf -- '- %s — committed\n' "$stamp"
        printf '  committed:\n'
        printf '    - %s\n' "$subject"
      } >> "$JOURNAL"
      printf '%s\n' "$now" > "$STATE"
      ;;

    end)
      # THE SECOND SITE OF #314, AND IT SURVIVED THAT FIX (#320). This arm hardcoded
      # ai/SESSION.md too -- the file preflight.sh hard-fails on here, because setup.sh
      # copies it verbatim into every adopting project. It stayed hidden because two
      # independent things bury it: SessionEnd fires about 6% of the time (187 sessions
      # started across the four repos, 12 ended), and this arm's stdout is redirected to
      # /dev/null by the correct per-event policy from 0.7.0. A line that runs rarely,
      # into a redirect, is one nobody reads -- including while fixing its twin.
      printf '## Session ended %s\n' "$stamp" >> "$JOURNAL"
      printf '[journal] session recorded in ai/SESSION_JOURNAL.md — distil into %s\n' "$(session_log_path)"
      ;;
  esac
} 2>/dev/null || true
exit 0
