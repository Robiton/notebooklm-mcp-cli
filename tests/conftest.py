# Project:  notebooklm-mcp-cli
# File:     tests/conftest.py
# Modified: 2026-10-12
# Version:  1.0.8.20261012.1333
# Purpose:  Shared test fixtures — personal mode, isolated storage, no cookie rotation.
# Changelog:
#   2026-10-12 v1.0.8 — header added: fork-modified file merged with upstream v0.10.0 (sync batch 4)
"""Shared test fixtures — personal mode, isolated storage, no cookie rotation."""

import os

import pytest

from notebooklm_tools.core.cookie_rotation import DISABLE_ROTATE_COOKIES_ENV


@pytest.fixture(autouse=True)
def personal_mode_for_tests(monkeypatch):
    """Force personal mode during tests to avoid config.toml interference."""
    monkeypatch.setenv("NOTEBOOKLM_MODE", "personal")
    # Reset cached config so it picks up the env var
    from notebooklm_tools.utils.config import reset_config

    reset_config()
    yield
    reset_config()


@pytest.fixture(autouse=True)
def _isolate_storage(monkeypatch, tmp_path, request):
    """Point all storage (~/.notebooklm-mcp-cli) at a per-test temp dir.

    Several code paths (e.g. BaseClient._update_cached_tokens, headless auth)
    write to the real auth cache and Chrome profile. Without this guard, tests
    that exercise them corrupt the developer's real login (see
    test_refresh_auth_tokens_success, which used to overwrite auth.json with
    fake test tokens).

    Explicitly enabled E2E tests need the real authenticated profile.
    """
    if os.environ.get("NOTEBOOKLM_E2E") and request.node.get_closest_marker("e2e"):
        return

    monkeypatch.setenv("NOTEBOOKLM_MCP_CLI_PATH", str(tmp_path / "storage"))


@pytest.fixture(autouse=True)
def _disable_cookie_rotation(monkeypatch):
    """Keep tests from hitting accounts.google.com.

    BaseClient._call_rpc rotates Google cookies before real RPC calls; a test
    with a mocked HTTP client could otherwise "succeed" at rotation against
    the mock. Tests that exercise rotation itself re-enable it with
    monkeypatch.delenv.
    """
    monkeypatch.setenv(DISABLE_ROTATE_COOKIES_ENV, "1")
