#!/usr/bin/env bash
# Project:  ai-project-scaffold
# File:     tools/preflight.sh
# Modified: 2026-10-10
# Version:  0.47.16.20261010.1324
# Purpose:  One command, run after `git commit` and before `git push`, that runs what CI runs.
# Changelog:
#   2026-10-10 v0.47.16.20261010.1324 — workflow_audit's coverage text names actionlint too (report item 29).
#   2026-10-10 v0.47.15.20261010.1205 — NEW GATE, upstream only: every `# >>> shared:<name>` block is identical in every file its `# carried by:` line names (report item 16).
#   2026-10-09 v0.47.14.20261009.1903 — a linked worktree gets its own GAP line quoting the main checkout's start count, not the generic 'wired and not firing' (#368). The block is lifted and run against a stub session_hook; proven red against the old text.
#   2026-10-06 v0.47.13.20261006.0503 — THE SELFTEST'S FAKE GATES NO LONGER WRITE TO THE
#                        LIVE RUN LOG. _probe runs real gate plumbing, and log_verdict appended
#                        every probe to ai/.scaffold-run-log -- about 734 rows each of
#                        "preflight:failing/skipping/passing gate" here, read by --report as
#                        checks that ran. PREFLIGHT_NO_LOG=1 inside _probe; a selftest case
#                        asserts the log's line count is unchanged.
#   2026-09-25 v0.47.11.20260925.0324 — selftest: thirteen pre-push cases for the default-branch refusal: main, HEAD:main, master, deleting main, a tag, a remote HEAD that adds trunk but cannot unprotect main, and the column-0 opt-out, which counts only from the REMOTE (a bare repo stands in), never from the checkout or a forged tracking ref. The existing HEAD case now pushes a feature branch.
#   2026-09-24 v0.47.10.20260924.1023 — QUIET BY DEFAULT: a passing gate prints nothing; every GAP, FAIL and NOT-verified prints in full, and the verdict line counts the passes it did not print. --verbose (or SCAFFOLD_VERBOSE=1) lists them. Caveated passes ("not checked here", "DECLARED UNAVAILABLE") still print, so nothing skipped reads as a pass.
#   2026-09-24 v0.47.9.20260924.0834 — the reverse --coverage check demands a mapping for every tool this file NAMES, not only those on disk. 0.47.8 filtered to existing files, so the scaffold (no tools/sbom.py) was green and localcoder (which has it) failed the selftest that runs --coverage on the repo as shipped. sbom.py is a declared known gap.
#   2026-09-24 v0.47.8.20260924.0416 — --coverage checks the OTHER direction: every tool this file runs that CI does not must have a local_only_note() entry, or --coverage fails. The comment said "both directions"; both halves checked local-covers-CI, so dependency_audit ran only here and COLLECTO PR #91 went CI-green with uuid 7.0.3. Nine real gates are declared known gaps and print as GAPs.
#   2026-09-23 v0.47.7.20260923.1022 — selftest: six pre-push cases for WHAT IS PUSHED
#                                      rather than what is checked out; the existing cases
#                                      run the hook with stdin closed.
#   2026-09-23 v0.47.6.20260923.0941 — fixtures run inside the root tools/fixture_guard.sh validates. There a git and a mktemp on PATH refuse anything that would land outside it. Every mktemp takes a ${TMPDIR} template, because macOS mktemp ignores TMPDIR without one.
#   2026-09-23 v0.47.5.20260923.0843 — every mktemp fails closed. A failed one left the temp
#                        variable empty, so the fixture ran in the caller's directory; header_check's
#                        committed into Robiton/control. AND the dependency gate calls --strict:
#                        --check turned findings into exit 0, so a scan WITH findings printed
#                        "[PASS] ... no known vulnerabilities". Selftest 1y runs the lifted block.
#   2026-09-22 v0.47.4.20260922.1855 — the wiring gap quotes --check-wiring's first finding
#                                      instead of guessing it from the exit code, which
#                                      named the wrong problem for redirect drift and for
#                                      a shadowed guard.
#   2026-09-22 v0.47.3.20260922.1642 — wiring check: exit 2 from --check-wiring takes the
#                                      wired path and reports the missing post-compact
#                                      reminder as a gap
#   2026-09-22 v0.47.2.20260922.1550 — UNPUSHED COMMITS ON main ARE A GAP when ai/TEAM.md
#                                      forbids committing there (Clocktower #3). Not a
#                                      failure: scaffold upgrades commit on main by design.
#                                      Says how to move the commits to a branch.
#   2026-09-22 v0.47.1.20260922.1536 — A DIRTY PASS IS NO RECEIPT. --allow-dirty wrote the
#                                      same ok sha=<HEAD> row as a clean pass, so the pre-
#                                      push hook waved through HEAD bytes that were never
#                                      gated as committed. The row now says
#                                      sha=<HEAD>+dirty, which the hook's prefix match
#                                      refuses; a selftest case pins it.
#   2026-09-22 v0.47.0.20260922.1448 — audit coverage gate. tools/audit_coverage.sh ships --check,
#                        and case 1b-vii fails a tool that ships --check with no gate
#                        calling it -- a selftest proves a tool WORKS, only a call here
#                        proves it RUNS. It is a GAP locally and says so: the question is
#                        "did ANY leg of the fan-out produce a verdict", and one machine is
#                        not a fan-out. Passing would be a green built from an absence;
#                        failing would redden every local push for a condition no local run
#                        can create. coverage_note() learned the tool in the same commit --
#                        the --coverage/selftest/adoption_check trio all fail on that one
#                        missing line, which is one fix at the top, not three.
#   2026-09-22 v0.46.0 — TWO NEW GATES, AND ONE REAL DEFECT IN THIS FILE.
#
#                        shell_lint.sh and workflow_audit.sh join the gate list. Neither
#                        tool existed and neither language was checked: shellcheck was
#                        present on some machines and wired to nothing, and zizmor had
#                        found a LIVE template injection in the shipped workflow the day
#                        before -- `github.base_ref` interpolated into a run: block, live in
#                        four repositories at once because that workflow is vendored. It was
#                        found by hand, once, and the follow-up sweep still missed a repo.
#
#                        THE DEFECT: four sites did `FAILED=$((FAILED + 1))` while gate()
#                        has always treated FAILED as a STRING OF GATE NAMES (`FAILED=""`,
#                        then `FAILED="$FAILED $label"`). Both orders are wrong and they
#                        fail differently, which is why it survived:
#                          a label first, then arithmetic -> `alpha: unbound variable`,
#                            FATAL under `set -u`, taking down the run
#                          arithmetic first, then a label -> a clean-looking summary
#                            reporting 2 failed gates when 1 failed, one of them named `1`
#                        All four converted to the string contract. FAIL_NAMES, a parallel
#                        variable that was assigned in four places and READ IN NONE, is
#                        removed -- and note that v0.42.5 had already "fixed" it by guarding
#                        it with ${FAIL_NAMES:-}, which silenced the crash and left the real
#                        defect quieter than before. A guard on a variable nobody reads is
#                        not a fix; it is a way to stop being told.
#
#                        python_floor_gate() no longer hand-rolls the 0/1/3 split -- it
#                        calls gate(), like lint_python.sh already did. Its bespoke copy is
#                        where the FAILED arithmetic came from, which is the argument
#                        against duplicated rules stated as a measurement rather than a
#                        preference.
#   2026-09-22 v0.45.0.20260922.0511 — python_floor_gate(): pyproject declares a
#                        requires-python floor and, until today, NOTHING in this repository
#                        read it. Not setup.sh, not a gate, not CI -- a promise made to every
#                        downstream installer and audited by no one. The gate parses every
#                        Python file against the declared floor's own grammar. Exit 3 / GAP
#                        when nothing declares a floor, because "examined nothing" is not
#                        "found nothing wrong". One new gate; it reports GAP in this repo.
#   2026-09-21 v0.44.4.20260921.1229 — one is_upstream(), not eight copies of it (#315).
#                        This file open-coded `[ -d overlays ] && [ -f OVERVIEW.md ] &&
#                        [ -f .github/workflows/mirror-sync.yml ]` EIGHT times to decide
#                        whether an upstream-only gate runs at all, while mode_scan.sh had
#                        already extracted the identical test as is_upstream() and
#                        context_survival.sh as scaffold_clone(). The failure mode of the
#                        copies is SILENCE: change the signature and each stale copy stops
#                        matching, the gate it guards never runs again, and nothing goes
#                        red -- the AGENTS.md ten-copy defect, which printed [OK] at real
#                        projects for as long as it existed. Gate count unchanged at 53;
#                        no gate gained, lost or changed its verdict. The extracted
#                        shipped-ai-kind fixture carries the predicate via `declare -f`,
#                        so it tests the real one rather than a ninth spelling.
#   2026-09-21 v0.44.3.20260921.1126 — A VERIFIED GREEN LOOKED EXACTLY LIKE NEVER CHECKING.
#                        The consuming case handled red, pending and unknown. `ok` and `skip`
#                        had no branch at all, so a run that READ the CI verdict and found it
#                        green printed nothing and counted nothing -- byte-identical output to
#                        a run where the precondition did not apply. This gate's whole thesis
#                        is that a non-verdict must not read as a pass, and its own reporting
#                        broke it one layer above the code that enforces it. Same shape as
#                        ci_status.sh #312: the vocabulary was short a word.
#                        Found by applying the #312 generalisation as a sweep -- when a guard
#                        carries a documented exemption, ask what the exempted case produces
#                        INSTEAD; if the answer is "the same output as the happy path", no
#                        call-site conditional can fix it.
#                        `ok` now prints [PASS] and names the ref it is about (#289: a verdict
#                        is a claim about a sha, and a branch moves). `skip` stays silent, and
#                        that silence is only defensible BECAUSE ok is loud -- otherwise
#                        "does not apply" and "checked and green" collapse again.
#                        Two structural selftest cases, asserted on the source because
#                        reproducing this needs a green CI and the invariant does not. Both
#                        watched RED: silencing ok fails one, deleting skip fails the other.
#   2026-09-21 v0.44.2.20260921.1122 — THE FIRST FEATURE BRANCH AN ADOPTER MAKES HAS NO UPSTREAM.
#                        `git rev-parse @{u}` exits 128 there, and an empty capture reading as
#                        "nothing red" is the shape of both bugs already fixed in this function.
#                        Driven rather than reasoned about, in temp repos with no network: a
#                        never-pushed branch reports unknown and says why (the caller turns that
#                        into a named gap, never a silent green); a repo with no origin remote
#                        SKIPS, because a repo that was never going to have CI has nothing to be
#                        advisory about and a gap people learn to ignore is worse than no gap.
#                        Both cases watched RED first -- mutating the absent-upstream branch to
#                        report ok turns the case red with the bug quoted back.
#                        Also records what @{u} MEANS here: the ref you would push to. This is a
#                        pre-push gate, so the verdict that matters is the one on the thing you
#                        are pushing onto. On a feature branch tracking origin/main that is
#                        main's verdict, correctly -- and "the last push's" and "the upstream's"
#                        are the same sentence in English, which is why it is now in the source.
#   2026-09-21 v0.44.1.20260921.1105 — GREEN WAS A DENYLIST, so `stale` counted as a pass. The
#                        aggregate matched the four red conclusions and let every other row fall
#                        through to the GREEN count. `stale` is a real GitHub conclusion; it
#                        reached no verdict and was read as one -- the precise failure this
#                        precondition exists to prevent, occurring inside the precondition, for
#                        the second time in this file's short history (the first was a literal
#                        tab inside a regex). Found by driving _ci_aggregate with one row per
#                        conclusion rather than by reading it.
#                        GitHub publishes NO conclusion-only enum -- the REST reference gives a
#                        single combined status/conclusion filter list -- so a denylist here is
#                        a promise that cannot be checked against anything, and it absorbs in
#                        silence whatever GitHub adds after this line was written. Inverted:
#                        success, skipped and neutral are green (they ran and did not object),
#                        the four remain red, and ANYTHING ELSE is unresolved -- exit 3, the
#                        could-not-run answer, not a pass.
#                        RED STAYS A DENYLIST ON PURPOSE. Calling CI red is a positive claim
#                        about someone's build and an unrecognised conclusion does not license
#                        it; unrecognised is unresolved, which is the honest half.
#                        AND THE UNRESOLVED MESSAGE NAMED THE WRONG FIELD: it printed the
#                        status, so a cancelled run told the reader preflight was blocking
#                        because "CI is completed" -- true, and no help. It now names the
#                        conclusion. Four selftest cases, each watched RED against the previous
#                        aggregate before being kept, and the lists now live in ONE classifier
#                        rather than three filters that can drift apart.
#   2026-09-21 v0.44.0.20260921.0645 — PRECONDITION: the LAST PUSH's CI verdict must be resolved.
#                        `check CI after every push` has been a standing fleet rule for weeks and
#                        it did not fire: a session shipped two scanner adapters, verified them
#                        with local `preflight.sh` alone, reported success, and CI had been RED on
#                        main the whole time. The rule was known and written down. NOTHING FORCED
#                        THE CHECK, and a rule enforced only by memory is enforced by nothing --
#                        writing it down again is the same class of control that already failed.
#                        So it moves into the tool: preflight now refuses to print PREFLIGHT
#                        PASSED while the commit at @{u} has a red or still-running run.
#                        MODELLED ON --allow-dirty, DELIBERATELY. A red CI must NOT hard-FAIL,
#                        or you cannot get a green preflight to push the FIX -- a gate that
#                        deadlocks the repair is a gate people delete. So: exit 3, the same
#                        "NO CHECK HAS FAILED, this is a precondition" shape as a dirty tree,
#                        with --ci-unresolved-ok one flag away.
#                        ADVISORY WHEN CI CANNOT BE REACHED, AND THIS IS A REAL LIMIT, recorded
#                        here rather than discovered later: no gh, no upstream, no network, a
#                        404 from a silently switched account -- all print a GAP and let the run
#                        report clean. Blocking every offline push would get the precondition
#                        disabled within a day, and a disabled gate checks nothing at all.
#   2026-09-21 v0.43.2.20260921.0959 — shipped-ai-kind enumerated `ai/*.md` OFF THE DISK while its own
#                        stated invariant is about what we SHIP. tools/session_journal.sh creates
#                        ai/SESSION_JOURNAL.md on every session, .gitignore excludes it, and NOTHING
#                        writes the kind marker into it -- so the gate hard-failed on an untracked,
#                        never-shipped file. Every adopter who ran a second session went red for
#                        doing nothing wrong. It stayed green HERE only because this machine's
#                        journal had been hand-marked once, which is how a shipped gate stays green
#                        for its author and red for everyone else. Both loops now read git ls-files;
#                        an empty list is a GAP, not a pass. Found by a peer session, not by CI.
#                        _kind_leak is also initialised now -- it was only ever `unset`.
#   2026-09-13 v0.43.1.20260913.0831 — FAIL_NAMES was unbound under `set -u` when a gate was the FIRST
#                        failure. runner_value_gate() copied the append from a gate that runs
#                        later, where FAIL_NAMES already existed -- so the new gate crashed
#                        preflight outright instead of reporting. All three appends now use
#                        ${FAIL_NAMES:-}.
#   2026-09-12 v0.43.0.20260912.1131 — selftest_mode_gate(). A TOOL THAT SHIPS --selftest AND CANNOT
#                        BE EXECUTED HAS A RETIRED SUITE, AND THIS FILE SAID NOTHING.
#                        selftest_tools() filters on `[ -x ]`, which is correct, but did it
#                        silently -- so a lost mode bit stopped a suite running locally with
#                        no word. CI has named this at the point it bites since the
#                        conflict_scan.sh incident (15 cases, tracked 644, step reported
#                        "12 suites passed" in green); preflight did not.
#                        mode_scan.sh IS NOT THE SAME COVER. In an adoption it checks only
#                        files whose header says the scaffold wrote them, so an adopter's
#                        OWN tool shipping --selftest at 644 falls through both -- skipped
#                        here without comment, out of scope there. REPORTED BY AN ADOPTER
#                        (collectionapp) who hit exactly that: their tool errored in CI
#                        while local preflight stayed quiet.
#                        SAME STANDARD THIS FILE ALREADY APPLIES ONE LAYER UP. It refuses a
#                        commit when a tool ships --check and no gate calls it; a tool that
#                        ships --selftest and cannot be invoked is that defect with the mode
#                        bit as the cause instead of the wiring. core.fileMode=false is the
#                        correct setting here and is exactly what hides it.
#   2026-09-12 v0.42.4.20260912.1119 — runner_value_gate(). ci_status.sh grew --check and this file
#                        did not call it, which its OWN selftest catches: "a tool ships
#                        --check and no preflight gate calls it (selftest-green, unused)".
#                        A capability nobody runs is one nobody trusts, and the guard was
#                        right to block the commit that shipped it.
#                        The gate is worth having on its own terms: a malformed
#                        SCAFFOLD_RUNNERS kills the workflow during expression evaluation,
#                        before any step exists, with an error that never names the
#                        variable. Catching that locally costs one call; catching it in CI
#                        costs a run that looks like a broken runner.
#   2026-09-11 v0.42.3.20260911.1202 — doc_currency_gate(). SPLIT OUT, like archive_gate, because
#                        inline in run_all it could only be exercised by owning a repository
#                        whose documents had actually drifted -- which is precisely how the
#                        drift went unnoticed. Exit 3 (nothing declared) is a GAP, not a
#                        pass: a checker that examined nothing is could-not-verify.
#   2026-09-04 v0.42.2.20260904.0624 — a shipped TEMPLATE naming a `../` sibling must be stripped by the adoption
#                        guide (#302). ai/BACKLOG.md carries scaffold:session-log pointing at
#                        ../ai-project-scaffold-dev and SHOULD — our log really is there. The
#                        defect was that it TRAVELLED: setup.sh strips it, the guide's manual
#                        path (the only route for existing code) did not, and every manual
#                        adoption hard-failed session_currency exit 4 on its first preflight.
#   2026-09-03 v0.42.1.20260903.1914 — the adoption-manifest gate uses the CANONICAL is_upstream_repo signals.
#                        Its first draft invented a fourth spelling and --selftest's drift pin
#                        caught it in one run, which is the pin doing precisely its job.
#   2026-09-03 v0.42.0.20260903.1906 — TWO GATES FOR THE ADOPTION DEFECTS NOTHING HERE COULD SEE (#291, #293, #294).
#                       `adoption manifest` runs tools/adoption_manifest.sh --check: the four
#                       restatements of what an adoption receives had all drifted at once and
#                       no gate compared them. `shipped ai/ file kind` requires every shipped
#                       ai/*.md to declare `template` or `reference`, and a reference file to
#                       say so to a human — ai/PROVENANCE.md and ai/STANDARDS_EVIDENCE.md
#                       shipped as our own engineering notes and the existing templates gate
#                       covered neither, because it checks three named files for dated
#                       headings. A grep for `ai-project-scaffold` would have missed
#                       STANDARDS_EVIDENCE.md entirely, whose self-reference is the phrase
#                       "this repository" — the correlate, not the property. Both gates are
#                       upstream-only: they are rules about what WE ship.
#   2026-09-01 v0.41.0.20260901.1656 — A DECLARED GAP STOPS READING AS A FIRING HOOK (#275).
#                        This file ran `session_hook.sh --closeout >/dev/null 2>&1` and then
#                        printed "wired AND the last start was recorded as HOOK_RAN" for
#                        every exit 0. `closeout` returns 0 for TWO states, and one of them
#                        is the opposite of that sentence: a repository declaring
#                        `<!-- scaffold:hooks-unavailable ... -->` has NO hook records at all
#                        and exits 0 BECAUSE the gap is declared. Preflight reported the
#                        escape hatch as a healthy hook, in green -- a verdict stronger than
#                        its evidence, which is the one thing this file exists to prevent.
#                        The closeout's own words are printed now, and the declared case has
#                        its own verdict line naming the reason.
#                        AND the localcoder budget ADVISORY prints WHICH sections are over
#                        it. The number was in the message and the actionable half was in
#                        stdout, which went to /dev/null (#277).
#                        AND `note`, a new verdict class, whose first subject is: how much
#                        delegable python landed with no draft row (localcoder#201).
#                        A NEW VERDICT CLASS THAT CANNOT FAIL. `note` touches neither PASSED,
#                        FAILED nor GAPS. It exists because the delegation share must be
#                        VISIBLE before it is enforceable: a threshold set from an opinion
#                        rather than from fleet data teaches people to route around the gate,
#                        which is this file's own most-repeated lesson.
#                        MEASURED 2026-09-01: 576 delegable lines in Robiton/localcoder and
#                        278 here in one week, 0 drafted in both, every report green. The
#                        share is the first check here whose denominator comes from git
#                        rather than from a log somebody has to remember to write.
#                        EXIT 3 IS PRINTED, NOT SWALLOWED. "No draft log here" is the right
#                        answer for an adopter with no localcoder, and it renders as that
#                        sentence rather than as silence or as a clean 0%.
#   2026-09-01 v0.40.0.20260901.0845 — THE VERDICT NOW NAMES THE COMMIT IT IS ABOUT, which
#                        is what makes the pre-push hook cheap enough to leave installed.
#                        The run log said `preflight:preflight ok 46 gate(s)` and nothing
#                        about WHAT was gated, so a pass from four commits ago was
#                        indistinguishable from the one you just ran -- and the hook
#                        therefore re-ran the entire ~173s gate to learn something this
#                        script had recorded seconds earlier. A hook that costs three
#                        minutes per push is one people uninstall, or route around until
#                        --no-verify is reflex; on this machine that is exactly what
#                        happened, and an adopter independently reported the shape it
#                        leaves: `preflight ; push` typed with a SEMICOLON, so the gate ran,
#                        FAILED, and the push went through anyway.
#                        Four cases run the REAL hook file against fixtures. The fourth is
#                        the one that matters: a stale PASS followed by a FAIL must not
#                        shortcut, because reading the newest PASS rather than the newest
#                        VERDICT would skip straight past the failure after it -- rebuilding
#                        the defect inside the guard. Mutation-verified both ways.
#   2026-09-01 v0.39.0.20260901.0531 — THE BURST MESSAGE NAMED ONE COMMAND FOR THREE FILES.
#                        --apply rotates SESSION.md and deliberately does not touch
#                        MEMORY.md -- ai/STANDARDS.md forbids auto-rotating it, because
#                        deciding which lines of a decision are load-bearing is judgement.
#                        So the new burst gate added in 0.38.0 sent people to a tool that
#                        correctly does nothing for the file they were sent about, and which
#                        until session_archive.py 0.17.0 then told them everything was
#                        already archived. A gate is only as good as the remedy it names.
#   2026-09-01 v0.38.0.20260901.0435 — THE ARCHIVE CEILINGS ARE A GATE NOW, AND A HOOK THAT
#                        NEVER FIRED IS A FAILURE (#265, #264).
#                        #265: the label said "archive ceilings" and nothing gated them.
#                        session_archive.py has shipped --exit-status since 0.11.0,
#                        documented as "so a caller can branch on the RESULT instead of
#                        grepping this tool's prose" -- and its only caller was setup.sh's
#                        ADVISORY block, so [PASS] printed over a breached ceiling under a
#                        label naming that ceiling. The shape 1b-vii catches is a --check
#                        nobody calls; this is one level out, a --check whose only caller
#                        cannot fail. OVER stays advisory -- 0.14.0 argued out failing on
#                        file length and that still holds -- but PAST THE BURST LINE fails,
#                        because the tool's own words for it are "a trim that stopped
#                        happening, not 'a bit over'". Three cases, since a fix failing on
#                        both would recreate what 0.14.0 removed and one failing on neither
#                        is what was reported. archive_gate() is split out so the branch is
#                        testable without owning an over-the-line repository.
#                        #264: an adopter found two repos, four days, 1333 logged rows and
#                        ZERO session_hook:start -- reported as an advisory GAP, exit 0, so a
#                        repository where no hook had ever run went green. --closeout asks
#                        about the MOST RECENT start, the right question for "did it work
#                        this session" and the wrong one for "has this client ever called
#                        us". Escalated only when the log PROVES the repo has been worked in
#                        (50+ rows from other tools, still no start); a fresh adoption
#                        returns 3, because reddening there is the hazard 0.58.0 shipped.
#   2026-09-01 v0.37.0.20260901.0419 — THE DECLARED MUST-RUN GATES DID NOT RUN ON A RED RUN
#                        (#259). They sat below the first `if [ -n "$FAILED" ]; then ...
#                        return 1`, so whenever any other gate had already failed, the
#                        adopter's own declared suite was skipped -- and not listed under
#                        DID NOT RUN either, because GAPS is only appended by the skip
#                        helpers and these never reached one. The condition under which you
#                        most want the product suite was the condition that dropped it, and
#                        AGENTS.md says plainly that a declared gate which does not run is a
#                        FAILURE whatever the reason. The reason was our own control flow.
#                        FOURTH DISTINCT FAILURE OF THIS ONE MECHANISM: never called; called
#                        after the only $FAILED check; verdict discarded; and now not reached
#                        on a red run. Each earlier fix was pinned by a case that could not
#                        see the next layer, so this one asserts the ORDERING -- must_gate
#                        must appear before the first failure return -- which is the property
#                        all three previous cases lacked.
#                        AND THE COVERAGE CLAIM IS CONDITIONAL NOW. "your project's own test
#                        suite -- run it separately" printed unconditionally, which is simply
#                        false in a repo declaring scaffold:must-run, and read as if the
#                        omission were deliberate on exactly the runs where the gates had
#                        been silently dropped.
#                        "DID NOT RUN on this machine" IS NO LONGER THE HEADING (#258). A
#                        missing ruff is a machine gap; session_currency on a repo that never
#                        tags is a REPOSITORY gap that no installation will ever close. Both
#                        printed under one heading that asserted the first cause.
#   2026-09-01 v0.36.0.20260901.0345 — "EVERYTHING CI WILL RUN" WAS FALSE ABOUT THIS FILE'S OWN
#                        SUITE, AND HAD BEEN FOR THREE RECORDED FAILURES. CI discovers every
#                        tools/*.sh advertising --selftest and runs it, preflight.sh
#                        included; preflight excluded ITSELF to avoid recursing. So the cases
#                        policing preflight ran only after a push. That produced a
#                        local-green/CI-red three times -- the must-run declaration case, the
#                        session_currency wiring, and on 2026-09-01 the CI-only assertion
#                        case, on the very commit adding a matrix leg -- each documented at
#                        the site that hit it, none closing the hole. Documented at three
#                        sites and closed at none is not a known limitation.
#                        THE EXCLUSION WAS LOAD-BEARING AND THE FIRST FIX WAS A FORK BOMB.
#                        selftest() copies this file into a fixture and runs THE MAIN FLOW,
#                        so main -> selftest -> main is unbounded. The gate shipped with a
#                        comment asserting recursion was impossible and forked 207 processes
#                        before being killed by hand. SCAFFOLD_PREFLIGHT_INNER bounds it at
#                        depth 2, and it is EXPORTED AT THE --selftest DISPATCH, not only at
#                        the gate: CI enters through --selftest directly, where a
#                        gate-only marker is never set, so the laptop would have been fine
#                        and the runner would have hung.
#                        TWO CASES PIN IT, and both took three attempts. The marker case is
#                        live-state, not static. The guard case went: presence anywhere in
#                        the main flow (the dispatch's own export satisfied it), then
#                        adjacency within six lines (the COMMENT EXPLAINING THE GUARD
#                        satisfied it -- the identical defect ci_status.sh fixed the same
#                        day, re-created in another file), and finally adjacency with
#                        comments stripped. A regression here does not look like a red
#                        build; it looks like a runner that stops responding.
#   2026-08-30 v0.35.0.20260830.0600 — NEW GATE: tools/dependency_audit.sh, the one class an
#                        off-the-shelf scanner genuinely owns. Deliberately NOT wired through
#                        gate(), which has two outcomes where this has three -- clean, found,
#                        and DID NOT SCAN. rc 3 prints a GAP. Collapsing that into a pass is
#                        the ci_status defect verbatim: no alerts for months across three
#                        repositories where every alert feature was switched off.
#   2026-08-30 v0.34.2.20260830.0527 — FIX IN v0.34.1: the w15 temp cleanup used $_w15 outside the
#                        OUTER guard that assigns it, so in any repo taking that branch --
#                        i.e. every adoption -- `set -u` raised "unbound variable" and killed
#                        preflight six gates in. Green upstream, fatal downstream: the exact
#                        blast radius this file has been bitten by before. Now ${_w15:-}.
#                        Found by re-running the sweep IN localcoder rather than assuming a
#                        fix verified upstream travels.
#   2026-08-30 v0.34.1.20260830.0025 — SECURITY: the W-15 gate wrote to /tmp/.w15hits, a fixed path
#                        in a world-writable directory. A local user can pre-create it as a
#                        symlink and the `>` redirect truncates whatever it points at, with
#                        this process's privileges; it also collides between concurrent runs,
#                        and CI here is SELF-HOSTED, so /tmp persists between jobs and across
#                        repositories. Now mktemp with a template -- the idiom four other
#                        sites in this file already use. The mktemp is done BEFORE the
#                        if-chain and fails CLOSED: the first draft had it inside the elif,
#                        where a failed mktemp would have printed [PASS] for a check that
#                        never ran.
#   2026-08-30 v0.34.0.20260830.0005 — NEW GATE: the canonical hook set and the hooks we actually
#                        run must agree. setup.sh installs .claude/settings.hooks.json into
#                        every adopter; if it drifts from .claude/settings.json, adopters get
#                        a hook set this repository does not run -- which is what happened
#                        when the set lived in a setup.sh heredoc and decayed to 1 of 6
#                        commands with nothing comparing them. A FAILURE, not a gap: both
#                        files are ours and both are in the tree.
#   2026-08-26 v0.33.0 — provenance_check.sh wired as a non-blocking gate. It ships --check, and
#                        case 1b-vii fails a tool that ships --check with nothing calling it --
#                        caught in CI only, because this script excludes itself from its own
#                        discovery, which is the same local blind spot the session-currency
#                        wiring hit in 0.31.1.
#   2026-08-22 v0.32.0 — A FAILING ROW BURIED IN A LONG SUITE WAS DISCARDED (localcoder#182).
#                        Both failure paths printed `tail -25` of the suite output. For a
#                        173-case suite that is 25 PASS rows and the summary, while the one
#                        `| FAIL` line sits in the middle. Measured 2026-08-22: the localcoder
#                        audit failed inside preflight and passed standalone four times on the
#                        same tree, and the case name was unrecoverable -- so an intermittent
#                        failure, the kind you get one look at, left nothing to diagnose.
#                        salient_then_tail() keeps the lines that look like a diagnosis, IN
#                        EMISSION ORDER with line numbers, and then the tail. Same fix
#                        localcoder's mcp_client.py already carries for the same reason.
#                        Deliberately over-inclusive: a duplicated line costs nothing, a
#                        dropped one costs the diagnosis. Three selftest cases, one of them
#                        asserting the tail SURVIVES -- printing only the salient lines would
#                        trade one blind spot for another.
#   2026-08-19 v0.31.1 — the session-currency wiring was an `echo`, not a gate, and case
#                        1b-vii caught it: selftest-green, unused. Now a real gate() call
#                        with --check passed EXPLICITLY — relying on the default left the
#                        call invisible to the matcher, which is the same defect one level
#                        down. Non-blocking: --check exits 0 even when the record is behind.
#   2026-08-19 v0.31.0 — session currency reported beside the unreleased-commits warning. They
#                        are one question from two ends: that one says a fix nobody can install
#                        exists, this says a release nobody wrote down shipped. Every SESSION.md
#                        reference in this file was TEMPLATE detection and none asked whether it
#                        was CURRENT — so eleven tags shipped through 44 green gates here with
#                        the record a day stale. Advisory, like release_status.
#   2026-08-18 v0.30.0.20260819.0231 — reports whether the session hooks are wired to
#                        tools/session_hook.sh (P0-5). ADVISORY, not a gate: the upgrade
#                        does not touch a developer's client configuration, so this names
#                        the one-command remedy instead of failing on arrival.
#   2026-08-18 v0.26.0.20260818.1827 — A TOOL THAT SHIPS --check MUST BE CALLED IN THAT MODE,
#                        and status_block.sh is why. It shipped in 0.58.0 specifically so a
#                        stale status table would be a GATE RESULT rather than something a
#                        reader has to notice — and for three releases nothing invoked its
#                        --check. Selftest discovery picked the tool up, so it sat green on
#                        its own fixtures while the file it exists to police was never once
#                        compared. Present, tested, pointed at nothing: D-18's shape, in the
#                        cure for D-18's shape.
#                        Two changes, the instance and the class. run_all now gates the block
#                        when the target file declares one (silent when it does not; a GAP
#                        when the markers are there and the generator is not). New selftest
#                        case 1b-vii fails if any tool with a `--check` mode has no preflight
#                        call in that mode and no `scaffold:no-gate <reason>`.
#                        --selftest proves a tool WORKS; only a call in run_all proves it RUNS.
#   2026-08-18 v0.25.0.20260818.1156 — EVERY FAILING ASSERTION IN A WORKFLOW MUST ALSO RUN LOCALLY,
#                        or say why it cannot (P0-2, the class behind the instance). Each
#                        `::error::` now needs `scaffold:also-local <which check>` or
#                        `scaffold:ci-only <why>` within three lines above it. Naming WHICH
#                        is the point: "there is a counterpart somewhere" is the claim that
#                        rotted, and a named one can be followed and falsified. All five in
#                        scaffold-check.yml were verified by hand and annotated -- including
#                        the lost-+x case, which mode_scan.sh catches by reading the mode git
#                        RECORDS rather than the one on disk (core.fileMode=false hides it).
#                        Also: coverage_note for tools/scaffold_version.sh, which --coverage
#                        demanded the moment the workflow started invoking it.
#   2026-08-18 v0.24.0.20260818.0844 — a shipped workflow must not assume a FRESH MACHINE. Every
#                        workflow here was written against GitHub-hosted runners, where each
#                        job gets a new VM; self-hosted runners persist their workspace and
#                        home directory, and the difference is silent until a one-shot step
#                        runs twice. `git remote add mirror` -> `error: remote mirror already
#                        exists`, exit 3, five seconds, on every run after the first. The
#                        mirror had not moved in 36 releases and the reason had silently
#                        changed from a billing block to this, because both present as a red
#                        X on a step no one reads. Looks for the SHAPE, so the next one-shot
#                        operation is caught too; an append guarded by an existence test is
#                        correct and is not flagged.
#   2026-08-18 v0.23.0.20260818.0753 — the archive verdict must be read from an EXIT CODE, not
#                        grepped out of prose. Asserts setup.sh asks session_archive.py for
#                        --exit-status and no longer branches on matching its report, so the
#                        blind spot cannot return by anyone matching one more token.
#   2026-08-18 v0.22.0.20260818.0653 — inside an adoption FIXTURE, the adopter's must-run gates
#                        are skipped and NAMED (#227). adoption_check runs a full inner
#                        preflight in each of two fixtures; in an adopter that declares a
#                        must-run gate that inner preflight was also running the ADOPTER'S
#                        OWN SUITE, and the same suite then ran a third time as the job's own
#                        audit step. Three runs of one suite per push, two of them proving
#                        nothing the third did not.
#                        MEASURED: localcoder's adoption_check 131s -> 66s, which is now the
#                        same as this repo's 62s -- the entire difference between the two was
#                        the declared gate. On the self-hosted M3 the localcoder job had been
#                        CANCELLED at a 5-minute ceiling and then again at 12.
#                        IT IS ALSO THE RIGHT SCOPE, which matters more than the minutes: a
#                        check named "do the SCAFFOLD's gates work in an adoption" should not
#                        fail because the adopter's product test failed. Skipping it makes the
#                        check answer its own question.
#                        NAMED, NEVER SILENT -- the verdict prints the skipped set and why,
#                        because a gate that stops running is what this file exists to catch.
#   2026-08-18 v0.21.0.20260818.0418 — an exception to selftest discovery is now CHECKED (#237).
#                        scaffold-check.yml skips adoption_check.sh in the discovery sweep
#                        because an explicit step already runs it: in that tool `--selftest`
#                        and bare are the same function, so CI ran one identical ~160s twice
#                        and was cancelled at its own 5-minute ceiling BEFORE eleven later
#                        steps -- header checks, required files, the scanners, the localcoder
#                        audit -- ran at all. Reported from the godsfall adoption at 162s+161s.
#                        THE SKIP IS THE INVERSE OF WHAT DISCOVERY EXISTS TO CATCH: not a
#                        suite nobody runs, a suite that runs twice. But delete that explicit
#                        step and the skip silently retires the suite -- the original defect,
#                        reintroduced one level up by its own exception. So it is checked,
#                        not trusted: every basename in SELFTEST_SKIP must appear as an
#                        explicit invocation elsewhere in the same workflow. Fixtures assert
#                        both directions, and the real tree was mutation-verified by deleting
#                        the step (27 passed / 1 failed, naming adoption_check.sh).
#   2026-08-16 v0.20.0.20260816.1916 — the vendored scaffold's freshness is now a GATE.
#                        tools/scaffold_version.sh exits 1 on "behind" and preflight called
#                        it only via --selftest: the check was verified and never run.
#                        Fails at two or more releases behind, reports at one, exit 3 when
#                        upstream is unreachable -- offline must not read as current.
#   2026-08-15 v0.19.1.20260815.0500 — A FAILING MUST-RUN GATE NO LONGER PRINTS UNDER A PASSED LINE. D-18's
#                        shape a THIRD time, one layer deeper than v0.16.0's fix and found the
#                        same way — by a release going out wrong. That fix added the must_gate
#                        CALL and placed it after the only `if [ -n "$FAILED" ]` branch, so from
#                        then until now a declared must-run gate could run, print [FAIL], set
#                        $FAILED, and be followed by PREFLIGHT PASSED. Same trigger as last
#                        time: version-files-agree, `version` 0.39.0 against pyproject 0.38.0.
#                        The tag was cut and published on that PASSED, and it installs under the
#                        old version string. $FAILED is now consulted again after the block.
#   2026-08-15 v0.19.0.20260815.0200 — Report whether a RELEASE is due, advisory and never a failure. A repo
#                        is pushed many times per release, and failing a push for that would
#                        train people to bypass this gate — which is how the prose checklist
#                        in ai/PLANNING.md stopped being read. Measured when someone finally
#                        asked: 9 unreleased product commits here, 26 in Robiton/localcoder.
#   2026-08-13 v0.18.0 — LIVENESS. A SILENT GATE AND A HUNG GATE LOOKED IDENTICAL.
#                        `gate()` captured its command in a command substitution, so nothing
#                        reached the terminal until it finished — fine at one second,
#                        indefensible at the 1,964s `tests/audit_localcoder.sh` measured on
#                        this machine (18s with --offline; eight cases do live model drafts).
#                        For thirty-three minutes preflight printed NOTHING, and three pushes
#                        were killed by people assuming it had wedged. A developer who cannot
#                        tell working from wedged kills it, and a gate that gets killed is a
#                        gate that does not run — this project's central defect arriving
#                        through the user interface instead of the code.
#                        Prints `[..] <label> — still running, 12m04s elapsed` after 20s, then
#                        every 15s on a TTY and every 60s when redirected: enough to prove
#                        liveness in a CI log without burying the verdict.
#                        run_selftests waits out loud too, naming what is RUNNING versus what
#                        is QUEUED behind the throttle — reporting a queued suite as running
#                        would be a lie in the one message whose job is telling the truth
#                        about what is happening.
#   2026-08-12 v0.17.0 — The is_upstream_repo drift pin now greps the WHOLE TRACKED TREE.
#                        Added in 0.36.6 after the drift was found in scaffold-check.yml, it
#                        checked scaffold-check.yml AND NOTHING ELSE — so it never saw
#                        setup.sh, which carried the same drift and was strictly worse. A pin
#                        scoped to the file where a defect was FOUND is scoped to the wrong
#                        thing; same mistake as sweeping *.md for W-15's stale paths.
#   2026-08-12 v0.16.0 — THE MUST-RUN DECLARATION WAS DECORATIVE. MUST_RUN was parsed from
#                        AGENTS.md and NAMED in the verdict under the words "all of which
#                        ran" — printed inside the PASSED branch, so the sentence appeared
#                        precisely when nothing had checked. must_gate() was defined,
#                        documented and covered by three selftest cases, and called from
#                        NOWHERE but those cases.
#                        Measured in Robiton/localcoder: tests/audit_localcoder.sh was
#                        declared must-run and FAILING (pyproject 0.21.0 vs version 0.22.0,
#                        so an install reported the wrong release). preflight printed "all of
#                        which ran" and PASSED; CI caught it after the push, which is the one
#                        thing this script exists to prevent.
#                        D-18's shape inside the mechanism built for D-18. The three cases
#                        were not wrong — they proved must_gate BEHAVES when called. Nothing
#                        proved it IS called, because reachability is not a property a unit
#                        test of the function can have. A case now greps the main flow for
#                        the call, which is the only place that answer lives.
#   2026-08-12 v0.15.1 — A DIRECTORY IS EXECUTABLE. The workflow's second discovery loop
#                        tested `[ -x ]` only, so src/localcoder/__pycache__ passed it and
#                        grep wrote "Is a directory" to stderr on every run. Invisible while
#                        discovery walked only tools/, which has no subdirectories; the very
#                        first product-dir run surfaced it. selftest_tools() here always had
#                        the test — so "the two copies agree" now checks for it, 3 -> 4
#                        signals. A pin that does not cover the thing that drifted is not a
#                        pin, and this drifted within a day of the pin being written.
#   2026-08-12 v0.15.0 — 25 -> 26 gates: tools/stale_path_scan.sh is discovered by the
#                        *_scan.sh convention, so it needed no registration in either CI or
#                        here. The added gate is its selftest. Also: the setup.sh --check
#                        label still promised "localcoder sync", retired in W-15 — surfaced
#                        by the gate's own failure output, which is the machinery working.
#   2026-08-12 v0.14.1 — Two stale W-15 references, both found by a scanner rather than by
#                        reading: the coverage map still carried notes for
#                        tools/audit_localcoder.sh and tools/localcoder_sync.py, and --list
#                        PRINTED "4. tools/audit_localcoder.sh --offline" as a step to run.
#                        An instruction to run a file that is not there.
#   2026-08-12 v0.14.0 — `scaffold:product-dir` — selftest discovery is no longer hardcoded to
#                        tools/. 24 -> 25 gates; the one added is "product dir" (DEC-18 — name
#                        the delta). Robiton/localcoder ships at src/localcoder/ and tools/
#                        there is the vendored governance layer, so scanning tools/ alone left
#                        that repo's own shipped executables as the one thing CI never
#                        selftested. It had been fixing that by EDITING scaffold-check.yml,
#                        which made a PRODUCT file divergent: every upgrade left a sidecar to
#                        reconcile, and three were found tracked since 2026-08-09.
#                        A DECLARED DIR THAT DOES NOT EXIST FAILS. Silently falling back to
#                        tools/ is how a renamed product directory retires a suite with nothing
#                        to notice — D-18, and why scaffold:must-run behaves the same way.
#                        TWO IMPLEMENTATIONS, PINNED. CI's discovery must not depend on the
#                        tool it is discovering, so the workflow has its own copy; --selftest
#                        checks it for the same marker, base and missing-dir treatment. The
#                        is_upstream_repo copies drifted for months and were correct only by
#                        accident; an unpinned duplicate is the defect, not the duplicate.
#   2026-08-12 v0.13.0 — --selftest now pins the WORKFLOW's copies of is_upstream_repo, not
#                        just the two shell ones. The AGENTS.md placeholder step used
#                        `setup.sh` as its third signal — the one file EVERY adopter has, so
#                        strictly weaker than the rule — and never misfired, because no
#                        adopter carries overlays/ either. Correct by accident is how a
#                        drifted duplicate survives, and 1b only ever looked at the shell.
#   2026-08-12 v0.12.0 — NEW GATE: shipped workflows must pin actions at or above a declared
#                        floor. 23 -> 24 gates; the one added is "shipped action floor"
#                        (DEC-18 — name the delta, never just observe a bigger number).
#                        scaffold-check.yml is a PRODUCT_FILE, so its pins run in every
#                        adopting repository: `actions/checkout@v4` put a node20 deprecation
#                        annotation on every run of every adopter, permanently, and one they
#                        could not act on because we chose the pin. That is A10's shape with
#                        a different owner, reported from the godsfall adoption on the day it
#                        first reached zero annotations. A FLOOR, NOT "IS IT LATEST": latest
#                        needs the network and would degrade to a silent pass offline.
#   2026-08-12 v0.11.0 — coverage_note for tools/adoption_check.sh, which CI now invokes. The
#                        coverage gate caught this the moment the workflow step landed,
#                        which is the machinery working: a tool CI runs and this script
#                        does not know about is exactly what it exists to find.
#   2026-08-11 v0.10.0 — THE NO-LOCALCODER-EXECUTION RULE IS SCAFFOLD-ONLY NOW. DEC-20 says
#                        THE SCAFFOLD does not invoke localcoder; an ADOPTER invoking it is
#                        the product working as designed. A pre-write hook, a best-of-N
#                        wrapper and an attribution wrapper all must call the binary, and
#                        this gate told adopters they may not use the thing they installed.
#                        Worse, it fired on the leftovers THE SPLIT ITSELF CREATED: 0.36.x
#                        stops shipping tools/localcoder and friends but deliberately does
#                        not delete them, so the upgrade left the files in place AND added
#                        a gate that failed on them. An upgrade that cannot pass its own
#                        gate immediately after running is the defect.
#                        The matcher was also mention-based: help text, docstrings and
#                        message f-strings counted as invocations. Those are excluded now,
#                        though scoping matters more — upstream has no wrappers, so this
#                        gate is green in every repo we test in and could only ever be seen
#                        from a real adoption.
#                        Reported from the first real 0.36.2 adoption, along with the
#                        context-survival gate failing there for the same reason: a check
#                        about the scaffold's own repository, enforced on everyone.
#   2026-08-11 v0.9.0 — THE LOCALCODER CONTEXT BUDGET IS HARD UPSTREAM AND ADVISORY IN AN
#                        ADOPTION, because 28 IS THIS REPOSITORY'S NUMBER. W-10 set it as a
#                        ratchet at a level this repo had already reached, which makes a
#                        failure here a real result — prose came back. It is not a fact
#                        about anyone else.
#                        An adoption that leans on the local model SHOULD carry more policy
#                        than the scaffold does. Measured on the one that reported this:
#                        localcoder drafted 16.1% of landed code at a 0% correction rate,
#                        off exactly the role-split table and delegation policy this gate
#                        would have told them to delete. Enforcing it downstream inverts
#                        the tool — red on arrival, demanding removal of the thing that was
#                        working — and ai/SECURITY.md's rule is that such a guard gets
#                        ripped out and then protects nothing.
#                        Caught before it reached anyone only because a real 0.36.0 adopter
#                        read the release BEFORE upgrading. The gate is green in every repo
#                        we test in, so nothing here could have found it.
#                        is_upstream_repo's three signals are INLINED rather than sourced —
#                        tools/scaffold_version.sh runs its main flow at top level — and
#                        the duplication is PINNED by a new selftest case asserting the two
#                        definitions still agree. Two copies of one rule is this project's
#                        most repeated defect; if either drifts, an adopter silently gets
#                        the wrong severity.
#   2026-08-11 v0.5.0 — GATES DECLARE MUST-RUN OR MAY-SKIP, PER REPOSITORY (D19, W-22
#                        part three). Every `if [ -x tool ]` guard here falls through to a
#                        gap, and a gap prints above a PASSED line and exits 0. Right for
#                        anything environmental; wrong for the repository's own test suite.
#                        D-18 is the case: forty behavioural cases that had never run in
#                        CI, discovered where they were not, gapped, green for months.
#                        The declaration lives in AGENTS.md, at column 0, because THIS FILE
#                        IS VENDORED and force-installed — a list here would be wrong in one
#                        of the two places by construction and overwritten in the adopter.
#                        Same argument as the divergence markers needing both sides.
#                        NOT AN EXPECTED GATE COUNT, and that was argued rather than
#                        assumed: a count is one number standing in for a set, so two gates
#                        can vanish while one appears and the total is unchanged; every
#                        legitimate environment difference forces a re-baseline nobody
#                        reads; and keyed on a fingerprint it mints a fresh baseline
#                        whenever the fingerprint moves, ending up always correct and never
#                        informative.
#                        NOT-INSTALLED AND NOT-EXECUTABLE NOW PRINT DIFFERENTLY. `[ -x ]`
#                        is false for both, so a lost +x bit and a missing file were
#                        indistinguishable — and the lost bit is likelier and more
#                        confusing, because the file is right there. Measured twice in one
#                        week in this repo: a git apply --reject dropped the +x from
#                        audit_localcoder.sh and preflight ran 24 gates instead of 26 and
#                        still printed PASSED; and localcoder_footprint.py was committed
#                        with git recording 644 despite the on-disk +x. Neither mechanism
#                        subsumes the other — this one catches both of those instantly and
#                        would NOT have caught D-18, where the file is genuinely absent.
#                        The verdict now NAMES the must-run set rather than counting it
#                        (D18): "18 gates, and I could not say which eighteen" is the
#                        sentence that found D-18 after three rounds of reading the gap as
#                        noise.
#   2026-08-10 v0.4.0 — FIND THE ADOPTER'S TEST SUITE, NOT JUST OUR OWN (#D-18). This
#                        script is vendored into every adopting project and searched only
#                        tools/ for the localcoder audit. Robiton/localcoder keeps its
#                        suite in tests/ — correctly, because tools/ there is this
#                        governance layer and its AGENTS.md says the product is src/, ops/,
#                        tests/, templates/. The paths had never matched, the gap printed
#                        above a PASSED line, and that repository had never run its own
#                        40-case suite in CI. A gap is not a failure by design and that
#                        design is right; the defect was that nothing could say which
#                        gates were supposed to have run. See D19 and W-22 part three.
#   2026-08-10 v0.3.0 — EXIT 3 IS A SKIP, NOT A FAILURE AND NOT A PASS (#188). An
#                        adopter's parse checker shelled out to a godot that was not
#                        installed: 'command not found' contains no 'Parse Error', so it
#                        announced '7 file(s) parse cleanly' and three CI runs went green
#                        on zero work. The gate gave its strongest verdict at the moment it
#                        could give none.
#                        gate() now renders 3 as [SKIP] — NOT verified, feeding the GAP
#                        machinery that already existed for this idea on the coverage side.
#                        It does not set the failure flag: a developer without the
#                        toolchain can still push and cannot mistake a skip for a pass.
#                        The bespoke lint_python branch is GONE — it hand-rolled this split
#                        for one tool on its exit 2, and keeping it would be a second
#                        definition of the rule, free to disagree with gate().
#                        The new case asserts all three outcomes at once and fails both
#                        ways a skip can be miscounted: folded into pass (the reported bug)
#                        and folded into fail (which trains people to ignore red).
#   2026-08-09 v0.2.0 — Knows about tools/mode_scan.sh, and needs to: this script's FIRST
#                        pull request landed two new tools at mode 644, their selftests did
#                        not run, and preflight reported both suites passing. It ran them off
#                        the FILESYSTEM mode while git records its own — and with
#                        core.fileMode false, which is correct on a filesystem that reports
#                        0700 for everything, those two numbers disagree by design. The gap
#                        was one this file already NAMED as not covered, which is the least
#                        bad way to be wrong but is still wrong.
#   2026-08-09 v0.1.0 — New (#166). The scaffold shipped several local gates and NO single
#                        command that ran them, so every adopter reconstructed CI's list from
#                        memory and each omitted a different check. Measured on this repo's
#                        own owner, 2026-08-09: two red builds in three minutes, on the
#                        commits that were adding a rule about checking CI. The first was a
#                        stale header; the second was the localcoder drift check, which had
#                        never been run once locally.
#
#                        THE SECOND FAILURE IS THE DESIGN INPUT, NOT THE FIRST. CI stops at
#                        its first failing step, so a red build teaches you about exactly one
#                        gate and hides the next one behind it — fix, push, wait, discover the
#                        next. This runs EVERY gate and reports all of them, so one round trip
#                        replaces N.
#
#                        IT DELEGATES AND DOES NOT REIMPLEMENT. `setup.sh --check` already
#                        runs the scanners, header_check, localcoder_sync and the archive
#                        report; re-running those rules from a second file is how #96 reached
#                        one copy and not the other, twice. What was missing is that nothing
#                        ran the three checks setup.sh --check explicitly NAMES as not
#                        covered, and nothing ran header_check in CI's stricter form.
#
#                        A DIRTY TREE IS A PRECONDITION FAILURE, NOT A WARNING (exit 3).
#                        `header_check --since` reads the COMMITTED diff, so running it with
#                        the change still in the working tree reports clean and proves
#                        nothing — the exact trap that produced two invalid test setups
#                        before a real reproduction. A warning is what gets skimmed past on
#                        the way to a push, so this refuses and says why; --allow-dirty is
#                        one flag away for the case where the dirt is unrelated.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 2

ALLOW_DIRTY=0
ALLOW_CI_UNRESOLVED=0
SERIAL=0
SINCE=""
MODE="run"
VERBOSE=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --allow-dirty) ALLOW_DIRTY=1; shift ;;
    --ci-unresolved-ok) ALLOW_CI_UNRESOLVED=1; shift ;;
    --serial)      SERIAL=1; shift ;;
    --verbose)     VERBOSE=1; shift ;;
    --since)       SINCE="${2:-}"; [ -n "$SINCE" ] || { echo "preflight: --since needs a ref" >&2; exit 2; }; shift 2 ;;
    --coverage)    MODE="coverage"; shift ;;
    --list)        MODE="list"; shift ;;
    # EXPORTED HERE, NOT ONLY AT THE GATE, AND THIS IS THE HALF THAT MATTERS IN CI.
    # The gate below runs `--selftest` with SCAFFOLD_PREFLIGHT_INNER=1 so the fixture runs
    # it spawns skip that gate. But CI does not enter through the main flow -- its
    # discovery loop invokes `tools/preflight.sh --selftest` DIRECTLY, with nothing set. The
    # fixtures would then run the main flow with the marker absent, hit the gate, and
    # recurse on the runner rather than on a laptop. Setting it at the entry point states
    # the real invariant: a preflight spawned from a selftest never runs the selftest gate,
    # whichever door the selftest came in by.
    --selftest)    MODE="selftest"; export SCAFFOLD_PREFLIGHT_INNER=1; shift ;;
    -h|--help)     MODE="help"; shift ;;
    *)             echo "preflight: unknown argument '$1'" >&2; MODE="help"; shift ;;
  esac
done

# QUIET BY DEFAULT (CONTROL, 2026-09-23). A green run printed 58 [PASS] lines around the
# five that needed reading. Passes are counted and hidden; every SKIP, GAP, FAIL and note
# prints exactly as before. SCAFFOLD_VERBOSE=1 is the same switch for sync-check.sh and
# session_hook.sh. No CI special case: one output shape everywhere, so no gate reads
# differently on a runner than it does here.
[ -n "${SCAFFOLD_VERBOSE:-}" ] && VERBOSE=1
export VERBOSE

WORKFLOW=".github/workflows/scaffold-check.yml"

# ---------------------------------------------------------------- what runs, and how
#
# THE MAP IS CHECKED AGAINST REALITY BY --coverage. A list of gates in a third file is a third
# thing to keep in step, and this repo's recurring failure is a rule stated in one place and
# implemented in another. So: --coverage reads the workflow, finds every tool CI invokes, and
# fails if one is not named here; and the selftest asserts every entry here really is
# invoked, either by this file or by the file it delegates to.
#
# THAT WAS ONE DIRECTION, AND THIS COMMENT USED TO SAY "BOTH". Both halves above ask whether
# LOCAL covers CI. Neither asked whether CI covers local, so a gate that ran only here was
# invisible by construction. dependency_audit was one: COLLECTO's PR #91 went CI-green while
# local preflight reported uuid 7.0.3. local_only_note() below is the other direction.
coverage_note() {
  case "$1" in
    tools/adoption_check.sh)   echo "run here, via the tool-selftest discovery" ;;
    # ADDED WHEN THE WORKFLOW STOPPED REIMPLEMENTING THE VERSION INVARIANT AND STARTED
    # CALLING IT (P0-2). --coverage caught this immediately: CI invoked a tool this map did
    # not list, which is exactly the drift the map exists to refuse.
    tools/scaffold_version.sh) echo "run here, and via setup.sh --check (--assert-consistent)" ;;
    tools/header_check.sh)     echo "run here, bare AND in CI's --since form" ;;
    tools/lint_python.sh)      echo "run here" ;;
    tools/shell_lint.sh)       echo "run here" ;;
    tools/workflow_audit.sh)   echo "run here (exit 3 without zizmor or actionlint, which is not a pass)" ;;
    tools/dependency_audit.sh) echo "run here (exit 3 with nothing declared or no osv-scanner, which is not a pass)" ;;
    # CI-ONLY BY CONSTRUCTION, not by omission. It answers "did ANY leg of the fan-out
    # audit this?", and one machine is not a fan-out. Its --selftest runs here via the
    # tool-selftest discovery, which is what this map is asserting about.
    tools/audit_coverage.sh)   echo "selftest runs here; the check itself is CI-only (a fan-out has no local equivalent)" ;;
    tools/session_archive.py)  echo "via setup.sh --check (advisory, never fails a push)" ;;
    tools/secret_scan.sh)      echo "via setup.sh --check (tools/*_scan.sh discovery)" ;;
    tools/conflict_scan.sh)    echo "via setup.sh --check (tools/*_scan.sh discovery)" ;;
    tools/mode_scan.sh)        echo "via setup.sh --check (tools/*_scan.sh discovery)" ;;
    tools/scaffold_log.sh)     echo "not a gate — it records what each gate said" ;;
    *)                         echo "" ;;
  esac
}

# Where each mapped tool must actually appear, so the note above cannot be a claim nobody
# checked. "run here" must be visible in this file; "via setup.sh --check" in setup.sh.
coverage_evidence() {
  case "$(coverage_note "$1")" in
    "run here"*)          echo "tools/preflight.sh" ;;
    "via setup.sh"*)      echo "setup.sh" ;;
    *)                    echo "" ;;
  esac
}

# THE OTHER DIRECTION: every tool THIS FILE runs that CI does not, and why. Returns
# "<kind>|<reason>". Kinds:
#   discovery   CI runs it through a glob, not by name. Checked: the glob must be in CI.
#   not-a-gate  a library or a recorder; there is no verdict to cover.
#   local       answerable only here, with the reason.
#   known-gap   a real gate CI does not run yet. Printed as a GAP on every run until it moves.
# A tool with no entry FAILS --coverage. That is the case that let dependency_audit sit
# local-only unnoticed.
local_only_note() {
  case "$1" in
    tools/*_scan.sh)              echo "discovery|CI's tree-scanner step runs every tools/*_scan.sh" ;;
    tools/fixture_guard.sh)       echo "not-a-gate|the library fixtures source; its --selftest runs in CI's tool-selftest step" ;;
    tools/scaffold_log.sh)        echo "not-a-gate|it records what each gate said" ;;
    tools/ci_status.sh)           echo "local|it asks the remote whether CI is green; CI asking itself is circular" ;;
    tools/session_hook.sh)        echo "local|it checks the session-hook wiring that Claude Code on this machine runs" ;;
    tools/release_status.sh)      echo "local|an advisory list of unreleased work, never a verdict" ;;
    tools/adoption_manifest.sh)   echo "known-gap|the four adoption manifests agree" ;;
    tools/changelog.sh)           echo "known-gap|CHANGELOG.md matches the tags" ;;
    tools/context_survival.sh)    echo "known-gap|an adopter's content survives setup and upgrade" ;;
    tools/doc_currency.py)        echo "known-gap|documents have not fallen behind their sources" ;;
    tools/localcoder_footprint.py) echo "known-gap|the localcoder context budget" ;;
    tools/provenance_check.sh)    echo "known-gap|borrowed sources have not moved" ;;
    tools/python_floor.py)        echo "known-gap|every file parses at the declared requires-python" ;;
    tools/sbom.py)                echo "known-gap|the SBOM dependency claim, where a project ships one" ;;  # scaffold:path-not-an-instruction (an adopter's tool; the map must name it)
    tools/session_currency.sh)    echo "known-gap|a release has a session entry behind it" ;;
    tools/status_block.sh)        echo "known-gap|the derived status block is current" ;;
    *)                            echo "" ;;
  esac
}

# Every tools/… path THIS FILE invokes, outside the selftest. Comment lines are stripped, and
# so are the `case` labels of the two maps -- naming a tool in a map is not running it.
# NOT filtered to files on disk: preflight runs some tools only where an adopter has them
# (tools/sbom.py), and a filter made that gap invisible here and red there.
local_tools() {
  local src="${PREFLIGHT_SRC:-tools/preflight.sh}"
  [ -f "$src" ] || return 0
  sed -n '1,/^selftest() {/p' "$src" \
    | grep -v '^[[:space:]]*#' \
    | grep -vE '^[[:space:]]*tools/[A-Za-z0-9_.*-]+\)' \
    | grep -oE 'tools/[A-Za-z0-9_.-]+\.(sh|py)' \
    | sort -u \
    | while read -r t; do [ "$t" != "tools/preflight.sh" ] && echo "$t"; done
}

# Every tools/… path CI actually invokes. COMMENT LINES ARE STRIPPED FIRST: this workflow
# carries long rationale comments that name tools by path — including tools an adopter owns
# and tools that were deleted — and counting those would demand coverage of things CI never
# runs. A path that does not resolve to a file is a glob or an example, not an invocation.
ci_tools() {
  [ -f "$WORKFLOW" ] || return 0
  grep -v '^[[:space:]]*#' "$WORKFLOW" \
    | grep -oE 'tools/[A-Za-z0-9_.-]+' \
    | sort -u \
    | while read -r t; do [ -f "$t" ] && echo "$t"; done
}

coverage() {
  local bad=0 t note ev
  echo "preflight --coverage — does this run what CI runs?"
  echo ""
  # NO WORKFLOW IS "COULD NOT ASK", NOT "NOTHING TO ANSWER FOR" (exit 3). ci_tools() prints
  # nothing both when CI invokes no tools and when there is no CI file to read, and the loop
  # below cannot tell those apart — it would print "every tool CI invokes has a local path"
  # over a repo whose workflow it never found. That is the false all-clear this whole
  # toolchain keeps finding in itself, and it would arrive first in exactly the repos that
  # vendor these tools without vendoring the workflow.
  if [ ! -f "$WORKFLOW" ]; then
    echo "  [GAP]  no $WORKFLOW here — coverage was NOT verified."
    echo "         This says nothing about whether preflight matches your CI. Point it at"
    echo "         the right file, or accept that the comparison did not happen."
    return 3
  fi
  for t in $(ci_tools); do
    note="$(coverage_note "$t")"
    if [ -z "$note" ]; then
      echo "  [GAP]  $t is invoked by CI and is not covered by preflight."
      echo "         Add it to coverage_note() in tools/preflight.sh — with a reason if it"
      echo "         deliberately stays CI-only."
      bad=1
    else
      echo "  [ok]   $t — $note"
    fi
  done
  echo ""
  if [ "$bad" -eq 0 ]; then
    echo "  Every tool CI invokes has a local path through this script."
  fi

  # THE OTHER DIRECTION: does CI run what this runs?
  echo ""
  echo "preflight --coverage — does CI run what this runs?"
  echo ""
  local ci_list kind reason known=0 back=0
  if [ ! -f "${PREFLIGHT_SRC:-tools/preflight.sh}" ]; then
    echo "  [GAP]  no ${PREFLIGHT_SRC:-tools/preflight.sh} to read — this direction was NOT verified."
    [ "$bad" -eq 0 ] && return 3
    return "$bad"
  fi
  ci_list="$(ci_tools)"
  for t in $(local_tools); do
    printf '%s\n' "$ci_list" | grep -qxF "$t" && continue
    note="$(local_only_note "$t")"
    kind="${note%%|*}"; reason="${note#*|}"
    case "$kind" in
      discovery)
        if grep -v '^[[:space:]]*#' "$WORKFLOW" | grep -qF 'tools/*_scan.sh'; then
          echo "  [ok]   $t — $reason"
        else
          echo "  [GAP]  $t — mapped as run by CI's tools/*_scan.sh discovery, and CI has no such step."
          bad=1; back=1
        fi ;;
      not-a-gate|local)
        echo "  [ok]   $t — $kind: $reason" ;;
      known-gap)
        echo "  [GAP]  $t — NOT run in CI ($reason). Declared, so advisory; it still only runs where someone runs preflight."
        known=$((known+1)) ;;
      *)
        echo "  [GAP]  $t is run by preflight and by nothing in CI."
        echo "         Add a CI step for it, or an entry in local_only_note() in tools/preflight.sh"
        echo "         saying why it stays local. A gate only one machine runs is invisible to CI."
        bad=1; back=1 ;;
    esac
  done
  echo ""
  if [ "$back" -eq 0 ]; then
    echo "  Every local gate is in CI, or declared local with a reason ($known declared known gap(s))."
  fi
  # THE INLINE STEPS ARE NAMED, NOT SILENTLY OMITTED. Several CI steps are shell in a `run:`
  # block with no tool behind them; reimplementing them here would create the second copy
  # this file exists to avoid, and pretending they are covered would be worse than both.
  echo ""
  echo "  CI steps with no tool behind them, so not reachable from here:"
  echo "    - required ai/ files exist        - AGENTS.md placeholders"
  echo "    - version / .scaffold-version     - SESSION.md and BACKLOG.md templates"
  echo "  Extracting them into tools/*_scan.sh brings them in for free — the discovery"
  echo "  already exists. tracked file modes was the first to move, on the PR where it"
  echo "  failed CI for the third time: two new tools landed at 644 and their selftests"
  echo "  did not run, while this script reported both suites passing off the DISK mode."
  return "$bad"
}

# ---------------------------------------------------------------- the gates
FAILED=""
PASSED=0
GAPS=""

# ---- ARE WE THE UPSTREAM SCAFFOLD, OR AN ADOPTER? (#315)
#
# Three signals together, because none alone is decisive: `setup.sh --type` strips overlays/
# and OVERVIEW.md, and mirror-sync.yml is ours alone. An adopter has none of the three.
#
# THIS WAS OPEN-CODED EIGHT TIMES IN THIS FILE, while tools/mode_scan.sh had already
# extracted the identical test as is_upstream() and tools/context_survival.sh as
# scaffold_clone() -- the latter noting it had "fixed one call site at a time twice now".
# The failure mode of the copies is SILENCE, not a wrong answer: change the signature and
# each stale copy stops matching, so the gate it guards never runs again and NOTHING goes
# red. A gate that stopped running is indistinguishable from a gate with nothing to report.
# That is the AGENTS.md ten-copy defect, where the one straggler still tested setup.sh --
# which every adopter has by definition -- and printed [OK] at a real project with a real
# unfilled command. The name matches mode_scan.sh's rather than inventing a third spelling.
#
# RELATIVE PATHS, DELIBERATELY. Every caller runs with the repo root as cwd, and the
# extracted shipped-ai-kind fixture runs this same test from inside a throwaway tree that is
# NOT this repository. Anchoring to $ROOT would quietly break that fixture.
is_upstream() {
  [ -d overlays ] && [ -f OVERVIEW.md ] && [ -f .github/workflows/mirror-sync.yml ]
}

log_verdict() {
  # The selftest drives gate() with fake gates; their verdicts are not this repo's and must
  # not reach the run log. They did, 734 times each, so the log held ~2,200 invented FAIL,
  # skip and pass rows (research-spike audit, 2026-10-05).
  [ "${PREFLIGHT_NO_LOG:-0}" = "1" ] && return 0
  [ -x tools/scaffold_log.sh ] && tools/scaffold_log.sh --log "preflight:$1" "$2" "${3:-}" >/dev/null 2>&1
  return 0
}

# ==== WHICH COMMIT WAS THE VERDICT ABOUT? ================================================
#
# The run log recorded `preflight:preflight  ok  46 gate(s)` and nothing about WHAT was
# gated, so a pass from an hour and four commits ago is indistinguishable from the one you
# just ran. That gap is why `.githooks/pre-push` had to re-run the whole 173s gate to learn
# something this script already knew a second earlier -- and a hook that costs three minutes
# per push is a hook people uninstall, or route around with --no-verify until the flag is
# reflex. Reported by an adopter who typed `preflight ; push` with a SEMICOLON: the gate ran,
# failed, and the push went anyway, because a semicolon makes a gate advisory.
#
# Binding the verdict to a sha is what makes the hook cheap enough to leave installed, and a
# guard that stays installed is the only kind that prevents anything.
#
# HEAD, NOT THE WORKING TREE, and that is the right anchor: preflight refuses outright on a
# dirty tree (exit 3), so a pass always describes a committed state. Amend the commit and the
# sha changes, which correctly invalidates the receipt.
# A DIRTY RUN IS NOT A VERDICT ABOUT HEAD. --allow-dirty gates the working tree, and the
# pre-push hook accepts `ok sha=<HEAD> ` as a receipt for HEAD -- so a dirty pass used to
# let HEAD's never-gated bytes through the hook. The +dirty suffix keeps the row honest and
# makes the hook's `sha=<HEAD> ` prefix match fail, which is the point.
PREFLIGHT_DIRTY=0
preflight_head_sha() {
  local h
  h="$(git rev-parse HEAD 2>/dev/null || echo "")"
  if [ -n "$h" ] && [ "$PREFLIGHT_DIRTY" -eq 1 ]; then h="$h+dirty"; fi
  printf '%s\n' "$h"
}

# Actions pinned in the workflows THIS PROJECT SHIPS, and the lowest major each may use.
# Declared, never derived: "is it the latest" needs the network, and a check that degrades to
# a silent pass when offline is this repository's most-repeated defect. A floor goes stale on
# purpose — raising it is a decision someone makes and writes down.
ACTION_FLOORS="actions/checkout:5"
# scaffold-check.yml is a PRODUCT_FILE — it lands in every adopting repository. mirror-sync
# is upstream-only but travels to the org mirror, so both are pins we own and nobody else
# can change. An adopter's OTHER workflows are deliberately not here: failing their push over
# a pin we did not choose is the inversion the context-budget gate was fixed for.
SHIPPED_WORKFLOWS=".github/workflows/scaffold-check.yml .github/workflows/mirror-sync.yml"

# Echo one line per pin below its floor: `<file>:<lineno>=<action>@v<major>`. Silence = clean.
# A FUNCTION, NOT INLINE, so selftest() can `declare -f` it and inject cases — a gate that
# has only ever been seen passing is a gate nobody should believe.
stale_action_pins() {
  local wf spec act min hits line maj
  for wf in $SHIPPED_WORKFLOWS; do
    [ -f "$wf" ] || continue
    for spec in $ACTION_FLOORS; do
      act="${spec%:*}"; min="${spec##*:}"
      # `uses:` LINES ONLY. scaffold-check.yml's own comments quote `actions/checkout@v4`
      # while explaining why it is wrong, so a matcher that read comments would fail on the
      # documentation of its own rule. That is precisely the defect the W-15 matcher shipped
      # with — help text and docstrings counted as invocations — found in an adoption, twice.
      hits="$(grep -nE "^[[:space:]]*(-[[:space:]]+)?uses:[[:space:]]*${act}@v[0-9]" "$wf" 2>/dev/null || true)"
      [ -n "$hits" ] || continue
      while IFS= read -r line; do
        [ -n "$line" ] || continue
        maj="$(printf '%s\n' "$line" | sed -n "s|.*@v\([0-9][0-9]*\).*|\1|p")"
        [ -n "$maj" ] || continue
        [ "$maj" -lt "$min" ] && printf '%s:%s=%s@v%s\n' "$wf" "${line%%:*}" "$act" "$maj"
      done <<EOF
$hits
EOF
    done
  done
  return 0
}

# Run one gate, keep going on failure, remember what broke. NOT `set -e` and not `&&`: the
# whole point is that a push learns about every gate at once, and a chain stops at the first.
# ==== LIVENESS, BECAUSE A SILENT GATE AND A HUNG GATE LOOK IDENTICAL =========================
#
# `gate` captured its command in a command substitution, so nothing reached the terminal until
# the command finished. That is fine at one second and indefensible at thirty-three minutes,
# which is what `tests/audit_localcoder.sh` measured on 2026-08-13: 1,964s for the full suite
# against 18s for `--offline`, because eight cases perform live model drafts.
#
# During those thirty-three minutes preflight printed NOTHING. Three pushes were killed by
# people (and by me) assuming it had hung. A developer who cannot tell "working" from "wedged"
# kills it, and a gate that gets killed is a gate that does not run — which is this project's
# central defect arriving through the user interface rather than through the code.
#
# CADENCE IS SLOWER WHEN NOBODY IS WATCHING. On a TTY a person is waiting and wants to see
# movement; in CI the same output is log noise, so it drops to once a minute — enough to prove
# liveness to whoever reads the log later, not enough to bury the verdict.
HEARTBEAT_AFTER="${PREFLIGHT_HEARTBEAT_AFTER:-20}"
if [ -t 1 ]; then HEARTBEAT_EVERY="${PREFLIGHT_HEARTBEAT_EVERY:-15}"
else HEARTBEAT_EVERY="${PREFLIGHT_HEARTBEAT_EVERY:-60}"; fi

_fmt_dur() {  # seconds -> 42s / 12m04s
  local s="$1"
  if [ "$s" -lt 60 ]; then printf '%ds' "$s"; else printf '%dm%02ds' "$((s / 60))" "$((s % 60))"; fi
}

_heartbeat_wait() {  # _heartbeat_wait <pid> <label>
  local pid="$1" label="$2" start now el last
  start="$(date +%s)"; last="$start"
  while kill -0 "$pid" 2>/dev/null; do
    sleep 1
    now="$(date +%s)"; el=$(( now - start ))
    [ "$el" -lt "$HEARTBEAT_AFTER" ] && continue
    if [ $(( now - last )) -ge "$HEARTBEAT_EVERY" ]; then
      last="$now"
      printf '[..] %s — still running, %s elapsed\n' "$label" "$(_fmt_dur "$el")"
    fi
  done
  wait "$pid" 2>/dev/null || true
}

# THE FAILING ROW IS ALMOST NEVER IN THE LAST 25 LINES (localcoder#182).
#
# Both failure paths below printed `tail -25` of the suite's output. For a 172-case suite
# that is the closing rows plus the summary -- all of them PASS -- while the one `| FAIL`
# line sits somewhere in the middle and is discarded. Measured 2026-08-22: the localcoder
# audit failed once inside preflight and passed standalone twice on the same tree, and the
# case name was unrecoverable, so there was nothing to diagnose and nothing to reproduce.
# An intermittent failure is exactly the kind you only get one look at.
#
# Same fix localcoder's own mcp_client.py already carries for the same reason: keep the
# lines that look like a diagnosis, IN EMISSION ORDER, and then the tail. A first line names
# what was attempted, which a tail can never supply.
#
# Deliberately over-inclusive on the pattern. A duplicated line costs nothing; a dropped one
# costs the diagnosis.
salient_then_tail() {
  _stt_out="$1"
  _stt_sal="$(printf '%s\n' "$_stt_out" \
    | grep -inE '\| *(FAIL|BLOCKED)|^\[(FAIL|BLOCKED)\]|(^| )(FAIL|FAILED|not ok)( |:|$)|ERROR' \
    | head -14 || true)"
  if [ -n "$_stt_sal" ]; then
    echo "       ---- lines that look like the failure, in emission order (line:text) ----"
    printf '%s\n' "$_stt_sal" | sed 's/^/       /'
    echo "       ---- last 25 lines ----"
  fi
  printf '%s\n' "$_stt_out" | sed 's/^/       /' | tail -25
}

gate() {
  local label="$1"; shift
  local out rc=0 tmpf
  # NOT a command substitution any more: the output has to be somewhere the heartbeat loop can
  # leave alone while the command is still writing to it.
  tmpf="$(mktemp "${TMPDIR:-/tmp}/preflight-gate.XXXXXX")" || { echo "preflight: mktemp failed; stopping" >&2; exit 1; }
  ( "$@" >"$tmpf" 2>&1; echo "$?" >"$tmpf.rc" ) &
  _heartbeat_wait "$!" "$label"
  rc="$(cat "$tmpf.rc" 2>/dev/null || echo 99)"
  out="$(cat "$tmpf" 2>/dev/null || true)"
  rm -f "$tmpf" "$tmpf.rc"
  if [ "$rc" -eq 0 ]; then
    say_pass "$label"
    PASSED=$((PASSED + 1))
    log_verdict "$label" ok ""
  elif [ "$rc" -eq 3 ]; then
    # EXIT 3 IS "I VERIFIED NOTHING", AND IT IS NEITHER A PASS NOR A FAILURE (#188).
    #
    # Reported by an adopter against a tool written specifically to prevent silent
    # failures: their GDScript parse checker shells out to godot, godot was absent on the
    # runner, `command not found` went into the captured output, that string contains no
    # "Parse Error", and the tool announced "7 file(s) parse cleanly". Three CI runs green
    # on zero work. The gate emitted its STRONGEST verdict at the moment it was incapable
    # of any verdict.
    #
    # This branch is the other half of that fix. A tool can now say "could not check", and
    # without it the honest answer arrives here and is rendered [FAIL] — which trains
    # people to treat a missing toolchain as a broken build, and a gate people route around
    # is dead. It feeds the existing GAP machinery, which already exists for exactly this
    # idea on the coverage side.
    echo "[SKIP] $label  — NOT verified (exit 3)"
    printf '%s\n' "$out" | sed 's/^/       /' | tail -6
    GAPS="$GAPS|$label (skipped)"
    log_verdict "$label" skipped "exit 3 — verified nothing"
  else
    echo "[FAIL] $label  (exit $rc)"
    salient_then_tail "$out"
    FAILED="$FAILED $label"
    log_verdict "$label" FAIL "exit $rc"
  fi
  return 0
}

# ADVISORY, AND STRUCTURALLY INCAPABLE OF FAILING. `note` touches neither PASSED, FAILED nor
# GAPS: it prints something worth knowing and changes no verdict. It exists because the
# delegation share (localcoder#201) must be visible before it is enforceable -- a threshold set from an
# opinion rather than from fleet data trains people to route around the gate, which is the
# failure this repository keeps paying for.
note() {
  echo "[note] $1"
  [ -n "${2:-}" ] && echo "       $2"
  return 0
}

# A PASS IS NOT NEWS. Printed only under --verbose; the count in the verdict line still says
# how many there were. A pass that carries "not checked" in its text is not a pass in this
# sense and keeps its echo -- hiding it would make a non-check silent.
say_pass() {
  [ "${VERBOSE:-0}" = 1 ] && echo "[PASS] $1"
  return 0
}

# A gate that could not run is neither a pass nor a failure, and must not read as either.
gap() {
  echo "[GAP]  $1"
  [ -n "${2:-}" ] && echo "       $2"
  GAPS="$GAPS|$1"
  return 0
}

# ---- MUST-RUN GATES, DECLARED BY THE REPOSITORY (D19, W-22 part three) ----------------
#
# THE PROBLEM THIS SOLVES. Every `if [ -x tool ]` guard in this file falls through to a
# gap, and a gap prints above a PASSED line and exits 0. That is right for a genuinely
# environmental thing — no Ollama, no godot on this machine — and it is wrong for the
# repository's OWN test suite, which is not optional anywhere. D-18 is the case: localcoder
# had a forty-case suite that had never run in CI, discovered where it was not, gapped, and
# gone green for months. The count was visible; which gates it stood for was not.
#
# WHY THE DECLARATION LIVES IN AGENTS.md AND NOT IN THIS FILE. This script is VENDORED into
# every adopting project and force-installed on upgrade. A list of must-run gates written
# here would be wrong in one of the two places by construction, and would be overwritten in
# the adopter. AGENTS.md is the adopter's, already carries the Test command, and is already
# the file people edit when commands change. Same argument as the divergence markers
# needing to exist on both sides, and the second time this week the answer was "the
# statement lives with the thing it describes".
#
# WHY NOT AN EXPECTED GATE COUNT. Considered and rejected. A count is one number standing
# in for a set: two gates can vanish while one appears and the total is unchanged. Every
# legitimate environment difference forces a re-baseline, which becomes a ritual performed
# without reading. And keyed on an environment fingerprint it mints a fresh baseline
# whenever the fingerprint moves, so the number ends up always correct and never
# informative. The split has none of that.
#
# KEEP THE SET SMALL. A must-run gate that fails the build is a gate people route around,
# and that pressure is worse here than anywhere else in this file. The initial membership
# is exactly the repository's own test suite and nothing else; additions carry a recorded
# reason next to them. If it grows past a handful without reasons, the discipline failed
# rather than the design.
#
# Declared at column 0 in AGENTS.md, same shape and same reason as the scaffold: markers —
# an indented example inside a code block is documentation, not a declaration.
#
#     <!-- scaffold:must-run tests/audit_localcoder.sh -->
#
MUST_RUN=""
if [ -f AGENTS.md ]; then
  MUST_RUN="$(grep -E '^<!--[[:space:]]*scaffold:must-run[[:space:]]+[^[:space:]]+[[:space:]]*-->[[:space:]]*$' \
              AGENTS.md 2>/dev/null | sed -E 's/^<!--[[:space:]]*scaffold:must-run[[:space:]]+//; s/[[:space:]]*-->[[:space:]]*$//' || true)"
fi

# INSIDE AN ADOPTION FIXTURE, THE ADOPTER'S OWN SUITE IS NOT THIS CHECK'S BUSINESS (#227).
#
# adoption_check.sh builds a synthetic adoption and runs a full preflight inside it, twice.
# Its question is "do the SCAFFOLD's gates work in an adoption" — and in an adopter that
# declares a must-run gate, that inner preflight was also running the ADOPTER'S PRODUCT
# SUITE, in both fixtures, on every push.
#
# MEASURED 2026-08-18, and it is the whole difference between the two repos:
#
#   ai-project-scaffold   declares no must-run   adoption_check  62s
#   localcoder            must-run: the audit    adoption_check 131s   (47s of audit, twice)
#
# On the self-hosted M3 that ran past a 12-minute ceiling, and the SAME suite then ran a
# third time as the job's own audit step. Three runs of one suite per push, two of them
# proving nothing the third did not.
#
# IT IS ALSO WRONG ATTRIBUTION, which matters more than the minutes: an adopter whose
# product suite fails would fail adoption_check — a check named for the scaffold, reporting
# a defect in something else. Skipping it here makes the check answer its own question.
#
# NAMED, NEVER SILENT. A gate that stops running must say so, which is the rule this file
# exists to enforce; the skip is printed with the reason and the set that was skipped.
ADOPTION_FIXTURE="${SCAFFOLD_ADOPTION_FIXTURE:-0}"
MUST_RUN_SKIPPED=""
if [ "$ADOPTION_FIXTURE" = "1" ] && [ -n "$MUST_RUN" ]; then
  MUST_RUN_SKIPPED="$MUST_RUN"
  MUST_RUN=""
fi

# NOT-INSTALLED AND NOT-EXECUTABLE ARE DIFFERENT FAILURES THAT PRINT THE SAME WAY.
# `[ -x path ]` is false for both, so a lost +x bit and a missing file are indistinguishable
# — and the lost bit is the likelier of the two and the more confusing, because the file is
# right there in the listing. Measured in this repo twice in one week: a `git apply --reject`
# dropped the +x from tools/audit_localcoder.sh and preflight ran 24 gates instead of 26 and
# still printed PASSED; and tools/localcoder_footprint.py was committed with git recording
# 644 despite the on-disk +x, which mode_scan caught only once the file was tracked.
#
# Neither mechanism subsumes the other. This one would have caught both of those instantly
# and would NOT have caught D-18, where the file is genuinely absent from the searched path.
# That is why D19 keeps them independent.
why_unrunnable() {
  if [ -e "$1" ]; then
    if [ -d "$1" ]; then
      echo "is a directory, not a runnable gate"
    else
      echo "EXISTS BUT IS NOT EXECUTABLE — chmod +x '$1' (and check 'git ls-files -s' records 755, not 644)"
    fi
  else
    echo "does not exist at that path"
  fi
}

# A gate the repository declares it MUST run. Not running it is a failure, whatever the
# reason — that is the entire content of the declaration.
# THE ARCHIVE CEILINGS, SPLIT OUT SO THE BRANCH HAS CASES (#265). Inline in run_all it could
# only be exercised by owning a repository whose ai/ files were actually over the line -- which
# is precisely how it went unnoticed that nothing escalated. Same reason classify_var_value and
# alert_line are split out in ci_status.sh.
# THE DOCUMENT-TO-SOURCE COUPLING (#doc-currency). Split out for the same reason
# archive_gate is: inline in run_all it could only be exercised by owning a repository whose
# documents had actually drifted, which is exactly how the drift went unnoticed in the first
# place. On 2026-09-11 mcp_client.py changed what an EMPTY credential does and docs/MCP.md
# described the old behaviour in four places, while every gate in the tree passed.
# THE RUNNER VALUE, VALIDATED BEFORE THE PUSH RATHER THAN AT PARSE TIME IN CI.
# A malformed SCAFFOLD_RUNNERS kills the workflow during EXPRESSION EVALUATION -- no steps,
# no log, and an error that never names the variable. That is indistinguishable from a broken
# runner. ci_status.sh --check applies the same rules locally, and exists because the shipped
# workflow had been telling people to run it since before it was written.
runner_value_gate() {
  if [ -x tools/ci_status.sh ]; then
    _rv_out="$(tools/ci_status.sh --check 2>&1)" && _rv_rc=0 || _rv_rc=$?
    case "$_rv_rc" in
      0) say_pass "the runner variable is a well-formed matrix list"
         PASSED=$((PASSED + 1)); log_verdict "runner value" ok "" ;;
      3) gap "runner value: could not read it" \
             "no gh, or not a GitHub repository — pass a value to check one offline" ;;
      *) echo "[FAIL] SCAFFOLD_RUNNERS is malformed — CI will die before any step runs"
         printf '%s\n' "$_rv_out" | sed 's/^/       /'
         FAILED="$FAILED runner-value"; log_verdict "runner value" fail "" ;;
    esac
  fi
}

doc_currency_gate() {
  if [ -x tools/doc_currency.py ]; then
    _dc_out="$(tools/doc_currency.py --check 2>&1)" && _dc_rc=0 || _dc_rc=$?
    case "$_dc_rc" in
      0) say_pass "documents are current with the source they describe"
         PASSED=$((PASSED + 1)); log_verdict "doc currency" ok "" ;;
      3) gap "doc currency: nothing declares what it documents" \
             "no <!-- scaffold:documents ... --> marker in the tree, so nothing was checked" ;;
      *) echo "[FAIL] a document is behind the source it describes"
         printf '%s\n' "$_dc_out" | sed 's/^/       /'
         FAILED="$FAILED doc-currency"; log_verdict "doc currency" fail "" ;;
    esac
  fi
}

python_floor_gate() {
  # THE FLOOR IS A PROMISE TO AN ADOPTER, and until 0.109.0 nothing in this tree read it.
  # Exit 3 is the normal answer here and in most adopters -- no pyproject.toml, or one that
  # declares no lower bound -- and it must stay a GAP rather than a pass, because "nobody
  # promised anything" and "the promise is kept" are different answers.
  #
  # THIS USED TO HAND-ROLL THE 0/1/3 SPLIT and was rewritten onto gate() at 0.110.0 for the
  # reason recorded above the lint_python.sh call: gate() already understands exit 3 for
  # every tool, so a bespoke case statement here was a second definition of the same rule,
  # free to drift from the first. It had already drifted -- it did arithmetic on FAILED,
  # which gate() treats as a string of gate names, and that mismatch is the defect fixed
  # in this same release. A duplicated rule does not stay a duplicate; it becomes a bug.
  if [ -x tools/python_floor.py ]; then
    gate "python floor (every file parses at the declared requires-python)" \
         tools/python_floor.py --check
  fi
}

archive_gate() {
  if [ -x tools/session_archive.py ]; then
    _arc_out="$(tools/session_archive.py --all --check --exit-status 2>&1)" && _arc_rc=0 || _arc_rc=$?
    case "$_arc_rc" in
      0) say_pass "archive ceilings (ai/ files under their lines)"
         PASSED=$((PASSED + 1)); log_verdict "archive ceilings" ok "" ;;
      1) printf '%s\n' "$_arc_out" | grep '\[over\]' | sed 's/^ *//; s/^/       /'
         gap "archive ceilings: a file is over its archive line" \
             "advisory by design — see the per-file commands under a BURST, nothing is deleted" ;;
      *) echo "[FAIL] archive ceilings — PAST THE BURST LINE"
         printf '%s\n' "$_arc_out" | grep -E '\[(BURST|over)\]' | sed 's/^ *//; s/^/       /'
         echo "       Past the burst line is a trim that STOPPED HAPPENING, not 'a bit over'."
         echo "       Nothing is deleted. THE COMMAND DIFFERS PER FILE:"
         echo "         tools/session_archive.py --apply             # SESSION.md — rotates"
         echo "         tools/session_archive.py --backlog-preserve  # BACKLOG.md — copies"
         echo "         tools/session_archive.py --memory-preserve   # MEMORY.md  — COPIES ONLY,"
         echo "                                                      # then you trim by hand"
         # ONE COMMAND FOR THREE FILES WAS WRONG AND EXPENSIVELY SO. --apply rotates
         # SESSION.md and deliberately does not touch MEMORY.md: deciding which lines of a
         # decision are still load-bearing is judgement, and ai/STANDARDS.md forbids
         # auto-rotating it. So naming only --apply here sends someone to a tool that
         # correctly does nothing for the file they were sent about -- and until this
         # release, then told them everything was already archived. That is how an adoption
         # reached 873 lines while every signal said the trim was done.
         FAILED="$FAILED archive-ceilings"
         log_verdict "archive ceilings" failed "past the burst line" ;;
    esac
  else
    gap "tools/session_archive.py is missing" "the archive ceilings were not checked"
  fi
}

# THE RECORD TRAVELS ONLY IF GIT CAN SEE IT (ai/STANDARDS.md -> What must never be
# gitignored). An archive exists because a live file hit its ceiling: the history MOVED there.
# If a .gitignore pattern matches it, the dirty-tree precondition cannot see it either, so it
# is never committed, never pushed, never pulled by the next developer, and nothing says so.
# That is a rotation turned into a silent data loss, on one machine.
#
# CHECKED BY NAME, NOT BY WHAT EXISTS. The archives a project does not have yet are exactly the
# ones a pattern would swallow on the day they are created, so all three standard names are
# tested whether or not the file is there, plus any other ai/*_ARCHIVE*.md on disk.
# --no-index: a file that was force-added is tracked today, but the pattern still hides the
# next archive a rotation writes, and on a fresh clone it hides nothing only by luck.
record_ignore_gate() {
  local f hits="" src
  [ -f ai/STANDARDS.md ] || return 0
  git rev-parse --git-dir >/dev/null 2>&1 || return 0
  for f in ai/MEMORY.md ai/SESSION.md ai/BACKLOG.md \
           ai/MEMORY_ARCHIVE.md ai/SESSION_ARCHIVE.md ai/BACKLOG_ARCHIVE.md ai/*_ARCHIVE*.md; do
    case "$f" in *'*'*) continue ;; esac
    case " $hits " in *" $f "*) continue ;; esac
    if src="$(git check-ignore --no-index -v "$f" 2>/dev/null)"; then
      hits="$hits $f"
      echo "       $f  <- ${src%%	*}"
    fi
  done
  if [ -z "$hits" ]; then
    say_pass "the record files and every archive are visible to git"
    PASSED=$((PASSED + 1)); log_verdict "record files not ignored" ok ""
  else
    echo "[FAIL] a .gitignore hides part of the project's record (pattern source above)"
    echo "       An ignored archive is never committed, so the history it holds stays on"
    echo "       this machine. Remove the pattern; see ai/STANDARDS.md -> What must never"
    echo "       be gitignored."
    FAILED="$FAILED record-ignored"
    log_verdict "record files not ignored" failed "$hits"
  fi
}

must_gate() {
  local label="$1" path="$2"; shift 2
  if [ -x "$path" ]; then
    gate "$label" "$path" "$@"
    return
  fi
  echo "[FAIL] $label  — DECLARED must-run in AGENTS.md and it did not run"
  echo "       $path $(why_unrunnable "$path")"
  echo "       A gap here would print above a PASSED line. This repository declared that"
  echo "       is not acceptable for this gate. Fix it or remove the declaration."
  FAILED="$FAILED $label"
  log_verdict "$label" failed "declared must-run; $(why_unrunnable "$path")"
}

declared_must_run() {
  case "|$(printf '%s' "$MUST_RUN" | tr '\n' '|')|" in
    *"|$1|"*) return 0 ;;
    *) return 1 ;;
  esac
}

# WHERE SELFTEST DISCOVERY LOOKS. `tools/` always — plus any directory the project DECLARES
# as holding its own product, at column 0 in AGENTS.md:
#
#     <!-- scaffold:product-dir src/localcoder -->
#
# WHY THIS EXISTS. `Robiton/localcoder` ships its product at `src/localcoder/`; `tools/` there
# is the vendored governance layer. Scanning only `tools/` meant that repository's own shipped
# executables were the one thing CI never selftested — the exact "a rule with nothing behind
# it" failure the discovery loop was written to prevent, reproduced by the loop itself.
#
# It had been fixing that by EDITING the workflow, which made `scaffold-check.yml` a divergent
# PRODUCT file: every upgrade left a `.scaffold-<version>` sidecar to reconcile by hand, and on
# 2026-08-12 three of those were found tracked and unreconciled since 2026-08-09 — one of them
# this file. A declaration the scaffold reads removes the divergence instead of asking a human
# to remember it on every upgrade.
#
# DECLARED, NEVER INFERRED — the same rule as every other marker here. Globbing for "somewhere
# that looks like a product" would pick up `dist/`, `vendor/` and a stale build tree, and a
# discovery loop that quietly grows is as bad as one that quietly shrinks. An indented example
# inside a code block is documentation, not a declaration.
#
# A DECLARED DIRECTORY THAT DOES NOT EXIST IS A FAILURE, not a skip. Silently ignoring it is
# how a renamed product directory retires a whole suite with nothing to notice — which is D-18
# exactly, and the reason `scaffold:must-run` behaves the same way.
PRODUCT_DIR_MARK='scaffold:product-dir'
declared_product_dirs() {
  [ -f AGENTS.md ] || return 0
  grep -oE "^<!--[[:space:]]*${PRODUCT_DIR_MARK}[[:space:]]+[^[:space:]]+" AGENTS.md 2>/dev/null \
    | awk '{print $NF}'
  return 0
}
missing_product_dirs() {
  local d
  for d in $(declared_product_dirs); do [ -d "$d" ] || echo "$d"; done
  return 0
}
scan_dirs() {
  local d
  echo tools
  for d in $(declared_product_dirs); do [ -d "$d" ] && echo "$d"; done
  return 0
}

# Every tools/* that advertises --selftest, DISCOVERED exactly as CI discovers them.
# SELF-EXCLUDED, OR THIS RECURSES: preflight advertises --selftest, its selftest runs the
# gates, and the gates would run every selftest. Excluded by basename, so a renamed copy
# still cannot re-enter.
# A SUITE THAT CANNOT BE INVOKED LOOKS EXACTLY LIKE A SUITE THAT PASSED.
#
# selftest_tools() filters on `[ -x ]`, which is correct -- a non-executable file cannot be
# run -- but it did so SILENTLY, so a tool that lost its mode bit stopped being selftested
# locally and nothing said a word. CI has named this at the point it bites since the
# conflict_scan.sh incident (15 cases, tracked 644, step reported "12 suites passed" in
# green); preflight did not.
#
# mode_scan.sh is not the same cover. In an ADOPTION it checks only files whose header says
# the scaffold wrote them, so an adopter's OWN tool shipping --selftest at 644 falls through
# both: skipped here without comment, and out of scope there. Reported by collectionapp, who
# hit exactly that -- their tool errored in CI while local preflight stayed quiet.
#
# Same standard this file already applies one layer up. It refuses a commit when a tool ships
# `--check` and no gate calls it; a tool that ships `--selftest` and cannot be executed is
# the same defect with the mode bit as the cause instead of the wiring.
selftest_unrunnable() {
  local t d
  for d in $(scan_dirs); do
  for t in "$d"/*; do
    [ -f "$t" ] || continue
    [ -x "$t" ] && continue
    case "$t" in *.md|*.template) continue ;; esac
    grep -q -- '--selftest' "$t" 2>/dev/null || continue
    echo "$t"
  done
  done
}

selftest_mode_gate() {
  local bad
  bad="$(selftest_unrunnable)"
  if [ -z "$bad" ]; then
    say_pass "every tool carrying --selftest can actually be invoked"
    PASSED=$((PASSED + 1)); log_verdict "selftest executability" ok ""
    return 0
  fi
  echo "[FAIL] a tool ships --selftest and cannot be executed — its suite is retired, silently"
  printf '%s\n' "$bad" | while IFS= read -r t; do
    [ -n "$t" ] || continue
    echo "       $t"
    echo "         git update-index --chmod=+x '$t'"
  done
  echo "       A skipped suite reads exactly like a passing one. core.fileMode=false is the"
  echo "       correct setting on this filesystem and is precisely what hides it locally."
  FAILED="$FAILED selftest-executability"; log_verdict "selftest executability" fail ""
}

selftest_tools() {
  local t d
  for d in $(scan_dirs); do
  for t in "$d"/*; do
    [ -x "$t" ] || continue
    [ -f "$t" ] || continue
    case "$t" in *.md|*.template) continue ;; esac
    if [ "$(basename "$t")" = "$(basename "${BASH_SOURCE[0]}")" ]; then continue; fi
    grep -q -- '--selftest' "$t" || continue
    echo "$t"
  done
  done
}

# CONCURRENT BY DEFAULT, AND THE ALTERNATIVE WAS TO RUN FEWER OF THEM.
#
# Serially the suites cost ~31s here, on top of ~12s for the rest — and a pre-push gate
# that takes three quarters of a minute is one people stop running, which ai/SECURITY.md
# already names as how a guard ends up protecting nothing. The tempting fix was to run only
# the selftests of tools changed on this branch. That is the cheaper answer and the wrong
# one: it is "a check aimed away from the risk reads as coverage" by construction, because
# the suite most likely to catch a regression is the one belonging to the tool you did NOT
# touch. Concurrency buys the same wall clock with no coverage given up — the run is bounded
# by the slowest single suite instead of their sum.
#
# Output is buffered per tool and printed in list order, so a parallel run reads exactly like
# a serial one. Interleaved output from eighteen suites would be unusable, and a gate whose
# failures are hard to read is a gate people re-run serially anyway.
run_selftests() {
  local tools tmp i n t rc out started jobs cap
  tools="$(selftest_tools)"
  if [ -z "$tools" ]; then
    gap "no tool selftests were found" "that is almost certainly wrong"
    return 0
  fi
  cap="$( (command -v nproc >/dev/null 2>&1 && nproc) || sysctl -n hw.ncpu 2>/dev/null || echo 4 )"
  [ "$cap" -gt 8 ] && cap=8
  [ "$SERIAL" -eq 1 ] && cap=1
  tmp="$(mktemp -d "${TMPDIR:-/tmp}/preflight-st.XXXXXX")" || { echo "preflight: mktemp failed; stopping" >&2; exit 1; }
  i=0
  started=$(date +%s)
  for t in $tools; do
    i=$((i + 1))
    ( : > "$tmp/$i.started"; "$t" --selftest >"$tmp/$i.out" 2>&1; echo "$?" >"$tmp/$i.rc" ) &
    # bash 3.2 has no `wait -n`, so throttle by polling the job table. The sleep is the
    # granularity of the throttle, not a fixed cost: suites finish in ~1s here.
    while [ "$(jobs -pr | wc -l | tr -d ' ')" -ge "$cap" ]; do sleep 0.2; done
  done

  # WAIT OUT LOUD. A bare `wait` here is silent for as long as the slowest suite takes, and
  # the slowest suite is the one you most want named — it is the one you are about to suspect
  # of hanging. Polling the .started/.rc markers is more honest than the job table: it can say
  # "running" and "queued" separately, and a queued suite reported as running would be a lie in
  # the one message whose whole job is telling the truth about what is happening.
  local hb_last hb_now hb_el j run_n queue_n run_names
  hb_last="$started"
  while :; do
    run_n=0; queue_n=0; run_names=""
    j=0
    for t in $tools; do
      j=$((j + 1))
      [ -f "$tmp/$j.rc" ] && continue
      if [ -f "$tmp/$j.started" ]; then
        run_n=$((run_n + 1)); run_names="$run_names $t"
      else
        queue_n=$((queue_n + 1))
      fi
    done
    [ "$run_n" -eq 0 ] && [ "$queue_n" -eq 0 ] && break
    hb_now="$(date +%s)"; hb_el=$(( hb_now - started ))
    if [ "$hb_el" -ge "$HEARTBEAT_AFTER" ] && [ $(( hb_now - hb_last )) -ge "$HEARTBEAT_EVERY" ]; then
      hb_last="$hb_now"
      printf '[..] %s elapsed — %d running,%s %d queued\n' \
        "$(_fmt_dur "$hb_el")" "$run_n" "$(printf '%s' "$run_names" | sed 's/  */ /g')" "$queue_n"
    fi
    sleep 1
  done
  wait
  n=$i
  i=0
  for t in $tools; do
    i=$((i + 1))
    rc="$(cat "$tmp/$i.rc" 2>/dev/null || echo 99)"
    if [ "$rc" -eq 0 ]; then
      say_pass "$t --selftest"
      PASSED=$((PASSED + 1))
      log_verdict "$t --selftest" ok ""
    else
      echo "[FAIL] $t --selftest  (exit $rc)"
      out="$(cat "$tmp/$i.out" 2>/dev/null || true)"
      salient_then_tail "$out"
      FAILED="$FAILED $t"
      log_verdict "$t --selftest" FAIL "exit $rc"
    fi
  done
  rm -rf "$tmp"
  echo "       ($n suite(s) in $(( $(date +%s) - started ))s, up to $cap at a time — CI runs the same set)"
  return 0
}

base_ref() {
  if [ -n "$SINCE" ]; then echo "$SINCE"; return; fi
  local b
  b="$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || true)"
  if [ -n "$b" ] && git rev-parse --verify --quiet "$b" >/dev/null; then echo "$b"; return; fi
  for b in origin/main origin/master main master; do
    if git rev-parse --verify --quiet "$b" >/dev/null; then echo "$b"; return; fi
  done
  echo ""
}

# ---------------------------------------------------------------- the last push's CI verdict
#
# THE RULE EXISTED AND DID NOT FIRE. "Check CI after every push" was standing fleet guidance
# when a session shipped two scanner adapters, ran `tools/preflight.sh` locally, saw green,
# and reported success -- while CI had been red on main since the previous push. The gap was
# never knowledge. It was that nothing in the loop REQUIRED the check, and a rule enforced by
# memory alone is enforced by nothing.
#
# WHAT THIS DOES NOT DO, stated here because a gate whose limits are written down can be
# trusted and one assumed to catch everything gets believed when it is silent:
#   - it does NOT check the commit you are about to push (nothing has run for it yet)
#   - it does NOT block when CI cannot be reached -- see the `unknown` state below
#   - it does NOT run inside CI, inside a fixture, or inside a nested preflight
_bounded() {  # _bounded <seconds> <cmd...> — portable; `timeout` is not on a stock macOS
  local secs="$1"; shift
  local tmpf pid waited rc
  tmpf="$(mktemp "${TMPDIR:-/tmp}/preflight-ci.XXXXXX")" || { echo "preflight: mktemp failed; stopping" >&2; exit 1; }
  ( "$@" >"$tmpf" 2>/dev/null; echo "$?" >"$tmpf.rc" ) &
  pid=$!
  waited=0
  while kill -0 "$pid" 2>/dev/null; do
    if [ "$waited" -ge "$secs" ]; then
      kill -TERM "$pid" 2>/dev/null; sleep 1; kill -KILL "$pid" 2>/dev/null; break
    fi
    sleep 1; waited=$((waited + 1))
  done
  wait "$pid" 2>/dev/null || true
  rc="$(cat "$tmpf.rc" 2>/dev/null || echo 124)"
  cat "$tmpf" 2>/dev/null
  rm -f "$tmpf" "$tmpf.rc"
  return "$rc"
}

# PURE, AND SEPARATE FROM THE FETCH ON PURPOSE: this is the half with the interesting logic,
# and splitting it is what lets --selftest exercise it with no network and no gh at all.
# Reads TSV on stdin: <status>\t<conclusion>\t<workflowName>\t<url>. Echoes "<state>|<detail>".
_ci_aggregate() {
  local raw cls red pend first
  raw="$(cat)"
  [ -n "$raw" ] && [ -n "$(printf '%s' "$raw" | tr -d '[:space:]')" ] || {
    echo "unknown|no workflow run is recorded for that commit"; return 0; }
  # GREEN IS AN ALLOWLIST, AND EVERYTHING ELSE IS UNRESOLVED (#312). The first version here
  # denylisted the red conclusions and let every other row fall through to the GREEN count.
  # `stale` is a real GitHub conclusion and counted as a pass -- the precise failure this
  # precondition exists to prevent, reproduced inside the precondition itself for the second
  # time. GitHub publishes no conclusion-only enum (the REST reference gives one combined
  # status/conclusion filter list), so a denylist is a promise that cannot be checked against
  # anything, and it silently absorbs whatever GitHub adds after this line was written.
  #
  # Three conclusions mean "it ran and did not object": success, skipped, neutral. A skipped
  # workflow deliberately did not apply. Four mean it objected. ANYTHING ELSE reached no
  # verdict, and unresolved -- exit 3, the could-not-run answer -- is the honest reading.
  # RED STAYS A DENYLIST ON PURPOSE: calling CI red is a positive claim about someone's
  # build, and an unrecognised conclusion does not license it. Unrecognised is unresolved.
  #
  # AWK FIELD-SPLITTING, NOT A TAB INSIDE A REGEX. The first version matched
  # '^completed<TAB>(failure|...)' with a literal tab byte in the pattern. It worked -- and it
  # is invisible in every editor, so one reformat, one copy through a web form, one linter that
  # expands tabs, and the pattern matches NOTHING. red and pending would both count zero and
  # every verdict would come back GREEN. awk -F splits on the field separator and needs no
  # escape anyone can disagree about or accidentally normalise.
  #
  # ONE CLASSIFIER, THREE READERS. The conclusion lists appear exactly once: three copies of
  # them in three filters is how the next edit moves one and leaves two, which is the same
  # one-string-two-callers rule the selftest is already held to. It prepends a class column,
  # so every reader cuts it off before formatting. NF>0 keeps blank lines out of the counts.
  _ci_classify() {
    awk -F'\t' '
      NF==0 { next }
      {
        cls = "pend"
        if ($1 == "completed") {
          if ($2 == "success" || $2 == "skipped" || $2 == "neutral") cls = "ok"
          else if ($2 == "failure" || $2 == "timed_out" || \
                   $2 == "startup_failure" || $2 == "action_required") cls = "red"
        }
        print cls "\t" $0
      }'
  }
  cls="$(printf '%s\n' "$raw" | _ci_classify)"
  red="$(printf  '%s\n' "$cls" | awk -F'\t' '$1=="red"'  | grep -c . | tr -d ' ')"
  pend="$(printf '%s\n' "$cls" | awk -F'\t' '$1=="pend"' | grep -c . | tr -d ' ')"
  if [ "${red:-0}" -gt 0 ]; then
    first="$(printf '%s\n' "$cls" | awk -F'\t' '$1=="red"' | head -1 | cut -f2-)"
    echo "red|$(printf '%s' "$first" | awk -F'\t' '{print $3" — "$4}')"
  elif [ "${pend:-0}" -gt 0 ]; then
    # THE DETAIL LINE MUST NAME WHAT HAPPENED, NOT THE STATUS FIELD. This printed $1, which
    # is right for a run still going and useless for anything completed: a CANCELLED run told
    # the reader preflight was blocking because "CI is completed" -- true, and no help at all.
    first="$(printf '%s\n' "$cls" | awk -F'\t' '$1=="pend"' | head -1 | cut -f2-)"
    echo "pending|$(printf '%s' "$first" | awk -F'\t' '{
      if ($1 != "completed")  w = "is " $1
      else if ($2 != "")      w = "completed as " $2 " (no verdict)"
      else                    w = "completed with NO conclusion recorded (no verdict)"
      print $3" "w" — "$4 }')"
  else
    echo "ok|$(printf '%s\n' "$raw" | grep -c . | tr -d ' ') run(s) green"
  fi
}

ci_last_push_state() {  # echoes "<state>|<detail>"; state is ok|red|pending|unknown|skip
  [ -n "${SCAFFOLD_PREFLIGHT_INNER:-}" ] && { echo "skip|nested preflight"; return 0; }
  [ -n "${CI:-}" ]                       && { echo "skip|running inside CI"; return 0; }
  [ "${SCAFFOLD_ADOPTION_FIXTURE:-0}" = "1" ] && { echo "skip|adoption fixture"; return 0; }
  [ -d .github/workflows ]               || { echo "skip|no .github/workflows here"; return 0; }
  command -v gh >/dev/null 2>&1          || { echo "unknown|gh is not installed"; return 0; }
  git remote get-url origin >/dev/null 2>&1 || { echo "skip|no origin remote"; return 0; }

  # @{u} MEANS "THE REF YOU WOULD PUSH TO", AND THAT IS THE MEANING INTENDED. This is a
  # pre-push gate, so the question is whether the thing you are about to push ONTO has
  # reached a verdict -- not whether your own last push has. On the ordinary configuration
  # they coincide; on a feature branch tracking origin/main they do not, and it is main's
  # verdict that is read, correctly. "The last push's CI verdict" and "the upstream's CI
  # verdict" are the same sentence in English and only one of them is what this code does.
  #
  # AN ABSENT UPSTREAM IS UNKNOWN, NEVER OK. `git rev-parse @{u}` exits 128 on a branch that
  # has never been pushed -- the first feature branch every adopter makes. An empty capture
  # reading as "nothing red" is the exact shape of both bugs already fixed in this function.
  local up sha br raw rc=0
  up="$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)"
  [ -n "$up" ] || { echo "unknown|this branch has no upstream — nothing has been pushed to check"; return 0; }
  sha="$(git rev-parse "$up" 2>/dev/null || true)"
  [ -n "$sha" ] || { echo "unknown|could not resolve $up"; return 0; }
  br="${up#origin/}"

  # gh's stderr is discarded and a non-zero rc becomes `unknown`, NOT "no runs, fine". The
  # account this CLI is logged into switches silently, and the symptom is a 404 that reads
  # exactly like a repository with no history.
  # FETCH UNFILTERED AND SELECT THE SHA LOCALLY, SO THE TWO EMPTY CASES STAY DISTINCT.
  # The first version pushed `select(.headSha==...)` into the --jq and got one empty string
  # back for BOTH "gh returned nothing at all" and "gh returned runs, none of them for this
  # commit". That cost a real diagnosis: this gate reported "no workflow run is recorded" once
  # on a commit that demonstrably had three, and the message could not say which half failed,
  # so it was unreproducible by construction. Two different facts must not share one symptom.
  raw="$(_bounded 25 gh run list --branch "$br" --limit 40 \
          --json headSha,status,conclusion,workflowName,url \
          --jq '.[] | [.headSha,.status,(.conclusion // ""),.workflowName,.url] | @tsv')" || rc=$?
  if [ "$rc" -ne 0 ]; then
    echo "unknown|gh could not list runs (exit $rc): offline, unauthenticated, rate-limited, or the wrong account"
    return 0
  fi
  local total mine
  total="$(printf '%s\n' "$raw" | grep -c . | tr -d ' ')"
  if [ "${total:-0}" -eq 0 ]; then
    echo "unknown|gh returned NO runs at all for branch $br (exit 0) — not a verdict, and not 'this commit has no run'"
    return 0
  fi
  # ENVIRON, NOT -v. `awk -v x=VALUE` runs the value through strnum conversion, and a sha is
  # 40 hex characters that can be all digits. Two such shas would then compare NUMERICALLY,
  # which is the documented way this estate has already lost a value to -inf once.
  mine="$(printf '%s\n' "$raw" | SHA="$sha" awk -F'\t' 'NF>0 && $1==ENVIRON["SHA"]' | cut -f2-)"
  if [ -z "$(printf '%s' "$mine" | tr -d '[:space:]')" ]; then
    echo "unknown|$total run(s) listed on $br, NONE for ${sha} — it may be older than the last 40, or path filters skipped it"
    return 0
  fi
  printf '%s\n' "$mine" | _ci_aggregate
}

run_all() {
  local dirty base t found

  if ! git rev-parse --git-dir >/dev/null 2>&1; then
    echo "preflight: not a git repository — nothing here can tell you what you would push."
    return 2
  fi

  echo "preflight — everything CI will run, before the push instead of after"
  echo ""

  # ---- precondition: the tree must be what you are about to push
  dirty="$(git status --porcelain -uall)"
  if [ -n "$dirty" ] && [ "$ALLOW_DIRTY" -eq 0 ]; then
    echo "REFUSING TO RUN — the working tree is dirty, so this run would not describe"
    echo "what you would push. NO CHECK HAS FAILED; this is a precondition."
    echo ""
    printf '%s\n' "$dirty" | sed 's/^/  /' | head -15
    echo ""
    echo "  tools/header_check.sh --since reads the COMMITTED diff. With a change still in"
    echo "  the working tree it reports clean and proves nothing — that is how two invalid"
    echo "  test setups passed before a real reproduction (#166)."
    echo ""
    echo "  Commit, then re-run.   Or: tools/preflight.sh --allow-dirty"
    return 3
  fi
  if [ -n "$dirty" ]; then
    PREFLIGHT_DIRTY=1
    gap "the working tree is dirty and --allow-dirty was given" \
        "the gates below describe the COMMITTED tree, not what is on disk"
  fi

  # ---- the repository's own branch rule (Clocktower #3)
  # ai/TEAM.md says "Never commit directly to main" in most adoptions, and a full day of
  # commits went to main anyway -- nothing that runs before a push reads TEAM.md. A GAP, not
  # a failure: scaffold upgrades commit on main by design, and a gate that blocks them gets
  # routed around. The guard hook is what asks at commit time; this says it at push time.
  _pf_branch="$(git branch --show-current 2>/dev/null || true)"
  case "$_pf_branch" in
    main|master)
      if grep -qiE 'never commit directly to .?(main|master)' ai/TEAM.md 2>/dev/null; then
        _pf_ahead="$(git rev-list --count '@{u}..HEAD' 2>/dev/null || echo '?')"
        if [ "$_pf_ahead" != "0" ]; then
          gap "$_pf_ahead unpushed commit(s) on '$_pf_branch', and ai/TEAM.md says never commit directly to it" \
              "branch and open a PR: git switch -c fix/<topic> (the commits come with you), then reset $_pf_branch to @{u}"
        fi
      fi ;;
  esac

  # ---- precondition: the LAST PUSH's CI verdict must be resolved and green
  _ci_raw="$(ci_last_push_state)"
  up_label="$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || echo '?') @ $(git rev-parse --short '@{u}' 2>/dev/null || echo '?')"
  _ci_why="${_ci_raw#*|}"
  _ci_state="${_ci_raw%%|*}"
  case "$_ci_state" in
    red|pending)
      if [ "$ALLOW_CI_UNRESOLVED" -eq 0 ]; then
        echo "REFUSING TO RUN — the commit you last PUSHED has an unresolved CI verdict, so a"
        echo "green run here would report clean on top of it. NO CHECK HAS FAILED; this is a"
        echo "precondition."
        echo ""
        echo "  last pushed:  $(git rev-parse --short '@{u}' 2>/dev/null || echo '?') on $(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || echo '?')"
        echo "  CI verdict:   $_ci_state — $_ci_why"
        echo ""
        echo "  This gate exists because \"check CI after every push\" was already the rule and"
        echo "  was followed by memory, which is to say not followed. Pushing again now stacks"
        echo "  a second commit on a verdict nobody has read."
        echo ""
        if [ "$_ci_state" = "red" ]; then
          echo "  Fix it, or — if THIS commit IS the fix, which is the whole reason this is a"
          echo "  precondition and not a failed gate:"
        else
          echo "  Wait for it to finish, or:"
        fi
        echo "    tools/preflight.sh --ci-unresolved-ok"
        return 3
      fi
      gap "the last push's CI verdict is $_ci_state and --ci-unresolved-ok was given" "$_ci_why"
      ;;
    unknown)
      # ADVISORY ON PURPOSE, AND THE LIMIT IS NAMED RATHER THAN HIDDEN. An offline preflight
      # still reports clean. Blocking here would make the tool unusable on a plane and a
      # precondition people cannot satisfy is a precondition people remove.
      gap "could not read the last push's CI verdict" \
          "$_ci_why — this precondition is ADVISORY when CI is unreachable, so THIS RUN PROVES NOTHING about CI"
      ;;
    ok)
      # A VERIFIED GREEN MUST SAY SO OUT LOUD, because the alternative is that it looks
      # exactly like never having checked. This branch did not exist: `ok` fell out of the
      # case printing nothing and counting nothing, so a run that READ the verdict and a run
      # that SKIPPED the check produced byte-identical output. That is this gate's own thesis
      # -- a non-verdict must not read as a pass -- failing one layer above the code that
      # enforces it, which is the shape that took a whole afternoon to find in ci_status.sh.
      # NAMES THE COMMIT IT IS ABOUT, for the same reason the CI verdict line does: "CI is
      # green" is a claim about a sha, and a branch moves.
      say_pass "the last push's CI verdict is green ($up_label)"
      PASSED=$((PASSED + 1))
      ;;
    skip)
      # SILENT ON PURPOSE, AND THIS IS THE ONE EXEMPTION HERE WORTH RE-READING. skip means
      # the precondition does not APPLY -- no workflows, no remote, nested run, inside CI --
      # as opposed to `unknown`, which means it applies and could not be read. Nothing is
      # claimed either way, so there is nothing to report and a line here would print in
      # every local-only repo forever. The distinction only holds while `ok` is LOUD: if this
      # branch is silent and ok is silent too, "does not apply" and "checked and green"
      # collapse into the same output, which is what they used to do.
      :
      ;;
  esac

  # ---- fast, and the one that bit hardest: CI's stricter header form
  if [ -x tools/header_check.sh ]; then
    base="$(base_ref)"
    if [ -n "$base" ]; then
      gate "header_check --since $base (CI's form)" tools/header_check.sh --since "$base"
    else
      gap "no base ref to compare against" \
          "CI runs header_check --since <base>; pass one with --since <ref>"
    fi
  else
    gap "tools/header_check.sh is missing" "headers and build stamps are unchecked"
  fi

  # ---- THIS SCRIPT'S OWN SELFTEST, WHICH ONLY CI RAN, THREE TIMES OVER --------------
  #
  # The first line of this file says "everything CI will run, before the push instead of
  # after". That was FALSE for one specific suite: this script's own. CI discovers every
  # `tools/*.sh` advertising `--selftest` and runs it -- preflight.sh included -- while
  # preflight excluded ITSELF from that discovery to avoid recursing. So the cases that
  # police preflight ran only on the far side of a push.
  #
  # THE COUNT IS WHY THIS IS NOW A GATE RATHER THAN A THIRD COMMENT. It has produced a
  # local-green/CI-red three times, each recorded at the site that hit it and none of them
  # closing the hole:
  #   1. the must-run declaration case (3d below) -- "structural rather than bad luck"
  #   2. the session_currency wiring (~line 1454) -- "exactly the gap ai/MEMORY.md records"
  #   3. 2026-09-01, the CI-only assertion case, on the very commit adding a matrix leg
  # A gap documented at three separate sites and closed at none is not a known limitation,
  # it is an unfixed defect with good comments.
  #
  # IT DOES RECURSE, AND THE DEPTH GUARD IS THE WHOLE MECHANISM. The first version of this
  # gate carried a comment asserting "NO RECURSION -- --selftest exits before the main
  # flow". That was wrong and it forked 207 processes on the machine that ran it: selftest()
  # copies this file into a fixture and runs THE MAIN FLOW (see the two fixture cases near
  # the end of selftest), so main -> selftest -> main -> selftest is unbounded. The
  # exclusion this gate removes was load-bearing, and only reading selftest() shows why.
  #
  # SCAFFOLD_PREFLIGHT_INNER bounds it at depth 2: the outer run sets it, the fixture runs
  # inherit it, and they skip this gate. Terminating, and the inner runs still execute every
  # OTHER gate, which is what those fixture cases are actually asserting.
  #
  # `$0` RATHER THAN A LITERAL PATH, so a vendored copy tests the copy it is running from
  # rather than whatever happens to sit at tools/preflight.sh.
  if [ -n "${SCAFFOLD_PREFLIGHT_INNER:-}" ]; then
    :   # inner run: the outer one is already running this suite
  else
    gate "preflight's own selftest (CI discovers it; this flow used not to)" \
      env SCAFFOLD_PREFLIGHT_INNER=1 bash "$0" --selftest
  fi

  # ---- everything setup.sh --check already owns: scanners, headers, sync, archive
  if [ -x setup.sh ]; then
    # LABEL CHANGED (#265). It said "archive ceilings" and did not gate them: setup.sh's
    # archive block is deliberately ADVISORY (0.14.0 removed the hard gate on file length and
    # argued it out), so this printed [PASS] over a breached ceiling while naming that
    # ceiling in its own label. A label is a claim, and this one claimed coverage the gate
    # did not have. The ceilings are now gated separately, immediately below.
    gate "setup.sh --check (scanners, headers, drift)" ./setup.sh --check

    # ---- THE ARCHIVE CEILINGS, AS AN ACTUAL GATE (#265) --------------------------------
    #
    # session_archive.py has shipped `--exit-status` since 0.11.0, documented as "so a caller
    # can branch on the RESULT instead of grepping this tool's prose for a literal" -- and
    # the only caller was setup.sh's advisory block. Reported by an adopter with ai/MEMORY.md
    # 73 lines over its archive line, where preflight printed PASSED under a gate whose label
    # said "archive ceilings". Exactly the shape 1b-vii exists to catch, one level out: not a
    # --check with no caller, but a --check whose only caller cannot fail.
    #
    # OVER STAYS ADVISORY. BURST DOES NOT, and the distinction is the entire judgement here.
    # 0.14.0's argument was against failing a build on file LENGTH, and it still holds: a
    # file drifting past its archive line while you work is normal, and a gate that goes red
    # on it is a gate people route around. The BURST line is a different claim -- the tool's
    # own words are "a trim that stopped happening, not 'a bit over'" -- and it is reached
    # only by ignoring the advisory for a long time. That is a gate.
    #
    # exit 2 -> fail, exit 1 -> gap, exit 0 -> pass. THREE OUTCOMES, from the tool's own
    # exit code, never from its prose: grepping this tool's report for `[over]` is how the
    # worse state (`[BURST]`) went silent for three files in 0.13.0, and the check got
    # QUIETER as the breach got WORSE.
    archive_gate
  record_ignore_gate
  doc_currency_gate
  python_floor_gate
  runner_value_gate
  selftest_mode_gate
  else
    gap "setup.sh is missing" "the scanners and the drift check did not run"
  fi

  # ---- IS THE VENDORED SCAFFOLD FRESH ENOUGH TO TRUST?
  # tools/scaffold_version.sh has exited 1 on "behind" since it was written, and NOTHING
  # EVER CALLED IT. Preflight ran its --selftest -- proving the check works -- and never
  # ran the check. Measured 2026-08-16: localcoder sat two releases behind while the newer
  # release was the one titled "the stamp gate had the defect it was built to catch", so
  # the fix for a defect an adopter reported never reached the adopter, and four releases
  # were cut past the warning that said so.
  # ONE RELEASE OF SLACK, then it fails: upstream cutting a release must not redden every
  # adopter the same afternoon, because a gate that reddens on somebody else's schedule is
  # one people learn to push past. Two behind is a different claim -- a fix has been
  # available through a full release you chose not to take.
  if [ -x tools/scaffold_version.sh ]; then
    gate "vendored scaffold is not more than one release behind" \
         tools/scaffold_version.sh --gate
  else
    gap "tools/scaffold_version.sh is missing" "staleness of the vendored scaffold is unknown"
  fi

  # ---- the three setup.sh --check names as NOT covered. This is the whole gap #166 found.
  if [ -x tools/lint_python.sh ]; then
    # ONE IMPLEMENTATION OF "COULD NOT RUN", NOT TWO. This block used to hand-roll the
    # skip/pass/fail split for lint_python alone, keyed on its exit 2 — the idea was right
    # and it was the only tool that had it. gate() now understands exit 3 for every tool
    # (#188), so a bespoke copy here would be a second definition of the same rule, free to
    # disagree with the first. That is the shape this repo keeps finding and removing.
    gate "ruff, pinned (tools/lint_python.sh)" tools/lint_python.sh
  else
    gap "tools/lint_python.sh is missing" "the pinned lint did not run"
  fi

  # SHELL IS THE LANGUAGE THIS REPOSITORY IS ACTUALLY WRITTEN IN, and until 0.110.0 nothing
  # linted it. The only mention of shellcheck anywhere in the tree was a `disable=SC2086`
  # directive -- a suppression for a tool that never ran. On the day the gate was written it
  # found two errors, one of them a REAL latent bug in ci_status.sh that `bash -n` passes:
  # an unescaped `${{ ... }}` inside a double-quoted string, so bash printed `bad
  # substitution` INSTEAD of the message, in exactly the case that message exists to explain.
  if [ -x tools/shell_lint.sh ]; then
    gate "shellcheck, pinned (tools/shell_lint.sh)" tools/shell_lint.sh --check
  else
    gap "tools/shell_lint.sh is missing" "shell was not linted"
  fi

  # THE WORKFLOWS ARE CODE AND THEY SHIP TO EVERY ADOPTER. zizmor found a live template
  # injection here on 2026-09-21 -- `github.base_ref`, a branch name, interpolated straight
  # into a run: block -- and the same line was therefore live in four repositories. It was
  # found by a person running the tool by hand, once; nothing ran it on a schedule, and the
  # sweep the next day still missed one repo. Exit 3 is the expected answer on a machine
  # without zizmor and actionlint, which includes this one by standing rule.
  if [ -x tools/workflow_audit.sh ]; then
    gate "workflow audit, pinned (tools/workflow_audit.sh)" tools/workflow_audit.sh --check
  else
    gap "tools/workflow_audit.sh is missing" "the workflows were not audited"
  fi

  # LOOK WHERE THE ADOPTER ACTUALLY KEEPS ITS SUITE (#D-18). This runner is vendored into
  # every adopting project and only ever searched its own directory, tools/. An adopter
  # whose product lives elsewhere — Robiton/localcoder keeps its suite in tests/, because
  # tools/ there is THIS governance layer — got a gap, a green build, and an unaudited
  # product. Measured 2026-08-10: that repo had never once run its own 40-case behavioural
  # suite in CI, and the gap printed above a PASSED line for as long as anyone had looked.
  #
  # This is the instance fix, and it is deliberately a search rather than a config key.
  # The general fix is W-22 part three and D19: the adopter declares which gates MUST run
  # here and where they live, because a vendored runner cannot otherwise find a product
  # laid out any way but its own.
  # ---- THE SCAFFOLD SHIPS NO localcoder, SO IT AUDITS NONE (W-15, DEC-20).
  #
  # This is where the audit-suite discovery used to live, and where D-18 was found: the
  # search looked in tools/ and the suite was in tests/, so a forty-case suite had never run
  # in the repository that owned the product. Both the search and the suite are gone from
  # here — localcoder owns them now — and what replaces them is the assertion below, which
  # is stronger than either because it has no environment dependency at all.
  #
  # A GREP GATE, AND IT IS UNIVERSAL. Under the earlier shim design this had to be
  # conditional on `scaffold:owns-localcoder`. With no shim there is nothing to except: no
  # repository receives a `tools/localcoder` of any kind, ever, so the check is one rule
  # with no exemption list to drift.
  # NOT IN THE REPOSITORY THAT SHIPS localcoder, WHICH IS THE OBVIOUS CASE I MISSED.
  #
  # This file is VENDORED into every adopter, and the first version of this gate ran
  # everywhere — including Robiton/localcoder, where invoking the localcoder binary is not a
  # violation, it is the product. It went red there immediately.
  #
  # `scaffold:owns-localcoder` is the right key and this gives it a purpose again: the split
  # emptied OWNS_LOCALCODER_PATHS, so the marker had become vestigial. Its remaining meaning
  # is exactly this — "the rules about not shipping localcoder do not apply to the repo that
  # IS localcoder". Declared, never inferred.
  if grep -qE '^<!--[[:space:]]*scaffold:owns-localcoder[[:space:]]*-->[[:space:]]*$' \
       ai/STANDARDS.md 2>/dev/null; then
    echo "[PASS] no localcoder execution — not checked here: this repo SHIPS localcoder"
    PASSED=$((PASSED + 1))
    log_verdict "no localcoder execution" ok "exempt: scaffold:owns-localcoder"
  else

  # TWO THINGS THIS MUST NOT FLAG, both found by running it. `localcoder -->` is the
  # owns-localcoder MARKER in a fixture, and `echo "localcoder --doctor"` is the scaffold
  # TELLING A HUMAN what to install — which is the behaviour DEC-20 asks for, so a gate that
  # forbade it would forbid its own remedy. Comment and output lines are excluded; an
  # execution is a command, not a string.
  # SCAFFOLD-ONLY. THIS IS A RULE ABOUT OUR SOURCE, NOT ABOUT ANYONE ELSE'S PROJECT.
  #
  # DEC-20 says the SCAFFOLD does not invoke localcoder. An ADOPTER invoking it is the
  # product working as designed — a pre-write hook, a best-of-N wrapper and an attribution
  # wrapper all must call the binary, and this gate told them they may not use the thing
  # they installed.
  #
  # Worse, it fired on the leftovers the split ITSELF created: 0.36.x stops shipping
  # tools/localcoder and friends but deliberately does not delete them, so the upgrade left
  # the files in place AND added a gate that failed on them. An upgrade that cannot pass its
  # own gate immediately after running is the defect, not the adopter's tree.
  #
  # Reported from a real 0.36.2 adoption, which is the only place it could be seen: upstream
  # has no leftovers and no wrappers, so this gate is green in every repo we test in.
  # A FIXED /tmp PATH IS A SYMLINK TARGET. This wrote to /tmp/.w15hits, which is predictable
  # and lives in a world-writable directory: anyone with an account on the machine can
  # pre-create it as a symlink and the `>` redirect below truncates whatever it points at,
  # with this process's privileges. It also collides between concurrent runs -- and CI here
  # is SELF-HOSTED, where the machine and its /tmp persist between jobs and between repos,
  # which is the same "nothing may assume a fresh machine" lesson the mirror step learned.
  # mktemp with a template is the idiom this file already uses in four other places.
  #
  # CREATED BEFORE THE CHAIN, AND FAILING CLOSED. A first draft put the mktemp inside the
  # `elif` as `_w15="$(mktemp ...)" && grep ...`, which reads fine and is a fail-OPEN: if
  # mktemp ever failed, the condition went false and the else branch printed
  # "[PASS] no localcoder execution". A gate that reports PASS because it could not run is
  # the exact failure this file exists to prevent.
  _w15=""
  if is_upstream \
     && ! _w15="$(mktemp "${TMPDIR:-/tmp}/preflight-w15.XXXXXX")"; then
    echo "[FAIL] no localcoder execution — could not create a temporary file, so the check DID NOT RUN"
    FAILED="$FAILED no-localcoder-execution"
    log_verdict "no localcoder execution" failed "mktemp failed"
  elif ! is_upstream; then
    echo "[PASS] no localcoder execution (scaffold-only rule; not checked in an adoption)"
    PASSED=$((PASSED + 1))
    log_verdict "no localcoder execution" ok "adoption — rule is scaffold-scoped"
  elif grep -rInE '(\$ROOT|\$REPO|\.)/tools/localcoder"|(^|[^_a-zA-Z])localcoder (--[a-z]|")' \
       --include='*.sh' --include='*.py' --include='*.yml' \
       tools/ setup.sh sync-check.sh .github/workflows/ 2>/dev/null \
       | grep -v localcoder_footprint.py \
       | grep -vE ':[0-9]+: *(#|echo |printf |print\()' \
       | grep -vE ':[0-9]+:.*("""|'"'''"')' \
       | grep -vE ":[0-9]+: *[A-Za-z_]* *= *f?[\"']" > "$_w15" 2>/dev/null; then
    echo "[FAIL] the scaffold must not invoke the localcoder binary (W-15, DEC-20)"
    sed 's/^/       /' "$_w15"
    echo "       localcoder is a separate product. The scaffold reads its config and ships"
    echo "       the markers; it does not run it. --doctor tells a developer to install it."
    FAILED="$FAILED no-localcoder-execution"
    log_verdict "no localcoder execution" failed "$(wc -l < "$_w15") site(s)"
  else
    say_pass "no localcoder execution anywhere in the scaffold"
    PASSED=$((PASSED + 1))
    log_verdict "no localcoder execution" ok ""
  fi
  fi
  # ${_w15:-} NOT $_w15. This cleanup sits outside the OUTER guard — the one that skips the
  # whole gate in a repo that ships localcoder — so on that path _w15 is never assigned, and
  # `set -u` (line 376) turned an unset variable into "unbound variable" and killed preflight
  # six gates in. Green upstream, fatal in every adoption, which is the exact blast radius
  # this file has been bitten by before. Caught by re-running the sweep in localcoder rather
  # than trusting that a fix verified upstream travels.
  rm -f "${_w15:-}"; unset _w15 2>/dev/null || true

  # ---- THE WORKFLOWS WE SHIP MUST NOT PIN A DEPRECATED ACTION RUNTIME.
  #
  # `.github/workflows/scaffold-check.yml` is a PRODUCT_FILE. Whatever it pins runs in every
  # repository that took the scaffold, so a deprecated pin here is not one warning — it is a
  # permanent annotation on every run of every adopter, and one they cannot act on, because
  # WE chose the pin. Reported from the godsfall adoption the day it reached zero
  # annotations for the first time:
  #
  #   ##[warning]Node.js 20 is deprecated ... actions/checkout@v4 ... forced to run on
  #   Node.js 24
  #
  # This is A10's shape with a different owner. A10 was two of our own warnings describing
  # the intended end state, firing forever; the rule drawn from it — "a warning that always
  # fires is one people learn to filter out" — does not care who wrote the warning. The slot
  # a real annotation would occupy is occupied either way.
  #
  # WHY A FLOOR AND NOT "IS IT LATEST". Latest needs the network, and a gate that silently
  # degrades to a pass when offline is this repository's most-repeated defect. A declared
  # minimum major is checkable with no network, states a decision, and fails loudly when the
  # decision is reverted. It goes stale — deliberately: raising the floor is a change someone
  # makes and writes down, not something that happens to a tree overnight.
  #
  # SCOPED TO THE FILES WE SHIP, downstream as well as up. An adopter failing this has an
  # actionable answer ("run the upgrade"). Their OWN workflows are their own pins, and
  # failing an adopter's push over a choice we did not make is exactly the inversion the
  # context-budget gate was fixed for on 2026-08-11.
  # ---- A DECLARED PRODUCT DIRECTORY MUST EXIST.
  # `<!-- scaffold:product-dir <path> -->` widens selftest discovery beyond tools/. If the
  # path is wrong or the directory was renamed, discovery silently goes back to tools/ only
  # and a whole suite retires with nothing to notice — D-18's shape, and the same reason a
  # declared `scaffold:must-run` gate that is ABSENT fails rather than skipping.
  _missing="$(missing_product_dirs)"
  if [ -n "$_missing" ]; then
    echo "[FAIL] a declared product directory does not exist"
    for _d in $_missing; do echo "       $PRODUCT_DIR_MARK $_d"; done
    echo "       Selftest discovery would fall back to tools/ alone and say nothing."
    echo "       Fix the path in AGENTS.md, or remove the declaration."
    FAILED="$FAILED product-dir-missing"
    log_verdict "product dir" failed "$(printf '%s' "$_missing" | wc -w | tr -d ' ') missing"
  elif [ -n "$(declared_product_dirs)" ]; then
    say_pass "declared product dir(s) exist and are scanned: $(declared_product_dirs | tr '\n' ' ')"
    PASSED=$((PASSED + 1))
    log_verdict "product dir" ok "$(declared_product_dirs | tr '\n' ' ')"
  else
    say_pass "no product dir declared — selftest discovery is tools/ only"
    PASSED=$((PASSED + 1))
    log_verdict "product dir" ok "none declared"
  fi
  unset _missing _d 2>/dev/null || true

  _stale="$(stale_action_pins)"
  if [ -n "$_stale" ]; then
    echo "[FAIL] a shipped workflow pins an action below its floor ($ACTION_FLOORS)"
    for _s in $_stale; do echo "       $_s"; done
    echo "       These pins run in every adopting repository. Below the floor they emit a"
    echo "       deprecation annotation on every run, forever, that the adopter cannot fix."
    FAILED="$FAILED shipped-action-floor"
    log_verdict "shipped action floor" failed "$(printf '%s' "$_stale" | wc -w | tr -d ' ') pin(s)"
  else
    say_pass "shipped workflows pin actions at or above the floor ($ACTION_FLOORS)"
    PASSED=$((PASSED + 1))
    log_verdict "shipped action floor" ok ""
  fi
  unset _stale _s 2>/dev/null || true

  # ---- THE FOUR RESTATEMENTS OF THE ADOPTION MANIFEST STILL AGREE (#291, #294, #297).
  #
  # What an adoption receives is written down in four places — docs/ADOPTION_GUIDE.md step 3
  # (fresh), PRODUCT_FILES/MERGE_FILES/UNION_FILES (upgrade), the build.sh template in
  # setup.sh (what must not reach a deployment artifact), and adoption_check.sh's fixtures.
  # Nothing compared them, and all three drifted at once:
  #
  #   - `.githooks/` was on the upgrade list and absent from the guide, so a FRESH adoption
  #     never received it.
  #   - `.claude/` and `.agents/` were on the guide and absent from the upgrade list, so
  #     every hook fix this project shipped reached zero adopters through an upgrade.
  #   - build.sh excluded 6 of 20, so a CORRECTLY BUILT Splunk package carried tools/,
  #     .claude/ and setup.sh onto a production host.
  #
  # All three were found by an outside reviewer reading one real adoption. None was
  # reachable by anything in this file. UPSTREAM ONLY: it is a rule about what we ship.
  #
  # THE THREE SIGNALS, IN THAT COMBINATION. The first draft of this gate used
  # `[ -d overlays ] && [ -x tools/adoption_manifest.sh ]` — a fourth spelling of "are we
  # upstream" — and --selftest's drift pin failed it within the minute, exactly as the note
  # on the hook gate below predicts. The tool's presence is a separate precondition and is
  # tested as one.
  if is_upstream \
     && [ -x tools/adoption_manifest.sh ]; then
    _am="$(tools/adoption_manifest.sh --check 2>&1)"; _am_rc=$?
    if [ "$_am_rc" -eq 0 ]; then
      say_pass "the adoption manifest and its four restatements agree"
      PASSED=$((PASSED + 1))
      log_verdict "adoption manifest" ok ""
    else
      echo "[FAIL] the adoption manifest and its restatements have drifted"
      printf '%s\n' "$_am" | sed 's/^/       /'
      FAILED="$FAILED adoption-manifest"
      log_verdict "adoption manifest" failed "exit $_am_rc"
    fi
    unset _am _am_rc 2>/dev/null || true
  fi

  # ---- EVERY SHIPPED ai/ FILE DECLARES WHAT IT IS: A TEMPLATE, OR A REFERENCE (#293).
  #
  # `cp -r ai .` copies the whole directory into every adoption, and two of the files in it
  # were this repository's own engineering notes. `ai/PROVENANCE.md` tracked OUR upstream
  # pins under a `Project: ai-project-scaffold` header; `ai/STANDARDS_EVIDENCE.md` opened by
  # measuring "this repository and its development repo". An outside reviewer of a real
  # adoption read both as leftover noise and recommended deleting them. They were right
  # about the confusion and wrong about the fix: the rows and the stories are worth
  # shipping, they were simply never labelled.
  #
  # WHY A DECLARATION AND NOT A GREP. The obvious check — does the file name
  # `ai-project-scaffold`? — passes STANDARDS_EVIDENCE.md, whose self-reference is the
  # phrase "this repository". That is measuring the correlate rather than the property, a
  # mistake this project has made before and written down. Whether a file is a template or
  # a reference is a decision, so it is declared, and the gate checks the declaration
  # exists rather than trying to infer it. Adding a file to ai/ now costs one line and one
  # deliberate answer.
  #
  # A REFERENCE FILE MUST ALSO SAY SO TO A HUMAN. The marker satisfies the gate; the
  # sentence is what stops the next reviewer filing the same finding. Both are required.
  # UPSTREAM ONLY, for the same reason the templates gate below is. An adopter may add
  # their own file to ai/ and must not be failed by a rule about what WE ship.
  # Same three signals, same combination, for the same reason.
  # scaffold:gate-extract-begin shipped-ai-kind
  if is_upstream; then
    _kind_bad=""; _kind_unlabelled=""; _kind_leak=""
    # SHIPPED MEANS TRACKED, NOT PRESENT ON DISK.
    # This was `for _f in ai/*.md` — a DISK glob — and the gate's own invariant, two
    # paragraphs up, is about what WE SHIP. tools/session_journal.sh creates
    # ai/SESSION_JOURNAL.md on every session, .gitignore excludes it, and NOTHING writes
    # the kind marker into it. So the first session in any clone produced an unmarked,
    # untracked, never-shipped file and this gate hard-failed on it: a red preflight for
    # doing nothing wrong, on every adopter who has ever run a session. It did not show up
    # here because a past session had hand-added a marker to this machine's journal, which
    # is exactly how a shipped gate stays green for its author and red for everyone else.
    # git ls-files IS the definition of shipped. One call, prefiltered into a variable,
    # because a bash 3.2 loop over process substitution segfaults on this machine.
    # The grep re-creates the glob's ONE level — a git pathspec `*` would descend.
    _ai_shipped="$(git ls-files ai/ 2>/dev/null | grep '^ai/[^/]*\.md$')"
    if [ -z "$_ai_shipped" ]; then
      gap "shipped ai/ file kind: no tracked ai/*.md — NOT CHECKED" \
          "git ls-files returned nothing here. An empty list is not a clean bill."
      log_verdict "shipped ai/ file kind" gap "no tracked ai/*.md"
    else
    for _f in $_ai_shipped; do
      [ -f "$_f" ] || continue
      _k="$(sed -nE 's/^<!--[[:space:]]*scaffold:ai-file-kind[[:space:]]+([a-z]+)[[:space:]]*-->.*/\1/p' "$_f" | head -1)"
      case "$_k" in
        template) : ;;
        reference)
          grep -q 'This file is about the scaffold itself' "$_f" \
            || _kind_unlabelled="$_kind_unlabelled $_f" ;;
        *) _kind_bad="$_kind_bad $_f" ;;
      esac
    done
    # ---- A TEMPLATE THAT NAMES OUR OWN LAYOUT MUST BE STRIPPED BY THE ADOPTION GUIDE (#302).
    #
    # ai/BACKLOG.md carries `<!-- scaffold:session-log ../ai-project-scaffold-dev/ai/SESSION.md -->`
    # and SHOULD: our session log really does live in the -dev sibling and
    # session_currency.sh really does have to find it. The marker is correct here.
    #
    # The defect was that it TRAVELLED. `setup.sh --type` strips it, and adoption_check
    # asserts that. The adoption guide's MANUAL path — the only documented route for
    # adopting into existing code — did not, so every manual adoption inherited a path to a
    # directory it does not have and session_currency.sh HARD-FAILED exit 4 on the project's
    # first preflight. Found by an acceptance test on a real fresh adoption, not here.
    #
    # SO THE INVARIANT IS NOT "the file must not contain it" — that would break our own
    # repo for doing the right thing. It is: every `../` marker in a shipped template has a
    # corresponding strip step in the guide. Add such a marker and this gate tells you the
    # guide now owes you a line.
    for _f in $_ai_shipped; do
      [ -f "$_f" ] || continue
      _k="$(sed -nE 's/^<!--[[:space:]]*scaffold:ai-file-kind[[:space:]]+([a-z]+)[[:space:]]*-->.*/\1/p' "$_f" | head -1)"
      [ "$_k" = "template" ] || continue
      for _m in $(sed -nE 's|^<!--[[:space:]]*scaffold:([a-z-]+)[[:space:]]+\.\./.*|\1|p' "$_f"); do
        grep -q "scaffold:$_m" docs/ADOPTION_GUIDE.md 2>/dev/null \
          || _kind_leak="$_kind_leak $_f(scaffold:$_m)"
      done
    done
    if [ -n "${_kind_leak:-}" ]; then
      echo "[FAIL] a shipped template names a path outside the adopter's repo, and the"
      echo "       adoption guide never strips it:$_kind_leak"
      echo "       A \`../\` sibling in a scaffold: marker describes OUR layout. It travels on a"
      echo "       manual adoption and fails the adopter's first preflight (exit 4)."
      echo "       Fix: add a strip step to docs/ADOPTION_GUIDE.md step 3, as session-log has."
      FAILED="$FAILED shipped-ai-kind"
      log_verdict "shipped ai/ template leak" failed "$_kind_leak"
    fi
    if [ -n "$_kind_bad" ] || [ -n "$_kind_unlabelled" ]; then
      echo "[FAIL] a shipped ai/ file does not say whether it is a template or a reference"
      [ -n "$_kind_bad" ] && {
        echo "       undeclared:$_kind_bad"
        echo "       Add at column 0:  <!-- scaffold:ai-file-kind template -->"
        echo "                     or  <!-- scaffold:ai-file-kind reference -->"
        echo "       template  = the adopter fills it in. reference = it describes the scaffold."
      }
      [ -n "$_kind_unlabelled" ] && {
        echo "       reference, but says nothing to the reader:$_kind_unlabelled"
        echo "       A reference file must open with a note containing the sentence"
        echo "       'This file is about the scaffold itself' — the marker is for the gate,"
        echo "       the sentence is for whoever adopts this and wonders whose repo it means."
      }
      FAILED="$FAILED shipped-ai-kind"
      log_verdict "shipped ai/ file kind" failed "$_kind_bad$_kind_unlabelled"
    else
      say_pass "every shipped ai/ file declares template or reference"
      PASSED=$((PASSED + 1))
      log_verdict "shipped ai/ file kind" ok ""
    fi
    fi
    unset _kind_bad _kind_unlabelled _kind_leak _ai_shipped _k _f 2>/dev/null || true
  fi
  # scaffold:gate-extract-end shipped-ai-kind

  # ---- THE SHIPPED NARRATIVE FILES MUST STAY TEMPLATES, IN THE SCAFFOLD ONLY.
  #
  # setup.sh copies ai/SESSION.md, ai/MEMORY.md and ai/BACKLOG.md into every adopting
  # project. If this repository's own development history is written into them, every
  # adopter receives it. That is why ai-project-scaffold-dev exists.
  #
  # ACCIDENTALLY DELETED DURING W-15 AND RESTORED BY THE GATE ACCOUNTING. The split replaced
  # a region of this file and this block sat inside it. Nothing failed — a removed gate
  # cannot fail — and the only reason it came back is that DEC-18 requires naming which
  # gates went rather than observing a smaller number: the count came out at 21 against a
  # prediction of 22, and this was the difference. That is the second time this week the
  # habit has paid, and the first time it caught a mistake made in the same change.
  #
  # ONLY IN THE UPSTREAM REPO. An adopter's SESSION.md is SUPPOSED to have dated entries.
  if is_upstream; then
    _hist=""
    for _f in ai/SESSION.md ai/MEMORY.md ai/BACKLOG.md; do
      [ -f "$_f" ] || continue
      _n="$(grep -cE '^## 20[0-9]{2}-[0-9]{2}-[0-9]{2}' "$_f" 2>/dev/null || true)"
      [ "${_n:-0}" -gt 0 ] && _hist="$_hist $_f($_n)"
    done
    if [ -n "$_hist" ]; then
      echo "[FAIL] shipped ai/ files are templates, not our session log"
      echo "       dated entries found in:$_hist"
      echo "       setup.sh copies these into EVERY adopting project. Move the entries to"
      echo "       ai-project-scaffold-dev, which is the dogfood adopter."
      FAILED="$FAILED shipped-ai-templates"
      log_verdict "shipped ai/ templates" failed "dated entries in$_hist"
    else
      say_pass "shipped ai/ files are still templates (no dated entries)"
      PASSED=$((PASSED + 1))
      log_verdict "shipped ai/ templates" ok ""
    fi
  fi

  # ---- W-05: adopter context survives setup, upgrade and overlay application.
  # The claim "AI Scaffold preserves your context" is load-bearing for the product and was
  # tested only against a fixture the upgrader builds for itself. This runs a real
  # 0.24.0 -> current upgrade against a real adoption. ~20s; blocking, per W-05's done-when.
  if [ -x tools/context_survival.sh ]; then
    gate "context survival (W-05)" tools/context_survival.sh
  else
    gap "tools/context_survival.sh is missing" \
        "nothing proves an upgrade preserves adopter content"
  fi

  # ---- the localcoder context budget (W-10).
  # RUN THE TOOL ON THIS REPOSITORY, not only its selftest. Discovery below picks up
  # `--selftest` and would have gated the tool's own fixtures while never once measuring
  # the files it exists to measure — which is D-18's shape exactly: a check that is present,
  # green, and pointed at nothing. Advisory-free on purpose: the budget is a ratchet at a
  # number already reached, so a failure means prose came BACK, and that is a real result.
  # HARD UPSTREAM, ADVISORY IN AN ADOPTION — because 28 IS THIS REPOSITORY'S NUMBER.
  #
  # The budget is a ratchet at a level THIS repo had already reached (W-10), which makes it
  # a real result here: a failure means prose came back. It is not a fact about anyone
  # else. An adoption that leans hard on the local model SHOULD carry more policy than the
  # scaffold does — measured on one, localcoder drafted 16.1% of landed code at a 0%
  # correction rate, off exactly the role-split table and delegation policy this gate would
  # have told them to delete.
  #
  # Enforcing it downstream inverts the tool: it would fail preflight on arrival and demand
  # the removal of the thing that was working. `ai/SECURITY.md`'s rule is that a guard which
  # blocks legitimate work gets ripped out and then protects nothing, and a preflight that
  # is red on arrival is one people learn to skip — including for the gates that matter.
  #
  # Reported from a real 0.36.0 adoption before it upgraded, which is the only reason this
  # was caught before it reached anyone: the gate is green in every repo we test in.
  if [ -x tools/localcoder_footprint.py ]; then
    # THE SAME THREE SIGNALS as tools/scaffold_version.sh -> is_upstream_repo(), inlined
    # rather than sourced: that file runs its main flow at top level (cache reads, a network
    # call), so sourcing it for one predicate would fire all of it. A second copy of a rule
    # is exactly what this project keeps getting bitten by, so it is pinned by the selftest
    # case below, which asserts the two definitions still agree on this repository.
    if is_upstream; then
      gate "localcoder context budget" tools/localcoder_footprint.py
    elif _lf_out="$(tools/localcoder_footprint.py 2>&1)"; then
      say_pass "localcoder context budget (advisory here — 28 is upstream's number)"
      PASSED=$((PASSED + 1))
      unset _lf_out
    else
      # THE TOOL'S OWN WORDS, NOT JUST OURS (#277 audit). This branch named the budget and
      # not the sections over it, so the one actionable fact -- which sections -- was in
      # stdout and stdout went to /dev/null.
      echo "[ADVISORY] localcoder context budget — over the shipped 28-line default."
      printf '%s\n' "$_lf_out" | sed 's/^/           /' | head -8
      unset _lf_out
      echo "           NOT a failure in an adoption. That budget is the scaffold's own"
      echo "           ratchet, not a fact about your project: if you delegate heavily,"
      echo "           carrying more policy is the correct choice and this line is noise."
      echo "           Set your own with: tools/localcoder_footprint.py --budget <n>"
    fi
  else
    gap "tools/localcoder_footprint.py is missing" \
        "localcoder policy can grow back into the always-loaded files unnoticed"
  fi

  # ---- THE CANONICAL HOOK SET AND THE LIVE ONE MUST AGREE. IN THE SCAFFOLD ONLY.
  #
  # setup.sh installs .claude/settings.hooks.json into an adopter's settings.json. Before
  # that file existed, setup.sh carried a SECOND copy of the hooks in a heredoc; the copy
  # drifted to ONE of SIX commands and every project created without an existing
  # settings.json silently lost the session journal and correction capture. Nothing caught
  # it because nothing compared the two.
  #
  # This is a FAILURE, not a gap: unlike the wiring check below, both files are ours and
  # both are in the tree. An adopter's settings.json legitimately differs (they may have
  # removed a hook on purpose), so this runs only in the upstream repo — same guard the
  # shipped-templates gate uses.
  # THE THREE SIGNALS ARE overlays + OVERVIEW.md + mirror-sync.yml, IN THAT COMBINATION.
  # An earlier draft of this gate substituted settings.hooks.json for mirror-sync.yml as the
  # third, and --selftest's drift pin failed it within the minute: "a copy of
  # is_upstream_repo uses a different third signal". Two definitions of one rule is this
  # project's most repeated defect, and the pin exists precisely so a new gate cannot quietly
  # invent a fourth spelling of "are we upstream". The settings files are a separate
  # precondition and are tested separately.
  if is_upstream \
     && [ -f .claude/settings.hooks.json ] && [ -f .claude/settings.json ] \
     && command -v python3 >/dev/null 2>&1; then
    _hookdiff="$(python3 - <<'PYHOOKDIFF' 2>/dev/null
import json, io
def cmds(p):
    try: h = json.load(io.open(p, encoding="utf-8")).get("hooks", {}) or {}
    except Exception: return None
    return {c.get("command") for v in h.values() for g in v for c in g.get("hooks", [])}
a = cmds(".claude/settings.hooks.json"); b = cmds(".claude/settings.json")
if a is None or b is None: print("UNREADABLE")
elif a == b: print("OK")
else: print("DRIFT only-canonical=%d only-live=%d" % (len(a - b), len(b - a)))
PYHOOKDIFF
)"
    case "$_hookdiff" in
      OK)
        say_pass ".claude/settings.hooks.json matches the hooks we actually run"
        PASSED=$((PASSED + 1))
        log_verdict "canonical hooks" ok "" ;;
      UNREADABLE)
        echo "[FAIL] canonical hook set unreadable — one of the two settings files is not valid JSON"
        FAILED="$FAILED canonical-hooks"
        log_verdict "canonical hooks" failed "unreadable" ;;
      *)
        echo "[FAIL] .claude/settings.hooks.json and .claude/settings.json disagree ($_hookdiff)"
        echo "       setup.sh installs the CANONICAL file into every adopter. If they differ,"
        echo "       adopters get a hook set this repository does not run. Change hooks in"
        echo "       .claude/settings.hooks.json, then mirror them into .claude/settings.json."
        FAILED="$FAILED canonical-hooks"
        log_verdict "canonical hooks" failed "$_hookdiff" ;;
    esac
    unset _hookdiff
  fi

  # ---- SHARED BLOCKS ARE ONE BODY IN EVERY FILE THAT CARRIES THEM. IN THE SCAFFOLD ONLY.
  #
  # `# >>> shared:<name>` ... `# <<< shared:<name>` marks code that vendored tools carry
  # byte for byte instead of sourcing (report item 16: the upgrader replaces itself mid-run,
  # so a library is one more file to deliver in step). The upstream helpers drifted between
  # three copies and produced item 8; nothing compared them. The block names the files that
  # must carry it on a `# carried by:` line, so deleting it from one is a failure too, not
  # a smaller set that agrees.
  # Upstream only, like the canonical hooks: an adopter cannot fix a drift in our tools.
  if is_upstream && command -v python3 >/dev/null 2>&1; then
    _shdiff="$(python3 - <<'PYSHARED' 2>&1
import glob, re
blocks = {}
for f in sorted(glob.glob("tools/*.sh")):
    t = open(f, encoding="utf-8").read()
    for m in re.finditer(r"^# >>> shared:([\w-]+)\n.*?^# <<< shared:\1\n", t, re.S | re.M):
        blocks.setdefault(m.group(1), {})[f] = m.group(0)
bad = []
for name, copies in sorted(blocks.items()):
    bodies = set(copies.values())
    if len(bodies) > 1:
        # Name the minority: the body most copies share is the reference.
        # With no majority (two copies, one each) there is no minority to name: name all.
        counts = sorted((sum(1 for v in copies.values() if v == b), b) for b in bodies)
        common = counts[-1][1] if counts[-1][0] > counts[-2][0] else None
        bad.append("shared:%s differs in %s" % (name, ", ".join(f for f in sorted(copies) if copies[f] != common)))
    carried = re.search(r"^# carried by: (.+)$", next(iter(bodies)), re.M)
    if not carried:
        bad.append("shared:%s has no '# carried by:' line" % name)
        continue
    named = set(carried.group(1).split())
    missing = sorted(named - set(copies))
    if missing:
        bad.append("shared:%s is missing from %s" % (name, ", ".join(missing)))
print("\n".join(bad) if bad else "OK %d" % len(blocks))
PYSHARED
)"
    case "$_shdiff" in
      "OK 0") ;;
      OK*)
        say_pass "every shared block is identical in every file that carries it"
        PASSED=$((PASSED + 1))
        log_verdict "shared blocks" ok "" ;;
      *)
        echo "[FAIL] shared code has drifted:"
        printf '%s\n' "$_shdiff" | sed 's/^/       /'
        echo "       Edit one copy, then paste the whole block over the others."
        FAILED="$FAILED shared-blocks"
        log_verdict "shared blocks" failed "$(printf '%s' "$_shdiff" | head -1)" ;;
    esac
    unset _shdiff
  fi

  # ---- are the session hooks actually wired to the wrapper? ADVISORY, ON PURPOSE.
  # Shipping tools/session_hook.sh is not the same as wiring it: the upgrade deliberately
  # does not touch .claude/settings.json, which is the developer's client configuration.
  # So this REPORTS and names the one-command remedy rather than failing. A preflight that
  # is red on arrival in every adoption is one people learn to skip — including for the
  # gates that matter — which is this repository's own stated rule, and the hazard it
  # shipped to every adopter in 0.58.0 by forgetting it.
  if [ -x tools/session_hook.sh ] && [ -f .claude/settings.json ]; then
    # EXIT 2 IS "WIRED, BUT NOTHING RESTORES THE RULES AFTER COMPACTION": the lifecycle
    # hooks fire, so it takes the wired path, and the missing reminder is its own gap.
    # THE FINDING IS QUOTED, NOT GUESSED FROM THE EXIT CODE. Exit 2 meant only "no reminder"
    # until --check-wiring also learned to report a hook that resolves to a stale copy; a
    # fixed sentence here would have named the wrong problem and the wrong fix.
    _cw_out="$(tools/session_hook.sh --check-wiring 2>&1)" && _cw_rc=0 || _cw_rc=$?
    _cw_first="$(printf '%s\n' "$_cw_out" | sed -n 's/^    //p' | head -1)"
    if [ "$_cw_rc" -eq 2 ]; then
      gap "session hooks are wired, with a finding: ${_cw_first:-see --check-wiring}" \
          "tools/session_hook.sh --check-wiring names every finding and its fix"
    fi
    if [ "$_cw_rc" -eq 0 ] || [ "$_cw_rc" -eq 2 ]; then
      # WIRED IS NOT THE SAME AS FIRING. The wiring check reads settings.json; only the
      # run log says the client ever actually invoked it. Both are needed, and reporting
      # only the first is how a hook that is perfectly configured and silently broken
      # reads as healthy — which is the exact state four hooks on this machine were in
      # for months. Still a GAP, never a failure: preflight can legitimately run before
      # the first session-start of a fresh adoption.
      # THE CLOSEOUT'S OWN WORDS, NOT A SENTENCE WE INVENT OVER THEM (#275).
      #
      # This line read `--closeout >/dev/null 2>&1` and then printed "wired AND the last
      # start was recorded as HOOK_RAN" for every exit 0. `closeout` returns 0 for TWO
      # different states, and one of them is the opposite of that sentence: a repository
      # that declares `<!-- scaffold:hooks-unavailable ... -->` in AGENTS.md has NO hook
      # records at all and exits 0 because the gap is declared. Preflight reported the
      # declared escape hatch as a firing hook, in green, which is the exact shape of defect
      # this file exists to prevent: a verdict stronger than the evidence behind it.
      _co_out="$(tools/session_hook.sh --closeout 2>&1)" && _co_rc=0 || _co_rc=$?
      if [ "${_co_rc:-0}" -eq 0 ]; then
        case "$_co_out" in
          *"DECLARED UNAVAILABLE"*)
            echo "[PASS] session hooks DECLARED UNAVAILABLE — $(printf '%s' "$_co_out" \
                    | head -1 | sed 's/.*DECLARED UNAVAILABLE in [^ ]* — //')"
            echo "       a declared gap, not a firing hook: nothing here is recorded by a hook"
            PASSED=$((PASSED + 1))
            log_verdict "session hook wiring" ok "declared unavailable" ;;
          *)
            say_pass "session hooks are wired AND the last start was recorded as HOOK_RAN"
            PASSED=$((PASSED + 1))
            log_verdict "session hook wiring" ok "" ;;
        esac
        printf '%s\n' "$_co_out" | sed 's/^/       /' | head -4
        unset _co_out _co_rc
      else
        unset _co_out _co_rc
        # WIRED, AND HAS IT EVER FIRED AT ALL? (#264) --closeout asks about the MOST RECENT
        # start, which is the right question for "did it work this session" and the wrong one
        # for "has this client ever called us". An adopter found two repos with four days and
        # 1333 logged rows between them and ZERO session_hook:start -- reported here as an
        # advisory gap, exit 0, so a repository where no hook has ever run went green.
        #
        # ESCALATED ONLY WHEN THE LOG PROVES THE REPO HAS BEEN WORKED IN. A fresh adoption
        # legitimately has no start yet, and reddening there is the hazard 0.58.0 shipped;
        # --ever-fired returns 3 for "too early to tell" and 1 only when other tools have
        # written 50+ rows and the hook still has none. That is not a young repo, it is a
        # hook nobody is calling.
        # scaffold:gate-extract-begin ever-fired
        _ef_out="$(tools/session_hook.sh --ever-fired 2>&1)" && _ef_rc=0 || _ef_rc=$?
        if [ "${_ef_rc:-0}" -eq 1 ]; then
          echo "[FAIL] session hooks are wired and have NEVER fired in this repository"
          printf '%s\n' "$_ef_out" | sed 's/^/       /'
          FAILED="$FAILED session-hooks-never-fired"
          log_verdict "session hook wiring" failed "wired, never fired"
        elif [ "${_ef_rc:-0}" -eq 3 ] && printf '%s' "$_ef_out" | grep -q 'LINKED WORKTREE'; then
          # A LINKED WORKTREE GETS ITS OWN WORDS (#368). The generic text below says "not
          # firing", which is the wrong claim here: the hook fires in the main checkout, and
          # session_hook says where to look. Its message is passed through, not re-worded.
          gap "session hooks: this is a linked worktree — judge the hook from the main checkout" \
              "$(printf '%s\n' "$_ef_out" | grep -m1 "main checkout's log" | sed 's/^ *//')"
        else
          gap "session hooks are wired but the last start is not a recorded HOOK_RAN" \
              "wired and not firing — --closeout prints the last start record"
        fi
        unset _ef_out _ef_rc
        # scaffold:gate-extract-end ever-fired
      fi
    else
      gap "session hook wiring does not match the policy: ${_cw_first:-see --check-wiring}" \
          "a failed hook is indistinguishable from an absent one — tools/session_hook.sh --wire"
    fi
    unset _cw_rc _cw_out _cw_first
  fi

  # ---- KNOWN VULNERABILITIES IN THE DEPENDENCIES WE DECLARE.
  #
  # NOT WIRED THROUGH gate(). gate() has two outcomes and this check has three: scanned-clean,
  # scanned-and-found, and DID NOT SCAN. Collapsing the third into either of the others is the
  # precise defect this tool was written to avoid -- `ci_status.sh` reported "no alerts" for
  # months across three repositories where every alert feature was switched off, because zero
  # and not-enabled print identically if you only look for a number.
  #
  # Today it exits 3 here: the scaffold declares no runtime dependency, so there is no
  # lockfile to read. That is a GAP, and it must read as one. The day health-app enables
  # Gradle dependency locking, the same gate starts doing real work with no edit.
  #
  # FINDINGS ARE ADVISORY AT PREFLIGHT, STRICT AT RELEASE -- the same split provenance_check
  # uses. A CVE published overnight should not turn somebody's push red on a morning they
  # changed a comment; it should absolutely stop a release.
  #
  # --strict, AND THE DOWNGRADE HAPPENS HERE. `--check` already turns findings into exit 0,
  # so calling it made the advisory branch below unreachable: a scan WITH findings printed
  # "[PASS] ... no known vulnerabilities" (CONTROL, 2026-09-23). --strict keeps 1 distinct,
  # and this case decides what 1 means at preflight.
  # scaffold:gate-extract-begin dependency-audit
  if [ -x tools/dependency_audit.sh ]; then
    _da_out="$(tools/dependency_audit.sh --strict 2>&1)"; _da_rc=$?
    case "$_da_rc" in
      0) say_pass "dependencies: no known vulnerabilities (tools/dependency_audit.sh)"
         PASSED=$((PASSED + 1)); log_verdict "dependency audit" ok "" ;;
      3) gap "dependency audit DID NOT RUN — $(printf '%s' "$_da_out" | head -1 | sed 's/^dependency_audit: //')" \
             "a skip is not a pass; tools/dependency_audit.sh --check says what is missing" ;;
      1) echo "[!]    dependencies: known vulnerabilities reported (advisory here, strict at release)"
         printf '%s\n' "$_da_out" | sed 's/^/       /' | head -14
         log_verdict "dependency audit" ok "findings reported, advisory" ;;
      *) gap "dependency audit exited $_da_rc — neither a result nor a skip" \
             "$(printf '%s' "$_da_out" | head -1)" ;;
    esac
    unset _da_out _da_rc
  fi
  # scaffold:gate-extract-end dependency-audit

  # ---- HOW MUCH DELEGABLE PYTHON LANDED WITH NO DRAFT ROW (localcoder#201).
  #
  # ADVISORY BY CONSTRUCTION -- `note`, not `gate`. The instruments in localcoder all measure
  # what the local model DID; none measured what it was never asked to do, so a project could
  # land hundreds of policy-eligible lines and every report stayed green. Measured 2026-09-01:
  # 576 delegable lines in localcoder and 278 here in one week, 0 drafted in both.
  #
  # EXIT 3 IS PRINTED, NOT SWALLOWED. "No draft log here" is the honest answer for an adopter
  # with no localcoder, and it must not render as 0% or as silence -- a missing instrument
  # reading as a clean result is the defect this file has the most comments about.
  if command -v localcoder-history >/dev/null 2>&1; then
    # AN OLD localcoder ON PATH IS "NOT MEASURED", NOT A RESULT. argparse answers an unknown
    # flag with `usage: ...` on stderr and exit 2, and the first run of this printed that
    # usage block where the number belongs -- a tool's error text rendered as its verdict,
    # which is precisely what this note was added to expose elsewhere.
    _ds_out="$(localcoder-history --delegation-share 2>&1 | head -1)"; _ds_rc=$?
    case "$_ds_out" in
      usage:*) note "delegation share NOT MEASURED — the localcoder-history on PATH has no --delegation-share" \
                    "it needs localcoder 1.7.0 or newer; nothing here is a percentage" ;;
      "")      note "delegation share NOT MEASURED — localcoder-history produced no output" ;;
      *)       note "$_ds_out" ;;
    esac
    unset _ds_out _ds_rc
  fi

  # ---- the SBOM's dependency claim still holds, where a project ships one.
  # Discovered, not assumed: no tools/sbom.py means nothing to say. It runs here as well as
  # at release time because a dependency arrives in the commit that adds the import, and
  # finding out at release is finding out after the review.
  if [ -x tools/sbom.py ]; then
    gate "SBOM dependency claim (tools/sbom.py --check)" tools/sbom.py --check
  fi

  # ---- CHANGELOG.md still matches the tags it is derived from.
  # Same contract as the status block, and the same reason it is generated rather than
  # written: a hand-maintained changelog goes stale exactly like the status table did, and
  # faster, because nobody reads it during the release they are cutting. A repository with
  # no CHANGELOG.md says nothing; one with no tags is exit 3, not a failure.
  if [ -f CHANGELOG.md ] && [ -x tools/changelog.sh ]; then
    gate "CHANGELOG.md matches the tags (tools/changelog.sh --check)" tools/changelog.sh --check
  fi

  # ---- the derived status block is still what a fresh derivation would produce.
  # SHIPPED IN 0.58.0 AND WIRED INTO NOTHING UNTIL NOW, which made it the very defect it was
  # written to cure. The whole argument for status_block.sh was that a stale table should be
  # a GATE RESULT rather than something a reader has to notice — and for three releases no
  # gate ran it. Its --selftest was picked up by discovery below, so the tool proved its own
  # fixtures green while the file it exists to police was never once compared.
  # That is D-18 exactly: present, green, pointed at nothing.
  #
  # NOT APPLICABLE IS NOT A FAILURE. A repo that declares no block has nothing to check and
  # says nothing. A file that CARRIES the markers with no generator on disk is the reverse —
  # a block claiming to be derived that nothing can re-derive — and that is a gap.
  _sb_file="${STATUS_BLOCK_FILE:-ai/BACKLOG.md}"
  if grep -q '<!-- scaffold:status-begin -->' "$_sb_file" 2>/dev/null; then
    if [ -x tools/status_block.sh ]; then
      gate "status block is current (tools/status_block.sh --check)" tools/status_block.sh --check
    else
      gap "$_sb_file carries a derived status block and tools/status_block.sh is missing" \
          "the block says it is generated; nothing here can regenerate or verify it"
    fi
  fi

  # IS THE RECORD BEHIND THE RELEASES? The mirror of the unreleased-commits warning: that one
  # says a fix nobody can install exists, this one says a release nobody wrote down shipped.
  #
  # A GATE, NOT A println. The first version of this wiring was a conditional `echo` in the
  # summary, and `--selftest` failed it as "a tool ships --check and no preflight gate calls
  # it (selftest-green, unused)" -- this script's own rule that a selftest proves a tool
  # WORKS and only a call here proves it RUNS. Local preflight passed at 37 gates while CI
  # went red, because preflight excludes itself from its own discovery, so that case runs
  # ONLY in CI. Exactly the gap ai/MEMORY.md records for `preflight.sh --selftest`.
  #
  # IT DOES NOT BLOCK: `--check` exits 0 even when the record is behind (exit 1 needs
  # --strict), so this reports on every run and fails nobody's push. Whether the RELEASE gate
  # should be strict is a separate judgement and is not made here.
  #
  # THE COST OF NOT HAVING IT, measured 2026-08-19 on Robiton/localcoder: ELEVEN tags in one
  # day, through 44 green gates in this very script, with the newest session entry dated the
  # day before. Every SESSION.md reference in this file was TEMPLATE detection -- "is this
  # still the unmodified stub" -- and none asked whether it was CURRENT, so the AGENTS.md
  # rule to checkpoint at milestones had been unenforced since it was written.
  if [ -x tools/session_currency.sh ]; then
    # `--check` PASSED EXPLICITLY, though it is the default. Case 1b-vii matches the literal
    # `<tool> --check` in this file, and relying on the default made the call invisible to it
    # -- a gate that runs while the coverage check reports it unused.
    gate "session record is current (tools/session_currency.sh --check)" \
         tools/session_currency.sh --check
  fi

  # HAVE THE SOURCES WE BORROWED FROM MOVED? Same shape as session currency above and wired
  # for the same reason: this tool ships --check, and case 1b-vii fails a tool that ships
  # --check with no gate calling it. `--check` PASSED EXPLICITLY, because the matcher looks
  # for the literal `<tool> --check` and the default is invisible to it.
  #
  # NON-BLOCKING BY CONSTRUCTION, and here that is not a preference. An upstream repository
  # moving is the NORMAL case -- other people push daily -- so a blocking version would be
  # red at a completely normal moment, which is #241 in this tracker. `--check` exits 0 and
  # reports; exit 1 needs --strict, which belongs to a scheduled review, not to a push.
  #
  # IT DEGRADES RATHER THAN FAILING: no gh, or no network, and it prints the rows it has and
  # says it could not ask. A registry with no reader is the thing this replaces.
  if [ -x tools/provenance_check.sh ] && [ -f ai/PROVENANCE.md ]; then
    gate "borrowed sources (tools/provenance_check.sh --check)" \
         tools/provenance_check.sh --check
  fi

  # DID ANYTHING ACTUALLY AUDIT? Same wiring reason as the two gates above: this tool ships
  # --check, and case 1b-vii fails a tool that ships --check with no gate calling it. The
  # literal `<tool> --check` is what the matcher looks for.
  #
  # LOCALLY THIS IS A GAP, AND THAT IS THE HONEST ANSWER. The question it asks is "did ANY
  # leg of the fan-out produce a verdict", and one machine is not a fan-out. So it runs here
  # only when leg reports are actually present, and otherwise says it could not tell --
  # rather than passing, which would be a green built from an absence, or failing, which
  # would redden every local push for a condition no local run can create.
  if [ -x tools/audit_coverage.sh ]; then
    if [ -d .audit-coverage ]; then
      gate "audit coverage (tools/audit_coverage.sh --check)" \
           tools/audit_coverage.sh --check .audit-coverage
    else
      gap "no leg reports present (tools/audit_coverage.sh --check)" \
          "one machine is not a fan-out; CI's aggregating job is the only place this is answerable"
    fi
  fi

  # ---- every tool selftest, DISCOVERED exactly as CI discovers them.
  # SELF-EXCLUDED, OR THIS RECURSES: preflight advertises --selftest, its selftest runs the
  # gates, and the gates run every selftest. The exclusion is by resolved path, not by name,
  # so a copy under another name still cannot re-enter.
  run_selftests || true

  # ---- coverage: has CI grown a gate this file does not know about?
  local cov_out cov_rc=0
  cov_out="$(coverage 2>&1)" || cov_rc=$?
  if [ "$cov_rc" -eq 0 ]; then
    say_pass "coverage — CI invokes no tool this script skips"
    PASSED=$((PASSED + 1))
  elif [ "$cov_rc" -eq 3 ]; then
    gap "coverage could not be verified — no $WORKFLOW in this repo" \
        "preflight may be running a different set from your CI, and cannot tell"
  else
    echo "[FAIL] coverage — CI invokes a tool this script skips"
    printf '%s\n' "$cov_out" | grep -A2 '\[GAP\]' | sed 's/^/       /'
    FAILED="$FAILED coverage"
  fi

  # ---- IS A RELEASE DUE? ADVISORY, NEVER A FAILURE ------------------------------------
  #
  # A repository is pushed many times per release, so failing a push because a release is due
  # would train people to bypass this gate — which is precisely how the prose release
  # checklist in ai/PLANNING.md stopped being read. It reports; the maintainer decides.
  #
  # THE COST OF NOT REPORTING IT, measured 2026-08-14: 9 unreleased product commits here and
  # 26 in Robiton/localcoder, including `ci_status.sh` having never once reported a red CI.
  # `scaffold_upgrade.sh` resolves an adopter's target with `gh release view`, so every one of
  # those fixes was unreachable by every adopter — and one of those adopters is this
  # programme's primary review control, which reviews each tagged release.
  if [ -x tools/release_status.sh ]; then
    echo ""
    tools/release_status.sh 2>&1 | sed -n '/\[!\]/,$p' | sed 's/^/  /' | head -8
  fi

  # ---- THE DECLARED MUST-RUN GATES. ACTUALLY RUN THEM, INCLUDING ON A RED RUN.
  #
  # MOVED ABOVE THE SUMMARY ON 2026-09-01 (#259). These gates used to sit BELOW the first
  # `if [ -n "$FAILED" ]; then ... return 1`, which meant that on any run where another gate
  # had already failed, the adopter's own declared suite DID NOT RUN -- and was not listed as
  # skipped either, because GAPS is only appended by the skip helpers and these never got as
  # far as being skipped. The one condition under which you most want the product suite --
  # something else is already broken -- was exactly the condition under which it was dropped.
  #
  # AGENTS.md: "A declared gate that does not run is a FAILURE, whatever the reason." The
  # reason here was our own control flow. Reported by an adopter, and it is the FOURTH time
  # this mechanism has failed in a new way (never called; called after the only $FAILED
  # check; verdict discarded; and now not reached on a red run) -- each fix landing one layer
  # below the last, which is why this one moves the call rather than adding another check
  # after it.
  #
  # THIS WAS A PRINTED CLAIM WITH NOTHING BEHIND IT, in the file that exists to prevent
  # exactly that. `MUST_RUN` was parsed from AGENTS.md, and the verdict below printed
  # "MUST-RUN gates declared in AGENTS.md, ALL OF WHICH RAN" — inside the PASSED branch, so
  # the sentence appeared precisely when nothing had checked. `must_gate()` was defined,
  # documented, covered by three selftest cases, and called from NOWHERE but those cases.
  #
  # Measured in Robiton/localcoder on 2026-08-12: `tests/audit_localcoder.sh` was declared
  # must-run and failing (version-files-agree: `version` said 0.22.0, `pyproject.toml` said
  # 0.21.0, so an install reported the wrong one). preflight printed "all of which ran" and
  # PASSED. CI caught it after the push, which is the thing preflight exists to prevent.
  #
  # D-18's shape, inside the mechanism built for D-18, with a sentence asserting the
  # opposite. The selftest cases were not wrong — they proved must_gate() behaves correctly
  # when called. Nothing asserted that it is called, because "is this function reachable"
  # is not a property a unit test of the function can have.
  if [ -n "$MUST_RUN" ]; then
    while IFS= read -r _mr; do
      [ -n "$_mr" ] || continue
      must_gate "$_mr (declared must-run)" "$_mr"
    done <<MUSTRUN_EOF
$MUST_RUN
MUSTRUN_EOF
    unset _mr
  fi
  _MUSTRUN_FAILED=""
  case "$FAILED" in *"(declared must-run)"*) _MUSTRUN_FAILED=1 ;; esac

  echo ""
  echo "-------------------------------------------------------------------"
  # NAME WHAT THIS DID NOT DO. "All checks passed" is a statement about the checks that ran,
  # and reading it as a statement about the push is exactly the mistake that makes a partial
  # gate worse than none.
  echo "NOT COVERED HERE, by design:"
  echo "  - anything needing Ollama or a network (the full localcoder audit, the eval)"
  # CONDITIONAL SINCE #259. This line is a standing claim that the adopter's suite is out of
  # scope -- and in a repository that DECLARES scaffold:must-run it is simply false: the
  # suite ran, as a gate, a few lines above. Printing it unconditionally told a reader the
  # opposite of what had just happened, and read as if the omission were deliberate on
  # exactly the runs where the gates had been silently dropped.
  if [ -n "$MUST_RUN" ] && [ -z "$MUST_RUN_SKIPPED" ]; then
    echo "  - (not your test suite — this repo declares scaffold:must-run, so it ran above)"
  else
    echo "  - your project's own test suite — run it separately; this is the scaffold's gate"
  fi
  echo "  - the CI steps with no tool behind them (tools/preflight.sh --coverage lists them)"
  if [ -n "$GAPS" ]; then
    echo ""
    # "ON THIS MACHINE" WAS THE WRONG FRAME (#258). ruff missing is a machine gap -- install
    # it and the gate runs. session_currency on a repo that never tags is a REPOSITORY gap:
    # nothing anyone installs will make it fire, ever. Both printed under this heading, so
    # the permanent one looked like the temporary one. The heading no longer asserts a cause;
    # each tool says its own, which is the only place the difference is actually known.
    echo "DID NOT RUN (each line says why — some are this machine, some are this repo):"
    printf '%s' "$GAPS" | tr '|' '\n' | sed '/^$/d; s/^/  - /'
  fi
  echo ""
  if [ -n "$FAILED" ]; then
    echo "PREFLIGHT FAILED:$FAILED"
    echo "Fix all of them before pushing — CI stops at the first, so it will only show you one."
    if [ -n "${_MUSTRUN_FAILED:-}" ]; then
      echo "A gate the repository DECLARED it cannot go green without has failed."
    fi
    log_verdict "preflight" FAIL "sha=$(preflight_head_sha) $(printf '%s' "$FAILED" | wc -w | tr -d ' ') gate(s)"
    return 1
  fi
  # ---- AND ACT ON WHAT THEY SAID. THE GATE RAN AND ITS VERDICT WAS DISCARDED.
  #
  # D-18's shape a THIRD time, one layer deeper than the last fix, and found the same way:
  # by a release going out wrong. v0.16.0 fixed "must_gate is never called" by adding the call
  # — and put it AFTER the `if [ -n "$FAILED" ]` branch above, which is the only place $FAILED
  # is ever consulted. So from that fix until now, a declared must-run gate ran, printed
  # [FAIL], set $FAILED, and preflight printed PREFLIGHT PASSED underneath it.
  #
  # MEASURED IN Robiton/localcoder ON 2026-08-15, and it is the same trigger as last time:
  # `tests/audit_localcoder.sh` failed `version-files-agree` (`version` 0.39.0 against
  # `pyproject.toml` 0.38.0, so an install reports the wrong release). preflight said PASSED,
  # the release was tagged and published, and the tag installs under the OLD version string.
  #
  # The previous fix's selftest case greps the main flow to prove must_gate is CALLED. That
  # was the right lesson from the wrong altitude: being called is not the property that
  # matters, being ACTED ON is. The case below now runs a fixture whose must-run gate exits 1
  # and asserts preflight exits non-zero.
  # RETAINED AS A DISTINCT MESSAGE, NOT A DISTINCT BRANCH. With the gates moved above the
  # summary, the first $FAILED branch now catches everything -- but "a scaffold gate failed"
  # and "a gate this repository declared it cannot go green without failed" are different
  # findings, and collapsing them would lose the second. The first branch prints this line
  # when a must-run gate is among the failures.

  # NAME THE MUST-RUN SET, DO NOT JUST COUNT IT (D18, D19). "18 gates, and I could not say
  # which eighteen" is the sentence that found D-18 after three rounds of reading the same
  # gap as noise. A count is a single number standing in for a set; the habit that catches
  # the next D-18 is being able to name the members, so the verdict names the ones the
  # repository declared it cannot go green without.
  if [ -n "$MUST_RUN_SKIPPED" ]; then
    # SAY IT, because a gate that stopped running is exactly what this file exists to catch.
    echo "MUST-RUN gates declared in AGENTS.md, DELIBERATELY NOT RUN HERE:"
    printf '%s\n' "$MUST_RUN_SKIPPED" | sed '/^$/d; s/^/  - /'
    echo "  This is an adoption FIXTURE (SCAFFOLD_ADOPTION_FIXTURE=1). The question here is"
    echo "  whether the SCAFFOLD's gates work inside an adoption; the adopter's own suite is"
    echo "  run by the adopter's own job, and running it in each fixture put it three times"
    echo "  in one push — and would have blamed the scaffold for an adopter's failing test."
  elif [ -n "$MUST_RUN" ]; then
    echo "MUST-RUN gates declared in AGENTS.md, each run as a gate above:"
    printf '%s\n' "$MUST_RUN" | sed '/^$/d; s/^/  - /'
  else
    echo "No must-run gates declared in AGENTS.md, so every gate here was free to skip."
    echo "  Declare the repository's own test suite with, at column 0:"
    echo "    <!-- scaffold:must-run <path> -->"
  fi
  echo ""
  _ngaps="$(printf '%s' "$GAPS" | tr -cd '|' | wc -c | tr -d ' ')"
  echo "PREFLIGHT PASSED — $PASSED gate(s), $_ngaps did not run (listed above). Push."
  [ "${VERBOSE:-0}" = 1 ] || echo "  The $PASSED passes are not printed; --verbose lists them."
  log_verdict "preflight" ok "sha=$(preflight_head_sha) $PASSED gate(s)"
  return 0
}

list_gates() {
  echo "preflight runs, in this order:"
  echo "  1. header_check.sh --since <base>          CI's stricter form; a bare run is weaker"
  echo "  2. setup.sh --check                        scanners, headers, archive ceilings"
  echo "  3. tools/lint_python.sh                    ruff at the pinned version"
  echo "  4. tools/adoption_check.sh                 every gate, inside a synthetic adoption"
  echo "  5. every tools/* --selftest                discovered, not listed"
  echo "  6. --coverage                              CI grew a gate this file does not run?"
}

usage() {
  echo "usage: tools/preflight.sh [--allow-dirty] [--ci-unresolved-ok] [--since <ref>]"
  echo "       tools/preflight.sh --list | --coverage | --selftest"
  echo ""
  echo "Run it AFTER git commit and BEFORE git push."
  echo "Exit: 0 all gates passed · 1 a gate failed · 2 could not run · 3 dirty tree"
}

# ---------------------------------------------------------------- selftest
selftest() {
  # FIXTURES RUN INSIDE A GUARDED ROOT (tools/fixture_guard.sh). Later mktemps land inside it,
  # and a git on PATH refuses any write outside it. The guard exists because a failed mktemp
  # once let a selftest run git init and commit in the real repo.
  . "$(dirname "${BASH_SOURCE[0]}")/fixture_guard.sh" || { echo "preflight: tools/fixture_guard.sh is missing; refusing to build fixtures" >&2; exit 1; }
  fixture_root FG_ROOT; trap fg_cleanup EXIT
  local pass=0 fail=0 tmp rc out
  echo "preflight selftest — a gate list that drifts from CI is the defect, so that is tested"
  ok()  { echo "  ok    $1"; pass=$((pass + 1)); }
  bad() { echo "  FAIL  $1"; fail=$((fail + 1)); }

  # 1. Coverage passes on this repo as shipped.
  if coverage >/dev/null 2>&1; then
    ok "--coverage is clean: CI invokes nothing this script skips"
  else
    bad "--coverage failed on the repo as shipped: $(coverage 2>&1 | grep -m1 GAP)"
  fi

  # 1q. QUIET BY DEFAULT (CONTROL, 2026-09-23). A pass is counted and not printed; a skip,
  #     a failure and the count still print; --verbose prints every pass. Run through gate()
  #     itself rather than a copy of its branches, in a directory with no run log to write.
  local _qd _qout
  _qd="$(mktemp -d "${TMPDIR:-/tmp}/preflight-q.XXXXXX")" || { echo "preflight: mktemp failed; stopping" >&2; exit 1; }
  _q() { ( cd "$_qd" && VERBOSE="$1" HEARTBEAT_AFTER=999 HEARTBEAT_EVERY=999 bash -c \
             "$(declare -f _heartbeat_wait log_verdict salient_then_tail gate say_pass); \
              PASSED=0; FAILED=''; GAPS=''; \
              gate 'good gate' true; gate 'unsure gate' sh -c 'exit 3'; gate 'bad gate' false; \
              echo \"PASSED=\$PASSED FAILED=[\$FAILED]\"" 2>&1 ); }
  _qout="$(_q 0)"
  if ! printf '%s' "$_qout" | grep -q '\[PASS\] good gate' \
     && printf '%s' "$_qout" | grep -q '\[SKIP\] unsure gate' \
     && printf '%s' "$_qout" | grep -q '\[FAIL\] bad gate' \
     && printf '%s' "$_qout" | grep -q 'PASSED=1 FAILED=\[ bad gate\]'; then
    ok "quiet by default: a pass is counted, not printed; a skip and a failure still print"
  else
    bad "quiet mode: $(printf '%s' "$_qout" | tr '\n' ' ' | cut -c1-200)"
  fi
  _qout="$(_q 1)"
  if printf '%s' "$_qout" | grep -q '\[PASS\] good gate'; then
    ok "--verbose prints every pass"
  else
    bad "--verbose did not print the pass: $(printf '%s' "$_qout" | tr '\n' ' ' | cut -c1-200)"
  fi
  rm -rf "$_qd"; unset -f _q

  # 1r. THE RECORD IS NEVER IGNORED (Brian, 2026-09-25: do the archives come down on a pull?).
  #     They do only if git can see them. An ignored archive is also invisible to the dirty-tree
  #     precondition, so nothing else would ever say so. The real gate runs, via declare -f, in
  #     throwaway repos: an archive pattern with no archive yet, a force-added archive that the
  #     pattern still matches, a live file, and a clean .gitignore that must stay green.
  local _rd _rout
  _rd="$(mktemp -d "${TMPDIR:-/tmp}/preflight-ri.XXXXXX")" || { echo "preflight: mktemp failed; stopping" >&2; exit 1; }
  _ri() { ( cd "$_rd/$1" && bash -c "$(declare -f say_pass log_verdict record_ignore_gate); \
             VERBOSE=1; PASSED=0; FAILED=''; record_ignore_gate; echo \"FAILED=[\$FAILED]\"" 2>&1 ); }
  _mkri() {
    mkdir -p "$_rd/$1/ai"; : > "$_rd/$1/ai/STANDARDS.md"; : > "$_rd/$1/ai/SESSION.md"
    printf '%s\n' "$2" > "$_rd/$1/.gitignore"
    ( cd "$_rd/$1" && git init -q . )
  }
  _mkri clean 'ai/SESSION_JOURNAL.md'
  _mkri future 'ai/*_ARCHIVE.md'
  _mkri forced 'ai/*ARCHIVE*'
  printf '# old\n' > "$_rd/forced/ai/SESSION_ARCHIVE.md"
  ( cd "$_rd/forced" && git add -f ai/SESSION_ARCHIVE.md )
  _mkri live 'ai/BACKLOG.md'
  _mkri other 'ai/DECISIONS_ARCHIVE_2025.md'
  printf '# old\n' > "$_rd/other/ai/DECISIONS_ARCHIVE_2025.md"
  _rout="$(_ri clean)"
  case "$_rout" in *'FAILED=[]'*) ok "record-ignore: a .gitignore that hides only the journal is green" ;;
    *) bad "record-ignore: clean repo went red: $(printf '%s' "$_rout" | tr '\n' ' ' | cut -c1-200)" ;; esac
  _rout="$(_ri future)"
  case "$_rout" in *'ai/BACKLOG_ARCHIVE.md'*'.gitignore:1:ai/*_ARCHIVE.md'*'FAILED=[ record-ignored]'*)
      ok "record-ignore: an archive pattern fails before any archive exists, naming the rule" ;;
    *) bad "record-ignore: archive pattern not caught: $(printf '%s' "$_rout" | tr '\n' ' ' | cut -c1-200)" ;; esac
  _rout="$(_ri forced)"
  case "$_rout" in *'ai/SESSION_ARCHIVE.md'*'FAILED=[ record-ignored]'*)
      ok "record-ignore: a force-added archive still fails while the pattern matches it" ;;
    *) bad "record-ignore: force-added archive hid the pattern: $(printf '%s' "$_rout" | tr '\n' ' ' | cut -c1-200)" ;; esac
  _rout="$(_ri live)"
  case "$_rout" in *'ai/BACKLOG.md'*'FAILED=[ record-ignored]'*) ok "record-ignore: an ignored live record file fails" ;;
    *) bad "record-ignore: ignored ai/BACKLOG.md not caught: $(printf '%s' "$_rout" | tr '\n' ' ' | cut -c1-200)" ;; esac
  _rout="$(_ri other)"
  case "$_rout" in *'ai/DECISIONS_ARCHIVE_2025.md'*'FAILED=[ record-ignored]'*) ok "record-ignore: a non-standard archive on disk is checked too" ;;
    *) bad "record-ignore: non-standard archive not caught: $(printf '%s' "$_rout" | tr '\n' ' ' | cut -c1-200)" ;; esac
  rm -rf "$_rd"; unset -f _ri _mkri

  # 1z. SHIPPED MEANS TRACKED. The shipped-ai-kind gate used a DISK glob over ai/*.md, and
  #     tools/session_journal.sh writes an ai/SESSION_JOURNAL.md that .gitignore excludes and
  #     that carries no kind marker -- so every adopter went red on their SECOND session for
  #     a file we never shipped. It stayed green for the author only because his journal had
  #     been hand-marked once. The fix reads git ls-files; this case is why it stays that way.
  #     THE GATE IS RUN, NOT GREPPED: the block is lifted between its own sentinels into a
  #     throwaway repo and executed, so a future edit that reintroduces a glob goes red here.
  local _ak _akd _akrc _akout
  _akd="$(mktemp -d "${TMPDIR:-/tmp}/preflight.XXXXXX" 2>/dev/null)"
  if [ -n "$_akd" ]; then
    _ak="$_akd/gate.sh"
    { echo 'FAILED=""; GAPS=""; PASSED=0'
      echo 'gap(){ echo "[GAP] $1"; }'
      echo 'log_verdict(){ :; }'
      # THE EXTRACTED REGION CALLS is_upstream, SO IT HAS TO TRAVEL WITH IT (#315).
      # `declare -f` emits the function this file actually defines, so the fixture tests the
      # real predicate. A hand-written stub here would be the ninth spelling of the rule --
      # precisely the defect the extraction was introduced to prevent.
      declare -f is_upstream say_pass
      # THE PATTERNS ARE BRACKETED SO THEY DO NOT MATCH THIS LINE. Unbracketed, sed opened
      # the range again here and printed to EOF -- the fixture then ran the whole selftest.
      sed -n "/scaffold:gate-extract-[b]egin shipped-ai-kind/,/scaffold:gate-extract-[e]nd shipped-ai-kind/p" "${BASH_SOURCE[0]}"
      echo 'echo "VERDICT:${FAILED:-clean}"'
    } > "$_ak"
    mkdir -p "$_akd/r/ai" "$_akd/r/overlays" "$_akd/r/.github/workflows"
    : > "$_akd/r/OVERVIEW.md"; : > "$_akd/r/.github/workflows/mirror-sync.yml"
    printf '<!-- scaffold:ai-file-kind template -->\n' > "$_akd/r/ai/KEPT.md"
    ( cd "$_akd/r" && git init -q . && git add ai/KEPT.md >/dev/null 2>&1 )
    # the journal a session creates: on disk, unmarked, NOT tracked.
    printf '# journal\n' > "$_akd/r/ai/SESSION_JOURNAL.md"
    _akout="$( cd "$_akd/r" && bash "$_ak" 2>&1 )"
    if printf '%s' "$_akout" | grep -q 'VERDICT:clean'; then
      ok "an untracked ai/SESSION_JOURNAL.md does not fail shipped-ai-kind (it is not shipped)"
    else
      bad "shipped-ai-kind failed on an UNTRACKED ai/ file — the disk glob is back, and every adopter goes red after one session"
    fi
    # AND THE GATE STILL BITES. A version that skipped ai/ entirely would pass the case above.
    printf 'no marker here\n' > "$_akd/r/ai/LEAKED.md"
    ( cd "$_akd/r" && git add ai/LEAKED.md >/dev/null 2>&1 )
    _akout="$( cd "$_akd/r" && bash "$_ak" 2>&1 )"
    if printf '%s' "$_akout" | grep -q 'shipped-ai-kind'; then
      ok "...and a TRACKED ai/ file with no kind marker still fails it"
    else
      bad "shipped-ai-kind passed a tracked, unmarked ai/ file — the gate was silenced, not fixed"
    fi
    rm -rf "$_akd"
  else
    bad "could not make a fixture for shipped-ai-kind — the case did NOT run"
  fi

  # 1x. A LINKED WORKTREE IS NAMED, NOT CALLED "NOT FIRING" (#368). The block is lifted and
  #     run against a stub session_hook that keeps the real contract: exit 3 and the
  #     worktree message. A stub exiting 1 confirms the FAIL path still bites.
  local _efd _efout
  if _efd="$(mktemp -d "${TMPDIR:-/tmp}/preflight.XXXXXX" 2>/dev/null)"; then
    mkdir -p "$_efd/tools"
    { echo 'FAILED=""; GAPS=""'; echo 'gap(){ echo "[GAP] $1"; [ -n "${2:-}" ] && echo "      $2"; }'; echo 'log_verdict(){ :; }'
      sed -n "/scaffold:gate-extract-[b]egin ever-fired/,/scaffold:gate-extract-[e]nd ever-fired/p" "${BASH_SOURCE[0]}"
      echo 'echo "VERDICT:${FAILED:-clean}"'
    } > "$_efd/gate.sh"
    printf '#!/bin/sh\necho "session_hook: no start recorded in this LINKED WORKTREE — too early to tell." >&2\necho "  The hook writes the run log where the session opened, and sessions open in the" >&2\necho "  main checkout, so 60 tool row(s) and 0 starts here is the expected shape." >&2\necho "  The main checkout'"'"'s log (/m/ai/.scaffold-run-log) records 4 start(s)." >&2\nexit 3\n' \
      > "$_efd/tools/session_hook.sh"; chmod +x "$_efd/tools/session_hook.sh"
    _efout="$(cd "$_efd" && bash gate.sh 2>&1)"
    case "$_efout" in
      *"linked worktree"*"records 4 start(s)"*"VERDICT:clean"*) ok "a linked worktree is a named GAP quoting the main checkout's starts" ;;
      *) bad "linked worktree not named: $(printf '%s' "$_efout" | tr '\n' ' ' | cut -c1-200)" ;;
    esac
    printf '#!/bin/sh\necho "session_hook: NEVER FIRED" >&2\nexit 1\n' > "$_efd/tools/session_hook.sh"
    _efout="$(cd "$_efd" && bash gate.sh 2>&1)"
    case "$_efout" in
      *"VERDICT: session-hooks-never-fired"*) ok "...and NEVER FIRED still FAILS" ;;
      *) bad "NEVER FIRED no longer fails: $(printf '%s' "$_efout" | tr '\n' ' ' | cut -c1-200)" ;;
    esac
    rm -rf "$_efd"
  else
    bad "could not make a fixture for the ever-fired gate — the case did NOT run"
  fi

  # 1y. FINDINGS MUST NOT READ AS A PASS. The dependency gate called `--check`, which already
  #     turns findings into exit 0, so a scan WITH findings printed "[PASS] ... no known
  #     vulnerabilities" and the advisory branch was unreachable (CONTROL, 2026-09-23). The
  #     block is lifted and run against a stub audit that keeps the real exit contract:
  #     --check 0 on findings, --strict 1.
  local _dad _dadout
  if _dad="$(mktemp -d "${TMPDIR:-/tmp}/preflight.XXXXXX" 2>/dev/null)"; then
    mkdir -p "$_dad/tools"
    printf '#!/bin/sh\necho "dependency_audit: GHSA-0000-stub in libstub 1.0"\n[ "$1" = --strict ] && exit 1\nexit 0\n' \
      > "$_dad/tools/dependency_audit.sh"; chmod +x "$_dad/tools/dependency_audit.sh"
    { echo 'PASSED=0; GAPS=""'; echo 'gap(){ echo "[GAP] $1"; }'; echo 'log_verdict(){ :; }'
      sed -n "/scaffold:gate-extract-[b]egin dependency-audit/,/scaffold:gate-extract-[e]nd dependency-audit/p" "${BASH_SOURCE[0]}"
    } > "$_dad/gate.sh"
    _dadout="$(cd "$_dad" && bash gate.sh 2>&1)"
    if printf '%s' "$_dadout" | grep -q 'PASS'; then
      bad "dependency gate printed PASS for a scan WITH findings: $(printf '%s' "$_dadout" | head -1)"
    elif printf '%s' "$_dadout" | grep -q 'GHSA-0000-stub'; then
      ok "dependency findings are reported as findings, not as a pass"
    else
      bad "dependency gate did not report the stub finding at all: $(printf '%s' "$_dadout" | head -1)"
    fi
    rm -rf "$_dad"
  else
    bad "could not make a fixture for the dependency gate — the case did NOT run"
  fi

  # 1a. A FAILING ROW BURIED IN A LONG SUITE MUST SURVIVE INTO THE REPORT (localcoder#182).
  #     `tail -25` of a 172-case suite is 25 PASS rows and the summary. The one FAIL line is
  #     in the middle and was discarded, so an intermittent failure -- the kind you get one
  #     look at -- left nothing to diagnose. Synthetic input, because reproducing a flake to
  #     test the reporting of flakes is not a thing that can be scheduled.
  local _st_in="" _st_out _i
  for _i in $(seq 1 60); do
    if [ "$_i" = 7 ]; then
      _st_in="$_st_in
TEST the-one-that-broke   | FAIL    | port already bound"
    else
      _st_in="$_st_in
TEST case-$_i             | PASS    | fine"
    fi
  done
  _st_in="$_st_in
AUDIT: 59 passed, 1 failed"
  _st_out="$(salient_then_tail "$_st_in")"
  if printf '%s' "$_st_out" | grep -q 'the-one-that-broke'; then
    ok "a FAIL row 53 lines above the tail survives into the failure report"
  else
    bad "the failing row was discarded — tail-only reporting is back, and an intermittent failure cannot be diagnosed"
  fi
  # AND THE TAIL IS STILL THERE. A version that printed only the salient lines would pass the
  # case above while throwing away the summary and the surrounding context.
  if printf '%s' "$_st_out" | grep -q 'case-60' \
     && printf '%s' "$_st_out" | grep -q 'AUDIT: 59 passed'; then
    ok "and the tail is still printed alongside it"
  else
    bad "the tail was dropped in favour of the salient lines — that trades one blind spot for another"
  fi
  # A CLEAN SUITE MUST NOT GROW A HEADER. This path only runs on failure, but a helper that
  # emits its banner unconditionally would clutter every future caller.
  if ! printf '%s' "$(salient_then_tail "one line
two lines
three lines")" | grep -q 'lines that look like the failure'; then
    ok "output with nothing failure-shaped in it gets no banner"
  else
    bad "the banner printed for output containing no failure"
  fi

  # 1b. THE TWO COPIES OF is_upstream_repo MUST AGREE. The footprint budget is a HARD gate
  #     upstream and ADVISORY in an adoption, and the whole difference turns on this
  #     predicate — inlined above because tools/scaffold_version.sh runs its main flow at
  #     top level and cannot be sourced for one function. Two definitions of one rule is
  #     this project's most repeated defect, so the duplication is pinned rather than
  #     trusted: if either drifts, an adopter silently gets the wrong severity.
  local _pf_up=no _sv_up=no
  is_upstream && _pf_up=yes
  if [ -f tools/scaffold_version.sh ] \
     && grep -q 'is_upstream_repo()' tools/scaffold_version.sh; then
    # Read the canonical body rather than sourcing the file.
    if sed -n '/^is_upstream_repo()/,/^}/p' tools/scaffold_version.sh \
       | grep -q 'overlays' \
       && sed -n '/^is_upstream_repo()/,/^}/p' tools/scaffold_version.sh \
          | grep -q 'OVERVIEW.md' \
       && sed -n '/^is_upstream_repo()/,/^}/p' tools/scaffold_version.sh \
          | grep -q 'mirror-sync.yml'; then
      _sv_up="$_pf_up"
    fi
  fi
  if [ "$_pf_up" = "$_sv_up" ]; then
    ok "is_upstream_repo agrees with tools/scaffold_version.sh (upstream=$_pf_up)"
  else
    bad "the two is_upstream_repo definitions disagree — the footprint gate severity is wrong somewhere"
  fi

  # 1b-ii. AND EVERY COPY IN THE WORKFLOW, which is where the drift actually was. Three steps
  #     in scaffold-check.yml inline the same predicate to decide "am I the template repo?",
  #     and until 2026-08-11 the AGENTS.md placeholder step used `setup.sh` as its third
  #     signal instead of `.github/workflows/mirror-sync.yml`. setup.sh is the one file EVERY
  #     adopter has, so that copy was strictly weaker than the rule — and it never misfired,
  #     because no adopter carries overlays/ either. Correct by accident is how a drifted
  #     duplicate survives, and 1b above only ever pinned the two SHELL copies.
  # EVERY COPY IN THE TREE, NOT JUST THE WORKFLOW'S. This pin was added in 0.36.6, when the
  # AGENTS.md placeholder step in scaffold-check.yml was found testing `setup.sh` as its
  # third signal. It checked scaffold-check.yml and nothing else — so it never saw
  # setup.sh:382, which had the SAME drift and was strictly worse: `setup.sh` exists in
  # every adoption by definition, so all three conjuncts held downstream and the AGENTS.md
  # placeholder check could not fire in ANY adopting project. It printed
  # `[OK] AGENTS.md (template repo — placeholders expected)` at real projects with real
  # unfilled commands, for as long as it has existed.
  #
  # Reported from the godsfall adoption (#208). A pin scoped to the file where the drift was
  # FOUND is scoped to the wrong thing — the same mistake as sweeping *.md for W-15's stale
  # paths and missing the two inside code. So this greps the tracked tree.
  local _updrift
  _updrift="$(git grep -n '\[ -d overlays \]' -- 'setup.sh' 'sync-check.sh' 'tools/*' '.github/workflows/*' 2>/dev/null \
              | grep -v 'mirror-sync\.yml \]' \
              | grep -vE ':[0-9]+:[[:space:]]*#' || true)"
  if [ -z "$_updrift" ]; then
    ok "every copy of is_upstream_repo in the tree uses the canonical third signal"
  else
    bad "a copy of is_upstream_repo uses a different third signal:"
    printf '%s\n' "$_updrift" | sed 's/^/          /' | head -4
  fi

  # 1b-iii. AN EXCEPTION TO SELFTEST DISCOVERY MUST BE INVOKED SOMEWHERE ELSE (#237).
  #     scaffold-check.yml now skips adoption_check.sh in the discovery sweep, because an
  #     explicit step already runs it -- in that tool `--selftest` and bare are the same
  #     function, so discovery was running one identical ~160s twice and cancelling the job
  #     at its own 5-minute ceiling BEFORE eleven later steps ran at all.
  #
  #     The skip is correct only while that explicit step exists. Delete the step and the
  #     skip silently retires the suite in CI -- which is precisely the defect the discovery
  #     sweep was built to catch (a suite nobody runs), reintroduced one level up by the
  #     exception to it. An exception that is trusted rather than checked is this repo's
  #     most repeated shape, so this checks it: every basename in SELFTEST_SKIP must appear
  #     as an explicit invocation elsewhere in the same workflow.
  _skip_unbacked() {   # _skip_unbacked <workflow> -> prints any skipped tool nothing runs
    local _wf="$1" _names _n _esc
    [ -f "$_wf" ] || return 0
    _names="$(sed -n 's/^[[:space:]]*SELFTEST_SKIP="\([^"]*\)".*/\1/p' "$_wf" 2>/dev/null)"
    for _n in $_names; do
      _esc="$(printf '%s' "$_n" | sed 's/\./\\./g')"
      grep -qE "^[[:space:]]*(\./)?tools/$_esc([[:space:]]|\$)" "$_wf" || printf '%s\n' "$_n"
    done
  }

  local _skipbad
  _skipbad="$(_skip_unbacked "$WORKFLOW")"
  if [ -z "$_skipbad" ]; then
    ok "every selftest-discovery exception is invoked by an explicit workflow step"
  else
    bad "a tool is skipped by selftest discovery and run by nothing:"
    printf '%s\n' "$_skipbad" | sed 's/^/          /'
  fi

  # AND ON FIXTURES, IN BOTH DIRECTIONS -- the tree above is green, so on its own it proves
  # nothing. A skip WITH its explicit step must pass; the same skip with the step deleted
  # must fail. Without the second case this would pass whether or not it can detect anything.
  local _skd
  _skd="$(mktemp -d "${TMPDIR:-/tmp}/skipcheck.XXXXXX")" || { echo "preflight: mktemp failed; stopping" >&2; exit 1; }
  printf '          SELFTEST_SKIP="adoption_check.sh"\n          tools/adoption_check.sh\n' \
    > "$_skd/backed.yml"
  printf '          SELFTEST_SKIP="adoption_check.sh"\n          echo nothing runs it\n' \
    > "$_skd/unbacked.yml"
  if [ -z "$(_skip_unbacked "$_skd/backed.yml")" ]; then
    ok "a skipped suite WITH its explicit step passes"
  else
    bad "a skipped suite with an explicit step was reported as unbacked"
  fi
  if [ -n "$(_skip_unbacked "$_skd/unbacked.yml")" ]; then
    ok "a skipped suite that NOTHING invokes is caught"
  else
    bad "a skipped suite invoked by nothing was not caught — the exception is unchecked"
  fi
  rm -rf "$_skd"

  # 1b-iv. THE ARCHIVE VERDICT IS READ FROM AN EXIT CODE, NOT GREPPED OUT OF PROSE.
  #     setup.sh grepped session_archive.py's report for `[over]`, which does not match
  #     `[BURST]` — the WORSE state — so a file 316 lines past its burst line printed
  #     `[OK] ai/ files under their archive lines` while one 23 lines over the archive line
  #     was reported. Found in this programme's own context repo on 2026-08-18.
  #     Matching one more token would only move the blind spot to the next state anyone
  #     adds, so the tool answers with an exit code and setup.sh reads it. This asserts the
  #     consumption side cannot quietly go back: the call must carry --exit-status, and the
  #     old prose-branch must be gone.
  local _arch_bad=""
  if [ -f setup.sh ]; then
    grep -q -- '--all --check --exit-status' setup.sh \
      || _arch_bad="$_arch_bad; setup.sh does not ask session_archive.py for an exit status"
    if grep -qE 'archive_report.*\|[[:space:]]*grep -q' setup.sh; then
      _arch_bad="$_arch_bad; setup.sh still BRANCHES on grepping the archive report"
    fi
  fi
  if [ -z "$_arch_bad" ]; then
    ok "the archive verdict is read from an exit code, not grepped out of prose"
  else
    bad "the archive verdict reverted to prose-matching:${_arch_bad#;}"
  fi

  # 1b-v. A SHIPPED WORKFLOW MUST NOT ASSUME A FRESH MACHINE.
  #     Every workflow here was written against GitHub-hosted runners, where each job gets a
  #     new VM. Self-hosted runners PERSIST their workspace and home directory, and the
  #     difference is silent until a step that is only correct once runs twice:
  #
  #       git remote add mirror ...   ->  error: remote mirror already exists.   exit 3
  #
  #     Measured 2026-08-18. The mirror had not moved in 36 releases; the reason changed from
  #     a billing block to this and nobody noticed, because both present as a red X on a step
  #     no one reads. `>> ~/.ssh/known_hosts` on every run is the same class, quieter — it
  #     grows without bound instead of failing.
  #
  #     Both are one-shot operations written as if the machine were new. This looks for that
  #     shape rather than for those two commands, so the next one is caught too.
  local _fresh=""
  if [ -d .github/workflows ]; then
    _fresh="$(grep -nE '^[[:space:]]*(git remote add|[^#]*>>[[:space:]]*~/\.ssh/)' \
              .github/workflows/*.yml 2>/dev/null \
              | grep -vE ':[0-9]+:[[:space:]]*#' || true)"
    # An append GUARDED by an existence test is correct and must not be flagged.
    if [ -n "$_fresh" ] && grep -q 'ssh-keygen -F' .github/workflows/*.yml 2>/dev/null; then
      _fresh="$(printf '%s\n' "$_fresh" | grep -v 'known_hosts' || true)"
    fi
  fi
  if [ -z "$_fresh" ]; then
    ok "no shipped workflow assumes a fresh machine (self-hosted runners persist)"
  else
    bad "a shipped workflow is only correct on its FIRST run on a persistent runner:"
    printf '%s\n' "$_fresh" | sed 's/^/          /' | head -4
  fi

  # 1b-vi. EVERY FAILING ASSERTION IN A WORKFLOW MUST ALSO RUN LOCALLY (P0-2).
  #     `.scaffold-version` drifted fourteen releases because the only thing asserting it was
  #     a step in scaffold-check.yml, and that step stopped running the day Actions were
  #     blocked. The instance is fixed; this is the class. Every `::error::` in a shipped
  #     workflow either has a local counterpart or is DECLARED as deliberately CI-only, with
  #     the reason on the same line — because "there is no local equivalent" is sometimes
  #     true (a Linux-only check cannot run here) and must be stated rather than assumed.
  #
  #     Declared like this, in the workflow, within three lines above the assertion:
  #         # scaffold:also-local <the local check that covers it>
  #         # scaffold:ci-only    <why no local equivalent is possible>
  #
  #     Naming WHICH local check is the point. "There is a local counterpart somewhere" is
  #     the claim that rotted last time; a named one can be followed and falsified.
  local _cionly="" _wf _ln _txt
  if [ -d .github/workflows ]; then
    for _wf in .github/workflows/*.yml; do
      [ -f "$_wf" ] || continue
      while IFS=: read -r _ln _txt; do
        [ -n "$_ln" ] || continue
        # A declaration in the three lines above exempts it.
        if sed -n "$(( _ln > 3 ? _ln - 3 : 1 )),$((_ln - 1))p" "$_wf" \
           | grep -qE 'scaffold:(ci-only|also-local)'; then
          continue
        fi
        _cionly="$_cionly
  $_wf:$_ln"
      done <<CIONLY
$(grep -n '::error::' "$_wf" 2>/dev/null | cut -d: -f1 | sed 's/$/:x/')
CIONLY
    done
  fi
  if [ -z "$_cionly" ]; then
    ok "every workflow assertion has a local counterpart or a declared CI-only reason"
  else
    bad "a workflow asserts something nothing local checks, and does not say it is CI-only:"
    printf '%s\n' "$_cionly" | sed '/^$/d' | head -6
  fi

  # 1b-vii. A TOOL THAT SHIPS A --check MODE MUST BE CALLED IN THAT MODE.
  #     status_block.sh shipped in 0.58.0 to make a stale status table a gate result, and for
  #     three releases nothing invoked its --check. Discovery below ran its --selftest, so it
  #     was green on its own fixtures the whole time while the file it exists to police was
  #     never compared — a tool can be present, tested and pointed at nothing.
  #
  #     --selftest proves a tool WORKS. Only a call in run_all proves it RUNS. This asserts
  #     the second, and takes a declaration where a tool genuinely has no place in preflight:
  #         # scaffold:no-gate <why this --check is not a preflight gate>
  local _nogate="" _ct _cb
  for _ct in tools/*.sh tools/*.py; do
    [ -f "$_ct" ] || continue
    _cb="$(basename "$_ct")"
    [ "$_cb" = "preflight.sh" ] && continue
    grep -qE -- "^[[:space:]]*--check\\)" "$_ct" || continue
    grep -qE -- 'scaffold:no-gate' "$_ct" && continue
    # SC1087 reads `$_cb[` as an array expansion. It is not: this builds a REGEX, and the
    # bracket belongs to the character class `['"]?` that allows the tool name to appear
    # quoted or bare in a call site. Suppressed deliberately rather than left to look
    # identical to a finding nobody examined.
    # shellcheck disable=SC1087
    grep -qE -- "$_cb['\"]? --check|$_cb --check" tools/preflight.sh >/dev/null 2>&1 && continue
    _nogate="$_nogate $_cb"
  done
  if [ -z "$_nogate" ]; then
    ok "every tool with a --check mode is invoked with it, or declares why not"
  else
    bad "a tool ships --check and no preflight gate calls it (selftest-green, unused):$_nogate"
  fi

  # 1c. THE ACTION FLOOR, IN BOTH DIRECTIONS, ON FIXTURES — the gate above only ever runs
  #     against this repo, where it is green, so on its own it proves nothing. All three
  #     cases matter: below-floor must be caught, at-floor must not be, and a COMMENT
  #     quoting an old pin must not be. The third is not hypothetical — scaffold-check.yml
  #     documents why v4 is wrong by quoting v4, so a matcher that read comments would fail
  #     on the explanation of its own rule.
  local _afd _afout
  _afd="$(mktemp -d "${TMPDIR:-/tmp}/actionfloor.XXXXXX")" || { echo "preflight: mktemp failed; stopping" >&2; exit 1; }
  mkdir -p "$_afd/.github/workflows"
  printf 'jobs:\n  a:\n    steps:\n      - uses: actions/checkout@v4\n' \
    > "$_afd/.github/workflows/scaffold-check.yml"
  _afout="$( cd "$_afd" && bash -c "$(declare -f stale_action_pins); \
      ACTION_FLOORS='actions/checkout:5'; \
      SHIPPED_WORKFLOWS='.github/workflows/scaffold-check.yml'; stale_action_pins" 2>/dev/null )"
  case "$_afout" in
    *"checkout@v4"*) ok "a shipped workflow pinned below the floor is caught" ;;
    *) bad "checkout@v4 was not caught by the action floor — the gate cannot fail" ;;
  esac
  printf 'jobs:\n  a:\n    steps:\n      - uses: actions/checkout@v7\n' \
    > "$_afd/.github/workflows/scaffold-check.yml"
  _afout="$( cd "$_afd" && bash -c "$(declare -f stale_action_pins); \
      ACTION_FLOORS='actions/checkout:5'; \
      SHIPPED_WORKFLOWS='.github/workflows/scaffold-check.yml'; stale_action_pins" 2>/dev/null )"
  if [ -z "$_afout" ]; then
    ok "a pin at or above the floor is not flagged"
  else
    bad "checkout@v7 was flagged against a floor of 5: $_afout"
  fi
  printf '# uses: actions/checkout@v4 is what we used to pin, and why it was wrong\njobs:\n  a:\n    steps:\n      - uses: actions/checkout@v7\n' \
    > "$_afd/.github/workflows/scaffold-check.yml"
  _afout="$( cd "$_afd" && bash -c "$(declare -f stale_action_pins); \
      ACTION_FLOORS='actions/checkout:5'; \
      SHIPPED_WORKFLOWS='.github/workflows/scaffold-check.yml'; stale_action_pins" 2>/dev/null )"
  if [ -z "$_afout" ]; then
    ok "an old pin quoted in a COMMENT does not fail the floor"
  else
    bad "a commented pin was read as a real one: $_afout"
  fi
  rm -rf "$_afd"

  # 1d. THE PRODUCT-DIR RULE HAS TWO IMPLEMENTATIONS — scan_dirs() above and an inline block
  #     in scaffold-check.yml — because CI's discovery must not depend on the tool it is
  #     discovering. That is a defensible duplication and an UNPINNED one is not: the
  #     is_upstream_repo copies drifted for months and were correct only by accident. So the
  #     workflow's copy is checked for the same marker name, the same anchor, and the same
  #     treatment of a missing directory.
  local _wfp=0
  if [ -f .github/workflows/scaffold-check.yml ]; then
    grep -q "scaffold:product-dir" .github/workflows/scaffold-check.yml && _wfp=$((_wfp + 1))
    grep -q 'SCAN_DIRS="tools"' .github/workflows/scaffold-check.yml && _wfp=$((_wfp + 1))
    grep -q 'declares scaffold:product-dir .*does not exist' .github/workflows/scaffold-check.yml && _wfp=$((_wfp + 1))
    # A DIRECTORY IS EXECUTABLE, so both discovery loops need `[ -f ]` and not `[ -x ]`
    # alone. Widening discovery past tools/ — which has no subdirectories — surfaced this
    # on the first product-dir run: grep wrote "Is a directory" for __pycache__ on every
    # run. selftest_tools() here has always had the test; the workflow's second loop did
    # not, and "the two copies agree" has to mean this too.
    [ "$(grep -c '\[ -f "\$f" \] || continue' .github/workflows/scaffold-check.yml)" = "2" ] \
      && _wfp=$((_wfp + 1))
  fi
  if [ "$_wfp" -eq 4 ]; then
    ok "the workflow's product-dir discovery matches scan_dirs (marker, base, hard error, -f test)"
  else
    bad "the workflow's product-dir block has drifted from scan_dirs ($_wfp/4 signals)"
  fi

  # 1e. AND IT RESOLVES, IN ALL THREE STATES. A marker feature whose only exercise is "this
  #     repo declares none" is a feature nobody has seen work.
  local _pdd _pdout
  _pdd="$(mktemp -d "${TMPDIR:-/tmp}/productdir.XXXXXX")" || { echo "preflight: mktemp failed; stopping" >&2; exit 1; }
  mkdir -p "$_pdd/tools" "$_pdd/src/thing"
  printf 'no marker here\n' > "$_pdd/AGENTS.md"
  _pdout="$( cd "$_pdd" && bash -c "$(declare -f declared_product_dirs missing_product_dirs scan_dirs); \
      PRODUCT_DIR_MARK='scaffold:product-dir'; scan_dirs | tr '\n' ' '" 2>/dev/null )"
  case "$_pdout" in
    "tools "*) [ "$_pdout" = "tools " ] && ok "no declaration: discovery is tools/ only" \
                 || bad "no declaration, yet discovery widened to: $_pdout" ;;
    *) bad "no declaration gave '$_pdout', expected 'tools '" ;;
  esac
  printf '<!-- scaffold:product-dir src/thing -->\n' >> "$_pdd/AGENTS.md"
  _pdout="$( cd "$_pdd" && bash -c "$(declare -f declared_product_dirs missing_product_dirs scan_dirs); \
      PRODUCT_DIR_MARK='scaffold:product-dir'; scan_dirs | tr '\n' ' '" 2>/dev/null )"
  if [ "$_pdout" = "tools src/thing " ]; then
    ok "a declared product dir widens discovery"
  else
    bad "declared src/thing gave '$_pdout'"
  fi
  # AN INDENTED EXAMPLE IS DOCUMENTATION, NOT A DECLARATION. This file and AGENTS.md both
  # SHOW the marker inside prose; an unanchored pattern read that documentation as a
  # declaration once already, for scaffold:localcoder-forked.
  printf '    <!-- scaffold:product-dir indented/example -->\n' >> "$_pdd/AGENTS.md"
  _pdout="$( cd "$_pdd" && bash -c "$(declare -f declared_product_dirs missing_product_dirs scan_dirs); \
      PRODUCT_DIR_MARK='scaffold:product-dir'; scan_dirs | tr '\n' ' '" 2>/dev/null )"
  if [ "$_pdout" = "tools src/thing " ]; then
    ok "an INDENTED marker is documentation, not a declaration"
  else
    bad "an indented example was read as a declaration: '$_pdout'"
  fi
  # A DECLARED DIRECTORY THAT IS GONE MUST BE REPORTED, not silently dropped.
  rm -rf "$_pdd/src/thing"
  _pdout="$( cd "$_pdd" && bash -c "$(declare -f declared_product_dirs missing_product_dirs scan_dirs); \
      PRODUCT_DIR_MARK='scaffold:product-dir'; missing_product_dirs | tr '\n' ' '" 2>/dev/null )"
  if [ "$_pdout" = "src/thing " ]; then
    ok "a declared dir that no longer exists is reported, not skipped"
  else
    bad "a missing declared dir gave '$_pdout' — a renamed product dir would retire its suite silently"
  fi
  rm -rf "$_pdd"

  # 1f. IS must_gate() REACHABLE FROM THE MAIN FLOW? Three cases below prove it BEHAVES
  #     correctly when called. None of them proved it is CALLED, and for months it was not:
  #     MUST_RUN was parsed, named in the verdict under the words "all of which ran", and
  #     never invoked. A declared suite could fail while preflight printed that sentence and
  #     exited 0 — measured in Robiton/localcoder on 2026-08-12.
  #
  #     "Is this function reachable" is not a property a unit test of the function can have,
  #     which is why three green cases sat on top of dead code. So this greps the main flow,
  #     outside selftest(), for a call — the only place the answer lives.
  local _mainflow _calls
  _mainflow="$(sed -n "1,/^selftest() {/p" "${BASH_SOURCE[0]}")"
  _calls="$(printf '%s\n' "$_mainflow" | grep -cE '^[[:space:]]*must_gate[[:space:]]+"' || true)"
  case "$_calls" in ''|*[!0-9]*) _calls=0 ;; esac
  if [ "$_calls" -ge 1 ]; then
    ok "must_gate() is called from the main flow, not only from these cases"
  else
    bad "must_gate() is defined and tested but NEVER CALLED — every must-run declaration is decorative"
  fi

  # 2. INJECTED: a workflow that invokes an unmapped tool must fail coverage. Without this,
  #    coverage_note() returning a note for everything would look identical to correctness.
  tmp="$(mktemp -d "${TMPDIR:-/tmp}/preflight.XXXXXX")" || { echo "preflight: mktemp failed; stopping" >&2; exit 1; }
  mkdir -p "$tmp/.github/workflows" "$tmp/tools"
  printf 'run: tools/brand_new_gate.sh\n' > "$tmp/.github/workflows/scaffold-check.yml"
  printf '#!/bin/sh\nexit 0\n' > "$tmp/tools/brand_new_gate.sh"
  printf '#!/bin/sh\n# a fixture preflight that runs nothing\n' > "$tmp/tools/preflight.sh"
  rc=0
  ( cd "$tmp" && WORKFLOW=".github/workflows/scaffold-check.yml" ROOT="$tmp" \
    bash -c "$(declare -f coverage_note coverage_evidence local_only_note local_tools ci_tools coverage); \
             WORKFLOW=.github/workflows/scaffold-check.yml; coverage" >/dev/null 2>&1 ) || rc=$?
  if [ "$rc" -ne 0 ]; then
    ok "a tool CI invokes and preflight does not know about fails --coverage"
  else
    bad "coverage passed a workflow invoking an unmapped tool"
  fi

  # 3. A path that appears ONLY in a comment must not demand coverage. The workflow names
  #    an adopter's tools/my_helper.py in prose; demanding a gate for it would make coverage
  #    unusable and it would be turned off, which is how a guard stops protecting anything.
  printf '# tools/only_in_a_comment.sh is discussed here\nrun: tools/header_check.sh\n' \
    > "$tmp/.github/workflows/scaffold-check.yml"
  printf '#!/bin/sh\nexit 0\n' > "$tmp/tools/only_in_a_comment.sh"
  rc=0
  ( cd "$tmp" && bash -c "$(declare -f coverage_note coverage_evidence local_only_note local_tools ci_tools coverage); \
             WORKFLOW=.github/workflows/scaffold-check.yml; coverage" >/dev/null 2>&1 ) || rc=$?
  if [ "$rc" -eq 0 ]; then
    ok "a tool named only in a comment does not demand coverage"
  else
    bad "a commented-out tool path was counted as a CI invocation"
  fi
  # 3b. NO WORKFLOW MUST NOT READ AS CLEAN. An empty tool list is what you get both when CI
  #     invokes nothing and when there is no CI file at all, and only one of those is a pass.
  rm -f "$tmp/.github/workflows/scaffold-check.yml"
  rc=0
  ( cd "$tmp" && bash -c "$(declare -f coverage_note coverage_evidence local_only_note local_tools ci_tools coverage); \
             WORKFLOW=.github/workflows/scaffold-check.yml; coverage" >/dev/null 2>&1 ) || rc=$?
  if [ "$rc" -eq 3 ]; then
    ok "a repo with no workflow reports 'could not verify', not 'clean'"
  else
    bad "no workflow gave exit $rc — an unverifiable comparison must not read as a pass"
  fi

  # 3c-rev. THE OTHER DIRECTION, SEEDED. A gate preflight runs and CI does not must fail
  #     --coverage unless it is declared. Baseline first: the same fixture with CI running it.
  _cov() { ( cd "$tmp" && bash -c "$(declare -f coverage_note coverage_evidence local_only_note local_tools ci_tools coverage); \
             WORKFLOW=.github/workflows/scaffold-check.yml; coverage" 2>&1 ); }
  printf '#!/bin/sh\nexit 0\n' > "$tmp/tools/local_gate.sh"
  printf '#!/bin/sh\ntools/local_gate.sh --check\n' > "$tmp/tools/preflight.sh"
  printf 'run: tools/local_gate.sh\n' > "$tmp/.github/workflows/scaffold-check.yml"
  rc=0; _cov >/dev/null || rc=$?
  # local_gate.sh is unmapped in the FORWARD map, so the forward half fails here; the
  # baseline asserts only that the reverse half is silent about it.
  if ! _cov | grep -q "local_gate.sh is run by preflight and by nothing in CI"; then
    ok "reverse baseline: a local gate CI also runs is not reported"
  else
    bad "reverse baseline: a gate CI runs was reported as local-only"
  fi
  printf 'run: tools/header_check.sh\n' > "$tmp/.github/workflows/scaffold-check.yml"
  printf '#!/bin/sh\nexit 0\n' > "$tmp/tools/header_check.sh"
  rc=0; out="$(_cov)" || rc=$?
  if [ "$rc" -eq 1 ] && printf '%s' "$out" | grep -q "local_gate.sh is run by preflight and by nothing in CI"; then
    ok "a gate preflight runs and CI does not FAILS --coverage, and is named"
  else
    bad "a local-only gate passed --coverage (rc=$rc) — the dependency_audit hole"
  fi
  printf '#!/bin/sh\n# tools/local_gate.sh is only discussed here\n' > "$tmp/tools/preflight.sh"
  rc=0; _cov >/dev/null || rc=$?
  if [ "$rc" -eq 0 ]; then
    ok "a tool preflight only names in a comment is not demanded of CI"
  else
    bad "a commented tool in preflight was counted as a local gate (rc=$rc)"
  fi
  printf '#!/bin/sh\ntools/ci_status.sh --check\n' > "$tmp/tools/preflight.sh"
  printf '#!/bin/sh\nexit 0\n' > "$tmp/tools/ci_status.sh"
  rc=0; _cov >/dev/null || rc=$?
  if [ "$rc" -eq 0 ]; then
    ok "a declared local-only tool passes the reverse check"
  else
    bad "a declared local-only tool failed the reverse check (rc=$rc)"
  fi
  printf '#!/bin/sh\ntools/x_scan.sh\n' > "$tmp/tools/preflight.sh"
  printf '#!/bin/sh\nexit 0\n' > "$tmp/tools/x_scan.sh"
  rc=0; _cov >/dev/null || rc=$?
  printf 'run: tools/header_check.sh\nrun: for f in tools/*_scan.sh; do "$f"; done\n' > "$tmp/.github/workflows/scaffold-check.yml"
  local rc2=0; _cov >/dev/null || rc2=$?
  if [ "$rc" -eq 1 ] && [ "$rc2" -eq 0 ]; then
    ok "a *_scan.sh counts as CI-covered only when CI has the discovery glob"
  else
    bad "scan discovery: without the glob rc=$rc (want 1), with it rc=$rc2 (want 0)"
  fi
  printf '#!/bin/sh\ntools/python_floor.py --check\n' > "$tmp/tools/preflight.sh"
  printf '#!/bin/sh\nexit 0\n' > "$tmp/tools/python_floor.py"
  rc=0; out="$(_cov)" || rc=$?
  if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q "\[GAP\]  tools/python_floor.py — NOT run in CI"; then
    ok "a declared known gap stays visible as a GAP without failing"
  else
    bad "a declared known gap: rc=$rc, or it was not printed as a GAP"
  fi
  # A tool preflight NAMES but this tree lacks must still be mapped. Filtering to files on
  # disk made the scaffold's own run green while localcoder, which has tools/sbom.py, went
  # red in the very selftest that runs --coverage on the repo as shipped (0.111.5).
  printf '#!/bin/sh\n[ -x tools/absent_gate.sh ] && tools/absent_gate.sh --check\n' > "$tmp/tools/preflight.sh"
  rm -f "$tmp/tools/absent_gate.sh"
  rc=0; out="$(_cov)" || rc=$?
  if [ "$rc" -eq 1 ] && printf '%s' "$out" | grep -q "absent_gate.sh is run by preflight and by nothing in CI"; then
    ok "a tool preflight names but this tree lacks must still be mapped"
  else
    bad "an absent-here tool escaped the reverse check (rc=$rc) — green upstream, red in the adopter that has it"
  fi
  rm -f "$tmp/tools/preflight.sh"
  rc=0; out="$(_cov)" || rc=$?
  if [ "$rc" -eq 3 ]; then
    ok "no preflight source to read -> reverse direction 'not verified' (exit 3), not clean"
  else
    bad "no preflight source gave exit $rc"
  fi
  unset -f _cov
  rm -rf "$tmp"

  # 3c. MUST-RUN: DECLARED AND UNRUNNABLE IS A FAILURE, AND THE TWO REASONS PRINT
  #     DIFFERENTLY (D19, W-22 part three). Three cases in one fixture, because the value is
  #     entirely in the distinctions: a gap that stays a gap, a lost +x, and an absent file.
  #     Without the first case this would pass by making everything fail, which is the
  #     always-red version of always-green.
  tmp="$(mktemp -d "${TMPDIR:-/tmp}/preflight-mr.XXXXXX")" || { echo "preflight: mktemp failed; stopping" >&2; exit 1; }
  mkdir -p "$tmp/tools"
  printf '#!/bin/sh\nexit 0\n' > "$tmp/tools/its_suite.sh"
  chmod +x "$tmp/tools/its_suite.sh"

  # NO DECLARATION: an absent gate stays a GAP and the build stays green. This is the
  # machinery D19 explicitly preserves, and breaking it would fail every adopter who does
  # not happen to have every optional tool installed.
  printf '# A\n' > "$tmp/AGENTS.md"
  out="$( cd "$tmp" && bash -c "$(declare -f why_unrunnable must_gate gate gap log_verdict say_pass _heartbeat_wait salient_then_tail); \
      MUST_RUN=\"\"; FAILED=\"\"; GAPS=\"\"; PASSED=0; \
      [ -x tools/absent.sh ] || gap 'tools/absent.sh is missing' 'optional'; \
      echo \"FAILED=[\$FAILED]\"" 2>&1 )"
  case "$out" in
    *"FAILED=[]"*) ok "an UNdeclared missing gate is still a gap, not a failure" ;;
    *) bad "an undeclared missing gate was treated as a failure: $out" ;;
  esac

  # DECLARED + NOT EXECUTABLE -> failure, and the message says which of the two it is.
  chmod -x "$tmp/tools/its_suite.sh"
  out="$( cd "$tmp" && bash -c "$(declare -f why_unrunnable must_gate gate gap log_verdict say_pass _heartbeat_wait salient_then_tail); \
      FAILED=\"\"; GAPS=\"\"; PASSED=0; \
      must_gate 'its suite' tools/its_suite.sh; echo \"FAILED=[\$FAILED]\"" 2>&1 )"
  case "$out" in
    *"NOT EXECUTABLE"*"FAILED=[ its suite]"*)
      ok "a declared must-run gate that is present but not executable FAILS, and says so" ;;
    *) bad "not-executable was not distinguished or did not fail: $out" ;;
  esac

  # DECLARED + ABSENT -> failure, with the OTHER message. This is D-18 itself.
  rm -f "$tmp/tools/its_suite.sh"
  out="$( cd "$tmp" && bash -c "$(declare -f why_unrunnable must_gate gate gap log_verdict say_pass _heartbeat_wait salient_then_tail); \
      FAILED=\"\"; GAPS=\"\"; PASSED=0; \
      must_gate 'its suite' tools/its_suite.sh; echo \"FAILED=[\$FAILED]\"" 2>&1 )"
  case "$out" in
    *"does not exist at that path"*"FAILED=[ its suite]"*)
      ok "a declared must-run gate that is ABSENT fails with a different message (D-18)" ;;
    *) bad "absent was not distinguished from not-executable, or did not fail: $out" ;;
  esac
  rm -rf "$tmp"

  # 3b-ii. THE PRE-PUSH RECEIPT: A SHORTCUT THAT CAN ONLY SKIP PROVEN WORK.
  #
  # The hook used to re-run the whole ~173s gate to learn what this script had recorded
  # seconds earlier, and a hook costing three minutes per push is one people uninstall or
  # route around until --no-verify is reflex. An adopter reported the shape that leaves:
  # `preflight ; push` with a SEMICOLON -- gate ran, FAILED, push went anyway.
  #
  # The shortcut is only safe if every path that is not "a PASS for THIS commit" still runs
  # the full gate, so all four are asserted against the real hook file. CASE 4 IS THE ONE
  # THAT MATTERS: a stale PASS followed by a FAIL must NOT shortcut. Reading the newest
  # PASS instead of the newest VERDICT would find the green row and skip straight past the
  # failure after it -- rebuilding, inside the hook, the exact defect the hook prevents.
  if [ -f .githooks/pre-push ]; then
    _hk="$(mktemp -d "${TMPDIR:-/tmp}/preflight-hook.XXXXXX")" || { echo "preflight: mktemp failed; stopping" >&2; exit 1; }
    mkdir -p "$_hk/ai" "$_hk/tools" "$_hk/.githooks"
    cp .githooks/pre-push "$_hk/.githooks/pre-push"
    printf '#!/bin/sh\necho FULL_RUN\nexit 0\n' > "$_hk/tools/preflight.sh"
    chmod +x "$_hk/tools/preflight.sh"
    ( cd "$_hk" && git init -q . && git config user.email t@t && git config user.name t \
        && printf 'x\n' > f && git add -A \
        && git -c commit.gpgsign=false commit -qm one ) >/dev/null 2>&1
    _hsha="$( cd "$_hk" && git rev-parse HEAD 2>/dev/null )"
    _hk_case() {   # _hk_case <label> <log contents> <want FULL_RUN: 1|0>
      local out ran
      printf '%b' "$2" > "$_hk/ai/.scaffold-run-log"
      out="$( cd "$_hk" && bash .githooks/pre-push 2>&1 </dev/null )"
      case "$out" in *FULL_RUN*) ran=1 ;; *) ran=0 ;; esac
      if [ "$ran" = "$3" ]; then ok "$1"; else bad "$1 (full run=$ran, want $3)"; fi
    }
    _hk_case "no receipt runs the full gate" "" 1
    _hk_case "a PASS for THIS commit skips the re-run" \
             "2026-09-01T00:00:00Z\tpreflight:preflight\tok\tsha=$_hsha 46 gate(s)\n" 0
    _hk_case "a PASS for a DIFFERENT commit still runs it" \
             "2026-09-01T00:00:00Z\tpreflight:preflight\tok\tsha=deadbeef 46 gate(s)\n" 1
    _hk_case "a FAIL after a PASS still runs it — newest VERDICT, not newest pass" \
             "2026-09-01T00:00:00Z\tpreflight:preflight\tok\tsha=$_hsha 46 gate(s)\n2026-09-01T00:01:00Z\tpreflight:preflight\tFAIL\tsha=$_hsha 2 gate(s)\n" 1
    _hk_case "a DIRTY pass (--allow-dirty) is no receipt for HEAD" \
             "2026-09-01T00:00:00Z\tpreflight:preflight\tok\tsha=$_hsha+dirty 46 gate(s)\n" 1
    # WHAT IS PUSHED, NOT WHAT IS CHECKED OUT. git names the pushed commits on stdin, and
    # they need not be HEAD: `git push origin other-branch` once went out on HEAD's receipt.
    # A second commit, left off HEAD, stands in for the other branch.
    ( cd "$_hk" && git checkout -q -b other && printf 'y\n' > f \
        && git -c commit.gpgsign=false commit -qam two && git checkout -q - ) >/dev/null 2>&1
    _osha="$( cd "$_hk" && git rev-parse other 2>/dev/null )"
    _z=0000000000000000000000000000000000000000
    _hk_push() {   # _hk_push <label> <log> <stdin> <want: skip|full|refused>
      local out got
      printf '%b' "$2" > "$_hk/ai/.scaffold-run-log"
      out="$( cd "$_hk" && printf '%b' "$3" | bash .githooks/pre-push origin x 2>&1 )"
      case "$out" in *REFUSED*) got=refused ;; *FULL_RUN*) got=full ;; *) got=skip ;; esac
      if [ "$got" = "$4" ]; then ok "$1"; else bad "$1 (got $got, want $4)"; fi
    }
    _pass_h="2026-09-01T00:00:00Z\tpreflight:preflight\tok\tsha=$_hsha 46 gate(s)\n"
    _pass_o="2026-09-01T00:00:00Z\tpreflight:preflight\tok\tsha=$_osha 46 gate(s)\n"
    _hk_push "pushing HEAD on its own PASS skips the re-run" "$_pass_h" \
             "refs/heads/feat $_hsha refs/heads/feat $_z\n" skip
    _hk_push "pushing ANOTHER branch on HEAD's PASS is refused" "$_pass_h" \
             "refs/heads/other $_osha refs/heads/other $_z\n" refused
    _hk_push "pushing another branch with no receipt is refused, not gated as HEAD" "" \
             "refs/heads/other $_osha refs/heads/other $_z\n" refused
    _hk_push "another branch with its OWN PASS goes out" "$_pass_o$_pass_h" \
             "refs/heads/other $_osha refs/heads/other $_z\n" skip
    _hk_push "its own PASS followed by its own FAIL is refused" \
             "${_pass_o}${_pass_h}2026-09-01T00:02:00Z\tpreflight:preflight\tFAIL\tsha=$_osha 2 gate(s)\n" \
             "refs/heads/other $_osha refs/heads/other $_z\n" refused
    _hk_push "a branch DELETION needs no receipt of its own" "$_pass_h" \
             "(delete) $_z refs/heads/gone $_hsha\n" skip
    # NEVER STRAIGHT TO THE DEFAULT BRANCH. The owner approves every merge, and a PR merged
    # on GitHub never reaches this hook, so the only push to main that gets here is a slip.
    # Each case carries HEAD's own PASS, so a refusal can only come from the target ref.
    _hk_push "a push to main is refused even on a PASS" "$_pass_h" \
             "refs/heads/main $_hsha refs/heads/main $_z\n" refused
    _hk_push "HEAD:main from a feature branch is refused" "$_pass_h" \
             "refs/heads/feat $_hsha refs/heads/main $_z\n" refused
    _hk_push "master is refused too" "$_pass_h" \
             "refs/heads/master $_hsha refs/heads/master $_z\n" refused
    _hk_push "deleting main is refused" "$_pass_h" \
             "(delete) $_z refs/heads/main $_hsha\n" refused
    _hk_push "a tag goes out (release.sh pushes one)" "$_pass_h" \
             "refs/tags/v1 $_hsha refs/tags/v1 $_z\n" skip
    # THE RECORDED REMOTE HEAD MAY ADD A BRANCH, NEVER REMOVE ONE. It is a local, writable
    # ref: trusting it to narrow the set lets one symbolic-ref unprotect main.
    ( cd "$_hk" && git update-ref refs/remotes/origin/trunk HEAD \
        && git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/trunk ) >/dev/null 2>&1
    _hk_push "the remote's HEAD naming trunk protects trunk" "$_pass_h" \
             "refs/heads/trunk $_hsha refs/heads/trunk $_z\n" refused
    _hk_push "and pointing it at trunk does NOT unprotect main" "$_pass_h" \
             "refs/heads/main $_hsha refs/heads/main $_z\n" refused
    ( cd "$_hk" && git symbolic-ref --delete refs/remotes/origin/HEAD \
        && git update-ref -d refs/remotes/origin/trunk ) >/dev/null 2>&1
    # THE OPT-OUT IS READ FROM THE REMOTE ITSELF. A bare repository stands in for GitHub so
    # `git ls-remote` has something real to answer. Neither the checkout's AGENTS.md nor a
    # tracking ref may count: the restricted agent can write both without any push.
    ( cd "$_hk" && git init -q --bare remote.git && git remote add origin "$_hk/remote.git" \
        && git push -q origin "$_hsha:refs/heads/main" ) >/dev/null 2>&1
    _mk='<!-- scaffold:direct-push-ok the owner decided vault notes go straight to main -->'
    printf 'Notes vault.\n  %s\n' "$_mk" > "$_hk/AGENTS.md"
    ( cd "$_hk" && git add AGENTS.md && git -c commit.gpgsign=false commit -qm indented ) >/dev/null 2>&1
    ( cd "$_hk" && git push -q origin HEAD:refs/heads/main ) >/dev/null 2>&1
    _hk_push "a marker on the remote that is not at column 0 exempts nothing" "$_pass_h" \
             "refs/heads/main $_hsha refs/heads/main $_z\n" refused
    ( cd "$_hk" && git reset -q --hard "$_hsha" && git push -q -f origin "$_hsha:refs/heads/main" ) >/dev/null 2>&1
    printf 'Notes vault.\n%s\n' "$_mk" > "$_hk/AGENTS.md"
    _hk_push "a marker only in the checkout exempts nothing" "$_pass_h" \
             "refs/heads/main $_hsha refs/heads/main $_z\n" refused
    ( cd "$_hk" && git add AGENTS.md && git -c commit.gpgsign=false commit -qm optout \
        && git update-ref refs/remotes/origin/main HEAD ) >/dev/null 2>&1
    _optsha="$( cd "$_hk" && git rev-parse HEAD 2>/dev/null )"
    _hk_push "a FORGED tracking ref (update-ref origin/main) exempts nothing" "$_pass_h" \
             "refs/heads/main $_hsha refs/heads/main $_z\n" refused
    ( cd "$_hk" && git push -q origin "$_optsha:refs/heads/main" && git reset -q --hard "$_hsha" ) >/dev/null 2>&1
    _hk_push "a marker on the remote's own main may push to main" "$_pass_h" \
             "refs/heads/main $_hsha refs/heads/main $_z\n" skip
    rm -rf "$_hk"
  fi
  # AND THE VERDICT MUST CARRY A SHA AT ALL, or every case above passes against a receipt
  # this script never writes. Comments stripped: the paragraphs above say `sha=` in prose.
  _rc_flow="$(sed -n "1,/^selftest() {/p" "${BASH_SOURCE[0]}" | sed 's/^[[:space:]]*#.*$//')"
  if [ "$(printf '%s\n' "$_rc_flow" | grep -c 'log_verdict "preflight" .*sha=')" -ge 2 ]; then
    ok "both preflight verdicts stamp the commit they are about"
  else
    bad "a preflight verdict does not carry sha= — the hook's receipt can never match"
  fi

  # 3c-i. THE ARCHIVE CEILINGS ESCALATE, AND ONLY PAST THE BURST LINE (#265).
  #
  # `--exit-status` shipped in session_archive.py 0.11.0 documented as "so a caller can
  # branch on the RESULT instead of grepping this tool's prose for a literal", and its only
  # caller was setup.sh's ADVISORY block -- so a breached ceiling produced [PASS] under a
  # gate whose own label said "archive ceilings". Reported by an adopter with MEMORY.md 73
  # lines over. The shape 1b-vii catches is "a --check nobody calls"; this was one level out,
  # a --check whose only caller could not fail.
  #
  # THREE CASES BECAUSE THE JUDGEMENT IS A THREE-WAY SPLIT, not a boolean. 0.14.0 removed the
  # hard gate on file LENGTH and that argument still holds -- drifting past the archive line
  # while you work is normal, and a gate that reddens on it gets routed around. Past the
  # BURST line is a different claim ("a trim that stopped happening"), reached only by
  # ignoring the advisory for a long time. A fix that failed on both would recreate what
  # 0.14.0 argued out; a fix that failed on neither is what was just reported.
  _ag="$(mktemp -d "${TMPDIR:-/tmp}/preflight-ag.XXXXXX")" || { echo "preflight: mktemp failed; stopping" >&2; exit 1; }; mkdir -p "$_ag/tools"
  _ag_case() {   # _ag_case <label> <stub exit> <want FAILED non-empty: 1|0> <want in output>
    local out
    printf '#!/bin/sh\necho "  [x] ai/MEMORY.md: 999 lines"\nexit %s\n' "$2" > "$_ag/tools/session_archive.py"
    chmod +x "$_ag/tools/session_archive.py"
    # VERBOSE=1: the first case asserts the pass is PRINTED, which quiet mode hides.
    out="$( cd "$_ag" && VERBOSE=1 bash -c "$(declare -f archive_gate gap log_verdict say_pass); \
        FAILED=''; GAPS=''; PASSED=0; archive_gate; echo \"FAILED=[\$FAILED]\"" 2>&1 )"
    local got_failed=0
    case "$out" in *"FAILED=[]"*) got_failed=0 ;; *) got_failed=1 ;; esac
    if [ "$got_failed" = "$3" ] && printf '%s' "$out" | grep -q "$4"; then
      printf '  ok   %s\n' "$1"
    else
      printf '  FAIL %s (failed=%s want=%s): %s\n' "$1" "$got_failed" "$3" "$(printf '%s' "$out" | tr '\n' ' ')"
      fails=$((fails + 1))
    fi
  }
  _ag_case "under the line PASSES"                        0 0 'PASS'
  _ag_case "OVER the line is a gap, NOT a failure (0.14.0)" 1 0 'over its archive line'
  _ag_case "PAST THE BURST LINE FAILS the build"          2 1 'PAST THE BURST LINE'
  rm -rf "$_ag"

  # 3c-ii. THE MUST-RUN GATES MUST BE REACHED ON A RED RUN (#259).
  #
  # The three cases above prove must_gate() BEHAVES. 1f below proves it is CALLED. Neither
  # asks WHERE it is called from, and that was the whole defect: the call sat below the first
  # `if [ -n "$FAILED" ]; then ... return 1`, so on any run where another gate had already
  # failed the adopter's declared suite did not run -- and was not listed as skipped either,
  # since GAPS is only appended by the skip helpers. The condition under which you most want
  # the product suite was the one condition that dropped it.
  #
  # This is the FOURTH distinct failure of this one mechanism (never called; called after the
  # only $FAILED check; verdict discarded; not reached on a red run), and each previous fix
  # was pinned by a case that could not see the next layer. So this case asserts the
  # ORDERING, which is the property the previous three all lacked.
  #
  # COMMENTS ARE STRIPPED FIRST, because the paragraphs around both sites discuss the other
  # site by name -- and a comment mentioning the pattern satisfying a check for the pattern
  # is a defect this file has now shipped twice in one day.
  _mr_flow="$(sed -n "1,/^selftest() {/p" "${BASH_SOURCE[0]}" | sed 's/^[[:space:]]*#.*$//')"
  _mr_call="$(printf '%s\n' "$_mr_flow" | grep -n 'must_gate "\$_mr' | head -1 | cut -d: -f1)"
  _mr_ret="$(printf '%s\n' "$_mr_flow" | grep -n 'PREFLIGHT FAILED:\$FAILED' | head -1 | cut -d: -f1)"
  if [ -n "$_mr_call" ] && [ -n "$_mr_ret" ] && [ "$_mr_call" -lt "$_mr_ret" ]; then
    ok "the must-run gates run BEFORE the first failure return, so a red run still runs them"
  else
    bad "must_gate is called at line ${_mr_call:-none}, at/after the failure exit at ${_mr_ret:-none} — a red run skips the declared suite"
  fi

  # 3d. A DECLARATION, IF THERE IS ONE, MUST NAME A PATH. Retired from "there must BE one".
  #
  # The original case asserted this repository declares at least one must-run gate, on the
  # reasoning that a mechanism nothing uses is a mechanism that rots. That was true while the
  # scaffold owned a behavioural suite. W-15 moved the suite to localcoder, and the scaffold
  # now legitimately declares NONE — its AGENTS.md says so in words, because an empty set is
  # a statement rather than an omission.
  #
  # IT FAILED IN CI AND PASSED LOCALLY, which is worth more than the case was. preflight
  # excludes itself from its own discovery to avoid recursing, so `preflight.sh --selftest`
  # runs only in CI. That is correct and it means a broken preflight selftest is invisible to
  # the very command whose job is "run what CI runs". First local-green/CI-red of this
  # programme, and structural rather than bad luck.
  #
  # The mechanism is still covered: the two cases above prove a declared gate that is absent
  # or not executable FAILS, which is the behaviour D19 asks for. Whether anyone uses it is
  # answered by localcoder, which vendors this file and declares tests/audit_localcoder.sh —
  # so the rot risk is real but it is not this repository's to detect.
  _decl="$(grep -E '^<!--[[:space:]]*scaffold:must-run' AGENTS.md 2>/dev/null || true)"
  if [ -z "$_decl" ]; then
    ok "no must-run gate declared here, and AGENTS.md says so deliberately"
  elif printf '%s' "$_decl" | grep -qE '^<!--[[:space:]]*scaffold:must-run[[:space:]]+[^[:space:]]+[[:space:]]*-->'; then
    ok "every must-run declaration names a path"
  else
    bad "a scaffold:must-run marker is present but names no path — it will never resolve"
  fi

  # 4. THE OTHER DIRECTION: every mapped tool must really be invoked where the note claims.
  #    A note is a claim, and this repo's signature failure is a claim nobody checked.
  #    THE LIST BELOW AND coverage_note()'s `case` ARE TWO COPIES OF ONE LIST. Retiring a
  #    tool from the map and not from here is how this case failed on 2026-08-12: the map
  #    lost its W-15 entries, the loop still asked for them, and coverage_note returned
  #    empty — the check reported a drifted note when what had drifted was the check.
  #    Only tools that EXIST are asked about; a missing one is the other cases' business.
  local t note ev miss=0
  for t in tools/header_check.sh tools/lint_python.sh tools/session_archive.py \
           tools/adoption_check.sh; do
    [ -f "$t" ] || continue
    note="$(coverage_note "$t")"
    ev="$(coverage_evidence "$t")"
    if [ -z "$ev" ] || [ ! -f "$ev" ]; then miss=1; continue; fi
    grep -q "$(basename "$t")" "$ev" || { echo "        $t is not invoked in $ev"; miss=1; }
  done
  if [ "$miss" -eq 0 ]; then
    ok "every mapped tool is really invoked where its note says it is"
  else
    bad "a coverage note claims a tool runs somewhere it does not appear"
  fi

  # 5. Self-exclusion. Without it the selftest discovery re-enters this script and the run
  #    never terminates — found the first time this file was executed, not by reading it.
  local self_listed=0
  for t in tools/*; do
    [ -x "$t" ] || continue
    [ -f "$t" ] || continue
    grep -q -- '--selftest' "$t" || continue
    case "$t" in tools/preflight.sh) self_listed=1 ;; esac
  done
  if [ "$self_listed" -eq 1 ]; then
    if grep -q 'basename "${BASH_SOURCE\[0\]}")" \]; then continue' "${BASH_SOURCE[0]}"; then
      ok "preflight advertises --selftest and excludes itself from its own discovery"
    else
      bad "preflight would run its own selftest — that recurses"
    fi
  else
    bad "preflight no longer advertises --selftest, so CI will not run this suite"
  fi

  # 5b. A GATE THAT EXITS 3 IS A SKIP, NOT A FAILURE AND NOT A PASS (#188).
  #     Reported by an adopter whose GDScript parse checker shelled out to a godot that was
  #     not installed: "command not found" contained no "Parse Error", so it announced
  #     "7 file(s) parse cleanly" and three CI runs went green on zero work. The gate gave
  #     its strongest verdict at the moment it could give none.
  #     ALL THREE OUTCOMES IN ONE CASE, because the risk is a skip being folded into either
  #     neighbour: counted as a pass it is the original bug, counted as a failure it trains
  #     people to ignore a red build on a machine that simply lacks a toolchain.
  local _p=0 _f="" _g="" _rl_before _rl_after
  _probe() {
    local PREFLIGHT_NO_LOG=1
    PASSED=0; FAILED=""; GAPS=""
    gate "skipping gate" bash -c 'echo "DID NOT RUN — no parser here"; exit 3' >/dev/null 2>&1
    gate "failing gate"  bash -c 'exit 1'                                     >/dev/null 2>&1
    gate "passing gate"  true                                                 >/dev/null 2>&1
    _p="$PASSED"; _f="$FAILED"; _g="$GAPS"
  }
  _rl_before="$( [ -f ai/.scaffold-run-log ] && wc -l < ai/.scaffold-run-log || echo 0)"
  ( _probe ) >/dev/null 2>&1
  _probe
  _rl_after="$( [ -f ai/.scaffold-run-log ] && wc -l < ai/.scaffold-run-log || echo 0)"
  if [ "$_rl_before" = "$_rl_after" ]; then
    ok "the fake gates above wrote nothing to the run log"
  else
    bad "the selftest's fake gates wrote $((_rl_after - _rl_before)) row(s) to ai/.scaffold-run-log"
  fi
  case "$_g" in *"skipping gate (skipped)"*) _skip_ok=1 ;; *) _skip_ok=0 ;; esac
  case "$_f" in *"skipping gate"*) _skip_leaked=1 ;; *) _skip_leaked=0 ;; esac
  if [ "$_skip_ok" = "1" ] && [ "$_skip_leaked" = "0" ] && [ "$_p" = "1" ]; then
    ok "exit 3 is a SKIP: not counted as a pass, not counted as a failure"
  else
    bad "exit 3 mishandled (gap=$_skip_ok leaked_to_failed=$_skip_leaked passes=$_p, want 1/0/1)"
  fi

  # 5b. THE RECURSION GUARD, BECAUSE ITS ABSENCE IS A FORK BOMB AND NOT A FAILED CHECK.
  #
  # The main flow gained a gate running `$0 --selftest`, closing a hole where this suite ran
  # ONLY in CI. selftest() runs the MAIN FLOW in fixtures (cases 6 and 7 below), so
  # main -> selftest -> main is unbounded unless something breaks the cycle. The first
  # version of that gate shipped with a comment asserting no recursion was possible; it
  # forked 207 processes on the machine that ran it before being killed by hand.
  #
  # TWO CASES, BECAUSE THE VARIABLE ALONE IS NOT THE INVARIANT. One asserts the marker is
  # live in this very process -- which can only be true if `--selftest` exported it, the
  # half that matters in CI, where discovery invokes `--selftest` DIRECTLY and the main
  # flow never runs. The other asserts the gate call site still reads it, so deleting the
  # `if` while leaving the export in place is caught too.
  #
  # A REGRESSION HERE DOES NOT LOOK LIKE A RED BUILD. It looks like a runner that stops
  # responding, which is the worst shape this project has a name for.
  if [ -n "${SCAFFOLD_PREFLIGHT_INNER:-}" ]; then
    ok "--selftest exports the recursion marker, so a fixture's main flow cannot re-enter it"
  else
    bad "SCAFFOLD_PREFLIGHT_INNER is NOT set inside --selftest: main<->selftest will recurse"
  fi
  # ADJACENCY, NOT PRESENCE. The first version of this case grepped the whole main flow for
  # the marker and for the `$0 --selftest` call, and a mutation deleting the `if` around the
  # gate SURVIVED it -- because the export in the argument parser is also in the main flow,
  # so the marker was "present" while guarding nothing. Second time in this session that a
  # test matched the wrong occurrence of the right string.
  #
  # So: find the line that runs `$0 --selftest` and require the marker within the six lines
  # ABOVE it. That is the guard, and nothing else in this file satisfies it by accident.
  #
  # AND COMMENTS ARE STRIPPED FIRST. The second version DID look at the six lines above the
  # call -- and the mutation survived again, because the paragraph explaining the guard sits
  # in those six lines and says "SCAFFOLD_PREFLIGHT_INNER" in prose. A comment describing a
  # guard satisfied a check for the guard. That is the same defect ci_status.sh fixed on
  # 2026-08-17 (a comment mentioning the variable counted as a `runs-on` reading it) and it
  # was re-created here, in a different file, on the same day it was fixed there. The rule
  # is general: NEVER MATCH A PATTERN AGAINST TEXT THAT INCLUDES COMMENTS ABOUT THE PATTERN.
  _guard_flow="$(sed -n "1,/^selftest() {/p" "${BASH_SOURCE[0]}" | sed 's/^[[:space:]]*#.*$//')"
  _guard_ctx="$(printf '%s\n' "$_guard_flow" | grep -B6 -- '\$0" --selftest' || true)"
  if [ -n "$_guard_ctx" ] && printf '%s' "$_guard_ctx" | grep -q 'SCAFFOLD_PREFLIGHT_INNER'; then
    ok "the selftest gate in the main flow is still guarded by the marker"
  else
    bad "the main flow runs --selftest with no SCAFFOLD_PREFLIGHT_INNER guard — recursion"
  fi

  # 6. A dirty tree is exit 3, and it is NOT reported as a failed check.
  tmp="$(mktemp -d "${TMPDIR:-/tmp}/preflight2.XXXXXX")" || { echo "preflight: mktemp failed; stopping" >&2; exit 1; }
  mkdir -p "$tmp/tools"
  cp "${BASH_SOURCE[0]}" "$tmp/tools/preflight.sh"; chmod +x "$tmp/tools/preflight.sh"
  ( cd "$tmp" && git init -q . && git -c user.email=t@t -c user.name=t commit -q \
      --allow-empty -m init ) >/dev/null 2>&1
  printf 'dirt\n' > "$tmp/untracked.txt"
  rc=0; out="$("$tmp/tools/preflight.sh" 2>&1)" || rc=$?
  if [ "$rc" -eq 3 ] && printf '%s' "$out" | grep -q 'NO CHECK HAS FAILED'; then
    ok "a dirty tree is exit 3 and says plainly that nothing failed"
  else
    bad "a dirty tree gave exit $rc — it must be 3, and distinct from a failed gate"
  fi

  # 7. --allow-dirty gets past the precondition and SAYS the tree is not what will be pushed.
  rc=0; out="$("$tmp/tools/preflight.sh" --allow-dirty 2>&1)" || rc=$?
  if [ "$rc" -ne 3 ] && printf '%s' "$out" | grep -q 'working tree is dirty'; then
    ok "--allow-dirty proceeds, and still names the tree as not what you would push"
  else
    bad "--allow-dirty either did not proceed (exit $rc) or went silent about the dirt"
  fi
  rm -rf "$tmp"

  # 7b. THE LAST-PUSH CI PRECONDITION. _ci_aggregate is pure and fed on stdin precisely so
  #     these run with no network, no gh and no repository -- the fetch half is the boring
  #     half. Every case below was watched FAILING against a deliberately broken aggregate
  #     before being kept; a skip-or-pass path nobody has seen go red is an assumption.
  _agg() { printf '%s' "$1" | _ci_aggregate; }
  _R="$(printf 'completed\tfailure\tCI\thttps://x/1\ncompleted\tsuccess\tLint\thttps://x/2\n')"
  case "$(_agg "$_R")" in
    red\|*) ok "one red run among greens is RED, and the red one is the one named" ;;
    *)      bad "a red run did not produce state=red: $(_agg "$_R")" ;;
  esac
  _R="$(printf 'in_progress\t\tCI\thttps://x/3\ncompleted\tsuccess\tLint\thttps://x/4\n')"
  case "$(_agg "$_R")" in
    pending\|*) ok "a still-running run among greens is PENDING, not green" ;;
    *)          bad "an in_progress run did not produce state=pending: $(_agg "$_R")" ;;
  esac
  # A CANCELLED RUN REACHED NO VERDICT, and the single thing this precondition exists to stop
  # is a non-verdict being read as a pass. It is the case most likely to be "simplified" into
  # the success branch by someone tidying the regex later.
  _R="$(printf 'completed\tcancelled\tCI\thttps://x/5\n')"
  case "$(_agg "$_R")" in
    pending\|*) ok "a CANCELLED run is unresolved, never green" ;;
    *)          bad "a cancelled run did not produce state=pending: $(_agg "$_R")" ;;
  esac
  # GREEN IS AN ALLOWLIST, AND THESE THREE CASES ARE WHY (#312). The first version denylisted
  # the red conclusions, so every conclusion nobody had thought of fell through to the green
  # count. `stale` is a real GitHub value and counted as a pass. GitHub publishes no
  # conclusion-only enum -- the REST reference gives one combined status/conclusion filter
  # list -- so a denylist here is a promise that cannot be checked against anything.
  _R="$(printf 'completed\tstale\tCI\thttps://x/8\n')"
  case "$(_agg "$_R")" in
    pending\|*) ok "a STALE run is unresolved, never green" ;;
    *)          bad "a stale run did not produce state=pending: $(_agg "$_R")" ;;
  esac
  # ROBUSTNESS, NOT AN OBSERVED BUG, and labelled as such: on a completed run GitHub sets a
  # conclusion, so this row was not shown occurring live. It stands in for the conclusion
  # GitHub adds after this line was written, which is the case a denylist cannot cover.
  _R="$(printf 'completed\t\tCI\thttps://x/9\n')"
  case "$(_agg "$_R")" in
    pending\|*) ok "a completed run with NO conclusion is unresolved, never green" ;;
    *)          bad "an empty conclusion did not produce state=pending: $(_agg "$_R")" ;;
  esac
  # THE UNRESOLVED MESSAGE MUST NAME WHAT HAPPENED. The pending detail line printed the
  # STATUS, which is right for in_progress and useless for anything completed: a cancelled
  # run told the reader preflight was blocking because "CI is completed".
  case "$(_agg "$(printf 'completed\tcancelled\tCI\thttps://x/5\n')")" in
    *"is completed"*) bad "the cancelled detail line still says 'is completed' — it names the status, not what happened" ;;
    *cancelled*)      ok "the unresolved detail line names the conclusion, not the status" ;;
    *)                bad "the cancelled detail line names neither: $(_agg "$(printf 'completed\tcancelled\tCI\thttps://x/5\n')")" ;;
  esac
  # SKIPPED AND NEUTRAL STAY GREEN, asserted so that tightening the allowlist later is a
  # deliberate act with a red test behind it. A skipped workflow deliberately did not apply.
  _R="$(printf 'completed\tskipped\tCI\thttps://x/10\ncompleted\tneutral\tLint\thttps://x/11\n')"
  case "$(_agg "$_R")" in
    ok\|*) ok "skipped and neutral are green — they ran and did not object" ;;
    *)     bad "skipped/neutral did not produce state=ok: $(_agg "$_R")" ;;
  esac
  _R="$(printf 'completed\tsuccess\tCI\thttps://x/6\ncompleted\tsuccess\tLint\thttps://x/7\n')"
  case "$(_agg "$_R")" in
    ok\|*) ok "all runs completed successfully is OK" ;;
    *)     bad "all-green did not produce state=ok: $(_agg "$_R")" ;;
  esac
  case "$(_agg '')" in
    unknown\|*) ok "no run recorded is UNKNOWN — advisory, and never a silent pass" ;;
    *)          bad "empty input did not produce state=unknown: $(_agg '')" ;;
  esac
  # STRUCTURAL, BECAUSE EVERY CASE ABOVE DRIVES THE PURE FUNCTION AND THIS BUG LIVED IN THE
  # SHELL AROUND IT. _ci_aggregate can emit five states; the consuming case handled three.
  # `ok` fell straight through, printing nothing and counting nothing, so a run that READ the
  # verdict and a run that never checked produced byte-identical output -- this gate's own
  # thesis failing one layer above the code that enforces it. Asserted on the SOURCE because
  # reproducing it needs a green CI, and the invariant does not: a state the aggregate can
  # emit and the reporter cannot name is wrong however it was reached.
  _ci_case="$(sed -n '/case "\$_ci_state" in/,/^  esac/p' "$0")"
  _ci_missing=""
  for _st in ok red pending unknown skip; do
    printf '%s\n' "$_ci_case" | grep -qE "^[[:space:]]*[a-z|]*\b${_st}\b[a-z|]*\)" \
      || _ci_missing="$_ci_missing $_st"
  done
  if [ -z "$_ci_missing" ]; then
    ok "every state _ci_aggregate can emit has a branch in the reporter"
  else
    bad "the reporter cannot name these states, so they fall through silently:$_ci_missing"
  fi
  # AND THE ok BRANCH MUST NOT BE SILENT. Deleting its echo is the exact regression, and it
  # would leave the branch above still present and still matching.
  if printf '%s\n' "$_ci_case" | sed -n '/^[[:space:]]*ok)/,/;;/p' | grep -q 'PASSED=\|echo'; then
    ok "a verified-green CI verdict is reported out loud, not silently"
  else
    bad "the ok branch prints nothing — a verified green looks identical to never checking"
  fi
  _ci_case=""; _ci_missing=""

  # THE FIRST FEATURE BRANCH AN ADOPTER MAKES HAS NO UPSTREAM, and `git rev-parse @{u}`
  # exits 128 there with "no upstream configured". That is the single most common way this
  # gate will ever be reached, and the failure to avoid is the one both of this file's other
  # bugs had: an empty capture reading as "nothing red", i.e. as a pass. It must be UNKNOWN
  # with a sentence a person can act on -- which the caller turns into a named gap, never a
  # silent green. Driven in a temp repo so this needs no network, no gh and no upstream.
  _up_d="$(mktemp -d "${TMPDIR:-/tmp}/preflight.XXXXXX")" || { echo "preflight: mktemp failed; stopping" >&2; exit 1; }
  (
    cd "$_up_d" || exit 1
    git init --quiet -b main . 2>/dev/null
    mkdir -p .github/workflows && : > .github/workflows/x.yml
    git add -A 2>/dev/null
    git -c user.email=a@b -c user.name=a commit --quiet -m seed 2>/dev/null
    git remote add origin https://github.com/Robiton/ai-project-scaffold.git 2>/dev/null
    git checkout --quiet -b feature-1 2>/dev/null
    # CLEAR EVERY SKIP GUARD, NOT THE TWO YOU REMEMBERED. These are EXPORTED, so they cross
    # both the subshell and the cd, and ci_last_push_state returns its skip before reaching
    # what is under test. The first version of this case cleared two of the three and went
    # green here while failing inside adoption_check, whose fixture exports the third -- the
    # same "an exported var beats cd" trap the upgrade flow hit, and the same
    # author-green/adopter-red shape this whole branch exists to stop. If a guard is added to
    # ci_last_push_state, it belongs in this list too; the list above the function is the one
    # to read, not this comment.
    unset SCAFFOLD_PREFLIGHT_INNER CI SCAFFOLD_ADOPTION_FIXTURE
    ci_last_push_state
  ) > "$_up_d/.state" 2>/dev/null
  case "$(cat "$_up_d/.state" 2>/dev/null)" in
    unknown\|*no\ upstream*) ok "a never-pushed branch is UNKNOWN and says why, never a silent pass" ;;
    ok\|*)  bad "a never-pushed branch reported OK — an absent upstream read as a pass: $(cat "$_up_d/.state")" ;;
    *)      bad "a never-pushed branch gave an unusable state: $(cat "$_up_d/.state")" ;;
  esac
  # AND NO REMOTE AT ALL IS A SKIP, NOT AN UNKNOWN. A repo that was never going to have CI
  # has nothing to be advisory about; calling it unknown would print a gap in every local-only
  # repo forever, and a gap people learn to ignore is worse than no gap.
  _up_e="$(mktemp -d "${TMPDIR:-/tmp}/preflight.XXXXXX")" || { echo "preflight: mktemp failed; stopping" >&2; exit 1; }
  (
    cd "$_up_e" || exit 1
    git init --quiet -b main . 2>/dev/null
    mkdir -p .github/workflows && : > .github/workflows/x.yml
    git add -A 2>/dev/null
    git -c user.email=a@b -c user.name=a commit --quiet -m seed 2>/dev/null
    unset SCAFFOLD_PREFLIGHT_INNER CI SCAFFOLD_ADOPTION_FIXTURE
    ci_last_push_state
  ) > "$_up_e/.state" 2>/dev/null
  case "$(cat "$_up_e/.state" 2>/dev/null)" in
    skip\|*remote*) ok "a repo with no origin remote SKIPS — nothing to be advisory about" ;;
    *)             bad "no-remote did not skip: $(cat "$_up_e/.state")" ;;
  esac
  rm -rf "$_up_d" "$_up_e"

  # AND IT MUST NOT FIRE IN A FIXTURE. selftest() runs the main flow in temp repos; if the
  # precondition tried to resolve an upstream there it would block this suite from inside.
  case "$(SCAFFOLD_PREFLIGHT_INNER=1 ci_last_push_state)" in
    skip\|*) ok "the CI precondition does not fire inside a nested preflight" ;;
    *)       bad "ci_last_push_state ran inside a nested preflight: $(SCAFFOLD_PREFLIGHT_INNER=1 ci_last_push_state)" ;;
  esac

  # 8. Base-ref resolution must not silently invent a ref. An unresolvable base has to be a
  #    named gap: a header check that did not run must not look like one that passed.
  if [ -n "$(base_ref)" ]; then
    ok "a base ref resolves in this repo ($(base_ref))"
  else
    bad "no base ref resolved here, so CI's stricter header form cannot run"
  fi

  echo "  $pass passed, $fail failed"
  [ "$fail" -eq 0 ]
}

case "$MODE" in
  run)      run_all; exit $? ;;
  coverage) coverage; exit $? ;;
  list)     list_gates; exit 0 ;;
  selftest) selftest; exit $? ;;
  help)     usage; exit 2 ;;
esac
