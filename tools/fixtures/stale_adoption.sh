#!/usr/bin/env bash
# Project:  ai-project-scaffold
# File:     tools/fixtures/stale_adoption.sh
# Modified: 2026-09-23
# Version:  0.1.3.20260923.0941
# Purpose:  The shape that found five defects in one day — a pre-tools/ adoption with a
#           legacy CLAUDE.md symlink, a camelCase codebase and a build tool that rewrites
#           tracked files — rebuilt synthetically so it stops being an anecdote.
# Changelog:
#   2026-09-23 v0.1.3.20260923.0941 — fixtures run inside the root tools/fixture_guard.sh validates. There a git and a mktemp on PATH refuse anything that would land outside it. Every mktemp takes a ${TMPDIR} template, because macOS mktemp ignores TMPDIR without one.
#   2026-09-23 v0.1.2.20260923.0843 — every mktemp fails closed. A failed one left the temp variable empty, so the fixture ran in the caller's directory; header_check's committed into Robiton/control.
#   2026-09-06 v0.1.1.20260906.0554 — Dropped a manufactured issue citation. "Initial (#307)" pointed at
#                        a number that was never filed; the WHY section below already says
#                        why this exists, so the citation was inventing a reference rather
#                        than making one.
#   2026-09-04 v0.1.0.20260904.0938 — Initial. The stale-adoption shape, rebuilt synthetically; see WHY THIS EXISTS below. No issue: this fixture records a shape, not a defect with a fix.
#
# WHY THIS EXISTS.
#
# On 2026-09-04 three sessions ran the adoption guide against real repositories and found
# ten defects. Nine of them were invisible to every gate in this repository, and five came
# from ONE repo whose shape nothing here reproduced: an adoption predating tools/, still
# carrying the <=v0.3.0 CLAUDE.md symlink, in a camelCase codebase, with a directory a build
# tool regenerates. Each of those properties found something.
#
# That repo is a private application. This file rebuilds the SHAPE with none of its content.
#
# WHAT IT IS NOT. It is not part of adoption_check.sh, deliberately: that file builds its
# fixture from the CURRENT repo and inherits its state, which is its own open defect. This
# one owns its tree from the first commit, because two of the six properties need real git
# history and one needs a change with NO commit behind it.
#
# Needs no network and no Ollama. Runs on either runner.
set -u

SELF="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SELF/../.." && pwd)"
# FIXTURES RUN INSIDE A GUARDED ROOT (tools/fixture_guard.sh). Later mktemps land inside it,
# and a git on PATH refuses any write outside it. The guard exists because a failed mktemp
# once let a selftest run git init and commit in the real repo.
. "$SELF/../fixture_guard.sh" || { echo "stale_adoption: tools/fixture_guard.sh is missing; refusing to build fixtures" >&2; exit 1; }
fixture_root FG_ROOT; trap fg_cleanup EXIT
pass=0; fail=0; red=0
ok()   { printf '  ok    %s\n' "$1"; pass=$((pass + 1)); }
bad()  { printf '  FAIL  %s\n' "$1"; fail=$((fail + 1)); }
# A case that is EXPECTED to be red, with a stated reason. See property 6.
open_() { printf '  OPEN  %s\n' "$1"; red=$((red + 1)); }

git_q() { git -c user.email=f@f -c user.name=f -c commit.gpgsign=false "$@"; }

# ---------------------------------------------------------------- build the tree
build() {
  local d="$1"
  mkdir -p "$d"/{ai,src,vendor_generated}
  ( cd "$d" && git init -q . )

  # --- property 1: a PRE-tools/ ADOPTION. The eight ai/ files of that era and nothing else.
  # No .scaffold-version, no tools/, no .githooks/, no .agents/, no .claude/. This is what
  # an adoption that stopped receiving updates actually looks like, and neither of the
  # guide's other two modes fits it: fresh adoption starts by overwriting ai/, and
  # --upgrade needs a .scaffold-version that is not there.
  local f
  for f in STANDARDS CODING SECURITY PLANNING BACKLOG SESSION MEMORY TEAM; do
    printf '# %s\n\nSynthetic fixture content the adopter would own.\n' "$f" > "$d/ai/$f.md"
  done

  # --- property 2: the <=v0.3.0 AGENTS.md, WITH the instruction that recreates the symlink.
  # The instruction is the fifth site: AGENTS.md is a MERGE file, so it survives upgrades
  # indefinitely and an adopter following their own file walks back into the truncation.
  cat > "$d/AGENTS.md" <<'AGENTSEOF'
# AI Context Bootstrap

Read ai/STANDARDS.md and load all files in the order it specifies.

CLAUDE.md is a symlink to this file for Claude Code compatibility.
If CLAUDE.md does not exist, run `./setup.sh` or create it manually:

    ln -s AGENTS.md CLAUDE.md

PROJECT CONTENT BELOW THAT MUST SURVIVE ANY MIGRATION.
AGENTSEOF
  ( cd "$d" && ln -s AGENTS.md CLAUDE.md )

  # --- property 3: CLAUDE.md ALSO gitignored. Same era, and the two interact — the ignore
  # rule is why CLAUDE.md never reaches a fresh clone, which is the failure that matters.
  printf 'CLAUDE.md\nnode_modules/\n' > "$d/.gitignore"

  # --- property 5: a camelCase codebase. This is what defeated REFERENCE_NAME, which
  # required a literal leading underscore and so only ever fired on snake_case.
  cat > "$d/src/billing.js" <<'JSEOF'
const svc = {};
svc._tokenUrl = '/functions/exchange-token';
svc.token_url = '/functions/exchange-token';
let offerToken = productIdAndOfferIndexArray[1];
const ERR_MISSING_TOKEN = ERROR_CODES_BASE + 16;
JSEOF
  # THE GUARD RAIL, and it is the whole reason the camelCase case is safe to assert. A
  # widening that suppresses the four lines above must still fail this one.
  printf 'API_KEY=sk_live_abcd1234efgh5678ijkl\n' > "$d/src/.env.sample"  # scaffold:not-a-secret

  # --- property 4, first half: files whose LAST COMMIT genuinely predates the baseline.
  # Backdated for real, because the amnesty compares committer dates and a fixture that
  # squashes cannot discriminate — which was itself a defect (#305).
  printf '#!/bin/sh\necho legacy-one\n' > "$d/legacy_one.sh"
  printf '#!/bin/sh\necho legacy-two\n' > "$d/legacy_two.sh"
  ( cd "$d" && git add -A \
      && GIT_AUTHOR_DATE='2025-01-02T00:00:00' GIT_COMMITTER_DATE='2025-01-02T00:00:00' \
         git_q commit -qm 'the project, before it adopted anything' )

  # --- property 4, second half: a file committed AFTER the baseline. Without this the
  # suite passes while broken — a regression that exempts EVERYTHING satisfies both the
  # "legacy is exempt" case and the "single commit is NOT MEASURED" case. Same guard-rail
  # logic as the unquoted key above. Raised by the session that reported the original bug.
  printf '#!/bin/sh\necho written-today\n' > "$d/written_today.sh"
  ( cd "$d" && git add -A && git_q commit -qm 'work done after the baseline' )

  # --- property 6: a TRACKED directory that a build tool regenerates. Simulates
  # `npx cap sync`. The regenerator discards whatever is in the directory, so anything
  # written there — including a scaffold: marker satisfying a gate — evaporates.
  printf 'generated, do not edit\n' > "$d/vendor_generated/Plugin.java"
  cat > "$d/regenerate.sh" <<'REGENEOF'
#!/bin/sh
# stands in for `npx cap sync`: rewrites the directory from a template, discarding edits
rm -rf vendor_generated && mkdir -p vendor_generated
printf 'generated, do not edit\n' > vendor_generated/Plugin.java
REGENEOF
  chmod +x "$d/regenerate.sh"
  ( cd "$d" && git add -A && git_q commit -qm 'vendored generated output' )
}

run() {
  local d; d="$(mktemp -d "${TMPDIR:-/tmp}/stale_adoption.XXXXXX")" || { echo "stale_adoption: mktemp failed; stopping" >&2; exit 1; }; d="$d/stale"
  build "$d"
  echo "stale-adoption fixture — the shape that found five defects on 2026-09-04"
  echo ""

  # ---- 1. it really is the stale shape, or every case below is testing something else.
  local wrong=""
  for f in .scaffold-version tools .githooks .agents .claude; do
    [ -e "$d/$f" ] && wrong="$wrong $f"
  done
  [ -z "$wrong" ] && ok "the fixture is a pre-tools/ adoption (no$( [ -n "$wrong" ] || echo ' .scaffold-version, tools/, .githooks/, .agents/, .claude/'))" \
                  || bad "the fixture is not stale — it already has:$wrong"

  # ---- 2. THE DATA LOSS. Run the pointer command exactly as the guide now writes it and
  # assert AGENTS.md is byte-identical. Unguarded, this truncates 300 bytes to 11.
  local before after
  before="$(shasum -a 256 "$d/AGENTS.md" | cut -d' ' -f1)"
  ( cd "$d" && [ -L CLAUDE.md ] && rm CLAUDE.md; printf '@AGENTS.md\n' > CLAUDE.md )
  after="$(shasum -a 256 "$d/AGENTS.md" | cut -d' ' -f1)"
  [ "$before" = "$after" ] \
    && ok "the guarded pointer command leaves AGENTS.md byte-identical" \
    || bad "AGENTS.md was TRUNCATED by the pointer command — the guard is gone"

  # ...and the unguarded form must still destroy it, or the case above proves nothing.
  ( cd "$d" && rm -f CLAUDE.md && ln -s AGENTS.md CLAUDE.md && printf '@AGENTS.md\n' > CLAUDE.md )
  [ "$(shasum -a 256 "$d/AGENTS.md" | cut -d' ' -f1)" != "$before" ] \
    && ok "...and the UNGUARDED form still destroys it (the guard is what saves you)" \
    || bad "the unguarded form did not truncate — this fixture can no longer detect the bug"
  ( cd "$d" && git checkout -q -- AGENTS.md && rm -f CLAUDE.md && ln -s AGENTS.md CLAUDE.md )

  # ---- 3. the gitignored pointer never reaches a fresh clone. That is the real failure,
  # and testing it by cloning is the only way to see it.
  ( cd "$d" && rm -f CLAUDE.md && printf '@AGENTS.md\n' > CLAUDE.md )
  local c; c="$(mktemp -d "${TMPDIR:-/tmp}/stale_adoption.XXXXXX")" || { echo "stale_adoption: mktemp failed; stopping" >&2; exit 1; }; c="$c/clone"
  git clone -q "$d" "$c" 2>/dev/null
  [ -f "$c/CLAUDE.md" ] \
    && bad "CLAUDE.md reached the clone while gitignored — the fixture lost property 3" \
    || ok "a gitignored CLAUDE.md does NOT reach a fresh clone (the real failure)"

  # ---- 4. the header baseline, all three directions.
  if [ -x "$ROOT/tools/header_check.sh" ]; then
    # VENDOR THE TOOL, do not invoke it across the boundary. header_check.sh cd's to its
    # own directory's parent at load, so running it by absolute path from here scans THE
    # SCAFFOLD and reports 34 clean files — a fixture that tests the wrong repository and
    # says "ok". An adopter vendors tools/; so does this.
    mkdir -p "$d/tools"
    cp "$ROOT/tools/header_check.sh" "$d/tools/"
    chmod +x "$d/tools/header_check.sh"
    printf '<!-- scaffold:header-baseline 2026-06-01 -->\n' >> "$d/ai/STANDARDS.md"
    ( cd "$d" && git add -A && git_q commit -qm 'declare the baseline' ) >/dev/null 2>&1
    local out; out="$( cd "$d" && ./tools/header_check.sh --list-legacy 2>&1 )"
    printf '%s' "$out" | grep -q 'legacy_one.sh' \
      && ok "a file older than the baseline is exempt" \
      || bad "the backdated file was not exempted — the amnesty is broken"
    # THE GUARD RAIL. Without it, a regression exempting EVERYTHING passes both other cases.
    printf '%s' "$out" | grep -qE '\[FAIL\][[:space:]]+written_today\.sh' \
      && ok "...and a file NEWER than the baseline still FAILS (the guard rail)" \
      || bad "a post-baseline file was exempted — the amnesty now covers everything"
    # A squashed copy cannot discriminate and must say NOT MEASURED, never FAIL.
    local sq; sq="$(mktemp -d "${TMPDIR:-/tmp}/stale_adoption.XXXXXX")" || { echo "stale_adoption: mktemp failed; stopping" >&2; exit 1; }; sq="$sq/squashed"
    mkdir -p "$sq" && ( cd "$d" && git archive HEAD ) | ( mkdir -p "$sq" && tar -x -C "$sq" )
    ( cd "$sq" && git init -q . && git add -A && git_q commit -qm one ) >/dev/null 2>&1
    ( cd "$sq" && ./tools/header_check.sh 2>&1 | grep -q 'NOT MEASURED' ) \
      && ok "a single-commit tree reports NOT MEASURED, not FAIL" \
      || bad "a squashed tree failed files it cannot date (#305 is back)"
    rm -rf "$sq"
  fi

  # ---- 5. camelCase suppression, with the credential as the guard rail.
  if [ -x "$ROOT/tools/secret_scan.sh" ]; then
    cp "$ROOT/.gitleaks.toml" "$d/" 2>/dev/null || true
    mkdir -p "$d/tools" && cp "$ROOT/tools/secret_scan.sh" "$d/tools/" && chmod +x "$d/tools/secret_scan.sh"
    ( cd "$d" && git add -A && git_q commit -qm 'scan inputs' ) >/dev/null 2>&1
    local sc; sc="$( cd "$d" && ./tools/secret_scan.sh 2>&1 )"
    printf '%s' "$sc" | grep -q 'billing.js' \
      && bad "a camelCase reference name was reported — REFERENCE_NAME regressed" \
      || ok "camelCase reference names and code expressions are suppressed"
    printf '%s' "$sc" | grep -q '.env.sample' \
      && ok "...and the unquoted API_KEY is still caught (the guard rail)" \
      || bad "the unquoted credential was suppressed — the widening went too far"
  fi

  # ---- 6. A GATE CAN BE UN-SATISFIED WITH NO COMMIT IN BETWEEN, AND NOTHING NOTICES.
  #
  # THIS CASE IS EXPECTED TO BE OPEN. Do not "fix" it by deleting it.
  #
  # The defect is NOT that a generated file can be overwritten. It is that the tree goes
  # from satisfying a gate to not satisfying it WITH NO COMMIT BETWEEN THE TWO STATES — so
  # every mechanism this toolchain has for noticing change is blind to it. header_check
  # --since reads a commit range. preflight's dirty-tree refusal reads the index. The
  # pre-push hook fires on a push. CI runs on commits. All of them are looking at commits,
  # and this happens between them.
  #
  # Anyone whose answer is "run the scanner in CI" has missed that CI also only runs on
  # commits, and the marker is gone before the next one exists.
  ( cd "$d" && printf 'x = 1;  # scaffold:not-a-secret\n' > vendor_generated/Plugin.java \
      && git add -A && git_q commit -qm 'declare the generated file safe' ) >/dev/null 2>&1
  ( cd "$d" && ./regenerate.sh )
  if grep -q 'scaffold:not-a-secret' "$d/vendor_generated/Plugin.java" 2>/dev/null; then
    ok "a marker in a regenerated directory survived its build tool"
  else
    open_ "a build tool silently un-satisfied a gate, with no commit in between"
    echo "        The marker is gone and git shows a dirty file, but nothing in this"
    echo "        toolchain treats 'a declaration disappeared' as an event. Every change"
    echo "        detector we have reads commits; this happens between them."
    echo "        OPEN BY DESIGN — a probe for a defect class, not a regression test."
  fi

  rm -rf "$(dirname "$d")" "$(dirname "$c")"
  echo ""
  echo "  $pass passed, $fail failed, $red open-by-design"
  [ "$fail" -eq 0 ]
}

case "${1:-}" in
  --selftest|"") run ;;
  -h|--help) echo "usage: $0 [--selftest]"; exit 0 ;;
  *) echo "unknown flag: $1" >&2; exit 2 ;;
esac
