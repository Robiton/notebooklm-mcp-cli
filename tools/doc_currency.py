#!/usr/bin/env python3
# Project:  ai-project-scaffold
# File:     tools/doc_currency.py
# Modified: 2026-09-11
# Version:  0.1.0.20260911.1156
# Purpose:  Fail when a document describes a source file that has moved on without it.
# Changelog:
#   2026-09-11 v0.1.0.20260911.1156 — THE GATE THAT WAS MISSING, and its absence was measured
#                        rather than theorised. On 2026-09-11 mcp_client.py 0.13.0 -> 0.13.1
#                        changed what happens to an EMPTY credential: it used to be accepted
#                        and sent as `Authorization: Bearer `, and now it refuses. docs/MCP.md
#                        described the old behaviour in FOUR places, including a sentence
#                        promising a 401 that the code no longer lets you reach. Every gate in
#                        the repository passed. Paths resolved, links resolved, every
#                        documented flag existed, the selftests were green, CI was green.
#                        Nothing in the tree relates a document to the code it describes, so
#                        there was nothing that could have noticed.
#                        DECLARED, NOT INFERRED. Firing on every commit that touches a source
#                        file would be noise -- most commits change nothing a reader was told
#                        -- and a noisy gate gets switched off. A document declares the source
#                        it describes AND the version it was last read against; the gate
#                        compares that against the source's current header. The remedy is the
#                        actual work: re-read the document, then move the marker.
#                        IT CANNOT PROVE THE DOCUMENT IS RIGHT. Nothing can. It proves someone
#                        LOOKED since the source last changed, which is the difference between
#                        a document with an owner and one nobody has opened in four months.
#                        A DECLARED SOURCE THAT DOES NOT EXIST IS A FAILURE, not a skip --
#                        otherwise renaming a file retires its documentation silently, which is
#                        the same defect one layer out.
#                        ZERO MARKERS IS REPORTED, NEVER A SILENT PASS. A checker that
#                        examined nothing and a checker that found nothing wrong are different
#                        answers, and this repository has been bitten by that distinction in
#                        four separate tools.
"""Relate a document to the source it describes, and notice when the source moves.

Usage:
    tools/doc_currency.py            report every declared coupling
    tools/doc_currency.py --check    exit 1 if any document is behind its source
    tools/doc_currency.py --selftest

Declare a coupling at column 0 in the document:

    <!-- scaffold:documents src/localcoder/mcp_client.py @ 0.13.1.20260911.0900 -->

Exit codes: 0 verified current, 1 a document is behind, 3 COULD NOT VERIFY.
"""
import os
import re
import subprocess
import sys


# ---------------------------------------------------------------------------------------
# DRAFTED BY localcoder (qwen3.6:27b-mlx), row 812958063402, accepted unmodified.
# Gate: 35/35 contract and edge cases, 20 of which the task did not enumerate -- indentation
# rejection, CRLF, an extra token after the version, leading zeros, five malformed-version
# shapes, and never-raises across 13 hostile strings. Recorded via close_out.py.
# ---------------------------------------------------------------------------------------


def parse_documents_marker(line):
    """Extract source path and version from a scaffold:documents marker line.

    Returns the parsed components so that downstream tooling can locate the
    authoritative definition of a document set. Indented lines are rejected
    to prevent accidental matches inside code blocks or examples.
    """
    if not isinstance(line, str):
        return None

    # Strip trailing newline only; leading whitespace disqualifies the line
    stripped = line.rstrip("\n").rstrip("\r")

    # Must start at column 0 with no leading whitespace
    if stripped != stripped.lstrip():
        return None

    # Match the two allowed forms
    # Form 1: <!-- scaffold:documents PATH @ VERSION -->
    # Form 2: # scaffold:documents PATH @ VERSION
    pattern = (r"^(?:<!--\s*scaffold:documents\s+([\S]+)\s+@\s+([\S]+)\s+-->"
               r"|#\s*scaffold:documents\s+([\S]+)\s+@\s+([\S]+))$")

    match = re.match(pattern, stripped)
    if not match:
        return None

    # Group 1,2 for form 1; group 3,4 for form 2
    if match.group(1) is not None:
        path = match.group(1)
        version = match.group(2)
    else:
        path = match.group(3)
        version = match.group(4)

    # Ensure non-empty (regex [\S]+ guarantees this, but explicit check for safety)
    if not path or not version:
        return None

    return (path, version)


def version_verdict(recorded, current):
    """Compare two dotted numeric version strings to determine staleness.

    Returns "current", "stale", "ahead", or "unparsable". This allows callers
    to decide whether to update a local cache based on the authoritative version.
    Numeric comparison handles leading zeros and unequal field counts correctly.
    """
    if not recorded or not current:
        return "unparsable"

    recorded_fields = recorded.split(".")
    current_fields = current.split(".")

    for field in recorded_fields:
        if not field or not field.isdigit():
            return "unparsable"

    for field in current_fields:
        if not field or not field.isdigit():
            return "unparsable"

    rec_ints = [int(f) for f in recorded_fields]
    cur_ints = [int(f) for f in current_fields]

    min_len = min(len(rec_ints), len(cur_ints))
    for i in range(min_len):
        if rec_ints[i] < cur_ints[i]:
            return "stale"
        if rec_ints[i] > cur_ints[i]:
            return "ahead"

    if len(rec_ints) < len(cur_ints):
        return "stale"
    if len(rec_ints) > len(cur_ints):
        return "ahead"
    return "current"


# ---------------------------------------------------------------------------------------
# The half that needs repository context, which the delegation policy says to keep.


HEADER_VERSION = re.compile(r"^#\s*Version:\s*(\S+)\s*$", re.M)


def source_version(path):
    """The version a source file declares in its own header, or None.

    READS THE HEADER, NOT git. A commit that touches a file is not a claim that anything a
    reader was told has changed; a version bump is exactly that claim, made by the author.
    Coupling to git log would fire on a typo fix and be switched off within a week.
    """
    try:
        with open(path, encoding="utf-8", errors="replace") as fh:
            head = fh.read(4096)
    except OSError:
        return None
    m = HEADER_VERSION.search(head)
    return m.group(1) if m else None


def candidates(root):
    """Files carrying a marker. One `git grep`, for the reason marker_scan.sh records."""
    try:
        out = subprocess.run(
            ["git", "grep", "-I", "-l", "-E", r"^(<!--|#)[[:space:]]*scaffold:documents", "--", "."],
            cwd=root, capture_output=True, text=True, timeout=60)
    except (OSError, subprocess.SubprocessError):
        return None
    if out.returncode not in (0, 1):
        return None
    return [f for f in out.stdout.split("\n") if f]


def scan(root):
    """(rows, problems). A row is (doc, lineno, src, recorded, current, verdict)."""
    files = candidates(root)
    if files is None:
        return None, ["git grep could not run -- not a repository, or git is unavailable"]
    rows, problems = [], []
    for f in files:
        full = os.path.join(root, f)
        try:
            lines = open(full, encoding="utf-8", errors="replace").read().split("\n")
        except OSError as exc:
            problems.append("%s: could not read -- %s" % (f, exc))
            continue
        for i, line in enumerate(lines, 1):
            parsed = parse_documents_marker(line)
            if parsed is None:
                continue
            src, recorded = parsed
            cur = source_version(os.path.join(root, src))
            if cur is None:
                # A DECLARED SOURCE THAT IS NOT THERE, or carries no version header, is a
                # FAILURE. Skipping it would let a rename retire a document's only tie to
                # the code it describes, silently.
                problems.append(
                    "%s:%d declares %s, which %s"
                    % (f, i, src,
                       "does not exist" if not os.path.exists(os.path.join(root, src))
                       else "has no `# Version:` header to compare against"))
                continue
            rows.append((f, i, src, recorded, cur, version_verdict(recorded, cur)))
    return rows, problems


def report(root, strict):
    """Print the couplings and return an exit code.

    THREE OUTCOMES, not two. `could not verify` is what a missing source or an unusable
    repository produces, and reporting it as either a pass or a failure is the defect this
    whole repository is organised around.
    """
    rows, problems = scan(root)
    if rows is None:
        print("[SKIP] doc_currency: %s" % problems[0])
        print("       NOT verified. This is exit 3 -- neither a pass nor a failure.")
        return 3

    # ZERO MARKERS IS AN ANSWER, AND IT IS NOT "PASS". A checker that examined nothing reads
    # identically to one that found nothing wrong unless it says which it was.
    if not rows and not problems:
        print("[GAP]  doc_currency: NO document declares what it documents.")
        print("       Nothing was checked, so nothing is proven. Add a marker at column 0 to")
        print("       any document that describes a source file:")
        print("         <!-- scaffold:documents path/to/source.py @ <its current version> -->")
        # EXIT 3, NOT 0. Nothing was examined, and "examined nothing" is could-not-verify
        # rather than verified. Returning 0 here would let a repository that declares no
        # coupling at all report a clean gate forever -- the scanner-that-scanned-zero-files
        # shape this project has been bitten by four separate times.
        return 3

    stale = [r for r in rows if r[5] == "stale"]
    odd = [r for r in rows if r[5] in ("ahead", "unparsable")]
    for doc, ln, src, rec, cur, verdict in sorted(rows):
        tag = {"current": "OK ", "stale": "!! ", "ahead": "?? ", "unparsable": "?? "}[verdict]
        print("  [%s] %s:%d  %s" % (tag, doc, ln, src))
        if verdict == "current":
            print("         read against %s, which is current" % rec)
        elif verdict == "stale":
            print("         read against %s -- the source is now %s" % (rec, cur))
        elif verdict == "ahead":
            # NOT A FAILURE, AND SAYING SO MATTERS. This is the ordinary state for a few
            # minutes during a release, and for longer on a branch. It is reported because a
            # marker ahead of its source is usually a typo, and never silently accepted.
            print("         claims %s, but the source is only at %s -- check the marker" % (rec, cur))
        else:
            print("         recorded %r vs %r -- one of these is not a version" % (rec, cur))
    for p in problems:
        print("  [!! ] %s" % p)

    print("")
    if problems:
        print("  %d declared source(s) could not be resolved. A declared coupling that does" % len(problems))
        print("  not resolve is a failure, not a skip: a rename would otherwise retire a")
        print("  document's only tie to the code it describes, and say nothing.")
    if stale:
        print("  %d document(s) are behind the source they describe." % len(stale))
        print("  RE-READ THE DOCUMENT FIRST, then move its marker to the current version.")
        print("  Moving the marker without reading is how this becomes a formality.")
    if not stale and not problems and not odd:
        print("  %d document(s) current with the source they describe." % len(rows))
    if strict and (stale or problems):
        return 1
    return 0


def selftest():
    fails = 0

    def chk(name, want, got):
        nonlocal fails
        if want == got:
            print("  ok   %-58s" % name)
        else:
            print("  FAIL %-58s want=%r got=%r" % (name, want, got))
            fails += 1

    print("doc_currency selftest")

    # ---- the delegated half, against the contract it was drafted to -------------------
    chk("html form parses", ("src/a.py", "1.2.3"),
        parse_documents_marker("<!-- scaffold:documents src/a.py @ 1.2.3 -->"))
    chk("hash form parses", ("src/a.py", "1.2.3"),
        parse_documents_marker("# scaffold:documents src/a.py @ 1.2.3"))
    # COLUMN 0 ONLY. AGENTS.md states the rule this rests on -- "an indented example is
    # documentation, not a declaration" -- and without it every worked example in the docs
    # teaching this syntax becomes a declaration, and the checker fires on its own manual.
    for pad in (" ", "  ", "\t"):
        chk("indented by %r is not a declaration" % pad, None,
            parse_documents_marker(pad + "<!-- scaffold:documents a @ 1 -->"))
    chk("prose mentioning a marker is not a declaration", None,
        parse_documents_marker("we write <!-- scaffold:documents a @ 1 --> like this"))
    chk("a marker with no version is not one", None,
        parse_documents_marker("<!-- scaffold:documents a -->"))
    chk("an extra token after the version is refused", None,
        parse_documents_marker("<!-- scaffold:documents a @ 1 2 -->"))
    chk("a different scaffold marker is not ours", None,
        parse_documents_marker("<!-- scaffold:ceilings 800 -->"))

    chk("equal versions are current", "current", version_verdict("1.2.3", "1.2.3"))
    chk("an older recording is stale", "stale", version_verdict("1.2.2", "1.2.3"))
    chk("a newer recording is ahead", "ahead", version_verdict("1.2.4", "1.2.3"))
    # THE FIELD-COUNT RULE, which is the one a hand-written comparator gets wrong.
    chk("fewer fields sorts earlier", "stale", version_verdict("1.2", "1.2.0"))
    chk("more fields sorts later", "ahead", version_verdict("1.2.0", "1.2"))
    chk("leading zeros compare numerically", "current", version_verdict("01.2", "1.02"))
    chk("real stamps compare", "stale",
        version_verdict("0.13.0.20260825.0316", "0.13.1.20260911.0900"))
    for bad in ("", "1.", ".1", "1..2", "1.x", "-1", "1. 2"):
        chk("%r is unparsable, never a silent pass" % bad, "unparsable",
            version_verdict(bad, "1.2.3"))
    # NEVER RAISES. This runs over every tracked document; one hostile line must not stop it.
    raised = []
    for s in ("", " ", "\n", "<!--", "#", "@", "." * 40, "\x00", "é" * 5):
        for call in (lambda: parse_documents_marker(s),
                     lambda: version_verdict(s, "1.0"),
                     lambda: version_verdict("1.0", s)):
            try:
                call()
            except Exception as exc:            # noqa: BLE001 - the point of the case
                raised.append((s, repr(exc)))
    chk("no input raises", [], raised)

    # ---- the half that reads the repository -------------------------------------------
    chk("a source with no version header yields None", None, source_version(os.devnull))
    chk("this tool's own header is readable",
        True, bool(source_version(os.path.abspath(__file__))))
    # ASSERTED AGAINST ITSELF, which is the cheapest fixture that cannot drift: if the
    # header format ever changes, this fails here rather than reporting every coupling
    # unresolvable in a repository nobody is looking at.
    chk("...and it is what the header says",
        True, source_version(os.path.abspath(__file__)).startswith("0."))

    print("")
    if fails == 0:
        print("  all checks passed")
        return 0
    print("  %d check(s) FAILED" % fails)
    return 1


def main(argv):
    root = subprocess.run(["git", "rev-parse", "--show-toplevel"],
                          capture_output=True, text=True).stdout.strip() or "."
    if "--selftest" in argv:
        return selftest()
    return report(root, strict="--check" in argv)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
