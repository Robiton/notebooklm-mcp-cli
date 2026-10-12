#!/usr/bin/env bash
# Project:  ai-project-scaffold
# File:     tools/dependency_audit.sh
# Modified: 2026-10-10
# Version:  0.3.4.20261010.1100
# Purpose:  Known vulnerabilities in the dependencies we actually declare — the one class a
#           scanner genuinely owns, reported so that "nothing found" and "nothing ran" can
#           never print the same way.
# Changelog:
#   2026-10-10 v0.3.4.20261010.1100 — every [libraries] entry is a coordinate or a counted skip (report item 17). The string form and the group/name form are read; an entry with no version in the catalog, or a version table, is listed [--] with its reason, and any skip ends in exit 3 rather than "N clean". --declared counts a catalog whose every entry is skipped.
#   2026-10-08 v0.3.3.20261008.1245 — the OSV query body is built by a JSON encoder, curl runs -fsS with the status read off -w, and any non-200 is NOT checked and ends in exit 3. A 400 with a JSON body used to read as a clean coordinate.
#   2026-09-24 v0.3.2.20260924.0416 — --declared: exit 0 when the tree declares a lockfile or a version catalog, 1 when it declares none. rc 3 joins "nothing to audit" and "could not audit"; CI's coverage marker needs them apart.
#   2026-09-23 v0.3.1.20260923.0941 — fixtures run inside the root tools/fixture_guard.sh validates. There a git and a mktemp on PATH refuse anything that would land outside it. Every mktemp takes a ${TMPDIR} template, because macOS mktemp ignores TMPDIR without one.
#   2026-08-30 v0.3.0.PENDING — TWO REGISTRIES, AND A SUMMARY THAT CANNOT ROUND UP. Staleness
#                        asked repo1.maven.org only; AndroidX does not publish to Central, so
#                        every androidx.* coordinate 404'd -- 4 of health-app's 7, the only repo
#                        here with a real dependency tree. kotlinx is the reverse case (Central
#                        200, Google 404), so both are genuinely required. Central first, Google
#                        on a miss, and the line now NAMES the registry that answered instead of
#                        asserting Central. Second and worse: those 4 [??] lines printed directly
#                        above "7 direct coordinate(s) clean" at rc 0 -- this file says a skip is
#                        not a pass in four places and then contradicted the four lines above it.
#                        staleness_line returns 2 when currency was not established, catalog_audit
#                        counts them, the summary refuses "clean" while any are outstanding. The
#                        EXIT CODE DOES NOT MOVE: staleness is not a vulnerability, a [..] line
#                        already never affects rc, and a registry hiccup must not fail builds.
#                        8 new selftests (26 total), one stubbing curl so every registry misses.
#   2026-08-30 v0.2.2.PENDING — `tail -1` PICKED A COMPAT VARIANT over the version it varies:
#                        kotlinx-datetime's list ends 0.8.0 then 0.8.0-0.6.x-compat, so "newest
#                        stable" was the compat artifact. Prefer a plain numeric version, fall
#                        back for artifacts like voyager that publish no plain form.
#   2026-08-30 v0.2.1.20260830.0719 — STALENESS FAIL-SILENT FIXED. An empty `latest` meant both
#                        "nothing newer" and "the lookup did not happen", and the guard read both as
#                        up to date. Observed live: three of four probes returned nothing on one run
#                        and everything on the next. Split into staleness_line() so the failure
#                        branches are testable without a network; 4 planted cases added.
#   2026-08-30 v0.2.0.20260830.0620 — VERSION-CATALOG MODE, which is the answer to "osv-scanner needs a
#                        lockfile and we have none". osv.dev answers by COORDINATE over HTTP,
#                        and a Gradle version catalog already names exact coordinates -- so the
#                        direct dependencies are auditable today, with no lockfile anywhere.
#                        Verified end to end against health-app's real catalog (7 coordinates,
#                        clean) and against a planted jackson-databind 2.9.8 (55 advisories),
#                        so a zero here is a real zero and not a broken request.
#                        HONEST ABOUT THE GAP: a catalog names DIRECT dependencies only. Most
#                        CVEs arrive transitively. This COMPLEMENTS dependency locking and
#                        stops being the best available answer the moment a lockfile exists.
#                        Staleness comes from maven-metadata.xml -- the artifact registry, not
#                        the source host -- with pre-releases filtered, because the first run
#                        told health-app it was behind an RC its own catalog says it refuses.
#   2026-08-30 v0.1.0 — Initial. Written after a week in which SEVEN real defects were found
#                        and an off-the-shelf shell linter would have caught NONE of them
#                        (tested against reproductions, not assumed). The conclusion was not
#                        "scanners are useless" but "scanners own exactly one class, and it is
#                        not the class we keep hitting". This is that one class.
#
# WHY THIS REPORTS "NOTHING TO SCAN" AS ITS OWN STATE
#
#   At the time of writing, an OSV scan of this repository finds nothing — not because the
#   dependencies are clean but because THERE ARE NONE. The scaffold declares no runtime
#   dependency and localcoder ships `dependencies = []` on purpose. A tool that printed a
#   green tick for that would be manufacturing assurance out of an empty set, and this
#   programme has been bitten by exactly that shape before: `ci_status.sh` reported no alerts
#   for months in three repositories where every alert feature was switched off, because zero
#   and not-enabled print identically if you only look for a number.
#
#   So there are three outcomes and they are not collapsed:
#     rc 0  scanned, and found nothing
#     rc 1  scanned, and found something          (only --strict turns this into a failure)
#     rc 3  DID NOT SCAN — no lockfile, or no scanner. Never reported as a pass.
#
# THE PREREQUISITE IS A LOCKFILE, NOT THIS SCRIPT
#
#   OSV reads Java through `gradle.lockfile`, `gradle/verification-metadata.xml` or
#   `pom.xml`. Gradle dependency locking is OPT-IN. Robiton/health-app -- the first project
#   here with a real dependency tree, and the one intended to be sold -- has none of those
#   files and has not enabled locking, so this script would scan an empty set in the only
#   repository where it currently matters. Enabling locking is the actual first move; this
#   script is what makes it pay off. It says so, out loud, rather than going green.
set -uo pipefail

SELF="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
ROOT="${DEPAUDIT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
MODE=check
STRICT=0

usage() {
  cat <<'USAGE'
dependency_audit.sh — known vulnerabilities in the dependencies we declare

  --check       (default) report and exit 0, even when something is found
  --strict      exit 1 when a vulnerability is found
  --list        list the lockfiles that would be scanned, and scan nothing
  --declared    exit 0 if this tree declares any dependency this tool reads (a lockfile
                or a version catalog), 1 if it declares none. Scans nothing. CI uses it
                to tell "nothing to audit" from "could not audit"; rc 3 is both
  --selftest    run the built-in cases
  -h, --help    this

Exit codes — the third one is the point:
  0   scanned, nothing found
  1   scanned, something found          (--strict only; --check still exits 0)
  3   DID NOT SCAN — no lockfile present, or osv-scanner not installed
  2   usage error

Registries consulted for staleness: Maven Central, then Google Maven (androidx).

Install the scanner:  brew install osv-scanner
                      https://github.com/google/osv-scanner  (Apache-2.0)
USAGE
}

# LOCKFILES OSV ACTUALLY PARSES. Taken from its own supported-lockfiles document rather than
# from memory; a name that is close but wrong here means a silent "nothing to scan".
LOCKFILES="gradle.lockfile buildscript-gradle.lockfile verification-metadata.xml pom.xml
package-lock.json pnpm-lock.yaml yarn.lock bun.lock
requirements.txt poetry.lock Pipfile.lock pdm.lock uv.lock
go.mod Cargo.lock composer.lock Gemfile.lock conan.lock mix.lock pubspec.lock renv.lock"

# TRACKED FILES ONLY. `find` would walk node_modules and vendor trees and hand the scanner a
# transitive forest that nobody chose -- the same distinction ai/PROVENANCE.md draws when it
# says the lockfile is the record and its contents are not.
discover() {  # discover <root>
  local root="$1" f base
  ( cd "$root" 2>/dev/null || return 0
    git ls-files 2>/dev/null || true ) | while IFS= read -r f; do
      [ -n "$f" ] || continue
      base="$(basename "$f")"
      case " $(echo $LOCKFILES | tr '\n' ' ') " in
        *" $base "*) printf '%s\n' "$f" ;;
      esac
    done
}

# THE ANSWER TO "OSV-SCANNER NEEDS A LOCKFILE AND WE HAVE NONE".
#
# osv-scanner reads lockfiles. Gradle dependency locking is opt-in, health-app has not enabled
# it, and every other repository here declares no dependencies at all -- so the scanner path
# reports "nothing to scan" in the one place it matters. That is honest and useless.
#
# A Gradle VERSION CATALOG already names exact coordinates, and osv.dev answers queries by
# coordinate over HTTP with no lockfile anywhere:
#     POST https://api.osv.dev/v1/query  {"package":{"name":"g:a","ecosystem":"Maven"},"version":"1.2.3"}
# Verified against a known-bad artifact before this was written: jackson-databind 2.9.8
# returns 55 advisories, so a zero here is a real zero and not a broken request.
#
# WHAT THIS DOES NOT COVER, said plainly because the gap is the whole reason lockfiles exist:
# a catalog names DIRECT, CHOSEN dependencies. It says nothing about the transitive tree
# beneath them, and most real CVEs arrive transitively. This is a COMPLEMENT to locking, not a
# replacement -- it is what can be checked today, and it stops being the best available answer
# the moment a lockfile exists.
# EVERY [libraries] ENTRY IS EITHER A COORDINATE OR A COUNTED SKIP (report item 17). The first
# parser read only `alias = { module = ..., version... }` and dropped everything else without
# a word: the string form `alias = "g:a:v"`, the `group = / name =` form, and any entry whose
# version a BOM or a platform supplies. Then the summary said "N clean" over a set it had
# silently made smaller. The two string forms are coordinates now; what still cannot be
# queried -- no version in the catalog, or a version table -- is listed with the reason.
catalog_parse() {  # catalog_parse <root> <coords|skips>
  local root="$1" mode="$2" cat
  cat="$( cd "$root" 2>/dev/null && git ls-files 2>/dev/null | grep -E '(^|/)libs\.versions\.toml$' | head -1 )"
  [ -n "$cat" ] || return 1
  python3 - "$root/$cat" "$mode" <<'PYCAT'
import re, sys, io
try:
    t = io.open(sys.argv[1], encoding="utf-8").read()
except Exception:
    raise SystemExit(1)
mode = sys.argv[2]
vsec = t.split("[versions]")[-1].split("[libraries]")[0] if "[versions]" in t else ""
vers = dict(re.findall(r'^([A-Za-z0-9_-]+)\s*=\s*"([^"]+)"', vsec, re.M))
lsec = t.split("[libraries]")[-1] if "[libraries]" in t else ""
lsec = re.split(r'^\[', lsec, maxsplit=1, flags=re.M)[0]
for alias, rhs in re.findall(r'^([A-Za-z0-9_.-]+)\s*=\s*(.+)$', lsec, re.M):
    rhs = rhs.strip()
    ga = v = why = None
    if rhs.startswith('"'):
        parts = rhs.strip('"').split(":")
        ga = ":".join(parts[:2]) if len(parts) >= 2 else None
        v = parts[2] if len(parts) >= 3 else None
        if not ga:
            why = "not a group:artifact string"
    elif rhs.startswith("{"):
        body = rhs
        m = re.search(r'module\s*=\s*"([^"]+)"', body)
        g = re.search(r'group\s*=\s*"([^"]+)"', body)
        n = re.search(r'name\s*=\s*"([^"]+)"', body)
        ga = m.group(1) if m else ("%s:%s" % (g.group(1), n.group(1)) if g and n else None)
        vr = re.search(r'version\.ref\s*=\s*"([^"]+)"', body)
        vl = re.search(r'version\s*=\s*"([^"]+)"', body)
        if not ga:
            why = "no module, and no group and name"
        elif vr:
            v = vers.get(vr.group(1))
            if not v:
                why = "version.ref %s is not in [versions]" % vr.group(1)
        elif vl:
            v = vl.group(1)
        elif re.search(r'version\s*=\s*\{', body):
            why = "a version table (strictly/require/prefer), not one version"
    else:
        why = "not a string or an inline table"
    if ga and v is None and not why:
        why = "no version in the catalog (a BOM or platform supplies it)"
    if why:
        if mode == "skips":
            print("%s\t%s" % (alias, why))
    elif mode == "coords":
        print("%s\t%s" % (ga, v))
PYCAT
}
catalog_coords() { catalog_parse "$1" coords; }  # catalog_coords <root>
catalog_skips()  { catalog_parse "$1" skips; }   # catalog_skips <root>

# staleness_line <ga> <ver> <metadata-xml-or-empty>
#
# SPLIT OUT FROM THE FETCH SO ITS FAILURE BRANCHES CAN BE TESTED WITHOUT A NETWORK. Every
# branch below is reachable from a string, which is the only reason the selftests can plant
# them.
#
# THE DEFECT THIS FIXES, observed live 2026-08-30: `latest` empty meant two different things
# -- "Maven Central has nothing newer" and "the lookup never happened" -- and the old guard
# `[ -n "$latest" ]` silently treated both as up to date. On one probe run three of four
# coordinates returned nothing (transient), and the check printed exactly what it prints when
# a project is current. A SKIP IS NOT A PASS, which this file already says in three other
# places about the scan and did not say about the staleness line.
# RETURNS 2 WHEN STALENESS WAS NOT DETERMINED, 0 WHEN IT WAS. The caller counts the 2s and
# the summary refuses to say "clean" if any came back. Before this, an unchecked coordinate
# printed [??] on its own line and then vanished from the total -- per-item honesty that did
# not survive into the aggregate, which is the same defect as a green tick one level up.
staleness_line() {
  local ga="$1" ver="$2" meta="$3" src="${4:-the registry}" latest
  if [ -z "$meta" ]; then
    echo "    [??] $ga:$ver — staleness NOT checked, not found on Maven Central or Google Maven"
    return 2
  fi
  # PICKING "NEWEST" NEEDS A COMPARISON, NOT A SHAPE TEST. Two wrong answers got here first,
  # both the same error -- something correlated with newest, substituted for newest:
  #
  #   `tail -1` (document order)  -> kotlinx-datetime ends 0.8.0 then 0.8.0-0.6.x-compat, and
  #                                  the COMPAT VARIANT of 0.8.0 was reported as newer than it.
  #                                  Maven's own <release> says the same wrong thing.
  #   "prefer a plain numeric"    -> my fix for the above. It then picked voyager's stale 1.0.1
  #                                  over 2.2.21-1.10.3, because voyager's current line is
  #                                  hyphenated (the suffix is the Compose version) and its
  #                                  plain-numeric releases are two years old. Caught by running
  #                                  it against real coordinates rather than by the selftests.
  #
  # So: compare the LEADING NUMERIC CORE numerically, and use the suffix only to break a tie --
  # where a bare version beats a suffixed one carrying the same core. That gets all three real
  # shapes right: 0.8.0 over 0.8.0-0.6.x-compat, 2.2.21-1.10.3 over 1.0.1, and 7.0.9 for a
  # project whose newest publish is a filtered milestone.
  local cands
  cands="$(printf '%s' "$meta" | tr '<' '\n' | sed -n 's:^versions*>::p' \
           | grep -viE 'rc|alpha|beta|-m[0-9]|snapshot|-dev|-eap')"
  latest="$(printf '%s' "$cands" | python3 -c '
import sys, re
best = bestkey = None
for line in sys.stdin:
    v = line.strip()
    if not v:
        continue
    m = re.match(r"^(\d+(?:\.\d+)*)", v)
    if not m:
        continue
    key = (tuple(int(x) for x in m.group(1).split(".")), 1 if m.group(0) == v else 0)
    if bestkey is None or key > bestkey:
        bestkey, best = key, v
print(best or "")
' 2>/dev/null)"
  if [ -z "$latest" ]; then
    # A 200 that parses to no stable version. Reported rather than swallowed: it is either a
    # library that has only ever shipped pre-releases, or the filter above is wrong for it.
    echo "    [??] $ga:$ver — staleness NOT checked, no STABLE version in the metadata"
    return 2
  elif [ "$latest" != "$ver" ]; then
    # NAME THE REGISTRY THAT ANSWERED. "newest on Maven Central" was wrong for every androidx
    # coordinate once Google Maven became a source, and a line that misattributes its own
    # evidence is the kind that gets argued with instead of acted on.
    echo "    [..] $ga:$ver — newest STABLE on $src is $latest"
  fi
  return 0
}

# THE REQUEST BODY IS BUILT BY A JSON ENCODER, NOT BY STRING INTERPOLATION (audit
# 2026-10-08). A coordinate is text out of a file in the repository being audited, and
# pasting it between quotes let a `"` or a `\` rewrite the query: at best a 400, at worst a
# question about a different package whose clean answer was then reported for this one.
osv_body() {  # osv_body <group:artifact> <version>
  python3 -c 'import json,sys; print(json.dumps({"package":{"name":sys.argv[1],"ecosystem":"Maven"},"version":sys.argv[2]}))' "$1" "$2"
}

catalog_audit() {  # catalog_audit <root>
  local root="$1" coords n hits=0 checked=0 unchecked=0 noquery=0 ga ver body vulns meta meta_src ga_path reg reg_url reg_name resp code skips nskip alias why
  coords="$(catalog_coords "$root")" || return 9
  skips="$(catalog_skips "$root" 2>/dev/null)" || skips=""
  n="$(printf '%s' "$coords" | grep -c . 2>/dev/null || true)"; n="${n:-0}"
  nskip="$(printf '%s' "$skips" | grep -c . 2>/dev/null || true)"; nskip="${nskip:-0}"
  if [ "$n" -eq 0 ] && [ "$nskip" -gt 0 ]; then
    echo "dependency_audit: DID NOT SCAN — the version catalog has $nskip entr(ies) and none names a version to query."
    printf '%s\n' "$skips" | while IFS="$(printf '\t')" read -r alias why; do echo "    [--] $alias — $why"; done
    return 3
  fi
  [ "$n" -gt 0 ] || return 9

  if ! command -v curl >/dev/null 2>&1; then
    echo "dependency_audit: DID NOT SCAN — a version catalog was found but curl is unavailable."
    return 3
  fi
  # ONE REACHABILITY PROBE BEFORE THE LOOP. Without it, an offline machine reports every
  # coordinate as clean -- N separate silent failures adding up to a green tick.
  if ! curl -s --max-time 12 -o /dev/null -w '' "https://api.osv.dev/v1/query" \
        -X POST -H 'Content-Type: application/json' -d '{}' 2>/dev/null; then
    echo "dependency_audit: DID NOT SCAN — osv.dev is unreachable, so $n coordinate(s) went unchecked."
    echo "    An unreachable database is not a clean result."
    return 3
  fi

  echo "dependency_audit: no lockfile — auditing $n DIRECT coordinate(s) from the version catalog"
  echo "    (direct dependencies only; the transitive tree is NOT covered — that needs a lockfile)"
  while IFS="$(printf '\t')" read -r ga ver; do
    [ -n "$ga" ] || continue
    checked=$((checked + 1))
    # ONLY A 200 IS AN ANSWER (audit 2026-10-08). This was `curl -s` with no status check, so
    # a 400 or a 429 whose body was JSON -- {"code":3,"message":...} -- parsed, held no
    # "vulns" key, and was reported as a clean coordinate. -f makes curl fail on >= 400 and
    # -w puts the status on the last line, so anything but 200 is "not checked", and the
    # run ends in exit 3 rather than in a green built from an error page.
    resp="$(curl -fsS --max-time 20 -w '\n%{http_code}' -X POST "https://api.osv.dev/v1/query" \
      -H 'Content-Type: application/json' \
      -d "$(osv_body "$ga" "$ver")" 2>/dev/null)" || true
    code="${resp##*$'\n'}"; body="${resp%$'\n'*}"
    [ "$code" = "200" ] || body=""
    # THREE IDS AND A COUNT, NOT FIFTY-FIVE. jackson-databind 2.9.8 returns 55 advisories and
    # printing them all put one unreadable line in the report -- which is the same defect as a
    # gate nobody reads, arrived at from the other direction.
    vulns="$(printf '%s' "$body" | python3 -c 'import sys,json
try: d=json.load(sys.stdin)
except Exception: print("ERR"); raise SystemExit
v=[x.get("id","?") for x in d.get("vulns",[])]
if not v: print("")
elif len(v)<=3: print(", ".join(v))
else: print("%s and %d more" % (", ".join(v[:3]), len(v)-3))' 2>/dev/null)"
    if [ "$code" != "200" ]; then
      echo "    [??] $ga:$ver — osv.dev answered HTTP ${code:-nothing}, NOT checked"
      noquery=$((noquery + 1))
    elif [ "$vulns" = "ERR" ]; then
      echo "    [??] $ga:$ver — osv.dev's 200 did not parse as JSON, NOT checked"
      noquery=$((noquery + 1))
    elif [ -n "$vulns" ]; then
      echo "    [!!] $ga:$ver — $vulns"
      hits=$((hits + 1))
    fi
    # STALENESS, from the artifact registry rather than the source host. A repo can tag a
    # version it never published, or publish constantly and tag nothing.
    #
    # PRE-RELEASES ARE FILTERED, and that is not fastidiousness. The first run of this check
    # told health-app that kotlin-test 2.4.10 was behind 2.4.20-RC2 -- while that project's own
    # version catalog says, at the top, "Newest STABLE of each: Kotlin 2.4.20-Beta2 exists and
    # is deliberately not used." A staleness line that argues with a decision already taken and
    # written down is noise, and noise is how a check earns the habit of being scrolled past.
    # -f, so an HTTP 404 is an EMPTY body and a failure rather than an error page that
    # parses to zero versions. Both end up reported; this keeps the reason accurate.
    #
    # TWO REGISTRIES, BECAUSE ANDROIDX IS NOT ON MAVEN CENTRAL. Measured 2026-08-30 against
    # Robiton/health-app: repo1.maven.org returns 404 for EVERY androidx.* coordinate, because
    # AndroidX publishes to Google's Maven repo and not to Central. On an Android/KMP project
    # -- which health-app is, and which is the only repo here with a real dependency tree --
    # that meant the staleness check printed "[??] lookup failed" for the majority of the tree
    # while the summary line underneath still said "clean". The registry was wrong, not the
    # coordinates. Central stays FIRST because it is the general case and answers for kotlinx,
    # kotlin, junit and everything else; Google is consulted only when Central misses, so the
    # common path still costs one request.
    meta=""; meta_src=""
    ga_path="$(printf '%s' "$ga" | sed 's|:|/|; s|\.|/|g')"
    for reg in "https://repo1.maven.org/maven2|Maven Central" \
               "https://dl.google.com/dl/android/maven2|Google Maven"; do
      reg_url="${reg%%|*}"; reg_name="${reg##*|}"
      meta="$(curl -sf --max-time 15 "$reg_url/$ga_path/maven-metadata.xml" 2>/dev/null || true)"
      if [ -n "$meta" ]; then meta_src="$reg_name"; break; fi
    done
    staleness_line "$ga" "$ver" "$meta" "$meta_src"
    # `|| true` so a FALSE test is not the last statement of the loop body: under an
    # inherited `-e` that aborts the whole audit mid-tree, and silently.
    [ $? -eq 2 ] && unchecked=$((unchecked + 1)) || true
  done <<EOFCOORDS
$coords
EOFCOORDS
  if [ "$nskip" -gt 0 ]; then
    printf '%s\n' "$skips" | while IFS="$(printf '\t')" read -r alias why; do
      echo "    [--] $alias — NOT audited: $why"
    done
  fi

  if [ "$hits" -gt 0 ]; then
    echo "dependency_audit: $hits of $checked direct coordinate(s) need attention"
    [ "$noquery" -gt 0 ] && \
      echo "    ...and $noquery of $checked were NOT queried at all — unknown, not clean."
    [ "$unchecked" -gt 0 ] && \
      echo "    ...and staleness was NOT checked for $unchecked of $checked — that part is unknown, not clean."
    [ "$nskip" -gt 0 ] && \
      echo "    ...and $nskip catalog entr(ies) were NOT audited at all (listed [--] above)."
    return 1
  fi
  # A QUERY THAT DID NOT ANSWER IS A SCAN THAT DID NOT RUN. Exit 3, the same as an
  # unreachable osv.dev: the vulnerability question went unasked for those coordinates.
  if [ "$noquery" -gt 0 ]; then
    echo "dependency_audit: DID NOT SCAN $noquery of $checked direct coordinate(s) — osv.dev did not answer 200."
    echo "    A failed query is not a clean result."
    return 3
  fi
  # A SKIPPED ENTRY IS A QUESTION NOBODY ASKED. Exit 3 for the same reason as a failed query:
  # "N clean" over a set the parser made smaller is a green built from an omission.
  if [ "$nskip" -gt 0 ]; then
    echo "dependency_audit: $checked direct coordinate(s) have no known vulnerabilities, but"
    echo "    $nskip catalog entr(ies) were NOT audited (listed [--] above) — NOT a clean result."
    echo "    Pin their versions in the catalog, or commit gradle.lockfile, to cover them."
    return 3
  fi
  # THE SUMMARY MAY NOT ROUND UP. Every [??] line above is a coordinate whose currency nobody
  # established, and a total that says "clean" while those lines sit above it is the same
  # manufactured assurance this file rejects everywhere else -- the per-item honesty has to
  # survive into the aggregate or it was decorative.
  #
  # THE EXIT CODE DELIBERATELY DOES NOT MOVE. A staleness gap is not a vulnerability: the OSV
  # query is what rc 0/1 reports on and it succeeded for all $checked. A newer-version line
  # already never affects rc, so an unknown-version line must not either, or a registry hiccup
  # starts failing builds and the check becomes the noise it filters pre-releases to avoid.
  if [ "$unchecked" -gt 0 ]; then
    echo "dependency_audit: $checked direct coordinate(s) have no known vulnerabilities,"
    echo "    but staleness was NOT checked for $unchecked of them — NOT a clean result."
    echo "    Transitives are NOT covered either; that needs a lockfile."
    return 0
  fi
  echo "dependency_audit: $checked direct coordinate(s) clean — transitives NOT covered"
  return 0
}

run_audit() {  # run_audit <root>
  local root="$1" found scanner_missing=0 n
  found="$(discover "$root")"
  n="$(printf '%s' "$found" | grep -c . 2>/dev/null || true)"; n="${n:-0}"

  if [ "$n" -eq 0 ]; then
    # NO LOCKFILE IS NOT THE END OF THE ROAD. A version catalog names direct coordinates and
    # osv.dev answers by coordinate, so the honest answer is "partial", not "nothing".
    catalog_audit "$root"; local crc=$?
    [ "$crc" -ne 9 ] && return "$crc"
    echo "dependency_audit: NOTHING TO SCAN — no lockfile and no version catalog in the tracked tree."
    echo "    This is not a clean bill of health. It means no dependency is DECLARED"
    echo "    anywhere this tool can read, so nothing was checked."
    echo "    If this project has dependencies, the lockfile is the missing piece:"
    echo "      Gradle  — dependency locking is opt-in; enable it, then commit gradle.lockfile"
    echo "      npm/pip — commit the lockfile rather than gitignoring it"
    return 3
  fi

  echo "dependency_audit: $n lockfile(s) to scan"
  printf '%s\n' "$found" | sed 's/^/    /'

  if ! command -v osv-scanner >/dev/null 2>&1; then
    scanner_missing=1
  fi
  if [ "$scanner_missing" -eq 1 ]; then
    echo "dependency_audit: DID NOT SCAN — osv-scanner is not installed."
    echo "    $n lockfile(s) went unchecked. A missing scanner is not a clean result."
    echo "    brew install osv-scanner    (Apache-2.0, google/osv-scanner)"
    return 3
  fi

  local out rc
  out="$( cd "$root" && osv-scanner scan source --recursive . 2>&1 )"; rc=$?
  # osv-scanner: 0 = nothing found, 1 = vulnerabilities found, >1 = it could not run.
  if [ "$rc" -gt 1 ]; then
    echo "dependency_audit: DID NOT SCAN — osv-scanner exited $rc"
    printf '%s\n' "$out" | tail -12 | sed 's/^/    /'
    return 3
  fi
  if [ "$rc" -eq 0 ]; then
    echo "dependency_audit: scanned $n lockfile(s) — no known vulnerabilities"
    return 0
  fi
  echo "dependency_audit: VULNERABILITIES FOUND"
  printf '%s\n' "$out" | sed 's/^/    /'
  return 1
}

# DOES THIS TREE DECLARE ANYTHING WE CAN READ? The same test run_audit() applies before it
# prints NOTHING TO SCAN, and NOT a verdict. It exists for CI's coverage marker. rc 3 means
# both "nothing is declared" and "declared, but no scanner". A fleet where every leg says
# the first has nothing to audit. A fleet where every leg says the second audited nothing
# it was given. Only the second may fail the fleet-wide coverage check.
declared() {  # declared <root>
  local root="$1" found coords
  found="$(discover "$root")"
  if [ -n "$found" ]; then
    printf 'lockfile: %s\n' $found
    return 0
  fi
  coords="$(catalog_coords "$root" 2>/dev/null)" || coords=""
  if [ -z "$coords" ]; then coords="$(catalog_skips "$root" 2>/dev/null)" || coords=""; fi
  if [ -n "$coords" ]; then
    echo "version catalog: $(printf '%s\n' "$coords" | grep -c .) entr(ies)"
    return 0
  fi
  echo "nothing declared: no lockfile and no version catalog in the tracked tree"
  return 1
}

selftest() {
  local fails=0 T rc out
  # FIXTURES RUN INSIDE A GUARDED ROOT (tools/fixture_guard.sh). Later mktemps land inside it,
  # and a git on PATH refuses any write outside it. The guard exists because a failed mktemp
  # once let a selftest run git init and commit in the real repo.
  . "$(dirname "${BASH_SOURCE[0]}")/fixture_guard.sh" || { echo "dependency_audit: tools/fixture_guard.sh is missing; refusing to build fixtures" >&2; exit 1; }
  fixture_root FG_ROOT; trap fg_cleanup EXIT
  T="$(mktemp -d "${TMPDIR:-/tmp}/depaudit-st.XXXXXX")" || exit 1
  ck() { if [ "$2" = "$3" ]; then printf '  ok   %-58s\n' "$1"
         else printf '  FAIL %-58s want=%s got=%s\n' "$1" "$2" "$3"; fails=$((fails+1)); fi; }

  echo "dependency_audit selftest"

  # A REPO WITH NO LOCKFILE MUST NOT REPORT SUCCESS. This is the whole reason the script
  # exists in this shape: at the time of writing it is the state of every repository here,
  # and a green tick for it would be a lie told in four places at once.
  mkdir -p "$T/empty" && ( cd "$T/empty" && git init -q . && : > README.md && git add -A \
    && git -c user.email=a@b -c user.name=t commit -qm init ) >/dev/null 2>&1
  out="$( run_audit "$T/empty" 2>&1 )"; rc=$?
  ck "no lockfile is rc 3, not rc 0" 3 "$rc"
  case "$out" in *"NOTHING TO SCAN"*) ck "...and it says so in words" 1 1 ;;
                 *) ck "...and it says so in words" 1 0 ;; esac
  case "$out" in *"not a clean bill of health"*) ck "...and refuses to be read as a pass" 1 1 ;;
                 *) ck "...and refuses to be read as a pass" 1 0 ;; esac

  # PLANT A LOCKFILE. Discovery must find it; and with no scanner installed the answer is
  # still 3, never 0 -- "we could not look" and "we looked and it was fine" are different
  # facts and this programme has shipped the bug of printing them identically.
  mkdir -p "$T/withlock" && ( cd "$T/withlock" && git init -q . \
    && printf '{"name":"x","lockfileVersion":3}\n' > package-lock.json \
    && git add -A && git -c user.email=a@b -c user.name=t commit -qm init ) >/dev/null 2>&1
  ck "a planted package-lock.json is discovered" "package-lock.json" "$(discover "$T/withlock")"
  if ! command -v osv-scanner >/dev/null 2>&1; then
    out="$( run_audit "$T/withlock" 2>&1 )"; rc=$?
    ck "a lockfile with no scanner is rc 3, not rc 0" 3 "$rc"
    case "$out" in *"not a clean result"*) ck "...and names the unchecked file count" 1 1 ;;
                   *) ck "...and names the unchecked file count" 1 0 ;; esac
  else
    ck "scanner present — live scan path exercised in CI, not here" 1 1
  fi

  # --declared SPLITS WHAT rc 3 JOINS. Both trees above give rc 3 without a scanner. Only
  # one of them has something to audit.
  rc=0; declared "$T/empty" >/dev/null 2>&1 || rc=$?
  ck "--declared: no lockfile, no catalog -> 1 (nothing to audit)" 1 "$rc"
  rc=0; declared "$T/withlock" >/dev/null 2>&1 || rc=$?
  ck "--declared: a tracked lockfile -> 0 (something to audit)" 0 "$rc"
  mkdir -p "$T/withcat/gradle" && ( cd "$T/withcat" && git init -q . \
    && printf '[versions]\nj = "2.9.8"\n[libraries]\njd = { module = "com.fasterxml.jackson.core:jackson-databind", version.ref = "j" }\n' > gradle/libs.versions.toml \
    && git add -A && git -c user.email=a@b -c user.name=t commit -qm init ) >/dev/null 2>&1
  rc=0; declared "$T/withcat" >/dev/null 2>&1 || rc=$?
  ck "--declared: a version catalog with a coordinate -> 0" 0 "$rc"
  mkdir -p "$T/untracked" && ( cd "$T/untracked" && git init -q . && : > README.md && git add -A \
    && git -c user.email=a@b -c user.name=t commit -qm init \
    && printf '{"lockfileVersion":3}\n' > package-lock.json ) >/dev/null 2>&1
  rc=0; declared "$T/untracked" >/dev/null 2>&1 || rc=$?
  ck "--declared: an UNTRACKED lockfile does not count -> 1" 1 "$rc"

  # STALENESS: A SKIP MUST NOT LOOK LIKE A PASS. These four plant the defect directly --
  # staleness_line takes the metadata as a STRING precisely so the failure branches are
  # reachable with no network, which is what made the original bug untestable and therefore
  # unnoticed. Case 3 uses the REAL shape of org.springframework:spring-core, whose newest
  # published version is a dotted milestone (7.1.0-M1) sitting after the stable line.
  out="$( staleness_line g:a 1.0.0 "" )"
  case "$out" in *"staleness NOT checked"*) ck "empty metadata says NOT CHECKED, not silence" 1 1 ;;
                 *) ck "empty metadata says NOT CHECKED, not silence" 1 0 ;; esac

  out="$( staleness_line g:a 1.0.0 "<versions><version>2.0-alpha1</version><version>2.0-RC2</version></versions>" )"
  case "$out" in *"no STABLE version"*) ck "all-prerelease metadata says NOT CHECKED" 1 1 ;;
                 *) ck "all-prerelease metadata says NOT CHECKED" 1 0 ;; esac

  out="$( staleness_line org.springframework:spring-core 7.0.1 \
          "<versions><version>7.0.8</version><version>7.0.9</version><version>7.1.0-M1</version></versions>" )"
  case "$out" in *"is 7.0.9"*) ck "a dotted milestone is filtered, 7.0.9 wins" 1 1 ;;
                 *) ck "a dotted milestone is filtered, 7.0.9 wins" 1 0 ;; esac

  # THE REAL kotlinx-datetime TAIL. A compat variant sorts last and is not newer.
  out="$( staleness_line org.jetbrains.kotlinx:kotlinx-datetime 0.8.0 \
          "<versions><version>0.8.0-rc02</version><version>0.8.0</version><version>0.8.0-0.6.x-compat</version></versions>" )"
  ck "a compat variant does not beat the plain version" "" "$out"

  # ...AND THE FALLBACK MUST SURVIVE: voyager has no plain-numeric form at all.
  out="$( staleness_line cafe.adriel.voyager:voyager-navigator 1.0.0 \
          "<versions><version>2.2.20-1.10.2</version><version>2.2.21-1.10.3</version></versions>" )"
  case "$out" in *"is 2.2.21-1.10.3"*) ck "an all-hyphenated artifact still resolves" 1 1 ;;
                 *) ck "an all-hyphenated artifact still resolves" 1 0 ;; esac

  # THE REGRESSION THAT "PREFER PLAIN NUMERIC" INTRODUCED: voyager's current line is
  # hyphenated and its plain-numeric releases are two years old, so a shape test picks 1.0.1.
  out="$( staleness_line cafe.adriel.voyager:voyager-navigator 2.2.21-1.10.3 \
          "<versions><version>1.0.0</version><version>1.0.1</version><version>2.2.20-1.10.2</version><version>2.2.21-1.10.3</version></versions>" )"
  ck "a hyphenated current version beats an old plain one" "" "$out"

  # AND SILENCE IS CORRECT IN EXACTLY ONE CASE -- current. If this ever starts printing, the
  # check has become the noise it was filtered to avoid being.
  out="$( staleness_line g:a 2.0.0 "<versions><version>1.9.0</version><version>2.0.0</version></versions>" )"
  ck "a current coordinate prints NOTHING" "" "$out"

  # AN IGNORED LOCKFILE IS NOT SCANNED: git ls-files is the boundary, so a vendored
  # node_modules cannot drag a forest of somebody else's lockfiles into the report.
  #
  # THE FIRST VERSION OF THIS CASE LEFT node_modules MERELY UNTRACKED, and the NEXT case's
  # `git add -A` then tracked it -- so the assertion below failed with the vendored lockfile
  # in the result. The tool was right and the fixture was unrealistic: a real project
  # gitignores node_modules, and one that does not genuinely SHOULD have it scanned. Fixed by
  # making the fixture look like a real project rather than by loosening the assertion.
  ( cd "$T/withlock" && printf 'node_modules/\n' > .gitignore && mkdir -p node_modules/dep \
    && printf '{}\n' > node_modules/dep/package-lock.json \
    && git add -A && git -c user.email=a@b -c user.name=t commit -qm ignore ) >/dev/null 2>&1
  ck "a gitignored lockfile is ignored" "package-lock.json" "$(discover "$T/withlock")"

  # A NAME THAT IS CLOSE BUT WRONG must not match, or the tool silently scans nothing.
  ( cd "$T/withlock" && printf '{}\n' > package-lock.json.bak && git add -A \
    && git -c user.email=a@b -c user.name=t commit -qm bak ) >/dev/null 2>&1
  ck "package-lock.json.bak is not a lockfile" "package-lock.json" "$(discover "$T/withlock")"

  # AND THE INVERSE, so the boundary is proved in both directions: a lockfile that IS
  # tracked gets scanned wherever it sits. Vendoring a dependency tree into git is a
  # decision, and this tool honours it rather than second-guessing the path.
  ( cd "$T/withlock" && mkdir -p vendor/sub && printf '{}\n' > vendor/sub/package-lock.json \
    && git add -A && git -c user.email=a@b -c user.name=t commit -qm vendor ) >/dev/null 2>&1
  ck "a TRACKED nested lockfile IS scanned" 2 "$(discover "$T/withlock" | grep -c .)"

  # ---------------------------------------------------------------- CATALOG PATH
  # A VERSION CATALOG IS DISCOVERED WHERE NO LOCKFILE EXISTS. This is the whole answer to
  # "osv-scanner needs a lockfile and health-app has none", so it is pinned rather than trusted.
  mkdir -p "$T/cat/gradle" && ( cd "$T/cat" && git init -q . \
    && printf '[versions]\nj = "2.9.8"\n\n[libraries]\njd = { module = "com.fasterxml.jackson.core:jackson-databind", version.ref = "j" }\n' \
       > gradle/libs.versions.toml \
    && git add -A && git -c user.email=a@b -c user.name=t commit -qm cat ) >/dev/null 2>&1
  ck "a version catalog resolves to a coordinate" \
     "com.fasterxml.jackson.core:jackson-databind	2.9.8" "$(catalog_coords "$T/cat")"
  ck "a catalog with no [libraries] yields nothing" "" "$( mkdir -p "$T/cat2/gradle" \
     && ( cd "$T/cat2" && git init -q . && printf '[versions]\na = "1"\n' > gradle/libs.versions.toml \
     && git add -A && git -c user.email=a@b -c user.name=t commit -qm c2 ) >/dev/null 2>&1
     catalog_coords "$T/cat2" )"

  # A VERSION WITHOUT A RESOLVABLE REF MUST BE DROPPED, not emitted with an empty version --
  # querying "g:a:" would return a confident nothing.
  mkdir -p "$T/cat3/gradle" && ( cd "$T/cat3" && git init -q . \
    && printf '[versions]\n\n[libraries]\nx = { module = "g:a", version.ref = "missing" }\n' \
       > gradle/libs.versions.toml \
    && git add -A && git -c user.email=a@b -c user.name=t commit -qm c3 ) >/dev/null 2>&1
  ck "an unresolvable version.ref is dropped, not emitted blank" "" "$(catalog_coords "$T/cat3")"
  ck "...and counted as a skip, with the reason" "x	version.ref missing is not in [versions]" "$(catalog_skips "$T/cat3")"

  # EVERY ENTRY IS A COORDINATE OR A COUNTED SKIP (report item 17). The string form and the
  # group/name form were dropped without a word; a BOM-managed entry has no version to query.
  mkdir -p "$T/cat4/gradle" && ( cd "$T/cat4" && git init -q . \
    && printf '[versions]\nk = "1.2"\n\n[libraries]\ns = "g1:a1:3.4"\ngn = { group = "g2", name = "a2", version.ref = "k" }\nbom = { module = "g3:a3" }\n\n[plugins]\np = { id = "x", version = "9" }\n' \
       > gradle/libs.versions.toml \
    && git add -A && git -c user.email=a@b -c user.name=t commit -qm c4 ) >/dev/null 2>&1
  ck "the string and group/name forms are coordinates" "g1:a1	3.4
g2:a2	1.2" "$(catalog_coords "$T/cat4")"
  ck "a BOM-managed entry is a counted skip, and [plugins] is not read" \
     "bom	no version in the catalog (a BOM or platform supplies it)" "$(catalog_skips "$T/cat4")"

  # ------------------------------------------------- STALENESS: REGISTRY AND AGGREGATE
  # A COORDINATE WHOSE CURRENCY NOBODY ESTABLISHED MUST BE COUNTABLE. staleness_line prints
  # [??] for it; that was already true and was already not enough, because the count in the
  # summary came from `hits` and [??] does not touch `hits`. The return code is what carries
  # it out of the function, so the return code is what gets pinned.
  staleness_line g:a 1.0.0 "" >/dev/null; rc=$?
  ck "unresolved staleness returns 2, so it can be counted" 2 "$rc"
  staleness_line g:a 2.0.0 "<versions><version>2.0.0</version></versions>" >/dev/null; rc=$?
  ck "resolved staleness returns 0" 0 "$rc"
  staleness_line g:a 1.0.0 "<versions><version>2.0-alpha1</version></versions>" >/dev/null; rc=$?
  ck "a 200 with no STABLE version also returns 2" 2 "$rc"

  # THE FAILURE MESSAGE MUST NAME BOTH REGISTRIES. It said "Maven Central lookup failed" while
  # the reason for every androidx miss was that Central is the wrong registry to ask.
  out="$( staleness_line androidx.core:core-ktx 1.19.0 "" )"
  case "$out" in *"Maven Central or Google Maven"*) ck "a miss names both registries" 1 1 ;;
                 *) ck "a miss names both registries" 1 0 ;; esac

  # AND A HIT MUST NAME THE ONE THAT ANSWERED, or the line misattributes its own evidence.
  out="$( staleness_line androidx.core:core-ktx 1.0.0 \
          "<versions><version>1.0.0</version><version>1.19.0</version></versions>" "Google Maven" )"
  case "$out" in *"newest STABLE on Google Maven is 1.19.0"*) ck "a hit names the answering registry" 1 1 ;;
                 *) ck "a hit names the answering registry" 1 0 ;; esac

  # THE AGGREGATE MUST NOT ROUND UP. Stub curl so osv.dev answers "no vulnerabilities" and
  # EVERY registry misses: that is exactly the health-app shape, and the summary underneath
  # those [??] lines used to read "clean".
  mkdir -p "$T/stub"
  cat > "$T/stub/curl" <<'STUB'
#!/bin/sh
for a in "$@"; do
  case "$a" in *maven-metadata.xml) exit 22 ;; esac
done
printf '{"vulns":[]}\n200'   # the body, then the status line real `curl -w` appends
exit 0
STUB
  chmod +x "$T/stub/curl"
  out="$( PATH="$T/stub:$PATH" catalog_audit "$T/cat" 2>&1 )"; rc=$?
  ck "vulns clean + staleness unknown is still rc 0" 0 "$rc"
  case "$out" in *"NOT a clean result"*) ck "...but the summary refuses to say clean" 1 1 ;;
                 *) ck "...but the summary refuses to say clean" 1 0 ;; esac
  case "$out" in *"staleness was NOT checked for 1 of"*) ck "...and counts how many went unchecked" 1 1 ;;
                 *) ck "...and counts how many went unchecked" 1 0 ;; esac

  # ONLY A 200 IS AN ANSWER (audit 2026-10-08). osv.dev answers a bad query with a 400 whose
  # body is JSON and has no "vulns" key, which the old parse read as clean. The stub answers
  # the reachability probe and fails every real query the way `curl -f` does on a 400.
  cat > "$T/stub/curl" <<'STUB'
#!/bin/sh
for a in "$@"; do
  case "$a" in *maven-metadata.xml) exit 22 ;; *'"package"'*) printf '\n400'; exit 22 ;; esac
done
echo '{"code":3,"message":"Invalid query."}'
exit 0
STUB
  chmod +x "$T/stub/curl"
  out="$( PATH="$T/stub:$PATH" catalog_audit "$T/cat" 2>&1 )"; rc=$?
  ck "an HTTP 400 from osv.dev is exit 3, not clean" 3 "$rc"

  case "$out" in *"answered HTTP 400"*) ck "...and names the status" 1 1 ;;
                 *) ck "...and names the status" 1 0 ;; esac

  # A SKIPPED ENTRY KEEPS THE RUN FROM READING CLEAN. osv.dev answers "no vulnerabilities" for
  # the two coordinates; the BOM-managed third was never asked about.
  cat > "$T/stub/curl" <<'STUB'
#!/bin/sh
for a in "$@"; do
  case "$a" in *maven-metadata.xml) printf '<versions><version>9.9</version></versions>'; exit 0 ;; esac
done
printf '{"vulns":[]}\n200'
exit 0
STUB
  chmod +x "$T/stub/curl"
  out="$( PATH="$T/stub:$PATH" catalog_audit "$T/cat4" 2>&1 )"; rc=$?
  ck "clean coordinates plus a skipped entry is exit 3, not clean" 3 "$rc"
  case "$out" in *"1 catalog entr(ies) were NOT audited"*) ck "...and counts the skip" 1 1 ;;
                 *) ck "...and counts the skip" 1 0 ;; esac
  case "$out" in *"[--] bom"*) ck "...and names the entry" 1 1 ;;
                 *) ck "...and names the entry" 1 0 ;; esac

  # THE BODY IS JSON WHATEVER THE COORDINATE HOLDS.
  out="$( osv_body 'g:a"b\c' '1.0"' 2>/dev/null | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d["package"]["name"]+"|"+d["version"])' 2>/dev/null )"
  ck "a quote or backslash in a coordinate cannot break the query" 'g:a"b\c|1.0"' "$out"

  rm -rf "$T"
  if [ "$fails" -eq 0 ]; then echo; echo "  all checks passed"; return 0; fi
  echo; echo "  $fails check(s) FAILED"; return 1
}

while [ $# -gt 0 ]; do
  case "$1" in
    --check)    MODE=check ;;
    --strict)   MODE=check; STRICT=1 ;;
    --list)     MODE=list ;;
    --declared) MODE=declared ;;
    --selftest) MODE=selftest ;;
    -h|--help)  usage; exit 0 ;;
    *) echo "dependency_audit: unknown argument $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

case "$MODE" in
  selftest) selftest; exit $? ;;
  list)     discover "$ROOT"; exit 0 ;;
  declared) declared "$ROOT"; exit $? ;;
  check)
    run_audit "$ROOT"; rc=$?
    # FINDINGS ARE ADVISORY AT PREFLIGHT AND STRICT AT RELEASE, which is the same split
    # provenance_check uses. A CVE published overnight should not turn somebody's push red
    # on a morning they changed a comment; it should absolutely stop a release.
    if [ "$rc" -eq 1 ] && [ "$STRICT" -eq 0 ]; then exit 0; fi
    exit "$rc"
    ;;
esac
