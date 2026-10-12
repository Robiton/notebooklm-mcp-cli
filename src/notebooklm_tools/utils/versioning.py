# Project:  notebooklm-mcp-cli
# File:     src/notebooklm_tools/utils/versioning.py
# Modified: 2026-10-12
# Version:  1.0.8.20261012.1546
# Purpose:  Shared package-version comparison helpers.
# Changelog:
#   2026-10-12 v1.0.8 — header added: file touched by upstream v0.15.4 merge (sync batch 6)
"""Shared package-version comparison helpers."""

from packaging.version import InvalidVersion, Version


def is_newer_version(current: str, latest: str) -> bool:
    """Return whether latest is newer than current under PEP 440."""
    try:
        return Version(latest) > Version(current)
    except InvalidVersion:
        return False
