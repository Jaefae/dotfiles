-- Requires the `stylua` formatter on PATH (`:MasonInstall stylua`, or via
-- brew/winget). Add more formatters under formatters_by_ft as needed.
return {
	"stevearc/conform.nvim",
	event = "BufWritePre",
	keys = {
		{
			"<leader>cf",
			function() require("conform").format({ async = true, lsp_format = "fallback" }) end,
			desc = "Format buffer",
		},
	},
	opts = {
		formatters_by_ft = {
			lua = { "stylua" },
		},
		format_on_save = {
			timeout_ms = 500,
			lsp_format = "fallback",
		},
	},
}
