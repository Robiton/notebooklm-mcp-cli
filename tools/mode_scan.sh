#!/usr/bin/env bash
# Project:  ai-project-scaffold
# File:     tools/mode_scan.sh
# Modified: 2026-09-23
# Version:  0.3.3.20260923.0941
# Purpose:  Fail while a tracked file's mode disagrees with its shebang — a tool at 644 stops running.
# Changelog:
#   2026-09-23 v0.3.3.20260923.0941 — fixtures run inside the root tools/fixture_guard.sh validates. There a git and a mktemp on PATH refuse anything that would land outside it. Every mktemp takes a ${TMPDIR} template, because macOS mktemp ignores TMPDIR without one.
#   2026-09-23 v0.3.2.20260923.0843 — every mktemp fails closed. A failed one left the temp variable empty, so the fixture ran in the caller's directory; header_check's committed into Robiton/control.
#   2026-09-23 v0.3.1.20260923.0733 — In an adoption, one `git grep` prefilters the files that
#                                     could carry the owner line; the head -8 test still decides.
#                                     godsfall: 23s -> 0.6s, output identical.
#   2026-08-18 v0.3.0.20260818.2135 — --fix, because the hint was not enough. This scanner
#                        caught the same defect FOUR times in one session: a new tool
#                        arrives from an upgrade, `git add` records it 644 because
#                        core.fileMode is false, and the suite it ships silently never
#                        runs. Every time the message named the exact command, and every
#                        time it was one file at a time. A remedy that scales with the
#                        number of findings is one people batch and then forget.
#                        It applies the SAME `git update-index` the message prints, to the
#                        INDEX only -- the working tree is never touched, so `git diff
#                        --cached` shows exactly what changed before you commit it.
#                        Two cases, both halves: --fix must repair the mode, and the PLAIN
#                        scan must still change nothing. A gate that quietly mutates the
#                        repository it is judging is worse than the defect.
#   2026-08-11 v0.2.0 — Catches skip-worktree and assume-unchanged (#D-10). Same defect
#                        class as the mode bit and that is why it lives here: git's record
#                        disagrees with the disk and nothing on screen says so. The mode bit
#                        makes a tool stop running; these make git stop LOOKING.
#                        MEASURED here 2026-08-11: ai/eval_tasks.py carried the bit with 14
#                        tasks on disk and 2 in HEAD, while the scaffold published pass@1
#                        scores measured against the 14. Anyone cloning got numbers they
#                        could not reproduce, and two people spent a review round measuring
#                        different things without either being wrong.
#                        Three cases, including the negative one: a scan that flagged every
#                        repository would be switched off, and most have nothing hidden.
#   2026-08-09 v0.1.0 — New, extracted from .github/workflows/scaffold-check.yml (#166).
#                        THIS RULE HAS NOW CAUGHT THE SAME MISTAKE THREE TIMES, AND EVERY
#                        TIME IT CAUGHT IT REMOTELY. tools/conflict_scan.sh landed as 644
#                        and its 15 new cases did not run while CI printed "12 tool selftest
#                        suite(s) passed" in green; tools/preflight.sh and
#                        tools/lint_python.sh did exactly the same thing on the PR that
#                        introduced the local pre-push gate — a gate that could not catch the
#                        defect in itself, because it ran the selftests off the FILESYSTEM
#                        mode while git records its own.
#                        That is the whole reason this is a file now. As inline shell in a
#                        `run:` block it could only ever run in CI. As tools/*_scan.sh it is
#                        discovered by `setup.sh --check`, by `tools/preflight.sh` and by the
#                        workflow, with no edit to any of them — and it has a selftest.
#                        `git config core.fileMode false` is the setting that makes this
#                        invisible locally, and it is the CORRECT setting on a filesystem
#                        that reports 0700 for everything (this repo lives on one). So the
#                        index is what gets asked, never the working tree.
set -u

cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)" || exit 2

# WHOSE FILES ARE IN SCOPE.
#
# In the upstream scaffold: every tracked file. The scaffold SHIPS its own modes, so a wrong
# one is a product defect — measured 2026-08-08, 45 of 92 tracked files were 755 with no
# shebang, including every ai/*.md, LICENSE and a .png, because this repo lives on a
# OneDrive-backed path that reports 0700 for everything.
#
# In an ADOPTION: only files whose header says the scaffold wrote them. Failing an adopter's
# build over a mode bit on THEIR file would be #76 again — their files, their call, possibly
# a mode we gave them. But a VENDORED tool that lost its +x is a tool that silently stopped
# running in their project too, and that they do want to know. Same ownership question
# tools/lint_python.sh asks, answered the same way: ask the file.
OWNER_RE='^#[[:space:]]*Project:[[:space:]]*ai-project-scaffold[[:space:]]*$'

is_upstream() {
  [ -d overlays ] && [ -f OVERVIEW.md ] && [ -f .github/workflows/mirror-sync.yml ]
}

# `<mode>\t<path>` for every tracked file — in an adoption, only the files that MIGHT be ours.
# ONE `git grep` PREFILTER, then the exact head -8 test in the loop. Asking every file costs
# two processes each: godsfall (3,991 files, 3,731 of them game assets) spent 23s here against
# 0.7s for the scaffold, inside a fixture preflight that runs twice per CI job under an 8-minute
# ceiling. A file with the owner line nowhere in it cannot have it in its first 8 lines, so
# the prefilter only removes files the loop would have skipped.
staged_modes() {
  local t; t="$(printf '\t')"
  if [ "$1" -eq 1 ]; then
    git ls-files -s 2>/dev/null | sed "s/^\([0-9]*\) [0-9a-f]* [0-9]*$t/\1$t/"
  else
    { git grep -lIE "$OWNER_RE" 2>/dev/null; printf '%s\n' "${t}END${t}"
      git ls-files -s 2>/dev/null | sed "s/^\([0-9]*\) [0-9a-f]* [0-9]*$t/\1$t/"
    } | awk -F'\t' 'm == 0 { if ($0 == "\tEND\t") m = 1; else c[$0] = 1; next } ($2 in c)'
  fi
}

scan() {
  local upstream=0 bad=0 checked=0 fixed=0 mode f
  is_upstream && upstream=1

  # Paths come off a TAB, not whitespace: `git ls-files -s` prints
  # `<mode> <hash> <stage>\t<path>`, and splitting on spaces loses a path containing one —
  # the defect tools/secret_scan.sh v0.2.0 already paid for.
  while IFS="$(printf '\t')" read -r mode f; do
    [ -n "${f:-}" ] || continue
    [ -f "$f" ] || continue
    if [ "$upstream" -eq 0 ]; then
      head -8 "$f" 2>/dev/null | grep -qE "$OWNER_RE" || continue
    fi
    checked=$((checked + 1))
    if head -1 "$f" 2>/dev/null | grep -q '^#!'; then
      if [ "$mode" = "100644" ]; then
        # THIS DIRECTION IS THE DANGEROUS ONE. A script that lost its +x does not error —
        # it silently stops being run by every loop that filters on `[ -x ]`, and a suite
        # that did not run looks exactly like a suite that passed.
        if [ "${MODE_FIX:-0}" = "1" ]; then
          git update-index --chmod=+x "$f" && echo "  [FIXED] $f -> 755"
          fixed=$((fixed + 1))
        else
          echo "  [DEAD] $f has a shebang but git records it as 644 — it will not run."
          echo "         Fix: git update-index --chmod=+x '$f'   (or: tools/mode_scan.sh --fix)"
          bad=1
        fi
      fi
    elif [ "$mode" = "100755" ]; then
      if [ "${MODE_FIX:-0}" = "1" ]; then
        git update-index --chmod=-x "$f" && echo "  [FIXED] $f -> 644"
        fixed=$((fixed + 1))
      else
        echo "  [755 ] $f is executable with no shebang."
        echo "         Fix: git update-index --chmod=-x '$f'   (or: tools/mode_scan.sh --fix)"
        bad=1
      fi
    fi
  done < <(staged_modes "$upstream")

  if [ "$checked" -eq 0 ]; then
    # Not a git repo, or nothing in scope. Say which rather than reporting a clean tree —
    # "no findings" and "did not look" print identically otherwise.
    if git rev-parse --git-dir >/dev/null 2>&1; then
      echo "mode_scan: no files in scope (no scaffold-owned files here). DID NOT check modes."
    else
      echo "mode_scan: not a git repository — file modes were NOT checked."
    fi
    return 0
  fi
  # ---- SKIP-WORKTREE AND ASSUME-UNCHANGED (#D-10) --------------------------------------
  #
  # SAME DEFECT CLASS AS THE MODE BIT, WHICH IS WHY IT LIVES HERE: git's record of a file
  # disagrees with what is on disk, and nothing on screen says so. The mode bit makes a tool
  # stop running; these make git stop LOOKING. `git status` reports clean, `git diff` shows
  # nothing, and a commit silently ships the old content.
  #
  # MEASURED 2026-08-11 in this repository: ai/eval_tasks.py carried the skip-worktree bit
  # with 14 tasks on disk and 2 in HEAD. The scaffold published model pass@1 scores measured
  # against those 14, so anyone cloning got numbers they could not reproduce and a suite that
  # produces different ones — and two people spent a review round measuring different things
  # without either being wrong. It had been set for days and `git status` never mentioned it.
  #
  # `git ls-files -v` prefixes each path with a tag: H is normal, S is skip-worktree, and a
  # LOWERCASE tag means assume-unchanged. Both hide content; both are almost always someone
  # silencing a file they meant to come back to.
  local hidden
  hidden="$(git ls-files -v 2>/dev/null | grep -E '^([a-z]|S) ' || true)"
  if [ -n "$hidden" ]; then
    echo ""
    echo "  [DEAD] git has been told to IGNORE CHANGES to these tracked files:"
    printf '%s\n' "$hidden" | sed 's/^/         /'
    echo "         git status reports clean and a commit ships the OLD content."
    echo "         Fix:  git update-index --no-skip-worktree <path>"
    echo "               git update-index --no-assume-unchanged <path>"
    echo "         Then look at the diff — it may be large and it has been invisible."
    bad=1
  fi

  if [ "$bad" -eq 1 ]; then
    echo ""
    echo "  Set 'git config core.fileMode false' if your filesystem reports every file as"
    echo "  executable — and note that setting is exactly why this is invisible locally:"
    echo "  the mode git RECORDS is not the mode on your disk."
    return 1
  fi
  echo "mode_scan: $checked tracked file(s) — modes agree with shebangs, none hidden from git."
  return 0
}

selftest() {
  local pass=0 fail=0 tmp rc out
  echo "mode_scan selftest — a suite that did not run looks exactly like one that passed"
  ok()  { echo "  ok    $1"; pass=$((pass + 1)); }
  bad() { echo "  FAIL  $1"; fail=$((fail + 1)); }

  # FIXTURES RUN INSIDE A GUARDED ROOT (tools/fixture_guard.sh). Later mktemps land inside it,
  # and a git on PATH refuses any write outside it. The guard exists because a failed mktemp
  # once let a selftest run git init and commit in the real repo.
  . "$(dirname "${BASH_SOURCE[0]}")/fixture_guard.sh" || { echo "mode_scan: tools/fixture_guard.sh is missing; refusing to build fixtures" >&2; exit 1; }
  fixture_root FG_ROOT; trap fg_cleanup EXIT
  tmp="$(mktemp -d "${TMPDIR:-/tmp}/modescan.XXXXXX")" || { echo "mode_scan: mktemp failed; stopping" >&2; exit 1; }
  mkdir -p "$tmp/tools" "$tmp/overlays" "$tmp/.github/workflows"
  : > "$tmp/OVERVIEW.md"; : > "$tmp/.github/workflows/mirror-sync.yml"
  cp "${BASH_SOURCE[0]}" "$tmp/tools/mode_scan.sh"
  printf '#!/bin/sh\nexit 0\n' > "$tmp/tools/runme.sh"
  printf '# Project:  ai-project-scaffold\nnotes\n' > "$tmp/tools/notes.md"
  ( cd "$tmp" && git init -q . && git config core.fileMode false \
      && git add -A && git update-index --chmod=+x tools/runme.sh tools/mode_scan.sh ) >/dev/null 2>&1

  rc=0; out="$("$tmp/tools/mode_scan.sh" 2>&1)" || rc=$?
  if [ "$rc" -eq 0 ]; then
    ok "a correctly-moded tree passes"
  else
    bad "a correct tree was failed: $(printf '%s' "$out" | head -2 | tr '\n' ' ')"
  fi

  # --fix REPAIRS IT, AND THE PLAIN SCAN STILL REFUSES TO. Both halves: a --fix that does
  # nothing would be a remedy people run and believe, and a plain scan that quietly fixed
  # things would make a gate mutate the repository it is judging.
  ( cd "$tmp" && git update-index --chmod=-x tools/runme.sh ) >/dev/null 2>&1
  rc=0; out="$( cd "$tmp" && ./tools/mode_scan.sh 2>&1 )" || rc=$?
  if [ "$rc" -ne 0 ] && [ "$( cd "$tmp" && git ls-files -s tools/runme.sh | cut -d' ' -f1 )" = "100644" ]; then
    ok "the plain scan REPORTS and changes nothing"
  else
    bad "the plain scan altered the index, or failed to report"
  fi
  rc=0; out="$( cd "$tmp" && ./tools/mode_scan.sh --fix 2>&1 )" || rc=$?
  if [ "$rc" -eq 0 ] && [ "$( cd "$tmp" && git ls-files -s tools/runme.sh | cut -d' ' -f1 )" = "100755" ]; then
    ok "--fix restores the mode and then passes"
  else
    bad "--fix did not repair the mode (exit $rc): $(printf '%s' "$out" | head -2 | tr '\n' ' ')"
  fi

  # THE CASE THAT MATTERS. A shebang at 644 is the silent one, and it is the one that has
  # now shipped three times.
  ( cd "$tmp" && git update-index --chmod=-x tools/runme.sh ) >/dev/null 2>&1
  rc=0; out="$("$tmp/tools/mode_scan.sh" 2>&1)" || rc=$?
  if [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q 'will not run'; then
    ok "a script git records as 644 is caught, and named as 'will not run'"
  else
    bad "a shebang recorded at 644 was not caught (exit $rc)"
  fi
  ( cd "$tmp" && git update-index --chmod=+x tools/runme.sh ) >/dev/null 2>&1

  # THE INDEX, NOT THE DISK. With core.fileMode false — the correct setting on a filesystem
  # that reports 0700 for everything, which is where this repo lives — chmod on disk changes
  # nothing git records. A scanner that read the working tree would report clean here, which
  # is exactly how this defect stays invisible until CI.
  chmod -x "$tmp/tools/runme.sh"
  rc=0; "$tmp/tools/mode_scan.sh" >/dev/null 2>&1 || rc=$?
  if [ "$rc" -eq 0 ]; then
    ok "a chmod on disk with core.fileMode false changes nothing — the index is asked"
  else
    bad "the working-tree mode was used instead of the recorded one"
  fi
  chmod +x "$tmp/tools/runme.sh"

  # 755 with no shebang: cosmetic, but it is OUR cosmetic and it travels to every adopter.
  ( cd "$tmp" && git update-index --chmod=+x tools/notes.md ) >/dev/null 2>&1
  rc=0; "$tmp/tools/mode_scan.sh" >/dev/null 2>&1 || rc=$?
  if [ "$rc" -ne 0 ]; then
    ok "an executable file with no shebang is caught"
  else
    bad "a 755 markdown file passed"
  fi
  ( cd "$tmp" && git update-index --chmod=-x tools/notes.md ) >/dev/null 2>&1

  # In an ADOPTION, the adopter's own files are not ours to fail — but a vendored tool that
  # lost its +x is, because it stops running in their project too.
  rm -f "$tmp/OVERVIEW.md"
  printf '#!/bin/sh\nexit 0\n' > "$tmp/tools/theirs.sh"
  ( cd "$tmp" && git add -A ) >/dev/null 2>&1
  rc=0; out="$("$tmp/tools/mode_scan.sh" 2>&1)" || rc=$?
  if [ "$rc" -eq 0 ]; then
    ok "an adopter's own 644 script is left alone (that would be #76)"
  else
    bad "an adopter's own file was failed: $(printf '%s' "$out" | head -2 | tr '\n' ' ')"
  fi
  ( cd "$tmp" && git update-index --chmod=-x tools/mode_scan.sh ) >/dev/null 2>&1
  rc=0; out="$("$tmp/tools/mode_scan.sh" 2>&1)" || rc=$?
  if [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q 'mode_scan.sh'; then
    ok "...but a VENDORED tool at 644 is still caught in an adoption"
  else
    bad "a scaffold-owned tool at 644 was ignored in an adoption (exit $rc)"
  fi

  # SKIP-WORKTREE, BOTH DIRECTIONS (#D-10). The negative case matters as much: a scan that
  # flagged every repo would be turned off, and most repos have no hidden files at all.
  tmp2="$(mktemp -d "${TMPDIR:-/tmp}/mode_scan.XXXXXX")" || { echo "mode_scan: mktemp failed; stopping" >&2; exit 1; }
  ( cd "$tmp2" && git init -q . && mkdir -p tools ai \
      && printf '#!/bin/sh\nexit 0\n' > tools/t.sh && chmod +x tools/t.sh \
      && printf 'x = 1\n' > ai/hidden.py \
      && git add -A && git -c commit.gpgsign=false commit -qm base ) >/dev/null 2>&1
  cp tools/mode_scan.sh "$tmp2/tools/mode_scan.sh"
  ( cd "$tmp2" && git add -A && git -c commit.gpgsign=false commit -qm scan ) >/dev/null 2>&1
  rc=0; out="$( cd "$tmp2" && ./tools/mode_scan.sh 2>&1 )" || rc=$?
  if [ "$rc" -eq 0 ]; then
    ok "a repo with nothing hidden from git passes"
  else
    bad "a clean repo was flagged as having hidden files (exit $rc)"
  fi
  ( cd "$tmp2" && git update-index --skip-worktree ai/hidden.py ) >/dev/null 2>&1
  rc=0; out="$( cd "$tmp2" && ./tools/mode_scan.sh 2>&1 )" || rc=$?
  if [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q 'ai/hidden.py'; then
    ok "a skip-worktree file is caught and named"
  else
    bad "skip-worktree went unreported (exit $rc) — git status is silent, so nothing else looks"
  fi
  ( cd "$tmp2" && git update-index --no-skip-worktree ai/hidden.py \
      && git update-index --assume-unchanged ai/hidden.py ) >/dev/null 2>&1
  rc=0; out="$( cd "$tmp2" && ./tools/mode_scan.sh 2>&1 )" || rc=$?
  if [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q 'ai/hidden.py'; then
    ok "assume-unchanged is caught too (lowercase tag, same effect)"
  else
    bad "assume-unchanged went unreported (exit $rc)"
  fi
  rm -rf "$tmp2"

  rm -rf "$tmp"
  echo "  $pass passed, $fail failed"
  [ "$fail" -eq 0 ]
}

case "${1:-}" in
  --selftest) selftest ;;
  # --fix EXISTS BECAUSE THE HINT WAS NOT ENOUGH. This scanner has caught the same defect
  # four times in one session on this machine -- a new tool arrives from an upgrade, `git
  # add` records it 644 because core.fileMode is false, and the suite it ships silently
  # never runs. Every time, the message named the exact command and every time it was one
  # file at a time. A remedy that scales with the number of findings is a remedy people
  # batch and forget. This applies the SAME `git update-index` the message prints, to the
  # INDEX only: it never touches the working tree, so nothing is destroyed and `git diff
  # --cached` shows exactly what changed before you commit it.
  --fix)      MODE_FIX=1 scan ;;
  "")         scan ;;
  *)          echo "usage: mode_scan.sh [--fix|--selftest]" >&2; exit 2 ;;
esac
