# Project:  notebooklm-mcp-cli
# File:     tests/test_fork_credential_hardening.py
# Modified: 2026-10-12
# Version:  1.0.8.20261012.1545
# Purpose:  Fork hardening of upstream's credential store: isolated worker, no enterprise probe.
# Changelog:
#   2026-10-12 v1.0.8 — created: hardening found reviewing upstream v0.15.4 (sync batch 6)
"""Fork hardening of upstream's credential store: isolated worker, no enterprise probe."""

import subprocess
from unittest.mock import MagicMock

import pytest

from notebooklm_tools.core.auth import AuthManager
from notebooklm_tools.core.credential_backend_worker import CredentialWorkerClient
from notebooklm_tools.mcp.tools import _utils
from notebooklm_tools.mcp.tools._utils import (
    _mcp_probe_event,
    maybe_attach_mcp_notice,
    reset_mcp_probe_state,
    start_mcp_background_probe,
)
from notebooklm_tools.utils.config import reset_config


@pytest.fixture(autouse=True)
def setup_env(tmp_path, monkeypatch, fake_credential_store):
    monkeypatch.setenv("NOTEBOOKLM_MCP_CLI_PATH", str(tmp_path))
    reset_config()
    reset_mcp_probe_state()
    yield
    reset_mcp_probe_state()
    reset_config()


def test_worker_subprocess_runs_python_in_isolated_mode(monkeypatch):
    """`python -m` without -I puts the cwd on sys.path; a planted package would run there."""
    captured = {}

    def fake_popen(cmd, **kwargs):
        captured["cmd"] = cmd
        raise OSError("stop before spawning")

    monkeypatch.setattr(subprocess, "Popen", fake_popen)
    client = CredentialWorkerClient(use_subprocess=True, timeout_seconds=5)
    with pytest.raises(OSError):
        client._execute_in_helper({"op": "get", "service": "s", "account": "a"})

    cmd = captured["cmd"]
    assert cmd[1] == "-I"
    assert cmd[2:] == ["-m", "notebooklm_tools.core.credential_backend_worker"]


def test_probe_never_touches_keystore_in_enterprise_mode(monkeypatch, pretend_desktop):
    AuthManager("default").save_profile(cookies={"SID": "leftover"}, email="user@example.com")
    monkeypatch.setenv("NOTEBOOKLM_MODE", "enterprise")
    reset_config()

    factory = MagicMock()
    start_mcp_background_probe(backend_factory=factory, force=True)
    assert _mcp_probe_event.wait(timeout=5.0)

    factory.assert_not_called()
    assert _utils._mcp_probe_available is False


def test_notice_not_attached_in_enterprise_mode(monkeypatch):
    monkeypatch.setattr(_utils, "_mcp_probe_available", True)
    _mcp_probe_event.set()
    monkeypatch.setenv("NOTEBOOKLM_MODE", "enterprise")
    reset_config()

    result: dict = {"status": "success"}
    maybe_attach_mcp_notice(result)

    assert "user_notice" not in result
