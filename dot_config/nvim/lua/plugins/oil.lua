return {
	"stevearc/oil.nvim",
	lazy = false,
	opts = {
		default_file_explorer = true,
		view_options = {
			show_hidden = true,
		},
	},
	keys = {
		{ "-", "<cmd>Oil<cr>", desc = "Open parent directory" },
		{ "<leader>-", function() require("oil").open_float() end, desc = "Open parent directory (float)" },
	},
}
