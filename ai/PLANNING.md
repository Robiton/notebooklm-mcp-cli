<!-- scaffold:ai-file-kind template -->
# Planning Standards

## AI-assisted development workflow

Every task follows five phases in order. Each phase has a quality gate — do not advance until the gate is met. Phases 1–3 are low-cost (text planning only); phase 4 is high-cost (writing code). Investing in phases 1–3 prevents rework in phase 4.

| Phase | Name | Goal | Quality gate |
|-------|------|------|--------------|
| 1 | **Clarify** | Surface the *goal* behind the task — the decision or outcome it drives — not just the stated requirements; ask questions; confirm scope | The real goal (not just the task) is understood, and requirements are unambiguous and agreed upon |
| 2 | **Design** | Choose architecture, identify affected files, decide approach | Design captures what will change, why, and trade-offs considered |
| 3 | **Plan** | Break into granular tasks with file paths and verification steps | Each task is small enough to complete in one pass (2–5 minutes) |
| 4 | **Code** | Implement — test-first when possible | All tests pass; implementation matches plan |
| 5 | **Verify** | Review against requirements; run full test suite; get an independent critic on the output; update docs | Code reviewed (ideally by a second model/tool), tests green, BACKLOG.md tasks marked done |

**When to use the full workflow:**
- Medium-to-complex changes (multiple files, new components, architecture decisions)
- Changes that touch security-sensitive code
- Work that will be reviewed by others (PRs)

**When to shorten:**
- Single-file bug fixes or typo corrections — skip directly to Plan → Code → Verify
- Documentation-only changes — Clarify → Code → Verify is sufficient

**Parallel execution:** When the plan identifies independent tasks (no shared state or dependencies), execute them in parallel. Use sub-agents or separate branches. Recombine at the Verify phase.

**When to update ai/ files during this workflow:**
- `ai/BACKLOG.md` — update immediately when tasks change status (during any phase)
- `ai/MEMORY.md` — update immediately when a design or architecture decision is made (typically during Design phase)
- `ai/SESSION.md` — update once at the end of the session with a summary of all work done (not per-task)

## Verification — get independent signal

The Verify gate is the main lever on quality. An AI tool is a capable but blind drafter — it cannot reliably tell when it is wrong or missing context, so do not let the same model that wrote the work be the only thing that blesses it.

- **Define "good" before coding.** The spec's *Success criteria* (below) are the evaluation rubric — write them first so Verify has something concrete to check against, not a vibe.
- **Use an independent critic.** Have a second model or tool review the output — a different one than wrote it. A different knowledge base catches what the author missed. (The optional local-coder workflow in `ai/CODING.md` is exactly this pattern: the local model drafts, the cloud agent reviews and verifies.)
- **Pull external signal where possible.** Tests, a real deployment target, or historical examples as format references make verification concrete instead of assumed.

**How to verify — check at the layer of the claim.** "It ran" is not verification:

- **Verify at the layer of the claim.** If the claim is "the output is correct," look at the output. If the claim is "the page renders," look at the page. Exit code 0 only proves the layer below the claim.
- **Use evidence you didn't generate.** Re-open the file that was written. Run the code. Diff before against after. Count the things you claimed to count.
- **Sample the tails, not just the middle.** First item, last item, weirdest item — happy-path spot checks hide the failures that matter.
- **Treat suspiciously good news as suspect.** A test that passes too easily or an all-clean sweep means the verification itself is broken until you can explain why the result is real.

## Guardrails — request vs. rule

Sort enforced behaviors into three tiers, and enforce the hard ones at the *tool* level, not just in prose:

- **Always do** — safe to run on autopilot.
- **Ask first** — pause for human confirmation.
- **Never do** — hard lines.

A rule written only in an `ai/` file or `AGENTS.md` is a *request* — the model can drift past it. For truly critical guardrails (destructive commands, secret exposure, protected paths) enforce them with a pre-tool-use **hook** (e.g. in `.claude/settings.json`) or a CI check: a hook is an actual *rule*. The mandatory hard lines live in `ai/SECURITY.md`; this scaffold already enforces some via the `SessionStart` hook and `scaffold-check` CI.

The snapshot-before-mutating hard line in `ai/SECURITY.md` is written as a rule, not yet a
hook, on purpose: the scaffold's own precedent is **rule first, hook as backstop** (see
`ai/STANDARDS.md` → *The session record*, where the checkpoint rule is deliberately
tool-agnostic and the `PreCompact` hook is only a Claude-specific safety net). A shipped
`PreToolUse` example belongs with the agent-threat work, so protected paths, destructive
commands and main-branch edits arrive as one coherent hook rather than three partial ones.

## Anti-patterns — workflow failures to never repeat

Codified failure modes. Any of these observed mid-task means stop and correct course:

- **Context dumping** — pasting whole files or logs at a model instead of the relevant slice. More context is not better context; it buries the signal.
- **Retry without revision** — re-running the same failed prompt, command, or fix unchanged and hoping. Every retry must change something deliberate.
- **Patching the symptom** — two failed attempts at the same fix means the *diagnosis* is wrong. Find the assumption underneath both attempts and test it directly.
- **Momentum execution** — continuing a plan's step 4 after step 2's output already invalidated it. Re-decide after every result: confirm or change.
- **Declaring done from intention** — reporting complete based on what was *meant* to happen, not what was observed. See *Verification* above.
- **Manufactured findings** — inventing problems in a review to look thorough. "Already solid" is a legitimate result.

(The local-coder loop in `ai/CODING.md` has its own smells list — same idea, specialized.)

---

## Spec documents

Every significant feature or change gets a spec file.

Location: `docs/specs/YYYY-MM-DD-feature-name.md`

Required sections:
- **Problem statement** — what problem are we solving
- **Proposed solution** — how we plan to solve it
- **Out of scope** — what we are explicitly not doing
- **Dependencies** — what this requires or affects
- **Risks** — what could go wrong
- **Success criteria** — how we know it worked
- **Version target** — which version this ships in

## Task format in BACKLOG.md

```
- [ ] Task description | Priority: High/Med/Low | Owner: [name or tool] | Due: YYYY-MM-DD
```

## Decision log format for MEMORY.md

When an architectural or design decision is made, add an entry:

```
## YYYY-MM-DD — Decision title
- Decision: what was decided
- Why: the reasoning
- Alternatives considered: what else was evaluated
- Revisit trigger: what would cause us to reconsider this
```

## Adding a new MCP tool — checklist

1. Capture the network request via Chrome DevTools (personal) or API docs (enterprise)
2. Document the endpoint in `docs/API_REFERENCE.md`
3. Add the low-level method in `core/client.py` (personal) or `core/enterprise_client.py`
4. If enterprise, add the adapter method in `core/enterprise_adapter.py`
5. Add business logic in the appropriate `services/*.py` module
6. Add the MCP tool wrapper in `mcp/tools/*.py`
7. Register in `mcp/tools/__init__.py` and `mcp/server.py`
8. Write unit tests for the service function in `tests/services/`
9. Run `uv run --extra dev ruff check . && uv run --extra dev ruff format --check .` — fix any issues
10. Update `ai/SESSION.md` and `ai/BACKLOG.md`

## Upstream PR strategy

This project is a fork of `jacob-bd/notebooklm-mcp-cli`. Before opening a PR upstream:
- Ensure the feature works independently of enterprise-only infrastructure
- Run the full upstream CI workflow locally: lint, format, tests
- Keep the diff minimal — one feature per PR
- Note: enterprise features will not be accepted upstream until Discovery Engine
  API promotes from v1alpha to v1 (see `ai/MEMORY.md`)

## Release checklist

Pre-flight:
- [ ] `uv run pytest -m "not e2e"` — no unexpected failures
- [ ] `.venv/bin/ruff check . && .venv/bin/ruff format --check .` — clean (use pinned ruff, not `uvx ruff`)
- [ ] `uvx pip-audit` — no unresolved CRITICAL/HIGH CVEs

Version bump (all 4 locations must match):
- [ ] `pyproject.toml` → `version = "X.Y.Z"`
- [ ] `src/notebooklm_tools/__init__.py` → `__version__ = "X.Y.Z"`
- [ ] `src/notebooklm_tools/data/SKILL.md` → `version: "X.Y.Z"`
- [ ] `version` file at repo root → `X.Y.Z`

Documentation:
- [ ] `CHANGELOG.md` — new version entry under the fork header (Keep a Changelog format)
- [ ] `ai/SESSION.md` — end-of-session entry with release notes
- [ ] `ai/BACKLOG.md` — completed tasks marked done

Release:
- [ ] PyPI OIDC trusted publisher configured on pypi.org (one-time setup, then automatic)
  - Publisher: `Robiton/notebooklm-mcp-cli`, workflow: `publish.yml`, environment: `pypi`
- [ ] Create GitHub release with tag `vX.Y.Z` — triggers `publish.yml` automatically
- [ ] Verify PyPI page shows correct version: `pip install notebooklm-enterprise-mcp==X.Y.Z`

Housekeeping:
- [ ] `ai/` rules reviewed — prune obsolete, merge duplicates, sharpen vague ones (see "Keeping rules maintainable")
- [ ] Completed BACKLOG items older than the current release moved to `ai/BACKLOG_ARCHIVE.md`

**Do NOT restamp a version after a rebase.** A rebase preserves the commit's AUTHOR date, so
a commit written at 06:50 still reports 06:50 however long the rebase took. The stamp gate
(#238) compares the stamp against that date and calls anything ahead of it a hand-typed
stamp — correctly, because a stamp the author could not have known sorts the release corpus
wrong. The tempting mistake is cosmetic: after a rebase the changelog can show 0.44.0 stamped
**0645** sitting above 0.43.2 stamped **0959**, which looks backwards, and "fixing" it reds
the gate. It is not backwards. Semver order and wall-clock order diverge across a rebase,
permanently and correctly, and each stamp is right relative to its own commit. Leave it alone.

## Release trigger rules

| Version bump | When to use |
|---|---|
| **PATCH** (X.Y.Z+1) | Any user-visible bug fix, security fix. Security: release immediately. |
| **MINOR** (X.Y+1.0) | New MCP tool, new CLI command, new enterprise feature, new config option |
| **MAJOR** (X+1.0.0) | Breaking change to auth, config schema, or MCP tool API |
| **No release** | Doc-only changes, CI-only, `ai/` context updates |

PyPI version: `MAJOR.MINOR.PATCH` only. The timestamp in the `version` file is for internal tracking.

## Keeping rules maintainable

Rules are living documentation, not a static artifact — left untended they sprawl
and contradict. Review the `ai/` rule files **at each release** (it's a release-checklist
gate above). Each review:
- Removes rules that no longer apply
- Merges duplicate or near-duplicate rules
- Sharpens vague instructions based on what was discovered in practice

**Pruning never loses history.** Removing a rule takes it out of the *active* set, not
out of the record:
- Git is the safety net — `git log`/`git blame` on the `ai/` file recovers any removed rule and shows when and why it left.
- Any rule **removal** also gets a one-line `ai/MEMORY.md` decision-log note (date, why removed, commit ref) so the reasoning is human-readable without git archaeology.

## Scenario checklists

For multi-file task types that recur, maintain checklists here so the steps
are not rediscovered each session. Add entries as patterns emerge.

### Template: [Scenario name]
Files to touch (in order):
1. `path/to/file` — what to change
2. `path/to/file` — what to change

Verification: [how to confirm it worked]
