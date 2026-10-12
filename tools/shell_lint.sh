#!/usr/bin/env bash
# Project:  ai-project-scaffold
# File:     tools/shell_lint.sh
# Modified: 2026-09-23
# Version:  0.3.1.20260923.0941
# Purpose:  ShellCheck at a pinned version and a declared severity — one definition, CI and local.
# Changelog:
#   2026-09-23 v0.3.1.20260923.0941 — a guarded mktemp with no ${TMPDIR} template is flagged too. macOS mktemp ignores TMPDIR without a template, so it escapes a fixture root.
#   2026-09-23 v0.3.0.20260923.0843 — names a mktemp assignment with no failure check (no || or && on the line, no [ -n ] test on the next). header_check committed its fixture into Robiton/control that way. Found three more sites in tools/fixtures/stale_adoption.sh.
#   2026-09-22 v0.2.0.20260922.1658 — lints only scaffold-owned shell, like lint_python
#                                     (#4); names a '# shellcheck <prose>' comment before
#                                     it becomes SC1072/SC1073 (#10); failure text says
#                                     severity is per finding. Its own first changelog
#                                     line wrapped into exactly that shape and it caught it.
#   2026-09-22 v0.1.0 — New. The only mention of shellcheck anywhere in this repository was
#                        a `# shellcheck disable=SC2086` directive -- a suppression for a
#                        tool that never ran.
#
#                        WHERE THE BINARY IS, MEASURED RATHER THAN REPORTED. Present on the
#                        macOS self-hosted runner and on the M5; ABSENT on the Linux
#                        self-hosted runner. This header first said it was installed "on
#                        every self-hosted runner", which I took from a peer session's
#                        report and never checked; CI disproved it on the first run, where
#                        the Linux leg went red and the macOS leg passed on the same commit.
#                        Exit 3 here is not a hypothetical branch, it is the Linux runner's
#                        state today -- and a gate that only ever runs where the toolchain
#                        happens to be installed is measuring the machine, not the product.
#
#                        THE SEVERITY FLOOR IS THE WHOLE DESIGN AND IT IS `error`. Measured
#                        on this tree the day the gate was written:
#                            -S style    178 finding(s)
#                            -S info     174
#                            -S warning   37
#                            -S error      2
#                        A gate that arrives red in five repositories on day one is a gate
#                        people clear on autopilot and then clear on the day it matters --
#                        the failure mode ai/STANDARDS.md already documents for the header
#                        check. `error` is the floor the tree can actually hold at zero, so
#                        a finding here is news rather than weather.
#
#                        AND THE FLOOR IS NOT A COMPROMISE. Of the two errors, one was a
#                        REAL LATENT BUG that `bash -n` cannot see: ci_status.sh:1392 had
#                        `${{ vars || 'ubuntu-latest' }}` unescaped inside a double-quoted
#                        string, so bash parsed it as a parameter expansion, printed
#                        `bad substitution` to stderr INSTEAD of the message, and continued.
#                        The one line that explains a set-but-empty runner variable was
#                        replaced by a shell error in exactly the case it exists to explain,
#                        and it had been that way since the line was written. The other was
#                        a false positive, now suppressed AT THE LINE with its reason.
#                        Two findings, one real, and the real one was invisible to every
#                        other gate in this repository.
#
#                        THE PIN IS LOAD-BEARING, for the reason lint_python.sh gives: a
#                        different shellcheck is a different gate, and a local run that
#                        disagrees with the build disagrees in the direction that reads as
#                        "my code is fine". A system binary is used ONLY at the pin.
#
#                        Exit 3 is "did not run", never 0 — no shellcheck, or a version that
#                        is not the pin. A machine without the tool must not report a clean
#                        lint. That is #188's rule and this file is built to it.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 3

SHELLCHECK_PIN="0.11.0"
SEVERITY="error"

# ---- which files ------------------------------------------------------------------------
# By EXTENSION OR SHEBANG, and tracked-only. A `*.sh` glob is not the set of shell files:
# tools/ has carried extensionless executables before, and the one file a glob misses is
# never the boring one. This mirrors tools/python_floor.py, which found localcoder's entry
# point exactly because it looked at shebangs too.
#
# AND OURS ONLY -- the rule lint_python.sh gives for #76. scaffold_upgrade.sh leaves an
# adopter's own files beside ours, and failing their build on a shellcheck version and a
# floor the scaffold chose for them is the same defect in a second language. The two
# linters disagreed about this until Clocktower's audit (#4) noticed. The file's `# Project:`
# header says who wrote it; a file with no owner header is linted, since only a header
# naming someone else is a claim that it is theirs.
OWNER_RE='^#[[:space:]]*Project:[[:space:]]*ai-project-scaffold[[:space:]]*$'
ANY_OWNER_RE='^#[[:space:]]*Project:'
is_ours() {
  local head8; head8="$(head -8 "$1" 2>/dev/null)"
  printf '%s\n' "$head8" | grep -qE "$OWNER_RE" && return 0
  printf '%s\n' "$head8" | grep -qE "$ANY_OWNER_RE" && return 1
  return 0
}
shell_files() {
  local f
  git ls-files -z 2>/dev/null | while IFS= read -r -d '' f; do
    [ -f "$f" ] || continue
    is_ours "$f" || continue
    case "$f" in
      *.sh|*.bash) printf '%s\n' "$f"; continue ;;
    esac
    case "$(head -c 80 "$f" 2>/dev/null | head -1)" in
      '#!'*/sh|'#!'*/bash|'#!'*env\ sh|'#!'*env\ bash) printf '%s\n' "$f" ;;
    esac
  done
}

# A COMMENT THAT STARTS `# shellcheck ` IS PARSED AS A DIRECTIVE (Clocktower #10). At 0.11.0
# "# shellcheck found this" is not prose to it; it is a malformed directive, reported as
# SC1072/SC1073 parse errors that name neither the word nor the fix. Named here instead.
DIRECTIVE_KEYS='disable|enable|source|source-path|shell|external-sources|extended-analysis'
misread_directives() {  # <file>...
  local f
  for f in "$@"; do
    grep -nE '^[[:space:]]*#[[:space:]]*shellcheck[[:space:]]' "$f" 2>/dev/null \
      | grep -vE "#[[:space:]]*shellcheck[[:space:]]+($DIRECTIVE_KEYS)=" \
      | sed "s|^|$f:|"
  done
}

# A BARE `VAR="$(mktemp ...)"` FAILS OPEN INTO THE CALLER'S DIRECTORY. When mktemp fails
# (it does under a Claude Code sandbox) VAR is empty, `cd "$VAR"` is a no-op and "$VAR/x" is
# /x. On 2026-09-23 header_check's selftest ran git init/add/commit in the real repo that way
# and a push published it into Robiton/control. Every mktemp assignment must carry `||` or
# `&&` on its line, or be tested with `if [ -n "$VAR" ]` on the next. awk reads the path
# through ENVIRON, not -v, which macOS awk mangles.
# AND EVERY mktemp NAMES A "${TMPDIR:-/tmp}/..." TEMPLATE. Measured 2026-09-23: macOS
# `mktemp -d` with no template IGNORES TMPDIR and uses the per-user system temp dir, so under
# a sandbox that sets TMPDIR to its only writable directory, a bare mktemp fails. That is
# how header_check's failed in the first place.
bare_mktemp() {  # <file>...
  local f
  for f in "$@"; do
    BM_FILE="$f" awk '
      pend != "" {
        if ($0 !~ ("^[[:space:]]*if \\[ -n \"\\$" pvar "\"")) print ENVIRON["BM_FILE"] ":" pn ": " pend
        pend = ""
      }
      /^[[:space:]]*#/ { next }
      /[A-Za-z_][A-Za-z0-9_]*="\$\(mktemp/ && $0 !~ /mktemp.*(\|\||&&)/ && $0 !~ /(^|[[:space:]])(if|!)[[:space:]]/ {
        match($0, /[A-Za-z_][A-Za-z0-9_]*="\$\(mktemp/)
        pvar = substr($0, RSTART, RLENGTH); sub(/=.*/, "", pvar)
        pend = $0; pn = NR
      }
      /\$\(mktemp( -[a-z]+)*( 2>\/dev\/null)?\)/ { print ENVIRON["BM_FILE"] ":" NR ": (no TMPDIR template) " $0 }
      END { if (pend != "") print ENVIRON["BM_FILE"] ":" pn ": " pend }
    ' "$f" 2>/dev/null
  done
}

runner_version() { "$1" --version 2>/dev/null | sed -n 's/^version: *//p' | head -1; }

# Resolve a shellcheck AT THE PIN, or report that we could not.
resolve_runner() {
  local cand v
  for cand in shellcheck; do
    command -v "$cand" >/dev/null 2>&1 || continue
    v="$(runner_version "$cand")"
    if [ "$v" = "$SHELLCHECK_PIN" ]; then printf '%s\n' "$cand"; return 0; fi
    printf 'MISMATCH %s\n' "${v:-unreadable}"; return 1
  done
  printf 'ABSENT\n'; return 1
}

gap() {
  echo "shell_lint: DID NOT RUN — $1"
  echo "  This is exit 3: NOT a pass. Nothing was examined."
  echo "  Install shellcheck $SHELLCHECK_PIN, or run this where it is present."
  exit 3
}

run_check() {
  local r res files n
  files="$(shell_files)"
  if [ -z "$files" ]; then gap "no shell files are tracked here"; fi
  n="$(printf '%s\n' "$files" | wc -l | tr -d ' ')"

  # BEFORE THE RUNNER: this needs no shellcheck, so it holds where shellcheck is absent too.
  local bad_dir
  # shellcheck disable=SC2086
  bad_dir="$(misread_directives $files)"
  if [ -n "$bad_dir" ]; then
    echo "shell_lint: comment(s) that shellcheck will parse as a DIRECTIVE"
    printf '%s\n' "$bad_dir" | sed 's/^/  /'
    echo ""
    echo "  A comment starting \`# shellcheck \` must be a directive (disable=, source=, ...)."
    echo "  Reword it -- \`# ShellCheck found\` or \`# per shellcheck\` -- or shellcheck reports"
    echo "  SC1072/SC1073 parse errors at this line and lints nothing after it."
    return 1
  fi

  local bare_mk
  # shellcheck disable=SC2086
  bare_mk="$(bare_mktemp $files)"
  if [ -n "$bare_mk" ]; then
    echo "shell_lint: mktemp result(s) used without a failure check"
    printf '%s\n' "$bare_mk" | sed 's/^/  /'
    echo ""
    echo "  Add  || { echo \"<tool>: mktemp failed; stopping\" >&2; exit 1; }  to the line, and"
    echo "  a template:  mktemp -d \"\${TMPDIR:-/tmp}/<tool>.XXXXXX\"  (macOS ignores TMPDIR without one)."
    echo "  An empty temp dir turns \`cd \"\$T\"\` into a no-op, and the fixture runs in the real repo."
    return 1
  fi

  res="$(resolve_runner)" || {
    case "$res" in
      ABSENT)      gap "no shellcheck on PATH" ;;
      MISMATCH\ *) gap "shellcheck ${res#MISMATCH } is not the pinned $SHELLCHECK_PIN — a different shellcheck is a different gate" ;;
      *)           gap "could not resolve a shellcheck" ;;
    esac
  }
  r="$res"


  local out rc
  # shellcheck disable=SC2086
  out="$(printf '%s\n' "$files" | xargs "$r" -f gcc -S "$SEVERITY" 2>&1)" && rc=0 || rc=$?

  if [ "$rc" = "0" ] && [ -z "$out" ]; then
    echo "shell_lint: $n shell file(s) clean at shellcheck $SHELLCHECK_PIN, severity >= $SEVERITY"
    echo "  SEVERITY FLOOR IS \`$SEVERITY\` — findings below it are NOT examined here."
    echo "  \`$r -f gcc -S style\` shows the full backlog; this gate is deliberately not it."
    return 0
  fi

  echo "shell_lint: shellcheck $SHELLCHECK_PIN found finding(s) at severity >= $SEVERITY"
  printf '%s\n' "$out" | sed 's/^/  /'
  echo ""
  echo "  A finding at this level is a defect, not style. If it is genuinely a false"
  echo "  positive, suppress it AT THE LINE with a reason:  # shellcheck disable=SCxxxx"
  echo "  SEVERITY IS PER FINDING, NOT PER CODE: SC2086 on a plain unquoted \$f is info and"
  echo "  never reaches this floor, so a clean run here is not a clean run of every SC code."
  return 1
}

# ---- selftest ---------------------------------------------------------------------------
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); }
bad() { FAIL=$((FAIL+1)); echo "  [FAIL] $1"; }
case_is() { if [ "$2" = "$3" ]; then ok; else bad "$1: expected [$3] got [$2]"; fi; }

selftest() {
  echo "shell_lint.sh --selftest"
  # T IS DELIBERATELY NOT `local`. The EXIT trap fires after this function has returned, so
  # a local T is out of scope by then and `set -u` turns the cleanup into an error message
  # printed on every single run -- a line that looks like a failure on a passing selftest.
  # FIXTURES RUN INSIDE A GUARDED ROOT (tools/fixture_guard.sh). Later mktemps land inside it,
  # and a git on PATH refuses any write outside it. The guard exists because a failed mktemp
  # once let a selftest run git init and commit in the real repo.
  . "$(dirname "${BASH_SOURCE[0]}")/fixture_guard.sh" || { echo "shell_lint: tools/fixture_guard.sh is missing; refusing to build fixtures" >&2; exit 1; }
  fixture_root FG_ROOT; trap fg_cleanup EXIT
  T="$(mktemp -d "${TMPDIR:-/tmp}/shell_lint.XXXXXX")" || { echo "shell_lint: mktemp failed; stopping" >&2; exit 1; }; trap 'rm -rf "$T"; fg_cleanup' EXIT

  # 1. the resolver must reject a non-pin version rather than answer with it
  local fake="$T/bin"; mkdir -p "$fake"
  printf '#!/bin/sh\necho "version: 0.0.1"\n' > "$fake/shellcheck"; chmod +x "$fake/shellcheck"
  local got; got="$(PATH="$fake:$PATH" bash -c '
    SHELLCHECK_PIN="0.11.0"
    v="$(shellcheck --version 2>/dev/null | sed -n "s/^version: *//p" | head -1)"
    [ "$v" = "$SHELLCHECK_PIN" ] && echo ACCEPTED || echo REJECTED')"
  case_is "a non-pin shellcheck is refused" "$got" "REJECTED"

  # 2. THE INSTRUMENT MUST FAIL WHAT IT CLAIMS TO CATCH. This is the exact defect the gate
  #    found on the day it was written, reconstructed. bash -n passes it; shellcheck must not.
  local bug="$T/bug.sh"
  printf '#!/usr/bin/env bash\nV=x\necho "so every ${{ vars || '"'"'u'"'"' }}"\n' > "$bug"
  if bash -n "$bug" 2>/dev/null; then ok; else bad "precondition: bash -n should PASS the buggy file"; fi
  if command -v shellcheck >/dev/null 2>&1 && [ "$(runner_version shellcheck)" = "$SHELLCHECK_PIN" ]; then
    shellcheck -f gcc -S error "$bug" >/dev/null 2>&1 && bad "shellcheck did NOT flag the bad substitution" || ok
    # 3. and it must PASS the escaped form, or it is not discriminating
    local fixed="$T/fixed.sh"
    printf '#!/usr/bin/env bash\nV=x\necho "so every \\${{ vars || '"'"'u'"'"' }}"\n' > "$fixed"
    shellcheck -f gcc -S error "$fixed" >/dev/null 2>&1 && ok || bad "shellcheck flagged the CORRECT escaped form"
  else
    echo "  [skip] no shellcheck at the pin here — the two discrimination cases did not run."
    echo "         That is a GAP in this selftest, not a pass; CI runs them on the runner."
  fi

  # 4. shebang discovery must find an extensionless shell file
  local d="$T/repo"; mkdir -p "$d"; ( cd "$d" && git init -q . 2>/dev/null )
  printf '#!/bin/sh\ntrue\n' > "$d/runme"; chmod +x "$d/runme"
  printf '#!/bin/sh\n# Project:  someone-else\ntrue\n' > "$d/theirs.sh"
  printf '#!/bin/sh\n# Project:  ai-project-scaffold\ntrue\n' > "$d/ours.sh"
  printf 'not a script\n' > "$d/notes.txt"
  ( cd "$d" && git add -A >/dev/null 2>&1 )
  # NO `case` INSIDE `$( )` HERE. bash 3.2 -- which is /bin/bash on every Mac in this
  # estate -- misparses the `)` that closes a case PATTERN as the `)` that closes the
  # command substitution, and reports `syntax error near unexpected token newline' against
  # a line that is perfectly valid. This selftest hit exactly that on first run.
  local found=""
  local f
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    if [ "${f%.sh}" != "$f" ]; then found="$found$f"; continue; fi
    local first; first="$(head -1 "$d/$f" 2>/dev/null)"
    if [ "${first#\#!}" != "$first" ] && [ "${first%sh}" != "$first" ]; then found="$found$f"; fi
  done <<EOF
$( cd "$d" && git ls-files )
EOF
  case_is "an extensionless #!/bin/sh file is discovered" "${found#*runme}" "${found#*runme}"
  [ "${found#*runme}" != "$found" ] || bad "the extensionless runme was not discovered: [$found]"

  # 5. a non-script must NOT be picked up
  case_is "a .txt file is not discovered" "$(printf '%s\n' "$found" | grep -c notes.txt)" "0"

  # 6. OWNERSHIP (#4), through the real shell_files: ours and unowned in, theirs out.
  ( cd "$d" && shell_files ) > "$T/list" 2>/dev/null
  case_is "a file whose header names ANOTHER project is not linted (#76/#4)" \
    "$(grep -c '^theirs.sh$' "$T/list")" "0"
  case_is "a file whose header names the scaffold is linted" "$(grep -c '^ours.sh$' "$T/list")" "1"
  case_is "a file with no owner header is linted" "$(grep -c '^runme$' "$T/list")" "1"

  # 7. A PROSE COMMENT THAT SHELLCHECK WOULD READ AS A DIRECTIVE (#10) is named; a real
  #    directive and a comment that merely mentions the tool mid-sentence are not.
  printf '#!/bin/sh\n# shellcheck found this last week\ntrue\n' > "$T/prose.sh"
  printf '#!/bin/sh\n# shellcheck disable=SC2086\n# per shellcheck, fine\ntrue\n' > "$T/fine.sh"
  case_is "a '# shellcheck <prose>' comment is flagged" \
    "$(misread_directives "$T/prose.sh" | grep -c ':2:')" "1"
  case_is "a real directive and a mid-sentence mention are not" \
    "$(misread_directives "$T/fine.sh" | wc -l | tr -d ' ')" "0"
  #    ...and --check reaches it: with only a wrong-version shellcheck on hand the run is
  #    exit 1 naming the line, not exit 3, because the directive check needs no runner.
  cp "$T/prose.sh" "$d/prose.sh"; ( cd "$d" && git add prose.sh >/dev/null 2>&1 )
  local rc_chk=0
  ( cd "$d" && PATH="$fake:$PATH" run_check ) > "$T/chk" 2>&1 || rc_chk=$?
  case_is "--check names a misread directive, without a shellcheck at the pin" \
    "$rc_chk:$(grep -c 'prose.sh:2:' "$T/chk")" "1:1"

  # 8. A BARE MKTEMP ASSIGNMENT is named; a guarded one, a conditional one and one tested on
  #    the next line are not. Then --check must reach it without a shellcheck at the pin.
  #    The command name goes in through %s so this line cannot match its own pattern.
  printf '#!/bin/sh\nX="$(%s -d)"\ncd "$X"\n' mktemp > "$T/mk_bare.sh"
  printf '#!/bin/sh\nA="$(mktemp -d "${TMPDIR:-/tmp}/shell_lint.XXXXXX")" || exit 1\nif ! B="$(mktemp "${TMPDIR:-/tmp}/shell_lint.XXXXXX")"; then exit 1; fi\nC="$(mktemp "${TMPDIR:-/tmp}/shell_lint.XXXXXX")"\nif [ -n "$C" ]; then :; fi\n# D="$(mktemp "${TMPDIR:-/tmp}/shell_lint.XXXXXX")"\n' > "$T/mk_ok.sh"
  case_is "an unguarded mktemp assignment is flagged" "$(bare_mktemp "$T/mk_bare.sh" | grep -c ':2: X=')" "1"
  printf '#!/bin/sh\nY="$(%s -d)" || exit 1\n' mktemp > "$T/mk_notpl.sh"
  case_is "a guarded mktemp with no TMPDIR template is flagged" \
    "$(bare_mktemp "$T/mk_notpl.sh" | grep -c 'no TMPDIR template')" "1"
  case_is "guarded, conditional, next-line-tested and commented mktemps are not" \
    "$(bare_mktemp "$T/mk_ok.sh" | wc -l | tr -d ' ')" "0"
  git -C "$d" rm -q --cached prose.sh >/dev/null 2>&1; rm -f "$d/prose.sh"
  cp "$T/mk_bare.sh" "$d/mk_bare.sh"; ( cd "$d" && git add mk_bare.sh >/dev/null 2>&1 )
  rc_chk=0
  ( cd "$d" && PATH="$fake:$PATH" run_check ) > "$T/chk2" 2>&1 || rc_chk=$?
  case_is "--check names a bare mktemp, without a shellcheck at the pin" \
    "$rc_chk:$(grep -c 'mk_bare.sh:2: X=' "$T/chk2")" "1:1"

  echo "  $PASS passed, $FAIL failed"
  [ "$FAIL" = "0" ]
}

case "${1:---check}" in
  --check)    run_check ;;
  --list)     shell_files ;;
  --pin)      echo "$SHELLCHECK_PIN (severity floor: $SEVERITY)" ;;
  --selftest) selftest ;;
  *) echo "usage: shell_lint.sh [--check | --list | --pin | --selftest]" >&2; exit 2 ;;
esac
