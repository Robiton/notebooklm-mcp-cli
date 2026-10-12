#!/usr/bin/env bash
# Project:  ai-project-scaffold
# File:     tools/provenance_check.sh
# Modified: 2026-09-23
# Version:  0.9.2.20260923.0941
# Purpose:  Answer "has anything we borrowed from moved since we looked at it?" — which a
#           registry with no upstream fingerprint in it cannot answer at all.
# Changelog:
#   2026-09-23 v0.9.2.20260923.0941 — mktemp takes a ${TMPDIR} template. macOS mktemp ignores TMPDIR without one, so a guarded fixture root could not contain it.
#   2026-09-06 v0.9.1.20260906.0600 — issue_refs_check is scoped OUT of --file runs. It emits `[??]`
#                        lines and the UNREACHABLE assertion counts them, so running it
#                        against a fixture registry turned a 1 into a 2. Caught by
#                        adoption_check in a synthetic adoption -- a gate I added broke an
#                        adopter's preflight, and the adoption fixture is the only thing
#                        that would have told me before they did. Asserted directly now.
#   2026-09-06 v0.9.0.20260906.0554 — A CITED ISSUE NUMBER ABOVE THE MAXIMUM WAS INVENTED (#303).
#                        Same question this file asks of upstream, pointed inward. FOUR
#                        fabricated forward-references were in the tree, all written on
#                        2026-09-04 as plausible next numbers for work never filed; a reader
#                        chasing one finds nothing and the reasoning is unrecoverable.
#                        THE FIRST CUT WAS WRONG AND THE WAY IT WAS WRONG IS THE DESIGN.
#                        Resolving every reference against the issue list reported NINE
#                        missing on a clean tree, because `localcoder#201` and bare prose
#                        like "measured in #147" cite ANOTHER tracker. Stripping the repo
#                        prefix fixes the qualified ones and cannot fix the bare ones -- the
#                        ambiguity is in the source text. A 9-to-1 false-positive rate is how
#                        a gate teaches people to scroll past it.
#                        So it flags ONLY numbers ABOVE the current maximum, which cannot be
#                        a shared cross-repo number and cannot be an old closed issue: it can
#                        only be invented. Catches all four real instances with zero false
#                        positives, and knowingly misses a fabrication below the maximum.
#                        Narrow and trustworthy beats broad and ignored.
#                        And it flagged its OWN comment naming the examples, so those are
#                        written without the sigil -- the paragraph explaining a guard
#                        otherwise satisfies the guard.
#   2026-08-30 v0.2.1.20260830.0005 — THE LOCAL WARNINGS NO LONGER SIT BEHIND A NETWORK CALL, and
#                        the selftest now PLANTS DEFECTS instead of only exercising helpers.
#                        An unreachable source hit `continue` before the licence and floor
#                        checks, so "licence unverified -- resolve before copying anything"
#                        was suppressed for precisely the rows that need it loudest: a repo
#                        renamed, deleted or made private is the one whose terms nobody can go
#                        and read. Both checks need no network and now run regardless, via
#                        local_row_warnings() so the two call sites cannot drift. Eight
#                        mutation tests assert each defect is REPORTED and that a clean row
#                        manufactures nothing -- everything here previously proved the parser
#                        worked on GOOD input and nothing proved the tool catches anything.
#   2026-08-26 v0.2.0 — `floor` SPLIT OUT FROM `reviewed`, because the first version conflated
#                        two different questions under one column and described the result as a
#                        "pin". The owner caught it. `reviewed` is HISTORY -- the version our
#                        evidence was taken on, which must never move or the evidence stops
#                        being interpretable. `floor` is POLICY -- the minimum we require,
#                        written `>=X`, because an exact pin claims one version is acceptable
#                        and goes stale the day upstream ships a fix.
#                        THE THIRD STATE IS THE USEFUL ONE: `reviewed` BELOW `floor` means our
#                        measurements predate the rule we adopted. Nothing has drifted and
#                        neither field is wrong, and nothing else in the tree can say it.
#                        Live example: ollama reviewed v0.32.13, floor >=0.32.15 -- two MLX
#                        dependency updates and a caching rewrite sit in between, under #147,
#                        #191, #117 and every T2/T2b number.
#                        `--write` refreshes reviewed and checked and NEVER floor: a tool that
#                        moved a policy would be granting itself permission.
#                        Fingerprint kind is inferred from what was recorded -- a SHA opts into
#                        commit tracking. cline ships `desktop-v*` and `sdk/*` tags from one
#                        tree, so its "latest release" flips between product lines and reported
#                        MOVED within the hour while meaning nothing.
#   2026-08-26 v0.1.1 — Header corrected: it claimed "preflight does not call this", which is
#                        both wrong and the reason CI went red. preflight case 1b-vii fails a
#                        tool that ships --check with no gate calling it, and this is now wired
#                        exactly as session_currency.sh is -- called every run, exits 0, exit 1
#                        only under --strict. Being CALLED and being ABLE TO FAIL A PUSH are
#                        different things, and the first draft conflated them.
#   2026-08-26 v0.1.0 — Initial. This programme had a "worth a second look" pile
#                        (localcoder-dev/docs/SKILLS-AND-TOOLS-IDEAS.md) recording source,
#                        licence and status — everything except the one field that makes
#                        revisiting possible. Nothing recorded WHICH COMMIT we read, so
#                        "have they fixed anything since?" had no answer short of reading
#                        the whole repo again from scratch.
#
# THIS IS A REPORT, NOT A GATE, AND THAT IS DELIBERATE
#   An upstream repository moving is the NORMAL case — active projects push daily. A
#   preflight gate that goes red every time someone else commits is red at a normal moment,
#   and ai-project-scaffold#241 is this month's example of what that trains: people learn to
#   scroll past it, and then it is worth nothing when it finally means something.
#   So `--check` REPORTS drift and exits 0. `--strict` returns the drift as an exit code for
#   a scheduled review that wants to act on it.
#
#   preflight DOES call it, in --check mode, and that is not a contradiction: the same wiring
#   session_currency.sh has. The scaffold's own rule (preflight case 1b-vii) is that a tool
#   shipping --check with no gate calling it is selftest-green and unused, and the first draft
#   of this header asserted the opposite on the way to failing CI for exactly that reason.
#   Being CALLED by a gate and being ABLE TO FAIL a push are different things.
#
# WHY THE LICENCE COLUMN IS LOAD-BEARING
#   `trailofbits/skills` is CC-BY-SA-4.0: forking the repo for reference is fine, copying its
#   SKILL.md text into our `.claude/skills/` drags share-alike into private repositories.
#   That distinction lives in the row, next to the thing it governs, because a licence
#   recorded somewhere else is a licence nobody reads at the moment of copying.
#
# WHAT A ROW MUST CARRY, and why each field is not optional
#   source    owner/repo. A search URL is not a source — record it as `unresolved:<note>`
#             so it shows up as work to do rather than as a tracked dependency.
#   licence   what it permits. `unverified` is a legitimate value and prints as a warning.
#   relation  code | idea | behaviour | evaluated | catalogue | dependency
#             `behaviour` is the one people forget: we did not take Cline's code, we read its
#             shipped bundle and depend on what we found there. An upstream change to that
#             behaviour breaks us exactly as a code change would.
#   took      what we actually took, in a few words.
#   landed    where it is in OUR tree — a file, a tool, an issue number. This is the blast
#             radius when the upstream moves, and it is the field that makes the report
#             actionable rather than merely interesting.
#   reviewed  the upstream fingerprint AT THE TIME WE LOOKED. Short SHA, or a release tag.
#             THIS IS HISTORY AND IT NEVER MOVES ON ITS OWN. Every measurement we hold about
#             a source is only interpretable against the version it was taken on; rewriting
#             this to "current" silently converts a dated fact into an undated claim.
#   floor     the MINIMUM version we require, as `>=X`, or `-` if we do not constrain it.
#             THIS IS A POLICY AND IT IS DELIBERATELY NOT A PIN. An exact pin says one
#             version is acceptable, which is almost never what is meant and goes stale the
#             day upstream ships a fix. A floor says "below this we know we are broken".
#             The two fields answer different questions and both are needed: `reviewed`
#             says what our evidence rests on, `floor` says what we will run.
#   checked   ISO date we last looked.
set -uo pipefail

SELF="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
ROOT="${PROVENANCE_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
REGISTRY="${PROVENANCE_FILE:-$ROOT/ai/PROVENANCE.md}"
MODE=check
REGISTRY_EXPLICIT=0
STRICT=0

while [ $# -gt 0 ]; do
  case "$1" in
    --check)    MODE=check ;;
    --write)    MODE=write ;;
    --list)     MODE=list ;;
    --selftest) MODE=selftest ;;
    --strict)   STRICT=1 ;;
    --file)     shift; REGISTRY="$1"; REGISTRY_EXPLICIT=1 ;;
    -h|--help)  MODE=usage ;;
    *) echo "provenance_check: unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done

usage() {
  cat <<'USAGE'
usage: provenance_check.sh [--check|--write|--list] [--strict] [--file PATH]

  --check    (default) report which upstream sources have moved since we recorded them.
             Exits 0 — drift is normal, not a failure. Add --strict to exit 1 on drift.
  --write    refresh the ref/checked columns to the CURRENT upstream state. Run this only
             after you have actually reviewed what changed; it is a statement that you
             looked, and writing it without looking makes the whole registry a lie.
  --list     print the registry rows with no network calls.

The registry is ai/PROVENANCE.md, between the scaffold:provenance markers.
USAGE
}

# ---------------------------------------------------------------- row parsing
# Rows live in a markdown table between markers, so the file stays readable as a document
# and parseable as data. Same pattern as scaffold:status-begin and scaffold:closeouts.
rows() {  # rows <file>
  [ -f "$1" ] || return 0
  awk '
    /<!--[[:space:]]*scaffold:provenance:begin/ { inblk=1; next }
    /<!--[[:space:]]*scaffold:provenance:end/   { inblk=0; next }
    inblk && /^\|/ {
      if ($0 ~ /^\|[[:space:]]*-+/) next          # separator
      if ($0 ~ /^\|[[:space:]]*source[[:space:]]*\|/) next   # header
      print
    }
  ' "$1"
}

field() {  # field <row> <n>
  printf '%s\n' "$1" | awk -F'|' -v n="$2" '{ gsub(/^[ \t]+|[ \t]+$/, "", $(n+1)); print $(n+1) }'
}

# WARNINGS THAT NEED NO NETWORK, so they must not sit behind a reachability check.
# Both were previously inline after the upstream lookup, which meant `continue` on an
# unreachable source skipped them. Kept as a function rather than duplicated, so the two
# call sites cannot drift.
local_row_warnings() {  # local_row_warnings <licence> <relation> <floor>
  case "$1" in
    unverified|"") printf '         [!] licence unverified — resolve before copying anything\n' ;;
  esac
  case "$3" in
    ""|-|—|n/a)
      case "$2" in
        behaviour|dependency)
          nofloor=$((nofloor + 1))
          printf '         [!] no floor declared, and relation is `%s` — which versions do we\n' "$2"
          printf '             actually require? An unstated floor is a claim nobody can check.\n' ;;
      esac ;;
  esac
}

# Strip markdown link syntax and backticks: [`owner/repo`](url) -> owner/repo
# BSD sed (macOS) has no `\?` in a basic regex, so this is ERE throughout -- the first
# draft silently left `https://github.com/` on the front of every bare-URL row, which
# resolves to nothing and would have reported every such source as unreachable.
clean_source() {
  printf '%s' "$1" | sed -E -e 's/\[([^]]*)\]\(([^)]*)\)/\1/g' -e 's/`//g' \
                            -e 's#^https?://github\.com/##' -e 's#/$##' -e 's/[[:space:]]*$//'
}

have_gh() { command -v gh >/dev/null 2>&1; }

# VERSION COMPARISON IN PYTHON, not `sort -V`. BSD sort on macOS has carried -V only
# recently and this file ships to Linux, WSL and macOS alike; a comparison that silently
# does the wrong thing on one of them is worse than no comparison. Non-numeric tags (a bare
# SHA) compare equal, because ordering them is meaningless rather than merely hard.
version_ge() {  # version_ge <have> <want>; 0 if have >= want
  python3 - "$1" "$2" <<'VPY'
import re, sys
def parts(v):
    v = re.sub(r'^[^0-9]*', '', (v or '').strip())
    nums = re.findall(r'\d+', v)
    return [int(n) for n in nums] if nums else None
have, want = parts(sys.argv[1]), parts(sys.argv[2])
if have is None or want is None:
    sys.exit(0)                      # not version-shaped: not a violation
have += [0] * (len(want) - len(have))
want += [0] * (len(have) - len(want))
sys.exit(0 if have >= want else 1)
VPY
}

# Current upstream fingerprint: the newest RELEASE if there is one, else the default
# branch's short SHA. A release is the better fingerprint where it exists -- it is what an
# adopter of that project would actually resolve.
# `gh api` ON A 404 WRITES THE ERROR JSON TO STDOUT. A repository with no releases at all
# -- trailofbits/skills, and every awesome-list -- therefore returns
# `{"message":"Not Found",...}` where a tag name was expected, and `|| true` swallows the
# non-zero exit that would have said so. Left unguarded, every release-less source records a
# blob of JSON as its fingerprint and reports MOVED forever. Caught on the first real run.
# The guard, as a function, so the selftest can call it instead of re-inlining a case.
sanitize_ref() {
  case "$1" in
    ''|null|*'{'*|*'"message"'*) printf '' ;;
    *) printf '%s' "$1" ;;
  esac
}

# THE FINGERPRINT KIND IS INFERRED FROM WHAT WAS RECORDED, and that is not a convenience.
# A repository that tags several products from one tree -- cline ships `desktop-v*` and
# `sdk/*` tags alongside the extension -- has a "latest release" that flips between unrelated
# product lines. Tracking it reports MOVED constantly and means nothing. Recording a SHA for
# such a source opts into commit tracking; recording a tag opts into release tracking.
looks_like_sha() { case "$1" in [0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]*) case "$1" in *[!0-9a-f]*) return 1 ;; *) return 0 ;; esac ;; *) return 1 ;; esac; }

upstream_ref() {  # upstream_ref <owner/repo> [recorded]  -> "<ref>\t<pushed_at>"
  # `rel` MUST be initialised: under `set -u` the SHA branch never assigns it, and the
  # test below then kills the row -- which reported every commit-tracked source as UNREACHABLE.
  local repo="$1" want="${2:-}" rel="" sha="" pushed=""
  pushed="$(sanitize_ref "$(gh api "repos/$repo" -q '.pushed_at' 2>/dev/null)")"
  if ! looks_like_sha "$want"; then
    rel="$(sanitize_ref "$(gh api "repos/$repo/releases/latest" -q '.tag_name' 2>/dev/null)")"
  fi
  if [ -n "$rel" ]; then
    printf '%s\t%s' "$rel" "${pushed:0:10}"
    return 0
  fi
  sha="$(sanitize_ref "$(gh api "repos/$repo/commits?per_page=1" -q '.[0].sha' 2>/dev/null)")"
  if [ -n "$sha" ]; then
    printf '%s\t%s' "${sha:0:7}" "${pushed:0:10}"
    return 0
  fi
  return 1
}

report() {
  local moved=0 same=0 unresolved=0 unreachable=0 belowfloor=0 nofloor=0 staleevidence=0
  local row src lic rel took landed ref floor checked
  local cur curref curpushed

  if [ ! -f "$REGISTRY" ]; then
    echo "provenance: no registry at $REGISTRY"
    echo "  Create one from the scaffold's ai/PROVENANCE.md template. A project that has"
    echo "  borrowed nothing should say so in the file rather than by the file's absence."
    return 0
  fi

  if [ "$MODE" != "list" ] && ! have_gh; then
    echo "provenance: [GAP] gh is not installed — cannot ask what upstream looks like now."
    echo "  Rows below are printed from the registry only."
    MODE=list
  fi

  printf '\n%s\n' "provenance — sources this project took something from"
  printf '%s\n' "-------------------------------------------------------------------"

  while IFS= read -r row; do
    [ -n "$row" ] || continue
    src="$(clean_source "$(field "$row" 1)")"
    lic="$(field "$row" 2)"
    rel="$(field "$row" 3)"
    took="$(field "$row" 4)"
    landed="$(field "$row" 5)"
    ref="$(field "$row" 6)"
    floor="$(field "$row" 7)"
    checked="$(field "$row" 8)"

    case "$src" in
      unresolved:*)
        unresolved=$((unresolved + 1))
        printf '  [TODO] %s\n' "$src"
        printf '         %s — never resolved to a real repository, so it cannot be tracked.\n' "$took"
        continue ;;
    esac

    if [ "$MODE" = "list" ]; then
      printf '  %-42s %-14s %s @ %s\n' "$src" "$rel" "$ref" "$checked"
      continue
    fi

    if ! cur="$(upstream_ref "$src" "$ref")"; then
      unreachable=$((unreachable + 1))
      printf '  [??]   %-40s unreachable (private, renamed, or deleted)\n' "$src"
      printf '         recorded %s @ %s — a source that has VANISHED is the case this\n' "$ref" "$checked"
      printf '         registry exists for; it is also why forking was suggested.\n'
      # THE LOCAL CHECKS STILL APPLY TO A SOURCE WE CANNOT REACH, and before this call they
      # did not. `continue` skipped them, so an unverified licence and a missing floor went
      # unreported for exactly the rows that need them loudest: a repo that has been renamed,
      # deleted or made private is the one whose terms nobody can go and read. The warning
      # says "resolve before copying anything" and it was suppressed in the one case where
      # resolving is hardest.
      local_row_warnings "$lic" "$rel" "$floor"
      continue
    fi
    curref="${cur%%	*}"
    curpushed="${cur##*	}"

    if [ "$curref" = "$ref" ]; then
      same=$((same + 1))
      printf '  [ok]   %-40s %s (unchanged since %s)\n' "$src" "$ref" "$checked"
    else
      moved=$((moved + 1))
      printf '  [MOVED]%-41s %s -> %s   (upstream pushed %s)\n' " $src" "$ref" "$curref" "$curpushed"
      printf '         licence: %-12s relation: %s\n' "$lic" "$rel"
      printf '         we took: %s\n' "$took"
      printf '         it is in: %s\n' "$landed"
      printf '         https://github.com/%s/compare/%s...%s\n' "$src" "$ref" "$curref"
    fi

    local_row_warnings "$lic" "$rel" "$floor"

    # THE FLOOR IS A SEPARATE QUESTION FROM THE DRIFT, and asking them together is the
    # mistake this column exists to fix. Drift asks "is our evidence stale". The floor asks
    # "would today's upstream still work for us".
    case "$floor" in
      ""|-|—|n/a)
        : ;;
      *)
        if ! version_ge "$curref" "${floor#>=}"; then
          belowfloor=$((belowfloor + 1))
          printf '         [X] FLOOR: we require %s and upstream latest is %s\n' "$floor" "$curref"
        fi
        # THE THIRD STATE, AND IT IS THE MOST USEFUL ONE. `reviewed` below `floor` means our
        # EVIDENCE was taken on a version we no longer permit. Neither field is wrong and
        # nothing has drifted -- the numbers we hold simply predate the rule we adopted, and
        # nothing else in the repository can say so.
        if ! version_ge "$ref" "${floor#>=}"; then
          staleevidence=$((staleevidence + 1))
          printf '         [!] EVIDENCE PREDATES THE FLOOR: measured on %s, floor is %s.\n' "$ref" "$floor"
          printf '             Anything we concluded from %s is unverified on what we now run.\n' "$ref"
        fi ;;
    esac
  done <<ROWS
$(rows "$REGISTRY")
ROWS

  printf '%s\n' "-------------------------------------------------------------------"
  printf '  %s moved, %s unchanged, %s unreachable, %s unresolved\n' \
    "$moved" "$same" "$unreachable" "$unresolved"
  [ "$belowfloor" -gt 0 ] && printf '  %s source(s) BELOW our declared floor\n' "$belowfloor"
  [ "$nofloor" -gt 0 ] && printf '  %s behaviour/dependency row(s) declare no floor\n' "$nofloor"
  [ "$staleevidence" -gt 0 ] && printf '  %s row(s) hold evidence taken BELOW the declared floor\n' "$staleevidence"
  if [ "$moved" -gt 0 ]; then
    printf '\n  A MOVED row is not a task. Read the compare link, decide, and only then run\n'
    printf '  --write, which records that you looked. Refreshing a ref you did not read\n'
    printf '  turns this file into a record of nothing.\n'
  fi
  [ "$STRICT" -eq 1 ] && [ $((moved + unreachable)) -gt 0 ] && return 1
  return 0
}

# --write refreshes ref/checked in place, for rows that resolve.
refresh() {
  local row src ref cur curref today tmp
  have_gh || { echo "provenance: gh is required for --write" >&2; return 2; }
  [ -f "$REGISTRY" ] || { echo "provenance: no registry at $REGISTRY" >&2; return 2; }
  today="$(date -u +%Y-%m-%d)"
  tmp="$(mktemp "${TMPDIR:-/tmp}/provenance_check.XXXXXX")" || return 1
  cp "$REGISTRY" "$tmp"
  while IFS= read -r row; do
    [ -n "$row" ] || continue
    src="$(clean_source "$(field "$row" 1)")"
    case "$src" in unresolved:*) continue ;; esac
    ref="$(field "$row" 6)"
    cur="$(upstream_ref "$src" "$ref")" || continue
    curref="${cur%%	*}"
    [ "$curref" = "$ref" ] && continue
    # Replace only the ref and checked cells of THIS row, matched on the whole row text.
    python3 - "$tmp" "$row" "$curref" "$today" <<'PY'
import sys
path, row, newref, today = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
s = open(path).read()
cells = row.split('|')
# Columns: 0 is the empty cell before the leading pipe, so source=1 ... checked=8.
# ONLY `reviewed` and `checked` are rewritten. `floor` is a policy someone decided and
# must never be moved by a tool -- that would be the tool granting itself permission.
if len(cells) >= 9:
    cells[6] = f' {newref} '
    cells[8] = f' {today} '
    s = s.replace(row, '|'.join(cells), 1)
    open(path, 'w').write(s)
PY
    printf '  refreshed %-40s -> %s\n' "$src" "$curref"
  done <<ROWS
$(rows "$REGISTRY")
ROWS
  mv "$tmp" "$REGISTRY"
  echo "provenance: $REGISTRY updated"
}

# ---------------------------------------------------------------- selftest
selftest() {
  local fails=0 T
  T="$(mktemp -d "${TMPDIR:-/tmp}/provenance_check.XXXXXX")" || exit 1
  chk() { if [ "$2" = "$3" ]; then printf '  ok   %-56s\n' "$1"
          else printf '  FAIL %-56s expected=%s got=%s\n' "$1" "$2" "$3"; fails=$((fails+1)); fi; }

  echo "provenance_check selftest"

  mkdir -p "$T/ai"
  cat > "$T/ai/PROVENANCE.md" <<'REG'
# Provenance

<!-- scaffold:provenance:begin -->
| source | licence | relation | took | landed | reviewed | floor | checked |
|---|---|---|---|---|---|---|---|
| [`owner/thing`](https://github.com/owner/thing) | MIT | code | the capture half | `tools/x.sh` | abc1234 | - | 2026-08-01 |
| unresolved:vakra | unverified | evaluated | a benchmark we only have a search link for | #186 | — | - | 2026-08-24 |
<!-- scaffold:provenance:end -->

Prose outside the markers is never parsed.
| this | pipe | table | is | outside | the | markers |
REG

  # PARSING: rows come only from inside the markers, and the header/separator are not rows.
  chk "two rows parse, header and separator excluded" 2 \
      "$(PROVENANCE_ROOT="$T" bash "$SELF" --list --file "$T/ai/PROVENANCE.md" 2>/dev/null \
         | grep -cE '^  (owner/thing|\[TODO\])')"

  # A table OUTSIDE the markers must never be read as data.
  chk "a table outside the markers is ignored" 0 \
      "$(PROVENANCE_ROOT="$T" bash "$SELF" --list --file "$T/ai/PROVENANCE.md" 2>/dev/null \
         | grep -c 'outside')"

  # LINK SYNTAX IS STRIPPED. The registry is a document first; a row that reads well in
  # markdown must still resolve to owner/repo.
  chk "markdown link syntax strips to owner/repo" "owner/thing" \
      "$(clean_source '[`owner/thing`](https://github.com/owner/thing)')"
  chk "a bare github URL strips too" "owner/thing" \
      "$(clean_source 'https://github.com/owner/thing')"

  # AN UNRESOLVED SOURCE IS WORK, NOT A DEPENDENCY, and must be visible as such.
  chk "an unresolved source reports as TODO" 1 \
      "$(PROVENANCE_ROOT="$T" bash "$SELF" --list --file "$T/ai/PROVENANCE.md" 2>/dev/null \
         | grep -c '\[TODO\]')"

  # THE FLOOR IS A `>=`, NOT A PIN, and the comparison has to actually order versions.
  version_ge "v0.32.15" "0.32.13" && chk "0.32.15 satisfies a floor of 0.32.13" 1 1 \
    || chk "0.32.15 satisfies a floor of 0.32.13" 1 0
  version_ge "v0.32.13" "0.32.15" && chk "0.32.13 does NOT satisfy a floor of 0.32.15" 1 0 \
    || chk "0.32.13 does NOT satisfy a floor of 0.32.15" 1 1
  version_ge "v0.33.0" "0.32.15" && chk "0.33.0 satisfies it too — a floor is not a pin" 1 1 \
    || chk "0.33.0 satisfies it too — a floor is not a pin" 1 0
  version_ge "v1.10.0" "1.9.0" && chk "1.10 sorts above 1.9, not below it" 1 1 \
    || chk "1.10 sorts above 1.9, not below it" 1 0
  version_ge "abc1234" "0.1.0" && chk "a bare SHA is not a floor violation" 1 1 \
    || chk "a bare SHA is not a floor violation" 1 0

  # A RECORDED SHA MUST OPT INTO COMMIT TRACKING, or a multi-product tagger reports MOVED forever.
  looks_like_sha "65720f8" && chk "a 7-hex value is recognised as a SHA" 1 1 || chk "a 7-hex value is recognised as a SHA" 1 0
  looks_like_sha "v0.32.13" && chk "a version tag is NOT a SHA" 1 0 || chk "a version tag is NOT a SHA" 1 1
  looks_like_sha "desktop-v0.0.17" && chk "a product tag is NOT a SHA" 1 0 || chk "a product tag is NOT a SHA" 1 1

  # EVIDENCE BELOW THE FLOOR is its own state: nothing drifted, but what we measured on is
  # no longer a version we permit.
  version_ge "v0.32.13" "0.32.15" && chk "reviewed below floor is detectable" 1 0 \
    || chk "reviewed below floor is detectable" 1 1

  # A 404 FROM `gh api` LANDS ON STDOUT, so an error body must never become a fingerprint.
  chk "a Not Found body is not treated as a ref" "" "$(sanitize_ref '{"message":"Not Found"}')"
  chk "the literal null is not a ref" "" "$(sanitize_ref null)"
  chk "a real tag survives the guard" "v1.3.0" "$(sanitize_ref v1.3.0)"

  # ------------------------------------------------------------------ MUTATION TESTS
  # PLANT THE DEFECT, THEN ASSERT IT IS REPORTED. Everything above proves the parser and the
  # comparators work on GOOD input. None of it proved this tool CATCHES anything -- and a
  # checker nobody has watched fail is a checker nobody knows is wired. `adoption_check.sh`
  # has planted violations since it was written; this file did not, and the register's own
  # rule 9 was a rule with no enforcement behind it.
  #
  # Every case below is offline: an owner/repo that cannot exist takes the `unreachable`
  # path, and these are the warnings that must survive it.
  mkdir -p "$T/mut"
  plant() {  # plant <licence> <relation> <floor>
    cat > "$T/mut/PROVENANCE.md" <<PLANTED
<!-- scaffold:provenance:begin -->
| source | licence | relation | took | landed | reviewed | floor | checked |
|---|---|---|---|---|---|---|---|
| scaffold-selftest-nonexistent/repo | $1 | $2 | planted by the selftest | nowhere | v1.0.0 | $3 | 2026-01-01 |
<!-- scaffold:provenance:end -->
PLANTED
    PROVENANCE_ROOT="$T/mut" bash "$SELF" --check --file "$T/mut/PROVENANCE.md" 2>/dev/null
  }

  chk "an unverified licence is reported" 1 \
      "$(plant unverified dependency '>=1.0.0' | grep -c 'licence unverified')"
  # Anchored on the row marker, not the word: "unreachable" also appears in the summary
  # line, so a bare grep -c counted two and the assertion failed on its own sloppiness.
  chk "...and survives an UNREACHABLE source (the regression)" 1 \
      "$(plant unverified dependency '>=1.0.0' | grep -cE '^  \[\?\?\]')"
  chk "a dependency with no floor is reported" 1 \
      "$(plant MIT dependency - | grep -c 'no floor declared')"
  chk "a behaviour with no floor is reported" 1 \
      "$(plant MIT behaviour - | grep -c 'no floor declared')"
  chk "an IDEA with no floor is NOT reported — it needs none" 0 \
      "$(plant MIT idea - | grep -c 'no floor declared')"
  chk "a declared licence and floor produce no warning" 0 \
      "$(plant MIT dependency '>=1.0.0' | grep -cE 'licence unverified|no floor declared')"

  # THE COUNTERS MUST MOVE, not just the text. A summary that always says zero is the same
  # failure as a gate that always passes.
  chk "the no-floor counter increments" 1 \
      "$(plant MIT dependency - | grep -cE '^  1 behaviour/dependency row\(s\) declare no floor')"

  # AND THE INVERSE: a registry with nothing wrong must not manufacture a finding.
  chk "a clean row reports no counters at all" 0 \
      "$(plant MIT dependency '>=1.0.0' | grep -cE 'declare no floor|BELOW our declared floor')"

  # THE ISSUE-REFERENCE CHECK MUST STAY OUT OF --file RUNS. It emits `[??]` lines, which the
  # UNREACHABLE assertion above counts; running it here made that 1 into a 2. Assert the
  # scoping directly rather than relying on the other case to notice.
  chk "--file suppresses the issue-reference check" 0 \
      "$(plant MIT dependency '>=1.0.0' | grep -cE 'cited in the tree|issue references NOT MEASURED')"

  # A MISSING REGISTRY IS NOT AN ERROR -- a project that borrowed nothing has no file yet.
  ( PROVENANCE_ROOT="$T/none" bash "$SELF" --check --file "$T/none/ai/PROVENANCE.md" >/dev/null 2>&1 )
  chk "a missing registry exits 0, and says what to do" 0 $?

  # DRIFT IS NOT A FAILURE without --strict. This is the #241 lesson: a gate that is red at
  # a normal moment gets scrolled past, and upstream moving is the normal moment here.
  ( PROVENANCE_ROOT="$T" bash "$SELF" --check --file "$T/ai/PROVENANCE.md" >/dev/null 2>&1 )
  chk "--check exits 0 even when rows cannot be verified" 0 $?

  rm -rf "$T"
  echo ""
  if [ "$fails" -eq 0 ]; then echo "  all checks passed"; return 0; fi
  echo "  $fails check(s) FAILED"; return 1
}


# ==== A CITED ISSUE NUMBER ABOVE THE HIGHEST ONE THAT EXISTS WAS INVENTED (#303) =========
#
# Same question this file already asks, pointed inward: we cite issue numbers as the
# justification for a change, and nothing checked they are real. Measured 2026-09-06: FOUR
# fabricated forward-references -- numbers 303, 304, 305 and 307, written WITHOUT the sigil
# here because a paragraph explaining a guard otherwise satisfies the guard -- all written
# on 2026-09-04 as
# plausible next numbers for work never filed. A reader chasing one finds nothing and the
# reasoning is unrecoverable. Same class as 0.84.0's nineteen dangling pointers.
#
# IT FLAGS ONLY NUMBERS ABOVE THE CURRENT MAXIMUM, and that is the whole design. The first
# cut resolved every reference against the issue list and reported nine missing on a clean
# tree -- because `localcoder#201`, and bare prose like "measured in #147", cite ANOTHER
# repository's tracker. Stripping the repo prefix fixes the qualified ones and cannot fix the
# bare ones; the ambiguity is in the source text, not the pattern. A gate with a 9-to-1
# false-positive rate is one people learn to scroll past, which is worse than no gate.
#
# A number ABOVE the maximum is unambiguous: it cannot be a cross-repo reference we happen to
# share, and it cannot be an old closed issue. It can only be a number someone made up. That
# is exactly the defect -- all four instances were forward-references -- caught with no false
# positives, at the cost of not catching a fabricated number that happens to fall below the
# maximum. Narrow and trustworthy beats broad and ignored.
#
# ONE NETWORK CALL. NOT MEASURED IS NOT A PASS.
issue_refs_check() {
  local files refs maxnum n bad=0
  # SCOPED TO THIS REPO'S OWN TREE. `--file` means the caller is checking some OTHER
  # registry -- a fixture, or a sibling project -- and the issue numbers cited in THIS
  # working tree say nothing about that. Skipping is not laziness: running anyway put a
  # second `[??]` line into the fixture output and broke an assertion that counts them,
  # which adoption_check caught in a synthetic adoption before this could reach an adopter.
  [ "${REGISTRY_EXPLICIT:-0}" = "1" ] && return 0
  files="$(git ls-files 'tools/*' 'setup.sh' 'AGENTS.md' 'ai/*.md' 2>/dev/null | grep -E '\.(sh|py|md)$')"
  [ -z "$files" ] && return 0
  refs="$(printf '%s\n' "$files" | tr '\n' '\0' \
          | xargs -0 grep -hoE '(^|[^A-Za-z0-9/_.-])#[0-9]{2,4}' 2>/dev/null \
          | sed 's/.*#//' | sort -un)"
  [ -z "$refs" ] && return 0

  if ! have_gh; then
    echo "  [??] issue references NOT MEASURED — no gh on PATH."
    return 0
  fi
  maxnum="$(gh issue list --state all --limit 1 --json number --jq '.[0].number' 2>/dev/null)"
  case "$maxnum" in
    ''|*[!0-9]*)
      echo "  [??] issue references NOT MEASURED — could not read the issue list (offline, or none enabled)."
      return 0 ;;
  esac

  for n in $refs; do
    [ "$n" -gt "$maxnum" ] 2>/dev/null || continue
    echo "  [!!] #$n is cited in the tree but the highest issue that exists is #$maxnum"
    bad=$((bad + 1))
  done
  if [ "$bad" -gt 0 ]; then
    echo "       A number above the maximum was invented, not observed. File the issue (the"
    echo "       number is usually still free) or drop the citation — a reader chasing it"
    echo "       finds nothing, and the reasoning behind the change is unrecoverable."
  fi
  return 0
}

case "$MODE" in
  usage)    usage ;;
  selftest) selftest ;;
  write)    refresh ;;
  *)        report; issue_refs_check ;;
esac
