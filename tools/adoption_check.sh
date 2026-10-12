#!/usr/bin/env bash
# Project:  ai-project-scaffold
# File:     tools/adoption_check.sh
# Modified: 2026-10-10
# Version:  0.10.10.20261010.1252
# Purpose:  Run this scaffold's own gates inside a synthetic ADOPTION, and fail if they
#           fail there. The gap that produced four defects in one evening.
# Changelog:
#   2026-10-10 v0.10.10.20261010.1252 — the setup fixture's owner is "R&D Ops/Infra", and TEAM.md must carry it intact.
#   2026-09-23 v0.10.9.20260923.0941 — fixtures run inside the root tools/fixture_guard.sh validates. There a git and a mktemp on PATH refuse anything that would land outside it. Every mktemp takes a ${TMPDIR} template, because macOS mktemp ignores TMPDIR without one.
#   2026-09-23 v0.10.8.20260923.0843 — every mktemp fails closed. A failed one left the temp variable empty, so the fixture ran in the caller's directory; header_check's committed into Robiton/control.
#   2026-09-23 v0.10.7.20260923.0818 — an ADOPTER that still carries overlays/ is named as
#                                      that, not failed on two scaffold-only assertions
#                                      (#1 version, #9 overlay docs) that assume ROOT is us
#   2026-09-23 v0.10.6.20260923.0702 — a preflight KILLED by a signal (exit 129-192) is reported
#                                     as killed from outside, not as "an adopter cannot push".
#                                     Still a failure.
#   2026-09-22 v0.10.5.20260922.1707 — fixture for Clocktower #9: stub threat model and
#                                      empty docs/specs/ named, and cleared once filled
#   2026-09-22 v0.10.4.20260922.1555 — Clocktower #1 fixture: the QUICK_START new project's
#                                      version must not equal the scaffold release it was
#                                      cloned from. Red before the setup.sh fix.
#   2026-09-22 v0.10.3.20260922.1548 — Clocktower #2 fixture: a planted scanner exiting 3
#                                      must read COULD NOT VERIFY through setup.sh --check,
#                                      never [FAIL] or [OK]. Mutation-proved.
#   2026-09-13 v0.10.2.20260913.0815 — the crashing-scanner assertion piped into `grep -q` twice under
#                        pipefail (#306), so it read as not-found precisely when found. Count
#                        instead. This suite runs preflight inside a synthetic adoption, so it
#                        inherited every instance of the bug as well as carrying its own.
#   2026-09-09 v0.10.1.20260909.1732 — the preflight-dirtied-the-tree failure NAMES ITS CAUSE. An adopter
#                        following AGENT_RUNBOOK.md literally hit it on a fresh repo and had to
#                        trace two paths back to a file that was never delivered to them. The
#                        manifest omits `.gitignore` deliberately -- an overlay generates it --
#                        so copying the manifest exactly leaves nothing ignoring preflight's own
#                        working files, and the first preflight dirties the tree it checks. The
#                        gate was right and unhelpful, which is the shape this project keeps
#                        paying for: a message that names the victim and not the cause.
#   2026-09-04 v0.10.0.20260904.0224 — a fourth scenario: overlay_writes() applies all seven overlays to a project
#                        that already has content and asserts nothing was overwritten — ten
#                        paths each, including the memory, backlog, session and archive files.
#                        Those were safe only because they are on no delivery list, which
#                        holds until somebody adds a line. Mutation-tested: putting #299 back
#                        names `version` in all seven and THREAT_MODEL.md in security-tool.
#   2026-09-03 v0.9.1.20260903.1929 — guide_adoption() skips, out loud, where docs/ADOPTION_GUIDE.md and overlays/
#                        do not exist. It read $ROOT unconditionally and reddened three
#                        adopters on the upgrade that shipped it.
#   2026-09-03 v0.9.0.20260903.1906 — A THIRD SCENARIO, BUILT FROM THE GUIDE AND RUNNING AN OVERLAY THAT WRITES
#                       (#297). The two existing scenarios build from a CLONE and apply
#                       python-script/base — the two overlays that write the least — so a path
#                       missing from ADOPTION_GUIDE.md was present in the fixture anyway, and
#                       nothing ever ran the splunk-app overlay where #291 and #292 lived.
#                       guide_adoption() extracts the guide's own fenced copy block and
#                       EXECUTES it, at apps/TA-fixture inside a repository, then applies the
#                       splunk overlay. It found two further defects on its first run: the
#                       guide never copied .cursor/rules/base.mdc, and the audit-log rule was
#                       skipped in every monorepo adoption. No preflight inside — the other
#                       two scenarios pay for that, and what is under test here is what
#                       setup.sh WROTE.
#   2026-09-01 v0.8.0.20260901.0249 — THIS SCENARIO CALLED A SAFETY REFUSAL A FAILURE, IN EVERY
#                        ADOPTER, AND THE RELEASE GATE COULD NOT SEE IT. new_project() clones
#                        $ROOT and asserts setup.sh completes. In the scaffold $ROOT IS the
#                        scaffold. In an adopter it is not -- adoption sheds overlays/, and
#                        0.82.5 made setup.sh REFUSE (exit 2) outside a scaffold checkout
#                        rather than half-create a tree. So 0.82.5 shipped green here and
#                        turned preflight red in all four repositories carrying it, on a
#                        deliberate refusal working exactly as designed.
#                        The adopter half is NOT a skip: a skip would drop the #256 guard out
#                        of coverage in precisely the population it protects. Inverted, it is
#                        a real gate -- the refusal travelled with the product, and it still
#                        writes nothing before refusing.
#                        THE SECOND ASSERTION COMPARES `git status --porcelain`, NOT `find`.
#                        The first version compared path lists and a mutation moving the
#                        guard back below `echo "$FULL_VERSION" > version` -- the literal
#                        #256 defect -- SURVIVED it, because an adopter already has a version
#                        file and overwriting it changes no path. A test that cannot fail on
#                        the defect it names is worse than no test: it reports coverage.
#   2026-08-30 v0.7.2.20260830.0023 — Two assertions on setup.sh's session-log stripper: that a new
#                        project does not inherit the declaration (#244), and that setup.sh
#                        SURVIVES a BACKLOG.md containing only it. The second is the one that
#                        matters: the happy-path test passes whether or not `grep -v` is
#                        guarded, which is exactly how that abort shipped.
#   2026-08-30 v0.7.1.20260830.0005 — The whole-tree fixture strips the scaffold's own
#                        scaffold:session-log declaration, as setup.sh now does for a real
#                        adopter (#244). This fixture is a COPY and never runs setup.sh, so
#                        it carried a pointer to ../ai-project-scaffold-dev that no adoption
#                        has. Invisible until #245 made a rotted pointer non-advisory, at
#                        which point this fixture failed preflight on the first run. The gate
#                        was right and the fixture was stale; weakening the gate to keep the
#                        fixture green is the trade this project refuses.
#   2026-08-23 v0.7.0 — THE FIXTURE COPIED WHAT git add DECLINES TO STAGE (#227). `tar` does
#                        not consult .gitignore, so each of the sixteen fixture builds copied
#                        the whole working tree and `git add -A` then tracked a fraction of it.
#                        Measured in an adopter's repo: 3.5 GB copied against 668 MB staged --
#                        81% waste, sixteen times, ~45 GB of pointless I/O per selftest, of
#                        which 739 MB was a Godot import cache regenerated on demand.
#                        Now copies `git ls-files -co --exclude-standard`, which IS the set
#                        `git add -A` stages: tracked, plus untracked that is not ignored.
#                        HONEST ABOUT THE LOCAL EFFECT: this repository is 6.3 MB, so the
#                        saving here is 3.5 -> 1.9 MB and the selftest still takes ~73s,
#                        unchanged within noise. The win scales with what the ADOPTER ignores
#                        and is not measurable from inside this repo. Verdicts byte-identical
#                        before and after.
#                        Falls back to the whole-tree copy if git cannot enumerate. A fixture
#                        that could not be built is a case that could not run, which is worse
#                        than one that is slow.
#                        STAMPED 0.47.0 ON THE FIRST ATTEMPT, forty versions ahead of the 0.6.0
#                        this file was actually on. The "0.46.0" in #227 is the SCAFFOLD
#                        release, not this tool, and the two were read as one. Corrected before
#                        anything pinned it -- a per-file header is not a published tag, so
#                        unlike the 1.0.0 case in localcoder this one could still be walked
#                        back. Shipped in scaffold 0.79.0 with the wrong number; 0.79.1 is the
#                        correction.
#   2026-08-17 v0.6.0.20260817.0322 — the two scenarios run CONCURRENTLY (#214). 114s -> 60s
#                        on this machine, with nothing removed from what is verified.
#                        PROFILED BEFORE TOUCHING ANYTHING, because the report said plainly
#                        that its diagnosis was inference from reading the script. It was two
#                        full inner preflights -- 43s and 42s, 75% of the cost -- plus 17s of
#                        context_survival and 10s across two setup.sh runs: 112s of a 114s
#                        run. Neither preflight is redundant, since an adoption and a
#                        from-scratch setup.sh project are different trees and the defect
#                        this file exists for was in what setup.sh LEAVES BEHIND. They share
#                        nothing but a read-only source tree, so they overlap.
#                        AND I COULD NOT REPRODUCE THE REPORTED 297s: 114s here at 0.45.0 on
#                        an M5 Max against 297s there at 0.42.0 on an M3 Max. Both are
#                        probably true; the ratio is 2.6x and it decides how much surgery is
#                        warranted, so it is recorded rather than smoothed over.
#                        NOT CACHED, NOT TIERED. A cache keyed on the scaffold version goes
#                        stale against the working tree and would hide the regression this
#                        check exists to catch. A slow tier is unsound while Actions are
#                        down, because nothing would guarantee it ever runs -- this
#                        repository's own argument about checks that stop running, applied to
#                        itself.
#                        THE SHORT-CIRCUIT IS GONE, which is a correctness change riding
#                        along: it was `run && new_project`, so a failure in the first hid
#                        the second entirely. That is exactly the complaint preflight.sh
#                        makes about CI in its own header, and this file was doing it.
#                        Mutation-verified: either scenario failing exits 1, and with both
#                        failing BOTH are reported rather than one.
#                        It also states up front what it does and prints its own MEASURED
#                        wall clock at the end -- no hardcoded "~5 minutes", which is a claim
#                        that rots on the next machine, as #214 itself demonstrates.
#   2026-08-15 v0.5.0.20260815.1100 — Plant a crashing scanner and assert setup.sh --check names it as a
#                        crash rather than printing an empty red (#212). It found a regression
#                        in that very fix immediately: a bare assignment under `set -e` took
#                        the whole script down.
#   2026-08-15 v0.4.0.20260815.0800 — Assert that a new project does not inherit the source repo's
#                        scaffold:must-run declaration. Same class as the CODEOWNERS case
#                        beside it: a statement about somebody else's product carried into a
#                        repository that cannot satisfy it, silent until the adopter's first
#                        push — and silent HERE until preflight stopped printing PASSED over a
#                        failing must-run gate.
#   2026-08-12 v0.3.1 — REPORT THE NESTED CAUSE, not just the gate that wrapped it.
#                        `[FAIL] setup.sh --check` is one gate around five scanners, so the
#                        failure line named the wrapper and nothing else. On 2026-08-12 that
#                        cost a full CI round trip: the failure reproduced on Linux only and
#                        the log said nothing a local run could act on. A check that reports
#                        a failure it cannot explain sends you off to reproduce it, which is
#                        the cost this fixture exists to remove.
#   2026-08-12 v0.3.0 — A CHECK MUST NOT MUTATE THE THING IT CHECKS, and this file could not
#                        see that it did. preflight was performing a real upgrade of the
#                        repository it was checking (scaffold_upgrade.sh v0.18.0), and every
#                        assertion here passed throughout — the fixture is a throwaway copy,
#                        so a mutation inside it is invisible. Asserting on the fixture's own
#                        CLEANLINESS afterwards is the missing half.
#                        AND THE FIXTURE IS NOW STAMPED BEHIND. The new assertion PASSED
#                        against a known-bad tree on its first run, because the fixture was at
#                        the newest release and the stray upgrade had nothing to change. A
#                        fixture that cannot reach the state under test reports a pass for a
#                        live defect.
#   2026-08-12 v0.2.0 — THE SECOND DOWNSTREAM SHAPE. This file modelled docs/ADOPTION_GUIDE.md
#                        (an existing project that took the scaffold) and nothing modelled
#                        docs/QUICK_START.md (clone the scaffold AS your project, run
#                        setup.sh). The second produces a tree carrying all three signals
#                        is_upstream_repo keys on, so a brand-new adopter was classified as
#                        THE SCAFFOLD: writing a dated ai/SESSION.md entry — the first thing
#                        AGENTS.md instructs — failed their preflight on two gates that exist
#                        only to police this repository. Found by running the published
#                        0.37.1 tarball end to end, not by reading.
#   2026-08-12 v0.1.1 — mktemp -d, BARE. The first version wrote `${TMPDIR:-/tmp%/}` trying
#                        to trim a cosmetic double slash — `%/` inside a DEFAULT VALUE is a
#                        literal, not a suffix strip. macOS sets TMPDIR so the default never
#                        fired; Linux CI does not, so it tried `/tmp%//adoption.XXXXXX`,
#                        failed, and fell back to creating `/adopt` at the filesystem root.
#                        A lesson this repo had already paid for once ($TMPDIR unbound on
#                        Linux under set -u) and I did not apply. Reproduced locally with
#                        `env -u TMPDIR` before and after.
#   2026-08-12 v0.1.0 — Initial. WE HAD NO ADOPTER IN CI, AND THAT IS A DEFECT CLASS.
#                        Every rule that is true of the scaffold and false of an adoption
#                        shipped green. On 2026-08-11 that single gap produced four defects
#                        in one evening — W-05's baseline resolving a scaffold tag against
#                        the adopter's repo, `--from "$ROOT"` one call site later, the
#                        no-localcoder-execution rule firing on adopters USING localcoder,
#                        and the context budget demanding they delete working policy. None
#                        was reachable by anything we run. All four were found by one
#                        person upgrading a real project, and two of them had to be
#                        reported twice.
#                        THE REASON THE EXISTING FIXTURES CANNOT COVER IT: they are built
#                        FROM the scaffold, so they carry `overlays/`, `OVERVIEW.md` and
#                        resolvable release tags. Those three are exactly what
#                        `is_upstream_repo` keys on, so a fixture that has them cannot
#                        express the adopter case at all — it is not that the tests were
#                        thin, it is that the shape was unreachable.
#                        A FIFTH DEFECT WOULD ALSO HAVE BEEN CAUGHT, and it is the one that
#                        matters most: `overlay application (python-script)` passed in an
#                        adoption while asserting NOTHING, because make_template_clone tars
#                        `overlays/` with stderr discarded. It was reported to us AS A PASS.
#                        This check asserts on the VERDICT, so a vacuous green is not
#                        enough — see the skip-not-pass assertion below.
# =============================================================================
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
pass=0; fail=0
ok()  { printf '  ok    %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf '  FAIL  %s\n' "$1"; fail=$((fail + 1)); }

# NO RECURSION. preflight discovers every tools/*.sh advertising --selftest and runs it;
# this one runs preflight. Without a guard that is an infinite regress, and the symptom
# would be a CI job that never finishes rather than an obvious error.
if [ -n "${SCAFFOLD_ADOPTION_FIXTURE:-}" ]; then
  echo "adoption_check: already inside the fixture — not recursing."
  exit 0
fi

build_adoption() {   # build_adoption <dir>
  local d="$1"
  mkdir -p "$d"
  # Copy the WORKING TREE, not a tag: this must test the code about to be pushed. Excluding
  # .git also removes every scaffold tag, which is half of what makes this an adoption.
  # COPY WHAT `git add -A` WOULD STAGE, NOT THE WHOLE TREE (#227). `tar` does not consult
  # .gitignore, so every fixture paid to copy build output that `git add` then declined to
  # track. Measured in an adopter's repo: 3.5 GB copied, 668 MB staged -- 81% waste, sixteen
  # times per selftest, ~45 GB of pointless I/O. `git ls-files -co --exclude-standard` is
  # exactly the set `git add -A` stages: tracked, plus untracked that is not ignored.
  #
  # This repo is 6.3 MB, so the saving HERE is small (3.5 -> 1.9 MB). The case that motivated
  # it is an adopter carrying a 739 MB Godot import cache, and the fix scales with whatever
  # the adopter ignores rather than with anything measurable from inside this repository.
  #
  # FALLS BACK RATHER THAN FAILING. If git cannot enumerate -- a broken index, no git on PATH
  # -- the old whole-tree copy still builds a correct fixture, just a slower one. A fixture
  # that could not be built is a case that could not run, which is worse than one that is slow.
  if ! ( cd "$ROOT" && git ls-files -co --exclude-standard -z 2>/dev/null \
           | tar -c --null -T - 2>/dev/null ) | ( cd "$d" && tar xf - ) 2>/dev/null; then
    ( cd "$ROOT" && tar -c --exclude=.git --exclude=dist --exclude=node_modules . 2>/dev/null ) \
      | ( cd "$d" && tar xf - ) 2>/dev/null
  fi
  # THE THREE SIGNALS is_upstream_repo KEYS ON. Removing them is the whole fixture: this is
  # what an adopter's tree looks like, because setup.sh never copies them.
  rm -rf "$d/overlays" "$d/OVERVIEW.md" "$d/.github/workflows/mirror-sync.yml"
  # AND THE SCAFFOLD'S OWN scaffold:session-log DECLARATION, for the same reason: it names
  # ../ai-project-scaffold-dev, which is true here and false in every adoption. This fixture
  # is a whole-tree COPY and never runs setup.sh, so it kept a pointer a real adopter does
  # not have — setup.sh strips it (#244). Until 2026-08-30 that discrepancy was invisible
  # because session_currency returned an ADVISORY code for a rotted pointer; #245 made it
  # non-advisory, and this fixture failed preflight on the first run afterwards. The gate
  # was right and the fixture was stale. Left in place, it would have been "fixed" by
  # weakening the gate, which is the trade this project keeps refusing.
  if [ -f "$d/ai/BACKLOG.md" ]; then
    grep -vE '^<!--[[:space:]]*scaffold:session-log[[:space:]]' "$d/ai/BACKLOG.md" \
      > "$d/ai/BACKLOG.md.tmp" && mv "$d/ai/BACKLOG.md.tmp" "$d/ai/BACKLOG.md"
  fi
  # THE FIXTURE MUST BE BEHIND, because a real adopter always is — and because an adoption
  # that is already current cannot exercise anything an upgrade would do. That is not
  # hypothetical: the mutation assertion below passed against a KNOWN-BAD tree on its first
  # run, purely because the fixture was stamped at the newest release and the stray upgrade
  # therefore had nothing to change. A fixture that cannot reach the state being tested
  # reports a pass for a defect that is live, which is this project's signature failure.
  printf '0.36.0.20260811.2130\n' > "$d/.scaffold-version"
  # An adopter carries their own tooling, including things that invoke localcoder — which
  # is the product working as designed, and which the no-execution gate used to forbid.
  mkdir -p "$d/tools"
  printf '#!/bin/sh\n# Project:  fixture\n# File:     tools/our_delegate.sh\n# Modified: 2026-08-12\n# Version:  1.0.0.20260812.0000\n# Purpose:  An adopter tool that DELEGATES, which is the product working.\nlocalcoder --lang python "$@"\n' \
    > "$d/tools/our_delegate.sh"
  chmod +x "$d/tools/our_delegate.sh"
  ( cd "$d" && git init -q . \
      && git config user.email t@t && git config user.name t \
      && git add -A && git -c commit.gpgsign=false commit -qm adoption ) >/dev/null 2>&1
}

run() {
  local tmp out rc
  # BARE `mktemp -d`. It already honours TMPDIR and falls back to /tmp correctly on both
  # platforms — a lesson this repo has paid for once already (`$TMPDIR` unbound on Linux CI
  # under `set -u`). The first version of this line wrote `${TMPDIR:-/tmp%/}` trying to trim
  # a cosmetic double slash; `%/` inside a default value is a LITERAL, not a suffix strip.
  # macOS sets TMPDIR so the default never fired, and Linux CI got `/tmp%//adoption.XXXXXX`,
  # failed, and fell back to creating `/adopt` at the filesystem root.
  tmp="$(mktemp -d "${TMPDIR:-/tmp}/adoption_check.XXXXXX")" || { echo "adoption_check: mktemp failed; stopping" >&2; exit 1; }
  # DOUBLE QUOTES: the path is expanded NOW, not when the trap fires. `tmp` is `local`, so
  # at exit it is out of scope and `set -u` kills the script in its own cleanup — an
  # unbound-variable death in an exit trap, which is the same class as the bug that made
  # this file necessary.
  trap "rm -rf '$tmp'" EXIT
  echo "adoption check — this scaffold's gates, run inside a synthetic adoption"
  echo ""

  build_adoption "$tmp/adopt"
  if [ ! -f "$tmp/adopt/tools/preflight.sh" ]; then
    bad "could not build the adoption fixture at all"
    echo "  $pass passed, $fail failed"; return 1
  fi
  ok "adoption built: no overlays/, no OVERVIEW.md, no mirror-sync.yml, no scaffold tags"

  # ---- the whole point: preflight must PASS in an adoption ---------------------------
  out="$tmp/preflight.out"; rc=0
  ( cd "$tmp/adopt" && SCAFFOLD_ADOPTION_FIXTURE=1 tools/preflight.sh --allow-dirty \
      >"$out" 2>&1 ) || rc=$?
  if [ "$rc" -eq 0 ]; then
    ok "preflight PASSES in an adoption"
  elif [ "$rc" -gt 128 ] && [ "$rc" -le 192 ]; then
    # KILLED FROM OUTSIDE is not "an adopter cannot push". Still red -- the check did not
    # finish -- but the line has to name the right suspect. 2026-09-23: an agent session's
    # `pkill -f "tools/preflight.sh"` killed this preflight in three repos' CI at once, the
    # line below said "an adopter cannot push", and it was chased as a flaky gate for an hour.
    bad "preflight was KILLED by signal $((rc - 128)) (exit $rc) before it finished — something outside this check sent it (a pkill/killall by pattern on a shared host?); rerun"
    grep -E '^\[FAIL\]|^PREFLIGHT' "$out" 2>/dev/null | sed 's/^/          /' | head -8
    # AND THE NESTED DETAIL, because the line above names the GATE and not the CAUSE.
    # `[FAIL] setup.sh --check` is one gate wrapping five scanners; without their output a
    # reader knows something broke and not what. That cost a full CI round trip on
    # 2026-08-12 — the failure reproduced on Linux only, and the log said nothing a local
    # run could act on. A check that reports a failure it cannot explain sends you off to
    # reproduce it, which is the cost this fixture exists to remove.
    if [ -s "$out" ]; then
      echo "          ---- the failing gate's own output ----"
      awk '/^\[FAIL\]/{p=1} p' "$out" 2>/dev/null | sed 's/^/          /' | head -24
    fi
  fi

  # ---- and the four specific rules that broke ----------------------------------------
  # W-05 must SKIP, not FAIL. Its baseline resolves a scaffold tag, which an adopter does
  # not have; "I could not verify" is not "it is broken".
  if grep -q '^\[SKIP\] context survival' "$out" 2>/dev/null; then
    ok "context survival SKIPS rather than failing (exit 3, not 1)"
  elif grep -q '^\[FAIL\] context survival' "$out" 2>/dev/null; then
    bad "context survival FAILED in an adoption — the 0.36.2/0.36.3 defect is back"
  else
    ok "context survival ran to completion in the adoption"
  fi

  # The no-execution rule is about OUR source. The fixture ships a tool that invokes
  # localcoder on purpose, because an adopter's delegation tooling must.
  if grep -q '^\[FAIL\] the scaffold must not invoke the localcoder binary' "$out" 2>/dev/null; then
    bad "the no-execution rule fired on an adopter's own delegation tooling"
  else
    ok "an adopter may invoke localcoder without failing a gate"
  fi

  # The 28-line budget is this repository's ratchet. Downstream it must never be fatal.
  if grep -q '^\[FAIL\] localcoder context budget' "$out" 2>/dev/null; then
    bad "the context budget was fatal in an adoption — 28 is OUR number, not theirs"
  else
    ok "the context budget is not fatal in an adoption"
  fi

  # ---- A CHECK MUST NOT MUTATE THE THING IT CHECKS.
  # tools/preflight.sh discovers and runs every selftest, and on 2026-08-12 one of them —
  # scaffold_upgrade.sh's bare-run case — performed a REAL upgrade of the host repository:
  # `cd "$ROOT" && bash "$SELF"` with no arguments. Upstream that bails for want of a base
  # tag. An adopter has a valid .scaffold-version, a network and gh, so it SUCCEEDED: PRODUCT
  # files replaced, `.scaffold-<version>` sidecars written, exit 0 throughout. An adopter
  # running the gate they are told to run before every push had their tree upgraded as a side
  # effect of checking it.
  #
  # THIS FILE COULD NOT SEE IT, and that is the interesting part. The fixture is a throwaway
  # copy, so a mutation inside it is invisible and harmless — every assertion above passed
  # while the defect was live. Asserting on the fixture's own CLEANLINESS is the missing half.
  if ( cd "$tmp/adopt" && git diff --quiet && git diff --cached --quiet \
       && [ -z "$(git status --porcelain)" ] ) 2>/dev/null; then
    ok "preflight left the adoption byte-for-byte unchanged"
  else
    bad "PREFLIGHT MODIFIED THE REPOSITORY IT WAS CHECKING:"
    ( cd "$tmp/adopt" && git status --porcelain 2>/dev/null | sed 's/^/          /' | head -6 )
    # NAME THE CAUSE, NOT ONLY THE VICTIM. Reported by an adopter 2026-09-09: this fired on
    # their first run, and the two paths it named are preflight's OWN working files. The
    # manifest deliberately omits `.gitignore` -- an overlay generates it -- so an adopter who
    # copies exactly what the manifest names has nothing ignoring them, and the first preflight
    # dirties the tree it is checking. The gate was right and unhelpful: it printed a symptom
    # the reader had to trace back to a file that was never delivered to them.
    if ( cd "$tmp/adopt" && git status --porcelain 2>/dev/null \
           | grep -qE '\.scaffold-version-check|ai/\.scaffold-run-log' ); then
      printf '        ^ THOSE ARE PREFLIGHT OWN WORKING FILES, and the cause is almost always\n'
      printf '          a missing .gitignore. The adoption manifest does not carry one (an\n'
      printf '          overlay generates it), so copying the manifest exactly leaves nothing\n'
      printf '          ignoring them. Append the scaffold block -- ADOPTION_GUIDE.md ->\n'
      printf '          "Update your .gitignore" -- so these two are ignored, then re-run:\n'
      printf '              .scaffold-version-check\n'
      printf '              ai/.scaffold-run-log\n'
    fi
  fi

  # ---- W-05 directly, because preflight only reports its verdict ---------------------
  # ASSERTING ON THE EXIT CODE, NOT ON "did it print ok". A vacuous pass is the failure
  # this whole file exists to prevent, and it was reported to us as a success.
  rc=0
  ( cd "$tmp/adopt" && SCAFFOLD_ADOPTION_FIXTURE=1 tools/context_survival.sh \
      >"$tmp/cs.out" 2>&1 ) || rc=$?
  case "$rc" in
    0) ok "context_survival exits 0 in an adoption (everything it could run, ran)" ;;
    3) ok "context_survival exits 3 in an adoption — unverified, correctly not a failure" ;;
    *) bad "context_survival exits $rc in an adoption; 0 or 3 are the honest answers" ;;
  esac
  # A SKIP MUST BE VISIBLE, NOT INFERRED. The overlay path cannot run without overlays/ and
  # used to PASS while applying nothing — green, and asserting zero. If it claims to have
  # applied an overlay here, it is lying again.
  if grep -qE '^\s+ok\s+overlay application' "$tmp/cs.out" 2>/dev/null; then
    bad "overlay application reported OK with no overlays/ present — vacuous pass is back"
  else
    ok "overlay application does not claim to have run without overlays/"
  fi

  echo ""
  echo "  logs: $tmp"
  echo "  $pass passed, $fail failed"
  [ "$fail" -eq 0 ]
}

# THE SECOND DOWNSTREAM SHAPE, AND IT WAS UNCOVERED UNTIL 2026-08-12.
#
# build_adoption() above models docs/ADOPTION_GUIDE.md: an EXISTING project that took the
# scaffold, and therefore never had overlays/, OVERVIEW.md or mirror-sync.yml. That is one of
# the two documented onboarding paths.
#
# The other is docs/QUICK_START.md step 1 — "clone the scaffold as your project, run
# ./setup.sh" — and it produces a completely different tree: one carrying ALL THREE signals
# `is_upstream_repo()` keys on. Every upstream-only rule therefore applied to the adopter, and
# the two that bite are the two that were scoped upstream-only ON PURPOSE so they could not:
# the shipped-ai-templates gate and the localcoder context budget.
#
# Measured from the published 0.37.1 tarball: a new project, set up by the book, that then did
# the first thing AGENTS.md instructs — write a dated ai/SESSION.md entry — failed
# tools/preflight.sh on both. Their session log failed the build for containing session
# entries.
#
# THIS RUNS setup.sh FOR REAL rather than simulating its output. The defect was in what
# setup.sh LEAVES BEHIND, so a fixture that constructed the tree by hand would assert my
# belief about setup.sh instead of setup.sh.
new_project() {
  local tmp out rc
  tmp="$(mktemp -d "${TMPDIR:-/tmp}/adoption_check.XXXXXX")" || { echo "adoption_check: mktemp failed; stopping" >&2; exit 1; }
  trap "rm -rf '$tmp'" EXIT
  echo "new-project check — docs/QUICK_START.md's path: clone the scaffold, run setup.sh"
  echo ""

  # A CLONE OF THIS REPOSITORY, which is what step 1 tells them to make.
  mkdir -p "$tmp/proj"
  ( cd "$ROOT" && tar -c --exclude=.git --exclude=dist --exclude=node_modules . 2>/dev/null ) \
    | ( cd "$tmp/proj" && tar xf - ) 2>/dev/null
  ( cd "$tmp/proj" && git init -q . && git config user.email t@t && git config user.name t \
      && git add -A && git -c commit.gpgsign=false commit -qm init ) >/dev/null 2>&1
  if [ ! -f "$tmp/proj/setup.sh" ]; then
    bad "could not build the new-project fixture"; return 1
  fi
  ok "new project built from a clone of this repository"

  # ONLY THE SCAFFOLD CAN RUN THIS SCENARIO — AND THE OTHERS MUST PROVE THE REFUSAL.
  #
  # Everything below models QUICK_START.md step 1, "clone the scaffold", and it clones
  # $ROOT. In the scaffold $ROOT IS the scaffold. In an ADOPTER it is not: setup.sh's
  # templates live in overlays/, adoption sheds overlays/, and since 0.82.5 setup.sh
  # refuses with exit 2 rather than half-creating a tree. So from 0.82.5 this scenario
  # asserted, in every adopter, that a deliberate safety refusal was a failure — and it
  # did so in the four repositories that carry the scaffold, not in the scaffold itself,
  # which is why the release gate was green when it shipped.
  #
  # The adopter half is NOT a skip. A skip here would drop the #256 guard out of coverage
  # in exactly the population it protects. Inverted, it is a real gate: the refusal
  # travels with the product, and it still writes nothing before refusing.
  # AN ADOPTER STILL CARRYING overlays/ (measured 2026-09-23, product-tracker). Adoption
  # sheds overlays/, but nothing removes one an older adoption kept, and setup.sh's guard keys
  # on overlays/ alone -- so such a clone passes the refusal below, setup.sh RUNS, and every
  # assertion after it assumes ROOT is the scaffold: the new project "is born at the scaffold's
  # version" because ROOT/version is the adopter's own, and a stale overlay has none of #9's
  # documents. Two failures, neither naming the cause. One finding that does.
  if [ -d "$ROOT/overlays" ] && ! { [ -f "$ROOT/OVERVIEW.md" ] \
       && [ -f "$ROOT/.github/workflows/mirror-sync.yml" ]; }; then
    bad "this adopter still carries overlays/ -- the scaffold's template store, which adoption sheds"
    echo "          setup.sh will run from it, and every check after this point assumes"
    echo "          it is the scaffold. Remove it:  git rm -r overlays"
    return 1
  fi
  if [ ! -d "$ROOT/overlays" ] || [ ! -f "$ROOT/ai/STANDARDS.md" ]; then
    local dirt
    ( cd "$tmp/proj" && SCAFFOLD_ADOPTION_FIXTURE=1 bash setup.sh \
        --type python-script --name fixture --owner "Fixture" >"$tmp/setup.out" 2>&1 ) || rc=$?
    # WHAT CHANGED, NOT WHAT EXISTS. The first version of this compared `find` output before
    # and after, and a mutation that moved the guard back below `echo "$FULL_VERSION" > version`
    # -- the literal #256 defect -- SURVIVED it: an adopter already has a `version` file, so
    # overwriting it changes no path. The fixture is a git repo committed at init, so porcelain
    # catches an overwrite and a new file alike.
    dirt="$( cd "$tmp/proj" && git status --porcelain 2>/dev/null )"
    if [ "${rc:-0}" -eq 2 ]; then
      ok "setup.sh refuses (exit 2) outside the scaffold — the #256 guard reached this adopter"
    else
      bad "setup.sh did NOT refuse outside the scaffold (exit ${rc:-0}) — the #256 guard is missing here"
      head -5 "$tmp/setup.out" 2>/dev/null | sed 's/^/          /'
    fi
    if [ -z "$dirt" ]; then
      ok "the refusal changed nothing — its own message is true"
    else
      bad "setup.sh wrote before refusing — 'Nothing has been created or modified' is a lie"
      printf '%s\n' "$dirt" | sed 's/^/          /' | head -5
    fi
    echo ""
    echo "  the rest of this scenario is the scaffold's: it needs overlays/ to run setup.sh."
    return 0
  fi

  # AN OWNER NAME WITH SED METACHARACTERS (report item 28, S11). `&` pasted the whole
  # placeholder row inside the name and `/` ended the expression, so TEAM.md kept its
  # template row with nothing said. The name goes in as given and must come out the same.
  ( cd "$tmp/proj" && SCAFFOLD_ADOPTION_FIXTURE=1 bash setup.sh \
      --type python-script --name fixture --owner "R&D Ops/Infra" >"$tmp/setup.out" 2>&1 ) || rc=$?
  if [ "${rc:-0}" -ne 0 ]; then
    bad "setup.sh failed in a new project (exit ${rc:-0})"
    grep -E '^ERROR|^\[FAIL\]' "$tmp/setup.out" 2>/dev/null | sed 's/^/          /' | head -5
    return 1
  fi
  ok "setup.sh completes in a new project"
  if grep -qF '| R&D Ops/Infra | | | |' "$tmp/proj/ai/TEAM.md" 2>/dev/null; then
    ok "an owner name with & and / reaches TEAM.md intact"
  else
    bad "the owner name \"R&D Ops/Infra\" did not reach TEAM.md intact: $(grep -m1 -E 'R&D|Your Name' "$tmp/proj/ai/TEAM.md" 2>/dev/null)"
  fi

  # A NEW PROJECT IS NOT BORN AT THE SCAFFOLD'S VERSION (Clocktower #1). The clone carries
  # our `version`; setup.sh used to keep it as the adopter's own.
  if [ "$(tr -d ' \n' < "$tmp/proj/version" 2>/dev/null)" = "$(tr -d ' \n' < "$ROOT/version" 2>/dev/null)" ]; then
    bad "the new project's version is the scaffold's own release ($(cat "$ROOT/version"))"
  else
    ok "the new project's version is its own, not the scaffold release it was cloned from"
  fi

  # THE PREDICATE MUST BE FALSE AFTERWARDS. This is the whole finding: a cloned scaffold
  # satisfies all three signals until setup.sh sheds them.
  if [ -d "$tmp/proj/overlays" ] && [ -f "$tmp/proj/OVERVIEW.md" ] \
     && [ -f "$tmp/proj/.github/workflows/mirror-sync.yml" ]; then
    bad "a set-up project still looks like the SCAFFOLD — every upstream-only gate applies to it"
  else
    ok "a set-up project is no longer classified as the scaffold"
  fi
  # `* @Robiton` in an adopter's repo puts us on every one of their pull requests.
  if [ -f "$tmp/proj/.github/CODEOWNERS" ]; then
    bad "the adopter kept our CODEOWNERS — their PRs would request review from Robiton"
  else
    ok "the adopter does not inherit our CODEOWNERS"
  fi

  # A SCANNER THAT DIES ON A SIGNAL MUST NOT PRINT A RED GATE WITH AN EMPTY BODY (#212).
  #
  # This is what the adopter actually saw: `[FAIL] tools/marker_scan.sh:` followed by nothing,
  # because a process killed by a signal has no output to echo. A red with no finding is worse
  # for a human than a false green — the false green is quiet, this one sends someone hunting a
  # defect in their own repository that was never there.
  #
  # Asserted through setup.sh --check for real, with a planted crashing scanner, because the
  # collapse happened in setup.sh's loop and not in any scanner.
  cp tools/marker_scan.sh "$tmp/marker_scan.bak" 2>/dev/null || true
  printf '#!/usr/bin/env bash\nkill -SEGV $$\n' > "$tmp/proj/tools/zz_crash_scan.sh"
  chmod +x "$tmp/proj/tools/zz_crash_scan.sh"
  out="$( cd "$tmp/proj" && SCAFFOLD_ADOPTION_FIXTURE=1 bash setup.sh --check 2>&1 || true )"
  rm -f "$tmp/proj/tools/zz_crash_scan.sh"
  # COUNT, never `grep -q` -- see #306. grep -q exits at the first match, printf takes
  # SIGPIPE, and under pipefail the pipeline reports 141, so this reads as "not found"
  # precisely when it IS found.
  _sig="$(printf '%s\n' "$out" | grep -c "DIED ON SIGNAL" || true)"
  _adv="$(printf '%s\n' "$out" | grep -c "not a problem in your repository" || true)"
  if [ "${_sig:-0}" != "0" ] && [ "${_adv:-0}" != "0" ]; then
    ok "a scanner that dies on a signal is reported as a crash, not as a finding"
  else
    bad "a crashing scanner still prints a red gate with no finding (#212)"
    printf '%s' "$out" | grep -A2 'zz_crash' | sed 's/^/          /' | head -4
  fi

  # A SCANNER THAT COULD NOT VERIFY (EXIT 3) IS A GAP, NOT A FINDING (Clocktower #2).
  printf '#!/usr/bin/env bash\necho "zz: cannot run here"\nexit 3\n' > "$tmp/proj/tools/zz_gap_scan.sh"
  chmod +x "$tmp/proj/tools/zz_gap_scan.sh"
  out="$( cd "$tmp/proj" && SCAFFOLD_ADOPTION_FIXTURE=1 bash setup.sh --check 2>&1 || true )"
  rm -f "$tmp/proj/tools/zz_gap_scan.sh"
  _gapl="$(printf '%s\n' "$out" | grep -c 'zz_gap_scan.sh COULD NOT VERIFY' || true)"
  # The loop's own line shapes only: header_check separately (and rightly) flags the planted
  # file's missing header, and that line is not the verdict under test.
  _gapf="$(printf '%s\n' "$out" | grep -c '^\[FAIL\] tools/zz_gap_scan.sh:$' || true)"    # scaffold:path-not-an-instruction
  _gapo="$(printf '%s\n' "$out" | grep -c '^\[OK\]   tools/zz_gap_scan.sh' || true)"    # scaffold:path-not-an-instruction
  if [ "${_gapl:-0}" != "0" ] && [ "${_gapf:-0}" = "0" ] && [ "${_gapo:-0}" = "0" ]; then
    ok "a scanner that exits 3 is reported COULD NOT VERIFY — neither [FAIL] nor [OK]"
  else
    bad "a scanner exiting 3 was reported as a finding or a pass (Clocktower #2)"
    printf '%s' "$out" | grep 'zz_gap' | sed 's/^/          /' | head -3
  fi

  # AN OVERLAY'S DOCUMENTS ARE READ, NOT JUST ITS NAME (Clocktower #9). A security-tool
  # project with the five-heading stub and an empty docs/specs/ gets both named; filling them
  # clears both. Planted and restored, so nothing after this sees the change.
  cp "$tmp/proj/ai/STANDARDS.md" "$tmp/standards.bak"
  printf '\n# Overlay: security-tool\n' >> "$tmp/proj/ai/STANDARDS.md"
  mkdir -p "$tmp/proj/docs/specs"
  [ -f "$tmp/proj/docs/THREAT_MODEL.md" ] && cp "$tmp/proj/docs/THREAT_MODEL.md" "$tmp/tm.bak"
  printf '# Threat Model\n\n## Trust boundaries\n\n## Data flows\n' > "$tmp/proj/docs/THREAT_MODEL.md"
  out="$( cd "$tmp/proj" && SCAFFOLD_ADOPTION_FIXTURE=1 bash setup.sh --check 2>&1 || true )"
  _tms="$(printf '%s\n' "$out" | grep -c 'THREAT_MODEL.md is still the unfilled stub' || true)"
  _spe="$(printf '%s\n' "$out" | grep -c 'docs/specs/ is empty' || true)"
  printf 'An attacker on the LAN can reach the collector.\n' >> "$tmp/proj/docs/THREAT_MODEL.md"
  printf '# Spec\n' > "$tmp/proj/docs/specs/collector.md"
  out="$( cd "$tmp/proj" && SCAFFOLD_ADOPTION_FIXTURE=1 bash setup.sh --check 2>&1 || true )"
  _tms2="$(printf '%s\n' "$out" | grep -c 'THREAT_MODEL.md is still the unfilled stub' || true)"
  _spe2="$(printf '%s\n' "$out" | grep -c 'docs/specs/ is empty' || true)"
  cp "$tmp/standards.bak" "$tmp/proj/ai/STANDARDS.md"
  rm -f "$tmp/proj/docs/specs/collector.md"; rmdir "$tmp/proj/docs/specs" 2>/dev/null || true
  if [ -f "$tmp/tm.bak" ]; then cp "$tmp/tm.bak" "$tmp/proj/docs/THREAT_MODEL.md"
  else rm -f "$tmp/proj/docs/THREAT_MODEL.md"; fi
  if [ "${_tms:-0}" != "0" ] && [ "${_spe:-0}" != "0" ] && [ "${_tms2:-0}" = "0" ] && [ "${_spe2:-0}" = "0" ]; then
    ok "an unfilled threat model and an empty docs/specs/ are named, and clear once filled"
  else
    bad "overlay documents not read: stub=$_tms/$_tms2 specs=$_spe/$_spe2 (want 1/0 1/0) (Clocktower #9)"
  fi

  # A NEW PROJECT MUST NOT INHERIT THE SOURCE REPO'S MUST-RUN DECLARATION. Same class as
  # CODEOWNERS above: a statement about somebody else's product, carried into a repository that
  # cannot satisfy it. Asserted rather than assumed, because the failure is silent until the
  # adopter's first push — and it was silent HERE until preflight stopped printing PASSED over
  # a failing must-run gate on 2026-08-15.
  if [ -f "$tmp/proj/AGENTS.md" ] \
     && grep -qE '^<!--[[:space:]]*scaffold:must-run[[:space:]]' "$tmp/proj/AGENTS.md"; then
    bad "the adopter inherited a scaffold:must-run declaration naming OUR test suite"
  else
    ok "a new project does not inherit the source repo's must-run declaration"
  fi

  # NOR THE SESSION-LOG POINTER (#244) -- it names ../ai-project-scaffold-dev, which is true
  # in the scaffold and false in every adoption.
  if [ -f "$tmp/proj/ai/BACKLOG.md" ] \
     && grep -qE '^<!--[[:space:]]*scaffold:session-log[[:space:]]' "$tmp/proj/ai/BACKLOG.md"; then
    bad "the adopter inherited a scaffold:session-log declaration naming OUR -dev sibling"
  else
    ok "a new project does not inherit the source repo's session-log declaration"
  fi

  # THE EDGE CASE THAT ABORTED setup.sh ENTIRELY, and the reason this assertion exists at all.
  # The stripper is `grep -v ... > tmp; mv tmp file`. grep -v exits 1 when it filters EVERY
  # line, `set -e` is in force, and an ai/BACKLOG.md consisting of nothing but that
  # declaration therefore killed setup.sh two thirds of the way through -- exit 1, no message,
  # in a run whose happy path was green. Pinned here because the happy-path test above passes
  # either way, which is exactly how the defect shipped in the first place.
  _edge="$tmp/edge"
  rm -rf "$_edge"; mkdir -p "$_edge"
  ( cd "$ROOT" && tar -c --exclude=.git --exclude=dist --exclude=node_modules . 2>/dev/null ) \
    | ( cd "$_edge" && tar xf - ) 2>/dev/null
  rm -f "$_edge/.claude/settings.json"
  printf '<!-- scaffold:session-log ../nope/ai/SESSION.md -->\n' > "$_edge/ai/BACKLOG.md"
  ( cd "$_edge" && git init -q . 2>/dev/null
    SCAFFOLD_ADOPTION_FIXTURE=1 bash setup.sh --type base --name edge --owner E >/dev/null 2>&1 )
  _edge_rc=$?
  if [ "$_edge_rc" -eq 0 ]; then
    ok "setup.sh survives a BACKLOG.md that is only the declaration (set -e + grep -v)"
  else
    bad "setup.sh aborted (exit $_edge_rc) on a BACKLOG.md containing only the declaration"
  fi
  rm -rf "$_edge"

  # AND THE THING THAT ACTUALLY BIT: do what AGENTS.md tells them to do, then push.
  printf '\n## 2026-08-12 — Fixture — Tool used: Claude Code\n\nDid some work.\n' \
    >> "$tmp/proj/ai/SESSION.md"
  ( cd "$tmp/proj" && git add -A && git -c commit.gpgsign=false commit -qm session ) >/dev/null 2>&1
  out="$tmp/preflight.out"; rc=0
  ( cd "$tmp/proj" && SCAFFOLD_ADOPTION_FIXTURE=1 tools/preflight.sh >"$out" 2>&1 ) || rc=$?
  if [ "$rc" -eq 0 ]; then
    ok "a new project that writes a dated SESSION.md entry can still push"
  else
    bad "preflight FAILS after the adopter does what AGENTS.md instructs (exit $rc):"
    grep -E '^\[FAIL\]|^PREFLIGHT' "$out" 2>/dev/null | sed 's/^/          /' | head -6
  fi

  echo ""
  echo "  logs: $tmp"
  echo "  $pass passed, $fail failed"
  [ "$fail" -eq 0 ]
}

# PROVE IT CAN FAIL. A fixture nobody has seen fail is a fixture nobody should believe —
# the same argument context_survival.sh makes for itself.
prove_it_fails() {
  local tmp before
  tmp="$(mktemp -d "${TMPDIR:-/tmp}/adoption_check.XXXXXX")" || { echo "adoption_check: mktemp failed; stopping" >&2; exit 1; }
  trap "rm -rf '$tmp'" EXIT
  echo "adoption check — INJECTED: an upstream-only gate made fatal downstream"
  build_adoption "$tmp/adopt"
  # Reinstate the pre-0.36.2 behaviour: the context budget as a hard gate everywhere.
  perl -0pi -e 's/if is_upstream_repo_inline; then\n/if true; then\n/' \
    "$tmp/adopt/tools/preflight.sh" 2>/dev/null || true
  perl -0pi -e 's/\[ -d overlays \] && \[ -f OVERVIEW\.md \] && \[ -f \.github\/workflows\/mirror-sync\.yml \]/true/' \
    "$tmp/adopt/tools/preflight.sh" 2>/dev/null || true
  before=$fail
  local rc=0
  ( cd "$tmp/adopt" && SCAFFOLD_ADOPTION_FIXTURE=1 tools/preflight.sh --allow-dirty \
      >"$tmp/neg.out" 2>&1 ) || rc=$?
  if [ "$rc" -ne 0 ]; then
    echo "  ok — with the upstream-only scoping removed, the adoption's preflight FAILS"
    echo "       (exit $rc), which is what this check exists to catch."
    return 0
  fi
  echo "  FAIL — scoping was removed and the adoption still passed. This check proves nothing."
  return 1
}

# TWO INDEPENDENT SCENARIOS, RUN CONCURRENTLY (#214).
#
# PROFILED BEFORE CHANGING ANYTHING, because the report said outright that its diagnosis was
# inference. Measured here with `PS4=+[$SECONDS] bash -x`, scaffold 0.45.0, M5 Max:
#
#     43s  tools/preflight.sh              (inside new_project)
#     42s  tools/preflight.sh --allow-dirty (inside run)
#     17s  tools/context_survival.sh
#      5s  bash setup.sh --type python-script
#      5s  bash setup.sh --check
#            -> 112s of a 114s run
#
# So it is TWO FULL PREFLIGHTS, 85s between them, 75% of the cost. One outer preflight
# therefore pays for three preflight runs. Neither inner run is redundant -- an adoption and
# a from-scratch `setup.sh` project are different trees, and the defect this file exists for
# was in what setup.sh LEAVES BEHIND -- so the fix is to overlap them, not to drop one.
# They build separate fixtures in separate temp directories and share nothing but the
# read-only source tree.
#
# NOT CACHED and NOT TIERED, deliberately. A cache keyed on the scaffold version would go
# stale against the working tree and hide exactly the regression this check exists to catch;
# and a slow tier is unsound while Actions are down, because nothing would guarantee it ever
# runs -- this repository's own argument, applied to itself.
#
# AND NEITHER SCENARIO SHORT-CIRCUITS THE OTHER ANY MORE. It was `run && new_project`, so a
# failure in the first hid the second completely. That is the precise complaint preflight.sh
# makes about CI in its own header -- "a push teaches you about exactly one failure and hides
# the next behind it" -- and this file was doing it too.
# ---- SCENARIO 3: THE ADOPTION THE GUIDE ACTUALLY DESCRIBES, WITH AN OVERLAY (#297).
#
# The two scenarios above build their fixture from a CLONE of this repository and apply
# `--type python-script`. Both choices hid real defects for months:
#
#   - A clone contains every path, so a path missing from docs/ADOPTION_GUIDE.md's copy
#     block is present in the fixture anyway. `.githooks/` was absent from the guide for
#     two releases and no fixture could notice (#294).
#   - python-script and base are the two overlays that WRITE THE LEAST. Everything in
#     #291 and #292 lives in the splunk-app overlay, which nothing here ever ran.
#
# So this scenario builds the fixture BY EXECUTING THE GUIDE'S OWN COPY BLOCK — if the guide
# stops copying something, this fixture stops having it — and then applies the overlay that
# writes files. No preflight inside: the two scenarios above already pay for that, and what
# is under test here is what setup.sh WROTE, not whether the gates pass afterwards.
guide_adoption() {
  local tmp proj rc=0 blk
  tmp="$(mktemp -d "${TMPDIR:-/tmp}/adoption_check.XXXXXX")" || { echo "adoption_check: mktemp failed; stopping" >&2; exit 1; }; proj="$tmp/repo/apps/TA-fixture"
  mkdir -p "$proj/default"
  echo "guide adoption — the copy block in ADOPTION_GUIDE.md, then the splunk-app overlay"
  echo ""

  # ---- THIS SCENARIO IS THE SCAFFOLD'S. An adopter has no docs/ADOPTION_GUIDE.md and no
  # overlays/, so there is nothing here to build a fixture from. Skipping is correct and it
  # is NOT a pass: the two scenarios above are the ones that must travel with the product,
  # and they do. Saying so out loud rather than returning silently, because a scenario that
  # quietly does nothing is how a suite reports 8 passed while testing 6 things.
  #
  # This half was learned the hard way one release earlier: the first version read $ROOT
  # unconditionally and reddened every adopter on the upgrade that delivered it. A selftest
  # asserts the TOOL, not the repo it happens to be sitting in.
  if [ ! -f "$ROOT/docs/ADOPTION_GUIDE.md" ] || [ ! -d "$ROOT/overlays" ]; then
    echo "  --    NOT RUN here: this scenario needs docs/ADOPTION_GUIDE.md and overlays/,"
    echo "        which an adoption sheds. It runs in the scaffold repository."
    rm -rf "$tmp"
    return 0
  fi

  ( cd "$tmp/repo" && git init -q . && printf 'root\n' > README.md \
      && git add -A && git -c user.email=f@f -c user.name=f commit -qm root ) >/dev/null 2>&1

  printf '[install]\n' > "$proj/default/app.conf"
  # A rule the adopter had before we arrived, and one the guide tells them to add. Both
  # must survive. The overlay used to `cat >` over the top of them.
  printf 'ADOPTER_OWN_RULE.env\n.env\n' > "$proj/.gitignore"

  # THE FIXTURE IS THE GUIDE. Extract the fenced bash from step 3 and run it verbatim.
  blk="$tmp/copy.sh"
  awk '/^### 3\. Copy the scaffold files/{s=1} /^### 4\./{s=0} s' "$ROOT/docs/ADOPTION_GUIDE.md" \
    | awk '/^```bash$/{f=1;next} /^```$/{f=0} f' > "$blk"
  if [ ! -s "$blk" ]; then
    bad "could not extract the guide's copy block — the fixture cannot be built from the guide"
    rm -rf "$tmp"; return 1
  fi
  ok "the guide's copy block extracted ($(grep -c '' "$blk") lines)"
  ( cd "$proj" && SCAFFOLD_DIR="$ROOT" bash "$blk" ) >"$tmp/copy.out" 2>&1 || rc=$?
  if [ "${rc:-0}" -ne 0 ]; then
    bad "the guide's own copy block failed (exit $rc) — an adopter following it cannot proceed"
    tail -5 "$tmp/copy.out" | sed 's/^/          /'
    rm -rf "$tmp"; return 1
  fi
  ok "the guide's copy block runs clean"

  # overlays/ is not part of an adoption, but setup.sh needs it to APPLY one. The guide
  # runs setup.sh from the scaffold clone for this reason; the fixture mirrors that.
  cp -R "$ROOT/overlays" "$proj/overlays"

  # #294: every path this repository delivers on upgrade must be here after the guide.
  local missing=""
  for m in $("$ROOT/tools/adoption_manifest.sh" --list | sed 's|/$||'); do
    # LICENSE is optional by design (a proprietary project skips it) and docs/ is
    # REFRESH-only — an upgrade must not push a docs/ tree into a project that never took
    # one. Both are exempt in tools/adoption_manifest.sh for the same stated reasons; this
    # list and that one must agree, which is the joke the whole file is about.
    case "$m" in LICENSE|docs) continue ;; esac
    [ -e "$proj/$m" ] || missing="$missing $m"
  done
  if [ -z "$missing" ]; then
    ok "the guide delivers every path on the adoption manifest"
  else
    bad "the guide's copy block does not deliver:$missing"
  fi

  ( cd "$proj" && bash setup.sh --type splunk-app --name TA-fixture --owner Fixture \
      --splunk-existing >"$tmp/setup.out" 2>&1 ) || rc=$?
  if [ "${rc:-0}" -ne 0 ]; then
    bad "setup.sh failed on a guide-shaped splunk adoption (exit $rc)"
    grep -E '^ERROR|^\[FAIL\]' "$tmp/setup.out" 2>/dev/null | sed 's/^/          /' | head -8
  else
    ok "setup.sh --type splunk-app completes and its own --check passes"
  fi

  # #292: the overlay must APPEND to .gitignore, never replace it.
  if grep -qxF 'ADOPTER_OWN_RULE.env' "$proj/.gitignore"; then
    ok "the adopter's own .gitignore rule survived the overlay"
  else
    bad "the overlay DESTROYED the adopter's .gitignore — this is #292, back again"
  fi
  if grep -q 'localcoder-audit' "$proj/.gitignore"; then
    ok "the localcoder audit-log rule survived the overlay"
  else
    bad "the overlay erased .localcoder-audit.jsonl* — the log holds tokens and query rows"
  fi

  # #291: a correctly built artifact must not carry the scaffold onto the host.
  if [ -f "$proj/build.sh" ]; then
    local unexcluded=""
    for m in $("$ROOT/tools/adoption_manifest.sh" --list | sed 's|/$||'); do
      grep -qF "\${APP_NAME}/$m\"" "$proj/build.sh" || unexcluded="$unexcluded $m"
    done
    if [ -z "$unexcluded" ]; then
      ok "build.sh excludes every scaffold path an adoption carries"
    else
      bad "build.sh would package the scaffold onto a production host:$unexcluded"
    fi
  else
    bad "the splunk-app overlay wrote no build.sh"
  fi

  # #296: the fixture is at repo/apps/TA-fixture, so the notice must fire.
  if grep -q 'SUBDIRECTORY of a git repository' "$tmp/setup.out" 2>/dev/null; then
    ok "the monorepo notice fires for a project below the repository root"
  else
    bad "no monorepo notice — an inert .github/ ships with nothing saying so (#296)"
  fi

  rm -rf "$tmp"
  return 0
}

# ---- SCENARIO 4: NO OVERLAY DESTROYS ANYTHING THE PROJECT ALREADY HAD (#299).
#
# Every overlay writes template documents for the project it is applying to, and applying an
# overlay to an EXISTING project is a documented mode. Each of those writes was a plain
# `cat >`. Measured across all seven with a fixture holding real content:
#
#   - `version` was reset from 9.9.9 to 0.1.0 by ALL SEVEN, despite ADOPTION_GUIDE.md saying
#     in so many words that the file is the adopter's and is deliberately not copied.
#   - the security-tool overlay replaced a filled-in `docs/THREAT_MODEL.md` with an empty
#     stub — in a security project, the document most expensive to lose.
#
# THE MEMORY AND ARCHIVE FILES WERE ALREADY SAFE, and this scenario exists partly to keep
# them that way: ai/MEMORY.md, ai/BACKLOG.md, ai/SESSION.md, ai/TEAM.md and the three
# *_ARCHIVE.md files are asserted here on every run, in every overlay. They are on no
# delivery list, which is why they survive — and "it is safe because nothing lists it" is
# exactly the kind of guarantee that holds until someone adds a line.
#
# CHEAP: seven `setup.sh --type` runs, no preflight, no network.
overlay_writes() {
  local tmp base rc=0 t
  tmp="$(mktemp -d "${TMPDIR:-/tmp}/adoption_check.XXXXXX")" || { echo "adoption_check: mktemp failed; stopping" >&2; exit 1; }
  echo "overlay writes — seven overlays against a project that already has content"
  echo ""

  if [ ! -d "$ROOT/overlays" ]; then
    echo "  --    NOT RUN here: needs overlays/, which an adoption sheds."
    rm -rf "$tmp"; return 0
  fi

  for t in base ai-skill splunk-app security-tool python-script it-automation api-integration; do
    base="$tmp/$t"; mkdir -p "$base"
    ( cd "$base" && git init -q . ) >/dev/null 2>&1
    cp -R "$ROOT/ai" "$ROOT/overlays" "$ROOT/tools" "$base/"
    for f in AGENTS.md .cursorrules .windsurfrules .codex .editorconfig setup.sh sync-check.sh; do
      cp "$ROOT/$f" "$base/"
    done
    chmod +x "$base/setup.sh" "$base"/tools/*.sh 2>/dev/null || true

    # Content a real project would have, and would not forgive losing.
    printf '9.9.9.20200101.0000\n' > "$base/version"
    printf 'ADOPTER_RULE.env\n'    > "$base/.gitignore"
    mkdir -p "$base/docs"
    printf '# Threat Model\n\nSENTINEL_THREAT\n'      > "$base/docs/THREAT_MODEL.md"
    printf '# Project Memory\n\nSENTINEL_MEMORY\n'    > "$base/ai/MEMORY.md"
    printf '# Project Backlog\n\n- [ ] SENTINEL_BACKLOG\n' > "$base/ai/BACKLOG.md"
    printf '# Session Log\n\n## 2026-01-01\nSENTINEL_SESSION\n' > "$base/ai/SESSION.md"
    printf '# Team\n\nSENTINEL_TEAM\n'                > "$base/ai/TEAM.md"
    printf '# Sessions\n\nSENTINEL_SESSION_ARCHIVE\n' > "$base/ai/SESSION_ARCHIVE.md"
    printf '# Backlog\n\nSENTINEL_BACKLOG_ARCHIVE\n'  > "$base/ai/BACKLOG_ARCHIVE.md"
    printf '# Memory\n\nSENTINEL_MEMORY_ARCHIVE\n'    > "$base/ai/MEMORY_ARCHIVE.md"
    ( cd "$base" && git add -A && git -c user.email=f@f -c user.name=f commit -qm init ) >/dev/null 2>&1

    if [ "$t" = "splunk-app" ]; then
      ( cd "$base" && bash setup.sh --type "$t" --name Fixture --owner F --splunk-existing ) \
        >"$tmp/$t.log" 2>&1 || true
    else
      ( cd "$base" && bash setup.sh --type "$t" --name Fixture --owner F ) \
        >"$tmp/$t.log" 2>&1 || true
    fi

    # THE OVERLAY MUST HAVE ACTUALLY RUN, or every assertion below is vacuous. This is the
    # check that catches a fixture whose setup.sh refused: a run that did nothing preserves
    # everything perfectly.
    if ! grep -q 'overlay applied\|Overlay standards\|Setup check' "$tmp/$t.log"; then
      bad "$t — setup.sh did not apply the overlay; the assertions below would be vacuous"
      sed -n '1,3p' "$tmp/$t.log" | sed 's/^/            /'
      rc=1
      continue
    fi

    local lost="" pair f n
    for pair in \
      "version:9.9.9" \
      ".gitignore:ADOPTER_RULE" \
      "docs/THREAT_MODEL.md:SENTINEL_THREAT" \
      "ai/MEMORY.md:SENTINEL_MEMORY" \
      "ai/BACKLOG.md:SENTINEL_BACKLOG" \
      "ai/SESSION.md:SENTINEL_SESSION" \
      "ai/TEAM.md:SENTINEL_TEAM" \
      "ai/SESSION_ARCHIVE.md:SENTINEL_SESSION_ARCHIVE" \
      "ai/BACKLOG_ARCHIVE.md:SENTINEL_BACKLOG_ARCHIVE" \
      "ai/MEMORY_ARCHIVE.md:SENTINEL_MEMORY_ARCHIVE" ; do
      f="${pair%%:*}"; n="${pair##*:}"
      grep -q "$n" "$base/$f" 2>/dev/null || lost="$lost $f"
    done

    if [ -z "$lost" ]; then
      ok "$t — nothing the project already had was overwritten"
    else
      bad "$t — the overlay DESTROYED:$lost"
      rc=1
    fi
  done

  rm -rf "$tmp"
  return $rc
}

selftest_both() {
  local o1 o2 r1 r2 t0
  t0=$SECONDS
  echo "adoption_check: two end-to-end scenarios, each running a full preflight inside its own"
  echo "  fixture, run concurrently. This takes MINUTES, not seconds, and is not hung."
  echo ""
  # FIXTURES RUN INSIDE A GUARDED ROOT (tools/fixture_guard.sh). Later mktemps land inside it,
  # and a git on PATH refuses any write outside it. The guard exists because a failed mktemp
  # once let a selftest run git init and commit in the real repo.
  . "$(dirname "${BASH_SOURCE[0]}")/fixture_guard.sh" || { echo "adoption_check: tools/fixture_guard.sh is missing; refusing to build fixtures" >&2; exit 1; }
  fixture_root FG_ROOT; trap fg_cleanup EXIT
  o1="$(mktemp "${TMPDIR:-/tmp}/adoption_check.XXXXXX")" && o2="$(mktemp "${TMPDIR:-/tmp}/adoption_check.XXXXXX")" && o3="$(mktemp "${TMPDIR:-/tmp}/adoption_check.XXXXXX")" && o4="$(mktemp "${TMPDIR:-/tmp}/adoption_check.XXXXXX")" \
    || { echo "adoption_check: mktemp failed; stopping" >&2; exit 1; }
  ( run            >"$o1" 2>&1; echo "$?" >"$o1.rc" ) &
  ( new_project    >"$o2" 2>&1; echo "$?" >"$o2.rc" ) &
  # The third is the cheap one — no preflight inside — so it lands well before the others
  # and costs nothing in wall clock. It is also the only one that runs an overlay which
  # writes files, which is where every defect in #291..#296 lived.
  ( guide_adoption >"$o3" 2>&1; echo "$?" >"$o3.rc" ) &
  ( overlay_writes  >"$o4" 2>&1; echo "$?" >"$o4.rc" ) &
  wait
  cat "$o1"; echo ""; cat "$o2"; echo ""; cat "$o3"; echo ""; cat "$o4"
  r1="$(cat "$o1.rc" 2>/dev/null || echo 1)"
  r2="$(cat "$o2.rc" 2>/dev/null || echo 1)"
  r3="$(cat "$o3.rc" 2>/dev/null || echo 1)"
  r4="$(cat "$o4.rc" 2>/dev/null || echo 1)"
  rm -f "$o1" "$o2" "$o3" "$o4" "$o1.rc" "$o2.rc" "$o3.rc" "$o4.rc"
  echo ""
  echo "adoption_check: four scenarios in $((SECONDS - t0))s wall clock."
  # MEASURED, NOT DECLARED. A hardcoded "~5 minutes" is a claim that rots on the next
  # machine -- the report that opened #214 measured 297s where this measures 114s.
  [ "$r1" -eq 0 ] && [ "$r2" -eq 0 ] && [ "$r3" -eq 0 ] && [ "$r4" -eq 0 ]
}

case "${1:-}" in
  --selftest)       selftest_both ;;
  --new-project)    new_project ;;
  --guide)          guide_adoption ;;
  --overlay-writes) overlay_writes ;;
  --prove-it-fails) prove_it_fails ;;
  "")               selftest_both ;;
  *) echo "usage: adoption_check.sh [--selftest|--new-project|--prove-it-fails]" >&2; exit 2 ;;
esac
