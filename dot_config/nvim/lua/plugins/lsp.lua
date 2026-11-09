-- Neovim 0.11+ already maps grn/gra/grr/gri/K (rename/code action/
-- references/implementation/hover) on LSP attach, and [d/]d (previous/next
-- diagnostic) globally — don't re-map those here. This only adds what core
-- doesn't cover: a key for the diagnostic float.
vim.api.nvim_create_autocmd("LspAttach", {
	callback = function(args)
		vim.keymap.set("n", "<leader>e", vim.diagnostic.open_float, { buffer = args.buf, desc = "Show diagnostic" })
	end,
})

return {
	{
		"williamboman/mason.nvim",
		-- Deferred past startup until a real file is opened — BufReadPre/
		-- BufNewFile (not VeryLazy) so mason-lspconfig's automatic_enable
		-- still runs before that same buffer's FileType autocmd needs an
		-- LSP attached.
		event = { "BufReadPre", "BufNewFile" },
		config = true,
	},
	{
		-- mason-lspconfig v2 auto-enables installed servers via vim.lsp.enable()
		-- (the automatic_enable default), so nvim-lspconfig just needs to be
		-- present for its bundled server configs, with no setup() call of our
		-- own — that per-server .setup() API is deprecated and being removed
		-- in nvim-lspconfig v3.0.0.
		"williamboman/mason-lspconfig.nvim",
		event = { "BufReadPre", "BufNewFile" },
		dependencies = { "mason.nvim", "neovim/nvim-lspconfig" },
		opts = {
			ensure_installed = { "lua_ls" },
		},
	},
}
