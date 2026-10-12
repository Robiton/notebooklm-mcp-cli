#!/usr/bin/env bash
# Project:  ai-project-scaffold
# File:     tools/release.sh
# Modified: 2026-10-10
# Version:  0.9.5.20261010.1252
# Purpose:  Cut a release that fails closed and leaves a receipt saying what was actually checked
# Changelog:
#   2026-10-10 v0.9.5.20261010.1252 — the pipx build fallback is pinned to build==1.6.1 (report item 28, S9).
#   2026-10-10 v0.9.4.20261010.1205 — a SHA256SUMS manifest of the tagged tree is built before the tag is pushed and attached to the release (report item 15). A manifest of files, not a tarball hash: GitHub builds tarballs on demand.
#   2026-09-23 v0.9.3.20260923.0941 — fixtures run inside the root tools/fixture_guard.sh validates. There a git and a mktemp on PATH refuse anything that would land outside it. Every mktemp takes a ${TMPDIR} template, because macOS mktemp ignores TMPDIR without one.
#   2026-09-23 v0.9.2.20260923.0843 — every mktemp fails closed. A failed one left the temp variable empty, so the fixture ran in the caller's directory; header_check's committed into Robiton/control.
#   2026-09-23 v0.9.1.20260923.0232 — --publish pushes the tag THROUGH the pre-push hook, before
#                        the changelog commit, so the receipt still matches HEAD; a refused
#                        push stops the release. The changelog commit goes on
#                        chore/changelog-<version> when releasing from main, never on main.
#   2026-09-01 v0.9.0.20260901.1930 — REGENERATES CHANGELOG.md AFTER TAGGING (#282), so the
#                        next commit does not land on a red gate. `changelog.sh --check`
#                        already tolerates the release moment -- HEAD carrying a tag the file
#                        predates is unavoidable -- but THAT TOLERANCE IS ONE COMMIT WIDE and
#                        closes the instant anything else is committed.
#                        MEASURED: three releases in one session, three `[FAIL] CHANGELOG.md
#                        matches the tags`, three `chore(changelog)` commits saying nothing a
#                        reader needs. A gate that fires predictably after a normal action,
#                        with a fixed one-command remedy and no decision in it, is one people
#                        clear on autopilot -- and then clear on the day it mattered.
#                        The file declares itself generated, so no judgement is taken from
#                        anyone. Committed, deliberately NOT pushed: pushing a branch is the
#                        releaser's call.
#   2026-08-31 v0.8.1.20260831.0904 — #250 the fixture set an identity per-commit but the SCRIPT UNDER TEST runs bare git tag -a,
#                        which needs its own -- exported now, so the fixture stops depending on ambient config.
#   2026-08-18 v0.8.0.20260819.0402 — Initial. Closes P0-7 (release receipts) and P0-8 (the
#                        release path must fail closed), which are one deliverable: a receipt
#                        nobody can trust is worse than none, and a release path that can
#                        proceed past a failed gate produces exactly that.
#                        A TAG IS NOT A RECEIPT. It records that someone typed a version. It
#                        does not say which SHA was tested, whether the gate ran or was
#                        merely skipped, what artifact was built, or on which platform.
#                        Every release cut here so far was `git tag` typed by hand after
#                        reading a summary line -- and on 2026-08-18 that exact habit pushed
#                        0.58.2 with preflight red, because a summary was read where an exit
#                        code should have been. This tool reads exit codes.
#                        FAILING CLOSED, CONCRETELY: no gate is ever piped into a formatter
#                        (the pipeline would report the formatter); every gate exit code is
#                        captured into a variable before anything is printed; BLOCKED (exit 3)
#                        is a refusal, not a pass, because "I could not check" must never
#                        read like "I checked"; and the tag is created only after every gate
#                        AND the receipt have succeeded, so a tag can never exist for a
#                        release whose evidence does not.
#                        RECEIPTS ARE NOT TRACKED, and that is forced rather than chosen: a
#                        receipt records the commit it describes, so committing it would
#                        produce a receipt filed under a SHA that is not the SHA it names.
#                        `.release-receipts/` is gitignored and the receipt is attached to
#                        the GitHub release, which is where it becomes immutable and
#                        fetchable by anyone asking what a given version was tested against.
set -euo pipefail

# >>> shared:upstream
# carried by: tools/scaffold_version.sh tools/scaffold_upgrade.sh tools/context_survival.sh tools/release.sh
# ONE BODY, FOUR FILES, byte for byte. preflight's "shared blocks" gate fails the moment a
# copy differs or a file on the line above stops carrying it (report item 16).
# Not a sourced library: these tools are vendored one by one, and scaffold_upgrade.sh
# replaces itself mid-run, so a library is one more file to deliver in step -- and the
# drift this block caused (item 8) came from copies nobody compared, not from copying.
UPSTREAM_DEFAULT="Robiton/ai-project-scaffold"
UPSTREAM_MIRROR="bworrell_Zotec/ai-project-scaffold"
upstream_valid() {  # upstream_valid <name> -> 0 only for one owner/repo
  # (An underscore is legal in an owner: managed-user accounts, like the mirror's, carry one.)
  # The name is spliced into `gh api repos/<name>/tarball/<tag>`, so `../x`, a third
  # segment or a leading dot reaches a different endpoint than the one it names.
  case "$1" in
    */*/*|.*|*/.|*/..) return 1 ;;
  esac
  printf '%s\n' "$1" | grep -Eq '^[A-Za-z0-9][A-Za-z0-9_-]*/[A-Za-z0-9_.-]+$'
}
upstream_pinned() {  # upstream_pinned <root> -> the declared upstream, or nothing
  # Order: SCAFFOLD_UPSTREAM (one run), then `.scaffold-upstream` in the project root (an
  # adopter-owned file, one owner/repo line, # comments allowed). Returns 1, saying why,
  # when what is declared is not an owner/repo: the caller decides whether that stops it.
  local _u=""
  if [ -n "${SCAFFOLD_UPSTREAM:-}" ]; then
    _u="$SCAFFOLD_UPSTREAM"
  elif [ -f "$1/.scaffold-upstream" ]; then
    _u="$(sed -e 's/#.*//' -e 's/[[:space:]]//g' "$1/.scaffold-upstream" | sed -n '/./{p;q;}')"
  fi
  [ -n "$_u" ] || return 0
  if upstream_valid "$_u"; then printf '%s\n' "$_u"; return 0; fi
  printf 'scaffold: the declared upstream "%s" is not an owner/repo name -- not used\n' "$_u" >&2
  return 1
}
scaffold_sums() {  # scaffold_sums make <dir>  |  scaffold_sums check <dir> <SHA256SUMS>
  # THE RELEASE'S SHA256SUMS IS A MANIFEST OF THE TREE, NOT A HASH OF THE TARBALL. GitHub
  # builds tarballs on demand and has changed their bytes before; the files inside do not
  # change. One line per file, "<sha256>  <path>", sorted; a symlink hashes its target.
  # check: exit 0 match, 1 differs (each difference on stdout), 3 could not run. An extra
  # file is a difference too -- `sha256sum -c` would pass a tree that gained one.
  python3 - "$@" <<'PY_SUMS'
import hashlib, os, sys
def tree(root):
    out = {}
    for d, dirs, files in os.walk(root):
        dirs[:] = sorted(x for x in dirs if x != ".git")
        for n in list(files) + [x for x in dirs if os.path.islink(os.path.join(d, x))]:
            p = os.path.join(d, n)
            rel = os.path.relpath(p, root).replace(os.sep, "/")
            if os.path.islink(p):
                out[rel] = hashlib.sha256(b"symlink:" + os.readlink(p).encode()).hexdigest()
            elif os.path.isfile(p):
                with open(p, "rb") as fh:
                    out[rel] = hashlib.sha256(fh.read()).hexdigest()
    return out
try:
    mode, root = sys.argv[1], sys.argv[2]
    have = tree(root)
    if mode == "make":
        for rel in sorted(have):
            print("%s  %s" % (have[rel], rel))
        sys.exit(0)
    want = {}
    with open(sys.argv[3]) as fh:
        for line in fh:
            if line.strip():
                h, rel = line.rstrip("\n").split("  ", 1)
                want[rel] = h
except Exception as e:
    print("could not compare: %s" % e)
    sys.exit(3)
if not want:
    print("the manifest lists no files")
    sys.exit(3)
bad = [("changed  " if rel in have else "missing  ") + rel
       for rel in sorted(want) if have.get(rel) != want[rel]]
bad += ["added    " + rel for rel in sorted(set(have) - set(want))]
if bad:
    print("\n".join(bad[:20]) + ("\n...and %d more" % (len(bad) - 20) if len(bad) > 20 else ""))
sys.exit(1 if bad else 0)
PY_SUMS
}
# <<< shared:upstream

SELF="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
RECEIPT_DIR="${RELEASE_RECEIPT_DIR:-.release-receipts}"
# The `build` front-end the pipx fallback runs, pinned (report item 28, S9). 1.6.1 was
# released 2026-09-10. uv and an installed `python3 -m build` are the machine's own.
BUILD_PIN="1.6.1"
PUBLISH=0
DRY=0
ALLOW_NO_ARTIFACT=0
MODE=release

while [ $# -gt 0 ]; do
  case "$1" in
    --selftest)          MODE=selftest ;;
    --ci-verdict)        MODE=ci_verdict ;;
    --publish)           PUBLISH=1 ;;
    --dry-run)           DRY=1 ;;
    --allow-no-artifact) ALLOW_NO_ARTIFACT=1 ;;
    -h|--help)           MODE=usage ;;
    *) echo "release: unknown argument: $1" >&2; exit 2 ;;
  esac
  shift
done

say()  { printf '%s\n' "$*"; }
die()  { printf 'release: %s\n' "$*" >&2; exit 1; }
blocked() { printf 'release: BLOCKED — %s\n' "$*" >&2; exit 3; }

sha256_of() {
  if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | cut -d' ' -f1
  elif command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | cut -d' ' -f1
  else echo "unavailable"; fi
}

# ---------------------------------------------------------------- the CI verdict
# ONE IMPLEMENTATION, CALLED BY BOTH the release flow and the selftest. Writing this rule
# a second time inside the test is the defect this tree has paid for five times: the copy
# agrees with itself and neither copy is the one that ships.
#
# ANY FAILURE IS A FAILURE; ANYTHING UNFINISHED IS UNVERIFIED. Success must be earned by
# EVERY run on the commit. The first cut took `gh run list --limit 1`, which returns the
# most recent run of ANY workflow -- usually the MIRROR job here -- so a green mirror
# would have been recorded as a green test suite.
ci_verdict() {  # reads the `gh run list --json ...` array on stdin, prints one word
  python3 -c '
import json, sys
try:
    runs = json.load(sys.stdin)
except Exception:
    runs = []
if not runs:
    print("CI_UNVERIFIED")
elif any(r.get("conclusion") == "failure" for r in runs):
    print("failure")
elif all(r.get("status") == "completed" and r.get("conclusion") == "success" for r in runs):
    print("success")
else:
    print("CI_UNVERIFIED")
'
}

# ---------------------------------------------------------------- gates
# THE WHOLE OF P0-8 IS IN THESE TEN LINES. The exit code is captured into a variable
# BEFORE any output is produced, and nothing is ever piped anywhere. `gate | tee` or
# `gate | sed` reports the exit status of tee or sed -- which is 0 essentially always --
# and that is precisely how a release proceeds past a gate that failed.
GATE_JSON=""
N_PASS=0; N_FAIL=0; N_BLOCKED=0
run_gate() {
  local label="$1"; shift
  local rc=0 out tmpf verdict
  tmpf="$(mktemp "${TMPDIR:-/tmp}/release-gate.XXXXXX")" || { echo "release: mktemp failed; stopping" >&2; exit 1; }
  set +e
  "$@" >"$tmpf" 2>&1
  rc=$?
  set -e
  out="$(cat "$tmpf" 2>/dev/null || true)"
  rm -f "$tmpf"
  case "$rc" in
    0) verdict=PASS;    N_PASS=$((N_PASS + 1)) ;;
    3) verdict=BLOCKED; N_BLOCKED=$((N_BLOCKED + 1)) ;;
    *) verdict=FAIL;    N_FAIL=$((N_FAIL + 1)) ;;
  esac
  say "[$verdict] $label  (exit $rc)"
  if [ "$verdict" != "PASS" ]; then printf '%s\n' "$out" | tail -20 | sed 's/^/       /'; fi
  GATE_JSON="$GATE_JSON$(printf '%s\t%s\t%s\t%s\n' "$label" "$*" "$rc" "$verdict")
"
  return 0
}

# ---------------------------------------------------------------- usage
if [ "$MODE" = usage ]; then
  say "usage: tools/release.sh [--publish] [--dry-run] [--allow-no-artifact] [--selftest]"
  say ""
  say "  Runs every release gate, builds and hashes the artifact, and writes an immutable"
  say "  receipt to $RECEIPT_DIR/. Creates the tag ONLY if all of that succeeded."
  say "  --publish additionally pushes the tag and opens the GitHub release."
  exit 0
fi

# ---------------------------------------------------------------- the release flow
do_release() {
  local root commit tag version scfver role receipt receipt_md prev_commit prev_decision
  git rev-parse --git-dir >/dev/null 2>&1 || die "not a git repository"
  root="$(git rev-parse --show-toplevel)"
  cd "$root"

  say "release — every gate, then the receipt, then the tag. In that order."
  say ""

  # ---- precondition: a dirty tree means the receipt would describe something that is
  # not what gets tagged. This is a REFUSAL, not a gate: nothing has failed yet.
  if [ -n "$(git status --porcelain -uall)" ]; then
    say "REFUSING — the working tree is dirty. A receipt for a tree that is not what"
    say "gets tagged is a receipt for nothing. Commit, then re-run."
    git status --porcelain -uall | head -10 | sed 's/^/  /'
    exit 3
  fi

  # ---- what is being released
  [ -f version ] || blocked "no 'version' file — this repository ships nothing to release"
  version="$(head -1 version)"
  commit="$(git rev-parse HEAD)"
  scfver="$(head -1 .scaffold-version 2>/dev/null || echo '')"
  # ALWAYS "product", AND SAYING SO IS THE POINT. A repository with no `version` file was
  # already refused above, so the context branch this line used to carry could never be
  # taken -- a conditional that reads like a check and decides nothing.
  role="product"

  case "$version" in
    *.*.*.*.*) : ;;
    *) die "version '$version' is not <sem>.<YYYYMMDD>.<HHMM>" ;;
  esac

  say "  version   $version"
  say "  commit    $commit"
  say "  role      $role"
  say ""

  # ---- gate: the version invariant, where a tool owns it
  if [ -x tools/scaffold_version.sh ]; then
    run_gate "version invariant (scaffold_version.sh --assert-consistent)" \
             tools/scaffold_version.sh --assert-consistent
  fi

  # ---- gate: everything CI runs
  if [ -x tools/preflight.sh ]; then
    run_gate "preflight (everything CI runs)" tools/preflight.sh
  else
    say "[BLOCKED] preflight — tools/preflight.sh is absent or not executable"
    N_BLOCKED=$((N_BLOCKED + 1))
    GATE_JSON="$GATE_JSON$(printf '%s\t%s\t%s\t%s\n' "preflight" "tools/preflight.sh" 3 BLOCKED)
"
  fi

  # ---- gate: whatever this repository DECLARES it cannot ship without
  local mr
  if [ -f AGENTS.md ]; then
    for mr in $(grep -E '^<!--[[:space:]]*scaffold:must-run[[:space:]]+[^[:space:]]+[[:space:]]*-->[[:space:]]*$' \
                AGENTS.md 2>/dev/null | sed -E 's/^<!--[[:space:]]*scaffold:must-run[[:space:]]+//; s/[[:space:]]*-->[[:space:]]*$//' || true); do
      if [ -x "$mr" ]; then
        run_gate "$mr (declared must-run)" "./$mr"
      else
        say "[FAIL] $mr — DECLARED must-run and it cannot run"
        N_FAIL=$((N_FAIL + 1))
        GATE_JSON="$GATE_JSON$(printf '%s\t%s\t%s\t%s\n' "$mr (declared must-run)" "$mr" 1 FAIL)
"
      fi
    done
  fi

  # ---- the artifact, AND ITS HASH. A receipt that names no artifact cannot later answer
  # "is the wheel on the index the one that was audited".
  local art_status art_name art_sha art_dir
  art_status=not_applicable; art_name=""; art_sha=""
  if [ -f pyproject.toml ]; then
    art_dir="$(mktemp -d "${TMPDIR:-/tmp}/release-wheel.XXXXXX")" || { echo "release: mktemp failed; stopping" >&2; exit 1; }
    # RESOLVE A BUILD FRONT-END, exactly as tools/lint_python.sh resolves ruff. The first
    # cut hardcoded `python3 -m build` and BLOCKED the release on a machine with uv
    # installed and `build` not -- a refusal that was correct in form and wrong in fact,
    # which is the kind that gets a gate waived rather than fixed.
    set +e
    local brc=1
    if command -v uv >/dev/null 2>&1; then
      uv build --wheel --out-dir "$art_dir" >"$art_dir/build.log" 2>&1; brc=$?
    fi
    if [ "$brc" -ne 0 ] && python3 -c 'import build' >/dev/null 2>&1; then
      python3 -m build --wheel --outdir "$art_dir" >>"$art_dir/build.log" 2>&1; brc=$?
    fi
    if [ "$brc" -ne 0 ] && command -v pipx >/dev/null 2>&1; then
      # PINNED (report item 28, S9): an unpinned `pipx run build` ran whatever the index
      # served that day, inside the release that is about to be published.
      pipx run "build==$BUILD_PIN" --wheel --outdir "$art_dir" >>"$art_dir/build.log" 2>&1; brc=$?
    fi
    set -e
    if [ "$brc" -eq 0 ]; then
      art_name="$(ls "$art_dir"/*.whl 2>/dev/null | head -1 || true)"
      if [ -n "$art_name" ]; then
        art_sha="$(sha256_of "$art_name")"; art_name="$(basename "$art_name")"
        art_status=built
        say "[PASS] wheel built and hashed: $art_name"
        N_PASS=$((N_PASS + 1))
      else
        art_status=blocked
        say "[BLOCKED] python3 -m build succeeded and produced no wheel"
        N_BLOCKED=$((N_BLOCKED + 1))
      fi
    else
      art_status=blocked
      say "[BLOCKED] no build front-end succeeded — tried uv, python3 -m build, pipx run build==$BUILD_PIN"
      tail -8 "$art_dir/build.log" 2>/dev/null | sed 's/^/       /' || true
      N_BLOCKED=$((N_BLOCKED + 1))
    fi
    rm -rf "$art_dir"
  fi

  # AN SBOM, IF THE PROJECT SHIPS ONE. Optional and discovered, not assumed: a repository
  # with no tools/sbom.py says nothing. Where it exists it runs AFTER the wheel so it can
  # hash the same artifact the receipt names, and a FAILING sbom check is a blocked gate --
  # an SBOM whose dependency claim does not hold is worse than none, because it is the
  # document downstream consumers trust instead of reading the code.
  local sbom_file="" sbom_sha=""
  if [ -x tools/sbom.py ] && [ "$art_status" = built ]; then
    if tools/sbom.py --write >/dev/null 2>&1; then
      [ -f sbom.json ] && sbom_file="sbom.json"
      # THE RECEIPT REFERENCES THE SBOM BY HASH, NOT BY NAME. A filename is exactly the
      # "detached document" a receipt is supposed to stop being: two files that claim to
      # describe one release with nothing tying them together, so a substituted or edited
      # SBOM is undetectable. The hash makes the pair verifiable by anyone who has both.
      [ -n "$sbom_file" ] && sbom_sha="$(sha256_of "$sbom_file")"
      say "[PASS] SBOM written, dependency claim verified, sha256 ${sbom_sha:0:12}…"
      N_PASS=$((N_PASS + 1))
    else
      say "[BLOCKED] tools/sbom.py refused — the declared dependencies do not match the code"
      tools/sbom.py --check 2>&1 | tail -6 | sed 's/^/       /' || true
      N_BLOCKED=$((N_BLOCKED + 1))
    fi
  fi

  # A BLOCKED ARTIFACT IS A REFUSAL unless it is explicitly waived, and the waiver is
  # RECORDED. "Could not build" must never be indistinguishable from "nothing to build".
  if [ "$art_status" = blocked ] && [ "$ALLOW_NO_ARTIFACT" -eq 1 ]; then
    art_status=waived
    N_BLOCKED=$((N_BLOCKED - 1))
    say "       waived by --allow-no-artifact; the receipt records the waiver"
  fi

  # ---- CI, or an honest statement that it was not consulted
  # EVERY WORKFLOW ON THIS COMMIT, NOT WHICHEVER RAN LAST. The first cut of this took
  # `--limit 1`, which returns the most recent run of ANY workflow -- in this repository
  # that is usually the MIRROR job, and a green mirror is not a green test suite. The
  # receipt would have recorded a true fact under a label that made it a false claim.
  # Aggregated here instead: any failure is a failure, anything still running or
  # cancelled leaves the verdict CI_UNVERIFIED, and success requires that every run
  # concluded successfully. The per-workflow rows go into the receipt so the aggregate
  # can always be checked against what it was computed from.
  local ci_json slug
  ci_json="[]"
  slug="$(git remote get-url origin 2>/dev/null || true)"
  slug="${slug%.git}"; slug="${slug#*github.com/}"; slug="${slug#*github.com:}"
  # A NON-GITHUB ORIGIN HAS NO SLUG. The two strips above leave a local path or another
  # host's URL untouched, and `gh --repo <that>` then asks GitHub about nonsense.
  case "$(git remote get-url origin 2>/dev/null)" in *github.com*) ;; *) slug="" ;; esac
  if [ -n "$slug" ] && command -v gh >/dev/null 2>&1; then
    ci_json="$(gh run list --repo "$slug" --commit "$commit" --limit 20 \
               --json workflowName,conclusion,status,databaseId,url 2>/dev/null || echo '[]')"
    [ -n "$ci_json" ] || ci_json="[]"
  fi
  local ci_agg; ci_agg="$(printf '%s' "$ci_json" | ci_verdict)"

  say ""
  say "  gates: $N_PASS pass, $N_FAIL fail, $N_BLOCKED blocked"

  # ---- THE DECISION. Blocked counts against the release. That is the whole point.
  # THREE OUTCOMES, NOT TWO. A dry run releases nothing, so recording it as RELEASED made
  # the immutability guard lock the version against the real release that followed --
  # found immediately by dry-running this tool on its own release. DRY_RUN is a real
  # verdict: the gates passed and nothing was cut.
  local decision=RELEASED
  if [ "$N_FAIL" -gt 0 ] || [ "$N_BLOCKED" -gt 0 ]; then decision=REFUSED
  elif [ "$DRY" -eq 1 ]; then decision=DRY_RUN; fi

  # ---- the receipt, written whether or not the release proceeds. A refusal is evidence too.
  mkdir -p "$RECEIPT_DIR"
  receipt="$RECEIPT_DIR/$version.json"
  receipt_md="$RECEIPT_DIR/$version.md"

  # IDEMPOTENT FOR THE SAME SHA, REFUSED FOR A DIFFERENT ONE. A receipt whose filename is
  # a version and whose contents are a different commit is worse than no receipt.
  if [ -f "$receipt" ]; then
    prev_commit="$(RCPT="$receipt" python3 -c 'import json,os;print(json.load(open(os.environ["RCPT"])).get("commit",""))' 2>/dev/null || echo '')"
    prev_decision="$(RCPT="$receipt" python3 -c 'import json,os;print(json.load(open(os.environ["RCPT"])).get("decision",""))' 2>/dev/null || echo '')"
    if [ -n "$prev_commit" ] && [ "$prev_commit" != "$commit" ]; then
      if [ "$prev_decision" = RELEASED ]; then
        die "a RELEASED receipt for $version already exists at a different commit ($prev_commit). Bump the version."
      fi
      # A REFUSED RECEIPT IS NOT IMMUTABLE — it is the record of an attempt, and the whole
      # point of a refusal is that you fix the thing and try again at a new commit. Guarding
      # it made the tool refuse its own second run and demand a version bump for a defect
      # that was never released. Found by using it: the first real run refused (a fabricated
      # timestamp, correctly caught), and the fixed re-run could then never proceed.
      # The superseded refusal is KEPT, not overwritten. Evidence of what failed is the
      # reason this tool exists.
      mv "$receipt" "$RECEIPT_DIR/$version.refused-$(printf '%s' "$prev_commit" | cut -c1-7).json"
      rm -f "$receipt_md"
      say "  superseding a REFUSED receipt from $prev_commit (kept alongside)"
    fi
  fi

  RCPT_JSON="$receipt" RCPT_MD="$receipt_md" \
  R_VERSION="$version" R_COMMIT="$commit" R_SCF="$scfver" R_ROLE="$role" R_SLUG="$slug" \
  R_ART_STATUS="$art_status" R_ART_NAME="$art_name" R_ART_SHA="$art_sha" \
  R_PASS="$N_PASS" R_FAIL="$N_FAIL" R_BLOCKED="$N_BLOCKED" R_DECISION="$decision" \
  R_CI_JSON="$ci_json" R_CI_AGG="$ci_agg" R_SBOM="$sbom_file" R_SBOM_SHA="$sbom_sha" R_GATES="$GATE_JSON" \
  R_MANIFESTS="$(for f in version .scaffold-version pyproject.toml AGENTS.md; do
                   [ -f "$f" ] && printf '%s\t%s\n' "$f" "$(sha256_of "$f")"; done)" \
  python3 - <<'PY'
import json, os, platform, subprocess, sys, datetime

def env(k, d=""): return os.environ.get(k, d)

gates = []
for line in env("R_GATES").splitlines():
    if not line.strip(): continue
    parts = line.split("\t")
    if len(parts) < 4: continue
    gates.append({"label": parts[0], "command": parts[1],
                  "exit": int(parts[2]), "verdict": parts[3]})

manifests = {}
for line in env("R_MANIFESTS").splitlines():
    if not line.strip(): continue
    p, h = line.split("\t", 1)
    manifests[p] = h

def cmd(*a):
    try:
        return subprocess.run(a, capture_output=True, text=True, timeout=10).stdout.strip()
    except Exception:
        return "unavailable"

# THE VERDICT IS NOT RECOMPUTED HERE. ci_verdict() above owns the rule; this only records
# the rows it was computed from, so the aggregate can always be checked against its input.
try:
    runs = json.loads(os.environ.get("R_CI_JSON") or "[]")
except Exception:
    runs = []
ci = {"conclusion": os.environ.get("R_CI_AGG") or "CI_UNVERIFIED",
      "runs": [{"workflow": r.get("workflowName"), "status": r.get("status"),
                "conclusion": r.get("conclusion"), "run_id": r.get("databaseId"),
                "url": r.get("url")} for r in runs]}

receipt = {
    "schema": "scaffold.release-receipt/1",
    "generated_utc": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "repo": env("R_SLUG") or "unknown",
    "role": env("R_ROLE"),
    "version": env("R_VERSION"),
    "commit": env("R_COMMIT"),
    "scaffold_version": env("R_SCF"),
    "decision": env("R_DECISION"),
    "gates": gates,
    "counts": {"pass": int(env("R_PASS", "0")),
               "fail": int(env("R_FAIL", "0")),
               "blocked": int(env("R_BLOCKED", "0"))},
    "artifact": {"status": env("R_ART_STATUS"),
                 "name": env("R_ART_NAME"),
                 "sha256": env("R_ART_SHA"),
                 "sbom": ({"name": env("R_SBOM"), "sha256": env("R_SBOM_SHA")}
                          if env("R_SBOM") else None)},
    "manifests": manifests,
    "ci": ci,
    "environment": {
        "platform": platform.platform(),
        "machine": platform.machine(),
        "python": platform.python_version(),
        "shell": os.environ.get("BASH_VERSION", cmd("bash", "--version").splitlines()[0] if cmd("bash", "--version") else "unknown"),
        "git": cmd("git", "--version"),
    },
}
with open(env("RCPT_JSON"), "w") as fh:
    json.dump(receipt, fh, indent=2, sort_keys=True)
    fh.write("\n")

L = []
L.append("# Release receipt — %s" % receipt["version"])
L.append("")
L.append("**%s**  ·  commit `%s`  ·  generated %s" % (receipt["decision"], receipt["commit"][:12], receipt["generated_utc"]))
L.append("")
L.append("A tag records that someone typed a version. This records what was checked.")
L.append("")
L.append("| gate | exit | verdict |")
L.append("|---|---|---|")
for g in gates:
    L.append("| %s | %d | %s |" % (g["label"], g["exit"], g["verdict"]))
L.append("")
L.append("- **counts** — %(pass)d pass, %(fail)d fail, %(blocked)d blocked" % receipt["counts"])
L.append("- **artifact** — %s %s %s" % (receipt["artifact"]["status"], receipt["artifact"]["name"], receipt["artifact"]["sha256"]))
if receipt["artifact"].get("sbom"):
    L.append("- **SBOM** — `%s` sha256 `%s`" % (receipt["artifact"]["sbom"]["name"],
                                                receipt["artifact"]["sbom"]["sha256"]))
L.append("- **CI** — %s (%d run(s): %s)" % (receipt["ci"]["conclusion"], len(ci["runs"]),
         ", ".join("%s=%s" % (r["workflow"], r["conclusion"]) for r in ci["runs"]) or "none"))
L.append("- **platform** — %s, python %s, %s" % (receipt["environment"]["platform"], receipt["environment"]["python"], receipt["environment"]["git"]))
L.append("")
L.append("Manifest hashes (sha256):")
L.append("")
for p in sorted(manifests):
    L.append("- `%s` — `%s`" % (p, manifests[p]))
L.append("")
with open(env("RCPT_MD"), "w") as fh:
    fh.write("\n".join(L))
PY

  say "  receipt: $receipt"

  if [ "$decision" = REFUSED ]; then
    say ""
    say "RELEASE REFUSED — $N_FAIL failed, $N_BLOCKED blocked. No tag was created."
    say "A blocked gate is not a pass. The receipt records exactly which one."
    return 1
  fi

  if [ "$decision" = DRY_RUN ]; then
    say ""
    say "DRY RUN — all gates passed and the receipt is written. No tag was created,"
    say "and the receipt is NOT immutable: re-run without --dry-run to cut the release."
    return 0
  fi

  # ---- THE TAG, LAST. It exists only if everything above did.
  if git rev-parse -q --verify "refs/tags/$version" >/dev/null 2>&1; then
    say "  tag $version already exists — leaving it alone"
  else
    # THE TAG MESSAGE IS THE RELEASE HEADLINE, NOT THE VERSION AGAIN. `-m "$version"`
    # produced a CHANGELOG.md whose every entry was its own heading. The commit subject is
    # already the headline somebody wrote deliberately.
    local _tagmsg; _tagmsg="$(git log -1 --format=%s)"
    [ -n "$_tagmsg" ] || _tagmsg="$version"
    git tag -a "$version" -m "$_tagmsg" && say "  tagged $version"
  fi

  if [ "$PUBLISH" -eq 1 ]; then
    # THE TREE MANIFEST IS BUILT BEFORE ANYTHING LEAVES (report item 15). It is what the
    # tag's tarball must unpack to, so scaffold_upgrade.sh and context_survival.sh can
    # refuse a tree that differs -- a tag moved after release, a corrupted download. Built
    # from the tag itself, before the push, so a failure here publishes nothing.
    local sums_dir
    sums_dir="$(mktemp -d "${TMPDIR:-/tmp}/release_sums.XXXXXX")" || { say "  [FAIL] mktemp failed -- nothing was published"; exit 1; }
    mkdir "$sums_dir/tree"
    if ! { git archive "$version" > "$sums_dir/t.tar" \
           && tar -x -C "$sums_dir/tree" -f "$sums_dir/t.tar" \
           && scaffold_sums make "$sums_dir/tree" > "$sums_dir/SHA256SUMS" \
           && [ -s "$sums_dir/SHA256SUMS" ]; }; then
      say "  [FAIL] could not build SHA256SUMS for $version -- nothing was published"
      exit 1
    fi
    # THE TAG GOES OUT BEFORE THE CHANGELOG COMMIT, AND THROUGH THE HOOK. This used to skip
    # the hook, because by then HEAD was the changelog commit and pre-push's receipt (a
    # preflight pass for HEAD) no longer matched. That was a gate bypass inside the tool
    # that is supposed to be the strictest gate there is, where no guard can see it. Pushed
    # now, HEAD is still the commit preflight just passed, so the receipt matches and the
    # hook is instant. If the hook refuses, the release stops here.
    git push -q origin "$version" && say "  pushed tag $version" \
      || { say "  [FAIL] the tag push was refused -- nothing was published"; exit 1; }
    if command -v gh >/dev/null 2>&1 && [ -n "$slug" ]; then
      # THE RECEIPT IS THE RELEASE ASSET. It cannot be committed into the tree it
      # describes -- the commit that added it would have a different SHA than the one it
      # records -- so the release is where it becomes immutable and fetchable.
      gh release create "$version" --repo "$slug" --title "$version" \
         --notes-file "$receipt_md" "$receipt" "$sums_dir/SHA256SUMS" ${sbom_file:+"$sbom_file"} >/dev/null \
         && say "  GitHub release created, receipt, SHA256SUMS${sbom_file:+ and SBOM} attached"
    fi
  fi

  # ---- THE CHANGELOG, WRITTEN NOW SO THE NEXT COMMIT IS NOT RED (#282).
  #
  # `changelog.sh --check` already tolerates the release moment: HEAD carries a tag the file
  # predates, which is unavoidable -- a changelog cannot name the tag its own commit is about
  # to receive. But THAT TOLERANCE IS EXACTLY ONE COMMIT WIDE. It closes the instant anything
  # else is committed, and then the gate is red for a reason nobody caused.
  #
  # MEASURED 2026-09-01: three releases in one session, three `[FAIL] CHANGELOG.md matches the
  # tags`, three `chore(changelog)` commits whose message says nothing a reader needs. A gate
  # that fires predictably after a normal action, with a fixed one-command remedy and no
  # decision attached, is one people learn to clear on autopilot -- and then they clear it on
  # the day it was telling them something.
  #
  # SO THE TOOL DOES ITS OWN TIDYING. The file's own header says it is generated and must not
  # be hand-edited, so there is no judgement here to take away from anyone. It is committed
  # and NOT pushed: pushing a branch is the releaser's call, and the tag push above carries
  # the objects it needs either way.
  #
  # NEVER ON main. TEAM.md says branch and PR in every repository, and this commit landed on
  # local main after every release, where the next `git push` either carried it past review
  # or had to be unpicked by hand (0.111.0, 2026-09-22). On a protected branch it goes on
  # chore/changelog-<version>, and the releaser is left on that branch to push and PR it.
  if [ -x tools/changelog.sh ]; then
    tools/changelog.sh --write >/dev/null 2>&1 || true
    if [ -n "$(git status --porcelain -- CHANGELOG.md)" ]; then
      case "$(git symbolic-ref --short -q HEAD 2>/dev/null)" in
        main|master) git switch -q -c "chore/changelog-$version" ;;
      esac
      git add -- CHANGELOG.md
      git -c commit.gpgsign=false commit -q -m "chore(changelog): $version" \
        -m "Generated by tools/changelog.sh --write from the annotated tags, by
tools/release.sh, so the next commit does not land on a red changelog gate. Not hand-edited."
      say "  CHANGELOG.md regenerated and committed (not pushed) on $(git symbolic-ref --short -q HEAD) — push it and open a PR"
    fi
  fi

  say ""
  say "RELEASED $version — $N_PASS gate(s) passed, receipt at $receipt"
  return 0
}

# ---------------------------------------------------------------- selftest
# EVERY CASE HERE IS A NEGATIVE ONE unless stated. A release tool that has only been seen
# to succeed has not been tested at all: the whole claim is that it REFUSES.
fixture() {  # fixture <dir> <preflight-exit>
  local d="$1" rc="$2"
  mkdir -p "$d/tools"
  git init -q "$d"
  printf '1.0.0.20260818.0900\n' > "$d/version"
  printf '1.0.0.20260818.0900\n' > "$d/.scaffold-version"
  printf '.r/\n' > "$d/.gitignore"
  printf '#!/usr/bin/env bash\necho "stub preflight"\nexit %s\n' "$rc" > "$d/tools/preflight.sh"
  chmod +x "$d/tools/preflight.sh"
  # THE REAL changelog.sh, NOT A STUB. The behaviour under test (#282) is that a release
  # leaves the file matching the tags, and a stub that writes a fixed string would pass
  # while proving nothing about the tool that actually has to agree with it.
  cp "$(dirname "$SELF")/changelog.sh" "$d/tools/changelog.sh" 2>/dev/null || true
  chmod +x "$d/tools/changelog.sh" 2>/dev/null || true
  git -C "$d" add -A
  git -C "$d" -c user.email=t@t -c user.name=t commit -qm init
}

selftest() {
  local d fails=0 rc out
  # A FIXTURE MUST NOT DEPEND ON THE MACHINE'S GIT CONFIG (#250). The fixtures below create
  # their commits with an inline `-c user.email=...`, but the SCRIPT UNDER TEST then runs
  # bare git commands -- `git tag -a` needs a committer identity of its own and inherits
  # nothing. On a machine whose identity is configured PER-REPOSITORY rather than globally
  # (an ordinary, careful setup when one machine commits under several identities) the tag
  # was never created and the assertion failed. Nothing in the scaffold says a global
  # identity is required, so the fixture supplies one to its children instead of assuming.
  # Exported, not `git -c`, precisely because the child process is the one that needs it.
  export GIT_AUTHOR_NAME="${GIT_AUTHOR_NAME:-scaffold-selftest}"
  export GIT_AUTHOR_EMAIL="${GIT_AUTHOR_EMAIL:-selftest@invalid}"
  export GIT_COMMITTER_NAME="${GIT_COMMITTER_NAME:-scaffold-selftest}"
  export GIT_COMMITTER_EMAIL="${GIT_COMMITTER_EMAIL:-selftest@invalid}"
  # FIXTURES RUN INSIDE A GUARDED ROOT (tools/fixture_guard.sh). Later mktemps land inside it,
  # and a git on PATH refuses any write outside it. The guard exists because a failed mktemp
  # once let a selftest run git init and commit in the real repo.
  . "$(dirname "${BASH_SOURCE[0]}")/fixture_guard.sh" || { echo "release: tools/fixture_guard.sh is missing; refusing to build fixtures" >&2; exit 1; }
  fixture_root FG_ROOT; trap fg_cleanup EXIT
  d="$(mktemp -d "${TMPDIR:-/tmp}/release-selftest.XXXXXX")" || { echo "release: mktemp failed; stopping" >&2; exit 1; }

  # 1. A FAILING GATE MUST REFUSE. This is the case P0-8 exists for.
  fixture "$d/fail" 1
  set +e; out="$(cd "$d/fail" && RELEASE_RECEIPT_DIR=.r "$SELF" --dry-run 2>&1)"; rc=$?; set -e
  if [ "$rc" -ne 0 ]; then say "  ok   a failed gate refuses the release"
  else say "  FAIL a failed gate released"; fails=1; fi
  case "$out" in *"RELEASE REFUSED"*) : ;; *) say "  FAIL the refusal was not stated"; fails=1 ;; esac

  # 2. A BLOCKED GATE MUST ALSO REFUSE. "I could not check" is not "I checked".
  fixture "$d/blocked" 3
  set +e; out="$(cd "$d/blocked" && RELEASE_RECEIPT_DIR=.r "$SELF" --dry-run 2>&1)"; rc=$?; set -e
  if [ "$rc" -ne 0 ]; then say "  ok   a BLOCKED gate refuses the release, same as a failure"
  else say "  FAIL a blocked gate released — exit 3 was treated as a pass"; fails=1; fi

  # 3. THE HAPPY PATH, or every case above proves only that it always refuses.
  fixture "$d/pass" 0
  set +e; out="$(cd "$d/pass" && RELEASE_RECEIPT_DIR=.r "$SELF" --dry-run 2>&1)"; rc=$?; set -e
  if [ "$rc" -eq 0 ]; then say "  ok   an all-green tree is released"
  else say "  FAIL an all-green tree was refused: $out"; fails=1; fi

  # 4. THE RECEIPT EXISTS AND NAMES THE COMMIT, in both outcomes.
  if [ -f "$d/pass/.r/1.0.0.20260818.0900.json" ] && [ -f "$d/fail/.r/1.0.0.20260818.0900.json" ]; then
    say "  ok   a receipt is written for a refusal as well as a release"
  else
    say "  FAIL no receipt for one of the outcomes"; fails=1
  fi
  if RCP="$d/fail/.r/1.0.0.20260818.0900.json" python3 -c 'import json,os,sys; r=json.load(open(os.environ["RCP"])); sys.exit(0 if r["decision"]=="REFUSED" and r["counts"]["fail"]==1 else 1)'; then
    say "  ok   the receipt records the refusal and the failing count"
  else
    say "  FAIL the receipt does not record the refusal"; fails=1
  fi

  # 4b. THE CHANGELOG IS CURRENT AFTER A RELEASE, AND STAYS CURRENT ONE COMMIT LATER (#282).
  #
  # `changelog.sh --check` tolerates HEAD carrying a tag the file predates -- it must, since a
  # changelog cannot name the tag its own commit is about to receive. THAT TOLERANCE IS ONE
  # COMMIT WIDE, and the second assertion here is the one that would have caught the real
  # problem: three releases in one session, three red gates on the very next commit.

  # 5. NO TAG MAY EXIST FOR A REFUSED RELEASE.
  set +e; out="$(cd "$d/fail" && RELEASE_RECEIPT_DIR=.r "$SELF" 2>&1)"; set -e
  if [ -z "$(git -C "$d/fail" tag -l)" ]; then say "  ok   a refused release creates no tag"
  else say "  FAIL a tag exists for a release that was refused"; fails=1; fi

  # 6. AND A TAG DOES EXIST FOR A REAL ONE, or case 5 proves nothing.
  set +e; out="$(cd "$d/pass" && RELEASE_RECEIPT_DIR=.r "$SELF" 2>&1)"; set -e
  if [ "$(git -C "$d/pass" tag -l)" = "1.0.0.20260818.0900" ]; then
    say "  ok   a passed release creates the tag"
  else
    say "  FAIL no tag after a successful release"; fails=1
  fi

  # 6b. AND THE CHANGELOG IS CURRENT AFTER IT, AND STILL CURRENT ONE COMMIT LATER (#282).
  if ( cd "$d/pass" && tools/changelog.sh --check >/dev/null 2>&1 ); then
    say "  ok   the changelog is current immediately after a release"
  else
    say "  FAIL the changelog is stale the moment the release finishes"; fails=1
  fi
  # THE ASSERTION THAT WOULD HAVE CAUGHT THE REAL PROBLEM. The one-commit tolerance in
  # changelog.sh --check hides staleness until anything else is committed, which is the
  # normal next action and is where it went red three times in one session.
  printf 'x\n' >> "$d/pass/version.note"
  git -C "$d/pass" add -A
  git -C "$d/pass" commit -qm "chore: an ordinary commit after a release"
  if ( cd "$d/pass" && tools/changelog.sh --check >/dev/null 2>&1 ); then
    say "  ok   ...and still current after the next ordinary commit"
  else
    say "  FAIL the changelog goes red on the first commit after a release"; fails=1
  fi

  # 6c. --publish GOES THROUGH THE HOOK AND LEAVES main ALONE. A local bare remote, and a
  #     pre-push hook that records that it ran. The tag push skipped the hook until
  #     2026-09-23, and the changelog commit landed on local main after every release.
  local v=1.0.0.20260818.0900 h
  for h in 0 1; do
    fixture "$d/pub$h" 0
    git -C "$d/pub$h" branch -M main
    git init -q --bare "$d/remote$h.git"
    git -C "$d/pub$h" remote add origin "$d/remote$h.git"
    printf '#!/bin/sh\necho ran >> "%s"\nexit %s\n' "$d/hookran$h" "$h" > "$d/pub$h/.git/hooks/pre-push"
    chmod +x "$d/pub$h/.git/hooks/pre-push"
    set +e; out="$(cd "$d/pub$h" && RELEASE_RECEIPT_DIR=.r "$SELF" --publish 2>&1)"; rc=$?; set -e
    if [ "$h" = "0" ]; then
      if [ -s "$d/hookran0" ] && [ "$(git -C "$d/remote0.git" tag -l)" = "$v" ]; then
        say "  ok   --publish pushes the tag THROUGH the pre-push hook"
      else say "  FAIL the tag push skipped the hook or did not arrive (rc $rc): $out"; fails=1; fi
      if [ "$(git -C "$d/pub0" rev-parse main)" = "$(git -C "$d/pub0" rev-parse "$v^{commit}")" ] \
         && [ "$(git -C "$d/pub0" symbolic-ref --short HEAD)" = "chore/changelog-$v" ]; then
        say "  ok   ...main stays at the tag, and the changelog commit is on chore/changelog-$v"
      else say "  FAIL the changelog commit moved main or is not on its own branch"; fails=1; fi
    else
      if [ "$rc" -ne 0 ] && [ -z "$(git -C "$d/remote1.git" tag -l)" ]; then
        say "  ok   a hook that refuses the tag push stops the release"
      else say "  FAIL a refused tag push was reported as a release (rc $rc)"; fails=1; fi
    fi
  done

  # 7. A RECEIPT MUST NOT BE OVERWRITTEN FOR A DIFFERENT SHA.
  printf 'x\n' >> "$d/pass/version.note"
  git -C "$d/pass" add -A
  git -C "$d/pass" -c user.email=t@t -c user.name=t commit -qm second
  set +e; out="$(cd "$d/pass" && RELEASE_RECEIPT_DIR=.r "$SELF" --dry-run 2>&1)"; rc=$?; set -e
  if [ "$rc" -ne 0 ]; then say "  ok   a RELEASED receipt is not overwritten for a different commit"
  else say "  FAIL a released receipt was silently rewritten at another SHA"; fails=1; fi

  # 8. A DIRTY TREE IS A REFUSAL, AND IT IS EXIT 3 — nothing failed, nothing was checked.
  fixture "$d/dirty" 0
  printf 'y\n' > "$d/dirty/loose"
  set +e; out="$(cd "$d/dirty" && RELEASE_RECEIPT_DIR=.r "$SELF" --dry-run 2>&1)"; rc=$?; set -e
  if [ "$rc" -eq 3 ]; then say "  ok   a dirty tree is exit 3, not a failure and not a pass"
  else say "  FAIL a dirty tree returned $rc"; fails=1; fi

  # 9. THE PIPEFAIL TRAP ITSELF. A gate that fails while its output is formatted must still
  #    fail. This is the defect P0-8 names: `gate | sed` reports sed.
  set +e
  ( set -o pipefail 2>/dev/null; false | sed 's/x/y/' ) ; rc=$?
  set -e
  if [ "$rc" -ne 0 ]; then
    say "  ok   this shell honours pipefail, so the no-pipe rule is belt and braces"
  else
    say "  ok   this shell drops pipefail in a subshell — which is exactly why run_gate pipes nothing"
  fi

  # 10. AND THE RULE IS CHECKED IN THE SOURCE, not just believed.
  if grep -nE '^\s*(run_gate|"\$@")[^|]*\|' "$SELF" | grep -v 'tail -20' >/dev/null 2>&1; then
    say "  FAIL a gate is piped somewhere in this file"; fails=1
  else
    say "  ok   no gate invocation in this file is piped into anything"
  fi

  # 11. A REFUSED RECEIPT MUST NOT BLOCK THE FIXED RE-RUN, and must not be destroyed either.
  fixture "$d/retry" 1
  set +e; ( cd "$d/retry" && RELEASE_RECEIPT_DIR=.r "$SELF" --dry-run >/dev/null 2>&1 ); set -e
  printf '#!/usr/bin/env bash\necho fixed\nexit 0\n' > "$d/retry/tools/preflight.sh"
  chmod +x "$d/retry/tools/preflight.sh"
  git -C "$d/retry" add -A
  git -C "$d/retry" -c user.email=t@t -c user.name=t commit -qm fix
  set +e; out="$(cd "$d/retry" && RELEASE_RECEIPT_DIR=.r "$SELF" --dry-run 2>&1)"; rc=$?; set -e
  if [ "$rc" -eq 0 ]; then say "  ok   a REFUSED receipt does not block the fixed re-run"
  else say "  FAIL the fixed re-run was blocked by its own earlier refusal"; fails=1; fi
  if ls "$d/retry"/.r/*.refused-*.json >/dev/null 2>&1; then
    say "  ok   the superseded refusal is kept, not overwritten"
  else
    say "  FAIL the refusal was destroyed — the evidence of what failed is gone"; fails=1
  fi

  # 12. A RELEASED RECEIPT IS STILL IMMUTABLE. Case 11 must not have opened that door.
  #     A REAL release, not a dry one: a dry run is decision DRY_RUN and deliberately does
  #     not lock the version, so running it here would assert nothing.
  set +e; ( cd "$d/retry" && RELEASE_RECEIPT_DIR=.r "$SELF" >/dev/null 2>&1 ); set -e
  printf 'z\n' > "$d/retry/another"
  git -C "$d/retry" add -A
  git -C "$d/retry" -c user.email=t@t -c user.name=t commit -qm third
  set +e; out="$(cd "$d/retry" && RELEASE_RECEIPT_DIR=.r "$SELF" --dry-run 2>&1)"; rc=$?; set -e
  case "$out" in
    *"RELEASED receipt for"*) say "  ok   a RELEASED receipt is still immutable at another commit" ;;
    *) say "  FAIL a released receipt was rewritten at a different commit"; fails=1 ;;
  esac

  # 13. A DRY RUN MUST NOT LOCK THE VERSION. It released nothing.
  fixture "$d/dry" 0
  set +e; ( cd "$d/dry" && RELEASE_RECEIPT_DIR=.r "$SELF" --dry-run >/dev/null 2>&1 ); set -e
  printf 'q\n' > "$d/dry/more"
  git -C "$d/dry" add -A
  git -C "$d/dry" -c user.email=t@t -c user.name=t commit -qm amend
  set +e; out="$(cd "$d/dry" && RELEASE_RECEIPT_DIR=.r "$SELF" --dry-run 2>&1)"; rc=$?; set -e
  if [ "$rc" -eq 0 ]; then say "  ok   a dry run does not lock the version against the real release"
  else say "  FAIL a dry run locked the version: $out"; fails=1; fi

  # 14. THE CI VERDICT, ON THE REAL FUNCTION. This is the one piece of the receipt that
  #     can state a falsehood rather than merely omit a truth.
  local v
  v="$(printf '%s' '[{"workflowName":"Mirror","status":"completed","conclusion":"success"},{"workflowName":"Scaffold Check","status":"completed","conclusion":"failure"}]' | "$SELF" --ci-verdict)"
  if [ "$v" = failure ]; then
    say "  ok   a green mirror does not launder a red test suite"
  else
    say "  FAIL a failing workflow was reported as '$v'"; fails=1
  fi
  v="$(printf '%s' '[{"workflowName":"Scaffold Check","status":"in_progress","conclusion":null}]' | "$SELF" --ci-verdict)"
  if [ "$v" = CI_UNVERIFIED ]; then
    say "  ok   a run still in progress is UNVERIFIED, never a pass"
  else
    say "  FAIL an unfinished run was reported as '$v'"; fails=1
  fi
  v="$(printf '%s' '[]' | "$SELF" --ci-verdict)"
  [ "$v" = CI_UNVERIFIED ] || { say "  FAIL no runs at all reported as '$v'"; fails=1; }
  v="$(printf '%s' '[{"workflowName":"A","status":"completed","conclusion":"success"},{"workflowName":"B","status":"completed","conclusion":"success"}]' | "$SELF" --ci-verdict)"
  if [ "$v" = success ]; then
    say "  ok   every run green is the only way to earn success"
  else
    say "  FAIL an all-green commit was reported as '$v'"; fails=1
  fi

  rm -rf "$d"
  # NO COUNT, BECAUSE A HAND-MAINTAINED COUNT IS A SECOND DEFINITION THAT DRIFTS. This line
  # said 19/19 while the suite ran 21 — the same defect localcoder_history.py documents in its
  # own harness, and the same shape as a doc claiming 23 checks against an actual 46. The
  # suite already knows whether anything failed; the number added nothing and was wrong.
  if [ "$fails" -eq 0 ]; then say "release: all selftests passed"; return 0; fi
  say "release: selftest FAILED" >&2; return 1
}

case "$MODE" in
  selftest)   selftest ;;
  ci_verdict) ci_verdict ;;
  release)    do_release ;;
esac
