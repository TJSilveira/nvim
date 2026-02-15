return
{
	"neovim/nvim-lspconfig",
	event = { "BufReadPre", "BufNewFile" },
	dependencies = {
        "saghen/blink.cmp",
		"hrsh7th/nvim-cmp",
		"hrsh7th/cmp-nvim-lsp",
		{ "antosha417/nvim-lsp-file-operations", config = true },
		{ "folke/neodev.nvim", opts = {} },
	},
	config = function()
        local capabilities = require('blink.cmp').get_lsp_capabilities()
        local lspconfig = require("lspconfig")
        local mason_lspconfig = require("mason-lspconfig")
        local cmp_nvim_lsp = require ("cmp_nvim_lsp")

        local keymap = vim.keymap


		vim.lsp.config('lua_ls', {
			-- Command and arguments to start the server.
			cmd = { 'lua-language-server' },
			-- Filetypes to automatically attach to.
			filetypes = { 'lua' },
			-- Sets the "workspace" to the directory where any of these files is found.
			-- Files that share a root directory will reuse the LSP server connection.
			-- Nested lists indicate equal priority, see |vim.lsp.Config|.
			root_markers = { { '.luarc.json', '.luarc.jsonc' }, '.git' },
			-- Specific settings to send to the server. The schema is server-defined.
			-- Example: https://raw.githubusercontent.com/LuaLS/vscode-lua/master/setting/schema.json
			settings = {
				Lua = {
					runtime = {
						version = 'LuaJIT',
					}
				}
			}
		})
		vim.lsp.enable('lua_ls')

		vim.lsp.config('clangd', {
			-- Command and arguments to start the server.
			cmd = { 'clangd' },
			-- Filetypes to automatically attach to.
			filetypes = { 'c', 'cpp' },
			capabilities = require('cmp_nvim_lsp').default_capabilities(),
			root_markers = { '.clangd', '.git' },
		})
		vim.lsp.enable('clangd')

        vim.lsp.config("*", {
            capabilities = capabilities,
        })
	end,
}
