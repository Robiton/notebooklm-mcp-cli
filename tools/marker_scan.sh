#!/usr/bin/env bash
# Project:  ai-project-scaffold
# File:     tools/marker_scan.sh
# Modified: 2026-09-23
# Version:  0.9.5.20260923.0941
# Purpose:  Every `scaffold:` marker at column 0 is one this scaffold actually reads.
# Changelog:
#   2026-09-23 v0.9.5.20260923.0941 — fixtures run inside the root tools/fixture_guard.sh validates. There a git and a mktemp on PATH refuse anything that would land outside it. Every mktemp takes a ${TMPDIR} template, because macOS mktemp ignores TMPDIR without one.
#   2026-09-14 v0.9.4.20260914.0624 — #307 register scaffold:no-releases (reader: tools/session_currency.sh).
#   2026-09-11 v0.9.3.20260911.1202 — register `documents`, read by tools/doc_currency.py. The registry
#                        exists so a marker nothing reads cannot be invented, and a new
#                        marker that skips it is exactly the dead declaration it guards
#                        against -- so this edit is part of shipping the gate, not after it.
#   2026-09-03 v0.9.2.20260903.1906 — register scaffold:ai-file-kind, read by tools/preflight.sh (#293).
#   2026-09-01 v0.9.1.20260901.1656 — REGISTERS hooks-unavailable (#275). The escape hatch
#                        for a client with no lifecycle hooks was read by session_hook.sh and
#                        absent from this registry, so --audit reported that nothing reads
#                        it. An unregistered marker is one a future cleanup deletes as dead.
#   2026-08-26 v0.9.0 — register scaffold:provenance, read by tools/provenance_check.sh. The registry key is
#                        the name before the SECOND colon -- `closeouts` covers
#                        `closeouts:begin` -- so this is one row, not two.
#   2026-08-19 v0.8.0 — `session-log` registered. tools/session_currency.sh reads it to find
#                        a record that lives in a sibling repo, which is where the split put
#                        localcoder's and the scaffold's own.
#   2026-08-18 — the three status_block markers registered. A marker nothing reads is
#                        indistinguishable from one that works, and this gate caught all three
#                        the moment they landed — which is the gate doing exactly its job on
#                        the author who added it.
#   2026-08-17 v0.6.0.20260817.0957 — register `closeouts`. THE SCAFFOLD SHIPPED A TOOL THAT WRITES AN
#                        UNREGISTERED MARKER. tools/close_out.py has written
#                        `scaffold:closeouts:begin/end` into ai/SESSION.md since 0.43.0, and
#                        this registry never listed it -- so every adopter who used the
#                        closeout adapter, which the session checklist tells them to use,
#                        failed setup.sh --check on a marker the scaffold itself put there.
#                        Found by an adopter's tree failing after an unrelated upgrade, which
#                        is the worst way to find it: the gate fires on work they did not do,
#                        in a file they did not edit, naming a marker they never typed.
#                        The reader column is close_out.py, so the reverse check -- a
#                        registered marker with nobody reading it -- is satisfied too.
#   2026-08-15 v0.5.0.20260815.1925 — Registers `version-stamp-baseline`, read by
#                        tools/release_status.sh. The gate caught its own author: the
#                        baseline was declared in AGENTS.md and wired to a real reader in the
#                        same change, and this registry still refused it — correctly, because
#                        "declared and wired" and "declared and inert" are indistinguishable
#                        from the declaration alone. That is the whole argument for the
#                        registry, demonstrated on the person adding a marker.
#   2026-08-16 v0.4.0.20260816.0900 — Registers `ci-down-until`, read by tools/ci_status.sh. Added
#                        because this gate CAUGHT IT: the declaration went into three AGENTS.md
#                        files and setup.sh --check went red on the same run, naming the file,
#                        the line and the reason. That is the composition rule working on a
#                        marker introduced an hour earlier, by the author who wrote the rule.
#   2026-08-15 v0.3.0.20260815.1100 — #212: SEGFAULT ON AN ADOPTER'S REPOSITORY, FIXED BY NOT WALKING EVERY
#                        TRACKED FILE. rc=139, empty output, 100% deterministic, taking
#                        setup.sh --check and preflight red on a repo where nothing was wrong.
#                        The loop iterated `git ls-files` — 3,903 files there — and opened a
#                        NESTED process substitution inside each iteration while the outer one
#                        stayed open. macOS ships bash 3.2.57, which backs process substitution
#                        with /dev/fd; thousands nested is the shape that faults. The reporter's
#                        bisect is what made it legible: same bash either way, dying only
#                        through the shebang from a bash parent, and SIGSEGV becoming SIGBUS
#                        under `env -i`.
#                        THEY ALSO NAMED THE FIX WITHOUT KNOWING IT: secret_scan.sh and
#                        stale_path_scan.sh walk the same tree and are fine because they
#                        PREFILTER with one `git grep`. This now does the same, so the loop
#                        visits the handful of files that contain a marker.
#                        -I SKIPS BINARIES. A marker can only appear in a text file, so feeding
#                        ~700 .gltf/.bin/PNG/LFS blobs to grep was wasted work independent of
#                        the crash — and a marker-shaped byte run inside an asset is not a
#                        declaration.
#                        Reproduced locally by mutation: restoring the per-file walk kills an
#                        800-file fixture with 200 binaries.
#   2026-08-14 v0.2.0 — --audit NO LONGER ACCEPTS A COMMENT AS EVIDENCE OF A READER, and
#                        found FOUR wrong rows out of twelve the moment it stopped.
#                        `not-a-secret` was credited to conflict_scan.sh on the strength of a
#                        comment reading "the same argument as scaffold:not-a-secret in
#                        tools/secret_scan.sh applies"; `ceilings` to conflict_scan.sh, which
#                        only builds one inside a printf fixture; `no-artifact` to
#                        header_check.sh, when setup.sh reads it. All three passed.
#                        `localcoder-forked` is RETIRED: nothing in any repository reads it
#                        outside a comment. It gated a drift check on a vendored
#                        tools/localcoder and the scaffold stopped shipping one in W-15 —
#                        the second dead marker of this exact shape after `-diverged`.
#                        A READ IS CODE. The signal is a mention on a line whose first
#                        non-blank character is not `#`. RESIDUAL WEAKNESS, STATED: a marker
#                        inside a fixture STRING on a code line still reads as a reader, which
#                        is why a row is checked for MEMBERSHIP in the derived set and why an
#                        empty derived set is a hard failure.
#   2026-08-13 v0.1.0 — New. THE COMPOSITION RULE, MADE MECHANICAL.
#                        A marker is a declaration read by a downstream consumer, and a
#                        declaration nothing reads is indistinguishable from one that works.
#                        There are thirteen marker names in this tree, all read at column 0,
#                        every one by a different grep in a different tool, and a misspelling
#                        is SILENTLY INERT — `scaffold:must-runs` looks exactly like a
#                        declaration and does exactly nothing. That is defect 1 of this
#                        programme in its purest form, and it had no checker.
#
#                        Found on its first run, live in `ai/STANDARDS.md` — the file loaded
#                        into every session — in ALL THREE repositories:
#
#                          <!-- scaffold:localcoder-diverged localcoder_bench.py -->
#                          <!-- scaffold:localcoder-diverged audit_localcoder.sh -->
#
#                        That marker was RETIRED with tools/localcoder_sync.py in W-15. The
#                        only mention left in tools/ is a sentence in README.md saying it is
#                        gone. Four declarations, three repositories, zero readers, sitting in
#                        the most-loaded file in the project and reading as live policy.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# ============================ THE REGISTRY ====================================
#
# Every marker this scaffold reads, and WHERE IT IS READ. The second column is not
# decoration: it is what makes an entry falsifiable. A registry that only lists names can go
# stale in the same way the markers did — a name stays in the list after its reader leaves,
# which is precisely how `localcoder-diverged` survived its own retirement.
#
# TO RETIRE A MARKER: delete the row, then run this. Every declaration of it in the tree now
# fails, which is the point — retiring a marker should be noisy on exactly the files that
# still declare it, not silent everywhere.
#
# TO ADD ONE: add the row, and make sure something reads it. `--audit` re-derives the reader
# column from the tree and complains if a registered marker has no reader, so a marker
# invented and never wired up is caught by the same gate.
MARKERS="
ai-file-kind|tools/preflight.sh
ceilings|tools/session_archive.py
status-repos|tools/status_block.sh
status-begin|tools/status_block.sh
status-end|tools/status_block.sh
ci-down-until|tools/ci_status.sh
documents|tools/doc_currency.py
context-ceiling|setup.sh
closeouts|tools/close_out.py
file-is-historical|tools/stale_path_scan.sh
header-baseline|tools/header_check.sh
hooks-unavailable|tools/session_hook.sh
hec-tokens-committed|tools/secret_scan.sh
must-run|tools/preflight.sh
no-artifact|setup.sh
no-releases|tools/session_currency.sh
not-a-conflict|tools/conflict_scan.sh
not-a-secret|tools/secret_scan.sh
owns-localcoder|tools/scaffold_upgrade.sh
path-not-an-instruction|tools/stale_path_scan.sh
product-dir|tools/preflight.sh
provenance|tools/provenance_check.sh
session-log|tools/session_currency.sh
version-stamp-baseline|tools/release_status.sh
"

registered() {  # registered <name>; 0 if in the registry
  printf '%s' "$MARKERS" | grep -qE "^$1\|"
}

# DID-YOU-MEAN, because the failure this exists to catch is a TYPO, and a checker that says
# "unknown marker" without naming the near miss makes the reader do the diff by eye. Longest
# common prefix is enough here: the real cases are `must-runs`, `product-dirs`, `not-a-secrets`.
nearest() {  # nearest <name>; prints the closest registered name, or nothing
  local want="$1" best="" bestlen=0 name plen
  while IFS='|' read -r name _; do
    [ -n "$name" ] || continue
    plen=0
    while [ "$plen" -lt "${#want}" ] && [ "$plen" -lt "${#name}" ]; do
      [ "${want:$plen:1}" = "${name:$plen:1}" ] || break
      plen=$((plen + 1))
    done
    if [ "$plen" -gt "$bestlen" ]; then bestlen=$plen; best="$name"; fi
  done <<< "$(printf '%s' "$MARKERS" | grep -v '^$')"
  [ "$bestlen" -ge 4 ] && printf '%s' "$best"
}

# ============================ THE SCAN =========================================
#
# COLUMN 0 ONLY, because that is the convention every reader already follows and AGENTS.md
# states: "an indented example is documentation, not a declaration". Scanning further left
# would make every worked example in the docs a declaration, and this checker would then
# fire on the files that teach people the syntax.
#
# Two forms, matching how the readers actually grep:
#   <!-- scaffold:<name> ... -->     markdown, the common case
#   # scaffold:<name> ...            shell and python
#
# A CHANGELOG LINE IS NOT A DECLARATION. `#   2026-08-05 v0.6.2 — the no-artifact marker`
# starts with `#` at column 0 and mentions a marker, and it is prose. The `#[[:space:]]*`
# anchor requires the marker to be the FIRST thing after the comment character, which is the
# same distinction stale_path_scan.sh draws between an instruction and a mention.
# ONE PROCESS FOR THE TREE, NOT TWO PER TRACKED FILE. THIS IS A CRASH FIX, NOT A TIDY-UP.
#
# Reported as #212 by an adopter on 0.39.0: `marker_scan.sh` SEGFAULTED, deterministically,
# with rc=139 and EMPTY output — taking `setup.sh --check` and therefore preflight red on a
# repository where nothing was wrong. Their bisect is what makes the cause legible: the same
# bash either way, dying only when launched through the `#!/usr/bin/env bash` shebang from a
# bash parent, and `env -i` turning SIGSEGV into SIGBUS. Both are memory faults.
#
# The loop iterated `git ls-files` — 3,903 files in their repo — and opened a NESTED PROCESS
# SUBSTITUTION inside each iteration, while the outer one stayed open. macOS ships bash 3.2.57,
# which implements process substitution with /dev/fd entries; thousands of them, nested, is the
# shape that faults. `secret_scan.sh` and `stale_path_scan.sh` walk the same tree and are fine
# BECAUSE THEY PREFILTER WITH ONE `git grep` — the adopter noticed exactly that difference and
# said so, which is what turned this from a crash report into a diagnosis.
#
# So the candidate list is now the handful of files that CONTAIN a marker, not every tracked
# file. -I skips binaries: a marker declaration can only appear in a text file, and feeding
# ~700 `.gltf`, `.bin`, PNG and LFS blobs to grep was wasted work independent of the crash.
candidates() {
  git grep -I -l -E '^(<!--|#)[[:space:]]*scaffold:[a-z]' -- . 2>/dev/null || true
}

scan() {
  git rev-parse --git-dir >/dev/null 2>&1 || {
    echo "[SKIP] marker_scan: not a git repository — NOT verified (exit 3)"
    return 3
  }

  local bad=0 seen=0 f line name lineno hint
  while IFS= read -r f; do
    [ -f "$f" ] || continue
    while IFS=: read -r lineno line; do
      [ -n "$lineno" ] || continue
      name="$(printf '%s' "$line" \
              | sed -nE 's/^(<!--|#)[[:space:]]*scaffold:([a-z][a-z-]*).*/\2/p')"
      [ -n "$name" ] || continue
      seen=$((seen + 1))
      if ! registered "$name"; then
        bad=$((bad + 1))
        echo "[FAIL] $f:$lineno  unknown marker: scaffold:$name"
        hint="$(nearest "$name")"
        if [ -n "$hint" ]; then
          echo "         did you mean scaffold:$hint ?"
        else
          echo "         not in the registry in tools/marker_scan.sh, so NOTHING READS IT."
        fi
        printf '         %s\n' "$line" | cut -c1-100
      fi
    done < <(grep -nE '^(<!--|#)[[:space:]]*scaffold:[a-z]' "$f" 2>/dev/null || true)
  done < <(candidates)

  if [ "$bad" -gt 0 ]; then
    echo ""
    echo "$bad unregistered marker declaration(s) at column 0, out of $seen scanned."
    echo "A marker nothing reads is indistinguishable from one that works — that is the"
    echo "whole reason this gate exists. Either register it in tools/marker_scan.sh and"
    echo "wire up a reader, or delete the declaration."
    return 1
  fi
  # THE COUNT IS PRINTED ON SUCCESS (DEC-18). A gate that discovers its own work can silently
  # do less of it, and "no unknown markers" reads identically whether it scanned 41 or zero.
  echo "[OK] $seen marker declaration(s) at column 0, all registered."
  return 0
}

# ============================ THE AUDIT ========================================
#
# The registry's second column claims a reader. This checks the claim, and it is the half
# that keeps the registry itself from becoming the next stale declaration — a name whose
# reader has left is exactly what `localcoder-diverged` was.
# WHICH FILES ACTUALLY READ A MARKER — DERIVED, NEVER DECLARED.
#
# "Mentions it" was the old test and it was far too weak. Measured 2026-08-14: FOUR of the
# twelve rows named the wrong file and all twelve passed, because a comment saying
# `the same argument as scaffold:not-a-secret in tools/secret_scan.sh applies` satisfies a
# grep for the marker. The instrument built to stop the registry becoming the next stale
# declaration had become one.
#
# The discriminating signal is that a READ is code. `ADJUDICATED='scaffold:not-a-secret|…'`
# and `re.compile(r"scaffold:ceilings…")` are executable; a `#` line explaining the marker is
# not. So: lines mentioning the marker whose first non-blank character is not `#`.
#
# RESIDUAL WEAKNESS, STATED RATHER THAN PAPERED OVER: a marker appearing inside a FIXTURE
# string on a code line reads as a reader. `conflict_scan.sh` builds a `scaffold:ceilings`
# marker inside a printf to make a merge-conflict fixture, and this cannot tell that from a
# read. That is why a row is checked for membership in the derived set rather than equality
# with it, and why a marker with an EMPTY derived set is a hard failure — the dead-marker
# case is the one that has actually bitten, twice.
readers_of() {  # readers_of <marker>; prints one path per line, possibly none
  local m="$1" f
  for f in "$ROOT"/tools/*.sh "$ROOT"/tools/*.py "$ROOT"/setup.sh; do
    [ -f "$f" ] || continue
    case "$f" in *marker_scan.sh) continue ;; esac
    if grep -E "scaffold:$m" "$f" 2>/dev/null | grep -qvE '^[[:space:]]*#'; then
      printf '%s\n' "${f#"$ROOT"/}"
    fi
  done
}

audit() {
  local name reader bad=0 derived
  while IFS='|' read -r name reader; do
    [ -n "$name" ] || continue
    derived="$(readers_of "$name")"
    if [ -z "$derived" ]; then
      # NOTHING EXECUTABLE MENTIONS IT. This is the `scaffold:localcoder-diverged` shape: a
      # marker a project can still declare, documented as live, read by nothing. Six dead
      # declarations of that one were found across three repos with the prose one line above
      # them already saying it was retired.
      echo "[FAIL] scaffold:$name — DEAD: no file reads it outside a comment."
      echo "       Either wire it up or retire it from the registry, ai/STANDARDS.md and"
      echo "       tools/README.md together. A marker nothing reads is indistinguishable"
      echo "       from one that works, which is the whole reason this registry exists."
      bad=$((bad + 1))
    elif [ ! -f "$ROOT/$reader" ]; then
      echo "[FAIL] scaffold:$name — declared reader $reader does not exist"
      echo "       Derived reader(s): $(printf '%s' "$derived" | tr '\n' ' ')"
      bad=$((bad + 1))
    elif ! printf '%s\n' "$derived" | grep -qxF "$reader"; then
      echo "[FAIL] scaffold:$name — $reader mentions it only in comments, if at all."
      echo "       Derived reader(s): $(printf '%s' "$derived" | tr '\n' ' ')"
      bad=$((bad + 1))
    fi
  done <<< "$(printf '%s' "$MARKERS" | grep -v '^$')"
  if [ "$bad" -gt 0 ]; then
    echo "$bad registry row(s) name a reader that does not read them."
    return 1
  fi
  echo "[OK] every registered marker is read, outside a comment, by the file the registry names."
  return 0
}

selftest() {
  local T fails=0 out got SELF_ABS="$ROOT/tools/marker_scan.sh"
  # FIXTURES RUN INSIDE A GUARDED ROOT (tools/fixture_guard.sh). Later mktemps land inside it,
  # and a git on PATH refuses any write outside it. The guard exists because a failed mktemp
  # once let a selftest run git init and commit in the real repo.
  . "$(dirname "${BASH_SOURCE[0]}")/fixture_guard.sh" || { echo "marker_scan: tools/fixture_guard.sh is missing; refusing to build fixtures" >&2; exit 1; }
  fixture_root FG_ROOT; trap fg_cleanup EXIT
  T="$(mktemp -d "${TMPDIR:-/tmp}/marker_scan.XXXXXX")" || return 1

  case_run() {  # case_run <label> <expected-exit> <setup-fn>
    local label="$1" want="$2" setup="$3" R="$T/case"
    rm -rf "$R"; mkdir -p "$R/tools" "$R/ai"
    ( cd "$R" && git init -q . && git config user.email a@b.c && git config user.name t )
    ( cd "$R" && $setup )
    ( cd "$R" && git add -A >/dev/null 2>&1 )
    out="$( cd "$R" && bash "$SELF_ABS" 2>&1 )"; got=$?
    if [ "$got" = "$want" ]; then printf '  ok   %-58s\n' "$label"
    else
      printf '  FAIL %-58s want exit %s, got %s\n' "$label" "$want" "$got"
      printf '%s\n' "$out" | sed 's/^/         /' | head -6
      fails=$((fails + 1))
    fi
  }

  echo "marker_scan selftest — a marker nothing reads is not a marker"

  # THE REAL ONE, BYTE FOR BYTE. Live in ai/STANDARDS.md in all three repos on 2026-08-13,
  # for a marker retired with tools/localcoder_sync.py in W-15.
  c_retired()  { printf '# S\n\n<!-- scaffold:localcoder-diverged localcoder_bench.py -->\n' > ai/STANDARDS.md; }
  # THE TYPO. This is the case the gate exists for: it looks exactly like a declaration.
  c_typo()     { printf '# A\n\n<!-- scaffold:must-runs tests/x.sh -->\n' > ai/AGENTS.md; }
  c_typo2()    { printf '# A\n\n<!-- scaffold:product-dirs src/x -->\n' > ai/AGENTS.md; }
  c_ok()       { printf '# A\n\n<!-- scaffold:must-run tests/x.sh -->\n' > ai/AGENTS.md; }
  c_ok_shell() { printf '#!/bin/sh\n# scaffold:not-a-secret\nexit 0\n' > tools/x.sh; }
  # AN INDENTED EXAMPLE IS DOCUMENTATION. AGENTS.md says so and every reader honours it; a
  # gate that fired here would fire on the files that teach the syntax, and be removed.
  c_indented() { printf '# A\n\nDeclare it like this:\n\n    <!-- scaffold:must-runs tests/x.sh -->\n' > ai/AGENTS.md; }
  # A CHANGELOG LINE IS PROSE. It starts with `#` at column 0 and names a marker, and if this
  # fired on it, no tool in this repo could document its own history.
  c_changelog() { printf '#!/bin/sh\n#   2026-08-05 v0.6.2 — the scaffold:no-artifact marker moved to column 0\nexit 0\n' > tools/x.sh; }
  # UNTRACKED FILES ARE NOT THE PROJECT. The scan walks git ls-files for the same reason
  # conflict_scan does: a scratch file in the tree is not a declaration anyone ships.
  c_untracked() { printf '# S\n\n<!-- scaffold:bogus-thing -->\n' > ai/NOTES.md; }
  c_empty()    { printf '# A\n\nnothing here\n' > ai/AGENTS.md; }

  case_run "a RETIRED marker still declared fails"        1 c_retired
  case_run "a typo'd must-run fails"                      1 c_typo
  case_run "a typo'd product-dir fails"                   1 c_typo2
  case_run "a correct marker passes"                      0 c_ok
  case_run "a correct marker in shell passes"             0 c_ok_shell
  case_run "an INDENTED example is documentation"         0 c_indented
  case_run "a changelog line naming a marker is prose"    0 c_changelog
  case_run "no markers at all passes"                     0 c_empty

  # The untracked case needs the file left out of the index, so it is run by hand.
  local R="$T/untracked"; rm -rf "$R"; mkdir -p "$R/ai"
  ( cd "$R" && git init -q . && git config user.email a@b.c && git config user.name t )
  ( cd "$R" && c_untracked )
  out="$( cd "$R" && bash "$SELF_ABS" 2>&1 )"; got=$?
  if [ "$got" = "0" ]; then printf '  ok   %-58s\n' "an UNTRACKED file is not a declaration"
  else printf '  FAIL %-58s want 0, got %s\n' "an UNTRACKED file is not a declaration" "$got"; fails=$((fails+1)); fi

  # DID-YOU-MEAN HAS TO NAME THE NEAR MISS, or the reader does the diff by eye on a name that
  # differs by one character.
  rm -rf "$T/hint"; mkdir -p "$T/hint/ai"
  ( cd "$T/hint" && git init -q . && git config user.email a@b.c && git config user.name t )
  ( cd "$T/hint" && c_typo && git add -A >/dev/null 2>&1 )
  out="$( cd "$T/hint" && bash "$SELF_ABS" 2>&1 )"
  if printf '%s' "$out" | grep -q "did you mean scaffold:must-run"; then
    printf '  ok   %-58s\n' "a typo is told which marker it nearly is"
  else
    printf '  FAIL %-58s\n' "a typo is told which marker it nearly is"
    printf '%s\n' "$out" | sed 's/^/         /' | head -4; fails=$((fails+1))
  fi

  # THE SUCCESS LINE CARRIES THE COUNT (DEC-18): "all registered" reads the same whether it
  # scanned forty declarations or none, and this project has shipped that defect twice.
  rm -rf "$T/cnt"; mkdir -p "$T/cnt/ai"
  ( cd "$T/cnt" && git init -q . && git config user.email a@b.c && git config user.name t )
  ( cd "$T/cnt" && c_ok && git add -A >/dev/null 2>&1 )
  out="$( cd "$T/cnt" && bash "$SELF_ABS" 2>&1 )"
  if printf '%s' "$out" | grep -qE '\[OK\] 1 marker declaration'; then
    printf '  ok   %-58s\n' "the pass line states how many it scanned"
  else
    printf '  FAIL %-58s got: %s\n' "the pass line states how many it scanned" "$out"; fails=$((fails+1))
  fi

  # THE REGISTRY MUST NOT OUTLIVE ITS READERS — the failure that produced this whole tool.
  out="$( audit 2>&1 )"; got=$?
  if [ "$got" = "0" ]; then printf '  ok   %-58s\n' "every registered marker has a live reader"
  else
    printf '  FAIL %-58s\n' "every registered marker has a live reader"
    printf '%s\n' "$out" | sed 's/^/         /' | head -6; fails=$((fails+1))
  fi

  # COULD-NOT-RUN IS EXIT 3, NEVER A PASS.
  local R2="$T/nogit"; mkdir -p "$R2"
  ( cd "$R2" && bash "$SELF_ABS" >/dev/null 2>&1 ); got=$?
  if [ "$got" = "3" ]; then printf '  ok   %-58s\n' "outside a git repo: exit 3, not a pass"
  else printf '  FAIL %-58s want 3, got %s\n' "outside a git repo: exit 3, not a pass" "$got"; fails=$((fails+1)); fi

  # ---- #212: A BIG TREE WITH BINARIES, FROM A BASH PARENT ------------------------------
  #
  # THE FIXTURE IS THE ADOPTER'S SHAPE, because that is the shape that found it: a repository
  # whose tracked tree is mostly assets. 800 files with 200 binary blobs, run through
  # `/bin/bash -c` — the launch path that segfaulted, since `bash <script>` directly exited 0
  # and only the `#!/usr/bin/env bash` shebang from a bash parent died.
  #
  # ASSERTS THE EXIT CODE AND THE OUTPUT, not just the exit code. A crash produces rc=139 AND
  # an empty body; a run that scans nothing produces rc=0 and a count of 0. Checking only the
  # code would pass a scanner that had silently stopped finding anything.
  local B="$T/big" i
  rm -rf "$B"; mkdir -p "$B/tools" "$B/assets"
  ( cd "$B" && git init -q . && git config user.email a@b.c && git config user.name t )
  printf '# S\n\n<!-- scaffold:must-run tests/x.sh -->\n' > "$B/AGENTS.md"
  i=0
  while [ "$i" -lt 600 ]; do printf 'text %d\n' "$i" > "$B/assets/f$i.txt"; i=$((i + 1)); done
  i=0
  while [ "$i" -lt 200 ]; do
    printf 'BIN\000\001\002 %d \377\376\n' "$i" > "$B/assets/b$i.bin"
    i=$((i + 1))
  done
  ( cd "$B" && git add -A >/dev/null 2>&1 )
  out="$( cd "$B" && /bin/bash -c "bash '$SELF_ABS'" 2>&1 )"; got=$?
  if [ "$got" -gt 128 ]; then
    printf '  FAIL %-58s died on signal %s (#212)\n' \
      "800 files incl. 200 binaries, from a bash parent" "$((got - 128))"
    fails=$((fails + 1))
  elif [ "$got" = "0" ] && printf '%s' "$out" | grep -q "1 marker declaration"; then
    printf '  ok   %-58s\n' "800 files incl. 200 binaries, from a bash parent"
  else
    printf '  FAIL %-58s exit %s: %s\n' \
      "800 files incl. 200 binaries, from a bash parent" "$got" "$(printf '%s' "$out" | head -1)"
    fails=$((fails + 1))
  fi

  # AND THE BINARIES ARE NOT READ. A marker cannot appear in one, so grepping ~700 blobs was
  # wasted work independent of the crash — and a marker-shaped byte sequence inside an asset
  # must not be reported as a declaration.
  printf '<!-- scaffold:not-a-real-marker -->\000\001binary\n' > "$B/assets/trap.bin"
  ( cd "$B" && git add -A >/dev/null 2>&1 )
  out="$( cd "$B" && bash "$SELF_ABS" 2>&1 )"; got=$?
  if [ "$got" = "0" ] && ! printf '%s' "$out" | grep -q "not-a-real-marker"; then
    printf '  ok   %-58s\n' "a marker-shaped byte run inside a binary is not a declaration"
  else
    printf '  FAIL %-58s %s\n' "a marker-shaped byte run inside a binary is not a declaration" \
      "$(printf '%s' "$out" | head -2 | tr '\n' ' ')"
    fails=$((fails + 1))
  fi
  rm -rf "$B"

  rm -rf "$T"
  echo ""
  if [ "$fails" -eq 0 ]; then echo "  all checks passed"; return 0; fi
  echo "  $fails failed"; return 1
}

case "${1:-}" in
  --selftest) selftest ;;
  --audit)    audit ;;
  "")         scan ;;
  *) echo "usage: marker_scan.sh [--selftest|--audit]" >&2; exit 2 ;;
esac
