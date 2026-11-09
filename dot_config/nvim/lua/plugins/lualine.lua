return {
	"nvim-lualine/lualine.nvim",
	opts = {
		-- lualine's built-in "base16" theme reads the live palette straight
		-- from base16-colorscheme (base01/02 bars, base0D/0B/0E/09 for the
		-- normal/insert/visual/replace mode blocks) rather than guessing it
		-- from highlight groups like "auto" does. It's re-read whenever a
		-- ColorScheme event fires, which the <leader>ft picker triggers.
		options = { theme = "base16", globalstatus = true },
	},
}
