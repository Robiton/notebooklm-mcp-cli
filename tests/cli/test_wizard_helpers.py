# Project:  notebooklm-mcp-cli
# File:     tests/cli/test_wizard_helpers.py
# Modified: 2026-10-12
# Version:  1.0.8.20261012.1546
# Purpose:  Tests for shared wizard picker-row model and questionary conversion.
# Changelog:
#   2026-10-12 v1.0.8 — header added: file touched by upstream v0.15.4 merge (sync batch 6)
"""Tests for shared wizard picker-row model and questionary conversion."""

from notebooklm_tools.cli.commands import setup_wizard as w


def test_rows_to_choices_inserts_separators_per_group():
    rows = [
        w.PickerRow(
            group="Needs a fix", label="Codex", value="codex", checked=True, note="⚠ quick fix"
        ),
        w.PickerRow(group="Not connected yet", label="Windsurf", value="windsurf", checked=True),
        w.PickerRow(
            group="Already connected", label="Cursor", value="cursor", disabled="already connected"
        ),
    ]
    choices = w.rows_to_choices(rows)
    titles = [getattr(c, "title", str(c)) for c in choices]
    assert any("Needs a fix" in t for t in titles)
    assert any("Codex" in t and "quick fix" in t for t in titles)
    cursor = next(c for c in choices if getattr(c, "value", None) == "cursor")
    assert cursor.disabled == "already connected"


def test_rows_to_choices_skips_empty_groups():
    rows = [w.PickerRow(group="Only group", label="A", value="a")]
    choices = w.rows_to_choices(rows)
    seps = [c for c in choices if isinstance(c, w.questionary.Separator)]
    assert len(seps) == 1


def test_rows_to_choices_ungrouped_has_no_separator():
    rows = [w.PickerRow(group=None, label="A", value="a")]
    choices = w.rows_to_choices(rows)
    seps = [c for c in choices if isinstance(c, w.questionary.Separator)]
    assert len(seps) == 0
