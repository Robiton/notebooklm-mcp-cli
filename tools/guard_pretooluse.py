#!/usr/bin/env python3
# Project:  ai-project-scaffold
# File:     tools/guard_pretooluse.py
# Modified: 2026-09-22
# Version:  0.6.0.20260922.1536
# Purpose:  PreToolUse guard — turn the ai/SECURITY.md hard lines into actual rules.
# Changelog:
#   2026-09-22 v0.6.0.20260922.1536 — GETTING AROUND THE GATES IS DENIED. push/commit --no-
#                                     verify, commit -n, core.hooksPath overrides and
#                                     'preflight.sh ; git push' are deny (measured: 15-32%
#                                     of weekly pushes on this machine went out ungated,
#                                     most via --no-verify, which the receipt made
#                                     pointless); --allow-dirty is ask. Flags match outside
#                                     quotes. The main-branch rule now resolves the repo
#                                     from git -C / the last cd / the edited file's
#                                     directory instead of the session cwd, so workspace-
#                                     root sessions -- most of them -- are no longer
#                                     invisible to it. 53 cases.
#   2026-08-09 v0.5.0 — Non-allow decisions are appended to the run log. A security
#                        decision that leaves no record is one nobody can review: the
#                        guard prompts, the human answers, and the exchange vanishes
#                        with the terminal — so "has this ever fired", "what did it stop"
#                        and "is it even wired" all had no answer, and the last of those
#                        was NO for months on this project's own machine.
#                        Allows are NOT logged: this runs on every matching tool call, so
#                        logging them would write thousands of lines a day and bury the
#                        few entries anyone would want. The guard fails open and its
#                        logging fails quiet — instrumentation must never be why a call
#                        is blocked.
#   2026-08-06 v0.2.1 — The selftest's branch probe is a def, not an assigned lambda (#98).
#                        Behaviour identical: `_b=branch` still captures this iteration's
#                        value. Pure lint compliance — E731.
#   2026-08-04 v0.2.0 — Close three gaps found by self-audit, all of which the original
#                        17/17 suite passed over. `rm -r -f`, `rm -f -r`,
#                        `rm --recursive --force` and `rm build/ -rf` were allowed
#                        silently: the matcher recognised exactly the two spellings its
#                        own tests used. Flags are now parsed rather than pattern-matched.
#                        `git commit` on main was invisible — the guard checked EDITS on
#                        main, a proxy for the rule, never the commit itself. And a shell
#                        write to a protected path (`echo >> ai/SECURITY.md`,
#                        `sed -i tools/guard_pretooluse.py`) bypassed the protected-path
#                        check entirely, because that check looked only at Edit/Write.
#   2026-08-04 v0.1.0 — Initial creation
"""guard_pretooluse — a PreToolUse hook that enforces the hard lines, rather than asking.

WHY THIS EXISTS
  ai/PLANNING.md says it plainly: a rule written only in an ai/ file or AGENTS.md is a
  REQUEST — the model can drift past it. For truly critical guardrails, a hook is an
  actual rule. This is that hook for the three hard lines the scaffold states:

    1. Never mutate production data without a verified-restorable snapshot
       (ai/SECURITY.md). Measured in one adoption: backup-db.sh had been failing
       silently for ~4 months, committed without its executable bit.
    2. Never commit directly to main (ai/CODING.md -> Version control). Both the commit
       and an edit made while on main are checked — the commit is the rule, the edit is
       an early warning, and for a while only the early warning existed.
    3. Protected paths — the files that define the guardrails must not be edited by
       the same agent the guardrails constrain, without a human in the loop. Checked for
       Edit/Write AND for shell writes, because `echo >> ai/SECURITY.md` is the same act.

DESIGN: CONTAINMENT OVER PREVENTION
  This hook cannot detect a clever attack and does not try. Pattern-matching a command
  string is defeated by `e''cho`, base64, a shell variable, or a script that does the
  work one level down. What it CAN do is make the dangerous-by-accident case loud and
  the dangerous-on-purpose case require a deliberate step. Treat it as a seatbelt, not
  a firewall — and read ai/SECURITY.md -> Agent threat model for why that distinction
  is the whole design.

  Consequence: it prefers "ask" to "deny" almost everywhere. A guard that blocks
  legitimate work gets disabled, and a disabled guard protects nothing — the same
  failure mode as a warning that always fires.

CONTRACT (https://code.claude.com/docs/en/hooks.md)
  stdin  : JSON with tool_name, tool_input, cwd, hook_event_name, ...
           Bash      -> tool_input.command
           Edit/Write-> tool_input.file_path
  stdout : {"hookSpecificOutput": {"hookEventName": "PreToolUse",
                                   "permissionDecision": "allow|deny|ask",
                                   "permissionDecisionReason": "..."}}
  exit 0 : decision honoured from stdout JSON
  A hook that crashes must NOT block the session, so every failure path falls through
  to allow. A guard that breaks your tooling is a guard you remove.

Usage (wired in .claude/settings.json — shipped commented out, see that file):
  echo '{"tool_name":"Bash","tool_input":{"command":"rm -rf /"}}' | tools/guard_pretooluse.py
  tools/guard_pretooluse.py --selftest
"""
import json
import os
import re
import subprocess
import sys

# Paths whose whole job is to constrain the agent. Editing them is not forbidden —
# it is exactly what a scaffold maintainer does — but it should never happen without
# someone noticing, because an agent that can rewrite its own guardrails has none.
PROTECTED_PATHS = (
    "ai/SECURITY.md",
    ".github/workflows/",
    ".claude/settings.json",
    "tools/guard_pretooluse.py",
)

SHELL_BREAK = re.compile(r"[;&|\n]")


def is_recursive_force_rm(cmd):
    """True when some `rm` in this command line carries BOTH recursive and force.

    PARSE THE FLAGS; do not pattern-match the string. The regex this replaces recognised
    `rm -rf` and `rm -fr` and nothing else, so `rm -r -f`, `rm -f -r` and
    `rm --recursive --force` were all allowed silently (verified 2026-08-04). The 17
    self-tests all passed, because every fixture used a spelling the regex covered — the
    tests were derived from the implementation instead of from how people actually type.

    Still a seatbelt, not a firewall: `$RM_CMD $FLAGS dir` defeats this, and is meant to.
    """
    for m in re.finditer(r"\brm\b", cmd):
        # Only the arguments belonging to THIS rm, not the rest of the pipeline.
        segment = SHELL_BREAK.split(cmd[m.end():], 1)[0]
        # Flags may follow the path (`rm build/ -rf`), so scan every token, not a prefix.
        short = [t[1:] for t in segment.split() if t.startswith("-") and not t.startswith("--")]
        long_ = [t for t in segment.split() if t.startswith("--")]
        recursive = "--recursive" in long_ or any("r" in t or "R" in t for t in short)
        force = "--force" in long_ or any("f" in t for t in short)
        if recursive and force:
            return True
    return False


# Bash can write a file just as well as Edit can — `>>`, `tee`, `sed -i`, `cp`, `mv`.
# The protected-path check used to look only at the write TOOLS, so editing the guard
# itself through a shell redirect was invisible to the guard itself.
BASH_WRITE = re.compile(r">>?[^>]|\btee\b|\bsed\b[^|;&]*\s-i|\bcp\b|\bmv\b|\btruncate\b|"
                        r"\bpatch\b|\bdd\b")

# Commands that mutate state git cannot restore. See ai/STANDARDS.md ->
# "Work that leaves no trace in git". An entry's matcher is either a compiled-on-demand
# regex or a callable — some of these are not honestly expressible as one pattern.
DESTRUCTIVE = (
    (is_recursive_force_rm, "recursive force delete"),
    (r"\bDROP\s+(TABLE|DATABASE|SCHEMA)\b", "SQL DROP"),
    (r"\bTRUNCATE\s+TABLE\b", "SQL TRUNCATE"),
    (r"\bDELETE\s+FROM\b(?!.*\bWHERE\b)", "SQL DELETE with no WHERE"),
    (r"\bUPDATE\s+\w+\s+SET\b(?!.*\bWHERE\b)", "SQL UPDATE with no WHERE"),
    (r"\bgit\s+push\b.*(--force|-f)\b", "force push"),
    (r"\bgit\s+reset\s+--hard\b", "hard reset"),
    (r"\bgit\s+clean\s+-[a-zA-Z]*f", "git clean -f"),
    (r"\bdd\s+.*\bof=/dev/", "raw device write"),
    (r"\bmkfs\b", "filesystem format"),
)

PROTECTED_BRANCHES = ("main", "master")
WRITE_TOOLS = ("Edit", "Write", "NotebookEdit", "MultiEdit")


def _audit(decision, reason):
    """Append a non-allow decision to the run log. Best-effort, never raises.

    A SECURITY DECISION THAT LEAVES NO RECORD IS ONE NOBODY CAN REVIEW. The guard prompts,
    the human answers, and the whole exchange vanishes with the terminal — so "has this ever
    fired?" and "what did it stop last month?" have no answer, and neither does "is it still
    wired?", which on this project's own machine was NO for months without anyone knowing.

    ONLY NON-ALLOW DECISIONS. This runs on every matching tool call, and logging the allows
    would write thousands of lines a day, age out the retention window in an afternoon, and
    bury the handful of entries anyone would ever want. The interesting event is the guard
    saying something, not the guard staying quiet.
    """
    if decision == "allow":
        return
    try:
        root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        logger = os.path.join(root, "tools", "scaffold_log.sh")
        if not os.access(logger, os.X_OK):
            return
        subprocess.run([logger, "--log", "guard_pretooluse.py", decision, reason[:120]],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=5)
    except Exception:
        # THE GUARD FAILS OPEN, AND ITS LOGGING FAILS QUIET. Instrumentation must never be
        # the reason a tool call is blocked or a decision is lost.
        pass


def decide(decision, reason):
    """Emit the documented PreToolUse JSON and exit."""
    _audit(decision, reason)
    print(json.dumps({
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": decision,
            "permissionDecisionReason": reason,
        }
    }))
    sys.exit(0)


def current_branch(cwd):
    """Current branch name, or "" if it cannot be determined.

    `git branch --show-current`, NOT `git rev-parse --abbrev-ref HEAD`: rev-parse fails
    on a repo with no commits yet (unborn HEAD) and prints a fatal to stderr, so the
    branch check silently never fired on a fresh repo — precisely the moment someone is
    most likely to be working straight on main.
    """
    try:
        r = subprocess.run(["git", "branch", "--show-current"],
                           cwd=cwd or None, capture_output=True, text=True, timeout=5)
        return r.stdout.strip() if r.returncode == 0 else ""
    except Exception:
        return ""


_CD = re.compile(r"(?:^|[;&|\n(]\s*)cd\s+(\"[^\"]+\"|'[^']+'|[^\s;&|)]+)")
_GIT_C = re.compile(r"\bgit\s+-C\s+(\"[^\"]+\"|'[^']+'|\S+)")


def target_dir(cmd, cwd):
    """The directory a git command in CMD runs in: `git -C X`, else the last `cd X`, else cwd.

    THE SESSION'S CWD IS NOT THE REPOSITORY. A session started at a workspace root runs
    `cd repo && git commit ...`; checking the branch of the workspace (no repo, branch "")
    meant the main-branch rule never fired for any session started there -- which is where
    most sessions on this estate start.
    """
    def unq(t):
        return t[1:-1] if t[:1] in "\"'" and t[-1:] == t[:1] else t
    m = _GIT_C.search(cmd)
    if m:
        d = os.path.expanduser(unq(m.group(1)))
    else:
        cds = _CD.findall(cmd)
        if not cds:
            return cwd
        d = os.path.expanduser(unq(cds[-1]))
    return d if os.path.isabs(d) else os.path.join(cwd, d)


# GETTING AROUND THE GATES. Each of these was measured on this estate, not imagined: 15-32%
# of pushes per week went out with no gate run, and the documented habit that carried most
# of them was `git push --no-verify` "because the hook re-runs the 173s suite". It does not
# -- .githooks/pre-push accepts preflight's `ok sha=<HEAD>` receipt and returns instantly --
# so --no-verify buys nothing but the bypass. DENY, not ask: an ask is a prompt the agent
# can talk its way through; the owner can still run any of these himself with `!`.
BYPASS = (
    (r"\bgit\b[^;&|\n]*\b(push|commit)\b[^;&|\n]*--no-verify\b",
     "--no-verify skips the gate hook. After tools/preflight.sh passes, a plain `git push` "
     "is instant: .githooks/pre-push accepts the receipt for HEAD. Without a pass, the hook "
     "IS the gate. Commit, run preflight, then push without --no-verify."),
    (r"\bgit\b[^;&|\n]*\bcommit\b(?:[^;&|\n]*\s)?-[a-zA-Z]*n[a-zA-Z]*\b",
     "`git commit -n` is --no-verify: it skips the commit hooks."),
    (r"\bgit\b[^;&|\n]*(?:-c\s+core\.hooksPath=|\bconfig\b[^;&|\n]*core\.hooksPath)",
     "Changing core.hooksPath unwires the gate hooks (.githooks/). If the hooks are wrong, "
     "fix the hooks."),
    (r"preflight\.sh[^;&|\n]*(?:;|\n)\s*(?:[^;&|\n]*;\s*)*git\s+push\b",
     "`preflight.sh ; git push` pushes even when preflight FAILED -- a semicolon ignores the "
     "exit code. Chain with &&."),
)
BYPASS_ASK = (
    (r"preflight\.sh[^;&|\n]*--allow-dirty\b",
     "--allow-dirty gates the working tree, not the commit, and silences header_check "
     "--since. Commit first, then run preflight. Confirm only if the dirty run is the point."),
)


def check(payload):
    """Return (decision, reason) or None to stay out of the way."""
    tool = payload.get("tool_name", "")
    ti = payload.get("tool_input") or {}
    cwd = payload.get("cwd") or os.getcwd()

    # --- writes -------------------------------------------------------------
    if tool in WRITE_TOOLS:
        path = str(ti.get("file_path") or ti.get("notebook_path") or "")
        rel = os.path.relpath(path, cwd) if os.path.isabs(path) and path else path

        for p in PROTECTED_PATHS:
            if rel.startswith(p) or rel == p.rstrip("/"):
                return ("ask",
                        f"'{rel}' defines the guardrails this agent runs under "
                        f"(ai/SECURITY.md -> Agent threat model). Editing it is normal "
                        f"maintainer work, but should never happen unnoticed — an agent "
                        f"that can rewrite its own limits has none. Confirm intent.")

        # The FILE's repository, not the session's cwd -- see target_dir().
        where = os.path.dirname(path) if os.path.isabs(path) else cwd
        branch = current_branch(where if os.path.isdir(where) else cwd)
        if branch in PROTECTED_BRANCHES:
            return ("ask",
                    f"On branch '{branch}'. ai/CODING.md -> Version control: never commit "
                    f"directly to main; branch first (feature/ fix/ chore/). Editing here "
                    f"is fine if you are about to branch — confirm.")

    # --- commands -----------------------------------------------------------
    if tool == "Bash":
        cmd = str(ti.get("command") or "")

        # Flags are matched OUTSIDE quotes: a commit message that says "--no-verify" is
        # prose about the flag, not the flag.
        bare = re.sub(r"\"(?:[^\"\\]|\\.)*\"|'[^']*'", "''", cmd)
        for pattern, why in BYPASS:
            if re.search(pattern, bare):
                return ("deny", f"Scaffold gate bypass refused. {why}")
        for pattern, why in BYPASS_ASK:
            if re.search(pattern, bare):
                return ("ask", why)

        # The rule is "never COMMIT directly to main" — the guard only ever checked
        # edits, which is a proxy for it. Editing on main then branching is fine and
        # common; committing on main is the violation itself, and it was invisible.
        if re.search(r"\bgit\s+(?:-C\s+\S+\s+)?(commit|merge|cherry-pick|revert)\b", cmd):
            branch = current_branch(target_dir(cmd, cwd))
            if branch in PROTECTED_BRANCHES:
                return ("ask",
                        f"This commits on '{branch}'. ai/CODING.md -> Version control: "
                        f"never commit directly to main; branch first "
                        f"(feature/ fix/ chore/), then open a PR. Confirm if deliberate.")

        # A shell write to a guardrail file is the same act as an Edit to it.
        if BASH_WRITE.search(cmd):
            for p in PROTECTED_PATHS:
                if p.rstrip("/") in cmd:
                    return ("ask",
                            f"This command writes to '{p}', which defines the guardrails "
                            f"this agent runs under (ai/SECURITY.md -> Agent threat model). "
                            f"A shell redirect is the same act as an Edit — an agent that "
                            f"can rewrite its own limits has none. Confirm intent.")

        for pattern, label in DESTRUCTIVE:
            hit = pattern(cmd) if callable(pattern) else re.search(pattern, cmd, re.I)
            if hit:
                return ("ask",
                        f"This looks like {label}, which changes state git cannot restore.\n"
                        f"ai/SECURITY.md hard line: never mutate production data without a "
                        f"snapshot you have VERIFIED IS RESTORABLE — taking a backup is not "
                        f"the rule, proving you can restore it is.\n"
                        f"If this is intended: confirm, then record the snapshot path and a "
                        f"reconciliation invariant in ai/SESSION.md "
                        f"(ai/STANDARDS.md -> Work that leaves no trace in git).")
    return None


SELFTESTS = (
    # (tool, tool_input, branch_override, expected_decision, label)
    #
    # NOTE ON HOW THESE ARE CHOSEN. The first version of this suite passed 17/17 while
    # `rm -r -f` sailed through, because every fixture was written from the regex. A test
    # derived from the implementation can only confirm the implementation. Each spelling
    # below is here because a person might TYPE it, not because the matcher handles it.
    ("Bash", {"command": "rm -rf build/"}, None, "ask", "recursive force delete"),
    ("Bash", {"command": "rm -fr build/"}, None, "ask", "-fr, flags reversed"),
    ("Bash", {"command": "rm -r -f build/"}, None, "ask", "-r -f, flags separated"),
    ("Bash", {"command": "rm -f -r build/"}, None, "ask", "-f -r, separated and reversed"),
    ("Bash", {"command": "rm --recursive --force build/"}, None, "ask", "GNU long flags"),
    ("Bash", {"command": "rm -rfv build/"}, None, "ask", "extra flag alongside"),
    ("Bash", {"command": "rm build/ -rf"}, None, "ask", "flags after the path"),
    ("Bash", {"command": "rm -r build/"}, None, None, "recursive without force is fine"),
    ("Bash", {"command": "rm -f stale.lock"}, None, None, "force without recursive is fine"),
    ("Bash", {"command": "ls -r . && grep -f p.txt src/"}, None, None, "no rm at all"),
    ("Bash", {"command": "git commit -am wip"}, "main", "ask", "commit on main"),
    ("Bash", {"command": "git commit -am wip"}, "feature/x", None, "commit on a branch is fine"),
    ("Bash", {"command": "git merge feature/x"}, "main", "ask", "merge on main"),
    ("Bash", {"command": "echo x >> ai/SECURITY.md"}, "feature/x", "ask", "shell write to a guardrail"),
    ("Bash", {"command": "sed -i '' s/ask/allow/ tools/guard_pretooluse.py"}, "feature/x",
     "ask", "sed -i on the guard itself"),
    ("Bash", {"command": "cat ai/SECURITY.md"}, "feature/x", None, "reading a guardrail is fine"),
    ("Bash", {"command": "echo x >> notes.md"}, "feature/x", None, "shell write elsewhere is fine"),
    ("Bash", {"command": "psql -c 'DROP TABLE users;'"}, None, "ask", "SQL DROP"),
    ("Bash", {"command": "sqlite3 db 'DELETE FROM orders;'"}, None, "ask", "DELETE without WHERE"),
    ("Bash", {"command": "sqlite3 db 'DELETE FROM orders WHERE id=3;'"}, None, None, "DELETE with WHERE is fine"),
    ("Bash", {"command": "git push --force origin main"}, None, "ask", "force push"),
    ("Bash", {"command": "git push origin feature/x"}, None, None, "ordinary push is fine"),
    ("Bash", {"command": "ls -alF"}, None, None, "ls is fine"),
    ("Bash", {"command": "grep -rf patterns.txt src/"}, None, None, "grep -rf is NOT rm -rf"),
    ("Edit", {"file_path": "ai/SECURITY.md"}, "feature/x", "ask", "protected path"),
    ("Edit", {"file_path": ".github/workflows/ci.yml"}, "feature/x", "ask", "protected workflow"),
    ("Edit", {"file_path": "src/app.py"}, "feature/x", None, "ordinary edit on a branch is fine"),
    ("Edit", {"file_path": "src/app.py"}, "main", "ask", "edit on main"),
    ("Read", {"file_path": "ai/SECURITY.md"}, None, None, "reading is never blocked"),
    # Regression: a repo with no commits reports no branch via rev-parse, which used to
    # make the branch check silently miss — on exactly the repo where someone is most
    # likely to be working straight on main.
    ("Edit", {"file_path": "src/app.py"}, "", None, "unknown branch does not false-positive"),
    ("Write", {"file_path": ".claude/settings.json"}, "feature/x", "ask", "protected settings"),
    ("Bash", {"command": "TRUNCATE TABLE audit_log;"}, None, "ask", "SQL TRUNCATE"),
    ("Bash", {"command": "git reset --hard origin/main"}, None, "ask", "hard reset"),
    # Bypass: each spelling is one an agent on this estate actually typed or was told to.
    ("Bash", {"command": "git push --no-verify"}, "feature/x", "deny", "push --no-verify"),
    ("Bash", {"command": "cd repo && tools/preflight.sh && git push --no-verify origin main"},
     "feature/x", "deny", "the documented habit, verbatim"),
    ("Bash", {"command": "git -C ../localcoder push --no-verify"}, "feature/x", "deny",
     "push --no-verify via -C"),
    ("Bash", {"command": "git commit --no-verify -m x"}, "feature/x", "deny", "commit --no-verify"),
    ("Bash", {"command": "git commit -nm x"}, "feature/x", "deny", "commit -n, bundled"),
    ("Bash", {"command": "git commit -m 'no -n here' -F msg"}, "feature/x", None,
     "-n inside a message is not the flag"),
    ("Bash", {"command": 'git commit -m "stop using --no-verify"'}, "feature/x", None,
     "--no-verify inside a message is not the flag"),
    ("Bash", {"command": "git log -n 5"}, "feature/x", None, "log -n is not commit -n"),
    ("Bash", {"command": "git push -n origin x"}, "feature/x", None, "push -n is a dry run"),
    ("Bash", {"command": "git -c core.hooksPath=/dev/null push"}, "feature/x", "deny",
     "hooksPath override"),
    ("Bash", {"command": "git config core.hooksPath ''"}, "feature/x", "deny", "hooksPath unset"),
    ("Bash", {"command": "tools/preflight.sh; git push"}, "feature/x", "deny", "semicolon chain"),
    ("Bash", {"command": "tools/preflight.sh && git push"}, "feature/x", None, "&& chain is fine"),
    ("Bash", {"command": "tools/preflight.sh --allow-dirty"}, "feature/x", "ask", "--allow-dirty"),
    ("Bash", {"command": "tools/preflight.sh --ci-unresolved-ok"}, "feature/x", None,
     "--ci-unresolved-ok is a documented, read-first flag"),
)


def selftest():
    global current_branch
    failed = 0
    for tool, ti, branch, expected, label in SELFTESTS:
        # Rebinds the module-level probe per case, exactly as the lambda did — `_b=branch`
        # captures this iteration's value rather than closing over the loop variable.
        def current_branch(_c, _b=branch):
            return _b if _b is not None else "feature/x"
        got = check({"tool_name": tool, "tool_input": ti, "cwd": os.getcwd()})
        got_decision = got[0] if got else None
        ok = got_decision == expected
        failed += not ok
        print(f"  {'ok  ' if ok else 'FAIL'} {label:42} expected={expected or 'allow':5} "
              f"got={got_decision or 'allow'}")
    # target_dir is what makes the branch rule reach a workspace-root session; the branch
    # stub above cannot see it, so it is asserted directly.
    tds = (
        ("git commit -m x", "/ws", "/ws", "no cd: the session cwd"),
        ("cd repo && git commit -m x", "/ws", "/ws/repo", "relative cd"),
        ('cd "/a b/r" && git commit', "/ws", "/a b/r", "quoted absolute cd"),
        ("cd x; cd y && git commit", "/ws", "/ws/y", "the LAST cd wins"),
        ("git -C ../lc commit -m x", "/ws/s", "/ws/s/../lc", "git -C beats cwd"),
    )
    for cmd, cwd, want, label in tds:
        got = target_dir(cmd, cwd)
        ok = got == want
        failed += not ok
        print(f"  {'ok  ' if ok else 'FAIL'} target_dir: {label:30} got={got}")
    total = len(SELFTESTS) + len(tds)
    print(f"\n  {total - failed}/{total} passed")
    return 1 if failed else 0


if __name__ == "__main__":
    if "--selftest" in sys.argv[1:]:
        sys.exit(selftest())
    try:
        payload = json.load(sys.stdin)
    except Exception:
        # Malformed input must never block the session.
        sys.exit(0)
    try:
        result = check(payload)
    except Exception as e:
        print(f"guard_pretooluse: {e} (allowing)", file=sys.stderr)
        sys.exit(0)
    if result:
        decide(*result)
    sys.exit(0)
