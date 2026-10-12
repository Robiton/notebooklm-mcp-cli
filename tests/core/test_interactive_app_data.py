# Project:  notebooklm-mcp-cli
# File:     tests/core/test_interactive_app_data.py
# Modified: 2026-10-12
# Version:  1.0.8.20261012.1439
# Purpose:  test_interactive_app_data.py
# Changelog:
#   2026-10-12 v1.0.8 — header added: file touched by upstream v0.12.0 merge (sync batch 5)
from unittest.mock import MagicMock

from notebooklm_tools.core.download import DownloadMixin


def test_reads_app_data_from_interactive_html():
    mixin = DownloadMixin(cookies={"SID": "x"}, csrf_token="t")
    mixin._get_artifact_content = MagicMock(
        return_value='<div data-app-data="{&quot;quiz&quot;: [{&quot;question&quot;: &quot;Q1&quot;}]}"></div>'
    )
    assert mixin.get_interactive_app_data("nb", "el") == {"quiz": [{"question": "Q1"}]}


def test_returns_none_without_content():
    mixin = DownloadMixin(cookies={"SID": "x"}, csrf_token="t")
    mixin._get_artifact_content = MagicMock(return_value=None)
    assert mixin.get_interactive_app_data("nb", "el") is None
