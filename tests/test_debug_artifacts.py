# Project:  notebooklm-mcp-cli
# File:     tests/test_debug_artifacts.py
# Modified: 2026-10-12
# Version:  1.0.8.20261012.1439
# Purpose:  test_debug_artifacts.py
# Changelog:
#   2026-10-12 v1.0.8 — header added: file touched by upstream v0.12.0 merge (sync batch 5)
import importlib.util
import subprocess
from pathlib import Path

_SCRIPT_PATH = Path(__file__).parents[1] / "scripts" / "inject_cookies_and_inspect.py"
_SPEC = importlib.util.spec_from_file_location("inject_cookies_and_inspect", _SCRIPT_PATH)
assert _SPEC and _SPEC.loader
_SCRIPT = importlib.util.module_from_spec(_SPEC)
_SPEC.loader.exec_module(_SCRIPT)
save_dom_capture = _SCRIPT.save_dom_capture


def test_save_dom_capture_defaults_outside_the_repository(tmp_path, monkeypatch):
    monkeypatch.chdir(tmp_path)

    output = save_dom_capture("<html>private</html>")

    assert output.is_file()
    assert output.parent != tmp_path
    assert output.name == "dom.html"
    assert output.read_text(encoding="utf-8") == "<html>private</html>"


def test_save_dom_capture_honors_explicit_output_path(tmp_path):
    output_path = tmp_path / "captures" / "dom.html"

    output = save_dom_capture("<html>private</html>", output_path)

    assert output == output_path
    assert output.read_text(encoding="utf-8") == "<html>private</html>"


def test_sensitive_debug_artifacts_are_ignored_by_git():
    repo_root = Path(__file__).parents[1]
    for artifact in (
        "dom_with_cookies.html",
        "dom_with_cookies-2026-08-23.html",
        "capture.har",
        ".chrome-debug-profile/Cookies",
    ):
        result = subprocess.run(
            ["git", "check-ignore", "--no-index", "--", artifact],
            cwd=repo_root,
            capture_output=True,
            text=True,
            check=False,
        )
        assert result.returncode == 0, f"{artifact} is not ignored"
