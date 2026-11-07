-- Targets nvim-treesitter's "main" branch rewrite, which replaced the old
-- require("nvim-treesitter.configs").setup({ highlight = ..., indent = ... })
-- API entirely — there's no configs module on main at all. Parsers are
-- installed explicitly, and highlighting is started per-buffer rather than
-- toggled through an opts table.
return {
	"nvim-treesitter/nvim-treesitter",
	branch = "main",
	build = ":TSUpdate",
	config = function()
		require("nvim-treesitter").setup()
		require("nvim-treesitter").install({ "lua", "vim", "vimdoc", "markdown", "bash" })

		vim.api.nvim_create_autocmd("FileType", {
			callback = function()
				pcall(vim.treesitter.start)
			end,
		})
	end,
}
