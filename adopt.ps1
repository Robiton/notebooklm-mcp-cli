# Project:  ai-project-scaffold
# File:     adopt.ps1
# Modified: 2026-09-08
# Version:  0.1.0.20260908.0528
# Purpose:  Adopt the scaffold into an existing project on Windows, natively, with no bash.
# Changelog:
#   2026-09-08 v0.1.0.20260908.0528 — Initial. THE ADOPTION PATH ONLY, and deliberately not a
#                        port of setup.sh. setup.sh is 2,175 lines and tools/ is another
#                        19,686 across 26 files; porting that is a second implementation of
#                        every rule, which is the defect this project exists to prevent.
#                        What a Windows adopter actually needs is the COPY, and that is a
#                        file operation. The gates still need bash -- see LIMITS below, which
#                        says so rather than implying coverage this does not have.
#                        NOT VERIFIED ON WINDOWS AT WRITING. No pwsh on the authoring machine.
#                        Run with -WhatIf first; see the note at the bottom.

<#
.SYNOPSIS
Copy the AI Project Scaffold into an existing project, on Windows, without bash.

.DESCRIPTION
Reads the SINGLE manifest declaration in tools/adoption_manifest.sh and copies exactly what
it names. It does not carry its own list of files.

That matters more than it looks. This project has already shipped a release where a new file
was on no delivery list and therefore reached nobody, and adoption_manifest.sh exists because
four separate restatements of "what an adoption receives" had drifted apart. A fifth
restatement, in PowerShell, on a platform nobody tests, would be the same defect with a new
file extension. So the manifest is parsed, never copied.

.PARAMETER ScaffoldPath
Path to a clone of the scaffold repository.

.PARAMETER Target
The project to adopt into. Defaults to the current directory.

.PARAMETER WhatIf
Show what would be copied and change nothing. Run this first.

.EXAMPLE
  git clone https://github.com/Robiton/ai-project-scaffold.git C:\src\ai-project-scaffold
  cd C:\src\my-project
  git checkout -b chore/add-scaffold
  C:\src\ai-project-scaffold\adopt.ps1 -ScaffoldPath C:\src\ai-project-scaffold -WhatIf
  C:\src\ai-project-scaffold\adopt.ps1 -ScaffoldPath C:\src\ai-project-scaffold

.NOTES
LIMITS — read these, they are the point.

  * This copies. It does not gate. tools/preflight.sh, setup.sh --check and every scanner are
    bash, and they are what actually enforce the standards. On Windows, run them under WSL or
    Git Bash. An adoption made by this script is NOT a verified adoption until a gate has run
    against it, and nothing here will tell you otherwise.
  * It does not fill in AGENTS.md. The Project Commands table ships with [fill in] markers and
    a human has to answer them; setup.sh --check reports them as a finding, so run it.
  * CLAUDE.md is created as a committed one-line pointer, never a symlink. Claude Code reads
    CLAUDE.md and not AGENTS.md, and a symlink here has destroyed the target file in a real
    adoption -- 86 bytes to 11. On Windows a symlink also needs Administrator or Developer
    Mode, so the pointer is the only correct form on this platform twice over.
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true)][string]$ScaffoldPath,
    [string]$Target = (Get-Location).Path
)

$ErrorActionPreference = 'Stop'

function Get-AdoptionManifest {
    <#
      Parse the manifest out of tools/adoption_manifest.sh.

      ONE DECLARATION, TWO READERS. The bash tool and this script read the same heredoc, so
      adding a file to the manifest reaches Windows adopters without anyone remembering to
      edit a second list. If this parse ever returns nothing, that is a HARD failure below
      rather than an empty copy -- an adoption that silently delivers zero files is the
      worst outcome available here, because it looks like it worked.
    #>
    param([string]$ManifestScript)

    if (-not (Test-Path $ManifestScript)) {
        throw "Cannot find $ManifestScript. Is -ScaffoldPath really a scaffold clone?"
    }
    $lines = Get-Content $ManifestScript
    $inBlock = $false
    $entries = @()
    foreach ($line in $lines) {
        if (-not $inBlock) {
            if ($line -match "^\s*cat\s+<<'EOF'\s*$") { $inBlock = $true }
            continue
        }
        if ($line -match '^\s*EOF\s*$') { break }
        $t = $line.Trim()
        if ($t) { $entries += $t }
    }
    return $entries
}

Write-Host ''
Write-Host '  AI Project Scaffold — Windows adoption' -ForegroundColor Cyan
Write-Host '  ------------------------------------------------------------'

if (-not (Test-Path $ScaffoldPath)) { throw "ScaffoldPath does not exist: $ScaffoldPath" }
if (-not (Test-Path $Target))       { throw "Target does not exist: $Target" }

$manifestScript = Join-Path $ScaffoldPath 'tools\adoption_manifest.sh'
$manifest = Get-AdoptionManifest -ManifestScript $manifestScript

if ($manifest.Count -eq 0) {
    throw ("Parsed ZERO entries from $manifestScript. The manifest format has changed and " +
           "this script has not. Refusing to copy nothing and call it an adoption.")
}
Write-Host ("  manifest: {0} entries from tools/adoption_manifest.sh" -f $manifest.Count)

# REFUSE TO ADOPT INTO A DIRTY TREE, for the same reason scaffold_upgrade.sh does: it makes
# `git checkout .` a complete undo. Skipped when the target is not a git repo at all.
Push-Location $Target
try {
    $isRepo = $false
    try { git rev-parse --git-dir *> $null; $isRepo = ($LASTEXITCODE -eq 0) } catch { $isRepo = $false }
    if ($isRepo) {
        $dirty = git status --porcelain
        if ($dirty -and -not $WhatIfPreference) {
            throw ("The target working tree is dirty. Commit or stash first, so that " +
                   "`git checkout .` is a complete undo of this adoption.")
        }
        Write-Host '  target is a git repository, working tree clean'
    } else {
        Write-Host '  target is not a git repository — proceeding, but you lose the undo' -ForegroundColor Yellow
    }
} finally { Pop-Location }

$copied = 0; $skipped = 0
foreach ($entry in $manifest) {
    $isDir = $entry.EndsWith('/')
    $name  = $entry.TrimEnd('/')
    $src   = Join-Path $ScaffoldPath ($name -replace '/', '\')
    $dst   = Join-Path $Target       ($name -replace '/', '\')

    if (-not (Test-Path $src)) {
        # A MANIFEST ENTRY WITH NO SOURCE IS A REAL FINDING, not a thing to pass over
        # quietly: it means the manifest and the tree disagree, which is what
        # adoption_manifest.sh --check exists to catch on the bash side.
        Write-Host ("  [MISSING] {0} — on the manifest, absent from the scaffold" -f $entry) -ForegroundColor Red
        $skipped++
        continue
    }

    if ($PSCmdlet.ShouldProcess($dst, "copy $entry")) {
        if ($isDir) {
            New-Item -ItemType Directory -Force -Path $dst | Out-Null
            Copy-Item -Path (Join-Path $src '*') -Destination $dst -Recurse -Force
        } else {
            $parent = Split-Path $dst -Parent
            if ($parent -and -not (Test-Path $parent)) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
            Copy-Item -Path $src -Destination $dst -Force
        }
        $copied++
    }
    Write-Host ("  {0} {1}" -f $(if ($WhatIfPreference) { 'would copy' } else { 'copied   ' }), $entry)
}

# CLAUDE.md — A COMMITTED POINTER, NEVER A SYMLINK. See LIMITS above.
$claude = Join-Path $Target 'CLAUDE.md'
$pointer = @'
<!-- Claude Code hook. The @AGENTS.md line below imports AGENTS.md verbatim at load
     time — a reference, not a copy; AGENTS.md stays the single source of truth.
     Add Claude Code-specific rules below the import if ever needed. -->

@AGENTS.md
'@
if ($PSCmdlet.ShouldProcess($claude, 'write the @AGENTS.md pointer')) {
    Set-Content -Path $claude -Value $pointer -Encoding utf8 -NoNewline:$false
}

Write-Host ''
Write-Host ("  {0} entry(ies) handled, {1} missing" -f $copied, $skipped)
Write-Host ''
Write-Host '  NOT DONE YET — this copied files, it did not verify them:' -ForegroundColor Yellow
Write-Host '    1. Fill in the Project Commands table in AGENTS.md ([fill in] markers).'
Write-Host '    2. Run the gates under WSL or Git Bash — they are bash and there is no'
Write-Host '       PowerShell equivalent:'
Write-Host '           ./setup.sh --check'
Write-Host '           tools/preflight.sh'
Write-Host '    3. Only a passing gate makes this a verified adoption. A copy is not one.'
Write-Host ''
if ($skipped -gt 0) {
    Write-Host '  Some manifest entries had no source file. Report that — it means the' -ForegroundColor Red
    Write-Host '  manifest and the scaffold tree disagree, which affects every adopter.' -ForegroundColor Red
    exit 1
}
