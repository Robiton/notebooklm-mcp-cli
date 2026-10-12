# Project:  notebooklm-mcp-cli
# File:     scripts/spike_enterprise_v15.py
# Modified: 2026-10-12
# Version:  1.0.8.20261012.1840
# Purpose:  v1.5 spike: exercise the official Enterprise v1alpha API end to end, logging every call.
# Changelog:
#   2026-10-12 v1.0.8 — created: v1.5 spike (notebook, text source, audio overview, share)
"""v1.5 spike: run the weekly-publish pipeline once against the official Enterprise API.

Answers the open questions in the v1.5 plan with real responses:

1. Does ``audioOverviews`` accept ``episodeFocus`` / ``languageCode`` / ``sourceIds`` now?
   (In March 2026 the API rejected them with "Unknown name"; Google now documents them.)
2. Can audio generation status be polled (GET on ``audioOverviews/default`` or the
   returned ``name``)?
3. Does ``:share`` work for a single email, and (optionally) for a group address?
4. What does a text source look like when it reaches ``SOURCE_STATUS_COMPLETE``?

Only documented ``discoveryengine.googleapis.com`` v1alpha endpoints are called. Nothing
touches Google Drive. The access token comes from ``NBLM_ACCESS_TOKEN`` or
``gcloud auth print-access-token`` and is never written to the log.

Usage (run it yourself; it needs your enterprise login)::

    uv run python scripts/spike_enterprise_v15.py \\
        --project-number 123456789012 --share-email you@example.com

Every request and response is appended as one JSON line to
``~/.notebooklm-mcp-cli/spike-logs/v15-<timestamp>.jsonl`` (outside the repo).
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import subprocess
import sys
import time
from pathlib import Path
from typing import Any

import httpx

API = "https://{endpoint}-discoveryengine.googleapis.com/v1alpha/projects/{project}/locations/{loc}"

SAMPLE_BRIEF = """# Spike brief

This is a short test document created by the v1.5 spike script. It exists only to give the
notebook a source so an audio overview can be generated. Topics: model releases this week,
an agent-security note, and one open-source tool worth a look.
"""


def get_token() -> str:
    """Return an access token from NBLM_ACCESS_TOKEN or gcloud. Never logged."""
    if token := os.environ.get("NBLM_ACCESS_TOKEN", "").strip():
        return token
    try:
        out = subprocess.run(
            ["gcloud", "auth", "print-access-token"],
            capture_output=True,
            text=True,
            timeout=30,
        )
    except FileNotFoundError:
        sys.exit("gcloud not found. Install it or set NBLM_ACCESS_TOKEN.")
    if out.returncode != 0 or not out.stdout.strip():
        sys.exit("gcloud could not print an access token. Run: gcloud auth login")
    return out.stdout.strip()


class Spike:
    """Thin logged HTTP client. Each call is one JSONL record: request, status, body, timing."""

    def __init__(self, base: str, token: str, log_path: Path):
        self.base = base
        self.log_path = log_path
        self.http = httpx.Client(
            timeout=120.0,
            headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
        )

    def call(self, step: str, method: str, path: str, body: Any = None) -> httpx.Response:
        """``path`` is relative to the location base, or a full https URL."""
        url = path if path.startswith("https://") else f"{self.base}/{path}"
        started = time.monotonic()
        resp = self.http.request(method, url, json=body)
        try:
            resp_body: Any = resp.json()
        except ValueError:
            resp_body = resp.text
        record = {
            "time": dt.datetime.now(dt.UTC).isoformat(),
            "step": step,
            "request": {"method": method, "url": url, "body": body},
            "status": resp.status_code,
            "response": resp_body,
            "elapsed_s": round(time.monotonic() - started, 3),
        }
        with self.log_path.open("a", encoding="utf-8") as fh:
            fh.write(json.dumps(record) + "\n")
        print(f"  {step}: {method} {url.removeprefix(self.base)} -> {resp.status_code}")
        return resp


def run(args: argparse.Namespace) -> int:
    log_dir = Path.home() / ".notebooklm-mcp-cli" / "spike-logs"
    log_dir.mkdir(parents=True, exist_ok=True, mode=0o700)
    log_path = log_dir / f"v15-{dt.datetime.now():%Y%m%d-%H%M%S}.jsonl"
    base = API.format(
        endpoint=args.endpoint_location, project=args.project_number, loc=args.location
    )
    s = Spike(base, get_token(), log_path)
    findings: dict[str, Any] = {}
    print(f"Logging to {log_path}\n")

    # 1. Create a notebook. Record its id; the API has no search-by-title.
    title = f"{args.title_prefix} {dt.date.today():%Y-%m-%d} spike"
    r = s.call("create_notebook", "POST", "notebooks", {"title": title})
    if r.status_code != 200:
        print("\nCreate failed; see the log. Check project number, IAM role and license.")
        return 1
    notebook = r.json()
    nb_id = notebook.get("notebookId")
    findings["notebook_id"] = nb_id
    findings["notebook_name"] = notebook.get("name")

    # 2. Add a text source (no Drive, no URL; URL sources are blocked under VPC-SC).
    r = s.call(
        "add_text_source",
        "POST",
        f"notebooks/{nb_id}/sources:batchCreate",
        {"userContents": [{"textContent": {"sourceName": "Spike brief", "content": SAMPLE_BRIEF}}]},
    )
    sources = r.json().get("sources", []) if r.status_code == 200 else []
    source_id = sources[0].get("sourceId", {}).get("id") if sources else None
    findings["add_text_source_status"] = r.status_code

    # 3. Wait for the source to finish processing.
    status = None
    for _ in range(args.poll_count):
        if not source_id:
            break
        r = s.call("get_source", "GET", f"notebooks/{nb_id}/sources/{source_id}")
        status = r.json().get("settings", {}).get("status") if r.status_code == 200 else None
        if status == "SOURCE_STATUS_COMPLETE":
            break
        time.sleep(args.poll_seconds)
    findings["source_status"] = status

    # 4. Audio overview with the documented fields; fall back to {} if they are rejected.
    full_body: dict[str, Any] = {"episodeFocus": args.focus, "languageCode": "en"}
    if source_id:
        full_body["sourceIds"] = [{"id": source_id}]
    r = s.call("audio_with_fields", "POST", f"notebooks/{nb_id}/audioOverviews", full_body)
    findings["audio_fields_accepted"] = r.status_code == 200
    if r.status_code != 200:
        r = s.call("audio_empty_body", "POST", f"notebooks/{nb_id}/audioOverviews", {})
        findings["audio_empty_body_status"] = r.status_code
    audio_name = r.json().get("audioOverview", {}).get("name") if r.status_code == 200 else None

    # 5. Can status be polled?
    r = s.call("audio_get_default", "GET", f"notebooks/{nb_id}/audioOverviews/default")
    findings["audio_get_default_status"] = r.status_code
    if audio_name:
        # The returned name is a full resource path (projects/...); GET it from the API root.
        root = s.base.split("/projects/")[0]
        r = s.call("audio_get_name", "GET", f"{root}/{audio_name}")
        findings["audio_get_name_status"] = r.status_code

    # 6. Share with one person (and optionally a group address).
    if args.share_email:
        r = s.call(
            "share_user",
            "POST",
            f"notebooks/{nb_id}:share",
            {"accountAndRoles": [{"email": args.share_email, "role": "PROJECT_ROLE_READER"}]},
        )
        findings["share_user_status"] = r.status_code
    if args.share_group:
        r = s.call(
            "share_group",
            "POST",
            f"notebooks/{nb_id}:share",
            {"accountAndRoles": [{"email": args.share_group, "role": "PROJECT_ROLE_READER"}]},
        )
        findings["share_group_status"] = r.status_code

    # 7. Optional cleanup.
    if args.cleanup and findings.get("notebook_name"):
        r = s.call(
            "delete_notebook",
            "POST",
            "notebooks:batchDelete",
            {"names": [findings["notebook_name"]]},
        )
        findings["deleted"] = r.status_code == 200

    print("\nFindings:")
    print(json.dumps(findings, indent=2))
    with log_path.open("a", encoding="utf-8") as fh:
        fh.write(json.dumps({"step": "findings", **findings}) + "\n")
    print(f"\nFull log: {log_path}")
    return 0


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    p.add_argument("--project-number", required=True, help="Google Cloud project NUMBER (not ID)")
    p.add_argument("--location", default="global", help="data store location (default global)")
    p.add_argument("--endpoint-location", default="global", choices=["us", "eu", "global"])
    p.add_argument("--share-email", default="", help="share the notebook with this address")
    p.add_argument("--share-group", default="", help="also try sharing with a group address")
    p.add_argument("--title-prefix", default="TWAI")
    p.add_argument("--focus", default="A short test episode. Keep it brief and plain.")
    p.add_argument("--poll-count", type=int, default=20)
    p.add_argument("--poll-seconds", type=float, default=5.0)
    p.add_argument("--cleanup", action="store_true", help="delete the notebook at the end")
    return run(p.parse_args())


if __name__ == "__main__":
    sys.exit(main())
