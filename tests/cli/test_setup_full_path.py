# Project:  notebooklm-mcp-cli
# File:     tests/cli/test_setup_full_path.py
# Modified: 2026-10-12
# Version:  1.0.8.20261012.1546
# Purpose:  Tests for full-detected-binary-path defaults in MCP setup entries.
# Changelog:
#   2026-10-12 v1.0.8 — header added: file touched by upstream v0.15.4 merge (sync batch 6)
"""Tests for full-detected-binary-path defaults in MCP setup entries."""

from notebooklm_tools.cli.commands import setup


def test_default_server_command_prefers_full_path(monkeypatch):
    monkeypatch.setattr(setup.shutil, "which", lambda _: "/opt/bin/notebooklm-mcp")
    assert setup._default_server_command() == "/opt/bin/notebooklm-mcp"


def test_default_server_command_falls_back_to_bare(monkeypatch):
    monkeypatch.setattr(setup.shutil, "which", lambda _: None)
    assert setup._default_server_command() == "notebooklm-mcp"


def test_add_mcp_server_writes_full_path(monkeypatch):
    monkeypatch.setattr(setup.shutil, "which", lambda _: "/opt/bin/notebooklm-mcp")
    cfg = setup._add_mcp_server({})
    entry = cfg["mcpServers"][setup.MCP_SERVER_NAME]
    assert entry["command"] == "/opt/bin/notebooklm-mcp"
    assert entry["args"] == []


def test_add_vscode_mcp_server_writes_full_path(monkeypatch):
    monkeypatch.setattr(setup.shutil, "which", lambda _: "/opt/bin/notebooklm-mcp")
    cfg = setup._add_vscode_mcp_server({})
    assert cfg["servers"][setup.MCP_SERVER_NAME]["command"] == "/opt/bin/notebooklm-mcp"
