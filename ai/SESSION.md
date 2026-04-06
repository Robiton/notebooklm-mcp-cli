# Session Log

_Updated at the end of every working session, by every tool and every person._
_Most recent session at the top._

---

## 2026-04-06 — Brian Worrell — Claude Code

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
- Wait for upstream podcast PR #129 review from jacob-bd
- Watch for Discovery Engine v1alpha → v1 promotion (re-submit enterprise PR when stable)
- Run `./sync-check.sh` before starting next session

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
- Tested against enterprise GCP project 204404889700
- Added paywall detection with SSRF protection
- Updated docs (README enterprise section, AUTHENTICATION.md enterprise section)
