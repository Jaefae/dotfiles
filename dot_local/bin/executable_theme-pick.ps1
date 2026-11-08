# Lists the themes from .chezmoidata.yaml via fzf and hands the choice to
# theme-sync.ps1, which syncs WezTerm and starship live.
#
# Known gap: this does NOT recolor an already-running Neovim instance —
# use the <leader>ft Telescope picker inside Neovim for that. This script
# is for switching from a plain terminal when Neovim isn't open.
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
