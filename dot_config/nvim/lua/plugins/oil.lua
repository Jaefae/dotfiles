-- oil.nvim edits a directory as a buffer, so by default selecting a file
-- replaces the oil view itself rather than opening it alongside a persistent
-- panel. The sidebar toggle below opens oil in a fixed-width split and
-- overrides <CR> to open files in the *other* window instead, so it behaves
-- like nvim-tree: a panel on the side, files opening next to it.
local function toggle_sidebar()
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "oil" then
			vim.api.nvim_win_close(win, false)
			return
		end
	end
	vim.cmd("topleft 30vsplit")
	require("oil").open()
	vim.wo.winfixwidth = true
end

local function open_entry_in_other_window()
	local oil = require("oil")
	local entry = oil.get_cursor_entry()
	if not entry then
		return
	end
	if entry.type == "directory" then
		oil.select()
		return
	end
	local path = oil.get_current_dir() .. entry.name
	vim.cmd("wincmd l")
	vim.cmd("edit " .. vim.fn.fnameescape(path))
end

return {
	"stevearc/oil.nvim",
	lazy = false,
	keys = {
		{ "-", "<cmd>Oil<cr>", desc = "Open parent directory" },
		{ "<leader>e", toggle_sidebar, desc = "Toggle file sidebar" },
	},
	opts = {
		default_file_explorer = true,
		keymaps = {
			["<CR>"] = open_entry_in_other_window,
		},
	},
}
