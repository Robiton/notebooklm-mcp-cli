<!-- scaffold:ai-file-kind template -->
# Coding Standards

<!-- localcoder:begin -->
## Drafting brief (what a local model is given)

`localcoder` injects ONLY this block, not the whole file. Keep it short, imperative,
and about the code being written — **it is a prompt, not documentation.** Everything outside
this block is for humans and cloud agents.

- <language + version, e.g. "Typed GDScript, Godot 4.7. No C#." or "Python 3.13, never assume 3.11">
- <indentation and line length — be explicit, models get this wrong>
- <whether file-header comment blocks are wanted; say NO explicitly if they are not>
- <doc-comment convention, and that comments should say WHY>
- <the two or three type-system traps this language actually has>
- Never invent an API. If unsure a method exists, say so in a comment rather than guessing —
  a plausible wrong method name is the most expensive thing you can produce.
- Guard inside the function that does the work, not only in its caller.
<!-- localcoder:end -->

<!-- Per-language blocks (localcoder:begin:python), the ~1,500-token budget, and what to
keep OUT of the block: tools/README.md -> The drafting brief. No block at all also works. -->

## Absent is not the same as empty, and neither is a value

Four defects in one week came from this one shape: an absent value read as a real one.

- **A missing key is not a default, and it is worse than inventing a method.** A wrong method
  name raises the first time it runs. `.get("k", 0)` on a key that is not there returns 0,
  every guard you asked for makes it quieter, and the program prints a confident number and
  exits 0. Verify the key against a real payload, or say in a comment that you did not.
- **A variable set to empty is not unset.** `os.environ.get(k, default)` returns the default
  only when the key is ABSENT; `export TOKEN=` is present and empty. An empty credential
  connects, lists everything, and fails every call.
- **Fall back only where a correct default exists.** A host with a documented default may
  default — and should say it did. A credential has no default, so empty must refuse.
- **An empty result and a result you could not obtain are different answers.** If one probe
  returns the same value for both, ask a second, cheaper question that separates them, and
  report the third outcome until it answers.

## General

- Write code for the next person to read, not just the next run
- One function, one responsibility
- No commented-out dead code in commits
- Prefer clarity over cleverness
- Files over 300 lines should be split into smaller modules

## Naming conventions

| Context | Style | Example |
|---------|-------|---------|
| Files | snake_case | enterprise_client.py |
| Python variables and functions | snake_case | get_user_token() |
| Constants | UPPER_SNAKE_CASE | MAX_RETRY_COUNT |
| Classes | PascalCase | EnterpriseClient |
| TypedDicts | PascalCase | AddSourceResult |
| Bash functions | lowercase_with_underscores | check_dependencies() |
| Bash local variables | lowercase_with_underscores | file_path |
| Bash constants / env vars | ALL_CAPS_SNAKE_CASE | MAX_RETRY_COUNT |

## File headers

> **Deliberately outside the drafting brief.** This rule is conditional — it has two
> exemptions below — and a model cannot weigh one paragraph against another. When this
> section was injected, drafts arrived with headers on exempt files and the review gate
> blamed the model for "fabricating" them. If your project *does* want a local model to
> write headers, say so explicitly inside the block at the top of this file.

Every source file — code, config, or markup — must begin with a header block
identifying what it is and tracking its change history. The exact format varies
by file type but must always include: project/app name, filename, last modified
date, current version, purpose, and a changelog.

**Generic format:**
```
# Project:  <project_name>
# File:     <filename>
# Modified: YYYY-MM-DD
# Version:  MAJOR.MINOR.PATCH.YYYYMMDD.HHMM
# Purpose:  <one-line description>
# Changelog:
#   YYYY-MM-DD vX.X.X — <description>
#   YYYY-MM-DD vX.X.X — Initial creation
```

Project-type overlays define the exact header format for their file types
(e.g. `.conf` files in Splunk, YAML frontmatter in skills).

**Exemption:** living Markdown documents whose history belongs to git — the `ai/` standards
and context files, READMEs, and docs — carry no embedded header; `git log` is their
changelog. Headers are for *deliverables* (code, configs, scripts, skills), where the file
travels away from the repo and needs its identity and history to travel with it.

A project may exempt **additional file classes** where headers don't fit the tooling —
engine-managed script files (e.g. Godot/Unity), generated code, formats without comment
syntax. Declare the exemption in the project's `ai/CODING.md` and record the rationale
in `ai/MEMORY.md`; the header rule is tool-scoped, not universal.

**`Modified:` must move when the file does.** A stale header is worse than a missing one:
it reads as deliberate, so the next person trusts a date that is wrong and concludes a
comment describing a measurement still describes the code. This rule went unchecked until
2026-08-04, and the scaffold itself was the clearest violator — `setup.sh` carried
`0.3.1.20260709.1050` through four later commits across two releases, `session_archive.py`
had no `Version:` line, `sync-check.sh` had no header at all. Nobody was careless; nothing
was watching, which is the same reason `SESSION.md` reached 1,001 lines against a stated
~150.

**PROSE FILES CARRY NO DATE LINE, AND THAT IS THE SAME RULE, NOT AN EXCEPTION TO IT.**
Markdown under `ai/`, `docs/` and `overlays/` used to open with `_Last updated: YYYY-MM-DD_`.
Measured 2026-08-09: **23 of 24 overlay files** claimed a date older than the file's last
real change, by as much as four months — and the convention was absent from the eight core
`ai/` files entirely, so it was neither universal nor true.

The reason it rotted is the reason `Modified:` did not: nothing watched it. But the fix here
is deletion rather than a checker, because unlike a source header — which carries `Version:`
and `Changelog:` that git does not know — a bare date on a prose file is a hand-maintained
copy of `git log -1`, which is exact, free, and cannot drift. **Two definitions that can
disagree, where one of them is already authoritative.** A claim you do not make cannot go
stale; substance that belongs in the file stays in the file, as content.

`tools/header_check.sh` watches it now, and CI runs it:

```bash
tools/header_check.sh                        # every source file has a complete header
tools/header_check.sh --since origin/main    # everything you changed was re-stamped
tools/header_check.sh --adopt                # adopting into existing code — see below
tools/header_check.sh --list-legacy          # what the baseline is still exempting
tools/header_check.sh --selftest             # prove the checker fails what it should

tools/preflight.sh                           # this, plus every other gate CI runs
```

`--since` covers the committed diff, the working tree **and** files git does not know about
yet. That last one was a real hole: every file list came from `git ls-files` until 0.3.0, so
a source file you had just created and not yet `git add`ed reported clean here and failed CI
on the commit that added it.

**Adopting this into an existing codebase: the rule applies forward.** Turning the check on
in a mature project fails every file written before the standard was — measured on a real
upgrade, 33 files at once, and the pull request could not merge. Run `--adopt` once. It
records the date in `ai/STANDARDS.md` (a file upgrades merge rather than overwrite) and
exempts files older than it, **until you edit one** — then it is in scope like anything
else. The exempt count prints on every run, so the amnesty stays visible rather than
becoming the new normal. Full rule: `ai/STANDARDS.md` → *File-header baseline*.

## Documentation

- Every function gets a docstring
- Document the why, not just the what
- README stays current with every major change
- Inline comments only when logic is non-obvious

## Version control

Commit message format: `type(scope): description`

```
feat(enterprise): add audio overview support
fix(sources): correct paywall check SSRF vulnerability
docs(auth): add enterprise authentication section
chore(deps): update uv.lock
refactor(client): remove dead enterprise batchexecute code paths
test(sources): update bulk add tests for per-URL processing
```

| Type | Use for |
|------|---------|
| `feat` | New feature or capability |
| `fix` | Bug fix |
| `docs` | Documentation only |
| `chore` | Build, deps, tooling — no logic change |
| `refactor` | Code restructure — no behavior change |
| `test` | Adding or updating tests |
| `style` | Formatting only — no logic change |

## Project-specific layering rules

```
cli/ and mcp/     →  thin wrappers only (UX, JSON responses)
services/         →  all business logic, validation, error handling
core/             →  low-level API calls only (no business logic)
utils/            →  config, auth, CDP, browser helpers
```

- `cli/` and `mcp/` must NOT import from `core/` directly — always go through `services/`
- `services/` raises `ServiceError`/`ValidationError` — never raw exceptions
- `core/` returns raw dicts from API calls — no business logic
- Enterprise and personal mode are selected at the `mcp/tools/_utils.get_client()` call site

## Testing

- `uv run pytest` — run full suite
- Tests must pass with `NOTEBOOKLM_MODE=personal` (set by `tests/conftest.py` autouse fixture)
- Do not use live API calls in tests — mock at the client layer
- Lint: `uv run --extra dev ruff check .` and `uv run --extra dev ruff format --check .` must be clean before pushing (pinned ruff; `uvx ruff` may differ from CI)

## Dependencies

- Pin dependency versions in `uv.lock`
- Run `uvx pip-audit` before each release
- `httpx` for HTTP in enterprise/podcast clients; `requests` is used by the personal client
- Never add a new dependency without checking license and maintenance status

- Prefer well-maintained packages with active communities

## Local coder (optional)

A local LLM drafts; the orchestrating agent reviews, tests and verifies. What to delegate,
the review gate, limits, setup, config: [`tools/README.md`](../tools/README.md) -> *Local
coder* — kept out of this always-loaded file. Policy: `localcoder --delegation`.

---

# API Integration Overlay — Coding Standards

_Extends base coding standards for API integration work in this project._

## Client structure

Each API surface has its own client class:

- `core/client.py` — personal batchexecute client (auth, request, retry)
- `core/enterprise_client.py` — enterprise Discovery Engine REST client
- `core/enterprise_adapter.py` — adapts enterprise client to personal client interface

Business logic lives in `services/`, not in the client classes.

## Retry and rate limit handling

```python
# Enterprise client uses httpx with explicit timeout
response = self._client.request("POST", url, headers=self._headers(), json=body, timeout=30)
```

- Retryable: 429, 500, 502, 503, 504
- Non-retryable: 400, 401, 403, 404 — fail immediately with clear error
- Enterprise 401: prompt `gcloud auth login`
- Enterprise 403: prompt IAM role assignment

## Error message hygiene

```python
# Strip auth headers from exception messages — never expose tokens
except httpx.HTTPStatusError as e:
    raise httpx.HTTPStatusError(
        f"API error: {e.response.status_code}",  # No headers, no body
        request=e.request,
        response=e.response,
    ) from None
```

## Mocking in tests

```python
# tests/conftest.py forces personal mode for all tests
@pytest.fixture(autouse=True)
def force_personal_mode(monkeypatch):
    monkeypatch.setenv("NOTEBOOKLM_MODE", "personal")
    reset_config()
    yield
    reset_config()
```

Never make live API calls in tests. Mock at the `NotebookLMClient` method level.

## What not to do

- Never use `shell=True` in subprocess calls (command injection risk)
- Never log full request or response bodies — they may contain cookies or tokens
- Never retry 4xx errors — they indicate a request problem, not a server problem
- Never store API responses to disk without confirming they contain no credentials
- Never hardcode base URLs — use `get_base_url()` from `utils/config.py`
- Never add `if is_enterprise:` branches inside service or core layers — use the adapter pattern
