#!/bin/bash
# Project:  ai-project-scaffold
# File:     setup.sh
# Modified: 2026-10-10
# Version:  0.29.8.20261010.1252
# Purpose:  Initialize a project from this scaffold — interactive or non-interactive (AI-driven)
# Changelog:
#   2026-10-10 v0.29.8.20261010.1252 — the owner name is escaped before it enters the TEAM.md sed (report item 28, S11): R&D pasted the placeholder row inside the name and Ops/Infra silently changed nothing.
#   2026-09-23 v0.29.7.20260923.0941 — mktemp takes a ${TMPDIR} template. macOS mktemp ignores TMPDIR without one, so a guarded fixture root could not contain it.
#   2026-09-23 v0.29.6.20260923.0843 — every mktemp fails closed. A failed one left the temp variable empty, so the fixture ran in the caller's directory; header_check's committed into Robiton/control.
#   2026-09-22 v0.29.5.20260922.1707 — --check reads the overlay's documents: a security-
#                                      tool THREAT_MODEL.md that is missing, still the stub,
#                                      or 50+ code commits behind, and an empty docs/specs/
#                                      (Clocktower #9)
#   2026-09-22 v0.29.4.20260922.1555 — A NEW PROJECT IS NOT BORN AT THE SCAFFOLD'S VERSION
#                                      (Clocktower #1). QUICK_START's clone path leaves the
#                                      scaffold's own 'version' in place and the keep-the-
#                                      adopter's-version guard kept it; equality with
#                                      .scaffold-version is now the tell, and the file is
#                                      reset. Reproduced by adoption_check (new project at
#                                      0.110.1) before the fix, green after.
#   2026-09-22 v0.29.3.20260922.1549 — monorepo_notice compares the repo root and the cwd by
#                                      inode (-ef) as well as by resolved string (Clocktower
#                                      #6: a case-insensitive volume reported the repository
#                                      root as a SUBDIRECTORY). Not reproduced here -- pwd
#                                      -P returned the on-disk case in a plain mktemp test
#                                      -- so this is the guard, not a proven fix for their
#                                      exact path.
#   2026-09-22 v0.29.2.20260922.1548 — A SCANNER'S EXIT 3 IS A GAP, NOT A FINDING
#                                      (Clocktower #2). --check printed [FAIL] for a
#                                      tools/*_scan.sh that could not verify, telling an
#                                      adopter their repo had a problem when nothing had
#                                      been looked at. It now prints COULD NOT VERIFY, logs
#                                      'gap', and is neither [FAIL] nor [OK]. adoption_check
#                                      pins it, red with the branch removed.
#   2026-09-13 v0.29.1.20260913.1724 — #308 ai/BACKLOG.md left at 0600 by mv; #309 the --upgrade hint printed an unquoted URL.
#   2026-09-10 v0.29.0.20260910.0951 — --check REPORTS WHETHER guard_pretooluse.py IS WIRED. It turns the
#                        ai/SECURITY.md hard lines into actual rules and ships DISABLED on
#                        purpose -- a PreToolUse guard that starts asking on a machine that
#                        never opted in gets ripped out. Deliberately off is fine. SILENTLY
#                        off is not, and nothing distinguished the two.
#                        Its own changelog said so on 2026-08-09: "'has this ever fired',
#                        'what did it stop' and 'is it even wired' all had no answer, and the
#                        last of those was NO for months on this project's own machine." A
#                        month later it was still NO in all five repositories of this fleet.
#                        The guard diagnosed its own gap and no check was ever built for it.
#                        A NOTE, not a failure -- [--], this file's did-not marker, distinct
#                        from [OK] and [!]. It names what is unenforced, the shipped default,
#                        how to turn it on, and the selftest to run first.
#                        Both branches proven before commit: OFF here, and the detection
#                        returning WIRED against a fixture that wires it.
#   2026-09-10 v0.28.0.20260910.0412 — SETUP SAYS WHAT IS LIVE AND WHAT MISSED ITS MOMENT. It printed
#                        "[OK] .claude/settings.json created -- 7 hooks (session start, ...)"
#                        and stopped, which reads as "logging is on". Stop, SessionEnd and
#                        PreCompact ARE on -- Claude Code watches settings files and picks up
#                        direct hook edits without a restart. SessionStart cannot be: it fired
#                        before the hooks existed, so the session that ran setup opens NO
#                        record in ai/SESSION.md and the green line above says nothing about it.
#                        Now printed at the moment the reader is looking at the screen, with
#                        the fact that a RESUME counts -- SessionStart fires on startup, resume,
#                        clear, compact and fork, so nobody has to lose a conversation for it.
#                        MINOR: new output at a step that had none, not a corrected message.
#                        Verified by running a real init in a throwaway adoption and reading
#                        the lines back, because `bash -n` passes a heredoc whose PYTHON is
#                        broken -- which it was, twice, on the way to this.
#   2026-09-06 v0.27.0.20260906.1244 — --check REACHES THE ADOPTION THAT NEVER UPGRADES (#303). The
#                        <=v0.3.0 `ln -s AGENTS.md CLAUDE.md` instruction lives in AGENTS.md,
#                        a MERGE file, in a repository we do not own. scaffold_upgrade.sh
#                        migrates it, which closes it for upgraders and for nobody else --
#                        and an adopter runs --check far more often than they upgrade.
#                        Two detections, because the artefact outlives the sentence: the
#                        instruction still present, and CLAUDE.md actually being a symlink
#                        (somebody may have run the command once and later deleted the
#                        paragraph). SAME PATTERN AS THE MIGRATION, deliberately -- one
#                        hazard definition, two callers, so they cannot drift apart.
#                        A FAILURE, not an advisory. Everything else --check reports is
#                        hygiene; this destroys the file carrying every rule, and it does so
#                        the moment somebody follows their own documentation. Measured on a
#                        real adoption: AGENTS.md 86 bytes -> 11.
#   2026-09-06 v0.26.2.20260906.0406 — --check reports the auto-memory count (#300). Placed with
#                        the archive advisory because that is where a reader already looks for
#                        ai/ hygiene, and it is advisory for the same reason: nothing here can
#                        fail a build.
#   2026-09-04 v0.26.1.20260904.0853 — the CLAUDE.md remediation string was a FOURTH site of the symlink
#                        data-loss bug (#305). `printf > CLAUDE.md` follows a legacy <=v0.3.0
#                        symlink and truncates AGENTS.md; three guide sites were guarded and the
#                        one the TOOL emits was missed — handed to exactly the population that
#                        still has the symlink. Now detects the symlink and the legacy gitignore
#                        line separately, and names the real cause of each.
#   2026-09-04 v0.26.0.20260904.0224 — create_if_absent(): AN OVERLAY STUB IS A STARTING POINT, NOT A RESET (#299).
#                        #292 fixed `cat > .gitignore` in one overlay; the same shape was in
#                        every other one. Measured across all seven against a project that
#                        already had content: `version` was reset from 9.9.9 to 0.1.0 by ALL
#                        SEVEN — despite ADOPTION_GUIDE.md saying in so many words that the
#                        file is the adopter's and is deliberately not copied — and the
#                        security-tool overlay replaced a filled-in docs/THREAT_MODEL.md with
#                        an empty stub. Every overlay stub goes through create_if_absent now,
#                        and `version` is kept with setup saying which value it would have
#                        written. ai/MEMORY.md, ai/BACKLOG.md, ai/SESSION.md, ai/TEAM.md and
#                        the three *_ARCHIVE.md files were already safe and are now asserted.
#   2026-09-03 v0.25.0.20260903.1906 — THREE ADOPTION DEFECTS, ALL FOUND BY AN OUTSIDE REVIEWER READING A REAL
#                       ADOPTION rather than by anything in this repository (#291, #292, #296).
#                       (1) The splunk-app overlay did `cat > .gitignore` — overwrite, no
#                       backup, no message — for existing apps as well as new ones. Following
#                       ADOPTION_GUIDE.md in its own order (step 4 appends the secret rules,
#                       step 6 applies the overlay) destroyed every one of them, plus whatever
#                       the project already had, plus `.localcoder-audit.jsonl*` which this
#                       same script appends 400 lines above under a comment reading "the
#                       ordering is unforgiving". Now gitignore_ensure_lines(): exact-line,
#                       append-only, one code path.
#                       (2) build.sh's exclusion list excluded 6 of the 20 scaffold artifacts
#                       an adoption carries, so a CORRECTLY BUILT Splunk package still put
#                       tools/, .claude/, .github/ and setup.sh onto a production host. It is
#                       generated from tools/adoption_manifest.sh now, and setup.sh REFUSES to
#                       write a build.sh if the generator is missing or produces nothing.
#                       (3) monorepo_notice(): a project below a repository root gets an inert
#                       .github/ and hooks that never fire, and nothing said so. The string
#                       `monorepo` appeared in this repository exactly once before today — in
#                       a comment explaining why we stop at one level.
#                       Also: the audit-log rule asked `[ -d .git ]`, which is FALSE in a
#                       monorepo subdirectory, so the one adoption shape that most needs it
#                       never got it. Asks git now. And the generated build.sh said `App:`
#                       where header_check wants `Project:`, so every Splunk adoption failed
#                       its own `setup.sh --check` on a file we wrote.
#   2026-09-02 v0.24.0.20260902.0517 — the always-loaded TARGET is 90 KB, set by the owner
#                        (#281). It was 80, which the product could not meet without moving
#                        rules out of the load order. 90 is met with room: a fresh adoption
#                        measures 78 KB once ai/OPERATIONS.md carries the reference half.
#                        THE TARGET AND THE CEILING ARE DIFFERENT NUMBERS ON PURPOSE. The
#                        target is what the product is trying to be; the 120 KB ceiling is
#                        where an ADOPTER hears about their own growth. Collapsing them would
#                        mean either a product that is red on arrival or a ceiling that never
#                        speaks.
#   2026-09-01 v0.23.0.20260901.1656 — --check MEASURES WHAT EVERY SESSION PAYS BEFORE THE
#                        FIRST INSTRUCTION (#280). Nothing counted the always-loaded set, and
#                        it grew the way an append-only file always does: 95 KB here, 156 KB
#                        in Robiton/localcoder, 179 in localcoder-dev, 211 in
#                        ai-project-scaffold-dev -- roughly 54k tokens, a quarter of a
#                        context window. ai/SESSION.md is counted AS THE LOAD ORDER READS
#                        IT (--session-head), not as it sits on disk, so the number is a
#                        cost somebody actually pays.
#                        THE DEFAULT IS 120 KB AND THE TARGET IS 80. 80 was the number asked
#                        for and could not be the default: a FRESH adoption measures 85 KB
#                        after this release's trim, so 80 would redden every adopter on the
#                        day they adopt -- how a check gets ignored, per ai/SECURITY.md's own
#                        rule. Per project via `<!-- scaffold:context-ceiling <KB> -->`.
#   2026-09-01 v0.23.0.20260901.1656 — --install-hooks: the printed remedy now terminates
#                        (#274). Reported from Robiton/godsfall, which followed it exactly:
#                        the orphan scan listed every executable non-sample hook in
#                        .git/hooks and refused unconditionally, while the message said "copy
#                        the ones you want into .githooks/ first, then re-run this" -- and
#                        re-running refused again. core.hooksPath had to be set by hand on a
#                        repository with 1,746 LFS-tracked files.
#                        COVERED IS NOT THE SAME AS PRESENT. A .githooks/<name> that does not
#                        chain to .git/hooks/<name> silences the original as completely as no
#                        file at all, while looking like the fix. So a covering hook is
#                        skipped only when it reaches the real hooks directory through `git
#                        rev-parse --git-dir`; anything else is refused BY NAME as UNCHAINED.
#                        COMMENTS ARE STRIPPED BEFORE THE MATCH, because the paragraph in
#                        each shipped hook explaining the chain contains the same words as
#                        the chain, and would otherwise pass a hook that only describes it.
#                        A fixture proves all three cases: chaining installs, unchained is
#                        refused by name, a genuine orphan is still refused.
#                        AND header_check's output is replayed on failure instead of "run it
#                        for the detail" -- the same shape --assert-consistent already uses
#                        180 lines above, on a branch that already has the answer (#277).
#   2026-09-01 v0.22.4.20260901.0435 — TWO VERDICTS FOR ONE FILE IN ONE RUN (#265). The
#                        required-files loop printed a bare `[OK]   ai/MEMORY.md` and the
#                        archive block a few lines later printed `[!] [over] ai/MEMORY.md:
#                        873 lines`. The reassuring one came first and unqualified, so anyone
#                        scanning the tag column -- which is what a tag column is for -- took
#                        the [OK]. That loop only ever asked whether the file EXISTS; it now
#                        says "present", and the [over] branch names the one-command fix the
#                        [BURST] branch already named.
#   2026-08-31 v0.22.3.20260831.1546 — REFUSES BEFORE IT WRITES when run outside the scaffold. Every template
#                        path here is relative, so the script only works when the current
#                        directory IS the scaffold -- and running it from the TARGET, the
#                        obvious reading of "adopt the scaffold into my project", created
#                        .claude, .cursor, .github and CLAUDE.md and then died on
#                        `ai/MEMORY.md: No such file or directory`, leaving a half-configured
#                        repo that LOOKS adopted. Now exits 2 with the correct route, having
#                        written nothing. The guard sits immediately above the first write:
#                        its first placement was ~100 lines lower, where it refused correctly
#                        while its own message "Nothing has been created" was false.
#   2026-08-31 v0.22.2.20260831.0904 — #249 second instance of the same class, not named in the issue: mktemp -t failed soft here,
#                        so on Linux the scaffold:no-artifact strip silently did nothing.
#   2026-08-30 v0.22.1.20260830.0023 — THREE DEFECTS IN v0.22.0, FOUND BY TESTING THE EDGE CASES
#                        RATHER THAN THE HAPPY PATH. (1) `grep -v` exits 1 when it filters
#                        EVERY line and `set -e` is in force from line 224, so an
#                        ai/BACKLOG.md consisting of nothing but the scaffold:session-log
#                        declaration ABORTED setup.sh two thirds of the way through -- exit 1,
#                        no message. `|| true` on both strippers; the must-run one had the
#                        same latent flaw and is fixed with it. (2) The settings.json write
#                        was open("w"), which truncates before it writes -- an interrupt left
#                        the adopter's file empty. Now a sibling temp plus os.replace, which
#                        is atomic. (3) realpath() so a symlinked settings.json is written
#                        THROUGH rather than replaced. Regression-tested in adoption_check,
#                        and the test was itself mutation-proved by reverting the fix.
#   2026-08-30 v0.22.0.20260830.0005 — HOOKS ARE MERGED, NEVER SKIPPED, and there is now ONE copy
#                        of them. .claude/settings.hooks.json is the canonical set; setup.sh
#                        merges it into .claude/settings.json, replacing only the `hooks` key
#                        and preserving every sibling the adopter owns. TWO bugs, one cause:
#                        (#246) an existing settings.json -- the normal state of any repo
#                        where Claude Code has ever run, i.e. the whole adoption population --
#                        was SKIPPED, so the adopter got no hooks at all; and the heredoc that
#                        wrote the file when it was absent had drifted to ONE of SIX commands,
#                        so even a fresh project lost the session journal, correction capture,
#                        SessionEnd and both PreCompact hooks. A malformed settings.json is
#                        left untouched rather than overwritten -- it is the adopter's file.
#                        --check now compares the HOOKS, not the file's existence: it reported
#                        [OK] on an empty object, exactly the state the skip left behind.
#                        ALSO (#244): the inherited `scaffold:session-log` declaration is
#                        stripped from ai/BACKLOG.md for a new project, unless the -dev sibling
#                        it names actually exists. Same class as the scaffold:must-run
#                        stripper directly above it.
#   2026-08-18 v0.21.0.20260818.1442 — setup.sh SHEDS an inherited scaffold:no-artifact
#                        declaration when it writes a version file. Same class as overlays/
#                        and OVERVIEW.md, and found by the invariant check added one release
#                        earlier: a template cloned from a repo that ships NOTHING inherits
#                        its declaration, setup.sh then writes `version`, and the new project
#                        makes two opposite claims about itself. Nothing noticed while the
#                        check was workflow-only, because it never ran in a fresh project.
#   2026-08-18 v0.20.0.20260818.1156 — --check asserts the version INVARIANT, not just the version
#                        FILE's existence. Printing `[OK] version file` proved a file was
#                        there; it never proved `version` and `.scaffold-version` agreed, and
#                        upstream they drifted fourteen releases apart. Calls
#                        tools/scaffold_version.sh --assert-consistent rather than restating
#                        the rule.
#   2026-08-18 v0.19.0.20260818.0753 — the archive check reports the WORSE state loudly instead of
#                        silently (#227 family). It grepped the report for `[over]`, which
#                        does not match `[BURST]`, so a file past its burst line printed
#                        `[OK] ai/ files under their archive lines` while a file merely over
#                        the archive line was reported -- quieter as the breach got worse.
#                        Now branches on session_archive.py --exit-status: 2 prints [!!] with
#                        the burst wording, 1 prints [!], 0 is the only path to [OK].
#   2026-08-16 v0.18.0.20260816.0100 — THE LOCALCODER AUDIT LOG IS IGNORED BEFORE IT EXISTS
#                        (localcoder#94). It records draft bodies, verify output and MCP tool
#                        ARGUMENTS AND RESULTS verbatim, so it can hold a bearer token passed
#                        to a server and every row a query returned, and it is not redacted by
#                        default — deliberately, for reasons in localcoder's docs/AUDIT.md.
#                        ADDED HERE RATHER THAN LEFT TO A WARNING because the ordering is
#                        unforgiving: the file is created by the first drafting run, and the
#                        window between that run and the next `git add -A` is often one
#                        command. A warning printed inside that window arrives at the same
#                        moment as the risk. Appends only, only when absent, only in a repo,
#                        keeps a backup, and SCAFFOLD_SKIP_GITIGNORE=1 opts out.
#   2026-08-15 v0.17.0.20260815.1100 — A SCANNER THAT DIES ON A SIGNAL IS REPORTED AS A CRASH, NOT A FINDING
#                        (#212). The adopter saw `[FAIL] tools/marker_scan.sh:` followed by
#                        NOTHING — a process killed by a signal has no output to echo. A red
#                        with no finding is worse for a human than a false green: the false
#                        green is quiet, this one sends someone hunting a defect in their own
#                        repository that was never there.
#                        rc > 128 is now named as a signal and stated to be a crash in the
#                        scanner; a non-zero exit with no output at all is named too.
#                        `|| scanner_rc=$?` IS LOAD-BEARING. The first version used a bare
#                        assignment, and under `set -e` a failing command substitution in an
#                        assignment aborts the shell — so the crashing scanner took the whole
#                        of `--check` down with it, exit 139, scanner never named. Strictly
#                        worse than the defect it fixed, and caught by the new fixture on its
#                        first run.
#   2026-08-15 v0.16.0.20260815.0800 — A NEW PROJECT NO LONGER INHERITS THE SOURCE REPO'S must-run
#                        DECLARATION. `<!-- scaffold:must-run tests/audit_localcoder.sh -->`
#                        names somebody else's behavioural suite; a project set up from a clone
#                        inherited it and preflight then refused to go green without a suite
#                        that is not theirs. Same class as .github/CODEOWNERS reading
#                        `* @Robiton`, and found the same way — by the failure finally being
#                        visible. It surfaced the moment preflight stopped printing PASSED over
#                        a failing must-run gate (preflight 0.19.1).
#                        THE RULE IS NOT WEAKENED: a declared gate that cannot run is still a
#                        failure. What was wrong is inheriting the declaration.
#                        GUARDED ON --name, and that guard is load-bearing. An EXISTING adopter
#                        declares its own suite legitimately, and silently retiring that would
#                        be the worst outcome in this file — a gate the repository said it
#                        cannot go green without, gone, with the verdict still green.
#   2026-08-12 v0.15.0 — THE TENTH COPY OF is_upstream_repo, and the worst one. This file
#                        tested `setup.sh` as its third signal — a file EVERY ADOPTER HAS BY
#                        DEFINITION — so all three conjuncts held downstream and the AGENTS.md
#                        placeholder check could not fire in ANY adoption. It printed
#                        "[OK] AGENTS.md (template repo — placeholders expected)" at real
#                        projects with real unfilled commands. Reported from godsfall (#208).
#   2026-08-12 v0.14.0 — A FRESH SETUP NOW SHEDS THE SCAFFOLD'S OWN REPO FILES. A new project
#                        is created by CLONING this repository (QUICK_START step 1), so it
#                        arrives carrying overlays/, OVERVIEW.md and mirror-sync.yml — the
#                        three signals is_upstream_repo() keys on. Until they went, every tool
#                        classified the adopter's project as THE SCAFFOLD, and the two gates
#                        scoped upstream-only on 2026-08-11 *so they could not do this* failed
#                        the adopter's first real commit: writing a dated ai/SESSION.md entry,
#                        which AGENTS.md instructs on every session, failed the
#                        shipped-ai-templates gate, and this repo's 28-line prose ratchet was
#                        enforced on their project. Measured end to end from the published
#                        0.37.1 tarball. .github/CODEOWNERS goes too — it reads `* @Robiton`,
#                        so their pull requests would request review from us.
#   2026-08-12 v0.13.1 — One line adjudicated for tools/stale_path_scan.sh: the sentence
#                        EXPLAINING that tools/localcoder left in W-15 is printed advice
#                        naming a path that is not there, which is exactly what that scanner
#                        looks for and exactly what its exemption exists for. Same trap the
#                        W-15 no-execution gate hit — it fired on this file's echo telling a
#                        developer what to install, a gate forbidding its own remedy.
#   2026-08-12 v0.13.0 — DETECT THE PRE-SPLIT VENDORED localcoder ON PATH. `command -v`
#                        succeeding is not "the product is installed", and ai/STANDARDS.md
#                        says exactly that — *probe by running the binary, not by
#                        `command -v`* — a rule this block broke while shipping the file
#                        that states it. Until W-15 tools/README.md said to
#                        `install -m 0755 tools/localcoder ~/bin/localcoder`; anyone who did
#                        has one on PATH forever, because the upgrader does not delete (A7).
#                        Found on this project's own machine: ~/bin/localcoder at 0.8.0,
#                        header `Project: ai-project-scaffold`, against a product at 0.31.2,
#                        with `uv tool list` showing localcoder not installed at all.
#   2026-08-12 v0.12.2 — The --check summary named `tools/audit_localcoder.sh`, gone in W-15.
#                        A PRINTED string, so every adopter running --check read it. The doc
#                        sweep in 0.36.7 covered the .md files and missed the prose inside
#                        tools/ — prose is prose wherever it lives.
#   2026-08-12 v0.12.1 — `grep -c` PRINTS "0" AND EXITS 1 on no matches, so `|| echo 0` made
#                        `placeholders` the two-line string "0\n0" and every numeric test on
#                        it died with `integer expression expected`. Swept after the identical
#                        line in scaffold-check.yml was found unable to fire AT ALL — that
#                        copy reported "SESSION.md has 0\n0 session entries." on every run of
#                        every adopting repository, which reads as a pass. Six sites, one
#                        idiom; fixing the one that was seen would have left five.
#   2026-08-11 v0.12.0 — --install-hooks / --uninstall-hooks (#171). A repo's hooks do not
#                        ship with its clone: .git/hooks is not versioned, so any rule
#                        enforced by a hook is enforced on whoever happened to install it —
#                        and it LOOKS enforced from the inside, which is the worse half.
#                        OPT-IN AND NEVER PART OF A NORMAL SETUP. A 25-second pre-push hook
#                        installed without asking is the guard ai/SECURITY.md warns about:
#                        it blocks legitimate work, gets ripped out, and then protects
#                        nothing. Undo is one visible command.
#                        REFUSES IF IT WOULD SILENCE HOOKS YOU ALREADY HAVE. core.hooksPath
#                        is EXCLUSIVE — setting it disables .git/hooks entirely, and
#                        git-lfs puts four hooks there that announce nothing. A dropped LFS
#                        pre-push means the push succeeds and the binaries never upload: a
#                        silent data failure traded for a convenience gate. pre-push itself
#                        is chained rather than replaced, so only the others are at risk
#                        and the refusal names them.
#   2026-08-09 v0.10.2 — The summary says what [!] means (#182). An adopter read
#                        '[!] no overlay applied' directly above 'all hard checks passed'
#                        and could not tell which to believe. Both are true; only one is
#                        a gate, and now the line that claims success says so.
#   2026-08-09 v0.10.1 — `--check`'s closing note points at tools/preflight.sh (#166). It
#                        already named the three things it does not cover, which was honest
#                        and left the reader to assemble the rest by hand — and every hand
#                        assembly of that list omitted something different.
#   2026-08-09 v0.10.0 — `--check` records each verdict via tools/scaffold_log.sh, so a
#                        check that stops being run becomes visible. Nothing here could
#                        show that before: a report covers the checks it RUNS, and by
#                        construction that excludes one that no longer runs at all.
#   2026-08-09 v0.9.0 — `--check` runs the vendored checks it had been skipping. It
#                        verified 4 things and printed "all hard checks passed" while CI
#                        ran 13 — header_check.sh, localcoder_sync.py and
#                        session_archive.py are all vendored, offline and fast, and none
#                        was invoked. A human got a narrower answer than the build, and
#                        the narrower one was the reassuring one: the same divergence the
#                        secret scan already cost this file. It now also NAMES what it
#                        does not cover, because "all hard checks passed" was true of the
#                        checks it ran and false as a claim about the scaffold.
#   2026-08-09 v0.8.0 — The SessionStart hook LOOKS for the repo instead of assuming it
#                        is standing in it. `[ -f sync-check.sh ]` resolves against the
#                        session working directory, and on this project's own machine —
#                        where sessions open in the PARENT of three scaffold repos, the
#                        layout its own AGENTS.md prescribes — that guard was false every
#                        time and `|| true` swallowed it. The session-start check had
#                        never run once. Not degraded: never run, and invisible because a
#                        hook whose every failure path is `|| true` cannot report doing
#                        nothing. Now scans the working directory and one level below,
#                        running wherever ai/STANDARDS.md says there is a real adoption.
#   2026-08-08 v0.7.0 — `--check` runs every tools/*_scan.sh instead of carrying its own
#                        copy of the secret regex. The copy it carried was scoped to `ai/`
#                        while tools/secret_scan.sh scans the whole tracked tree, so the
#                        verification a human reads at the end of ./setup.sh was the
#                        narrower of two disagreeing answers — reassuring, and wrong.
#                        Discovery rather than a name also means tools/conflict_scan.sh is
#                        covered without an edit here, which is the point: a listed step is
#                        the next thing to go stale.
#   2026-08-08 v0.6.4 — The "fetch the upgrade tool" hint is gh api, not curl (#136).
#   2026-08-06 v0.6.3 — `--check` can find a dated SESSION.md entry (#96). The pattern
#                        required a bare date while the shipped template prescribes
#                        `## [YYYY-MM-DD]`, so it could never match a correctly-formatted
#                        file: following the template earned a permanent warning, and the
#                        only way to silence it was to stop following the template. The
#                        bracket is now optional. Two things make this worth more than the
#                        one character it took — a warning nobody can action trains people
#                        to skim `[!]` lines in the same output that carries skills drift
#                        and the header baseline, and .github/workflows/scaffold-check.yml
#                        held a second copy of the identical pattern, fixed here too.
#   2026-08-05 v0.6.2 — Anchor the no-artifact marker to column 0: the documented example
#                        in ai/STANDARDS.md would otherwise read as a declaration. Latent,
#                        masked only because the scaffold has a version file and the check
#                        short-circuits before reaching that branch.
#   2026-08-05 v0.6.1 — `--check` honours `<!-- scaffold:no-artifact -->` in ai/STANDARDS.md:
#                        a repo that ships nothing correctly has no version file. Declared,
#                        never inferred — absence alone still fails, because inferring it
#                        would turn a real omission into a silent pass.
#   2026-08-04 v0.6.0 — `--upgrade` delegates to tools/scaffold_upgrade.sh. Upgrading is a
#                        different job from initialising, and the upgrader must re-exec
#                        itself from a temp copy because the upgrade replaces tools/ while
#                        it runs — neither fits inside this script.
#   2026-08-04 v0.5.0 — Stamp correction, not a behaviour change. This header read
#                        0.3.1.20260709.1050 while the file had been modified in four
#                        later commits across two releases — the scaffold that publishes
#                        the header rule was the clearest violation of it, because
#                        nothing checked. tools/header_check.sh now does, and CI runs it.
#                        Substantive changes made under the stale stamp, recorded here so
#                        the history is not lost: the CLAUDE.md un-gitignore upgrade path,
#                        the skills-drift and secret-scan check fixes, .scaffold-version
#                        separation, and the optional local-coder integration notice.
#   2026-07-09 v0.3.1 — TEAM.md seeding matches the new generic placeholder row
#                        (ai/ context files are now clean templates)
#   2026-07-09 v0.3.0 — CLAUDE.md is now a committed '@AGENTS.md' pointer file, not a
#                        gitignored symlink (OneDrive/Windows-safe; loads in session 1)
#   2026-07-09 v0.2.0 — Non-interactive flags (--type/--name/--owner/...), --check
#                        verifier, setup ends with a verification pass, generated
#                        build.sh aligned with the Splunk overlay standard
#   (pre-2026-07-09 history: see git log)

set -e

# Initialize all variables empty before parsing (script runs under set -e)
PROJECT_TYPE=""
PROJECT_NAME=""
SEMVER=""
YOUR_NAME=""
SPLUNK_NEW_OR_EXISTING=""
SPLUNK_APP_TYPE=""
SPLUNK_VERSION_CHOICE=""
SPLUNK_DEPLOY=""
CHECK_ONLY=""
NONINTERACTIVE=""

usage() {
  cat <<EOF
AI Project Scaffold setup — interactive by default; flags enable non-interactive
(AI-driven) setup. Run with no flags to be prompted.

Usage: ./setup.sh [flags]
       ./setup.sh --check        # verify an existing setup, change nothing
       ./setup.sh --upgrade      # move an existing project to a newer scaffold release

Flags:
  --type <t>            Project type: base, ai-skill, splunk-app, security-tool,
                        python-script, it-automation, api-integration
                        (providing --type switches to non-interactive mode)
  --name <n>            Project name
  --owner <o>           Your name (for SESSION.md and TEAM.md)
  --version <v>         Initial MAJOR.MINOR.PATCH (default: 0.1.0)
  --splunk-new          Splunk app: new app (scaffold directory structure)
  --splunk-existing     Splunk app: existing app (standards only)
  --splunk-app-type <t> ucc | conf | tbd            (default: tbd)
  --splunk-version <v>  9.0 | 9.3 | 10              (default: 9.3)
  --splunk-deploy <d>   onprem | cloud | both       (default: both)
  --check               Run setup verification only and exit (0 = correct)
  --install-hooks       Opt in to .githooks (pre-push runs tools/preflight.sh).
                        Refuses if it would silence hooks you already have.
  --uninstall-hooks     Undo the above (git config --unset core.hooksPath)
  -h, --help            Show this help

Examples:
  ./setup.sh --type base --name my-project --owner "Jane Doe"
  ./setup.sh --type splunk-app --name TA-vendor-product --owner "Jane Doe" \\
             --splunk-new --splunk-app-type conf --splunk-version 9.3 --splunk-deploy onprem
EOF
}

# Helper: a value-taking flag must actually have a value
need_value() {
  if [ -z "${2:-}" ] || [ "${2#--}" != "$2" ]; then
    echo "Error: $1 requires a value" >&2
    exit 2
  fi
}

# Parse command-line arguments
while [ $# -gt 0 ]; do
  case "$1" in
    --type)
      need_value "$1" "${2:-}"
      NONINTERACTIVE=1
      case "$2" in
        base) PROJECT_TYPE=1 ;;
        ai-skill) PROJECT_TYPE=2 ;;
        splunk-app) PROJECT_TYPE=3 ;;
        security-tool) PROJECT_TYPE=4 ;;
        python-script) PROJECT_TYPE=5 ;;
        it-automation) PROJECT_TYPE=6 ;;
        api-integration) PROJECT_TYPE=7 ;;
        *) echo "Error: invalid --type '$2'. Valid: base, ai-skill, splunk-app, security-tool, python-script, it-automation, api-integration" >&2; exit 2 ;;
      esac
      shift 2 ;;
    --name) need_value "$1" "${2:-}"; PROJECT_NAME="$2"; shift 2 ;;
    --version) need_value "$1" "${2:-}"; SEMVER="$2"; shift 2 ;;
    --owner) need_value "$1" "${2:-}"; YOUR_NAME="$2"; shift 2 ;;
    --splunk-new) SPLUNK_NEW_OR_EXISTING=1; shift ;;
    --splunk-existing) SPLUNK_NEW_OR_EXISTING=2; shift ;;
    --splunk-app-type)
      need_value "$1" "${2:-}"
      case "$2" in
        ucc) SPLUNK_APP_TYPE=1 ;;
        conf) SPLUNK_APP_TYPE=2 ;;
        tbd) SPLUNK_APP_TYPE=3 ;;
        *) echo "Error: invalid --splunk-app-type '$2'. Valid: ucc, conf, tbd" >&2; exit 2 ;;
      esac
      shift 2 ;;
    --splunk-version)
      need_value "$1" "${2:-}"
      case "$2" in
        9.0) SPLUNK_VERSION_CHOICE=1 ;;
        9.3) SPLUNK_VERSION_CHOICE=2 ;;
        10) SPLUNK_VERSION_CHOICE=3 ;;
        *) echo "Error: invalid --splunk-version '$2'. Valid: 9.0, 9.3, 10" >&2; exit 2 ;;
      esac
      shift 2 ;;
    --splunk-deploy)
      need_value "$1" "${2:-}"
      case "$2" in
        onprem) SPLUNK_DEPLOY=1 ;;
        cloud) SPLUNK_DEPLOY=2 ;;
        both) SPLUNK_DEPLOY=3 ;;
        *) echo "Error: invalid --splunk-deploy '$2'. Valid: onprem, cloud, both" >&2; exit 2 ;;
      esac
      shift 2 ;;
    --check) CHECK_ONLY=1; shift ;;
    # ---------------------------------------------------------------- git hooks (#171)
    # OPT-IN, AND REVERSIBLE IN ONE VISIBLE COMMAND. A 25-second pre-push hook installed
    # without asking is the definition of a guard that blocks legitimate work, and
    # ai/SECURITY.md's rule is that those get ripped out at the first inconvenience and
    # then protect nothing. So: never during a normal setup, only when asked for by name.
    --install-hooks|--uninstall-hooks)
      _hook_action="$1"; shift
      if ! git rev-parse --git-dir >/dev/null 2>&1; then
        echo "setup.sh: not a git repository, so there are no hooks to configure." >&2
        exit 1
      fi
      if [ "$_hook_action" = "--uninstall-hooks" ]; then
        if [ "$(git config --get core.hooksPath 2>/dev/null || true)" = ".githooks" ]; then
          git config --unset core.hooksPath
          echo "Hooks uninstalled. .git/hooks is live again."
        else
          echo "core.hooksPath is not set to .githooks; nothing to undo."
          echo "  current: $(git config --get core.hooksPath 2>/dev/null || echo '(unset)')"
        fi
        exit 0
      fi
      if [ ! -x .githooks/pre-push ]; then
        echo "setup.sh: .githooks/pre-push is missing or not executable." >&2
        exit 1
      fi
      # core.hooksPath IS EXCLUSIVE. Setting it does not merge with .git/hooks — it
      # REPLACES it, and everything already installed there stops running. git-lfs puts
      # four hooks there and none of them announce themselves; a dropped LFS pre-push means
      # the push succeeds and the binaries never upload. That is a silent data failure, and
      # trading it for a convenience gate would be a strictly worse deal than the problem.
      # pre-push is chained by .githooks/pre-push, so only the OTHERS are at risk.
      #
      # AND IT MUST ASK WHETHER .githooks/ ALREADY COVERS THEM (#274). The scan below used
      # to list every executable non-sample hook and bail unconditionally, while the printed
      # remedy said "copy the ones you want into .githooks/ first, then re-run this" -- so
      # following the instruction exactly landed you back on the same refusal. Reported from
      # Robiton/godsfall after doing precisely that; core.hooksPath had to be set by hand.
      #
      # COVERED IS NOT THE SAME AS PRESENT. A .githooks/<name> that does NOT chain to
      # .git/hooks/<name> silences the original just as completely as no file at all, and it
      # does it while looking like the fix. So a covering hook must reach the real hooks
      # directory through `git rev-parse --git-dir` -- never `--git-path hooks/<name>`,
      # which honours core.hooksPath and, once installed, resolves to the covering hook
      # itself. Anything else is reported as UNCHAINED and still refuses.
      #
      # COMMENTS ARE STRIPPED BEFORE THE MATCH. The paragraph in each shipped hook that
      # EXPLAINS the chain contains the same words as the chain, and matching against it
      # would pass a hook whose only chaining is a description of chaining.
      _gd="$(git rev-parse --git-dir)"
      _orphans=""
      _unchained=""
      if [ -d "$_gd/hooks" ]; then
        for _h in "$_gd/hooks"/*; do
          [ -f "$_h" ] && [ -x "$_h" ] || continue
          case "$_h" in *.sample) continue ;; esac
          _hn="$(basename "$_h")"
          case "$_hn" in pre-push) continue ;; esac
          if [ -x ".githooks/$_hn" ]; then
            if sed 's/#.*//' ".githooks/$_hn" | grep -q -- "--git-dir" \
               && sed 's/#.*//' ".githooks/$_hn" | grep -q "hooks/$_hn"; then
              continue
            fi
            _unchained="$_unchained $_hn"
            continue
          fi
          _orphans="$_orphans $_hn"
        done
        unset _hn
      fi
      if [ -n "$_unchained" ]; then
        echo "REFUSING — .githooks/ covers these, but does not CHAIN to the originals:" >&2
        echo "   $_unchained" >&2
        echo >&2
        echo "  A .githooks/<name> that does not exec .git/hooks/<name> silences the hook" >&2
        echo "  already installed there just as completely as having no file at all — and" >&2
        echo "  it does it while looking like the fix. The scaffold ships chaining" >&2
        echo "  post-checkout, post-commit and post-merge; copy their shape." >&2
        exit 1
      fi
      if [ -n "$_orphans" ]; then
        echo "REFUSING — core.hooksPath would silence hooks you already have." >&2
        echo >&2
        echo "  Installed in $_gd/hooks and NOT sample files:$_orphans" >&2
        echo >&2
        echo "  Setting core.hooksPath disables that directory entirely. If any of those" >&2
        echo "  are git-lfs's, your binaries stop uploading and NOTHING reports it." >&2
        echo "  (Your pre-push, if any, would be fine — .githooks/pre-push chains it.)" >&2
        echo >&2
        echo "  Copy the ones you want into .githooks/ first — CHAINING to the original," >&2
        echo "  the way the shipped .githooks/post-checkout does — then re-run this. A" >&2
        echo "  covering hook that chains is skipped here; one that does not is refused" >&2
        echo "  by name, so following this remedy now terminates. Or skip" >&2
        echo "  the hook and keep running tools/preflight.sh by hand — CI is the backstop" >&2
        echo "  either way, and this only moves the same gate earlier." >&2
        exit 1
      fi
      git config core.hooksPath .githooks
      echo "Hooks installed: core.hooksPath -> .githooks"
      echo "  pre-push runs tools/preflight.sh — every gate CI runs, reported at once."
      echo "  Emergency escape:  git push --no-verify"
      echo "  Turn it off:       ./setup.sh --uninstall-hooks"
      exit 0 ;;
    # Upgrading is a DIFFERENT JOB from initialising, and it is delegated rather than
    # inlined: this script is already ~950 lines, and the upgrade has to reason about
    # three-way merges, migrations and file ownership. Keeping it separate means setup.sh
    # stays "initialise and verify" — and means the upgrader can re-exec itself from a temp
    # copy, which it must, because the upgrade replaces tools/ while it is running.
    --upgrade)
      shift
      if [ ! -x tools/scaffold_upgrade.sh ]; then
        echo "setup.sh: tools/scaffold_upgrade.sh not found." >&2
        echo "  This project predates the upgrade command. Fetch it first:" >&2
        # gh, not curl: the upstream repo is PRIVATE so raw.githubusercontent.com 404s,
        # and `curl -sS -o` writes that 404 body into the target rather than failing (#136).
        # SINGLE-quoted (#309). Double-quoted, the inner quotes are eaten by the shell and
        # the URL prints bare -- and `?` then globs, so the hint dies with "no matches found"
        # under zsh, the default shell on every Mac here. The one instruction we hand somebody
        # too old to self-upgrade has to survive being copied.
        echo '    gh api "repos/Robiton/ai-project-scaffold/contents/tools/scaffold_upgrade.sh?ref=main" \' >&2
        echo "      --jq .content | base64 -d > tools/scaffold_upgrade.sh" >&2
        echo "    chmod +x tools/scaffold_upgrade.sh" >&2
        exit 1
      fi
      exec tools/scaffold_upgrade.sh "$@" ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown flag: $1" >&2; usage >&2; exit 2 ;;
  esac
done

# Non-interactive validation and defaults
if [ "$NONINTERACTIVE" = "1" ]; then
  MISSING_FLAGS=""
  [ -z "$PROJECT_NAME" ] && MISSING_FLAGS="$MISSING_FLAGS --name"
  [ -z "$YOUR_NAME" ] && MISSING_FLAGS="$MISSING_FLAGS --owner"
  if [ -n "$MISSING_FLAGS" ]; then
    echo "Error: non-interactive mode (--type) also requires:$MISSING_FLAGS" >&2
    exit 2
  fi
  SEMVER=${SEMVER:-0.1.0}
  if [ "$PROJECT_TYPE" = "3" ]; then
    if [ -z "$SPLUNK_NEW_OR_EXISTING" ]; then
      echo "Error: --type splunk-app requires --splunk-new or --splunk-existing" >&2
      exit 2
    fi
    SPLUNK_APP_TYPE=${SPLUNK_APP_TYPE:-3}
    SPLUNK_VERSION_CHOICE=${SPLUNK_VERSION_CHOICE:-2}
    SPLUNK_DEPLOY=${SPLUNK_DEPLOY:-3}
  fi
fi

# Verify a scaffold setup — used by --check and run automatically after setup.
# [OK] pass, [FAIL] hard failure (affects exit code), [!] advisory.
# ---- IS THIS PROJECT THE REPOSITORY, OR A DIRECTORY INSIDE ONE? (#296)
#
# The scaffold assumes the project it adopts into IS a repository root, and that assumption
# is load-bearing in three places that all fail SILENTLY when it does not hold:
#
#   - GitHub discovers workflows, CODEOWNERS and the PR template only at the REPOSITORY
#     root. In a subdirectory they are inert. `.github/workflows/scaffold-check.yml` is 332
#     lines that will never run, and it reads to any reviewer as though CI is enforcing the
#     standards. That is worse than having no workflow at all.
#   - `.claude/settings.json` walks `. */` — ONE level, deliberately (see the comment at the
#     hook installer). A project two levels down is invisible from the repository root, so
#     no hook ever fires for it.
#   - The adoption checklist says "AGENTS.md exists in repo root", which passes in the
#     project directory and quietly means something else there.
#
# Measured on a real adoption at `apps/<app>/` in a monorepo: all three were inert, nobody
# was told, and an outside reviewer found it. Before this, the string `monorepo` appeared in
# this repository exactly once — in a comment explaining why we stop at one level. We had
# identified the case, chosen the cheap thing, and told nobody.
#
# A NOTICE, NOT A REFUSAL. Adopting into a monorepo subdirectory is legitimate and common;
# it just needs different wiring, and the adopter has to know that before a reviewer tells
# them. `docs/ADOPTION_GUIDE.md` -> "Adopting inside a monorepo" says what to do.
monorepo_notice() {
  _mr_top="$(git rev-parse --show-toplevel 2>/dev/null || true)"
  [ -n "$_mr_top" ] || return 0
  # Compare resolved paths: OneDrive and /tmp both hand out symlinked parents on macOS, and
  # an unresolved compare reports every adoption as a monorepo.
  _mr_top="$(cd "$_mr_top" 2>/dev/null && pwd -P || printf '%s' "$_mr_top")"
  _mr_here="$(pwd -P)"
  [ "$_mr_top" != "$_mr_here" ] || return 0
  # SAME DIRECTORY, DIFFERENT SPELLING (Clocktower #6). On a case-insensitive volume
  # `cd ~/code/myrepo` into MyRepo leaves pwd -P with the typed case while git reports the
  # on-disk one, and the string compare above called the repository root a subdirectory.
  # -ef compares device and inode, which no spelling can disagree about.
  [ ! "$_mr_top" -ef "$_mr_here" ] || return 0
  _mr_rel="${_mr_here#"$_mr_top"/}"
  echo "[!]    this project is a SUBDIRECTORY of a git repository, not its root"
  echo "         repository root : $_mr_top"
  echo "         this project    : $_mr_rel"
  echo "       Three things do not work from here, and none of them says so on its own:"
  echo "         - .github/workflows/, CODEOWNERS and the PR template are INERT."
  echo "           GitHub reads them only at the repository root."
  echo "         - Claude Code hooks scan one level down; this is deeper, so none fire."
  echo "         - 'AGENTS.md in repo root' in the checklist means the ROOT, not here."
  echo "       Fix: docs/ADOPTION_GUIDE.md -> 'Adopting inside a monorepo'."
  unset _mr_top _mr_here _mr_rel 2>/dev/null || true
  return 0
}

# ---- A STUB IS A STARTING POINT, NOT A RESET (#299).
#
# Every overlay writes template documents for the project it is applying to. They were all
# `cat > <path>`, unconditional, so RE-RUNNING setup.sh — or applying an overlay to an
# existing project, which is a documented mode — replaced whatever was there.
#
# Measured across all seven overlays with a fixture holding real content: the security-tool
# overlay destroyed a filled-in `docs/THREAT_MODEL.md`, which in a security project is the
# single document most expensive to lose. The Splunk document and .conf stubs sat behind a
# "new app" answer and so were one wrong prompt away from the same thing.
#
# Same fix as gitignore_ensure_lines(), same reason: an adopter's file is the adopter's.
# The heredoc is still consumed when the file exists, because the caller's redirect has to
# be balanced whether we write it or not.
create_if_absent() {   # create_if_absent <path> <what it is>   ; body on stdin
  if [ -e "$1" ]; then
    cat > /dev/null
    echo "[OK] $1 exists — left alone (would have written a $2)"
    return 0
  fi
  _cia_dir="$(dirname "$1")"
  [ "$_cia_dir" = "." ] || mkdir -p "$_cia_dir"
  cat > "$1"
  echo "[OK] $1 created — $2"
  unset _cia_dir 2>/dev/null || true
}

# ---- .gitignore IS APPENDED TO, NEVER REPLACED (#292).
#
# The splunk-app overlay used to do `cat > .gitignore`, unconditionally, for existing apps
# as well as new ones. Following docs/ADOPTION_GUIDE.md in its own order — step 4 appends
# the scaffold secret rules, step 6 applies the overlay — destroyed every rule step 4 had
# just added, plus whatever the project already had, with no backup and no message. It also
# erased `.localcoder-audit.jsonl*`, which this same script appends 400 lines above under a
# comment reading "the ordering is unforgiving". Reproduced end to end before the fix.
#
# .gitignore is a SET OF LINES, not prose. scaffold_upgrade.sh already reasons this way and
# treats it as a UNION file; the overlay never got the memo. Exact-line, order-independent,
# append-only is the same rule in both places.
gitignore_ensure_lines() {
  _gi_head="$1"; shift
  [ -f .gitignore ] || : > .gitignore
  _gi_add=""
  for _gi_l in "$@"; do
    # -x -F: whole line, literal. Entries start with ! and * and must not be read as regex.
    if ! grep -qxF -- "$_gi_l" .gitignore 2>/dev/null; then
      _gi_add="$_gi_add$_gi_l
"
    fi
  done
  if [ -n "$_gi_add" ]; then
    { printf '\n%s\n' "$_gi_head"; printf '%s' "$_gi_add"; } >> .gitignore
    _gi_n="$(printf '%s' "$_gi_add" | grep -c '' || true)"
    echo "[OK] .gitignore — added ${_gi_n} entry(ies); nothing already there was touched"
  else
    echo "[OK] .gitignore — every entry already present, left unchanged"
  fi
  unset _gi_head _gi_l _gi_add _gi_n 2>/dev/null || true
  return 0
}
run_checks() {
  local fail_count=0

  # Required ai/ files
  #
  # THE TAG NAMES WHAT IT CHECKED (#265). This printed a bare `[OK]   ai/MEMORY.md`, and a
  # few lines later the archive block printed `[!] [over] ai/MEMORY.md: 873 lines`. Two
  # verdicts for one file in one run, the reassuring one first and unqualified -- so anyone
  # scanning the tag column, which is the whole point of a tag column, took the [OK].
  # This loop only ever asked whether the file EXISTS. Now it says so.
  for f in ai/STANDARDS.md ai/CODING.md ai/SECURITY.md ai/PLANNING.md ai/BACKLOG.md ai/SESSION.md ai/MEMORY.md ai/TEAM.md; do
    if [ -f "$f" ]; then
      echo "[OK]   $f present"
    else
      echo "[FAIL] $f missing — restore from the scaffold repo"
      (( fail_count++ )) || true
    fi
  done

  # AGENTS.md hook — and whether its Project Commands table was actually filled in.
  # An unfilled table is worse than none: it looks authoritative and tells the agent
  # nothing. Advisory, not a hard failure — a brand-new project legitimately has not
  # filled it in yet, and failing setup on that would be noise.
  if [ -f AGENTS.md ]; then
    local placeholders
    # `grep -c` prints "0" AND exits 1 on no matches, so `|| echo 0` made this "0\n0"
    # and every numeric test on it died with `integer expression expected`. Swept
    # 2026-08-11 after the copy in scaffold-check.yml was found unable to fire at all.
    placeholders=$(grep -c '\[fill in' AGENTS.md 2>/dev/null || true)
    case "$placeholders" in ''|*[!0-9]*) placeholders=0 ;; esac
    # The scaffold template repo itself legitimately ships these placeholders — it IS
    # the template. Warning about them on every run of its own CI is permanent noise,
    # and a warning that always fires is one people learn to filter out.
    #
    # THE THIRD SIGNAL IS mirror-sync.yml, AND THIS WAS THE TENTH COPY OF THE PREDICATE —
    # the only one still testing `setup.sh`, which EVERY ADOPTER HAS BY DEFINITION. So all
    # three conjuncts held downstream and this check could not fire in any adoption: it
    # printed `[OK] AGENTS.md (template repo — placeholders expected)` at a real project
    # with a real unfilled command. A check that cannot fail, reporting reassuringly.
    #
    # 0.36.6 fixed the same drift in scaffold-check.yml and added a --selftest pin for it —
    # A PIN THAT LOOKED ONLY AT THE WORKFLOW, so it never saw this one. Worse, the comment
    # I wrote justifying that fix said the drifted copy "happened not to misfire because no
    # adopter carries overlays/ either". THAT IS FALSE. A project created the documented
    # way — clone the scaffold, run setup.sh — carries overlays/ and OVERVIEW.md until
    # 0.38.0 sheds them, and every adoption before that keeps them forever. Reported from
    # the godsfall adoption (#208), which is the second time a comment of mine asserting
    # "this could not have misfired" has been wrong about a copy nobody was checking.
    if [ -d overlays ] && [ -f OVERVIEW.md ] && [ -f .github/workflows/mirror-sync.yml ]; then
      echo "[OK]   AGENTS.md (template repo — placeholders expected)"
    elif [ "${placeholders:-0}" -gt 0 ]; then
      echo "[!]    AGENTS.md has $placeholders '[fill in]' placeholder(s) — agents read the"
      echo "       Project Commands table first; fill it in or delete rows that don't apply"
    else
      echo "[OK]   AGENTS.md (Project Commands filled in)"
    fi
  else
    echo "[FAIL] AGENTS.md missing — restore from the scaffold repo"
    (( fail_count++ )) || true
  fi

  # ==== THE <=v0.3.0 SYMLINK INSTRUCTION, REACHED WITHOUT AN UPGRADE (#303) ===============
  #
  # scaffold_upgrade.sh migrates this, which closes it for anyone who UPGRADES and for
  # nobody else. The instruction lives in AGENTS.md, a MERGE file, in a repository we do not
  # own -- so an adoption that never upgrades keeps a paragraph telling the reader to run
  # `ln -s AGENTS.md CLAUDE.md`, and the next `printf '@AGENTS.md' > CLAUDE.md` from anywhere
  # follows the link and TRUNCATES AGENTS.md to eleven bytes. Measured: 86 -> 11.
  #
  # --check is the reach we DO have: an adopter runs it far more often than they upgrade.
  # Same detection as the migration, deliberately -- one pattern, two callers, so they cannot
  # drift apart and disagree about what the hazard looks like.
  #
  # A FAILURE, NOT AN ADVISORY. Everything else --check reports is hygiene; this one destroys
  # the file that carries every rule, and it destroys it the moment somebody follows their own
  # documentation. It also names the fix inline, because an adopter who never upgrades is by
  # definition not going to be told by an upgrade.
  if [ -f AGENTS.md ] && grep -qE '^[[:space:]]*ln -s AGENTS\.md CLAUDE\.md[[:space:]]*$' AGENTS.md; then
    echo "[FAIL] AGENTS.md still tells the reader to run: ln -s AGENTS.md CLAUDE.md"
    echo "       That is scaffold <=v0.3.0 guidance and it DESTROYS THIS FILE. CLAUDE.md is a"
    echo "       committed one-line pointer now; if it is a symlink, the next"
    echo "       'printf @AGENTS.md > CLAUDE.md' follows it and truncates AGENTS.md to 11 bytes."
    echo "       Fix, keeping a backup:"
    echo "         cp AGENTS.md AGENTS.md.scaffold-backup"
    echo "         # delete the 'ln -s AGENTS.md CLAUDE.md' line and the sentence above it"
    echo "         [ -L CLAUDE.md ] && rm CLAUDE.md; printf '@AGENTS.md\\n' > CLAUDE.md"
    echo "       tools/scaffold_upgrade.sh does this for you if you are upgrading anyway."
    (( fail_count++ )) || true
  fi

  # AND THE ARTEFACT, which can exist without the instruction -- somebody may have run the
  # command once and later deleted the paragraph. Cheap, and it is the state that actually
  # bites rather than the sentence that causes it.
  if [ -L CLAUDE.md ]; then
    echo "[FAIL] CLAUDE.md is a SYMLINK. It must be a committed one-line pointer:"
    echo "         rm CLAUDE.md && printf '@AGENTS.md\\n' > CLAUDE.md && git add CLAUDE.md"
    echo "       While it is a link, any write to CLAUDE.md writes through to AGENTS.md."
    (( fail_count++ )) || true
  fi

  # version file
  if [ -s version ]; then
    echo "[OK]   version file ($(cat version))"
  elif grep -qE '^<!--[[:space:]]*scaffold:no-artifact[[:space:]]*-->[[:space:]]*$' ai/STANDARDS.md 2>/dev/null; then
    # DECLARED, not inferred. A missing `version` is correct for a context/docs/research
    # repo that builds nothing — but only if someone said so. Inferring it from absence
    # would turn a real omission into a silent pass, which is the failure mode this whole
    # file argues against. See ai/STANDARDS.md -> Versioning standard.
    echo "[OK]   no version file — ai/STANDARDS.md declares scaffold:no-artifact"
  else
    echo "[FAIL] version file missing or empty — run ./setup.sh"
    echo "       (a repo that ships nothing declares scaffold:no-artifact in ai/STANDARDS.md)"
    (( fail_count++ )) || true
  fi

  # AND THE INVARIANT BETWEEN `version` AND `.scaffold-version`, from the ONE place that
  # defines it (P0-2). The block above proves a version file EXISTS; it never proved the two
  # markers agreed, and in the upstream repo — where they are the same release — they drifted
  # fourteen releases apart because the only assertion lived in scaffold-check.yml and died
  # with Actions on 2026-08-13. Calling the canonical command rather than restating the rule:
  # two copies of one rule is the defect this repo keeps finding in itself.
  if [ -x tools/scaffold_version.sh ]; then
    if ! tools/scaffold_version.sh --assert-consistent --quiet >/dev/null 2>&1; then
      tools/scaffold_version.sh --assert-consistent 2>&1 | sed 's/^/       /'
      (( fail_count++ )) || true
    else
      echo "[OK]   version markers agree (tools/scaffold_version.sh --assert-consistent)"
    fi
  fi

  # CLAUDE.md — committed '@AGENTS.md' pointer (legacy symlink also accepted)
  if [ -L CLAUDE.md ] || { [ -f CLAUDE.md ] && grep -q '^@AGENTS.md' CLAUDE.md 2>/dev/null; }; then
    echo "[OK]   CLAUDE.md (imports AGENTS.md)"
  elif [ -f CLAUDE.md ]; then
    echo "[!]    CLAUDE.md present but has no '@AGENTS.md' line — Claude Code may not load AGENTS.md"
  else
    # THE REMEDIATION STRING WAS THE FOURTH SITE OF A DATA-LOSS BUG (#305).
    #
    # `printf ... > CLAUDE.md` FOLLOWS a symlink, and scaffold <=v0.3.0 told adopters to
    # `ln -s AGENTS.md CLAUDE.md`. Handing that command to exactly the population that still
    # has the legacy symlink truncates their AGENTS.md to eleven bytes. Three sites in the
    # adoption guide were guarded; this one is emitted by the tool itself and was missed.
    #
    # AND THE POPULATION IS THE SAME ONE, which is what makes it sharp: this branch is
    # reached when CLAUDE.md is absent from the tracked tree, and the commonest cause is a
    # legacy `.gitignore` line ignoring it — both come from the same <=v0.3.0 adoption.
    if [ -L CLAUDE.md ]; then
      echo "[FAIL] CLAUDE.md is a LEGACY SYMLINK — do not redirect into it, that truncates AGENTS.md"
      echo "       fix: rm CLAUDE.md && printf '@AGENTS.md\n' > CLAUDE.md"
    elif grep -qE '^[[:space:]]*/?CLAUDE\.md[[:space:]]*$' .gitignore 2>/dev/null; then
      echo "[FAIL] CLAUDE.md is gitignored, so it never reaches a fresh clone — a <=v0.3.0 leftover"
      echo "       fix: remove the CLAUDE.md line from .gitignore, then ./setup.sh"
    else
      echo "[FAIL] CLAUDE.md missing — fix: [ -L CLAUDE.md ] && rm CLAUDE.md; printf '@AGENTS.md\n' > CLAUDE.md"
    fi
    (( fail_count++ )) || true
  fi

  # Skills mirror — tools/skills_check.sh owns the comparison (one definition; it
  # ignores intentional localcoder blocks and names the right fix direction).
  if [ -d .agents/skills ]; then
    if [ -x tools/skills_check.sh ]; then
      if tools/skills_check.sh --quiet; then
        echo "[OK]   skills mirror (.agents/skills == .claude/skills)"
      else
        echo "[FAIL] skills mirror drifted — run: tools/skills_check.sh"
        (( fail_count++ )) || true
      fi
    elif diff -rq .agents/skills .claude/skills >/dev/null 2>&1; then
      echo "[OK]   skills mirror (.agents/skills == .claude/skills)"
    else
      echo "[FAIL] skills mirror drifted — fix: cp -R .agents/skills/. .claude/skills/"
      (( fail_count++ )) || true
    fi
  fi

  # TREE SCANNERS — DISCOVERED, NOT LISTED, AND NOT REIMPLEMENTED HERE.
  #
  # This block used to carry its OWN copy of the secret-scan regex, and that copy was
  # scoped to `ai/` while tools/secret_scan.sh scans the whole tracked tree. So the two
  # answers to "are there secrets in this repo?" disagreed by construction, and the one a
  # human saw at the end of ./setup.sh was the narrower of the two — "a check aimed away
  # from the risk reads as coverage" (ai/MEMORY.md), with the added twist that the reading
  # was reassuring. Two copies of one rule is also how #96 reached one file and not the
  # other, twice.
  #
  # So there is now exactly one definition of each scan, in tools/, and this delegates.
  # New scanners are picked up with no edit here — the same discovery the CI workflow and
  # the selftest loop already use.
  #
  # AN ABSENT TOOL IS REPORTED AS "DID NOT RUN", NOT QUIETLY REPLACED BY A SMALLER CHECK.
  # Substituting a narrower inline scan is what created the divergence above. It stays
  # advisory rather than a hard failure: `./setup.sh` force-installs tools/, so absence
  # means someone deleted it deliberately, and failing their verification run over it
  # would be a guard that blocks legitimate work.
  local scanner scanner_found=0 scanner_out scanner_rc
  for scanner in tools/*_scan.sh; do
    [ -x "$scanner" ] || continue
    scanner_found=$((scanner_found + 1))
    # ECHO THE TOOL'S OWN VERDICT LINE RATHER THAN ASSERTING ONE HERE. Both scanners say
    # "did NOT run" when they cannot (outside a git repo) while still exiting 0, and a
    # bare "[OK] tools/secret_scan.sh" printed over that would be this file inventing a
    # pass the tool never claimed.
    # `|| scanner_rc=$?` IS NOT STYLE, IT IS WHAT KEEPS `set -e` FROM KILLING THIS SCRIPT.
    # The first version of this fix used a bare assignment followed by `$?`. Under `set -e` a
    # failing command substitution in an assignment aborts the shell, so the crashing scanner
    # took `setup.sh --check` down with it — exit 139 for the whole run, and the scanner never
    # named. That is strictly worse than the empty [FAIL] it was meant to fix, and the fixture
    # below caught it on the first run.
    scanner_rc=0
    scanner_out="$("$scanner" 2>&1)" || scanner_rc=$?
    if [ "$scanner_rc" -eq 0 ]; then
      echo "[OK]   $scanner — $(printf '%s\n' "$scanner_out" | tail -1)"
      [ -x tools/scaffold_log.sh ] && tools/scaffold_log.sh --log "$(basename "$scanner")" ok "" || true
    elif [ "$scanner_rc" -eq 3 ]; then
      # EXIT 3 IS "COULD NOT VERIFY", NOT A FINDING (Clocktower #2). Printing it [FAIL] told
      # an adopter their repository had a problem when the scanner had merely been unable to
      # look -- the same collapse of two facts the signal branch below exists to prevent.
      # Not a pass either: it is named, logged as a gap, and never counted as [OK].
      echo "[!]    $scanner COULD NOT VERIFY (exit 3) — nothing was checked, nothing was found:"
      [ -n "$scanner_out" ] && printf '%s\n' "$scanner_out" | sed 's/^/       /' | tail -4
      [ -x tools/scaffold_log.sh ] && tools/scaffold_log.sh --log "$(basename "$scanner")" gap "exit 3" || true
    elif [ "$scanner_rc" -gt 128 ]; then
      # DIED ON A SIGNAL IS NOT THE SAME FACT AS FOUND A PROBLEM, and printing them the same
      # way is how an operator gets a red gate with nothing to act on.
      #
      # Reported as #212: tools/marker_scan.sh segfaulted (rc=139 = 128+11) on an adopter's
      # repository and this printed `[FAIL] tools/marker_scan.sh:` followed by NOTHING, because
      # a process killed by a signal produces no output to echo. A red with no finding is worse
      # for a human than a false green — the false green is at least quiet, while this sends
      # someone looking for a defect in their own repo that was never there.
      #
      # This project's whole exit vocabulary exists to keep these apart, and the one place a
      # crash could surface was the one place that collapsed them.
      echo "[FAIL] $scanner DIED ON SIGNAL $((scanner_rc - 128)) (exit $scanner_rc)"
      echo "       It produced ${#scanner_out} byte(s) of output, so it did NOT report a"
      echo "       finding — this is a CRASH IN THE SCANNER, not a problem in your repository."
      echo "       Nothing here has been verified. Please report it with the repo's size:"
      echo "         git ls-files | wc -l"
      [ -n "$scanner_out" ] && printf '%s\n' "$scanner_out" | sed 's/^/       /' | head -6
      [ -x tools/scaffold_log.sh ] && tools/scaffold_log.sh --log "$(basename "$scanner")" FAIL "signal $((scanner_rc - 128))" || true
      (( fail_count++ )) || true
    else
      echo "[FAIL] $scanner:"
      if [ -z "$scanner_out" ]; then
        # A NON-ZERO EXIT WITH NO OUTPUT IS ALSO NOT A FINDING. Same argument one tier down:
        # the scanner is broken or was interrupted, and saying so beats an empty red.
        echo "       exit $scanner_rc and NO OUTPUT. A gate that fails without saying why has"
        echo "       not told you anything — treat this as a broken scanner, not a finding."
      else
        printf '%s\n' "$scanner_out" | sed 's/^/       /' | head -12
      fi
      [ -x tools/scaffold_log.sh ] && tools/scaffold_log.sh --log "$(basename "$scanner")" FAIL "findings" || true
      (( fail_count++ )) || true
    fi
  done
  if [ "$scanner_found" -eq 0 ]; then
    echo "[!]    no tools/*_scan.sh found — the secret and conflict scans DID NOT RUN"
    echo "       (restore tools/ from the scaffold; a skip is not a pass)"
  fi

  # Advisories
  #
  # CHECK THE HOOKS, NOT THE FILE. This reported [OK] on a settings.json containing `{}`,
  # which is precisely the state setup.sh used to leave an adopter in -- file present,
  # zero hooks, correction capture and the session journal silently absent (#246). A check
  # that confirms a file exists cannot see the failure the file was supposed to prevent.
  if [ ! -f .claude/settings.json ]; then
    echo "[!]    .claude/settings.json missing — run ./setup.sh to install the hooks"
  elif [ -f .claude/settings.hooks.json ] && command -v python3 >/dev/null 2>&1; then
    _hook_delta="$(python3 - <<'PYCHK' 2>/dev/null
import json, io
def cmds(p):
    try: h = json.load(io.open(p, encoding="utf-8")).get("hooks", {}) or {}
    except Exception: return None
    return {c.get("command") for v in h.values() for g in v for c in g.get("hooks", [])}
want = cmds(".claude/settings.hooks.json")
have = cmds(".claude/settings.json")
if want is None: print("CANON_UNREADABLE")
elif have is None: print("MALFORMED")
else: print("MISSING %d/%d" % (len(want - have), len(want)) if want - have else "OK")
PYCHK
)"
    case "$_hook_delta" in
      OK)       echo "[OK]   .claude/settings.json — every scaffold hook is wired" ;;
      MALFORMED) echo "[!]    .claude/settings.json is not valid JSON — hooks cannot be verified" ;;
      MISSING*) echo "[!]    .claude/settings.json is missing hooks (${_hook_delta#MISSING }) — re-run ./setup.sh"
                echo "       Without them the session journal and correction capture do not run." ;;
      *)        echo "[OK]   .claude/settings.json (hook comparison unavailable)" ;;
    esac
    unset _hook_delta
    # ---- IS THE SECURITY GUARD EVEN WIRED? Nothing answered that until now. -------------
    #
    # tools/guard_pretooluse.py turns the ai/SECURITY.md hard lines into actual rules --
    # destructive commands, protected paths, commits on main -- and ships DISABLED on purpose,
    # because a PreToolUse guard that starts asking on a machine that never opted in is a guard
    # people rip out. Deliberately off is fine. Silently off is not.
    #
    # Its own changelog, 2026-08-09: "'has this ever fired', 'what did it stop' and 'is it even
    # wired' all had no answer, and the last of those was NO for months on this project's own
    # machine." A month later it was still NO, in all five of this fleet's repositories, and
    # nothing anywhere said so. The guard diagnosed its own gap and no check was built for it.
    #
    # A NOTE, NOT A FAILURE. Shipping it off is a supported choice; the reader just has to know
    # which choice is in force. `[--]` is this file's could-not/did-not marker, distinct from
    # both [OK] and [!].
    if [ -f tools/guard_pretooluse.py ]; then
      _g_wired="$(python3 - <<'PYGUARD' 2>/dev/null
import json, io
try:
    h = json.load(io.open(".claude/settings.json", encoding="utf-8")).get("hooks", {}) or {}
except Exception:
    print("UNREADABLE"); raise SystemExit
cmds = " ".join(c.get("command", "") for v in h.values() for g in v for c in g.get("hooks", []))
print("WIRED" if "guard_pretooluse" in cmds else "OFF")
PYGUARD
)"
      case "$_g_wired" in
        WIRED) echo "[OK]   tools/guard_pretooluse.py is wired as a PreToolUse hook" ;;
        OFF)   echo "[--]   tools/guard_pretooluse.py is present and NOT wired — the ai/SECURITY.md"
               echo "       hard lines are documented here and enforced by nothing. That is the"
               echo "       shipped default and may be what you want; it is reported because"
               echo "       'deliberately off' and 'nobody ever wired it' look identical."
               echo "       Enforce them:  add it as a PreToolUse hook in .claude/settings.json"
               echo "       Prove it first: python3 tools/guard_pretooluse.py --selftest  (33 cases)" ;;
        *)     echo "[--]   tools/guard_pretooluse.py wiring could not be determined" ;;
      esac
      unset _g_wired
    fi
  else
    echo "[OK]   .claude/settings.json (hooks not compared — no python3 or no canonical set)"
  fi

  local session_entries
  # THE BRACKET IS OPTIONAL AND THAT IS THE WHOLE FIX. ai/SESSION.md ships a template
  # prescribing `## [YYYY-MM-DD] — [Person or Tool]`, and this pattern required a bare
  # date — so it could never match a correctly-formatted file. Every adopter who followed
  # the template got this warning forever, and the only way to silence it was to stop
  # following the template. tools/session_archive.py parsed the same file correctly
  # throughout, so the format was never ambiguous; this check simply had a second opinion.
  session_entries=$(grep -cE '^## \[?[0-9]{4}-[0-9]{2}-[0-9]{2}' ai/SESSION.md 2>/dev/null || true)
  if [ -z "$session_entries" ] || [ "$session_entries" = "0" ]; then
    echo "[!]    ai/SESSION.md has no dated session entries yet"
  fi

  local overlay_line
  overlay_line=$(grep -m1 '^# Overlay: ' ai/STANDARDS.md 2>/dev/null || true)
  if [ -n "$overlay_line" ]; then
    echo "[OK]   overlay applied: ${overlay_line#\# Overlay: }"
  else
    echo "[!]    no overlay applied (base scaffold only)"
  fi

  # THE OVERLAY'S DOCUMENTS, NOT JUST ITS NAME (Clocktower #9). The security-tool overlay
  # writes a THREAT_MODEL.md of five empty headings, and four overlays create docs/specs/;
  # nothing ever looked at either again. "Overlay applied" above a threat model nobody wrote
  # reads as a security project that has done its homework.
  if grep -q '^# Overlay: security-tool' ai/STANDARDS.md 2>/dev/null; then
    if [ ! -f docs/THREAT_MODEL.md ]; then
      echo "[!]    security-tool overlay, and no docs/THREAT_MODEL.md at all"
    else
      local tm_body tm_behind
      tm_body=$(grep -vE '^[[:space:]]*(#|$)' docs/THREAT_MODEL.md | grep -c . || true)
      if [ "${tm_body:-0}" = "0" ]; then
        echo "[!]    docs/THREAT_MODEL.md is still the unfilled stub — headings, no content"
      else
        # STALE, MEASURED IN WORK RATHER THAN DAYS: commits outside docs/ since it last
        # changed. 50 is several weeks of ordinary work; a quiet project never trips it.
        tm_behind=$(git log --oneline "$(git log -1 --format=%H -- docs/THREAT_MODEL.md 2>/dev/null)..HEAD" \
                      -- . ':!docs' 2>/dev/null | wc -l | tr -d ' ')
        if [ "${tm_behind:-0}" -ge 50 ] 2>/dev/null; then
          echo "[!]    docs/THREAT_MODEL.md has not changed in $tm_behind commits of code — re-read it"
        fi
      fi
    fi
  fi
  if [ -d docs/specs ] && [ -z "$(find docs/specs -type f ! -name .gitkeep 2>/dev/null | head -1)" ]; then
    echo "[!]    docs/specs/ is empty — the overlay that created it keeps specs there"
  fi

  # THE VENDORED CHECKS, RUN RATHER THAN ASSUMED — AND LOGGED INDIVIDUALLY.
  #
  # `setup.sh --check` logging once would say the wrapper ran and nothing about whether it
  # still runs each check INSIDE it. That distinction is not academic: until 0.9.0 this
  # function skipped header_check, localcoder_sync and the archive report entirely while
  # printing "all hard checks passed", and a per-run log would have recorded a healthy
  # `setup.sh --check` every single day throughout. The granularity of the log has to match
  # the granularity of the thing that can go missing.
  #
  # This function verified 4 things and printed "all hard checks passed", while CI ran 13.
  # header_check.sh, session_archive.py and localcoder_sync.py are all vendored, offline and
  # fast, and none of them was invoked — so a human running `./setup.sh --check` got a
  # materially narrower answer than the build, and the narrower one was the reassuring one.
  # That is the same divergence the secret scan already cost this file: two answers to "is
  # this scaffold OK", and the one a person reads was the smaller.
  #
  # Delegation, not reimplementation. Each tool owns its own rule and its own message.
  # ---- WHAT EVERY SESSION PAYS BEFORE THE FIRST INSTRUCTION (#280) ------------------------
  #
  # The load order in ai/STANDARDS.md names nine files, and every one of them is read in full
  # at session start. Nothing measured the total, and it grew the way an append-only file
  # always does. MEASURED 2026-09-01: 95 KB here (~24k tokens), 156 KB in Robiton/localcoder,
  # 184 KB in localcoder-dev and 217 KB in ai-project-scaffold-dev -- roughly 54k tokens, a
  # quarter of a 200k window spent before anybody has asked for anything.
  #
  # ADVISORY, AND THE DEFAULT IS SET WHERE IT IS NOT RED ON ARRIVAL. 80 KB was the number
  # asked for and it cannot be the default: a FRESH adoption -- template ai/ files and
  # nothing else -- measures 85 KB after this release's trim, so an 80 KB default would
  # redden every adopter on the day they adopt, which ai/SECURITY.md's own rule says is how
  # a check gets ignored. 120 KB is the product floor plus headroom. It still trips the
  # three repositories that needed to hear it: localcoder 151 KB, localcoder-dev 179 KB and
  # ai-project-scaffold-dev 211 KB, all measured 2026-09-01.
  #
  # 80 KB IS STILL THE TARGET, and the over-message says so, because the goal is to get the
  # product's own floor down rather than to raise the line until it stops complaining -- the
  # failure the MEMORY.md ceiling section in ai/STANDARDS.md is entirely about.
  #
  # PER PROJECT, like every other ceiling here: <!-- scaffold:context-ceiling <KB> --> in
  # ai/STANDARDS.md. It never fails --check.
  _lo_ceiling="$(grep -oE '^<!--[[:space:]]*scaffold:context-ceiling[[:space:]]+[0-9]+' \
                   ai/STANDARDS.md 2>/dev/null | grep -oE '[0-9]+$' | head -1)"
  case "$_lo_ceiling" in ''|*[!0-9]*) _lo_ceiling=120 ;; esac
  _lo_total=0; _lo_worst=""; _lo_worst_n=0
  for _lo_f in AGENTS.md ai/STANDARDS.md ai/MEMORY.md ai/BACKLOG.md ai/SESSION.md \
               ai/CODING.md ai/SECURITY.md ai/PLANNING.md ai/TEAM.md; do
    [ -f "$_lo_f" ] || continue
    # SESSION.md IS COUNTED AS THE LOAD ORDER READS IT, not as it sits on disk. The load
    # order asks for the newest few entries, so charging a session for the whole log would
    # measure a cost nobody pays and would keep reporting red after the fix that helps.
    if [ "$_lo_f" = "ai/SESSION.md" ] && [ -x tools/session_archive.py ]; then
      _lo_n="$(tools/session_archive.py --session-head --bytes 2>/dev/null || true)"
      case "$_lo_n" in ''|*[!0-9]*) _lo_n="$(wc -c < "$_lo_f" | tr -d ' ')" ;; esac
    else
      _lo_n="$(wc -c < "$_lo_f" | tr -d ' ')"
    fi
    _lo_total=$((_lo_total + _lo_n))
    if [ "$_lo_n" -gt "$_lo_worst_n" ]; then _lo_worst_n="$_lo_n"; _lo_worst="$_lo_f"; fi
  done
  if [ "$_lo_total" -gt $((_lo_ceiling * 1024)) ]; then
    echo "[!]    always-loaded context: $((_lo_total / 1024)) KB (~$((_lo_total / 4000))k tokens) — over the ${_lo_ceiling} KB advisory ceiling"
    echo "       Largest: $_lo_worst at $((_lo_worst_n / 1024)) KB. Every session pays this before"
    echo "       the first instruction. The TARGET is 90 KB; this ceiling is the product's"
    echo "       own floor plus headroom, not a goal. tools/session_archive.py moves history"
    echo "       out without deleting it, and ai/STANDARDS_EVIDENCE.md is where a rule's"
    echo "       story goes when the rule itself has to stay loaded."
  else
    echo "[OK]   always-loaded context: $((_lo_total / 1024)) KB (~$((_lo_total / 4000))k tokens), under the ${_lo_ceiling} KB ceiling"
  fi
  unset _lo_total _lo_worst _lo_worst_n _lo_f _lo_n _lo_ceiling

  if [ -x tools/header_check.sh ]; then
    if tools/header_check.sh >/dev/null 2>&1; then
      echo "[OK]   file headers and build stamps"
      [ -x tools/scaffold_log.sh ] && tools/scaffold_log.sh --log header_check.sh ok "" || true
    else
      # REPLAY THE OUTPUT, the way --assert-consistent does 180 lines above. "run it for the
      # detail" asks the reader to run a command whose answer this branch already has.
      echo "[FAIL] tools/header_check.sh"
      tools/header_check.sh 2>&1 | sed 's/^/       /' | head -10
      [ -x tools/scaffold_log.sh ] && tools/scaffold_log.sh --log header_check.sh FAIL "" || true
      (( fail_count++ )) || true
    fi
  fi
  # THE DRIFT CHECK IS GONE, NOT SKIPPED (W-15, DEC-20). localcoder_sync.py existed because
  # localcoder lived in two repositories. After the split it lives in one, so there is
  # nothing to compare and the tool retired with the files it watched — taking D-15, D-16
  # and D-19 with it, unreachable rather than fixed.
  #
  # REMOVED RATHER THAN LEFT TO SKIP. The block was guarded by `[ -x tools/localcoder_sync.py ]`
  # and would simply have fallen through, printing nothing, forever. That is D-18's exact
  # shape: a check that is absent and silent about it. A dead branch that can never run is
  # worse than no branch, because a reader counts it as coverage.
  # ADVISORY, AND IT STAYS ADVISORY HERE TOO. 0.14.0 removed the gate on file length; a
  # local check that failed on it would reintroduce exactly what that release argued out.
  if [ -x tools/session_archive.py ]; then
    local archive_report
    # BRANCH ON THE RESULT, NEVER ON THE PROSE.
    #
    # This grepped the report for `[over]`. session_archive.py emits `[over]` between the
    # archive line and the burst line and `[BURST]` PAST the burst line — which matched
    # nothing, so the worse state fell through to the else and printed
    # `[OK] ai/ files under their archive lines`.
    #
    # MEASURED IN THIS PROGRAMME'S OWN CONTEXT REPO, 2026-08-18, which is how it was found:
    #
    #   BACKLOG.md    623 lines,  23 over the archive line   -> [over]  -> REPORTED
    #   SESSION.md   1016 lines, 316 PAST the burst line     -> [BURST] -> silent
    #   MEMORY.md    1220 lines, 120 PAST the burst line     -> [BURST] -> silent
    #
    # It warned about the least-breached file and said nothing about the two worst: the
    # check got QUIETER as the breach got WORSE. Grepping a sibling tool's human-readable
    # output for a literal is the defect, not the missing literal — matching one more token
    # would only postpone it to the next state anyone adds. So the tool now answers with an
    # exit code (0 clean / 1 over / 2 burst) and this reads that.
    archive_report="$(tools/session_archive.py --all --check --exit-status 2>/dev/null)" \
      && archive_rc=0 || archive_rc=$?
    case "${archive_rc:-0}" in
      2)
        printf '%s\n' "$archive_report" | grep -E '\[(BURST|over)\]' | sed 's/^ *//; s/^/[!!]   /'
        echo "       PAST THE BURST LINE — a trim that stopped happening, not 'a bit over'."
        echo "       archive before starting new work — nothing is deleted:"
        echo "         tools/session_archive.py --apply"
        ;;
      1)
        printf '%s\n' "$archive_report" | grep '\[over\]' | sed 's/^ *//; s/^/[!]    /'
        echo "       archive before starting new work — nothing is deleted:"
        echo "         tools/session_archive.py --apply"
        ;;
      *)
        echo "[OK]   ai/ files under their archive lines"
        ;;
    esac
    [ -x tools/scaffold_log.sh ] && tools/scaffold_log.sh --log session_archive.py ok "" || true
  fi

  # AUTO MEMORY: COUNTED, SO THE SILENCE STOPS LOOKING LIKE "NOTHING TO PROMOTE" (#300).
  # --distill lists these notes, which closed the DETECTION half -- but only when somebody
  # runs it, and #264 recorded an adoption whose session hooks never fired at all. So the
  # mechanism meant to surface them depended on one already known not to run. Measured in
  # `mobile-kmp`: a genuine user correction sat unpromoted for three days and came to light
  # only because the owner asked.
  # ADVISORY, NEVER A FAILURE, and deliberately so: plenty of notes legitimately never need
  # promoting, and the store is per-machine and unversioned, so failing a build on it would
  # redden repositories over something no teammate can see or fix.
  if [ -x tools/close_out.py ]; then
    tools/close_out.py --auto-memory-status 2>/dev/null | sed 's/^ *//; s/^/       /' || true
  fi

  monorepo_notice

  echo ""
  if [ "$fail_count" -gt 0 ]; then
    [ -x tools/scaffold_log.sh ] && tools/scaffold_log.sh --log "setup.sh --check" FAIL "$fail_count failure(s)" || true
    echo "Setup check: $fail_count FAILURE(S) — see fixes above."
    return 1
  fi
  # NAME WHAT THIS DID NOT DO. "All hard checks passed" was true of the checks it ran and
  # false as a statement about the scaffold, which is the difference between a report and a
  # reassurance. CI is still broader on purpose: the selftests and ruff are slow, ruff needs
  # a network fetch of a pinned version, and the localcoder audit wants a minute.
  [ -x tools/scaffold_log.sh ] && tools/scaffold_log.sh --log "setup.sh --check" ok "" || true
  # SAY WHAT [!] MEANS, next to the line that contradicts it (#182). An adopter read
  # "[!] no overlay applied" above "all hard checks passed" and reasonably could not
  # tell which to believe. Both are true; only one is a gate.
  echo "Setup check: all hard checks passed."
  echo "            ([!] lines above are advisory — they do not affect this exit code.)"
  echo "  Not covered here — CI runs these too: tool --selftest suites, ruff (pinned),"
  echo "  the adoption fixture, and header_check in CI's stricter"
  echo "  --since form. ONE COMMAND RUNS ALL OF IT, INCLUDING THIS:"
  echo "      tools/preflight.sh          # after git commit, before git push"
  return 0
}

# --check mode: verify and exit, change nothing
if [ "$CHECK_ONLY" = "1" ]; then
  echo ""
  echo "================================="
  echo " Scaffold Setup Check"
  echo "================================="
  run_checks
  exit $?
fi

echo ""
echo "================================="
echo " AI Project Scaffold Setup"
echo "================================="

if [ -z "$PROJECT_TYPE" ]; then
  echo ""
  echo "What type of project is this?"
  echo "  1) Base only (no overlay)"
  echo "  2) AI skill  (Agent Skills standard — universal format)"
  echo "  3) Splunk app"
  echo "  4) Security tool"
  echo "  5) Python script / automation"
  echo "  6) IT automation / runbooks"
  echo "  7) API integration"
  echo ""
  read -p "Enter number [1-7]: " PROJECT_TYPE
fi

if [ -z "$PROJECT_NAME" ]; then
  echo ""
  read -p "Project name (used in version file and README): " PROJECT_NAME
fi
if [ -z "$SEMVER" ] && [ -z "$NONINTERACTIVE" ]; then
  read -p "Initial version — MAJOR.MINOR.PATCH (default: 0.1.0): " SEMVER
fi
SEMVER=${SEMVER:-0.1.0}
if [ -z "$YOUR_NAME" ]; then
  read -p "Your name (for SESSION.md and TEAM.md): " YOUR_NAME
fi

TIMESTAMP=$(date +"%Y%m%d.%H%M")
FULL_VERSION="${SEMVER}.${TIMESTAMP}"

echo ""
echo "---------------------------------"
echo "Project : $PROJECT_NAME"
echo "Version : $FULL_VERSION"
echo "Owner   : $YOUR_NAME"
echo "---------------------------------"
echo ""

# Write version file — THE ADOPTING PROJECT'S version, not the scaffold's.
# ---- SETUP READS ITS TEMPLATES FROM THE CURRENT DIRECTORY, SO REFUSE EARLY IF IT IS NOT
# ---- THE SCAFFOLD. Measured 2026-08-31 while adopting into a new repo: running
#      `../ai-project-scaffold/setup.sh --type base ...` from INSIDE the target -- the
#      obvious reading of "adopt the scaffold into my project" -- created .claude, .cursor,
#      .github and CLAUDE.md, then died with
#
#          setup.sh: line 1484: ai/MEMORY.md: No such file or directory
#
#      leaving a HALF-CONFIGURED repository: an empty ai/, no .scaffold-version, and four
#      directories that look like a successful adoption. Every template path here is
#      relative (`overlays/<type>/REFERENCE.md`, `ai/...`), so the script only works when
#      the current directory IS the scaffold -- and nothing said so until it was too late
#      to be useful.
#
#      A wrong invocation must fail BEFORE it writes anything, and say what to do instead.
#      PLACED IMMEDIATELY ABOVE THE FIRST WRITE, and that position is the fix. The first
#      version of this guard sat ~100 lines lower, after `version`, `.gitignore` and
#      CLAUDE.md had already been created -- so it refused correctly while its own message
#      ("Nothing has been created or modified") was false. A guard that lies about what it
#      prevented is worse than the defect it guards.
#      Runs after --check has exited, so it never fires for --check or --upgrade.
if [ ! -f ai/STANDARDS.md ] || [ ! -d overlays ]; then
  echo "" >&2
  echo "setup: REFUSING TO RUN — this is not the scaffold directory." >&2
  echo "" >&2
  echo "  setup.sh reads its templates from the CURRENT directory (overlays/, ai/), so it" >&2
  echo "  must be run from inside the scaffold, not from the project you are adopting into." >&2
  echo "  Nothing has been created or modified." >&2
  echo "" >&2
  echo "  For a NEW project, follow docs/ADOPTION_GUIDE.md -> 'Copy the scaffold files'." >&2
  echo "  To verify or upgrade an EXISTING adoption, those modes run from the project:" >&2
  echo "      ./setup.sh --check          # verify, change nothing" >&2
  echo "      ./setup.sh --upgrade        # move to a newer release" >&2
  echo "" >&2
  exit 2
fi

# THE VERSION FILE IS THE ADOPTER'S, AND ADOPTION_GUIDE.md SAYS SO IN SO MANY WORDS:
# "`version` is deliberately NOT copied — that file is YOUR project's version." This line
# then overwrote it with 0.1.0 on every `setup.sh --type` run, in all seven overlays.
# Measured with a fixture at 9.9.9: every overlay reset it. Applying an overlay to an
# existing project is a documented mode, so this was not a corner case.
#
# EXCEPT WHEN IT IS OURS (Clocktower #1). QUICK_START step 1 is "clone the scaffold", so on
# that path `version` exists before setup.sh runs -- holding the SCAFFOLD's release -- and the
# guard above kept it as "yours": a new project born at 0.108.0.20260915.0843. Upstream keeps
# `version` equal to `.scaffold-version` (setup.sh --check enforces it), and a real adopter's
# own version never equals the scaffold release it records, so equality is the tell.
_inherited_version=0
if [ -f version ] && [ -f .scaffold-version ] \
   && [ "$(tr -d " \t\n\r" < version 2>/dev/null)" = "$(tr -d " \t\n\r" < .scaffold-version 2>/dev/null)" ]; then
  _inherited_version=1
fi
if [ -f version ] && [ "$_inherited_version" -eq 1 ]; then
  echo "[OK] version file reset to $FULL_VERSION — it held the scaffold's own release"
  echo "     ($(tr -d " \t\n\r" < version)), inherited from the clone, not this project's."
  echo "$FULL_VERSION" > version
elif [ -f version ]; then
  _existing_version="$(tr -d " \t\n\r" < version 2>/dev/null)"
  if [ "$_existing_version" = "$FULL_VERSION" ]; then
    echo "[OK] version ($FULL_VERSION)"
  else
    echo "[OK] version ($_existing_version) — kept. This project already had one, and it is"
    echo "     yours; setup.sh would have written $FULL_VERSION over it."
  fi
  unset _existing_version 2>/dev/null || true
else
  echo "$FULL_VERSION" > version
  echo "[OK] version file created ($FULL_VERSION)"
fi

# AND SHED AN INHERITED no-artifact DECLARATION, because we just contradicted it.
#
# THE SAME CLASS AS overlays/ AND OVERVIEW.md, found by the invariant check added in 0.57.0.
# A template can be cloned from a repo that ships NOTHING — both of this programme's context
# repos are exactly that — and such a repo declares `scaffold:no-artifact` in ai/STANDARDS.md.
# The clone inherits the declaration, setup.sh then writes a `version` file, and the new
# project now makes two opposite claims about itself: it ships an artifact, and it ships none.
#
# Nothing noticed until the invariant became local: the workflow-only check never ran in a
# fresh project, and `[OK] version file` was printed while the contradiction sat one file away.
if [ -f ai/STANDARDS.md ] && grep -qE '^<!--[[:space:]]*scaffold:no-artifact[[:space:]]*-->[[:space:]]*$' ai/STANDARDS.md; then
  # `mktemp -t NAME` is BSD-only (#249). On Linux this returned empty and the guard below
  # then SILENTLY SKIPPED the strip -- no error, just a scaffold:no-artifact marker that
  # never got removed. Not named in the issue; found by grepping the tree for the class.
  _tmp_std="$(mktemp "${TMPDIR:-/tmp}/stdshed.XXXXXX")" || _tmp_std=""
  if [ -n "$_tmp_std" ]; then
    grep -vE '^<!--[[:space:]]*scaffold:no-artifact[[:space:]]*-->[[:space:]]*$' ai/STANDARDS.md > "$_tmp_std" \
      && cat "$_tmp_std" > ai/STANDARDS.md
    rm -f "$_tmp_std"
    echo "[OK] shed the inherited scaffold:no-artifact declaration — this project has a version file"
  fi
fi
echo "[OK] version file created: $FULL_VERSION"

# ...and record WHICH SCAFFOLD RELEASE this project is on, separately.
#
# These were the same file, and that collided badly. Updating is documented as
# "clone the scaffold and diff its files against yours", so `version` showed up as a
# diff on every update — and taking that diff silently replaced the adopter's project
# version with the scaffold's. Measured downstream: `version` held a SCAFFOLD version
# from day one and never the app's, and a v0.3.0 update did not bump it at all, so
# ai/MEMORY.md claimed v0.3.0 while the file still said 0.2.0 for a month.
#
# It also made staleness undetectable: a human who thought to check "what scaffold am
# I on?" was reading their own project version.
# .scaffold-version ships WITH the scaffold's own files, so it travels on every update
# exactly like the tools and standards do. Nothing here writes it: it is already correct
# if the adopter copied the scaffold across, and its absence means they are on a release
# that predates it.
if [ -f .scaffold-version ]; then
  echo "[OK] .scaffold-version: $(cat .scaffold-version)"
  echo "     That is the SCAFFOLD release. 'version' above is YOUR project's."
  echo "     Different files on purpose — never copy 'version' across on an update."
else
  echo "[!]  no .scaffold-version — this project predates scaffold release tracking."
  echo "     Copy .scaffold-version from the scaffold repo so updates can tell you"
  echo "     when you are behind (tools/scaffold_version.sh)."
fi

# Ensure the CLAUDE.md pointer exists — a committed one-line '@AGENTS.md' import.
# Claude Code inlines AGENTS.md at load time (a reference, not a copy). This replaced
# the old gitignored symlink: symlinks are flattened by OneDrive, need elevation on
# Windows, and a fresh clone had no CLAUDE.md until setup ran.
if [ -L CLAUDE.md ]; then
  rm CLAUDE.md   # legacy symlink from the old design — replace with the pointer file
fi
# UPGRADE GAP: ≤v0.3.0 told adopters to gitignore CLAUDE.md, because it was a symlink
# then. Creating the pointer file is not enough — if the ignore rule survives, the file
# is created and never committed, so every teammate and every fresh clone still has no
# CLAUDE.md and the whole point of the committed-pointer change is lost. Silently, since
# the file exists locally and everything looks right on the machine that ran setup.
if [ -f .gitignore ] && grep -qE '^[[:space:]]*/?CLAUDE\.md[[:space:]]*$' .gitignore; then
  # Keep a backup: editing someone's .gitignore unasked deserves an undo.
  cp .gitignore .gitignore.scaffold-backup
  grep -vE '^[[:space:]]*/?CLAUDE\.md[[:space:]]*$' .gitignore > .gitignore.tmp && mv .gitignore.tmp .gitignore
  echo "[OK] removed CLAUDE.md from .gitignore — it is committed now, not a symlink"
  echo "     (previous .gitignore saved as .gitignore.scaffold-backup)"
  echo "     Commit it: git add CLAUDE.md .gitignore"
fi
# THE LOCALCODER AUDIT LOG MUST BE IGNORED BEFORE IT EXISTS (localcoder#94). It records draft
# bodies verbatim, verify command output verbatim, and MCP tool ARGUMENTS AND RESULTS
# verbatim — so it can hold a bearer token passed to a server and every row a query returned.
# It is not redacted by default, deliberately (docs/AUDIT.md).
#
# ADDED HERE RATHER THAN LEFT TO A WARNING, because the ordering is unforgiving: the file is
# created by the first drafting run, and the window between that run and the next `git add -A`
# is often one command. A warning printed inside that window arrives at the same moment as the
# risk. Only appends, only when absent, and only to a repository — same rule as above.
# ASK GIT, DO NOT LOOK FOR A .git DIRECTORY (#296). In a monorepo the project is a
# SUBDIRECTORY and `.git` lives at the repository root, so `[ -d .git ]` is false and this
# whole block was skipped — meaning the one adoption shape that most needs the audit-log
# rule (a shared repository, many people, production config alongside) was the one shape
# that never got it. Found by the guide-shaped fixture in tools/adoption_check.sh, which is
# the first thing here to build an adoption below a repository root.
if git rev-parse --is-inside-work-tree >/dev/null 2>&1 \
   && [ "${SCAFFOLD_SKIP_GITIGNORE:-0}" != "1" ]; then
  # One code path writes .gitignore now (#292). The glob covers rotations .1 .. .5 and the
  # .bodies/ sidecar directory, because rotation invents filenames.
  gitignore_ensure_lines \
    "# localcoder audit log (#94) — draft bodies, tool arguments and verify output, VERBATIM
# and NOT redacted by default. SCAFFOLD_SKIP_GITIGNORE=1 to opt out." \
    '.localcoder-audit.jsonl*'
fi
if [ ! -f CLAUDE.md ]; then
  printf '@AGENTS.md\n' > CLAUDE.md
  echo "[OK] CLAUDE.md pointer created (@AGENTS.md import)"
elif ! grep -q '^@AGENTS.md' CLAUDE.md; then
  echo "[!]  CLAUDE.md exists but has no '@AGENTS.md' line — Claude Code will not load AGENTS.md."
  echo "[!]  Add a line containing exactly: @AGENTS.md"
else
  echo "[OK] CLAUDE.md pointer present (@AGENTS.md import)"
fi

# Mirror skills into .claude/skills/ for Claude Code
# .agents/skills/ is the canonical, cross-tool location (Agent Skills open standard,
# read natively by Codex and others). Claude Code only scans .claude/skills/, so we
# keep a byte-identical mirror there. Real copies, not symlinks — symlinks do not
# survive OneDrive sync. Edit the canonical copy, then re-run this script.
if [ -d .agents/skills ]; then
  mkdir -p .claude/skills
  cp -R .agents/skills/. .claude/skills/
  echo "[OK] .claude/skills/ mirrored from .agents/skills/ (canonical)"
fi

# Create Cursor rules in the new .cursor/rules/base.mdc format
# (.cursorrules is retained in the repo as a fallback for older Cursor versions)
mkdir -p .cursor/rules
cat > .cursor/rules/base.mdc << 'CURSOREOF'
---
description: AI context bootstrap — load project standards before beginning any work
globs: ["**/*"]
alwaysApply: true
---

# AI Context Bootstrap

Read `ai/STANDARDS.md` and load all files in the order it specifies before beginning
any work. Do not start coding, planning, or responding until the full load order is
complete.

At the end of every session, update `ai/SESSION.md` and `ai/BACKLOG.md`.
Never store credentials, secrets, or PHI in any `ai/` file.
CURSOREOF
echo "[OK] .cursor/rules/base.mdc created (Cursor v0.44+ format)"

# Create scoped GitHub Copilot instructions (.github/instructions/ — added July 2025)
# (.github/copilot-instructions.md is retained as a fallback for older Copilot versions)
mkdir -p .github/instructions
cat > .github/instructions/general.instructions.md << 'COPILOTEOF'
---
applyTo: "**"
---

# AI Context Bootstrap

Read `ai/STANDARDS.md` and load all files in the order it specifies before beginning
any work. Do not start coding, planning, or responding until the full load order is
complete.

At the end of every session, update `ai/SESSION.md` and `ai/BACKLOG.md`.
Never store credentials, secrets, or PHI in any `ai/` file.
COPILOTEOF
echo "[OK] .github/instructions/general.instructions.md created (Copilot scoped format)"

# Create .claude/settings.json with SessionStart hook to auto-run sync-check.sh
# (settings.local.json is globally gitignored — settings.json is committed project config)
#
# THE HOOK LOOKS FOR THE REPO, IT DOES NOT ASSUME IT IS STANDING IN IT.
#
# `[ -f sync-check.sh ]` is relative to the session's WORKING DIRECTORY, which is only the
# repo root when someone opens the editor exactly there. Measured 2026-08-09 on this
# project's own machine: sessions run in the PARENT of three scaffold repos — the layout
# this project's own AGENTS.md prescribes, "open this repo plus ../ai-project-scaffold as a
# second working directory" — so the guard was false every time, `|| true` swallowed it, and
# **the session-start check had never run once**. Not degraded: never run. A hook whose
# every failure path is `|| true` cannot tell you it did nothing.
#
# So it scans the current directory and one level below, and runs in each place that is
# actually an adoption (`ai/STANDARDS.md` present — the same signal every other check keys
# on). In an ordinary single-repo session `.` matches and nothing else does. In a
# multi-repo session every repo gets checked, which is the behaviour that was intended all
# along. One level only: deeper is a monorepo, and walking it at session start is a cost
# nobody asked for.
# MERGE, NEVER SKIP. This block used to do two wrong things and they had the same cause:
# a SECOND copy of the hooks lived here, in a heredoc, and the real set lived in
# .claude/settings.json. The copy drifted to ONE of SIX commands, so a project created
# without an existing settings.json lost the session journal, correction capture,
# SessionEnd and both PreCompact hooks (#246 and the drift found alongside it). And when a
# settings.json DID exist -- the normal state of any repo where someone has already run
# Claude Code, which is exactly the adoption population -- the whole file was skipped and
# the adopter got no hooks at all.
#
# So: .claude/settings.hooks.json is now the single source of truth, and this merges it.
# The scaffold owns the `hooks` key. The adopter owns every sibling key -- permissions,
# env, model, statusLine -- and they are preserved untouched. That is what a person
# reconciling the two files by hand would do.
mkdir -p .claude
if [ -f .claude/settings.hooks.json ] && command -v python3 >/dev/null 2>&1; then
  _hooks_before="$( [ -f .claude/settings.json ] && cat .claude/settings.json || echo '' )"
  if python3 - "$PWD" <<'PYHOOKS'
import json, io, os, sys
root = sys.argv[1]
canon = os.path.join(root, ".claude", "settings.hooks.json")
target = os.path.join(root, ".claude", "settings.json")
hooks = json.load(io.open(canon, encoding="utf-8"))["hooks"]
existing = {}
if os.path.exists(target):
    try:
        existing = json.load(io.open(target, encoding="utf-8"))
    except ValueError:
        # A malformed settings.json is the adopter's file and not ours to discard.
        sys.stderr.write("settings.json is not valid JSON -- leaving it alone\n")
        raise SystemExit(2)
    if not isinstance(existing, dict):
        sys.stderr.write("settings.json is not a JSON object -- leaving it alone\n")
        raise SystemExit(2)
existed = bool(existing)
kept = [k for k in existing if k != "hooks"]
existing["hooks"] = hooks
# WRITE VIA A TEMPORARY IN THE SAME DIRECTORY, THEN RENAME. A direct open("w") truncates
# first and writes second, so an interrupt between the two leaves the adopter with an empty
# or half-written settings.json -- their file, destroyed by our convenience. os.replace is
# atomic within a filesystem, and the temp sits beside the target so it always is one.
# os.path.realpath keeps a symlinked settings.json working: write through it, not over it.
real = os.path.realpath(target)
tmp = real + ".scaffold-tmp"
io.open(tmp, "w", encoding="utf-8").write(json.dumps(existing, indent=2) + "\n")
os.replace(tmp, real)
n = sum(len(g.get("hooks", [])) for v in hooks.values() for g in v)
if existed:
    print("[OK] .claude/settings.json — %d hooks merged in; kept your %s"
          % (n, ", ".join(kept) if kept else "other keys"))
else:
    print("[OK] .claude/settings.json created — %d hooks (session start, journal, "
          "correction capture, pre-compact)" % n)
# THE HOOKS ARE LIVE; THE SESSION-START ONE HAS ALREADY MISSED ITS MOMENT.
#
# Claude Code picks up direct edits to hooks in settings files automatically via its file
# watcher, so Stop, SessionEnd and PreCompact begin working in THIS session. SessionStart
# cannot: that event fired before these hooks existed. So the session RECORD for the session
# that ran setup is never opened, ai/SESSION.md shows no entry for it, and the reasonable
# reading of a green setup is that logging works. It does -- from the next session onward.
#
# Printed here rather than written in a document, because this is the moment the reader is
# looking at the screen.
print("     Stop / SessionEnd / PreCompact are live now (Claude Code watches this file).")
print("     SessionStart is NOT -- it fired before these hooks existed, so THIS session")
print("     opens no record in ai/SESSION.md. Start or resume a session to get one;")
print("     a resume counts: SessionStart fires on startup, resume, clear, compact, fork.")
PYHOOKS
  then :
  else
    echo "[!]  .claude/settings.json left unchanged — see the message above."
    echo "     The scaffold's hooks are in .claude/settings.hooks.json; merge the \`hooks\`"
    echo "     key into your settings.json by hand to get the session journal and"
    echo "     correction capture."
  fi
  unset _hooks_before
elif [ ! -f .claude/settings.json ]; then
  # python3 absent AND no settings.json: write the canonical file verbatim rather than a
  # hand-maintained subset, so the degraded path cannot drift the way the heredoc did.
  if [ -f .claude/settings.hooks.json ]; then
    cp .claude/settings.hooks.json .claude/settings.json
    echo "[OK] .claude/settings.json created from the canonical hook set (python3 absent,"
    echo "     so the _comment key is carried across too — harmless, and Claude Code ignores it)"
  fi
else
  echo "[!]  .claude/settings.json exists and python3 is unavailable — hooks NOT merged."
  echo "     Merge the \`hooks\` key from .claude/settings.hooks.json by hand, or the session"
  echo "     journal and correction capture will not run."
fi

# Make scripts executable
chmod +x sync-check.sh 2>/dev/null || true

# Helper: apply overlay content to ai/ files (guards against duplicate appends)
apply_overlay() {
  local overlay_name="$1"
  if grep -q "# Overlay: $overlay_name" ai/STANDARDS.md 2>/dev/null; then
    echo "[!]  Overlay '$overlay_name' already applied to ai/STANDARDS.md — skipping append."
    echo "[!]  If you need to switch overlays, see docs/TROUBLESHOOTING.md"
    return 1
  fi
  echo "" >> ai/STANDARDS.md && echo "---" >> ai/STANDARDS.md
  echo "# Overlay: $overlay_name" >> ai/STANDARDS.md
  cat "overlays/$overlay_name/STANDARDS.md" >> ai/STANDARDS.md
  echo "" >> ai/CODING.md && echo "---" >> ai/CODING.md
  echo "# Overlay: $overlay_name" >> ai/CODING.md
  cat "overlays/$overlay_name/CODING.md" >> ai/CODING.md
  if [ -f "overlays/$overlay_name/REFERENCE.md" ]; then
    cp "overlays/$overlay_name/REFERENCE.md" ai/REFERENCE.md
    echo "[OK] Reference material copied to ai/REFERENCE.md"
  fi
  return 0
}

# Apply overlay based on project type
case $PROJECT_TYPE in
  2)
    OVERLAY="ai-skill"
    echo "[..] Applying AI skill overlay..."
    # .agents/skills/ is the cross-client standard path for Agent Skills-compatible tools
    mkdir -p .agents/skills
    if apply_overlay "ai-skill"; then
      echo "[OK] AI skill overlay applied."
    fi
    echo "[!]  Skills go in .agents/skills/<skill-name>/SKILL.md"
    echo "[!]  User-level skills go in ~/.agents/skills/<skill-name>/"
    echo "[!]  ChatGPT flat .md only needed if targeting Custom GPTs"
    ;;

  3)
    OVERLAY="splunk-app"
    echo ""
    echo "--- Splunk App Setup ---"

    # New vs existing
    if [ -z "$SPLUNK_NEW_OR_EXISTING" ]; then
      echo ""
      echo "Is this a new app or an existing app?"
      echo "  1) New app (scaffold creates directory structure)"
      echo "  2) Existing app (standards only — no scaffolding)"
      echo ""
      read -p "Enter number [1-2]: " SPLUNK_NEW_OR_EXISTING
    fi

    # UCC or conf-only (relevant for new apps; recorded either way)
    if [ -z "$SPLUNK_APP_TYPE" ]; then
      echo ""
      echo "What type of Splunk app?"
      echo "  1) UCC-based TA  (modular inputs, UI, REST handlers — uses ucc-gen)"
      echo "  2) Conf-only app (no Python, no UI — props/transforms/savedsearches etc.)"
      echo "  3) Not sure yet"
      echo ""
      read -p "Enter number [1-3]: " SPLUNK_APP_TYPE
    fi

    # Splunk version → determines runtime Python
    if [ -z "$SPLUNK_VERSION_CHOICE" ]; then
      echo ""
      echo "What is your target Splunk Enterprise version?"
      echo "  1) 9.0.x / 9.1.x / 9.2.x  (bundled Python 3.7)"
      echo "  2) 9.3.x / 9.4.x           (bundled Python 3.9)"
      echo "  3) 10.x                     (bundled Python 3.9+)"
      echo ""
      read -p "Enter number [1-3]: " SPLUNK_VERSION_CHOICE
    fi

    case $SPLUNK_VERSION_CHOICE in
      1) SPLUNK_PYTHON="3.7"; SPLUNK_VER_LABEL="9.0–9.2" ;;
      3) SPLUNK_PYTHON="3.9+"; SPLUNK_VER_LABEL="10.x" ;;
      *) SPLUNK_PYTHON="3.9"; SPLUNK_VER_LABEL="9.3–9.4" ;;
    esac

    # Deployment target → gates cloud vetting requirements
    if [ -z "$SPLUNK_DEPLOY" ]; then
      echo ""
      echo "Deployment target?"
      echo "  1) On-premises only"
      echo "  2) Splunk Cloud (or potential future Cloud)"
      echo "  3) Both / undecided"
      echo ""
      read -p "Enter number [1-3]: " SPLUNK_DEPLOY
    fi

    # Always apply overlay standards
    echo ""
    echo "[..] Applying Splunk app overlay standards..."
    apply_overlay "splunk-app"

    # Scaffold creation — new apps only
    if [ "$SPLUNK_NEW_OR_EXISTING" = "1" ]; then
      if [ "$SPLUNK_APP_TYPE" = "1" ]; then
        # UCC-based TA: package/ is the source; output/ is generated by ucc-gen build
        mkdir -p package/bin package/default package/lib metadata docs lookups
        create_if_absent package/default/app.conf "Splunk app identity stub" << EOF
# App:       $PROJECT_NAME
# File:      app.conf
# Modified:  $(date +%Y-%m-%d)
# Version:   $FULL_VERSION
# Purpose:   App identity and configuration

[install]
build = 1
is_configured = false

[launcher]
version = $FULL_VERSION
description =
author = $YOUR_NAME

[package]
id = $PROJECT_NAME
check_for_updates = false

[ui]
is_visible = false
label = $PROJECT_NAME
EOF
        echo "[OK] UCC app structure created (package/ layout)."
        echo "[!]  Next: run 'ucc-gen init' to generate the full add-on skeleton."
        echo "[!]  See ai/STANDARDS.md — UCC Toolchain Setup section for full steps."

        # UCC stubs — globalConfig.json, settings.conf, requirements.txt
        create_if_absent package/globalConfig.json "UCC global config stub" << EOF
{
  "pages": {
    "configuration": {
      "title": "Configuration",
      "tabs": [
        {
          "name": "credentials",
          "title": "Credentials",
          "entity": []
        }
      ]
    },
    "inputs": {
      "title": "Inputs",
      "description": "Manage your data inputs",
      "table": {
        "header": [],
        "moreInfo": [],
        "actions": ["edit", "delete", "clone"]
      },
      "services": []
    }
  },
  "meta": {
    "name": "$PROJECT_NAME",
    "restRoot": "$PROJECT_NAME",
    "version": "0.1.0",
    "displayName": "$PROJECT_NAME",
    "schemaVersion": "0.0.10"
  }
}
EOF
        create_if_absent "package/default/${PROJECT_NAME}_settings.conf" "UCC settings stub" << 'SETTINGSEOF'
[credentials]
SETTINGSEOF
        create_if_absent requirements.txt "UCC runtime dependency list" << 'REQEOF'
splunk-sdk
splunktaucclib
solnlib
REQEOF
        echo "[OK] UCC stubs created: package/globalConfig.json, package/default/${PROJECT_NAME}_settings.conf, requirements.txt"
      else
        # Conf-only or undecided: standard Splunk app layout
        mkdir -p default metadata docs lookups bin
        create_if_absent default/app.conf "Splunk app identity stub" << EOF
# App:       $PROJECT_NAME
# File:      app.conf
# Modified:  $(date +%Y-%m-%d)
# Version:   $FULL_VERSION
# Purpose:   App identity and configuration

[install]
build = 1
is_configured = false

[launcher]
version = $FULL_VERSION
description =
author = $YOUR_NAME

[package]
id = $PROJECT_NAME
check_for_updates = false

[ui]
is_visible = true
label = $PROJECT_NAME
EOF
        echo "[OK] Conf-only app structure created."
      fi

      # Documentation stubs — for all new Splunk apps
      create_if_absent docs/manual_testing_guide.md "manual testing guide stub" << 'MTGEOF'
# Manual Testing Guide

## Pre-test setup
[Describe environment and prerequisites]

## Test cases
| # | Scenario | Steps | Expected result | Pass/Fail |
|---|----------|-------|-----------------|-----------|
| 1 | | | | |

## Known issues
[Document any known test limitations]
MTGEOF
      create_if_absent docs/deployment_summary.md "deployment summary stub" << 'DSEOF'
# Deployment Summary

## Version
[Version number]

## Deployment targets
| Component | Target | Notes |
|-----------|--------|-------|
| | | |

## Pre-deployment checklist
- [ ] AppInspect passed
- [ ] Manual testing complete
- [ ] CHANGELOG updated
- [ ] Version bumped

## Post-deployment verification
[Steps to verify the deployment succeeded]
DSEOF
      echo "[OK] docs/manual_testing_guide.md and docs/deployment_summary.md created."

    else
      echo "[OK] Existing app — directory scaffolding skipped."
      echo "[!]  Overlay standards have been appended to ai/STANDARDS.md and ai/CODING.md."
      echo "[!]  Review ai/STANDARDS.md for directory structure and naming requirements."
    fi

    # Gitignore and build script — for all Splunk apps (new and existing)
    gitignore_ensure_lines \
      "# Splunk app distribution — lib/ must be committed, generated output must not" \
      '!lib/' '!lib/**' '!package/lib/' '!package/lib/**' \
      '!appserver/static/js/build/' '!appserver/static/js/build/**' \
      'output/' '*.pyc' '__pycache__/' '*.egg-info/' '.pytest_cache/' 'dist/'
    # build.sh — the canonical packaging path (never hand-tar; see overlay Build Process).
    # Header written with real values; body is the overlay REFERENCE.md template verbatim.
    cat > build.sh << BUILDHEADEOF
#!/usr/bin/env bash
# Project:  $PROJECT_NAME
# File:     build.sh
# Modified: $(date +%Y-%m-%d)
# Version:  $FULL_VERSION
# Purpose:  Package this app for deployment with the required exclusions
# Changelog:
#   $(date +%Y-%m-%d) v${SEMVER} — Initial creation (generated by scaffold setup.sh)
BUILDHEADEOF
    cat >> build.sh << 'BUILDEOF'
set -euo pipefail
APP_NAME="$(basename "$(pwd)")"
VERSION="$(cat version)"
ARTIFACT="${APP_NAME}_v${VERSION}.tar.gz"
cd ..
COPYFILE_DISABLE=1 tar \
BUILDEOF
    # ---- THE EXCLUSIONS ARE GENERATED FROM THE MANIFEST, NOT RESTATED HERE (#291).
    #
    # The hand-maintained list excluded 6 of the 20 scaffold artifacts an adoption carries,
    # so a CORRECTLY BUILT package still put tools/, .claude/, .github/ and setup.sh onto a
    # production Splunk host. It excluded ai/, which is precisely what made an outside
    # reviewer read it as "complete and correct". A list that must track another list is
    # the defect; generating it is the fix.
    #
    # FAIL LOUDLY IF THE GENERATOR IS ABSENT. A build script with no exclusions packages
    # the entire repository and says "Built:" — the silent-empty-list failure this project
    # keeps writing about. Refuse instead.
    if [ ! -x tools/adoption_manifest.sh ]; then
      echo "[FAIL] tools/adoption_manifest.sh is missing — cannot generate build.sh exclusions." >&2
      echo "       Copy tools/ (ADOPTION_GUIDE.md step 3) and re-run. Refusing to write a" >&2
      echo "       build.sh that would package the whole repository." >&2
      exit 1
    fi
    _bex="$(tools/adoption_manifest.sh --build-excludes)"
    if [ -z "$_bex" ]; then
      echo "[FAIL] the adoption manifest produced no exclusions — refusing to write build.sh." >&2
      exit 1
    fi
    printf '%s\n' "$_bex" >> build.sh
    unset _bex
    cat >> build.sh << 'BUILDEOF'
  -czf "${APP_NAME}/${ARTIFACT}" "${APP_NAME}"
cd "${APP_NAME}"
echo "Built: ${ARTIFACT}"
echo "Verify before handing off: see ai/REFERENCE.md — 'Verify the artifact before handing off'"
BUILDEOF
    chmod +x build.sh
    echo "[OK] .gitignore and build.sh created (build.sh follows the overlay Build Process standard)."

    # Record Splunk-specific context in MEMORY.md (guard against duplicate append)
    if ! grep -q "## Splunk app context" ai/MEMORY.md 2>/dev/null; then
    echo "" >> ai/MEMORY.md
    echo "## Splunk app context" >> ai/MEMORY.md
    echo "- Target Splunk version: $SPLUNK_VER_LABEL" >> ai/MEMORY.md
    echo "- Runtime Python: $SPLUNK_PYTHON (Splunk bundled — use /opt/splunk/bin/splunk cmd python3)" >> ai/MEMORY.md

    case $SPLUNK_APP_TYPE in
      1) echo "- App type: UCC-based TA" >> ai/MEMORY.md ;;
      2) echo "- App type: Conf-only" >> ai/MEMORY.md ;;
      *) echo "- App type: TBD — update this when decided" >> ai/MEMORY.md ;;
    esac

    case $SPLUNK_DEPLOY in
      2) echo "- Deployment target: Splunk Cloud — cloud AppInspect vetting required" >> ai/MEMORY.md ;;
      3) echo "- Deployment target: Both/undecided — apply cloud AppInspect standards to be safe" >> ai/MEMORY.md ;;
      *) echo "- Deployment target: On-premises" >> ai/MEMORY.md ;;
    esac
    fi  # end duplicate-append guard

    echo "[OK] Splunk app overlay applied."
    ;;

  4)
    OVERLAY="security-tool"
    echo "[..] Applying security tool overlay..."
    mkdir -p docs/specs
    if apply_overlay "security-tool"; then
      echo "[OK] Security tool overlay applied."
    fi
    create_if_absent docs/THREAT_MODEL.md "threat model stub" << EOF
# Threat Model — $PROJECT_NAME

## Trust boundaries

## Data flows

## Attack surface

## Mitigations

## Residual risk
EOF
    echo "     Fill it in before first deploy."
    ;;

  5)
    OVERLAY="python-script"
    echo "[..] Applying Python script overlay..."
    mkdir -p src tests docs/specs
    if apply_overlay "python-script"; then
      echo "[OK] Python script overlay applied."
    fi
    ;;

  6)
    OVERLAY="it-automation"
    echo "[..] Applying IT automation overlay..."
    mkdir -p runbooks scripts docs/specs
    if apply_overlay "it-automation"; then
      echo "[OK] IT automation overlay applied."
    fi
    ;;

  7)
    OVERLAY="api-integration"
    echo "[..] Applying API integration overlay..."
    mkdir -p src tests docs/specs
    if apply_overlay "api-integration"; then
      echo "[OK] API integration overlay applied."
    fi
    ;;

  *)
    OVERLAY="general"
    echo "[OK] Using base scaffold only — no overlay applied."
    ;;
esac

# Record overlay and owner in MEMORY.md
echo "" >> ai/MEMORY.md
echo "## Scaffold setup" >> ai/MEMORY.md
echo "- Project: $PROJECT_NAME" >> ai/MEMORY.md
echo "- Project type / overlay: $OVERLAY" >> ai/MEMORY.md
echo "- Initialized by: $YOUR_NAME" >> ai/MEMORY.md
echo "- Date: $(date +%Y-%m-%d)" >> ai/MEMORY.md
echo "- Initial version: $FULL_VERSION" >> ai/MEMORY.md
echo "[OK] Setup recorded in ai/MEMORY.md"

# Seed TEAM.md with owner name — replace the placeholder template row
if grep -q "\[Your Name\]" ai/TEAM.md 2>/dev/null; then
  # ESCAPED FOR THE REPLACEMENT (report item 28, S11). A name with `/`, `&` or a backslash in it --
  # "R&D", "Ops/Infra" -- broke the sed expression or was rewritten by it: `&` is "the
  # whole match", so the placeholder row came back inside the name. `|` is escaped too,
  # as `\\|`, since a bare one would split the table row.
  _owner_sed="$(printf '%s' "$YOUR_NAME" | sed -e 's/[\\/&]/\\&/g' -e 's/|/\\\\|/g')"
  sed -i.bak "s/| \[Your Name\] | \[Role\] | \[AI tools\] | \[@handle\] |/| $_owner_sed | | | |/" ai/TEAM.md 2>/dev/null || true
  rm -f ai/TEAM.md.bak
fi

# ---------------------------------------------------------------- THIS IS NOT THE SCAFFOLD
# A NEW PROJECT IS CREATED BY CLONING THIS REPOSITORY — docs/QUICK_START.md step 1 says so —
# which means it arrives carrying the scaffold's OWN repo artifacts. Three of them are the
# exact signals `is_upstream_repo()` keys on, so until they go, every tool in here classifies
# the adopter's project as THE SCAFFOLD ITSELF.
#
# MEASURED END TO END ON 2026-08-12, from the published 0.37.1 tarball. A new project set up
# by the documented path, which then did the very first thing AGENTS.md instructs — write a
# dated ai/SESSION.md entry — and ran `tools/preflight.sh` as instructed:
#
#   [FAIL] shipped ai/ files are templates, not our session log
#   [FAIL] localcoder context budget  (exit 1)
#
# Their session log is failing the build for containing session entries, and this
# repository's 28-line prose ratchet is being enforced on their project. BOTH of those were
# scoped to upstream-only on 2026-08-11 precisely so they could not do this to an adopter —
# and the scoping works. It keys on a predicate that a cloned scaffold satisfies.
#
# `tools/adoption_check.sh` did not catch it because it builds the OTHER downstream shape:
# an existing project that took the scaffold by docs/ADOPTION_GUIDE.md and therefore never
# had these files. Two onboarding paths, one covered.
#
# .github/CODEOWNERS IS NOT PART OF THE PREDICATE AND IS REMOVED ANYWAY: it reads `* @Robiton`,
# so every pull request in the adopter's own repository would request review from us.
#
# NOT ON --upgrade AND NOT ON --check. An existing adopter has none of these to remove, and
# the upgrader never installs them.
_scaffold_own=""
for _f in OVERVIEW.md .github/workflows/mirror-sync.yml .github/CODEOWNERS overlays; do
  [ -e "$_f" ] || continue
  rm -rf "$_f"
  _scaffold_own="$_scaffold_own $_f"
done
# AND THE SOURCE REPOSITORY'S OWN MUST-RUN DECLARATION GOES TOO, for exactly the CODEOWNERS
# reason: it is a statement about somebody else's product.
#
# `<!-- scaffold:must-run tests/audit_localcoder.sh -->` names the SOURCE repo's behavioural
# suite. A new project set up from a clone inherits the declaration, and preflight then refuses
# to go green without a suite that is not theirs and cannot pass in their environment. Found
# 2026-08-15 the moment preflight stopped printing PASSED over a failing must-run gate: the
# new-project fixture, built by tarring the localcoder repo, failed its own preflight on
# `tests/audit_localcoder.sh`.
#
# A DECLARED GATE THAT CANNOT RUN IS A FAILURE — that rule is right and is not being weakened.
# What is wrong is inheriting the declaration in the first place. An adopter declares their own
# suite, and AGENTS.md still documents how.
# SCOPED TO A REPOSITORY BEING NAMED AS A NEW PROJECT, and that guard is load-bearing. An
# EXISTING adopter — Robiton/localcoder is the one in front of me — declares its own suite
# legitimately, and silently retiring that declaration would be the worst thing in this file:
# a gate the repository said it cannot go green without, gone, with the verdict still green.
# `--name` is only supplied when someone is naming a NEW project, so the source's declarations
# are by definition not theirs. `--upgrade` and `--check` never reach here at all.
if [ -n "$PROJECT_NAME" ] && [ -f AGENTS.md ] \
   && grep -qE '^<!--[[:space:]]*scaffold:must-run[[:space:]]' AGENTS.md; then
  _mr_had="$(grep -cE '^<!--[[:space:]]*scaffold:must-run[[:space:]]' AGENTS.md)"
  _tmp_agents="$(mktemp "${TMPDIR:-/tmp}/setup.XXXXXX")" || { echo "setup: mktemp failed; stopping" >&2; exit 1; }
  # Same `|| true` as the session-log stripper below, and for the same reason: grep -v exits
  # 1 when nothing survives the filter, and `set -e` turns that into a silent abort. Latent
  # here rather than live -- an AGENTS.md that is nothing but must-run declarations does not
  # occur in practice -- but it is the same landmine and was found by the same test.
  grep -vE '^<!--[[:space:]]*scaffold:must-run[[:space:]]' AGENTS.md > "$_tmp_agents" || true
  mv "$_tmp_agents" AGENTS.md
  echo ""
  echo "[OK] removed $_mr_had inherited scaffold:must-run declaration(s) from AGENTS.md."
  echo "     They named the SOURCE repository's own test suite, not yours. Declare yours at"
  echo "     column 0 when you have one:  <!-- scaffold:must-run <path> -->"
fi

# THE SAME CLASS AS scaffold:must-run ABOVE, AND FOUND THE SAME WAY (#244). ai/BACKLOG.md
# carries, at column 0:
#     <!-- scaffold:session-log ../ai-project-scaffold-dev/ai/SESSION.md -->
# True of THIS repository, whose history lives in the -dev sibling. False in every project
# created from it, where the sibling does not exist -- so session_currency reported
# "the declared session log does not exist" in a fresh project that had a perfectly good
# ai/SESSION.md sitting next to the pointer. Unset, resolve_log() falls back to
# ai/SESSION.md, which is what a new project wants.
#
# Kept when a -dev sibling really is there: someone adopting the two-repo layout on purpose
# should not have their declaration stripped by a tool that assumed they had not.
if [ -n "$PROJECT_NAME" ] && [ -f ai/BACKLOG.md ] \
   && grep -qE '^<!--[[:space:]]*scaffold:session-log[[:space:]]' ai/BACKLOG.md; then
  _sl_target="$(grep -E '^<!--[[:space:]]*scaffold:session-log[[:space:]]' ai/BACKLOG.md \
                | head -1 | sed -E 's/^<!--[[:space:]]*scaffold:session-log[[:space:]]+//; s/[[:space:]]*-->.*$//')"
  if [ -n "$_sl_target" ] && [ -f "$_sl_target" ]; then
    echo ""
    echo "[OK] kept the scaffold:session-log declaration — $_sl_target exists here."
  else
    _tmp_backlog="$(mktemp "${TMPDIR:-/tmp}/setup.XXXXXX")" || { echo "setup: mktemp failed; stopping" >&2; exit 1; }
    # `|| true` IS LOAD-BEARING. grep -v exits 1 when it filters EVERY line, and `set -e` is
    # in force from line 224 -- so an ai/BACKLOG.md consisting only of this declaration
    # aborted the whole of setup.sh with exit 1, silently, two thirds of the way through.
    # Found by testing the edge case rather than the happy path; the happy path was green.
    # Filtering everything out is a legitimate result and an empty file is the right answer.
    grep -vE '^<!--[[:space:]]*scaffold:session-log[[:space:]]' ai/BACKLOG.md > "$_tmp_backlog" || true
    # `cat >` NOT `mv` (#308). mktemp creates 0600 and mv carries that mode onto the
    # target, so every fresh adoption ended with ai/BACKLOG.md at 600 while every sibling
    # in ai/ stayed 644. The strip was correct; the mode was not. On a headless Linux box
    # where the user running setup.sh is not the user CI runs as, that one file is
    # unreadable and the fix reads as though it never landed. The scaffold:no-artifact
    # block above already uses cat for exactly this reason -- same operation, written the
    # other way, and only one of the two was right.
    cat "$_tmp_backlog" > ai/BACKLOG.md
    rm -f "$_tmp_backlog"
    echo ""
    echo "[OK] removed the inherited scaffold:session-log declaration from ai/BACKLOG.md."
    echo "     It named the SOURCE repository's -dev sibling ($_sl_target), which does not"
    echo "     exist here. Unset, the session record resolves to ai/SESSION.md — yours."
  fi
  unset _sl_target
fi

if [ -n "$_scaffold_own" ]; then
  echo ""
  echo "[OK] removed the scaffold repository's own files — this is your project now:"
  for _f in $_scaffold_own; do echo "       $_f"; done
  echo "     They are not yours to carry: OVERVIEW.md documents the scaffold as a product,"
  echo "     mirror-sync.yml pushes to OUR downstream mirror, CODEOWNERS reads '* @Robiton',"
  echo "     and overlays/ has already been applied above. Keeping the first three would also"
  echo "     make every tool in tools/ treat your project as the scaffold itself, and gates"
  echo "     that police THIS repository would fail your first real commit."
fi

echo ""
echo "================================="
echo " Verifying setup"
echo "================================="
if ! run_checks; then
  echo ""
  echo "ERROR: setup finished but verification found failures — fix them before starting work."
  exit 1
fi

echo ""
echo "================================="
echo " Setup complete"
echo "================================="
echo ""
echo "Next steps:"
echo "  1. Fill in ai/MEMORY.md with your project overview"
echo "  2. Fill in ai/TEAM.md with the full team roster"
echo "  3. Add initial tasks to ai/BACKLOG.md"
echo "  4. Open your AI tool and send this as your first message:"
echo ""
echo '     "Read ai/STANDARDS.md and load all files in the order'
echo '      it specifies before we begin any work."'
echo ""
echo "  5. Commit everything:"
echo "     git add . && git commit -m \"chore(scaffold): initialize v$FULL_VERSION\""
echo ""

# If the project keeps the optional local-coder workflow, verify it now rather than
# leaving the developer to discover at first use that Ollama is not running, the model
# is not pulled, or the formatter is missing. Installing without verifying leaves people
# believing they are configured. Advisory only — a --doctor failure must not fail setup,
# because the local-coder workflow is optional and the rest of the scaffold is fine.
# THE SCAFFOLD NO LONGER SHIPS localcoder (W-15, DEC-20), so there is nothing here to run.
# What it still ships is the INTEGRATION POINT: ai/localcoder.config.json, the marked prompt
# region and the markers. The presence of that config is a project SAYING it intends to
# delegate, which is exactly the moment to say what to install — DEC-21 keeps the file for
# that reason.
#
# This is where the shim would have gone and did not. A ~50-line executable that resolves
# and execs the real tool buys a better error message and costs a permanent compatibility
# surface in the repository this separation exists to keep clean. The sentence is cheaper
# and lands in the same place.
if [ -f ai/localcoder.config.json ]; then
  echo "================================="
  echo " Local-coder integration (optional)"
  echo "================================="
  echo ""
  # `command -v` SUCCEEDING IS NOT "THE PRODUCT IS INSTALLED", and ai/STANDARDS.md says so
  # in as many words — *probe by running the binary, not by `command -v`* — a rule this
  # block was breaking while shipping the file that states it.
  #
  # THE PRE-SPLIT COPY ANSWERS TO THE SAME NAME. Until W-15 the scaffold vendored the tool
  # and tools/README.md told you to `install -m 0755 tools/localcoder ~/bin/localcoder`.
  # Anyone who followed that has a `localcoder` on PATH forever: `command -v` finds it, the
  # scaffold says "installed", and it is the pre-split vendored implementation. The upgrader
  # has no deletion mechanism (A7), so nothing has ever taken it away.
  #
  # MEASURED ON THIS PROJECT'S OWN DEVELOPMENT MACHINE, 2026-08-12: `localcoder` resolved to
  # ~/bin/localcoder at 0.8.0.20260805.1600, header `Project: ai-project-scaffold`, against a
  # product at 0.31.2 released as 0.21.0 — thirteen minors of drift. `uv tool list` showed
  # localcoder was not installed at all, and none of the three console scripts existed. Every
  # draft and every measurement taken there had gone to the old binary, and nothing said so.
  #
  # The HEADER is the evidence, not the version: a copy whose `Project:` is the scaffold came
  # from the scaffold, whatever it is stamped. Read, never executed — running an unknown
  # binary to identify it is not something a setup script should do.
  _lc_path="$(command -v localcoder 2>/dev/null || true)"
  _lc_vendored=0
  if [ -n "$_lc_path" ] && [ -r "$_lc_path" ]; then
    head -8 "$_lc_path" 2>/dev/null \
      | grep -qE '^#[[:space:]]*Project:[[:space:]]*ai-project-scaffold[[:space:]]*$' \
      && _lc_vendored=1
  fi
  if [ "$_lc_vendored" = "1" ]; then
    echo "  [!] The localcoder on your PATH is the PRE-SPLIT VENDORED COPY, not the product."
    echo ""
    echo "        $_lc_path"
    echo "        $(head -8 "$_lc_path" 2>/dev/null | grep -m1 -E '^#[[:space:]]*Version:' || echo '# Version: unknown')"
    echo ""
    echo "      It came from tools/localcoder, which the scaffold stopped shipping in W-15."    # scaffold:path-not-an-instruction
    echo "      Nothing removed it, so it still answers to the name and every draft you take"
    echo "      goes to it. Replace it with the product:"
    echo ""
    echo "          rm $_lc_path"
    echo "          uv tool install git+https://github.com/Robiton/localcoder"
    echo "          localcoder --doctor"
    echo ""
    echo "      Measurements taken against the old copy are not comparable with anyone else's."
  elif [ -n "$_lc_path" ]; then
    echo "  localcoder is installed. Verify the whole chain — Ollama reachable, model"
    echo "  pulled, digest matching, formatters present — with:"
    echo ""
    echo "      localcoder --doctor"
    echo ""
    echo "  It is a separate product and it reports its own problems; this scaffold does"
    echo "  not run it and does not depend on it."
  else
    echo "  This project is CONFIGURED to delegate — ai/localcoder.config.json is present —"
    echo "  and localcoder is not installed on this machine."
    echo ""
    echo "      uv tool install localcoder        # then: localcoder --doctor"
    echo ""
    echo "  Nothing here is broken without it. The scaffold works with no local model, and"
    echo "  every gate above passed. Delete ai/localcoder.config.json to opt out."
  fi
  echo ""
fi
