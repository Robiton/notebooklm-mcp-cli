# Project:  notebooklm-mcp-cli
# File:     tests/test_mcp_health_routes.py
# Modified: 2026-10-12
# Version:  1.0.8.20261012.1546
# Purpose:  test_mcp_health_routes.py
# Changelog:
#   2026-10-12 v1.0.8 — header added: file touched by upstream v0.15.4 merge (sync batch 6)
from starlette.routing import Route

from notebooklm_tools.mcp.server import mcp


def test_health_routes_support_conventional_probe_paths_and_head():
    app = mcp.http_app()
    health_routes = {
        route.path: route
        for route in app.routes
        if isinstance(route, Route) and route.path in {"/health", "/healthz"}
    }

    assert set(health_routes) == {"/health", "/healthz"}
    for route in health_routes.values():
        assert "GET" in route.methods
        assert "HEAD" in route.methods
