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
		local cmp_nvim_lsp = require("cmp_nvim_lsp")

		-- ─── Go to definition ─────────────────────────────────────────────────────
		-- tsserver often answers textDocument/definition for an imported symbol with
		-- the local `import` line instead of the file that declares it, and asking
		-- again from that import just points at itself — so `gd` appears to refuse to
		-- leave the current file. Its goToSourceDefinition command resolves through to
		-- the real declaration, but only when asked *at the import binding*, and it
		-- errors loudly for same-file symbols. So: normal request first, and escalate
		-- only when the answer turns out to be an import statement in this buffer.
		local function to_quickfix(items)
			local seen = {}
			items = vim.tbl_filter(function(item)
				local key = item.filename .. ":" .. item.lnum
				if seen[key] then return false end
				seen[key] = true
				return true
			end, items)
			vim.cmd("normal! m'") -- keep <C-o> working
			vim.fn.setqflist({}, " ", { title = "Definitions", items = items })
			if #items == 1 then
				vim.cmd("cfirst")
			else
				vim.cmd("copen")
			end
		end

		local function lands_on_import(uri, line)
			local target = vim.uri_to_bufnr(uri)
			vim.fn.bufload(target)
			local text = vim.api.nvim_buf_get_lines(target, line, line + 1, false)[1] or ""
			return text:match("^%s*import%s") ~= nil
		end

		local function go_to_definition(bufnr)
			local ts = vim.lsp.get_clients({ bufnr = bufnr, name = "ts_ls" })[1]
			if not ts then
				vim.lsp.buf.definition({ on_list = function(opts) to_quickfix(opts.items) end })
				return
			end

			local params = vim.lsp.util.make_position_params(0, ts.offset_encoding)
			ts:request("textDocument/definition", params, function(err, result)
				local locations = result or {}
				if not vim.islist(locations) then locations = { locations } end
				if err or #locations == 0 then
					vim.notify("No definition found", vim.log.levels.WARN)
					return
				end

				local function jump(final)
					to_quickfix(vim.lsp.util.locations_to_items(final, ts.offset_encoding))
				end

				local first = locations[1]
				local uri = first.targetUri or first.uri
				local range = first.targetSelectionRange or first.range
				if #locations > 1 or uri ~= params.textDocument.uri or not lands_on_import(uri, range.start.line) then
					jump(locations)
					return
				end

				ts:request("workspace/executeCommand", {
					command = "_typescript.goToSourceDefinition",
					arguments = { uri, range.start },
				}, function(cmd_err, cmd_result)
					if not cmd_err and type(cmd_result) == "table" and not vim.tbl_isempty(cmd_result) then
						jump(cmd_result)
					else
						jump(locations)
					end
				end, bufnr)
			end, bufnr)
		end

		-- ─── Keymaps (only active when an LSP attaches to a buffer) ───────────────
		vim.api.nvim_create_autocmd("LspAttach", {
			group = vim.api.nvim_create_augroup("UserLspConfig", {}),
			callback = function(ev)
				local map = function(keys, func, desc)
					vim.keymap.set("n", keys, func, { buffer = ev.buf, desc = "LSP: " .. desc })
				end

				map("gd", function()
					go_to_definition(ev.buf)
				end, "Go to Definition")
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

				if vim.lsp.inlay_hint then
					vim.lsp.inlay_hint.enable(true, { bufnr = ev.buf })
					map("<leader>ih", function()
						vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = ev.buf }), { bufnr = ev.buf })
					end, "Toggle Inlay Hints")
				end
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
				-- IMPORTANT (monorepo): Neovim's built-in lsp/ts_ls.lua roots the project
				-- at the nearest lockfile (pnpm-lock.yaml). In this pnpm monorepo that
				-- lives at ~/Monorepo, so tsserver would try to load the WHOLE repo and
				-- never resolve individual files. Root at the workspace package instead.
				--
				-- tsconfig/jsconfig is searched BEFORE package.json, and package.json is
				-- only a last resort: nested package.json files (wasm `pkg/` output,
				-- generated Prisma clients, one-off script folders) sit far below the real
				-- TS project. Rooting there drops tsserver into inferred-project mode,
				-- where same-file navigation still works but cross-file `gd` and path
				-- aliases silently return nothing.
				root_dir = function(bufnr, on_dir)
					local fname = vim.api.nvim_buf_get_name(bufnr)
					if fname == "" then return end
					local search = { upward = true, path = vim.fs.dirname(fname), stop = vim.loop.os_homedir() }
					local found = vim.fs.find({ "tsconfig.json", "jsconfig.json" }, search)[1]
						or vim.fs.find({ "package.json" }, search)[1]
					if found then on_dir(vim.fs.dirname(found)) end
				end,
				-- tsserver's 3GB default is not enough for a package this size; when it
				-- hits the ceiling it stops answering cross-file requests instead of
				-- reporting an error.
				init_options = { maxTsServerMemory = 8192 },
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

		-- ─── Register each server via the native Neovim 0.11 API ─────────────────
		-- On Neovim 0.11+, `lspconfig[server].setup()` is the deprecated path and,
		-- crucially, does NOT override the built-in `lsp/<server>.lua` config that
		-- mason-lspconfig's `automatic_enable` activates through `vim.lsp.enable()`.
		-- That is why the custom ts_ls root_dir above was previously ignored and
		-- tsserver rooted itself at the whole monorepo. `vim.lsp.config()`
		-- deep-merges onto the built-in config, so our overrides (root_dir,
		-- settings, capabilities) actually take effect. mason-lspconfig still calls
		-- `vim.lsp.enable()` for each installed server.
		for server_name, opts in pairs(server_settings) do
			opts.capabilities = opts.capabilities or capabilities
			vim.lsp.config(server_name, opts)
		end
	end,
}
