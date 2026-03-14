return {
	"neovim/nvim-lspconfig",
	event = { "BufReadPre", "BufNewFile" },
	dependencies = {
		"hrsh7th/cmp-nvim-lsp",
		{ "antosha417/nvim-lsp-file-operations", config = true },
		{ "folke/neodev.nvim", opts = {} }, -- better lua_ls for Neovim config/plugin files
	},
	config = function()
		local lspconfig = require("lspconfig")
		local mason_lspconfig = require("mason-lspconfig")
		local cmp_nvim_lsp = require("cmp_nvim_lsp")

		-- ─── Keymaps (only active when an LSP attaches to a buffer) ───────────────
		vim.api.nvim_create_autocmd("LspAttach", {
			group = vim.api.nvim_create_augroup("UserLspConfig", {}),
			callback = function(ev)
				local map = function(keys, func, desc)
					vim.keymap.set("n", keys, func, { buffer = ev.buf, desc = "LSP: " .. desc })
				end

				map("gd", vim.lsp.buf.definition, "Go to Definition")
				map("gD", vim.lsp.buf.declaration, "Go to Declaration")
				map("gr", vim.lsp.buf.references, "Show References")
				map("gI", vim.lsp.buf.implementation, "Go to Implementation")
				map("gy", vim.lsp.buf.type_definition, "Go to Type Definition")
				map("K", vim.lsp.buf.hover, "Hover Documentation")
				map("<leader>ca", vim.lsp.buf.code_action, "Code Action")
				map("<leader>rn", vim.lsp.buf.rename, "Rename Symbol")
				map("<leader>rs", ":LspRestart<CR>", "Restart LSP")
				map("[d", vim.diagnostic.goto_prev, "Previous Diagnostic")
				map("]d", vim.diagnostic.goto_next, "Next Diagnostic")
				map("<leader>d", vim.diagnostic.open_float, "Show Line Diagnostics")
				map("<leader>D", vim.diagnostic.setloclist, "Diagnostics List")
			end,
		})

		-- ─── Capabilities (merges nvim-cmp completion into LSP) ──────────────────
		local capabilities = cmp_nvim_lsp.default_capabilities()

		-- ─── Diagnostic signs ─────────────────────────────────────────────────────
		local signs = { Error = " ", Warn = " ", Hint = "󰠠 ", Info = " " }
		for type, icon in pairs(signs) do
			local hl = "DiagnosticSign" .. type
			vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = "" })
		end

		-- ─── Per-server settings ──────────────────────────────────────────────────
		local server_settings = {
			lua_ls = {
				settings = {
					Lua = {
						diagnostics = { globals = { "vim" } },
						completion = { callSnippet = "Replace" },
						workspace = { checkThirdParty = false },
						telemetry = { enable = false },
					},
				},
			},

			ts_ls = {
				settings = {
					typescript = { inlayHints = { includeInlayParameterNameHints = "all" } },
					javascript = { inlayHints = { includeInlayParameterNameHints = "all" } },
				},
			},

			gopls = {
				settings = {
					gopls = {
						analyses = { unusedparams = true },
						staticcheck = true,
						gofumpt = true,
					},
				},
			},

			pyright = {
				settings = {
					python = {
						analysis = {
							typeCheckingMode = "basic",
							autoSearchPaths = true,
							useLibraryCodeForTypes = true,
						},
					},
				},
			},

			clangd = {
				cmd = {
					"clangd",
					"--background-index",
					"--clang-tidy",
					"--header-insertion=iwyu",
					"--completion-style=detailed",
					"--function-arg-placeholders",
				},
				capabilities = vim.tbl_deep_extend("force", capabilities, {
					offsetEncoding = { "utf-16" }, -- clangd requires this
				}),
			},

			rust_analyzer = {
				settings = {
					["rust-analyzer"] = {
						cargo = { allFeatures = true },
						checkOnSave = { command = "clippy" },
						inlayHints = { lifetimeElisionHints = { enable = "always" } },
					},
				},
			},

			emmet_ls = {
				filetypes = {
					"html",
					"typescriptreact",
					"javascriptreact",
					"css",
					"sass",
					"scss",
					"less",
					"svelte",
				},
			},

			graphql = {
				filetypes = { "graphql", "gql", "typescriptreact", "javascriptreact" },
			},

			-- servers that need no extra config beyond defaults
			html = {},
			tailwindcss = {},
			prismals = {},
			bashls = {},
			dockerls = {},
			eslint = {},
			ast_grep = {},
		}

		-- ─── Setup handler (wires mason-lspconfig → nvim-lspconfig) ──────────────
		mason_lspconfig.setup_handlers({
			-- default handler — called for every installed server not listed below
			function(server_name)
				local opts = server_settings[server_name] or {}
				opts.capabilities = opts.capabilities or capabilities
				lspconfig[server_name].setup(opts)
			end,
		})
	end,
}
