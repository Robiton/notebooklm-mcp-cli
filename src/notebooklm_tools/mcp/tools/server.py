# Project:  notebooklm-mcp-cli
# File:     src/notebooklm_tools/mcp/tools/server.py
# Modified: 2026-10-12
# Version:  1.0.8.20261012.0901
# Purpose:  Server tools - Server info with auth status
# Changelog:
#   2026-10-12 v1.0.8 — header added: fork-modified file merged with upstream v0.6.0 (sync batch 1)
"""Server tools - Server info with auth status."""

import json
import subprocess
import time
import urllib.request
from typing import Any, cast

from notebooklm_tools import __version__

from ._utils import logged_tool


def _check_enterprise_auth() -> str:
    """Check if GCP OAuth is available."""
    try:
        result = subprocess.run(
            ["gcloud", "auth", "print-access-token"],
            capture_output=True,
            text=True,
            timeout=5,
        )
        if result.returncode == 0 and result.stdout.strip():
            return "authenticated (gcloud)"
    except (FileNotFoundError, subprocess.TimeoutExpired):
        pass
    return "not authenticated — run 'gcloud auth login'"


def _check_personal_auth() -> str:
    """Check if personal cookies exist."""
    try:
        from notebooklm_tools.core.auth import load_cached_tokens

        cached = load_cached_tokens()
        if cached and cached.cookies:
            return "authenticated (cookies)"
    except Exception:
        pass
    return "not authenticated — run 'nlm login'"


def _get_latest_pypi_version() -> str | None:
    """Fetch the latest version from PyPI."""
    try:
        url = "https://pypi.org/pypi/notebooklm-enterprise-mcp/json"
        req = urllib.request.Request(url, headers={"User-Agent": "notebooklm-enterprise-mcp"})
        with urllib.request.urlopen(req, timeout=2) as response:
            data = cast(dict[str, Any], json.loads(response.read().decode()))
            info = data.get("info")
            if isinstance(info, dict):
                version = info.get("version")
                if isinstance(version, str):
                    return version
    except Exception:
        return None
    return None


def _compare_versions(current: str, latest: str) -> bool:
    """Compare version strings to determine if an update is available.

    Returns:
        True if latest is greater than current.
    """
    try:
        current_parts = [int(x) for x in current.split(".")]
        latest_parts = [int(x) for x in latest.split(".")]
        return latest_parts > current_parts
    except (ValueError, AttributeError):
        return False


def _check_auth_status() -> str:
    """Map AuthCheckResult.reason to the stable status strings documented in server_info."""
    try:
        from notebooklm_tools.services.auth import check_auth

        res = check_auth(live=True)

        if res.valid:
            return "configured"
        if res.reason == "no_tokens":
            return "not_configured"
        reason = res.reason or ""
        if reason in ("expired", "stale_heuristic") or reason.startswith("load_error"):
            return "stale"
        # 401/403 are definitive credential rejections, not transient network issues.
        if reason in ("http_401", "http_403"):
            return "stale"
        if reason.startswith("network_error") or reason.startswith("http_"):
            return "unverified"
        # Unknown reason — be conservative.
        return "stale"
    except Exception:
        return "error"


@logged_tool()
def server_info() -> dict[str, Any]:
    """Get server version, mode, auth status, and check for updates.

    AI assistants: If update_available is True, inform the user that a new
    version is available and suggest updating with the provided command.

    auth_status is reported per mode. "enterprise" checks for a gcloud access
    token; "personal" checks that cached cookies exist on disk (no network call),
    so "authenticated" means credentials are present, not that they are still valid.
    `_check_auth_status()` is upstream's live check (`nlm login --check`),
    kept for a later decision on whether personal mode should report it.

    Returns:
        dict with version info, configuration, and auth status for both modes:
        - version: Current installed version
        - latest_version: Latest version on PyPI (or None if check failed)
        - update_available: True if a newer version exists
        - auth_status: {"enterprise": ..., "personal": ...} human-readable status per mode
        - update_command: Command to run to update
    """
    from notebooklm_tools.utils.config import get_config

    config = get_config()
    mode = config.enterprise.mode
    project_id = config.enterprise.project_id
    location = config.enterprise.location

    info = {
        "status": "success",
        "version": __version__,
        "mode": mode,
        "fork": "Robiton/notebooklm-mcp-cli (enterprise + personal)",
        "switch_mode": "Use configure_mode tool or: nlm config set enterprise.mode <personal|enterprise>",
        "auth_status": {
            "enterprise": _check_enterprise_auth(),
            "personal": _check_personal_auth(),
        },
        "latest_version": latest,
        "update_available": update_available,
        "update_command": "uv tool upgrade notebooklm-enterprise-mcp",
        "pip_update_command": "pip install --upgrade notebooklm-enterprise-mcp",
    }

    if mode == "enterprise":
        info["project_id"] = project_id
        info["location"] = location
        info["api"] = "Discovery Engine REST API (stable)"
        info["supported_operations"] = [
            "notebook_list",
            "notebook_create",
            "notebook_get",
            "notebook_delete",
            "source_add (URL, text, YouTube, Drive, file upload)",
            "source_delete",
            "audio_overview (generate, delete)",
            "podcast_create (standalone, no notebook needed)",
            "notebook_share",
        ]
        info["unsupported_in_enterprise"] = [
            "chat/query",
            "video",
            "reports",
            "flashcards",
            "quizzes",
            "infographics",
            "slides",
            "mind_maps",
            "notes",
            "research",
        ]
    else:
        info["api"] = "batchexecute (all features supported)"

    return info
