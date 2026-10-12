# tools/ — the commands this repository actually runs

_Nested AGENTS.md: **additive**, per ai/STANDARDS.md -> Nested AGENTS.md. Everything in the
root `AGENTS.md` still applies. This file exists because the root one is the TEMPLATE every
adopter receives, so its Project Commands table is `[fill in]` on purpose and cannot name
these._

| Task | Command |
|---|---|
| Every gate CI runs, in one command | `tools/preflight.sh` |
| Scanners, headers, drift, always-loaded byte total | `./setup.sh --check` |
| One tool's own suite | `tools/<name>.sh --selftest` (every tool here has one) |
| Is the build green on GitHub, and are the alert features on | `tools/ci_status.sh` |
| What a release would say about this commit | `tools/release_status.sh` |
| Cut a release | `tools/release.sh` |

## Rules that apply in this directory

- **Commit first, then `tools/preflight.sh`.** Never `--allow-dirty`: it disables
  `header_check --since`, the only gate that reads git. Read the exit code, not the colour.
- **Never push with `--no-verify`.** After a green preflight a plain `git push` is instant:
  the pre-push hook accepts preflight's receipt for HEAD. Without one, the hook is the gate.
  (This line used to say the opposite, and it carried most of the estate's ungated pushes.)
- **Every tool has three outcomes, not two.** `0` verified, non-zero found something, and
  `3` COULD NOT VERIFY. A tool that cannot run must never emit its strongest verdict; see
  ai/STANDARDS.md -> Exit codes, and ai/STANDARDS_EVIDENCE.md for what that cost to learn.
- **A `>/dev/null` on a tool with a verdict throws the verdict away.** The exit code is the
  contract and the text is usually the point. If you silence one, say why on the line above.
- **A selftest asserts the TOOL, not the repository.** A case that reads this repo's own
  files passes here and reddens every adopter on upgrade.
- **New executables track 644 here** (`core.fileMode=false` in these working copies).
  `git update-index --chmod=+x <path>`, or the tool ships as a file git never runs.
