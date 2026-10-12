<!-- scaffold:ai-file-kind template -->
# Operations — the reference half of the standards

_**Not in the session-start load order.** `ai/STANDARDS.md` keeps the rules an agent needs_
_to behave correctly; this file holds the parts you read while doing a specific thing —_
_cutting a release, stamping a header, reading a CI result, setting an archive ceiling._

_Every rule here is enforced by a tool (`release_status.sh`, `header_check.sh`,_
_`ci_status.sh`, `session_archive.py`), which is why it is safe to read on demand: an agent_
_that never opens this file still cannot violate these silently. That test is the reason_
_these sections moved and others did not._

_Split out on 2026-09-02 (#281). Measured before the split: a fresh adoption read 85 KB —_
_about 21k tokens — before its first instruction._

## Versioning standard

All projects and releases use this format:

    MAJOR.MINOR.PATCH.YYYYMMDD.HHMM

| Part     | Meaning                           | Example  |
|----------|-----------------------------------|----------|
| MAJOR    | Breaking changes                  | 1        |
| MINOR    | New features, backward compatible | 2        |
| PATCH    | Bug fixes only                    | 3        |
| YYYYMMDD | Build date                        | 20260325 |
| HHMM     | Build time, 24-hour format        | 0624     |

Full example: `1.2.3.20260325.0624`

Rules:
- Tag every release in GitHub using this full format
- Update version in the project version file before tagging
- **Every merged PR updates the build-stamp** (`YYYYMMDD.HHMM`) portion of the `version`
  file to its build time — the version file always identifies the current build.
  `MAJOR.MINOR.PATCH` changes only at release. **On conflict** (a one-line file — union
  merge cannot help it): take either side, finish the merge, and restamp once at the
  end of the merge train — the later timestamp wins; never let a version conflict
  block a PR.
- MAJOR bumps reset MINOR and PATCH to 0
- MINOR bumps reset PATCH to 0
- Timestamp reflects actual build time, not planned release time
- **The same stamp moves in the header of every source file the PR touches.** The `version`
  file says what the build is; a file header says when *that file* last changed, which is
  how a reader decides whether the measurement quoted in a comment still describes the
  code. `tools/header_check.sh --since origin/main` checks it, and CI runs it.

**A repo that ships nothing carries no `version` file.** `version` identifies a BUILD of
a product. A repository that publishes no artifact has no build to identify, and a
number nobody consumes is a number nobody maintains.
Evidence: ai/STANDARDS_EVIDENCE.md -> a repo that ships nothing carries no version file.

Declare it, so the absence is a decision rather than an oversight:

<!-- scaffold:no-artifact — not declared; the form to use is shown below -->

    <!-- scaffold:no-artifact -->

in this file. `setup.sh --check` and CI then treat a missing `version` as correct instead of
failing. Such a repo still carries `.scaffold-version` (which scaffold release it runs) and
still obeys the file-header rules — `git log` already answers "when did this last change",
and answers it better than a hand-maintained number.

Evidence: ai/STANDARDS_EVIDENCE.md -> the repo that published this rule was the worst offender.

### File-header baseline — a rule introduced in release N does not fail work done before N

Making that check blocking failed an existing adoption's **entire codebase at once** — 33
files written long before the standard was — and the pull request could not merge. The bill
scales with how old and large a project is, so it lands hardest on exactly the projects with
the most to gain from upgrading. The likely outcome is not that anyone writes 33 headers; it
is that they stop upgrading, which is the problem the upgrade tool exists to solve.

So a project adopting this standard into existing code declares the date it did so:

(The live marker is declared in `ai/STANDARDS.md`, which is the only file
`header_check.sh` reads.)

    <!-- scaffold:header-baseline YYYY-MM-DD -->

`tools/header_check.sh --adopt` writes that line for you and prints how many files it
exempts. A tracked source file whose last commit predates the date is **legacy**: reported
and counted on every run, never failed. **Edit it and it is in scope immediately** — the
baseline exempts history, not future work, and the count stays on screen so an amnesty
cannot quietly become permanent. `--list-legacy` names what is left.

**This is not a loosening, and that distinction matters** — *Rule precedence* above forbids
a project from relaxing a general rule, so an adopter who followed the standards had no
sanctioned way out and one who worked around it broke a different rule to do it. The rule
as stated here has always been *headers on the code this project writes*; the baseline says
when this project started writing them. What the standard does **not** permit is deleting
the marker's date to switch the check off, or carrying a baseline once the legacy list is
empty. Remove the line when the list reaches zero.

No marker means no exemption, so a project that starts with the standard is unaffected and
nothing is ever inferred from absence — the same reason `scaffold:no-artifact` is declared
rather than guessed. And the marker lives **here**, in a file upgrades three-way merge, not
in `tools/` which every upgrade replaces: the two escape hatches that existed before this
one (`EXCLUDE` in the checker, `--warn-only` in the workflow) were both erased by the next
upgrade, which is why neither was a real answer.

### Ask GitHub, not only your own machine

**Local green is not CI green, and only one of them is the truth about the project.**
Ask GitHub — `tools/ci_status.sh` — rather than inferring from a clean local run.
Evidence: ai/STANDARDS_EVIDENCE.md -> local green is not CI green.

`tools/ci_status.sh` is that checker. It reports failed runs on the default branch, open PRs
whose checks have already failed, and **open security alerts**, and `sync-check.sh` runs it
at session start through the `SessionStart` hook. Re-run it after every push, after every
merge, and before reporting work complete — the hook fires once, and a session outlives it.

**Do not assume the hook fired.** It resolves paths against the session's WORKING
DIRECTORY, and a hook whose every failure path is `|| true` cannot tell you it did nothing.
Evidence: ai/STANDARDS_EVIDENCE.md -> do not assume the hook fired.
When a run has failed, read the job log (`gh run view <id> --log-failed`) rather than
inferring the cause from the change that triggered it.

**Alerts are checked, and "not enabled" is reported as its own answer.** Dependabot,
code scanning and secret scanning each answer separately, and an absent feature is NOT
a clean one.
Evidence: ai/STANDARDS_EVIDENCE.md -> "not enabled" is not the same as "no alerts".

Dependabot is free on any repo and is now on. Code scanning and secret scanning need paid
Advanced Security on a private repo, so their absence is reported once at `--verbose` and
never as a finding — nagging about the impossible is how a report gets muted.

**The check with teeth is the transition, not the state.** A repo that *gains*
dependencies while nothing watches them arrives on an ordinary commit nobody thinks of as a
security change, and `ci_status.sh` warns on exactly that.
Evidence: ai/STANDARDS_EVIDENCE.md -> the check with teeth is the transition.

It is **silent when it cannot ask**: no `gh`, no auth, no GitHub remote, or offline, it
prints nothing and exits 0. That is deliberate and is the same argument
`tools/scaffold_version.sh` makes — a check that errors on a plane is one people disable,
and it runs at session start, so disabling it takes every other session-start check with it.
`--verbose` distinguishes *"green"* from *"could not ask"*, which are not the same answer.

`sync-check.sh` warns at session start and CI reports it; **neither fails the build**
(0.14.0 — see *These numbers are advisory* above). Nothing is ever deleted —
the archive is the long memory, and the template blocks a fresh scaffold ships with are
never counted or rotated.

**The ceilings live here, in this file, and the tool reads them from it.** The line below
is the single definition — `tools/session_archive.py` parses it, and `--check` prints
which source it used. Edit it to set your project's ceilings.

**All three ship `800/900`** — archive at 800, burst at 900. A session entry is a log line
and a backlog item is a task, but a memory entry is an *argument*: the decision, what it
rules out, and the evidence that settled it. Set too low, the cheapest way back under the
line is to write the next decision as a one-liner nobody can act on.
Evidence: ai/STANDARDS_EVIDENCE.md -> why all three ceilings ship at 800/900.

**Two numbers, and NEITHER OF THEM BLOCKS.** That is what separates this from the
`warn/hard` pair 0.14.0 removed, and the distinction is the whole point. A hard level failed
the build, fired on whichever commit happened to cross it, and caught people mid-thought —
`ai/SECURITY.md`'s rule is that a guard blocking legitimate work gets disabled, and then it
protects nothing. A **burst** line changes the volume of a report and never its exit code.

It exists because one number cannot say two different things:

| state | what it means | what to do |
| --- | --- | --- |
| under 800 | normal | nothing |
| `[over]` 800 | you crossed the archive line while writing decisions | get to the trim |
| `[BURST]` 900 | the trim stopped happening | do it now — the file is loaded every session |

A report that says the same thing at 601 lines and at 750 is one people stop reading, which
is the failure this whole section is built around.

**`NAME=800/900` is the syntax.** Order is irrelevant — the smaller number is the archive
line, the larger the burst. An old `warn/hard` pair from 0.13.x is reinterpreted safely.
Evidence: ai/STANDARDS_EVIDENCE.md -> the ceiling syntax reuses the old shape.

A single number is still perfectly valid and means "archive line, no burst". All of this is
per-project and meant to be edited; raise it before you shorten an entry that is carrying
its weight.

(The live marker is declared in `ai/STANDARDS.md`, which is the only file
`session_archive.py` reads.)

**The whole always-loaded set has a ceiling too**, in bytes rather than lines, because what
a session pays is the total of the nine files the load order names and not any one of them.
`./setup.sh --check` prints it. The default is 120 KB — the product's own floor plus
headroom, not a goal; the target is 80 KB. Set your own with an un-backticked marker at
column 0: `<!-- scaffold:context-ceiling 120 -->`. It is advisory and never fails.

**That example is in backticks on purpose (#180).** At column 0 it would be a LIVE
marker, and an upgrade would merge a second one into projects that already had theirs.
Evidence: ai/STANDARDS_EVIDENCE.md -> the ceiling example is in backticks on purpose.

**To set your own, put an un-backticked marker at column 0 anywhere in this file.**

It lives here and not in the script because `tools/` is vendored and overwritten on
upgrade, and because a rule stated in one place and implemented in another is two
definitions that can disagree.
Evidence: ai/STANDARDS_EVIDENCE.md -> why the ceilings live in STANDARDS.md.

**These numbers are a starting point, not a measurement.** They are the shipped default,
not a fact about your project. Change them in ai/STANDARDS.md and say why.
Evidence: ai/STANDARDS_EVIDENCE.md -> the ceilings are a starting point, not a measurement.
