# Project:  notebooklm-mcp-cli
# File:     tests/test_mcp_chat_note.py
# Modified: 2026-10-12
# Version:  1.0.8.20261012.1546
# Purpose:  test_mcp_chat_note.py
# Changelog:
#   2026-10-12 v1.0.8 — header added: file touched by upstream v0.15.4 merge (sync batch 6)
from unittest.mock import patch

from notebooklm_tools.mcp.tools import chats

SVC = "notebooklm_tools.services.chats.save_chat_to_note"


def test_saves_whole_chat_when_turn_is_zero():
    with patch(SVC, return_value={"note_id": "n1"}) as svc:
        out = chats.chat_save_to_note(notebook_id="nb", conversation_id="c1")
    svc.assert_called_once_with(notebook="nb", conversation_id="c1", turn_index=None, title=None)
    assert out == {"status": "success", "note_id": "n1"}


def test_saves_one_turn_with_title():
    with patch(SVC, return_value={"note_id": "n2"}) as svc:
        chats.chat_save_to_note(notebook_id="nb", conversation_id="c1", turn=2, title="Key answer")
    svc.assert_called_once_with(
        notebook="nb", conversation_id="c1", turn_index=2, title="Key answer"
    )


def test_service_error_becomes_error_result():
    with patch(SVC, side_effect=ValueError("empty")):
        assert chats.chat_save_to_note(notebook_id="nb", conversation_id="c1")["status"] == "error"
