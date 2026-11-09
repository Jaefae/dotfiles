local opt = vim.opt

vim.g.mapleader = " "
vim.g.maplocalleader = " "

opt.number = true
opt.relativenumber = true
opt.signcolumn = "yes"
opt.wrap = false
opt.scrolloff = 8

opt.expandtab = true
opt.shiftwidth = 2
opt.tabstop = 2
opt.smartindent = true

opt.ignorecase = true
opt.smartcase = true

opt.splitright = true
opt.splitbelow = true

opt.undofile = true
opt.swapfile = false
opt.updatetime = 200

opt.termguicolors = true
opt.winborder = "rounded" -- border on all floats (hover, diagnostics, etc.) so they read as separate from the buffer

opt.clipboard = "unnamedplus"

opt.foldmethod = "expr"
opt.foldexpr = "v:lua.vim.treesitter.foldexpr()"
opt.foldlevelstart = 99 -- open buffers unfolded; fold on demand with za/zc

vim.api.nvim_create_autocmd("BufReadPost", {
	callback = function()
		local mark = vim.api.nvim_buf_get_mark(0, '"')
		local lines = vim.api.nvim_buf_line_count(0)
		if mark[1] > 0 and mark[1] <= lines then
			vim.api.nvim_win_set_cursor(0, mark)
		end
	end,
})

-- Lets WezTerm detect when a pane is inside nvim, to pass CTRL+hjkl through
-- instead of navigating terminal panes (see dot_config/wezterm/keys.lua).
-- WezTerm user vars are base64-encoded; vim.base64 (nvim 0.10+) encodes
-- in-process, so this needs no subprocess or `base64` binary on PATH.
local function set_is_nvim(value)
	io.write(string.format("\x1b]1337;SetUserVar=IS_NVIM=%s\x07", vim.base64.encode(value)))
end

vim.api.nvim_create_autocmd("VimEnter", {
	callback = function()
		set_is_nvim("true")
	end,
})
vim.api.nvim_create_autocmd({ "VimLeave", "VimSuspend" }, {
	callback = function()
		set_is_nvim("false")
	end,
})
vim.api.nvim_create_autocmd("VimResume", {
	callback = function()
		set_is_nvim("true")
	end,
})
