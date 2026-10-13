#!/usr/bin/env bash
# Project:  ai-project-scaffold
# File:     tools/context_survival.sh
# Modified: 2026-10-13
# Version:  0.3.7.20261013.0405
# Purpose:  Prove an adopter's own content survives setup, upgrade and overlay application.
# Changelog:
#   2026-10-13 v0.3.7.20261013.0405 — local edit in a public adopter: work mirror account no longer named; mirror comes from SCAFFOLD_UPSTREAM_MIRROR (scaffold issue #387).
#   2026-10-10 v0.3.6.20261010.1205 — a baseline tarball that does not match its release's SHA256SUMS is not used (report item 15), and the declared upstream comes from the shared parser, quoted -- it was word-split into the loop.
#   2026-10-07 v0.3.5.20261007.0347 — the baseline tarball comes from wherever this project gets the scaffold. It was fetched from Robiton only, which a work machine on the the work mirror account mirror cannot read, so the upgrade path always skipped there. Tries SCAFFOLD_UPSTREAM or .scaffold-upstream first, then Robiton, then the mirror.
#   2026-10-04 v0.3.4.20261004.0655 — A FAIL IS EXIT 1 EVEN WHEN SOMETHING ELSE SKIPPED. Any skip forced exit 3, and in an adoption the overlay path always skips, so a real failure there could never come out as 1. preflight showed it as [SKIP] and adoption_check accepted it. Measured in localcoder: "6 passed, 1 failed", exit 3, and a message saying the upgrade path was not verified, printed under 6 passing upgrade-path checks. The failure was path 1: setup.sh refuses outside a template clone, so it exited 2 in every adoption. Paths 1 and 3 now print n/a where scaffold_clone is false. They test the template, which an adoption does not have, so not running them there is neither unverified nor a pass. The exit decision is verdict(), and --selftest drives it.
#   2026-09-23 v0.3.3.20260923.0941 — fixtures run inside the root tools/fixture_guard.sh validates. There a git and a mktemp on PATH refuse anything that would land outside it. Every mktemp takes a ${TMPDIR} template, because macOS mktemp ignores TMPDIR without one.
#   2026-09-23 v0.3.2.20260923.0843 — every mktemp fails closed. A failed one left the temp variable empty, so the fixture ran in the caller's directory; header_check's committed into Robiton/control.
#   2026-09-08 v0.3.1.20260908.1916 — the fixtures ship `docs/` now, because the manifest says an
#                        adoption receives it and these three file lists are a FIFTH restatement
#                        of that delivery — one adoption_manifest.sh --check has never seen. It
#                        cross-checks four lists against each other; these were not among them,
#                        and they disagreed with all four in the same two ways (README.md in,
#                        docs/ out). Surfaced by the new link pass in stale_path_scan.sh 0.5.0
#                        reporting six broken links inside the fixture, five of which were the
#                        fixture's own omission and one of which was real.
#                        THE LIST IS STILL RESTATED HERE. Deriving it from the manifest is the
#                        right fix and is a larger change than the one that found it; backlogged
#                        rather than done quietly at the end of an unrelated commit.
#   2026-08-12 v0.3.0 — SWEPT EVERY $ROOT USE INSTEAD OF FIXING THE NEXT REPORTED ONE.
#                        v0.2.0 fixed the BASELINE and the failure moved one layer down, to
#                        `--from "$ROOT"` at the upgrade step: `--from <path>` means "a
#                        local SCAFFOLD CLONE", and in an adoption $ROOT is not one, so the
#                        upgrader reported "could not determine the latest release" and the
#                        fixture called that a FAILURE. Reported a second time by the same
#                        adoption, with the right instruction attached — grep the file once
#                        rather than wait for the next occurrence.
#                        Nine uses, three of them scaffold-clone-only. They now go through
#                        scaffold_clone(), so the distinction is stated once: reading the
#                        VENDORED setup.sh or scaffold_upgrade.sh is fine anywhere;
#                        resolving a tag, passing --from, and tarring overlays/ are not.
#                        AND THE OVERLAY PATH WAS PASSING VACUOUSLY, which is worse than the
#                        failure that was reported. make_template_clone tars `overlays` and
#                        `OVERVIEW.md` with stderr discarded, so in an adoption it built a
#                        tree with no overlay, setup.sh had none to apply, and the
#                        assertions went GREEN under the label "overlay application". A
#                        loud wrong answer gets fixed in a day; a green line pointed at
#                        nothing is this project's most repeated defect, and it had already
#                        been reported to us as a pass.
#                        Could-not-run is exit 3 at the upgrade step too, not only at the
#                        baseline: without network an adoption cannot fetch a release, and
#                        "the upgrade path is broken" is a much louder claim than the truth.
#   2026-08-11 v0.2.0 — COULD-NOT-BUILD IS NOW EXIT 3, NOT A FAILURE — AND IT WAS FAILING
#                        EVERY ADOPTER. The baseline came from `git archive <scaffold tag>`
#                        against $ROOT, which in an adoption is the ADOPTER's repo, where a
#                        scaffold tag does not exist and never will. preflight wires this in
#                        as a BLOCKING gate, so every adopter's preflight failed
#                        permanently on a check about the scaffold's own layout. Reported
#                        from the first real 0.36.2 adoption; it cannot be seen upstream,
#                        where the tags always resolve.
#                        Two changes: fall back to the release TARBALL via gh, the way
#                        scaffold_upgrade.sh already materialises a release, and when the
#                        baseline still cannot be built, exit 3. "I could not verify the
#                        upgrade path" is not "the upgrade path is broken", and this
#                        project's own exit vocabulary exists for exactly that distinction.
#                        Silently substituting the current tree remains forbidden — that is
#                        the substitution that produced the conflicts described below.
#   2026-08-11 v0.1.0 — Initial, for W-05. The claim "AI Scaffold preserves your context" is
#                        load-bearing for the product and was tested only against a fixture
#                        the upgrader builds for ITSELF — never against a populated adopter
#                        repository end to end.
#                        FAMILY 2 IS THE POINT AND IS FIRST. NEVER_FILES is a do-not-write
#                        rule with an explicit list and passing selftests; a fixture covering
#                        only that would have been green on every day #179 was live. Union
#                        merge is a three-way content operation with a SILENT failure mode
#                        and three recorded occurrences, one of which put 693 binaries
#                        (6.1 MB) into git history as raw blobs. Git LFS does not error when
#                        a filter pattern disappears — it stops applying, and git add, the
#                        commit and CI all stay green.
#                        THE SENTINEL IS ai/localcoder.config.json, NOT ai/eval_tasks.py.
#                        W-05 was accepted with eval_tasks as the sentinel and that file is
#                        on W-15's move list, so the fixture would have gone red on the day
#                        the split landed and the repair would have been to edit it in the
#                        same commit — the test proving upgrades preserve adopter content,
#                        rewritten by the largest upgrade in the product's history, by the
#                        person performing it. config.json is in NEVER_FILES, stays per
#                        DEC-21, and asserting it makes this fixture cover DEC-21 for free.
#                        THE DELETION CASE is the risk the split introduces and the only
#                        place it is cheap to test: an adopter's own file under tools/ must
#                        survive an upgrade that REMOVES scaffold-owned files from the same
#                        directory. Nothing asserted that before; both families only ever
#                        checked that adopter content is not overwritten.
# =============================================================================
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
pass=0; fail=0; UNBUILDABLE=0

# >>> shared:upstream
# carried by: tools/scaffold_version.sh tools/scaffold_upgrade.sh tools/context_survival.sh tools/release.sh
# ONE BODY, FOUR FILES, byte for byte. preflight's "shared blocks" gate fails the moment a
# copy differs or a file on the line above stops carrying it (report item 16).
# Not a sourced library: these tools are vendored one by one, and scaffold_upgrade.sh
# replaces itself mid-run, so a library is one more file to deliver in step -- and the
# drift this block caused (item 8) came from copies nobody compared, not from copying.
UPSTREAM_DEFAULT="Robiton/ai-project-scaffold"
# Local edit (public adopter, scaffold issue #387): the work mirror is configured, not named.
UPSTREAM_MIRROR="${SCAFFOLD_UPSTREAM_MIRROR:-}"
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
# >>> shared:release-sums
# carried by: tools/scaffold_upgrade.sh tools/context_survival.sh
# ONE BODY, TWO FILES: the two that fetch a release. Not in shared:upstream, because
# scaffold_version.sh pins every gh call it carries to a bound, and it never fetches.
release_sums() {  # release_sums <owner/repo> <tag> <out> -> 0 fetched, 1 this release has none
  # The the work mirror account mirror has tags and no releases (a deploy key cannot create one), so
  # there is nothing to fetch there, and releases cut before 0.111.21 carry no SHA256SUMS.
  # Both are "unverified", which the caller reports; neither is a mismatch.
  command -v gh >/dev/null 2>&1 || return 1
  rm -f "$3"
  gh release download "$2" --repo "$1" --pattern SHA256SUMS --output "$3" >/dev/null 2>&1 \
    && [ -s "$3" ] && return 0
  rm -f "$3"
  return 1
}
# <<< shared:release-sums

# IS $ROOT A SCAFFOLD CLONE, OR JUST THE REPO THIS HAPPENS TO BE RUNNING IN?
#
# The distinction is the whole reason this file kept failing in adoptions. Some uses of
# $ROOT are fine anywhere — reading the VENDORED setup.sh or scaffold_upgrade.sh, which
# every adopter has. Others treat $ROOT as a full scaffold checkout: resolving a release
# tag, passing `--from <clone>`, tarring `overlays/`. Those are only valid upstream.
#
# Fixed one call site at a time twice now, so this is a predicate rather than an inline
# test, and every scaffold-clone use below goes through it.
scaffold_clone() {
  [ -d "$ROOT/overlays" ] && [ -f "$ROOT/OVERVIEW.md" ] \
    && [ -f "$ROOT/.github/workflows/mirror-sync.yml" ]
}

skip() { printf '  SKIP  %s\n' "$1"; UNBUILDABLE=1; }
# NOT APPLICABLE IS NOT COULD-NOT-RUN. An adoption has no template to initialise and no
# overlays/ to apply. Those paths test the scaffold's own clone, and their absence here is
# a fact about the repository, not a gap in what was verified. skip() means "this
# should have run and could not", and it forces exit 3. na() does not.
na()  { printf '  n/a   %s\n' "$1"; }
ok()  { printf '  ok    %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf '  FAIL  %s\n' "$1"; fail=$((fail + 1)); }

# A sentinel that cannot occur by accident and survives a grep of a binary-ish file.
SENTINEL="ADOPTER-CONTENT-MUST-SURVIVE-8f3a1c"

# NEVER_FILES, read from the upgrader rather than restated. Two literals in two files is the
# shape this repo keeps being bitten by; if the list changes and this copy does not, the
# fixture silently stops covering the new entry.
never_files() {
  sed -n '/^NEVER_FILES="/,/^"/p' "$ROOT/tools/scaffold_upgrade.sh" \
    | sed '1d;$d' | tr ' ' '\n' | sed '/^$/d'
}

# TWO TREE SHAPES, BECAUSE THERE ARE TWO, AND THE FIRST VERSION OF THIS FILE HAD ONE.
#
# `setup.sh` is run inside a TEMPLATE CLONE — a full copy of the scaffold, overlays and all —
# and what it produces is an ADOPTION. An adoption does not carry `overlays/`, `OVERVIEW.md`
# or `.github/workflows/mirror-sync.yml`; those three are exactly the signals
# `is_upstream_repo` uses, and a fixture carrying them is refused by the upgrader with "this
# looks like the scaffold's own repository". That is the upgrader being right and the fixture
# being wrong, and it cost two rounds to see.
#
# THE CONTRACTS ALSO DIFFER, which the first version conflated. `NEVER_FILES` is the
# UPGRADER's promise. `setup.sh` at init legitimately writes `ai/MEMORY.md` (the setup
# block), `ai/TEAM.md` (the owner) and `version` — that is its job. Asserting byte-identity
# across an initialisation is asserting that setup does not set anything up.
adopter_content() {   # adopter_content <dir> — the project's own material, over the top
  local d="$1" f
  for f in $(never_files); do
    mkdir -p "$d/$(dirname "$f")"
    case "$f" in
      version)              printf '9.9.9.20260811.0000\n' > "$d/$f" ;;
      .github/CODEOWNERS)   printf '* @%s-owner\n' "$SENTINEL" > "$d/$f" ;;
      *.json)               printf '{"_adopter": "%s"}\n' "$SENTINEL" > "$d/$f" ;;
      *)                    printf '%s in %s\n' "$SENTINEL" "$f" >> "$d/$f" ;;
    esac
  done
  # UNION_FILES: an adopter LFS pattern for a type the scaffold does not ship (#179's exact
  # shape) and an adopter gitignore line, APPENDED to whatever the scaffold ships.
  printf '*.psd filter=lfs diff=lfs merge=lfs -text\n' >> "$d/.gitattributes"
  printf '%s\n' "$SENTINEL-gitignore" >> "$d/.gitignore"
  # An adopter's OWN tool, in the directory the split empties. It carries a file header
  # because the scaffold mandates one and header_check fails the run otherwise — a real
  # adopter following the standard has one.
  printf '#!/bin/sh\n# Project:  fixture\n# File:     tools/our_deploy.sh\n# Modified: 2026-08-11\n# Version:  1.0.0.20260811.0000\n# Purpose:  An adopter own tool, which must survive an upgrade. %s\necho adopter tool\n' \
    "$SENTINEL" > "$d/tools/our_deploy.sh"
  chmod +x "$d/tools/our_deploy.sh"
  ( cd "$d" && git add -A && git -c commit.gpgsign=false commit -qm adopter ) >/dev/null 2>&1
}

make_template_clone() {   # what you run setup.sh inside
  local d="$1"
  mkdir -p "$d"
  ( cd "$ROOT" && tar cf - ai overlays tools docs setup.sh sync-check.sh AGENTS.md OVERVIEW.md \
      README.md .gitignore .gitattributes .github 2>/dev/null ) | ( cd "$d" && tar xf - )
  ( cd "$d" && git init -q . && git config user.email t@t && git config user.name t )
  adopter_content "$d"
}

make_adoption() {   # what setup.sh PRODUCES, and what the upgrader runs against
  # BUILT FROM THE OLD RELEASE, NOT FROM TODAY'S FILES. The first version tarred the current
  # working tree and then wrote `.scaffold-version 0.24.0` on top, so the "0.24.0 adoption"
  # already contained the 0.35.0 text. Merging 0.24 -> 0.35 onto that conflicted in
  # AGENTS.md, ai/STANDARDS.md and ai/CODING.md, the upgrader exited 1, and it was RIGHT —
  # an adopter really would have to resolve those. It was the fixture claiming a base it
  # did not have. An upgrade fixture built from the wrong base tests nothing.
  local d="$1" from_tag="${2:-0.24.0.20260809.1220}"
  mkdir -p "$d"
  # `git archive <scaffold tag>` ONLY RESOLVES INSIDE THE SCAFFOLD REPO. $ROOT is whatever
  # repository is running this, and in an adoption that is the adopter's own — where a
  # scaffold tag does not exist and never will. Reported from a real 0.36.2 adoption: this
  # returned nothing, `bad` fired, and because preflight wires this in as a BLOCKING gate,
  # EVERY ADOPTER'S PREFLIGHT FAILED PERMANENTLY on a check about the scaffold's own layout.
  ( cd "$ROOT" && git archive "$from_tag" ai tools docs setup.sh sync-check.sh AGENTS.md \
      README.md .gitignore .gitattributes 2>/dev/null ) | ( cd "$d" && tar xf - ) 2>/dev/null
  if [ ! -f "$d/ai/STANDARDS.md" ] && command -v gh >/dev/null 2>&1; then
    # Second try, the way scaffold_upgrade.sh already materialises a release: the tarball
    # from upstream. Works in an adoption when the machine has gh and network.
    local _t; _t="$(mktemp -d "${TMPDIR:-/tmp}/context_survival.XXXXXX")" || { echo "context_survival: mktemp failed; stopping" >&2; exit 1; }
    # FROM WHEREVER THIS PROJECT GETS THE SCAFFOLD: work machines read only the
    # the work mirror account mirror. Same order as scaffold_upgrade.sh's upstream_pinned/probe.
    # The shared block's parser, so a name that is not owner/repo is refused here too
    # (it was word-split into the loop unquoted), then the two known upstreams.
    local _pin _src
    _pin="$(upstream_pinned "$ROOT")" || _pin=""
    for _src in ${_pin:+"$_pin"} "$UPSTREAM_DEFAULT" ${UPSTREAM_MIRROR:+"$UPSTREAM_MIRROR"}; do
      rm -rf "$_t/tree"; mkdir "$_t/tree"
      if gh api "repos/$_src/tarball/$from_tag" > "$_t/b.tgz" 2>/dev/null \
         && tar -xz -C "$_t/tree" --strip-components=1 -f "$_t/b.tgz" 2>/dev/null; then
        # A BASELINE THAT DOES NOT MATCH ITS RELEASE IS NOT A BASELINE (report item 15).
        # Used anyway, it would score the upgrade path against a tree nobody released.
        if release_sums "$_src" "$from_tag" "$_t/SHA256SUMS" \
           && ! _sums_out="$(scaffold_sums check "$_t/tree" "$_t/SHA256SUMS")"; then
          bad "the $from_tag tarball from $_src does not match its release SHA256SUMS -- not used"
          printf '%s\n' "$_sums_out" | head -5 | sed 's/^/        /'
          break
        fi
        ( cd "$_t/tree" && tar cf - ai tools docs setup.sh sync-check.sh AGENTS.md README.md \
            .gitignore .gitattributes 2>/dev/null ) | ( cd "$d" && tar xf - ) 2>/dev/null
        break
      fi
    done
    rm -rf "$_t"
  fi
  if [ ! -f "$d/ai/STANDARDS.md" ]; then
    # COULD NOT BUILD THE BASE — AND THAT IS A SKIP, NOT A FAILURE.
    #
    # Silently falling back to the current tree is the substitution that produced the
    # conflicts described above, so it still must not do that. But "I could not verify the
    # upgrade path" is not "the upgrade path is broken", and this project's own exit-3 rule
    # exists for exactly that distinction. Exit 3 is what preflight renders as [SKIP].
    printf '  SKIP  could not build a %s baseline here.\n' "$from_tag"
    printf '        %s tags live in the scaffold repo; this is not it, and gh could not\n' "$from_tag"
    printf '        fetch the tarball either. The upgrade path is UNVERIFIED, not broken.\n'
    UNBUILDABLE=1
    return 1
  fi
  mkdir -p "$d/.github"
  ( cd "$ROOT" && tar cf - .github/CODEOWNERS 2>/dev/null ) | ( cd "$d" && tar xf - ) 2>/dev/null
  printf '@AGENTS.md\n' > "$d/CLAUDE.md"
  ( cd "$d" && git init -q . && git config user.email t@t && git config user.name t )
  adopter_content "$d"
}

snapshot() {   # snapshot <dir> — record every never-touch file byte for byte
  # INSIDE .git ON PURPOSE. Written into the working tree it made the tree dirty, and
  # scaffold_upgrade.sh refuses a dirty tree — rightly, since its own message explains that
  # a clean tree is the restorable snapshot that makes `git checkout .` a complete undo.
  # The fixture was breaking the precondition it was about to test.
  local d="$1" f
  : > "$d/.git/w05-snapshot"
  for f in $(never_files); do
    [ -f "$d/$f" ] && printf '%s  %s\n' "$(shasum -a 256 < "$d/$f" | cut -d" " -f1)" "$f" \
      >> "$d/.git/w05-snapshot"
  done
}

check_survival() {   # NEVER_FILES, byte for byte. The UPGRADER's promise only.
  local d="$1" label="$2" f missing="" want got
  while read -r want f; do
    [ -n "${f:-}" ] || continue
    [ -f "$d/$f" ] || { missing="$missing $f(gone)"; continue; }
    got="$(shasum -a 256 < "$d/$f" | cut -d" " -f1)"
    [ "$got" = "$want" ] || missing="$missing $f(modified)"
  done < "$d/.git/w05-snapshot"
  if [ -z "$missing" ]; then
    ok "$label — every never-touch file is byte-identical"
  else
    bad "$label — adopter content lost:$missing"
  fi
}

check_union() {   # FAMILY 2, and the half that matters. Applies to every path.
  local d="$1" label="$2"
  if grep -q '\*\.psd filter=lfs' "$d/.gitattributes" 2>/dev/null; then
    ok "$label — the adopter's LFS pattern survived (#179's shape)"
  else
    bad "$label — an LFS filter pattern was DROPPED. Git LFS does not error on this; it"
    bad "$label   stops applying, and binaries then enter history as raw blobs."
  fi
  if grep -q "$SENTINEL-gitignore" "$d/.gitignore" 2>/dev/null; then
    ok "$label — the adopter's .gitignore line survived"
  else
    bad "$label — an adopter .gitignore line was dropped by the union merge"
  fi
  # ...and the upstream half is not silently dropped either. A union keeping only the
  # adopter's side passes both checks above and is still broken.
  if grep -qE '^\.venv|^__pycache__|^\.DS_Store|^node_modules' "$d/.gitignore" 2>/dev/null; then
    ok "$label — the scaffold's own lines are present too (union kept both sides)"
  else
    bad "$label — the scaffold's .gitignore lines went missing; the union kept one side"
  fi
  # THE DELETION CASE. The split removes a directory's worth of scaffold files from tools/.
  if [ -f "$d/tools/our_deploy.sh" ] && grep -q "$SENTINEL" "$d/tools/our_deploy.sh"; then
    ok "$label — an adopter's own file under tools/ survived"
  else
    bad "$label — an adopter file under tools/ was removed with the scaffold-owned ones"
  fi
}

# THE TOOL MUST ACTUALLY RUN, AND THE FIRST VERSION OF THIS FILE DID NOT CHECK.
#
# It invoked `setup.sh --yes`. There is no `--yes` flag, so setup printed its usage text and
# exited 0, and a `|| true` swallowed it. Every assertion then measured a tree nothing had
# touched: 12 of 15 "passed" because adopter content trivially survives an upgrade that never
# happened. A fixture that passes by never exercising its subject is the exact defect class
# this repository exists to remove, and it was reproduced inside the fixture written to
# catch it.
#
# So every path below asserts that the tool RAN and CHANGED SOMETHING before any survival
# claim is allowed to count. The evidence is a scaffold-owned file appearing that the adopter
# fixture never created.
ran_and_changed() {   # ran_and_changed <dir> <label> <rc>
  local d="$1" label="$2" rc="$3"
  if [ "$rc" -ne 0 ]; then
    bad "$label — the tool exited $rc. Nothing below this line has been tested."
    return 1
  fi
  # The adopter now STARTS with the scaffold's files, so their presence proves nothing.
  # A dirty tree does: the fixture commits before running, so any modification is the tool's.
  if [ -z "$( cd "$d" && git status --porcelain 2>/dev/null )" ]; then
    bad "$label — the tool exited 0 and changed NOTHING. It probably rejected its flags,"
    bad "$label   which is how the first version of this fixture passed 12 assertions"
    bad "$label   against a tree nothing had touched."
    return 1
  fi
  ok "$label — the tool ran and wrote into the tree"
  return 0
}

run() {
  local tmp rc; tmp="$(mktemp -d "${TMPDIR:-/tmp}/context_survival.XXXXXX")" || { echo "context_survival: mktemp failed; stopping" >&2; exit 1; }
  KEEPTMP="$tmp"

  # ---- path 1: setup.sh init, inside a template clone -------------------------------
  # NEVER_FILES does NOT apply here — init writes MEMORY, TEAM and version by design. What
  # must survive is the material setup has no business in: the union files and the
  # adopter's own tool.
  # A TEMPLATE CLONE CAN ONLY BE BUILT FROM ONE. In an adoption make_template_clone gets no
  # overlays/ or OVERVIEW.md, setup.sh refuses with exit 2, and that came out as a FAIL in
  # every adoption. Exit 3 was masking it until 0.3.4.
  if ! scaffold_clone; then
    na "setup.sh init — runs inside a template clone, and an adoption is not one."
  else
  make_template_clone "$tmp/setup"
  rc=0
  ( cd "$tmp/setup" && "$ROOT/setup.sh" --type base --name fixture --owner "W-05" \
      >"$tmp/setup.log" 2>&1 ) || rc=$?
  if ran_and_changed "$tmp/setup" "setup.sh init" "$rc"; then
    check_union "$tmp/setup" "setup.sh init"
  fi
  fi

  # ---- path 2: the upgrader, against a real adoption --------------------------------
  # This is the path NEVER_FILES governs, and the one the split will exercise hardest.
  if ! make_adoption "$tmp/upgrade"; then rc=99; else
  printf '0.24.0.20260809.1220\n' > "$tmp/upgrade/.scaffold-version"
  ( cd "$tmp/upgrade" && git add -A \
      && git -c commit.gpgsign=false commit -qm adopted ) >/dev/null 2>&1
  snapshot "$tmp/upgrade"
  # `--from <path>` means "take both releases from a LOCAL SCAFFOLD CLONE". $ROOT is the
  # repository running this, which in an adoption is not one — the upgrader then reports
  # "could not determine the latest release" and the fixture called that a FAILURE.
  #
  # Reported from a real adoption AFTER the baseline fix landed: the failure simply moved
  # one layer down, because the fix stopped at make_adoption and did not follow $ROOT to
  # where it is used as a clone. Same defect, one call site along.
  #
  # Upstream keeps --from, which is what makes the fixture offline and fast there. In an
  # adoption the upgrader resolves the release from upstream by itself — the same path a
  # real upgrade takes, and already proven to work by the tarball fallback above.
  rc=0
  if scaffold_clone; then
    ( cd "$tmp/upgrade" && "$ROOT/tools/scaffold_upgrade.sh" --from "$ROOT" \
        >"$tmp/upgrade.log" 2>&1 ) || rc=$?
  else
    ( cd "$tmp/upgrade" && "$ROOT/tools/scaffold_upgrade.sh" \
        >"$tmp/upgrade.log" 2>&1 ) || rc=$?
  fi
  # COULD-NOT-RUN IS UNVERIFIED, NOT BROKEN — the same rule the baseline already follows.
  # Without network or gh, an adoption cannot fetch a release to upgrade from, and saying
  # "the upgrade path is broken" on that evidence is a much louder claim than the truth.
  if [ "$rc" -ne 0 ] && grep -qiE "could not determine the latest release|could not fetch|network" \
       "$tmp/upgrade.log" 2>/dev/null; then
    skip "the upgrade step could not fetch a release here — upgrade path UNVERIFIED."
  elif ran_and_changed "$tmp/upgrade" "scaffold_upgrade.sh from 0.24.0" "$rc"; then
    check_survival "$tmp/upgrade" "scaffold_upgrade.sh from 0.24.0"
    check_union    "$tmp/upgrade" "scaffold_upgrade.sh from 0.24.0"
  fi
  fi

  # ---- path 3: overlay application ---------------------------------------------------
  # NEEDS overlays/, WHICH AN ADOPTION DOES NOT HAVE. make_template_clone tars `overlays`
  # and `OVERVIEW.md` with stderr discarded, so in an adoption it produced a tree with no
  # overlay in it, setup.sh had none to apply, and the assertions PASSED under a label that
  # says "overlay application (python-script)".
  #
  # THAT IS WORSE THAN THE FAILURE THIS FILE WAS JUST REPORTED FOR. A loud wrong answer gets
  # fixed in a day; a green line that tests nothing is the exact shape this project keeps
  # finding — present, green, pointed at nothing — and it was reported to us as a PASS.
  if ! scaffold_clone; then
    na "overlay application — no overlays/ here, so there is no overlay to apply."
  else
  make_template_clone "$tmp/overlay"
  rc=0
  ( cd "$tmp/overlay" && "$ROOT/setup.sh" --type python-script --name fixture \
      --owner "W-05" >"$tmp/overlay.log" 2>&1 ) || rc=$?
  if ran_and_changed "$tmp/overlay" "overlay application (python-script)" "$rc"; then
    check_union "$tmp/overlay" "overlay application (python-script)"
  fi
  fi

  echo ""
  echo "  logs: $tmp"
  echo "  $pass passed, $fail failed"
  verdict
}

# THE EXIT DECISION, IN ONE PLACE, IN THIS ORDER.
#
# 1. A FAILURE IS 1, WHATEVER ELSE HAPPENED. Until 0.3.4 a skip was checked first, so one
#    skipped path turned every failure into 3, and preflight rendered that as [SKIP].
# 2. EXIT 3 IS COULD-NOT-RUN, and it must not look like either other answer. If the baseline
#    could not be built, the assertions that depend on it never ran, and reporting 1 would
#    claim the upgrade path is broken. preflight renders 3 as [SKIP].
# 3. NOTHING RAN IS ALSO 3. Zero assertions and zero failures is not a pass.
verdict() {
  if [ "$fail" -gt 0 ]; then
    [ "$UNBUILDABLE" = "1" ] && echo "  (a path was also skipped; the failure above still stands)"
    return 1
  fi
  if [ "$UNBUILDABLE" = "1" ] || [ "$pass" -eq 0 ]; then
    echo ""
    echo "  EXIT 3 — part of the upgrade path was NOT verified here. That is not a failure."
    echo "  This check compares a real scaffold release against the current tree, so it can"
    echo "  only run where the scaffold's own tags resolve. In an adoption it needs gh and"
    echo "  network to fetch the baseline; without them there is nothing to compare."
    return 3
  fi
  return 0
}

# THE VERDICT ALONE, ON SYNTHETIC COUNTS. The fixture run needs a network and takes 30s. The
# exit order is what masked a failure for weeks, and it can be pinned in milliseconds.
selftest() {
  local n=0 bad_n=0 p f u want got
  while read -r p f u want; do
    [ -n "${p:-}" ] || continue
    pass=$p; fail=$f; UNBUILDABLE=$u; got=0
    verdict >/dev/null 2>&1 || got=$?
    n=$((n + 1))
    if [ "$got" = "$want" ]; then
      printf '  ok    pass=%s fail=%s skipped=%s -> %s\n' "$p" "$f" "$u" "$got"
    else
      printf '  FAIL  pass=%s fail=%s skipped=%s -> %s, want %s\n' "$p" "$f" "$u" "$got" "$want"
      bad_n=$((bad_n + 1))
    fi
  done <<'CASES'
6 0 0 0
6 1 0 1
6 1 1 1
0 1 1 1
6 0 1 3
0 0 1 3
0 0 0 3
CASES
  echo "  $((n - bad_n))/$n verdict cases pass"
  [ "$bad_n" -eq 0 ]
}

# DEMONSTRATE THE FIXTURE CAN FAIL. W-05 asks for this once; making it a flag means it is
# re-runnable, and a fixture nobody has seen fail is a fixture nobody should believe.
prove_it_fails() {
  local tmp; tmp="$(mktemp -d "${TMPDIR:-/tmp}/context_survival.XXXXXX")" || { echo "context_survival: mktemp failed; stopping" >&2; exit 1; }
  trap 'rm -rf "$tmp"' RETURN
  echo "  injecting: an upgrade that overwrites ai/MEMORY.md and drops the LFS pattern"
  make_adoption "$tmp/broken"
  snapshot "$tmp/broken"
  printf 'upstream content, adopter sentinel gone\n' > "$tmp/broken/ai/MEMORY.md"
  printf '# scaffold line only\n' > "$tmp/broken/.gitattributes"
  rm -f "$tmp/broken/tools/our_deploy.sh"
  local before=$fail
  check_survival "$tmp/broken" "INJECTED BREAKAGE"
  check_union    "$tmp/broken" "INJECTED BREAKAGE"
  if [ "$fail" -gt "$before" ]; then
    echo ""
    echo "  ok — the fixture detects it ($((fail - before)) assertion(s) fired)"
    return 0
  fi
  echo ""
  echo "  FAIL — the fixture passed a tree with adopter content destroyed. It proves nothing."
  return 1
}

# FIXTURES RUN INSIDE A GUARDED ROOT (tools/fixture_guard.sh). Later mktemps land inside it,
# and a git on PATH refuses any write outside it. The guard exists because a failed mktemp
# once let a selftest run git init and commit in the real repo.
. "$(dirname "${BASH_SOURCE[0]}")/fixture_guard.sh" || { echo "context_survival: tools/fixture_guard.sh is missing; refusing to build fixtures" >&2; exit 1; }
fixture_root --keep-gh-token FG_ROOT; trap fg_cleanup EXIT
case "${1:-}" in
  --selftest)       selftest; exit $? ;;
  --prove-it-fails) prove_it_fails ;;
  "")               run ;;
  *) echo "usage: context_survival.sh [--selftest | --prove-it-fails]" >&2; exit 2 ;;
esac
