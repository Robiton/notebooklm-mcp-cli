# tools/

Three independent groups: **session durability** and **repo hygiene** (both recommended
for every project), and the optional **local-coder workflow**.

## Session durability

| File | What it is |
|------|-----------|
| `session_hook.sh` | **The one entry point a session hook calls**, so that *whether it ran* is answerable. The hook commands used to be shell literals in `.claude/settings.json`, one per event, each ending in `>/dev/null 2>&1; done; true` — so the hook ran, there was no hook to run, and the hook failed all arrived as the same silent success. The old selftests proved the journal script can be executed directly; nothing proved the **client** invokes it from the directory people actually work in. Root discovery is deterministic and ordered: `SCAFFOLD_HOOK_ROOT`, then `CLAUDE_PROJECT_DIR`, then the git toplevel, then **one** level of subdirectories carrying `ai/STANDARDS.md` — the multi-repo workspace case, which is a correct answer there and a guess anywhere else. Emits exactly one of `HOOK_RAN` / `HOOK_SKIPPED` / `HOOK_UNVERIFIED` per project per event, with repo, commit, timestamp and reason, into the run log that `scaffold_log.sh --report` already reads. The client-facing exit stays 0 **by design** — a hook that fails the client is a hook the user turns off, after which nothing is recorded at all — and `--strict` returns the outcome as an exit code for tests and closeout. `--closeout` **refuses on an unverified session** and is what preflight asks after the wiring check — wired is not firing, and a perfectly configured broken hook otherwise reads as healthy. The **newest** start record decides, never "is there a `HOOK_RAN` anywhere", which is true forever after the first success. A client with no lifecycle support declares `<!-- scaffold:hooks-unavailable <why> -->` in AGENTS.md and the reason is printed every time — a declared gap, not a silent opt-out. Twenty-one selftest cases, each launching from a different directory, because launching from the right one is exactly what could not have been caught before. |
| `session_journal.sh` | Captures session **facts** (changed files, new commits, branch) into a gitignored `ai/SESSION_JOURNAL.md`, continuously. Wired to `SessionStart` / `Stop` / `SessionEnd` in `.claude/settings.json`. |
| `session_archive.py` | **Reports** the ai/ files that are over the archive ceilings `ai/STANDARDS.md` states, and names the one command that helps each. Advisory since 0.14.0 — it never fails a build. Every path adds to an archive; none removes from the live file. |
| `guard_delegation.py` | **PreToolUse nudge — off by default.** Interrupts the *first* large write to a file the delegation policy covers when `localcoder` has not drafted anything in 30 minutes, then allows every later attempt on that file. It can interrupt a habit; it can never block work. Upstreamed from an adopting project (#187) where the instruction to delegate sat in three separate files and one 27-commit session drafted zero lines. (An attribution figure was quoted here and is withdrawn — see *A number that used to be here*.) Asks rather than denies by default; `"delegation": {"guard": {"decision": "deny"}}` once your project has decided. The delegatable set comes from `delegation.languages`, so it never fires on a language the policy does not cover. |
| `guard_pretooluse.py` | **PreToolUse guard** — turns the `ai/SECURITY.md` hard lines into actual rules. Shipped **disabled**; carries its own selftest. |

**Why.** `ai/SESSION.md` is written at the END of a session, so a session that dies first
loses the whole record. The split that makes this work: **hooks capture facts, the agent
writes narrative.** Facts are mechanical and are exactly what is lost; narrative needs
judgment and a hook that tried would produce noise nobody reads. If the session dies, the
facts survive and the narrative is reconstructable.

```bash
tools/session_archive.py --check    # advisory, always 0; add --exit-status for 0/1/2
tools/session_archive.py --apply    # rotate oldest entries -> ai/SESSION_ARCHIVE.md
```

The journal is **gitignored** — per-developer working state, distilled into `SESSION.md`.
It stays silent when nothing changed, and never counts its own files as project changes.
An un-distilled journal at session start is announced: that means a previous session ended
without writing `SESSION.md`, which is the exact failure this exists to surface.

Only the *hook wiring* is Claude Code-specific. The script is portable bash — other tools
run it manually or wire their own trigger.

## What we borrowed, and whether it has moved since: `provenance_check.sh`

`ai/PROVENANCE.md` records every external source this project took something from, with the
**upstream fingerprint at the time we took it**. That last field is the whole point: a
registry naming source, licence and decision — which is what this programme had — cannot
answer "have they fixed anything since?" without re-reading the entire repository.

```bash
tools/provenance_check.sh            # what has moved since we looked
tools/provenance_check.sh --list     # rows only, no network
tools/provenance_check.sh --write    # record that you looked — AFTER you actually did
```

**It is a report, not a gate, and preflight does not call it.** Upstream repositories move
constantly; a check that goes red whenever a stranger pushes is red at a normal moment, and
#241 is this month's example of what that trains. `--check` exits 0. `--strict` returns drift
as an exit code for a scheduled review that wants to act on it.

**`--write` is a claim about you, not about them.** It stamps "reviewed at this ref on this
date". Running it without reading the compare link turns the file into a decoration.

### The relation column, and the one people forget

`code` · `idea` · `behaviour` · `evaluated` · `catalogue` · `dependency`

**`behaviour`** is a dependency on someone else's internals with no package manager watching
it. We did not take Cline's code — we read its shipped bundle and found that MCP child
processes inherit exactly `HOME LOGNAME PATH SHELL TERM USER`. #192 rests on that. If they
add a seventh variable, nothing tells us, and the failure is silent: the server still starts,
still completes `initialize`, still returns a tool list, with an empty credential.

**Recording a rejection is not bookkeeping** — it stops the same source being re-evaluated
from scratch, and it is what lets you notice when a rejection has stopped being true.

### What the first run found, 2026-08-26

Two things, on a registry that had existed for minutes:

- **`claude-reflect-system` has no LICENSE file.** It had been recorded as MIT in five places
  on the strength of its README. `GET /repos/.../license` is 404. No exposure — an idea was
  taken, not code — but nothing may be copied from it, and the rows now say so.
- **It was evaluated at v1.0.0 while v1.3.0 had been out for a month**, and v1.1–v1.3
  answered both criticisms in our own evaluation. The conclusions held; the reasoning was
  against a version that no longer existed.

`ollama/ollama` is deliberately pinned at **v0.32.13** — the version every behavioural claim
in #147, #117 and T2b was measured on — so it reports MOVED against v0.33.0 permanently until
someone re-measures. That is a standing reminder, not a defect.

## Corrections, captured where they are said: `correction_capture.py`

`ai/STANDARDS.md` → *Corrections are learnings* has always had three steps — capture,
review, apply. Step 1 said "a running list in the session is enough" and shipped with no
instrument, so it depended on someone remembering mid-task. This is the instrument.

It rides the **same Stop hook as the journal** (`session_hook.sh checkpoint`), reads the
client's transcript, and appends matching sentences to `ai/SESSION_JOURNAL.md`:

```
- 2026-08-26 06:43:44 — correction candidate [negation]: "no, don't use pip here, use uv instead"
- 2026-08-26 06:43:44 — correction candidate [remember]: "the mirror is one-way and force-pushed"
```

**What it does not do is the point.** It does not classify, score by confidence, or write
to any context file. Steps 2 and 3 — review with the human, then apply to `ai/MEMORY.md`
or the standard it contradicts — are unchanged and still human. The standard's own line
holds: *never auto-write corrections to context files without the review step*.

| | |
|---|---|
| writes to | `ai/SESSION_JOURNAL.md` only |
| state | `.correction-capture-state` (gitignored), so a turn is never captured twice |
| secrets | every quote is redacted before it is written — a correction can name a token |
| failure | always exits 0; a hook that fails a session is a hook people turn off |

**The `remember:` prefix is a first-class rule** and the only one exempt from the
turn-length filter. A person who typed the marker has stated intent; a heuristic must not
overrule a statement.

### Why it is this narrow, and how to widen it honestly

The idea is from [`haddock-development/claude-reflect-system`](https://github.com/haddock-development/claude-reflect-system)
(**no declared licence** — the README says MIT but the repository has no LICENSE file, so
nothing may be copied from it; see `ai/PROVENANCE.md`). That project scores matches into
HIGH/MEDIUM/LOW confidence and then edits skill files from them, targeting ">80% precision,
>60% recall" — stated as a goal, with no measurement attached. **We read v1.0.0's README
while v1.3.0 was current**; v1.1–v1.3 answered both of those criticisms upstream, which is
why `ai/PROVENANCE.md` now records the version we evaluated. Both halves of that were rejected here on evidence this project
already had: localcoder #185 (gotcha selection ranks by keyword and ranks the wrong entry
first) and the SPL time-bound advisory, which fired 53 times against real saved searches
and was **noise 41 of those times**. It was narrowed to 12 rules by deletion.

So the precision number here is measured, not targeted. Against a real 484-turn
transcript:

| | matches | genuine |
|---|---|---|
| first draft (loose `instead of`, loose `never/always`) | 63 | ~3 |
| shipped rules | **3** | **3** |

`--measure <transcript>` prints every match with the rule that fired it, so the count can
be done by hand. **A rule whose matches are mostly not corrections gets deleted, not
tuned.** Two were: a bare `instead of` was 0-for-12 (all comparative prose), and a bare
`never|always` was ~2-for-40 ("that copy never runs").

The single highest-value filter is `MAX_TURN`. User-turn length on that transcript is
bimodal — median 134 characters, p75 364, **p90 2057, p95 13255** — and the long tail is
entirely pasted material: agent reports relayed into the chat, which are technical prose
full of "never", "not" and "instead of". That population produced 56 of the 63 first-draft
matches and none of the corrections.

```bash
tools/correction_capture.py --selftest              # and it must MISS things
tools/correction_capture.py --measure <transcript>  # count precision by hand before widening
tools/correction_capture.py --health                # promoted/captured, per rule
tools/correction_capture.py --promote <rule>        # at closeout, when one lands in MEMORY.md
tools/correction_capture.py --dry-run --transcript <path>
```

### Pattern health: which rules have earned their place

`--measure` counts precision **by hand, once**, against one transcript. `--health` makes it
accumulate, and it needs no inference — **the acceptance signal already exists and a person
already makes it.** Step 3 of *Corrections are learnings* is a human deciding a correction is
recurring and writing it into `ai/MEMORY.md`. That IS the judgement; all that was missing was
recording which rule produced the candidate that earned it.

```
promoted/captured, per rule (worst first):

     0/8      0.0%  actually  <-- 0 promotions in 8 captures: delete it, do not tune it
     7/9     77.8%  use-not
     4/4    100.0%  remember
```

**A rule that never earns a promotion is named, not left in a column for you to notice.** A
health report that cannot say "this rule is dead" is decoration.

Nothing here adjusts anything. The idea comes from `claude-reflect-system` v1.3.0, whose
version of it pairs the score with `--use-meta` — feeding it back into detection confidence.
That is the loop closing on itself: a keyword scorer tuning its own keyword scores, with
nobody reading the result. The value is the **number**, which tells a person which rule to
delete.

## Enforcing the hard lines: `guard_pretooluse.py`

`ai/PLANNING.md` puts it plainly: **a rule written only in an `ai/` file is a request** —
the model can drift past it. This hook is the enforcement for three of them:

| what | why |
|---|---|
| Destructive commands (recursive-force `rm` **in any spelling**, `DROP`, `DELETE` with no `WHERE`, force push, hard reset) | state git cannot restore — see `ai/STANDARDS.md` → *Work that leaves no trace in git* |
| Protected paths (`ai/SECURITY.md`, workflows, `.claude/settings.json`, the guard itself) — via `Edit`/`Write` **and** via a shell write | an agent that can rewrite its own guardrails has none, and `echo >> ai/SECURITY.md` is the same act as an edit |
| Edits **and commits** while on `main` | `ai/CODING.md` → *Version control*: branch first. The commit is the rule; the edit is an early warning |

```bash
tools/guard_pretooluse.py --selftest    # 33 behavioural cases, no Claude Code needed
```

**"In any spelling" is doing real work in that first row.** The original matcher recognised
`rm -rf` and `rm -fr` and nothing else, so `rm -r -f`, `rm -f -r`, `rm --recursive --force`
and `rm build/ -rf` were all allowed **silently** — while the suite reported 17/17, because
every fixture had been written from the regex. Flags are parsed now, and the suite tests
the spellings people type rather than the ones the code already handled.

**Shipped disabled**, and it lives in `.claude/settings.pretooluse-guard.example.json`.
Copy the `PreToolUse` key from there into the `hooks` object of `.claude/settings.json`
to turn it on. It is off by default because **a guard nobody chose is a guard someone
rips out** at the first inconvenience.

*It used to ship as an inert `_DISABLED_PreToolUse` key inside `.claude/settings.json`
itself.* JSON has no comments, so an inert key looked like the idiom, and it sat in the
file you already had rather than an example nobody opens. That reasoning was sound and
the bet underneath it — that Claude Code ignores unknown hook events silently — expired:
the key now prints `hooks._DISABLED_PreToolUse: Unknown hook event ... was ignored` on
every session start, in every project, forever, with nothing an adopter can do about it
(#101). The first question it drew was *"is this due to the AI scaffold?"* — a
deliberately-disabled feature is indistinguishable from a broken config to the person
reading the warning, and that channel also carries settings that really are broken. Same
argument this repo makes about `[!]` lines in `setup.sh --check`: a permanently-wrong
warning devalues the ones that are right.

A no-op `PreToolUse` entry would have been the worse fix — it registers a real hook that
runs on every tool call to do nothing, trading a visible warning for an invisible cost.

**Already carrying the old key?** Upgrades do not touch `.claude/settings.json`, so this
change will not reach you. Delete the `_DISABLED_PreToolUse` block by hand; if you want
the guard, take the `PreToolUse` key from the example file instead.

**It asks; it rarely denies.** A guard that blocks legitimate work gets disabled, and a
disabled guard protects nothing — the same failure mode as a warning that always fires.

**It is a seatbelt, not a firewall.** Pattern-matching a command string is defeated by a
shell variable, an encoding, or a wrapper script one level down. The goal is to make the
dangerous-by-accident case loud and the dangerous-on-purpose case deliberate. That is
*containment over prevention*, which `ai/SECURITY.md` → *Agent threat model* explains.

**It fails open.** Malformed input, a crash, an unparseable payload — every failure path
allows. Verified: malformed and empty stdin both exit 0 without blocking.

**Its hook LOOKS for the guard rather than assuming your cwd is the repo.** The command was
`python3 tools/guard_pretooluse.py`, resolved against the session's working directory —
which is only the repo root if you open the editor exactly there. Measured 2026-08-09 on
this project's own machine, where sessions open in the parent of three scaffold repos (the
layout this scaffold's own `AGENTS.md` prescribes): every cwd-relative hook had **never
fired once**. For the session journal that is a lost feature. For a security guard it is
worse than not installing it, because you believe you are covered. It now takes the first
`tools/guard_pretooluse.py` in the working directory or one level below — every copy is
identical, since `tools/` is force-installed, and the guard reads its target out of the
hook payload rather than out of its own location.

## The delegation nudge: `guard_delegation.py`

**A rule written only in an `ai/` file is a request.** `guard_pretooluse.py` says so in its
own docstring, and delegation was on the request side of that line. Measured on an adopting
project: *"use localcoder by default"* was present in `ai/MEMORY.md`, in `AGENTS.md` **and**
in a Skill — and one 27-commit session still drafted **zero** lines against 2,762 written by
hand. Never disputed, never followed, invisible until someone asked for numbers.

A share-of-landed-code figure used to sit in that sentence. It is **withdrawn** as an invalid
test — see *A number that used to be here* below. The zero-of-2,762 session is a direct
observation and survives it, and the argument this gate rests on is that a rule stated in
three places and followed in none is a request rather than a control. That never needed a
percentage.

**IT MOVED IN W-15 AND THIS SECTION DID NOT.** `guard_delegation.py` is localcoder's, not
the scaffold's — it reads the delegation policy and watches for localcoder drafts, so it
went to `ops/guard_delegation.py` in `Robiton/localcoder` with everything else. The scaffold
has not shipped it since 0.36.0, and `.claude/settings.pretooluse-guard.example.json` still
wires a `tools/` path that no adopter can satisfy: the hook is `[ -x ]`-guarded, so it exits
0 and says nothing — a hook that cannot fire and cannot report not firing, which is the
class `AGENTS.md` names as four hooks doing nothing for months.

```bash
# In Robiton/localcoder, which owns it:
ops/guard_delegation.py --selftest      # 24 cases, no Claude Code needed
```

**The gate is only worth its interruptions if the drafts are good**, so the same project
measured that too — one repo, one model, one week:

| prompt | drafted | corrected | rate |
|---|---:|---:|---:|
| no recipe — no context, or raw files pasted | 223 | 212 | **95%** |
| digest + contract + typing rule + best-of-N | 216 | 8 | **3.7%** |

A 25× difference from **prompt construction alone**. The failure was never *"the local model
cannot do this"*; it was *"nobody assembled the prompt that makes it reliable"*.

**It interrupts once per file per session, then allows.** If the honest answer is "this one
is not delegatable", repeating the call goes straight through and the decision is recorded.
Same containment-over-prevention stance as the security guard: one that blocks legitimate
work gets disabled, and a disabled guard protects nothing.

**It asks; the original denied.** That argument is good — the audience is the agent, and
prompting a human about the agent's working habits is noise rather than approval. It is
right for a project that has decided delegation is the norm, and too much blast radius for a
scaffold default, because upstream cannot know whether you run a local model at all. One key
changes it:

```json
"delegation": { "guard": { "decision": "deny", "min_lines": 40 } }
```

**The delegatable set comes from `delegation.languages`**, so the nudge can never fire on a
language your policy does not cover — a gate that interrupts work you never agreed to
delegate is one you switch off in its first hour. A policy of `"off"`, or one with no
languages, silences it entirely.

Excluded by default and **anchored, not substring-matched**: `ai/`, `docs/`, `.github/`,
anything under `addons/`, `node_modules/`, `vendor/`, `__pycache__/`, and files named
`test_*`/`harness_*`. That anchoring is the reporter's catch — `"ai/" in path` also matches
`game/scripts/ai/behaviour.gd`, a directory holding exactly the pure decision code most
worth delegating, and it would have turned the gate off precisely where it earns its keep.

**Half its selftests are known-good inputs**, and that rule came from the same report: three
checkers written in one day there were tested only against inputs they were meant to catch,
and all three rejected valid code in production. A verifier needs proof it stays quiet.

**Every failure path allows.** A malformed payload, an unreadable log, a crash — all fall
through. A guard that breaks the session is a guard that gets removed.

### Declaring who does what

The shipped policy answers *what may be delegated*. It never answers *who does what*, and the
default reads as **localcoder is an optional accelerator**. A project that wants the stronger
stance declares it, and `localcoder --delegation` renders it — any key it does not recognise
is printed rather than dropped:

```json
"delegation": {
  "roles": {
    "agent": "planner, project manager, assessor, validator, approver",
    "localcoder": "writes the implementation"
  }
}
```

| | agent | localcoder |
|---|---|---|
| decide WHAT to build | ✅ | ❌ |
| state the CONTRACT | ✅ | ❌ |
| build context (digest, data shapes) | ✅ | ❌ |
| **write the implementation** | needs a reason | ✅ |
| review, test, harness the contract | ✅ | ❌ |
| approve, integrate, own the CI result | ✅ | ❌ |

**This is not in `AGENTS.md` on purpose.** That file merges into every adopter and is loaded
into every session, so putting *"hand-writing implementation is the exception and needs a
reason"* there would impose it on projects that never asked — the agent-behaviour change the
release gate exists to make loud. Declared in your own config, it is a decision you made.

---

## Repo hygiene

| File | What it is |
|------|-----------|
| `preflight.sh` | **The one command to run after `git commit` and before `git push`.** Runs every gate CI runs — discovered the same way the workflow discovers them — and reports **all** failures rather than stopping at the first, because CI stops at the first and hides the next behind it. `--coverage` reads the workflow and fails if CI invokes a tool preflight skips. Refuses a dirty tree (exit 3) since a run against a half-committed tree does not describe what you would push; `--allow-dirty` overrides. ~25s. |
| `lint_python.sh` | The pinned ruff, as a file rather than forty lines inside a `run:` block. Holds the version pin, the rule set and the ownership scoping — an adopter's own Python is never linted by it, an extensionless file with a python shebang is. Resolves pipx **or** uvx **or** a system ruff at exactly the pin; exit 2 is "could not run", never confused with 1, "found something". |
| `shell_lint.sh` | The pinned ShellCheck, same shape as `lint_python.sh` and for the same reason — a rule that lives only in YAML can only ever run in CI. The severity floor is `error`, and that is a measurement: `-S style` reports 178 findings on this tree, `-S error` reports 2. A gate that arrives red in five repositories on day one is a gate people clear on autopilot. Finds shell files by extension **or** shebang. Exit 3 is "no shellcheck at the pin", never a clean lint. |
| `fixture_guard.sh` | Sourced, not run: `fixture_root T` gives a selftest a validated, empty, disposable directory, or exits 1 before anything is written. It checks that mktemp succeeded, that the path is non-empty and outside the live repo (by `git rev-parse --absolute-git-dir`) and outside any repository, and that nothing from git's environment or credentials is inherited. Then it puts two wrappers first on PATH: a `git` that refuses any write outside the root, or any push that is not to a local path inside it (exit 97, logged in `$FG_BASE/refused`), and a `mktemp` that fails unless its path exists inside the root, so the tool's own `|| exit` fires. It exists because header_check's selftest once ran with a failed mktemp, `cd ""` did nothing, and the fixture committed into the real repository. Every tool whose selftest builds git fixtures sources it; `--selftest` seeds each fault against a passing baseline. |
| `workflow_audit.sh` | zizmor over `.github/workflows/`, pinned, at `--persona=auditor --min-severity high`. **Both flags are load-bearing**: the default persona suppressed 7 of 11 findings here, so a plain `zizmor` call audits a third of what its output implies. It also **inverts zizmor's exit codes** — zizmor returns `14` for findings and `1` for *could not run*, with an empty stdout, so a pass-through wrapper reports findings when it audited nothing. Second half: **actionlint**, pinned, for validity (unknown keys, bad `needs:`, expressions), with its shellcheck/pyflakes integration off so the verdict does not depend on the box. |
| `header_check.sh` | Enforces the file-header and build-stamp rules from `ai/CODING.md`. `--since <ref>` catches a file changed without a re-stamp — across the committed diff, the working tree **and** files git does not know about yet. `--selftest` proves the checker fails what it should. |
| `skills_check.sh` | Names the **direction** of drift between `.agents/skills/` and `.claude/skills/` — "they differ" is not actionable; "the Claude mirror is behind" is. |
| `scaffold_log.sh` | Records that a check RAN, so a check that STOPS running becomes visible. Every other tool here prints to a console that is then thrown away — so nothing could show that four hooks had never fired on this project's own machine for months. `--report` names what has gone quiet; `sync-check.sh` calls it at session start. Per-machine and gitignored, rotated by age (90d) not line count, because the oldest entry is the one that answers "when did this last run". |
| `ci_status.sh` | Reports red CI on the **remote** — failed runs on the default branch, and open PRs whose checks already failed. Local green is not CI green: measured here, a repo sat red for four hours while every local check passed. Silent when it cannot ask (no `gh`, no auth, offline); `--verbose` distinguishes "green" from "could not ask". `sync-check.sh` runs it at session start. |
| `scaffold_version.sh` | Tells this project when the scaffold it vendored has gone stale. Cached 24h, **silent offline** — a version check that nags on a plane is one people disable. |
| `localcoder_sync.py` | Detects drift between this repo's `localcoder` and the standalone product's copy. Offline — both repos record the same normalised hash and each verifies its own file. `--emit-patch` re-paths your change for the other repo, for the case where the sibling is not checked out on this machine and "apply it there too" is not an available action. `--selftest` covers the drift cases. |
| `scaffold_upgrade.sh` | Acts on the answer: moves the project to a newer release, three-way merging the standards files against your `.scaffold-version`. `./setup.sh --upgrade` delegates here. `--selftest` runs end-to-end checks against a synthetic project, offline. |
| `status_block.sh` | Derives the repository status table in `ai/BACKLOG.md` from git and gh, between `<!-- scaffold:status-begin -->` / `<!-- scaffold:status-end -->`. It exists because a **hand-maintained** status table went stale twice here — the second time inside a block whose own text warned about the first, and an outside review caught it in two consecutive assessments. Discipline was tried and failed, so the table is generated: `--write` regenerates, `--check` fails on drift (preflight runs it), `--status` prints the working-tree view. Human commentary lives OUTSIDE the markers and is never rewritten — prose and data sharing one block is how it went stale. A block whose declared sibling repositories are not present on this machine is **exit 3** — a fresh clone or an adopter that inherited the markers cannot derive it, and `--write` there would replace the real table with a shorter one and call that an update. A failed network lookup prints `?`, never `0`: "no open issues" and "could not ask" are different claims. The written table deliberately carries **no working-tree state**, because HEAD, dirty and ahead/behind are all changed by the act of committing the block, and a check that can never be green is one people learn to skip. |
| `changelog.sh` | **Derives `CHANGELOG.md` from the tags**, so it cannot disagree with what was released. A hand-maintained one would go stale exactly like the status table did — and faster, because nobody reads it during the release they are cutting. Newest first by tag date with a **version-aware** tiebreak: date alone ties when two releases are cut in the same second (this repository cut seven in under two hours), and refname alone has the 0.9.0-above-0.10.0 defect every hand-rolled version comparison has. A tag message that merely repeats the version is treated as **no** message and falls through to the commit subject — `git tag -a X -m X` otherwise produces a changelog whose every entry is its own heading, a row that looks like data and carries none. No tags is exit 3, not a stale file. |
| `release.sh` | **Cuts the release, and leaves a receipt saying what was actually checked.** A tag records that someone typed a version; it does not say which SHA was tested, whether a gate ran or was skipped, what artifact was built, or on what platform. Runs the version invariant, preflight and every declared must-run gate, builds and SHA-256-hashes the wheel, aggregates **every** workflow run on the commit into one CI verdict — any failure is a failure, anything still running is `CI_UNVERIFIED`, and success must be earned by every run, because `--limit 1` returns whichever workflow finished last and a green mirror is not a green test suite, and writes `.release-receipts/<version>.json` plus a human companion. **Fails closed**: no gate is ever piped into a formatter (the pipeline would report the formatter's status, not the gate's), every exit code is captured before anything is printed, a **BLOCKED** gate refuses exactly like a failure, and the tag is created only after the gates *and* the receipt succeed — so a tag can never exist for a release whose evidence does not. Where a project ships a `tools/sbom.py`, the SBOM is generated against the **same wheel** the receipt names and attached alongside it; a failing SBOM check is a **blocked** gate, because an SBOM whose dependency claim does not hold is worse than none — it is the document consumers trust instead of reading the code. Receipts are gitignored by construction: a receipt names the commit it describes, so committing it would file it under a different SHA than the one it records. `--publish` attaches it to the GitHub release, which is where it becomes immutable. Nineteen selftest cases, nearly all negative — a release tool only ever seen to succeed has not been tested. |

### Tree scanners: `*_scan.sh`

A tree scanner takes no arguments, prints its findings, and exits non-zero when it has any.
The name is the contract: `./setup.sh --check` and CI **discover** `tools/*_scan.sh` rather
than naming them, so a new one is picked up with no edit to either. Both are cheap on a
large repo — one `git grep` for the whole tree, not one process per file.

| File | What it is |
|------|-----------|
| `secret_scan.sh` | Heuristic backstop for committed credentials — keyword + separator + a literal value, across the tracked tree. gitleaks is the real tool; this catches an obvious paste. A reviewed line is cleared with `# scaffold:not-a-secret` (or an existing `# nosec`), never by excluding the file or renaming the variable. |
| `mode_scan.sh` | Fails while a tracked file's recorded mode disagrees with its shebang. A script that lost its `+x` does not error — it silently stops being run by every `[ -x ]` loop, and a suite that did not run looks exactly like one that passed. `--fix` applies the same `git update-index` the message prints, to the **index only** — the working tree is untouched, so `git diff --cached` shows exactly what changed before you commit it. It exists because the hint was not enough: this caught the same defect four times in one session, naming the exact command every time, one file at a time. It reads the **index**, never the working tree: `core.fileMode false` is the correct setting on a filesystem that reports 0700 for everything, and it is exactly what makes this invisible locally. Upstream it checks every tracked file; in an adoption, only files whose header says the scaffold wrote them. |
| `conflict_scan.sh` | Fails the build while merge-conflict markers are committed. They arrive from `--upgrade` on a MERGE-class file, and the instruction to resolve them was for thirteen releases the only thing enforcing it — this scaffold's own dev repo committed a set and stayed green for two releases. A deliberate example is cleared with `scaffold:not-a-conflict` on any of its three marker lines. |

Each carries `--selftest`, which the CI discovery loop finds automatically. See
`docs/TROUBLESHOOTING.md` for what to do when either one goes red.

### `doc_currency.py` — a document that describes code, and code that moved on without it

Every other check in this repository asks whether the tree is *internally* consistent: paths
resolve, links resolve, markers are registered, headers are stamped. None of them relate a
**document** to the **code it describes**, and that is where the drift actually happens.

Measured 2026-09-11. `mcp_client.py` 0.13.0 → 0.13.1 changed what an empty credential does:
it used to be accepted and sent as `Authorization: Bearer `, and now it refuses. `docs/MCP.md`
described the old behaviour in four places, including a sentence promising a 401 the code no
longer lets you reach. **Every gate passed** — paths, links, flags, selftests, CI.

So a document declares what it describes, and the version it was last read against:

    <!-- scaffold:documents src/localcoder/mcp_client.py @ 0.13.1.20260911.0900 -->

Column 0, like every other marker; an indented example is documentation, not a declaration.
The gate reads the source's own `# Version:` header and compares.

**It reads the version header, not `git log`.** A commit that touches a file is not a claim
that anything a reader was told has changed — a typo fix would fire it, and a gate that fires
on noise is one people clear on autopilot and then clear on the day it mattered. A version
bump *is* that claim, made deliberately by the author.

**It cannot prove the document is right.** Nothing can. It proves somebody *looked* since the
source last changed, which is the whole difference between a document with an owner and one
nobody has opened in four months. Moving the marker without re-reading is how it becomes a
formality, and the failure message says so.

Three outcomes, like everything else here. A declared source that does not exist is a
**failure**, not a skip — otherwise a rename retires a document's only tie to the code
silently. And **no markers at all is exit 3**, reported as a GAP: a checker that examined
nothing and a checker that found nothing wrong are different answers.

    tools/doc_currency.py            # report every declared coupling
    tools/doc_currency.py --check    # exit 1 if a document is behind

### `python_floor.py` — a `requires-python` that nothing ever checked

`pyproject.toml` declares `requires-python = ">=3.9"`. Measured 2026-09-22: **nothing in this
repository read that value.** Not `setup.sh`, not any gate, not CI. It was a promise made to
every downstream installer and audited by no one — the same shape as a document with no owner,
except the reader finds out at import time on a machine you do not have.

The gate parses every Python file in the tree against the declared floor's own grammar, using
`ast.parse(src, feature_version=(major, minor))`. A file that uses `match`, a walrus in a
comprehension's condition, or PEP 604 `X | Y` annotations under a 3.9 floor fails to parse and
is named with its line.

**It finds files without a `.py` extension.** `localcoder`'s entry point is
`src/localcoder/localcoder` — no suffix, a python shebang, and the single most important file
in the package. A glob for `*.py` would have declared the project clean while never opening it.

**SYNTAX ONLY, and it says so on every run.** `datetime.UTC` is 3.11 and parses perfectly under
a 3.9 floor; so does every stdlib call, argument, and attribute added since. This gate proves
the *grammar* is honest and makes no claim about the library. Printing that limit is the point
— a checker whose scope is misremembered is worse than none, because it is trusted for what it
never measured.

Three outcomes. No `pyproject.toml`, no `requires-python`, or a floor this interpreter cannot
express are all **exit 3, a GAP** — "nothing declared a floor" and "every file honours the
floor" are different answers and must never share a verdict.

    tools/python_floor.py            # report the declared floor and every file checked
    tools/python_floor.py --check    # exit 1 if a file needs a newer Python than declared

### `shell_lint.sh` — a suppression for a tool that never ran

Before 0.110.0 the only mention of ShellCheck anywhere in this repository was a
`# shellcheck disable=SC2086` directive. Nothing invoked it. A suppression comment is evidence that someone once
expected the tool to run, which makes it the most misleading possible artefact to leave behind.

**The severity floor is `error`, and it was chosen by counting rather than by taste.** On this
tree the day the gate was written:

| floor | findings |
|---|---|
| `-S style` | 178 |
| `-S info` | 174 |
| `-S warning` | 37 |
| `-S error` | **2** |

A gate that arrives permanently red is a gate people clear on autopilot, and then clear on the
day it matters — the failure mode `ai/STANDARDS.md` already documents for the header check.
`error` is the floor this tree can hold at zero, so a finding here is news rather than weather.

**And the floor is not a compromise.** Of those two findings, one was a real latent bug that
`bash -n` cannot see: `ci_status.sh` carried `${{ vars || 'ubuntu-latest' }}` unescaped inside
a double-quoted string, so bash printed `bad substitution` to stderr *instead of* the message —
the one line explaining a set-but-empty runner variable, broken in exactly the case it exists
to explain, since the day it was written. The other was a false positive, now suppressed at the
line with its reason. No other gate in this repository could see either.

**It finds shell files by extension or by shebang**, for the reason `python_floor.py` does:
`tools/` has carried extensionless executables before, and the file a glob misses is never the
boring one.

    tools/shell_lint.sh --check      # exit 1 on a finding at or above the floor
    tools/shell_lint.sh --list       # which files it considers shell
    tools/shell_lint.sh --pin        # the version and floor it will use

### `workflow_audit.sh` — the workflows are code, and they ship

On 2026-09-21 zizmor found a live template injection in `.github/workflows/scaffold-check.yml`:
`github.base_ref` — an attacker-controllable branch name — interpolated straight into a `run:`
block. Because that workflow is vendored into every adopter, the same line was live in four
repositories at once. **It was found by a person running the tool by hand, once.** Nothing ran
it on a schedule, and the sweep the following day still missed a repository that was carrying
it. This gate is that sweep, made routine.

**`--persona=auditor` is the most important flag in the file.** zizmor's default persona
suppressed **7 of the 11** findings on this tree. A gate invoking `zizmor` plainly would examine
four findings while printing something that reads exactly like a full audit — a non-verdict
wearing a verdict's clothes.

**`--min-severity high` was also measured, not guessed.** Against a reconstruction of the real
bug, `${{ github.base_ref }}` in a `run:` block is `error[template-injection]`, **high**; the
three surviving `${{ needs.<job>.result }}` interpolations are `help`, **low** — `needs.*.result`
is a closed enum the workflow engine writes, not user input. So the floor separates the
injection that can hurt from the three that cannot, and the gate is green on this tree today
while still red against the exact bug that motivated it.

**The exit mapping is inverted, and that is the trap.** zizmor and this toolchain disagree
about what `1` means:

| zizmor | means | this tool |
|---|---|---|
| `0` | clean | `0` pass |
| `14` | findings | `1` found something |
| `1` | **could not run** | `3` verified nothing |

On that last case zizmor writes `fatal: no audit was performed` to **stderr** and leaves
**stdout completely empty** — so a wrapper that passes the code through reports *findings* when
nothing was audited, and one that reads stdout for its verdict sees a clean, quiet nothing. The
selftest proves each arm against stub binaries, and fails if the mapping is flattened.

One more trap worth naming: zizmor prints `(N ignored)` both when the **persona** suppresses a
finding and when `--min-severity` filters one. They are not the same thing.

**It also carries one check that needs no zizmor at all**, so it does real work on a box that
cannot audit. GitHub runs a `run:` block as `bash -e`, which means

    tool --check; rc=$?          # WRONG — the shell dies here, rc=$? never runs

kills the step at the first non-zero and leaves every line of exit-3 handling below it as dead
code. `|| rc=$?` is the correct form, because the left side of `||` is exempt from `-e`. This
gate's own CI step shipped with that bug on 2026-09-22: the Linux runner went red with
"Process completed with exit code 3" while the macOS runner passed the same commit, because
macOS had the binary and never took the failing path. **A three-outcome gate whose third
outcome is unreachable is a two-outcome gate**, and only a heterogeneous fleet revealed it.

**actionlint is the second half** (report item 29). zizmor reads a workflow for security;
actionlint checks that it is *valid*: an unknown key, a `needs:` naming a job that does not
exist, an expression that will not type-check. Those otherwise fail on GitHub, often only on
the event that exercises them. It runs at a pin, with `-shellcheck= -pyflakes=` so that a box
which happens to carry shellcheck does not get a different verdict for the same commit (shell
in workflows is `shell_lint.sh`'s job). actionlint's `1` is a finding; `2` and `3` audited
nothing and map to exit 3. **One missing tool does not hide the other's verdict**: each half
prints its result, a finding from either is exit 1, and otherwise a half that did not run
makes the whole run exit 3.

    tools/workflow_audit.sh --check     # exit 1 on a finding from either tool, 3 if one could not run
    tools/workflow_audit.sh --pin       # the zizmor version, persona and floor it will use

```bash
tools/preflight.sh                           # ALL of the below, plus ruff and every selftest
tools/preflight.sh --list                    # what it runs, in order
tools/preflight.sh --coverage                # does CI invoke anything preflight skips?

tools/scaffold_upgrade.sh --selftest         # end-to-end checks, synthetic, offline
tools/scaffold_upgrade.sh --dry-run          # what an upgrade would do; changes nothing
tools/header_check.sh --selftest             # prove the checker fails what it should
tools/header_check.sh                        # every source file has a complete header
tools/header_check.sh --since origin/main    # everything you changed was re-stamped
tools/skills_check.sh                        # silent when in sync
tools/scaffold_version.sh --force            # ignore the 24h cache
```

**Why a header checker exists at all.** `ai/CODING.md` has always called the header
mandatory and `ai/STANDARDS.md` has always required a build stamp per PR. Nothing checked
either until 2026-08-04, and the repo publishing the rule was the clearest violator:
`setup.sh` carried a stamp four versions and a month behind its own last change,
`session_archive.py` had no `Version:` line, `sync-check.sh` had no header at all. Same
shape as the `SESSION.md` that reached 1,001 lines against a stated ~150 — the rule was
there, everyone agreed with it, nothing was watching.

`Modified:` is not bookkeeping. It is how the next reader decides whether the measurement
quoted in a comment still describes the code underneath it — and this repo's comments are
full of measurements.

**`scaffold_version.sh` compares ordered version components, not strings.** Anyone tracking
`main` carries a build stamp *newer* than the latest release, and a plain inequality
reported them "BEHIND" — which is the fastest way to teach people to ignore a version
check. It reads `.scaffold-version` (the scaffold release you vendored), never `version`
(your own project's number); those were one file, and a human who thought to look was
reading the wrong number entirely.

---

## Local coder (optional)

Optional helpers for the **local-coder orchestrator workflow**: a cloud agent (Claude Code,
Codex, ...) plans and verifies, while a **local LLM** does the bulk code generation — free,
offline, no rate limits. Skip the rest of this file entirely if you don't run a local model.

The design and the rationale — why the local model is called as a *tool* and not a
sub-agent, what to delegate, and the review gate — are at the bottom of this file under
**Policy moved out of the always-loaded files**. `ai/CODING.md` carries a pointer only:
that file loads into every session and this policy does not belong there (W-10).

## Contents

**None of this is in `tools/` any more.** W-15 made localcoder a separate product; the
scaffold ships the INTEGRATION POINT and nothing else. Install it once per machine:

```bash
uv tool install git+https://github.com/Robiton/localcoder
```

| What the scaffold still ships | What it is |
|------|-----------|
| `../ai/localcoder.config.json` | Committed per-project pins — approved models, digests, context window, check policy — so every machine behaves identically. **Ships as a template with reference values; replace them or delete the file.** Its PRESENCE is a project saying it intends to delegate (DEC-21), which is why the upgrade keeps it even though the tool left. Scopes are exclusive: this file wins outright over a developer's `~/.config/localcoder/config.json`, used only when this one is absent or declares `"extends": "device"`. `localcoder --where` names the scope and the origin of every setting. |
| the marked drafting brief | The `localcoder:begin:<lang>` region in `ai/CODING.md`. localcoder injects ONLY that block, not the whole file. |
| the markers | `scaffold:owns-localcoder`, read from `ai/STANDARDS.md` by `setup.sh --upgrade`. `-forked` and `-diverged` are retired and read by nothing. See *The markers* at the bottom of this file. |
| `localcoder_footprint.py` | Measures how many lines of localcoder POLICY sit in the always-loaded `ai/` files, and fails on a budget. The scaffold's own number is 28; downstream it is advisory, because that is OUR number and an adoption leaning on the local model should carry more. |

The commands below are the INSTALLED tool's, run from anywhere once it is on your PATH.

<details><summary>What used to live here, for anyone reading an old release</summary>

| File | What it was |
|------|-----------|
| `localcoder` | A Python CLI that POSTs a coding task to Ollama and prints the code. `--task-template <name>` prepends the invariants this project declares for that kind of work (`--task-templates` lists them; an unknown name is a hard error, never a silent pass-through). `--delegation` prints what this project sends to the local model at all. `--digest <path>` adds API surface instead of whole files; `--context targeted|repo|none` sets the scope and **records it in the log**, and prints the token cost — with the seconds of prefill it will cost when the model declares a `prefill_toks` rate, because prefill varies ~6x across models one fleet has approved and the slowest is often the default on quality. `-f` is unchanged and still sends whole files: that is the file you are working *in*. Injects the **marked drafting brief** from `ai/CODING.md` (see below), relevance-matched gotchas from `ai/MEMORY.md`, and any `-f` context files. The agent runs it via its shell tool, then reviews/integrates/tests/verifies. |
| `../ai/localcoder.config.json` | Committed per-project pins — approved models, digests, context window, check policy — so every machine behaves identically. **Ships as a template with reference values; replace them or delete the file.** Scopes are exclusive: this file wins outright over a developer's `~/.config/localcoder/config.json`, which is used only when this one is absent or when this one declares `"extends": "device"`. `localcoder --where` names the scope and the origin of every setting. |
| `api_digest.py` | The **callable surface** of a file or tree — declarations and the first doc line, never bodies. Measured on this repo: 686 KB of `tools/` and `ai/` reduce to 136 KB **in 78 ms**, which is why it is generated on demand from the working tree rather than cached by a commit hook with a staleness gate. There is no staleness to gate, and a commit-time index is stale exactly when you need it — you draft against the file you edited a minute ago. Python via `ast`; other languages by declared line patterns, extended in `ai/localcoder.config.json` under `"digest"` rather than by editing the tool. Multi-line declarations are **collapsed, not truncated**: `const ALL := [` alone tells a model nothing, and the contents of that table are what it otherwise invents. |
| `audit_localcoder.sh` | Adversarial behavioural audit; `--offline` runs the subset that needs no Ollama. Re-run after any change to the tool. |
| `localcoder_eval.py` | **Optional** execution-graded coding eval — does the model write code that WORKS. Reads tasks from `ai/eval_tasks.py` (**yours**, never overwritten by an upgrade). `--selftest` proves every reference passes and every trap is caught, needs no Ollama, and CI runs it. `--compare` fails on a >10% pass@1 regression however much faster the candidate is. |
| `localcoder_history.py` | **Optional** the committed, cross-machine benchmark and eval history — `--publish` merges this machine's gitignored rows into `docs/benchmarks/reference/history.jsonl`, `--render` regenerates `HISTORY.md` grouped by model, digest and `num_ctx` with Δ computed against the earliest row in each group. The per-machine files never meet without it. `--selftest` covers the merge and the deltas.  **`--attribution`** answers *does drafting earn its place* in DX Core 4's four numbers — **speed** (drafts, wall clock), **effectiveness** (did the drafted lines survive, and which way is the trend), **quality** (lint-clean rate, retries, and how many drafts could not be checked at all) and **impact** (what landed). It reports **two bounds and says the truth is between them**: *up to* counts every drafted line, *at least* counts lines still present byte-for-byte in the tree. Neither is a productivity measure, and the report says why — DORA 2025 records output rising while delivery stays flat, so volume is the number most likely to mislead a team.|
| `localcoder_bench.py` | **Optional** hardware-stamped benchmarks → `docs/benchmarks/`. Nothing fails without it. Asks `localcoder --config-path`, so it measures at the window the tool actually resolves — including one inherited via `"extends": "device"`. `--selftest` proves that offline. Runbook and conditions: [`localcoder/docs/benchmarks/README.md`](https://github.com/Robiton/localcoder/blob/main/docs/benchmarks/README.md); the generated data is gitignored and never ships to adopters. |
| `com.ollama.serve.plist.template` | macOS LaunchAgent to run Ollama persistently (independent of any terminal). |
| `install_ollama_service.sh` | Renders and installs that LaunchAgent, **deriving `OLLAMA_CONTEXT_LENGTH` and `OLLAMA_KEEP_ALIVE` from whichever config `localcoder --config-path` resolves** — project or device — so the server default cannot drift from the window the client asks for. Now `ops/install_ollama_service.sh` in `Robiton/localcoder`. |

</details>

## Start here: `localcoder --doctor`

Preflights the whole chain and prints the exact remediation for each failure — config
present, Ollama reachable **and new enough**, pinned model pulled, **digest matching the
pin**, RAM sufficient for the selected model, and formatters present **at the pinned
version** for the languages this project declares. Exits non-zero, so it can gate
onboarding or run in CI. `setup.sh` runs it at the end (advisory — it never fails setup,
since this workflow is optional).

**Three things are pinned, because all three change the bytes you commit:**

| Pin | Where | Empty means |
|---|---|---|
| Model tag | `default_model` / `approved_models` | — |
| Model **digest** | `approved_models[tag].digest` | *not pinned yet* — skipped, not failed |
| **Formatter version** | `formatters[lang].expect` | *not pinned yet* — skipped, not failed |

The formatter pin matters for the same reason the model pin does: `--check` **runs** the
formatter and the formatter **rewrites the draft**, so two developers on different minors
can run the identical task against the identical model and still commit different bytes.

`expect` is a **prefix match on a version token** — `"0.14"` matches `0.14.2` but not
`0.1` or `10.140`. Pin the minor, not the patch: formatters don't change output across
patch releases, so a patch pin buys churn rather than determinism.

**An empty digest or `expect` is deliberate, not an oversight.** The scaffold ships this
file as a template, and inheriting someone else's digest means every fresh clone fails
`--doctor` the moment that upstream tag is re-published, with no obvious cause. `--doctor`
prints the value to paste in once you've pulled the model you intend to keep.

Run it **on install and in CI, not per call.** Onboarding used to mean discovering by trial
that Ollama wasn't running, or the model wasn't pulled, or the formatter was missing — three
different opaque failures at three different moments.

## One context window, not four

`OLLAMA_CONTEXT_LENGTH` is the **server-wide default for any request that omits `num_ctx`**.
`localcoder` always passes it — which is exactly why this drifts unnoticed: the one client
that hardcodes past the problem is fine, while every *other* client of the same server (a
direct `curl`, an editor plugin, a tool added later) silently gets a different window.

```bash
ops/install_ollama_service.sh            # in Robiton/localcoder: render + install
ops/install_ollama_service.sh --render   # print it, change nothing
```

`--doctor` compares the installed LaunchAgent against the config and fails on drift.
**Re-run the installer whenever `num_ctx` changes** — the LaunchAgent is a per-machine
artefact installed once and never revisited, so drift there is permanent and invisible.

`min_ram_gb` is anchored to the context it was measured at
(`min_ram_measured_at_num_ctx`). On a **GGUF** model, raising `num_ctx` raises resident
footprint — 35.5 GB at 32k, 45.5 GB at 128k on the reference model — so a floor measured at
32k would otherwise keep reporting OK on a machine that will now swap. `--doctor` scales the
estimate and says it is an estimate. **It does not scale MLX floors**, because measurement
says there is nothing there to scale: the same MLX model is 26.94 GB at both windows.
Charging it ~1 GB per 32k would refuse models a machine can run comfortably, and enforcing
the wrong quantity is harder to notice than enforcing none.

## The drafting brief — the standards file is a PROMPT

`localcoder` injects **only** the block marked `<!-- localcoder:begin -->` … `<!-- localcoder:end -->`
in `ai/CODING.md`, not the whole file. Blocks may be language-scoped
(`localcoder:begin:python`) and then ship only when the task touches that language — which
is what makes this work in a polyglot repo: a Python task gets the Python rules and is not
charged for the others. **The language is resolved from the `-f` file extensions, then an
explicit `--lang`, then failing both, the wording of the task itself.**

Why it matters, measured: injecting the whole file cost ~3,440 tokens and ~16 s of prompt
processing **per draft** — 37% of wall time — to send rules that mostly could not apply. And
the file's *File headers* section was instructing the model to stamp headers on exempt files,
which was then logged as the model "fabricating" them. **The standards file caused the defect
and the review gate blamed the model.** Keep conditional rules, human-process rules, and
other languages' rules outside the block.

**A project with no marked block still works** — the whole file is sent, exactly as before.
That fallback is the compatibility guarantee for every existing project.

## Auditing and benchmarking

```bash
# In Robiton/localcoder, which owns the suite:
tests/audit_localcoder.sh              # full suite (live checks run if Ollama is up)
tests/audit_localcoder.sh --offline    # offline only — what CI runs
localcoder-bench --runs 3              # benchmark every approved model on this machine
localcoder --help                      # flags, without loading anything
localcoder --unload                    # give the memory back when you are done drafting
```

**Exit codes from the audit.** `0` everything ran and passed · `1` something failed ·
**`2` nothing failed but checks were skipped — incomplete, not success.** The suite used
to print "not run, NOT passed" and then exit 0, so CI went green having never exercised
`--doctor`, `--check` honesty or log anchoring. `--offline` is exempt: there the skips
are the declared scope.

The suite **reuses an already-resident model** if there is one, otherwise picks the
**smallest installed** and unloads it on exit. It previously took whatever the API listed
first and left it pinned — 37 GB for half an hour, as a side effect of running the tests.

**`--unload` releases the model.** `keep_alive` is 30m so a follow-up draft does not pay a
reload, which is the right default — but that pins 27-45 GB for half an hour after a
one-line helper request, and there was no supported way to say "I'm done".


**The audit builds its own throwaway project** — its own standards file with
language-scoped blocks, its own gotcha register, its own model registry, and a nested
subdirectory. It never reads this repo's `ai/` files, so it cannot be fooled by them or
broken by editing them.

Most checks assert on what the tool prints while **assembling the prompt**, which happens
before any network call — so they need no Ollama and no pulled model, and run in CI. The
three that need a real draft back are **skipped and reported as skipped, never as passes**.
A suite that silently passes what it did not run is the exact defect it exists to catch.

Three rules the suite is built on, all learned by getting them wrong:

- **Assert on observable behaviour, never on the artefact meant to produce it.** An earlier
  version grepped the tool's source; after the fixes it kept failing because the greps were
  stale, not because the code was broken.
- **A helper that prints its own verdict must also exit non-zero.** One check printed
  `FAIL` from a Python helper while the suite exited 0, because the shell was testing
  `python3`'s exit code rather than the assertion.
- **Choose the fixture from how the thing fails, not from how it is written.** This is the
  expensive one. Four checks here reported clean against broken behaviour, every time
  because the input had been picked by reading the implementation: the remote-host test
  used a hostname containing no `localhost` against a guard that was a bare substring
  search; the model-pin test exercised the env-var override and never the default, which
  was the unguarded path; the `--check` honesty test covered the one dishonest path someone
  had already thought of. **A test derived from the implementation can only confirm the
  implementation.** None of those four could have told the fix from the defect.

**The benchmark table is generated from the JSONL, not appended to.** `localcoder-benchmarks.jsonl`
is the source of truth; the `.md` is regenerated on every run, sorted by model then `num_ctx`.
That is why it can show `num_ctx`, `runs`, `digest`, `params` and `quant` — and why historical
rows gained the first two retroactively, having always been captured. It refuses to regenerate
if the table holds rows the JSONL cannot account for, and backs it up first.

**`digest` is read from `/api/tags` at bench time**, so a row records the weights that actually
ran. **A tag is not an identity** — Ollama can re-publish one, and a benchmark row that only
names a tag cannot be trusted across time, which is the single job these rows have.

**Benchmarks use a fixed synthetic corpus embedded in the script**, not a file from your
project. The point of a row is comparing one machine to another, and a corpus that differs
per project — or drifts as its files are edited — makes rows quietly incomparable. Prefill
and generation are reported separately because models trade one against the other, and a
prefill rate below ~500 prompt tokens is recorded as `n/a*` rather than published, because
at that size the number is fixed overhead rather than throughput.

## Setup

Prereqs: Apple Silicon Mac (32 GB+ unified memory for MLX), Homebrew, an orchestrating
agent (e.g. Claude Code).

```bash
# 1. Ollama — RUN 0.33.3. Newest on Homebrew and upstream as of 2026-09-09.
#    The numbers below are FEATURE FLOORS, not a recommendation: 0.14+ for the native
#    Anthropic endpoint, 0.19+ for the MLX backend, and 0.33+ for `ollama launch`.
#    A floor says what stops working underneath it; it does not say what to install.
#    CHECK THE API, NOT `brew info`. Local formula metadata is only as fresh as the last
#    `brew update`, and a stale cache reports an older stable with no indication it is
#    stale — measured 2026-09-08, when a cache last refreshed on 2026-09-03 reported
#    0.33.2 and was believed over a correct document:
#      curl -s https://formulae.brew.sh/api/formula/ollama.json | grep -o '"stable":"[^"]*"'
brew install ollama

# 2. A local coder model. On Apple Silicon prefer a mixture-of-experts coding tag:
#    at the SAME memory footprint an MoE (~3B active per token) measured ~4.5x faster
#    than a dense model of equal size, at indistinguishable output quality.
#    It buys SPEED, not correctness — do not attribute a prompt fix to a model swap.
ollama pull qwen3-coder:30b-a3b-q8_0   # MoE, ~32 GB. Check ai/localcoder.config.json for this project's approved list.

# 3. Install the tool. It is a separate product (W-15) — NOT vendored in tools/.
uv tool install git+https://github.com/Robiton/localcoder
localcoder --doctor                                    # verify the whole chain before first use
localcoder "write a python is_prime(n) with a docstring"   # smoke test (first call cold-loads the model)

# 4. Run Ollama as a persistent service (so it survives closing the terminal)
#    Edit the template (replace REPLACE_ME with your username), then:
#    ops/install_ollama_service.sh in Robiton/localcoder does this and derives the
#    context length from your config, so the server default cannot drift from the pin.
launchctl load -w ~/Library/LaunchAgents/com.ollama.serve.plist
curl -s localhost:11434/api/tags     # verify
```

## Using it

In a normal cloud-agent session, tell the agent to use the tool:

> "Use the `localcoder` command via your shell tool to draft each piece, then review it, wire
> it in, run it/tests, and fix anything wrong before moving on. Start with `<first task>`."

Loop: **plan → `localcoder -f <context> "<task>"` → review → integrate + test → verify.**

## Configuration

**Four scopes, and the first one found wins WHOLE.** They are exclusive, not layered.

| | Scope | Where | Who it is for |
|---|---|---|---|
| 1 | explicit | `$LOCALCODER_CONFIG` | a one-off run, CI, or trying a config before committing it |
| 2 | **project** | `<project>/ai/localcoder.config.json` | **committed** — fifteen machines draft with the same model at the same settings |
| 3 | **device** | `$XDG_CONFIG_HOME/localcoder/config.json` (usually `~/.config/localcoder/config.json`) | every project on this machine that does not pin its own — including ones with no `ai/` directory at all |
| 4 | built-in defaults | — | nothing pinned anywhere |

While a project config exists, a developer's device config is **ignored — including for the
keys the project leaves unset**, which fall to built-in defaults rather than to the device.
That is the deliberate part: a device file quietly filling in what a project did not set is
exactly the per-machine divergence a committed config exists to prevent, and it would
happen with no message. To inherit device defaults *on purpose*, the project declares it:

```json
{ "extends": "device", "num_ctx": 65536 }
```

The merge is **shallow** and the project still wins per key. `approved_models` is never
deep-merged — a device must not be able to add a model to a reviewed registry.

- `localcoder --where` — the scope in force and the origin of **every** effective setting.
  It also says when a device config exists and is being ignored, so "my machine-wide
  setting does nothing" is answered in one command instead of an afternoon.
- `localcoder --config-path` — just the path. `install_ollama_service.sh` asks for it
  rather than re-implementing the walk, because a second implementation of a resolution
  rule stays true only until the rule changes.
- `localcoder --init-device` — write a starter device config. Unpinned, with an empty
  `approved_models`: a device file is one developer's convenience and must never quietly
  become team policy.

**`.localcoderrc` is gone.** It was the pre-fleet per-project config (plain `KEY=VALUE`)
and was removed in **v0.5.0, 2026-07-31**; this page went on listing it in the precedence
chain for four releases. Settings live in one of the four scopes above, or in an env var.

Rule and rationale: `ai/STANDARDS.md` → **A device config is never team behaviour**.
Symptoms and fixes: [`docs/TROUBLESHOOTING.md`](https://github.com/Robiton/ai-project-scaffold/blob/main/docs/TROUBLESHOOTING.md).
This file SHIPS to adopters and `docs/` does not, so the link is absolute on purpose —
a relative one resolves only inside the scaffold's own checkout.

| Key | Default | Notes |
|-----|---------|-------|
| `LOCALCODER_CONFIG` | unset | absolute path to a config file; **wins over both the project and the device scope** |
| `LOCALCODER_MODEL` | from config | must be in `approved_models` when a registry is declared |
| `OLLAMA_HOST` | `http://localhost:11434` | **non-local hosts are refused** unless `LOCALCODER_ALLOW_REMOTE=1` |
| `LOCALCODER_TEMP` | `model` | defer to the model's own tuned sampling; set a number to override |
| `LOCALCODER_NUM_CTX` | `131072` | `0` = model native. Overridable per model in `approved_models`. See the memory/truncation trade below |
| `LOCALCODER_THINK` | `0` (off) | see below |
| `LOCALCODER_STANDARDS` | `ai/CODING.md` if present | `0` disables |
| `LOCALCODER_ROOT` | auto-discovered | overrides the `ai/`-or-`.git` project-root walk |
| `LOCALCODER_GOTCHAS` | `3` | max relevance-matched `MEMORY.md` entries; `0` disables |
| `LOCALCODER_GOTCHA_FILE` | `ai/MEMORY.md` | when set, **overrides** the config's `gotcha_sources` list rather than being ignored by it |

Settings named in the config are **locked** unless listed in its `allow_overrides` — an
attempted env override exits naming the required value and the file to change. Changing the
model is a reviewed commit, not a shell export.

**`OLLAMA_HOST` is refuse-by-default for non-local hosts.** The premise of this tool is that
source never leaves the machine, and every `-f` file is POSTed to that host. One line in a
shell profile and a team streams source to a third party while believing the opposite — so a
warning isn't enough. Set `LOCALCODER_ALLOW_REMOTE=1` to opt in deliberately.

### Keys in the config file itself

The table above is **environment variables**. These are the keys in
`ai/localcoder.config.json`, and they are the ones an adopter actually edits — the file is on
`NEVER_FILES`, so an upgrade never rewrites yours and never delivers documentation for keys
added since you adopted. That is why they are listed here, in a file upgrades *do* refresh.

| Key | What it does |
|---|---|
| `default_model` | the tag used when nothing overrides it; must be in `approved_models` when that is non-empty |
| `approved_models` | the registry. An empty object means **no model is ever refused** |
| `approved_models.<tag>.digest` | pin the weights. Empty = not pinned yet, and is skipped rather than failed |
| `approved_models.<tag>.runner` | `MLX` or anything else. **Load-bearing**: it decides whether the prompt ceiling is the window or half of it, and whether the RAM floor scales with the window. Undeclared is treated as the halving runner |
| `approved_models.<tag>.num_ctx` | per-model window, overriding the global. Use it when your fleet runs both runners — the window is free on MLX and pre-allocated on GGUF |
| `approved_models.<tag>.min_ram_gb` / `.min_ram_measured_at_num_ctx` | the floor, and the window it was measured at. `--doctor` scales GGUF floors and refuses a model this machine cannot hold |
| `approved_models.<tag>.prefill_toks` | measured prefill rate **at repo scale**, so `--digest` can print the seconds before spending them. Never guess one — an invented rate turns a real trade into a confident wrong number |
| `num_ctx` | the global window. Changing it means re-running `ops/install_ollama_service.sh` |
| `delegation` | **what this project sends to the local model at all** — see below |
| `digest.languages` | extend `api_digest.py` with declaration patterns for a language it does not know, without editing the tool |
| `tasks` | named prompt templates, one per kind of work (`--task-template`). Ships empty; an unknown name is a hard error |
| `formatters`, `standards`, `gotcha_sources`, `keepalive`, `temperature`, `gotchas` | as named; `localcoder --where` prints every effective value and where it came from |
| `allow_overrides` | env vars a developer may set despite the config pinning them |
| `extends` | `"device"` to inherit your machine-wide config for keys this file leaves unset |

**`delegation` is the one to read first**, because it is what an agent follows:

```json
"delegation": {
  "policy": "draft-first",
  "languages": ["python"],
  "min_lines": 8,
  "delegate": ["a pure function with a stated contract"],
  "avoid": ["shell and YAML", "cross-file edits"]
}
```

`localcoder --delegation` prints the effective policy, **where it came from, and that it is
a project decision rather than a ranking of languages**. The shipped default is
`languages: ["python"]` because that is what this project measured, on its own code — so on
a Go, Rust or GDScript project an agent following it correctly sends nothing until you widen
it. `policy: "off"` turns delegation off and says so.

**The measured variable is context, not language.** On an adopting project, the same model
and the same GDScript task: with **no context, every API call was invented**; with four
whole files, none; with a signature digest at a third of the tokens, none. So the useful
question for an unlisted stack is *what to attach*, not whether the language qualifies.
`tools/api_digest.py` already extracts `.gd`, `.js`, `.ts`, `.go`, `.rs`, shell and `.py`.

`requires_context` turns that into a rule the tool enforces rather than advises:

```json
"delegation": {
  "languages": ["python", "gdscript"],
  "requires_context": {
    "gdscript": "only with an api_digest of the classes you call"
  }
}
```

A draft in that language with no `-f` and no `--digest` is **refused**, naming your reason
and the config key. `--context none` still works — deliberately blind is a choice, it is
recorded in the log, and a flag that is silently overridden is a lie. It ships **empty**:
which languages need it is a measurement each fleet takes, and a guessed entry refuses work
that was fine. Deleting `ai/localcoder.config.json` opts out of localcoder
entirely, including its `--doctor` block in `setup.sh --check`.

### What each draft records

Every call appends one line to `.localcoder-log.jsonl` at the project root (gitignored,
per-developer). `localcoder-history --attribution` reads it. The fields that answer a
question you will actually ask:

| Field | Answers |
|---|---|
| `contract` | was a `--contract` block attached? A digest fixes signatures; a contract fixes semantics, and they are independent |
| `gotchas_selected` | **which** entries were injected, not just how many — a count cannot tell a good selection from a bad one |
| `truncated`, `num_ctx` | **did the model receive what was sent?** `truncated` is computed from the server's own `prompt_eval_count`, so it is evidence rather than an estimate |
| `context`, `context_digested`, `context_chars` | what scope was sent — `targeted`, `repo` or `none` — and how much of it |
| `line_hashes` | fingerprints of substantial drafted lines, which is what makes the *survival* bound computable later |
| `seconds`, `calls`, `prompt_tokens`, `eval_tokens` | wall clock across every round trip including a retry, not the model's own durations |
| `template` | which `--task-template` was applied, so "phrasing moves quality" is testable rather than asserted |
| `checked`, `lint_clean`, `retried` | whether `--check` ran, what it found, and whether a retry followed. `lint_clean: null` means **could not check**, which is not the same as clean |
| `gotchas_parsed`, `gotchas_injected` | an empty register and an unparseable one look identical without both |
| `context_files` | the paths sent with `-f`, extracted from the prompt actually built |
| `stamp`, `lines`, `chars` | when, and how much code came back |
| `model`, `task` | the tag, and the first 200 characters of the task as typed |

The list above is checked against the tool: every field it writes appears here, and
nothing here is invented. A reference table that drifts from the code is worse than no
table, because it is quoted with confidence.

**Gotchas are read from `ai/MEMORY.md`, and only from Markdown list items.** An entry is a
`- ` (or `* `) item starting at **column 0**; a prose paragraph under that heading is not
read. Relevance is scored per task keyword — **1** in the body, **3** in a `**bolded
title**`, **5** in a `<!-- tags: a, b -->` comment inside the entry — and an entry needs
**3** to be injected at all. Blank lines, fenced examples, HTML comments and italic
guidance lines are never entries, so the format example the template ships cannot inject
itself.

Until v0.8.0 an unreadable register was **silent**: a project with a full page of prose
gotchas got zero injected on every call, indistinguishable from having nothing to say.
Now the tool distinguishes all three outcomes on stderr — nothing recorded, nothing
*readable* (with the required form), and nothing relevant (with how many were read and how
many were skipped as toolchain notes). The decision log records `gotchas_parsed` alongside
`gotchas_injected` for the same reason.

**The flags worth knowing** (scope flags are in the table above; `--help` lists them all):

- `--check` runs the project's formatter then linter on the draft and hands any complaint
  back for **one** retry. The formatter *rewrites* the draft, so style arrives fixed rather
  than reported, and its **exit status is kept** — gdformat, rustfmt, gofmt and prettier all
  refuse to parse broken code, so refusing is a real finding rather than noise.

  **"Could not check" is a distinct third state and is never logged as "clean".** It prints
  `UNCHECKED`, names what did not happen, and logs `lint_clean: null`. That covers a missing
  formatter, a missing linter, a timeout, a language with no `CHECKS` entry — and the case
  that hid longest: a language with a formatter but **no standalone linter**. javascript,
  typescript, rust and go ship that way, because clippy and `go vet` need a package rather
  than a scratch file. Until 2026-08-04 those four logged `lint_clean: true` having linted
  nothing, and said nothing on stderr.
- `--lang <name>` scopes the brief when there are no `-f` files to infer from.

**Context window: the cost is a property of the runner, not of the model.** Measured
2026-08-09, M5 Max / 64 GB / Ollama 0.32.5, one server, a ~20-token prompt:

| `num_ctx` | `gemma4:26b-mxfp8` (MLX) | `qwen3-coder:30b-a3b-q8_0` (GGUF) |
|---|---|---|
| 32,768 | 26.94 GB | 35.48 GB |
| 131,072 | 26.94 GB (**unchanged**) | 45.46 GB (**+10 GB, unused**) |

**MLX sizes the cache to the sequence**; a window you don't fill is free, and the two
numbers above are identical rather than close. What it costs is ~70 KB per token actually
sent — 26.94 GB idle, 33.1 GB holding 88,998 tokens — so a *full* 131,072 window is about
+9 GB, and only while you're in it. **GGUF pre-allocates the whole window at load**: that
+10 GB was paid for a fifteen-token prompt. Set `num_ctx` per model in `approved_models`
when your fleet runs both.

**Generation speed:** measured flat across a 4x window range on GGUF (M3 Max, 55.4 tok/s at
32k / 64k / 128k). On MLX the window's effect is **below this machine's thermal noise
floor** — see *Sustained load, not the window* below — so treat it as "not measurable here",
which is a weaker claim than "zero" and the only one the data supports.

*(This section previously carried one table, measured on the GGUF model, presented as a law
about all of them: "RAM accelerates, +1 GB then +4 GB". True of that model. Six of the eight
models this project has approved are MLX, including the default, and for those the memory
axis of that conclusion is simply absent. An earlier revision before that claimed capping
had "no speed change", which was true of generation and false of prefill.)*

**The halving is the part that actually bites.** The llama.cpp runner reads `num_ctx/2` and
reserves the rest for generation. Past that it keeps the first **four** tokens and drops the
front of your prompt — standards first — and **tells the client nothing**; the warning goes
to the server log:

```
msg="truncating input prompt" limit=16386 prompt=32832 keep=4   (num_ctx  32,768)
msg="truncating input prompt"  limit=4098 prompt=18997 keep=4   (num_ctx   8,192)
```

Measured against the same 200,000-character prompt at `num_ctx` 8,192: the GGUF model
received 4,098 tokens and answered in **2.3 s**; the MLX model received all 63,431 and took
58.6 s. **The truncated call was the fast one** — a prompt losing 94% of itself presents as
the tool getting quicker, and the reply still reads plausibly because the model answers the
question it was left with. MLX did not truncate at any window tested.

So the working ceiling is `num_ctx/2` on GGUF and `num_ctx` on MLX. Both **`--doctor`** and
**`--where`** print it as **`max prompt`** — `--doctor` because it is the first thing an
adopter runs, and because `ai/localcoder.config.json` is on `NEVER_FILES`, so an upgrade
never delivers the table above to the project that needs it; the tool warns before the call from an estimate and reports
**`truncated`** after it from the token count the server returns. The second is the reliable
half — it is evidence rather than arithmetic, and it survives a tokeniser it has never seen.
(The widely-repeated "Ollama truncates to 4,096" claim is **false by default** on this
version; the halving is real at every window.)

**Thinking is OFF by default.** Thinking-capable models (qwen3.6 etc.) default thinking *on*
at the API and burn minutes of hidden reasoning before emitting code — measured 18s (off)
vs 75s+ (on) for the same prompt. General rule: any Ollama model whose capabilities include
`thinking` needs an explicit think decision in the harness; `localcoder` sends
`"think": false` unless `LOCALCODER_THINK=1`.

**Visibility:** if the project uses this loop, record `Localcoder: <files, or none>` in each
PR body (see `ai/CODING.md` → *Make usage visible*).

**Review is a gate, not a glance** — run the draft, check it against the ask and the house
standards, sample the edge cases. And the **two-strikes rule**: if a draft fails review twice
on the same task, stop re-prompting — split the task or let the cloud agent write that piece.
Full checklist in `ai/CODING.md` → *The review gate*; the `/verify` skill (`.agents/skills/verify/`)
runs the final verification pass.

**Hands-free (optional):** to avoid invoking it each session, add a **trigger directive** — a phrase
*you* choose — to your project context. See the *Local coder* section in `ai/CODING.md`.

### A digest fixes signatures. A contract fixes semantics. Shapes fix data.

They are independent, and an adopting project measured both. A signature digest took invented
API calls from **119 to zero** across six drafts — and one of those zero-invention drafts
still returned a `const` Dictionary **by reference**:

```gdscript
static func style_for(saga: int) -> Dictionary:
    return STYLES.get(saga, STYLES[SAGA_I])    # caller mutates the shared table
```

Correct signature, correct fallback, real aliasing bug. A sibling function **in the same
digest** called `.duplicate(true)` for exactly that reason; the model had the counter-example
in front of it and did not generalise. It lints clean, so `--check` cannot reach this class.

The same task, same model, same digest, with a contract naming the property:

```bash
localcoder --digest src/ --contract "POSTCONDITION: the caller MAY mutate what it receives
with no effect on any later call — Dictionaries are REFERENCE types here.
INVARIANT: STYLES itself is never modified at runtime." "write the lookup"
```

returned `STYLES[saga].duplicate()`, six `duplicate()` calls across the file, the bug gone,
plus an unprompted guard. This matches
[ContractEval](https://arxiv.org/html/2510.12047): models skew toward postconditions that
constrain the **output shape** and miss properties like aliasing.

**And a third failure sits under both.** A digest-fed draft read `row["name"]` where the key
is `"label"`. `gdformat` passed it, `gdlint` passed it, **the engine parser passed it** — a
wrong key is a runtime fault, so every mechanical gate was blind and a human reading the
draft caught it. The keys were built inside a *private* helper, which a digest correctly
drops, so the signature said "returns Array" and nothing said what the records hold.

`api_digest.py` now emits them:

```
# Data shapes built in this file — USE THESE KEY NAMES:
#   {bonus, label, value}
#   {rows, title}
```

Python shapes come from the **AST** — no regex can mistake a slice for a record — and other
languages use brace-balanced regions. **Opt-in per language** via `"shapes"` in the registry,
so nobody pays tokens for a guess. Measured on this repo with shapes on: still **19%** of
793 KB.

The contract is appended **last** and declared to outrank everything above it, and it is
**recorded in the log** — like `context` and `template`, so the claim stays testable rather
than argued. Standing postconditions for a *kind* of work belong in a `tasks` template; the
flag is for the ones specific to this draft.

## Honest limits

- **The weakness is lopsided, not uniform** — measured over ~3 weeks of real use. "Local
  models are ≈75–85% accurate" implies even weakness and therefore "check everything a bit
  harder", which makes review exhausting and still misses the bugs. The weakness is
  concentrated almost entirely in one place:

  | | observed |
  |---|---|
  | **Logic that follows from supplied context** | **Reliable.** Deterministic-ordering requirements, numeric constants, correctly reusing a helper from a `-f` file — right first time. |
  | **Engine/library API recall** | **Unreliable, and the only thing that shipped bugs.** Invented methods, methods put on the wrong class, hallucinated error accessors. |
  | **Acting as a reviewer** | **Confident false positives.** See *never let it close a search* below. |

  So the agent's verification step is **load-bearing**, but aim it: review-gate item 5 is
  where the defects are. Treat local output as a draft to check, never trust it blind.
- **A clean compile is not evidence of a real API.** Measured: Godot compiles
  `Thread.create()` without complaint. `--check` proves style and parse, never existence.
- **Rules are not self-enforcing.** An explicit rule in the drafting brief was verified to
  reach the model every call and ignored 4/4, while others in the same block were followed.
  Anything that must hold needs a checker behind it.
- **`--check` cannot lint every language.** javascript, typescript, rust and go get a
  formatter and no linter, because clippy and `go vet` need a package rather than a scratch
  file. Those drafts come back **UNCHECKED** — the formatter proves the code parses and
  nothing proves anything else. That is stated loudly rather than papered over, because
  until 2026-08-04 it was silently logged as `lint_clean: true`.
- **The prompt-size estimate is still an estimate**, now `chars/3.2` — measured on this
  codebase (200,000 chars → 63,431 tokens, 3.15) rather than the 4.0 rule of thumb for
  prose, which under-counted a real prompt by ~20% in the one direction that mattered. It
  is an estimate all the same, and a different tokeniser will move it; that is why the
  **`truncated` report after the call** exists, computed from what the server says it read.
  This limitation used to be an `INFO` line in the audit reading *"code tokenises higher, so
  the truncation warning under-fires"* — correct, unmeasured, and parked for weeks. It is
  now five checks, one of which fails if the constant drifts.
- **Gotcha relevance is keyword overlap**, weighted (a bolded title counts triple, an
  explicit `<!-- tags: ... -->` counts five). Measured roughly one useful entry in three on
  one task and three of three on another. Embeddings would fix it properly; that is a
  project, not a tweak.
- Cold start ≈1–4 min to load the model on first call; fast within the keep-alive window.
- macOS / Apple Silicon-specific as written (MLX, LaunchAgent). The pattern ports elsewhere;
  the model tags and service mechanism differ.

---

# Policy moved out of the always-loaded files (W-10)

Everything from here down used to live in `ai/STANDARDS.md` and `ai/CODING.md`, which load
into **every** agent session in every adopting project — including projects that will never
run a local model. Measured 2026-08-11 before the move: **393 lines** across six sections.
After: 20, all of it pointers and the three markers the tooling reads.

Nothing was dropped in the move. Three paragraphs were **merged** into *Honest limits*
above rather than repeated (the lopsided-weakness table, "a clean compile is not evidence",
and "rules are not self-enforcing"), and one withdrawn measurement was struck — see
*A number that used to be here* below.

`tools/localcoder_footprint.py` keeps the budget: it fails when localcoder policy in the
session-start load order goes back over 20 lines. W-10 is a documentation change, and
nothing about a documentation change stops the prose returning one paragraph at a time.

## The loop, and how to call it

A project may use a **local LLM as a coding assistant** under an orchestrating agent
(Claude Code, Codex, etc.). The cloud agent stays the **planner and verifier**; a local
model (e.g. Qwen 3.6 via Ollama, MLX-accelerated on Apple Silicon) does the bulk code
generation — free, offline, no rate limits. Optional; skip if you do not run a local model.

- **Invoke the local model as a tool, not a sub-agent.** A cloud agent's API base URL is
  process-global, so it cannot route a sub-agent to a different (local) endpoint. Calling
  the local model as a CLI sidesteps this — the agent runs `localcoder` via its shell tool,
  reads the output, integrates it, runs/tests, and verifies.
- **`localcoder` is a shell command, not an agent skill/option** — it will not appear in any
  agent menu. Tell the agent to *run the command*, e.g. `localcoder '<task>'`.

**The loop:** plan → `localcoder -f <context files> "<focused task>"` → review → integrate
+ test → verify or send back. Keep each task narrow — local-model quality is best on
well-scoped asks.

**Two-strikes rule.** If the local draft fails review **twice on the same task**, stop
re-prompting. The task is either too broad (split it and retry) or beyond the local model
(the orchestrating agent writes that piece itself). A third re-prompt of the same failing
task is never the answer.

**Smells — the loop is being run wrong if:**

- A local draft was integrated without being executed
- You are on the third re-prompt of the same task
- A draft passed review suspiciously clean and nobody asked why

**Enable it hands-free (optional).** To avoid invoking it each session, add a **trigger
directive** to this project's context — a phrase *you* choose that the agent recognizes. For
example: *"When I say `<your trigger>`, use the local-coder loop above — draft with
`localcoder`, then review/test/verify."* It is **trigger-gated** (only fires on your phrase;
ordinary edits still go straight to the agent) and is an instruction the agent follows, not
a hard rule. For mechanical routing instead, use a proxy such as `claude-code-router`.

## What to delegate, and what not to — measured, not assumed

**Give it a self-contained function in Python. Do not give it shell.**

Measured 2026-08-09, the same task in both languages, one prompt each, `qwen3.6:27b-mlx`:

| language | result |
| --- | --- |
| Python | **6/6** — every case passed straight out of the model, including four edge cases invented after the fact and never mentioned in the prompt |
| Bash | **did not parse.** `"```"` opens command substitution inside double quotes, and `flag=!$flag` is not a boolean toggle |

That is not a close call, and it is consistent with the evidence that already existed:
`ai/eval_tasks.py` is Python throughout, so 88% pass@1 has always been a statement about
Python and never about anything else. A shell draft has never been measured because a shell
task has never been in the suite.

**AND IT IS A PROJECT SETTING, NOT A FIXED RULE.** The numbers above are this project, this
model, this machine. A Go shop with a 70B model has a different answer, and a repo with no
local model has none. Declare yours in `ai/localcoder.config.json` under `delegation` and
read the effective policy any time with:

    localcoder --delegation

It lives in the config rather than in a standards file because the tool can read the config
and cannot read the standards — the same argument that put the archive ceilings in a marker.
`policy: "off"` turns delegation off entirely and says so.

**The shipped default, which is what applies until you change it:**

- **Delegate** — a pure function with a clear contract, in Python: parsing, formatting,
  transforming, a tricky loop, an edge case you can state.
- **Do not delegate** — shell, YAML, cross-file edits, anything needing repository context,
  and anything where the hard part is *deciding what to build* rather than writing it.

### A number that used to be here

This section used to end with an attribution figure — a percentage of landed lines credited
to the local model over a 30-day window — offered as the honest reason the routing rule
matters. **It is withdrawn.** It came from an invalid test, and by the time that was
established it had been quoted, reasoned from, and had three separate arguments built on
top of it.

**There is no delegation baseline for this project.** Establishing one is what the planned
use period is for, and `localcoder_history.py --attribution` plus the outcome capture in
W-23 are what will produce it. The routing rule above stands on the measured Python-vs-bash
result, which is a different piece of evidence and still good.

The withdrawal is recorded rather than quietly deleted because the failure mode is the
point: a number with no valid measurement behind it gets quoted, then defended, and the
only defence is writing down that it is gone.

## Send the subsystem, not the sentence

Narrow the *task*; do not narrow the *context*. The instinct is to send a tight, minimal
prompt — it feels efficient, and it is what you would do with a hosted frontier model. For a
local 30B it is precisely wrong: the model cannot infer your naming conventions, your helper
functions or your house patterns, so it has to **see** them. Measured across three drafts in
one session, same model, same settings, with context as the only variable:

| context supplied | result |
|---|---|
| task text only (a few hundred tokens) | fabricated 3 engine attributes; stubbed the actual deliverable as `pass` with a comment saying a real implementation would do it |
| one file (~2k tokens) | correct scaffolding, broken core logic |
| **the subsystem (~16.5k tokens)** — module under test, two peer files as patterns, both call sites | **7 of 7 symbols real, zero fabrications**, and it followed the project's assert-on-behaviour rule unprompted |

The third was that project's first draft with no fabricated symbols. **Peer files are the
highest-value context of all** — "follow this pattern" is a far easier instruction to satisfy
than "write it in our style".

There is a hard prerequisite: a subsystem does not fit in a small window, so this only pays
off if `num_ctx` is large enough to hold one.

**Check the ceiling, not the window — on GGUF they are not the same number.**
`localcoder --where` and `--doctor` print `max prompt`. That runner reads only `num_ctx/2`
and silently drops the front of anything longer, which is where the standards are; it tells
the client nothing and the reply still reads plausibly. Measured, an over-long prompt comes
back **faster**, so there is no symptom to notice. MLX-runner models did not truncate at any
window tested. Raising `num_ctx` is free on MLX until you fill it and is memory paid at load
on GGUF — set it per model in `approved_models` when you run both, and re-run
`ops/install_ollama_service.sh` after any change. The cost table is in
`ai/localcoder.config.json`; use `localcoder --unload` when you are done drafting.

Every draft records `truncated` and `num_ctx`, so *"did the model actually receive the
subsystem?"* is answerable after the fact rather than inferred from whether the output looks
right — which, measured, it does either way.

## The review gate — what "review" means

A local draft passes review only when all five hold:

1. **Run it, do not read it.** Execute the draft (or its tests) — "it parses" and "it looks
   right" are not verification. Verify at the layer of the claim (`ai/PLANNING.md` → *How to
   verify*).
2. **Check against the ask.** Does it do what the plan step required — not something adjacent?
3. **Check against the project's standards.** Naming, docstrings — house rules a local model
   will not know unless it was given them (see the drafting brief). Style is better
   *enforced* than reviewed: `localcoder --check` runs the project's formatter and linter,
   which rewrites whole classes of finding out of existence.
4. **Sample the edges.** Empty input, first/last item, the weird case — not just the happy path.
5. **Verify every engine/library symbol it named.** This is the failure mode that actually
   ships bugs. **A clean compile is not evidence** — measured: Godot compiles
   `Thread.create()` without complaint, and `godot --check-only` exits 0 on a file full of
   fabricated APIs. Confirm against runtime introspection (`get_method_list()` or the
   language's equivalent) or the documentation.

**Using a local model as a reviewer: never let it close a search.** Anything it emits during
a review is a *hypothesis*. Asked to hunt exploits in a server-authoritative component it
returned six findings; the two spot-checked were **both wrong** — it flagged calls whose
bounds checks were sitting inside the very functions it was flagging. It pattern-matches
handler names rather than reading guards. Use it to widen the search; verify before
repeating. Repeating an unverified finding is exactly how a false positive becomes a
documented bug.

## Discover the project's vocabulary — never assert it

When a check depends on a project-specific name — a helper, a convention, a directory —
**derive the set from the project**; do not hardcode it. Hardcode only names owned by the
language or framework, and say in a comment why those are safe. This defect class has
produced four distinct failures across two projects, two of them in this scaffold's own
history:

- The *File headers* section instructed a model to stamp headers, and the result was logged
  as the model "fabricating" them. **The standards file caused the bug report it received.**
- A static auditor hardcoded a list of guard-function names and reported 13 CRITICAL
  "unguarded handler" findings. All 13 were correctly guarded — via a project-specific
  helper name no hardcoded list could have predicted.
- Fixing that with an *unconstrained* transitive closure over the call graph produced 142
  "guard functions" including `_draw` and `_tick`, and the audit then reported all-clear.
  **A false all-clear is strictly worse than a false positive, because it is silent.**
- Five feature-presence checks returned a false ABSENT because they grepped for the name the
  checker expected rather than the one the project uses.

When deriving transitively, **constrain the derivation** (e.g. "a predicate returning bool
that reaches a framework primitive") — an unconstrained closure converges on "everything" and
then cheerfully reports all-clear.

**Corollary: a checker's first run is evidence about the checker, not about the code.**
Verify a sample of its findings by hand before believing any of them. In the case above that
step killed 13 of 13.

## Make usage visible, and route by shape

Without visibility, localcoder use silently drifts to zero under momentum. Two conventions
keep it honest:

- **PR attribution:** every PR body records which files were localcoder-drafted —
  `Localcoder: file_a.py, file_b.py` or `Localcoder: none` — so the local-vs-cloud ratio is
  auditable and under-use surfaces early.
- **Ask the question per task:** when planning a task, explicitly consider "is this a
  well-scoped draft localcoder should take?" — guidance, not a gate.

`localcoder` drafts; the agent reviews, tests and integrates. How much of what lands
actually comes from it is answered by `localcoder-history --attribution`, which reports
drafted lines against lines added to git, as an upper bound, over a window.

**Shape, not volume.** The same task in Python passed 6/6 straight out of the model —
including edge cases invented afterwards and never mentioned in the prompt — while the bash
version **did not parse**. Delegate self-contained functions; keep shell, YAML, cross-file
edits and anything needing repository context.

**Visibility, at the right moment.** The share is checked at **end of session**, not at
session start. A nudge you cannot act on yet is the noise that gets a report ignored — and by
the end of a session you know what you built and whether any of it was the right shape to
delegate.

**A low share is not automatically a problem to fix.** A session spent on shell tooling
should show near zero, and forcing work to the local model to move a number would be the
metric driving the work. What the number is for is noticing a session that had plenty of
delegatable work and delegated none.

## A device config is never team behaviour

`localcoder` resolves ONE config: `$LOCALCODER_CONFIG`, else this project's
`ai/localcoder.config.json`, else the developer's `~/.config/localcoder/config.json`, else
built-in defaults. **Scopes are exclusive.** While a project config exists, a device config
is ignored — *including for keys the project leaves unset*, which fall to built-in defaults
rather than to whatever that machine happens to have.

That is deliberate and it is the same rule as everywhere else here: a value that changes
behaviour must be **declared, not inherited from context**. A device file quietly filling the
gaps would mean two developers running one task on one project get different windows, with
nothing on screen to say why — the divergence a committed config exists to prevent,
reintroduced through a side door.

So:

- **Never commit a device config**, and never answer "it works on my machine" with one.
- A project that genuinely wants a developer's defaults declares `"extends": "device"` in its
  own committed file. Shallow merge, project wins per key; `approved_models` is never
  deep-merged, because a device must not be able to add a model to a reviewed registry.
- **`localcoder --where` prints the origin of every effective setting.** Read it before
  concluding a setting is being ignored — it says out loud when a device config is present
  and unused.

**Per-project config:** commit `ai/localcoder.config.json` to pin the approved model(s),
their digests, context window and check policy, so every machine on the project behaves
identically and changing the model is a reviewed commit rather than a shell export. Run
`localcoder --doctor` once on install (and in CI) to verify the whole chain — Ollama
reachable, model pulled, digest matching, RAM sufficient, formatters present. Thinking is
**off by default** (`LOCALCODER_THINK=1` to opt in).

## The markers (dual-homing is over)

**localcoder had two homes until W-15 and now has one.** It lived at `tools/localcoder` here
and `src/localcoder/localcoder` in `Robiton/localcoder`, byte-identical below the header, with
`tools/localcoder_sync.py` failing CI on drift. The scaffold no longer vendors it, so there is
nothing to compare — the sync tool, its record file and the `scaffold:localcoder-diverged`
marker all retired with the second copy.

```bash
uv tool install git+https://github.com/Robiton/localcoder
localcoder --doctor
```

**Two markers survive, and `setup.sh --upgrade` still reads both** from `ai/STANDARDS.md` at
column 0. An indented example inside a code block is documentation, not a declaration — every
marker check keys on exactly that difference, because this file documents its own markers and
an unanchored pattern once read that documentation as a declaration.

### `scaffold:localcoder-forked` — RETIRED 2026-08-14

**Nothing reads it, and nothing has since W-15.** It gated a drift check on a vendored
`tools/localcoder`; the scaffold stopped shipping one in that work item, so the check it
guarded no longer exists. Found by `tools/marker_scan.sh --audit` once that command stopped
accepting a comment as evidence of a reader — until then it was registered, documented here as
live policy, and inert. That is the same shape as `scaffold:localcoder-diverged`, retired for
the same reason, and it is the second time in this tree.

**Delete the declaration if a project still carries one.** Keeping it costs nothing visible
and buys nothing at all, which is precisely what makes it dangerous: a reader who sees it in
`ai/STANDARDS.md` concludes a fork is protected.

### `scaffold:owns-localcoder` — this repo SHIPS localcoder

Declared by `Robiton/localcoder` itself. `setup.sh --upgrade` then installs none of
localcoder's own files into it, and prints one line saying so, because an exclusion nobody can
see is indistinguishable from a bug.

**Without it, the repo that ships localcoder receives a second copy of its own product** —
and the checks then move to the wrong file rather than failing. Both `localcoder_sync.py` and
`audit_localcoder.sh` resolved a `tools/` path first, so the drift check and the behavioural
suite would have verified the vendored copy while `src/localcoder/localcoder` went unwatched,
both green. A check that silently changes what it measures is worse than one that breaks.

**"Owns" is about the UPGRADER, not about editing rights** — it means *upgrades will not
overwrite these files*. Renaming it was considered and refused: an adopter declaration that
silently stopped matching would let the next upgrade overwrite the product it protects, and
that failure is far worse than the confusion it fixes. (The sentence here used to contrast it
with `scaffold:localcoder-forked` as "the permissive one"; that marker is retired and read by
nothing, so the contrast was teaching a distinction that no longer exists.)

Suppressed under the marker: `tools/localcoder`, the `localcoder_*.py` helpers,
`audit_localcoder.sh`, the Ollama service installer and its plist template, and
`tools/.localcoder-sync` — that last one records *this* repo's own path and stamp, the same
reason `version` is never overwritten. **The list is a literal, and it must agree with
`localcoder_sync.py`'s `DUAL_HOMED`**; deriving it would break "declared, never inferred", and
an inferred list that comes back empty silently stops every adopter receiving localcoder.
`scaffold_upgrade.sh --selftest` asserts the two agree.
