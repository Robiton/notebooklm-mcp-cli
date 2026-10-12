#!/usr/bin/env bash
# Project:  ai-project-scaffold
# File:     tools/ci_status.sh
# Modified: 2026-10-08
# Version:  0.17.10.20261008.1245
# Purpose:  Report red CI on the remote at session start — local green is not CI green.
# Changelog:
#   2026-10-08 v0.17.10.20261008.1245 — the token-in-URL selftest fixture is marked not-a-secret, for secret_scan's new URL-credential shape. No behaviour change.
#   2026-09-23 v0.17.9.20260923.0941 — mktemp takes a ${TMPDIR} template. macOS mktemp ignores TMPDIR without one, so a guarded fixture root could not contain it.
#   2026-09-23 v0.17.8.20260923.0843 — every mktemp fails closed. A failed one left the temp variable empty, so the fixture ran in the caller's directory; header_check's committed into Robiton/control.
#   2026-09-22 v0.17.7 — AN ALARM THAT COULD NEVER GO QUIET. The newest-per-workflow
#                        reducer keyed on `name`, which is the run's DISPLAY TITLE, not the
#                        workflow. Dependabot appends a unique update id to every one:
#                            npm_and_yarn in /. for uuid - Update #1587421234
#                            npm_and_yarn in /. for uuid - Update #1587416440
#                        so each run is trivially "the newest of its name", the dedupe never
#                        fires, and a superseded failure is reported as current FOREVER --
#                        no future run can ever share that name to supersede it.
#
#                        Measured on collectionapp 2026-09-22, reported by the Master
#                        Control session: two spent uuid security-update runs on old commits
#                        reported red while the tip was green on every workflow, so the tool
#                        printed "CI IS RED on origin/master" and named master green two
#                        lines later -- contradicting itself in one output.
#
#                        Keyed on `workflowName` ("Dependabot Updates" for all four), whose
#                        newest run SUCCEEDED, which is the true answer. The MESSAGE still
#                        names the run title, because the key needs stable identity and the
#                        reader needs the specific run; those are different jobs.
#
#                        This is the shape that gets a checker switched off -- a reader who
#                        sees a red they cannot clear stops reading the red. Three selftest
#                        cases, driven on the real API response, and verified to go red
#                        against the old key rather than merely passing against the new one.
#   2026-09-22 v0.17.6 — FIXED A MESSAGE THAT COULD NEVER PRINT. Line ~1392 carried
#                        `${{ vars || 'ubuntu-latest' }}` unescaped inside a double-quoted
#                        string, so bash read `${{` as a parameter expansion, wrote
#                        `bad substitution` to stderr INSTEAD of the line, and carried on.
#                        The one message that explains a set-but-empty runner variable was
#                        replaced by a shell error in precisely the case it exists to
#                        explain, and had been since the line was written. `bash -n` passes
#                        it; no gate in this repository could see it. It was found by
#                        tools/shell_lint.sh on the day that gate was written -- one of
#                        exactly two findings at severity `error` across 33 shell files.
#                        Line ~1415 had the same interpolation escaped correctly all along,
#                        which is how a one-character defect hid next to its own fix.
#   2026-09-21 v0.17.5.20260921.1236 — green was a DENYLIST, so a dead python3 read as a
#                        pass (#316). COVERS_PY answers yes|novrd|pending|no|unknown and an
#                        interpreter that cannot start answers "". Three of those five had
#                        branches, so `unknown` -- computed deliberately when the run list
#                        will not parse -- and "" fell through to the green sentence.
#                        Measured with a python3 stub behaving like one gated behind an
#                        unaccepted Xcode license: `[OK] CI green on main @ 8f6c238`, exit 0,
#                        from a tool that never ran the probe that establishes it. True on
#                        that commit, which is what makes it dangerous.
#                        0.17.3 applied this rule to REDUCER_PY and the red path; it was
#                        never applied to the one probe gating the word "green". Red stays a
#                        denylist (an accusation needs evidence), green becomes an allowlist.
#                        The COVERS_PY and FIRSTFAIL_PY calls lose 2>/dev/null, matching
#                        REDUCER_PY and NOVRD_PY: the cause was one file descriptor away.
#   2026-09-21 v0.17.4.20260921.1152 — THE GAP GAVE ONE INSTRUCTION FOR TWO SITUATIONS, AND THE
#                        RELEASE ABOUT TO BE CUT IS THE CASE IT GETS WRONG. novrd printed
#                        "re-running is what resolves it". That is right for a cancelled
#                        GATE and wrong for a side workflow a later push superseded -- and
#                        the second is how this state usually arises. Measured by Master
#                        Control across the last 60 mirror runs: 11 cancelled, 11 of 11
#                        superseded, and 6 of those on chore(version)/chore(release)
#                        commits, because cutting a release IS a double push. So a release
#                        commit spends a window as the tip with the gate green, a cancelled
#                        mirror beside it, and the tool telling whoever cut it to re-run
#                        something that needs nothing.
#                        NOVRD_PY names which workflow reached no verdict and how it ended,
#                        sharing COVERS_PY's grouping and verdict list because a name that
#                        disagreed with the state it explains is worse than no name. The
#                        advice now branches on it. Verified against the real run list for
#                        07b760a: "Mirror to work-mirror (cancelled)". Four cases, two
#                        watched failing first, two controls -- a workflow that ANSWERED is
#                        never named, and a cancelled run on an older sha is not this tip's
#                        gap. The gap itself is unchanged: we still do not have a verdict.
#   2026-09-21 v0.17.3.20260921.1136 — A NON-VERDICT READ AS A PASS AT ONE END AND AS AN ACCUSATION AT
#                        THE OTHER. Found by driving COVERS_PY and REDUCER_PY across every
#                        conclusion GitHub returns, after Master Control flagged the reducer
#                        half while reviewing the opposite axis in preflight.
#                        COVERS_PY asked only whether a run had COMPLETED, never what it
#                        concluded -- so a CANCELLED run answered "yes", and because the
#                        reducer correctly declines to call cancelled a failure, the verdict
#                        line printed the green sentence. That is #312 again, one layer down,
#                        and live. `novrd` is the fourth answer: every workflow finished, at
#                        least one reached no verdict. Not `pending` (nothing is running, so
#                        waiting is wrong advice), not `no` (runs existed). Still-running
#                        outranks it.
#                        REDUCER_PY was the mirror: `ok` was a denylist, so `stale` and any
#                        future conclusion became a positive "fix or revert" accusation over
#                        a run that decided nothing. Red is now an allowlist of the four real
#                        failures. FIRSTFAIL_PY carries the same list, because a disagreement
#                        between them picks a different run than the one reported.
#                        Nine cases, five watched failing first; the other four are controls
#                        that fail if red stops being reported or if a failure gets diverted
#                        into the new gap.
#   2026-09-21 v0.17.2.20260921.1106 — THE TOOL PRINTED "CI IS RED" AND "CI green" ABOUT THE
#                        SAME SHA, FOUR LINES APART (#312). report() raises the red alarm and
#                        then report_alerts(), thirty lines further down the same function,
#                        phrases its summary through ci_word() -- which branched on
#                        CI_UNVERIFIED alone. A red build deliberately does NOT set that flag
#                        (it is the opposite of unverified, and the selftest's structural scan
#                        exempts the red alarm for that reason), so "verified and RED" fell
#                        through to the string for "verified and green". The exemption was
#                        correct and had nowhere to go. NOT FIXED BY GUARDING THE CALL SITES:
#                        nothing was missing from either of them, which is why two structural
#                        checks written to catch exactly this contradiction both passed over
#                        it. The vocabulary was two-valued over a three-valued domain, so the
#                        third state had to exist first -- CI_RED, asked before CI_UNVERIFIED
#                        in both ci_tag() and ci_word(). Seven cases, five of them watched
#                        failing against the old code before the fix went in, plus a control
#                        that fails if the new state swallows the green one. The green-sentence
#                        scan is now scoped to the shipped region above selftest(), because
#                        assertions that prove the red verdict never emits the green literal
#                        must name it.
#   2026-09-13 v0.17.1.20260913.0831 — --check REPORTED A MALFORMED VARIABLE THAT DID NOT EXIST.
#                        `gh api` on a missing variable prints a 404 JSON BODY to stdout and
#                        exits non-zero. The fetch took the output alone, so the error body
#                        reached classify_list_value, which correctly called it malformed --
#                        and a repository that had simply never set SCAFFOLD_RUNNERS was told
#                        its configuration was broken. A false finding, inside the gate
#                        written to prevent one, shipped in 0.106.0 and found the first time
#                        it ran anywhere but the repo it was built in. Read the exit code.
#   2026-09-12 v0.17.0.20260912.1115 — --check, WHICH THE SHIPPED WORKFLOW HAS PROMISED SINCE
#                        BEFORE IT EXISTED. scaffold-check.yml:87 says, in the paragraph
#                        about a malformed value killing the run at parse time: "`tools/
#                        ci_status.sh --check` validates it locally against the same rules."
#                        It did not. The flag has never existed at any version, and that
#                        sentence sits exactly where a reader is most likely to follow it --
#                        mid-diagnosis of the failure it claims to diagnose.
#                        REPORTED BY AN ADOPTER (collectionapp), against 0.105.0, found in
#                        the .yml. My own flag audit the same morning scanned only *.md and
#                        missed it -- 374 pairs checked, zero suspect, and the defect was in
#                        a file the scan could not see. Widened to every tracked text file,
#                        which then found this plus three more in a shipped Python docstring.
#                        ADDED RATHER THAN DELETED, because the need is real and nothing
#                        else answers it, and because classify_list_value() was already here,
#                        already split from the fetch, already selftested. Only the entry
#                        point was missing.
#                        TAKES A VALUE OR READS THE REPOSITORY, and the argument form is the
#                        primary one: the value being checked is not in GitHub yet, which is
#                        the entire reason to check before the push. Offline with an
#                        argument, so it works in a pre-push hook.
#                        EMPTY IS NOT MALFORMED. An unset variable is the documented default
#                        and flagging it would redden every repo that deliberately has not
#                        retargeted CI. Ten cases, including the mistake people actually make
#                        (unquoted labels), which must be a loud 1 and never a quiet 0.
#   2026-09-11 v0.16.3.20260911.0843 — ASK THE ENDPOINT WHOSE EMPTY RESULT IS BEING READ. 0.16.2
#                        probed `repos/<nwo>` -- can we see the repository. That is the right
#                        question for the account case and the WRONG one in general: a token
#                        with `repo` and without `actions` reads the repository fine and 403s
#                        on the runs endpoint, and the verdict would go straight back to
#                        announcing an outage by a second door. The fix shipped this morning
#                        would have covered the case that produced it and not the class.
#                        `actions/runs?per_page=1 --jq .total_count` answers exactly what the
#                        caller needs -- could this call have returned runs if there were any
#                        -- and `total_count` separates "200, and there are none" from "we
#                        never got a 200" in a single field.
#                        AND IT NAMES WHICH OF THE TWO. Both produce an empty run list and
#                        they have different fixes, so a note stopping at "could not ask"
#                        sends half its readers to the wrong one. The repository probe is now
#                        the DISCRIMINATOR -- repo answers and runs does not means an Actions
#                        scope, repo does not answer means the wrong account -- which is the
#                        job it was always good at and never the job it was doing.
#                        classify_runs_probe() IS SPLIT FROM THE FETCH, the third time in this
#                        file and the same reason each time. ZERO IS AN ANSWER, and that is
#                        the half a careless `-n` check gets wrong: a repository with
#                        genuinely no runs returns 0, which is a true statement about CI, and
#                        swallowing it would suppress the real no-runs alarm on exactly the
#                        repositories that need it. Mutation confirms in both directions --
#                        folding 0 into could-not-ask reddens 1 case, accepting anything
#                        non-empty reddens 4.
#   2026-09-11 v0.16.2.20260911.0647 — AN EMPTY ANSWER IS NOT AN ANSWER. `gh auth status`
#                        succeeds for ANY logged-in account, including one with no access to
#                        this repository, and usable() only ever asked the first question.
#                        OBSERVED AT SESSION START 2026-09-11 on FOUR repositories at once:
#                        gh had silently become a second account, every API call 404d,
#                        run_capped() discards stderr so the 404 arrived here as an empty
#                        string, and all four printed "[!!] NO WORKFLOW RUNS AT ALL --
#                        nothing has been checked remotely" while CI was GREEN on all four.
#                        Four repos reporting zero runs at once is not four outages; that was
#                        the cheapest available signal and nothing was looking at it.
#                        This is the inverse of the defect the whole file is built around and
#                        it is not harmless: a session-start alarm that cries wolf teaches the
#                        reader the line is noise, which is how the true one gets skimmed past.
#                        cannot_ask_note() asks the REPOSITORY, not the account -- if the run
#                        list is empty and repos/<nwo> does not answer either, the honest
#                        verdict is COULD NOT ASK, the third outcome this project already
#                        treats as distinct from pass and fail. It names the active login and
#                        the switch command, because "which account am I" is the question a
#                        reader cannot answer from this output otherwise.
#                        REPRODUCED WITH THE OTHER ACCOUNT'S TOKEN BEFORE FIXING, and verified
#                        after: the wrong account now prints COULD NOT ASK, the right one is
#                        unchanged and green.
#                        repo_nwo() IS SPLIT FROM THE FETCH BECAUSE IT HAD TO BE -- the same
#                        lesson as classify_var_value(). A networked function with the URL
#                        parser inside it has no test at all; split out, it has eleven, and
#                        two of them found real defects. `repo_nwo ""` fell through to the
#                        live remote (`-n "$1"` cannot tell an empty argument from an absent
#                        one, so the case asserting an empty url is refused passed by reading
#                        this repo's own origin), and a deeper path built `repos/a/b/c`, whose
#                        404 says nothing whatsoever about who is asking.
#                        THE STRUCTURAL CHECK IS SCOPED TO ABSENT-ANSWER ALARMS. My first
#                        version asserted on both `NO WORKFLOW RUN` and `NOT RUNNING` and
#                        failed the latter, which is correct code: it fires only when the run
#                        list came back POPULATED and a job in it had zero steps. Exactly the
#                        trap the neighbouring check already records -- a check that flags
#                        correct code gets deleted, not obeyed.
#   2026-09-08 v0.16.1.20260908.1949 — COVERAGE IS PER WORKFLOW, NOT PER COMMIT. The
#                        pending answer exists because a queued run for the tip used to report
#                        green. It was reduced with `any(status == completed)` across every run
#                        for the commit, so ONE workflow finishing answered for ALL of them.
#                        Measured on a real push of 54697ab: two workflows started, "Mirror to
#                        work-mirror" finished in seconds, "Scaffold Check" -- the gate --
#                        ran for another 65 s, and this printed "CI green on main @ 54697ab"
#                        for that whole minute. The standing rule here is to check CI after
#                        every push, and the tool that answers it was answering early.
#                        It survived because the case pinning the rule -- "queued BESIDE
#                        completed is still covered" -- used rows with NO workflow name, so it
#                        could not distinguish a RE-RUN of one workflow (where a finished copy
#                        really is an answer) from a DIFFERENT workflow (where it is not).
#                        Grouped by name: a workflow is answered when any of its runs
#                        completed, the commit when every workflow is. The re-run case is
#                        preserved and now says so explicitly, and a permanently queued
#                        workflow holds the verdict at pending, which is what unverified means.
#   2026-09-03 v0.16.0.20260903.1628 — A QUEUED RUN FOR THE TIP IS NOT A RUN THAT PASSED (#289).
#                        The HEAD-coverage probe asked only whether a row EXISTS for the tip,
#                        so a queued or in-progress run satisfied it -- and the green verdict
#                        then came from the PREVIOUS commit, which had completed.
#                        OBSERVED 2026-09-02: `[OK] CI green on main` printed moments after a
#                        push while the only run for HEAD was still queued. A reader who
#                        skims to the last line, which is what a verdict line is FOR, was
#                        told the commit they had just pushed was green by a tool that had
#                        not seen it finish.
#                        THREE ANSWERS NOW: no run (not green), pending (not green YET, and
#                        not a failure), completed (judge the conclusion). And the verdict
#                        NAMES THE COMMIT -- "green on main" is a claim about a branch, and a
#                        branch moves; only a SHA answers the question a reader actually has.
#                        THE SELFTEST WAS CERTIFYING THE DEFECT. `covers()` re-implemented
#                        the probe instead of running it, so five cases stayed green while
#                        the shipped behaviour changed underneath them -- and one case
#                        asserted the bug outright ("an in-progress run counts as covered",
#                        expecting yes). This file states that rule 200 lines above, about
#                        the reducer, and then broke it here. The probe is COVERS_PY now, one
#                        string with two callers, and the moment the selftest ran the shipped
#                        code it went red on exactly that case.
#   2026-09-01 v0.15.0.20260901.0722 — A MATRIX LEG NAMING LABELS NO RUNNER HAS DOES NOT FAIL.
#                        IT QUEUES. runner_verdict() catches a registered runner that went
#                        offline; it cannot catch the half SCAFFOLD_RUNNERS made reachable --
#                        a leg targeting [self-hosted, Linux] in a repo whose only runner is
#                        macOS. GitHub does not reject that job. It queues indefinitely, and
#                        timeout-minutes never applies because the job never starts, so the
#                        run sits in progress and the PR never goes red. "CI is red" traded
#                        for "CI is silent" is the one trade this project keeps refusing, and
#                        the matrix makes it a one-variable mistake.
#                        WRITTEN BEFORE THE MOVE, NOT AFTER. The fleet is shifting its Linux
#                        leg off ubuntu-latest onto a self-hosted Linux box, and the window
#                        between "the variable names the labels" and "a runner carries them
#                        HERE" is exactly when this fires. Runners are repo-scoped -- this is
#                        a User account, so no runner groups and no org sharing -- so every
#                        repo needs its own registration and each can be missed on its own.
#                        HOSTED LABELS ARE NEVER FLAGGED (ubuntu-*, macos-*, windows-*):
#                        flagging them would fire on the shipped default in every adopter
#                        with no self-hosted runner, which is red on arrival.
#                        An OFFLINE runner does not satisfy a leg, a runner with EXTRA labels
#                        does, and a leg asking for a label the runner lacks does not --
#                        all three mutation-verified, because "both say self-hosted" passing
#                        is the plausible wrong implementation.
#   2026-09-01 v0.14.0.20260901.0419 — ZERO ENABLED FEATURES IS NOT A ZERO ALERT COUNT (#263).
#                        With all three alert features off this printed `[OK] ... 0 open
#                        alerts` and exited 0. The caveat sentence was present and did not
#                        help: the tag, the leading clause and the exit code all said clean
#                        against one adverbial clause. At _enabled=0 the count is vacuous --
#                        nothing answered, so zero is the count of nothing.
#                        THE DEFECT preflight's OWN CHANGELOG NAMES. 0.35.0 called collapsing
#                        rc 3 into a pass "the ci_status defect verbatim: no alerts for
#                        months across three repositories where every alert feature was
#                        switched off" -- then gave the three-outcome treatment to
#                        dependency_audit and left this file printing exactly that. Reported
#                        by an adopter on health-app with all three off.
#                        [??] rather than [!]: nothing is WRONG, the features are simply off,
#                        and a warning tag people learn to ignore would recreate the problem.
#                        alert_line() IS SPLIT OUT so the branch has cases at all -- inline in
#                        report(), behind a network call, the only way to exercise it was to
#                        own a repo with the features off, which is how this shipped.
#   2026-09-01 v0.13.0.20260901.0249 — THE KNOWN LIMIT BECAME THE PRODUCT. The 0.12.0 header
#                        recorded `runs-on: ${ matrix.os }` as a false positive we accepted
#                        in the safe direction. Then scaffold-check.yml gained a matrix so
#                        the gate could run on macOS AND Linux, and this check would have
#                        reported the scaffold's own retargeted workflow as unretargeted --
#                        on every adopter, on every run, permanently. A false positive is the
#                        right direction to fail, but a PERMANENT one trains people to skip
#                        the line, which costs the check the only thing it has.
#                        ONE LEVEL of indirection now resolves: a `runs-on:` reading
#                        `matrix.<key>` counts when a `<key>:` line in the same file
#                        interpolates the variable. Exactly one level, and a matrix key built
#                        from anything else is still flagged -- verified by mutation, because
#                        the obvious wrong fix (accept any matrix.* line) passes every case
#                        that does not specifically check where the key came from.
#                        SCAFFOLD_RUNNERS JOINS SCAFFOLD_RUNNER, both honoured, plural first
#                        -- the same precedence the workflows implement, or this check would
#                        answer a different question than CI does.
#                        AND `malformed` JOINED set/empty/unset, which is the case with real
#                        teeth: fromJSON() on a bad value does not fall back, it kills the
#                        run during expression evaluation BEFORE any step exists, with an
#                        error that never names the variable. Indistinguishable from a dead
#                        runner. Same class as `empty` in 0.12.0, one layer up again.
#   2026-08-17 v0.12.0.20260817.1748 — PROPERTIES 2 AND 3 WERE ANNOUNCED AND NOT IMPLEMENTED
#                        (#213). This file's header claimed three properties for a
#                        ci-down-until declaration; an adopter seed-tested all three against a
#                        real repository and only the FIRST held. ci_outage_expired() existed
#                        and was called from nothing but its own selftest, and property 3 was
#                        never written at all. Worse than dead code, because the property was
#                        DOCUMENTED: the record said the alarm would return and nothing would
#                        have returned it. Three AGENTS.md files name 2026-09-01, and on
#                        2026-09-02 nothing would have said a word.
#                        ci_outage_overdue_note() and ci_outage_suppressing_nothing_note() now
#                        run from report(), ONE place each, and deliberately not inside the
#                        three ci_outage_note() branches -- those are reached only on specific
#                        findings, and an overdue declaration must be said whatever else is
#                        true, including on a fully green repo, which is exactly the case none
#                        of them runs in.
#                        ASSERTED ON OUTPUT, NOT ON RETURN CODES. runner_verdict() passed four
#                        return-code cases while calling a `say` that does not exist here and
#                        printing nothing; only the case that read the text caught it. These
#                        read the text, and mutation confirms: killing the overdue note fails
#                        4 cases, killing the suppressing-nothing note fails 2.
#   2026-08-17 v0.11.0.20260817.0914 — the scanner reads `runs-on:` LINES, not the whole file, and an
#                        EMPTY variable value is its own answer. Both defects were PREDICTED
#                        BY A REVIEWER rather than found by a test, and both were real.
#                        A COMMENT MENTIONING THE VARIABLE COUNTED AS A READ -- and this
#                        repository's own shipped workflow carries exactly such a comment, so
#                        copying that block above a hardcoded `runs-on` passed the check.
#                        Demonstrated on a fixture before fixing, not theorised.
#                        AND A FOUR-JOB WORKFLOW WITH ONE JOB RETARGETED read as "reading" at
#                        file granularity -- the intra-file partial migration this check
#                        exists to catch, invisible in exactly the case cheapest to create.
#                        Now every `runs-on:` in a file must interpolate it.
#                        `empty` JOINED set/unset because `${ vars.X || 'ubuntu-latest' }`
#                        with X set to "" reads the variable and still runs hosted: present,
#                        read by every workflow, retargeting nothing. Reports present and
#                        enforces nothing, one layer further up than the case that started it.
#                        classify_var_value() IS SPLIT FROM THE FETCH BECAUSE IT HAD TO BE:
#                        mutating empty->set inside the networked function changed nothing,
#                        since every verdict case passed the state in directly. The
#                        classifier deciding which state we are in had no test at all.
#                        KNOWN LIMIT, IN THE SAFE DIRECTION: `runs-on: ${ matrix.os }`,
#                        reusable workflows and composite actions defeat a line match and are
#                        flagged as not reading it. A false POSITIVE is noisy and never
#                        silent, which is the correct way round here.
#   2026-08-17 v0.10.0.20260817.0752 — report_runner_var(): A VARIABLE SET WITH NO READER REPORTS
#                        PRESENT AND ENFORCES NOTHING. The adopter's phrasing and their
#                        catch. Retargeting CI takes TWO facts in two places -- the repository
#                        variable and a `runs-on` that interpolates it -- and they had one
#                        repo with the variable about to be set against a workflow still
#                        hardcoded to ubuntu-latest. Nothing reconciled them, so "no run for
#                        the tip" would read as "the runner is still coming up" instead of
#                        "this repo was never retargeted": a silent CI that looks like a
#                        booting one, which is worse than either.
#                        IT ALSO FIRES ON A PARTIAL MIGRATION, which is their "two truths
#                        about where CI runs" case: one workflow retargeted and three not is
#                        how a repo ends up disagreeing with itself, and the warning names
#                        the files rather than counting them.
#                        UNKNOWN IS TREATED AS UNSET so an unreachable API cannot manufacture
#                        a false alarm, and an unset variable says nothing at all because
#                        that is the shipped default every adopter is in.
#                        THE SCANNER GOT ITS OWN CASES ONLY AFTER A MUTATION EMBARRASSED IT:
#                        feeding the verdict via stdin left workflows_not_reading_var
#                        completely untested, and swapping its pattern for `runs-on` passed
#                        every case -- a check on a check with nothing on the half that reads
#                        the repository.
#   2026-08-17 v0.9.0.20260817.0655 — report_runners(): AN OFFLINE SELF-HOSTED RUNNER IS NOT SILENCE.
#                        Once a repo points SCAFFOLD_RUNNER at a self-hosted label, a
#                        workflow whose runner is down does not FAIL -- it QUEUES, and
#                        `timeout-minutes` never applies because the job never starts. On the
#                        status page that is indistinguishable from a slow build, which is
#                        this file's own opening argument turned on the fix for it: trading
#                        "CI is red" for "CI is silent" is the one trade this project refuses.
#                        ANY STATUS THAT IS NOT `online` COUNTS AS DOWN, including ones this
#                        code has never seen. A check whose purpose is noticing absence must
#                        not read an unfamiliar status as healthy.
#                        Zero registered runners says NOTHING -- almost every repo is in that
#                        state and a line there is noise people learn to skip.
#                        report() still returns 0. It is a session-start report, not a gate,
#                        and quietly making it non-zero would change the exit code of every
#                        SessionStart hook that calls it. The line is loud instead.
#                        THE VERDICT IS SPLIT FROM THE FETCH so it has cases without a
#                        network -- and that split earned its keep immediately: the first
#                        version called `say`, WHICH DOES NOT EXIST IN THIS FILE, so it
#                        printed nothing at all. Four cases asserting only the return code
#                        passed over a silent function; the one asserting OUTPUT caught it.
#   2026-08-16 v0.8.0.20260816.0900 — A KNOWN, DATED CI OUTAGE CAN BE DECLARED. Actions on this account
#                        are stopped until September, so every session start printed a
#                        four-line emergency about a fact the reader already knew and could
#                        not act on — and this tree's own rule (tools/scaffold_version.sh) is
#                        that a warning nobody can action is the one that gets the whole check
#                        disabled. Losing ci_status would also lose alert reporting, which
#                        still works.
#                        `<!-- scaffold:ci-down-until YYYY-MM-DD <reason> -->` in AGENTS.md at
#                        column 0, read from the repo you are standing in, so an adopter whose
#                        CI is fine is unaffected.
#                        THREE PROPERTIES, AND EACH IS WHY IT IS A DATED DECLARATION RATHER
#                        THAN A FLAG: it NEVER says green (CI_UNVERIFIED stays set, the tag
#                        stays [..]); it EXPIRES, and the alarm returns louder past the date,
#                        because a suppression with no end is how a fortnight's workaround
#                        becomes the reason nobody noticed in November; and it reports itself
#                        when it is suppressing nothing, since a filter that removes nothing
#                        must say so.
#                        The selftest caught a real trap while being written: the helper sets
#                        CI_UNVERIFIED, and a `\$(...)` capture runs it in a subshell where
#                        that assignment is lost — which would suppress the alarm and leave
#                        the verdict green, the exact defect 0.7.0 fixed. Call sites set the
#                        flag themselves and BOTH directions are asserted.
#   2026-08-16 v0.7.0.20260816.0700 — THE VERDICT CONTRADICTED THE FINDING. Observed against a live
#                        billing block: the same run printed "CI IS NOT RUNNING on origin/main"
#                        and then "[OK] CI green on main" eight lines below. Two of the three
#                        did-not-run branches set CI_UNVERIFIED and the newest one did not, so
#                        the tool detected the outage and reported green in the one line a
#                        reader skims to. This programme's signature defect, inside the check
#                        written to catch it — and the rule it broke is already stated at the
#                        bottom of this file.
#                        Guarded STRUCTURALLY, because the unit tests exercise the reducer and
#                        this bug lives in the shell around it: every `[!!]` alarm whose text
#                        says CI did not run must set the flag, and the count of such alarms is
#                        asserted so deleting them is not a way to pass. Scoped deliberately —
#                        alert alarms are a different axis and `CI IS RED` is verified-and-red.
#   2026-08-13 v0.4.0 — THIS FILE HAD NEVER ONCE REPORTED A RED CI. The failure reducer was
#                        `f"...{r.get(\"conclusion\")}..."` — a backslash-escaped quote inside
#                        an f-string expression, inside a single-quoted shell string. That is
#                        a SyntaxError. Its stderr went to `2>/dev/null`, so `failed_main` was
#                        ALWAYS EMPTY and the verdict was ALWAYS `[OK] CI green`. Present in
#                        3c676ad, the commit that created the tool, on 2026-08-09.
#                        NINE SELFTEST CASES ASSERTED THE REDUCER AND ALL NINE PASSED, because
#                        selftest() carried its OWN tidier copy of the logic. A test that
#                        re-implements its subject proves the author understood it and proves
#                        nothing about what ships. `must_gate()` in a different costume.
#                        Found by a live outage: three repos red on a billing stop while
#                        --verbose said green. The tool written because "local green is not CI
#                        green" could not say otherwise — including through the four-hour red
#                        build it was written in response to.
#                        Fixes: ONE reducer in REDUCER_PY, run by report() and by the
#                        selftest, verified by reintroducing the SyntaxError and watching the
#                        suite go red. No f-strings, no nested quotes, no swallowed stderr.
#                        AND A BILLING STOP IS NOT A BROKEN BUILD. GitHub creates the run and
#                        marks it failed, so every red-build heuristic sends the reader
#                        hunting a defect that is not there. A job that never started has zero
#                        steps; that is the signal, and it does not depend on GitHub's wording.
#   2026-08-13 v0.3.0 — A CI THAT STOPPED RUNNING LOOKED EXACTLY LIKE A CI THAT PASSED.
#                        Everything here asked "did anything FAIL"; nothing asked "did
#                        anything RUN", and `[ -n "$runs" ] || return 0` returned success on
#                        an EMPTY run list without printing a word, even under --verbose.
#                        Now asserts a run EXISTS for the tip of the default branch, which is
#                        the only observation that separates green from stopped.
#                        NOT HYPOTHETICAL: a $0 Actions budget cap goes on this account with
#                        ~190 of 2,000 included minutes left. Every repo here is private, so
#                        when it bites every push runs nothing and this would have said
#                        "[OK] CI green" about a commit no gate had ever seen. Sixth instance
#                        of the shape (`must-run` printing "all of which ran", `[OK ] RAM
#                        check skipped`, sweeps behind a macOS-missing `timeout`, a scanner
#                        that read zero files, a reviewer returning NONE) and the FIRST seen
#                        coming rather than found afterwards.
#                        THE ORACLE RULE, per 05-TEST-PLAN.md: state what would be observed
#                        if the check were silently wrong, and assert that. Here nothing
#                        would be observed, which is what success looks like — so the
#                        assertion has to be presence-of-a-run, not absence-of-a-failure.
#                        ci_tag()/ci_word() are now the ONLY place a verdict is phrased: two
#                        sites each built their own green sentence, so the guard could only
#                        be greped for as a literal and flagged the GUARDED one. Funnelling
#                        both makes the assertion exact.
#   2026-08-09 v0.2.1 — SUCCESS SAYS SOMETHING (#182). This printed zero bytes and
#                        exited 0 on a clean repo — indistinguishable from 'the tool did
#                        nothing', on the one check whose stated purpose is telling zero
#                        apart from not-enabled. The new line counts the alert features
#                        that ANSWERED, because '0 across 3' and '0 across 1' are very
#                        different assurances and used to print identically.
#   2026-08-09 v0.2.0 — Reports open security alerts as well as failed runs, with THREE
#                        answers rather than two: alerts, none, or COULD NOT ASK. The last
#                        prints as silence if you only look for a number, and it was the
#                        true state here — all three of this project's repos had
#                        Dependabot, code scanning and secret scanning disabled while the
#                        release gate had been prescribing a dependency audit for months.
#                        Nobody was ignoring alerts; there were none to ignore.
#                        The finding with teeth is the TRANSITION: alerting off costs
#                        nothing with no manifest to scan, so that is silent, but a repo
#                        that GAINS dependencies while nothing watches them is warned —
#                        and that arrives on an ordinary commit nobody reads as a security
#                        change. localcoder is the live case: `dependencies = []` with a
#                        comment saying stdlib-only is a feature, one line from being real.
#   2026-08-09 v0.1.0 — New. Every check this repo ships runs LOCALLY, and the one place a
#                        failure actually lives is GitHub. Measured 2026-08-08: this
#                        project's own dev repo was red for four hours while every local
#                        check passed, because the failing step lints by a header the local
#                        run never exercised. It was the OWNER who noticed, not the
#                        toolchain — "I keep getting github errors you need to check those
#                        too". The lesson went into ai/MEMORY.md as *check the repo's CI,
#                        not only its local checks*, and then sat there as a note, which is
#                        this project's most-repeated failure: a rule with no checker behind
#                        it is not a rule. This file is the checker.
#                        Same day, a second instance: a merged PR left main red for twenty
#                        minutes and the next three commits were made on top of it.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# SILENT WHEN IT CANNOT ANSWER, LOUD WHEN IT CAN.
#
# This runs at session start, through the SessionStart hook, on whatever network the
# developer happens to be on. `tools/scaffold_version.sh` already settled the precedent and
# the reason: "a version check that nags on a plane is one people disable". A check that
# prints an error because a laptop is offline teaches people to skip session start, and then
# none of the other checks run either.
#
# So: no gh, not authenticated, no GitHub remote, or the call fails — say nothing at all and
# exit 0. A missing answer is not a red build. The distinction that matters is between "CI
# is failing" and "I could not ask", and only the first is worth interrupting for.
TIMEOUT_SECS="${CI_STATUS_TIMEOUT:-8}"

# SET WHEN NOTHING RAN FOR THE COMMIT UNDER TEST. Every "[OK] CI green" line below is a
# claim about a workflow's VERDICT, and none of them is true when no workflow produced one.
# Without this the fix would report the missing run and then reassure the reader two lines
# later, which is worse than either message alone.
CI_UNVERIFIED=""

# SET WHEN A COMPLETED RUN COVERED THE COMMIT AND FAILED. THE THIRD ANSWER (#312).
# CI_UNVERIFIED above means "nothing judged this commit". It is deliberately NOT set for a
# red build -- a red build is the opposite of unverified, and the structural check in the
# selftest exempts the red alarm for exactly that reason. The exemption was right and had
# nowhere to go: with one flag, "verified and RED" and "verified and green" produced the
# same sentence, so report() printed the red alarm and ci_word() said green about the same
# sha four lines below it. Two states cannot carry three answers.
CI_RED=""

# ==== A KNOWN, DATED CI OUTAGE ============================================================
#
# Declared in AGENTS.md at column 0, exactly like every other marker this tree reads:
#
#     <!-- scaffold:ci-down-until 2026-09-01 Actions billing blocked; preflight is the gate -->
#
# WHY THIS EXISTS. From 2026-08-13 the account's Actions are stopped and will not return
# until September. Without a declaration, every session start prints a four-line emergency
# about a fact the reader already knows and cannot act on — and this project's own rule,
# written in tools/scaffold_version.sh, is that a warning nobody can action is the one that
# gets the whole check disabled. Losing ci_status entirely would also lose the alert
# reporting, which still works.
#
# WHAT IT MUST NOT DO, and these are the reasons it is a declaration and not a flag:
#
#   1. IT NEVER SAYS GREEN. CI_UNVERIFIED stays set for the whole outage. The verdict line
#      reads [..] not [OK], because nothing verified anything. Quieter is not the same as
#      passing, and collapsing those two is the defect this file exists to prevent.
#   2. IT EXPIRES. Past the date, the alarm comes back LOUDER and names the declaration as
#      overdue. A suppression with no end is how a temporary workaround becomes permanent
#      silence, and the date is the only part that cannot rot quietly.
#   3. IT REPORTS ITSELF WHEN IT SUPPRESSES NOTHING. If CI is running again while the
#      declaration is still in force, that is said out loud and the line is asked to be
#      deleted — a filter that removes nothing must say so.
#
# Read from the repo you are standing in, so an adopter whose CI is fine is unaffected.
CI_DOWN_UNTIL=""
CI_DOWN_REASON=""
if [ -f AGENTS.md ]; then
  _cd_line="$(grep -oE '^<!--[[:space:]]*scaffold:ci-down-until[[:space:]]+[0-9]{4}-[0-9]{2}-[0-9]{2}[^>]*' \
                AGENTS.md 2>/dev/null | head -1)"
  if [ -n "$_cd_line" ]; then
    CI_DOWN_UNTIL="$(printf '%s' "$_cd_line" | awk '{print $3}')"
    CI_DOWN_REASON="$(printf '%s' "$_cd_line" | cut -d' ' -f4- | sed 's/[[:space:]]*--$//')"
  fi
fi
# LEXICOGRAPHIC, DELIBERATELY. ISO-8601 sorts correctly as text, so this needs no date
# arithmetic — which on this fleet means no `date -d` (GNU) versus `date -v` (BSD) split,
# the same portability trap that has already cost this tree a Linux-only CI failure.
ci_outage_active() {
  [ -n "$CI_DOWN_UNTIL" ] || return 1
  [ "$(date -u +%Y-%m-%d)" \< "$CI_DOWN_UNTIL" ] || return 1
}
ci_outage_expired() {
  [ -n "$CI_DOWN_UNTIL" ] || return 1
  ci_outage_active && return 1
  return 0
}

# ==== PROPERTIES 2 AND 3 WERE ANNOUNCED AND NOT IMPLEMENTED (#213) =========================
#
# The header of this file claims three properties for a `ci-down-until` declaration. An adopter
# seed-tested all three against a real repository and reported that only the FIRST held:
#
#   1. IT NEVER SAYS GREEN.                                         -- held
#   2. IT EXPIRES, and past the date the alarm returns LOUDER.      -- ci_outage_expired() was
#                                                                      defined and called from
#                                                                      nothing but its own
#                                                                      selftest
#   3. IT REPORTS ITSELF WHEN IT SUPPRESSES NOTHING.                -- never written at all
#
# A function whose only callers are its own tests is this repository's most-repeated defect, and
# here it was worse than dead code: the property was DOCUMENTED, so the record said the alarm
# would return and nothing would have returned it. The declaration in three AGENTS.md files
# names 2026-09-01, and on 2026-09-02 nothing would have said a word.
ci_outage_overdue_note() {
  ci_outage_expired || return 1
  CI_UNVERIFIED=1
  echo "[!!] THE CI-DOWN DECLARATION IS OVERDUE. It expired on ${CI_DOWN_UNTIL} and is still"
  echo "     in AGENTS.md, which means this tool has been treating unverified as expected"
  echo "     since then. Delete the line:"
  echo "       <!-- scaffold:ci-down-until ... -->   in AGENTS.md, at column 0"
  echo "     Until it goes, every report below reads softer than the truth."
  return 0
}

# PROPERTY 3. A declaration that suppresses nothing is worse than none: it is a live excuse
# attached to a working CI, and the next real outage arrives already forgiven.
ci_outage_suppressing_nothing_note() {
  ci_outage_active || return 1
  [ "${1:-no}" = "yes" ] || return 1
  echo "[..] CI IS RUNNING AGAIN while the ci-down declaration is still in force"
  echo "     (until ${CI_DOWN_UNTIL}). It is suppressing nothing, so delete it now rather"
  echo "     than on its expiry date — a stale declaration forgives the next real outage."
  echo "       <!-- scaffold:ci-down-until ... -->   in AGENTS.md, at column 0"
  return 0
}

# THE ONE PLACE THE KNOWN-OUTAGE LINE IS PHRASED, for the same reason ci_word exists: three
# call sites each writing their own sentence is three places to forget CI_UNVERIFIED.
# Returns 0 when it printed (caller should stay quiet), 1 when the caller should alarm.
# NOTE FOR ANYONE ADDING A CALL SITE: set CI_UNVERIFIED=1 BEFORE calling this, as all three
# existing branches do. The assignment below is belt-and-braces and is LOST if this function
# is ever called in a subshell — `msg="$(ci_outage_note)"` would suppress the alarm and leave
# the verdict green, which is the exact defect 0.7.0 fixed. The selftest asserts the direct
# call sets it, and asserts the captured form does not, so the trap is documented by a case
# rather than by a comment alone.
ci_outage_note() {
  ci_outage_active || return 1
  CI_UNVERIFIED=1
  echo "[..] CI is down by declaration until ${CI_DOWN_UNTIL} — nothing ran, and that is expected."
  [ -n "$CI_DOWN_REASON" ] && echo "     ${CI_DOWN_REASON}"
  echo "     tools/preflight.sh is the ONLY gate until then. Run it before every push."
  echo "     Declared in AGENTS.md; delete that line when Actions return."
  return 0
}

# ==== THE REDUCER LIVES HERE, ONCE, AND THE SELFTEST RUNS THIS EXACT STRING ==============
#
# It used to be written out twice: once inline in report(), once again inside selftest() as a
# tidier copy. The copy parsed. The shipped one did not — `f"...{r.get(\"conclusion\")}..."`
# is a SyntaxError, its stderr went to /dev/null, `failed_main` was therefore always empty,
# and this file printed `[OK] CI green` unconditionally FROM THE COMMIT THAT CREATED IT
# (3c676ad, 2026-08-09). Nine selftest cases asserted the reducer's behaviour and every one
# of them passed, against a re-implementation that shared no bytes with the real thing.
#
# It was found on 2026-08-13 by a live outage: three repositories red on a billing stop,
# `ci_status.sh --verbose` reporting green, and the failure visible in `gh run list` two
# commands away. The tool whose entire stated purpose is "local green is not CI green" was
# structurally incapable of saying otherwise, including through the four hours the dev repo
# sat red on 2026-08-08 that this file was written in response to.
#
# NO f-STRINGS AND NO NESTED QUOTES. The bug was purely quoting: a `\"` inside an f-string
# expression, inside a single-quoted shell string. %-formatting has neither hazard, and this
# is a place where the boring construct is the correct one.
REDUCER_PY='
import json, sys
try:
    rows = json.load(sys.stdin)
except Exception:
    sys.exit(0)
# Newest run PER WORKFLOW only. An older failure that a later run has already fixed is not
# a current failure, and reporting it would be the false positive that gets this disabled.
#
# KEYED ON workflowName, NOT name, AND THE DIFFERENCE IS THE WHOLE BUG. `name` is the RUN
# DISPLAY TITLE, which Dependabot makes UNIQUE PER RUN by appending its update id:
#     npm_and_yarn in /. for uuid - Update #1587421234
#     npm_and_yarn in /. for uuid - Update #1587416440
# Keyed on that, every Dependabot run is trivially "the newest of its name", so the dedupe
# never fires for them and a superseded failure is reported as current FOREVER -- no future
# run can ever share that name to supersede it. Measured on collectionapp 2026-09-22: two
# spent uuid security-update runs on old commits reported as red while the tip was green on
# every workflow, so the tool printed "CI IS RED on origin/master" and named master green
# two lines later. `workflowName` is the stable identity ("Dependabot Updates" for all four),
# and under it the newest one SUCCEEDED, which is the true answer.
#
# This is the alarm-that-cannot-go-quiet shape, and it is the one that gets a checker
# switched off: a reader who sees a red they cannot clear stops reading the red.
#
# workflowName is requested in the --json list at the call site, and `gh` FAILS LOUDLY on a
# field it does not know rather than omitting it -- so the fallback below is unreachable in
# practice and is not a silent degrade path.
seen, out = set(), []
for r in rows:
    n = r.get("workflowName") or r.get("name")
    if n in seen:
        continue
    seen.add(n)
    # RED IS AN ALLOWLIST. This was a denylist -- anything not "ok" was reported under
    # "fix or revert" -- so `stale`, and any conclusion GitHub adds later, became a
    # positive accusation about someone code over a run that reached no verdict. Red is a
    # claim; an unrecognised conclusion does not license it. Non-verdicts are COVERS_PY.
    # tools/preflight.sh classifies the same conclusions for a DIFFERENT question, and the
    # two must not be harmonised into one: an alarm asks "is anything broken", a
    # precondition asks "has anything been decided". Both now refuse to read a non-verdict
    # as either a pass or an accusation, which is the part that does agree.
    red = ("failure", "timed_out", "startup_failure", "action_required")
    if r.get("status") == "completed" and r.get("conclusion") in red:
        # REPORTS r["name"], THE DISPLAY TITLE, while keying on workflowName above. The key
        # has to be the stable identity or the dedupe cannot work; the message has to be the
        # specific run or the reader cannot act on it. They are different jobs.
        out.append("       %s  %s\n       %s" % (r.get("conclusion"), r.get("name") or n, r.get("url")))
print("\n".join(out))
'


# THE ONLY PLACE A CI VERDICT IS PHRASED. Two call sites used to each build their own green
# sentence, so guarding them meant guarding both and the selftest could only grep for a
# literal — which cannot tell a guarded claim from an unguarded one. It reported the guarded
# one as a defect, which is a false positive in the check written to prevent false all-clears.
# Funnelling both through here makes the assertion exact: the literal must not appear at all.
ci_tag() {   # [!!] when a run covered the tip and failed, [..] when nothing did, else [OK]
  # RED IS ASKED FIRST. Both flags can be set at once -- the tip can be unjudged while an
  # older run of another workflow is red -- and of the two true statements the actionable
  # one wins. Either way the [OK] a reader skims to is unreachable, which is the property
  # that matters.
  if [ -n "${CI_RED:-}" ]; then printf '[!!]'
  elif [ -n "$CI_UNVERIFIED" ]; then printf '[..]'
  else printf '[OK]'; fi
}
ci_word() {  # ci_word <branch-label>
  # THE VERDICT NAMES THE COMMIT IT IS ABOUT (#289). "CI green on main" is a claim about a
  # branch, and a branch moves. The question a reader actually has is whether the thing they
  # just pushed is green, and only a SHA answers that.
  _cw_at=""
  [ -n "${head_sha:-}" ] && _cw_at=" @ $(printf '%.7s' "$head_sha")"
  if [ -n "${CI_RED:-}" ]; then
    printf 'CI IS RED on %s%s (a completed run FAILED)' "$1" "$_cw_at"
  elif [ -n "$CI_UNVERIFIED" ]; then
    printf 'CI NOT VERIFIED on %s%s (no completed run for the tip)' "$1" "$_cw_at"
  else
    printf 'CI green on %s%s' "$1" "$_cw_at"
  fi
}

# macOS ships no `timeout`(1) — it is GNU coreutils, and assuming it is the same class of
# mistake as `mktemp -t`, which meant scaffold_upgrade.sh had never run on Linux while its
# own checks passed on macOS. This is portable to both.

# DOES A RUN COVER THE TIP, AND HAS IT FINISHED? Three answers, hoisted to a constant so the
# selftest can run THE SHIPPED CODE (#289).
#
# The selftest used to carry its own tidier copy of this, and that is why changing the shipped
# probe left five cases green while the behaviour moved underneath them. This file already
# states the rule 200 lines above, about the reducer, and then broke it here: a test that
# re-implements its subject proves the author understood the logic and nothing about what
# ships. Same discipline as REDUCER_PY and FIRSTFAIL_PY — one string, two callers.
#
# `pending` is the answer that did not exist. A queued run for the tip satisfied "a row
# exists", and the green verdict then came from the previous commit.
COVERS_PY='
import json, os, sys
try:
    rows = json.load(sys.stdin)
except Exception:
    print("unknown"); sys.exit(0)
sha = os.environ.get("HEAD_SHA", "")
mine = [r for r in rows if r.get("headSha") == sha]
if not mine:
    print("no")
else:
    # PER WORKFLOW, NOT PER COMMIT. "any completed run is an answer" was right about
    # RE-RUNS -- a finished copy of a workflow beside a queued copy of the SAME workflow
    # really is an answer -- and wrong about DIFFERENT workflows, because one workflow
    # completing says nothing whatever about another.
    #
    # Measured 2026-09-08: pushing 54697ab started two workflows. "Mirror to work-mirror"
    # finished in seconds; "Scaffold Check", the actual gate, ran for another 65 seconds.
    # This printed "CI green on main @ 54697ab" for the whole of that minute -- the exact
    # defect the pending answer was added to remove, one level down. It survived because the
    # case that pinned the rule used rows with NO workflow name, so it could not tell the two
    # situations apart.
    #
    # Grouping keeps the original rule intact: a workflow is answered when ANY of its runs
    # for this commit completed, and the commit is answered when EVERY workflow is. A
    # permanently queued workflow now holds the verdict at pending, which is correct: it is
    # unverified, and refusing to call that green is the whole job here.
    by_wf = {}
    for r in mine:
        wf = r.get("name") or ""
        by_wf.setdefault(wf, []).append(r)
    # A COMPLETED RUN IS NOT AUTOMATICALLY AN ANSWER (the #312 defect, one layer down).
    # This asked only whether a run FINISHED, never what it concluded, so a CANCELLED run
    # answered "yes" -- and since the reducer correctly declines to call cancelled a
    # failure, the verdict line then printed the green sentence. A non-verdict reading as
    # a pass, in the tool written to prevent that.
    #
    # `novrd` is the fourth answer: every workflow finished, at least one reached no
    # verdict. Not `pending` (nothing is still running, so waiting is wrong advice) and
    # not `no` (runs did exist). STILL-RUNNING OUTRANKS IT -- the commit may yet be
    # answered, and novrd would close a door that is open.
    verdicts = ("success", "failure", "timed_out", "startup_failure",
                "action_required", "skipped", "neutral")
    groups = list(by_wf.values())
    if all(any(r.get("status") == "completed" and r.get("conclusion") in verdicts
               for r in rs) for rs in groups):
        print("yes")
    elif all(any(r.get("status") == "completed" for r in rs) for rs in groups):
        print("novrd")
    else:
        print("pending")
'

# WHICH WORKFLOW LEFT THE GAP. Same grouping and same verdict list as COVERS_PY, because a
# name that disagreed with the state it explains is worse than no name. Split out so it has
# cases on it without a network, exactly like REDUCER_PY and COVERS_PY.
#
# The gap alone could not be acted on: "Scaffold Check reached no verdict" is a thing to
# chase, a superseded mirror is a thing to ignore, and one sentence covered both.
NOVRD_PY='
import json, os, sys
try:
    rows = json.load(sys.stdin)
except Exception:
    sys.exit(0)
sha = os.environ.get("HEAD_SHA", "")
verdicts = ("success", "failure", "timed_out", "startup_failure",
            "action_required", "skipped", "neutral")
by_wf = {}
for r in rows:
    if r.get("headSha") != sha:
        continue
    by_wf.setdefault(r.get("name") or "", []).append(r)
out = []
for wf in sorted(by_wf):
    rs = by_wf[wf]
    if any(r.get("status") == "completed" and r.get("conclusion") in verdicts for r in rs):
        continue
    done = [r for r in rs if r.get("status") == "completed"]
    if done:
        out.append("%s (%s)" % (wf, done[0].get("conclusion")))
print("\n".join(out))
'

# The run id of the first current failure — used only to ask whether its job ever started.
# Same no-f-string, no-nested-quote discipline as REDUCER_PY, and for the same reason.
FIRSTFAIL_PY='
import json, sys
try:
    rows = json.load(sys.stdin)
except Exception:
    sys.exit(0)
# THE SAME LIST AS REDUCER_PY, AND IT HAS TO BE. This picks the run whose job count is
# checked for the billing case; if it disagreed about what counts as red it would pick a
# different run than the one reported, or none at all.
red = ("failure", "timed_out", "startup_failure", "action_required")
for r in rows:
    if r.get("status") == "completed" and r.get("conclusion") in red:
        print((r.get("url") or "").rsplit("/", 1)[-1])
        break
'

run_capped() {   # run_capped <command...>; exits 124 on timeout
  local out rc pid
  out="$(mktemp "${TMPDIR:-/tmp}/ci_status.XXXXXX")" || return 1
  "$@" >"$out" 2>/dev/null &
  pid=$!
  ( sleep "$TIMEOUT_SECS"; kill -9 "$pid" 2>/dev/null ) >/dev/null 2>&1 &
  local watchdog=$!
  wait "$pid" 2>/dev/null; rc=$?
  kill -9 "$watchdog" 2>/dev/null; wait "$watchdog" 2>/dev/null
  cat "$out"; rm -f "$out"
  return $rc
}

usable() {
  command -v gh >/dev/null 2>&1 || return 1
  git rev-parse --git-dir >/dev/null 2>&1 || return 1
  git remote get-url origin 2>/dev/null | grep -q 'github\.com' || return 1
  run_capped gh auth status >/dev/null 2>&1 || return 1
  return 0
}

# THE DEFAULT BRANCH IS WHAT "IS THE PROJECT BROKEN" MEANS. A red feature branch is work in
# progress; red main is everyone's problem and is the state people build on top of without
# noticing — which is exactly what happened here on 2026-08-08.
default_branch() {
  local b
  b="$(run_capped gh repo view --json defaultBranchRef --jq .defaultBranchRef.name)"
  [ -n "$b" ] && { printf '%s' "$b"; return 0; }
  printf 'main'
}

# ------------------------------------------------- who is asking, and can they see this repo
#
# `gh auth status` SUCCEEDS FOR THE WRONG ACCOUNT, and every answer downstream then looks
# like an outage. usable() has always asked "is gh logged in" — which is not the question.
# The question is whether the account it is logged in AS can see THIS repository.
#
# OBSERVED 2026-09-11 at session start, on four repositories at once: gh had silently become
# a second account with no access to these repos. Reproduced with that account's token
# rather than reasoned about:
#
#     gh auth status                            -> rc 0       (usable() passes)
#     gh api repos/<owner>/<repo>               -> HTTP 404
#     gh run list --branch main                 -> HTTP 404 on stderr
#
# run_capped() sends stderr to /dev/null, so the 404 vanished and `$runs` came back EMPTY —
# the same observation as a repository whose workflows have stopped. Four repos printed
# "[!!] NO WORKFLOW RUNS AT ALL ... nothing has been checked remotely" while CI was green on
# every one of them. The tool written to stop a false all-clear produced a false ALARM
# instead, which sends a reader hunting a dead CI that is not dead — and, worse, teaches
# them that this line is noise.
#
# FOUR REPOSITORIES REPORTING ZERO RUNS AT ONCE IS NOT FOUR OUTAGES. That was the cheapest
# available signal and no version of this tool was looking at it.
#
# The fix is not to detect the account — it is to stop claiming an empty answer is an
# answer. An empty run list means one of two things, and this asks the repository itself
# which: if the repo does not answer either, we could not ask, and COULD NOT ASK is the
# third outcome this project already treats as distinct from both pass and fail.

# SPLIT FROM THE FETCH BECAUSE IT HAD TO BE — the same lesson as classify_var_value() above.
# Parsing a remote URL is the half that can be tested offline; a networked function with the
# parser inside it has no test at all.
repo_nwo() {   # repo_nwo [url] -> owner/repo, or rc 1 if it is not a github remote
  # $# NOT -n: an EMPTY argument is an input to judge, not an absent one to substitute for.
  # The selftest caught this — `repo_nwo ""` fell through to the live remote and the case
  # asserting an empty url is refused passed by reading this repository's own origin.
  local u
  if [ "$#" -gt 0 ]; then u="$1"; else u="$(git remote get-url origin 2>/dev/null)"; fi
  [ -n "$u" ] || return 1
  u="${u%/}"; u="${u%.git}"; u="${u%/}"
  case "$u" in
    git@github.com:*)       u="${u#git@github.com:}" ;;
    ssh://git@github.com/*) u="${u#ssh://git@github.com/}" ;;
    https://*@github.com/*) u="${u#*@github.com/}" ;;
    https://github.com/*)   u="${u#https://github.com/}" ;;
    http://github.com/*)    u="${u#http://github.com/}" ;;
    *) return 1 ;;
  esac
  # OWNER/REPO AND NOTHING ELSE. A trailing path would build a URL that 404s for a reason
  # that has nothing to do with the account, which is the misdiagnosis this exists to stop.
  case "$u" in
    */*/*|*/) return 1 ;;
    */*)      [ -n "${u%%/*}" ] && [ -n "${u#*/}" ] && printf '%s' "$u" || return 1 ;;
    *)        return 1 ;;
  esac
}

# 0 = we could not ask and have said so; 1 = the remote answered, carry on.
# CALL SITES MUST SET CI_UNVERIFIED THEMSELVES — see the note on ci_outage_note(); a
# $(...) capture runs this in a subshell where the assignment below is lost.
# SPLIT FROM THE FETCH, for the third time in this file and for the same reason each time:
# the decision is the part worth testing and a networked function with it inside has no test.
#
# ZERO IS AN ANSWER. That is the whole of this function and it is the half a careless `-n`
# check gets wrong: a repository with genuinely no runs returns `total_count: 0`, which is a
# true statement about CI, and treating it as "could not ask" would suppress the real
# no-runs alarm on exactly the repositories that need it. Anything that is not a run of
# digits -- empty, `null`, a JSON error body, an HTML error page -- means no count came back.
classify_runs_probe() {   # classify_runs_probe <total_count output> -> answered | could-not-ask
  case "$1" in
    ''|*[!0-9]*) printf 'could-not-ask' ;;
    *)           printf 'answered' ;;
  esac
}

cannot_ask_note() {
  local nwo who total
  nwo="$(repo_nwo)" || return 1

  # PROBE THE CAPABILITY WHOSE EMPTY RESULT IS BEING INTERPRETED, not a neighbouring one.
  #
  # The first version of this asked `repos/<nwo>` — can we see the repository. That is the
  # right question for the account case and the WRONG one for the general case: a token with
  # `repo` and without `actions` reads the repository fine and 403s on the runs endpoint, and
  # the verdict below would go back to announcing an outage. Asking `actions/runs` answers
  # exactly what the caller needs to know — could this call have returned runs if there were
  # any — and `total_count` distinguishes "200, and there are none" from "we never got a 200"
  # in one field.
  total="$(run_capped gh api "repos/$nwo/actions/runs?per_page=1" --jq .total_count 2>/dev/null)"
  [ "$(classify_runs_probe "$total")" = "answered" ] && return 1

  CI_UNVERIFIED=1
  who="$(run_capped gh api user --jq .login 2>/dev/null)"
  echo "[!!] COULD NOT ASK GitHub for the runs on ${nwo} — this is not an answer about CI."
  echo "       asking as: ${who:-<gh did not say>}"
  echo "       The run list came back empty and the runs endpoint did not answer either, so"
  echo "       \"no runs\" and \"could not look\" are indistinguishable from here. Neither is"
  echo "       a pass and neither is a failure."
  # AND SAY WHICH OF THE TWO IT IS. Both produce an empty run list and they have different
  # fixes, so a note that stopped at "could not ask" would send half its readers to the wrong
  # one. The repository probe is the DISCRIMINATOR, which is the job it is actually good at.
  if [ "$(run_capped gh api "repos/$nwo" --jq .full_name 2>/dev/null)" = "$nwo" ]; then
    echo "       The REPOSITORY answers and the runs endpoint does not, so this is a"
    echo "       permission on Actions rather than on the repo — most likely a token without"
    echo "       the \`actions\`/\`workflow\` scope, or Actions restricted for this account."
    echo "         gh auth status                     # look at the token scopes"
    echo "         gh auth refresh -h github.com -s workflow"
  else
    echo "       The repository does not answer either, so gh is almost certainly"
    echo "       authenticated as an account without access to ${nwo%%/*}:"
    echo "         gh auth status                     # which account is active"
    echo "         gh auth switch --user <account that can see ${nwo%%/*}>"
    echo "       Measured 2026-09-11: gh had silently switched accounts and FOUR repositories"
    echo "       reported zero runs at once while CI was green on all four."
  fi
  echo "       Until this resolves nothing here has looked at the remote — preflight is the gate."
  return 0
}


# ---------------------------------------------------------------- --check (the runner value)
#
# THE SHIPPED WORKFLOW HAS TOLD PEOPLE TO RUN THIS SINCE BEFORE IT EXISTED.
# `.github/workflows/scaffold-check.yml:87` says, in the paragraph about a malformed value
# killing the run at parse time: "`tools/ci_status.sh --check` validates it locally against
# the same rules." It did not. The flag has never existed at any version, and the sentence
# sits exactly where a reader is most likely to follow it -- mid-diagnosis of the failure it
# claims to diagnose. Reported by an adopter (collectionapp) against 0.105.0, who found it in
# the .yml after my own flag audit scanned only *.md and missed it.
#
# ADDED RATHER THAN DELETED, because the need the sentence describes is real and nothing else
# answers it: `fromJSON` on a malformed value fails during expression evaluation, BEFORE any
# step exists, so the run shows no steps, no log, and an error that never names the variable.
# The classifier it needs was already here, already split from the fetch, already selftested --
# only the entry point was missing.
#
# TAKES A VALUE OR READS THE REPOSITORY. The whole point is to check BEFORE the push, and a
# candidate value is not in GitHub yet, so an argument is the primary form and the fetch is the
# convenience. Offline with an argument, which is what makes it usable in a pre-push hook.
check_runner_value() {
  local val="${1-}" src state
  if [ "$#" -gt 0 ]; then
    src="the value you passed"
  else
    if ! usable; then
      echo "[SKIP] ci_status --check: no gh, or not a GitHub repository."
      echo "       Pass the value instead:  tools/ci_status.sh --check '[[\"self-hosted\",\"Linux\"]]'"
      echo "       NOT verified. Exit 3 is could-not-check, not a pass."
      return 3
    fi
    # READ THE EXIT CODE, NOT THE OUTPUT. `gh api` on a variable that does not exist prints a
    # 404 JSON BODY to stdout and exits non-zero. Taking the output alone fed that body to the
    # classifier, which correctly called it malformed -- so a repository that had simply never
    # set the variable was told its configuration was broken. A false finding, in the gate
    # written to prevent one, found the first time it ran anywhere but where it was built.
    local rc_list=0 rc_one=0
    val="$(run_capped gh api "repos/{owner}/{repo}/actions/variables/$RUNNER_VAR_LIST" --jq .value 2>/dev/null)" || rc_list=$?
    [ "$rc_list" = 0 ] || val=""
    src="SCAFFOLD_RUNNERS in this repository"
    if [ -z "$val" ] || [ "$val" = "null" ]; then
      local single
      single="$(run_capped gh api "repos/{owner}/{repo}/actions/variables/$RUNNER_VAR" --jq .value 2>/dev/null)" || rc_one=$?
      [ "$rc_one" = 0 ] || single=""
      if [ -n "$single" ] && [ "$single" != "null" ]; then
        echo "[OK ] SCAFFOLD_RUNNERS is not set; SCAFFOLD_RUNNER=$single is, and the workflow"
        echo "      wraps it into [\"$single\"]. That is the documented fallback, not a defect."
        return 0
      fi
      echo "[OK ] neither variable is set — every job runs on ubuntu-latest."
      echo "      That is the documented default. Nothing is malformed."
      return 0
    fi
  fi

  state="$(classify_list_value "$val")"
  case "$state" in
    set)
      echo "[OK ] $src parses as a runner list."
      printf '%s' "$val" | python3 -c '
import json, sys
d = json.loads(sys.stdin.read())
for i, e in enumerate(d):
    labels = [e] if isinstance(e, str) else e
    print("       leg %d -> a runner carrying ALL of: %s" % (i + 1, ", ".join(labels)))
print("       %d matrix leg(s). A leg with no matching ONLINE runner QUEUES FOREVER —" % len(d))
print("       it does not fail, and nothing goes red. Check with:")
print("         gh api repos/{owner}/{repo}/actions/runners --jq \x27.runners[] | \"\\(.name) \\(.status)\"\x27")
' 2>/dev/null
      return 0 ;;
    empty)
      echo "[OK ] $src is empty — the workflow falls through to ubuntu-latest."
      return 0 ;;
    *)
      echo "[!!] $src is MALFORMED as a runner list:"
      echo "       $val"
      echo ""
      echo "     fromJSON fails during EXPRESSION EVALUATION, before any step exists. The run"
      echo "     shows no steps, no log, and an error that never names the variable — which is"
      echo "     indistinguishable from a broken runner unless something says so here."
      echo ""
      echo "     It must be a JSON array of strings, or of arrays of strings:"
      echo "       '[\"ubuntu-latest\"]'"
      echo "       '[[\"self-hosted\",\"Linux\"]]'"
      echo "       '[[\"self-hosted\",\"macOS\"],[\"self-hosted\",\"Linux\"]]'"
      return 1 ;;
  esac
}

# ---------------------------------------------------------------- security alerts
#
# THREE ANSWERS, NOT TWO: alerts, none, or COULD NOT ASK. The third is the one that gets
# lost, and it is the one this project cares about — ai/PLANNING.md rates a false all-clear
# as strictly worse than a false positive because it is silent. "0 open alerts" and "the
# feature is off" both print nothing if you only look for a number.
#
# Measured 2026-08-09: all three of this project's repos had Dependabot, code scanning and
# secret scanning DISABLED, and the release gate had been telling people to run a dependency
# audit since it was written. Nobody was ignoring alerts; there were none to ignore, and no
# way to tell that from being clean.
#
# WHAT IS AND IS NOT AVAILABLE, so the report does not nag about the impossible:
#   - Dependabot alerts: free on every repo, public or private. Asked for always.
#   - Code scanning / secret scanning: on a PRIVATE repo these need paid Advanced Security.
#     A 404 there means "not on this plan", not "you forgot", so it is reported once at
#     --verbose and never as a finding.
alerts_count() {   # alerts_count <kind>; prints a number, or empty when it cannot ask
  local kind="$1" out
  out="$(run_capped gh api "repos/{owner}/{repo}/$kind/alerts?state=open&per_page=100" \
          --jq 'length' 2>/dev/null)"
  case "$out" in ''|*[!0-9]*) printf '' ;; *) printf '%s' "$out" ;; esac
}

# THE STATE THAT SILENTLY BECOMES WRONG.
#
# With no dependency manifest, alerting off costs nothing — there is nothing to scan, and
# warning about it would be noise that trains people to ignore this whole report. The risk
# is not "alerts are off"; it is "alerts are off AND this repo now has dependencies", which
# arrives on an ordinary commit that nobody thinks of as a security change.
#
# localcoder is the live example and the reason this is a check rather than a note: it ships
# `pyproject.toml` with `dependencies = []` and a comment explaining that being stdlib-only
# is a deliberate feature. The day someone adds one line there, the manifest stops being
# empty and nothing else changes.
has_real_dependencies() {
  local f
  for f in requirements.txt requirements-dev.txt Pipfile poetry.lock go.mod Cargo.toml Gemfile package.json; do
    [ -f "$f" ] && [ -s "$f" ] && return 0
  done
  # pyproject.toml is only a finding when `dependencies` is non-empty: an empty list is a
  # decision, and this repo's own is documented as one.
  if [ -f pyproject.toml ]; then
    python3 - <<'PYEOF' 2>/dev/null && return 0
import re, sys
s = open("pyproject.toml").read()
m = re.search(r'^dependencies\s*=\s*\[(.*?)\]', s, re.S | re.M)
sys.exit(0 if (m and m.group(1).strip()) else 1)
PYEOF
  fi
  return 1
}

report_alerts() {   # report_alerts [--verbose]
  local n_dep n_code n_secret
  n_dep="$(alerts_count dependabot)"
  if [ -n "$n_dep" ] && [ "$n_dep" -gt 0 ]; then
    echo ""
    echo "[!!] $n_dep open Dependabot alert(s):"
    run_capped gh api "repos/{owner}/{repo}/dependabot/alerts?state=open&per_page=10" \
      --jq '.[] | "       \(.security_advisory.severity)  \(.dependency.package.name)  \(.security_advisory.summary[0:70])"' 2>/dev/null
    echo ""
  elif [ -z "$n_dep" ]; then
    # COULD NOT ASK. Silent unless there is something to scan — see has_real_dependencies.
    if has_real_dependencies; then
      echo ""
      echo "[!!] This repo declares dependencies and Dependabot alerts are NOT enabled."
      echo "     Nothing is watching them. Free on any repo, public or private:"
      echo "       gh api -X PUT repos/{owner}/{repo}/vulnerability-alerts"
      echo ""
    elif [ "${1:-}" = "--verbose" ]; then
      echo "[..] Dependabot: not enabled — and no dependency manifest to scan, so nothing is missed."
    fi
  elif [ "${1:-}" = "--verbose" ]; then
    echo "[OK] Dependabot: 0 open alert(s)"
  fi

  for kind in code-scanning secret-scanning; do
    local n
    case "$kind" in
      code-scanning)   n="$(alerts_count code-scanning)" ;;
      secret-scanning) n="$(alerts_count secret-scanning)" ;;
    esac
    if [ -n "$n" ] && [ "$n" -gt 0 ]; then
      echo ""
      echo "[!!] $n open $kind alert(s) — see the Security tab."
      echo ""
    elif [ -z "$n" ]; then
      [ "${1:-}" = "--verbose" ] && echo "[..] $kind: not enabled (paid Advanced Security on a private repo) — NOT the same as clean."
    elif [ "${1:-}" = "--verbose" ]; then
      echo "[OK] $kind: 0 open alert(s)"
    fi
  done

  # SUCCESS MUST SAY SOMETHING (#182). This printed NOTHING on a clean repo — exit 0, zero
  # bytes — which is indistinguishable from "the tool did nothing", on the one check whose
  # stated purpose is telling zero apart from not-enabled. An adopter reported it as the
  # ambiguity it is.
  #
  # ONE LINE, AND IT CARRIES THE DISTINCTION. Counting the alert features that answered is
  # the whole point: "0 alerts across 3 features" and "0 alerts across 1 feature" are very
  # different assurances and used to print identically, which is to say not at all.
  if [ "${1:-}" != "--verbose" ]; then
    local _enabled=0 _total=3
    [ -n "$n_dep" ] && _enabled=$((_enabled + 1))
    [ -n "$(alerts_count code-scanning)" ] && _enabled=$((_enabled + 1))
    [ -n "$(alerts_count secret-scanning)" ] && _enabled=$((_enabled + 1))
    # ZERO FEATURES ENABLED IS NOT A ZERO ALERT COUNT (#263). At _enabled=0 the phrase
    # "0 open alerts" is not under-qualified, it is VACUOUS: nothing answered, so zero is
    # the count of nothing. The caveat sentence was already there, and it did not help --
    # the tag said [OK], the leading clause said 0 open alerts, and the exit code said 0.
    # Three signals saying clean and one adverbial clause saying otherwise.
    #
    # THIS IS THE DEFECT preflight's OWN CHANGELOG NAMES. 0.35.0 wrote "collapsing rc 3 into
    # a pass is the ci_status defect verbatim: no alerts for months across three
    # repositories where every alert feature was switched off" -- and gave the three-outcome
    # treatment to dependency_audit while leaving ci_status, the file it was named after,
    # printing exactly that. Reported by an adopter on health-app with all three off.
    #
    # [??] IS ITS OWN TAG, deliberately not [!] . Nothing is WRONG here; the repository has
    # simply not turned the features on, and a warning tag would train people to ignore it.
    # What is wrong is calling that a clean bill of health.
    alert_line "$_enabled" "$_total" "$br"
  fi
}

# SPLIT FROM THE FETCH, LIKE classify_var_value AND runner_verdict, AND FOR THE SAME REASON:
# every interesting case here is about the COUNT, and none of them needs a network. Inline in
# report() this branch had no test at all, which is how the _enabled=0 case (#263) shipped.
alert_line() {   # alert_line <enabled> <total> <branch-label>
  local _enabled="$1" _total="$2" br="$3"
    if [ "$_enabled" -eq 0 ]; then
      echo "[??] $(ci_word "$br"); ALERTS NOT CHECKED — 0 of $_total alert features are"
      echo "     enabled, so NO ALERT COUNT EXISTS. Zero features answered; a count of"
      echo "     zero would be the count of nothing, and is deliberately not printed here."
      echo "     Enable Dependabot, code scanning and secret scanning in repo settings,"
      echo "     or accept that nothing here is watching for vulnerable dependencies."
    elif [ "$_enabled" -eq "$_total" ]; then
      echo "$(ci_tag) $(ci_word "$br"); 0 open alerts across all $_total alert features."
    else
      echo "$(ci_tag) $(ci_word "$br"); 0 open alerts — but only $_enabled of $_total alert"
      echo "     features are enabled. --verbose says which, and an absent feature is"
      echo "     NOT the same as clean."
    fi
}

# ==== A QUEUED JOB IS NOT A SLOW JOB — IT IS A SILENT ONE ==============================
#
# Once a repo sets SCAFFOLD_RUNNER to a self-hosted label, a workflow whose runner is offline
# does not FAIL. It QUEUES, indefinitely, and `timeout-minutes` does not apply because the
# job never starts. On the status page that is indistinguishable from a slow build, and in
# this repository`s own words: a CI that stopped running looks exactly like a CI that passed.
#
# Trading "CI is red" for "CI is silent" is the one trade this project keeps refusing, so
# moving to a self-hosted runner has to come with the check that notices it is gone.
runner_lines() {
  # "name<TAB>status" per registered self-hosted runner. Empty when there are none, when gh
  # cannot ask, or on a repo that uses hosted runners — all of which are the ordinary case.
  run_capped gh api "repos/{owner}/{repo}/actions/runners" \
    --jq '.runners[] | "\(.name)\t\(.status)"' 2>/dev/null || true
}

runner_verdict() {
  # Reads "name<TAB>status" on stdin. 0 nothing wrong, 1 a registered runner is offline.
  # SPLIT FROM THE FETCH so the decision has cases on it without a network.
  local total=0 offline=0 names="" name status
  while IFS="$(printf '\t')" read -r name status; do
    [ -z "$name" ] && continue
    total=$((total + 1))
    if [ "$status" != "online" ]; then
      offline=$((offline + 1)); names="$names $name"
    fi
  done
  # NO REGISTERED RUNNERS IS NOT A PROBLEM AND NOT A PASS TO ANNOUNCE. Almost every repo is
  # in this state and a line here would be noise people learn to skip.
  [ "$total" -eq 0 ] && return 0
  if [ "$offline" -gt 0 ]; then
    echo "[!]  $offline of $total self-hosted runner(s) OFFLINE:$names"
    echo "     A workflow targeting them QUEUES rather than failing, so CI goes SILENT"
    echo "     instead of red — and a queued job looks exactly like a slow one."
    echo "     Start the runner, or unset SCAFFOLD_RUNNER to fall back to hosted."
    return 1
  fi
  echo "[OK] $total self-hosted runner(s) online"
  return 0
}

# ==== A VARIABLE SET WITH NO READER REPORTS PRESENT AND ENFORCES NOTHING ================
#
# The adopter's phrasing, and their catch. Retargeting CI takes TWO facts that live in
# different places: the repository variable, and a `runs-on` that interpolates it. Set the
# variable against a workflow still hardcoded to `ubuntu-latest` and nothing changes, but the
# settings page says self-hosted -- so `no run for the tip` reads as "the runner is still
# coming up" rather than "this repo was never retargeted". A silent CI that looks like a
# booting one, which is worse than either.
#
# Same shape as a declared verifier nobody calls, and as ci_outage_expired() being asserted
# by three selftests and invoked from zero production sites. This file is where that class
# gets caught, so it catches this one too.
RUNNER_VAR="SCAFFOLD_RUNNER"
# THE PLURAL ONE, added when scaffold-check gained a matrix so the gate could run on macOS
# and Linux at once. Both are live: SCAFFOLD_RUNNERS wins where set, SCAFFOLD_RUNNER stays
# honoured because five repositories already had it and this file is force-installed into
# all of them. Everything below accepts EITHER, or the migration itself would be reported
# as a repo that was never retargeted.
RUNNER_VAR_LIST="SCAFFOLD_RUNNERS"
RUNNER_VAR_RE="vars\.\(${RUNNER_VAR}\|${RUNNER_VAR_LIST}\)"

runner_var_is_set() {
  # set | empty | unset. UNKNOWN IS TREATED AS UNSET, deliberately: the loud paths fire only
  # when the variable is confirmed to exist, so an unreachable API cannot manufacture a
  # false alarm.
  # `empty` IS ITS OWN ANSWER, and it was predicted rather than found. `runs-on:
  # ${{ vars.X || 'ubuntu-latest' }}` with X set to the empty string reads the variable and
  # still runs hosted -- so the variable is present, every workflow reads it, and nothing is
  # retargeted. Reports present, enforces nothing, one layer up again.
  local val
  # THE PLURAL VARIABLE WINS, because that is the precedence the workflows implement. Read
  # them in the same order or this check answers a different question than CI does.
  val="$(run_capped gh api "repos/{owner}/{repo}/actions/variables/$RUNNER_VAR_LIST" \
           --jq .value 2>/dev/null)" || val=""
  if [ -n "$val" ] && [ "$val" != "null" ]; then
    classify_list_value "$val"
    return 0
  fi
  val="$(run_capped gh api "repos/{owner}/{repo}/actions/variables/$RUNNER_VAR" \
           --jq .value 2>/dev/null)" || { echo unset; return 0; }
  classify_var_value "$val"
}

classify_list_value() {
  # set | empty | malformed. SPLIT FROM THE FETCH, like classify_var_value, and for the
  # same reason: the interesting cases are all about the VALUE and none of them need a
  # network.
  #
  # MALFORMED IS A DISTINCT ANSWER AND IT IS THE WHOLE POINT OF THIS FUNCTION. `fromJSON`
  # on a bad value does not fall back to the default -- it fails the workflow during
  # expression evaluation, BEFORE any step exists, so the run shows no steps, no log, and
  # an error that never names SCAFFOLD_RUNNERS. That is indistinguishable from a broken
  # runner unless something says so here, locally, where it is cheap.
  case "$1" in
    "" | null) echo empty; return 0 ;;
  esac
  printf '%s' "$1" | python3 -c '
import json, sys
v = sys.stdin.read()
try:
    d = json.loads(v)
except Exception:
    sys.exit(1)
if not isinstance(d, list) or not d:
    sys.exit(1)
for e in d:
    if isinstance(e, str):
        continue
    if isinstance(e, list) and e and all(isinstance(x, str) for x in e):
        continue
    sys.exit(1)
' 2>/dev/null && echo set || echo malformed
}


classify_var_value() {
  # SPLIT FROM THE FETCH SO IT HAS CASES. Mutating `empty -> set` inside the networked
  # function changed nothing, because every verdict case passed the state in directly --
  # the classifier that decides which state we are in had no test at all.
  case "$1" in
    "" | null) echo empty ;;
    *)         echo set ;;
  esac
}

# ONE SCRATCH FILE, NOT PROCESS SUBSTITUTION. bash 3.2 on macOS -- the whole fleet -- can
# segfault on `<(...)` feeding a `while read` loop, and the symptom is an EMPTY loop body,
# i.e. this scanner silently flagging every workflow. Created once, cleaned by the trap.
_ci_runson_tmp="$(mktemp "${TMPDIR:-/tmp}/ci_runson.XXXXXX")" || { echo "ci_status: mktemp failed; stopping" >&2; exit 1; }
trap 'rm -f "$_ci_runson_tmp"' EXIT

workflows_not_reading_var() {
  # Workflow files where NOT EVERY `runs-on:` interpolates the variable.
  #
  # MATCHING ANYWHERE IN THE FILE WAS A FALSE NEGATIVE TWICE OVER, and both were predicted
  # by a reviewer rather than found by a test:
  #
  #   1. A COMMENT mentioning `vars.$RUNNER_VAR` counted as a read. THIS FILE'S OWN SHIPPED
  #      workflow carries exactly such a comment, so a copy of that comment block above a
  #      hardcoded `runs-on` passed the check. Demonstrated, not theorised.
  #   2. A workflow with four jobs where one reads the variable and three do not read as
  #      "reading" at file granularity -- the intra-file partial migration this check exists
  #      to catch, invisible in precisely the case cheapest to create.
  #
  # So only `runs-on:` lines count, and ALL of them in a file must interpolate it.
  #
  # KNOWN LIMIT, IN THE SAFE DIRECTION: indirection defeats a line match. `runs-on:
  # ${{ matrix.os }}` with the variable in the matrix, a reusable workflow whose caller has
  # no `runs-on`, and composite actions will be flagged as not reading it when they may.
  # That is a false POSITIVE -- noisy, never silent -- which is the correct way round for a
  # check whose whole purpose is refusing to report a retargeting that did not happen.
  local d=".github/workflows" f total read_ line key
  # TWO GUARDS, EITHER SUFFICIENT ON ITS OWN, AND THAT IS DELIBERATE. bash 3.2 leaves an
  # unmatched glob literal, so the `-f` test below already skips it; this `-d` test is the
  # cheaper early exit. Mutation-verified: removing THIS one changes no behaviour, which is
  # recorded here so a future reader does not remove BOTH on the grounds that one is dead.
  [ -d "$d" ] || return 0
  for f in "$d"/*.yml "$d"/*.yaml; do
    [ -f "$f" ] || continue
    total="$(grep -cE '^[[:space:]]*runs-on:' "$f")"
    # A FILE WITH NO `runs-on:` HAS NOTHING TO RETARGET and is not a finding.
    # DELIBERATELY REDUNDANT, like the -d guard above: with total 0 the equality below is
    # 0 -eq 0 and the file is not flagged anyway. Mutation-verified as behaviour-preserving,
    # and recorded so a future reader does not delete both on the grounds that one is dead.
    [ "$total" -eq 0 ] && continue
    # ONE LEVEL OF MATRIX INDIRECTION IS RESOLVED, and it had to be. The header above
    # listed `runs-on: ${{ matrix.os }}` as a KNOWN LIMIT in the safe direction -- and then
    # scaffold-check.yml became exactly that file. Left alone, this check would have
    # reported the scaffold's own retargeted workflow as unretargeted, on every adopter, on
    # every run. A false positive is the correct direction to fail, but a PERMANENT one
    # trains people to skip the line, which costs the check its whole purpose.
    #
    # A `runs-on:` line counts as reading the variable when it interpolates it directly, OR
    # when it interpolates `matrix.<key>` and a `<key>:` line in the same file interpolates
    # it. That is deliberately ONE level: a matrix built from another expression, a reusable
    # workflow, or a composite action is still flagged, still in the safe direction.
    read_=0
    printf '%s\n' "$(grep -E '^[[:space:]]*runs-on:' "$f")" > "$_ci_runson_tmp"
    while IFS= read -r line; do
      [ -z "$line" ] && continue
      if printf '%s' "$line" | grep -q "$RUNNER_VAR_RE"; then
        read_=$((read_ + 1)); continue
      fi
      # `runs-on: ${{ matrix.runner }}` -> key=runner
      key="$(printf '%s' "$line" | sed -n 's/.*matrix\.\([A-Za-z0-9_-]*\).*/\1/p')"
      [ -z "$key" ] && continue
      # ...and the matrix must define that key FROM the variable. Anchored to a `key:` line
      # so a stray mention elsewhere in the file does not count, which is the same mistake
      # the comment-only case above already cost us once.
      if grep -E "^[[:space:]]*${key}:" "$f" | grep -q "$RUNNER_VAR_RE"; then
        read_=$((read_ + 1))
      fi
    done < "$_ci_runson_tmp"
    [ "$read_" -eq "$total" ] || printf '%s\n' "$f"
  done
}

runner_var_verdict() {
  # $1 is set|unset. stdin is the list of workflow files that do not read the variable.
  # SPLIT FROM BOTH FETCHES so the decision has cases without a network or a repo.
  local var="$1" missing=0 names="" f
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    missing=$((missing + 1))
    names="$names $(basename "$f")"
  done
  # THE VARIABLE BEING UNSET IS THE SHIPPED DEFAULT AND SAYS NOTHING. Every adopter is in
  # that state and a line here would be noise people learn to skip.
  if [ "$var" = "empty" ]; then
    # THE BACKSLASH IS LOAD-BEARING AND ITS ABSENCE WAS INVISIBLE. Unescaped, bash parses
    # `${{` as a parameter expansion, prints `bad substitution` to stderr INSTEAD of this
    # line, and carries on -- so the one message that explains a set-but-empty runner
    # variable was replaced by a shell error in exactly the situation it exists to explain.
    # `bash -n` passes on it; only shellcheck (SC2296) sees it. Line 1415 below had it right.
    echo "[!]  $RUNNER_VAR exists but its VALUE IS EMPTY, so every \${{ vars || 'ubuntu-latest' }}"
    echo "     falls back to the hosted runner. The variable is present and retargets nothing."
    return 1
  fi
  if [ "$var" = "malformed" ]; then
    echo "[!]  $RUNNER_VAR_LIST is set to a value fromJSON() CANNOT PARSE."
    echo "     CI will not fall back — the run dies during expression evaluation, before any"
    echo "     step exists, with an error that never names the variable. It looks like a dead"
    echo "     runner, not a typo."
    echo "     It must be a non-empty JSON array of strings or of string arrays, e.g."
    echo "       gh variable set $RUNNER_VAR_LIST --body '[[\"self-hosted\",\"macOS\"],[\"self-hosted\",\"Linux\"]]'"
    return 1
  fi
  [ "$var" != "set" ] && return 0
  if [ "$missing" -eq 0 ]; then
    echo "[OK] the runner variable is set and every runs-on: reads it"
    return 0
  fi
  echo "[!]  the runner variable is SET but $missing workflow(s) do not read it:$names"
  echo "     Those jobs still target the hosted runner, so this repo has TWO TRUTHS about"
  echo "     where CI runs — and \"no run for the tip\" will read as a runner still coming"
  echo "     up rather than a repo that was never retargeted."
  echo "     Fix: upgrade the scaffold so product files gain the indirection, or add"
  echo "     runs-on: \${{ vars.$RUNNER_VAR || 'ubuntu-latest' }} to the workflows above."
  return 1
}

report_runner_var() {
  local rc=0
  workflows_not_reading_var | runner_var_verdict "$(runner_var_is_set)" || rc=1
  return "$rc"
}

# ==== A MATRIX LEG NAMING LABELS NO RUNNER HAS DOES NOT FAIL. IT QUEUES. =================
#
# runner_verdict() catches a REGISTERED runner that went offline. It cannot catch the other
# half, which SCAFFOLD_RUNNERS made reachable: a leg targeting `[self-hosted, Linux]` in a
# repository whose only runner is macOS. GitHub does not reject that job. It queues it,
# indefinitely, and `timeout-minutes` never applies because the job never starts -- so the
# run sits "in progress" forever and the PR never goes red. Trading "CI is red" for "CI is
# silent" is the one trade this project keeps refusing, and the matrix is the feature that
# makes it a one-variable mistake.
#
# THIS IS NOT HYPOTHETICAL, IT IS THE NEXT STEP ON THE PLAN. The fleet is moving its Linux
# leg from `ubuntu-latest` onto a self-hosted Linux box, and the window between "the variable
# names [self-hosted, Linux]" and "a Linux runner is registered HERE" is exactly when this
# fires. Runners are repo-scoped -- Robiton is a User account, so there are no runner groups
# and no org-level sharing -- which means every repo needs its own registration and every one
# of them can be missed independently.
#
# HOSTED LABELS ARE SATISFIABLE BY DEFINITION and must not be flagged: `ubuntu-latest`,
# `macos-14`, `windows-2022` and friends are GitHub's, not ours.
runner_labels_lines() {
  # "label,label,label<TAB>status" per registered runner, so the matcher can be tested with
  # no network -- the same fetch/decide split as runner_lines and classify_var_value.
  run_capped gh api "repos/{owner}/{repo}/actions/runners" \
    --jq '.runners[] | "\([.labels[].name]|join(","))\t\(.status)"' 2>/dev/null || true
}

leg_is_hosted() {
  # GitHub-hosted images. Anything else is ours to provide.
  case "$1" in
    ubuntu-*|macos-*|macOS-*|windows-*|Windows-*) return 0 ;;
    *) return 1 ;;
  esac
}

unsatisfiable_legs() {
  # $1 is the SCAFFOLD_RUNNERS value. stdin is runner_labels_lines output. Prints one line
  # per leg that no ONLINE runner can serve. Empty output means every leg is satisfiable.
  #
  # SPLIT FROM BOTH FETCHES so the matching has cases without a repo or a network -- the
  # lesson classify_var_value cost this file once already.
  local value="$1" runners
  runners="$(cat)"
  [ -n "$value" ] || return 0
  printf '%s' "$value" | RUNNERS="$runners" python3 -c '
import json, os, sys
raw = sys.stdin.read()
try:
    legs = json.loads(raw)
except Exception:
    sys.exit(0)            # malformed is classify_list_value(); not this checks job
if not isinstance(legs, list):
    sys.exit(0)
have = []
for line in os.environ.get("RUNNERS", "").splitlines():
    if not line.strip():
        continue
    parts = line.split("\t")
    labels = set(parts[0].split(",")) if parts[0] else set()
    status = parts[1] if len(parts) > 1 else ""
    if status == "online":
        have.append(labels)
HOSTED = ("ubuntu-", "macos-", "macOS-", "windows-", "Windows-")
for leg in legs:
    want = [leg] if isinstance(leg, str) else list(leg)
    if len(want) == 1 and want[0].startswith(HOSTED):
        continue           # GitHub provides it
    need = set(want)
    if not any(need <= labels for labels in have):
        print(",".join(want))
'
}

unsatisfiable_verdict() {
  # stdin is the leg list. SPLIT SO IT HAS CASES.
  local legs="" n=0 leg
  while IFS= read -r leg; do
    [ -z "$leg" ] && continue
    n=$((n + 1)); legs="$legs
       - [$leg]"
  done
  [ "$n" -eq 0 ] && return 0
  echo "[!]  $n matrix leg(s) in $RUNNER_VAR_LIST name labels NO ONLINE RUNNER HAS:$legs"
  echo "     Those jobs QUEUE — they do not fail. timeout-minutes never applies, because"
  echo "     the job never starts, so the run sits in progress and the PR never goes red."
  echo "     Register a runner with those labels in THIS repository (runners are repo-scoped;"
  echo "     this account has no runner groups), or drop the leg from the variable."
  return 1
}

report_unsatisfiable_legs() {
  local val rc=0
  val="$(run_capped gh api "repos/{owner}/{repo}/actions/variables/$RUNNER_VAR_LIST" \
           --jq .value 2>/dev/null)" || return 0
  [ -n "$val" ] && [ "$val" != "null" ] || return 0
  runner_labels_lines | unsatisfiable_legs "$val" | unsatisfiable_verdict || rc=1
  return "$rc"
}

report_runners() {
  local lines rc=0
  lines="$(runner_lines)"
  printf '%s\n' "$lines" | runner_verdict || rc=1
  return "$rc"
}

report() {
  if ! usable; then
    [ "${1:-}" = "--verbose" ] && echo "[..] CI status: not checked (no gh, no auth, or no GitHub remote)."
    return 0
  fi

  local br runs failed_main open_prs
  br="$(default_branch)"

  # One run per workflow, newest first, on the default branch. `--json` keeps this to a
  # single call rather than one per workflow.
  # workflowName IS LOAD-BEARING, see REDUCER_PY: `name` is the run's display title and
  # Dependabot makes it unique per run, which defeats the per-workflow dedupe entirely.
  runs="$(run_capped gh run list --branch "$br" --limit 12 \
            --json conclusion,name,workflowName,status,headSha,url)"

  # PROPERTIES 2 AND 3, EACH IN ONE PLACE (#213). Both sit here rather than inside the three
  # ci_outage_note() branches: those branches are reached only on specific findings, and an
  # OVERDUE declaration must be said whatever else is true — including on a fully green repo,
  # which is exactly the case none of those branches runs in.
  ci_outage_overdue_note || true
  if [ -n "$runs" ] && [ "$runs" != "[]" ]; then
    # A run list with anything in it means Actions executed. That is the observation property 3
    # needs, and it is available here and nowhere earlier.
    ci_outage_suppressing_nothing_note yes || true
  fi

  # ==== A CI THAT STOPPED RUNNING LOOKS EXACTLY LIKE A CI THAT PASSED ====================
  #
  # Everything below this point asks "did anything FAIL". Nothing asked "did anything RUN",
  # so the answer for a repository whose Actions have stopped was silence — and silence here
  # is what green looks like. `[ -n "$runs" ] || return 0` returned success on an EMPTY run
  # list without printing a word, even under --verbose.
  #
  # This stops being hypothetical on 2026-08-13: a $0 Actions budget cap is being set on the
  # account, and at 1,800 of 2,000 included minutes it will bite this week. When it does,
  # every push to all four repos silently runs nothing, and this check would have said
  # `[OK] CI green on origin/main` about a commit no gate had ever seen.
  #
  # THE ORACLE RULE, as worded for 05-TEST-PLAN.md: for every automated check, state what
  # would be observed if the check were silently wrong, and assert THAT. Here the answer is
  # "nothing would be observed", which is the same observation as success — so the assertion
  # has to be the presence of a run for the commit, not the absence of a failure.
  #
  # Sixth known instance of this shape in this programme (`must-run` printing "all of which
  # ran", `[OK ] RAM check skipped`, sweeps behind a `timeout` that does not exist on macOS,
  # a scanner that examined zero files, a reviewer returning NONE). It is the first one we
  # saw coming rather than discovered afterwards.
  local head_sha have_run
  head_sha="$(run_capped gh api "repos/{owner}/{repo}/commits/$br" --jq '.sha' 2>/dev/null)"
  if [ -n "$head_sha" ]; then
    # NO 2>/dev/null (#316). Same rule as REDUCER_PY and NOVRD_PY: this probe is what the
    # word "green" rests on, so an interpreter that cannot start must be LOUD, not silent.
    have_run="$(printf '%s' "$runs" | HEAD_SHA="$head_sha" python3 -c "$COVERS_PY")"
    # A QUEUED RUN FOR THE TIP IS NOT A RUN THAT PASSED (#289).
    #
    # This probe asked only whether a row EXISTS for the tip, so a queued or in-progress run
    # satisfied it -- and the green verdict below then came from the previous commit, which
    # had completed. OBSERVED 2026-09-02: `[OK] CI green on main` printed while the only run
    # for HEAD was still queued, moments after a push. A reader who skims to the last line
    # was told the commit they had just pushed was green by a tool that had not seen it
    # finish.
    #
    # Same family as the no-run case immediately below, and the same rule: a commit nothing
    # has judged reports identically to one that passed unless the tool says otherwise. Not
    # a failure -- nothing is wrong yet -- so it sets CI_UNVERIFIED and says what to do.
    if [ "$have_run" = "pending" ]; then
      CI_UNVERIFIED=1
      echo ""
      echo "[..] CI has NOT FINISHED for the tip of origin/$br — this is not green yet."
      echo "       commit: $head_sha"
      echo "       A run exists and has not completed. Re-run this when it has; a queued"
      echo "       run and a passing one are different answers."
    fi
    # THE FOURTH ANSWER NEEDS A BRANCH, OR IT FALLS THROUGH TO THE GREEN VERDICT -- which
    # is the whole lesson of #312: a state with nowhere to go is a state that reads as a
    # pass. [..] not [!!]: nothing is broken, we simply have no answer.
    if [ "$have_run" = "novrd" ]; then
      CI_UNVERIFIED=1
      echo ""
      echo "[..] A run COMPLETED for the tip of origin/$br and reached NO VERDICT."
      echo "       commit: $head_sha"
      # NO 2>/dev/null. Same rule as REDUCER_PY: if this cannot run, that must be loud.
      _novrd="$(printf '%s' "$runs" | HEAD_SHA="$head_sha" python3 -c "$NOVRD_PY")"
      [ -n "$_novrd" ] && printf '       %s\n' "$_novrd"
      echo "       Cancelled, stale, or a conclusion this tool does not recognise — neither"
      echo "       a pass nor a failure."
      # ONE INSTRUCTION FOR TWO SITUATIONS WAS THE DEFECT. "Re-run it" is right for a
      # cancelled GATE and wrong for a superseded side workflow -- and the second is the
      # commonest way this state occurs. Measured across the last 60 mirror runs: 11
      # cancelled, 11 of 11 superseded by a later push, 6 of those on release commits,
      # because cutting a release IS a double push. A release therefore spends a window
      # looking like this, with nothing wrong.
      echo "       If the name above is the GATE, re-run it. If it is a mirror or a side"
      echo "       workflow a later push superseded, nothing is wrong and the next push"
      echo "       clears it."
    fi
    if [ "$have_run" = "no" ]; then
      CI_UNVERIFIED=1
      echo ""
      # COULD NOT ASK OUTRANKS BOTH. A declared outage explains why nothing ran; it does not
      # explain why the repository will not answer, and asserting the former over the latter
      # would put a confident sentence on top of a question we never resolved.
      if cannot_ask_note; then
        echo ""
      elif ci_outage_note; then
        echo ""
      else
      echo "[!!] NO WORKFLOW RUN EXISTS for the tip of origin/$br — this is NOT green."
      echo "       commit: $head_sha"
      echo "       A commit no workflow ever saw reports identically to one that passed."
      echo "       Most likely: the \$0 Actions budget cap has been reached (the included"
      echo "       allowance resets on the 1st), Actions are disabled for the repo, or the"
      echo "       push touched only paths every workflow filters out."
      echo "       Check:  gh api repos/{owner}/{repo}/actions/permissions"
      echo "       While Actions are stopped, tools/preflight.sh is the ONLY gate — run it"
      echo "       before every push, because nothing downstream will catch what it misses."
      echo ""
      fi
    fi

    # ---- GREEN IS AN ALLOWLIST (#316).
    #
    # COVERS_PY answers one of yes | novrd | pending | no | unknown, and an interpreter that
    # cannot start answers with the EMPTY STRING. The branches above test three of those
    # five. `unknown` -- which this file COMPUTES DELIBERATELY when the run list will not
    # parse -- and "" therefore matched nothing and fell through to the green sentence.
    #
    # MEASURED, not reasoned: a python3 stub behaving exactly like one gated behind an
    # unaccepted Xcode license (nag on stderr, exit 69, reads no stdin), prepended to PATH
    # with every neighbour verified intact, produced `[OK] CI green on main @ 8f6c238` at
    # exit 0 -- a green verdict from a tool that had not run the probe establishing it. It
    # was the TRUE answer on that commit, which is what makes it dangerous: equally
    # confident on a commit that was red.
    #
    # This is the rule 0.17.3 applied to REDUCER_PY, in the other direction. Red stays a
    # DENYLIST because calling a build red is a positive accusation; green must be an
    # ALLOWLIST because a non-verdict must never read as a pass. That was applied to the red
    # path and to NOVRD_PY and never here -- the one probe that gates the word "green".
    case "$have_run" in
      yes|pending|novrd|no) : ;;
      *)
        CI_UNVERIFIED=1
        echo ""
        echo "[..] CI COULD NOT BE DETERMINED for origin/$br — this is NOT green."
        echo "       commit: $head_sha"
        if [ -z "$have_run" ]; then
          echo "       The coverage probe produced NOTHING, so python3 did not run. Check the"
          echo "       interpreter FIRST: a gated or missing python3 looks exactly like a CI"
          echo "       problem, and the stderr above names the real cause."
        else
          echo "       The coverage probe answered '$have_run', which this tool does not"
          echo "       recognise — the run list did not parse as JSON."
        fi
        echo "       Nothing here says the commit is bad. It says NOTHING JUDGED IT."
        ;;
    esac
  fi

  # AN EMPTY RUN LIST IS NOT A PASS. It is reported even without --verbose: a repo that has
  # never run a workflow and a repo whose workflows have stopped are the same observation,
  # and both are things the person at session start needs to be told.
  if [ -z "$runs" ] || [ "$runs" = "[]" ]; then
    CI_UNVERIFIED=1
    echo ""
    # THE BRANCH THAT CRIED WOLF ON 2026-09-11. An empty `$runs` is the observation; "nothing
    # has been checked remotely" is a conclusion, and it only follows if we could ask at all.
    if cannot_ask_note; then
      echo ""
      return 0
    fi
    if ci_outage_note; then
      # FALL THROUGH TO THE ALERTS, DO NOT RETURN. Alert reporting does not use Actions
      # minutes and still works during the outage — it is the reason this tool is worth
      # running at all right now, and the original `return 0` here would have discarded it.
      echo ""
    else
      echo "[!!] NO WORKFLOW RUNS AT ALL on origin/$br — nothing has been checked remotely."
      echo "       This is could-not-run, not a pass. tools/preflight.sh is the only gate."
      echo ""
      return 0
    fi
  fi

  # NO `2>/dev/null` ON THE REDUCER. Swallowing its stderr is what let a SyntaxError read as
  # "no failures" for four days. If python cannot run this, that must be loud.
  failed_main="$(printf '%s' "$runs" | python3 -c "$REDUCER_PY")"

  if [ -n "$failed_main" ]; then
    # "FIX OR REVERT" IS THE WRONG INSTRUCTION FOR A JOB THAT NEVER RAN.
    #
    # When Actions stop for billing, GitHub still CREATES the run and marks it `failure`, so
    # every red-build heuristic fires and sends the reader hunting a defect that is not
    # there. Live on 2026-08-13 across all three repositories: "The job was not started
    # because recent account payments have failed or your spending limit needs to be
    # increased." Nothing in the code was wrong and the advice on screen said otherwise.
    #
    # A job that never started has ZERO STEPS, which is the cheapest available signal and
    # does not depend on matching GitHub's wording. One extra call, made only when something
    # is already red, so the common path is unchanged.
    local _rid _steps=""
    # NO 2>/dev/null (#316), for consistency with the other three probes. Unlike COVERS_PY
    # this one cannot turn a non-verdict into a pass: it runs only after a failure is already
    # established, so an empty _rid costs the run's NAME and not the verdict. Loud anyway --
    # the reason this file keeps finding these is that a silent probe has no bad day.
    _rid="$(printf '%s' "$runs" | python3 -c "$FIRSTFAIL_PY")"
    if [ -n "$_rid" ]; then
      _steps="$(run_capped gh api "repos/{owner}/{repo}/actions/runs/$_rid/jobs" \
                  --jq '.jobs[0].steps | length' 2>/dev/null | head -1)"
    fi
    echo ""
    if [ "${_steps:-x}" = "0" ]; then
      # AND THE VERDICT HAS TO AGREE WITH THE FINDING. Without this the same run printed
      # "CI IS NOT RUNNING on origin/main" and then "[OK] CI green on main" eight lines
      # later, because the summary is conditioned on CI_UNVERIFIED and this branch was the
      # one path that detected a problem without setting it.
      #
      # OBSERVED 2026-08-16 against the live billing block. A reader who skims to the last
      # line — which is what a verdict line is FOR — was told green by a tool that had just
      # said nothing had run. That is this programme's signature defect appearing inside the
      # check written to catch it, and the comment at the bottom of this file already states
      # the rule it broke: every claim here must be conditioned on CI_UNVERIFIED.
      CI_UNVERIFIED=1
      if ci_outage_note; then
        echo ""
      else
      echo "[!!] CI IS NOT RUNNING on origin/$br — the job never started."
      echo "       BILLING OR QUOTA, not a broken build. GitHub creates the run and marks"
      echo "       it failed anyway, so every red-build check fires and points at code."
      echo "       Check: Settings -> Billing & plans -> Actions spending limit."
      echo "       Until it clears, tools/preflight.sh is the ONLY gate that runs."
      printf '%s\n' "$failed_main"
      fi
    else
      # AND THE VERDICT BELOW MUST AGREE WITH THIS ALARM (#312). report_alerts() runs thirty
      # lines further down this same function and phrases its summary through ci_word(),
      # which without this said "CI green" about the identical sha four lines under the
      # alarm. NOT CI_UNVERIFIED: a run completed and reported, so the tip IS verified --
      # it is verified and FAILING, which is the answer the vocabulary did not have.
      CI_RED=1
      echo "[!!] CI IS RED on origin/$br — fix or revert before building on it:"
      printf '%s\n' "$failed_main"
    fi
    echo ""
  elif [ "${1:-}" = "--verbose" ]; then
    echo "$(ci_tag) $(ci_word "origin/$br")"
  fi

  # Open PRs whose checks have already failed. Cheap, and it is the other half of "is
  # anything red" — a PR left red overnight is the same lost signal as a red main.
  open_prs="$(run_capped gh pr list --state open --limit 20 --json number,title,statusCheckRollup \
              | python3 -c '
import json, sys
try:
    rows = json.load(sys.stdin)
except Exception:
    sys.exit(0)
out = []
for p in rows:
    roll = p.get("statusCheckRollup") or []
    bad = [c for c in roll
           if (c.get("conclusion") in ("FAILURE", "TIMED_OUT", "ACTION_REQUIRED")
               or c.get("state") in ("FAILURE", "ERROR"))]
    if bad:
        out.append(f"       #{p[\"number\"]}  {p[\"title\"][:64]}  ({len(bad)} failing)")
print("\n".join(out))
' 2>/dev/null)"

  if [ -n "$open_prs" ]; then
    echo "[!]  Open PR(s) with failing checks:"
    printf '%s\n' "$open_prs"
    echo ""
  fi

  report_alerts "${1:-}"
  # AFTER THE ALERTS, AND IT DOES NOT CHANGE THE RETURN. report() has always returned 0 --
  # it is a session-start report, not a gate -- and quietly making it non-zero here would
  # change the exit code of every SessionStart hook that calls it. The line is loud instead:
  # an offline runner is the thing you must read, not the thing that fails your shell.
  report_runners || true
  # BOTH HALVES OF THE RETARGETING, REPORTED TOGETHER. An offline runner and an unread
  # variable produce the same symptom -- no run for the tip -- from opposite causes, so
  # reporting one without the other sends the reader to the wrong fix.
  report_runner_var || true
  # THE THIRD CAUSE OF THE SAME SYMPTOM. "No run for the tip" comes from an offline runner, an
  # unread variable, or -- since SCAFFOLD_RUNNERS -- a matrix leg naming labels nothing has.
  # The first two fail loudly somewhere; the third QUEUES, which is the quietest of the three
  # and the only one a person cannot distinguish from a slow build.
  report_unsatisfiable_legs || true
  return 0
}

selftest() {
  # WHAT IS TESTABLE HERE IS THE VERDICT LOGIC, NOT GITHUB. The network half is exercised
  # every session; what a fixture can prove is that this stays quiet when it cannot ask, and
  # that it does not cry wolf over a failure a later run already fixed — the two ways a
  # session-start check gets disabled.
  local fails=0
  chk() {  # chk <label> <expected> <actual>
    if [ "$2" = "$3" ]; then printf '  ok   %-56s\n' "$1"
    else printf '  FAIL %-56s expected=%s got=%s\n' "$1" "$2" "$3"; fails=$((fails + 1)); fi
  }

  echo "ci_status selftest — verdict logic, offline"

  # The newest-per-workflow reducer, fed the shapes that actually occur.
  # THE SHIPPED REDUCER, NOT A COPY OF IT.
  #
  # This was a second, cleaner implementation of the same logic, and that is exactly why
  # nine passing cases sat on top of a reducer that had never parsed. A test that
  # re-implements its subject proves the AUTHOR understood the logic; it proves nothing
  # whatsoever about the code that ships. Verified the only way that counts: reintroduce the
  # original SyntaxError and this suite must go red.
  #
  # `$REDUCER_PY` is the same string report() runs. It emits two lines per failure — the
  # verdict line and its url — so odd lines carry the names, and stripping the conclusion
  # prefix leaves exactly the workflow names the existing expectations were written against.
  verdict() {
    printf '%s' "$1" | python3 -c "$REDUCER_PY" 2>&1 \
      | awk 'NR%2==1' | sed -E 's/^ +[a-z_]+  //' | paste -sd, -
  }

  chk "a green run reports nothing" "" \
      "$(verdict '[{"name":"CI","status":"completed","conclusion":"success"}]')"
  chk "a failure is reported" "CI" \
      "$(verdict '[{"name":"CI","status":"completed","conclusion":"failure"}]')"
  # THE ONE THAT KEEPS A CHECK ALIVE. A fix pushed after a failure means the workflow is
  # green NOW; reporting the older red would be a false positive on every subsequent
  # session, and this repo's position is that a warning nobody can action gets filtered out.
  chk "a fixed workflow is not still reported" "" \
      "$(verdict '[{"name":"CI","status":"completed","conclusion":"success"},{"name":"CI","status":"completed","conclusion":"failure"}]')"
  chk "an older green does not mask a newer red" "CI" \
      "$(verdict '[{"name":"CI","status":"completed","conclusion":"failure"},{"name":"CI","status":"completed","conclusion":"success"}]')"
  chk "two workflows are judged independently" "Mirror" \
      "$(verdict '[{"name":"CI","status":"completed","conclusion":"success"},{"name":"Mirror","status":"completed","conclusion":"failure"}]')"
  # A run still going is not a failure, and neither is one nobody let run.
  chk "an in-progress run is not a failure" "" \
      "$(verdict '[{"name":"CI","status":"in_progress","conclusion":null}]')"
  chk "a cancelled run is not a failure" "" \
      "$(verdict '[{"name":"CI","status":"completed","conclusion":"cancelled"}]')"

  # DEPENDABOT DEFEATS A name-KEYED DEDUPE, AND THIS IS THE REGRESSION GUARD (2026-09-22).
  # Dependabot appends a unique update id to every run's DISPLAY TITLE, so keyed on `name`
  # each run is trivially the newest of its name, the dedupe never fires, and a superseded
  # failure is reported as current forever -- nothing can ever supersede it. Measured on
  # collectionapp: two spent uuid runs reported red while the tip was green on every
  # workflow, so the tool said "CI IS RED on origin/master" and called master green two
  # lines later. Reconstructed from that exact API response.
  chk "a superseded Dependabot failure is NOT still reported" "" \
      "$(verdict '[{"name":"npm_and_yarn in /. - Update #1587423581","workflowName":"Dependabot Updates","status":"completed","conclusion":"success"},{"name":"npm_and_yarn in /. for uuid - Update #1587421234","workflowName":"Dependabot Updates","status":"completed","conclusion":"failure"},{"name":"npm_and_yarn in /. for uuid - Update #1587416440","workflowName":"Dependabot Updates","status":"completed","conclusion":"failure"}]')"
  # AND THE FIX MUST NOT BUY THAT SILENCE BY GOING DEAF. A dedupe change can hide a real
  # failure just as easily as it can stop a false one, so the opposite direction is asserted
  # too: newest Dependabot run red is STILL red, and it is named by its title, not its key.
  chk "a CURRENT Dependabot failure is still reported" "npm_and_yarn in /. for uuid - Update #1587421234" \
      "$(verdict '[{"name":"npm_and_yarn in /. for uuid - Update #1587421234","workflowName":"Dependabot Updates","status":"completed","conclusion":"failure"},{"name":"npm_and_yarn in /. - Update #1587416440","workflowName":"Dependabot Updates","status":"completed","conclusion":"success"}]')"
  # A row with no workflowName must still be judged -- gh fails loudly on an unknown --json
  # field, so this is unreachable in practice, but it must not silently drop a failure.
  chk "a row without workflowName falls back to name" "CI" \
      "$(verdict '[{"name":"CI","status":"completed","conclusion":"failure"}]')"
  chk "a skipped run is not a failure" "" \
      "$(verdict '[{"name":"CI","status":"completed","conclusion":"skipped"}]')"
  chk "timed_out IS a failure" "CI" \
      "$(verdict '[{"name":"CI","status":"completed","conclusion":"timed_out"}]')"

  # ==== AN UNRECOGNISED CONCLUSION MUST NOT BECOME AN ACCUSATION ========================
  #
  # The reducer's `ok` tuple is a DENYLIST wearing an allowlist's clothes: anything not in it
  # is reported under "[!!] CI IS RED on origin/$br -- fix or revert before building on it".
  # `stale` is a real GitHub conclusion and reaches that branch, so the tool tells someone to
  # revert a commit over a run that reached no verdict at all.
  #
  # This is the MIRROR of #312 rather than a repeat. #312 was a non-verdict reading as a
  # pass; this is a non-verdict reading as a FAILURE. Red is a positive claim about someone's
  # code and an unrecognised conclusion does not license it -- and this file's own comment
  # says a false positive is what gets the tool disabled. Red becomes the allowlist; the
  # non-verdicts are handled by COVERS_PY below, which is where "we do not know" belongs.
  chk "a stale run is NOT an accusation"            "" \
      "$(verdict '[{"name":"CI","status":"completed","conclusion":"stale"}]')"
  chk "a conclusion we do not know is NOT an accusation" "" \
      "$(verdict '[{"name":"CI","status":"completed","conclusion":"some_future_thing"}]')"
  # THE CONTROLS. A check that cannot tell the fix from "never report anything red" is not
  # measuring anything.
  chk "startup_failure IS still a failure"          "CI" \
      "$(verdict '[{"name":"CI","status":"completed","conclusion":"startup_failure"}]')"
  chk "action_required IS still a failure"          "CI" \
      "$(verdict '[{"name":"CI","status":"completed","conclusion":"action_required"}]')"

  # ==== EVERY [!!] MUST SET CI_UNVERIFIED, OR THE VERDICT CONTRADICTS THE FINDING =======
  #
  # STRUCTURAL, BECAUSE THE UNIT TEST ABOVE CANNOT SEE IT. `verdict()` exercises the
  # reducer; the bug this catches lives in the shell around it, where a branch prints an
  # alarm and the summary line — conditioned on CI_UNVERIFIED — still says [OK].
  #
  # OBSERVED 2026-08-16 against a live billing block: the same run printed "CI IS NOT
  # RUNNING on origin/main" and then "[OK] CI green on main" eight lines below it. Two of
  # the three alarm branches set the flag and the third did not, so the tool detected the
  # problem and then reported green in the one line a reader skims to. This programme's
  # signature defect, inside the check written to catch it.
  #
  # Asserted on the SOURCE rather than by simulating a billing outage, because the outage
  # needs GitHub to be broken in a specific way and the invariant does not: an alarm and a
  # verdict that disagree is wrong however it was reached.
  # SCOPED TO THE "IT DID NOT RUN" ALARMS, and the scoping is the point. Alert alarms
  # (Dependabot, code scanning) are a different axis — CI ran fine and something else is
  # wrong — and `[!!] CI IS RED` is verified-and-failing, which is the opposite of
  # unverified. My first version of this check asserted on every `[!!]` and failed on four
  # branches that were correct; a check that flags correct code gets deleted, not obeyed.
  _alarm_lines="$(grep -nE 'echo "\[!!\].*(NO WORKFLOW RUN|NOT RUNNING)' "$0" | cut -d: -f1)"
  _unset_alarms=""
  for _al in $_alarm_lines; do
    _from=$(( _al > 14 ? _al - 14 : 1 ))
    sed -n "${_from},${_al}p" "$0" | grep -q 'CI_UNVERIFIED=1' \
      || _unset_alarms="$_unset_alarms $_al"
  done
  chk "every 'did not run' alarm marks CI unverified (lines that do not)" "" \
      "$(printf '%s' "$_unset_alarms" | sed 's/^ *//')"

  # ==== ...AND EVERY ONE OF THEM MUST BE BEHIND "COULD WE ASK AT ALL" ==================
  #
  # Same shape as the check above, one question earlier. That one asserts the verdict agrees
  # with the alarm; this one asserts the alarm is entitled to fire. On 2026-09-11 both
  # branches were internally consistent — they set the flag, the verdict said [..] — and
  # both were reporting a CI outage that did not exist, because `gh` was authenticated as an
  # account that could not see the repository and a 404 arrives here as an empty string.
  #
  # STRUCTURAL, for the same reason: simulating it needs a second GitHub account with the
  # wrong permissions, and the invariant does not. An alarm about the remote that fires
  # without first establishing the remote answered is wrong however it was reached.
  # SCOPED TO THE ALARMS THAT FIRE FROM AN ABSENT ANSWER, and the scoping is the point —
  # the same lesson the check above records. "CI IS NOT RUNNING" fires only when the run
  # list came back POPULATED and a job in it had zero steps: the remote answered, so that
  # branch needs no identity guard and flagging it would flag correct code. Only the two
  # branches that conclude from an EMPTY answer are in scope.
  _absent_alarms="$(grep -nE 'echo "\[!!\].*NO WORKFLOW RUN' "$0" | cut -d: -f1)"
  chk "both absent-answer alarms are found by the scan" "2" \
      "$(printf '%s\n' $_absent_alarms | grep -c . )"
  _unguarded=""
  for _al in $_absent_alarms; do
    _from=$(( _al > 20 ? _al - 20 : 1 ))
    sed -n "${_from},${_al}p" "$0" | grep -q 'cannot_ask_note' \
      || _unguarded="$_unguarded $_al"
  done
  chk "every 'did not run' alarm is behind cannot_ask_note (lines that are not)" "" \
      "$(printf '%s' "$_unguarded" | sed 's/^ *//')"

  # ==== A VERIFIED-AND-FAILING CI IS THE THIRD ANSWER, AND ci_word HAD TWO (#312) =======
  #
  # The structural check above is RIGHT to exempt the red alarm from CI_UNVERIFIED, and the
  # reasoning it records is still correct: a red build is the OPPOSITE of unverified, and
  # setting that flag there would trade one false sentence for another. What the exemption
  # never noticed is that it had nowhere to go. ci_word() branched on CI_UNVERIFIED alone,
  # so "verified and RED" fell through to the same string as "verified and green".
  #
  # OBSERVED in this repository: report() prints the red alarm, and thirty lines further
  # down the SAME function report_alerts() prints the verdict through ci_word() -- which
  # said green about the identical sha, four lines under the alarm. This programme's
  # signature defect once more, and the reason the two structural checks above could not
  # see it is that nothing was missing from either call site. A vocabulary that is
  # two-valued over a three-valued domain cannot be repaired by adding conditionals to its
  # callers; the third word has to exist first. Same lesson as the three-outcome rewrites
  # of dependency_audit and run_verify: 0, 1 and "could not run" are three answers.
  _saved_red="${CI_RED:-}"
  CI_RED=1; CI_UNVERIFIED=""
  chk "a RED verdict never says green"             "" "$(ci_word main | grep -o 'CI green')"
  chk "a RED verdict names itself red"             "1" "$(ci_word main | grep -c 'RED')"
  chk "a RED verdict does not print the [OK] tag"  "" "$(ci_tag | grep -o '\[OK\]')"
  # THE LINE THE READER ACTUALLY SEES. ci_word is the phrase; alert_line is the sentence it
  # lands in, and alert_line is what printed four lines below the alarm. Testing only the
  # phrase would leave the observed defect untested.
  chk "the alert summary never says green while CI is red" "" \
      "$(alert_line 1 3 main 2>&1 | grep -o 'CI green')"
  # THE CONTROL. A check that cannot distinguish the fix from a blanket refusal to say green
  # is not measuring anything -- this one fails if the third state swallows the first.
  CI_RED=""; CI_UNVERIFIED=""
  chk "...and an ordinary green run still says green" "1" "$(ci_word main | grep -c 'CI green')"
  CI_RED="$_saved_red"

  # STRUCTURAL, exactly like the two scans above and for the same reason: reaching this
  # branch live needs a genuinely red remote, and the invariant does not.
  _red_alarm="$(grep -nE 'echo "\[!!\] CI IS RED' "$0" | cut -d: -f1)"
  chk "the red alarm is found by the scan" "1" "$(printf '%s\n' $_red_alarm | grep -c . )"
  _red_unset=""
  for _al in $_red_alarm; do
    _from=$(( _al > 14 ? _al - 14 : 1 ))
    sed -n "${_from},${_al}p" "$0" | grep -q 'CI_RED=1' || _red_unset="$_red_unset $_al"
  done
  chk "the red alarm marks CI red (lines that do not)" "" \
      "$(printf '%s' "$_red_unset" | sed 's/^ *//')"

  # ---- repo_nwo(): the half of the identity probe that can be tested offline ------------
  # It exists as a separate function precisely so these cases can exist. The failure it
  # guards against is subtle: a nwo with a trailing path builds a URL that 404s for a reason
  # that has nothing to do with the account, and the note would then blame the wrong thing.
  nwo_case() {  # nwo_case <label> <expected|EMPTY> <url>
    local got; got="$(repo_nwo "$3" 2>/dev/null)" || got=""
    chk "$1" "$2" "$got"
  }
  nwo_case "https remote"            "Robiton/thing" "https://github.com/Robiton/thing.git"
  nwo_case "https remote, no .git"   "Robiton/thing" "https://github.com/Robiton/thing"
  nwo_case "ssh scp-style remote"    "Robiton/thing" "git@github.com:Robiton/thing.git"
  nwo_case "ssh:// remote"           "Robiton/thing" "ssh://git@github.com/Robiton/thing.git"
  nwo_case "token in the url"        "Robiton/thing" "https://x-access-token:abc@github.com/Robiton/thing.git"  # scaffold:not-a-secret
  nwo_case "trailing slash"          "Robiton/thing" "https://github.com/Robiton/thing/"
  # NOT GITHUB, AND NOT OURS TO JUDGE. usable() already refuses a non-github origin; this is
  # the second line of that same refusal, so the note never fires on a GitLab remote.
  nwo_case "a gitlab remote is refused"  "" "https://gitlab.com/Robiton/thing.git"
  nwo_case "a local path is refused"     "" "/Users/someone/repos/thing"
  nwo_case "an empty url is refused"     "" ""
  # A DEEPER PATH IS NOT AN owner/repo. Left unrefused this produced `repos/a/b/c`, whose
  # 404 says nothing about who is asking.
  nwo_case "a deeper path is refused"    "" "https://github.com/Robiton/thing/tree/main"
  nwo_case "an owner with no repo is refused" "" "https://github.com/Robiton"

  # ---- classify_runs_probe(): ZERO IS AN ANSWER --------------------------------------
  # The `repos/<nwo>` probe this replaced asked the wrong question. A token with `repo` and
  # without `actions` reads the repository fine and 403s on the runs endpoint, so the note
  # would have gone back to announcing an outage by a second door. This asks the endpoint
  # whose empty result is being interpreted, and `total_count` separates "200, none" from
  # "never got a 200" in one field.
  crp_case() {  # crp_case <label> <probe output> <expected>
    chk "$1" "$3" "$(classify_runs_probe "$2")"
  }
  # THE ONE THAT MATTERS. A repository with genuinely no runs answers 0, and that IS an
  # answer about CI -- suppressing it would silence the real no-runs alarm on exactly the
  # repositories that need it. A `-n`-style check gets this backwards.
  crp_case "a count of ZERO is an answer, not a failure to ask" "0"    "answered"
  crp_case "a real count is an answer"                          "1216" "answered"
  crp_case "nothing came back — could not ask"                  ""     "could-not-ask"
  crp_case "jq printing null — could not ask"                   "null" "could-not-ask"
  crp_case "a JSON error body — could not ask" '{"message":"Not Found"}' "could-not-ask"
  crp_case "an HTML error page — could not ask" "<html>502</html>"       "could-not-ask"
  crp_case "a number with trailing text is not a count" "0 runs"         "could-not-ask"

  # ---- --check: the flag the shipped workflow promised before it existed ---------------
  # scaffold-check.yml:87 has told readers to run this since before it was written, in the
  # paragraph about a malformed value killing the run at parse time. Reported by an adopter
  # against 0.105.0. The ARGUMENT path is asserted because it is the one that matters: the
  # value being validated is not in GitHub yet, which is the entire reason to check locally.
  chk_case() {  # chk_case <label> <expected rc> <value>
    local rc=0
    check_runner_value "$3" >/dev/null 2>&1 || rc=$?
    chk "$1" "$2" "$rc"
  }
  chk_case "a one-leg list is accepted"        "0" '[["self-hosted","Linux"]]'
  chk_case "the documented two-leg list"       "0" '[["self-hosted","macOS"],["self-hosted","Linux"]]'
  chk_case "a plain string list is accepted"   "0" '["ubuntu-latest"]'
  # THE CASE THE FLAG EXISTS FOR. Unquoted labels are the mistake a person actually makes,
  # and fromJSON dies on it before any step exists -- no steps, no log, no mention of the
  # variable. Locally it must be a loud 1, never a quiet 0.
  chk_case "unquoted labels are MALFORMED"     "1" '[[self-hosted,Linux]]'
  chk_case "a bare string is malformed"        "1" 'self-hosted'
  chk_case "an object is malformed"            "1" '{"os":"linux"}'
  chk_case "an empty array is malformed"       "1" '[]'
  chk_case "a nested empty array is malformed" "1" '[[]]'
  chk_case "mixed types in a leg are malformed" "1" '[["self-hosted",1]]'
  # EMPTY IS NOT MALFORMED. An unset variable is the documented default, and reporting it as
  # a defect would redden every repository that has deliberately not retargeted CI.
  chk_case "an empty value is the documented default, not an error" "0" ''

  # STRUCTURAL: the fetch must read the EXIT CODE, not just the output. `gh api` on a variable
  # that does not exist prints a 404 JSON BODY to stdout and exits non-zero; taking the output
  # alone fed that body to the classifier, which correctly called it malformed -- so a repo
  # that had simply never set the variable was told its config was broken. Found the first
  # time this ran anywhere but where it was built. Asserted on the source because reproducing
  # it needs a repository without the variable, and the invariant does not.
  chk "the runner fetch checks gh's exit code, not only its output" "2" \
      "$(grep -c 'rc_list=\$?\||| rc_one=\$?' "$0")"
  chk "...and discards the body when that code is non-zero" "2" \
      "$(sed -n '/^check_runner_value/,/^}/p' "$0" | grep -c '|| val=""\||| single=""')"

  # ==== THE DECLARED OUTAGE: QUIETER, NEVER GREEN, AND IT EXPIRES ======================
  #
  # The risk in this feature is not that it fails to suppress — it is that it suppresses
  # too well, or forever. So the arms asserted are the ones that would let it rot: it must
  # still mark CI unverified WHILE ACTIVE, and it must stop suppressing once the date has
  # passed. A suppression with no end is how a fortnight's workaround becomes the reason
  # nobody noticed CI was off in November.
  _saved_until="$CI_DOWN_UNTIL"; _saved_reason="$CI_DOWN_REASON"; _saved_unv="$CI_UNVERIFIED"

  CI_DOWN_UNTIL="2099-01-01"; CI_DOWN_REASON="test reason"; CI_UNVERIFIED=""
  # DIRECT CALL for the flag — this is how report() calls it, and a $(...) capture would
  # run it in a subshell and lose the assignment. That distinction is the trap, so it is
  # asserted in both directions below rather than glossed over.
  _note_rc=0; ci_outage_note >/dev/null || _note_rc=$?
  chk "an active declaration suppresses the alarm" "0" "$_note_rc"
  chk "...and still marks CI UNVERIFIED, so no line can say green" "1" "${CI_UNVERIFIED:-}"
  _note_out="$(ci_outage_note)"
  chk "...and names the date it expires" "yes" \
      "$(printf '%s' "$_note_out" | grep -q '2099-01-01' && echo yes || echo no)"
  chk "...and names preflight as the gate" "yes" \
      "$(printf '%s' "$_note_out" | grep -q 'preflight.sh' && echo yes || echo no)"
  chk "...and carries the declared reason" "yes" \
      "$(printf '%s' "$_note_out" | grep -q 'test reason' && echo yes || echo no)"
  # THE VERDICT LINE MUST AGREE. This is the same failure as the billing branch, one layer
  # up: a suppression that quietened the alarm and left [OK] behind would be strictly worse
  # than the noise it removed.
  chk "...and the verdict tag is [..] not [OK]" "[..]" "$(ci_tag)"
  # THE TRAP, ASSERTED. Captured in a subshell the flag does NOT propagate — which is why
  # every call site sets it itself. If someone "tidies" report() into a capture, this case
  # is the record of why that breaks.
  CI_UNVERIFIED=""
  _ignored="$(ci_outage_note)"
  chk "a captured call does NOT set the flag — call sites must set it themselves" "" \
      "${CI_UNVERIFIED:-}"
  CI_UNVERIFIED=1

  # EXPIRY. The whole reason this is a date and not a boolean.
  CI_DOWN_UNTIL="2000-01-01"; CI_UNVERIFIED=""
  _note_rc=0; ci_outage_note >/dev/null || _note_rc=$?
  chk "an EXPIRED declaration does not suppress — the alarm returns" "1" "$_note_rc"
  chk "...and an expired declaration is detected as expired" "yes" \
      "$(ci_outage_expired && echo yes || echo no)"
  chk "an active declaration is not treated as expired" "no" \
      "$(CI_DOWN_UNTIL=2099-01-01; ci_outage_expired && echo yes || echo no)"

  # ---- PROPERTIES 2 AND 3, WHICH WERE ANNOUNCED AND NOT IMPLEMENTED (#213) --------------
  # ASSERTED ON OUTPUT, not on a return code. runner_verdict() passed four return-code cases
  # while calling a `say` that does not exist in this file and printing nothing at all; only
  # the case that read the text caught it. These read the text.
  CI_DOWN_UNTIL="2000-01-01"; CI_UNVERIFIED=""
  _ov="$(ci_outage_overdue_note)"
  chk "an expired declaration says OVERDUE, out loud" "yes" \
      "$(printf '%s' "$_ov" | grep -qi 'OVERDUE' && echo yes || echo no)"
  chk "...and names the marker to delete" "yes" \
      "$(printf '%s' "$_ov" | grep -q 'scaffold:ci-down-until' && echo yes || echo no)"
  chk "...and the expiry date it passed" "yes" \
      "$(printf '%s' "$_ov" | grep -q '2000-01-01' && echo yes || echo no)"
  # AND IT MARKS THE RUN UNVERIFIED. An overdue declaration means this tool has been softening
  # its verdict since the date; saying so while still reporting green would be the same defect.
  CI_DOWN_UNTIL="2000-01-01"; CI_UNVERIFIED=""
  ci_outage_overdue_note >/dev/null
  chk "an overdue declaration marks the run unverified" "1" "$CI_UNVERIFIED"

  CI_DOWN_UNTIL="2099-01-01"; CI_UNVERIFIED=""
  chk "an ACTIVE declaration is never called overdue" "" "$(ci_outage_overdue_note)"
  CI_DOWN_UNTIL=""; CI_UNVERIFIED=""
  chk "no declaration is never called overdue" "" "$(ci_outage_overdue_note)"

  # PROPERTY 3: a live declaration with CI actually running suppresses nothing.
  CI_DOWN_UNTIL="2099-01-01"; CI_UNVERIFIED=""
  _sn="$(ci_outage_suppressing_nothing_note yes)"
  chk "a live declaration over a RUNNING CI says it suppresses nothing" "yes" \
      "$(printf '%s' "$_sn" | grep -qi 'suppressing nothing' && echo yes || echo no)"
  chk "...and asks for the line now, not on its expiry date" "yes" \
      "$(printf '%s' "$_sn" | grep -q 'scaffold:ci-down-until' && echo yes || echo no)"
  chk "with NO runs observed it stays silent" "" \
      "$(ci_outage_suppressing_nothing_note no)"
  CI_DOWN_UNTIL="2000-01-01"; CI_UNVERIFIED=""
  chk "an expired declaration is overdue, not suppressing-nothing" "" \
      "$(ci_outage_suppressing_nothing_note yes)"

  # NO DECLARATION AT ALL is the ordinary case and must change nothing.
  CI_DOWN_UNTIL=""; CI_UNVERIFIED=""
  _note_rc=0; ci_outage_note >/dev/null || _note_rc=$?
  chk "no declaration means no suppression" "1" "$_note_rc"
  chk "...and CI_UNVERIFIED is untouched by a no-op note" "" "${CI_UNVERIFIED:-}"

  CI_DOWN_UNTIL="$_saved_until"; CI_DOWN_REASON="$_saved_reason"; CI_UNVERIFIED="$_saved_unv"
  # AND THE COUNT IS ASSERTED, so deleting the alarms is not a way to pass this.
  chk "all three 'did not run' alarms are still present" "3" \
      "$(printf '%s\n' "$_alarm_lines" | grep -c .)"

  # ==== "NOTHING RAN" MUST NOT READ AS "NOTHING FAILED" ================================
  #
  # THE ORACLE RULE: state what would be observed if this check were silently wrong, and
  # assert that. If Actions stop — a $0 budget cap, a disabled repo, a workflow whose path
  # filters exclude the push — this file observes an empty failure list, which is byte for
  # byte what a passing build looks like. The reducer above cannot tell them apart BY
  # CONSTRUCTION, which is why the assertion has to be about the PRESENCE OF A RUN for the
  # commit rather than the absence of a failure.
  #
  # Live case, not hypothetical: a $0 cap is being set on this account with ~190 of 2,000
  # included minutes left. Every repo here is private, so when it bites, every push runs
  # nothing and the honest answer becomes "unverified" on all four.
  # THE SHIPPED PROBE, not a copy. This helper used to re-implement it, which is why the
  # cases below stayed green while the shipped behaviour gained a third answer.
  covers() { printf '%s' "$1" | HEAD_SHA="$2" python3 -c "$COVERS_PY"; }

  chk "a run for the tip counts as covered" "yes" \
      "$(covers '[{"name":"CI","status":"completed","conclusion":"success","headSha":"abc123"}]' abc123)"
  # THE ONE THE CAP MAKES REAL. Runs exist and every one is green, but they belong to an
  # OLDER commit — which is precisely the state the day the allowance runs out.
  chk "green runs for an OLDER commit do not cover the tip" "no" \
      "$(covers '[{"name":"CI","status":"completed","conclusion":"success","headSha":"old999"}]' abc123)"
  chk "an empty run list does not cover the tip" "no" \
      "$(covers '[]' abc123)"
  # A RUN STILL GOING IS ITS OWN ANSWER, AND THIS CASE USED TO ASSERT THE DEFECT (#289).
  #
  # It expected "yes" — covered — and the reasoning written beside it was half right: an
  # in-progress run is indeed pending rather than missing, and reporting it as missing would
  # fire on every push made in the last minute. But "not missing" was then read as "green",
  # and the verdict came from the PREVIOUS commit. Observed 2026-09-02: `[OK] CI green on
  # main` printed while the only run for the tip was queued.
  #
  # Pending is the third answer. Not missing, not green.
  chk "an in-progress run for the tip is PENDING, not covered" "pending" \
      "$(covers '[{"name":"CI","status":"in_progress","conclusion":null,"headSha":"abc123"}]' abc123)"
  chk "a queued run for the tip is PENDING too" "pending" \
      "$(covers '[{"name":"CI","status":"queued","conclusion":null,"headSha":"abc123"}]' abc123)"
  # AND IT MUST NOT REGRESS THE OTHER WAY. A finished run beside a queued one is an answer;
  # treating any pending row as pending would leave every busy repository unverified.
  chk "queued BESIDE completed is still covered" "yes" \
      "$(covers '[{"status":"queued","headSha":"abc123"},{"status":"completed","conclusion":"success","headSha":"abc123"}]' abc123)"
  # ...AND THAT CASE COULD NOT SEE THE DEFECT IT WAS GUARDING. Its two rows carry no
  # workflow name, so they are the SAME workflow re-run -- where one finished run really is
  # an answer. Two DIFFERENT workflows are not. Measured on a real push: Mirror finished in
  # seconds while Scaffold Check ran for another 65, and the tip reported green throughout.
  chk "a DIFFERENT workflow still running is PENDING, not covered" "pending" \
      "$(covers '[{"name":"Mirror","status":"completed","conclusion":"success","headSha":"abc123"},{"name":"Scaffold Check","status":"in_progress","conclusion":null,"headSha":"abc123"}]' abc123)"
  # The re-run case, stated explicitly now that names decide it: same workflow, one finished.
  chk "a re-run of the SAME workflow beside a finished one is covered" "yes" \
      "$(covers '[{"name":"CI","status":"queued","conclusion":null,"headSha":"abc123"},{"name":"CI","status":"completed","conclusion":"success","headSha":"abc123"}]' abc123)"
  # Every workflow finished is the ordinary green.
  chk "every workflow finished is covered" "yes" \
      "$(covers '[{"name":"Mirror","status":"completed","conclusion":"success","headSha":"abc123"},{"name":"CI","status":"completed","conclusion":"success","headSha":"abc123"}]' abc123)"

  # ==== A RUN THAT COMPLETED AND REACHED NO VERDICT IS NOT A PASS =======================
  #
  # THE SAME DEFECT AS #312, ONE LAYER DOWN, AND IT WAS LIVE. This asked only whether a run
  # COMPLETED, never what it concluded, so a CANCELLED run answered "yes" -- and with the
  # reducer correctly declining to call cancelled a failure, the verdict line printed
  # "[OK] CI green". Measured by driving both constants across every conclusion GitHub can
  # return: cancelled gave covers=yes with no red row, which is a non-verdict reading as a
  # pass in the one tool written to prevent exactly that.
  #
  # `novrd` is the fourth answer. It is NOT `pending` -- the run finished, and telling
  # someone to wait for it is wrong -- and it is NOT `no`, because a run did exist. Same
  # rule as everywhere here: yes, no, not-yet and no-answer are four different things, and
  # collapsing any of them into "yes" is how this class of bug ships.
  chk "a CANCELLED run completed but reached no verdict" "novrd" \
      "$(covers '[{"name":"CI","status":"completed","conclusion":"cancelled","headSha":"abc123"}]' abc123)"
  chk "a STALE run reached no verdict either"            "novrd" \
      "$(covers '[{"name":"CI","status":"completed","conclusion":"stale","headSha":"abc123"}]' abc123)"
  chk "a conclusion we do not know is no verdict"        "novrd" \
      "$(covers '[{"name":"CI","status":"completed","conclusion":"some_future_thing","headSha":"abc123"}]' abc123)"
  # STILL RUNNING OUTRANKS NO-VERDICT. One workflow cancelled while another is genuinely
  # in flight is pending: the commit may yet be answered, and novrd would close the door.
  chk "cancelled BESIDE a running workflow is still pending" "pending" \
      "$(covers '[{"name":"A","status":"completed","conclusion":"cancelled","headSha":"abc123"},{"name":"B","status":"in_progress","conclusion":null,"headSha":"abc123"}]' abc123)"
  # A FAILING RUN IS A VERDICT. Red is an answer, and it must not be diverted into novrd --
  # that would turn every red build into "we could not tell", which is the #312 defect
  # wearing the fix's clothes.
  chk "a FAILED run is a verdict, not a gap"             "yes" \
      "$(covers '[{"name":"CI","status":"completed","conclusion":"failure","headSha":"abc123"}]' abc123)"
  chk "skipped and neutral are verdicts"                 "yes" \
      "$(covers '[{"name":"A","status":"completed","conclusion":"skipped","headSha":"abc123"},{"name":"B","status":"completed","conclusion":"neutral","headSha":"abc123"}]' abc123)"

  # ==== novrd MUST NAME WHICH WORKFLOW REACHED NO VERDICT ===============================
  #
  # "A run reached NO VERDICT ... re-running is what resolves it" is WRONG ADVICE in the
  # commonest way this state occurs. Master Control pulled the last 60 Mirror runs: 11 were
  # cancelled, 11 of 11 because a later push superseded them -- and 6 of those 11 were
  # `chore(version)` / `chore(release)` commits, because cutting a release IS the
  # double-push pattern. So a release commit spends a window as the tip with the gate GREEN
  # and a cancelled Mirror beside it, and the tool tells the person who just cut the release
  # to re-run something that does not need re-running.
  #
  # The gap is real and must stay -- we genuinely do not have a verdict for every workflow.
  # What was missing is the one fact that lets a reader act: WHICH workflow, and how it
  # ended. "Scaffold Check" reaching no verdict is a thing to chase; a superseded mirror is
  # a thing to ignore, and the bare sentence could not tell them apart.
  novrd_names() { printf '%s' "$1" | HEAD_SHA="$2" python3 -c "$NOVRD_PY" | paste -sd, - ; }
  chk "names the workflow and how it ended" "Mirror (cancelled)" \
      "$(novrd_names '[{"name":"Mirror","status":"completed","conclusion":"cancelled","headSha":"abc"},{"name":"Scaffold Check","status":"completed","conclusion":"success","headSha":"abc"}]' abc)"
  chk "lists every workflow without a verdict" "A (cancelled),B (stale)" \
      "$(novrd_names '[{"name":"A","status":"completed","conclusion":"cancelled","headSha":"abc"},{"name":"B","status":"completed","conclusion":"stale","headSha":"abc"}]' abc)"
  # THE CONTROL. A workflow that DID reach a verdict must never be named as a gap, or the
  # line blames the run that actually answered.
  chk "a workflow that answered is never named" "" \
      "$(novrd_names '[{"name":"Scaffold Check","status":"completed","conclusion":"success","headSha":"abc"}]' abc)"
  # AND IT READS THE TIP, not every run in the list -- an older superseded sha is not this
  # commit's gap.
  chk "a cancelled run for an OLDER commit is not this tip's gap" "" \
      "$(novrd_names '[{"name":"Mirror","status":"completed","conclusion":"cancelled","headSha":"older"}]' abc)"

  # AND THE GUARD ON THE REASSURANCE. Reporting the missing run and then printing
  # "[OK] CI green" two lines later is worse than either message on its own, so every green
  # claim in this file must be conditioned on CI_UNVERIFIED. Source-level, because the state
  # needs a live GitHub answering "no runs" and a fixture cannot produce one.
  # `gree[n]` matches "green" but this line does not match itself — without that the check
  # reports its own grep as a defect, which is the false positive it exists to prevent
  # wearing the check's clothes. Comment lines are excluded; prose about the rule is not a
  # claim, and requiring the rationale to omit the word would delete the reason it exists.
  local _unguarded _greenpat _prod_end
  _greenpat='CI gree[n]'
  # SCOPED TO THE SHIPPED REGION, which is everything above selftest(). The rule is about
  # what the tool PRINTS, and every printing path is defined up there. Assertions below it
  # must name the literal they assert on -- #312 added four that grep for the green string
  # to prove the red verdict never emits it -- and flagging those is this check reporting
  # its own tests as the defect. The same false positive `gree[n]` already dodges one scope
  # in, and the same lesson the two alarm scans above record: a check that flags correct
  # code gets deleted, not obeyed. A claim in production is still caught, because
  # production cannot live below this line.
  _prod_end="$(grep -n '^selftest() {' "$ROOT/tools/ci_status.sh" | head -1 | cut -d: -f1)"
  _unguarded="$(sed -n "1,$(( _prod_end - 1 ))p" "$ROOT/tools/ci_status.sh" \
                 | grep -nE "$_greenpat" \
                 | grep -vE '^[0-9]+: *#' \
                 | grep -vE "^[0-9]+: *printf 'CI gree" || true)"
  chk "no green sentence is built outside ci_word()" "" "$_unguarded"

  # SILENT WHEN IT CANNOT ASK. Run it somewhere with no git repo at all: it must print
  # nothing and exit 0, or session start becomes noise on every offline machine.
  local T out rc
  T="$(mktemp -d "${TMPDIR:-/tmp}/ci_status.XXXXXX")" || return 1
  out="$( cd "$T" && bash "$ROOT/tools/ci_status.sh" 2>&1 )"; rc=$?
  chk "outside a git repo: silent"        "" "$out"
  chk "outside a git repo: exits 0"       0  "$rc"
  # And with --verbose it SAYS it did not check, rather than implying a pass.
  out="$( cd "$T" && bash "$ROOT/tools/ci_status.sh" --verbose 2>&1 )"
  case "$out" in
    *"not checked"*) chk "--verbose says it did not check" 1 1 ;;
    *)               chk "--verbose says it did not check" 1 0 ;;
  esac
  rm -rf "$T"

  # HAS_REAL_DEPENDENCIES IS THE WHOLE JUDGEMENT, so it gets the cases. Everything else in
  # the alerts path is one API call and a number; this is where the check decides whether
  # silence is correct, and getting it wrong in either direction kills the report — nag on
  # an empty manifest and people stop reading, stay quiet on a real one and it is a false
  # all-clear.
  local D
  D="$(mktemp -d "${TMPDIR:-/tmp}/ci_status.XXXXXX")" || return 1
  dep_case() {  # dep_case <label> <expected 0|1> <setup>
    rm -rf "$D/r"; mkdir -p "$D/r"; ( cd "$D/r" && eval "$3" )
    local got; ( cd "$D/r" && has_real_dependencies ) && got=0 || got=1
    if [ "$got" = "$2" ]; then printf '  ok   %-56s\n' "$1"
    else printf '  FAIL %-56s want %s got %s\n' "$1" "$2" "$got"; fails=$((fails + 1)); fi
  }

  dep_case "a bare repo has nothing to scan"            1 "true"
  dep_case "requirements.txt counts"                    0 "printf 'requests==2.0\n' > requirements.txt"
  dep_case "an EMPTY requirements.txt does not"         1 ": > requirements.txt"
  dep_case "package.json counts"                        0 "printf '{}\n' > package.json"
  dep_case "go.mod counts"                              0 "printf 'module x\n' > go.mod"
  # THE LIVE CASE. localcoder ships this exact shape and documents being stdlib-only as a
  # feature — warning about it every session would be the noise that gets the report muted.
  dep_case "pyproject with dependencies = [] does not"  1 "printf 'dependencies = []\n' > pyproject.toml"
  # AND THE DAY SOMEONE ADDS ONE LINE. This is the transition the check exists for: an
  # ordinary commit that nobody thinks of as a security change.
  dep_case "pyproject with a real dependency counts"    0 "printf 'dependencies = [\"requests\"]\n' > pyproject.toml"
  dep_case "a multi-line dependencies list counts"      0 "printf 'dependencies = [\n  \"requests\",\n]\n' > pyproject.toml"
  dep_case "a multi-line EMPTY list does not"           1 "printf 'dependencies = [\n]\n' > pyproject.toml"
  # A pyproject with no dependencies key at all is not a declaration of anything.
  dep_case "pyproject with no dependencies key"         1 "printf '[project]\nname = \"x\"\n' > pyproject.toml"
  rm -rf "$D"

  # ---- the variable must have a reader ------------------------------------------------
  rvv_case() {   # rvv_case <label> <var> <expected rc> <stdin>
    local got=0
    printf '%b' "$4" | runner_var_verdict "$2" >/dev/null 2>&1 || got=$?
    if [ "$got" = "$3" ]; then printf '  ok   %-56s\n' "$1"
    else printf '  FAIL %-56s expected=%s got=%s\n' "$1" "$3" "$got"; fails=$((fails + 1)); fi
  }
  rvv_case "unset variable says nothing, whatever the workflows" unset 0 ".github/workflows/a.yml\n"
  rvv_case "set and every workflow reads it is fine"             set   0 ""
  rvv_case "set with NO reader is reported, not silence"         set   1 ".github/workflows/a.yml\n"
  # A PARTIAL MIGRATION IS THE ADOPTER'S "two truths" CASE, and it must fire too: one
  # workflow retargeted and three not is how a repo ends up disagreeing with itself.
  rvv_case "set with SOME readers still fires"                   set   1 ".github/workflows/b.yml\n.github/workflows/c.yml\n"
  if [ "$(printf '.github/workflows/gdscript-lint.yml\n' | runner_var_verdict set 2>/dev/null | grep -c 'gdscript-lint.yml')" = "1" ]; then
    printf '  ok   %-56s\n' "the warning names the workflows that do not read it"
  else printf '  FAIL %-56s\n' "the warning names the workflows that do not read it"; fails=$((fails + 1)); fi

  # THE SCANNER NEEDS CASES TOO. Feeding runner_var_verdict via stdin left
  # workflows_not_reading_var entirely untested, and a mutation swapping its pattern for
  # `runs-on` passed every case above -- a check on a check, with nothing on the half that
  # actually reads the repository.
  _W="$(mktemp -d "${TMPDIR:-/tmp}/ci_status.XXXXXX")" || { echo "ci_status: mktemp failed; stopping" >&2; exit 1; }; mkdir -p "$_W/.github/workflows"
  {
    echo "jobs:"
    echo "  x:"
    printf '    runs-on: ${{ vars.%s || %s }}\n' "$RUNNER_VAR" "'ubuntu-latest'"
  } > "$_W/.github/workflows/good.yml"
  printf 'jobs:\n  y:\n    runs-on: ubuntu-latest\n' > "$_W/.github/workflows/bad.yml"
  # BOTH OF THESE WERE PREDICTED BY A REVIEWER, NOT FOUND BY A TEST, and both were real.
  # A comment mentioning the variable counted as a read -- and this repo's own shipped
  # workflow carries exactly such a comment, so copying that block above a hardcoded
  # runs-on passed the check.
  printf 'jobs:\n  x:\n    # vars.%s is empty when unset\n    runs-on: ubuntu-latest\n' \
    "$RUNNER_VAR" > "$_W/.github/workflows/comment-only.yml"
  # And a workflow with one job reading it and one not read as "reading" at file
  # granularity -- the intra-file partial migration this check exists to catch, invisible
  # in exactly the case cheapest to create.
  {
    echo "jobs:"
    echo "  a:"
    printf '    runs-on: ${{ vars.%s }}\n' "$RUNNER_VAR"
    echo "  b:"
    echo "    runs-on: ubuntu-latest"
  } > "$_W/.github/workflows/partial.yml"
  # A file with no runs-on: at all has nothing to retarget and must not be a finding.
  printf 'name: docs only\non: push\n' > "$_W/.github/workflows/norunson.yml"
  # THE MATRIX SHAPE, which is what scaffold-check.yml became. `runs-on: ${{ matrix.runner }}`
  # is the documented false positive this scanner used to produce; it must now resolve.
  {
    echo "jobs:"
    echo "  x:"
    echo "    strategy:"
    echo "      matrix:"
    printf '        runner: ${{ fromJSON(vars.%s || %s) }}\n' "$RUNNER_VAR_LIST" "'[\"ubuntu-latest\"]'"
    echo '    runs-on: ${{ matrix.runner }}'
  } > "$_W/.github/workflows/matrix-good.yml"
  # ...and the indirection must not become a blanket excuse. A matrix key built from
  # something OTHER than the variable is still an unretargeted workflow, and this is the
  # case that would let a hardcoded fleet hide behind the word "matrix".
  {
    echo "jobs:"
    echo "  x:"
    echo "    strategy:"
    echo "      matrix:"
    echo '        runner: [ubuntu-latest, ubuntu-22.04]'
    echo '    runs-on: ${{ matrix.runner }}'
  } > "$_W/.github/workflows/matrix-bad.yml"
  # A DIFFERENT KEY MUST NOT SATISFY IT. The matrix defines `runner` from the variable but
  # runs-on reads `os`, so nothing is retargeted -- the same class as the comment-only case,
  # one level deeper.
  {
    echo "jobs:"
    echo "  x:"
    echo "    strategy:"
    echo "      matrix:"
    printf '        runner: ${{ fromJSON(vars.%s) }}\n' "$RUNNER_VAR_LIST"
    echo '        os: [ubuntu-latest]'
    echo '    runs-on: ${{ matrix.os }}'
  } > "$_W/.github/workflows/matrix-wrongkey.yml"
  _got="$( cd "$_W" && workflows_not_reading_var )"
  _want=".github/workflows/bad.yml
.github/workflows/comment-only.yml
.github/workflows/matrix-bad.yml
.github/workflows/matrix-wrongkey.yml
.github/workflows/partial.yml"
  if [ "$(printf '%s\n' "$_got" | sort)" = "$(printf '%s\n' "$_want" | sort)" ]; then
    printf '  ok   %-56s\n' "scanner flags hardcoded, comment-only AND partial files"
  else
    printf '  FAIL %-56s got=%s\n' "scanner flags hardcoded, comment-only AND partial files" "$(printf '%s' "$_got" | tr '\n' ' ')"
    fails=$((fails + 1))
  fi
  case "$_got" in
    *matrix-good.yml*|*norunson.yml*)
      printf '  FAIL %-56s\n' "a fully-retargeted or runs-on-less file is not flagged"
      fails=$((fails + 1)) ;;
    *) printf '  ok   %-56s\n' "a fully-retargeted or runs-on-less file is not flagged" ;;
  esac
  # AN EMPTY VALUE IS ITS OWN ANSWER: present, read by every workflow, retargeting nothing.
  rvv_case "an EMPTY variable value is reported, not treated as set" empty 1 ""
  # The CLASSIFIER, separately from the verdict. `null` is what `gh --jq .value` prints for
  # a variable that exists with no value, and it must not read as a usable label.
  cv_case() {
    local got; got="$(classify_var_value "$2")"
    if [ "$got" = "$3" ]; then printf '  ok   %-56s\n' "$1"
    else printf '  FAIL %-56s expected=%s got=%s\n' "$1" "$3" "$got"; fails=$((fails + 1)); fi
  }
  cv_case "an empty string classifies as empty, not set"   ""            empty
  cv_case "jq's null classifies as empty, not set"         "null"        empty
  cv_case "a real label classifies as set"                 "self-hosted" set
  # THE LIST CLASSIFIER. A malformed value is not "unset with a fallback" -- fromJSON kills
  # the run before any step exists, so it must be its own loud answer.
  cl_case() {
    local got; got="$(classify_list_value "$2")"
    if [ "$got" = "$3" ]; then printf '  ok   %-56s\n' "$1"
    else printf '  FAIL %-56s expected=%s got=%s\n' "$1" "$3" "$got"; fails=$((fails + 1)); fi
  }
  cl_case "a list of labels classifies as set"      '["ubuntu-latest"]'                 set
  cl_case "a list of label ARRAYS classifies as set" '[["self-hosted","macOS"]]'        set
  cl_case "a bare label is malformed, not set"      'self-hosted'                        malformed
  cl_case "unclosed JSON is malformed"              '[["self-hosted"'                    malformed
  cl_case "an EMPTY array is malformed, not set"    '[]'                                 malformed
  cl_case "a JSON object is malformed"              '{"os":"linux"}'                     malformed
  cl_case "an empty value classifies as empty"      ''                                   empty
  cl_case "jq null classifies as empty"             'null'                               empty
  rvv_case "a malformed list is reported, not treated as set" malformed 1 ""
  # ---- a leg naming labels no runner has (queues, never fails) ------------------------
  # THE MATCHER, WITH NO NETWORK. Registered-runner lines go in on stdin, the variable's
  # value goes in as $1, and the unsatisfiable legs come out. Every case below is one
  # someone can actually create with a single `gh variable set`.
  _MACOS="self-hosted,macOS,ARM64	online"
  _LINUX="self-hosted,Linux,X64	online"
  ul_case() {   # ul_case <label> <runners> <value> <expected output>
    local got
    got="$(printf '%s\n' "$2" | unsatisfiable_legs "$3" | tr '\n' ' ' | sed 's/ *$//')"
    if [ "$got" = "$4" ]; then printf '  ok   %-56s\n' "$1"
    else printf '  FAIL %-56s want=[%s] got=[%s]\n' "$1" "$4" "$got"; fails=$((fails + 1)); fi
  }
  ul_case "a Linux leg with only a macOS runner is unsatisfiable" \
          "$_MACOS" '[["self-hosted","macOS"],["self-hosted","Linux"]]' "self-hosted,Linux"
  ul_case "...and satisfiable once a Linux runner is registered" \
          "$_MACOS
$_LINUX" '[["self-hosted","macOS"],["self-hosted","Linux"]]' ""
  # HOSTED LABELS ARE GITHUB'S. Flagging ubuntu-latest as unsatisfiable would fire on the
  # shipped default in every adopter that has no self-hosted runner at all -- i.e. red on
  # arrival, the hazard this project keeps naming.
  ul_case "a hosted label is never unsatisfiable" \
          "" '["ubuntu-latest"]' ""
  ul_case "the shipped default with NO runners at all is quiet" \
          "" '["ubuntu-latest"]' ""
  # AN OFFLINE RUNNER CANNOT SATISFY A LEG. runner_verdict already reports it as offline;
  # this must not ALSO call the leg satisfiable, or the two checks contradict each other.
  ul_case "an OFFLINE runner does not satisfy a leg" \
          "self-hosted,Linux,X64	offline" '[["self-hosted","Linux"]]' "self-hosted,Linux"
  # A SUPERSET OF LABELS SATISFIES. The runner carries ARM64 too; the leg does not ask.
  ul_case "extra labels on the runner still satisfy the leg" \
          "$_MACOS" '[["self-hosted","macOS"]]' ""
  # ...AND A SUBSET DOES NOT. This is the direction that matters: asking for X64 when the
  # only runner is ARM64 must not pass merely because both say self-hosted.
  ul_case "a leg asking for a label the runner lacks is unsatisfiable" \
          "$_MACOS" '[["self-hosted","X64"]]' "self-hosted,X64"
  ul_case "a bare self-hosted string leg is matched, not skipped" \
          "" '["self-hosted"]' "self-hosted"
  # MALFORMED IS classify_list_value'S JOB, NOT THIS ONE. Two checks both shouting about one
  # typo is how a report gets skimmed.
  ul_case "malformed JSON is left to the classifier, not double-reported" \
          "$_MACOS" 'self-hosted' ""
  uv_case() {   # uv_case <label> <stdin legs> <expected rc>
    local got=0
    printf '%b' "$2" | unsatisfiable_verdict >/dev/null 2>&1 || got=$?
    if [ "$got" = "$3" ]; then printf '  ok   %-56s\n' "$1"
    else printf '  FAIL %-56s expected=%s got=%s\n' "$1" "$3" "$got"; fails=$((fails + 1)); fi
  }
  uv_case "no unsatisfiable legs says nothing and passes"  ""                    0
  uv_case "an unsatisfiable leg is reported, not silence"  "self-hosted,Linux\n" 1
  if [ "$(printf 'self-hosted,Linux\n' | unsatisfiable_verdict 2>/dev/null | grep -c 'QUEUE')" -ge 1 ]; then
    printf '  ok   %-56s\n' "the message says the job QUEUES rather than fails"
  else
    printf '  FAIL %-56s\n' "the message does not say the job queues"; fails=$((fails + 1))
  fi
  # ---- the alert line: zero features is not a zero count (#263) ----------------------
  # This branch had NO test before 0.13.0 -- it lived inline in report(), behind a network
  # call, so the only way to exercise it was to own a repo with the features off. That is
  # how "0 open alerts" shipped for a repository where nothing was watching.
  al_case() {   # al_case <label> <enabled> <must-match> <must-NOT-match>
    local got; got="$(CI_UNVERIFIED="" alert_line "$2" 3 main 2>&1)"
    if printf '%s' "$got" | grep -q "$3" && ! printf '%s' "$got" | grep -q "$4"; then
      printf '  ok   %-56s\n' "$1"
    else
      printf '  FAIL %-56s got=%s\n' "$1" "$(printf '%s' "$got" | tr '\n' ' ')"; fails=$((fails + 1))
    fi
  }
  al_case "0 features says ALERTS NOT CHECKED, never '0 open alerts'" 0 'ALERTS NOT CHECKED' '0 open alerts'
  al_case "0 features does not print the [OK] tag"                    0 'ALERTS NOT CHECKED' '\[OK\]'
  al_case "1 of 3 still reports the count AND the shortfall"          1 'only 1 of 3'        'across all'
  al_case "3 of 3 reports the clean all-features line"                3 'across all 3'      'only'
  # A REPO WITH NO WORKFLOWS AT ALL must not report every file as unretargeted, and must not
  # die on an unmatched glob -- bash 3.2 leaves the pattern literal.
  _W2="$(mktemp -d "${TMPDIR:-/tmp}/ci_status.XXXXXX")" || { echo "ci_status: mktemp failed; stopping" >&2; exit 1; }
  _got2="$( cd "$_W2" && workflows_not_reading_var )"
  if [ -z "$_got2" ]; then printf '  ok   %-56s\n' "no .github/workflows is empty, not a literal glob"
  else printf '  FAIL %-56s got=%s\n' "no .github/workflows is empty, not a literal glob" "$_got2"; fails=$((fails + 1)); fi
  rm -rf "$_W" "$_W2"

  # ---- self-hosted runners: an offline one must not be silence -----------------------
  rv_case() {   # rv_case <label> <expected rc> <stdin>
    local got=0
    printf '%b' "$3" | runner_verdict >/dev/null 2>&1 || got=$?
    if [ "$got" = "$2" ]; then printf '  ok   %-56s\n' "$1"
    else printf '  FAIL %-56s expected=%s got=%s\n' "$1" "$2" "$got"; fails=$((fails + 1)); fi
  }
  rv_case "no registered runners is not a problem"       0 ""
  rv_case "an online runner is fine"                     0 "m3\tonline\n"
  rv_case "an OFFLINE runner is reported, not silence"   1 "m3\toffline\n"
  # A STATUS THIS DOES NOT KNOW IS NOT "ONLINE". `idle`, `busy` and anything a future API
  # adds must not be read as healthy by a check whose whole purpose is noticing absence.
  rv_case "an unknown status is treated as not-online"   1 "m3\tsomething-new\n"
  rv_case "one offline among several still fires"        1 "a\tonline\nb\toffline\n"
  # The verdict must not depend on the report() exit contract, which stays 0 by design.
  if [ "$(printf 'm3\toffline\n' | runner_verdict 2>/dev/null | grep -c 'OFFLINE')" = "1" ]; then
    printf '  ok   %-56s\n' "the offline line names the runner"
  else printf '  FAIL %-56s\n' "the offline line names the runner"; fails=$((fails + 1)); fi

  # The watchdog must not outlive the command it guards, or session start hangs.
  local start elapsed
  start=$(date +%s)
  TIMEOUT_SECS=2 run_capped sleep 30 >/dev/null 2>&1
  elapsed=$(( $(date +%s) - start ))
  if [ "$elapsed" -le 4 ]; then printf '  ok   %-56s\n' "a hung call is capped, not waited on"
  else printf '  FAIL %-56s took %ss\n' "a hung call is capped, not waited on" "$elapsed"; fails=$((fails + 1)); fi

  # ---- GREEN IS AN ALLOWLIST, AND IT MUST STAY ONE (#316).
  #
  # The bug was not a wrong branch, it was a MISSING one: COVERS_PY could answer `unknown`
  # (and "" when python3 could not start) and no branch tested for either, so both fell
  # through to the green sentence. So the assertion is a CONTRACT between the two halves --
  # every value the python probe can emit must be named in the shell case that consumes it.
  # A future value added to COVERS_PY without a branch reintroduces the exact defect, and
  # this goes red the moment it does.
  # The first version of this case asserted that EVERY COVERS_PY answer appears in the
  # explicit arm, and it went red on `unknown` -- correctly, but for the wrong reason: the
  # specification was mine, not the code's. `unknown` is SUPPOSED to reach `*)`. Once that
  # arm sets CI_UNVERIFIED, any future answer is safe by construction, which is the entire
  # point of the allowlist; demanding an explicit branch per value would just be a second
  # place to forget. What actually has to hold is narrower: the arm that continues to the
  # green sentence must not contain a non-verdict.
  local _cv_arm
  _cv_arm="$(grep -m1 -oE '^ *yes\|[a-z|]+\)' "$0" | tr -d ' )')"
  case "|$_cv_arm|" in
    *"|unknown|"*) chk "'unknown' must NOT be in the pass-through arm" "absent" "present" ;;
    *)             chk "'unknown' must NOT be in the pass-through arm" "absent" "absent" ;;
  esac

  # AND THE PROBE REALLY DOES EMIT THE ONE THAT WAS UNHANDLED. Driving the shipped string,
  # not a description of it: non-JSON on stdin is what a broken run list looks like.
  chk "COVERS_PY answers 'unknown' on unparseable input" "unknown" \
      "$(printf 'not json at all' | HEAD_SHA=deadbeef python3 -c "$COVERS_PY" 2>/dev/null)"

  # THE FALLTHROUGH ARM MUST STILL REFUSE TO CALL IT GREEN. If someone makes it quiet again,
  # the verdict silently becomes a pass -- which is how this defect existed in the first place.
  if grep -A4 -E '^ *\*\)$' "$0" | grep -q 'CI_UNVERIFIED=1'; then
    printf '  ok   %-56s\n' "the unrecognised-answer arm sets CI_UNVERIFIED"
  else
    printf '  FAIL %-56s\n' "the unrecognised-answer arm sets CI_UNVERIFIED"; fails=$((fails + 1))
  fi

  echo ""
  if [ "$fails" -eq 0 ]; then echo "  all checks passed"; return 0; fi
  echo "  $fails check(s) FAILED"; return 1
}

case "${1:-}" in
  --selftest) selftest ;;
  --check)    shift; check_runner_value "$@" ;;
  --verbose)  report --verbose ;;
  "")         report ;;
  *)          echo "usage: ci_status.sh [--verbose|--selftest|--check [VALUE]]" >&2; exit 2 ;;
esac
