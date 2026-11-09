# newera

A minimal, fast, cross-platform (macOS + Windows) developer environment: WezTerm, Neovim, and starship, managed by [chezmoi](https://www.chezmoi.io/) and themed from a single color source.

## Why

Most dotfiles setups end up with one of two problems: config drifts between machines, or re-theming means hand-editing several files in different formats. This repo fixes both by using a real dotfile manager instead of hand-rolled symlink scripts, and by generating every tool's colors from one YAML file.

## What's in here

| Tool | Role |
|---|---|
| [WezTerm](https://wezterm.org/) | Terminal + pane multiplexer, with nvim-aware pane navigation |
| [Neovim](https://neovim.io/) | Editor, [lazy.nvim](https://github.com/folke/lazy.nvim)-managed |
| [starship](https://starship.rs/) | Shell prompt |
| [chezmoi](https://www.chezmoi.io/) | Applies this repo to `$HOME` on any machine, templating OS differences |

## Theming

[`.chezmoidata.yaml`](.chezmoidata.yaml) holds a set of named color palettes (`themes`), in [base24](https://github.com/tinted-theming/base24) shape (the base16 slots plus real ANSI-bright colors), plus a `current_theme` pointer to the live one. Every templated config (`*.tmpl` files) reads from it:

- `dot_config/wezterm/theme.lua.tmpl` → WezTerm's color scheme
- `dot_config/nvim/lua/plugins/colorscheme.lua.tmpl` → Neovim, via [base16-nvim](https://github.com/RRethy/base16-nvim)
- `dot_config/starship.toml.tmpl` → starship's palette block
- `dot_config/nvim/lua/theme-data.lua.tmpl` → Lua-native theme list for the picker below

**Switching themes:**

- Inside Neovim, `<leader>ft` opens a Telescope picker. Selecting a theme recolors the running nvim instance instantly and syncs everything else in the background.
- From a terminal, run `theme-pick` (bash/macOS) or `theme-pick.ps1` (Windows) for an fzf picker. It syncs WezTerm and starship live but won't recolor an already-open Neovim instance.
- By hand: edit `current_theme` in `.chezmoidata.yaml`, then run `chezmoi apply`.

Both pickers call the shared `theme-sync`/`theme-sync.ps1` script, which persists the choice into `.chezmoidata.yaml` and renders the affected templates straight to their destinations via `chezmoi execute-template` — no full `chezmoi apply` needed. WezTerm auto-reloads on config-file change and starship re-reads its config every prompt, so both pick up the switch immediately; a later `chezmoi apply` is then a no-op for these files.

## Layout

```
.chezmoidata.yaml                  # the color themes — single source of truth
.chezmoi.toml.tmpl                 # one-time setup prompts (name/email)
.chezmoiignore                     # OS-conditional file exclusions
.chezmoiscripts/                   # package install scripts, run once per machine
dot_config/
  wezterm/                         # entry point + theme/platform/keys/filelinks/hyperlinks modules
  nvim/                            # init.lua, config/, plugins/ (one file per plugin)
  starship.toml.tmpl
dot_local/bin/                     # theme-sync + theme-pick (fzf), bash and PowerShell
dot_bashrc.tmpl                    # macOS/Linux bash profile
dot_zshrc.tmpl                     # macOS/Linux zsh profile (macOS default shell)
Documents/PowerShell/...ps1.tmpl   # Windows shell profile
run_onchange_after_nvim-sync-plugins.sh.tmpl
.github/workflows/verify.yml       # dry-run apply on macOS/Windows/Linux + filelinks parser test
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

`chezmoi init --apply` will prompt once for a name and email (used only for local git config, not committed anywhere), install the required packages (WezTerm, Neovim, starship, ripgrep, fd, zoxide, eza, fzf) via `winget`/`brew`, render every templated config, and sync Neovim plugins headlessly.

## Verifying changes

```bash
chezmoi diff                       # preview changes before they touch real files
chezmoi apply --dry-run -v         # full dry run
chezmoi cat ~/.config/starship.toml  # render one file in isolation
```

`.github/workflows/verify.yml` runs a dry-run apply on Linux, macOS, and Windows runners on every push, since OS-conditional templates can't be fully verified from a single machine.

## Neovim plugins

`lazy.nvim`, `nvim-lspconfig` + `mason.nvim`, `nvim-treesitter`, `blink.cmp`, `telescope.nvim`, `gitsigns.nvim`, `lualine.nvim`, `base16-nvim`, `oil.nvim`, `conform.nvim`, `which-key.nvim`. Deliberately small — add what you need as you need it, under `dot_config/nvim/lua/plugins/`, one file per plugin.
