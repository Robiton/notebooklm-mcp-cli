"""Server tools - Server info with auth status."""

import json
import subprocess
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
        url = "https://pypi.org/pypi/notebooklm-mcp-cli/json"
        req = urllib.request.Request(url, headers={"User-Agent": "notebooklm-mcp-cli"})
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


@logged_tool()
def server_info() -> dict[str, Any]:
    """Get server version, mode, and auth status.

    Returns:
        dict with version, configuration, and auth status for both modes.
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
