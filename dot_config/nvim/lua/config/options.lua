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
-- instead of navigating terminal panes. WezTerm user vars are base64-encoded.
-- Needs a POSIX `base64` on PATH; on Windows that's Git's bundled usr/bin,
-- added to PATH by the PowerShell profile (Documents/PowerShell/...ps1.tmpl),
-- not by this file.
local function encode_and_send(encoded)
	io.write(string.format("\x1b]1337;SetUserVar=IS_NVIM=%s\x07", encoded:gsub("%s+", "")))
end

local function base64_cmd(value)
	return "echo -n " .. value .. " | base64"
end

vim.api.nvim_create_autocmd("VimEnter", {
	callback = function()
		-- Async here: startup latency is what the "fast" goal actually cares
		-- about, and nothing downstream depends on this finishing in order.
		-- jobstart (unlike vim.system) takes a plain string and goes through
		-- &shell/&shellcmdflag the same way the original system() call did.
		local chunks = {}
		vim.fn.jobstart(base64_cmd("true"), {
			stdout_buffered = true,
			on_stdout = function(_, data)
				chunks = data
			end,
			on_exit = function()
				encode_and_send(table.concat(chunks, ""))
			end,
		})
	end,
})
vim.api.nvim_create_autocmd("VimLeave", {
	callback = function()
		-- Sync here: nvim is about to exit, so blocking briefly is harmless,
		-- but going async risks the process exiting before the signal is sent.
		encode_and_send(vim.fn.system(base64_cmd("false")))
	end,
})
