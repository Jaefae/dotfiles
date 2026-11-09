# newera

A minimal, fast, cross-platform (macOS + Windows) developer environment: WezTerm, Neovim, and starship, managed by [chezmoi](https://www.chezmoi.io/) and themed from a single color source.

## Why

Most dotfiles setups end up with one of two problems: config drifts between machines, or re-theming means hand-editing several files in different formats. This repo fixes both by using a real dotfile manager instead of hand-rolled symlink scripts, and by generating every tool's colors from one set of theme files.

## What's in here

| Tool | Role |
|---|---|
| [WezTerm](https://wezterm.org/) | Terminal + pane multiplexer, with nvim-aware pane navigation and LEADER+g to open file references in nvim |
| [Neovim](https://neovim.io/) | Editor, [lazy.nvim](https://github.com/folke/lazy.nvim)-managed, plugins pinned by `lazy-lock.json` |
| [starship](https://starship.rs/) | Shell prompt |
| [fzf](https://github.com/junegunn/fzf), [eza](https://github.com/eza-community/eza) | Fuzzy finder and `ls`, both themed |
| [chezmoi](https://www.chezmoi.io/) | Applies this repo to `$HOME` on any machine, templating OS differences |

## Theming

Themes live in [`.chezmoidata/`](.chezmoidata/), one file per theme, in [base24](https://github.com/tinted-theming/base24) shape (the base16 slots plus real ANSI-bright colors). chezmoi reads the directory in alphabetical order and merges it:

| File | Holds |
|---|---|
| `00-defaults.yaml` | the fallback `current_theme`, plus the schema and the rules for sourcing a palette |
| `theme-<slug>.yaml` | one theme: `name`, `variant` (`dark`/`light`), `palette`, optional `lint_ignore` |
| `zz-local.yaml` | **this machine's** selection, git-ignored and read last so it wins |

Every themed template starts with `{{ template "theme-guard" . }}` (from [`.chezmoitemplates/`](.chezmoitemplates/)), which fails with a readable message if the selected theme doesn't exist. Currently themed: WezTerm (`theme.lua.tmpl`), Neovim (`theme-data.lua.tmpl`, applied by `lua/theme.lua` via [base16-nvim](https://github.com/RRethy/base16-nvim)), starship, fzf, and eza.

**Switching themes** (per machine, never a git change):

- Inside Neovim, `<leader>ft` opens a Telescope picker that previews each theme live as you move; `<Esc>` restores the original.
- From a terminal, `theme-pick` (bash) or `theme-pick.ps1` (Windows) opens an fzf picker.
- Directly: `theme-sync <slug>` / `theme-sync.ps1 <slug>`.

All of them go through `theme-sync`, which validates the slug, writes `zz-local.yaml`, runs `chezmoi apply --force` on every template that includes `theme-guard` (found automatically), and recolors every running Neovim over its RPC socket. WezTerm reloads on file change, and starship/fzf/eza re-read their config on every run, so everything switches at once and a later `chezmoi apply` stays a no-op.

**Adding a theme:** `scripts/theme-import <tinted-theming scheme>` (see `--help`) writes `.chezmoidata/theme-<slug>.yaml` from [tinted-theming/schemes](https://github.com/tinted-theming/schemes) and runs the checker on it. Palettes that are role-mapped rather than hue-mapped (base08 isn't red, base0D isn't blue, ...) need `--override` fixes, because WezTerm maps base08-0E straight onto ANSI red..magenta. Record deliberate deviations with `--lint-ignore`.

**Theming another tool:** write a template whose first line is `{{ template "theme-guard" . }}` that reads `(index .themes .current_theme).palette`. `theme-sync` and `scripts/check-themes` pick it up with no other changes.

## Layout

```
.chezmoidata/                      # themes, one per file; zz-local.yaml = this machine's pick
.chezmoitemplates/                 # shared partials: theme-guard, shellrc (bash + zsh body)
.chezmoi.toml.tmpl                 # one-time setup prompts (name/email)
.chezmoiignore                     # OS-conditional exclusions, plus repo-only files
.chezmoiscripts/                   # package/font install, re-run when their inputs change
Brewfile                           # macOS packages + fonts (installed by the darwin script)
lazy-lock.json                     # Neovim plugin pins (lazy.nvim reads/writes it here)
dot_config/
  wezterm/                         # entry point + theme/platform/keys/filelinks/hyperlinks/statusbar
  nvim/                            # init.lua, config/, plugins/, lua/theme.lua, theme-broadcast.lua
  starship.toml.tmpl
  fzf/theme.tmpl                   # FZF_DEFAULT_OPTS_FILE
  eza/theme.yml.tmpl               # EZA_CONFIG_DIR
dot_local/bin/                     # theme-sync + theme-pick (fzf), bash and PowerShell
dot_bashrc.tmpl, dot_zshrc.tmpl    # one-line includes of .chezmoitemplates/shellrc
Documents/PowerShell/...ps1.tmpl   # Windows shell profile
run_onchange_after_nvim-sync-plugins-*.tmpl  # `Lazy! restore` when plugins or pins change
scripts/                           # repo tools, never deployed: check-themes, theme-import
.github/workflows/verify.yml       # lint, theme checks, PSScriptAnalyzer, dry-run apply on 3 OSes
```

## Setup on a new machine

**Windows**

```powershell
winget install twpayne.chezmoi
chezmoi init --apply <this-repo-url>
```

**macOS**

```bash
brew install chezmoi
chezmoi init --apply <this-repo-url>
```

`chezmoi init --apply` will prompt once for a name and email (used only for local git config, not committed anywhere), install the required packages and fonts (WezTerm, Neovim, starship, ripgrep, fd, zoxide, eza, fzf, Monaspace, Symbols Nerd Font) via `brew bundle`/`winget`, render every templated config with the default theme, and restore Neovim plugins to the pinned versions headlessly. macOS needs [Homebrew](https://brew.sh) installed first.

## Verifying changes

```bash
chezmoi diff                       # preview changes before they touch real files
chezmoi apply --dry-run -v         # full dry run
chezmoi cat ~/.config/starship.toml  # render one file in isolation
```

```bash
scripts/check-themes --strict      # every theme x every themed template: schema, render, parse, palette lint
```

`.github/workflows/verify.yml` runs those checks plus Lua/shell/PowerShell linting and a dry-run apply on Linux, macOS, and Windows runners on every push, since OS-conditional templates can't be fully verified from a single machine.

## Neovim plugins

`lazy.nvim`, `nvim-lspconfig` + `mason.nvim`, `nvim-treesitter`, `blink.cmp`, `telescope.nvim`, `gitsigns.nvim`, `lualine.nvim`, `base16-nvim`, `oil.nvim`, `conform.nvim`, `which-key.nvim`. Deliberately small — add what you need as you need it, under `dot_config/nvim/lua/plugins/`, one file per plugin. Versions are pinned in `lazy-lock.json` at the repo root: `:Lazy update` updates the pins (commit the result), and `chezmoi apply` restores every machine to them.
