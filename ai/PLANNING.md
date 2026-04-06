# Planning Standards

## Spec documents

Every significant feature or change gets a spec file.

Location: `docs/specs/YYYY-MM-DD-feature-name.md`

Required sections:
- **Problem statement** — what problem are we solving
- **Proposed solution** — how we plan to solve it
- **Out of scope** — what we are explicitly not doing
- **Dependencies** — what this requires or affects
- **Risks** — what could go wrong
- **Success criteria** — how we know it worked
- **Version target** — which version this ships in

## Task format in BACKLOG.md

```
- [ ] Task description | Priority: High/Med/Low | Owner: [name or tool] | Due: YYYY-MM-DD
```

## Decision log format for MEMORY.md

When an architectural or design decision is made, add an entry:

```
## YYYY-MM-DD — Decision title
- Decision: what was decided
- Why: the reasoning
- Alternatives considered: what else was evaluated
- Revisit trigger: what would cause us to reconsider this
```

## Adding a new MCP tool — checklist

1. Capture the network request via Chrome DevTools (personal) or API docs (enterprise)
2. Document the endpoint in `docs/API_REFERENCE.md`
3. Add the low-level method in `core/client.py` (personal) or `core/enterprise_client.py`
4. If enterprise, add the adapter method in `core/enterprise_adapter.py`
5. Add business logic in the appropriate `services/*.py` module
6. Add the MCP tool wrapper in `mcp/tools/*.py`
7. Register in `mcp/tools/__init__.py` and `mcp/server.py`
8. Write unit tests for the service function in `tests/services/`
9. Run `uvx ruff check . && uvx ruff format --check .` — fix any issues
10. Update `ai/SESSION.md` and `ai/BACKLOG.md`

## Upstream PR strategy

This project is a fork of `jacob-bd/notebooklm-mcp-cli`. Before opening a PR upstream:
- Ensure the feature works independently of enterprise-only infrastructure
- Run the full upstream CI workflow locally: lint, format, tests
- Keep the diff minimal — one feature per PR
- Note: enterprise features will not be accepted upstream until Discovery Engine
  API promotes from v1alpha to v1 (see `ai/MEMORY.md`)

## Release checklist

- [ ] Version updated in `version` file and `src/notebooklm_tools/__init__.py`
- [ ] `uv run pytest` passes
- [ ] `uvx ruff check . && uvx ruff format --check .` clean
- [ ] `ai/SESSION.md` updated with release notes entry
- [ ] `ai/BACKLOG.md` updated — completed tasks marked done
- [ ] GitHub release tagged with full version string
