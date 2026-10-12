# Project:  notebooklm-mcp-cli
# File:     src/notebooklm_tools/core/__init__.py
# Modified: 2026-10-12
# Version:  1.0.8.20261012.1546
# Purpose:  Core functionality shared between CLI and MCP interfaces.
# Changelog:
#   2026-10-12 v1.0.8 — header added: file touched by upstream v0.15.4 merge (sync batch 6)
"""Core functionality shared between CLI and MCP interfaces."""

from notebooklm_tools.core import constants

__all__ = ["load_cached_tokens", "save_tokens_to_cache", "constants"]


def __getattr__(name: str):
    if name in ("load_cached_tokens", "save_tokens_to_cache"):
        from notebooklm_tools.core import auth

        return getattr(auth, name)
    raise AttributeError(f"module {__name__!r} has no attribute {name!r}")
