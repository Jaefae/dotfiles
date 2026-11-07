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

-- Lets WezTerm detect when a pane is inside nvim, to pass CTRL+hjkl through
-- instead of navigating terminal panes. WezTerm user vars are base64-encoded.
local function set_is_nvim(value)
	local encoded = vim.fn.system("echo -n " .. value .. " | base64"):gsub("%s+", "")
	io.write(string.format("\x1b]1337;SetUserVar=IS_NVIM=%s\x07", encoded))
end

vim.api.nvim_create_autocmd("VimEnter", {
	callback = function()
		set_is_nvim("true")
	end,
})
vim.api.nvim_create_autocmd("VimLeave", {
	callback = function()
		set_is_nvim("false")
	end,
})
