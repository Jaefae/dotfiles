# Persists the chosen theme slug into .chezmoidata.yaml, then renders the
# templates that encode it straight to their real destinations via
# `chezmoi execute-template` — skipping a full `chezmoi apply` so WezTerm
# (auto-reloads on config-file change) and starship (re-reads its config
# every prompt) sync instantly, without touching anything else chezmoi
# manages. A later `chezmoi apply` is then a no-op for these files.
#
# Called by the <leader>ft Telescope picker inside Neovim and by the
# standalone theme-pick.ps1 (fzf) script. Usage: theme-sync.ps1 <theme-slug>
param(
	[Parameter(Mandatory = $true)]
	[string]$Slug
)

$ErrorActionPreference = "Stop"

$sourceDir = (chezmoi source-path | Out-String).Trim()
$dataFile = Join-Path $sourceDir ".chezmoidata.yaml"

$lines = Get-Content -LiteralPath $dataFile
if (-not ($lines -match '^current_theme:')) {
	Write-Error "theme-sync: no current_theme: line found in $dataFile"
	exit 1
}

$newLines = @("current_theme: `"$Slug`"") + ($lines | Where-Object { $_ -notmatch '^current_theme:' })
Set-Content -LiteralPath $dataFile -Value $newLines

# Byte-exact render: PowerShell's text pipeline/redirection re-splits
# external-process stdout into lines and rejoins with CRLF, which would
# make the destination mismatch what `chezmoi apply` itself writes (LF,
# no BOM) and leave a spurious diff on the next apply. Capturing raw
# stdout bytes directly avoids that.
function Render([string]$Template, [string]$Dest) {
	$psi = [System.Diagnostics.ProcessStartInfo]::new()
	$psi.FileName = "chezmoi"
	$psi.ArgumentList.Add("execute-template")
	$psi.ArgumentList.Add("-f")
	$psi.ArgumentList.Add((Join-Path $sourceDir $Template))
	$psi.RedirectStandardOutput = $true
	$psi.UseShellExecute = $false

	$proc = [System.Diagnostics.Process]::Start($psi)
	$ms = [System.IO.MemoryStream]::new()
	$proc.StandardOutput.BaseStream.CopyTo($ms)
	$proc.WaitForExit()
	if ($proc.ExitCode -ne 0) {
		throw "chezmoi execute-template failed for $Template"
	}

	[System.IO.File]::WriteAllBytes($Dest, $ms.ToArray())
}

Render "dot_config/wezterm/theme.lua.tmpl" "$HOME\.config\wezterm\theme.lua"
Render "dot_config/starship.toml.tmpl" "$HOME\.config\starship.toml"
Render "dot_config/nvim/lua/plugins/colorscheme.lua.tmpl" "$HOME\.config\nvim\lua\plugins\colorscheme.lua"
Render "dot_config/nvim/lua/theme-data.lua.tmpl" "$HOME\.config\nvim\lua\theme-data.lua"

Write-Output "Theme set to $Slug"
