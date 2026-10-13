#!/usr/bin/env bash
# Project:  ai-project-scaffold
# File:     tools/scaffold_version.sh
# Modified: 2026-10-13
# Version:  0.8.4.20261013.0405
# Purpose:  Tell an adopting project when the scaffold it vendored has gone stale.
# Changelog:
#   2026-10-13 v0.8.4.20261013.0405 — local edit in a public adopter: work mirror account no longer named; mirror comes from SCAFFOLD_UPSTREAM_MIRROR (scaffold issue #387).
#   2026-10-10 v0.8.3.20261010.1205 — carries shared:upstream (report item 16): upstream_pinned now refuses a declared upstream that is not one owner/repo, and the block is gated byte-identical across the four tools that carry it.
#   2026-10-08 v0.8.2.20261008.1245 — count_newer takes the version-shape filter newest_of already had. A GraphQL error body counted as one newer release; a list holding no version now reports could-not-tell, not 0.
#   2026-10-07 v0.8.1.20261007.0658 — THE PROBE READS THE ANSWER, NOT THAT THERE WAS ONE. gh api prints its 404 body to STDOUT
#                        even with --jq, so a work machine that cannot see Robiton got non-empty output for it and
#                        picked it, and 0.111.15's mirror support never engaged. The tag picker then took a version out
#                        of that error JSON and cached it. Found end-to-end as the work account, after release; the
#                        selftest's fake gh printed nothing on failure, which no real gh does. It now prints the 404.
#   2026-10-07 v0.8.0.20261007.0347 — THE UPSTREAM IS WHERE THIS PROJECT GOT THE SCAFFOLD. Work adopters get it from the the work mirror account mirror, which carries every tag but no GitHub releases, and cannot see Robiton at all; this asked Robiton for its latest release and so could never answer there. Source order: SCAFFOLD_UPSTREAM, then a .scaffold-upstream file, then the first of Robiton and the mirror that this machine can read. With no release, the newest annotated tag and its tagger date stand in.
#   2026-09-23 v0.7.2.20260923.0941 — mktemp takes a ${TMPDIR} template. macOS mktemp ignores TMPDIR without one, so a guarded fixture root could not contain it.
#   2026-09-23 v0.7.1.20260923.0843 — every mktemp fails closed. A failed one left the temp variable empty, so the fixture ran in the caller's directory; header_check's committed into Robiton/control.
#   2026-09-06 v0.7.0.20260906.0406 — STALENESS IS DENOMINATED IN TIME, NOT RELEASES (#301).
#                        The gate failed at >1 release behind whatever the calendar said. On
#                        2026-09-04 this repo cut SIX releases in five hours, and an adopter
#                        who upgraded, did an hour of unrelated Kotlin, then tried to push was
#                        failed three times in one session by releases that landed WHILE THEY
#                        WORKED -- two of which replaced one product file and merged four
#                        standards files at +0 upstream lines. The risk being managed is "a fix
#                        has been available and you did not take it", which is a duration.
#                        So the COUNT opens the question and the AGE answers it: over the lag
#                        tolerance is a failure only once the oldest release not taken has been
#                        sitting there longer than RELEASE_AGE_TOLERANCE_DAYS.
#                        AGE UNKNOWN KEEPS THE OLD VERDICT. With no date we are exactly as
#                        informed as before this argument existed, so a missing fact must not
#                        manufacture leniency -- fixtured in both directions.
#                        The one-argument call is the backward-compatible contract, and a bare
#                        $2 under `set -u` turned it into an unbound-variable crash. The
#                        selftest caught that on its first run, which is the argument for
#                        having written the case before the code.
#   2026-08-31 v0.6.1.20260831.0904 — #249 mktemp -t is BSD-only -- bounded() returned 1 on its first line and never ran the
#                        command on Linux, so every gh call failed closed and a hang was not bounded at all.
#   2026-08-18 v0.6.0.20260818.1156 — `--assert-consistent`: THE ONE PLACE THE VERSION INVARIANT
#                        IS DEFINED (P0-2). It lived only in scaffold-check.yml, so it could
#                        not run on the machine that cuts the release -- and when Actions were
#                        blocked on 2026-08-13 it stopped running at all. `.scaffold-version`
#                        drifted FOURTEEN releases behind `version` in the upstream repo,
#                        where they are the same file and a fresh adoption inherits it as the
#                        merge base for its first --upgrade.
#                        setup.sh, preflight and the WORKFLOW now all call this rather than
#                        restating it. Reimplementing it locally would have been the wrong
#                        fix: two copies of one rule is this repo's most repeated defect.
#                        Three roles, and absence is never inferred -- upstream (must match),
#                        adoption (differ by design), no-artifact (must DECLARE it, and
#                        declaring both a version file and no-artifact is refused).
#                        Placed BELOW is_upstream_repo() after the first version died with
#                        `command not found` and took the ADOPTION branch upstream, printing
#                        the opposite of the truth -- the trap this file's 0.4.0 entry records.
#   2026-08-17 v0.5.2.20260817.1739 — #226 NAMED TWO UNBOUNDED CALLS AND 0.51.2 BOUNDED ONE. The
#                        one left is `gh release list` inside releases_behind() -- the call the
#                        GATE uses to count the lag, so the one that decides a verdict. I fixed
#                        the instance I had been looking at rather than the class the issue
#                        described, and the issue had been open the whole time. Reading the
#                        issue list before implementing would have cost nothing.
#                        SO THE CHECK IS NOW ON THE CLASS: every `gh` invocation in this file
#                        must be wrapped in bounded(), derived from the source, so the NEXT one
#                        added without a bound fails here instead of shipping. Mutation-verified
#                        both ways -- unbinding either call fails it.
#                        bounded() also MOVED above releases_behind(). Runtime-safe either way,
#                        but "defined below its caller" is the trap this file's own 0.4.0 entry
#                        records, and leaving a second instance of it in place was asking for it.
#   2026-08-17 v0.5.1.20260817.1636 — EVERY FETCH IN A GATE NEEDS A CEILING, and `gh` has no
#                        --max-time. 0.51.0 stopped --gate reading the cache, which was right,
#                        and thereby made every gated run depend on a live call -- so that
#                        call's worst case became the gate's worst case. curl was already
#                        bounded at 6s; gh was not, and gh is the PRIMARY path because the
#                        upstream repo is private and unauthenticated api.github.com 404s. An
#                        unbounded fetch inside preflight is a gate that HANGS instead of
#                        failing, which is worse than the stale answer 0.51.0 removed: a hang
#                        has no exit code to read. bounded() runs it in the background with a
#                        deadline and kills it, because neither `timeout` nor `gtimeout` ships
#                        with macOS and this runs on adopters' machines -- and with no process
#                        substitution, which segfaults bash 3.2 inside a loop. On timeout the
#                        curl fallback gets its own 6s, and if both are empty the existing
#                        branch reports exit 3 in gate mode. Asserted on the MECHANISM: a slow
#                        command returns 124, does so within 4s, and a fast one's stdout
#                        survives -- neither of which can pass vacuously, confirmed by
#                        mutation.
#   2026-08-17 v0.5.0.20260817.1505 — A GATE MAY CACHE THE COST OF A CHECK, NEVER ITS
#                        VERDICT. Measured on an adopter the day it was found: this repo
#                        shipped five releases, their 24h cache held 0.45.0 while 0.50.0 was
#                        current, and because their adopted 0.48.0 sorts ABOVE the stale
#                        0.45.0 the gate did not merely under-report -- it INVERTED the
#                        verdict into `[OK] ... tracking main` and passed. Their preflight
#                        passed on it all day, including the run immediately before a
#                        release. A 24-hour TTL on a gate, in a project releasing several
#                        times a day, is blind for most of the window it guards, and it is
#                        silent by construction because a stale value still looks like an
#                        answer. Shipped in 0.45.0, whose own title was "staleness is a gate
#                        now".
#                        THE TTL SURVIVES FOR THE ADVISORY PATH, which is what it was built
#                        for -- SessionStart costs nothing on a normal day and its verdict is
#                        a note. Under --gate the cache is not consulted at all; if the fetch
#                        then fails, the existing branch reports exit 3, could-not-run and
#                        NOT a pass, which is the answer a stale cache was concealing.
#                        cache_is_usable() IS SPLIT OUT so the decision has cases with no
#                        network in it -- and it went in BELOW the selftest first, where
#                        three of its four cases passed against `command not found`, because
#                        a missing function is falsy and they expected "no". Only the
#                        positive case failed. That is the trap the 0.4.0 entry below already
#                        records, repeated in the same file it is written in.
#   2026-08-16 v0.4.0.20260816.1916 — `--gate`: THIS CHECK HAD NO CALLER.
#                        It has exited 1 on "behind" since it was written, and preflight
#                        ran only its --selftest -- proving the check works while never
#                        running it. A declaration nothing reads, in the file whose entire
#                        subject is a stale copy looking identical to a current one.
#                        MEASURED THE DAY IT WAS FOUND: localcoder sat two releases behind,
#                        and the newer release was the one titled "the stamp gate had the
#                        defect it was built to catch" -- so the fix for a defect an adopter
#                        reported never reached the adopter, and four releases were cut past
#                        the warning that said so.
#                        ONE RELEASE OF TOLERANCE, then it fails. Upstream cutting a release
#                        must not redden every adopter the same afternoon; a gate that
#                        reddens on somebody else's schedule is one people push past, and
#                        this estate has already measured that cost. Two behind is a
#                        different claim: a fix was available through a full release nobody
#                        took.
#                        count_newer IS SPLIT FROM THE FETCH so the ordering logic has cases
#                        on it without a network, and it carries the same numeric-not-string
#                        compare as the rest of this file -- as text "0.10" < "0.5", which
#                        would report a current repo nine releases behind and fail its gate.
#                        UNDETERMINABLE IS 3, NEVER 0: offline and current are identical
#                        from here, and only one of them is a pass.
#                        THE HELPERS SIT ABOVE THE SELFTEST DELIBERATELY. Written below it
#                        first, every case errored `command not found` -- and one PASSED
#                        anyway, because a missing function returns empty and the expected
#                        value was empty. A case that passes because the code is absent.
#   2026-08-08 v0.3.1 — Same re-fetch fix as scaffold_upgrade.sh (#136): gh api, quoted,
#                        plus a `head -1` check, because the failure mode is a file that
#                        exists and is wrong rather than an error.
#   2026-08-08 v0.3.0 — The upstream repo is not BEHIND, it is the thing compared TO (#134).
#                        `.scaffold-version` is advanced only by scaffold_upgrade.sh, which
#                        correctly refuses to run in the scaffold's own repository — so the
#                        file can never move there. It sat at 0.8.0.20260805.1400 through
#                        three releases while `version` read 0.11.3, and this printed BEHIND
#                        at every session start, in the repo whose maintainer reads it most.
#                        This file already warned that a wrong BEHIND is "the fastest way to
#                        teach people to ignore a version check"; it was doing that to
#                        itself. All three signals, per #113 — a mirroring sibling and a
#                        template clone are both real adoptions and must still be told.
#   2026-08-08 v0.2.0 — Say when the UPGRADE TOOL ITSELF is too old to fix being behind
#                        (#130). `setup.sh --upgrade` delegates to the vendored
#                        tools/scaffold_upgrade.sh, so a defect in that script's
#                        preconditions cannot be repaired by upgrading — the fix ships
#                        inside the thing that refuses to run. Robiton/localcoder carried
#                        0.3.2, whose scaffold's-own-repo check keyed on mirror-sync.yml
#                        alone; that repo mirrors, so every attempt died with "There is
#                        nothing to upgrade here", which reads as SUCCESS. It sat 13
#                        releases behind while the fix sat upstream. "Behind" and "cannot
#                        become current" were indistinguishable from inside the repo,
#                        which is precisely what this script exists to make visible.
#                        Floor is DECLARED (0.5.0), not fetched: deriving it would need a
#                        second network call on a session-start check and would still be
#                        silent offline. Comparison extracted as a pure function with a
#                        --selftest this script never had — including 0.10.0 vs 0.5.0,
#                        where a string compare says "behind" and would send a current
#                        adopter at a curl command they do not need.
#   2026-08-04 v0.1.0 — Initial creation
#
# WHY THIS EXISTS
#   Updating is a manual clone-and-diff and nothing in an adopting repo ever said
#   "you are behind". sync-check.sh checks a lot — pointer health, skills drift, ai/
#   commits on the remote, the archive threshold — but every one of those compares the
#   project against ITS OWN origin. None compared the vendored scaffold against upstream.
#
#   Measured: one project sat on v0.2.0 for FOUR MONTHS, through a v0.3.0 update that
#   did not land cleanly, and nobody knew. It surfaced only because a human asked
#   "update the scaffold" out of the blue; upstream was on v0.5.0 by then. Nothing was
#   broken enough to notice, which is the whole problem — a silently stale scaffold
#   looks identical to a current one from inside the repo.
#
# DESIGN NOTES
#   - Reads .scaffold-version, NOT `version`. Those were the same file, and `version`
#     usually holds the adopter's project version, so a human who thought to look was
#     reading the wrong number entirely.
#   - Result is CACHED (24h) so the SessionStart path costs nothing on a normal day.
#   - Degrades SILENTLY offline. A version check that nags when you are on a plane is
#     one people disable, and then it protects nobody.
#
# Usage:
#   tools/scaffold_version.sh              # cached check; silent when current
#   tools/scaffold_version.sh --force      # ignore the cache
#   tools/scaffold_version.sh --quiet      # exit code only (0 current/unknown, 1 behind)
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOCAL_FILE="$ROOT/.scaffold-version"
CACHE="$ROOT/.scaffold-version-check"
# WHERE THIS PROJECT GETS THE SCAFFOLD FROM, WHICH IS NOT ALWAYS ROBITON.
#
# Personal repos take it from Robiton/ai-project-scaffold. Work repos take it from the
# the work mirror account mirror, which mirror-sync.yml keeps byte-identical -- main and every tag --
# but which has NO GitHub releases, because a deploy key can push tags and cannot create a
# release. A work machine usually cannot see Robiton at all. Hardcoding Robiton therefore
# made this check unanswerable on every work adoption.
#
# Order: SCAFFOLD_UPSTREAM (one run), then `.scaffold-upstream` in the project root (an
# adopter-owned file the upgrader never touches; one owner/repo line, # comments allowed),
# then the first of the two below that this machine's gh can read. Resolved lazily, by
# ensure_upstream, so the advisory path pays for no probe when its cache answers.
# >>> shared:upstream
# carried by: tools/scaffold_version.sh tools/scaffold_upgrade.sh tools/context_survival.sh tools/release.sh
# ONE BODY, FOUR FILES, byte for byte. preflight's "shared blocks" gate fails the moment a
# copy differs or a file on the line above stops carrying it (report item 16).
# Not a sourced library: these tools are vendored one by one, and scaffold_upgrade.sh
# replaces itself mid-run, so a library is one more file to deliver in step -- and the
# drift this block caused (item 8) came from copies nobody compared, not from copying.
UPSTREAM_DEFAULT="Robiton/ai-project-scaffold"
# Local edit (public adopter, scaffold issue #387): the work mirror is configured, not named.
UPSTREAM_MIRROR="${SCAFFOLD_UPSTREAM_MIRROR:-}"
upstream_valid() {  # upstream_valid <name> -> 0 only for one owner/repo
  # (An underscore is legal in an owner: managed-user accounts, like the mirror's, carry one.)
  # The name is spliced into `gh api repos/<name>/tarball/<tag>`, so `../x`, a third
  # segment or a leading dot reaches a different endpoint than the one it names.
  case "$1" in
    */*/*|.*|*/.|*/..) return 1 ;;
  esac
  printf '%s\n' "$1" | grep -Eq '^[A-Za-z0-9][A-Za-z0-9_-]*/[A-Za-z0-9_.-]+$'
}
upstream_pinned() {  # upstream_pinned <root> -> the declared upstream, or nothing
  # Order: SCAFFOLD_UPSTREAM (one run), then `.scaffold-upstream` in the project root (an
  # adopter-owned file, one owner/repo line, # comments allowed). Returns 1, saying why,
  # when what is declared is not an owner/repo: the caller decides whether that stops it.
  local _u=""
  if [ -n "${SCAFFOLD_UPSTREAM:-}" ]; then
    _u="$SCAFFOLD_UPSTREAM"
  elif [ -f "$1/.scaffold-upstream" ]; then
    _u="$(sed -e 's/#.*//' -e 's/[[:space:]]//g' "$1/.scaffold-upstream" | sed -n '/./{p;q;}')"
  fi
  [ -n "$_u" ] || return 0
  if upstream_valid "$_u"; then printf '%s\n' "$_u"; return 0; fi
  printf 'scaffold: the declared upstream "%s" is not an owner/repo name -- not used\n' "$_u" >&2
  return 1
}
scaffold_sums() {  # scaffold_sums make <dir>  |  scaffold_sums check <dir> <SHA256SUMS>
  # THE RELEASE'S SHA256SUMS IS A MANIFEST OF THE TREE, NOT A HASH OF THE TARBALL. GitHub
  # builds tarballs on demand and has changed their bytes before; the files inside do not
  # change. One line per file, "<sha256>  <path>", sorted; a symlink hashes its target.
  # check: exit 0 match, 1 differs (each difference on stdout), 3 could not run. An extra
  # file is a difference too -- `sha256sum -c` would pass a tree that gained one.
  python3 - "$@" <<'PY_SUMS'
import hashlib, os, sys
def tree(root):
    out = {}
    for d, dirs, files in os.walk(root):
        dirs[:] = sorted(x for x in dirs if x != ".git")
        for n in list(files) + [x for x in dirs if os.path.islink(os.path.join(d, x))]:
            p = os.path.join(d, n)
            rel = os.path.relpath(p, root).replace(os.sep, "/")
            if os.path.islink(p):
                out[rel] = hashlib.sha256(b"symlink:" + os.readlink(p).encode()).hexdigest()
            elif os.path.isfile(p):
                with open(p, "rb") as fh:
                    out[rel] = hashlib.sha256(fh.read()).hexdigest()
    return out
try:
    mode, root = sys.argv[1], sys.argv[2]
    have = tree(root)
    if mode == "make":
        for rel in sorted(have):
            print("%s  %s" % (have[rel], rel))
        sys.exit(0)
    want = {}
    with open(sys.argv[3]) as fh:
        for line in fh:
            if line.strip():
                h, rel = line.rstrip("\n").split("  ", 1)
                want[rel] = h
except Exception as e:
    print("could not compare: %s" % e)
    sys.exit(3)
if not want:
    print("the manifest lists no files")
    sys.exit(3)
bad = [("changed  " if rel in have else "missing  ") + rel
       for rel in sorted(want) if have.get(rel) != want[rel]]
bad += ["added    " + rel for rel in sorted(set(have) - set(want))]
if bad:
    print("\n".join(bad[:20]) + ("\n...and %d more" % (len(bad) - 20) if len(bad) > 20 else ""))
sys.exit(1 if bad else 0)
PY_SUMS
}
# <<< shared:upstream
UPSTREAM="$(upstream_pinned "$ROOT")"
MAX_AGE_HOURS=24
FORCE=0; QUIET=0; DO_SELFTEST=0; GATE_MODE=0

# HOW FAR BEHIND IS TOO FAR. One release of slack, deliberately: upstream cutting a release
# must not turn every adopter red the same afternoon, because a gate that reddens on
# somebody else's schedule is one people learn to push past -- and this repo has already
# measured what that costs (a 297s gate taught everyone here to use --no-verify).
# Two or more releases behind is a different claim: at that point a fix has been available
# through at least one full release you chose not to take.
RELEASE_LAG_TOLERANCE=1

# ...AND THE COUNT ALONE IS THE WRONG DENOMINATOR (#301). The paragraph above is right about
# WHY, and then measures it in the one unit upstream controls. On 2026-09-04 this repo cut six
# releases in five hours; an adopter who upgraded, did an hour of unrelated Kotlin, and tried
# to push was failed three times in one session by releases that landed WHILE THEY WORKED.
# Two of those upgrades replaced one product file and merged four standards files at +0
# upstream lines -- scored identically to a six-release jump that genuinely mattered.
#
# The risk being managed is "a fix has been available and you did not take it", and that is
# denominated in TIME. So the count opens the question and the age answers it: over the lag
# tolerance is only a FAILURE once the oldest release you skipped has been sitting there
# longer than this. A burst is reported and passes; genuine neglect still fails.
RELEASE_AGE_TOLERANCE_DAYS=7
for a in "$@"; do
  [ "$a" = "--force" ] && FORCE=1
  [ "$a" = "--quiet" ] && QUIET=1
  [ "$a" = "--selftest" ] && DO_SELFTEST=1
  [ "$a" = "--gate" ] && GATE_MODE=1
  [ "$a" = "--assert-consistent" ] && ASSERT_MODE=1
done
say() { [ "$QUIET" = "1" ] || printf '%s\n' "$1"; }


# BEING BEHIND IS ONLY HALF THE STORY: THE TOOL THAT FIXES IT CAN BE TOO OLD TO RUN (#130).
#
# `setup.sh --upgrade` delegates to the VENDORED tools/scaffold_upgrade.sh, so a defect in
# that script's preconditions cannot be repaired by upgrading — the fix ships inside the
# thing that refuses to run. Measured on Robiton/localcoder: it carried 0.3.2, whose
# scaffold's-own-repo check keyed on .github/workflows/mirror-sync.yml ALONE. That repo
# mirrors, so every upgrade attempt died with "There is nothing to upgrade here", which
# reads as SUCCESS. It sat 13 releases behind while the fix (0.5.0) sat upstream, reachable
# only by a command nobody had a reason to run.
#
# Nothing detected it, because "behind" and "cannot become current" looked identical from
# inside the repo — which is the exact thing this script exists to say out loud.
#
# The floor is DECLARED, not derived. Comparing against upstream's copy of the file would
# need a second network fetch on a session-start check, and would still be silent offline.
# 0.5.0 is where the three-signal precondition landed; below it, a sibling product repo is
# refused outright and no adopter can be sure their copy is not the stranded shape.
UPGRADE_TOOL_FLOOR="0.5.0"

# PURE, so the floor can be tested without a repo, a network or a stranded clone. The
# behaviour this guards was unobservable for 13 releases; a check for it that is itself
# unverifiable would be no better.
# Prints "yes" when $1 is older than $2. Empty or unparseable -> "no": unknown is not stale.
upgrade_tool_is_older() {
  VER="$1" FLOOR="$2" python3 -c '
import os, re
def parts(v): return [int(x) for x in re.findall(r"[0-9]+", v)]
a, b = parts(os.environ["VER"]), parts(os.environ["FLOOR"])
if not a or not b:
    print("no"); raise SystemExit
a += [0] * (len(b) - len(a)); b += [0] * (len(a) - len(b))
print("yes" if a < b else "no")
' 2>/dev/null || echo no
}

# Reads the vendored tool's own header. Extracted from the reporting so the version
# comparison above can be exercised directly.
upgrade_tool_version() {
  sed -n 's/^# Version:[[:space:]]*\([0-9][0-9.]*\).*/\1/p' "$1" 2>/dev/null | head -1
}

check_upgrade_tool_can_run() {
  local tool="$ROOT/tools/scaffold_upgrade.sh" ver
  [ -f "$tool" ] || return 0            # not vendored here; setup.sh --upgrade says so itself
  ver="$(upgrade_tool_version "$tool")"
  [ -n "$ver" ] || return 0             # unreadable header is not evidence of anything
  [ "$(upgrade_tool_is_older "$ver" "$UPGRADE_TOOL_FLOOR")" = "yes" ] || return 0
  say ""
  say "     ** AND YOUR UPGRADE TOOL MAY BE TOO OLD TO FIX THAT **"
  say "     tools/scaffold_upgrade.sh is $ver; $UPGRADE_TOOL_FLOOR is the first version whose"
  say "     'is this the scaffold's own repo' check is reliable. Below it, a repo that"
  say "     mirrors upstream is refused with \"There is nothing to upgrade here\" — which"
  say "     reads as nothing-to-do rather than as a broken check, so the project silently"
  say "     stops receiving releases (#130)."
  say ""
  say "     The tool cannot deliver its own replacement. Re-fetch it once, by hand:"
  # gh, not curl (#136): the upstream repo is private so the raw URL 404s, and
  # `curl -sS -o` writes that 404 body into the target instead of failing — which turns
  # the one command that rescues a stranded repo into a way to corrupt its tool.
  say "       gh api "repos/${UPSTREAM:-$UPSTREAM_DEFAULT}/contents/tools/scaffold_upgrade.sh?ref=main" \\"
  say "         --jq .content | base64 -d > tools/scaffold_upgrade.sh"
  say "       chmod +x tools/scaffold_upgrade.sh"
  say "       head -1 tools/scaffold_upgrade.sh   # must be a shebang, not '404:'"
  say "     Then ./setup.sh --upgrade --dry-run as normal."
}

is_upstream_repo() {   # is_upstream_repo <root>
  [ -d "$1/overlays" ] && [ -f "$1/OVERVIEW.md" ] && [ -f "$1/.github/workflows/mirror-sync.yml" ]
}

# DEFINED BELOW is_upstream_repo() ON PURPOSE, AND THAT IS NOT STYLE. The first version of
# this block sat above it and died with `is_upstream_repo: command not found`, taking the
# ADOPTION branch in the upstream repo and printing the opposite of the truth. This file's
# own history records the same trap in scaffold_version.sh 0.4.0; a helper placed beside its
# relatives instead of below its dependency is how it recurs.
# ---------------------------------------------------------------- --assert-consistent
#
# THE ONE PLACE THIS INVARIANT IS DEFINED. It lived only in scaffold-check.yml, so it could
# not run on the machine that cuts the release — and when Actions were blocked by billing on
# 2026-08-13 it stopped running at all. `.scaffold-version` then drifted FOURTEEN releases
# behind `version` in the upstream repo, where the two are the same file, and every fresh
# adoption inherited a merge base from fourteen releases back. Turning CI on again would have
# failed the first run.
#
# The workflow now CALLS THIS rather than reproducing it. That distinction is the whole point
# and it was the reviewer's, not mine: a local reimplementation of what the workflow does is
# not one rule enforced twice, it is two rules that will disagree — which is this project's
# single most repeated defect.
#
# TWO REPOSITORY ROLES, AND ABSENCE IS NEVER INFERRED:
#   upstream product   `.scaffold-version` MUST equal `version` — they are the same release,
#                      and `.scaffold-version` ships into a fresh adoption as its merge base.
#   adoption           they differ BY DESIGN: `version` is the adopter's product,
#                      `.scaffold-version` is the scaffold release they run. Nothing to assert.
#   no-artifact repo   no `version` at all, and it must SAY so via scaffold:no-artifact.
assert_consistent() {   # -> 0 consistent, 1 inconsistent. Prints why either way.
  _ac_bad=0
  _ac_ver=""; _ac_scf=""
  [ -f "$ROOT/version" ] && _ac_ver="$(tr -d '[:space:]' < "$ROOT/version")"
  [ -f "$LOCAL_FILE" ] && _ac_scf="$(tr -d '[:space:]' < "$LOCAL_FILE")"

  _ac_noartifact=0
  grep -qE '^<!--[[:space:]]*scaffold:no-artifact[[:space:]]*-->[[:space:]]*$' \
    "$ROOT/ai/STANDARDS.md" 2>/dev/null && _ac_noartifact=1

  if [ -z "$_ac_ver" ]; then
    if [ "$_ac_noartifact" = "1" ]; then
      say "[OK] no version file — ai/STANDARDS.md declares scaffold:no-artifact."
    else
      say "[FAIL] no version file, and no scaffold:no-artifact declaration."
      say "       A repo that ships nothing must SAY so; absence is never inferred here."
      _ac_bad=1
    fi
  elif [ "$_ac_noartifact" = "1" ]; then
    say "[FAIL] BOTH a version file ($_ac_ver) and a scaffold:no-artifact declaration."
    say "       Those are opposite claims. Delete one."
    _ac_bad=1
  fi

  if is_upstream_repo "$ROOT"; then
    if [ -z "$_ac_scf" ]; then
      say "[FAIL] upstream repo has no .scaffold-version — adopters inherit it as their base."
      _ac_bad=1
    elif [ "$_ac_scf" != "$_ac_ver" ]; then
      say "[FAIL] .scaffold-version ($_ac_scf) != version ($_ac_ver)."
      say "       In the UPSTREAM repo these are one release: a fresh adoption inherits"
      say "       .scaffold-version as the merge base for its first --upgrade, so a stale"
      say "       value hands every new adopter conflicts in regions nobody touched."
      _ac_bad=1
    else
      say "[OK] .scaffold-version matches version ($_ac_ver) — adopters inherit a correct base."
    fi
  elif [ -n "$_ac_ver" ]; then
    say "[OK] adoption: version ($_ac_ver) and .scaffold-version (${_ac_scf:-none}) differ by design."
  fi
  return "$_ac_bad"
}

if [ "${ASSERT_MODE:-0}" = "1" ]; then
  assert_consistent || exit 1
  exit 0
fi

# COUNTING THE LAG, SPLIT FROM FETCHING IT ON PURPOSE. count_newer reads a release list on
# stdin and is therefore testable without a network; releases_behind does the fetching and
# is not. Everything that can be wrong about the ORDERING lives in the half with cases on it.
count_newer() {
  # stdin: one release tag per line. $1: the version this project is on.
  # stdout: how many of them are strictly newer. Nothing at all means "could not tell".
  LOCAL_VER="$1" python3 -c '
import sys, os, re

def parts(v):
    return [int(x) for x in re.findall(r"[0-9]+", v)]

mine = parts(os.environ["LOCAL_VER"])
if not mine:
    raise SystemExit(0)
n = 0
seen = 0
for line in sys.stdin:
    tag = line.split()[0] if line.split() else ""
    # THE SAME VERSION-SHAPE FILTER newest_of HAS (audit 2026-10-08). Without it every line
    # holding a digit counted: a GraphQL error body carrying "line":1,"column":30 read as
    # one release newer than this project, and a current adopter failed its staleness gate.
    if not re.fullmatch(r"v?[0-9]+(\.[0-9]+)+", tag):
        continue
    seen += 1
    b = parts(tag)
    a = list(mine)
    a += [0] * (len(b) - len(a))
    b += [0] * (len(a) - len(b))
    if a < b:
        n += 1
# A LIST WITH NO VERSION IN IT IS "COULD NOT TELL", NOT ZERO. Zero is a pass; an error body
# is not evidence of being current.
if seen:
    print(n)
' 2>/dev/null
}

# EVERY FETCH IN A GATE NEEDS A CEILING, AND `gh` HAS NO --max-time.
#
# 0.51.0 stopped --gate reading the cache, which was right, and made every gated run depend on
# a live call -- so the call's worst case became the gate's worst case. curl was already bounded
# at 6s; `gh` is not boundable by any flag it offers, and it is the PRIMARY path here because
# the upstream repo is private and unauthenticated api.github.com would 404. An unbounded fetch
# inside preflight is a gate that can hang instead of failing, which is worse than the stale
# answer it replaced: a hang has no exit code to read.
#
# No `timeout`/`gtimeout` -- neither ships with macOS, and this script runs on adopters'
# machines. No process substitution either: bash 3.2 segfaults on one opened inside a loop.
bounded() {
  # bounded <seconds> <cmd...> -> stdout of cmd, or exit 124 having killed it.
  _bnd_secs="$1"; shift
  # `mktemp -t NAME` IS BSD-ONLY (#249). GNU coreutils requires at least three trailing
  # X's and exits 1 with "too few X's in template" -- so this returned 1 on its first line
  # and NEVER RAN THE COMMAND on Linux. Every gh call routed through bounded() failed
  # closed, and the "a slow command is KILLED" property reported 1 instead of 124, meaning
  # a hang was not bounded at all -- the exact guarantee #226 added this wrapper to provide.
  # This repo had already found, fixed and documented this class in scaffold_upgrade.sh and
  # written the lesson into four separate comments. IT CAME BACK ANYWAY -- twice, here and
  # in setup.sh -- which is the argument for a gate rather than a fifth comment. Logged.
  _bnd_out="$(mktemp "${TMPDIR:-/tmp}/scaffver.XXXXXX")" || return 1
  "$@" >"$_bnd_out" 2>/dev/null &
  _bnd_pid=$!
  _bnd_waited=0
  while kill -0 "$_bnd_pid" 2>/dev/null; do
    if [ "$_bnd_waited" -ge "$_bnd_secs" ]; then
      kill -TERM "$_bnd_pid" 2>/dev/null
      wait "$_bnd_pid" 2>/dev/null
      rm -f "$_bnd_out"
      return 124
    fi
    sleep 1
    _bnd_waited=$((_bnd_waited + 1))
  done
  wait "$_bnd_pid" 2>/dev/null
  cat "$_bnd_out"
  rm -f "$_bnd_out"
  return 0
}

probe_upstream() {  # stdout: the first candidate this machine can read, else the default
  local _c
  if command -v gh >/dev/null 2>&1; then
    for _c in "$UPSTREAM_DEFAULT" ${UPSTREAM_MIRROR:+"$UPSTREAM_MIRROR"}; do
      # COMPARE THE ANSWER. gh prints a 404 body to stdout, so "non-empty" was true for a
      # repo this machine cannot see, and bounded() does not pass gh's exit status through.
      if [ "$(bounded 8 gh api "repos/$_c" --jq .full_name | tr '[:upper:]' '[:lower:]' || true)" \
           = "$(printf '%s' "$_c" | tr '[:upper:]' '[:lower:]')" ]; then
        printf '%s\n' "$_c"; return 0
      fi
    done
  fi
  printf '%s\n' "$UPSTREAM_DEFAULT"
}

ensure_upstream() {  # call in the MAIN shell, never inside $( ), or the answer is lost
  [ -n "$UPSTREAM" ] || UPSTREAM="$(probe_upstream)"
}

tags_dated() {
  # stdout: "<tag> <tagger date>" per annotated tag upstream -- the same shape as
  # `gh release list --json tagName,publishedAt`, so the callers need no second parser.
  # THE MIRROR HAS TAGS AND NO RELEASES. release.sh tags only after every gate passed, and
  # mirror-sync pushes every tag, so on the mirror a tag IS the release record. One GraphQL
  # call returns the names and the dates; the REST tags list has no dates at all.
  # ORDERED BY DATE, NOT BY NAME. Refs sort by name by default, where "0.99" outranks
  # "0.111"; with 201 tags on the mirror (2026-10-07) a name-ordered window of 100 would
  # not even contain the newest release.
  command -v gh >/dev/null 2>&1 || return 0
  bounded 8 gh api graphql -F o="${UPSTREAM%%/*}" -F n="${UPSTREAM#*/}" \
    -f query='query($o:String!,$n:String!){repository(owner:$o,name:$n){refs(refPrefix:"refs/tags/",first:100,orderBy:{field:TAG_COMMIT_DATE,direction:DESC}){nodes{name target{... on Tag{tagger{date}}}}}}}' \
    --jq '.data.repository.refs.nodes[] | .name + " " + (.target.tagger.date // "")' || true
}

newest_of() {  # stdin: one version per line -> the highest, compared as numbers
  python3 -c '
import sys, re
best, bp = "", None
for line in sys.stdin:
    t = line.split()[0] if line.split() else ""
    if not re.fullmatch(r"v?[0-9]+(\.[0-9]+)+", t):
        continue  # an error body is not a version: one came out of 404 JSON and was cached
    p = [int(x) for x in re.findall(r"[0-9]+", t)]
    if p and (bp is None or p > bp):
        best, bp = t, p
if best:
    print(best)
'
}

releases_behind() {
  # How many upstream releases are newer than $1. Empty = undeterminable, never zero:
  # offline and current look identical otherwise, and only one of them is a pass.
  local list=""
  if command -v gh >/dev/null 2>&1; then
    # BOUNDED, same reason as the fetch below — and this is the call the GATE uses to
    # count the lag, so it is the one that decides a verdict. #226 named both; 0.51.2
    # bounded only the other one, which is what reading the issue list first would have
    # prevented.
    list="$(bounded 8 gh release list --repo "$UPSTREAM" --limit 100 --json tagName --jq ".[].tagName" || true)"
  fi
  [ -z "$list" ] && list="$(tags_dated | cut -d' ' -f1)"
  [ -z "$list" ] && return 0
  printf '%s\n' "$list" | count_newer "$1"
}

oldest_missing_age_days() {
  # $1: the version this project is on.
  # stdout: whole DAYS since the OLDEST release newer than $1 was published. The oldest is
  # the right one: it is the release that has been available longest and still not taken,
  # so it is the one the staleness claim is actually about. Nothing at all means "could not
  # tell", which gate_verdict treats as no reason to be lenient (#301).
  local list=""
  if command -v gh >/dev/null 2>&1; then
    # BOUNDED, for the reason recorded against every other gh call in this file: an
    # unbounded fetch inside a gate hangs instead of failing, and a hang has no exit code.
    list="$(bounded 8 gh release list --repo "$UPSTREAM" --limit 100 \
              --json tagName,publishedAt --jq '.[] | .tagName + " " + .publishedAt' || true)"
  fi
  [ -z "$list" ] && list="$(tags_dated)"
  [ -z "$list" ] && return 0
  printf '%s\n' "$list" | LOCAL_VER="$1" python3 -c '
import sys, os, re, datetime

def parts(v):
    return [int(x) for x in re.findall(r"[0-9]+", v)]

mine = parts(os.environ["LOCAL_VER"])
if not mine:
    raise SystemExit(0)
oldest = None
for line in sys.stdin:
    bits = line.split()
    if len(bits) < 2:
        continue
    tag, when = bits[0], bits[1]
    b = parts(tag)
    if not b:
        continue
    a = list(mine)
    a += [0] * (len(b) - len(a))
    b += [0] * (len(a) - len(b))
    if not a < b:
        continue
    try:
        # TIMEZONE-AWARE, NOT utcnow(): the tags carry a Z, utcnow() is deprecated for
        # removal, and its DeprecationWarning only stayed invisible here because this call
        # is 2>/dev/null. A warning a gate cannot show is one nobody fixes.
        ts = datetime.datetime.strptime(when[:19], "%Y-%m-%dT%H:%M:%S").replace(
            tzinfo=datetime.timezone.utc)
    except ValueError:
        continue
    if oldest is None or ts < oldest:
        oldest = ts
if oldest is not None:
    print(max(0, (datetime.datetime.now(datetime.timezone.utc) - oldest).days))
' 2>/dev/null
}

# THE SYNTHETIC ADOPTION IS STALE BY CONSTRUCTION, NOT BY CHOICE. adoption_check.sh builds
# its fixture from a pinned old release (0.36.0) precisely so the upgrade path has something
# to upgrade FROM, and it already declares itself with SCAFFOLD_ADOPTION_FIXTURE. Failing
# that fixture would make this gate impossible to satisfy in the one harness that proves an
# adopter can push. Reported as exit 3 and not 0: it renders [SKIP] "NOT verified", so the
# exemption is visible in the output rather than being a hole nobody can see.
fixture_exempt() { [ -n "${SCAFFOLD_ADOPTION_FIXTURE:-}" ]; }

cache_is_usable() {
  # (force, gate_mode) -> 0 usable / 1 not. Split from the fetch for the same reason
  # count_newer is: a decision with no network in it can be tested.
  [ "${1:-0}" = "1" ] && return 1        # --force: the caller asked for live
  [ "${2:-0}" = "1" ] && return 1        # --gate: never a cached verdict
  return 0
}

gate_verdict() {
  # $1: lag.  $2: age in DAYS of the oldest release not taken (optional).
  # Echoes the exit code this should produce. Pure, so it has cases on it.
  case "$1" in
    ""|*[!0-9]*) echo 3; return ;;                          # could not tell — never a pass
  esac
  if [ "$1" -le "$RELEASE_LAG_TOLERANCE" ]; then echo 0; return; fi
  # Over the release tolerance. #301: that opens the question, it does not answer it — a
  # burst of releases in one afternoon is upstream's cadence, not this project's neglect.
  # AGE UNKNOWN IS NOT A PASS-BY-DEFAULT: with no date we are exactly as informed as before
  # this argument existed, so keep the old verdict rather than inventing leniency from a
  # missing fact.
  # ${2-} NOT $2: this runs under `set -u`, and the one-argument call is the whole point of
  # the backward-compatible contract -- a bare $2 turns "no age known" into an unbound-variable
  # crash, which the selftest caught on the first run.
  case "${2-}" in
    ""|*[!0-9]*) echo 1; return ;;
  esac
  if [ "${2-}" -gt "$RELEASE_AGE_TOLERANCE_DAYS" ]; then echo 1; else echo 0; fi
}

if [ "$DO_SELFTEST" = "1" ]; then
  # BOTH DIRECTIONS, AND THE HEADER PARSE TOO. A floor check that never fires is the
  # failure this repo keeps recording; one that fires on everything would push every
  # adopter at a curl command they do not need.
  st_fails=0
  st() {  # st <label> <expected> <actual>
    if [ "$2" = "$3" ]; then printf '  ok   %-54s\n' "$1"
    else printf '  FAIL %-54s expected=%s got=%s\n' "$1" "$2" "$3"; st_fails=$((st_fails + 1)); fi
  }
  echo "scaffold_version selftest — the stale-upgrade-tool floor (#130), offline"
  # The real stranded value, and the real fixed value, from Robiton/localcoder.
  st "0.3.2 is below the 0.5.0 floor"        yes "$(upgrade_tool_is_older 0.3.2 0.5.0)"
  st "0.5.0 itself is not below the floor"   no  "$(upgrade_tool_is_older 0.5.0 0.5.0)"
  st "0.7.1 is not below the floor"          no  "$(upgrade_tool_is_older 0.7.1 0.5.0)"
  # 0.10 vs 0.5: a STRING compare says "0.10" < "0.5" and would strand a current repo.
  st "0.10.0 is not below the floor"         no  "$(upgrade_tool_is_older 0.10.0 0.5.0)"
  st "a build stamp does not confuse it"     no  "$(upgrade_tool_is_older 0.7.1.20260807.0548 0.5.0)"
  st "unparseable is not stale"              no  "$(upgrade_tool_is_older 'banana' 0.5.0)"
  st "empty is not stale"                    no  "$(upgrade_tool_is_older '' 0.5.0)"
  # The header parse, against this repo's own file rather than a fixture of my own shape.
  st "reads a Version: header"               1 \
     "$([ -n "$(upgrade_tool_version "$ROOT/tools/scaffold_upgrade.sh")" ] && echo 1 || echo 0)"
  st "a file with no header yields nothing"  "" "$(upgrade_tool_version /dev/null)"
  # THE UPSTREAM DISCRIMINATOR, BOTH DIRECTIONS (#134). Over-firing here is worse than
  # the bug: it would silence the staleness check for a real adoption, which is the one
  # thing this script exists to do.
  _t="$(mktemp -d "${TMPDIR:-/tmp}/scaffold_version.XXXXXX")" || { echo "scaffold_version: mktemp failed; stopping" >&2; exit 1; }
  mkdir -p "$_t/full/overlays" "$_t/full/.github/workflows"
  : > "$_t/full/OVERVIEW.md"; : > "$_t/full/.github/workflows/mirror-sync.yml"
  st "all three signals -> upstream repo"    yes "$(is_upstream_repo "$_t/full" && echo yes || echo no)"
  # A template clone keeps overlays/ + OVERVIEW.md and IS a real adoption (#113).
  mkdir -p "$_t/clone/overlays"; : > "$_t/clone/OVERVIEW.md"
  st "template clone is NOT upstream"        no  "$(is_upstream_repo "$_t/clone" && echo yes || echo no)"
  # A sibling product repo mirrors and IS a real adoption — this is the localcoder shape.
  mkdir -p "$_t/sib/.github/workflows"; : > "$_t/sib/.github/workflows/mirror-sync.yml"
  st "mirroring sibling is NOT upstream"     no  "$(is_upstream_repo "$_t/sib" && echo yes || echo no)"
  mkdir -p "$_t/plain"
  st "an ordinary adoption is NOT upstream"  no  "$(is_upstream_repo "$_t/plain" && echo yes || echo no)"
  rm -rf "$_t"

  # THE STALENESS GATE (#: preflight had no call site for this check at all).
  # count_newer is split from the fetch precisely so these can exist without a network.
  _rl="0.44.1.20260816.1151
0.44.0.20260816.0753
0.43.1.20260815.2014
0.43.0.20260815.1925"
  st "two releases newer than 0.43.1"    2   "$(printf '%s\n' "$_rl" | count_newer 0.43.1.20260815.2014)"
  st "nothing newer than the latest"     0   "$(printf '%s\n' "$_rl" | count_newer 0.44.1.20260816.1151)"
  st "a local build ahead of every tag"  0   "$(printf '%s\n' "$_rl" | count_newer 0.99.0.20260901.0000)"
  # THE SAME STRING-COMPARE TRAP THE COMPARISON ABOVE CARRIES. "0.10" < "0.5" as text, so
  # a text compare would report a current repo as nine releases behind and fail its gate.
  st "0.10.0 is not behind 0.5.0"        0   "$(printf '%s\n' "0.5.0
0.9.0" | count_newer 0.10.0)"
  st "an unparseable local version tells nothing" "" "$(printf '%s\n' "$_rl" | count_newer banana)"
  # AN ERROR BODY IS NOT A RELEASE (audit 2026-10-08). The shape a failed GraphQL call left in
  # the list: JSON whose digits are a line and a column. It counted as one newer release.
  _eb='{"errors":[{"message":"Something went wrong","locations":[{"line":1,"column":30}]}]}'
  st "an error body beside real tags adds nothing" 0 "$(printf '%s\n%s\n' "$_rl" "$_eb" | count_newer 0.44.1.20260816.1151)"
  st "an error body ALONE tells nothing, not 0"   "" "$(printf '%s\n' "$_eb" | count_newer 0.44.1.20260816.1151)"
  st "a dated tag line still counts by its tag"   1  "$(printf '%s\n' "0.44.1.20260816.1151 2026-08-16T11:51:00Z" | count_newer 0.44.0.20260816.0753)"
  # THE CACHE MAY NOT SUPPLY A GATE'S VERDICT. The defect this replaced: an adopter two
  # releases behind read `[OK] ... tracking main` off a 24h cache holding a version OLDER
  # than their own, so the staleness gate passed for the whole window it existed to guard.
  # EVERY FETCH IN A GATE NEEDS A CEILING. Asserted on the MECHANISM, not on a flag: `gh`
  # offers no --max-time, and 0.51.0 made the gate depend on a live call every run.
  _b0=$(date +%s)
  bounded 1 sleep 9 >/dev/null 2>&1; _brc=$?
  _bel=$(( $(date +%s) - _b0 ))
  st "a slow command is KILLED, not awaited"  124 "$_brc"
  st "and it is killed promptly (<=4s)"      yes "$( [ "$_bel" -le 4 ] && echo yes || echo no )"
  # THE CLASS, NOT THE INSTANCE. #226 named TWO unbounded calls and 0.51.2 bounded one --
  # fixing the instance I had looked at rather than the class the issue described. Derived from
  # the source so the NEXT call added without a bound fails here instead of shipping.
  _unbounded="$(grep -nE '(^|[^-])\bgh (release|api|auth|issue|pr) ' "$0" \
                | grep -v 'bounded [0-9]* gh ' | grep -v '^[0-9]*: *#' | grep -v 'say "' \
                | grep -cv 'grep -nE' || true)"
  st "every gh call in this file carries a bound" 0 "$_unbounded"
  st "a fast command's stdout survives"      hi  "$(bounded 5 printf 'hi')"
  st "a fast command returns 0"              0   "$(bounded 5 true >/dev/null 2>&1; echo $?)"
  st "advisory path uses the cache"      yes "$(cache_is_usable 0 0 && echo yes || echo no)"
  st "--force never uses the cache"      no  "$(cache_is_usable 1 0 && echo yes || echo no)"
  st "--gate never uses the cache"       no  "$(cache_is_usable 0 1 && echo yes || echo no)"
  st "--gate --force still fetches"      no  "$(cache_is_usable 1 1 && echo yes || echo no)"
  # gate_verdict: the tolerance, and the two ways of not knowing.
  st "lag 0 passes the gate"             0   "$(gate_verdict 0)"
  st "lag 1 is within tolerance"         0   "$(gate_verdict 1)"
  st "lag 2 FAILS the gate"              1   "$(gate_verdict 2)"
  st "an empty lag is 3, never 0"        3   "$(gate_verdict "")"
  st "a non-numeric lag is 3, never 0"   3   "$(gate_verdict banana)"
  # #301: over the lag tolerance opens the question, the AGE of the oldest missed release
  # answers it. Both directions, and the two ways of not knowing the age -- a missing date
  # must keep the OLD verdict, never invent leniency out of an absent fact.
  st "lag 2, 0 days old, passes"         0   "$(gate_verdict 2 0)"
  st "lag 6, 1 day old, passes"          0   "$(gate_verdict 6 1)"
  st "lag 2, exactly 7 days, passes"     0   "$(gate_verdict 2 7)"
  st "lag 2, 8 days, FAILS"              1   "$(gate_verdict 2 8)"
  st "lag 2, age empty, still FAILS"     1   "$(gate_verdict 2 "")"
  st "lag 2, age banana, still FAILS"    1   "$(gate_verdict 2 banana)"
  st "lag 1 passes whatever the age"     0   "$(gate_verdict 1 999)"
  # THE EXEMPTION MUST BE NARROW AND VISIBLE. It fires only on the declared fixture marker,
  # and the branch it guards exits 3 (renders [SKIP] "NOT verified"), never 0 -- an
  # exemption that reads as a pass is a hole nobody can see in the output.
  # UNSET EXPLICITLY. This suite RUNS inside the adoption fixture, which exports the very
  # marker under test -- so asserting the un-exempt case without clearing it first asserted
  # something about the environment rather than about the function, and failed there only.
  st "no fixture marker -> no exemption" no \
     "$(unset SCAFFOLD_ADOPTION_FIXTURE; fixture_exempt && echo yes || echo no)"
  st "the declared fixture marker exempts" yes \
     "$(SCAFFOLD_ADOPTION_FIXTURE=1; fixture_exempt && echo yes || echo no)"

  # WHERE THE SCAFFOLD COMES FROM. Work adopters read the the work mirror account mirror; a check
  # pinned to Robiton could never answer there. Every case uses its own temp root, never
  # this repo's files (a selftest asserts the tool, not the repo it runs in).
  _u="$(mktemp -d "${TMPDIR:-/tmp}/scaffold_version.XXXXXX")" || { echo "scaffold_version: mktemp failed; stopping" >&2; exit 1; }
  st "no env, no file -> nothing pinned"     "" "$(unset SCAFFOLD_UPSTREAM; upstream_pinned "$_u")"
  printf '# work repos read the mirror\n  acme/scaffold  # trailing note\n' > "$_u/.scaffold-upstream"
  st ".scaffold-upstream is honoured"        acme/scaffold "$(unset SCAFFOLD_UPSTREAM; upstream_pinned "$_u")"
  st "SCAFFOLD_UPSTREAM beats the file"      x/y "$(SCAFFOLD_UPSTREAM=x/y upstream_pinned "$_u")"
  # The probe, against a fake gh that can see only the mirror -- the work-machine shape.
  mkdir -p "$_u/bin"
  # A REAL gh PRINTS THE 404 BODY ON STDOUT AND EXITS 1. A fake that printed nothing is how
  # 0.111.15 shipped a probe that could never pick the mirror.
  UPSTREAM_MIRROR=example-mirror/ai-project-scaffold  # fixture: no real account (issue #387)
  printf '#!/bin/sh\ncase "$*" in *Robiton/*) echo "{\\"message\\":\\"Not Found\\",\\"status\\":\\"404\\"}"; exit 1 ;; *example-mirror/*) echo example-mirror/ai-project-scaffold ;; esac\n' > "$_u/bin/gh"
  chmod +x "$_u/bin/gh"
  st "a mirror-only machine resolves the mirror" "$UPSTREAM_MIRROR" "$(PATH="$_u/bin:$PATH" probe_upstream)"
  printf '#!/bin/sh\necho Robiton/ai-project-scaffold\n' > "$_u/bin/gh"
  st "a machine that sees Robiton takes Robiton" "$UPSTREAM_DEFAULT" "$(PATH="$_u/bin:$PATH" probe_upstream)"
  printf '#!/bin/sh\necho "{\\"message\\":\\"Not Found\\",\\"status\\":\\"404\\"}"; exit 1\n' > "$_u/bin/gh"
  st "a machine that sees neither gets the default" "$UPSTREAM_DEFAULT" "$(PATH="$_u/bin:$PATH" probe_upstream)"
  rm -rf "$_u"
  # NO RELEASES, ONLY TAGS: the newest is chosen as numbers, and a dated line parses.
  st "newest tag by number, not by text"     0.10.0 "$(printf '0.9.0 2026-01-01\n0.10.0 2026-02-01\n0.5.0\n' | newest_of)"
  st "no tags -> nothing"                    "" "$(printf '' | newest_of)"
  st "an error body is not a version"        "" "$(printf '%s\n' '{"data":{"repository":null},"errors":[{"locations":[{"line":1,"column":30}]}]}' | newest_of)"

  echo ""
  if [ "$st_fails" -eq 0 ]; then echo "  all checks passed"; exit 0; fi
  echo "  $st_fails check(s) FAILED"; exit 1
fi

# THE UPSTREAM REPO IS NOT "BEHIND" — IT IS THE THING BEING COMPARED TO (#134).
#
# `.scaffold-version` records the release a project ADOPTED, and only scaffold_upgrade.sh
# advances it. That tool correctly REFUSES to run in the scaffold's own repository, so the
# file can never move there: it sat at 0.8.0.20260805.1400 through three releases while
# `version` read 0.11.3, and this check printed BEHIND at every session start, in the repo
# whose maintainer reads it most.
#
# This file already warns, about its own comparison, that a wrong BEHIND is "the fastest
# way to teach people to ignore a version check". It was doing exactly that to itself.
#
# ALL THREE SIGNALS, because #113 established that no single one is sound —
# Robiton/localcoder mirrors upstream too, and keying on mirror-sync.yml alone stranded it
# for 13 releases. A template clone keeps overlays/ + OVERVIEW.md and IS a real adoption.
#
# DUPLICATED PREDICATE, DECLARED AS SUCH. The same three-signal test lives in
# tools/scaffold_upgrade.sh (search: "looks like the scaffold's own repository"). Two
# copies of one rule is the shape this project has been bitten by before — the Ollama
# service installer re-deriving the config path in shell is the recorded case. It is
# tolerated here because these are two independently vendored tools with no shared library
# between them, and the alternative is a third file to keep in sync. If a third site ever
# needs it, extract it instead of copying again. Change one, change both.
if is_upstream_repo "$ROOT"; then
  say "[OK] this IS the scaffold repository — nothing to compare against."
  exit 0
fi

# No marker: either the scaffold was never adopted here, or it predates tracking.
if [ ! -f "$LOCAL_FILE" ]; then
  say "[!]  no .scaffold-version — cannot tell which scaffold release this project is on."
  say "     Copy .scaffold-version from the scaffold repo when you next update."
  [ "$GATE_MODE" = "1" ] && exit 3
  exit 0
fi
LOCAL_VER="$(tr -d '[:space:]' < "$LOCAL_FILE")"

# Cache supplies LATEST and nothing else. It deliberately does NOT do its own
# comparison: an earlier version did, with a plain string inequality, so the cached
# path could report "behind" for someone who was ahead while the live path said
# otherwise. One value, one comparison, one verdict.
#
# A GATE MAY CACHE THE COST OF A CHECK, NEVER ITS VERDICT. Measured 2026-08-17: this repo
# shipped five releases in a day, an adopter's cache held 0.45.0 while 0.50.0 was current,
# and because their adopted 0.48.0 sorts ABOVE the stale 0.45.0 the gate did not merely
# under-report -- it INVERTED the verdict into `[OK] ... tracking main` and passed. Their
# preflight passed on it all day, including the run before a release. A 24-hour TTL on a
# gate in a project that releases several times a day is blind for most of the window it
# guards, and the failure is silent by construction because a stale value still looks like
# an answer.
#
# So the TTL survives for the advisory SessionStart path, which is what it was built for --
# that path costs nothing on a normal day and its verdict is a note, not a gate. Under
# --gate the cache is not consulted at all. If the fetch then fails, the branch below
# reports exit 3 (could-not-run, NOT a pass), which is the honest answer an offline gate
# owes and the one a stale cache was concealing.
LATEST=""
if cache_is_usable "$FORCE" "$GATE_MODE" && [ -f "$CACHE" ]; then
  now=$(date +%s)
  then_=$(awk 'NR==1{print $1}' "$CACHE" 2>/dev/null || echo 0)
  cached_latest=$(awk 'NR==1{print $2}' "$CACHE" 2>/dev/null || echo "")
  if [ -n "$cached_latest" ] && [ $(( (now - then_) / 3600 )) -lt "$MAX_AGE_HOURS" ]; then
    LATEST="$cached_latest"
  fi
fi

# Ask upstream when the cache had nothing. Silent on any failure — offline,
# rate-limited, private repo, no gh.
if [ -z "$LATEST" ]; then
  ensure_upstream
  if command -v gh >/dev/null 2>&1; then
    # BOUNDED: see bounded() above. On timeout this yields empty, the curl fallback gets its
    # own 6s, and if both come back empty the branch below reports exit 3 in gate mode --
    # could-not-run, which is the honest answer. A hang would have had no answer at all.
    LATEST="$(bounded 8 gh release view --repo "$UPSTREAM" --json tagName --jq .tagName || true)"
  fi
  if [ -z "$LATEST" ] && command -v curl >/dev/null 2>&1; then
    LATEST="$(curl -fsS --max-time 6 "https://api.github.com/repos/$UPSTREAM/releases/latest" 2>/dev/null \
              | sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
  fi
  [ -z "$LATEST" ] && LATEST="$(tags_dated | newest_of)"
  [ -n "$LATEST" ] && printf '%s %s\n' "$(date +%s)" "$LATEST" > "$CACHE"
fi

if [ -z "$LATEST" ]; then
  # Unknown is not "behind". Say nothing and do not fail.
  # IN GATE MODE IT IS ALSO NOT A PASS. Offline and current are indistinguishable from
  # here, and a gate that cannot reach upstream reporting green is the exact shape this
  # repository has spent months removing everywhere else.
  [ "$GATE_MODE" = "1" ] && { say "[ ] scaffold freshness NOT checked — upstream unreachable"; exit 3; }
  exit 0
fi

# COMPARE AS ORDERED VERSIONS, NOT STRINGS. `.scaffold-version` records the RELEASE a
# project adopted, but anyone tracking main carries a build-stamp NEWER than the latest
# release — the stamp advances every PR, MAJOR.MINOR.PATCH only at release. A plain
# inequality reported "BEHIND" for someone who was ahead, which is the fastest way to
# teach people to ignore a version check.
cmp_result="$(LOCAL_VER="$LOCAL_VER" LATEST="$LATEST" python3 -c '
import os, re
def parts(v):
    return [int(x) for x in re.findall(r"[0-9]+", v)]
a, b = parts(os.environ["LOCAL_VER"]), parts(os.environ["LATEST"])
a += [0] * (len(b) - len(a)); b += [0] * (len(a) - len(b))
print("same" if a == b else ("behind" if a < b else "ahead"))
' 2>/dev/null)"

case "$cmp_result" in
  same)
    say "[OK] scaffold $LOCAL_VER is current"
    exit 0 ;;
  ahead)
    # Tracking main, or a local build newer than the last release. Not a problem.
    say "[OK] scaffold $LOCAL_VER (newer than release $LATEST — tracking main)"
    exit 0 ;;
  behind)
    say "[!]  scaffold is BEHIND: this project is on $LOCAL_VER, upstream released $LATEST"
    say "     A stale scaffold looks identical to a current one from inside the repo —"
    say "     that is why this check exists. See docs/ADOPTION_GUIDE.md to update."
    check_upgrade_tool_can_run
    if [ "$GATE_MODE" = "1" ]; then
      if fixture_exempt; then
        say "     synthetic adoption fixture — staleness NOT checked (exit 3)"
        exit 3
      fi
      ensure_upstream
      _lag="$(releases_behind "$LOCAL_VER")"
      _age="$(oldest_missing_age_days "$LOCAL_VER")"
      _rc="$(gate_verdict "$_lag" "$_age")"
      case "$_rc" in
        3) say "     Could not count how many releases behind — NOT a pass." ;;
        1) if [ -n "$_age" ]; then
             say "     $_lag releases behind, and the oldest one you have not taken has been"
             say "     available $_age day(s) — over the tolerance of $RELEASE_AGE_TOLERANCE_DAYS."
           else
             say "     $_lag releases behind, over the tolerance of $RELEASE_LAG_TOLERANCE,"
             say "     and the age of the oldest missed release could not be established."
           fi
           say "     A fix has been available through at least one full release you did not take." ;;
        0) if [ "$_lag" -gt "$RELEASE_LAG_TOLERANCE" ] 2>/dev/null; then
             say "     $_lag releases behind, but the oldest you have not taken is only"
             say "     $_age day(s) old — upstream cadence, not this project going stale (#301)."
             say "     Reported, not failed. Upgrade when the work in hand is finished."
           else
             say "     $_lag release behind, within tolerance — reported, not failed."
           fi ;;
      esac
      exit "$_rc"
    fi
    exit 1 ;;
  *)
    # Could not compare — unknown is not "behind", and in gate mode it is not a pass either.
    [ "$GATE_MODE" = "1" ] && exit 3
    exit 0 ;;
esac
