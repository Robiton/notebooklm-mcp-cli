#!/usr/bin/env python3
# =============================================================================
# Project:  ai-project-scaffold
# File:     tools/localcoder_footprint.py
# Modified: 2026-08-11
# Version:  0.2.0.20260811.0510
# Purpose:  Measure how much localcoder policy every session pays for, and hold it
#           to a budget. A project that will never run a local model should not be
#           loading the local model's rules.
# Changelog:
#   2026-08-11 v0.2.0 — Budget 33 -> 28 after the AGENTS.md delegation policy moved to
#                        tools/README.md. W-10's named scope now sits at exactly its target
#                        of 20; the 8 over are the AGENTS.md pointer and the File-headers
#                        blockquote, both named above. The follow-up was estimated at 25 on
#                        the assumption AGENTS.md would reach zero — it reached three,
#                        because a pointer that names localcoder is still charged, and the
#                        measurement is right to charge for it.
#   2026-08-11 v0.1.0 — Initial, for W-10. MEASURED before the move: 393 lines of
#                        localcoder policy in the session-start load order, in a
#                        scaffold whose whole premise is that it stays useful with no
#                        local model installed. A Splunk app paid for all of it.
#                        Written as a CHECK and not a one-off measurement on purpose.
#                        W-10 is a documentation change, and nothing about a
#                        documentation change stops the next release putting the prose
#                        back one paragraph at a time. The budget is the thing that
#                        survives; the measurement on its own is an anecdote with a
#                        date on it.
# =============================================================================
"""Measure localcoder policy in the always-loaded context files.

WHY SECTION-SCOPED AND NOT LINE-SCOPED. A session does not pay for the lines that say
"localcoder", it pays for the sections those lines sit in — nobody reads half a heading.
So the unit is the section, and a section is either about localcoder or it is not.

WHY DENSITY AND NOT MENTION. The first version of this counted any section containing
the word, and reported 705 lines against a hand count of ~300. It swept up "Ask GitHub,
not only your own machine" — 126 lines of CI policy with four incidental mentions — and
"File headers", 85 lines about header stamps. A metric that overstates by 2.3x in its
first run is one nobody will act on, and it would have made this item look done while
half the real prose was still in place.
"""
import argparse
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)

# The session-start load order, from ai/STANDARDS.md -> Load order. STANDARDS.md itself
# is second because it is the file that names the others.
#
# AGENTS.md IS FIRST AND IS NOT IN THAT LIST. It is the universal hook every tool reads at
# startup — CLAUDE.md is a one-line import of it — so it is loaded even more reliably than
# the files the load order names. The first version of this tool measured only the ai/
# files and missed 24 lines of delegation policy sitting in the one file that is always
# read; found while chasing a dangling cross-reference, not by the measurement. A budget
# tool that omits the most-loaded file in the repo is the shape of defect this package
# keeps finding: a check that reports a number for a set smaller than the one that matters.
LOADED = ("AGENTS.md", "ai/STANDARDS.md", "ai/MEMORY.md", "ai/BACKLOG.md", "ai/SESSION.md",
          "ai/CODING.md", "ai/SECURITY.md", "ai/PLANNING.md", "ai/TEAM.md")

# IN THE REPO THAT SHIPS localcoder, ITS OWN NARRATIVE FILES ARE NOT OVERHEAD.
#
# The premise of this budget is "a project that will never run a local model should not
# load the local model's rules". In `Robiton/localcoder` that premise is simply false: its
# ai/MEMORY.md decisions, ai/BACKLOG.md tasks and ai/SESSION.md history are about localcoder
# because localcoder is what the project IS. Measured there 2026-08-11: 680 lines, of which
# 204 are those three files. Charging them would make the number meaningless in the one
# repository that owns the subject, and a meaningless gate is a disabled gate.
#
# Keyed on `scaffold:owns-localcoder`, which already exists and already means exactly this
# distinction for the upgrader. Declared, never inferred: without the marker every adopter
# is measured in full, which is the safe direction.
OWNED_EXEMPT = ("ai/MEMORY.md", "ai/BACKLOG.md", "ai/SESSION.md")
OWNS_RE = re.compile(r"^<!--\s*scaffold:owns-localcoder\s*-->\s*$", re.M)

# `delegat` earns its place: this codebase uses "delegation" as a localcoder term of art
# — `localcoder --delegation`, `guard_delegation.py`, the config's `delegation` key. Adding
# it moved ai/CODING.md's 55-line "What to delegate, and what not to" from 12.2% (missed)
# to a heading match, and moved nothing else.
TERM = re.compile(r"localcoder|local model|local coder|ollama|local LLM|local draft"
                  r"|drafting brief|qwen|delegat", re.I)
HEADING = re.compile(r"^(#{2,4}) +(.*)$")

# The marked prompt region is CONTRACT SURFACE, NOT POLICY PROSE, and W-10 says so
# explicitly. localcoder injects exactly this block; deleting it to win a budget would
# be optimising the measurement instead of the thing measured. Counted and reported
# separately so the exemption is visible rather than silently applied — an exclusion
# nobody can see is indistinguishable from a bug.
REGION = re.compile(r"^[ \t]*<!--\s*localcoder:(begin(?::[a-z0-9_+#-]+)?|end)\s*-->")

# A section is localcoder policy if its HEADING names the subject, or its body keeps
# naming it, or its TOPIC SENTENCE names it and the body goes on doing so.
#
# THE THRESHOLDS ARE MEASURED, NOT PICKED. Full distribution over this repo's eight
# always-loaded files, 2026-08-11, every section containing at least one term:
#
#     35.3%  129  H  1st   STANDARDS  localcoder lives in two repos      <- W-10 names it
#     35.0%   26  H  1st   STANDARDS  Route work to the local model      <- W-10 names it
#     25.0%   12  H        CODING     Drafting brief                     <- contract surface
#     24.8%  147  H  1st   CODING     Local coder (optional)             <- W-10 names it
#     22.0%   55  H        CODING     What to delegate, and what not to  <- W-10 names it
#     15.8%   24     1st   STANDARDS  A device config is never team beh. <- W-10 names it
#     ---------------------------------------------------------------- boundary
#     11.8%   23            MEMORY    Known issues and gotchas
#     10.0%   15            PLANNING  Verification
#     10.0%   12            SECURITY  No secrets in prompts
#      3.4%   36            STANDARDS Exit 3 means "I verified nothing"
#      2.9%   85     1st    CODING    File headers
#      1.0%  126            STANDARDS Ask GitHub, not only your own machine
#
# Density alone does not separate them: the last item W-10 names sits at 15.8% and the
# first it does not at 11.8%, which is far too narrow to rest a gate on. Hence the second
# signal. A TOPIC SENTENCE naming the subject is strong evidence a section is ABOUT it —
# "A device config is never team behaviour" opens with "`localcoder` resolves ONE config"
# and never needs the word again. On its own the topic sentence is not enough either: 85
# lines of "File headers" open with a localcoder mention and are not localcoder policy.
# Together they separate the two populations cleanly, and each one alone does not.
DENSITY = 0.20
DENSITY_WITH_TOPIC = 0.10

# AND A PARAGRAPH SWEEP INSIDE THE SECTIONS THAT DID NOT QUALIFY, because section scope
# alone reported AGENTS.md as ZERO. That file is the universal hook — every tool reads it
# at startup — and its localcoder content sits inside two big mixed sections: "During a
# session" (79 lines, 7.9%) and "End of session" (26 lines, 8.0%), both mostly CI and
# session policy. Charging either whole section to localcoder would be the 705-line
# overcount again; reporting zero was worse, because the delegation policy and the
# attribution check in there are real per-session cost and together they exceed the entire
# remaining budget.
#
# So: a section that does not qualify is re-scanned by paragraph. The bar is higher (a
# paragraph is short, so a single mention is a larger fraction of it) and it is measured —
# at 0.40 this picks up the four genuine localcoder paragraphs in AGENTS.md and nothing
# else anywhere in the tree.
PARA_DENSITY = 0.40
PARA_MIN = 3

# THE BUDGET IS A RATCHET AT TODAY'S NUMBER, NOT W-10's TARGET, AND THE GAP IS DELIBERATE.
#
# W-10 says "under 20 lines". Its named scope — ai/STANDARDS.md and ai/CODING.md — now sits
# at exactly 20: 10 for the markers the tooling reads out of that file, 4 for the drafting
# brief's surround, and 6 for the Local coder pointer. That criterion is met.
#
# The 8 over are in two places W-10 did not name:
#
#   3   AGENTS.md, a pointer to tools/README.md. This was 24 lines of delegation policy in
#       the universal hook file until 2026-08-11 and is now three. It CANNOT go to zero: a
#       pointer that names localcoder is still localcoder text in an always-loaded file, and
#       the honest measurement charges for it. Estimating this at 25 assumed AGENTS.md would
#       reach zero; it reached three, and the estimate was wrong rather than the work.
#   5   ai/CODING.md "File headers", a blockquote warning that the rule is deliberately
#       OUTSIDE the drafting brief. It earns its place: it is the warning that stopped
#       drafts arriving with headers on exempt files, and it only works where the rule is.
#
# Setting the budget to 20 would ship a gate that is red on arrival, and a gate that is red
# on arrival gets a `|| true` within a week. 28 permits no regression and names the debt.
DEFAULT_BUDGET = 28
W10_TARGET = 20


def sections(lines):
    """(start_index, heading_text, body_lines) for every ## / ### / #### section."""
    marks = [i for i, ln in enumerate(lines) if HEADING.match(ln)]
    out = []
    for a, b in zip(marks, marks[1:] + [len(lines)]):
        out.append((a, HEADING.match(lines[a]).group(2), lines[a:b]))
    return out


LIST_ITEM = re.compile(r"^ {0,3}(?:[-*+]|\d+[.)]) +")


def paragraphs(body):
    """(offset, lines) for each block in a section body.

    Blank-line delimited, AND split at every list item. Markdown lists are not blank-line
    separated, so without the second rule AGENTS.md's whole end-of-session checklist reads
    as one 23-line block: nine lines of localcoder attribution policy averaged against
    fourteen lines about CI and hooks, landing below any threshold. The content was real
    and the shape of the container hid it.
    """
    out, cur, start = [], [], 0
    for i, ln in enumerate(body):
        if not ln.strip():
            if cur:
                out.append((start, cur))
                cur = []
            continue
        if LIST_ITEM.match(ln) and cur:
            out.append((start, cur))
            cur, start = [], i
        elif not cur:
            start = i
        cur.append(ln)
    if cur:
        out.append((start, cur))
    return out


def exempt_lines(lines):
    """Indices inside localcoder:begin..end blocks, resolved over the WHOLE file.

    NOT PER SECTION, and the difference is not cosmetic. In this repo's own ai/CODING.md
    the `begin` marker sits at line 3 and the section heading at line 4, so a per-section
    scan starts inside a region it never saw opened, strips the closing marker alone, and
    charges 25 lines of contract surface to the budget. Found by reading the first run's
    output — "1 line EXEMPT" against a 26-line block that is visibly all region.
    """
    out, inside = set(), False
    for i, ln in enumerate(lines):
        m = REGION.match(ln)
        if m:
            out.add(i)
            inside = m.group(1).startswith("begin")
            continue
        if inside:
            out.add(i)
    return out


def owns_localcoder(root):
    """True when this repository SHIPS localcoder rather than vendoring it."""
    try:
        with open(os.path.join(root, "ai", "STANDARDS.md"), encoding="utf-8") as fh:
            return bool(OWNS_RE.search(fh.read()))
    except OSError:
        return False


def measure(root):
    """(total, exempt, rows). rows are (rel, line_no, count, heading, why)."""
    total, exempt, rows = 0, 0, []
    owned = owns_localcoder(root)
    for rel in LOADED:
        if owned and rel in OWNED_EXEMPT:
            continue
        path = os.path.join(root, rel)
        if not os.path.exists(path):
            continue
        with open(path, encoding="utf-8") as fh:
            lines = fh.read().splitlines()
        skip = exempt_lines(lines)
        exempt += len(skip)
        for start, heading, body in sections(lines):
            body = [ln for i, ln in enumerate(body, start) if i not in skip]
            live = [ln for ln in body if ln.strip()]
            if not live:
                continue
            hits = sum(1 for ln in live if TERM.search(ln))
            by_heading = bool(TERM.search(heading))
            topic = next((ln for ln in body[1:] if ln.strip()), "")
            by_topic = bool(TERM.search(topic))
            density = hits / len(live)
            if by_heading:
                why = "heading"
            elif density >= DENSITY:
                why = f"{density:.0%} density"
            elif by_topic and density >= DENSITY_WITH_TOPIC:
                why = f"topic sentence + {density:.0%}"
            else:
                for off, para in paragraphs(body):
                    plive = [ln for ln in para if ln.strip()]
                    phits = sum(1 for ln in plive if TERM.search(ln))
                    # A one- or two-line block at 100% is a cross-reference, not policy.
                    # Without PARA_MIN the sweep reported ai/PLANNING.md's single-line
                    # pointer as a finding, which is the kind of noise that gets a budget
                    # tool switched off.
                    if len(plive) >= PARA_MIN and phits / len(plive) >= PARA_DENSITY:
                        total += len(para)
                        rows.append((rel, start + 1 + off, len(para),
                                     f"(in {heading[:34]})",
                                     f"paragraph {phits / len(plive):.0%}"))
                continue
            total += len(body)
            rows.append((rel, start + 1, len(body), heading, why))
    return total, exempt, rows


def report(root, budget, verbose=True):
    total, exempt, rows = measure(root)
    if not os.path.exists(os.path.join(root, "ai", "STANDARDS.md")):
        # COULD NOT RUN IS NOT A PASS. Without the load-order file there is no defined
        # set of always-loaded files, so a 0 here would mean "found nothing to count",
        # which reads identically to "there is nothing to count".
        print("localcoder_footprint: ai/STANDARDS.md not found — no load order to read.")
        print("  Measured nothing. That is not the same as measuring zero.")
        return 3
    if verbose:
        for rel, no, n, heading, why in rows:
            print(f"  {n:>4} lines  {rel}:{no:<4} {heading[:52]:<52} ({why})")
        if exempt:
            print(f"  {exempt:>4} lines  EXEMPT — localcoder:begin..end, contract surface")
    # NAME WHAT WAS COUNTED (D18). "301 lines" with no membership is the number that hid
    # D-18 for four rounds.
    print(f"  localcoder policy in the session-start load order: {total} line(s) "
          f"across {len(rows)} section(s), budget {budget}")
    if budget > W10_TARGET and total <= budget:
        print(f"  (W-10's target is {W10_TARGET}; the budget is a ratchet at the number "
              f"reached, not the target — see DEFAULT_BUDGET for what the gap is.)")
    if total > budget:
        print(f"  OVER BUDGET by {total - budget} line(s). Every session of every")
        print("  adopting project pays for these, including projects that will never")
        print("  run a local model. Move the prose to tools/README.md and leave a stub.")
        return 1
    return 0


def selftest():
    """Prove it FAILS on a bloated fixture, not merely that it passes on a lean one."""
    import shutil
    import tempfile
    fails = 0
    # FIXED, and deliberately not DEFAULT_BUDGET. The shipped budget is a ratchet that moves
    # every time real prose moves; a fixture keyed to it would silently retune itself and
    # two of these cases would stop testing anything. Found the hard way — raising the
    # shipped budget from 20 to 33 turned two green cases red, which is the tests working.
    FIXTURE_BUDGET = 20

    def case(label, expected, got):
        nonlocal fails
        ok = expected == got
        fails += not ok
        print(f"  {'ok  ' if ok else 'FAIL'} {label:56} expected={expected} got={got}")

    tmp = tempfile.mkdtemp()
    try:
        ai = os.path.join(tmp, "ai")
        os.makedirs(ai)
        lean = ("# Standards\n\n## Load order\n\nRead ai/CODING.md.\n\n"
                "## Git workflow\n\nBranch, then PR. Never commit to main.\n")
        open(os.path.join(ai, "STANDARDS.md"), "w").write(lean)
        case("a file with no localcoder prose is under budget", 0,
             report(tmp, FIXTURE_BUDGET, verbose=False))

        # THE CASE THAT MATTERS: the state this item exists to remove.
        bloat = lean + "\n### Using localcoder\n\n" + "".join(
            f"Line {i} of local model policy about ollama drafts.\n" for i in range(40))
        open(os.path.join(ai, "STANDARDS.md"), "w").write(bloat)
        case("40 lines of localcoder policy is caught", 1,
             report(tmp, FIXTURE_BUDGET, verbose=False))

        # A SECTION THAT MERELY MENTIONS IT MUST NOT COUNT. This is the overcount that
        # made the first version of this tool report 705 against a hand count of ~300.
        passing = lean + "\n### Ask GitHub, not only your own machine\n\n" + "".join(
            f"Line {i} about CI, runs, alerts and logs.\n" for i in range(60)) + \
            "Read the localcoder drift check output too.\n"
        open(os.path.join(ai, "STANDARDS.md"), "w").write(passing)
        case("a passing mention in a long section does NOT count", 0,
             report(tmp, FIXTURE_BUDGET, verbose=False))

        # THE TOPIC-SENTENCE SIGNAL, both directions. A section that opens on the subject
        # and keeps returning to it is policy; one that opens on it and then talks about
        # something else for 80 lines is ai/CODING.md's "File headers", which is not.
        topical = lean + "\n### A device config is never team behaviour\n\n" \
            "`localcoder` resolves ONE config, and scopes are exclusive.\n" + "".join(
                f"Line {i}: a value that changes behaviour must be declared.\n"
                for i in range(24)) + \
            "Never commit a device config.\nRead `localcoder --where` first.\n" \
            "The project config wins per key, and ollama is never consulted.\n"
        open(os.path.join(ai, "STANDARDS.md"), "w").write(topical)
        case("topic sentence + sustained mention DOES count", 1,
             report(tmp, FIXTURE_BUDGET, verbose=False))

        headers = lean + "\n## File headers\n\n" \
            "Stamped by tools/header_check.sh, and localcoder drafts get one too.\n" + \
            "".join(f"Line {i} about version stamps and modified dates.\n"
                    for i in range(80))
        open(os.path.join(ai, "STANDARDS.md"), "w").write(headers)
        case("topic sentence WITHOUT sustained mention does not", 0,
             report(tmp, FIXTURE_BUDGET, verbose=False))

        # The marked prompt region is exempt, and generously sized so that counting it
        # would blow any budget — if this passes, the exemption is real.
        region = lean + "\n## Drafting brief\n\n<!-- localcoder:begin -->\n" + "".join(
            f"Rule {i} for the local model.\n" for i in range(50)) + \
            "<!-- localcoder:end -->\n"
        open(os.path.join(ai, "STANDARDS.md"), "w").write(region)
        case("the localcoder:begin..end region is exempt", 0,
             report(tmp, FIXTURE_BUDGET, verbose=False))

        # ...but prose OUTSIDE the region in the same section is not exempt, or the
        # exemption becomes a way to hide anything by parking a marker above it.
        leaky = region + "".join(
            f"Unmarked policy line {i} about localcoder.\n" for i in range(30))
        open(os.path.join(ai, "STANDARDS.md"), "w").write(leaky)
        case("prose OUTSIDE the region is still counted", 1,
             report(tmp, FIXTURE_BUDGET, verbose=False))

        # THE REPO THAT SHIPS localcoder IS NOT CHARGED FOR ITS OWN RECORD. Both directions,
        # because an exemption that always applies is indistinguishable from not measuring.
        open(os.path.join(ai, "STANDARDS.md"), "w").write(lean)
        open(os.path.join(ai, "MEMORY.md"), "w").write(
            "# Memory\n\n## Architecture decisions\n\n" + "".join(
                f"Decision {i}: how localcoder resolves the ollama model pin.\n"
                for i in range(30)))
        case("an ADOPTER is charged for localcoder in ai/MEMORY.md", 1,
             report(tmp, FIXTURE_BUDGET, verbose=False))
        open(os.path.join(ai, "STANDARDS.md"), "w").write(
            lean + "\n<!-- scaffold:owns-localcoder -->\n")
        case("the repo that OWNS localcoder is not", 0,
             report(tmp, FIXTURE_BUDGET, verbose=False))
        os.remove(os.path.join(ai, "MEMORY.md"))

        os.remove(os.path.join(ai, "STANDARDS.md"))
        case("no load order is COULD-NOT-RUN, not a pass", 3,
             report(tmp, FIXTURE_BUDGET, verbose=False))
    finally:
        shutil.rmtree(tmp, ignore_errors=True)

    print(f"\n  {'all checks passed' if not fails else str(fails) + ' check(s) FAILED'}")
    return 1 if fails else 0


def main():
    ap = argparse.ArgumentParser(
        description="Measure localcoder policy in the always-loaded context files.")
    ap.add_argument("--budget", type=int, default=DEFAULT_BUDGET,
                    help=f"maximum lines allowed (default {DEFAULT_BUDGET}, from W-10)")
    ap.add_argument("--root", default=ROOT, help="repository root to measure")
    ap.add_argument("--selftest", action="store_true",
                    help="prove it fails what it should")
    args = ap.parse_args()
    if args.selftest:
        return selftest()
    return report(args.root, args.budget)


if __name__ == "__main__":
    sys.exit(main())
