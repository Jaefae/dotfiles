# macOS packages for this config, installed by
# .chezmoiscripts/run_onchange_before_00-install-packages-darwin.sh.tmpl
# (re-run by chezmoi whenever this file changes). Check by hand with:
#   brew bundle check --file=Brewfile --verbose

brew "chezmoi"
brew "neovim"
brew "starship"
brew "zoxide"
brew "eza"
brew "fd"
brew "ripgrep"
brew "git"
brew "fzf"

# Skip the cask when WezTerm was installed by hand: brew refuses to install
# over an existing /Applications/WezTerm.app.
cask "wezterm" unless File.exist?("/Applications/WezTerm.app")

# Fonts referenced by dot_config/wezterm/wezterm.lua.tmpl. WezTerm's bundled
# Symbols Nerd Font is older than the glyphs starship/eza use, which shows up
# as "No fonts contain glyphs for ..." warnings in its log.
cask "font-monaspace"
cask "font-symbols-only-nerd-font"
