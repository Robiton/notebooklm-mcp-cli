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

    IMPORTANT: Enterprise and personal use SEPARATE authentication.
    - Enterprise: requires `gcloud auth login` (GCP OAuth2)
    - Personal: requires `nlm login` (browser cookie auth)
    Switching modes without the correct auth will cause 400/401 errors.
    Always confirm the user has authenticated for the target mode before switching.

    Args:
        mode: "personal" or "enterprise"
        project_id: GCP project number (required for enterprise, found in NotebookLM URL)
        location: GCP location - "global", "us", or "eu" (default: "global")

    Returns:
        Dictionary with status, configuration, and auth requirements.
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

    # Pre-check: warn if switching to personal without cookies
    if mode == "personal":
        from notebooklm_tools.core.auth import load_cached_tokens
        cached = load_cached_tokens()
        if not cached or not cached.cookies:
            return {
                "status": "warning",
                "mode": mode,
                "message": "Mode set to personal, but no personal auth tokens found. "
                           "Run 'nlm login' in your terminal first to authenticate "
                           "with your personal Google account, then try again.",
                "auth_required": True,
            }

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
