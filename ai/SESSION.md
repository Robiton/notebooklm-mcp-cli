# Session Log

_Updated at the end of every working session, by every tool and every person._
_Most recent session at the top._

---

## 2026-10-12 — Brian Worrell — Claude Code (session 10)

**Who worked on this:** Brian Worrell + Claude Code (claude-opus-5-5)

**What we worked on:**
- Upgraded the AI scaffold from its original April adoption to `Robiton/ai-project-scaffold` 0.111.23.20261010.1324
- The project had no `.scaffold-version` (adopted before scaffold releases existed). Identified the adopted scaffold commit as `9d56ce2` (2026-04-04) by diffing AGENTS.md / sync-check.sh / .cursorrules against early commits, tagged it locally as `0.1.1.20260404.0000`, and ran `tools/scaffold_upgrade.sh --from <local clone>` against it so the three-way merge had a real base
- Resolved 7 merge conflicts (AGENTS.md, ai/STANDARDS.md, ai/CODING.md ×2, ai/SECURITY.md ×2, ai/PLANNING.md) — API-integration overlay and all project-specific release/coding/security content preserved
- Reconciled 8 kept product files: took incoming `.cursorrules`, `.windsurfrules`, `copilot-instructions.md`, `.editorconfig`, `sync-check.sh`, `scaffold-check.yml`; kept our `.codex` (added version-format line) and our PR template
- `CLAUDE.md` is now a committed `@AGENTS.md` pointer (was a gitignored symlink); `.gitignore` narrowed so `.claude/` skills + hook templates and `.cursor/rules/` are committed, personal `.claude/settings*.json` stay ignored
- Filled AGENTS.md Project Commands and SECURITY.md project-specific risks; PHI section marked not applicable
- Declared header baseline 2026-10-12 (`tools/header_check.sh --adopt`)
- Fixes found by the new gates: broken `./CLAUDE.md` link in `docs/API_REFERENCE.md`; four status strings in `mcp/tools/auth.py` marked `scaffold:not-a-secret` (+ file header); `upstream-check.yml` `git remote add` made idempotent
- Standardised lint commands on pinned ruff (`uv run --extra dev ruff`) everywhere in `ai/`

**Decisions made:**
- Scaffold base for this project is `9d56ce2`; `.scaffold-version` now tracks releases, so future upgrades are plain `tools/scaffold_upgrade.sh`
- Did NOT run `tools/changelog.sh --write` — it would replace the hand-maintained fork + upstream CHANGELOG with a tag-derived one (see BACKLOG)

**Problems encountered:**
- `tools/changelog.sh --check` fails: the scaffold expects a tag-generated CHANGELOG; ours is hand-written Keep a Changelog with upstream history and upstream's lightweight `v0.x` tags. No opt-out exists in the scaffold
- New CI gate `header_check --since origin/main` requires a file header on every edited `.py` file — affects upstream cherry-picks going forward
- `uv run` in a fresh checkout rewrites 2 lines of `uv.lock` (same churn as the uncommitted `uv.lock` change on main)
- Local gaps (exit 3, not passes): zizmor, actionlint, osv-scanner not installed

**Follow-up (same session):**
- CI fixes on the PR: pinned scanners installed in scaffold-check.yml; all workflow actions pinned to commit SHAs; uv cache off in publish.yml (zizmor). Merged as #34.
- `uv.lock` churn root cause: the v1.0.8 bump never re-ran `uv lock` (lock said 1.0.7). Synced the version line only (kept `revision = 3`; newer local uv writes 5). `version-check.yml` now also compares `uv.lock`; release checklist has a `uv lock` step. Merged as #35.
- Dependabot: 56 open alerts (2 critical, 18 high), all transitive except pytest. Targeted `uv lock --upgrade-package` on the 14 flagged packages (lock now `revision = 5`). Notable: starlette 0.50→1.7, mcp 1.25→1.30, cryptography 46→50, authlib 1.6→1.8 (adds joserfc). 750 tests pass, `nlm --help` OK, HTTP MCP `initialize` OK, pip-audit clean. Merged as #36; Dependabot open alerts → 0 after the graph rescan.
- Investigated the two open scaffold decisions (CHANGELOG gate, header rule). Findings and recommendations are recorded on the BACKLOG items; both still need a decision from Brian. Filed Robiton/ai-project-scaffold#380 (CHANGELOG opt-out). #37, #38 merged.
- Standing instruction from Brian: scaffold defects found here get filed on Robiton/ai-project-scaffold. Filed #381 (guarded multi-line `git remote add` flagged), #382 (scaffold-check.yml installs no scanners; osv-scanner unpinned), #383 (pre-0.4.0 adoption has no merge base), #384 (vendored `tools/*.py` linted by adopter ruff). Tracked in BACKLOG.
- Upstream sync triage: fork is 455 commits / 74 releases behind (v0.5.24 → v0.15.4). Issue #26 had flagged it since April; scheduled runs paused after 2026-06-14 (inactive repo). Plan: `docs/plans/2026-10-12-upstream-sync-v0.15-plan.md` — `merge -s ours v0.5.24` baseline, then merge by release band (6 batches), merge-commit PRs only.
- Batch 1 (v0.6.0): 16 conflicts resolved; found and fixed a live bug (async query MCP tools always errored — service functions never synced); took WSL2 (previously skipped); 763 tests pass. Header check fails all upstream files → filed Robiton/ai-project-scaffold#385; header-rule recommendation reversed.

- Batch 1 PR #40: CI showed the red was not the header check alone. Upstream's new `release-gate.yml` was tag-pinned (zizmor 7 high), and its `uv run --dev` would have lacked ruff/pytest in the fork. Fixed both; also re-stamped `mcp/tools/auth.py`. Merged with a merge commit.
- Batch 2 (v0.7.0): 20 conflicts. External bind refusal adopted (stricter than the fork's warning; an OAuth exemption was not added, so that is left to Brian). Docker/multi-user docs gain `NOTEBOOKLM_ALLOW_EXTERNAL_BIND=1`. GETTING_STARTED install fixed to the fork package. Duplicate `.epub` removed. `run_log.txt` (accidental upstream CI log) dropped. 928 tests pass; bind refusal/override and HTTP `tools/list` (42) smoke-tested.

- Batch 2 merged as #41. CodeQL flagged upstream's live auth check (substring `accounts.google.com`); fixed with a hostname helper and regression test.
- Batch 3 (v0.8.0): 19 conflicts. uv.lock re-locked (adds socksio). The upstream `--auto-import` option was lost in the conflicted signature and re-added. The new `AuthHealthChecker` repeats the substring check and now uses the helper. Upstream tests adapted: freshness test thread race (upstream fixes it later), file-source error (fork resolves the path first), config stub lacks `.enterprise`. Found a pre-existing fork bug: `nlm setup` uvx config ran upstream's package; fixed along with 3 install docs. 1015 tests pass.

- Batch 3 merged as #42.
- Batch 4 (v0.10.0): 33 conflicts. Upstream added its own Enterprise support (batchexecute, chosen by `NOTEBOOKLM_BASE_URL`), overlapping the fork's `APIProfile`. Folded in: the profile still decides enterprise (`enterprise.mode`) and upstream's `_is_enterprise()` / prefix / query-endpoint helpers read it; upstream's personal `base_host` (notebook.google.com) kept. Enterprise listing params and upload path follow upstream's captured traffic (not live-verified by either side). Found and fixed a batch 1 regression: `server_info` raised `NameError` (update check dropped). Mistake caught: `git checkout --ours` on version files dropped upstream's clean hunks in SKILL.md and others; redone with `checkout -m`. 1475 tests pass.

**Next steps:**
- Batches 5–6 of the upstream sync (plan doc); pin any new upstream workflows each batch
- Decide header-rule policy for upstream-derived `src/` files and the CHANGELOG gate (BACKLOG)
- Optionally wire session hooks: `./setup.sh` writes `.claude/settings.json` hooks (currently a personal allowlist only)

---

## 2026-04-14 — Brian Worrell — Claude Code (session 9)

**Who worked on this:** Brian Worrell + Claude Code (claude-sonnet-4-6)

**What we worked on:**
- Backlog sweep: all outstanding enterprise API gap items from BACKLOG.md
- Enterprise studio constraints: updated FastMCP system prompt (`mcp/server.py`) and `data/SKILL.md` to explicitly document that `studio_status` polling and video generation do NOT work in enterprise mode (hard Discovery Engine REST API limits confirmed by live test in v1.0.7)
- EPUB source support: `.epub` / `application/epub+zip` added to `core/sources.py` supported_extensions and enterprise_client suffix_map
- Notebook `is_shareable`: added field to `Notebook` dataclass, extracted from enterprise API `notebookMetadata.isShareable`, surfaced through enterprise_adapter, services/notebooks, and MCP list_notebooks output
- YouTube metadata surfacing: `enterprise_client._parse_source_result` now extracts `youtubeMetadata.channelName` → `youtube_channel` and `videoId` → `youtube_video_id`
- README approved_domains quick-start: added `nlm config set sources.approved_domains` example under Enterprise Mode section
- Marked complete: custom_style_description (already video_style_prompt), Agentspace rename (no code refs found), OAuth 2.1 (already implemented in upstream sync)
- Added Docker container design as new research backlog item
- Version bumped 1.0.7 → 1.0.8 in all four locations; CHANGELOG.md v1.0.8 entry added
- PR #24 opened: feat/backlog-sweep-v1.0.8 → main

**Decisions made:**
- Enterprise `studio_status` and video are documented as intentionally unsupported via MCP (not bugs) — system prompt directs LLMs to use notebook_url from error response for manual UI access
- `is_shareable` defaults to `True` in `Notebook` dataclass (safe fallback for consumer API which doesn't surface this field)
- Docker research deferred — needs design doc before implementation

**Problems encountered:**
- `tests/services/test_notebooks.py` mock SimpleNamespace missing `is_shareable` attribute after adding it to `NotebookInfo` TypedDict — fixed by adding to test defaults

**Next steps:**
- Wait for CI green on PR #24, then squash-merge
- Docker container design research (background agent running)
- Release v1.0.8 to PyPI after merge

---

## 2026-04-11 — Brian Worrell — Claude Code (session 8)

**Who worked on this:** Brian Worrell + Claude Code (claude-sonnet-4-6)

**What we worked on:**
- Upstream sync v0.5.18–v0.5.24 onto `chore/upstream-sync-v0.5.18-v0.5.24` branch
- Applied 22 commits via cherry-pick in dependency order across six release versions
- Major commits: thread-safety (56d5c8c), security hardening (dddd518), CDP regression fix (6511197), v1/v2 RPC dispatch (b31ab7e-style via 56d5c8c), MCP runtime contracts (f23b211 — 26 files), ruff format (70edb43), chat timeout (5ff8cca), studio None leaks (1389efd), _call_rpc consistency (de07758), Windows desktop fixes (2d7cf12, 7c12af6), studio revise errors (d7db3bb)
- Skipped: WSL2-only (a4f6174, 5626e64), housekeeping/release (805e5e9, 3d3f1c9, c838c5a, 6f921dd, 8c11438, 9dedf29), already-applied (7c612ed, e8b68ac, 0d5cba8)
- Resolved 30+ merge conflicts preserving enterprise additions: `get_api_profile().web_url()`, enterprise error fallback in studio_status, `_check_enterprise_auth()`, `skip_paywall_check`, `_SENSITIVE_DIR_BLOCKLIST`, CDP 30s timeout + chmod 600
- Post-cherry-pick fixes: added `RPCError` import, `RPC_ADD_SOURCE_V2` constant, `return result` to v1 sub-methods, reconstructed `_add_url_sources_v2`, removed inner TimeoutException catches, guarded `_parse_source_result` against None, fixed E402/duplicate-logger in studio service
- Full security scan: pip-audit clean, bandit 0 HIGH (4 Medium pre-existing), ruff --select S clean, auth diff clean
- 750 tests pass (up from 736 pre-sync), 37 skipped, 0 failures
- Version bumped to 1.0.7 in all four locations

**Decisions made:**
- `_add_url_source_v1/_v2` sub-methods do NOT catch `httpx.TimeoutException` — they let it bubble to `add_url_source`'s outer handler which returns the `{"status": "timeout"}` dict
- `_parse_source_result` returns `None` if `source_data` is `None` or `source_id` is `None` (guard against malformed RPC responses)
- `RPC_ADD_SOURCE_V2 = "ozz5Z"` added as distinct constant from `RPC_SUBSCRIPTION = "ozz5Z"` to make the v2 dispatch self-documenting (same RPC ID, different semantic context)
- Kept `get_api_profile().web_url(notebook_id)` over `f"{get_base_url()}/notebook/{notebook_id}"` — former is enterprise-aware

**Problems encountered:**
- f23b211 conflict left `_add_url_source_v1` and `_add_url_sources_v1` without `return result` statements (HEAD had inline parsing; f23b211 refactored to static methods but git auto-merged wrong)
- `_add_url_sources_v2` body was incorrectly merged inside `_add_url_sources_v1` — had to reconstruct the v2 method manually
- `RPCError` used in sources.py but never imported; `RPC_ADD_SOURCE_V2` referenced but never defined
- Studio service had duplicate `logger = logging.getLogger(__name__)` and imports out of order (E402) from a bad auto-merge

**Next steps:**
- Push branch and open PR into main
- Wait for CI green, then squash-merge
- Consider promoting OAuth 2.1 backlog item (dizz fork already implemented) — enables hosted deployment scenario

---

## 2026-04-07 — Brian Worrell — Claude Code (session 6)

**Who worked on this:** Brian Worrell + Claude Code (claude-sonnet-4-6)

**What we worked on:**
- Planned and implemented three high-priority security fixes from fork research on `fix/security-hardening` branch
- Fix 1 (D-intelligence): Added `_safe_output_path()` to `services/downloads.py` — validates output path is within HOME, cwd, or system temp before any download write; added `chmod 0o700` to all credential dir creation in `utils/config.py`
- Fix 2 (hectorreyes-ship-it): Moved SSRF `_is_private_url()` check unconditionally before paywall check in `add_source()` so `skip_paywall_check=True` can no longer bypass it; added `_SENSITIVE_DIR_BLOCKLIST` and `_assert_file_safe()` to block file uploads from `~/.ssh`, `~/.aws`, `~/.gnupg`, `~/.config`, `~/.notebooklm-mcp-cli`
- Fix 3 (RhysEJF): Changed `get_page_cookies()` in `utils/cdp.py` from `Network.getAllCookies` to `Network.getCookies` with `_NOTEBOOKLM_COOKIE_URLS` filter — scopes cookie capture to notebooklm.google.com and accounts.google.com only
- Opened Robiton/notebooklm-mcp-cli#7 into enterprise-url-support; 664 tests passing, ruff clean

**Decisions made:**
- `_safe_output_path` also allows system temp dir — tests use `/tmp/...` which macOS resolves to `/private/tmp`; both `tempfile.gettempdir()` and `/tmp` are added as allowed roots
- `_assert_file_safe` passes the resolved path to `client.add_file()` (canonicalises symlinks); updated test assertion accordingly
- All three fixes in one PR (simpler than three PRs for closely related security changes)

**Problems encountered:**
- `tempfile.gettempdir()` on macOS returns `/var/folders/.../T` (resolves to `/private/var/...`) while test paths used `/tmp` (resolves to `/private/tmp`) — these are different; fixed by adding both

**Next steps:**
- Merge PR #7 into enterprise-url-support (wait for CI green)
- Docker research: design minimal secure single-user container
- brainupgrade-in: custom_style_description for video overview (low priority)
- Branch protection on main (manual GitHub Settings)
- Merge enterprise-url-support → main for first clean release

**Backlog changes:**
- Moved 3 security fix items from "up next" to completed
- Added PR #7 to "in progress"

---

## 2026-04-06 — Brian Worrell — Claude Code (session 5)

**Who worked on this:** Brian Worrell + Claude Code (claude-sonnet-4-6)

**What we worked on:**
- Resumed from context limit (session 4 ended mid-upstream cherry-pick)
- Completed cherry-picks from upstream v0.5.11–v0.5.16 onto `chore/upstream-sync-v0.5.16`:
  - `10f0cd7` auth.json chmod 0o600 (clean)
  - `67ff30c` auth recovery + --cdp-url fix (clean)
  - `86e2603` Python 3.13 Literal crash + CDP proxy bypass (clean)
  - `055629c` research polling loop — minor conflict resolved in services/research.py and tests/
  - `4ea50fc` configurable base URL merge — many conflicts; kept our enterprise URL routing via APIProfile throughout
- Fixed 6 ruff errors introduced by cherry-picks (unused imports, B904, I001, SIM105)
- All tests: 664 passed, 37 skipped — clean
- Opened and merged Robiton/notebooklm-mcp-cli#6 (upstream sync) into enterprise-url-support
- README updates: added "What this fork adds" table, updated Vibe Coding Alert to Robiton voice, added demo video attribution note, replaced legacy upgrade section with "Switching from Upstream" guide, removed star history chart
- Added 4 GitHub issue templates (bug-enterprise, bug-personal, feature-request, question)
- Added "Reporting Issues" section to README with routing table
- Enabled GitHub Issues on the repo (was disabled)
- Added PR template (.github/PULL_REQUEST_TEMPLATE.md)
- Added Dependabot config (.github/dependabot.yml) — weekly pip + GitHub Actions updates
- Fixed publish.yml: MCPB build/upload steps now skip on workflow_dispatch (only run on release events)
- Researched all ~430 active forks of jacob-bd/notebooklm-mcp-cli for useful contributions
- Deep-dived dizz (OAuth 2.1 remote MCP) and brainupgrade-in (custom video style) forks

**Decisions made:**
- Star history chart removed — new fork with near-zero stars looks worse than no chart; re-add when repo has traction
- Upstream cherry-pick `b31ab7e` (dual RPC fallback) permanently skipped — incompatible with our enterprise adapter design
- For 4ea50fc conflicts: kept our APIProfile-based URL routing throughout; upstream's `get_base_url()` approach is a simpler but less flexible design
- Docker strategy: single-user container (one Google account per container) is viable and useful as a distributable option for teams; multi-user requires significant new architecture
- High-priority fork contributions to implement: D-intelligence (path traversal), hectorreyes-ship-it (SSRF + sensitive dir blocklist), RhysEJF (CDP cookie allowlist)

**Problems encountered:**
- `gh pr create` defaulted to jacob-bd repo again — always use `--repo Robiton/notebooklm-mcp-cli --base <branch>` explicitly
- 4ea50fc was a merge commit requiring `-m 1` flag for cherry-pick

**Next steps:**
- Security fixes from forks: D-intelligence path traversal, hectorreyes SSRF + sensitive-dir blocklist, RhysEJF CDP cookie allowlist
- Research Docker single-user container: what does a minimal secure image look like, and how would distribution/deployment work for teams
- Add brainupgrade-in custom_style_description for video overview (low effort, good feature)
- Branch protection on main (manual GitHub Settings → Branches)
- Merge enterprise-url-support → main for first clean main release

**Backlog changes:**
- Completed: upstream sync v0.5.11–v0.5.16 (PR #6), README identity overhaul, issue templates, PR template, Dependabot, GitHub Issues enabled, publish.yml MCPB guard
- Added to up-next: 3 security fixes from fork research, Docker research task, brainupgrade-in video feature
- Removed from up-next: all items that are now done (PR #5, GitHub About, Discussions, PyPI OIDC were completed in earlier sessions)

---

## 2026-04-06 — Brian Worrell — Claude Code (session 4)

**Who worked on this:** Brian Worrell + Claude Code (claude-sonnet-4-6)

**What we worked on:**
- Resumed from context limit (session 3 ended mid-execution after merging PRs #2, #3, #4)
- Created `chore/p3-debt` branch from enterprise-url-support
- P3-A: Fixed `test_mcp_download_report` — was importing removed `download_report`; updated to use `download_artifact` (async), removed `@pytest.mark.skip`
- P3-B: Fixed 5 `TestFileUploadProtocol` failures — added `client._profile = APIProfile()` when constructing `SourceMixin.__new__`; `_profile` was added to `BaseClient.__init__` after tests were written
- P3-C: Added v1.0.0 fork header to CHANGELOG.md above upstream history
- P3 cleanup: Fixed pre-existing ruff errors across 13 files (F401, I001 import sort, SIM105 → contextlib.suppress) — all were blocking CI
- P4-A: Updated `ai/MEMORY.md` — upstream sync conflict hotspots table, updated PR status
- P4-B: Created `.github/workflows/upstream-check.yml` — weekly check for upstream drift; opens/updates GitHub issue if behind
- P5: Populated `.codex` with architecture layers, test commands, version locations, upstream sync guidance, and hard rules
- P6: Expanded `ai/PLANNING.md` with full release checklist (version locations, PyPI OIDC) and release trigger rules
- Opened Robiton/notebooklm-mcp-cli#5 (chore/p3-debt → enterprise-url-support)

**Decisions made:**
- SIM105 (try/except/pass) → `contextlib.suppress(Exception)` is safe for both enterprise_adapter.py and enterprise_client.py cases
- ruff format auto-reformatted 13 pre-existing files — these are all cosmetic and CI-safe
- BACKLOG "~19 pre-existing failures" item removed — the downloads.py failures were already fixed upstream; the file_upload.py failures were fixed in P3-B

**Problems encountered:**
- ruff check found 9 pre-existing errors on the branch; fixed 8 with `--fix`, 2 SIM105 needed manual `contextlib.suppress`
- `test_file_upload.py TestFileUploadE2E::test_upload_text_file` still errors with 400 when live credentials are expired — this is expected behavior for e2e tests and was pre-existing

**Next steps:**
- Merge PR #5 into enterprise-url-support
- GitHub About section (manual UI): description + topics
- Enable GitHub Discussions (manual UI toggle)
- PyPI OIDC trusted publisher setup (manual on pypi.org — one-time before first release)
- Monitor upstream podcast PR #129 for review from jacob-bd

**Backlog changes:**
- Completed: All of Phases 3-6 (PRs #3 and #4 were merged in session 3, PR #5 opened this session)
- Removed: "Pre-existing test failures ~19" — resolved
- Added to up-next: merge PR #5, GitHub About, Discussions, PyPI OIDC

---

## 2026-04-06 — Brian Worrell — Claude Code (session 2)

**Who worked on this:** Brian Worrell + Claude Code (claude-sonnet-4-6)

**What we worked on:**
- Resumed from context limit with all scaffold files already staged
- Committed scaffold adoption (21 files, 960 insertions) as commit `6c494d0` on `chore/add-scaffold`
- Pushed `chore/add-scaffold` to `Robiton/notebooklm-mcp-cli`
- Opened Robiton/notebooklm-mcp-cli#2 (scaffold PR targeting enterprise-url-support)
- Accidentally opened jacob-bd/notebooklm-mcp-cli#130 (immediately closed with note)
- Updated all ai/ context files per scaffold end-of-session requirements

**Decisions made:**
- Scaffold PR targets `enterprise-url-support` (fork's active base), not `main`
- `main` on Robiton fork tracks upstream; enterprise-url-support is where real work happens

**Problems encountered:**
- `gh pr create` defaults to upstream parent repo (jacob-bd) when run inside a fork
  — solution: always use `--repo Robiton/notebooklm-mcp-cli --head <branch>` flags

**Next steps:**
- Merge scaffold PR (Robiton/notebooklm-mcp-cli#2)
- Discuss project next steps with Brian
- Wait for upstream podcast PR #129 review from jacob-bd

**Backlog changes:**
- Completed: scaffold commit + push + PR (Robiton/notebooklm-mcp-cli#2)

---

## 2026-04-06 — Brian Worrell — Claude Code (session 1)

**Who worked on this:** Brian Worrell + Claude Code (claude-sonnet-4-6)

**What we worked on:**
- Fixed CI lint failure on upstream podcast PR #129 (ruff format + import sort)
- Added AI project scaffold (`Robiton/ai-project-scaffold`) to this repo
  - Created `ai/` folder with all 8 context files
  - Applied api-integration overlay to STANDARDS.md and CODING.md
  - Migrated CLAUDE.md institutional knowledge → ai/MEMORY.md
  - Replaced CLAUDE.md with AGENTS.md + gitignored symlink
  - Added hook files (.cursorrules, .windsurfrules, .codex, copilot-instructions.md)
  - Added GitHub scaffold files (PR template, CODEOWNERS, scaffold-check CI)
  - Added sync-check.sh, .editorconfig, version file

**Decisions made:**
- Scaffold overlay: api-integration (project calls two Google API surfaces)
- CLAUDE.md content moved to ai/MEMORY.md; CLAUDE.md becomes gitignored symlink to AGENTS.md
- ai/ files committed to repo so context is portable across machines and tools

**Problems encountered:**
- Upstream PR #129 failed lint CI: ruff format and import sort issues in podcast.py,
  __init__.py, server.py — fixed and pushed

**Next steps:**
- Commit scaffold and open PR (carried into session 2)

**Backlog changes:**
- Added: scaffold adoption task (completed same session)
- Completed: scaffold adoption, lint fix for podcast PR

---

## 2026-04-03 — Brian Worrell — Claude Code

**Who worked on this:** Brian Worrell + Claude Code

**What we worked on:**
- Completed remaining pre-PR items: paywall detection, per-URL bulk results, enterprise auth docs
- Fixed SSRF vulnerability in paywall URL checker (private IP blocking)
- Ran full security audit — no CRITICAL/HIGH findings; SSRF was the only actionable issue
- Wrote detailed project write-up
- Merged enterprise PR to Robiton fork (PR #1 → main)
- Opened upstream PR jacob-bd/notebooklm-mcp-cli#126 (enterprise support — full)
- Received response from jacob-bd: declined due to v1alpha instability + feature parity gap
- Opened focused upstream PR jacob-bd/notebooklm-mcp-cli#129 (standalone podcast only)
- Rebranded fork README as enterprise-first with "Why This Fork?" section

**Decisions made:**
- Don't fight the upstream decision — maintain as enterprise fork
- Podcast-only PR is the right small contribution to upstream
- Watch v1alpha promotion as the trigger for re-submission

**Problems encountered:**
- Podcast PR #129 failed upstream CI on lint (fixed 2026-04-06)

---

## 2026-03 (multiple sessions) — Brian Worrell — Claude Code

**Who worked on this:** Brian Worrell + Claude Code

**What we worked on:**
- Forked jacob-bd/notebooklm-mcp-cli
- Built enterprise NotebookLM support via Discovery Engine REST API
  - EnterpriseClient, EnterpriseAdapter, APIProfile
  - Persistent config (EnterpriseConfig in config.toml)
  - configure_mode MCP tool with auth pre-checks
  - Standalone Podcast API
  - Audio overview fix (empty body — API rejects documented fields)
  - server_info auth status display
- Security hardening: token leakage prevention, ID validation, path traversal fix
- Removed duplicate MCP server / 0.5.10 nag
- Bumped version to 1.0.0
- Tested against enterprise GCP project YOUR_PROJECT_ID
- Added paywall detection with SSRF protection
- Updated docs (README enterprise section, AUTHENTICATION.md enterprise section)
