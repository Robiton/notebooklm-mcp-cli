#!/usr/bin/env python3
# Project:  ai-project-scaffold
# File:     tools/python_floor.py
# Modified: 2026-09-22
# Version:  0.1.0.20260922.0503
# Purpose:  Hold a project to the requires-python floor it advertises, instead of trusting it.
# Changelog:
#   2026-09-22 v0.1.0 — AN UNGUARDED FLOOR IS A CLAIM. localcoder's pyproject.toml has said
#                        `requires-python = ">=3.9"` throughout, and NOTHING in this scaffold
#                        read that string: grepping the whole tools/ tree, setup.sh and the
#                        workflows for `requires-python` returned nothing at all. Every machine
#                        in this estate runs 3.14, so the floor could only ever be broken
#                        silently -- by an author whose interpreter accepts what an adopter's
#                        does not, with no gate anywhere able to notice.
#                        WHAT IT PROVES, AND WHAT IT CANNOT. It parses every Python file against
#                        the GRAMMAR of the declared floor, so `match`, `X | Y` annotations, the
#                        walrus below 3.8 and friends are caught at the point they are written.
#                        It says nothing about stdlib CALLS: `datetime.UTC` is 3.11 and parses
#                        cleanly under any floor. That limit is printed with the result rather
#                        than left for a reader to assume, because a gate whose scope is assumed
#                        wider than it is, is worse than no gate.
#                        THREE OUTCOMES, as everywhere here. No pyproject, or one with no
#                        requires-python, is exit 3 -- a checker that examined nothing and one
#                        that found nothing wrong are different answers, and a project that never
#                        made the promise is not in breach of it. A floor the running interpreter
#                        cannot express is exit 3 too, never a pass.
"""Check every Python file in the tree against the declared requires-python floor."""

import argparse
import ast
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

SKIP_DIRS = {".git", "build", "dist", ".venv", "venv", "node_modules",
             "__pycache__", ".mypy_cache", ".ruff_cache", ".pytest_cache"}

# `>=3.9`, `>= 3.9`, `>=3.9,<4.0`. The LOWER bound is the promise; an upper bound is a
# different statement and is not what this gate is about.
FLOOR_RE = re.compile(r">=\s*(\d+)\.(\d+)")
REQUIRES_RE = re.compile(r'^\s*requires-python\s*=\s*["\']([^"\']+)["\']', re.M)


def declared_floor(pyproject_text):
    """Return (major, minor) from requires-python, or None when nothing is promised."""
    m = REQUIRES_RE.search(pyproject_text)
    if not m:
        return None
    f = FLOOR_RE.search(m.group(1))
    if not f:
        return None
    return (int(f.group(1)), int(f.group(2)))


def is_python_file(path):
    """A .py file, or an extensionless script whose shebang names python.

    localcoder's entry point is `src/localcoder/localcoder` with no extension, and it is
    the largest Python file in that tree. A gate that globbed *.py would have skipped the
    one file most worth checking.
    """
    if path.endswith(".py"):
        return True
    if os.path.splitext(path)[1]:
        return False
    try:
        with open(path, "rb") as fh:
            first = fh.readline(200)
    except OSError:
        return False
    return first.startswith(b"#!") and b"python" in first


def python_files(root):
    out = []
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]
        for name in filenames:
            p = os.path.join(dirpath, name)
            if is_python_file(p):
                out.append(p)
    return sorted(out)


def check_file(path, floor):
    """Return None when the file is within the floor, else a (line, message) tuple."""
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as fh:
            src = fh.read()
    except OSError as exc:
        return (0, "cannot read: %s" % exc)
    try:
        ast.parse(src, filename=path, feature_version=floor)
    except SyntaxError as exc:
        return (exc.lineno or 0, (exc.msg or str(exc)).strip())
    return None


def floor_is_expressible(floor):
    """Can THIS interpreter express that floor? A floor it cannot is exit 3, not a pass."""
    try:
        ast.parse("x = 1", feature_version=floor)
    except (ValueError, TypeError) as exc:
        return str(exc)
    return None


def run(root):
    """Returns (exit_code, lines)."""
    lines = []
    pp = os.path.join(root, "pyproject.toml")
    if not os.path.exists(pp):
        return 3, ["python_floor: NOTHING TO CHECK — no pyproject.toml in %s." % root,
                   "  A project that never promised a floor is not in breach of one."]
    with open(pp, "r", encoding="utf-8", errors="replace") as fh:
        floor = declared_floor(fh.read())
    if floor is None:
        return 3, ["python_floor: NOTHING TO CHECK — pyproject.toml declares no",
                   "  `requires-python` lower bound, so there is no promise to hold it to."]

    why = floor_is_expressible(floor)
    if why is not None:
        return 3, ["python_floor: CANNOT CHECK — this interpreter (%d.%d) cannot parse against"
                   % (sys.version_info[0], sys.version_info[1]),
                   "  a %d.%d floor: %s" % (floor[0], floor[1], why),
                   "  Not a pass. Run this on a newer interpreter, or raise the floor."]

    files = python_files(root)
    if not files:
        return 3, ["python_floor: NOTHING TO CHECK — no Python files found under %s." % root]

    bad = []
    for path in files:
        hit = check_file(path, floor)
        if hit is not None:
            bad.append((os.path.relpath(path, root), hit[0], hit[1]))

    if bad:
        lines.append("python_floor: %d file(s) use syntax newer than the declared "
                     ">=%d.%d floor" % (len(bad), floor[0], floor[1]))
        for rel, ln, msg in bad[:25]:
            lines.append("  %s:%s  %s" % (rel, ln, msg))
        if len(bad) > 25:
            lines.append("  ... and %d more" % (len(bad) - 25))
        lines.append("  Either fix the syntax or raise requires-python to what you actually "
                     "support.")
        return 1, lines

    lines.append("python_floor: %d Python file(s) parse against the declared >=%d.%d floor"
                 % (len(files), floor[0], floor[1]))
    lines.append("  SYNTAX ONLY — this cannot see stdlib calls. `datetime.UTC` is 3.11 and "
                 "parses fine under any floor.")
    return 0, lines


# ---------------------------------------------------------------------------- selftest

FIXTURE_OK = "def f(x):\n    return [i for i in range(x)]\n"
FIXTURE_310 = "def f(x):\n    match x:\n        case 1:\n            return 'one'\n"


def selftest():
    import tempfile
    fails = 0

    def chk(label, expected, actual):
        nonlocal fails
        if expected == actual:
            print("  ok   %-58s" % label)
        else:
            print("  FAIL %-58s expected=%r got=%r" % (label, expected, actual))
            fails += 1

    print("python_floor selftest — an unguarded floor is a claim")

    chk("a >= lower bound is read", (3, 9), declared_floor('requires-python = ">=3.9"'))
    chk("whitespace and an upper bound do not confuse it", (3, 10),
        declared_floor('requires-python = ">= 3.10, <4.0"'))
    chk("single quotes too", (3, 8), declared_floor("requires-python = '>=3.8'"))
    # NO PROMISE IS NOT A FLOOR OF ZERO. Returning (0,0) here would make every file pass.
    chk("no requires-python at all is None", None, declared_floor('name = "x"\n'))
    chk("a bound with no >= is None", None, declared_floor('requires-python = "<4.0"'))

    with tempfile.TemporaryDirectory() as d:
        # THE DISCRIMINATING PAIR: the same file must pass under one floor and fail under
        # the other, or the feature_version argument is not doing anything.
        p = os.path.join(d, "m.py")
        with open(p, "w") as fh:
            fh.write(FIXTURE_310)
        chk("3.10 syntax FAILS against a 3.9 floor", True, check_file(p, (3, 9)) is not None)
        chk("the same file PASSES against a 3.10 floor", True, check_file(p, (3, 10)) is None)

        p2 = os.path.join(d, "ok.py")
        with open(p2, "w") as fh:
            fh.write(FIXTURE_OK)
        chk("plain syntax passes the 3.9 floor", True, check_file(p2, (3, 9)) is None)

        # AN EXTENSIONLESS ENTRY POINT IS STILL PYTHON. localcoder's is the biggest file in
        # its tree; a *.py glob would have skipped exactly the file most worth checking.
        p3 = os.path.join(d, "cli")
        with open(p3, "w") as fh:
            fh.write("#!/usr/bin/env python3\n" + FIXTURE_310)
        os.chmod(p3, 0o755)
        chk("an extensionless python shebang is picked up", True, is_python_file(p3))
        # THIS CASE HAS TO EXIST TO FAIL. The first version asked about a path that was
        # never created, so it returned False for the one reason that proves nothing.
        p4 = os.path.join(d, "runme")
        with open(p4, "w") as fh:
            fh.write("#!/bin/sh\nexit 0\n")
        chk("an extensionless SHELL script is not picked up", False, is_python_file(p4))

        # NOTHING TO CHECK IS EXIT 3, NEVER 0. A project with no pyproject has made no
        # promise, and reporting that as a pass is how an absent gate reads as a green one.
        rc, _ = run(d)
        chk("a tree with no pyproject.toml is exit 3", 3, rc)

        with open(os.path.join(d, "pyproject.toml"), "w") as fh:
            fh.write('[project]\nname = "x"\n')
        rc, _ = run(d)
        chk("a pyproject with no requires-python is exit 3", 3, rc)

        with open(os.path.join(d, "pyproject.toml"), "w") as fh:
            fh.write('[project]\nrequires-python = ">=3.9"\n')
        rc, out = run(d)
        chk("and with a floor declared, the 3.10 file FAILS it", 1, rc)
        chk("the failing file is named", True, any("m.py" in ln for ln in out))
        chk("so is the extensionless one", True, any("cli" in ln for ln in out))

        with open(os.path.join(d, "pyproject.toml"), "w") as fh:
            fh.write('[project]\nrequires-python = ">=3.10"\n')
        rc, out = run(d)
        chk("raising the floor to 3.10 makes the same tree clean", 0, rc)
        chk("and the syntax-only limit is stated in the result", True,
            any("SYNTAX ONLY" in ln for ln in out))

    print("")
    if fails == 0:
        print("  all checks passed")
        return 0
    print("  %d check(s) FAILED" % fails)
    return 1


def main(argv):
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--check", action="store_true",
                    help="check the tree (the default)")
    ap.add_argument("--root", default=ROOT, help="tree to check (default: this repository)")
    ap.add_argument("--selftest", action="store_true", help="run the selftest")
    args = ap.parse_args(argv)

    if args.selftest:
        return selftest()

    rc, lines = run(args.root)
    stream = sys.stderr if rc == 1 else sys.stdout
    for ln in lines:
        print(ln, file=stream)
    return rc


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
