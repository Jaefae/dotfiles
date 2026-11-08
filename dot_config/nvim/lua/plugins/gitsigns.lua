return {
	"lewis6991/gitsigns.nvim",
	opts = {
		on_attach = function(bufnr)
			local gitsigns = require("gitsigns")
			local opts = { buffer = bufnr }
			vim.keymap.set("n", "]c", gitsigns.next_hunk, vim.tbl_extend("force", opts, { desc = "Next hunk" }))
			vim.keymap.set("n", "[c", gitsigns.prev_hunk, vim.tbl_extend("force", opts, { desc = "Previous hunk" }))
			vim.keymap.set("n", "<leader>hs", gitsigns.stage_hunk, vim.tbl_extend("force", opts, { desc = "Stage hunk" }))
			vim.keymap.set("n", "<leader>hr", gitsigns.reset_hunk, vim.tbl_extend("force", opts, { desc = "Reset hunk" }))
			vim.keymap.set("n", "<leader>hp", gitsigns.preview_hunk, vim.tbl_extend("force", opts, { desc = "Preview hunk" }))
			vim.keymap.set("n", "<leader>hb", gitsigns.blame_line, vim.tbl_extend("force", opts, { desc = "Blame line" }))
		end,
	},
}
