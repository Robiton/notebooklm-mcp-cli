# Docker Container Design — notebooklm-enterprise-mcp

> **Status:** Design document (research phase). No Dockerfile exists yet.
> See `ai/BACKLOG.md` for implementation status.

## Executive Summary

This document answers the seven design questions for containerising `notebooklm-enterprise-mcp` as a long-running MCP server reachable over HTTP.

**Scope: enterprise-only for v1.** Personal mode requires a live Chromium browser driven over CDP — that dependency is fundamentally incompatible with a minimal container. Enterprise mode needs only GCP credentials and outbound HTTPS, making it a clean fit for Docker.

---

## 1. Base Image

**Recommendation: `python:3.12-slim` (Debian-based)**

Distroless is tempting for attack-surface reduction, but two hard requirements make it impractical:

- **`gcloud` CLI** is a Python application distributed as a shell-script bundle. Installing it on distroless requires layering a full Debian/Alpine userland anyway, eliminating the size benefit.
- **Interactive auth operations** (`gcloud auth login`, `nlm config set`) need a shell. Distroless has none, so `docker exec -it <container> bash` is impossible.

`python:3.12-slim` (~130 MB compressed) gives a working shell, `apt`, and a system Python.

An alternative is **`gcr.io/google.com/cloudsdktool/google-cloud-cli:slim`** (~280 MB), which ships gcloud pre-installed on Debian-slim. That removes a manual gcloud installation step.

**Do not use Alpine.** The `websocket-client`, `httpx`, and `pydantic` wheels have C extensions that require glibc. Alpine's musl compatibility layer causes subtle build failures or forces a full recompile at image build time.

---

## 2. Enterprise GCP Authentication

**Recommendation: Application Default Credentials (ADC) volume-mounted from the host**

Three options exist:

### Option A — `gcloud auth login` inside the container
Opens a browser OAuth flow. Requires port-forwarding or `--no-browser` device flow. Fragile: credentials expire every hour and require re-auth on each restart unless a refresh token is stored. Not recommended for unattended use.

### Option B — Service Account JSON key file
A GCP service account key JSON is injected as a Docker secret or bind-mount. Set `GOOGLE_APPLICATION_CREDENTIALS=/run/secrets/sa-key.json`. The `google-auth` library picks this up automatically.

Drawbacks: service account keys are long-lived, high-value secrets that require rotation policy. **Never** pass as an environment variable or bake into the image.

**Use for CI/CD or production deployments.**

### Option C — Host ADC token file (recommended for developer workstations)

Authenticate once on the host:

```bash
gcloud auth application-default login
```

Mount the resulting file read-only into the container:

```bash
-v "$HOME/.config/gcloud:/home/nlm/.config/gcloud:ro"
```

Set `GOOGLE_APPLICATION_CREDENTIALS=/home/nlm/.config/gcloud/application_default_credentials.json`. The `google-auth` library refreshes access tokens automatically using the stored refresh token — no browser needed after first login, no service account key required.

---

## 3. Personal Mode Authentication (CDP/Browser)

**Short answer: Not feasible in a minimal container. Excluded from v1.**

Personal mode works by:
1. `nlm login` launches a Chromium browser with a dedicated user-data-dir
2. User logs in interactively
3. Cookies are extracted via CDP WebSocket and cached to `~/.notebooklm-mcp-cli/profiles/default/cookies.json`
4. The server reads cached cookies on subsequent starts; the browser refreshes them automatically when they age out

In a container this requires Chrome (~400–500 MB extra), an X display or headless Chrome with `--cap-add SYS_ADMIN` (or disabling the sandbox — a security regression), and ongoing cookie refresh that may re-trigger the browser at unexpected times.

**Advanced workaround for personal-mode users:** Run `nlm login` on the host, then mount the profile directory:

```bash
-v "$HOME/.notebooklm-mcp-cli:/home/nlm/.notebooklm-mcp-cli:rw"
```

The code respects `NOTEBOOKLM_MCP_CLI_PATH` to override the storage directory. The container reads cached cookies without needing Chrome installed — but automatic refresh on expiry will fail, requiring periodic re-login on the host.

**v1 decision: enterprise-only. Document the volume-mount workaround for advanced personal-mode users only.**

---

## 4. Auth Persistence Across Container Restarts

**Recommendation: Two named volumes**

```
notebooklm-gcloud-creds  →  /home/nlm/.config/gcloud
notebooklm-nlm-data      →  /home/nlm/.notebooklm-mcp-cli
```

The `NOTEBOOKLM_MCP_CLI_PATH` environment variable controls the storage path; set explicitly to `/home/nlm/.notebooklm-mcp-cli`.

The gcloud token cache in `~/.config/gcloud` contains the refresh token. As long as the volume is mounted, `google-auth` auto-refreshes the 1-hour access token without user interaction.

The `config.toml` (enterprise mode, project ID, location) only needs to be written once — either via a pre-built config file or by running `nlm config set` in a one-time init step. It then persists in the `notebooklm-nlm-data` volume.

**Do not use bind mounts for secrets in production.** Use named volumes for developer setups and Docker secrets / Kubernetes Secrets / cloud secrets managers for multi-user or server deployments.

---

## 5. Exposing the MCP Server

**Recommendation: HTTP transport (Streamable HTTP / MCP 2025-03-26) on port 8000, path `/mcp`**

The server supports `--transport http` via the `NOTEBOOKLM_MCP_TRANSPORT` environment variable, using FastMCP's `streamable-http` transport. A `/health` endpoint is already implemented.

**Container startup command:**

```bash
notebooklm-mcp --transport http --host 0.0.0.0 --port 8000 --path /mcp
```

Or equivalently via environment variables:

```
NOTEBOOKLM_MCP_TRANSPORT=http
NOTEBOOKLM_MCP_HOST=0.0.0.0
NOTEBOOKLM_MCP_PORT=8000
NOTEBOOKLM_MCP_PATH=/mcp
```

**Security:** Do not bind `0.0.0.0` on a host-networked container without a reverse proxy or network-level firewall. The HTTP transport has no built-in authentication unless OAuth is configured (see below). Use `127.0.0.1` if the client is on the same machine.

**OAuth 2.1 (optional, for claude.ai remote MCP):** The server has a built-in OAuth 2.1 provider:

```
NOTEBOOKLM_OAUTH_CLIENT_ID=<your-id>
NOTEBOOKLM_OAUTH_CLIENT_SECRET=<your-secret>
NOTEBOOKLM_OAUTH_SERVER_URL=https://your-public-host.example.com
```

This activates `/.well-known/oauth-authorization-server` and `/oauth/token` endpoints.

---

## 6. Claude Desktop / Claude Code Configuration

**Container on localhost:**

```json
{
  "mcpServers": {
    "notebooklm-mcp": {
      "type": "http",
      "url": "http://localhost:8000/mcp"
    }
  }
}
```

**Container on a remote host (with TLS via reverse proxy):**

```json
{
  "mcpServers": {
    "notebooklm-mcp": {
      "type": "http",
      "url": "https://your-host.example.com/mcp"
    }
  }
}
```

If OAuth is enabled, clients that support OAuth 2.1 auto-discover the authorization server via `/.well-known/oauth-authorization-server`. The JSON config is identical — the client detects OAuth from the metadata endpoint.

> **Note:** Older Claude Desktop versions may require stdio-style config. Confirm your version supports `"type": "http"` before relying on HTTP transport for Desktop.

---

## 7. Security Hardening

### Non-root user

```dockerfile
RUN useradd --create-home --shell /bin/bash --uid 1000 nlm
USER nlm
```

### Read-only filesystem

Run with `--read-only`, mounting writable tmpfs/volumes only where needed:
- `/tmp` — tmpfs (runtime scratch)
- `/home/nlm/.notebooklm-mcp-cli` — named volume (config + auth cache)
- `/home/nlm/.config/gcloud` — named volume (GCP ADC tokens)

### Capability drops

```bash
--cap-drop ALL
```

The process only needs outbound HTTPS. No privileged ports, no sandbox requirements (enterprise-only — personal mode's Chrome would need `SYS_ADMIN`).

### Network policy

- Do not publish port 8000 on the host interface without a reverse proxy handling auth and TLS.
- Egress: allow only `notebooklm.cloud.google.com` (enterprise API) and `oauth2.googleapis.com` (token refresh).

### Secrets handling

- Service account keys: mount via Docker secrets (`/run/secrets/sa-key.json`), never as environment variables or image layers.
- `NOTEBOOKLM_OAUTH_CLIENT_SECRET`: inject via Docker secrets or a secrets manager; never in `docker-compose.yml` plaintext.
- Auth/cookie files written by the auth flow are chmod 600; treat the volume as sensitive.

### Image hygiene

- No dev dependencies in the production image (no pytest, ruff, mypy).
- Pin the base image by digest in production to prevent silent base-image drift.
- Run `pip-audit` on the lock file as part of CI before building.
- The gcloud CLI binary is only needed at credential-setup time, not at server runtime. If credentials are pre-injected as a file, gcloud does not need to be installed in the production image.

---

## Recommended Architecture — Enterprise-Only v1

```
Host machine
├── gcloud auth application-default login  (run once by user)
├── ~/.config/gcloud/application_default_credentials.json  (refresh token stored here)
│
Docker container: notebooklm-enterprise-mcp:latest
├── Base: python:3.12-slim
├── User: nlm (uid 1000, non-root)
├── Installed: notebooklm-enterprise-mcp (pip, from PyPI)
├── NOT installed: Chrome, gcloud CLI (not needed at server runtime)
├── Transport: HTTP on 0.0.0.0:8000/mcp
├── Health: GET /health → 200 OK
├── Read-only rootfs with:
│   ├── /tmp (tmpfs)
│   ├── /home/nlm/.config/gcloud (named volume — GCP ADC tokens)
│   └── /home/nlm/.notebooklm-mcp-cli (named volume — config.toml)
│
Environment variables at docker run time:
    GOOGLE_APPLICATION_CREDENTIALS=/home/nlm/.config/gcloud/application_default_credentials.json
    NOTEBOOKLM_MODE=enterprise
    NOTEBOOKLM_PROJECT_ID=<your-gcp-project-id>
    NOTEBOOKLM_LOCATION=global
    NOTEBOOKLM_MCP_TRANSPORT=http
    NOTEBOOKLM_MCP_HOST=0.0.0.0
    NOTEBOOKLM_MCP_PORT=8000
│
Claude Code / Claude Desktop:
    { "type": "http", "url": "http://localhost:8000/mcp" }
```

---

## Distribution Options

| Option | Pros | Cons |
|--------|------|------|
| **Docker Hub** (`robiton/notebooklm-enterprise-mcp`) | Easy `docker pull`, no auth needed | Public by default; rate limits |
| **GitHub Container Registry** (`ghcr.io/Robiton/notebooklm-enterprise-mcp`) | Free for public repos, tied to releases | Requires GitHub account to pull from private |
| **Private registry** (GCR, ECR, ACR) | Full access control | Requires auth config on client machines |

For v1: **GitHub Container Registry** paired with GitHub Actions `publish.yml` is the simplest. Images are built on tag push (same trigger as PyPI publish) and tagged with the version number.

---

## Future: Personal Mode in a Container

If personal mode is added to a future container variant, the recommended approach is:

1. A separate `notebooklm-mcp-personal` image that includes Chromium.
2. Run with `--security-opt seccomp=chrome.json` (custom seccomp profile) instead of `--privileged`.
3. The initial login step (`nlm login`) would use `--manual --file cookies.txt` with a cookie file bind-mounted from the host — avoiding a live browser inside the container.
4. Auto-CDP cookie refresh is explicitly documented as host-only; users who need it should run the server directly on the host.
