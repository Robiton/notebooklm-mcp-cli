# Project:  notebooklm-mcp-cli
# File:     tests/test_mcp_pipeline_create.py
# Modified: 2026-10-12
# Version:  1.0.8.20261012.1546
# Purpose:  test_mcp_pipeline_create.py
# Changelog:
#   2026-10-12 v1.0.8 — header added: file touched by upstream v0.15.4 merge (sync batch 6)
from unittest.mock import patch

from notebooklm_tools.mcp.tools import pipeline as pipeline_tool

SVC = "notebooklm_tools.services.pipeline.pipeline_create"
STEPS = [{"action": "notebook_query", "params": {"query": "Summarize"}}]


def test_create_passes_name_description_steps():
    with patch(SVC, return_value={"name": "mine", "steps_count": 1}) as svc:
        out = pipeline_tool(action="create", pipeline_name="mine", description="d", steps=STEPS)
    svc.assert_called_once_with("mine", "d", STEPS)
    assert out["status"] == "success" and out["name"] == "mine"


def test_create_requires_name_and_steps():
    assert pipeline_tool(action="create", steps=STEPS)["status"] == "error"
    assert pipeline_tool(action="create", pipeline_name="mine")["status"] == "error"
