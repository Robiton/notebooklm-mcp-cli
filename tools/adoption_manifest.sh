#!/usr/bin/env bash
# Project:  ai-project-scaffold
# File:     tools/adoption_manifest.sh
# Modified: 2026-09-23
# Version:  0.5.2.20260923.0941
# Purpose:  ONE list of what an adoption receives from the scaffold, and a check that the
#           four places which restate that list still agree with it.
# Changelog:
#   2026-09-23 v0.5.2.20260923.0941 — mktemp takes a ${TMPDIR} template. macOS mktemp ignores TMPDIR without one, so a guarded fixture root could not contain it.
#   2026-09-23 v0.5.1.20260923.0843 — every mktemp fails closed. A failed one left the temp variable empty, so the fixture ran in the caller's directory; header_check's committed into Robiton/control.
#   2026-09-09 v0.5.0.20260909.0522 — docs/ IS DELIVERED NOW, and the exemption that hid that goes with it.
#                        The manifest has declared docs/ since it was written and NOTHING ever
#                        copied it: the guide's step 3 did not, the headless path did not, and
#                        both were EXEMPTED here with a reason -- so the check passed while
#                        three real adoptions had no docs/ directory at all. A declared path
#                        that reaches nobody is the exact failure this tool was built for, and
#                        it was carrying a written-down exception for it.
#                        Step 3 copies docs/; the headless path fetches the markdown and skips
#                        the two images and the .docx deliberately. Both exemptions removed,
#                        and the stale-exemption guard fired on the first of them immediately,
#                        which is why the second was found rather than left.
#                        docs/AGENT_RUNBOOK.md is the reason this mattered: it is written so an
#                        AGENT can set up an adoption without reading the 1,200-line guide, and
#                        it reached no adoption.
#                        The selftest fixture restated the same two exemptions and had to move
#                        with them -- a fixture honouring a rule the tool no longer has is a
#                        fixture asserting the old behaviour.
#   2026-09-08 v0.4.0.20260908.0528 — adopt.ps1 joins the manifest. Adding one root file walked
#                        through all FOUR delivery lists in sequence -- upgrade, guide,
#                        headless -- refusing each time until they agreed. That is the
#                        tool doing precisely what it was built for.
#   2026-09-04 v0.3.0.20260904.0710 — BOTH ADOPTION PATHS ARE CHECKED NOW (#303). The guide has two — step 3
#                        clones and copies, "Headless Linux" fetches over gh api for a machine
#                        that cannot clone — and they were maintained as two separate lists.
#                        Measured by EXECUTING the headless block: it never fetched setup.sh at
#                        all, so an SSH-only adopter could not run the ./setup.sh --check that
#                        the same section tells them to run next; it never stripped
#                        scaffold:session-log, so the step-3 fix shipped an hour earlier left
#                        this path still hard-failing exit 4; and .agents/ and .cursor/ were
#                        missing outright. Step 3 was bitten by the setup.sh omission on
#                        2026-08-31 and fixed; the parallel path was never given the line.
#   2026-09-04 v0.2.0.20260904.0558 — THE REVERSE CHECK: what does the scaffold own that nobody declared? (#300)
#                        Everything here checked that DECLARED paths are delivered consistently.
#                        It could not see a file on no list at all — which is exactly how
#                        `.gitleaks.toml` hid. That file was written 2026-08-30 to suppress the
#                        12 synthetic fixtures in tools/secret_scan.sh that every adopter
#                        vendors; its own header records the measurement. It was correct,
#                        argued, committed — and reached NOBODY. Five weeks later a fleet sweep
#                        re-measured the identical 12 findings in eight repositories. Every
#                        tracked root file is now declared or exempted with a reason.
#   2026-09-03 v0.1.1.20260903.1929 — --selftest ASSERTS THE TOOL, NOT THE REPO, and `check` has three outcomes.
#                        The first version mutated a copy of the LIVE tree, so in an adopter
#                        (no docs/ADOPTION_GUIDE.md) `cp` failed and every adopter went red on
#                        the upgrade that delivered this file. The mutations now run against a
#                        synthetic three-file fixture this function builds. `check` returns 3
#                        — NOT MEASURED — where the four restatements it compares do not exist,
#                        which is neither a pass nor a failure. Both rules were already
#                        written down here; the tool that exists to stop lists drifting broke
#                        them on its first release.
#   2026-09-03 v0.1.0.20260903.1853 — Initial (#291, #294, #297). The manifest existed in four
#                        places and no two were checked against each other, so a FRESH
#                        adoption and an UPGRADE delivered different file sets. Found by an
#                        outside reviewer reading a real adoption, not by anything here.
#
# THE FOUR COPIES, and what each one is for:
#
#   1. docs/ADOPTION_GUIDE.md step 3   — what a human copies for a FRESH adoption.
#   2. PRODUCT_FILES / PRODUCT_DIRS_*  — what scaffold_upgrade.sh refreshes on an UPGRADE.
#   3. build.sh (splunk-app overlay)   — what must NOT go into a deployment artifact.
#   4. tools/adoption_check.sh         — what the fixtures build.
#
# Measured drift at 0.88.3, all three found by an external review of one real adoption:
#   - `.githooks/` was in (2) and absent from (1): 18 occurrences vs 0. A fresh adoption
#     never received it and never would until its first upgrade.
#   - build.sh excluded 6 of 20 (#291), so a CORRECTLY BUILT Splunk package shipped tools/,
#     .claude/, .github/ and setup.sh to a production host. The reviewer read that list as
#     "complete and correct" — it excludes ai/, which is what makes it read as considered.
#   - ai/PROVENANCE.md and ai/STANDARDS_EVIDENCE.md were in (1) via `cp -r ai .` (#293).
#
# WHY A SCRIPT AND NOT A DERIVED LIST. Deriving "everything the scaffold owns" from the
# tree would silently start shipping whatever lands in it next, and an inferred list that
# comes back empty stops every adopter receiving anything — the failure mode
# scaffold_upgrade.sh already writes about at PRODUCT_FILES. So: declared here, once, and
# --check asserts the restatements match. Adding a file is one line and one failing check.
set -e

SELF="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SELF/.." && pwd)"

# ---- THE MANIFEST.
#
# Every path an adoption receives FROM the scaffold. Directories end in `/`.
#
# `build.sh` and `.gitignore` are NOT here: both are GENERATED by an overlay from the
# adopter's own answers rather than copied, so neither has an upstream copy to compare
# against. They are still scaffold-owned for exclusion purposes — see BUILD_EXTRA below.
#
# `version` is deliberately absent: that file is the ADOPTER's, and the guide says so.
adoption_manifest() {
  cat <<'EOF'
ai/
AGENTS.md
CLAUDE.md
LICENSE
setup.sh
adopt.ps1
sync-check.sh
tools/
docs/
.agents/
.claude/
.codex
.cursor/
.cursorrules
.editorconfig
.gitattributes
.gitleaks.toml
.githooks/
.github/
.scaffold-version
.windsurfrules
EOF
}

# ---- WHAT A DEPLOYMENT ARTIFACT MUST NOT CONTAIN.
#
# The manifest, plus the two generated files, plus the build artifact itself and the
# ordinary development cruft. A Splunk package is copied onto a production host; every
# path here is repository maintenance and none of it is app runtime.
#
# `local/` and `passwords.conf` are Splunk-specific and not scaffold paths at all: local/
# is per-instance config that must never be packaged, and passwords.conf holds credentials.
BUILD_EXTRA="build.sh .gitignore local output __pycache__ .git .DS_Store passwords.conf"

build_excludes() {
  # One `--exclude` per path, in tar's ${APP_NAME}/ form. Directories lose the trailing
  # slash: tar matches the directory itself, and a trailing slash makes it match nothing.
  { adoption_manifest; printf '%s\n' $BUILD_EXTRA; } \
    | sed 's|/$||' | sort -u \
    | while IFS= read -r p; do
        [ -n "$p" ] || continue
        printf '  --exclude="${APP_NAME}/%s" \\\n' "$p"
      done
  # Globs, which are not paths and so are not in the manifest.
  printf '  --exclude="${APP_NAME}/%s" \\\n' '*.pyc' '*.tar.gz' '*.spl' '._*'
}

# ---- THE CROSS-CHECK.

# ---- THE GUIDE HAS TWO ADOPTION PATHS AND THEY DRIFT (#303).
#
# Step 3 clones the scaffold and copies. The "Headless Linux" section fetches each file over
# `gh api` instead, for a machine that cannot clone. They deliver the same adoption and they
# are maintained as two separate lists — which is this project's most-repeated defect, now
# inside a single document.
#
# Measured, by executing the headless block rather than reading it: it never fetched
# `setup.sh` AT ALL, so a headless adopter could not run the `./setup.sh --check` that the
# same section tells them to run next; it never stripped `scaffold:session-log`, so the fix
# that went into step 3 an hour earlier left this path still hard-failing exit 4; and its
# hand-written ai/ list had gone stale by three files. Step 3 had already been bitten by the
# setup.sh omission on 2026-08-31 and fixed; the parallel path was never given the same line.
#
# So both are checked. A path satisfied by one and not the other is the bug.
headless_paths() {
  sed -n '/^## Headless Linux/,$p' "$ROOT/docs/ADOPTION_GUIDE.md" \
    | sed -n '1,/^## [^H]/p' \
    | grep -oE 'fetch "[^"]+"' | sed 's/fetch "//; s/"$//' \
    | sed 's|/$||' | sort -u
  # Discovery loops cover a whole directory: `contents/tools?ref=main` covers tools/.
  sed -n '/^## Headless Linux/,$p' "$ROOT/docs/ADOPTION_GUIDE.md" \
    | sed -n '1,/^## [^H]/p' \
    | grep -oE 'contents/[A-Za-z0-9_.-]+\?ref=' | sed 's|contents/||; s|?ref=||' | sort -u
}

# Paths the guide's step 3 tells a human to copy. Read from the `cp` lines, so a path that
# is documented in prose and never copied does not count — the failure this catches is
# exactly a path nobody copies.
guide_paths() {
  sed -n '/^### 3\. Copy the scaffold files/,/^### 4\./p' "$ROOT/docs/ADOPTION_GUIDE.md" \
    | grep -oE '\$SCAFFOLD_DIR/[^" ]+' \
    | sed 's|^\$SCAFFOLD_DIR/||' \
    | sed 's|/$||' | sort -u
}

# Paths scaffold_upgrade.sh installs on an upgrade. PRODUCT_FILES is a whitespace-separated
# shell string; PRODUCT_DIRS_INSTALL/REFRESH are directories. MERGE_FILES are all under
# ai/, which the manifest carries as a directory, so they need no separate row.
upgrade_paths() {
  awk '/^PRODUCT_FILES="/{f=1;next} f&&/^"/{f=0} f{print}' "$ROOT/tools/scaffold_upgrade.sh" \
    | tr ' \t' '\n\n' | grep -v '^$'
  awk -F'"' '/^PRODUCT_DIRS_(INSTALL|REFRESH)=/{print $2}' "$ROOT/tools/scaffold_upgrade.sh" \
    | tr ' ' '\n' | grep -v '^$'
  # MERGE_FILES (three-way merged) and UNION_FILES (line-unioned) are delivered too — they
  # are not COPIED, but the adopter does receive our changes to them, which is what this
  # check is asking. AGENTS.md is a MERGE file and .gitattributes a UNION file; reading
  # only PRODUCT_FILES reported both as frozen, which is wrong in the direction that
  # matters (a false alarm trains people to ignore the check).
  awk -F'"' '/^(MERGE_FILES|UNION_FILES)=/{print $2}' "$ROOT/tools/scaffold_upgrade.sh" \
    | tr ' ' '\n' | grep -v '^$'
}

# Does setup.sh GENERATE its build.sh exclusions from this manifest, or restate them?
#
# A restated list is the bug (#291): it was 6 of 20 and nothing said so. Once setup.sh
# calls the generator the coverage question is answered by construction, so this is the
# only thing left to check — and it is checked, because a future edit could quietly put
# the literal list back and every path below would report as covered.
setup_generates_excludes() {
  grep -q 'adoption_manifest\.sh --build-excludes' "$ROOT/setup.sh"
}

# A manifest entry is SATISFIED by a restatement that names it or names a directory
# containing it. `.github/workflows/scaffold-check.yml` in PRODUCT_FILES satisfies
# `.github/`; the reverse is not true, which is the direction that matters.
covered_by() {
  # $1 = manifest entry (no trailing slash), stdin = the restatement, one path per line
  _cb="$1"; _hit=1
  while IFS= read -r _p; do
    [ -n "$_p" ] || continue
    case "$_p" in "$_cb"|"$_cb"/*) _hit=0; break ;; esac
  done
  return $_hit
}

check() {
  _rc=0
  # ---- THREE OUTCOMES. `check` compares FOUR UPSTREAM FILES; an adopter has none of them.
  # 0 = they agree, 1 = they have drifted, 3 = COULD NOT VERIFY. A missing input is not a
  # pass and it is not a failure — the alternative was reddening every adopter on upgrade,
  # which is a rule this project has already had to learn once.
  if [ ! -f "$ROOT/docs/ADOPTION_GUIDE.md" ] || [ ! -f "$ROOT/tools/scaffold_upgrade.sh" ] \
     || [ ! -f "$ROOT/setup.sh" ] || [ ! -d "$ROOT/overlays" ]; then
    echo "adoption_manifest: NOT MEASURED — this is not the scaffold repository."
    echo "  The four restatements it compares (docs/ADOPTION_GUIDE.md, PRODUCT_FILES,"
    echo "  the build.sh template, the fixtures) exist upstream. Nothing was checked."
    return 3
  fi
  _guide="$(guide_paths)"
  _headless="$(headless_paths)"
  _upg="$(upgrade_paths)"

  echo "adoption_manifest: $( adoption_manifest | grep -c '' ) path(s) declared"

  if setup_generates_excludes; then
    echo "[PASS] setup.sh generates build.sh exclusions from this manifest"
  else
    echo "[FAIL] setup.sh restates its build.sh exclusions instead of generating them"
    echo "       That list was 6 of 20 the last time it was measured by hand (#291)."
    echo "       Call: tools/adoption_manifest.sh --build-excludes"
    _rc=1
  fi

  # A path can legitimately be absent from ONE restatement, but only with a reason stated
  # here. Declared, never inferred — an unexplained absence is the bug.
  #
  #   CLAUDE.md          — the guide CREATES it (printf '@AGENTS.md'), does not copy it.
  #   .scaffold-version  — scaffold_upgrade.sh rewrites it itself, at the end of the run.
  #   docs/              — REFRESH only: an upgrade must not push a docs/ tree into a
  #                        project that deliberately never took one, and the guide leaves
  #                        the choice to the adopter.

  _guide_exempt="CLAUDE.md"
  # The headless path creates CLAUDE.md rather than fetching it. `.cursor` is fetched as
  # .cursor/rules/base.mdc, which covered_by handles; nothing else may be exempt without a
  # line here.
  #
  # docs/ IS NO LONGER EXEMPT. It was, with the reason "for the same reason step 3 does" --
  # and step 3 now copies it, which made the reason false while the exemption still passed.
  # An exemption whose stated reason has stopped being true is worse than none: it reads as
  # considered. The headless path fetches the markdown and deliberately skips the two images
  # and the .docx, which base64-through-jq would mangle anyway.
  _headless_exempt="CLAUDE.md"
  _upg_exempt="CLAUDE.md .scaffold-version LICENSE"

  for _m in $(adoption_manifest | sed 's|/$||'); do
    if ! printf '%s\n' "$_guide" | covered_by "$_m"; then
      case " $_guide_exempt " in *" $_m "*) : ;;
        *) echo "[FAIL] $_m is delivered on upgrade but the ADOPTION GUIDE never copies it"
           echo "       A fresh adoption does not receive it. This is #294 exactly."
           _rc=1 ;;
      esac
    fi
    if ! printf '%s\n' "$_headless" | covered_by "$_m"; then
      case " $_headless_exempt " in *" $_m "*) : ;;
        *) echo "[FAIL] $_m is copied by the guide's step 3 but the HEADLESS path never fetches it"
           echo "       Two adoption paths, one list. A machine that cannot clone gets a"
           echo "       different adoption from one that can. This is #303 exactly."
           _rc=1 ;;
      esac
    fi
    if ! printf '%s\n' "$_upg" | covered_by "$_m"; then
      case " $_upg_exempt " in *" $_m "*) : ;;
        *) echo "[FAIL] $_m is copied at adoption but scaffold_upgrade.sh never refreshes it"
           echo "       It is delivered once and then frozen at the version it was copied."
           _rc=1 ;;
      esac
    fi
  done

  # ---- THE REVERSE DIRECTION: WHAT DOES THE SCAFFOLD OWN THAT NOBODY DECLARED? (#300)
  #
  # Everything above checks that DECLARED paths are consistently delivered. It cannot see a
  # file that is on no list at all — and that is exactly how `.gitleaks.toml` hid.
  #
  # That file was written on 2026-08-30 to suppress the 12 synthetic fixtures inside
  # `tools/secret_scan.sh`, which every adopter vendors. Its own header records the
  # measurement: "gitleaks reports 12 findings in tools/secret_scan.sh in EVERY repository
  # the scaffold ships to". The fix was correct, well-argued, committed — and reached NOBODY,
  # because it was never added to a delivery list. Five weeks later a fleet-wide sweep
  # re-measured the identical 12 findings in eight repositories.
  #
  # So: every tracked file at the repository root is either on the manifest, or exempt here
  # with a stated reason. Adding a root file now costs one deliberate answer.
  #
  #   .gitignore              — UNION on upgrade, appended by setup.sh. Never copied whole.
  #   .version-stamp-baseline — header_check's per-project baseline. The adopter's own.
  #   version                 — the adopter's project version. The guide says so explicitly.
  #   CHANGELOG/README/SECURITY/CODE_OF_CONDUCT/OVERVIEW — this project's own documents.
  _root_exempt=".gitignore .version-stamp-baseline version CHANGELOG.md README.md SECURITY.md CODE_OF_CONDUCT.md OVERVIEW.md"
  for _f in $(git -C "$ROOT" ls-files 2>/dev/null | grep -v '/'); do
    printf '%s\n' "$(adoption_manifest | sed 's|/$||')" | grep -qxF "$_f" && continue
    case " $_root_exempt " in *" $_f "*) continue ;; esac
    echo "[FAIL] $_f is tracked at the root and is on NO delivery list"
    echo "       Either add it to adoption_manifest() so adopters receive it, or add it to"
    echo "       _root_exempt with a reason. A file on no list reaches nobody, silently."
    _rc=1
  done

  # AN EXEMPTION THAT IS NO LONGER NEEDED IS ITSELF A DEFECT — it hides the next drift for
  # that path. Every entry must still be genuinely absent from the restatement it is exempt
  # from. `.githooks` sat in the guide exemption for one commit after the guide grew a hooks
  # step, and an earlier, narrower version of this guard is what said so.
  for _e in $_guide_exempt; do
    if printf '%s\n' "$_guide" | covered_by "$_e"; then
      echo "[FAIL] $_e is exempt from the guide check but the guide now copies it"
      echo "       Remove it from _guide_exempt — a stale exemption hides the next drift."
      _rc=1
    fi
  done
  for _e in $_upg_exempt; do
    if printf '%s\n' "$_upg" | covered_by "$_e"; then
      echo "[FAIL] $_e is exempt from the upgrade check but the upgrade now delivers it"
      echo "       Remove it from _upg_exempt."
      _rc=1
    fi
  done

  [ "$_rc" -eq 0 ] && echo "[PASS] the guide, the upgrade lists and build.sh all match the manifest"
  return $_rc
}

selftest() {
  _p=0; _f=0
  chk() { # name expected actual
    if [ "$2" = "$3" ]; then echo "  ok    $1"; _p=$((_p+1))
    else echo "  FAIL  $1 — expected [$2] got [$3]"; _f=$((_f+1)); fi
  }

  echo "adoption_manifest --selftest"

  # THE MANIFEST IS NON-EMPTY. An inferred-then-empty list is the failure this file warns
  # about at the top; assert the shape it would take.
  chk "manifest is non-empty" 0 "$( [ "$(adoption_manifest | grep -c '')" -gt 10 ] && echo 0 || echo 1 )"

  # covered_by is the whole cross-check. Test it in both directions.
  chk "a directory covers a file under it" 0 \
    "$(printf '.github/workflows/x.yml\n' | covered_by ".github" && echo 0 || echo 1)"
  chk "a file does NOT cover its parent" 1 \
    "$(printf '.github\n' | covered_by ".github/workflows/x.yml" && echo 0 || echo 1)"
  chk "an unrelated prefix does not match" 1 \
    "$(printf '.githooks\n' | covered_by ".github" && echo 0 || echo 1)"

  # THE POINT OF THE TOOL: build_excludes must cover every manifest path. Asserted against
  # the generated text, not against the same list twice.
  _missing=""
  _gen="$(build_excludes)"
  for _m in $(adoption_manifest | sed 's|/$||'); do
    printf '%s' "$_gen" | grep -qF "\${APP_NAME}/$_m\"" || _missing="$_missing $_m"
  done
  chk "build_excludes covers every manifest path" "" "$_missing"

  # ---- THE MUTATIONS RUN AGAINST A FIXTURE THIS FUNCTION BUILDS, NEVER AGAINST $ROOT.
  #
  # The first version copied the live tree and mutated the copy, which meant `check` was
  # really being asked "does the scaffold repository currently agree with itself". In an
  # ADOPTER there is no docs/ADOPTION_GUIDE.md, so `cp` failed and every adopter went red
  # on the upgrade that delivered this file. That is a rule already written down here —
  # a selftest asserts the TOOL, not the repo — and it was broken by the tool that exists
  # to stop lists drifting. The fixture below is minimal and synthetic: three files whose
  # only job is to be consistent, then to be made inconsistent one at a time.
  _fx="$(mktemp -d "${TMPDIR:-/tmp}/adoption_manifest.XXXXXX")" || { echo "adoption_manifest: mktemp failed; stopping" >&2; exit 1; }
  mkdir -p "$_fx/tools" "$_fx/docs" "$_fx/overlays"
  # The fixture must honour the SAME exemptions check() declares, or the stale-exemption
  # guard fires on it — a fixture that delivers LICENSE on upgrade is not consistent, it is
  # a fixture contradicting a documented exception. Kept as one list per restatement so the
  # two stay visibly paired with the ones in check().
  _fx_not_guide="CLAUDE.md"
  _fx_not_headless="CLAUDE.md"
  _fx_not_upg="CLAUDE.md .scaffold-version LICENSE"
  _fx_paths() {  # _fx_paths <space-separated exemptions>
    adoption_manifest | sed 's|/$||' | while IFS= read -r _m; do
      case " $1 " in *" $_m "*) continue ;; esac
      printf '%s\n' "$_m"
    done
  }
  {
    printf '### 3. Copy the scaffold files\n\n```bash\n'
    _fx_paths "$_fx_not_guide" | while IFS= read -r _m; do
      printf 'cp -r "$SCAFFOLD_DIR/%s" .\n' "$_m"
    done
    printf '```\n\n### 4. Next\n\n'
    # THE FIXTURE MUST CARRY BOTH ADOPTION PATHS, or it cannot exercise the check that
    # exists because the guide has two. Adding the headless check without this made the
    # consistent fixture fail its own check — caught immediately, which is the point.
    printf '## Headless Linux (SSH-only machines)\n\n```bash\n'
    _fx_paths "$_fx_not_headless" | while IFS= read -r _m; do
      printf 'fetch "%s" %s\n' "$_m" "$_m"
    done
    printf '```\n\n## After\n'
  } > "$_fx/docs/ADOPTION_GUIDE.md"
  {
    printf 'PRODUCT_FILES="\n'
    _fx_paths "$_fx_not_upg" | tr '\n' ' '
    printf '\n"\nPRODUCT_DIRS_INSTALL=""\nMERGE_FILES=""\nUNION_FILES=""\n'
  } > "$_fx/tools/scaffold_upgrade.sh"
  printf 'tools/adoption_manifest.sh --build-excludes\n' > "$_fx/setup.sh"

  chk "a consistent fixture passes" 0 "$( ROOT="$_fx" check >/dev/null 2>&1 && echo 0 || echo 1 )"

  # MUTATION 1 — setup.sh restates its exclusions instead of generating them (#291).
  printf 'echo hand-written-list\n' > "$_fx/setup.sh"
  chk "a restated exclusion list fails" 1 "$( ROOT="$_fx" check >/dev/null 2>&1 && echo 0 || echo 1 )"
  printf 'tools/adoption_manifest.sh --build-excludes\n' > "$_fx/setup.sh"

  # MUTATION 2 — a path on the upgrade list that the guide never copies (#294). This is
  # the half that went unnoticed for two releases, so it gets its own case.
  grep -v 'sync-check\.sh' "$_fx/docs/ADOPTION_GUIDE.md" > "$_fx/g.tmp" && mv "$_fx/g.tmp" "$_fx/docs/ADOPTION_GUIDE.md"
  chk "a path dropped from the guide fails" 1 "$( ROOT="$_fx" check >/dev/null 2>&1 && echo 0 || echo 1 )"

  # MUTATION 3 — a path the CLONE path copies and the HEADLESS path does not (#303). This
  # is the shape that shipped: setup.sh was in step 3 and absent from the headless fetch, so
  # an SSH-only adopter could not run the verification the same section told them to run.
  _fx_h="$(sed -n '/^## Headless Linux/,$p' "$_fx/docs/ADOPTION_GUIDE.md" | grep -v 'sync-check\.sh')"
  sed -n '/^## Headless Linux/q;p' "$_fx/docs/ADOPTION_GUIDE.md" > "$_fx/g.tmp"
  printf '%s\n' "$_fx_h" >> "$_fx/g.tmp"
  mv "$_fx/g.tmp" "$_fx/docs/ADOPTION_GUIDE.md"
  chk "a path the headless path skips fails" 1 "$( ROOT="$_fx" check >/dev/null 2>&1 && echo 0 || echo 1 )"

  # MUTATION 4 — inputs absent entirely is NOT MEASURED (exit 3), never a pass.
  rm -rf "$_fx/overlays"
  chk "a tree that is not the scaffold is exit 3" 3 "$( ROOT="$_fx" check >/dev/null 2>&1; echo $? )"
  rm -rf "$_fx"

  echo "  $_p passed, $_f failed"
  [ "$_f" -eq 0 ]
}

case "${1:-}" in
  --check)          check ;;
  --build-excludes) build_excludes ;;
  --selftest)       selftest ;;
  ""|--list)        adoption_manifest ;;
  *) echo "usage: $0 [--list|--check|--build-excludes|--selftest]" >&2; exit 2 ;;
esac
