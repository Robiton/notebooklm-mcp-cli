#!/usr/bin/env bash
# Project:  ai-project-scaffold
# File:     tools/session_hook.sh
# Modified: 2026-10-10
# Version:  0.11.6.20261010.1100
# Purpose:  The one entry point a session hook calls, so that whether it RAN is answerable
# Changelog:
#   2026-10-10 v0.11.6.20261010.1100 — the hook scan is scoped (report item 14). `for d in . */` ran a matching script in every child directory, so a repository cloned under an adopter ran code at session start with no trust prompt. The wrappers now run only CLAUDE_PROJECT_DIR when it is a scaffold root and keep the one-level scan for a workspace that is not. --check-wiring reports an unscoped head on any hook (exit 2); --wire swaps the head and keeps the body.
#   2026-10-09 v0.11.5.20261009.0902 — --ever-fired in a LINKED WORKTREE is too early to tell (exit 3), not NEVER FIRED (#368). Sessions open in the main checkout, so the worktree's log has tool rows and no starts by construction. The message quotes the main checkout's start count and warns against running start in the worktree to turn it green.
#   2026-09-24 v0.11.4.20260924.1023 — QUIET BY DEFAULT: the hook output goes through --quiet-filter, which hides a one-line [OK] and progress lines, prints everything else untouched, and ends with a count of what it hid. An [OK] carrying a caveat is a NOT-verified and still prints. --verbose / SCAFFOLD_VERBOSE=1 shows all.
#   2026-09-23 v0.11.3.20260923.0941 — fixtures run inside the root tools/fixture_guard.sh validates. There a git and a mktemp on PATH refuse anything that would land outside it. Every mktemp takes a ${TMPDIR} template, because macOS mktemp ignores TMPDIR without one.
#   2026-09-23 v0.11.2.20260923.0843 — every mktemp fails closed. A failed one left the temp variable empty, so the fixture ran in the caller's directory; header_check's committed into Robiton/control.
#   2026-09-22 v0.11.1.20260922.1855 — --check-wiring resolves each first-match launcher
#                                      the way bash does and reports a copy shadowed by a
#                                      newer one (exit 2). A backup folder sorting ahead of
#                                      the live repo ran a v0.5.0 guard that allows
#                                      --no-verify, and every text check passed.
#   2026-09-22 v0.11.0.20260922.1642 — --check-wiring reports a missing or stale
#                                      SessionStart:compact reminder (exit 2, wired but
#                                      rules not restored); --wire copies it from
#                                      settings.hooks.json
#   2026-09-22 v0.10.3.20260922.1631 — selftest 1b: fan out from a loop like the wiring;
#                                      bash 5 exec'd the last of a;b;c and moved its PPID
#   2026-09-22 v0.10.2.20260922.1622 — claim_fanout: GNU stat -f printed a File: block into
#                                      arithmetic on Linux; try stat -c first and require
#                                      digits
#   2026-09-22 v0.10.1.20260922.1532 — ONE FAN-OUT PER FIRING. The workspace wiring drops `break`, so every
#                        repo's copy scanned */ and journalled every repo again: N x N rows,
#                        N-1 with session=unknown (stdin already drained). The first scanning
#                        call under a parent claims the firing (mkdir); siblings return 0.
#                        Case 1b pins it; red with the claim removed.
#   2026-09-17 v0.10.0.20260917.0936 — #277 REACHED ALMOST NOBODY, AND BOTH TOOLS SAID IT HAD.
#                        0.7.0 made the redirect per-event: SessionStart and Stop stdout is
#                        READ -- the client puts it in the model's context -- so those two
#                        must speak, while SessionEnd and PreCompact stay silent. It shipped
#                        WRAP_SPEAKS/WRAP_SILENT and rewrote the hook commands accordingly.
#                        IT ONLY EVER REWROTE THE OLD `session_journal.sh` FORM. A command
#                        already calling the wrapper hit `if "session_hook.sh" in cmd:
#                        wired.append(event); continue` -- matched on the FILENAME, never on
#                        the redirect. So --check-wiring returned 0 over a blanket
#                        `>/dev/null 2>&1`, and --wire printed "nothing to rewire" and left
#                        it. Every repo wired to the wrapper BEFORE 0.7.0 kept the silencer
#                        permanently, with no way to discover it from either tool.
#                        FOUND BY DOGFOODING, IN THIS PROJECT'S OWN DEV REPO. Its three hook
#                        commands still carried the blanket redirect, so the journal's one
#                        instruction -- "N un-distilled entries ... fold them into
#                        ai/SESSION.md before starting new work" -- had gone to /dev/null on
#                        every session start since the wrapper landed. --check-wiring said
#                        "3 hook event(s) call tools/session_hook.sh", exit 0.
#                        The command is now compared to WRAP_FOR, not to the filename, and
#                        --wire repairs a drifted redirect in place.
#                        THE FIRST ATTEMPT AT THIS FIX SILENTLY DID NOTHING. The wrapper
#                        literal is `"$d/tools/session_hook.sh" start`, so a pattern
#                        expecting a bare space after `.sh` matched nothing and every
#                        command read as compliant -- the same shape of miss as the bug
#                        being fixed. Caught by running it, not by reading it.
#                        AND THE SECOND ATTEMPT WOULD HAVE DESTROYED WORKING CONFIG. It
#                        compared the whole command to WRAP_FOR() and called anything else
#                        drift -- so the hand-edited wrapper this machine runs, which skips
#                        `*-backup/` repos and drops the `break` to reach EVERY adopted repo
#                        rather than the first, was reported as broken and --wire would have
#                        silently overwritten both deliberate customisations. A diagnostic
#                        that eats what it was pointed at is worse than the silence it
#                        replaced. Only the trailing redirect is the scaffold's business now;
#                        the body of the command belongs to whoever wrote it.
#                        The redirect test itself then needed a third pass: `2>/dev/null`
#                        CONTAINS `>/dev/null`, so a substring check called the correct
#                        speaking form silenced and flagged every compliant command. stdout
#                        is discarded by a bare `>`, `1>`, `&>` or `>&` and never by `2>` --
#                        asserted over nine hand-built cases before it went in.
#                        Six selftest cases, verified to discriminate: with the comparison
#                        neutered they FAIL naming the cause. Two of them assert the
#                        customisation SURVIVES a repair, which is the property the second
#                        attempt broke and no earlier case would have noticed.
#   2026-09-08 v0.9.0.20260908.0403 — A BURST IS NOT A HISTORY. --ever-fired escalated on ROW
#                        COUNT alone, and the threshold was documented as "chosen so a
#                        genuinely new adoption cannot trip it". THAT WAS NEVER TESTED AND IT
#                        IS FALSE. Measured on a real fresh adoption built exactly as the
#                        README documents -- clone, setup.sh, then preflight as instructed --
#                        the run log held 101 ROWS SPANNING FIVE MINUTES, every one written
#                        by setup and preflight themselves. The adopter had followed the
#                        instructions and preflight FAILED them on a hook they never touched.
#                        Exactly the hazard 0.58.0 shipped to avoid, reintroduced through the
#                        count: the escalation asks HOW MUCH WAS WRITTEN while the claim it
#                        makes is THIS REPOSITORY HAS BEEN WORKED IN, and those differ
#                        precisely in the fresh-adoption case.
#                        Now requires SPAN as well as volume -- 12h, longer than any adoption
#                        sequence and shorter than a working day. Under that, exit 3.
#                        BOTH SELFTEST FIXTURES WROTE 60 ROWS AT ONE IDENTICAL TIMESTAMP,
#                        describing a repo that cannot exist, and both went red the moment
#                        span mattered. Spread across days -- the fixture has to carry the
#                        property it is named for. A new case pins the burst at exit 3.
#                        Verified three ways: burst 3, worked-in-with-no-start 1, has-fired 0.
#   2026-09-02 v0.8.0.20260902.1024 — --wire NOW PROVES ITSELF, because it was creating the
#                        condition that failed the next gate (#285). Reported from
#                        Robiton/product-tracker: preflight printed a GAP whose stated remedy
#                        is `--wire`, the adopter ran exactly that, `--check-wiring` confirmed
#                        it worked, and the next preflight went from PASSED to
#                        `[FAIL] session hooks are wired and have NEVER fired`. The tool
#                        recommended an action, they took it, and it broke the gate.
#                        THE CAUSE IS BENIGN AND STRUCTURAL. --ever-fired counts
#                        `session_hook:start` rows and before a rewire there are necessarily
#                        ZERO -- every prior start was logged under the old literal. Their
#                        repo had 2,656 rows, so it cleared the "not a young repo" bar
#                        instantly and returned 1 instead of 3. THE MESSAGE OFFERED TWO
#                        EXPLANATIONS AND NEITHER WAS THE ACTUAL ONE, so both sent them
#                        hunting a misconfiguration that was not there.
#                        Their own fix is what ships: --wire fires the wrapper once, which
#                        writes a real HOOK_RAN row and PROVES THE WRAPPER RUNS -- the check's
#                        whole purpose, satisfied rather than suppressed, and strictly better
#                        than the hooks-unavailable declaration the old message pointed at.
#                        A `session_hook:wired` row is recorded too, so --ever-fired can tell
#                        "no start since the wiring changed" from "never fired" for the two
#                        paths that do not run --wire: an older release, and a hand edit.
#                        And the message names the cause it could not name before.
#   2026-09-01 v0.7.0.20260901.1656 — THE JOURNAL'S ONLY INSTRUCTION STOPS GOING TO
#                        /dev/null (#277), and hook output shapes are now a gate (#276).
#                        SILENCED TWICE, MEASURED HERE: nine un-distilled entries waiting,
#                        the hook firing on every start, and the model receiving one line --
#                        `HOOK_RAN ... exited 0`. The journal's "fold them into ai/SESSION.md
#                        before starting new work" was discarded by this wrapper AND by the
#                        `>/dev/null 2>&1` on the hook command it writes into settings.json.
#                        Both are fixed. The exit code is still the contract; the text is the
#                        point, and it prints AFTER the outcome line so the verdict is never
#                        buried under the detail that explains it. correction_capture.py's
#                        stdout rides the same change: a captured correction nobody is told
#                        about is a correction that did not happen.
#                        THE REDIRECT IS NOW PER EVENT. A SessionStart hook's stdout reaches
#                        the model; a SessionEnd hook's reaches nobody. start and checkpoint
#                        speak, end and precompact stay silent. stderr is discarded
#                        everywhere -- a hook that reddens a terminal is a hook the user
#                        turns off, after which nothing is recorded at all.
#                        --check-output-shapes (#276): every command in settings.hooks.json
#                        is EXECUTED, in an empty directory, and its stdout validated against
#                        the schema for its own event. Both shipped PreCompact hooks emitted
#                        `hookSpecificOutput.additionalContext`, which PreCompact REJECTS, so
#                        the checkpoint rule had never once reached a model in any adopter.
#                        A grep over the JSON catches that one and misses the next; running
#                        the command catches the class.
#   2026-09-01 v0.6.0.20260901.0435 — --ever-fired, BECAUSE --closeout ANSWERS A DIFFERENT
#                        QUESTION (#264). --closeout reads the MOST RECENT start record,
#                        which is right for "did the hook work this session" and useless for
#                        "has this client ever called us once". An adopter had to answer the
#                        second by hand: two repositories, four days, 1333 logged rows, zero
#                        session_hook:start. Stop fires after every assistant turn, so zero
#                        checkpoints across that is a client never calling the hook, in a repo
#                        whose wiring reads correct and whose commands all work by hand.
#                        THE DISCRIMINATOR IS NOT "ZERO STARTS", it is zero starts in a log
#                        OTHER TOOLS HAVE BEEN WRITING TO. 0 fired, 3 too early to tell, 1
#                        never fired in a worked-in repo. 50 rows is the line -- about one
#                        session's tool activity, so a genuinely new adoption cannot trip it
#                        and the reported case (1333) is nowhere near it. Mutation-verified:
#                        dropping the threshold to 0 reddens the fresh-adoption case.
#   2026-09-01 v0.5.0.20260901.0419 — --closeout ANSWERS THE EITHER/OR IT USED TO REPORT
#                        (#262). On a log with no start record it printed "either the hook is
#                        not wired, or it has never fired" -- and preflight pointed readers
#                        HERE for the answer, having already established which one it is by
#                        calling --check-wiring one line earlier. The recommended command was
#                        strictly less informative than the line above it, on the diagnostic
#                        for a hook that has never run, where the two branches have entirely
#                        different fixes: edit settings, or start a session.
#                        It now calls --check-wiring itself -- a local file read, no cost --
#                        and says which. Two selftest cases, because a fix that always
#                        answers one of them is no better than the either/or.
#   2026-08-26 v0.4.0.20260826.0245 — The payload is read ONCE, and a second field is taken from
#                        it: transcript_path, which tools/correction_capture.py needs and which
#                        nothing can derive -- only the client knows where the conversation is.
#                        THE BUG THIS SHIPPED WITH FOR ONE ITERATION, kept because it is the
#                        exact class this file exists to remove: `SESSION="$(session_id)"` runs
#                        in a COMMAND-SUBSTITUTION FORK. A lazy stdin reader inside that fork
#                        fills its cache in the fork and drains the pipe for everyone, so the
#                        parent's next field read found EOF and returned empty. session_id was
#                        right, transcript_path was silently blank, capture never ran, and the
#                        hook still reported HOOK_RAN. The selftests passed 21/21 throughout --
#                        they asserted ONE field, and one field passing is exactly what a dead
#                        cache still permits. Found end to end, fixed by reading stdin in this
#                        shell before any substitution, and pinned by a 22nd case that asserts
#                        BOTH fields off ONE read. --dump-payload exists for that case.
#   2026-08-18 v0.3.0.20260818.2054 — --wire and --check-wiring, because SHIPPING THE WRAPPER IS
#                        NOT WIRING IT. The upgrade carries tools/ and deliberately leaves
#                        .claude/settings.json alone -- it is the developer's client
#                        configuration -- so every adopter would have received the wrapper
#                        and kept calling session_journal.sh directly, and P0-5 would have
#                        been "fixed" everywhere except where it was reported.
#                        --check-wiring names the events still on the old literal, --wire
#                        rewrites them and is idempotent, and a settings file it cannot
#                        parse is exit 3 and left untouched rather than overwritten.
#                        preflight reports it as a GAP, never a failure: a gate red on
#                        arrival in every adoption is one people skip.
#   2026-08-18 v0.1.0.20260818.2013 — Initial (P0-5, outside review).
#                        WHAT WAS WRONG. The hook commands lived as shell literals inside
#                        .claude/settings.json, one per event, each ending in
#                        `>/dev/null 2>&1; done; true`. Three outcomes -- the hook ran, there
#                        was no hook to run, and the hook failed -- arrived at the caller as
#                        the same silent success. The existing selftests proved the journal
#                        script can be executed directly; nothing proved the CLIENT invokes
#                        it, from the directory and environment people actually work in.
#                        That is the difference between a tested tool and a wired one, and
#                        this tree has now paid for it twice in a week.
#                        WHAT THIS DOES. One tracked wrapper with deterministic root
#                        discovery, which emits exactly one of HOOK_RAN / HOOK_SKIPPED /
#                        HOOK_UNVERIFIED per repository per event, carrying repo, event,
#                        commit, timestamp and reason -- into the run log, where
#                        `scaffold_log.sh --report` already answers "what has gone quiet".
#                        THE CLIENT-FACING EXIT IS STILL 0, AND THAT IS NOT THE `|| true`
#                        THIS REPLACES. A hook that fails the client is a hook the user
#                        turns off, and then nothing is recorded at all. The review's actual
#                        requirement was that a failure must not be INDISTINGUISHABLE from a
#                        success -- so the outcome is written down every time, and `--strict`
#                        returns it as an exit code for the tests and the closeout that need
#                        to act on it.
set -uo pipefail

SELF="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
SESSION="unknown"
EVENT=""
STRICT=0
MODE=hook

while [ $# -gt 0 ]; do
  case "$1" in
    --strict)   STRICT=1 ;;
    --selftest) MODE=selftest ;;
    --check-output-shapes) MODE=check_output_shapes ;;
    --report)   MODE=report ;;
    --wire)     MODE=wire ;;
    --check-wiring) MODE=check_wiring ;;
    --closeout) MODE=closeout ;;
    --ever-fired) MODE=ever_fired ;;
    --dump-payload) MODE=dump_payload ;;
    --quiet-filter) MODE=quiet_filter ;;
    --verbose)  export SCAFFOLD_VERBOSE=1 ;;
    -h|--help)  MODE=usage ;;
    -*)         echo "session_hook: unknown option: $1" >&2; exit 2 ;;
    *)          EVENT="$1" ;;
  esac
  shift
done

now_iso() { date -u +%Y-%m-%dT%H:%M:%SZ; }

# ---- QUIET BY DEFAULT (CONTROL, 2026-09-23) --------------------------------------------
#
# Every session start printed a HOOK_RAN line per repository and five [OK] lines per
# sync-check, around the one or two lines that needed reading. This hides WHAT PASSED AND
# NOTHING ELSE, and counts it:
#   - a one-line [OK]. An [OK] followed by an indented line is carrying a caveat ("only 1
#     of 3 alert features", "STRUCTURE ONLY"), which is a NOT-verified, so it prints whole;
#   - a HOOK_RAN with nothing after it. One followed by the journal's output keeps its
#     line, because it is the only thing naming which repository that output is about;
#   - [..] progress lines, which are not results and are not counted.
# Everything else prints exactly as it came. SCAFFOLD_VERBOSE=1 (or --verbose) turns it off.
# Also used by sync-check.sh, which has no selftest of its own; this one tests the filter.
quiet_filter() {  # quiet_filter [label] < output
  awk -v label="${1:-}" '
    function hide() { hidden++; pend = ""; kind = "" }
    function show() { print pend; pend = ""; kind = "" }
    function begin(line) {
      if (line ~ /^\[OK\]/)     { pend = line; kind = "ok";   return }
      if (line ~ /^HOOK_RAN /)  { pend = line; kind = "hook"; return }
      if (line ~ /^\[\.\.\]/)  { return }
      print line
    }
    {
      if (kind == "ok"   && $0 ~ /^[ \t]+[^ \t]/)                              { show(); print; next }
      if (kind == "hook" && $0 != "" && $0 !~ /^HOOK_/ && $0 !~ /^\[(OK|\.\.)\]/) { show(); print; next }
      if (kind != "") hide()
      begin($0)
    }
    END {
      if (kind != "") hide()
      if (hidden > 0)
        printf "(%s%d passing check(s) not shown; SCAFFOLD_VERBOSE=1 shows them)\n", (label != "" ? label ": " : ""), hidden
    }'
}

# WHICH SESSION THIS WAS. Without it, "did the hook run this session" can only be answered
# by timestamp proximity, which is a guess that gets more wrong the longer a session runs.
# The client passes its hook payload on stdin as JSON carrying session_id.
#
# READ WITH A TIMEOUT, NEVER A BARE `cat`. A client that leaves stdin open would hang the
# hook forever, and a hung SessionStart hook is worse than an unrecorded one -- it is the
# whole session. One second, and "unknown" is an acceptable answer.
# THE PAYLOAD IS READ ONCE, because stdin cannot be read twice. Two fields are wanted from
# it now -- session_id and transcript_path -- and a second reader would find an empty pipe
# and silently report "unknown", which is the failure this file exists to make impossible.
PAYLOAD=""
read_payload() {
  [ -n "$PAYLOAD" ] && return 0
  [ -t 0 ] && return 0
  local line
  # `|| [ -n "$line" ]` HANDLES A PAYLOAD WITH NO TRAILING NEWLINE. `read` returns
  # non-zero at EOF even when it read something, so the plain loop DISCARDS the last
  # line — and a one-line JSON object with no newline is entirely the last line. Caught
  # by the fixture, which is exactly how a real client would send it.
  while IFS= read -r -t 1 line || [ -n "$line" ]; do
    PAYLOAD="$PAYLOAD$line
"
    line=""
  done
  return 0
}

payload_field() {  # payload_field <name>
  read_payload
  [ -n "$PAYLOAD" ] || return 0
  printf '%s' "$PAYLOAD" \
    | sed -n "s/.*\"$1\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" \
    | head -1
}

session_id() {
  [ -n "${SCAFFOLD_HOOK_SESSION:-}" ] && { printf '%s' "$SCAFFOLD_HOOK_SESSION"; return 0; }
  [ -n "${CLAUDE_SESSION_ID:-}" ] && { printf '%s' "$CLAUDE_SESSION_ID"; return 0; }
  local id
  id="$(payload_field session_id)"
  [ -n "$id" ] && { printf '%s' "$id"; return 0; }
  printf 'unknown'
}

# WHERE THE CONVERSATION IS ON DISK. Only the client knows; there is no way to derive it.
transcript_path() {
  [ -n "${SCAFFOLD_HOOK_TRANSCRIPT:-}" ] && { printf '%s' "$SCAFFOLD_HOOK_TRANSCRIPT"; return 0; }
  [ -n "${CLAUDE_TRANSCRIPT_PATH:-}" ] && { printf '%s' "$CLAUDE_TRANSCRIPT_PATH"; return 0; }
  payload_field transcript_path
}

# ---------------------------------------------------------------- root discovery
# DETERMINISTIC AND ORDERED, so that "which repository did the hook act on" has one answer
# rather than depending on where the client happened to be started.
#
#   1. SCAFFOLD_HOOK_ROOT   an explicit override. Wins outright, and is how a test or an
#                           unusual client says exactly what it means.
#   2. CLAUDE_PROJECT_DIR   the client's own statement of the project it opened.
#   3. the git toplevel     of the working directory.
#   4. one level down       THE WORKSPACE CASE, and the only reason this is not a single
#                           root: this programme is four sibling repositories under one
#                           parent, and the client is started at the parent. A scan is the
#                           correct answer there and a guess anywhere else, so it is
#                           narrow -- exactly one level, and only directories that carry
#                           ai/STANDARDS.md, which is what makes a directory a scaffold
#                           project rather than merely a directory.
is_scaffold_root() { [ -f "$1/ai/STANDARDS.md" ]; }

discover_roots() {
  local top
  if [ -n "${SCAFFOLD_HOOK_ROOT:-}" ]; then
    printf '%s\n' "$SCAFFOLD_HOOK_ROOT"; return 0
  fi
  if [ -n "${CLAUDE_PROJECT_DIR:-}" ] && is_scaffold_root "$CLAUDE_PROJECT_DIR"; then
    printf '%s\n' "$CLAUDE_PROJECT_DIR"; return 0
  fi
  top="$(git rev-parse --show-toplevel 2>/dev/null || true)"
  if [ -n "$top" ] && is_scaffold_root "$top"; then
    printf '%s\n' "$top"; return 0
  fi
  is_scaffold_root "$PWD" && { printf '%s\n' "$PWD"; return 0; }
  local d found=0
  for d in */; do
    [ -d "$d" ] || continue
    if is_scaffold_root "${d%/}"; then
      printf '%s\n' "$(cd "${d%/}" && pwd)"; found=1
    fi
  done
  [ "$found" -eq 1 ] && return 0
  return 1
}

# True when discover_roots would reach the */ scan: nothing more specific named a root.
resolved_by_scan() {
  local top
  [ -n "${SCAFFOLD_HOOK_ROOT:-}" ] && return 1
  [ -n "${CLAUDE_PROJECT_DIR:-}" ] && is_scaffold_root "$CLAUDE_PROJECT_DIR" && return 1
  top="$(git rev-parse --show-toplevel 2>/dev/null || true)"
  [ -n "$top" ] && is_scaffold_root "$top" && return 1
  is_scaffold_root "$PWD" && return 1
  return 0
}

# claim_fanout -- 0 for the first scanning call under this parent for this event, 1 after.
# mkdir is the atomic claim; a claim older than 120s is a recycled PID, not a sibling.
claim_fanout() {
  local m="${TMPDIR:-/tmp}/scaffold-hook-fanout.$PPID.$EVENT" age mtime
  if mkdir "$m" 2>/dev/null; then return 0; fi
  # GNU first: GNU `stat -f` is filesystem mode and prints a "File:" block before failing.
  mtime="$(stat -c %Y "$m" 2>/dev/null || stat -f %m "$m" 2>/dev/null || true)"
  case "$mtime" in ''|*[!0-9]*) mtime=0 ;; esac
  age=$(( $(date +%s) - mtime ))
  if [ "$age" -gt 120 ]; then
    rmdir "$m" 2>/dev/null; mkdir "$m" 2>/dev/null && return 0
  fi
  return 1
}

# ---------------------------------------------------------------- the record
# ONE LINE PER REPOSITORY PER EVENT, and the three outcomes are three different words.
# `scaffold_log.sh --report` already answers "what has gone quiet"; this makes the session
# lifecycle one of the things it can answer about.
record() {  # record <root> <outcome> <reason>
  local root="$1" outcome="$2" reason="$3" repo commit line
  repo="$(basename "$root")"
  commit="$(git -C "$root" rev-parse --short HEAD 2>/dev/null || echo none)"
  line="$outcome repo=$repo event=$EVENT commit=$commit session=$SESSION at=$(now_iso) reason=$reason"
  printf '%s\n' "$line"
  if [ -x "$root/tools/scaffold_log.sh" ]; then
    # THE SESSION GOES IN THE RECORD, NOT ONLY IN THE PRINTED LINE. The printed line is
    # thrown away with the console; the log is what --closeout reads, and "which session"
    # is the question it exists to answer.
    ( cd "$root" && tools/scaffold_log.sh --log "session_hook:$EVENT" "$outcome" \
        "session=$SESSION $reason" ) \
      >/dev/null 2>&1
  fi
}

# A TEST AFFORDANCE, and it exists because one field passing proved nothing. session_id
# parsed correctly while transcript_path came back empty, for eight selftest runs.
dump_payload() {
  read_payload
  printf 'session=%s transcript=%s\n' "$(session_id)" "$(transcript_path)"
}

run_hook() {
  local roots rc=0 ran=0 failed=0 root jrc TP jout cout
  # READ STDIN IN THIS SHELL, BEFORE ANY COMMAND SUBSTITUTION TOUCHES IT.
  #
  # `SESSION="$(session_id)"` forks a subshell. A lazy reader inside that fork populates the
  # cache in the FORK and drains the pipe for everyone; the parent then reads an empty stdin
  # and every later field comes back blank. Found end to end, not by the selftests, which
  # passed 21/21 while transcript_path silently returned nothing and the hook still reported
  # HOOK_RAN -- the precise shape of failure this whole file was written to make impossible.
  read_payload
  SESSION="$(session_id)"
  case "$EVENT" in
    start|checkpoint|end|precompact) : ;;
    "") echo "session_hook: an event is required (start|checkpoint|end|precompact)" >&2; exit 2 ;;
    *)  echo "session_hook: unknown event '$EVENT'" >&2; exit 2 ;;
  esac

  roots="$(discover_roots || true)"
  # ONE FAN-OUT PER HOOK FIRING, HOWEVER THE WIRING LOOPS. A hook command run from a
  # workspace directory resolves by scanning */ and covers EVERY repository in one call. The
  # hand-edited workspace variant drops `break` on purpose so no repository is missed -- and
  # then every repository's copy of this script fans out again: N calls x N repositories,
  # N-1 of them reading an stdin the first call already drained (session=unknown). Six
  # repeated HOOK_RAN blocks per session start, in the model's context, every session.
  # Sibling calls share one parent (the wiring's bash -c), so the first claims the firing.
  if [ -n "$roots" ] && resolved_by_scan && ! claim_fanout; then
    return 0
  fi
  if [ -z "$roots" ]; then
    # NOTHING RESOLVED IS NOT NOTHING HAPPENED. It is the one outcome the old wiring could
    # not express at all, and it is the one that means the hook is silently doing nothing.
    printf 'HOOK_UNVERIFIED repo=- event=%s commit=- at=%s reason=no scaffold root resolved from %s\n' \
      "$EVENT" "$(now_iso)" "$PWD"
    [ "$STRICT" -eq 1 ] && return 3
    return 0
  fi

  while IFS= read -r root; do
    [ -n "$root" ] || continue
    if [ ! -x "$root/tools/session_journal.sh" ]; then
      record "$root" HOOK_SKIPPED "no tools/session_journal.sh in this project"
      continue
    fi
    # THE JOURNAL'S EXIT CODE IS THE CONTRACT. ITS TEXT IS THE POINT (#277).
    #
    # This line read `>/dev/null 2>&1` from the day it was written, and the reasoning was
    # sound for stderr and wrong for stdout: a hook that chatters on every event is noise,
    # so everything was silenced. What went with it was the ONLY channel that tells a model
    # there is unfinished record-keeping waiting:
    #
    #   [journal] 9 un-distilled entries from a previous session are in ai/SESSION_JOURNAL.md
    #   [journal] Fold them into ai/SESSION.md before starting new work.
    #
    # Measured 2026-09-01 in this repository: nine entries waiting, the hook firing on every
    # session start, and the model seeing one line -- `HOOK_RAN ... exited 0`. The scaffold's
    # central promise is that the record survives the session, and the instruction to keep it
    # was being written to /dev/null on every start for as long as the wrapper has existed.
    #
    # STDOUT IS CAPTURED AND REPLAYED; stderr still goes nowhere, because a journal that
    # cannot write says so through its exit code and this is a hook, not a terminal.
    jout="$( cd "$root" && tools/session_journal.sh "$EVENT" 2>/dev/null )"
    jrc=$?
    # CORRECTION CAPTURE RIDES THE SAME EVENT, and its outcome is deliberately NOT folded
    # into jrc. The journal is the contract this wrapper reports on; a capture tool that
    # cannot read a transcript must not turn a working journal into HOOK_UNVERIFIED.
    #
    # ITS STDOUT IS CAPTURED FOR THE SAME REASON AS THE JOURNAL'S. A capture that found a
    # correction and had no way to say so is a capture that did not happen, as far as the
    # session is concerned.
    cout=""
    if [ "$EVENT" = "checkpoint" ] && [ -f "$root/tools/correction_capture.py" ]; then
      TP="$(transcript_path)"
      if [ -n "$TP" ] && [ -f "$TP" ]; then
        cout="$( cd "$root" && python3 tools/correction_capture.py --root "$root" \
                   --transcript "$TP" 2>/dev/null )" || cout=""
      fi
    fi
    if [ "$jrc" -eq 0 ]; then
      record "$root" HOOK_RAN "session_journal.sh $EVENT exited 0"
      ran=$((ran + 1))
    else
      record "$root" HOOK_UNVERIFIED "session_journal.sh $EVENT exited $jrc"
      failed=$((failed + 1))
    fi
    # AFTER the outcome line, so the verdict is never buried under the detail it explains.
    [ -n "$jout" ] && printf '%s\n' "$jout"
    [ -n "$cout" ] && printf '%s\n' "$cout"
  done <<ROOTS
$roots
ROOTS

  if [ "$STRICT" -eq 1 ]; then
    [ "$failed" -gt 0 ] && rc=1
    [ "$ran" -eq 0 ] && [ "$failed" -eq 0 ] && rc=3
  fi
  return $rc
}

report() {
  local root
  root="$(discover_roots | head -1)"
  [ -n "$root" ] || { echo "session_hook: no scaffold root here"; return 3; }
  if [ ! -f "$root/ai/.scaffold-run-log" ]; then
    echo "session_hook: no run log in $(basename "$root") — the hook has never recorded here"
    return 3
  fi
  echo "session_hook — the last recorded outcome per event, in $(basename "$root"):"
  awk -F'\t' '$2 ~ /^session_hook:/ { last[$2] = $1 "  " $3 "  " $4 }
              END { for (k in last) printf "  %-26s %s\n", k, last[k] }' \
      "$root/ai/.scaffold-run-log" | sort
}

# ---------------------------------------------------------------- the wiring itself
# SHIPPING THE WRAPPER IS NOT WIRING IT. The upgrade carries tools/ and deliberately does
# not touch .claude/settings.json -- that file is the developer's client configuration and
# rewriting it silently would be exactly the kind of thing this project refuses to do.
# So the wiring is a REPORTED FACT with a one-command remedy, rather than an assumption:
# --check-wiring says which events still call the journal directly, and --wire rewrites
# them. Advisory in preflight, never fatal: a gate that is red on arrival in every
# adoption is one people learn to skip.
SETTINGS=".claude/settings.json"

wire_json() {  # <mode: check|write>
  SH_MODE="$1" \
  SH_TEMPLATE="${SCAFFOLD_HOOK_TEMPLATE:-$(cd "$(dirname "$SELF")/.." && pwd)/.claude/settings.hooks.json}" \
    python3 - "$SETTINGS" <<'WIREPY'
import json, os, re, sys
path = sys.argv[1]
mode = os.environ["SH_MODE"]
template = os.environ.get("SH_TEMPLATE", "")
if not os.path.exists(path):
    print("no %s here — this client is not wired at all" % path)
    sys.exit(3)
try:
    data = json.load(open(path))
except Exception as e:
    print("%s is not valid JSON (%s) — refusing to touch it" % (path, e))
    sys.exit(3)

# THE REDIRECT IS PER EVENT, BECAUSE THE AUDIENCE IS PER EVENT (#277).
#
# Every wrapper here ended in `>/dev/null 2>&1`, and for SessionStart and Stop that threw
# away the only channel the record-keeping has. A SessionStart hook's stdout is added to the
# model's context by the client; the journal's start message -- "N un-distilled entries are
# in ai/SESSION_JOURNAL.md, fold them into ai/SESSION.md before starting new work" -- was
# written to /dev/null on every session start since this wrapper existed. Same for the
# correction candidates that ride Stop.
#
# SessionEnd AND PreCompact STAY SILENT. Nothing reads their stdout, the session is over or
# about to lose its context, and a hook that chatters where nobody is listening is the noise
# the original blanket redirect was right to remove. stderr is discarded everywhere: a hook
# that fails must not put a red line in front of a user, or the user turns the hook off.
# THE SCAN IS FOR THE WORKSPACE, NOT FOR EVERY SESSION (report item 14). `for d in . */` ran
# a matching script in EVERY child directory, so a session opened in an adopter ran
# sync-check.sh -- or the PreToolUse guard -- out of any repository cloned beneath it, with
# no trust prompt for that child. The client says which project it opened
# (CLAUDE_PROJECT_DIR); when that is a scaffold root, only it runs. The one-level scan
# survives for the case it was written for: a session started in the PARENT of several
# adopted repos, where the parent itself is not one.
OLD_SCAN = "for d in . */; do"
SCOPED_SCAN = ('r="${CLAUDE_PROJECT_DIR:-.}"; if [ -f "$r/ai/STANDARDS.md" ]; '
               'then set -- "$r"; else set -- . */; fi; for d in "$@"; do')
WRAP_SPEAKS = ("bash -c '" + SCOPED_SCAN + " [ -x \"$d/tools/session_hook.sh\" ] || continue; "
               "\"$d/tools/session_hook.sh\" %s; break; done' 2>/dev/null")
WRAP_SILENT = ("bash -c '" + SCOPED_SCAN + " [ -x \"$d/tools/session_hook.sh\" ] || continue; "
               "\"$d/tools/session_hook.sh\" %s; break; done' >/dev/null 2>&1")
SPEAKS = {"start", "checkpoint"}


def WRAP_FOR(event_arg):
    return (WRAP_SPEAKS if event_arg in SPEAKS else WRAP_SILENT) % event_arg


# COMPARE THE PROPERTY, NOT THE WHOLE STRING.
#
# The first version of this check compared the command to WRAP_FOR() outright, and that is
# wrong in a way that would have done damage: the hook command is a place people legitimately
# customise. The machine this was written on runs a hand-edited variant that skips `*-backup/`
# directories and drops the `break` so the hook reaches EVERY adopted repo rather than the
# first one found. Both are deliberate, both are good, and a whole-string comparison called
# them drift and offered to overwrite them.
#
# What #277 is actually about is one bit: IS STDOUT DISCARDED. So that is what is asserted,
# and a repair rewrites only the trailing redirect and leaves the body of the command alone.
_REDIR = re.compile(r"\s*(?:>\s*/dev/null(?:\s+2>&1)?|1>\s*/dev/null|2>\s*/dev/null"
                    r"|>&\s*/dev/null|&>\s*/dev/null)\s*$")

# `2>/dev/null` CONTAINS `>/dev/null`, and a substring test therefore calls the CORRECT
# speaking form silenced -- which is what the first cut of this did, flagging every
# compliant command. stdout is discarded by a bare `>`, an explicit `1>`, `&>` or `>&`,
# and never by `2>`; the lookbehinds are the whole point of the pattern.
_STDOUT_GONE = re.compile(r"(?:(?<![0-9&])>|(?<![0-9])1>|&>|>&)\s*/dev/null")


def strip_redirect(cmd):
    """Peel trailing redirects off, so the body can be kept and re-terminated."""
    prev = None
    while prev != cmd:
        prev = cmd
        cmd = _REDIR.sub("", cmd)
    return cmd


def stdout_ok(cmd, event_arg):
    """True when stdout goes where this event's audience needs it to go."""
    tail = cmd[len(strip_redirect(cmd)):]
    swallowed = bool(_STDOUT_GONE.search(tail))
    return (not swallowed) if event_arg in SPEAKS else swallowed


def describe(cmd):
    tail = cmd[len(strip_redirect(cmd)):].strip()
    return "stdout is discarded (%s)" % tail if tail else "stdout is kept"


def retarget(cmd, event_arg):
    """Fix the redirect ONLY. Everything the author wrote before it survives."""
    body = strip_redirect(cmd)
    return body + (" 2>/dev/null" if event_arg in SPEAKS else " >/dev/null 2>&1")

stale, wired, changed, unscoped = [], [], 0, []
for event, groups in (data.get("hooks") or {}).items():
    for grp in groups:
        for h in grp.get("hooks", []):
            cmd = h.get("command", "")
            # THE UNSCOPED SCAN, on ANY hook that uses it -- sync-check and the guards too.
            # The rewrite swaps the loop head only, so a hand-written body (a *-backup/
            # skip, a dropped break) survives it exactly as the redirect repair's does.
            if OLD_SCAN in cmd and SCOPED_SCAN not in cmd:
                m3 = re.search(r"([\w.-]+\.(?:sh|py))\b", cmd)
                unscoped.append("%s -> runs %s in every child directory, not just this project"
                                % (event, m3.group(1) if m3 else "a script"))
                if mode == "write":
                    cmd = cmd.replace(OLD_SCAN, SCOPED_SCAN, 1)
                    h["command"] = cmd; changed += 1
            if "session_hook.sh" in cmd:
                wired.append(event)
                # THE REDIRECT IS PART OF THE WIRING, AND PRETENDING OTHERWISE MADE #277 A
                # FIX THAT REACHED ALMOST NOBODY.
                #
                # This branch used to `continue` on the strength of the wrapper's NAME. So a
                # command calling the wrapper with the pre-#277 blanket `>/dev/null 2>&1`
                # was "wired": --check-wiring returned 0 on it, and --wire -- which only ever
                # rewrote the OLDER `session_journal.sh` form -- skipped it and printed
                # "nothing to rewire". Both tools reported success over the exact defect #277
                # shipped to remove.
                #
                # The consequence is that #277 only ever reached repos still on the
                # pre-wrapper form. Every repo wired to the wrapper BEFORE it -- this
                # project's own included -- kept the blanket redirect permanently, with the
                # journal's one instruction ("N un-distilled entries ... fold them into
                # ai/SESSION.md before starting new work") going to /dev/null on every
                # session start, and no way to find out from either tool.
                #
                # So the command is now compared to the policy, not to the filename.
                # THE CLOSING QUOTE IS PART OF THE COMMAND. The wrapper literal reads
                # `"$d/tools/session_hook.sh" start`, so a pattern expecting a bare space
                # after `.sh` matches nothing and every command silently reads as compliant
                # -- which is the same shape of miss as the bug this branch exists to catch.
                # The first `.sh"` in the line belongs to the `[ -x ... ]` test and is
                # followed by `]`, not a word, so it cannot be matched by accident.
                m2 = re.search(r"session_hook\.sh\"?\s+(\w+)", cmd)
                if m2 and not stdout_ok(cmd, m2.group(1)):
                    stale.append("%s -> %s, but this event's stdout %s"
                                 % (event, describe(cmd),
                                    "is READ by the client"
                                    if m2.group(1) in SPEAKS else "is read by nobody"))
                    if mode == "write":
                        h["command"] = retarget(cmd, m2.group(1)); changed += 1
                continue
            m = re.search(r"session_journal\.sh (\w+)", cmd)
            if not m:
                continue
            stale.append("%s -> session_journal.sh %s" % (event, m.group(1)))
            if mode == "write":
                h["command"] = WRAP_FOR(m.group(1)); changed += 1

# THE POST-COMPACT REMINDER IS WIRING TOO.
#
# Compaction keeps a summary and drops the rules: AGENTS.md and STANDARDS.md were read at
# the start of the session, and nothing in the summary says "branch first, preflight before
# push, never --no-verify". The SessionStart:compact reminder is the one channel that puts
# them back, and a workspace settings.json written by hand had every lifecycle hook except
# that one -- so every session launched from the workspace came back from compaction with
# the rules gone and no tool that said so. The template (settings.hooks.json, next to this
# tool) owns the text; a missing or stale copy is reported, and --wire copies it in.
def _compact_group(d):
    for grp in (d.get("hooks") or {}).get("SessionStart", []):
        if grp.get("matcher") == "compact":
            for h in grp.get("hooks", []):
                if "COMPACTED" in h.get("command", ""):
                    return grp, h
    return None, None

tmpl_cmd, reminder = None, []
try:
    _g, _h = _compact_group(json.load(open(template)))
    tmpl_cmd = _h["command"] if _h else None
except Exception:
    pass
if tmpl_cmd and (data.get("hooks") or {}).get("SessionStart"):
    grp, h = _compact_group(data)
    if h is None:
        reminder.append("SessionStart:compact -> no post-compact reminder; the rules do not "
                     "survive compaction and nothing puts them back")
        if mode == "write":
            data["hooks"]["SessionStart"].append(
                {"matcher": "compact", "hooks": [{"type": "command", "command": tmpl_cmd}]})
            changed += 1
    elif h["command"] != tmpl_cmd:
        reminder.append("SessionStart:compact -> the reminder text differs from %s" % template)
        if mode == "write":
            h["command"] = tmpl_cmd; changed += 1

# A LAUNCHER THAT TAKES THE FIRST MATCH RUNS WHICHEVER COPY SORTS FIRST, NOT THE NEWEST.
#
# Every hook here finds its tool with `for d in . */`, and the guards exec the first one
# they find. The example file said that is safe because "every copy is identical". On
# 2026-09-22 it was not: the workspace held ai-project-scaffold-backup/, an Aug 9 copy that
# sorts before ai-project-scaffold/. So the freshly wired PreToolUse guard ran v0.5.0,
# which predates the --no-verify deny. Every text check passed, because the command text
# was correct. Only the file it resolved to was wrong. So resolve it here the way bash
# does, and report a copy that is shadowed by a newer one elsewhere in the same workspace.
root = os.path.dirname(os.path.dirname(os.path.abspath(path)))
def _ver(p):
    try:
        t = open(p, errors="ignore").read(4096)
    except OSError:
        return []
    m = re.search(r"(?m)^# Version:\s*(\S+)", t)
    return [int(x) for x in re.findall(r"\d+", m.group(1))] if m else []
shadowed = []
for event, groups in sorted((data.get("hooks") or {}).items()):
    for grp in groups if isinstance(groups, list) else []:
        for h in grp.get("hooks", []):
            cmd = h.get("command", "")
            m = re.search(r"\$d/tools/([\w.-]+)", cmd)
            if "*/" not in cmd or not m:
                continue
            rel = ["tools/" + m.group(1)] + sorted(
                os.path.join(d, "tools", m.group(1)) for d in os.listdir(root)
                if os.path.isdir(os.path.join(root, d)) and not d.startswith("."))
            found = [r for r in rel if os.access(os.path.join(root, r), os.X_OK)]
            if not found:
                continue
            first = found[0]
            best = max(found, key=lambda r: _ver(os.path.join(root, r)))
            if _ver(os.path.join(root, first)) < _ver(os.path.join(root, best)):
                s = ("%s -> runs %s (%s), but %s is %s; the launcher takes the first match"
                     % (event, first, ".".join(map(str, _ver(os.path.join(root, first)))) or "?",
                        best, ".".join(map(str, _ver(os.path.join(root, best))))))
                if s not in shadowed:
                    shadowed.append(s)
def _print_unscoped():
    for s in unscoped:
        print("    " + s)
    if unscoped:
        print("  A repository cloned under this one would have its script run at session start,")
        print("  with no trust prompt for it. Fix: tools/session_hook.sh --wire   (rewrites the")
        print("  loop head only; the scan is kept for a workspace that is not itself a project)")
def _print_shadowed():
    for s in shadowed:
        print("    " + s)
    if shadowed:
        print("  --wire cannot fix this. A shadowing copy is usually a backup folder: move it")
        print("  out of the workspace, or chmod -x its tools/ so the launcher skips it.")

if mode == "write":
    for s in shadowed:
        print("    not fixable by --wire: " + s)
    if changed:
        json.dump(data, open(path, "w"), indent=2)
        open(path, "a").write("\n")
        print("rewired %d hook command(s) to tools/session_hook.sh" % changed)
    else:
        print("nothing to rewire — %d event(s) already call the wrapper" % len(wired))
    sys.exit(0)

if stale:
    print("hook commands do not match the wiring policy:")
    for s in stale:
        print("    " + s)
    print("  A direct session_journal.sh call makes a FAILED hook indistinguishable from an")
    print("  absent one. A wrapper call with the wrong redirect is worse, because both this")
    print("  check and --wire used to pass it: SessionStart and Stop stdout is READ -- the")
    print("  client puts it in the model's context -- and a blanket >/dev/null 2>&1 throws")
    print("  away the journal's only instruction on every single session.")
    print("  Fix: tools/session_hook.sh --wire")
    for s in reminder:
        print("    " + s)
    _print_unscoped()
    _print_shadowed()
    sys.exit(1)
if not wired:
    print("no session lifecycle hooks are configured in %s" % path)
    _print_unscoped()
    _print_shadowed()
    sys.exit(3)
print("%d hook event(s) call tools/session_hook.sh" % len(wired))
# EXIT 2, NOT 1: the lifecycle hooks fire either way, and --closeout reads 1 as NOT WIRED.
if reminder or shadowed or unscoped:
    for s in reminder:
        print("    " + s)
    if reminder:
        print("  Fix: tools/session_hook.sh --wire   (copies the reminder from the template)")
    _print_unscoped()
    _print_shadowed()
    sys.exit(2)
sys.exit(0)
WIREPY
}

# ---------------------------------------------------------------- the closeout
# THE ONE COMMAND THAT REFUSES ON AN UNVERIFIED SESSION (P0-5, point 6).
#
# Everything above makes the outcome RECORDABLE. This makes it ACTIONABLE: a session that
# ends with no evidence the hook ever fired is a session whose journal is empty for a
# reason nobody has looked at, and that is exactly how four hooks on this programme's own
# machine went months without firing.
#
# AND AN HONEST WAY OUT, because a rule with no legitimate exit gets routed around. A
# client with no lifecycle integration at all is a real thing, and it is not a failure --
# it is a fact somebody has to write down, at column 0 in AGENTS.md:
#
#     <!-- scaffold:hooks-unavailable <which client, and why> -->
#
# A DECLARED GAP IS NOT THE SAME AS A GAP NOBODY NOTICED. The declaration is printed every
# time, so it stays visible rather than becoming a silent permanent opt-out.
# ==== HAS THIS HOOK EVER FIRED HERE, AND IS THE ANSWER MEANINGFUL YET? (#264) ============
#
# --closeout asks about the MOST RECENT start, which is the right question for "did the hook
# work this session". It is the wrong question for "has this client ever called us", and that
# is the one an adopter had to answer by hand: two repositories, four days, 1333 logged rows,
# and ZERO session_hook:start among them. Stop fires after every assistant turn, so zero
# checkpoints across 1333 rows is not a coincidence -- it is a client that never called the
# hook, in a repo where the wiring reads as correct and every command works by hand.
#
# THE HARD PART IS NOT DETECTING IT, IT IS NOT CRYING WOLF. preflight legitimately runs
# before the first session-start of a fresh adoption, and a check that reddens there is one
# people learn to skip -- this repository's own rule, and the hazard 0.58.0 shipped by
# forgetting it. So the discriminator is not "zero starts", it is "zero starts IN A LOG THAT
# OTHER TOOLS HAVE BEEN WRITING TO". A log with 900 preflight rows and no hook rows is not a
# fresh repo; it is a repo that has been worked in, repeatedly, with the hook never called.
#
#   0  it has fired here at least once
#   3  cannot tell yet — no log, or too few rows from anything to draw a conclusion
#   1  the log is substantial and NOTHING here has ever recorded a start
#
# 50 ROWS is the threshold: about one working session's worth of tool activity, chosen so a
# genuinely new adoption cannot trip it and the reported case (1333) is nowhere near the line.
EVER_FIRED_MIN_ROWS=50
# AND A MINIMUM SPAN, because rows alone cannot tell a worked-in repo from a setup burst.
# 12 hours: longer than any adoption sequence, shorter than a working day, so a repo used on
# two separate occasions clears it and a clone-setup-preflight run never does.
EVER_FIRED_MIN_SPAN=43200
# date(1) differs between BSD and GNU and this ships to both. Try each, echo nothing if
# neither parses -- the caller treats an empty result as "cannot tell" and skips the branch.
_epoch() {
  date -j -f '%Y-%m-%dT%H:%M:%SZ' "$1" '+%s' 2>/dev/null && return 0
  date -d "$1" '+%s' 2>/dev/null && return 0
  echo ""
}
ever_fired() {
  local root log rows starts
  root="$(discover_roots | head -1)"
  [ -n "$root" ] || { echo "session_hook: no scaffold root here" >&2; return 3; }
  log="$root/ai/.scaffold-run-log"
  if [ ! -f "$log" ]; then
    echo "session_hook: no run log in $(basename "$root") — nothing has recorded anything yet." >&2
    return 3
  fi
  rows="$(wc -l < "$log" 2>/dev/null | tr -d ' ')"; rows="${rows:-0}"
  starts="$(grep -c 'session_hook:start' "$log" 2>/dev/null || true)"; starts="${starts:-0}"
  if [ "$starts" -gt 0 ]; then
    echo "session_hook: has fired here — $starts recorded start(s) in $rows log row(s)."
    return 0
  fi
  if [ "$rows" -lt "$EVER_FIRED_MIN_ROWS" ]; then
    echo "session_hook: no start recorded yet, and only $rows log row(s) — too early to tell." >&2
    return 3
  fi
  # A REWIRE RESETS THE CLOCK, AND THE ROW COUNT DOES NOT KNOW THAT (#285).
  #
  # `--wire` fires the hook itself now, so this branch is the backstop for the two paths that
  # do not go through it: someone who rewired with an older release, and someone who edited
  # settings.json by hand. In both, every start predates the rewire and is logged under the
  # old literal, so the count is legitimately zero on a busy repo -- the exact shape that
  # made an adopter chase a misconfiguration that was not there.
  #
  # "Correctly wired, no session since" is the EXPECTED state for the whole window between
  # rewiring and the next session start. That is too-early-to-tell, which is what exit 3 is.
  if grep -q 'session_hook:wired' "$log" 2>/dev/null \
     && [ "$(awk -F'\t' '$2 == "session_hook:wired" { n = NR } END { print n + 0 }' "$log")" \
          -gt "$(awk -F'\t' '$2 == "session_hook:start" { n = NR } END { print n + 0 }' "$log")" ]; then
    echo "session_hook: rewired, and no session has started since — too early to tell." >&2
    echo "  This is the EXPECTED state between a rewire and the next session start, and it is" >&2
    echo "  indistinguishable from a broken hook by row count alone. Prove it now without" >&2
    echo "  waiting:  tools/session_hook.sh start" >&2
    return 3
  fi
  # ==== A BURST IS NOT A HISTORY (#307-class, measured 2026-09-08) =========================
  #
  # The 50-row threshold above is documented as "chosen so a genuinely new adoption cannot
  # trip it". THAT ASSUMPTION WAS NEVER TESTED AND IT IS FALSE. Measured today on a brand-new
  # adoption created exactly as the README documents -- clone, `setup.sh --type python-script`,
  # then `preflight.sh` as the guide instructs -- the run log held 101 ROWS SPANNING FIVE
  # MINUTES, all of them written by setup and preflight themselves. The adopter had done
  # nothing but follow the instructions, and preflight FAILED them on a session hook they had
  # never touched.
  #
  # That is the hazard 0.58.0 explicitly shipped to avoid, reintroduced through the row count:
  # the escalation asks "how much has been written" when the claim it makes is "this
  # repository has been WORKED IN", and those differ precisely in the fresh-adoption case.
  #
  # SO REQUIRE SPAN, NOT VOLUME. Real work accumulates rows across sessions and days; an
  # adoption produces them in one burst. A log whose entire history is shorter than this is
  # too early to tell -- exit 3 -- however many rows it holds.
  _first="$(awk -F'\t' 'NF && $1 ~ /^20/ { print $1; exit }' "$log" 2>/dev/null)"
  _last="$(awk -F'\t' 'NF && $1 ~ /^20/ { t = $1 } END { print t }' "$log" 2>/dev/null)"
  if [ -n "$_first" ] && [ -n "$_last" ]; then
    _fs="$(_epoch "$_first")"; _ls="$(_epoch "$_last")"
    if [ -n "$_fs" ] && [ -n "$_ls" ] && [ "$((_ls - _fs))" -lt "$EVER_FIRED_MIN_SPAN" ]; then
      echo "session_hook: no start recorded, and the whole log spans $(( (_ls - _fs) / 60 )) minute(s)" >&2
      echo "  across $rows row(s) — that is a setup burst, not a worked-in repository." >&2
      echo "  Too early to tell. Prove the hook now without waiting:" >&2
      echo "      tools/session_hook.sh start" >&2
      return 3
    fi
  fi
  # ==== A LINKED WORKTREE IS NOT WHERE SESSIONS OPEN (#368) ================================
  #
  # The run log is per-tree and git-ignored, and the hook writes it in the SESSION's working
  # directory. A session opened in the main checkout that edits in a `git worktree` leaves
  # this tree's log full of tool rows and empty of starts, by construction: the hook fired,
  # just not here. Reported by an adopter as a FAIL in the same session whose start hook had
  # demonstrably run. The remedy the message below prints would make it worse -- running
  # `start` in the worktree turns the check green without any hook having fired there.
  #
  # So a linked worktree is too early to tell (exit 3), and we say where the evidence lives.
  local _gd _cd _main _pfx _mlog _ms
  _gd="$( cd "$root" && cd "$(git rev-parse --git-dir 2>/dev/null)" 2>/dev/null && pwd -P )"
  _cd="$( cd "$root" && cd "$(git rev-parse --git-common-dir 2>/dev/null)" 2>/dev/null && pwd -P )"
  if [ -n "$_gd" ] && [ -n "$_cd" ] && [ "$_gd" != "$_cd" ]; then
    _main="$( cd "$root" && git worktree list --porcelain 2>/dev/null | sed -n '1s/^worktree //p' )"
    _pfx="$( cd "$root" && git rev-parse --show-prefix 2>/dev/null )"
    _mlog="$_main/${_pfx}ai/.scaffold-run-log"
    echo "session_hook: no start recorded in this LINKED WORKTREE — too early to tell." >&2
    echo "  The hook writes the run log where the session opened, and sessions open in the" >&2
    echo "  main checkout, so $rows tool row(s) and 0 starts here is the expected shape." >&2
    if [ -f "$_mlog" ]; then
      _ms="$(grep -c 'session_hook:start' "$_mlog" 2>/dev/null || true)"
      echo "  The main checkout's log ($_mlog) records ${_ms:-0} start(s)." >&2
    else
      echo "  The main checkout's log was not found at $_mlog." >&2
    fi
    echo "  Judge the hook from the main checkout. Do NOT run 'start' here to turn this" >&2
    echo "  green: that records a firing that did not happen in this tree." >&2
    return 3
  fi
  echo "session_hook: NEVER FIRED — $rows log rows written by other tools, 0 session_hook:start." >&2
  echo "  This repository has been worked in. The hook has not been called once." >&2
  echo "  The wiring can still be correct: --check-wiring reads settings.json, this reads" >&2
  echo "  what actually happened. A hook that is configured and never invoked records" >&2
  echo "  nothing, and an absent record is indistinguishable from a clean one." >&2
  echo "  Check the client is reading the settings file you wired (project vs user scope)." >&2
  echo "  IF YOU JUST RAN --wire: no start has been recorded under the new name yet. Fire it" >&2
  echo "  once and this passes honestly:  tools/session_hook.sh start" >&2
  echo "  Only if the client genuinely has no lifecycle hooks, declare it:" >&2
  echo "  <!-- scaffold:hooks-unavailable <client, and why> --> in AGENTS.md" >&2
  return 1
}

closeout() {
  local root log newest verdict why
  root="$(discover_roots | head -1)"
  [ -n "$root" ] || { echo "session_hook: no scaffold root here — nothing to close out" >&2; return 3; }

  why="$(grep -E '^<!--[[:space:]]*scaffold:hooks-unavailable[[:space:]]+[^>]*-->' \
         "$root/AGENTS.md" 2>/dev/null \
         | sed -E 's/^<!--[[:space:]]*scaffold:hooks-unavailable[[:space:]]+//; s/[[:space:]]*-->$//' \
         | head -1)"
  if [ -n "$why" ]; then
    echo "session_hook: HOOKS DECLARED UNAVAILABLE in $(basename "$root") — $why"
    echo "  Recorded, not assumed. Remove the declaration when the client supports them."
    return 0
  fi

  log="$root/ai/.scaffold-run-log"
  if [ ! -f "$log" ]; then
    echo "session_hook: UNVERIFIED — no run log in $(basename "$root")." >&2
    echo "  The session hook has never recorded anything here, so nothing shows it fired." >&2
    echo "  Fix the wiring: tools/session_hook.sh --check-wiring" >&2
    return 1
  fi

  # THE NEWEST `start` RECORD DECIDES. Not "is there a HOOK_RAN anywhere in the log" --
  # that is true forever after the first success and would pass every session after a
  # hook broke, which is the failure this is meant to catch.
  newest="$(awk -F'\t' '$2 == "session_hook:start" { line = $0 } END { print line }' "$log")"
  if [ -z "$newest" ]; then
    # ANSWER THE EITHER/OR INSTEAD OF REPORTING IT (#262). This branch printed "either the
    # hook is not wired, or it has never fired" -- and preflight sends readers HERE for the
    # answer, having already established which one it is by calling --check-wiring one line
    # earlier. So the recommended command was strictly less informative than the line above
    # it, on the diagnostic for a hook that has never run, where the two branches have
    # completely different fixes: edit settings, versus start a session and come back.
    #
    # We can settle it ourselves at no cost -- --check-wiring is a local file read.
    echo "session_hook: UNVERIFIED — the run log has no session_hook:start record." >&2
    local _cw=0; "$SELF" --check-wiring >/dev/null 2>&1 || _cw=$?
    if [ "$_cw" -eq 0 ] || [ "$_cw" -eq 2 ]; then
      echo "  The hook IS wired correctly, and has never fired in this project." >&2
      echo "  Nothing to edit. Start a session in this repo and run --closeout again;" >&2
      echo "  if it still says this, the hook is wired and silently not executing." >&2
    else
      echo "  The hook is NOT wired: settings do not call it." >&2
      echo "  Fix it: tools/session_hook.sh --wire   (--check-wiring names what is wrong)" >&2
    fi
    return 1
  fi
  verdict="$(printf '%s' "$newest" | awk -F'\t' '{print $3}')"
  case "$verdict" in
    HOOK_RAN)
      printf 'session_hook: verified — %s\n' \
        "$(printf '%s' "$newest" | awk -F'\t' '{printf "%s  %s", $1, $4}')"
      return 0 ;;
    *)
      echo "session_hook: UNVERIFIED — the most recent start reported $verdict." >&2
      printf '  %s\n' "$newest" >&2
      return 1 ;;
  esac
}


# ---------------------------------------------------------------- hook OUTPUT SHAPES (#276)
#
# THE SHAPE IS PER EVENT, AND GETTING IT WRONG IS SILENT UNTIL A COMPACTION HAPPENS.
#
# This repository shipped two PreCompact hooks to every adopter that emitted
# `hookSpecificOutput.additionalContext` -- the way a hook speaks to the model. The harness
# accepts that key for SessionStart, UserPromptSubmit, PostToolUse/PostToolBatch and
# Stop/SubagentStop, and REJECTS it for PreCompact. The client printed
#
#     Hook JSON output validation failed — hookSpecificOutput.hookEventName: expected one of ...
#
# at the moment of compaction, and nothing else ever said a word. The checkpoint rule the
# scaffold is built around had never once reached a model, in any adopter, since it shipped.
#
# WHY THE COMMANDS ARE ACTUALLY RUN. A grep over the JSON would have caught this one and
# would miss the next: a hook whose shape depends on what the command does at runtime. So
# each command is EXECUTED, in an empty directory -- where the repo-scanning hooks find no
# tools/session_hook.sh and print nothing, which is itself a valid shape -- and its stdout is
# validated against the schema for the event it is registered under.
#
# EMPTY STDOUT IS VALID. Most hooks here are side-effect hooks and say nothing. What is not
# valid is JSON carrying a key the event cannot accept, or an hookEventName naming a
# different event than the one the hook is registered under.
ADDITIONAL_CONTEXT_EVENTS="UserPromptSubmit PostToolUse PostToolBatch Stop SubagentStop SessionStart"

check_output_shapes() {
  local f="${1:-.claude/settings.hooks.json}"
  [ -f "$f" ] || { echo "hook shapes: no $f — nothing to validate"; return 3; }
  ADDITIONAL_CONTEXT_EVENTS="$ADDITIONAL_CONTEXT_EVENTS" python3 - "$f" <<'PYEOF'
import json, os, subprocess, sys, tempfile

path = sys.argv[1]
allowed = set(os.environ["ADDITIONAL_CONTEXT_EVENTS"].split())
try:
    hooks = json.load(open(path)).get("hooks") or {}
except (OSError, ValueError) as exc:
    print(f"hook shapes: {path} does not parse — {exc}")
    sys.exit(1)

bad, ran = [], 0
# AN EMPTY DIRECTORY, ON PURPOSE. The repo-scanning hooks find no tools/session_hook.sh
# there and are no-ops, so this validates the OUTPUT SHAPE without writing a journal entry
# into whatever tree the selftest happened to be run from.
scratch = tempfile.mkdtemp(prefix="hook-shapes-")
for event, groups in hooks.items():
    for group in groups or []:
        for hook in (group or {}).get("hooks") or []:
            cmd = hook.get("command")
            if hook.get("type") != "command" or not cmd:
                continue
            ran += 1
            try:
                p = subprocess.run(["bash", "-c", cmd], cwd=scratch, capture_output=True,
                                   text=True, timeout=30, stdin=subprocess.DEVNULL)
            except (OSError, subprocess.SubprocessError) as exc:
                bad.append(f"{event}: command could not be run — {exc}")
                continue
            out = (p.stdout or "").strip()
            if not out:
                continue        # a side-effect hook that says nothing is valid
            try:
                doc = json.loads(out)
            except ValueError:
                # Plain text on stdout is valid for the user-facing channel; only JSON is
                # schema-checked, because only JSON is read as a directive.
                continue
            if not isinstance(doc, dict):
                continue
            hso = doc.get("hookSpecificOutput")
            if hso is None:
                continue
            named = (hso or {}).get("hookEventName")
            if named != event:
                bad.append(f"{event}: hookEventName says {named!r}, but the hook is "
                           f"registered under {event!r}")
            if "additionalContext" in (hso or {}) and event not in allowed:
                bad.append(f"{event}: emits hookSpecificOutput.additionalContext, which "
                           f"this event REJECTS. Valid for: {', '.join(sorted(allowed))}. "
                           f"The harness prints a validation error and the text never "
                           f"reaches a model.")

for line in bad:
    print(f"  FAIL {line}")
if bad:
    sys.exit(1)
print(f"  ok   {ran} hook command(s) produce a shape their own event accepts")
PYEOF
}

# ---------------------------------------------------------------- selftest
# THE CALLER PATH IS THE POINT. Running the journal directly is what the old cases did, and
# it is exactly what could not have caught this: the question is whether an invocation from
# the directory a person actually starts the client in reaches the repository and leaves a
# FRESH record. So every case below launches from a different place and asserts the journal
# moved.
selftest() {
  local d fails=0 out rc ROOT_TOOLS
  ROOT_TOOLS="$(dirname "$SELF")"
  # FIXTURES RUN INSIDE A GUARDED ROOT (tools/fixture_guard.sh). Later mktemps land inside it,
  # and a git on PATH refuses any write outside it. The guard exists because a failed mktemp
  # once let a selftest run git init and commit in the real repo.
  . "$(dirname "${BASH_SOURCE[0]}")/fixture_guard.sh" || { echo "session_hook: tools/fixture_guard.sh is missing; refusing to build fixtures" >&2; exit 1; }
  fixture_root FG_ROOT; trap fg_cleanup EXIT
  d="$(mktemp -d "${TMPDIR:-/tmp}/session-hook.XXXXXX")" || { echo "session_hook: mktemp failed; stopping" >&2; exit 1; }
  # The selftest brings its own template: an adopter's settings.hooks.json is not the tool.
  printf '%s\n' '{"hooks":{"SessionStart":[{"matcher":"compact","hooks":[{"type":"command","command":"echo COMPACTED fixture reminder"}]}]}}' \
    > "$d/template.json"
  export SCAFFOLD_HOOK_TEMPLATE="$d/template.json"
  # THE CASES BELOW ASSERT ON THE FULL RECORD, so they run verbose. The quiet cases near the
  # end clear it themselves.
  export SCAFFOLD_VERBOSE=1
  mkdir -p "$d/ws/proj/ai" "$d/ws/proj/tools" "$d/ws/proj/deep/nested"
  : > "$d/ws/proj/ai/STANDARDS.md"
  # A STUB JOURNAL that records the directory it was run from. If the wrapper cd-ed
  # somewhere unexpected, the evidence says so instead of the case passing anyway.
  printf '#!/usr/bin/env bash\nprintf "%%s %%s\\n" "$1" "$PWD" >> "$(dirname "$0")/../ai/SESSION_JOURNAL.md"\n' \
    > "$d/ws/proj/tools/session_journal.sh"
  chmod +x "$d/ws/proj/tools/session_journal.sh"
  git init -q "$d/ws/proj"
  git -C "$d/ws/proj" add -A
  git -C "$d/ws/proj" -c user.email=t@t -c user.name=t commit -qm init

  count() { [ -f "$d/ws/proj/ai/SESSION_JOURNAL.md" ] && wc -l < "$d/ws/proj/ai/SESSION_JOURNAL.md" | tr -d ' ' || echo 0; }

  # 1. FROM THE PARENT WORKSPACE — the case the old one-level scan was written for, and the
  #    one nobody proved.
  local before after
  before="$(count)"
  out="$( cd "$d/ws" && CLAUDE_PROJECT_DIR= SCAFFOLD_HOOK_ROOT= "$SELF" start 2>&1 )"
  after="$(count)"
  if [ "$after" -gt "$before" ]; then
    echo "  ok   launched from the PARENT workspace, the journal moved"
  else
    echo "  FAIL launched from the parent workspace and nothing was journalled"; fails=1
  fi
  case "$out" in
    *HOOK_RAN*) echo "  ok   and it said HOOK_RAN — the outcome is on the record, not inferred" ;;
    *) echo "  FAIL no HOOK_RAN was recorded: $out"; fails=1 ;;
  esac

  # 1b. A WIRING THAT LOOPS WITHOUT `break` FANS OUT ONCE, NOT ONCE PER COPY. Three sibling
  #     calls under one parent, as the workspace variant makes; the journal moves by one.
  #     A LOOP, like the wiring: bash 5 execs the last command of `a; b; c`, which moves
  #     that call's $PPID to the grandparent (Linux CI journalled twice; bash 3.2 never does).
  before="$(count)"
  out="$( cd "$d/ws" && CLAUDE_PROJECT_DIR= SCAFFOLD_HOOK_ROOT= S="$SELF" \
          bash -c 'for _ in 1 2 3; do "$S" start; done' 2>&1 )"
  after="$(count)"
  if [ "$((after - before))" -eq 1 ]; then
    echo "  ok   three sibling calls from a workspace journalled ONCE"
  else
    echo "  FAIL three sibling calls journalled $((after - before)) times: $out"; fails=1
  fi

  # 2. FROM A NESTED DIRECTORY — git discovery, not the scan.
  before="$(count)"
  out="$( cd "$d/ws/proj/deep/nested" && CLAUDE_PROJECT_DIR= SCAFFOLD_HOOK_ROOT= "$SELF" checkpoint 2>&1 )"
  after="$(count)"
  if [ "$after" -gt "$before" ]; then
    echo "  ok   launched from a NESTED directory, the journal moved"
  else
    echo "  FAIL a nested launch journalled nothing — cwd is still deciding"; fails=1
  fi

  # 3. FROM THE REPOSITORY ROOT.
  before="$(count)"
  out="$( cd "$d/ws/proj" && CLAUDE_PROJECT_DIR= SCAFFOLD_HOOK_ROOT= "$SELF" end 2>&1 )"
  after="$(count)"
  if [ "$after" -gt "$before" ]; then
    echo "  ok   launched from the repository ROOT, the journal moved"
  else
    echo "  FAIL a root launch journalled nothing"; fails=1
  fi

  # 4. THE THREE OUTCOMES ARE THREE DIFFERENT WORDS. This is the whole complaint: the old
  #    wiring returned the same silence for ran, absent and failed.
  chmod -x "$d/ws/proj/tools/session_journal.sh"
  out="$( cd "$d/ws/proj" && SCAFFOLD_HOOK_ROOT= "$SELF" start 2>&1 )"
  case "$out" in
    *HOOK_SKIPPED*) echo "  ok   a project with no runnable journal is SKIPPED, not silently fine" ;;
    *) echo "  FAIL an absent journal did not report HOOK_SKIPPED: $out"; fails=1 ;;
  esac
  printf '#!/usr/bin/env bash\nexit 4\n' > "$d/ws/proj/tools/session_journal.sh"
  chmod +x "$d/ws/proj/tools/session_journal.sh"
  out="$( cd "$d/ws/proj" && SCAFFOLD_HOOK_ROOT= "$SELF" start 2>&1 )"
  case "$out" in
    *HOOK_UNVERIFIED*) echo "  ok   a FAILING journal is UNVERIFIED, distinct from both" ;;
    *) echo "  FAIL a failing journal was not reported: $out"; fails=1 ;;
  esac

  # 5. AND THE CLIENT NEVER SEES A FAILURE, while --strict does. A hook that breaks the
  #    client is a hook the user disables, after which nothing is recorded at all.
  ( cd "$d/ws/proj" && SCAFFOLD_HOOK_ROOT= "$SELF" start >/dev/null 2>&1 ); rc=$?
  [ "$rc" -eq 0 ] && echo "  ok   the client-facing exit stays 0 even when the journal failed" \
                  || { echo "  FAIL the wrapper returned $rc to the client"; fails=1; }
  ( cd "$d/ws/proj" && SCAFFOLD_HOOK_ROOT= "$SELF" --strict start >/dev/null 2>&1 ); rc=$?
  [ "$rc" -eq 1 ] && echo "  ok   --strict returns the failure as an exit code" \
                  || { echo "  FAIL --strict returned $rc, so nothing can act on the outcome"; fails=1; }

  # 6. NOTHING RESOLVED IS EXIT 3 UNDER --strict — could not check, not a pass.
  mkdir -p "$d/empty"
  ( cd "$d/empty" && CLAUDE_PROJECT_DIR= SCAFFOLD_HOOK_ROOT= "$SELF" --strict start >/dev/null 2>&1 ); rc=$?
  [ "$rc" -eq 3 ] && echo "  ok   no scaffold root anywhere is exit 3, not a silent success" \
                  || { echo "  FAIL a directory with no project returned $rc"; fails=1; }

  # 7. THE EXPLICIT OVERRIDE WINS, so a test or an unusual client can say what it means.
  printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$1" >> "$(dirname "$0")/../ai/SESSION_JOURNAL.md"\n' \
    > "$d/ws/proj/tools/session_journal.sh"
  chmod +x "$d/ws/proj/tools/session_journal.sh"
  before="$(count)"
  out="$( cd "$d/empty" && SCAFFOLD_HOOK_ROOT="$d/ws/proj" "$SELF" start 2>&1 )"
  after="$(count)"
  if [ "$after" -gt "$before" ]; then
    echo "  ok   SCAFFOLD_HOOK_ROOT reaches a project from an unrelated directory"
  else
    echo "  FAIL the explicit override did not reach the project: $out"; fails=1
  fi

  # 8. EVERY SIBLING, NOT JUST THE FIRST. This is the case that catches the mistake made
  #    while wiring this: a settings entry that cd-s into the first project it finds makes
  #    git discovery resolve THAT project and never scan the rest, so three of four
  #    repositories in a workspace stop being journalled and nothing says so.
  local sib
  for sib in second third; do
    mkdir -p "$d/ws/$sib/ai" "$d/ws/$sib/tools"
    : > "$d/ws/$sib/ai/STANDARDS.md"
    printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$1" >> "$(dirname "$0")/../ai/SESSION_JOURNAL.md"\n' \
      > "$d/ws/$sib/tools/session_journal.sh"
    chmod +x "$d/ws/$sib/tools/session_journal.sh"
  done
  out="$( cd "$d/ws" && CLAUDE_PROJECT_DIR= SCAFFOLD_HOOK_ROOT= "$SELF" start 2>&1 )"
  local seen
  seen="$(printf '%s\n' "$out" | grep -c '^HOOK_RAN')"
  if [ "$seen" -ge 3 ]; then
    echo "  ok   a workspace launch reaches every sibling project ($seen), not just the first"
  else
    echo "  FAIL only $seen of 3 sibling projects were journalled from the workspace"; fails=1
  fi
  for sib in second third; do
    [ -f "$d/ws/$sib/ai/SESSION_JOURNAL.md" ] || { echo "  FAIL $sib was never journalled"; fails=1; }
  done

  # 9. THE WIRING CHECK, BOTH DIRECTIONS. A checker that only ever sees correct input has
  #    not been tested; and this one has to be able to say "already wired" without
  #    rewriting, or --wire is not safe to run twice.
  mkdir -p "$d/wire/.claude" "$d/wire/tools"
  cat > "$d/wire/.claude/settings.json" <<'STALE'
{"hooks":{"SessionStart":[{"hooks":[{"type":"command","command":"bash -c 'tools/session_journal.sh start' >/dev/null 2>&1"}]}]}}
STALE
  ( cd "$d/wire" && "$SELF" --check-wiring >/dev/null 2>&1 ); rc=$?
  [ "$rc" -eq 1 ] && echo "  ok   --check-wiring FAILS while the old literal is still in settings" \
                  || { echo "  FAIL stale wiring returned $rc"; fails=1; }
  ( cd "$d/wire" && "$SELF" --wire >/dev/null 2>&1 )
  ( cd "$d/wire" && "$SELF" --check-wiring >/dev/null 2>&1 ); rc=$?
  [ "$rc" -eq 0 ] && echo "  ok   --wire fixes it and --check-wiring then passes" \
                  || { echo "  FAIL still not wired after --wire (exit $rc)"; fails=1; }
  cp "$d/wire/.claude/settings.json" "$d/wire/once"
  ( cd "$d/wire" && "$SELF" --wire >/dev/null 2>&1 )
  if diff -q "$d/wire/once" "$d/wire/.claude/settings.json" >/dev/null; then
    echo "  ok   --wire is idempotent — running it twice changes nothing"
  else
    echo "  FAIL --wire rewrote an already-wired file"; fails=1
  fi

  #    THE POST-COMPACT REMINDER. A settings file with every lifecycle hook and no
  #    SessionStart:compact entry is exit 2 -- wired, but nothing restores the rules after
  #    compaction -- and --wire copies the template's text in. A stale copy is the same.
  ( cd "$d/wire" && "$SELF" --check-wiring >/dev/null 2>&1 ); rc=$?
  if [ "$rc" -eq 0 ] && grep -q 'COMPACTED' "$d/wire/.claude/settings.json"; then
    echo "  ok   --wire added the post-compact reminder from the template"
  else
    echo "  FAIL --wire left no post-compact reminder (check exit $rc)"; fails=1
  fi
  python3 - "$d/wire/.claude/settings.json" <<'NOCOMPACT'
import json, sys
p = sys.argv[1]; d = json.load(open(p))
d["hooks"]["SessionStart"] = [g for g in d["hooks"]["SessionStart"] if g.get("matcher") != "compact"]
json.dump(d, open(p, "w"))
NOCOMPACT
  ( cd "$d/wire" && "$SELF" --check-wiring >/dev/null 2>&1 ); rc=$?
  [ "$rc" -eq 2 ] && echo "  ok   no post-compact reminder is exit 2 — wired, rules not restored" \
                  || { echo "  FAIL a missing post-compact reminder returned $rc, want 2"; fails=1; }
  sed -i.bak 's/COMPACTED/COMPACTED (an old copy)/' "$d/wire/once"
  cp "$d/wire/once" "$d/wire/.claude/settings.json"
  ( cd "$d/wire" && "$SELF" --check-wiring >/dev/null 2>&1 ); rc=$?
  [ "$rc" -eq 2 ] && echo "  ok   a STALE reminder text is exit 2 as well" \
                  || { echo "  FAIL a stale reminder returned $rc, want 2"; fails=1; }
  ( cd "$d/wire" && "$SELF" --wire >/dev/null 2>&1; "$SELF" --check-wiring >/dev/null 2>&1 ); rc=$?
  [ "$rc" -eq 0 ] && echo "  ok   ...and --wire replaces it with the template's" \
                  || { echo "  FAIL still $rc after --wire on a stale reminder"; fails=1; }

  #    THE WRAPPER'S NAME WAS TREATED AS PROOF, SO #277 REACHED ALMOST NOBODY.
  #    A command that CALLS the wrapper but keeps the pre-#277 blanket `>/dev/null 2>&1`
  #    used to satisfy both tools: --check-wiring returned 0 on the strength of the
  #    filename, and --wire only ever rewrote the OLDER session_journal.sh form, so it
  #    printed "nothing to rewire" and left the redirect alone. Any repo wired before #277
  #    -- this project's own among them -- therefore kept sending the journal's one
  #    instruction to /dev/null forever, with no way to learn that from either tool.
  #    The per-event policy is the assertion: start and checkpoint SPEAK, end stays SILENT,
  #    so a case that only checked "is there a redirect" would pass the wrong fix too.
  mkdir -p "$d/drift/.claude"
  cat > "$d/drift/.claude/settings.json" <<'DRIFT'
{"hooks":{
 "SessionStart":[{"hooks":[{"type":"command","command":"bash -c 'for d in . */; do [ -x \"$d/tools/session_hook.sh\" ] || continue; \"$d/tools/session_hook.sh\" start; break; done' >/dev/null 2>&1"}]}],
 "SessionEnd":[{"hooks":[{"type":"command","command":"bash -c 'for d in . */; do [ -x \"$d/tools/session_hook.sh\" ] || continue; \"$d/tools/session_hook.sh\" end; break; done' >/dev/null 2>&1"}]}]}}
DRIFT
  ( cd "$d/drift" && "$SELF" --check-wiring >/dev/null 2>&1 ); rc=$?
  [ "$rc" -eq 1 ] && echo "  ok   --check-wiring FAILS on a wrapper call with the wrong redirect" \
                  || { echo "  FAIL redirect drift returned $rc, want 1 — the name was taken as proof"; fails=1; }
  ( cd "$d/drift" && "$SELF" --wire >/dev/null 2>&1 )
  if grep -q "start; break; done' 2>/dev/null" "$d/drift/.claude/settings.json"; then
    echo "  ok   --wire restores SessionStart's stdout, which the client reads"
  else
    echo "  FAIL --wire left SessionStart silenced"; fails=1
  fi
  if grep -q "end; break; done' >/dev/null 2>&1" "$d/drift/.claude/settings.json"; then
    echo "  ok   ...and left SessionEnd silent, because nothing reads it"
  else
    echo "  FAIL --wire made SessionEnd speak, which the policy says it must not"; fails=1
  fi
  ( cd "$d/drift" && "$SELF" --check-wiring >/dev/null 2>&1 ); rc=$?
  [ "$rc" -eq 0 ] && echo "  ok   and the check passes once the redirects match the policy" \
                  || { echo "  FAIL still $rc after --wire"; fails=1; }

  #    A REPAIR MUST NOT EAT A CUSTOMISATION, and the first version of this fix did.
  #    It compared the whole command to WRAP_FOR() and called anything else drift. The
  #    machine this was developed on runs a hand-edited wrapper that skips `*-backup/`
  #    directories and drops the `break` so every adopted repo is reached, not just the
  #    first -- both deliberate. Whole-string comparison flagged them and --wire would have
  #    silently overwritten them, turning a diagnostic into data loss. Only the trailing
  #    redirect is the scaffold's business; the body belongs to whoever wrote it.
  mkdir -p "$d/custom/.claude"
  cat > "$d/custom/.claude/settings.json" <<'CUSTOM'
{"hooks":{"SessionStart":[{"hooks":[{"type":"command","command":"bash -c 'for d in . */; do case \"$d\" in *-backup/) continue ;; esac; [ -x \"$d/tools/session_hook.sh\" ] || continue; \"$d/tools/session_hook.sh\" start; done' >/dev/null 2>&1"}]}]}}
CUSTOM
  ( cd "$d/custom" && "$SELF" --wire >/dev/null 2>&1 )
  custom_cmd="$(python3 -c 'import json;print(json.load(open("'"$d"'/custom/.claude/settings.json"))["hooks"]["SessionStart"][0]["hooks"][0]["command"])')"
  case "$custom_cmd" in
    *'*-backup/'*) echo "  ok   --wire preserved the hand-written backup-skip guard" ;;
    *) echo "  FAIL --wire ate the customisation: $custom_cmd"; fails=1 ;;
  esac
  if printf '%s' "$custom_cmd" | grep -q '2>/dev/null$' \
     && ! printf '%s' "$custom_cmd" | grep -q '>/dev/null 2>&1'; then
    echo "  ok   ...and fixed only the redirect, leaving the missing break alone"
  else
    echo "  FAIL the redirect was not corrected: $custom_cmd"; fails=1
  fi

  printf 'not json at all\n' > "$d/wire/.claude/settings.json"
  ( cd "$d/wire" && "$SELF" --wire >/dev/null 2>&1 ); rc=$?
  if [ "$rc" -eq 3 ] && grep -q 'not json at all' "$d/wire/.claude/settings.json"; then
    echo "  ok   unparseable settings are exit 3 and left untouched, never rewritten"
  else
    echo "  FAIL a file it could not parse returned $rc and may have been overwritten"; fails=1
  fi

  # 9b. THE COMMAND TEXT CAN BE RIGHT AND THE FILE IT RUNS WRONG. A first-match launcher
  #     runs whichever copy sorts first; a backup folder that sorts ahead of the live repo
  #     silently runs an old guard. Exit 2 naming the stale copy, and 0 once it is skipped.
  mkdir -p "$d/shadow/.claude" "$d/shadow/a-old/tools" "$d/shadow/b-new/tools"
  printf '#!/usr/bin/env python3\n# Version:  0.1.0.20260101.0000\n' > "$d/shadow/a-old/tools/g.py"
  printf '#!/usr/bin/env python3\n# Version:  0.2.0.20260201.0000\n' > "$d/shadow/b-new/tools/g.py"
  chmod +x "$d/shadow/a-old/tools/g.py" "$d/shadow/b-new/tools/g.py"
  printf '%s\n' '{"hooks":{"SessionEnd":[{"hooks":[{"type":"command","command":"bash -c '"'"'r=\"${CLAUDE_PROJECT_DIR:-.}\"; if [ -f \"$r/ai/STANDARDS.md\" ]; then set -- \"$r\"; else set -- . */; fi; for d in \"$@\"; do [ -x \"$d/tools/session_hook.sh\" ] || continue; \"$d/tools/session_hook.sh\" end; break; done'"'"' >/dev/null 2>&1"}]}],"PreToolUse":[{"matcher":"Bash","hooks":[{"type":"command","command":"bash -c '"'"'r=\"${CLAUDE_PROJECT_DIR:-.}\"; if [ -f \"$r/ai/STANDARDS.md\" ]; then set -- \"$r\"; else set -- . */; fi; for d in \"$@\"; do [ -x \"$d/tools/g.py\" ] && exec python3 \"$d/tools/g.py\"; done; exit 0'"'"'"}]}]}}' \
    > "$d/shadow/.claude/settings.json"
  _so="$(cd "$d/shadow" && "$SELF" --check-wiring 2>&1)"; rc=$?
  case "$rc:$_so" in
    2:*"runs a-old/tools/g.py"*) echo "  ok   a launcher resolving to an older copy is exit 2, naming the copy" ;;
    *) echo "  FAIL a shadowed launcher returned $rc: $_so"; fails=1 ;;
  esac
  chmod -x "$d/shadow/a-old/tools/g.py"
  ( cd "$d/shadow" && "$SELF" --check-wiring >/dev/null 2>&1 ); rc=$?
  [ "$rc" -eq 0 ] && echo "  ok   ...and chmod -x on the stale copy clears it" \
                  || { echo "  FAIL still exit 2 after the stale copy was made non-executable"; fails=1; }

  # 9c. THE SCAN IS FOR A WORKSPACE, NOT FOR EVERY SESSION (report item 14). `for d in . */`
  #     ran sync-check.sh out of every child directory, so a repository cloned under an
  #     adopter ran code at session start with no trust prompt of its own. --check-wiring
  #     names it (exit 2: the hooks still fire), --wire swaps the loop head, and the
  #     rewritten command is then RUN, because a head that reads right and scans wrong is
  #     the defect this case exists for.
  mkdir -p "$d/scan/proj/.claude" "$d/scan/proj/ai" "$d/scan/proj/kid/ai" \
           "$d/scan/ws/a/ai" "$d/scan/ws/b/ai"
  for _p in proj proj/kid ws/a ws/b; do
    : > "$d/scan/$_p/ai/STANDARDS.md"
    printf 'echo RAN:%s\n' "$_p" > "$d/scan/$_p/sync-check.sh"
  done
  printf '%s\n' '{"hooks":{"SessionStart":[{"hooks":[{"type":"command","command":"bash -c '"'"'for d in . */; do case \"$d\" in *-backup/) continue ;; esac; [ -f \"$d/ai/STANDARDS.md\" ] || continue; [ -f \"$d/sync-check.sh\" ] && ( cd \"$d\" && bash sync-check.sh ); done; true'"'"'"}]}],"SessionEnd":[{"hooks":[{"type":"command","command":"bash -c '"'"'r=\"${CLAUDE_PROJECT_DIR:-.}\"; if [ -f \"$r/ai/STANDARDS.md\" ]; then set -- \"$r\"; else set -- . */; fi; for d in \"$@\"; do [ -x \"$d/tools/session_hook.sh\" ] || continue; \"$d/tools/session_hook.sh\" end; break; done'"'"' >/dev/null 2>&1"}]}]}}' \
    > "$d/scan/proj/.claude/settings.json"
  _so="$(cd "$d/scan/proj" && "$SELF" --check-wiring 2>&1)"; rc=$?
  case "$rc:$_so" in
    2:*"sync-check.sh in every child directory"*) echo "  ok   an unscoped scan is exit 2, naming the script it would run" ;;
    *) echo "  FAIL an unscoped scan returned $rc: $_so"; fails=1 ;;
  esac
  ( cd "$d/scan/proj" && "$SELF" --wire >/dev/null 2>&1 )
  _sc="$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["hooks"]["SessionStart"][0]["hooks"][0]["command"])' "$d/scan/proj/.claude/settings.json")"
  case "$_sc" in
    *'CLAUDE_PROJECT_DIR'*'*-backup/'*) echo "  ok   --wire rewrote the loop head and kept the hand-written body" ;;
    *) echo "  FAIL --wire did not scope the scan, or ate the body: $_sc"; fails=1 ;;
  esac
  _r1="$(cd "$d/scan/proj" && CLAUDE_PROJECT_DIR="$d/scan/proj" bash -c "$_sc" 2>&1)"
  case "$_r1" in
    *RAN:proj*RAN:proj/kid*|*RAN:proj/kid*) echo "  FAIL a project session still ran the child repository: $_r1"; fails=1 ;;
    *RAN:proj*) echo "  ok   a session in a project runs only that project" ;;
    *) echo "  FAIL a project session ran nothing: $_r1"; fails=1 ;;
  esac
  _r2="$(cd "$d/scan/ws" && CLAUDE_PROJECT_DIR="$d/scan/ws" bash -c "$_sc" 2>&1)"
  case "$_r2" in
    *RAN:ws/a*RAN:ws/b*) echo "  ok   ...and a workspace that is not a project still reaches every repo in it" ;;
    *) echo "  FAIL the workspace scan was lost: $_r2"; fails=1 ;;
  esac
  ( cd "$d/scan/proj" && "$SELF" --check-wiring >/dev/null 2>&1 ); rc=$?
  [ "$rc" -ne 2 ] || { echo "  FAIL still exit 2 after --wire scoped the scan"; fails=1; }

  # 10. THE CLOSEOUT. Four cases, and the third is the one that matters: a log containing
  #     an old success and a recent failure must FAIL. "Is there a HOOK_RAN anywhere" is
  #     true forever after the first one, so it would pass every session after a hook broke
  #     — which is precisely the failure this command exists to catch.
  mkdir -p "$d/co/ai" "$d/co/tools"
  : > "$d/co/ai/STANDARDS.md"
  ( cd "$d/co" && "$SELF" --closeout >/dev/null 2>&1 ); rc=$?
  [ "$rc" -eq 1 ] && echo "  ok   --closeout FAILS when nothing was ever recorded" \
                  || { echo "  FAIL an empty project closed out with $rc"; fails=1; }

  # 10b. THE EMPTY-LOG BRANCH MUST ANSWER, NOT OFFER A COIN FLIP (#262). A log file that
  #      exists with no `start` record is the "never fired" case, and it used to print
  #      "either the hook is not wired, or it has never fired" -- while preflight pointed
  #      readers here FOR that answer. Two cases, because a fix that always says one of them
  #      is no better than the either/or it replaced.
  : > "$d/co/ai/.scaffold-run-log"
  out="$( cd "$d/co" && "$SELF" --closeout 2>&1 )"
  case "$out" in
    *"is NOT wired"*) echo "  ok   --closeout resolves an empty log to NOT WIRED when it is not" ;;
    *"Either the hook"*) echo "  FAIL --closeout still reports the either/or (#262)"; fails=1 ;;
    *) echo "  FAIL --closeout said neither: $out"; fails=1 ;;
  esac
  # ...and with the hook actually wired, the SAME empty log must resolve the other way.
  mkdir -p "$d/co/.claude"
  printf '{"hooks":{"SessionStart":[{"hooks":[{"type":"command","command":"tools/session_hook.sh"}]}]}}\n' \
    > "$d/co/.claude/settings.json"
  out="$( cd "$d/co" && "$SELF" --closeout 2>&1 )"
  case "$out" in
    *"IS wired correctly, and has never fired"*) echo "  ok   --closeout resolves the same empty log to WIRED, NEVER FIRED" ;;
    *"is NOT wired"*) echo "  FAIL --closeout answers NOT WIRED regardless of the wiring — the answer is a constant"; fails=1 ;;
    *) echo "  FAIL --closeout gave no wiring verdict on a wired repo: $out"; fails=1 ;;
  esac
  rm -rf "$d/co/.claude"

  # 10c. --ever-fired: THREE ANSWERS, AND THE MIDDLE ONE IS THE POINT (#264). A fresh
  #      adoption with no start yet must NOT be a failure -- reddening there is the hazard
  #      0.58.0 shipped -- while a log other tools have been writing to for 50+ rows with no
  #      start at all is a hook nobody is calling. A fix returning 1 whenever starts==0 would
  #      pass the third case and break every new adoption.
  : > "$d/co/ai/.scaffold-run-log"
  ( cd "$d/co" && "$SELF" --ever-fired >/dev/null 2>&1 ); rc=$?
  [ "$rc" -eq 3 ] && echo "  ok   --ever-fired on a near-empty log is 'too early', not a failure" \
                  || { echo "  FAIL an almost-empty log returned $rc, want 3"; fails=1; }

  i=0; while [ "$i" -lt 60 ]; do
    # Spread across days — see the note on the --wire fixture below. An identical timestamp
    # on every row is a burst, which is now correctly 'too early to tell', not 'never fired'.
    printf '2026-08-%02dT0%d:00:00Z\tpreflight:something\tok\t\n' \
      "$(( 18 + i / 24 ))" "$(( i % 8 ))" >> "$d/co/ai/.scaffold-run-log"
    i=$((i + 1))
  done
  ( cd "$d/co" && "$SELF" --ever-fired >/dev/null 2>&1 ); rc=$?
  [ "$rc" -eq 1 ] && echo "  ok   --ever-fired FAILS on a worked-in log with zero starts" \
                  || { echo "  FAIL 60 rows and no start returned $rc, want 1"; fails=1; }

  # AND THE CASE THAT COST A REAL ADOPTER A RED GATE ON DAY ONE. Same row count, one
  # burst instead of a history: this must be 'too early to tell', not 'never fired'.
  # Measured 2026-09-08 on a real fresh adoption: 101 rows in five minutes, written by
  # setup.sh and preflight themselves, and the adopter was failed on a hook they had
  # never touched. The 50-row threshold was documented as chosen so this could not
  # happen; it was never tested against an actual adoption.
  mkdir -p "$d/burst/ai" "$d/burst/tools"; : > "$d/burst/ai/STANDARDS.md"
  printf '0.1.0\n' > "$d/burst/version"; : > "$d/burst/.scaffold-version"
  i=0; while [ "$i" -lt 101 ]; do
    printf '2026-09-08T07:5%d:00Z\tsetup.sh\tok\t\n' "$(( i % 5 ))" >> "$d/burst/ai/.scaffold-run-log"
    i=$((i + 1))
  done
  ( cd "$d/burst" && "$SELF" --ever-fired >/dev/null 2>&1 ); rc=$?
  [ "$rc" -eq 3 ] && echo "  ok   a setup BURST is too-early-to-tell, not NEVER FIRED" \
                  || { echo "  FAIL 101 rows in 5 minutes returned $rc, want 3"; fails=1; }

  # A REWIRE ON A BUSY LOG IS 'TOO EARLY', NOT 'NEVER FIRED' (#285). Reported from
  # Robiton/product-tracker: preflight's own remedy took them from PASSED to FAILED. Every
  # start before a rewire is logged under the old literal, so a 2,656-row repo has zero and
  # clears the busy bar instantly. Asserted BEFORE the start below, on the same 60-row log
  # that returns 1 above -- the only difference between the two cases is the wire event.
  printf '2026-08-18T10:30:00Z\tsession_hook:wired\tok\trewired\n' >> "$d/co/ai/.scaffold-run-log"
  ( cd "$d/co" && "$SELF" --ever-fired >/dev/null 2>&1 ); rc=$?
  [ "$rc" -eq 3 ] && echo "  ok   a rewire with no start since is 'too early', not NEVER FIRED" \
                  || { echo "  FAIL a busy log after a rewire returned $rc, want 3"; fails=1; }

  printf '2026-08-18T10:00:00Z\tsession_hook:start\tHOOK_RAN\tsession=x\n' >> "$d/co/ai/.scaffold-run-log"
  ( cd "$d/co" && "$SELF" --ever-fired >/dev/null 2>&1 ); rc=$?
  [ "$rc" -eq 0 ] && echo "  ok   --ever-fired passes once a single start exists" \
                  || { echo "  FAIL a log with one start returned $rc, want 0"; fails=1; }

  printf '2026-08-18T10:00:00Z\tsession_hook:start\tHOOK_RAN\tsession=abc ran\n' \
    > "$d/co/ai/.scaffold-run-log"
  ( cd "$d/co" && "$SELF" --closeout >/dev/null 2>&1 ); rc=$?
  [ "$rc" -eq 0 ] && echo "  ok   --closeout passes on a recorded HOOK_RAN" \
                  || { echo "  FAIL a good record closed out with $rc"; fails=1; }

  printf '2026-08-18T11:00:00Z\tsession_hook:start\tHOOK_UNVERIFIED\tsession=def broke\n' \
    >> "$d/co/ai/.scaffold-run-log"
  ( cd "$d/co" && "$SELF" --closeout >/dev/null 2>&1 ); rc=$?
  [ "$rc" -eq 1 ] && echo "  ok   an older success does not launder a newer failure" \
                  || { echo "  FAIL a broken hook closed out clean because it once worked"; fails=1; }

  printf '<!-- scaffold:hooks-unavailable this client has no lifecycle hooks -->\n' \
    > "$d/co/AGENTS.md"
  out="$( cd "$d/co" && "$SELF" --closeout 2>&1 )"; rc=$?
  if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q 'no lifecycle hooks'; then
    echo "  ok   a DECLARED unavailability passes, and the reason is printed every time"
  else
    echo "  FAIL the declaration was not honoured or not shown (exit $rc)"; fails=1
  fi

  # 11. THE SESSION IDENTITY REACHES THE DURABLE RECORD. It was in the printed line and
  #     not in the log for one revision — and the printed line is thrown away with the
  #     console, while the log is the only thing --closeout can read.
  mkdir -p "$d/sid/ai" "$d/sid/tools"
  : > "$d/sid/ai/STANDARDS.md"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$d/sid/tools/session_journal.sh"
  chmod +x "$d/sid/tools/session_journal.sh"
  cp "$(dirname "$SELF")/scaffold_log.sh" "$d/sid/tools/" 2>/dev/null
  chmod +x "$d/sid/tools/scaffold_log.sh" 2>/dev/null
  ( cd "$d/sid" && printf '{"session_id":"sid-from-stdin"}' | "$SELF" start >/dev/null 2>&1 )
  if grep -q 'session=sid-from-stdin' "$d/sid/ai/.scaffold-run-log" 2>/dev/null; then
    echo "  ok   the session id is parsed from the client payload and lands in the log"
  else
    echo "  FAIL the session id never reached the record --closeout reads"; fails=1
  fi
  ( cd "$d/sid" && SCAFFOLD_HOOK_SESSION=explicit-wins "$SELF" start >/dev/null 2>&1 )
  if tail -1 "$d/sid/ai/.scaffold-run-log" 2>/dev/null | grep -q 'session=explicit-wins'; then
    echo "  ok   an explicit SCAFFOLD_HOOK_SESSION outranks the payload"
  else
    echo "  FAIL the explicit session override was ignored"; fails=1
  fi

  # BOTH FIELDS OFF ONE STDIN READ. One field alone passes even when the payload cache dies
  # in a command-substitution fork, which is exactly what happened here.
  out2="$(printf '{"session_id":"s2","transcript_path":"/tmp/x.jsonl"}' \
         | "$SELF" --dump-payload 2>&1)"
  case "$out2" in
    *"session=s2"*"transcript=/tmp/x.jsonl"*)
      echo "  ok   session_id AND transcript_path both survive one stdin read" ;;
    *)
      echo "  FAIL transcript_path was empty: $out2"; fails=1 ;;
  esac

  # --wire LEAVES THE REPO PROVEN, NOT MERELY REWIRED (#285). The whole report was that the
  # remedy preflight prints made the gate red; the fix is that running it now makes the gate
  # green, so that is what is asserted -- end to end, through the same command an adopter runs.
  mkdir -p "$d/wire/tools" "$d/wire/ai" "$d/wire/.claude"
  : > "$d/wire/ai/STANDARDS.md"
  cp "$ROOT_TOOLS/session_journal.sh" "$ROOT_TOOLS/scaffold_log.sh" "$d/wire/tools/" 2>/dev/null || true
  chmod +x "$d/wire/tools/"* 2>/dev/null || true
  printf '{"hooks":{"SessionStart":[{"hooks":[{"type":"command","command":"bash -c '"'"'tools/session_journal.sh start'"'"' >/dev/null 2>&1"}]}]}}\n' \
    > "$d/wire/.claude/settings.json"
  i=0; while [ "$i" -lt 60 ]; do
    # SPREAD ACROSS DAYS, not one instant. 60 rows at an identical timestamp described a
    # repo that cannot exist, and once the escalation required SPAN as well as volume the
    # fixture stopped representing the thing it is named for. A worked-in repo has rows
    # across sessions; that is the property, and the fixture has to carry it.
    printf '2026-09-%02dT0%d:00:00Z\tother_tool\tok\trow\n' \
      "$(( 1 + i / 24 ))" "$(( i % 8 ))" >> "$d/wire/ai/.scaffold-run-log"
    i=$((i + 1))
  done
  git init -q "$d/wire" 2>/dev/null
  ( cd "$d/wire" && "$SELF" --ever-fired >/dev/null 2>&1 ); rc=$?
  [ "$rc" -eq 1 ] && echo "  ok   the adopter's starting state reproduces (NEVER FIRED)" \
                  || { echo "  FAIL could not reproduce the reported state, got $rc"; fails=1; }
  ( cd "$d/wire" && "$SELF" --wire >/dev/null 2>&1 )
  ( cd "$d/wire" && "$SELF" --ever-fired >/dev/null 2>&1 ); rc=$?
  [ "$rc" -eq 0 ] && echo "  ok   ...and --wire leaves it PROVEN, not red (#285)" \
                  || { echo "  FAIL the remedy left the gate at $rc, want 0"; fails=1; }

  # A LINKED WORKTREE IS TOO EARLY TO TELL, NOT NEVER FIRED (#368). The main checkout has
  # starts; a worktree of it, nested one level as in a monorepo, has 60 tool rows across days
  # and none. Asserted against the named state, and the main checkout's count must be quoted.
  mkdir -p "$d/wtm/app/ai"
  : > "$d/wtm/app/ai/STANDARDS.md"
  ( cd "$d/wtm" && git init -q . && git config user.email a@b.c && git config user.name t \
      && git add -A && git commit -qm init && git worktree add -q "$d/wtl" ) >/dev/null 2>&1
  printf '2026-09-01T00:00:00Z\tsession_hook:start\tHOOK_RAN\tsession=m\n' > "$d/wtm/app/ai/.scaffold-run-log"
  i=0; while [ "$i" -lt 60 ]; do
    printf '2026-09-%02dT0%d:00:00Z\tother_tool\tok\trow\n' \
      "$(( 1 + i / 24 ))" "$(( i % 8 ))" >> "$d/wtl/app/ai/.scaffold-run-log"
    i=$((i + 1))
  done
  out="$( cd "$d/wtl/app" && env -u CLAUDE_PROJECT_DIR -u SCAFFOLD_HOOK_ROOT "$SELF" --ever-fired 2>&1 )"; rc=$?
  case "$rc:$out" in
    3:*"LINKED WORKTREE"*"records 1 start(s)"*)
      echo "  ok   a linked worktree with no starts is too early to tell, not NEVER FIRED (#368)" ;;
    *) echo "  FAIL linked worktree: want 3 naming the main checkout's 1 start, got $rc: $out"; fails=1 ;;
  esac
  # ...and the main checkout itself is not exempted by that branch.
  : > "$d/wtm/app/ai/.scaffold-run-log"
  cp "$d/wtl/app/ai/.scaffold-run-log" "$d/wtm/app/ai/.scaffold-run-log"
  ( cd "$d/wtm/app" && env -u CLAUDE_PROJECT_DIR -u SCAFFOLD_HOOK_ROOT "$SELF" --ever-fired >/dev/null 2>&1 ); rc=$?
  [ "$rc" -eq 1 ] && echo "  ok   ...while the main checkout with the same log is still NEVER FIRED" \
                  || { echo "  FAIL the worktree branch exempted the main checkout too, got $rc"; fails=1; }

  # THE OUTPUT SHAPE OF EVERY REGISTERED HOOK (#276). Run from the repository root, not
  # from $d — the file being validated is this repository's canonical hook set.
  local shape_out shape_rc
  local _selfroot; _selfroot="$(dirname "$(dirname "$SELF")")"
  shape_out="$( cd "$_selfroot" && check_output_shapes .claude/settings.hooks.json 2>&1 )"; shape_rc=$?
  printf '%s\n' "$shape_out"
  if [ "$shape_rc" -eq 1 ]; then
    fails=1
  fi

  # QUIET BY DEFAULT (CONTROL, 2026-09-23). The filter hides what passed and nothing else.
  # Each case feeds it the exact shapes the SessionStart hook prints.
  qf() { printf '%b' "$1" | SCAFFOLD_VERBOSE= "$SELF" --quiet-filter ${2:+"$2"} 2>&1; }
  qcase() {  # qcase <label> <input> <want present, |-separated> <want absent, |-separated>
    local o w bad=""
    o="$(qf "$2" "${5:-}")"
    local IFS='|'
    for w in $3; do [ -z "$w" ] || printf '%s' "$o" | grep -qF -- "$w" || bad="$bad missing[$w]"; done
    for w in $4; do [ -z "$w" ] || ! printf '%s' "$o" | grep -qF -- "$w" || bad="$bad present[$w]"; done
    if [ -z "$bad" ]; then echo "  ok   quiet: $1"; else echo "  FAIL quiet: $1 --$bad :: $(printf '%s' "$o" | tr '\n' '~')"; fails=1; fi
  }
  qcase "a one-line [OK] is hidden and counted" \
        '[OK] scaffold 1.0 is current\n[OK] runners online\n' \
        '2 passing check(s) not shown' '[OK] scaffold'
  qcase "an [OK] carrying a caveat is a NOT-verified, and prints whole" \
        '[OK] CI green; but only 1 of 3 alert\n     features are enabled\n' \
        '[OK] CI green|features are enabled' 'not shown'
  qcase "progress lines go, and are not counted as checks" \
        '[..] Fetching latest from origin...\n[!]  scaffold is BEHIND\n' \
        '[!]  scaffold is BEHIND' '[..] Fetching|not shown'
  qcase "a lone HOOK_RAN is hidden; UNVERIFIED and SKIPPED print" \
        'HOOK_RAN repo=a event=start\nHOOK_UNVERIFIED repo=b event=start\nHOOK_SKIPPED repo=c event=start\n' \
        'HOOK_UNVERIFIED repo=b|HOOK_SKIPPED repo=c|1 passing check(s) not shown' 'HOOK_RAN repo=a'
  qcase "a HOOK_RAN with journal detail keeps its line, which names the repo" \
        'HOOK_RAN repo=a event=start\n[journal] 5 un-distilled entries\nHOOK_RAN repo=b event=start\n' \
        'HOOK_RAN repo=a|[journal] 5 un-distilled|1 passing check(s) not shown' 'HOOK_RAN repo=b'
  qcase "the count names its source when given one" \
        '[OK] x\n' '(proj: 1 passing check(s) not shown' '' proj
  qcase "nothing hidden, no count line" \
        '[FAIL] something\n' '[FAIL] something' 'not shown'
  # END TO END: a real start, quiet. The printed HOOK_RAN goes; the RECORD does not.
  out="$( cd "$d/ws/proj" && SCAFFOLD_VERBOSE= SCAFFOLD_HOOK_ROOT= "$SELF" start 2>&1 )"
  case "$out" in
    *HOOK_RAN*) echo "  FAIL quiet: a plain start still printed HOOK_RAN: $out"; fails=1 ;;
    *"passing check(s) not shown"*) echo "  ok   quiet: a plain start prints the count, not the HOOK_RAN line" ;;
    *) echo "  FAIL quiet: a plain start printed neither HOOK_RAN nor a count: $out"; fails=1 ;;
  esac
  unset -f qf qcase

  rm -rf "$d"
  [ "$fails" -eq 0 ] && { echo "session_hook: selftest passed"; return 0; }
  echo "session_hook: selftest FAILED" >&2; return 1
}

case "$MODE" in
  usage)
    echo "usage: session_hook.sh <start|checkpoint|end|precompact> [--strict]"
    echo "       session_hook.sh --report | --closeout | --ever-fired | --check-wiring | --wire | --selftest"
    echo "       session_hook.sh --check-output-shapes   # run every registered hook, validate its stdout"
    echo "       session_hook.sh --quiet-filter [label]  # stdin to stdout, passes hidden and counted"
    echo "       add --verbose (or SCAFFOLD_VERBOSE=1) to any hook event to print every line"
    ;;
  selftest) selftest ;;
  check_output_shapes) check_output_shapes "${SHAPES_FILE:-.claude/settings.hooks.json}" ;;
  dump_payload) dump_payload ;;
  quiet_filter) quiet_filter "$EVENT" ;;
  wire)
    # ---- --wire FIRES THE HOOK ONCE, BECAUSE IT JUST CREATED THE CONDITION (#285) --------
    #
    # Reported from Robiton/product-tracker: preflight printed a GAP whose stated remedy is
    # `--wire`, the adopter ran exactly that, --check-wiring confirmed it worked, and the next
    # preflight went from PASSED to `[FAIL] session hooks are wired and have NEVER fired`.
    # The tool recommended an action, they took it, and it broke the gate.
    #
    # THE CAUSE IS STRUCTURAL AND BENIGN. --ever-fired counts `session_hook:start` rows, and
    # before the rewire there are necessarily ZERO -- every prior start was logged under the
    # old literal. Their repo had 2,656 rows, so it cleared the "not a young repo" bar
    # instantly and returned 1 rather than 3. The message offered two explanations and
    # NEITHER WAS THE ACTUAL ONE, so both sent them hunting a misconfiguration that was not
    # there.
    #
    # Their own fix is the right one and is what runs here: fire the wrapper once. That writes
    # a real HOOK_RAN row and PROVES THE WRAPPER RUNS, which is the check's whole purpose --
    # satisfied properly rather than suppressed. Strictly better than declaring
    # hooks-unavailable, which is what the old message pointed at.
    wire_json write || exit $?
    # RECORD THE REWIRE, so --ever-fired can tell "no start since the wiring changed" from
    # "never fired". Written before the start below, so the ordering the backstop reads is
    # the real one even if the start fails.
    _wire_root="$(discover_roots | head -1)"
    if [ -n "$_wire_root" ] && [ -x "$_wire_root/tools/scaffold_log.sh" ]; then
      ( cd "$_wire_root" && tools/scaffold_log.sh --log "session_hook:wired" ok \
          "hook commands rewired to tools/session_hook.sh" ) >/dev/null 2>&1
    fi
    unset _wire_root
    if [ -x "$SELF" ]; then
      echo "  firing the wrapper once, so the rewire is proven rather than assumed:"
      SCAFFOLD_VERBOSE=1 "$SELF" start 2>/dev/null | sed 's/^/    /'
    fi
    ;;
  check_wiring)  wire_json check ;;
  closeout)      closeout ;;
  ever_fired)    ever_fired ;;
  report)   report ;;
  # pipefail is set, so --strict's exit code survives the filter.
  hook)     if [ -n "${SCAFFOLD_VERBOSE:-}" ]; then run_hook; else run_hook | quiet_filter; fi ;;
esac
