<!-- scaffold:ai-file-kind reference -->
# Standards — the evidence behind the rules

> ## This file is about the scaffold itself, not about your project.
>
> Every rule in `ai/STANDARDS.md` that exists because something specific went wrong keeps
> the rule there and the story here. The stories are the **scaffold's** — measurements taken
> in `ai-project-scaffold` and its development repo, not in your repository.
>
> That is deliberate, and it is why the file ships. A rule you are asked to follow is easier
> to judge — to keep, to adapt, or to argue with — when you can see what it cost to learn.
> Nothing here describes your project, and nothing here needs editing to be correct.
>
> The sizes, dates and issue numbers below are ours. Read them as evidence, not as a report
> on your repository.


_Not in the session-start load order, and deliberately so. Every rule in_
_`ai/STANDARDS.md` that was written because something specific went wrong keeps the_
_rule there and the story here. The rule has to stand on its own; this file is what you_
_read when you want to change the rule and need to know what it cost to learn._

_Moved out of ai/STANDARDS.md on 2026-09-01 (#280), when the nine always-loaded files_
_measured 95 KB in the scaffold repository and 217 KB in its development repo — around 54k_
_tokens, a quarter of a context window spent before the first instruction. Nothing was_
_deleted._

## Correction capture is deliberately narrow

1. **Capture** — when corrected, note the correction (a running list in the session
   is enough). A human-typed `remember:` prefix marks something as a learning
   explicitly — honor it in any tool.
   **`tools/correction_capture.py` now does this half automatically**, on the same Stop
   hook as the journal: it appends the correction VERBATIM to `ai/SESSION_JOURNAL.md`
   and does nothing else. It does not classify, score, or write to any context file —
   steps 2 and 3 below are unchanged and still require a human. This step used to end
   "no tooling required", and the record shows what that bought: fourteen releases
   across four repos on 2026-08-25 with no session entry behind any of them.
   The tool is deliberately narrow. Measured against a real 484-turn transcript, the
   first draft matched 63 times and was mostly comparative prose ("cost 7 minutes
   instead of 11", "that copy never runs"); the shipped rules match **3 times, all 3
   genuine**. Run `tools/correction_capture.py --measure <transcript>` before widening
   a rule, and delete a rule whose matches are mostly not corrections rather than
   tuning it — the SPL time-bound advisory was 85% noise and got deleted, not tuned.
2. **Review** — at session END, replay the list with the human: is this recurring/
   behavioral, or a one-off?
3. **Apply** — recurring corrections go to `ai/MEMORY.md` (or the standard they
   contradict); one-offs die with the session. **When one lands, record which rule found
   it** — `tools/correction_capture.py --promote <rule>`, where the rule name is the tag in
   the journal line. That is the only acceptance signal the capture tool ever gets, and
   `--health` turns it into promoted/captured per rule: measured, rather than an opinion
   about which patterns are pulling their weight. If a correction lands while a
   project skill is executing, route it to the skill file too (see the ai-skill
   overlay).

## The session record gate warns and does not block

**And it is reported, not trusted — but as of 0.14.0 it does NOT block.** A rule that depends
on a human remembering it at the end of a long session is a rule that quietly stops being
true: measured in a real adoption, `SESSION.md` reached **1,001 lines against its own
~150-line ceiling, with no archive file at all**, the rule present and simply never applied.
It shipped as a CI warning, and a warning is what was ignored on the way to 1,001 lines.
It was made blocking on 2026-08-05 and that was reverted in 0.14.0: failing the build over
the length of a working record stops the work in order to tidy the notes about the work,
and it kept catching people mid-entry. What replaced the gate is a report that names the
oversized entries and the one command that fixes each, plus archive paths that only ever
ADD — so the remedy is cheap and safe rather than compulsory. The 1,001-line risk is real
and is accepted knowingly. If the ceiling is genuinely wrong for your project, raise it in the
marker below — do not silence the check. So:

## The ceiling moved because the format was not enforced

**The ceiling was enforced and the FORMAT was not, which is why the ceiling kept moving.**
A line count cannot tell *"the ceiling is too low"* from *"nobody wrote stubs"* — this
section says so above, and it happened anyway. Measured on this scaffold's own development
repo, 2026-08-08: 348 lines, of which **23 dated decision entries were 286 lines — 82% of
the file** — averaging 12 lines each against a 3–4 line bar, with only 6 of 23 carrying an
archive cross-reference. Its ceiling had gone 250 → 300 → 350 in three weeks and none of
those raises was the fix. Stubbing projects to ~157 lines, *less than half the shipped
default*. The 350 that ships today is the fourth raise — chosen because a decision entry
that earns its place is long, not because the file had grown past a number again.

## Exit 3 came from an adopters green run on zero work

Measured by an adopting project on 2026-08-09, in a tool written specifically to prevent
silent failures: a GDScript parse checker shelled out to `godot`, which was not installed on
the runner. `command not found` went into the captured output, that string contains no
`Parse Error`, and the tool announced **"7 file(s) parse cleanly"**. Three CI runs green on
zero work. *The gate emitted its strongest verdict at the exact moment it was incapable of
any verdict.* More logging would not have changed the exit code, and the exit code is what
CI acts on.

## Why 3 and not 2

**This number was not free, and the collision is the reason it is written down.** Before
2026-08-10, `2` meant *usage error* in `header_check.sh`, *could not run* in
`lint_python.sh` and *skipped* in `audit_localcoder.sh` — one code, three meanings, so no
caller could act on it. The idea predated the convention; only the number was wrong.

## A configured hook that never fires is invisible

**This is the project's dominant failure mode, and it is invisible by construction.**
Measured 2026-08-09: four `.claude/settings.json` hooks — `sync-check.sh` at SessionStart
and the journal at SessionStart, Stop and SessionEnd — had **never fired once** on the
machine that develops this scaffold, because they resolved paths against the session's
working directory. Months, silently. The same week, `sync-check.sh`'s archive nudge had been
dead for five releases (it branched on an exit code the tool stopped returning), and CI
printed *"12 tool selftest suite(s) passed"* in green while a 15-case suite was skipped for
a missing mode bit.

## Local green is not ci green

**Local green is not CI green, and only one of them is the truth about the project.**
Every check this scaffold ships runs locally; the place a failure actually lives is the
remote. Measured 2026-08-08 on this scaffold's own dev repo: red for four hours while every
local check passed, because the failing step scopes by a `# Project:` header that the local
run never exercised. The owner noticed, not the toolchain — and the lesson was written down
as a memory entry, where it sat until it got a checker, which is this project's most-repeated
failure in miniature.

## Not enabled is not the same as no alerts

**Alerts are checked, and "not enabled" is reported as its own answer.** Dependabot,
code scanning and secret scanning each have three states — has alerts, has none, and *could
not ask* — and the last one prints as silence if you only look for a number. Measured
2026-08-09 on this project: all three repos had every alert feature disabled while
`docs/RELEASE_SECURITY_REVIEW_GATE.md` had been prescribing a dependency audit since it was
written. Nobody was ignoring alerts; there were none to ignore, and no way to tell that
apart from being clean.

## The ceilings are a starting point not a measurement

**These numbers are a starting point, not a measurement.** The original 150 for `SESSION.md` was
evidenced — it is where entries stop being skimmable. 120 and 250 were judgement. The one
measurement taken since (2026-08-04, on the scaffold's own development repo): ~14 live
architectural decisions written to this file's own specificity bar came to ~250 lines with
nothing left over, so that repo raised its `MEMORY.md` ceiling to 350 in its own copy of
this line. **Raise yours if the same is true of your project — but do the supersession pass
first**, because "the ceiling is too low" and "I have not archived" look identical from
inside the file.

## Why the session record rule exists

**Why this rule exists.** Measured 2026-08-05 on this scaffold's own development repo, which
had needed a hand trim to fit its ceiling three sessions running: **57% of the file was
decision entries** at ~18 lines each — one per significant design choice, and that repo
makes roughly one per session. Growth was structural, not editorial slack, so compressing
prose bought a line at a time and never converged. Restating the same 11 decisions as stubs
took the file from 350 lines to ~200 with nothing lost, because the archive is committed and
greppable. The ceiling was never the wrong number; the entry format was.

## A repo that ships nothing carries no version file

**A repo that ships nothing carries no `version` file.** `version` identifies a BUILD of a
deliverable. A context, docs or research repo has no build, so a number there labels nothing
and goes stale the day it is created — measured on this scaffold's own development repo,
where it was written once on 2026-07-09 and never touched again while dozens of commits
landed around it. Nothing read it; nothing could have noticed.

## The repo that published this rule was the worst offender

This rule went unenforced until 2026-08-04, and the repo that publishes it was the
clearest violator: `setup.sh` carried a stamp four versions and a month behind its own
last change, `tools/session_archive.py` had no `Version:` line, and `sync-check.sh` had no
header at all. Nobody was careless — nothing was watching. See *Archiving* above for the
same failure with the same cause and a different number on it.

## Do not assume the hook fired

**Do not assume the hook fired.** It resolves paths against the session's WORKING DIRECTORY.
Until 0.17.0 that meant the repo root and nowhere else — and on this project's own machine,
where sessions open in the parent of three scaffold repos (the layout its own `AGENTS.md`
prescribes), the guard was false every time and `|| true` swallowed it. The session-start
check had not run once, in the file that exists to make it run. **A hook whose every failure
path is `|| true` cannot tell you it did nothing**, which is why this was invisible rather
than merely broken. The hook now also scans one level below the working directory and runs
in each place that is a real adoption; deeper is a monorepo, and walking it at session start
is a cost nobody asked for.
When a run has failed

## The check with teeth is the transition

**The check with teeth is the transition, not the state.** Alerting off costs nothing when
there is nothing to scan, so silence there is correct. What is not correct is a repo that
*gains* dependencies while nothing watches them — which arrives on an ordinary commit nobody
thinks of as a security change. `ci_status.sh` warns on exactly that, and treats an empty
`dependencies = []` as the deliberate declaration it is in `localcoder`'s `pyproject.toml`,
not as a finding.

## Why all three ceilings ship at 800/900

**All three ship `800/900`** — archive at 800, burst at 900. `MEMORY.md` was once the only
one set that high, which is why the paragraph below argues for it specifically; v0.8.0 gave
the same pair to all three, and 0.16.0 raised them together so there is room for every
participant to write to the record, not only the frontier model. A session entry is a log
line and a backlog item is a task, but a memory entry is an *argument*: the decision, what it rules
out, and the evidence that settled it. At 250 this project's own context repo crossed the
line for having eight of them, which produces exactly the wrong pressure — the cheapest way
back under is to write the next decision as a one-liner nobody can act on.

## The ceiling syntax reuses the old shape

**`NAME=800/900` is the syntax, and 0.13.x wrote the same shape meaning `warn/hard`.**
Reinterpreting it is safe, which is the only reason it reuses the syntax rather than
inventing one: under the old meaning the larger number FAILED THE BUILD, under this one it
raises the volume of a report that always exits 0. Every project carrying an old pair gets a
strictly softer outcome, never a harder one, and the lower number keeps the meaning it always
had. Order is irrelevant — the smaller is the archive line, the larger the burst.

## The ceiling example is in backticks on purpose

**That example is in backticks on purpose, and the reason is a real defect an adopter
hit (#180).** It used to sit at column 0, which makes it a LIVE marker — syntactically
identical to configuration, in the exact file the parser reads. On upgrade it merged
into projects that already had their own, leaving two live markers and ceilings that
depended on which appeared first. One project ran for a release on 150/200/260 purely
because their line happened to sit above upstream's; any edit reordering the two would
have silently moved them to 600/700 — the shipped defaults at that time. `CEILING_RE` is anchored with `^<!--`, so an
inline-code version can never match — and the values above are the built-in defaults
anyway, so nothing here changes by not declaring them.

## Why the ceilings live in STANDARDS.md

Two reasons it is here and not a constant in the script. First, `tools/` is **vendored**:
a scaffold update overwrites it, so a number edited there is silently reverted on the next
upgrade — while `ai/STANDARDS.md` is marked *never overwrite* in the adoption guide.
Second, this project keeps being bitten by rules that are stated in one place and
implemented in another; a ceiling written in prose and hardcoded in a script is two
definitions that can disagree, and the table above is where a human already looks.

## Why no ceiling has a hard level

**Every ceiling flexes, and every path archives rather than deletes.** One number per file
— the line at which you should archive — and crossing it is a report, never a refusal. The
mid-thought problem is not specific to decisions: a long session entry or a busy backlog
crosses its line in the middle of the work just the same, which is why none of the three
has a hard level any more.

## The third column decides how much the ceiling matters

**All three carry the same pair, on purpose.** Until 0.19.0 only `MEMORY.md` had a burst,
which made it read as a special case for one file rather than as how ceilings work here.
One pair to remember, and no file where crossing the line means something different.

**But the third column is the one that decides how much the number matters.** `SESSION.md`
is the only path that MOVES text, automatically and losslessly — its selftest asserts that
archived plus remaining equals what went in. So nothing is at risk there whatever the
ceiling says; a low number would only have meant rotating sooner. `BACKLOG.md` and
`MEMORY.md` **copy, and a human deletes or trims**. That is where a tight ceiling turns into
pressure on a person to remove something, and it is the reason these numbers are generous:
**the archive is the safety net, and no number should be pushing anyone toward the
alternative.**

This table described a `warn/hard` pair until 0.15.0, five releases after 0.14.0 removed
the hard level — the same defect as the "it BLOCKS" claim #145 corrected two paragraphs
below, in the same file, missed on the same pass. A document that keeps its claim and
loses its status is this project's most-repeated failure, and prose is where it hides:
`tools/session_archive.py` had one number the whole time.

`SESSION.md` is the only path that moves text, and its selftest asserts the move is
lossless — archived plus remaining equals what went in. The other two only ever *add*, so
"the tool never removes anything" is a property that holds across the whole toolchain
rather than per command.
