# Upstream sync plan: v0.5.24 → v0.15.4

**Date:** 2026-10-12 · **Status:** batch 1 merged (#40); batch 2 (v0.7.0) in review · **Tracking:** issue #26, `ai/BACKLOG.md`

## Where we are

The last sync (fork 1.0.7, April 2026) brought in upstream through **v0.5.24**. Since then, upstream
(`jacob-bd/notebooklm-mcp-cli`, now redirecting to `jacob-bd/gemini-notebook-mcp-cli`) has shipped
**74 releases, up to v0.15.4 (2026-10-06)**:

| | |
|---|---|
| Commits | 455 (390 non-merge, 65 merges) |
| By type | 153 fix · 59 chore · 55 feat · 48 docs · 18 release · 11 test · 8 refactor · 8 style · other |
| Diff | 321 files, +62,871 / −2,695 (153 of the files are tests) |
| `src/` files changed upstream | 122, of which **31 the fork has also modified** |

The drift was reported: `upstream-check.yml` opened issue #26 in April. Its weekly runs then stopped
after 2026-06-14, most likely because GitHub pauses scheduled workflows in an inactive repository.
The workflow is active again.

## What changed upstream that matters

- **Rebrand:** Google renamed NotebookLM to **Gemini Notebook**. The upstream repo is now
  `gemini-notebook-mcp-cli`, but the PyPI package (`notebooklm-mcp-cli`), the module
  (`notebooklm_tools`) and the `nlm` CLI are unchanged. Docs and README wording changed throughout.
- **New dependencies:** `keyring`, `cryptography`, `filelock`, `tomlkit`, `packaging`,
  `questionary`, `pexpect`, `pyte`, `httpx[socks]`. The `fastmcp` ceiling rises to `<5.0`.
- **Auth rework:** OS credential store (`core/credential_store.py`, keyring), auth migration,
  cookie rotation, auth replay and Firefox support. This moves personal-mode secrets out of
  `auth.json`, so it needs a security read against `ai/SECURITY.md`. Enterprise mode (ADC / gcloud
  token) is not on this path.
- **New features:** setup wizard, chats, labels, collections, usage tracking, aliases and profiles
  as MCP tools, interactive reports, MCP tool groups, CDP transport.
- **Heaviest upstream churn in files the fork also edits:** `utils/cdp.py`, `cli/main.py`,
  `core/base.py`, `services/downloads.py`, `utils/config.py`, `services/chat.py`,
  `mcp/server.py`, `services/sources.py`.
- **Untouched by upstream** (fork-only): `core/enterprise_adapter.py`, `core/enterprise_client.py`,
  `core/api_profile.py`, `mcp/tools/podcast.py`, `mcp/tools/setup.py`, `mcp/oauth.py`.

## Strategy: merge by release band, not cherry-pick

Earlier syncs cherry-picked commit by commit, so upstream is **not an ancestor** of the fork, and git
cannot tell what has already been taken. Cherry-picking 390 commits would mean resolving the same
regions over and over.

Instead:

1. **Record the baseline once:** `git merge -s ours v0.5.24`. This creates a merge commit with no
   content change, saying "upstream through v0.5.24 is accounted for". The commits skipped in
   earlier syncs (e.g. `b31ab7e`, the dual-RPC fallback) stay skipped, now explicitly.
2. **Merge upstream one release band at a time** (`git merge v0.6.0`, then `v0.7.0` and so on).
   Each is a real three-way merge with v0.5.24 as the base, so only genuine collisions conflict.
3. **Merge each sync PR with a merge commit, never squash.** Squashing throws away the ancestry,
   and the next sync would be back to cherry-picking. Branch protection allows merge commits.

After this, every future sync is a single `git merge upstream/main`.

### Batches

A trial run (each band merged, conflicts auto-resolved, then discarded) gives the conflicted files
per band. Later bands are underestimates, because the trial took upstream's side on earlier
conflicts.

| Batch | Band | Commits | Conflicted files (trial) | Notes |
|---|---|---|---|---|
| 1 | baseline + v0.5.25–v0.6.0 | 28 | 16 | version files, CHANGELOG, desktop-extension, core src |
| 2 | v0.6.1–v0.7.0 | 71 | 9 | workflows (keep our SHA pins), AGENTS.md, MCP tools |
| 3 | v0.7.1–v0.8.0 | 44 | 7 | `.gitignore`, CLAUDE.md (keep the scaffold pointer), studio, research |
| 4 | v0.8.1–v0.10.0 | 110 | 9 | conversation, data_types, notebooks |
| 5 | v0.10.1–v0.12.0 | 32 | 2 | dependabot.yml, SECURITY.md |
| 6 | v0.12.1–v0.15.4 | 105 | 1 | **credential store / auth rework**: security review |

### Resolution rules (every batch)

- **Version files** (`pyproject.toml` version, `__init__.py`, `SKILL.md`, `version`, `uv.lock`
  project entry): keep the fork's 1.0.x. A fork release happens after the sync, not during it.
- **Enterprise code paths:** keep the fork's behaviour, and take upstream changes around them.
- **Scaffold-owned files** (`AGENTS.md`, `CLAUDE.md`, `ai/`, `.github/workflows/*`, `tools/`):
  keep ours, and port upstream's workflow changes by hand where they matter (keep SHA pins).
- **CHANGELOG.md:** keep the fork's hand-maintained file and add the upstream entries under the
  upstream-history section.
- **New upstream dependencies:** add them to `pyproject.toml`, run `uv lock`, then
  `pip-audit` / osv-scanner.
- **Merge sync PRs with a merge commit** (`gh pr merge --merge`), never squash.
- **Gate per batch:** `uv run pytest -m "not e2e"`, pinned ruff, `tools/preflight.sh` (only the
  known CHANGELOG FAIL is allowed), `nlm --help`, and an HTTP MCP `initialize` smoke test. If a
  batch's resolution needs a judgement call on enterprise behaviour, the PR says so and waits.

## Findings from batch 1

- **Live bug on main, fixed by the sync:** `notebook_query_start` / `notebook_query_status` (MCP) call
  `services.chat.query_start` / `query_status`, which never reached the fork. Upstream's v0.5.15 async
  polling was only partly cherry-picked, so every call failed with
  `module 'notebooklm_tools.services.chat' has no attribute 'query_start'`. The fork's `chat.py` was a
  strict subset of upstream's, so batch 1 takes upstream's file whole. That also restores upstream's
  empty-notebook guard, which is a no-op in enterprise mode (the REST dict falls through its `except`).
- **Skips before v0.5.24 that the baseline records as "not taken":** WSL2 (`636fe51`, `0708d46`,
  `a4f6174`, `5626e64`), dual-RPC fallback `b31ab7e`, and PEP 735 dev group `f42c2a1`. WSL is now
  taken (batch 1), because later upstream code imports it.
- **The header rule cannot apply to upstream files.** `tools/header_check.sh --since` fails every
  upstream `.py` the merge touches (121 in batch 1, and 271 files over the full sync). Stamping a fork
  header on upstream code would be false provenance and churn. Filed Robiton/ai-project-scaffold#385
  for a declared path exemption. Until then, `scaffold-check` is **expected red on sync PRs** (it is
  not a required check). The bare form that runs on `main` passes, because the merged files' last
  commits predate the header baseline. A file that **already has a fork header** and takes a clean
  upstream change (e.g. `mcp/tools/auth.py`) is correctly flagged as stale; re-stamp it.
- **New upstream workflows arrive tag-pinned.** v0.6.0 added `release-gate.yml` with `@v4`/`@v7`
  actions, and zizmor failed it (7 high). Every batch: SHA-pin new or changed upstream workflows to
  the SHAs already used here, and set `enable-cache: false` on release triggers. Upstream workflows
  also use `uv run --dev`, which in the fork resolves to the pip-audit-only dependency group (PEP 735
  `f42c2a1` was never taken), so rewrite it to `--extra dev`. Check locally with
  `uvx zizmor@1.30.1 --min-severity high --offline .github/workflows/`.

## Findings from batch 2

- **External bind refusal.** Upstream v0.6.x refuses HTTP/SSE on a non-loopback host unless
  `NOTEBOOKLM_ALLOW_EXTERNAL_BIND=1`. The fork only warned. Adopted as-is, which also applies to
  OAuth-protected servers (they need the env var too). The Docker and multi-user docs now set it.
- **`server_info` auth status.** Upstream moved to a live check (`check_auth(live=True)`). The fork
  reports per-mode status (gcloud token, cookie presence). The fork's output is kept and upstream's
  function is merged but unused.
- **Package name in new upstream docs.** New upstream docs install `notebooklm-mcp-cli`. Every
  batch, grep new or changed docs for `install notebooklm-mcp-cli` and point it at
  `notebooklm-enterprise-mcp`.
- **Both sides added the same feature** (`.epub`) and the set ended up with a duplicate. Ruff B033
  caught it, so the per-batch ruff gate is doing its job.

## Open decisions (Brian)

1. **Credential store (batch 6):** adopt upstream's OS-keyring storage for personal mode, or keep
   `auth.json`? Recommendation: adopt, after a security read. A keyring is the stronger default.
2. **Rebrand wording:** follow upstream to "Gemini Notebook" in user-facing docs, or keep
   "NotebookLM"? The enterprise API is still Discovery Engine "NotebookLM Enterprise".
   Recommendation: follow upstream for personal mode and keep "NotebookLM Enterprise" for
   enterprise.
3. **Fork release after the sync:** probably 1.1.0, given the new features and dependencies.
4. **OAuth and the external-bind refusal (batch 2):** exempt OAuth-protected servers, or keep
   requiring `NOTEBOOKLM_ALLOW_EXTERNAL_BIND=1`? Keeping it is the conservative default.
5. **Live auth check in `server_info` (batch 2):** report upstream's live personal-mode check?
