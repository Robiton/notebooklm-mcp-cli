#!/usr/bin/env bash
# Project:  ai-project-scaffold
# File:     tools/secret_scan.sh
# Modified: 2026-10-08
# Version:  0.10.2.20261008.1245
# Purpose:  Heuristic backstop for committed credentials, with line-scoped exceptions.
# Changelog:
#   2026-10-08 v0.10.2.20261008.1245 — keyword-free SHAPES: a GitHub token (ghp_/github_pat_), an AWS key id (AKIA/ASIA), a PEM private key header and a password in a URL are caught whatever the variable is called. Only a line marker clears one. 8 selftests, 5 proven red against 0.10.1. Measured across five repos: two deliberate examples, both marked.
#   2026-09-23 v0.10.1.20260923.0941 — fixtures run inside the root tools/fixture_guard.sh validates. There a git and a mktemp on PATH refuse anything that would land outside it. Every mktemp takes a ${TMPDIR} template, because macOS mktemp ignores TMPDIR without one. Its preamble message names the tool (secret_scan: ...), which its own keyword rule reads as an assignment, so the line is marked not-a-secret.
#   2026-09-04 v0.10.0.20260904.0824 — REFERENCE_NAME was snake_case-only, and a code expression cannot hold a
#                        credential (#304). Every alternative required a literal leading
#                        underscore, so `token_url` was suppressed and `tokenUrl` flagged —
#                        same name, different convention. JS, Java, Kotlin, Swift and Go are
#                        camelCase, so the suppressor was effectively OFF for most languages an
#                        adopter brings. Measured on a real repo: 5 findings, all false.
#                        EXPRESSION_VALUE adds the second half — an RHS with no string literal
#                        AND a code operator holds nothing. "No literal" alone would have been
#                        unsafe: API_KEY=sk_live_... is unquoted too, and that is what a .env
#                        looks like. Both guard rails are asserted in the same selftest run.
#   2026-09-03 v0.9.0.20260903.1639 — PROSE IN A MARKDOWN FILE IS NOT A CREDENTIAL (#290).
#                        The value half accepts ANY quoted string of eight characters or more
#                        after a keyword-ish name. In code that is right; in prose it fires on
#                        ordinary English. A sentence reporting a token COUNT followed by a
#                        quoted result turned two commits red, on 2026-09-02 and 09-03 -- the
#                        exact text is in the fixtures, where the scan reads it deliberately
#                        and a marker declares it. Both times it was in a
#                        session log written moments earlier, and both times the fix was to
#                        reword a TRUE sentence to appease a scanner. A check that makes
#                        people edit honest prose is one they learn to route around.
#                        THE DISCRIMINATOR IS NARROW: a value with a SPACE and NO DIGIT, in
#                        .md only. "Tr0ub4dor" has no space, an AWS key has no space, and
#                        "correct horse battery9" has a digit -- all still caught, in Markdown
#                        too. The three other value shapes are untouched everywhere.
#                        What it gives up is a passphrase with spaces and no digit in a
#                        Markdown file, and scaffold:not-a-secret remains the way to declare
#                        anything this gets wrong.
#                        Both fixtures are the EXACT sentences that turned a commit red, plus
#                        three that must still fail: a real secret in Markdown, a spaced value
#                        with a digit, and the same prose in a .py file.
#   2026-08-14 v0.8.0 — EVERY SUPPRESSION REPORTS ITS COUNT, AND ZERO IS THE INTERESTING
#                        VALUE. Four filters stood between a keyword hit and a reported
#                        finding and none of them said how much they removed. The largest is
#                        `scaffold:not-a-secret` — a human declaration that suppresses
#                        SECRET-SCANNER findings — and 25 of them had accumulated one at a
#                        time, each added to quieten a specific line, with nothing ever
#                        reviewing the set. Measured on this tree: 25 adjudicated, 4 reference
#                        names, 1 placeholder, 0 HEC.
#                        PRINTED ON THE GREEN PATH TOO, which is the whole point: "No obvious
#                        secrets found" is the same sentence whether nothing matched or an
#                        allowlist ate every match.
#                        The pipeline is staged rather than chained so each removal is
#                        attributable to ITS filter — four chained greps report one number for
#                        four decisions, and only one of the four is a human decision.
#                        COUNTS GO TO A FILE, NOT A GLOBAL. unadjudicated_lines runs inside
#                        `$( )`, a SUBSHELL, so a global counter would have reported 0 forever
#                        while looking correct — this programme's own favourite defect, very
#                        nearly shipped inside the fix for it.
#   2026-08-09 v0.7.0 — A placeholder VALUE is not a credential: `changeme`, `example`,
#                        `TODO`, or anything ending in `(` — a call, not a value. It earns
#                        its place at any floor, because the QUOTED rule reaches these
#                        shapes whatever the unquoted floor is.
#                        AND IT RECORDS A REVERTED EXPERIMENT. With it, dropping the floor
#                        16 -> 6 scored 14/14 with zero false positives on a 40-line
#                        corpus — then the real repos rejected it: `# ... tokens: Splunk
#                        cannot read them from passwords.conf` is PROSE, and six characters
#                        of a normal word clears a floor of six. ai/MEMORY.md is
#                        deliberately not excluded and is the file most likely to discuss
#                        auth in prose. The corpus measured what I thought of; the repos
#                        found the class I had not. `api_key = abc123` stays missed, now
#                        asserted as a DECISION so nobody re-lowers the floor without
#                        meeting the case.
#   2026-08-09 v0.6.0 — Tuned against a CORPUS instead of a guess: 32 lines of real
#                        credential shapes and real false-positive shapes. Before:
#                        12/14 leaks caught with 2 FALSE POSITIVES. After: 13/14 with 0.
#                        The false positives were mine. 0.16.0 widened the NAME half and
#                        was measured as "zero new findings" against three repos that
#                        happen to contain neither shape — so `api_key_header =
#                        "X-Api-Key"` and `secret_name = "prod/db/creds"` started firing
#                        and nothing said so. A name ending in a reference suffix POINTS
#                        AT a secret and is not one; that is the same indirection
#                        argument that already excludes $VAR and {{ template }} from the
#                        value half.
#                        Unquoted floor 20 -> 16, which is where the last reachable leak
#                        is caught (a 19-char password sat under the old rule by one).
#                        Below 16 gains nothing but noise. `api_key = abc123` stays
#                        missed at six characters, deliberately: gitleaks is the real
#                        tool, and a six-character value is a placeholder far more often
#                        than a credential.
#   2026-08-09 v0.5.0 — The keyword no longer has to TOUCH the separator. A name that
#                        contained a keyword but did not end with one was invisible, so
#                        `aws_secret_access_key = wJalrXUtnFEMI/...` — 40 characters, the
#                        canonical example from AWS's own docs — was reported as "no
#                        obvious secrets found". Every plausible real variable name
#                        carries a suffix: _prod, _v2, _ro, _access_key. Widened to
#                        `[A-Za-z0-9_]*`, which stops at a dot, dash or space, so it
#                        widens the NAME and nothing else — the separator and value rules
#                        are untouched and cannot admit a shape they already reject.
#                        Cost measured across all three real repos before shipping: ZERO
#                        new findings. Four cases, including one proving a suffixed name
#                        is still adjudicable (a widening with no sanctioned way out is
#                        the #127 mistake) and one proving it stops at a word boundary.
#   2026-08-08 v0.4.0 — Read binary files with --text on BOTH halves. Without it grep will
#                        not print matching lines from a file it calls binary, and the two
#                        greps that ship disagree about where that notice goes: BSD grep
#                        (macOS) writes "Binary file X matches" to STDOUT, so the finding
#                        lands and the build fails; GNU grep 3.5+ (every Linux runner)
#                        writes it to STDERR, so the result is EMPTY and the file passes.
#                        A credential pasted into a .p12 or a .pyc therefore failed on a
#                        developer's Mac and was silently cleared by the same scan in CI —
#                        the platform that gates the merge being the blind one. Latent
#                        since v0.1.0; invisible because every fixture was text. The v0.3.0
#                        binary case passed locally and went red on its first Linux run,
#                        which is this repo's only Linux exposure. Output is now stripped
#                        of non-printables: reading binary as text means a match can carry
#                        control bytes, and raw escapes in a log are an injection surface.
#   2026-08-08 v0.3.0 — Prefilter the tree with ONE `git grep` instead of two greps per
#                        tracked file. Measured before the change on a synthetic 5,000-file
#                        repo: 20s, inside a CI job that budgets 5 minutes for every check
#                        it runs. The cost was linear in tracked files and nothing capped
#                        it, so the scan got slower for every adopter as their repo grew,
#                        and the first response to a slow check is to stop running it.
#                        After: 0.09s on the same fixture — 19.7s -> 0.09s, both measured.
#                        THE PREFILTER IS DERIVED FROM THE VERDICT'S OWN PATTERN ($KEYWORDS)
#                        rather than written out beside it, because a second copy of a rule
#                        is how a fix reaches one of them — the failure #96 already cost
#                        this repo twice. A superset prefilter can only cost time, never a
#                        detection; verified by differential test against v0.2.0 over the
#                        full fixture corpus, identical verdicts on every case.
#                        Also: outside a git repo this printed "No obvious secrets found"
#                        and exited 0. It now says it did not run. Same exit code, but the
#                        claim was false and false all-clears are the point of this file.
#   2026-08-08 v0.2.0 — NUL-safe file walk. 0.1.0 built a newline-joined list and walked it
#                        with `for f in $hits`, which word-splits: a tracked file named
#                        `app/my config.py` became two non-existent paths, grep found
#                        nothing in either, and the file PASSED. Measured — a real
#                        `api_key = "sk_live_..."` reported as "No obvious secrets found",  # scaffold:not-a-secret
#                        exit 0. The inline step this replaced failed on a non-empty LIST,
#                        so a mis-split still failed the build; moving the verdict into the
#                        per-file loop is what turned a detection into a silent pass, and a
#                        false negative is the worst outcome a secret scan has. The path now
#                        goes from `git ls-files -z` into the loop and is never a word, and
#                        the exclusion is a `case` rather than a grep over a joined list.
#                        Two selftest cases: every fixture had a tidy path, which is how the
#                        whole class went untested.
#   2026-08-08 v0.1.0 — Lifted out of .github/workflows/scaffold-check.yml so it can be
#                        tested and linted as code (#127). It lived in a `run:` block, and
#                        this repo has already shipped a dropped `fi` that way: bash -n
#                        covers SCRIPT FILES and a workflow is YAML, so the only check on
#                        it was a proxy. As a file it gets --selftest, and CI discovers
#                        that the same way it discovers every other tool's.
#                        Behaviour change in the same move: exceptions are adjudicated per
#                        LINE, so `# scaffold:not-a-secret` or an existing `# nosec` clears
#                        one line without excluding a file. Extracting it immediately paid
#                        for itself — writing the fixtures found that reading matched lines
#                        case-SENSITIVELY while the file list is built case-INsensitively,
#                        which silently passed every file it was supposed to examine.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# A LEAK IS word + separator + a LITERAL VALUE. An earlier pattern ended in `[=: ]`, whose
# character class contains a BARE SPACE, so any prose where one of these words was followed
# by a space failed the build — including a line documenting CSRF handling, and the note
# written to describe the trap. ai/MEMORY.md is deliberately not excluded and is also the
# file most likely to discuss auth in prose, so it fired on exactly the wrong file.
#
# Values that are REFERENCES — $VAR, ${VAR}, {{ template }}, <placeholder> — are
# indirection, not secrets. Flagging them teaches people to ignore the check.
#
# SPLIT IN TWO SO THE PREFILTER CANNOT DRIFT FROM THE VERDICT. scan() needs a cheap way to
# find candidate files across the whole tree (see there for why), and the only safe
# prefilter is one that is a STRICT SUPERSET of the real pattern. Deriving both from the
# same $KEYWORDS makes that a property of the source rather than a promise in a comment:
# every line PATTERN can match begins with a KEYWORDS match, so a file the prefilter skips
# provably has nothing for the verdict to find.
# The keyword-free SHAPES below join the prefilter as a second alternative, for the same reason.
KEYWORDS='(password|passwd|api_key|apikey|secret_key|secret|token|bearer)'

# THE KEYWORD DOES NOT HAVE TO TOUCH THE SEPARATOR, AND REQUIRING IT TO MISSED THE MOST
# RECOGNISABLE SECRET THERE IS.
#
# Until 0.15.3 the pattern went straight from $KEYWORDS to `[=:]`, so a name that CONTAINED
# a keyword but did not END with one was invisible. Measured:
#
#     aws_secret_access_key = wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY   MISSED  # scaffold:not-a-secret
#     github_token_ro       = ghp_xxxxxxxxxxxxxxxxxxxx                   MISSED  # scaffold:not-a-secret
#     secret = "Tr0ub4dor"                                               caught  # scaffold:not-a-secret
#
# Those three lines carry the marker because THIS SCAN NOW READS THEM, which it could not
# do before the widening — the checker firing on its own rulebook, one commit after the
# rule changed. That is the shape #127 was about, and the line-scoped marker is the
# sanctioned way out rather than excluding the file or contorting the example.
#
# The AWS one is the canonical example from AWS's own documentation. A scan that reports
# "no obvious secrets" over a committed AWS secret key is the false all-clear ai/PLANNING.md
# rates as strictly worse than a false positive, and every plausible variable name in real
# code carries a suffix: _prod, _v2, _ro, _access_key.
#
# `[A-Za-z0-9_]*` ONLY — no dots, no dashes, no spaces. It widens the NAME and nothing else:
# the separator and the value half are untouched, so this cannot admit a shape the value
# rules already rejected. Cost measured before shipping, across all three real repos
# (scaffold, its dev context, localcoder): ZERO new findings. The widening is close to free
# because it discriminates on a part of the line that was never doing any work.
KEYWORD_NAME="$KEYWORDS"'[A-Za-z0-9_]*'
PATTERN="$KEYWORD_NAME"'[[:space:]]*[=:][[:space:]]*("[^"$<{][^"]{7,}"|'"'"'[^'"'"'$<{][^'"'"']{7,}'"'"'|[A-Za-z0-9_+/=-]{16,}|[A-Za-z_+/=!@#%^&*-]{6,}[0-9][A-Za-z0-9_+/=!@#%^&*-]*)'

# A SHAPE NEEDS NO KEYWORD (audit 2026-10-08). Everything above starts from a NAME, so a
# credential whose variable is called `gh`, `creds` or nothing at all -- a token pasted into
# a URL, a heredoc, a YAML list -- was invisible however recognisable the value was. These
# four shapes are recognisable on their own: a GitHub token, an AWS access key id, a PEM
# private key header, and a password in a URL's userinfo. A URL whose password half is a
# reference (${TOKEN}, $PW, <password>) is excluded by the character class, as above.
#
# HIGH PRECISION, SO ONLY A HUMAN CAN CLEAR ONE. A shape line skips the reference-name,
# placeholder, expression and prose filters: those were built to tell a name from a value,
# and a shape match is already a value. `scaffold:not-a-secret` / `nosec` still clear it.
# Measured before shipping across scaffold, -dev, localcoder, localcoder-dev and control:
# two hits per repo, both deliberate examples, both now marked on the line.
SHAPES='(gh[pousr]_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{22,}|(AKIA|ASIA)[0-9A-Z]{16}|-----BEGIN ([A-Z0-9]+ )*PRIVATE KEY-----|[A-Za-z][A-Za-z0-9+.-]*://[^/[:space:]:@"'"'"'<>$]+:[^/[:space:]@"'"'"'<>${}]+@)'

UUID='[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}'

# A HUMAN ALREADY RULED ON THIS LINE (#127).
#
# #120 widened this scan from ai/ to the whole tracked tree, which is correct and is what
# made real source reachable. It also made a shape close to boilerplate fail: a Flask or
# Django config module carrying
#     _DEFAULT_SECRET = 'dev-secret-key-change-in-production'  # scaffold:not-a-secret
# is word + separator + literal, so it matches, and the value genuinely IS a literal so it
# always will. Measured on a real 0.6.3 -> 0.11.3 upgrade: CI went red on a line untouched
# for years that already carried `# nosec B105`, because bandit flagged it once and a human
# ruled on it then.
#
# The three available responses were all bad. Renaming the variable to dodge the regex
# contorts source to satisfy a checker and leaves the next person free to rename it back.
# Excluding the file is a hole — the argument the HEC exception already makes. Appending
# `|| echo ::warning::` makes the whole scan advisory, and this repo argues everywhere that
# a warning nobody acts on is indistinguishable from no check. None of them was "declare
# that this line was reviewed and is fine", and a prohibition with no sanctioned path gets
# worked around — which is exactly where the HEC rule was before it got one.
#
# `# nosec` is honoured beside the scaffold marker because it is line-scoped by
# construction and ALREADY means a human reviewed this line; B105 is literally
# hardcoded_password_string. Demanding a second, different marker next to it would be
# ceremony, not safety.
ADJUDICATED='scaffold:not-a-secret|(^|[^A-Za-z0-9_])nosec([^A-Za-z0-9_]|$)'

# A NAME ENDING IN ONE OF THESE POINTS AT A SECRET; IT IS NOT ONE.
#
# `api_key_header = "X-Api-Key"` is an HTTP header name. `secret_name = "prod/db/creds"` is
# a lookup key for a vault. Both are quoted literals over eight characters, so the value
# rules match them, and after 0.16.0 widened the NAME half they matched there too — the
# widening that was measured as "zero new findings" against three repos that happen to
# contain neither shape. Measured properly against a 32-line corpus of real credential
# shapes and real false-positive shapes: 2 false positives, both of this form, both gone
# when the suffix is excluded.
#
# THE COST OF A FALSE POSITIVE HERE IS THE WHOLE CHECK. #127 is the record: one boilerplate
# line failing a build produced three bad options and nearly got the scan switched off.
# These suffixes are the shapes where the variable name itself says "this is a reference",
# and a reference is indirection — the same reason `$VAR` and `{{ template }}` are excluded
# from the value half.
# A VALUE THAT IS A PLACEHOLDER OR A CALL IS NOT A CREDENTIAL, and saying so is what made
# the short-value floor affordable at all.
#
# It earns its place at ANY floor, because the quoted-value rule reaches these shapes too:
# `password = "changeme123"` is eleven quoted characters and matches whatever the unquoted
# floor is. #127 is the record of what ONE such false positive costs — three bad options and
# a scan nearly switched off.
#
# AND IT IS WHAT MADE A SHORT-VALUE FLOOR *LOOK* AFFORDABLE, WHICH IT IS NOT.
# Dropping the unquoted floor 16 -> 6 catches `api_key = abc123`, the last leak in the
# corpus, and with this exclusion it scored 14/14 with zero false positives. Then the real
# repos rejected it: four findings, and the decisive one was
#     # commit HEC receiver tokens: Splunk cannot read them from passwords.conf
# — ordinary PROSE, where `tokens:` is followed by six characters of a normal word. That is
# the exact failure the pattern's own history records (`[=: ]` once contained a bare space
# and failed the build on a line about CSRF), and `ai/MEMORY.md` is deliberately not excluded
# and is the file most likely to discuss auth in prose.
#
# The corpus had 40 lines and not one of them was prose with a colon. It measured what I
# thought of; the real repos found the class I had not. Floor stays at 16 and
# `api_key = abc123` stays missed at six characters — deliberately, and now with a second
# reason: gitleaks is the real tool, and the alternative costs the whole check.
#
# It matches the VALUE, never the name — a variable called `password` holding a real secret
# is still caught; only a value that announces itself as a stand-in is cleared.
PLACEHOLDER_VALUE='[=:][[:space:]]*["'"'"']?(changeme|change-me|example|sample|test|dummy|placeholder|todo|fixme|none|null|nil|true|false|xxx+|your[-_])|[=:][[:space:]]*[A-Za-z_][A-Za-z0-9_]*\('

# ==== PROSE IN A MARKDOWN FILE IS NOT A CREDENTIAL (#290) ===================================
#
# The value half accepts `"[^"$<{][^"]{7,}"` — ANY quoted string of eight characters or more
# after a keyword-ish name. In code that is right; in prose it fires on ordinary English:
#
#     4 generated tokens: "No issues found."   # scaffold:not-a-secret
#
# (That example line carries the marker because THIS SCAN READS IT — a `.sh` file, so the
# Markdown-only suppression below does not apply to it. The checker firing on its own
# rulebook is the same shape the AWS example above records, and the line-scoped marker is
# the sanctioned way out rather than contorting the example.)
#
# `tokens` matches the name, `: ` the separator, and the sentence the value. That exact line
# turned two commits red on 2026-09-02 and 2026-09-03, both times in a session log I had just
# written, and both times the fix was to reword a true sentence to appease a scanner. A check
# that makes people edit honest prose is one they learn to route around.
#
# THE DISCRIMINATOR IS NARROW ON PURPOSE: a value containing a SPACE and NO DIGIT, in a
# Markdown file only. Secrets do not look like that.
#
#     "No issues found."              space, no digit   -> prose
#     "Tr0ub4dor"                     no space          -> still caught
#     "correct horse battery9"        space AND digit   -> still caught
#     wJalrXUtnFEMI/K7MDENG/bPx...    no space          -> still caught
#
# SCOPED TO .md, AND ONLY THE QUOTED-STRING ALTERNATIVE. The three other value shapes — the
# long unbroken token, the letters-with-a-digit run, and the single-quoted form — are
# untouched everywhere, so a real credential pasted into a session log is still found. A
# passphrase with spaces AND no digit in a Markdown file is the one thing this gives up, and
# `scaffold:not-a-secret` remains the way to declare anything this gets wrong.
PROSE_VALUE='[=:][[:space:]]*"[^"0-9]*[[:space:]][^"0-9]*"[[:space:]]*$'

# EVERY ALTERNATIVE REQUIRED A LITERAL LEADING UNDERSCORE, so this only ever fired on
# snake_case. `token_url` was suppressed and `tokenUrl` was flagged — same name, same
# meaning, different convention. JavaScript, Java, Kotlin, Swift and Go are camelCase by
# convention, so the suppressor was effectively OFF for most of the languages an adopter
# brings. Measured on a real repo: five findings, all false, one of them
# `this._tokenUrl = '/.netlify/functions/google-token'` — a name that names a URL, which is
# precisely what this exists to suppress.
#
# `([_-]|[a-z0-9])` accepts the camelCase boundary as well as the underscore, and the grep
# is already -i so the capitalised half matches. The word list is unchanged: these are
# REFERENCE words only. `password`, `token` and `secret` are deliberately absent from it,
# so widening the boundary cannot suppress a real credential name.
REFERENCE_NAME='([_-]|[a-z0-9])(header|name|names|field|id|ttl|url|uri|path|file|env|var|type|prefix|suffix|label|column|param|arg|hash|algo|length|len|regex|pattern)[[:space:]]*[=:]'

# A CREDENTIAL NEEDS A LITERAL TO LIVE IN. Three of that same repo's five findings assigned
# a plain host-language expression with no string anywhere on the right-hand side:
#
#     ERR_MISSING_TOKEN = ERROR_CODES_BASE + 16;                      arithmetic
#     offerToken = productIdAndOfferIndexArray[1];                    subscript
#     offerToken = subscriptionOfferDetails.get(0).getOfferToken();   method call
#
# None of those can hold a secret. But "no quotes on the RHS" is NOT a safe rule on its own:
# `API_KEY=sk_live_abc123` is a real credential and is also unquoted, which is the ordinary  # scaffold:not-a-secret
# shape of a .env file. So this requires BOTH no string literal AND an operator that only
# appears in code — a call, a subscript or arithmetic. A bare unquoted value stays flagged.
EXPRESSION_VALUE='[=:][[:space:]]*[^"'"'"']*[][()+][^"'"'"']*$'

# The five standards files DOCUMENT credential handling in prose, and a checker that fires
# on its own rulebook is one people switch off.
#
# A CASE, NOT A GREP FILTER, so the path never has to survive a newline-delimited pipeline.
# See scan() for why that matters.
is_excluded() {   # is_excluded <path>
  case "$1" in
    ai/SECURITY.md|ai/PLANNING.md|ai/STANDARDS.md|ai/CODING.md|ai/REFERENCE.md) return 0 ;;
    overlays/*|docs/*|.github/workflows/*) return 0 ;;
  esac
  return 1
}

# ==== EVERY SUPPRESSION REPORTS ITS COUNT, AND ZERO IS THE INTERESTING VALUE ================
#
# Four filters stand between a keyword hit and a reported finding, and until now NONE of them
# said how much they removed. That is the worst place in this tree for it: the largest is
# `scaffold:not-a-secret`, a human declaration that suppresses SECRET-SCANNER findings, and 33
# of them accumulated one at a time, each added to quieten a specific line, with nothing ever
# reviewing the set.
#
# The distinguishing test, from design review 2026-08-14 and worded by them because my own
# version readmitted everything it had just excluded: **report a suppression when a human
# declared it, or when the set it removes could change a figure the tool reports.** Skipping
# `node_modules` is machinery and stays silent; all four below can move a finding count.
#
# ZERO IS WHY THIS IS PRINTED UNCONDITIONALLY. "No obvious secrets found" reads identically
# whether nothing matched or whether an allowlist quietly ate every match, and those want
# opposite actions. A count of 0 adjudications on a clean tree is the reassuring case; a count
# of 33 on a clean tree is a finding about the allowlist.
#
# COUNTS GO TO A FILE, NOT A GLOBAL. unadjudicated_lines is called inside `$( )`, which is a
# SUBSHELL — a variable incremented there is discarded the moment it returns, so a global
# counter would have reported 0 forever while looking entirely correct. That is this
# programme's own favourite defect and it would have shipped inside the fix for it.
SUPPRESS_LOG=""

nlines() {  # nlines <string>; 0 for empty, else the line count
  [ -n "$1" ] || { printf '0'; return; }
  printf '%s\n' "$1" | grep -c '' || true
}

# Returns the matched lines in $1 that no one has adjudicated. Empty output = file is clean.
unadjudicated_lines() {
  local f="$1" hec_ok="$2" remain
  # -i IS LOAD-BEARING AND MUST MATCH THE FILE SELECTION. The file list is built with
  # `grep -liE`, so `_DEFAULT_SECRET` matches `secret` — that case-insensitivity is the
  # whole reason #127's line was reachable at all. Reading the file case-SENSITIVELY here
  # found no lines, left this empty, and passed the file: a silent false negative that
  # reports success for work it did not do. Found by running fixtures, not by reading.
  # -a IS THE OTHER HALF, AND WITHOUT IT THIS SCAN'S ANSWER DEPENDED ON THE OPERATING
  # SYSTEM. Without --text, grep refuses to print matching lines from a file it decides is
  # binary. BSD grep (macOS) announces "Binary file X matches" on STDOUT, which lands in
  # $remain and fails the build; GNU grep 3.5+ (every Linux CI runner) writes the same
  # notice to STDERR, so $remain came back EMPTY and the file passed.
  #
  # So a credential pasted into a .p12, a .pyc, a keystore — anything git calls binary —
  # was reported by this scan on a developer's Mac and silently cleared by the same scan in
  # CI. That is worse than either behaviour on its own: the platform that gates the merge
  # was the blind one. Latent since v0.1.0 and invisible to the fixtures, because every
  # fixture file was text; the case added in v0.3.0 passed locally and failed on the first
  # Linux run, which is the only exposure this repo has (the `mktemp -t` lesson again).
  #
  # EVERY GREP IN THE PIPELINE NEEDS IT, NOT JUST THE FIRST. The matched line still carries
  # the NUL bytes that made the file binary, so the NEXT grep re-runs the same detection on
  # its own stdin and suppresses the line again — "Binary file (standard input) matches",
  # which is neither a finding nor a pass. Found by the differential harness, not by
  # reading: the first fix moved the failure one process to the right.
  #
  # --text makes both platforms read the bytes. The pattern needs keyword + separator +
  # literal, which random binary content does not produce by accident, and scan() strips
  # non-printables before anything reaches a log.
  # STAGE BY STAGE, so each filter's removal is attributable to IT rather than to the
  # pipeline. Chained greps report one number for four decisions, which is the same reason
  # this scan reads each gotcha source separately: a total is reassuring in exactly the case
  # that is broken.
  local s0 s1 s2 s3
  s0="$(grep -a -niE "$PATTERN" "$f" 2>/dev/null || true)"
  s1="$(printf '%s' "$s0" | grep -a -vE "$ADJUDICATED" || true)"
  s2="$(printf '%s' "$s1" | grep -a -viE "$REFERENCE_NAME" || true)"
  s3="$(printf '%s' "$s2" | grep -a -viE "$PLACEHOLDER_VALUE" || true)"
  s3="$(printf '%s' "$s3" | grep -a -vE "$EXPRESSION_VALUE" || true)"
  # PROSE, IN MARKDOWN ONLY (#290). Applied after the other three so its count is its own and
  # a reader can see how often it fires; a suppression nobody can count is one nobody can
  # question.
  local sp="$s3"
  case "$f" in
    *.md) sp="$(printf '%s' "$s3" | grep -a -vE "$PROSE_VALUE" || true)" ;;
  esac
  remain="$sp"
  # THE HEC EXCEPTION, DELIBERATELY NARROW AND UNCHANGED IN MEANING. A declared project may
  # commit HEC receiver tokens: Splunk cannot read them from passwords.conf and the repo is
  # the disaster-recovery copy for a fleet of them. ONE SHAPE is allowed — `token = <uuid>`
  # in a file named inputs.conf. A password, an api_key, a bearer, or a token whose value is
  # not a UUID still fails, in inputs.conf and everywhere else.
  local s4="$remain"
  if [ "$hec_ok" = "1" ]; then
    case "$f" in
      *inputs.conf)
        s4="$(printf '%s\n' "$remain" \
                  | grep -a -vE "^[0-9]+:[[:space:]]*token[[:space:]]*=[[:space:]]*${UUID}[[:space:]]*$" || true)"
        remain="$s4"
        ;;
    esac
  fi
  # THE SHAPES, MERGED IN BY LINE NUMBER. A line both rules match is reported once.
  local h0 h1 hadj=0
  h0="$(grep -a -nE "$SHAPES" "$f" 2>/dev/null || true)"
  h1="$(printf '%s' "$h0" | grep -a -vE "$ADJUDICATED" || true)"
  if [ -n "$h0" ]; then
    # Adjudicated shape lines the keyword rule did not already count, so no line is counted twice.
    hadj="$(printf '%s\n' "$h0" | grep -a -E "$ADJUDICATED" | grep -a -vxF -e "${s0:-}" | grep -c '' || true)"
    remain="$(printf '%s\n%s\n' "$remain" "$h1" | sed '/^$/d' | sort -t: -k1,1n -u)"
  fi
  # One row per file: adjudicated, reference-name, placeholder-value, hec. Summed by the
  # caller, which is outside the subshell this function runs in.
  if [ -n "$SUPPRESS_LOG" ]; then
    printf '%s %s %s %s %s\n' \
      "$(( $(nlines "$s0") - $(nlines "$s1") + ${hadj:-0} ))" \
      "$(( $(nlines "$s1") - $(nlines "$s2") ))" \
      "$(( $(nlines "$s2") - $(nlines "$s3") ))" \
      "$(( $(nlines "$sp") - $(nlines "$s4") ))" \
      "$(( $(nlines "$s3") - $(nlines "$sp") ))" >> "$SUPPRESS_LOG"
  fi
  printf '%s' "$remain" | sed '/^$/d'
}

scan() {
  local hec_ok=0 failed="" f remain
  # SAY THAT IT DID NOT RUN, RATHER THAN THAT IT FOUND NOTHING. Outside a git repo the walk
  # yields nothing, and every earlier version printed "No obvious secrets found in the
  # tracked tree" and exited 0 — a report of success for work it did not do, which is the
  # single failure mode ai/PLANNING.md rates worst. The exit code is unchanged (there is no
  # finding to fail on); only the claim is.
  if ! git rev-parse --git-dir >/dev/null 2>&1; then
    echo "Not a git repository — the secret scan did NOT run."
    return 0
  fi
  grep -qE '^<!--[[:space:]]*scaffold:hec-tokens-committed[[:space:]]*-->[[:space:]]*$' \
       ai/STANDARDS.md 2>/dev/null && hec_ok=1
  SUPPRESS_LOG="$(mktemp "${TMPDIR:-/tmp}/secret_scan.XXXXXX")" || SUPPRESS_LOG=""
  # Tracked files only — git ls-files skips .venv/, node_modules/ and build output, so this
  # cannot be drowned by a dependency tree. It scans the TRACKED TREE, not just ai/ (#120):
  # pointing it at a directory that holds prose read as coverage and was not.
  # NUL-DELIMITED END TO END, AND THAT IS A SECURITY PROPERTY, NOT TIDINESS.
  #
  # This built a newline-joined file list and then walked it with `for f in $hits`, which
  # word-splits. A tracked file named `app/my config.py` became `app/my` and `config.py`,
  # neither of which exists, so grep found nothing in either and the file PASSED. Measured:
  # a real `api_key = "sk_live_..."` in a filename containing a space was reported as  # scaffold:not-a-secret
  # "No obvious secrets found in the tracked tree", exit 0.
  #
  # The version this replaced failed on `[ -n "$HITS" ]` — a non-empty LIST — so a
  # mis-split still failed the build. Moving the verdict into the per-file loop is what
  # turned a detection into a silent pass. A false negative in a secret scan is the worst
  # outcome available to it: ai/PLANNING.md, "a false all-clear is strictly worse than a
  # false positive, because it is silent".
  #
  # So the path goes straight from the prefilter into the loop and is never a word.
  #
  # ONE PROCESS FOR THE TREE, NOT TWO PER FILE — A SCALE PROPERTY, MEASURED.
  # v0.1.0-0.2.0 walked every tracked path and ran `grep -qiE` on each. On a synthetic
  # 5,000-file repo that took ~20s, in a CI job that budgets 5 minutes for everything; a
  # 50k-file monorepo would spend the entire budget concluding it had nothing to report,
  # and the first thing anyone does to a slow check is stop running it. `git grep` searches
  # the tracked working tree in one process, so the loop below only visits files that
  # already contain one of the keywords — normally a handful, often none.
  #
  # -a AND NO -I, BOTH DELIBERATE, BOTH ABOUT BINARY FILES.
  # Adding -I would exclude binary files, making this scan quieter than the walk it
  # replaced — the change this repo refuses on principle, because a false all-clear is
  # silent. --text goes further and makes git read their bytes as text, so the prefilter
  # cannot decline a file that unadjudicated_lines is then willing to read; without it the
  # two halves could disagree about what "binary" means, which is the platform split
  # documented there. tools/conflict_scan.sh DOES use -I, because a conflict marker is a
  # text-file defect by definition — different question, different answer.
  while IFS= read -r -d "" f; do
    is_excluded "$f" && continue
    [ -f "$f" ] || continue
    remain="$(unadjudicated_lines "$f" "$hec_ok")"
    if [ -n "$remain" ]; then
      failed="yes"
      echo "$f:"
      # STRIP NON-PRINTABLES BEFORE THIS REACHES A TERMINAL OR A CI LOG. Now that binary
      # files are read as text, a match can drag control bytes along with it, and raw
      # escape sequences printed to a terminal are an injection surface, not just noise.
      printf '%s\n' "$remain" | LC_ALL=C tr -c '[:print:]\n' '?' | head -10
    fi
  done < <(git grep -a -l -z -iE "$KEYWORDS|$SHAPES" -- . 2>/dev/null || true)
  suppression_report
  if [ -n "$failed" ]; then
    echo "::error::Possible credential found. Review and remove."
    echo ""
    echo "If a flagged line is genuinely not a credential — a placeholder, a development"
    echo "default, a documented example — mark THAT LINE and re-run:"
    echo "    _DEFAULT_SECRET = 'dev-only-change-me'  # scaffold:not-a-secret"
    echo "An existing '# nosec' on the line is honoured too. Do not exclude the file, and"
    echo "do not rename the variable to dodge the pattern."
    return 1
  fi
  echo "No obvious secrets found in the tracked tree."
  return 0
}

# WHAT THE FILTERS REMOVED, ALWAYS, INCLUDING ALL ZEROS.
#
# Printed before the verdict on BOTH paths, because the case this exists for is a GREEN run:
# "No obvious secrets found" is the same sentence whether nothing matched or an allowlist ate
# every match. A reader who sees `33 adjudicated` above a clean verdict knows to go and read
# the 33; a reader who sees `0 adjudicated` knows the tree is genuinely quiet. Those were one
# observation until now.
suppression_report() {
  local a=0 r=0 p=0 h=0 total
  if [ -n "$SUPPRESS_LOG" ] && [ -f "$SUPPRESS_LOG" ]; then
    read -r a r p h w <<< "$(awk '{a+=$1; r+=$2; p+=$3; h+=$4; w+=$5} END {printf "%d %d %d %d %d", a, r, p, h, w}' \
                           "$SUPPRESS_LOG" 2>/dev/null)"
    rm -f "$SUPPRESS_LOG"
  fi
  a="${a:-0}"; r="${r:-0}"; p="${p:-0}"; h="${h:-0}"; w="${w:-0}"
  total=$((a + r + p + h + w))
  echo "Suppressed $total keyword hit(s) before the verdict:"
  echo "  $a  declared not-a-secret   (scaffold:not-a-secret / nosec, on the line)"
  echo "  $r  reference name          (a name that names a credential, not one that holds it)"
  echo "  $p  placeholder value       (changeme, xxxx, your-key-here)"
  echo "  $h  HEC token               (scaffold:hec-tokens-committed; token=<uuid> in inputs.conf)"
  echo "  $w  prose in Markdown       (a quoted value with a space and no digit, .md only)"
  # THE ADJUDICATION COUNT IS THE ONE WORTH A SECOND LINE. The other three are pattern
  # judgements this tool makes and can be re-derived by reading the patterns. That one is a
  # standing human decision to disbelieve a secret scanner, and nothing has ever reviewed the
  # set — 33 of them accumulated in this tree before anyone counted.
  if [ "$a" -gt 0 ]; then
    echo "  The $a adjudicated line(s) are a standing decision to disbelieve this scan."
    echo "  List them:  grep -rn 'scaffold:not-a-secret' \$(git ls-files)"
  fi
}

selftest() {
  # PROVE IT FAILS WHAT IT SHOULD, not merely that it runs. Every case here is a real
  # shape: #127's Flask default, the HEC exception's exact boundary, and the ways a
  # line-scoped marker could be abused into a file-scoped hole.
  local T fails=0 out got
  # FIXTURES RUN INSIDE A GUARDED ROOT (tools/fixture_guard.sh). Later mktemps land inside it,
  # and a git on PATH refuses any write outside it. The guard exists because a failed mktemp
  # once let a selftest run git init and commit in the real repo.
  . "$(dirname "${BASH_SOURCE[0]}")/fixture_guard.sh" || { echo "secret_scan: tools/fixture_guard.sh is missing; refusing to build fixtures" >&2; exit 1; }  # scaffold:not-a-secret (a tool name in a message)
  fixture_root FG_ROOT; trap fg_cleanup EXIT
  T="$(mktemp -d "${TMPDIR:-/tmp}/secret_scan.XXXXXX")" || return 1
  local SELF_ABS="$ROOT/tools/secret_scan.sh"

  case_run() {  # case_run <label> <expected-exit> <setup-fn>
    local label="$1" want="$2" setup="$3" R="$T/case"
    rm -rf "$R"; mkdir -p "$R/ai"
    ( cd "$R" && git init -q . && git config user.email a@b.c && git config user.name t )
    printf '# Standards\n' > "$R/ai/STANDARDS.md"
    ( cd "$R" && $setup )
    ( cd "$R" && git add -A >/dev/null 2>&1 )
    out="$( cd "$R" && bash "$SELF_ABS" 2>&1 )"; got=$?
    if [ "$got" = "$want" ]; then printf '  ok   %-54s\n' "$label"
    else
      printf '  FAIL %-54s want exit %s, got %s\n' "$label" "$want" "$got"
      printf '%s\n' "$out" | sed 's/^/         /' | head -6
      fails=$((fails + 1))
    fi
  }

  c_flask_bare()   { mkdir -p app; printf "_DEFAULT_SECRET = 'dev-secret-key-change-in-production'\n" > app/config.py; }  # scaffold:not-a-secret
  c_flask_nosec()  { mkdir -p app; printf "_DEFAULT_SECRET = 'dev-secret-key-change-in-production'  # nosec B105\n" > app/config.py; }  # scaffold:not-a-secret
  c_flask_marker() { mkdir -p app; printf "_DEFAULT_SECRET = 'dev-secret-key-change-in-production'  # scaffold:not-a-secret\n" > app/config.py; }
  c_real()         { mkdir -p app; printf 'api_key = "sk_live_9f8a7b6c5d4e3f2a1b"\n' > app/settings.py; }  # scaffold:not-a-secret

  # ---- PROSE IN MARKDOWN (#290). Both fixtures are the EXACT sentences that turned a commit
  # red, on 2026-09-02 and 2026-09-03, in session logs written moments earlier. The fix each
  # time was to reword a true sentence to appease a scanner, which is how a check teaches
  # people to route around it.
  c_prose_md()     { mkdir -p ai; printf 'The arm returned 4 generated tokens: "No issues found."\n' >> ai/SESSION.md; }
  c_prose_md2()    { mkdir -p ai; printf 'The reply was 4 tokens, the words: "No issues were located here"\n' >> ai/SESSION.md; }
  # AND THE THINGS IT MUST STILL CATCH IN THE SAME FILE TYPE. A digit, or no space, and the
  # value is credential-shaped again — a real key pasted into a session log is still found.
  c_secret_md()    { mkdir -p ai; printf 'token = "Tr0ub4dorAndMore"\n' >> ai/SESSION.md; }  # scaffold:not-a-secret
  c_secret_md_sp() { mkdir -p ai; printf 'password: "correct horse battery9"\n' >> ai/SESSION.md; }  # scaffold:not-a-secret
  # AND PROSE IS NOT SUPPRESSED IN CODE. The relaxation is Markdown-only by construction.
  c_prose_py()     { mkdir -p app; printf 'token = "No issues found here"\n' > app/x.py; }  # scaffold:not-a-secret
  # ---- camelCase REFERENCE NAMES, and host-language EXPRESSIONS (#304).
  # Every one of these was a real false positive on a real repository. The two
  # credential cases below them are the guard rails: widening a suppressor is only safe
  # if you assert what it must still catch, in the same run.
  c_camel_url()    { mkdir -p app; printf "this._tokenUrl = '/.netlify/functions/google-token';\n" > app/g.js; }
  c_snake_url()    { mkdir -p app; printf "this.token_url = '/.netlify/functions/google-token';\n" > app/g.js; }
  c_expr_arith()   { mkdir -p app; printf 'int ERR_MISSING_TOKEN = ERROR_CODES_BASE + 16;\n' > app/C.java; }
  c_expr_index()   { mkdir -p app; printf 'offerToken = productIdAndOfferIndexArray[1];\n' > app/P.java; }
  c_expr_call()    { mkdir -p app; printf 'offerToken = details.get(0).getOfferToken();\n' > app/P.java; }
  # THE UNQUOTED CREDENTIAL. "no string literal on the RHS" would have suppressed this,
  # which is why EXPRESSION_VALUE also requires a code operator. A .env file looks exactly
  # like this and it is the single most common way a real key gets committed.
  c_unquoted_key() { mkdir -p app; printf 'API_KEY=sk_live_abcd1234efgh5678ijkl\n' > app/.env.sample; }
  c_marker_other() { mkdir -p app; printf '# scaffold:not-a-secret\napi_key = "sk_live_9f8a7b6c5d4e3f2a1b"\n' > app/settings.py; }
  c_mixed()        { mkdir -p app; printf "_D_SECRET = 'dev-only-change-me'  # scaffold:not-a-secret\napi_key = \"sk_live_9f8a7b6c5d4e3f2a1b\"\n" > app/settings.py; }
  c_hec_ok()       { printf '# Standards\n<!-- scaffold:hec-tokens-committed -->\n' > ai/STANDARDS.md
                     mkdir -p default; printf 'token = 3f9a1b2c-4d5e-6f70-8192-a3b4c5d6e7f8\n' > default/inputs.conf; }  # scaffold:not-a-secret
  c_hec_undecl()   { mkdir -p default; printf 'token = 3f9a1b2c-4d5e-6f70-8192-a3b4c5d6e7f8\n' > default/inputs.conf; }  # scaffold:not-a-secret
  # THE CASE THAT WAS MISSING, AND THAT COST A SILENT FALSE NEGATIVE. A path with a space
  # word-split into two non-existent files under the old `for f in $hits`, so grep found
  # nothing in either and the file passed with exit 0. Every fixture here had a tidy path,
  # which is how a whole class of filename went untested — "a fixture acquires properties
  # real input does not guarantee" (ai/MEMORY.md).
  c_spaced_path()  { mkdir -p app; printf 'api_key = "sk_live_9f8a7b6c5d4e3f2a1b"\n' > "app/my config.py"; }  # scaffold:not-a-secret
  c_spaced_ok()    { mkdir -p app; printf "_D_SECRET = 'dev-only'  # scaffold:not-a-secret\n" > "app/my config.py"; }
  # BINARY FILES ARE IN SCOPE, AND THE PREFILTER MUST NOT QUIETLY DROP THEM. `git grep -I`
  # would have — the reason -I is absent from the prefilter, asserted here so the next
  # person to add it for tidiness sees a failing case instead of a smaller scan.
  c_binary()       { mkdir -p bin; printf 'HDR\x00\x01api_key = "sk_live_9f8a7b6c5d4e3f2a1b"\x00\n' > bin/blob.dat; }  # scaffold:not-a-secret
  # THE VALUE FLOOR, MEASURED RATHER THAN GUESSED. 19 characters unquoted sat under the old
  # 20-char rule by one, and the digit-alternative needs six non-digits before the first
  # digit — `Sup3r` is five. Scored against a 32-line corpus of real credential shapes and
  # real false-positive shapes; 16 is where the last reachable leak is caught and nothing
  # below it gains anything but noise.
  c_short_value()  { mkdir -p app; printf 'password = Sup3rSecretValue123\n' > app/s.py; }  # scaffold:not-a-secret
  # PLACEHOLDER VALUES. These reach the quoted-value rule at any floor, so the exclusion is
  # not tied to the short-value experiment that was reverted — see PLACEHOLDER_VALUE.
  c_tiny_value()    { mkdir -p app; printf 'api_key = abc123\n' > app/t.py; }  # scaffold:not-a-secret
  c_place_changeme(){ mkdir -p app; printf 'password = changeme\n' > app/p.py; }
  c_place_example() { mkdir -p app; printf 'secret = example\n' > app/e.py; }
  c_place_call()    { mkdir -p app; printf 'token = get_token()\n' > app/c.py; }
  # The exclusion must not become a laundering route on another line.
  c_place_then_real(){ mkdir -p app; printf 'password = changeme\napi_key = "sk_live_9f8a7b6c5d4e3f2a1b"\n' > app/m.py; }  # scaffold:not-a-secret
  # REFERENCE NAMES. Both of these are quoted literals over eight characters, so the value
  # rules match them; after 0.16.0 widened the NAME half they matched there too. They were
  # the two false positives the corpus found, and the widening had been measured against
  # three repos that contain neither shape.
  c_ref_header()   { mkdir -p app; printf 'api_key_header = "X-Api-Key"\n' > app/h.py; }
  c_ref_name()     { mkdir -p app; printf 'secret_name = "prod/db/creds"\n' > app/n.py; }
  # And the exclusion must not become a laundering route: a real credential on another line
  # of the same file still fails.
  c_ref_plus_real(){ mkdir -p app; printf 'api_key_header = "X-Api-Key"\napi_key = "sk_live_9f8a7b6c5d4e3f2a1b"\n' > app/m.py; }  # scaffold:not-a-secret
  # THE SHAPE THAT WAS INVISIBLE UNTIL 0.15.3, AND IT IS THE ONE EVERYONE RECOGNISES.
  # AWS's own documentation names this variable, so it is what a pasted credential looks
  # like in real code. The keyword `secret` is present but the name continues past it, and
  # the pattern used to require the keyword to sit against the separator.
  c_aws_key()      { mkdir -p app; printf 'aws_secret_access_key = wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY\n' > app/aws.py; }  # scaffold:not-a-secret
  c_suffix_token() { mkdir -p app; printf 'github_token_ro = ghp_A1b2C3d4E5f6G7h8I9j0K1l2\n' > app/gh.py; }                    # scaffold:not-a-secret
  # A suffixed name must still be adjudicable, or the widening creates a shape with no
  # sanctioned way out — the #127 mistake.
  c_suffix_adj()   { mkdir -p app; printf 'aws_secret_access_key = wJalrXUtnFEMI/K7MDENG/bPx  # scaffold:not-a-secret\n' > app/aws.py; }
  # THE WIDENING MUST NOT REACH ACROSS A WORD BOUNDARY. `[A-Za-z0-9_]*` stops at a dot, a
  # dash or a space, so prose and attribute access do not become findings.
  #
  # THE VALUE HERE MATCHES ON PURPOSE. The first version of this fixture used prose whose
  # value half could never match anything, so it passed under a deliberately over-wide name
  # rule too — it was asserting the value rules, not the boundary, and an injected
  # `[^=:]*` sailed through it. A fixture has to fail for the reason you are testing.
  c_not_a_name()   { mkdir -p app; printf 'the secret handling policy = documented_in_SECURITY_and_reviewed_2026\n' > app/doc.py; }
  # SHAPES WITH NO KEYWORD (audit 2026-10-08). Every value is ASSEMBLED AT RUN TIME, so this
  # source never holds the shape: the scan reads its own file, and a literal fixture here is
  # also what a host's push protection blocks. The variable names avoid every keyword, so
  # only the shape rule can catch them -- before it existed, all five passed.
  _r() { local n="$1" o=""; while [ "${#o}" -lt "$n" ]; do o="${o}Ab3"; done; printf '%s' "${o:0:$n}"; }
  c_shape_ghp()    { mkdir -p app; printf 'gh = "%s%s"\n' "ghp" "_$(_r 36)" > app/a.py; }
  c_shape_pat()    { mkdir -p app; printf 'pat: %s%s\n' "github" "_pat_$(_r 40)" > app/a.yml; }
  c_shape_akia()   { mkdir -p app; printf 'aws_id = %s%s\n' "AKIA" "QW3RTY7UIOP2ASDF" > app/a.ini; }
  c_shape_pem()    { mkdir -p app; printf '%sBEGIN RSA PRIVATE KEY%s\nMIIEow\n' "-----" "-----" > app/k.txt; }
  c_shape_url()    { mkdir -p app; printf 'DB = "postgres://app:%s@db.internal:5432/x"\n' "$(_r 14)" > app/d.py; }  # scaffold:not-a-secret (the %s is the password slot)
  c_shape_ref()    { mkdir -p app; printf 'DB = "postgres://app:${DB_PW}@db:5432/x"\nURL = "https://github.com/x/y"\n' > app/d.py; }
  c_shape_marked() { mkdir -p app; printf 'aws_id = %s%s  # scaffold:not-a-secret\n' "AKIA" "QW3RTY7UIOP2ASDF" > app/a.ini; }
  c_shape_short()  { mkdir -p app; printf 'gh = "%s%s"\n' "ghp" "_$(_r 20)" > app/a.py; }
  c_hec_pw()       { printf '# Standards\n<!-- scaffold:hec-tokens-committed -->\n' > ai/STANDARDS.md
                     mkdir -p default; printf 'token = 3f9a1b2c-4d5e-6f70-8192-a3b4c5d6e7f8\npassword = hunter2hunter2hunter2\n' > default/inputs.conf; }  # scaffold:not-a-secret

  echo "secret_scan selftest — line-scoped exceptions (#127), offline"
  case_run "an unmarked dev default still fails"              1 c_flask_bare
  case_run "an existing '# nosec' is honoured"                0 c_flask_nosec
  case_run "'# scaffold:not-a-secret' is honoured"            0 c_flask_marker
  case_run "a real credential still fails"                    1 c_real
  case_run "a marker on another line launders nothing"        1 c_marker_other
  case_run "one marked line does not excuse an unmarked one"  1 c_mixed
  case_run "a declared HEC token passes"                      0 c_hec_ok
  case_run "an undeclared HEC token still fails"              1 c_hec_undecl
  case_run "a password beside a token still fails"            1 c_hec_pw
  case_run "a secret in a path WITH SPACES still fails"      1 c_spaced_path
  case_run "a marked line in a spaced path still passes"     0 c_spaced_ok
  case_run "a secret in a BINARY file still fails"           1 c_binary
  case_run "aws_secret_access_key = <40 chars> fails"        1 c_aws_key
  case_run "a suffixed token name fails"                     1 c_suffix_token
  case_run "a suffixed name is still adjudicable"            0 c_suffix_adj
  case_run "the widening stops at a word boundary"           0 c_not_a_name
  case_run "a 19-char unquoted password fails"               1 c_short_value
  # DELIBERATELY MISSED, AND ASSERTED SO IT IS A DECISION RATHER THAN A GAP. Catching six
  # characters costs prose: `tokens: Splunk cannot read them...` matches, and ai/MEMORY.md
  # is the file most likely to contain exactly that. Measured — floor 6 gains this one leak
  # and loses two prose lines. gitleaks is the real tool.
  case_run "a 6-char value is missed, on purpose"            0 c_tiny_value
  case_run "password = changeme is a placeholder"            0 c_place_changeme
  case_run "secret = example is a placeholder"               0 c_place_example
  case_run "token = get_token() is a call, not a value"      0 c_place_call
  case_run "a placeholder VALUE does not clear a real one"   1 c_place_then_real
  case_run "a header NAME is not a credential"               0 c_ref_header
  case_run "a vault lookup NAME is not a credential"         0 c_ref_name
  case_run "a reference suffix does not launder a real one"  1 c_ref_plus_real
  case_run "prose in a session log is not a credential"      0 c_prose_md
  case_run "and the other sentence that turned a commit red" 0 c_prose_md2
  case_run "a real secret in Markdown is STILL caught"       1 c_secret_md
  case_run "a spaced value WITH a digit is still caught"     1 c_secret_md_sp
  case_run "the same prose in a .py file is still caught"    1 c_prose_py
  case_run "a camelCase reference name is suppressed"       0 c_camel_url
  case_run "...and snake_case still is, unchanged"          0 c_snake_url
  case_run "an arithmetic RHS cannot hold a credential"     0 c_expr_arith
  case_run "a subscript RHS cannot hold a credential"       0 c_expr_index
  case_run "a method-call RHS cannot hold a credential"     0 c_expr_call
  case_run "an UNQUOTED key is still caught (the guard rail)" 1 c_unquoted_key
  case_run "a ghp_ token with no keyword name fails"       1 c_shape_ghp
  case_run "a github_pat_ token fails"                     1 c_shape_pat
  case_run "an AKIA access key id fails"                   1 c_shape_akia
  case_run "a PEM private key header fails"                1 c_shape_pem
  case_run "a password in a URL fails"                     1 c_shape_url
  case_run "a URL whose password is a \${REF} passes"      0 c_shape_ref
  case_run "a marked shape line is adjudicable"            0 c_shape_marked
  case_run "a ghp_ prefix with too few chars passes"       0 c_shape_short

  # ---- THE SUPPRESSION COUNTS (design review 2026-08-14) ------------------------------
  #
  # THE CASE THAT MATTERS IS THE GREEN ONE. A red run is already being read carefully; the
  # failure this counting exists to end is a CLEAN verdict that is clean because an allowlist
  # ate every match, which prints the identical sentence to a genuinely quiet tree.
  #
  # Every case here asserts a NUMBER, not the presence of a line. "Reports its count" is
  # satisfied by printing the word `0` forever, and a counter wired to nothing does exactly
  # that — which is the defect class this whole ruling is about.
  sup_out() {  # sup_out <setup-fn>; runs a fixture and echoes the scan output
    local setup="$1" R="$T/sup"
    rm -rf "$R"; mkdir -p "$R/ai"
    ( cd "$R" && git init -q . && git config user.email a@b.c && git config user.name t )
    printf '# Standards\n' > "$R/ai/STANDARDS.md"
    ( cd "$R" && $setup )
    ( cd "$R" && git add -A >/dev/null 2>&1 )
    ( cd "$R" && bash "$SELF_ABS" 2>&1 )
  }
  sup_check() {  # sup_check <label> <expected-line> <setup-fn>
    local label="$1" want="$2" setup="$3" out
    out="$(sup_out "$setup")"
    if printf '%s\n' "$out" | grep -qF "$want"; then printf '  ok   %-54s\n' "$label"
    else
      printf '  FAIL %-54s wanted a line containing: %s\n' "$label" "$want"
      printf '%s\n' "$out" | sed 's/^/         /' | head -8
      fails=$((fails + 1))
    fi
  }

  # ZERO PRINTS. A tree with a keyword hit and no suppressions must still show the counts, or
  # a reader cannot tell "nothing was suppressed" from "nothing counted the suppressions".
  c_sup_none() { mkdir -p app; printf 'api_key = "sk_live_9f8a7b6c5d4e3f2a1b"\n' > app/s.py; }
  sup_check "0 adjudicated prints on a run with no suppressions" \
            "0  declared not-a-secret" c_sup_none

  # AND THE NUMBER IS REAL. Two adjudicated lines must read as two, not as "some".
  c_sup_two()  { mkdir -p app
                 printf "a_secret = 'dev-only-change-me'  # scaffold:not-a-secret\n" > app/a.py
                 printf "b_secret = 'dev-only-change-me'  # nosec B105\n" > app/b.py; }
  sup_check "two adjudicated lines are counted as two" \
            "2  declared not-a-secret" c_sup_two

  # ON THE RED PATH TOO. A finding plus a suppression is the case where the reader most needs
  # to know that something else was removed on the way to the one line they can see.
  c_sup_mixed(){ mkdir -p app
                 printf "d_secret = 'dev-only-change-me'  # scaffold:not-a-secret\napi_key = \"sk_live_9f8a7b6c5d4e3f2a1b\"\n" > app/m.py; }
  sup_check "the count prints on a FAILING run, not only a clean one" \
            "1  declared not-a-secret" c_sup_mixed

  # THE OTHER THREE FILTERS ARE ATTRIBUTED SEPARATELY. Chained greps would report one number
  # for four decisions, and the adjudication count is the only one that is a human decision.
  c_sup_ref()  { mkdir -p app; printf 'api_key_header = "X-Api-Key"\n' > app/r.py; }
  sup_check "a reference name is counted as a reference, not an adjudication" \
            "1  reference name" c_sup_ref
  sup_check "and does not inflate the adjudication count" \
            "0  declared not-a-secret" c_sup_ref

  # SCALE, ASSERTED RATHER THAN ASSUMED. v0.2.0's per-file walk cost ~4ms per tracked file
  # and nothing in the suite noticed, because every fixture repo held a handful of files —
  # a fixture acquires properties real input does not guarantee (ai/MEMORY.md). 600 files
  # would take ~2.4s under that shape and takes ~0.05s under this one, so the bound below
  # catches a reintroduced walk without making this suite slow enough to skip.
  local R="$T/scale" i start elapsed
  rm -rf "$R"; mkdir -p "$R/ai/pkg"
  ( cd "$R" && git init -q . && git config user.email a@b.c && git config user.name t )
  printf '# Standards\n' > "$R/ai/STANDARDS.md"
  i=0; while [ "$i" -lt 600 ]; do printf 'x = %d\n' "$i" > "$R/ai/pkg/m$i.py"; i=$((i + 1)); done
  ( cd "$R" && git add -A >/dev/null 2>&1 )
  start=$(date +%s)
  ( cd "$R" && bash "$SELF_ABS" >/dev/null 2>&1 )
  elapsed=$(( $(date +%s) - start ))
  if [ "$elapsed" -le 1 ]; then printf '  ok   %-54s\n' "600 files scan in <=1s (prefilter intact)"
  else
    printf '  FAIL %-54s took %ss\n' "600 files scan in <=1s (prefilter intact)" "$elapsed"
    fails=$((fails + 1))
  fi

  rm -rf "$T"
  echo ""
  if [ "$fails" -eq 0 ]; then echo "  all checks passed"; return 0; fi
  echo "  $fails check(s) FAILED"; return 1
}

case "${1:-}" in
  --selftest) selftest ;;
  "")         scan ;;
  *)          echo "usage: secret_scan.sh [--selftest]" >&2; exit 2 ;;
esac
