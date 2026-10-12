#!/usr/bin/env bash
# Project:  ai-project-scaffold
# File:     tools/release_status.sh
# Modified: 2026-10-09
# Version:  0.5.3.20261009.0902
# Purpose:  Say when shipped work has not been released, because an unreleased fix does not exist.
# Changelog:
#   2026-10-09 v0.5.3.20261009.0902 — selftest sourced fixture_guard.sh through the relative BASH_SOURCE after the load-time cd, so a monorepo-nested adoption failed before any case ran (#368). SELF_DIR is resolved before the cd now, and a nested-layout case invoked by relative path guards it.
#   2026-09-23 v0.5.2.20260923.0941 — fixtures run inside the root tools/fixture_guard.sh validates. There a git and a mktemp on PATH refuse anything that would land outside it. Every mktemp takes a ${TMPDIR} template, because macOS mktemp ignores TMPDIR without one.
#   2026-09-04 v0.5.1.20260904.0624 — --selftest could not find its own script in a monorepo-nested adoption.
#                        This file cd's to `git rev-parse --show-toplevel` at load, and SELF was
#                        re-derived from the still-RELATIVE BASH_SOURCE after that cd — so it
#                        looked for tools/ under the repository root, which in an apps/<app>/
#                        adoption has none. SELF became the literal /release_status.sh and all
#                        18 sub-checks failed. INVOKED_FROM is captured before the cd now.
#                        Every fixture here is a repo root, so the shape could not arise.
#   2026-08-16 v0.5.0.20260816.1151 — THE STAMP GATE HAD THE DEFECT IT WAS BUILT TO CATCH (#222,
#                        adopter). HHMM was compared as a STRING while the version key was
#                        compared numerically, and PEP 440 strips a leading zero -- the same
#                        release is 0928 as a git tag and 928 in packaging metadata. "928" <
#                        "1000" is False, so a backwards-ordered release PASSED the gate
#                        whose entire purpose is refusing one.
#                        LATENT ONLY BECAUSE EVERY FIXTURE WAS HAND-PADDED, which is the
#                        exact shape the adopter named: a fixture that encodes the defect it
#                        is meant to catch. The new case is deliberately unpadded and lives
#                        in its own repository so no earlier tag can shadow the baseline.
#                        Reverting to the string comparison now fails three cases.
#   2026-08-16 v0.4.0.20260816.0753 — A BASELINE THAT EXEMPTS EVERYTHING IS INERT, AND THE BASELINE
#                        MUST NOT TRAVEL (adopter report, this repo #220). AGENTS.md SHIPS.
#                        A column-0 declaration in it merged into an adopter with zero tags
#                        and version 0.1.0, where THIS repo's 0.43.0 baseline sits above
#                        every version they will ever cut -- so everything would be exempt
#                        forever and the gate would report on nothing. So: the scaffold
#                        keeps its own baseline in `.version-stamp-baseline`, a file
#                        adopters never receive, and that file outranks the shipped
#                        declaration. AGENTS.md now carries the RULE with an INDENTED
#                        example, which the tool ignores by construction.
#                        And the foreign case is named rather than silently honoured: a
#                        baseline naming no tag here, sitting above the current version, is
#                        reported as a GAP -- it cannot be describing this repo's history.
#   2026-08-15 v0.3.1.20260815.2014 — The baseline marker may carry ANY project prefix, not just
#                        `scaffold:`. localcoder declares `localcoder:version-stamp-baseline`
#                        because it hit this defect first and gates it in its OWN suite,
#                        which is stricter and product-owned. Matching only `scaffold:` made
#                        this report "stamp ordering is NOT checked" in the one repository
#                        that checks it hardest — a false statement whose obvious remedy is
#                        to declare a SECOND baseline, and two copies of one fact is the
#                        defect this tree has now paid for five times. Caught by asking what
#                        the new gate would say in the adopter, before the adopter upgraded.
#   2026-08-15 v0.3.0.20260815.1925 — THE STAMP GATE, ported from localcoder (#113, this repo's #217).
#                        This repository has the defect an adopter reported there: 0.39.5
#                        through 0.42.0 carry stamps one to two days AHEAD of the commits
#                        that made them, so the first release stamped truthfully sorts
#                        EARLIER than its predecessors. It was fixed there and not here, and
#                        it surfaced today by blocking a real release.
#                        BOTH HALVES, because either alone permits it: a stamp may not go
#                        backwards from the newest non-exempt tag, and may not sit in the
#                        future. When the two conflict a release is correctly BLOCKED until
#                        the calendar catches up.
#                        THE BASELINE IS ALSO THE FLOOR. The first release past it has no
#                        non-exempt predecessor, and comparing against an empty set would let
#                        any backdated stamp through — the hole localcoder shipped and had to
#                        close afterwards. Closed here from the start, and asserted.
#                        AN UNDECLARED BASELINE IS A GAP, NOT A PASS: a repo that has not
#                        opted in must not read as checked.
#   2026-08-16 v0.2.0.20260816.0700 — A REPO THAT DECLARES ITS PRODUCT DIRECTORIES IS BELIEVED.
#                        `tools setup.sh templates overlays` were added on top of every
#                        `scaffold:product-dir` declaration, which is the tool disagreeing with
#                        the declaration it just read. In `localcoder`, AGENTS.md states tools/
#                        is the VENDORED GOVERNANCE LAYER and adopters install with
#                        `uv tool install`, so they never receive it — and a vendored-scaffold
#                        upgrade reported a release due, costing a no-op 0.47.1.
#                        Reporting a release owed for a change nobody can receive trains people
#                        to cut releases without reading why, which is the habit that lets a
#                        REAL unreleased fix through. The default is unchanged for a repo that
#                        declares nothing; both arms are asserted, because "believed the
#                        declaration" and "counted nothing" print identically otherwise.
#   2026-08-15 v0.1.0 — New. THE PRODUCER SIDE OF A CHECK THAT ONLY EXISTED FOR CONSUMERS.
#                        `tools/scaffold_version.sh` tells an ADOPTER their vendored copy is
#                        stale. Nothing told the MAINTAINER they had not cut the release that
#                        adopter is waiting for, and the release process was a prose checklist
#                        in ai/PLANNING.md with nothing running it.
#
#                        Measured on 2026-08-14, when someone finally asked:
#                          ai-project-scaffold   9 unreleased commits touching shipped paths
#                          Robiton/localcoder   19 unreleased commits touching shipped paths,
#                                               and a `version` file 13 minor versions ahead
#                                               of the newest tag
#
#                        THE CONSEQUENCE IS NOT UNTIDINESS. `scaffold_upgrade.sh` resolves its
#                        target with `gh release view --json tagName`, so an adopter upgrading
#                        gets the newest RELEASE. Every fix in those commits — including
#                        `ci_status.sh` having never once reported a red CI — was unreachable
#                        by every adopter, and one of those adopters is the programme's primary
#                        review control, which reviews each tagged release.
#
#                        REPORTS, DOES NOT BLOCK, and that is deliberate. A repository is
#                        pushed many times per release; failing a push because a release is due
#                        would train people to bypass the gate, which is how the prose
#                        checklist stopped being read. It exits 1 only when asked to be strict.
set -u

# THE REPOSITORY YOU ARE STANDING IN, not the one this script was copied into. Same rule as
# tools/ci_status.sh, and for a sharper reason here: this file is vendored into every adopting
# project, so resolving from BASH_SOURCE would make an adopter's release status be reported as
# the scaffold's. It also made every selftest fixture below silently run against the real repo
# and report its numbers — six cases passing on the wrong subject, which is the composition
# defect this tree keeps finding.
# NO FALLBACK TO THE SCRIPT'S OWN REPO, and the first version had one. Outside a git tree it
# resolved ROOT from BASH_SOURCE and cheerfully reported the SCAFFOLD's release status to
# someone standing somewhere else — a confident answer about the wrong subject, which is worse
# than refusing. Caught by the case asserting exit 3, which the fallback turned into exit 0.
# THE DIRECTORY WE WERE INVOKED FROM, captured BEFORE the cd below. Everything that needs
# to resolve a relative path the caller typed — notably this script's own location — has to
# use this, not the post-cd cwd. See selftest().
INVOKED_FROM="$(pwd -P)"
# THIS SCRIPT'S OWN DIRECTORY, ABSOLUTE, for the same reason and at the same moment (#368).
# selftest() fixed SELF this way in 0.5.1 but still sourced fixture_guard.sh through the
# relative BASH_SOURCE after the cd, so a monorepo-nested adoption failed one line earlier.
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd -P)"
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [ -z "$ROOT" ] || ! cd "$ROOT" 2>/dev/null; then
  echo "release_status: not a git repository — NOT checked (exit 3)"
  exit 3
fi

STRICT=0
SELFTEST=0
for a in "$@"; do
  case "$a" in
    --strict)   STRICT=1 ;;
    --selftest) SELFTEST=1 ;;
    -h|--help)
      echo "usage: release_status.sh [--strict] [--selftest]"
      echo "  Reports unreleased work. --strict exits 1 when a release is overdue."
      exit 0 ;;
    *) echo "release_status.sh: unknown argument: $a" >&2; exit 2 ;;
  esac
done

# WHICH PATHS ARE THE PRODUCT — DERIVED FROM THE SAME MARKER preflight READS, never a second
# list. A hand-written path list here would drift from the one selftest discovery uses, and
# then this tool would report "nothing unreleased" for a repository whose product it could not
# see. That is the two-copies-of-one-fact defect this tree has now paid for three times.
PRODUCT_DIR_MARK='scaffold:product-dir'
product_paths() {
  local d found=0
  if [ -f AGENTS.md ]; then
    while IFS= read -r d; do
      [ -n "$d" ] || continue
      if [ -e "$d" ]; then printf '%s\n' "$d"; found=1; fi
    done < <(grep -oE "^<!--[[:space:]]*${PRODUCT_DIR_MARK}[[:space:]]+[^[:space:]]+" \
                  AGENTS.md 2>/dev/null | awk '{print $NF}')
  fi
  # A REPO THAT DECLARES ITS PRODUCT DIRECTORIES HAS ALREADY ANSWERED THIS QUESTION.
  #
  # These four are the right default for a repo that declares nothing — the scaffold itself
  # and any adopter whose shipped executables live in tools/. But adding them BEHIND the back
  # of a repo that declared `scaffold:product-dir` is the tool disagreeing with the
  # declaration it just read, and `tools/` is exactly where that goes wrong: in `localcoder`,
  # AGENTS.md states tools/ is the VENDORED GOVERNANCE LAYER and adopters install with
  # `uv tool install`, so they never receive it.
  #
  # MEASURED 2026-08-16: a vendored-scaffold upgrade touching only tools/ and setup.sh
  # reported "a release is due" in that repo, and a no-op 0.47.1 was cut to clear a gate that
  # was asking the wrong question. Reporting a release owed for a change no adopter can
  # receive trains people to cut releases without reading why — which is the habit that lets
  # a REAL unreleased fix through.
  #
  # So: declared wins. Undeclared keeps the default, unchanged.
  if [ "$found" = "1" ]; then
    return 0
  fi
  local p
  for p in tools setup.sh templates overlays; do
    [ -e "$p" ] && printf '%s\n' "$p"
  done
}

# THE NEWEST TAG AND THE NEWEST RELEASE ARE DIFFERENT FACTS. A tag with no GitHub release
# behind it is invisible to `scaffold_upgrade.sh`, which resolves with `gh release view` — so
# a maintainer who tags and forgets to release has shipped nothing, and every local check
# would call that state current.
latest_tag() { git tag --sort=-v:refname 2>/dev/null | head -1; }
latest_release() {
  command -v gh >/dev/null 2>&1 || return 0
  gh release view --json tagName --jq .tagName 2>/dev/null || true
}

# ---- THE TWO HALVES OF A VERSION MUST AGREE ABOUT WHICH RELEASE IS NEWER --------------
#
# `MAJOR.MINOR.PATCH.YYYYMMDD.HHMM` only works if sorting by version and sorting by
# timestamp give the same order. This repository broke that: 0.39.5 through 0.42.0 carry
# stamps one to two days AHEAD of the commits that made them, so the next release stamped
# truthfully sorts EARLIER than its predecessors. An adopter reported the identical defect
# against localcoder as #113, and it was fixed there and not here.
#
# Retagging is not available — those releases are published. So the breach is DECLARED via
# a baseline at column 0 in AGENTS.md, and the invariant is enforced from the next release
# onward. Everything at or below the baseline is exempt, and says so rather than passing
# quietly; everything above it must satisfy both halves.
#
# BOTH HALVES, because either one alone permits the defect: a stamp may not go BACKWARDS
# from the newest non-exempt tag (or ordering breaks) and may not sit in the FUTURE (or the
# next honest release inherits this same trap). When the two conflict, a release is
# correctly BLOCKED until the calendar catches up — which is the only honest state for a
# corpus that already contains a stamp from the future.
#
# THE BASELINE IS ALSO THE FLOOR. The first release past it has no non-exempt predecessor,
# so comparing against an empty set would let any backdated stamp through — a hole found
# and closed in localcoder after the first version shipped with it.
version_stamp_baseline() {
  # Column 0 only: an indented example is documentation, not a declaration.
  #
  # ANY PREFIX, NOT JUST `scaffold:`. localcoder declares
  # `<!-- localcoder:version-stamp-baseline ... -->` because it hit this defect first and
  # gates it in its OWN suite, which is stricter and product-owned. Matching only
  # `scaffold:` would make this report "stamp ordering is NOT checked" in the one
  # repository that checks it hardest — a false statement whose obvious remedy is to
  # declare a SECOND baseline, and two copies of one fact is the defect this tree has now
  # paid for five times. So the namespace is the project's to choose and the invariant is
  # shared.
  # `.version-stamp-baseline` FIRST, and it exists because AGENTS.md SHIPS. This file is
  # merged into every adopting project, so a column-0 declaration in it travels — carrying
  # THIS repository's baseline into a repo with zero tags, where it exempts every version
  # they will ever release and the gate reports [OK] while doing nothing. An adopter found
  # exactly that. So the scaffold keeps its own baseline in a file adopters never receive,
  # and AGENTS.md carries the RULE with an indented example that declares nothing.
  if [ -f "$ROOT/.version-stamp-baseline" ]; then
    tr -d '[:space:]' < "$ROOT/.version-stamp-baseline" 2>/dev/null
    return 0
  fi
  grep -m1 -E '^<!-- [A-Za-z0-9_-]+:version-stamp-baseline ' "$ROOT/AGENTS.md" 2>/dev/null \
    | awk '{print $3}'
}

# Sets STAMP_STATE to ok|exempt|gap|fail and STAMP_MSG to the reason.
stamp_check() {
  local base ver tags
  base="$(version_stamp_baseline)"
  ver="$(tr -d '[:space:]' < "$ROOT/version" 2>/dev/null || true)"
  tags="$(git tag --sort=-v:refname 2>/dev/null || true)"
  if [ -z "$ver" ]; then
    STAMP_STATE=gap; STAMP_MSG="no version file to check"; return 0
  fi
  if [ -z "$base" ]; then
    STAMP_STATE=gap
    STAMP_MSG="no baseline declared — stamp ordering is NOT checked. Declare one at column 0 in AGENTS.md:
        <!-- scaffold:version-stamp-baseline $ver -->"
    return 0
  fi
  local out
  out="$(BASE="$base" VER="$ver" TAGS="$tags" python3 - <<'PYSTAMP'
import os, datetime

def key(v):
    parts = v.split(".")
    out = []
    for p in parts:
        out.append(int(p) if p.isdigit() else 0)
    return tuple(out)

def stamp(v):
    # NUMERIC, NOT STRING. PEP 440 normalisation strips a leading zero, so the same release
    # is 0928 as a git tag and 928 in packaging metadata -- and "928" < "1000" is False,
    # which let a backwards-ordered release PASS the gate built to stop exactly that.
    # Reported by an adopter as #222. Latent only because every fixture and every value in
    # circulation had been hand-padded, which is the same shape as fixtures that encode the
    # defect they are meant to catch.
    p = v.split(".")
    if len(p) < 5:
        return None
    try:
        return (int(p[-2]), int(p[-1]))
    except ValueError:
        return None

base = os.environ["BASE"].strip()
ver = os.environ["VER"].strip()
tags = [t.strip() for t in os.environ["TAGS"].splitlines() if t.strip()]

if stamp(ver) is None:
    print("gap|version %s has no datestamp to check" % ver)
    raise SystemExit(0)

# NO APOSTROPHES BELOW THIS LINE. This block is a quoted heredoc inside $( ), and on the
# bash 3.2 that ships with macOS a lone apostrophe there swallows everything past the
# terminator — the error then surfaces on an unrelated line 200 lines later. Cost this
# project a session once already, and cost it again writing this very comment.
# AN INERT GATE MUST NOT REPORT [OK]. A repository with no tags has nothing to order, so a
# baseline there exempts everything and checks nothing — and it printed [OK] while doing
# it, which is worse than printing nothing. An adopter received the baseline of THIS repo
# through an AGENTS.md merge into a project with ZERO tags and version 0.1.0: every release
# they will ever cut sorts below it, forever.
if base not in tags and key(ver) <= key(base):
    print("gap|the declared baseline %s names no tag in this repository and sits above the "
          "current version %s, so every release this project cuts would be exempt and "
          "nothing would ever be checked" % (base, ver))
    raise SystemExit(0)
if key(ver) <= key(base):
    print("exempt|%s is at or below the declared baseline %s" % (ver, base))
    raise SystemExit(0)

# Non-exempt predecessors only; the baseline itself is the floor when there are none.
prev = [t for t in tags if key(t) > key(base) and key(t) < key(ver) and stamp(t)]
newest = max(prev, key=key) if prev else base
ns, vs = stamp(newest), stamp(ver)
now = datetime.datetime.now()
now_s = (int(now.strftime("%Y%m%d")), int(now.strftime("%H%M")))

if vs < ns:
    print("fail|%s is stamped %s.%04d, EARLIER than %s at %s.%04d. Sorting by version and "
          "by date would disagree." % (ver, vs[0], vs[1], newest, ns[0], ns[1]))
elif vs > now_s:
    print("fail|%s is stamped %s.%04d, which is in the FUTURE (now %s.%04d). A fabricated "
          "stamp is what caused this." % (ver, vs[0], vs[1], now_s[0], now_s[1]))
else:
    print("ok|%s stamped %s.%04d — not behind %s, not ahead of the clock"
          % (ver, vs[0], vs[1], newest))
PYSTAMP
)"
  STAMP_STATE="${out%%|*}"
  STAMP_MSG="${out#*|}"
}

report() {
  git rev-parse --git-dir >/dev/null 2>&1 || {
    echo "release_status: not a git repository — NOT checked (exit 3)"
    return 3
  }
  local tag ver rel n_all n_prod paths=()
  # Initialised because this script runs under `set -u`, and an unbound variable here would
  # abort the report AFTER printing most of it — a partial report that ends in a shell error
  # is the shape most likely to be read as "it finished".
  STAMP_STATE=""; STAMP_MSG=""; STAMP_BAD=0
  tag="$(latest_tag)"
  ver="$(cat version 2>/dev/null || true)"
  rel="$(latest_release)"

  echo "RELEASE STATUS — $(basename "$ROOT")"
  echo ""
  if [ -z "$tag" ]; then
    # A repo that has never tagged is a legitimate state and must not read as an error, but it
    # also must not read as "up to date". Say which it is.
    echo "  no tags in this repository."
    if [ -n "$ver" ]; then
      echo "  version file says $ver, and nothing has ever been released. If this repo ships"
      echo "  an artifact, the version file is a claim with no release behind it."
      return $([ "$STRICT" = "1" ] && echo 1 || echo 0)
    fi
    echo "  no version file either — consistent with a repo that ships nothing."
    return 0
  fi

  while IFS= read -r p; do [ -n "$p" ] && paths+=("$p"); done < <(product_paths)
  n_all="$(git rev-list "$tag..HEAD" --count 2>/dev/null || echo 0)"
  if [ "${#paths[@]}" -gt 0 ]; then
    n_prod="$(git rev-list "$tag..HEAD" --count -- "${paths[@]}" 2>/dev/null || echo 0)"
  else
    n_prod=0
  fi

  printf '  newest tag        %s\n' "$tag"
  printf '  newest release    %s\n' "${rel:-(gh unavailable or none — NOT checked)}"
  printf '  version file      %s\n' "${ver:-(none)}"
  printf '  commits since tag %s total, %s touching the product\n' "$n_all" "$n_prod"
  printf '  product paths     %s\n' "${paths[*]:-(none found)}"
  echo ""

  local overdue=0

  # A TAG WITH NO RELEASE SHIPS NOTHING. Checked before the commit count, because it is the
  # failure that looks most like success from inside the repository.
  if [ -n "$rel" ] && [ "$rel" != "$tag" ]; then
    echo "  [!] The newest tag is NOT the newest release."
    echo "      Adopters resolve upgrades with \`gh release view\`, so they are on $rel."
    echo "      $tag exists locally and ships to nobody."
    overdue=1
  fi

  # THE VERSION FILE IS A CLAIM. Ahead of the newest tag, it says a release happened that did
  # not. localcoder carried 0.38.0 against a newest tag of 0.25.0 — thirteen minor versions of
  # work that every adopter, including this programme's own review control, could not reach.
  if [ -n "$ver" ] && [ "$ver" != "$tag" ]; then
    echo "  [!] The version file and the newest tag disagree."
    echo "      version=$ver  tag=$tag"
    echo "      Either the release was never cut, or the tag was never pushed."
    overdue=1
  fi

  # ZERO IS PRINTED, and it is the reassuring case rather than the boring one. \"Nothing to
  # release\" and \"this tool could not see the product\" produce the same silence otherwise.
  if [ "$n_prod" -gt 0 ]; then
    echo "  [!] $n_prod commit(s) have changed the product since $tag and are unreleased."
    echo "      An unreleased fix does not exist as far as an adopter is concerned."
    git log --oneline "$tag..HEAD" -- "${paths[@]}" | sed 's/^/        /' | head -15
    local extra=$((n_prod - 15))
    [ "$extra" -gt 0 ] && echo "        ... and $extra more"
    overdue=1
  else
    echo "  [OK] no unreleased product commits."
  fi

  echo ""
  stamp_check
  case "$STAMP_STATE" in
    ok)     echo "  [OK] version stamp: $STAMP_MSG" ;;
    exempt) echo "  [OK] version stamp: $STAMP_MSG" ;;
    gap)    echo "  [GAP] version stamp: $STAMP_MSG" ;;
    fail)
      echo "  [!] VERSION STAMP: $STAMP_MSG"
      echo "      Sorting by version and sorting by date must give the same order —"
      echo "      every benchmark row and every envelope carries a version."
      echo "      A release is correctly BLOCKED until the calendar catches up."
      overdue=1
      STAMP_BAD=1
      ;;
  esac

  echo ""
  if [ "$overdue" = "1" ]; then
    if [ "$STAMP_BAD" = "1" ]; then
      echo "  A release is due, and the stamp above must be fixed first."
    else
      echo "  A release is due. ai/PLANNING.md -> Release checklist."
    fi
    [ "$STRICT" = "1" ] && return 1
    return 0
  fi
  echo "  Nothing to release."
  return 0
}

selftest() {
  local T fails=0 out got
  # FIXTURES RUN INSIDE A GUARDED ROOT (tools/fixture_guard.sh). Later mktemps land inside it,
  # and a git on PATH refuses any write outside it. The guard exists because a failed mktemp
  # once let a selftest run git init and commit in the real repo.
  . "$SELF_DIR/fixture_guard.sh" || { echo "release_status: tools/fixture_guard.sh is missing; refusing to build fixtures" >&2; exit 1; }
  fixture_root FG_ROOT; trap fg_cleanup EXIT
  T="$(mktemp -d "${TMPDIR:-/tmp}/release_status.XXXXXX")" || return 1
  # ABSOLUTE, resolved before any cd, because ROOT is now the fixture once we move.
  #
  # "BEFORE ANY cd" WAS NOT TRUE. This file already cd's to `git rev-parse --show-toplevel`
  # at load time — correct, so an adopter's release status is not reported as the scaffold's
  # — and BASH_SOURCE[0] is still the RELATIVE fragment the caller typed. Resolving it after
  # that cd looks for `tools/` under the repository ROOT, which in a monorepo-nested adoption
  # (`apps/<app>/`, and preflight invokes this by relative path) does not exist. The inner cd
  # failed, the subshell printed nothing, and SELF became the literal `/release_status.sh`:
  # all 18 sub-checks failed with "No such file or directory".
  #
  # Found by an acceptance test on a real monorepo adoption, not by anything here — every
  # fixture in this file is a repository root, so the shape could not arise.
  #
  # $0 is what the caller actually invoked and is unaffected by our cd; fall back to
  # BASH_SOURCE only when $0 is not usable (sourced rather than executed).
  local SELF _src
  _src="${BASH_SOURCE[0]:-$0}"
  case "$_src" in /*) : ;; *) _src="$INVOKED_FROM/$_src" ;; esac
  SELF="$_src"
  if [ ! -f "$SELF" ]; then
    echo "release_status: NOT MEASURED — cannot locate my own script (tried $SELF)" >&2
    return 3
  fi
  # The nested-layout case below re-enters --selftest only to prove it can get this far.
  if [ -n "${RELEASE_STATUS_PROBE:-}" ]; then echo "release_status: probe located its tools"; return 0; fi

  # EVERY CASE ASSERTS A NUMBER OR A NAMED STATE, never merely that the tool ran. A release
  # checker that always printed "nothing to release" would pass a runs-clean check and would
  # be the exact defect it exists to prevent.
  run_in() {  # run_in <dir> [args...]; echoes output, sets $got to the exit code
    local d="$1"; shift
    out="$( cd "$d" && bash "$SELF" "$@" 2>&1 )"; got=$?
  }
  case_is() {  # case_is <label> <must-contain>
    if printf '%s' "$out" | grep -qF "$2"; then printf '  ok   %-52s\n' "$1"
    else
      printf '  FAIL %-52s wanted: %s\n' "$1" "$2"
      printf '%s\n' "$out" | sed 's/^/         /' | head -8
      fails=$((fails + 1))
    fi
  }

  # 1. Not a git repository is exit 3 — could-not-run, never a pass.
  mkdir -p "$T/nogit"
  run_in "$T/nogit"
  if [ "$got" = "3" ]; then printf '  ok   %-52s\n' "outside git: exit 3, not a pass"
  else printf '  FAIL %-52s got %s\n' "outside git: exit 3, not a pass" "$got"; fails=$((fails+1)); fi

  # 1b. MONOREPO-NESTED, INVOKED BY RELATIVE PATH (#368). The git top level is the repo, the
  #     scaffold root is apps/<app>/, and preflight types `tools/release_status.sh`. Every
  #     other fixture here is a repository root, which is how this shape went unseen twice.
  local N="$T/mono"; mkdir -p "$N/app/tools"
  cp "$SELF" "$SELF_DIR/fixture_guard.sh" "$N/app/tools/"
  ( cd "$N" && git init -q . && git config user.email a@b.c && git config user.name t \
      && git add -A >/dev/null && git commit -qm init )
  out="$( cd "$N/app" && RELEASE_STATUS_PROBE=1 bash tools/release_status.sh --selftest 2>&1 )"
  case_is "nested component, relative path: finds its tools" "probe located its tools"

  # 2. A repo with a tag and NO product commits since reports zero — printed, not silent.
  local R="$T/clean"; mkdir -p "$R/tools"
  ( cd "$R" && git init -q . && git config user.email a@b.c && git config user.name t )
  printf '0.1.0.20260101.0000\n' > "$R/version"
  printf '#!/bin/sh\nexit 0\n' > "$R/tools/x.sh"
  ( cd "$R" && git add -A >/dev/null && git commit -qm init && git tag 0.1.0.20260101.0000 )
  run_in "$R"
  case_is "a released repo says zero, out loud" "[OK] no unreleased product commits."

  # 3. One commit touching tools/ makes it overdue, WITH THE COUNT. This is the pair that
  #    makes case 2 discriminating: without it, "always reports zero" would pass.
  printf '#!/bin/sh\necho changed\n' > "$R/tools/x.sh"
  ( cd "$R" && git add -A >/dev/null && git commit -qm "fix: something" )
  run_in "$R"
  case_is "one product commit is counted as one" "1 commit(s) have changed the product"

  # 4. --strict turns overdue into exit 1; the default stays 0 so a push is never blocked.
  run_in "$R"
  if [ "$got" = "0" ]; then printf '  ok   %-52s\n' "overdue is exit 0 by default (never blocks a push)"
  else printf '  FAIL %-52s got %s\n' "overdue is exit 0 by default" "$got"; fails=$((fails+1)); fi
  run_in "$R" --strict
  if [ "$got" = "1" ]; then printf '  ok   %-52s\n' "--strict makes overdue exit 1"
  else printf '  FAIL %-52s got %s\n' "--strict makes overdue exit 1" "$got"; fails=$((fails+1)); fi

  # 5. A commit that touches NOTHING shipped does not make a release due. Otherwise every
  #    session-log commit would demand a release and the signal would be discarded.
  local R2="$T/docsonly"; mkdir -p "$R2/tools" "$R2/ai"
  ( cd "$R2" && git init -q . && git config user.email a@b.c && git config user.name t )
  printf '0.1.0.20260101.0000\n' > "$R2/version"
  printf '#!/bin/sh\nexit 0\n' > "$R2/tools/x.sh"
  ( cd "$R2" && git add -A >/dev/null && git commit -qm init && git tag 0.1.0.20260101.0000 )
  printf 'notes\n' > "$R2/ai/SESSION.md"
  ( cd "$R2" && git add -A >/dev/null && git commit -qm "docs: session" )
  run_in "$R2"
  case_is "a docs-only commit does not demand a release" "[OK] no unreleased product commits."

  # 6. A version file ahead of the newest tag is called out on its own — the localcoder state,
  #    where 0.38.0 sat against a 0.25.0 tag through 29 commits.
  printf '0.9.0.20260102.0000\n' > "$R2/version"
  ( cd "$R2" && git add -A >/dev/null && git commit -qm "chore: bump" )
  run_in "$R2"
  case_is "version ahead of the tag is reported" "version file and the newest tag disagree"

  # 6b. A REPO THAT DECLARES ITS PRODUCT DIRECTORIES IS BELIEVED, and tools/ is not added
  #     behind its back. This is `localcoder`'s exact shape: product in src/, and AGENTS.md
  #     stating that tools/ is the vendored governance layer adopters never receive.
  #     MEASURED 2026-08-16 — a vendored-scaffold upgrade touching only tools/ reported a
  #     release due there, and a no-op release was cut to clear a gate asking the wrong
  #     question. Both arms are asserted, because "believed the declaration" and "counted
  #     nothing at all" print identically if you only look for the OK line.
  local R4="$T/declared"; mkdir -p "$R4/tools" "$R4/src/thing"
  ( cd "$R4" && git init -q . && git config user.email a@b.c && git config user.name t )
  printf '0.1.0.20260101.0000\n' > "$R4/version"
  printf '<!-- scaffold:product-dir src/thing -->\n' > "$R4/AGENTS.md"
  printf '#!/bin/sh\nexit 0\n' > "$R4/tools/vendored.sh"
  printf 'x = 1\n' > "$R4/src/thing/app.py"
  ( cd "$R4" && git add -A >/dev/null && git commit -qm init && git tag 0.1.0.20260101.0000 )
  printf '#!/bin/sh\necho upgraded\n' > "$R4/tools/vendored.sh"
  ( cd "$R4" && git add -A >/dev/null && git commit -qm "chore(scaffold): vendored upgrade" )
  run_in "$R4"
  case_is "a declared product dir is believed — tools/ is not added behind it" \
          "[OK] no unreleased product commits."
  # ...AND THE DECLARED DIRECTORY IS STILL WATCHED. Without this, "believe the declaration"
  # and "stop counting anything" are the same result.
  printf 'x = 2\n' > "$R4/src/thing/app.py"
  ( cd "$R4" && git add -A >/dev/null && git commit -qm "fix: real product change" )
  run_in "$R4"
  case_is "...and a change inside it still demands a release" \
          "1 commit(s) have changed the product"

  # 6b. VERSION STAMPS MUST ORDER THE SAME WAY VERSIONS DO. This is #113 as reported by an
  # adopter against localcoder, and present in this repository at 0.39.5 through 0.42.0.
  # Both halves are asserted, because either one alone permits the defect.
  local R5="$T/stamps"; mkdir -p "$R5/tools"
  ( cd "$R5" && git init -q . && git config user.email a@b.c && git config user.name t )
  printf '#!/bin/sh\nexit 0\n' > "$R5/tools/x.sh"
  printf '0.5.0.20260610.1200\n' > "$R5/version"
  printf '<!-- scaffold:version-stamp-baseline 0.5.0.20260610.1200 -->\n' > "$R5/AGENTS.md"
  ( cd "$R5" && git add -A >/dev/null && git commit -qm init \
      && git tag 0.5.0.20260610.1200 )
  run_in "$R5"
  case_is "a version at the baseline is exempt, and SAYS so" \
          "at or below the declared baseline"
  # BACKWARDS: the floor is the BASELINE when nothing non-exempt exists above it. Comparing
  # against an empty set here is the hole localcoder shipped and had to close.
  printf '0.6.0.20260101.0000\n' > "$R5/version"
  run_in "$R5"
  case_is "a backdated stamp above the baseline FAILS against the baseline as floor" \
          "EARLIER than 0.5.0.20260610.1200"
  # FUTURE: the half that stops this defect being recreated by the next maintainer.
  printf '0.6.0.21000101.0000\n' > "$R5/version"
  run_in "$R5"
  case_is "a stamp in the future FAILS" "is in the FUTURE"
  # AN UNPADDED HHMM MUST STILL ORDER (#222). PEP 440 strips the leading zero, so the same
  # release is 0928 as a git tag and 928 in packaging metadata. Comparing those as STRINGS
  # makes "928" < "1000" false and a backwards release PASSES the gate built to stop it.
  # THIS FIXTURE IS DELIBERATELY UNPADDED, in its own repo so no earlier tag can shadow the
  # baseline: every other fixture here is hand-written and therefore padded, which is
  # precisely why the defect survived -- the same shape as a fixture that encodes the bug it
  # is meant to catch.
  local R7="$T/unpadded"; mkdir -p "$R7/tools"
  ( cd "$R7" && git init -q . && git config user.email a@b.c && git config user.name t )
  printf '#!/bin/sh\nexit 0\n' > "$R7/tools/x.sh"
  printf '0.5.0.20260610.1000\n' > "$R7/version"
  printf '<!-- x:version-stamp-baseline 0.5.0.20260610.1000 -->\n' > "$R7/AGENTS.md"
  ( cd "$R7" && git add -A >/dev/null && git commit -qm init \
      && git tag 0.5.0.20260610.1000 )
  printf '0.6.0.20260610.928\n' > "$R7/version"
  run_in "$R7"
  case_is "an UNPADDED HHMM still compares numerically, not as a string" \
          "EARLIER than 0.5.0.20260610.1000"

  # A PROJECT MAY OWN THE NAMESPACE. localcoder declares `localcoder:` because it hit this
  # defect first and gates it in its own suite; matching only `scaffold:` would report
  # "NOT checked" in the repo that checks it hardest, and the obvious remedy for that
  # false message is a SECOND baseline to keep in sync.
  printf '<!-- someproject:version-stamp-baseline 0.5.0.20260610.1200 -->\n' > "$R5/AGENTS.md"
  printf '0.6.0.20260101.0000\n' > "$R5/version"
  run_in "$R5"
  case_is "a project-prefixed baseline is honoured, not ignored" \
          "EARLIER than 0.5.0.20260610.1200"

  # AN INERT GATE MUST NOT REPORT [OK] — the adopter case: a baseline arrives by merge into
  # a repo with ZERO tags, exempts every version they will ever cut, and prints OK.
  local R6="$T/foreign"; mkdir -p "$R6"
  ( cd "$R6" && git init -q . && git config user.email a@b.c && git config user.name t )
  printf '0.1.0.20260712.0708\n' > "$R6/version"
  printf '<!-- someproject:version-stamp-baseline 0.43.0.20260815.1925 -->\n' > "$R6/AGENTS.md"
  ( cd "$R6" && git add -A >/dev/null && git commit -qm init \
      && git tag 0.1.0.20260712.0708 )
  run_in "$R6"
  case_is "a foreign baseline that exempts everything is inert, and says so" \
          "names no tag in this repository"

  # THE NON-SHIPPED FILE WINS, because AGENTS.md ships and its declaration travels.
  # The file names the REAL tag; AGENTS.md names a foreign one. If AGENTS.md won, the
  # foreign-baseline guard above would fire instead and the message would differ.
  printf '0.5.0.20260610.1200\n' > "$R5/.version-stamp-baseline"
  printf '<!-- someproject:version-stamp-baseline 9.9.9.20200101.0000 -->\n' > "$R5/AGENTS.md"
  printf '0.5.0.20260610.1200\n' > "$R5/version"
  run_in "$R5"
  case_is ".version-stamp-baseline outranks the shipped AGENTS.md declaration" \
          "at or below the declared baseline 0.5.0.20260610.1200"
  rm -f "$R5/.version-stamp-baseline"

  # AND AN UNDECLARED BASELINE IS A GAP, NOT A PASS. A repo that has not opted in must not
  # read as checked — that is the all-clear-indistinguishable-from-silence defect.
  printf '<!-- nothing declared -->\n' > "$R5/AGENTS.md"
  printf '0.6.0.20260701.0000\n' > "$R5/version"
  run_in "$R5"
  case_is "no baseline declared reports a GAP, never a pass" \
          "[GAP] version stamp"

  # 7. A repo that never tagged is a state, not an error, and must not read as current.
  local R3="$T/untagged"; mkdir -p "$R3"
  ( cd "$R3" && git init -q . && git config user.email a@b.c && git config user.name t )
  printf 'x\n' > "$R3/README.md"
  ( cd "$R3" && git add -A >/dev/null && git commit -qm init )
  run_in "$R3"
  case_is "an untagged repo says so rather than 'up to date'" "no tags in this repository."

  rm -rf "$T"
  echo ""
  if [ "$fails" -eq 0 ]; then echo "  all checks passed"; return 0; fi
  echo "  $fails check(s) FAILED"
  return 1
}

if [ "$SELFTEST" = "1" ]; then
  selftest
  exit $?
fi
report
exit $?
