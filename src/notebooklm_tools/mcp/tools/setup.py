"""Setup tools — Configure NotebookLM mode (personal/enterprise)."""

from typing import Any

from ._utils import logged_tool, reset_client


@logged_tool()
def configure_mode(
    mode: str = "personal",
    project_id: str = "",
    location: str = "global",
) -> dict[str, Any]:
    """Configure NotebookLM mode (personal or enterprise).

    For enterprise mode, provide your GCP project ID (found in your
    NotebookLM URL: ...?project=YOUR_PROJECT_ID) and location.

    Changes are saved to config.toml and take effect immediately.

    Args:
        mode: "personal" or "enterprise"
        project_id: GCP project number (required for enterprise)
        location: GCP location - "global", "us", or "eu" (default: "global")

    Returns:
        Dictionary with status and current configuration.
    """
    if mode not in ("personal", "enterprise"):
        return {"status": "error", "error": "mode must be 'personal' or 'enterprise'"}

    if mode == "enterprise" and not project_id:
        return {
            "status": "error",
            "error": "project_id is required for enterprise mode. "
                     "Find it in your NotebookLM URL: ...?project=YOUR_PROJECT_ID",
        }

    from notebooklm_tools.utils.config import get_config, reset_config, save_config

    config = get_config()
    config.enterprise.mode = mode
    if project_id:
        config.enterprise.project_id = project_id
    config.enterprise.location = location
    save_config(config)

    # Reset cached config and client so next call uses new mode
    reset_config()
    reset_client()

    result = {
        "status": "success",
        "mode": mode,
        "message": f"Mode set to {mode}.",
    }

    if mode == "enterprise":
        result["project_id"] = project_id
        result["location"] = location
        result["auth_hint"] = "Run 'gcloud auth login' if not already authenticated."
    else:
        result["auth_hint"] = "Run 'nlm login' if not already authenticated."

    return result
