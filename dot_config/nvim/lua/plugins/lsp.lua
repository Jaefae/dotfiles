return {
	{
		"williamboman/mason.nvim",
		config = true,
	},
	{
		-- mason-lspconfig v2 auto-enables installed servers via vim.lsp.enable()
		-- (the automatic_enable default), so nvim-lspconfig just needs to be
		-- present for its bundled server configs, with no setup() call of our
		-- own — that per-server .setup() API is deprecated and being removed
		-- in nvim-lspconfig v3.0.0.
		"williamboman/mason-lspconfig.nvim",
		dependencies = { "mason.nvim", "neovim/nvim-lspconfig" },
		opts = {
			ensure_installed = { "lua_ls" },
		},
	},
}
