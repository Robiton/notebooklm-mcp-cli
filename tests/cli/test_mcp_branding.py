# Project:  notebooklm-mcp-cli
# File:     tests/cli/test_mcp_branding.py
# Modified: 2026-10-12
# Version:  1.0.8.20261012.1333
# Purpose:  Tests for the Gemini Notebook MCP branding contract.
# Changelog:
#   2026-10-12 v1.0.8 — header added: fork-modified file merged with upstream v0.10.0 (sync batch 4)
"""Tests for the Gemini Notebook MCP branding contract."""

from pathlib import Path

import pytest

from notebooklm_tools.cli.commands.setup import (
    MCP_SERVER_NAME,
    _add_mcp_server,
    _add_vscode_mcp_server,
    _default_server_command,
)
from notebooklm_tools.mcp.server import mcp


def test_json_mcp_setup_uses_gemini_notebook_server_name():
    config = {}

    _add_mcp_server(config)

    assert MCP_SERVER_NAME == "gemini-notebook-mcp"
    assert config["mcpServers"][MCP_SERVER_NAME]["command"] == _default_server_command()


def test_vscode_mcp_setup_uses_gemini_notebook_server_name():
    config = {}

    _add_vscode_mcp_server(config)

    assert list(config["servers"]) == [MCP_SERVER_NAME]


def test_bundled_skill_uses_gemini_notebook_mcp_namespace():
    skill_path = Path("src/notebooklm_tools/data/SKILL.md")
    content = skill_path.read_text(encoding="utf-8")

    assert "mcp__gemini-notebook-mcp__" in content
    assert "mcp__notebooklm-mcp__" not in content


@pytest.mark.skip(
    reason="Fork keeps its FastMCP server name pending the rebrand decision "
    "(docs/plans/2026-10-12-upstream-sync-v0.15-plan.md, open decision 2)"
)
def test_mcp_server_uses_gemini_notebook_branding():
    assert mcp.name == MCP_SERVER_NAME
