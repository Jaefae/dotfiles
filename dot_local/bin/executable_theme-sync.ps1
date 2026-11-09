# Switches this machine's theme: records the choice in the git-ignored
# .chezmoidata/zz-local.yaml (read last, so it overrides the default in
# .chezmoidata/00-defaults.yaml), re-applies every themed file through
# chezmoi.
#
# Themed files are discovered, not listed: any template that includes
# {{ template "theme-guard" . }} is re-applied. Theming a new tool only
# takes writing such a template.
#
# Called by the <leader>ft Telescope picker inside Neovim and by the
# standalone theme-pick.ps1 (fzf) script. Usage: theme-sync.ps1 <theme-slug>
#
# Works under Windows PowerShell 5.1 and PowerShell 7. 5.1 mangles double
# quotes inside arguments passed to native programs, so no argument given
# to chezmoi or nvim below contains one.
param(
	[Parameter(Mandatory = $true)]
	[string]$Slug
)

$ErrorActionPreference = "Stop"

function Invoke-Native {
	# Runs a native command, returning its stdout lines; throws on failure.
	param([string]$Exe, [string[]]$Arguments)
	$output = & $Exe @Arguments
	if ($LASTEXITCODE -ne 0) {
		throw "$Exe $($Arguments -join ' ') failed with exit code $LASTEXITCODE"
	}
	return $output
}

function Write-Selection([string]$Content) {
	# LF, no BOM: matches what git and chezmoi expect on every OS.
	$tmp = "$localFile.tmp"
	[System.IO.File]::WriteAllText($tmp, $Content, (New-Object System.Text.UTF8Encoding $false))
	Move-Item -LiteralPath $tmp -Destination $localFile -Force
}

$sourceDir = (Invoke-Native "chezmoi" @("source-path") | Out-String).Trim()
$localFile = Join-Path $sourceDir ".chezmoidata\zz-local.yaml"

# 1. Validate before touching anything.
$listTemplate = @'
{{ range $slug, $t := .themes }}{{ $slug }}
{{ end }}
'@
$known = @(Invoke-Native "chezmoi" @("execute-template", $listTemplate) | Where-Object { $_.Trim() -ne "" })
if ($known -notcontains $Slug) {
	[Console]::Error.WriteLine("theme-sync: unknown theme '$Slug'. Known themes:")
	$known | ForEach-Object { [Console]::Error.WriteLine("  $_") }
	exit 1
}

# 2. Find the themed targets: source templates that include theme-guard,
#    mapped to their destinations, keeping only ones chezmoi manages on this
#    OS (.chezmoiignore may exclude some). chezmoi prints forward slashes, so
#    compare normalized, case-insensitively.
function Normalize([string]$Path) { return $Path.Replace('\', '/').ToLowerInvariant() }
$managed = @{}
Invoke-Native "chezmoi" @("managed", "--path-style", "absolute") | ForEach-Object { $managed[(Normalize $_)] = $true }

$excluded = @(".git", ".chezmoitemplates", "scripts")
$templates = Get-ChildItem -LiteralPath $sourceDir -Recurse -File -Filter "*.tmpl" |
	Where-Object {
		$relative = $_.FullName.Substring($sourceDir.Length).TrimStart('\', '/')
		$top = ($relative -split '[\\/]')[0]
		$excluded -notcontains $top
	} |
	Where-Object { Select-String -LiteralPath $_.FullName -SimpleMatch -Quiet -Pattern 'template "theme-guard"' } |
	Sort-Object FullName

$targets = @()
foreach ($template in $templates) {
	$target = (Invoke-Native "chezmoi" @("target-path", $template.FullName) | Out-String).Trim()
	if ($managed.ContainsKey((Normalize $target))) {
		$targets += $target
	}
}
if ($targets.Count -eq 0) {
	[Console]::Error.WriteLine("theme-sync: no themed templates found under $sourceDir")
	exit 1
}

# 3. Record the selection, then apply. --force skips chezmoi's "changed since
#    last written" prompt for these targets only; chezmoi writes each file
#    atomically and records it in its state, so a later `chezmoi apply` stays
#    a no-op. On failure, put the previous selection back and re-apply it.
$previous = $null
if (Test-Path -LiteralPath $localFile) {
	$previous = [System.IO.File]::ReadAllText($localFile)
}
Write-Selection "current_theme: `"$Slug`"`n"

& chezmoi apply --force -- @targets
if ($LASTEXITCODE -ne 0) {
	[Console]::Error.WriteLine("theme-sync: applying '$Slug' failed; restoring the previous theme")
	if ($null -ne $previous) {
		Write-Selection $previous
	} else {
		Remove-Item -LiteralPath $localFile -Force
	}
	& chezmoi apply --force -- @targets
	exit 1
}

Write-Output "Theme set to $Slug"
