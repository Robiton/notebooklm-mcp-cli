#!/usr/bin/env python3
# Project:  ai-project-scaffold
# File:     tools/close_out.py
# Modified: 2026-09-06
# Version:  0.9.1.20260906.0534
# Purpose:  Record what happened to a delegated draft, in ai/SESSION.md, after the gates ran.
# Changelog:
#   2026-09-06 v0.9.1.20260906.0534 — --auto-memory-status NAMES THE REMEDY (#300). 0.9.0
#                        counted unpromoted notes and told a reader a rename would strand
#                        them, which is a diagnosis with no next step. Both questions #300
#                        recorded as undeterminable turn out to be answered in the Claude
#                        Code documentation: `autoMemoryDirectory` (settings.json, ANY
#                        scope) relocates the whole store, so it can point somewhere
#                        committed or backed up, and CLAUDE_CODE_PROJECT_DIR_NAME (2.1.234+)
#                        pins the <project> segment so a directory RENAME stops stranding
#                        notes -- the HeatlhApp typo case exactly. Nobody had looked; the
#                        issue was closed with preservation open on an assumption.
#   2026-09-06 v0.9.0.20260906.0406 — --auto-memory-status: THE SILENCE IS COUNTABLE NOW (#300).
#                        0.8.0 listed auto-memory notes at distill, which closed DETECTION.
#                        What remained is that "nothing to promote" and "nobody looked" render
#                        identically -- and #264 recorded an adoption whose session hooks never
#                        fired at all, so the mechanism meant to surface these depended on one
#                        already known not to run. Measured in `mobile-kmp`: a genuine user
#                        correction sat unpromoted for three days and surfaced only because the
#                        owner asked.
#                        Prints how many notes exist, how many were never promoted, and the age
#                        of the oldest. ADVISORY, ALWAYS EXIT 0 -- plenty of notes legitimately
#                        never need promoting, and the store is per-machine and uncommitted, so
#                        failing a build on it would redden repos over something no teammate can
#                        see or fix.
#                        AND THE ORPHAN CHECK, which is the data-loss half: the store key is the
#                        ABSOLUTE workspace path, so renaming a directory -- or fixing a typo in
#                        it, which is how #300 was found -- strands every note silently. A store
#                        that names this repo while not covering it is that signature, and is
#                        now reported instead of starting empty in silence.
#   2026-09-03 v0.8.0.20260903.0420 — --distill SURFACES CLAUDE CODE AUTO MEMORY, and promotes
#                        none of it (#286). Those notes live under
#                        <config>/projects/<encoded-workspace>/memory/, one file per fact.
#                        They are PER MACHINE and NOT COMMITTED -- the exact gap ai/MEMORY.md
#                        exists to close -- so they are a SOURCE and never the record. Same
#                        rule as correction candidates: listed for a person, written nowhere.
#                        MEASURED: 31 notes in the store covering this workspace, none of
#                        which had reached ai/MEMORY.md except by hand.
#                        TWO THINGS THAT ARE EASY TO GET WRONG, and both are fixtured. The
#                        store is not always under ~/.claude -- CLAUDE_CONFIG_DIR moves it.
#                        And the key is the WORKSPACE, not the repo: Claude Code encodes the
#                        directory the SESSION opened in, which here is the parent of four
#                        sibling repos, so the lookup walks up. It also SKIPS AN EMPTY STORE,
#                        because Claude Code creates those eagerly -- 4 of 8 on this machine
#                        are empty, and stopping at one would hide the real notes above it.
#   2026-09-01 v0.7.0.20260901.1810 — --distill --from: A -dev REPO'S LOG IS ABOUT WORK DONE
#                        SOMEWHERE ELSE (#278). The first real run, in
#                        Robiton/localcoder-dev, found 13 commits -- every one of them
#                        `chore(scaffold): upgrade to ...` -- and none of the two releases
#                        and four defects the entry was supposed to be about. Those are in
#                        Robiton/localcoder. The journal has the same shape for the same
#                        reason: it is per-repository too. So --distill read the right log
#                        and the wrong repository, and produced a confident, complete-looking
#                        skeleton about nothing that mattered.
#                        --from <path>, repeatable. Commits and tags from each named repo are
#                        LABELLED with the repo they came from, because a session entry that
#                        mixes two histories without saying which is which is worse than one
#                        that covers only half.
#   2026-09-01 v0.6.0.20260901.1656 — --distill: THE SESSION RECORD STOPS DEPENDING ON
#                        SOMEBODY REMEMBERING (#278). The scaffold's central claim is that
#                        the record survives the session, and the mechanism was a rule in
#                        prose. MEASURED 2026-09-01: Robiton/localcoder-dev's ai/SESSION.md
#                        ended 27 August with two releases and four Linux-found defects
#                        unlogged, while the journal on this machine held every commit.
#                        A SKELETON, NOT AN ENTRY. It writes what shipped, what was
#                        committed and what the correction capture flagged, with an explicit
#                        edit-me marker and [fill in] on the fields that matter. Handing back
#                        a finished-looking entry assembled from commit subjects would make
#                        the log LOOK current while the reasoning -- the half only a person
#                        has -- was still missing, which is worse than the empty log.
#                        CORRECTION CANDIDATES STAY CANDIDATES: listed for confirmation,
#                        never written into ai/CODING.md or ai/MEMORY.md. A correction
#                        promoted by a script is a rule nobody agreed to.
#                        IDEMPOTENT ON THE NEWEST ENTRY'S DATE, not on a flag file -- a flag
#                        would be a second source of truth for something ai/SESSION.md
#                        already records.
#   2026-09-01 v0.6.0.20260901.1656 — A CLOSEOUT NOW SAYS WHAT WAS NEVER DRAFTED
#                        (localcoder#201). Recording what happened to a draft says nothing
#                        about the work that was never delegated at all, and that gap was
#                        the finding: measured 2026-09-01, 42 draft rows in Robiton/localcoder
#                        over 30 days, every one a fixture, while 576 policy-eligible lines
#                        landed there in a week and 278 landed here. Every report was green.
#                        IT SHELLS OUT AND ADDS NOTHING. localcoder owns the draft log and the
#                        fingerprint definition, so this prints localcoder's own first line.
#                        An adopter with no localcoder-history on PATH gets one sentence
#                        saying the share was NOT MEASURED -- pinned by a selftest that fails
#                        if a percentage ever appears in it, because a missing instrument
#                        reading as a clean 0% is the exact defect the share exists to find.
#   2026-08-20 — STAMP CORRECTED from .1420 to .0544. The first was
#                        FABRICATED: written from nothing rather than read from the clock,
#                        landing ~8 hours in the future. ai/STANDARDS.md names this exact
#                        failure -- a stamp rounded forward makes the next honest release
#                        sort EARLIER than its predecessor. The replacement is this file's
#                        real commit time from git.
#   2026-08-20 v0.5.0 — `--tool`: THE RECORD NOW REACHES ai/ FROM EVERY ADOPTION PATH.
#                        Options 3 and 4 drive a local runtime directly -- no localcoder,
#                        no MCP, no draft log, and therefore no row-id -- so until now they
#                        could record NOTHING. The shared history had a hole exactly where
#                        the local work happened, and the frontier side was the only
#                        participant whose work travelled to other developers.
#                        `--tool ollama|llama.cpp|lm-studio|manual` replaces --row-id and
#                        derives a `manual-<8hex>` id from tool+summary+date. THE PREFIX IS
#                        LOAD-BEARING: a reader who looks up a bare hex id in the draft log
#                        and finds nothing reads it as data loss, so the id says up front
#                        that the record stops here. DERIVED rather than random, so the
#                        idempotency this file already guarantees is not weaker on this path.
#                        --summary becomes REQUIRED with --tool: with a draft log behind a
#                        row the prompt and diff are recoverable; without one, that line is
#                        the only record the work happened.
#                        SIX COLUMNS ARE PRESERVED -- a selftest holds the table to six and
#                        widening it would orphan every row already written -- so provenance
#                        goes in the summary as `[tool]`.
#                        And the mirror is SKIPPED and says so. Calling localcoder with a
#                        row-id it never issued makes it exit 1, which reported a failure on
#                        a path that had worked perfectly. Found by running it, not reading it.
#   2026-08-15 v0.1.1 — THE MIRROR WAS WRITTEN AGAINST AN INTERFACE THAT DOES NOT EXIST.
#                        v0.1.0 set LOCALCODER_OUTCOME_SOURCE, an environment variable
#                        localcoder has never read. Nothing would have failed: the
#                        subprocess would have succeeded, the outcome would have been
#                        recorded, and every row this tool wrote would have been filed as
#                        `manual` -- so the source split that exists to separate a person
#                        typing a judgement from a record written after the gates ran would
#                        have carried exactly one value forever and looked like a working
#                        feature. The real mechanism is a FLAG, `--outcome-source
#                        close_out`, and localcoder's own comment beside it says it "exists
#                        for close_out to declare itself": the flag was built for this
#                        caller, and this caller did not use it.
#                        Found by checking `localcoder --help` instead of trusting the call
#                        I had written, which is the rule this programme adopted after two
#                        earlier proposals shipped scripts written against an imagined CLI.
#                        The argv is now built by draft_log_argv() so it can be ASSERTED
#                        without localcoder installed, and two cases pin both the flag and
#                        the positional order.
#   2026-08-15 v0.1.0 — Initial. W-06's other half, and the stage the design has always
#                        called its weakest: a draft arrives, it gets used or thrown away,
#                        and the session ends. Every acceptance rate this programme quotes is
#                        computed over the rows somebody chose to come back to, and those are
#                        not missing at random — a clean acceptance is recorded far more
#                        readily than an abandonment three days old.
#                        THE SCAFFOLD OWNS ai/SESSION.md, NOT THE DRAFTING TOOL (DEC-20).
#                        localcoder never writes project memory; it hands back a
#                        `log_row_id` and this closes the loop. That boundary is why this
#                        file is here and not there, and it is also why this works with no
#                        localcoder installed at all: the SESSION entry is written either
#                        way, and the draft-log write is best-effort and SAID OUT LOUD when
#                        it cannot happen.
#                        IDEMPOTENT ON row_id, because the alternative is a retry that
#                        silently doubles a record everyone will later count. Writes are
#                        atomic (tmp + rename in the same directory) and serialised by an
#                        O_EXCL lock, because two agents finishing at once is the normal
#                        case in this project, not the exotic one.
#                        THE GATE RESULT IS A COLUMN, NOT A NARRATIVE. There is no path
#                        through this tool that records an outcome without the gate result
#                        beside it, so "accepted" can never be read without seeing whether
#                        anything verified it. Asserted by selftest, both directions.

import argparse
import datetime
import errno
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time

OUTCOMES = ("accepted", "modified", "rejected", "abandoned")
GATES = ("pass", "fail", "not_run")

BEGIN = "<!-- scaffold:closeouts:begin -->"
END = "<!-- scaffold:closeouts:end -->"

HEADER = (
    "| row id | when | outcome | gate | actor | summary |\n"
    "|---|---|---|---|---|---|\n"
)

REGION_DOC = (
    "\n## Delegated drafts — what happened to them\n"
    "\n"
    "_Written by `tools/close_out.py`, after the repository gates ran. One row per draft,\n"
    "keyed by the `log_row_id` the drafting tool returned. The gate column is not optional:\n"
    "an outcome with no verification beside it is an opinion._\n"
    "\n"
)


def root():
    """The repository root, walking up from this file."""
    here = os.path.dirname(os.path.abspath(__file__))
    return os.path.dirname(here)


def session_path():
    return os.path.join(root(), "ai", "SESSION.md")


class Lock:
    """An O_EXCL lock file. Two agents finishing at once is normal here.

    A stale lock is BROKEN AFTER A TIMEOUT rather than waited on forever: a crashed
    process must not permanently prevent the one write this project already struggles to
    get people to perform.
    """

    def __init__(self, path, timeout=10.0, stale=60.0):
        self.path, self.timeout, self.stale = path, timeout, stale
        self.fd = None

    def __enter__(self):
        deadline = time.time() + self.timeout
        while True:
            try:
                self.fd = os.open(self.path, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
                os.write(self.fd, str(os.getpid()).encode())
                return self
            except OSError as e:
                if e.errno != errno.EEXIST:
                    raise
                try:
                    age = time.time() - os.path.getmtime(self.path)
                except OSError:
                    age = 0
                if age > self.stale:
                    try:
                        os.unlink(self.path)
                        continue
                    except OSError:
                        pass
                if time.time() > deadline:
                    raise TimeoutError(f"could not acquire {self.path} within "
                                       f"{self.timeout}s")
                time.sleep(0.05)

    def __exit__(self, *a):
        if self.fd is not None:
            os.close(self.fd)
        try:
            os.unlink(self.path)
        except OSError:
            pass


def atomic_write(path, text):
    """Write via a temp file in the SAME directory, then rename.

    Same directory because rename is only atomic within a filesystem, and /tmp is often a
    different one. This project has already shipped one read-only-log defect caused by
    getting the permissions of a replacement wrong; the directory matters for the same
    class of reason.
    """
    d = os.path.dirname(path) or "."
    fd, tmp = tempfile.mkstemp(dir=d, prefix=".close_out.", suffix=".tmp")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as fh:
            fh.write(text)
        if os.path.exists(path):
            shutil.copymode(path, tmp)
        os.replace(tmp, path)
    except BaseException:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        raise


def _cell(s):
    """Make a value safe for a markdown table cell without silently losing it."""
    return (str(s or "").replace("|", "\\|").replace("\n", " ").strip())[:200]


def parse_region(text):
    """Return (before, rows, after). `rows` is a list of raw row strings, in file order."""
    if BEGIN not in text or END not in text:
        return None, [], None
    head, rest = text.split(BEGIN, 1)
    body, tail = rest.split(END, 1)
    rows = [ln for ln in body.splitlines()
            if ln.strip().startswith("|") and not ln.strip().startswith("|---")
            and not ln.strip().startswith("| row id")]
    return head, rows, tail


def row_id_of(row):
    parts = [p.strip() for p in row.strip().strip("|").split("|")]
    return parts[0] if parts else ""


def render(rows):
    return BEGIN + "\n" + HEADER + "".join(r.rstrip() + "\n" for r in rows) + END


def manual_row_id(tool, summary, stamp):
    """A stable id for work that has no draft-log row behind it.

    THE PREFIX IS THE POINT. A row keyed `dc1d6896f440` promises a matching entry in the
    draft log; a reader who looks it up and finds nothing reads that as data loss rather
    than as "there was never a log row". `manual-` says up front that the record stops here,
    so the two kinds of row cannot be mistaken for one another in a table that renders them
    identically. Same reason the four-state audit contract exists: a state the reader cannot
    distinguish gets read as the familiar one.

    DERIVED, NOT RANDOM, so re-running the same closeout updates its row instead of adding a
    second one -- idempotency is the property this file already guarantees for draft rows and
    it must not be weaker here.
    """
    import hashlib
    seed = f"{tool}\x00{(summary or '').strip()}\x00{stamp}"
    return "manual-" + hashlib.sha256(seed.encode("utf-8")).hexdigest()[:8]


def close_out(row_id, outcome, gate, actor=None, summary=None, files=None, path=None,
              mirror=True,
              now=None):
    """Record one closeout. Returns (exit_code, message)."""
    if outcome not in OUTCOMES:
        return 2, f"outcome must be one of {'|'.join(OUTCOMES)}, got {outcome!r}"
    if gate not in GATES:
        return 2, f"gate must be one of {'|'.join(GATES)}, got {gate!r}"
    if not row_id or not str(row_id).strip():
        return 2, ("a closeout needs the log_row_id the draft returned, or --tool <name> "
                   "when a local model was driven directly and there is no draft log")

    path = path or session_path()
    if not os.path.exists(path):
        # EXIT 3, NOT 1. Could-not-run is not a failure of the thing being checked, and
        # this project's exit vocabulary is 0/1/3 everywhere else.
        return 3, f"no {os.path.relpath(path, root())} to write to"

    stamp = (now or datetime.datetime.now(datetime.timezone.utc)).strftime("%Y-%m-%d")
    actor = actor or os.environ.get("USER") or "unknown"
    note = _cell(summary)
    if files:
        note = (note + "  files: " + ", ".join(files[:6])).strip()
    row = (f"| {_cell(row_id)} | {stamp} | {outcome} | {gate} | {_cell(actor)} "
           f"| {note} |")

    with Lock(path + ".lock"):
        with open(path, encoding="utf-8") as fh:
            text = fh.read()
        head, rows, tail = parse_region(text)
        if head is None:
            # First use: create the region directly under the file's intro block, so it
            # sits above the session narrative rather than drifting to the bottom where
            # nobody reading the top of the file will see it.
            marker = "\n---\n"
            i = text.find(marker)
            at = (i + len(marker)) if i != -1 else len(text)
            new = (text[:at] + REGION_DOC + render([row]) + "\n" + text[at:])
        else:
            existing = {row_id_of(r): idx for idx, r in enumerate(rows)}
            key = _cell(row_id)
            if key in existing:
                # IDEMPOTENT. A retry replaces its own row and never appends a second one;
                # a doubled record is worse than a missing one because it is counted.
                rows[existing[key]] = row
            else:
                rows.insert(0, row)
            new = head + render(rows) + tail
        atomic_write(path, new)

    # Best effort, and LOUD when it cannot happen: the scaffold must work with no
    # localcoder installed, so this is never a failure — but a silent skip would leave the
    # two records disagreeing with nothing saying why.
    # A --tool ROW HAS NOTHING TO MIRROR INTO. Calling localcoder with a row-id it has
    # never seen makes it exit 1, and the closeout then reports "draft log not updated" as
    # though something had gone wrong -- a manufactured failure on the happy path of an
    # adoption option that is working exactly as designed.
    note_lc = record_in_draft_log(row_id, outcome) if mirror else ""
    return 0, f"recorded {row_id} = {outcome} (gate {gate}){note_lc}"


def draft_log_argv(exe, row_id, outcome):
    """The exact argv used to mirror an outcome. Split out so it can be ASSERTED.

    `--outcome-source close_out` is the whole reason this call is worth making.
    localcoder records `manual` for anything that does not say otherwise — deliberately,
    so the weaker evidence cannot pass itself off as the stronger one by omission — and
    its own source comment says the flag "exists for close_out to declare itself".

    THE FIRST VERSION OF THIS FUNCTION SET AN ENVIRONMENT VARIABLE THAT DOES NOT EXIST.
    Nothing would have failed: the subprocess would have succeeded, the outcome would have
    been recorded, and every row this tool wrote would have been filed as `manual` — so the
    source split that exists to separate the two kinds of evidence would have had exactly
    one value forever, and looked like a working feature. Written against an imagined
    interface, which is the failure this programme has documented twice before.
    """
    return [exe, "--outcome", str(row_id), outcome, "--outcome-source", "close_out"]


def record_in_draft_log(row_id, outcome):
    """Mirror the outcome into localcoder's own log, if localcoder is installed."""
    exe = shutil.which("localcoder")
    if not exe:
        return "  [localcoder not on PATH — draft log not updated]"
    try:
        p = subprocess.run(draft_log_argv(exe, row_id, outcome),
                           capture_output=True, text=True, timeout=30)
    except (OSError, subprocess.SubprocessError) as e:
        return f"  [draft log not updated: {e}]"
    if p.returncode != 0:
        return f"  [draft log not updated: localcoder exited {p.returncode}]"
    return "  [draft log updated]"


# ==== THE DELEGATION SHARE, PRINTED WHERE A CLOSEOUT ALREADY LOOKS (localcoder#201) =======
#
# Recording what happened to a draft says nothing about the work that was never drafted at
# all. Measured 2026-09-01 in Robiton/localcoder: 42 draft rows over 30 days, every one a
# fixture or a probe, and 576 delegable lines landed in the same week with no row. Every
# report was green because every report read only from the log.
#
# ADVISORY, AND IT SHELLS OUT. The share is localcoder's measurement -- localcoder owns the
# draft log and the fingerprint definition -- so this prints what localcoder says and adds
# nothing of its own. An adopter with no localcoder gets one line saying the check did not
# run, which is the answer, not a failure.
def delegation_share_note():
    """One line from `localcoder-history --delegation-share`, or a reason it is absent."""
    exe = shutil.which("localcoder-history")
    if not exe:
        return "  [delegation share not measured — localcoder-history not on PATH]"
    try:
        p = subprocess.run([exe, "--delegation-share"],
                           capture_output=True, text=True, timeout=180)
    except (OSError, subprocess.SubprocessError) as e:
        return f"  [delegation share not measured: {e}]"
    head = (p.stdout or p.stderr or "").strip().splitlines()
    # AN OLD localcoder ON PATH IS "NOT MEASURED", NOT A RESULT. argparse answers an unknown
    # flag with a usage block on stderr and exit 2, and printing its first line as the share
    # put `usage: localcoder-history [-h] ...` where a number belongs -- a tool's error text
    # rendered as its verdict, which is the failure this whole note exists to surface.
    if p.returncode == 2 or (head and head[0].startswith("usage:")):
        return ("  [delegation share not measured — the localcoder-history on PATH has no "
                "--delegation-share; it needs localcoder 1.7.0 or newer]")
    if not head:
        return f"  [delegation share not measured: exited {p.returncode} with no output]"
    return "  " + head[0]



# ==== --distill: THE PROMISE WAS KEPT ONLY WHEN SOMEBODY REMEMBERED (#278) ==================
#
# The scaffold's central claim is that the record survives the session and travels to every
# machine. The mechanism was a rule in prose, and prose does not run. MEASURED 2026-09-01:
# Robiton/localcoder-dev's ai/SESSION.md ended on 27 August with 1.6.0, 1.6.1 and four
# Linux-found defects unlogged, while the journal on this machine held every one of their
# commits. Nothing was lost; nothing was written down either.
#
# A SKELETON, NOT AN ENTRY. What this produces is the mechanical half -- what shipped, what
# was committed, what the correction capture flagged -- with an explicit edit-me marker. The
# reasoning is the valuable half and only a person has it. Handing back a finished-looking
# entry assembled from commit subjects would make the log LOOK current while the thing worth
# keeping was still missing, which is a worse failure than the empty log it replaces.
#
# CORRECTION CANDIDATES STAY CANDIDATES. They are listed for a person to confirm, never
# written into ai/CODING.md or ai/MEMORY.md: a correction promoted by a script is a rule
# nobody agreed to.
DISTILLED_MARKER = "<!-- distilled by tools/close_out.py --distill — edit me -->"


def parse_journal(text):
    """Parse ai/SESSION_JOURNAL.md into sessions, commits and correction candidates.

    Commits are de-duplicated on the sha, first occurrence wins, because a journal spanning
    several sessions records the same commit under each checkpoint that saw it. A '- ' line
    that is neither a commit nor a correction is ignored: the journal also carries
    uncommitted-file counts, which are a fact about a moment and not about the work.
    """
    out = {"sessions": [], "commits": [], "corrections": []}
    if not text:
        return out
    head_re = re.compile(r"^##\s+Session started\s+(\S+ \S+)"
                         r"(?:\s+\(branch\s+(\S+)\s+@\s+(\S+)\))?")
    commit_re = re.compile(r"^\s*-\s+([0-9a-f]{7,40})\s+(.+?)\s*$")
    seen = set()
    for line in text.splitlines():
        m = head_re.match(line)
        if m:
            out["sessions"].append({"stamp": m.group(1),
                                    "branch": (m.group(2) or ""),
                                    "sha": (m.group(3) or "")})
            continue
        if "correction candidate" in line:
            tail = line.split("correction candidate", 1)[1]
            tail = re.sub(r"^\s*(\[[^\]]*\])?\s*:?\s*", "", tail).strip()
            out["corrections"].append(tail.strip().strip('"').strip("'").strip())
            continue
        m = commit_re.match(line)
        if m and m.group(1) not in seen:
            seen.add(m.group(1))
            out["commits"].append({"sha": m.group(1), "subject": m.group(2)})
    return out


def newest_entry_date(markdown):
    """Newest YYYY-MM-DD on a HEADING line, or None. Headings only, and a real month/day.

    The scaffold's own ai/SESSION.md template heading is `## [YYYY-MM-DD] — [Person or Tool]`,
    which is why the digits are validated: a placeholder must not set the range.
    """
    best = None
    for line in (markdown or "").splitlines():
        if not line.lstrip().startswith("#"):
            continue
        for y, mo, d in re.findall(r"(\d{4})-(\d{2})-(\d{2})", line):
            if "01" <= mo <= "12" and "01" <= d <= "31":
                found = f"{y}-{mo}-{d}"
                if best is None or found > best:
                    best = found
    return best


def _git(*args, cwd=None):
    """git, in this repository by default and in `cwd` when a --from source names one."""
    try:
        p = subprocess.run(["git"] + list(args), cwd=(cwd or root()), capture_output=True,
                           text=True, timeout=60)
    except (OSError, subprocess.SubprocessError):
        return ""
    return p.stdout if p.returncode == 0 else ""


CC_TYPES = (("feat", "Features"), ("fix", "Fixes"), ("perf", "Performance"),
            ("refactor", "Refactors"), ("docs", "Documentation"), ("test", "Tests"),
            ("build", "Build"), ("ci", "CI"), ("chore", "Chores"))


def group_by_type(subjects):
    """Group conventional-commit subjects by type, preserving order within each group.

    An unconventional subject is not dropped and not guessed at: it lands under 'Other',
    where a reader can see it. A commit silently missing from a summary of commits is the
    shape of defect this package keeps finding in itself.
    """
    groups = {}
    for subject in subjects:
        label = "Other"
        head = subject.split(":", 1)[0].strip()
        base = head.split("(", 1)[0].strip().rstrip("!")
        for name, pretty in CC_TYPES:
            if base == name:
                label = pretty
                break
        groups.setdefault(label, []).append(subject)
    order = [p for _, p in CC_TYPES] + ["Other"]
    return [(label, groups[label]) for label in order if label in groups]



# ==== AUTO MEMORY IS A SOURCE, NOT A REPLACEMENT (#286) ====================================
#
# Claude Code writes notes for itself under `<config>/projects/<encoded-root>/memory/` — one
# file per fact, YAML-ish frontmatter, plus a MEMORY.md index whose first 200 lines are
# auto-loaded. It is PER MACHINE and NOT COMMITTED, which is the exact gap this scaffold
# exists to close. So it does not replace ai/MEMORY.md and must never be treated as it.
#
# It is a SOURCE. A note Claude wrote to itself during a session is the same kind of raw
# material as a correction candidate: worth a person's attention at closeout, and never
# promoted by a script. Same rule, same reason — a fact promoted without judgement is a
# rule nobody agreed to.
#
# THE STORE IS NOT ALWAYS UNDER ~/.claude. `CLAUDE_CONFIG_DIR` moves it, and this workspace
# uses a `.claude-personal` directory. Both are checked; neither is assumed.
#
# AND THE KEY IS THE WORKSPACE, NOT THE REPO. Claude Code encodes the directory the session
# opened in, which here is the PARENT of four sibling repos — so a distill run inside
# ai-project-scaffold-dev has to walk up to find its own notes. Looking only at the repo
# root finds nothing and would report "no auto memory" on a machine covered in it.
def _encode_project_dir(path):
    """Claude Code's project key: the absolute path with every non-alphanumeric run as '-'."""
    return re.sub(r"[^A-Za-z0-9]+", "-", os.path.abspath(path))


def auto_memory_dir(start=None):
    """The auto-memory directory covering `start`, or None. Nearest ancestor wins.

    Returns the first directory that EXISTS AND HOLDS A NOTE. An empty memory directory is
    not a match: Claude Code creates them eagerly, and treating one as the answer would stop
    the walk at a directory with nothing in it while the real notes sit one level up.
    """
    roots = []
    cfg = os.environ.get("CLAUDE_CONFIG_DIR")
    if cfg:
        roots.append(os.path.join(cfg, "projects"))
    roots.append(os.path.join(os.path.expanduser("~"), ".claude", "projects"))
    here = os.path.abspath(start or root())
    seen = set()
    while True:
        for base in roots:
            cand = os.path.join(base, _encode_project_dir(here), "memory")
            if cand in seen:
                continue
            seen.add(cand)
            try:
                if any(n.endswith(".md") and n != "MEMORY.md" for n in os.listdir(cand)):
                    return cand
            except OSError:
                pass
        parent = os.path.dirname(here)
        if parent == here:
            return None
        here = parent


def parse_memory_note(text):
    """Name, description, type and first body line from an auto-memory note.

    Frontmatter is the block between the first `---` and the next. Only TOP-LEVEL keys are
    read, except that `type` is taken from an indented line when there is no top-level one —
    the shipped notes nest it under `metadata:`. Every key is always present; absent means
    an empty string, never a missing key, because the caller renders all four.
    """
    out = {"name": "", "description": "", "type": "", "first_line": ""}
    if not text:
        return out
    lines = text.split("\n")
    body_at = 0
    fm = []
    if lines and lines[0].strip() == "---":
        for i in range(1, len(lines)):
            if lines[i].strip() == "---":
                fm, body_at = lines[1:i], i + 1
                break

    def clean(v):
        v = v.strip()
        if len(v) >= 2 and v[0] == v[-1] and v[0] in "\"'":
            v = v[1:-1]
        return v.strip()

    nested_type = ""
    for ln in fm:
        if ":" not in ln:
            continue
        key, val = ln.split(":", 1)
        if ln[:1] not in (" ", "\t"):
            k = key.strip()
            if k in out:
                out[k] = clean(val)
        elif key.strip() == "type" and not nested_type:
            nested_type = clean(val)
    if not out["type"]:
        out["type"] = nested_type
    for ln in lines[body_at:]:
        if ln.strip():
            out["first_line"] = ln.strip()
            break
    return out


def auto_memory_candidates(start=None):
    """(name, description, type) for every note in the covering store, newest first.

    Returns [] when there is no store — which is the common case and is not an error. A
    machine with no auto memory must produce a skeleton that says nothing about it rather
    than one that reports an absence as a finding.
    """
    d = auto_memory_dir(start)
    if not d:
        return []
    notes = []
    for name in os.listdir(d):
        if not name.endswith(".md") or name == "MEMORY.md":
            continue
        path = os.path.join(d, name)
        try:
            with open(path, encoding="utf-8", errors="replace") as fh:
                meta = parse_memory_note(fh.read())
            mtime = os.path.getmtime(path)
        except OSError:
            continue
        notes.append((mtime, meta.get("name") or name[:-3],
                      meta.get("description") or meta.get("first_line", ""),
                      meta.get("type", "")))
    notes.sort(reverse=True)
    return [(n, desc, kind) for _, n, desc, kind in notes]


def auto_memory_status(start=None):
    """Counts for the escalation line (#300): how many notes, how many never promoted.

    `--distill` closed the DETECTION half -- the notes are listed when somebody runs it.
    What was missing is that silence and "nothing to promote" look identical: a real user
    correction sat unpromoted for three days in `mobile-kmp` and surfaced only because the
    owner asked. This gives a gate something to COUNT, so the silence becomes a number.

    Promotion is judged by whether the note NAME appears anywhere in ai/MEMORY.md. That is
    deliberately loose -- a person paraphrasing a note into a longer entry usually keeps the
    slug, and the failure this guards is "nobody looked at all", not "the wording drifted".
    Over-reporting a promoted note costs one glance; under-reporting hides the whole point.
    """
    d = auto_memory_dir(start)
    out = {"dir": d, "total": 0, "unpromoted": [], "oldest_days": None, "orphans": []}
    if not d:
        out["orphans"] = _orphan_stores(start)
        return out
    mem = ""
    mem_path = os.path.join(root(), "ai", "MEMORY.md")
    if os.path.exists(mem_path):
        with open(mem_path, encoding="utf-8", errors="replace") as fh:
            mem = fh.read()
    now = time.time()
    for name in sorted(os.listdir(d)):
        if not name.endswith(".md") or name == "MEMORY.md":
            continue
        out["total"] += 1
        slug = name[:-3]
        try:
            age = int((now - os.path.getmtime(os.path.join(d, name))) // 86400)
        except OSError:
            age = 0
        if slug and slug in mem:
            continue
        out["unpromoted"].append((slug, age))
    if out["unpromoted"]:
        out["oldest_days"] = max(a for _, a in out["unpromoted"])
    return out


def _orphan_stores(start=None):
    """Stores that are NOT an ancestor of here but whose notes name this repository.

    The store key is the ABSOLUTE workspace path, so renaming a directory -- or fixing a
    typo in it, which is how #300 found this -- silently strands every note for the project
    and nothing reports the loss. A store that mentions this repo by name while not covering
    it is the readable signature of that, so say so rather than starting empty in silence.
    """
    here = os.path.abspath(start or root())
    base = os.path.basename(here)
    if not base:
        return []
    roots = []
    cfg = os.environ.get("CLAUDE_CONFIG_DIR")
    if cfg:
        roots.append(os.path.join(cfg, "projects"))
    roots.append(os.path.join(os.path.expanduser("~"), ".claude", "projects"))
    found = []
    for r in roots:
        try:
            entries = sorted(os.listdir(r))
        except OSError:
            continue
        for key in entries:
            mem = os.path.join(r, key, "memory")
            if not os.path.isdir(mem):
                continue
            # A store that already covers us is not an orphan.
            if _encode_project_dir(here).endswith(key) or key.endswith(_encode_project_dir(here)):
                continue
            if base.lower() not in key.lower():
                continue
            try:
                n = len([x for x in os.listdir(mem)
                         if x.endswith(".md") and x != "MEMORY.md"])
            except OSError:
                continue
            if n:
                found.append((mem, n))
    return found


def print_auto_memory_status(start=None):
    """The advisory a gate prints. ALWAYS exit 0 -- plenty of notes never need promoting."""
    st = auto_memory_status(start)
    if not st["dir"] and not st["orphans"]:
        print("  [ok  ] auto memory: no store covers this workspace — nothing to promote.")
        return 0
    if st["dir"]:
        n_un = len(st["unpromoted"])
        where = st["dir"].replace(os.path.expanduser("~"), "~")
        if n_un:
            print(f"  [note ] auto memory: {st['total']} note(s) for this workspace, "
                  f"{n_un} never promoted, oldest {st['oldest_days']} day(s) old.")
            for slug, age in st["unpromoted"][:6]:
                print(f"           - {slug}  ({age}d)")
            if n_un > 6:
                print(f"           - …and {n_un - 6} more")
            print(f"           {where}")
            print("           Per-machine and NOT committed. Promote what belongs in")
            print("           ai/MEMORY.md; a rename of this directory strands the rest.")
            # THE REMEDY IS SUPPORTED, AND #300 CLOSED WITHOUT IT BECAUSE NOBODY LOOKED.
            # Both of the questions that issue recorded as undeterminable are answered in
            # the Claude Code docs: `autoMemoryDirectory` (settings.json, any scope) moves
            # the whole store, and CLAUDE_CODE_PROJECT_DIR_NAME (v2.1.234+) pins the
            # <project> segment so a directory rename stops stranding notes. Naming them
            # here rather than in an issue comment, because the person who needs them is
            # the one reading this line.
            print("           PRESERVE them by moving the store somewhere committed or")
            print("           backed up — `autoMemoryDirectory` in settings.json (any")
            print("           scope) relocates it. To survive a RENAME of this directory,")
            print("           set CLAUDE_CODE_PROJECT_DIR_NAME (Claude Code 2.1.234+).")
        else:
            print(f"  [ok  ] auto memory: {st['total']} note(s), all promoted.")
    for mem, n in st["orphans"]:
        print(f"  [note ] auto memory: a store naming this project holds {n} note(s) but does")
        print(f"           NOT cover this path — likely a rename. {mem.replace(os.path.expanduser('~'), '~')}")
    return 0


def distill(dry_run=False, sources=None):
    """Write a dated skeleton entry into ai/SESSION.md from the journal and git log.

    `sources` names OTHER repositories whose history belongs in this log. A -dev repository
    is the case this exists for: its ai/SESSION.md records work done in the PRODUCT
    repository, and its own git log holds nothing but its scaffold upgrades. Measured
    2026-09-01 in Robiton/localcoder-dev -- the first run found 13 commits, every one of them
    `chore(scaffold): upgrade to ...`, and none of the two releases and four defects the
    entry was supposed to be about. The journal is per-repository too, so it has the same
    shape and does not fill the gap.

    IDEMPOTENT BY THE DATE OF THE NEWEST ENTRY, not by a flag file. Running it twice on one
    day finds its own entry already there and adds nothing; a flag file would have been a
    second source of truth for something ai/SESSION.md already records.
    """
    sess = session_path()
    if not os.path.exists(sess):
        print("close_out --distill: no ai/SESSION.md here — nothing to distill into.")
        return 3

    with open(sess, encoding="utf-8", errors="replace") as fh:
        existing = fh.read()
    today = datetime.date.today().isoformat()
    newest = newest_entry_date(existing)
    if newest == today:
        print(f"close_out --distill: ai/SESSION.md already has a {today} entry. "
              "Nothing added — edit that one.")
        return 0

    journal_path = os.path.join(root(), "ai", "SESSION_JOURNAL.md")
    journal = ""
    if os.path.exists(journal_path):
        with open(journal_path, encoding="utf-8", errors="replace") as fh:
            journal = fh.read()
    parsed = parse_journal(journal)

    # THE RANGE IS THE NEWEST DATED ENTRY, and the journal is only the other half. The
    # journal is gitignored and per-machine, so a commit made on another machine is in the
    # log and not in the journal; a commit made before any hook fired is in neither.
    since = f"--since={newest}" if newest else "--max-count=50"
    # WITH NO DATED ENTRY THERE IS NO RANGE, only a guess -- so the guess is bounded and SAID
    # OUT LOUD rather than rendered as a range somebody might trust. A template ai/SESSION.md,
    # which is what a fresh adoption has, lands here every time.
    repos = [(None, None)] + [(os.path.abspath(sp), os.path.basename(os.path.abspath(sp)))
                              for sp in (sources or [])]
    log_commits, seen, shipped = [], set(), []
    for cwd, label in repos:
        if cwd and not os.path.isdir(os.path.join(cwd, ".git")):
            print(f"close_out --distill: {cwd} is not a git repository — skipped.",
                  file=sys.stderr)
            continue
        for line in _git("log", since, "--no-merges", "--format=%h\t%s",
                         cwd=cwd).splitlines():
            if "\t" not in line:
                continue
            sha, subject = line.split("\t", 1)
            if sha in seen:
                continue
            seen.add(sha)
            log_commits.append({"sha": sha, "subject": subject, "repo": label})
        tags = [t for t in _git("tag", "--sort=-creatordate", "--merged", "HEAD",
                                cwd=cwd).splitlines() if t.strip()]
        for t in tags[:12 if newest else 5]:
            when = _git("log", "-1", "--format=%cs", t, cwd=cwd).strip()
            if newest and when and when < newest:
                break
            if when:
                shipped.append((t, when, label))
    for c in parsed["commits"]:
        if c["sha"][:7] not in {x["sha"][:7] for x in log_commits}:
            log_commits.append({"sha": c["sha"], "subject": c["subject"], "repo": None})

    lines = [
        f"## {today} — [who] — [tool] — [what this session was about]",
        "",
        DISTILLED_MARKER,
        "",
        "**Who worked on this:** [fill in]",
        "",
        "**What we worked on:** [fill in — this is the half only a person has. The lists",
        "below are what the journal and the git log could reconstruct on their own.]",
        "",
    ]
    if not newest:
        lines += ["> No dated entry in ai/SESSION.md, so there is no range to distill from.",
                  "> What follows is the newest 5 tags and 50 commits — a bound, not a range.",
                  ""]
    if shipped:
        lines.append("**What shipped:**")
        lines.append("")
        for tag, when, label in shipped:
            lines.append(f"- `{tag}` ({when})" + (f" — {label}" if label else ""))
        lines.append("")
    else:
        lines += ["**What shipped:** nothing tagged in this range.", ""]

    if log_commits:
        lines.append(f"**Commits since {newest or 'the start of the log'}:**")
        lines.append("")
        for label, subjects in group_by_type([c["subject"] for c in log_commits]):
            lines.append(f"- **{label}**")
            for c in log_commits:
                if c["subject"] in subjects:
                    where = f" _{c['repo']}_" if c.get("repo") else ""
                    lines.append(f"  - `{c['sha']}` {c['subject']}{where}")
        lines.append("")
    else:
        lines += ["**Commits:** none in range.", ""]

    if parsed["corrections"]:
        lines += ["**Corrections to confirm** — candidates from `correction_capture.py`.",
                  "Nothing here has been written to ai/CODING.md or ai/MEMORY.md: a",
                  "correction promoted by a script is a rule nobody agreed to.", ""]
        for c in parsed["corrections"]:
            lines.append(f"- [ ] {c}")
        lines.append("")
    else:
        lines += ["**Corrections to confirm:** none captured in this range.", ""]

    # AUTO MEMORY, LISTED AND NEVER PROMOTED (#286). Same rule as the correction candidates
    # above and for the same reason: these are notes Claude wrote to ITSELF, on THIS machine,
    # in a store that is not committed. Surfacing them at closeout is how they get a person's
    # attention; writing them into ai/MEMORY.md would be a script deciding what the project
    # remembers.
    _mem = auto_memory_candidates()
    if _mem:
        lines += ["**Candidates from auto memory** — notes Claude wrote to itself on this",
                  "machine, in a store that is per-machine and NOT committed. Listed so they",
                  "can be considered for `ai/MEMORY.md`; nothing here has been promoted.", ""]
        for _n, _desc, _kind in _mem[:12]:
            _tag = f"`{_kind}` " if _kind else ""
            lines.append(f"- [ ] {_tag}**{_n}** — {_desc}" if _desc
                         else f"- [ ] {_tag}**{_n}**")
        if len(_mem) > 12:
            lines.append(f"- [ ] …and {len(_mem) - 12} more in "
                         f"`{os.path.relpath(auto_memory_dir() or '', root())}`")
        lines.append("")

    lines += ["**Decisions made:** [fill in]", "",
              "**Problems encountered:** [fill in]", ""]
    entry = "\n".join(lines) + "\n"

    if dry_run:
        print(entry)
        return 0

    # MOST RECENT AT THE TOP, under the file's preamble. The insertion point is the first
    # existing entry heading, so the preamble that explains the file is never displaced.
    body = existing.splitlines(keepends=True)
    at = len(body)
    for i, line in enumerate(body):
        if line.startswith("## "):
            at = i
            break
    updated = "".join(body[:at]) + entry + "\n" + "".join(body[at:])
    with open(sess, "w", encoding="utf-8") as fh:
        fh.write(updated)

    print(f"close_out --distill: wrote a {today} skeleton into ai/SESSION.md — "
          f"{len(log_commits)} commit(s), {len(shipped)} tag(s), "
          f"{len(parsed['corrections'])} correction candidate(s).")
    print("  It is a SKELETON. The reasoning is the half only you have; the marker in it")
    print("  says so, and the fields marked [fill in] are the ones that matter.")
    return 0


def selftest():
    bad = []

    def case(name, cond, detail=""):
        if cond:
            print(f"  [ok  ] {name}")
        else:
            print(f"  [FAIL] {name} — {detail}")
            bad.append(name)

    d = tempfile.mkdtemp(prefix="closeout-selftest-")
    p = os.path.join(d, "SESSION.md")
    with open(p, "w", encoding="utf-8") as fh:
        fh.write("# Session Log\n\n_intro_\n\n---\n\n## 2026-08-01 — an older entry\n")

    rc, msg = close_out("abc123", "accepted", "pass", actor="tester",
                        summary="a first draft", path=p)
    body = open(p, encoding="utf-8").read()
    case("a closeout is recorded", rc == 0 and "abc123" in body, msg)
    case("the region is created above the existing narrative",
         body.index("abc123") < body.index("an older entry"),
         "a record nobody scrolls to is a record nobody reads")
    case("the gate result travels with the outcome",
         "| accepted | pass |" in body,
         "an outcome with no verification beside it is an opinion")

    rc2, _ = close_out("abc123", "rejected", "fail", actor="tester",
                       summary="changed my mind", path=p)
    body2 = open(p, encoding="utf-8").read()
    case("a second closeout for the same row REPLACES, never appends",
         rc2 == 0 and body2.count("| abc123 |") == 1,
         f"found {body2.count('| abc123 |')} rows for one id — a doubled record is worse "
         f"than a missing one, because it gets counted")
    case("the replacement carries the new values",
         "| rejected | fail |" in body2 and "accepted" not in body2.split(END)[0],
         "an idempotent write that keeps the stale value is just a slower wrong answer")

    close_out("def456", "modified", "not_run", actor="tester", path=p)
    body3 = open(p, encoding="utf-8").read()
    case("a second DIFFERENT row is added, newest first",
         body3.count("| abc123 |") == 1 and body3.count("| def456 |") == 1
         and body3.index("def456") < body3.index("abc123"),
         "idempotency must not become deduplication of distinct rows")

    # A FAILED GATE MUST NEVER BE INVISIBLE. This is the assertion the spec asks for:
    # there is no path that records an outcome without its verification state.
    rows_txt = body3.split(BEGIN)[1].split(END)[0]
    case("every recorded row carries a gate value",
         all(len([c for c in r.strip().strip("|").split("|")]) == 6
             for r in rows_txt.splitlines()
             if r.strip().startswith("|") and "row id" not in r and "---" not in r),
         "a row missing its gate column would let 'accepted' read as verified")

    rc3, m3 = close_out("x", "shipped", "pass", path=p)
    case("an unknown outcome is refused", rc3 == 2, m3)
    rc4, m4 = close_out("x", "accepted", "green", path=p)
    case("an unknown gate value is refused", rc4 == 2, m4)
    rc5, m5 = close_out("", "accepted", "pass", path=p)
    case("a missing row id is refused", rc5 == 2, m5)
    rc6, m6 = close_out("y", "accepted", "pass", path=os.path.join(d, "nope.md"))
    case("a missing SESSION.md is exit 3, not 1", rc6 == 3, m6)

    # A pipe in a summary must not silently eat the rest of the row.
    close_out("pipe1", "accepted", "pass", summary="a|b", path=p)
    b4 = open(p, encoding="utf-8").read()
    case("a pipe in the summary cannot break the table",
         "a\\|b" in b4, "an unescaped pipe would shift every column after it")

    # THE MIRROR MUST DECLARE ITSELF. Without --outcome-source, localcoder files the row
    # as `manual`, and the source split that separates a person typing a judgement from a
    # record written after the gates ran would have exactly one value forever — a feature
    # that looks like it works because nothing ever contradicts it.
    argv = draft_log_argv("/usr/bin/localcoder", "abc123", "accepted")
    # ---- THE RECORD REACHES ai/ FROM ADOPTION OPTIONS 3 AND 4 TOO ------------------------
    #
    # Those paths drive a local runtime directly: no localcoder, no MCP, no draft log and so
    # no row-id. Until this shipped they had no way to record anything, which left the shared
    # history with a hole exactly where the local work happened — and the frontier side was
    # the only participant whose work travelled to other developers.
    mp = os.path.join(d, "MANUAL.md")
    with open(mp, "w", encoding="utf-8") as fh:
        fh.write("# Session Log\n\n_intro_\n\n---\n\n## 2026-08-01 — older\n")
    _id = manual_row_id("ollama", "did a thing", "2026-08-20")
    rc_m, msg_m = close_out(_id, "modified", "pass", actor="tester",
                            summary="[ollama] did a thing", path=mp, mirror=False)
    body_m = open(mp, encoding="utf-8").read()
    case("a run with no draft log can still be recorded",
         rc_m == 0 and _id in body_m, msg_m)
    # THE PREFIX IS LOAD-BEARING. A reader who looks up a bare hex id in the draft log and
    # finds nothing reads that as data loss; `manual-` says the record stops here on purpose.
    case("a row with no draft log behind it is marked as such",
         _id.startswith("manual-"), _id)
    case("the producing runtime survives into the row",
         "[ollama]" in body_m, body_m[-90:])
    # DERIVED, NOT RANDOM: re-running the same closeout must update, never append a twin.
    case("the same work re-recorded keeps one row",
         manual_row_id("ollama", "did a thing", "2026-08-20") == _id, "id not stable")
    case("different work gets a different row",
         manual_row_id("llama.cpp", "did a thing", "2026-08-20") != _id, "ids collide")
    # AND THE MIRROR MUST NOT RUN. Calling localcoder with a row-id it has never seen makes
    # it exit 1, and the closeout then reports a failure on a path that worked perfectly.
    case("no draft-log mirror is attempted when there is no draft log",
         "draft log not updated" not in msg_m, msg_m)

    case("the draft-log mirror declares itself as close_out",
         "--outcome-source" in argv and argv[argv.index("--outcome-source") + 1] == "close_out",
         f"argv was {argv} — an outcome recorded without its source is filed as manual")
    # THE NOTE MUST NEVER INVENT A NUMBER. An absent localcoder-history is "not measured",
    # and the one shape that must not appear in that sentence is a percentage -- a missing
    # instrument reading as a clean 0% is the whole reason the share exists.
    # ---- AUTO MEMORY IS A SOURCE, NOT A REPLACEMENT (#286) --------------------------------
    import tempfile as _tf6
    _t6 = _tf6.mkdtemp()
    _saved_cfg = os.environ.get("CLAUDE_CONFIG_DIR")
    try:
        # A note in the SHIPPED shape: nested `type:` under metadata, quoted description.
        _note = ('---\n'
                 'name: a-real-note\n'
                 'description: "the thing that was learned"\n'
                 'metadata:\n'
                 '  node_type: memory\n'
                 '  type: feedback\n'
                 '---\n'
                 '\n'
                 'The body, whose first line is not the description.\n')
        _m = parse_memory_note(_note)
        case("a note's name, description and NESTED type are all read",
             _m["name"] == "a-real-note" and _m["description"] == "the thing that was learned"
             and _m["type"] == "feedback"
             and _m["first_line"].startswith("The body"),
             f"{_m['name']}/{_m['type']}")
        case("a note with no frontmatter still yields every key",
             set(parse_memory_note("just a body").keys())
             == {"name", "description", "type", "first_line"},
             "the caller renders all four; a missing key would be a KeyError at closeout")
        case("empty input is four empty strings, not a crash",
             parse_memory_note("") == {"name": "", "description": "", "type": "",
                                       "first_line": ""}, "")

        # THE STORE IS FOUND BY WALKING UP, because Claude Code keys on the directory the
        # SESSION opened in -- here the parent of four sibling repos. A lookup that only
        # tried the repo root would report "no auto memory" on a machine covered in it.
        _proj = os.path.join(_t6, "cfg", "projects",
                             _encode_project_dir(os.path.join(_t6, "ws")), "memory")
        os.makedirs(_proj)
        open(os.path.join(_proj, "n1.md"), "w").write(_note)
        open(os.path.join(_proj, "MEMORY.md"), "w").write("- [index](n1.md) - not a note\n")
        os.makedirs(os.path.join(_t6, "ws", "repo", "deep"))
        os.environ["CLAUDE_CONFIG_DIR"] = os.path.join(_t6, "cfg")
        _found = auto_memory_dir(os.path.join(_t6, "ws", "repo", "deep"))
        case("the store is found from a nested repo by walking up to the workspace",
             _found == _proj, _found or "(not found)")
        _cands = auto_memory_candidates(os.path.join(_t6, "ws", "repo", "deep"))
        case("MEMORY.md is an index, not a candidate",
             [c[0] for c in _cands] == ["a-real-note"], f"{len(_cands)} candidate(s)")

        # AN EMPTY MEMORY DIRECTORY IS NOT A MATCH. Claude Code creates them eagerly, and
        # stopping the walk at one would hide the real notes one level up. Measured: 4 of 8
        # stores on this machine are empty.
        _empty = os.path.join(_t6, "cfg", "projects",
                              _encode_project_dir(os.path.join(_t6, "ws", "repo")), "memory")
        os.makedirs(_empty)
        case("an EMPTY store does not stop the walk",
             auto_memory_dir(os.path.join(_t6, "ws", "repo", "deep")) == _proj,
             "the eagerly-created empty directory is skipped")

        # AND NO STORE AT ALL SAYS NOTHING, rather than reporting an absence as a finding.
        os.environ["CLAUDE_CONFIG_DIR"] = os.path.join(_t6, "nothing-here")
        case("no store is [] and not an error",
             auto_memory_candidates(os.path.join(_t6, "ws")) == [], "silent, as it must be")
    finally:
        if _saved_cfg is None:
            os.environ.pop("CLAUDE_CONFIG_DIR", None)
        else:
            os.environ["CLAUDE_CONFIG_DIR"] = _saved_cfg
        shutil.rmtree(_t6, ignore_errors=True)

    _saved_which = shutil.which
    try:
        shutil.which = lambda name: None
        _n = delegation_share_note()
        case("an absent localcoder-history reads as not measured, never as a percentage",
             "not measured" in _n and "%" not in _n, _n.strip())
    finally:
        shutil.which = _saved_which

    case("the mirror argv matches localcoder's documented flag order",
         argv[1:4] == ["--outcome", "abc123", "accepted"],
         "--outcome takes <id> <value> positionally; a reordered argv would be parsed as "
         "task text")

    # The lock must actually be exclusive.
    lockpath = os.path.join(d, "l.lock")
    with Lock(lockpath, timeout=0.2):
        try:
            with Lock(lockpath, timeout=0.2):
                case("the lock is exclusive", False, "a second holder got in")
        except TimeoutError:
            case("the lock is exclusive", True)

    shutil.rmtree(d, ignore_errors=True)
    print()
    if bad:
        print(f"{len(bad)} FAILED: {', '.join(bad)}")
        return 1
    print("close_out: all selftests passed")
    return 0


def main():
    ap = argparse.ArgumentParser(
        description="Record what happened to a delegated draft, after the gates ran.")
    ap.add_argument("--row-id", help="the log_row_id the drafting tool returned")
    ap.add_argument("--tool",
                    help="what produced the work, when there is no draft log to key on: "
                         "ollama, llama.cpp, lm-studio, manual. Use INSTEAD of --row-id for "
                         "a local model driven directly (scaffold adoption options 3 and 4)")
    ap.add_argument("--outcome", choices=OUTCOMES)
    ap.add_argument("--gate", choices=GATES,
                    help="the repository gate result. Required: an outcome with no "
                         "verification beside it is an opinion.")
    ap.add_argument("--actor", help="who judged it (default: $USER)")
    ap.add_argument("--summary", help="one line: what happened")
    ap.add_argument("--files", help="comma-separated files touched")
    ap.add_argument("--json", action="store_true", help="machine-readable result")
    ap.add_argument("--distill", action="store_true",
                    help="write a dated SKELETON entry into ai/SESSION.md from the journal "
                         "and the git log since the newest dated entry. Idempotent.")
    ap.add_argument("--from", dest="sources", action="append", default=[], metavar="PATH",
                    help="--distill only: another repository whose history belongs in this "
                         "log. Repeatable. A -dev repo needs this: its own log holds only "
                         "its scaffold upgrades, and the work it records happened elsewhere.")
    ap.add_argument("--dry-run", action="store_true",
                    help="--distill only: print the skeleton instead of writing it")
    ap.add_argument("--auto-memory-status", action="store_true",
                    dest="auto_memory_status",
                    help="count auto-memory notes and how many were never promoted (#300); "
                         "advisory, always exit 0")
    ap.add_argument("--selftest", action="store_true")
    args = ap.parse_args()

    if args.selftest:
        return selftest()
    if args.auto_memory_status:
        return print_auto_memory_status()
    if args.distill:
        return distill(dry_run=args.dry_run, sources=args.sources)
    if args.row_id and args.tool:
        print("close_out: REFUSED — pass --row-id OR --tool, not both. A row-id means a "
              "draft log entry exists to mirror into; --tool means it does not.")
        return 2

    # THE RECORD MUST REACH ai/ FROM EVERY ADOPTION PATH, not only the one with localcoder in
    # it. Options 3 and 4 drive a local runtime directly, so there is no draft log and no
    # row-id -- and until now that meant no way to record anything at all, which left the
    # shared history with a hole exactly where the local work happened.
    row_id, mirror = args.row_id, True
    if args.tool:
        # A SUMMARY IS NOT OPTIONAL HERE, and it is optional for a draft row. With a draft
        # log behind it the prompt, the model and the diff are all recoverable; with --tool
        # this line is the ONLY record that the work ever happened.
        if not (args.summary or "").strip():
            print("close_out: REFUSED — --tool needs --summary. There is no draft log behind "
                  "this row, so the summary is the only record of what was done.")
            return 2
        row_id = manual_row_id(args.tool, args.summary, datetime.date.today().isoformat())
        mirror = False

    if not (row_id and args.outcome and args.gate):
        ap.print_help()
        print("\n  --outcome and --gate are required, plus EITHER --row-id or --tool.")
        print("  The gate is required BY DESIGN: this tool exists so that an acceptance")
        print("  cannot be recorded without saying whether anything verified it.")
        print("  --tool is for adoption options 3 and 4, where a local runtime is driven")
        print("  directly and there is no draft log to key on.")
        return 2

    files = [f.strip() for f in (args.files or "").split(",") if f.strip()]
    _sum = args.summary
    if args.tool:
        # NAME THE PRODUCER IN THE ROW ITSELF. The table has six columns and a selftest holds
        # it to six; widening it would orphan every row already written. The summary is where
        # provenance fits without changing the shape.
        _sum = f"[{args.tool}] {args.summary}"
    rc, msg = close_out(row_id, args.outcome, args.gate, actor=args.actor,
                        summary=_sum, files=files, mirror=mirror)
    if rc == 0 and not mirror:
        # SKIPPED, AND SAID SO. A silent skip of the mirror is indistinguishable from a
        # mirror that ran, which is the failure mode this whole file argues against.
        print("close_out: no draft log to mirror into (--tool), so the outcome was written "
              "to ai/SESSION.md only.")
    if rc == 0 and not args.json:
        print(delegation_share_note())
    if args.json:
        print(json.dumps({"status": "ok" if rc == 0 else "refused", "exit_code": rc,
                          "row_id": row_id, "tool": args.tool, "outcome": args.outcome,
                          "gate": args.gate, "message": msg}))
    else:
        print(("close_out: " if rc == 0 else "close_out: REFUSED — ") + msg)
    return rc


if __name__ == "__main__":
    sys.exit(main())
