#!/usr/bin/env bash
# Project:  ai-project-scaffold
# File:     tools/scaffold_upgrade.sh
# Modified: 2026-10-13
# Version:  0.26.3.20261013.0405
# Purpose:  Upgrade an adopting project from the scaffold release it is on to a newer one.
# Changelog:
#   2026-10-13 v0.26.3.20261013.0405 — local edit in a public adopter: work mirror account no longer named; mirror comes from SCAFFOLD_UPSTREAM_MIRROR (scaffold issue #387).
#   2026-10-10 v0.26.2.20261010.1205 — the new tree is checked against its release's SHA256SUMS before anything is written, and a release with none is named UNVERIFIED (report item 15). The release-to-newest-tag fallback fires only where the upstream has no releases at all, the release tag passes through newest_tag, and a declared upstream that is not owner/repo stops the upgrade. Selftest: units for the manifest and the name check, and a gh-path end to end through a fake gh; each half proven red by mutation.
#   2026-10-07 v0.26.1.20261007.0658 — THE PROBE READS THE ANSWER, NOT THAT THERE WAS ONE. gh api prints its 404 body to STDOUT
#                        even with --jq, so a work machine that cannot see Robiton got non-empty output for it and
#                        picked it, and 0.111.15's mirror support never engaged. The tag picker then took a version out
#                        of that error JSON and cached it. Found end-to-end as the work account, after release; the
#                        selftest's fake gh printed nothing on failure, which no real gh does. It now prints the 404.
#   2026-10-07 v0.26.0.20261007.0347 — upgrades from wherever this project got the scaffold. Work adopters read the the work mirror account mirror, which has every tag and no GitHub releases and is often the only copy their machine can see; this always asked Robiton for its latest release and died there. Source order: SCAFFOLD_UPSTREAM, then .scaffold-upstream, then the first of Robiton and the mirror this machine can read. With no release, the newest tag is the target. The tag list is paginated: 201 tags upstream, and the first page of 30 could not find the base for an older adoption.
#   2026-09-29 v0.25.5.20260929.1446 — the vendored localcoder files are retired on upgrade. tools/RETIRED.tsv gains the 14 files the scaffold shipped before localcoder became its own product (0.36.0), each with every sha it shipped with. A row whose note begins `localcoder:` is skipped in the repository declaring scaffold:owns-localcoder, where it is the product: localcoder's apple-m3-max.md still matches a shipped sha. ai/eval_tasks.py stays, because the installed localcoder reads it.
#   2026-09-23 v0.25.4.20260923.0941 — fixtures run inside the root tools/fixture_guard.sh validates. There a git and a mktemp on PATH refuse anything that would land outside it. Every mktemp takes a ${TMPDIR} template, because macOS mktemp ignores TMPDIR without one. The selftest runs from a temp copy, so SCAFFOLD_UPGRADE_TOOLS carries the real tools directory across the re-exec to find fixture_guard.sh. The upgrade path's EXIT trap was left as it was: fg_cleanup exists only in the selftest.
#   2026-09-23 v0.25.3.20260923.0843 — every mktemp fails closed. A failed one left the temp variable empty, so the fixture ran in the caller's directory; header_check's committed into Robiton/control.
#   2026-09-23 v0.25.2.20260923.0219 — a workflow that differs from its baseline ONLY in `uses:`
#                                      pins takes the incoming copy. A Dependabot bump is not
#                                      an edit; keeping it cut health-app and collectionapp
#                                      off from every later scaffold-check.yml change.
#   2026-09-22 v0.25.1.20260922.1700 — a kept workflow's unpinned uses: are named with the
#                                      incoming pin, before workflow_audit meets them at the
#                                      next preflight (Clocktower #5)
#   2026-09-14 v0.25.0.20260914.1011 — refresh a declared status block after upgrading; this tool is what staled it.
#   2026-09-13 v0.24.3.20260913.0815 — three selftest assertions piped into `grep -q` under pipefail (#306).
#                        grep -q exits at the first match, printf takes SIGPIPE, the pipeline
#                        reports 141, and the assertion fails BECAUSE the string was found.
#                        The line directly above them already used `grep -c` for this exact
#                        reason. Same defect, same file, four lines apart. 0/15 runs fail now.
#   2026-09-08 v0.24.2.20260908.0528 — adopt.ps1 joins PRODUCT_FILES, so a Windows adopter's copy
#                        is refreshed on upgrade rather than frozen at whatever version
#                        they first copied.
#   2026-09-06 v0.24.1.20260906.0600 — The fifth site cited #306, a number that was never filed. Now
#                        points at #303, which exists and tracks the residual: an adoption
#                        that never upgrades keeps the instruction and the scaffold has no
#                        reach into it. Two sites, not one -- the changelog and the function.
#   2026-09-04 v0.24.0.20260904.0928 — mig_agents_symlink_instruction — THE FIFTH SITE, and the only one that
#                        cannot be closed from this repository (#303). <=v0.3.0 shipped an
#                        AGENTS.md telling the reader `ln -s AGENTS.md CLAUDE.md`. AGENTS.md is
#                        a MERGE file, so that paragraph survives every upgrade indefinitely —
#                        mig_claude_gitignore repairs the artefact and leaves the instruction
#                        that recreates it. An adopter who upgrades and then follows their own
#                        AGENTS.md walks straight back into the truncation. Surgical: only the
#                        two unambiguous <=v0.3.0 lines are rewritten, prose is untouched, and
#                        AGENTS.md.scaffold-backup is kept.
#   2026-09-04 v0.23.2.20260904.0558 — .gitleaks.toml joins PRODUCT_FILES (#300) — the allowlist that makes
#                        the shipped secret scanner usable never shipped with it.
#   2026-09-04 v0.23.1.20260904.0243 — .github/CONTRIBUTING.md JOINS MERGE_FILES (#298). It sidecarred on three
#                        consecutive upgrades in localcoder with an identical diff — three
#                        release-checklist rows that repo legitimately owns. The mechanism was
#                        working; it was just asking the same question every release and
#                        getting the same answer. A checklist both sides extend is what a
#                        three-way merge is for. Same move AGENTS.md made, same reason.
#   2026-09-03 v0.23.0.20260903.1906 — .claude/ AND .agents/ ARE DELIVERED ON UPGRADE (#291). Neither directory was
#                       touched by an upgrade at all, so every hook fix this project has
#                       shipped — the PreCompact hook, the --wire fix, the un-silencing of the
#                       session hook, all of 0.88.x — reached exactly ZERO adopters through an
#                       upgrade. Found by tools/adoption_manifest.sh --check, which is the
#                       first thing to compare what an adoption RECEIVES against what an
#                       upgrade REFRESHES. `.claude/settings.json` is deliberately still not
#                       delivered: it is the adopter's own config. The canonical
#                       settings.hooks.json is, so `setup.sh --check` reports the delta.
#   2026-09-02 v0.22.0.20260902.0517 — ai/OPERATIONS.md JOINS MERGE_FILES (#281). It carries
#                        the reference half of the standards and ai/STANDARDS.md now points at
#                        it eleven times, so shipping one without the other repeats #280
#                        exactly: pointers with no file behind them, invisible to every check
#                        that reads only the upstream tree. Merged rather than force-installed
#                        for the same reason as STANDARDS_EVIDENCE.md -- an adopter will want
#                        to append their own operational notes.
#   2026-09-01 v0.21.2.20260901.1845 — DELIVERED HOOKS ARRIVE EXECUTABLE IN THE INDEX, not
#                        only on the filesystem (#283). `core.fileMode` is false in every
#                        working copy here, so `chmod +x` is invisible to git: the file runs
#                        on the machine that upgraded and is committed 644, and the next
#                        clone gets a hook git silently never runs.
#                        MEASURED: 0.84.0 delivered the three chaining git-lfs hooks to
#                        Robiton/localcoder and mode_scan.sh reported all three [DEAD] on the
#                        first preflight after the upgrade. `git update-index --chmod=+x`
#                        now runs beside the chmod.
#                        THE FIXTURE MISSED IT BECAUSE IT ASSERTED THE WRONG PROPERTY -- the
#                        filesystem bit, when the thing that ships is the index bit. The
#                        matching case now reads `git ls-files -s`. Same class as most of
#                        what this file has ever caught: a check measuring the correlate.
#   2026-09-01 v0.21.1.20260901.1751 — ai/STANDARDS_EVIDENCE.md JOINS MERGE_FILES (#280).
#                        0.84.0 moved the story behind eighteen rules out of ai/STANDARDS.md
#                        and left the pointers in. The new file was on no delivery list, so
#                        the first adopter upgraded to nineteen dangling cross-references and
#                        no file behind them. Caught by upgrading Robiton/localcoder, not by
#                        a fixture: a file that ships to nobody is invisible to every check
#                        that reads only the upstream tree.
#                        MERGED, NOT FORCE-INSTALLED. It is upstream reference material an
#                        adopter will want to append their own evidence to, which is exactly
#                        what the three-way merge is for.
#   2026-09-01 v0.21.0.20260901.1656 — SHIPS THE THREE CHAINING git-lfs HOOKS (#274), and
#                        stops swallowing two verdicts (#277).
#                        core.hooksPath is EXCLUSIVE: setting it disables .git/hooks
#                        entirely, and git-lfs installs post-checkout, post-commit and
#                        post-merge there and announces none of them. Upstreamed from
#                        Robiton/godsfall#146, where that repository had already paid the
#                        bill once -- 377 broken pointer files across every clone. They CHAIN
#                        rather than copy, so git-lfs keeps one implementation, and they are
#                        on PRODUCT_FILES so an adopter receives them without being asked.
#                        The fixture asserts all three arrive EXECUTABLE: core.fileMode is
#                        false in these working copies, and a 644 hook is one git silently
#                        never runs.
#                        A FAILING skills_check PRINTED NOTHING AT ALL. The `&&` chain meant
#                        in-sync said so and out-of-sync said nothing -- indistinguishable
#                        from the tool being absent, the exact pair this package refuses to
#                        conflate everywhere else. And header_check's "reported problems --
#                        run it" now prints what it found, on the one branch that has it.
#   2026-08-31 v0.20.1.20260831.1416 — ONE SHA PER PATH WAS WRONG (#255), and the message that went with it
#                        made a claim about the adopter that was not true. A retired file
#                        changes over its shipped life; recording only the LAST revision told
#                        every adopter on an earlier one that they had EDITED it -- and the
#                        adopters most likely to be on an older revision are the ones who
#                        carried the file longest, which is the backlog the manifest exists to
#                        clear. Measured: install_ollama_service.sh shipped in FOUR revisions.
#                        Now: every shipped sha, any may match.
#                        AND THE WORDING. Manifest removals cited "$FROM_TAG", a baseline that
#                        by definition never held the file, and the kept message said the
#                        adopter had edited it. Someone who knows they did not was left
#                        working out which half of the sentence was wrong. Manifest removals
#                        now explain themselves by what the scaffold shipped, and a kept file
#                        is described without any claim about what its owner did.
#   2026-08-31 v0.20.0.20260831.1327 — TWO DEFECTS FROM ONE ADOPTER, BOTH IN CODE SHIPPED HOURS EARLIER.
#                        #254 SECURITY: a comment after a line continuation ended the command,
#                        so `env` ran with NO COMMAND and printed the whole environment -- any
#                        ANTHROPIC_API_KEY, GITHUB_TOKEN or AWS_* in it, into a log that
#                        outlives the run, from a repo that ships secret_scan.sh. The same
#                        typo silently dropped the two variables the handover exists to pass.
#                        #253: the BASE-vs-NEW diff added in 0.19.2 is blind by construction to
#                        anything retired BEFORE the adopter's baseline -- it is in neither
#                        tree, so it reads as adopter-added. Measured: the two files that
#                        MOTIVATED that fix survived a real 0.38.3 -> 0.82.2 upgrade.
#                        tools/RETIRED.tsv now carries path + sha256-as-last-shipped, so
#                        removal is safe without a tree to compare against. And the dry run
#                        previews it: a removal nobody can preview is one nobody can refuse.
#   2026-08-31 v0.19.2.20260831.0904 — #252 files upstream RETIRED were never removed -- 0.38->0.82 left two behind. The baseline is
#                        the discriminator; an edited retired file is kept and named, never deleted.
#   2026-08-30 v0.19.1.20260830.0927 — THE EXCLUSION GUARD HAD SILENTLY STOPPED EXCLUDING, and said so
#                        100+ times per upgrade in a message nobody connected to it.
#                        OWNS_LOCALCODER_PATHS was emptied deliberately months ago; the line
#                        appending it to PRODUCT_PATH_EXCLUDE was not removed with it, leaving
#                        a TRAILING EMPTY ALTERNATIVE. macOS /usr/bin/grep (BSD 2.6.0-FreeBSD)
#                        exits 2 on that, so `grep -qE "$re" && return 0` never fired.
#                        Harmless ONLY BY ACCIDENT: copy_product returns earlier for paths
#                        absent from the new release, and the scaffold ships nothing under
#                        docs/benchmarks/ today. The day it does, the guard written to protect
#                        an adopter's file would have replaced it instead.
#                        Now: an `if` guarding the append (not `&&`, which is the shape that
#                        aborted setup.sh under set -e in v0.22.0); exclude_regex_sane() as a
#                        shared function; and a RUNTIME guard that dies naming the bad value,
#                        because assembling a regex and never checking it is the actual defect.
#                        5 selftest cases, both directions, mutation-verified.
#   2026-08-22 v0.19.0 — THE CLOSING INSTRUCTION COMMITTED THE SIDECAR IT HAD JUST WRITTEN
#                        (#239). This script ended by printing `git add -A && git commit`,
#                        which stages the unreconciled `.scaffold-<version>` copies left when
#                        a product file could not be overwritten -- and tools/conflict_scan.sh
#                        then fails the NEXT preflight on them, two gates away from the line
#                        that caused it. Reproduced 2026-08-21 upgrading Robiton/localcoder
#                        0.73.0 -> 0.74.0, which kept .github/CONTRIBUTING.md.
#                        With sidecars outstanding the closing text now withholds the
#                        one-liner, names each sidecar with its diff and `git rm`, and offers
#                        a `-- ':!*.scaffold-*'` pathspec for committing the rest first. With
#                        none, the message is unchanged.
#                        Four selftest cases, mutation-verified: widening the `kept` guard
#                        fails all four.
#   2026-08-12 v0.18.0 — THE BARE-RUN SELFTEST WAS UPGRADING THE HOST REPOSITORY. It ran
#                        `cd "$ROOT" && bash "$SELF"` with no arguments, on the reasoning
#                        that a bare run "will exit non-zero for want of a network or a base
#                        tag". TRUE HERE, FALSE IN AN ADOPTION: an adopter has a valid
#                        .scaffold-version, a network and gh, so it SUCCEEDED and performed a
#                        real upgrade — PRODUCT files replaced, sidecars written, exit 0.
#                        preflight.sh runs every selftest, so an adopter running the gate they
#                        are told to run before every push had their tree upgraded as a side
#                        effect of CHECKING it. Measured in Robiton/localcoder: preflight
#                        rewrote tools/preflight.sh mid-run. Now runs in a disposable empty
#                        git repo, which stops in the prologue by construction everywhere.
#   2026-08-11 v0.17.0 — THE FIXTURE NOW RUNS THE BARE INVOCATION. Asked for by the adopter
#                        who found the 3.2 bug, and correctly: the zero-argument run is the
#                        DEFAULT and the one the docs prescribe, while every other case
#                        here passes --from and --to so it can work offline. So the bug
#                        lived in the only path nothing exercised.
#                        The case asserts one thing — no unbound-variable abort — and
#                        tolerates any exit code, because a bare run legitimately fails for
#                        want of a network. It guards THE WHOLE PRE-HANDOVER PROLOGUE, not
#                        the single line that broke, because that region is effectively
#                        un-upgradable for an existing adopter: a fix to it can only arrive
#                        through the release they are already on, so it earns a different
#                        standard of care. Verified to fail by reinstating the defect.
#   2026-08-11 v0.16.0 — THE HANDOVER ABORTED ON macOS FOR A BARE RUN. RELEASE-BLOCKING.
#                        macOS ships bash 3.2.57, where an EMPTY array expanded as
#                        "${a[@]}" under `set -u` is treated as UNBOUND and aborts — fixed
#                        upstream in bash 4.4, which no Mac has. `_ORIG_ARGS=("$@")` is
#                        empty on a bare `tools/scaffold_upgrade.sh`, so line 1171 died
#                        before the handover could exec anything.
#                        THE ASYMMETRY IS THE DEFECT. `--dry-run` is one argument, so the
#                        array is non-empty and the dry run passes CLEANLY. The bare run —
#                        the only one that writes — is the only one that fails. Dry-run
#                        green, real run dead, on every macOS adopter.
#                        And the hand-over design cannot rescue it: this line IS the
#                        handover, so it aborts in the OUTGOING copy and the fixed copy
#                        never executes. A fix reaches an adopter only through the release
#                        they are already on, which is why this is a patch release.
#                        WHY THE FIXTURE COULD NOT FIND IT: every selftest case passes
#                        --from and --to so it can run offline against a synthetic
#                        upstream, so _ORIG_ARGS is never empty here. Found on a real M3
#                        adoption at 0.34.0. The new cases therefore have a different shape
#                        — they assert the EXPANSION under the real 3.2 binary and grep the
#                        source, rather than running an upgrade.
#                        The grep guard needed two false positives removed first: the naive
#                        pattern matched the explanatory COMMENTS and the guarded form
#                        itself, since `${a[@]+"${a[@]}"}` contains `"${a[@]}"` as a
#                        substring. A guard that flags its own fix is worse than none.
#   2026-08-11 v0.15.0 — DELIVERS .githooks/pre-push, AND REPAIRS ITS MODE ON ARRIVAL
#                        (#171). Shipping the file is the whole point: .git/hooks is not
#                        versioned and does not come with a clone, so a hook nobody can
#                        receive is a rule enforced on whoever happened to install it.
#                        Nothing here ACTIVATES it — that is `setup.sh --install-hooks`, by
#                        hand, per machine. An upgrade that silently started gating pushes
#                        would be the guard ai/SECURITY.md warns about.
#                        THE MODE REPAIR IS NOT BELT-AND-BRACES. `cp` carries the source
#                        mode, so a 755 upstream needs no help — but measured on this
#                        project's own machine, `core.fileMode` is false (OneDrive working
#                        copy) and `chmod +x` is therefore INVISIBLE to git: the hook was
#                        committed 100644 and took `git update-index --chmod=+x` to record.
#                        A maintainer on such a machine ships an inert hook to every
#                        adopter and gets no warning, because git ignores a non-executable
#                        hook SILENTLY. The selftest fixture ships 644 on purpose so the
#                        repair is load-bearing rather than decorative — verified to fail
#                        without it. `tools/localcoder` left the chmod arm; it went in W-15.
#   2026-08-11 v0.13.0 — DUAL_HOMED_GOVERNANCE: dual-homed and force-installed is a
#                        MECHANISM, not a leak (#D-19). localcoder_sync.py joined DUAL_HOMED
#                        and the "every DUAL_HOMED tools/ path is owned-excluded" assertion
#                        failed it, correctly by its own terms and wrongly on the merits.
#                        That assertion exists for PRODUCT files: #115, where vendoring a
#                        second copy of localcoder into the repo that ships it made the drift
#                        check silently move onto the vendored file. localcoder_sync.py is
#                        this governance layer, not product — localcoder runs it the way it
#                        runs preflight.sh — and force-installing it is exactly what has kept
#                        the two copies byte-identical with nobody syncing them by hand.
#                        Listed as an explicit exception rather than loosening the check, and
#                        verified by injection: a PRODUCT file added to DUAL_HOMED and
#                        forgotten here still fails, which is the api_digest.py case the
#                        assertion was written for.
#   2026-08-09 v0.12.1 — The verify step names the failing lines (#182). It discarded the
#                        output and said 'setup.sh --check reported problems — run it',
#                        which sent an adopter to the first [!] they saw: advisory, exit
#                        0, and not the cause. Saying something is wrong without saying
#                        what makes the reader pick a suspect.
#   2026-08-09 v0.12.0 — THE NEWER UPGRADER DOES THE WORK (#179). A fix to this tool could
#                        not fix the upgrade that installs it: the copy doing the work is
#                        the one VENDORED IN THE ADOPTER, i.e. the release being left. So
#                        every defect here was repaired one upgrade late, by the broken
#                        version. Measured, three times, on one project: .gitattributes
#                        became union-merged in 0.12.0 and an 0.11.3 -> 0.24.0 upgrade still
#                        deleted 24 Git LFS patterns, because 0.11.3's copy did the
#                        replacing. The fix was correct, shipped, and could not run.
#                        Before anything is written, if the target release carries a newer
#                        scaffold_upgrade.sh, the whole run is handed to it — the same code
#                        that is about to be installed either way.
#                        HONEST LIMIT: this cannot help an adopter whose vendored copy
#                        predates it. Reproduced in a fixture — 0.11.3 -> a release carrying
#                        the handover still lost 2 of 2 LFS patterns. Anyone on <=0.11.x
#                        must fetch this file before upgrading; setup.sh and the release
#                        notes say so.
#                        Arguments are saved before the parse loop shifts them, because a
#                        handover that silently drops --dry-run is the one failure with no
#                        undo. The injection that drops them fails 22 checks, not one.
#                        The conflict-marker case is anchored at column 0, matching what
#                        conflict_scan.sh actually treats as a conflict — the fixture now
#                        installs a real upgrader, which necessarily contains the string it
#                        greps for.
#   2026-08-09 v0.11.0 — OWNS_LOCALCODER_PATHS gains tools/api_digest.py, and a check that
#                        it and localcoder_sync.py's DUAL_HOMED stay in agreement. The file
#                        was added to DUAL_HOMED this morning and not here, so the next real
#                        upgrade of Robiton/localcoder vendored tools/api_digest.py into the
#                        repo that ships it as src/localcoder/api_digest.py. Nothing failed:
#                        the drift check still resolved the product copy first, so it was
#                        visible only in `git status`.
#                        THE CHECK ITSELF SHIPPED BROKEN TWICE and both were caught by
#                        injection, not by reading. Its sed required `("` before `tools/`
#                        where DUAL_HOMED has `, `, so it extracted nothing and passed. Then
#                        it looked beside $BASH_SOURCE — but this script copies itself to
#                        $TMPDIR and re-execs, so it searched /tmp, found nothing, and took
#                        an else branch that reported OK. A check aimed away from the risk
#                        reads as coverage; a skip is not a pass. Both branches now fail.
#   2026-08-08 v0.10.0 — `.scaffold-<version>` sidecars no longer accumulate. A divergence
#                        is usually permanent, so writing one per release grew without
#                        bound: measured in Robiton/localcoder, 21 committed sidecars —
#                        3 files across 7 releases — for three decisions each made once,
#                        and its divergence is deliberate and forever (its docs name the
#                        command it installs on PATH). Now: one per file, the newest, and
#                        none at all once the divergence is resolved. Safe to delete
#                        because a sidecar is OUR released bytes, never adopter work —
#                        `git show <tag>:<path>` reproduces any of them.
#   2026-08-08 v0.9.0 — Warn when core.fileMode=false will record a force-installed tool
#                        NON-EXECUTABLE. Measured on the 0.15.0 upgrade: both consumers
#                        recorded tools/conflict_scan.sh at 644 though it arrived 755,
#                        and every discovery loop filters on [ -x ] — its 15 cases would
#                        have been skipped in silence in both repos. Advice, not an
#                        action: this command deliberately leaves the index alone so
#                        `git checkout .` stays a complete undo, and --chmod needs a
#                        staged path. Extracted as a function so it has a selftest.
#   2026-08-08 v0.8.2 — Point the conflict summary at tools/conflict_scan.sh. The exit 1
#                        and the paragraph above it were the whole mechanism for thirteen
#                        releases, and a non-zero exit at merge time says nothing about
#                        the commit that follows: this repo's own dev context committed
#                        the markers 0.14.0 wrote into ai/STANDARDS.md and stayed green.
#   2026-08-08 v0.8.1 — The refusal's re-fetch command is `gh api`, not a curl to
#                        raw.githubusercontent (#136). The upstream repo is PRIVATE, so
#                        that URL 404s for everyone — and `curl -sS -o` writes the 404 body
#                        into the target, so the one command that rescues a stranded repo
#                        instead left a "script" whose first line was `404: Not Found`.
#                        The path is QUOTED because zsh globs `?`.
#   2026-08-08 v0.8.0 — A product-owned file is not automatically ours to replace (#125).
#                        .gitattributes was on PRODUCT_FILES and holds adopters' Git LFS
#                        patterns; every upgrade deleted them, exit 0, under a heading
#                        reading "no adopter content by construction". Twice in one repo,
#                        693 binaries into history as raw blobs the first time, and silent
#                        because LFS stops applying rather than erroring. It is union-merged
#                        now, keyed on the PATTERN not the whole line — last match wins in
#                        that file, so appending ours below an adopter's deliberate
#                        `-merge` would have overturned it.
#                        The classification was never the real instrument: "no adopter
#                        content" is a PREDICTION, and it was wrong twice from one cause —
#                        AGENTS.md was caught pre-release only because a checker pointed at
#                        it, .gitattributes went four months because none did. So every
#                        remaining product file is now compared against the copy it SHIPPED
#                        as ($BASE, already fetched for the three-way merges): identical
#                        means untouched and safe to replace, different means someone edited
#                        it and the incoming version goes to <file>.scaffold-<TO> instead.
#                        Found by that rule on this machine: Robiton/localcoder's
#                        scaffold-check.yml scans src/localcoder/* as well as tools/*,
#                        because scanning only tools/ left THE PRODUCT unchecked by its own
#                        CI — a fix that lived in a product-owned file and would have been
#                        reverted, silently, with CI still green.
#                        tools/ is EXEMPT and stays force-installed: the ceilings live in
#                        ai/STANDARDS.md precisely because tools/ is overwritten, and
#                        honouring edits there is how a project quietly forks its tooling.
#                        The fixture had NO product-owned files at all, which is why 23
#                        checks passed over this for four months — copy_product() returns
#                        early when the release does not ship the path. Three are shipped
#                        in it now; 4 of the 7 new checks fail against the old code and 3
#                        are controls that pass against both.
#                        Also (#130): the scaffold's-own-repo refusal now NAMES the version
#                        that refused and the re-fetch command. That message reads as
#                        "nothing to do", and an older copy of this file emitted the same
#                        sentence for any repo carrying mirror-sync.yml — Robiton/localcoder
#                        believed it and sat 13 releases behind. The fix for that check
#                        ships inside this file, so a stale copy cannot deliver its own
#                        replacement; the only exit is a human re-fetching it, and nobody
#                        re-fetches a tool that reports success.
#   2026-08-07 v0.7.1 — The banner catches BOLD rule lead-ins, not only headings, and never
#                        truncates a section heading. These files state most rules as **bold
#                        paragraphs**, so matching `^#` alone covered the rarer form and
#                        missed the common one — proven on the very next real upgrade, where
#                        0.11.0 -> 0.11.2 delivered the scaffold:owns-localcoder rule as a
#                        bold lead-in and printed no banner at all. Adding bold then took a
#                        real 0.5.0 -> 0.5.4 from 7 named rules to 18 and the old 14-line cap
#                        pushed "No secrets in prompts or agent memory" — the rule the banner
#                        exists for — into "and 4 more", so headings now print in full and
#                        only bold lead-ins are capped.
#   2026-08-06 v0.7.0 — Name the agent-visible rules an upgrade delivers, do not count them
#                        (#118). AGENTS.md and the four ai/ standards are merged into every
#                        adopter AND loaded into every agent session, so a merge here changes
#                        what their agents DO — and the only signal was a line count.
#                        Measured on the real 0.5.0 -> 0.5.4 transition: an adopter was told
#                        "ai/SECURITY.md clean (+79 upstream lines)" while the merge delivered
#                        "No secrets in prompts or agent memory", and the next thing to
#                        mention it was his own agent refusing a commit he had made for
#                        months. This class has no failing build to read, so the upgrade is
#                        the only place it can be surfaced at all.
#   2026-08-06 v0.6.0 — scaffold:owns-localcoder (#115). tools/ is force-installed, so the
#                        repo that SHIPS localcoder was about to receive a vendored copy of
#                        its own product — and localcoder_sync.py resolves tools/localcoder
#                        FIRST, so the drift check would have moved onto the duplicate and
#                        stopped watching src/localcoder/localcoder, passing throughout.
#                        audit_localcoder.sh resolves a tools/ path too. Eight files are
#                        suppressed under the marker, including .localcoder-sync, which
#                        records this repo own path and stamp. Announced on screen, because
#                        an invisible exclusion is indistinguishable from a bug. Three
#                        selftest cases including the without-marker direction, since an
#                        exclusion that over-fires silently stops vendoring for everyone.
#   2026-08-06 v0.5.0 — The scaffold-own-repo check needs ALL THREE signals, not just
#                        mirror-sync.yml (#113). That comment claimed the marker "exists
#                        only in the scaffold s own repo"; Robiton/localcoder mirrors too,
#                        so this REFUSED to upgrade it and stranded it five releases behind
#                        in silence — the message is confident and wrong, so it reads as
#                        "nothing to do". overlays/ alone is no better: setup.sh does not
#                        delete it, so a template clone keeps it and is a real adoption.
#                        Two selftest cases, both directions; 23 checks had never asked what
#                        "the scaffold s own repository" means.
#   (header said 0.4.0 while this entry read 0.4.1 — pre-existing, corrected forward 2026-08-06)
#   2026-08-05 v0.4.1 — Never carry eval data or a BASELINE into an adopter. A baseline is
#                        a regression gate keyed to one machine's models; inherited, it
#                        fails builds over a comparison nobody made.
#   2026-08-05 v0.4.0 — Surface a file-header shortfall as a MIGRATION with a named remedy,
#                        not as a red build after the upgrade. Reported from a real 0.5.0 ->
#                        0.6.3 upgrade (#76): the upgrade was flawless, then CI failed 33
#                        pre-existing files and the PR could not merge.
#   2026-08-05 v0.3.2 — Never carry benchmark DATA into an adopter. docs/ is refreshed, and
#                        "refresh" means "update files that already exist" — so an adopter
#                        who had run a benchmark would have had their own measurements
#                        overwritten by the maintainer's. The runbook still refreshes; only
#                        the data and the reference rows are excluded.
#   2026-08-05 v0.3.1 — `mktemp -t NAME` is BSD-only; GNU mktemp needs X's in the template.
#                        The tool had never run on Linux, and the failure was in the re-exec
#                        so nothing else could report it. Found by CI, which is the only
#                        Linux in the loop — not by any of my macOS runs.
#   2026-08-05 v0.3.0 — `--selftest`: 23 end-to-end checks against a synthetic upstream and
#                        a synthetic adoption, no network. Every defect in this tool so far
#                        was found by running it — four from a hand-built fixture, two from
#                        the first real project it touched — so the fixture is now scripted.
#                        Writing it found one more: a five-line AGENTS.md put the adopter's
#                        filled-in row on the LAST line, so any upstream append was adjacent
#                        and conflicted. The real file is ~90 lines with sections after the
#                        table. A fixture that is merely smaller than the real file is a
#                        different file.
#   2026-08-05 v0.2.0 — Fall back to the newest release at or below the recorded version
#                        when .scaffold-version names something that was never tagged.
#                        Found on the FIRST real use: build stamps advance every PR while
#                        tags exist only at releases, so every project tracking main — the
#                        state scaffold_version.sh reports as fine — could not use this
#                        command at all, and the error advised `--from`, which cannot help
#                        because the ref exists nowhere.
#   2026-08-04 v0.1.0 — Initial creation
#
# WHY THIS EXISTS
#   Updating was a documented file-by-file copy, and the four standards files were on the
#   "do not overwrite" list because they hold adopter content — overlay appends, the
#   ceilings marker, local edits. So nobody could take upstream changes to them at all.
#
#   MEASURED 2026-08-04: 430 lines changed across ai/STANDARDS.md, ai/CODING.md,
#   ai/SECURITY.md and ai/PLANNING.md in the four weeks between v0.4.0 and v0.5.2. An
#   adopter following the documented procedure got NONE of it — no agent threat model, no
#   drafting brief, no "work that leaves no trace in git", and a review gate two revisions
#   stale. Their standards freeze on the day they adopt, permanently.
#
#   Demonstrated on this project's own dev repo, which is a normal scaffold adoption: it
#   was three sections behind and still carried the "≈75–85% accurate" framing that its own
#   MEMORY.md records as superseded. The dogfooding repo was running standards it had
#   written the correction for, because nothing ever told it to update.
#
# HOW THE HARD PART IS SOLVED
#   `.scaffold-version` names the release you adopted. That is the missing third input for
#   a real THREE-WAY MERGE, and it is what that file was created for:
#
#       base   = the file as it shipped in YOUR release
#       ours   = your file now (overlay appendix, ceilings, local edits)
#       theirs = the file in the new release
#
#   `git merge-file` then applies upstream changes to regions you never touched, keeps your
#   edits to regions upstream never touched, and marks the genuine collisions rather than
#   guessing. Overlay appendices and the ceilings line survive because you edited them and
#   upstream did not.
#
#   Without `.scaffold-version` there is no base, so a three-way merge is impossible and
#   this script REFUSES to merge rather than overwriting — see the check below.
#
# SAFETY, in the terms ai/SECURITY.md already states
#   The hard line is "never mutate state without a snapshot you have verified is
#   restorable". Here the snapshot is git: this refuses to run on a dirty tree, so
#   `git checkout .` is a verified undo for everything it does. It never writes
#   SESSION/BACKLOG/MEMORY/TEAM/version/CODEOWNERS or any *_ARCHIVE.md — the files that
#   hold what you cannot regenerate.
#
# Usage:
#   tools/scaffold_upgrade.sh --dry-run          # show the plan, change nothing
#   tools/scaffold_upgrade.sh                    # upgrade to the latest release
#   tools/scaffold_upgrade.sh --to 0.5.0.20260731.1600
#   tools/scaffold_upgrade.sh --from ../ai-project-scaffold   # use a local clone
set -uo pipefail

# ---------------------------------------------------------------------------------------
# RE-EXEC FROM A COPY BEFORE TOUCHING ANYTHING.
#
# This script lives in tools/, and the upgrade REPLACES tools/. Bash reads a script
# incrementally as it executes, so overwriting the file mid-run makes it resume at a byte
# offset into different content — a silent, near-undebuggable failure that only fires on
# the runs that matter. Copy to a temp location and hand over before any write happens.
# ---------------------------------------------------------------------------------------
if [ -z "${SCAFFOLD_UPGRADE_REEXEC:-}" ]; then
  # `mktemp -t NAME` is BSD syntax. GNU mktemp REQUIRES X's in the template and exits
  # "too few X's" — so this tool never ran on Linux at all, and because the failure is in
  # the re-exec it happened before anything else could report it. Every test run of mine
  # was on macOS; CI (ubuntu) is the only Linux in the loop and is what caught it. Write
  # the template explicitly, which both implementations accept.
  _self_copy="$(mktemp "${TMPDIR:-/tmp}/scaffold_upgrade.XXXXXX")" || exit 1
  cat "${BASH_SOURCE[0]}" > "$_self_copy"
  chmod +x "$_self_copy"
  # ORIGIN IS THE CURRENT DIRECTORY, NOT THE SCRIPT'S DIRECTORY.
  #
  # Every other tool here resolves its root from `__file__/..`, because they are vendored
  # into the project they act on. Copying that habit here was a real defect, caught by the
  # first fixture run: invoked as `../ai-project-scaffold/tools/scaffold_upgrade.sh` from
  # inside a project, it read the SCAFFOLD's .scaffold-version and would have upgraded the
  # scaffold repo instead of the adopter. For a tool that rewrites standards files, acting
  # on the wrong repository is the worst thing it can do, so it acts on where you ARE.
  # The copy runs from a temp directory, so its own dirname no longer holds the sibling
  # tools. SCAFFOLD_UPGRADE_TOOLS remembers where they are; only the selftest reads it, to
  # find fixture_guard.sh. A nested run keeps the first value, which is the real one.
  SCAFFOLD_UPGRADE_TOOLS="${SCAFFOLD_UPGRADE_TOOLS:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}" \
  SCAFFOLD_UPGRADE_REEXEC=1 SCAFFOLD_UPGRADE_ORIGIN="$(pwd)" \
    bash "$_self_copy" "$@"
  _rc=$?
  rm -f "$_self_copy"
  exit $_rc
fi

ROOT="${SCAFFOLD_UPGRADE_ORIGIN:-$(pwd)}"
cd "$ROOT" || exit 1

# WHERE THIS PROJECT GETS THE SCAFFOLD FROM. Personal repos: Robiton. Work repos: the
# the work mirror account mirror, which mirror-sync.yml keeps identical (main and every tag) but which
# has NO GitHub releases, and is often the only copy a work machine can read.
# Order: SCAFFOLD_UPSTREAM, then `.scaffold-upstream` in the project root (adopter-owned, one
# owner/repo line, # comments allowed), then the first candidate this machine's gh can read.
#
# probe_upstream is still duplicated in tools/scaffold_version.sh (that copy is bounded,
# because it runs in a session hook); everything else is the shared block below.
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
# >>> shared:release-sums
# carried by: tools/scaffold_upgrade.sh tools/context_survival.sh
# ONE BODY, TWO FILES: the two that fetch a release. Not in shared:upstream, because
# scaffold_version.sh pins every gh call it carries to a bound, and it never fetches.
release_sums() {  # release_sums <owner/repo> <tag> <out> -> 0 fetched, 1 this release has none
  # The the work mirror account mirror has tags and no releases (a deploy key cannot create one), so
  # there is nothing to fetch there, and releases cut before 0.111.21 carry no SHA256SUMS.
  # Both are "unverified", which the caller reports; neither is a mismatch.
  command -v gh >/dev/null 2>&1 || return 1
  rm -f "$3"
  gh release download "$2" --repo "$1" --pattern SHA256SUMS --output "$3" >/dev/null 2>&1 \
    && [ -s "$3" ] && return 0
  rm -f "$3"
  return 1
}
# <<< shared:release-sums
probe_upstream() {  # stdout: the first candidate this machine can read, else the default
  local _c
  if command -v gh >/dev/null 2>&1; then
    for _c in "$UPSTREAM_DEFAULT" ${UPSTREAM_MIRROR:+"$UPSTREAM_MIRROR"}; do
      # COMPARE THE ANSWER: gh prints a 404 body to stdout, so "non-empty" picked a repo
      # this machine cannot see. Same fix as scaffold_version.sh.
      if [ "$(gh api "repos/$_c" --jq .full_name 2>/dev/null | tr '[:upper:]' '[:lower:]' || true)" \
           = "$(printf '%s' "$_c" | tr '[:upper:]' '[:lower:]')" ]; then
        printf '%s\n' "$_c"; return 0
      fi
    done
  fi
  printf '%s\n' "$UPSTREAM_DEFAULT"
}
newest_tag() {  # stdin: one tag per line -> the highest, compared as numbers, not text
  python3 -c '
import sys, re
best, bp = "", None
for line in sys.stdin:
    t = line.strip()
    if not re.fullmatch(r"v?[0-9]+(\.[0-9]+)+", t):
        continue  # an error body is not a version
    p = [int(x) for x in re.findall(r"[0-9]+", t)]
    if p and (bp is None or p > bp):
        best, bp = t, p
if best:
    print(best)
'
}
# A DECLARED UPSTREAM THAT IS NOT owner/repo STOPS THE UPGRADE. Falling back to the probe
# would install from a repository nobody named; the advisory check may shrug, this may not.
if ! UPSTREAM="$(upstream_pinned "$ROOT")"; then
  printf 'scaffold_upgrade: fix SCAFFOLD_UPSTREAM or .scaffold-upstream (one owner/repo line), then re-run\n' >&2
  exit 1
fi
TO=""; FROM=""; DRY=0; FORCE=0; DO_SELFTEST=0
# SAVED BEFORE PARSING, because the loop below shifts them away and the hand-over near
# the end needs the invocation as the user typed it. Without this the newer upgrader
# would be handed no arguments and would silently ignore --dry-run, which is the one
# flag where doing the opposite is unrecoverable.
_ORIG_ARGS=("$@")
while [ $# -gt 0 ]; do
  case "$1" in
    --to) TO="${2:-}"; shift 2 ;;
    --from) FROM="${2:-}"; shift 2 ;;
    --dry-run) DRY=1; shift ;;
    --force) FORCE=1; shift ;;
    --selftest) DO_SELFTEST=1; shift ;;
    -h|--help)
      cat <<'USAGE'
scaffold_upgrade.sh — move this project from the scaffold release it is on to a newer one.

  --dry-run        print the plan and change nothing
  --to <tag>       target release (default: the latest release upstream)
  --from <path>    take both releases from a local scaffold clone instead of fetching
  --force          proceed on a dirty working tree (NOT recommended — git is your undo)
  --selftest       run an end-to-end upgrade against a synthetic project; no network
  -h, --help       this message

Product-owned files are replaced. SESSION/BACKLOG/MEMORY/TEAM/version/CODEOWNERS and any
*_ARCHIVE.md are never touched. The standards files and AGENTS.md are THREE-WAY MERGED
against the release named in .scaffold-version, so your overlay appendix, your ceilings
marker and your filled-in command table survive while upstream changes still land.
USAGE
      exit 0 ;;
    *) echo "scaffold_upgrade: unknown argument '$1' (try --help)" >&2; exit 2 ;;
  esac
done

say()  { printf '%s\n' "$*"; }
ok()   { printf '[OK] %s\n' "$*"; }
warn() { printf '[!]  %s\n' "$*"; }
die()  { printf 'scaffold_upgrade: %s\n' "$*" >&2; exit 1; }

# exclude_regex_sane <regex> -- 0 if grep will accept it, 1 if it is malformed.
#
# PRODUCT_PATH_EXCLUDE IS ASSEMBLED BY CONCATENATION, AND NOTHING CHECKED THE RESULT. On
# 2026-08-30 it carried a trailing empty alternative from a variable emptied months earlier.
# macOS /usr/bin/grep (BSD 2.6.0-FreeBSD) exits 2 on that -- "grep: empty (sub)expression" --
# so the consumer's `grep -qE "$re" && return 0` never fired and the exclusion silently
# stopped excluding, while spraying one error line per file into the middle of the upgrade
# plan. A FUNCTION so the runtime guard and the selftest check the same thing.
# sha256_of_path <file> -- prints the hash, or nothing if no hasher exists. Both names are
# tried because macOS ships shasum and most Linux images ship sha256sum.
sha256_of_path() {
  if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" 2>/dev/null | cut -d' ' -f1
  elif command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" 2>/dev/null | cut -d' ' -f1
  fi
}

# unpinned_uses <workflow> -- one `action@ref` per `uses:` whose ref is not a full commit SHA.
# A KEPT WORKFLOW KEEPS ITS UNPINNED ACTIONS TOO (Clocktower #5). An adopter's edited
# scaffold-check.yml is kept, correctly, and the incoming copy's pinned checkout goes into a
# sidecar nobody has read yet -- so the next preflight reddens workflow_audit on a line this
# upgrade could have named. Local (`./`) and docker:// actions have no ref to pin.
unpinned_uses() {
  grep -E '^[[:space:]]*-?[[:space:]]*uses:[[:space:]]*' "$1" 2>/dev/null \
    | sed -E 's/^[[:space:]]*-?[[:space:]]*uses:[[:space:]]*//; s/[[:space:]]*#.*$//; s/^["'"'"']//; s/["'"'"']$//' \
    | grep -vE '^(\./|docker://)' \
    | grep -vE '@[0-9a-f]{40}$' \
    | sort -u
}

# pins_only_differ <a> <b> -- true when two workflows differ ONLY in the ref of `uses:` lines
# (and any trailing `# vN` comment). A DEPENDABOT BUMP IS NOT AN EDIT. An adopter running
# Dependabot on github-actions gets scaffold-check.yml's checkout bumped; the file then
# differs from its baseline, the upgrade keeps it as "you edited it", and that repository
# silently stops receiving every later template change to its CI. Measured 2026-09-22:
# health-app and collectionapp both run that ecosystem. Identical files are not "only pins".
pins_only_differ() {
  cmp -s "$1" "$2" && return 1
  local _n='s/^([[:space:]]*-?[[:space:]]*uses:[[:space:]]*[^@[:space:]]+)@[^[:space:]]+([[:space:]]*#.*)?$/\1@/'
  [ -f "$1" ] && [ -f "$2" ] || return 1
  [ "$(sed -E "$_n" "$1")" = "$(sed -E "$_n" "$2")" ]
}

exclude_regex_sane() {
  local re="$1" rc
  case "|$re|" in *"||"*) return 1 ;; esac      # empty alternative: leading, middle or trailing
  printf 'a/probe/path' | grep -qE "$re" >/dev/null 2>&1
  rc=$?
  [ "$rc" -ne 2 ]                               # 0 matched, 1 no match, 2 = grep REFUSED it
}

SELF="${BASH_SOURCE[0]}"
SELF_DIR="$(cd "$(dirname "$SELF")" && pwd)"
# DEFINED HERE, ABOVE THE --selftest DISPATCH, because --selftest exits before the
# upgrade path runs and would otherwise test an empty string against every path.
# NOTHING TO SUPPRESS ANY MORE (W-15, DEC-20).
#
# This list existed because `tools/` is force-installed and the repository that SHIPS
# localcoder must not receive a vendored copy of its own product — #115, where the drift
# check silently moved onto the vendored file and stopped watching `src/`. After the split
# the scaffold ships no localcoder files at all, so there is nothing to except and the list
# is empty by construction rather than by omission.
#
# `scaffold:owns-localcoder` is still RECOGNISED, because adopters carry it and a marker
# that silently stops being read is how an upgrade overwrites the thing it protects. It
# simply has nothing left to do here.
#
# DUAL_HOMED_GOVERNANCE is gone with it. It named localcoder_sync.py as dual-homed but
# scaffold-owned; nothing is dual-homed now, and localcoder_sync.py left with the rest.
OWNS_LOCALCODER_PATHS=""

# Read from this file's own header so a refusal can name the version that refused (#130).
# Falls back to "unknown" rather than empty: a message reading "This is scaffold_upgrade.sh
# ." is worse than one admitting it cannot tell.
SELF_VERSION="$(sed -n 's/^# Version:[[:space:]]*\([0-9][0-9.]*\).*/\1/p' "$SELF" 2>/dev/null | head -1)"
[ -n "$SELF_VERSION" ] || SELF_VERSION="unknown"

#
# A FUNCTION SO IT CAN BE TESTED. The same argument that moved the secret scan out of a
# workflow `run:` block: logic that only exists inline at the bottom of a script has no
# checker but the eye of whoever last read it.
tools_recorded_non_executable() {   # prints one path per line; empty = nothing to warn about
  local f m
  for f in tools/*; do
    [ -f "$f" ] || continue
    head -1 "$f" 2>/dev/null | grep -q '^#!' || continue
    m="$(git ls-files -s "$f" 2>/dev/null | cut -d' ' -f1)"
    # UNTRACKED IS NOT A FINDING. A file git has never seen has no recorded mode yet, and
    # `git add` under core.fileMode=false is exactly when it acquires the wrong one — so
    # it belongs in the list. An empty $m means untracked, which is the common case
    # immediately after a force-install.
    [ "$m" = "100755" ] && continue
    printf '%s\n' "$f"
  done
}

# ------------------------------------------------------------------ selftest
selftest() {
  # A SCRIPTED END-TO-END CASE, because this tool has the largest blast radius in the repo
  # and every defect in it so far was found by RUNNING it, never by reading it: four from a
  # hand-built fixture (wrong ROOT, SIGPIPE under pipefail, overlay conflicts on every
  # upgrade, a conflict made of one blank line) and two more from the first real project it
  # touched (an untagged build stamp, a ref name written as a version). A hand-rebuilt
  # fixture found those once; only a scripted one finds them again.
  #
  # Everything below is synthetic and offline: a fake upstream with two tagged releases and
  # a fake adoption carrying the four kinds of content that must survive.
  local T fails=0
  # WHERE THE SCAFFOLD COMES FROM -- checked first, offline, against a fake gh. Work
  # adopters read the the work mirror account mirror and usually cannot see Robiton at all.
  local _u _r
  _u="$(mktemp -d "${TMPDIR:-/tmp}/scaffold_upgrade_up.XXXXXX")" || return 1
  _r="$(unset SCAFFOLD_UPSTREAM; upstream_pinned "$_u")"
  [ -z "$_r" ] && echo "  ok   no env, no file -> nothing pinned" || { echo "  FAIL no env, no file -> got '$_r'"; fails=$((fails+1)); }
  printf '# work repos read the mirror\n  acme/scaffold  # note\n' > "$_u/.scaffold-upstream"
  _r="$(unset SCAFFOLD_UPSTREAM; upstream_pinned "$_u")"
  [ "$_r" = acme/scaffold ] && echo "  ok   .scaffold-upstream is honoured" || { echo "  FAIL .scaffold-upstream -> got '$_r'"; fails=$((fails+1)); }
  _r="$(SCAFFOLD_UPSTREAM=x/y upstream_pinned "$_u")"
  [ "$_r" = x/y ] && echo "  ok   SCAFFOLD_UPSTREAM beats the file" || { echo "  FAIL env vs file -> got '$_r'"; fails=$((fails+1)); }
  mkdir -p "$_u/bin"
  # A REAL gh PRINTS THE 404 BODY ON STDOUT AND EXITS 1 -- a silent fake hid the 0.111.15 bug.
  UPSTREAM_MIRROR=example-mirror/ai-project-scaffold  # fixture: no real account (issue #387)
  printf '#!/bin/sh\ncase "$*" in *Robiton/*) echo "{\\"message\\":\\"Not Found\\",\\"status\\":\\"404\\"}"; exit 1 ;; *example-mirror/*) echo example-mirror/ai-project-scaffold ;; esac\n' > "$_u/bin/gh"
  chmod +x "$_u/bin/gh"
  _r="$(PATH="$_u/bin:$PATH" probe_upstream)"
  [ "$_r" = "$UPSTREAM_MIRROR" ] && echo "  ok   a mirror-only machine resolves the mirror" || { echo "  FAIL mirror-only machine -> got '$_r'"; fails=$((fails+1)); }
  printf '#!/bin/sh\necho Robiton/ai-project-scaffold\n' > "$_u/bin/gh"
  _r="$(PATH="$_u/bin:$PATH" probe_upstream)"
  [ "$_r" = "$UPSTREAM_DEFAULT" ] && echo "  ok   a machine that sees Robiton takes Robiton" || { echo "  FAIL Robiton machine -> got '$_r'"; fails=$((fails+1)); }
  rm -rf "$_u"
  _r="$(printf '0.9.0\n0.10.0\n0.5.0\n' | newest_tag)"
  [ "$_r" = 0.10.0 ] && echo "  ok   newest tag by number, not by text" || { echo "  FAIL newest tag -> got '$_r'"; fails=$((fails+1)); }
  _r="$(printf '%s\n' '{"message":"Not Found","status":"404"}' | newest_tag)"
  [ -z "$_r" ] && echo "  ok   an error body is not a version" || { echo "  FAIL error body -> got '$_r'"; fails=$((fails+1)); }
  # THE DECLARED UPSTREAM IS ONE owner/repo, OR IT IS NOT USED (report item 15). It is spliced
  # into `gh api repos/<it>/tarball/<tag>`, and context_survival word-split it unquoted.
  local _n _bad_up=""
  for _n in Robiton/ai-project-scaffold example-mirror/ai-project-scaffold acme/.github; do
    upstream_valid "$_n" || _bad_up="$_bad_up rejected:$_n"
  done
  for _n in ../evil a/b/c .x/y a/.. "a b/c" "x/y;rm" ""; do
    upstream_valid "$_n" && _bad_up="$_bad_up accepted:'$_n'"
  done
  [ -z "$_bad_up" ] && echo "  ok   upstream_valid takes owner/repo and nothing else" || { echo "  FAIL upstream_valid:$_bad_up"; fails=$((fails+1)); }
  if _r="$(SCAFFOLD_UPSTREAM=../evil upstream_pinned /nonexistent 2>/dev/null)"; then
    echo "  FAIL a traversal upstream was accepted -> '$_r'"; fails=$((fails+1))
  else
    [ -z "$_r" ] && echo "  ok   a traversal upstream returns 1 and names nothing" || { echo "  FAIL traversal upstream printed '$_r'"; fails=$((fails+1)); }
  fi
  # THE MANIFEST CATCHES ALL THREE KINDS OF DIFFERENCE. sha256sum -c passes a tree that GAINED
  # a file, which is the one an attacker would add; the empty manifest is could-not-run.
  local _st; _st="$(mktemp -d "${TMPDIR:-/tmp}/scaffold_upgrade_sums.XXXXXX")" || return 1
  mkdir -p "$_st/t/ai"; printf 'a\n' > "$_st/t/ai/A.md"; printf 'b\n' > "$_st/t/B"
  scaffold_sums make "$_st/t" > "$_st/S"
  scaffold_sums check "$_st/t" "$_st/S" >/dev/null; _n=$?
  [ "$_n" = 0 ] && echo "  ok   an unchanged tree matches its manifest" || { echo "  FAIL unchanged tree -> rc $_n"; fails=$((fails+1)); }
  printf 'x\n' >> "$_st/t/B"; printf 'new\n' > "$_st/t/ai/C.md"; rm "$_st/t/ai/A.md"
  _r="$(scaffold_sums check "$_st/t" "$_st/S")"; _n=$?
  case "$_n:$_r" in
    1:*"changed  B"*"added    ai/C.md"*) case "$_r" in *"missing  ai/A.md"*)
         echo "  ok   changed, added and missing files each fail the manifest" ;;
       *) echo "  FAIL missing not named: $_r"; fails=$((fails+1)) ;; esac ;;
    *) echo "  FAIL manifest difference -> rc $_n: $_r"; fails=$((fails+1)) ;;
  esac
  : > "$_st/E"; scaffold_sums check "$_st/t" "$_st/E" >/dev/null; _n=$?
  [ "$_n" = 3 ] && echo "  ok   an empty manifest is could-not-run (3), not a match" || { echo "  FAIL empty manifest -> rc $_n"; fails=$((fails+1)); }
  rm -rf "$_st"
  # FIXTURES RUN INSIDE A GUARDED ROOT (tools/fixture_guard.sh). Later mktemps land inside it,
  # and a git on PATH refuses any write outside it. The guard exists because a failed mktemp
  # once let a selftest run git init and commit in the real repo.
  . "${SCAFFOLD_UPGRADE_TOOLS:-$(dirname "${BASH_SOURCE[0]}")}/fixture_guard.sh" || { echo "scaffold_upgrade: tools/fixture_guard.sh is missing; refusing to build fixtures" >&2; exit 1; }
  fixture_root FG_ROOT; trap fg_cleanup EXIT
  T="$(mktemp -d "${TMPDIR:-/tmp}/scaffold_upgrade.XXXXXX")" || return 1
  local UP="$T/upstream" ADOPT="$T/project"
  # `$SELF` re-execs itself, and this process already has the re-exec variables in its
  # environment — a child would inherit them and act on OUR directory instead of its own.
  local RUN="env -u SCAFFOLD_UPGRADE_REEXEC -u SCAFFOLD_UPGRADE_ORIGIN bash $SELF"

  chk() {  # chk <label> <expected> <actual>
    if [ "$2" = "$3" ]; then
      printf '  ok   %-52s\n' "$1"
    else
      printf '  FAIL %-52s expected=%s got=%s\n' "$1" "$2" "$3"; fails=$((fails + 1))
    fi
  }

  # #5: A KEPT WORKFLOW'S UNPINNED ACTIONS ARE NAMED. The real helper, on a fixture with one
  #     unpinned, one pinned, one local and one quoted-and-commented unpinned action.
  printf '%s\n' 'jobs:' '  a:' '    steps:' \
    '      - uses: actions/checkout@v7' \
    '      - uses: actions/setup-python@3d3c42e5aac5ba805825da76410c181273ba90b1 # v6' \
    '      - uses: ./.github/actions/local' \
    "        uses: 'owner/thing@main'   # floating" > "$T/wf.yml"
  chk "unpinned uses: named, pinned and local ones not" \
    "actions/checkout@v7,owner/thing@main" "$(unpinned_uses "$T/wf.yml" | paste -sd, -)"

  # THE ASSEMBLY BUG, PLANTED IN BOTH DIRECTIONS. exclude_regex_sane is what the runtime
  # guard calls, so these two cases test the real check rather than a copy of it.
  if exclude_regex_sane "docs/a|docs/b"; then
    chk "a well-formed exclusion regex is accepted" "ok" "ok"
  else
    chk "a well-formed exclusion regex is accepted" "ok" "REJECTED"
  fi
  for _bad in "docs/a|docs/b|" "|docs/a" "docs/a||docs/b" ""; do
    if exclude_regex_sane "$_bad"; then
      chk "empty alternative rejected: '${_bad}'" "rejected" "ACCEPTED"
    else
      chk "empty alternative rejected: '${_bad}'" "rejected" "rejected"
    fi
  done
  unset _bad

  # ---- fake upstream, release 1 -------------------------------------------------------
  mkdir -p "$UP/ai" "$UP/tools"
  ( cd "$UP" && git init -q . && git config user.email a@b.c && git config user.name t )
  printf '# Standards\n\n## Load order\nRead CODING.\n\n## Archiving\nKeep it small.\n' > "$UP/ai/STANDARDS.md"
  printf '# Coding\n\n## Naming\nsnake_case.\n' > "$UP/ai/CODING.md"
  # SHAPE MATTERS, NOT JUST CONTENT. The first version of this fixture was a five-line
  # AGENTS.md, so the row an adopter fills in was the LAST line and any upstream append
  # landed adjacent to it — which a textual merge must conflict on. The real AGENTS.md is
  # ~90 lines with several sections after the command table, so an upstream append is
  # nowhere near it. A fixture that is merely smaller than the real file is a different
  # file: third time this class of thing has bitten in one session.
  printf '# Agents\n\n## Project Commands\n\n| Task | Command |\n|---|---|\n| Test | `[fill in]` |\n\n## Toolchain Registry\n\nAGENTS.md is the universal hook.\n\n## Load order\n\nRead ai/STANDARDS.md first.\n' > "$UP/AGENTS.md"
  printf '*.log\n' > "$UP/.gitignore"
  # THE FIXTURE HAD NO PRODUCT FILES AT ALL, WHICH IS WHY 23 CHECKS PASSED OVER #125.
  # copy_product() returns early when the release does not ship the path, so every
  # product-owned file was untested by construction — including .gitattributes, which was
  # eating adopters' Git LFS patterns the whole time. Three shipped here now: a line-set
  # file (.gitattributes), one the adopter will edit (.editorconfig) and one they will not
  # (.codex).
  printf 'ai/SESSION.md merge=union\nai/BACKLOG.md merge=union\n' > "$UP/.gitattributes"
  printf 'root = true\n\n[*]\nindent_size = 2\n' > "$UP/.editorconfig"
  mkdir -p "$UP/.github/workflows"
  printf 'jobs:\n  c:\n    steps:\n      - uses: actions/checkout@v7\n' > "$UP/.github/workflows/scaffold-check.yml"
  printf '# Codex hook\nRead ai/STANDARDS.md first.\n' > "$UP/.codex"
  printf 'echo v1\n' > "$UP/tools/session_journal.sh"
  printf '1.0.0.20260101.0000\n' > "$UP/version"
  cp "$UP/version" "$UP/.scaffold-version"
  # #252 FIXTURE: two files r1 ships and r2 does NOT. One the adoption leaves alone (must be
  # removed on upgrade), one it edits (must be KEPT and named — an edit is a decision).
  printf 'retired, untouched\n'  > "$UP/tools/gone_clean.sh"
  printf 'retired, edited\n'     > "$UP/tools/gone_edited.sh"
  chmod +x "$UP/tools/gone_clean.sh" "$UP/tools/gone_edited.sh"
  ( cd "$UP" && git add -A >/dev/null && git commit -qm r1 && git tag 1.0.0.20260101.0000 )

  # ---- the adoption, at release 1, with content that MUST survive ---------------------
  mkdir -p "$ADOPT"
  ( cd "$UP" && git archive 1.0.0.20260101.0000 ) > "$T/r1.tar"
  tar -x -C "$ADOPT" -f "$T/r1.tar"
  printf '\n---\n# Overlay: splunk-app\nMust pass AppInspect.\n' >> "$ADOPT/ai/STANDARDS.md"
  python3 - "$ADOPT/AGENTS.md" <<'PY'
import sys
p = sys.argv[1]; s = open(p).read()
open(p, "w").write(s.replace("`[fill in]`", "`pytest -q`"))
PY
  # THE FOUR SHAPES OF ADOPTER CONTENT IN PRODUCT-OWNED FILES (#125).
  #  - .gitattributes: their own LFS patterns, plus a DELIBERATE reversal of a shipped
  #    line (`-merge` turns off the union driver the scaffold asks for). Order decides the
  #    winner in this file, so appending ours below theirs would silently overturn it.
  #  - .editorconfig: an ordinary edit — indent 4, not the shipped 2.
  #  - .codex: untouched, and must still be replaced or the upgrade stops delivering.
  #  - tools/: edited, and must be replaced ANYWAY — vendored tooling is force-installed
  #    on purpose, and honouring edits there is how a project quietly forks its tools.
  printf 'ai/SESSION.md merge=union\nai/BACKLOG.md -merge\n*.png filter=lfs diff=lfs merge=lfs -text\n*.blend filter=lfs diff=lfs merge=lfs -text\n' > "$ADOPT/.gitattributes"
  printf 'root = true\n\n[*]\nindent_size = 4\n' > "$ADOPT/.editorconfig"
  printf '      - run: make product-check\n' >> "$ADOPT/.github/workflows/scaffold-check.yml"
  printf 'echo LOCAL EDIT\n' > "$ADOPT/tools/session_journal.sh"
  printf '# Memory\n\n- Postgres over Mongo.\n' > "$ADOPT/ai/MEMORY.md"
  printf '# Session\n\n## 2026-01-02\nDid a thing.\n' > "$ADOPT/ai/SESSION.md"
  printf '9.9.9.20260401.1200\n' > "$ADOPT/version"          # THEIR project version
  printf 'build/\n' >> "$ADOPT/.gitignore"
  ( cd "$ADOPT" && git init -q . && git config user.email a@b.c && git config user.name t \
      && git add -A >/dev/null && git commit -qm adopted )

  # ---- fake upstream, release 2: changes in regions the adopter never touched ---------
  printf '\n## Versioning\nStamp every PR.\n' >> "$UP/ai/STANDARDS.md"
  # A BOLD LEAD-IN IS HOW THESE FILES USUALLY STATE A RULE, so the banner must catch it.
  # The first version matched headings only and missed the scaffold:owns-localcoder rule on
  # the very next real upgrade — reported as a line count, named as nothing.
  printf '\n**Never commit a rendered secret.** Reference it by indirection.\n' >> "$UP/ai/STANDARDS.md"
  printf '\n## Docstrings\nAlways.\n' >> "$UP/ai/CODING.md"
  # Upstream changes PROSE in AGENTS.md, not the command table. Checked against the real
  # repo's history: the table rows were written once and never edited in 8 later commits,
  # while the surrounding prose changed repeatedly. An earlier version of this test had
  # upstream appending a table row directly below the row the adopter fills in — adjacent
  # edits with no separating context, which textual 3-way merge must conflict on. That
  # conflict was real but the scenario was invented, and testing an invented scenario is
  # how you end up engineering around a problem nobody has. The genuine-collision case is
  # tested deliberately further down.
  printf '\n## Judgment Boundaries\nUpdate MEMORY.md as decisions land.\n' >> "$UP/AGENTS.md"
  printf 'node_modules/\n' >> "$UP/.gitignore"
  # r2 moves all three product files, so each check below is about what the upgrade DID,
  # not about upstream having nothing to deliver.
  printf 'ai/SESSION.md merge=union\nai/BACKLOG.md merge=union\nai/DECISIONS.md merge=union\n' > "$UP/.gitattributes"
  printf 'root = true\n\n[*]\nindent_size = 2\n\n[*.md]\nindent_size = 3\n' > "$UP/.editorconfig"
  printf 'jobs:\n  c:\n    steps:\n      - uses: actions/checkout@%s # v7\n' \
    3d3c42e5aac5ba805825da76410c181273ba90b1 > "$UP/.github/workflows/scaffold-check.yml"
  printf '# Codex hook\nRead ai/STANDARDS.md and ai/CODING.md.\n' > "$UP/.codex"
  printf 'echo v2\n' > "$UP/tools/session_journal.sh"
  printf 'echo new tool\n' > "$UP/tools/header_check.sh"
  # A HOOK WITH NO EXTENSION, SHIPPED 644 ON PURPOSE (#171).
  #
  # git requires the bare name `pre-push`, and a hook without its exec bit is SILENTLY
  # IGNORED — present, correct, doing nothing. `cp` carries the source mode, so a hook that
  # is 755 upstream needs no help and this case would prove nothing.
  #
  # 644 IS THE REALISTIC UPSTREAM, NOT A CONTRIVANCE. Measured on this project's own
  # machine: `core.fileMode` is false (a OneDrive working copy), so `chmod +x` is invisible
  # to git and the hook was committed 100644 — it took `git update-index --chmod=+x` to
  # record it. Any maintainer on such a machine ships an inert hook to every adopter and
  # gets no warning, so the upgrader repairs the mode on arrival rather than trusting it.
  mkdir -p "$UP/.githooks"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$UP/.githooks/pre-push"
  chmod 644 "$UP/.githooks/pre-push"
  # THE THREE CHAINING git-lfs HOOKS SHIP TOO (#274), and they are 644 upstream for the same
  # reason pre-push is: core.fileMode is false in these working copies, so the mode has to be
  # repaired on arrival or the adopter receives a hook git will silently never run.
  for _lfsh in post-checkout post-commit post-merge; do
    printf '#!/usr/bin/env bash\nexit 0\n' > "$UP/.githooks/$_lfsh"
    chmod 644 "$UP/.githooks/$_lfsh"
  done
  unset _lfsh
  # RELEASE 2 CARRIES A NEWER UPGRADER (#179). It is this very script with a bumped header
  # and one extra line, so the hand-over is exercised against something that really runs.
  # The marker is what proves WHICH copy did the work — a version number printed by the old
  # copy would prove only that it read the new one's header.
  sed -e 's/^# Version:  [0-9.]*$/# Version:  99.0.0.20261231.2359/' \
      -e 's/^ok "fetched both releases"$/ok "fetched both releases"; echo "HANDOVER_MARKER_R2"/' \
      "$SELF" > "$UP/tools/scaffold_upgrade.sh"
  chmod +x "$UP/tools/scaffold_upgrade.sh"
  printf '2.0.0.20260201.0000\n' > "$UP/version"
  cp "$UP/version" "$UP/.scaffold-version"
  # #253 FIXTURE: a manifest naming a file that NEITHER release ships — the pre-baseline
  # case the BASE-vs-NEW diff is blind to by construction.
  printf 'long gone\n' > "$T/prebaseline_content"
  _pb_sha="$( (shasum -a 256 "$T/prebaseline_content" 2>/dev/null || sha256sum "$T/prebaseline_content") | cut -d' ' -f1 )"
  printf '# fixture manifest\n' > "$UP/tools/RETIRED.tsv"
  # #255: TWO shipped revisions, and the adopter is on the OLDER one. With a single-sha
  # manifest this is misclassified as "you edited it" — the defect an adopter carrying the
  # file longest is most likely to hit.
  printf 'an older shipped revision\n' > "$T/prebaseline_old"
  _pb_old="$( (shasum -a 256 "$T/prebaseline_old" 2>/dev/null || sha256sum "$T/prebaseline_old") | cut -d' ' -f1 )"
  printf 'tools/prebaseline.sh\t%s,%s\tretired long before this baseline\n' "$_pb_old" "$_pb_sha" >> "$UP/tools/RETIRED.tsv"
  printf 'tools/prebaseline_edited.sh\t%s\tretired long before this baseline\n' "$_pb_sha" >> "$UP/tools/RETIRED.tsv"
  # A FILE THE SCAFFOLD VENDORED FROM LOCALCODER. Removed from an ordinary adopter, kept in
  # the repository that declares scaffold:owns-localcoder, where it is the product.
  printf 'tools/lc_vendored.sh\t%s,%s\tlocalcoder: fixture, vendored before the split\n' "$_pb_old" "$_pb_sha" >> "$UP/tools/RETIRED.tsv"
  # #252: r2 RETIRES both. git rm so they are genuinely absent from the r2 tree.
  ( cd "$UP" && git rm -q -f tools/gone_clean.sh tools/gone_edited.sh >/dev/null 2>&1 || true )
  rm -f "$UP/tools/gone_clean.sh" "$UP/tools/gone_edited.sh"
  ( cd "$UP" && git add -A >/dev/null && git commit -qm r2 && git tag 2.0.0.20260201.0000 )

  echo "scaffold_upgrade selftest — synthetic upstream, synthetic adoption, no network"

  # ---- 1. a dirty tree is refused ------------------------------------------------------
  echo scratch > "$ADOPT/dirty.txt"
  ( cd "$ADOPT" && $RUN --from "$UP" --to 2.0.0.20260201.0000 ) >/dev/null 2>&1
  chk "dirty tree is refused (git is the undo)" 1 $?
  rm -f "$ADOPT/dirty.txt"

  # ---- 2. dry run changes nothing ------------------------------------------------------
  local before after
  before="$(cd "$ADOPT" && git status --porcelain | wc -l | tr -d ' ')"
  ( cd "$ADOPT" && $RUN --from "$UP" --to 2.0.0.20260201.0000 --dry-run ) >/dev/null 2>&1
  after="$(cd "$ADOPT" && git status --porcelain | wc -l | tr -d ' ')"
  chk "--dry-run writes nothing" "$before" "$after"

  # ---- 2b. the newer upgrader does the work (#179) -------------------------------------
  # A FIX TO THIS TOOL CANNOT FIX THE UPGRADE THAT INSTALLS IT, unless it hands over. That
  # cost a real project three sets of Git LFS patterns: .gitattributes became union-merged
  # in 0.12.0, and an 0.11.3 -> 0.24.0 upgrade still replaced it, because 0.11.3's copy did
  # the work. The marker comes from release 2's copy, so seeing it proves the handover ran
  # rather than that this copy merely read the other's version header.
  _ho="$( cd "$ADOPT" && $RUN --from "$UP" --to 2.0.0.20260201.0000 --dry-run 2>&1 )"
  chk "the newer upgrader in the target release does the work" 1 \
      "$(printf '%s' "$_ho" | grep -c 'HANDOVER_MARKER_R2')"
  chk "the handover says which copy it came from" 1 \
      "$(printf '%s' "$_ho" | grep -c 'handing over to scaffold_upgrade.sh 99.0.0')"

  # #254: THE HANDOVER MUST NOT PRINT THE ENVIRONMENT, and the existing handover cases all
  # passed while it was doing exactly that -- they asserted the handover HAPPENED, never
  # what else it emitted. A canary variable is the cheapest way to assert absence.
  _canary_out="$( cd "$ADOPT" && SCAFFOLD_CANARY_254=NOT_FOR_STDOUT \
                  $RUN --from "$UP" --to 2.0.0.20260201.0000 --dry-run 2>&1 )"
  case "$_canary_out" in
    *NOT_FOR_STDOUT*) chk "handover does NOT dump the environment (#254)" "clean" "LEAKED" ;;
    *)                chk "handover does NOT dump the environment (#254)" "clean" "clean" ;;
  esac
  # ...and the variables it exists to pass must actually arrive, which the same typo broke.
  case "$_canary_out" in
    *"handing over"*) chk "  and the handover still runs at all" 1 1 ;;
    *)                chk "  and the handover still runs at all" 1 0 ;; esac
  unset _canary_out
  # --dry-run MUST SURVIVE THE HANDOVER. It is the one flag where doing the opposite is
  # unrecoverable, and the args are re-read from a list saved before parsing shifted them.
  chk "--dry-run survives the handover" 1 \
      "$(printf '%s' "$_ho" | grep -c 'dry run complete')"

  # ---- 2c. THE HANDOVER MUST SURVIVE AN EMPTY ARGUMENT LIST (bash 3.2) ---------------
  #
  # macOS ships bash 3.2.57, where an EMPTY array expanded as "${a[@]}" under `set -u` is
  # treated as unbound and ABORTS. Fixed upstream in bash 4.4; irrelevant to an adopter on
  # a Mac. Reproduced on 3.2.57: `a=(); echo "${a[@]}"` exits 127.
  #
  # EVERY CASE ABOVE PASSES --from AND --to, because they must run offline against a
  # synthetic upstream. So _ORIG_ARGS is never empty in this fixture and a full-upgrade
  # test CANNOT reach this path — the bare run is the only one that fails, and the bare run
  # is the only one that writes. Dry-run green, real run dead.
  #
  # Found on a real M3 adoption, not here. The assertion therefore has a different shape
  # from every other case in this file: it tests the EXPANSION under the real 3.2 binary,
  # and greps the source so the unguarded form cannot come back anywhere.
  # THE ZERO-ARGUMENT INVOCATION, END TO END, UNDER THE REAL 3.2 BINARY.
  #
  # Asked for by the adopter who found the original bug: the bare run is the DEFAULT
  # invocation and the one the docs tell people to use, and every other case in this file
  # passes --from and --to so it can work offline. So this runs the real script with NO
  # arguments and asserts only that it gets past the prologue — it will exit non-zero for
  # want of a network or a base tag, which is fine and expected. What must NEVER appear is
  # an unbound-variable abort, because that is a syntax-level death before any work starts.
  #
  # THE WHOLE PRE-HANDOVER PROLOGUE IS EFFECTIVELY UN-UPGRADABLE for an existing adopter —
  # a fix to it can only arrive through the release they are already on — so it deserves a
  # different standard of care than the rest of the file. This case guards all of it, not
  # just the one line that broke.
  # IN A DISPOSABLE TREE, NEVER IN $ROOT — and getting that wrong made this the most
  # damaging defect the project has shipped.
  #
  # This case used to run `cd "$ROOT" && /bin/bash "$SELF"`, on the reasoning quoted above:
  # a bare run "will exit non-zero for want of a network or a base tag, which is fine and
  # expected". THAT IS TRUE HERE AND FALSE IN AN ADOPTION. Upstream there is no base tag to
  # resolve, so it bails. An adopter has a valid `.scaffold-version`, a network and `gh` —
  # so the bare run SUCCEEDS and performs a real upgrade of their repository.
  #
  # `tools/preflight.sh` discovers and runs every selftest. So an adopter running the gate
  # they are told to run before every push had their tree silently upgraded to the latest
  # release as a side effect of CHECKING it: PRODUCT files replaced, `.scaffold-<version>`
  # sidecars written, and exit 0 throughout. A check that mutates the thing it checks.
  #
  # Measured in Robiton/localcoder on 2026-08-12: `tools/preflight.sh` rewrote
  # tools/preflight.sh itself to a newer release mid-run and left a CONTRIBUTING.md sidecar.
  # It reproduces in every adoption and in none of our own repositories, which is why nothing
  # caught it — including tools/adoption_check.sh, whose fixture is a throwaway copy where a
  # mutation is invisible. That check now asserts the tree is unchanged afterwards.
  #
  # The case only ever needed the PROLOGUE to execute, so a bare empty git repo is a
  # strictly better subject: no `.scaffold-version`, so it stops early by construction,
  # everywhere, for the same reason on every machine.
  #
  # AND IT IS WEAKER THAN ITS NAME SUGGESTS, WHICH WAS ALSO TRUE BEFORE. Checked by
  # reintroducing the 2026-08-11 defect: this case still reports `ok`, because the abort was
  # at the HANDOVER and a run that stops in the prologue never reaches it. That was equally
  # true of the old `cd "$ROOT"` version — upstream it bailed for want of a base tag, so it
  # never reached the handover either. **The grep guard below is what actually catches that
  # defect**, and it does: it fails on the reintroduced version. This case is a smoke test
  # that the prologue parses and runs, which is worth having and is all it is.
  if [ -x /bin/bash ]; then
    _bt="$(mktemp -d "${TMPDIR:-/tmp}/bare.XXXXXX")" || { echo "scaffold_upgrade: mktemp failed; stopping" >&2; exit 1; }
    mkdir -p "$_bt/tools"
    cp "$SELF" "$_bt/tools/scaffold_upgrade.sh"
    ( cd "$_bt" && git init -q . >/dev/null 2>&1 ) || true
    # `env -u SCAFFOLD_UPGRADE_ORIGIN`, AND THAT IS THE WHOLE DEFECT, TWICE OVER.
    #
    # ROOT is `${SCAFFOLD_UPGRADE_ORIGIN:-$(pwd)}`, and this script EXPORTS that variable
    # when it re-execs and when it hands over. So a nested invocation inherits it and
    # targets the OUTER repository no matter what directory it runs in — `cd` is not
    # enough, and the environment silently wins. That is why every other case here goes
    # through $RUN, which is `env -u SCAFFOLD_UPGRADE_REEXEC -u SCAFFOLD_UPGRADE_ORIGIN`.
    # This block called /bin/bash directly and inherited it.
    #
    # Proved by logging every invocation: the bare run showed `pwd=<disposable tree>` and
    # `root=<the real repository>` on the same line. Moving the run to a temp directory —
    # the obvious fix, and the one I shipped first — did nothing at all, because the
    # directory was never what selected the target.
    _bare="$( cd "$_bt" && env -u SCAFFOLD_UPGRADE_REEXEC -u SCAFFOLD_UPGRADE_ORIGIN \
                /bin/bash tools/scaffold_upgrade.sh 2>&1 </dev/null | head -40 )" || true
    rm -rf "$_bt"
    chk "a BARE run reaches the prologue without an unbound-variable abort" 0 \
        "$(printf '%s' "$_bare" | grep -ciE 'unbound variable' || true)"
  fi

  if [ -x /bin/bash ]; then
    chk "empty array survives expansion under /bin/bash (3.2 compat)" 0 \
        "$( /bin/bash -c 'set -u; a=(); printf "%s" ${a[@]+"${a[@]}"}' >/dev/null 2>&1; echo $? )"
    chk "a populated array still expands with quoting intact" "a b|c" \
        "$( /bin/bash -c 'set -u; a=("a b" c); for x in ${a[@]+"${a[@]}"}; do printf "%s|" "$x"; done' 2>/dev/null | sed 's/|$//' )"
  fi
  # THE DURABLE HALF: no unguarded array expansion anywhere in this script. A grep guard
  # rather than a behavioural case, because the failure is a SYNTAX-level abort on one bash
  # version — there is no runtime state to assert against, and the next instance will be a
  # different variable in a different function.
  #
  # TWO FALSE POSITIVES HAD TO BE REMOVED FROM IT FIRST, and both are instructive: the
  # naive pattern matched the COMMENTS above (which quote the broken form to explain it)
  # AND the guarded form itself, because `${a[@]+"${a[@]}"}` literally contains `"${a[@]}"`
  # as a substring. A guard that flags its own fix is worse than none. Comments are dropped
  # and the guarded construct is deleted before counting; verified to still catch a real
  # one by injecting `exec foo "${BAD[@]}"` and watching the count go to 1.
  chk "no unguarded array expansion remains in this script" 0 \
      "$(grep -vE '^[[:space:]]*#' "$SELF" \
         | sed 's/\${[A-Za-z_]*\[@\]+"\${[A-Za-z_]*\[@\]}"}//g' \
         | grep -cE '\$\{[A-Za-z_]+\[@\]\}')"

  # ---- 3. the real upgrade -------------------------------------------------------------
  local out
  out="$( cd "$ADOPT" && $RUN --from "$UP" --to 2.0.0.20260201.0000 2>&1 )"
  chk "upgrade exits 0 when nothing conflicts" 0 $?
  # ANCHORED AT COLUMN 0, which is what tools/conflict_scan.sh actually treats as a
  # conflict — an unanchored match counts any file that MENTIONS the marker. That includes
  # every tool written to detect conflicts, and this fixture now installs one: release 2
  # ships a real scaffold_upgrade.sh, which necessarily contains the string it greps for.
  # The looser pattern passed only because nothing in the fixture had ever discussed a
  # conflict marker in prose.
  chk "no conflict markers written" 0 \
      "$(grep -rl '^<<<<<<<' "$ADOPT" --exclude-dir=.git 2>/dev/null | wc -l | tr -d ' ')"

  # ---- 3b. a delivered git hook must ARRIVE EXECUTABLE (#171) --------------------------
  # Shipping the file is the whole point — .git/hooks is not versioned and does not come
  # with a clone — but git ignores a non-executable hook WITHOUT SAYING SO. Delivered and
  # inert is this project's most recurrent failure shape, and it is the one a "the file is
  # there" check cannot tell from success.
  chk ".githooks/pre-push was delivered" 1 \
      "$([ -f "$ADOPT/.githooks/pre-push" ] && echo 1 || echo 0)"
  chk ".githooks/pre-push arrived EXECUTABLE (a 644 hook is silently ignored)" 1 \
      "$([ -x "$ADOPT/.githooks/pre-push" ] && echo 1 || echo 0)"
  # A HOOK THAT ARRIVES 644 IS A HOOK THAT NEVER RUNS, and git says nothing about it. The
  # three git-lfs chainers are the case where that costs an adopter their binaries.
  chk "the three git-lfs chaining hooks arrived, and arrived EXECUTABLE (#274)" 3 \
      "$(_n=0; for _h in post-checkout post-commit post-merge; do \
           [ -x "$ADOPT/.githooks/$_h" ] && _n=$((_n + 1)); done; echo "$_n")"
  # ...AND EXECUTABLE IN THE INDEX, WHICH IS THE BIT THAT SHIPS. `core.fileMode` is false in
  # these working copies, so the case above passes on a hook git records as 644 and never
  # runs. It did exactly that in 0.84.0, and mode_scan.sh -- not this suite -- is what found
  # it, one adopter and one release too late.
  chk "...and git RECORDS them executable, which is the bit a clone receives" 3 \
      "$(git -C "$ADOPT" ls-files -s .githooks/post-checkout .githooks/post-commit \
           .githooks/post-merge 2>/dev/null | grep -c '^100755')"

  # adopter content survived
  chk "overlay appendix survived"     1 "$(grep -c 'AppInspect' "$ADOPT/ai/STANDARDS.md")"
  chk "filled-in command survived"    1 "$(grep -c 'pytest -q' "$ADOPT/AGENTS.md")"
  chk "their MEMORY.md untouched"     1 "$(grep -c 'Postgres over Mongo' "$ADOPT/ai/MEMORY.md")"
  chk "their SESSION.md untouched"    1 "$(grep -c 'Did a thing' "$ADOPT/ai/SESSION.md")"
  chk "their project version kept"    "9.9.9.20260401.1200" "$(cat "$ADOPT/version")"
  chk "their gitignore entry kept"    1 "$(grep -c '^build/$' "$ADOPT/.gitignore")"

  # upstream content arrived
  chk "upstream STANDARDS section landed" 1 "$(grep -c 'Stamp every PR' "$ADOPT/ai/STANDARDS.md")"
  chk "upstream CODING section landed"    1 "$(grep -c 'Docstrings' "$ADOPT/ai/CODING.md")"
  chk "upstream AGENTS prose landed"      1 "$(grep -c 'Judgment Boundaries' "$ADOPT/AGENTS.md")"
  chk "upstream gitignore entry unioned"  1 "$(grep -c '^node_modules/$' "$ADOPT/.gitignore")"
  chk "product file replaced"             1 "$(grep -c 'echo v2' "$ADOPT/tools/session_journal.sh")"
  chk "missing tool installed"            1 "$([ -f "$ADOPT/tools/header_check.sh" ] && echo 1 || echo 0)"
  chk "version stamp recorded"            "2.0.0.20260201.0000" "$(cat "$ADOPT/.scaffold-version")"

  # ---- 3a-bis. the two owned-paths lists must agree (2026-08-09) ----------------------
  # OWNS_LOCALCODER_PATHS here and DUAL_HOMED in tools/localcoder_sync.py are two literals
  # naming one set. api_digest.py was added to DUAL_HOMED and not here, and the next real
  # upgrade of Robiton/localcoder vendored tools/api_digest.py into the repo that ships that
  # file as its product. Nothing failed: the drift check still resolved the product copy
  # first, so the mistake was invisible except to someone reading `git status`.
  #
  # Asserted rather than derived, deliberately. The comment on OWNS_LOCALCODER_PATHS says
  # "declared, never inferred" for a real reason — a derivation that silently yields an
  # empty list stops EVERY adopter receiving localcoder. So the literal stays authoritative
  # and this check fails when someone extends one list and not the other.
  # NOT $SELF_DIR. This script copies itself to $TMPDIR and re-execs (see the top), so
  # BASH_SOURCE points at /tmp by the time any of this runs — the first version of this
  # check looked for /tmp/localcoder_sync.py, found nothing, took the else branch, and
  # printed "ok". It reported a pass having never run, against BOTH injected defects.
  # SCAFFOLD_UPGRADE_ORIGIN is the directory the user invoked from, which is the repo
  # whose two lists are being compared.
  # THE ASSERTION IS NOW UNIVERSAL, AND THAT IS SHORTER AND STRONGER (W-15, DEC-20).
  #
  # It used to compare two literals — DUAL_HOMED in localcoder_sync.py against
  # OWNS_LOCALCODER_PATHS here — because a file in one and not the other meant the repo that
  # ships localcoder got a vendored copy of its own product. That was a conditional
  # guarantee: only a repository declaring `scaffold:owns-localcoder` was protected.
  #
  # With the split there is nothing to vendor, so the rule has no exemptions: NO repository
  # receives a tools/localcoder, ever. A universal assertion cannot drift out of step with a
  # second list, because there is no second list.
  _lc_shipped="$(find "$NEW" -name localcoder -o -name 'localcoder_[bhes]*.py' \
                   -o -name audit_localcoder.sh -o -name api_digest.py 2>/dev/null \
                 | grep -v localcoder_footprint | head -5 || true)"
  chk "the release ships no localcoder implementation" "" "$_lc_shipped"

  # ---- 3b. product-owned files carry adopter content too (#125) -----------------------
  # Every case below FAILS against the code before this release: .gitattributes was
  # replaced wholesale, taking the LFS lines, and no product file consulted the baseline.
  chk "LFS patterns survive an upgrade" 2 \
      "$(grep -c 'filter=lfs' "$ADOPT/.gitattributes")"
  chk "a deliberate -merge is not overridden" 0 \
      "$(grep -c '^ai/BACKLOG.md merge=union$' "$ADOPT/.gitattributes")"
  chk "a new upstream attribute still arrives" 1 \
      "$(grep -c '^ai/DECISIONS.md merge=union$' "$ADOPT/.gitattributes")"
  chk "an edited product file is kept" 1 \
      "$(grep -c 'indent_size = 4' "$ADOPT/.editorconfig")"
  chk "the incoming version is saved alongside" 1 \
      "$([ -f "$ADOPT/.editorconfig.scaffold-2.0.0.20260201.0000" ] && echo 1 || echo 0)"
  # #5, end to end: the kept workflow's unpinned checkout is named, with the incoming pin.
  chk "a kept workflow's unpinned action is named, with the pin" 1 \
      "$(printf '%s\n' "$out" | grep -c 'still uses actions/checkout@v7 UNPINNED -- the incoming copy pins it: actions/checkout@3d3c42e5')"
  chk "an untouched product file is still replaced" 1 \
      "$(grep -c 'ai/CODING.md' "$ADOPT/.codex")"
  # tools/ is force-installed: the adopter's `echo LOCAL EDIT` must NOT survive. The
  # existing "product file replaced" check above asserts `echo v2` arrived; this asserts
  # the local edit is gone, which is the half that would pass by accident.
  chk "tools/ ignores local edits (force-install)" 0 \
      "$(grep -c 'LOCAL EDIT' "$ADOPT/tools/session_journal.sh")"

  # ---- 3b. sidecars do not accumulate --------------------------------------------------
  # A divergence is usually PERMANENT, so writing one `.scaffold-<version>` per release
  # grows without bound. Measured 2026-08-08 in Robiton/localcoder: 21 committed sidecars,
  # 3 files across 7 releases, for three decisions that were each made once. Only the
  # newest is useful — it is what you diff against — and every older one is our own
  # released bytes, recoverable with `git show <tag>:<path>`.
  chk "only the newest sidecar for that file remains" 1 \
      "$(ls "$ADOPT"/.editorconfig.scaffold-* 2>/dev/null | wc -l | tr -d ' ')"
  # Plant two older ones and re-run: they must go, and the current one must stay.
  : > "$ADOPT/.editorconfig.scaffold-1.5.0.20260115.0000"
  : > "$ADOPT/.editorconfig.scaffold-1.9.9.20260120.0000"
  printf 'indent_size = 8\n' >> "$ADOPT/.editorconfig"     # still diverged, so still kept
  printf '1.0.0.20260101.0000\n' > "$ADOPT/.scaffold-version"
  ( cd "$ADOPT" && git add -A >/dev/null && git commit -qm sidecars )
  _sc_out="$( ( cd "$ADOPT" && $RUN --from "$UP" --to 2.0.0.20260201.0000 ) 2>&1 )"
  chk "superseded sidecars are removed"       1 \
      "$(ls "$ADOPT"/.editorconfig.scaffold-* 2>/dev/null | wc -l | tr -d ' ')"
  # ---- 3c. the closing instruction must not commit the sidecar it just wrote (#239) -----
  # `git add -A` stages the sidecar, the printed commit lands it, and conflict_scan.sh fails
  # the NEXT preflight — two gates away from the line that caused it. Reproduced upgrading
  # Robiton/localcoder 0.73.0 -> 0.74.0. This run keeps .editorconfig, so a sidecar exists.
  # The old unconditional one-liner is the thing that must be gone. `git add -A` still appears
  # further down, AFTER the removal step, which is correct — asserting it never appears would
  # fail on the fixed version and pass on one that prints nothing at all.
  chk "the unconditional 'Review and commit' one-liner is withheld" 0 \
      "$(printf '%s\n' "$_sc_out" | grep -c 'Review and commit:' || true)"
  # COUNT, never `grep -q`. Under `set -o pipefail` grep -q exits at the first match,
  # printf takes SIGPIPE, and the pipeline reports 141 -- so the assertion fails BECAUSE
  # the string was found. The line immediately above already uses `grep -c` for exactly
  # this reason; these three did not, and failed intermittently for a day (#306).
  chk "and the adopter is warned off a bare add" 1 \
      "$( [ "$(printf '%s\n' "$_sc_out" | grep -c "DO NOT run a bare" || true)" != "0" ] && echo 1 || echo 0 )"
  chk "the closing text names the sidecar and how to remove it" 1 \
      "$( [ "$(printf '%s\n' "$_sc_out" | grep -c 'git rm .*\.scaffold-' || true)" != "0" ] && echo 1 || echo 0 )"
  chk "and it offers a pathspec that excludes sidecars" 1 \
      "$( [ "$(printf '%s\n' "$_sc_out" | grep -c "':!\*\.scaffold-\*'" || true)" != "0" ] && echo 1 || echo 0 )"
  # NOT LOAD-BEARING, AND SAYING SO RATHER THAN IMPLYING OTHERWISE. Passing the keep
  # argument is belt-and-braces: the `cp` immediately after would recreate the current
  # sidecar anyway, so an injected defect that drops it too still passes every case here.
  # It stays because it makes drop_sidecars correct on its own terms and survives a future
  # reordering — but this assertion proves the END STATE, not the argument.
  chk "the one kept is the CURRENT release"   1 \
      "$([ -f "$ADOPT/.editorconfig.scaffold-2.0.0.20260201.0000" ] && echo 1 || echo 0)"
  # And when the divergence ENDS, the sidecar goes with it — otherwise the adopter is
  # prompted forever about a decision they already made by taking the upstream file.
  cp "$ADOPT/.editorconfig.scaffold-2.0.0.20260201.0000" "$ADOPT/.editorconfig"
  printf '1.0.0.20260101.0000\n' > "$ADOPT/.scaffold-version"
  ( cd "$ADOPT" && git add -A >/dev/null && git commit -qm converged )
  ( cd "$ADOPT" && $RUN --from "$UP" --to 2.0.0.20260201.0000 ) >/dev/null 2>&1
  chk "a resolved divergence leaves no sidecar" 0 \
      "$(ls "$ADOPT"/.editorconfig.scaffold-* 2>/dev/null | wc -l | tr -d ' ')"
  # Restore the diverged state so later cases see the fixture they were written against.
  printf 'indent_size = 4\n' >> "$ADOPT/.editorconfig"
  ( cd "$ADOPT" && git add -A >/dev/null && git commit -qm rediverged )

  # ---- 3d. a Dependabot bump is not an edit ----------------------------------------------
  # The adopter's workflow is r1 with only its checkout pin moved -- what Dependabot does.
  # Keeping it as "you edited it" cuts that repo off from every later template change.
  _wf=.github/workflows/scaffold-check.yml
  cp "$ADOPT/$_wf" "$T/wf.kept"; cp "$ADOPT/$_wf.scaffold-2.0.0.20260201.0000" "$T/wf.side" 2>/dev/null || :
  ( cd "$UP" && git show "1.0.0.20260101.0000:$_wf" ) \
    | sed -E 's/checkout@v7$/checkout@0123456789abcdef0123456789abcdef01234567 # v8/' > "$ADOPT/$_wf"
  printf '1.0.0.20260101.0000\n' > "$ADOPT/.scaffold-version"
  ( cd "$ADOPT" && git add -A >/dev/null && git commit -qm dependabot-bump )
  _pb_out="$( ( cd "$ADOPT" && $RUN --from "$UP" --to 2.0.0.20260201.0000 ) 2>&1 )"
  chk "a workflow differing only in pins takes the incoming copy" 1 \
      "$( ( cd "$UP" && git show "2.0.0.20260201.0000:$_wf" ) | cmp -s - "$ADOPT/$_wf" && echo 1 || echo 0)"
  chk "  and says it was a pin-only difference" 1 \
      "$( [ "$(printf '%s\n' "$_pb_out" | grep -c 'only in action pins' || true)" != "0" ] && echo 1 || echo 0 )"
  chk "  and leaves no sidecar for it" 0 \
      "$(ls "$ADOPT/$_wf".scaffold-* 2>/dev/null | wc -l | tr -d ' ')"
  chk "pins_only_differ: a real edit is not pin-only" 1 \
      "$(pins_only_differ "$T/wf.kept" "$ADOPT/$_wf" && echo 0 || echo 1)"
  chk "pins_only_differ: identical files are not pin-only" 1 \
      "$(pins_only_differ "$ADOPT/$_wf" "$ADOPT/$_wf" && echo 0 || echo 1)"
  cp "$T/wf.kept" "$ADOPT/$_wf"; [ -f "$T/wf.side" ] && cp "$T/wf.side" "$ADOPT/$_wf.scaffold-2.0.0.20260201.0000"
  ( cd "$ADOPT" && git add -A >/dev/null && git commit -qm rediverged-wf )

  # ---- 4. idempotent -------------------------------------------------------------------
  ( cd "$ADOPT" && git add -A >/dev/null && git commit -qm upgraded )
  out="$( cd "$ADOPT" && $RUN --from "$UP" --to 2.0.0.20260201.0000 2>&1 )"
  case "$out" in *"already on"*) chk "re-run is a no-op" 1 1 ;; *) chk "re-run is a no-op" 1 0 ;; esac

  # ---- 5. an untagged build stamp falls back to the newest release at or below ----------
  printf '2.0.5.20260215.0000\n' > "$ADOPT/.scaffold-version"   # never tagged: tracking main
  ( cd "$ADOPT" && git add -A >/dev/null && git commit -qm stamp )
  out="$( cd "$ADOPT" && $RUN --from "$UP" --to 2.0.0.20260201.0000 --dry-run 2>&1 )"
  case "$out" in
    *"is not a tag"*) chk "untagged build stamp falls back to a release" 1 1 ;;
    *)                chk "untagged build stamp falls back to a release" 1 0 ;;
  esac

  # ---- 6. a genuine collision IS reported, not guessed ----------------------------------
  printf '1.0.0.20260101.0000\n' > "$ADOPT/.scaffold-version"
  python3 - "$ADOPT/ai/CODING.md" <<'PY'
import sys
p = sys.argv[1]; s = open(p).read()
# edit the SAME region release 2 appends to
open(p, "w").write(s.replace("## Docstrings\nAlways.\n", "## Docstrings\nOnly public API.\n"))
PY
  ( cd "$ADOPT" && git add -A >/dev/null && git commit -qm collide )
  out="$( cd "$ADOPT" && $RUN --from "$UP" --to 2.0.0.20260201.0000 2>&1 )"
  local rc=$?
  case "$out" in
    *CONFLICT*) chk "a real collision is handed over, not guessed" 1 1 ;;
    *)          chk "a real collision is handed over, not guessed" 1 0 ;;
  esac
  chk "conflicts exit non-zero" 1 "$([ "$rc" -ne 0 ] && echo 1 || echo 0)"

  # ---- 6b. KNOWN LIMITATION, tested so it stays known ------------------------------------
  # If upstream ever appends a row DIRECTLY below the command-table row an adopter filled
  # in, a textual three-way merge has no separating context and must conflict. It has never
  # happened in this repo's history, so it is documented rather than engineered around —
  # but it is asserted, so the day it changes, this says so instead of surprising someone.
  ( cd "$ADOPT" && git checkout -q . && git clean -qfd )
  printf '1.0.0.20260101.0000\n' > "$ADOPT/.scaffold-version"
  printf '\n| Lint | `ruff check` |\n' >> "$UP/AGENTS.md"
  ( cd "$UP" && git add -A >/dev/null && git commit -qm r3 && git tag 3.0.0.20260301.0000 )
  ( cd "$ADOPT" && git add -A >/dev/null && git commit -qm reset >/dev/null 2>&1 )
  out="$( cd "$ADOPT" && $RUN --from "$UP" --to 3.0.0.20260301.0000 2>&1 )"
  case "$out" in
    *"AGENTS.md"*CONFLICT*) chk "adjacent table-row edit conflicts (known, documented)" 1 1 ;;
    *)                      chk "adjacent table-row edit conflicts (known, documented)" 1 0 ;;
  esac

  # ---- 7. refuses to act on a non-adoption ----------------------------------------------
  mkdir -p "$T/bare" && ( cd "$T/bare" && git init -q . )
  ( cd "$T/bare" && $RUN --from "$UP" --to 2.0.0.20260201.0000 ) >/dev/null 2>&1
  chk "refuses a directory with no ai/" 1 $?

  # ---- 8. the scaffold's own repo is identified by ALL THREE signals (#113) --------------
  # 23 checks and none of them asked what "the scaffold's own repository" means. Keying on
  # mirror-sync.yml alone stranded Robiton/localcoder — which mirrors too — five releases
  # behind, silently, because the refusal message is confident and reads as "nothing to do".
  #
  # Both directions, because a discriminator has two ways to be wrong and the old one was
  # only ever tested in the direction that passed.
  mk_sibling() {   # an adoption that happens to mirror: 1 signal of 3
    rm -rf "$T/sib" && mkdir -p "$T/sib" && ( cd "$T/sib" && git archive --remote=. 2>/dev/null || true )
    tar -x -C "$T/sib" -f "$T/r1.tar"
    mkdir -p "$T/sib/.github/workflows"
    printf 'name: Mirror\n' > "$T/sib/.github/workflows/mirror-sync.yml"
    ( cd "$T/sib" && git init -q . && git config user.email a@b.c && git config user.name t \
      && git add -A >/dev/null && git commit -qm sib )
  }
  mk_sibling
  ( cd "$T/sib" && $RUN --from "$UP" --to 2.0.0.20260201.0000 ) >/dev/null 2>&1
  chk "a mirroring sibling product IS upgradeable" 0 $?

  # And the scaffold itself must still be refused — the check has to keep working.
  mkdir -p "$T/self/.github/workflows" && tar -x -C "$T/self" -f "$T/r1.tar"
  mkdir -p "$T/self/overlays/python-script" && printf '# O\n' > "$T/self/overlays/python-script/STANDARDS.md"
  printf '# Overview\n' > "$T/self/OVERVIEW.md"
  printf 'name: Mirror\n' > "$T/self/.github/workflows/mirror-sync.yml"
  ( cd "$T/self" && git init -q . && git config user.email a@b.c && git config user.name t \
    && git add -A >/dev/null && git commit -qm self )
  ( cd "$T/self" && $RUN --from "$UP" --to 2.0.0.20260201.0000 ) >/dev/null 2>&1
  chk "the scaffold's own repo is still refused" 1 $?

  # ---- 8b. AGENT-VISIBLE RULE CHANGES ARE NAMED, NOT COUNTED (#118) ----------------------
  # A merge into these five files changes what every agent DOES, and the only signal used to
  # be a line count. Measured on the real 0.5.0 -> 0.5.4 transition: an adopter was told
  # `ai/SECURITY.md  clean (+79 upstream lines)` while the merge delivered "No secrets in
  # prompts or agent memory" — and the next thing to mention it was his own agent refusing a
  # commit he had been making for months.
  rm -rf "$T/rules" && mkdir -p "$T/rules"
  tar -x -C "$T/rules" -f "$T/r1.tar"
  ( cd "$T/rules" && git init -q . && git config user.email a@b.c && git config user.name t \
    && git add -A >/dev/null && git commit -qm adopt )
  rules_out="$( cd "$T/rules" && $RUN --from "$UP" --to 2.0.0.20260201.0000 --dry-run 2>&1 )"
  case "$rules_out" in
    *"AGENT-VISIBLE RULES CHANGED"*) chk "agent-visible rule changes are announced" 1 1 ;;
    *)                               chk "agent-visible rule changes are announced" 1 0 ;;
  esac
  # And it must name the SECTION, since the whole failure was a number that said nothing.
  case "$rules_out" in
    *"## Versioning"*) chk "the arriving section is named, not counted" 1 1 ;;
    *)                 chk "the arriving section is named, not counted" 1 0 ;;
  esac
  # These files state most rules as **bold**, not as headings. Matching headings alone
  # silently under-covered the common case.
  case "$rules_out" in
    *"**Never commit a rendered secret.**"*) chk "a bold rule lead-in is named too" 1 1 ;;
    *)                                       chk "a bold rule lead-in is named too" 1 0 ;;
  esac

  # ---- 9. scaffold:owns-localcoder suppresses vendoring localcoder into its own repo (#115)
  # Both directions on the SAME fixture, changed only by the marker — anything else and the
  # test could pass for a reason that has nothing to do with the declaration.
  printf 'echo localcoder\n' > "$UP/tools/localcoder"
  printf 'echo bench\n' > "$UP/tools/localcoder_bench.py"
  printf 'sha256 = deadbeef\n' > "$UP/tools/.localcoder-sync"
  ( cd "$UP" && git add -A >/dev/null && git commit -qm r3 \
    && git tag -f 2.0.0.20260201.0000 >/dev/null 2>&1 )

  mk_owner() {   # an adoption that ships localcoder itself
    rm -rf "$T/own" && mkdir -p "$T/own/src/localcoder"
    tar -x -C "$T/own" -f "$T/r1.tar"
    printf 'echo the real product\n' > "$T/own/src/localcoder/localcoder"
    printf 'sha256 = mine\n' > "$T/own/tools/.localcoder-sync"
    [ "$1" = "declared" ] && printf '\n<!-- scaffold:owns-localcoder -->\n' >> "$T/own/ai/STANDARDS.md"
    ( cd "$T/own" && git init -q . && git config user.email a@b.c && git config user.name t \
      && git add -A >/dev/null && git commit -qm own )
  }

  mk_owner declared
  ( cd "$T/own" && $RUN --from "$UP" --to 2.0.0.20260201.0000 ) >/dev/null 2>&1
  # THREE CASES RETIRED HERE, AND THE REASON IS WORTH MORE THAN THE CASES (W-15, DEC-20).
  #
  # They asserted the owns-localcoder exclusion in both directions: with the marker, no
  # vendored tools/localcoder arrives and the repo keeps its own .localcoder-sync; without
  # it, the vendored copy MUST still arrive or every adopter silently stops receiving
  # localcoder. All three were correct and all three now have no subject — the scaffold
  # ships no localcoder to vendor or to withhold.
  #
  # None of them was wrong. The change they were pointed at removed the property they
  # described, which is the third time this week a test has been retired rather than fixed
  # (check-not-requested-ok, and the DUAL_HOMED agreement assertion above). Retiring with a
  # note beats deleting, and beats leaving them passing vacuously against a fixture that
  # manufactures the file they look for.
  #
  # What replaces them is stronger and sits above: the release ships no localcoder
  # implementation AT ALL, asserted unconditionally, with no marker and no exemption list.

  # ---- executable bits under core.fileMode=false -----------------------------------------
  # Measured on the 0.15.0 upgrade: BOTH consumers recorded the newly force-installed
  # tools/conflict_scan.sh as 644 despite it arriving 755 on disk, because both had
  # core.fileMode=false (correctly — their filesystem reports 0700 for everything). Git
  # records a NEW file at 644 under that setting, discovery loops filter on `[ -x ]`, and
  # the tool's 15 cases would have been skipped in silence in both repos.
  local MT="$T/modes"
  rm -rf "$MT" && mkdir -p "$MT/tools"
  ( cd "$MT" && git init -q . && git config user.email a@b.c && git config user.name t \
                && git config core.fileMode false )
  printf '#!/usr/bin/env bash\necho ok\n' > "$MT/tools/already_right.sh"
  printf '#!/usr/bin/env bash\necho ok\n' > "$MT/tools/newly_added.sh"
  printf 'not a script\n'                 > "$MT/tools/README.md"
  chmod +x "$MT/tools/already_right.sh" "$MT/tools/newly_added.sh"
  ( cd "$MT" && git add -A >/dev/null 2>&1 && git update-index --chmod=+x tools/already_right.sh )
  local flagged
  flagged="$( cd "$MT" && tools_recorded_non_executable | tr '\n' ' ' )"
  chk "flags a tool git recorded 644"        1 "$(printf '%s' "$flagged" | grep -c newly_added.sh)"
  chk "leaves a correctly recorded tool"     0 "$(printf '%s' "$flagged" | grep -c already_right.sh)"
  # A .md in tools/ has no shebang and is not a tool; flagging it would train people to
  # ignore the warning, which is the failure this repo names about warnings generally.
  chk "does not flag a non-script in tools/" 0 "$(printf '%s' "$flagged" | grep -c README.md)"
  # UNTRACKED IS THE COMMON CASE right after a force-install and must be flagged: that is
  # precisely the moment before `git add` gives it the wrong mode forever.
  printf '#!/usr/bin/env bash\necho new\n' > "$MT/tools/untracked.sh"
  chmod +x "$MT/tools/untracked.sh"
  flagged="$( cd "$MT" && tools_recorded_non_executable | tr '\n' ' ' )"
  chk "flags an untracked tool too"          1 "$(printf '%s' "$flagged" | grep -c untracked.sh)"

  # ---- #252: RETIRED FILES ARE REMOVED, EDITED ONES ARE KEPT AND NAMED -----------------
  # r1 shipped both; r2 ships neither. The adoption edits one of them.
  # Earlier cases already advanced this adoption to 2.0.0, so rewind it — otherwise the
  # upgrade short-circuits with "already on ..." and this case passes without running.
  printf '1.0.0.20260101.0000\n' > "$ADOPT/.scaffold-version"
  printf 'retired, untouched\n' > "$ADOPT/tools/gone_clean.sh"
  printf 'MINE — I changed this\n' > "$ADOPT/tools/gone_edited.sh"
  chmod +x "$ADOPT/tools/gone_clean.sh" "$ADOPT/tools/gone_edited.sh"
  # #253: two files NEITHER release ships — the pre-baseline case the tree diff is blind to.
  # One still matches its last-shipped hash (untouched -> removable); one does not.
  printf 'an older shipped revision\n' > "$ADOPT/tools/prebaseline.sh"
  printf 'I changed this\n' > "$ADOPT/tools/prebaseline_edited.sh"
  printf 'long gone\n' > "$ADOPT/tools/lc_vendored.sh"
  chmod +x "$ADOPT/tools/prebaseline.sh" "$ADOPT/tools/prebaseline_edited.sh"
  ( cd "$ADOPT" && git add -A >/dev/null 2>&1 && git -c user.email=t@t -c user.name=t commit -qm retfix ) >/dev/null 2>&1

  # THE DRY RUN MUST SHOW A DESTRUCTIVE STEP BEFORE IT FIRES, and must fire nothing. Raised
  # by the adopter: a removal nobody can preview is one nobody can refuse.
  _dry_ret="$( cd "$ADOPT" && $RUN --from "$UP" --to 2.0.0.20260201.0000 --dry-run 2>&1 )"
  case "$_dry_ret" in *"would remove"*prebaseline.sh*) chk "dry run PREVIEWS the removal (#253)" 1 1 ;;
                      *)                               chk "dry run PREVIEWS the removal (#253)" 1 0 ;; esac
  chk "  and the dry run removed nothing" 1 "$([ -f "$ADOPT/tools/prebaseline.sh" ] && echo 1 || echo 0)"

  _ret_out="$( cd "$ADOPT" && $RUN --from "$UP" --to 2.0.0.20260201.0000 2>&1 )"
  chk "an unmodified retired file is REMOVED"        0 "$([ -f "$ADOPT/tools/gone_clean.sh" ] && echo 1 || echo 0)"
  chk "an EDITED retired file is kept"               1 "$([ -f "$ADOPT/tools/gone_edited.sh" ] && echo 1 || echo 0)"
  case "$_ret_out" in *gone_edited.sh*) chk "  ...and is NAMED, not silently left" 1 1 ;;
                      *)                chk "  ...and is NAMED, not silently left" 1 0 ;; esac
  case "$_ret_out" in *"retired upstream"*) chk "  ...and the removal is reported"  1 1 ;;
                      *)                    chk "  ...and the removal is reported"  1 0 ;; esac
  # ASSERT THE CORRECT WORDING IS PRESENT, not that a version string is globally absent —
  # the banner legitimately names the baseline, so the first version of this check matched
  # its own header. What matters is that the MANIFEST section explains itself by what the
  # scaffold shipped rather than by a baseline that never held the file, and that the KEPT
  # message makes no claim about what the adopter did.
  case "$_ret_out" in
    *"matches a revision this scaffold shipped"*)
      chk "manifest removal explains itself without the baseline (#255)" "true" "true" ;;
    *) chk "manifest removal explains itself without the baseline (#255)" "true" "MISSING" ;;
  esac
  case "$_ret_out" in
    *"matches no revision this scaffold shipped"*)
      chk "  and a kept file is not accused of being edited" "true" "true" ;;
    *) chk "  and a kept file is not accused of being edited" "true" "MISSING" ;;
  esac
  chk "a PRE-BASELINE retired file is removed (#253)" 0 "$([ -f "$ADOPT/tools/prebaseline.sh" ] && echo 1 || echo 0)"
  chk "  but an EDITED pre-baseline file is kept"     1 "$([ -f "$ADOPT/tools/prebaseline_edited.sh" ] && echo 1 || echo 0)"
  chk "a vendored localcoder file is removed from an ordinary adopter" 0 "$([ -f "$ADOPT/tools/lc_vendored.sh" ] && echo 1 || echo 0)"
  rm -f "$ADOPT/tools/prebaseline_edited.sh"
  rm -f "$ADOPT/tools/gone_edited.sh"
  ( cd "$ADOPT" && git add -A >/dev/null 2>&1 && git -c user.email=t@t -c user.name=t commit -qm retclean ) >/dev/null 2>&1

  # THE REPOSITORY THAT SHIPS LOCALCODER KEEPS THE SAME FILE. Same manifest, same untouched
  # content, and the only difference is the declaration.
  printf '1.0.0.20260101.0000\n' > "$ADOPT/.scaffold-version"
  printf 'long gone\n' > "$ADOPT/tools/lc_vendored.sh"
  cp "$ADOPT/ai/STANDARDS.md" "$T/standards_before_owns"
  printf '\n<!-- scaffold:owns-localcoder -->\n' >> "$ADOPT/ai/STANDARDS.md"
  ( cd "$ADOPT" && git add -A >/dev/null 2>&1 && git -c user.email=t@t -c user.name=t commit -qm owns ) >/dev/null 2>&1
  _own_out="$( cd "$ADOPT" && $RUN --from "$UP" --to 2.0.0.20260201.0000 2>&1 )"
  chk "  but KEPT where scaffold:owns-localcoder is declared" 1 "$([ -f "$ADOPT/tools/lc_vendored.sh" ] && echo 1 || echo 0)"
  case "$_own_out" in *"they are the product"*) chk "  ...and the upgrade says why" 1 1 ;;
                      *)                        chk "  ...and the upgrade says why" 1 0 ;; esac
  rm -f "$ADOPT/tools/lc_vendored.sh"
  cp "$T/standards_before_owns" "$ADOPT/ai/STANDARDS.md"
  ( cd "$ADOPT" && git add -A >/dev/null 2>&1 && git -c user.email=t@t -c user.name=t commit -qm unowns ) >/dev/null 2>&1

  # ---- 9. THE gh PATH: SHA256SUMS AND THE RELEASE FALLBACK (report item 15) -------------
  # Every case above uses --from. This one fetches through a fake gh, the way an adopter
  # does: tarballs from `git archive`, a release asset only when GH_SUMS names a file.
  mkdir -p "$T/ghbin"
  cat > "$T/ghbin/gh" <<'EOF_FAKE_GH'
#!/bin/sh
case "$*" in
  "release view"*) [ -n "${GH_LATEST:-}" ] && { echo "$GH_LATEST"; exit 0; }
                   echo '{"message":"Not Found","status":"404"}'; exit 1 ;;
  *"releases?per_page=1"*) echo "${GH_NREL:-1}" ;;
  *"/tags"*) git -C "$GH_UP" tag ;;
  *"/tarball/"*) for a in "$@"; do t="$a"; done
                 git -C "$GH_UP" archive --format=tar.gz --prefix=up/ "${t##*/tarball/}" ;;
  "release download"*)
    [ -n "${GH_SUMS:-}" ] || { echo "release asset not found" >&2; exit 1; }
    out=""; prev=""
    for a in "$@"; do [ "$prev" = "--output" ] && out="$a"; prev="$a"; done
    cp "$GH_SUMS" "$out" ;;
  *) echo '{"message":"Not Found","status":"404"}'; exit 1 ;;
esac
EOF_FAKE_GH
  chmod +x "$T/ghbin/gh"
  mkdir -p "$T/r2tree"
  ( cd "$UP" && git archive 2.0.0.20260201.0000 ) | ( cd "$T/r2tree" && tar xf - )
  scaffold_sums make "$T/r2tree" > "$T/sums.good"
  sed '1s/^./0/' "$T/sums.good" > "$T/sums.bad"
  [ "$(head -c1 "$T/sums.good")" = 0 ] && sed '1s/^./1/' "$T/sums.good" > "$T/sums.bad"
  _ghrun() {  # _ghrun <dir> <dry|wet> [VAR=value...]: the upgrader through the fake gh, no --from
    local _d="$1" _m="$2"; shift 2
    ( cd "$_d" && env -u SCAFFOLD_UPGRADE_REEXEC -u SCAFFOLD_UPGRADE_ORIGIN \
        PATH="$T/ghbin:$PATH" GH_UP="$UP" SCAFFOLD_UPSTREAM=acme/scaffold "$@" \
        bash "$SELF" ${_m:+$([ "$_m" = dry ] && echo --dry-run)} 2>&1 )
  }
  rm -rf "$T/gh"; cp -R "$ADOPT" "$T/gh"
  printf '1.0.0.20260101.0000\n' > "$T/gh/.scaffold-version"
  ( cd "$T/gh" && git add -A >/dev/null 2>&1 && git -c user.email=t@t -c user.name=t commit -qm r1 ) >/dev/null 2>&1
  _o="$(_ghrun "$T/gh" dry GH_LATEST=2.0.0.20260201.0000 GH_SUMS="$T/sums.good")"
  case "$_o" in *"matches its release SHA256SUMS"*) chk "gh path: a tree matching its SHA256SUMS is accepted" 1 1 ;;
    *) chk "gh path: a tree matching its SHA256SUMS is accepted" 1 0; printf '%s\n' "$_o" | tail -3 ;; esac
  _o="$(_ghrun "$T/gh" wet GH_LATEST=2.0.0.20260201.0000 GH_SUMS="$T/sums.bad")"; _n=$?
  case "$_n:$_o" in [1-9]*"does NOT match"*) chk "gh path: a tree that differs from its SHA256SUMS stops" 1 1 ;;
    *) chk "gh path: a tree that differs from its SHA256SUMS stops" 1 0 ;; esac
  chk "  ...and nothing was written" 1.0.0.20260101.0000 "$(tr -d '[:space:]' < "$T/gh/.scaffold-version")"
  _o="$(_ghrun "$T/gh" dry GH_LATEST=2.0.0.20260201.0000)"
  case "$_o" in *"UNVERIFIED"*) chk "gh path: a release with no SHA256SUMS is named UNVERIFIED" 1 1 ;;
    *) chk "gh path: a release with no SHA256SUMS is named UNVERIFIED" 1 0 ;; esac
  _o="$(_ghrun "$T/gh" dry GH_NREL=1)"; _n=$?
  case "$_n:$_o" in [1-9]*"it has releases"*) chk "gh path: no latest release where releases exist stops" 1 1 ;;
    *) chk "gh path: no latest release where releases exist stops" 1 0; printf '%s\n' "$_o" | head -8 ;; esac
  _o="$(_ghrun "$T/gh" dry GH_NREL=0)"
  case "$_o" in *"->  3.0.0.20260301.0000"*) chk "gh path: an upstream with no releases takes the newest tag" 1 1 ;;
    *) chk "gh path: an upstream with no releases takes the newest tag" 1 0; printf '%s\n' "$_o" | tail -3 ;; esac
  _o="$(_ghrun "$T/gh" dry SCAFFOLD_UPSTREAM=../evil GH_LATEST=2.0.0.20260201.0000)"; _n=$?
  case "$_n:$_o" in [1-9]*"not an owner/repo"*) chk "gh path: an upstream that is not owner/repo stops" 1 1 ;;
    *) chk "gh path: an upstream that is not owner/repo stops" 1 0 ;; esac

  rm -rf "$T"
  echo ""

  if [ "$fails" -eq 0 ]; then echo "  all checks passed"; return 0; fi
  echo "  $fails check(s) FAILED"; return 1
}

if [ "$DO_SELFTEST" = "1" ]; then selftest; exit $?; fi

# ------------------------------------------------------------------ file classes
#
# PRODUCT  replaced wholesale — no adopter content by construction.
# MERGE    three-way merged — product documents that adopters legitimately edit.
# NEVER    never written. Listed explicitly rather than "everything else", because a
#          default of "touch it" is how an upgrade eats someone's session history.
#
#          "No adopter content BY CONSTRUCTION" is a claim about a file, and this list got
#          it wrong twice from the same cause. AGENTS.md was caught before release only
#          because `setup.sh --check` fails on its unfilled placeholders — a CHECKER
#          pointed at it. Nothing points at the rest, so nothing re-examined them, and
#          `.gitattributes` shipped here for four months while adopters kept Git LFS
#          patterns in it (#125). The class is now handled two ways rather than by
#          predicting which files adopters edit: `.gitattributes` moved to UNION below,
#          and every remaining PRODUCT file is checked against the copy it SHIPPED as
#          before being replaced. See copy_product().
PRODUCT_FILES="
.cursorrules .windsurfrules .codex .editorconfig
sync-check.sh setup.sh adopt.ps1
.cursor/rules/base.mdc
.gitleaks.toml
.github/copilot-instructions.md .github/instructions/general.instructions.md
.github/PULL_REQUEST_TEMPLATE.md
.github/workflows/scaffold-check.yml
.githooks/pre-push
.githooks/post-checkout .githooks/post-commit .githooks/post-merge
.claude/settings.hooks.json .claude/settings.pretooluse-guard.example.json
.agents/skills/verify/SKILL.md
"
# `.claude/` AND `.agents/` WERE FROZEN AT WHATEVER VERSION THE ADOPTER COPIED (#291).
# scaffold_upgrade.sh did not touch either directory at all, so every hook fix this project
# has shipped — the PreCompact hook, the `--wire` fix, the un-silencing of the session hook,
# all of the 0.88.x work — reached exactly zero adopters through an upgrade. Nothing said
# so, because nothing compared what an adoption RECEIVES against what an upgrade REFRESHES;
# tools/adoption_manifest.sh --check now does, and this line is what it found.
#
# `.claude/settings.json` IS DELIBERATELY NOT HERE. That file is the adopter's own Claude
# Code configuration and may hold permissions, MCP servers and hooks we know nothing about.
# `settings.hooks.json` is the CANONICAL scaffold set and is ours; delivering it makes
# `setup.sh --check` say "missing hooks (…) — re-run ./setup.sh", which is a report the
# adopter acts on rather than an edit made to their config behind their back.
# The `.example.json` guard ships alongside it and stays inert by its name, as designed.
# `.githooks/pre-push` SHIPS BUT IS NOT ACTIVATED. Delivering the file is the whole point of
# #171 — `.git/hooks` is not versioned and does not come with a clone, so a hook nobody can
# receive is a rule enforced on whoever happened to install it. But nothing here runs
# `git config core.hooksPath`: that is `setup.sh --install-hooks`, by hand, per machine.
# An upgrade that silently started gating pushes would be the guard ai/SECURITY.md warns
# about — one that blocks legitimate work, gets ripped out, and then protects nothing.
# `overlays/` is deliberately NOT here. setup.sh appends the chosen overlay's content into
# ai/STANDARDS.md and ai/CODING.md at init; the overlays directory itself is not something
# an adoption carries, and installing it on upgrade would add a tree nobody asked for.
# INSTALL: added even if the project never had them — the CI workflow CALLS tools/, so
#   shipping a newer workflow without them is how you get a warning instead of a check.
# REFRESH: only files that already exist are updated. An upgrade should not push a docs/
#   tree into a project that deliberately never took one.
PRODUCT_DIRS_INSTALL="tools"
PRODUCT_DIRS_REFRESH="docs"
# ...except benchmark data, which is per-machine. REFRESH means "update files that already
# exist", so an adopter who has run a benchmark HAS docs/benchmarks/localcoder-benchmarks.md
# — and without this exclusion the next upgrade would overwrite their measurements with the
# maintainer's. The runbook is a normal doc and still refreshes; only the data is excluded.
PRODUCT_PATH_EXCLUDE="docs/benchmarks/localcoder-benchmarks|docs/benchmarks/localcoder-eval|docs/benchmarks/reference/"
# A REPO THAT OWNS localcoder MUST NOT BE HANDED A VENDORED COPY OF IT (#115).
#
# `Robiton/localcoder` ships the product at `src/localcoder/localcoder`. Installing
# `tools/localcoder` there does more than duplicate it — `localcoder_sync.py` resolves
# CANDIDATES in order and `tools/localcoder` comes FIRST, so the drift check would quietly
# start verifying the vendored copy and stop watching the product. `audit_localcoder.sh`
# resolves `$REPO/tools/localcoder` too, so the behavioural suite would move off the product
# as well. Both go green while measuring the wrong file, which is this project's
# most-repeated defect.
#
# `tools/.localcoder-sync` is excluded for the same reason `version` is: it records THIS
# repo's own path and stamp (`src/localcoder/localcoder v0.10.1...`), and the scaffold's
# copy names its own.
#
# Declared, never inferred — the absence of the marker must keep vendoring normally, or
# every adopter silently stops receiving localcoder.
# THIS LIST AND localcoder_sync.py's DUAL_HOMED MUST AGREE, and they are two literals
# in two files — the shape this repo keeps being bitten by. api_digest.py was added to
# DUAL_HOMED on 2026-08-09 and NOT here, so the very next upgrade of Robiton/localcoder
# vendored tools/api_digest.py into the repo that ships the product at
# src/localcoder/api_digest.py. Deriving the list would break the rule the comment
# above states ("declared, never inferred" — an inferred list that comes back empty
# silently stops every adopter receiving localcoder), so the literal stays and
# --selftest asserts the two agree.
if grep -qE '^<!--[[:space:]]*scaffold:owns-localcoder[[:space:]]*-->[[:space:]]*$' ai/STANDARDS.md 2>/dev/null; then
  # APPEND ONLY IF THERE IS SOMETHING TO APPEND. OWNS_LOCALCODER_PATHS was deliberately
  # emptied above ("it simply has nothing left to do here") and this line kept concatenating
  # it anyway, leaving a TRAILING EMPTY ALTERNATIVE on the end of the regex.
  #
  # macOS /usr/bin/grep (BSD grep 2.6.0-FreeBSD) exits 2 on that -- "grep: empty
  # (sub)expression" -- so the guard below it,
  #
  #     printf '%s' "$rel" | grep -qE "$PRODUCT_PATH_EXCLUDE" && return 0
  #
  # never fired, and THE EXCLUSION SILENTLY STOPPED EXCLUDING. Harmless only by accident:
  # copy_product returns earlier when the path is absent from the new release, and the
  # scaffold currently ships nothing under docs/benchmarks/. The day it ships one, the
  # adopter's file is replaced by a guard written to protect it.
  #
  # The visible half was 100+ "grep: empty (sub)expression" lines sprayed into the MIDDLE of
  # the list of files being replaced, on every adopter upgrade -- which reads as a failure
  # and is exactly the A10 habit-forming noise this project files bugs about.
  #
  # An `if`, not `[ -n ... ] &&`: the && form returns 1 when the test fails, which is the
  # same shape that aborted setup.sh under set -e in v0.22.0.
  if [ -n "$OWNS_LOCALCODER_PATHS" ]; then
    PRODUCT_PATH_EXCLUDE="$PRODUCT_PATH_EXCLUDE|$OWNS_LOCALCODER_PATHS"
  fi
  OWNS_LOCALCODER=1
else
  OWNS_LOCALCODER=0
fi
# FAIL LOUDLY RATHER THAN EXCLUDE NOTHING. This guard costs one grep and turns a silent
# behaviour change into a refusal naming the value that caused it.
exclude_regex_sane "$PRODUCT_PATH_EXCLUDE" \
  || die "internal: PRODUCT_PATH_EXCLUDE is not a usable regex: $PRODUCT_PATH_EXCLUDE"
# AGENTS.md IS A MERGE FILE, NOT A PRODUCT FILE. The adoption guide called it "Standard
# hook — no project-specific content" and that is wrong: it carries the Project Commands
# table the adopter fills in, and setup.sh --check fails on unfilled placeholders. Copying
# it wholesale silently deletes every command the project documented.
# `.github/CONTRIBUTING.md` MOVED HERE FROM PRODUCT_FILES (#298). It is a prose document
# with a release checklist, and adopters legitimately add rows to that checklist —
# `Robiton/localcoder` carries three about `tests/audit_localcoder.sh`, a release gate no
# other adopter has because that repo ships the product the suite exercises.
#
# As a PRODUCT file it was replaced wholesale, so copy_product spotted the divergence and
# sidecarred it on EVERY upgrade: 0.89.0, 0.89.1 and 0.90.0 all produced an identical
# sidecar and an identical decision. The mechanism was working; the question was simply the
# wrong one to keep asking. A checklist both sides extend is what three-way merge is for.
#
# Same reasoning that moved AGENTS.md here, and the same shape #125 describes for
# `.gitattributes`: a file we see as MECHANISM and the adopter sees as CONTENT.
MERGE_FILES="AGENTS.md .github/CONTRIBUTING.md ai/STANDARDS.md ai/STANDARDS_EVIDENCE.md ai/OPERATIONS.md ai/CODING.md ai/SECURITY.md ai/PLANNING.md"
# .gitignore is a SET OF LINES, not prose, so a three-way merge is the wrong tool: both
# sides append entries and a textual merge calls that a conflict every single time
# (verified on the fixture — it did).
#
# .gitattributes IS THE SAME SHAPE, AND THAT WAS WRITTEN DOWN HERE BEFORE IT WAS ACTED ON.
# The sentence this comment used to end with — "the repo already reasons this way:
# .gitattributes gives SESSION.md/BACKLOG.md a union merge for exactly the same reason" —
# had the file in view as the MECHANISM that implements union merge, and never as CONTENT
# with an owner. It sat in PRODUCT_FILES fifty lines above, replaced wholesale.
#
# Measured (#125): an upgrade deleted four `filter=lfs` patterns, `* text=auto eol=lf` and
# a linguist rule from one adopter, exit 0, under a heading reading "no adopter content by
# construction". Twice in the same repository; the first time put 693 binaries (6.1 MB)
# into git history as raw blobs, which needs `git lfs migrate import` — a history rewrite —
# to undo. Git LFS does not error when a filter pattern disappears, it simply stops
# applying, so `git add`, the commit, and CI all stay green. The scaffold ships two lines
# in this file; everything else in it belongs to the project.
UNION_FILES=".gitignore .gitattributes"
NEVER_FILES="
ai/SESSION.md ai/BACKLOG.md ai/MEMORY.md ai/TEAM.md
ai/localcoder.config.json
version .github/CODEOWNERS CLAUDE.md
"

# ------------------------------------------------------------------ preconditions
git rev-parse --git-dir >/dev/null 2>&1 || \
  die "not a git repository. git IS the undo for this operation — refusing to run without it."

# Acting on the wrong directory is this tool's worst failure mode, so say which one it is
# and refuse anything that is obviously not an adoption.
[ -d ai ] || die "no ai/ directory here — '$ROOT' does not look like a scaffold adoption.
  Run this from the root of the project you want to upgrade."

# Upgrading the scaffold with itself is meaningless and would three-way merge the product
# against the product.
#
# ALL THREE SIGNALS, BECAUSE NO SINGLE ONE IS SOUND (#113). This keyed on `mirror-sync.yml`
# alone, described in this comment as "the clean discriminator: it exists only in the
# scaffold's own repo". It does not: `Robiton/localcoder` mirrors to the org space too, so
# this refused to run there and **stranded that repo five releases behind, silently** — the
# message is confident and wrong, so it reads as "nothing to do" rather than "this check is
# misfiring". A repo that quietly stops receiving upgrades looks exactly like a current one.
#
# The other direction is real too, which is why the old comment rejected `overlays/`:
# `setup.sh` does NOT delete `overlays/` or `OVERVIEW.md`, so a project generated from the
# GitHub template keeps them — and that project IS an adoption and must stay upgradeable.
#
# Requiring all three separates the cases by what each repo actually has:
#   the scaffold      overlays/ + OVERVIEW.md + mirror-sync.yml   -> 3, refuse
#   a template clone  overlays/ + OVERVIEW.md                     -> 2, upgrade
#   a sibling product mirror-sync.yml                             -> 1, upgrade
if [ -d overlays ] && [ -f OVERVIEW.md ] && [ -f .github/workflows/mirror-sync.yml ]; then
  # A REFUSAL MUST NAME THE VERSION THAT REFUSED (#130). This message reads as
  # "nothing to do", which is indistinguishable from success — and an OLDER copy of this
  # script emitted the very same sentence for a repo that merely MIRRORED upstream,
  # because the check keyed on mirror-sync.yml alone until 0.5.0. Robiton/localcoder took
  # that at face value and sat 13 releases behind, silently. The fix for that check ships
  # inside this file, so a stale copy cannot deliver its own replacement; the only exit is
  # a human re-fetching it, and nobody re-fetches a tool that reports success.
  die "this looks like the scaffold's own repository, not an adoption of it.
  There is nothing to upgrade here — changes land through a PR instead.

  If that is WRONG and this is a real adoption, this check is what to doubt first.
  This is scaffold_upgrade.sh $SELF_VERSION. Copies before 0.5.0 refused any repo
  carrying .github/workflows/mirror-sync.yml, including sibling product repos that
  legitimately mirror upstream (#113, #130). Re-fetch and re-run before believing it:
      gh api "repos/${UPSTREAM:-$UPSTREAM_DEFAULT}/contents/tools/scaffold_upgrade.sh?ref=main" \\
        --jq .content | base64 -d > tools/scaffold_upgrade.sh
  (gh, not curl: this repo is private, so raw.githubusercontent.com 404s — and curl -sS -o
   writes the 404 body into the file rather than failing. Check the result parses.)"
fi
say "  project: $ROOT"

if [ "$DRY" = "0" ] && [ "$FORCE" = "0" ] && [ -n "$(git status --porcelain 2>/dev/null)" ]; then
  warn "working tree is not clean."
  say  "     ai/SECURITY.md: never mutate state without a snapshot you have VERIFIED is"
  say  "     restorable. A clean tree is that snapshot — it makes 'git checkout .' a"
  say  "     complete undo for everything this does. Commit or stash first."
  say  "     (--force overrides, and then you own the recovery.)"
  exit 1
fi

[ -f .scaffold-version ] || die \
"no .scaffold-version, so there is no way to know which release you adopted.

  A three-way merge needs the file as it shipped in YOUR release as its base. Without it
  the only options are to overwrite your standards files or to skip them entirely, and
  both are worse than stopping.

  If you know which release you are on, write it and re-run:
      echo 0.4.0.20260709.0708 > .scaffold-version
  Otherwise run with --to and accept that only product-owned files will be updated."
FROM_TAG="$(tr -d '[:space:]' < .scaffold-version)"

# ------------------------------------------------------------------ resolve target
[ -n "$UPSTREAM" ] || [ -n "$FROM" ] || UPSTREAM="$(probe_upstream)"
[ -n "$FROM" ] || say "  upstream: $UPSTREAM"
if [ -z "$TO" ]; then
  if [ -n "$FROM" ]; then
    TO="$(git -C "$FROM" tag --sort=-v:refname 2>/dev/null | head -1)"
  elif command -v gh >/dev/null 2>&1; then
    # THROUGH newest_tag, WHICH PASSES ONLY A VERSION: whatever gh prints on a failure must
    # never become the tag this upgrade installs (the selftest's fake gh prints a 404 body).
    TO="$(gh release view --repo "$UPSTREAM" --json tagName --jq .tagName 2>/dev/null | newest_tag || true)"
    # THE MIRROR HAS TAGS AND NO RELEASES. release.sh tags only after every gate passed and
    # mirror-sync pushes every tag, so there the newest tag IS the newest release.
    # ...BUT ONLY WHERE THERE ARE NO RELEASES AT ALL (report item 15). The fallback used to
    # fire whenever the release query came back empty -- a network blip, a rate limit -- and
    # on an upstream that HAS releases the newest tag can be one whose publish never
    # finished. An exact "0" is required: gh prints a 404 body on stdout, and that is not 0.
    if [ -z "$TO" ]; then
      _nrel="$(gh api "repos/$UPSTREAM/releases?per_page=1" --jq 'length' 2>/dev/null || true)"
      if [ "$_nrel" = "0" ]; then
        TO="$(gh api --paginate "repos/$UPSTREAM/tags" --jq '.[].name' 2>/dev/null | newest_tag || true)"
      else
        die "could not read the latest release of $UPSTREAM, and it has releases, so the newest tag is not a stand-in. Re-run, or pass --to <tag>."
      fi
    fi
  fi
  [ -n "$TO" ] || die "could not determine the latest release. Pass --to <tag>, or --from <clone>."
fi

say ""
say "scaffold_upgrade — $FROM_TAG  ->  $TO"
[ "$DRY" = "1" ] && say "  (dry run: nothing will be written)"
say ""

if [ "$FROM_TAG" = "$TO" ]; then
  ok "already on $TO — nothing to do."
  exit 0
fi

# ------------------------------------------------------------------ materialise trees
WORK="$(mktemp -d "${TMPDIR:-/tmp}/scaffold_upgrade.XXXXXX")" || { echo "scaffold_upgrade: mktemp failed; stopping" >&2; exit 1; }; trap 'rm -rf "$WORK"' EXIT
BASE="$WORK/base"; NEW="$WORK/new"
mkdir -p "$BASE" "$NEW"

fetch_tree() {   # fetch_tree <tag> <dest>
  local tag="$1" dest="$2"
  if [ -n "$FROM" ]; then
    git -C "$FROM" rev-parse --verify --quiet "$tag" >/dev/null || return 1
    # DO NOT PIPE `git archive` INTO `tar`. Under `set -o pipefail`, bsdtar stops at the
    # end-of-archive marker without draining git's trailing padding, git takes SIGPIPE, and
    # the pipeline reports 141 — a hard failure on a fetch that actually succeeded. Third
    # time this exact interaction has bitten in one day (header_check's `grep -q`, the
    # audit's `printf | grep -q`), so: no pipes where the consumer can finish early.
    git -C "$FROM" archive "$tag" > "$WORK/t.tar" 2>/dev/null || return 1
    tar -x -C "$dest" -f "$WORK/t.tar" 2>/dev/null || return 1
    return 0
  fi
  # gh first: the scaffold repo may be private, and a bare curl to codeload 404s there
  # in a way that looks exactly like a bad tag.
  if command -v gh >/dev/null 2>&1; then
    if gh api "repos/$UPSTREAM/tarball/$tag" > "$WORK/t.tgz" 2>/dev/null; then
      tar -xz -C "$dest" --strip-components=1 -f "$WORK/t.tgz" 2>/dev/null && return 0
    fi
  fi
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "https://codeload.github.com/$UPSTREAM/tar.gz/refs/tags/$tag" > "$WORK/t.tgz" 2>/dev/null \
      && tar -xz -C "$dest" --strip-components=1 -f "$WORK/t.tgz" 2>/dev/null && return 0
  fi
  return 1
}

# THE RECORDED VERSION IS OFTEN NOT A TAG, AND THAT IS NORMAL.
#
# .scaffold-version carries a BUILD STAMP, which advances on every merged PR; tags exist
# only at releases. So every project tracking main records a version that was never
# tagged — which is the state `scaffold_version.sh` calls "tracking main" and reports as
# fine. Found on the first real use of this command, against the scaffold's own dev repo:
# it recorded 0.5.1.20260804.1800, no such tag exists, and the command refused outright
# while advising `--from`, which cannot help because the ref exists nowhere.
#
# Fall back to the newest RELEASE at or below the recorded version. The base is then
# slightly older than what you actually have, so the merge sees more upstream change than
# strictly necessary — that costs extra conflicts, never silent wrongness, which is the
# right direction to be wrong in. Say so rather than quietly substituting.
if ! fetch_tree "$FROM_TAG" "$BASE"; then
  cand=""
  if [ -n "$FROM" ]; then
    cand="$(git -C "$FROM" tag 2>/dev/null)"
  elif command -v gh >/dev/null 2>&1; then
    cand="$(gh api --paginate "repos/$UPSTREAM/tags" --jq '.[].name' 2>/dev/null || true)"
  fi
  BASE_TAG="$(WANT="$FROM_TAG" CANDS="$cand" python3 -c '
import os, re
def parts(v): return [int(x) for x in re.findall(r"[0-9]+", v)]
want = parts(os.environ["WANT"])
best, best_p = "", None
for tag in os.environ["CANDS"].split():
    p = parts(tag)
    if not p:
        continue
    a, b = p[:], want[:]
    a += [0] * (len(b) - len(a)); b += [0] * (len(a) - len(b))
    if a <= b and (best_p is None or p > best_p):
        best, best_p = tag, p
print(best)
' 2>/dev/null)"
  if [ -n "$BASE_TAG" ] && fetch_tree "$BASE_TAG" "$BASE"; then
    warn "$FROM_TAG is not a tag — that is normal for a project tracking main,"
    say  "     because .scaffold-version is a build stamp and tags exist only at releases."
    say  "     Using the newest release at or below it as the merge base: $BASE_TAG"
    say  "     Consequence: the merge sees a little more upstream change than you actually"
    say  "     lack, so you may get conflicts on text you already have. Never the reverse."
  else
    die "could not fetch $FROM_TAG, and found no release at or below it to use as a base.

  A three-way merge needs the file as it shipped to you. Without any usable base the only
  options are to overwrite your standards files or skip them, and both are worse than
  stopping. Set .scaffold-version to a release you know you are at or past, and re-run:
      echo 0.5.0.20260731.1600 > .scaffold-version"
  fi
fi
fetch_tree "$TO" "$NEW" || die "could not fetch release $TO. Check the tag, or pass --from <clone>."

# THE NEW TREE IS CHECKED AGAINST ITS RELEASE'S SHA256SUMS BEFORE A BYTE OF IT IS WRITTEN
# (report item 15). A tag moved after release, or a damaged download, stops here. A release
# with no manifest -- the mirror has no releases; releases before 0.111.21 have none -- is
# reported UNVERIFIED and proceeds, because refusing would strand every work adoption.
# --from reads a local clone, whose objects git has already hashed.
if [ -z "$FROM" ]; then
  if release_sums "$UPSTREAM" "$TO" "$WORK/SHA256SUMS"; then
    _sums_out="$(scaffold_sums check "$NEW" "$WORK/SHA256SUMS")"; _sums_rc=$?
    case "$_sums_rc" in
      0) ok "$TO matches its release SHA256SUMS" ;;
      1) printf '%s\n' "$_sums_out" | sed 's/^/     /' >&2
         die "$TO does NOT match the SHA256SUMS attached to its release -- nothing was written." ;;
      *) die "could not check $TO against its SHA256SUMS ($_sums_out) -- nothing was written." ;;
    esac
  else
    warn "$TO is UNVERIFIED: $UPSTREAM has no SHA256SUMS for it (the mirror has no releases,"
    say  "     and releases before 0.111.21 carry none). Proceeding, as before."
  fi
fi
ok "fetched both releases"

# ------------------------------------------------------- hand over to the newer upgrader
#
# A FIX TO THIS TOOL CANNOT FIX THE UPGRADE THAT INSTALLS IT (#179).
#
# The copy doing the work is the one VENDORED IN THE ADOPTER, i.e. the release they are
# leaving. So every defect here is repaired one upgrade late, and the upgrade that carries
# the repair is performed by the broken version. Measured, and it cost an adopting project
# three times: `.gitattributes` became union-merged in 0.12.0, and a project moving
# 0.11.3 -> 0.24.0 on 2026-08-09 still lost 24 Git LFS patterns, because 0.11.3's copy did
# the replacing. The fix was correct, shipped, and could not run.
#
# So: before anything is written, if the release being installed carries a NEWER
# scaffold_upgrade.sh, hand the whole run to it. It is the same code that is about to be
# installed either way — declining to run it while installing it is the strange choice.
#
# Guarded by an env var rather than a version comparison alone, so a bad stamp cannot loop.
if [ -z "${SCAFFOLD_UPGRADE_HANDED_OVER:-}" ] && [ -f "$NEW/tools/scaffold_upgrade.sh" ]; then
  _their_v="$(sed -n 's/^# Version:[[:space:]]*\([0-9][0-9.]*\).*/\1/p' \
              "$NEW/tools/scaffold_upgrade.sh" 2>/dev/null | head -1)"
  if [ -n "$_their_v" ] && [ "$_their_v" != "$SELF_VERSION" ] && \
     [ "$(printf '%s\n%s\n' "$SELF_VERSION" "$_their_v" | sort -V | tail -1)" = "$_their_v" ]; then
    say ""
    say "  handing over to scaffold_upgrade.sh $_their_v from $TO"
    say "    (this copy is $SELF_VERSION — the newer one does the work, so a fix to this"
    say "     tool takes effect on the upgrade that delivers it rather than the one after)"
    _handover="$WORK/handover.sh"
    cat "$NEW/tools/scaffold_upgrade.sh" > "$_handover"
    chmod +x "$_handover"
    # A COMMENT AFTER A LINE CONTINUATION ENDS THE COMMAND (#254). These comments used to
    # sit BETWEEN the `env` line and the `bash` line, each preceded by a `\`. The backslash
    # joins the lines, the `#` then comments out the remainder -- so the command terminated
    # at `env -u ... SCAFFOLD_UPGRADE_ORIGIN=...` WITH NO COMMAND, and `env` with no command
    # PRINTS THE ENVIRONMENT. Two failures from one typo:
    #
    #   1. Every handover dumped ~40 lines of the adopter's environment to stdout. On a
    #      machine holding ANTHROPIC_API_KEY, GITHUB_TOKEN or AWS_* those printed too, and
    #      in CI they land in a log that outlives the run. In a repo that ships
    #      tools/secret_scan.sh to stop exactly that.
    #   2. The two variables it exists to pass were silently dropped, and
    #      SCAFFOLD_UPGRADE_REEXEC was never unset -- so the handover ran without the
    #      environment the re-exec logic depends on, and nothing said so.
    #
    # The comments now sit ABOVE the command and the continuation is contiguous.
    #
    # ${a[@]+"${a[@]}"} -- NOT "${_ORIG_ARGS[@]}". macOS ships bash 3.2.57, where an EMPTY
    # array expanded as "${a[@]}" under `set -u` is treated as UNBOUND and aborts the script
    # (bash fixed this in 4.4). Reproduced on 3.2.57: `a=(); echo "${a[@]}"` exits 127 with
    # "a[@]: unbound variable".
    #
    # THE ASYMMETRY IS THE WHOLE DEFECT AND IT IS THE NASTIEST POSSIBLE SHAPE. `--dry-run`
    # is one argument, so the array is non-empty and the dry run passes cleanly. The BARE
    # run -- the only one that writes -- is the only one that fails. Dry-run green, real run
    # dead, on every macOS adopter.
    #
    # The hand-over design does not rescue it either: this line IS the handover, so it
    # aborts in the OUTGOING copy and the fixed copy never executes. A fix can therefore
    # only reach an adopter through the release they are already on.
    #
    # Found on a real M3 adoption at 0.34.0, running bare, exactly as W-05 could not: the
    # fixture always passes --from and --to, so its array is never empty.
    SCAFFOLD_UPGRADE_HANDED_OVER="$SELF_VERSION" \
      env -u SCAFFOLD_UPGRADE_REEXEC SCAFFOLD_UPGRADE_ORIGIN="$ROOT" \
      bash "$_handover" ${_ORIG_ARGS[@]+"${_ORIG_ARGS[@]}"}
    exit $?
  fi
fi

# ------------------------------------------------------------------ product-owned
say ""
say "  product-owned files (replaced where you have not edited them):"
# Say it out loud. An exclusion nobody can see is indistinguishable from a bug, and this one
# suppresses eight files.
[ "$OWNS_LOCALCODER" = "1" ] && \
  say "    (scaffold:owns-localcoder declared — localcoder's own files are NOT vendored here)"
replaced=0
kept=0
kept_list=""
superseded=0
# Removes `<rel>.scaffold-*` copies, optionally keeping one. The sidecars are OUR released
# bytes, never the adopter's work, so this is the one place in the toolchain that deletes:
# `git show <tag>:<path>` reproduces any of them exactly. See the divergence branch in
# copy_product() for why they must not accumulate.
drop_sidecars() {   # drop_sidecars <relative-path> [keep-this-one]
  local rel="$1" keep="${2:-}" f
  [ "$DRY" = "0" ] || return 0
  for f in "$rel".scaffold-*; do
    [ -f "$f" ] || continue
    [ -n "$keep" ] && [ "$f" = "$keep" ] && continue
    rm -f "$f"
    superseded=$((superseded + 1))
  done
}

copy_product() {   # copy_product <relative-path> [refresh-only] [force]
  local rel="$1" refresh_only="${2:-0}" force="${3:-0}"
  [ -f "$NEW/$rel" ] || return 0                 # not in the new release: leave yours alone
  if [ "$refresh_only" = "1" ] && [ ! -f "$rel" ]; then return 0; fi
  printf '%s' "$rel" | grep -qE "$PRODUCT_PATH_EXCLUDE" && return 0
  # TAKING THE UPSTREAM FILE IS RESOLVING THE DIVERGENCE, and this path returns before
  # anything else runs — so the sidecar has to be dropped here or the adopter is prompted
  # forever about a decision they already made.
  if [ -f "$rel" ] && cmp -s "$NEW/$rel" "$rel"; then drop_sidecars "$rel"; return 0; fi
  # ASK THE BASELINE WHETHER THIS IS OURS TO REPLACE (#125).
  #
  # "Product-owned" was a PREDICTION about which files adopters never edit, and the list
  # got it wrong twice — AGENTS.md, caught only because a checker pointed at it, and
  # .gitattributes, which was not caught for four months. Predicting the set is the wrong
  # instrument, because the failure is silent for exactly the files nobody thought of.
  #
  # So stop predicting and MEASURE: $BASE holds each file as it shipped in the release
  # this project adopted. Identical to it means the project never touched it and replacing
  # is safe. Different means someone edited it deliberately, and an upgrade that overwrites
  # that is destroying work no matter which list the file is on.
  #
  # Real case this catches, found on this machine: Robiton/localcoder's
  # .github/workflows/scaffold-check.yml scans `src/localcoder/*` as well as `tools/*`,
  # because scanning only tools/ left THE PRODUCT unchecked by its own CI. That fix lives
  # in a product-owned file. Without this branch the next upgrade reverts it and CI stays
  # green while silently going back to not checking the product.
  #
  # No baseline (file added upstream after the adopted release, or an unfetchable base) is
  # treated the same way: an adopter file we cannot prove is untouched is not ours to
  # overwrite. Yours is kept either way; the incoming version is written alongside so the
  # merge is a diff rather than an archaeology exercise.
  #
  # `force` EXEMPTS tools/, AND THAT IS DELIBERATE, NOT AN OVERSIGHT. Vendored tooling is
  # force-installed on purpose: `ai/STANDARDS.md` puts the archive ceilings in a standards
  # file rather than in tools/ precisely BECAUSE tools/ is overwritten, and the adoption
  # guide tells adopters so. Honouring local edits there would invert a documented contract
  # and let a project quietly fork its own tooling — which is exactly how Robiton/localcoder
  # ended up 13 releases behind on a copy of this script too old to upgrade itself.
  # A project that genuinely means to fork declares scaffold:localcoder-forked and keeps the
  # change where upgrades do not reach.
  local _pins_only=0
  case "$rel" in .github/workflows/*.yml|.github/workflows/*.yaml)
    pins_only_differ "$BASE/$rel" "$rel" && _pins_only=1 ;;
  esac
  if [ "$_pins_only" = "1" ]; then
    printf '    %s %s — your copy differed from %s only in action pins (a Dependabot bump?)\n' \
      "$([ "$DRY" = "1" ] && echo 'would take  ' || echo 'took        ')" "$rel" "$FROM_TAG"
    printf '      the incoming copy carries its own pins, kept current upstream\n'
  fi
  if [ "$force" = "0" ] && [ "$_pins_only" = "0" ] && [ -f "$rel" ] && ! cmp -s "$BASE/$rel" "$rel" 2>/dev/null; then
    local why="you edited it"
    [ -f "$BASE/$rel" ] || why="not in $FROM_TAG, so it cannot be shown untouched"
    # ONE SIDECAR PER FILE, NOT ONE PER RELEASE.
    #
    # A DIVERGENCE IS USUALLY PERMANENT, and this wrote a fresh `.scaffold-<version>` copy
    # on every upgrade regardless. Measured 2026-08-08 in Robiton/localcoder: 21 committed
    # sidecars — 3 files across 7 releases — and the divergence is deliberate and forever
    # (its docs say `localcoder-bench`, the command it installs on PATH; the template says
    # `tools/localcoder_bench.py`, which is right for everyone else). So the count grows by
    # 3 every release, permanently, and each one is noise in `git status` for a decision
    # that was already made.
    #
    # THE OLD ONES ARE OUR OWN RELEASED BYTES, so removing them loses nothing an adopter
    # wrote — `git show <tag>:<path>` reproduces any of them exactly. That is why this can
    # delete where the rest of this toolchain will not: the archive-never-delete rule
    # protects the ADOPTER's content, and a sidecar is a copy of ours.
    #
    # Only the newest matters anyway. It is what you diff against to decide whether to take
    # the upstream change, and an older one answers a question nobody is asking.
    drop_sidecars "$rel" "$rel.scaffold-$TO"
    if [ "$DRY" = "0" ]; then
      cp "$NEW/$rel" "$rel.scaffold-$TO"
    fi
    kept=$((kept + 1))
    kept_list="$kept_list $rel"
    printf '    %s %s — %s\n' "$([ "$DRY" = "1" ] && echo 'would keep  ' || echo 'kept        ')" "$rel" "$why"
    printf '      %s incoming version left at %s\n' \
      "$([ "$DRY" = "1" ] && echo 'would be:' || echo 'saved:   ')" "$rel.scaffold-$TO"
    case "$rel" in .github/workflows/*.yml|.github/workflows/*.yaml)
      local _u _act _pin
      while IFS= read -r _u; do
        [ -n "$_u" ] || continue
        _act="${_u%@*}"
        _pin="$(grep -oE "uses:[[:space:]]*$_act@[0-9a-f]{40}" "$NEW/$rel" 2>/dev/null \
                | head -1 | sed -E 's/^uses:[[:space:]]*//')"
        printf '      [!] your copy still uses %s UNPINNED%s\n' "$_u" \
          "${_pin:+ -- the incoming copy pins it: $_pin}"
        printf '          tools/workflow_audit.sh fails on this at the next preflight.\n'
      done <<EOF_UNPINNED
$(unpinned_uses "$rel")
EOF_UNPINNED
      ;;
    esac
    return 0
  fi
  # THE DIVERGENCE IS OVER, SO THE SIDECARS GO WITH IT. Falling through here means the file
  # now matches its base — the adopter took the upstream version, or reverted their edit —
  # and it is about to be replaced wholesale. Leaving stale `.scaffold-*` copies behind
  # would keep prompting a decision that has already been made.
  drop_sidecars "$rel"
  if [ "$DRY" = "0" ]; then
    mkdir -p "$(dirname "$rel")"
    cp "$NEW/$rel" "$rel"
    # EXTENSION IS NOT THE TEST — EXECUTABILITY IS. `.githooks/pre-push` has no extension
    # (git requires the bare name), and a hook that arrives without its exec bit is SILENTLY
    # IGNORED by git: present, correct, and doing nothing, which is this project's most
    # recurrent failure shape. `tools/localcoder` left in W-15 and its arm went with it.
    #
    # AND THE FILESYSTEM BIT IS NOT THE ONE GIT SHIPS. `core.fileMode` is false in every
    # working copy here, so `chmod +x` is INVISIBLE to git: the file runs on this machine and
    # is committed 644, and the next clone gets a hook git silently never runs. Measured
    # 2026-09-01: 0.84.0 delivered three chaining git-lfs hooks to Robiton/localcoder and
    # `mode_scan.sh` reported all three [DEAD] on the first preflight after the upgrade.
    #
    # THE FIXTURE MISSED IT BECAUSE IT ASSERTED THE WRONG PROPERTY -- `[ -x ]`, the
    # filesystem bit, when the thing that ships is the INDEX bit. Same class as every other
    # defect in this file: a check measuring the correlate rather than the property.
    case "$rel" in *.sh|*.py|.githooks/*)
      chmod +x "$rel"
      # --add IS REQUIRED FOR A FILE THAT IS NEW HERE. `update-index --chmod` alone refuses
      # on an untracked path, which is every hook the first time it is delivered -- exactly
      # the case this fix is for. It stages the path; the adopter is told to `git add -A &&
      # git commit` next anyway, so nothing is committed behind their back.
      git update-index --add --chmod=+x -- "$rel" 2>/dev/null || true ;;
    esac
  fi
  replaced=$((replaced + 1))
  printf '    %s %s\n' "$([ "$DRY" = "1" ] && echo 'would update' || echo 'updated     ')" "$rel"
}
for f in $PRODUCT_FILES; do copy_product "$f"; done
# Only files the new release ships. Adopter-added files under these directories are never
# deleted — an upgrade that removes work is not an upgrade.
for d in $PRODUCT_DIRS_INSTALL; do
  [ -d "$NEW/$d" ] || continue
  # force=1: tools/ is vendored and force-installed, see copy_product().
  while IFS= read -r rel; do copy_product "$rel" 0 1; done < <(cd "$NEW" && find "$d" -type f | sort)
done
for d in $PRODUCT_DIRS_REFRESH; do
  [ -d "$NEW/$d" ] || continue
  while IFS= read -r rel; do copy_product "$rel" 1 0; done < <(cd "$NEW" && find "$d" -type f | sort)
done

# ---- FILES UPSTREAM HAS RETIRED (#252)
#
# The loops above install what the new release SHIPS. Nothing has ever removed what it has
# STOPPED shipping, so a retired file survived indefinitely -- measured across a 0.38 -> 0.82
# upgrade that left tools/install_ollama_service.sh and its plist template behind, two
# releases after they moved out to localcoder.
#
# NOT COSMETIC, and it had already bitten once: an earlier upgrade left tools/audit_localcoder.sh
# behind, scaffold-check.yml invoked it because it was present, and preflight's coverage list no
# longer knew it existed -- so a GATE FAILED FOR A FILE THE UPGRADE SHOULD HAVE DELETED. The
# adopter turned it into a private habit ("after any upgrade, diff tools/ against a pristine
# clone"), which worked and which nobody else knows to do.
#
# THE BASELINE IS THE DISCRIMINATOR, and it is why this is safe. A file in BASE but not in NEW
# is one upstream retired. A file the ADOPTER added is not in BASE at all, so it is never even
# considered -- an upgrade that removes someone's work is not an upgrade.
#
# AND AN EDITED RETIRED FILE IS NOT DELETED. If the adopter's copy differs from BASE they
# changed it, which is a decision; it is named and left. Silence would be the defect here.
_retired=0 _retired_kept=0 _retired_list="" _retired_kept_list=""
_mret=0 _mkept=0 _mret_list="" _mkept_list="" _mown=0
for d in $PRODUCT_DIRS_INSTALL $PRODUCT_DIRS_REFRESH; do
  [ -d "$BASE/$d" ] || continue
  while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    [ -f "$NEW/$rel" ] && continue          # still shipped
    [ -f "$rel" ] || continue               # adopter already removed it
    printf '%s' "$rel" | grep -qE "$PRODUCT_PATH_EXCLUDE" && continue
    if cmp -s "$BASE/$rel" "$rel"; then
      _retired=$((_retired + 1)); _retired_list="$_retired_list $rel"
      [ "$DRY" = "1" ] || rm -f "$rel"
    else
      _retired_kept=$((_retired_kept + 1)); _retired_kept_list="$_retired_kept_list $rel"
    fi
  done < <(cd "$BASE" && find "$d" -type f 2>/dev/null | sort)
done
# ---- AND THE MANIFEST, FOR ANYTHING RETIRED BEFORE THE ADOPTER'S BASELINE (#253)
#
# The BASE-vs-NEW diff above is blind by construction to a file retired BEFORE the baseline:
# it is in neither tree, so it is indistinguishable from one the adopter added. Measured on a
# real 0.38.3 -> 0.82.2 upgrade, where the two files that motivated #252 survived it entirely.
#
# tools/RETIRED.tsv carries the path, the sha256 AS LAST SHIPPED, and why it went. The sha is
# what makes removal safe without a tree to compare against: matching means untouched, and
# differing means the adopter made a decision that is theirs to keep.
if [ -f "$NEW/tools/RETIRED.tsv" ]; then
  while IFS="$(printf '\t')" read -r _rp _rsha _rwhy; do
    case "$_rp" in ''|'#'*) continue ;; esac
    [ -n "$_rsha" ] || continue
    [ -f "$_rp" ] || continue                 # already gone, or never had it
    [ -f "$NEW/$_rp" ] && continue            # upstream ships it again; not retired after all
    case " $_retired_list $_retired_kept_list " in *" $_rp "*) continue ;; esac
    # THE REPOSITORY THAT SHIPS LOCALCODER KEEPS ITS OWN FILES. A row whose note begins
    # `localcoder:` is a file the scaffold vendored before localcoder became its own product
    # (0.36.0, W-15). In an ordinary adopter it is a stale duplicate; in localcoder's repo it
    # is the product, and a sha match there is not proof of a leftover, because the two were
    # identical copies. Measured on 2026-09-29: localcoder's
    # docs/benchmarks/reference/apple-m3-max.md matches a shipped sha, and without this line
    # the upgrade would have deleted it.
    case "$_rwhy" in localcoder:*)
      if [ "$OWNS_LOCALCODER" = "1" ]; then _mown=$((_mown + 1)); continue; fi ;;
    esac
    # ANY SHIPPED SHA MAY MATCH (#255). The field is a comma-separated list of every
    # revision this path was ever shipped with. One sha meant an adopter on an earlier
    # shipped revision was told they had EDITED a file they never touched -- and those
    # adopters are precisely the long-carrying ones this manifest exists to help.
    _have="$(sha256_of_path "$_rp")"
    _match=0
    if [ -n "$_have" ]; then
      case ",$_rsha," in *",$_have,"*) _match=1 ;; esac
    fi
    if [ "$_match" = "1" ]; then
      _mret=$((_mret + 1)); _mret_list="$_mret_list $_rp"
      [ "$DRY" = "1" ] || rm -f "$_rp"
    else
      _mkept=$((_mkept + 1)); _mkept_list="$_mkept_list $_rp"
    fi
  done < "$NEW/tools/RETIRED.tsv"
fi

# MANIFEST-DERIVED REMOVALS SAY SOMETHING TRUE (#255). These files are in NEITHER release,
# so citing the baseline -- "present in $FROM_TAG" -- was false, and "differs from $FROM_TAG"
# was false in a worse way: it is a claim about the ADOPTER. Someone who knows they never
# touched the file is left working out which half of the sentence is wrong. The manifest
# knows why the file went; say that instead.
if [ "$_mret" -gt 0 ]; then
  say ""
  say "  retired upstream — $([ "$DRY" = "1" ] && echo 'would remove' || echo 'removed') $_mret file(s) this scaffold no longer ships:"
  for _r in $_mret_list; do say "    $_r"; done
  say "    (your copy matches a revision this scaffold shipped, so nothing of yours is lost)"
fi
if [ "$_mown" -gt 0 ]; then
  say ""
  say "  scaffold:owns-localcoder — $_mown file(s) the scaffold once vendored from localcoder are"
  say "    left alone here: in this repository they are the product, not a leftover."
fi
if [ "$_mkept" -gt 0 ]; then
  say ""
  say "  ** $_mkept retired file(s) KEPT — your copy matches no revision this scaffold shipped **"
  for _r in $_mkept_list; do say "    $_r"; done
  say "     Upstream no longer ships these. Your copy differs from every revision it was"
  say "     shipped with, so this tool will not remove it. Delete by hand if you want it gone."
fi

if [ "$_retired" -gt 0 ]; then
  say ""
  say "  retired upstream — $([ "$DRY" = "1" ] && echo 'would remove' || echo 'removed') $_retired file(s) this release no longer ships:"
  for _r in $_retired_list; do say "    $_r"; done
  say "    (unmodified here, and present in $FROM_TAG — so this is upstream retiring them, not you)"
fi
if [ "$_retired_kept" -gt 0 ]; then
  say ""
  say "  ** $_retired_kept retired file(s) KEPT because this project edited them **"
  for _r in $_retired_kept_list; do say "    $_r"; done
  say "     Upstream no longer ships these and your copy differs from $FROM_TAG. Decide and"
  say "     remove by hand — a retired file that anything still invokes is a gate waiting"
  say "     to fail for a reason nobody can find."
fi
[ "$replaced" -eq 0 ] && [ "$kept" -eq 0 ] && say "    (none changed)"
if [ "$kept" -gt 0 ]; then
  say ""
  say "  ** $kept product file(s) KEPT because this project edited them **"
  say "     Previous releases replaced these silently. Review each one and decide:"
  for _k in $kept_list; do say "       diff $_k $_k.scaffold-$TO"; done
  say "     Keep yours, take the incoming version, or merge by hand — then delete the"
  say "     .scaffold-$TO file. Nothing else in this upgrade depends on the choice."
fi
if [ "$superseded" -gt 0 ]; then
  say "     ($superseded superseded .scaffold-* copy/copies removed — only the newest is"
  say "      useful, and every one of them is recoverable with git show <tag>:<path>.)"
fi

# ------------------------------------------------------------------ three-way merge
say ""
say "  three-way merge against the release you adopted ($FROM_TAG):"
conflicts=""
merged=0
for rel in $MERGE_FILES; do
  [ -f "$NEW/$rel" ] || continue
  if [ ! -f "$rel" ]; then
    [ "$DRY" = "0" ] && { mkdir -p "$(dirname "$rel")"; cp "$NEW/$rel" "$rel"; }
    printf '    %-20s added (you did not have it)\n' "$rel"
    continue
  fi
  if cmp -s "$NEW/$rel" "$rel"; then
    printf '    %-20s already current\n' "$rel"
    continue
  fi
  if [ ! -f "$BASE/$rel" ]; then
    # No base means no honest merge. Report and leave it — never overwrite a file that
    # may hold an overlay appendix or a filled-in command table.
    printf '    %-20s SKIPPED — absent in %s, so there is no merge base\n' "$rel" "$FROM_TAG"
    conflicts="$conflicts $rel(no-base)"
    continue
  fi
  # DETACH THE OVERLAY APPENDIX BEFORE MERGING, REATTACH AFTER.
  #
  # setup.sh appends the chosen overlay's content at END OF FILE under a `# Overlay: <name>`
  # marker. Upstream's newest sections also tend to land at end of file, so a plain textual
  # merge collides on EVERY upgrade for every project that applied an overlay — verified on
  # the fixture, which conflicted on exactly this and nothing else. The appendix is
  # adopter-owned by construction and upstream never touches it, so there is no information
  # in merging it: split it off, merge the document, put it back.
  ov_start="$(grep -n '^# Overlay: ' "$rel" 2>/dev/null | head -1 | cut -d: -f1)"
  : > "$WORK/appendix"
  if [ -n "$ov_start" ]; then
    # Include the `---` separator line above the marker when setup.sh wrote one.
    head -n $((ov_start - 1)) "$rel" | tail -1 | grep -q '^---$' && ov_start=$((ov_start - 1))
    tail -n "+$ov_start" "$rel" > "$WORK/appendix"
    # TRIM TRAILING BLANK LINES from the detached document. setup.sh writes a blank line
    # before the `---` separator, so the split leaves `ours` ending in whitespace that the
    # merge base does not have — which reads to git as "you added a line at EOF" and
    # collides with every upstream section that also lands at EOF. That produced a
    # conflict on the fixture whose entire content was one empty line.
    head -n $((ov_start - 1)) "$rel" | python3 -c \
      'import sys; sys.stdout.write(sys.stdin.read().rstrip("\n") + "\n")' > "$WORK/ours"
  else
    cp "$rel" "$WORK/ours"
  fi
  # git merge-file writes the result into the FIRST argument and exits with the number of
  # conflicts (>0), or negative on error. Merge into a scratch copy so a failure cannot
  # leave a half-written standards file behind.
  git merge-file -L "yours" -L "scaffold $FROM_TAG" -L "scaffold $TO" \
      "$WORK/ours" "$BASE/$rel" "$NEW/$rel" >/dev/null 2>&1
  rc=$?
  added="$(diff "$BASE/$rel" "$NEW/$rel" 2>/dev/null | grep -c '^>' || true)"
  if [ "$rc" -lt 0 ] 2>/dev/null || [ "$rc" -gt 100 ]; then
    printf '    %-20s MERGE FAILED — left untouched\n' "$rel"
    conflicts="$conflicts $rel(failed)"
    continue
  fi
  if [ -s "$WORK/appendix" ]; then
    printf '\n' >> "$WORK/ours"          # restore the blank line setup.sh writes
    cat "$WORK/appendix" >> "$WORK/ours"
    ov_note=" (overlay appendix kept out of the merge)"
  else
    ov_note=""
  fi
  # NAME THE RULES THAT ARRIVED, DO NOT COUNT THE LINES (#118). These five files are read by
  # every agent at every session start, so a merge here changes BEHAVIOUR — and "+2 upstream
  # lines" says nothing about what those two lines make an agent do.
  #
  # Measured: 0.5.4 merged an agent threat model into ai/SECURITY.md saying "never paste a
  # credential into a prompt or a tool call". A maintainer who had committed HEC tokens for
  # months was refused by his own agent the next time he tried, with no build to read and no
  # error to search. His upgrade had told him `ai/SECURITY.md  clean (+2 upstream lines)`.
  #
  # Every other upgrade-impacting change this project has hit announced itself as a failing
  # check. This class announces itself as a person being told no, so the upgrade is the only
  # place it can be surfaced at all.
  #
  # A BOLD LEAD-IN IS A HEADING HERE. The first version matched `^#{1,6} ` only, and these
  # files state most of their rules as **bold paragraphs** rather than headings — so it
  # caught rules written one way and silently missed the way they are usually written.
  # Proven on the very next real upgrade: 0.11.0 -> 0.11.2 merged the scaffold:owns-localcoder
  # rule into ai/STANDARDS.md as a bold lead-in, reported `clean (+20 upstream lines)`, and
  # printed no banner at all. A check that covers less than it appears to is this project's
  # most repeated defect, and that time I shipped it.
  #
  # Bold lines are truncated to the bold segment: the lead-in is the rule, the sentence
  # after it is prose, and a banner people skim is a banner that stops working.
  if [ "$added" -gt 0 ] 2>/dev/null; then
    diff "$BASE/$rel" "$NEW/$rel" 2>/dev/null | sed -n 's/^> //p' \
      | grep -E '^#{1,6}[[:space:]]' \
      | sed "s|^|      $rel — |" >> "$WORK/agent_rules_h" 2>/dev/null || true
    diff "$BASE/$rel" "$NEW/$rel" 2>/dev/null | sed -n 's/^> //p' \
      | grep -E '^\*\*' | sed -E 's/^(\*\*[^*]+\*\*).*/\1/' \
      | sed "s|^|      $rel — |" >> "$WORK/agent_rules_b" 2>/dev/null || true
  fi
  [ "$DRY" = "0" ] && cp "$WORK/ours" "$rel"
  if [ "$rc" -eq 0 ]; then
    merged=$((merged + 1))
    printf '    %-20s clean (+%s upstream lines)%s\n' "$rel" "$added" "$ov_note"
  else
    conflicts="$conflicts $rel($rc)"
    printf '    %-20s %s CONFLICT(S) — markers written, resolve by hand\n' "$rel" "$rc"
  fi
done

# THE ONE PLACE THIS CAN BE SAID (#118). Loud, above the fold, and naming the sections that
# arrived — because the next thing to mention them will be an agent refusing something.
# SECTION HEADINGS FIRST, AND THEY ARE NEVER TRUNCATED. Adding bold lead-ins took a real
# 0.5.0 -> 0.5.4 upgrade from 7 named rules to 18, and the 14-line cap then pushed
# "No secrets in prompts or agent memory" — the rule this whole banner exists for — into
# "... and 4 more". A fix that buries its own motivating case is not a fix.
#
# Headings are section-level, far fewer, and the likeliest to matter, so they print in full.
# Only the bold lead-ins are capped.
: > "$WORK/agent_rules"
[ -f "$WORK/agent_rules_h" ] && cat "$WORK/agent_rules_h" >> "$WORK/agent_rules"
_n_head="$( [ -f "$WORK/agent_rules_h" ] && wc -l < "$WORK/agent_rules_h" | tr -d ' ' || echo 0)"
if [ -f "$WORK/agent_rules_b" ]; then
  head -20 "$WORK/agent_rules_b" >> "$WORK/agent_rules"
  _n_bold="$(wc -l < "$WORK/agent_rules_b" | tr -d ' ')"
  [ "$_n_bold" -gt 20 ] && printf '      ... and %s more\n' "$((_n_bold - 20))" >> "$WORK/agent_rules"
fi
if [ -s "$WORK/agent_rules" ]; then
  _n_rules="$(wc -l < "$WORK/agent_rules" | tr -d ' ')"
  say ""
  say "  ** AGENT-VISIBLE RULES CHANGED — $_n_rules new section(s) **"
  say "     These files are loaded into EVERY agent session, so your agents will act on"
  say "     the rules below from their next session. There is no build that fails if you"
  say "     disagree with one — an agent will simply start refusing things."
  say ""
  while IFS= read -r _line; do say "$_line"; done < "$WORK/agent_rules"
  say ""
  say "     Read them in full before your next session:"
  say "       git diff HEAD -- $MERGE_FILES"
fi

# ------------------------------------------------------------------ union merge
say ""
say "  union merge (line sets, where a textual merge would conflict on every append):"
for rel in $UNION_FILES; do
  [ -f "$NEW/$rel" ] || continue
  if [ ! -f "$rel" ]; then
    [ "$DRY" = "0" ] && cp "$NEW/$rel" "$rel"
    printf '    %-20s added\n' "$rel"
    continue
  fi
  u_new=0
  u_tmp="$WORK/union.add"; : > "$u_tmp"
  while IFS= read -r line; do
    case "$line" in ''|'#'*) continue ;; esac
    grep -qxF -- "$line" "$rel" 2>/dev/null && continue
    grep -qxF -- "$line" "$u_tmp" 2>/dev/null && continue
    # KEY ON THE PATTERN, NOT THE WHOLE LINE, WHERE ORDER DECIDES THE OUTCOME.
    #
    # In .gitattributes the LAST matching line wins for a given path, and this loop
    # appends. So exact-line matching is not enough here: an adopter who deliberately
    # wrote `ai/SESSION.md -merge` to turn union merge OFF does not match the shipped
    # `ai/SESSION.md merge=union` textually, and we would append ours below theirs and
    # silently overturn the choice — re-enabling a merge driver on their session log,
    # which is the same class of quiet override this whole change is about.
    #
    # An adopter with a line for that path has an opinion about that path. Leave it.
    # .gitignore is order-independent and keeps exact-line matching.
    if [ "$rel" = ".gitattributes" ]; then
      u_pat="${line%%[ 	]*}"
      awk -v p="$u_pat" '
        /^[ \t]*#/ || /^[ \t]*$/ { next }
        { f = $1; if (f == p) { found = 1; exit } }
        END { exit(found ? 0 : 1) }
      ' "$rel" && continue
    fi
    printf '%s\n' "$line" >> "$u_tmp"
    u_new=$((u_new + 1))
  done < "$NEW/$rel"
  if [ "$u_new" -gt 0 ] && [ "$DRY" = "0" ]; then
    {
      printf '\n# --- entries added by tools/scaffold_upgrade.sh, %s ---\n' "$TO"
      cat "$u_tmp"
    } >> "$rel"
  fi
  printf '    %-20s %s new entr%s (yours kept)\n' "$rel" "$u_new" \
    "$([ "$u_new" = "1" ] && echo y || echo ies)"
done

# ------------------------------------------------------------------ never touched
say ""
say "  never touched (this is where your irreplaceable content lives):"
printf '    %s\n' "$(echo $NEVER_FILES) *_ARCHIVE.md"

# ------------------------------------------------------------------ migrations
#
# Version-gated one-off fixes that a file copy cannot express. Add new ones HERE, with the
# release that introduced the need — a migration applied blindly on every upgrade is a
# migration that eventually undoes something.
say ""
say "  migrations:"
mig_claude_gitignore() {
  # ≤v0.3.0 told adopters to gitignore CLAUDE.md, because it was a symlink then. Creating
  # the pointer is not enough: if the ignore rule survives, the file is never committed, so
  # every teammate and every fresh clone still has no CLAUDE.md — silently, because it
  # looks correct on the machine that ran the upgrade.
  if [ -f .gitignore ] && grep -qE '^[[:space:]]*/?CLAUDE\.md[[:space:]]*$' .gitignore; then
    if [ "$DRY" = "0" ]; then
      cp .gitignore .gitignore.scaffold-backup
      grep -vE '^[[:space:]]*/?CLAUDE\.md[[:space:]]*$' .gitignore > .gitignore.tmp \
        && mv .gitignore.tmp .gitignore
    fi
    say "    CLAUDE.md un-gitignored (backup: .gitignore.scaffold-backup)"
  else
    say "    CLAUDE.md gitignore rule — not present, skipped"
  fi
  if [ -L CLAUDE.md ]; then
    [ "$DRY" = "0" ] && { rm CLAUDE.md; printf '@AGENTS.md\n' > CLAUDE.md; }
    say "    legacy CLAUDE.md symlink replaced with the committed @AGENTS.md pointer"
  fi
  if [ ! -f CLAUDE.md ]; then
    [ "$DRY" = "0" ] && printf '@AGENTS.md\n' > CLAUDE.md
    say "    CLAUDE.md pointer created"
  fi
}
mig_claude_gitignore

mig_agents_symlink_instruction() {
  # ---- THE FIFTH SITE, AND THE ONLY ONE IN THE ADOPTER'S OWN FILES (#303).
  #
  # mig_claude_gitignore above repairs the ARTEFACT — the symlink and the ignore rule. It
  # does not touch the INSTRUCTION that created them. Scaffold <=v0.3.0 shipped an AGENTS.md
  # reading, verbatim:
  #
  #     CLAUDE.md is a symlink to this file for Claude Code compatibility.
  #     If CLAUDE.md does not exist, run `./setup.sh` or create it manually:
  #
  #         ln -s AGENTS.md CLAUDE.md
  #
  # AGENTS.md is a MERGE file, so that paragraph survives every upgrade indefinitely. An
  # adopter who upgrades and then follows their OWN AGENTS.md re-creates the symlink — and
  # the next `printf '@AGENTS.md\n' > CLAUDE.md` from anywhere truncates AGENTS.md to eleven
  # bytes. Four sites were closed in this repository on 2026-09-04; this is the one that
  # cannot be closed from here, only migrated in the adopter's tree.
  #
  # Reported by an adoption session that hit the data loss, fixed its own AGENTS.md by hand,
  # and pointed out that nothing would have done it for the next adopter.
  #
  # SURGICAL AND REVERSIBLE. Only the command line is rewritten, the surrounding prose is
  # left alone, and a backup is kept — AGENTS.md is adopter-owned and a blind rewrite of
  # someone's context file is exactly the class of thing this repository keeps apologising
  # for. Detection is unambiguous: that exact command in that exact file.
  if [ -f AGENTS.md ] && grep -qE '^[[:space:]]*ln -s AGENTS\.md CLAUDE\.md[[:space:]]*$' AGENTS.md; then
    if [ "$DRY" = "0" ]; then
      cp AGENTS.md AGENTS.md.scaffold-backup
      # The sentence ABOVE the command is equally wrong and equally unambiguous — leaving
      # it turns the migrated block into a contradiction, which is its own kind of unclear.
      awk '
        /^CLAUDE\.md is a symlink to this file for Claude Code compatibility\.[[:space:]]*$/ {
          print "CLAUDE.md is a COMMITTED one-line pointer to this file (`@AGENTS.md`)."
          print "It was a symlink in scaffold <=v0.3.0 and must not be one again."
          next
        }
        /^[[:space:]]*ln -s AGENTS\.md CLAUDE\.md[[:space:]]*$/ {
          print "    # DO NOT DO THIS. CLAUDE.md is a COMMITTED one-line pointer now, not a"
          print "    # symlink. Recreating the symlink makes any later"
          print "    #     printf @AGENTS.md > CLAUDE.md"
          print "    # follow it and TRUNCATE THIS FILE to eleven bytes. Measured: 86 -> 11."
          print "    printf @AGENTS.md\\n > CLAUDE.md      # the pointer, committed"
          next
        }
        { print }
      ' AGENTS.md > AGENTS.md.tmp && mv AGENTS.md.tmp AGENTS.md
    fi
    say "    AGENTS.md no longer tells you to recreate the CLAUDE.md symlink"
    say "      (backup: AGENTS.md.scaffold-backup — that instruction destroys AGENTS.md)"
  else
    say "    AGENTS.md symlink instruction — not present, skipped"
  fi
}
mig_agents_symlink_instruction

mig_lost_lfs_patterns() {
  # REPORT WHAT EARLIER RELEASES ALREADY DELETED (#125), AND NEVER WRITE IT BACK.
  #
  # Until this release .gitattributes was product-owned, so every upgrade replaced it and
  # took any Git LFS filter patterns with it. LFS does not error when a pattern disappears —
  # it just stops applying — so the symptom is binaries silently entering history as raw
  # blobs, discovered much later and only fixable by rewriting history. One adopter lost
  # 693 files (6.1 MB) that way before anyone noticed.
  #
  # This CANNOT be auto-repaired and must not try. Restoring a line means deciding which
  # historical version was right, and the blobs already committed need `git lfs migrate
  # import`, which rewrites history — ai/SECURITY.md routes irreversible operations through
  # a human. So: detect, show the exact lines from the adopter's own history, name the
  # command, stop. Git is the record; this only points at it.
  local had
  had="$(git log --all -p -- .gitattributes 2>/dev/null \
         | grep -E '^-.*filter=lfs' | sed 's/^-//' | sort -u)"
  if [ -z "$had" ]; then
    say "    Git LFS patterns — none ever removed from .gitattributes, nothing to restore"
    return 0
  fi
  if [ -f .gitattributes ] && grep -q 'filter=lfs' .gitattributes 2>/dev/null; then
    say "    Git LFS patterns — present in .gitattributes, nothing to restore"
    return 0
  fi
  warn "Git LFS patterns were removed from .gitattributes at some point and are not back."
  say  "     Earlier scaffold releases replaced this file wholesale, which is how they were"
  say  "     lost (#125, fixed in this release — it is union-merged from now on)."
  say  "     Found in this repository's own history:"
  printf '%s\n' "$had" | while IFS= read -r _l; do say "       $_l"; done
  say  "     Restore the lines you still want, then check whether binaries were committed"
  say  "     as raw blobs while the patterns were missing:"
  say  "       git lfs ls-files | head"
  say  "       git lfs migrate import --include='<pattern>' --everything   # REWRITES HISTORY"
  say  "     Coordinate the migrate with anyone else holding a clone — it changes every"
  say  "     commit id. Nothing here has been written for you."
}
mig_lost_lfs_patterns

# ------------------------------------------------------------------ stamp
# RECORD A VERSION, NOT A REF NAME. `--to main` is legitimate (that is how you take
# unreleased changes), but writing "main" into .scaffold-version makes the staleness check
# compare a word against a number — scaffold_version.sh parses digits out of it, finds
# none, and every future session reports nonsense. Read the version the target ref actually
# carries and record that; fall back to the ref name only if it has none.
STAMP="$TO"
if [ -f "$NEW/version" ]; then
  _v="$(tr -d '[:space:]' < "$NEW/version")"
  case "$_v" in [0-9]*.[0-9]*) STAMP="$_v" ;; esac
fi
if [ "$DRY" = "0" ]; then
  printf '%s\n' "$STAMP" > .scaffold-version
fi
say ""
ok ".scaffold-version -> $STAMP$([ "$STAMP" != "$TO" ] && echo "  (the version carried by '$TO')")"
say "     ('version' is untouched — that one is your project's, not the scaffold's.)"

# ------------------------------------------------------------------ verify
say ""
say "  verify:"
if [ "$DRY" = "1" ]; then
  say "    (skipped in a dry run)"
else
  # NAME THE FAILING LINES, DO NOT JUST SAY "problems" (#182). Discarding the output to
  # /dev/null and reporting "reported problems — run it" sent an adopter to investigate the
  # first `[!]` they saw, which was "no overlay applied (base scaffold only)" — advisory,
  # exit 0, and not the cause. A verify step that says something is wrong without saying
  # what makes the reader pick a suspect, and the nearest suspect is rarely the right one.
  if [ -x ./setup.sh ]; then
    _sc_out="$(./setup.sh --check 2>&1)"
    if [ $? -eq 0 ]; then
      ok "   setup.sh --check"
    else
      warn "   setup.sh --check failed:"
      printf '%s\n' "$_sc_out" | grep -E '^\[FAIL\]' | sed 's/^/       /' || true
      say  "       ([!] lines are advisory and are NOT why this failed — run"
      say  "        ./setup.sh --check to see everything)"
    fi
  fi
  if [ -x tools/header_check.sh ]; then
    if tools/header_check.sh >/dev/null 2>&1; then
      ok "   header_check"
    elif [ -f ai/STANDARDS.md ] \
         && grep -q -- '--adopt' tools/header_check.sh \
         && ! grep -qE '^<!--[[:space:]]*scaffold:header-baseline[[:space:]]+[0-9]{4}-[0-9]{2}-[0-9]{2}[[:space:]]*-->[[:space:]]*$' ai/STANDARDS.md; then
      # ONLY ADVISE A FLAG THE INSTALLED CHECKER ACTUALLY HAS. `--to` can target a release
      # older than this tool, which installs a header_check.sh predating --adopt — and a
      # remedy that errors out is worse than the bare warning it replaced.
      # SURFACE IT AS A MIGRATION, NOT AS A RED BUILD LATER (#76). Reported from a real
      # 0.5.0 -> 0.6.3 upgrade: the upgrade itself was flawless, then CI went red on an
      # unrelated axis and the PR could not merge. The person who ran the upgrade is the
      # one who can act on this, and this is the moment they are looking at the output.
      warn "   header_check: files here predate the file-header standard."
      say  "       This release applies that rule going forward, not retroactively. Declare"
      say  "       when this project adopted it — one line in ai/STANDARDS.md, which upgrades"
      say  "       merge rather than overwrite:"
      say  "           tools/header_check.sh --adopt"
      say  "       Files older than that date are then exempt until they are next edited."
    else
      # NAME WHAT IT FOUND. "run it" is a second command for the reader to run before they
      # learn anything, on the one path where the tool already knows the answer.
      warn "   header_check reported problems:"
      tools/header_check.sh 2>&1 | sed 's/^/       /' | head -8
    fi
  fi
  if [ -x tools/session_archive.py ]; then
    # DISTINGUISH "over ceiling" FROM "this tool does not know that flag". argparse exits 2
    # on an unknown argument, and `--all` only exists from v0.5.1 — so upgrading TO an older
    # target ran a tool without it and the result was reported as "a file is over its
    # ceiling", which is a confident wrong diagnosis. Caught on the fixture.
    tools/session_archive.py --all --check >/dev/null 2>&1
    case $? in
      0) ok "   archive ceilings" ;;
      1) warn "   a file is over its ceiling — run: tools/session_archive.py --all" ;;
      *) say  "     archive ceilings: not checked (this release's session_archive.py has no --all)" ;;
    esac
  fi
  # A FAILING skills_check USED TO PRINT NOTHING AT ALL (#277 audit). The `&&` chain meant
  # in-sync said so and out-of-sync said nothing, which is indistinguishable from the tool
  # not being installed -- the exact pair this package refuses to conflate everywhere else.
  if [ -x tools/skills_check.sh ]; then
    if _sk_out="$(tools/skills_check.sh 2>&1)"; then
      ok "   skills mirror in sync"
    else
      warn "   skills mirror is OUT OF SYNC — tools/skills_check.sh"
      printf '%s\n' "$_sk_out" | sed 's/^/       /' | head -6
    fi
    unset _sk_out
  fi

  # ---- REFRESH THE DERIVED STATUS BLOCK, BECAUSE THIS UPGRADE IS WHAT INVALIDATED IT.
  #
  # A status block records `.scaffold-version` for every declared repository -- including
  # the one being upgraded. So a successful upgrade leaves the block describing the release
  # this repo was on a moment ago, and the next preflight fails on a staleness THIS TOOL
  # created. Twice in one day here, both times with the same one-command remedy.
  #
  # That is the shape the archive-ceiling and issue-count arguments already rejected in this
  # codebase: a gate that fires predictably after a normal action, with a fixed remedy and
  # no decision attached, is one people learn to clear on autopilot -- and then clear on the
  # day it was telling them something. The answer there was to stop failing on facts that
  # are not about this tree. The answer HERE is different, because an adoption version IS a
  # fact about this tree: refresh it at the moment it changes, rather than letting a human
  # be the generation trigger.
  #
  # NON-FATAL, AND QUIET WHEN ABSENT. Most repositories declare no status block at all --
  # only one in this programme does -- so a missing tool or missing markers is the normal
  # case, not a problem. `--write` also refuses (exit 3) when it cannot see every declared
  # sibling, which is exactly right on a fresh clone and must not turn an otherwise clean
  # upgrade red.
  _sb_decl="$(grep -rl 'scaffold:status-begin' ai/ 2>/dev/null | head -1)"
  if [ -x tools/status_block.sh ] && [ -n "$_sb_decl" ]; then
    _sb_out="$(tools/status_block.sh --write 2>&1)"; _sb_rc=$?
    case "$_sb_rc" in
      0) ok "   status block refreshed — this upgrade changed the adoption version it records" ;;
      3) say "     status block: not refreshed — $(printf '%s' "$_sb_out" | head -1)" ;;
      *) warn "   status block refresh failed:"
         printf '%s\n' "$_sb_out" | sed 's/^/       /' | head -4 ;;
    esac
    unset _sb_out _sb_rc
  fi
  unset _sb_decl
fi

# ------------------------------------------------------------------ executable bits
#
# `core.fileMode false` MAKES GIT RECORD A NEWLY ADDED FILE AS 644 WHATEVER ITS MODE ON
# DISK, and a tool that lands non-executable is a tool that silently stops running.
#
# This is not hypothetical and it is not rare. Measured 2026-08-08: the 0.15.0 upgrade
# force-installed `tools/conflict_scan.sh` at 755 on disk into BOTH consumers, and both
# recorded it 644 — because both had just set `core.fileMode false` (correctly: their
# filesystem reports 0700 for every file). CI discovery filters on `[ -x ]`, so the tool's
# 15 cases would have been skipped in silence in both repos, in the same session that made
# a skipped suite a hard failure precisely because it looks identical to a passing one.
#
# WHY THIS IS ADVICE AND NOT AN ACTION. The upgrade deliberately does not touch the index —
# it leaves a reviewable working tree so `git checkout .` is a complete undo, which is the
# snapshot argument in ai/SECURITY.md. `git update-index --chmod` needs the path to be in
# the index, which it is not until the adopter stages. So the honest move is to name the
# exact command at the moment it is needed, and to say what it costs to skip it.
#
# The backstop is elsewhere and it is real: CI fails when a tools/ file advertises
# `--selftest` and is not executable. This message is what stops that from being a surprise.

if [ "$DRY" = "0" ] && [ "$(git config core.fileMode 2>/dev/null)" = "false" ]; then
  needs_x="$(tools_recorded_non_executable | tr '\n' ' ')"
  needs_x="${needs_x% }"
  if [ -n "$needs_x" ]; then
    say ""
    warn "core.fileMode is false, so git will record these tools NON-EXECUTABLE:"
    for f in $needs_x; do say "       $f"; done
    say "     A non-executable tool is skipped by every discovery loop that runs it —"
    say "     its selftest does not run, and the log says nothing. After staging:"
    say "       git add -A && git update-index --chmod=+x $needs_x"
  fi
fi

# ------------------------------------------------------------------ summary
say ""
if [ -n "$conflicts" ]; then
  warn "upgrade applied with conflicts in:$conflicts"
  say  "     Search those files for '<<<<<<<' — each marker shows your version, the"
  say  "     scaffold at $FROM_TAG, and the scaffold at $TO. Resolve, then:"
  say  "       tools/conflict_scan.sh          # confirms every marker is gone"
  say  "       git add -A && git commit -m 'chore(scaffold): upgrade to $TO'"
  say  "     A conflict means you and upstream edited the same region. That is the case"
  say  "     where guessing would be wrong, so it is handed to you deliberately."
  # THIS EXIT 1 AND THE PARAGRAPH ABOVE WERE, FOR THIRTEEN RELEASES, THE ENTIRE MECHANISM,
  # and they are not one. This project's own dev repo committed the markers 0.14.0 wrote
  # into ai/STANDARDS.md, layered the 0.14.1 upgrade on top of them, and stayed CI-green
  # throughout — a non-zero exit at the moment of the merge does nothing about the commit
  # that comes after it. tools/conflict_scan.sh is the check that outlives this message;
  # it runs in `./setup.sh --check` and in CI on every push.
  exit 1
fi
if [ "$DRY" = "1" ]; then
  say "dry run complete — $replaced product file(s) and $merged merge(s) would be applied."
  exit 0
fi
ok "upgrade complete: $replaced product file(s) replaced, $merged standards file(s) merged cleanly."
# THE INSTRUCTION USED TO PRODUCE THE STATE THE GATE FORBIDS (#239). `git add -A` stages the
# sidecars this run just wrote, the printed commit lands them, and tools/conflict_scan.sh then
# fails the NEXT preflight with "unreconciled upgrade sidecars are committed" -- two gates away
# from the line that caused it. Reproduced 2026-08-21 upgrading Robiton/localcoder 0.73.0 ->
# 0.74.0, which kept .github/CONTRIBUTING.md and left a sidecar beside it.
#
# The reconciliation is usually trivial -- diff, keep yours, git rm -- which is exactly why the
# instruction has to say so rather than leaving it to a gate the adopter meets later and reads
# as the upgrade having gone wrong.
if [ "$kept" -gt 0 ]; then
  say ""
  say "  ** DO NOT run a bare 'git add -A' yet — $kept sidecar(s) are unreconciled **"
  say "     A committed sidecar is invisible: it is in no diff, breaks no build, and reads as"
  say "     an ordinary file. tools/conflict_scan.sh fails the build on one, and it will do so"
  say "     on your next preflight, not here."
  say ""
  for _k in $kept_list; do
    say "       diff $_k $_k.scaffold-$TO   &&  git rm $_k.scaffold-$TO"
  done
  say ""
  say "     Fold in anything the incoming copy added, keep your edits, remove the sidecar,"
  say "     and then:"
  say "       git add -A && git commit -m 'chore(scaffold): upgrade to $TO'"
  say ""
  say "     Or commit the rest now and reconcile after:"
  say "       git add -A -- ':!*.scaffold-*' && git commit -m 'chore(scaffold): upgrade to $TO'"
else
  say "     Review and commit:  git diff  &&  git add -A && git commit -m 'chore(scaffold): upgrade to $TO'"
fi
