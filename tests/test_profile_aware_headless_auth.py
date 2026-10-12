# Project:  notebooklm-mcp-cli
# File:     tests/test_profile_aware_headless_auth.py
# Modified: 2026-10-12
# Version:  1.0.8.20261012.1333
# Purpose:  Regression tests for profile-aware headless auth refresh.
# Changelog:
#   2026-10-12 v1.0.8 — fork-modified file merged with upstream v0.10.0 (sync batch 4)
#   2026-10-12 v1.0.8 — fork-modified file merged with upstream v0.8.0 (sync batch 3)
"""Regression tests for profile-aware headless auth refresh."""

from types import SimpleNamespace


def test_mcp_refresh_auth_uses_configured_default_profile(monkeypatch):
    """refresh_auth() must run headless auth against the configured default profile."""
    import notebooklm_tools.mcp.tools.auth as auth_tools
    from notebooklm_tools.core.auth import AuthTokens

    calls: list[str] = []

    monkeypatch.delenv("NOTEBOOKLM_COOKIES", raising=False)
    monkeypatch.setattr(
        "notebooklm_tools.services.auth.load_cached_tokens",
        lambda: None,
        raising=True,
    )
    monkeypatch.setattr(
        "notebooklm_tools.utils.config.get_config",
        lambda: SimpleNamespace(
            auth=SimpleNamespace(default_profile="pte"),
            enterprise=SimpleNamespace(mode="personal"),  # fork: get_api_profile reads it
        ),
        raising=True,
    )

    def fake_headless_auth(
        *,
        profile_name,
        timeout=30,
        expected_revision=None,
        force=False,
        **kwargs,
    ):
        calls.append(profile_name)
        return AuthTokens(cookies={"SID": "x"}, extracted_at=1.0)

    monkeypatch.setattr(
        "notebooklm_tools.utils.auth_browser.run_headless_auth",
        fake_headless_auth,
        raising=True,
    )
    monkeypatch.setattr(auth_tools, "reset_client", lambda: None, raising=True)
    monkeypatch.setattr(auth_tools, "get_client", lambda: object(), raising=True)

    result = auth_tools.refresh_auth()

    assert result["status"] == "success"
    assert calls == ["pte"]


def test_core_recovery_uses_configured_default_profile(monkeypatch):
    """NotebookLMClient auth recovery must also use the configured default profile."""
    from notebooklm_tools.core.auth import AuthTokens
    from notebooklm_tools.core.base import BaseClient

    calls: list[str] = []

    monkeypatch.setattr(
        "notebooklm_tools.core.auth.load_cached_tokens",
        lambda *, profile_name=None: None,
        raising=True,
    )
    monkeypatch.setattr(
        "notebooklm_tools.utils.config.get_config",
        lambda: SimpleNamespace(
            auth=SimpleNamespace(default_profile="pte"),
            enterprise=SimpleNamespace(mode="personal"),  # fork: get_api_profile reads it
        ),
        raising=True,
    )

    def fake_headless_auth(
        *,
        profile_name,
        timeout=30,
        expected_revision=None,
        force=False,
        **kwargs,
    ):
        calls.append(profile_name)
        return AuthTokens(
            cookies={"SID": "x"},
            csrf_token="csrf",
            session_id="sid",
            extracted_at=1.0,
        )

    monkeypatch.setattr(
        "notebooklm_tools.utils.auth_browser.run_headless_auth",
        fake_headless_auth,
        raising=True,
    )

    monkeypatch.setattr(BaseClient, "_refresh_auth_tokens", lambda self: None)

    client = BaseClient(cookies={"SID": "old"})
    assert client._try_reload_or_headless_auth() is True

    assert calls == ["pte"]
    assert client.cookies == {"SID": "x"}
    assert client.csrf_token == "csrf"
    assert client._session_id == "sid"
