"""Server tools - Server info."""

from typing import Any

from notebooklm_tools import __version__

from ._utils import logged_tool


@logged_tool()
def server_info() -> dict[str, Any]:
    """Get server version and mode info.

    Returns:
        dict with version and configuration info.
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
    }

    if mode == "enterprise":
        info["project_id"] = project_id
        info["location"] = location
        info["api"] = "Discovery Engine REST API (stable)"
        info["auth"] = "GCP OAuth2 (gcloud auth login)"
        info["supported_operations"] = [
            "notebook_list", "notebook_create", "notebook_get", "notebook_delete",
            "source_add (URL, text, YouTube, Drive, file upload)",
            "source_delete",
            "audio_overview (generate, delete)",
            "podcast_create (standalone, no notebook needed)",
            "notebook_share",
        ]
        info["unsupported_operations"] = [
            "chat/query", "video", "reports", "flashcards", "quizzes",
            "infographics", "slides", "mind_maps", "notes", "research",
            "rename_notebook",
        ]
    else:
        info["api"] = "batchexecute (all features)"
        info["auth"] = "Browser cookies (nlm login)"

    return info
