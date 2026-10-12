#!/usr/bin/env python3
# Project:  ai-project-scaffold
# File:     tools/correction_capture.py
# Modified: 2026-09-22
# Version:  0.3.0.20260922.1538
# Purpose:  Capture a correction VERBATIM at the moment it is given, because the thing that
#           gets lost is not the decision, it is the sentence that produced it.
# Changelog:
#   2026-09-22 v0.3.0.20260922.1538 — EVERY ROW NAMES ITS SPEAKER (Clocktower #7). A peer
#                                     session's sentence landed in the journal as
#                                     'correction candidate [directive]' with no speaker --
#                                     the tool that preserves the owner's words promoted a
#                                     peer's to a standing instruction. Rows now carry
#                                     speaker=owner|peer|relayed|unattributed (origin.kind,
#                                     <cross-session-message>, a TO:/FROM: routing header on
#                                     line 1); only owner rows keep a rule label or count
#                                     toward rule health. Rows are stamped with the TURN's
#                                     time, not the capture's, which is what put 12:54
#                                     inside an 08-09 block. One sentence of context rides
#                                     with each quote. Both mutations proved red.
#   2026-08-26 v0.2.0 — PATTERN HEALTH (#242): --health reports promoted/captured per rule and
#                        --promote records one. It needs no inference, because the acceptance
#                        signal already exists and a person already makes it: step 3 of
#                        "Corrections are learnings" is a human writing a correction into
#                        ai/MEMORY.md. All that was missing was which rule found it.
#                        A rule with zero promotions across >=5 captures is NAMED as dead --
#                        a report that cannot say so is decoration.
#                        DELIBERATELY NOT the source project's --use-meta, which feeds the
#                        score back into detection confidence: a keyword scorer tuning its own
#                        scores, with nobody reading the result. Nothing here adjusts anything.
#   2026-08-26 v0.1.1 — LICENCE CORRECTED, and this is not a footnote. The source below was
#                        recorded as MIT on the strength of its README. It has NO LICENSE
#                        FILE: `GET /repos/.../license` is 404 and the root listing has no
#                        LICENSE/LICENCE/COPYING. GitHub's default for an unlicensed public
#                        repo is all rights reserved, so a licence named in prose is not the
#                        grant. No exposure here -- what was taken is the IDEA of capturing on
#                        the Stop hook, every line below was written here, and their MEDIUM
#                        and LOW tiers are not implemented at all -- but nothing may be COPIED
#                        from that repository until a real licence exists. Recorded in
#                        ai/PROVENANCE.md, which is the file that made the check happen.
#                        ALSO: we evaluated v1.0.0 while v1.3.0 had been out a month, and both
#                        criticisms below have upstream answers. See ai/PROVENANCE.md.
#   2026-08-26 v0.1.0 — Initial. The idea is taken from haddock-development/claude-reflect-system
#                        (licence: NONE DECLARED -- see ai/PROVENANCE.md); the inferring half is NOT taken,
#                        and the reason is measured rather than aesthetic. That project scores
#                        matches into HIGH/MEDIUM/LOW confidence and then EDITS SKILL FILES
#                        from them. This project has already measured that exact instrument
#                        twice: localcoder #185 (gotcha selection ranks by keyword and ranks
#                        the wrong entry first) and the SPL time-bound advisory, which fired
#                        53 times against real saved searches and was NOISE 41 of those times
#                        -- 85% wrong, narrowed to 12 rules, most of it deleted. A keyword
#                        scorer that writes to files is that same instrument pointed at the
#                        record itself.
#
#                        So this tool keeps their good half and drops their inferring half:
#                          - It CAPTURES. It never classifies, never scores, never rewrites
#                            any file except by appending to the journal.
#                          - It quotes the matched SENTENCE verbatim, not a paraphrase and
#                            not the whole message.
#                          - MEDIUM and LOW are not implemented at all. "Yes, that's exactly
#                            right" confirms one instance and is not a rule; "have you
#                            considered X" is a question. Both are pure noise generators in
#                            a file whose value is that it is short enough to read.
#
# THE SPLIT THIS PRESERVES, from tools/session_journal.sh
#   Hooks capture FACTS. The agent writes NARRATIVE. A sentence the user actually typed is a
#   fact. What it MEANT is narrative, and a hook that guesses at it produces the journal
#   nobody reads -- which is the failure mode session_journal.sh v0.3.0 was written to fix
#   when it was logging itself on every turn.
#
# WHY THIS IS NEEDED AT ALL, stated as the failure it prevents
#   ai/SESSION.md is written at the end. ai/MEMORY.md gets a gotcha when someone remembers to
#   write one. On 2026-08-25 this programme shipped fourteen releases across four repos with
#   ZERO session entries, while tools/session_currency.sh printed BEHIND on every preflight
#   run and preflight logged it `ok` because --check is advisory. Discipline had already been
#   tried and had already failed twice in the same file. Capture is not a substitute for
#   writing the record; it is what makes writing it possible hours later.
#
# WHAT IT WILL NOT DO, and these are safety properties with tests
#   - It will not write outside ai/SESSION_JOURNAL.md.
#   - It will not emit a secret. Every captured sentence is redacted first (see redact()).
#     The journal is a file people paste into issues; a correction that names a token would
#     put that token somewhere it was never meant to go, and secret_scan.sh does not read it.
#   - It will not capture from anything but a real user turn. In a Claude Code transcript,
#     tool results, command stdout and <system-reminder> blocks all arrive with role=user.
#     They are not the user speaking, and the negative half of the selftest is mostly this.
#   - It will not fail a session. Every path returns 0 to a hook caller.

import argparse
import json
import os
import re
import sys
import tempfile
from datetime import datetime, timezone

STATE_NAME = ".correction-capture-state"
HEALTH_NAME = ".correction-capture-health"
JOURNAL_REL = os.path.join("ai", "SESSION_JOURNAL.md")

# ---------------------------------------------------------------- the patterns
#
# NARROW ON PURPOSE. Every pattern here is an EXPLICIT correction -- the user rejecting a
# thing and/or naming the replacement. There is no tier below this one, because the tiers
# below it are where a keyword scorer earns its 85% noise rate.
#
# Each entry is (name, compiled regex). The name is recorded so that a bad pattern can be
# identified and removed from evidence rather than from memory -- see --measure.
# THE EXPLICIT MARKER, and it is not my invention -- ai/STANDARDS.md -> "Corrections are
# learnings" already declares it: *"A human-typed `remember:` prefix marks something as a
# learning explicitly -- honor it in any tool, no tooling required."* This is the tooling.
# It is the only rule that BYPASSES MAX_TURN, because a person who typed the marker has
# stated intent, and a heuristic must not overrule a statement.
REMEMBER = re.compile(r"(?:^|\n)\s*remember\s*[:\-—]\s*(.+)", re.I)

PATTERNS = [
    # "no, don't use pip directly, use uv instead" / "no - not the 27b"
    ("negation", re.compile(
        r"\b(?:no|nope)\b[,\s—-]+(?:(?:that|this|it)(?:'s| is)\s+not|do\s?n[o']t|don't|not)\b",
        re.I)),
    # "use uv instead of pip" -- IMPERATIVE `use`, at a clause boundary. The loose form,
    # a bare \binstead of\b, was 0 for 12 on a real transcript: every match was comparative
    # prose ("cost 7 minutes instead of 11", "142 instead of 124").
    ("use-instead", re.compile(
        r"(?:^|[.!?;]\s+|\n)\s*(?:please\s+)?use\b[^.!?]{1,90}?\binstead\b", re.I)),
    # "use the 27b model, not the 4b" -- same imperative anchor, for the same reason.
    ("use-not", re.compile(
        r"(?:^|[.!?;]\s+|\n)\s*(?:please\s+)?use\b[^.!?]{1,80}?,\s*not\b", re.I)),
    # "actually, the flag is --strict"
    ("actually", re.compile(r"(?:^|[.!?]\s+|\n)\s*actually\b", re.I)),
    # "Never background a mutation harness." -- SENTENCE-INITIAL, so it is an instruction
    # rather than a description. The loose form, \b(never|always)\b\s+\w+, was ~2 for 40:
    # "that copy never runs", "it never asserts anything USES it", "never drifted".
    ("imperative-rule", re.compile(r"(?:^|[.!?]\s+|\n)\s*(?:never|always)\s+\w+", re.I)),
    # "stop doing X"
    ("stop-doing", re.compile(r"\bstop\s+\w+ing\b", re.I)),
    # "that's wrong" / "this is incorrect"
    ("wrong", re.compile(r"\b(?:that|this|it)(?:'s| is)\s+(?:wrong|incorrect|backwards)\b", re.I)),
    # "don't <verb>" as a bare directive
    ("directive", re.compile(r"(?:^|[.!?]\s+|\n)\s*(?:do\s?n[o']t|don't)\s+\w+", re.I)),
]

# A CORRECTION IS SHORT AND DIRECTED. A PASTED REPORT IS NEITHER.
#
# This is the single highest-value filter in the file and it is not a guess. On a real
# 484-turn transcript the user-turn length distribution is bimodal: median 134 characters,
# p75 364 -- and p90 2057, p95 13255. The long tail is entirely pasted material, agent
# reports relayed into the conversation, which is technical prose full of "never", "instead
# of" and "not". That population produced 56 of the 63 matches the first draft of this file
# made, and none of them were corrections.
MAX_TURN = 2000

# Sentences shorter than this are not corrections, they are noise ("no.", "wrong").
MIN_SENTENCE = 12
# A captured quote longer than this is a pasted document, not a sentence someone typed.
MAX_QUOTE = 400

# ---------------------------------------------------------------- redaction
#
# A CORRECTION CAN CARRY A CREDENTIAL. "no, use the token sk-abc... instead" is a perfectly
# ordinary correction and an exfiltration if it lands in a file that gets pasted into an
# issue. secret_scan.sh does not read the journal, so this is the only thing standing there.
REDACTIONS = [
    (re.compile(r"\b(?:sk|pk|gh[pousr]|xox[baprs]|AKIA|ASIA)[-_A-Za-z0-9]{10,}"), "[redacted-key]"),
    (re.compile(r"\beyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{5,}"), "[redacted-jwt]"),
    (re.compile(r"(?i)\b(?:bearer|token|password|passwd|secret|api[-_]?key)\b\s*[:=]?\s*\S{8,}"),
     "[redacted-credential]"),
    # A bare high-entropy blob: 32+ chars of base64/hex with no spaces.
    (re.compile(r"\b[A-Za-z0-9+/_-]{40,}={0,2}\b"), "[redacted-blob]"),
]


def redact(text):
    """Remove anything credential-shaped. Applied to every quote before it is written."""
    for pat, repl in REDACTIONS:
        text = pat.sub(repl, text)
    return text


# ---------------------------------------------------------------- transcript reading
#
# ROLE=USER IS NOT THE SAME AS "THE USER SAID IT". In a Claude Code transcript the user role
# also carries tool results, the stdout of a `!` command, hook output and <system-reminder>
# blocks. Capturing from those produces a journal full of the project's own text quoted back
# at it, which is exactly the "logs itself every turn" failure session_journal.sh already had.
# WHO SAID IT, BECAUSE A ROLE=USER TURN IS NOT ALWAYS THE OWNER. Clocktower's audit found a
# peer session's text in ai/SESSION_JOURNAL.md as `correction candidate [directive]` with no
# speaker -- a peer's sentence promoted to the owner's standing instruction by the tool meant
# to preserve the owner's words. Three ways a non-owner reaches a user turn on this estate:
#   peer         the client delivers another session's message (origin.kind == "peer", or a
#                <cross-session-message> block) -- flagged isMeta by some client versions only
#   relayed      the owner PASTES a peer's prompt from his phone; the routing convention puts
#                a `TO: <ROLE>` header on line 1 of every such prompt, so the header is the tell
#   unattributed no origin field at all (older transcripts): we do not know, so we do not say
# Only "owner" rows keep their rule label; every other row is labelled by its speaker, so no
# reader can mistake it for a directive.
RELAY_HEADER = re.compile(r"\A\s*(?:```[^\n]*\n\s*)?(?:TO|FROM)\s*:\s*[A-Z][A-Z0-9_-]{2,}")


def speaker_of(rec, text):
    origin = rec.get("origin") if isinstance(rec.get("origin"), dict) else {}
    kind = origin.get("kind")
    if kind == "peer" or "<cross-session-message" in text \
            or text.lstrip().startswith("Another Claude session sent a message"):
        return "peer"
    if RELAY_HEADER.search(text):
        return "relayed"
    if kind == "human":
        return "owner"
    return "unattributed"


def turn_stamp(rec):
    """The TURN's time, not the capture's. Capture runs at Stop, so stamping rows with 'now'
    put a 12:54 capture inside an 08-09 block -- rows out of order with what they record."""
    ts = str(rec.get("timestamp") or "")
    m = re.match(r"(\d{4}-\d{2}-\d{2})T(\d{2}:\d{2}:\d{2})", ts)
    if m:
        return f"{m.group(1)} {m.group(2)}"
    return datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S")


def user_texts(path, after_uuid=None, with_info=False):
    """Yield (uuid, text) for genuine user turns, in order, after `after_uuid` if given.
    with_info=True yields (uuid, text, {"speaker": ..., "ts": ...})."""
    seen_marker = after_uuid is None
    try:
        fh = open(path, "r", errors="replace")
    except OSError:
        return
    with fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            try:
                rec = json.loads(line)
            except (ValueError, TypeError):
                continue
            uuid = rec.get("uuid") or ""
            if not seen_marker:
                if uuid and uuid == after_uuid:
                    seen_marker = True
                continue
            if rec.get("type") != "user":
                continue
            # A meta/sidechain turn is the harness talking, not a person.
            if rec.get("isMeta") or rec.get("isSidechain"):
                continue
            msg = rec.get("message") or {}
            content = msg.get("content")
            parts = []
            if isinstance(content, str):
                parts = [content]
            elif isinstance(content, list):
                for item in content:
                    if not isinstance(item, dict):
                        continue
                    # tool_result carries command output. Never a correction.
                    if item.get("type") != "text":
                        continue
                    parts.append(item.get("text") or "")
            text = "\n".join(p for p in parts if p)
            if text:
                if with_info:
                    yield uuid, text, {"speaker": speaker_of(rec, text), "ts": turn_stamp(rec)}
                else:
                    yield uuid, text


SENTENCE_SPLIT = re.compile(r"(?<=[.!?])\s+|\n+")
REMINDER = re.compile(r"<system-reminder>.*?</system-reminder>", re.S | re.I)
TAGBLOCK = re.compile(r"<(command-name|command-message|local-command-stdout|"
                      r"command-args|function_results|bash-stdout|bash-stderr)\b.*?</\1>", re.S | re.I)


def candidate_sentences(text):
    """Split a user turn into sentences that are plausibly things a person typed."""
    text = REMINDER.sub(" ", text)
    text = TAGBLOCK.sub(" ", text)
    # Applied AFTER stripping harness blocks, so a short turn carrying a big
    # <system-reminder> is still read.
    if len(text) > MAX_TURN:
        return []
    stripped = text.strip()
    # A turn that IS a slash command, or that opens with a tag, is harness traffic.
    if stripped.startswith("/") and "\n" not in stripped[:40]:
        return []
    if stripped.startswith("<"):
        return []
    # A continuation summary injected after /compact is the harness quoting itself.
    if stripped.startswith("This session is being continued from a previous conversation"):
        return []
    out = []
    for raw in SENTENCE_SPLIT.split(text):
        s = " ".join(raw.split())
        if len(s) < MIN_SENTENCE:
            continue
        # A fenced-code or diff line is not a sentence.
        if s.startswith(("```", "|", "+", "-", ">", "#", "$")):
            continue
        out.append(s)
    return out


def find_corrections(text, with_context=False):
    """Return [(pattern_name, sentence)] for a single user turn; with_context=True returns
    (pattern_name, sentence, previous_sentence_or_"") -- one sentence of context, because a
    bare "Never do that." is unreadable a day later."""
    hits = []
    # The explicit marker first, and outside the length filter. See REMEMBER above.
    marker_src = REMINDER.sub(" ", text)
    marker_src = TAGBLOCK.sub(" ", marker_src)
    for m in REMEMBER.finditer(marker_src):
        said = " ".join(m.group(1).split())
        if len(said) >= MIN_SENTENCE:
            quote = said if len(said) <= MAX_QUOTE else said[:MAX_QUOTE - 1] + "\u2026"
            hits.append(("remember", redact(quote), ""))
    prev = ""
    for sentence in candidate_sentences(text):
        for name, pat in PATTERNS:
            if pat.search(sentence):
                quote = sentence if len(sentence) <= MAX_QUOTE else sentence[:MAX_QUOTE - 1] + "…"
                ctx = prev if len(prev) <= MAX_QUOTE else prev[:MAX_QUOTE - 1] + "…"
                hits.append((name, redact(quote), redact(ctx)))
                break  # one line per sentence, whichever pattern caught it
        prev = sentence
    if with_context:
        return hits
    return [(n, q) for n, q, _c in hits]


# ---------------------------------------------------------------- pattern health
#
# `--measure` counts precision BY HAND, ONCE, against one transcript. That is how the shipped
# rules got from 63 matches to 3, and it is a one-off: nothing tracks whether a rule stays
# good after the day it was calibrated.
#
# THE ACCEPTANCE SIGNAL ALREADY EXISTS AND A PERSON ALREADY MAKES IT. ai/STANDARDS.md ->
# "Corrections are learnings" is capture, review, apply. Step 3 -- a human deciding a
# correction is recurring and writing it into ai/MEMORY.md -- IS the judgement. All that was
# missing is recording which rule produced the candidate that earned it.
#
#     pattern health = promoted / captured, per rule
#
# Measured, not remembered. A rule at 0-for-15 is the `instead of` rule again and should be
# deleted; a rule at 12-for-14 has earned the right to be widened.
#
# WHAT THIS DELIBERATELY IS NOT. The source project's v1.3.0 pairs this with `--use-meta`,
# which feeds the score back into detection confidence. That is the loop closing on itself: a
# keyword scorer tuning its own keyword scores, with nobody reading the result. The value here
# is the NUMBER, which tells a person which rule to delete. Nothing here adjusts anything.
def _health_path(root):
    return os.path.join(root, HEALTH_NAME)


def read_health(root):
    try:
        with open(_health_path(root), encoding="utf-8") as fh:
            data = json.load(fh)
    except (OSError, ValueError):
        return {"captured": {}, "promoted": {}}
    if not isinstance(data, dict):
        return {"captured": {}, "promoted": {}}
    return {"captured": dict(data.get("captured") or {}),
            "promoted": dict(data.get("promoted") or {})}


def _write_health(root, data):
    try:
        fd, tmp = tempfile.mkstemp(dir=root, prefix=".cchealth")
        with os.fdopen(fd, "w") as fh:
            json.dump(data, fh, indent=2, sort_keys=True)
        os.replace(tmp, _health_path(root))
    except OSError:
        pass


def bump(root, kind, rule, n=1):
    """Record one capture or one promotion for `rule`. Never raises."""
    data = read_health(root)
    side = data.setdefault(kind, {})
    side[rule] = int(side.get(rule, 0)) + n
    _write_health(root, data)
    return data


def health_report(root):
    """promoted/captured per rule, worst first. Returns (lines, any_dead)."""
    data = read_health(root)
    cap, pro = data["captured"], data["promoted"]
    rules = sorted(set(cap) | set(pro))
    if not rules:
        return (["no captures recorded yet — nothing to report.",
                 "Health accrues as corrections are captured and promoted; it is not "
                 "derivable from the rules alone."], False)
    rows, dead = [], False
    for r in sorted(rules, key=lambda k: (pro.get(k, 0) / max(cap.get(k, 0), 1), -cap.get(k, 0))):
        c, pm = int(cap.get(r, 0)), int(pro.get(r, 0))
        rate = (pm / c * 100) if c else 0.0
        note = ""
        # A RULE THAT HAS NEVER EARNED A PROMOTION IS THE FINDING, so it is named rather than
        # left for the reader to spot in a column. A health report that cannot say "this rule
        # is dead" is decoration.
        if c >= 5 and pm == 0:
            note = "  <-- 0 promotions in %d captures: delete it, do not tune it" % c
            dead = True
        rows.append(f"  {pm:>4}/{c:<4} {rate:>5.1f}%  {r}{note}")
    return (["promoted/captured, per rule (worst first):", ""] + rows, dead)


# ---------------------------------------------------------------- state
def read_state(root):
    try:
        with open(os.path.join(root, STATE_NAME)) as fh:
            return (fh.read().strip() or None)
    except OSError:
        return None


def write_state(root, uuid):
    if not uuid:
        return
    path = os.path.join(root, STATE_NAME)
    try:
        # Atomic: a half-written state file re-captures the whole transcript next turn.
        fd, tmp = tempfile.mkstemp(dir=root, prefix=".ccstate")
        with os.fdopen(fd, "w") as fh:
            fh.write(uuid + "\n")
        os.replace(tmp, path)
    except OSError:
        pass


# ---------------------------------------------------------------- the capture
def capture(root, transcript, dry_run=False):
    """Append correction candidates to the journal. Returns the number written."""
    after = read_state(root)
    last_uuid = after
    rows = []
    for uuid, text, info in user_texts(transcript, after_uuid=after, with_info=True):
        last_uuid = uuid or last_uuid
        for name, quote, ctx in find_corrections(text, with_context=True):
            rows.append((name, quote, ctx, info["speaker"], info["ts"]))
    if dry_run:
        for name, quote, _ctx, who, _ts in rows:
            print(f"{name if who == 'owner' else who}\t{who}\t{quote}")
        return len(rows)
    if rows:
        journal = os.path.join(root, JOURNAL_REL)
        try:
            os.makedirs(os.path.dirname(journal), exist_ok=True)
            with open(journal, "a") as fh:
                for name, quote, ctx, who, stamp in rows:
                    # VERBATIM AND UNJUDGED. The pattern name is provenance, not a verdict:
                    # it says which rule fired so a bad rule can be removed from evidence.
                    # It is shown ONLY for the owner's words; anything else is labelled by
                    # who said it, and never counts toward a rule's health.
                    if who == "owner":
                        bump(root, "captured", name)
                    label = name if who == "owner" else f"{who} — not the owner's words"
                    after_txt = f' (after: "{ctx}")' if ctx else ""
                    fh.write(f'- {stamp} — correction candidate [{label}] speaker={who}: '
                             f'"{quote}"{after_txt}\n')
        except OSError:
            return 0
    write_state(root, last_uuid)
    return len(rows)


# ---------------------------------------------------------------- selftest
#
# BOTH DIRECTIONS, because the scaffold's own rule -- probe on VALID and INVALID input before
# declaring a checker works -- is the rule that disqualified `sqlfluff lint` and put three
# languages in the formatter tier. A capture tool that matches everything passes any test
# that only feeds it corrections, and then fills the journal with the project's own prose.
POSITIVE = [
    ("no, don't use pip directly, use uv instead", "negation"),
    ("Use uv instead of pip for every install in this repo.", "use-instead"),
    ("Actually, the flag is --strict and not --check.", "actually"),
    ("Never background a mutation harness, it restores over live edits.", "imperative-rule"),
    ("stop reformatting the whole file when you touch one line", "stop-doing"),
    ("That's wrong — the tag is written after the commit.", "wrong"),
    ("Don't push without running preflight first.", "directive"),
    ("use the 27b model, not the 4b, for anything that cites files", "use-not"),
    ("remember: the tag is written after the commit, never before", "remember"),
    ("Remember - preflight before push, always", "remember"),
]

NEGATIVE = [
    # Harness traffic wearing a user role.
    "<system-reminder>Remember to always check CI after every push.</system-reminder>",
    "<local-command-stdout>never mind</local-command-stdout>",
    "/compact",
    "This session is being continued from a previous conversation that ran out of context.",
    # Too short to be a correction.
    "no",
    "nope",
    # Ordinary prose that a looser matcher would grab.
    "Can you check whether the mirror workflow ran?",
    "The release notes look good to me, ship it.",
    "I think the M3 is still running the benchmark.",
    # Code and diffs.
    "```python\nif never_seen: pass\n```",
    "+   use_cache = False  # instead of the old path",
    # REAL FALSE POSITIVES, taken from a 484-turn transcript this tool was measured against.
    # The first draft matched all of these. They are prose, not instructions, and they are
    # here so that loosening a pattern back has to break a test rather than a journal.
    "The fix being in 0.36.0 is irrelevant — that copy never runs.",
    "It never asserts anything USES it.",
    "It did fire and was correct; it is the reason #136 cost 7 minutes instead of 11.",
    "The exit code surfaced as 142 instead of 124.",
    "Thinking about another use case, not localcoder per say, but the pentesting cases.",
    "The `$ROOT` predicate is the right shape — one place to reason about instead of nine.",
]


def selftest():
    fails = 0

    def chk(label, expected, actual):
        nonlocal fails
        if expected == actual:
            print(f"  ok   {label[:58]:<58}")
        else:
            print(f"  FAIL {label[:58]:<58} expected={expected} got={actual}")
            fails += 1

    print("correction_capture selftest — it must MISS things, or it is not a filter")

    for text, want in POSITIVE:
        hits = find_corrections(text)
        chk(f"matches: {text[:40]}", True, len(hits) > 0)
        if hits:
            chk(f"  ...via {want}", want, hits[0][0])

    for text in NEGATIVE:
        hits = find_corrections(text)
        chk(f"ignores: {text[:40]!r}", 0, len(hits))

    # Redaction is a safety property, so it is tested as one.
    red = redact("no, use the token ghp_abcdefghijklmnopqrstuvwxyz012345 instead")
    chk("a github token is redacted", True, "ghp_abcdef" not in red)
    red2 = redact("actually the password: hunter2hunter2 is wrong")
    chk("a labelled credential is redacted", True, "hunter2hunter2" not in red2)
    chk("and the sentence survives redaction", True, "actually" in red2.lower())

    # THE EXPLICIT MARKER OUTRANKS THE HEURISTICS, including the length filter. A person who
    # typed `remember:` has stated intent; a turn-length guess must not overrule a statement.
    long_marked = ("filler text here. " * 200) + "\nremember: never push without preflight"
    chk("`remember:` is honoured past MAX_TURN", True,
        any(n == "remember" for n, _ in find_corrections(long_marked)))
    chk("  and only the marked sentence is taken", True,
        all("filler" not in q for n, q in find_corrections(long_marked) if n == "remember"))

    # A PASTED REPORT IS SKIPPED WHOLE. This is the filter that took the match count on a
    # real transcript from 63 to 3; without a test, loosening MAX_TURN silently restores 60
    # lines of noise to a file whose only value is being short enough to read.
    pasted = ("Never mind the preamble. " * 5) + ("x" * MAX_TURN)
    chk("a turn over MAX_TURN is skipped entirely", 0, len(find_corrections(pasted)))
    chk("  but the same sentence alone IS caught", True,
        len(find_corrections("Never mind the preamble.")) > 0)

    # The quote is capped, so a pasted document cannot land in the journal whole.
    long_hit = find_corrections("Actually, " + ("x" * 900) + ".")
    chk("a pasted wall of text is capped", True,
        bool(long_hit) and len(long_hit[0][1]) <= MAX_QUOTE)

    # End to end, against a transcript in the real shape, including the traps.
    tmp = tempfile.mkdtemp()
    try:
        os.makedirs(os.path.join(tmp, "ai"), exist_ok=True)
        tpath = os.path.join(tmp, "t.jsonl")
        with open(tpath, "w") as fh:
            recs = [
                {"type": "user", "uuid": "u1", "origin": {"kind": "human"},
                 "timestamp": "2026-09-20T08:10:00.000Z",
                 "message": {"content": "That breaks the lockfile. no, don't use pip, use uv instead"}},
                # tool_result must never be read as speech
                {"type": "user", "uuid": "u2",
                 "message": {"content": [{"type": "tool_result",
                                          "content": "error: never mind, that's wrong"}]}},
                {"type": "assistant", "uuid": "a1", "message": {"content": "ok"}},
                {"type": "user", "uuid": "u3", "isMeta": True,
                 "message": {"content": "Actually this is a meta turn and must be skipped."}},
                {"type": "user", "uuid": "u4", "origin": {"kind": "human"},
                 "timestamp": "2026-09-20T08:20:00.000Z",
                 "message": {"content": [{"type": "text",
                                          "text": "Always commit before running preflight."}]}},
                # CLOCKTOWER #7: three non-owner speakers, each wearing role=user.
                {"type": "user", "uuid": "u5", "origin": {"kind": "peer", "from": "x"},
                 "timestamp": "2026-09-20T08:30:00.000Z",
                 "message": {"content": "Never merge without asking the peer first."}},
                {"type": "user", "uuid": "u6", "origin": {"kind": "human"},
                 "timestamp": "2026-09-20T08:40:00.000Z",
                 "message": {"content": "```\nTO: CONTROL — release\nNever release on a Friday.\n```"}},
                {"type": "user", "uuid": "u7",
                 "timestamp": "2026-09-20T08:50:00.000Z",
                 "message": {"content": "Always pin every action to a SHA."}},
            ]
            for r in recs:
                fh.write(json.dumps(r) + "\n")

        n = capture(tmp, tpath)
        chk("end to end captures the two owner corrections + 3 labelled others", 5, n)
        with open(os.path.join(tmp, JOURNAL_REL)) as fh:
            body = fh.read()
        rows = body.splitlines()
        chk("  every row names its speaker", True, all(" speaker=" in r for r in rows))
        chk("  an owner row keeps its rule label", True,
            any("[negation] speaker=owner" in r for r in rows))
        chk("  a PEER's sentence is never a directive", True,
            any("merge without asking" in r and "speaker=peer" in r and "[peer" in r
                for r in rows) and not any("merge without" in r and "[imperative" in r
                                           for r in rows))
        chk("  a RELAYED prompt (TO: header) is labelled relayed", True,
            any("Friday" in r and "speaker=relayed" in r for r in rows))
        chk("  no origin at all is unattributed, not the owner", True,
            any("pin every action" in r and "speaker=unattributed" in r for r in rows))
        chk("  rows carry the TURN's time, in turn order", True,
            [r[2:21] for r in rows] == sorted(r[2:21] for r in rows)
            and rows[0].startswith("- 2026-09-20 08:10:00"))
        chk("  one sentence of context rides with the quote", True,
            '(after: "That breaks the lockfile.")' in body)
        chk("  the tool_result was not captured", True, "never mind" not in body)
        chk("  the meta turn was not captured", True, "meta turn" not in body)
        chk("  the quote is verbatim", True, "use uv instead" in body)

        # STATE MEANS IT DOES NOT RE-CAPTURE. Without this the journal grows by the whole
        # transcript on every single turn -- the exact defect session_journal.sh v0.3.0 fixed.
        n2 = capture(tmp, tpath)
        chk("a second run captures nothing new", 0, n2)

        # ---- PATTERN HEALTH (#242) ---------------------------------------------------
        # A GENUINELY FRESH ROOT, not `tmp` -- the end-to-end case above has already captured
        # into it, so asserting "fresh" there tests nothing and fails for the right reason.
        _fresh = tempfile.mkdtemp()
        _lines, _ = health_report(_fresh)
        chk("health on a fresh root says so, not an empty table", True,
            any("nothing to report" in ln for ln in _lines))
        import shutil as _sh
        _sh.rmtree(_fresh, ignore_errors=True)

        # A capture must increment its rule's counter, or the denominator is always wrong.
        before = int(read_health(tmp)["captured"].get("negation", 0))
        chk("capturing incremented that rule's count", True, before >= 1)

        bump(tmp, "captured", "negation", 5)
        bump(tmp, "promoted", "negation", 3)
        bump(tmp, "captured", "actually", 8)          # captured often, never promoted
        lines, dead = health_report(tmp)
        body = "\n".join(lines)
        chk("a promoted rule reports a ratio", True, "actually" in body and "negation" in body)
        # THE POINT OF THE REPORT. A rule that never earns a promotion must be NAMED, or the
        # number is decoration and the reader has to spot a zero in a column to act on it.
        chk("a rule with 0 promotions in >=5 captures is named as dead", True, dead)
        chk("  and the advice is DELETE, not tune", True, "delete it, do not tune it" in body)
        chk("health persists across reads", 3,
            int(read_health(tmp)["promoted"].get("negation", 0)))

        # A transcript that does not exist is not a crash.
        chk("a missing transcript is 0, not an exception", 0,
            capture(tmp, os.path.join(tmp, "nope.jsonl")))
    finally:
        import shutil
        shutil.rmtree(tmp, ignore_errors=True)

    print("")
    if fails == 0:
        print("  all checks passed")
        return 0
    print(f"  {fails} check(s) FAILED")
    return 1


# ---------------------------------------------------------------- measure
#
# THE PRECISION NUMBER IS MEASURED OR IT IS NOT CLAIMED. The project this idea came from
# states ">80% precision, >60% recall" as a target to hit before production, with no evidence
# attached. That is a declaration read as coverage, which is the shape ai/STANDARDS.md names.
# This mode runs the patterns over a REAL transcript and prints every match with its rule, so
# the number can be counted by hand against what the transcript actually contains.
def measure(transcript):
    total = 0
    by_rule = {}
    for _uuid, text in user_texts(transcript):
        for name, quote in find_corrections(text):
            total += 1
            by_rule[name] = by_rule.get(name, 0) + 1
            print(f"{name}\t{quote}")
    print("", file=sys.stderr)
    print(f"{total} match(es) across {len(by_rule)} rule(s)", file=sys.stderr)
    for name in sorted(by_rule, key=lambda k: -by_rule[k]):
        print(f"  {by_rule[name]:>4}  {name}", file=sys.stderr)
    print("Read them. A rule whose matches are mostly not corrections should be deleted,",
          file=sys.stderr)
    print("not tuned -- see localcoder #185 and the SPL advisory that was 85% noise.",
          file=sys.stderr)
    return 0


def main(argv):
    ap = argparse.ArgumentParser(
        description="Capture explicit corrections verbatim into ai/SESSION_JOURNAL.md.")
    ap.add_argument("--root", default=os.environ.get("SESSION_JOURNAL_ROOT") or os.getcwd())
    ap.add_argument("--transcript", default=os.environ.get("CLAUDE_TRANSCRIPT_PATH") or "")
    ap.add_argument("--dry-run", action="store_true", help="print what would be captured")
    ap.add_argument("--selftest", action="store_true")
    ap.add_argument("--measure", metavar="TRANSCRIPT",
                    help="print every match with its rule, for counting precision by hand")
    ap.add_argument("--health", action="store_true",
                    help="promoted/captured per rule — which rules have earned their place")
    ap.add_argument("--promote", metavar="RULE",
                    help="record that a candidate from RULE was written into ai/MEMORY.md. "
                         "Run this at closeout, step 3 of 'Corrections are learnings'.")
    args = ap.parse_args(argv)

    if args.selftest:
        return selftest()
    if args.health:
        lines, dead = health_report(args.root)
        for ln in lines:
            print(ln)
        if dead:
            print("")
            print("A rule whose captures are never promoted is not a rule that needs tuning.")
            print("The SPL time-bound advisory fired 53 times, was noise 41 of them, and was")
            print("narrowed by DELETION. See tools/README.md.")
        return 0
    if args.promote:
        if args.promote not in {n for n, _ in PATTERNS} | {"remember"}:
            print(f"correction_capture: {args.promote!r} is not a rule name. Known: "
                  f"{', '.join(sorted({n for n, _ in PATTERNS} | {'remember'}))}",
                  file=sys.stderr)
            return 2
        data = bump(args.root, "promoted", args.promote)
        c = int(data["captured"].get(args.promote, 0))
        pm = int(data["promoted"].get(args.promote, 0))
        print(f"correction_capture: {args.promote} is now {pm}/{c} promoted/captured")
        return 0
    if args.measure:
        return measure(args.measure)
    if not args.transcript or not os.path.exists(args.transcript):
        # NOT AN ERROR. This runs from a Stop hook; a client that does not pass a transcript
        # path, or an older client that passes none, must not colour the session red.
        return 0
    capture(args.root, args.transcript, dry_run=args.dry_run)
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv[1:]))
    except Exception as exc:  # never fail a session
        print(f"correction_capture: {exc}", file=sys.stderr)
        sys.exit(0)
