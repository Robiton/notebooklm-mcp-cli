# Project:  notebooklm-mcp-cli
# File:     src/notebooklm_tools/__init__.py
# Modified: 2026-10-12
# Version:  1.0.8.20261012.0901
# Purpose:  NotebookLM Tools - Unified CLI and MCP server for Google NotebookLM
# Changelog:
#   2026-10-12 v1.0.8 — header added: fork-modified file merged with upstream v0.6.0 (sync batch 1)
"""NotebookLM Tools - Unified CLI and MCP server for Google NotebookLM."""

from __future__ import annotations

from typing import Any

__version__ = "1.0.8"

__all__ = ["NotebookLMClient", "__version__"]


def __getattr__(name: str) -> Any:
    """Lazy-load heavy client so early imports (e.g. stdio encoding) stay light."""
    if name == "NotebookLMClient":
        from notebooklm_tools.core.client import NotebookLMClient as _NotebookLMClient

        globals()["NotebookLMClient"] = _NotebookLMClient
        return _NotebookLMClient
    raise AttributeError(f"module {__name__!r} has no attribute {name!r}")
