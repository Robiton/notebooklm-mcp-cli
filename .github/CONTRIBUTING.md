# Contributing and AI Setup Guide

## First time on this project? Start here.

When opening this project with any AI tool for the first time,
paste this as your very first message:

> "Read ai/STANDARDS.md and load all files in the order it specifies
> before we begin any work."

The tool will load all project context automatically. Do not skip this step —
it is what ensures every tool and every developer starts from the same place.

---

## Before starting any session

Run the sync check to make sure your local `ai/` files match the remote:

```bash
./sync-check.sh
```

This prevents working from stale context when switching between machines.

---

## Supported AI tools

`AGENTS.md` is the universal standard — one file read by all tools.
`CLAUDE.md` is a committed one-line `@AGENTS.md` import for Claude Code — a reference, not a copy.

| Tool | Hook file | Behavior |
|------|-----------|----------|
| Claude Code | `CLAUDE.md` (`@AGENTS.md` import) | Loaded automatically at CLI startup |
| Claude (web / project) | `CLAUDE.md` (`@AGENTS.md` import) | Paste the prompt above on first message |
| Cursor | `AGENTS.md` + `.cursorrules` | Loaded automatically when project opens |
| Windsurf | `AGENTS.md` + `.windsurfrules` | Loaded automatically when project opens |
| GitHub Copilot | `.github/copilot-instructions.md` | Loaded automatically in supported editors |
| Codex / ChatGPT | `AGENTS.md` + `.codex` | Loaded automatically |
| Devin, Amp, Aider, Zed, Warp | `AGENTS.md` | Loaded automatically |

---

## Platform setup

### macOS / Linux (standard)

After cloning, make the scripts executable (CLAUDE.md needs no setup — it ships
committed as a one-line `@AGENTS.md` import):

```bash
chmod +x setup.sh sync-check.sh
./setup.sh
```

### Windows

`setup.sh` is a bash script. Run it in one of these environments:

- **WSL** (recommended): `bash setup.sh` or `./setup.sh` from a WSL terminal
- **Git Bash**: open Git Bash, navigate to the repo, run `./setup.sh`

CLAUDE.md needs no special handling on Windows — it is a plain committed file
(a one-line `@AGENTS.md` import), not a symlink.

### Headless Linux (no GUI)

```bash
git clone https://github.com/<your-handle>/ai-project-scaffold.git
cd ai-project-scaffold
chmod +x setup.sh sync-check.sh
./setup.sh
```

Everything works natively on headless Linux — no additional setup required.

---

## Git workflow

This org uses a **merge-only** workflow. Do not rebase.

### Starting new work
Always sync check and pull main before creating a branch:
```bash
./sync-check.sh
git checkout main
git pull origin main
git checkout -b feature/your-work
```

### Committing and opening a PR
```bash
git add .
git commit -m "type(scope): description"
git push origin feature/your-work
```
Then open a Pull Request in GitHub. Use the PR template in `.github/PULL_REQUEST_TEMPLATE.md`.

### Keeping your branch current
If another PR is merged into main while yours is open, bring your branch
up to date by merging main into it — never rebase:
```bash
git checkout feature/your-work
git fetch origin
git merge origin/main
git push origin feature/your-work
```
If merge conflicts occur, fix them in the affected files, then:
```bash
git add .
git commit
git push origin feature/your-work
```

### After your PR is merged
```bash
git checkout main
git pull origin main
# Start your next branch from the updated main
```

### Quick daily reference
```bash
# Starting new work
./sync-check.sh && git checkout main && git pull origin main && git checkout -b feature/new-task

# Updating your branch when main moves ahead
git checkout feature/new-task && git fetch origin && git merge origin/main && git push origin feature/new-task
```

---

## Session hygiene (required of everyone — human and AI)

At the end of every working session:

1. Update `ai/SESSION.md` — what was done, decisions made, next steps
2. Update `ai/BACKLOG.md` — mark completed tasks, add new ones
3. Commit and push both files before closing your session

This takes two minutes and is what makes context available to every teammate
on every machine using every tool. Skipping it breaks the whole system.

---

## CI enforcement

The scaffold includes a GitHub Actions workflow (`.github/workflows/scaffold-check.yml`)
that validates on every PR:

**Blocking — these fail the build:**

- All required `ai/` files exist, and `AGENTS.md` exists
- Every source file carries a complete header, and files changed in the PR were re-stamped
  (`tools/header_check.sh`)
- Every `tools/` selftest passes — **and a tool that advertises `--selftest` but is not
  executable fails too**, because a skipped suite is indistinguishable from a passing one
- `tools/secret_scan.sh` — no obvious credential anywhere in the **tracked tree** (not just
  `ai/`; widened in #120)
- `tools/conflict_scan.sh` — no committed merge-conflict markers
- `tools/adoption_check.sh` — this scaffold's own gates, run inside a synthetic ADOPTION
- ruff, **pinned to a version and a rule set**, over the scaffold's own Python only

**Blocking in the upstream scaffold repo only** — these cannot fire in an adopting project:
`.scaffold-version` matches `version`, and tracked file modes agree with shebangs.

**Non-blocking (warnings):** template-only `SESSION.md`/`BACKLOG.md`, unfilled `AGENTS.md`
placeholders, a missing `version` file, and any check whose **tool is absent**. Those
describe a fresh adoption that is not finished yet, not a rule being broken.

**Archive ceilings do NOT block, and have not since 0.14.0.** They were blocking from
2026-08-05, on the argument that a warning is exactly what went unheeded while `SESSION.md`
reached 1,001 lines against a stated ~150. That lost to a stronger argument: a gate on file
LENGTH stops the work in order to tidy the notes about the work, and fires on whichever
commit happens to cross the line, mid-thought, in a PR about something else. The report is
kept because the report is the remedy — it names the oversized entries and the one command
that fixes each. Build stamps and headers still block; they are deterministic and are not a
judgement call.

**If a ceiling is the problem, raise the ceiling, not the check.** Ceilings are per-project:
edit the `scaffold:ceilings` marker in your own `ai/STANDARDS.md`, which no scaffold update
overwrites. Do the archive pass first — "the ceiling is too low" and "I have not archived"
look identical from inside the file.

### Run it all locally before you push

**One command. Run it after `git commit` and before `git push`:**

```bash
tools/preflight.sh          # ~25s; exits 0 only if every gate CI runs passed here first
tools/ci_status.sh          # and AFTER pushing: is the remote actually green
```

It runs `header_check --since` in CI's stricter form, `setup.sh --check`, the pinned ruff,
and every tool's `--selftest` — discovered the same way the
workflow discovers them, so a gate added to CI is picked up here with no edit. `--coverage`
proves that: it reads the workflow, and fails if CI invokes a tool preflight does not.

**It reports every failure rather than stopping at the first, and that is the point.** CI
stops at its first red step, so one push teaches you about exactly one gate and hides the
next behind it. Measured on 2026-08-09: two red builds in three minutes, on the commits that
were adding a rule about checking CI — a stale header, then the localcoder drift check that
had never once been run locally. Preflight surfaces both in one run.

**A dirty tree is refused (exit 3), and that is not a failed check.** `header_check --since`
reads the committed diff plus the working tree, so a run against a half-committed tree does
not describe what you would push. `--allow-dirty` overrides it and says so in the output.

Three things it deliberately does not cover, and it prints them every run: anything needing
Ollama or a network, your project's own test suite, and the CI steps that are inline shell
with no tool behind them (`tools/preflight.sh --coverage` lists those by name).

Writing the list out by hand is what this replaces — every adopter who reconstructed it from
memory omitted something different, and the copy that used to live in this file had gone
stale in exactly that way: its ruff command globbed `tools/*.py`, which missed the
extensionless `tools/localcoder` — the largest Python file in the repo at the time, and
since moved out entirely (W-15). `tools/lint_python.sh` owns the pin and the scoping.

---

## Working on a shared codebase

When multiple people or tools are working on the same repo:

- **Never commit directly to `main`** — always work in a branch
- **Branch names:** `feature/`, `fix/`, `chore/` prefixes required
- **Pull requests:** Use the PR template in `.github/PULL_REQUEST_TEMPLATE.md`
- **`ai/` file conflicts:** If SESSION.md or BACKLOG.md has a merge conflict,
  keep both entries — do not discard either side. These are append-only logs.
- **MEMORY.md conflicts:** Stop and resolve manually — this file contains
  architectural decisions and both sides must be reviewed before merging.
- **Ownership:** See `ai/TEAM.md` for who owns what and who to contact.
- **CLAUDE.md is committed** — a one-line `@AGENTS.md` import shared by everyone.
  Keep it a pointer; project rules belong in AGENTS.md and the `ai/` files.

---

## Starting a new project from this scaffold

1. Clone or copy this scaffold into your new repo
2. Run `./setup.sh` — it will ask what type of project this is
3. The script applies the right overlay, sets the initial version, and verifies the CLAUDE.md pointer
4. Fill in `ai/MEMORY.md` with your project overview
5. Fill in `ai/TEAM.md` with the team roster
6. Commit everything and push: `git add . && git commit -m "chore(scaffold): initialize v[version]"`

---

## Versioning

All releases use: `MAJOR.MINOR.PATCH.YYYYMMDD.HHMM`

Example: `1.0.0.20260325.0624`

Tag every release in GitHub using the full version string.
The timestamp is the actual build time in 24-hour format.

### Every PR carries a build stamp

`MAJOR.MINOR.PATCH` moves at a release. The `YYYYMMDD.HHMM` half moves on **every PR**,
in the `version` file and in the header of every source file the PR touches.

This is checked now, and it did not used to be. Measured 2026-08-04 on this repo:
`setup.sh` carried `0.3.1.20260709.1050` through four later commits across two releases,
`tools/session_archive.py` had no `Version:` line, and `sync-check.sh` had no header at
all. Same shape as the archive ceiling that reached 1,001 lines — the rule was stated,
everyone agreed with it, and nothing was watching.

```bash
tools/header_check.sh                          # every source file has a complete header
tools/header_check.sh --since origin/main      # everything you changed was re-stamped
tools/header_check.sh --selftest               # prove the checker fails what it should
```

`--since` reads the committed diff, the working tree **and** files git does not know about
yet. That last one was the gap: until 0.3.0 every file list came from `git ls-files`, so a
source file you had created and not yet `git add`ed was invisible — it reported clean, and
the same file failed CI on the commit that added it.

`Modified:` is not bookkeeping. It is how the next reader decides whether the measurement
quoted in a comment still describes the code underneath it.

---

## Scaffold maintainers only

**Skip this section if you adopted the scaffold for your own project — it is about
releasing the scaffold itself.** These steps deliberately do not live in `ai/PLANNING.md`:
adopters inherit that file, and a release checklist that mixes "your project" steps with
"the scaffold's own repo" steps gets followed wrongly in both directions.

At each scaffold release, in addition to the checklist in `ai/PLANNING.md`:

- [ ] **Update `.scaffold-version` to match `version`.** It is the marker every adopting
  project reads to learn it has gone stale (`tools/scaffold_version.sh`). It is a
  *separate file from* `version` on purpose — `version` holds the adopter's own project
  version, so a human who thought to look was reading the wrong number entirely. If
  `.scaffold-version` is not bumped, every adopter is told they are current forever.
- [ ] **Tag with the full stamp**, e.g. `0.5.0.20260731.1600` — `tools/scaffold_version.sh`
  compares component-wise against the release tag, so a bare `v0.5.0` makes anyone
  tracking `main` look "ahead" and suppresses the notice.
- [ ] Confirm `mirror-sync` ran: it force-pushes `main` and tags to the downstream mirror
  on every merge and every tag.
- [ ] `tools/adoption_check.sh` — exit **3** anywhere means checks were SKIPPED, which is
  not a pass.
- [ ] `tools/header_check.sh` and `tools/guard_pretooluse.py --selftest` clean.

---

## What NOT to commit

The `.gitignore` covers tool caches, build artifacts, and secrets.
The `ai/` folder IS committed — it is the source of truth.
`CLAUDE.md` is committed — a one-line `@AGENTS.md` import, identical for everyone on every OS.
Never put credentials, API keys, or PHI in any `ai/` file.

---

## Creating a new overlay

If your project type isn't covered by the existing overlays (splunk-app, ai-skill, security-tool, python-script, it-automation, api-integration), create a new one.

### Step-by-step

1. **Create the overlay directory:**
   ```bash
   mkdir -p overlays/<your-type>
   ```

2. **Create four files** — use an existing overlay as a starting point:
   ```bash
   cp overlays/api-integration/STANDARDS.md overlays/<your-type>/STANDARDS.md
   cp overlays/api-integration/CODING.md overlays/<your-type>/CODING.md
   cp overlays/api-integration/RESEARCH.md overlays/<your-type>/RESEARCH.md
   cp overlays/api-integration/REFERENCE.md overlays/<your-type>/REFERENCE.md
   ```

   > **This step said "three files" and omitted `REFERENCE.md` (#247).** All six shipped
   > overlays carry four. `REFERENCE.md` is not optional decoration: `apply_overlay()` in
   > `setup.sh` copies it to `ai/REFERENCE.md`, and `ai/STANDARDS.md` tells agents to load
   > it on demand — so an overlay built by following the old step produced a project whose
   > `ai/STANDARDS.md` pointed at a file that was never created.

3. **Write STANDARDS.md** — project-type-specific rules that extend `ai/STANDARDS.md`:
   - Environment and runtime requirements
   - Directory structure and naming patterns
   - Required configuration files and their formats
   - Testing and validation requirements
   - Deployment and release checklists

4. **Write CODING.md** — implementation guidance that extends `ai/CODING.md`:
   - Language/framework-specific patterns and conventions
   - Error handling approach
   - Logging standard
   - File header format (if different from base)

5. **Write RESEARCH.md** — why the standards are what they are:
   - Sources consulted (URLs, docs, internal practice)
   - Key decisions made (with reasoning and alternatives considered)
   - Revisit triggers (what would cause standards to change)

5b. **Write REFERENCE.md** — the detail that must not sit in the always-loaded files:
   - Worked examples, templates, command reference, tables
   - Anything an agent needs *sometimes* — `ai/STANDARDS.md` loads this on demand,
     which is the whole reason the body files stay short

6. **Update `setup.sh`** — add your overlay as a new option in the project type menu and add a case block that applies it.

7. **Update documentation** — every place that enumerates the overlays. **This list was
   wrong in both directions (#247): it named `PROJECT-NOTES.md`, which has not existed
   since before 0.81.0, and it missed three files that do need editing.** Adding an overlay
   without touching these leaves `--type <yours>` undocumented or, worse, rejected:
   - `README.md` — **two tables**: the overlays table *and* the file reference table
   - `OVERVIEW.md` (overlay listing)
   - `ai/STANDARDS.md` — the overlay list in the load-order section
   - `docs/ADOPTION_GUIDE.md` — the `--type` comment listing the valid values
   - This file — the overlay list in the intro to this section, and the supported AI tools
     section if the overlay changes tool behaviour

8. **Test** — run `setup.sh`, select your new overlay, and verify:
   - Overlay content is appended to `ai/STANDARDS.md` and `ai/CODING.md`
   - No duplicate content if setup.sh is run twice
   - The resulting `ai/` files are valid and readable

### Overlay design principles

- **Extend, don't repeat** — the base `ai/` files already cover universal rules. Only add what's specific to your project type.
- **RESEARCH.md is not optional** — every decision should have a documented "why" and a revisit trigger. This prevents standards drift.
- **Keep STANDARDS.md scannable** — use tables, code blocks, and headers. Developers skim, not read.

---

## Troubleshooting

See `docs/TROUBLESHOOTING.md` for common issues and fixes.

---

## Questions or problems?

Update `ai/SESSION.md` with the issue so it is not lost between sessions.
For architectural questions, check `ai/MEMORY.md` first — it may already be answered.
