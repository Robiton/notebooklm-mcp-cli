#!/usr/bin/env python3
# Project:  ai-project-scaffold
# File:     tools/session_archive.py
# Modified: 2026-10-06
# Version:  0.20.4.20261006.0503
# Purpose:  Enforce the scaffold's own archiving ceilings instead of trusting anyone to remember.
# Changelog:
#   2026-10-06 v0.20.4.20261006.0503 — --exit-status NOW WORKS ON THE DEFAULT PATH.
#                        main()'s single-file path returned 0 whether SESSION.md was over or
#                        past burst; only --all honoured the 0/1/2 contract. Both returns now
#                        give 1 over / 2 past burst under --exit-status; plain --check stays
#                        advisory 0. Four subprocess selftest cases, proven red at 81/83.
#   2026-09-22 v0.20.3.20260922.0354 — #318 WHAT COUNTS AS AN ENTRY IS NOW AN ALLOWLIST.
#                        TEMPLATE_RE was a denylist, written because template blocks once took
#                        3 of 5 retention slots and rotated four REAL sessions out. It held
#                        until somebody wrote a heading it had not seen: on 2026-09-22 a
#                        STANDING POINTER in localcoder-dev ("the live table is NOT here", the
#                        paragraph replacing the scaffold:closeouts markers) was counted as a
#                        session and moved into SESSION_ARCHIVE.md -- out of the file loaded at
#                        every session start. Nothing reported it. A session entry is now a
#                        DATED heading or `## Project start`, the same shape MEMORY_ENTRY_RE
#                        already used eight lines up, and everything else is skeleton: never
#                        counted, never archived, left in place.
#                        MEASURED BEFORE CHANGING THE REGEX, across every SESSION.md and
#                        SESSION_ARCHIVE.md on this machine. notebooklm-mcp-cli carries
#                        `## 2026-03 (multiple sessions)` -- a month-dated REAL entry that a
#                        \d{4}-\d{2}-\d{2} allowlist would have reclassified as skeleton,
#                        never counted and never archived, silently. Hence the optional day.
#                        The widened form reclassifies exactly 6 headings estate-wide and all
#                        six are genuinely skeleton. localcoder gains the most: both its
#                        pointers, including the one naming where its history lives, were
#                        rotatable entries before.
#                        plan_rotation() is extracted so the selection can be tested through
#                        the function main() calls rather than a restatement of it. 7 cases,
#                        both mutation-tested red: reverting to the denylist, and requiring a
#                        day in the date.
#   2026-09-06 v0.20.2.20260906.0406 — --check NAMES THE CEILING THAT BINDS (#302). The [ok]
#                        line reported the LINE ceiling only, so a reader watching "785 / 800
#                        lines" read that as comfortable while the file sat ~450 chars from an
#                        [over]. In a dense repository the CHARACTER ceiling is the one that
#                        actually trips -- measured three times in one adopting repo in two
#                        days, on MEMORY.md twice and BACKLOG.md once, and the 800-line ceiling
#                        was never approached in any of them. The information already existed
#                        on the [over] line; it was simply invisible until after the surprise.
#                        Now both are shown with the binding one named and its headroom given.
#   2026-09-02 v0.20.1.20260902.0359 — THE REVISIT DETECTOR MATCHED A FORM NOBODY WRITES
#                        (#284). The pattern demanded the word immediately after the bullet.
#                        ai/STANDARDS.md's example is written that way and NOTHING ELSE IN
#                        THESE FILES IS: every other lead-in in a MEMORY.md entry is bolded,
#                        so the house style is `- **Revisit:**` and the `**` sits exactly
#                        where the pattern demanded the word.
#                        MEASURED in ai-project-scaffold-dev: 10 triggers present, 10 bolded,
#                        0 matched. The check reported "no Revisit trigger" on 100% of
#                        entries since it shipped, including every entry that had one -- the
#                        single signal it exists to find was the one thing it could not see.
#                        AND `\b` WAS THE WRONG BOUNDARY. `_` is a word character, so
#                        `Revisit\b` fails on `_Revisit_:` -- the emphasis form breaking on
#                        its own closing mark. A negative lookahead for a letter is the
#                        property meant: the word Revisit, not Revisiting.
#   2026-09-01 v0.20.0.20260901.1656 — --session-head: THE LOAD ORDER STOPS ASKING FOR THE
#                        WHOLE LOG (#280). ai/SESSION.md is append-only and was read in full
#                        at every session start, so the older it got the more of every
#                        context window went to older and older history. MEASURED across
#                        four repositories on 2026-09-01, the nine always-loaded files came
#                        to 95, 156, 179 and 211 KB -- the last is roughly 54k tokens, a
#                        quarter of a window spent before the first instruction.
#                        ARCHIVING WAS NOT THE ANSWER ON ITS OWN. It moves entries out of a
#                        file people want whole in git; this moves nothing and deletes
#                        nothing. It prints the preamble plus the newest N entries (3 by
#                        default) and says how many it did not show. --bytes gives
#                        setup.sh --check the number the load order actually costs, so the
#                        ceiling measures what a session pays rather than what is on disk.
#   2026-09-01 v0.19.0.20260901.0615 — A SELFTEST THAT FAILED ON THE CONTENTS OF SOMEBODY'S
#                        MEMORY FILE. 0.17.0 asserted "ai/MEMORY.md is archivable, or teaches
#                        the archivable shape" inside selftest(). It is a true and useful
#                        property -- and it is a fact about a REPOSITORY, not about this
#                        tool. Every adopter whose ai/MEMORY.md predates the 0.17.0 template
#                        has zero dated entries and no placeholder, and ai/MEMORY.md is on
#                        the upgrade's never-touched list, so the new template reaches NEW
#                        adoptions only. Measured: it went red in control and localcoder-dev
#                        the moment they took 0.82.10. Preflight red on arrival is the one
#                        hazard this project keeps naming, because a gate that is red on
#                        arrival is a gate people learn to skip.
#                        A selftest asserts the TOOL. The repository condition moved to
#                        report_memory_archivability(), printed by --all --check as a [note ]
#                        that fails nothing -- and it is upstream of check_memory_format(),
#                        which reports on entries it RECOGNISES and therefore had nothing to
#                        say about the one file it could not read at all. The three cases now
#                        run on fixtures, one per shape.
#   2026-09-01 v0.18.0.20260901.0550 — ROTATING A SESSION LOG TURNED A GREEN REPO RED, and
#                        0.82.8 had just made the gate that recommends rotating a FAILING
#                        one. Session entries quote the commands that were run; once rotated
#                        they sit in SESSION_ARCHIVE.md naming tools since renamed or
#                        retired, and stale_path_scan reads them as live instructions.
#                        Measured here: one rotation moved 11 entries and produced three
#                        findings, turning a passing repo red as the direct result of running
#                        the archiver the gate had recommended. The mechanism already existed
#                        -- `scaffold:file-is-historical` is that scanner's own whole-file
#                        exemption, documented for files that "record dead commands" -- and
#                        nothing wrote it. Now stamped with a date and a reason, because the
#                        same scanner separately reports exemptions carrying neither.
#                        AND THE 0.17.0 TEMPLATE CASE OVER-GENERALISED. It asserted a property
#                        of the SHIPPED TEMPLATE and then ran in every adopter, where
#                        ai/MEMORY.md is a real memory file -- so it failed in
#                        ai-project-scaffold-dev, whose file has 78 dated entries and no
#                        placeholder. Identical mistake to adoption_check's new-project
#                        scenario, made the same day, both by assuming $ROOT is upstream. The
#                        property that holds everywhere is "this file is archivable, or it
#                        teaches the archivable shape".
#   2026-09-01 v0.17.0.20260901.0531 — IT COULD NOT SEE THE FILE IT SHIPS. memory_entries()
#                        recognises `## YYYY-MM-DD` headings. The shipped ai/MEMORY.md
#                        template contains none and never did: decisions were rows in a
#                        MARKDOWN TABLE and gotchas are list items. So for every adopter
#                        following the template exactly, `entries` was empty, and
#                        memory_preserve() printed "every non-stub entry is already preserved
#                        in ai/MEMORY_ARCHIVE.md" -- about a file that in most repos DOES NOT
#                        EXIST, over an empty set. Counted 2026-09-01: 78 dated entries in
#                        ai-project-scaffold-dev, 0 in localcoder, 0 in control, 0 here. It
#                        worked in the maintainer's own repo and was blind everywhere it
#                        shipped. An adopter hit it at 873 lines: over the line, told to
#                        archive, and told archiving was already done.
#                        THE TEMPLATE NOW TEACHES `### YYYY-MM-DD` ENTRIES and the parser
#                        accepts `##` or `###`. The selftest asserts the AGREEMENT -- that
#                        the shape the template teaches is the shape the parser accepts --
#                        because every existing case built its own dated fixture, which is
#                        how a suite of 30 checks missed that the shipped format matched
#                        none of them.
#                        AND `LINES` IS THE WRONG UNIT. These files are loaded at every
#                        session start, so the cost is tokens: localcoder's MEMORY.md is 236
#                        lines and 33,017 chars (~8,250 tok) where the -dev one is 736 lines
#                        and 50,489 (~12,600) -- 140 chars/line against 69. Under an 800-LINE
#                        ceiling the dense file may reach ~28,000 tokens while every report
#                        says it is comfortably under. CHAR_LIMITS adds that dimension,
#                        ADVISORY AND WITH NO BURST: a new measure able to fail a build the
#                        day it ships would redden repositories on a number nobody has been
#                        shown.
#                        THE DENOMINATOR IS COUNTED NOW, NOT DECLARED. `total = 8` had not
#                        moved in twenty additions: the suite said 31/31 whether it held 31
#                        checks or 66, so adding a case could only ever make the number go
#                        DOWN. It holds 66.
#   2026-08-20 — STAMP CORRECTED from .1330 to .0518. The first was
#                        FABRICATED: written from nothing rather than read from the clock,
#                        landing ~8 hours in the future. ai/STANDARDS.md names this exact
#                        failure -- a stamp rounded forward makes the next honest release
#                        sort EARLIER than its predecessor. The replacement is this file's
#                        real commit time from git.
#   2026-08-20 v0.16.0 — THE SHIPPED CEILING MOVES 600/700 -> 800/900. Asked for by the
#                        owner to make room for every participant writing to the record,
#                        not only Claude Code: a local model driven directly, or through
#                        localcoder, should land its outcome in ai/ too, and the old line
#                        was sized for one writer.
#                        FIVE SITES CARRY THE DEFAULT AND THREE MORE ONLY LOOK LIKE IT.
#                        This file's own header records the bug where a declaration and a
#                        doc drifted apart, so the split matters: DEFAULT_LIMITS,
#                        DEFAULT_BURSTS, the shipped-burst case, and both halves of the
#                        #210 drift case read the default and moved. The 600/700 inside
#                        `scaffold:ceilings` MARKERS did NOT -- those are fixture values
#                        proving the parser reads a declared pair, and rewriting them
#                        would have tested nothing while looking tidy.
#   2026-08-18 v0.11.0.20260818.0753 — --exit-status, because setup.sh had to GREP THIS TOOL'S
#                        PROSE to learn what happened, and grepped for `[over]` -- which does
#                        not match `[BURST]`. The worse state matched nothing and fell through
#                        to `[OK] ai/ files under their archive lines`.
#                        MEASURED IN THIS PROGRAMME'S OWN CONTEXT REPO: BACKLOG.md 23 lines
#                        over the archive line was REPORTED, while SESSION.md 316 lines PAST
#                        burst and MEMORY.md 120 past burst were SILENT. The check got
#                        quieter as the breach got worse.
#                        0 clean / 1 over / 2 burst, OPT-IN: plain --check is documented as
#                        always exiting 0 and callers rely on it, so the contract is unchanged.
#                        The selftest asserts the three rungs are STRICTLY ORDERED rather than
#                        merely present -- a case asserting "burst warns" would have passed
#                        the whole time, since check_size always printed the line. The loss
#                        was one caller down, in what it did with it.
#   2026-08-13 v0.10.1 — A CEILING DECLARED FOR A FILE THAT IS NOT THERE NOW SAYS SO. The
#                        production loop iterates the DECLARED ceilings, and check_size
#                        returned at its first line when the file was absent — so a marker
#                        naming a missing file produced NO OUTPUT AT ALL. The report was one
#                        line shorter and nothing said which line or why. "Under its limit"
#                        and "not checked at all" are the two states this tool exists to
#                        separate, and they printed identically.
#                        Same argument as scaffold:product-dir failing on a missing directory
#                        rather than skipping: otherwise renaming the target retires a check
#                        and discovery just gets quieter. Advisory, like everything here.
#                        Found by the owner asking whether the scaffold needs to SHIP
#                        ai/BACKLOG.md. It already does — all three are tracked templates —
#                        and the real gap was what happens once an adopter removes one.
#   2026-08-13 v0.10.0 — #180 STOPPED IT RECURRING AND NEVER TOLD THE PROJECTS ALREADY
#                        HOLDING IT (#210). Two live ceilings markers meant adopters ran whole
#                        releases on their own 150/200/260 because their line sat above
#                        upstream's. Making upstream's an inline example prevented NEW
#                        occurrences and did nothing for the existing ones, which had no way
#                        to find out. Reported from Robiton/godsfall, whose ai/STANDARDS.md
#                        DECLARES BACKLOG.md=200 at line 440 and DOCUMENTS 600/700 at line
#                        485 — the machine reads one, the human reads the other, forty-five
#                        lines apart, in the file loaded into every session.
#                        An over-the-line report now names both numbers. FIRES ONLY WHEN
#                        ACTIONABLE: a project deliberately holding a low ceiling is making a
#                        legitimate choice and is not nagged for it, and at or above the
#                        shipped default the note is silent — a warning that always fires is
#                        one people filter out, which is this file's founding argument.
#                        Also fixed a fixture that could not fail: the BACKLOG case asserted
#                        `is False` against a file that did not exist in the temp root, which
#                        check_size satisfies by returning at its first line.
#   2026-08-09 v0.9.0 — TWO LIVE ceilings MARKERS IS A REAL STATE, AND IT WAS SILENT (#180).
#                        Upstream carried its own marker at column 0 as an example; the
#                        three-way merge brought it into projects that already had one, and
#                        .search() takes the FIRST. An adopter ran a release on 150/200/260
#                        purely because their line sat above upstream's — any edit that
#                        reordered them would have moved the project to 600/700 with nothing
#                        reporting it. Upstream's example is inline code now (the values were
#                        the built-in defaults anyway, so nothing changes by not declaring
#                        them), and duplicates print every marker with the one in force.
#                        The rule is unchanged — FIRST wins — and is now stated and tested
#                        rather than emergent. The new case fails under last-wins.
#   2026-08-09 v0.8.0 — ALL THREE files ship 600/700, not just MEMORY.md. A burst on one
#                        file read as a special case rather than as how ceilings work
#                        here; one pair to remember, and no file where crossing the line
#                        means something different.
#                        The numbers are generous because of what the archive paths DO.
#                        SESSION.md MOVES text, automatically and losslessly — nothing is
#                        at risk there whatever the number says. BACKLOG.md and MEMORY.md
#                        COPY, and a human then deletes or trims: that is where a tight
#                        ceiling becomes pressure on a person to remove something, and no
#                        number here should be pushing anyone toward that.
#   2026-08-09 v0.7.0 — MEMORY.md ships at 600 with a BURST line at 700, and neither
#                        number blocks. That is what separates this from the warn/hard
#                        pair 0.14.0 removed: a hard level failed the build and caught
#                        people mid-thought; a burst line changes the VOLUME of a report
#                        and never its exit code. It exists because one number cannot say
#                        both "you crossed the line while writing decisions" and "the trim
#                        stopped happening", and a report that says the same thing at 601
#                        lines and at 750 is one people stop reading.
#                        `NAME=600/700` reuses the 0.13.x warn/hard syntax deliberately:
#                        reinterpreting it is a strict SOFTENING, since the larger number
#                        used to fail the build and now only raises volume, and the lower
#                        number keeps the meaning it always had.
#                        Also: three marker fixtures hardcoded 400 as "over the built-in
#                        ceiling", true at 350 and false at 600 — they went green while
#                        asserting the opposite of what they read. Derived from
#                        DEFAULT_LIMITS now. A fixture that encodes a constant it does not
#                        own is a second definition of that constant.
#   2026-08-08 v0.6.1 — The MEMORY.md fallback ceiling is 350, matching what the scaffold
#                        now declares. It is only a fallback — ai/STANDARDS.md is the
#                        definition — but a fallback that disagrees with the shipped
#                        marker reports a different verdict the moment the marker is
#                        missing, which is the one situation where nobody is looking.
#   2026-08-08 v0.6.0 — ARCHIVING IS ADVISORY. Nothing in this tool fails a build any more.
#                        The hard level went in as "warn gives room, hard still bites", and
#                        the bite was the wrong instrument: these files are a working
#                        record, and failing CI over their length stops the work to tidy
#                        the notes about the work. Every hard variant caught someone
#                        mid-thought. One number per file now — the line at which you
#                        should archive; 0.13.x warn/hard markers still load, on the lower
#                        number. --check and --all --check both exit 0, so the two modes
#                        can no longer disagree at all (#142's defect is gone by
#                        construction rather than by a matching exemption).
#                        BACKLOG.md gains the third can_shrink supplier it never had, so
#                        every file's advice distinguishes "there is something to archive"
#                        from "this is simply long" — the latter says to shorten or raise
#                        the number instead, because advice that cannot be followed is how
#                        a report stops being read.
#   2026-08-08 v0.5.1 — --all --check honours the same "nothing left to archive" exemption
#                        the single-file path has always applied (#142). They returned
#                        OPPOSITE verdicts for one ai/SESSION.md — 89 lines, one entry,
#                        --check passed and --all --check failed — and --all is the mode a
#                        project wires into CI, so the decision that failing on one long
#                        entry "would be noise" was made in the path CI does not use and
#                        silently reversed in the path it does. check_size's conditional is
#                        now general: `can_shrink` is whatever archiving could still remove,
#                        non-stub entries for MEMORY.md and rotatable entries for SESSION.md.
#   2026-08-08 v0.5.0 — Check the MEMORY entry FORMAT, and preserve before anyone trims.
#                        The ceiling was enforced and the format was not, so a line count
#                        could not tell "the ceiling is too low" from "nobody wrote stubs"
#                        — the ambiguity ai/STANDARDS.md warns about, which then moved that
#                        repo's ceiling 250 -> 300 -> 350 in three weeks. Measured on it:
#                        23 dated entries = 286 of 348 lines, 82%, averaging 12 lines
#                        against a 3-4 line bar, 6 of 23 carrying an archive reference.
#                        ADVISORY, never blocking: making it fail would turn every existing
#                        MEMORY.md red on this release, which is #76 exactly.
#                        --memory-preserve copies non-stub entries VERBATIM into
#                        MEMORY_ARCHIVE.md and never writes MEMORY.md. Archive, not purge:
#                        choosing which lines are the decision is judgement and a script
#                        guessing would drop a live one, but COPYING is not a judgement, so
#                        the human's trim becomes reversible by construction. Idempotent.
#                        Five selftest cases including the safety property itself.
#                        TWO LEVELS, HARD ONE CONDITIONAL. `MEMORY.md=250/350` is warn/hard;
#                        a bare number still means both, so existing markers are unchanged.
#                        A single hard line fires on the commit that crosses it — in
#                        practice the middle of writing an entry — and ai/SECURITY.md's own
#                        rule is that a guard blocking legitimate work gets disabled. Warn
#                        gives room to finish; hard still bites, because a level that never
#                        bites is what let SESSION.md reach 1,001 lines against a stated 150.
#                        The hard level blocks ONLY while entries are still essays: all
#                        stubs and still over means archiving cannot help and the number is
#                        too small, so it warns and says to raise it. That is the ambiguity
#                        ai/STANDARDS.md names, made machine-answerable — and it is what
#                        stops the ceiling being the thing that moves every few weeks.
#                        ALL THREE FILES flex, not just MEMORY.md — a long session entry or
#                        a busy backlog crosses its line mid-work the same way. And
#                        --backlog-preserve gives BACKLOG.md the same copy-only archive path
#                        MEMORY.md has. SESSION.md stays the one command that MOVES text, and
#                        its selftest now asserts the move is lossless; the other two only
#                        ever add, so "this tool never removes anything" holds toolchain-wide
#                        rather than per command.
#   2026-08-05 v0.4.1 — Anchor the ceilings marker to column 0, so a documented example
#                        cannot be read as a declaration. Correct today only because no
#                        second example existed yet.
#   2026-08-04 v0.4.0 — Ceilings are read from the `<!-- scaffold:ceilings ... -->` line in
#                        ai/STANDARDS.md, not hardcoded here. `tools/` is VENDORED — a
#                        project that raised its ceiling in this file would have it
#                        silently reverted by the next scaffold update, and the reversion
#                        would look like the file suddenly going over. ai/STANDARDS.md is
#                        marked never-overwrite and already states the ceilings in prose,
#                        so the machine-readable copy now sits beside the human-readable
#                        one: one definition, editable safely. `--check` names which source
#                        it used. Added `--selftest` (6 cases) proving the marker changes
#                        the verdict in BOTH directions — a config mechanism only ever
#                        exercised at its default is indistinguishable from a constant.
#   2026-08-04 v0.3.0 — `--all --apply` accepted the flag and rotated nothing. Refuse it
#                        and name the command that does rotate. Added the file header this
#                        file was missing entirely — it is the tool that enforces the
#                        scaffold's own rules, and it did not follow them.
#   2026-08-04 v0.2.0 — `--all`: check every ai/ file with a stated ceiling, not just
#                        SESSION.md; preserve an existing archive's own preamble; never
#                        count or rotate the template blocks a fresh scaffold ships with.
#   2026-07-31 v0.1.0 — Initial creation
"""session_archive — rotate the append-only scaffold logs past their stated ceilings.

WHY THIS EXISTS
  ai/STANDARDS.md already specifies the ceilings:
    SESSION.md  — exceeds its archive line -> SESSION_ARCHIVE.md (a lossless MOVE)
    BACKLOG.md  — at each release, completed tasks -> BACKLOG_ARCHIVE.md
    MEMORY.md   — superseded entries               -> MEMORY_ARCHIVE.md
  Nobody does it. Measured 2026-07-31 in this repo: SESSION.md was 1001 lines
  against its own ~150-line ceiling, and no archive file existed at all. A rule
  that depends on a human remembering it at the end of a long session is a rule
  that quietly stops being true, and these files are loaded at EVERY session
  start — so the cost of ignoring it is paid by every future session.

  This makes it mechanical. Run it from a hook, from CI, or by hand.

CEILINGS ARE DECLARED IN ai/STANDARDS.md, not here — see load_limits() for why.

Usage:
  tools/session_archive.py --check     # report only, non-zero if over ceiling (for CI)
  tools/session_archive.py --all       # every file with a stated ceiling
  tools/session_archive.py --apply     # actually rotate SESSION.md
  tools/session_archive.py --keep 5    # sessions to retain (default 5)
  tools/session_archive.py --selftest  # prove the ceiling marker is load-bearing
"""
import argparse
import datetime
import os
import re
import sys


def _today():
    """Local date as YYYY-MM-DD, for stamping a declaration that has to carry one."""
    return datetime.date.today().strftime("%Y-%m-%d")

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SESSION = os.path.join(ROOT, "ai", "SESSION.md")
ARCHIVE = os.path.join(ROOT, "ai", "SESSION_ARCHIVE.md")
BACKLOG = os.path.join(ROOT, "ai", "BACKLOG.md")
BACKLOG_ARCHIVE = os.path.join(ROOT, "ai", "BACKLOG_ARCHIVE.md")
MEMORY = os.path.join(ROOT, "ai", "MEMORY.md")
MEMORY_ARCHIVE = os.path.join(ROOT, "ai", "MEMORY_ARCHIVE.md")

# THE CEILING WAS ENFORCED AND THE FORMAT WAS NOT, WHICH IS WHY THE CEILING KEEPS MOVING.
#
# ai/STANDARDS.md -> "MEMORY.md quality bar" says a LIVE entry is a stub: what was decided
# plus the measurement that makes it stick, the revisit trigger, and a cross-reference to
# ai/MEMORY_ARCHIVE.md for the why and the rejected alternatives. Nothing checked any of
# that, so entries grew to full essays and the only visible symptom was the line count —
# at which point "the ceiling is too low" and "I have not written stubs" look identical
# from inside the file, exactly as that section warns.
#
# Measured on this scaffold's own development repo, 2026-08-08: 348 lines, of which 23
# dated decision entries were 286 lines — 82% of the file — averaging 12 lines each
# against a 3-4 line bar, and only 6 of the 23 carried an archive cross-reference. Stubbing
# them projects to ~157 lines, BELOW the shipped 250 default. The ceiling had been raised
# 250 -> 300 -> 350 over three weeks; none of those raises was the fix.
STUB_MAX_LINES = 6
# Only dated entries are decisions. "## Project overview", "## Architecture" and the other
# structural sections are the file's skeleton and are never stubbed.
# `##` OR `###`, because the shipped template's sections are `##` and a decision written
# under one is necessarily a level deeper. Requiring `##` meant an adopter following the
# template exactly produced zero recognisable entries -- see memory_preserve().
MEMORY_ENTRY_RE = re.compile(r"^#{2,3} (\d{4}-\d{2}-\d{2})")
# Entries start with "## [date]" or "## Project start"; the file's preamble is
# everything before the first one and must never be archived.
ENTRY_RE = re.compile(r"^## ", re.M)

# A freshly-adopted scaffold ships SESSION.md with instructional blocks — a
# "## Template — copy this block" heading and unfilled "## [YYYY-MM-DD]" placeholders.
# Those are structure, not history. Counting them as entries makes them consume
# retention slots: measured on the shipped template plus 6 real sessions, the 3
# template blocks took 3 of the 5 slots and four REAL sessions were rotated out.
# They are never counted and never archived; they stay where they are.
TEMPLATE_RE = re.compile(r"^## (?:Template\b|.*YYYY-MM-DD)", re.I)

# ==== WHAT COUNTS AS AN ENTRY IS AN ALLOWLIST, NOT A DENYLIST (#318) =======================
#
# TEMPLATE_RE above is a denylist, and it was written because this already went wrong once:
# template blocks took 3 of the 5 retention slots and four REAL sessions were rotated out. The
# fix at the time was to add one name to the denylist, so it held only until somebody wrote a
# heading the tool had not seen.
#
# On 2026-09-22 that happened in localcoder-dev. A STANDING POINTER --
# "## Delegated drafts — the live table is NOT here", the paragraph that replaces the
# scaffold:closeouts markers and stops a close_out.py run there from splitting the record
# across two files -- was counted as a session and rotated into SESSION_ARCHIVE.md. Out of the
# file loaded at every session start, into the file that is not. Nothing reported it; it was
# caught by reading the rotation list.
#
# The right shape was already in this file, eight lines up: MEMORY_ENTRY_RE requires a DATE,
# with the reasoning written next to it -- structural sections are the file's skeleton. The
# comment above ENTRY_RE says the same thing about SESSION.md ("Entries start with
# `## [date]` or `## Project start`"); the regex simply did not say it.
#
# THE MONTH-ONLY FORM IS REAL AND IS AN ENTRY. Measured across every SESSION.md and
# SESSION_ARCHIVE.md on this machine before changing anything: notebooklm-mcp-cli carries
# `## 2026-03 (multiple sessions) — Brian Worrell — Claude Code`. A `\d{4}-\d{2}-\d{2}`
# allowlist would have reclassified a REAL session as skeleton -- never counted, never
# archived -- which is the dangerous direction and is silent. Hence `\d{4}-\d{2}` with an
# optional day. Over the whole estate the widened form reclassifies exactly 6 headings, and
# every one is genuinely skeleton: three repo-name sections in the scaffold-dev archive and
# three "the live table is NOT here" pointers.
SESSION_ENTRY_RE = re.compile(r"^## (?:\d{4}-\d{2}(?:-\d{2})?\b|Project start\b)", re.I)


def _head(block):
    lines = block.splitlines()
    return lines[0] if lines else ""


def is_entry(block):
    """True for a session entry: a dated heading, or `## Project start`.

    Everything else under `## ` is skeleton -- templates, pointers, structural sections --
    and is never counted against a ceiling and never archived.
    """
    return bool(SESSION_ENTRY_RE.match(_head(block)))


def is_template(entry):
    """True for the scaffold's instructional blocks. Retained for REPORTING only.

    is_entry() already excludes these; this distinguishes "template" from "standing section"
    in the summary line so the count is explainable rather than merely correct.
    """
    return bool(TEMPLATE_RE.match(_head(entry)))


def plan_rotation(text, keep, max_lines):
    """Decide what rotates out of SESSION.md, without touching a file.

    Returns (kept_blocks, rotate_blocks, projected_lines, real, skeleton).

    EXTRACTED SO IT CAN BE TESTED (#318). This selection used to live inline in main(),
    reachable only through argparse and a real file, so the only way to assert on it was to
    restate it in the test -- which is the ci_status defect this project already named: a
    second copy of the logic agrees with itself and with nothing else. main() now calls this.
    """
    preamble, entries = split_sessions(text)
    real = [e for e in entries if is_entry(e)]
    skeleton = [e for e in entries if not is_entry(e)]

    def rebuild(n):
        kept_real = real[:n]
        # SKELETON KEEPS ITS PLACE. The comprehension walks `entries` in FILE ORDER, so a
        # standing section that sits between two entries stays between what remains of them
        # rather than being appended somewhere it did not come from.
        kept = [e for e in entries if not is_entry(e) or e in kept_real]
        return kept, len((preamble + "".join(kept).rstrip() + "\n").splitlines())

    n = min(keep, len(real))
    while n > 1 and rebuild(n)[1] > max_lines:
        n -= 1
    kept, projected = rebuild(n)
    return kept, real[n:], projected, real, skeleton


def split_sessions(text):
    """(preamble, [entry, ...]) — entries newest-first, matching the file's order."""
    marks = [m.start() for m in ENTRY_RE.finditer(text)]
    if not marks:
        return text, []
    preamble = text[: marks[0]]
    entries = [text[marks[i]: (marks[i + 1] if i + 1 < len(marks) else len(text))]
               for i in range(len(marks))]
    return preamble, entries


# ai/STANDARDS.md states ceilings for THREE files; only SESSION.md was ever enforced.
# A stated ceiling that nothing enforces is the failure this project already learned the
# hard way — SESSION.md reached 1001 lines against a stated ~150 precisely because the
# rule depended on someone remembering it. MEMORY.md and BACKLOG.md were on exactly that
# footing: measured downstream, ai/MEMORY.md grew 148 -> 218 lines in a single day and
# nothing complained, because nothing was watching.
#
# The destination is NOT the hard part — the SELECTION is, and it differs per file:
#   SESSION.md  oldest entries, purely age-based        -> mechanical, --apply supported
#   BACKLOG.md  completed tasks, at each release        -> mechanical, --apply supported
#   MEMORY.md   SUPERSEDED decisions                    -> needs judgement, --check only
# Auto-rotating MEMORY.md would mean a script deciding which decisions are obsolete.
# That is a human call, so it is reported and never applied.
# ONE NUMBER PER FILE: the line at which you should ARCHIVE. Nothing here ever blocks.
#
# These files are a working record, and a check that fails the build over their length
# stops the work to tidy the notes about the work. Every hard variant of this tried so far
# hit someone mid-thought: a single hard line fires on the commit that crosses it, and
# ai/SECURITY.md's own rule is that a guard blocking legitimate work gets disabled — at
# which point it protects nothing anyway.
#
# So the enforcement is not a gate, it is the pair of properties that make archiving safe
# and obvious: the report says exactly which entries are over the bar and what archiving
# would recover, and every archive path ADDS to the archive without removing from the live
# file, so acting on it is never a risk. A warning you can act on in one command is a
# different thing from a warning with no cheap remedy.
#
# The known cost, recorded rather than hidden: ai/SESSION.md once reached 1,001 lines
# against a stated ~150 while this was advisory. That is why the report is specific and
# why --apply and the preserve commands exist. Length is a housekeeping matter; it is not
# worth a red build.
# MEMORY.md sits higher than the other two on purpose. A session entry is a log line and a
# backlog item is a task, but a memory entry is an argument — decision, what it rules out,
# the evidence that settled it — and the entries worth re-reading run 13 to 35 lines. At 250
# a project crossed the line for having eight of them, and the cheapest way back under was
# to write the next decision as a one-liner nobody can act on. See ai/STANDARDS.md.
# ALL THREE FILES FLEX, AND THEY FLEX THE SAME WAY. Until 0.19.0 only MEMORY.md had a
# burst line, which made the mechanism look like a special case for one file rather than how
# ceilings work here. The numbers are deliberately identical: one pair to remember, and no
# file where crossing the line means something different from the others.
# THE SIZE CEILING, IN THE UNIT THAT IS ACTUALLY PAID. See check_size() for the measurement
# that motivated it. ~48,000 chars is about 12,000 tokens, which is what 800 lines costs at
# the ~60 chars/line these templates were sized against. No burst pair: this reports and
# never fails, until there is fleet data to justify promoting it.
CHAR_LIMITS = {
    "SESSION.md": 48000,
    "BACKLOG.md": 48000,
    "MEMORY.md": 48000,
}

DEFAULT_LIMITS = {
    "SESSION.md": 800,
    "BACKLOG.md": 800,
    "MEMORY.md": 800,
}

# THE BURST LINE: "you are not a little over, you are well over."
#
# NEITHER NUMBER BLOCKS. That is what separates this from the warn/hard pair 0.14.0
# removed, and the distinction is the whole point: a hard level failed the build, fired on
# whichever commit happened to cross it, and caught people mid-thought — ai/SECURITY.md's
# rule is that a guard blocking legitimate work gets disabled, and then it protects nothing.
# A burst line changes the VOLUME of a report, never its exit code.
#
# It exists because one number cannot say both things. Crossing the archive line while
# actively writing decisions is normal and the right response is "get to it". Sitting 100
# lines past it means the trim stopped happening, and a report that says the same thing in
# both cases is one people stop reading — the failure this whole file is built around.
DEFAULT_BURSTS = {
    "SESSION.md": 900,
    "BACKLOG.md": 900,
    "MEMORY.md": 900,
}

# The ceilings are DECLARED IN ai/STANDARDS.md, not here.
#
#   <!-- scaffold:ceilings SESSION.md=150 BACKLOG.md=120 MEMORY.md=350 -->
#
# Why not a constant in this file: `tools/` is vendored into adopting projects, so a
# scaffold update overwrites it — a project that raised its own ceiling here would have it
# silently reverted on the next upgrade, and the reversion would look like the file
# suddenly going over. ai/STANDARDS.md is marked "never overwrite" in the adoption guide
# and is already where the ceilings are stated in prose, so putting the machine-readable
# copy beside the human-readable one keeps it to ONE definition that can be edited safely.
#
# Deliberately a marker rather than prose parsing: reading the numbers out of the
# surrounding sentences would be a regex over English, and this project has already been
# bitten twice by a regex that worked on the fixture and not on the real file.
# Anchored for the same reason FORK_MARKER is: a marker documented in the file it is read
# from will match its own documentation unless the pattern distinguishes a declaration
# (column 0) from an example (indented in a code block). This one happened to be correct
# because no second example exists yet — "correct by luck" is the state this repo keeps
# finding and removing.
CEILING_RE = re.compile(r"^<!--\s*scaffold:ceilings\s+([^>]*?)-->", re.I | re.M)


def load_limits():
    """(limits, source) — ceilings from ai/STANDARDS.md, else the built-in defaults.

    An unparseable or absent marker falls back silently to defaults: a project that has
    not adopted the marker yet must keep working, and a broken marker must not be the
    reason archiving stops being enforced.
    """
    limits = dict(DEFAULT_LIMITS)
    bursts = dict(DEFAULT_BURSTS)
    path = os.path.join(ROOT, "ai", "STANDARDS.md")
    try:
        _text = open(path).read()
    except OSError:
        return limits, bursts, "built-in defaults (no ai/STANDARDS.md)"
    # TWO LIVE MARKERS IS A REAL STATE, AND IT USED TO BE SILENT (#180).
    #
    # Upstream carried its own marker at column 0 as an example. The three-way merge brought
    # it into projects that already had one, and `.search()` takes the FIRST — so an adopter
    # ran a whole release on their own 150/200/260 purely because their line happened to sit
    # above upstream's. Any later edit reordering the two would have moved them to 600/700
    # with nothing reporting the change. Upstream's example is inline code now, so this
    # cannot arise from an upgrade again; it can still arise from a hand edit.
    #
    # The rule is FIRST WINS, unchanged — this only makes it visible. Silently picking one of
    # two contradictory declarations is the shape this repo keeps removing.
    _all = CEILING_RE.findall(_text)
    m = CEILING_RE.search(_text)
    if len(_all) > 1:
        _line = _text[: m.start()].count("\n") + 1 if m else 0
        print(f"[!]  {len(_all)} scaffold:ceilings markers in ai/STANDARDS.md — the FIRST wins "
              f"(line {_line}).", file=sys.stderr)
        for _i, _raw in enumerate(_all):
            print(f"       {'IN FORCE' if _i == 0 else 'ignored '}  {_raw.strip()}",
                  file=sys.stderr)
        print("       Two declarations of one setting is ambiguous. Delete the one you do "
              "not mean.", file=sys.stderr)
    if not m:
        return limits, bursts, "built-in defaults (no scaffold:ceilings marker in ai/STANDARDS.md)"
    found, found_bursts = {}, {}
    for pair in m.group(1).split():
        name, _, value = pair.partition("=")
        if name not in limits:
            continue
        # `NAME=600` is the archive line. `NAME=600/700` adds a BURST line: still an
        # archive line at the lower number, plus a louder report above the higher one.
        #
        # 0.13.x WROTE THE SAME SHAPE MEANING warn/hard, AND REINTERPRETING IT IS SAFE —
        # which is the only reason this reuses the syntax rather than inventing one. Under
        # the old meaning the larger number FAILED THE BUILD; under this one it raises the
        # volume of a report that always exits 0. Every adopter carrying a 0.13.x pair
        # therefore gets a strictly softer outcome, never a harder one, and the lower number
        # keeps the same meaning it always had. Order does not matter: min is the archive
        # line, max is the burst.
        a_s, _, b_s = value.partition("/")
        nums = [int(x) for x in (a_s, b_s) if x.isdigit() and int(x) > 0]
        if not nums:
            continue
        found[name] = min(nums)
        if len(nums) > 1 and max(nums) > min(nums):
            found_bursts[name] = max(nums)
    if not found:
        return limits, bursts, "built-in defaults (scaffold:ceilings marker present but unreadable)"
    limits.update(found)
    # A DECLARED marker OWNS its bursts. Leaving the built-in 700 in place for a project
    # that declared `MEMORY.md=200` would burst it at a number it never chose and cannot
    # see — a value the tool invented, reported as though the project had set it.
    for name in found:
        bursts.pop(name, None)
    bursts.update(found_bursts)
    return limits, bursts, "ai/STANDARDS.md"


def rotatable_sessions(keep=1):
    """How many SESSION.md entries could still be archived. 0 = archiving cannot help.

    The single-file path has always applied this exemption — "over on lines with a single
    entry left: archiving cannot help, and failing CI over one long session entry would be
    noise" — and `--all` never reached it, because it is a line-count loop and check_size
    knows nothing about entries. So the two modes returned OPPOSITE verdicts for the same
    file, and the mode a project wires into CI is the one that got it wrong (#142).
    """
    try:
        with open(SESSION, encoding="utf-8") as fh:
            entries = [e for e in split_sessions(fh.read())[1] if is_entry(e)]
    except (OSError, ValueError, IndexError):
        return None                      # cannot tell: fall back to blocking at hard
    return max(0, len(entries) - keep)


# ==== --session-head: THE LOAD ORDER STOPS ASKING FOR THE WHOLE FILE (#280) ================
#
# ai/SESSION.md is read in full at session start, and it is an append-only log: the older it
# gets, the more of every context window it costs, and the older the part that is costing it.
# MEASURED 2026-09-01 across four repositories, the nine always-loaded files came to 95 KB,
# 156 KB, 184 KB and 217 KB -- the last is roughly 54k tokens, a quarter of the window spent
# before the first instruction.
#
# ARCHIVING IS NOT THE ANSWER ON ITS OWN, because it moves entries OUT of a file people still
# want whole in git. The cheaper move is to stop READING all of it: the newest few entries
# carry the state a session actually resumes from, and the rest is history that can be asked
# for. So the load order in ai/STANDARDS.md now names the newest N entries, and this is the
# command that produces exactly those. Nothing is deleted and nothing is moved.
SESSION_HEAD_DEFAULT = 3


def session_head(n=SESSION_HEAD_DEFAULT, bytes_only=False):
    """Print the preamble plus the newest n entries of ai/SESSION.md.

    The preamble is always included: it is the paragraph that says what the file is, and a
    log whose header is missing reads as a truncated file rather than a deliberate view.
    A template entry is skipped for counting but printed, because in a fresh adoption it is
    the only thing there and printing nothing would look like a broken command.
    """
    try:
        with open(SESSION, encoding="utf-8") as fh:
            text = fh.read()
    except OSError as exc:
        print(f"session_archive --session-head: cannot read {SESSION} ({exc})",
              file=sys.stderr)
        return 3
    preamble, entries = split_sessions(text)
    real = [e for e in entries if is_entry(e)]
    kept = (real[:n] if real else entries[:n])
    out = preamble + "".join(kept)
    if bytes_only:
        print(len(out.encode("utf-8")))
        return 0
    sys.stdout.write(out)
    if len(real) > len(kept):
        sys.stdout.write(f"\n<!-- {len(real) - len(kept)} older entr"
                         f"{'y' if len(real) - len(kept) == 1 else 'ies'} not shown. "
                         f"They are still in ai/SESSION.md; ask for them by date. -->\n")
    return 0


# ==== THE REVISIT DETECTOR MATCHED A FORM NOBODY WRITES (#284) =============================
#
# The pattern was `^\s*[-*]\s*Revisit\b` — a bullet whose very next characters are "Revisit".
# ai/STANDARDS.md's own example is written that way, and NOTHING ELSE IN THESE FILES IS. Every
# other lead-in in a MEMORY.md entry is bolded, so the form people actually write is
# `- **Revisit:** ...`, and the `**` sits exactly where the pattern demanded the word.
#
# MEASURED 2026-09-02 in ai-project-scaffold-dev: 10 Revisit triggers present, 10 in the bold
# form, 0 matched. The check has reported "no Revisit trigger" on 100% of entries since it
# shipped, including every entry that had one — so the one signal it exists to find was the one
# thing it could never see, and the report was uniformly, confidently wrong.
#
# THE FIX IS TO READ THE FILE'S HOUSE STYLE, not to make people write against it. Optional
# emphasis (`**`, `*`, `_`, `__`) and an optional heading form are accepted; the word and its
# position in the bullet still carry the meaning.
# `\b` IS THE WRONG BOUNDARY HERE. `_` is a word character, so `Revisit\b` does not match
# `_Revisit_:` — the emphasis form fails on its own closing mark. A negative lookahead for a
# letter is the property meant: "the word Revisit, not Revisiting".
REVISIT_RE = re.compile(r"^\s*(?:[-*]|#{2,4})\s*[*_]{0,2}\s*Revisit(?![A-Za-z])",
                        re.M | re.I)


def memory_entries(text):
    """Dated decision entries only, as (heading, [lines]) — the skeleton is left alone."""
    lines = text.split("\n")
    starts = [i for i, ln in enumerate(lines)
              if ln.startswith("## ") or ln.startswith("### ")]
    out = []
    for a, b in zip(starts, starts[1:] + [len(lines)]):
        if MEMORY_ENTRY_RE.match(lines[a]):
            body = lines[a:b]
            while body and not body[-1].strip():
                body.pop()
            out.append((lines[a], body))
    return out


def completed_backlog_items():
    """How many `- [x]` items BACKLOG.md still holds. 0 = archiving cannot shorten it.

    The third supplier. BACKLOG.md had none, which is why it was the one file whose size
    report could not tell "there is something to archive" from "this is just long".
    """
    try:
        with open(BACKLOG, encoding="utf-8") as fh:
            return len(re.findall(r"^- \[[xX]\] ", fh.read(), re.M))
    except OSError:
        return None


def report_memory_archivability():
    """Can ai/MEMORY.md ever be archived by this tool? Advisory, and never a failure.

    A REPOSITORY CONDITION, NOT A TOOL PROPERTY, and putting it in --selftest was a category
    error that cost a fleet-wide red. 0.17.0 asserted this inside selftest(); every adopter
    whose ai/MEMORY.md predates the 0.17.0 template has zero dated entries and no placeholder
    -- and ai/MEMORY.md is on the upgrade's never-touched list, so the new template reaches
    NEW adoptions only. The result was a selftest failing on the contents of somebody's
    memory file, i.e. preflight red on arrival for every existing adopter, which is the exact
    hazard this project refuses: a gate that is red on arrival is one people learn to skip.

    A selftest asserts that the TOOL works. Whether THIS repository's file is in a shape the
    tool can act on is a finding about the repository, and findings belong in --check.
    """
    if not os.path.exists(MEMORY):
        return
    text = open(MEMORY, encoding="utf-8", errors="replace").read()
    if memory_entries(text):
        return
    if re.search(r"^#{2,3} YYYY-MM-DD", text, re.M):
        return       # the template shape is present; entries written to it will be archivable
    print("  [note ] ai/MEMORY.md has NO entry this tool can archive.")
    print("          It moves entries headed `## YYYY-MM-DD` or `### YYYY-MM-DD`. This file")
    print("          has neither, so there is no automated way back under its ceiling —")
    print("          only a trim by hand. Not a failure, and nothing here is broken.")
    print("          Head new decisions `### YYYY-MM-DD — <what was decided>` and they")
    print("          become archivable from that point on.")


def check_memory_format():
    """Report decision entries that are not stubs. NEVER blocking, and never a rewrite.

    ADVISORY ON PURPOSE, and that is a decision rather than timidity. Making it fail the
    build would turn every existing MEMORY.md red on the release that introduced it —
    which is #76 exactly, the defect this project already paid for once when a blocking
    header check failed 33 pre-existing files and the pull request could not merge. The
    bill lands hardest on the oldest, largest projects, i.e. the ones with the most to
    gain from upgrading. So this counts, names and totals; it does not refuse.

    What makes it more than a warning is that acting on it is cheap and safe:
    --memory-preserve copies the full entry into the archive first, so trimming afterwards
    cannot lose anything. A warning with no cheap remedy is the kind nobody acts on.
    """
    if not os.path.exists(MEMORY):
        return 0
    entries = memory_entries(open(MEMORY).read())
    if not entries:
        return 0
    bad = []
    for head, body in entries:
        text = "\n".join(body)
        reasons = []
        if len(body) > STUB_MAX_LINES:
            reasons.append(f"{len(body)} lines")
        if not REVISIT_RE.search(text):
            reasons.append("no Revisit trigger")
        if "MEMORY_ARCHIVE" not in text:
            reasons.append("no archive cross-reference")
        if reasons:
            bad.append((head, body, reasons))
    total = sum(len(b) for _, b, _ in bad)
    print("  ai/MEMORY.md entry format (ai/STANDARDS.md -> MEMORY.md quality bar):")
    if not bad:
        print(f"    all {len(entries)} decision entry(ies) are stubs")
        return 0
    print(f"    {len(bad)} of {len(entries)} decision entry(ies) are not stubs "
          f"({total} lines; a stub is <= {STUB_MAX_LINES})")
    for head, body, reasons in sorted(bad, key=lambda x: -len(x[1]))[:8]:
        print(f"      {len(body):>3} lines  {head[3:][:52]:<52}  {', '.join(reasons)}")
    if len(bad) > 8:
        print(f"      ... and {len(bad) - 8} more")
    saving = total - (len(bad) * 4)
    print(f"    Stubbing these would recover roughly {saving} line(s).")
    print("    ARCHIVE FIRST, THEN TRIM — nothing is ever deleted:")
    print("      tools/session_archive.py --memory-preserve   "
          "# full text -> MEMORY_ARCHIVE.md")
    print("    then trim each entry in ai/MEMORY.md to decision + Revisit + the reference.")
    return len(bad)


def memory_preserve(apply_it):
    """Copy over-bar entries VERBATIM into ai/MEMORY_ARCHIVE.md. Adds only; never removes.

    THIS IS THE WHOLE SAFETY ARGUMENT. Deciding which lines of an entry are "the decision"
    and which are "the rationale" is judgement, and a script guessing would quietly drop a
    live one — ai/STANDARDS.md is explicit that MEMORY.md is never auto-rotated. But
    COPYING is not a judgement. Once the full text is in the archive, the human's trim is
    reversible by construction, so the risky half of the job stops being risky.

    Archive entries are append-only and keep their original headings, so this is idempotent:
    an entry whose heading is already present is skipped rather than duplicated.
    """
    if not os.path.exists(MEMORY):
        print("  no ai/MEMORY.md — nothing to preserve")
        return 0
    entries = memory_entries(open(MEMORY).read())
    existing = open(MEMORY_ARCHIVE).read() if os.path.exists(MEMORY_ARCHIVE) else ""
    todo = []
    for head, body in entries:
        text = "\n".join(body)
        over = (len(body) > STUB_MAX_LINES
                or not REVISIT_RE.search(text)
                or "MEMORY_ARCHIVE" not in text)
        if not over:
            continue
        if head.strip() in existing:
            continue          # already archived; never write it twice
        todo.append((head, body))
    if not todo:
        # AN EMPTY SET IS NOT A CLEAN BILL OF HEALTH, AND THIS ONE WAS NEARLY ALWAYS EMPTY.
        #
        # memory_entries() recognises `## YYYY-MM-DD` (and now `### YYYY-MM-DD`) headings.
        # THE SHIPPED ai/MEMORY.md TEMPLATE CONTAINS NO SUCH HEADING AND NEVER DID: its
        # decisions are rows in a Markdown TABLE under "## Architecture decisions", and its
        # gotchas are list items under "## Known issues and gotchas". So on a repository
        # that follows the template exactly -- which is every adopter -- `entries` was empty,
        # `todo` was empty, and this branch printed that everything was already preserved in
        # a file that in most cases DOES NOT EXIST.
        #
        # Measured across this fleet on 2026-09-01, `## YYYY-MM-DD` headings in ai/MEMORY.md:
        #     ai-project-scaffold-dev  737 lines   78   (and it has MEMORY_ARCHIVE.md)
        #     localcoder               237 lines    0
        #     control                   89 lines    0
        #     ai-project-scaffold       89 lines    0
        # It worked in exactly the one repository whose entries happen to be dated, which is
        # the maintainer's own, and was blind everywhere it shipped. An adopter hit it at 873
        # lines: over the archive line, told to archive, and told archiving was already done.
        #
        # SAY WHICH EMPTY THIS IS. "Nothing left to preserve" and "I cannot see anything in
        # this file" are opposite findings that produced identical output.
        if not entries:
            print("  NOTHING TO PRESERVE — and that is because this tool recognised NO")
            print("  entries in ai/MEMORY.md, not because everything is already archived.")
            print("")
            print("  It archives entries headed `## YYYY-MM-DD` or `### YYYY-MM-DD`.")
            print("  The shipped template has none: decisions are TABLE ROWS under")
            print("  '## Architecture decisions' and gotchas are LIST ITEMS under")
            print("  '## Known issues and gotchas'. Neither is an entry this can move.")
            print("")
            print("  So this file has no automated path back under its ceiling. Either:")
            print("    - head new decisions `### YYYY-MM-DD — <decision>` and they become")
            print("      archivable from then on, or")
            print("    - trim it by hand, moving full text to ai/MEMORY_ARCHIVE.md yourself.")
            return 0
        print(f"  all {len(entries)} recognised entry(ies) are already preserved in "
              f"ai/MEMORY_ARCHIVE.md")
        return 0
    print(f"  {len(todo)} entry(ies) to preserve into ai/MEMORY_ARCHIVE.md:")
    for head, body in todo:
        print(f"    {len(body):>3} lines  {head[3:][:60]}")
    if not apply_it:
        print("  (dry run — pass --apply to write. ai/MEMORY.md is never modified either way.)")
        return 0
    blocks = []
    for head, body in todo:
        blocks.append("\n".join(body))
    add = ("\n\n## Preserved from ai/MEMORY.md (full text; the live file keeps a stub)\n\n"
           + "\n\n".join(blocks) + "\n")
    with open(MEMORY_ARCHIVE, "a") as fh:
        fh.write(add)
    print(f"  wrote {len(todo)} entry(ies) to ai/MEMORY_ARCHIVE.md — ai/MEMORY.md UNCHANGED.")
    print("  Now trim each one there to decision + Revisit + the archive reference.")
    return 0


def backlog_preserve(apply_it):
    """Copy COMPLETED backlog items into ai/BACKLOG_ARCHIVE.md. Adds only; never removes.

    Same guarantee as memory_preserve, for the same reason. `- [x]` is unambiguous, so a
    full automatic move would be defensible here — but the value of one consistent rule
    across every ai/ file is worth more than saving one manual deletion, and "the tool only
    ever adds" is a property a reader can hold in their head for the whole toolchain rather
    than per command.

    Idempotent on the item text, so re-running never duplicates.
    """
    if not os.path.exists(BACKLOG):
        print("  no ai/BACKLOG.md — nothing to preserve")
        return 0
    lines = open(BACKLOG).read().split("\n")
    items, cur = [], None
    for ln in lines:
        if re.match(r"^- \[[xX]\] ", ln):
            cur = [ln]
            items.append(cur)
        elif cur is not None and (ln.startswith("  ") and ln.strip()):
            cur.append(ln)          # continuation of the same item
        else:
            cur = None
    existing = open(BACKLOG_ARCHIVE).read() if os.path.exists(BACKLOG_ARCHIVE) else ""
    todo = [it for it in items if it[0].strip() not in existing]
    if not items:
        print("  no completed items in ai/BACKLOG.md")
        return 0
    if not todo:
        print(f"  all {len(items)} completed item(s) already preserved in ai/BACKLOG_ARCHIVE.md")
        return 0
    print(f"  {len(todo)} completed item(s) to preserve into ai/BACKLOG_ARCHIVE.md:")
    for it in todo:
        print(f"    {it[0][:78]}")
    if not apply_it:
        print("  (dry run — pass --apply to write. ai/BACKLOG.md is never modified either way.)")
        return 0
    add = ("\n\n## Preserved from ai/BACKLOG.md (completed; the live file still holds them)\n\n"
           + "\n\n".join("\n".join(it) for it in todo) + "\n")
    with open(BACKLOG_ARCHIVE, "a") as fh:
        fh.write(add)
    print(f"  wrote {len(todo)} item(s) to ai/BACKLOG_ARCHIVE.md — ai/BACKLOG.md UNCHANGED.")
    print("  Now delete them from ai/BACKLOG.md; the archive holds the record.")
    return 0


def count_non_stub_entries():
    """How many MEMORY.md decision entries fail the stub bar. 0 when the file is absent.

    Separated from check_memory_format() so the size verdict can consult it without
    printing the report twice — the verdict needs the NUMBER, the reader needs the detail,
    and they are wanted at different moments.
    """
    if not os.path.exists(MEMORY):
        return 0
    n = 0
    for _head, body in memory_entries(open(MEMORY).read()):
        text = "\n".join(body)
        if (len(body) > STUB_MAX_LINES
                or not REVISIT_RE.search(text)
                or "MEMORY_ARCHIVE" not in text):
            n += 1
    return n


# THE WORST STATE SEEN THIS RUN, 0 clean / 1 over / 2 burst.
#
# check_size() RETURNS A BOOL and callers depend on it, so severity rides beside it rather
# than replacing it. It exists because setup.sh had to GREP THIS TOOL'S PROSE to find out
# what happened, and grepped for `[over]` — which does not match `[BURST]`, the worse state.
# A file 316 lines past its burst line therefore fell through to
# `[OK] ai/ files under their archive lines`, while a file 23 lines over the ARCHIVE line was
# reported. The check got quieter as the breach got worse (#227 family).
#
# One caller reading one integer cannot reproduce that, and a future third state raises the
# number rather than silently matching nothing.
WORST = 0


def check_size(name, limit, can_shrink=None, burst=None):
    """Report on a session-start file. ALWAYS returns False — nothing here blocks.

    `can_shrink` is how much archiving could still remove, when it is knowable: non-stub
    entries for MEMORY.md, rotatable entries for SESSION.md, completed items for
    BACKLOG.md. It does not change the verdict, because there is no verdict — it changes
    the ADVICE, which is the part that has to be worth reading.

    `burst` is the second, higher line. It changes the VOLUME of the report and nothing
    else: `[over]` means you crossed the archive line, which happens normally while you are
    writing decisions; `[BURST]` means the trim stopped happening. One number cannot say
    both, and a report that says the same thing in both cases is one people stop reading.
    """
    path = os.path.join(ROOT, "ai", name)
    if not os.path.exists(path):
        # A CEILING DECLARED FOR A FILE THAT IS NOT THERE IS A DECLARATION WITH NOTHING
        # BEHIND IT — and it used to print nothing at all.
        #
        # The scaffold ships all three of these as templates, so absence is a deliberate act:
        # someone deleted the file, renamed it, or adopted partially. Whichever it was, the
        # ceiling for it silently stopped being enforced and the report simply got one line
        # shorter. Nothing named the file, so there was no way to tell "under its limit" from
        # "not being checked at all" — the two states this whole tool exists to separate.
        #
        # Same argument as `scaffold:product-dir` failing on a missing directory rather than
        # skipping: otherwise renaming the target retires a check and discovery just gets
        # quieter. Advisory here, like everything else in this file — nothing blocks — but it
        # is said out loud, and it names the marker so the fix is one edit away.
        print(f"  [--  ] ai/{name}: declared in scaffold:ceilings, NOT PRESENT — not checked.")
        print("         The scaffold ships this file, so it was deleted, renamed, or never")
        print("         adopted. Restore it, or drop it from the scaffold:ceilings marker in")
        print("         ai/STANDARDS.md. An unchecked file is not a file under its limit.")
        return False
    _raw = open(path, encoding="utf-8", errors="replace").read()
    lines = len(_raw.splitlines())
    chars = len(_raw)
    over = lines > limit
    burst_hit = bool(burst) and lines > burst

    # ==== LINES ARE A PROXY FOR THE THING WE ACTUALLY PAY FOR, AND A BAD ONE ================
    #
    # These files are loaded at EVERY session start, so their cost is tokens, not rows. Line
    # density varies enough between repositories to make the line ceiling meaningless as a
    # cost control. Measured across this fleet on 2026-09-01:
    #
    #     localcoder              ai/MEMORY.md   236 lines   33,017 chars   ~8,250 tok
    #     ai-project-scaffold-dev ai/MEMORY.md   736 lines   50,489 chars  ~12,600 tok
    #
    # 236 lines costs two thirds of what 736 lines costs -- 140 chars/line against 69. Under
    # an 800-line ceiling, localcoder's file may grow to roughly 28,000 tokens and every
    # report will say it is comfortably under the line. Raising the LINE ceiling, which is
    # the obvious response to "we keep hitting it", makes a wrong measure wronger.
    #
    # ADVISORY-ONLY, AND DELIBERATELY WITH NO BURST. A new dimension that can fail a build
    # the day it ships would redden repositories on a number nobody has ever been shown. It
    # reports, it feeds WORST=1 (a GAP in preflight, never a failure), and whether it earns a
    # burst line is a decision for after some weeks of fleet data. Written down here so that
    # decision is made rather than forgotten.
    char_over = bool(CHAR_LIMITS.get(name)) and chars > CHAR_LIMITS[name]

    global WORST
    if burst_hit:
        WORST = max(WORST, 2)
        tag, where = "BURST", f"archive at {limit}, burst at {burst}"
    elif over:
        WORST = max(WORST, 1)
        tag, where = "over", f"archive at {limit}" + (f", burst at {burst}" if burst else "")
    elif char_over:
        WORST = max(WORST, 1)
        tag, where = "over", f"under {limit} lines but over {CHAR_LIMITS[name]} chars"
    else:
        # ==== REPORT THE CEILING THAT BINDS, NOT THE ONE THAT IS EASIER TO PRINT ===========
        #
        # This line used to name the LINE ceiling only. In a dense repository the CHARACTER
        # ceiling is the one that actually trips, so a reader watching "785 / 800 lines" read
        # that as comfortable while the file sat ~450 chars from an [over]. The information
        # existed and was only shown AFTER the surprise. Name both, and say which one binds.
        climit = CHAR_LIMITS.get(name)
        if climit and limit:
            if chars / climit >= lines / limit:
                where = f"chars bind: {climit - chars} left of {climit}; lines {lines}/{limit}"
            else:
                where = f"lines bind: {limit - lines} left of {limit}; chars {chars}/{climit}"
            if burst:
                where += f", burst at {burst}"
        else:
            where = f"archive at {limit}" + (f", burst at {burst}" if burst else "")
        tag = "ok  "
    print(f"  [{tag}] ai/{name}: {lines} lines, {chars} chars (~{chars // 4} tok) ({where})")
    if char_over and not over:
        print(f"         UNDER the line ceiling and OVER the size ceiling: {chars} chars is")
        print(f"         roughly {chars // 4} tokens, paid at every session start. Line count")
        print("         is a proxy for that cost and this file is unusually dense.")
        print("         Advisory only — no build fails on this.")
        return False
    if burst_hit:
        print(f"         {lines - burst} line(s) PAST THE BURST LINE — this is not 'a bit over',")
        print("         it is a trim that stopped happening. Still advisory: nothing here")
        print("         fails a build, and nothing is ever deleted.")
    if not over:
        return False

    # ==== #180 STOPPED IT RECURRING; IT NEVER TOLD THE PROJECTS ALREADY HOLDING IT ==========
    #
    # #180 was two live `scaffold:ceilings` markers: upstream's example sat at column 0, the
    # three-way merge carried it into projects that had their own, and `.search()` took the
    # first. Adopters ran whole releases on their own numbers purely because of line order.
    # The fix made upstream's example inline code, so a NEW occurrence is impossible.
    #
    # It did nothing for the projects already sitting on the old numbers, and there was no
    # way for them to find out. Reported from `Robiton/godsfall` on 2026-08-13 (#210), where
    # `ai/STANDARDS.md` DECLARES `BACKLOG.md=200` at line 440 and DOCUMENTS `600/700` at line
    # 485 — the machine reads one, the human reads the other, and they are 45 lines apart in
    # the file loaded into every session.
    #
    # FIRES ONLY WHEN IT IS ACTIONABLE. A project deliberately holding a low ceiling is making
    # a legitimate choice and must not be nagged for it — a warning that always fires is one
    # people filter out, which is this file's own founding argument. So it speaks only when
    # the file is ALREADY over, where the reader is being asked to do work and the stale
    # number may be the entire reason.
    _shipped = DEFAULT_LIMITS.get(name)
    if _shipped and limit < _shipped:
        print(f"         NOTE: this ceiling is {limit}; the scaffold now ships {_shipped}"
              f"{'/' + str(DEFAULT_BURSTS[name]) if name in DEFAULT_BURSTS else ''}.")
        print("         A marker written before 0.19.0 kept its own numbers through every")
        print("         upgrade — by design, since ai/STANDARDS.md is merged, not replaced.")
        print("         If the low number is deliberate, keep it. If it is left over, edit")
        print("         the scaffold:ceilings marker in ai/STANDARDS.md.")

    if can_shrink == 0:
        # Nothing archiving can do. Saying "archive this" here would be advice that cannot
        # be followed, which is how a report stops being read.
        print("         Nothing left to archive — this file is long because its remaining")
        print("         content is long. Shorten it, or raise the number in the")
        print("         scaffold:ceilings marker. Either is a deliberate choice.")
        return False
    if name == "MEMORY.md":
        print("         Preserve, then trim — nothing is deleted:")
        print("           tools/session_archive.py --memory-preserve --apply")
        print("         Then reduce each entry to decision + Revisit + the archive reference.")
    elif name == "BACKLOG.md":
        print("         Preserve, then delete — nothing is deleted for you:")
        print("           tools/session_archive.py --backlog-preserve --apply")
    elif name == "SESSION.md":
        print("         Rotate the oldest entries into ai/SESSION_ARCHIVE.md:")
        print("           tools/session_archive.py --apply")
    return False


def selftest():
    # ONE DECLARATION, AT THE TOP. Python requires `global` before the first USE in a
    # function, and two blocks below both touch WORST -- whichever is edited to come
    # first turns the other into a SyntaxError at import, i.e. the whole tool stops.
    global WORST
    """Prove the ceiling marker actually changes behaviour, in both directions.

    A config mechanism that is only ever exercised at its default value is indistinguishable
    from a hardcoded constant — and this project has now shipped four checks that passed
    because nothing tested the path where they should fail. So: a file that is OVER at 250
    must be UNDER at 350, and a broken marker must fall back rather than crash or silently
    take a wrong number.
    """
    import shutil
    import tempfile
    global ROOT
    real_root, failed = ROOT, 0

    def case(label, marker, lines, name, want_over, want_source_contains):
        nonlocal failed
        global ROOT
        tmp = tempfile.mkdtemp()
        try:
            os.makedirs(os.path.join(tmp, "ai"))
            std = "# Standards\n\n" + (marker + "\n" if marker is not None else "")
            open(os.path.join(tmp, "ai", "STANDARDS.md"), "w").write(std)
            open(os.path.join(tmp, "ai", name), "w").write("x\n" * lines)
            ROOT = tmp
            limits, bursts, source = load_limits()
            over = lines > limits[name]
            ok = (over == want_over) and (want_source_contains in source)
            failed += not ok
            print(f"  {'ok  ' if ok else 'FAIL'} {label:52} "
                  f"{name}={lines} vs {limits[name]} -> {'over' if over else 'ok'}")
        finally:
            ROOT = real_root
            shutil.rmtree(tmp, ignore_errors=True)

    print("session_archive selftest — the ceiling marker must be load-bearing")
    # DERIVED FROM THE DEFAULT, NOT A LITERAL. These fixtures hardcoded 400 as "over the
    # built-in ceiling", which was true at 350 and false the moment the default moved to
    # 600 — three cases went green while asserting the opposite of what they read. Exactly
    # the rotting-number class this release already deleted from the docs and from
    # localcoder_history's `total = 7`. A fixture that encodes a constant it does not own
    # is a second definition of that constant.
    OVER = DEFAULT_LIMITS["MEMORY.md"] + 50
    case("no marker: built-in default applies", None, OVER, "MEMORY.md",
         True, "built-in defaults")
    case("marker at the default: same verdict",
         "<!-- scaffold:ceilings MEMORY.md=250 -->", OVER, "MEMORY.md",
         True, "ai/STANDARDS.md")
    case("marker RAISED: the same file is now under",
         "<!-- scaffold:ceilings MEMORY.md=%d -->" % (OVER + 50), OVER, "MEMORY.md",
         False, "ai/STANDARDS.md")
    case("marker LOWERED: a file that was fine is now over",
         "<!-- scaffold:ceilings SESSION.md=50 -->", 80, "SESSION.md",
         True, "ai/STANDARDS.md")
    case("garbage marker falls back, does not crash",
         "<!-- scaffold:ceilings MEMORY.md=banana -->", OVER, "MEMORY.md",
         True, "unreadable")
    # A marker documented in the file it is read from must not count as a declaration —
    # the same trap that left localcoder_sync's fork escape hatch stuck open (2026-08-05).
    case("an INDENTED example is not a declaration",
         "    <!-- scaffold:ceilings MEMORY.md=%d -->" % (OVER + 50), OVER, "MEMORY.md",
         True, "built-in defaults")
    case("unknown key ignored, known keys still read",
         "<!-- scaffold:ceilings NOPE.md=9 MEMORY.md=%d -->" % (OVER + 50), OVER, "MEMORY.md",
         False, "ai/STANDARDS.md")
    # TWO MARKERS: FIRST WINS, AND IT IS A STATED RULE NOW RATHER THAN AN ACCIDENT (#180).
    # An adopter ended up with two after an upgrade merged upstream's example in beside
    # their own, and ran a release on ceilings that held only because of line order. The
    # second marker here would pass the file if it were the one read, so this case
    # distinguishes "first wins" from "last wins" rather than merely from "crashes".
    case("two markers: the FIRST is in force",
         "<!-- scaffold:ceilings MEMORY.md=%d -->\n\nprose\n\n"
         "<!-- scaffold:ceilings MEMORY.md=%d -->" % (OVER - 40, OVER + 500),
         OVER, "MEMORY.md", True, "ai/STANDARDS.md")
    # THE DENOMINATOR IS COUNTED, NOT DECLARED. It was `total = 8  # the case() block above;
    # the marker/burst blocks count separately`, and everything added since -- roughly twenty
    # assertions -- ran without appearing in it. The suite reported "31/31 passed" whether it
    # held 31 checks or 45, so the only visible effect of adding a case was that the number
    # could go DOWN. This file's own header records the same class ("a fixture that encodes a
    # constant it does not derive"); this is that constant, in the counter.
    total = 8  # the `case(...)` block above, which does not use mchk_pre
    def mchk_pre(label, cond, detail):
        nonlocal_total[0] += 1
        print(f"  {'ok  ' if cond else 'FAIL'} {label:52} {detail}")
        return 0 if cond else 1
    nonlocal_total = [0]

    # ---- warn/hard parsing, and the CONDITIONAL hard level ----------------------------
    # The conditional is the whole point of two levels: over-and-still-essays must block,
    # over-and-all-stubs must not, because no amount of archiving would help the second.
    # Both directions, or it is just a bigger number.
    import tempfile as _t2
    _oldroot = ROOT
    ptmp = _t2.mkdtemp()
    try:
        os.makedirs(os.path.join(ptmp, "ai"))
        def _marker(m):
            open(os.path.join(ptmp, "ai", "STANDARDS.md"), "w").write("# S\n\n" + m + "\n")
        globals()["ROOT"] = ptmp
        _marker("<!-- scaffold:ceilings MEMORY.md=250 -->")
        lim, _bursts, _src = load_limits()
        failed += mchk_pre("a bare number is the archive line", lim["MEMORY.md"] == 250,
                           str(lim["MEMORY.md"]))
        # 0.13.x wrote warn/hard pairs; they must keep loading, on the lower number.
        _marker("<!-- scaffold:ceilings MEMORY.md=250/350 -->")
        lim, _bursts, _src = load_limits()
        failed += mchk_pre("a 0.13.x warn/hard pair takes the LOWER", lim["MEMORY.md"] == 250,
                           str(lim["MEMORY.md"]))
        _marker("<!-- scaffold:ceilings MEMORY.md=350/250 -->")
        lim, _bursts, _src = load_limits()
        failed += mchk_pre("order within the pair does not matter", lim["MEMORY.md"] == 250,
                           str(lim["MEMORY.md"]))

        # THE BURST LINE. A pair now means archive/burst, and BOTH numbers have to survive
        # the parse — the old code took min() and threw the larger away, so a burst that
        # silently defaulted to nothing would look identical to one that worked.
        _marker("<!-- scaffold:ceilings MEMORY.md=600/700 -->")
        lim, bst, _src = load_limits()
        failed += mchk_pre("a pair keeps the LOWER as the archive line",
                           lim["MEMORY.md"] == 600, str(lim["MEMORY.md"]))
        failed += mchk_pre("a pair keeps the HIGHER as the burst line",
                           bst.get("MEMORY.md") == 700, str(bst.get("MEMORY.md")))
        _marker("<!-- scaffold:ceilings MEMORY.md=700/600 -->")
        lim, bst, _src = load_limits()
        failed += mchk_pre("burst order does not matter either",
                           (lim["MEMORY.md"], bst.get("MEMORY.md")) == (600, 700),
                           f'{lim["MEMORY.md"]}/{bst.get("MEMORY.md")}')
        # A SINGLE NUMBER MUST NOT INHERIT THE SHIPPED BURST. A project that declares
        # MEMORY.md=200 would otherwise be burst at 700 — a number it never chose and
        # cannot see in its own marker, reported as though it had set it.
        _marker("<!-- scaffold:ceilings MEMORY.md=200 -->")
        lim, bst, _src = load_limits()
        failed += mchk_pre("a declared single number clears the default burst",
                           bst.get("MEMORY.md") is None, str(bst.get("MEMORY.md")))
        # An equal pair is one number written twice, not a burst at the same height.
        _marker("<!-- scaffold:ceilings MEMORY.md=600/600 -->")
        lim, bst, _src = load_limits()
        failed += mchk_pre("an equal pair declares no burst",
                           bst.get("MEMORY.md") is None, str(bst.get("MEMORY.md")))
        # Untouched files keep the shipped default, marker or not.
        _marker("<!-- scaffold:ceilings SESSION.md=150 -->")
        lim, bst, _src = load_limits()
        failed += mchk_pre("an unmentioned file keeps its shipped burst",
                           bst.get("MEMORY.md") == 900, str(bst.get("MEMORY.md")))
        # The conditional, on a file deliberately over the hard level either way.
        open(os.path.join(ptmp, "ai", "MEMORY.md"), "w").write("x\n" * 400)  # vs explicit 250/350 markers below, not the default
        # NOTHING BLOCKS. That is the property, so it is the thing asserted.
        r1 = check_size("MEMORY.md", 250, can_shrink=3)
        failed += mchk_pre("over the line with work to do never blocks", r1 is False, "advisory")
        r2 = check_size("MEMORY.md", 250, can_shrink=0)
        failed += mchk_pre("over the line with nothing to archive never blocks",
                           r2 is False, "advisory")
        # #142: the SAME exemption must hold for SESSION.md, or --check and --all --check
        # return opposite verdicts for one file and CI is wired to the wrong one.
        r3 = check_size("SESSION.md", 50, can_shrink=2)
        failed += mchk_pre("SESSION over the line never blocks either", r3 is False, "advisory")
        r4 = check_size("BACKLOG.md", 50, can_shrink=4)
        failed += mchk_pre("BACKLOG over the line never blocks either", r4 is False, "advisory")
        total += 2
        # THE REPORT ITSELF, because the parse being right is not the same as the volume
        # changing — and the volume is the entire feature.
        import io as _io2
        import contextlib as _cl2
        _buf = _io2.StringIO()
        with _cl2.redirect_stdout(_buf):
            rb1 = check_size("MEMORY.md", 10, can_shrink=3, burst=20)
        _out = _buf.getvalue()
        failed += mchk_pre("past the burst line reports [BURST]", "[BURST]" in _out, _out.strip()[:60])
        failed += mchk_pre("burst still returns False (nothing blocks)", rb1 is False, str(rb1))
        _buf = _io2.StringIO()
        with _cl2.redirect_stdout(_buf):
            check_size("MEMORY.md", 10, can_shrink=3, burst=9999)
        _out = _buf.getvalue()
        failed += mchk_pre("over but under burst stays [over]",
                           "[over]" in _out and "[BURST]" not in _out, _out.strip()[:60])

        # ---- THE SHIPPED TEMPLATE MUST BE ARCHIVABLE BY THIS TOOL -----------------------
        #
        # THE CASE THAT WAS MISSING FOR THE WHOLE LIFE OF THIS FILE. Every case here builds
        # its own fixture with `## YYYY-MM-DD` headings -- the format the tool was designed
        # around -- so they all passed while the format the scaffold actually SHIPS produced
        # zero recognised entries. memory_preserve() then reported "every non-stub entry is
        # already preserved in ai/MEMORY_ARCHIVE.md", about a file that in most repos does
        # not exist, over an empty set.
        #
        # Measured 2026-09-01, `## YYYY-MM-DD` headings in ai/MEMORY.md across this fleet:
        # ai-project-scaffold-dev 78, localcoder 0, control 0, ai-project-scaffold 0. It
        # worked in the maintainer's own repo and nowhere it shipped. An adopter hit it at
        # 873 lines: over the line, told to archive, and told archiving was already done.
        #
        # So this case reads THE REAL ai/MEMORY.md TEMPLATE off disk rather than a fixture.
        # A fixture would encode the format I believe I ship, which is exactly the belief
        # that was wrong.
        # THE INVARIANT IS "TEMPLATE AND PARSER AGREE", not "the template has entries" -- a
        # template's heading is a PLACEHOLDER and cannot be a real date. So: the template must
        # teach a dated heading, and substituting a real date into the shape it teaches must
        # produce something this parser recognises. That is the agreement that was absent.
        _mp_probe = os.path.join(ptmp, "ai", "MEMORY_PROBE.md")
        # ---- ARCHIVABILITY IS REPORTED, ON FIXTURES, NOT ON THIS REPO'S OWN FILE --------
        # 0.17.0 asserted this against the real ai/MEMORY.md inside selftest(), which made a
        # SELFTEST fail on the CONTENTS of somebody's memory file -- red on arrival for every
        # adopter whose file predates the new template (and ai/MEMORY.md is never touched by
        # the upgrade, so that is all of them). A selftest asserts the tool; the repository
        # condition belongs in --check. Three fixtures, one per shape.
        for _label, _body, _want in (
                ("a file with no dated entry and no placeholder is flagged",
                 "# M\n\n## Architecture decisions\n\nprose\n", True),
                ("a file with real dated entries is not flagged",
                 "# M\n\n### 2026-01-01 — a decision\n\ndetail\n", False),
                ("a file carrying the template placeholder is not flagged",
                 "# M\n\n### YYYY-MM-DD — [the decision]\n\ndetail\n", False)):
            open(_mp_probe, "w").write(_body)
            _old = globals()["MEMORY"]
            globals()["MEMORY"] = _mp_probe
            _buf = _io2.StringIO()
            with _cl2.redirect_stdout(_buf):
                report_memory_archivability()
            globals()["MEMORY"] = _old
            _flagged = "NO entry this tool can archive" in _buf.getvalue()
            failed += mchk_pre(_label, _flagged == _want, f"flagged={_flagged}")

        # AND AN EMPTY RECOGNISED SET MUST NOT REPORT SUCCESS. The distinct halves are
        # "nothing left to preserve" and "I could not see anything here", and they printed
        # identically. Asserted on prose with no dated heading at all.
        _mp = os.path.join(ptmp, "ai", "MEMORY.md")
        _oldmem = globals()["MEMORY"]
        _oldarc = globals()["MEMORY_ARCHIVE"]
        globals()["MEMORY"] = _mp
        globals()["MEMORY_ARCHIVE"] = os.path.join(ptmp, "ai", "MEMORY_ARCHIVE.md")
        try:
            open(_mp, "w").write("# Memory\n\n## Architecture decisions\n\n"
                                 + "prose that is not an entry\n" * 40)
            _buf = _io2.StringIO()
            with _cl2.redirect_stdout(_buf):
                memory_preserve(False)
            _out = _buf.getvalue()
            failed += mchk_pre("0 recognised entries is NOT reported as already preserved",
                               "recognised NO" in _out and "already preserved" not in _out,
                               _out.strip().split("\n")[0][:58])
            # ...and the dated form still works, or the fix above is just a louder failure.
            open(_mp, "w").write("# Memory\n\n### 2026-08-01 — a decision\n\n"
                                 + "detail\n" * 30)
            _buf = _io2.StringIO()
            with _cl2.redirect_stdout(_buf):
                memory_preserve(False)
            _out = _buf.getvalue()
            failed += mchk_pre("a dated ### entry IS recognised and offered for preserving",
                               "to preserve into" in _out, _out.strip().split("\n")[0][:58])
        finally:
            globals()["MEMORY"] = _oldmem
            globals()["MEMORY_ARCHIVE"] = _oldarc

        # ---- THE WORSE STATE MUST BE STRICTLY LOUDER, NOT MERELY PRESENT -----------------
        #
        # setup.sh grepped this tool's output for `[over]` and therefore MISSED `[BURST]`,
        # so a file 316 lines past its burst line printed `[OK] ai/ files under their
        # archive lines` while a file 23 lines over the ARCHIVE line was reported. The check
        # got quieter as the breach got worse.
        #
        # A CASE ASSERTING "BURST WARNS" WOULD HAVE PASSED THE WHOLE TIME, because check_size
        # always printed the [BURST] line — the loss was one caller down, in what it did with
        # it. So this asserts the ORDERING of the machine-readable severity, which is what a
        # caller can actually branch on, and it asserts all three rungs: a clean file, an
        # over file and a burst file must produce three DIFFERENT answers, strictly ordered.
        _sev = {}
        for _label, _n, _lim, _burst in (("clean", 5, 100, 200),
                                         ("over", 150, 100, 200),
                                         ("burst", 250, 100, 200)):
            open(os.path.join(ptmp, "ai", "SESSION.md"), "w").write("x\n" * _n)
            WORST = 0
            _buf = _io2.StringIO()
            with _cl2.redirect_stdout(_buf):
                check_size("SESSION.md", _lim, can_shrink=0, burst=_burst)
            _sev[_label] = WORST
        WORST = 0
        failed += mchk_pre("clean < over < burst, strictly (the severity a caller branches on)",
                           _sev["clean"] == 0 and _sev["over"] == 1 and _sev["burst"] == 2
                           and _sev["clean"] < _sev["over"] < _sev["burst"],
                           "clean=%s over=%s burst=%s" % (_sev["clean"], _sev["over"], _sev["burst"]))

        # ---- A CEILING LEFT BEHIND BY #180 SAYS SO, AND ONLY WHEN IT MATTERS (#210) -------
        #
        # Reported from Robiton/godsfall: ai/STANDARDS.md DECLARES BACKLOG.md=200 and
        # DOCUMENTS 600/700 forty-five lines further down. #180 stopped a NEW occurrence and
        # left every existing one in place with no way to notice.
        #
        # Both directions, because the note is only worth having if it stays quiet otherwise:
        # a project deliberately holding a low ceiling must not be nagged, and this file's own
        # founding argument is that a warning which always fires is one people filter out.
        # THE FILE HAS TO EXIST OR check_size RETURNS AT THE FIRST LINE. The BACKLOG case
        # above (r4) asserts `is False`, which a non-existent file satisfies without the
        # function doing anything — an assertion that cannot fail for the reason it names.
        open(os.path.join(ptmp, "ai", "BACKLOG.md"), "w").write("x\n" * 400)
        _buf = _io2.StringIO()
        with _cl2.redirect_stdout(_buf):
            check_size("BACKLOG.md", 200, can_shrink=0, burst=None)
        _out = _buf.getvalue()
        failed += mchk_pre("a ceiling below the shipped default names both numbers",
                           "the scaffold now ships 800" in _out and "200" in _out,
                           _out.strip().splitlines()[-1][:58] if _out.strip() else "(silent)")
        # AT the shipped default: nothing to say. This is the case that keeps it readable.
        _buf = _io2.StringIO()
        with _cl2.redirect_stdout(_buf):
            check_size("BACKLOG.md", 800, can_shrink=0, burst=900)
        _out = _buf.getvalue()
        failed += mchk_pre("a ceiling AT the shipped default says nothing about it",
                           "the scaffold now ships" not in _out, _out.strip()[:58])
        # ABOVE it — a project that deliberately raised its own — is also silent. Reporting
        # here would be nagging someone for making the choice the note exists to invite.
        _buf = _io2.StringIO()
        with _cl2.redirect_stdout(_buf):
            check_size("BACKLOG.md", 900, can_shrink=0, burst=1000)
        _out = _buf.getvalue()
        failed += mchk_pre("a ceiling ABOVE the shipped default is not nagged",
                           "the scaffold now ships" not in _out, _out.strip()[:58])
        # AND IT MUST STAY SILENT WHEN THE FILE IS UNDER ITS LINE, whatever the ceiling. The
        # note is advice attached to work the reader is already being asked to do; detached
        # from that it is a nag on every session of every project that never upgraded.
        _buf = _io2.StringIO()
        with _cl2.redirect_stdout(_buf):
            check_size("MEMORY.md", 99999, can_shrink=0)
        _out = _buf.getvalue()
        failed += mchk_pre("under the line, a low ceiling is never mentioned",
                           "the scaffold now ships" not in _out, _out.strip()[:58])

        # ---- A DECLARED CEILING WITH NO FILE BEHIND IT SAYS SO -------------------------
        #
        # The production loop iterates the DECLARED ceilings, so a marker naming a file that
        # is not there produced no output whatever — the report was one line shorter and
        # nothing said which line or why. "Under its limit" and "not checked at all" are the
        # two states this tool exists to separate, and they printed identically.
        #
        # Raised by the owner asking whether the scaffold needs to ship ai/BACKLOG.md. It
        # already does; the gap was what happens when an adopter removes it.
        _buf = _io2.StringIO()
        with _cl2.redirect_stdout(_buf):
            check_size("NOSUCH.md", 100, can_shrink=0)
        _out = _buf.getvalue()
        failed += mchk_pre("a declared file that is absent is reported, not skipped",
                           "NOT PRESENT" in _out and "NOSUCH.md" in _out,
                           _out.strip()[:58] if _out.strip() else "(silent)")
        # AND IT STILL NEVER BLOCKS. Every other path here is advisory; a new one that
        # returned True would fail builds on a file somebody deliberately removed.
        failed += mchk_pre("an absent declared file still does not block",
                           check_size("NOSUCH.md", 100, can_shrink=0) is False, "advisory")
        total += 6

        r5 = check_size("MEMORY.md", 9999, can_shrink=3)
        failed += mchk_pre("under the line is quiet and passes", r5 is False, "ok")
        total += 6
    finally:
        globals()["ROOT"] = _oldroot
        shutil.rmtree(ptmp, ignore_errors=True)

    # ---- MEMORY stub format + preserve -------------------------------------------------
    # BOTH DIRECTIONS, and the safety property ASSERTED rather than assumed: the entire
    # argument for automating this half is that ai/MEMORY.md is never written to.
    import tempfile as _tf
    global MEMORY, MEMORY_ARCHIVE
    _m, _a = MEMORY, MEMORY_ARCHIVE
    mtmp = _tf.mkdtemp()
    try:
        MEMORY = os.path.join(mtmp, "MEMORY.md")
        MEMORY_ARCHIVE = os.path.join(mtmp, "MEMORY_ARCHIVE.md")
        stub = ("## 2026-01-01 — a proper stub\n\n"
                "- Decided X, because the measurement said Y.\n"
                "- Revisit: if Z changes -> undo it.\n"
                "- Full rationale: `ai/MEMORY_ARCHIVE.md`\n")
        fat = "## 2026-01-02 — an essay\n\n" + "".join(f"- line {i}\n" for i in range(12))
        # THE FORM PEOPLE ACTUALLY WRITE (#284). Every other lead-in in a MEMORY.md entry is
        # bolded, so `- **Revisit:**` is the house style — and the old pattern demanded the
        # word immediately after the bullet, so it matched none of them. Measured in
        # ai-project-scaffold-dev: 10 triggers present, 10 bolded, 0 detected. The check
        # reported "no Revisit trigger" on every entry including the ones that had one.
        bold = ("## 2026-01-03 — a stub whose trigger is bolded\n\n"
                "- Decided X, because the measurement said Y.\n"
                "- **Revisit:** if Z changes -> undo it.\n"
                "- Full rationale: `ai/MEMORY_ARCHIVE.md`\n")
        # A structural section is not a DECISION and must never be counted or preserved.
        skel = "## Project overview\n\n" + "".join(f"prose {i}\n" for i in range(20))
        open(MEMORY, "w").write("# Project Memory\n\n" + skel + "\n" + stub + "\n"
                                + bold + "\n" + fat)

        def mchk(label, cond, detail):
            print(f"  {'ok  ' if cond else 'FAIL'} {label:52} {detail}")
            return 0 if cond else 1

        ents = memory_entries(open(MEMORY).read())
        failed += mchk("structural sections are not decisions", len(ents) == 3, f"{len(ents)} dated")
        bad = check_memory_format()
        failed += mchk("a stub passes, an essay is flagged", bad == 1, f"{bad} flagged")
        # THE BOLDED TRIGGER IS THE ONE THAT WAS INVISIBLE (#284). Asserted as its own case
        # rather than folded into the line above: "1 flagged" would still be true if the
        # bolded stub were flagged and the essay were not.
        failed += mchk("a BOLDED Revisit trigger counts as one",
                       REVISIT_RE.search("- **Revisit:** if Z changes") is not None
                       and REVISIT_RE.search("- Revisiting the plan") is None,
                       "house style detected; 'Revisiting' still is not a trigger")
        before = open(MEMORY).read()
        memory_preserve(True)
        same = open(MEMORY).read() == before
        failed += mchk("--memory-preserve NEVER modifies MEMORY.md", same,
                       "unchanged" if same else "MODIFIED")
        arc = open(MEMORY_ARCHIVE).read()
        failed += mchk("only the non-stub entry is preserved",
                       "an essay" in arc and "a proper stub" not in arc
                       and "trigger is bolded" not in arc
                       and "Project overview" not in arc,
                       f"{len(arc.splitlines())} archive line(s)")
        n1 = len(open(MEMORY_ARCHIVE).read())
        memory_preserve(True)
        failed += mchk("re-running preserves nothing twice",
                       len(open(MEMORY_ARCHIVE).read()) == n1, "idempotent")
        total += 6
    finally:
        MEMORY, MEMORY_ARCHIVE = _m, _a
        shutil.rmtree(mtmp, ignore_errors=True)

    # ---- BACKLOG preserve, and SESSION rotation is LOSSLESS -----------------------------
    # The session rotation is the one path in this tool that genuinely MOVES text, so it is
    # the one that has to be proven not to lose any: archived + remaining must equal what
    # went in. "It only adds" covers the other two by construction; this one needs a test.
    import tempfile as _t3
    _r3 = ROOT
    btmp = _t3.mkdtemp()
    try:
        os.makedirs(os.path.join(btmp, "ai"))
        globals()["ROOT"] = btmp
        global BACKLOG, BACKLOG_ARCHIVE
        _b, _ba = BACKLOG, BACKLOG_ARCHIVE
        BACKLOG = os.path.join(btmp, "ai", "BACKLOG.md")
        BACKLOG_ARCHIVE = os.path.join(btmp, "ai", "BACKLOG_ARCHIVE.md")
        open(BACKLOG, "w").write(
            "# Backlog\n\n- [x] done one\n  with a continuation line\n"
            "- [ ] still open\n- [x] done two\n")
        before_b = open(BACKLOG).read()
        backlog_preserve(True)
        failed += mchk_pre("--backlog-preserve NEVER modifies BACKLOG.md",
                           open(BACKLOG).read() == before_b, "unchanged")
        arc_b = open(BACKLOG_ARCHIVE).read()
        failed += mchk_pre("only completed items are preserved",
                           "done one" in arc_b and "done two" in arc_b
                           and "still open" not in arc_b,
                           "2 of 3")
        failed += mchk_pre("a continuation line travels with its item",
                           "with a continuation line" in arc_b, "kept")
        n_b = len(open(BACKLOG_ARCHIVE).read())
        backlog_preserve(True)
        failed += mchk_pre("re-running preserves nothing twice",
                           len(open(BACKLOG_ARCHIVE).read()) == n_b, "idempotent")
        total += 4
    finally:
        BACKLOG, BACKLOG_ARCHIVE = _b, _ba
        globals()["ROOT"] = _r3
        shutil.rmtree(btmp, ignore_errors=True)

    # ---- WHAT COUNTS AS AN ENTRY (#318) -------------------------------------------------
    # Driven through plan_rotation(), the function main() actually calls, on a fixture
    # carrying all four heading shapes at once: two day-dated entries, one MONTH-dated entry,
    # one standing pointer and one template block. Asserting on is_entry() alone would prove
    # the predicate and not the rotation, and the rotation is where the content was lost.
    _fx = (
        "# Session Log\n\n_preamble that must never move_\n\n"
        "## 2026-09-22 — newest\nbody newest\n\n"
        "## Delegated drafts — the live table is NOT here\nthe standing pointer\n\n"
        "## 2026-09-21 — middle\nbody middle\n\n"
        "## 2026-03 (multiple sessions) — month-dated, and REAL\nbody month\n\n"
        "## Template — copy this block for each new session\ntemplate body\n")
    _kept, _rot, _proj, _real, _skel = plan_rotation(_fx, keep=1, max_lines=10_000)
    _keptj, _rotj = "".join(_kept), "".join(_rot)

    failed += mchk_pre("a month-dated heading is a REAL session entry",
                       len(_real) == 3 and "month-dated, and REAL" in "".join(_real),
                       f"{len(_real)} entries")
    failed += mchk_pre("a standing section is NOT a session entry",
                       len(_skel) == 2 and any("live table is NOT here" in e for e in _skel),
                       f"{len(_skel)} skeleton")
    failed += mchk_pre("a standing section is never rotated out",
                       "live table is NOT here" in _keptj
                       and "live table is NOT here" not in _rotj, "stays")
    failed += mchk_pre("a template block is still never rotated out",
                       "Template — copy this block" in _keptj
                       and "Template — copy this block" not in _rotj, "stays")
    failed += mchk_pre("older real entries DO rotate",
                       "body middle" in _rotj and "body month" in _rotj
                       and "body middle" not in _keptj, "2 moved")
    failed += mchk_pre("skeleton keeps its place in file order",
                       _kept.index(next(e for e in _kept if "live table" in e))
                       > _kept.index(next(e for e in _kept if "newest" in e)), "after newest")
    # The preamble is not part of `kept`; prove main()'s reassembly still leads with it.
    failed += mchk_pre("the preamble is never an entry and never rotates",
                       "_preamble that must never move_" not in _keptj
                       and "_preamble that must never move_" not in _rotj, "preamble")
    nonlocal_total[0] += 7

    # --check --exit-status ON THE SINGLE-FILE PATH, END TO END. It exited 0 on a file past
    # its burst line because only --all honoured the flag, and every case above calls
    # functions rather than main(), so none could see it. A real subprocess, with the tool
    # copied in, because ROOT comes from the tool's own location.
    import subprocess as _sp
    _ex = tempfile.mkdtemp()
    try:
        os.makedirs(os.path.join(_ex, "ai"))
        os.makedirs(os.path.join(_ex, "tools"))
        shutil.copy(os.path.abspath(__file__), os.path.join(_ex, "tools", "session_archive.py"))
        _lim = DEFAULT_LIMITS["SESSION.md"]
        _bst = DEFAULT_BURSTS.get("SESSION.md") or (_lim + 100)

        def _rc(n_lines, *flags, entries=8):
            body = ["# Session Log", ""]
            per = max(1, n_lines // entries)
            for d in range(1, entries + 1):
                body.append(f"## 2026-09-{d:02d} — t — t — entry {d}")
                body += ["x"] * (per - 1)
            open(os.path.join(_ex, "ai", "SESSION.md"), "w").write("\n".join(body[:n_lines]) + "\n")
            return _sp.run([sys.executable, os.path.join(_ex, "tools", "session_archive.py"),
                            "--check", *flags], capture_output=True).returncode
        # 3 entries for the clean case: under BOTH ceilings. 8 short entries is over the
        # 5-entry count, a real `over` -- the first draft of this case asserted 0 there.
        for _label, _n, _ents, _flags, _want in (
                ("--exit-status past the burst line exits 2", _bst + 40, 8, ("--exit-status",), 2),
                ("--exit-status over the archive line exits 1", _lim + 10, 8, ("--exit-status",), 1),
                ("--exit-status under both ceilings exits 0", _lim // 3, 3, ("--exit-status",), 0),
                ("plain --check stays advisory (0) past burst", _bst + 40, 8, (), 0)):
            _got = _rc(_n, *_flags, entries=_ents)
            ok = _got == _want
            failed += not ok
            print(f"  {'ok  ' if ok else 'FAIL'} {_label:52} rc={_got}, want {_want}")
    finally:
        shutil.rmtree(_ex, ignore_errors=True)
    nonlocal_total[0] += 4

    total += nonlocal_total[0]
    print(f"\n  {total - failed}/{total} passed")
    return 1 if failed else 0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--keep", type=int, default=5, help="sessions to retain (default 5)")
    ap.add_argument("--max-lines", type=int, default=None,
                    help="line ceiling for SESSION.md (default: from ai/STANDARDS.md)")
    ap.add_argument("--apply", action="store_true", help="write the rotation")
    ap.add_argument("--check", action="store_true",
                    help="report only, never rotate. Always exits 0 — archiving is advisory.")
    ap.add_argument("--exit-status", action="store_true",
                    help="with --check, exit 0 clean / 1 over the archive line / 2 past the "
                         "BURST line, so a caller can branch on the RESULT instead of "
                         "grepping this tool's prose for a literal. Off by default: --check "
                         "is documented as always exiting 0 and callers rely on it.")
    ap.add_argument("--all", action="store_true",
                    help="check every ai/ file with a stated ceiling, not just SESSION.md")
    ap.add_argument("--memory-preserve", action="store_true",
                    help="copy non-stub MEMORY.md entries into MEMORY_ARCHIVE.md (adds "
                         "only; MEMORY.md is never modified). Use with --apply to write.")
    ap.add_argument("--backlog-preserve", action="store_true",
                    help="copy completed BACKLOG.md items into BACKLOG_ARCHIVE.md (adds "
                         "only; BACKLOG.md is never modified). Use with --apply to write.")
    ap.add_argument("--session-head", nargs="?", const=SESSION_HEAD_DEFAULT, type=int,
                    metavar="N",
                    help="print the preamble plus the newest N entries of ai/SESSION.md "
                         f"(default {SESSION_HEAD_DEFAULT}). This is what the load order "
                         "asks a session to read; the rest stays in the file.")
    ap.add_argument("--bytes", action="store_true",
                    help="--session-head only: print the byte count instead of the text")
    ap.add_argument("--selftest", action="store_true",
                    help="prove the ceiling marker changes behaviour in both directions")
    args = ap.parse_args()
    if args.selftest:
        return selftest()
    if args.session_head is not None:
        return session_head(args.session_head, bytes_only=args.bytes)
    if args.memory_preserve:
        return memory_preserve(args.apply)
    if args.backlog_preserve:
        return backlog_preserve(args.apply)
    limits, bursts, source = load_limits()
    # A sentinel default rather than a literal 150: with a hardcoded default there is no
    # way to tell "the user asked for 150" from "nobody asked", so an explicit flag and
    # the file's own ceiling could not both be honoured.
    # REMEMBER WHETHER A HUMAN ASKED, BEFORE THE DEFAULT ERASES THE ANSWER. The sentinel
    # exists to tell "the caller wants 150" from "nobody said"; reading it after defaulting
    # made SESSION.md look like an explicit override on every run and silently dropped its
    # warn level. Set outside the branch, or the flag's own path never assigns it.
    explicit_max = args.max_lines is not None
    if args.max_lines is None:
        args.max_lines = limits["SESSION.md"]

    if args.all and args.apply:
        # `--all` reports; it has never rotated anything. Accepting --apply alongside it
        # and doing nothing is the "flag that appears to work" failure this repo has now
        # hit three times (localcoder's --check after the task, its -h, the installer's
        # unknown flags). Refuse, and say which command actually rotates.
        print("session_archive: --all is report-only — it cannot rotate.\n"
              "  SESSION.md rotates mechanically:  tools/session_archive.py --apply\n"
              "  BACKLOG.md is swept at each release, by hand (ai/STANDARDS.md -> Archiving).\n"
              "  MEMORY.md is never automated: deciding what is superseded is a human call.",
              file=sys.stderr)
        return 2

    if args.all:
        # NAME THE SOURCE. A ceiling that silently came from somewhere other than where
        # the reader thinks is how "I raised it and nothing changed" happens — and the
        # fallback path is invisible by design, so it has to announce itself here.
        print(f"ai/ session-start files against the ceilings in {source}:")
        # Counted BEFORE the size verdicts, because MEMORY.md's hard level is conditional
        # on it. quiet=True so the detail prints once, below, and not twice.
        non_stub = count_non_stub_entries()
        for name, limit in limits.items():
            # An explicit --max-lines still wins for SESSION.md; it predates the marker
            # and CI/sync-check pass it. It sets BOTH levels — a caller asking for one
            # number means one number.
            lim = args.max_lines if (name == "SESSION.md" and explicit_max) else limit
            # The SAME exemption in both modes. Whatever archiving could still remove:
            # non-stub entries for MEMORY.md, rotatable entries for SESSION.md.
            # ALL THREE get a supplier, so the advice is right in every case. BACKLOG.md
            # had none, which is why it was the one file that still failed unconditionally.
            if name == "MEMORY.md":
                shrink = non_stub
            elif name == "SESSION.md":
                shrink = rotatable_sessions()
            else:
                shrink = completed_backlog_items()
            check_size(name, lim, shrink, burst=bursts.get(name))
        print("  (advisory — archiving never fails the build)")
        # The format report rides with --all because a line count alone cannot tell
        # "too small a ceiling" from "no stubs written", and that ambiguity is what has
        # moved this project's MEMORY ceiling three times. It never changes the exit code.
        print("")
        check_memory_format()
        # WHETHER THE FILE IS ARCHIVABLE AT ALL, which is upstream of whether its entries are
        # stubs. check_memory_format() reports on entries it RECOGNISES; if it recognises
        # none it has nothing to say, and said nothing -- so the file with no automated path
        # back under its ceiling was the one this report was quietest about.
        report_memory_archivability()
        # ALWAYS 0 UNLESS ASKED OTHERWISE. Length is a housekeeping matter, not a build
        # failure — but a caller that wants to react to it should not have to parse prose to
        # find out what happened, which is the defect this flag exists to end.
        return WORST if args.exit_status else 0

    if not os.path.exists(SESSION):
        print("session_archive: no ai/SESSION.md")
        return 0

    text = open(SESSION).read()
    lines = len(text.splitlines())
    preamble, entries = split_sessions(text)
    # Skeleton is structure, not history: never counted, never rotated (#318).
    real = [e for e in entries if is_entry(e)]
    skeleton = [e for e in entries if not is_entry(e)]
    templates = sum(1 for e in skeleton if is_template(e))
    standing = len(skeleton) - templates
    over = lines > args.max_lines or len(real) > args.keep

    print(f"ai/SESSION.md: {lines} lines, {len(real)} session entries "
          f"(ceiling {args.max_lines} lines / {args.keep} entries, from {source})"
          + (f" [+{templates} template block(s), not counted]" if templates else "")
          + (f" [+{standing} standing section(s), not counted and never archived]"
             if standing else ""))

    if not over:
        print("  within ceiling — nothing to do")
        return 0

    # --exit-status ON THE SINGLE-FILE PATH. It used to be honoured by --all only, so
    # `--check --exit-status` exited 0 on a SESSION.md 170 lines past its burst line while
    # --help promised 1/2 (research-spike audit, 2026-10-05). Same rungs as check_size():
    # 2 past the burst line, 1 over the archive line or the entry count. An explicit
    # --max-lines sets both levels, so it has no separate burst.
    _burst = None if explicit_max else bursts.get("SESSION.md")
    over_rc = 2 if (_burst and lines > _burst) else 1

    # Two independent ceilings, and the entry count alone does not satisfy the line one.
    # A file at exactly `keep` entries but over the line ceiling used to report
    # "OVER CEILING: 0 entries would move" and still exit non-zero — so CI failed
    # permanently with no action that could fix it. plan_rotation() sheds the oldest entries
    # until the file is actually under BOTH ceilings, keeping at least one.
    keep, rotate, projected, _real, _skel = plan_rotation(text, args.keep, args.max_lines)
    keep_real = [e for e in keep if is_entry(e)]

    if not rotate:
        # Over on lines with a single entry left: archiving cannot help, and failing
        # CI over one long session entry would be noise. Say so and pass.
        print(f"  {lines} lines is over the {args.max_lines}-line ceiling, but only "
              f"{len(real)} entry(ies) remain — nothing left to archive.")
        print("  Shorten the entry itself, or raise --max-lines for this project.")
        return over_rc if (args.check and args.exit_status) else 0

    print(f"  OVER CEILING: {len(rotate)} entry(ies) would move to ai/SESSION_ARCHIVE.md"
          f" (leaving {len(keep_real)} entries, ~{projected} lines)")
    for e in rotate:
        first = e.splitlines()[0][:88]
        print(f"    - {first}")

    if args.check:
        # ADVISORY, like every other size report here. This used to return 1 so CI could
        # fail on it, and that is the half of the design that kept catching people
        # mid-thought. The ceiling still matters — these files are read at every session
        # start — but the answer is a report you can act on in one command, not a red
        # build. See DEFAULT_LIMITS for the full reasoning and the known cost.
        # Advisory unless the caller ASKED for the result as a code (--exit-status).
        return over_rc if args.exit_status else 0
    if not args.apply:
        print("\n  (dry run — pass --apply to rotate)")
        return 0

    default_header = (
        "# Session Archive\n\n"
        "_Older entries rotated out of `ai/SESSION.md` by `tools/session_archive.py`._\n"
        "_Newest first. Nothing here is deleted — this is the long memory._\n"
        "_Not loaded at session start; read on demand when older context is needed._\n\n---\n")
    # PRESERVE an existing archive's own preamble. Overwriting it with our default
    # silently discarded project-authored guidance the first time this ran on a real
    # repo. The default header is for CREATING the file, not for re-stamping it.
    header, existing = default_header, ""
    if os.path.exists(ARCHIVE):
        prior = open(ARCHIVE).read()
        if "---\n" in prior:
            head, existing = prior.split("---\n", 1)
            header = head + "---\n"
        else:
            existing = prior

    # ROTATING A SESSION LOG MUST NOT TURN A GREEN REPOSITORY RED.
    #
    # Session entries quote the commands that were run. Once rotated, those commands sit in
    # SESSION_ARCHIVE.md naming tools that have since been renamed or retired --
    # tools/stale_path_scan.sh reads them as live instructions and fails the build. Measured
    # here 2026-09-01: one rotation moved 11 entries and produced three findings
    # (tools/list, tools/install_ollama_service.sh, tools/localcoder), turning a passing
    # repo red as the direct result of running the archiver the gate had just recommended.
    #
    # THE MECHANISM ALREADY EXISTS -- `scaffold:file-is-historical` is stale_path_scan's own
    # whole-file exemption, documented for files that "record dead commands". An archive is
    # the definitive such file. It was simply never applied, because nothing writes it.
    #
    # STAMPED WITH A DATE AND A REASON, because that scanner separately reports exemptions
    # that carry neither: "an exemption without one cannot be told apart from a line somebody
    # added to make a build go green." This one has both, and is true.
    if "scaffold:file-is-historical" not in header:
        header = header.rstrip("\n").rstrip("-").rstrip("\n")
        header += (
            "\n\n<!-- scaffold:file-is-historical %s this is rotated history: the commands in "
            "it were run in the past and are not instructions to anyone -->\n\n---\n"
            % _today())
    with open(ARCHIVE, "w") as fh:
        fh.write(header + "\n" + "".join(rotate).rstrip() + "\n" + existing)
    with open(SESSION, "w") as fh:
        fh.write(preamble + "".join(keep).rstrip() + "\n")

    print(f"\n  rotated {len(rotate)} entry(ies) -> ai/SESSION_ARCHIVE.md")
    print(f"  ai/SESSION.md now {len(open(SESSION).read().splitlines())} lines")
    return 0


if __name__ == "__main__":
    sys.exit(main())
