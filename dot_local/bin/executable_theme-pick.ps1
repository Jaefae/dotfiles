# Lists the themes from .chezmoidata/ via fzf and hands the choice to
# theme-sync.ps1, which re-applies every themed file (WezTerm, starship,
# fzf, eza, Neovim) and recolors running Neovim instances too.
$ErrorActionPreference = "Stop"

$listTemplate = @'
{{ range $slug, $t := .themes }}{{ $slug }}  {{ $t.name }}
{{ end }}
'@

$choice = (chezmoi execute-template $listTemplate) -split "`n" |
	Where-Object { $_.Trim() -ne "" } |
	fzf --prompt="Theme> " --with-nth=2.. --delimiter="  "

if (-not $choice) {
	exit 0
}

$slug = ($choice -split '\s+')[0]
& (Join-Path $PSScriptRoot "theme-sync.ps1") $slug
