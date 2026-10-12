#!/usr/bin/env bash
# Project:  ai-project-scaffold
# File:     tools/fixture_guard.sh
# Modified: 2026-09-23
# Version:  0.1.0.20260923.0941
# Purpose:  Make every git fixture provably disposable: validated root, clean env, a git that refuses the live repo.
# Changelog:
#   2026-09-23 v0.1.0.20260923.0941 — New. header_check's selftest ran `TD="$(mktemp -d)"`
#                        unchecked. Under a Claude Code sandbox mktemp failed, `cd ""` was a
#                        no-op, and the fixture ran git init/add/commit in the REAL repo. It
#                        committed tools/thing.sh into Robiton/control, and a push published it.
#                        Guarding each mktemp closes one door. This closes the class: a fixture
#                        root that is validated before use, an env with nothing inherited, and a
#                        `git` on PATH that refuses every write outside that root. A `mktemp`
#                        on PATH fails unless its path exists inside the root. A seeded run
#                        showed why: a tool's own `|| exit` misses a mktemp that exits 0 with an
#                        empty path, and the fixture's plain file writes then land in the live
#                        tree, where the git wrapper never sees them. Acceptance criteria from
#                        the external reviewer, relayed by CONTROL.
#
# USE (in a tool, before any fixture):
#   . "$(dirname "${BASH_SOURCE[0]}")/fixture_guard.sh" || { echo "<tool>: fixture_guard.sh missing" >&2; exit 1; }
#   fixture_root T        # T is now a validated, empty, disposable directory
#   (fixture_root --keep-gh-token T keeps GH_TOKEN/GITHUB_TOKEN for `gh api` reads only)
#   trap 'rm -rf "$T"; fg_cleanup' EXIT
#
# WHAT fixture_root GUARANTEES, or it exits 1 before anything is written:
#   1. mktemp succeeded, explicitly (`||`, not only set -e);
#   2. the path is non-empty, exists, is a directory, and is not / or $HOME;
#   3. it is not inside the live repo, and not inside ANY git repository;
#   5. inherited GIT_DIR, GIT_WORK_TREE, GIT_INDEX_FILE, GIT_CONFIG* and friends are unset;
#      global config is a fixture-owned file, system config is off;
#   6. no push credential is in scope: GH/GitHub tokens, askpass and the SSH agent are unset,
#      and the credential helpers came from the configs that are now off;
#   7. nothing is removed on a failed validation: the caller's trap is set only after return.
#   And for 4 (and 3 again, at every write): later mktemp calls land inside the root
#   (TMPDIR moves there), and PATH puts a `git` first that runs every mutating subcommand
#   only after checking where it will write. Its git dir must be inside the root and must
#   not be the live repo. A push must go to a local path inside the root. Anything else
#   exits 97 and is recorded in $FG_BASE/refused. A `mktemp` on PATH does the same for any
#   path that is empty, missing or outside the root, so a tool's own `|| exit` fires. Child
#   processes inherit PATH, so this holds for a tool that runs a copy of itself.
#
# Exit codes: fixture_root exits 1 on any failed check. The wrapper exits 97 on a refusal.
# --selftest: 0 all cases pass, 1 a case failed.

fg_die() { echo "fixture_guard: $1 — stopping before any fixture is written" >&2; exit 1; }

# The real directory of an existing path, or of its nearest existing ancestor plus the rest.
fg_real() {
  local p="$1" rest=""
  case "$p" in /*) ;; *) p="$PWD/$p" ;; esac
  while [ ! -d "$p" ]; do rest="/$(basename "$p")$rest"; p="$(dirname "$p")"; done
  printf '%s%s\n' "$(cd "$p" && pwd -P)" "$rest"
}

fixture_root() {  # fixture_root [--keep-gh-token] <varname>
  local _keep_gh=0
  if [ "${1:-}" = "--keep-gh-token" ]; then _keep_gh=1; shift; fi
  [ -n "${1:-}" ] || fg_die "fixture_root needs a variable name"
  local _gitbin _mkbin _d _base _l _live="" _src _ghk="" _gtk=""
  _gitbin="$(command -v git)" || fg_die "no git on PATH"
  _mkbin="$(command -v mktemp)" || fg_die "no mktemp on PATH"

  # THE LIVE REPOS, recorded BEFORE the env is cleaned: the one this tool lives in, the one
  # the caller stands in, and whatever an inherited GIT_DIR points at.
  _src="$(cd "$(dirname "${BASH_SOURCE[1]:-$0}")" 2>/dev/null && pwd -P)"
  for _l in \
      "$(git -C "${_src:-/nonexistent}" rev-parse --absolute-git-dir 2>/dev/null)" \
      "$(git rev-parse --absolute-git-dir 2>/dev/null)" \
      "$(env -u GIT_DIR -u GIT_WORK_TREE git -C "${_src:-/nonexistent}" rev-parse --absolute-git-dir 2>/dev/null)" \
      "$(env -u GIT_DIR -u GIT_WORK_TREE git rev-parse --absolute-git-dir 2>/dev/null)"; do
    [ -n "$_l" ] || continue
    _live="$_live$(fg_real "$_l")
$(fg_real "$(dirname "$_l")")
"
  done

  # 1. mktemp, explicitly checked.
  _base="$(mktemp -d "${TMPDIR:-/tmp}/fixture_guard.XXXXXX")" || fg_die "mktemp failed"
  # 2. non-empty, a real directory, not a root-like path.
  [ -n "$_base" ] || fg_die "mktemp returned an empty path"
  [ -d "$_base" ] || fg_die "mktemp returned [$_base], which is not a directory"
  _base="$(cd "$_base" && pwd -P)" || fg_die "cannot enter [$_base]"
  case "$_base" in /|"$(cd ~ 2>/dev/null && pwd -P)") fg_die "unexpected fixture path [$_base]" ;; esac
  # 3. not inside the live repo, not inside any repository at all.
  while IFS= read -r _l; do
    [ -n "$_l" ] || continue
    case "$_base/" in "$_l"/*) fg_die "fixture path [$_base] is inside the live repo [$_l]" ;; esac
  done <<EOF
$_live
EOF
  if env -u GIT_DIR -u GIT_WORK_TREE git -C "$_base" rev-parse --git-dir >/dev/null 2>&1; then
    fg_die "fixture path [$_base] is inside a git repository"
  fi
  [ -z "$(ls -A "$_base" 2>/dev/null)" ] || fg_die "fixture path [$_base] is not empty"

  # 5 and 6. Nothing inherited. --keep-gh-token keeps GH_TOKEN/GITHUB_TOKEN for `gh api`
  # READS (context_survival fetches a release tarball that way in adopter CI). git cannot use
  # them: its credential helpers came from the global and system configs, which are off, and
  # the wrapper still refuses every push that leaves the root.
  if [ "$_keep_gh" -eq 1 ]; then _ghk="${GH_TOKEN:-}"; _gtk="${GITHUB_TOKEN:-}"; fi
  unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES \
        GIT_COMMON_DIR GIT_NAMESPACE GIT_CONFIG GIT_CONFIG_PARAMETERS GIT_CONFIG_COUNT \
        GIT_CONFIG_SYSTEM GIT_CEILING_DIRECTORIES GIT_DISCOVERY_ACROSS_FILESYSTEM \
        GH_TOKEN GITHUB_TOKEN GH_ENTERPRISE_TOKEN GITHUB_ENTERPRISE_TOKEN \
        GIT_ASKPASS SSH_ASKPASS SSH_AUTH_SOCK GIT_SSH GIT_SSH_COMMAND
  [ -n "$_ghk" ] && export GH_TOKEN="$_ghk"
  [ -n "$_gtk" ] && export GITHUB_TOKEN="$_gtk"
  local _v
  for _v in $(env | sed -nE 's/^(GIT_CONFIG_(KEY|VALUE)_[0-9]+)=.*/\1/p'); do unset "$_v"; done
  mkdir -p "$_base/bin" "$_base/tmp" "$_base/root" || fg_die "cannot lay out [$_base]"
  printf '[user]\n\tname = fixture\n\temail = fixture@example.invalid\n[init]\n\tdefaultBranch = main\n[commit]\n\tgpgsign = false\n[tag]\n\tgpgsign = false\n' \
    > "$_base/gitconfig" || fg_die "cannot write the fixture git config"
  export GIT_CONFIG_GLOBAL="$_base/gitconfig" GIT_CONFIG_NOSYSTEM=1 GIT_TERMINAL_PROMPT=0

  # 4. The wrapper. Written with printf, not a heredoc inside $( ), for bash 3.2.
  fg_write_wrapper "$_base/bin/git" "$_gitbin" "$_base" "$_live" || fg_die "cannot write the git wrapper"
  # 2 and 4 AGAIN, AT EVERY LATER mktemp. A tool's own `|| exit` catches a mktemp that FAILS,
  # not one that exits 0 with an empty or missing path: `cd ""` is a no-op, and the fixture's
  # plain file writes (no git involved, so the wrapper above never sees them) land in the caller's
  # directory. Measured with a seeded mktemp: header_check wrote tools/thing.sh into the clone.
  # This mktemp exits non-zero unless the path exists inside the root, so every `||` fires.
  fg_write_mktemp "$_base/bin/mktemp" "$_mkbin" "$_base" || fg_die "cannot write the mktemp wrapper"
  export PATH="$_base/bin:$PATH" TMPDIR="$_base/tmp" FG_BASE="$_base"

  printf -v "$1" '%s' "$_base/root"
}

fg_cleanup() {  # removes FG_BASE only when it is what fixture_root made
  case "${FG_BASE:-}" in ""|/) return 0 ;; esac
  [ -f "$FG_BASE/gitconfig" ] && [ -d "$FG_BASE/bin" ] && rm -rf "$FG_BASE"
  return 0
}

fg_write_mktemp() {  # <dest> <real mktemp> <base>
  {
    printf '#!/usr/bin/env bash\n'
    printf '# fixture_guard mktemp wrapper: a path that is not a real entry inside %s is a failure\n' "$3"
    printf 'REAL=%q\nBASE=%q\n' "$2" "$3"
    cat <<'WRAP'
refuse() {
  echo "fixture_guard: REFUSED mktemp — $1" >&2
  printf 'mktemp\t%s\t%s\n' "$PWD" "$1" >> "$BASE/refused"
  exit 97
}
out="$("$REAL" "$@")" || refuse "the real mktemp failed"
for a in "$@"; do case "$a" in -u|--dry-run) printf '%s\n' "$out"; exit 0 ;; esac; done
[ -n "$out" ] || refuse "it returned an empty path"
[ -e "$out" ] || refuse "it returned [$out], which does not exist"
real="$(cd "$(dirname "$out")" 2>/dev/null && pwd -P)/$(basename "$out")"
case "$real" in "$BASE"/*) ;; *) refuse "it returned [$out], outside the fixture root [$BASE]" ;; esac
printf '%s\n' "$out"
WRAP
  } > "$1" && chmod +x "$1"
}

fg_write_wrapper() {  # <dest> <real git> <base> <live list>
  {
    printf '#!/usr/bin/env bash\n'
    printf '# fixture_guard git wrapper: refuses any write outside %s\n' "$3"
    printf 'REAL=%q\nBASE=%q\nLIVE=%q\n' "$2" "$3" "$4"
    cat <<'WRAP'
real_dir() {
  local p="$1" rest=""
  case "$p" in /*) ;; *) p="$PWD/$p" ;; esac
  while [ ! -d "$p" ]; do rest="/$(basename "$p")$rest"; p="$(dirname "$p")"; done
  printf '%s%s\n' "$(cd "$p" && pwd -P)" "$rest"
}
refuse() {
  echo "fixture_guard: REFUSED git $SUB — $1" >&2
  printf '%s\t%s\t%s\n' "$SUB" "$PWD" "$1" >> "$BASE/refused"
  exit 97
}
inside() {  # inside <real path>: under BASE and not a live repo
  local l
  case "$1/" in "$BASE"/*) ;; *) return 1 ;; esac
  while IFS= read -r l; do
    [ -n "$l" ] || continue
    [ "$1" = "$l" ] && return 1
  done <<EOF
$LIVE
EOF
  return 0
}
PRE=(); CDIR="$PWD"; i=1; n=$#
args=("$@")
while [ $i -le $n ]; do
  a="${args[$((i-1))]}"
  case "$a" in
    -C) b="${args[$i]}"; case "$b" in /*) CDIR="$b" ;; *) CDIR="$CDIR/$b" ;; esac
        PRE+=(-C "$b"); i=$((i+2)) ;;
    -c|--git-dir|--work-tree|--namespace|--exec-path) PRE+=("$a" "${args[$i]}"); i=$((i+2)) ;;
    -*) PRE+=("$a"); i=$((i+1)) ;;
    *) break ;;
  esac
done
SUB="${args[$((i-1))]:-}"
REST=("${args[@]:$i}")
has() { local x; for x in "${REST[@]}"; do [ "$x" = "$1" ] && return 0; done; return 1; }
case "$SUB" in
  ""|rev-parse|status|log|show|diff|diff-tree|diff-files|diff-index|ls-files|ls-tree|ls-remote|\
  cat-file|for-each-ref|show-ref|grep|describe|merge-base|rev-list|version|help|var|\
  check-ignore|check-attr|check-ref-format|name-rev|blame|annotate|shortlog|count-objects|\
  cherry|range-diff|whatchanged|verify-commit|verify-tag|fsck|column|hash-object|archive|\
  get-tar-commit-id|mailinfo|stripspace|interpret-trailers|patch-id|format-patch)
    [ "$SUB" = hash-object ] && has -w || exec "$REAL" "$@" ;;
esac
if [ "$SUB" = config ]; then
  for x in "${REST[@]}"; do case "$x" in --get|--get-all|--get-regexp|--list|-l|get|list|--show-origin|--show-scope|--global) exec "$REAL" "$@" ;; esac; done
fi
if [ "$SUB" = branch ] || [ "$SUB" = tag ]; then
  # LIST MODE, DECIDED BY THE WHOLE ARGUMENT LIST. The first version looked only at the first
  # argument, which refused `tag --sort=-v:refname` (a read scaffold_upgrade runs) and waved
  # through `tag -a v1 -m x` because `-a` means --all to branch. A write option anywhere is a
  # write; otherwise a positional name is a write unless --list/-l makes it a pattern.
  _pos=0 _lst=0 _val=0
  for x in "${REST[@]}"; do
    if [ $_val = 1 ]; then _val=0; continue; fi
    case "$SUB:$x" in
      *:-l|*:--list|branch:--show-current) _lst=1 ;;
      *:-d|*:-D|*:--delete|*:-f|*:--force|*:-m|*:-M|*:-c|*:-C|*:--move|*:--copy|*:-F|*:--file|*:--file=*|\
      *:-e|*:--edit|*:--message|*:--message=*|*:-m?*|*:--cleanup*|\
      branch:-u|branch:--set-upstream-to*|branch:--unset-upstream|branch:--edit-description|\
      branch:-t|branch:--track*|branch:--no-track|branch:--recurse-submodules|branch:--create-reflog|\
      tag:-a|tag:--annotate|tag:-s|tag:--sign|tag:-u|tag:--local-user*|tag:--create-reflog|tag:--trailer*)
        _pos=99; break ;;
      *:--contains|*:--no-contains|*:--merged|*:--no-merged|*:--points-at|*:--sort|*:--format|*:--color) _val=1 ;;
      *:-*) ;;
      *) _pos=$((_pos+1)) ;;
    esac
  done
  if [ $_pos -eq 0 ] || { [ $_lst = 1 ] && [ $_pos -lt 99 ]; }; then exec "$REAL" "$@"; fi
fi
if [ "$SUB" = remote ] || [ "$SUB" = stash ] || [ "$SUB" = worktree ]; then
  # read-only forms
  if [ ${#REST[@]} -eq 0 ]; then exec "$REAL" "$@"; fi
  case "${REST[0]}" in --show-current|--list|-l|-v|-vv|-a|-r|--contains|--merged|--no-merged|--points-at|get-url|show|list) exec "$REAL" "$@" ;; esac
fi
if [ "$SUB" = symbolic-ref ] && [ ${#REST[@]} -le 1 ]; then exec "$REAL" "$@"; fi

# A WRITE. Where will it land? An env GIT_DIR or GIT_WORK_TREE overrides every path argument,
# so it is checked first: fixture_root unset them, and anything that set one since is suspect.
for ev in "${GIT_DIR:-}" "${GIT_WORK_TREE:-}"; do
  [ -n "$ev" ] || continue
  case "$ev" in /*) ;; *) ev="$CDIR/$ev" ;; esac
  inside "$(real_dir "$ev")" || refuse "GIT_DIR/GIT_WORK_TREE [$ev] is outside the fixture root [$BASE]"
done
if [ "$SUB" = init ] || [ "$SUB" = clone ]; then
  pos=()
  skip=0
  for x in "${REST[@]}"; do
    if [ $skip -eq 1 ]; then skip=0; continue; fi
    case "$x" in
      -b|--initial-branch|--template|--separate-git-dir|-o|--origin|--depth|--reference|--branch|-c|--config|--object-format|--shared) skip=1 ;;
      -*) ;;
      *) pos+=("$x") ;;
    esac
  done
  if [ "$SUB" = init ]; then t="${pos[0]:-.}"; else
    if [ ${#pos[@]} -ge 2 ]; then t="${pos[1]}"; else t="$(basename "${pos[0]:-x}" .git)"; fi
  fi
  case "$t" in /*) ;; *) t="$CDIR/$t" ;; esac
  rt="$(real_dir "$t")"
  inside "$rt" || refuse "target [$rt] is outside the fixture root [$BASE]"
  exec "$REAL" "$@"
fi
gd="$("$REAL" "${PRE[@]}" rev-parse --absolute-git-dir 2>/dev/null)" || gd=""
if [ -n "$gd" ]; then
  rg="$(real_dir "$gd")"
  inside "$rg" || refuse "its git dir [$rg] is outside the fixture root [$BASE]"
fi
if [ "$SUB" = push ]; then
  urls=""
  r=""
  for x in "${REST[@]}"; do case "$x" in -*) ;; *) r="$x"; break ;; esac; done
  if [ -n "$r" ] && ! "$REAL" "${PRE[@]}" remote get-url --push "$r" >/dev/null 2>&1; then
    urls="$r"
  elif [ -n "$r" ]; then
    urls="$("$REAL" "${PRE[@]}" remote get-url --push "$r" 2>/dev/null)"
  else
    for rm_ in $("$REAL" "${PRE[@]}" remote 2>/dev/null); do
      urls="$urls
$("$REAL" "${PRE[@]}" remote get-url --push "$rm_" 2>/dev/null)"
    done
  fi
  while IFS= read -r u; do
    [ -n "$u" ] || continue
    case "$u" in *://*|*@*:*) refuse "push to a non-local remote [$u]" ;; esac
    case "$u" in /*) ;; *) u="$CDIR/$u" ;; esac
    inside "$(real_dir "$u")" || refuse "push to [$u], outside the fixture root"
  done <<EOF
$urls
EOF
fi
exec "$REAL" "$@"
WRAP
  } > "$1" && chmod +x "$1"
}

# ---- selftest -----------------------------------------------------------------------------
fg_selftest() (
  # A SUBSHELL, so the env changes stay here. Every case runs against a throwaway "live"
  # repo made by the real git, so a failure here cannot touch the repo this file lives in.
  PASS=0; FAIL=0
  ok()  { PASS=$((PASS+1)); echo "  ok    $1"; }
  bad() { FAIL=$((FAIL+1)); echo "  FAIL  $1"; }
  here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
  # THIS SELFTEST IS A FIXTURE TOO, and cannot use fixture_root: it builds the "live" repo
  # that fixture_root is tested against. So it takes the same front door by hand. Measured
  # with a seeded mktemp returning a path inside the caller's repo, plus an inherited GIT_DIR:
  # the setup below ran `git init` and `remote add` into the caller's .git.
  unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES \
        GIT_COMMON_DIR GIT_NAMESPACE GIT_CONFIG GIT_CONFIG_PARAMETERS GIT_CONFIG_COUNT
  export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 GIT_TERMINAL_PROMPT=0
  scratch="$(mktemp -d "${TMPDIR:-/tmp}/fixture_guard.XXXXXX")" || { echo "fixture_guard: mktemp failed" >&2; exit 1; }
  { [ -n "$scratch" ] && [ -d "$scratch" ]; } || { echo "fixture_guard: mktemp returned [$scratch], not a directory" >&2; exit 1; }
  scratch="$(cd "$scratch" && pwd -P)" || exit 1
  if git -C "$scratch" rev-parse --git-dir >/dev/null 2>&1 || [ -n "$(ls -A "$scratch")" ]; then
    echo "fixture_guard: selftest scratch [$scratch] is inside a git repository or not empty; stopping" >&2; exit 1
  fi
  trap 'rm -rf "$scratch"' EXIT
  live="$scratch/live"; mkdir -p "$live/tools" "$scratch/bare.git"
  cp "$here/fixture_guard.sh" "$live/tools/"
  ( cd "$live" && git init -q . && git -c user.email=a@b -c user.name=a commit -q --allow-empty -m live )
  git init -q --bare "$scratch/bare.git"
  ( cd "$live" && git remote add origin "$scratch/bare.git" && git remote add prod https://github.com/example/prod.git )
  snap() { ( cd "$live" && git rev-parse HEAD && git for-each-ref && git status --porcelain && cat .git/config ) | shasum; }
  before="$(snap)"

  run() {  # run <env-prefix...> -- <script>: a child that sources the guard from the live copy
    ( cd "$live" && env "$@" bash -c '. tools/fixture_guard.sh && '"$SCRIPT" ) >"$scratch/out" 2>&1
  }
  fb="$scratch/fakebin"; mkdir -p "$fb"
  mk() { printf '#!/bin/sh\n%s\n' "$1" > "$fb/mktemp"; chmod +x "$fb/mktemp"; }

  # A. baseline: a fixture commits inside its root, and the live repo is untouched.
  SCRIPT='fixture_root T && cd "$T" && git init -q . && echo x > f && git add f && git commit -qm t && echo DONE'
  run PATH="$PATH"; rc=$?
  if [ $rc -eq 0 ] && grep -q DONE "$scratch/out"; then ok "baseline: a fixture commits inside its root"; else bad "baseline failed rc=$rc: $(tail -2 "$scratch/out")"; fi
  [ "$(snap)" = "$before" ] && ok "baseline left the live repo byte-identical" || bad "baseline changed the live repo"

  SCRIPT='fixture_root T && cd "$T" && git init -q . && echo MUTATED'
  # B. each seeded fault aborts before mutation.
  #    EACH SEED NAMES ITS OWN CHECK. Without the expected message, one check (say "not
  #    empty") could stand in for another and every seed would still read as caught.
  mkdir -p "$live/e" "$scratch/other/e"; git init -q "$scratch/other"
  : > "$scratch/full-marker"; mkdir -p "$scratch/full"; : > "$scratch/full/x"
  for seed in fail empty missing live other full; do
    case "$seed" in
      fail)    mk 'exit 1';                              want='mktemp failed' ;;
      empty)   mk 'exit 0';                              want='empty path' ;;
      missing) mk 'echo /nonexistent/fg-missing; exit 0'; want='which is not a directory' ;;
      live)    mk "echo $live/e; exit 0";                want='inside the live repo' ;;
      other)   mk "echo $scratch/other/e; exit 0";       want='inside a git repository' ;;
      full)    mk "echo $scratch/full; exit 0";          want='is not empty' ;;
    esac
    run PATH="$fb:$PATH"; rc=$?
    if [ $rc -ne 0 ] && ! grep -q MUTATED "$scratch/out" && grep -q "$want" "$scratch/out" \
       && [ "$(snap)" = "$before" ]; then
      ok "seeded [$seed]: aborted before mutation on '$want', live repo byte-identical"
    else
      bad "seeded [$seed]: rc=$rc, wanted '$want', got [$(tail -1 "$scratch/out")]"
    fi
  done
  rm -f "$fb/mktemp"

  # B2. a LATER mktemp (the tool's own) that exits 0 with a bad path is turned into a failure,
  #     so the tool's `|| exit` fires. The first call (fixture_root's) is real.
  _realmk="$(command -v mktemp)"
  for seed in empty missing outside; do
    case "$seed" in
      empty)   body='exit 0';                               want='empty path' ;;
      missing) body='echo /nonexistent/fg-later; exit 0';   want='does not exist' ;;
      outside) body="mkdir -p $scratch/out-dir; echo $scratch/out-dir; exit 0"; want='outside the fixture root' ;;
    esac
    printf '#!/bin/sh\nC=%s/mkcount; n=$(cat "$C" 2>/dev/null || echo 0); echo $((n+1)) > "$C"\n[ "$n" -eq 0 ] && exec %s "$@"\n%s\n' \
      "$scratch" "$_realmk" "$body" > "$fb/mktemp"; chmod +x "$fb/mktemp"; rm -f "$scratch/mkcount"
    SCRIPT='fixture_root T && { D="$(mktemp -d "$TMPDIR/t.XXXXXX")" || { echo CAUGHT; exit 1; }; cd "$D"; echo x > thing.sh; echo MUTATED; }'
    run PATH="$fb:$PATH"
    if grep -q CAUGHT "$scratch/out" && ! grep -q MUTATED "$scratch/out" && grep -q "$want" "$scratch/out" \
       && [ ! -e "$live/thing.sh" ] && [ "$(snap)" = "$before" ]; then
      ok "a later mktemp returning [$seed] fails, so the tool's own || fires before any write"
    else
      bad "a later mktemp returning [$seed] was accepted: $(tail -1 "$scratch/out")"; rm -f "$live/thing.sh"
    fi
  done
  SCRIPT='fixture_root T && D="$(mktemp -d "$TMPDIR/t.XXXXXX")" && [ -d "$D" ] && echo INSIDE'
  run PATH="$PATH"
  grep -q INSIDE "$scratch/out" && ok "a real mktemp inside the root passes the wrapper" || bad "a good mktemp was refused: $(tail -1 "$scratch/out")"
  rm -f "$fb/mktemp"

  # C. an inherited GIT_DIR pointing at the live repo is neutralised, not obeyed.
  SCRIPT='fixture_root T && cd "$T" && git init -q . && echo x > f && git add f && git commit -qm t && echo DONE'
  run PATH="$PATH" GIT_DIR="$live/.git" GIT_WORK_TREE="$live"; rc=$?
  #    NEUTRALISED MEANS BOTH: the live repo is untouched AND the fixture still works. The
  #    wrapper alone would keep the live repo safe by refusing, and hide a missing unset.
  if [ "$(snap)" = "$before" ] && grep -q DONE "$scratch/out"; then
    ok "an inherited GIT_DIR at the live repo is neutralised (fixture ran, live untouched)"
  else
    bad "an inherited GIT_DIR was not neutralised: rc=$rc, $(tail -1 "$scratch/out")"
  fi

  # C2. ...and one set AFTER fixture_root is refused by the wrapper itself.
  SCRIPT='fixture_root T && cd "$T" && GIT_DIR='"$live"'/.git git commit -q --allow-empty -m t; echo rc=$?'
  run PATH="$PATH"
  grep -q 'rc=97' "$scratch/out" && [ "$(snap)" = "$before" ] && ok "a GIT_DIR set after fixture_root is refused by the wrapper" \
    || bad "a later GIT_DIR at the live repo was obeyed: $(tail -1 "$scratch/out")"

  # D. a failed cd leaves the fixture standing in the live repo; the wrapper refuses the write.
  SCRIPT='fixture_root T && cd "$T/no/such/dir"; echo x > f; git add f; git commit -qm t; echo rc=$?'
  run PATH="$PATH"; rc=$?
  ( cd "$live" && rm -f f )
  if grep -q 'REFUSED git add' "$scratch/out" && grep -q 'rc=97' "$scratch/out" && [ "$(snap)" = "$before" ]; then
    ok "a failed cd: the wrapper refuses git add/commit in the live repo"
  else
    bad "a failed cd was not caught: $(grep -m2 -E 'REFUSED|rc=' "$scratch/out" | tr '\n' ' ')"
  fi

  # E. a push to a production remote is refused; a push inside the root is allowed.
  SCRIPT='fixture_root T && cd "$T" && git init -q . && git commit -q --allow-empty -m t && git remote add prod https://github.com/example/prod.git && git push -q prod HEAD:main; echo rc=$?'
  run PATH="$PATH"
  grep -q 'rc=97' "$scratch/out" && ok "a push to a production URL is refused" || bad "a production push was not refused: $(tail -1 "$scratch/out")"
  SCRIPT='fixture_root T && git init -q --bare "$T/b.git" && cd "$T" && mkdir w && cd w && git init -q . && git commit -q --allow-empty -m t && git push -q "$T/b.git" HEAD:main; echo rc=$?'
  run PATH="$PATH"
  grep -q 'rc=0' "$scratch/out" && ok "a push to a bare repo inside the root is allowed" || bad "an in-root push was refused: $(tail -2 "$scratch/out" | tr '\n' ' ')"

  # F. reads of the live repo still work (tools compare against it).
  SCRIPT='fixture_root T && git -C '"$live"' rev-parse HEAD >/dev/null && git -C '"$live"' log -1 --format=%s'
  run PATH="$PATH"
  grep -q '^live$' "$scratch/out" && ok "reads of the live repo pass through" || bad "a read of the live repo was blocked: $(tail -1 "$scratch/out")"

  # F2. branch/tag LIST forms pass, WRITE forms are refused — decided by every argument.
  #     `tag --sort=...` was refused (scaffold_upgrade's read) and `tag -a` was let through.
  SCRIPT='fixture_root T; L='"$live"'
    for c in "tag --sort=-v:refname" "tag -n" "tag -l v*" "branch -a" "branch --contains HEAD" "branch --format=%(refname) --sort=-committerdate"; do
      git -C "$L" $c >/dev/null 2>&1; echo "R $? $c"; done
    for c in "tag -a v1 -m x" "tag v2" "tag -d v1" "tag -f v3 HEAD" "branch nb" "branch -D main" "branch -m nb2" "branch -l -d main" "tag --list -d v1" "tag -a -l v1"; do
      git -C "$L" $c >/dev/null 2>&1; echo "W $? $c"; done'
  run PATH="$PATH"
  _rb="$(grep -E '^R ' "$scratch/out" | grep -v '^R 0 ')"; _wb="$(grep -E '^W ' "$scratch/out" | grep -v '^W 97 ')"
  [ "$(grep -c '^R 0 ' "$scratch/out")" -eq 6 ] && [ -z "$_rb" ] && ok "branch/tag list forms of the live repo pass through" \
    || bad "a branch/tag list form was blocked: $(printf '%s' "$_rb" | head -2 | tr '\n' ' ')"
  [ "$(grep -c '^W 97 ' "$scratch/out")" -eq 10 ] && [ -z "$_wb" ] && [ "$(snap)" = "$before" ] \
    && ok "branch/tag write forms against the live repo are refused, live byte-identical" \
    || bad "a branch/tag write reached the live repo: $(printf '%s' "$_wb" | head -2 | tr '\n' ' ')"

  # G. no credential survives.
  SCRIPT='fixture_root T && echo "[${GH_TOKEN:-}${GITHUB_TOKEN:-}${SSH_AUTH_SOCK:-}${GIT_ASKPASS:-}]" && git config --global --get user.name'
  run PATH="$PATH" GH_TOKEN=x GITHUB_TOKEN=y SSH_AUTH_SOCK=/tmp/s GIT_ASKPASS=/bin/echo
  grep -q '^\[\]$' "$scratch/out" && grep -q '^fixture$' "$scratch/out" && ok "tokens, agent and askpass are unset; global config is the fixture file" \
    || bad "credentials survived: $(head -2 "$scratch/out" | tr '\n' ' ')"

  # G2. --keep-gh-token keeps the API token and nothing else.
  SCRIPT='fixture_root --keep-gh-token T && echo "[${GH_TOKEN:-}|${SSH_AUTH_SOCK:-}|${GIT_ASKPASS:-}]"'
  run PATH="$PATH" GH_TOKEN=x SSH_AUTH_SOCK=/tmp/s GIT_ASKPASS=/bin/echo
  grep -q '^\[x||\]$' "$scratch/out" && ok "--keep-gh-token keeps GH_TOKEN only" || bad "--keep-gh-token: $(head -1 "$scratch/out")"

  # H. nothing reached the bare remote the live repo points at.
  [ -z "$(git -C "$scratch/bare.git" for-each-ref)" ] && ok "no push reached the live repo's remote" || bad "something was pushed to the live remote"

  echo "  $PASS passed, $FAIL failed"
  [ "$FAIL" -eq 0 ]
)

# Run directly: selftest. Sourced: only the functions above are defined.
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  case "${1:---selftest}" in
    --selftest) echo "fixture_guard.sh --selftest"; fg_selftest ;;
    *) echo "usage: fixture_guard.sh [--selftest]   (source it to use fixture_root)" >&2; exit 2 ;;
  esac
fi
