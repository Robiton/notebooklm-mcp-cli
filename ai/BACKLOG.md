# Project Backlog

_This file is the project to-do list. Updated by all tools and team members._
_Last updated: 2026-04-14 (session 9, v1.0.8) by Claude Code_

---

## In progress

_(nothing active)_

---

## Up next

### Research tasks

- [x] **Enterprise SDK comparison** — Completed 2026-04-07. See findings below. | Priority: High | Owner: Claude Code | Due: —

### Enterprise API gaps (from SDK comparison — 2026-04-07)

- [x] **Separate endpoint_location from resource location** — Completed 2026-04-07. Added `endpoint_location` field to `EnterpriseConfig` and `NOTEBOOKLM_ENDPOINT_LOCATION` env var. `EnterpriseClient` now uses it as the API hostname prefix (falls back to `location`). | Priority: High | Owner: Claude Code | Due: —
- [x] **YouTube source type in enterprise** — Completed 2026-04-07. `enterprise_adapter.add_url_source()` now detects `youtube.com/youtu.be` URLs and routes to `add_source_youtube()` which uses the correct `videoContent` body format. | Priority: Med | Owner: Claude Code | Due: —
- [x] **Retry with exponential backoff** — Completed 2026-04-07. `_request()` in `enterprise_client.py` retries up to 3x on 429/500/502/503/504 with 500ms–5s backoff, ±25% jitter, and Retry-After header support. | Priority: Med | Owner: Claude Code | Due: —
- [x] **`NBLM_ACCESS_TOKEN` env var support** — Completed 2026-04-07. `_get_token()` checks `NBLM_ACCESS_TOKEN` env var before falling back to gcloud CLI. | Priority: Med | Owner: Claude Code | Due: —
- [x] **Surface `isShareable`/`isShared` in notebook responses** — Added `is_shareable` to `Notebook` dataclass; enterprise adapter extracts `metadata.isShareable` and `metadata.isShared`; service layer includes `is_shareable` in `list_notebooks` output. Completed 2026-04-14. | Priority: Low | Owner: Claude Code | Due: —
- [x] **`youtubeMetadata` in source responses** — Enterprise `_parse_source_result` now extracts `metadata.youtubeMetadata.channelName` → `youtube_channel` and `metadata.youtubeMetadata.videoId` → `youtube_video_id` when present. Completed 2026-04-14. | Priority: Low | Owner: Claude Code | Due: —
- [x] **Docker research** — Completed 2026-04-14. Design doc written to `docs/DOCKER.md`. Recommendation: enterprise-only v1 on `python:3.12-slim`, ADC volume-mount auth, HTTP transport on port 8000/mcp, non-root + `--cap-drop ALL` + read-only rootfs, GitHub Container Registry for distribution. Personal mode excluded (CDP/Chrome incompatible with minimal container). | Priority: Med | Owner: Claude Code | Due: —

### New features (consumer API — from teng-lin/notebooklm-py v0.3.x research)

- [x] **Infographic style selection** — Already implemented (discovered during session 7 audit). 10 styles in `constants.py`, exposed via `studio_create` MCP tool and `nlm infographic create --style`. | Priority: Med | Owner: Claude Code | Due: —
- [x] **PPTX download for slide decks** — Already implemented (discovered during session 7 audit). `download_artifact` accepts `slide_deck_format=pptx`; CLI exposes `--format pptx`. | Priority: Med | Owner: Claude Code | Due: —

### New features from fork research

- [x] **brainupgrade-in**: `custom_style_description` for video overview — already implemented as `video_style_prompt` param in `studio_create`. No code change needed. | Priority: Low | Owner: Claude Code | Due: —
- [x] **EPUB source type** — Added `.epub` (application/epub+zip) to supported_extensions in `core/sources.py` and to the enterprise client suffix_map. Completed 2026-04-14. | Priority: Low | Owner: Claude Code | Due: —
- [x] **"Agentspace" → "Gemini Enterprise" rename** — No code references found; the term only appeared in this backlog entry. Marked complete 2026-04-14. | Priority: Low | Owner: Claude Code | Due: —

### Enterprise UX improvements (from 2026-04-07 live test)

- [x] **`studio_status` enterprise gap** — Completed 2026-04-07. `poll_studio_status` in enterprise adapter now raises `NotImplementedError` with a clear message; `services/studio.py` propagates it as a user-facing `ServiceError`. | Priority: Med | Owner: Claude Code | Due: —
- [x] **Bot-blocked domain list** — Completed 2026-04-07. Added `thehackernews.com`, `orca.security`, `securityonline.info` to `KNOWN_PAYWALL_DOMAINS` in `services/sources.py`. | Priority: Med | Owner: Claude Code | Due: —

### Maintenance

- [x] Branch protection on `main` — Completed 2026-04-07. Ruleset configured in GitHub Settings. | Priority: Med | Owner: Brian | Due: —
- [ ] Test configure_mode + full enterprise workflow end-to-end | Priority: Med | Owner: Brian | Due: —
- [x] **Upstream sync v0.5.17** — Completed 2026-04-07. Cherry-picked 5 commits (audio type 10, custom video style, visual_style_prompt parsing, CDP exception chaining, security hardening). Skipped b31ab7e (dual-RPC fallback, incompatible with enterprise adapter) and style/release/docs-only commits. Merged as Robiton#12. | Priority: High | Owner: Claude Code | Due: —
- [x] **Upstream sync v0.5.18–v0.5.24** — Completed 2026-04-11. Cherry-picked 22 commits covering thread-safety, security hardening, MCP runtime contracts, v1/v2 URL RPC dispatch, chat timeout, studio fixes, Windows desktop fixes, RPC error surfacing. Resolved 30+ conflicts preserving all enterprise additions. 750 tests pass, security scan clean. Versioned as 1.0.7. Branch: chore/upstream-sync-v0.5.18-v0.5.24 (PR pending). | Priority: High | Owner: Claude Code | Due: —

---

## Backlog

- [x] OAuth 2.1 provider for remote MCP — already implemented in `mcp/server.py` (`_setup_oauth()`) and `mcp/oauth.py` via upstream sync. Enabled via `--oauth-client-id/secret/server-url` flags or env vars. Completed in upstream sync v0.5.18-v0.5.24. | Priority: Low | Owner: Claude Code | Due: —
- [x] Consider adding `nlm config set sources.approved_domains` to README quick-start for paywall guidance — Added to README.md Enterprise Mode section. Completed 2026-04-14. | Priority: Low | Owner: Brian | Due: —
- [ ] Watch Discovery Engine API for v1alpha → v1 promotion (no longer triggers upstream PR — just informs our own stability posture) | Priority: Low | Owner: Brian | Due: —
- [ ] **Docker container implementation** — Build Dockerfile + docker-compose.yml + GitHub Actions publish workflow per design in `docs/DOCKER.md`. Scope: enterprise-only, `python:3.12-slim`, non-root, HTTP transport, ghcr.io distribution. | Priority: Med | Owner: Claude Code | Due: —

---

## Completed

- [x] Fork jacob-bd/notebooklm-mcp-cli | Completed: 2026-03
- [x] Enterprise REST API client (EnterpriseClient + EnterpriseAdapter) | Completed: 2026-03
- [x] Persistent config — [enterprise] section in config.toml | Completed: 2026-03
- [x] configure_mode MCP tool with auth pre-checks | Completed: 2026-03
- [x] Audio overview fix — empty body (API rejects documented fields) | Completed: 2026-03
- [x] Standalone Podcast API (enterprise, v1 stable) | Completed: 2026-03
- [x] server_info auth status for both modes | Completed: 2026-03
- [x] Security hardening — token leakage, ID validation, path traversal | Completed: 2026-03
- [x] Remove duplicate MCP server / 0.5.10 version nag | Completed: 2026-03
- [x] Bump version to 1.0.0 | Completed: 2026-03
- [x] Paywall detection for URL sources (domain list + HTTP HEAD check) | Completed: 2026-04-03
- [x] SSRF fix in paywall checker (private IP blocking) | Completed: 2026-04-03
- [x] Per-URL bulk source results (individual processing, partial success) | Completed: 2026-04-03
- [x] docs/AUTHENTICATION.md — enterprise auth section | Completed: 2026-04-03
- [x] Security audit — 0 CRITICAL/HIGH findings | Completed: 2026-04-03
- [x] Merge enterprise PR to Robiton/notebooklm-mcp-cli (PR #1) | Completed: 2026-04-03
- [x] Open upstream enterprise PR jacob-bd/notebooklm-mcp-cli#126 | Completed: 2026-04-03
- [x] Open upstream podcast PR jacob-bd/notebooklm-mcp-cli#129 | Completed: 2026-04-03
- [x] Rebrand fork README as enterprise-first | Completed: 2026-04-03
- [x] Fix podcast PR #129 CI — 3 root causes: unused import, upstream drift, ruff version mismatch | Completed: 2026-04-06
- [x] Add AI project scaffold (api-integration overlay) | Completed: 2026-04-06
- [x] Commit + push scaffold branch, open and merge Robiton/notebooklm-mcp-cli#2 | Completed: 2026-04-06
- [x] Phase 0+1: package rename, CI fix, pyproject.toml, README — Robiton#3 (merged) | Completed: 2026-04-06
- [x] Phase 2: CONTRIBUTING, CODE_OF_CONDUCT, SECURITY, issue templates — Robiton#4 (merged) | Completed: 2026-04-06
- [x] Phase 3-A: fix test_mcp_download_report (use download_artifact, remove stale skip) | Completed: 2026-04-06
- [x] Phase 3-B: fix 5 TestFileUploadProtocol failures (_profile missing in SourceMixin.__new__) | Completed: 2026-04-06
- [x] Phase 3-C: CHANGELOG fork header (v1.0.0 entry above upstream history) | Completed: 2026-04-06
- [x] Phase 3 cleanup: fix pre-existing ruff errors (F401, I001, SIM105) across 13 files | Completed: 2026-04-06
- [x] Phase 4-A: ai/MEMORY.md upstream sync conflict hotspots, PR status update | Completed: 2026-04-06
- [x] Phase 4-B: .github/workflows/upstream-check.yml (weekly upstream drift alert) | Completed: 2026-04-06
- [x] Phase 5: Populate .codex with architecture, test commands, version locations, hard rules | Completed: 2026-04-06
- [x] Phase 6: ai/PLANNING.md release checklist + trigger rules | Completed: 2026-04-06
- [x] D-intelligence: _safe_output_path() + chmod 0o700 on credential dirs | Completed: 2026-04-07
- [x] hectorreyes: unconditional SSRF block + sensitive-dir file blocklist | Completed: 2026-04-07
- [x] RhysEJF: CDP cookie scope to NotebookLM domain only | Completed: 2026-04-07
- [x] Merge enterprise-url-support → main (PR #8, squash merge) | Completed: 2026-04-07
- [x] Release v1.0.1 to PyPI (GitHub release tag, publish.yml triggered) | Completed: 2026-04-07
- [x] Swap local install from upstream notebooklm-mcp-cli to notebooklm-enterprise-mcp v1.0.1 | Completed: 2026-04-07
- [x] Close upstream contribution strategy — jacob-bd closed #126 (enterprise) and #129 (podcast); fork is now one-way sync only | Completed: 2026-04-07
