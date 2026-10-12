#!/usr/bin/env bash
# Project:  ai-project-scaffold
# File:     tools/skills_check.sh
# Modified: 2026-09-23
# Version:  0.6.2.20260923.0941
# Purpose:  Compare the canonical skills tree against the Claude Code mirror, and say
#           what actually drifted and which direction the fix runs.
# Changelog:
#   2026-09-23 v0.6.2.20260923.0941 — mktemp takes a ${TMPDIR} template. macOS mktemp ignores TMPDIR without one, so a guarded fixture root could not contain it.
#   2026-09-23 v0.6.1.20260923.0843 — every mktemp fails closed. A failed one left the temp variable empty, so the fixture ran in the caller's directory; header_check's committed into Robiton/control.
#   2026-09-08 v0.6.0.20260908.0242 — IT SAYS THAT IT RAN, AND WHAT IT DID NOT MEASURE. Exiting 0
#                        in silence made a clean run indistinguishable from a run that never
#                        happened -- the [GAP]-versus-[PASS] shape this project keeps paying
#                        for. And a bare success invited the reader to hear an outcome claim
#                        the check never made: it proves two trees match and frontmatter
#                        parses, and proves NOTHING about whether a skill is selected when it
#                        should be or helps when it is.
#                        Prompted by tjboudreaux/cc-thinking-skills, whose eval harness
#                        separates structural conformance from outcome, and whose authors --
#                        having actually measured -- deleted 11 of their 39 skills and
#                        authorised no claim that the remaining 28 work. Someone else
#                        arriving independently at this project's own recurring defect.
#                        Verbose path only; --quiet and the exit code are unchanged, so
#                        setup.sh and adoption_check are untouched.
#   2026-09-07 v0.5.0.20260907.0959 — PRESENT ON DISK IS NOT PRESENT IN THE REPOSITORY.
#                        This tool compares two FILESYSTEM trees, so a mirror created
#                        locally and never committed passed here and failed everywhere
#                        else. Measured in Robiton/collectionapp: exit 0 on the authoring
#                        machine while CI's adoption gate reported `skills mirror drifted`,
#                        because nothing under .claude/ was tracked at all. The file was
#                        correct and invisible -- and the local pass is what made it look
#                        like a CI problem rather than a missing commit.
#                        Same family as the executable-bit rule this project records:
#                        assert against the INDEX, because the working tree is the one
#                        place a file is guaranteed to look right. `[ -f ]` answers 'did
#                        somebody create this'; the question is 'will anyone else get it'.
#                        ADVISORY and git-gated -- mid-authoring is legitimate and a
#                        non-checkout is not a defect. Mutation-verified both directions.
#   2026-08-23 v0.4.0 — IT VERIFIED THE COPIES MATCHED AND NEVER ASKED WHETHER THE THING BEING
#                        COPIED WAS A SKILL. Found in Robiton/localcoder 2026-08-23:
#                        delegate/SKILL.md had NO YAML frontmatter in either home -- both
#                        copies identical, both invalid, and this script called that pair
#                        clean. Claude Code documents frontmatter as required and uses
#                        `description` to decide when to load a skill AUTOMATICALLY, so a
#                        skill without one can never be auto-invoked. `/delegate` still
#                        worked from the directory name, which is why nobody noticed.
#                        The skill in question exists because "the measured failure is not
#                        that delegation goes badly, it is that it never starts". It could
#                        not start.
#                        Now checks, on the CANONICAL side only: frontmatter at line 1,
#                        a non-empty name:, a non-empty description:, and name matching the
#                        directory -- the directory is what becomes the command, so a name
#                        that disagrees is a label pointing at a different skill. Checking
#                        both homes would report every fault twice and imply they were two.
#                        Three selftest cases for it, because every other fixture here is now
#                        VALID -- without them the check never fires in the suite and could be
#                        deleted with everything still green.
#                        Also: "8 selftest case(s) passed" was a LITERAL. It stayed 8 while
#                        eleven cases ran. Counted now.
#   2026-08-06 v0.2.1 — The blank-line collapse was too broad, and the negative case could
#                        not see it. `\n{3,}` -> `\n\n` flattens whitespace inside FENCED CODE
#                        too, so a canonical skill with PEP 8 two-blank-line spacing and a
#                        mirror that had lost one compared EQUAL — real drift, silently
#                        missed, which is this tool own defect facing the other way. Case 2
#                        differs by TEXT so it passed either way. Now only the newlines
#                        adjacent to the removed block are consumed; nothing else is touched.
#   2026-08-06 v0.2.0 — Collapse the blank lines a stripped localcoder block leaves behind
#                        (#97), and add --selftest. Stripping removed the block and left
#                        the whitespace around it, so two semantically identical skills
#                        still differed and the check reported drift. The damage was in
#                        the REMEDY, not the false positive: `cp -R .agents/skills/.
#                        .claude/skills/` clears it by copying the localcoder block into
#                        the agent-facing mirror — precisely what stripping exists to
#                        prevent — and the check then goes green, so the wrong fix looks
#                        like the right one. At least one adopter has already applied it.
#                        The 7 selftest cases are the missing half: the old code passed
#                        "does it strip the block" and nothing asked "do two files
#                        differing only by a block compare equal".
#   2026-08-04 v0.1.0 — Initial creation
#
# WHY THIS EXISTS AS ITS OWN SCRIPT
#   sync-check.sh and setup.sh both had their own `diff -rq` plus their own advice, and
#   both were wrong in the same two ways. One definition, called by both — the same
#   reason tools/session_archive.py owns the archive count.
#
# TWO DEFECTS IT FIXES
#   1. A `localcoder:begin` block in a canonical SKILL.md is an INTENTIONAL divergence.
#      It is drafting guidance for a local model; localcoder reads it from .agents/, and
#      copying it into the agent-facing mirror just injects noise into a context that will
#      never act on it. The old check reported drift every single session, and its
#      suggested fix made things slightly worse. Those blocks are now stripped from both
#      sides before comparing.
#   2. `cp -R .agents/skills/. .claude/skills/` ADDS and OVERWRITES; it never removes.
#      When the mirror held adopter-authored skills the canonical side lacked — five of
#      them in one real project — the suggested command changed nothing and the warning
#      fired again next session. A warning whose fix does not work is a warning people
#      learn to ignore, and this one shares a channel with the un-distilled-journal
#      warning, which genuinely matters.
#
# Usage:
#   tools/skills_check.sh            # human-readable diagnosis; exit 1 if drifted
#   tools/skills_check.sh --quiet    # exit code only
set -u

CANON=".agents/skills"
MIRROR=".claude/skills"
QUIET=0
[ "${1:-}" = "--quiet" ] && QUIET=1

say() { [ "$QUIET" = "1" ] || printf '%s\n' "$1"; }

if [ "${1:-}" = "--selftest" ]; then
  # THE OLD IMPLEMENTATION PASSED A NAIVE TEST AND FAILED THE REAL ONE. "Does it strip
  # the block" was true and not the question; "do two skills differing ONLY by a block
  # compare equal" was the question, and nothing asked it. Case 1 below is that question,
  # and it fails on the pre-fix script.
  #
  # This script resolves CANON/MIRROR relative to $PWD, so a fixture is just a directory
  # to cd into — no repo, no git.
  SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
  TD="$(mktemp -d "${TMPDIR:-/tmp}/skills_check.XXXXXX")" || { echo "skills_check: mktemp failed; stopping" >&2; exit 1; }
  trap 'rm -rf "$TD"' EXIT
  fails=0
  # THE TOTAL WAS HARDCODED AND THE PASSES WERE NEVER COUNTED. "8 selftest case(s) passed"
  # was printed by a literal, so it stayed 8 while eleven cases ran -- a number that reads as
  # a measurement and is a constant. Adding a case did not change it; deleting three would
  # not either, which is the direction that matters.
  passes=0
  ok()  { printf '  ok    %s\n' "$1"; passes=$((passes + 1)); }
  bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails + 1)); }
  check() { # check <name> <expected-exit> <fixture-dir>
    local name="$1" want="$2" dir="$3" got
    ( cd "$dir" && "$SELF" --quiet ); got=$?
    if [ "$got" = "$want" ]; then ok "$name"; else bad "$name (exit $got, wanted $want)"; fi
  }

  echo "skills_check: selftest"

  # 1. THE REGRESSION. Identical skills; the canonical side carries a localcoder block.
  #    Stripping it left the blank lines that surrounded it, so the normalised copies
  #    differed by whitespace alone and the check reported drift. Must be clean.
  F="$TD/localcoder-block-only"
  mkdir -p "$F/.agents/skills/demo" "$F/.claude/skills/demo"
  # THE FIXTURES CARRY FRONTMATTER BECAUSE THEY MODEL A REAL SKILL. Without it the
  # validity check below fires on them, and a fixture that could not ship is the wrong
  # thing to test a drift comparison against.
  cat > "$F/.agents/skills/demo/SKILL.md" <<'CANON_MD'
---
name: demo
description: A fixture skill, so the selftest exercises a VALID skill shape.
---

# Demo

Guidance the agent reads.

<!-- localcoder:begin -->
Drafting notes only the local model should see.
<!-- localcoder:end -->

More guidance the agent reads.
CANON_MD
  cat > "$F/.claude/skills/demo/SKILL.md" <<'MIRROR_MD'
---
name: demo
description: A fixture skill, so the selftest exercises a VALID skill shape.
---

# Demo

Guidance the agent reads.

More guidance the agent reads.
MIRROR_MD
  check "a localcoder block is not drift" 0 "$F"

  # 2. NEGATIVE CASE. Collapsing whitespace must not swallow a real difference — a
  #    normaliser that reports everything equal is the same defect facing the other way.
  F="$TD/real-difference"
  mkdir -p "$F/.agents/skills/demo" "$F/.claude/skills/demo"
  printf -- '---\nname: demo\ndescription: A fixture skill, so the selftest exercises a VALID skill shape.\n---\n\n# Demo\n\nCanonical says this.\n' > "$F/.agents/skills/demo/SKILL.md"
  printf -- '---\nname: demo\ndescription: A fixture skill, so the selftest exercises a VALID skill shape.\n---\n\n# Demo\n\nThe mirror says something else.\n' > "$F/.claude/skills/demo/SKILL.md"
  check "a real content difference still fails" 1 "$F"

  # 2b. WHITESPACE INSIDE A FENCED CODE BLOCK IS NOT NOISE. Case 2 differs by TEXT, so it
  #     passes against a normaliser that flattens all blank lines — which is exactly what
  #     the first fix for case 1 did, and it hid this. PEP 8 puts two blank lines between
  #     top-level functions; a mirror that has lost one has really drifted.
  F="$TD/codeblock-whitespace"
  mkdir -p "$F/.agents/skills/demo" "$F/.claude/skills/demo"
  printf '# Demo\n\n```python\ndef a():\n    pass\n\n\ndef b():\n    pass\n```\n' \
    > "$F/.agents/skills/demo/SKILL.md"
  printf '# Demo\n\n```python\ndef a():\n    pass\n\ndef b():\n    pass\n```\n' \
    > "$F/.claude/skills/demo/SKILL.md"
  check "blank-line drift inside a code fence still fails" 1 "$F"

  # 3. Skill only in the mirror — adopter-authored; `cp -R` would not fix it.
  F="$TD/only-mirror"
  mkdir -p "$F/.agents/skills/demo" "$F/.claude/skills/demo" "$F/.claude/skills/theirs"
  printf -- '---\nname: demo\ndescription: A fixture skill, so the selftest exercises a VALID skill shape.\n---\n\n# Demo\n' > "$F/.agents/skills/demo/SKILL.md"
  printf -- '---\nname: demo\ndescription: A fixture skill, so the selftest exercises a VALID skill shape.\n---\n\n# Demo\n' > "$F/.claude/skills/demo/SKILL.md"
  printf -- '---\nname: theirs\ndescription: A fixture skill, so the selftest exercises a VALID skill shape.\n---\n\n# Theirs\n' > "$F/.claude/skills/theirs/SKILL.md"
  check "a mirror-only skill still fails" 1 "$F"

  # 4. Skill only in the canonical tree — the mirror is stale.
  F="$TD/only-canon"
  mkdir -p "$F/.agents/skills/demo" "$F/.agents/skills/fresh" "$F/.claude/skills/demo"
  printf -- '---\nname: demo\ndescription: A fixture skill, so the selftest exercises a VALID skill shape.\n---\n\n# Demo\n' > "$F/.agents/skills/demo/SKILL.md"
  printf -- '---\nname: fresh\ndescription: A fixture skill, so the selftest exercises a VALID skill shape.\n---\n\n# Fresh\n' > "$F/.agents/skills/fresh/SKILL.md"
  printf -- '---\nname: demo\ndescription: A fixture skill, so the selftest exercises a VALID skill shape.\n---\n\n# Demo\n' > "$F/.claude/skills/demo/SKILL.md"
  check "a canonical-only skill still fails" 1 "$F"

  # 5. No skills at all is legitimate, not drift.
  F="$TD/no-skills"; mkdir -p "$F"
  check "a project with no skills is clean" 0 "$F"

  # 6. Canonical tree present, mirror absent — Claude Code loads nothing.
  F="$TD/no-mirror"
  mkdir -p "$F/.agents/skills/demo"
  printf -- '---\nname: demo\ndescription: A fixture skill, so the selftest exercises a VALID skill shape.\n---\n\n# Demo\n' > "$F/.agents/skills/demo/SKILL.md"
  check "a missing mirror still fails" 1 "$F"

  # 7. A block with a language suffix (localcoder:begin:python) strips the same way.
  F="$TD/suffixed-block"
  mkdir -p "$F/.agents/skills/demo" "$F/.claude/skills/demo"
  cat > "$F/.agents/skills/demo/SKILL.md" <<'SUFFIX_MD'
---
name: demo
description: A fixture skill, so the selftest exercises a VALID skill shape.
---

# Demo

Shared guidance.

<!-- localcoder:begin:python -->
Python drafting notes.
<!-- localcoder:end -->

Trailing guidance.
SUFFIX_MD
  printf -- '---\nname: demo\ndescription: A fixture skill, so the selftest exercises a VALID skill shape.\n---\n\n# Demo\n\nShared guidance.\n\nTrailing guidance.\n' > "$F/.claude/skills/demo/SKILL.md"
  check "a suffixed localcoder block is not drift" 0 "$F"

  # 8. A MIRRORED FILE THAT IS NOT A SKILL. Both copies identical, both invalid — which is
  #    exactly what this script used to call clean, and what shipped in Robiton/localcoder.
  #    Without this case the validity check is untested: every other fixture here is valid, so
  #    the check never fires and could be deleted with the suite still green.
  F="$TD/no-frontmatter"
  mkdir -p "$F/.agents/skills/demo" "$F/.claude/skills/demo"
  printf -- '# Demo\n\nGuidance with no frontmatter at all.\n' > "$F/.agents/skills/demo/SKILL.md"
  printf -- '# Demo\n\nGuidance with no frontmatter at all.\n' > "$F/.claude/skills/demo/SKILL.md"
  check "two identical copies of an invalid skill still fail" 1 "$F"

  # 9. AND THE NAME MUST MATCH THE DIRECTORY, since the directory is what becomes the command.
  F="$TD/name-mismatch"
  mkdir -p "$F/.agents/skills/demo" "$F/.claude/skills/demo"
  printf -- '---\nname: something-else\ndescription: Valid shape, wrong name.\n---\n\n# Demo\n' \
    > "$F/.agents/skills/demo/SKILL.md"
  printf -- '---\nname: something-else\ndescription: Valid shape, wrong name.\n---\n\n# Demo\n' \
    > "$F/.claude/skills/demo/SKILL.md"
  check "a name that disagrees with its directory fails" 1 "$F"

  # 10. A DESCRIPTION IS WHAT DECIDES AUTO-INVOCATION, so its absence is not cosmetic.
  F="$TD/no-description"
  mkdir -p "$F/.agents/skills/demo" "$F/.claude/skills/demo"
  printf -- '---\nname: demo\n---\n\n# Demo\n' > "$F/.agents/skills/demo/SKILL.md"
  printf -- '---\nname: demo\n---\n\n# Demo\n' > "$F/.claude/skills/demo/SKILL.md"
  check "a skill with no description fails" 1 "$F"

  if [ "$fails" -gt 0 ]; then
    echo "skills_check: $fails selftest case(s) FAILED"
    exit 1
  fi
  echo "skills_check: $passes selftest case(s) passed"
  exit 0
fi

# Nothing to compare — a project may legitimately have no skills at all.
[ -d "$CANON" ] || exit 0

# ==== PRESENT ON DISK IS NOT THE SAME AS PRESENT IN THE REPOSITORY ========================
#
# This tool compares two trees on the FILESYSTEM, so a mirror that exists locally and was
# never committed passes here and fails everywhere else -- CI, a fresh clone, a teammate.
# Measured 2026-09-07 in Robiton/collectionapp: skills_check exited 0 on the authoring
# machine while the adoption gate in CI reported `skills mirror drifted`, because nothing
# under .claude/ was tracked at all. The file was correct and invisible.
#
# Same family as the executable-bit rule this project already records: assert against the
# INDEX, not the working tree, because the working tree is the one place the file is
# guaranteed to look right. `[ -f ]` answers "did somebody create this", and the question
# that matters is "will anyone else receive it".
#
# ADVISORY, NOT A FAILURE, and only when git is available: a project may legitimately be
# mid-authoring, and a repo that is not a git checkout is not a defect. It reports, and the
# comparison below still runs.
if command -v git >/dev/null 2>&1 && git rev-parse --git-dir >/dev/null 2>&1; then
  _untracked="$(git ls-files --others --exclude-standard -- "$MIRROR" 2>/dev/null | head -5)"
  if [ -n "$_untracked" ]; then
    say "[!]  $MIRROR/ has file(s) present on disk but NOT TRACKED by git:"
    printf '%s\n' "$_untracked" | sed 's|^|       |'
    say "     They pass this check here and fail in CI and in every fresh clone."
    say "     Fix: git add $MIRROR"
  fi
fi

if [ ! -d "$MIRROR" ]; then
  say "[!]  $MIRROR/ is missing — Claude Code reads that path, so no skill loads."
  say "     Fix: mkdir -p $MIRROR && cp -R $CANON/. $MIRROR/"
  exit 1
fi

# Normalised copies: strip localcoder:begin…end blocks so an intentional drafting
# block does not read as drift. Same marker the tool itself uses.
NORM="$(mktemp -d "${TMPDIR:-/tmp}/skills_check.XXXXXX")" || { echo "skills_check: mktemp failed; stopping" >&2; exit 1; }
trap 'rm -rf "$NORM"' EXIT
strip_blocks() {
  local src="$1" dst="$2"
  mkdir -p "$dst"
  ( cd "$src" && find . -type f -print0 ) | while IFS= read -r -d '' f; do
    mkdir -p "$dst/$(dirname "$f")"
    if [ "${f##*.}" = "md" ]; then
      python3 - "$src/$f" "$dst/$f" <<'PY'
import re, sys
src, dst = sys.argv[1], sys.argv[2]
text = open(src, encoding="utf-8", errors="replace").read()
# THE BLANK LINES AROUND THE BLOCK ARE PART OF THE BLOCK, so they come out with it —
# and ONLY they do.
#
# Removing the block alone left the whitespace that surrounded it, so two semantically
# identical skills still differed and the check reported drift; worse, its printed remedy
# resolved that by copying the localcoder block INTO the agent-facing mirror, the exact
# outcome this stripping exists to prevent.
#
# THE FIRST FIX FOR THAT WAS A BLANKET `\n{3,}` -> `\n\n`, AND IT WAS WRONG. Markdown
# treats consecutive blank lines as insignificant; a FENCED CODE BLOCK does not. PEP 8 puts
# two blank lines between top-level functions, so a canonical skill whose Python example had
# them and a mirror that had lost one normalised to the same bytes and the check reported
# IN SYNC — real drift, silently missed. That is the same defect this tool exists to catch,
# facing the other way, and the negative case written for it could not see it because it
# differed by TEXT rather than by whitespace.
#
# Consuming the newlines adjacent to the removed block touches nothing else in the file.
text = re.sub(
    r"\n*[ \t]*<!--\s*localcoder:begin(?::[a-z0-9_+#-]+)?\s*-->.*?<!--\s*localcoder:end\s*-->[ \t]*\n*",
    "\n\n", text, flags=re.S | re.I)
open(dst, "w", encoding="utf-8").write(text.strip() + "\n")
PY
    else
      cp "$src/$f" "$dst/$f"
    fi
  done
}
strip_blocks "$CANON" "$NORM/canon"
strip_blocks "$MIRROR" "$NORM/mirror"

# Which skills exist on each side, so the advice can name the right direction.
only_mirror="$( comm -13 <(cd "$NORM/canon" && find . -mindepth 1 -maxdepth 1 -type d | sort) \
                          <(cd "$NORM/mirror" && find . -mindepth 1 -maxdepth 1 -type d | sort) \
                | sed 's|^\./||' )"
only_canon="$( comm -23 <(cd "$NORM/canon" && find . -mindepth 1 -maxdepth 1 -type d | sort) \
                         <(cd "$NORM/mirror" && find . -mindepth 1 -maxdepth 1 -type d | sort) \
               | sed 's|^\./||' )"
content_diff="$( diff -rq "$NORM/canon" "$NORM/mirror" 2>/dev/null | grep '^Files ' || true )"

# ---- A MIRRORED FILE THAT IS NOT A SKILL ---------------------------------------------------
#
# This script verified that two copies matched and never asked whether the thing being copied
# was a skill at all. Found 2026-08-23: `delegate/SKILL.md` had NO YAML frontmatter in either
# home -- both copies identical, both invalid. Claude Code documents frontmatter as required
# and uses `description` to decide when to load a skill automatically, so a skill without one
# can never be auto-invoked. `/delegate` still worked, which is why nobody noticed.
#
# The skill in question exists because "the measured failure is not that delegation goes badly,
# it is that it never starts". It could not start.
#
# Checked on the CANONICAL side only. The mirror is asserted byte-identical two lines above, so
# checking both would report every fault twice and imply they are separate faults.
fm_bad=""
for _sk in "$CANON"/*/SKILL.md; do
  [ -f "$_sk" ] || continue
  _dir="$(basename "$(dirname "$_sk")")"
  # Frontmatter must be the FIRST thing in the file. A block after a header comment is not
  # frontmatter, it is prose that happens to contain colons.
  if [ "$(head -1 "$_sk")" != "---" ]; then
    fm_bad="$fm_bad
       $_dir/SKILL.md — no YAML frontmatter at line 1; Claude Code cannot load it automatically"
    continue
  fi
  _fm="$(awk 'NR>1 && /^---$/{exit} NR>1' "$_sk")"
  printf '%s' "$_fm" | grep -qE '^name:[[:space:]]*[^[:space:]]' \
    || fm_bad="$fm_bad
       $_dir/SKILL.md — frontmatter has no name:"
  printf '%s' "$_fm" | grep -qE '^description:[[:space:]]*[^[:space:]]' \
    || fm_bad="$fm_bad
       $_dir/SKILL.md — frontmatter has no description:, so nothing tells Claude when to use it"
  # THE NAME MUST MATCH THE DIRECTORY. The directory is what becomes the command; a name that
  # disagrees with it is a label pointing at a different skill.
  _nm="$(printf '%s' "$_fm" | sed -n 's/^name:[[:space:]]*//p' | head -1 | tr -d '[:space:]')"
  if [ -n "$_nm" ] && [ "$_nm" != "$_dir" ]; then
    fm_bad="$fm_bad
       $_dir/SKILL.md — name: '$_nm' does not match its directory '$_dir'"
  fi
done
if [ -n "$fm_bad" ]; then
  say "[!]  a mirrored file is not a valid skill"
  say "     Two identical copies of an invalid skill is still an invalid skill, and this"
  say "     script used to report that pair as clean."
  printf '%s\n' "$fm_bad" | { [ "$QUIET" = "1" ] && cat >/dev/null || cat; }
  say "     Frontmatter goes at line 1, between --- markers, with name: and description:."
  say "     See $CANON/verify/SKILL.md for the shape."
  exit 1
fi

# ==== SAY THAT IT RAN, AND SAY WHAT IT DID NOT MEASURE ====================================
#
# Two problems with exiting 0 in silence, and this project has recorded both elsewhere.
#
# FIRST: a check that prints nothing when clean is indistinguishable from a check that never
# ran. That is the same shape as `[GAP]` versus `[PASS]`, and as a repository with no CI
# reading identically to one that is green.
#
# SECOND, and the reason this line names it: THIS MEASURES STRUCTURE, NOT OUTCOME. It proves
# two trees match and that frontmatter parses. It proves nothing about whether a skill is
# selected when it should be, or helps when it is. Prompted by tjboudreaux/cc-thinking-skills
# (registered 2026-09-08), whose eval harness separates exactly these -- "does the file have
# the right headers" from "does it improve reasoning and fire at the right time" -- and whose
# authors, having measured, DELETED 11 of 39 of their own skills and authorised no claim that
# the rest work. A structural check reporting a bare success invites the reader to hear the
# outcome claim it never made.
if [ -z "$only_mirror" ] && [ -z "$only_canon" ] && [ -z "$content_diff" ]; then
  _n=$(find "$CANON" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
  say "[OK] skills mirror: $_n skill(s), $CANON == $MIRROR, frontmatter parses."
  say "     STRUCTURE ONLY — this does not measure whether a skill is SELECTED when it"
  say "     should be, or whether it helps when it is. Those need an outcome eval."
  exit 0
fi

say "[!]  skills mirror is out of sync ($CANON is canonical)"

if [ -n "$only_mirror" ]; then
  say ""
  say "     Only in $MIRROR/ — these look adopter-authored:"
  printf '       %s\n' $only_mirror | { [ "$QUIET" = "1" ] && cat >/dev/null || cat; }
  say "     Copying canonical over the mirror will NOT fix this — cp never removes,"
  say "     so the warning would just fire again. Promote them instead:"
  say "       cp -R $MIRROR/<skill> $CANON/<skill>     # then re-run this check"
  say "     (Or delete them from the mirror if they were scratch work.)"
fi

if [ -n "$only_canon" ]; then
  say ""
  say "     Only in $CANON/ — the mirror is stale:"
  printf '       %s\n' $only_canon | { [ "$QUIET" = "1" ] && cat >/dev/null || cat; }
  say "     Fix: cp -R $CANON/. $MIRROR/"
fi

if [ -n "$content_diff" ]; then
  say ""
  say "     Same skill, different content (localcoder blocks already ignored):"
  printf '%s\n' "$content_diff" | sed "s|$NORM/canon|$CANON|; s|$NORM/mirror|$MIRROR|; s|^|       |" \
    | { [ "$QUIET" = "1" ] && cat >/dev/null || cat; }
  say "     Canonical wins: cp -R $CANON/. $MIRROR/"
  say "     (If you edited the mirror directly, port that change to $CANON first.)"
fi

exit 1
