-- Applies themes from lua/theme-data.lua, which chezmoi generates from
-- .chezmoidata/ (theme-data.lua.tmpl). Used at startup (plugins/
-- colorscheme.lua), by the <leader>ft picker (plugins/telescope.lua, also
-- for its live preview), and remotely by `theme-sync`, which calls
-- reload() over each running nvim's RPC socket after re-applying the files.
local M = {}

-- Returns the theme data, re-reading it from disk when `fresh` is set
-- (theme-sync rewrites theme-data.lua while nvim is running).
function M.data(fresh)
	if fresh then
		package.loaded["theme-data"] = nil
	end
	return require("theme-data")
end

-- Recolors this instance. Returns true on success.
function M.apply(slug)
	local theme = M.data().themes[slug]
	if not theme then
		vim.notify("Unknown theme: " .. tostring(slug), vim.log.levels.ERROR)
		return false
	end
	-- Before setup(): changing 'background' resets the default highlight
	-- groups, which setup() then overrides.
	vim.o.background = theme.variant == "light" and "light" or "dark"
	require("base16-colorscheme").setup(theme.palette)
	-- base16-colorscheme links NormalFloat to Normal, so hover/diagnostic/
	-- completion floats are the same color as the buffer behind them. base01
	-- is the palette's "lighter background" step, used elsewhere for things
	-- like the statusline, so it reads as a raised surface in every theme.
	vim.api.nvim_set_hl(0, "NormalFloat", { bg = theme.palette.base01 })
	vim.api.nvim_set_hl(0, "FloatBorder", { fg = theme.palette.base03, bg = theme.palette.base01 })
	M.current = slug
	-- base16-colorscheme.setup() only sets highlight groups and never fires
	-- ColorScheme, so plugins that cache theme colors (lualine) would keep
	-- the old palette until restart.
	vim.api.nvim_exec_autocmds("ColorScheme", { pattern = "base16-" .. slug, modeline = false })
	return true
end

-- Re-reads theme-data.lua, then applies `slug` (default: its current theme).
function M.reload(slug)
	local data = M.data(true)
	return M.apply(slug or data.current)
end

return M
