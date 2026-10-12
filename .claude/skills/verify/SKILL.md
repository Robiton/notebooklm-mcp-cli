---
name: verify
description: Run a structured verification pass before declaring work done. Use PROACTIVELY at the Verify phase of ai/PLANNING.md, before reporting "done" on any multi-step task, after integrating a localcoder draft, or when the user says "verify", "verify this", "prove it", "check your work", or "is this actually done". Checks the claim at the right layer with evidence, samples edge cases, and reports verified vs. assumed.
---

<!--
Project:  ai-project-scaffold
File:     .agents/skills/verify/SKILL.md (canonical) — mirrored at .claude/skills/verify/SKILL.md
Modified: 2026-07-08
Version:  0.1.1.20260708.0919
Purpose:  Invocable verification pass — codifies the Verify gate (ai/PLANNING.md)
Changelog:
  2026-07-08 v0.1.1 — Dual-homed: canonical in .agents/skills/ (Agent Skills open standard,
                       read by Codex etc.); byte-identical mirror in .claude/skills/ for
                       Claude Code (which does not scan .agents/skills as of v2.1.203).
                       Edit the canonical copy, then re-run setup.sh — sync-check.sh
                       flags drift between the two.
  2026-07-07 v0.1.0 — Initial creation
-->

# Verify

A verification pass for work that is about to be called done. "It ran" is not verification —
this skill checks the *claim*, at the right layer, with evidence, and reports calibrated.
It is the invocable form of `ai/PLANNING.md` → *Verification*; that file is the source of truth.

## The pass — run every step

### 1. Restate the claims

List what "done" is claiming, explicitly. One line each. ("The parser handles quoted commas."
"The README matches the new flags." "All 14 call sites were updated.") If a claim can't be
stated, it can't be verified — go back and scope it.

### 2. Verify each claim at its own layer

- If the claim is "the output is correct" — look at the output, not the exit code.
- If the claim is "the page renders" — render the page, not just the build.
- If the claim is "N things were changed" — count them.
- Exit code 0, "it compiles," and "the diff looks right" only prove the layer *below* the claim.

### 3. Use evidence you didn't generate

Re-open the file that was written. Run the code or its tests. Diff before against after.
Screenshot and read the screenshot. Intention is not evidence; observation is.

### 4. Sample the tails

Check the first item, the last item, and the weirdest item — empty input, unicode, the
boundary value. Happy-path spot checks hide the failures that matter.

### 5. Interrogate good news

A test that passes too easily, an all-clean sweep, a suspiciously fast run — treat the
*verification* as broken until you can explain why the result is real.

### 6. Re-check the original ask

Compare the result against the original request and the standing rules loaded at session
start (`ai/` files). Built the right thing, and built it by the rules?

## Report format

Lead with the verdict, then:

- **Verified:** each claim + the evidence (command run, file re-read, number counted) — with specifics.
- **Assumed:** anything not directly checked, and why it couldn't be.
- **Found:** anything the pass turned up — including "nothing." Finding nothing wrong is a
  legitimate result; never manufacture a finding to look thorough.

Never state as fact what was not verified this session.

## Notes

- Pairs with the **local-coder loop** (`tools/README.md` → *Local coder*): this pass is
  load-bearing there, not optional. Aim it — local drafts are reliable on logic that follows
  from supplied context and unreliable on **engine/library API recall**, which is the failure
  mode that actually ships bugs. Verify every symbol the draft named; a clean compile does not
  prove the API exists.
- Right-size it: for a one-line change, steps 1–2 alone may be the whole pass. Forcing all
  six steps onto trivial work is its own failure mode.
